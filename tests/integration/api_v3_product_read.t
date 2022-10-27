#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test::More;
use ProductOpener::APITest qw/:all/;
use ProductOpener::Test qw/:all/;
use ProductOpener::TestDefaults qw/:all/;

use File::Basename "dirname";

use Storable qw(dclone);

remove_all_users();

remove_all_products();

wait_dynamic_front();

my $ua = new_client();

my %create_user_args = (%default_user_form, (email => 'bob@gmail.com'));
create_user($ua, \%create_user_args);

# Create some products

my @products = (
	{
		%{dclone(\%default_product_form)},
		(
			code => '200000000034',
			product_name => "Some product",
			generic_name => "Tester",
			ingredients_text => "apple, milk, eggs, palm oil",
            categories => "cookies",
            labels => "organic",
			origin => "france",
		)
	},
);

foreach my $product_form_override (@products) {
	edit_product($ua, $product_form_override);
}


my $tests_ref = [
    {
        test_case => 'get-unexisting-product',
        method => 'GET',
        path => '/api/v3/product/12345678',
    },    
    {
        test_case => 'get-existing-product',
        method => 'GET',
        path => '/api/v3/product/200000000034',
    },
     {
        test_case => 'get-specific-fields',
        method => 'GET',
        path => '/api/v3/product/200000000034',
        query_string => '?fields=product_name,categories_tags,categories_tags_en',
    },   
];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
