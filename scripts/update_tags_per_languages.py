"""
This Python code: 
 - fetch unknown tags for categories, allergens, etc.
 - check if each unknown tag exists in the taxonomy in different language
 - if yes, to all products having the tag in wrong language:
    - add existing tag in different language 
    - remove tag in wrong language
 - if the script is interrupted, rerunning it should resume where it stopped

- To use a virtual environment (depend on the OS:
  https://python.land/virtual-environments/virtualenv)
```python3.xx -m venv venv```
```source venv/bin/activate```
```pip install requests```

- run the code with:
```python3 update_tags_per_languages.py --tags "categories,countries" \
    --env dev --user_id "" --password "" [--debug 10]```

- to run tests
```python3 -m unittest update_tags_per_languages_tests.py```


The url used to update products should be updated to corresponding country. 
Otherwise the language of the tags (example: categories_lc) will be updated 
to "en"
Before to update all products, comment the part under:
"comment following lines to test the code only"
and run the code, to be sure that each <tag_plural>_lc of all products 
that should be updated are having a corresponding country in the dictionary 
mapping_languages_countries. If not, it should print similar message:
    "ERROR: when updating product 8850718818921. Unknown country for this 
    language: th"
"""

import argparse
import requests
import os
import polars as pl
import re
import sys
import dbm
import time

file_unknown = "update_tags_per_languages_{plural}"
file_other_lc = "update_tags_per_languages_{plural}_exist"
file_other_lc_all_products = "update_tags_per_languages_{plural}_exist_all"
file_updated_products = "update_tags_per_languages_{plural}_exist_all_updated"
file_new = "update_tags_per_languages_{plural}_new"
file_new_count = "update_tags_per_languages_{plural}_new_count"
file_to_update = "update_tags_per_languages_{plural}_to_udpate"
file_to_update_count = "update_tags_per_languages_{plural}_to_udpate_count"
file_dbm = "update_tags_per_languages_dbm"

map_tags_field_url_dic = {
    # tag field in API, file name in taxonomies: url parameter
    # "allergens": "allergen", # cannot update allergens but traces instead
    # "brands": "brand", # all unknown for now (no taxonomy for it)
    "categories": "category",
    "countries": "country",
    "labels": "label",
    "origins": "origin", 
    # "ingredients": "ingredient" # not handled, it is a list not a string
    "traces": "trace", 
}

headers = {
    'Accept': 'application/json', 
    'User-Agent': 'UpdateTagsLanguages',
}

# <- language code <- : -> country code ->
mapping_languages_countries = {
    "aa": "dj",
    "af": "za",
    "ar": "world",  # ar but categories are en:<french name> 
    "ba": "ru",
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
    "eo": "world",
    "xx": "world", # xx but categories are en:<french name>
    "es": "es",
    "et": "ee",
    "fa": "ir",
    "fi": "fi",
    "fr": "fr",
    "gd": "gb",
    "gl": "es",
    "he": "il",
    "hr": "hr",
    "hu": "hu",
    "id": "id",
    "is": "is",
    "it": "it",
    "ja": "jp",
    "lt": "lt",
    "lv": "lv",
    "ms": "my",
    "nb": "no",
    "no": "no",
    "nl": "nl",
    "pl": "pl",
    "pt": "pt",
    "ro": "ro",
    "ru": "ru",
    "sk": "sk",
    "sl": "si",
    "sq": "al",
    "sr": "rs",
    "sv": "se",
    "th": "th",
    "ti": "et",
    "tr": "tr",
    "ug": "cn",
    "uk": "world",
    "uz": "uz",
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
        print(f"ERROR: when calling api. {get_call_url_res.status_code} "
              f"status code. url: {get_call_url}")
        sys.exit()
    

    return get_call_url_res.json()


def get_all_unknown(tags_list_url: str, tag_type: str, debug: 
                    int=None) -> None:
    """Send a GET request to the given URL.
    
    :param tags_list_url: the URL to send the request to
    :param tag_type: the tag type (countries, labels, etc.)
    :param debug: optional, interrupt queries after having reach number 
    provided
    """
    file_name_end = file_unknown.format(plural=tag_type)
    if os.path.exists(file_name_end):
        return

    if os.path.exists(f"{file_name_end}_in_progress"):
        # retrieve last saved log
        with open(f"{file_name_end}_in_progress", 'r') as read_file:
            for line in read_file:
                pass
            # line is the last line
            # first element in the header is not an int
            if line == "page;current tag":
                page_nb = 1
            else:
                page_nb = int(line.split(";")[0])
                remove_lines_with_value(f"{file_name_end}_in_progress", 
                                        page_nb)
            file_end = open(f"{file_name_end}_in_progress", "a")
    else:
        page_nb = 1
        file_end = open(f"{file_name_end}_in_progress", "w")
        file_end.write("page;current tag") 

    # example or response:
    #  api_result = {
    #      "tags": [
    #          {"id": "it:frankreich", "known": 0, "name": "frankreich", ...},
    #      ],
    #  }
    tag_found = 0
    api_result = get_from_api(f"{tags_list_url}?page={page_nb}")
    total_number_of_tags = api_result['count']
    page_tot = total_number_of_tags // 100 + 1
    for tag in api_result["tags"]:
        if tag["known"] == 0:
            tag = tag['id']
            # id: agricultura-no-ue for origin (no country code)
            if ":" not in tag:
                tag = f"en:{tag}"
            file_end.write(f"\n{page_nb};{tag}")
            file_end.flush()
            tag_found += 1
            if debug is not None and tag_found > debug:
                break
    page_nb += 1

    while page_nb < page_tot:
        api_result = get_from_api(f"{tags_list_url}?page={page_nb}")
        for tag in api_result["tags"]:
            if tag["known"] == 0:
                tag = tag['id']
                # id: agricultura-no-ue for origin (no country code)
                if ":" not in tag:
                    tag = f"en:{tag}"
                file_end.write(f"\n{page_nb};{tag}")
                file_end.flush()
                tag_found += 1
                if debug is not None and tag_found > debug:
                    break
        else:
            page_nb += 1
            continue
        break

    file_end.close()
    os.rename(f"{file_name_end}_in_progress", file_name_end)

    # remove duplicates
    df = pl.read_csv(file_name_end, separator=';', has_header=True)
    df_grouped = df.group_by('current tag').agg(pl.col('page').alias('page').str.concat('-'))
    df_no_duplicates = df_grouped.select(['page', 'current tag'])
    df_no_duplicates.write_csv(file_name_end, separator=';')


def unknown_tags_taxonomy_comparison(tag_type: str) -> None:
    """Iterate over all unknown tags, search in the taxonomy.
    Save results in a file if the tag is found in a different language.
    Save results in another file if it is not found (possible new tag).

    :param tag_type: the current tag type (category, allergens, etc.). Used to 
       save output file

    :return: None
    """        
    file_name_end = file_other_lc.format(plural=tag_type)
    if os.path.exists(file_name_end):
        return
    
    if tag_type in ["categories", "ingredients"]:
        taxonomy_file_location = os.path.abspath(os.path.join(os.path \
            .dirname( __file__ ), '..', f'taxonomies/food/{tag_type}.txt'))
    elif tag_type in ["traces"]:
        taxonomy_file_location = os.path.abspath(os.path.join(os.path \
            .dirname( __file__ ), '..', f'taxonomies/allergens.txt'))
    else:
        taxonomy_file_location = os.path.abspath(os.path.join(os.path \
            .dirname( __file__ ), '..', f'taxonomies/{tag_type}.txt'))

    with open(taxonomy_file_location, "r") as taxonomy_file:
        taxonomy_file_content = taxonomy_file.read() \
            .lower().replace(" ", "-", -1)

    with open(file_unknown.format(plural=tag_type), 'r') as previous_file:
        _ = previous_file.readline()
        all_tags_id = previous_file.readlines()
        # keep tag_id only (not the pages of API get calls)
        all_tags_id = [line.split(";")[1].strip() for line in all_tags_id]

    # if file exists already, resume interrupted job, otherwise start from the 
    #   beginning
    if os.path.exists(f"{file_name_end}_in_progress"):
        # retrieve last saved log
        with open(f"{file_name_end}_in_progress", 'r') as output_file_exist:
            for line in output_file_exist:
                pass
            # line is the last line
            last_tag = line.split(";")[0]
        
        # found the index of the last saved log
        last_tag_index = None
        for i, item in enumerate(all_tags_id):
            if item == last_tag:
                last_tag_index = i
                break

        # remove all tags already in the logs from the api response, to 
        #   restart AFTER (i.e., +1) last log
        if last_tag_index:
            all_tags_id = all_tags_id[last_tag_index+1:]
            output_file_exist = open(f"{file_name_end}_in_progress", "a")
            # also resume for file_new
            output_file_new = open(file_new.format(plural=tag_type), "a")
            # also resume for file_to_update
            output_file_to_update = open(file_to_update.format(plural=tag_type), "a")

        # not found, restart from the beginning
        else:
            output_file_exist = open(f"{file_name_end}_in_progress", "w")
            output_file_exist.write("current tag;new tag") 
            output_file_new = open(file_new.format(plural=tag_type), "w")
            output_file_new.write("current tag;new tag") 
            output_file_to_update = open(file_to_update.format(plural=tag_type), "w")
            output_file_to_update.write("current tag;new tag") 
    # no file, start from the beginning
    else:
        output_file_exist = open(f"{file_name_end}_in_progress", "w")
        output_file_exist.write("current tag;new tag") 
        output_file_new = open(file_new.format(plural=tag_type), "w")
        output_file_new.write("current tag;new tag")
        output_file_to_update = open(file_to_update.format(plural=tag_type), "w")
        output_file_to_update.write("current tag;new tag")
    
    for tag_id in all_tags_id:
        tag = tag_id.split(":")[1]

        # should retrieve all "en: blablabla, tag_name" or "it: tag_name"
        # the prefix is either the language or a comma. 
        # Suffix is either an end of line or a comma
        tag_regex = re. \
            compile(f'\n([a-z][a-z]:-(?:[\w\s\-\']*\,-)*{tag})[,|\n]')

        tag_regex_res = tag_regex.findall(taxonomy_file_content)

        # found more than a single occurence in the taxonomy
        # if exists, take value that correspond to "en" (i.e., unknown but 
        #   already referenced in the taxonomy)
        # otherwise (i.e., only different languages than "en"), keep first 
        #   occurence
        if len(tag_regex_res) > 1:
            # in the case that "en" is not in the list
            tag_regex_res_first = tag_regex_res[0]

            # xx: shows in api results as fr:, de:, en: etc. 
            # However they are already known
            universal = [x for x in tag_regex_res if "xx:" in x]
            if universal:
                continue

            tag_regex_res = [x for x in tag_regex_res if "en:" in x]

            # "en" was not in the last put back first value in the list
            if not tag_regex_res:
                tag_regex_res.append(tag_regex_res_first)

        # got one occurence in the taxonomy, or recreated tag_regex_res 
        #   with single element in the previous condition (hence, we have a if
        #   condition below and not an elif condition
        if len(tag_regex_res) == 1:
            # xx: shows in api results as fr:, de:, en: etc. 
            # However they are already known
            universal = [x for x in tag_regex_res if "xx:" in x]
            if universal:
                continue

            # if == "en" it means that the tag from the api response is 
            #   already in the taxonomy because api call is for world, that is 
            #   in "en" if available and if occurence found in the taxonomy is
            #   also in "en", then this tag is known but the product has not 
            #   been updated for some time. Need to update product only
            if tag_regex_res[0][:2] != "en" and \
                tag_regex_res[0][:2] != tag_id[0][:2]:
                existing_tag = tag_regex_res[0] \
                    .split(',')[0].replace(':-', ':')
                output_file_exist.write(f"\n{tag_id};{existing_tag}")
                output_file_exist.flush()

            # tag already in taxonomy. Need to update product only
            if tag_regex_res[0][:2] == "en" or \
                tag_regex_res[0][:2] == tag_id[0][:2]:
                output_file_to_update.write(f"\n{tag_id};")
                output_file_to_update.flush()

        # 0 occurences
        else:
            output_file_new.write(f"\n{tag_id};")
            output_file_new.flush()

    output_file_exist.close()
    output_file_new.close()
    output_file_to_update.close()

    os.rename(f"{file_name_end}_in_progress", file_name_end)

    return


def remove_lines_with_value(file_name: str, value: str) -> None:
    """Given a semi-colon separated file and a value appearing in the first 
    element of some lines in the file, this function remove all lines having 
    the given value. 
    
    :param file_name: name of the file
    :param value: first element of the semi-colon separated file 
    """
    with open(file_name, 'r') as f:
        lines = f.readlines()

    lines_to_keep = [line for line in lines if not 
                     line.startswith(f"{value};")]
    
    if lines_to_keep:
        lines_to_keep[-1] = lines_to_keep[-1].rstrip('\n')

    with open(file_name, 'w') as f:
        f.writelines(lines_to_keep)


def extract_all_products(base_url: str, tag_type: str) -> None:
    """Base on the input file, for all tags existing in a different language, 
    get from the api and save the list of product having these tags.
    
    :param base_url: base of the url to query tags one by one
    :param tag_type: the tag type (countries, labels, etc.)
    """

    file_name_end = file_other_lc_all_products.format(plural=tag_type)
    if os.path.exists(file_name_end):
        return

    file_name_start = file_other_lc.format(plural=tag_type)
    with open(file_name_start, 'r') as previous_file:
        _ = previous_file.readline()
        all_tags = previous_file.readlines()
        all_tags = [line.strip() for line in all_tags]
        # example 'en:italien;da:italien'

    # if file exists already, resume interrupted job, otherwise start from the 
    #   beginning
    if os.path.exists(f"{file_name_end}_in_progress"):
        # retrieve last saved line
        with open(f"{file_name_end}_in_progress", 'r') as read_file_end:
            for line in read_file_end:
                pass
            # line is the last line
            last_tag = line.split(";")[0]
        
        # found the index of the last saved file
        last_tag_index = None
        for i, item in enumerate(all_tags):
            if item.split(";")[0] == last_tag:
                last_tag_index = i
                break

        # remove all tags that are in the api response and that already in the 
        #   file_end, to restart INCLUDING last tag
        # remove all products for last tag from file_end. All products have 
        #   not been extracted for this tag. Hence we will extract all the
        #   products again
        if last_tag_index is not None:
            all_tags = all_tags[last_tag_index:]
            
            remove_lines_with_value(f"{file_name_end}_in_progress", 
                                    last_tag_index)

            file_end = open(f"{file_name_end}_in_progress", "a")

        # not found, restart from the beginning
        else:
            file_end = open(f"{file_name_end}_in_progress", "w")
            file_end.write("current tag;new tag;product code;field;field lc")
    # no file, start from the beginning
    else:
        file_end = open(f"{file_name_end}_in_progress", "w")
        file_end.write("current tag;new tag;product code;field;field lc") 


    for line in all_tags:
        current_tag = line.split(";")[0]

        url_get_all_products_for_a_tag = base_url.format(
            tag_id_placeholder=current_tag
        )

        all_products_for_tag_response = get_from_api(
            url_get_all_products_for_a_tag
        )

        if all_products_for_tag_response['page_count'] == 0:
            print(f"extract_all_products - {current_tag} - no products, INFO")
            continue

        total_number_of_products = all_products_for_tag_response['count']

        # current_tag is synonym of new_tag
        # current_tag is redirected to new_tag
        # there are too many products
        # example: es:nata;es:leche 
        threshold = 1000
        if total_number_of_products > threshold:
            print(f"extract_all_products - {current_tag} - too many " \
                  "products, WARNING")
            continue

        for page_nb in range(2, total_number_of_products // 100 + 2):
            next_page = get_from_api(f"{url_get_all_products_for_a_tag}" \
                                     f"&page={page_nb}")
            all_products_for_tag_response['products'] += next_page['products']

        all_products_for_tag = all_products_for_tag_response['products']
        count = len(all_products_for_tag)
        print(f"extract_all_products - {current_tag} - {count} products, INFO")

        for product in all_products_for_tag:
            # 06746209, Nnghjifiif\n uh
            # 4607053473698 бифидобактериями; массовая
            field = product[tag_type] \
                .replace("&quot;", "", -1) \
                .replace("\n", "", -1) \
                .replace(";", "", -1)

            # missing for many allergens, 8000500390771 for example
            if f'{tag_type}_lc' in product:
                field_lc = product[f'{tag_type}_lc']
            else:
                print(f"extract_all_products - {current_tag} - {tag_type}_lc "
                      f"missing in product {product['code']}, WARNING")
                continue
            
            file_end.write(f"\n{line};{product['code']};{field};{field_lc}")
            file_end.flush()

    file_end.close()
    os.rename(f"{file_name_end}_in_progress", file_name_end)

    # reorder by barcode (infer_schema_length to avoid auto assigned type for 
    # barcode and breaking because barcode are too big)
    df = pl.read_csv(file_name_end, separator=';', has_header=True, 
                     infer_schema_length=0)
    df_unique = df.unique()
    df_sorted = df_unique.sort('product code')
    df_sorted.write_csv(file_name_end, separator=';')


def count_products(base_url: str, tag_type: str) -> None:
    """Base on the input file, for all tags that are not existing in a 
    different language, get from the api and save the count of product having 
    these tags.
    
    :param base_url: base of the url to query tags one by one
    :param tag_type: the tag type (countries, labels, etc.)
    """
    for file in [file_new_count, file_to_update_count]:
        file_name_end = file.format(plural=tag_type)
        if os.path.exists(file_name_end):
            continue
        
        if file_name_end == file_new_count:
            file_name_start = file_new.format(plural=tag_type)
        else:
            file_name_start = file_to_update.format(plural=tag_type)

        with open(file_name_start, 'r') as previous_file:
            _ = previous_file.readline()
            all_tags = previous_file.readlines()
            all_tags = [line.strip() for line in all_tags]
            # example 'en:turkiye;'

            # limit to 100 first, should be enough for reviewing, otherwise it 
            # will take a lot of time
            all_tags = all_tags[:100]

        # if file exists already, resume interrupted job, otherwise start from the 
        #   beginning
        if os.path.exists(f"{file_name_end}_in_progress"):
            with open(f"{file_name_end}_in_progress", 'r') as read_file_end:
                line_count = sum(1 for _ in read_file_end)

            if line_count:
                all_tags = all_tags[line_count-1:]
                file_end = open(f"{file_name_end}_in_progress", "a")
            # not found, restart from the beginning
            else:
                file_end = open(f"{file_name_end}_in_progress", "w")
                file_end.write("current tag;new tag;count")
        # no file, start from the beginning
        else:
            file_end = open(f"{file_name_end}_in_progress", "w")
            file_end.write("current tag;new tag;count") 


        for line in all_tags:
            current_tag = line.split(";")[0]

            url_get_all_products_for_a_tag = base_url.format(
                tag_id_placeholder=current_tag
                )

            all_products_for_tag_response = get_from_api(
                url_get_all_products_for_a_tag
            )
            # example:
            #  all_products_for_tag_response = {
            #      "products": [
            #          {"categories": "Lait", "categories_lc": "en", ...}, 
            #      ],
            #  }

            total_number_of_products = all_products_for_tag_response['count']

            # sometimes 'count' is not null but there are no products at all
            if all_products_for_tag_response['page_count'] == 0:
                total_number_of_products = 0

                
            file_end.write(f"\n{line};{total_number_of_products}")
            file_end.flush()

        file_end.close()
        os.rename(f"{file_name_end}_in_progress", file_name_end)


def update_tags_field(tags_field_string: str, tags_field_lc: str, 
                      current_tag: str, updated_tag: str) -> str:
    """substitute current tag that is in the wrong language from the field,
    by the tag found in another language.

    :param tags_field_string: the current tags_field before to replace the tag
    :param tags_field_lc: the language of tags_field_string
    :param current_tag: tag to replace
    :param updated_tag: updated tag

    :return tags_field_string: updated tags_field_string
    """
    
    # convert into list to better handle upper and lower cases, split and 
    # concatenation, spaces
    tags_field = tags_field_string.split(",")

    tags_field_lower = [x.lower().strip().replace(" ", "-", -1) for x in 
                        tags_field]
    # add tags_field_lc as prefix if there is no language tag in the element
    tags_field_lower = [f"{tags_field_lc}:{x}" if len(x) > 3 and x[2] != ":" 
                        else x for x in tags_field_lower]
    # get rid of empty elements
    tags_field_lower = [x for x in tags_field_lower if x != ""]

    # old tag is still in the field
    if current_tag in tags_field_lower:
        index = tags_field_lower.index(current_tag)
        # updated tag is not yet in the field
        # replace current tag by updated tag
        if updated_tag not in tags_field_lower:
            print(f'update_tags_field - {current_tag} found in the field and '
                  f'{updated_tag} not yet in the field, updated_tag will '
                  f'replace current_tag, INFO')
            tags_field_lower[index] = updated_tag
        # updated tag is already in the field
        # delete only instead of updating
        else:
            print(f'update_tags_field - {current_tag} found in the field and '
                  f'{updated_tag} already in the field, current_tag will be '
                  f'removed, INFO')
            del tags_field_lower[index]
    # old tag is not in the field
    else:
        # updated tag is not yet in the field
        # add updated tag
        if updated_tag not in tags_field_lower:
            print(f'update_tags_field - {current_tag} not in the field '
                  f'anymore, {updated_tag} is also not yet in the field, '
                  f'updated_tag will be added, INFO')
            tags_field_lower.append(updated_tag)
        # final case, current tag missing and updated tag already in the field
        # is equivalent to leave the field as is
        else:
            print(f'update_tags_field - {current_tag} not in the field '
                  f'anymore and {updated_tag} already in the field, field '
                  f'will be posted as is, INFO')

    tags_field_string = ",".join(tags_field_lower)

    return tags_field_string


def update_tags(data: dict, post_call_url: str, tag_type: str) -> str:
    """Base on the input file, for all products, get the field for the tag 
    as well as the language code corresponding to this field from the api, 
    update the field based on tag in different language found in the taxonomy 
    save result in a temporary database - barcode: last field version - in 
    case the same barcode appears later in the file. Save updated field in the 
    output file. Note that we have to use the <tag_type> field because 
    <tag_type>_tags cannot be update with post method.
    
    :param data: data to add in the header of the post request
    :param post_call_url: base of the url to post updated field
    :param tag_type: the tag type (countries, labels, etc.)
    """
    file_name_end = file_updated_products.format(plural=tag_type)
    if os.path.exists(file_name_end):
        return
    
    file_name_start = file_other_lc_all_products.format(plural=tag_type)
    with open(file_name_start, 'r') as previous_file:
        _ = previous_file.readline()
        all_tags = previous_file.readlines()
        all_tags = [line.strip() for line in all_tags]

    # if file exists already, resume interrupted job, otherwise start from the 
    #   beginning
    if os.path.exists(f"{file_name_end}_in_progress"):
        # expect same number of line in both input and output files
        with open(f"{file_name_end}_in_progress", 'r') as read_file_end:
            line_count = sum(1 for _ in read_file_end)
          
        if line_count:
            all_tags = all_tags[line_count-1:]
            file_end = open(f"{file_name_end}_in_progress", "a")
        # not found, restart from the beginning
        else:
            file_end = open(f"{file_name_end}_in_progress", "w")
            file_end.write("current tag;new tag;product code;field;field lc;" \
                           "updated field")
    # no file, start from the beginning
    else:
        file_end = open(f"{file_name_end}_in_progress", "w")
        file_end.write("current tag;new tag;product code;field;field lc;"
                       "updated field")


    for line in all_tags:
        current_tag = line.split(";")[0]
        new_tag = line.split(";")[1]
        barcode = line.split(";")[2]
        with dbm.open(file_dbm, 'c') as db:
            if barcode in db:
                current_field = db[barcode].decode('utf-8')
                print(f"update_tags - {current_tag} - {barcode} - using "
                      f"cache, INFO")
            else:
                current_field = line.split(";")[3]
        field_lc = line.split(";")[4]

        updated_field = update_tags_field(current_field, field_lc, 
                                          current_tag, new_tag)
        
        # case when countries_lc was de and countries field was input as if 
        #   countries_lc would have been en (8410014871909)
        # case when it was 'en:beurre, en:lait', both leading to 'fr:lait'. 
        #   in this case WARNING appears from second occurence of the 
        #   same barcode
        if updated_field == current_field:
            print(f"update_tags - {current_tag} - {barcode} - new field and "
                  f"old field are the same: {updated_field}, this product "
                  f"update will be skipped, WARNING")
            file_end.write(f"\n{current_tag};{new_tag};{barcode};"
                           f"{current_field};{field_lc};SKIPPED")
            file_end.flush() 
            continue

        # country is needed otherwise <plural>_lc will be "en"
        try:
            country = mapping_languages_countries[field_lc]
        except KeyError:
            print(f"ERROR: when updating product '{current_tag}' to " \
                  f"'{new_tag}' ({barcode}). Unknown country for this " \
                  f"language: {field_lc}")
            sys.exit()

        data.update({
            'code': barcode, 
            tag_type: updated_field,
        })

        error_msg = ""
        # comment following lines to test the code only
        # i = 0
        # while True:
        #     post_call_url_res = requests.post(
        #         post_call_url.format(country=country),
        #         data=data,
        #         headers=headers,
        #     )
        #     if post_call_url_res.status_code == 200:
        #         break
        #     # 504: Gateway Timeout
        #     # 502: Bad Gateway, server got an invalid response
        #     elif post_call_url_res.status_code in [502, 504]:
        #         print(f"ERROR: when updating tag {current_tag} for product "
        #             f"{barcode}. {post_call_url_res.status_code} status code, "
        #             f"occurence: {i}")
        #         if i > 10:
        #             sys.exit()
        #         else:
        #             time.sleep(120)
        #             i += 1
        #     # 500: Internal Server Error (update product manually results in 
        #     #   "can't write into /srv/off/products/761/670/018/7847/38.sto: 
        #     #   No such file or directory at /opt/product-opener/lib
        #     #   /ProductOpener/Store.pm line 238.
        #     elif post_call_url_res.status_code in [500]:
        #         print(f"ERROR: when updating tag {current_tag} for product "
        #             f"{barcode}. {post_call_url_res.status_code} status code")
        #         error_msg = "SKIPPED ERROR 500"
        #         break          
        #     else:
        #         print(f"ERROR: when updating tag {current_tag} for product "
        #             f"{barcode}. {post_call_url_res.status_code} status code")
        #         print(f"    data.code: {barcode}, "
        #               f"data.{tag_type}: {updated_field}, "
        #               f"country: {country}")
        #         sys.exit()

        if error_msg:
            file_end.write(f"\n{current_tag};{new_tag};{barcode};"
                           f"{current_field};{field_lc};{error_msg}")
            file_end.flush()
        else:
            file_end.write(f"\n{current_tag};{new_tag};{barcode};"
                           f"{current_field};{field_lc};{updated_field}")
            file_end.flush()      
            with dbm.open(file_dbm, 'c') as db:
                db[barcode] = updated_field.encode('utf-8')

    file_end.close()
    os.rename(f"{file_name_end}_in_progress", file_name_end)


def main():
    parser = argparse.ArgumentParser(description="Provide tags type "
        "(allergens, categories, countries, labels, origins). Also, provide "
        "environment (prod, dev), user and password"
        )
    parser.add_argument('--tags', required=True, help="tags type (allergens, "
        "categories, countries, labels, origins). Comma separated, and quotes"
        )
    parser.add_argument('--env', required=True, help="environment (prod, dev) "
        "to connect to openfoodfacts"
        )
    parser.add_argument('--user_id', required=True, help="user id to connect "
        "to openfoodfacts"
        )
    parser.add_argument('--password', required=True, help="password to "
        "connect to openfoodfacts"
        )
    parser.add_argument('--debug', type=int, help="integer, limit number of "
        "unknown tags to fetch"
        )
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
        env = "org"
        user = ""
    elif env == "dev":
        env = "net"
        user = "off:off@"
    else:
        print(f"Environment should be 'prod' or 'dev', unexpected value: "
              f"{env}", file=sys.stderr)
        sys.exit()

    # int if provided, otherwise None
    debug = args.debug

    for plural, singular in map_tags_field_url_parameter.items():
        print(f"STEP 0 - START NEW TAG TYPE {plural.upper()}")
        
        tags_list_url = f"https://{user}world.openfoodfacts.{env}/{plural}" \
                        f".json"

        # reinitialize for each loop because "plural" and "code" are added 
        # below, hence, we need to remove it for the next item
        data = {
            'user_id': args.user_id,
            'password': args.password,
            # 'code': barcode, # added later
            # plural: updated_field, # added later
        }
        
        products_list_for_tag_url = f"https://{user}world.openfoodfacts." \
                                    f"{env}/{singular}/" \
                                    f"{{tag_id_placeholder}}.json" \
                                    f"?page_size=100"
        
        # country is needed otherwise <plural>_lc will be "en"
        post_call_url = f"https://{user}{{country}}.openfoodfacts.{env}/cgi/" \
                        f"product_jqm2.pl"

        # STEP 0 - SET UP VARIABLES
        # STEP 1 - GET ALL UNKNOWN ELEMENTS FROM API
        # STEP 2 - EXTRACT ALL UNKNOWN TAGS EXISTING IN TAXONOMY UNDER A 
        #          DIFFERENT LANGUAGE
        # STEP 3 - EXTRACT ALL PRODUCTS FOR EACH TAG
        # STEP 4 - COUNT PRODUCTS FOR EACH NEW TAG OR TO UPDATE
        # STEP 5 - UPDATE ALL PRODUCTS

        print(f"STEP 1 - GET ALL UNKNOWN ELEMENTS FROM API {plural.upper()}")
        get_all_unknown(tags_list_url, plural, debug)

        print(f"STEP 2 - EXTRACT ALL UNKNOWN TAGS EXISTING IN TAXONOMY UNDER "
              f"A DIFFERENT LANGUAGE {plural.upper()}")
        # filter to unknown tags only
        # search for the tag in the taxonomy
        # create 2 files:
        #  - tag exists in another language (file_other_lc)
        #  - tag does not exist in another language (file_new)
        unknown_tags_taxonomy_comparison(plural)

        print(f"STEP 3 - EXTRACT ALL PRODUCTS FOR EACH TAG {plural.upper()}")
        extract_all_products(products_list_for_tag_url, plural)
        
        print(f"STEP 4 - COUNT PRODUCTS FOR EACH NEW TAG OR TO UPDATE "
              f"{plural.upper()}")
        count_products(products_list_for_tag_url, plural)
        
        print(f"STEP 5 - UPDATE ALL PRODUCTS {plural.upper()}")
        update_tags(data, post_call_url, plural)

        # delete db (1 db per 1 tag type)
        try:
            os.remove(f"{file_dbm}.db")
        except FileNotFoundError:
            pass

if __name__ == "__main__":
    main()
