#!/bin/bash

# Define '**' behavior explicitly
shopt -s globstar

APP_DIR="/var/www/onlyoffice/documentserver"
DATA_DIR="/var/www/onlyoffice/Data"
LOG_DIR="/var/log/onlyoffice"
DS_LOG_DIR="${LOG_DIR}/documentserver"
LIB_DIR="/var/lib/onlyoffice"
DS_LIB_DIR="${LIB_DIR}/documentserver"
CONF_DIR="/etc/onlyoffice/documentserver"

ONLYOFFICE_DATA_CONTAINER=${ONLYOFFICE_DATA_CONTAINER:-false}
ONLYOFFICE_DATA_CONTAINER_HOST=${ONLYOFFICE_DATA_CONTAINER_HOST:-localhost}
ONLYOFFICE_DATA_CONTAINER_PORT=80

SSL_CERTIFICATES_DIR="${DATA_DIR}/certs"
SSL_CERTIFICATE_PATH=${SSL_CERTIFICATE_PATH:-${SSL_CERTIFICATES_DIR}/onlyoffice.crt}
SSL_KEY_PATH=${SSL_KEY_PATH:-${SSL_CERTIFICATES_DIR}/onlyoffice.key}
CA_CERTIFICATES_PATH=${CA_CERTIFICATES_PATH:-${SSL_CERTIFICATES_DIR}/ca-certificates.pem}
SSL_DHPARAM_PATH=${SSL_DHPARAM_PATH:-${SSL_CERTIFICATES_DIR}/dhparam.pem}
SSL_VERIFY_CLIENT=${SSL_VERIFY_CLIENT:-off}
SSL_SELFSIGNED_CERTIFICATE=${SSL_SELFSIGNED_CERTIFICATE:-false}
ONLYOFFICE_HTTPS_HSTS_ENABLED=${ONLYOFFICE_HTTPS_HSTS_ENABLED:-true}
ONLYOFFICE_HTTPS_HSTS_MAXAGE=${ONLYOFFICE_HTTPS_HSTS_MAXAGE:-31536000}
SYSCONF_TEMPLATES_DIR="/app/onlyoffice/setup/config"

NGINX_CONFD_PATH="/etc/nginx/conf.d";
NGINX_ONLYOFFICE_PATH="${CONF_DIR}/nginx"
NGINX_ONLYOFFICE_CONF="${NGINX_ONLYOFFICE_PATH}/ds.conf"
NGINX_ONLYOFFICE_EXAMPLE_PATH="${CONF_DIR}-example/nginx"
NGINX_ONLYOFFICE_EXAMPLE_CONF="${NGINX_ONLYOFFICE_EXAMPLE_PATH}/includes/ds-example.conf"

NGINX_CONFIG_PATH="/etc/nginx/nginx.conf"
NGINX_WORKER_PROCESSES=${NGINX_WORKER_PROCESSES:-1}
NGINX_WORKER_CONNECTIONS=${NGINX_WORKER_CONNECTIONS:-$(ulimit -n)}

JWT_ENABLED=${JWT_ENABLED:-false}
JWT_SECRET=${JWT_SECRET:-secret}
JWT_HEADER=${JWT_HEADER:-Authorization}

ONLYOFFICE_DEFAULT_CONFIG=${CONF_DIR}/local.json
ONLYOFFICE_LOG4JS_CONFIG=${CONF_DIR}/log4js/production.json
ONLYOFFICE_EXAMPLE_CONFIG=${CONF_DIR}-example/local.json

JSON_BIN=${APP_DIR}/npm/node_modules/.bin/json
JSON="${JSON_BIN} -q -f ${ONLYOFFICE_DEFAULT_CONFIG}"
JSON_LOG="${JSON_BIN} -q -f ${ONLYOFFICE_LOG4JS_CONFIG}"
JSON_EXAMPLE="${JSON_BIN} -q -f ${ONLYOFFICE_EXAMPLE_CONFIG}"

LOCAL_SERVICES=()

PG_ROOT=/var/lib/postgresql
PG_VERSION=9.5
PG_NAME=main
PGDATA=${PG_ROOT}/${PG_VERSION}/${PG_NAME}
PG_NEW_CLUSTER=false

read_setting(){
  POSTGRESQL_SERVER_HOST=${POSTGRESQL_SERVER_HOST:-$(${JSON} services.CoAuthoring.sql.dbHost)}
  POSTGRESQL_SERVER_PORT=${POSTGRESQL_SERVER_PORT:-5432}
  POSTGRESQL_SERVER_DB_NAME=${POSTGRESQL_SERVER_DB_NAME:-$(${JSON} services.CoAuthoring.sql.dbName)}
  POSTGRESQL_SERVER_USER=${POSTGRESQL_SERVER_USER:-$(${JSON} services.CoAuthoring.sql.dbUser)}
  POSTGRESQL_SERVER_PASS=${POSTGRESQL_SERVER_PASS:-$(${JSON} services.CoAuthoring.sql.dbPass)}

  RABBITMQ_SERVER_URL=${RABBITMQ_SERVER_URL:-$(${JSON} rabbitmq.url)}
  AMQP_SERVER_URL=${AMQP_SERVER_URL:-${RABBITMQ_SERVER_URL}}
  AMQP_SERVER_TYPE=${AMQP_SERVER_TYPE:-rabbitmq}
  parse_rabbitmq_url ${AMQP_SERVER_URL}

  REDIS_SERVER_HOST=${REDIS_SERVER_HOST:-$(${JSON} services.CoAuthoring.redis.host)}
  REDIS_SERVER_PORT=${REDIS_SERVER_PORT:-6379}

  DS_LOG_LEVEL=${DS_LOG_LEVEL:-$(${JSON_LOG} categories.default.level)}
}

parse_rabbitmq_url(){
  local amqp=$1

  # extract the protocol
  local proto="$(echo $amqp | grep :// | sed -e's,^\(.*://\).*,\1,g')"
  # remove the protocol
  local url="$(echo ${amqp/$proto/})"

  # extract the user and password (if any)
  local userpass="`echo $url | grep @ | cut -d@ -f1`"
  local pass=`echo $userpass | grep : | cut -d: -f2`

  local user
  if [ -n "$pass" ]; then
    user=`echo $userpass | grep : | cut -d: -f1`
  else
    user=$userpass
  fi

  # extract the host
  local hostport="$(echo ${url/$userpass@/} | cut -d/ -f1)"
  # by request - try to extract the port
  local port="$(echo $hostport | sed -e 's,^.*:,:,g' -e 's,.*:\([0-9]*\).*,\1,g' -e 's,[^0-9],,g')"

  local host
  if [ -n "$port" ]; then
    host=`echo $hostport | grep : | cut -d: -f1`
  else
    host=$hostport
    port="5672"
  fi

  # extract the path (if any)
  local path="$(echo $url | grep / | cut -d/ -f2-)"

  AMQP_SERVER_PROTO=${proto:0:-3}
  AMQP_SERVER_HOST=$host
  AMQP_SERVER_USER=$user
  AMQP_SERVER_PASS=$pass
  AMQP_SERVER_PORT=$port
}

waiting_for_connection(){
  until nc -z -w 3 "$1" "$2"; do
    >&2 echo "Waiting for connection to the $1 host on port $2"
    sleep 1
  done
}

waiting_for_postgresql(){
  waiting_for_connection ${POSTGRESQL_SERVER_HOST} ${POSTGRESQL_SERVER_PORT}
}

waiting_for_amqp(){
  waiting_for_connection ${AMQP_SERVER_HOST} ${AMQP_SERVER_PORT}
}

waiting_for_redis(){
  waiting_for_connection ${REDIS_SERVER_HOST} ${REDIS_SERVER_PORT}
}
waiting_for_datacontainer(){
  waiting_for_connection ${ONLYOFFICE_DATA_CONTAINER_HOST} ${ONLYOFFICE_DATA_CONTAINER_PORT}
}
update_postgresql_settings(){
  ${JSON} -I -e "this.services.CoAuthoring.sql.dbHost = '${POSTGRESQL_SERVER_HOST}'"
  ${JSON} -I -e "this.services.CoAuthoring.sql.dbPort = '${POSTGRESQL_SERVER_PORT}'"
  ${JSON} -I -e "this.services.CoAuthoring.sql.dbName = '${POSTGRESQL_SERVER_DB_NAME}'"
  ${JSON} -I -e "this.services.CoAuthoring.sql.dbUser = '${POSTGRESQL_SERVER_USER}'"
  ${JSON} -I -e "this.services.CoAuthoring.sql.dbPass = '${POSTGRESQL_SERVER_PASS}'"
}

update_rabbitmq_setting(){
  if [ "${AMQP_SERVER_TYPE}" == "rabbitmq" ]; then
    ${JSON} -I -e "if(this.queue===undefined)this.queue={};"
    ${JSON} -I -e "this.queue.type = 'rabbitmq'"
    ${JSON} -I -e "this.rabbitmq.url = '${AMQP_SERVER_URL}'"
  fi
  
  if [ "${AMQP_SERVER_TYPE}" == "activemq" ]; then
    ${JSON} -I -e "if(this.queue===undefined)this.queue={};"
    ${JSON} -I -e "this.queue.type = 'activemq'"
    ${JSON} -I -e "if(this.activemq===undefined)this.activemq={};"
    ${JSON} -I -e "if(this.activemq.connectOptions===undefined)this.activemq.connectOptions={};"

    ${JSON} -I -e "this.activemq.connectOptions.host = '${AMQP_SERVER_HOST}'"

    if [ ! "${AMQP_SERVER_PORT}" == "" ]; then
      ${JSON} -I -e "this.activemq.connectOptions.port = '${AMQP_SERVER_PORT}'"
    else
      ${JSON} -I -e "delete this.activemq.connectOptions.port"
    fi

    if [ ! "${AMQP_SERVER_USER}" == "" ]; then
      ${JSON} -I -e "this.activemq.connectOptions.username = '${AMQP_SERVER_USER}'"
    else
      ${JSON} -I -e "delete this.activemq.connectOptions.username"
    fi

    if [ ! "${AMQP_SERVER_PASS}" == "" ]; then
      ${JSON} -I -e "this.activemq.connectOptions.password = '${AMQP_SERVER_PASS}'"
    else
      ${JSON} -I -e "delete this.activemq.connectOptions.password"
    fi

    case "${AMQP_SERVER_PROTO}" in
      amqp+ssl|amqps)
        ${JSON} -I -e "this.activemq.connectOptions.transport = 'tls'"
        ;;
      *)
        ${JSON} -I -e "delete this.activemq.connectOptions.transport"
        ;;
    esac 
  fi
}

update_redis_settings(){
  ${JSON} -I -e "this.services.CoAuthoring.redis.host = '${REDIS_SERVER_HOST}'"
  ${JSON} -I -e "this.services.CoAuthoring.redis.port = '${REDIS_SERVER_PORT}'"
}

update_jwt_settings(){
  if [ "${JWT_ENABLED}" == "true" ]; then
    ${JSON} -I -e "this.services.CoAuthoring.token.enable.browser = ${JWT_ENABLED}"
    ${JSON} -I -e "this.services.CoAuthoring.token.enable.request.inbox = ${JWT_ENABLED}"
    ${JSON} -I -e "this.services.CoAuthoring.token.enable.request.outbox = ${JWT_ENABLED}"

    ${JSON} -I -e "this.services.CoAuthoring.secret.inbox.string = '${JWT_SECRET}'"
    ${JSON} -I -e "this.services.CoAuthoring.secret.outbox.string = '${JWT_SECRET}'"
    ${JSON} -I -e "this.services.CoAuthoring.secret.session.string = '${JWT_SECRET}'"

    ${JSON} -I -e "this.services.CoAuthoring.token.inbox.header = '${JWT_HEADER}'"
    ${JSON} -I -e "this.services.CoAuthoring.token.outbox.header = '${JWT_HEADER}'"

    if [ -f "${ONLYOFFICE_EXAMPLE_CONFIG}" ] && [ "${JWT_ENABLED}" == "true" ]; then
      ${JSON_EXAMPLE} -I -e "this.server.token.enable = ${JWT_ENABLED}"
      ${JSON_EXAMPLE} -I -e "this.server.token.secret = '${JWT_SECRET}'"
      ${JSON_EXAMPLE} -I -e "this.server.token.authorizationHeader = '${JWT_HEADER}'"
    fi
  fi
}

create_postgresql_cluster(){
  local pg_conf_dir=/etc/postgresql/${PG_VERSION}/${PG_NAME}
  local postgresql_conf=$pg_conf_dir/postgresql.conf
  local hba_conf=$pg_conf_dir/pg_hba.conf

  mv $postgresql_conf $postgresql_conf.backup
  mv $hba_conf $hba_conf.backup

  pg_createcluster ${PG_VERSION} ${PG_NAME}
}

create_postgresql_db(){
  sudo -u postgres psql -c "CREATE DATABASE onlyoffice;"
  sudo -u postgres psql -c "CREATE USER onlyoffice WITH password 'onlyoffice';"
  sudo -u postgres psql -c "GRANT ALL privileges ON DATABASE onlyoffice TO onlyoffice;"
}

create_postgresql_tbl(){
  CONNECTION_PARAMS="-h${POSTGRESQL_SERVER_HOST} -p${POSTGRESQL_SERVER_PORT} -U${POSTGRESQL_SERVER_USER} -w"
  if [ -n "${POSTGRESQL_SERVER_PASS}" ]; then
    export PGPASSWORD=${POSTGRESQL_SERVER_PASS}
  fi

  PSQL="psql -q $CONNECTION_PARAMS"
  CREATEDB="createdb $CONNECTION_PARAMS"

  # Create db on remote server
  if $PSQL -lt | cut -d\| -f 1 | grep -qw | grep 0; then
    $CREATEDB $POSTGRESQL_SERVER_DB_NAME
  fi

  $PSQL -d "${POSTGRESQL_SERVER_DB_NAME}" -f "${APP_DIR}/server/schema/postgresql/createdb.sql"
}

update_nginx_settings(){
  # Set up nginx
  sed 's/^worker_processes.*/'"worker_processes ${NGINX_WORKER_PROCESSES};"'/' -i ${NGINX_CONFIG_PATH}
  sed 's/worker_connections.*/'"worker_connections ${NGINX_WORKER_CONNECTIONS};"'/' -i ${NGINX_CONFIG_PATH}
  sed 's/access_log.*/'"access_log off;"'/' -i ${NGINX_CONFIG_PATH}

  # setup HTTPS
  if [ -f "${SSL_CERTIFICATE_PATH}" -a -f "${SSL_KEY_PATH}" ]; then
    cp -f ${NGINX_ONLYOFFICE_PATH}/ds-ssl.conf.tmpl ${NGINX_ONLYOFFICE_CONF}

    # configure nginx
    sed 's,{{SSL_CERTIFICATE_PATH}},'"${SSL_CERTIFICATE_PATH}"',' -i ${NGINX_ONLYOFFICE_CONF}
    sed 's,{{SSL_KEY_PATH}},'"${SSL_KEY_PATH}"',' -i ${NGINX_ONLYOFFICE_CONF}

    # turn on http2
    sed 's,\(443 ssl\),\1 http2,' -i ${NGINX_ONLYOFFICE_CONF}

    # if dhparam path is valid, add to the config, otherwise remove the option
    if [ -r "${SSL_DHPARAM_PATH}" ]; then
      sed 's,\(\#* *\)\?\(ssl_dhparam \).*\(;\)$,'"\2${SSL_DHPARAM_PATH}\3"',' -i ${NGINX_ONLYOFFICE_CONF}
    else
      sed '/ssl_dhparam/d' -i ${NGINX_ONLYOFFICE_CONF}
    fi

    sed 's,\(ssl_verify_client \).*\(;\)$,'"\1${SSL_VERIFY_CLIENT}\2"',' -i ${NGINX_ONLYOFFICE_CONF}

    if [ -f "${CA_CERTIFICATES_PATH}" ]; then
      sed '/ssl_verify_client/a '"ssl_client_certificate ${CA_CERTIFICATES_PATH}"';' -i ${NGINX_ONLYOFFICE_CONF}
    fi

    if [ "${ONLYOFFICE_HTTPS_HSTS_ENABLED}" == "true" ]; then
      sed 's,\(max-age=\).*\(;\)$,'"\1${ONLYOFFICE_HTTPS_HSTS_MAXAGE}\2"',' -i ${NGINX_ONLYOFFICE_CONF}
    else
      sed '/max-age=/d' -i ${NGINX_ONLYOFFICE_CONF}
    fi

    if [ "${SSL_SELFSIGNED_CERTIFICATE}" == "true" ]; then
      ${JSON} -I -e "if(this.services.CoAuthoring.requestDefaults===undefined)this.services.CoAuthoring.requestDefaults={}"
      ${JSON} -I -e "if(this.services.CoAuthoring.requestDefaults.rejectUnauthorized===undefined)this.services.CoAuthoring.requestDefaults.rejectUnauthorized=false"
    fi
  else
    ln -sf ${NGINX_ONLYOFFICE_PATH}/ds.conf.tmpl ${NGINX_ONLYOFFICE_CONF}
  fi

  # check if ipv6 supported otherwise remove it from nginx config
  if [ ! -f /proc/net/if_inet6 ]; then
    sed '/listen\s\+\[::[0-9]*\].\+/d' -i $NGINX_ONLYOFFICE_CONF
  fi

  if [ -f "${NGINX_ONLYOFFICE_EXAMPLE_CONF}" ]; then
    sed 's/linux/docker/' -i ${NGINX_ONLYOFFICE_EXAMPLE_CONF}
  fi
}

update_supervisor_settings(){
  # Copy modified supervisor start script
  cp ${SYSCONF_TEMPLATES_DIR}/supervisor/supervisor /etc/init.d/
  # Copy modified supervisor config
  cp ${SYSCONF_TEMPLATES_DIR}/supervisor/supervisord.conf /etc/supervisor/supervisord.conf
}

update_log_settings(){
   ${JSON_LOG} -I -e "this.categories.default.level = '${DS_LOG_LEVEL}'"
}

update_logrotate_settings(){
  sed 's|\(^su\b\).*|\1 root root|' -i /etc/logrotate.conf
}

# create base folders
for i in converter docservice spellchecker metrics gc; do
  mkdir -p "${DS_LOG_DIR}/$i"
done

mkdir -p ${DS_LOG_DIR}-example

# create app folders
for i in App_Data/cache/files App_Data/docbuilder; do
  mkdir -p "${DS_LIB_DIR}/$i"
done

# change folder rights
for i in ${LOG_DIR} ${LIB_DIR} ${DATA_DIR}; do
  chown -R ds:ds "$i"
  chmod -R 755 "$i"
done

if [ ${ONLYOFFICE_DATA_CONTAINER_HOST} = "localhost" ]; then

  read_setting

  update_log_settings

  update_jwt_settings

  # update settings by env variables
  if [ ${POSTGRESQL_SERVER_HOST} != "localhost" ]; then
    update_postgresql_settings
    waiting_for_postgresql
    create_postgresql_tbl
  else
    # change rights for postgres directory
    chown -R postgres:postgres ${PG_ROOT}
    chmod -R 700 ${PG_ROOT}

    # create new db if it isn't exist
    if [ ! -d ${PGDATA} ]; then
      create_postgresql_cluster
      PG_NEW_CLUSTER=true
    fi
    LOCAL_SERVICES+=("postgresql")
  fi

  if [ ${AMQP_SERVER_HOST} != "localhost" ]; then
    update_rabbitmq_setting
  else
    LOCAL_SERVICES+=("rabbitmq-server")
    # allow Rabbitmq startup after container kill
    rm -rf /var/run/rabbitmq
  fi

  if [ ${REDIS_SERVER_HOST} != "localhost" ]; then
    update_redis_settings
  else
    LOCAL_SERVICES+=("redis-server")
  fi
else
  # no need to update settings just wait for remote data
  waiting_for_datacontainer

  # read settings after the data container in ready state
  # to prevent get unconfigureted data
  read_setting
fi

#start needed local services
for i in ${LOCAL_SERVICES[@]}; do
  service $i start
done

if [ ${PG_NEW_CLUSTER} = "true" ]; then
  create_postgresql_db
  create_postgresql_tbl
fi

if [ ${ONLYOFFICE_DATA_CONTAINER} != "true" ]; then
  waiting_for_postgresql
  waiting_for_amqp
  waiting_for_redis

  update_nginx_settings

  update_supervisor_settings
  service supervisor start
  
  # start cron to enable log rotating
  update_logrotate_settings
  service cron start
fi

# nginx used as a proxy, and as data container status service.
# it run in all cases.
service nginx start

# Regenerate the fonts list and the fonts thumbnails
documentserver-generate-allfonts.sh ${ONLYOFFICE_DATA_CONTAINER}
documentserver-static-gzip.sh ${ONLYOFFICE_DATA_CONTAINER}

tail -f /var/log/onlyoffice/**/*.log
