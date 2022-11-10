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

# Note: expected results are stored in json files, see execute_api_tests
my $tests_ref = [
	{
		test_case => 'patch-no-body',
		method => 'PATCH',
		path => '/api/v3/product/1234567890002',
	},
	{
		test_case => 'patch-broken-json-body',
		method => 'PATCH',
		path => '/api/v3/product/1234567890003',
		body => 'not json'
	},
	{
		test_case => 'patch-no-product',
		method => 'PATCH',
		path => '/api/v3/product/1234567890004',
		body => '{}'
	},
	{
		test_case => 'patch-empty-product',
		method => 'PATCH',
		path => '/api/v3/product/1234567890005',
		body => '{"product":{}}'
	},
	{
		test_case => 'patch-packagings-add-not-array',
		method => 'PATCH',
		path => '/api/v3/product/1234567890006',
		body => '{"product": {"packagings_add": {"shape": "bottle"}}}'
	},
	{
		test_case => 'patch-packagings-add-one-component',
		method => 'PATCH',
		path => '/api/v3/product/1234567890007',
		body => '{"product": {"fields": "updated", "packagings_add": [{"shape": "bottle"}]}}'
	},
	# Only the PATCH method is valid, test other methods
	{
		test_case => 'post-packagings',
		method => 'POST',
		path => '/api/v3/product/1234567890007',
		body => '{"product": {"fields": "updated", "packagings": [{"shape": "bottle"}]}}'
	},
	{
		test_case => 'put-packagings',
		method => 'PUT',
		path => '/api/v3/product/1234567890007',
		body => '{"product": {"fields": "updated", "packagings": [{"shape": "bottle"}]}}'
	},
	{
		test_case => 'delete-packagings',
		method => 'DELETE',
		path => '/api/v3/product/1234567890007',
		body => '{"product": {"fields": "updated", "packagings": [{"shape": "bottle"}]}}'
	},
	{
		test_case => 'patch-packagings-add-components-to-existing-product',
		method => 'PATCH',
		path => '/api/v3/product/1234567890007',
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
		test_case => 'patch-packagings-fr-fields',
		method => 'PATCH',
		path => '/api/v3/product/1234567890007',
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
	{
		test_case => 'patch-packagings-quantity-and-weight',
		method => 'PATCH',
		path => '/api/v3/product/1234567890008',
		body => '{
			"fields": "updated",
			"tags_lc": "en",
			"product": {
				"packagings_add": [
					{
						"number_of_units": 6,
						"shape": "bottle",
						"material": "PET",
						"quantity_per_unit": "25cl",
						"weight_measured": 10
					},
					{
						"number_of_units": 1,
						"shape": "box",
						"material": "wood",
						"weight_specified": 25.5
					}				
				]
			}
		}'
	},
	{
		test_case => 'patch-replace-packagings',
		method => 'PATCH',
		path => '/api/v3/product/1234567890008',
		body => '{
			"fields": "updated",
			"tags_lc": "en",
			"product": {
				"packagings": [
					{
						"number_of_units": 1,
						"shape": "bag",
						"material": "plastic",
						"weight_measured": 10.5
					},
					{
						"number_of_units": 1,
						"shape": "label",
						"material": "paper",
						"weight_specified": 0.25
					}				
				]
			}
		}'
	},
	{
		test_case => 'patch-request-fields-undef',
		method => 'PATCH',
		path => '/api/v3/product/1234567890009',
		body => '{
			"tags_lc": "en",
			"product": {
				"packagings": [
					{
						"number_of_units": 1,
						"shape": "bag",
						"material": "plastic",
					}
				]
			}
		}'
	},
	{
		test_case => 'patch-request-fields-none',
		method => 'PATCH',
		path => '/api/v3/product/1234567890009',
		body => '{
			"fields": "none",
			"tags_lc": "en",
			"product": {
				"packagings": [
					{
						"number_of_units": 1,
						"shape": "bag",
						"material": "plastic",
					}
				]
			}
		}'
	},
	{
		test_case => 'patch-request-fields-updated',
		method => 'PATCH',
		path => '/api/v3/product/1234567890009',
		body => '{
			"fields": "updated",
			"tags_lc": "en",
			"product": {
				"packagings": [
					{
						"number_of_units": 1,
						"shape": "bag",
						"material": "plastic",
					}
				]
			}
		}'
	},
	{
		test_case => 'patch-request-fields-all',
		method => 'PATCH',
		path => '/api/v3/product/1234567890009',
		body => '{
			"fields": "updated",
			"tags_lc": "en",
			"product": {
				"packagings": [
					{
						"number_of_units": 1,
						"shape": "bag",
						"material": "plastic",
					}
				]
			}
		}'
	},
	{
		test_case => 'patch-request-fields-packagings',
		method => 'PATCH',
		path => '/api/v3/product/1234567890009',
		body => '{
			"fields": "packagings",
			"tags_lc": "en",
			"product": {
				"packagings": [
					{
						"number_of_units": 1,
						"shape": "bag",
						"material": "plastic",
					}
				]
			}
		}'
	},
	{
		test_case => 'patch-request-fields-ecoscore-data',
		method => 'PATCH',
		path => '/api/v3/product/1234567890009',
		body => '{
			"fields": "ecoscore_data",
			"tags_lc": "en",
			"product": {
				"packagings": [
					{
						"number_of_units": 1,
						"shape": "bag",
						"material": "plastic",
					}
				]
			}
		}'
	},
];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
