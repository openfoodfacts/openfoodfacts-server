# /// script
# requires-python = ">=3.14"
# dependencies = [
#   "ijson>=3.5.0",
# ]
# ///

import argparse
import csv
import json
import os
import tomllib
from collections import Counter
from pathlib import Path

import ijson

BRANDED_FOODS_PATH = "BrandedFoods.item"


def set_up_config():
	current_folder = Path(__file__).parent
	config_path = os.path.relpath("../config/schema_info.toml")
	with open(os.path.join(current_folder, config_path), "rb") as f:
	    return tomllib.load(f)


def create_nutrient_appearance_json(input_json: Path, output_json: Path) -> None:
	"""Create a JSON with appearance counts for each nutrient name across all foodNutrients entries."""
	nutrient_counts = Counter()

	with input_json.open("rb") as f:
		for product in ijson.items(f, BRANDED_FOODS_PATH):
			for nutrient_entry in product.get("foodNutrients", []):
				nutrient_name = nutrient_entry.get("nutrient", {}).get("name", "").strip() 
				if nutrient_name:
					nutrient_counts[nutrient_name] += 1

	rows = [
		{"fdc_nutrient_name": nutrient_name, "appearance_count": count}
		for nutrient_name, count in sorted(
			nutrient_counts.items(), key=lambda item: item[1], reverse=True
		)
	]

	output_json.parent.mkdir(parents=True, exist_ok=True)
	with output_json.open("w", encoding="utf-8") as f:
		json.dump(rows, f, ensure_ascii=False, indent=2)


def create_nutrient_appearance_json_by_product(input_json: Path, output_json: Path) -> None:
    """Counts how many product have each nutrient name."""
    nutrient_counts = Counter()

    with input_json.open("rb") as f:
        for product in ijson.items(f, BRANDED_FOODS_PATH):
            product_nutrients = set()
            for nutrient_entry in product.get("foodNutrients", []):
                nutrient_name = nutrient_entry.get("nutrient", {}).get("name", "").strip()
                if nutrient_name:
                    product_nutrients.add(nutrient_name)
            
            nutrient_counts.update(product_nutrients)
	
    rows = [
		{"fdc_nutrient_name": nutrient_name, "appearance_count": count}
		for nutrient_name, count in sorted(
			nutrient_counts.items(), key=lambda item: item[1], reverse=True
		)
	]

    output_json.parent.mkdir(parents=True, exist_ok=True)
    with output_json.open("w", encoding="utf-8") as f:
	    json.dump(rows, f, ensure_ascii=False, indent=2)

def create_schema_json(input_json: Path, output_json: Path) -> None:
	"""Extracts first layer keys from a json and creates a schema.json that counts their presence. 
	Also extracts and counts the presence of the first layer keys from the nutrients.
    create_nutrient_appearance_json is the function that counts nutrients presence instead of just their keys"""
	product_key_presence_count = Counter()
	nutrient_key_presence_count = Counter()

	with input_json.open("rb") as f:
		for product in ijson.items(f, BRANDED_FOODS_PATH):
			for key in product.keys():
				product_key_presence_count[key] += 1

			for nutrient_entry in product.get("foodNutrients", []):
				for key in nutrient_entry.keys():
					nutrient_key_presence_count[key] += 1

	schema = {
		"product_level": {
			"keys": {
				key: {"presence_count": product_key_presence_count[key]}
				for key in sorted(product_key_presence_count.keys())
			}
		},
		"food_nutrient_entry_level": {
			"keys": {
				key: {"presence_count": nutrient_key_presence_count[key]}
				for key in sorted(nutrient_key_presence_count.keys())
			}
		},
	}

	output_json.parent.mkdir(parents=True, exist_ok=True)
	with output_json.open("w", encoding="utf-8") as f:
		json.dump(schema, f, ensure_ascii=False, indent=2)


def create_missing_nutrients_csv(
	input_json: Path, nutrients_map_csv: Path, output_csv: Path
) -> None:
	"""Create a CSV with FDC nutrients that do not appear in nutrients_map.csv."""
	mapped_fdc_names = set()

	with nutrients_map_csv.open("r", encoding="utf-8") as f:
		reader = csv.DictReader(f)
		for row in reader:
			name = (row.get("fdc_name")).strip()
			if  row.get("off_col_name") != "":
				mapped_fdc_names.add(name)

	missing_counts = Counter()
	sample_product_name = {}

	with input_json.open("rb") as f:
		for product in ijson.items(f, BRANDED_FOODS_PATH):
			product_name = product.get("description", "").replace("\n", " ").replace("\r", " ")

			for nutrient_entry in product.get("foodNutrients", []):
				nutrient_name = nutrient_entry.get("nutrient", {}).get("name", "").strip()

				if nutrient_name and nutrient_name not in mapped_fdc_names:
					missing_counts[nutrient_name] += 1
					if nutrient_name not in sample_product_name:
						sample_product_name[nutrient_name] = product_name

	output_csv.parent.mkdir(parents=True, exist_ok=True)
	with output_csv.open("w", newline="", encoding="utf-8") as f:
		writer = csv.DictWriter(
			f,
			fieldnames=[
				"fdc_nutrient_name",
				"appearance_count",
				"sample_product_name",
			],
		)
		writer.writeheader()

		for nutrient_name, count in sorted(
			missing_counts.items(), key=lambda item: item[1], reverse=True
		):
			writer.writerow(
				{
					"fdc_nutrient_name": nutrient_name,
					"appearance_count": count,
					"sample_product_name": sample_product_name.get(nutrient_name, ""),
				}
			)


def main():
	parser = argparse.ArgumentParser()
	parser.add_argument(
		"--input",
		type=Path,
		default=Path("data/fdc.json"),
		help="Path to fdc.json",
	)
	args = parser.parse_args()
	config = set_up_config()

	nutrients_map = Path(config["paths"]["nutrients_map"])
	output_nutrient_counts_json = Path(config["paths"]["output_nutrient_counts_json"])
	output_schema_json = Path(config["paths"]["output_schema_json"])
	output_missing_nutrients_csv = Path(config["paths"]["output_missing_nutrients_csv"])
	output_nutrient_counts_json_by_product = Path(config["paths"]["output_nutrient_counts_json_by_product"])

	create_nutrient_appearance_json_by_product(args.input, output_nutrient_counts_json_by_product)
	create_nutrient_appearance_json(args.input, output_nutrient_counts_json)
	create_schema_json(args.input, output_schema_json)
	create_missing_nutrients_csv(
		args.input, nutrients_map, output_missing_nutrients_csv
	)


if __name__ == "__main__":
	main()
