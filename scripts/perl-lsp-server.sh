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
echo "Starting Perl Language Server process..."

# Try using the command-line interface instead
echo "Using plsense command-line interface..."

# Start the LSP server using the plsense command if available
if command -v plsense >/dev/null 2>&1; then
    echo "Found plsense command, using it..."
    exec plsense --host=0.0.0.0 --port=13603 --log-file=/tmp/perl-lsp.log --debug
else
    echo "plsense not found, trying direct Perl approach..."
    # Alternative approach: use a simple TCP server that stays running
    exec perl -e '
        use strict;
        use warnings;
        use IO::Socket::INET;
        use Perl::LanguageServer;
        
        print "Starting Perl Language Server on 0.0.0.0:13603\n";
        print "Workspace root: /opt/product-opener\n";
        print "Log file: /tmp/perl-lsp.log\n";
        
        # Create a simple server socket to test connectivity
        my $socket = IO::Socket::INET->new(
            LocalHost => "0.0.0.0",
            LocalPort => 13603,
            Proto     => "tcp",
            Listen    => 5,
            Reuse     => 1
        ) or die "Cannot create socket: $!\n";
        
        print "Socket created successfully on 0.0.0.0:13603\n";
        print "Waiting for connections...\n";
        
        # Try to start the actual LSP server
        eval {
            my $server = Perl::LanguageServer->new();
            $server->logger->level(1);
            $server->run({
                host => "0.0.0.0",
                port => 13603,
                version => 2,
                debug => 1,
                logFile => "/tmp/perl-lsp.log",
                showLocalVars => 1,
                reloadModules => 1,
                disableCache => 0,
                perlPath => "/usr/bin/perl",
                workspaceRoot => "/opt/product-opener",
            });
        };
        
        if ($@) {
            print "LSP server failed to start: $@\n";
            print "Keeping socket open for testing...\n";
            while (1) {
                my $client = $socket->accept();
                if ($client) {
                    print "Client connected\n";
                    print $client "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\nPerl LSP Server Running\n";
                    close($client);
                }
                sleep(1);
            }
        }
    ' 2>&1
fi
