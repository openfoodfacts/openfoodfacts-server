# How to run several worktrees (or several agents) on one machine

By default every dev environment on a machine shares the same Docker names: the
`product-opener` network, the `po_users` / `po_orgs` / `po_export_files` /
`po_off_product_images` volumes, the `openfoodfacts-server/*:dev` images and host
port 80.

That is fine for a single checkout, but it breaks as soon as two worktrees (for
example two AI agents editing the same repository) run `make dev` at the same
time:

* the second one cannot bind host port 80;
* both join the same network, and Docker DNS answers `backend`, `frontend`,
  `postgres`, `world.openfoodfacts.localhost`… for **both** of them, so requests
  are round-robined between worktrees;
* they share the users, orgs and product images volumes, so `make hdown` in one
  destroys the other's data, and a change to the `.sto` format in one breaks the
  other.

This guide shows how to give each worktree its own names, domain and port.

## Quick start

Once per worktree, from the repository root:

```bash
make agent
make dev
```

That is the whole procedure. **You do not have to choose an id and you do not
have to check what is free** — which is the point, because agents cannot ask each
other. `make agent`:

* derives an id from the worktree directory name (`../off/11790` → `w11790`),
* claims it atomically, so two agents starting at the same moment get different
  ids rather than both settling on the same one,
* allocates the first free host port from 8081, claimed the same atomic way,
* reuses the same id and port if the worktree already has them, so the URL is
  stable across re-runs.

It prints what it settled on:

```text
🥫 Worktree 'w11790' is now isolated.
  URL: http://world.w11790.openfoodfacts.localhost:8081/
```

In a second worktree, run exactly the same two commands; the directory name is
different, so it gets its own id and port without any coordination.

### Seeing what is already taken

```bash
make list-agents
```

```text
ID             PORT    DIRECTORY
 w11790        8081    /home/me/off/11790
* w11790-2     8082    /home/me/off/11790-fix
  fix-tags     9001    /home/me/off/tags
```

`*` marks an id whose Docker network still exists, so it is really in use. The
registry lives in `~/.cache/off-agents` and is per user, so a worktree belonging
to another user of the same machine would not be listed — Docker itself remains
the authority.

### When you do want to choose

```bash
make agent ID=b2              # refused if another worktree already owns 'b2'
make agent ID=b2 PORT=9000    # and pick the port too
make agent PORT=9000          # keep the derived id, choose the port
```

`ID` accepts lowercase letters, digits and dashes. Asking for an id that another
worktree already owns is refused rather than silently shared, because that would
make both worktrees use the same volumes. If the other worktree no longer exists
and you want its slot back:

```bash
make release-agent ID=b2
```

To undo isolation for the current worktree, `make release-agent` removes the
generated block and frees the port. The suffixed images, volumes and containers
stay on disk until `make prune`.

Only 19 ports (8081-8099) are handed out by default, so a 20th concurrent
worktree has to pass `PORT=`.

### What gets written

`make agent` writes a **generated, git-ignored block** to `.envrc`. It replaces
that block on every run and leaves any other line you put in `.envrc` (such as
`USER_UID`, `CPANMOPTS` or `DEPS_DIR`) untouched.

To check what a worktree resolved to:

```bash
make print-agent-config
```

## What gets isolated

Taking `w11790` as the example, in addition to everything `COMPOSE_PROJECT_NAME`
already covers:

| Resource | Default | With id `w11790` |
| --- | --- | --- |
| compose project | `po_off` | `po_off_w11790` |
| default network | `product-opener` | `product-opener_w11790` |
| `minion_db` network | `minion_db` | `w11790_minion_db` |
| `users` volume | `po_users` | `w11790_po_users` |
| `orgs` volume | `po_orgs` | `w11790_po_orgs` |
| `export_files` volume | `po_export_files` | `w11790_po_export_files` |
| `product_images` volume | `po_off_product_images` | `w11790_po_off_product_images` |
| images | `openfoodfacts-server/backend:dev` | `openfoodfacts-server/backend:dev_w11790` |
| domain | `openfoodfacts.localhost` | `w11790.openfoodfacts.localhost` |
| host port | `80` | `8081` (allocated) |

The project-scoped volumes (`podata`, `build_cache`, `node_modules`,
`icons_dist`, `js_dist`, `css_dist`, `pgdata`, `html_data`, `products`) already
followed `COMPOSE_PROJECT_NAME`, so they are covered too.

### What is deliberately *not* isolated

MongoDB, Redis, PostgreSQL, Keycloak and the SMTP server come from
`deps/openfoodfacts-shared-services` and `deps/openfoodfacts-auth`. Those pin
their own compose project names (`off_shared`, `openfoodfacts-auth`), so **all
worktrees already share them**, and there is no need to suffix them. This is also
what keeps the memory footprint sane: the `backend` container alone wants about
6 GB, so running one full stack per worktree does not scale.

Sharing MongoDB is convenient (the sample data and any imported production data
are available everywhere). The volumes that are isolated are the ones holding
state that is tied to a specific code checkout: users, orgs and product images.

### `/etc/hosts` is not needed

`a1.openfoodfacts.localhost` and all its subdomains resolve to `127.0.0.1`
on their own in current browsers, because `*.localhost` is special-cased
(RFC 6761). Tools that do not special-case it (`curl`, `wget`, some resolvers)
still need an entry:

```text
127.0.0.1 world.a1.openfoodfacts.localhost auth.a1.openfoodfacts.localhost
```

Only add the entries you actually need; `make edit_etc_hosts` handles the default
domain.

## Two guards, so mistakes are loud

* If `PO_AGENT_ID` is set but the host port is still 80, `make up` / `make dev`
  refuse to start instead of silently fighting over the port. Set
  `ALLOW_SHARED_PORT=1` to bypass deliberately.
* If `PRODUCT_OPENER_HOST_PORT` and `PRODUCT_OPENER_PORT` disagree, startup is
  refused too: `Config2_docker.pm` derives its server domain from
  `PRODUCT_OPENER_PORT`, so a mismatch makes the application generate URLs and
  redirects pointing at the wrong port. `make agent` always writes both.

## How it works

`PO_AGENT_ID` is the single knob. `make agent` writes it to `.envrc`, and:

* the **Makefile** derives `COMPOSE_PROJECT_NAME`, `PRODUCT_OPENER_DOMAIN` and
  `MINION_QUEUE` by appending the id. It does this *only* in the Makefile, so
  `make agent` must not write them as well or the prefix would be applied twice.
* `scripts/dev-agent-env.sh` keeps a small registry (`~/.cache/off-agents`) of
  id to port and directory, and claims entries by creating a file with
  `set -o noclobber`, which is atomic on POSIX filesystems. If a run fails after
  claiming, the claim is given back, so the registry never keeps a worktree that
  has no port.
* the **compose files** derive network, volume and image names from
  `PO_AGENT_PREFIX` / `PO_AGENT_SUFFIX`, which the Makefile computes from the id.
  Compose's `${VAR:+word}` treats an *empty but set* variable as true, which
  would produce names such as `product-opener_`, so the Makefile always passes a
  real value and the compose files use the empty-safe `${VAR:-}` form.

Everything is optional: with `PO_AGENT_ID` unset, all of these resolve to the
historical names, byte for byte.

`.github/scripts/check_worktree_isolation.sh` asserts all of it in CI — that the
default configuration is unchanged, that an isolated worktree is fully suffixed,
that five worktrees racing for the same directory name still get distinct ids and
ports, and that an id owned by another worktree is refused. You can run it
locally at any time.

### Shell variables do not override `.env` for `make`

The quick start guide notes that shell variables take precedence over `.env`. That
is true for `docker compose`, but **not** for `make`: the `Makefile` includes
`.env`, and an assignment in a makefile always wins over an inherited environment
variable. So put per-worktree overrides in `.envrc` (which is included after
`.env`), not in your shell.

If you use [direnv](how-to-use-direnv.md), `.envrc` is loaded automatically, which
also makes raw `docker compose` commands see the prefix.

## Other things worth knowing

* **One branch per worktree.** `pull_request.yml` uses
  `concurrency: {workflow}-{ref}` with `cancel-in-progress: true`, so two agents
  pushing to the *same* branch cancel each other's CI run. Separate worktrees
  normally mean separate branches, which do not collide.
* **Share `deps/`.** `DEPS_DIR` defaults to `$(PWD)/deps`, so each worktree
  re-clones about 2 GB of dependency repositories. To share one copy, add
  `export DEPS_DIR=~/off-deps` to `.envrc`; the `Makefile` honours an existing
  `DEPS_DIR` and the test compose files reference it.
* **RAM.** Budget roughly one `backend` container (about 6 GB) per worktree.
  Three concurrent worktrees is usually the practical limit.
* **Devcontainer.** `.devcontainer/devcontainer.json` forwards `PO_AGENT_ID` and
  the two affixes into the container, but the *host-side* compose invocation is
  what decides container and volume names. Export the variables in your shell
  (or use direnv) before reopening the folder in the devcontainer, otherwise the
  devcontainer silently falls back to the shared names.
* **Tests** keep using their own project name and `PO_COMMON_PREFIX=test_`. If
  `PO_AGENT_ID` is set in your shell they simply become suffixed too, which is
  harmless: the test project name becomes `po_off_w11790_test`.

## See also

* [Dev environment quick start guide](how-to-quick-start-guide.md)
* [How to develop using Docker](how-to-develop-using-docker.md) — running several
  OFF flavours (`obf`, `opf`, `opff`) side by side, which uses a different
  mechanism (`ENV_FILE` / `env/setenv.sh`)
* [How to use direnv](how-to-use-direnv.md)
* [How to write and run tests](how-to-write-and-run-tests.md)