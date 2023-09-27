
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
        with open('USDA_fdc_categories.csv', newline='') as csvfile:
            reader = csv.DictReader(csvfile)
            for row in reader:
                categories[row['fdc_category']] = row
    return categories[name]

def create_off(gtinUpc):

    usda_url = f"https://api.nal.usda.gov/fdc/v1/foods/search?api_key={cfg['API_KEY']}"
    obj = {'query': gtinUpc}

    r = requests.post(usda_url, json = obj)

    status = r.status_code
    output = r.text
    j_output = json.loads(str(output))

    print("-------------------------")
    print(f"status: {status}")
    print("-------------------------")

    food = j_output['foods'][0]
    print("USDA data:")
    pprint(food)

    serving_size = food['servingSize']
    serving_size_unit = food['servingSizeUnit']

    print("-------------------------")

    off_data = dict()
    off_data['product'] = dict()

    product = off_data['product']

    product['sources_fields'] = dict()
    product['sources_fields']['org-database-usda'] = dict()

    usda = product['sources_fields']['org-database-usda']
    usda['fdc_category'] = food['foodCategory']
    usda['fdc_data_source'] = 'LI' # ????
    usda['fdc_id'] = food['fdcId']
    usda['available_date'] = None # ????
    usda['modified_date'] = food['modifiedDate']
    usda['published_date'] = food['publishedDate']

    if len(food['gtinUpc']) == 12:
        product['code'] = f"0{food['gtinUpc']}"
        product['code_tags'] = list()
        product['code_tags'].append('code-13')
        for x in reversed(range(1, 11)):
            next_code = product['code'][:x]
            while len(next_code) < 13:
                next_code = f"{next_code}X"
            product['code_tags'].append(next_code)

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

    nutrients = food['foodNutrients']

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
            product['nutriments'][f"{prefix}_100g"] = usda_nutrient['value'] / 100
        if unit == 'mg':
            product['nutriments'][f"{prefix}_100g"] = usda_nutrient['value'] / 10

        product['nutriments'][f"{prefix}_unit"] = usda_nutrient['unitName']

    return product


if __name__ == '__main__':

    # not_founds = ['619128673216, '8056446910016', '3800231791176', '3800231791206',
    #               '3800231791190', '3800231791183', '772065760129',
    #               '628834166633', '628055222231', '628055222217', '628055222323']

    not_founds = ['619128673216']

    for not_found in not_founds:
        p = create_off('619128673216')
        print("OFF data:")
        pprint(p)
        print("-------------------------")
