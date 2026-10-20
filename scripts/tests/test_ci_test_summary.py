"""Execute the workflow's real summary gate across success and skipped states."""

import os
from pathlib import Path
import re
import subprocess
import textwrap
import unittest

WORKFLOW = Path(__file__).resolve().parents[2] / '.github/workflows/pull_request.yml'


class TestSummaryGate(unittest.TestCase):
    def test_required_jobs_cannot_be_failed_cancelled_or_unexpectedly_skipped(self):
        workflow = WORKFLOW.read_text()
        marker = '      - name: Check required test jobs\n'
        self.assertIn(marker, workflow, 'summary must check the coordinator and required shards')
        section = workflow.split(marker, 1)[1]
        section = section.split('\n  tests_dev:', 1)[0]
        script = textwrap.dedent(section.split('        run: |\n', 1)[1])
        base = dict(os.environ, FILTER_RESULT='success', BUILD_RESULT='success',
                    CODE_MODIFIED='true', MATRIX_RESULT='success', UNIT_RESULT='success',
                    INTEGRATION_RESULT='success', EVENT_NAME='pull_request')
        cases = [({}, True),
                 ({'EVENT_NAME': 'push', 'INTEGRATION_RESULT': 'skipped'}, True),
                 ({'CODE_MODIFIED': 'false', 'MATRIX_RESULT': 'skipped',
                   'UNIT_RESULT': 'skipped', 'INTEGRATION_RESULT': 'skipped'}, True)]
        for key in ('FILTER_RESULT', 'BUILD_RESULT', 'MATRIX_RESULT', 'UNIT_RESULT', 'INTEGRATION_RESULT'):
            for status in ('failure', 'cancelled', 'skipped'):
                cases.append(({key: status}, False))
        cases.append(({'CODE_MODIFIED': ''}, False))
        for changes, expected in cases:
            with self.subTest(changes=changes):
                result = subprocess.run(['bash', '-c', script], env=dict(base, **changes),
                                        capture_output=True, text=True)
                self.assertEqual(result.returncode == 0, expected, result.stdout + result.stderr)

    def test_failed_shard_rerun_can_download_the_original_coordinator_plan(self):
        workflow = WORKFLOW.read_text()
        upload = workflow.split('- name: Share the exact test plan with every shard', 1)[1].split('\n  unit_tests:', 1)[0]
        upload_name = re.search(r'^        name: (.+)$', upload, re.M).group(1)
        downloads = re.findall(r"- name: Download the coordinator's shared test plan\n.*?^        name: ([^\n]+)$", workflow, re.M | re.S)
        self.assertEqual(len(downloads), 2)
        for download_name in downloads:
            # GitHub leaves a successful matrix job untouched on a failed-jobs rerun.
            first_attempt = upload_name.replace('${{ github.run_attempt }}', '1')
            second_attempt = download_name.replace('${{ github.run_attempt }}', '2')
            self.assertEqual(first_attempt, second_attempt)
        self.assertIn('overwrite: true', upload)
