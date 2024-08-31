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
import unicodedata


file_unknown = "update_tags_per_languages_{plural}"
file_other_lc = "update_tags_per_languages_{plural}_exist"
file_other_lc_all_products = "update_tags_per_languages_{plural}_exist_all"
file_other_lc_all_products_agg = "update_tags_per_languages_{plural}_exist_all_agg"
file_updated_products = "update_tags_per_languages_{plural}_exist_all_agg_updated"
file_new = "update_tags_per_languages_{plural}_new"
file_to_update = "update_tags_per_languages_{plural}_to_update"
file_dbm = "update_tags_per_languages_dbm"
start_time = time.time()

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
    "eu": "es",
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
    "ko": "kr",
    "lt": "lt",
    "lv": "lv",
    "ms": "my",
    "mt": "mt",
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
    i = 0
    while i < 10:
        get_call_url_res = requests.get(
            get_call_url,
            headers=headers,
        )
        if get_call_url_res.status_code == 200:
            break
        print(f"WARNING: when calling api. {get_call_url_res.status_code} "
              f"status code. url: {get_call_url}")
        time.sleep(2)
        i += 1

    if i == 10:
        print(f"ERROR: when calling api. {get_call_url_res.status_code} "
              f"status code. url: {get_call_url}")
        sys.exit()
    

    return get_call_url_res.json()


def get_all_unknown(tags_list_url: str, tag_type: str, debug: 
                    int=None) -> None:
    """Send a GET request to the given URL. Save result in one file having 
    tag_id as well as the number of products having this tag_id
    
    :param tags_list_url: the URL to send the request to
    :param tag_type: the tag type (countries, labels, etc.)
    :param debug: optional, interrupt queries after having reach number 
    provided

    :return: None
    """
    file_name_end = file_unknown.format(plural=tag_type)
    if os.path.exists(file_name_end):
        print(f"STEP 1 - GET ALL UNKNOWN ELEMENTS FROM API {tag_type.upper()} - SKIP - time elapsed: {round(time.time() - start_time)}")
        return
    else:
        print(f"STEP 1 - GET ALL UNKNOWN ELEMENTS FROM API {tag_type.upper()} - time elapsed: {round(time.time() - start_time)}")
        file_end = open(f"{file_name_end}", "w")
        file_end.write("current tag;products") 

    api_result = get_from_api(tags_list_url)
    tag_found = 0
    for tag in api_result["tags"]:
        if tag["known"] == 0:
            tag_id = tag['id']
            # id: agricultura-no-ue for origin (no country code)
            if ":" not in tag_id:
                tag_id = f"en:{tag_id}"
            file_end.write(f"\n{tag_id};{tag['products']}")
            file_end.flush()
            tag_found += 1
            if debug is not None and tag_found > debug:
                break

    file_end.close()


def unknown_tags_taxonomy_comparison(tag_type: str) -> None:
    """Iterate over all unknown tags, search in the taxonomy.
    Save results in a file if the tag is found in a different language.
    Save results in another file if it is not found (possible new tag).
    Save results in third file if it is knwn (only need to update product).

    :param tag_type: the current tag type (category, allergens, etc.). Used 
    to save the output file.

    :return: None
    """        
    file_name_end = file_other_lc.format(plural=tag_type)
    if os.path.exists(file_name_end):
        print(f"STEP 2 - EXTRACT ALL UNKNOWN TAGS EXISTING IN TAXONOMY UNDER "
              f"A DIFFERENT LANGUAGE {tag_type.upper()} - SKIPPED - time "
              f"elapsed: {round(time.time() - start_time)}")
        return
    

    print(f"STEP 2 - EXTRACT ALL UNKNOWN TAGS EXISTING IN TAXONOMY UNDER "
          f"A DIFFERENT LANGUAGE {tag_type.upper()} - time elapsed: "
          f"{round(time.time() - start_time)}")
        
    if tag_type in ["categories", "ingredients"]:
        taxonomy_file_location = os.path.abspath(os.path.join(os.path \
            .dirname( __file__ ), '..', f'taxonomies/food/{tag_type}.txt'))
    elif tag_type in ["traces"]:
        taxonomy_file_location = os.path.abspath(os.path.join(os.path \
            .dirname( __file__ ), '..', f'taxonomies/allergens.txt'))
    else:
        taxonomy_file_location = os.path.abspath(os.path.join(os.path 
            .dirname( __file__ ), '..', f'taxonomies/{tag_type}.txt'))

    with open(taxonomy_file_location, "r") as taxonomy_file:
        taxonomy_file_content = taxonomy_file.read() \
            .lower().replace(" ", "-", -1)
    # origins includes countries
    if tag_type == "origins":
        with open(os.path.abspath(os.path.join(os.path \
            .dirname( __file__ ), '..', f'taxonomies/countries.txt'))) \
            as country_taxonomy_file:
            taxonomy_file_content += country_taxonomy_file.read() \
            .lower().replace(" ", "-", -1)
        
    with open(file_unknown.format(plural=tag_type), 'r') as previous_file:
        _ = previous_file.readline()
        all_tags_id = previous_file.readlines()
        all_tags_id = [line.strip() for line in all_tags_id]

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
            if item.split(";")[0] == last_tag:
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
            output_file_to_update = open(file_to_update
                                         .format(plural=tag_type), "a")

        # not found, restart from the beginning
        else:
            output_file_exist = open(f"{file_name_end}_in_progress", "w")
            output_file_exist.write("current tag;new tag;products") 
            output_file_new = open(file_new.format(plural=tag_type), "w")
            output_file_new.write("current tag;products") 
            output_file_to_update = open(file_to_update
                                         .format(plural=tag_type), "w")
            output_file_to_update.write("current tag;products") 
    # no file, start from the beginning
    else:
        output_file_exist = open(f"{file_name_end}_in_progress", "w")
        output_file_exist.write("current tag;new tag;products") 
        output_file_new = open(file_new.format(plural=tag_type), "w")
        output_file_new.write("current tag;products")
        output_file_to_update = open(file_to_update
                                     .format(plural=tag_type), "w")
        output_file_to_update.write("current tag;products")
    
    for line in all_tags_id:
        tag_id, products = line.split(';')
        tag_lc = tag_id.split(":")[0]
        tag = tag_id.split(":")[1]

        # should retrieve all "en: blablabla, tag_name" or "it: tag_name"
        # the prefix is either the language or a comma. 
        # Suffix is either an end of line or a comma
        tag_regex = re. \
            compile(f'^([a-z][a-z]:-(?:[\w\s\-\']*\,-)*{tag})[,|\n]', 
                    re.MULTILINE)

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
            # # However they are already known
            universal = [x for x in tag_regex_res if "xx:" in x]
            # the tag already exists in the right language as a synonym
            same_lc = [x for x in tag_regex_res if f"{tag_lc}:" in x]
            # "en" was not in the last put back first value in the list
            contains_en = [x for x in tag_regex_res if "en:" in x]
            
            if universal:
                print(f"the tag xx:{tag} exists for this tag, WARNING")
                continue
            elif same_lc:
                print(f"the tag {tag_id} already exists in the right language "
                      f"as a synonym, WARNING")
                tag_regex_res= same_lc
            elif contains_en:
                tag_regex_res= same_lc
            else:
                tag_regex_res = [tag_regex_res_first]

        # got one occurence in the taxonomy, or recreated tag_regex_res 
        #   with single element in the previous condition (hence, we have a if
        #   condition below and not an elif condition
        if len(tag_regex_res) == 1:
            # xx: shows in api results as fr:, de:, en: etc.
            # However they are already known
            # same code before was done when len(tag_regex_res) > 1
            universal = [x for x in tag_regex_res if "xx:" in x]
            if universal:
                print(f"the tag xx:{tag} exists for this tag, WARNING")
                continue

            if tag_regex_res[0][:2] == tag_lc:
                output_file_to_update.write(f"\n{tag_id};{products}")
                output_file_to_update.flush()
            else:
                existing_tag = tag_regex_res[0] \
                    .split(',')[0].replace(':-', ':')
                output_file_exist.write(f"\n{tag_id};{existing_tag};{products}")
                output_file_exist.flush()

        # 0 occurences
        else:
            output_file_new.write(f"\n{tag_id};{products}")
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

    :return: None
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
    get from the api and save the list of products having these tags.
    
    :param base_url: base of the url to query tags one by one
    :param tag_type: the tag type (countries, labels, etc.)

    :return: None
    """

    file_name_end = file_other_lc_all_products.format(plural=tag_type)
    if os.path.exists(file_name_end):
        print(f"STEP 3 - EXTRACT ALL PRODUCTS FOR EACH TAG {tag_type.upper()}"
              f" - SKIP - time elapsed: {round(time.time() - start_time)}")
        return

    print(f"STEP 3 - EXTRACT ALL PRODUCTS FOR EACH TAG {tag_type.upper()} - "
          f"time elapsed: {round(time.time() - start_time)}")

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

        # there are too many products
        # example: en:unknown has > 2 978 485 products
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
            
            file_end.write(f"\n{line.split(';')[0]};{line.split(';')[1]};"
                           f"{product['code']};{field};{field_lc}")
            file_end.flush()

    file_end.close()
    os.rename(f"{file_name_end}_in_progress", file_name_end)

    # reorder by barcode (infer_schema_length to avoid auto assigned type for 
    # barcode and breaking because barcode are too big)
    df = pl.read_csv(
        file_name_end, 
        separator=';', 
        has_header=True, 
        infer_schema_length=0
    )
    df_unique = df.unique()
    df_sorted = df_unique.sort('product code')
    df_sorted.write_csv(file_name_end, separator=';')


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

    # non-breaking space (NBSP), 356470078727413 "el:fromages en tranches"
    tags_field_lower = [x.lower().strip().replace(" ", "-", -1)
                        .replace("\u00A0", "-", -1) for x in 
                        tags_field]

    # add tags_field_lc as prefix if there is no language tag in the element
    # problem for en:riz
    tags_field_lower = [f"{tags_field_lc}:{x}" if ":" not in x \
                        else x for x in tags_field_lower]
    # get rid of empty elements
    tags_field_lower = [x for x in tags_field_lower if x != ""]
    # strip dots (en:noten. in 8718906699045)
    tags_field_lower = [x.strip(".") for x in tags_field_lower]
    # remove duplicates
    tags_field_lower = list(set(tags_field_lower))

    # current tag does not have accent but tag in field does
    tags_field_lower_no_accent = [
        "".join(
                c for c in unicodedata.normalize('NFKD', s) 
                if not unicodedata.combining(c)
        ) for s in tags_field_lower]
    
    # current tag with accent but tag in field without it
    current_tag_no_accent = "".join(
        c for c in unicodedata.normalize(
            'NFKD', current_tag
        ) if not unicodedata.combining(c)
    )

    # old tag is still in the field
    if current_tag_no_accent in tags_field_lower_no_accent:
        index = tags_field_lower_no_accent.index(current_tag_no_accent)
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


def update_tags(tag_type: str) -> None:
    """Based on the input file, for all products, for all tags to update,
    get the current field as well as the language code corresponding to this 
    field. Replace the current tag by the updated tag in the field. Save the 
    result in a database. Go to next line. If current product (next line) 
    differs from the previous product (barcode), save the initial field and 
    the last version of the updated field - which includes all updated tags - 
    to the output file.
    Note that we have to use the <tag_type> field because <tag_type>_tags 
    cannot be update with post method.
    
    :param data: data to add in the header of the post request
    :param post_call_url: base of the url to post updated field
    :param tag_type: the tag type (countries, labels, etc.)
    """
    file_name_end = file_other_lc_all_products_agg.format(plural=tag_type)
    if os.path.exists(file_name_end):
        print(f"STEP 4 - UPDATE FIELD {tag_type.upper()} - SKIP - time "
              f"elapsed: {round(time.time() - start_time)}")
        return
    
    print(f"STEP 4 - UPDATE FIELD {tag_type.upper()} - time elapsed: "
          f"{round(time.time() - start_time)}")
    file_name_start = file_other_lc_all_products.format(plural=tag_type)
    with open(file_name_start, 'r') as previous_file:
        _ = previous_file.readline()
        all_tags = previous_file.readlines()
        all_tags = [line.strip() for line in all_tags]



    # delete db (1 db per 1 tag type)
    # this function cannot be resumed, it restarts from scratch
    # hence, we should make sure database is deleted before to start
    try:
        os.remove(f"{file_dbm}.db")
    except FileNotFoundError:
        pass

    file_end = open(f"{file_name_end}_in_progress", "w")
    file_end.write("product code;field lc;field;updated field")

    previous_line = ''
    for line in all_tags:
        update_bool = True
        current_tag = line.split(";")[0]
        new_tag = line.split(";")[1]
        barcode = line.split(";")[2]
        
        with dbm.open(file_dbm, 'c') as db:
            if barcode in db:
                current_field_int = db[barcode].decode('utf-8')
                update_bool = False
            else:
                # keep the original because if there are more than one we want 
                # the first - here - before any update and the last after 
                # all subsequent updates
                current_field = line.split(";")[3] 
                current_field_int = line.split(";")[3]
        field_lc = line.split(";")[4]

        # save previous line, skip first (previous_line is empty) 
        # because first line is handled below
        # last line will be added after the for loop
        if previous_line and update_bool:
            file_end.write(f"\n{previous_line}")
            file_end.flush()

        updated_field = update_tags_field(current_field_int, field_lc, 
                                          current_tag, new_tag)
        
        previous_line = f"{barcode};{field_lc};{current_field};{updated_field}"
        # case when countries_lc was de and countries field was input as if 
        #   countries_lc would have been en (8410014871909)
        # case when it was 'en:beurre, en:lait', both leading to 'fr:lait'. 
        #   in this case WARNING appears from second occurence of the 
        #   same barcode
        # case when it was already updated by the current script recently. 
        #   Current tag is not in the field but in the _old field 
        #   instead. Example 3422210438065 for en:cordon-bleus
        # this warning need to be reviewed in the output file
        if updated_field == current_field_int:
            print(f"update_tags - updated_field and current_field_int are "
                  f"the same for {barcode}. updated_field: {updated_field}. "
                  f"current_field_int: {current_field_int}, WARNING")

        with dbm.open(file_dbm, 'c') as db:
            db[barcode] = updated_field.encode('utf-8')

    file_end.write(f"\n{previous_line}")
    file_end.flush() 

    file_end.close()
    os.rename(f"{file_name_end}_in_progress", file_name_end)

    # delete db (1 db per 1 tag type)
    try:
        os.remove(f"{file_dbm}.db")
    except FileNotFoundError:
        pass


def update_products(data: dict, post_call_url: str, tag_type: str) -> None:
    """Base on the input file, for all products, get the field for the tag
    as well as the language code corresponding to this field from the api, 
    update the field based on tag in different language found in the taxonomy 
    Save updated field in the output file. 
    Note that we have to use the <tag_type> field because <tag_type>_tags 
    cannot be update with post method.
    
    :param data: data to add in the header of the post request
    :param post_call_url: base of the url to post updated field
    :param tag_type: the tag type (countries, labels, etc.)
    """
    file_name_end = file_updated_products.format(plural=tag_type)
    if os.path.exists(file_name_end):
        print(f"STEP 5 - UPDATE ALL PRODUCTS {tag_type.upper()} - SKIP - "
              f"time elapsed: {round(time.time() - start_time)}")
        return
    
    print(f"STEP 5 - UPDATE ALL PRODUCTS {tag_type.upper()} - time elapsed: "
          f"{round(time.time() - start_time)}")
    file_name_start = file_other_lc_all_products_agg.format(plural=tag_type)
    with open(file_name_start, 'r') as previous_file:
        _ = previous_file.readline()
        all_tags = previous_file.readlines()
        all_tags = [line.strip() for line in all_tags]

    # if file exists already, resume interrupted job, otherwise start from the 
    #   beginning
    if os.path.exists(f"{file_name_end}_in_progress"):
        # retrieve last saved log
        with open(f"{file_name_end}_in_progress", 'r') as file_end:
            for line in file_end:
                pass
            # line is the last line
            last_barcode = line.split(";")[0]
            last_updated_field = line.split(";")[1]
        
        # find the index of the last saved log
        last_tag_index = None
        for i, item in enumerate(all_tags):
            if item.split(";")[0] == last_barcode and item.split(";")[3] == last_updated_field:
                last_tag_index = i
                break

        # remove all tags already in the logs from the api response, to 
        #   restart AFTER (i.e., +1) last log
        if last_tag_index:
            all_tags = all_tags[last_tag_index+1:]
            file_end = open(f"{file_name_end}_in_progress", "a")

        # not found, restart from the beginning
        else:
            file_end = open(f"{file_name_end}_in_progress", "w")
            file_end.write("barcode;updated field")
    # no file, start from the beginning
    else:
        file_end = open(f"{file_name_end}_in_progress", "w")
        file_end.write("barcode;updated field")


    for line in all_tags:
        barcode = line.split(";")[0]
        field_lc = line.split(";")[1]
        updated_field = line.split(";")[3]

        # country is needed otherwise <plural>_lc will be "en"
        try:
            country = mapping_languages_countries[field_lc]
        except KeyError:
            print(f"ERROR: when updating product {barcode}. "
                  f"Unknown country for this language: {field_lc}")
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
        #         print(f"ERROR: when updating product {barcode}. "
        #               f"{post_call_url_res.status_code} status code, "
        #               f"occurence: {i}")
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
        #         print(f"ERROR: when updating product {barcode}. "
        #             f"{post_call_url_res.status_code} status code, skip")
        #         error_msg = "SKIPPED ERROR 500"
        #         break          
        #     else:
        #         print(f"ERROR: when updating product {barcode}. "
        #               f"{post_call_url_res.status_code} status code")
        #         sys.exit()

        if error_msg:
            file_end.write(f"\n{barcode};{error_msg}")
            file_end.flush()
        else:
            file_end.write(f"\n{barcode};{updated_field}")
            file_end.flush()

    file_end.close()
    os.rename(f"{file_name_end}_in_progress", file_name_end)


def main():
    parser = argparse.ArgumentParser(description="Provide tags type "
        "(categories, countries, labels, origins, traces). Also, provide "
        "environment (prod, dev), user and password"
        )
    parser.add_argument('--tags', required=True, help="tags type (categories, "
        "countries, labels, origins, traces). Comma separated, and quotes"
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
        # STEP 0 - SET UP VARIABLES
        print(f"STEP 0 - START NEW TAG TYPE {plural.upper()}")

        tags_list_url = f"https://{user}world.openfoodfacts.{env}/{plural}?" \
                        f"status=unknown.json"

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

        # STEP 1 - GET ALL UNKNOWN ELEMENTS FROM API
        get_all_unknown(tags_list_url, plural, debug)


        # STEP 2 - EXTRACT ALL UNKNOWN TAGS EXISTING IN TAXONOMY UNDER A 
        #          DIFFERENT LANGUAGE
        # filter to unknown tags only
        # search for the tag in the taxonomy
        # create 3 files:
        #  - tag exists in another language (file_other_lc)
        #  - tag does not exist in another language (file_new)
        #  - tag exists a as-is in the taxonomy
        unknown_tags_taxonomy_comparison(plural)

        # STEP 3 - EXTRACT ALL PRODUCTS FOR EACH TAG
        extract_all_products(products_list_for_tag_url, plural)        
        
        # STEP 4 - UPDATE FIELD
        update_tags(plural)

        # STEP 5 - UPDATE ALL PRODUCTS
        update_products(data, post_call_url, plural)

        print(f"STEP X -  {plural.upper()} DONE - time elapsed: {round(time.time() - start_time)}")


if __name__ == "__main__":
    main()
