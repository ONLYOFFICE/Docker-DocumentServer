#!/bin/bash

set -eo pipefail

: "${config:?Set config to a compose file}"
ssl=${ssl:-false}
tls_services=${tls_services:-}
private_key=${private_key:-tls.key}
certificate_request=${certificate_request:-tls.csr}
certificate=${certificate:-tls.crt}
test_directory=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
export SMOKE_JWT_SECRET
SMOKE_JWT_SECRET=$(openssl rand -hex 32)
if [[ ${assert_graphite:-false} == true ]]; then
  # A unique prefix prevents a metric left by an earlier run from passing the test.
  export METRICS_PREFIX
  METRICS_PREFIX="ds.smoke.$(openssl rand -hex 6)."
fi

# Generate certificate
if [[ $ssl == "true" ]]; then
  url=${url:-"https://localhost"}

  mkdir -p data/certs
  pushd data/certs

  openssl req -x509 -newkey rsa:2048 -nodes -days 1 \
    -addext 'basicConstraints=critical,CA:TRUE' -addext 'keyUsage=critical,keyCertSign,cRLSign' \
    -keyout ca.key -out ca-certificates.pem -subj '/CN=ONLYOFFICE HTTPS Test CA'
  openssl genrsa -out "${private_key}" 2048
  openssl req \
    -new \
    -subj '/CN=localhost' \
    -key "${private_key}" \
    -out "${certificate_request}"
  printf '%s\n' 'basicConstraints=critical,CA:FALSE' 'keyUsage=critical,digitalSignature,keyEncipherment' \
    'subjectAltName=DNS:localhost,IP:127.0.0.1' 'extendedKeyUsage=serverAuth' > https.ext
  openssl x509 -req -days 1 -in "${certificate_request}" \
    -CA ca-certificates.pem -CAkey ca.key -CAcreateserial \
    -extfile https.ext -out "${certificate}"
  openssl dhparam -out dhparam.pem 2048
  chmod 400 "${private_key}" ca.key

  popd
else
  url=${url:-"http://localhost"}
fi

# Generate service TLS certificates
if [[ -n $tls_services ]]; then
  mkdir -p data/tls
  pushd data/tls

  openssl genrsa -out ca.key 2048
  MSYS_NO_PATHCONV=1 openssl req \
    -x509 \
    -new \
    -nodes \
    -days 365 \
    -addext 'basicConstraints=critical,CA:TRUE' \
    -addext 'keyUsage=critical,keyCertSign,cRLSign' \
    -subj "/C=US/ST=Denial/L=Springfield/O=Dis/CN=ONLYOFFICE Test CA" \
    -key ca.key \
    -out ca.crt
  chmod 600 ca.key
  chmod 644 ca.crt

  generate_server_cert() {
    local service=$1
    local common_name=$2

    openssl genrsa -out "${service}.key" 2048
    chmod 644 "${service}.key"
    cat > "${service}.cnf" <<EOF
[req]
distinguished_name = dn
req_extensions = v3_req
prompt = no

[dn]
C = US
ST = Denial
L = Springfield
O = Dis
CN = ${common_name}

[v3_req]
subjectAltName = DNS:${common_name}
EOF

    openssl req -new -key "${service}.key" -out "${service}.csr" -config "${service}.cnf"
    openssl x509 \
      -req \
      -days 365 \
      -in "${service}.csr" \
      -CA ca.crt \
      -CAkey ca.key \
      -CAcreateserial \
      -out "${service}.crt" \
      -extensions v3_req \
      -extfile "${service}.cnf"
    chmod 644 "${service}.crt"
  }

  has_tls_service() {
    [[ " ${tls_services} " == *" $1 "* ]]
  }

  for service in ${tls_services}; do
    generate_server_cert "${service}" "onlyoffice-${service}"
  done

  if has_tls_service postgresql; then
    cat > postgresql-init-tls.sh <<'EOF'
cp /tls/postgresql.crt "${PGDATA}/server.crt"
cp /tls/postgresql.key "${PGDATA}/server.key"
chmod 600 "${PGDATA}/server.key"

cat >> "${PGDATA}/postgresql.conf" <<'PGCONF'
ssl = on
ssl_cert_file = 'server.crt'
ssl_key_file = 'server.key'
PGCONF

cat > "${PGDATA}/pg_hba.conf" <<'PGHBA'
local all all trust
hostnossl all all all reject
hostssl all all all scram-sha-256
PGHBA
EOF
  fi
  if has_tls_service rabbitmq; then
    cat > rabbitmq.conf <<EOF
listeners.tcp = none
listeners.ssl.default = 5671
ssl_options.cacertfile = /tls/ca.crt
ssl_options.certfile = /tls/rabbitmq.crt
ssl_options.keyfile = /tls/rabbitmq.key
ssl_options.verify = verify_none
ssl_options.fail_if_no_peer_cert = false
EOF
  fi
  if has_tls_service mssql; then
    cat > mssql.conf <<EOF
[network]
forceencryption = 1
tlscert = /tls/mssql.crt
tlskey = /tls/mssql.key
EOF
  fi

  popd
fi

# Check if the yml exists
if [[ ! -f $config ]]; then
  echo "File $config doesn't exist!"
  exit 1
fi

compose=(docker compose -p ds -f "$config")
test_override=$(mktemp)
smoke_state=
cleanup() {
  local status=$?
  set +e
  if (( status != 0 )); then
    local status_log=/dev/null compose_log=/dev/null service_log=/dev/null metrics_log=/dev/null
    if [[ -n ${TEST_ARTIFACTS_DIR:-} ]]; then
      mkdir -p "$TEST_ARTIFACTS_DIR"
      status_log="$TEST_ARTIFACTS_DIR/containers.txt"
      compose_log="$TEST_ARTIFACTS_DIR/compose.log"
      service_log="$TEST_ARTIFACTS_DIR/documentserver.log"
      metrics_log="$TEST_ARTIFACTS_DIR/metrics.txt"
    fi
    "${compose[@]}" ps --all 2>&1 | tee "$status_log"
    "${compose[@]}" logs --no-color 2>&1 | tee "$compose_log"
    if [[ ${assert_graphite:-false} == true ]]; then
      "${compose[@]}" exec -T onlyoffice-documentserver python3 <<'PYTHON' 2>&1 | tee "$metrics_log"
import json
import socket

with open('/etc/onlyoffice/documentserver/local.json', encoding='utf-8') as file:
    settings = json.load(file).get('statsd', {})
print('Document Server StatsD settings:', json.dumps(settings), flush=True)
with open('/var/www/onlyoffice/documentserver/server/Metrics/config/config.js', encoding='utf-8') as file:
    print('StatsD forwarding configuration:', file.read(), flush=True)
# Inspect counters without sending a synthetic conversion metric. This separates
# missing application messages from a failure to forward them to Graphite.
with socket.create_connection(('127.0.0.1', 8126), timeout=5) as connection:
    connection.sendall(b'stats\n')
    print('StatsD management counters:', flush=True)
    with connection.makefile('r', encoding='utf-8', errors='replace') as response:
        for line in response:
            print(line, end='', flush=True)
            if line.strip() == 'END':
                break
PYTHON
    fi
    "${compose[@]}" exec -T onlyoffice-documentserver sh -c '
      for file in /var/log/onlyoffice/documentserver/docservice/*.log \
                  /var/log/onlyoffice/documentserver/converter/*.log \
                  /var/log/onlyoffice/documentserver/metrics/*.log \
                  /var/log/onlyoffice/documentserver/nginx.error.log; do
        if [ -f "$file" ]; then
          printf "\n%s\n" "$file"
          tail -n 200 "$file"
        fi
      done
    ' 2>&1 | tee "$service_log"
  fi
  if ! "${compose[@]}" down; then
    (( status != 0 )) || status=1
  fi
  rm -f "$test_override"
  [[ -z "$smoke_state" ]] || rm -f "$smoke_state"
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# This source server is local to the test runner; JWT validation stays enabled.
# Keep signed download URLs valid across the restart under test.
smoke_link_secret=$(openssl rand -hex 32)
cat > "$test_override" <<EOF
services:
  onlyoffice-documentserver:
    environment:
      JWT_ENABLED: "true"
      JWT_SECRET: "$SMOKE_JWT_SECRET"
      JWT_IN_BODY: "true"
      SECURE_LINK_SECRET: "$smoke_link_secret"
      ALLOW_PRIVATE_IP_ADDRESS: "true"
    extra_hosts:
      - "host.docker.internal:host-gateway"
EOF
compose+=(-f "$test_override")

# Run test environment
if [[ -n ${DOCUMENTSERVER_IMAGE:-} ]]; then
  printf '    image: %s\n' "$DOCUMENTSERVER_IMAGE" >> "$test_override"
  printf '    pull_policy: never\n' >> "$test_override"
  "${compose[@]}" pull --policy always onlyoffice-documentserver
  "${compose[@]}" up -d --no-build
elif [[ -n ${PACKAGE_VERSION:-} ]]; then
  : "${PACKAGE_BASEURL:?PACKAGE_BASEURL must be set with PACKAGE_VERSION}"
  "${compose[@]}" build \
    --build-arg "PACKAGE_VERSION=${PACKAGE_VERSION}" \
    --build-arg "PACKAGE_BASEURL=${PACKAGE_BASEURL}" \
    onlyoffice-documentserver
  "${compose[@]}" up -d --no-build
else
  "${compose[@]}" up -d
fi

http=(curl --silent --show-error --fail --connect-timeout 2 --max-time 5)
if [[ $ssl == true ]]; then
  http+=(--cacert data/certs/ca-certificates.pem)
fi

wait_ready() {
  local deadline=$((SECONDS + 300))
  local healthcheck_res
  echo 'Wait for service wake up'
  while (( SECONDS < deadline )); do
    if healthcheck_res=$("${http[@]}" "$url/healthcheck") && [[ $healthcheck_res == true ]]; then
      echo 'Healthcheck passed.'
      return 0
    fi
    sleep 5
  done
  echo 'Healthcheck failed after 300 seconds!'
  return 1
}
wait_ready

if [[ $ssl == true ]]; then
  expected=$(openssl x509 -in "data/certs/$certificate" -noout -fingerprint -sha256)
  if ! served=$(timeout 10 openssl s_client -connect localhost:443 -servername localhost \
    -CAfile data/certs/ca-certificates.pem -verify_return_error -verify_hostname localhost \
    </dev/null 2>/dev/null | openssl x509 -noout -fingerprint -sha256); then
    echo 'Failed to retrieve or verify the server HTTPS certificate!'
    exit 1
  fi
  if [[ "$served" != "$expected" ]]; then
    echo 'The server is not using the configured HTTPS certificate!'
    exit 1
  fi
  openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj '/CN=Untrusted Test CA' \
    -addext 'basicConstraints=critical,CA:TRUE' -addext 'keyUsage=critical,keyCertSign,cRLSign' \
    -keyout data/certs/untrusted.key -out data/certs/untrusted.crt
  # smoke.py checks CA rejection by SSL exception type, independently of curl's
  # TLS backend. Network, handshake and CA-file errors remain test failures.
  echo 'HTTPS hostname and served certificate checks passed.'
fi

# Verify that database-only TLS does not leak into Redis or RabbitMQ settings.
if [[ ${assert_tls_isolation:-false} == "true" ]]; then
  "${compose[@]}" exec -T onlyoffice-documentserver python3 <<'PYTHON'
import json

with open('/etc/onlyoffice/documentserver/local.json', encoding='utf-8') as file:
    cfg = json.load(file)

coauthoring = cfg.get('services', {}).get('CoAuthoring', {})
sql = coauthoring.get('sql', {})
redis = coauthoring.get('redis', {})
redis_tls = any(
    options and any(key in options for key in ('tls', 'ca', 'cert', 'key'))
    for options in (
        redis.get('options', {}).get('socket'),
        redis.get('iooptions', {}).get('tls'),
        redis.get('iooptionsClusterOptions', {}).get('tls'),
    )
)
rabbit = cfg.get('rabbitmq', {})
rabbit_tls = not rabbit.get('url', '').startswith('amqp://') or bool(rabbit.get('socketOptions'))
if not sql.get('pgPoolExtraOptions', {}).get('ssl') or redis_tls or rabbit_tls:
    raise RuntimeError('Database TLS settings leaked into Redis or RabbitMQ')
print('Database TLS isolation passed.')
PYTHON
fi

smoke=(python3 "$test_directory/smoke.py" --url "$url")
if [[ ${assert_cached_conversion:-false} == true ]]; then
  smoke+=(--require-cached-conversion)
fi
if [[ $ssl == true ]]; then
  smoke+=(--ca-file data/certs/ca-certificates.pem --untrusted-ca-file data/certs/untrusted.crt)
fi
if [[ ${assert_graphite:-false} == true ]]; then
  smoke+=(--graphite-url http://localhost:8888 --metrics-prefix "$METRICS_PREFIX")
fi
if [[ ${assert_restart:-false} == true ]]; then
  smoke_state=$(mktemp)
  "${smoke[@]}" --save-state "$smoke_state"
  container_id=$("${compose[@]}" ps -q onlyoffice-documentserver)
  started_before=$(docker inspect --format '{{.State.StartedAt}}' "$container_id")
  "${compose[@]}" restart --timeout 60 onlyoffice-documentserver
  wait_ready
  started_after=$(docker inspect --format '{{.State.StartedAt}}' "$container_id")
  if [[ "$started_before" == "$started_after" ]]; then
    echo 'Document Server did not restart!'
    exit 1
  fi
  "${smoke[@]}" --resume-state "$smoke_state"
else
  "${smoke[@]}"
fi
