FROM ubuntu:14.04
MAINTAINER Ascensio System SIA <support@onlyoffice.com>

ENV LANG en_US.UTF-8  
ENV LANGUAGE en_US:en  
ENV LC_ALL en_US.UTF-8 

RUN apt-get update && apt-get -y -q install libreoffice 

RUN echo "#!/bin/sh\nexit 0" > /usr/sbin/policy-rc.d && \
    echo "deb http://static.teamlab.com.s3.amazonaws.com/repo/debian/ squeeze main" >>  /etc/apt/sources.list && \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys D9D0BF019CC8AC0D && \
    echo "deb http://download.mono-project.com/repo/debian wheezy/snapshots/3.12.0  main" | sudo tee /etc/apt/sources.list.d/mono-xamarin.list && \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF && \
    echo "deb http://archive.ubuntu.com/ubuntu precise main universe multiverse" >> /etc/apt/sources.list && \
    DEBIAN_FRONTEND=noninteractive  && \
    locale-gen en_US.UTF-8 && \
    apt-get -y update && \
    echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections && \
    apt-get install --force-yes -yq software-properties-common && \
    add-apt-repository ppa:ubuntu-toolchain-r/test && \
    apt-get -y update && \
    apt-get --force-yes -yq install gcc-4.9 onlyoffice-documentserver nano htop && \
    rm -rf /var/lib/apt/lists/*

ADD config /app/onlyoffice/setup/config/
ADD run-document-server.sh /app/onlyoffice/run-document-server.sh
RUN chmod 755 /app/onlyoffice/*.sh

VOLUME ["/var/log/onlyoffice"]
VOLUME ["/var/www/onlyoffice/Data"]

EXPOSE 80
EXPOSE 443

CMD bash -C '/app/onlyoffice/run-document-server.sh';'bash'
