#!/bin/bash

#generate SA password
SYMBOLS='!#$%&*+,-.:;=?@^_~'
for (( i=1; i <= 20; i++ )); do
  PASS=$(tr -dc "A-Za-z0-9$SYMBOLS" </dev/urandom | head -c 15)
  if [[ $PASS == *[0-9]* && 
        $PASS != $(echo "$PASS" | tr [:upper:] ' ') && 
        $PASS != $(echo "$PASS" | tr [:lower:] ' ') && 
        $PASS != $(echo "$PASS" | tr "$SYMBOLS" ' ') ]]; then
    break
  fi
done
export MSSQL_SA_PASSWORD=$PASS

CONNECTION_STR="/opt/mssql-tools/bin/sqlcmd -S localhost,1433 -U SA -P "$MSSQL_SA_PASSWORD" -C -Q"

#start db
/opt/mssql/bin/sqlservr &

#wait for db up
for (( i=1; i <= 10; i++ )); do
  RES=$($CONNECTION_STR "SELECT @@VERSION;" 2>/dev/null | grep "affected" | wc -l)
  if [ "$RES" -eq "1" ]; then
    echo "Database is ready"
    break
  fi
  sleep 10
done

#create new db user
$CONNECTION_STR "IF NOT EXISTS (SELECT * FROM sys.sql_logins WHERE name = '$MSSQL_USER') BEGIN CREATE LOGIN $MSSQL_USER WITH PASSWORD = '$MSSQL_PASSWORD' , CHECK_POLICY = OFF; ALTER SERVER ROLE [dbcreator] ADD MEMBER [$MSSQL_USER]; END"
