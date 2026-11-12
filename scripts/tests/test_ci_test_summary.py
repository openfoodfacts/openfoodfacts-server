"""Execute the real summary gate script across success and skipped states."""

import os
from pathlib import Path
import re
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = ROOT / '.github/workflows/pull_request.yml'
GATE = ROOT / '.github/scripts/check_test_jobs.sh'


class TestSummaryGate(unittest.TestCase):
    def test_required_jobs_cannot_be_failed_cancelled_or_unexpectedly_skipped(self):
        self.assertIn('run: bash .github/scripts/check_test_jobs.sh', WORKFLOW.read_text(),
                      'summary must run the gate script')
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
                result = subprocess.run(['bash', str(GATE)], env=dict(base, **changes),
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
