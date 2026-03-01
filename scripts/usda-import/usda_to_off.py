
import csv
import json
from pprint import pprint

import requests
from dotenv import dotenv_values


def cfg() -> dict:
    d = dotenv_values(".env")
    return d

cfg = cfg()

usda_to_off_names = {
    'Calcium, Ca': 'calcium',
    'Carbohydrate, by difference': 'carbohydrates',
    'Cholesterol': 'cholesterol',
    'Energy': 'energy',
    'Fatty acids, total saturated': 'saturated-fat',
    'Fatty acids, total trans': 'trans-fat',
    'Fiber, total dietary': 'fiber',
    'Iron, Fe': 'iron',
    'Protein': 'proteins',
    'Salt': 'salt',
    'Sodium, Na': 'sodium',
    'Sugars, total including NLEA': 'sugars',
    'Total lipid (fat)': 'fat',
    'Vitamin A, IU': 'vitamin-a',
    'Vitamin C, total ascorbic acid': 'vitamin-c'

}

nutrient_extras = [
    '',
    'trans-fat',
    '_serving',
    '_unit',
    '_value'
]

categories = dict()

def category(name):
    global categories
    if len(categories) == 0:
        with open('/home/ray/Projects/OFF/usda/USDA_fdc_categories.csv', newline='') as csvfile:
            reader = csv.DictReader(csvfile)
            for row in reader:
                categories[row['fdc_category']] = row
    return categories[name]

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


def generate_code_tags_list(upc):
    result = list()
    if len(upc) == 13:
        result.append('code-13')
        for x in reversed(range(1, 11)):
            next_code = upc[:x]
            while len(next_code) < 13:
                next_code = f"{next_code}X"
            result.append(next_code)
        return result
    raise Exception("What should I do here if the UPC is not length 13?")


def upc_to_barcode(upc):
    """
    Note: On Open Food Facts, when you import a code of 14, you delete the 1st 0
    on the left. When you have a UPC 12, add a 0.  If the code is 14 characters
    long, we import it as is.
    """
    result = dict()

    # print(f"upc_to_barcode:: upc: {upc}")

    if len(upc) == 12:
        result['code'] = f"0{upc}"
        result['code_tags'] = generate_code_tags_list(result['code'])

    if len(upc) == 13:
        result['code'] = upc
        result['code_tags'] = generate_code_tags_list(result['code'])

    if len(upc) == 14:
        if upc.startswith('0'):
            result['code'] = f"{upc[1:]}"
            result['code_tags'] = generate_code_tags_list(result['code'])

    '''
    Codes starting with 9 → would correspond to products with variable weights.
    Ok to import them as they are.
    What? Where do these appear? What is their length?
    '''
    return result


def create_off(gtinUpc):

    search_output = search_via_upc(gtinUpc)
    # print(f"search_output: {search_output}")

    food = search_output['foods'][0]

    fetch_output = fetch_via_fdcid(food['fdcId'])
    # print(f"fetch_output: {fetch_output}")

    serving_size = food['servingSize']
    serving_size_unit = food['servingSizeUnit']

    off_data = dict()
    off_data['product'] = dict()

    product = off_data['product']

    product['sources_fields'] = dict()

    '''
    The org used for the import must be org-database-usda
    because there is special treatment for orgs starting with org-database-xxxx
    '''
    product['sources_fields']['org-database-usda'] = dict()

    usda = product['sources_fields']['org-database-usda']
    usda['fdc_category'] = food['foodCategory']
    usda['fdc_data_source'] = 'LI' # ????
    usda['fdc_id'] = food['fdcId']
    usda['available_date'] = "0000-00-00" # ????
    usda['modified_date'] = food['modifiedDate']
    usda['published_date'] = food['publishedDate']

    # add the barcode and the 'code_tags' list here.
    product = product | upc_to_barcode(food['gtinUpc'])

    product['ingredients_text'] = food['ingredients']
    product['ingredients_text_en'] = food['ingredients']

    product['categories_tags'] = list()
    product['categories_tags'].append(category(usda['fdc_category'])['category'])

    product['serving_size'] = f"{serving_size} {serving_size_unit}"

    if serving_size_unit != 'g':
        # raise Exception(f"What unit are we using? unit = {serving_size_unit}")
        print(f"ERROR What unit are we using? unit = {serving_size_unit}")
    else:
        product['serving_quantity'] = serving_size

    product['nutriments'] = dict()

    # If we have value = 40, that is per 100g. Say that serving is 29 gram.
    # Then the amount per serving in grams is (40 * 29) / 100.

    for usda_nutrient in food['foodNutrients']:
        name = usda_nutrient['nutrientName']
        prefix = usda_to_off_names[name]

        unit = usda_nutrient['unitName'].lower()

        product['nutriments'][f"{prefix}_value"] = usda_nutrient['value']
        product['nutriments'][f"{prefix}_serving"] = usda_nutrient['value']
        if unit == 'g':
            calculated = usda_nutrient['value'] / 100
            if calculated == int(calculated):
                calculated = int(calculated)
            product['nutriments'][f"{prefix}_100g"] = calculated

        if unit == 'mg':
            calculated = usda_nutrient['value'] / 10
            if calculated == int(calculated):
                calculated = int(calculated)
            product['nutriments'][f"{prefix}_100g"] = calculated

        product['nutriments'][f"{prefix}_unit"] = usda_nutrient['unitName']

    return product


if __name__ == '__main__':

    '''
    Find foods in the USDA database that do not appear in OFF. Import them.
    '''

    '''
    Find foods in the USDA database that are more up-to-date (determined how?)
    than the OFF foods and update them with USDA information.
    '''

    # Be done.
