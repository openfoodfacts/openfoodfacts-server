import pytest
from unittest.mock import MagicMock, patch

from common import geocode


@pytest.fixture
def fake_cache():
    """Simulate a cache dictionary for dbm."""
    return {}

# tests for simplify_query_params function

def test_simplify_query_params_comma_removal():
    """Test strategy 0: Remove text after comma in street"""
    params = {'street': 'Main St, Extra Info', 'city': 'Test', 'postalcode': '123', 'country': 'Country', 'countrycodes': 'cc', 'format': 'jsonv2'}
    initial_params = params.copy()
    updated_params = geocode.simplify_query_params("Testland", params, 1, "CODE", initial_params)
    assert updated_params['street'] == 'Main St'


def test_simplify_query_params_street_removal():
    """Test strategy 1: Remove street entirely"""
    params = {'street': 'Main', 'city': 'Test', 'postalcode': '123', 'country': 'Country', 'countrycodes': 'cc', 'format': 'jsonv2'}
    initial_params = params.copy()
    updated_params = geocode.simplify_query_params("Testland", params, 2, "CODE", initial_params)
    assert 'street' not in updated_params
    assert updated_params['city'] == 'Test'


def test_simplify_query_params_postal_removal():
    """Test strategy 2: Remove postalcode"""
    params = {'city': 'Test', 'postalcode': '123', 'country': 'Country', 'countrycodes': 'cc', 'format': 'jsonv2'}
    initial_params = params.copy()
    updated_params = geocode.simplify_query_params("Testland", params, 3, "CODE", initial_params)
    assert 'postalcode' not in updated_params
    assert updated_params['city'] == 'Test'


def test_simplify_query_params_simplify_city():
    """Test strategy 3: Simplify city (before hyphen)"""
    params = {'city': 'New-City', 'country': 'Country', 'countrycodes': 'cc', 'format': 'jsonv2'}
    initial_params = params.copy()
    updated_params = geocode.simplify_query_params("Testland", params, 4, "CODE", initial_params)
    assert updated_params['city'] == 'New'


def test_simplify_query_params_city_removal():
    """Test strategy 4: Remove city entirely"""
    params = {'city': 'Test', 'country': 'Country', 'countrycodes': 'cc', 'format': 'jsonv2'}
    initial_params = params.copy()
    updated_params = geocode.simplify_query_params("Testland", params, 5, "CODE", initial_params)
    assert 'city' not in updated_params


def test_simplify_query_params_remove_country():
    """Test attempt 6: Remove country restrictions"""
    params = {'street': 'Main', 'city': 'Test', 'country': 'Country', 'countrycodes': 'cc', 'format': 'jsonv2'}
    initial_params = params.copy()
    updated_params = geocode.simplify_query_params("Testland", params, 6, "CODE", initial_params)
    assert 'country' not in updated_params
    assert 'countrycodes' not in updated_params
    assert updated_params['street'] == 'Main'  # Reset to initial params


def test_simplify_query_params_second_round():
    """Test attempt 7: Second round strategies without country"""
    params = {'street': 'Main St, Extra', 'city': 'Test', 'format': 'jsonv2'}
    initial_params = {'street': 'Main St, Extra', 'city': 'Test', 'country': 'Country', 'countrycodes': 'cc', 'format': 'jsonv2'}
    updated_params = geocode.simplify_query_params("Testland", params, 7, "CODE", initial_params)
    assert updated_params['street'] == 'Main St'  # Comma removal again

# tests for convert_address_to_lat_lng function

def test_convert_address_to_lat_lng_success():
    row = ["CODE1", "Name", "Main St", "Testville", "12345"]
    fake_response = [{"lat": "12.34", "lon": "56.78"}]

    with patch("common.geocode.dbm.open", MagicMock()), \
         patch("common.geocode.cached_get", return_value=fake_response) as mock_cached:
        lat_lng = geocode.convert_address_to_lat_lng(True, "Testland", "cc", row)
    
    assert lat_lng == ["12.34", "56.78"]
    mock_cached.assert_called_once()


def test_convert_address_to_lat_lng_retry_then_success():
    row = ["CODE1", "Name", "Main St", "Testville", "12345"]
    responses = [[], [{"lat": "12.34", "lon": "56.78"}]]

    with patch("common.geocode.dbm.open", MagicMock()), \
         patch("common.geocode.cached_get", side_effect=responses) as mock_cached:
        lat_lng = geocode.convert_address_to_lat_lng(True, "Testland", "cc", row)

    assert lat_lng == ["12.34", "56.78"]
    assert mock_cached.call_count == 2


# tests for geocode_csv function

def test_geocode_csv_writes(tmp_path):
    input_csv = tmp_path / "input.csv"
    output_csv = tmp_path / "output.csv"
    
    # Write CSV header + one row
    input_csv.write_text(
        "code;name;street;city;postalcode\nCODE1;Name;Main St;Testville;12345",
        encoding="utf-8"
    )
    
    with patch("common.geocode.dbm.open", MagicMock()), \
         patch("common.geocode.convert_address_to_lat_lng", return_value=["12.34", "56.78"]), \
         patch("common.geocode.write_csv") as mock_write_csv:
        failure_count, total_count = geocode.geocode_csv(True, "Testland", "cc", str(input_csv), str(output_csv))
    
    # Check return values
    assert failure_count == 0
    assert total_count == 1
    
    # write_csv called with header + lat/lng row
    rows = mock_write_csv.call_args[0][2]
    assert rows[0] == ["code", "name", "street", "city", "postalcode", "lat", "lng"]
    assert rows[1] == ["CODE1", "Name", "Main St", "Testville", "12345", "12.34", "56.78"]
