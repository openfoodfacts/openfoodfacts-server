# How to develop on the producers platform

Here is how to develop for the producers platform using docker.

### Prerequisites:

- Docker should already be [set up for development.](how-to-quick-start-guide.md).

### Shell Setup:
You will need two types of shells:
- Shell for OpenFoodFacts:
  - Use this shell for general development on the OpenFoodFacts platform.
- Shell for OpenFoodFacts-Pro: Use this shell when working on the OpenFoodFacts-Pro platform.
  - To set up the shell, source the `setenv-pro.sh` file by running the command: `. setenv-pro.sh`.
  - Once the shell is set up, your prompt will show `(pro)` to indicate that you are in the producers environment.(this simply sets some environment variables that will overides the one in `.env`)

### Development Workflow:
To develop on the producers platform, follow these steps:

- Open a shell for OpenFoodFacts-Pro.
- Run the command `make dev` to start the development environment. This command functions as usual.
  - If you encounter any issues with CSS not showing up, you can run `make build_lang` in the *pro* shell.

### Working with Product Import/Export and Interacting with the Public Platform:
If you need to work on product import/export or interact with the public platform, you must start the following services: `PostgreSQL`, `MongoDB`, and the `Minion`. Here's how:

- In a *non-pro* shell (OpenFoodFacts shell), run the command `docker compose up postgres minion mongodb`.
  - This command starts the necessary services in the background.

#### Note: The setup does not currently support running the http server for both public and pro platform at the same simultaneously. Therefore, to access the public platform, you need to follow these steps:

- in your *pro shell*, run a `docker compose stop frontend`
- in your *non pro shell*, run a `docker compose up frontend`
Now, the public database can be accessed at `openfoodfacts.localhost`.If you need to access the *pro* HTTP server, reverse these steps.

Note that if you [use direnv](how-to-use-direnv.md), the setup should work seamlessly without redefining the variables set by `setenv-pro.sh`.

An explanation of the setup can be found at [explain-pro-dev-setup.md](explain-pro-dev-setup.md)

- If you want to see state of tasks, you can run:

```
docker compose exec minion /opt/product-opener/scripts/minion_producers.pl  minion job
```
(add --help to see all options), or refer to https://docs.mojolicious.org/Minion/Command/minion/job

- You may also inspect database by running:
```
docker compose exec  postgres psql -U productopener -W minion
```
The password is given by the `POSTGRES_PASSWORD` variable in the `.env` file and defaults to `productopener`. 
Inspecting the minion table can be helpful in understanding the database structure and contents.
