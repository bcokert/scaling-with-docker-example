#!/usr/bin/env bash
ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/../..
SOURCE_DIR=${ROOT_DIR}/src
RESOURCE_DIR=${ROOT_DIR}/resources
DOCKERFILE_DIR=${RESOURCE_DIR}/dockerfiles
ARTIFACT_DIR=${ROOT_DIR}/build
OUTPUT_DIR=${ROOT_DIR}/release-consul-tmp
CONSUL_CONFIG_DIR=${RESOURCE_DIR}/consul.d
CONSUL_SCRIPTS_DIR=${RESOURCE_DIR}/consul-scripts

DOCKER_MACHINE_NAME=default
REPOSITORY=${DOCKER_REPOSITORY}
DOCKER_FILE_NAME=dockerfile-consul
IMAGE=simple-consul

# Some nice red text for the terminal
ERROR_TXT="\033[1m\033[41m\033[97mERROR:\033[0m"

echo "Checking that docker VM is available..."
if ! docker-machine ls | grep -q ${DOCKER_MACHINE_NAME}; then
  echo -e "${ERROR_TXT} Docker VM is not created. Please run 'docker-machine create --driver virtualbox ${DOCKER_MACHINE_NAME}'"
  exit 1
elif ! docker-machine ls | grep -q ${DOCKER_MACHINE_NAME}.*Running; then
  echo -e "${ERROR_TXT} Docker VM is not running. Please run 'docker-machine start ${DOCKER_MACHINE_NAME}'"
  exit 1
fi

echo "Cleaning any old release files..."
rm -rf ${OUTPUT_DIR}
mkdir ${OUTPUT_DIR}

echo "Preparing build artifacts for docker imaging..."
# Do any post-build setup here, like unzipping files
cp -r ${CONSUL_CONFIG_DIR} ${OUTPUT_DIR}
cp ${CONSUL_SCRIPTS_DIR}/* ${OUTPUT_DIR}
cp ${DOCKERFILE_DIR}/${DOCKER_FILE_NAME} ${OUTPUT_DIR}

echo "Connecting to Docker VM..."
eval "$(docker-machine env ${DOCKER_MACHINE_NAME})"

echo "Building Docker Image..."
docker build -t ${REPOSITORY}/${IMAGE}:latest -f ${OUTPUT_DIR}/${DOCKER_FILE_NAME} ${OUTPUT_DIR} || exit 1
docker images | grep ${IMAGE} # list our new images info

echo "Cleaning up build artifacts..."
rm -rf ${OUTPUT_DIR}

echo "Checking that you are logged in to docker hub..."
if ! docker info | grep -q Username; then
  echo "You must login to push to docker Hub (you only need to do this once):"
  docker login
else
  echo "Succesfully logged in!"
fi

echo "Pushing docker images..."
echo "If this fails saying it's already in progress, try 'docker-machine restart ${DOCKER_MACHINE_NAME}'"
docker push ${REPOSITORY}/${IMAGE}
