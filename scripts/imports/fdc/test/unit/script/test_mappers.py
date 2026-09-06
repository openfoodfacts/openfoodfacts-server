import pytest
from unittest.mock import patch

from script.mappers import (
    parse_product_base_data,
    parse_product_nutrients,
    find_preferred_entry,
)

PRODUCT_BARCODE = "0000123456789"
PRODUCT_BARCODE_WITH_HYPHENS = (
    PRODUCT_BARCODE[:2] + "-" + PRODUCT_BARCODE[2:5] + "-" + PRODUCT_BARCODE[5:] + "-"
)
PRODUCT_DESCRIPTION = "AWESOME SUPER CHIPS"
PRODUCT_FDC_CATEGORY = "Breads"
PRODUCT_MODIFIED_DATE = "3/7/2018"
PRODUCT_AVAILABLE_DATE = "2019-09-28T00:00:00Z"
PRODUCT_PUBLICATION_DATE = "2019-12-06T00:00:00Z"
PRODUCT_DATA_SOURCE = "LI"
PRODUCT_FDC_ID = "672854"
CONVERTED_PRODUCT_TIMESTAMP = 1111111111
PRODUCT_BRAND = "A REGULAR BRAND INC."
PRODUCT_BRAND_OWNER = "SUPER BRAND"
NOT_A_BRANDED_ITEM = "NOT A BRANDED ITEM"
PRODUCT_PACKAGE_WEIGHT = "16 oz/454 g"
PRODUCT_PREPARATION_STATE_CODE = "UNPREPARED"
SERVING_SIZE = 450
SERVING_SIZE_UNIT = "g"
HOUSEHOLD_SERVING_FULL_TEXT_DIFFERENT_AS_SERVING_FIELDS = (
    str(SERVING_SIZE + 5) + " " + SERVING_SIZE_UNIT
)
HOUSEHOLD_SERVING_FULL_TEXT_SAME_AS_SERVING_FIELDS = (
    str(SERVING_SIZE) + " " + SERVING_SIZE_UNIT
)
PRODUCT_INGREDIENTS = "ingredient 1, ingredient 2, ..."

FDC_COUNTRY = "United States"

PROTEIN_AMOUNT = 10.7
ENERGY_AMOUNT = 500
VITAMIN_C_AMOUNT = 0.000
PROTEIN_UNIT = "g"
ENERGY_UNIT = "kcal"
VITAMIN_C_UNIT = "mg"

NUTRIENTS_MAPPING = {
    "Protein": "proteins",
    "Energy": "energy",
}


FIRST_TOTAL_SUGARS = "Total sugars"
SECOND_TOTAL_SUGARS = "Sugars, total"
SUGARS_OFF_MATCH = "sugars"
SUGARS_UNIT = "g"
NUTRIENTS_MAPPING_SAME_MATCH = {
    FIRST_TOTAL_SUGARS: SUGARS_OFF_MATCH,
    SECOND_TOTAL_SUGARS: SUGARS_OFF_MATCH,
}

SOURCE_CODE_PRIORITY = {"LCGE": 0, "LCGP": 1, "LCGA": 2}
FIRST_NUTRIENT_LCGE = {"foodNutrientDerivation": {"code": "LCGE"}, "amount": 145.0}
SECOND_NUTRIENT_LCGE = {"foodNutrientDerivation": {"code": "LCGE"}, "amount": 27.3}
NUTRIENT_LCGA = {"foodNutrientDerivation": {"code": "LCGA"}, "amount": 36.7}


@pytest.fixture
def base_product() -> dict:
    return {
        "gtinUpc": PRODUCT_BARCODE,
        "description": PRODUCT_DESCRIPTION,
        "modifiedDate": PRODUCT_MODIFIED_DATE,
        "availableDate": PRODUCT_AVAILABLE_DATE,
        "publicationDate": PRODUCT_PUBLICATION_DATE,
        "dataSource": PRODUCT_DATA_SOURCE,
        "fdcId": PRODUCT_FDC_ID,
        "brandedFoodCategory": PRODUCT_FDC_CATEGORY,
        "brandName": PRODUCT_BRAND,
        "brandOwner": PRODUCT_BRAND_OWNER,
        "servingSize": SERVING_SIZE,
        "servingSizeUnit": SERVING_SIZE_UNIT,
        "householdServingFullText": HOUSEHOLD_SERVING_FULL_TEXT_DIFFERENT_AS_SERVING_FIELDS,
        "ingredients": PRODUCT_INGREDIENTS,
        "packageWeight": PRODUCT_PACKAGE_WEIGHT,
        "preparationStateCode": PRODUCT_PREPARATION_STATE_CODE,
    }


@pytest.fixture
def base_product_values_to_handle() -> dict:
    return {
        "gtinUpc": PRODUCT_BARCODE_WITH_HYPHENS,
        "description": PRODUCT_DESCRIPTION,
        "modifiedDate": PRODUCT_MODIFIED_DATE,
        "availableDate": PRODUCT_AVAILABLE_DATE,
        "publicationDate": PRODUCT_PUBLICATION_DATE,
        "dataSource": PRODUCT_DATA_SOURCE,
        "fdcId": PRODUCT_FDC_ID,
        "brandedFoodCategory": PRODUCT_FDC_CATEGORY,
        "brandName": NOT_A_BRANDED_ITEM,
        "servingSize": SERVING_SIZE,
        "servingSizeUnit": SERVING_SIZE_UNIT,
        "householdServingFullText": HOUSEHOLD_SERVING_FULL_TEXT_SAME_AS_SERVING_FIELDS,
    }


@pytest.fixture
def nutrients_product() -> dict:
    return {
        "preparationStateCode": "AS SOLD",
        "foodNutrients": [
            {
                "nutrient": {"name": "Protein", "unitName": PROTEIN_UNIT},
                "amount": PROTEIN_AMOUNT,
            },
            {
                "nutrient": {"name": "Energy", "unitName": ENERGY_UNIT},
                "amount": ENERGY_AMOUNT,
            },
            {
                "nutrient": {
                    "name": "Vitamin C, total ascorbic acid",
                    "unitName": VITAMIN_C_UNIT,
                },
                "amount": VITAMIN_C_AMOUNT,
            },
        ],
    }


@pytest.fixture
def product_without_preparation() -> dict:
    return {
        "foodNutrients": [
            {
                "nutrient": {"name": "Protein", "unitName": PROTEIN_UNIT},
                "amount": PROTEIN_AMOUNT,
            }
        ]
    }


@pytest.fixture
def product_without_base_preparation(product_without_preparation) -> dict:
    product_without_preparation["preparationStateCode"] = "READY_TO_EAT"
    return product_without_preparation


@pytest.fixture
def product_whitespace_preparation(product_without_preparation) -> dict:
    product_without_preparation["preparationStateCode"] = "   "
    return product_without_preparation


@pytest.fixture
def product_prepared_preparation(product_without_preparation) -> dict:
    product_without_preparation["preparationStateCode"] = "PREPARED"
    return product_without_preparation


@pytest.fixture
def product_same_match() -> dict:
    return {
        "foodNutrients": [
            {
                "nutrient": {"name": FIRST_TOTAL_SUGARS, "unitName": SUGARS_UNIT},
                "amount": 13.4,
            },
            {
                "nutrient": {"name": SECOND_TOTAL_SUGARS, "unitName": SUGARS_UNIT},
                "amount": 10.0,
            },
        ]
    }


def test_parse_product_base_data(base_product):
    with patch("script.mappers.convert_to_seconds") as mock_api:
        mock_api.return_value = CONVERTED_PRODUCT_TIMESTAMP
        res = parse_product_base_data(base_product)

    wanted_fields = {
        "code",
        "name",
        "categories",
        "countries",
        "sources_fields:org-database-usda:available_date",
        "sources_fields:org-database-usda:fdc_branded_category",
        "sources_fields:org-database-usda:fdc_data_source",
        "sources_fields:org-database-usda:fdc_id",
        "sources_fields:org-database-usda:modified_date",
        "sources_fields:org-database-usda:publication_date",
        "sources_fields:org-database-usda:preparation_state_code",
        "last_updated_t",
        "ingredients",
        "serving_size",
        "brands",
        "brand_owner",
        "quantity",
    }
    assert set(res.keys()) == wanted_fields
    assert res.get("code") == PRODUCT_BARCODE
    assert res.get("name") == PRODUCT_DESCRIPTION
    assert res.get("categories") == PRODUCT_FDC_CATEGORY
    assert res.get("countries") == FDC_COUNTRY
    assert res.get("last_updated_t") == CONVERTED_PRODUCT_TIMESTAMP
    assert res.get("brands") == PRODUCT_BRAND
    assert res.get("brand_owner") == PRODUCT_BRAND_OWNER
    assert (
        res.get("serving_size")
        == f"{HOUSEHOLD_SERVING_FULL_TEXT_DIFFERENT_AS_SERVING_FIELDS} ({SERVING_SIZE} {SERVING_SIZE_UNIT})"
    )
    assert res.get("ingredients") == PRODUCT_INGREDIENTS
    assert res.get("quantity") == PRODUCT_PACKAGE_WEIGHT
    assert (
        res.get("sources_fields:org-database-usda:available_date")
        == PRODUCT_AVAILABLE_DATE
    )
    assert (
        res.get("sources_fields:org-database-usda:fdc_branded_category")
        == f"FDC-Category {PRODUCT_FDC_CATEGORY}"
    )
    assert (
        res.get("sources_fields:org-database-usda:fdc_data_source")
        == PRODUCT_DATA_SOURCE
    )
    assert res.get("sources_fields:org-database-usda:fdc_id") == PRODUCT_FDC_ID
    assert (
        res.get("sources_fields:org-database-usda:modified_date")
        == PRODUCT_MODIFIED_DATE
    )
    assert (
        res.get("sources_fields:org-database-usda:publication_date")
        == PRODUCT_PUBLICATION_DATE
    )
    assert (
        res.get("sources_fields:org-database-usda:preparation_state_code")
        == PRODUCT_PREPARATION_STATE_CODE
    )

def test_parse_product_base_data_normalise_fields(base_product_values_to_handle):
    with patch("script.mappers.convert_to_seconds") as mock_api:
        mock_api.return_value = CONVERTED_PRODUCT_TIMESTAMP
        res = parse_product_base_data(base_product_values_to_handle)

    assert res.get("code") == PRODUCT_BARCODE
    assert res.get("brands") is None
    assert res.get("serving_size") == HOUSEHOLD_SERVING_FULL_TEXT_SAME_AS_SERVING_FIELDS
    assert res.get("quantity") is None


def test_parse_product_nutrients(nutrients_product):
    res = parse_product_nutrients(nutrients_product, NUTRIENTS_MAPPING)

    wanted_protein_field = f"proteins - as sold for 100g/100ml in {PROTEIN_UNIT}"
    wanted_energy_kcal_field = f"energy-kcal - as sold for 100g/100ml in {ENERGY_UNIT}"
    wanted_vitamin_c_field = (
        f"Vitamin C, total ascorbic acid - as sold for 100g/100ml in {VITAMIN_C_UNIT}"    )
    
    assert {
        wanted_protein_field,
        wanted_energy_kcal_field,
        wanted_vitamin_c_field,
    } == set(res.keys())
    assert res.get(wanted_protein_field) == PROTEIN_AMOUNT
    assert res.get(wanted_energy_kcal_field) == ENERGY_AMOUNT
    assert res.get(wanted_vitamin_c_field) == VITAMIN_C_AMOUNT


def test_parse_product_nutrients_same_nutrient_off_match_populate_same_column(
    product_same_match,
):
    res = parse_product_nutrients(product_same_match, NUTRIENTS_MAPPING_SAME_MATCH)

    assert set(res.keys()) == {
        f"{SUGARS_OFF_MATCH} - as sold for 100g/100ml in {SUGARS_UNIT}"
    }


def test_parse_product_base_data_preparation_state_code_not_prepared_defaults_to_as_sold(
    product_without_base_preparation,
):
    res = parse_product_nutrients(product_without_base_preparation, {})

    assert set(res.keys()) == {f"Protein - as sold for 100g/100ml in {PROTEIN_UNIT}"}
    

def test_parse_product_base_data_preparation_state_code_empty_defaults_to_as_sold(
    product_without_preparation,
):
    res = parse_product_nutrients(product_without_preparation, {})

    assert set(res.keys()) == {f"Protein - as sold for 100g/100ml in {PROTEIN_UNIT}"}


def test_parse_product_base_data_preparation_state_code_whitespace_defaults_to_as_sold(
    product_whitespace_preparation,
):
    res = parse_product_nutrients(product_whitespace_preparation, {})

    assert set(res.keys()) == {f"Protein - as sold for 100g/100ml in {PROTEIN_UNIT}"}


def test_parse_product_base_data_preparation_state_code_prepared_is_kept(
    product_prepared_preparation,
):
    res = parse_product_nutrients(product_prepared_preparation, {})

    assert set(res.keys()) == {f"Protein - prepared for 100g/100ml in {PROTEIN_UNIT}"}


def test_parse_product_base_data_quantity_empty_returns_none():
    product = {
        "gtinUpc": PRODUCT_BARCODE,
        "description": PRODUCT_DESCRIPTION,
        "modifiedDate": PRODUCT_MODIFIED_DATE,
        "brandedFoodCategory": PRODUCT_FDC_CATEGORY,
        "packageWeight": "",
    }
    with patch("script.mappers.convert_to_seconds"):
        res = parse_product_base_data(product)

    assert res.get("quantity") is None


def test_parse_product_base_data_quantity_whitespace_returns_none():
    product = {
        "gtinUpc": PRODUCT_BARCODE,
        "description": PRODUCT_DESCRIPTION,
        "modifiedDate": PRODUCT_MODIFIED_DATE,
        "brandedFoodCategory": PRODUCT_FDC_CATEGORY,
        "packageWeight": "   ",
    }
    with patch("script.mappers.convert_to_seconds"):
        res = parse_product_base_data(product)

    assert res.get("quantity") is None


def test_parse_product_base_data_brand_owner_empty_returns_none():
    product = {
        "gtinUpc": PRODUCT_BARCODE,
        "description": PRODUCT_DESCRIPTION,
        "modifiedDate": PRODUCT_MODIFIED_DATE,
        "brandedFoodCategory": PRODUCT_FDC_CATEGORY,
        "brandOwner": "",
    }
    with patch("script.mappers.convert_to_seconds"):
        res = parse_product_base_data(product)

    assert res.get("brand_owner") is None


def test_parse_product_base_data_brand_owner_whitespace_returns_none():
    product = {
        "gtinUpc": PRODUCT_BARCODE,
        "description": PRODUCT_DESCRIPTION,
        "modifiedDate": PRODUCT_MODIFIED_DATE,
        "brandedFoodCategory": PRODUCT_FDC_CATEGORY,
        "brandOwner": "   ",
    }
    with patch("script.mappers.convert_to_seconds"):
        res = parse_product_base_data(product)

    assert res.get("brand_owner") is None


def test_find_preferred_entry_same_source_returns_last_one():
    entries_with_same_source = [FIRST_NUTRIENT_LCGE, SECOND_NUTRIENT_LCGE]

    res = find_preferred_entry(entries_with_same_source, SOURCE_CODE_PRIORITY)

    assert res == SECOND_NUTRIENT_LCGE


def test_find_preferred_entry_different_sources_returns_highest_priority():
    entries_with_same_source = [FIRST_NUTRIENT_LCGE, NUTRIENT_LCGA]

    res = find_preferred_entry(entries_with_same_source, SOURCE_CODE_PRIORITY)

    assert res == FIRST_NUTRIENT_LCGE


def test_find_preferred_entry_one_entry_returns_given_entry():
    entries_with_same_source = [NUTRIENT_LCGA]

    res = find_preferred_entry(entries_with_same_source, SOURCE_CODE_PRIORITY)

    assert res == NUTRIENT_LCGA
