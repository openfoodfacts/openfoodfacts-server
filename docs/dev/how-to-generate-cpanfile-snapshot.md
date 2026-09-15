# How to Generate cpanfile.snapshot

This document explains how to generate and update the `cpanfile.snapshot` file for reproducible Perl dependency builds.

## What is cpanfile.snapshot?

`cpanfile.snapshot` is a lockfile that records the exact versions of all Perl dependencies (including transitive dependencies) installed from CPAN. This ensures reproducible builds across different environments and times.

## Why Carton?

We use [Carton](https://metacpan.org/pod/Carton) for snapshot generation because:

- It's available as a Debian package (`carton`)
- It generates deterministic `cpanfile.snapshot` files compatible with industry standards
- It's widely adopted in the Perl community
- It integrates well with our existing `cpanfile`
- The snapshot format is human-readable and can be version controlled

## How it Works

The build system uses a hybrid approach for maximum flexibility and reproducibility:

### Production Builds (with cpanfile.snapshot)

When `cpanfile.snapshot` exists in the repository:
- **Carton** is used with `--deployment` mode
- Dependencies are installed from exact versions in the snapshot
- Build is fully reproducible across different environments
- This is used for production deployments and CI/CD

### Development Builds (without cpanfile.snapshot)

When `cpanfile.snapshot` doesn't exist:
- **cpanminus (cpanm)** is used with the original approach
- Dependencies are resolved from `cpanfile` constraints
- Supports `CPANMOPTS` like `--with-develop` and `--with-feature=...`
- More flexible for development and testing new dependencies
- The snapshot can be generated afterward using the helper script

This hybrid approach provides both reproducibility and flexibility.

## Prerequisites

To generate the snapshot, you need:

- Docker installed on your system
- Access to the openfoodfacts-server repository
- Sufficient disk space (~5GB) and time (~15-30 minutes)

## Generating cpanfile.snapshot

### Method 1: Using the Helper Script (Recommended)

We provide a helper script that automates the snapshot generation:

```bash
# Run the snapshot generation script
./scripts/generate_cpanfile_snapshot.sh

# The script will:
# 1. Build the Docker image without a snapshot (uses cpanm)
# 2. Run Carton to analyze installed modules
# 3. Generate cpanfile.snapshot with exact versions
# 4. Extract the snapshot to the repository root
```

### Method 2: Using Docker Build Directly

You can also generate the snapshot manually:

```bash
# Remove existing snapshot to force cpanm-based installation
rm -f cpanfile.snapshot

# Build the Docker image (this uses cpanm to install dependencies)
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
# Build with the snapshot
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
4. Review the build logs for specific error messages

### Snapshot generation fails

If snapshot generation fails:

1. Ensure you have enough disk space
2. Check your internet connection (Carton needs to download from CPAN)
3. Look for error messages in the build logs
4. Try cleaning the build cache: `docker system prune -af`

## CI/CD Integration

The snapshot is automatically used in CI/CD pipelines:

- GitHub Actions use the snapshot for reproducible builds
- Pull requests should include snapshot updates when dependencies change
- The container build workflow validates the snapshot

## Automated Updates (Future)

A GitHub Action workflow could be added to automatically check for dependency updates and create PRs with updated snapshots. See the issue for more details.

## Related Files

- `cpanfile` - Declares direct dependencies and version constraints
- `cpanfile.snapshot` - Lockfile with exact versions of all dependencies
- `Dockerfile` - Uses Carton to install dependencies from the snapshot
- `.github/workflows/container-build.yml` - CI/CD workflow using the snapshot

## Additional Resources

- [Carton Documentation](https://metacpan.org/pod/Carton)
- [cpanfile Documentation](https://metacpan.org/pod/cpanfile)
- [Reproducible Builds](https://reproducible-builds.org/)
