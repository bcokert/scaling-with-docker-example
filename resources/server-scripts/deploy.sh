#!/usr/bin/env bash
REPOSITORY=${DOCKER_REPOSITORY}
WEB_IMAGE=simple-server
DOCKER_MACHINE_NAME=default
NETWORK_NAME=network

# These can be modified by options/arguments
INCLUDE_SERVERS=true
SERVER_NAME_PREFIX=server

# A function that prints the help message
function print_usage {
  echo "Usage:"
  echo "  deploy.sh [-h|--help] num_servers"
  echo
  echo "Options:"
  echo "  -h|--help            Display this help"
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
    docker run -d --net=${NETWORK_NAME} -e SIMPLE_SERVER_PORT=8080 --name ${SERVER_NAME_PREFIX}_${i} ${REPOSITORY}/${WEB_IMAGE} /usr/local/lib/simple-service/runserver.sh
  done
fi
