#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test::More;
use Log::Any::Adapter 'TAP';

use ProductOpener::Routing qw/:all/;
use ProductOpener::Lang qw/:all/;

# TODO: create a test case array and use the update_test_results system to
# store and compare the returned $request object

# TODO: add tests for all routes

my @tests = (
	{
		desc => "API to get attribute groups",
		lc => "en",
		input_request => {
			cc => "world",
			lc => "en",
			original_query_string => 'api/v0/attribute_groups',
			no_index => '0',
			is_crawl_bot => '1'
		},
		expected_output_request => {
			'api' => 'v0',
			'api_action' => 'attribute_groups',
			'api_method' => undef,
			'api_version' => '0',
			'cc' => 'world',
			'lc' => 'en',
			'original_query_string' => 'api/v0/attribute_groups',
			'page' => 1,
			'query_string' => 'api/v0/attribute_groups',
			'no_index' => '0',
			'is_crawl_bot' => '1'
		},
	},
	{
		desc => "Invalid URL with last component which is not a facet or a page number",
		lc => "en",
		input_request => {
			cc => "world",
			lc => "en",
			original_query_string => 'category/breads/no-nutrition-data',
			no_index => '0',
			is_crawl_bot => '0'
		},
		expected_output_request => {
			'api' => 'v0',
			'canon_rel_url' => '/category/en:breads',
			'cc' => 'world',
			'error_message' => 'Invalid address.',
			'lc' => 'en',
			'original_query_string' => 'category/breads/no-nutrition-data',
			'page' => 1,
			'query_string' => 'category/breads/no-nutrition-data',
			'status_code' => 404,
			'tag' => 'en:breads',
			'tag_prefix' => '',
			'tagid' => 'en:breads',
			'tagtype' => 'categories',
			'no_index' => '0',
			'is_crawl_bot' => '0'
		},
	},
	{
		desc => "Facet URL",
		lc => "en",
		input_request => {
			cc => "world",
			lc => "en",
			original_query_string => 'category/breads',
			no_index => '0',
			is_crawl_bot => '1'
		},
		expected_output_request => {
			'api' => 'v0',
			'canon_rel_url' => '/category/en:breads',
			'cc' => 'world',
			'lc' => 'en',
			'original_query_string' => 'category/breads',
			'page' => 1,
			'query_string' => 'category/breads',
			'tag' => 'en:breads',
			'tag_prefix' => '',
			'tagid' => 'en:breads',
			'tagtype' => 'categories',
			'no_index' => '0',
			'is_crawl_bot' => '1'
		},
	},
	{
		desc => "Facet URL with a page number",
		lc => "en",
		input_request => {
			cc => "world",
			lc => "en",
			original_query_string => 'category/breads/4',
			no_index => '0',
			is_crawl_bot => '1'
		},
		expected_output_request => {
			'api' => 'v0',
			'canon_rel_url' => '/category/en:breads',
			'cc' => 'world',
			'lc' => 'en',
			'original_query_string' => 'category/breads/4',
			'page' => '4',
			'query_string' => 'category/breads/4',
			'tag' => 'en:breads',
			'tag_prefix' => '',
			'tagid' => 'en:breads',
			'tagtype' => 'categories',
			'no_index' => '1',
			'is_crawl_bot' => '1'
		},
	},
	{
		desc => "Facet URL with a facet synonym and a page number",
		lc => "en",
		input_request => {
			cc => "world",
			lc => "en",
			original_query_string => 'category/bread/4',
			no_index => '0',
			is_crawl_bot => '0'
		},
		expected_output_request => {
			'api' => 'v0',
			'canon_rel_url' => '/category/en:bread',
			'cc' => 'world',
			'lc' => 'en',
			'original_query_string' => 'category/bread/4',
			'page' => '4',
			'query_string' => 'category/bread/4',
			'tag' => 'en:bread',
			'tag_prefix' => '',
			'tagid' => 'en:bread',
			'tagtype' => 'categories',
			'no_index' => '0',
			'is_crawl_bot' => '0'
		},
	},

);

foreach my $test_ref (@tests) {

	# Set $lc global because currently analyze_request uses the global $lc
	$lc = $test_ref->{input_request}{lc};
	analyze_request($test_ref->{input_request});

	is_deeply($test_ref->{input_request}, $test_ref->{expected_output_request}) or diag explain $test_ref;
}

done_testing();
