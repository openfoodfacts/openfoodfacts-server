#!/bin/bash

# Script to update test groups in CI based on new tests or timing changes
# This script should be run before test execution to ensure groups are up-to-date
# It uses dynamic_test_grouper.py to generate test groups, generating
# .test_groups_cache/${test_type}_groups.json and ".test_groups_cache/${test_type}_groups.mk

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

echo "🥫 Checking and updating dynamic test groups..."

# Check if Python 3 is available
if ! command -v python3 >/dev/null 2>&1; then
    echo "Error: Python 3 is required but not found"
    exit 1
fi

echo "🐍 Python version: $(python3 --version)"

# Create cache directory if it doesn't exist
mkdir -p .test_groups_cache

# Function to check if test groups need regeneration
# Param $1: the type of test: unit or integration
# Exit with code 1 if tests needs to be regenerated
check_test_groups_validity() {
    local test_type="$1"
    
    echo "Checking $test_type test groups validity..."
    
    # Check if cache exists
    if [ ! -f ".test_groups_cache/${test_type}_groups.json" ]; then
        echo "Cache not found for $test_type tests, generating..."
        return 1
    fi
    
    # Check if any new test files exist since last cache
    local current_test_files
    current_test_files=$(find "tests/$test_type" -name "*.t" -type f 2>/dev/null | sort || echo "")
    
    # Get the list of tests contained in cached files
    local cached_test_files=""
    if [ -f ".test_groups_cache/${test_type}_groups.json" ]; then
        cached_test_files=$(python3 -c "
import json
import sys
try:
    with open('.test_groups_cache/${test_type}_groups.json', 'r') as f:
        data = json.load(f)
    tests = []
    for group in data:
        if 'tests' in group:
            tests.extend(group['tests'])
    for test in sorted(tests):
        print(test)
except:
    pass
        " 2>/dev/null || echo "")
    fi
    
    # Compare test lists
    if [ "$current_test_files" != "$cached_test_files" ]; then
        echo "Test files changed for $test_type tests, regenerating..."
        echo "Current tests: $(echo "$current_test_files" | wc -l) files"
        echo "Cached tests: $(echo "$cached_test_files" | wc -l) files"
        return 1
    fi
    
    return 0
}

# Function to generate test groups
generate_test_groups() {
    local test_type="$1"
    
    echo "🥫 Generating $test_type test groups (auto-calculated count)..."
    
    # Use force flag if cache is invalid or doesn't exist
    local force_flag=""
    if ! check_test_groups_validity "$test_type"; then
        force_flag="--force"
    fi
    
    # Generate groups using the Python script with auto-calculation
    if python3 scripts/dynamic_test_grouper.py --type="$test_type" $force_flag > ".test_groups_cache/${test_type}_groups.mk.tmp"; then
        mv ".test_groups_cache/${test_type}_groups.mk.tmp" ".test_groups_cache/${test_type}_groups.mk"
        echo "Test groups for $test_type generated successfully"
    else
        echo "Failed to generate $test_type test groups"
        rm -f ".test_groups_cache/${test_type}_groups.mk.tmp"
        return 1
    fi
}

# Update unit test groups if needed
if ! check_test_groups_validity "unit"; then
    generate_test_groups "unit"
else
    echo "Unit test groups are up to date"
fi

# Update integration test groups if needed
if ! check_test_groups_validity "integration"; then
    generate_test_groups "integration"
else
    echo "Integration test groups are up to date"
fi

# Print group statistics if requested
if [ "$1" = "--stats" ]; then
    echo ""
    echo "Current test group statistics:"
    echo ""
    
    if [ -f ".test_groups_cache/unit_timings.json" ]; then
        echo "Unit tests (auto-calculated groups):"
        python3 scripts/dynamic_test_grouper.py --type=unit 2>&1 | grep "^# Group" | head -8
        echo ""
    else
        echo "Unit tests: No timing data available yet"
        echo ""
    fi
    
    if [ -f ".test_groups_cache/integration_timings.json" ]; then
        echo "Integration tests (auto-calculated groups):"
        python3 scripts/dynamic_test_grouper.py --type=integration 2>&1 | grep "^# Group" | head -11
        echo ""
    else
        echo "Integration tests: No timing data available yet"
        echo ""
    fi
    
    echo "Groups will improve automatically as timing data is collected from CI runs"
fi

# Validate generated Makefile syntax
if [ -f ".test_groups_cache/unit_groups.mk" ]; then
    if ! grep -q "GROUP_1_TESTS" ".test_groups_cache/unit_groups.mk"; then
        echo "Warning: Unit test groups Makefile seems invalid, regenerating..."
        generate_test_groups "unit" || echo "Failed to regenerate unit groups"
    fi
fi

if [ -f ".test_groups_cache/integration_groups.mk" ]; then
    if ! grep -q "GROUP_1_TESTS" ".test_groups_cache/integration_groups.mk"; then
        echo "Warning: Integration test groups Makefile seems invalid, regenerating..."
        generate_test_groups "integration" || echo "Failed to regenerate integration groups"
    fi
fi

echo "🥫 Test group update completed successfully"