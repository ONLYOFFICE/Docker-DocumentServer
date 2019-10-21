FROM ubuntu:16.04
LABEL maintainer Ascensio System SIA <support@onlyoffice.com>

ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8 DEBIAN_FRONTEND=noninteractive

ARG ONLYOFFICE_VALUE=onlyoffice

RUN echo "#!/bin/sh\nexit 0" > /usr/sbin/policy-rc.d && \
    apt-get -y update && \
    apt-get -yq install wget apt-transport-https curl locales && \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 0x8320ca65cb2de8e5 && \
    locale-gen en_US.UTF-8 && \
    curl -sL https://deb.nodesource.com/setup_8.x | bash - && \
    apt-get -y update && \
    apt-get -yq install \
        adduser \
        bomstrip \
        htop \
        libasound2 \
        libboost-regex-dev \
        libcairo2 \
        libcurl3 \
        libgconf2-4 \
        libgtkglext1 \
        libnspr4 \
        libnss3 \
        libnss3-nssdb \
        libstdc++6 \
        libxml2 \
        libxss1 \
        libxtst6 \
        nano \
        net-tools \
        netcat \
        nginx-extras \
        nodejs \
        postgresql \
        postgresql-client \
        pwgen \
        rabbitmq-server \
        redis-server \
        software-properties-common \
        sudo \
        supervisor \
        xvfb \
        zlib1g && \
    sudo -u postgres psql -c "CREATE DATABASE $ONLYOFFICE_VALUE;" && \
    sudo -u postgres psql -c "CREATE USER $ONLYOFFICE_VALUE WITH password '$ONLYOFFICE_VALUE';" && \
    sudo -u postgres psql -c "GRANT ALL privileges ON DATABASE $ONLYOFFICE_VALUE TO $ONLYOFFICE_VALUE;" && \ 
    service postgresql stop && \
    service redis-server stop && \
    service rabbitmq-server stop && \
    service supervisor stop && \
    service nginx stop && \
    rm -rf /var/lib/apt/lists/*

COPY config /app/ds/setup/config/
COPY run-document-server.sh /app/ds/run-document-server.sh

EXPOSE 80 443

ARG REPO_URL="deb http://download.onlyoffice.com/repo/debian squeeze main"
ARG COMPANY_NAME=onlyoffice
ARG PRODUCT_NAME=documentserver

ENV COMPANY_NAME=$COMPANY_NAME

RUN echo "$REPO_URL" | tee /etc/apt/sources.list.d/ds.list && \
    apt-get -y update && \
    service postgresql start && \
    apt-get -yq install $COMPANY_NAME-$PRODUCT_NAME && \
    service postgresql stop && \
    service supervisor stop && \
    chmod 755 /app/ds/*.sh && \
    rm -rf /var/log/$COMPANY_NAME && \
    rm -rf /var/lib/apt/lists/*

VOLUME /var/log/$COMPANY_NAME /var/lib/$COMPANY_NAME /var/www/$COMPANY_NAME/Data /var/lib/postgresql /usr/share/fonts/truetype/custom

ENTRYPOINT /app/ds/run-document-server.sh
