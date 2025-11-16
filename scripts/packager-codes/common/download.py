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
import sys
from time import sleep

HEADERS = {'User-Agent': 'packager-openfoodfacts'}


def download_excel_file(country_name: str, url: str, output_file: str, keyword: str = None, expected_file_name: str = None):
    """
    Download an Excel file from the given URL.
    
    Two modes of operation:
    1. Keyword search mode (keyword provided):
       - Scrapes the page for Excel files matching the keyword
       - Compares found filename with expected_file_name
       - Exits early if filename matches (no update needed)
       - Returns the current filename found
       
    2. Direct download mode (keyword is None):
       - Directly downloads the file at expected_file_name from the URL
       - No change detection in this mode
       - Returns None
    
    Args:
        country_name: Name of the country for logging
        url: The URL of the page containing the Excel file (or direct file URL if keyword is None)
        output_file: The path where to save the downloaded file
        keyword: Optional keyword to search for in Excel file links (e.g., 'svi odobreni objekti').
                If None, downloads expected_file_name directly.
        expected_file_name: The expected filename for comparison (keyword mode) or direct download (no keyword mode).
                           In keyword mode: exits with code 0 if found filename matches this.
                           In direct mode: appended to URL for download.
    
    Returns:
        str or None: Current filename if keyword mode, None if direct mode
    """
    print(f"\n{country_name} - Step - Downloading Excel file from {url}")
    
    try:
        if keyword:
            response = requests.get(url, headers=HEADERS)
            response.raise_for_status()
            
            soup = BeautifulSoup(response.content, 'html.parser')
            
            excel_files = []
            for link in soup.find_all('a', href=True):
                href = link['href']
                if href.endswith('.xls') or href.endswith('.xlsx'):
                    excel_files.append(href)
            
            if not excel_files:
                print(f"{country_name} - Error - Could not find any Excel file links in {url}.")
                sys.exit(1)

            excel_link = None
            for file_url in excel_files:
                if keyword in file_url:
                    excel_link = file_url
                    break
            
            if not excel_link:
                print(f"{country_name} - Error - Could not find Excel file matching keyword '{keyword}' in {url}.")
                sys.exit(1)

            current_filename = excel_link.split('/')[-1]
            
            if expected_file_name:
                if current_filename == expected_file_name:
                    print(f"{country_name} - Info - File '{current_filename}' already processed. No update needed.")
                    sys.exit(0)
                else:
                    print(f"{country_name} - Info - New version detected: '{current_filename}' (expected: '{expected_file_name}')")
            
            excel_response = requests.get(excel_link, headers=HEADERS)
            excel_response.raise_for_status()
            
            with open(output_file, 'wb') as f:
                f.write(excel_response.content)

            print(f"{country_name} - Info - Excel file downloaded successfully: {output_file}, file size: {len(excel_response.content)} bytes")
            
            return current_filename
            
        else:
            if not expected_file_name:
                print(f"{country_name} - Error - expected_file_name must be provided when keyword is None")
                sys.exit(1)
            
            file_url = f"{url.rstrip('/')}/{expected_file_name}"
            print(f"{country_name} - Info - Direct download mode: {file_url}")
            
            excel_response = requests.get(file_url, headers=HEADERS)
            excel_response.raise_for_status()
            
            with open(output_file, 'wb') as f:
                f.write(excel_response.content)

            print(f"{country_name} - Info - Excel file downloaded successfully: {output_file}, file size: {len(excel_response.content)} bytes")
            
            return None
        
    except requests.exceptions.RequestException as e:
        print(f"{country_name} - Error - Downloading file: {e}")
        sys.exit(1)


def cached_get(debug: bool, country_name: str, url: str, cache) -> list:
    """
    Get data from URL with caching support.
    
    Args:
        debug: Enable debug logging
        country_name: Name of the country for logging
        url: The URL to fetch
        cache: DBM cache object
        
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
    i = 0
    if debug:
        print(f"{country_name} - Debug - Fetching from API: {url}")
    while restart:
        try:
            response = requests.get(url, headers=HEADERS)
            # 1 request per second (Nominatim usage policy) - increased to 2 seconds for safety
            sleep(2)
        except (requests.exceptions.RequestException, KeyError, IndexError) as e:
            print(f"{country_name} - Error - Request failed: {e}")
            return []

        if response.status_code == 403:
            print(f"{country_name} - Error - HTTP 403 (too many requests). Queries on API are too frequent, increase sleep time")
            sys.exit(1)
        
        if response.status_code != 200:
            print(f"{country_name} - Error - Unexpected HTTP {response.status_code} for URL: {url}")
            sys.exit(1)
            
        data = response.json()
        restart = False

    cache[url] = json.dumps(data)
    if debug:
        if data:
            print(f"{country_name} - Debug - Cached successful result with data")
        else:
            print(f"{country_name} - Debug - Cached empty result (location not found)")

    return data
