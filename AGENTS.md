# OpenFoodFacts Server (Product Opener) — Agent Guide

Product Opener is a Perl web application (CGI + modules) with a Gulp-built JavaScript/SCSS frontend, run locally through Docker Compose. **Always drive it through the Makefile** — it wraps every Docker, test and lint invocation with the right compose files and env vars.

Start here, then read the canonical docs in `docs/dev/` rather than guessing:

| Doc | Covers |
| --- | --- |
| [`how-to-quick-start-guide.md`](docs/dev/how-to-quick-start-guide.md) | Full first-run setup, `/etc/hosts`, parallel builds, editors |
| [`how-to-write-and-run-tests.md`](docs/dev/how-to-write-and-run-tests.md) | Test targets, expected-results regeneration, yath options |
| [`docker/README.md`](docker/README.md) | Container lifecycle targets (`up`, `down`, `status`, `log`, `prune`, data import) |
| [`explain-frontend-build-scripts.md`](docs/dev/explain-frontend-build-scripts.md) | How `gulpfile.mjs` wires `scss/` + `html/js/` into `dist/` |

Note that no doc covers *every* target — `grep -E '^[a-z_]+:' Makefile` is the authoritative list. If this file and the docs ever disagree, `docs/dev/` and the `Makefile` are the source of truth.

## Initial setup

1. Docker + Docker Compose installed, BuildKit enabled.
2. Clone: `git clone https://github.com/openfoodfacts/openfoodfacts-server.git`
3. **Optional — hosts entry.** Only needed if your system can't resolve `*.openfoodfacts.localhost` on its own. Modern Linux, macOS and Windows resolve `*.localhost` automatically, so you can skip this. It's also unnecessary when the containers run under WSL2 and you browse from Windows. If you *do* hit name-resolution errors, add:
   ```
   127.0.0.1 world.openfoodfacts.localhost fr.openfoodfacts.localhost static.openfoodfacts.localhost ssl-api.openfoodfacts.localhost fr-en.openfoodfacts.localhost
   ```
   to `/etc/hosts` (Linux/macOS) or `C:\Windows\System32\drivers\etc\hosts`. `make edit_etc_hosts` (Makefile:130) appends the entry idempotently. Do not edit system files unless you actually hit this error.
4. Optional: `cp .env .envrc` and use [direnv](https://direnv.net/) for local overrides. Prefer `.envrc` over editing the tracked `.env` so overrides don't leak into commits.
5. `make dev` — builds taxonomies, translations and images, then starts everything. **10–30 minutes cold** (network-bound: Docker base images + Debian + Perl modules); a few minutes once layers are cached.

Parallelism is the main speedup for a cold build, since the work is mostly network waits:

```bash
make dev --jobs=32      # or: export MAKEFLAGS=--jobs=32
```

## Core commands

| Goal | Command |
| --- | --- |
| Start the dev environment | `make dev` |
| Verify the site answers | `make livecheck` |
| Restart backend (needed after editing Perl modules) | `make restart_backend` |
| Container status | `make status` |
| Stop everything | `make down` |
| Rebuild images (needed after `cpanfile` changes) | `make build` |
| Frontend install / build / lint | `make front_npm_update` / `make front_build` / `make front_lint` |
| One unit test | `make test-unit test=additives.t` |
| One integration test | `make test-int test=api_v3_product_read.t` |
| Debug a test | `make test-unit test=additives.t TEST_CMD="perl -d"` |
| Whole unit suite | `make unit_test` (~15 min) |
| Whole integration suite | `make integration_test` (~15–20 min) |
| Everything, with prerequisites | `make tests` (30+ min — allow 60) |
| Frontend + Perl lint | `make checks` |

`test-unit` / `test-int` run a single `.t`; `unit_test` / `integration_test` run the whole suite; `make tests` chains those with the taxonomy and language builds they need.

`make dev` imports ~100 sample products, so there is data to browse. For production-scale data (~4M products, ~14 GB uncompressed) run `make import_prod_data` — slow, and rarely needed for dev.

## Testing

### Prerequisites are not automatic for single-test targets

`test-unit`, `test-int` and `unit_test` do **not** build test taxonomies or translations. On a fresh clone, run once:

```bash
make build_taxonomies_test
make build_lang_test
```

`make tests` (Makefile:299) chains these for you and is the best way to run everything. Rerun `build_lang_test` after touching any `.pot`/`.po` file.

### Regenerating expected results

Integration tests diff against stored JSON/HTML fixtures. If you intentionally change output, regenerate — never hand-edit fixtures:

```bash
make test-int test="api_v3_product_read.t :: --update-expected-results"   # single test
make update_tests_results                                                 # everything
```

Always review the regenerated diff before committing.

### Interpreting failures

CI is the arbiter: **both the unit and integration suites are gated** — `tests_summary` fails the PR if either job fails. If a test fails, make sure containers are fully up, rerun, then compare against CI. Do not assume failures are pre-existing.

### Before opening a PR

`make checks` covers `front_build`, `front_lint`, `check_perltidy`, `check_perl_fast`, `check_critic`, `check_taxonomies`. CI additionally runs:

- `make check_perl` — compiles **every** `.pl`/`.pm`/`.t`; the check that catches a rename you didn't update. Slower, but not optional.
- `make update_package_lock` — CI fails if `package-lock.json` drifts after a `package.json` change.
- Translation check (`translation-check.yml`) and Spectral linting of `docs/api/ref/*.yaml` (`api-linting.yml`).

> **Caveat:** `check_perltidy`, `check_perl_fast`, `check_critic` and `check_taxonomies` select files via `git diff origin/main --name-only` (Makefile:408) and **exit 0 when that list is empty**. On a clone without an `origin/main` ref (e.g. a single-branch clone), they silently check nothing. Verify with `git rev-parse origin/main`; use `make check_perl` and `make lint_perltidy` when you need unconditional coverage.

### Manual validation

With `make dev` running at http://world.openfoodfacts.localhost/ :

- Create an account: open http://world.openfoodfacts.localhost/, click **Sign in** (auth is Keycloak), then **Register**. **The account stays inactive until you click the verification link in http://localhost:5605/ (SMTP4Dev)** — that step is required locally, not a bug.
- Browse a product page and confirm images and data render.
- Submit a product edit and verify it persists.
- Run a search.
- Check responsive layout at mobile width.

## Repository layout

- `lib/ProductOpener/` — Perl modules: business logic, API, tags, import/export. Key ones: `API.pm`, `Products.pm`, `Store.pm`, `Tags.pm`, `Config2_docker.pm`
- `cgi/*.pl` — web/API entry points
- `templates/web/pages/*.tt.html` — page templates
- `scss/`, `html/js/` — frontend sources
- `tests/unit/`, `tests/integration/` — test suites (`*.t`, run via yath)
- `taxonomies/` — food classification data (ingredients, categories, additives, brands…)
- `docker/` — compose overrides, entrypoints, helper scripts
- `conf/` — apache/nginx configuration
- `docs/dev/` — developer documentation

Generated frontend output lands in `html/css/dist/`, `html/js/dist/`, `html/images/icons/dist/` and `html/images/attributes/dist/`. These are build products — don't hand-edit them.

### Key files

- `Makefile` — all build/test/lint entry points
- `package.json`, `gulpfile.mjs` — frontend deps and build pipeline (`gulpfile.mjs` is plain ESM JavaScript, not TypeScript)
- `cpanfile` — Perl deps; changing it requires rebuilding images
- `docker-compose.yml` + `docker/*.yml` — container orchestration
- `.env` — Docker/environment defaults (e.g. `PRODUCT_OPENER_DOMAIN`)

### Configuration

**Do not edit `lib/ProductOpener/Config2.pm`.** It is gitignored and generated: `docker/docker-entrypoint.sh:4` symlinks it to `Config2_docker.pm` inside the container. The only tracked variants are `Config2_docker.pm` and `Config2_sample.pm` — there is no per-environment family of `Config2_*.pm` files.

To change configuration, edit `.env` (or a `.envrc` override), `conf/`, or `lib/ProductOpener/Config2_docker.pm` as appropriate. Edits to `Config2.pm` itself are silently discarded on container start.

## Frontend workflow

1. Edit `scss/` or `html/js/`.
2. `make front_build` — compiles in a container.
3. Confirm output appeared in the `dist/` directories above.
4. `make front_lint` — ESLint/Stylelint.
5. Use the dev environment for live reload while iterating.

Deprecation warnings about Sass `@import` are expected and harmless.

## Backend workflow

1. Edit modules under `lib/ProductOpener/`.
2. `make restart_backend` — files are mounted, but the running server needs a restart to pick up Perl changes.
3. `make test-unit test=<file>.t` / `make test-int test=<file>.t`.
4. `make check_perltidy`, `make check_perl_fast`, `make check_critic`, and `make check_perl`.

Changing `cpanfile` requires `make build`. Databases and containers persist between sessions, so tests get faster over time.

## Troubleshooting

**Cannot reach http://world.openfoodfacts.localhost/** — if the domain fails to resolve, add the `/etc/hosts` entry from Initial setup (most common cause). Otherwise check that `make dev` completed and the containers are up with `make status`.

**"could not find an available, non-overlapping IPv4 address pool"** — a Docker networking conflict, not a repo problem. Add `{"base": "172.80.0.0/16", "size": 24}, {"base": "172.90.0.0/16", "size": 24}` to `default-address-pools` in `/etc/docker/daemon.json` and restart Docker.

**Database connection errors in tests** — containers may still be starting. Wait a minute or two after `make dev` and rerun.

**Test fails with missing taxonomies or translations** — you skipped `make build_taxonomies_test` / `make build_lang_test`.

**`check_*` target passes instantly** — see the `origin/main` caveat above; it probably checked zero files.

**Cold build is slow** — expected, it is network-bound. Use `--jobs=32`.

**BuildKit errors** — ensure BuildKit is enabled (`export DOCKER_BUILDKIT=1`).

**Messed up file ownership in containers** — `make reset_owner`.

**Need disk space / a clean slate** — use the scoped targets, which filter by compose project and leave other projects alone:

```bash
make prune        # unused images, volumes, networks for this project
make prune_cache  # docker builder cache for this project
```

Do **not** run a bare `docker system prune` — it is unscoped and will remove artifacts belonging to unrelated projects on the same machine.

**Diagnosing a running environment** — `make log`, or `docker compose logs <service>`. Full reset: `make down && make dev`.
