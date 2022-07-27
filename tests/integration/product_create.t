#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test;
use ProductOpener::APITest qw/:all/;
use ProductOpener::Test qw/:all/;

remove_all_products();
wait_dynamic_front();

my $ua = new_client();

my %product_feilds = (
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
	".submit" => "submit",
	type => "add"
);

create_product($ua, \%product_feilds);

# edit preference accessible
my $response = $ua->get("http://world.openfoodfacts.localhost/cgi/product.pl?type=edit&code=200000000099");

#$DB::single = 1;
is $response->{_rc}, 200;

done_testing();
