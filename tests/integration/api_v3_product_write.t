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
		test_case => 'post-no-body',
		method => 'POST',
		path => '/api/v3/product/1234567890002',
	},
	{
		test_case => 'post-broken-json-body',
		method => 'POST',
		path => '/api/v3/product/1234567890003',
		body => 'not json'
	},
	{
		test_case => 'post-no-product',
		method => 'POST',
		path => '/api/v3/product/1234567890004',
		body => '{}'
	},
	{
		test_case => 'post-empty-product',
		method => 'POST',
		path => '/api/v3/product/1234567890005',
		body => '{"product":{}}'
	},
	{
		test_case => 'post-packagings-add-not-array',
		method => 'POST',
		path => '/api/v3/product/1234567890006',
		body => '{"product": {"packagings_add": {"shape": "bottle"}}}'
	},
	{
		test_case => 'post-packagings-add-one-component',
		method => 'POST',
		path => '/api/v3/product/1234567890007',
		body => '{"product": {"fields": "updated", "packagings_add": [{"shape": "bottle"}]}}'
	},
	{
		test_case => 'post-packagings-add-components-to-existing-product',
		method => 'POST',
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
		test_case => 'post-packagings-fr-fields',
		method => 'POST',
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
		test_case => 'post-packagings-quantity-and-weight',
		method => 'POST',
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
		test_case => 'post-replace-packagings',
		method => 'POST',
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
		test_case => 'post-request-fields-undef',
		method => 'POST',
		path => '/api/v3/product/1234567890009',
		body => '{
			"tags_lc": "en",
			"product": {
				"packagings": [
					{
						"number_of_units": 1,
						"shape": "bag",
						"material": "plastic",
					},			
				]
			}
		}'
	},
	{
		test_case => 'post-request-fields-none',
		method => 'POST',
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
					},			
				]
			}
		}'
	},
	{
		test_case => 'post-request-fields-updated',
		method => 'POST',
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
					},			
				]
			}
		}'
	},
	{
		test_case => 'post-request-fields-all',
		method => 'POST',
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
					},			
				]
			}
		}'
	},
	{
		test_case => 'post-request-fields-packagings',
		method => 'POST',
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
					},			
				]
			}
		}'
	},
	{
		test_case => 'post-request-fields-ecoscore-data',
		method => 'POST',
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
					},			
				]
			}
		}'
	},		
];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
