#!/bin/bash

APP_DIR="/var/www/onlyoffice/documentserver"
DATA_DIR="/var/www/onlyoffice/Data"
LOG_DIR="/var/log/onlyoffice/documentserver"

ONLYOFFICE_HTTPS=${ONLYOFFICE_HTTPS:-false}

SSL_CERTIFICATES_DIR="${DATA_DIR}/certs"
SSL_CERTIFICATE_PATH=${SSL_CERTIFICATE_PATH:-${SSL_CERTIFICATES_DIR}/onlyoffice.crt}
SSL_KEY_PATH=${SSL_KEY_PATH:-${SSL_CERTIFICATES_DIR}/onlyoffice.key}
CA_CERTIFICATES_PATH=${CA_CERTIFICATES_PATH:-${SSL_CERTIFICATES_DIR}/ca-certificates.pem}
SSL_DHPARAM_PATH=${SSL_DHPARAM_PATH:-${SSL_CERTIFICATES_DIR}/dhparam.pem}
SSL_VERIFY_CLIENT=${SSL_VERIFY_CLIENT:-off}
ONLYOFFICE_HTTPS_HSTS_ENABLED=${ONLYOFFICE_HTTPS_HSTS_ENABLED:-true}
ONLYOFFICE_HTTPS_HSTS_MAXAGE=${ONLYOFFICE_HTTPS_HSTS_MAXAG:-31536000}
SYSCONF_TEMPLATES_DIR="/app/onlyoffice/setup/config"

NGINX_ONLYOFFICE_PATH="/etc/nginx/conf.d/onlyoffice-documentserver.conf";

NGINX_CONFIG_PATH="/etc/nginx/nginx.conf"
NGINX_WORKER_PROCESSES=${NGINX_WORKER_PROCESSES:-$(grep processor /proc/cpuinfo | wc -l)}
NGINX_WORKER_CONNECTIONS=${NGINX_WORKER_CONNECTIONS:-$(ulimit -n)}

ONLYOFFICE_DEFAULT_CONFIG=/etc/onlyoffice/documentserver/default.json

MYSQL_SERVER_HOST=${MYSQL_SERVER_HOST:-"localhost"}
MYSQL_SERVER_PORT=${MYSQL_SERVER_PORT:-"3306"}
MYSQL_SERVER_DB_NAME=${MYSQL_SERVER_DB_NAME:-"onlyoffice"}
MYSQL_SERVER_USER=${MYSQL_SERVER_USER:-"root"}
MYSQL_SERVER_PASS=${MYSQL_SERVER_PASS:-""}

RABBITMQ_SERVER_HOST=${RABBITMQ_SERVER_HOST:-"localhost"}
RABBITMQ_SERVER_USER=${RABBITMQ_SERVER_USER:-"guest"}
RABBITMQ_SERVER_PASS=${RABBITMQ_SERVER_PASS:-"guest"}

REDIS_SERVER_HOST=${REDIS_SERVER_HOST:-"localhost"}
REDIS_SERVER_PORT=${REDIS_SERVER_PORT:-"6379"}

# create base folders
for i in converter docservice spellchecker metrics gc; do
	mkdir -p "${LOG_DIR}/$i"
done

mkdir -p ${LOG_DIR}-example

# Set up nginx
sed 's/^worker_processes.*/'"worker_processes ${NGINX_WORKER_PROCESSES};"'/' -i ${NGINX_CONFIG_PATH}
sed 's/worker_connections.*/'"worker_connections ${NGINX_WORKER_CONNECTIONS};"'/' -i ${NGINX_CONFIG_PATH}
sed 's/access_log.*/'"access_log off;"'/' -i ${NGINX_CONFIG_PATH}

# setup HTTPS
if [ -f "${SSL_CERTIFICATE_PATH}" -a -f "${SSL_KEY_PATH}" ]; then
  cp ${SYSCONF_TEMPLATES_DIR}/nginx/onlyoffice-documentserver-ssl.conf ${NGINX_ONLYOFFICE_PATH}

  mkdir ${DATA_DIR}

  # configure nginx
  sed 's,{{SSL_CERTIFICATE_PATH}},'"${SSL_CERTIFICATE_PATH}"',' -i ${NGINX_ONLYOFFICE_PATH}
  sed 's,{{SSL_KEY_PATH}},'"${SSL_KEY_PATH}"',' -i ${NGINX_ONLYOFFICE_PATH}

  # if dhparam path is valid, add to the config, otherwise remove the option
  if [ -r "${SSL_DHPARAM_PATH}" ]; then
    sed 's,{{SSL_DHPARAM_PATH}},'"${SSL_DHPARAM_PATH}"',' -i ${NGINX_ONLYOFFICE_PATH}
  else
    sed '/ssl_dhparam {{SSL_DHPARAM_PATH}};/d' -i ${NGINX_ONLYOFFICE_PATH}
  fi

  sed 's,{{SSL_VERIFY_CLIENT}},'"${SSL_VERIFY_CLIENT}"',' -i ${NGINX_ONLYOFFICE_PATH}

  if [ -f "${CA_CERTIFICATES_PATH}" ]; then
    sed 's,{{CA_CERTIFICATES_PATH}},'"${CA_CERTIFICATES_PATH}"',' -i ${NGINX_ONLYOFFICE_PATH}
  else
    sed '/{{CA_CERTIFICATES_PATH}}/d' -i ${NGINX_ONLYOFFICE_PATH}
  fi

  if [ "${ONLYOFFICE_HTTPS_HSTS_ENABLED}" == "true" ]; then
    sed 's/{{ONLYOFFICE_HTTPS_HSTS_MAXAGE}}/'"${ONLYOFFICE_HTTPS_HSTS_MAXAGE}"'/' -i ${NGINX_ONLYOFFICE_PATH}
  else
    sed '/{{ONLYOFFICE_HTTPS_HSTS_MAXAGE}}/d' -i ${NGINX_ONLYOFFICE_PATH}
  fi
else
  cp ${SYSCONF_TEMPLATES_DIR}/nginx/onlyoffice-documentserver.conf ${NGINX_ONLYOFFICE_PATH}
fi

JSON="json -I -q -f ${ONLYOFFICE_DEFAULT_CONFIG}"

if [ ${MYSQL_SERVER_HOST} != "localhost" ]; then

  # Change mysql settings
  ${JSON} -e "this.services.CoAuthoring.sql.dbHost = '${MYSQL_SERVER_HOST}'"
  ${JSON} -e "this.services.CoAuthoring.sql.dbPort = '${MYSQL_SERVER_PORT}'"
  ${JSON} -e "this.services.CoAuthoring.sql.dbName = '${MYSQL_SERVER_DB_NAME}'"
  ${JSON} -e "this.services.CoAuthoring.sql.dbUser = '${MYSQL_SERVER_USER}'"
  ${JSON} -e "this.services.CoAuthoring.sql.dbPass = '${MYSQL_SERVER_PASS}'"

  MYSQL="mysql -s -h${MYSQL_SERVER_HOST} -u${MYSQL_SERVER_USER}"
  if [ -n "${MYSQL_SERVER_PASS}" ]; then
    MYSQL="$MYSQL -p${MYSQL_SERVER_PASS}"
  fi

  # Create  db on remote server
  ${MYSQL} -e "CREATE DATABASE IF NOT EXISTS ${MYSQL_SERVER_DB_NAME} CHARACTER SET utf8 COLLATE 'utf8_general_ci';"
  ${MYSQL} "${MYSQL_SERVER_DB_NAME}" < "${APP_DIR}/server/schema/createdb.sql"
else
  service mysql start
fi

if [ ${RABBITMQ_SERVER_HOST} != "localhost" ]; then

  # Change rabbitmq settings
  ${JSON} -e "this.rabbitmq.url = 'amqp://${RABBITMQ_SERVER_HOST}'"
  ${JSON} -e "this.rabbitmq.login = '${RABBITMQ_SERVER_USER}'"
  ${JSON} -e "this.rabbitmq.password = '${RABBITMQ_SERVER_PASS}'"
  
else
  service redis-server start
fi

if [ ${REDIS_SERVER_HOST} != "localhost" ]; then

  # Change redis settings
  ${JSON} -e "this.services.CoAuthoring.redis.host = '${REDIS_SERVER_HOST}'"
  ${JSON} -e "this.services.CoAuthoring.redis.port = '${REDIS_SERVER_PORT}'"
  
else
  service rabbitmq-server start
fi

# Copy modified supervisor start script
cp ${SYSCONF_TEMPLATES_DIR}/supervisor/supervisor /etc/init.d/
# Copy modified supervisor config
cp ${SYSCONF_TEMPLATES_DIR}/supervisor/supervisord.conf /etc/supervisor/supervisord.conf

service nginx start
service supervisor start

# Regenerate the fonts list and the fonts thumbnails
documentserver-generate-allfonts.sh
