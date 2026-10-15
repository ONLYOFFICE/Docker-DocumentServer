FROM onlyoffice/documentserver-ee:latest as schema-source

FROM onlyoffice/damengdb:8.1.3 as damengdb

ARG DM8_USER="SYSDBA"
ARG DM8_PASS="SYSDBA_dm001"
ARG DB_HOST="localhost"
ARG DB_PORT="5236"
ARG DISQL_BIN="/opt/dmdbms/bin"

SHELL ["/bin/bash", "-c"]

COPY <<"EOF" /wait_dm_ready.sh
#!/usr/bin/env bash

function wait_dm_ready() {
  cd /opt/dmdbms/bin
  for i in `seq 1  10`; do
    echo `./disql /nolog <<EOF
CONN SYSDBA/SYSDBA_dm001@localhost
exit
EOF` | grep  "connection failure" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      echo "DM Database is not OK, please wait..."
      sleep 10
    else
      echo "DM Database is OK"
      break
    fi
  done
}

wait_dm_ready

EOF

COPY <<"EOF" /permissions.sql

CREATE SYNONYM onlyoffice.DOC_CHANGES FOR sysdba.DOC_CHANGES;
CREATE SYNONYM onlyoffice.TASK_RESULT FOR sysdba.TASK_RESULT;
GRANT ALL PRIVILEGES ON sysdba.DOC_CHANGES TO onlyoffice;
GRANT ALL PRIVILEGES ON sysdba.TASK_RESULT TO onlyoffice;

EOF

RUN mkdir -p /schema/dameng

COPY --from=schema-source /var/www/onlyoffice/documentserver/server/schema/dameng/createdb.sql /schema/dameng/createdb.sql

ARG OO_DB_USER="onlyoffice"
ARG OO_DB_PASS="Onlyoffice_2026"

RUN   bash /opt/startup.sh > /dev/null 2>&1 \
   &  mkdir -p /schema/damengdb \
   && export DEBIAN_FRONTEND=noninteractive \
   && apt-get update \
   && rm -rf /var/lib/apt/lists/* \
   && bash ./wait_dm_ready.sh \
   && cd ${DISQL_BIN} \
   && ./disql $DM8_USER/$DM8_PASS@$DB_HOST:$DB_PORT -e \
      "create user \"${OO_DB_USER}\" identified by \"${OO_DB_PASS}\";" \
   && ./disql $DM8_USER/$DM8_PASS@$DB_HOST:$DB_PORT -e \
      "GRANT SELECT ON DBA_TAB_COLUMNS TO onlyoffice;" \
   && echo "EXIT" | tee -a /schema/dameng/createdb.sql \
   && ./disql $DM8_USER/$DM8_PASS@$DB_HOST:$DB_PORT \`/schema/dameng/createdb.sql \
   && ./disql $DM8_USER/$DM8_PASS@$DB_HOST:$DB_PORT \`/permissions.sql \
   && sleep 10
