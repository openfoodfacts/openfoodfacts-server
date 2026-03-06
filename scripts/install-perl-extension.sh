#!/bin/bash

# Script to install and configure Perl extension for Cursor/VS Code
# This automates the setup process for the Perl Language Server integration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[SETUP]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SETUP]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[SETUP]${NC} $1"
}

print_error() {
    echo -e "${RED}[SETUP]${NC} $1"
}

# Function to detect IDE
detect_ide() {
    if command -v cursor >/dev/null 2>&1; then
        echo "cursor"
    elif command -v code >/dev/null 2>&1; then
        echo "code"
    elif command -v codium > /dev/null 2>&1; then
        echo "codium"
    else
        echo "none"
    fi
}

# Function to install Perl extension
install_extension() {
    local ide=$1

    print_status "Installing Perl extension for $ide..."

    case $ide in
        cursor | code | codium)
            $ide --install-extension richterger.perl
            ;;
        *)
            print_error "No supported IDE found (cursor or code/codium)"
            return 1
            ;;
    esac
}

# Function to check if extension is installed
check_extension() {
    local ide=$1
    case $ide in
        cursor | code | codium)
            $ide --list-extensions | grep -q "richterger.perl"
            ;;
        *)
            return 1
            ;;
    esac
}

# Function to show setup instructions
show_instructions() {
    cat << 'EOF'

🎉 Perl Language Server Setup Complete!

Next Steps:
1. Start the LSP server:
   ./scripts/start-perl-lsp.sh start

2. Open your IDE (Cursor/VS Code/Codium) in this project directory

3. The Perl extension should automatically connect to the LSP server

4. Test the setup:
   - Open any .pl or .pm file
   - You should see syntax highlighting and error checking
   - Try Ctrl/Cmd+Click on a function to go to definition

Troubleshooting:
- If LSP doesn't connect, check: ./scripts/start-perl-lsp.sh status
- View LSP logs with: ./scripts/start-perl-lsp.sh logs
- Test functionality: ./scripts/start-perl-lsp.sh test

Configuration Files:
- .vscode/settings.json - LSP client settings
- .vscode/launch.json - Debug configurations
- docker/perl-lsp.yml - LSP server container
- README-PERL-LSP.md - Complete documentation

Happy coding! 🚀

EOF
}

# Main setup process
main() {
    print_status "Setting up Perl Language Server for OpenFoodFacts development..."
    
    # Detect IDE
    local ide=$(detect_ide)
    
    if [ "$ide" = "none" ]; then
        print_error "Neither Cursor nor VS Code / Codium found in PATH"
        print_status "Please install Cursor,VS Code or Codium and try again"
        print_status "Cursor: https://cursor.sh/"
        print_status "VS Code: https://code.visualstudio.com/"
        print_status "https://vscodium.com/"
        exit 1
    fi
    
    print_success "Detected IDE: $ide"
    
    # Check if extension is already installed
    if check_extension "$ide"; then
        print_success "Perl extension is already installed"
    else
        # Install extension
        if install_extension "$ide"; then
            print_success "Perl extension installed successfully"
        else
            print_error "Failed to install Perl extension"
            exit 1
        fi
    fi
    
    # Verify configuration files exist
    local project_root="$(dirname "$(dirname "$(realpath "$0")")")"
    
    if [ -f "$project_root/.vscode/settings.json" ]; then
        print_success "VS Code settings configured"
    else
        print_warning "VS Code settings not found - run the main setup script first"
    fi
    
    if [ -f "$project_root/docker/perl-lsp.yml" ]; then
        print_success "Docker LSP configuration found"
    else
        print_warning "Docker LSP configuration not found - run the main setup script first"
    fi
    
    # Show final instructions
    show_instructions
}

# Run main function
main "$@"
