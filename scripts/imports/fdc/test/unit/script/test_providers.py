import csv
import json
from unittest.mock import MagicMock, patch

import pytest

from script.providers import (
    build_csv,
    build_csv_columns,
    build_nutrients_mapping,
    download_fdc_json_export,
)

BASE_COLUMNS = [
    "code",
    "name",
    "last_updated_t",
    "categories",
    "countries",
    "brand_owner",
    "preparationStateCode",
    "quantity",
]
FDC_NUTRIENTS = {"Protein": ["g", "g"], "Energy": ["kcal"]}
NUTRIENTS_MAPPING = {"Protein": "proteins", "Energy": "energy"}

CSV_CONTENT = "fdc_name,off_col_name\nProtein,proteins\nEnergy,energy\nSodium,\n"

FDC_PRODUCT = {
    "gtinUpc": "0000123456789",
    "description": "TEST PRODUCT",
    "brandedFoodCategory": "Breads",
    "modifiedDate": "3/7/2018",
    "brandOwner": "TEST BRAND OWNER",
    "packageWeight": "16 oz/454 g",
    "preparationStateCode": "UNPREPARED",
    "foodNutrients": [],
}

PARSED_PRODUCT = {
    "code": "0000123456789",
    "name": "TEST PRODUCT",
    "last_updated_t": 1520380800,
    "categories": ["Breads - FDC", "bread", "bakery"],
    "countries": "United States",
    "brand_owner": "TEST BRAND OWNER",
    "preparationStateCode": "UNPREPARED",
    "quantity": "16 oz/454 g",
}


@pytest.fixture
def category_mapping_file(tmp_path):
    category_file = tmp_path / "categories.json"
    category_file.write_text(
        json.dumps({"categories": [{"fdc": "Breads", "off": ["bread", "bakery"]}]})
    )
    return category_file


@pytest.fixture
def mapping_file(tmp_path):
    file_path = tmp_path / "nutrient_map.csv"
    file_path.write_text(CSV_CONTENT)
    return file_path


@pytest.fixture
def zip_setup(tmp_path):
    extract_path = tmp_path / "fdc.zip"
    extract_path.write_bytes(b"fake zip content")
    extracted_name = "fdc_original.json"
    downloaded_name = "fdc_renamed.json"
    (tmp_path / extracted_name).write_text("{}")
    return extract_path, tmp_path, extracted_name, downloaded_name


def _make_mock_zip(extracted_name):
    mock_zip = MagicMock()
    mock_zip.__enter__ = MagicMock(return_value=mock_zip)
    mock_zip.__exit__ = MagicMock(return_value=False)
    mock_zip.namelist.return_value = [extracted_name]
    return mock_zip


def test_build_nutrients_mapping(mapping_file):
    res = build_nutrients_mapping(str(mapping_file))

    assert {"Protein": "proteins", "Energy": "energy"} == res


def test_build_csv_columns():
    res = build_csv_columns(NUTRIENTS_MAPPING, FDC_NUTRIENTS, BASE_COLUMNS)

    wanted_columns = {
        "proteins - as sold for 100g/100ml in g",
        "proteins - prepared for 100g/100ml in g",
        "energy-kcal - as sold for 100g/100ml in kcal",
        "energy-kcal - prepared for 100g/100ml in kcal",
    }
    assert BASE_COLUMNS == res[: len(BASE_COLUMNS)]
    assert wanted_columns == set(res[len(BASE_COLUMNS) :])


@patch("script.providers.parse_product")
@patch("script.providers.ijson.items")
def test_build_csv(
    mock_ijson_items, mock_parse_product, tmp_path, mapping_file, category_mapping_file
):
    json_file = tmp_path / "fdc.json"
    json_file.write_bytes(b"{}")
    output_file = tmp_path / "output.csv"

    mock_ijson_items.return_value = iter([FDC_PRODUCT])
    mock_parse_product.return_value = PARSED_PRODUCT

    build_csv(
        json_file_path=json_file,
        output_csv_file=str(output_file),
        mapping_path=str(mapping_file),
        fdc_nutrients=FDC_NUTRIENTS,
        base_columns=BASE_COLUMNS,
    )

    with open(output_file, newline="") as output_stream:
        rows = list(csv.DictReader(output_stream))

    assert 1 == len(rows)
    assert PARSED_PRODUCT["code"] == rows[0].get("code")
    mock_parse_product.assert_called_once_with(
        FDC_PRODUCT,
        NUTRIENTS_MAPPING,
    )


@patch("script.providers.zipfile.ZipFile")
@patch("script.providers.urllib.request.urlretrieve")
def test_download_fdc_json_export(zip_mock_urlretrieve, mock_zipfile, zip_setup):
    extract_path, unzip_dir, extracted_name, downloaded_name = zip_setup
    mock_zipfile.return_value = _make_mock_zip(extracted_name)

    download_fdc_json_export(
        "http://example.com/fdc.zip", extract_path, unzip_dir, downloaded_name
    )

    assert not extract_path.exists()
    zip_mock_urlretrieve.assert_called_once_with(
        "http://example.com/fdc.zip", extract_path
    )


@patch("script.providers.zipfile.ZipFile")
@patch("script.providers.urllib.request.urlretrieve")
def test_download_fdc_json_export_raises_when_zip_has_no_json(
    _, mock_zipfile, zip_setup
):
    extract_path, unzip_dir, _, downloaded_name = zip_setup
    mock_zipfile.return_value = _make_mock_zip("readme.txt")

    with pytest.raises(FileNotFoundError):
        download_fdc_json_export(
            "http://example.com/fdc.zip",
            extract_path,
            unzip_dir,
            downloaded_name,
        )
