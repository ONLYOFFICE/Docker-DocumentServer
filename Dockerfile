FROM debian:latest
LABEL maintainer="jiriks74"

RUN echo "deb http://deb.debian.org/debian bullseye main contrib non-free\ndeb http://deb.debian.org/debian-security/ bullseye-security main contrib non-free\ndeb http://deb.debian.org/debian bullseye-updates main contrib non-free\ndeb http://deb.debian.org/debian bullseye-backports main" > /etc/apt/sources.list 

RUN mkdir /build
RUN cd /build

ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8 DEBIAN_FRONTEND=noninteractive PG_VERSION=13

ARG ONLYOFFICE_VALUE=onlyoffice

RUN echo "#!/bin/sh\nexit 0" > /usr/sbin/policy-rc.d && \
    apt-get -y update && \
    apt-get -yq install wget apt-transport-https gnupg locales && \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 0x8320ca65cb2de8e5 && \
    locale-gen en_US.UTF-8 && \
    echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections && \
    apt-get -yq install \
        adduser \
        apt-utils \
        bomstrip \
        certbot \
        curl \
        gconf-service \
        htop \
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
        mariadb-client \
        nano \
        net-tools \
        netcat-openbsd \
        nginx-extras \
        postgresql \
        postgresql-client \
        pwgen \
        rabbitmq-server \
        redis-server \
        software-properties-common \
        sudo \
        supervisor \
        ttf-mscorefonts-installer \
        xvfb \
        zlib1g && \
    if [  $(ls -l /usr/share/fonts/truetype/msttcorefonts | wc -l) -ne 61 ]; \
        then echo 'msttcorefonts failed to download'; exit 1; fi  && \
    echo "SERVER_ADDITIONAL_ERL_ARGS=\"+S 1:1\"" | tee -a /etc/rabbitmq/rabbitmq-env.conf && \
    sed -i "s/bind .*/bind 127.0.0.1/g" /etc/redis/redis.conf && \
    sed 's|\(application\/zip.*\)|\1\n    application\/wasm wasm;|' -i /etc/nginx/mime.types && \
    pg_conftool $PG_VERSION main set listen_addresses 'localhost' && \
    service postgresql restart && \
    sudo -u postgres psql -c "CREATE DATABASE $ONLYOFFICE_VALUE;" && \
    sudo -u postgres psql -c "CREATE USER $ONLYOFFICE_VALUE WITH password '$ONLYOFFICE_VALUE';" && \
    sudo -u postgres psql -c "GRANT ALL privileges ON DATABASE $ONLYOFFICE_VALUE TO $ONLYOFFICE_VALUE;" && \ 
    service postgresql stop && \
    service redis-server stop && \
    service rabbitmq-server stop && \
    service supervisor stop && \
    service nginx stop 

RUN apt install qemu binfmt-support qemu-user-static -t bullseye-backports -y

RUN dpkg --add-architecture amd64
RUN apt update && apt install libgcc-s1 libgcc-s1:amd64 -y

RUN cd /build && apt download libc6:amd64
RUN dpkg-deb -R /build/libc6*.deb /build/libc6

RUN sed -i 's/^Package: libc6$/Package: libc6-amd64/' /build/libc6/DEBIAN/control
RUN sed -i 's/^Depends: libgcc-s1, libcrypt1$/#Depends: libgcc-s1, libcrypt1/' /build/libc6/DEBIAN/control

RUN rm -rf /build/libc6/usr/share/doc
RUN rm -rf /build/libc6/usr/share/lintian 

RUN dpkg-deb -b /build/libc6 /build/libc6-modified.deb
RUN dpkg -i /build/libc6-modified.deb

RUN cd /build && apt download libstdc++6:amd64 
RUN dpkg-deb -R /build/libstdc++6*.deb /build/stdc

RUN sed -i 's/^Depends: gcc-10-base (= 10.2.1-6), libc6 (>= 2.23), libgcc-s1 (>= 4.2)$/#Depends: gcc-10-base (= 10.2.1-6), libc6 (>= 2.23), libgcc-s1 (>= 4.2)/' /build/stdc/DEBIAN/control 

RUN dpkg-deb -b /build/stdc /build/libstdc++6-modified.deb
RUN dpkg -i /build/libstdc++6-modified.deb

RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys CB2DE8E5
RUN echo "deb https://download.onlyoffice.com/repo/debian squeeze main" | tee /etc/apt/sources.list.d/onlyoffice.list

RUN cd /build && apt update && apt download onlyoffice-documentserver:amd64
RUN dpkg-deb -R /build/onlyoffice-documentserver*.deb /build/onlyoffice

RUN sed -i 's/^Depends: debconf (>= 0.5) | debconf-2.0, adduser, ca-certificates, coreutils, curl, libasound2, libcairo2, libcurl3 | libcurl4, libcurl3-gnutls, libgconf-2-4, libgtk-3-0, libstdc++6 (>= 4.8.4), libxml2, libxss1, libxtst6, logrotate, mysql-client | mariadb-client, nginx-extras (>= 1.3.13), postgresql-client (>= 9.1), pwgen, supervisor (>= 3.0b2), xvfb, zlib1g$/Depends: debconf:arm64 (>= 0.5) | debconf-2.0:arm64, adduser:arm64, ca-certificates:arm64, coreutils:arm64, curl:arm64, libasound2:arm64, libcairo2:arm64, libcurl3:arm64 | libcurl4:arm64, libcurl3-gnutls:arm64, libgconf-2-4:arm64, libgtk-3-0:arm64, libstdc++6:amd64 (>= 4.8.4), libxml2:arm64, libxss1:arm64, libxtst6:arm64, logrotate:arm64, mysql-client:arm64 | mariadb-client:arm64, nginx-extras:arm64 (>= 1.3.13), postgresql-client:arm64 (>= 9.1), pwgen:arm64, supervisor:all (>= 3.0b2), xvfb:arm64, zlib1g:arm64/' /build/onlyoffice/DEBIAN/control

RUN dpkg-deb -b /build/onlyoffice /build/onlyoffice-documentserver-modified.deb

COPY config /app/ds/setup/config/
COPY run-document-server.sh /app/ds/run-document-server.sh

EXPOSE 80 443

ARG COMPANY_NAME=onlyoffice
ARG PRODUCT_NAME=documentserver
ARG PACKAGE_URL="http://download.onlyoffice.com/install/documentserver/linux/${COMPANY_NAME}-${PRODUCT_NAME}_amd64.deb"

ENV COMPANY_NAME=$COMPANY_NAME \
    PRODUCT_NAME=$PRODUCT_NAME
 
RUN service postgresql start && \
    apt-get -yq install /build/onlyoffice-documentserver-modified.deb && \
    service postgresql stop && \
    service supervisor stop && \
    chmod 755 /app/ds/*.sh && \
    rm -rf /build/ && \
    rm -rf /var/log/$COMPANY_NAME && \
    rm -rf /var/lib/apt/lists/*

VOLUME /var/log/$COMPANY_NAME /var/lib/$COMPANY_NAME /var/www/$COMPANY_NAME/Data /var/lib/postgresql /var/lib/rabbitmq /var/lib/redis /usr/share/fonts/truetype/custom

ENTRYPOINT ["/app/ds/run-document-server.sh"]
