import argparse
import json
from os.path import exists
from pprint import pprint

import requests
from config import cfg

cfg = cfg()

def arguments():
    parser = argparse.ArgumentParser()
    parser.add_argument('--verbose', '-v', action='store_true')
    parser.add_argument('--upc', required=True, help="Within OFF, known as 'code', 'gtinPuc' is USDA.")
    return parser.parse_args()


def search_via_upc(upc):

    usda_url = f"https://api.nal.usda.gov/fdc/v1/foods/search?api_key={cfg['API_KEY']}"
    # print(f"usda_url: {usda_url}")
    obj = {'query': upc}

    resp = requests.post(usda_url, json = obj)

    status = resp.status_code
    if status != 200:
        raise Exception(f"Status {status} returned from USDA search for gtinUPC ({upc}).")

    return  json.loads(str(resp.text))


def fetch_via_fdcid(fdcid):

    usda_url = f"https://api.nal.usda.gov/fdc/v1/food/{fdcid}?format=full&api_key={cfg['API_KEY']}"
    # print(f"usda_url: {usda_url}")

    resp = requests.get(usda_url)

    status = resp.status_code
    if status != 200:
        raise Exception(f"Status {status} returned from USDA fetch by fdcId ({fdcid}).")

    return  json.loads(str(resp.text))


label_matches = {
    'fat': 'Total lipid (fat)',
    'saturatedFat': 'Fatty acids, total saturated',
    'transFat': 'Fatty acids, total trans',
    'cholesterol': 'Cholesterol',
    'sodium': 'Sodium, Na',
    'carbohydrates': 'Carbohydrate, by difference',
    'fiber': 'Fiber, total dietary',
    'sugars': 'Sugars, total including NLEA',
    'protein': 'Protein',
    'calcium': 'Calcium, Ca',
    'iron': 'Iron, Fe',
    'calories': 'Energy'
}

if __name__ == '__main__':

    if not exists('.env'):
        raise Exception("A .env file must exist with an API_KEY value for the USDA fetch.")

    args = arguments()

    r1 = search_via_upc(args.upc)
    if len(r1['foods']) == 0:
        print(f"\nNo food found in search for ({args.upc})\n")
        quit()

    if args.verbose:
        print("search response")
        pprint(r1)

    print(f"\nsearch located fdcId: {r1['foods'][0]['fdcId']}\n")

    fdcId = r1['foods'][0]['fdcId']
    fetch_response = fetch_via_fdcid(fdcId)

    if args.verbose:
        print("fetch response")
        pprint(fetch_response)

    print(f"Serving size = {fetch_response['servingSize']} {fetch_response['servingSizeUnit']}")
    print(f"Package size = {fetch_response['packageWeight']}")
    print("")

    if fetch_response['servingSizeUnit'] == 'GRM':
        fraction = fetch_response['servingSize'] / 100
    else:
        fraction = -1

    extra_labels = list(label_matches.keys())

    next_entries = list()
    for entry in fetch_response['foodNutrients']:
        next_entry = dict()
        next_entry['name'] = entry['nutrient']['name']
        next_entry['unit'] = entry['nutrient']['unitName']
        next_entry['usda_name'] = 'UNKNOWN'
        next_entry['usda_amount'] = entry['amount']
        next_entry['amount'] = 'UNKNOWN'
        next_entry['calculated'] = False
        for label_entry_key in fetch_response['labelNutrients']:
            if label_matches[label_entry_key] == next_entry['name']:
                next_entry['usda_name'] = label_entry_key
                next_entry['amount'] = fetch_response['labelNutrients'][label_entry_key]['value']
                extra_labels.remove(label_entry_key)
        if fraction > 0 and next_entry['amount'] == 'UNKNOWN':
            next_entry['amount'] = entry['amount'] * fraction
            next_entry['calculated'] = True
        next_entries.append(next_entry)

    print("Nutrients Per 100g:")
    for entry in fetch_response['foodNutrients']:
        name = entry['nutrient']['name']
        unit = entry['nutrient']['unitName']
        amount = entry['amount']
        print(f"    {name} - {amount} {unit}")
    print("")

    print("Nutrients Per Serving (on Label):")
    for entry in next_entries:
        if entry['calculated']:
            print(f"    {entry['name']} ({entry['usda_name']}) - {entry['amount']} {entry['unit']} (C)")
        else:
            print(f"    {entry['name']} ({entry['usda_name']}) - {entry['amount']} {entry['unit']}")
    print("")

    print(f"Extra Labels: {extra_labels}")
    print("")
