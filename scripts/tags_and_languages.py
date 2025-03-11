"""
This script:
 - compare tags on products together with the taxonomy, using Hugging Face
   parquet dataset and Open Food Facts' taxonomies (-c or --compare argument)
 - for all tags being unknown but having a known element in the taxonomy for 
   another language, update the text defining the tags
 - finally, update the products (-m or --modify argument) using Open Food 
   Facts API


To use a virtual environment, open a terminal and run:
$ sudo mkdir /usr/bin/uv
$ sudo curl -LsSf https://astral.sh/uv/install.sh | sudo env UV_INSTALL_DIR="/usr/bin/uv" sh
$ source /usr/bin/uv/env
$ uv --version
$ uv venv --python=3.11
$ source .venv/bin/activate
$ uv pip install -r tags_and_languages_requirements.txt

- add a username and password as environment variables. In a terminal, run:
$ export USER_ID='user_id' # please use a dedicated bot account, not your personal account
$ echo "Type password:"; read -s PASSWORD; export PASSWORD

- run the code with:
```python3 tags_and_languages.py```
"""

from datetime import datetime
import duckdb
import os
import re
import requests
import sys
import unicodedata
import argparse

# Use script header as documentation; see -h or --help or no argument
usage, epilog = __doc__.split("\n\n", 1)
parser = argparse.ArgumentParser(
    usage=usage,
    epilog=epilog,
    formatter_class=argparse.RawTextHelpFormatter
)
parser.add_argument('--nb', type=int, default=10000, help='Number of products (default: 10000)')
parser.add_argument('-c', '--compare', action='store_true', help='Compare mode (no modification)')
parser.add_argument('-m', '--modify', action='store_true', help='Allow modifications')
args = parser.parse_args()
if args.modify and args.compare:
    parser.print_help()
    sys.exit("\nError: -m and -c cannot be used together.")
if not args.modify and not args.compare:
    parser.print_help()
    sys.exit("\nError: Either -m or -c must be used.")

limit = f"LIMIT {args.nb}"

USER_ID = os.getenv('USER_ID')
PASSWORD = os.getenv('PASSWORD')

if USER_ID is None or PASSWORD is None:
    raise ValueError("Environment variables USER_ID and PASSWORD must be set")

BASE_DATA = {
    'user_id': USER_ID,
    'password': PASSWORD,
}

# tag_types = ["countries", "traces"] # "countries" and "traces" are missing in parquet file from hf. Only "countries_tags" and "traces_tags" are there
tag_types = ["categories", "labels", "origins"]
# tag_types = ["categories"]
# tag_types = ["labels"]
# tag_types = ["origins"]

# country is needed otherwise <tag_type>_lc will be "en"
post_call_url = "https://{country}.openfoodfacts.org/cgi/product_jqm2.pl"


headers = {
    'Accept': 'application/json',
    'User-Agent': 'UpdateTagsLanguages',
}

mapping_languages_countries = {
    "aa": "dj",
    "af": "za",
    "ar": "world",  # ar but categories are en:<french name>
    "be": "by",
    "bg": "bg",
    "bn": "bd",
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
    "he": "il",
    "hr": "hr",
    "hu": "hu",
    "id": "id",
    "is": "is",
    "it": "it",
    "iw": "il",
    "ja": "jp",
    "ko": "kr",
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
    "uk": "ua",
    "uz": "uz",
    "zh": "cn",
}

conn = duckdb.connect(database=':memory:', read_only=False) # it takes ~30 sec to get from static url in memory

sql_query = '''
    WITH 
    
    -- fetch all products from the last dataset in hugging face
    products_tags AS (
        SELECT
            hf_dataset.code, -- example: 0201441508005
            hf_dataset.lang, -- example: en
            hf_dataset.{tag_type}, -- example: Cambozola

            -- unnest all tags to have multiple row per product with 1 tag per row 
            --   instead of a single row and a list of tags
            unnest(hf_dataset.{tag_type}_tags) AS {tag_type}_lc_and_tag, -- example: ['Cambozola'] -> en:cambozola

            -- same but remove the language code, i.e. en:breakfasts -> breakfasts
            str_split(unnest(hf_dataset.{tag_type}_tags), ':')[2] AS {tag_type}_tag -- example: ['Cambozola'] -> cambozola

        FROM 'hf://datasets/openfoodfacts/product-database/food.parquet' hf_dataset

        -- skip products without tags
        WHERE {tag_type}_tags IS NOT NULL
        {limit}
    ),

    -- from the previous CTE, retrieve the tags that are not in the taxonomy
    products_unknown_tags AS (
        SELECT
            products_tags.code, -- example: 0201441508005
            products_tags.lang, -- example: en
            products_tags.{tag_type}, -- example: Cambozola
            products_tags.{tag_type}_lc_and_tag, -- example: ['Cambozola'] -> en:cambozola
            products_tags.{tag_type}_tag -- example: ['Cambozola'] -> cambozola
        FROM products_tags
        LEFT JOIN {tag_type}_tags taxonomy_tags
        ON products_tags.{tag_type}_lc_and_tag = taxonomy_tags.tag

        WHERE taxonomy_tags.lc_tag_name IS NULL
    )

    -- from the previous CTE, retrieve the tags existing in another language
    SELECT
        products_unknown_tags.code AS products_code, -- example: 0201441508005
        products_unknown_tags.lang AS products_lang, -- example: en
        products_unknown_tags.{tag_type} AS products_{tag_type}, -- example: Cambozola
        products_unknown_tags.{tag_type}_lc_and_tag AS products_{tag_type}_unknown_tag, -- example: ['Cambozola'] -> en:cambozola
        products_unknown_tags.{tag_type}_tag AS products_{tag_type}_unknown_tag_name, -- example: ['Cambozola'] -> cambozola

        taxonomy_tags.tag AS taxonomy_tag_id, -- example: de:cambozola
        taxonomy_tags.lc AS taxonomy_tag_lc, -- example: de
        taxonomy_tags.lc_tag_name AS taxonomy_tag_name, -- example: cambozola
        taxonomy_tags.lc_tag_name_concat AS taxonomy_tag -- example: de:cambozola

    FROM products_unknown_tags
    -- use inner join to keep only rows for which unknown tag is found in another language
    INNER JOIN {tag_type}_tags taxonomy_tags
    ON products_unknown_tags.{tag_type}_tag = taxonomy_tags.lc_tag_name

    -- ignore if language code is xx because it means that it is the name for any language
    AND taxonomy_tags.lc != 'xx'

    -- prevent "fr:angleterre" and "fr:angleterre"
    AND products_unknown_tags.{tag_type}_lc_and_tag != taxonomy_tags.lc_tag_name_concat
'''



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


def retrieve_tags_to_update(conn, tag_type):
    """Retrieve tags to update from the database."""
    # This query can be long, but there is no simple way to display progress
    # https://github.com/duckdb/duckdb/discussions/11923
    tags_to_update = conn.execute(sql_query.format(tag_type=tag_type,limit=limit)).fetchall()

    return tags_to_update


def create_and_populate_table(conn_db, tag_type, tags_to_update):
    """Create and populate the products_to_update_{tag_type} table if it doesn't exist."""
    
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

    for row in tags_to_update:
        products_code = row[0]
        products_lang = row[1]
        products_categories = row[2]
        products_categories_unknown_tag = row[3]
        products_categories_unknown_tag_name = row[4]
        taxonomy_tag = row[8]

        existing_row = conn_db.execute(f"SELECT * FROM products_to_update_{tag_type} WHERE code = '{products_code}'").fetchone()

        if existing_row:
            new_tags_text = existing_row[3]

            new_tags_text, updated_tags_text = update_tags(
                tags_text=new_tags_text, 
                old_tag_with_lc=products_categories_unknown_tag, 
                old_tag=products_categories_unknown_tag_name, 
                new_tag=taxonomy_tag
            )
            conn_db.execute(f'''
            UPDATE products_to_update_{tag_type}
            SET new_tags_text = ?, updated_tags_text = CASE
                                    WHEN updated_tags_text = TRUE THEN TRUE
                                    ELSE ?
                                END
            WHERE code = ?
            ''', [new_tags_text, updated_tags_text, products_code])
        else:
            new_tags_text, updated_tags_text = update_tags(
                tags_text=products_categories, 
                old_tag_with_lc=products_categories_unknown_tag, 
                old_tag=products_categories_unknown_tag_name, 
                new_tag=taxonomy_tag
            )
            conn_db.execute(f'''
            INSERT INTO products_to_update_{tag_type} (code, lang, old_tags_text, new_tags_text, updated_tags_text, updated)
            VALUES (?, ?, ?, ?, ?, ?)
            ''', [products_code, products_lang, products_categories, new_tags_text, updated_tags_text, False])


def run_modifications(conn_db, tag_type, mapping_languages_countries, post_call_url, headers):
    """Run modifications for the given tag type."""

    # resume job by filtering by updated = false
    all_rows = conn_db.execute(f"SELECT * FROM products_to_update_{tag_type} WHERE updated = FALSE").fetchall()
    print(f"There are {len(all_rows)} products to update")

    for row_to_update in all_rows:
        product_number = all_rows.index(row_to_update) + 1
        print(f"\rProcessing product {product_number}/{len(all_rows)} with code {row_to_update[0]}", end="", flush=True)
        code = row_to_update[0]
        lang = row_to_update[1]
        updated_tag_field = row_to_update[3]

        try:
            country = mapping_languages_countries[lang]
        except KeyError:
            print(f"ERROR: language {lang} is not referenced in mapping_languages_countries", file=sys.stderr)
            sys.exit()

        data = dict(BASE_DATA, code=code, tag_type=updated_tag_field)

        try:
            post_call_url_res = requests.post(
                post_call_url.format(country=country),
                data=data,
                headers=headers,
            )

            if post_call_url_res.status_code != 200:
                print(f"ERROR: when updating product {code}. Received {post_call_url_res.status_code} status code")
                sys.exit()

            conn_db.execute(f'''
                UPDATE products_to_update_{tag_type}
                SET updated = true
                WHERE code = ?
            ''', [code])

        except requests.RequestException as e:
            print(f"Request failed for code {code}: {e}")
            continue


# Main execution loop
time_start = datetime.now()
print(f"start time {time_start}")
print(f"Be aware this script can take dozens of minutes to run...")
print(f"It produces a local DB which might take a few MB of space")
if args.modify:
    print("-m or --modify parameter allows to modify products.")
else:
    print("Without -m or --modify parameter, no modification will be done.")

for tag_type in tag_types:

    table_name = f"products_to_update_{tag_type}"
    
    # Check if the table already exists in DuckDB
    conn_db = duckdb.connect(database='tags_and_languages_updated.db', read_only=False)
    
    if not conn_db.execute(f"""
    SELECT table_name
    FROM information_schema.tables
    WHERE table_name = '{table_name}'
    """).fetchone():
        print(f"\nretrieve_taxonomy_tag from static url {tag_type} - time {datetime.now()-time_start}")
        retrieve_taxonomy_tag(tag_type)

        print(f"call products from hf {tag_type} - time {datetime.now()-time_start}")
        tags_to_update = retrieve_tags_to_update(conn, tag_type)

        print(f"prepare log table {tag_type} - time {datetime.now()-time_start}")
        create_and_populate_table(conn_db, tag_type, tags_to_update)

    if args.modify:
        print(f"update products {tag_type} - time {datetime.now()-time_start}")
        run_modifications(conn_db, tag_type, mapping_languages_countries, post_call_url, headers)
    else:
        all_rows = conn_db.execute(f"SELECT * FROM products_to_update_{tag_type} WHERE updated = FALSE").fetchall()
        print(f"There are {len(all_rows)} products to be updated for {tag_type}")
        print(f"$ duckdb tags_and_languages_updated.db \"SELECT * FROM products_to_update_{tag_type} "
            f"WHERE updated = FALSE LIMIT 5\"")