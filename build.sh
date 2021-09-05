#!/bin/bash

IMAGE=arrow-pi
DB_IMAGE=arrow-db-pi

set -e


#cd ./arrow-ctl/ && cargo sqlx prepare --check || exit "sqlx database out of sync"
#cd ..

COMPOSE_DOCKER_CLI_BUILD=1 DOCKER_BUILDKIT=1 docker-compose -f docker-compose.yml build
docker save -o ${IMAGE}.tar ${IMAGE}
docker save -o ${DB_IMAGE}.tar ${DB_IMAGE}
tar -czf ${IMAGE}-dist.tar.gz ${IMAGE}.tar ${DB_IMAGE}.tar install.sh docker-compose.yml
rm ${IMAGE}.tar
rm ${DB_IMAGE}.tar
echo "done"
