# How to develop with WebComponents

If you are developing a new WebComponent in openfoodfacts-webcomponents project,
you might want to test its integration immediately.

To do this you can use the following steps:

We need to include the dev-webcomponents.yml file in the docker-compose.yml file.

Edit your .env to add the following line:
```ini
COMPOSE_FILE_BUILD=docker-compose.yml;docker/dev.yml;docker/dev-webcomponents.yml
COMPOSE_FILE=docker-compose.yml;docker/dev.yml;docker/dev-webcomponents.yml;docker/run.yml
```

If your project is located, relatively to your openfoodfacts-server project,
at `../openfoodfacts-webcomponents`, you are all set,
otherwise you need to define the `WEBCOMPONENTS_DIR` in your .env file
to point to  the right relative location.

BEWARE: not to commit you .env changes !

## If you want to use envrc

There is a caveat if you [use the .envrc file](./how-to-use-direnv.md)
(which as the advantage to be ignored by git),
because, in `.env` we define the separator between the different `COMPOSE_FILE` to be `;`
which does not work with the `.envrc` syntax.
So you have to define the `COMPOSE_FILE` variable in your `.envrc` file to be `:`.
Which means the changes in your .envrc should be:

```bash
# eventually use this if your location is distinct
# export WEBCOMPONENTS_DIR=../openfoodfacts-webcomponents
export COMPOSE_PATH_SEPARATOR=:
export COMPOSE_FILE_BUILD=docker-compose.yml:docker/dev.yml:docker/dev-webcomponents.yml
export COMPOSE_FILE=docker-compose.yml:docker/dev.yml:docker/dev-webcomponents.yml:docker/run.yml
```