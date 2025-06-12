#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use ProductOpener::Test qw/compare_to_expected_results init_expected_results/;
use ProductOpener::Routing qw/analyze_request load_routes/;
use ProductOpener::Lang qw/$lc/;

use Test2::V0;
use Data::Dumper;
$Data::Dumper::Terse = 1;
use Log::Any::Adapter 'TAP';

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));
# TODO: add tests for all routes
load_routes();

my @tests = (
	{
		id => "api-v0-attribute-groups",
		desc => "API to get attribute groups",
		lc => "en",
		input_request => {
			cc => "world",
			lc => "en",
			original_query_string => 'api/v0/attribute_groups',
			no_index => '0',
			is_crawl_bot => '1',
			rate_limiter_bucket => undef,
			rate_limiter_blocking => 0,
			rate_limiter_limit => undef,
			rate_limiter_user_requests => undef
		},
	},
	{
		id => 'invalid-last-url-component',
		desc => "Invalid URL with last component which is not a facet or a page number",
		lc => "en",
		input_request => {
			cc => "world",
			lc => "en",
			original_query_string => 'facets/categories/breads/no-nutrition-data',
			no_index => '0',
			is_crawl_bot => '0',
			rate_limiter_bucket => undef,
			rate_limiter_blocking => 0,
			rate_limiter_limit => undef,
			rate_limiter_user_requests => undef
		},
	},
	{
		id => 'facet-url',
		desc => "Facet URL",
		lc => "en",
		input_request => {
			cc => "world",
			lc => "en",
			original_query_string => 'facets/categories/breads',
			no_index => '0',
			is_crawl_bot => '1',
			rate_limiter_bucket => undef,
			rate_limiter_blocking => 0,
			rate_limiter_limit => undef,
			rate_limiter_user_requests => undef
		},
	},
	{
		id => 'facet-url-with-page-number',
		desc => "Facet URL with a page number",
		lc => "en",
		input_request => {
			cc => "world",
			lc => "en",
			original_query_string => 'facets/categories/breads/4',
			no_index => '0',
			is_crawl_bot => '1',
			rate_limiter_bucket => undef,
			rate_limiter_blocking => 0,
			rate_limiter_limit => undef,
			rate_limiter_user_requests => undef
		},
	},
	{
		id => 'facet-url-with-synonym-and-page-number',
		desc => "Facet URL with a facet synonym and a page number",
		lc => "en",
		input_request => {
			cc => "world",
			lc => "en",
			original_query_string => 'facets/categories/bread/4',
			no_index => '0',
			is_crawl_bot => '0',
			rate_limiter_bucket => undef,
			rate_limiter_blocking => 0,
			rate_limiter_limit => undef,
			rate_limiter_user_requests => undef
		},
	},
	{
		id => 'api-v3-product-code',
		desc => "API v3 URL with product code",
		lc => "en",
		input_request => {
			cc => "world",
			lc => "en",
			original_query_string => 'api/v3/product/03564703999971',
			no_index => '0',
			is_crawl_bot => '0',
			rate_limiter_bucket => undef,
			rate_limiter_blocking => 0,
			rate_limiter_limit => undef,
			rate_limiter_user_requests => undef
		},
	},
	{
		id => 'api-v3-product-gs1-data-uri',
		desc => "API v3 URL with product GS1 Data URI",
		lc => "en",
		input_request => {
			cc => "world",
			lc => "en",
			original_query_string =>
				'api/v3/product/https%3A%2F%2Fid.gs1.org%2F01%2F03564703999971%2F10%2FABC%2F21%2F123456%3F17%3D211200',
			no_index => '0',
			is_crawl_bot => '0',
			rate_limiter_bucket => undef,
			rate_limiter_blocking => 0,
			rate_limiter_limit => undef,
			rate_limiter_user_requests => undef
		},
	},
	{
		id => 'facet-url-group-by',
		desc => "Facet URL with a group-by",
		lc => "en",
		input_request => {
			cc => "world",
			lc => "en",
			original_query_string => 'facets/categories/breads/ingredients',
			no_index => '0',
			is_crawl_bot => '1',
			rate_limiter_bucket => undef,
			rate_limiter_blocking => 0,
			rate_limiter_limit => undef,
			rate_limiter_user_requests => undef
		},
	},
	{
		id => 'facet-url-group-by-in-english',
		desc => "Facet URL with a group-by in English",
		lc => "en",
		input_request => {
			cc => "world",
			lc => "es",
			original_query_string => 'facets/categories/breads/ingredients',
			no_index => '0',
			is_crawl_bot => '1',
			rate_limiter_bucket => undef,
			rate_limiter_blocking => 0,
			rate_limiter_limit => undef,
			rate_limiter_user_requests => undef
		},
	},
	{
		id => 'geoip-get-country-from-ipv4-us',
		desc => 'geoip get country from ipv4 us',
		input_request => {
			cc => "world",
			lc => "en",
			original_query_string => 'api/v3/geopip/12.45.23.45',
			no_index => '0',
			is_crawl_bot => '0',
			rate_limiter_bucket => undef,
			rate_limiter_blocking => 0,
			rate_limiter_limit => undef,
			rate_limiter_user_requests => undef
		}
	},
	{
		id => 'geoip-get-country-from-ipv6-fr',
		desc => 'geoip get country from ipv6 fr',
		lc => "en",
		input_request => {
			cc => "world",
			lc => "en",
			original_query_string => 'api/v3/geopip/2001:ac8:25:3b::e01d',
			no_index => '0',
			is_crawl_bot => '0',
			rate_limiter_bucket => undef,
			rate_limiter_blocking => 0,
			rate_limiter_limit => undef,
			rate_limiter_user_requests => undef

		},
	},
	# /products
	{
		id => 'products-code',
		desc => 'products with a single barcode',
		lc => "en",
		input_request => {
			cc => "world",
			lc => "en",
			original_query_string => 'products/3564703999971',
			no_index => '0',
			is_crawl_bot => '0',
			rate_limiter_bucket => undef,
			rate_limiter_blocking => 0,
			rate_limiter_limit => undef,
			rate_limiter_user_requests => undef
		}
	},
	# /products with multiple barcodes
	{
		id => 'products-codes',
		desc => 'products with multiple barcodes',
		lc => "en",
		input_request => {
			cc => "world",
			lc => "en",
			original_query_string => 'products/3564703999971,3564703999972',
			no_index => '0',
			is_crawl_bot => '0',
			rate_limiter_bucket => undef,
			rate_limiter_blocking => 0,
			rate_limiter_limit => undef,
			rate_limiter_user_requests => undef
		}
	},
	{
		id => 'product-french',
		desc => 'product translated in french',
		lc => "fr",
		input_request => {
			cc => "world",
			lc => "fr",
			original_query_string => 'produit/3564703999971',
			no_index => '0',
			is_crawl_bot => '0',
			rate_limiter_bucket => undef,
			rate_limiter_blocking => 0,
			rate_limiter_limit => undef,
			rate_limiter_user_requests => undef
		}
	},
	# Rate-limit tests
	{
		id => 'rate-limit-on-facet-registered-user',
		desc => "Rate limit on facet for registered user",
		lc => "en",
		input_request => {
			cc => "world",
			lc => "en",
			original_query_string => 'facets/categories/breads',
			no_index => '0',
			is_crawl_bot => '0',
			user_id => "userid",
			rate_limiter_bucket => undef,
			rate_limiter_blocking => 0,
			rate_limiter_limit => undef,
			rate_limiter_user_requests => undef
		},
	},
	# redirect tests
	{
		id => 'redirect-to-plural-tagtype',
		desc => "Redirect to plural tagtype",
		lc => "en",
		input_request => {
			cc => "world",
			lc => "en",
			original_query_string => 'facets/category/breads/brand/lidl',
			no_index => '0',
			is_crawl_bot => '0',
			user_id => "userid",
			rate_limiter_bucket => undef,
			rate_limiter_blocking => 0,
			rate_limiter_limit => undef,
			rate_limiter_user_requests => undef
		},
	},
	{
		id => 'redirect-to-facets-prefix',
		desc => "Redirect to facets prefix",
		lc => "en",
		input_request => {
			cc => "world",
			lc => "en",
			original_query_string => 'categories',
			no_index => '0',
			is_crawl_bot => '0',
			user_id => "userid",
			rate_limiter_bucket => undef,
			rate_limiter_blocking => 0,
			rate_limiter_limit => undef,
			rate_limiter_user_requests => undef
		},
	},
	{
		id => 'redirect-to-facets-prefix-and-plural',
		desc => "Redirect to facets prefix and plural",
		lc => "fr",
		input_request => {
			cc => "world",
			lc => "fr",
			original_query_string => 'categories/pain/brand/lidl',
			no_index => '0',
			is_crawl_bot => '0',
			user_id => "userid",
			rate_limiter_bucket => undef,
			rate_limiter_blocking => 0,
			rate_limiter_limit => undef,
			rate_limiter_user_requests => undef
		},
	},
	{
		id => 'redirect-to-product-normalized-code',
		desc => "Redirect to product normalized code",
		lc => "fr",
		input_request => {
			cc => "world",
			lc => "fr",
			original_query_string => 'product/012345678',
			no_index => '0',
			is_crawl_bot => '0',
			user_id => "userid",
			rate_limiter_bucket => undef,
			rate_limiter_blocking => 0,
			rate_limiter_limit => undef,
			rate_limiter_user_requests => undef
		},
	},

);

foreach my $test_ref (@tests) {

	# Set $lc global because currently analyze_request uses the global $lc
	$lc = $test_ref->{input_request}{lc};
	analyze_request($test_ref->{input_request});
	compare_to_expected_results(
		$test_ref->{input_request},
		"$expected_result_dir/$test_ref->{id}.json",
		$update_expected_results, $test_ref
	);
}

# Test rate limit whitelist

{

	my $request_ref = {rate_limiter_bucket => "search",};

	# Mock the get_rate_limit_user_requests method called in set_rate_limit_attributes()
	# Note: even though the original method is in ProductOpener::Redis,
	# we need to mock the method in ProductOpener::Routing
	my $redis_module = mock 'ProductOpener::Routing' => (
		override => [
			get_rate_limit_user_requests => sub {
				my $bucket = shift;
				my $user_id = shift;
				print "bucket: $bucket, user_id: $user_id\n";
				return 100;
			}
		]
	);

	ProductOpener::Routing::set_rate_limit_attributes($request_ref, "1.2.3.4");
	is($request_ref->{rate_limiter_blocking}, 1, "IP not in rate limit whitelist");

	ProductOpener::Routing::set_rate_limit_attributes($request_ref, "163.5.3.4");
	is($request_ref->{rate_limiter_blocking}, 0, "IP in rate limit whitelist");

}

done_testing();
