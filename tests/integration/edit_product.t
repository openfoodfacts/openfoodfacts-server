#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test::More;
use ProductOpener::APITest qw/:all/;
use ProductOpener::Test qw/:all/;
use LWP::Simple "get";
use Data::Dumper;
use Encode;
use File::Basename "dirname";
use JSON::PP;
use ProductOpener::TestDefaults qw/:all/;
use ProductOpener::Test qw/:all/;
use Getopt::Long;

my $test_name = "edit_product";
my $tests_dir = dirname(__FILE__);
my $expected_dir = $tests_dir . "/expected_test_results/" . $test_name;

my $update_expected_results =1;

if ((defined $update_expected_results) and (! -e $expected_dir)) {
	mkdir($expected_dir, 0755) or die("Could not create $expected_dir directory: $!\n");
}

remove_all_products();
wait_dynamic_front();

my $admin_ua = new_client();

my %product_fields = (
	code => '200000000099',
	lang => "en",
	product_name => "Testttt-75ml",
	generic_name => "Tester",
	quantity => "75 ml",
	link => "https://github.com/openfoodfacts/openfoodfacts-server",
	expiration_date => "test",
	ingredients_text => "apple, palm-oil, meat, egg", 
	origin => "france",
	serving_size => "10g",
	packaging_text => "no",
	action => "process",
	type => "add",
	".submit" => "submit"
);

my %fields = (
    code => '200000000099',
	ingredients_text => "apple, milk",
    categories => "snacks"
);

create_user($admin_ua, {});

create_product($admin_ua, \%product_fields);

my $response = $admin_ua->post("http://world.openfoodfacts.localhost/cgi/product_jqm2.pl?type=edit&code=200000000099", Content => \%fields,);

my $json = get("http://world.openfoodfacts.localhost/cgi/search.pl?action=process&json=1&ingredients_from_palm_oil=without");
my $decoded_json = decode_json($json);

compare_to_expected_results($decoded_json, "$expected_dir/edit_product.json", $update_expected_results);


is($response->{_rc}, 200);

