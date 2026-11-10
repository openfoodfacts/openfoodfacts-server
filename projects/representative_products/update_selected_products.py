"""Update the versioned list of the products of the representative products dataset.

The dataset has one product for each country and FoodEx2 term (FOODTURE code) of the mapping.
selected_products.csv is the source of truth: one row per (country, FOODTURE code) that ever had a product,
with its status (active or removed). Git history shows how the set evolved.

Input: the output of extract_data_for_representative_products.pl (representative_products.csv).
Only rows with a product that is still complete are selected.

Output:
- selected_products.csv, updated in place (or --output)
- added_codes.txt: codes that are in the set now and were not before (to add the team to)
- removed_codes.txt: codes that were in the set and are not anymore (to remove the team from)

Usage: python3 update_selected_products.py <representative_products.csv> [--selected selected_products.csv]
    [--date YYYY-MM-DD] [--reason "..."] [--output-dir dir]
"""
import argparse
import csv
import datetime
import os
import sys

FIELDS = [
    "code",
    "country",
    "off_country_id",
    "foodture_country",
    "foodture_code",
    "foodture_name",
    "foodex2_code",
    "foodex2_name",
    "off_category_id",
    "product_name",
    "status",
    "date_added",
    "date_removed",
    "reason",
]

here = os.path.dirname(os.path.abspath(__file__))
parser = argparse.ArgumentParser()
parser.add_argument("representative_products")
parser.add_argument("--selected", default=os.path.join(here, "selected_products.csv"))
parser.add_argument("--output-dir", default=here)
parser.add_argument("--date", default=datetime.date.today().isoformat())
parser.add_argument("--reason", default="most scanned complete product")
args = parser.parse_args()

csv.field_size_limit(sys.maxsize)

# current selection: (country, FOODTURE code) -> row
new = {}
with open(args.representative_products, newline="", encoding="utf-8") as f:
    for row in csv.DictReader(f):
        if not row.get("code") or row.get("complete") != "1" or not row.get("foodture_code"):
            continue
        key = (row["off_country_id"], row["foodture_code"])
        new[key] = {
            "code": row["code"],
            "country": row["Country"],
            "off_country_id": row["off_country_id"],
            "foodture_country": row["foodture_country"],
            "foodture_code": row["foodture_code"],
            "foodture_name": row["Food Product L7"],
            "foodex2_code": row["foodex2_code"],
            "foodex2_name": row["foodex2_name"],
            "off_category_id": row["off_category_id"],
            "product_name": row["product_name"],
        }

old_rows = []
if os.path.exists(args.selected):
    with open(args.selected, newline="", encoding="utf-8") as f:
        old_rows = list(csv.DictReader(f))

old_active_codes = {r["code"] for r in old_rows if r["status"] == "active"}
active_by_key = {(r["off_country_id"], r["foodture_code"]): r for r in old_rows if r["status"] == "active"}

rows = []
counts = {"kept": 0, "replaced": 0, "removed": 0, "added": 0}
for row in old_rows:
    key = (row["off_country_id"], row["foodture_code"])
    if row["status"] == "active":
        current = new.get(key)
        if current is not None and current["code"] == row["code"]:
            # same product: update the descriptive columns only
            row.update({k: v for k, v in current.items() if k != "code"})
            counts["kept"] += 1
        else:
            row["status"] = "removed"
            row["date_removed"] = args.date
            row["reason"] = (row["reason"] + "; " if row["reason"] else "") + (
                "replaced by " + current["code"] if current else "no product anymore"
            )
            counts["replaced" if current else "removed"] += 1
    rows.append(row)

for key, current in sorted(new.items()):
    old = active_by_key.get(key)
    if old is not None and old["code"] == current["code"]:
        continue
    rows.append({**current, "status": "active", "date_added": args.date, "date_removed": "", "reason": args.reason})
    counts["added"] += 1

rows.sort(key=lambda r: (r["off_country_id"], r["foodture_code"], r["status"] != "active", r["date_added"]))

new_active_codes = {r["code"] for r in rows if r["status"] == "active"}
added_codes = sorted(new_active_codes - old_active_codes)
removed_codes = sorted(old_active_codes - new_active_codes)

os.makedirs(args.output_dir, exist_ok=True)
with open(os.path.join(args.output_dir, "selected_products.csv"), "w", newline="", encoding="utf-8") as f:
    writer = csv.DictWriter(f, fieldnames=FIELDS, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
for name, codes in (("added_codes.txt", added_codes), ("removed_codes.txt", removed_codes)):
    with open(os.path.join(args.output_dir, name), "w") as f:
        f.writelines(c + "\n" for c in codes)

print(
    f"(country, FOODTURE code) pairs: {counts['kept']} kept, {counts['replaced']} replaced, "
    f"{counts['removed']} without a product anymore, {counts['added']} new rows; "
    f"{len(new_active_codes)} distinct products in the set, "
    f"{len(added_codes)} codes to add, {len(removed_codes)} codes to remove",
    file=sys.stderr,
)
non_numeric = [c for c in added_codes + removed_codes if not c.isdigit()]
if non_numeric:
    print(
        f"warning: {len(non_numeric)} codes are not numeric, update_all_products.pl --query-codes-from-file skips them: "
        + ", ".join(non_numeric[:10]),
        file=sys.stderr,
    )
