#!/bin/bash

# Check if the yml exists
if [[ ! -f $file ]]; then
  echo "File $file doesn't exist!"
  exit 1
fi

# Run test environment
docker-compose -p ds -f $file up -d

wakeup_attempts=30
wakeup_timeout=5

for ((i=0; i<$wakeup_attempts; i++))
do
  # Get documentserver healthcheck status
  healthcheck_res=$(wget --no-check-certificate -qO - localhost/healthcheck)
  
  if [[ $healthcheck_res == "true" ]]; then
    break
  else
    echo "Wait for service wake up #$i"
    sleep $wakeup_timeout
  fi
done

# Fail if it isn't true
if [[ $healthcheck_res == "true" ]]; then
  echo "Healthcheck passed."
else
  echo "Healthcheck failed!"
  exit 1
fi

docker-compose -p ds -f $file down