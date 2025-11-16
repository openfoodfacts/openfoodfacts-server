import pytest
from unittest.mock import MagicMock, patch
import tempfile

from common import geocode


@pytest.fixture
def fake_cache():
    """Simulate a cache dictionary for dbm."""
    return {}

# tests for no_results_update_query function

def test_no_results_update_query_street_removal():
    url = "https://example.com/search.php?street=Main&city=Test&postalcode=123&country=Country&countrycodes=cc&format=jsonv2"
    updated_url = geocode.no_results_update_query("Testland", url, 1, "CODE")
    assert "street=" not in updated_url
    assert "city=Test" in updated_url
    assert "postalcode=123" in updated_url


def test_no_results_update_query_postal_removal():
    url = "https://example.com/search.php?city=Test&postalcode=123&country=Country&countrycodes=cc&format=jsonv2"
    updated_url = geocode.no_results_update_query("Testland", url, 2, "CODE")
    assert "postalcode=" not in updated_url
    assert "city=Test" in updated_url


def test_no_results_update_query_simplify_city():
    url = "https://example.com/search.php?city=New-City&country=Country&countrycodes=cc&format=jsonv2"
    updated_url = geocode.no_results_update_query("Testland", url, 3, "CODE")
    assert "city=New" in updated_url
    assert "City" not in updated_url

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
        geocode.geocode_csv(True, "Testland", "cc", str(input_csv), str(output_csv))
    
    # write_csv called with header + lat/lng row
    rows = mock_write_csv.call_args[0][2]
    assert rows[0] == ["code", "name", "street", "city", "postalcode", "lat", "lng"]
    assert rows[1] == ["CODE1", "Name", "Main St", "Testville", "12345", "12.34", "56.78"]
