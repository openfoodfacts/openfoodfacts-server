from countries.dk.transform import is_valid_approval_code_denmark, extract_address_components_denmark
import pytest

# tests for is_valid_approval_code_denmark function

@pytest.mark.parametrize(
    "code,expected",
    [
        ("123", True),  # Pure number
        ("456-A", True),  # Number with suffix
        ("M123", True),  # Alphanumeric
        ("DK4772", True),  # With DK prefix (will be stripped)
        ("2", True),  # Single digit
        ("", False),  # Empty
        ("Name", False),  # Header keyword
    ]
)
def test_is_valid_approval_code_denmark(code, expected):
    assert is_valid_approval_code_denmark(code) == expected


# tests for extract_address_components_denmark

@pytest.mark.parametrize(
    "address,expected",
    [
        ("Lilledybet 6, 9220 Aalborg Øst", ("Lilledybet 6", "9220", "Aalborg Øst")),
        ("Sleipnersvej 1, 4600 Køge", ("Sleipnersvej 1", "4600", "Køge")),
        ("Main Street, 1234 Copenhagen", ("Main Street", "1234", "Copenhagen")),
        ("Street, City, 5000 Town", ("Street, City", "5000", "Town")),
    ]
)
def test_extract_address_components_denmark(address, expected):
    assert extract_address_components_denmark(address) == expected
