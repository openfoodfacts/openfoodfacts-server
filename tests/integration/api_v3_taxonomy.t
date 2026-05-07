#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use ProductOpener::APITest qw/execute_api_tests wait_application_ready/;
use ProductOpener::Test qw/remove_all_products remove_all_users/;
use ProductOpener::TestDefaults qw/:all/;

use File::Basename "dirname";

use Storable qw(dclone);

wait_application_ready(__FILE__);
remove_all_products();
remove_all_users();

# Note: expected results are stored in json files, see execute_api_tests
my $tests_ref = [
	# taxonomy_canonicalize_tags
	{
		test_case => 'canonicalize-no-tagtype',
		method => 'GET',
		path => '/api/v3/taxonomy_canonicalize_tags',
		expected_status_code => 400,
	},
	{
		test_case => 'canonicalize-incorrect-tagtype',
		method => 'GET',
		path => '/api/v3/taxonomy_canonicalize_tags?tagtype=not_a_taxonomy',
		expected_status_code => 400,
	},
	{
		test_case => 'canonicalize-ingredients-no-local-tags-list',
		method => 'GET',
		path => '/api/v3/taxonomy_canonicalize_tags?tagtype=ingredients',
		expected_status_code => 400,
	},
	{
		test_case => 'canonicalize-ingredients-local-tags-list',
		method => 'GET',
		path =>
			'/api/v3/taxonomy_canonicalize_tags?tagtype=ingredients&lc=fr&local_tags_list=banane,en:pineapple,petits pois, épinards, unknown ingredient,de:Other Unknown Ingredient',
	},
	# taxonomy_display_tags
	{
		test_case => 'display-no-tagtype',
		method => 'GET',
		path => '/api/v3/taxonomy_display_tags',
		expected_status_code => 400,
	},
	{
		test_case => 'display-incorrect-tagtype',
		method => 'GET',
		path => '/api/v3/taxonomy_display_tags?tagtype=not_a_taxonomy',
		expected_status_code => 400,
	},
	{
		test_case => 'display-ingredients-no-canonical-tags-list',
		method => 'GET',
		path => '/api/v3/taxonomy_display_tags?tagtype=ingredients',
		expected_status_code => 400,
	},
	{
		test_case => 'display-ingredients-canonical-tags-list',
		method => 'GET',
		path =>
			'/api/v3/taxonomy_display_tags?tagtype=ingredients&lc=fr&canonical_tags_list=en:banana,en:pineapple, en:garden-peas, en:spinach,fr:unknown ingredient, de:Other Unknown Ingredient',
	},
];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
