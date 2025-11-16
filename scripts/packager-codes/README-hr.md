# Croatian Packager Codes Geocoding Script

## Overview

This Python script automates the process of downloading, converting, and geocoding Croatian packager codes from the Croatian Ministry of Agriculture website.

## What it does

1. **Downloads** the latest Excel file from http://veterinarstvo.hr/default.aspx?id=2423
2. **Converts** the Excel file to CSV format
3. **Preprocesses** the data (removes header lines, handles semicolons, cleans formatting)
4. **Geocodes** all addresses using Nominatim OpenStreetMap API
5. **Outputs** a final CSV file with latitude and longitude coordinates

## Installation

Install the required Python packages:

```bash
pip install -r requirements-hr.txt
```

Or manually:

```bash
pip install requests openpyxl pandas beautifulsoup4 xlrd
```

## Usage

### Basic Usage

Simply run the script:

```bash
python3 hr-packagers-refresh.py
```

Or make it executable and run directly:

```bash
chmod +x hr-packagers-refresh.py
./hr-packagers-refresh.py
```

### Advanced Options

**List available Excel files** (without downloading):
```bash
python3 hr-packagers-refresh.py --list-files
```

**Force re-download** of the Excel file (even if it exists):
```bash
python3 hr-packagers-refresh.py --force-download
```

**Skip geocoding** (only download and preprocess):
```bash
python3 hr-packagers-refresh.py --skip-geocoding
```

### File Selection

The Croatian ministry website may contain multiple Excel files. The target file follows this pattern:
- **Format**: `DD-MM-YYYY. svi odobreni objekti.xls`
- **Example**: `03-11-2025. svi odobreni objekti.xls` (current)
- **Previous**: `07-08-2023. svi odobreni objekti.xls` (older version)

The script will:

1. **Automatically select** the file containing "svi odobreni objekti" (all approved establishments)
2. **Ask you to choose** if multiple files exist and none match
3. Show all available files with their descriptions

To see all available files without downloading:
```bash
python3 hr-packagers-refresh.py --list-files
```

## Output

The script generates several files:

- `hr_downloaded.xls` - Downloaded Excel file from the ministry website
- `hr_raw.csv` - Raw CSV conversion from Excel
- `hr-export.csv` - Preprocessed CSV ready for geocoding
- `HR-merge-UTF-8.csv` - **Final output** with coordinates
- `cache_hr.db` - Cache of geocoding API responses (speeds up reruns)

## Features

- **Caching**: API responses are cached to avoid redundant requests
- **Rate limiting**: Respects Nominatim's 1 request per second policy
- **Retry logic**: If geocoding fails, tries with progressively simplified queries
- **Resumable**: Intermediate files are kept, so you can restart from any step
- **Error handling**: Graceful handling of API failures and missing data

## Rerunning

The script checks for existing intermediate files and skips steps that are already complete. To force a fresh run:

```bash
# Remove all intermediate files
rm hr_downloaded.xls hr_raw.csv hr-export.csv cache_hr.db

# Run again
python3 hr-packagers-refresh.py
```

## Manual Download

If automatic download fails, manually download the Excel file from the ministry website and save it as `hr_downloaded.xls` in the same directory as the script.

## Notes

- The script follows OpenStreetMap Nominatim usage policy (1 req/sec with User-Agent)
- Geocoding may take time due to rate limiting (especially on first run without cache)
- Empty coordinates are returned if an address cannot be geocoded after multiple attempts
