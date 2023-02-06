#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test::More;
use Log::Any::Adapter 'TAP';
use Test::MockModule;

use ProductOpener::Config qw/@edit_rules/;
use ProductOpener::Users qw/$User_id/;

use ProductOpener::Test qw/:all/;
use ProductOpener::TestDefaults qw/:all/;
use ProductOpener::Products qw/process_product_edit_rules/;

my %base_product = (%default_product,);

# tests are composed of following fields:
# - id: an id for test (to quickly find it)
# - desc: description of the test
# - edit_rules: the edit_rules to test.
#   Note that during test, user_id is "test"
# - product (optional): some more fields for product, which defaults to TestDefaults default_product
# - form (optional): some more parameters submitted to the form,
#   which defaults to TestDefaults default_product_form
# and some expectations:
# - result: the expected return result of process_product_edit_rules
# - delete_param (optional): form entries which are expected to be removed by process_product_edit_rules
my @tests = (
	{
		id => "no_rule_ok",
		desc => "No rule should do no change",
		edit_rules => [],
		result => 1,
	},
	{
		id => "block_user_test",
		desc => "Block user test",
		edit_rules => [{name => "Block test", conditions => [["user_id", "test"]], actions => [["ignore"]]},],
		result => 0,
	},
	{
		id => "block_user_other",
		desc => "Block user other, does not block tests",
		edit_rules => [{name => "Block other", conditions => [["user_id", "other"]], actions => [["ignore"]]},],
		result => 1,
	},
	{
		id => "block_all_user_but_other",
		desc => "Block all user but other, blocks test",
		edit_rules =>
			[{name => "Block all but other", conditions => [["user_id_not", "other"]], actions => [["ignore"]]},],
		result => 0,
	},
	{
		id => "block_all_user_but_test",
		desc => "Block all user but test, does not blocks test",
		edit_rules =>
			[{name => "Block all but test", conditions => [["user_id_not", "test"]], actions => [["ignore"]]},],
		result => 1,
	},
	{
		id => "block_by_category_tag",
		desc => "Block for product with a category",
		edit_rules => [
			{
				name => "Block all but test",
				conditions => [["in_category_tags", "en:test_cat"]],
				actions => [["ignore"]]
			},
		],
		product => {category_tags => ["en:test_cat", "en:other_cat"]},
		result => 0,
	},
	{
		id => "block_by_category_tag_no_match",
		desc => "Block for product with a category, does not block non matching",
		edit_rules => [
			{
				name => "Block all but test",
				conditions => [["in_category_tags", "en:test_cat"]],
				actions => [["ignore"]]
			},
		],
		product => {category_tags => ["en:other_cat"]},
		result => 1,
	},
	{
		id => "ignore_if_existing_ingredients_text_fr",
		desc => "Remove edit on a ingredients text in french if one already exists",
		edit_rules => [{name => "Disallow ingredients", actions => [["ignore_if_existing_ingredients_text_fr"]]},],
		product => {ingredients_text_fr => "YES"},
		form => {ingredients_text_fr => "NOPE"},
		delete_param => ["ingredients_text_fr", "ingredients_text"],
		result => 1,
	},
	{
		id => "ignore_if_existing_ingredients_text_fr_no_lang_suffix",
		desc => "Remove edit on a ingredients text in french if one already exists works without lang prefix",
		edit_rules => [{name => "Disallow ingredients", actions => [["ignore_if_existing_ingredients_text_fr"]]},],
		product => {ingredients_text_fr => "YES"},
		form => {ingredients_text => "NOPE"},
		delete_param => ["ingredients_text_fr", "ingredients_text"],
		result => 1,
	},
	{
		id => "ignore_if_existing_ingredients_text_fr_empty",
		desc =>
			"Remove edit on a ingredients text in french if one already exists not applicable because there is none",
		edit_rules => [{name => "Disallow ingredients", actions => [["ignore_if_existing_ingredients_text_fr"]]},],
		form => {ingredients_text_fr => "NOPE"},
		result => 1,
	},
	{
		id => "ignore_if_0_nutriment_fruits_vegetables_nuts",
		desc => "Remove edit if 0 value on a nutriment field",
		edit_rules =>
			[{name => "Disallow ingredients", actions => [["ignore_if_0_nutriment_fruits-vegetables-nuts"]]},],
		form => {"nutriment_fruits-vegetables-nuts" => 0},
		result => 1,
		delete_param => ["nutriment_fruits-vegetables-nuts"],
	},
	{
		id => "ignore_if_equal_nutriments_sugar",
		desc => "Remove edit if value on a nutriment field is equal to a value",
		edit_rules => [{name => "Disallow ingredients", actions => [["ignore_if_equal_nutriment_sugar", 100]]},],
		product => {"nutriment" => {"sugar_100g" => 22}},
		form => {"nutriment_sugar" => 100},
		result => 1,
		delete_param => ["nutriment_sugar"],
	},
	{
		id => "ignore_if_match_serving_size",
		desc => "Remove edit if string value match a value",
		edit_rules => [{name => "Disallow ingredients", actions => [["ignore_if_match_serving_size", "serving"]]},],
		form => {"serving_size" => "serving"},
		result => 1,
		delete_param => ["serving_size"],
	},
	{
		id => "ignore_if_regexp_match_brand",
		desc => "Remove edit if string value match a regexp",
		edit_rules =>
			[{name => "Disallow ingredients", actions => [["ignore_if_regexp_match_brands", "(acme|hacky)"]]},],
		form => {"brands" => "Another, Acme inc."},
		result => 1,
		delete_param => ["brands"],
	},
	{
		id => "combine_actions",
		desc => "Remove edit with combined actions",
		edit_rules => [
			{
				name => "Disallow ingredients",
				actions => [
					["ignore_if_existing_ingredients_text_fr"],
					["ignore_if_equal_nutriment_sugar", 100],
					["ignore_if_match_serving_size", "serving"],
					["ignore_if_regexp_match_brands", "(acme|hacky)"]
				]
			},
		],
		product => {ingredients_text_fr => "YES", "nutriment" => {"sugar_100g" => 22}},
		form => {
			ingredients_text_fr => "NOPE",
			"nutriment_sugar" => 100,
			"serving_size" => "serving",
			"brands" => "Another, Acme inc."
		},
		result => 1,
		delete_param => ["ingredients_text_fr", "ingredients_text", "nutriment_sugar", "serving_size", "brands"],
	},
	# FIXME: add tests on warning and slack notifications
);

my @edit_rules_backup = @edit_rules;

# a global for fake CGI parameters
my %form = ();

sub fake_single_param ($name) {
	return scalar $form{$name};
}

# removed params
my @removed = ();

sub fake_delete ($name) {
	push @removed, $name;
	return;
}

{
	# monkey patch single_param
	my $display_module = Test::MockModule->new('ProductOpener::Display');
	$display_module->mock('single_param', \&fake_single_param);
	# because this is a direct import in Products we have to monkey patch here, there also
	my $products_module = Test::MockModule->new('ProductOpener::Products');
	$products_module->mock('single_param', \&fake_single_param);
	# patch CGI Delete
	my $cgi_module = Test::MockModule->new('CGI');
	$cgi_module->mock('Delete', \&fake_delete);
	$products_module->mock('Delete', \&fake_delete);

	foreach my $test_ref (@tests) {
		# use eval to ensure edit_rules changes will be reverted
		eval {
			my $id = $test_ref->{id};
			my $desc = $test_ref->{desc};
			# overide edit rules
			@edit_rules = @{$test_ref->{edit_rules}};
			$User_id = $test_ref->{user_id} // "test";
			my %product = (%base_product, %{$test_ref->{product} // {}});
			%form = (%default_product_form, %{$test_ref->{form} // {}});
			@removed = ();
			my $result = process_product_edit_rules(\%product);
			is($result, $test_ref->{result}, "Result for $id - $desc");
			is_deeply(\@removed, $test_ref->{delete_param} // [], "Delete params for $id - $desc");
		};
		# restore edit_rules
		@edit_rules = @edit_rules_backup;
	}
}

done_testing();
