import pytest

from countries.hr.main import generate_file_identifier

# tests for generate_file_identifier function

@pytest.mark.parametrize(
    "keyword, last_filename, expected",
    [
        ("svi odobreni objekti", None, "svi_odobreni_objekti"),
        ("keyword/with\\chars", None, "keyword_with_chars"),
        (None, "03-11-2025. svi odobreni objekti.xls", "03_11_2025__svi_odobreni_objek"),
        (None, None, "unknown"),
    ]
)
def test_generate_file_identifier(keyword, last_filename, expected):
    assert generate_file_identifier(keyword, last_filename) == expected
