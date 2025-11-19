#!/usr/bin/env python3
"""
Dynamic test grouping for parallel CI execution

This script dynamically groups tests using a greedy algorithm to balance execution time
across multiple groups for optimal parallel CI performance. It aims to keep group
execution time under 10-13 minutes.

Features:
- Dynamic test discovery
- Greedy bin-packing algorithm for load balancing
- Persistent caching of test groups and timings
- Automatic regrouping when new tests are added
- Historical timing data collection

Usage:
    # Generate test groups for unit tests
    python scripts/dynamic_test_grouper.py --type=unit --groups=6

    # Generate test groups for integration tests  
    python scripts/dynamic_test_grouper.py --type=integration --groups=9

    # Force regeneration of groups (ignore cache)
    python scripts/dynamic_test_grouper.py --type=unit --groups=6 --force

    # Update timing data after test execution
    python scripts/dynamic_test_grouper.py --type=unit --update-timings --junit-dir=tests/unit/outputs
"""

import argparse
import json
import os
import sys
import time
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Dict, List, Optional, Any

# Configuration
CACHE_DIR = '.test_groups_cache'
MAX_GROUP_TIME = 13 * 60  # 13 minutes in seconds
DEFAULT_TEST_TIME = 30    # Default time for new tests (30 seconds)


class TestGroup:
    """Represents a group of tests with their total execution time."""
    
    def __init__(self):
        self.tests: List[str] = []
        self.total_time: float = 0.0


class DynamicTestGrouper:
    """Main class for dynamic test grouping functionality."""
    
    def __init__(self, test_type: str, num_groups: Optional[int] = None, force: bool = False):
        self.test_type = test_type
        self.num_groups = num_groups  # None means auto-calculate
        self.force = force
        self.cache_dir = Path(CACHE_DIR)
        self.cache_dir.mkdir(exist_ok=True)
    
    def calculate_optimal_group_count(self, test_files: List[str], 
                                     timings: Dict[str, float]) -> int:
        """Calculate optimal number of groups based on total execution time."""
        if not test_files:
            return 1
        
        # Calculate total estimated time
        total_time = sum(self._get_test_time(test, timings) for test in test_files)
        
        # Calculate optimal group count to keep each group under MAX_GROUP_TIME
        optimal_groups = max(1, int(total_time / MAX_GROUP_TIME) + 1)
        
        # Apply reasonable bounds with test type-specific minimums
        if self.test_type == 'unit':
            min_groups = 6  # Minimum 6 groups for unit tests
        elif self.test_type == 'integration':
            min_groups = 9  # Minimum 9 groups for integration tests
        else:
            min_groups = 1  # Default minimum
        
        max_groups = min(len(test_files), 12)  # Don't exceed test count or 12 groups
        
        optimal_groups = max(min_groups, min(optimal_groups, max_groups))
        
        # as this files are in git
        # round estimated time to minutes to avoid too many conflicts between branches
        print(f"# Auto-calculated {optimal_groups} groups for {len(test_files)} tests "
              f"(total estimated time: {total_time/60:.0f}m)")
        
        return optimal_groups
    
    def generate_test_groups(self) -> None:
        """Generate test groups using greedy algorithm with caching."""
        cache_file = self.cache_dir / f"{self.test_type}_groups.json"
        timing_file = self.cache_dir / f"{self.test_type}_timings.json"
        
        # Discover all test files
        test_files = self._discover_test_files()
        
        # Load existing cache and timings
        cached_groups = self._load_cache(cache_file)
        test_timings = self._load_cache(timing_file) or {}
        
        # Auto-calculate optimal group count if not specified
        if self.num_groups is None:
            self.num_groups = self.calculate_optimal_group_count(test_files, test_timings)
        
        # Check if we need to regenerate groups
        if (not self.force and cached_groups and 
            self._cache_is_valid(cached_groups, test_files)):
            self._print_groups(cached_groups)
            return
        
        # Generate new groups using greedy algorithm
        groups = self._generate_groups_greedy(test_files, test_timings)
        
        # Cache the results
        self._save_cache(cache_file, self._groups_to_dict(groups))
        
        self._print_groups(self._groups_to_dict(groups))
        self._print_group_statistics(groups, test_timings)
    
    def update_timings_from_junit(self, junit_dir: str) -> None:
        """Update timing data from JUnit XML files."""
        junit_path = Path(junit_dir) if junit_dir else Path(f"tests/{self.test_type}/outputs")
        
        if not junit_path.exists():
            print(f"Warning: JUnit directory not found: {junit_path}")
            return
        
        timing_file = self.cache_dir / f"{self.test_type}_timings.json"
        test_timings = self._load_cache(timing_file) or {}
        
        # Find all JUnit XML files
        junit_files = list(junit_path.rglob("*.xml"))
        updated_count = 0
        
        for junit_file in junit_files:
            try:
                tree = ET.parse(junit_file)
                root = tree.getroot()
                
                # Extract test timings from XML
                for testcase in root.findall('.//testcase'):
                    name = testcase.get('name')
                    time_attr = testcase.get('time')
                    
                    # Convert test name to file path format
                    if name and time_attr and name.endswith('.t'):
                        try:
                            test_timings[name] = float(time_attr)
                            updated_count += 1
                        except ValueError:
                            continue
                            
            except ET.ParseError as e:
                print(f"Warning: Error parsing {junit_file}: {e}")
        
        # Save updated timings
        if updated_count > 0:
            self._save_cache(timing_file, test_timings)
        
        print(f"Updated timing data for {updated_count} tests")
    
    def _discover_test_files(self) -> List[str]:
        """Discover test files in the test directory."""
        test_dir = Path(f"tests/{self.test_type}")
        
        if not test_dir.exists():
            return []
        
        test_files = []
        for test_file in test_dir.rglob("*.t"):
            if test_file.is_file():
                # Use the full path from project root, not relative to test_dir
                full_path = str(test_file)
                test_files.append(full_path)
        
        return sorted(test_files)
    
    def _generate_groups_greedy(self, test_files: List[str], 
                               timings: Dict[str, float]) -> List[TestGroup]:
        """Generate test groups using greedy bin-packing algorithm."""
        # Ensure num_groups is set (should be set by generate_test_groups)
        if self.num_groups is None:
            self.num_groups = self.calculate_optimal_group_count(test_files, timings)
        
        # Initialize groups
        groups = [TestGroup() for _ in range(self.num_groups)]
        
        # Sort tests by estimated time (descending) for better load balancing
        sorted_tests = sorted(test_files, 
                            key=lambda test: self._get_test_time(test, timings),
                            reverse=True)
        
        # Greedy bin-packing: assign each test to the group with least total time
        for test in sorted_tests:
            test_time = self._get_test_time(test, timings)
            
            # Find group with minimum total time
            min_group = min(groups, key=lambda g: g.total_time)
            
            # Assign test to the group with minimum time
            min_group.tests.append(test)
            min_group.total_time += test_time
        
        return groups
    
    def _get_test_time(self, test: str, timings: Dict[str, float]) -> float:
        """Get estimated execution time for a test."""
        return timings.get(test, DEFAULT_TEST_TIME)
    
    def _cache_is_valid(self, cached_groups: List[Dict], 
                       current_tests: List[str]) -> bool:
        """Check if cached groups are still valid."""
        # If using auto-calculation, always regenerate for now
        # (In future, we could cache the optimal group count too)
        if self.num_groups is None:
            return False
        
        # Check if number of groups matches
        if len(cached_groups) != self.num_groups:
            return False
        
        # Get all tests from cache
        cached_tests = set()
        for group in cached_groups:
            cached_tests.update(group.get('tests', []))
        
        # Check if test sets match
        current_test_set = set(current_tests)
        
        return cached_tests == current_test_set
    
    def _load_cache(self, cache_file: Path) -> Optional[Any]:
        """Load data from cache file."""
        if not cache_file.exists():
            return None
        
        try:
            with cache_file.open('r') as f:
                return json.load(f)
        except (json.JSONDecodeError, IOError):
            return None
    
    def _save_cache(self, cache_file: Path, data: Any) -> None:
        """Save data to cache file."""
        try:
            with cache_file.open('w') as f:
                json.dump(data, f, indent=2)
        except IOError as e:
            print(f"Warning: Cannot write to {cache_file}: {e}")
    
    def _groups_to_dict(self, groups: List[TestGroup]) -> List[Dict]:
        """Convert TestGroup objects to dictionary format for caching."""
        return [
            {
                'tests': group.tests,
                'total_time': group.total_time
            }
            for group in groups
        ]
    
    def _print_groups(self, groups: List[Dict]) -> None:
        """Print test groups in Makefile variable format."""
        print(f"# Generated test groups for {self.test_type} tests")
        # don't print this as it makes much conflicts between branches
        # print(f"# Generated at: {time.ctime()}\n")
        
        # Use test-type-specific variable names to avoid conflicts
        var_prefix = f"{self.test_type.upper()}_GROUP"
        
        for i, group in enumerate(groups, 1):
            tests = group.get('tests', [])
            # Strip the test type prefix from paths since Makefile adds it
            test_prefix = f"tests/{self.test_type}/"
            relative_tests = []
            for test in tests:
                if test.startswith(test_prefix):
                    relative_tests.append(test[len(test_prefix):])
                else:
                    relative_tests.append(test)
            print(f"{var_prefix}_{i}_TESTS := {' '.join(relative_tests)}")
    
    def _print_group_statistics(self, groups: List[TestGroup], 
                               timings: Dict[str, float]) -> None:
        """Print statistics about the generated groups."""
        print("\n# Group Statistics:")
        
        group_times = []
        for i, group in enumerate(groups, 1):
            total_time = sum(self._get_test_time(test, timings) for test in group.tests)
            test_count = len(group.tests)
            
            group_times.append(total_time)
            minutes = int(total_time // 60)
            seconds = int(total_time % 60)
            
            print(f"# Group {i}: {test_count} tests, {minutes}m {seconds}s")
        
        if group_times:
            max_time = max(group_times)
            min_time = min(group_times)
            avg_time = sum(group_times) / len(group_times)
            
            print(f"# Max group time: {max_time/60:.0f}m, "
                  f"Min: {min_time/60:.0f}m, "
                  f"Avg: {avg_time/60:.0f}m")
            
            if max_time > MAX_GROUP_TIME:
                print(f"# WARNING: Max group time exceeds target of "
                      f"{MAX_GROUP_TIME/60} minutes")
                print("# Consider increasing the number of groups")


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Dynamic test grouping for parallel CI execution",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --type=unit                              # Auto-calculate optimal groups
  %(prog)s --type=unit --groups=6                   # Use exactly 6 groups
  %(prog)s --type=integration --auto                # Auto-calculate integration groups
  %(prog)s --type=unit --update-timings --junit-dir=tests/unit/outputs
        """
    )
    
    parser.add_argument('--type', choices=['unit', 'integration'], 
                       default='unit',
                       help='Test type: unit or integration (default: unit)')
    parser.add_argument('--groups', type=int, 
                       help='Number of groups to create (default: auto-calculate)')
    parser.add_argument('--auto', action='store_true',
                       help='Auto-calculate optimal number of groups (default behavior)')
    parser.add_argument('--force', action='store_true',
                       help='Force regeneration, ignore cache')
    parser.add_argument('--update-timings', action='store_true',
                       help='Update timing data from JUnit XML files')
    parser.add_argument('--junit-dir', 
                       help='Directory containing JUnit XML files')
    
    args = parser.parse_args()
    
    # Validate inputs
    if args.groups is not None and args.groups <= 0:
        print("Error: Number of groups must be positive", file=sys.stderr)
        sys.exit(1)
    
    # Create grouper instance (None means auto-calculate)
    grouper = DynamicTestGrouper(args.type, args.groups, args.force)
    
    # Execute main functionality
    if args.update_timings:
        junit_dir = args.junit_dir or f"tests/{args.type}/outputs"
        grouper.update_timings_from_junit(junit_dir)
    else:
        grouper.generate_test_groups()


if __name__ == '__main__':
    main()