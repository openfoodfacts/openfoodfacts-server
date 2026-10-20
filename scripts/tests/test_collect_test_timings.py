"""Exercise the untrusted-artifact boundary and per-profile median merge."""

import io
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from dynamic_test_grouper import DynamicTestGrouper


class TestCollectTestTimings(unittest.TestCase):
    def collector(self):
        path = Path(__file__).resolve().parents[1] / 'collect_test_timings.py'
        self.assertTrue(path.exists(), 'weekly collector must consume PR timing artifacts')
        import collect_test_timings
        return collect_test_timings

    def archive(self, files):
        buffer = io.BytesIO()
        with zipfile.ZipFile(buffer, 'w') as archive:
            for path, content in files.items():
                archive.writestr(path, content)
        return buffer.getvalue()

    def test_zip_is_read_as_data_with_no_path_extraction(self):
        collector = self.collector()
        data = self.archive({'../../outside.xml': '<testsuite name="tests_unit_file_t" time="12"/>',
                             'untrusted.py': 'raise RuntimeError("never executed")'})
        self.assertEqual(collector.read_artifact_timings(data, ['tests/unit/file.t']), {'tests/unit/file.t': 12})
        self.assertEqual(collector.read_artifact_timings(b'not zip', ['tests/unit/file.t']), {})
        data = self.archive({'junit.xml': '<not xml'})
        self.assertEqual(collector.read_artifact_timings(data, ['tests/unit/file.t']), {})

    def test_unknown_xml_encoding_does_not_abort_the_collector(self):
        collector = self.collector()
        data = self.archive({'junit.xml': '<?xml version="1.0" encoding="unknown-encoding"?>'
                             '<testsuite name="tests_unit_file_t" time="12"/>'})
        self.assertEqual(collector.read_artifact_timings(data, ['tests/unit/file.t']), {})

    def test_merge_preserves_other_profiles_and_uses_median_for_all_shards(self):
        collector = self.collector()
        cwd = Path.cwd()
        with tempfile.TemporaryDirectory() as temp:
            try:
                os.chdir(temp)
                Path('tests/unit').mkdir(parents=True)
                Path('tests/unit/a.t').touch()
                Path('tests/unit/b.t').touch()
                covered = DynamicTestGrouper('unit', profile='coverage')
                plain = DynamicTestGrouper('unit', profile='no-coverage')
                covered._save_cache(covered.timing_file, {'tests/unit/a.t': 1, 'tests/unit/deleted.t': 99})
                plain._save_cache(plain.timing_file, {'tests/unit/a.t': 2})
                collector.merge_samples('coverage', 'unit', {
                    'tests/unit/a.t': [10, 14, 1000],
                    'tests/unit/b.t': [20],
                    'tests/unit/unknown.t': [100],
                })
                self.assertEqual(covered.load_timings(), {'tests/unit/a.t': 14, 'tests/unit/b.t': 20})
                self.assertEqual(plain.load_timings(), {'tests/unit/a.t': 2})
                self.assertNotIn('tests/unit/deleted.t', json.loads(covered.timing_file.read_text()))
            finally:
                os.chdir(cwd)

    def test_rerun_selects_latest_available_artifact_per_shard(self):
        collector = self.collector()
        artifacts = [
            {'id': 1, 'name': 'test-timings-v2-coverage-unit-1-attempt-1', 'expired': False},
            {'id': 2, 'name': 'test-timings-v2-coverage-unit-2-attempt-1', 'expired': False},
            {'id': 3, 'name': 'test-timings-v2-coverage-unit-1-attempt-2', 'expired': False},
            {'id': 4, 'name': 'test-timings-v2-no-coverage-unit-1-attempt-1', 'expired': False},
            {'id': 5, 'name': 'other-report', 'expired': False},
            {'id': 6, 'name': 'test-timings-v2-coverage-unit-3-attempt-1', 'expired': True},
        ]
        selected = collector.select_artifacts(artifacts)
        self.assertEqual({artifact['id'] for _, _, artifact in selected}, {2, 3, 4})
