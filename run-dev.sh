#!/bin/bash

DOCKER_HOST=10.19.88.248 \
DOCKER_PORT=2375 \
HTTP_PORT=8080 \
AUTH_TOKEN=authtoken \
ETCD_BASEURL=http://etcd1.isd.ictu:4001 \
DATA_DIR=/tmp/local/data \
SCRIPT_BASE_DIR=/tmp/local/data/scripts \
SHARED_DATA_DIR=/tmp/mnt/data \
ROOT_URL=http://localhost:8080 \
TARGET_VLAN=3080 \
SYSLOG_URL=udp://logstash.isd.ictu:5454 \
nodemon index.coffee
