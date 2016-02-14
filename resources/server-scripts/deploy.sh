#!/usr/bin/env bash
REPOSITORY=${DOCKER_REPOSITORY}
WEB_IMAGE=simple-server
CONSUL_IMAGE=simple-consul
HAPROXY_IMAGE=simple-haproxy
DOCKER_MACHINE_NAME=default
NETWORK_NAME=simple-network

# These can be modified by options/arguments
INCLUDE_SERVERS=true
INCLUDE_CONSUL=false
INCLUDE_LOAD_BALANCERS=false
SERVER_NAME_PREFIX=server

# A function that prints the help message
function print_usage {
  echo "Usage:"
  echo "  deploy.sh [-h|--help] [-c|--consul] [-l|--lb num_lbs] num_servers"
  echo
  echo "Options:"
  echo "  -h|--help            Display this help"
  echo "  -c|--consul          Whether to redeploy the consul servers"
  echo "  -l|--lb num          How many load balancers to deploy. Defaults to 0"
  echo "  --prefix             The prefix for the names of each server container"
  echo
  echo "Arguments:"
  echo "  num_servers          The number of servers to create"
}

# Process the options and arguments
if [[ $# == 0 ]]; then print_usage; exit 1; fi
while [[ $# > 0 ]] ; do key="$1"
case ${key} in
    -h|--help) print_usage; exit 0;;
    --prefix) SERVER_NAME_PREFIX=$2; shift;;
    -c|--consul) INCLUDE_CONSUL=true;;
    -l|--lb) INCLUDE_LOAD_BALANCERS=true; NUM_LOAD_BALANCERS=$2; shift;;
    -*) echo "Illegal Option: ${key}"; print_usage; exit 1;;
    *) break;
esac
shift
done

# Verify the options and arguments
reNumber='^[0-9]+$'
if [ ${INCLUDE_SERVERS} = true ]; then
  if [[ $1 =~ $reNumber ]]; then
    NUM_SERVERS=$1
  else
    echo "First arg must be a number. Received: '$1'"; print_usage; exit 1
  fi
fi

if [ ${INCLUDE_LOAD_BALANCERS} = true ]; then
  if ! [[ ${NUM_LOAD_BALANCERS} =~ $reNumber ]]; then
    echo "Argument to -l must be a number. Received: '${NUM_LOAD_BALANCERS}'"; print_usage; exit 1
  fi
fi

# Verify that the docker machine is running
if which docker-machine | grep -q /*/docker-machine; then
  echo "Connecting to Docker VM..."
  eval "$(docker-machine env ${DOCKER_MACHINE_NAME})"
fi

# Verify that the network has been created, and create it if not
if ! docker network ls | grep -q ${NETWORK_NAME}; then
  docker network create ${NETWORK_NAME}
fi

# Log in to Docker Hub
echo "Checking that you are logged in to docker hub..."
if ! docker info | grep -q Username; then
  echo "You must login to push to docker Hub (you only need to do this once):"
  docker login
else
  echo "Successfully logged in!"
fi





### CONSUL SERVERS
if [ ${INCLUDE_CONSUL} = true ]; then\

  echo "Deploying Consul Servers..."

  echo "Pulling latest consul server image..."
  docker pull ${REPOSITORY}/${CONSUL_IMAGE}

  echo "Cleaning up any existing containers..."
  if docker ps -a | grep -q simple_consul; then
    docker rm -f $(docker ps -a | grep simple_consul | cut -d ' ' -f1)
  else
    echo "No existing consul service to remove"
  fi

  echo "Starting new consul server containers..."
  for (( i=1; i<=5; i++ )); do
    docker run -d --net=${NETWORK_NAME} -p 850${i}:8500 -e NETWORK=${NETWORK_NAME} -e CONSUL_NODE_NUMBER=${i} --name simple_consul_${i} ${REPOSITORY}/${CONSUL_IMAGE} /usr/local/bin/consul-server-start.sh
  done

  echo "Giving consul servers a few seconds to elect someone..."
  sleep 5

  echo "  The ui is available on each server, under port 850X, where X is the server number"
  echo "  Eg: http://docker.host.address:8502/  is the ui served by host 2"

  echo "Finished deploying consul cluster!"
fi


### HA PROXY Servers
if [ ${INCLUDE_LOAD_BALANCERS} = true ]; then
  echo "Deploying Load Balancers..."

  echo "Pulling latest load balancer image..."
  docker pull ${REPOSITORY}/${HAPROXY_IMAGE}

  echo "Cleaning up any existing containers..."
  if docker ps -a | grep -q "simple_haproxy"; then
    docker rm -f $(docker ps -a | grep "simple_haproxy" | cut -d ' ' -f1)
  else
    echo "No existing load balancers to remove"
  fi

  echo "Starting new load balancer containers..."
  for (( i=1; i<=${NUM_LOAD_BALANCERS}; i++ )); do
    docker run -d --net=${NETWORK_NAME} -p 8${i}:80 -e CONSUL_NODE_NAME=haproxy_${i} -e CONSUL_SERVICE=simple-haproxy --name simple_haproxy_${i} ${REPOSITORY}/${HAPROXY_IMAGE} /bin/bash -c "rsyslogd -f /etc/syslog.d/haproxy.conf & consul-template -consul simple_consul_1:8500 -config /etc/consul-template.d/simple-haproxy/simple-haproxy.cfg"
  done
fi


### SIMPLE SERVERS
if [ ${INCLUDE_SERVERS} = true ]; then
  echo "Deploying Web Servers..."

  echo "Pulling latest server image..."
  docker pull ${REPOSITORY}/${WEB_IMAGE}

  echo "Cleaning up any existing containers..."
  if docker ps -a | grep -q ${SERVER_NAME_PREFIX}; then
    docker rm -f $(docker ps -a | grep ${SERVER_NAME_PREFIX} | cut -d ' ' -f1)
  else
    echo "No existing services to remove"
  fi

  echo "Starting new server containers..."
  for (( i=1; i<=${NUM_SERVERS}; i++ )); do
    docker run -d --net=${NETWORK_NAME} -e SIMPLE_SERVER_PORT=8080 -e CONSUL_NODE_NAME=${SERVER_NAME_PREFIX}_${i} -e CONSUL_SERVERS="simple_consul_1 simple_consul_2 simple_consul_3 simple_consul_4 simple_consul_5" -e CONSUL_SERVICE="simple-service" --name ${SERVER_NAME_PREFIX}_${i} ${REPOSITORY}/${WEB_IMAGE} /bin/bash -c "/usr/local/bin/consul-client-start.sh & /usr/local/lib/simple-service/runserver.sh"
  done
fi
