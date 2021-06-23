#!/bin/sh

# Export for the Best Remap EU project
#
# The goal is to be able to filter the products in each country to keep only the products
# that are really intented for sale to this country
#
# Usage:
# ./export_best_remap_cc_country_category.sh fr en:france en:breakfast-cereals

cc=$1
country=$2
category=$3

if [ -z $1 ]
then
  echo "First argument needs to be country code. e.g. fr"
  exit 1
else
  echo "country code: $cc"
fi

if [ -z $2 ]
then
  echo "Second argument needs to be country tag. e.g. en:france"
  exit 1
else
  echo "country tag: $country"
fi

category_suffix=""

if [ ! -z $3 ]
then
  echo "category: $category"
  category_condition="--query categories_tags=$category"
  category_suffix=".$category"
fi


./export_data.pl $category_condition --query countries_tags=$country --extra_fields=ingredients_text_en,ingredients_text_de,ingredients_text_${cc},ingredients_text_nl,ingredients_original_tags,scans_2020_unique_scans_n_by_country_${cc},scans_2020_unique_scans_n_by_country_world,scans_2019_unique_scans_n_by_country_${cc},scans_2019_unique_scans_n_by_country_world,scans_2018_unique_scans_n_by_country_${cc},scans_2018_unique_scans_n_by_country_world > best_remap_202105_${cc}${category_suffix}.unfiltered.csv

./export_data.pl $category_condition --query countries_tags=$country --query misc_tags=-en:main-countries-${cc}-unexpectedly-low-scans,-en:main-countries-${cc}-no-data-in-country-language --extra_fields=ingredients_text_en,ingredients_text_de,ingredients_text_${cc},ingredients_text_nl,ingredients_original_tags,scans_2020_unique_scans_n_by_country_${cc},scans_2020_unique_scans_n_by_country_world,scans_2019_unique_scans_n_by_country_${cc},scans_2019_unique_scans_n_by_country_world,scans_2018_unique_scans_n_by_country_${cc},scans_2018_unique_scans_n_by_country_world > best_remap_202105_${cc}${category_suffix}.filtered.csv

./export_data.pl $category_condition --query countries_tags=$country --query misc_tags=-en:main-countries-${cc}-unexpectedly-low-scans,-en:main-countries-${cc}-ingredients-not-in-country-language,-en:main-countries-old-product-without-scans-in-2020 --extra_fields=ingredients_text_en,ingredients_text_de,ingredients_text_${cc},ingredients_text_nl,ingredients_original_tags,scans_2020_unique_scans_n_by_country_${cc},scans_2020_unique_scans_n_by_country_world,scans_2019_unique_scans_n_by_country_${cc},scans_2019_unique_scans_n_by_country_world,scans_2018_unique_scans_n_by_country_${cc},scans_2018_unique_scans_n_by_country_world > best_remap_202105_${cc}${category_suffix}.filtered2.csv

./export_data.pl $category_condition --query countries_tags=$country --query popularity_tags=at-least-5-${cc}-scans-2020 --query misc_tags=-en:main-countries-${cc}-unexpectedly-low-scans,-en:main-countries-${cc}-ingredients-not-in-country-language,-en:main-countries-old-product-without-scans-in-2020 --extra_fields=ingredients_text_en,ingredients_text_de,ingredients_text_${cc},ingredients_text_nl,ingredients_original_tags,scans_2020_unique_scans_n_by_country_${cc},scans_2020_unique_scans_n_by_country_world,scans_2019_unique_scans_n_by_country_${cc},scans_2019_unique_scans_n_by_country_world,scans_2018_unique_scans_n_by_country_${cc},scans_2018_unique_scans_n_by_country_world > best_remap_202105_${cc}${category_suffix}.filtered2.5_${cc}_scans_2020.csv

./export_data.pl $category_condition --query countries_tags=$country --query popularity_tags=at-least-10-${cc}-scans-2020 --query misc_tags=-en:main-countries-${cc}-unexpectedly-low-scans,-en:main-countries-${cc}-ingredients-not-in-country-language,-en:main-countries-old-product-without-scans-in-2020 --extra_fields=ingredients_text_en,ingredients_text_de,ingredients_text_${cc},ingredients_text_nl,ingredients_original_tags,scans_2020_unique_scans_n_by_country_${cc},scans_2020_unique_scans_n_by_country_world,scans_2019_unique_scans_n_by_country_${cc},scans_2019_unique_scans_n_by_country_world,scans_2018_unique_scans_n_by_country_${cc},scans_2018_unique_scans_n_by_country_world > best_remap_202105_${cc}${category_suffix}.filtered2.10_${cc}_scans_2020.csv


