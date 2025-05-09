#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use ProductOpener::APITest qw/create_user edit_product execute_api_tests new_client wait_application_ready/;
use ProductOpener::Test qw/remove_all_products remove_all_users/;
use ProductOpener::TestDefaults qw/%default_product_form %default_user_form/;

use File::Basename "dirname";

use Storable qw(dclone);

remove_all_users();

remove_all_products();

wait_application_ready();

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
			code => '2000000000034',
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
	{
		%{dclone(\%default_product_form)},
		(
			lc => "en",
			lang => "en",
			code => '0020000000034',
			product_name => "Some other product",
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
		path => '/product/2000000000034/some-product',
		expected_status_code => 200,
		expected_type => 'html',
	},
	{
		test_case => 'get-unexisting-product',
		method => 'GET',
		path => '/product/3000000000034',
		expected_status_code => 404,
		expected_type => 'html',
	},
	# redirect to correct url, 13 chars instead of 12
	{
		test_case => 'non-normalized-code',
		method => 'GET',
		path => '/product/20000000034',
		expected_status_code => 302,
		expected_type => 'html',
		response_content_must_match => "/product/0020000000034",
	},

];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
