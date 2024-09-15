#!/usr/bin/env python3
"""A small script to export agribalyse categories in a CSV using categories.full.json
"""
import json
import csv

datas = json.load(open("categories.full.json", "r"))


# get agribalyse
all_agri_cats = set(tagid for tagid, d in datas.items() for k in d.keys() if "agribalyse" in k)
agri_cats = all_agri_cats

# and children (until we have no more children)
while agri_cats:
    children = set(
        tagid
        for tagid, d in datas.items()
        if set(d.get("parents",[])) & agri_cats
    )
    all_agri_cats |= children
    agri_cats = children

# get agribalyse exploring parents
def agribalyse(tagid, depth=0):
    data = datas[tagid]
    code = data.get("agribalyse_food_code", data.get("agribalyse_proxy_food_code", {})).get("en")
    if code:
        return code, depth
    # explore all parents and take the lowest depth
    candidates = []
    for p in data.get("parents", []):
        candidate = agribalyse(p, depth + 1)
        if candidate:
            candidates.append(candidate)
    candidates.sort(key=lambda c: c[1])
    return candidates[0] if candidates else None


# build data
rows = []
for tagid in sorted(all_agri_cats):
    d = datas[tagid]
    if not ({"en", "fr"} & set(d["name"].keys())):
        # no fr or en, skip
        continue
    agri, depth = agribalyse(tagid)
    rows.append({
        "tagid": tagid,
        "cat_en": d["name"].get("en", ""),
        "cat_fr": d["name"].get("fr", ""),
        "agribalyse_food_code": agri,
        })

len(rows)

rows.sort(key=lambda r: r.get("cat_en") or r.get("cat_fr"))

with open("ecoscores-cat.csv", "w") as f:
    writer = csv.DictWriter(f, fieldnames=["tagid", "cat_en", "cat_fr", "agribalyse_food_code"])
    writer.writeheader()
    writer.writerows(rows)
