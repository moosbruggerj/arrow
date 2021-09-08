# ARRO(W)
__Analysation of Residual Rouge Overstress__

The goal of the project is to build a machine that calculates the wasted energy while shooting an arrow from a bow.
This is the software for the Arro(w) machine.
The calculation compares the energy input in form of potential energy into the bow and the kinetic energy of the arrow.
The purpose of the software is to control the physical actors and sensors and perform the calculation and presentation.

# Requirements
* Raspian
* Docker
* Docker-Compose
* Rust (dev only)
* Cargo (dev only)

## Installation
1. Install dependencies
  - docker
  - `docker pull postgres`
  - `docker pull adminer` (dev only)
  - docker-compose

# Development setup
* `docker-compose -f dev_database.yml up -d`
  - shutdown: `docker-compose -f dev_database.yml down`
  - shutdown + delete database: `docker-compose -f dev_database.yml down --volumes`
* Database admin at `localhost:8080`, username `postgres`, database `arrow`, password irrelevant
* Building/running: `cargo build`/`cargo run`
  - To run with higher log level `cargo run -- -vvv`
  - To check SQL queries against database export `DATABASE_URL=postgres://arrow:<password>@localhost/arrow` before building, the build fails otherwise.

# Deployment on Raspberry Pi
To deploy on the raspberry pi, the sql schema of the database must be correct in `arrow-ctl/sqlx-data.json`.
This file is needed so the database interfacing code can be built in 'offline' mode.
It can be generated with `cd arrow-ctl && cargo sqlx prepare` and checked with `cd arrow-ctl && cargo sqlx prepare --check`.
For this to work the development database must be running.

The build script `./build.sh` compiles the project for the armv7 (raspberry pi 4) architecture and bundles it in the `arrow-pi` image.
Afterwards the postgres docker container is downloaded and with the database schema the `arrow-db-pi` image is built.
The database gets initialized on first startup.
Those two images get bundled in the `arrow-pi.tar.gz` with the `install.sh` script and the `docker-compose.yml`.

To run the project on the raspberry pi, copy the bundle, untar it and run `install.sh`.
This imports the images in docker.
It is then started with `docker-compose up -d`.
