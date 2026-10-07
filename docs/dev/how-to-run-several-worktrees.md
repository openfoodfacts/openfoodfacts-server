# How to run several worktrees (or several agents) on one machine

By default every dev environment on a machine shares the same Docker names: the
`product-opener` network, the `po_users` / `po_orgs` / `po_export_files` /
`po_off_product_images` volumes, the `openfoodfacts-server/*:dev` images, host
port 80, and the MongoDB / Redis / PostgreSQL / Keycloak stack from `deps/`.

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
* claims a **slot** for it atomically, so two agents starting at the same moment
  get different ids rather than both settling on the same one,
* derives every host port it needs from that slot, and skips a slot whose ports
  something else already holds,
* reuses the same id and slot if the worktree already has them, so the URL is
  stable across re-runs.

It prints what it settled on:

```text
🥫 Worktree 'w11790' is now isolated (slot 1).

  .envrc updated (git-ignored, it is a local file).

  URL:        http://world.w11790.openfoodfacts.localhost:8081/
  frontend:   8081
  mongodb:    8181
  postgres:   8281
  redis:      8381
  keycloak:   8481
  smtp4dev:   8681

  dependencies: MongoDB, Redis, PostgreSQL and Keycloak get their own containers
  and their own network (off_shared_network_w11790). Set PO_SHARED_DATA=1 in .envrc
  to go back to one shared stack.
```

In a second worktree, run exactly the same two commands; the directory name is
different, so it gets its own id and port without any coordination.

### Seeing what is already taken

```bash
make list-agents
```

```text
   ID            SLOT  WEB   MONGO  KC   DIRECTORY
 * w11790        1     8081  8181   8481 /home/me/off/11790
   w11790-2      2     8082  8182   8482 /home/me/off/11790-fix
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

Slots are handed out from 1 to 19, and each one reserves seven ports (see
[What gets isolated](#what-gets-isolated)), so a 20th concurrent worktree needs a
free port range of its own.

### What gets written

`make agent` writes a **generated, git-ignored block** to `.envrc`. It replaces
that block on every run and leaves any other line you put in `.envrc` (such as
`USER_UID` or `CPANMOPTS`) untouched.

It also writes a generated block into each dependency checkout, in
`deps/openfoodfacts-shared-services/.envrc` and `deps/openfoodfacts-auth/.envrc`.
Both of those `Makefile`s load `.env` first and then `.envrc`, and both git-ignore
`.envrc`, which is exactly the override they need. `make run_deps` refreshes those
files, so a worktree whose `deps/` was cloned after `make agent` is still isolated.

To check what a worktree resolved to:

```bash
make print-agent-config
```

## What gets isolated

Taking `w11790` in **slot 1** as the example, in addition to everything
`COMPOSE_PROJECT_NAME` already covers:

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
| frontend host port | `80` | `8081` |
| domain of the shared stack | `openfoodfacts.localhost` | `w11790.openfoodfacts.localhost` |

The project-scoped volumes (`podata`, `build_cache`, `node_modules`,
`icons_dist`, `js_dist`, `css_dist`, `pgdata`, `html_data`, `products`) already
followed `COMPOSE_PROJECT_NAME`, so they are covered too.

### The dependencies are isolated as well

`deps/openfoodfacts-shared-services` (MongoDB, Redis, PostgreSQL) and
`deps/openfoodfacts-auth` (Keycloak, SMTP4Dev) get their own containers, their own
volumes, their own host ports and their own network:

| Resource | Default | With id `w11790` (slot 1) |
| --- | --- | --- |
| their compose project | `off_shared` / `openfoodfacts-auth` | `off_shared_w11790` / `openfoodfacts-auth_w11790` |
| shared network | `off_shared_network` | `off_shared_network_w11790` |
| mongodb port | `27017` | `8181` |
| postgres port | `5432` | `8281` |
| redis port | `6379` | `8381` |
| keycloak port | `5600` | `8481` |
| keycloak management port | `5602` | `8581` |
| smtp4dev port | `5605` | `8681` |

This is **not** optional tidiness. Keycloak publishes `user-deleted`,
`user-registered` and `user-updated` events to Redis, and every Product Opener
instance consumes all three streams (`lib/ProductOpener/Redis.pm`). With a shared
Redis, deleting a test user in one worktree would enqueue `delete_user` in
another, and `delete_user_task` calls `find_and_replace_user_id_in_products`,
which rewrites product edits in MongoDB to an anonymous user — irreversible, in
somebody else's data.

Because the stream names are global, a per-worktree Keycloak alone would not be
enough: Redis has to be per worktree too.

`MONGODB_HOST`, `REDIS_URL` and `KC_SPI_EVENTS_LISTENER_REDIS_EVENT_LISTENER_REDIS_URL`
need no change. On the per-worktree network, `mongodb` and `redis` already resolve
to that worktree's containers.

MongoDB's WiredTiger cache is lowered to 1 GB per worktree
(`PO_AGENT_MONGO_CACHE_SIZE` overrides it), because the shared default of 8 GB
would exhaust the machine with several instances.

### What is deliberately *not* isolated

* **Nothing that belongs to Product Opener itself.** Everything above is isolated,
  including the dependencies.
* **The registry is per user.** It lives in `~/.cache/off-agents`, so a worktree
  owned by a different user of the same machine is not listed. Docker remains the
  authority, which is what the `*` marker in `make list-agents` checks.

### Sharing the dependencies again: `PO_SHARED_DATA=1`

To go back to one shared MongoDB / Redis / PostgreSQL / Keycloak, put this in
`.envrc`:

```bash
export PO_SHARED_DATA=1
```

It removes the generated dependency blocks, so `make run_deps` reuses the shared
`off_shared` containers. That is cheaper, and it is the only way to see the
production data dump in every worktree — at the price of the cross-talk described
above. It shares Keycloak too, because both have to agree on the network name.

`make agent PO_SHARED_DATA=1` remembers the setting, so a later `make dev` without
the environment variable keeps behaving the same way.

**Do not point several worktrees at one `DEPS_DIR`.** The generated dependency
`.envrc` files live inside `deps/`, so a shared `DEPS_DIR` cannot be isolated:
`make agent` says so and leaves the dependencies shared. The trade-off is about
disk (about 2 GB of dependency repositories re-cloned per worktree) rather than
correctness.

### `/etc/hosts` is not needed

`w11790.openfoodfacts.localhost` and all its subdomains resolve to `127.0.0.1`
on their own in current browsers, because `*.localhost` is special-cased
(RFC 6761). Tools that do not special-case it (`curl`, `wget`, some resolvers)
still need an entry:

```text
127.0.0.1 world.w11790.openfoodfacts.localhost
```

`make edit_etc_hosts` derives the entries from `PRODUCT_OPENER_DOMAIN`, so it
already points at the right worktree.

Only add the entries you actually need; `make edit_etc_hosts` handles the default
domain.

## Three guards, so mistakes are loud

* If `PO_AGENT_ID` is set but the host port is still 80, `make up` / `make dev`
  refuse to start instead of silently fighting over the port. Set
  `ALLOW_SHARED_PORT=1` to bypass deliberately.
* If `PRODUCT_OPENER_HOST_PORT` and `PRODUCT_OPENER_PORT` disagree, startup is
  refused too: `Config2_docker.pm` derives its server domain from
  `PRODUCT_OPENER_PORT`, so a mismatch makes the application generate URLs and
  redirects pointing at the wrong port. `make agent` always writes both.
* If `PO_AGENT_ID` is set, `PO_SHARED_DATA` is not, and the dependencies'
  `.envrc` does not mention this id, startup is refused: the dependencies would
  silently stay shared and one worktree would act on another worktree's Keycloak
  events. `make run_deps` regenerates those files, so the usual fix is simply to
  re-run `make agent`.

## How it works

`PO_AGENT_ID` is the single knob. `make agent` writes it to `.envrc`, and:

* the **Makefile** derives `COMPOSE_PROJECT_NAME`, `PRODUCT_OPENER_DOMAIN` and
  `MINION_QUEUE` by appending the id. It does this *only* in the Makefile, so
  `make agent` must not write them as well or the prefix would be applied twice.
  It also derives `PRODUCT_OPENER_NETWORK` here, which is what `docker-compose.yml`
  uses for the default network.
* `scripts/dev-agent-env.sh` keeps a small registry (`~/.cache/off-agents`) mapping
  id to slot and directory. Two different things have to be unique and are enforced
  differently: the **slot** by a `.slot-<n>` lock file that is created once and
  never rewritten, and the **id** by writing its registry entry with
  `set -o noclobber`, once, at the very end. Both are atomic on POSIX filesystems.
  If a run fails after claiming, the claim is given back, so the registry never
  keeps a worktree that has no slot.
* the **compose files** derive network, volume and image names from
  `PO_AGENT_PREFIX` / `PO_AGENT_SUFFIX`, which the Makefile computes from the id.
  Compose's `${VAR:+word}` treats an *empty but set* variable as true, which
  would produce names such as `product-opener_`, so the Makefile always passes a
  real value and the compose files use the empty-safe `${VAR:-}` form.

Everything is optional: with `PO_AGENT_ID` unset, all of these resolve to the
historical names, byte for byte.

`.github/scripts/check_worktree_isolation.sh` asserts all of it in CI: that the
default configuration is unchanged, that an isolated worktree is fully suffixed
(dependencies included), that five worktrees racing for the same directory name
still get distinct ids, slots and ports, that `PO_SHARED_DATA=1` shares again and
is remembered, that an id owned by another worktree is refused, and that a
`DEPS_DIR` outside the worktree is reported as shared rather than silently
overwritten. You can run it locally at any time.

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
* **`DEPS_DIR` must stay per worktree.** It defaults to `$(PWD)/deps`, so each
  worktree re-clones about 2 GB of dependency repositories, and that is the price
  of isolating the dependencies. Sharing one copy across worktrees leaves MongoDB,
  Redis, PostgreSQL and Keycloak shared, and `make agent` warns when you do it.
  The `Makefile` does honour an existing `DEPS_DIR`, so a per-worktree path
  outside the checkout (for example `~/off-deps-11790`) works fine.
* **RAM.** Budget roughly one `backend` container (about 6 GB) plus about 1 GB for
  the isolated dependencies per worktree. Two or three concurrent worktrees is
  usually the practical limit; measure before adding more.
  `PO_SHARED_DATA=1` brings the dependency part back down to about 250 MB.
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