import pytest
import tempfile
import os

from common.transform import (
    is_valid_approval_code,
    format_approval_code,
    extract_address,
    extract_address_street_postalcode_city,
    extract_address_city_and_postalcode,
    preprocess_csv
)


# tests for is_valid_approval_code function

@pytest.mark.parametrize(
    "code,header_keywords,expected",
    [
        ("123", ["Name"], True),  # Pure number
        ("456-A", ["Name"], True),  # Number with suffix
        ("M123", ["Name"], True),  # Alphanumeric
        ("DK4772", ["Name"], True),  # With country prefix
        ("2", ["Name"], True),  # Single digit
        ("", ["Name"], False),  # Empty
        ("Name", ["Name"], False),  # Header keyword exact match
        ("name", ["Name"], False),  # Header keyword case insensitive
        ("No", ["No", "Br"], False),  # Header keyword
        ("ABC", ["Name"], False),  # No digits
        (" 2 ", ["Name"], True),  # Digit with spaces
        ("FI 123 EC", ["Name"], True),  # Formatted code
    ]
)
def test_is_valid_approval_code(code, header_keywords, expected):
    # Convert header keywords to lowercase for comparison
    header_keywords_lower = [k.lower() for k in header_keywords]
    assert is_valid_approval_code(code, header_keywords_lower) == expected


# tests for format_approval_code function

@pytest.mark.parametrize(
    "raw_code,country_code,code_config,expected",
    [
        ("123", "fi", {"suffix": "EC"}, "FI 123 EC"),
        ("DK4772", "dk", {"strip_prefix": "DK", "suffix": "EF"}, "DK 4772 EF"),
        ("456-A", "hr", {"suffix": "EU"}, "HR 456-A EU"),
        ("789", "fi", {}, "FI 789 EC"),  # Default suffix
    ]
)
def test_format_approval_code(raw_code, country_code, code_config, expected):
    assert format_approval_code(raw_code, country_code, code_config) == expected


# tests for extract_address function (default - separate columns)

def test_extract_address():
    row = ["Street 123", "City Name", "12345"]
    columns = {"street": 0, "city": 1, "postalcode": 2}
    result = extract_address(row, columns)
    assert result == {"street": "Street 123", "city": "City Name", "postalcode": "12345"}


# tests for extract_address_street_postalcode_city

@pytest.mark.parametrize(
    "address,expected",
    [
        ("Lilledybet 6, 9220 Aalborg Øst", {"street": "Lilledybet 6", "postalcode": "9220", "city": "Aalborg Øst"}),
        ("Main Street, 1234 Copenhagen", {"street": "Main Street", "postalcode": "1234", "city": "Copenhagen"}),
        ("Street, City, 5000 Town", {"street": "Street, City", "postalcode": "5000", "city": "Town"}),
    ]
)
def test_extract_address_street_postalcode_city(address, expected):
    row = [address]
    columns = {"street_postalcode_city": 0}
    result = extract_address_street_postalcode_city(row, columns)
    assert result == expected


# tests for extract_address_city_and_postalcode

@pytest.mark.parametrize(
    "street,city_and_postalcode,expected",
    [
        ("Street 1", "Zagreb, 10000", {"street": "Street 1", "city": "Zagreb", "postalcode": "10000"}),
        ("Main St", "Region, Split, 21000", {"street": "Main St", "city": "Split", "postalcode": "21000"}),
        ("Avenue 5", "City without postal", {"street": "Avenue 5", "city": "City without postal", "postalcode": ""}),
        ("Road 7", "Some City, 21 217", {"street": "Road 7", "city": "Some City", "postalcode": "21217"}),
    ]
)
def test_extract_address_city_and_postalcode(street, city_and_postalcode, expected):
    row = [street, city_and_postalcode]
    columns = {"street": 0, "city_and_postalcode": 1}
    result = extract_address_city_and_postalcode(row, columns)
    assert result == expected


# tests for preprocess_csv function

def test_preprocess_csv_basic():
    """Test basic CSV preprocessing with separate address columns"""
    with tempfile.TemporaryDirectory() as tmpdir:
        input_csv = os.path.join(tmpdir, "input.csv")
        output_csv = os.path.join(tmpdir, "output.csv")
        
        # Create input CSV (comma-delimited)
        with open(input_csv, "w", encoding="utf-8", newline="") as f:
            f.write("Code,Name,Street,City,PostalCode\n")
            f.write("123,Company A,Main St,Helsinki,00100\n")
            f.write("456,Company B,Second Ave,Espoo,02100\n")
        
        # Config
        file_config = {
            "columns": {
                "code": 0,
                "name": 1,
                "street": 2,
                "city": 3,
                "postalcode": 4
            },
            "header_keywords": ["code", "name"],
            "code_format": {"suffix": "EC"},
            "normalize_fields": ["code", "name", "street", "city", "postalcode"]
        }
        
        # Process
        preprocess_csv("Finland", "fi", input_csv, output_csv, file_config)
        
        # Verify output
        with open(output_csv, "r", encoding="utf-8") as f:
            lines = [line.strip() for line in f.readlines()]
        
        assert lines == [
            "code;name;street;city;postalcode",
            "FI 123 EC;Company A;Main St;Helsinki;00100",
            "FI 456 EC;Company B;Second Ave;Espoo;02100"
        ]


def test_preprocess_csv_with_address_extractor():
    """Test CSV preprocessing with street_postalcode_city address extractor"""
    with tempfile.TemporaryDirectory() as tmpdir:
        input_csv = os.path.join(tmpdir, "input.csv")
        output_csv = os.path.join(tmpdir, "output.csv")
        
        # Create input CSV (comma-delimited)
        with open(input_csv, "w", encoding="utf-8", newline="") as f:
            f.write("Code,Name,Address\n")
            f.write("123,Company A,Main St; 00100 Helsinki\n")
            f.write("456,Company B,Second Ave; 02100 Espoo\n")
        
        # Config with address extractor
        file_config = {
            "columns": {
                "code": 0,
                "name": 1,
                "street_postalcode_city": 2
            },
            "header_keywords": ["code", "name"],
            "code_format": {"suffix": "EC"},
            "address_extractor": "street_postalcode_city",
            "normalize_fields": ["code", "name", "street", "city", "postalcode"]
        }
        
        # Process
        preprocess_csv("Finland", "fi", input_csv, output_csv, file_config)
        
        # Verify output
        with open(output_csv, "r", encoding="utf-8") as f:
            lines = [line.strip() for line in f.readlines()]
        
        assert lines == [
            "code;name;street;city;postalcode",
            "FI 123 EC;Company A;Main St;Helsinki;00100",
            "FI 456 EC;Company B;Second Ave;Espoo;02100"
        ]


def test_preprocess_csv_skips_invalid_codes():
    """Test that rows with invalid codes are skipped"""
    with tempfile.TemporaryDirectory() as tmpdir:
        input_csv = os.path.join(tmpdir, "input.csv")
        output_csv = os.path.join(tmpdir, "output.csv")
        
        # Create input CSV with invalid codes (comma-delimited)
        with open(input_csv, "w", encoding="utf-8", newline="") as f:
            f.write("Code,Name,Street,City,PostalCode\n")
            f.write("123,Company A,Main St,Helsinki,00100\n")
            f.write("Name,Invalid,Street,City,12345\n")  # Invalid - header keyword
            f.write(",Empty,Street,City,12345\n")  # Invalid - empty
            f.write("456,Company B,Second Ave,Espoo,02100\n")
        
        # Config
        file_config = {
            "columns": {
                "code": 0,
                "name": 1,
                "street": 2,
                "city": 3,
                "postalcode": 4
            },
            "header_keywords": ["code", "name"],
            "code_format": {"suffix": "EC"},
            "normalize_fields": ["code", "name", "street", "city", "postalcode"]
        }
        
        # Process
        preprocess_csv("Finland", "fi", input_csv, output_csv, file_config)
        
        # Verify output - only 2 valid rows
        with open(output_csv, "r", encoding="utf-8") as f:
            lines = [line.strip() for line in f.readlines()]
        
        assert lines == [
            "code;name;street;city;postalcode",
            "FI 123 EC;Company A;Main St;Helsinki;00100",
            "FI 456 EC;Company B;Second Ave;Espoo;02100"
        ]


def test_preprocess_csv_postal_code_formatting():
    """Test postal code zero-padding"""
    with tempfile.TemporaryDirectory() as tmpdir:
        input_csv = os.path.join(tmpdir, "input.csv")
        output_csv = os.path.join(tmpdir, "output.csv")
        
        # Create input CSV with short postal codes (comma-delimited)
        with open(input_csv, "w", encoding="utf-8", newline="") as f:
            f.write("Code,Name,Street,City,PostalCode\n")
            f.write("123,Company A,Main St,Helsinki,100\n")
            f.write("456,Company B,Second Ave,Espoo,'2100\n")  # Excel format with quote
        
        # Config with postal code formatting
        file_config = {
            "columns": {
                "code": 0,
                "name": 1,
                "street": 2,
                "city": 3,
                "postalcode": 4
            },
            "header_keywords": ["code", "name"],
            "code_format": {"suffix": "EC"},
            "normalize_fields": ["code", "name", "street", "city", "postalcode"],
            "postalcode_format": {"zfill": 5}
        }
        
        # Process
        preprocess_csv("Finland", "fi", input_csv, output_csv, file_config)
        
        # Verify output
        with open(output_csv, "r", encoding="utf-8") as f:
            lines = [line.strip() for line in f.readlines()]
        
        assert lines == [
            "code;name;street;city;postalcode",
            "FI 123 EC;Company A;Main St;Helsinki;00100",
            "FI 456 EC;Company B;Second Ave;Espoo;02100"
        ]
