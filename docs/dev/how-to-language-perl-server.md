# How to setup Perl Language Server (LSP) for IDE support

This guide explains how to set up and use Perl Language Server (LSP) support for development in Docker containers with Cursor/VS Code.

The Perl LSP provides modern IDE features like syntax checking, IntelliSense, go-to definition, and debugging capabilities for Perl development in the OpenFoodFacts project.

## Prerequisites

Before setting up the Perl LSP, ensure you have:

- **Docker development environment** already set up following the [dev environment quick start guide](how-to-quick-start-guide.md)
- **Cursor or VS Code** installed on your machine
- **Basic Docker knowledge** - see [how to develop using Docker](how-to-develop-using-docker.md)

> **_NOTE:_** New to Perl? Check [how to learn perl](how-to-learn-perl.md)!

## Quick Start

### 1. Complete Setup (Recommended)

For new developers, use the one-command setup:

```console
make lsp_setup
```

This command will:
- Install the Perl extension in your IDE
- Start the Perl Language Server container
- Configure everything automatically

### 1bis. Manual Step-by-Step Setup

If you prefer to set up manually:

```console
# 1. Start your main development environment (if not already running)
make dev

# 2. Start the Perl Language Server
make lsp_start

# 3. Install the Perl extension
make lsp_install
```

### 2. Modify your settings

You have to edit the vscode/setting.json with those keys:
```json
    "perl.sshCmd": "",
    "perl.perlInc": [],
    "perl.containerName": "po_off-perl-lsp-1",
    "perl.containerMode": "exec",
    "perl.containerArgs": [],
    "perl.disablePassEnv": true,
    "perl.logLevel": 2,
    "perl.containerCmd": "docker",
    "perl.pathMap": [["file:///opt/product-opener", "file:///home/alex/docker/off-server"]]
```
For the last line, it of course depends on where your project is located 
(here it was located in `/home/alex/docker/off-server`).

### 3. Verify Setup

Open any Perl file (e.g., `cgi/auth.pl`) in your IDE and verify:
- Syntax highlighting works
- Error detection appears
- Ctrl/Cmd+Click for go-to-definition
- IntelliSense suggestions appear

## Available Make Commands

The Perl LSP integrates with the existing make command structure:

```console
# Setup and management
make lsp_setup     # Complete setup (install extension + start server)
make lsp_start     # Start Perl Language Server
make lsp_stop      # Stop Perl Language Server
make lsp_restart   # Restart Perl Language Server

# Monitoring and debugging
make lsp_status    # Check LSP server status
make lsp_logs      # View LSP server logs
make lsp_test      # Test LSP functionality
make lsp_shell     # Access container shell

# Extension management
make lsp_install   # Install Perl extension for Cursor/VS Code
```

## IDE Features

Once the LSP server is running and the Perl extension is installed, you get:

### Syntax Checking
- Real-time error detection
- Warning highlights
- Compile-time error checking

### IntelliSense
- Auto-completion for variables, functions, and modules
- Context-aware suggestions
- Documentation on hover

### Navigation
- **Go to Definition**: Ctrl/Cmd+Click on symbols
- **Find References**: Right-click → "Find All References"
- **Symbol search**: Ctrl/Cmd+T to search symbols

### Debugging
- Set breakpoints in Perl code
- Step through code execution
- Inspect variables and call stack
- Support for CGI script debugging

## Debugging Perl Scripts

The LSP setup includes pre-configured debugging profiles:

1. **Set breakpoints** in your Perl code by clicking in the gutter
2. **Press F5** or use "Run and Debug" panel
3. **Choose debug configuration**:
   - `Debug Perl Script` - for regular Perl scripts
   - `Debug Perl CGI Script` - for CGI scripts with web environment
   - `Debug Current Perl File in Container` - for container-specific debugging

## Architecture Overview

### Docker Integration

The Perl LSP runs in a separate Docker container that:
- Extends your existing development environment
- Exposes the LSP server on port `13603`
- Binds to `0.0.0.0` to work across Docker network boundaries
- Includes health checks and proper volume mounts

### Key Files

- **`docker/perl-lsp.yml`** - Docker Compose configuration
- **`scripts/perl-lsp-server.sh`** - Container startup script
- **`scripts/start-perl-lsp.sh`** - Management script
- **`.vscode/settings.json`** - IDE configuration
- **`.vscode/launch.json`** - Debug configurations

### Network Configuration

- **LSP Server Port**: `13603`
- **Docker Port Mapping**: `13603:13603`
- **Host Access**: `localhost:13603`
- **Container Path**: `/opt/product-opener`
- **Perl Libraries**: `/opt/product-opener/lib/` and `/opt/perl/local/lib/perl5/`

## Troubleshooting

### LSP Server Won't Start

1. **Check Docker is running**:
   ```console
   docker info
   ```

2. **Check port availability**:
   ```console
   lsof -i :13603
   ```

3. **View container logs**:
   ```console
   make lsp_logs
   ```

4. **Test functionality**:
   ```console
   make lsp_test
   ```

### IDE Not Connecting

1. **Verify LSP server is running**:
   ```console
   make lsp_status
   ```

2. **Check extension installation**:
   - Open VS Code/Cursor extensions panel
   - Look for "Perl" extension by richterger
   - Reinstall if necessary: `make lsp_install`

3. **Restart IDE or reload window**:
   - VS Code: Ctrl/Cmd+Shift+P → "Developer: Reload Window"
   - Cursor: Similar reload command

### Performance Issues

If the LSP server is slow or unresponsive:

1. **Check container resources**:
   ```console
   docker stats openfoodfacts-server-perl-lsp-1
   ```

2. **Disable cache** (edit `.vscode/settings.json`):
   ```json
   "perl-language-server.disableCache": true
   ```

3. **Reduce log level**:
   ```json
   "perl-language-server.logLevel": 0
   ```

### Debugging Issues

1. **Check path mappings** in `.vscode/launch.json`
2. **Verify PERL5LIB** includes project libraries
3. **Ensure container access** to source files
4. **Test with simple script** first

## Development Workflow

### Daily Development

```console
# Start main development environment
make up

# Start LSP server
make lsp_start

# Start coding with full IDE support!
```

### Integration with Existing Workflow

The LSP setup integrates seamlessly:
- Works alongside existing `make dev` workflow
- Doesn't interfere with main development containers
- Can be started/stopped independently
- Uses same Docker network as main containers

### Team Development

The configuration is version-controlled and shareable:
- All team members get identical LSP setup
- No manual configuration required
- Consistent development experience across machines
- Works on macOS, Linux, and Windows with Docker

## Technical Details

### Public Interface Binding Fix

The setup solves the Docker networking issue (GitHub issue #131) by configuring the LSP server to bind to `0.0.0.0` instead of `localhost`:

```perl
my $server = Perl::LanguageServer->new({
    host => "0.0.0.0",  # Bind to all interfaces
    port => 13603,
    # ... other configuration
});
```

### Dependencies

The LSP server uses these Perl modules (already in `cpanfile`):
- `Perl::LanguageServer` - Main LSP implementation
- `Hash::SafeKeys` - Required dependency
- `IO::Socket::INET` - Network communication
- `JSON` - Protocol communication

### Health Monitoring

The container includes health checks that verify:
- LSP server responds on port 13603
- Perl dependencies are available
- Container is healthy and ready

## Advanced Configuration

### Custom LSP Settings

Edit `.vscode/settings.json` to customize:
- Log levels and debugging output
- Cache behavior and performance
- Path mappings between host and container
- Debugging options and breakpoint behavior

### Container Customization

Edit `docker/perl-lsp.yml` to:
- Change port mappings
- Add environment variables
- Mount additional volumes
- Modify resource limits

### Script Customization

Edit `scripts/perl-lsp-server.sh` to:
- Change LSP server configuration
- Add custom initialization steps
- Modify logging behavior
- Add project-specific setup

## Maintenance

### Updating Dependencies

When Perl dependencies change:
1. Update `cpanfile`
2. Rebuild LSP container: `make lsp_restart`

### Log Management

LSP logs are available in:
- **Container logs**: `make lsp_logs`
- **Internal log file**: `/tmp/perl-lsp.log` (inside container)
- **Access container**: `make lsp_shell`

### Cleanup

To clean up LSP resources:
```console
make lsp_stop
docker system prune -f --filter "label=com.docker.compose.project=docker"
```

## Support and Resources

### Getting Help

1. **Check this guide** for common issues and solutions
2. **View container logs**: `make lsp_logs`
3. **Test functionality**: `make lsp_test`
4. **Access container shell**: `make lsp_shell`

### External Resources

- [Perl::LanguageServer documentation](https://metacpan.org/pod/Perl::LanguageServer)
- [VS Code Perl extension](https://marketplace.visualstudio.com/items?itemName=richterger.perl)
- [Docker Compose documentation](https://docs.docker.com/compose/)

### Related Documentation

- [How to setup dev environment](how-to-quick-start-guide.md)
- [How to develop using Docker](how-to-develop-using-docker.md)
- [How to learn Perl](how-to-learn-perl.md)