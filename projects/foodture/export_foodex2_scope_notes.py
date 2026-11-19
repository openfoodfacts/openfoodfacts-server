#!/usr/bin/env python3
# Writes foodture_foodex2_scope_notes.csv: the FoodEx2 description (scope note of the EFSA MTX catalogue) of each
# FoodEx2 code of foodture_foodex2_to_off_categories.csv, shown by build_campaign_site.pl next to the categories.
# The sentences about sampling and reporting (part consumed / analysed, facets) are removed, as for the
# foodex2_scope_note properties of the categories taxonomy (foodex2_mapping/add_foodex2_properties.py).
#
# Usage: python3 export_foodex2_scope_notes.py <mtx_terms.json> [<mapping.csv>] [<output.csv>]
# mtx_terms.json: termCode -> term of the MTX catalogue term sheet (foodex2_mapping work directory)
import csv
import json
import os
import re
import sys

here = os.path.dirname(os.path.abspath(__file__))
terms_file = sys.argv[1]
mapping_file = sys.argv[2] if len(sys.argv) > 2 else os.path.join(here, 'foodture_foodex2_to_off_categories.csv')
output_file = sys.argv[3] if len(sys.argv) > 3 else os.path.join(here, 'foodture_foodex2_scope_notes.csv')

BOILERPLATE = re.compile(r'part consumed|part considered|\bfacets?\b|descriptor|data collections related to legislations')


def scope(note):
    s = (note or '').split('£')[0]
    s = re.sub(r'\.(?=[A-Z])', '. ', s)
    return ' '.join(x for x in re.split(r'(?<=[.!?])\s+(?=[A-Z])', s.strip()) if not BOILERPLATE.search(x)).strip()


terms = json.load(open(terms_file, encoding='utf-8'))
codes = sorted({row['foodex2_code'] for row in csv.DictReader(open(mapping_file, encoding='utf-8')) if row['foodex2_code']})
missing = 0
with open(output_file, 'w', newline='', encoding='utf-8') as out:
    w = csv.writer(out, lineterminator='\n')
    w.writerow(['foodex2_code', 'foodex2_name', 'foodex2_scope_note'])
    for code in codes:
        term = terms.get(code)
        if term is None:
            missing += 1
            continue
        w.writerow([code, term.get('termExtendedName', ''), scope(term.get('termScopeNote'))])
print(f'{len(codes) - missing} FoodEx2 codes written to {output_file}, {missing} not in {terms_file}', file=sys.stderr)
