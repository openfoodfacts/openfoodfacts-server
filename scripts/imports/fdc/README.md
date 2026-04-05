# Food Data Central Import

This script imports data from the *BrandedFood* database of the USDA's [FoodData Central](https://fdc.nal.usda.gov/).

## How to run

From the *fdc* folder, run 
`uv run main.py`


### Update download link for the FDC json export

To update the link from which the FDC export is downloaded, change the value of *fdc_json_url* to the wanted link in *config/config.toml*.


### Run script with an input test file

To run with an input test file, change the value of *raw_fdc_json_file* to *fdc_extract.json* (small portion of the FDC json export) or to another wanted file name in *config/config.toml*.



## Export file

Once the command is run, the CSV export file can be found in the *data/export/* folder.

## Statistics and Schema Analysis

The project includes a utility script to analyze the FDC data, count nutrient occurrences, and identify missing mappings.

### How to run statistics

From the *fdc* folder, run:
`uv run stats/scripts/stats.py`

By default, it looks for the data in `fdc/data/fdc.json`. You can specify a different path using the `--input` argument:

### Generated Files

The script produces several files in the locations defined in `config/schema_info.toml`:

*   **nutrient_appearance.json**: JSON files listing every nutrient name found in the FDC export, sorted by total frequency.
*   **nutrient_appearance_by_product.json**: A JSON file describing how many individual products contain each nutrient (avoiding double-counting within the same product).
*   **schema.json**: A JSON file describing the structure found at the top level and within the nutrient entries of the JSON source.
*   **missing_nutrients.csv**: A CSV file describing nutrients found in the source JSON that are not yet mapped in your `nutrient_map.csv`. This is useful for identifying new data to import.