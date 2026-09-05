# Reproducible Perl Builds with Carton - Implementation Summary

This document summarizes the changes made to implement reproducible Perl builds for Open Food Facts.

## Problem Statement

Previously, Perl dependencies were installed using `cpanminus` without version locking, making builds non-deterministic and reproducible builds impossible.

## Solution Overview

We implemented a **hybrid approach** using Carton for reproducibility while maintaining cpanm for flexibility:

### Production Builds (Reproducible)
- When `cpanfile.snapshot` exists, Carton installs exact dependency versions
- Fully reproducible builds across environments and time
- Used for production deployments and CI/CD

### Development Builds (Flexible)
- When no snapshot exists, cpanm installs from cpanfile constraints
- Supports `CPANMOPTS` for features (`--with-develop`, `--with-feature=...`)
- Allows testing new dependencies before generating a snapshot

## Changes Made

### 1. Dockerfile Updates
- **Added Carton package** to base image for dependency management
- **Added ca-certificates** to fix SSL issues during builds
- **Updated builder stage** to use Carton when snapshot exists, cpanm otherwise
- **Added comprehensive comments** explaining the build process

### 2. Scripts
- **Created `scripts/generate_cpanfile_snapshot.sh`**: Automated snapshot generation
  - Builds Docker image with all dependencies
  - Runs Carton to generate the snapshot
  - Extracts snapshot to repository root

### 3. Documentation
- **`docs/dev/how-to-generate-cpanfile-snapshot.md`**: Complete guide for snapshot management
  - Explains the hybrid approach
  - Multiple generation methods
  - When to update the snapshot
  - Troubleshooting tips

- **`docs/dev/how-to-automate-perl-dependency-updates.md`**: Future enhancement guide
  - GitHub Actions workflow template
  - Automated monthly dependency updates
  - Security considerations

- **Updated `docker/README.md`**: Added reproducible builds section

### 4. Git Configuration
- **Updated `.gitattributes`**: Ensure consistent line endings for cpanfile and cpanfile.snapshot

## How It Works

### With cpanfile.snapshot (Production)
```dockerfile
# Carton uses the snapshot for exact versions
export PERL_CARTON_PATH=/tmp/local
carton install --deployment
```

### Without cpanfile.snapshot (Development)
```dockerfile
# cpanm uses cpanfile with flexibility for features
cpanm $CPANMOPTS --notest --quiet --skip-satisfied \
  --local-lib /tmp/local/ --installdeps .
```

## Usage

### For Developers
```bash
# Build normally (uses snapshot if available, otherwise cpanfile)
make build

# Generate or update snapshot
./scripts/generate_cpanfile_snapshot.sh

# Commit the snapshot
git add cpanfile.snapshot
git commit -m "chore: update cpanfile.snapshot"
```

### For CI/CD
No changes needed! The build automatically:
1. Uses snapshot if committed (reproducible)
2. Falls back to cpanfile if not (flexible)

## Benefits

### ✅ Reproducibility
- **Deterministic builds**: Same output from same inputs
- **Predictable deployments**: No surprise dependency changes
- **Easier debugging**: Exact dependency versions are known

### ✅ Security
- **Version tracking**: All dependency versions in git
- **Audit trail**: Changes visible in git history
- **Controlled updates**: Dependencies updated intentionally

### ✅ Flexibility
- **Development freedom**: Test new deps without snapshot
- **Feature support**: CPANMOPTS still works
- **Backward compatible**: No breaking changes to workflow

### ✅ Maintainability
- **Debian packaging**: Carton available as `carton` package
- **Industry standard**: cpanfile.snapshot format widely used
- **Future automation**: Template for GitHub Actions updates

## Migration Path

### Phase 1: Current State ✅
- Carton installed
- Build system supports both modes
- Documentation complete
- Helper script available

### Phase 2: Initial Snapshot (Next Steps)
- Run `./scripts/generate_cpanfile_snapshot.sh`
- Review and test the generated snapshot
- Commit to repository

### Phase 3: Production Adoption
- All builds use the snapshot
- Fully reproducible deployments
- Regular snapshot updates

### Phase 4: Automation (Future)
- Implement GitHub Actions workflow
- Monthly automated dependency updates
- Security vulnerability scanning

## Technical Details

### Carton vs Carmel Decision
We chose **Carton** because:
- Available as Debian package (no cpanm installation needed)
- More widely adopted and stable
- Better documentation
- Aligns with existing infrastructure

### Snapshot Format
The `cpanfile.snapshot` is:
- Human-readable text format
- Version-controlled
- Compatible with industry standards
- Can be generated from any valid cpanfile

### Backward Compatibility
- Existing CPANMOPTS usage unchanged
- No impact on developers without snapshot
- Production builds improved when snapshot added
- Zero breaking changes

## Testing Strategy

### Without Snapshot
```bash
# Remove snapshot to test cpanm path
rm cpanfile.snapshot
make build
# Should succeed using cpanfile
```

### With Snapshot
```bash
# Generate snapshot
./scripts/generate_cpanfile_snapshot.sh
make build
# Should succeed using snapshot
```

### Reproducibility Test
```bash
# Build twice, compare results
make build
docker images --format "{{.Repository}}:{{.Tag}} {{.ID}}" | grep backend
make clean && make build
docker images --format "{{.Repository}}:{{.Tag}} {{.ID}}" | grep backend
# IDs may differ due to timestamps, but deps should be identical
```

## Related Files

- `Dockerfile`: Main build logic with Carton integration
- `cpanfile`: Declares dependencies and constraints
- `cpanfile.snapshot`: Lockfile with exact versions (to be generated)
- `scripts/generate_cpanfile_snapshot.sh`: Snapshot generation helper
- `docs/dev/how-to-generate-cpanfile-snapshot.md`: User guide
- `docs/dev/how-to-automate-perl-dependency-updates.md`: Automation guide
- `.gitattributes`: Git configuration for consistent handling

## Future Enhancements

1. **Automated Updates**: GitHub Actions for monthly dependency updates
2. **Security Scanning**: Integrate vulnerability scanning for CPAN modules
3. **Dependency Diff**: Visual comparison of snapshot changes
4. **Split Snapshots**: Separate snapshots for different feature sets
5. **Build Cache**: Optimize using snapshot for faster builds

## References

- [Carton Documentation](https://metacpan.org/pod/Carton)
- [cpanfile Documentation](https://metacpan.org/pod/cpanfile)
- [Reproducible Builds](https://reproducible-builds.org/)
- [GitHub Issue #12548](https://github.com/openfoodfacts/openfoodfacts-server/issues/12548)

## Contributors

- Implementation: GitHub Copilot
- Review and guidance: @hangy

---

**Status**: ✅ Implementation Complete - Ready for snapshot generation and testing
