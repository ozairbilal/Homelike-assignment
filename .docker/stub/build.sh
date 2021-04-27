#!/usr/bin/env bash

IMAGE=`basename \`pwd\``

$(aws ecr get-login --no-include-email)

docker build -t "${AWS_REPOSITORY}/${IMAGE}:latest" --no-cache . || exit 1
docker push     "${AWS_REPOSITORY}/${IMAGE}:latest" || exit 1

docker rmi      "${AWS_REPOSITORY}/${IMAGE}:latest"
docker rmi       "ubuntu:latest"
