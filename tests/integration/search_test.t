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

my %product_fields_1 = (
	code => '200000000034',
	lang => "en",
	product_name => "test_1",
	generic_name => "Tester",
	quantity => "100 ml",
	link => "https://github.com/openfoodfacts/openfoodfacts-server",
	expiration_date => "test",
	ingredients_text => "apple, milk, eggs, palm oil",
	origin => "france",
	serving_size => "10g",
	packaging_text => "no",
	action => "process",
	type => "add",
	".submit" => "submit"
);

my %product_fields_4 = (
	code => '200000000037',
	lang => "en",
	product_name => "vegan & palm oil free",
	generic_name => "Tester",
	quantity => "100 ml",
	link => "https://github.com/openfoodfacts/openfoodfacts-server",
	expiration_date => "test",
	ingredients_text => "fruit, rice",
	origin => "france",
	serving_size => "10g",
	packaging_text => "no",
	action => "process",
	type => "add",
	".submit" => "submit"
);

my %product_fields_5 = (
	code => '200000000038',
	lang => "en",
	product_name => "palm oil free & non vegan",
	generic_name => "Tester",
	quantity => "100 ml",
	link => "https://github.com/openfoodfacts/openfoodfacts-server",
	expiration_date => "test",
	ingredients_text => "apple, milk, eggs",
	origin => "france",
	serving_size => "10g",
	packaging_text => "no",
	action => "process",
	type => "add",
	".submit" => "submit"
);

my %product_fields_6 = (
	code => '200000000039',
	lang => "es",
	product_name => "Vegan Test Snack",
	generic_name => "Tester",
	quantity => "100 ml",
	link => "https://github.com/openfoodfacts/openfoodfacts-server",
	expiration_date => "test",
	ingredients_text => "apple, water",
	origin => "spain",
	serving_size => "5g",
	packaging_text => "no",
	action => "process",
    categories => "snacks",
	type => "add",
	".submit" => "submit"
);


remove_all_users();

remove_all_products();

wait_dynamic_front();

my $ua = new_client();

my %create_user_args = (%default_user_form, (email => 'bob@gmail.com'));
create_user($ua, \%create_user_args);

create_product($ua, \%product_fields_1);
create_product($ua, \%product_fields_4);
create_product($ua, \%product_fields_5);
create_product($ua, \%product_fields_6);

my $query_1_json = get("http://world.openfoodfacts.localhost//cgi/search.pl?action=process&json=1");
my $query_1_json_decoded = decode_json($query_1_json);

my $query_2_json = get("http://world.openfoodfacts.localhost//cgi/search.pl?action=process&json=1&ingredients_from_palm_oil=without");
my $query_2_json_decoded = decode_json($query_2_json);

# my $query_3_json = get("http://world.openfoodfacts.localhost/api/v2/search?code=200000000039,200000000038&fields=code,product_name");
# my $query_3_json_decoded = decode_json($query_3_json);

my $update_expected_results;

compare_to_expected_results($query_1_json_decoded, "expected_test_results/search_api_results/q1.json", $update_expected_results);
compare_to_expected_results($query_2_json_decoded, "expected_test_results/search_api_results/q2.json", $update_expected_results);
# compare_to_expected_results($query_3_json_decoded, "expected_test_results/search_api_results/q3.json", $update_expected_results);


