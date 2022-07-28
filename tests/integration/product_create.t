#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test::More;
use ProductOpener::APITest qw/:all/;
use ProductOpener::Test qw/:all/;

remove_all_products();
wait_dynamic_front();

my $ua = new_client();

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
	".submit" => "submit"
);

my $admin_ua = new_client();
create_user($admin_ua, {userid => "stephane", email => 'stephane@test.com'});
create_product($admin_ua, \%product_fields);

# edit preference accessible
my $response = $admin_ua->get("http://world.openfoodfacts.localhost/product/200000000099");

#$DB::single = 1;
is ($response->{_rc}, 200);

done_testing();
