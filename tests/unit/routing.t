#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use ProductOpener::Test qw/compare_to_expected_results init_expected_results/;
use ProductOpener::Routing qw/analyze_request load_routes/;
use ProductOpener::RateLimiter
	qw/account_request_for_rate_limiting move_rate_limit_accounting rollback_rate_limit_accounting set_rate_limit_bucket/;
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
		id => 'products-codes-gs1-formats',
		desc => 'products with multiple various GS1 format barcodes',
		lc => "en",
		input_request => {
			cc => "world",
			lc => "en",
			original_query_string =>
				'products/https%3A%2F%2Fid.gs1.org%2F01%2F03564703999971%2F10%2FABC%2F21%2F123456%3F17%3D211200+%1D010356470399997210ABC123%1D1524050431030002753922499',
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
	# The accounting minute is time-dependent and is not part of the snapshot
	delete $test_ref->{input_request}{rate_limiter_accounted_minute};
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
	# Note: even though the original method is in ProductOpener::Redis, we need to mock the
	# method in ProductOpener::RateLimiter, which is where set_rate_limit_attributes lives now
	my $redis_module = mock 'ProductOpener::RateLimiter' => (
		override => [
			get_rate_limit_user_requests => sub {
				my $bucket = shift;
				my $user_id = shift;
				print "bucket: $bucket, user_id: $user_id\n";
				return 100;
			}
		]
	);

	ProductOpener::RateLimiter::set_rate_limit_attributes($request_ref, "1.2.3.4");
	is($request_ref->{rate_limiter_blocking}, 1, "IP not in rate limit whitelist");

	ProductOpener::RateLimiter::set_rate_limit_attributes($request_ref, "163.5.3.4");
	is($request_ref->{rate_limiter_blocking}, 0, "IP in rate limit whitelist");

}

# Every request must be accounted for in a rate-limit bucket

{

	my @incremented_buckets = ();
	my @decremented_buckets = ();
	my $module = mock 'ProductOpener::RateLimiter' => (
		override => [
			increment_rate_limit_requests => sub {
				my ($ip_address, $bucket, $minute) = @_;
				push @incremented_buckets, $bucket;
				return;
			},
			decrement_rate_limit_requests => sub {
				my ($ip_address, $bucket, $minute) = @_;
				push @decremented_buckets, $bucket;
				return;
			},
		]
	);

	# Without a bucket, the request is counted in the "other" bucket: the bucket of a route was the
	# only thing that set it, and only 5 of the 52 cgi/*.pl scripts go through the router
	my $request_ref = {no_index => 0};
	account_request_for_rate_limiting($request_ref);
	is($request_ref->{rate_limiter_bucket}, "other", "a request without a bucket is counted in 'other'");
	is($request_ref->{rate_limiter_accounted_bucket}, "other", "the request is accounted for");
	is(scalar @incremented_buckets, 1, "the request is counted once");
	is(defined $request_ref->{rate_limiter_accounted_minute}, 1, "the accounting minute is stored");

	# A route that sets a bucket only changes the bucket: the count moves when the accounting is
	# refreshed, so that eligibility for the new bucket is checked before it is incremented
	set_rate_limit_bucket($request_ref, "product");
	is($request_ref->{rate_limiter_bucket}, "product", "the route bucket is set");
	is($request_ref->{rate_limiter_accounted_bucket}, "other", "the count has not moved yet");
	is(scalar @incremented_buckets, 1, "setting the bucket does not count the request again");
	is(scalar @decremented_buckets, 0, "setting the bucket does not move the count yet");

	# move_rate_limit_accounting() moves the count to the new bucket
	move_rate_limit_accounting($request_ref);
	is($request_ref->{rate_limiter_accounted_bucket}, "product", "the count moved to the new bucket");
	is(scalar @incremented_buckets, 2, "the request is counted in the new bucket");
	is($incremented_buckets[1], "product", "the second count is for the route bucket");
	is(scalar @decremented_buckets, 1, "the count is removed from the previous bucket");
	is($decremented_buckets[0], "other", "the removed count is the one of the previous bucket");

	# Setting the same bucket again and refreshing does not count the request twice
	set_rate_limit_bucket($request_ref, "product");
	move_rate_limit_accounting($request_ref);
	is(scalar @incremented_buckets, 2, "the request is not counted twice in the same bucket");
	is(scalar @decremented_buckets, 1, "the count is not moved when the bucket does not change");

	# A request that was not accounted for (init_request() was not called) is counted when the
	# accounting is asked for, in the bucket that was set in the meantime
	my $not_accounted_ref = {no_index => 0, rate_limiter_bucket => "facet_tags"};
	move_rate_limit_accounting($not_accounted_ref);
	is($not_accounted_ref->{rate_limiter_accounted_bucket}, "facet_tags", "the request is accounted for");
	is(scalar @incremented_buckets, 3, "the request is counted once");

	# A no-index page (an empty page returned to known web crawlers) is not counted
	my $no_index_ref = {no_index => 1, rate_limiter_bucket => "other"};
	is(account_request_for_rate_limiting($no_index_ref), 0, "a no-index page is not accounted for");
	is($no_index_ref->{rate_limiter_accounted_bucket}, undef, "a no-index page is not counted");
	is(scalar @incremented_buckets, 3, "a no-index page does not increment a counter");

	# A request counted by init_request() that routing later marks no-index (for example a crawler
	# paginating a facet) backs its count out instead of consuming the quota
	my $crawler_ref = {no_index => 0};
	account_request_for_rate_limiting($crawler_ref);
	my $increments_before_crawler = scalar @incremented_buckets;
	set_rate_limit_bucket($crawler_ref, "facet_products");
	$crawler_ref->{no_index} = 1;
	move_rate_limit_accounting($crawler_ref);
	is($crawler_ref->{rate_limiter_accounted_bucket}, undef, "the no-index count is rolled back");
	is($crawler_ref->{rate_limiter_blocking}, 0, "a no-index page is never blocking");
	is(scalar @decremented_buckets, 2, "the init_request() count is removed");
	is(scalar @incremented_buckets,
		$increments_before_crawler, "the route bucket is never incremented for a no-index page");
}

# The limit is checked before the final bucket is incremented, as it was before accounting moved
# to init_request(): a search limit of 10 blocks the 11th request, not the 10th

{

	my $limit_module = mock 'ProductOpener::RateLimiter' => (
		override => [
			remote_addr => sub {
				return "1.2.3.4";
			},
			get_rate_limit_user_requests => sub {
				return 9;
			},
			increment_rate_limit_requests => sub {return;},
			decrement_rate_limit_requests => sub {return;},
		]
	);

	my $request_ref = {no_index => 0, rate_limiter_bucket => "search"};
	account_request_for_rate_limiting($request_ref);
	is($request_ref->{rate_limiter_blocking}, 0, "9 previous requests do not block (limit 10)");
}

{

	my $limit_module = mock 'ProductOpener::RateLimiter' => (
		override => [
			remote_addr => sub {
				return "1.2.3.4";
			},
			get_rate_limit_user_requests => sub {
				return 10;
			},
			increment_rate_limit_requests => sub {return;},
			decrement_rate_limit_requests => sub {return;},
		]
	);

	my $request_ref = {no_index => 0, rate_limiter_bucket => "search"};
	account_request_for_rate_limiting($request_ref);
	is($request_ref->{rate_limiter_blocking}, 1, "10 previous requests block (limit 10)");
}

# The initialization-then-routing flow checks the final bucket before incrementing it

{

	my %counts = (other => 0, search => 9);
	my $flow_module = mock 'ProductOpener::RateLimiter' => (
		override => [
			remote_addr => sub {
				return "1.2.3.4";
			},
			get_rate_limit_user_requests => sub {
				my ($ip, $bucket) = @_;
				return $counts{$bucket};
			},
			increment_rate_limit_requests => sub {
				my ($ip, $bucket, $minute) = @_;
				$counts{$bucket}++;
				return;
			},
			decrement_rate_limit_requests => sub {
				my ($ip, $bucket, $minute) = @_;
				$counts{$bucket}--;
				return;
			},
		]
	);

	my $request_ref = {no_index => 0};
	account_request_for_rate_limiting($request_ref);
	set_rate_limit_bucket($request_ref, "search");
	move_rate_limit_accounting($request_ref);
	is($request_ref->{rate_limiter_blocking}, 0, "the 10th search request is not blocked (limit 10)");
	is($counts{other}, 0, "the init_request() count moved out of 'other'");
	is($counts{search}, 10, "the search counter holds the 10 requests");
}

done_testing();
