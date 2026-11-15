#!/usr/bin/env python3
"""Create one canonical test plan, its Makefiles, and the CI matrix together."""

import contextlib
import io
import json
import sys

from dynamic_test_grouper import DynamicTestGrouper


def generate_matrix_config(profile=None):
    matrix = {}
    plan = {'version': 2, 'groups': {}}
    for test_type in ('unit', 'integration'):
        grouper = DynamicTestGrouper(test_type, profile=profile)
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            groups = grouper.generate_test_groups()
        (grouper.cache_dir / f'{test_type}_groups.mk').write_text(output.getvalue())
        print(output.getvalue(), file=sys.stderr, end='')
        plan['profile'] = grouper.profile
        plan['groups'][test_type] = groups
        matrix[f'{test_type}_groups'] = len(groups)
        matrix[f'{test_type}_group_range'] = list(range(1, len(groups) + 1))
    grouper._save_cache(grouper.cache_dir / 'plan.json', plan)
    return matrix


if __name__ == '__main__':
    print(json.dumps(generate_matrix_config(), indent=2))
