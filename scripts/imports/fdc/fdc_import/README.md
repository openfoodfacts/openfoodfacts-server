# Food Data Central Import

This script imports data from the *BrandedFood* database of the USDA's [FoodData Central](https://fdc.nal.usda.gov/).

## How to run

From the *fdc* folder, run 
`uv run python -m fdc_import.main`


### Update download link for the FDC json export

To update the link from which the FDC export is downloaded, change the value of *fdc_json_url* to the wanted link in *config/config.toml*.


### Run script with an input test file

To run with an input test file, change the value of *raw_fdc_json_file* to *fdc_extract.json* (small portion of the FDC json export) or to another wanted file name in *config/config.toml*.



## Export file

Once the command is run, the CSV export file can be found in the *data/export/* folder.
