# Dockerfile Build Optimization

## Overview

This document describes the multi-stage build optimization implemented for the backend Docker image to reduce production image size and improve separation between development and production environments.

## Changes Made

### 1. Multi-Stage Build Architecture

The Dockerfile has been restructured from a single `modperl` stage to a multi-stage build with clear separation of concerns:

- **runtime-base**: Contains only runtime dependencies (no build tools, no -dev packages)
  - Apache, Perl runtime, image processing tools
  - Runtime Perl libraries (libwww-perl, libimage-magick-perl, etc.)
  - Runtime image libraries (libjpeg62-turbo, libpng16-16, libwebp6, etc.)
  
- **build-base**: Extends runtime-base and adds build tools and development packages
  - Build tools: gcc, g++, make, cmake, pkg-config
  - Development libraries: libperl-dev, libapache2-mod-perl2-dev, libssl-dev, etc.
  - Image processing -dev packages: libavif-dev, libjpeg-dev, libpng-dev, etc.
  - Perl packages needed for building CPAN modules
  
- **builder**: Compiles Perl modules from cpanfile using cpanm
  - Downloads and compiles all Perl dependencies
  - Installs to /tmp/local/ for later copying
  
- **runnable/prod** (default): Production image with minimal dependencies
  - Copies compiled Perl modules from builder
  - Copies zxing-cpp libraries from build-base
  - Only includes runtime dependencies
  
- **dev**: Development image with all build tools
  - Based on build-base (includes all development tools)
  - Includes modules from cpanfile's `develop` and `off_server_dev_tools` features
  - Used for local development with `make dev`

### 2. Size Reduction

The production image size is reduced by removing:

- **Build tools** (~200-300MB): gcc, g++, make, cmake, pkg-config
- **Development libraries** (~100-200MB): All -dev packages
- **Redundant Perl packages**: Older versions replaced by newer cpanm-installed versions

Estimated total savings: **300-500MB** in the final production image.

### 3. Development vs Production

#### Production Build (default)
```bash
docker build -t backend:prod .
# or explicitly:
docker build --target prod -t backend:prod .
```

#### Development Build
```bash
docker build --target dev -t backend:dev .
# or use docker-compose with dev.yml:
docker compose -f docker-compose.yml -f docker/dev.yml build
```

The dev.yml automatically targets the `dev` stage and includes `CPANMOPTS=--with-develop --with-feature=off_server_dev_tools`.

## Build Order

1. `runtime-base` - Install runtime packages
2. `build-base` - Add build tools and -dev packages, build zxing-cpp
3. `builder` - Compile Perl modules from cpanfile
4. `runnable` - Copy compiled modules, remove build tools
5. `dev` - Alternative final stage with build tools for development (from build-base)
6. `prod` - Aliases runnable as the default production target (DEFAULT)

## Security Benefits

- **Reduced attack surface**: Production images don't contain compilers or development tools
- **Fewer CVEs**: Fewer packages means fewer potential vulnerabilities
- **Principle of least privilege**: Production only has what it needs to run

## Compatibility

### Backwards Compatibility
- The default target (`prod`) produces a production-ready image
- `make dev` continues to work as before, now using the `dev` target
- All existing docker-compose configurations work unchanged

### Layer Caching
- Build stages are ordered to maximize layer caching
- Runtime dependencies rarely change, so runtime-base is highly cacheable
- Build dependencies change less often than Perl modules, so build-base is cached
- Perl module compilation happens in a separate stage for better caching

## Known Issues & Workarounds

No known issues at this time. Previous CI-specific certificate workarounds have been removed as the necessary domains are now allow-listed.

## Migration Guide

### For Developers

No changes required! The existing `make dev` workflow continues to work.

### For Production Deployments

The default build target is `prod`, so no changes are needed:

```bash
# This builds the production image:
docker build -t backend:latest .

# This is equivalent to:
docker build --target prod -t backend:latest .
```

### For Custom Builds

If you need to build a specific stage:

```bash
# Build just the runtime base (for testing):
docker build --target runtime-base -t backend:runtime-base .

# Build with all build tools (development):
docker build --target dev -t backend:dev .
```

## Future Optimizations

Potential further improvements:

1. **Additional stage separation**: Consider splitting runtime-base into smaller stages
2. **Multi-architecture builds**: Leverage BuildKit for ARM64/AMD64 parallel builds
3. **Perl module optimization**: Further reduce Perl dependencies
4. **Layer squashing**: Consider squashing final layers for even smaller images

## Testing

To verify the optimization:

```bash
# Build and check image size
docker build -t backend:prod .
docker images backend:prod

# Compare with dev image
docker build --target dev -t backend:dev .
docker images backend:dev

# The prod image should be significantly smaller than dev
```

## References

- [Docker Multi-Stage Builds](https://docs.docker.com/build/building/multi-stage/)
- [Dockerfile Best Practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [Original Issue Discussion](https://github.com/openfoodfacts/openfoodfacts-server/issues) - Clean up and reorganize backend container build
