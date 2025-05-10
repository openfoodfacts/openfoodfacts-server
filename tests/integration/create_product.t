#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use Data::Dumper;
$Data::Dumper::Terse = 1;
use ProductOpener::APITest qw/construct_test_url create_user edit_product new_client wait_application_ready/;
use ProductOpener::Test qw/remove_all_products remove_all_users/;
use ProductOpener::TestDefaults qw/%default_user_form/;

remove_all_users();
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
my %create_user_args = (%default_user_form, (email => 'bob@test.com'));
create_user($user_ua, \%create_user_args);
edit_product($user_ua, \%product_fields);
my $response = $user_ua->get(construct_test_url("/cgi/product.pl?type=edit&code=200000000098"));
is($response->{_rc}, 200) or diag Dumper $response;

# Test creating a product without a user: the product should not be created
$product_fields{code} = "200000000099";
edit_product($anon_ua, \%product_fields, 1);    # $ok_to_fail = 1, as we expect this to fail
$response = $user_ua->get(construct_test_url("/cgi/product.pl?type=edit&code=200000000099"));
is($response->{_rc}, 404) or diag Dumper $response;

done_testing();
