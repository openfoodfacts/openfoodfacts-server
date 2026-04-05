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
    obj = {'query': upc}

    if args.verbose:
        print(f"fetching {usda_url} with data: {obj}")

    resp = requests.post(usda_url, json = obj)

    status = resp.status_code
    if status != 200:
        raise Exception(f"Status {status} returned from USDA search for gtinUPC ({upc}).")

    return  json.loads(str(resp.text))


def fetch_via_fdcid(fdcid):

    usda_url = f"https://api.nal.usda.gov/fdc/v1/food/{fdcid}?format=full&api_key={cfg['API_KEY']}"

    if args.verbose:
        print(f"fetching {usda_url}")

    resp = requests.get(usda_url)

    status = resp.status_code
    if status != 200:
        raise Exception(f"Status {status} returned from USDA fetch by fdcId ({fdcid}).")

    return  json.loads(str(resp.text))


def fetch_via_off(barcode):

    off_url = f"https://world.openfoodfacts.org/api/v3/product/{barcode}"

    if args.verbose:
        print(f"fetching: {off_url}")

    resp = requests.get(off_url)

    status = resp.status_code
    if status != 200:
        return {}
    else:
        return json.loads(str(resp.text))


off_name_for_usda = {
    'Calcium, Ca': ['calcium'],
    'Carbohydrate, by difference': ['carbohydrates'],
    'Cholesterol': ['cholesterol'],
    'Energy': ['energy', 'calories'], # 'energy-kcal' ???
    'Fatty acids, total monounsaturated': ['monounsaturated-fat'],
    'Fatty acids, total polyunsaturated': ['polyunsaturated-fat'],
    'Fatty acids, total saturated': ['saturated-fat'],
    'Fatty acids, total trans': ['trans-fat'],
    'Fiber, total dietary': ['fiber'],
    'Iron, Fe': ['iron'],
    'Pantothenic acid': ['pantothenic-acid'],
    'Potassium, K': ['potassium'],
    'Protein': ['protein', 'proteins'],
    'Sodium, Na': ['sodium'],
    'Sugars, added': ['addedSugar', 'sugars'],
    'Sugars, total including NLEA': ['sugars'],
    'Thiamin': ['thiamin'],
    'Total lipid (fat)': ['fat'],
    'Vitamin B-6': ['vitamin-b6'],
    'Vitamin D (D2 + D3), International Units': ['vitamin-d'],
    'Vitamin D (D2 + D3)': ['vitamin-d'],
    'Zinc, Zn': ['zinc']
}

if __name__ == '__main__':

    if not exists('.env'):
        raise Exception("A .env file must exist with an API_KEY value for the USDA fetch.")

    args = arguments()

    upc = args.upc

    search_response = search_via_upc(args.upc)

    if args.verbose:
        print("search response")
        pprint(search_response)

    if len(search_response['foods']) == 0:

        print(f"\nNo food found in search of USDA for ({args.upc})\n")
        fdcId = None

    else:
        print(f"\nsearch located fdcId: {search_response['foods'][0]['fdcId']}\n")

        fdcId = search_response['foods'][0]['fdcId']
        fetch_response = fetch_via_fdcid(fdcId)

        if args.verbose:
            print("fetch response")
            pprint(fetch_response)

        print(f"Serving size = {fetch_response['servingSize']} {fetch_response['servingSizeUnit']}")

        if fetch_response['servingSizeUnit'] == 'GRM':
            fraction = fetch_response['servingSize'] / 100
        else:
            fraction = -1

    off_response = fetch_via_off(upc)

    if args.verbose:
        print("off response")
        pprint(off_response)

    if off_response == {}:
        print("No OFF product found.")

    if not fdcId:
        quit()

    off_nutrients = list()

    for key in off_response['product']['nutriments']:
        if key.endswith('_100g'):
            off_nutrients.append(key[:-5])

    # if args.verbose:
    print("off_nutrients:")
    pprint(off_nutrients)

    extra_off_nutrients = off_nutrients.copy()

    if 'packageWeight' in fetch_response:
        print(f"Package size = {fetch_response['packageWeight']}")
    print("")

    names = dict()
    searched = dict()
    for search_entry in search_response['foods'][0]['foodNutrients']:
        id = search_entry['nutrientId']
        searched[id] = dict()
        searched[id]['name'] = search_entry['nutrientName']
        searched[id]['unit'] = search_entry['unitName']
        searched[id]['amount'] = search_entry['value']
        names[searched[id]['name']] = id

    fetched = dict()
    for fetch_entry in fetch_response['foodNutrients']:
        id = fetch_entry['nutrient']['id']
        fetched[id] = dict()
        fetched[id]['name'] = fetch_entry['nutrient']['name']
        fetched[id]['unit'] = fetch_entry['nutrient']['unitName']
        fetched[id]['amount'] = fetch_entry['amount']
        names[fetched[id]['name']] = id

    print("")
    print("Nutrient                                             USDA Per 100g         USDA Per Serving       OFF Per Serving")

    snames = sorted(list(names.keys()))

    for name in snames:
        id = names[name]
        if id in searched:
            per100g = f"{searched[id]['amount']} {searched[id]['unit']}"
        else:
            per100g = "MISSING"
        if id in fetched:
            perSrv = f"{fetched[id]['amount']} {fetched[id]['unit']}"
        else:
            perSrv = "MISSING"

        if name in off_name_for_usda:
            for short_name in off_name_for_usda[name]:
                # print(f"checking {short_name} in list?")
                if short_name in off_response['product']['nutriments']:
                    if short_name in extra_off_nutrients:
                        extra_off_nutrients.remove(short_name)
                    amount = off_response['product']['nutriments'][f"{short_name}_value"]
                    unit = off_response['product']['nutriments'][f"{short_name}_unit"]
                    perOFF = f"{amount} {unit}"
                    break
                else:
                    perOFF = "NO SHORT NAME"
                    # print(f"key {short_name} does not appear in list: {list(off_response['product']['nutriments'].keys())}")
        else:
            perOFF = "NO LONG NAME"

        print(f"  {name.ljust(50)}| {per100g.ljust(20)}| {perSrv.ljust(20)}| {perOFF.ljust(20)}|")
        # print(f"  {name.ljust(50)}| {perSrv.ljust(20)}| {perOFF.ljust(20)}|")

    print("")
    print("Extra OFF Nutrients:")
    pprint(extra_off_nutrients)
    print("")
