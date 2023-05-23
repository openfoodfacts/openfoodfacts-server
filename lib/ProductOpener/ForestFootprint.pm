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

ProductOpener::ForestFootprint - compute the forest footprint of a food product

=head1 SYNOPSIS

C<ProductOpener::Ecoscore> is used to compute the forest footprint of a food product.

=head1 DESCRIPTION

The modules implements the forest footprint computation as defined by the French NGO Envol Vert.

The computation is based on the amount of soy needed to produce the ingredients,
and the risk that that soy contributed to deforestation.

=cut

package ProductOpener::ForestFootprint;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

use Log::Any qw($log);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(

		&load_forest_footprint_data
		&compute_forest_footprint

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Config qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Store qw/:all/;

use Storable qw(dclone freeze);
use Text::CSV();

my %forest_footprint_data = (ingredients_categories => []);

=head1 FUNCTIONS

=head2 load_forest_footprint_data ()

Loads data needed to compute the forest footprint.

=cut

sub load_forest_footprint_data() {

	my $errors = 0;

	my $csv_options_ref = {binary => 1, sep_char => ","};    # should set binary attribute.
	my $csv = Text::CSV->new($csv_options_ref)
		or die("Cannot use CSV: " . Text::CSV->error_diag());

	# Each file contains a category of ingredients: chicken, eggs

	for (my $k = 0; $k <= 1; $k++) {

		my $csv_file
			= $data_root . "/external-data/forest-footprint/envol-vert/Empreinte Forêt - Envol Vert - OFF.csv.$k";
		my $encoding = "UTF-8";

		$log->debug("opening forest footprint CSV file", {file => $csv_file}) if $log->is_debug();

		my @rows = ();

		if (open(my $io, "<:encoding($encoding)", $csv_file)) {

			my $row_ref;

			# Load the complete file as the data for each ingredient is in columns and not in rows

			while ($row_ref = $csv->getline($io)) {

				push @rows, $row_ref;
			}

			# 1st column: title
			# 2nd column: unit
			# Each of the following columns contains data for a specific ingredient type with specific conditions on categories, labels, origins etc.
			# The 3rd column is the most generic (e.g. "chicken"), and the columns on the right are the most specific (e.g. "organic chicken with AB label")

			# We are going to create an array of ingredient types starting with the ones that are the most on the right,
			# as we can select them and stop matching if their conditions are met.

			my @types = ();
			my $errors = 0;

			for (my $i = scalar(@{$rows[0]}) - 1; $i >= 2; $i--) {

				my %type = (
					name => $rows[0][$i],
					soy_feed_factor => $rows[5][$i] + 0,
					soy_yield => $rows[6][$i] + 0,
					deforestation_risk => $rows[7][$i] + 0,
					conditions => [],
				);

				# Conditions are on 2 lines, each of the form:
				# [tagtype]_[language code]:[tag value],[tag value..] ; [other tagtype values]
				# e.g. "labels_fr:volaille française,igp,aop,poulet français ; origins_fr:france"
				foreach my $j (2, 3) {
					next if $rows[$j][$i] eq "";

					my @tags = ();

					foreach my $tagtype_values (split(/;/, $rows[$j][$i])) {
						if ($tagtype_values =~ /(\S+)_([a-z][a-z])(?::|=)(.+)/) {
							my ($tagtype, $language, $values) = ($1, $2, $3);

							foreach my $value (split(/,/, $values)) {

								next if $value =~ /^(\s*)$/;

								my $tagid;

								if (defined $taxonomy_fields{$tagtype}) {
									$tagid = canonicalize_taxonomy_tag($language, $tagtype, $value);

									if (not exists_taxonomy_tag($tagtype, $tagid)) {

										$log->error(
											"forest footprint condition does not exist in taxonomy",
											{tagtype => $tagtype, tagid => $tagid, value => $value}
										) if $log->is_error();
										$errors++;
									}
								}
								else {
									$tagid = get_string_id_for_lang($language, $value);
								}

								push @tags, [$tagtype, $tagid];
							}
						}
					}

					if (scalar @tags > 0) {
						push @{$type{conditions}}, \@tags;
					}
				}

				push @types, \%type;
			}

			# Starting from line 12, each line contains 1 ingredient or category and the corresponding transformation factor
			# Critère OFF sur les ingrédients ou les catégories		Facteur de transformation
			# ingredients_fr=poulet	1
			# ingredients_fr=viande de poulet	0,75
			# We will reverse the order as the most specific items come last

			my $ingredients_category_data_ref
				= {category => "chicken", ingredients => [], categories => [], types => \@types};

			for (my $j = 12; $j < scalar(@rows) - 1; $j++) {

				if ($rows[$j][0] =~ /(\S+)_([a-z][a-z])(?::|=)(.+)/) {
					my ($tagtype, $language, $values) = ($1, $2, $3);

					my $processing_factor = $rows[$j][1] + 0;    # Add 0 to convert string to number

					foreach my $value (split(/,/, $values)) {

						next if $value =~ /^(\s*)$/;

						my $tagid;

						if (defined $taxonomy_fields{$tagtype}) {
							$tagid = canonicalize_taxonomy_tag($language, $tagtype, $value);

							if (not exists_taxonomy_tag($tagtype, $tagid)) {

								$log->error("forest footprint ingredient or category tag does not exist in taxonomy",
									{tagtype => $tagtype, tagid => $tagid})
									if $log->is_error();
								$errors++;
							}
						}
						else {
							$tagid = get_string_id_for_lang($language, $value);
						}

						# tag + transformation factor
						unshift @{$ingredients_category_data_ref->{$tagtype}}, [$tagid, $processing_factor];
					}
				}
			}

			push @{$forest_footprint_data{ingredients_categories}}, $ingredients_category_data_ref;

			$log->debug("forest footprint CSV data",
				{csv_file => $csv_file, ingredients_category_data_ref => $ingredients_category_data_ref})
				if $log->is_debug();

			if ($errors) {
				die("$errors unrecognized tags in CSV $csv_file");
			}
		}
		else {
			die("Could not open forest footprint CSV $csv_file: $!");
		}
	}
	return;
}

=head2 compute_forest_footprint ( $product_ref )

C<compute_forest_footprint()> computes the forest footprint of a food product, and stores the details of the computation.

=head3 Arguments

=head4 Product reference $product_ref

=head3 Return values

The forest footprint and computations details are stored in the product reference passed as input parameter.

Returned values:

- ecoscore_score : numeric Eco-Score value
- ecoscore_grade : corresponding A to E grade
- forest_footprint_data : forest footprint computation details

=cut

sub compute_forest_footprint ($product_ref) {

	$product_ref->{forest_footprint_data} = {ingredients => [],};

	# If we have ingredients, analyze each ingredient
	if (defined $product_ref->{ingredients}) {
		$product_ref->{forest_footprint_data}{ingredients} = [];
		compute_footprints_of_ingredients(
			$product_ref,
			$product_ref->{forest_footprint_data}{ingredients},
			$product_ref->{ingredients}
		);
	}
	# if we don't have ingredients, we may have a category that matches exactly one ingredient
	# e.g. for a fresh whole chicken, we may not have ingredients listed
	# in that case, we construct an ingredients structure with only one ingredient
	else {
		compute_footprint_of_category($product_ref, $product_ref->{forest_footprint_data}{ingredients});
	}

	# Remove forest-footprint-[grade] tags
	foreach my $grade (qw(a b c d e)) {
		remove_tag($product_ref, "misc", "en:forest-footprint-" . $grade);
	}

	# Compute total footprint
	if (scalar(@{$product_ref->{forest_footprint_data}{ingredients}}) > 0) {
		$product_ref->{forest_footprint_data}{footprint_per_kg} = 0;
		foreach my $ingredient_ref (@{$product_ref->{forest_footprint_data}{ingredients}}) {
			$product_ref->{forest_footprint_data}{footprint_per_kg} += $ingredient_ref->{footprint_per_kg};
		}

		# Assign a A to E grade (used for icons and descriptions)

		my $grade = "e";

		if ($product_ref->{forest_footprint_data}{footprint_per_kg} < 0.5) {
			$grade = "a";
		}
		elsif ($product_ref->{forest_footprint_data}{footprint_per_kg} < 1) {
			$grade = "b";
		}
		elsif ($product_ref->{forest_footprint_data}{footprint_per_kg} < 1.5) {
			$grade = "c";
		}
		elsif ($product_ref->{forest_footprint_data}{footprint_per_kg} < 2) {
			$grade = "d";
		}
		$product_ref->{forest_footprint_data}{grade} = $grade;

		add_tag($product_ref, "misc", "en:forest-footprint-computed");
		add_tag($product_ref, "misc", "en:forest-footprint-" . $grade);
	}
	else {
		delete $product_ref->{forest_footprint_data};
		remove_tag($product_ref, "misc", "en:forest-footprint-computed");
	}
	return;
}

=head2 add_footprint ( $product_ref, $ingredient_ref, $footprints_ref, $ingredients_category_ref, $footprint_ref )

This function is called when we have an ingredient or a category for which we have a forest footprint.
It determines the type of the footprint based on labels, origins etc. and adds a corresponding footprint
to the list of footprints for the products (possibly several if the product has multiple ingredients with a footprint)

=head3 Synopsis

add_footprint($product_ref, $ingredient_ref, $footprints_ref, $ingredients_category_ref, {
							tag => ["ingredients", $ingredients_ref->{id}, $category_ingredient_id],
							percent_estimate => $ingredients_ref->{percent_estimate},
					});
					
=cut

sub add_footprint ($product_ref, $ingredient_ref, $footprints_ref, $ingredients_category_ref, $footprint_ref) {

	# Check which type has matching conditions for the product

	foreach my $type_ref (@{$ingredients_category_ref->{types}}) {

		$log->debug("compute_footprints_of_ingredients - checking type", {type => $type_ref}) if $log->is_debug();

		my $match = 1;    # The type will match if there are no conditions
		my @conditions_tags = ();    # We will return the tags that match the conditions

		# Check all conditions

		foreach my $condition_tags_ref (@{$type_ref->{conditions}}) {

			$log->debug(
				"compute_footprints_of_ingredients - checking condition for type",
				{conditions => $type_ref->{conditions}, ingredient_ref => $ingredient_ref}
			) if $log->is_debug();

			$match = 0;

			# Check if we have a matching tag for the condition

			foreach my $tag_ref (@{$condition_tags_ref}) {

				my ($tagtype, $tagid) = @$tag_ref;

				if (has_tag($product_ref, $tagtype, $tagid)) {

					$log->debug("compute_footprints_of_ingredients - matching product tag for condition",
						{tag => $tag_ref, conditions => $type_ref->{conditions}})
						if $log->is_debug();

					$match = 1;
					push @conditions_tags, $tag_ref;
					last;
				}
				# Also check if we have the label or origin at the ingredients level
				elsif ( (defined $ingredient_ref)
					and (defined $ingredient_ref->{$tagtype})
					and ($ingredient_ref->{$tagtype} =~ /(?:^|,)$tagid(?:,|$)/))
				{

					$log->debug("compute_footprints_of_ingredients - matching ingredient tag for condition",
						{tag => $tag_ref, conditions => $type_ref->{conditions}})
						if $log->is_debug();

					$match = 1;
					push @conditions_tags, $tag_ref;
					last;
				}
			}
		}

		if ($match) {

			my $cloned_type_ref = dclone($type_ref);
			delete $cloned_type_ref->{conditions};    # No need to return all the conditions

			$log->debug("compute_footprints_of_ingredients - matching type", {cloned_type => $cloned_type_ref})
				if $log->is_debug();

			$footprint_ref->{type} = $cloned_type_ref;
			$footprint_ref->{conditions_tags} = \@conditions_tags;
			$footprint_ref->{footprint_per_kg}
				= ($footprint_ref->{percent} / 100)
				/ $footprint_ref->{processing_factor}
				* $footprint_ref->{type}{soy_feed_factor}
				/ $footprint_ref->{type}{soy_yield}
				* $footprint_ref->{type}{deforestation_risk};

			push @$footprints_ref, $footprint_ref;

			last;
		}
	}
	return;
}

=head2 compute_footprints_of_ingredients ( $product_ref, $footprints_ref, $ingredients_ref )

Computes the forest footprints of the ingredients.

The function is recursive and may call itself for sub-ingredients.

=head3 Arguments

=head4 Product reference $product_ref

Used to determine the footprint type based on labels, categories, origins etc.

=head4 Footprints reference $footprints_ref

Data structure to which we will add the forest footprints for the ingredients specified in $ingredients_ref

=head4 Ingredients reference $ingredients_ref

Ingredients reference that may contains an ingredients structure for sub-ingredients.

=head3 Return values

The footprints are stored in $footprints_ref

=cut

sub compute_footprints_of_ingredients ($product_ref, $footprints_ref, $ingredients_ref) {

	# The ingredients array contains sub-ingredients in nested ingredients properties
	# and they are also listed at the end on the ingredients array, without the rank property
	# For this aggregation, we want to use the nested sub-ingredients,
	# and ignore the same sub-ingredients listed at the end
	my $ranked = 0;

	# Return the number of ingredients with a footprint
	my $ingredients_with_footprint = 0;

	foreach my $ingredient_ref (@$ingredients_ref) {

		# If we are at the first level of the ingredients array,
		# ingredients have a rank, except the sub-ingredients listed at the end
		if ($ingredient_ref->{rank}) {
			$ranked = 1;
		}
		elsif ($ranked) {
			# The ingredient does not have a rank, but a previous ingredient had one:
			# we are at the first level of the ingredients array,
			# and we are at the end where the sub-ingredients have been added
			last;
		}

		# Check if the ingredient belongs to one of the ingredients categories for which their is a forest footprint

		$log->debug("compute_footprints_of_ingredients - checking ingredient match",
			{ingredient_id => $ingredient_ref->{id}})
			if $log->is_debug();

		my $current_ingredient_category;

		# If the ingredient has sub-ingredients, compute the forest footprint of sub-ingredients
		# e.g. Viande de poulet en salaison (viande de poulet, eau, saumure)
		# If we don't have a footprint for sub-ingredients, we will try on the ingredient

		if (defined $ingredient_ref->{ingredients}) {
			$log->debug("compute_footprints_of_ingredients - ingredient has subingredients",
				{ingredient_id => $ingredient_ref->{id}})
				if $log->is_debug();
			my $sub_ingredients_with_footprint
				= compute_footprints_of_ingredients($product_ref, $footprints_ref, $ingredient_ref->{ingredients});
			if ($sub_ingredients_with_footprint > 0) {
				$ingredients_with_footprint += 1;
				# If a sub-ingredient has a footprint, we do not match also on the ingredient
				next;
			}
		}

		foreach my $ingredients_category_ref (@{$forest_footprint_data{ingredients_categories}}) {

			$log->debug(
				"compute_footprints_of_ingredients - checking ingredient match - category",
				{ingredient_id => $ingredient_ref->{id}, category => $ingredients_category_ref->{category}}
			) if $log->is_debug();

			foreach my $category_ingredient_ref (@{$ingredients_category_ref->{ingredients}}) {

				my ($category_ingredient_id, $processing_factor) = @$category_ingredient_ref;

				$log->debug(
					"compute_footprints_of_ingredients - checking ingredient match - category - category_ingredient",
					{ingredient_id => $ingredient_ref->{id}, category_ingredient_id => $category_ingredient_id}
				) if $log->is_debug();

				if (is_a("ingredients", $ingredient_ref->{id}, $category_ingredient_id)) {
					$log->debug("compute_footprints_of_ingredients - ingredient match",
						{ingredient_id => $ingredient_ref->{id}, category_ingredient_id => $category_ingredient_id})
						if $log->is_debug();

					my $footprint_ref = {
						tag_type => "ingredients",
						tag_id => $ingredient_ref->{id},
						matching_tag_id => $category_ingredient_id,
						processing_factor => $processing_factor,
					};

					if (defined $ingredient_ref->{percent}) {
						$footprint_ref->{percent} = $ingredient_ref->{percent};
					}
					else {
						$footprint_ref->{percent} = $ingredient_ref->{percent_estimate};
						$footprint_ref->{percent_estimate} = $ingredient_ref->{percent_estimate};
					}

					add_footprint($product_ref, $ingredient_ref, $footprints_ref, $ingredients_category_ref,
						$footprint_ref);

					$current_ingredient_category = $category_ingredient_id;
					$ingredients_with_footprint += 1;

					last;
				}
			}

			if (defined $current_ingredient_category) {
				last;
			}
		}
	}

	return $ingredients_with_footprint;
}

=head2 compute_footprint_of_category ( $product_ref, $footprints_ref )

Computes the forest footprints associated with the category of the product,
if the product does not have ingredients (e.g. "whole chickens" category 
for which we may not have ingredients listed)

=head3 Arguments

=head4 Product reference $product_ref

Used to determine the footprint type based on labels, categories, origins etc.

=head4 Footprints reference $footprints_ref

Data structure to which we will add the forest footprints for the ingredients specified in $ingredients_ref

=head3 Return values

The footprints are stored in $footprints_ref

=cut

sub compute_footprint_of_category ($product_ref, $footprints_ref) {

	# Check if the ingredient belongs to one of the categories for which their is a forest footprint

	$log->debug(
		"compute_footprint_of_category - checking category match",
		{categories_tags => $product_ref->{categories_tags}}
	) if $log->is_debug();

	my $current_ingredient_category;

	foreach my $ingredients_category_ref (@{$forest_footprint_data{ingredients_categories}}) {

		$log->debug(
			"compute_footprint_of_category - checking category match - category",
			{ingredients_category => $ingredients_category_ref->{category}}
		) if $log->is_debug();

		foreach my $category_ref (@{$ingredients_category_ref->{categories}}) {

			my ($category_id, $processing_factor) = @$category_ref;

			$log->debug("compute_footprint_of_category - checking category match - category - category_ingredient",
				{category_id => $category_id})
				if $log->is_debug();

			if (has_tag($product_ref, "categories", $category_id)) {
				$log->debug("compute_footprint_of_category - category match", {category_id => $category_id})
					if $log->is_debug();

				add_footprint(
					$product_ref,
					undef,
					$footprints_ref,
					$ingredients_category_ref,
					{
						tag_type => "categories",
						tag_id => $category_id,
						percent => 100,
						processing_factor => $processing_factor,
					}
				);

				last;
			}
		}

		if (defined $current_ingredient_category) {
			last;
		}
	}
	return;
}

1;

