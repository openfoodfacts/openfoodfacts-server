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
import csv
import math
import os
from collections import defaultdict
from statistics import median
from typing import Dict, Iterable, List, Optional, Tuple

LAT_COLUMNS = ('lat', 'latitude')
LNG_COLUMNS = ('lng', 'lon', 'long', 'longitude')
GROUP_COLUMNS = ('postalcode',)

REPORT_FIELDS = ['line', 'code', 'group', 'lat', 'lng', 'reason', 'distance_km', 'group_lat', 'group_lng', 'group_size']

EARTH_RADIUS_KM = 6371.0

# packager-codes/ directory at the root of the repository
PACKAGER_CODES_DIR = os.path.realpath(os.path.join(os.path.dirname(__file__), '..', '..', '..', 'packager-codes'))


def haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Great-circle distance between two points, in kilometers."""
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lng2 - lng1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    return 2 * EARTH_RADIUS_KM * math.asin(math.sqrt(a))


def median_longitude(longitudes: List[float]) -> float:
    """
    Median of longitudes, taking the antimeridian into account.

    If the points span more than 180 degrees, they are assumed to cross the
    antimeridian: negative longitudes are shifted by 360 before taking the median.
    """
    if max(longitudes) - min(longitudes) <= 180:
        return median(longitudes)
    center = median(lng + 360 if lng < 0 else lng for lng in longitudes)
    return center - 360 if center > 180 else center


def find_column(header: List[str], candidates: Iterable[str]) -> Optional[str]:
    """Return the first header name matching one of the candidates (case-insensitive)."""
    lowered = {name.strip().lower(): name for name in header}
    for candidate in candidates:
        if candidate in lowered:
            return lowered[candidate]
    return None


def parse_coordinates(lat: str, lng: str) -> Tuple[Optional[float], Optional[float], Optional[str]]:
    """
    Parse a lat/lng pair.

    Returns:
        Tuple of (lat, lng, reason). reason is None when the pair is usable,
        otherwise 'missing_coordinates', 'invalid_coordinates' or 'null_island'.
    """
    lat = (lat or '').strip()
    lng = (lng or '').strip()
    if not lat or not lng:
        return None, None, 'missing_coordinates'
    try:
        lat_f = float(lat.replace(',', '.'))
        lng_f = float(lng.replace(',', '.'))
    except ValueError:
        return None, None, 'invalid_coordinates'
    if not (math.isfinite(lat_f) and math.isfinite(lng_f)) or not (-90 <= lat_f <= 90 and -180 <= lng_f <= 180):
        return None, None, 'invalid_coordinates'
    if lat_f == 0 and lng_f == 0:
        return None, None, 'null_island'
    return lat_f, lng_f, None


def check_rows(rows: List[Dict[str, str]], code_col: str, lat_col: str, lng_col: str,
               group_col: Optional[str] = None, group_prefix: Optional[int] = None,
               max_distance_km: float = 100.0, min_group_size: int = 3,
               report_missing: bool = False) -> List[Dict[str, str]]:
    """
    Find suspicious coordinates in packager rows.

    Each point is compared with the median position of the points sharing the same
    group (e.g. postal code or department). Points farther than max_distance_km are
    reported as 'far_from_group'. Groups with fewer than min_group_size valid points
    are not checked, as their median is not reliable.

    Args:
        rows: Rows as dicts (from csv.DictReader)
        code_col: Column holding the approval code
        lat_col: Column holding the latitude
        lng_col: Column holding the longitude
        group_col: Column used to group points (no distance check if None)
        group_prefix: If set, only the first group_prefix characters of the group value are used
        max_distance_km: Distance to the group median above which a point is reported
        min_group_size: Minimum number of valid points in a group to check it
        report_missing: Also report rows without coordinates

    Returns:
        List of report rows (see REPORT_FIELDS), in input order
    """
    issues = []
    groups = defaultdict(list)  # group -> [(line, row, lat, lng)]

    # line numbers are 1-based and count the header line
    for line, row in enumerate(rows, start=2):
        lat, lng, reason = parse_coordinates(row.get(lat_col), row.get(lng_col))
        group = _group_key(row, group_col, group_prefix)
        if reason:
            if reason != 'missing_coordinates' or report_missing:
                issues.append(_report(line, row, code_col, group, reason))
        elif group:
            groups[group].append((line, row, lat, lng))

    for group, members in groups.items():
        if len(members) >= min_group_size:
            issues.extend(_far_from_group(group, members, code_col, max_distance_km))

    issues.sort(key=lambda issue: issue['line'])
    return issues


def _group_key(row: Dict[str, str], group_col: Optional[str], group_prefix: Optional[int]) -> str:
    if not group_col:
        return ''
    group = (row.get(group_col) or '').strip()
    return group[:group_prefix] if group_prefix else group


def _far_from_group(group: str, members: List[Tuple[int, Dict[str, str], float, float]],
                    code_col: str, max_distance_km: float) -> List[Dict[str, str]]:
    """Report the members of a group that are farther than max_distance_km from its median position."""
    center_lat = median(m[2] for m in members)
    center_lng = median_longitude([m[3] for m in members])
    issues = []
    for line, row, lat, lng in members:
        distance = haversine_km(lat, lng, center_lat, center_lng)
        if distance > max_distance_km:
            issue = _report(line, row, code_col, group, 'far_from_group')
            issue.update({
                'lat': lat,
                'lng': lng,
                'distance_km': round(distance, 1),
                'group_lat': round(center_lat, 6),
                'group_lng': round(center_lng, 6),
                'group_size': len(members),
            })
            issues.append(issue)
    return issues


def _report(line: int, row: Dict[str, str], code_col: str, group: str, reason: str) -> Dict[str, str]:
    issue = dict.fromkeys(REPORT_FIELDS, '')
    issue.update({'line': line, 'code': (row.get(code_col) or '').strip(), 'group': group, 'reason': reason})
    return issue


def neutralize_formula(value):
    """
    Prefix text starting with a spreadsheet formula character with a quote, so that
    values coming from downloaded files are not run as formulas when the report is
    opened in a spreadsheet. Other values are returned unchanged.
    """
    if isinstance(value, str) and value.startswith(('=', '+', '-', '@', '\t', '\r')):
        return "'" + value
    return value


def find_packager_file(country_code: str, base_dir: str = PACKAGER_CODES_DIR) -> str:
    """
    Find the packager file of a country (e.g. FR-merge-UTF-8.csv for 'fr').

    The returned path is built from the directory listing, never from the argument.

    Raises:
        ValueError: If no file is found for the country
    """
    prefix = f"{country_code.strip().upper()}-merge"
    for name in sorted(os.listdir(base_dir)):
        if name.upper().startswith(prefix.upper()) and name.lower().endswith(('.csv', '.tsv')):
            return os.path.join(base_dir, name)
    raise ValueError(f"no packager file for country '{country_code}' in {base_dir}")


def read_packager_file(path: str) -> Tuple[List[str], List[Dict[str, str]]]:
    """Read a packager CSV/TSV file, guessing the delimiter from the header line."""
    with open(path, newline='', encoding='utf-8-sig') as f:
        first_line = f.readline()
        delimiter = '\t' if first_line.count('\t') > first_line.count(';') else ';'
        f.seek(0)
        reader = csv.DictReader(f, delimiter=delimiter)
        rows = list(reader)
        return list(reader.fieldnames or []), rows
