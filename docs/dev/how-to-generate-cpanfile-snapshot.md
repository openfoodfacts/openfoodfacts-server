# How to Generate cpanfile.snapshot

This document explains how to generate and update the `cpanfile.snapshot` file for reproducible Perl builds.

## What is cpanfile.snapshot?

`cpanfile.snapshot` is a lockfile that records the exact versions of all Perl dependencies (including transitive dependencies) installed from CPAN. This ensures reproducible builds across different environments and times. It uses the [Carton](https://metacpan.org/pod/Carton) format.

## Why cpm for install and Carton for snapshot?

* **`cpm`** is used for installation (`Dockerfile` builder stage): parallel, `--show-build-log-on-failure -w $(nproc)`, `--snapshot` auto-loaded when `cpanfile.snapshot` exists.
* **`Carton`** is used only for **generating** the snapshot: `cpm` can *consume* a snapshot (`--snapshot` / `--resolver snapshot` via `Carton::Snapshot`, see `skaji/cpm#174`) but cannot *create* it. The Debian `carton` package is therefore kept in `Dockerfile` solely for `scripts/generate_cpanfile_snapshot.sh`.

> Note on `cpm` snapshot semantics: plain `cpm install` (no ARGV) auto-adds a `Snapshot` resolver if `cpanfile.snapshot` exists (see `generate_resolver` in `App::cpm::CLI`), consulting it first and falling back to `MetaCPAN`/`MetaDB` for anything missing. Snapshot-only resolution (`--resolver snapshot --no-default-resolvers`) is deliberately NOT used: `carton` omits distributions satisfied by the system at snapshot generation time, so a strict snapshot-only resolver can never resolve a full `cpanfile` graph (observed on CI with `ExtUtils::CppGuess`, `Alien::FFI`, `Devel::CheckLib`, `Test::MockObject`, etc.).
>
> Note on feature flags: `cpm` accepts `--with-develop` (like `cpanm`) and `--feature=<name>`, but NOT `--with-feature=<name>`. If you need `off_server_dev_tools` from `cpanfile`, pass `--feature=off_server_dev_tools` to `cpm` (the `--with-feature=` spelling in `cpanfile:174` and `docker/devcontainer.yml` is `cpanm` syntax and will fail under `cpm` — pre-existing on `main`, out of scope here).

## How it Works

### Production Builds (with cpanfile.snapshot)

When `cpanfile.snapshot` exists:
- `Dockerfile` runs `cpm install` with no ARGV, so `cpm` auto-loads the snapshot and uses it as the primary resolver
- Exact versions from the snapshot via `Carton::Snapshot`; anything missing falls back to `MetaCPAN`

### Development / Initial Builds (without cpanfile.snapshot)

When `cpanfile.snapshot` doesn't exist:
- `Dockerfile` runs plain `cpm install` resolving from `cpanfile` constraints (`cpm install --with-develop` etc. via `CPANMOPTS`)
- Snapshot can be generated afterward with `scripts/generate_cpanfile_snapshot.sh`

## Prerequisites

To generate the snapshot, you need:

- Docker installed on your system
- Access to the openfoodfacts-server repository
- Sufficient disk space (~5GB) and time (~15-30 minutes) - faster with `cpm`

## Generating cpanfile.snapshot

### Method 1: Using the Helper Script (Recommended)

We provide a helper script that automates the snapshot generation:

```bash
# Run the snapshot generation script
./scripts/generate_cpanfile_snapshot.sh

# The script will:
# 1. Build the Docker image (builder stage) without a snapshot (cpm resolves from cpanfile)
# 2. Run Carton inside the built image to generate cpanfile.snapshot
# 3. Extract the snapshot to the repository root (via docker cp)
```

### Method 2: Using Docker Build Directly

You can also generate the snapshot manually:

```bash
# Remove existing snapshot to force cpm to resolve from cpanfile
rm -f cpanfile.snapshot

# Build the Docker image (this uses cpm to install dependencies)
docker build --target builder --build-arg CPANMOPTS=--with-develop -t off-builder .

# Create a container to run Carton and generate the snapshot
# Note: We use docker cp instead of stdout redirection because carton install
# outputs logs that would contaminate the snapshot file
CONTAINER_ID=$(docker create off-builder bash -c "
  export PERL_CARTON_PATH=/tmp/local
  cd /tmp
  carton install
")

# Run the container and let it generate the snapshot
docker start -a "$CONTAINER_ID"

# Extract the snapshot from the container
docker cp "$CONTAINER_ID:/tmp/cpanfile.snapshot" cpanfile.snapshot

# Clean up
docker rm "$CONTAINER_ID"

# Verify the snapshot was created
ls -lh cpanfile.snapshot
```

### Method 3: Using docker-compose (Advanced)

For environments where docker-compose is preferred:

```bash
# Remove existing snapshot
rm -f cpanfile.snapshot

# Build without snapshot
docker compose build backend

# The easiest approach is to use the helper script from within compose:
docker compose run --rm backend bash /opt/product-opener/scripts/generate_cpanfile_snapshot.sh

# Alternatively, manually generate and extract:
# 1. Start a temporary container
docker compose run --rm -d --name snapshot-gen backend sleep 300

# 2. Generate snapshot inside
docker compose exec snapshot-gen bash -c "
  export PERL_CARTON_PATH=/opt/perl/local
  cd /opt/product-opener
  carton install
"

# 3. Copy the file out
docker cp snapshot-gen:/opt/product-opener/cpanfile.snapshot cpanfile.snapshot

# 4. Stop the container
docker stop snapshot-gen
```

**Note:** Method 1 (helper script) is recommended for most use cases.

## When to Update cpanfile.snapshot

You should update `cpanfile.snapshot` when:

1. **Adding new dependencies** - After adding a `requires` line to `cpanfile`
2. **Updating dependency versions** - After changing version constraints in `cpanfile`
3. **Periodic updates** - Monthly or quarterly to get security updates and bug fixes
4. **After dependency vulnerabilities** - When security issues are discovered in dependencies

## Testing the Snapshot

After generating or updating the snapshot, test it by:

```bash
# Build with the snapshot (cpm will auto-detect it)
make build

# Run tests
make tests

# Check that the build is reproducible
make clean && make build
```

## Troubleshooting

### Build failures after updating snapshot

If the build fails after updating the snapshot:

1. Check that all system dependencies (apt packages) are still installed
2. Verify that version constraints in `cpanfile` are correct
3. Check for incompatibilities between dependencies
4. Review the build logs for specific error messages (`--show-build-log-on-failure`)

### Snapshot generation fails

If snapshot generation fails:

1. Ensure you have enough disk space
2. Check your internet connection (Carton needs to download from CPAN)
3. Look for error messages in the build logs
4. Try cleaning the build cache: `docker system prune -af`
5. Ensure `carton` is installed in the builder image (Debian `carton` package or `Carton::Snapshot` CPAN module - required for `cpm --snapshot` to work)

## CI/CD Integration

The snapshot is automatically used in CI/CD pipelines:

- GitHub Actions use the snapshot for reproducible builds (cpm picks it up automatically)
- Pull requests should include snapshot updates when dependencies change
- The container build workflow validates the snapshot

## Automated Updates (Future)

A GitHub Action workflow could be added to automatically check for dependency updates and create PRs with updated snapshots. See `docs/dev/how-to-automate-perl-dependency-updates.md` for a template.

## Related Files

- `cpanfile` - Declares direct dependencies and version constraints
- `cpanfile.snapshot` - Lockfile with exact versions of all dependencies (Carton format, read by cpm)
- `Dockerfile` - Uses `cpm` to install dependencies (auto-loads snapshot when present)
- `scripts/generate_cpanfile_snapshot.sh` - Generates snapshot via Carton from a cpm-built image
- `.github/workflows/container-build.yml` - CI/CD workflow using the snapshot

## Additional Resources

- [cpm Documentation](https://github.com/skaji/cpm) - fast installer, `cpm --help` for `--snapshot`, `--resolver snapshot`
- [Carton Documentation](https://metacpan.org/pod/Carton) - snapshot format and generation
- [cpanfile Documentation](https://metacpan.org/pod/cpanfile)
- [Reproducible Builds](https://reproducible-builds.org/)
