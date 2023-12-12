#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test::More;
use ProductOpener::APITest qw/:all/;
use ProductOpener::Test qw/:all/;
use ProductOpener::TestDefaults qw/:all/;

use File::Basename "dirname";

use Storable qw(dclone);

wait_application_ready();

#remove_all_users();

#remove_all_products();

my $ua = new_client();

my %create_user_args = (%default_user_form, (email => 'bob@gmail.com'));
create_user($ua, \%create_user_args);

# Create some products

my @products = (
	{
		%{dclone(\%default_product_form)},
		(
			lc => "en",
			lang => "en",
			code => '200000000034',
			product_name => "Some product",
			generic_name => "Tester",
			ingredients_text => "apple, milk, eggs, palm oil",
			categories => "cookies",
			labels => "organic",
			origin => "france",
			packaging_text_en =>
				"1 wooden box to recycle, 6 25cl glass bottles to reuse, 3 steel lids to recycle, 1 plastic film to discard",
		)
	},
);

foreach my $product_form_override (@products) {
	edit_product($ua, $product_form_override);
}

# Note: expected results are stored in json files, see execute_api_tests
my $tests_ref = [
	{
		test_case => 'get-existing-product',
		method => 'GET',
		# the path needs to include the product title, otherwise we get a redirect (not supported in tests container)
		path => '/product/200000000034/some-product',
		expected_status_code => 200,
		expected_type => 'html',
	},
	{
		test_case => 'get-unexisting-product',
		method => 'GET',
		path => '/product/300000000034',
		expected_status_code => 404,
		expected_type => 'html',
	},
];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
