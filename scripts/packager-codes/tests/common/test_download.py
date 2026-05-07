from common.download import download_excel_file, cached_get
import pytest
import requests_mock
from unittest.mock import MagicMock, patch

@pytest.fixture
def fake_cache():
    """Provides an empty dictionary to simulate a cache for tests."""
    return {}

@pytest.fixture
def mock_requests_get():
    """Fixture to patch requests.get for tests."""
    with patch("requests.get") as mock_get:
        yield mock_get


# Tests for download_excel_file function

def test_download_excel_file_direct_mode(tmp_path, mock_requests_get):
    url = "https://example.com/page"
    output_file = tmp_path / "output.xlsx"
    expected_file_name = "file.xlsx"

    # Mock HTML page with file link
    html_content = '<html><body><a href="/downloads/file.xlsx">Download</a></body></html>'
    page_response = MagicMock()
    page_response.status_code = 200
    page_response.content = html_content.encode()
    
    file_response = MagicMock()
    file_response.status_code = 200
    file_response.content = b"excel-content"
    
    mock_requests_get.side_effect = [page_response, file_response]

    result = download_excel_file(
        country_name="Testland",
        url=url,
        output_file=str(output_file),
        keyword=None,
        expected_file_name=expected_file_name
    )

    # In filename search mode, function returns None
    assert result is None
    assert output_file.exists()
    assert output_file.read_bytes() == b"excel-content"


def test_download_excel_file_keyword_mode(tmp_path, mock_requests_get):
    page_url = "https://example.com/page"
    output_file = tmp_path / "output.xlsx"
    keyword = "data"
    expected_file_name = "data_file_old.xlsx"

    # Mock HTML page with keyword in file name
    mock_html = """
    <html>
        <body>
            <a href="https://example.com/files/data_file_new.xlsx">data_file_new.xlsx</a>
        </body>
    </html>
    """
    page_response = MagicMock()
    page_response.status_code = 200
    page_response.content = mock_html.encode("utf-8")

    excel_response = MagicMock()
    excel_response.status_code = 200
    excel_response.content = b"excel-content"

    # requests.get returns page first, then Excel file
    mock_requests_get.side_effect = [page_response, excel_response]

    result = download_excel_file(
        country_name="Testland",
        url=page_url,
        output_file=str(output_file),
        keyword=keyword,
        expected_file_name=expected_file_name
    )

    # Keyword mode returns the current filename
    assert result == "data_file_new.xlsx"
    assert output_file.exists()
    assert output_file.read_bytes() == b"excel-content"


# Tests for cached_get function

def test_cached_get_returns_from_cache(fake_cache):
    url = "https://example.com/data.json"
    expected_data = {"id": 1}
    fake_cache[url] = '{"id": 1}'

    result = cached_get(debug=True, country_name="Testland", url=url, cache=fake_cache)
    assert result == expected_data


def test_cached_get_fetches(fake_cache):
    url = "https://example.com/data.json"
    expected_data = {"id": 1}

    with patch("common.download.sleep", return_value=None), requests_mock.Mocker() as m:
        m.get(url, json=expected_data, status_code=200)

        result = cached_get(
            debug=True,
            country_name="Testland",
            url=url,
            cache=fake_cache
        )

    assert result == expected_data
    assert url in fake_cache
    assert fake_cache[url] == '{"id": 1}'
