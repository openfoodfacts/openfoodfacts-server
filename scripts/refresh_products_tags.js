/*global db*/
/*
	Name				: refresh_products_tags.js
	Description : Refresh products_tags collection by copying *_tags fields from products collection
	Version		 : 1.1
	Usage			 : mongo dbname refresh_products_tags.js
	Add in crontab for daily refresh :
	00 02 * * * /usr/bin/mongo off /etc/mongo/refresh_products_tags.js	>> /var/log/mongodb/refresh_products_tags.log
*/

print(Date() + ' : Refresh products_tags collection...');
db.products.aggregate( [
{"$project" :
	{
	creator:1,
	countries_tags:1,
	brands_tags:1,
	categories_tags:1,
	labels_tags:1,
	packaging_tags:1,
	origins_tags:1,
	manufacturing_places_tags:1,
	emb_codes_tags:1,
	ingredients_tags:1,
	additives_tags:1,
	vitamins_tags:1,
	minerals_tags:1,
	amino_acids_tags:1,
	nucleotides_tags:1,
	allergens_tags:1,
	traces_tags:1,
	nova_groups_tags:1,
	nutrition_grades_tags:1,
	languages_tags:1,
	creator_tags:1,
	editors_tags:1,
	states_tags:1,
	entry_dates_tags:1,
	last_edit_dates_tags:1,
	codes_tags:1,
	nutrient_levels_tags:1,
	stores_tags:1,
	informers_tags:1,
	photographers_tags:1,
	checkers_tags:1,
	correctors_tags:1,
	ingredients_from_palm_oil_tags:1,
	ingredients_that_may_be_from_palm_oil_tags:1,
	purchase_places_tags:1,
	ingredients_n_tags:1,
	pnns_groups_1_tags:1,
	pnns_groups_2_tags:1,
	misc_tags:1,
	quality_tags:1,
	unknown_nutrients_tags:1,
	last_image_dates_tags:1,
	cities_tags:1,
	ingredients_analysis_tags:1,
	popularity_tags:1,
	data_sources_tags:1,
	data_quality_tags:1,
	data_quality_bugs_tags:1,
	data_quality_info_tags:1,
	data_quality_warnings_tags:1,
	data_quality_errors_tags:1,
	teams_tags:1,
	categories_properties_tags:1,
	ecoscore_tags:1,
	owners_tags:1,
	food_groups_tags:1,
	weighers_tags:1,
	}},
{"$out": "products_tags"}
]);

// estimatedDocumentCount() is available from mongodb 4.0.3
//print(Date() + ' : ' + db.products_tags.estimatedDocumentCount() + ' products refreshed in products_tags collection.');
print(Date() + ' : ' + db.products_tags.count() + ' products refreshed in products_tags collection.');


print(Date() + ' : Create indexes for products_tags collection (if not already existing)...');

db.products_tags.createIndex({creator:1}, { background: true });
db.products_tags.createIndex({countries_tags:1}, { background: true });
db.products_tags.createIndex({brands_tags:1}, { background: true });
db.products_tags.createIndex({categories_tags:1}, { background: true });
db.products_tags.createIndex({labels_tags:1}, { background: true });
db.products_tags.createIndex({packaging_tags:1}, { background: true });
db.products_tags.createIndex({origins_tags:1}, { background: true });
db.products_tags.createIndex({manufacturing_places_tags:1}, { background: true });
db.products_tags.createIndex({emb_codes_tags:1}, { background: true });
db.products_tags.createIndex({ingredients_tags:1}, { background: true });
db.products_tags.createIndex({additives_tags:1}, { background: true });
db.products_tags.createIndex({vitamins_tags:1}, { background: true });
db.products_tags.createIndex({minerals_tags:1}, { background: true });
db.products_tags.createIndex({amino_acids_tags:1}, { background: true });
db.products_tags.createIndex({nucleotides_tags:1}, { background: true });
db.products_tags.createIndex({allergens_tags:1}, { background: true });
db.products_tags.createIndex({traces_tags:1}, { background: true });
db.products_tags.createIndex({nova_groups_tags:1}, { background: true });
db.products_tags.createIndex({nutrition_grades_tags:1}, { background: true });
db.products_tags.createIndex({languages_tags:1}, { background: true });
db.products_tags.createIndex({creator_tags:1}, { background: true });
db.products_tags.createIndex({editors_tags:1}, { background: true });
db.products_tags.createIndex({states_tags:1}, { background: true });
db.products_tags.createIndex({entry_dates_tags:1}, { background: true });
db.products_tags.createIndex({last_edit_dates_tags:1}, { background: true });
db.products_tags.createIndex({codes_tags:1}, { background: true });
db.products_tags.createIndex({nutrient_levels_tags:1}, { background: true });
db.products_tags.createIndex({stores_tags:1}, { background: true });
db.products_tags.createIndex({informers_tags:1}, { background: true });
db.products_tags.createIndex({photographers_tags:1}, { background: true });
db.products_tags.createIndex({checkers_tags:1}, { background: true });
db.products_tags.createIndex({correctors_tags:1}, { background: true });
db.products_tags.createIndex({ingredients_from_palm_oil_tags:1}, { background: true });
db.products_tags.createIndex({ingredients_that_may_be_from_palm_oil_tags:1}, { background: true });
db.products_tags.createIndex({purchase_places_tags:1}, { background: true });
db.products_tags.createIndex({ingredients_n_tags:1}, { background: true });
db.products_tags.createIndex({pnns_groups_1_tags:1}, { background: true });
db.products_tags.createIndex({pnns_groups_2_tags:1}, { background: true });
db.products_tags.createIndex({misc_tags:1}, { background: true });
db.products_tags.createIndex({quality_tags:1}, { background: true });
db.products_tags.createIndex({unknown_nutrients_tags:1}, { background: true });
db.products_tags.createIndex({last_image_dates_tags:1}, { background: true });
db.products_tags.createIndex({cities_tags:1}, { background: true });
db.products_tags.createIndex({ingredients_analysis_tags:1}, { background: true });
db.products_tags.createIndex({popularity_tags:1}, { background: true });
db.products_tags.createIndex({data_sources_tags:1}, { background: true });
db.products_tags.createIndex({data_quality_tags:1}, { background: true });
db.products_tags.createIndex({data_quality_bugs_tags:1}, { background: true });
db.products_tags.createIndex({data_quality_info_tags:1}, { background: true });
db.products_tags.createIndex({data_quality_warnings_tags:1}, { background: true });
db.products_tags.createIndex({data_quality_errors_tags:1}, { background: true });
db.products_tags.createIndex({teams_tags:1}, { background: true });
db.products_tags.createIndex({categories_properties_tags:1}, { background: true });
db.products_tags.createIndex({owners_tags:1}, { background: true });
db.products_tags.createIndex({ecoscore_tags:1}, { background: true });
db.products_tags.createIndex({nutriscore_score_opposite: -1}, { background: true });
db.products_tags.createIndex({ecoscore_score: -1}, { background: true });
db.products_tags.createIndex({popularity_key: -1}, { background: true });
db.products_tags.createIndex({food_groups_tags:1}, { background: true });

print(Date() + ' : Refresh done.');
