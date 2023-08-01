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

wait_application_ready();

my $ua = new_client();

my $CRAWLING_BOT_USER_AGENT
	= 'Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko; compatible; bingbot/2.0; +http://www.bing.com/bingbot.htm) Chrome/';
my $NORMAL_USER_USER_AGENT
	= 'Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/114.0Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/114.0';

my %product_form = (
	%{dclone(\%default_product_form)},
	(
		code => '0200000000235',
		product_name => "Only-Product",
	)
);

edit_product($ua, \%product_form);

my $tests_ref = [
	# Normal user should have access to product page
	{
		test_case => 'normal-user-access-product-page',
		method => 'GET',
		path => '/product/0200000000235/only-product',
		headers_in => {'User-Agent' => $CRAWLING_BOT_USER_AGENT},
		expected_status_code => 200,
		expected_type => 'html',
		response_content_must_match => '<title>Only-Product - 100 g</title>'
	},
	# Crawling bot should have access to product page
	{
		test_case => 'crawler-access-product-page',
		method => 'GET',
		path => '/product/0200000000235/only-product',
		headers_in => {'User-Agent' => $NORMAL_USER_USER_AGENT},
		expected_status_code => 200,
		expected_type => 'html',
		response_content_must_match => '<title>Only-Product - 100 g</title>'
	},
	# Crawling bot should receive a noindex page for nested facets
	{
		test_case => 'crawler-access-nested-facet-page',
		method => 'GET',
		path => '/category/hazelnut-spreads/brand/nutella',
		headers_in => {'User-Agent' => $CRAWLING_BOT_USER_AGENT},
		expected_status_code => 200,
		expected_type => 'html',
		response_content_must_match => '<h1>NOINDEX</h1>'
	},
	# Normal user should have access to nested facets
	{
		test_case => 'normal-user-access-nested-facet-page',
		method => 'GET',
		path => '/category/hazelnut-spreads/brand/nutella',
		headers_in => {'User-Agent' => $NORMAL_USER_USER_AGENT},
		expected_status_code => 200,
		expected_type => 'html',
		response_content_must_not_match => '<h1>NOINDEX</h1>'
	},
	# Crawling bot should have access to specific facet pages (such as category)
	{
		test_case => 'crawler-access-category-facet-page',
		method => 'GET',
		path => '/category/hazelnut-spreads',
		headers_in => {'User-Agent' => $CRAWLING_BOT_USER_AGENT},
		expected_status_code => 200,
		expected_type => 'html',
		response_content_must_not_match => '<h1>NOINDEX</h1>'
	},
	# Normal user should have access to facet pages
	{
		test_case => 'normal-user-access-category-facet-page',
		method => 'GET',
		path => '/category/hazelnut-spreads',
		headers_in => {'User-Agent' => $NORMAL_USER_USER_AGENT},
		expected_status_code => 200,
		expected_type => 'html',
		response_content_must_not_match => '<h1>NOINDEX</h1>'
	},
	# Crawling bot should receive a noindex page for most facet pages (including editor facet)
	{
		test_case => 'crawler-access-editor-facet-page',
		method => 'GET',
		path => '/editor/unknown-user',
		headers_in => {'User-Agent' => $CRAWLING_BOT_USER_AGENT},
		expected_status_code => 200,
		expected_type => 'html',
		response_content_must_match => '<h1>NOINDEX</h1>'
	},
	# Normal user should have access to editor facet
	{
		test_case => 'normal-user-access-editor-facet-page',
		method => 'GET',
		path => '/editor/unknown-user',
		headers_in => {'User-Agent' => $NORMAL_USER_USER_AGENT},
		expected_status_code => 200,
		expected_type => 'html',
		response_content_must_match => 'Unknown user.'
	},
];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
