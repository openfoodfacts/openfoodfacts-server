#!/usr/bin/env python3
"""Merge recent successful PR-run JUnit artifacts into default-branch history.

Run only from trusted default-branch code. PR artifacts are parsed as bounded data
in memory; their files and code are never extracted or executed. The cache stores
separate coverage profiles, never cached group assignments.
"""

from collections import defaultdict
import io
import json
import os
import re
from statistics import median
import subprocess
import sys
import zipfile

from dynamic_test_grouper import (
    DynamicTestGrouper, MAX_JUNIT_BYTES, TIMING_PROFILES, read_junit_timings, valid_duration,
)

ARTIFACT_NAME = re.compile(
    r'test-timings-v2-(coverage|no-coverage)-(unit|integration)-([1-9][0-9]*)-attempt-([1-9][0-9]*)$'
)


def read_artifact_timings(data, test_files):
    if len(data) > MAX_JUNIT_BYTES:
        return {}
    try:
        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            entries = archive.infolist()
            if len(entries) > 100 or sum(entry.file_size for entry in entries) > MAX_JUNIT_BYTES:
                return {}
            timings = {}
            for entry in entries:
                if entry.filename.endswith('.xml') and not entry.is_dir():
                    timings.update(read_junit_timings(archive.read(entry), test_files))
            return timings
    except (zipfile.BadZipFile, OSError, RuntimeError, ValueError, NotImplementedError):
        return {}


def select_artifacts(artifacts):
    """Partial reruns keep successful older shards; prefer each shard's latest attempt."""
    latest = {}
    for artifact in artifacts:
        match = ARTIFACT_NAME.fullmatch(artifact['name'])
        if artifact['expired'] or not match:
            continue
        profile, test_type, group, attempt = match.groups()
        key = (profile, test_type, group)
        if key not in latest or int(attempt) > latest[key][0]:
            latest[key] = (int(attempt), artifact)
    return [(profile, test_type, artifact)
            for (profile, test_type, _), (_, artifact) in sorted(latest.items())]


def merge_samples(profile, test_type, samples):
    grouper = DynamicTestGrouper(test_type, profile=profile)
    timings = grouper.load_timings()
    known = set(grouper._discover_test_files())
    updates = {}
    for test, values in samples.items():
        valid = [duration for value in values if (duration := valid_duration(value)) is not None]
        if test in known and valid:
            updates[test] = median(valid)
    timings.update(updates)
    grouper._save_cache(grouper.timing_file, timings)
    print(f'{profile}/{test_type}: updated {len(updates)}, retained {len(timings)} test timings')
    return len(updates)


def github_api(path, binary=False):
    result = subprocess.run(['gh', 'api', path], check=True, capture_output=True)
    return result.stdout if binary else json.loads(result.stdout)


def main():
    repository = os.environ['GITHUB_REPOSITORY']
    # shortcut: a bounded ten-run window keeps the weekly download small; increase
    # if too few successful PR runs contain timing artifacts after rollout.
    runs = github_api(f'repos/{repository}/actions/workflows/pull_request.yml/runs'
                      '?event=pull_request&status=success&per_page=10')['workflow_runs']
    samples = {(profile, test_type): defaultdict(list)
               for profile in TIMING_PROFILES for test_type in ('unit', 'integration')}
    files = {test_type: DynamicTestGrouper(test_type)._discover_test_files()
             for test_type in ('unit', 'integration')}
    for run in runs:
        artifacts = github_api(f'repos/{repository}/actions/runs/{run["id"]}/artifacts?per_page=100')['artifacts']
        for profile, test_type, artifact in select_artifacts(artifacts):
            if artifact['size_in_bytes'] > MAX_JUNIT_BYTES:
                continue
            try:
                data = github_api(f'repos/{repository}/actions/artifacts/{artifact["id"]}/zip', binary=True)
            except subprocess.CalledProcessError:
                print(f'Warning: artifact {artifact["id"]} could not be downloaded', file=sys.stderr)
                continue
            for test, duration in read_artifact_timings(data, files[test_type]).items():
                samples[(profile, test_type)][test].append(duration)
    for (profile, test_type), values in samples.items():
        merge_samples(profile, test_type, values)


if __name__ == '__main__':
    main()
