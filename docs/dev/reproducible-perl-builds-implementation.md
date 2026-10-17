# Reproducible Perl Builds - Implementation Summary

This document summarizes the changes made to implement reproducible Perl builds for Open Food Facts.

## Problem Statement

Previously, Perl dependencies were installed without strict version locking, making builds non-deterministic. `main` migrated from `cpanm` to `cpm` for speed; this branch adds a lockfile on top.

## Solution Overview

**Install with `cpm` (fast) + lock with `cpanfile.snapshot` (Carton format).**

### Production Builds (Reproducible)
- When `cpanfile.snapshot` exists, `cpm` (no ARGV) auto-loads it via `Carton::Snapshot` and uses it as the *primary* resolver
- Any package missing from the snapshot falls back to `MetaCPAN`/`MetaDB` (snapshot-only `--resolver snapshot --no-default-resolvers` is not used, see below)
- Used for production deployments and CI/CD

### Development Builds (Flexible)
- When no snapshot exists, `cpm` resolves from `cpanfile` constraints (`CPANMOPTS=--with-develop` etc.)
- Same installer (`cpm -w $(nproc)`) in both cases; snapshot presence only changes resolution priority, not the command

## Changes Made

### 1. Dockerfile Updates
- **Kept `cpm`** as primary installer; build command identical to `main` (`cpm install $CPANMOPTS --show-build-log-on-failure -w $(nproc) -g`), which auto-loads `cpanfile.snapshot` when present
- **Added `carton` Debian package** to base image *only* for snapshot generation / `Carton::Snapshot` runtime dep for `cpm --snapshot` (cpm can read `cpanfile.snapshot` via `--snapshot` / `--resolver snapshot` but cannot write it - see `skaji/cpm#174`)
- **Builder stage** matches `main`'s install command; `cpm` auto-detects `cpanfile.snapshot` after `COPY ./cpanfile* /tmp/` (fixes a pre-existing trailing space after `\` on the `PERL_MM_OPT` line from `main`)
- Added comments linking to `docs/dev/how-to-generate-cpanfile-snapshot.md`

### 2. Scripts
- **Created `scripts/generate_cpanfile_snapshot.sh`**: Automated snapshot generation
  - Builds `builder` stage *without* snapshot (forces `cpm` to resolve from `cpanfile`)
  - Runs `carton install` inside the built image to generate `cpanfile.snapshot`
  - Extracts snapshot via `docker cp` to repository root
  - Updated from `cpanm`-centric to `cpm`-centric wording

### 3. Documentation
- **`docs/dev/how-to-generate-cpanfile-snapshot.md`**: Complete guide
  - Explains `cpm` install + `Carton` generate split
  - Documents `--snapshot` vs `--resolver snapshot` distinction
  - Multiple generation methods

- **`docs/dev/how-to-automate-perl-dependency-updates.md`**: Future enhancement guide

- **Updated `docker/README.md`**: Reproducible builds section now mentions `cpm`+`Carton`

### 4. Git Configuration
- **Updated `.gitattributes`**: Ensure consistent line endings for `cpanfile` and `cpanfile.snapshot`

## How It Works

### With cpanfile.snapshot (Production)
```dockerfile
# cpm auto-loads cpanfile.snapshot (no ARGV), snapshot first then MetaCPAN fallback
COPY ./cpanfile* /tmp/
RUN cpm install $CPANMOPTS --show-build-log-on-failure -w $(nproc) -g
```

### Without cpanfile.snapshot (Development)
```dockerfile
# same command; no snapshot present so cpm resolves from cpanfile via MetaCPAN
COPY ./cpanfile* /tmp/
RUN cpm install $CPANMOPTS --show-build-log-on-failure -w $(nproc) -g
```

Both modes use the **same** command. When `cpanfile.snapshot` exists, `cpm` auto-adds a `Snapshot` resolver ahead of `MetaCPAN`/`MetaDB` (`generate_resolver` in `App::cpm::CLI`). Snapshot-only resolution (`--resolver snapshot --no-default-resolvers`) is deliberately avoided: `carton` omits distributions satisfied by the system at snapshot generation time, so a strict snapshot-only resolver can never resolve a full `cpanfile` graph (observed on CI with `ExtUtils::CppGuess`, `Alien::FFI`, `Devel::CheckLib`, `Test::MockObject`, etc.).

## Usage

### For Developers
```bash
# Build normally (cpm uses snapshot if available, otherwise cpanfile)
make build

# Generate or update snapshot (uses Carton inside cpm-built image)
./scripts/generate_cpanfile_snapshot.sh

# Commit the snapshot
git add cpanfile.snapshot
git commit -m "chore: update cpanfile.snapshot"
```

### For CI/CD
No changes needed! The build automatically:
1. Uses snapshot if committed (reproducible, cpm loads it)
2. Falls back to cpanfile if not (flexible)

## Benefits

### ✅ Reproducibility
- Deterministic builds via `cpanfile.snapshot`
- Predictable deployments

### ✅ Performance
- `cpm -w $(nproc)` is way faster than `carton`/`cpanm` (parallel downloads/builds)

### ✅ Security
- Version tracking in git, audit trail, controlled updates

### ✅ Flexibility
- `CPANMOPTS` / `cpm --with-develop` etc. still work
- Backward compatible with `main`

### ✅ Maintainability
- `cpm` fatpacked single-file installer; `carton` Debian package only for snapshot generation
- `cpanfile.snapshot` standard Carton format

## Migration Path

### Phase 1: Current State ✅
- `cpm` for install, `carton` for snapshot generation
- Build system supports both modes (with/without snapshot)
- Documentation and helper script available

### Phase 2: Initial Snapshot (Next Steps)
- Run `./scripts/generate_cpanfile_snapshot.sh`
- Review and test the generated snapshot
- Commit to repository

### Phase 3: Production Adoption
- All builds use the snapshot
- Fully reproducible deployments
- Regular snapshot updates

### Phase 4: Automation (Future)
- GitHub Actions workflow for monthly updates

## Technical Details

### Why not Carton for install?
Performance: `cpm` is parallel and an order of magnitude faster. Carton is retained only because `cpm` has no snapshot writer (`--snapshot` is read-only, `--resolver snapshot` documented in `skaji/cpm#174#629747948`).

### Snapshot Format
- Carton `version 1.0` text format
- Read by both `carton` and `cpm` (via `Carton::Snapshot`); used as primary resolver with `MetaCPAN` fallback
- Version-controlled, human-readable

### Backward Compatibility
- `CPANMOPTS` usage unchanged (mapped to `cpm` flags)
- No impact on developers without snapshot
- Dockerfile diff vs `main` is just `+carton` apt package, comments, and a trailing-space fix

## Testing Strategy

### Without Snapshot
```bash
rm cpanfile.snapshot
make build  # cpm resolves from cpanfile
```

### With Snapshot
```bash
./scripts/generate_cpanfile_snapshot.sh
make build  # cpm loads snapshot
```

## Related Files

- `Dockerfile`: cpm install logic (matches main + carton)
- `cpanfile`: Declares dependencies and constraints
- `cpanfile.snapshot`: Lockfile (generated by Carton, read by cpm)
- `scripts/generate_cpanfile_snapshot.sh`: Snapshot generation helper
- `docs/dev/how-to-generate-cpanfile-snapshot.md`: User guide
- `.gitattributes`: Git configuration

## Future Enhancements

1. Automated Updates: GitHub Actions for monthly dependency updates
2. Security Scanning: Vulnerability scanning for CPAN modules
3. Dependency Diff: Visual comparison of snapshot changes

## References

- [cpm Documentation](https://github.com/skaji/cpm)
- [Carton Documentation](https://metacpan.org/pod/Carton)
- [cpanfile Documentation](https://metacpan.org/pod/cpanfile)
- [Reproducible Builds](https://reproducible-builds.org/)
- [GitHub Issue #12548](https://github.com/openfoodfacts/openfoodfacts-server/issues/12548)

---

**Status**: ✅ Implementation Complete - cpm for install, Carton for snapshot generation
