#!/bin/sh

# Export for the Best Remap EU project

# Note: the main-countries misc tags are not saved in the .sto files,
# so they need to be regenerated before exporting:

# ./update_all_products.pl --query categories_tags=en:breakfast-cereals --compute-main-countries --mongodb-to-mongodb

./export_data.pl --query categories_tags=en:breakfast-cereals --query countries_tags=en:belgium --query misc_tags=-en:main-countries-be-unexpectedly-low-scans,-en:main-countries-be-no-data-in-country-language --extra_fields=ingredients_text_en,ingredients_text_de,ingredients_text_fr,ingredients_text_nl,ingredients_original_tags,scans_2020_unique_scans_n_by_country_be,scans_2020_unique_scans_n_by_country_world > best_remap_202104_be_breakfast_cereals.csv

./export_data.pl --query categories_tags=en:breakfast-cereals --query countries_tags=en:france --query misc_tags=-en:main-countries-fr-unexpectedly-low-scans,-en:main-countries-fr-no-data-in-country-language --extra_fields=ingredients_text_en,ingredients_text_de,ingredients_text_fr,ingredients_text_nl,ingredients_original_tags,scans_2020_unique_scans_n_by_country_fr,scans_2020_unique_scans_n_by_country_world > best_remap_202104_fr_breakfast_cereals.csv

./export_data.pl --query categories_tags=en:breakfast-cereals --query countries_tags=en:the-netherlands --query misc_tags=-en:main-countries-nl-unexpectedly-low-scans,-en:main-countries-nl-no-data-in-country-language --extra_fields=ingredients_text_en,ingredients_text_de,ingredients_text_fr,ingredients_text_nl,ingredients_original_tags,scans_2020_unique_scans_n_by_country_nl,scans_2020_unique_scans_n_by_country_world > best_remap_202104_nl_breakfast_cereals.csv

./export_data.pl --query categories_tags=en:breakfast-cereals --query countries_tags=en:ireland --query misc_tags=-en:main-countries-ie-unexpectedly-low-scans,-en:main-countries-ie-no-data-in-country-language --extra_fields=ingredients_text_en,ingredients_text_de,ingredients_text_fr,ingredients_text_nl,ingredients_original_tags,scans_2020_unique_scans_n_by_country_ie,scans_2020_unique_scans_n_by_country_world > best_remap_202104_ie_breakfast_cereals.csv

./export_data.pl --query categories_tags=en:breakfast-cereals --query countries_tags=en:austria --query misc_tags=-en:main-countries-at-unexpectedly-low-scans,-en:main-countries-at-no-data-in-country-language --extra_fields=ingredients_text_en,ingredients_text_de,ingredients_text_fr,ingredients_text_nl,ingredients_original_tags,scans_2020_unique_scans_n_by_country_at,scans_2020_unique_scans_n_by_country_world > best_remap_202104_at_breakfast_cereals.csv

