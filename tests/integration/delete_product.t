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

my $test_name = "delete_product";
my $tests_dir = dirname(__FILE__);
my $expected_dir = $tests_dir . "/expected_test_results/" . $test_name;

my %product_fields = (
	code => '200000000037',
	lang => "en",
	product_name => "vegan & palm oil free",
	generic_name => "Tester",
	quantity => "100 ml",
	link => "#",
	expiration_date => "test",
	ingredients_text => "fruit, rice, egg",
	origin => "france",
	serving_size => "10g",
	packaging_text => "no",
	action => "process",
	type => "add",
	".submit" => "submit"
);

remove_all_users();
remove_all_products();
wait_dynamic_front();
my $ua = new_client();
my %create_user_args = (%default_user_form, (email => 'test@off.com'));
create_user($ua, \%create_user_args);
create_product($ua, \%product_fields);

remove_all_products();
wait_dynamic_front();

my $update_expected_results =1;

if ((defined $update_expected_results) and (! -e $expected_dir)) {
	mkdir($expected_dir, 0755) or die("Could not create $expected_dir directory: $!\n");
}

my $query = get("http://world.openfoodfacts.localhost/cgi/search.pl?search_terms=&search_simple=1&action=process&json=true");
my $query_json_decoded = decode_json($query);

is (compare_to_expected_results($query_json_decoded, "$expected_dir/$test_name.json", $update_expected_results), 1);

done_testing();


