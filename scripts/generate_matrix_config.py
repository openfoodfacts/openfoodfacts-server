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
    
    # Use the existing optimal group calculation methods
    unit_test_files = unit_grouper._discover_test_files()
    unit_timings = unit_grouper._load_cache(unit_grouper.cache_dir / "unit_timings.json") or {}
    
    # Temporarily redirect stdout to stderr for the calculation
    import contextlib
    with contextlib.redirect_stdout(sys.stderr):
        unit_groups = unit_grouper.calculate_optimal_group_count(unit_test_files, unit_timings)
    
    integration_test_files = integration_grouper._discover_test_files()
    integration_timings = integration_grouper._load_cache(integration_grouper.cache_dir / "integration_timings.json") or {}
    
    with contextlib.redirect_stdout(sys.stderr):
        integration_groups = integration_grouper.calculate_optimal_group_count(integration_test_files, integration_timings)
    
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