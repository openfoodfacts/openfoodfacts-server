#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test::More;
use Log::Any::Adapter 'TAP';

use ProductOpener::Tags qw/:all/;
use ProductOpener::TaxonomySuggestions qw/:all/;

ProductOpener::Tags::retrieve_tags_taxonomy("test");

# Filtering suggestions matching strings

my $tags_ref = ["en:banana-yogurts", "en:yogurts", "en:soup", "en:vegetable", "en:non-existent-entry",];

my @filter_tests = (
	{
		desc => 'Empty string',
		tags => $tags_ref,
		tagtype => "test",
		lc => "en",
		string => "",
		expected => ['Banana yogurts', 'Yogurts', 'Soup', 'Vegetable'],
	},
	{
		desc => 'Match at start',
		tags => $tags_ref,
		tagtype => "test",
		lc => "en",
		string => "ba",
		expected => ['Banana yogurts'],
	},
	{
		desc => 'Match at start and inside, return start first',
		tags => $tags_ref,
		tagtype => "test",
		lc => "en",
		string => "yog",
		expected => ['Yogurts', 'Banana yogurts'],
	},
	{
		desc => 'No match',
		tags => $tags_ref,
		tagtype => "test",
		lc => "en",
		string => "xyz",
		expected => [],
	},
	{
		desc => 'match an xx: synonym',
		tags => $tags_ref,
		tagtype => "test",
		lc => "en",
		string => "something else",
		expected => ["Soup"],
	},
);

foreach my $test_ref (@filter_tests) {
	my @results = ProductOpener::TaxonomySuggestions::filter_suggestions_matching_string($test_ref->{tags},
		$test_ref->{tagtype}, $test_ref->{lc}, $test_ref->{string}, {});
	if (not is_deeply(\@results, $test_ref->{expected})) {
		diag explain($test_ref, \@results);
	}
}

# Complete suggestion generation

my @suggest_tests = (
	{
		desc => 'Match at start',
		tagtype => "test",
		lc => "en",
		string => "ba",
		expected => ['Banana yogurts'],
	},
	{
		desc => 'Match at start and inside, return start first',
		tagtype => "test",
		lc => "en",
		string => "yog",
		expected => ['Yogurts', 'Banana yogurts', 'Lemon yogurts', 'Passion fruit yogurts'],
	},

);

foreach my $test_ref (@suggest_tests) {
	my @results = ProductOpener::TaxonomySuggestions::get_taxonomy_suggestions($test_ref->{tagtype}, $test_ref->{lc},
		$test_ref->{string}, {}, {});
	if (not is_deeply(\@results, $test_ref->{expected})) {
		diag explain($test_ref, \@results);
	}
}

done_testing();
