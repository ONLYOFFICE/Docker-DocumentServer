FROM container-registry.oracle.com/database/express:21.3.0-xe as onlyoffice-oracle

ARG ORACLE_DATABASE=
ARG ORACLE_PASSWORD=
ARG ORACLE_USER=

ENV ORACLE_DATABASE=$ORACLE_DATABASE \
    ORACLE_PASSWORD=$ORACLE_PASSWORD \
    ORACLE_USER=$ORACLE_USER

SHELL ["/bin/bash", "-c"]

COPY create_db_user.sh /tmp/create_db_user.sh

RUN bash /tmp/create_db_user.sh
