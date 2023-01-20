#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test::More;
use ProductOpener::APITest qw/:all/;
use ProductOpener::Test qw/:all/;
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
	},
	{
		test_case => 'incorrect-tagtype',
		method => 'GET',
		path => '/cgi/suggest.pl?tagtype=not_a_taxonomy',
	},	    
	{
		test_case => 'categories-no-string',
		method => 'GET',
		path => '/api/v3/taxonomy_suggestions?tagtype=categories',
		expected_status_code => 200,
	},
	{
		test_case => 'categories-string-strawberry',
		method => 'GET',
		path => '/api/v3/taxonomy_suggestions?tagtype=categories&string=strawberry',
		expected_status_code => 200,
	},
	{
		test_case => 'categories-string-fraise',
		method => 'GET',
		path => '/api/v3/taxonomy_suggestions?tagtype=categories&string=fraise',
		expected_status_code => 200,
	},
	{
		test_case => 'categories-string-fr-fraise',
		method => 'GET',
		path => '/api/v3/taxonomy_suggestions?tagtype=categories&string=fraise&lc=fr',
		expected_status_code => 200,
	},
	{
		test_case => 'categories-string-fr-frais',
		method => 'GET',
		path => '/api/v3/taxonomy_suggestions?tagtype=categories&string=frais&lc=fr',
		expected_status_code => 200,
	},
	{
		test_case => 'categories-string-fr-cafe-accent',
		method => 'GET',
		path => '/api/v3/taxonomy_suggestions?tagtype=categories&string=Café&lc=fr',
		expected_status_code => 200,
	},
	{
		test_case => 'categories-string-fr-cafe-accent',
		method => 'GET',
		path => '/api/v3/taxonomy_suggestions?tagtype=categories&string=Café&lc=fr',
		expected_status_code => 200,
	},
    # Packaging suggestions return most popular suggestions first
  	{
		test_case => 'packaging-shapes',
		method => 'GET',
		path => '/api/v3/taxonomy_suggestions?tagtype=packaging_shapes',
		expected_status_code => 200,
	}, 
  	{
		test_case => 'packaging-shapes-fr',
		method => 'GET',
		path => '/api/v3/taxonomy_suggestions?tagtype=packaging_shapes&lc=fr',
		expected_status_code => 200,
	},  
];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
