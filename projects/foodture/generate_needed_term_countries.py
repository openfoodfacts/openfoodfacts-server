#!/usr/bin/env python3
# This file is part of Product Opener.
# Copyright (C) 2011-2026 Association Open Food Facts
# Product Opener is free software, licensed under the GNU Affero General Public License v3 or later.

"""List the countries in which FOODTURE needs each FoodEx2 term.

Inputs:
- the ACTIA workbook (not in the repo: https://docs.google.com/spreadsheets/d/1IuVaQWNB072WD627e7CrGCGPc5ODJExo/export?format=xlsx)
  - tab Food_product_to_model: one row per Country / Food product L7
  - tab Is_needed_a_recipe: "Is_needed_a_recipe ? Mano" (Yes / Maybe / No) for each L7
- foodture_foodex2_to_off_categories.csv: FOODTURE code -> OFF category, with the ACTIA L7 names of each code
  (column actia_l7_names, names separated by | or ;)

Only the L7s with Yes or Maybe are kept. "EU27+N" in the Country column means that the term is needed in all
the 32 FOODTURE countries. "UK" is the United Kingdom.

Outputs (committed, as the ACTIA workbook is not in the repo):
- foodture_needed_term_countries.csv: one row per needed FOODTURE code x country
- foodture_needed_countries_per_term.csv: one row per FOODTURE code, with its needed countries

The representative products dataset also covers 2 countries that FOODTURE does not need, for other research.
EFSA has no consumption data for them in the ACTIA workbook, so their terms are chosen with simple rules:
- Iceland: the terms needed in at least --iceland-min-nordic (2) of the 4 Nordic FOODTURE countries
  (Denmark, Finland, Norway, Sweden)
- Canada: the terms needed in at least --canada-min-countries (9) of the 32 FOODTURE countries (common European basket)
Output: representative_dataset_other_countries.csv (one row per term x country)

Usage: generate_needed_term_countries.py <actia.xlsx> [--mapping <csv>] [--output-dir <dir>]
	[--iceland-min-nordic 2] [--canada-min-countries 9]
Needs openpyxl.
"""

import argparse
import collections
import csv
import os
import re
import sys

import openpyxl

# The 32 FOODTURE countries (EU27, Norway, Switzerland, United Kingdom, Serbia, Montenegro): ACTIA name -> OFF tag
FOODTURE_COUNTRIES = {
    "Austria": "en:austria",
    "Belgium": "en:belgium",
    "Bulgaria": "en:bulgaria",
    "Croatia": "en:croatia",
    "Cyprus": "en:cyprus",
    "Czech Republic": "en:czech-republic",
    "Denmark": "en:denmark",
    "Estonia": "en:estonia",
    "Finland": "en:finland",
    "France": "en:france",
    "Germany": "en:germany",
    "Greece": "en:greece",
    "Hungary": "en:hungary",
    "Ireland": "en:ireland",
    "Italy": "en:italy",
    "Latvia": "en:latvia",
    "Lithuania": "en:lithuania",
    "Luxembourg": "en:luxembourg",
    "Malta": "en:malta",
    "Montenegro": "en:montenegro",
    "Netherlands": "en:netherlands",
    "Norway": "en:norway",
    "Poland": "en:poland",
    "Portugal": "en:portugal",
    "Romania": "en:romania",
    "Serbia": "en:serbia",
    "Slovakia": "en:slovakia",
    "Slovenia": "en:slovenia",
    "Spain": "en:spain",
    "Sweden": "en:sweden",
    "Switzerland": "en:switzerland",
    "United Kingdom": "en:united-kingdom",
}
COUNTRY_ALIASES = {"UK": "United Kingdom", "Czechia": "Czech Republic"}
NEEDED_ANSWERS = {"yes", "maybe"}


def header_index(header, wanted, default):
    for i, name in enumerate(header):
        if name and wanted.lower() in str(name).lower():
            return i
    return default


def read_actia(path):
    """Return {L7 name: needs recipe answer} for Yes / Maybe L7s, and {L7 name: set of countries}."""
    wb = openpyxl.load_workbook(path, read_only=True)

    rows = wb["Is_needed_a_recipe"].iter_rows(values_only=True)
    header = next(rows)
    l7_col = header_index(header, "Food Product L7", 2)
    mano_col = header_index(header, "Mano", 3)
    needs = {}
    for r in rows:
        if r[l7_col] and str(r[mano_col] or "").strip().lower() in NEEDED_ANSWERS:
            needs[str(r[l7_col]).strip()] = str(r[mano_col]).strip()

    rows = wb["Food_product_to_model"].iter_rows(values_only=True)
    header = next(rows)
    country_col = header_index(header, "Country", 0)
    l7_col = header_index(header, "Food product L7", 1)
    countries = collections.defaultdict(set)
    for r in rows:
        if r[country_col] and r[l7_col]:
            countries[str(r[l7_col]).strip()].add(str(r[country_col]).strip())
    return needs, countries


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("actia", help="ACTIA workbook (xlsx)")
    parser.add_argument("--mapping", default=os.path.join(here, "foodture_foodex2_to_off_categories.csv"))
    parser.add_argument("--output-dir", default=here)
    parser.add_argument("--iceland-min-nordic", type=int, default=2)
    parser.add_argument("--canada-min-countries", type=int, default=9)
    args = parser.parse_args()

    needs, l7_countries = read_actia(args.actia)
    with open(args.mapping, newline="", encoding="utf-8") as f:
        mapping = list(csv.DictReader(f))

    unknown_countries = collections.Counter()
    terms = []
    for row in mapping:
        l7_names = [n.strip() for n in re.split(r"[|;]", row["actia_l7_names"]) if n.strip()]
        countries = set()
        all_countries = False
        for name in l7_names:
            if name not in needs:
                continue
            for country in l7_countries.get(name, ()):
                if country.upper().startswith("EU27"):
                    all_countries = True
                    continue
                country = COUNTRY_ALIASES.get(country, country)
                if country in FOODTURE_COUNTRIES:
                    countries.add(country)
                else:
                    unknown_countries[country] += 1
        if all_countries:
            countries = set(FOODTURE_COUNTRIES)
        terms.append((row, sorted(countries), all_countries))

    if unknown_countries:
        print(f"Unknown countries (ignored): {dict(unknown_countries)}", file=sys.stderr)

    cells = 0
    with open(os.path.join(args.output_dir, "foodture_needed_term_countries.csv"), "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(["foodture_code", "foodex2_name", "off_category", "country", "country_tag", "needs_recipe", "eu27_all_countries"])
        for row, countries, all_countries in terms:
            for country in countries:
                w.writerow([row["foodture_code"], row["foodture_name"], row["off_category"], country,
                            FOODTURE_COUNTRIES[country], row["needs_recipe"], "yes" if all_countries else ""])
                cells += 1

    with open(os.path.join(args.output_dir, "foodture_needed_countries_per_term.csv"), "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(["foodture_code", "foodex2_name", "off_category", "needs_recipe", "n_countries", "countries", "eu27_all_countries"])
        for row, countries, all_countries in terms:
            w.writerow([row["foodture_code"], row["foodture_name"], row["off_category"], row["needs_recipe"], len(countries),
                        ", ".join(countries), "yes" if all_countries else ""])

    nordic = {"Denmark", "Finland", "Norway", "Sweden"}
    other = []
    for row, countries, all_countries in terms:
        n_nordic = len(nordic.intersection(countries))
        if n_nordic >= args.iceland_min_nordic:
            other.append((row, "Iceland", "en:iceland", f"needed in {n_nordic} of the 4 Nordic FOODTURE countries"))
    for row, countries, all_countries in terms:
        if len(countries) >= args.canada_min_countries:
            other.append((row, "Canada", "en:canada", f"needed in {len(countries)} of the 32 FOODTURE countries"))
    with open(os.path.join(args.output_dir, "representative_dataset_other_countries.csv"), "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(["foodture_code", "foodex2_name", "off_category", "country", "country_tag", "selection_rule"])
        for row, country, country_tag, rule in other:
            w.writerow([row["foodture_code"], row["foodture_name"], row["off_category"], country, country_tag, rule])
    print(f"Other countries: {collections.Counter(o[1] for o in other)}", file=sys.stderr)

    print(f"{len(terms)} terms, {sum(1 for t in terms if t[1])} needed in at least one country, "
          f"{sum(1 for t in terms if t[2])} in all countries (EU27+N), {cells} needed term x country cells", file=sys.stderr)


if __name__ == "__main__":
    main()
