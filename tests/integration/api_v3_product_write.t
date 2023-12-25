#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test::More;
use Log::Any::Adapter 'TAP';
use Log::Any qw($log);

use ProductOpener::APITest qw/:all/;
use ProductOpener::Test qw/:all/;
use ProductOpener::TestDefaults qw/:all/;
use ProductOpener::Auth qw/get_token_using_password_credentials/;

use File::Basename qw/dirname/;

use Storable qw/dclone/;

wait_application_ready();

remove_all_users();

remove_all_products();

my $ua = new_client();

my %create_user_args = (%default_user_form, (email => 'bob@gmail.com'));
create_user($ua, \%create_user_args);

my $token = get_token_using_password_credentials('tests', $test_password)->{access_token};
$log->debug('test token', {token => $token}) if $log->is_debug();

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
		body => '{"product": {"packagings_add": {"shape": {"lc_name": "bottle"}}}}'
	},
	{
		test_case => 'patch-packagings-add-one-component',
		method => 'PATCH',
		path => '/api/v3/product/1234567890007',
		body => '{"product": { "packagings_add": [{"shape": {"lc_name": "bottle"}}]}}'
	},
	# Only the PATCH method is valid, test other methods
	{
		test_case => 'post-packagings',
		method => 'POST',
		path => '/api/v3/product/1234567890007',
		body => '{"product": { "packagings": [{"shape": {"lc_name": "bottle"}}]}}'
	},
	{
		test_case => 'put-packagings',
		method => 'PUT',
		path => '/api/v3/product/1234567890007',
		body => '{"product": { "packagings": [{"shape": {"lc_name": "bottle"}}]}}'
	},
	{
		test_case => 'delete-packagings',
		method => 'DELETE',
		path => '/api/v3/product/1234567890007',
		body => '{"product": { "packagings": [{"shape": {"lc_name": "bottle"}}]}}'
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
						"shape": {"id": "en:bottle"},
						"material": {"lc_name": "plastic"},
						"recycling": {"lc_name": "strange value"}
					},
					{
						"number_of_units": 1,
						"shape": {"id": "en:box"},
						"material": {"lc_name": "cardboard"},
						"recycling": {"lc_name": "to recycle"}
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
			"fields": "updated,misc_tags,weighers_tags",
			"tags_lc": "fr",
			"product": {
				"packagings_add": [
					{
						"number_of_units": 3,
						"shape": {"lc_name": "bouteille"},
						"material": {"lc_name": "plastique"}
					},
					{
						"number_of_units": 4,
						"shape": {"lc_name": "pot"},
						"material": {"lc_name": "verre"},
						"recycling": {"lc_name": "à recycler"}
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
			"fields": "updated,misc_tags,weighers_tags",
			"tags_lc": "en",
			"product": {
				"packagings_add": [
					{
						"number_of_units": 6,
						"shape": {"lc_name": "bottle"},
						"material": {"lc_name": "PET"},
						"quantity_per_unit": "25cl",
						"weight_measured": 10
					},
					{
						"number_of_units": 1,
						"shape": {"lc_name": "box"},
						"material": {"lc_name": "wood"},
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
						"shape": {"lc_name": "bag"},
						"material": {"lc_name": "plastic"},
						"weight_measured": 10.5
					},
					{
						"number_of_units": 1,
						"shape": {"lc_name": "label"},
						"material": {"lc_name": "paper"},
						"weight_specified": 0.25
					}				
				]
			}
		}'
	},
	# Test different value for the fields parameter
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
						"shape": {"lc_name": "bag"},
						"material": {"lc_name": "plastic"}
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
						"shape": {"lc_name": "bag"},
						"material": {"lc_name": "plastic"}
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
						"shape": {"lc_name": "bag"},
						"material": {"lc_name": "plastic"}
					}
				]
			}
		}'
	},
	{
		test_case => 'patch-request-fields-updated-attribute-groups-knowledge-panels',
		method => 'PATCH',
		path => '/api/v3/product/1234567890009',
		body => '{
			"fields": "updated,attribute_groups,knowledge_panels",
			"tags_lc": "en",
			"product": {
				"packagings": [
					{
						"number_of_units": 1,
						"shape": {"lc_name": "bag"},
						"material": {"lc_name": "plastic"}
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
			"fields": "all",
			"tags_lc": "en",
			"product": {
				"packagings": [
					{
						"number_of_units": 1,
						"shape": {"lc_name": "bag"},
						"material": {"lc_name": "plastic"}
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
						"shape": {"lc_name": "bag"},
						"material": {"lc_name": "plastic"}
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
						"shape": {"lc_name": "bag"},
						"material": {"lc_name": "plastic"}
					}
				]
			}
		}'
	},
	{
		test_case => 'patch-properties-with-lc-name',
		method => 'PATCH',
		path => '/api/v3/product/1234567890010',
		body => '{
			"tags_lc": "en",
			"product": {
				"packagings": [
					{
						"number_of_units": 2,
						"shape": {"lc_name": "film"},
						"material": {"lc_name": "PET"},
						"recycling": {"lc_name": "discard"}
					}
				]
			}
		}'
	},
	{
		test_case => 'patch-properties-with-lc-name-fr',
		method => 'PATCH',
		path => '/api/v3/product/1234567890011',
		body => '{
			"tags_lc": "fr",
			"product": {
				"packagings": [
					{
						"number_of_units": 2,
						"shape": {"lc_name": "sachet"},
						"material": {"lc_name": "papier"},
						"recycling": {"lc_name": "à recycler"}
					}
				]
			}
		}'
	},
	{
		test_case => 'patch-properties-with-lc-name-fr-and-spanish',
		method => 'PATCH',
		path => '/api/v3/product/1234567890012',
		body => '{
			"tags_lc": "fr",
			"product": {
				"packagings": [
					{
						"number_of_units": 2,
						"shape": {"lc_name": "es:Caja"},
						"material": {"lc_name": "papier"},
						"recycling": {"lc_name": "à recycler"}
					}
				]
			}
		}'
	},
	{
		test_case => 'patch-properties-with-lc-name-fr-and-unrecognized-spanish',
		method => 'PATCH',
		path => '/api/v3/product/1234567890012',
		body => '{
			"tags_lc": "fr",
			"product": {
				"packagings": [
					{
						"number_of_units": 2,
						"shape": {"lc_name": "es:Something in Spanish"},
						"material": {"lc_name": "papier"},
						"recycling": {"lc_name": "à recycler"}
					}
				]
			}
		}'
	},
	# weight should be a number, but we can accept strings like "24", "23.1" or "25,1"
	{
		test_case => 'patch-weight-as-number-or-string',
		method => 'PATCH',
		path => '/api/v3/product/1234567890013',
		body => '{
			"tags_lc": "en",
			"fields": "updated,misc_tags",
			"product": {
				"packagings": [
					{
						"number_of_units": 1,			
						"shape": {"lc_name": "Bottle"},
						"weight_measured": 0.43
					},
					{
						"number_of_units": "2",
						"shape": {"lc_name": "Box"},
						"weight_measured": "0.43"
					},
					{
						"number_of_units": 3,
						"shape": {"lc_name": "Lid"},
						"weight_measured": "0,43"
					}								
				]
			}
		}'
	},
	# Test authentication - HTTP Basic Auth
	{
		test_case => 'patch-auth-good-password',
		method => 'PATCH',
		path => '/api/v3/product/1234567890014',
		body => '{
			"user_id": "tests",
			"password": "' . $test_password . '",
			"fields": "creator,editors_tags,packagings",
			"tags_lc": "en",
			"product": {
				"packagings": [
					{
						"number_of_units": 1,
						"shape": {"lc_name": "can"},
						"recycling": {"lc_name": "recycle"}
					}
				]
			}
		}'
	},
	{
		test_case => 'patch-auth-bad-user-password',
		method => 'PATCH',
		path => '/api/v3/product/1234567890015',
		body => '{
			"user_id": "tests",
			"password": "bad password",
			"fields": "creator,editors_tags,packagings",
			"tags_lc": "en",
			"product": {
				"packagings": [
					{
						"number_of_units": 1,
						"shape": {"lc_name": "can"},
						"recycling": {"lc_name": "recycle"}
					}			
				]
			}
		}',
		expected_status_code => 200,
	},
	# Test authentication - OAuth token
	{
		test_case => 'patch-auth-good-oauth-token',
		method => 'PATCH',
		path => '/api/v3/product/2234567890001',
		body => '{
			"fields": "creator,editors_tags,packagings,created_by_client,last_modified_by_client",
			"tags_lc": "en",
			"product": {
				"packagings": [
					{
						"number_of_units": 1,
						"shape": {"lc_name": "can"},
						"recycling": {"lc_name": "recycle"}
					}
				]
			}
		}',
		headers_in => {
			'Authorization' => 'Bearer ' . $token,
		},
	},
	{
		test_case => 'patch-auth-bad-oauth-token',
		method => 'PATCH',
		path => '/api/v3/product/2234567890002',
		body => '{
			"fields": "creator,editors_tags,packagings",
			"tags_lc": "en",
			"product": {
				"packagings": [
					{
						"number_of_units": 1,
						"shape": {"lc_name": "can"},
						"recycling": {"lc_name": "recycle"}
					}			
				]
			}
		}',
		headers_in => {
			'Authorization' => 'Bearer 4711',
		},
		expected_status_code => 200,
	},
	# Packaging complete
	{
		test_case => 'patch-packagings-complete-0',
		method => 'PATCH',
		path => '/api/v3/product/1234567890016',
		body => '{
			"fields": "packagings,packagings_complete",
			"tags_lc": "en",
			"product": {
				"packagings": [
					{
						"number_of_units": 1,
						"shape": {"lc_name": "bottle"},
						"recycling": {"lc_name": "recycle"}
					}			
				],
				"packagings_complete": 0
			}
		}'
	},
	{
		test_case => 'patch-packagings-complete-1',
		method => 'PATCH',
		path => '/api/v3/product/1234567890016',
		body => '{
			"fields": "packagings,packagings_complete",
			"tags_lc": "en",
			"product": {
				"packagings": [
					{
						"number_of_units": 1,
						"shape": {"lc_name": "bottle"},
						"recycling": {"lc_name": "recycle"}
					},
					{
						"number_of_units": 1,
						"shape": {"lc_name": "lid"},
						"recycling": {"lc_name": "recycle"}
					}								
				],
				"packagings_complete": 1
			}
		}'
	},
	{
		test_case => 'patch-packagings-complete-2',
		method => 'PATCH',
		path => '/api/v3/product/1234567890016',
		body => '{
			"fields": "packagings,packagings_complete",
			"tags_lc": "en",
			"product": {
				"packagings": [
					{
						"number_of_units": 1,
						"shape": {"lc_name": "bottle"},
						"recycling": {"lc_name": "recycle"}
					},
					{
						"number_of_units": 1,
						"shape": {"lc_name": "lid"},
						"recycling": {"lc_name": "recycle"}
					}								
				],
				"packagings_complete": 2
			}
		}'
	},
	# Weights sent as strings (with dot or comma)
	{
		test_case => 'patch-packagings-weights-as-strings',
		method => 'PATCH',
		path => '/api/v3/product/1234567890017',
		body => '{
			"fields": "updated,misc_tags,weighers_tags",
			"tags_lc": "en",
			"product": {
				"packagings_add": [
					{
						"number_of_units": 6,
						"shape": {"lc_name": "bottle"},
						"material": {"lc_name": "PET"},
						"quantity_per_unit": "25cl",
						"weight_measured": "10"
					},
					{
						"number_of_units": 1,
						"shape": {"lc_name": "box"},
						"material": {"lc_name": "wood"},
						"weight_specified": "25.5"
					},
					{
						"number_of_units": 1,
						"shape": {"lc_name": "film"},
						"material": {"lc_name": "plastic"},
						"weight_specified": "2,01"
					}					
				]
			}
		}'
	},
	# Weights sent as strings with units
	{
		test_case => 'patch-packagings-weights-as-strings-with-units',
		method => 'PATCH',
		path => '/api/v3/product/1234567890018',
		body => '{
			"fields": "updated,misc_tags,weighers_tags",
			"tags_lc": "en",
			"product": {
				"packagings_add": [
					{
						"number_of_units": 6,
						"shape": {"lc_name": "bottle"},
						"material": {"lc_name": "PET"},
						"quantity_per_unit": "25cl",
						"weight_measured": "10 g"
					},
					{
						"number_of_units": 1,
						"shape": {"lc_name": "box"},
						"material": {"lc_name": "wood"},
						"weight_specified": "25.5g"
					},
					{
						"number_of_units": 1,
						"shape": {"lc_name": "film"},
						"material": {"lc_name": "plastic"},
						"weight_specified": "2,01 grams"
					}		
				]
			}
		}'
	},
	# invalid codes
	{
		test_case => 'patch-code-123',
		method => 'PATCH',
		path => '/api/v3/product/123',
		body => '{"product": { "ingredients_text_en": "milk 80%, sugar, cocoa powder"}}',
	},
	# code "test" to get results for an empty product without saving anything
	{
		test_case => 'patch-code-test',
		method => 'PATCH',
		path => '/api/v3/product/test',
		body => '{"product": { "ingredients_text_en": "milk 80%, sugar, cocoa powder"}}',
	},
	{
		test_case => 'options-code-test',
		method => 'OPTIONS',
		path => '/api/v3/product/test',
		body => '{"product": { "ingredients_text_en": "milk 80%, sugar, cocoa powder"}}',
		headers => {
			"Access-Control-Allow-Origin" => "*",
			"Access-Control-Allow-Methods" => "HEAD, GET, PATCH, POST, PUT, OPTIONS",
		},
		expected_type => "html",
	},
	{
		test_case => 'patch-unrecognized-field',
		method => 'PATCH',
		path => '/api/v3/product/test',
		body => '{"product": { "some_unrecognized_field": "some value"}}',
	},
	# language specific fields
	{
		test_case => 'patch-language-fields',
		method => 'PATCH',
		path => '/api/v3/product/test',
		body => '{
			"fields" : "updated,ingredients_text,ingredients,lc",
			"product": { 
				"ingredients_text_en": "milk 80%, sugar, cocoa powder",
				"ingredients_text_fr": "lait 80%, sucre, poudre de cacao"
			}
		}',
	},
	# tags fields
	{
		test_case => 'patch-tags-fields',
		method => 'PATCH',
		path => '/api/v3/product/1234567890100',
		body => '{
			"fields" : "updated",
			"product": { 
				"categories_tags": ["coffee"],
				"labels_tags": ["en:organic", "fr:max havelaar", "vegan", "Something unrecognized"],
				"brands_tags": ["Some brand"],
				"unknown_tags": ["some value"],
				"stores_tags": "comma,separated,list"
			}
		}',
	},
	# add to categories (existing) and stores (empty), replace labels
	{
		test_case => 'patch-tags-fields-add',
		method => 'PATCH',
		path => '/api/v3/product/1234567890100',
		body => '{
			"fields" : "updated",
			"product": { 
				"categories_tags_add": ["en:tea"],
				"stores_tags_add": ["Carrefour", "Mon Ptit magasin"],
				"countries_tags_fr_add": ["Italie", "en:spain"],
				"labels_tags_fr": ["végétarien", "Something unrecognized in French"]
			}
		}',
	},
	# nutriscore of a test product
	{
		test_case => 'patch-ingredients-categories-to-get-nutriscore',
		method => 'PATCH',
		path => '/api/v3/product/test',
		body => '{
			"fields" : "updated,ingredients,nutriments,nutriments_estimated,nutriscore_grade,nutriscore_score,nutriscore_data",
			"product": { 
				"lang": "fr",
				"categories_tags_fr": ["confiture"],
				"ingredients_text_fr": "Sucre 300g, pommes 100g"
			}
		}',
	},
];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
