# Developing on the producers platform

Here is how to develop for the producers platform using docker.

It suppose [you already have setup docker for dev](../introduction/dev-environment-quick-start-guide.md).

You should have two kind of shell:
- the shell for openfoodfacts
- the shell for openfoodfacts-pro, this is a shell where you have source the `setenv-pro.sh`,
  that is you run `. setenv-pro.sh`.
  Your prompt, should now contains a `(pro)` to recall you you are in producers environment.
  (this simply sets some environment variables that will overides the one in .env)

To develop, on producers plateform, you can then us a shell for openfoodfacts-pro and simply do a `make dev` and everything as usual.

If you need to work on product import/export, or interacting with public platform,
you have to start postgres and the minion on off side.
That is, in a *non pro* shell, run `docker-compose up postgres minion mongodb`.

Note that the setup does not currently support running the http server for both public and pro platform at the same time.
So as you need the public platform:
- in your *pro shell*, run a `docker-compose stop backend`
- in your *non pro shell*, run a `docker-compose up backend`
Now `openfoodfacts.localhost` is the public database.
Of course, do this inside-out to access the pro http server.

Note that if you [use direnv](./use-direnv.md), it should be fine, if you did not redefine variables set by `setenv-pro.sh`.

An explanation of the setup can be found at [pro-dev-setup.md](../explanations/pro-dev-setup.md)

If you want to see state of tasks, you can run:

```
docker-compose exec minion /opt/product-opener/scripts/minion_producers.pl  minion job
```
(add --help to see all options), or refer to https://docs.mojolicious.org/Minion/Command/minion/job

You may also inspect database by running:
```
docker-compose exec  postgres psql -U productopener -W minion
```
(password is given by `POSTGRES_PASSWORD` in `.env` and defaults to `productopener`)

Inspecting table minion, should help.
