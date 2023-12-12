#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test::More;
use ProductOpener::APITest qw/:all/;
use ProductOpener::Test qw/:all/;
use ProductOpener::TestDefaults qw/:all/;

use File::Basename "dirname";

use Storable qw(dclone);

wait_application_ready();

remove_all_users();

remove_all_products();

my $ua = new_client();

my $CRAWLING_BOT_USER_AGENT = 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)';
my $DENIED_CRAWLING_BOT_USER_AGENT = 'Mozilla/5.0 (compatible; AhrefsBot/6.1; +http://ahrefs.com/robot/)';
my $NORMAL_USER_USER_AGENT
	= 'Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/114.0Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/114.0';

my %product_form = (
	%{dclone(\%default_product_form)},
	(
		code => '0200000000235',
		product_name => "Only-Product",
		categories => "cakes, hazelnut spreads",
		brands => "Nutella",
	)
);

edit_product($ua, \%product_form);

my $tests_ref = [
	# Normal user should have access to product page
	{
		test_case => 'normal-user-access-product-page',
		method => 'GET',
		path => '/product/0200000000235/only-product-nutella',
		headers_in => {'User-Agent' => $NORMAL_USER_USER_AGENT},
		expected_status_code => 200,
		expected_type => 'html',
		response_content_must_match => '<title>Only-Product - Nutella - 100 g</title>'
	},
	# Crawling bot should have access to product page
	{
		test_case => 'crawler-access-product-page',
		method => 'GET',
		path => '/product/0200000000235/only-product-nutella',
		headers_in => {'User-Agent' => $CRAWLING_BOT_USER_AGENT},
		expected_status_code => 200,
		expected_type => 'html',
		response_content_must_match => '<title>Only-Product - Nutella - 100 g</title>'
	},
	# Denied crawling bot should not have access to any page
	{
		test_case => 'denied-crawler-access-product-page',
		method => 'GET',
		path => '/product/0200000000235/only-product-nutella',
		headers_in => {'User-Agent' => $DENIED_CRAWLING_BOT_USER_AGENT},
		expected_status_code => 200,
		expected_type => 'html',
		response_content_must_match => '<h1>NOINDEX</h1>'
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
	# Crawling bot should not have access to list of tags
	{
		test_case => 'crawler-access-list-of-tags',
		method => 'GET',
		path => '/categories',
		headers_in => {'User-Agent' => $CRAWLING_BOT_USER_AGENT},
		expected_status_code => 200,
		expected_type => 'html',
		response_content_must_match => '<h1>NOINDEX</h1>'
	},
	# Normal user should have access to list of tags
	{
		test_case => 'normal-user-access-category-facet-page',
		method => 'GET',
		path => '/categories',
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
		response_content_must_match => '<h1>NOINDEX</h1>',
	},
	# Normal user should have access to editor facet
	{
		test_case => 'normal-user-access-editor-facet-page',
		method => 'GET',
		path => '/editor/unknown-user',
		headers_in => {'User-Agent' => $NORMAL_USER_USER_AGENT},
		expected_status_code => 404,
		expected_type => 'html',
		response_content_must_match => 'Unknown user.'
	},
	# Normal user should get facet knowledge panels
	{
		test_case => 'normal-user-get-facet-knowledge-panels',
		method => 'GET',
		path => '/category/cakes',
		headers_in => {'User-Agent' => $NORMAL_USER_USER_AGENT},
		expected_status_code => 200,
		expected_type => 'html',
		response_content_must_match => 'Fetching facet knowledge panel'
	},
	# Crawling bot should not display facet knowledge panels
	{
		test_case => 'crawler-does-not-get-facet-knowledge-panels',
		method => 'GET',
		path => '/category/cakes',
		headers_in => {'User-Agent' => $CRAWLING_BOT_USER_AGENT},
		expected_status_code => 200,
		expected_type => 'html',
		response_content_must_not_match => 'Fetching facet knowledge panel'
	},
	# Normal user should get access to every possible cc-lc combination
	{
		test_case => 'normal-user-get-non-official-cc-lc',
		method => 'GET',
		path => '/?cc=ch&lc=es',
		headers_in => {'User-Agent' => $NORMAL_USER_USER_AGENT},
		expected_status_code => 200,
		expected_type => 'html',
		response_content_must_not_match => '<h1>NOINDEX</h1>'
	},
	# Crawling bot should not have access to non official cc-lc combination
	# Here lc=es is not an official language of cc=ch
	{
		test_case => 'crawler-get-non-official-cc-lc',
		method => 'GET',
		path => '/?cc=ch&lc=es',
		headers_in => {'User-Agent' => $CRAWLING_BOT_USER_AGENT},
		expected_status_code => 200,
		expected_type => 'html',
		response_content_must_match => '<h1>NOINDEX</h1>'
	},
	# Crawling bot should not have access to world-{lc} where lc != en
	{
		test_case => 'crawler-get-non-official-cc-lc',
		method => 'GET',
		path => '/?cc=world&lc=es',
		headers_in => {'User-Agent' => $CRAWLING_BOT_USER_AGENT},
		expected_status_code => 200,
		expected_type => 'html',
		response_content_must_match => '<h1>NOINDEX</h1>'
	},
	# Indexing should be disabled on all world-{lc} subdomains
	{
		test_case => 'get-robots-txt-word-lc-subdomain',
		path => '/robots.txt',
		subdomain => 'world-it',
		expected_type => 'text',
	},
	# Indexing should be disabled on invalid {cc}-{lc} subdomains
	{
		test_case => 'get-robots-txt-invalid-cc-lc-subdomain',
		path => '/robots.txt',
		subdomain => 'es-it',
		expected_type => 'text',
	},
	# Indexing should be disabled selectively on valid {cc}-{lc} subdomains
	{
		test_case => 'get-robots-txt-ch-it',
		path => '/robots.txt',
		subdomain => 'ch-it',
		expected_type => 'text',
	},
	# Indexing should be disabled on ssl-api subdomain
	{
		test_case => 'get-robots-txt-ssl-api-subdomain',
		path => '/robots.txt',
		subdomain => 'ssl-api',
		expected_type => 'text',
	},
	# Indexing should be enabled on all {lc}-pro platform
	{
		test_case => 'get-robots-txt-fr-pro-platform',
		path => '/robots.txt',
		subdomain => 'fr.pro',
		expected_type => 'text',
	},
	# Indexing should be enabled on world.prod platform
	{
		test_case => 'get-robots-txt-world-pro-platform',
		path => '/robots.txt',
		subdomain => 'world.pro',
		expected_type => 'text',
	},
	# Indexing should be disabled selectively (facet pages only) on {lc} subdomains
	{
		test_case => 'get-robots-txt-fr',
		path => '/robots.txt',
		subdomain => 'fr',
		expected_type => 'text',
	},
	# Indexing should be disabled selectively (facet pages only) on world subdomains
	{
		test_case => 'get-robots-txt-world',
		path => '/robots.txt',
		subdomain => 'world',
		expected_type => 'text',
	},
];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
