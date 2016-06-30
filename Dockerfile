FROM ubuntu:14.04
MAINTAINER Ascensio System SIA <support@onlyoffice.com>

ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8 DEBIAN_FRONTEND=noninteractive

RUN echo "#!/bin/sh\nexit 0" > /usr/sbin/policy-rc.d && \
    apt-get -y update && \
    apt-get --force-yes -yq install apt-transport-https && \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys D9D0BF019CC8AC0D && \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 1655A0AB68576280 && \
    echo "deb http://archive.ubuntu.com/ubuntu precise main universe multiverse" >> /etc/apt/sources.list && \
    echo "deb https://deb.nodesource.com/node_4.x trusty main" | tee /etc/apt/sources.list.d/nodesource.list && \
    locale-gen en_US.UTF-8 && \
    apt-get -y update && \
    echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections && \
    apt-get install --force-yes -yq software-properties-common && \
    add-apt-repository ppa:ubuntu-toolchain-r/test && \
    apt-get -y update && \
    apt-get --force-yes -yq install software-properties-common adduser mysql-server redis-server rabbitmq-server nginx-extras nodejs libstdc++6 libcurl3 libxml2 libboost-regex-dev zlib1g supervisor fonts-dejavu fonts-liberation ttf-mscorefonts-installer fonts-crosextra-carlito fonts-takao-gothic fonts-opensymbol libxss1 libgtkglext1 libcairo2 xvfb libxtst6 libgconf2-4 libasound2 bomstrip libnspr4 libnss3 libnss3-nssdb nano htop && \
    service mysql stop && \
    service redis-server stop && \
    service rabbitmq-server stop && \
    service supervisor stop && \
    service nginx stop && \
    rm -rf /var/lib/apt/lists/*

ADD config /app/onlyoffice/setup/config/
ADD run-document-server.sh /app/onlyoffice/run-document-server.sh

EXPOSE 80 443

RUN echo "deb http://static.teamlab.com/repo/debian/ squeeze main" | tee /etc/apt/sources.list.d/onlyoffice.list && \
    apt-get -y update && \
    service mysql start && \
    apt-get --force-yes -yq install onlyoffice-documentserver && \
    service mysql stop && \
    chmod 755 /app/onlyoffice/*.sh && \
    rm -rf /var/lib/apt/lists/*

VOLUME /etc/onlyoffice /var/log/onlyoffice /var/lib/onlyoffice /var/www/onlyoffice/Data

CMD bash -C '/app/onlyoffice/run-document-server.sh';'bash'
