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

use ProductOpener::Tags qw/retrieve_tags_taxonomy display_taxonomy_tag/;
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

# The index is shared between requests, but the order the entries are scanned in must not be.
#
# For the packaging taxonomies the list of entries is built from the popularity of the shapes and
# materials for one country, one set of categories and one shape, so it differs from one request to
# the next while the index it is scanned against is keyed on the taxonomy and the language alone.
# Scanning the index in its own order froze that ranking at whichever context reached the worker
# first: a later request with a different context rebuilt the right list and then ignored it.
#
# The index now holds the resolved names and the normalized synonyms, which are the same whatever
# the context, and the scan takes its order from the list the request came in with. That is what
# the cases below pin: the index built from one order has to answer for any other order.

clear_suggestions_index();

# Entries of the packaging_shapes taxonomy, in the order a first request would get them for one
# country and one set of categories: the popular shapes come first. All three start with "bottle",
# so they all match the same way and the order they are returned in is the order they are given in
# (entries are grouped by how well they match before that order matters).
my @ordered_one = ("bottle", "bottle-cap", "bottle-or-vial");

# The first request builds the index that the requests after it share
my $shared_index_ref
	= ProductOpener::TaxonomySuggestions::_get_suggestions_index("packaging_shapes", "en", \@ordered_one);

# A second request, same taxonomy and same language, but the entries in another order, which is
# what the popularity of another country or another set of categories gives

my @ordered_two = reverse @ordered_one;

my @reused
	= map {$_->{tag}}
	ProductOpener::TaxonomySuggestions::_filter_suggestions($shared_index_ref, \@ordered_two, "packaging_shapes", "en",
	"bottle", {limit => 10});

is(scalar(@reused), 3, "every entry of the request is answered from the shared index");

# The entry the request asked for first has to be the one returned first. The name is looked up
# here rather than read back out of the index, so that this case reports what it found instead of
# dying on an index of a shape it did not expect.
is(
	$reused[0],
	display_taxonomy_tag("en", "packaging_shapes", $ordered_two[0]),
	"the suggestions follow the order of the request, not the order the index was built in"
);

# And the ranking a request asks for has to come out the same whether or not the index was already
# there, which is what an index that carries its own order with it breaks

my @built_here
	= map {$_->{tag}}
	ProductOpener::TaxonomySuggestions::_filter_suggestions(
	ProductOpener::TaxonomySuggestions::_build_suggestions_index("packaging_shapes", "en", \@ordered_two),
	\@ordered_two, "packaging_shapes", "en", "bottle", {limit => 10});

is(join("|", @reused), join("|", @built_here), "a reused index answers the same as an index built for this request");

clear_suggestions_index();

done_testing();
