import re
from collections import defaultdict

from ..utils import convert_to_seconds


def normalize_empty_string(value):
    if value is None:
        return None
    text = str(value).strip()
    return text if text else None


def parse_product_serving_size(
    household_serving_full_text_value: str,
    serving_size_value: str,
    serving_size_unit_value: str,
) -> str:
    household_serving_full_text = normalize_empty_string(
        household_serving_full_text_value
    )
    serving_size_value = normalize_empty_string(serving_size_value)
    serving_size_unit = normalize_empty_string(serving_size_unit_value)

    if household_serving_full_text and serving_size_value and serving_size_unit:
        serving_size_with_unit = f"{serving_size_value} {serving_size_unit}"

        household_serving_full_text_normalized = (
            household_serving_full_text.lower().replace(" ", "")
        )
        serving_size_with_unit_normalized = serving_size_with_unit.lower().replace(
            " ", ""
        )

        if household_serving_full_text_normalized == serving_size_with_unit_normalized:
            serving_size_output = serving_size_with_unit
        else:
            serving_size_output = (
                f"{household_serving_full_text} ({serving_size_with_unit})"
            )
    else:
        serving_size_output = None

    return serving_size_output


def parse_product_brand_data(brand_value: str) -> str:
    brand = brand_value
    if brand is not None:
        brand = brand.replace(",", "")
        if brand.strip().lower() in ["", "not a branded item"]:
            brand = None

    return brand


def parse_product_code(code: str) -> str | None:
    parsed_code = code.replace("-", "").replace(" ", "")
    code_pattern = re.compile(r"^[0-9]+$")

    if not code_pattern.match(parsed_code):
        parsed_code = None

    return parsed_code


def parse_product_base_data(product: dict) -> dict:
    fdc_category = product.get("brandedFoodCategory", "")
    fdc_category_without_commas = fdc_category.replace(",", "")

    brand = parse_product_brand_data(product.get("brandName"))
    code = parse_product_code(product.get("gtinUpc", ""))
    serving_size = parse_product_serving_size(
        product.get("householdServingFullText", ""),
        product.get("servingSize", ""),
        product.get("servingSizeUnit", ""),
    )

    preparation_state_code = normalize_empty_string(product.get("preparationStateCode"))
    if preparation_state_code != "prepared":
        preparation_state_code = "as_sold"

    quantity = normalize_empty_string(product.get("packageWeight"))

    row = {
        "code": code,
        "name": normalize_empty_string(product.get("description")),
        "last_updated_t": convert_to_seconds(
            normalize_empty_string(product.get("modifiedDate"))
        ),
        "categories": normalize_empty_string(fdc_category_without_commas),
        "countries": ["United States"],
        "ingredients": normalize_empty_string(product.get("ingredients")),
        "serving_size": serving_size,
        "brands": brand,
        "brand_owner": normalize_empty_string(product.get("brandOwner")),
        "preparationStateCode": preparation_state_code,
        "quantity": quantity,
    }

    return row


def find_preferred_entry(entries: list, code_priority: dict) -> dict | None:
    best_priority = float("inf")
    last_best_entry = None

    for entry in entries:
        entry_code = entry.get("foodNutrientDerivation", {}).get("code")
        priority = code_priority.get(entry_code, float("inf"))

        if priority < best_priority:
            best_priority = priority
            last_best_entry = entry
        elif priority == best_priority:
            last_best_entry = entry

    return last_best_entry


def parse_product_nutrients(product: dict, nutrients_mapping: dict) -> dict:
    row = {}
    food_nutrients = product.get("foodNutrients", [])

    # one same nutrient can have several entries
    # store every entry for each nutrient while preserving the original appearing order
    nutrient_entries_dict = defaultdict(list)
    for nutrient_entry in food_nutrients:
        nutrient_info = nutrient_entry.get("nutrient", {})
        nutrient_name_off = nutrient_info.get("name")
        unit = nutrient_info.get("unitName")

        matched_nutrient_name_off = nutrients_mapping.get(
            nutrient_name_off, nutrient_name_off
        )
        # if off match is energy then we need to add the name of the unit at the end of the name
        # ie we need to have either energy-kcal of energy-kj
        if matched_nutrient_name_off.lower() == "energy" and unit.lower() in [
            "kj",
            "kcal",
        ]:
            matched_nutrient_name_off += f"-{unit.lower()}"

        nutrient_entries_dict[matched_nutrient_name_off].append(nutrient_entry)

    # different sources have different priorities
    # and if several nutrient entries with the same priority, take the last appearing for the nutrient
    source_code_priority = {
        "LCGE": 0,  # Given by information provider as an exact value per 100 unit measure
        "LCGP": 1,  # Given by information provider as a value per 100 unit measure
        "LCGA": 2,  # Given by information provider as an approximate value per 100 unit measure
        "LCGL": 3,  # Given by information provider as a less than value per 100 unit measure
        "LCSE": 4,  # Calculated from an exact value per serving size measure
        "LCCS": 5,  # Calculated from value per serving size measure
        "LCCD": 6,  # Calculated from a daily value percentage per serving size measure
        "LCSA": 7,  # Calculated from an approximate value per serving size measure
        "LCSL": 8,  # Calculated from a less than value per serving size measure
        "LCSG": 9,  # Calculated from a greater than value per serving size measure
    }

    for nutrient_name_off, nutrient_entries in nutrient_entries_dict.items():
        nutrient_entry = find_preferred_entry(nutrient_entries, source_code_priority)

        nutrient_info = nutrient_entry.get("nutrient", {})
        amount = nutrient_entry.get("amount")
        unit = nutrient_info.get("unitName")

        target_col = f"{nutrient_name_off} per 100g/100ml in {unit}"

        if target_col:
            row[target_col] = amount

    return row


def parse_product(product: dict, nutrients_mapping: dict) -> dict:
    """Creates a CSV row from a given product using mapping dicts."""
    base_data = parse_product_base_data(product)
    nutrients_data = parse_product_nutrients(product, nutrients_mapping)
    row = base_data | nutrients_data

    return row
