import csv
import json
from decimal import Decimal

from script.providers import build_csv


BASE_COLUMNS = [
    "code",
    "name",
    "last_updated_t",
    "categories",
    "countries",
    "ingredients",
    "serving_size",
    "brands",
    "brand_owner",
    "quantity",
]

FDC_NUTRIENTS = {"Protein": ["g"], "Energy": ["kcal"]}


def test_build_csv_integration_writes_expected_rows(tmp_path):
    mapping_file = tmp_path / "nutrient_map.csv"
    mapping_file.write_text(
        "fdc_name,off_col_name\nProtein,proteins\nEnergy,energy\n",
        encoding="utf-8",
    )

    json_file = tmp_path / "fdc.json"
    payload = {
        "BrandedFoods": [
            {
                "gtinUpc": "0000123456789",
                "description": "TEST PRODUCT",
                "modifiedDate": "3/7/2018",
                "brandedFoodCategory": "Egg Based Products, Frozen",
                "brandName": "A BRAND, INC.",
                "brandOwner": "OWNER",
                "servingSize": 46,
                "servingSizeUnit": "g",
                "householdServingFullText": "46g",
                "ingredients": "Eggs, milk",
                "packageWeight": "16 oz/454 g",
                "preparationStateCode": "UNPREPARED",
                "foodNutrients": [
                    {
                        "nutrient": {"name": "Protein", "unitName": "g"},
                        "amount": 10.7,
                    },
                    {
                        "nutrient": {"name": "Energy", "unitName": "kcal"},
                        "amount": 109,
                    },
                ],
            },
            {
                "gtinUpc": "bad-code",
                "description": "INVALID PRODUCT",
                "modifiedDate": "3/7/2018",
                "brandedFoodCategory": "Breads",
                "foodNutrients": [],
            },
        ]
    }
    json_file.write_text(json.dumps(payload), encoding="utf-8")

    output_file = tmp_path / "output.csv"

    build_csv(
        json_file_path=json_file,
        output_csv_file=str(output_file),
        mapping_path=str(mapping_file),
        fdc_nutrients=FDC_NUTRIENTS,
        base_columns=BASE_COLUMNS,
    )

    with open(output_file, newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))

    assert len(rows) == 1
    row = rows[0]

    assert row["code"] == "0000123456789"
    assert row["name"] == "TEST PRODUCT"
    assert row["categories"] == "Egg Based Products Frozen"
    assert row["countries"] == "United States"
    assert row["ingredients"] == "Eggs, milk"
    assert row["serving_size"] == "46 g"
    assert row["brands"] == "A BRAND INC."
    assert row["brand_owner"] == "OWNER"
    assert row["quantity"] == "16 oz/454 g"
    assert Decimal(row["proteins - as sold for 100g/100ml in g"]) == Decimal("10.7")
    assert Decimal(row["energy-kcal - as sold for 100g/100ml in kcal"]) == Decimal("109.0")


def test_build_csv_integration_empty_values_are_written_as_empty_cells(tmp_path):
    mapping_file = tmp_path / "nutrient_map.csv"
    mapping_file.write_text(
        "fdc_name,off_col_name\nProtein,proteins\nEnergy,energy\n",
        encoding="utf-8",
    )

    json_file = tmp_path / "fdc.json"
    payload = {
        "BrandedFoods": [
            {
                "gtinUpc": "0000123456789",
                "description": "TEST PRODUCT",
                "modifiedDate": "3/7/2018",
                "brandedFoodCategory": "Breads",
                "brandName": "NOT A BRANDED ITEM",
                "brandOwner": "   ",
                "servingSize": 46,
                "servingSizeUnit": "g",
                "householdServingFullText": "",
                "ingredients": "",
                "packageWeight": "",
                "preparationStateCode": "PREPARED",
                "foodNutrients": [
                    {
                        "nutrient": {"name": "Protein", "unitName": "g"},
                        "amount": 10.7,
                    }
                ],
            }
        ]
    }
    json_file.write_text(json.dumps(payload), encoding="utf-8")

    output_file = tmp_path / "output.csv"

    build_csv(
        json_file_path=json_file,
        output_csv_file=str(output_file),
        mapping_path=str(mapping_file),
        fdc_nutrients=FDC_NUTRIENTS,
        base_columns=BASE_COLUMNS,
    )

    with open(output_file, newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))

    assert len(rows) == 1
    row = rows[0]

    assert row["brands"] == ""
    assert row["brand_owner"] == ""
    assert row["quantity"] == ""
    assert row["ingredients"] == ""
    assert row["serving_size"] == ""
    assert Decimal(row["proteins - prepared for 100g/100ml in g"]) == Decimal("10.7")
