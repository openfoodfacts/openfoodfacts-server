# Forest Footprint Data Files (2026)

## Overview

This directory contains CSV files that provide input data to compute the forest footprint of products, according to the formula created by the French nonprofit "Envol Vert".

The first version of the forest footprint targeted only products containing chicken or eggs (as hens often consume imported soy that causes deforestation). The 2026 version of the forest footprint is being developed to cover a wider range of products and ingredients, including cocoa, coffee, and palm oil.

## Files in This Directory

This directory contains mapping tables to link ingredients of food products to their corresponding forest footprint data.

## Input ids and canonical ids

Envol Vert provides French names for ingredients, labels etc. They are identified with columns ending with "_fr". The corresponding canonical ids are in columns ending with "_id". The canonical ids can be automatically updated from the French names using the script scripts/convert_forest_footprint_2026.pl

## Files

### Ingredient to ingredient category mapping - ingredient.ingredient_category.equivalence.tsv

Maps an OFF ingredient (e.g. en:cocoa-butter) to an ingredient category (e.g. en:cocoa-paste). The equivalence factor is used to specify the that the ingredient corresponds to a different quantity of the ingredient category .

### Ingredient category to primary ingredient mapping - ingredient_category.primary_ingredient.equivalence.tsv

Maps an ingredient category (e.g. en:cocoa-paste) to a primary ingredient (e.g. en:cocoa). The equivalence factor is used to specify the that the ingredient category corresponds to a different quantity of the primary ingredient.

### label.primary_ingredient.risk.tsv

Maps a label (e.g. "organic") and a primary ingredient (e.g. en:cocoa) to a deforestation risk factor. 100% indicates that the label does not reduce the deforestation risk, while 0% indicates that the label completely eliminates the deforestation risk.

### origin.primary_ingredient.footprint.tsv

Maps the origin of a primary ingredient (e.g. en:cocoa) to its forest footprint.