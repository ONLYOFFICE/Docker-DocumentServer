FROM onlyoffice/documentserver-ee:latest

RUN sed -i '/trap clean_exit SIGTERM/s/^/#/' /app/ds/run-document-server.sh

