import pytest
from common.check_coordinates import (haversine_km, find_column, parse_coordinates,
                                      check_rows, read_packager_file)


def make_row(code, postalcode, lat, lng):
    return {'code': code, 'postalcode': postalcode, 'lat': lat, 'lng': lng}


def run(rows, **kwargs):
    return check_rows(rows, 'code', 'lat', 'lng', **kwargs)


# tests for haversine_km function

def test_haversine_km_same_point():
    assert haversine_km(48.85, 2.35, 48.85, 2.35) == 0


def test_haversine_km_paris_lyon():
    # Paris - Lyon is about 392 km
    assert haversine_km(48.8566, 2.3522, 45.7640, 4.8357) == pytest.approx(392, abs=5)


# tests for find_column function

def test_find_column_case_insensitive():
    assert find_column(['Code', 'Latitude', 'Longitude'], ('lat', 'latitude')) == 'Latitude'


def test_find_column_not_found():
    assert find_column(['code', 'name'], ('lat',)) is None


# tests for parse_coordinates function

@pytest.mark.parametrize("lat, lng, expected", [
    ("45.5", "5.25", (45.5, 5.25, None)),
    ("45,5", "5,25", (45.5, 5.25, None)),
    ("", "5.25", (None, None, 'missing_coordinates')),
    (None, None, (None, None, 'missing_coordinates')),
    ("abc", "5.25", (None, None, 'invalid_coordinates')),
    ("95", "5.25", (None, None, 'invalid_coordinates')),
    ("45", "200", (None, None, 'invalid_coordinates')),
    ("nan", "5", (None, None, 'invalid_coordinates')),
    ("0", "0", (None, None, 'null_island')),
])
def test_parse_coordinates(lat, lng, expected):
    assert parse_coordinates(lat, lng) == expected


# tests for check_rows function

def test_check_rows_far_from_group():
    rows = [
        make_row('A', '01500', '45.96', '5.34'),
        make_row('B', '01500', '45.97', '5.35'),
        make_row('C', '01500', '45.95', '5.33'),
        # namesake in the USA
        make_row('D', '01500', '42.37', '-71.80'),
    ]
    issues = run(rows, group_col='postalcode')
    assert len(issues) == 1
    issue = issues[0]
    assert issue['code'] == 'D'
    assert issue['line'] == 5
    assert issue['reason'] == 'far_from_group'
    assert issue['group'] == '01500'
    assert issue['group_size'] == 4
    assert issue['distance_km'] > 5000


def test_check_rows_no_issue():
    rows = [make_row(c, '01500', '45.96', '5.34') for c in 'ABC']
    assert run(rows, group_col='postalcode') == []


def test_check_rows_small_group_skipped():
    rows = [
        make_row('A', '01500', '45.96', '5.34'),
        make_row('B', '01500', '42.37', '-71.80'),
    ]
    assert run(rows, group_col='postalcode') == []
    assert len(run(rows, group_col='postalcode', min_group_size=2)) == 2


def test_check_rows_group_prefix():
    rows = [
        make_row('A', '01500', '45.96', '5.34'),
        make_row('B', '01200', '46.12', '5.80'),
        make_row('C', '01000', '46.20', '5.22'),
        make_row('D', '01100', '51.00', '10.00'),
    ]
    # each postal code alone is too small to be checked
    assert run(rows, group_col='postalcode') == []
    issues = run(rows, group_col='postalcode', group_prefix=2)
    assert [issue['code'] for issue in issues] == ['D']
    assert issues[0]['group'] == '01'


def test_check_rows_max_distance():
    rows = [
        make_row('A', '01500', '45.96', '5.34'),
        make_row('B', '01500', '45.97', '5.35'),
        make_row('C', '01500', '46.50', '5.34'),  # about 60 km north
    ]
    assert run(rows, group_col='postalcode') == []
    assert [issue['code'] for issue in run(rows, group_col='postalcode', max_distance_km=50)] == ['C']


def test_check_rows_invalid_and_missing():
    rows = [
        make_row('A', '01500', '0', '0'),
        make_row('B', '01500', 'x', '5'),
        make_row('C', '01500', '', ''),
    ]
    assert [(i['code'], i['reason']) for i in run(rows)] == [
        ('A', 'null_island'), ('B', 'invalid_coordinates')]
    assert [i['reason'] for i in run(rows, report_missing=True)] == [
        'null_island', 'invalid_coordinates', 'missing_coordinates']


def test_check_rows_without_group():
    rows = [make_row('A', '01500', '45.96', '5.34'), make_row('B', '01500', '42.37', '-71.80')]
    assert run(rows) == []


# tests for read_packager_file function

def test_read_packager_file_semicolon(tmp_path):
    path = tmp_path / "XX-merge-UTF-8.csv"
    path.write_text("code;name;lat;lng\nXX 1 EC;Foo;45.1;5.2\n", encoding="utf-8")
    header, rows = read_packager_file(str(path))
    assert header == ['code', 'name', 'lat', 'lng']
    assert rows == [{'code': 'XX 1 EC', 'name': 'Foo', 'lat': '45.1', 'lng': '5.2'}]


def test_read_packager_file_tab(tmp_path):
    path = tmp_path / "XX-merge-UTF-8.tsv"
    path.write_text("code\tname; with semicolon\tlat\tlng\nXX 1\tFoo\t45.1\t5.2\n", encoding="utf-8")
    header, rows = read_packager_file(str(path))
    assert header == ['code', 'name; with semicolon', 'lat', 'lng']
    assert rows[0]['lat'] == '45.1'
