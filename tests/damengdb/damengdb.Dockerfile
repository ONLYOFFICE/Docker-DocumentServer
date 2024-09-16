FROM onlyoffice/damengdb:8.1.2 as damengdb

ARG DM8_USER="SYSDBA"
ARG DM8_PASS="SYSDBA001"
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
CONN SYSDBA/SYSDBA001@localhost
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

RUN   bash /opt/startup.sh > /dev/null 2>&1 \
   &  mkdir -p /schema/damengdb \
   && apt update -y ; apt install wget -y \
   && wget https://raw.githubusercontent.com/ONLYOFFICE/server/master/schema/dameng/createdb.sql -P /schema/dameng/ \
   && bash ./wait_dm_ready.sh \
   && cd ${DISQL_BIN} \
   && ./disql $DM8_USER/$DM8_PASS@$DB_HOST:$DB_PORT -e \
      "create user "onlyoffice" identified by "onlyoffice" password_policy 0;" \
   && ./disql $DM8_USER/$DM8_PASS@$DB_HOST:$DB_PORT -e \
      "GRANT SELECT ON DBA_TAB_COLUMNS TO onlyoffice;" \
   && echo "EXIT" | tee -a /schema/dameng/createdb.sql \
   && ./disql $DM8_USER/$DM8_PASS@$DB_HOST:$DB_PORT \`/schema/dameng/createdb.sql \
   && ./disql $DM8_USER/$DM8_PASS@$DB_HOST:$DB_PORT \`/permissions.sql \
   && sleep 10
