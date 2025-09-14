# OpenAPI Documentation TODO List

## Include these missing fields into the product response (for v2 API first)

### General Product Information

**Basic Fields:**
- `url` - Product URL
- `created_datetime` - Creation timestamp
- `last_modified_datetime` - Last modification timestamp
- `image_small_url` - Small image URL

**Categorization & Labels:**
- `categories_fr` - French categories
- `labels_fr` - French labels
- `main_category` - Primary category
- `main_category_fr` - Primary category (French)

**Geographic & Additional Info:**
- `first_packaging_code_geo` - Geographic packaging code
- `cities` - Associated cities
- `countries_fr` - Countries (French)
- `no_nutriments` - Nutriment availability flag
- `additives` - Additives information
- `ingredients_from_palm_oil` - Palm oil ingredients

### Nutritional Components (per 100g)

**Proteins & Carbohydrates:**
- `casein_100g` - Casein content
- `serum-proteins_100g` - Serum proteins
- `nucleotides_100g` - Nucleotides
- `fiber_100g` - Dietary fiber

**Sugars & Carbohydrates:**
- `sucrose_100g` - Sucrose
- `glucose_100g` - Glucose  
- `fructose_100g` - Fructose
- `lactose_100g` - Lactose
- `maltose_100g` - Maltose
- `maltodextrins_100g` - Maltodextrins
- `starch_100g` - Starch
- `polyols_100g` - Sugar alcohols

**Other Nutrients:**
- `caffeine_100g` - Caffeine content
- `taurine_100g` - Taurine content
- `ph_100g` - pH level
- `fruits-vegetables-nuts_100g` - Fruits/vegetables/nuts percentage

### Fatty Acids (per 100g)

**General Fats:**
- `fat_100g` - Total fat
- `trans-fat_100g` - Trans fat
- `cholesterol_100g` - Cholesterol

**Saturated Fatty Acids:**
- `butyric-acid_100g` - Butyric acid
- `caproic-acid_100g` - Caproic acid
- `caprylic-acid_100g` - Caprylic acid
- `capric-acid_100g` - Capric acid
- `lauric-acid_100g` - Lauric acid
- `myristic-acid_100g` - Myristic acid
- `palmitic-acid_100g` - Palmitic acid
- `stearic-acid_100g` - Stearic acid
- `arachidic-acid_100g` - Arachidic acid
- `behenic-acid_100g` - Behenic acid
- `lignoceric-acid_100g` - Lignoceric acid
- `cerotic-acid_100g` - Cerotic acid
- `montanic-acid_100g` - Montanic acid
- `melissic-acid_100g` - Melissic acid

**Unsaturated Fatty Acids:**
- `monounsaturated-fat_100g` - Monounsaturated fat
- `polyunsaturated-fat_100g` - Polyunsaturated fat

**Omega Fatty Acids:**
- `omega-3-fat_100g` - Omega-3 fat
- `alpha-linolenic-acid_100g` - Alpha-linolenic acid
- `eicosapentaenoic-acid_100g` - EPA
- `docosahexaenoic-acid_100g` - DHA
- `omega-6-fat_100g` - Omega-6 fat
- `linoleic-acid_100g` - Linoleic acid
- `arachidonic-acid_100g` - Arachidonic acid
- `gamma-linolenic-acid_100g` - Gamma-linolenic acid
- `dihomo-gamma-linolenic-acid_100g` - Dihomo-gamma-linolenic acid
- `omega-9-fat_100g` - Omega-9 fat
- `oleic-acid_100g` - Oleic acid
- `elaidic-acid_100g` - Elaidic acid
- `gondoic-acid_100g` - Gondoic acid
- `mead-acid_100g` - Mead acid
- `erucic-acid_100g` - Erucic acid
- `nervonic-acid_100g` - Nervonic acid
- 
### Vitamins (per 100g)

**Fat-Soluble Vitamins:**
- `vitamin-a_100g` - Vitamin A
- `vitamin-d_100g` - Vitamin D
- `vitamin-e_100g` - Vitamin E
- `vitamin-k_100g` - Vitamin K

**Water-Soluble Vitamins:**
- `vitamin-c_100g` - Vitamin C (Ascorbic acid)
- `vitamin-b1_100g` - Vitamin B1 (Thiamine)
- `vitamin-b2_100g` - Vitamin B2 (Riboflavin)
- `vitamin-pp_100g` - Vitamin B3 (Niacin)
- `vitamin-b6_100g` - Vitamin B6 (Pyridoxine)
- `vitamin-b9_100g` - Vitamin B9 (Folate)
- `vitamin-b12_100g` - Vitamin B12 (Cobalamine)
- `biotin_100g` - Biotin (Vitamin B7)
- `pantothenic-acid_100g` - Pantothenic acid (Vitamin B5)

### Minerals & Trace Elements (per 100g)

**Major Minerals:**
- `calcium_100g` - Calcium
- `phosphorus_100g` - Phosphorus
- `magnesium_100g` - Magnesium
- `potassium_100g` - Potassium
- `chloride_100g` - Chloride
- `bicarbonate_100g` - Bicarbonate

**Trace Elements:**
- `iron_100g` - Iron
- `zinc_100g` - Zinc
- `copper_100g` - Copper
- `manganese_100g` - Manganese
- `fluoride_100g` - Fluoride
- `selenium_100g` - Selenium
- `chromium_100g` - Chromium
- `molybdenum_100g` - Molybdenum
- `iodine_100g` - Iodine
- `silica_100g` - Silica

**Nutritional Scores:**
- `carbon-footprint_100g` - Carbon footprint
- `nutrition-score-fr_100g` - French nutrition score
- `nutrition-score-uk_100g` - UK nutrition score

## Sections to be Added

### Authentication

Describe the authentication process for the different enviroments. The error code for wrong user name and password is 403 for now but you still get html response.

### API Conventions

List the readable and writeable fields. Specify that in adding or editing a product only the writable fields can be modified. Also list existing API conventions.

### Country Code

Specify that you can use `ll` and `cc` to limit the results you need to a particular country or language. List all possible country codes and language codes.

### External Links

OpenAPI allows you to add external link to reference where more info can be found.

### Description

Go through all parameters and response fields and check if they have been properly described with suitable examples.

### Reuses

Take out the reuses section from introduction. We are working on something else for that.
