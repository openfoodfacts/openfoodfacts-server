# DIVINFOOD: New biodiversity information in the Open Food Facts food products database

## Introduction

The Open Food Facts database is a collaborative, free and open database of food products from around the world. It contains information about ingredients, nutrition facts, allergens, and more. The database is used by researchers, developers, and consumers to learn about the food they eat.

Over the course of the DIVINFOOD EU project (2022-2026), we extended the Open Food Facts database with information about biodiversity in food products, and in particular the presence of Neglected and Underutilized Crops (NUCs) in the ingredients lists of food products. This information is useful for consumers who want to make informed choices about the food they eat, and for researchers who want to analyze the prevalence of NUCs in food products and their impact on biodiversity.

This document describes how we detect NUCs in food products, how prevalent they are in the Open Food Facts database, and how to access this information in the Open Food Facts database and API.

## How we detect Neglected and Underutilize Crops (NUCs) in food products

Open Food Facts gathers raw data about food products, such as labels, ingredients lists, nutrition facts, and more. This data is then processed and analyzed to extract useful information. One of the analyses we performed was to detect the presence of Neglected and Underutilized Crops (NUCs) in the ingredients lists of food products.

To identify NUCs in the ingredients lists, we extended the multilingual Open Food Facts taxonomy of ingredients with all the NUCs that we identified in the DIVINFOOD project. DIVINFOOD partners and Open Food Facts contributors provided translations and synonyms of the NUCs in multiple languages, which allowed us to detect them in the ingredients lists of products from different countries.

### NUCs in the Open Food Facts ingredients taxonomy

The source file for the Open Food Facts ingredients taxonomy is available in the Open Food Facts GitHub repository:
https://github.com/openfoodfacts/openfoodfacts-server/blob/main/taxonomies/food/ingredients.txt

NUCs are identified with the property rare_crop:en: yes

Example entry for grass pea in the ingredients taxonomy:

```
< en:pea
en: grass pea, grasspea, grass peas, cicerchia, blue sweet pea, chickling pea
de: Saat-Platterbse
es: almorta, Chícharo, chicharo
fi: peltonätkelmä
fr: pois carré, pois carrés, gesse
hr: trava grašak
hu: szegletes lednek, szeges lednek
it: cicerchia
la: lathyrus sativus
pt: chícharo
sv: plattvial
rare_crop:en: yes
```  

The ingredients taxonomy is open source and collaborative, and improvements such as new entries, translations, and synonyms are submitted by contributors every day. New NUCs or new translations of existing NUCs can be added to the ingredients taxonomy by submitting a pull request to the Open Food Facts GitHub repository. All changes to the ingredients taxonomy are reviewed by Open Food Facts contributors before being merged, to ensure the quality of the taxonomy.

### Identification of NUCs in the ingredients lists of food products

Using the taxonomy, we added a new field in the Open Food Facts database to indicate whether a product contains a NUC in its ingredients list. The field is misc_tags = en:ingredients-contain-rare-crops

This field can be used when users of the Open Food Facts app or 3rd party apps using the Open Food Facts API scan or search for food products, to easily identify products that contain NUCs in their ingredients lists.

This field is also available as a facet to easily filter products that contain NUCs in their ingredients lists and analyze the prevalence of NUCs in food products in different countries and categories.

## How prevalent are NUCs in food products from the Open Food Facts database?

### Prevalence of NUCs in food products

As of June 2026, there are 33,511 products in the Open Food Facts database that contain a NUC in their ingredients list (out of 1,270,287 products that have an ingredients list in the Open Food Facts database). This represents 2.6% of the products with an ingredients list in the database.

Source: https://world.openfoodfacts.org/facets/misc/ingredients-contain-rare-crops (products with NUCs in their ingredients lists)
Source: https://world.openfoodfacts.org/facets/states/Ingredients%20completed (products with ingredients completed)

#### Countries with the most products in the Open Food Facts database containing NUCs in their ingredients lists

Note that Open Food Facts has many more products from some countries than others, so the number of products containing NUCs in their ingredients lists is not directly comparable between countries. For example, there are many more products from France in the database than from other countries, which explains why France has the most products containing NUCs in their ingredients lists.

Country	Products	*
France	10978	
United States	7726	
Germany	4120	
United Kingdom	3153	
Italy	1919	
Spain	1670	
Belgium	1121	
Netherlands	1084	
Switzerland	991	
world	986	
Canada	603	
Australia	529	
Ireland	405	
Poland	383	
Austria	330	
India	225	
Bulgaria	208	
Portugal	180	
Finland	177	
Sweden	174	
Mexico	134	
Romania	124	
Czech Republic	124	
New Zealand	120	
Brazil	103	
Luxembourg	88	
Hungary	82	
Croatia	68	
Greece	60	
Norway	54	
Denmark	51

Source: https://world.openfoodfacts.org/facets/misc/ingredients-contain-rare-crops/countries

## DIVINFOOD biodiversity knowledge panel in the Open Food Facts website and app

In addition to raw and enriched product data for food products (such as the ingredients list and the presence of NUCs in the ingredients list), Open Food Facts also provide knowledge panels that turn the raw data into useful information for consumers. For example, when a user scans a product with the Open Food Facts app or visits a product page on the Open Food Facts website, they can see a knowledge panel that indicates whether the product contains NUCs, with information on what NUCs are and why they are important for biodiversity.

Example product: https://world.openfoodfacts.org/product/3268350120824/biscuits-equi-libre-petit-epeautre-et-chocolat-le-moulin-du-pivert

## How to access the NUC information in the Open Food Facts database and API?

NUC information is available in the Open Food Facts database dumps and in the Open Food Facts API in the JSON format.
For information on how to access the Open Food Facts database dumps and API, see https://world.openfoodfacts.org/data

### Presence of NUCs in the ingredients list

The presence of NUCs in the ingredients list is indicated by the field "misc_tags" with the value "en:ingredients-contain-rare-crops"

### Detailed analysis of ingredients

The "ingredients" structure contains data for all ingredients and sub-ingredients in the ingredients list, with the taxonomy tags for each ingredient (including NUCs). The quantity of each ingredient is estimated (if not specified in the ingredient list) and indicated. This allows developers to analyze the ingredients lists of products in detail and identify the presence of NUCs, as well as their estimated quantity in the product.

### DIVINFOOD biodiversity knowledge panel

The DIVINFOOD biodiversity knowledge panel is available in the "knowledge_panels" structure of the product data, with the key "ingredients_rare_crops". It contains information on whether the product contains NUCs, which NUCs are present, and information on what NUCs are and why they are important for biodiversity.

## Feedback from Open Food Facts app users - Survey

We conducted a survey with DIVINFOOD partners and stakeholders and with Open Food Facts users to gather feedback on the usefulness of the NUC information in the Open Food Facts database, website and app, and to identify areas for improvement. The survey was conducted online and promoted through the Open Food Facts website, app, and social media channels, as well as through DIVINFOOD partners and stakeholders.

We received 1806 responses to the survey from January to March 2026. The feedback from the survey was very positive, with many users finding the NUC information useful and informative. Some users also provided suggestions for improvement, such as adding more information on the specific NUCs present in products, and providing more educational content on NUCs and their importance for biodiversity.

## Funding

DIVINFOOD has been funded from the European Union’s Horizon 2020 research and innovation programme under the Grant Agreement N°101000383