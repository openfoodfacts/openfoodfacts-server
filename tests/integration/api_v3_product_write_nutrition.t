#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use Log::Any::Adapter 'TAP';
use Log::Any qw($log);

use ProductOpener::APITest qw/create_user execute_api_tests new_client wait_application_ready/;
use ProductOpener::Test qw/remove_all_products remove_all_users/;
use ProductOpener::TestDefaults qw/%default_user_form/;
use ProductOpener::Auth qw/get_token_using_password_credentials/;

use File::Basename qw/dirname/;

use Storable qw/dclone/;

wait_application_ready(__FILE__);

remove_all_users();

remove_all_products();

my $ua = new_client();

my %create_user_args = (%default_user_form, (email => 'bob@gmail.com'));
create_user($ua, \%create_user_args);

my $token = get_token_using_password_credentials('tests', 'testtest')->{access_token};
$log->debug('test token', {token => $token}) if $log->is_debug();

# nutrition
# input_sets - array
# preparation: “as_sold” or “prepared”
# per: “100g”, “100ml”, “serving”
# per_quantity (e.g. 50 or 250) - always present, even for 100g / 100ml
# per_unit (e.g. “g”, “ml”) - always present, even for 100g / 100 ml
# source “packaging”, “manufacturer”, “database-usda”, “estimate”
# -> only “packaging” is writable for normal users, “manufacturer” and “database-usda” are writable by the pro platform
# -> more values may be added (e.g. other databases)
# source_description
# e.g. “USDA non-branded foods 2025/04”
# e.g. “Import from org-nestle-france through Equadis”
# e.g. “Estimate from ingredients”, “Estimate from category: Olive oils”
# for the “packaging” source: “” empty string
# last_updated_t: timestamp of last modification
# -> automatically computed
# nutrients
# -> send undef / none to remove completely an input set
# sodium
# -> send undef / none to remove completely a nutrient
# value_string (preferred for “packaging”)
# e.g. “2.0”, “4,1”
# -> possibly normalize commas / dots
# unit
# “mg”
# modifier: <, <=, ~, >, >= (optional)
# unspecified_nutrients (optional) (array of nutrients)
# -> especially for packaging source, list of nutrients that are typically present, but that are not specified for this particular product
# e.g. [“fibers”] in EU
# -> limit to specific values? (e.g. “fibers”, “calcium” etc.)
# Decision: in description, specify that this is only for nutrients that are typically displayed in nutrition facts tables in at least one country (available in Food.pm code %nutrients_table)

# Note: expected results are stored in json files, see execute_api_tests
my $tests_ref = [

	# tags fields
	{
		test_case => 'patch-nutrition-input-sets-add',
		method => 'PATCH',
		path => '/api/v3.5/product/4230000001000',
		body => '{
			"fields" : "updated",
			"product": { 
				"nutrition": {
					"input_sets": [
						{
							"preparation": "as_sold",
							"per": "100g",
							"per_quantity": 100,
							"per_unit": "g",
							"source": "packaging",
							"source_description": "",
							"nutrients": {
								"energy-kj": {
									"value_string": "2000",
									"unit": "kJ"
								},
								"fat": {
									"value_string": "10",
									"unit": "g"
								},
								"saturated-fat": {
									"value_string": "2",
									"unit": "g"
								},
								"carbohydrates": {
									"value_string": "30",
									"unit": "g"
								},
								"sugars": {
									"value_string": "20",
									"unit": "g"
								},
								"fiber": {
									"value_string": "5",
									"unit": "g"
								},
								"proteins": {
									"value_string": "5",
									"unit": "g"
								},
								"salt": {
									"value_string": "1.5",
									"unit": "g"
								},
								"sodium": {
									"value_string": "0.59",
									"unit": "g"
								}
							},
							"unspecified_nutrients": ["alcohol", "polyols"]
						},
						{
							"preparation": "prepared",
							"per": "200ml",
							"per_quantity": 200,
							"per_unit": "ml",
							"source": "packaging",
							"source_description": "",
							"nutrients": {
								"energy-kj": {
									"value_string": "1000",
									"unit": "kJ"
								},
								"fat": {
									"value_string": "5",
									"unit": "g"
								},
								"saturated-fat": {
									"value_string": "1",
									"unit": "g"
								},
								"carbohydrates": {
									"value_string": "15",
									"unit": "g"
								},
								"sugars": {
									"value_string": "10",
									"unit": "g"
								},
								"fiber": {
									"value_string": "2.5",
									"unit": "g"
								},
								"proteins": {
									"value_string": "2.5",
									"unit": "g"
								},
								"salt": {
									"value_string": "0.75",
									"unit": "g"
								},
								"sodium": {
									"value_string": "0.295",
									"unit": "g"
								}
							},
							"unspecified_nutrients": ["fiber"]
						}
					]
				}
			}
		}',
	},
	{
		test_case => 'patch-nutrition-add-nutrient-to-existing-set',
		method => 'PATCH',
		path => '/api/v3.5/product/4230000001000',
		body => '{
			"fields" : "updated",
			"product": { 
				"nutrition": {
					"input_sets": [
						{
							"preparation": "as_sold",
							"per": "100g",
							"per_quantity": 100,
							"per_unit": "g",
							"source": "packaging",
							"source_description": "",
							"nutrients": {
								"alcohol": {
									"value_string": "0.5",
									"unit": "g"
								}
							}
						}
					]
				}
			}
		}',
	},
	{
		test_case => 'patch-nutrition-input-sets-change-nutrient-value',
		method => 'PATCH',
		path => '/api/v3.5/product/4230000001000',
		body => '{
			"fields" : "updated",
			"product": { 
				"nutrition": {
					"input_sets": [
						{
							"preparation": "as_sold",
							"per": "100g",
							"per_quantity": 100,
							"per_unit": "g",
							"source": "packaging",
							"source_description": "",
							"nutrients": {
								"fat": {
									"value_string": "11",
									"unit": "g"
								}
							}
						}
					]
				}
			}
		}',
	},
	{
		test_case => 'patch-nutrition-input-sets-remove-nutrient',
		method => 'PATCH',
		path => '/api/v3.5/product/4230000001000',
		body => '{
			"fields" : "updated",
			"product": { 
				"nutrition": {
					"input_sets": [
						{
							"preparation": "as_sold",
							"per": "100g",
							"per_quantity": 100,
							"per_unit": "g",
							"source": "packaging",
							"source_description": "",
							"nutrients": {
								"sodium": null
							}
						}
					]
				}
			}
		}',
	},
	{
		test_case => 'patch-nutrition-input-sets-remove-set',
		method => 'PATCH',
		path => '/api/v3.5/product/4230000001000',
		body => '{
			"fields" : "updated",
			"product": { 
				"nutrition": {
					"input_sets": [
						{
							"preparation": "prepared",
							"per": "200ml",
							"per_quantity": 200,
							"per_unit": "ml",
							"source": "packaging",
							"source_description": "",
							"nutrients": null
						}
					]
				}
			}
		}',
	},
];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
