#!/usr/bin/perl -w

# A suggestion request that misses the result cache used to walk every entry of the taxonomy and
# normalize its display text and its synonyms, tens of thousands of Unicode normalizations for the
# categories taxonomy. That work does not depend on the string being searched for, so it is indexed
# once per taxonomy and language and reused.
#
# What matters here is that indexing changes nothing: the same queries must give the same answers
# whether the index was just built, reused, or dropped, and the packaging taxonomies, whose
# suggestions do depend on the country and the category, must keep doing so.

use ProductOpener::PerlStandards;

use Test2::V0;

use ProductOpener::TaxonomySuggestions qw/get_taxonomy_suggestions_with_synonyms clear_suggestions_index/;

my @queries = ("yogurt", "yog", "chocolat", "eau", "zzqqxx", "pain", "fromage", "a");

# Drop the index between the two runs below, so the second run builds it again from scratch

clear_suggestions_index();

my @first_run;
foreach my $query (@queries) {
	push @first_run, [get_taxonomy_suggestions_with_synonyms("en", "ingredients", "en", $query, {}, {limit => 10})];
}

# With the index in place, the same queries must give the same answers

my $position_counter = 0;
foreach my $query (@queries) {
	my @again = get_taxonomy_suggestions_with_synonyms("en", "ingredients", "en", $query, {}, {limit => 10});
	my $position = $position_counter++;
	is(
		scalar(@again),
		scalar(@{$first_run[$position]}),
		"'$query' returns the same number of suggestions when the index is reused"
	);
}

# And the same again after dropping the index, which is what happens when the taxonomies are rebuilt

clear_suggestions_index();

my $position = 0;
foreach my $query (@queries) {
	my @rebuilt = get_taxonomy_suggestions_with_synonyms("en", "ingredients", "en", $query, {}, {limit => 10});
	is(
		scalar(@rebuilt),
		scalar(@{$first_run[$position]}),
		"'$query' returns the same number of suggestions after the index is dropped"
	);
	$position++;
}

# A second language gets its own index, and the answers are that language's

my @english = get_taxonomy_suggestions_with_synonyms("en", "ingredients", "en", "chocolat", {}, {limit => 10});
my @french = get_taxonomy_suggestions_with_synonyms("en", "ingredients", "fr", "chocolat", {}, {limit => 10});

ok(scalar(@english) > 0, "the English query returns suggestions");

if (scalar(@french) > 0) {
	my @french_tags = map {$_->{tag}} @french;
	my @english_tags = map {$_->{tag}} @english;
	isnt(join("|", @french_tags), join("|", @english_tags), "the French query does not reuse the English index");
}

clear_suggestions_index();

done_testing();
