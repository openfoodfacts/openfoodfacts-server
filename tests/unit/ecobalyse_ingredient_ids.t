#!/usr/bin/perl -w

# Tests of the selection of Ecobalyse ids (with label and origin variants) for ingredients

use Test2::V0;

use ProductOpener::PerlStandards;
use ProductOpener::Tags qw/get_property/;
use ProductOpener::Ingredients qw/get_missing_ecobalyse_ids/;
use ProductOpener::LoadData qw/load_data/;
use File::Basename qw/dirname/;

load_data();

# Ecobalyse ids are generated from Ecobalyse data and change when the data is updated:
# expected ids are read from the ingredients taxonomy instead of being hardcoded,
# and the taxonomy data the tests depend on is checked first.

sub ingredient_property ($tagid, $property) {
	return get_property("ingredients", $tagid, $property);
}

my @preconditions = (
	# en:rice has an organic variant, en:rice-flour (child of en:rice) has a base match but no organic variant
	["en:rice", "ecobalyse_labels_en_organic_id:en", 1],
	["en:rice-flour", "ecobalyse_id:en", 1],
	["en:rice-flour", "ecobalyse_labels_en_organic_id:en", 0],
	# en:orange has an organic French variant, en:orange-juice (child of en:orange) has a base match
	# but no organic, French or EU variant
	["en:orange", "ecobalyse_labels_en_organic_origins_en_france_id:en", 1],
	["en:orange-juice", "ecobalyse_id:en", 1],
	["en:orange-juice", "ecobalyse_labels_en_organic_origins_en_france_id:en", 0],
	["en:orange-juice", "ecobalyse_labels_en_organic_origins_en_europe_and_maghreb_id:en", 0],
	["en:orange-juice", "ecobalyse_labels_en_organic_id:en", 0],
	["en:orange-juice", "ecobalyse_origins_en_france_id:en", 0],
	["en:orange-juice", "ecobalyse_origins_en_europe_and_maghreb_id:en", 0],
	# en:minced-beef has no Ecobalyse data, its parent en:beef has an organic French variant
	["en:minced-beef", "ecobalyse_id:en", 0],
	["en:beef", "ecobalyse_labels_en_organic_origins_en_france_id:en", 1],
	# en:sardine has no Ecobalyse data, its parent en:fish has a proxy with a French variant
	["en:sardine", "ecobalyse_id:en", 0],
	["en:sardine", "ecobalyse_proxy_id:en", 0],
	["en:fish", "ecobalyse_proxy_origins_en_france_id:en", 1],
	# en:duck and en:rabbit have no Ecobalyse data, en:poultry and en:rabbit have a proxy with a French variant
	["en:duck", "ecobalyse_proxy_id:en", 0],
	["en:poultry", "ecobalyse_proxy_origins_en_france_id:en", 1],
	["en:rabbit", "ecobalyse_proxy_origins_en_france_id:en", 1],
);

foreach my $precondition (@preconditions) {
	my ($tagid, $property, $expected_defined) = @$precondition;
	is(defined(ingredient_property($tagid, $property)) ? 1 : 0,
		$expected_defined,
		"taxonomy precondition: $tagid " . ($expected_defined ? "has" : "does not have") . " $property");
}

my @tests = (
	# Ingredient with its own variant
	[
		"French organic orange: own organic French variant",
		{id => "en:orange", labels => "en:organic", origins => "en:france"},
		"ecobalyse", "en:orange", "ecobalyse_labels_en_organic_origins_en_france",
	],
	# Ingredient without the variant, but with a base match: the variant of the parent is not used
	[
		"organic rice flour: rice flour base match, not the organic variant of rice",
		{id => "en:rice-flour", labels => "en:organic"},
		"ecobalyse", "en:rice-flour", "ecobalyse",
	],
	[
		"French organic orange juice: orange juice base match, not the organic French variant of orange",
		{id => "en:orange-juice", labels => "en:organic", origins => "en:france"},
		"ecobalyse", "en:orange-juice", "ecobalyse",
	],
	# Ingredient without its own data: the base match and the variant of the parent are used
	[
		"French organic minced beef: organic French variant of beef",
		{id => "en:minced-beef", labels => "en:organic", origins => "en:france"},
		"ecobalyse", "en:beef", "ecobalyse_labels_en_organic_origins_en_france",
	],
	[
		"French sardine: French variant of the fish proxy", {id => "en:sardine", origins => "en:france"},
		"ecobalyse_proxy", "en:fish",
		"ecobalyse_proxy_origins_en_france",
	],
	[
		"French duck: French variant of the poultry proxy", {id => "en:duck", origins => "en:france"},
		"ecobalyse_proxy", "en:poultry",
		"ecobalyse_proxy_origins_en_france",
	],
	["rabbit: rabbit proxy", {id => "en:rabbit"}, "ecobalyse_proxy", "en:rabbit", "ecobalyse_proxy",],
);

foreach my $test_ref (@tests) {
	my ($test_name, $ingredient_ref, $expected_prefix, $expected_tagid, $expected_property) = @$test_ref;
	my $other_prefix = $expected_prefix eq "ecobalyse" ? "ecobalyse_proxy" : "ecobalyse";
	my @missing = get_missing_ecobalyse_ids([$ingredient_ref]);
	is(\@missing, [], "$test_name - no missing id");
	is(
		$ingredient_ref->{$expected_prefix . "_id"},
		ingredient_property($expected_tagid, $expected_property . "_id:en"),
		"$test_name - id"
	);
	is(
		$ingredient_ref->{$expected_prefix . "_name"},
		ingredient_property($expected_tagid, $expected_property . "_name:fr"),
		"$test_name - name"
	);
	is($ingredient_ref->{$other_prefix . "_id"}, undef, "$test_name - no $other_prefix id");
}

# OFF ingredients listed in off_ingredients_without_ecobalyse_data.tsv have "undef" base ids
# that stop the inheritance of the Ecobalyse data of their parents (e.g. the en:poultry proxy for foie gras)

my $blocked_file = dirname(__FILE__) . "/../../external-data/ecobalyse/off_ingredients_without_ecobalyse_data.tsv";
open(my $blocked_fh, '<:encoding(UTF-8)', $blocked_file) or die "Cannot open $blocked_file: $!";
my @blocked_tagids = map {(split /\t/)[0]} grep {(not /^#/) and /\S/} map {chomp; $_} <$blocked_fh>;
close($blocked_fh);
ok(scalar(grep {$_ eq "en:duck-foie-gras"} @blocked_tagids), "en:duck-foie-gras is blocked");

foreach my $tagid (@blocked_tagids) {
	foreach my $property ("ecobalyse_id:en", "ecobalyse_proxy_id:en") {
		is(ingredient_property($tagid, $property), "undef", "blocked $tagid has $property undef in the taxonomy");
	}
}

my @blocked_tests = (
	# blocked ingredient, with or without label and origin
	{id => "en:duck-foie-gras"},
	{id => "en:duck-foie-gras", labels => "en:organic", origins => "en:france"},
	{id => "en:duck-foie-gras", origins => "en:spain"},
	{id => "fr:foie-gras-d-oie", origins => "en:france"},
	# child of a blocked ingredient
	{id => "fr:foie-gras-de-canard-du-sud-ouest", origins => "en:france"},
);

foreach my $ingredient_ref (@blocked_tests) {
	my $test_name = join(" ", map {"$_=$ingredient_ref->{$_}"} sort keys %$ingredient_ref);
	my @missing = get_missing_ecobalyse_ids([$ingredient_ref]);
	is(\@missing, [$ingredient_ref->{id}], "$test_name - missing id");
	is($ingredient_ref->{ecobalyse_id}, undef, "$test_name - no ecobalyse id");
	is($ingredient_ref->{ecobalyse_proxy_id}, undef, "$test_name - no ecobalyse proxy id");
}

done_testing();
