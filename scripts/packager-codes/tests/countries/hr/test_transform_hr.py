from countries.hr.transform import is_valid_approval_code, extract_city_and_postal
import pytest

# tests for is_valid_approval_code function

@pytest.mark.parametrize(
    "code,expected",
    [
        ("123", True),
        ("456-A", True),
        ("", False),
        ("No", False),
        ("Br", False),
        ("App", False),
        ("A123", False),
        (" 2 ", True),
    ]
)
def test_is_valid_approval_code(code, expected):
    assert is_valid_approval_code(code) == expected


# tests for extract_city_and_postal

@pytest.mark.parametrize(
    "input_str,expected",
    [
        ("Zagreb, 10000", ("Zagreb", "10000")),
        ("Region, Split, 21000", ("Split", "21000")),
        ("City without postal", ("City without postal", "")),
        ("Some City, 21 217", ("Some City", "21217")),
        ("No digits here", ("No digits here", "")),
    ]
)
def test_extract_city_and_postal(input_str, expected):
    assert extract_city_and_postal(input_str) == expected
