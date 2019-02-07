/* 
  Name        : refresh_products_tags.js 
  Description : Refresh products_tags collection by copying *_tags fields from products collection 
  Version     : 1.1
  Usage       : mongo dbname refresh_products_tags.js
  Add in crontab for daily refresh : 
	00 02 * * * /usr/bin/mongo off /etc/mongo/refresh_products_tags.js  >> /var/log/mongodb/refresh_products_tags.log
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
	cities_tags:1
	}},
{"$out": "products_tags"}
]);

// estimatedDocumentCount() is available from mongodb 4.0.3
//print(Date() + ' : ' + db.products_tags.estimatedDocumentCount() + ' products refreshed in products_tags collection.');
print(Date() + ' : ' + db.products_tags.count() + ' products refreshed in products_tags collection.');


print(Date() + ' : Create indexes for products_tags collection (if not already existing)...');
db.products_tags.createIndex({countries_tags: 1}, { background: true });
db.products_tags.createIndex({brands_tags: 1}, { background: true });
db.products_tags.createIndex({categories_tags: 1}, { background: true });
db.products_tags.createIndex({labels_tags: 1}, { background: true });
db.products_tags.createIndex({ingredients_tags: 1}, { background: true });

print(Date() + ' : Refresh done.');
