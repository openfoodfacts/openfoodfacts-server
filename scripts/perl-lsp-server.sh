#!/bin/bash

# Perl Language Server startup script for Docker container
# This script addresses the public interface binding issue from GitHub issue #131

set -e

echo "Starting Perl Language Server..."
echo "Working directory: $(pwd)"
echo "Perl version: $(perl -v | head -2 | tail -1)"
echo "PERL5LIB: $PERL5LIB"

# Ensure Perl::LanguageServer is installed
if ! perl -e "use Perl::LanguageServer" 2>/dev/null; then
    echo "ERROR: Perl::LanguageServer not found. Installing..."
    cpanm --quiet Perl::LanguageServer Hash::SafeKeys
fi

# Check if LSP server dependencies are available
echo "Checking Perl::LanguageServer dependencies..."
perl -e "
use Perl::LanguageServer;
use Hash::SafeKeys;
use IO::Socket::INET;
use JSON;
print \"All dependencies OK\n\";
"

# Create LSP server configuration
cat > /tmp/perl-lsp-config.json << 'EOF'
{
    "host": "0.0.0.0",
    "port": 13603,
    "version": 2,
    "debug": true,
    "logLevel": 1,
    "pathMap": [],
    "perlPath": "/usr/bin/perl",
    "sshAddr": "",
    "sshPort": "",
    "sshUser": "",
    "sshCmd": "",
    "sshWorkspaceRoot": "",
    "logFile": "/tmp/perl-lsp.log",
    "showLocalVars": true,
    "reloadModules": true,
    "disableCache": false,
    "env": {}
}
EOF

echo "LSP Configuration:"
cat /tmp/perl-lsp-config.json

# Ensure log file exists and is writable
touch /tmp/perl-lsp.log
chmod 666 /tmp/perl-lsp.log

# Start the Perl Language Server
# Key fix: Bind to 0.0.0.0 instead of localhost to work across Docker network boundaries
echo "Starting Perl Language Server on 0.0.0.0:13603..."
echo "Project root: /opt/product-opener"

# Use exec to replace the shell process, ensuring proper signal handling
exec perl -MPerl::LanguageServer -e '
    use strict;
    use warnings;
    use Perl::LanguageServer;
    
    # Configure server to bind to public interface
    my $server = Perl::LanguageServer->new({
        host => "0.0.0.0",
        port => 13603,
        version => 2,
        debug => 1,
        logLevel => 1,
        logFile => "/tmp/perl-lsp.log",
        showLocalVars => 1,
        reloadModules => 1,
        disableCache => 0,
        perlPath => "/usr/bin/perl",
        workspaceRoot => "/opt/product-opener",
    });
    
    print "Perl Language Server starting on 0.0.0.0:13603\n";
    print "Workspace root: /opt/product-opener\n";
    print "Log file: /tmp/perl-lsp.log\n";
    
    # Start the server
    $server->run();
'
