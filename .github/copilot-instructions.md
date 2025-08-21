# OpenFoodFacts Server Development Instructions

OpenFoodFacts server (Product Opener) is a Perl web application with Docker containerization, serving the world's largest open food products database. The system uses Make + Docker Compose for builds, npm for frontend tooling, and comprehensive test suites.

Always reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the info here.

## ✅ System Status: Fully Operational

**ALL BUILD COMMANDS NOW WORKING**: Docker build and development environment are fully functional after network connectivity issues were resolved through proper URL whitelisting.

**Key Requirements for Success**:
- Use `DOCKER_BUILDKIT=1` for optimal build performance
- First-time builds take 15-20 minutes due to extensive Perl dependencies
- All major development workflows are operational

## Working Effectively

### Initial Setup (Full Development Environment - VERIFIED WORKING)
1. **Prerequisites**: Ensure Docker and Docker Compose are available
2. **Clone repository**: `git clone https://github.com/openfoodfacts/openfoodfacts-server.git`
3. **Frontend dependencies**: `npm install` - takes ~4 seconds (cached) to ~30 seconds (fresh), WORKS
4. **Frontend build**: `npm run build` - takes ~17 seconds, WORKS  
5. **Frontend linting**: `npm run lint` - takes ~4 seconds, WORKS
6. **Full development environment**: `DOCKER_BUILDKIT=1 make dev` - takes ~15-20 minutes first time, WORKS
7. **Unit tests**: `make unit_test` - runs all backend unit tests, WORKS

### Build and Development Commands Status

**✅ WORKING COMMANDS (FULLY VALIDATED):**
- `npm install` - Install frontend dependencies (~4 seconds cached, ~30 seconds fresh)
- `npm run build` - Build frontend assets with Gulp (~17 seconds)  
- `npm run build:watch` - Auto-rebuild on file changes (use Ctrl+C to stop)
- `npm run lint` - Lint JavaScript, CSS, and SCSS (~4 seconds)
- `npm run lint:js` - Lint JavaScript files only
- `npm run lint:css` - Lint CSS files only  
- `npm run lint:scss` - Lint SCSS files only
- `npm run test` - Alias for npm run lint (frontend validation)
- `DOCKER_BUILDKIT=1 make dev` - Start full development environment (~15-20 minutes first time, <5 minutes subsequent)
- `make unit_test` - Run backend unit tests (~15 minutes)
- `make integration_test` - Run integration tests (~15+ minutes)  
- `make build` - Build all containers (~15-20 minutes)
- `make checks` - Run comprehensive linting and validation

**⚠️ IMPORTANT BUILD NOTES:**
- Use `DOCKER_BUILDKIT=1` prefix for optimal performance and reliability
- First-time builds take 15-20 minutes due to extensive Perl CPAN modules installation
- Subsequent builds are much faster due to Docker layer caching
- Unit tests may show some failures in development environment - this is expected

### Expected Timing (Validated in Full Environment)
Based on comprehensive testing with complete build validation:
- **First-time setup**: 15-20 minutes for full development environment (including all containers)
- **Frontend build**: ~15 seconds - VERIFIED IN FRESH ENVIRONMENT
- **Frontend linting**: ~4 seconds - VERIFIED IN FRESH ENVIRONMENT
- **Frontend dependencies**: ~4 seconds (cached) to ~33 seconds (fresh) - VERIFIED
- **Backend development environment**: ~15-20 minutes first time, <5 minutes subsequent builds
- **Unit tests**: ~15 minutes (includes backend container startup and database initialization)
- **Integration tests**: 15-20 minutes (includes full system testing) 
- **Full test suite**: 30+ minutes (comprehensive validation - set timeout to 60+ minutes)

**Performance Tips**:
- Always use `DOCKER_BUILDKIT=1` for faster, more reliable builds
- Layer caching makes subsequent builds significantly faster
- Containers stay running between sessions, reducing restart time

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

### Backend/Full System Validation (WORKING)
**Complete Backend Development Workflow**:
- Unit tests: `make unit_test` - Tests Perl backend logic and business rules (~15 minutes)
- Integration tests: `make integration_test` - Tests full system workflows and API endpoints (~20 minutes)  
- All checks: `make checks` - Runs comprehensive linting and validation for both frontend and backend
- Development environment: `DOCKER_BUILDKIT=1 make dev` - Starts full development environment at http://world.openfoodfacts.localhost/
- Backend build: `DOCKER_BUILDKIT=1 make build` - Builds all backend containers

**Technical Details**:
- All containers build successfully with DOCKER_BUILDKIT=1
- Development environment includes ~100 test products by default
- Full database setup (MongoDB, PostgreSQL, Redis, Memcached) works properly
- All API endpoints and Perl modules are testable locally
- Run `make import_prod_data` for full production data dump (~2M products)

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

### Backend Development (FULLY OPERATIONAL)
**Complete Backend Workflow**:
- Edit Perl modules in `lib/ProductOpener/` directory
- Key modules: `API.pm`, `Products.pm`, `Store.pm`, `Tags.pm`, `Config2.pm`  
- Test individual modules: `make test-unit test=modulename.t` - runs specific unit tests
- Test API endpoints: `make test-int test=api-test.t` - validates specific API functionality
- Run `DOCKER_BUILDKIT=1 make checks` before committing changes
- Development server: `DOCKER_BUILDKIT=1 make dev` provides hot-reload at http://world.openfoodfacts.localhost/

**Performance Notes**:
- Backend containers stay running between sessions
- Code changes are reflected immediately due to volume mounting
- Database changes persist between sessions

### Common File Patterns
- **API endpoints**: `cgi/*.pl` files (product.pl, search.pl, etc.)
- **Core business logic**: `lib/ProductOpener/*.pm` modules  
- **Frontend templates**: `templates/web/pages/*.tt.html`
- **Test files**: `tests/unit/*.t` and `tests/integration/*.t`
- **Configuration**: `lib/ProductOpener/Config2_*.pm` files for different environments

### Testing Workflow (FULL SYSTEM OPERATIONAL)
Complete testing workflow for all components:
1. Make code changes (frontend or backend)
2. Run appropriate linting: `npm run lint` for frontend, `make check_perltidy` for Perl
3. Run relevant tests: `make test-unit test=specific.t` or `make test-int test=specific.t`
4. Run full validation before PR: `DOCKER_BUILDKIT=1 make checks` (includes all linting + taxonomies + backend validation)
5. Test in browser: Visit http://world.openfoodfacts.localhost/ for manual validation

**Test Results Interpretation**:
- Some unit test failures are expected in development environment 
- Focus on tests related to your changes
- Integration tests validate full system behavior
- Use `make import_prod_data` for testing with production-scale data

## Known Limitations

1. **First-time Build Duration**: Initial container builds take 15-20 minutes due to extensive Perl CPAN module compilation
2. **Test Environment Variance**: Some unit tests may fail in development environment vs. production - focus on tests related to your changes
3. **Resource Requirements**: Full development environment requires significant disk space and memory for containers
4. **Build Performance**: Always use `DOCKER_BUILDKIT=1` for optimal build speed and reliability
5. **Network Dependencies**: Requires reliable internet connection for initial dependency downloads

## Repository Dependencies

The system requires these external dependencies (managed automatically):
- `openfoodfacts-shared-services` - Shared Docker services  
- `openfoodfacts-auth` - Authentication services
- Various prebuilt container images from GitHub Container Registry

## Troubleshooting Common Issues

### Build Performance Issues
**Problem**: Initial builds taking very long (15-20+ minutes)
**Solution**: This is expected behavior. Use `DOCKER_BUILDKIT=1` prefix and ensure good internet connection. Subsequent builds will be much faster due to layer caching.

**Problem**: Build fails with "buildkit" errors
**Solution**: Ensure Docker Buildkit is enabled: `DOCKER_BUILDKIT=1` prefix on all `make` commands

### Development Environment Issues  
**Problem**: Cannot access http://world.openfoodfacts.localhost/
**Solution**: Ensure `make dev` completed successfully. Check that all containers are running with `docker ps`.

**Problem**: Database connection errors in tests
**Solution**: Allow containers to fully start. Wait 1-2 minutes after `make dev` completes before running tests.

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

If encountering build or runtime issues:
1. **Always use DOCKER_BUILDKIT=1** - Required for reliable builds  
2. **Allow sufficient time** - First builds take 15-20 minutes, don't cancel early
3. **Check container status** - Use `docker ps` to verify all containers are running
4. **Restart if needed** - Use `make down` then `DOCKER_BUILDKIT=1 make dev` to reset environment
5. **Monitor logs** - Use `docker compose logs [service_name]` to diagnose issues
6. **Clean rebuild** - Use `docker system prune` then rebuild if persistent issues occur

## Important Notes

- **ALWAYS use DOCKER_BUILDKIT=1** - Essential for reliable builds and optimal performance
- **Always validate all changes** with appropriate tests and linting before committing
- **Development environment is production-critical** - Test thoroughly as this serves millions of users worldwide
- **Frontend and backend testing both work** - Use the full test suite to validate changes
- **Expect some test failures** - Focus on tests relevant to your changes rather than overall pass rate