#!/usr/bin/env python3
"""
Generate dynamic group configurations for GitHub Actions matrix strategy.
This script outputs JSON that can be used directly in GitHub Actions workflows.
"""

import json
import sys
from pathlib import Path

# Add the scripts directory to Python path
sys.path.insert(0, str(Path(__file__).parent))

from dynamic_test_grouper import DynamicTestGrouper

def generate_matrix_config():
    """Generate GitHub Actions matrix configuration."""
    
    # Create test groupers for auto-calculation
    unit_grouper = DynamicTestGrouper('unit', None, False)
    integration_grouper = DynamicTestGrouper('integration', None, False)
    
    # Discover tests and calculate optimal groups
    unit_test_files = unit_grouper._discover_test_files()
    unit_timings = unit_grouper._load_cache(unit_grouper.cache_dir / "unit_timings.json") or {}
    
    # Calculate without printing
    total_unit_time = sum(unit_grouper._get_test_time(test, unit_timings) for test in unit_test_files)
    unit_groups = max(1, int(total_unit_time / 780) + 1)  # 780 seconds = 13 minutes
    unit_groups = max(1, min(unit_groups, min(len(unit_test_files), 12)))
    
    integration_test_files = integration_grouper._discover_test_files()
    integration_timings = integration_grouper._load_cache(integration_grouper.cache_dir / "integration_timings.json") or {}
    
    total_integration_time = sum(integration_grouper._get_test_time(test, integration_timings) for test in integration_test_files)
    integration_groups = max(1, int(total_integration_time / 780) + 1)
    integration_groups = max(1, min(integration_groups, min(len(integration_test_files), 12)))
    
    # Print info to stderr so it doesn't interfere with JSON
    print(f"# Auto-calculated {unit_groups} unit test groups for {len(unit_test_files)} tests (total estimated time: {total_unit_time/60:.1f}m)", file=sys.stderr)
    print(f"# Auto-calculated {integration_groups} integration test groups for {len(integration_test_files)} tests (total estimated time: {total_integration_time/60:.1f}m)", file=sys.stderr)
    
    # Generate matrix configuration
    matrix_config = {
        "unit_groups": unit_groups,
        "integration_groups": integration_groups,
        "unit_group_range": list(range(1, unit_groups + 1)),
        "integration_group_range": list(range(1, integration_groups + 1))
    }
    
    return matrix_config

if __name__ == '__main__':
    config = generate_matrix_config()
    print(json.dumps(config, indent=2))