# Dashboard Agent

[![Build Status](https://circleci.com/gh/ICTU/docker-agent/tree/master.png?style=shield&circle-token=e323d5e59ad078bd93fcaa50b3201518047dd6c4)](https://circleci.com/gh/ICTU/docker-agent/tree/master)

An agent implementation for [ICTU/docker-dashboard](https://github.com/ICTU/docker-dashboard).

## How to run

    docker run \
      -e AUTH_TOKEN=1234 \
      -e DOCKER_SOCKET_PATH=/var/run/docker.sock \
      -e HTTP_PORT=80 \
      -e ROOT_URL=http://hostnameofagent \
      -e ETCD_BASEURL=http://etcdhost:4001 \
      -e DATA_DIR=/local/data \
      -e SCRIPT_BASE_DIR=/local/data/scripts \
      -e SHARED_DATA_DIR=/mnt/shareddata \
      -e TARGET_VLAN=3030 \
      -e SYSLOG_URL=udp://logstashhost:5454 \
      -v /local/data:/local/data \
      -v /mnt/data:/mnt/data
      -v /var/run/docker.sock:/var/run/docker.sock
      --name dashboard-agent
      ictu/dashboard-agent:script-gen

## Contributing

If you want to contribute please fork the repo and submit a pull request in
order to get your changes merged into the main branch.

### Development

Below you find an example of how to run the agent for development.

    DOCKER_HOST=<IP_OF_HOST>:<PORT_OF_HOST> \
    HTTP_PORT=8080 \
    AUTH_TOKEN=infra \
    ETCD_BASEURL=http://<ETCD_HOST>:4001 \
    DATA_DIR=/tmp/local/data \
    SCRIPT_BASE_DIR=/tmp/local/data/scripts \
    SHARED_DATA_DIR=/tmp/mnt/data \
    ROOT_URL=http://localhost:8080 \
    TARGET_VLAN=<VLAN> \
    SYSLOG_URL=udp://<LOGSTASH_HOST:5454 \
    nodemon index.coffee
