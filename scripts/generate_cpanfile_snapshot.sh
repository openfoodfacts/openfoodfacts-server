#!/usr/bin/env bash

# Script to generate cpanfile.snapshot for reproducible Perl builds
# This script builds a Docker image and extracts the generated snapshot

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🥫 Generating cpanfile.snapshot for reproducible Perl builds..."
echo "🥫 This may take 15-30 minutes depending on your system and network speed."
echo ""

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker is not installed or not in PATH" >&2
    exit 1
fi

# Change to repository root
cd "$REPO_ROOT"

# Clean up any existing snapshot to force regeneration
if [[ -f cpanfile.snapshot ]]; then
    echo "🥫 Backing up existing cpanfile.snapshot..."
    mv cpanfile.snapshot cpanfile.snapshot.backup
    echo "🥫 Backup saved as cpanfile.snapshot.backup"
fi

echo "🥫 Building Docker image (builder stage only)..."
echo "🥫 This will install all dependencies (including development deps)..."

# Build the builder stage without a snapshot
# This forces cpanm to be used, which will install all dependencies
if docker build --target builder --build-arg CPANMOPTS=--with-develop -t off-snapshot-builder . ; then
    echo ""
    echo "🥫 Build successful!"
    echo "🥫 Now generating the snapshot using Carton..."
    
    # Create a temporary container to run Carton and extract the snapshot
    # We need to use docker cp because carton install outputs logs to stdout
    # which would contaminate the snapshot file if we used stdout redirection
    CONTAINER_ID=$(docker create off-snapshot-builder bash -c "
        export PERL_CARTON_PATH=/tmp/local
        cd /tmp
        carton install
    ")
    
    echo "🥫 Running Carton to generate snapshot in container $CONTAINER_ID..."
    docker start -a "$CONTAINER_ID"
    
    echo "🥫 Extracting cpanfile.snapshot from container..."
    docker cp "$CONTAINER_ID:/tmp/cpanfile.snapshot" cpanfile.snapshot
    
    # Clean up the container
    docker rm "$CONTAINER_ID" > /dev/null 2>&1
    
    if [[ -f cpanfile.snapshot && -s cpanfile.snapshot ]]; then
        echo "🥫 Successfully generated cpanfile.snapshot!"
        echo "🥫 Snapshot size: $(du -h cpanfile.snapshot | cut -f1)"
        echo "🥫 Number of distributions: $(grep -c "^  " cpanfile.snapshot || echo "0")"
        echo ""
        echo "🥫 Next steps:"
        echo "   1. Review the generated cpanfile.snapshot"
        echo "   2. Test the build: make build"
        echo "   3. Run tests: make tests"
        echo "   4. Commit the snapshot: git add cpanfile.snapshot && git commit -m 'chore: update cpanfile.snapshot'"
        
        # Remove backup if generation was successful
        if [[ -f cpanfile.snapshot.backup ]]; then
            rm cpanfile.snapshot.backup
            echo "🥫 Removed backup file"
        fi
        
        # Clean up the temporary builder image
        docker rmi off-snapshot-builder &>/dev/null || true
        
        exit 0
    else
        echo "ERROR: cpanfile.snapshot was not created or is empty" >&2
        # Restore backup if it exists
        if [[ -f cpanfile.snapshot.backup ]]; then
            mv cpanfile.snapshot.backup cpanfile.snapshot
            echo "🥫 Restored backup snapshot"
        fi
        exit 1
    fi
else
    echo ""
    echo "ERROR: Docker build failed" >&2
    echo "🥫 Check the error messages above for details" >&2
    echo "🥫 Common issues:"
    echo "   - Network connectivity problems"
    echo "   - Insufficient disk space"
    echo "   - Dependency conflicts in cpanfile"
    
    # Restore backup if it exists
    if [[ -f cpanfile.snapshot.backup ]]; then
        mv cpanfile.snapshot.backup cpanfile.snapshot
        echo "🥫 Restored backup snapshot"
    fi
    
    exit 1
fi
