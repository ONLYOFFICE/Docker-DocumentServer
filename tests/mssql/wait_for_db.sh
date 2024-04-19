#!/bin/bash

for (( i=1; i <= 10; i++ )); do
  RES=$($CONNECTION_STR "SELECT @@VERSION;" 2>/dev/null | grep "affected" | wc -l)
  if [ "$RES" -eq "1" ]; then
    echo "Database is ready"
    break
  fi
  sleep 5
done
