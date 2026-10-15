#!/bin/bash

set -e

ssl=${ssl:-false}
tls_services=${tls_services:-}
private_key=${private_key:-tls.key}
certificate_request=${certificate_request:-tls.csr}
certificate=${certificate:-tls.crt}

# Generate certificate
if [[ $ssl == "true" ]]; then
  url=${url:-"https://localhost"}

  mkdir -p data/certs
  pushd data/certs

  openssl genrsa -out ${private_key} 2048
  openssl req \
    -new \
    -subj "/C=US/ST=Denial/L=Springfield/O=Dis/CN=www.example.com" \
    -key ${private_key} \
    -out ${certificate_request}
  openssl x509 -req -days 365 -in ${certificate_request} -signkey ${private_key} -out ${certificate}
  openssl dhparam -out dhparam.pem 2048
  chmod 400 ${private_key}

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

trap 'docker compose -p ds -f $config down' EXIT

# Run test environment
if [[ -n ${PACKAGE_VERSION:-} ]]; then
  : "${PACKAGE_BASEURL:?PACKAGE_BASEURL must be set with PACKAGE_VERSION}"
  docker compose -p ds -f "$config" build \
    --build-arg "PACKAGE_VERSION=${PACKAGE_VERSION}" \
    --build-arg "PACKAGE_BASEURL=${PACKAGE_BASEURL}" \
    onlyoffice-documentserver
  docker compose -p ds -f "$config" up -d --no-build
else
  docker compose -p ds -f "$config" up -d
fi

wakeup_timeout=300

# Get documentserver healthcheck status
echo "Wait for service wake up"
for (( elapsed=0; elapsed<=wakeup_timeout; elapsed+=10 )); do
  if healthcheck_res=$(wget --no-check-certificate -qO - ${url}/healthcheck); then
    if [[ $healthcheck_res == "true" ]]; then
      break
    fi
  fi

  sleep 10
done

# Fail if it isn't true
if [[ $healthcheck_res == "true" ]]; then
  echo "Healthcheck passed."
else
  echo "Healthcheck failed!"
  docker compose -p ds -f $config logs --no-color
  exit 1
fi

# Verify that database-only TLS does not leak into Redis or RabbitMQ settings.
if [[ ${assert_tls_isolation:-false} == "true" ]]; then
  docker compose -p ds -f "$config" exec -T onlyoffice-documentserver python3 <<'PYTHON'
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
