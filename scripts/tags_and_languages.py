"""
This Python code: 
 - compare tags on products (using hugging face dataset) together with the 
taxonomy
 - for all tags being unknown but having a known element in the taxonomy for 
 another language, update the text defining the tags
 - finally, update the products

To use a virtual environment (it depends on the OS:
  https://python.land/virtual-environments/virtualenv)
```python3.xx -m venv venv```
```source venv/bin/activate```
```pip install requests```
```pip install duckdb```
```pip install numpy```
```pip install pandas```

- add your username and password in the variable

- run the code with:
```python3 tags_per_languages.py```
"""

from datetime import datetime
import duckdb
import re
import requests
import sys
import unicodedata

data = {
    'user_id': "TODO",
    'password': "TODO",
}

# tag_types = ["countries", "traces"] # "countries" and "traces" are missing in parquet file from hf. Only "countries_tags" and "traces_tags" are there
# tag_types = ["categories", "labels", "origins"]
# tag_types = ["categories"]
# tag_types = ["labels"]
tag_types = ["origins"]

# country is needed otherwise <tag_type>_lc will be "en"
post_call_url = "https://{country}.openfoodfacts.org/cgi/product_jqm2.pl"


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

conn = duckdb.connect(database=':memory:', read_only=False) # it takes ~30 sec to get from static url in memory


def retrieve_taxonomy_tag(tag_type: str) -> None:
    url = f"https://static.openfoodfacts.org/data/taxonomies/{tag_type}.json"
    response = requests.get(url, headers=headers)
    res = response.json()

    conn.execute(f'''
    CREATE TABLE {tag_type}_tags (
        tag TEXT,
        lc TEXT,
        lc_tag_name TEXT,
        lc_tag_name_concat TEXT
    )
    ''')

    for tag, data in res.items():
        for lc, lc_tag_name in data['name'].items():
            lc_tag_name = lc_tag_name.lower().replace(" ", "-")
            lc_tag_name_concat = f"{lc}:{lc_tag_name}"

            # Check if lc_tag_name already exists with lc = 'xx'
            exists = conn.execute(f'''
                SELECT lc FROM {tag_type}_tags
                WHERE tag = ? AND lc_tag_name = ?
            ''', (tag, lc_tag_name)).fetchone()

            if exists:
                if lc == 'xx':
                    conn.execute(f'''
                        UPDATE {tag_type}_tags
                        SET lc = ?, lc_tag_name = ?, lc_tag_name_concat = ?
                        WHERE tag = ?
                    ''', (lc, lc_tag_name, lc_tag_name_concat, tag))
            else:
                # Insert the new entry
                conn.execute(f'''
                    INSERT INTO {tag_type}_tags (tag, lc, lc_tag_name, lc_tag_name_concat)
                    VALUES (?, ?, ?, ?)
                ''', (tag, lc, lc_tag_name, lc_tag_name_concat))

    print(f' total count of tags for {tag_type}: {conn.execute(f"SELECT COUNT(*) FROM {tag_type}_tags").fetchone()[0]}')


def remove_accents(input_str):
    # Normalize the string to decompose accented characters
    normalized_str = unicodedata.normalize('NFD', input_str)
    # Filter out the accents
    no_accent_str = ''.join(c for c in normalized_str if unicodedata.category(c) != 'Mn')
    return no_accent_str


def clean_tag(tag):
    # Use regular expressions to replace spaces with hyphens and remove unwanted characters
    cleaned_tag = re.sub(r'[().]', '', tag).replace(" ", "-")
    return cleaned_tag


def update_tags(tags_text: str, old_tag_with_lc: str, old_tag: str, new_tag: str):
    tags_text = tags_text.lower()

    # Check if new_tag contains accents
    # if contains_accents(new_tag):
    # If new_tag contains accents, do not remove accents from tags_text
    tags_list = tags_text.split(",")
    tags_list = [clean_tag(x.strip()) for x in tags_list]

    updated = False
    # first, with lc as prefix: 
    #  "Porc, en:Porc" -> "porc, fr:porc" and not "fr:porc, en:porc"
    for i, tag in enumerate(tags_list):
        if tag == old_tag_with_lc:
            tags_list[i] = new_tag
            updated = True
            break
    if not updated:
        for i, tag in enumerate(tags_list):
            if tag == old_tag:
                tags_list[i] = new_tag
                updated = True
                break
    # sometimes, tag is not having accent whereas text is having accent
    if not updated:
        # If new_tag does not contain accents, remove accents from tags_text
        tags_list = remove_accents(tags_text).split(",")
        # tags_list = [x.strip().replace(" ", "-") for x in tags_list]
        tags_list = [clean_tag(x.strip()) for x in tags_list]
        for i, tag in enumerate(tags_list):
            if tag == old_tag_with_lc:
                tags_list[i] = new_tag
                updated = True
                break
    if not updated:
        for i, tag in enumerate(tags_list):
            if tag == old_tag:
                tags_list[i] = new_tag
                updated = True
                break


    updated_tags_text = ", ".join(tags_list)

    return updated_tags_text, updated


time_start = datetime.now()

for tag_type in tag_types:
    print(f"retrieve_taxonomy_tag from static url - time {datetime.now()-time_start}")
    retrieve_taxonomy_tag(tag_type)


    print(f"call products from hf - time {datetime.now()-time_start}")
    tags_to_update_df = conn.execute(f'''
    WITH products_tags AS (
        SELECT
            hf_dataset.code,
            hf_dataset.lang,
            hf_dataset.{tag_type},
            unnest(hf_dataset.{tag_type}_tags) AS {tag_type}_lc_and_tag,
            str_split(unnest(hf_dataset.{tag_type}_tags), ':')[2] AS {tag_type}_tag
        FROM 'hf://datasets/openfoodfacts/product-database/food.parquet' hf_dataset
        WHERE {tag_type}_tags IS NOT NULL
    ),
    products_unknown_tags AS (
        SELECT
            products_tags.code,
            products_tags.lang,
            products_tags.{tag_type},
            products_tags.{tag_type}_lc_and_tag,
            products_tags.{tag_type}_tag,
            taxonomy_tags.tag,
            taxonomy_tags.lc,
            taxonomy_tags.lc_tag_name,
            taxonomy_tags.lc_tag_name_concat
        FROM products_tags
        LEFT JOIN {tag_type}_tags taxonomy_tags
        ON products_tags.{tag_type}_lc_and_tag = taxonomy_tags.tag
        WHERE taxonomy_tags.lc_tag_name IS NULL
    )
    SELECT
        products_unknown_tags.code AS products_code,
        products_unknown_tags.lang AS products_lang,
        products_unknown_tags.{tag_type} AS products_{tag_type},
        products_unknown_tags.{tag_type}_lc_and_tag AS products_{tag_type}_unknown_tag,
        products_unknown_tags.{tag_type}_tag AS products_{tag_type}_unknown_tag_name,
        taxonomy_tags.tag AS taxonomy_tag_id,
        taxonomy_tags.lc AS taxonomy_tag_lc,
        taxonomy_tags.lc_tag_name AS taxonomy_tag_name,
        taxonomy_tags.lc_tag_name_concat AS taxonomy_tag
    FROM products_unknown_tags
    LEFT JOIN {tag_type}_tags taxonomy_tags
    ON products_unknown_tags.{tag_type}_tag = taxonomy_tags.lc_tag_name
    WHERE taxonomy_tags.lc_tag_name IS NOT NULL
    AND taxonomy_tags.lc != 'xx'
    AND products_unknown_tags.{tag_type}_lc_and_tag != taxonomy_tags.lc_tag_name_concat
    ''').df()
    # remark:
    #   AND products_unknown_tags.{tag_type}_lc_and_tag != taxonomy_tags.lc_tag_name_concat -> to prevent fr:angleterre and fr:angleterre

    print(f"prepare log table - time {datetime.now()-time_start}")
    conn_db = duckdb.connect(database='tags_and_languages.db', read_only=False)
    conn_db.execute(f'''
    DROP TABLE IF EXISTS products_to_update_{tag_type}
    ''')
    conn_db.execute(f'''
    CREATE TABLE products_to_update_{tag_type} (
        code TEXT,
        lang TEXT,
        old_tags_text TEXT,
        new_tags_text TEXT,
        updated_tags_text BOOLEAN,
        updated BOOLEAN
    )
    ''')
    for _, row in tags_to_update_df.iterrows():
        code = row[0]
        lang = row[1]
        
        existing_row = conn_db.execute(f"SELECT * FROM products_to_update_{tag_type} WHERE code = '{code}'").fetchone()
        
        if existing_row:
            # Update the existing row
            # existing_row[2] is tags as text already updated
            # row[3] is unknown tag with lc
            # row[4] is unknown tag
            # row[8] is row[4] tag found in another language
            new_tags_text, updated_tags_text = update_tags(existing_row[3], row[3], row[4], row[8])

            conn_db.execute(f'''
            UPDATE products_to_update_{tag_type}
            SET new_tags_text = ?, updated_tags_text = CASE 
                                    WHEN updated_tags_text = TRUE THEN TRUE 
                                    ELSE ? 
                                END
            WHERE code = ?
            ''', [new_tags_text, updated_tags_text, code])
        else:
            # Insert a new row
            # row[2] is tags as text
            # row[3] is unknown tag with lc
            # row[4] is unknown tag
            # row[8] is row[4] tag found in another language
            new_tags_text, updated_tags_text = update_tags(row[2], row[3], row[4], row[8])

            conn_db.execute(f'''
            INSERT INTO products_to_update_{tag_type} (code, lang, old_tags_text, new_tags_text, updated_tags_text, updated)
            VALUES (?, ?, ?, ?, ?, ?)
            ''', [code, lang, row[2], new_tags_text, updated_tags_text, False])

    print(f"finally update products - time {datetime.now()-time_start}")
    all_rows = conn_db.execute(f"SELECT * products_to_update_{tag_type}").fetchall()

    for row in all_rows:
        code = row[0]
        lang = row[1]

        try:
            country = mapping_languages_countries[lang]
        except KeyError:
            print(f"ERROR: language {lang} is not referenced in mapping_languages_countries")
            sys.exit()

        data.update({
            'code': code,
            tag_type: row[3],
        })
        try:
            post_call_url_res = requests.post(
                post_call_url.format(country=country),
                data=data,
                headers=headers,
            )

            if post_call_url_res.status_code != 200:
                print(f"ERROR: when updating product {code}. Received {post_call_url_res.status_code} status code")
                sys.exit()

            conn.execute(f'''
                UPDATE products_to_update_{tag_type} 
                SET updated = true
                WHERE code = ?
            ''', [code])

        except requests.RequestException as e:
            print(f"Request failed for code {code}: {e}")
            continue
