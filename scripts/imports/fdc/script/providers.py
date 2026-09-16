import urllib.request
import zipfile
import csv
from pathlib import Path

import ijson
import logging
from script.mappers import parse_product


def download_fdc_json_export(
    url: str, extract_path: Path, unzip_dir: Path, downloaded_filename: str
) -> Path:
    """Downloads the ZIP, extracts it to unzip_dir, deletes the ZIP and returns the JSON path."""

    urllib.request.urlretrieve(url, extract_path)
    try:
        with zipfile.ZipFile(extract_path, "r") as zip_ref:
            zip_ref.extractall(unzip_dir)

            extracted_files = zip_ref.namelist()
            json_filename = next(
                (f for f in extracted_files if f.endswith(".json")), None
            )

            if not json_filename:
                raise FileNotFoundError("No JSON file found inside the ZIP.")

        json_file_path = unzip_dir / json_filename
        json_file_path = json_file_path.rename(unzip_dir / downloaded_filename)

        extract_path.unlink()

    except Exception as e:
        logging.error(f"Failed to unzip file: {e}")
        raise


def build_nutrients_mapping(mapping_path: str) -> dict:
    """Creates a mapping dictionary of the nutrients of FDC and OFF"""

    mapping_dict = {}

    with open(mapping_path, "r", encoding="utf-8") as f_map:
        reader = csv.DictReader(f_map)
        for row in reader:
            fdc_name = row["fdc_name"].strip()
            off_name = row["off_col_name"].strip()
            if off_name:
                mapping_dict[fdc_name] = off_name
    return mapping_dict


def add_nutrient_column(nutrient_name: str, nutrient_unit: str, preparation_states: list, columns: list) -> None:
    for preparation in preparation_states:
        columns.append(f"{nutrient_name} - {preparation} for 100g/100ml in {nutrient_unit}")


def build_csv_columns(
    mapping_dict: dict, fdc_nutrients: dict, base_columns: list
) -> list:
    """Creates a list of all the columns of the import CSV"""
    nutrient_cols = []
    preparation_states = ["as sold", "prepared"]

    for nutrient in fdc_nutrients.keys():
        for nutrient_unit in fdc_nutrients.get(nutrient):
            if nutrient.lower() == "energy" and nutrient_unit.lower() in ["kj", "kcal"]:
                nutrient_name = mapping_dict.get(nutrient, nutrient)
                add_nutrient_column(f"{nutrient_name}-{nutrient_unit.lower()}", nutrient_unit, preparation_states, nutrient_cols)
            else:
                add_nutrient_column(f"{mapping_dict.get(nutrient, nutrient)}", nutrient_unit, preparation_states, nutrient_cols)

    all_columns = base_columns + list(dict.fromkeys(nutrient_cols))

    return all_columns


def build_csv(
    json_file_path: Path,
    output_csv_file: str,
    mapping_path: str,
    fdc_nutrients: list,
    base_columns: list,
):
    """Builds the import CSV from the FDC export data."""
    nutrients_mapping = build_nutrients_mapping(mapping_path)
    all_columns = build_csv_columns(nutrients_mapping, fdc_nutrients, base_columns)

    # write in final file
    with open(json_file_path, "rb") as raw_json, open(
        output_csv_file, "w", newline="", encoding="utf-8"
    ) as out_csv:

        writer = csv.DictWriter(out_csv, fieldnames=all_columns)
        writer.writeheader()

        raw_products = ijson.items(raw_json, "BrandedFoods.item", use_float=True)

        for product in raw_products:
            try:
                product_row = parse_product(product, nutrients_mapping)

                if product_row.get("code") is not None:
                    writer.writerow(product_row)

            except Exception as e:
                logging.warning(
                    f"Failed to parse product {product.get('gtinUpc')}: {e}"
                )
