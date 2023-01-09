#!/bin/bash
# Get disql for remote access
  docker run -d -p 5236:5236 --restart=always --name dm8_01 --privileged=true -e PAGE_SIZE=16 -e LD_LIBRARY_PATH=/opt/dmdbms/bin -e INSTANCE_NAME=dm8_01 dm8_single:v8.1.2.128_ent_x86_64_ctm_pack4
  echo "Disql bin will be copied from dm8 container. Please wait couple of minutes"
  sleep 60
  docker cp dm8_01:/opt/dmdbms/bin .
  echo "OK: Files was copy"
  docker stop dm8_01 ; docker rm dm8_01
  echo "OK: Disql bin files ready"
