#!/usr/bin/env python3
"""Balance discovered test files using Yath suite durations and greedy bin packing.

CI restores timings into .test_timing_history/v2, creates a plan once in the matrix
job, and shares its Makefiles with every shard. Legacy checked-in group files and
unversioned timings are never used as timing history.
"""

import argparse
from collections import defaultdict
import json
import math
import os
from pathlib import Path
import re
import xml.etree.ElementTree as ET

CACHE_DIR = '.test_groups_cache'
TIMING_DIR = '.test_timing_history/v2'
TIMING_PROFILES = ('coverage', 'no-coverage')
MAX_GROUP_TIME = 13 * 60
DEFAULT_TEST_TIME = 30
MAX_JUNIT_BYTES = 20 * 1024 * 1024


def valid_duration(value):
    """Reject corrupt/untrusted timing values, including bool, NaN and infinity."""
    if isinstance(value, bool):
        return None
    try:
        duration = float(value)
    except (TypeError, ValueError, OverflowError):
        return None
    # GitHub-hosted jobs cannot run longer than six hours.
    return duration if math.isfinite(duration) and 0 <= duration <= 6 * 3600 else None


def read_junit_timings(xml_data, test_files):
    """Map Yath's suite names back to known files without guessing on collisions.

    Test2::Harness::Renderer::JUnit replaces runs of [^-:_A-Za-z0-9] with '_'.
    Assertion testcase times omit setup/teardown, so use the enclosing suite time.
    Artifacts are untrusted data: never extract paths or resolve XML entities.
    """
    if len(xml_data) > MAX_JUNIT_BYTES or b'<!DOCTYPE' in xml_data.upper():
        return {}
    names = defaultdict(list)
    for test in test_files:
        names[re.sub(r'[^-:_A-Za-z0-9]+', '_', test)].append(test)
    try:
        root = ET.fromstring(xml_data)
    except (ET.ParseError, LookupError):
        return {}
    timings = {}
    for suite in root.iter('testsuite'):
        matches = names.get(suite.get('name'), [])
        duration = valid_duration(suite.get('time'))
        if (len(matches) == 1 and duration is not None
                and suite.get('failures', '0') == '0'
                and suite.get('errors', '0') == '0'
                and suite.find('.//failure') is None
                and suite.find('.//error') is None):
            timings[matches[0]] = duration
    return timings


class TestGroup:
    def __init__(self):
        self.tests = []
        self.total_time = 0.0


class DynamicTestGrouper:
    def __init__(self, test_type, num_groups=None, force=False, profile=None):
        if test_type not in ('unit', 'integration'):
            raise ValueError('Unknown test type')
        self.test_type = test_type
        self.num_groups = num_groups
        self.force = force  # Retained for existing local callers; plans are always fresh.
        self.profile = profile or os.environ.get('TEST_TIMING_PROFILE', 'coverage')
        if self.profile not in TIMING_PROFILES:
            raise ValueError('Unknown test timing profile')
        self.cache_dir = Path(CACHE_DIR)
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        self.timing_file = Path(TIMING_DIR) / self.profile / f'{test_type}_timings.json'

    def load_timings(self):
        data = self._load_cache(self.timing_file)
        if not isinstance(data, dict):
            return {}
        known_tests = set(self._discover_test_files())
        return {test: duration for test, value in data.items()
                if test in known_tests and (duration := valid_duration(value)) is not None}

    def calculate_optimal_group_count(self, test_files, timings):
        if not test_files:
            return 0
        total_time = sum(self._get_test_time(test, timings) for test in test_files)
        minimum = 6 if self.test_type == 'unit' else 9
        groups = min(len(test_files), 12, max(minimum, math.ceil(total_time / MAX_GROUP_TIME)))
        print(f'# Auto-calculated {groups} groups for {len(test_files)} tests '
              f'(total estimated time: {total_time / 60:.0f}m)')
        return groups

    def generate_test_groups(self):
        """Reconcile the current files and timings on every plan generation."""
        test_files = self._discover_test_files()
        timings = self.load_timings()
        if self.num_groups is None:
            self.num_groups = self.calculate_optimal_group_count(test_files, timings)
        else:
            self.num_groups = min(len(test_files), self.num_groups)
        groups = self._generate_groups_greedy(test_files, timings)
        data = self._groups_to_dict(groups)
        if not self._cache_is_valid(data, test_files):
            raise ValueError('Generated test plan has missing, duplicate or empty groups')
        self._save_cache(self.cache_dir / f'{self.test_type}_groups.json', data)
        self._print_groups(data)
        self._print_group_statistics(groups, timings)
        return data

    def update_timings_from_junit(self, junit_dir):
        timings = self.load_timings()
        samples = {}
        for junit_file in sorted(Path(junit_dir).rglob('*.xml')):
            if junit_file.stat().st_size <= MAX_JUNIT_BYTES:
                samples.update(read_junit_timings(junit_file.read_bytes(), self._discover_test_files()))
        timings.update(samples)
        if samples:
            self._save_cache(self.timing_file, timings)
        print(f'Updated timing data for {len(samples)} tests ({self.profile})')

    def _discover_test_files(self):
        return sorted(path.as_posix() for path in Path(f'tests/{self.test_type}').rglob('*.t')
                      if path.is_file())

    def _generate_groups_greedy(self, test_files, timings):
        if self.num_groups is None:
            self.num_groups = self.calculate_optimal_group_count(test_files, timings)
        groups = [TestGroup() for _ in range(self.num_groups)]
        for test in sorted(test_files, key=lambda file: self._get_test_time(file, timings), reverse=True):
            group = min(groups, key=lambda item: (item.total_time, len(item.tests)))
            group.tests.append(test)
            group.total_time += self._get_test_time(test, timings)
        return groups

    def _get_test_time(self, test, timings):
        duration = valid_duration(timings.get(test))
        return DEFAULT_TEST_TIME if duration is None else duration

    def _cache_is_valid(self, cached_groups, current_tests):
        if not isinstance(cached_groups, list) or len(cached_groups) != self.num_groups:
            return False
        if any(not isinstance(group, dict) or not isinstance(group.get('tests'), list)
               or not group['tests'] for group in cached_groups):
            return False
        files = [test for group in cached_groups for test in group['tests']]
        return sorted(files) == sorted(current_tests)

    def _load_cache(self, cache_file):
        try:
            return json.loads(cache_file.read_text())
        except (OSError, ValueError):
            return None

    def _save_cache(self, cache_file, data):
        cache_file.parent.mkdir(parents=True, exist_ok=True)
        cache_file.write_text(json.dumps(data, indent=2, sort_keys=True) + '\n')

    def _groups_to_dict(self, groups):
        return [{'tests': group.tests, 'total_time': group.total_time} for group in groups]

    def _print_groups(self, groups):
        print(f'# Generated test groups for {self.test_type} tests ({self.profile})')
        prefix = f'tests/{self.test_type}/'
        for number, group in enumerate(groups, 1):
            tests = ' '.join(test[len(prefix):] for test in group['tests'])
            print(f'{self.test_type.upper()}_GROUP_{number}_TESTS := {tests}')

    def _print_group_statistics(self, groups, timings):
        print('\n# Group Statistics:')
        for number, group in enumerate(groups, 1):
            print(f'# Group {number}: {len(group.tests)} tests, {group.total_time / 60:.1f}m')
        if groups and max(group.total_time for group in groups) > MAX_GROUP_TIME:
            print(f'# WARNING: Max group time exceeds target of {MAX_GROUP_TIME / 60:.0f} minutes')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--type', choices=['unit', 'integration'], default='unit')
    parser.add_argument('--groups', type=int)
    parser.add_argument('--auto', action='store_true', help='Auto-calculate group count (default)')
    parser.add_argument('--force', action='store_true', help='Accepted for existing local callers')
    parser.add_argument('--profile', choices=TIMING_PROFILES)
    parser.add_argument('--update-timings', action='store_true')
    parser.add_argument('--junit-dir')
    args = parser.parse_args()
    if args.groups is not None and args.groups <= 0:
        parser.error('Number of groups must be positive')
    grouper = DynamicTestGrouper(args.type, args.groups, args.force, args.profile)
    if args.update_timings:
        grouper.update_timings_from_junit(args.junit_dir or f'tests/{args.type}/outputs')
    else:
        grouper.generate_test_groups()


if __name__ == '__main__':
    main()
