#!/bin/bash

# Perl Language Server Setup script for Docker container

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

# Do nothing we just want to have a running server
exec sleep infinity
