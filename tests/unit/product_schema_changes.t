#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test2::V0;
use Log::Any::Adapter 'TAP';

use JSON;

use ProductOpener::Config qw/:all/;
use ProductOpener::ProductSchemaChanges qw/convert_product_schema/;
use ProductOpener::Test qw/compare_to_expected_results init_expected_results/;

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

my @tests = (

	[
		'1000-to-1001-remove-ingredients-hierarchy',
		1001,
		{
			# schema_version field exists only for version 1001+
			lc => "en",
			ingredients_text_en => "Banana",
			ingredients_tags => ["en:fruit", "en:banana"],
			ingredients_hierarchy => ["en:fruit", "en:banana"],
		}
	],

	[
		'1001-to-1000-add-ingredients-hierarchy',
		1000,
		{
			schema_version => 1001,
			lc => "en",
			ingredients_text_en => "Banana",
			ingredients_tags => ["en:fruit", "en:banana"],
		}
	],

);

foreach my $test_ref (@tests) {

	my $testid = $test_ref->[0];
	my $target_schema_version = $test_ref->[1];
	my $product_ref = $test_ref->[2];

	convert_product_schema($product_ref, $target_schema_version);

	compare_to_expected_results($product_ref, "$expected_result_dir/$testid.json", $update_expected_results);
}

done_testing();
