"""Export the FoodEx2 -> OFF categories mapping from the workbook to a CSV file read by
extract_data_for_representative_products.pl --mapping-file.

Usage: python export_mapping_csv.py <foodture_foodex2_l7_to_off_mapping.xlsx> <output.csv>
"""
import csv
import sys

import openpyxl

COLUMNS = [
    # output column, workbook column ("FOODTURE codes" sheet)
    ("foodture_code", "FOODTURE code"),
    ("foodture_name", "FOODTURE name"),
    ("actia_l7_names", "ACTIA L7 names"),
    ("needs_recipe", "Needs recipe (Mano)"),
    ("l1", "ACTIA L1"),
    ("l2", "ACTIA L2"),
    ("foodex2_code", "FoodEx2 code"),
    ("foodex2_name", "FoodEx2 name"),
    ("foodex2_level", "FoodEx2 level"),
    ("off_category", "OFF category"),
    ("off_name", "OFF name"),
    ("off_status", "OFF status"),
    ("status", "Flag"),
]

wb = openpyxl.load_workbook(sys.argv[1], read_only=True)
rows = list(wb["FOODTURE codes"].iter_rows(values_only=True))
header = list(rows[0])
index = [header.index(source) for _, source in COLUMNS]
with open(sys.argv[2], "w", newline="", encoding="utf-8") as f:
    writer = csv.writer(f, lineterminator="\n")
    writer.writerow([name for name, _ in COLUMNS])
    n = 0
    for row in rows[1:]:
        if row[index[0]] is None:
            continue
        writer.writerow(["" if row[i] is None else str(row[i]).strip() for i in index])
        n += 1
print(f"{n} rows written to {sys.argv[2]}", file=sys.stderr)
