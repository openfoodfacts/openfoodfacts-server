# GitHub Agent Environment Setup

This document provides instructions for GitHub's coding agent to work effectively with the Open Food Facts server codebase.

## Development Workflow

As a developer would, use the `make` command to manage the development environment:

### Initial Setup

```bash
make dev
```

This command will:
- Build and run all necessary containers
- Initialize the backend
- Import sample data (~100 products)
- Create MongoDB indexes
- Set up the complete development environment

### Common Make Targets

- `make up` - Build and run containers from local directory with live code reloading
- `make down` - Stop all containers
- `make build` - Build container images
- `make import_sample_data` - Load test data into the database
- `make import_prod_data` - Import full production data (~2M products)
- `make test` - Run the test suite
- `make lint` - Run linting checks

### Environment Access

After running `make dev`, the application will be available at:
- **Main site**: http://world.openfoodfacts.localhost/
- **French site**: http://fr.openfoodfacts.localhost/
- **Static files**: http://static.openfoodfacts.localhost/

### Development Notes

1. **First build** can take 10-30 minutes depending on machine specs and internet connection
2. **Test products** may not appear immediately - create an account and login to see them
3. **Docker requirements**: Ensure adequate disk space and memory (recommended: 8GB RAM minimum)
4. **Dependencies**: The project uses external dependencies managed through git submodules

### Authentication (Keycloak)

The development environment is configured to work without requiring a full Keycloak instance:
- `OIDC_IMPLEMENTATION_LEVEL=1` in `.env` provides basic authentication
- Full Keycloak integration is only required for integration tests
- For development, the system can work with simplified authentication

### Troubleshooting

If you encounter issues:

1. **Container build failures**: Run `make down` followed by `make dev`
2. **Port conflicts**: Check that ports 80 and other service ports are not in use
3. **Memory issues**: Docker may need more memory allocated (8GB+ recommended)
4. **Network issues**: Ensure Docker networking is properly configured

For detailed development setup instructions, see [docs/dev/how-to-quick-start-guide.md](docs/dev/how-to-quick-start-guide.md).

### Integration with CI/CD

The agent should use the same commands that developers use:
- Use `make` targets for all operations
- Follow the established patterns in the codebase
- Test changes with `make test` before proposing them
- Use `make lint` to ensure code quality

This approach ensures consistency between agent contributions and developer workflow.