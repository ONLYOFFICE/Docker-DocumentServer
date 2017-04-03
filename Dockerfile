FROM ubuntu:14.04
MAINTAINER Ascensio System SIA <support@onlyoffice.com>

ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8 DEBIAN_FRONTEND=noninteractive

RUN echo "#!/bin/sh\nexit 0" > /usr/sbin/policy-rc.d && \
    apt-get -y update && \
    apt-get --force-yes -yq install wget apt-transport-https curl && \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys CB2DE8E5 && \
    echo "deb http://archive.ubuntu.com/ubuntu precise main universe multiverse" >> /etc/apt/sources.list && \
    locale-gen en_US.UTF-8 && \
    curl -sL https://deb.nodesource.com/setup_6.x | bash - && \
    apt-get -y update && \
    echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections && \
    apt-get --force-yes -yq install software-properties-common adduser postgresql postgresql-client redis-server rabbitmq-server nginx-extras nodejs libstdc++6 libcurl3 libxml2 libboost-regex-dev zlib1g supervisor fonts-dejavu fonts-liberation ttf-mscorefonts-installer fonts-crosextra-carlito fonts-takao-gothic fonts-opensymbol libxss1 libgtkglext1 libcairo2 xvfb libxtst6 libgconf2-4 libasound2 bomstrip libnspr4 libnss3 libnss3-nssdb nano htop && \
    sudo -u postgres psql -c "CREATE DATABASE onlyoffice;" && \
    sudo -u postgres psql -c "CREATE USER onlyoffice WITH password 'onlyoffice';" && \
    sudo -u postgres psql -c "GRANT ALL privileges ON DATABASE onlyoffice TO onlyoffice;" && \ 
    service postgresql stop && \
    service redis-server stop && \
    service rabbitmq-server stop && \
    service supervisor stop && \
    service nginx stop && \
    rm -rf /var/lib/apt/lists/*

ADD config /app/onlyoffice/setup/config/
ADD run-document-server.sh /app/onlyoffice/run-document-server.sh

EXPOSE 80 443

ARG REPO_URL="deb http://download.onlyoffice.com/repo/debian squeeze main"
ARG PRODUCT_NAME=onlyoffice-documentserver

RUN echo "$REPO_URL" | tee /etc/apt/sources.list.d/onlyoffice.list && \
    apt-get -y update && \
    service postgresql start && \
    apt-get --force-yes -yq install $PRODUCT_NAME && \
    service postgresql stop && \
    service supervisor stop && \
    chmod 755 /app/onlyoffice/*.sh && \
    rm -rf /var/log/onlyoffice && \
    rm -rf /var/lib/apt/lists/*

VOLUME /etc/onlyoffice /var/log/onlyoffice /var/lib/onlyoffice /var/www/onlyoffice/Data /usr/share/fonts/truetype/custom

CMD bash -C '/app/onlyoffice/run-document-server.sh';'bash'
