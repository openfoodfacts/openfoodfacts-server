# Open Api Documentation Todo List

## Include these missing fields into the product response

`url`, `created_datetime`, `last_modified_datetime`,`categories_fr`,`labels_fr`, `first_packaging_code_geo`, `cities`, `countries_fr`, `no_nutriments`, `additives`, `ingredients_from_palm_oil`,`main_category`,`main_category_fr`, `image_small_url`,`casein_100g`, `serum-proteins_100g`, `nucleotides_100g`, `sucrose_100g`, `glucose_100g`, `fructose_100g`, `lactose_100g`, `maltose_100g`,`maltodextrins_100g`, `starch_100g`, `polyols_100g`, `fat_100g`, `butyric-acid_100g`, `caproic-acid_100g`, `caprylic-acid_100g`,`capric-acid_100g`, `lauric-acid_100g`, `myristic-acid_100g`, `palmitic-acid_100g`, `stearic-acid_100g`, `arachidic-acid_100g`,`behenic-acid_100g`, `lignoceric-acid_100g`, `cerotic-acid_100g`, `montanic-acid_100g`, `melissic-acid_100g`,`melissic-acid_100g`, `monounsaturated-fat_100g`, `polyunsaturated-fat_100g`, `omega-3-fat_100g`,  `alpha-linolenic-acid_100g`, `eicosapentaenoic-acid_100g`, `docosahexaenoic-acid_100g`, `omega-6-fat_100g`, `linoleic-acid_100g`, `arachidonic-acid_100g`,`gamma-linolenic-acid_100g`, `dihomo-gamma-linolenic-acid_100g`, `omega-9-fat_100g`, `oleic-acid_100g`, `elaidic-acid_100g`, `gondoic-acid_100g`,`mead-acid_100g`, `erucic-acid_100g`, `nervonic-acid_100g`, `trans-fat_100g`, `cholesterol_100g`, `fiber_100g`, `vitamin-a_100g`, `vitamin-a_100g`, v`itamin-d_100g`, `vitamin-e_100g`, `vitamin-k_100g`,
`vitamin-c_100g`, `vitamin-b1_100g`, `vitamin-b2_100g`, `vitamin-pp_100g`, `vitamin-b6_100g`, `vitamin-b9_100g`, `vitamin-b12_100g`, `biotin_100g`, `pantothenic-acid_100g`, `silica_100g`, `bicarbonate_100g`, `potassium_100g`, `chloride_100g`, `calcium_100g`, `phosphorus_100g`, `iron_100g`, `magnesium_100g`, `zinc_100g`, `copper_100g`, `manganese_100g`, `fluoride_100g`,  `selenium_100g`, `chromium_100g`, `molybdenum_100g`, `iodine_100g`, `caffeine_100g`, `taurine_100g`, `ph_100g`, `fruits-vegetables-nuts_100g`, `carbon-footprint_100g`, `nutrition-score-fr_100g`, `nutrition-score-uk_100g`

## Sections to be Added

### Authentication

Describe the authentication procees for the differnet enviroments. The error code for wrong user name and password is 403 for now but you still get html response.

### API Conventions

List the readable and writeable fields. Specify that in adding or editing a product only the writable fields can be modified. Also list existing API conventions.

### Country Code

Specify that you can use `ll` and `cc` to limit the results you need to a particular country or language. List all possible country codes and language codes.

### External Links

Open api allows you to add external link to reference where more info can be found.

### Description

Go through all parameters and response fields , to see if they have been properly described with suitable examples.

### Reuses

Take out reuses section from introduction, We are working on something else for that.