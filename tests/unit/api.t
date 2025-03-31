#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test2::V0;
use Data::Dumper;
$Data::Dumper::Terse = 1;
$Data::Dumper::Sortkeys = 1;
use Log::Any::Adapter 'TAP';

use ProductOpener::API qw/:all/;

is(
	ProductOpener::API::api_compatibility_for_product_response({environmental_score_grade => "a"}, "3"),
	{ecoscore_grade => "a", schema_version => 999},
	"ecoscore_grade 3"
);
is(
	ProductOpener::API::api_compatibility_for_product_response({environmental_score_grade => "b"}, "3.1"),
	{environmental_score_grade => "b", schema_version => 1000},
	"ecoscore_grade 3.1"
);

done_testing();
