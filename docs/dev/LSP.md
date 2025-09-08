# Perl Language Server Setup for OpenFoodFacts Server

This document explains how to set up and use Perl Language Server (LSP) support for development in Docker containers with Cursor/VS Code.

## Overview

The Perl LSP setup provides:
- ✅ Syntax checking and error detection
- ✅ IntelliSense/autocompletion for Perl code
- ✅ Go-to definition and find references
- ✅ Debugging capabilities
- ✅ Docker container integration
- ✅ Public interface binding (fixes GitHub issue #131)

## Quick Start

### 1. Start the LSP Server

**Using Make Commands (Recommended):**
```bash
# Complete setup (install extension + start server)
make lsp_setup

# Or individual commands:
make lsp_start    # Start the Perl Language Server container
make lsp_status   # Check status
make lsp_logs     # View logs
```

**Using Scripts Directly:**
```bash
# Start the Perl Language Server container
./scripts/start-perl-lsp.sh start

# Check status
./scripts/start-perl-lsp.sh status

# View logs
./scripts/start-perl-lsp.sh logs
```

### 2. Configure Cursor/VS Code

The configuration files are already created:
- `.vscode/settings.json` - LSP client configuration
- `.vscode/launch.json` - Debugging configuration

### 3. Install Perl Extension

In Cursor/VS Code:
1. Install the "Perl" extension by richterger
2. The extension will automatically connect to the LSP server on `localhost:13603`

## Architecture

### Docker Configuration

**File: `docker/perl-lsp.yml`**
- Extends the development environment
- Exposes LSP server on port 13603
- Binds to `0.0.0.0` to work across Docker network boundaries
- Includes health checks and proper volume mounts

**File: `scripts/perl-lsp-server.sh`**
- Container startup script
- Configures LSP server to bind to public interfaces
- Handles dependency installation and validation

### LSP Client Configuration

**File: `.vscode/settings.json`**
- Configures Perl extension to connect to containerized LSP server
- Sets up proper path mappings and Perl library paths
- Enables debugging and advanced LSP features

**File: `.vscode/launch.json`**
- Debugging configurations for Perl scripts
- Path mapping between host and container
- Support for CGI script debugging

## Usage

### Starting/Stopping LSP Server

**Using Make Commands (Recommended):**
```bash
# Complete setup for new developers
make lsp_setup     # Install extension + start server

# Individual commands
make lsp_start     # Start LSP server
make lsp_stop      # Stop LSP server  
make lsp_restart   # Restart LSP server
make lsp_status    # Check status
make lsp_logs      # View logs
make lsp_test      # Test functionality
make lsp_shell     # Access container shell
make lsp_install   # Install Perl extension
```

**Using Scripts Directly:**
```bash
# Start LSP server
./scripts/start-perl-lsp.sh start

# Stop LSP server
./scripts/start-perl-lsp.sh stop

# Restart LSP server
./scripts/start-perl-lsp.sh restart

# Check status
./scripts/start-perl-lsp.sh status

# View logs
./scripts/start-perl-lsp.sh logs

# Test functionality
./scripts/start-perl-lsp.sh test

# Access container shell
./scripts/start-perl-lsp.sh shell
```

### IDE Features

Once the LSP server is running and the Perl extension is installed:

1. **Syntax Checking**: Errors and warnings appear in real-time
2. **IntelliSense**: Auto-completion for variables, functions, and modules
3. **Go to Definition**: Ctrl/Cmd+Click on symbols to jump to definitions
4. **Find References**: Right-click → "Find All References"
5. **Debugging**: Use F5 to start debugging with breakpoints

### Debugging Perl Scripts

1. Set breakpoints in your Perl code
2. Press F5 or use "Run and Debug" panel
3. Choose appropriate debug configuration:
   - "Debug Perl Script" - for regular Perl scripts
   - "Debug Perl CGI Script" - for CGI scripts with environment setup
   - "Debug Current Perl File in Container" - for container-specific debugging

## Technical Details

### Public Interface Binding Solution

The key fix for GitHub issue #131 is in `scripts/perl-lsp-server.sh`:

```perl
my $server = Perl::LanguageServer->new({
    host => "0.0.0.0",  # Bind to all interfaces, not just localhost
    port => 13603,
    # ... other configuration
});
```

This allows the LSP server running inside the Docker container to accept connections from the host machine.

### Port Configuration

- **LSP Server Port**: 13603
- **Docker Port Mapping**: `13603:13603`
- **Host Access**: `localhost:13603`

### Path Mapping

The LSP server maps paths between host and container:
- **Container Path**: `/opt/product-opener`
- **Host Path**: Your project directory
- **Perl Libraries**: `/opt/product-opener/lib/` and `/opt/perl/local/lib/perl5/`

### Dependencies

The LSP server requires these Perl modules (already in cpanfile):
- `Perl::LanguageServer`
- `Hash::SafeKeys`
- `IO::Socket::INET`
- `JSON`

## Troubleshooting

### LSP Server Won't Start

1. Check Docker is running:
   ```bash
   docker info
   ```

2. Check port availability:
   ```bash
   lsof -i :13603
   ```

3. View container logs:
   ```bash
   ./scripts/start-perl-lsp.sh logs
   ```

### IDE Not Connecting

1. Verify LSP server is running:
   ```bash
   ./scripts/start-perl-lsp.sh status
   ```

2. Check Perl extension configuration in VS Code settings
3. Restart the Perl extension or reload VS Code window

### Debugging Issues

1. Ensure path mappings are correct in `.vscode/launch.json`
2. Check PERL5LIB environment variable includes project libraries
3. Verify container has access to source files

### Performance Issues

1. Disable cache if needed:
   ```json
   "perl-language-server.disableCache": true
   ```

2. Reduce log level:
   ```json
   "perl-language-server.logLevel": 0
   ```

## Development Workflow

### Recommended Setup

1. Complete LSP setup: `make lsp_setup`
2. Open project in Cursor/VS Code  
3. Start coding with full LSP support!

**Alternative step-by-step:**
1. Start main development: `make dev`
2. Start LSP server: `make lsp_start`
3. Install Perl extension: `make lsp_install`
4. Start coding with full LSP support!

### Integration with Existing Development

The LSP setup integrates seamlessly with existing development workflow:
- Works alongside `docker-compose -f docker/dev.yml`
- Doesn't interfere with existing containers
- Can be started/stopped independently

### Team Development

The configuration is version-controlled and shareable:
- All team members get the same LSP setup
- No manual configuration required
- Consistent development experience across machines

## Advanced Configuration

### Custom LSP Settings

Edit `.vscode/settings.json` to customize:
- Log levels
- Cache behavior
- Path mappings
- Debugging options

### Container Customization

Edit `docker/perl-lsp.yml` to:
- Change port mappings
- Add environment variables
- Mount additional volumes
- Modify resource limits

### Script Customization

Edit `scripts/perl-lsp-server.sh` to:
- Change LSP server configuration
- Add custom initialization
- Modify logging behavior

## Maintenance

### Updating Dependencies

When Perl dependencies change:
1. Update cpanfile
2. Rebuild LSP container: `./scripts/start-perl-lsp.sh restart`

### Log Management

LSP logs are stored in:
- Container: `/tmp/perl-lsp.log`
- Docker logs: `docker logs openfoodfacts-server-perl-lsp-1`

### Health Monitoring

The LSP container includes health checks that verify:
- LSP server is responding on port 13603
- Perl dependencies are available
- Container is healthy

## Support

For issues with this LSP setup:
1. Check this README for troubleshooting steps
2. View container logs for error details
3. Test with `./scripts/start-perl-lsp.sh test`
4. Refer to [Perl::LanguageServer documentation](https://metacpan.org/pod/Perl::LanguageServer)

## Files Created/Modified

This setup creates the following files:
- `docker/perl-lsp.yml` - Docker Compose configuration
- `scripts/perl-lsp-server.sh` - LSP server startup script
- `scripts/start-perl-lsp.sh` - Management script
- `.vscode/settings.json` - VS Code/Cursor settings
- `.vscode/launch.json` - Debug configurations
- `README-PERL-LSP.md` - This documentation

The setup leverages existing files:
- `cpanfile` - Already includes Perl::LanguageServer in development dependencies
- `Dockerfile` - Used as base for LSP container
- Existing Docker development infrastructure
