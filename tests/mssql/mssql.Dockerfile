FROM mcr.microsoft.com/mssql/server:2022-latest as onlyoffice-mssql

ENV ACCEPT_EULA=Y

SHELL ["/bin/bash", "-c"]

COPY create_db_user.sh /tmp/create_db_user.sh

RUN bash /tmp/create_db_user.sh
