#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test2::V0;
use Data::Dumper;
$Data::Dumper::Terse = 1;
use Log::Any::Adapter 'TAP';

use ProductOpener::Tags qw/retrieve_tags_taxonomy/;
use ProductOpener::TaxonomySuggestions qw/get_taxonomy_suggestions get_taxonomy_suggestions_with_synonyms/;

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
		expected => ['banana yogurts', 'yogurts', 'soup', 'vegetable'],
	},
	{
		desc => 'Match at start',
		tags => $tags_ref,
		tagtype => "test",
		lc => "en",
		string => "ba",
		expected => ['banana yogurts'],
	},
	{
		desc => 'Match at start and inside, return start first',
		tags => $tags_ref,
		tagtype => "test",
		lc => "en",
		string => "yog",
		expected => ['yogurts', 'banana yogurts'],
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
		expected => ["soup"],
	},
);

foreach my $test_ref (@filter_tests) {
	my @results = ProductOpener::TaxonomySuggestions::filter_suggestions_matching_string($test_ref->{tags},
		$test_ref->{tagtype}, $test_ref->{lc}, $test_ref->{string}, {});
	if (not is(\@results, $test_ref->{expected})) {
		diag Dumper($test_ref, \@results);
	}
}

# Complete suggestion generation

my @suggest_tests = (
	{
		desc => 'Match at start',
		tagtype => "test",
		lc => "en",
		string => "ba",
		expected => ['banana yogurts'],
	},
	{
		desc => 'Match at start and inside, return start first',
		tagtype => "test",
		lc => "en",
		string => "yog",
		expected => ['yogurts', 'Passion fruit yogurts', 'banana yogurts', 'lemon yogurts'],
		# Note: "Passion fruit yogurts" is capitalized in the test.txt taxonomy, while other entries are not
	},

);

foreach my $test_ref (@suggest_tests) {
	my @results = ProductOpener::TaxonomySuggestions::get_taxonomy_suggestions("en:world", $test_ref->{tagtype},
		$test_ref->{lc}, $test_ref->{string}, {}, {});
	if (not is(\@results, $test_ref->{expected})) {
		diag Dumper($test_ref, \@results);
	}
}

# Complete suggestion generation (with synonyms)

@suggest_tests = (
	{
		desc => 'Match at start',
		tagtype => "test",
		lc => "en",
		string => "ba",
		expected => [
			{
				'matched_synonym' => 'banana yogurts',
				'tag' => 'banana yogurts'
			}
		],
	},
	{
		desc => 'Match at start and inside, return start first',
		tagtype => "test",
		lc => "en",
		string => "yog",
		expected => [
			{
				'matched_synonym' => 'yogurts',
				'tag' => 'yogurts'
			},
			{
				'matched_synonym' => 'Passion fruit yogurts',
				'tag' => 'Passion fruit yogurts'
			},
			{
				'matched_synonym' => 'banana yogurts',
				'tag' => 'banana yogurts'
			},
			{
				'matched_synonym' => 'lemon yogurts',
				'tag' => 'lemon yogurts'
			},
		],
	},

);

foreach my $test_ref (@suggest_tests) {
	my @results
		= ProductOpener::TaxonomySuggestions::get_taxonomy_suggestions_with_synonyms("en:world", $test_ref->{tagtype},
		$test_ref->{lc}, $test_ref->{string}, {}, {});
	if (not is(\@results, $test_ref->{expected})) {
		diag Dumper($test_ref, \@results);
	}
}

done_testing();
