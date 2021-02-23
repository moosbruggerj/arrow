# ARRO(W)
__Analysation of Residual Rouge Overstress__

The goal of the project is to build a machine that calculates the wasted energy while shooting an arrow from a bow.
This is the software for the Arro(w) machine.
The calculation compares the energy input in form of potential energy into the bow and the kinetic energy of the arrow.
The purpose of the software is to control the physical actors and sensors and perform the calculation and presentation.

# Requirements
* Raspian
* Docker
* Rust
* Cargo

## Installation
1. Install dependencies
  - docker
  - `docker pull postgres`
  - `docker pull adminer` (dev only)

# Development setup
* `docker-compose -f dev_database.yml up -d`
  - shutdown: `docker-compose -f dev_database.yml down`
  - shutdown + delete database: `docker-compose -f dev_database.yml down --volumes`
* Database admin at `localhost:8080`, username `postgres`, database `arrow`, password irrelevant
* Building/running: `cargo build`/`cargo run`
  - To run with higher log level `cargo run -- -vvv`
  - To check SQL queries against database export `DATABASE_URL=postgres://arrow:<password>@localhost/arrow` before building
