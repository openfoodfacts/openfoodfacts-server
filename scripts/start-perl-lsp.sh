#!/bin/bash

# Perl Language Server Docker Management Script
# This script handles starting, stopping, and managing the Perl LSP container

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$PROJECT_ROOT/docker/perl-lsp.yml"
CONTAINER_NAME="po_off-perl-lsp-1"
LSP_PORT=13603

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[LSP]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[LSP]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[LSP]${NC} $1"
}

print_error() {
    echo -e "${RED}[LSP]${NC} $1"
}

# Function to check if Docker is running
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker first."
        exit 1
    fi
}

# Function to check if port is available
check_port() {
    if lsof -Pi :$LSP_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
        print_warning "Port $LSP_PORT is already in use. Checking if it's our LSP container..."
        if docker ps --format "table {{.Names}}\t{{.Ports}}" | grep -q "$CONTAINER_NAME.*$LSP_PORT"; then
            print_status "LSP container is already running on port $LSP_PORT"
            return 0
        else
            print_error "Port $LSP_PORT is in use by another process. Please free the port first."
            lsof -Pi :$LSP_PORT -sTCP:LISTEN
            exit 1
        fi
    fi
}

# Function to start the LSP server
start_lsp() {
    print_status "Starting Perl Language Server..."
    
    check_docker
    check_port
    
    # Set environment variables (use 1000 for GID to avoid conflicts)
    export USER_UID=$(id -u)
    export USER_GID=1000
    
    print_status "Starting LSP container..."
    cd "$PROJECT_ROOT"
    
    # Start the LSP service
    docker compose -f "$COMPOSE_FILE" up -d
    # TODO: we should check it's really started…
    print_success "Container started"
    docker ps |grep $CONTAINER_NAME
}

# Function to stop the LSP server
stop_lsp() {
    print_status "Stopping Perl Language Server..."
    
    cd "$PROJECT_ROOT"
    docker compose -f "$COMPOSE_FILE" down
    
    print_success "Perl Language Server stopped"
}

# Function to restart the LSP server
restart_lsp() {
    print_status "Restarting Perl Language Server..."
    stop_lsp
    sleep 2
    start_lsp
}

# Function to show LSP server status
status_lsp() {
    echo "FIXME: implement this"
    exit 1
}

# Function to show LSP server logs
logs_lsp() {
    print_status "Showing Perl Language Server logs..."
    
    if docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
        docker logs -f "$CONTAINER_NAME"
    else
        print_error "LSP container is not running"
        exit 1
    fi
}

# Function to connect to LSP container shell
shell_lsp() {
    print_status "Connecting to Perl Language Server container shell..."
    
    if docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
        docker exec -it "$CONTAINER_NAME" /bin/bash
    else
        print_error "LSP container is not running"
        exit 1
    fi
}

# Function to test LSP functionality
test_lsp() {
    print_status "Testing Perl Language Server functionality..."
    
    if ! docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
        print_error "LSP container is not running. Start it first with: $0 start"
        exit 1
    fi
    
    # Test basic Perl syntax
    local test_file="/tmp/test_lsp.pl"
    cat > "$test_file" << 'EOF'
#!/usr/bin/perl
use strict;
use warnings;
use ProductOpener::Config qw/:all/;

print "Testing LSP functionality\n";

# Test variable
my $test_var = "Hello World";
print "$test_var\n";

# Test subroutine
sub test_function {
    my $param = shift;
    return "Processed: $param";
}

my $result = test_function("test");
print "$result\n";
EOF
    
    print_status "Testing Perl syntax check..."
    if docker exec "$CONTAINER_NAME" perl -c "$test_file" 2>/dev/null; then
        print_success "Perl syntax check passed"
    else
        print_error "Perl syntax check failed"
    fi
    
    print_status "Testing LSP server connection..."
    if curl -s --connect-timeout 5 "http://localhost:$LSP_PORT" >/dev/null 2>&1; then
        print_success "LSP server is accessible"
    else
        print_warning "LSP server connection test inconclusive (this is normal for LSP protocol)"
    fi
    
    # Clean up
    rm -f "$test_file"
}

# Function to show help
show_help() {
    cat << EOF
Perl Language Server Docker Management Script

Usage: $0 [COMMAND]

Commands:
    start       Start the Perl Language Server container
    stop        Stop the Perl Language Server container
    restart     Restart the Perl Language Server container
    status      Show the status of the LSP server
    logs        Show and follow the LSP server logs
    shell       Connect to the LSP container shell
    test        Test LSP functionality
    help        Show this help message

Examples:
    $0 start        # Start the LSP server
    $0 status       # Check if LSP server is running
    $0 logs         # View LSP server logs
    $0 test         # Test LSP functionality

The LSP server will be available on localhost:$LSP_PORT for your IDE to connect to.

For Cursor/VS Code integration:
1. Install the Perl extension
2. Configure the extension to connect to localhost:$LSP_PORT
3. The .vscode/settings.json file has been configured automatically

EOF
}

# Main script logic
case "${1:-help}" in
    start)
        start_lsp
        ;;
    stop)
        stop_lsp
        ;;
    restart)
        restart_lsp
        ;;
    status)
        status_lsp
        ;;
    logs)
        logs_lsp
        ;;
    shell)
        shell_lsp
        ;;
    test)
        test_lsp
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
