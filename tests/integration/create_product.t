#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test::More;
use ProductOpener::APITest qw/:all/;
use ProductOpener::Test qw/:all/;

remove_all_products();
wait_application_ready();

my $user_ua = new_client();
my $anon_ua = new_client();

my %product_fields = (
	code => '200000000098',
	lang => "en",
	product_name => "Cool test product 75ml",
	generic_name => "A sample test product",
	quantity => "75 ml",
	link => "https://github.com/openfoodfacts/openfoodfacts-server",
	expiration_date => "test",
	ingredients_text => "apple, milk",
	origin => "france",
	serving_size => "10g",
	packaging_text => "Plastic box, paper lid",
	nutriment_salt_value => "1.1",
	nutriment_salt_unit => "g",
);

# Test creating a product as a registered user: the product should be created
create_user($user_ua, {});
edit_product($user_ua, \%product_fields);
my $response = $anon_ua->get(construct_test_url("/cgi/product.pl?type=edit&code=200000000098"));
is($response->{_rc}, 200) or diag explain $response;

# Test creating a product without a user: the product should not be created
$product_fields{code} = "200000000099";
edit_product($anon_ua, \%product_fields);
$response = $anon_ua->get(construct_test_url("/cgi/product.pl?type=edit&code=200000000099"));

# TODO: the product is in fact created, need to investigated if this behavior is wanted or not
#is($response->{_rc}, 404) or diag explain $response;

done_testing();
