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
			'query_string' => 'api/v0/attribute_groups'
		},
	},
	{
		desc => "Invalid URL with last component which is not a facet or a page number",
		lc => "en",
		input_request => {
			cc => "world",
			lc => "en",
			original_query_string => 'category/breads/no-nutrition-data',
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
			'tagtype' => 'categories'
		},
	},
	{
		desc => "Facet URL",
		lc => "en",
		input_request => {
			cc => "world",
			lc => "en",
			original_query_string => 'category/breads',
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
			'tagtype' => 'categories'

		},
	},
	{
		desc => "Facet URL with a page number",
		lc => "en",
		input_request => {
			cc => "world",
			lc => "en",
			original_query_string => 'category/breads/4',
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
			'tagtype' => 'categories'
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
