#!/bin/bash
# Download dameng image 
        wget -O dm8_docker.tar -c https://download.dameng.com/eco/dm8/dm8_20220822_rev166351_x86_rh6_64_ctm.tar
        docker load -i dm8_docker.tar
        echo "OK: Dameng image already downloaded"
	rm -rf dm8_docker.tar
