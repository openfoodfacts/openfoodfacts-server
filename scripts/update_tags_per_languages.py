"""
This Python code: 
 - fetch unknown tags for categories, allergens, etc.
 - check if each unknown tag exists in the taxonomy in different language
 - if yes, to all products having the tag in wrong language:
    - add existing tag in different language 
    - remove tag in wrong language 

- To use a virtual environment (depend on the OS:
  https://python.land/virtual-environments/virtualenv)
```python3.xx -m venv venv```
```source venv/bin/activate```
```pip install requests```

Need to update user_id and password variables before to run the code.

dev mode (dev = True) will:
 - run in .net environment
 - iterate over all tags until one unknown tag is found in the taxonomy (a)
   for a different language.
 - print possible_new_tag, already_referenced_tags, possible_wrong_language_tags
 - iterate over a single product of all products having the tag corresponding to (a)
 - will NOT update the products

- to run tests
```python3 -m unittest update_tags_per_languages_tests.py```


The url used to update products should be updated to corresponding country. 
Otherwise the language of the tags (example: categories_lc) will be updated to "en"
Before to update all products, comment the following part
    post_call_url_res = requests.post(
        post_call_url.format(country=country),
        data=data,
        headers=headers,
    )
    if post_call_url_res.status_code != 200:
        print(f"ERROR: when updating product {product['code']}. {post_call_url_res.status_code} status code")
        sys.exit()
and run the code, to be sure that each <tag_plural>_lc of all products 
that should be updated are having a corresponding country in the dictionary 
mapping_languages_countries. If not, it should print similar message:
    "ERROR: when updating product 8850718818921. Unknown country for this language: th"
"""

import requests
import os
import re
import sys

# define parameters
map_tags_field_url_parameter = {
    # tag field in API, file name in taxonomies: url parameter
    # "allergens": "allergen",
    # "brands": "brand", # all unknown for now (no taxonomy for it)
    "categories": "category",
    # "countries": "country",
    # "labels": "label",
    # "origins": "origin", 
}

dev = True
if dev:
    env = "net"
    user = "off:off@" 
else:
    env = "org"
    user = "" 

headers = {
    'Accept': 'application/json', 
    'User-Agent': 'UpdateTagsLanguages',
}
data = {
    'user_id': '',
    'password': '',
}

logs_file = "update_tags_per_languages_logs"
if os.path.isfile(logs_file):
    os.remove(logs_file)

mapping_languages_countries = {
    "aa": "dj",
    "ar": "world",  # ar but categories are en:<french name> 
    "be": "by",
    "bg": "bg",
    "br": "fr",
    "bs": "ba",
    "ca": "fr",
    "cs": "cz",
    "da": "dk",
    "de": "de",
    "el": "gr",
    "en": "world",
    "xx": "world", # xx but categories are en:<french name>
    "es": "es",
    "et": "ee",
    "fa": "ir",
    "fi": "fi",
    "fr": "fr",
    "hr": "hr",
    "id": "id",
    "is": "is",
    "it": "it",
    "ja": "jp",
    "lt": "lt",
    "ms": "my",
    "nb": "no",
    "nl": "nl",
    "pl": "pl",
    "pt": "pt",
    "ro": "ro",
    "ru": "ru",
    "sk": "sk",
    "sl": "si",
    "sr": "rs",
    "sv": "se",
    "th": "th",
    "zh": "cn",
}

def get_from_api(get_call_url: str) -> dict:
    """Send a GET request to the given URL.
    
    :param get_call_url: the URL to send the request to

    :return: the API response
    stop the code if returned status_code is different than 200
    """
    get_call_url_res = requests.get(
        get_call_url,
        headers=headers,
    )

    if get_call_url_res.status_code != 200:
        print(f"ERROR: when calling api. {get_call_url_res.status_code} status code. url: {get_call_url}")
        sys.exit()
    
    return get_call_url_res.json()


def unknown_tags_taxonomy_comparison(all_tags: dict, file: str, tag_type: str) -> dict:
    """Iterate over all referenced tags, filter unknowns tags, and search in taxonomy

    :param all_tags: all_tags as returned by API call
    :param file: path of the corresponding taxonomy file
    :param tag_type: the current tag type (category, allergens, etc.). Used to save output file

    :return: possible_wrong_language_tags {"old_tag": "tag_found_in_different_lang"}
    """
    possible_new_tags = []
    possible_wrong_language_tags = {}
    already_referenced_tags = []

    for tag in all_tags["tags"]:
        if tag["known"] == 0:
            # limit number of iterations
            if dev and len(possible_wrong_language_tags) > 0:
                break

            tag_name = tag['name']
            # should retrieve all "en:blablabla, tag_name" or "it:tag_name"
            tag_regex = re.compile(f'\n([a-z][a-z]:(?:[\w\s\-\']*\,-)*{tag_name})[,|\n]')

            with open(file, "r") as f:

                tag_regex_res = tag_regex.findall(f.read().lower().replace(" ", "-", -1))
                print(tag_regex_res)

                # found more than a single occurence in the taxonomy
                # if exists, take value that correspond to "en" (i.e., unknown but 
                #   already referenced in the taxonomy)
                # otherwise (i.e., only different languages than "en"), keep first occurence
                if len(tag_regex_res) > 1:
                    # in the case that "en" is not in the list
                    tag_regex_res_first = tag_regex_res[0]
                    
                    tag_regex_res = [x for x in tag_regex_res if "en:" in x]

                    # "en" was not in the last put back first value in the list
                    if not tag_regex_res:
                        tag_regex_res.append(tag_regex_res_first)

                # got one occurence in the taxonomy
                if len(tag_regex_res) == 1:
                    # world is in "en", hence if the tag is found in the taxonomy for "en" line,
                    # it means that the tag is already referenced in the taxonomy
                    if tag_regex_res[0][:2] == "en":
                        already_referenced_tags.append(tag['id'])
                    else:
                        possible_wrong_language_tags[tag['id']] = tag_regex_res[0].split(',')[0]


                # 0 occurences
                else:
                    possible_new_tags.append(tag['id'])


    # print (for dev only) and save results of possible new tags in a file
    if dev:
        print(f"> Possible new tags for {tag_type}: <")
        for possible_new_tag in possible_new_tags:
            print("  ", possible_new_tag)

        print(f"> Already referenced tags for {tag_type}: <")
        for known_tag in already_referenced_tags:
            print("  ", known_tag)

        print(f"> Tags to update for {tag_type} (current => new): <")
        for current_tag, updated_tag in possible_wrong_language_tags.items():
            print(f"  {current_tag} => {updated_tag}")

    # only save possible new tags to be reviewed and added
    with open("update_tags_per_languages_possible_new_tags_" + tag_type, "w") as f:
        f.write("possible_new_tags")
    with open("update_tags_per_languages_possible_new_tags_" + tag_type, "a") as f:
        for possible_new_tag in possible_new_tags:
            f.write("\n" + possible_new_tag) 

    return possible_wrong_language_tags


def update_tags_field(tags_field_string: str, tags_field_lc: str, current_tag: str, updated_tag: str) -> str:
    """Iterate over all referenced tags, filter unknowns tags, and search in taxonomy

    :param tags_field_string: the current tags_field before to replace the tag
    :param tags_field_lc: the language of tags_field_string
    :param current_tag: tag to replace
    :param updated_tag: updated tag

    :return tags_field_string: updated tags_field_string
    """

    # language of the tags_field_string is the same as the language 
    # of the current tag that we want to remove, 
    # it will not be prefixed by the language.
    if tags_field_lc == current_tag[:2]:
        current_tag = current_tag.split(':')[1]
    # same if new tag is the same as the language
    if tags_field_lc == updated_tag[:2]:
        updated_tag = updated_tag.split(':')[1]
    
    # convert into list to better handle upper and lower cases, split and concatenation, spaces
    tags_fields = tags_field_string.split(",")
    # can contain upper case letters
    # create new list list as lower case - and remove space after commas (strip) - to get the index
    tags_fields_lower = [x.lower().strip().replace(" ", "-", -1) for x in tags_fields]

    # old tag is still in the field
    if current_tag in tags_fields_lower:
        index = tags_fields_lower.index(current_tag)
        # updated tag is not yet in the field
        # replace current tag by updated tag
        if updated_tag not in tags_fields_lower:
            # add space if the tag is not the first one in the string "do-not-add-space, add-space"
            if index != 0:
                tags_fields[index] = f" {updated_tag}"
            else:
                tags_fields[index] = f"{updated_tag}"
        # updated tag is already in the field
        # delete only instead of updating
        else:
            del tags_fields[index]
    # old tag is not in the field
    else:
        # updated tag is not yet in the field
        # add updated tag
        if updated_tag not in tags_fields_lower:
            # add space if the tag is not the first one in the string "do-not-add-space, add-space"
            if tags_field_string != "":
                tags_fields.append(f" {updated_tag}")
            else:
                tags_fields.append(f"{updated_tag}")
        # final case, current tag missing and updated tag already in the field
        # is equivalent to leave the field as is

    tags_field_string = ",".join(tags_fields)
    
       
    return tags_field_string


def main():
    for plural, singular in map_tags_field_url_parameter.items():
        # 0) set variables
        tags_list_url = f"https://{user}world.openfoodfacts.{env}/{plural}.json"
        
        # by default the query return 24 results. 
        # increase to 1000 (so far chips in EN (should be crisps in EN)
        #   had max number of products for categories with ~550)
        products_list_for_tag_url = f"https://{user}world.openfoodfacts.{env}/{singular}/{{tag_id_placeholder}}.json?page_size=1000"
        
        file = os.path.abspath(os.path.join(os.path.dirname( __file__ ), '..', f'taxonomies/{plural}.txt')) 
        
        # country is needed otherwise <plural>_lc will be "en"
        post_call_url = f"https://{user}{{country}}.openfoodfacts.{env}/cgi/product_jqm2.pl"


        # 1) get all tags
        all_tags = get_from_api(tags_list_url)
        # example:
        #  all_tags = {
        #      "tags": [
        #          {"id": "it:frankreich", "known": 0, "name": "frankreich", ...}, 
        #      ],
        #  }

        # 2) fetch unknown tags and look into taxonomy
        possible_wrong_language_tags = unknown_tags_taxonomy_comparison(all_tags, file, plural)

        # limit number of iterations
        # for dev, number of elements in possible_wrong_language_tags 
        #   can be changed in unknown_tags_taxonomy_comparison()
        for current_tag, updated_tag in possible_wrong_language_tags.items():

            # 3) get all products for this tag 
            all_products_for_tag = get_from_api(products_list_for_tag_url.format(tag_id_placeholder=current_tag))
            # example:
            #  all_products_for_tag = {
            #      "products": [
            #          {"categories": "Lait", "categories_lc": "en", ...}, 
            #      ],
            #  }

            if dev:
                i = 0
            for product in all_products_for_tag["products"]:
                if dev:
                    if i > 0:
                        break
                    i += 1

                # 4) update tags_fields 
                updated_field = update_tags_field(product[plural], product[f'{plural}_lc'], current_tag, updated_tag)
                
                # 5) finally, update
                if updated_field != product[plural] and not dev:

                    # country is needed otherwise <plural>_lc will be "en"
                    try:
                        country = mapping_languages_countries[product[f'{plural}_lc']]
                    except KeyError:
                        print(f"ERROR: when updating product {product['code']}. Unknown country for this language: {product[f'{plural}_lc']}")
                        sys.exit()

                    data = {
                        'code': product['code'], 
                        plural: updated_field,
                    }
                    post_call_url_res = requests.post(
                        post_call_url.format(country=country),
                        data=data,
                        headers=headers,
                    )
                    if post_call_url_res.status_code != 200:
                        print(f"ERROR: when updating product {product['code']}. {post_call_url_res.status_code} status code")
                        sys.exit()

                with open(logs_file, "a") as f:
                    f.write(f"{product['code']},{plural};{current_tag};{updated_tag}\n") 


if __name__ == "__main__":
    main()
