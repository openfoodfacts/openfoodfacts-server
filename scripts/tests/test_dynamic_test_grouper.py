"""Regression tests for Yath timings and the shared CI plan (stdlib only)."""

import contextlib
import io
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from dynamic_test_grouper import DynamicTestGrouper


class TestWorkspace(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.cwd = Path.cwd()
        os.chdir(self.temp.name)
        Path("tests/unit").mkdir(parents=True)
        Path("tests/integration").mkdir(parents=True)

    def tearDown(self):
        os.chdir(self.cwd)
        self.temp.cleanup()

    def add_test(self, name, test_type="unit"):
        path = Path("tests") / test_type / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.touch()
        return path.as_posix()


class TestDynamicTestGrouper(TestWorkspace):
    def test_yath_suite_duration_is_recorded_instead_of_assertion_duration(self):
        self.add_test("display.t")
        Path("results").mkdir()
        Path("results/junit.xml").write_bytes(
            (Path(__file__).parent / "fixtures/yath-junit.xml").read_bytes()
        )
        grouper = DynamicTestGrouper("unit")
        grouper.update_timings_from_junit("results")
        files = list(Path(".").rglob("*timings.json"))
        self.assertEqual(len(files), 1, "the real Yath suite should produce a timing")
        timings = json.loads(files[0].read_text())
        self.assertEqual(timings, {"tests/unit/display.t": 6.46810007095337})

    def test_duplicate_cached_tests_are_invalid_even_when_sets_match(self):
        file = self.add_test("one.t")
        grouper = DynamicTestGrouper("unit", 1)
        self.assertFalse(grouper._cache_is_valid([{"tests": [file, file]}], [file]))

    def test_small_test_sets_have_no_empty_groups(self):
        files = [self.add_test("one.t"), self.add_test("two.t")]
        grouper = DynamicTestGrouper("unit")
        self.assertEqual(grouper.calculate_optimal_group_count(files, {}), 2)



class TestPlansAndHistory(TestWorkspace):
    def generate(self, grouper):
        with contextlib.redirect_stdout(io.StringIO()):
            return grouper.generate_test_groups()

    def test_plan_reconciles_added_deleted_and_duplicate_cached_files(self):
        files = [self.add_test(f'file_{i}.t') for i in range(8)]
        grouper = DynamicTestGrouper('unit')
        grouper._save_cache(grouper.cache_dir / 'unit_groups.json', [
            {'tests': ['tests/unit/deleted.t', files[0], files[0]]}
        ])
        groups = self.generate(grouper)
        assigned = [test for group in groups for test in group['tests']]
        self.assertEqual(sorted(assigned), files)
        self.assertTrue(all(group['tests'] for group in groups))
        self.assertEqual(len(groups), 6)
        self.assertEqual(sum(group['total_time'] for group in groups), 8 * 30)

    def test_invalid_timing_files_fall_back_and_legacy_history_is_ignored(self):
        file = self.add_test('file.t')
        grouper = DynamicTestGrouper('unit')
        grouper._save_cache(grouper.cache_dir / 'unit_timings.json', {file: 123})
        for data in ('{broken', '[]', 'null', '{"tests/unit/file.t": "NaN"}',
                     '{"tests/unit/file.t": -1}', '{"tests/unit/file.t": true}',
                     '{"tests/unit/file.t": "Infinity"}'):
            grouper.timing_file.parent.mkdir(parents=True, exist_ok=True)
            grouper.timing_file.write_text(data)
            self.assertEqual(self.generate(DynamicTestGrouper('unit'))[0]['total_time'], 30)

    def test_profiles_do_not_mix_and_unknown_or_deleted_tests_are_discarded(self):
        file = self.add_test('file.t')
        covered = DynamicTestGrouper('unit', profile='coverage')
        covered._save_cache(covered.timing_file, {file: 123, 'tests/unit/deleted.t': 900})
        plain = DynamicTestGrouper('unit', profile='no-coverage')
        self.assertEqual(covered.load_timings(), {file: 123})
        self.assertEqual(self.generate(plain)[0]['total_time'], 30)

    def test_zero_duration_tests_still_fill_every_group(self):
        files = [self.add_test(f'file_{i}.t') for i in range(8)]
        grouper = DynamicTestGrouper('unit')
        grouper._save_cache(grouper.timing_file, dict.fromkeys(files, 0))
        self.assertTrue(all(group['tests'] for group in self.generate(grouper)))

    def test_empty_test_type_produces_an_empty_matrix(self):
        self.assertEqual(self.generate(DynamicTestGrouper('unit')), [])

    def test_matrix_and_makefiles_are_created_from_the_same_canonical_plan(self):
        from generate_matrix_config import generate_matrix_config
        unit_files = [self.add_test(f'unit_{i}.t') for i in range(8)]
        integration_files = [self.add_test(f'int_{i}.t', 'integration') for i in range(10)]
        with contextlib.redirect_stderr(io.StringIO()):
            matrix = generate_matrix_config()
        plan_path = Path('.test_groups_cache/plan.json')
        self.assertTrue(plan_path.exists(), 'coordinator must save the plan it used for the matrix')
        plan = json.loads(plan_path.read_text())
        for test_type, expected in [('unit', unit_files), ('integration', integration_files)]:
            groups = plan['groups'][test_type]
            self.assertEqual(matrix[f'{test_type}_group_range'], list(range(1, len(groups) + 1)))
            self.assertEqual(sorted(test for group in groups for test in group['tests']), expected)
            makefile = Path(f'.test_groups_cache/{test_type}_groups.mk').read_text()
            for number, group in enumerate(groups, 1):
                relative = ' '.join(file[len(f'tests/{test_type}/'):] for file in group['tests'])
                self.assertIn(f'{test_type.upper()}_GROUP_{number}_TESTS := {relative}\n', makefile)


class TestJUnitParsing(unittest.TestCase):
    def parse(self, xml, files):
        from dynamic_test_grouper import read_junit_timings
        return read_junit_timings(xml.encode(), files)

    def test_ambiguous_normalized_paths_are_skipped_and_hyphens_are_preserved(self):
        files = ['tests/unit/foo/bar.t', 'tests/unit/foo_bar.t', 'tests/unit/foo-bar.t']
        xml = '<testsuites><testsuite name="tests_unit_foo_bar_t" time="1"/>' \
              '<testsuite name="tests_unit_foo-bar_t" time="2"/></testsuites>'
        self.assertEqual(self.parse(xml, files), {files[2]: 2})

    def test_unknown_paths_failed_suites_and_invalid_durations_are_ignored(self):
        file = 'tests/unit/file.t'
        for duration in ('NaN', 'Infinity', '-1', 'garbage', '21601'):
            self.assertEqual(self.parse(f'<testsuite name="tests_unit_file_t" time="{duration}"/>', [file]), {})
        self.assertEqual(self.parse('<testsuite name="tests_unit_unknown_t" time="1"/>', [file]), {})
        self.assertEqual(self.parse('<testsuite name="tests_unit_file_t" time="1" failures="1"/>', [file]), {})
        self.assertEqual(self.parse('<testsuite name="tests_unit_file_t" time="1"><testcase><error/></testcase></testsuite>', [file]), {})
        self.assertEqual(self.parse('<invalid', [file]), {})
        self.assertEqual(self.parse('<!DOCTYPE x [<!ENTITY x "1">]><testsuite name="tests_unit_file_t" time="&x;"/>', [file]), {})


if __name__ == "__main__":
    unittest.main()
