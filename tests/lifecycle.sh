#!/bin/bash

# Lifecycle checks of the entrypoint on a random high port (80 and 443 stay free): secrets, *_FILE, release marker, DS_DB_UPGRADE, WAIT_TIMEOUT.

# Usage: DOCUMENTSERVER_IMAGE=<image> scenario="secrets db-upgrade mssql-upgrade wait-timeout" bash lifecycle.sh (the database scenarios skip Community Edition).

set -eo pipefail

: "${DOCUMENTSERVER_IMAGE:?Set DOCUMENTSERVER_IMAGE to the image under test}"
scenario=${scenario:-secrets db-upgrade wait-timeout}
port=${port:-$((20000 + RANDOM % 20000))}
run_label="dslc-$$"
workdir=$(mktemp -d)
failures=0
db_password='p@ss w"or$*?'
data_path=/var/www/onlyoffice/Data
json_tool=/var/www/onlyoffice/documentserver/npm/json
local_json=/etc/onlyoffice/documentserver/local.json

cleanup() {
  local status=$?
  set +e
  if (( status != 0 || failures != 0 )) && [[ -n ${TEST_ARTIFACTS_DIR:-} ]]; then
    mkdir -p "$TEST_ARTIFACTS_DIR"
    for container in $(docker ps --all --quiet --filter "label=$run_label"); do
      docker logs "$container" > "$TEST_ARTIFACTS_DIR/lifecycle-$(docker inspect --format '{{.Name}}' "$container" | tr -d /).log" 2>&1
    done
  fi
  docker ps --all --quiet --filter "label=$run_label" | xargs -r docker rm --force --volumes > /dev/null
  docker volume ls --quiet --filter "label=$run_label" | xargs -r docker volume rm --force > /dev/null
  docker network ls --quiet --filter "label=$run_label" | xargs -r docker network rm > /dev/null
  rm -rf "$workdir"
  exit $(( status != 0 ? status : failures != 0 ))
}
trap cleanup EXIT

check() {
  local description=$1 expected=$2 actual=$3
  if [[ $expected == "$actual" ]]; then
    echo "PASS: $description"
  else
    echo "FAIL: $description (expected '$expected', got '$actual')" >&2
    failures=$((failures + 1))
  fi
}

# Print a short fingerprint so that secrets never reach the log.
fingerprint() { printf '%s' "$1" | sha256sum | cut -c1-12; }

new_volume() {
  docker volume create --label "$run_label" "$run_label-$1" > /dev/null
  echo "$run_label-$1"
}

# start_container <name> <extra docker arguments...>: the Data volume is <name>-data unless -v overrides it.
start_container() {
  local name=$1; shift
  docker rm --force --volumes "$run_label-$name" > /dev/null 2>&1 || true
  docker run --detach --name "$run_label-$name" --label "$run_label" --publish "127.0.0.1:$port:80" "$@" "$DOCUMENTSERVER_IMAGE" > /dev/null
}

wait_ready() {
  local name=$1 deadline=$((SECONDS + 300))
  while (( SECONDS < deadline )); do
    if [[ $(curl --silent --max-time 3 "http://127.0.0.1:$port/healthcheck" || true) == true ]]; then
      return 0
    fi
    if [[ $(docker inspect --format '{{.State.Running}}' "$run_label-$name") != true ]]; then
      docker logs --tail 20 "$run_label-$name" >&2
      echo "Container $name exited before it became ready!" >&2
      exit 1
    fi
    sleep 5
  done
  docker logs --tail 20 "$run_label-$name" >&2
  echo "Container $name did not pass the healthcheck in 300 seconds!" >&2
  exit 1
}

config_fingerprint() {
  fingerprint "$(docker exec "$run_label-$1" "$json_tool" -q -f "$local_json" "$2")"
}

scenario_secrets() {
  echo '== Secrets'
  local data jwt_before link_before
  data=$(new_volume secrets-data)
  start_container secrets --volume "$data:$data_path"
  wait_ready secrets
  jwt_before=$(config_fingerprint secrets services.CoAuthoring.secret.inbox.string)
  link_before=$(config_fingerprint secrets storage.fs.secretString)

  docker restart "$run_label-secrets" > /dev/null
  wait_ready secrets
  check 'JWT secret survives a restart' "$jwt_before" "$(config_fingerprint secrets services.CoAuthoring.secret.inbox.string)"
  check 'secure link secret survives a restart' "$link_before" "$(config_fingerprint secrets storage.fs.secretString)"

  start_container secrets --volume "$data:$data_path"
  wait_ready secrets
  check 'JWT secret survives a recreated container' "$jwt_before" "$(config_fingerprint secrets services.CoAuthoring.secret.inbox.string)"
  check 'secrets are stored with mode 600' '600 600' \
    "$(docker exec "$run_label-secrets" stat --format %a "$data_path/.private/jwt_secret" "$data_path/.private/secure_link_secret" | paste -sd ' ')"

  start_container secrets --volume "$data:$data_path" --env JWT_SECRET=explicit-jwt --env SECURE_LINK_SECRET=explicit-link
  wait_ready secrets
  check 'explicit JWT_SECRET wins over the stored one' "$(fingerprint explicit-jwt)" "$(config_fingerprint secrets services.CoAuthoring.secret.inbox.string)"
  check 'explicit SECURE_LINK_SECRET wins over the stored one' "$(fingerprint explicit-link)" "$(config_fingerprint secrets storage.fs.secretString)"

  start_container secrets --volume "$data:$data_path"
  wait_ready secrets
  check 'stored JWT secret is used again after an explicit one' "$jwt_before" "$(config_fingerprint secrets services.CoAuthoring.secret.inbox.string)"

  printf '%s\n' file-jwt-secret > "$workdir/jwt"
  printf '%s\n' file-link-secret > "$workdir/link"
  start_container secrets --volume "$(new_volume secrets-file-data):$data_path" \
    --volume "$workdir/jwt:/run/secrets/jwt:ro" --volume "$workdir/link:/run/secrets/link:ro" \
    --env JWT_SECRET_FILE=/run/secrets/jwt --env SECURE_LINK_SECRET_FILE=/run/secrets/link
  wait_ready secrets
  check 'JWT_SECRET_FILE is read without the trailing newline' "$(fingerprint file-jwt-secret)" "$(config_fingerprint secrets services.CoAuthoring.secret.inbox.string)"
  check 'SECURE_LINK_SECRET_FILE is read without the trailing newline' "$(fingerprint file-link-secret)" "$(config_fingerprint secrets storage.fs.secretString)"

  start_container secrets --volume "$(new_volume secrets-disabled-data):$data_path" --env JWT_ENABLED=false
  wait_ready secrets
  check 'no JWT secret is stored when JWT is disabled' 'secure_link_secret' \
    "$(docker exec "$run_label-secrets" ls -A "$data_path/.private" | grep -v '^ds_release_date$' | paste -sd ' ')"

  local status=0
  docker run --name "$run_label-missing-file" --label "$run_label" --env JWT_SECRET_FILE=/nonexistent "$DOCUMENTSERVER_IMAGE" > "$workdir/missing-file.log" 2>&1 || status=$?
  check 'an unreadable *_FILE stops the start' 1 "$status"
  check 'an unreadable *_FILE is reported' true "$(grep -q 'JWT_SECRET_FILE .* is not readable' "$workdir/missing-file.log" && echo true || echo false)"
  docker rm --force --volumes "$run_label-secrets" > /dev/null
}

is_commercial_image() {
  docker image inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$DOCUMENTSERVER_IMAGE" | grep -q '^PRODUCT_EDITION=.\+'
}

postgres_query() {
  docker exec --env "PGPASSWORD=$db_password" "$run_label-postgres" psql --host 127.0.0.1 --username onlyoffice --dbname onlyoffice --tuples-only --no-align --command "$1"
}

sentinel_count() { postgres_query "SELECT count(*) FROM doc_changes WHERE id = 'sentinel'"; }

add_sentinel() { postgres_query "INSERT INTO doc_changes VALUES ('t', 'sentinel', 1, 'u', 'u', 'n', 'data', now())" > /dev/null; }

warning_count() { docker logs "$run_label-ds" 2>&1 | grep -c '^WARNING: no release marker' || true; }

scenario_db_upgrade() {
  echo '== Release marker and DS_DB_UPGRADE'
  is_commercial_image || { echo 'SKIP: the image is not an Enterprise or Developer edition'; return; }
  local network="$run_label-postgres-net"
  docker network create --label "$run_label" "$network" > /dev/null
  printf '%s\n' "$db_password" > "$workdir/db_password"
  docker run --detach --name "$run_label-postgres" --label "$run_label" --network "$network" \
    --env POSTGRES_USER=onlyoffice --env "POSTGRES_PASSWORD=$db_password" --env POSTGRES_DB=onlyoffice postgres:16 > /dev/null
  local postgres_deadline=$((SECONDS + 120))
  until [[ $(postgres_query 'SELECT 1' 2> /dev/null || true) == 1 ]]; do
    if (( SECONDS >= postgres_deadline )); then
      docker logs --tail 20 "$run_label-postgres" >&2
      echo 'PostgreSQL did not become ready in 120 seconds!' >&2
      exit 1
    fi
    sleep 2
  done

  # The password comes from a file, which also covers DB_PWD_FILE.
  local database_arguments=(--network "$network" --volume "$workdir/db_password:/run/secrets/db_password:ro"
    --env DB_TYPE=postgres --env DB_HOST="$run_label-postgres" --env DB_PORT=5432 --env DB_NAME=onlyoffice --env DB_USER=onlyoffice
    --env DB_PWD_FILE=/run/secrets/db_password --env JWT_SECRET=lifecycle)

  start_container ds --volume "$(new_volume db-data-empty):$data_path" "${database_arguments[@]}"
  wait_ready ds
  check 'a fresh volume with an empty database prints no marker warning' 0 "$(warning_count)"
  check 'the schema is created from DB_PWD_FILE credentials' 1 "$(postgres_query "SELECT count(*) FROM information_schema.tables WHERE table_name = 'doc_changes'")"
  add_sentinel

  start_container ds --volume "$(new_volume db-data-kept):$data_path" "${database_arguments[@]}"
  wait_ready ds
  check 'tables are kept on a start without a release marker' 1 "$(sentinel_count)"
  check 'existing tables without a marker are reported' 1 "$(warning_count)"

  start_container ds --volume "$(new_volume db-data-upgrade):$data_path" --env DS_DB_UPGRADE=true "${database_arguments[@]}"
  wait_ready ds
  check 'DS_DB_UPGRADE=true recreates the tables without a marker' 0 "$(sentinel_count)"
  check 'no marker warning is printed for DS_DB_UPGRADE=true' 0 "$(warning_count)"

  add_sentinel
  docker restart "$run_label-ds" > /dev/null
  wait_ready ds
  check 'a restart with an existing marker keeps the tables even with DS_DB_UPGRADE=true' 1 "$(sentinel_count)"

  docker exec "$run_label-ds" sh -c "echo 1999-01-01 > $data_path/.private/ds_release_date"
  docker restart "$run_label-ds" > /dev/null
  wait_ready ds
  check 'a different release marker recreates the tables' 0 "$(sentinel_count)"
  check 'the release marker is refreshed after an upgrade' false "$(docker exec "$run_label-ds" grep -q 1999-01-01 "$data_path/.private/ds_release_date" && echo true || echo false)"
  docker rm --force --volumes "$run_label-ds" > /dev/null

  # Bundled PostgreSQL: its data volume is kept while the Data volume (and the marker) is not.
  local postgres_data local_query
  postgres_data=$(new_volume local-postgres)
  local_query() { docker exec "$run_label-ds" sudo -u postgres psql --dbname onlyoffice --tuples-only --no-align --command "$1"; }
  start_container ds --volume "$postgres_data:/var/lib/postgresql" --volume "$(new_volume local-data-first):$data_path" --env JWT_SECRET=lifecycle
  wait_ready ds
  local_query "INSERT INTO doc_changes VALUES ('t', 'sentinel', 1, 'u', 'u', 'n', 'data', now())" > /dev/null
  docker rm --force --volumes "$run_label-ds" > /dev/null
  start_container ds --volume "$postgres_data:/var/lib/postgresql" --volume "$(new_volume local-data-second):$data_path" --env JWT_SECRET=lifecycle
  wait_ready ds
  check 'bundled PostgreSQL keeps its tables when only the Data volume is new' 1 "$(local_query "SELECT count(*) FROM doc_changes WHERE id = 'sentinel'")"
  docker rm --force --volumes "$run_label-ds" > /dev/null
  start_container ds --volume "$postgres_data:/var/lib/postgresql" --volume "$(new_volume local-data-third):$data_path" --env DS_DB_UPGRADE=true --env JWT_SECRET=lifecycle
  wait_ready ds
  check 'DS_DB_UPGRADE=true recreates the bundled PostgreSQL tables' 0 "$(local_query "SELECT count(*) FROM doc_changes WHERE id = 'sentinel'")"
  docker rm --force --volumes "$run_label-ds" "$run_label-postgres" > /dev/null
  docker network rm "$network" > /dev/null
}

mssql_query() {
  docker exec --env "SQLCMDPASSWORD=$mssql_password" "$run_label-mssql" /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -d "${2:-onlyoffice}" -h -1 -W \
    -Q "SET NOCOUNT ON; $1" | tr -d '[:space:]'
}

mssql_sentinel_count() { mssql_query "SELECT COUNT(*) FROM doc_changes WHERE id = N'sentinel'"; }

add_mssql_sentinel() {
  mssql_query "INSERT INTO doc_changes (tenant, id, change_id, user_id, user_id_original, user_name, change_data, change_date) VALUES (N't', N'sentinel', 1, N'u', N'u', N'n', N'data', GETDATE())" > /dev/null
}

scenario_mssql_upgrade() {
  echo '== MSSQL release marker and DS_DB_UPGRADE'
  is_commercial_image || { echo 'SKIP: the image is not an Enterprise or Developer edition'; return; }
  local network="$run_label-mssql-net" mssql_deadline=$((SECONDS + 240))
  mssql_password='Sa-Str0ng p@ss w"1'
  docker network create --label "$run_label" "$network" > /dev/null
  printf '%s\n' "$mssql_password" > "$workdir/mssql_password"
  docker run --detach --name "$run_label-mssql" --label "$run_label" --network "$network" --env ACCEPT_EULA=Y --env "MSSQL_SA_PASSWORD=$mssql_password" \
    --env MSSQL_MEMORY_LIMIT_MB=2048 mcr.microsoft.com/mssql/server:2022-latest > /dev/null
  until [[ $(mssql_query 'SELECT 1' master 2> /dev/null || true) == 1 ]]; do
    if (( SECONDS >= mssql_deadline )); then
      docker logs --tail 20 "$run_label-mssql" >&2
      echo 'MSSQL did not become ready in 240 seconds!' >&2
      exit 1
    fi
    sleep 3
  done

  local database_arguments=(--network "$network" --volume "$workdir/mssql_password:/run/secrets/db_password:ro"
    --env DB_TYPE=mssql --env DB_HOST="$run_label-mssql" --env DB_PORT=1433 --env DB_NAME=onlyoffice --env DB_USER=sa
    --env DB_PWD_FILE=/run/secrets/db_password --env JWT_SECRET=lifecycle)

  start_container ds --volume "$(new_volume mssql-data-empty):$data_path" "${database_arguments[@]}"
  wait_ready ds
  check 'MSSQL: a fresh volume with a database that does not exist yet prints no marker warning' 0 "$(warning_count)"
  check 'MSSQL: the schema is created' 1 "$(mssql_query "SELECT COUNT(*) FROM sys.tables WHERE name = N'doc_changes'")"
  add_mssql_sentinel

  start_container ds --volume "$(new_volume mssql-data-kept):$data_path" "${database_arguments[@]}"
  wait_ready ds
  check 'MSSQL: tables are kept on a start without a release marker' 1 "$(mssql_sentinel_count)"
  check 'MSSQL: existing tables without a marker are reported' 1 "$(warning_count)"

  start_container ds --volume "$(new_volume mssql-data-upgrade):$data_path" --env DS_DB_UPGRADE=true "${database_arguments[@]}"
  wait_ready ds
  check 'MSSQL: DS_DB_UPGRADE=true recreates the tables without a marker' 0 "$(mssql_sentinel_count)"
  check 'MSSQL: no marker warning is printed for DS_DB_UPGRADE=true' 0 "$(warning_count)"

  add_mssql_sentinel
  docker restart "$run_label-ds" > /dev/null
  wait_ready ds
  check 'MSSQL: a restart with an existing marker keeps the tables' 1 "$(mssql_sentinel_count)"
  docker rm --force --volumes "$run_label-ds" "$run_label-mssql" > /dev/null
  docker network rm "$network" > /dev/null
}

# run_wait_timeout <timeout> <expected exit code> <expected message>
run_wait_timeout() {
  local timeout=$1 expected_status=$2 expected_message=$3 status=0 started=$SECONDS
  docker rm --force --volumes "$run_label-wait" > /dev/null 2>&1 || true
  # An unreachable data container host is the dependency wait that exists in every edition.
  docker run --name "$run_label-wait" --label "$run_label" --env ONLYOFFICE_DATA_CONTAINER_HOST=no-such-host --env "WAIT_TIMEOUT=$timeout" \
    "$DOCUMENTSERVER_IMAGE" > "$workdir/wait.log" 2>&1 || status=$?
  check "WAIT_TIMEOUT=$timeout exits with $expected_status" "$expected_status" "$status"
  check "WAIT_TIMEOUT=$timeout reports '$expected_message'" true "$(grep -q "$expected_message" "$workdir/wait.log" && echo true || echo false)"
  check "WAIT_TIMEOUT=$timeout fails fast" 1 "$(( SECONDS - started < 120 ? 1 : 0 ))"
}

scenario_wait_timeout() {
  echo '== WAIT_TIMEOUT'
  run_wait_timeout 5 1 'not reachable after 5 seconds'
  # A leading zero must be read as a decimal number, not as octal.
  run_wait_timeout 08 1 'not reachable after 8 seconds'
  run_wait_timeout abc 1 'WAIT_TIMEOUT must be a number of seconds'
}

for name in $scenario; do
  case $name in
    secrets) scenario_secrets ;;
    db-upgrade) scenario_db_upgrade ;;
    mssql-upgrade) scenario_mssql_upgrade ;;
    wait-timeout) scenario_wait_timeout ;;
    *) echo "Unknown scenario: $name" >&2; exit 2 ;;
  esac
done

if (( failures != 0 )); then
  echo "$failures check(s) failed!" >&2
fi
