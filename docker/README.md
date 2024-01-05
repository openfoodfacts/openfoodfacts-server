# Reference Docker / Makefile commands

<!--
NOTE: this file is copied to ref-docker-commands.md at documentation build time
-->

See also [Docker best practice at Open Food Facts](https://openfoodfacts.github.io/openfoodfacts-infrastructure/docker/)

The docker/ directory contains `docker compose` overrides for running Product Opener on [Docker](https://docker.com).
The main docker compose file [`docker-compose.yml`](../docker-compose.yml) is located in the root of the repository.

The step-by-step guide to setup the Product Opener using Docker is available on [dev environment quick start guide](../docs/dev/how-to-quick-start-guide.md).

## Makefile targets

Makefile targets are handy for beginners to start the project and for some usual tasks.

It's better though, as you progress, if you understand how things work and be able to use targeted docker compose commands.

See also [targets to run tests](../docs/dev/how-to-write-and-run-tests.md#running-tests)

| Command                   | Description                                                                            | Notes                                                         |
| ------------------------- | -------------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| `make dev`                | Setup a fresh dev environment.                                                        | Run only once, then use the `up`, `down`, `restart` commands. |
| `make up`                 | Start containers.                                                                      |                                                               |
| `make down`               | Stop containers and keep the volumes.                                                  | Products and users data will be kept.                         |
| `make hdown`              | Stop containers and delete the volumes (hard down).                                    | Products and users data will be lost !                        |
| `make restart`            | Restart `frontend` and `backend` containers.                                           |                                                               |
| `make reset`              | Run `hdown` and `up`.                                                                  |                                                               |
| `make status`             | Get containers status (up, down, fail).                                                |                                                               |
| `make log`                | Get logs.                                                                              | Include only logs written to container's `stdout`.            |
| `make tail`               | Get other logs (`Apache`, `mod_perl`, ...) bound to the local `logs/` directory.       |                                                               |
| `make prune`              | Save space by removing unused Docker artifacts.                                        | Next build will take time (no cache) !                        |
| `make prune_cache`        | Remove Docker build cache.                                                             | Next build will take time (no build cache) !                  |
| `make clean`              | Clean up your dev environment: removes locally bound folders, run `hdown` and `prune`. | Run `make dev` to recreate a fresh dev env afterwards.        |
| `make import_sample_data` | Load sample data (~100 products) into the MongoDB database.                            |                                                               |
| `make import_prod_data`   | Load latest prod data (~2M products, 1.7GB) into the MongoDB database.                 | Takes up to 10m. Not recommended for dev setups !             |
| `make lint`      | Indent and reformat your code[^lint]                       |

[^lint]: If you are having permission issues with `make lint` try writing the following commands :
`export MSYS_NO_PATHCONV=1
docker compose run --rm --no-deps -u root backend chown www-data:www-data -R /opt/product-opener/`
then run again `make lint` and you should be good to go

