FROM ubuntu:14.04
LABEL maintainer Ascensio System SIA <support@onlyoffice.com>

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
    apt-get --force-yes -yq install adduser \
                                    bomstrip \
                                    fonts-crosextra-carlito \
                                    fonts-dejavu \
                                    fonts-liberation \
                                    fonts-opensymbol \
                                    fonts-takao-gothic \
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
                                    nginx-extras \
                                    nodejs \
                                    postgresql \
                                    postgresql-client \
                                    pwgen \
                                    rabbitmq-server \
                                    redis-server \
                                    software-properties-common \
                                    supervisor \
                                    ttf-mscorefonts-installer \
                                    xvfb \
                                    zlib1g && \
    [  $(ls -l /usr/share/fonts/truetype/msttcorefonts | wc -l) -eq 61 ] && \
    sudo -u postgres psql -c "CREATE DATABASE onlyoffice;" && \
    sudo -u postgres psql -c "CREATE USER onlyoffice WITH password 'onlyoffice';" && \
    sudo -u postgres psql -c "GRANT ALL privileges ON DATABASE onlyoffice TO onlyoffice;" && \ 
    service postgresql stop && \
    service redis-server stop && \
    service rabbitmq-server stop && \
    service supervisor stop && \
    service nginx stop && \
    rm -rf /var/lib/apt/lists/*

COPY config /app/onlyoffice/setup/config/
COPY run-document-server.sh /app/onlyoffice/run-document-server.sh

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

VOLUME /etc/onlyoffice /var/log/onlyoffice /var/lib/onlyoffice /var/www/onlyoffice/Data /var/lib/postgresql /usr/share/fonts/truetype/custom

CMD bash -C '/app/onlyoffice/run-document-server.sh';'bash'
