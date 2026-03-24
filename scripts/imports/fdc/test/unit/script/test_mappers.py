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
def base_product():
    return {
        "gtinUpc": PRODUCT_BARCODE,
        "description": PRODUCT_DESCRIPTION,
        "modifiedDate": PRODUCT_MODIFIED_DATE,
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
def base_product_values_to_handle():
    return {
        "gtinUpc": PRODUCT_BARCODE_WITH_HYPHENS,
        "description": PRODUCT_DESCRIPTION,
        "modifiedDate": PRODUCT_MODIFIED_DATE,
        "brandedFoodCategory": PRODUCT_FDC_CATEGORY,
        "brandName": NOT_A_BRANDED_ITEM,
        "servingSize": SERVING_SIZE,
        "servingSizeUnit": SERVING_SIZE_UNIT,
        "householdServingFullText": HOUSEHOLD_SERVING_FULL_TEXT_SAME_AS_SERVING_FIELDS,
    }


@pytest.fixture
def nutrients_product():
    return {
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
        ]
    }


@pytest.fixture
def product_same_match():
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
        "last_updated_t",
        "ingredients",
        "serving_size",
        "brands",
        "brand_owner",
        "preparationStateCode",
        "quantity",
    }
    assert set(res.keys()) == wanted_fields
    assert res.get("code") == PRODUCT_BARCODE
    assert res.get("name") == PRODUCT_DESCRIPTION
    assert res.get("categories") == PRODUCT_FDC_CATEGORY
    assert res.get("countries") == [FDC_COUNTRY]
    assert res.get("last_updated_t") == CONVERTED_PRODUCT_TIMESTAMP
    assert res.get("brands") == PRODUCT_BRAND
    assert res.get("brand_owner") == PRODUCT_BRAND_OWNER
    assert (
        res.get("serving_size")
        == f"{HOUSEHOLD_SERVING_FULL_TEXT_DIFFERENT_AS_SERVING_FIELDS} ({SERVING_SIZE} {SERVING_SIZE_UNIT})"
    )
    assert res.get("ingredients") == PRODUCT_INGREDIENTS
    assert res.get("preparationStateCode") == "as_sold"  
    assert res.get("quantity") == PRODUCT_PACKAGE_WEIGHT


def test_parse_product_base_data_normalise_fields(base_product_values_to_handle):
    with patch("script.mappers.convert_to_seconds") as mock_api:
        mock_api.return_value = CONVERTED_PRODUCT_TIMESTAMP
        res = parse_product_base_data(base_product_values_to_handle)

    assert res.get("code") == PRODUCT_BARCODE
    assert res.get("brands") is None
    assert res.get("serving_size") == HOUSEHOLD_SERVING_FULL_TEXT_SAME_AS_SERVING_FIELDS
    assert res.get("preparationStateCode") == "as_sold" 
    assert res.get("quantity") is None


def test_parse_product_nutrients(nutrients_product):
    res = parse_product_nutrients(nutrients_product, NUTRIENTS_MAPPING)

    wanted_protein_field = f"proteins per 100g/100ml in {PROTEIN_UNIT}"
    wanted_energy_kcal_field = f"energy-kcal per 100g/100ml in {ENERGY_UNIT}"
    wanted_vitamin_c_field = (
        f"Vitamin C, total ascorbic acid per 100g/100ml in {VITAMIN_C_UNIT}"
    )
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

    assert set(res.keys()) == {f"{SUGARS_OFF_MATCH} per 100g/100ml in {SUGARS_UNIT}"}


def test_parse_product_base_data_preparation_state_code_not_prepared_defaults_to_as_sold():
    product = {
        "gtinUpc": PRODUCT_BARCODE,
        "description": PRODUCT_DESCRIPTION,
        "modifiedDate": PRODUCT_MODIFIED_DATE,
        "brandedFoodCategory": PRODUCT_FDC_CATEGORY,
        "preparationStateCode": "READY_TO_EAT",
    }
    with patch("script.mappers.convert_to_seconds"):
        res = parse_product_base_data(product)

    assert res.get("preparationStateCode") == "as_sold"  # Non prepared values default to as_sold


def test_parse_product_base_data_preparation_state_code_empty_defaults_to_as_sold():
    product = {
        "gtinUpc": PRODUCT_BARCODE,
        "description": PRODUCT_DESCRIPTION,
        "modifiedDate": PRODUCT_MODIFIED_DATE,
        "brandedFoodCategory": PRODUCT_FDC_CATEGORY,
        "preparationStateCode": "",
    }
    with patch("script.mappers.convert_to_seconds"):
        res = parse_product_base_data(product)

    assert res.get("preparationStateCode") == "as_sold"  


def test_parse_product_base_data_preparation_state_code_whitespace_defaults_to_as_sold():
    product = {
        "gtinUpc": PRODUCT_BARCODE,
        "description": PRODUCT_DESCRIPTION,
        "modifiedDate": PRODUCT_MODIFIED_DATE,
        "brandedFoodCategory": PRODUCT_FDC_CATEGORY,
        "preparationStateCode": "   ",
    }
    with patch("script.mappers.convert_to_seconds"):
        res = parse_product_base_data(product)

    assert res.get("preparationStateCode") == "as_sold" 


def test_parse_product_base_data_preparation_state_code_prepared_is_kept():
    product = {
        "gtinUpc": PRODUCT_BARCODE,
        "description": PRODUCT_DESCRIPTION,
        "modifiedDate": PRODUCT_MODIFIED_DATE,
        "brandedFoodCategory": PRODUCT_FDC_CATEGORY,
        "preparationStateCode": "prepared",
    }
    with patch("script.mappers.convert_to_seconds"):
        res = parse_product_base_data(product)

    assert res.get("preparationStateCode") == "prepared"  


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
