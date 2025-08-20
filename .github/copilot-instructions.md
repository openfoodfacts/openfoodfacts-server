# OpenFoodFacts Server Development Instructions

OpenFoodFacts server (Product Opener) is a Perl web application with Docker containerization, serving the world's largest open food products database. The system uses Make + Docker Compose for builds, npm for frontend tooling, and comprehensive test suites.

Always reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the info here.

## ⚠️ CRITICAL: Known Build Issues

**DOCKER BUILD FAILURES - NETWORK CONNECTIVITY ISSUES**: 
- The local Docker build process currently fails due to DNS resolution issues with Debian package repositories
- Error: "Temporary failure resolving 'deb.debian.org'" during `apt update` operations
- This affects ALL make commands that trigger container builds: `make dev`, `make build`, `make unit_test`, `make integration_test`
- **WORKAROUND**: Use prebuilt container images from GitHub Container Registry when available
- **DO NOT attempt to build containers locally** - it will fail after ~60 seconds with package installation errors

## Working Effectively

### Initial Setup (Frontend Only - VERIFIED WORKING)
1. **Prerequisites**: Ensure Docker and Docker Compose are available
2. **Clone repository**: `git clone https://github.com/openfoodfacts/openfoodfacts-server.git`
3. **Frontend dependencies**: `npm install` - takes ~30 seconds, WORKS
4. **Frontend build**: `npm run build` - takes ~15 seconds, WORKS  
5. **Frontend linting**: `npm run lint` - takes ~4 seconds, WORKS

### Build and Development Commands Status

**✅ WORKING COMMANDS:**
- `npm install` - Install frontend dependencies (~30 seconds)
- `npm run build` - Build frontend assets with Gulp (~15 seconds)  
- `npm run lint` - Lint JavaScript, CSS, and SCSS (~4 seconds)
- `npm run lint:js` - Lint JavaScript files only
- `npm run lint:css` - Lint CSS files only  
- `npm run lint:scss` - Lint SCSS files only

**❌ BROKEN COMMANDS (DNS/Network Issues):**
- `make dev` - **FAILS** after ~60 seconds with Debian package errors
- `make build` - **FAILS** after ~60 seconds with Debian package errors
- `make up` - **FAILS** during container build phase
- `make unit_test` - **FAILS** during container build phase  
- `make integration_test` - **FAILS** during container build phase
- `make checks` - **FAILS** because it requires backend container builds

### Expected Timing (When Working)
Based on documentation and partial validation:
- **First-time setup**: 10-30 minutes (when Docker build works)
- **Frontend build**: ~15 seconds - VERIFIED
- **Frontend linting**: ~4 seconds - VERIFIED  
- **Unit tests**: Estimated 15+ minutes (NEVER CANCEL - set timeout to 30+ minutes)
- **Integration tests**: Estimated 15+ minutes (NEVER CANCEL - set timeout to 30+ minutes)
- **Full test suite**: Estimated 30+ minutes (NEVER CANCEL - set timeout to 60+ minutes)

## Testing and Validation

### Frontend Validation (WORKING)
Always validate frontend changes with these WORKING commands:
- `npm run build` - Ensure frontend builds successfully
- `npm run lint` - Check code style compliance
- Manual review of generated files in `html/css/` and `html/js/` directories

### Backend/Full System Validation (CURRENTLY BROKEN)
**WARNING**: These commands currently fail due to Docker build issues:
- Unit tests: `make unit_test` - Would test Perl backend logic  
- Integration tests: `make integration_test` - Would test full system workflows
- All checks: `make checks` - Would run comprehensive linting and validation

### Manual Validation Scenarios (When System Works)
When the Docker build issues are resolved, always test these scenarios:
- Create a user account and login successfully
- View product pages and ensure images/data display correctly  
- Submit product edits and verify they are saved
- Search for products using the search functionality
- Test the mobile-responsive design on different screen sizes

## Repository Structure

### Key Directories
- `lib/` - Perl backend modules and business logic
- `html/` - Web frontend files (PHP/HTML)
- `js/` and `scss/` - Frontend source files (built to `html/js/` and `html/css/`)
- `tests/` - Unit and integration test suites  
- `docker/` - Docker configuration and overrides
- `docs/dev/` - Development documentation
- `taxonomies/` - Food classification taxonomies

### Configuration Files
- `package.json` - Frontend dependencies and npm scripts
- `cpanfile` - Perl dependencies
- `docker-compose.yml` - Main container orchestration
- `Makefile` - Build automation and shortcuts
- `.env` - Environment variables for Docker

## Common Development Tasks

### Frontend Development (WORKING)
- Edit source files in `scss/` and `html/js/` directories
- Run `npm run build` to compile changes  
- Run `npm run lint` to check style compliance
- Use `npm run build:watch` for auto-compilation during development

### Backend Development (WHEN DOCKER WORKS)
- Edit Perl modules in `lib/ProductOpener/` directory
- Test individual modules: `make test-unit test=modulename.t`
- Test API endpoints: `make test-int test=api-test.t`
- Always run `make checks` before committing changes

### Testing Workflow (WHEN SYSTEM WORKS)
1. Make code changes
2. Run appropriate linting: `npm run lint` for frontend, `make check_perltidy` for Perl
3. Run relevant tests: `make test-unit test=specific.t` or `make test-int test=specific.t`
4. Run full validation before PR: `make checks` (includes all linting + taxonomies)

## Known Limitations

1. **Critical Docker Build Failure**: Local container builds fail due to network connectivity issues with Debian repositories
2. **No Local Backend Testing**: Cannot validate backend changes locally until Docker issues resolved  
3. **Limited Development Environment**: Only frontend development/testing currently functional
4. **CI-Dependent**: Full testing requires GitHub Actions CI environment

## Repository Dependencies

The system requires these external dependencies (managed automatically):
- `openfoodfacts-shared-services` - Shared Docker services  
- `openfoodfacts-auth` - Authentication services
- Various prebuilt container images from GitHub Container Registry

## Emergency Procedures

If encountering build failures:
1. **DO NOT cancel long-running builds** - Some operations take 45+ minutes
2. Check if prebuilt images exist: `docker pull ghcr.io/openfoodfacts/openfoodfacts-server/backend:latest`
3. For frontend-only development, focus on `npm` commands which work reliably
4. For backend testing, rely on GitHub Actions CI pipeline
5. Document any new failure patterns for future developers

## Important Notes

- **NEVER CANCEL builds or tests** - Set timeouts of 60+ minutes minimum  
- **Always validate frontend changes** with `npm run build` and `npm run lint`
- **Network issues are environmental** - the same codebase works in CI/production
- **Focus on working tools** - Use npm for frontend development, document backend issues
- **Test early and often** - Run `npm run lint` frequently to catch style issues

This repository serves millions of users worldwide - treat every change as production-critical and test thoroughly within the constraints of the current environment.