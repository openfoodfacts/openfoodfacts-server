# Explain nutrition data

Product fields:
 - nutrition_data_per: Whether it is per "serving" or "100g"
 - serving_size: Entered data from packaging
 - serving_quantity: Computed value in g


For each nutrient:

 - _value: What was entered
 - _unit: Unit of what was entered
 - _100g: Amount per 100g in original unit
 - _serving: Amount per serving normalised unit
 - _no suffix_: What was entered in normalised unit
 - _label: Entered label for an unknown nutrient?

## Carbon footprint declarations

In the current nutrition schema, the emission unit and the product quantity are
stored separately. To enter `0.48 kg CO₂e/kg` from a package, select **for 1 kg**
in the product edit form and enter `0.48` with the **kg CO₂e** unit (preselected for
this column). The unit identifier is `kg`; `CO₂e` describes the equivalent emissions
measured by the `carbon-footprint` field.

For a food, the **for 1 kg** reference is only available for the carbon footprint:
the other nutrients are declared per 100 g, 100 ml, 1 l or serving. The unit of the
footprint is chosen for each column (e.g. `52 g CO₂e` per 100 ml and `0.48 kg CO₂e`
per 1 kg can be entered side by side). The per references valid for each nutrient are
returned by `get_pers_for_nutrient()` in `ProductOpener::Nutrition`: the product edit form,
the web form / API v2 parameters and the CSV imports all use it, so invalid nutrient and
per combinations are never offered or accepted.

The API v3 declaration is:

```json
{
  "product": {
    "nutrition": {
      "input_sets": [{
        "source": "packaging",
        "preparation": "as_sold",
        "per": "1kg",
        "nutrients": {
          "carbon-footprint": {"value_string": "0.48", "unit": "kg"}
        }
      }]
    }
  }
}
```

This retains the original declaration and normalizes it to `48 g CO₂e/100g`
when the aggregated nutrition set uses a mass reference. A declaration of
`0.31 kg CO₂e/100g` instead uses `per: "100g"` and normalizes to `310 g CO₂e/100g`.

For a drink with nutrition facts per 100 ml and a footprint per **kg**, no density is assumed
(whereas a footprint per 100 g is merged into the aggregated set per 100 ml like all the other nutrients,
as 1 ml is considered to be 1 g). The original footprint is preserved in its input set and displayed
in a separate column with its mass reference. It is omitted from the aggregate
per volume and from the corresponding legacy `nutriments` fields; API clients
should read the native `nutrition.input_sets` declaration in this case.
