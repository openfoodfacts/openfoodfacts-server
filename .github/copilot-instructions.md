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
- `npm run build:watch` - Auto-rebuild on file changes (use Ctrl+C to stop)
- `npm run lint` - Lint JavaScript, CSS, and SCSS (~4 seconds)
- `npm run lint:js` - Lint JavaScript files only
- `npm run lint:css` - Lint CSS files only  
- `npm run lint:scss` - Lint SCSS files only
- `npm run test` - Alias for npm run lint (frontend validation)

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
- Manual review of generated files in `html/css/dist/` and `html/js/dist/` directories
- Check build artifacts: Verify CSS/JS files are generated in correct directories
- Test watch mode: `npm run build:watch` for development (auto-rebuilds on file changes)

**Frontend Development Workflow (VERIFIED):**
1. Edit source files in `scss/` directory for styles
2. Edit JavaScript files in `html/js/` directory  
3. Run `npm run build` to compile changes (~15 seconds)
4. Verify output files in `html/css/dist/` and `html/js/dist/`
5. Run `npm run lint` to check compliance (~4 seconds)
6. For active development: Use `npm run build:watch` (stops with Ctrl+C)

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
- `lib/ProductOpener/` - Perl backend modules and business logic (33+ modules)
- `html/` - Web frontend files and compiled assets  
- `scss/` - Frontend SCSS source files (compiled to `html/css/dist/`)
- `html/js/` - Frontend JavaScript files (processed to `html/js/dist/`)
- `tests/unit/` and `tests/integration/` - Test suites (unit tests and full system tests)
- `docker/` - Docker configuration and overrides
- `docs/dev/` - Development documentation
- `taxonomies/` - Food classification taxonomies (ingredients, categories, etc.)
- `templates/` - HTML templates for web interface
- `cgi/` - CGI scripts for web endpoints

### Critical Files
- `package.json` - Frontend dependencies and npm scripts  
- `gulpfile.ts` - Frontend build configuration (TypeScript)
- `cpanfile` - Perl backend dependencies
- `docker-compose.yml` - Main container orchestration  
- `Makefile` - Build automation and shortcuts (580+ lines)
- `.env` - Environment variables for Docker (PRODUCT_OPENER_DOMAIN, etc.)
- `lib/ProductOpener/Config2.pm` - Main backend configuration

## Common Development Tasks

### Frontend Development (WORKING)
- Edit source files in `scss/` and `html/js/` directories
- Run `npm run build` to compile changes  
- Run `npm run lint` to check style compliance
- Use `npm run build:watch` for auto-compilation during development

### Backend Development (WHEN DOCKER WORKS)
- Edit Perl modules in `lib/ProductOpener/` directory
- Key modules: `API.pm`, `Products.pm`, `Store.pm`, `Tags.pm`, `Config2.pm`  
- Test individual modules: `make test-unit test=modulename.t`
- Test API endpoints: `make test-int test=api-test.t`
- Always run `make checks` before committing changes

### Common File Patterns
- **API endpoints**: `cgi/*.pl` files (product.pl, search.pl, etc.)
- **Core business logic**: `lib/ProductOpener/*.pm` modules  
- **Frontend templates**: `templates/web/pages/*.tt.html`
- **Test files**: `tests/unit/*.t` and `tests/integration/*.t`
- **Configuration**: `lib/ProductOpener/Config2_*.pm` files for different environments

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

## Troubleshooting Common Issues

### Docker Build Failures
**Problem**: `make dev` fails with "Temporary failure resolving 'deb.debian.org'"
**Solution**: This is a known network connectivity issue. Use prebuilt images:
```bash
docker pull ghcr.io/openfoodfacts/openfoodfacts-server/backend:latest
docker pull ghcr.io/openfoodfacts/openfoodfacts-server/frontend:latest
```

**Problem**: `make build` fails after ~60 seconds with package installation errors  
**Solution**: Do not attempt local builds. Focus on frontend development with npm commands.

### Frontend Build Issues
**Problem**: `npm install` fails with permission errors
**Solution**: Ensure you have write permissions to the project directory

**Problem**: `npm run build` produces warnings about deprecated Sass @import rules
**Solution**: These are expected warnings. Build still succeeds - ignore deprecation warnings.

**Problem**: ESLint warnings during `npm run lint`  
**Solution**: These are style warnings, not errors. Build still succeeds. Fix with:
- Replace `var` with `let` or `const`
- Avoid unary operators like `++` and `--` where possible

### Performance Issues
**Problem**: Frontend builds seem slow
**Solution**: ~15 seconds is normal for full build. Use `npm run build:watch` during active development.

**Problem**: npm install takes too long
**Solution**: ~30 seconds is normal. Consider using npm ci for faster CI builds.

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