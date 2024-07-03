#!/bin/bash

CONNECTION_STR="sqlplus sys/$ORACLE_PASSWORD@//localhost:1521/$ORACLE_DATABASE as sysdba"

export ORACLE_PWD=$ORACLE_PASSWORD

#start db
/opt/oracle/runOracle.sh &

#wait for db up
for (( i=1; i <= 20; i++ )); do
  RES=$(echo "SELECT version FROM V\$INSTANCE;" | $CONNECTION_STR 2>/dev/null | grep "Connected" | wc -l)
  if [ "$RES" -ne "0" ]; then
    echo "Database is ready"
    break
  fi
  sleep 10
done

sleep 1

#create new db user
$CONNECTION_STR <<EOF
CREATE USER $ORACLE_USER IDENTIFIED BY $ORACLE_PASSWORD;
GRANT CREATE SESSION TO $ORACLE_USER;
GRANT CREATE TABLE TO $ORACLE_USER; 
ALTER USER $ORACLE_USER quota unlimited on USERS;
EOF
