"""
This Python code: 
 - fetch unknown tags for categories, allergens, etc.
 - check if each unknown tag exists in the taxonomy in different language
 - if yes, to all products having the tag in wrong language:
    - add existing tag in different language 
    - remove tag in wrong language 
 - at the end there should be 3 output files: 
   - possible new tags (not in the taxonomy at all)
   - all tags found in different language
   - all updated products
 - if the script is interrupted, rerunning it should resume where it stopped

- To use a virtual environment (depend on the OS:
  https://python.land/virtual-environments/virtualenv)
```python3.xx -m venv venv```
```source venv/bin/activate```
```pip install requests```

- run the code with:
```python3 update_tags_per_languages.py --tags "categories,countries" --env dev --user_id "" --password ""```

dev mode (--env=dev) will:
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

import argparse
import requests
import os
import re
import sys


log_file_name_1 = "update_tags_per_languages_wrong_languages_detected_{plural}"
log_file_name_2 = "update_tags_per_languages_wrong_languages_updated_{plural}"
output_file_name = "update_tags_per_languages_possible_new_tags_{plural}"

map_tags_field_url_dic = {
    # tag field in API, file name in taxonomies: url parameter
    "allergens": "allergen",
    # "brands": "brand", # all unknown for now (no taxonomy for it)
    "categories": "category",
    "countries": "country",
    "labels": "label",
    "origins": "origin",
}

headers = {
    'Accept': 'application/json',
    'User-Agent': 'UpdateTagsLanguages',
}

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
    "xx": "world",  # xx but categories are en:<french name>
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
        print(f"ERROR: when calling api. {
              get_call_url_res.status_code} status code. url: {get_call_url}")
        sys.exit()

    return get_call_url_res.json()


def unknown_tags_taxonomy_comparison(api_result: dict, taxonomy_file_location: str, tag_type: str, dev: bool) -> None:
    """Iterate over all referenced tags, filter unknowns tags, and search in taxonomy. Save results in a file.

    :param api_result: api_result as returned by API call
    :param taxonomy_file_location: path of the corresponding taxonomy file
    :param tag_type: the current tag type (category, allergens, etc.). Used to save output file
    :param dev: boolean, dev=True will not process all data

    :return: None
    """
    possible_new_tags = []
    possible_wrong_language_tags = {}
    already_referenced_tags = []

    with open(taxonomy_file_location, "r") as taxonomy_file:
        taxonomy_file_content = taxonomy_file.read().lower().replace(" ", "-", -1)

    all_tags = api_result["tags"]

    # if file exists already, resume interrupted job, otherwise start from the beginning
    if os.path.exists(log_file_name_1.format(plural=tag_type)):
        # retrieve last saved log
        with open(log_file_name_1.format(plural=tag_type), 'r') as read_log:
            for line in read_log:
                pass
            # line is the last line
            last_tag = line.split(",")[0]

        # found the index of the last saved log
        last_tag_index = None
        for i, item in enumerate(all_tags):
            if item['id'] == last_tag:
                last_tag_index = i
                break

        # remove all tags already in the logs, to restart AFTER (i.e., +1) last log
        if last_tag_index is not None:
            all_tags = all_tags[last_tag_index+1:]
            log_file_1 = open(log_file_name_1.format(plural=tag_type), "a")
        # not found, restart from the beginning
        else:
            log_file_1 = open(log_file_name_1.format(plural=tag_type), "w")
            log_file_1.write("current tag, <language>:found tag")
    # no file, start from the beginning
    else:
        log_file_1 = open(log_file_name_1.format(plural=tag_type), "w")
        log_file_1.write("current tag, <language>:found tag")

    for tag in all_tags:
        if tag["known"] == 0:
            # limit number of iterations
            if dev and len(possible_wrong_language_tags) > 0:
                break

            tag_name = tag['name']
            # should retrieve all "en:blablabla, tag_name" or "it:tag_name"
            # the prefix is either the language or a comma.
            # Suffix is either an end of line or a comma
            tag_regex = re.compile(
                f'\n([a-z][a-z]:(?:[\w\s\-\']*\,-)*{tag_name})[,|\n]')

            tag_regex_res = tag_regex.findall(taxonomy_file_content)

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
                    possible_wrong_language_tags[tag['id']] = tag_regex_res[0].split(',')[
                        0]
                    # save in the logs to ease resume if it crashes
                    log_file_1.write(f"\n{tag['id']},{
                                     tag_regex_res[0].split(',')[0]}")
                    log_file_1.flush()
            # 0 occurences
            else:
                possible_new_tags.append(tag['id'])

    log_file_1.close()

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
    with open(output_file_name.format(plural=tag_type), "a") as output_possible_new_tag_file:
        output_possible_new_tag_file.write("possible_new_tags")
        for possible_new_tag in possible_new_tags:
            output_possible_new_tag_file.write("\n" + possible_new_tag)

    return


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
    tags_fields_lower = [x.lower().strip().replace(" ", "-", -1)
                         for x in tags_fields]

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
    parser = argparse.ArgumentParser(
        description="Provide tags type (allergens, categories, countries, labels, origins). Also, provide environment (prod, dev), user and password")
    parser.add_argument('--tags', required=True,
                        help='tags type (allergens, categories, countries, labels, origins). Comma separated, and quotes')
    parser.add_argument('--env', required=True,
                        help='environment (prod, dev) to connect to openfoodfacts')
    parser.add_argument(
        '--user_id', help='user id to connect to openfoodfacts')
    parser.add_argument(
        '--password', help='password to connect to openfoodfacts')
    args = parser.parse_args()
    tags = args.tags.split(",")
    tags = [i.strip() for i in tags]
    env = args.env

    map_tags_field_url_parameter = {}
    for tag in tags:
        if tag in map_tags_field_url_dic:
            map_tags_field_url_parameter[tag] = map_tags_field_url_dic[tag]
        else:
            print("This tag is not known:", tag, file=sys.stderr)
            sys.exit()

    if env == "prod":
        dev = False
        env = "org"
        user = ""
    elif env == "dev":
        dev = True
        env = "net"
        user = "off:off@"
    else:
        print("Environment should be 'prod' or 'dev', unexpected value:",
              env, file=sys.stderr)
        sys.exit()

    for plural, singular in map_tags_field_url_parameter.items():
        # 0) set variables
        tags_list_url = f"https://{user}world.openfoodfacts.{env}/{plural}.json"
        # reinitialize for each loop because "plural" is added below, hence, we need to remove it for the next item
        data = {
            'user_id': args.user_id,
            'password': args.password,
        }

        # by default the query return 24 results.
        # increase to 1000 (so far chips in EN (should be crisps in EN)
        #   add max number of products for categories with ~550)
        products_list_for_tag_url = f"https://{user}world.openfoodfacts.{
            env}/{singular}/{{tag_id_placeholder}}.json?page_size=1000"

        taxonomy_file_location = os.path.abspath(os.path.join(
            os.path.dirname(__file__), '..', f'taxonomies/{plural}.txt'))

        # country is needed otherwise <plural>_lc will be "en"
        post_call_url = f"https://{user}{{country}}.openfoodfacts.{
            env}/cgi/product_jqm2.pl"

        # if log_file_name_2 exists, it means step 1) and 2) completely ran already, hence, resume from step 3)
        if not os.path.exists(log_file_name_2.format(plural=plural)):
            # 1) get all tags
            api_result = get_from_api(tags_list_url)
            # example:
            #  api_result = {
            #      "tags": [
            #          {"id": "it:frankreich", "known": 0, "name": "frankreich", ...},
            #      ],
            #  }

            # 2) fetch unknown tags and look into taxonomy
            unknown_tags_taxonomy_comparison(
                api_result, taxonomy_file_location, plural, dev)

            # create second log file
            with open(log_file_name_2.format(plural=plural), "w"):
                pass

        # retrieve result of the previous step
        possible_wrong_language_tags = {}
        with open(log_file_name_1.format(plural=plural), 'r') as log_file_1:
            # skip header
            log_file_1.readline()
            possible_wrong_language_tags = dict(
                line.strip().split(',', 1) for line in log_file_1
            )

        resume = False
        if os.path.getsize(log_file_name_2.format(plural=plural)) != 0:
            # retieve last saved log
            with open(log_file_name_2.format(plural=plural), 'r') as log_file_2:
                # include header, see next condition
                for line in log_file_2:
                    pass

            # line is the last line
            if line != "current tag, updated tag, product code":
                last_tag, last_product = line.split(",")[0], line.split(",")[2]
                # remove from possible_wrong_language_tags the product that were already updated,
                # we keep last tag because maybe all products were not updated in previous run
                sorted_dict = dict(
                    sorted(possible_wrong_language_tags.items()))
                possible_wrong_language_tags = {
                    k: v for k, v in sorted_dict.items() if k >= last_tag}
                resume = True
            # only header was in the file, restart from beginning
            else:
                with open(log_file_name_2.format(plural=plural), "w") as log_file_2:
                    log_file_2.write("current tag, updated tag, product code")

        # file exists and is empty
        else:
            with open(log_file_name_2.format(plural=plural), "w") as log_file_2:
                log_file_2.write("current tag, updated tag, product code")

        # limit number of iterations
        # for dev, number of elements in possible_wrong_language_tags
        #   can be changed in unknown_tags_taxonomy_comparison()
        for current_tag, updated_tag in possible_wrong_language_tags.items():

            # 3) get all products for this tag
            all_products_for_tag = get_from_api(products_list_for_tag_url.format(
                tag_id_placeholder=current_tag))["products"]
            # example:
            #  all_products_for_tag = {
            #      "products": [
            #          {"categories": "Lait", "categories_lc": "en", ...},
            #      ],
            #  }

            # if it is resuming, ignore already updated products
            if resume:
                if current_tag == last_tag:
                    # found the index of the last saved log
                    last_product_tag_index = None
                    for i, item in enumerate(all_products_for_tag):
                        if item['_id'] == last_product:
                            last_product_tag_index = i
                            break

                    # remove all tags already in the logs
                    if last_product_tag_index is not None:
                        all_products_for_tag = all_products_for_tag[last_product_tag_index]
                    # else, not found, will restart from the beginning

            for i, product in enumerate(all_products_for_tag):
                if dev and i > 0:
                    break

                # 4) update tags_fields
                updated_field = update_tags_field(
                    product[plural], product[f'{plural}_lc'], current_tag, updated_tag)

                # 5) finally, update
                if updated_field != product[plural] and not dev:

                    # country is needed otherwise <plural>_lc will be "en"
                    try:
                        country = mapping_languages_countries[product[f'{
                            plural}_lc']]
                    except KeyError:
                        print(f"ERROR: when updating product {
                              product['code']}. Unknown country for this language: {product[f'{plural}_lc']}")
                        sys.exit()

                    data.update({
                        'code': product['code'],
                        plural: updated_field,
                    })
                    post_call_url_res = requests.post(
                        post_call_url.format(country=country),
                        data=data,
                        headers=headers,
                    )
                    if post_call_url_res.status_code != 200:
                        print(f"ERROR: when updating product {product['code']}. {
                              post_call_url_res.status_code} status code")
                        sys.exit()

                with open(log_file_name_2.format(plural=plural), "a") as log_file_2:
                    log_file_2.write(f"\n{current_tag},{
                                     updated_tag},{product['code']}")
                    log_file_2.flush()

    # finally, rename log files, next iteration should start from scratch
    os.rename(log_file_name_1.format(plural=plural),
              log_file_name_1.format(plural=plural) + "_log")
    os.rename(log_file_name_2.format(plural=plural),
              log_file_name_2.format(plural=plural) + "_log")


if __name__ == "__main__":
    main()
