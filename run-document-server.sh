#!/bin/bash

sed "/user=/s/onlyoffice/root/" -i /etc/supervisor/conf.d/CoAuthoringService.conf
sed "/user=/s/onlyoffice/root/" -i /etc/supervisor/conf.d/DocService.conf
sed "/user=/s/onlyoffice/root/" -i /etc/supervisor/conf.d/FileConverterService.conf
sed "/user=/s/onlyoffice/root/" -i /etc/supervisor/conf.d/LibreOfficeService.conf
sed "/user=/s/onlyoffice/root/" -i /etc/supervisor/conf.d/SpellCheckerService.conf

sed "/sudo /s/-u onlyoffice//" -i /var/www/onlyoffice/documentserver/Tools/CheckDocService.sh
sed "/sudo /s/-u onlyoffice//" -i /var/www/onlyoffice/documentserver/Tools/GenerateAllFonts.sh

chown root /var/www/onlyoffice
chown root /var/lib/onlyoffice

adduser --quiet www-data root

DATA_DIR="/var/www/onlyoffice/Data"
LOG_DIR="/var/log/onlyoffice"

ONLYOFFICE_HTTPS=${ONLYOFFICE_HTTPS:-false}

SSL_CERTIFICATES_DIR="${DATA_DIR}/certs"
SSL_CERTIFICATE_PATH=${SSL_CERTIFICATE_PATH:-${SSL_CERTIFICATES_DIR}/onlyoffice.crt}
SSL_KEY_PATH=${SSL_KEY_PATH:-${SSL_CERTIFICATES_DIR}/onlyoffice.key}
SSL_DHPARAM_PATH=${SSL_DHPARAM_PATH:-${SSL_CERTIFICATES_DIR}/dhparam.pem}
SSL_VERIFY_CLIENT=${SSL_VERIFY_CLIENT:-off}
ONLYOFFICE_HTTPS_HSTS_ENABLED=${ONLYOFFICE_HTTPS_HSTS_ENABLED:-true}
ONLYOFFICE_HTTPS_HSTS_MAXAGE=${ONLYOFFICE_HTTPS_HSTS_MAXAG:-31536000}
SYSCONF_TEMPLATES_DIR="/app/onlyoffice/setup/config"

NGINX_ONLYOFFICE_PATH="/etc/nginx/sites-enabled/onlyoffice-documentserver";

# create base folders
mkdir -p /var/log/onlyoffice/documentserver/FileConverterService/
mkdir -p /var/log/onlyoffice/documentserver/CoAuthoringService/
mkdir -p /var/log/onlyoffice/documentserver/DocService/
mkdir -p /var/log/onlyoffice/documentserver/SpellCheckerService/
mkdir -p /var/log/onlyoffice/documentserver/LibreOfficeService/

# setup HTTPS
if [ -f "${SSL_CERTIFICATE_PATH}" -a -f "${SSL_KEY_PATH}" ]; then
        cp ${SYSCONF_TEMPLATES_DIR}/nginx/onlyoffice-ssl ${NGINX_ONLYOFFICE_PATH}

        mkdir ${DATA_DIR}
        mkdir ${LOG_DIR}/nginx

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

        if [ -f /usr/local/share/ca-certificates/ca.crt ]; then
          sed 's,{{CA_CERTIFICATES_PATH}},'"${CA_CERTIFICATES_PATH}"',' -i ${NGINX_ONLYOFFICE_PATH}
        else
          sed '/{{CA_CERTIFICATES_PATH}}/d' -i ${NGINX_ONLYOFFICE_PATH}
        fi

        if [ "${ONLYOFFICE_HTTPS_HSTS_ENABLED}" == "true" ]; then
          sed 's/{{ONLYOFFICE_HTTPS_HSTS_MAXAGE}}/'"${ONLYOFFICE_HTTPS_HSTS_MAXAGE}"'/' -i ${NGINX_ONLYOFFICE_PATH}
        else
          sed '/{{ONLYOFFICE_HTTPS_HSTS_MAXAGE}}/d' -i ${NGINX_ONLYOFFICE_PATH}
        fi
fi

service mysql start
service nginx start
service supervisor start
