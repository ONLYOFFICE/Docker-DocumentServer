ARG BASE_VERSION=24.04

ARG BASE_IMAGE=ubuntu:$BASE_VERSION

FROM ${BASE_IMAGE} AS documentserver
LABEL maintainer="Ascensio System SIA <support@onlyoffice.com>"

ARG BASE_VERSION
ARG PG_VERSION=16
ARG PACKAGE_SUFFIX=t64

ENV OC_RELEASE_NUM=23
ENV OC_RU_VER=7
ENV OC_RU_REVISION_VER=0
ENV OC_RESERVED_NUM=25
ENV OC_RU_DATE=01
ENV OC_PATH=${OC_RELEASE_NUM}${OC_RU_VER}0000
ENV OC_FILE_SUFFIX=${OC_RELEASE_NUM}.${OC_RU_VER}.${OC_RU_REVISION_VER}.${OC_RESERVED_NUM}.${OC_RU_DATE}
ENV OC_VER_DIR=${OC_RELEASE_NUM}_${OC_RU_VER}
ENV OC_DOWNLOAD_URL=https://download.oracle.com/otn_software/linux/instantclient/${OC_PATH}

ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8 DEBIAN_FRONTEND=noninteractive PG_VERSION=${PG_VERSION} BASE_VERSION=${BASE_VERSION}

ARG ONLYOFFICE_VALUE=onlyoffice
COPY fonts/ /usr/share/fonts/truetype/

RUN echo "#!/bin/sh\nexit 0" > /usr/sbin/policy-rc.d && \
    apt-get -y update && \
    apt-get -yq install wget apt-transport-https gnupg locales lsb-release && \
    wget -q -O /etc/apt/sources.list.d/mssql-release.list "https://packages.microsoft.com/config/ubuntu/$BASE_VERSION/prod.list" && \
    wget -q -O /tmp/microsoft.asc https://packages.microsoft.com/keys/microsoft.asc && \
    apt-key add /tmp/microsoft.asc && \
    gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg < /tmp/microsoft.asc && \
    apt-get -y update && \
    locale-gen en_US.UTF-8 && \
    echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections && \
    ACCEPT_EULA=Y apt-get -yq install \
        adduser \
        apt-utils \
        bomstrip \
        certbot \
        cron \
        curl \
        htop \
        libaio1${PACKAGE_SUFFIX} \
        libasound2${PACKAGE_SUFFIX} \
        libboost-regex-dev \
        libcairo2 \
        libcurl3-gnutls \
        libcurl4 \
        libgtk-3-0 \
        libnspr4 \
        libnss3 \
        libstdc++6 \
        libxml2 \
        libxss1 \
        libxtst6 \
        mssql-tools18 \
        mysql-client \
        nano \
        net-tools \
        netcat-openbsd \
        nginx-extras \
        postgresql \
        postgresql-client \
        pwgen \
        rabbitmq-server \
        redis-server \
        sudo \
        supervisor \
        ttf-mscorefonts-installer \
        unixodbc-dev \
        unzip \
        xvfb \
        xxd \
        zlib1g || dpkg --configure -a && \
    # Added dpkg --configure -a to handle installation issues with rabbitmq-server on arm64 architecture
    if [  $(find /usr/share/fonts/truetype/msttcorefonts -maxdepth 1 -type f -iname '*.ttf' | wc -l) -lt 30 ]; \
        then echo 'msttcorefonts failed to download'; exit 1; fi  && \
    echo "SERVER_ADDITIONAL_ERL_ARGS=\"+S 1:1\"" | tee -a /etc/rabbitmq/rabbitmq-env.conf && \
    sed -i "s/bind .*/bind 127.0.0.1/g" /etc/redis/redis.conf && \
    sed 's|\(application\/zip.*\)|\1\n    application\/wasm wasm;|' -i /etc/nginx/mime.types && \
    pg_conftool $PG_VERSION main set listen_addresses 'localhost' && \
    service postgresql restart && \
    sudo -u postgres psql -c "CREATE USER $ONLYOFFICE_VALUE WITH password '$ONLYOFFICE_VALUE';" && \
    sudo -u postgres psql -c "CREATE DATABASE $ONLYOFFICE_VALUE OWNER $ONLYOFFICE_VALUE;" && \
    wget -O basic.zip ${OC_DOWNLOAD_URL}/instantclient-basic-linux.$(dpkg --print-architecture | sed 's/amd64/x64/')-${OC_FILE_SUFFIX}.zip && \
    wget -O sqlplus.zip ${OC_DOWNLOAD_URL}/instantclient-sqlplus-linux.$(dpkg --print-architecture | sed 's/amd64/x64/')-${OC_FILE_SUFFIX}.zip && \
    unzip -o basic.zip -d /usr/share && \
    unzip -o sqlplus.zip -d /usr/share && \
    mv /usr/share/instantclient_${OC_VER_DIR} /usr/share/instantclient && \
    find /usr/lib /lib -name "libaio.so.1$PACKAGE_SUFFIX" -exec bash -c 'ln -sf "$0" "$(dirname "$0")/libaio.so.1"' {} \; && \
    service postgresql stop && \
    service redis-server stop && \
    service rabbitmq-server stop && \
    service supervisor stop && \
    service nginx stop && \
    rm -rf /var/lib/apt/lists/*

COPY config/supervisor/supervisor /etc/init.d/
COPY config/supervisor/ds/*.conf /etc/supervisor/conf.d/
COPY run-document-server.sh /app/ds/run-document-server.sh
COPY oracle/sqlplus /usr/bin/sqlplus

EXPOSE 80 443

ARG COMPANY_NAME=onlyoffice
ARG PRODUCT_NAME=documentserver
ARG PRODUCT_EDITION=
ARG PACKAGE_VERSION=
ARG TARGETARCH
ARG PACKAGE_BASEURL="http://download.onlyoffice.com/install/documentserver/linux"

ENV COMPANY_NAME=$COMPANY_NAME \
    PRODUCT_NAME=$PRODUCT_NAME \
    PRODUCT_EDITION=$PRODUCT_EDITION \
    DS_PLUGIN_INSTALLATION=false \
    DS_DOCKER_INSTALLATION=true

RUN PACKAGE_FILE="${COMPANY_NAME}-${PRODUCT_NAME}${PRODUCT_EDITION}${PACKAGE_VERSION:+_$PACKAGE_VERSION}_${TARGETARCH:-$(dpkg --print-architecture)}.deb" && \
    wget -q -P /tmp "$PACKAGE_BASEURL/$PACKAGE_FILE" && \
    apt-get -y update && \
    service postgresql start && \
    apt-get -yq install /tmp/$PACKAGE_FILE && \
    if [ "${PRODUCT_EDITION}" != "-ee" ] && [ "${PRODUCT_EDITION}" != "-de" ]; then rm -f /etc/supervisor/conf.d/ds-adminpanel.conf && sed -i 's/,adminpanel//' /etc/supervisor/conf.d/ds.conf; fi && \
    PGPASSWORD=$ONLYOFFICE_VALUE dropdb -h localhost -p 5432 -U $ONLYOFFICE_VALUE $ONLYOFFICE_VALUE && \
    sudo -u postgres psql -c "DROP ROLE onlyoffice;" && \
    service postgresql stop && \
    chmod 755 /etc/init.d/supervisor && \
    sed "s/COMPANY_NAME/${COMPANY_NAME}/g" -i /etc/supervisor/conf.d/*.conf && \
    service supervisor stop && \
    chmod 755 /app/ds/*.sh && \
    printf "\nGO" >> "/var/www/$COMPANY_NAME/documentserver/server/schema/mssql/createdb.sql" && \
    printf "\nGO" >> "/var/www/$COMPANY_NAME/documentserver/server/schema/mssql/removetbl.sql" && \
    printf "\nexit" >> "/var/www/$COMPANY_NAME/documentserver/server/schema/oracle/createdb.sql" && \
    printf "\nexit" >> "/var/www/$COMPANY_NAME/documentserver/server/schema/oracle/removetbl.sql" && \
    rm -f /tmp/$PACKAGE_FILE && \
    rm -rf /var/log/$COMPANY_NAME && \
    rm -rf /var/lib/apt/lists/*

VOLUME /var/log/$COMPANY_NAME /var/lib/$COMPANY_NAME /var/www/$COMPANY_NAME/Data /var/lib/postgresql /var/lib/rabbitmq /var/lib/redis /usr/share/fonts/truetype/custom

ENTRYPOINT ["/app/ds/run-document-server.sh"]
