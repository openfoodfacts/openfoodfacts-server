#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use ProductOpener::APITest qw/execute_api_tests wait_application_ready/;
use ProductOpener::Test qw/remove_all_products remove_all_users/;
use ProductOpener::TestDefaults qw/:all/;

use File::Basename "dirname";

use Storable qw(dclone);

remove_all_users();

remove_all_products();

wait_application_ready();

# Note: expected results are stored in json files, see execute_api_tests
my $tests_ref = [
	{
		test_case => 'no-tagtype',
		method => 'GET',
		path => '/api/v3/taxonomy_suggestions',
		expected_status_code => 400,
	},
	{
		test_case => 'incorrect-tagtype',
		method => 'GET',
		path => '/api/v3/taxonomy_suggestions?tagtype=not_a_taxonomy',
		expected_status_code => 400,
	},
	{
		test_case => 'categories-no-string',
		method => 'GET',
		path => '/api/v3/taxonomy_suggestions?tagtype=categories',
	},
	{
		test_case => 'categories-string-strawberry',
		method => 'GET',
		path => '/api/v3/taxonomy_suggestions?tagtype=categories&string=strawberry',
	},
	{
		test_case => 'categories-term-strawberry',
		method => 'GET',
		path => '/api/v3/taxonomy_suggestions?tagtype=categories&term=strawberry',
	},
	{
		test_case => 'categories-string-fraise',
		method => 'GET',
		path => '/api/v3/taxonomy_suggestions?tagtype=categories&string=fraise',
	},
	{
		test_case => 'categories-string-fr-fraise',
		method => 'GET',
		path => '/api/v3/taxonomy_suggestions?tagtype=categories&string=fraise&lc=fr',
	},
	{
		test_case => 'categories-string-fr-frais',
		method => 'GET',
		path => '/api/v3/taxonomy_suggestions?tagtype=categories&string=frais&lc=fr',
	},
	{
		test_case => 'categories-string-fr-cafe-accent',
		method => 'GET',
		path => '/api/v3/taxonomy_suggestions?tagtype=categories&string=caf%C3%A9&lc=fr',
	},
	{
		test_case => 'allergens-string-fr-o-get-synonyms',
		method => 'GET',
		path => '/api/v3/taxonomy_suggestions?tagtype=allergens&string=o&lc=fr&get_synonyms=1',
	},
	# Packaging suggestions return most popular suggestions first
	{
		test_case => 'packaging-shapes',
		method => 'GET',
		path => '/api/v3/taxonomy_suggestions?tagtype=packaging_shapes',
	},
	{
		test_case => 'packaging-shapes-fr',
		method => 'GET',
		path => '/api/v3/taxonomy_suggestions?tagtype=packaging_shapes&lc=fr',
	},
	{
		test_case => 'packaging-shapes-string-po',
		method => 'GET',
		path => '/api/v3/taxonomy_suggestions?tagtype=packaging_shapes&string=po',
	},
	{
		test_case => 'packaging-shapes-string-fr-po',
		method => 'GET',
		path => '/api/v3/taxonomy_suggestions?tagtype=packaging_shapes&string=po&lc=fr',
	},
	# Packaging shape suggestions can be specific to a country and categories, and shape
	{
		test_case => 'packaging-shapes-cc-fr',
		method => 'GET',
		path => '/api/v3/taxonomy_suggestions?tagtype=packaging_shapes&cc=fr',
	},
	# categories can contain a comma separated list of taxonomy entry ids, entry name or synonym in the lc language
	{
		test_case => 'packaging-shapes-categories-mango-nectars-beverages',
		method => 'GET',
		path => '/api/v3/taxonomy_suggestions?tagtype=packaging_shapes&categories=mango%20nectars,beverages',
	},
	{
		test_case => 'packaging-shapes-cc-fr-categories-yogurt',
		method => 'GET',
		path => '/api/v3/taxonomy_suggestions?tagtype=packaging_shapes&cc=fr&categories=yogurt',
	},
	{
		test_case => 'packaging-shapes-cc-fr-categories-en-yogurts',
		method => 'GET',
		path => '/api/v3/taxonomy_suggestions?tagtype=packaging_shapes&cc=fr&categories=en:yogurts',
	},
	{
		test_case => 'packaging-shapes-cc-fr-categories-yaourt-fr',
		method => 'GET',
		path => '/api/v3/taxonomy_suggestions?tagtype=packaging_shapes&cc=fr&categories=yaourt&lc=fr',
	},
	# Packaging materials suggestions can be specific to a country and categories, and shape
	{
		test_case => 'packaging-materials',
		method => 'GET',
		path => '/api/v3/taxonomy_suggestions?tagtype=packaging_materials',
	},
	{
		test_case => 'packaging-materials-cc-fr',
		method => 'GET',
		path => '/api/v3/taxonomy_suggestions?tagtype=packaging_materials&cc=fr',
	},
	{
		test_case => 'packaging-materials-cc-fr-shape-pot',
		method => 'GET',
		path => '/api/v3/taxonomy_suggestions?tagtype=packaging_materials&cc=fr&shape=pot',
	},
	{
		test_case => 'packaging-materials-cc-fr-categories-yaourt-shape-pot',
		method => 'GET',
		path => '/api/v3/taxonomy_suggestions?tagtype=packaging_materials&cc=fr&categories=yogurts&shape=pot',
	},
	# match with xx: synonyms
	{
		test_case => 'packaging-materials-1',
		method => 'GET',
		path => '/api/v3/taxonomy_suggestions?tagtype=packaging_materials&string=1',
	},
	{
		test_case => 'packaging-materials-01',
		method => 'GET',
		path => '/api/v3/taxonomy_suggestions?tagtype=packaging_materials&string=01',
	},
	{
		test_case => 'packaging-materials-1-pet',
		method => 'GET',
		path => '/api/v3/taxonomy_suggestions?tagtype=packaging_materials&string=1-pet',
	},
	{
		test_case => 'packaging-materials-pet-1',
		method => 'GET',
		path => '/api/v3/taxonomy_suggestions?tagtype=packaging_materials&string=pet-1',
	},
	# Packaging recycling
	{
		test_case => 'packaging-recycling-fr-recy',
		method => 'GET',
		path => '/api/v3/taxonomy_suggestions?tagtype=packaging_recycling&cc=fr&string=recy',
	},
	{
		test_case => 'packaging-recycling-fr-bac-ver',
		method => 'GET',
		path => '/api/v3/taxonomy_suggestions?tagtype=packaging_recycling&cc=fr&string=bac-ver',
	},
	{
		test_case => 'packaging-recycling-fr-bac-verre',
		method => 'GET',
		path => '/api/v3/taxonomy_suggestions?tagtype=packaging_recycling&cc=fr&string=bac-verre',
	},
	{
		test_case => 'packaging-recycling-fr-bac-tri',
		method => 'GET',
		path => '/api/v3/taxonomy_suggestions?tagtype=packaging_recycling&cc=fr&string=bac-tri',
	},
	# packaging codes / EMB codes: not a taxonomy, but can have suggestions too
	{
		test_case => 'emb-codes',
		method => 'GET',
		path => '/api/v3/taxonomy_suggestions?tagtype=emb_codes&string=fr%2056',
	},
	# suggestions with synonyms
	{
		test_case => 'categories-string-fr-tart-get-synonyms',
		method => 'GET',
		path => '/api/v3/taxonomy_suggestions?tagtype=categories&string=tart&lc=fr&get_synonyms=1',
	}
];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
