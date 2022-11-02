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

wait_dynamic_front();

my $ua = new_client();

my %create_user_args = (%default_user_form, (email => 'bob@gmail.com'));
create_user($ua, \%create_user_args);

my $tests_ref = [
	{
		test_case => 'get-unexisting-product',
		method => 'GET',
		path => '/api/v3/product/12345678',
	},
	{
		test_case => 'post-no-body',
		method => 'POST',
		path => '/api/v3/product/12345678',
	},
	{
		test_case => 'post-broken-json-body',
		method => 'POST',
		path => '/api/v3/product/12345678',
		body => 'not json'
	},
	{
		test_case => 'post-no-product',
		method => 'POST',
		path => '/api/v3/product/12345678',
		body => '{}'
	},
	{
		test_case => 'post-empty-product',
		method => 'POST',
		path => '/api/v3/product/12345678',
		body => '{"product":{}}'
	},
	{
		test_case => 'post-packagings-add-not-array',
		method => 'POST',
		path => '/api/v3/product/12345678',
		body => '{"product": {"packagings_add": {"shape": "bottle"}}}'
	},
	{
		test_case => 'post-packagings-add-one-component',
		method => 'POST',
		path => '/api/v3/product/12345678',
		body => '{"product": {"fields": "updated", "packagings_add": [{"shape": "bottle"}]}}'
	},
	{
		test_case => 'post-packagings-add-components-to-existing-product',
		method => 'POST',
		path => '/api/v3/product/12345678',
		body => '{
			"fields": "updated",
			"product": {
				"packagings_add": [
					{
						"number_of_units": 2,
						"shape": "en:bottle",
						"material": "plastic",
						"recycling": "strange value"
					},
					{
						"number_of_units": 1,
						"shape": "en:box",
						"material": "cardboard",
						"recycling": "to recycle"
					}				
				]
			}
		}'
	},
	{
		test_case => 'post-packagings-fr-fields',
		method => 'POST',
		path => '/api/v3/product/123456780',
		body => '{
			"fields": "updated",
			"tags_lc": "fr",
			"product": {
				"packagings_add": [
					{
						"number_of_units": 3,
						"shape": "bouteille",
						"material": "plastique"
					},
					{
						"number_of_units": 4,
						"shape": "pot",
						"material": "verre",
						"recycling": "à recycler"
					}				
				]
			}
		}'
	},
];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
