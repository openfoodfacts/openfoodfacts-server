#!/usr/bin/env python3
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

Report suspicious coordinates in a packager codes file (read-only).

Examples:
    python3 check_packager_coordinates.py ../../packager-codes/DK-merge-UTF-8.csv
    python3 check_packager_coordinates.py ../../packager-codes/FR-merge-UTF-8.csv \\
        --code "Numéro agrément/Approval number" --group "Numero de département"
"""
import argparse
import csv
import sys

from common.check_coordinates import (GROUP_COLUMNS, LAT_COLUMNS, LNG_COLUMNS, REPORT_FIELDS,
                                      check_rows, find_column, read_packager_file)


def parse_args(argv=None):
    parser = argparse.ArgumentParser(
        description="Report suspicious coordinates in a packager codes CSV/TSV file. "
                    "Points far from the median of their group (e.g. postal code) are reported. "
                    "The input file is not modified.")
    parser.add_argument('file', help='packager codes file (; or tab separated, with a header line)')
    parser.add_argument('--code', help='code column (default: first column)')
    parser.add_argument('--lat', help=f"latitude column (default: one of {', '.join(LAT_COLUMNS)})")
    parser.add_argument('--lng', help=f"longitude column (default: one of {', '.join(LNG_COLUMNS)})")
    parser.add_argument('--group', help=f"column used to group points (default: {', '.join(GROUP_COLUMNS)} if present)")
    parser.add_argument('--group-prefix', type=int,
                        help='only use the first N characters of the group value (e.g. 2 for a French department)')
    parser.add_argument('--max-distance-km', type=float, default=100.0,
                        help='report points farther than this from their group median (default: 100)')
    parser.add_argument('--min-group-size', type=int, default=3,
                        help='do not check groups with fewer valid points (default: 3)')
    parser.add_argument('--report-missing', action='store_true', help='also report rows without coordinates')
    parser.add_argument('--output', help='write the report to this file instead of stdout')
    return parser.parse_args(argv)


def resolve_column(header, requested, candidates, label, required=True):
    if requested:
        if requested not in header:
            sys.exit(f"Error: {label} column '{requested}' not found. Columns: {', '.join(header)}")
        return requested
    found = find_column(header, candidates)
    if found is None and required:
        sys.exit(f"Error: no {label} column found, use --{label}. Columns: {', '.join(header)}")
    return found


def main(argv=None):
    args = parse_args(argv)
    header, rows = read_packager_file(args.file)
    if not header:
        sys.exit(f"Error: {args.file} is empty")

    code_col = resolve_column(header, args.code, header[:1], 'code')
    lat_col = resolve_column(header, args.lat, LAT_COLUMNS, 'lat')
    lng_col = resolve_column(header, args.lng, LNG_COLUMNS, 'lng')
    group_col = resolve_column(header, args.group, GROUP_COLUMNS, 'group', required=False)

    issues = check_rows(rows, code_col, lat_col, lng_col,
                        group_col=group_col, group_prefix=args.group_prefix,
                        max_distance_km=args.max_distance_km, min_group_size=args.min_group_size,
                        report_missing=args.report_missing)

    out = open(args.output, 'w', newline='', encoding='utf-8') if args.output else sys.stdout
    try:
        writer = csv.DictWriter(out, fieldnames=REPORT_FIELDS, delimiter=';')
        writer.writeheader()
        writer.writerows(issues)
    finally:
        if args.output:
            out.close()

    if group_col is None:
        print("Warning: no group column, only invalid coordinates were checked (use --group)", file=sys.stderr)
    print(f"{len(issues)} suspicious rows out of {len(rows)}", file=sys.stderr)


if __name__ == "__main__":
    main()
