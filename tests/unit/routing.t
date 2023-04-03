#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test::More;
use Log::Any::Adapter 'TAP';

use ProductOpener::Routing qw/:all/;

# TODO: create a test case array and use the update_test_results system to
# store and compare the returned $request object

# TODO: add tests for all routes

# Test below moved from display.t

my %request = (
	'original_query_string' => 'api/v0/attribute_groups',
	'referer' => 'http://world.openfoodfacts.localhost/product/3564703999971/huile-d-olive-marque-repere'
);

analyze_request(\%request);
is($request{'api'}, "v0");
is($request{'page'}, "1");
is($request{'api_version'}, "0");

# for checking invalid facets or urls having missing facets
my %testcase = ('original_query_string' => 'category/breads/no-nutrition-data');

analyze_request(\%testcase);
is($testcase{'status_code'}, "404");

done_testing(4);
