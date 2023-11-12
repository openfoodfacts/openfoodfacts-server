#!/bin/sh

# Export for the Best Remap EU project

# Note: the main-countries misc tags are not saved in the .sto files,
# so they need to be regenerated before exporting:

# ./update_all_products.pl --query categories_tags=en:breakfast-cereals --compute-main-countries --mongodb-to-mongodb

./export_data.pl --query categories_tags=en:breakfast-cereals --query countries_tags=en:france --extra_fields=ingredients_text_en,ingredients_text_de,ingredients_text_fr,ingredients_text_nl,ingredients_original_tags,scans_2020_unique_scans_n_by_country_fr,scans_2020_unique_scans_n_by_country_world,scans_2019_unique_scans_n_by_country_fr,scans_2019_unique_scans_n_by_country_world,scans_2018_unique_scans_n_by_country_fr,scans_2018_unique_scans_n_by_country_world > best_remap_202105_fr_breakfast_cereals.unfiltered.csv

./export_data.pl --query categories_tags=en:breakfast-cereals --query countries_tags=en:france --query misc_tags=-en:main-countries-fr-unexpectedly-low-scans,-en:main-countries-fr-no-data-in-country-language --extra_fields=ingredients_text_en,ingredients_text_de,ingredients_text_fr,ingredients_text_nl,ingredients_original_tags,scans_2020_unique_scans_n_by_country_fr,scans_2020_unique_scans_n_by_country_world,scans_2019_unique_scans_n_by_country_fr,scans_2019_unique_scans_n_by_country_world,scans_2018_unique_scans_n_by_country_fr,scans_2018_unique_scans_n_by_country_world > best_remap_202105_fr_breakfast_cereals.filtered.csv

./export_data.pl --query categories_tags=en:breakfast-cereals --query countries_tags=en:france --query misc_tags=-en:main-countries-fr-unexpectedly-low-scans,-en:main-countries-fr-ingredients-not-in-country-language,-en:main-countries-old-product-without-scans-in-2020 --extra_fields=ingredients_text_en,ingredients_text_de,ingredients_text_fr,ingredients_text_nl,ingredients_original_tags,scans_2020_unique_scans_n_by_country_fr,scans_2020_unique_scans_n_by_country_world,scans_2019_unique_scans_n_by_country_fr,scans_2019_unique_scans_n_by_country_world,scans_2018_unique_scans_n_by_country_fr,scans_2018_unique_scans_n_by_country_world > best_remap_202105_fr_breakfast_cereals.filtered2.csv

./export_data.pl --query categories_tags=en:breakfast-cereals --query countries_tags=en:france --query popularity_tags=at-least-5-fr-scans-2020 --query misc_tags=-en:main-countries-fr-unexpectedly-low-scans,-en:main-countries-fr-ingredients-not-in-country-language,-en:main-countries-old-product-without-scans-in-2020 --extra_fields=ingredients_text_en,ingredients_text_de,ingredients_text_fr,ingredients_text_nl,ingredients_original_tags,scans_2020_unique_scans_n_by_country_fr,scans_2020_unique_scans_n_by_country_world,scans_2019_unique_scans_n_by_country_fr,scans_2019_unique_scans_n_by_country_world,scans_2018_unique_scans_n_by_country_fr,scans_2018_unique_scans_n_by_country_world > best_remap_202105_fr_breakfast_cereals.filtered2.5_fr_scans_2020.csv

./export_data.pl --query categories_tags=en:breakfast-cereals --query countries_tags=en:france --query popularity_tags=at-least-10-fr-scans-2020 --query misc_tags=-en:main-countries-fr-unexpectedly-low-scans,-en:main-countries-fr-ingredients-not-in-country-language,-en:main-countries-old-product-without-scans-in-2020 --extra_fields=ingredients_text_en,ingredients_text_de,ingredients_text_fr,ingredients_text_nl,ingredients_original_tags,scans_2020_unique_scans_n_by_country_fr,scans_2020_unique_scans_n_by_country_world,scans_2019_unique_scans_n_by_country_fr,scans_2019_unique_scans_n_by_country_world,scans_2018_unique_scans_n_by_country_fr,scans_2018_unique_scans_n_by_country_world > best_remap_202105_fr_breakfast_cereals.filtered2.10_fr_scans_2020.csv

