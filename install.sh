#!/bin/bash

IMAGE=pi-docker-test
DB_IMAGE=arrow-db-pi

docker load -i ${IMAGE}.tar
docker load -i ${DB_IMAGE}.tar
echo "done"
