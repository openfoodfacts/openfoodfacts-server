#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test::More;
use ProductOpener::APITest qw/:all/;
use ProductOpener::Test qw/:all/;

remove_all_products();
wait_dynamic_front();

my $admin_ua = new_client();
my $anon_ua = new_client();

my %product_fields = (
	code => '200000000099',
	lang => "en",
	product_name => "Testttt-75ml",
	generic_name => "Tester",
	quantity => "75 ml",
	link => "https://github.com/openfoodfacts/openfoodfacts-server",
	expiration_date => "test",
	ingredients_text => "apple, milk",
	origin => "france",
	serving_size => "10g",
	packaging_text => "no",
	action => "process",
	type => "add",
	".submit" => "submit"
);

create_user($admin_ua, {});
create_user($anon_ua, {});
edit_product($admin_ua, \%product_fields);

my $response = $admin_ua->get("http://world.openfoodfacts.localhost/cgi/product.pl?type=edit&code=200000000099");
my $response = $anon_ua->get("http://world.openfoodfacts.localhost/cgi/product.pl?type=edit&code=200000000099");

is($response->{_rc}, 200);

done_testing();
