#!/bin/sh

# Export for the Best Remap EU project

./export_csv_file.pl --query categories_tags=en:breakfast-cereals --query countries_tags=en:belgium --extra_fields=nutriscore_score,nutriscore_grade,nova_group,pnns_groups_1,pnns_groups_2,categories_tags,labels_tags,countries_tags,scans_2020_unique_scans_n_by_country_be,scans_2020_unique_scans_n_by_country_world > best_remap_202104_be_breakfast_cereals.csv

