ARG BASE_VERSION=22.04

ARG BASE_IMAGE=ubuntu:$BASE_VERSION

FROM ${BASE_IMAGE} AS documentserver
LABEL maintainer Ascensio System SIA <support@onlyoffice.com>

ARG BASE_VERSION
ARG PG_VERSION=14
ARG OOU_VERSION_MAJOR=8.2.2
ARG OOU_BUILD=1

ENV OC_RELEASE_NUM=21
ENV OC_RU_VER=12
ENV OC_RU_REVISION_VER=0
ENV OC_RESERVED_NUM=0
ENV OC_RU_DATE=0
ENV OC_PATH=${OC_RELEASE_NUM}${OC_RU_VER}000
ENV OC_FILE_SUFFIX=${OC_RELEASE_NUM}.${OC_RU_VER}.${OC_RU_REVISION_VER}.${OC_RESERVED_NUM}.${OC_RU_DATE}${OC_FILE_SUFFIX}dbru
ENV OC_VER_DIR=${OC_RELEASE_NUM}_${OC_RU_VER}
ENV OC_DOWNLOAD_URL=https://download.oracle.com/otn_software/linux/instantclient/${OC_PATH}

ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8 DEBIAN_FRONTEND=noninteractive PG_VERSION=${PG_VERSION} BASE_VERSION=${BASE_VERSION}

ARG ONLYOFFICE_VALUE=onlyoffice

RUN echo "#!/bin/sh\nexit 0" > /usr/sbin/policy-rc.d && \
    apt-get -y update && \
    apt-get -yq install wget apt-transport-https gnupg locales lsb-release && \
    wget -q -O /etc/apt/sources.list.d/mssql-release.list https://packages.microsoft.com/config/ubuntu/$BASE_VERSION/prod.list && \
    wget -q -O - https://packages.microsoft.com/keys/microsoft.asc | apt-key add - && \
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
        libaio1 \
        libasound2 \
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
        zlib1g && \
    if [  $(ls -l /usr/share/fonts/truetype/msttcorefonts | wc -l) -ne 61 ]; \
        then echo 'msttcorefonts failed to download'; exit 1; fi  && \
    echo "SERVER_ADDITIONAL_ERL_ARGS=\"+S 1:1\"" | tee -a /etc/rabbitmq/rabbitmq-env.conf && \
    sed -i "s/bind .*/bind 127.0.0.1/g" /etc/redis/redis.conf && \
    sed 's|\(application\/zip.*\)|\1\n    application\/wasm wasm;|' -i /etc/nginx/mime.types && \
    pg_conftool $PG_VERSION main set listen_addresses 'localhost' && \
    service postgresql restart && \
    sudo -u postgres psql -c "CREATE USER $ONLYOFFICE_VALUE WITH password '$ONLYOFFICE_VALUE';" && \
    sudo -u postgres psql -c "CREATE DATABASE $ONLYOFFICE_VALUE OWNER $ONLYOFFICE_VALUE;" && \
    wget -O basic.zip ${OC_DOWNLOAD_URL}/instantclient-basic-linux.x64-${OC_FILE_SUFFIX}.zip && \
    wget -O sqlplus.zip ${OC_DOWNLOAD_URL}/instantclient-sqlplus-linux.x64-${OC_FILE_SUFFIX}.zip && \
    unzip -d /usr/share basic.zip && \
    unzip -d /usr/share sqlplus.zip && \
    mv /usr/share/instantclient_${OC_VER_DIR} /usr/share/instantclient && \
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

## PACKAGE_FILE="${COMPANY_NAME}-${PRODUCT_NAME}${PRODUCT_EDITION}${PACKAGE_VERSION:+_$PACKAGE_VERSION}_${TARGETARCH:-$(dpkg --print-architecture)}.deb" && \
##    wget -q -P /tmp "$PACKAGE_BASEURL/$PACKAGE_FILE" && \
##    rm -f /tmp/onlyoffice-documentserver*.deb && \
RUN    wget -q -P /tmp "https://github.com/thomisus/server/releases/download/${OOU_VERSION_MAJOR}.${OOU_BUILD}/onlyoffice-documentserver_${OOU_VERSION_MAJOR}-${OOU_BUILD}.oou_amd64.deb" && \
    apt-get -y update && \
    service postgresql start && \
    apt-get -yq install /tmp/onlyoffice-documentserver_${OOU_VERSION_MAJOR}-${OOU_BUILD}.oou_amd64.deb && \
    service postgresql stop && \
    chmod 755 /etc/init.d/supervisor && \
    sed "s/COMPANY_NAME/${COMPANY_NAME}/g" -i /etc/supervisor/conf.d/*.conf && \
    service supervisor stop && \
    chmod 755 /app/ds/*.sh && \
    rm -f /tmp/onlyoffice-documentserver_${OOU_VERSION_MAJOR}-${OOU_BUILD}.oou_amd64.deb && \
    printf "\nGO" >> /var/www/$COMPANY_NAME/documentserver/server/schema/mssql/createdb.sql && \
    printf "\nGO" >> /var/www/$COMPANY_NAME/documentserver/server/schema/mssql/removetbl.sql && \
    printf "\nexit" >> /var/www/$COMPANY_NAME/documentserver/server/schema/oracle/createdb.sql && \
    printf "\nexit" >> /var/www/$COMPANY_NAME/documentserver/server/schema/oracle/removetbl.sql && \
    rm -f /tmp/$PACKAGE_FILE && \
    rm -rf /var/log/$COMPANY_NAME && \
    rm -rf /var/lib/apt/lists/*

VOLUME /var/log/$COMPANY_NAME /var/lib/$COMPANY_NAME /var/www/$COMPANY_NAME/Data /var/lib/postgresql /var/lib/rabbitmq /var/lib/redis /usr/share/fonts/truetype/custom

ENTRYPOINT ["/app/ds/run-document-server.sh"]
