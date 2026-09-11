#!/bin/bash
set -o pipefail
umask 0022 # Ensure created files get 644 and dirs 755 regardless of container defaults.

# Initialize all configuration variables from environment and computed defaults.
init_config(){
  # Directory structure: app, data, logs, config, services.
  APP_DIR="/var/www/${COMPANY_NAME}/documentserver"
  DATA_DIR="/var/www/${COMPANY_NAME}/Data"
  PRIVATE_DATA_DIR="${DATA_DIR}/.private"
  DS_RELEASE_DATE="${PRIVATE_DATA_DIR}/ds_release_date"
  LOG_DIR="/var/log/${COMPANY_NAME}"
  DS_LOG_DIR="${LOG_DIR}/documentserver"
  LIB_DIR="/var/lib/${COMPANY_NAME}"
  DS_LIB_DIR="${LIB_DIR}/documentserver"
  CONF_DIR="/etc/${COMPANY_NAME}/documentserver"
  SUPERVISOR_CONF_DIR="/etc/supervisor/conf.d"
  IS_UPGRADE="false"
  PLUGINS_ENABLED=${PLUGINS_ENABLED:-true}

  # Docker/data container mode.
  ONLYOFFICE_DATA_CONTAINER=${ONLYOFFICE_DATA_CONTAINER:-false}
  ONLYOFFICE_DATA_CONTAINER_HOST=${ONLYOFFICE_DATA_CONTAINER_HOST:-localhost}
  ONLYOFFICE_DATA_CONTAINER_PORT=80

  # SSL/TLS and HTTPS configuration.
  SSL_VERIFY_CLIENT=${SSL_VERIFY_CLIENT:-off}
  USE_UNAUTHORIZED_STORAGE=${USE_UNAUTHORIZED_STORAGE:-false}
  ONLYOFFICE_HTTPS_HSTS_ENABLED=${ONLYOFFICE_HTTPS_HSTS_ENABLED:-true}
  ONLYOFFICE_HTTPS_HSTS_MAXAGE=${ONLYOFFICE_HTTPS_HSTS_MAXAGE:-31536000}

  # Nginx configuration: paths and worker tuning.
  NGINX_ONLYOFFICE_PATH="${CONF_DIR}/nginx"
  NGINX_ONLYOFFICE_CONF="${NGINX_ONLYOFFICE_PATH}/ds.conf"

  NGINX_CONFIG_PATH="/etc/nginx/nginx.conf"
  NGINX_WORKER_PROCESSES=${NGINX_WORKER_PROCESSES:-1}
  NGINX_ACCESS_LOG=${NGINX_ACCESS_LOG:-true}
  local limit
  limit=$(ulimit -n); [ "$limit" = "unlimited" ] || [ "$limit" -gt 1048576 ] && limit=1048576
  NGINX_WORKER_CONNECTIONS=${NGINX_WORKER_CONNECTIONS:-$limit}
  RABBIT_CONNECTIONS=${RABBIT_CONNECTIONS:-$limit}

  # JWT and WOPI/security settings.
  JWT_ENABLED=${JWT_ENABLED:-true}
  JWT_ENABLED="$([[ "${JWT_ENABLED}" == "true" ]] && echo "true" || echo "false")"
  [[ "${JWT_ENABLED}" == "true" && -z "${JWT_SECRET}" ]] && JWT_MESSAGE='JWT is enabled by default. A random secret is generated automatically. Run the command "docker exec $(sudo docker ps -q) sudo documentserver-jwt-status" to get information about JWT.'

  JWT_SECRET=${JWT_SECRET:-$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)}
  JWT_HEADER=${JWT_HEADER:-Authorization}
  JWT_IN_BODY=${JWT_IN_BODY:-false}

  WOPI_ENABLED=${WOPI_ENABLED:-false}
  ALLOW_META_IP_ADDRESS=${ALLOW_META_IP_ADDRESS:-false}
  ALLOW_PRIVATE_IP_ADDRESS=${ALLOW_PRIVATE_IP_ADDRESS:-false}

  # Feature flags and feature availability.
  GENERATE_FONTS=${GENERATE_FONTS:-true}

  local _is_commercial
  [ -n "${PRODUCT_EDITION}" ] && _is_commercial=true || _is_commercial=false
  REDIS_AVAILABLE=${_is_commercial} RABBITMQ_AVAILABLE=${_is_commercial} DB_AVAILABLE=${_is_commercial} ADMINPANEL_AVAILABLE=${_is_commercial}

  # JSON config files and CLI tool paths.
  ONLYOFFICE_DEFAULT_CONFIG=${CONF_DIR}/local.json
  ONLYOFFICE_LOG4JS_CONFIG=${CONF_DIR}/log4js/production.json
  ONLYOFFICE_EXAMPLE_CONFIG=${CONF_DIR}-example/local.json

  JSON_BIN=${APP_DIR}/npm/json
  JSON="${JSON_BIN} -q -f ${ONLYOFFICE_DEFAULT_CONFIG}"
  JSON_LOG="${JSON_BIN} -q -f ${ONLYOFFICE_LOG4JS_CONFIG}"
  JSON_EXAMPLE="${JSON_BIN} -q -f ${ONLYOFFICE_EXAMPLE_CONFIG}"

  LOCAL_SERVICES=()

  # Data paths for bundled services: PostgreSQL, RabbitMQ, Redis.
  PG_ROOT=/var/lib/postgresql
  PG_NAME=main
  PGDATA=${PG_ROOT}/${PG_VERSION}/${PG_NAME}
  PG_NEW_CLUSTER=false
  RABBITMQ_DATA=/var/lib/rabbitmq
  REDIS_DATA=/var/lib/redis

  # Detect if this is an upgrade: release date changed and not a data container.
  RELEASE_DATE="$(stat -c="%y" "${APP_DIR}"/server/DocService/docservice | sed -r 's/=([0-9]+)-([0-9]+)-([0-9]+) ([0-9:.+ ]+)/\1-\2-\3/')"
  PREV_RELEASE_DATE="$([[ -f ${DS_RELEASE_DATE} ]] && head -n 1 "${DS_RELEASE_DATE}" || echo "0")"
  [[ "${RELEASE_DATE}" != "${PREV_RELEASE_DATE}" && "${ONLYOFFICE_DATA_CONTAINER}" != "true" ]] && IS_UPGRADE="true"
}

# Resolve SSL/TLS paths: user-supplied > company-specific > Let's Encrypt > default.
# If self-signed (subject == issuer), inject into Node.js as extra CA certificate.
init_ssl(){
  SSL_CERTIFICATES_DIR="/usr/share/ca-certificates/ds"; mkdir -p ${SSL_CERTIFICATES_DIR}
  find "${DATA_DIR}/certs" -type f \( -iname '*.crt' -o -iname '*.pem' -o -iname '*.key' \) -exec cp -f {} "${SSL_CERTIFICATES_DIR}"/ \; 2>/dev/null
  if find "${SSL_CERTIFICATES_DIR}" -maxdepth 1 -type f | read _; then
    find "${SSL_CERTIFICATES_DIR}" -type f \( -iname '*.crt' -o -iname '*.pem' \) -exec chmod 644 {} \;
    find "${SSL_CERTIFICATES_DIR}" -type f -iname '*.key' -exec chmod 400 {} \;
  fi

  CA_CERTIFICATES_PATH=${CA_CERTIFICATES_PATH:-${SSL_CERTIFICATES_DIR}/ca-certificates.pem}
  SSL_DHPARAM_PATH=${SSL_DHPARAM_PATH:-${SSL_CERTIFICATES_DIR}/dhparam.pem}

  [[ -z "$SSL_CERTIFICATE_PATH" && -f "${SSL_CERTIFICATES_DIR}/${COMPANY_NAME}.crt" ]] &&
    SSL_CERTIFICATE_PATH="${SSL_CERTIFICATES_DIR}/${COMPANY_NAME}.crt"
  SSL_CERTIFICATE_PATH="${SSL_CERTIFICATE_PATH:-${SSL_CERTIFICATES_DIR}/tls.crt}"

  [[ -z "$SSL_KEY_PATH" && -f "${SSL_CERTIFICATES_DIR}/${COMPANY_NAME}.key" ]] &&
    SSL_KEY_PATH="${SSL_CERTIFICATES_DIR}/${COMPANY_NAME}.key"
  SSL_KEY_PATH="${SSL_KEY_PATH:-${SSL_CERTIFICATES_DIR}/tls.key}"

  NODE_EXTRA_CA_CERTS=${NODE_EXTRA_CA_CERTS:-${SSL_CERTIFICATES_DIR}/extra-ca-certs.pem}
  if [[ -f ${NODE_EXTRA_CA_CERTS} ]]; then
    NODE_EXTRA_ENVIRONMENT="${NODE_EXTRA_CA_CERTS}"
  elif [[ -f ${SSL_CERTIFICATE_PATH} ]]; then
    local subj issuer
    subj=$(openssl x509 -subject -noout -in "${SSL_CERTIFICATE_PATH}" | sed 's/subject=//')
    issuer=$(openssl x509 -issuer -noout -in "${SSL_CERTIFICATE_PATH}" | sed 's/issuer=//')
    [[ "$subj" == "$issuer" ]] && NODE_EXTRA_ENVIRONMENT="${SSL_CERTIFICATE_PATH}"
  fi
  [[ -n "$NODE_EXTRA_ENVIRONMENT" ]] && sed -i "s|^environment=.*$|&,NODE_EXTRA_CA_CERTS=${NODE_EXTRA_ENVIRONMENT}|" "${SUPERVISOR_CONF_DIR}"/*.conf

  if [[ -n "${LETS_ENCRYPT_DOMAIN}" && -n "${LETS_ENCRYPT_MAIL}" ]]; then
    local letsencrypt_root="/etc/letsencrypt/live"
    SSL_CERTIFICATE_PATH=${letsencrypt_root}/${LETS_ENCRYPT_DOMAIN}/fullchain.pem
    SSL_KEY_PATH=${letsencrypt_root}/${LETS_ENCRYPT_DOMAIN}/privkey.pem
  fi
}

# Create log/lib directories, set ownership and permissions for runtime files.
init_folders(){
  for f in "${SUPERVISOR_CONF_DIR}"/ds-*.conf; do
    local d="${DS_LOG_DIR}/${f##*/ds-}"; d="${d%.conf}"
    mkdir -p "$d" && touch "$d"/{out,err}.log
  done
  mkdir -p "${DS_LOG_DIR}-example" && touch "${DS_LOG_DIR}-example"/{out,err}.log
  mkdir -p "${DS_LIB_DIR}/App_Data/cache/files" "${DS_LIB_DIR}/App_Data/docbuilder" "${DS_LIB_DIR}-example/files"

  chmod -R 755 "${DS_LOG_DIR}" "${DS_LOG_DIR}-example" "${LIB_DIR}"

  # Bug 75324: runtime.json may be owned by root after volume mount
  local ai_config="${DATA_DIR}/runtime.json"
  [ -f "${ai_config}" ] && { chown ds:ds "${ai_config}" && chmod 644 "${ai_config}"; }
}

# Run a process in the background, tracking its PID for clean_exit.
start_process() {
  "$@" &
  CHILD=$!; wait "$CHILD"; CHILD="";
}

# Graceful shutdown: terminate tracked child, run prepare4shutdown if needed.
clean_exit() {
  [[ -z "$CHILD" ]] || kill -s SIGTERM "$CHILD" 2>/dev/null
  if [ "${ONLYOFFICE_DATA_CONTAINER}" == "false" ] && [ "${ONLYOFFICE_DATA_CONTAINER_HOST}" == "localhost" ]; then
    /usr/bin/documentserver-prepare4shutdown
  fi
  exit
}

# Parse an AMQP URL of the form: scheme://[user[:pass]@]host[:port][/vhost]
# Sets AMQP_SERVER_{PROTO,HOST,USER,PASS,PORT} as side-effects.
parse_rabbitmq_url(){
  local amqp=$1
  # Groups: 1=proto  3=user  5=pass  6=host  8=port
  local re='^([a-z+]+)://(([^:@]+)(:([^@]*))?@)?([^/:]+)(:([0-9]+))?'
  [[ -z "$amqp" ]] && { echo "ERROR: empty AMQP URL"; return 1; }
  [[ $amqp =~ $re ]] || { echo "ERROR: invalid AMQP URL: $amqp"; return 1; }

  AMQP_SERVER_PROTO="${BASH_REMATCH[1]}"
  AMQP_SERVER_USER="${BASH_REMATCH[3]}"
  AMQP_SERVER_PASS="${BASH_REMATCH[5]}"
  AMQP_SERVER_HOST="${BASH_REMATCH[6]}"
  AMQP_SERVER_PORT="${BASH_REMATCH[8]:-5672}"
}

# Warn if a deprecated environment variable is still set by the user.
deprecated_var() { [[ -n ${!1} ]] && echo "Variable $1 is deprecated. Use $2 instead."; }

# Resolve all service connection settings from env or local.json defaults.
read_setting(){
  METRICS_ENABLED="${METRICS_ENABLED:-false}"
  METRICS_HOST="${METRICS_HOST:-localhost}"
  METRICS_PORT="${METRICS_PORT:-8125}"
  METRICS_PREFIX="${METRICS_PREFIX:-ds.}"
  MSSQL_TLS_PARAMS="-C"
  case "${DB_TLS_MODE,,}" in
    ""|"disable"|"require")    DB_TLS_REJECT_UNAUTHORIZED=false ;;
    "verify-ca"|"verify-full") DB_TLS_REJECT_UNAUTHORIZED=true ;;
    *) echo "ERROR: unsupported DB_TLS_MODE '${DB_TLS_MODE}'"; exit 1 ;;
  esac
  case "${REDIS_TLS_MODE,,}" in
    ""|"disable"|"require") REDIS_TLS_REJECT_UNAUTHORIZED=false ;;
    "verify-full")          REDIS_TLS_REJECT_UNAUTHORIZED=true ;;
    *) echo "ERROR: unsupported REDIS_TLS_MODE '${REDIS_TLS_MODE}'"; exit 1 ;;
  esac
  case "${AMQP_TLS_MODE,,}" in
    ""|"disable"|"require") AMQP_TLS_REJECT_UNAUTHORIZED=false ;;
    "verify-full")          AMQP_TLS_REJECT_UNAUTHORIZED=true ;;
    *) echo "ERROR: unsupported AMQP_TLS_MODE '${AMQP_TLS_MODE}'"; exit 1 ;;
  esac

  if [ "${DB_AVAILABLE}" = "true" ]; then
    deprecated_var POSTGRESQL_SERVER_HOST DB_HOST
    deprecated_var POSTGRESQL_SERVER_PORT DB_PORT
    deprecated_var POSTGRESQL_SERVER_DB_NAME DB_NAME
    deprecated_var POSTGRESQL_SERVER_USER DB_USER
    deprecated_var POSTGRESQL_SERVER_PASS DB_PWD
    DB_HOST=${DB_HOST:-${POSTGRESQL_SERVER_HOST:-$(${JSON} services.CoAuthoring.sql.dbHost)}}
    DB_TYPE=${DB_TYPE:-$(${JSON} services.CoAuthoring.sql.type)}
    declare -A _db_ports=([postgres]=5432 [mariadb]=3306 [mysql]=3306 [dameng]=5236 [mssql]=1433 [oracle]=1521)
    if [[ -n "$DB_TYPE" && -n "${_db_ports[$DB_TYPE]+x}" ]]; then
      DB_PORT=${DB_PORT:-${_db_ports[$DB_TYPE]}}
    elif [[ -z "$DB_TYPE" ]]; then
      DB_PORT=${DB_PORT:-${POSTGRESQL_SERVER_PORT:-$(${JSON} services.CoAuthoring.sql.dbPort)}}
    else
      echo "ERROR: unknown database type"; exit 1
    fi
    DB_NAME=${DB_NAME:-${POSTGRESQL_SERVER_DB_NAME:-$(${JSON} services.CoAuthoring.sql.dbName)}}
    DB_USER=${DB_USER:-${POSTGRESQL_SERVER_USER:-$(${JSON} services.CoAuthoring.sql.dbUser)}}
    DB_PWD=${DB_PWD:-${DB_PASSWORD:-${POSTGRESQL_SERVER_PASS:-$(${JSON} services.CoAuthoring.sql.dbPass)}}}
    if [ "${DB_TYPE}" = "postgres" ] && [ "${DB_HOST}" != "localhost" ] && [ -n "${DB_TLS_MODE}" ]; then
      export PGSSLMODE="${DB_TLS_MODE}"
      [ -n "${TLS_CA_CERT}" ] && export PGSSLROOTCERT="${TLS_CA_CERT}"
      [ -n "${TLS_CERT}" ] && export PGSSLCERT="${TLS_CERT}"
      [ -n "${TLS_KEY}" ] && export PGSSLKEY="${TLS_KEY}"
    fi
    if [ "${DB_TYPE}" = "mariadb" ] || [ "${DB_TYPE}" = "mysql" ]; then
      declare -A _mysql_ssl_modes=([disable]=DISABLED [require]=REQUIRED [verify-ca]=VERIFY_CA [verify-full]=VERIFY_IDENTITY)
      MYSQL_TLS_PARAMS=""
      if [ -n "${DB_TLS_MODE}" ]; then
        MYSQL_TLS_PARAMS="${_mysql_ssl_modes[${DB_TLS_MODE,,}]:+--ssl-mode=${_mysql_ssl_modes[${DB_TLS_MODE,,}]}}"
        [ -n "${TLS_CA_CERT}" ] && MYSQL_TLS_PARAMS="${MYSQL_TLS_PARAMS} --ssl-ca=${TLS_CA_CERT}"
        [ -n "${TLS_CERT}" ] && MYSQL_TLS_PARAMS="${MYSQL_TLS_PARAMS} --ssl-cert=${TLS_CERT}"
        [ -n "${TLS_KEY}" ] && MYSQL_TLS_PARAMS="${MYSQL_TLS_PARAMS} --ssl-key=${TLS_KEY}"
      fi
    fi
    if [ "${DB_TYPE}" = "mssql" ]; then
      case "${DB_TLS_MODE,,}" in
        "verify-ca"|"verify-full")
          MSSQL_TLS_PARAMS=""
          ;;
      esac
    fi
  fi

  if [ "${RABBITMQ_AVAILABLE}" = "true" ]; then
    deprecated_var RABBITMQ_SERVER_URL AMQP_URI
    deprecated_var AMQP_SERVER_URL AMQP_URI
    deprecated_var AMQP_SERVER_TYPE AMQP_TYPE
    RABBITMQ_SERVER_URL=${RABBITMQ_SERVER_URL:-$(${JSON} rabbitmq.url)}
    AMQP_URI=${AMQP_URI:-${AMQP_SERVER_URL:-${RABBITMQ_SERVER_URL}}}
    AMQP_TYPE=${AMQP_TYPE:-${AMQP_SERVER_TYPE:-rabbitmq}}
    parse_rabbitmq_url "${AMQP_URI}"
  fi

  if [ "${REDIS_AVAILABLE}" = "true" ]; then
    REDIS_SERVER_HOST=${REDIS_SERVER_HOST:-$(${JSON} services.CoAuthoring.redis.host)}
    REDIS_SERVER_PORT=${REDIS_SERVER_PORT:-6379}
  fi
}

set_json_tls_file(){
  if [ -n "$1" ]; then
    if [ ! -r "$1" ]; then
      echo "ERROR: $2 '$1' is not readable"
      exit 1
    fi
    TLS_FILE_VALUE="$(cat "$1")" ${JSON} -I -e "$3"
  fi
}

set_json_tls_files(){
  set_json_tls_file "${TLS_CA_CERT}" "$1 TLS CA certificate file" "$2"
  set_json_tls_file "${TLS_CERT}" "$1 TLS client certificate file" "$3"
  set_json_tls_file "${TLS_KEY}" "$1 TLS client private key file" "$4"
}

set_json_tls_options(){
  local reject_unauthorized=$1 service=$2 options=$3 ca_value=$4
  ${JSON} -I -e "${options} ||= {}; ${options}.rejectUnauthorized = ${reject_unauthorized}"
  set_json_tls_files "${service}" \
    "${options}.ca = ${ca_value}" \
    "${options}.cert = process.env.TLS_FILE_VALUE" \
    "${options}.key = process.env.TLS_FILE_VALUE"
}


# Block until a TCP connection to host:port succeeds, retrying every second.
waiting_for_connection(){
  until nc -z -w 3 "$1" "$2"; do >&2 echo "Waiting for $1:$2..."; sleep 1; done
}

# Wait for the database TCP port, then run Oracle-specific readiness probe if needed.
waiting_for_db(){
  waiting_for_connection "$DB_HOST" "$DB_PORT"

  # Only Oracle needs an extra readiness probe beyond the TCP connection check.
  [[ "$DB_TYPE" != "oracle" ]] && return
  local i out
  for (( i=1; i<=10; i++ )); do
    out=$(echo "SELECT version FROM V\$INSTANCE;" | sqlplus "$DB_USER/$DB_PWD@//$DB_HOST:$DB_PORT/${DB_NAME}" 2>/dev/null)
    [[ "$out" == *Connected* ]] && { echo "Database is ready"; return; }
    sleep 5
  done
  >&2 echo "WARNING: Oracle did not become ready after 50s"
}

# Write StatsD metrics config to local.json and toggle supervisor autostart.
update_statsd_settings(){
  ${JSON} -I -e "this.statsd = this.statsd || {}; \
    this.statsd.useMetrics = '${METRICS_ENABLED}'; \
    this.statsd.host = '${METRICS_HOST}'; \
    this.statsd.port = '${METRICS_PORT}'; \
    this.statsd.prefix = '${METRICS_PREFIX}'"
  sed -i -E "s/(autostart|autorestart)=.*$/\1=${METRICS_ENABLED}/g" "${SUPERVISOR_CONF_DIR}"/ds-metrics.conf
}

# Write database connection parameters to local.json.
update_db_settings(){
  ${JSON} -I -e "this.services.CoAuthoring.sql.type = '${DB_TYPE}'; \
    this.services.CoAuthoring.sql.dbHost = '${DB_HOST}'; \
    this.services.CoAuthoring.sql.dbPort = '${DB_PORT}'; \
    this.services.CoAuthoring.sql.dbName = '${DB_NAME}'; \
    this.services.CoAuthoring.sql.dbUser = '${DB_USER}'; \
    this.services.CoAuthoring.sql.dbPass = '${DB_PWD}'"

  if [ -n "${DB_TLS_MODE}" ]; then
    case "${DB_TYPE}" in
      "postgres")
        SQL_TLS_OPTIONS="this.services.CoAuthoring.sql.pgPoolExtraOptions"
        ;;
      "mariadb"|"mysql")
        SQL_TLS_OPTIONS="this.services.CoAuthoring.sql.mysqlExtraOptions"
        ;;
      "mssql")
        ;;
      *)
        echo "ERROR: database TLS settings are not supported for '${DB_TYPE}'"
        exit 1
        ;;
    esac

    if [ "${DB_TLS_MODE,,}" = "disable" ]; then
      if [ "${DB_TYPE}" = "mssql" ]; then
        ${JSON} -I -e "this.services.CoAuthoring.sql.msSqlExtraOptions ||= {}; this.services.CoAuthoring.sql.msSqlExtraOptions.options ||= {}; this.services.CoAuthoring.sql.msSqlExtraOptions.options.encrypt = false; this.services.CoAuthoring.sql.msSqlExtraOptions.options.trustServerCertificate = true; delete this.services.CoAuthoring.sql.msSqlExtraOptions.options.cryptoCredentialsDetails"
      else
        ${JSON} -I -e "if (${SQL_TLS_OPTIONS}) delete ${SQL_TLS_OPTIONS}.ssl"
      fi
    else
      if [ "${DB_TYPE}" = "mssql" ]; then
        ${JSON} -I -e "this.services.CoAuthoring.sql.msSqlExtraOptions ||= {}; \
          this.services.CoAuthoring.sql.msSqlExtraOptions.options ||= {}; \
          this.services.CoAuthoring.sql.msSqlExtraOptions.options.encrypt = true; \
          this.services.CoAuthoring.sql.msSqlExtraOptions.options.trustServerCertificate = $([ "${DB_TLS_REJECT_UNAUTHORIZED}" = "true" ] && echo false || echo true)"
        set_json_tls_files "database" \
          "this.services.CoAuthoring.sql.msSqlExtraOptions.options.cryptoCredentialsDetails ||= {}; this.services.CoAuthoring.sql.msSqlExtraOptions.options.cryptoCredentialsDetails.ca = process.env.TLS_FILE_VALUE" \
          "this.services.CoAuthoring.sql.msSqlExtraOptions.options.cryptoCredentialsDetails ||= {}; this.services.CoAuthoring.sql.msSqlExtraOptions.options.cryptoCredentialsDetails.cert = process.env.TLS_FILE_VALUE" \
          "this.services.CoAuthoring.sql.msSqlExtraOptions.options.cryptoCredentialsDetails ||= {}; this.services.CoAuthoring.sql.msSqlExtraOptions.options.cryptoCredentialsDetails.key = process.env.TLS_FILE_VALUE"
      else
        ${JSON} -I -e "${SQL_TLS_OPTIONS} ||= {}"
        set_json_tls_options "${DB_TLS_REJECT_UNAUTHORIZED}" "database" "${SQL_TLS_OPTIONS}.ssl" "process.env.TLS_FILE_VALUE"
      fi
    fi
  fi
}

# Write AMQP/RabbitMQ or ActiveMQ connection config to local.json.
update_rabbitmq_setting(){
  if [ "${AMQP_TYPE}" == "rabbitmq" ]; then
    ${JSON} -I -e "this.queue = this.queue || {}; \
      this.queue.type = 'rabbitmq'"

    if [ -n "${AMQP_TLS_MODE}" ]; then
      if [ "${AMQP_TLS_MODE,,}" = "disable" ]; then
        AMQP_URI=${AMQP_URI/amqps:\/\//amqp://}
        ${JSON} -I -e "this.rabbitmq.socketOptions = {}"
      else
        AMQP_URI=${AMQP_URI/amqp:\/\//amqps://}
        set_json_tls_options "${AMQP_TLS_REJECT_UNAUTHORIZED}" "AMQP" "this.rabbitmq.socketOptions" "[process.env.TLS_FILE_VALUE]"
      fi
    fi

    ${JSON} -I -e "this.rabbitmq.url = '${AMQP_URI}'"
  fi

  if [ "${AMQP_TYPE}" == "activemq" ]; then
    local transport_expr="delete this.activemq.connectOptions.transport"
    [[ "${AMQP_SERVER_PROTO}" == amqp+ssl || "${AMQP_SERVER_PROTO}" == amqps ]] &&
      transport_expr="this.activemq.connectOptions.transport = 'tls'"

    # Empty optional values resolve to a delete, non-empty values are assigned.
    ${JSON} -I -e "this.queue = this.queue || {}; \
      this.queue.type = 'activemq'; \
      this.activemq = this.activemq || {}; \
      this.activemq.connectOptions = this.activemq.connectOptions || {}; \
      var co = this.activemq.connectOptions; \
      co.host = '${AMQP_SERVER_HOST}'; \
      ('${AMQP_SERVER_PORT}') ? (co.port = '${AMQP_SERVER_PORT}') : (delete co.port); \
      ('${AMQP_SERVER_USER}') ? (co.username = '${AMQP_SERVER_USER}') : (delete co.username); \
      ('${AMQP_SERVER_PASS}') ? (co.password = '${AMQP_SERVER_PASS}') : (delete co.password); \
      ${transport_expr}"

    if [ -n "${AMQP_TLS_MODE}" ]; then
      if [ "${AMQP_TLS_MODE,,}" = "disable" ]; then
        ${JSON} -I -e "delete this.activemq.connectOptions.transport; \
          delete this.activemq.connectOptions.rejectUnauthorized; \
          delete this.activemq.connectOptions.ca; \
          delete this.activemq.connectOptions.cert; \
          delete this.activemq.connectOptions.key"
      else
        ${JSON} -I -e "this.activemq.connectOptions.transport = 'tls'"
        set_json_tls_options "${AMQP_TLS_REJECT_UNAUTHORIZED}" "AMQP" "this.activemq.connectOptions" "process.env.TLS_FILE_VALUE"
      fi
    fi
  fi
}

# Write Redis host, port, and auth options to local.json.
update_redis_settings(){
  local REDIS_SERVER_USER_OPT="" REDIS_SERVER_PASS_OPT="" REDIS_SERVER_DB_OPT=""
  [ -n "${REDIS_SERVER_USER}" ] && REDIS_SERVER_USER_OPT="username: '${REDIS_SERVER_USER}',"
  [ -n "${REDIS_SERVER_PASS}" ] && REDIS_SERVER_PASS_OPT="password: '${REDIS_SERVER_PASS}',"
  [ -n "${REDIS_SERVER_DB}" ]   && REDIS_SERVER_DB_OPT="database: '${REDIS_SERVER_DB}',"
  ${JSON} -I -e "this.services.CoAuthoring.redis = this.services.CoAuthoring.redis || {}; \
    this.services.CoAuthoring.redis.host = '${REDIS_SERVER_HOST}'; \
    this.services.CoAuthoring.redis.port = '${REDIS_SERVER_PORT}'; \
    this.services.CoAuthoring.redis.options = {
      ${REDIS_SERVER_USER_OPT}
      ${REDIS_SERVER_PASS_OPT}
      ${REDIS_SERVER_DB_OPT}
    }"

  if [ -n "${REDIS_TLS_MODE}" ]; then
    if [ "${REDIS_SERVER_HOST}" = "localhost" ] || [ "${REDIS_TLS_MODE,,}" = "disable" ]; then
      ${JSON} -I -e "if(this.services.CoAuthoring.redis.options) delete this.services.CoAuthoring.redis.options.socket; \
        if(this.services.CoAuthoring.redis.iooptions) delete this.services.CoAuthoring.redis.iooptions.tls; \
        if(this.services.CoAuthoring.redis.iooptionsClusterOptions) delete this.services.CoAuthoring.redis.iooptionsClusterOptions.tls"
    else
      ${JSON} -I -e "this.services.CoAuthoring.redis.options ||= {}; \
        this.services.CoAuthoring.redis.options.socket ||= {}; \
        this.services.CoAuthoring.redis.options.socket.tls = true; \
        this.services.CoAuthoring.redis.options.socket.rejectUnauthorized = ${REDIS_TLS_REJECT_UNAUTHORIZED}; \
        this.services.CoAuthoring.redis.iooptions ||= {}; \
        this.services.CoAuthoring.redis.iooptions.tls ||= {}; \
        this.services.CoAuthoring.redis.iooptions.tls.rejectUnauthorized = ${REDIS_TLS_REJECT_UNAUTHORIZED}; \
        this.services.CoAuthoring.redis.iooptionsClusterOptions ||= {}; \
        this.services.CoAuthoring.redis.iooptionsClusterOptions.tls ||= {}; \
        this.services.CoAuthoring.redis.iooptionsClusterOptions.tls.rejectUnauthorized = ${REDIS_TLS_REJECT_UNAUTHORIZED}"
      set_json_tls_files "Redis" \
        "this.services.CoAuthoring.redis.options.socket.ca = process.env.TLS_FILE_VALUE; this.services.CoAuthoring.redis.iooptions.tls.ca = process.env.TLS_FILE_VALUE; this.services.CoAuthoring.redis.iooptionsClusterOptions.tls.ca = process.env.TLS_FILE_VALUE" \
        "this.services.CoAuthoring.redis.options.socket.cert = process.env.TLS_FILE_VALUE; this.services.CoAuthoring.redis.iooptions.tls.cert = process.env.TLS_FILE_VALUE; this.services.CoAuthoring.redis.iooptionsClusterOptions.tls.cert = process.env.TLS_FILE_VALUE" \
        "this.services.CoAuthoring.redis.options.socket.key = process.env.TLS_FILE_VALUE; this.services.CoAuthoring.redis.iooptions.tls.key = process.env.TLS_FILE_VALUE; this.services.CoAuthoring.redis.iooptionsClusterOptions.tls.key = process.env.TLS_FILE_VALUE"
    fi
  fi
}

# Write JWT tokens, WOPI keys, and request-filtering-agent settings to local.json.
update_ds_settings(){
  ${JSON} -I -e "this.services.CoAuthoring.token.enable.browser = ${JWT_ENABLED}; \
    this.services.CoAuthoring.token.enable.request.inbox = ${JWT_ENABLED}; \
    this.services.CoAuthoring.token.enable.request.outbox = ${JWT_ENABLED}; \
    this.services.CoAuthoring.secret.inbox.string = '${JWT_SECRET}'; \
    this.services.CoAuthoring.secret.outbox.string = '${JWT_SECRET}'; \
    this.services.CoAuthoring.secret.session.string = '${JWT_SECRET}'; \
    this.services.CoAuthoring.secret.browser.string = '${JWT_SECRET}'; \
    this.services.CoAuthoring.token.inbox.header = '${JWT_HEADER}'; \
    this.services.CoAuthoring.token.outbox.header = '${JWT_HEADER}'; \
    this.services.CoAuthoring.token.inbox.inBody = ${JWT_IN_BODY}; \
    this.services.CoAuthoring.token.outbox.inBody = ${JWT_IN_BODY}"

  if [ -f "${ONLYOFFICE_EXAMPLE_CONFIG}" ]; then
    ${JSON_EXAMPLE} -I -e "this.server.token.enable = ${JWT_ENABLED}; \
      this.server.token.secret = '${JWT_SECRET}'; \
      this.server.token.authorizationHeader = '${JWT_HEADER}'"
  fi

  if [ "${USE_UNAUTHORIZED_STORAGE}" == "true" ]; then
    ${JSON} -I -e "this.services.CoAuthoring.requestDefaults = this.services.CoAuthoring.requestDefaults || {}; \
      if(this.services.CoAuthoring.requestDefaults.rejectUnauthorized===undefined)this.services.CoAuthoring.requestDefaults.rejectUnauthorized=false"
  fi

  WOPI_PRIVATE_KEY="${DATA_DIR}/wopi_private.key"
  WOPI_PUBLIC_KEY="${DATA_DIR}/wopi_public.key"

  [ ! -f "${WOPI_PRIVATE_KEY}" ] && echo -n "Generating WOPI private key..." && openssl genpkey -algorithm RSA -outform PEM -out "${WOPI_PRIVATE_KEY}" >/dev/null 2>&1 && echo "Done"
  [ ! -f "${WOPI_PUBLIC_KEY}" ] && echo -n "Generating WOPI public key..." && openssl rsa -RSAPublicKey_out -in "${WOPI_PRIVATE_KEY}" -outform "MS PUBLICKEYBLOB" -out "${WOPI_PUBLIC_KEY}" >/dev/null 2>&1 && echo "Done"
  WOPI_MODULUS=$(openssl rsa -pubin -inform "MS PUBLICKEYBLOB" -modulus -noout -in "${WOPI_PUBLIC_KEY}" | sed 's/Modulus=//' | xxd -r -p | openssl base64 -A)
  WOPI_EXPONENT=$(openssl rsa -pubin -inform "MS PUBLICKEYBLOB" -text -noout -in "${WOPI_PUBLIC_KEY}" | grep -oP '(?<=Exponent: )\d+')
  local wopi_private_key wopi_public_key
  wopi_private_key=$(awk '{printf "%s\\n", $0}' "${WOPI_PRIVATE_KEY}")
  wopi_public_key=$(openssl base64 -in "${WOPI_PUBLIC_KEY}" -A)

  ${JSON} -I -e "this.wopi = this.wopi || {}; \
    this.wopi.enable = ${WOPI_ENABLED}; \
    this.wopi.privateKey = '${wopi_private_key}'; \
    this.wopi.privateKeyOld = '${wopi_private_key}'; \
    this.wopi.publicKey = '${wopi_public_key}'; \
    this.wopi.publicKeyOld = '${wopi_public_key}'; \
    this.wopi.modulus = '${WOPI_MODULUS}'; \
    this.wopi.modulusOld = '${WOPI_MODULUS}'; \
    this.wopi.exponent = ${WOPI_EXPONENT}; \
    this.wopi.exponentOld = ${WOPI_EXPONENT}"

  if [ "${ALLOW_META_IP_ADDRESS}" = "true" ] || [ "${ALLOW_PRIVATE_IP_ADDRESS}" = "true" ]; then
    local rfa_expr="this.services.CoAuthoring['request-filtering-agent'] = this.services.CoAuthoring['request-filtering-agent'] || {};"
    [ "${ALLOW_META_IP_ADDRESS}" = "true" ] && rfa_expr+=" this.services.CoAuthoring['request-filtering-agent'].allowMetaIPAddress = true;"
    [ "${ALLOW_PRIVATE_IP_ADDRESS}" = "true" ] && rfa_expr+=" this.services.CoAuthoring['request-filtering-agent'].allowPrivateIPAddress = true;"
    ${JSON} -I -e "${rfa_expr}"
  fi

  ${JSON_LOG} -I -e "this.categories.default.level = '${DS_LOG_LEVEL:-$(${JSON_LOG} categories.default.level)}'"
}

# Initialize a fresh PostgreSQL cluster, preserving original config backups.
create_postgresql_cluster(){
  local pg_conf_dir=/etc/postgresql/${PG_VERSION}/${PG_NAME}
  local postgresql_conf=$pg_conf_dir/postgresql.conf
  local hba_conf=$pg_conf_dir/pg_hba.conf

  mv "$postgresql_conf" "$postgresql_conf".backup
  mv "$hba_conf" "$hba_conf".backup

  pg_createcluster "${PG_VERSION}" "${PG_NAME}"
}

# Create the application PostgreSQL user and database.
create_postgresql_db(){
  # Pass the password as a psql variable so special characters are quoted safely.
  # The statement goes via stdin because psql does not interpolate :'var' in -c strings.
  sudo -u postgres psql -v pwd="$DB_PWD" <<< "CREATE USER $DB_USER WITH password :'pwd';"
  sudo -u postgres psql -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;"
}

# Dispatch schema create/upgrade to the correct per-backend function.
run_db_tbl() {
  local operation=$1
  declare -A _tbl_fn=([postgres]=postgresql_tbl [mariadb]=mysql_tbl [mysql]=mysql_tbl [mssql]=mssql_tbl [oracle]=oracle_tbl)
  [[ -n "$DB_TYPE" && -n "${_tbl_fn[$DB_TYPE]+x}" ]] && "${_tbl_fn[$DB_TYPE]}" "$operation"
}

# Execute an Oracle SQL script file via sqlplus.
run_oracle_sql_file() {
  local sql_file="$1"
  local conn="$DB_USER/$DB_PWD@//$DB_HOST:$DB_PORT/$DB_NAME"
  printf '@"%s"\nexit\n' "$sql_file" | sqlplus -s -L "$conn" >/dev/null 2>&1
}

# Apply PostgreSQL schema; creates schema namespace if DB_SCHEMA is set.
postgresql_tbl() {
  local operation=$1
  [ -n "$DB_PWD" ] && export PGPASSWORD="$DB_PWD"
  PSQL="psql -q -h$DB_HOST -p$DB_PORT -d$DB_NAME -U$DB_USER -w"
  DB_SCHEMA=${DB_SCHEMA:-$(${JSON} services.CoAuthoring.sql.pgPoolExtraOptions.options 2>/dev/null | sed -n 's/.*search_path=\([^, ]*\).*/\1/p')}
  if [ -n "${DB_SCHEMA}" ]; then
    export PGOPTIONS="-c search_path=${DB_SCHEMA}"
    $PSQL -c "CREATE SCHEMA IF NOT EXISTS ${DB_SCHEMA};" >/dev/null 2>&1
    ${JSON} -I -e "this.services.CoAuthoring.sql.pgPoolExtraOptions ||= {}; this.services.CoAuthoring.sql.pgPoolExtraOptions.options = '${PGOPTIONS}'"
  fi
  [ "$operation" = "upgrade" ] && $PSQL -f "$APP_DIR/server/schema/postgresql/removetbl.sql"
  $PSQL -f "$APP_DIR/server/schema/postgresql/createdb.sql"
}

# Apply MySQL/MariaDB schema; creates database if operation is "create".
mysql_tbl() {
  local operation=$1
  MYSQL="mysql -q -h$DB_HOST -P$DB_PORT -u$DB_USER -p$DB_PWD -w ${MYSQL_TLS_PARAMS}"
  if [ "$operation" = "create" ]; then
    $MYSQL -e "CREATE DATABASE IF NOT EXISTS $DB_NAME DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_general_ci;" >/dev/null 2>&1
  else
    $MYSQL "$DB_NAME" < "$APP_DIR/server/schema/mysql/removetbl.sql" >/dev/null 2>&1
  fi
  $MYSQL "$DB_NAME" < "$APP_DIR/server/schema/mysql/createdb.sql" >/dev/null 2>&1
}

# Apply MSSQL schema; creates database and schema if needed.
mssql_tbl() {
  local operation=$1
  [ -n "$DB_PWD" ] && export SQLCMDPASSWORD="$DB_PWD"
  MSSQL="/opt/mssql-tools18/bin/sqlcmd -S $DB_HOST,$DB_PORT -d $DB_NAME -U $DB_USER ${MSSQL_TLS_PARAMS}"
  [ "$operation" = "create" ] && ${MSSQL/ -d $DB_NAME/} -b -Q "IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = '$DB_NAME') BEGIN CREATE DATABASE [$DB_NAME]; END"
  if [ -n "${DB_SCHEMA}" ]; then
    ${MSSQL} -b -Q "DECLARE @s sysname=N'${DB_SCHEMA}'; IF SCHEMA_ID(@s) IS NULL BEGIN DECLARE @sql nvarchar(max); SET @sql=N'CREATE SCHEMA '+QUOTENAME(@s)+N' AUTHORIZATION '+QUOTENAME(N'${DB_USER}'); EXEC(@sql); END"
    ${MSSQL} -b -Q "DECLARE @s sysname=N'${DB_SCHEMA}'; DECLARE @u sysname=N'${DB_USER}'; IF USER_ID(@u) IS NOT NULL BEGIN DECLARE @sql nvarchar(max); SET @sql=N'ALTER USER '+QUOTENAME(@u)+N' WITH DEFAULT_SCHEMA = '+QUOTENAME(@s); EXEC(@sql); END"
  fi
  [ "$operation" = "upgrade" ] && $MSSQL < "$APP_DIR/server/schema/mssql/removetbl.sql" >/dev/null 2>&1
  $MSSQL < "$APP_DIR/server/schema/mssql/createdb.sql" >/dev/null 2>&1
}

# Apply Oracle schema via sqlplus.
oracle_tbl() {
  local operation=$1
  [ "$operation" = "upgrade" ] && run_oracle_sql_file "$APP_DIR/server/schema/oracle/removetbl.sql"
  run_oracle_sql_file "$APP_DIR/server/schema/oracle/createdb.sql"
}

# Patch welcome and disabled-page HTML to replace docker container placeholder.
update_welcome_page() {
  INDEX_PAGE="${APP_DIR}-example/welcome/index.html"
  WELCOME_PAGE="${APP_DIR}-example/welcome/docker.html"
  EXAMPLE_DISABLED_PAGE="${APP_DIR}-example/welcome/example-disabled.html"
  sed -Ei 's/(data-platform=")[^"]*/\1docker/' "$INDEX_PAGE"
  if ${ADMINPANEL_AVAILABLE}; then
    ADMIN_DISABLED_PAGE="${APP_DIR}-example/welcome/admin-disabled.html"
    sed -Ei 's#sudo systemctl start ds-(adminpanel|example)#sudo docker exec $(sudo docker ps -q) supervisorctl start ds:\1#g' "$ADMIN_DISABLED_PAGE" "$EXAMPLE_DISABLED_PAGE"
  else
    sed -Ei 's#sudo systemctl start ds-example#sudo docker exec $(sudo docker ps -q) supervisorctl start ds:example#g' "$EXAMPLE_DISABLED_PAGE"
  fi

  TARGET_PAGES="$INDEX_PAGE $WELCOME_PAGE $EXAMPLE_DISABLED_PAGE ${ADMIN_DISABLED_PAGE:+$ADMIN_DISABLED_PAGE}"
  if [[ -e $WELCOME_PAGE ]]; then
    [ -r /proc/1/cpuset ] && DOCKER_CONTAINER_ID=$(basename "$(</proc/1/cpuset)") || DOCKER_CONTAINER_ID=""
    (( ${#DOCKER_CONTAINER_ID} < 12 )) && DOCKER_CONTAINER_ID=$(hostname)
    if (( ${#DOCKER_CONTAINER_ID} >= 12 )); then
      if [[ -x $(command -v docker) ]]; then
        DOCKER_CONTAINER_NAME=$(docker inspect --format="{{.Name}}" $DOCKER_CONTAINER_ID)
        sed 's/$(sudo docker ps -q)/'"${DOCKER_CONTAINER_NAME#/}"'/' -i ${TARGET_PAGES}
        JWT_MESSAGE=$(echo "$JWT_MESSAGE" | sed 's/$(sudo docker ps -q)/'"${DOCKER_CONTAINER_NAME#/}"'/')
      else
        sed 's/$(sudo docker ps -q)/'"${DOCKER_CONTAINER_ID::12}"'/' -i ${TARGET_PAGES}
        JWT_MESSAGE=$(echo "$JWT_MESSAGE" | sed 's/$(sudo docker ps -q)/'"${DOCKER_CONTAINER_ID::12}"'/')
      fi
    fi
  fi
}

# Configure nginx workers, access log, SSL/HTTPS, IPv6 and securelink.
update_nginx_settings(){
  # Worker and connection limits.
  sed -i "${NGINX_CONFIG_PATH}" \
    -e "s/^worker_processes.*/worker_processes ${NGINX_WORKER_PROCESSES};/" \
    -e "s/worker_connections.*/worker_connections ${NGINX_WORKER_CONNECTIONS};/"

  # Access logging.
  sed -ri 's|^\s*(access_log)\b.*;|\1 off;|' "${NGINX_CONFIG_PATH}"
  if [ "${NGINX_ACCESS_LOG}" != "true" ]; then
    sed -ri 's|^\s*(access_log)\b.*;|\1 off;|' \
      "${NGINX_ONLYOFFICE_PATH}/includes/ds-common.conf" \
      "${NGINX_ONLYOFFICE_PATH}/ds-ssl.conf.tmpl" 2>/dev/null
  fi

  # SSL/HTTPS setup.
  if [[ -f "${SSL_CERTIFICATE_PATH}" && -f "${SSL_KEY_PATH}" ]]; then
    cp -f "${NGINX_ONLYOFFICE_PATH}/ds-ssl.conf.tmpl" "${NGINX_ONLYOFFICE_CONF}"
    sed -i "${NGINX_ONLYOFFICE_CONF}" \
      -e "s,{{SSL_CERTIFICATE_PATH}},${SSL_CERTIFICATE_PATH}," \
      -e "s,{{SSL_KEY_PATH}},${SSL_KEY_PATH}," \
      -e "s,\(ssl_verify_client \).*\(;\)$,\1${SSL_VERIFY_CLIENT}\2,"

    if [ -r "${SSL_DHPARAM_PATH}" ]; then
      sed -i "s,\(\#* *\)\?\(ssl_dhparam \).*\(;\)$,\2${SSL_DHPARAM_PATH}\3," "${NGINX_ONLYOFFICE_CONF}"
    else
      sed -i '/ssl_dhparam/d' "${NGINX_ONLYOFFICE_CONF}"
    fi
    if [ "${ONLYOFFICE_HTTPS_HSTS_ENABLED}" == "true" ]; then
      sed -i "s,\(max-age=\).*\(;\)$,\1${ONLYOFFICE_HTTPS_HSTS_MAXAGE}\2," "${NGINX_ONLYOFFICE_CONF}"
    else
      sed -i '/max-age=/d' "${NGINX_ONLYOFFICE_CONF}"
    fi
    [ -f "${CA_CERTIFICATES_PATH}" ] && \
      sed -i "/ssl_verify_client/a ssl_client_certificate ${CA_CERTIFICATES_PATH};" "${NGINX_ONLYOFFICE_CONF}"
  else
    ln -sf "${NGINX_ONLYOFFICE_PATH}/ds.conf.tmpl" "${NGINX_ONLYOFFICE_CONF}"
  fi

  [ ! -f /proc/net/if_inet6 ] && sed -i '/listen\s\+\[::[0-9]*\].\+/d' "${NGINX_ONLYOFFICE_CONF}"

  start_process documentserver-update-securelink \
    -s "${SECURE_LINK_SECRET:-$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 20)}" -r false
}

# Set up database: configure remote or initialize local PostgreSQL.
setup_db(){
  if [ "$DB_HOST" != "localhost" ]; then
    update_db_settings; waiting_for_db; run_db_tbl create
  else
    chown -R postgres:postgres "${PG_ROOT}"; chmod -R 700 ${PG_ROOT}
    if [ ! -d "${PGDATA}" ]; then create_postgresql_cluster; PG_NEW_CLUSTER=true; fi
    LOCAL_SERVICES+=("postgresql")
  fi
}

# Set up RabbitMQ: configure remote or initialize local broker.
setup_rabbitmq(){
  if [ "${AMQP_SERVER_HOST}" != "localhost" ]; then
    update_rabbitmq_setting
  else
    chown -R rabbitmq:rabbitmq "${RABBITMQ_DATA}"; chmod -R go=rX,u=rwX "${RABBITMQ_DATA}"
    [ -f "${RABBITMQ_DATA}"/.erlang.cookie ] && chmod 400 "${RABBITMQ_DATA}"/.erlang.cookie
    sed -i '/^[[:space:]]*ulimit[[:space:]]\+-n[[:space:]]\+/d' /etc/default/rabbitmq-server
    printf 'ulimit -n %s\n' "${RABBIT_CONNECTIONS}" >> /etc/default/rabbitmq-server
    LOCAL_SERVICES+=("rabbitmq-server"); rm -rf /var/run/rabbitmq
  fi
}

# Set up Redis: configure remote, or generate a password and initialize local instance.
setup_redis(){
  if [ "${REDIS_SERVER_HOST}" != "localhost" ]; then
    update_redis_settings
  else
    local redis_pass_file="${REDIS_DATA}/.redis_pass"
    REDIS_SERVER_PASS=${REDIS_SERVER_PASS:-$(cat "${redis_pass_file}" 2>/dev/null)}
    REDIS_SERVER_PASS=${REDIS_SERVER_PASS:-$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 16)}
    printf '%s' "${REDIS_SERVER_PASS}" > "${redis_pass_file}"
    sed -i '/^[[:space:]]*#\?[[:space:]]*requirepass\b/d; /^[[:space:]]*#\?[[:space:]]*protected-mode\b/d' /etc/redis/redis.conf
    printf 'requirepass %s\nprotected-mode yes\n' "${REDIS_SERVER_PASS}" >> /etc/redis/redis.conf
    update_redis_settings
    chown -R redis:redis "${REDIS_DATA}"; chmod -R 750 "${REDIS_DATA}"; chmod 600 "${redis_pass_file}"
    LOCAL_SERVICES+=("redis-server")
  fi
}

# Create PostgreSQL database and schema if cluster is new or database is missing.
init_postgresql_db(){
  [ "${DB_TYPE}" = "postgres" ] || return
  local pg_db_exists
  pg_db_exists=$(PGPASSWORD="$DB_PWD" psql -h "${DB_HOST}" -p"${DB_PORT}" -U "${DB_USER}" -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}';" 2>/dev/null)
  if [ "${PG_NEW_CLUSTER}" = "true" ] || [ "${pg_db_exists}" != "1" ]; then
    create_postgresql_db
    run_db_tbl create
  fi
}

# Allow logrotate to run as root when invoked via cron.
update_logrotate_settings(){
  sed 's|\(^su\b\).*|\1 root root|' -i /etc/logrotate.conf
}

# Persist the current release date so the next start can detect upgrades.
update_release_date(){
  mkdir -p "${PRIVATE_DATA_DIR}" && echo "${RELEASE_DATE}" > "${DS_RELEASE_DATE}"
}

# Enable optional supervisor services based on environment flags.
# Adminpanel autostarts by default; set ADMINPANEL_ENABLED=false to opt out.
configure_autostart(){
  ${ADMINPANEL_AVAILABLE} && [ "${ADMINPANEL_ENABLED:-true}" = "false" ] && \
    sed -i 's,\(autostart=\)true,\1false,' "${SUPERVISOR_CONF_DIR}"/ds-adminpanel.conf
  [ "${EXAMPLE_ENABLED:-false}" = "true" ] && \
    sed -i 's,\(autostart=\)false,\1true,' "${SUPERVISOR_CONF_DIR}"/ds-example.conf
}

# --------------------------- End of function definitions; execution starts below. ---------------------------

trap clean_exit SIGTERM SIGQUIT SIGABRT SIGINT # Graceful shutdown on any termination signal.

# Initialize variables, SSL certificates, and filesystem layout.
init_config
init_ssl
init_folders

# Configure services: apply settings locally or wait for remote data container.
if [ "${ONLYOFFICE_DATA_CONTAINER_HOST}" = "localhost" ]; then
  read_setting
  update_welcome_page
  update_ds_settings
  [ "${DB_AVAILABLE}" = "true" ]       && setup_db
  [ "${RABBITMQ_AVAILABLE}" = "true" ] && setup_rabbitmq
  [ "${REDIS_AVAILABLE}" = "true" ]    && setup_redis
  [ "${METRICS_ENABLED}" = "true" ]    && update_statsd_settings
else
  waiting_for_connection "${ONLYOFFICE_DATA_CONTAINER_HOST}" "${ONLYOFFICE_DATA_CONTAINER_PORT}"
  read_setting
  update_welcome_page
fi

# Start bundled local services (postgresql, rabbitmq, redis if running in-container).
for SVC in "${LOCAL_SERVICES[@]}"; do service "$SVC" start; done

# Create PostgreSQL database and schema if this is a new or missing database.
[ "${DB_AVAILABLE}" = "true" ] && init_postgresql_db

chown ds:ds "${DATA_DIR}"
chown -R ds:ds "${DS_LOG_DIR}" "${DS_LOG_DIR}-example" "${LIB_DIR}"
find "/etc/${COMPANY_NAME}" ! -path '*logrotate*' -exec chown ds:ds {} +

# Full startup: only runs in non-data-container mode.
if [ "${ONLYOFFICE_DATA_CONTAINER}" != "true" ]; then
  # Start plugin manager in background before waiting for services.
  [ "${PLUGINS_ENABLED}" = "true" ] && { documentserver-pluginsmanager -r false --update="${APP_DIR}/sdkjs-plugins/plugin-list-default.json" >/dev/null & PLUGINSMANAGER_PID=$!; }

  # Wait for external services to become ready.
  [ "${DB_AVAILABLE}" = "true" ]       && { waiting_for_db; [ "${IS_UPGRADE}" = "true" ] && run_db_tbl upgrade; }
  [ "${RABBITMQ_AVAILABLE}" = "true" ] && waiting_for_connection "${AMQP_SERVER_HOST}" "${AMQP_SERVER_PORT}"
  [ "${REDIS_AVAILABLE}" = "true" ]    && waiting_for_connection "${REDIS_SERVER_HOST}" "${REDIS_SERVER_PORT}"
  [ "${IS_UPGRADE}" = "true" ]       && update_release_date

  # Apply nginx configuration (SSL, workers, access log, securelink).
  update_nginx_settings

  # Enable optional supervisor services and start supervisor and cron.
  configure_autostart
  ${ADMINPANEL_AVAILABLE} && tail -n 0 -F "$DS_LOG_DIR/adminpanel/out.log" &
  service supervisor start
  update_logrotate_settings
  service cron start
fi

# nginx runs in all modes: as a proxy and as a data-container health endpoint.
start_process documentserver-flush-cache -r false
service nginx start

# Obtain or renew Let's Encrypt certificate if domain is configured.
if [[ -n "${LETS_ENCRYPT_DOMAIN}" && -n "${LETS_ENCRYPT_MAIL}" ]]; then
  if [[ ! -f "${SSL_CERTIFICATE_PATH}" && ! -f "${SSL_KEY_PATH}" ]]; then
    start_process documentserver-letsencrypt "${LETS_ENCRYPT_MAIL}" "${LETS_ENCRYPT_DOMAIN}"
  fi
fi

# Background tasks: font generation, static gzip, log tailing.
if [ ! -s "${APP_DIR}/sdkjs/common/AllFonts.js" ]; then
  GENERATE_FONTS=true
fi
[ "${GENERATE_FONTS}" == "true" ] && start_process documentserver-generate-allfonts "${ONLYOFFICE_DATA_CONTAINER}"

echo "${JWT_MESSAGE}"

[ -n "${PLUGINSMANAGER_PID}" ] && { wait "${PLUGINSMANAGER_PID}"; echo "[pluginsmanager] Plugins initialization finished"; }

start_process bash -c "find '$DS_LOG_DIR' '$DS_LOG_DIR-example' -type f -name '*.log' ! -path '$DS_LOG_DIR/adminpanel/out.log' | xargs tail -F"
