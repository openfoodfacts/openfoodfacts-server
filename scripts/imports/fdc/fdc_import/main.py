import logging
import os
import tomllib
from pathlib import Path

from .script.providers import build_csv, download_fdc_json_export

from .script.csv_schema import CSV_BASE_COLUMNS, FDC_NUTRIENTS


def set_up_config():
    """set up config data for the script"""
    current_folder = Path(__file__).parent
    config_toml_file = os.path.relpath("config/config.toml")

    with open(os.path.join(current_folder, config_toml_file), "rb") as f:
        config = tomllib.load(f)

    return config


def main():
    config = set_up_config()
    current_folder = Path(__file__).parent

    paths = config["paths"]
    FDC_JSON_URL = config["download_links"]["fdc_json_url"]

    DATA_FOLDER = current_folder / paths["data_folder"]
    EXPORT_FOLDER = current_folder / paths["export_folder"]

    EXTRACT_PATH = DATA_FOLDER / paths["fdc_downloaded_file"]
    DOWNLOADED_JSON = paths["raw_fdc_json_file"]
    JSON_PATH = DATA_FOLDER / DOWNLOADED_JSON
    OUTPUT_PATH = EXPORT_FOLDER / paths["result_file"]
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)

    NUTRIENTS_MATCH = DATA_FOLDER / paths["nutrients_mapping_file"]

    if not os.path.exists(JSON_PATH):
        download_fdc_json_export(
            url=FDC_JSON_URL,
            extract_path=EXTRACT_PATH,
            unzip_dir=DATA_FOLDER,
            downloaded_filename=DOWNLOADED_JSON,
        )

    try:
        build_csv(
            json_file_path=JSON_PATH,
            output_csv_file=OUTPUT_PATH,
            mapping_path=NUTRIENTS_MATCH,
            fdc_nutrients=FDC_NUTRIENTS,
            base_columns=CSV_BASE_COLUMNS,
        )

    except Exception as e:
        logging.error(f"Error during CSV build: {e}")


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    main()
