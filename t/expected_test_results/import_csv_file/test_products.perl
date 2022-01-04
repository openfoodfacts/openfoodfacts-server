# This file is a result for import_csv_file test
# Note: if needed you may use utilitary methods from Test::Deep like supersetof or ignore
use Test::Deep qw/bag ignore/;
[
  {
    'abbreviated_product_name' => 'Lentilles bio',
    'abbreviated_product_name_fr' => 'Lentilles bio',
    'abbreviated_product_name_fr_imported' => 'Lentilles bio',
    'added_countries_tags' => [],
    'allergens' => '',
    'allergens_from_ingredients' => '',
    'allergens_from_user' => '(fr) ',
    'allergens_hierarchy' => [],
    'allergens_tags' => [],
    'amino_acids_tags' => [],
    'brand_owner' => 'Carrefour',
    'brand_owner_imported' => 'Carrefour',
    'brands' => 'Carrefour Bio, Carrefour',
    'brands_imported' => 'Carrefour Bio, Carrefour',
    'brands_tags' => [
      'carrefour-bio',
      'carrefour'
    ],
    'categories' => 'Plant-based foods and beverages, Plant-based foods, Legumes and their products, Cereals and potatoes, Fruits and vegetables based foods, Legumes, Seeds, Legume seeds, Pulses, Lentils, Green lentils',
    'categories_hierarchy' => [
      'en:plant-based-foods-and-beverages',
      'en:plant-based-foods',
      'en:legumes-and-their-products',
      'en:cereals-and-potatoes',
      'en:fruits-and-vegetables-based-foods',
      'en:legumes',
      'en:seeds',
      'en:legume-seeds',
      'en:vegetables-based-foods',
      'en:pulses',
      'en:lentils',
      'en:green-lentils'
    ],
    'categories_imported' => 'Plant-based foods and beverages, Plant-based foods, Legumes and their products, Cereals and potatoes, Fruits and vegetables based foods, Legumes, Seeds, Legume seeds, Vegetables based foods, Pulses, Lentils, Green lentils',
    'categories_lc' => 'fr',
    'categories_properties' => {
      'agribalyse_proxy_food_code:en' => '20585'
    },
    'categories_tags' => [
      'en:plant-based-foods-and-beverages',
      'en:plant-based-foods',
      'en:legumes-and-their-products',
      'en:cereals-and-potatoes',
      'en:fruits-and-vegetables-based-foods',
      'en:legumes',
      'en:seeds',
      'en:legume-seeds',
      'en:vegetables-based-foods',
      'en:pulses',
      'en:lentils',
      'en:green-lentils'
    ],
    'cities_tags' => [
      'chaspuzac-haute-loire-france'
    ],
    'code' => '3270190128403',
    'codes_tags' => [
      'code-13',
      '3270190128xxx',
      '327019012xxxx',
      '32701901xxxxx',
      '3270190xxxxxx',
      '327019xxxxxxx',
      '32701xxxxxxxx',
      '3270xxxxxxxxx',
      '327xxxxxxxxxx',
      '32xxxxxxxxxxx',
      '3xxxxxxxxxxxx'
    ],
    'countries' => 'France',
    'countries_hierarchy' => [
      'en:france'
    ],
    'countries_imported' => 'France',
    'countries_lc' => 'fr',
    'countries_tags' => [
      'en:france'
    ],
    'creator' => 'test-user',
    'data_sources' => 'Producers, Producer - test-org',
    'data_sources_imported' => 'Producers, Producer - test-org',
    'data_sources_tags' => [
      'producers',
      'producer-test-org'
    ],
    'ecoscore_data' => {
      'adjustments' => {
        'origins_of_ingredients' => {
          'aggregated_origins' => [
            {
              'origin' => 'en:unknown',
              'percent' => 100
            }
          ],
          'origins_from_origins_field' => [
            'en:unknown'
          ],
        },
        'packaging' => {
          'packagings' => [
            {
              'ecoscore_material_score' => 0,
              'ecoscore_shape_ratio' => 1,
              'material' => 'en:unknown',
              'shape' => 'en:unknown'
            }
          ],
        },
        'production_system' => {
          'labels' => [
            'fr:ab-agriculture-biologique',
            'en:eu-organic'
          ],
        },
        'threatened_species' => {}
      },
      'agribalyse' => {
        'agribalyse_proxy_food_code' => '20585'
      },
    },
    'editors_tags' => [
      'test-user'
    ],
    'emb_codes' => 'EMB 43062A',
    'emb_codes_imported' => 'EMB 43062A',
    'emb_codes_orig' => 'EMB 43062A',
    'emb_codes_tags' => [
      'emb-43062a'
    ],
    'entry_dates_tags' => [
      '2022-01-04',
      '2022-01',
      '2022'
    ],
    'food_groups' => 'en:vegetables',
    'food_groups_tags' => [
      'en:fruits-and-vegetables',
      'en:vegetables'
    ],
    'generic_name' => 'Lentilles',
    'generic_name_fr' => 'Lentilles',
    'generic_name_fr_imported' => 'Lentilles',
    'id' => '3270190128403',
    'informers_tags' => [
      'test-user'
    ],
    'ingredients' => [
      {
        'id' => 'en:green-lentils',
        'labels' => 'en:organic',
        'percent_estimate' => '100',
        'percent_max' => '100',
        'percent_min' => '100',
        'text' => 'Lentilles vertes',
        'vegan' => 'yes',
        'vegetarian' => 'yes'
      }
    ],
    'ingredients_analysis_tags' => [
      'en:palm-oil-free',
      'en:vegan',
      'en:vegetarian'
    ],
    'ingredients_from_or_that_may_be_from_palm_oil_n' => 0,
    'ingredients_from_palm_oil_n' => 0,
    'ingredients_from_palm_oil_tags' => [],
    'ingredients_hierarchy' => [
      'en:green-lentils',
      'en:legume',
      'en:lentils'
    ],
    'ingredients_n' => '1',
    'ingredients_n_tags' => [
      '1',
      '1-10'
    ],
    'ingredients_original_tags' => [
      'en:green-lentils'
    ],
    'ingredients_percent_analysis' => 1,
    'ingredients_tags' => [
      'en:green-lentils',
      'en:legume',
      'en:lentils'
    ],
    'ingredients_text' => 'Lentilles vertes issues de l\'agriculture biologique.',
    'ingredients_text_fr' => 'Lentilles vertes issues de l\'agriculture biologique.',
    'ingredients_text_fr_imported' => 'Lentilles vertes issues de l\'agriculture biologique.',
    'ingredients_text_with_allergens' => 'Lentilles vertes issues de l\'agriculture biologique.',
    'ingredients_text_with_allergens_fr' => 'Lentilles vertes issues de l\'agriculture biologique.',
    'labels' => 'Organic, EU Organic, FR-BIO-01, AB Agriculture Biologique, Agriculture France',
    'labels_hierarchy' => [
      'en:organic',
      'en:eu-organic',
      'en:fr-bio-01',
      'fr:ab-agriculture-biologique',
      'fr:Agriculture France'
    ],
    'labels_imported' => 'Organic, EU Organic, FR-BIO-01, AB Agriculture Biologique, Agriculture France, en:organic',
    'labels_lc' => 'fr',
    'labels_tags' => [
      'en:organic',
      'en:eu-organic',
      'en:fr-bio-01',
      'fr:ab-agriculture-biologique',
      'fr:agriculture-france'
    ],
    'lang' => 'fr',
    'lang_imported' => 'fr',
    'languages' => {
      'en:french' => 5
    },
    'languages_codes' => {
      'fr' => 5
    },
    'languages_hierarchy' => [
      'en:french'
    ],
    'languages_tags' => [
      'en:french',
      'en:1'
    ],
    'last_edit_dates_tags' => [
      '2022-01-04',
      '2022-01',
      '2022'
    ],
    'last_editor' => 'test-user',
    'last_modified_by' => 'test-user',
    'last_modified_t' => ignore(),
    'lc' => 'fr',
    'lc_imported' => 'fr',
    'link' => 'https://www.carrefour.fr/p/lentilles-bio-vertes-carrefour-bio-3270190128403',
    'link_imported' => 'https://www.carrefour.fr/p/lentilles-bio-vertes-carrefour-bio-3270190128403',
    'main_countries_tags' => [],
    'manufacturing_places' => 'Chaspuzac, Haute-Loire, Auvergne, France',
    'manufacturing_places_imported' => 'Chaspuzac,Haute-Loire,Auvergne,France',
    'manufacturing_places_tags' => [
      'chaspuzac',
      'haute-loire',
      'auvergne',
      'france'
    ],
    'minerals_tags' => [],
    'nova_group' => 1,
    'nova_groups' => '1',
    'nova_groups_tags' => [
      'en:1-unprocessed-or-minimally-processed-foods'
    ],
    'nutriments' => {
      'energy' => 1409,
      'energy-kcal' => 333,
      'energy-kcal_100g' => 333,
      'energy-kcal_unit' => 'kcal',
      'energy-kcal_value' => 333,
      'energy-kj' => 1409,
      'energy-kj_100g' => 1409,
      'energy-kj_unit' => 'kJ',
      'energy-kj_value' => 1409,
      'energy_100g' => 1409,
      'energy_unit' => 'kJ',
      'energy_value' => 1409,
      'fruits-vegetables-nuts-estimate-from-ingredients_100g' => 0,
      'fruits-vegetables-nuts-estimate-from-ingredients_serving' => 0,
      'nova-group' => 1,
      'nova-group_100g' => 1,
      'nova-group_serving' => 1
    },
    'nutrition_data' => 'on',
    'nutrition_data_per' => '100g',
    'nutrition_data_prepared_per' => '100g',
    'origins' => 'France',
    'origins_hierarchy' => [
      'en:france'
    ],
    'origins_imported' => 'France',
    'origins_lc' => 'fr',
    'origins_tags' => [
      'en:france'
    ],
    'owner' => 'org-test-org',
    'owner_fields' => {
      'abbreviated_product_name_fr' => ignore(),
      'brand_owner' => ignore(),
      'brands' => ignore(),
      'categories' => ignore(),
      'countries' => ignore(),
      'data_sources' => ignore(),
      'emb_codes' => ignore(),
      'energy-kcal' => ignore(),
      'energy-kj' => ignore(),
      'generic_name_fr' => ignore(),
      'ingredients_text_fr' => ignore(),
      'labels' => ignore(),
      'lang' => ignore(),
      'lc' => ignore(),
      'link' => ignore(),
      'manufacturing_places' => ignore(),
      'origins' => ignore(),
      'packaging' => ignore(),
      'packaging_text_fr' => ignore(),
      'periods_after_opening' => ignore(),
      'producer_product_id' => ignore(),
      'producer_version_id' => ignore(),
      'product_name_fr' => ignore(),
      'stores' => ignore(),
      'traces' => ignore()
    },
    'owners_tags' => 'org-test-org',
    'packaging' => 'carton',
    'packaging_imported' => 'carton',
    'packaging_tags' => [
      'carton'
    ],
    'packaging_text' => "boite carton \x{e0} recycler",
    'packaging_text_fr' => "boite carton \x{e0} recycler",
    'packaging_text_fr_imported' => "boite carton \x{e0} recycler",
    'periods_after_opening' => '48 mois',
    'periods_after_opening_hierarchy' => [
      'en:48-months'
    ],
    'periods_after_opening_imported' => '48 mois',
    'periods_after_opening_lc' => 'fr',
    'periods_after_opening_tags' => [
      'en:48-months'
    ],
    'photographers_tags' => [],
    'producer_product_id' => 'xb22-a33',
    'producer_product_id_imported' => 'xb22-a33',
    'producer_version_id' => '34',
    'producer_version_id_imported' => '34',
    'product_name' => 'Lentilles vertes Bio',
    'product_name_fr' => 'Lentilles vertes Bio',
    'product_name_fr_imported' => 'Lentilles vertes Bio',
    'sources' => [
      {
        'fields' => bag(
          'product_name_fr',
          'abbreviated_product_name_fr',
          'generic_name_fr',
          'packaging_text_fr',
          'packaging',
          'brands',
          'categories',
          'labels',
          'origins',
          'manufacturing_places',
          'emb_codes',
          'link',
          'stores',
          'countries',
          'producer_product_id',
          'producer_version_id',
          'brand_owner',
          'data_sources',
          'periods_after_opening',
          'traces',
          'ingredients_text_fr',
          'nutrients.energy-kcal_unit',
          'nutrients.energy-kcal_value',
          'nutrients.energy-kj_unit',
          'nutrients.energy-kj_value',
        ),
        'id' => undef,
        'images' => [],
        'manufacturer' => undef,
        'name' => undef,
        'url' => undef,
      }
    ],
    'stores' => 'Carrefour',
    'stores_imported' => 'Carrefour',
    'stores_tags' => [
      'carrefour'
    ],
    'traces' => 'en:gluten',
    'traces_from_ingredients' => '',
    'traces_from_user' => '(fr) Gluten',
    'traces_imported' => 'Gluten',
    'traces_lc' => 'fr',
    'traces_tags' => [
      'en:gluten'
    ],
  }
];