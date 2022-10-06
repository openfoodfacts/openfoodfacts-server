#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test::More;
use ProductOpener::APITest qw/:all/;
use ProductOpener::Test qw/:all/;
use LWP::Simple "get";
use Data::Dumper;
use Encode;
use JSON::PP;
use ProductOpener::TestDefaults qw/:all/;
use ProductOpener::Test qw/:all/;
use Storable qw(dclone);

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

my @products = (

	{
		%{dclone(\%default_product_form)},
		(
			code => '200000000034',
			product_name => "test_1",
			generic_name => "Tester",
			ingredients_text => "apple, milk, eggs, palm oil",
			origin => "france"
		)
	},
	{
		%{dclone(\%default_product_form)},
		(
			code => '200000000037',
			product_name => "vegan & palm oil free",
			generic_name => "Tester",
			ingredients_text => "fruit, rice",
			packaging_text => "no"
		)
	},
	{
		%{dclone(\%default_product_form)},
		(
			code => '200000000038',
			product_name => "palm oil free & non vegan",
			generic_name => "Tester",
			quantity => "100 ml",
			ingredients_text => "apple, milk, eggs",
			origin => "france"
		)
	},
	{
		%{dclone(\%default_product_form)},
		(
			code => '200000000039',
			lang => "es",
			product_name => "Vegan Test Snack",
			generic_name => "Tester",
			ingredients_text => "apple, water, palm oil",
			origin => "spain",
			categories => "snacks"
		)
	},
	{
		%{dclone(\%default_product_form)},
		(
			code => '200000000045',
			lang => "es",
			product_name => "Vegan Test Snack",
			generic_name => "Tester",
			ingredients_text => "apple, water",
			origin => "China",
			packaging_text => "no",
			categories => "breakfast cereals"
		)
	}
);

remove_all_users();

remove_all_products();

wait_dynamic_front();

my $ua = new_client();

my %create_user_args = (%default_user_form, (email => 'bob@gmail.com'));
create_user($ua, \%create_user_args);

foreach my $product_form_override (@products) {
	edit_product($ua, $product_form_override);
}

my @tests = (
	["q1", construct_test_url("/cgi/search.pl?action=process&json=1", "world")],
	["q2", construct_test_url("/cgi/search.pl?action=process&json=1&ingredients_from_palm_oil=without", "world")],
	[
		"q3",
		construct_test_url(
			"/api/v2/search?code=200000000039,200000000038,200000000034&fields=code,product_name", "world"
		)
	],
	[
		"q4",
		construct_test_url(
			"/cgi/search.pl?action=process&tagtype_0=categories&tag_contains_0=contains&tag_0=breakfast_cereals&tagtype_1=nutrition_grades&tag_contains_1=contains&ingredients_from_palm_oil=without&json=1",
			"world"
		)
	]
);

foreach my $test_ref (@tests) {
	my $testid = $test_ref->[0];
	my $query_url = $test_ref->[1];
	my $json = get($query_url);

	my $decoded_json;
	eval {
		$decoded_json = decode_json($json);
		1;
	} or do {
		my $json_decode_error = $@;
		diag("The query_url $query_url returned a response that is not valid JSON: $json_decode_error");
		diag("Response content: " . $json);
		fail($testid);
		next;
	};

	# normalize for comparison
	normalize_products_for_test_comparison(\@{$decoded_json->{'products'}});

	is(compare_to_expected_results($decoded_json, "$expected_result_dir/$testid.json", $update_expected_results), 1,);
}

done_testing();
