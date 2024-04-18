FROM mcr.microsoft.com/mssql/server:2022-latest as onlyoffice-mssql

ENV ACCEPT_EULA=Y \
    MSSQL_SA_PASSWORD="Onlyoffice1!"

ARG MSSQL_DATABASE="onlyoffice"
ARG MSSQL_USER="onlyoffice"
ARG MSSQL_PASSWORD="onlyoffice"

SHELL ["/bin/bash", "-c"]

RUN echo -e "#!/bin/bash\n/opt/mssql/bin/sqlservr &" > /tmp/run_mssql.sh && \
    bash /tmp/run_mssql.sh && \
    sleep 10 && \
    /opt/mssql-tools/bin/sqlcmd -S localhost,1433 -U SA -P "$MSSQL_SA_PASSWORD" -C -Q "IF NOT EXISTS (SELECT * FROM sys.sql_logins WHERE name = '$MSSQL_USER') BEGIN CREATE LOGIN $MSSQL_USER WITH PASSWORD = '$MSSQL_PASSWORD' , CHECK_POLICY = OFF; ALTER SERVER ROLE [dbcreator] ADD MEMBER [$MSSQL_USER]; END"
