#!/bin/bash

private_key=tls.key
certificate_request=tls.csr
certificate=tls.crt

# Generate certificate
openssl genrsa -out ${private_key} 2048
openssl req \
  -new \
  -key ${private_key} \
  -out ${certificate_request}
openssl x509 \
  -req \
  -days 365 \
  -in ${certificate_request} \
  -signkey ${private_key} \
  -out ${certificate}

# Strengthening the server security
openssl dhparam -out dhparam.pem 2048

mkdir -p /app/onlyoffice/DocumentServer/data/certs
cp $private_key /app/onlyoffice/DocumentServer/data/certs/
cp $certificate /app/onlyoffice/DocumentServer/data/certs/
cp dhparam.pem /app/onlyoffice/DocumentServer/data/certs/
chmod 400 /app/onlyoffice/DocumentServer/data/certs/$private_key

# Check if the yml exists
if [[ ! -f $config ]]; then
  echo "File $config doesn't exist!"
  exit 1
fi

# Run test environment
docker-compose -p ds -f $config up -d

wakeup_timeout=30

# Get documentserver healthcheck status
echo "Wait for service wake up"
sleep $wakeup_timeout
healthcheck_res=$(wget --no-check-certificate -qO - localhost/healthcheck)

# Fail if it isn't true
if [[ $healthcheck_res == "true" ]]; then
  echo "Healthcheck passed."
else
  echo "Healthcheck failed!"
  exit 1
fi

docker-compose -p ds -f $config down
