"""
This file is part of Product Opener.

Product Opener
Copyright (C) 2011-2025 Association Open Food Facts
Contact: contact@openfoodfacts.org
Address: 21 rue des Iles, 94100 Saint-Maur des Fossés, France

Product Opener is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
"""
from bs4 import BeautifulSoup
import json
import requests
from time import sleep
from urllib.parse import urljoin, urlsplit

HEADERS = {'User-Agent': 'packager-openfoodfacts'}
REQUEST_TIMEOUT = 30


def _download_file_from_page(country_name: str, url: str, output_file: str, allowed_extensions: tuple[str, ...],
                             keyword: str = None, expected_file_name: str = None, label: str = 'file'):
    """Download a linked file from a page or a direct file URL."""
    url_path = urlsplit(url).path.lower()
    if not keyword and not expected_file_name and url_path.endswith(allowed_extensions):
        response = requests.get(url, headers=HEADERS, timeout=REQUEST_TIMEOUT)
        response.raise_for_status()

        with open(output_file, 'wb') as f:
            f.write(response.content)

        print(f"{country_name} - Info - {label.capitalize()} downloaded successfully: {output_file}, file size: {len(response.content)} bytes")
        return None

    response = requests.get(url, headers=HEADERS, timeout=REQUEST_TIMEOUT)
    response.raise_for_status()

    soup = BeautifulSoup(response.content, 'html.parser')

    linked_files = []
    for link in soup.find_all('a', href=True):
        href = link['href']
        if urlsplit(href).path.lower().endswith(allowed_extensions):
            linked_files.append(href)

    if not linked_files:
        raise FileNotFoundError(f"Could not find any {label} file links in {url}.")

    matched_link = None
    for file_url in linked_files:
        if keyword and keyword in file_url:
            matched_link = file_url
            break
        if expected_file_name and expected_file_name in file_url:
            matched_link = file_url
            break

    if not matched_link:
        if keyword:
            raise FileNotFoundError(f"Could not find {label} file matching keyword '{keyword}' in {url}.")
        raise FileNotFoundError(f"Could not find {label} file matching '{expected_file_name}' in {url}.")

    current_filename = urlsplit(matched_link).path.split('/')[-1]

    if keyword and expected_file_name and current_filename == expected_file_name:
        print(f"{country_name} - Info - File '{current_filename}' already processed. No update needed.")
        return None
    if keyword and expected_file_name:
        print(f"{country_name} - Info - New version detected: '{current_filename}' (expected: '{expected_file_name}')")

    absolute_url = urljoin(url, matched_link)
    file_response = requests.get(absolute_url, headers=HEADERS, timeout=REQUEST_TIMEOUT)
    file_response.raise_for_status()

    with open(output_file, 'wb') as f:
        f.write(file_response.content)

    print(f"{country_name} - Info - {label.capitalize()} downloaded successfully: {output_file}, file size: {len(file_response.content)} bytes")

    return current_filename if keyword else None


def download_excel_file(country_name: str, url: str, output_file: str, keyword: str = None, expected_file_name: str = None):
    """
    Download an Excel file from the given URL.
    
    Two modes of operation:
    1. Keyword search mode (keyword provided):
       - Scrapes the page for Excel files matching the keyword
       - Compares found filename with expected_file_name
       - Returns None if filename matches (no update needed)
       - Returns the current filename if different
       
    2. Filename search mode (keyword is None, expected_file_name provided):
       - Scrapes the page for Excel file matching expected_file_name
       - No change detection (filename doesn't change over time)
       - Downloads the file
       - Returns None
    
    Args:
        country_name: Name of the country for logging
        url: The URL of the page containing Excel file links
        output_file: The path where to save the downloaded file
        keyword: Optional keyword to search for in Excel file links (e.g., 'svi odobreni objekti').
                If provided, enables change detection.
        expected_file_name: The expected filename for comparison (keyword mode) or exact filename to find (filename search mode).
    
    Returns:
        str or None: Current filename if new version found in keyword mode, None otherwise
        
    Raises:
        FileNotFoundError: If no Excel files found or filename doesn't match
        ValueError: If neither keyword nor expected_file_name is provided
        RuntimeError: If download fails
    """
    print(f"\n{country_name} - Step - Downloading Excel file from {url}")
    
    try:
        return _download_file_from_page(country_name, url, output_file, ('.xls', '.xlsx'), keyword, expected_file_name, 'excel file')
    except requests.exceptions.RequestException as e:
        raise RuntimeError(f"Failed to download file: {e}") from e


def download_csv_file(country_name: str, url: str, output_file: str, keyword: str = None, expected_file_name: str = None):
    """Download a CSV file from a web page or direct URL."""
    print(f"\n{country_name} - Step - Downloading CSV file from {url}")

    try:
        return _download_file_from_page(country_name, url, output_file, ('.csv',), keyword, expected_file_name, 'csv file')
    except requests.exceptions.RequestException as e:
        raise RuntimeError(f"Failed to download file: {e}") from e


def cached_get(debug: bool, country_name: str, url: str, cache, sleep_duration: float = 2.0) -> list:
    """
    Get data from URL with caching support.
    
    This is notably used to query nominatim. 
    The cache can be a dbm database to enable persistent cache,
    allowing to only fetch new addresses as data source is updated.
    
    Args:
        debug: Enable debug logging
        country_name: Name of the country for logging
        url: The URL to fetch
        cache: DBM cache object
        sleep_duration: Delay in seconds between API requests (default: 2.0 for Nominatim policy compliance)
        
    Returns:
        JSON response as list/dict
    """
    if url in cache:
        cached_data = json.loads(cache[url])
        if debug:
            print(f"{country_name} - Debug - Using cached result for URL")
        return cached_data

    # Restart 3 times in case of empty response to make sure it is not an issue on API-side
    restart = True
    if debug:
        print(f"{country_name} - Debug - Fetching from API: {url}")
    while restart:
        try:
            response = requests.get(url, headers=HEADERS, timeout=REQUEST_TIMEOUT)
            # 1 request per second (Nominatim usage policy) - configurable via sleep_duration
            sleep(sleep_duration)
        except (requests.exceptions.RequestException, KeyError, IndexError) as e:
            print(f"{country_name} - Error - Request failed: {e}")
            return []

        if response.status_code == 403:
            raise RuntimeError("HTTP 403 (too many requests). Queries on API are too frequent, increase sleep time")
        
        if response.status_code != 200:
            raise RuntimeError(f"Unexpected HTTP {response.status_code} for URL: {url}")
            
        data = response.json()
        restart = False

    cache[url] = json.dumps(data)
    if debug:
        if data:
            print(f"{country_name} - Debug - Cached successful result with data")
        else:
            print(f"{country_name} - Debug - Cached empty result (location not found)")

    return data
