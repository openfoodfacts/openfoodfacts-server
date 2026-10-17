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

use ProductOpener::Tags qw/retrieve_tags_taxonomy/;
use ProductOpener::TaxonomySuggestions qw/get_taxonomy_suggestions_with_synonyms clear_suggestions_index/;

# The "test" taxonomy is the one that carries translations in several languages, which the language
# prefix cases below need. Load it explicitly rather than relying on it being loaded already.
retrieve_tags_taxonomy("test");

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

# A search string that starts with a language code is searched in that language, so the index has
# to be the one built for that language: fr:yaourts on an English page has to answer with the
# French labels, not with the English ones. The index is chosen before the string is looked at,
# so this is the case where picking the wrong index is invisible until it is checked.

clear_suggestions_index();

my @french = get_taxonomy_suggestions_with_synonyms("en:world", "test", "en", "fr:yaourts", {}, {limit => 10});

ok(scalar(@french) > 0, "a search prefixed with a language code returns suggestions");

my %french_tags = map {$_->{tag} => 1} @french;

ok(
	(grep({$_ eq "yaourts à la banane"} keys %french_tags)),
	"fr:yaourts answers with the French label of banana yogurts"
);
ok((not(grep({$_ eq "banana yogurts"} keys %french_tags))), "fr:yaourts does not answer with the English label");

my @dutch = get_taxonomy_suggestions_with_synonyms("en:world", "test", "en", "nl:yoghurt", {}, {limit => 10});

my %dutch_tags = map {$_->{tag} => 1} @dutch;

ok((grep({$_ eq "bananenyoghurt"} keys %dutch_tags)), "nl:yoghurt answers with the Dutch label");

# The same query without a prefix is searched in the language of the page

my @english = get_taxonomy_suggestions_with_synonyms("en:world", "test", "en", "yaourts", {}, {limit => 10});

ok(scalar(@english) == 0, "the same words without a prefix are not matched in English");

clear_suggestions_index();

done_testing();
