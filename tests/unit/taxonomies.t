#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test::More;
use Log::Any::Adapter 'TAP';

use ProductOpener::Test qw/:all/;
use ProductOpener::Tags qw/:all/;

my ($test_id, $test_dir, $expected_results_dir, $update_expected_results) = (init_expected_results(__FILE__));

ProductOpener::Tags::retrieve_tags_taxonomy("ingredients");

# Check the Eurocode properties of ingredients

my @ingredients = ProductOpener::Tags::get_all_taxonomy_entries("ingredients");

my %eurocodes = ();

foreach my $ingredient (@ingredients) {
	my $eurocode_2_group_3 = get_property("ingredients", $ingredient, "eurocode_2_group_3:en");
	if ($eurocode_2_group_3) {
		my $eurocode_2_group_2 = get_inherited_property("ingredients", $ingredient, "eurocode_2_group_2:en");

		if (not $eurocode_2_group_2) {
			fail("ingredient $ingredient is missing an inherited eurocode_2_group_2 property");
		}

		my $eurocode_2_group_3_prefix = $eurocode_2_group_3;
		$eurocode_2_group_3_prefix =~ s/\.[^\.]+$//;
		is($eurocode_2_group_3_prefix, $eurocode_2_group_2, "$eurocode_2_group_3 prefix matches eurocode_2_group_2");

		# Add to the list of known Eurocodes
		# We may have several taxonomy entries with the same eurocode_2_group_3,
		# we suffix them with the name of the ingredient
		$eurocodes{$eurocode_2_group_3 . " " . $ingredient} = {
			ingredient => $ingredient,
			eurocode_2_group_2 => $eurocode_2_group_2,
			eurocode_2_group_3 => $eurocode_2_group_3,
		};

	}
}

# Output the list of known Eurocodes in tab separated CSV
# Used to see diffs, and also to easily see which Eurocodes we have

if (!-e $expected_results_dir) {
	mkdir($expected_results_dir, 0755) or confess("Could not create $expected_results_dir directory: $!\n");
}

open(my $out, ">:encoding(UTF-8)", "$expected_results_dir/eurocodes.csv");
print $out "eurocode_2_group_2\teurocode_2_group_3\tingredient\n";
foreach my $eurocode_ingredient (sort keys %eurocodes) {

	print $out join("\t",
		$eurocodes{$eurocode_ingredient}{eurocode_2_group_2},
		$eurocodes{$eurocode_ingredient}{eurocode_2_group_3},
		$eurocodes{$eurocode_ingredient}{ingredient},
	) . "\n";
}
close $out;

# Check the units taxonomy

foreach my $tagid (get_all_taxonomy_entries("units")) {

	my $standard_unit = get_property("units", $tagid, "standard_unit:en");
	my $conversion_factor = get_property("units", $tagid, "conversion_factor:en");

	is(defined $standard_unit, 1, "$tagid has a standard unit");
	is(defined $conversion_factor, 1, "$tagid has a conversion factor");
}

done_testing();
