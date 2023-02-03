# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2023 Association Open Food Facts
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
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

=head1 NAME

ProductOpener::Recipes - Analyze the distribution of ingredients in a set of products

=head1 SYNOPSIS

This module contains functions to compute the distribution of specific ingredients in
a specified set of products.

For instance, one can compute the distribution of water, sugar and fruits 
for products in the fruit nectar category.

Functions in this module can be called through scripts for batch processing,
and/or they could also be called for real time analysis through the API or web interface
(for a small enough set of products).

=head1 DESCRIPTION

The ingredients list is first analyzed with the Ingredients.pm module to identify
each ingredient and estimate the percentage of each ingredient.

Then each ingredient is matched against the specified list of parents ingredients.
(e.g. if we want the distribution of water, sugar and fruits, "apple" will be mapped to fruits.)

=cut

package ProductOpener::Recipes;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

use Log::Any qw($log);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(

		&compute_product_recipe
		&add_product_recipe_to_set
		&analyze_recipes

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::Lang qw/:all/;

=head1 FUNCTIONS


=head2 compute_product_recipe( $product_ref, $parent_ingredients_ref )

Given a list of parent ingredients, analyze the ingredients of the parent
to compute the percentage of each parent ingredient.

=head3 Arguments

=head4 product reference $product_ref

Loaded from the MongoDB database, Storable files, or the OFF API.

=head4 list of parent ingredients $parent_ingredients_ref

Reference to an array of canonicalized ingredients.

=head3 Return values

Percentages are returned in a hash that contains the parent ingredients
canonicalized ids as the key, and the percentage as a value.

2 extra keys are also returned:

- "unknown": for ingredients that are not known in the taxonomy
- "other": for ingredients that are known but are not children of any of the
specified parent ingredients.

=cut

sub compute_product_recipe ($product_ref, $parent_ingredients_ref) {

	$log->debug("compute recipe for product",
		{code => $product_ref->{code}, parent_ingredients_ref => $parent_ingredients_ref})
		if $log->is_debug();

	if ((not defined $product_ref->{ingredients}) or (scalar @{$product_ref->{ingredients}} == 0)) {
		$log->debug("compute recipe for product - empty ingredients", {code => $product_ref->{code}})
			if $log->is_debug();
		return;
	}

	my $recipe_ref = {"unknown" => 0, "other" => 0};

	foreach my $parent_ingredient (@{$parent_ingredients_ref}) {
		$recipe_ref->{$parent_ingredient} = 0;
	}

	if ((defined $product_ref->{ingredients_percent_analysis}) and ($product_ref->{ingredients_percent_analysis} < 0)) {
		$log->debug(
			"compute recipe for product - ingredients percent analysis returned impossible values",
			{code => $product_ref->{code}, ingredients => $product_ref->{ingredients}}
		) if $log->is_debug();
		$recipe_ref->{"warning"} = "ingredients_percent_analysis_failed";
	}

	# Traverse the ingredients tree, breadth first.
	# Stop if the ingredient matches one of the parent ingredients,
	# otherwise go into sub ingredients if they exist

	my @ingredients = ();

	for (my $i = 0; $i < @{$product_ref->{ingredients}}; $i++) {
		push @ingredients, $product_ref->{ingredients}[$i];
	}

	while (@ingredients) {

		my $ingredient_ref = shift @ingredients;
		my $ingredient_id = $ingredient_ref->{id};
		my $parent_of_current_ingredient = "other";
		if (not exists_taxonomy_tag("ingredients", $ingredient_id)) {
			$parent_of_current_ingredient = "unknown";
		}
		else {
			foreach my $parent_ingredient (@{$parent_ingredients_ref}) {
				if (is_a("ingredients", $ingredient_id, $parent_ingredient)) {
					$parent_of_current_ingredient = $parent_ingredient;
					last;
				}
			}
		}

		# If the ingredient is unknown or other and it has sub ingredients,
		# try to find the parent ingredients we care about in the sub ingredients

		if (    (($parent_of_current_ingredient eq "other") or ($parent_of_current_ingredient eq "unknown"))
			and (defined $ingredient_ref->{ingredients}))
		{
			for (my $i = 0; $i < @{$ingredient_ref->{ingredients}}; $i++) {
				push @ingredients, $ingredient_ref->{ingredients}[$i];
			}
		}
		else {

			# If ingredients percent analysis failed, percent_estimate may not be defined
			my $percent = $ingredient_ref->{percent_estimate};
			if (defined $ingredient_ref->{percent}) {
				$percent = $ingredient_ref->{percent};
			}
			$recipe_ref->{$parent_of_current_ingredient} += $percent;
		}
	}

	return $recipe_ref;
}

=head2 add_product_recipe_to_set( $recipes_ref, $product_ref, $recipe_ref )


=head3 Arguments


=head3 Return value


=cut

sub add_product_recipe_to_set ($recipes_ref, $product_ref, $recipe_ref) {

	# Do not add undefined recipes (e.g. products without ingredients)
	if (defined $recipe_ref) {

		push @$recipes_ref,
			{
			product => $product_ref,
			recipe => $recipe_ref,
			};
	}
	return;
}

=head2 analyze_recipes( $recipes_ref, $parent_ingredients_ref )


=head3 Arguments


=head3 Return value


=cut

sub analyze_recipes ($recipes_ref, $original_parent_ingredients_ref) {

	# Add "other" and "unknown"
	my $parent_ingredients_ref = [@$original_parent_ingredients_ref, "other", "unknown"];

	# Initialize the resulting analysis structure

	my $analysis_ref = {
		n => 0,
		parent_ingredients => $parent_ingredients_ref,
		ingredients => {

		},
	};

	foreach my $ingredient (@$parent_ingredients_ref) {
		$analysis_ref->{ingredients}{$ingredient} = {
			n => 0,
			min => 100,
			max => 0,
			sum => 0,
			values => [],
		};
	}

	# Go through each product recipe

	foreach my $product_recipe_ref (@$recipes_ref) {
		my $recipe_ref = $product_recipe_ref->{recipe};
		$analysis_ref->{n}++;
		foreach my $ingredient (@$parent_ingredients_ref) {
			push @{$analysis_ref->{ingredients}{$ingredient}{values}}, $recipe_ref->{$ingredient};
			if ($recipe_ref->{$ingredient} > 0) {
				$analysis_ref->{ingredients}{$ingredient}{n} += 1;
				$analysis_ref->{ingredients}{$ingredient}{sum} += $recipe_ref->{$ingredient};
			}
			if ($recipe_ref->{$ingredient} < $analysis_ref->{ingredients}{$ingredient}{min}) {
				$analysis_ref->{ingredients}{$ingredient}{min} = $recipe_ref->{$ingredient};
			}
			if ($recipe_ref->{$ingredient} > $analysis_ref->{ingredients}{$ingredient}{max}) {
				$analysis_ref->{ingredients}{$ingredient}{max} = $recipe_ref->{$ingredient};
			}
		}
	}

	# Compute some statistics

	foreach my $ingredient (@$parent_ingredients_ref) {
		$analysis_ref->{ingredients}{$ingredient}{mean}
			= $analysis_ref->{ingredients}{$ingredient}{sum} / $analysis_ref->{n};
		# Put min to 0 if there were no products with the ingredient
		if ($analysis_ref->{ingredients}{$ingredient}{min} > $analysis_ref->{ingredients}{$ingredient}{max}) {
			$analysis_ref->{ingredients}{$ingredient}{min} = $analysis_ref->{ingredients}{$ingredient}{max};
		}
	}

	return $analysis_ref;
}

1;
