#!/bin/bash

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
