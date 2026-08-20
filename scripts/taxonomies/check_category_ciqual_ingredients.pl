#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2024 Association Open Food Facts
# Contact: contact@openfoodfacts.org
# Address: 21 rue des Iles, 94100 Saint-Maur des Fossés, France
#
# Product Opener is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

use Modern::Perl '2017';
use utf8;

binmode(STDIN, ":encoding(UTF-8)");
binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");

use Getopt::Long qw/GetOptions/;
use ProductOpener::Config qw/:all/;
use ProductOpener::Tags qw/:all/;

my $output_properties_file;

GetOptions("output_properties_file=s" => \$output_properties_file,)
	or die("Error in command line arguments\n");

my @ciqual_props = qw(ciqual_food_code:en ciqual_proxy_food_code:en ciqual_food_name:en ciqual_proxy_food_name:en);

my %category_ciqual;
my @properties_to_write;

my $categories = 0;
my $matching_ingredients_with_missing_props = 0;

foreach my $tagid (sort keys %{$translations_to{"categories"}}) {
	next if ((exists $just_synonyms{"categories"}) and (exists $just_synonyms{"categories"}{$tagid}));

	my @props;
	foreach my $prop (@ciqual_props) {
		my $value = get_property("categories", $tagid, $prop);
		push @props, [$prop, $value] if defined $value;
	}

	next unless @props;

	my $en_name = display_taxonomy_tag_name("en", "categories", $tagid);

	my $exists = 0;
	my $ingredient_tagid = canonicalize_taxonomy_tag("en", "ingredients", $en_name, \$exists);

	next if not $exists;

	my @missing;
	foreach my $entry (@props) {
		my ($prop, $value) = @$entry;
		# Check if the ingredient (or its parents) has the same property value as the category
		my $ing_value = $ingredient_tagid ? get_inherited_property("ingredients", $ingredient_tagid, $prop) : undef;
		push @missing, [$prop, $value, $ing_value] unless defined $ing_value;
	}

	if (@missing) {
		print "Category: $tagid ($en_name)\n";
		print "  Matched ingredient: $ingredient_tagid\n";

		foreach my $entry (@missing) {
			my ($prop, $cat_value, $ing_value) = @$entry;
			printf "  Missing %s: category=%s\n", $prop, $cat_value;
			push @properties_to_write, [$ingredient_tagid, $prop, $cat_value];
		}
		print "\n";
		$matching_ingredients_with_missing_props++;
	}
	$categories++;
}

print "Checked $categories categories with Ciqual properties.\n";
print "Found $matching_ingredients_with_missing_props matching ingredients with missing properties.\n";

if (defined $output_properties_file and @properties_to_write) {
	open my $fh, '>:encoding(utf8)', $output_properties_file
		or die "Cannot open $output_properties_file for writing: $!";
	foreach my $entry (@properties_to_write) {
		my ($canonical_id, $prop, $value) = @$entry;
		print $fh join("\t", $canonical_id, $prop, $value) . "\n";
	}
	close $fh;
	print "Wrote properties to $output_properties_file\n";
	print "You can add them to the taxonomy with:\n";
	print
		"  perl scripts/taxonomies/add_properties_to_taxonomy.pl --taxonomy_file taxonomies/food/ingredients.txt --properties_file $output_properties_file\n";
}
