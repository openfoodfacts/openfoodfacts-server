#!/usr/bin/perl -w

use Modern::Perl '2017';
no warnings qw(experimental::signatures);

use utf8;

use Test2::V0;
use Data::Dumper;
$Data::Dumper::Terse = 1;
$Data::Dumper::Sortkeys = 1;
use Log::Any::Adapter 'TAP';

use ProductOpener::Config qw/:all/;

use ProductOpener::StorageConditions qw/set_storage_conditions/;

use ProductOpener::LoadData qw/load_data/;

load_data();

my @tests = (
	['frozen-food-category', {lc => "en", categories_tags => ["en:frozen-foods"]}, {storage_conditions => "en:frozen", storage_conditions_tags => ["en:frozen"]}],
	['refrigerated-food-category', {lc => "en", categories_tags => ["en:refrigerated-foods"]}, {storage_conditions => "en:refrigerated", storage_conditions_tags => ["en:refrigerated"]}],
	['ambient-food-category', {lc => "en", categories_tags => ["en:canned-foods"]}, {storage_conditions => "en:ambient", storage_conditions_tags => ["en:ambient"]}],
	['no-matching-category', {lc => "en", categories_tags => ["en:beverages"]}, {storage_conditions => undef, storage_conditions_tags => undef}],
	['no-categories', {lc => "en"}, {storage_conditions => undef, storage_conditions_tags => undef}],
);

foreach my $test_ref (@tests) {
	my $testid = $test_ref->[0];
	my $product_ref = $test_ref->[1];
	my $expected_storage_conditions_tags_ref = $test_ref->[2];

	set_storage_conditions($product_ref);

	is($product_ref->{storage_conditions}, $expected_storage_conditions_tags_ref->{storage_conditions}, "$testid - storage_conditions");
	is($product_ref->{storage_conditions_tags}, $expected_storage_conditions_tags_ref->{storage_conditions_tags}, "$testid - storage_conditions_tags");
}

done_testing();
