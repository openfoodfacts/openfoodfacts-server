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

ProductOpener::Controller::Nutriscore - handling HTTP requests related to nutriscores

=cut

package ProductOpener::Controller::Nutriscore;
use ProductOpener::PerlStandards;


=head2 display_nutriscore_calculation_details( $nutriscore_data_ref, $version = "2021" )

Generates HTML code with information on how the Nutri-Score was computed for a particular product.

For each component of the Nutri-Score (energy, sugars etc.) it shows the input value,
the rounded value according to the Nutri-Score rules, and the corresponding points.

=cut

sub display_nutriscore_calculation_details ($nutriscore_data_ref, $version = "2021") {

	my $beverage_view;

	if ($nutriscore_data_ref->{is_beverage}) {
		$beverage_view = lang("nutriscore_is_beverage");
	}
	else {
		$beverage_view = lang("nutriscore_is_not_beverage");
	}

	# Select message that explains the reason why the proteins points have been counted or not

	my $nutriscore_protein_info;
	if ($nutriscore_data_ref->{negative_points} < 11) {
		$nutriscore_protein_info = lang("nutriscore_proteins_negative_points_less_than_11");
	}
	elsif ((defined $nutriscore_data_ref->{is_cheese}) and ($nutriscore_data_ref->{is_cheese})) {
		$nutriscore_protein_info = lang("nutriscore_proteins_is_cheese");
	}
	elsif (
		(
				((defined $nutriscore_data_ref->{is_beverage}) and ($nutriscore_data_ref->{is_beverage}))
			and ($nutriscore_data_ref->{fruits_vegetables_nuts_colza_walnut_olive_oils_points} == 10)
		)
		or (    ((not defined $nutriscore_data_ref->{is_beverage}) or (not $nutriscore_data_ref->{is_beverage}))
			and ($nutriscore_data_ref->{fruits_vegetables_nuts_colza_walnut_olive_oils_points} == 5))
		)
	{

		$nutriscore_protein_info = lang("nutriscore_proteins_maximum_fruits_points");
	}
	else {
		$nutriscore_protein_info = lang("nutriscore_proteins_negative_points_greater_or_equal_to_11");
	}

	# Generate a data structure that we will pass to the template engine

	my $template_data_ref = {

		beverage_view => $beverage_view,
		is_fat => $nutriscore_data_ref->{is_fat},

		nutriscore_protein_info => $nutriscore_protein_info,

		score => $nutriscore_data_ref->{score},
		grade => uc($nutriscore_data_ref->{grade}),
		positive_points => $nutriscore_data_ref->{positive_points},
		negative_points => $nutriscore_data_ref->{negative_points},

		# Details of positive and negative points, filled dynamically below
		# as the nutrients and thresholds are different for some products (beverages and fats)
		points_groups => []
	};

	my %points_groups = (
		"positive" => ["proteins", "fiber", "fruits_vegetables_nuts_colza_walnut_olive_oils"],
		"negative" => ["energy", "sugars", "saturated_fat", "sodium"],
	);

	foreach my $type ("positive", "negative") {

		# Initiate a data structure for the points of the group

		my $points_group_ref = {
			type => $type,
			points => $nutriscore_data_ref->{$type . "_points"},
			nutrients => [],
		};

		# Add the nutrients for the group
		foreach my $nutrient (@{$points_groups{$type}}) {

			my $nutrient_threshold_id = $nutrient;

			if (    (defined $nutriscore_data_ref->{is_beverage})
				and ($nutriscore_data_ref->{is_beverage})
				and (defined $points_thresholds{$nutrient_threshold_id . "_beverages"}))
			{
				$nutrient_threshold_id .= "_beverages";
			}
			if (($nutriscore_data_ref->{is_fat}) and ($nutrient eq "saturated_fat")) {
				$nutrient = "saturated_fat_ratio";
				$nutrient_threshold_id = "saturated_fat_ratio";
			}
			push @{$points_group_ref->{nutrients}},
				{
				id => $nutrient,
				points => $nutriscore_data_ref->{$nutrient . "_points"},
				maximum => scalar(@{$points_thresholds{$nutrient_threshold_id}}),
				value => $nutriscore_data_ref->{$nutrient},
				rounded => $nutriscore_data_ref->{$nutrient . "_value"},
				};
		}

		push @{$template_data_ref->{points_groups}}, $points_group_ref;
	}

	# Nutrition Score Calculation Template

	my $html;
	process_template('web/pages/product/includes/nutriscore_details.tt.html', $template_data_ref, \$html)
		|| return "template error: " . $tt->error();

	return $html;
}

=head2 data_to_display_nutrient_levels ( $product_ref )

Generates a data structure to display the nutrient levels (food traffic lights).

The resulting data structure can be passed to a template to generate HTML or the JSON data for a knowledge panel.

=head3 Arguments

=head4 Product reference $product_ref

=head3 Return values

Reference to a data structure with needed data to display.

=cut

sub data_to_display_nutrient_levels ($product_ref) {

	my $result_data_ref = {};

	# Do not display traffic lights for baby foods
	if (has_tag($product_ref, "categories", "en:baby-foods")) {

		$result_data_ref->{do_not_display} = 1;
	}

	# do not compute a score for dehydrated products to be rehydrated (e.g. dried soups, coffee, tea)
	# unless we have nutrition data for the prepared product

	my $prepared = "";

	foreach my $category_tag ("en:dried-products-to-be-rehydrated",
		"en:chocolate-powders", "en:dessert-mixes", "en:flavoured-syrups")
	{

		if (has_tag($product_ref, "categories", $category_tag)) {

			if ((defined $product_ref->{nutriments}{"energy_prepared_100g"})) {
				$prepared = '_prepared';
				last;
			}
			else {
				$result_data_ref->{do_not_display} = 1;
			}
		}
	}

	if (not $result_data_ref->{do_not_display}) {

		$result_data_ref->{nutrient_levels} = [];

		foreach my $nutrient_level_ref (@nutrient_levels) {
			my ($nid, $low, $high) = @{$nutrient_level_ref};

			if ((defined $product_ref->{nutrient_levels}) and (defined $product_ref->{nutrient_levels}{$nid})) {

				push @{$result_data_ref->{nutrient_levels}}, {
					nid => $nid,
					nutrient_level => $product_ref->{nutrient_levels}{$nid},
					nutrient_quantity_in_grams =>
						sprintf("%.2e", $product_ref->{nutriments}{$nid . $prepared . "_100g"}) + 0.0,
					nutrient_in_quantity => sprintf(
						lang("nutrient_in_quantity"),
						display_taxonomy_tag($lc, "nutrients", "zz:$nid"),
						lang($product_ref->{nutrient_levels}{$nid} . "_quantity")
					),
					# Needed for the current display on product page, can be removed once transitioned fully to knowledge panels
					nutrient_bold_in_quantity => sprintf(
						lang("nutrient_in_quantity"),
						"<b>" . display_taxonomy_tag($lc, "nutrients", "zz:$nid") . "</b>",
						lang($product_ref->{nutrient_levels}{$nid} . "_quantity")
					),
				};
			}
		}
	}

	return $result_data_ref;
}

=head2 data_to_display_nutriscore ($nutriscore_data_ref, $version = "2021" )

Generates a data structure to display the Nutri-Score.

The resulting data structure can be passed to a template to generate HTML or the JSON data for a knowledge panel.

=head3 Arguments

=head4 Product reference $product_ref

=head3 Return values

Reference to a data structure with needed data to display.

=cut

sub data_to_display_nutriscore ($product_ref, $version = "2021") {

	my $result_data_ref = {};

	# Nutri-Score data

	my @nutriscore_warnings = ();

	my $nutriscore_grade = deep_get($product_ref, "nutriscore", $version, "grade");
	my $nutriscore_data_ref = deep_get($product_ref, "nutriscore", $version, "data");
	# On old product revisions, nutriscore grade was in nutrition_grade_fr
	if ((not defined $nutriscore_grade) and ($version eq "2021")) {
		$nutriscore_grade = $product_ref->{"nutrition_grade_fr"};
		$nutriscore_data_ref = $product_ref->{nutriscore_data};
	}

	if ((defined $nutriscore_grade) and ($nutriscore_grade =~ /^[abcde]$/)) {

		$result_data_ref->{nutriscore_grade} = $nutriscore_grade;

		# Do not display a warning for water
		if (not(has_tag($product_ref, "categories", "en:spring-waters"))) {

			# Warning for nutrients estimated from ingredients
			if ($product_ref->{nutrition_score_warning_nutriments_estimated}) {
				push @nutriscore_warnings, lang("nutrition_grade_fr_nutriments_estimated_warning");
			}

			# Warning for tea and herbal tea in bags: state that the Nutri-Score applies
			# only when reconstituted with water only (no milk, no sugar)
			if (
				   (has_tag($product_ref, "categories", "en:tea-bags"))
				or (has_tag($product_ref, "categories", "en:herbal-teas-in-tea-bags"))
				# many tea bags are only under "en:teas", but there are also many tea beverages under "en:teas"
				or ((has_tag($product_ref, "categories", "en:teas"))
					and not(has_tag($product_ref, "categories", "en:tea-based-beverages")))
				)
			{
				push @nutriscore_warnings, lang("nutrition_grade_fr_tea_bags_note");
			}

			# Combined message when we miss both fruits and fiber
			if (    ($product_ref->{nutrition_score_warning_no_fiber})
				and (defined $product_ref->{nutrition_score_warning_no_fruits_vegetables_nuts})
				and ($product_ref->{nutrition_score_warning_no_fruits_vegetables_nuts} == 1))
			{
				push @nutriscore_warnings, lang("nutrition_grade_fr_fiber_and_fruits_vegetables_nuts_warning");
			}
			elsif ($product_ref->{nutrition_score_warning_no_fiber}) {
				push @nutriscore_warnings, lang("nutrition_grade_fr_fiber_warning");
			}
			elsif ($product_ref->{nutrition_score_warning_no_fruits_vegetables_nuts}) {
				push @nutriscore_warnings, lang("nutrition_grade_fr_no_fruits_vegetables_nuts_warning");
			}

			if ($product_ref->{nutrition_score_warning_fruits_vegetables_nuts_estimate}) {
				push @nutriscore_warnings,
					sprintf(
					lang("nutrition_grade_fr_fruits_vegetables_nuts_estimate_warning"),
					$product_ref->{nutriments}{"fruits-vegetables-nuts-estimate_100g"}
					);
			}
			if ($product_ref->{nutrition_score_warning_fruits_vegetables_nuts_from_category}) {
				push @nutriscore_warnings,
					sprintf(
					lang("nutrition_grade_fr_fruits_vegetables_nuts_from_category_warning"),
					display_taxonomy_tag(
						$lc, 'categories', $product_ref->{nutrition_score_warning_fruits_vegetables_nuts_from_category}
					),
					$product_ref->{nutrition_score_warning_fruits_vegetables_nuts_from_category_value}
					);
			}
			if ($product_ref->{nutrition_score_warning_fruits_vegetables_nuts_estimate_from_ingredients}) {
				push @nutriscore_warnings,
					sprintf(
					lang("nutrition_grade_fr_fruits_vegetables_nuts_estimate_from_ingredients_warning"),
					$product_ref->{nutrition_score_warning_fruits_vegetables_nuts_estimate_from_ingredients_value}
					);
			}
		}
	}
	# The Nutri-Score is unknown
	else {

		# Category without Nutri-Score: baby food, alcoholic beverages etc.
		if (has_tag($product_ref, "misc", "en:nutriscore-not-applicable")) {
			push @nutriscore_warnings, lang("nutriscore_not_applicable");
			$result_data_ref->{nutriscore_grade} = "not-applicable";
			$result_data_ref->{nutriscore_unknown_reason} = "not_applicable";
			$result_data_ref->{nutriscore_unknown_reason_short} = f_lang(
				"f_attribute_nutriscore_not_applicable_description",
				{
					category => display_taxonomy_tag_name(
						$lc, "categories",
						deep_get($product_ref, qw/nutriscore_data nutriscore_not_applicable_for_category/)
					)
				}
			);
		}
		else {

			$result_data_ref->{nutriscore_grade} = "unknown";

			# Missing category?
			if (has_tag($product_ref, "misc", "en:nutriscore-missing-category")) {
				push @nutriscore_warnings, lang("nutriscore_missing_category");
				$result_data_ref->{nutriscore_unknown_reason} = "missing_category";
				$result_data_ref->{nutriscore_unknown_reason_short} = lang("nutriscore_missing_category_short");
			}

			# Missing nutrition facts?
			if (has_tag($product_ref, "misc", "en:nutriscore-missing-nutrition-data")) {
				push @nutriscore_warnings, lang("nutriscore_missing_nutrition_data");
				if (not has_tag($product_ref, "misc", "en:nutriscore-missing-category")) {
					$result_data_ref->{nutriscore_unknown_reason} = "missing_nutrition_data";
					$result_data_ref->{nutriscore_unknown_reason_short}
						= lang("nutriscore_missing_nutrition_data_short");
				}
				else {
					$result_data_ref->{nutriscore_unknown_reason} = "missing_category_and_nutrition_data";
					$result_data_ref->{nutriscore_unknown_reason_short}
						= lang("nutriscore_missing_category_and_nutrition_data_short");
				}
			}
		}
	}

	if (@nutriscore_warnings > 0) {
		$result_data_ref->{nutriscore_warnings} = \@nutriscore_warnings;
	}

	# Display the details of the computation of the Nutri-Score if we computed one
	if ((defined $product_ref->{nutriscore_grade}) and ($product_ref->{nutriscore_grade} =~ /^[a-e]$/)) {
		$result_data_ref->{nutriscore_details} = display_nutriscore_calculation_details($nutriscore_data_ref, $version);
	}

	return $result_data_ref;
}

sub add_product_nutriment_to_stats ($nutriments_ref, $nid, $value) {

	if ((defined $value) and ($value ne '')) {

		if (not defined $nutriments_ref->{"${nid}_n"}) {
			$nutriments_ref->{"${nid}_n"} = 0;
			$nutriments_ref->{"${nid}_s"} = 0;
			$nutriments_ref->{"${nid}_array"} = [];
		}

		$nutriments_ref->{"${nid}_n"}++;
		$nutriments_ref->{"${nid}_s"} += $value + 0.0;
		push @{$nutriments_ref->{"${nid}_array"}}, $value + 0.0;

	}
	return 1;
}


=head2 display_possible_improvement_description( PRODUCT_REF, TAGID )

Display an explanation of the possible improvement, using the improvement
data stored in $product_ref->{improvements_data}

=cut

sub display_possible_improvement_description ($product_ref, $tagid) {

	my $html = "";

	if ((defined $product_ref->{improvements_data}) and (defined $product_ref->{improvements_data}{$tagid})) {

		my $template_data_ref_improvement = {};

		$template_data_ref_improvement->{tagid} = $tagid;

		# Comparison of product nutrition facts to other products of the same category

		if ($tagid =~ /^en:nutrition-(very-)?high/) {
			$template_data_ref_improvement->{product_ref_improvements_data} = $product_ref->{improvements_data};
			$template_data_ref_improvement->{product_ref_improvements_data_tagid}
				= $product_ref->{improvements_data}{$tagid};
			$template_data_ref_improvement->{product_ref_improvements_data_tagid_product_100g}
				= $product_ref->{improvements_data}{$tagid}{product_100g};
			$template_data_ref_improvement->{product_ref_improvements_data_tagid_category_100g}
				= $product_ref->{improvements_data}{$tagid}{category_100g};
			$template_data_ref_improvement->{display_taxonomy_tag_improvements_data_category} = sprintf(
				lang("value_for_the_category"),
				display_taxonomy_tag($lc, "categories", $product_ref->{improvements_data}{$tagid}{category})
			);
		}

		# Opportunities to improve the Nutri-Score by slightly changing the nutrients

		if ($tagid =~ /^en:better-nutri-score/) {
			# msgid "The Nutri-Score can be changed from %s to %s by changing the %s value from %s to %s (%s percent difference)."
			$template_data_ref_improvement->{nutriscore_sprintf_data} = sprintf(
				lang("better_nutriscore"),
				uc($product_ref->{improvements_data}{$tagid}{current_nutriscore_grade}),
				uc($product_ref->{improvements_data}{$tagid}{new_nutriscore_grade}),
				lc(lang("nutriscore_points_for_" . $product_ref->{improvements_data}{$tagid}{nutrient})),
				$product_ref->{improvements_data}{$tagid}{current_value},
				$product_ref->{improvements_data}{$tagid}{new_value},
				sprintf("%d", $product_ref->{improvements_data}{$tagid}{difference_percent})
			);
		}

		process_template('web/common/includes/display_possible_improvement_description.tt.html',
			$template_data_ref_improvement, \$html)
			|| return "template error: " . $tt->error();

	}

	return $html;
}


sub compute_stats_for_products ($stats_ref, $nutriments_ref, $count, $n, $min_products, $id) {

	#my $stats_ref        ->    where we will store the stats
	#my $nutriments_ref   ->    values for some nutriments
	#my $count            ->    total number of products (including products that have no values for the nutriments we are interested in)
	#my $n                ->    number of products with defined values for specified nutriments
	#my $min_products     ->    min number of products needed to compute stats
	#my $id               ->    id (e.g. category id)

	$stats_ref->{stats} = 1;
	$stats_ref->{nutriments} = {};
	$stats_ref->{id} = $id;
	$stats_ref->{count} = $count;
	$stats_ref->{n} = $n;

	foreach my $nid (keys %{$nutriments_ref}) {
		next if $nid !~ /_n$/;
		$nid = $`;

		next if ($nutriments_ref->{"${nid}_n"} < $min_products);

		# Compute the mean and standard deviation, without the bottom and top 5% (so that huge outliers
		# that are likely to be errors in the data do not completely overweight the mean and std)

		my @values = sort {$a <=> $b} @{$nutriments_ref->{"${nid}_array"}};
		my $nb_values = $#values + 1;
		my $kept_values = 0;
		my $sum_of_kept_values = 0;

		my $i = 0;
		foreach my $value (@values) {
			$i++;
			next if ($i <= $nb_values * 0.05);
			next if ($i >= $nb_values * 0.95);
			$kept_values++;
			$sum_of_kept_values += $value;
		}

		my $mean_for_kept_values = $sum_of_kept_values / $kept_values;

		$nutriments_ref->{"${nid}_mean"} = $mean_for_kept_values;

		my $sum_of_square_differences_for_kept_values = 0;
		$i = 0;
		foreach my $value (@values) {
			$i++;
			next if ($i <= $nb_values * 0.05);
			next if ($i >= $nb_values * 0.95);
			$sum_of_square_differences_for_kept_values
				+= ($value - $mean_for_kept_values) * ($value - $mean_for_kept_values);
		}
		my $std_for_kept_values = sqrt($sum_of_square_differences_for_kept_values / $kept_values);

		$nutriments_ref->{"${nid}_std"} = $std_for_kept_values;

		$stats_ref->{nutriments}{"${nid}_n"} = $nutriments_ref->{"${nid}_n"};
		$stats_ref->{nutriments}{"$nid"} = $nutriments_ref->{"${nid}_mean"};
		$stats_ref->{nutriments}{"${nid}_100g"} = sprintf("%.2e", $nutriments_ref->{"${nid}_mean"}) + 0.0;
		$stats_ref->{nutriments}{"${nid}_std"} = sprintf("%.2e", $nutriments_ref->{"${nid}_std"}) + 0.0;

		if ($nid =~ /^energy/) {
			$stats_ref->{nutriments}{"${nid}_100g"} = int($stats_ref->{nutriments}{"${nid}_100g"} + 0.5);
			$stats_ref->{nutriments}{"${nid}_std"} = int($stats_ref->{nutriments}{"${nid}_std"} + 0.5);
		}

		$stats_ref->{nutriments}{"${nid}_min"} = sprintf("%.2e", $values[0]) + 0.0;
		$stats_ref->{nutriments}{"${nid}_max"} = sprintf("%.2e", $values[$nutriments_ref->{"${nid}_n"} - 1]) + 0.0;
		#$stats_ref->{nutriments}{"${nid}_5"} = $nutriments_ref->{"${nid}_array"}[int ( ($nutriments_ref->{"${nid}_n"} - 1) * 0.05) ];
		#$stats_ref->{nutriments}{"${nid}_95"} = $nutriments_ref->{"${nid}_array"}[int ( ($nutriments_ref->{"${nid}_n"}) * 0.95) ];
		$stats_ref->{nutriments}{"${nid}_10"}
			= sprintf("%.2e", $values[int(($nutriments_ref->{"${nid}_n"} - 1) * 0.10)]) + 0.0;
		$stats_ref->{nutriments}{"${nid}_90"}
			= sprintf("%.2e", $values[int(($nutriments_ref->{"${nid}_n"}) * 0.90)]) + 0.0;
		$stats_ref->{nutriments}{"${nid}_50"}
			= sprintf("%.2e", $values[int(($nutriments_ref->{"${nid}_n"}) * 0.50)]) + 0.0;

		#print STDERR "-> lc: lc -category $tagid - count: $count - n: nutriments: " . $nn . "$n \n";
		#print "categories stats - cc: $cc - n: $n- values for category $id: " . join(", ", @values) . "\n";
		#print "tagid: $id - nid: $nid - 100g: " .  $stats_ref->{nutriments}{"${nid}_100g"}  . " min: " . $stats_ref->{nutriments}{"${nid}_min"} . " - max: " . $stats_ref->{nutriments}{"${nid}_max"} .
		#	"mean: " . $stats_ref->{nutriments}{"${nid}_mean"} . " - median: " . $stats_ref->{nutriments}{"${nid}_50"} . "\n";

	}

	return;
}

=head2 compare_product_nutrition_facts_to_categories ($product_ref, $target_cc, $max_number_of_categories)

Compares a product nutrition facts to average nutrition facts of each of its categories.

=head3 Arguments

=head4 Product reference $product_ref

=head4 Target country code $target_cc

=head4 Max number of categories $max_number_of_categories

If defined, we will limit the number of categories returned, and keep the most specific categories.

=head3 Return values

Reference to a comparisons data structure that can be passed to the data_to_display_nutrition_table() function.

=cut

sub compare_product_nutrition_facts_to_categories ($product_ref, $target_cc, $max_number_of_categories) {

	my @comparisons = ();

	if (
		(
			not(    (defined $product_ref->{not_comparable_nutrition_data})
				and ($product_ref->{not_comparable_nutrition_data}))
		)
		and (defined $product_ref->{categories_tags})
		and (scalar @{$product_ref->{categories_tags}} > 0)
		)
	{

		my $categories_nutriments_ref = $categories_nutriments_per_country{$target_cc};

		if (defined $categories_nutriments_ref) {

			foreach my $cid (@{$product_ref->{categories_tags}}) {

				if (    (defined $categories_nutriments_ref->{$cid})
					and (defined $categories_nutriments_ref->{$cid}{stats}))
				{

					push @comparisons,
						{
						id => $cid,
						name => display_taxonomy_tag($lc, 'categories', $cid),
						link => canonicalize_taxonomy_tag_link($lc, 'categories', $cid),
						nutriments => compare_nutriments($product_ref, $categories_nutriments_ref->{$cid}),
						count => $categories_nutriments_ref->{$cid}{count},
						n => $categories_nutriments_ref->{$cid}{n},
						};
				}
			}

			if ($#comparisons > -1) {
				@comparisons = sort {$a->{count} <=> $b->{count}} @comparisons;
				$comparisons[0]{show} = 1;
			}

			# Limit the number of categories returned
			if (defined $max_number_of_categories) {
				while (@comparisons > $max_number_of_categories) {
					pop @comparisons;
				}
			}
		}
	}

	return \@comparisons;
}

=head2 data_to_display_nutrition_table ( $product_ref, $comparisons_ref )

Generates a data structure to display a nutrition table.

The nutrition table can be the nutrition table of a product, or of a category (stats for the categories).

In the case of a product, extra columns can be added to compare the product nutrition facts to the average for its categories.

The resulting data structure can be passed to a template to generate HTML or the JSON data for a knowledge panel.

=head3 Arguments

=head4 Product reference $product_ref

=head4 Comparisons reference $product_ref

Reference to an array with nutrition facts for 1 or more categories.

=head3 Return values

Reference to a data structure with needed data to display.

=cut

sub data_to_display_nutrition_table ($product_ref, $comparisons_ref) {

	# This function populates a data structure that is used by the template to display the nutrition facts table
	my $template_data_ref = {

		nutrition_table => {
			id => "nutrition",
			header => {
				name => lang('nutrition_data_table'),
				columns => [],
			},
			rows => [],
		},
	};

	# List of columns
	my @cols = ();

	# Data for each column
	my %columns = ();

	# We can have data for the product as sold, and/or prepared
	my @displayed_product_types = ();
	my %displayed_product_types = ();

	if ((not defined $product_ref->{nutrition_data}) or ($product_ref->{nutrition_data})) {
		# by default, old products did not have a checkbox, display the nutrition data entry column for the product as sold
		push @displayed_product_types, "";
		$displayed_product_types{as_sold} = 1;
	}
	if ((defined $product_ref->{nutrition_data_prepared}) and ($product_ref->{nutrition_data_prepared} eq 'on')) {
		push @displayed_product_types, "prepared_";
		$displayed_product_types{prepared} = 1;
	}

	foreach my $product_type (@displayed_product_types) {

		my $nutrition_data_per = "nutrition_data" . "_" . $product_type . "per";

		my $col_name = lang("product_as_sold");
		if ($product_type eq 'prepared_') {
			$col_name = lang("prepared_product");
		}

		$columns{$product_type . "100g"} = {
			scope => "product",
			product_type => $product_type,
			per => "100g",
			name => $col_name . "<br>" . lang("nutrition_data_per_100g"),
			short_name => "100g",
		};
		$columns{$product_type . "serving"} = {
			scope => "product",
			product_type => $product_type,
			per => "serving",
			name => $col_name . "<br>" . lang("nutrition_data_per_serving"),
			short_name => lang("nutrition_data_per_serving"),
		};

		if ((defined $product_ref->{serving_size}) and ($product_ref->{serving_size} ne '')) {
			$columns{$product_type . "serving"}{name} .= ' (' . $product_ref->{serving_size} . ')';
		}

		if (not defined $product_ref->{$nutrition_data_per}) {
			$product_ref->{$nutrition_data_per} = '100g';
		}

		if ($product_ref->{$nutrition_data_per} eq 'serving') {

			if ((defined $product_ref->{serving_quantity}) and ($product_ref->{serving_quantity} > 0)) {
				if (($product_type eq "") and ($displayed_product_types{prepared})) {
					# do not display non prepared by portion if we have data for the prepared product
					# -> the portion size is for the prepared product
					push @cols, $product_type . '100g';
				}
				else {
					push @cols, ($product_type . '100g', $product_type . 'serving');
				}
			}
			else {
				push @cols, $product_type . 'serving';
			}
		}
		else {
			if ((defined $product_ref->{serving_quantity}) and ($product_ref->{serving_quantity} > 0)) {
				if (($product_type eq "") and ($displayed_product_types{prepared})) {
					# do not display non prepared by portion if we have data for the prepared product
					# -> the portion size is for the prepared product
					push @cols, $product_type . '100g';
				}
				else {
					push @cols, ($product_type . '100g', $product_type . 'serving');
				}
			}
			else {
				push @cols, $product_type . '100g';
			}
		}
	}

	# Comparisons with other products, categories, recommended daily values etc.

	if ((defined $comparisons_ref) and (scalar @{$comparisons_ref} > 0)) {

		# Add a comparisons array to the template data structure

		$template_data_ref->{comparisons} = [];

		my $i = 0;

		foreach my $comparison_ref (@{$comparisons_ref}) {

			my $col_id = "compare_" . $i;

			push @cols, $col_id;

			$columns{$col_id} = {
				"scope" => "comparisons",
				"name" => lang("compared_to") . lang("sep") . ": " . $comparison_ref->{name},
				"class" => $col_id,
			};

			$log->debug("displaying nutrition table comparison column",
				{colid => $col_id, id => $comparison_ref->{id}, name => $comparison_ref->{name}})
				if $log->is_debug();

			my $checked = 0;
			if (defined $comparison_ref->{show}) {
				$checked = 1;
			}
			else {
				$styles .= <<CSS
.$col_id { display:none }
CSS
					;
			}

			my $checked_html = "";
			if ($checked) {
				$checked_html = ' checked="checked"';
			}

			push @{$template_data_ref->{comparisons}},
				{
				col_id => $col_id,
				checked => $checked,
				name => $comparison_ref->{name},
				link => $comparison_ref->{link},
				count => $comparison_ref->{count},
				};

			$i++;
		}
	}

	# Stats for categories

	if (defined $product_ref->{stats}) {

		foreach my $col_id ('std', 'min', '10', '50', '90', 'max') {
			push @cols, $col_id;
			$columns{$col_id} = {
				"scope" => "categories",
				"name" => lang("nutrition_data_per_" . $col_id),
				"class" => "stats",
			};
		}

		if ($product_ref->{id} ne 'search') {

			# Show checkbox to display/hide stats for the category

			$template_data_ref->{category_stats} = 1;
		}
	}

	# Data for the nutrition table header

	foreach my $col_id (@cols) {

		$columns{$col_id}{col_id} = $col_id;
		push(@{$template_data_ref->{nutrition_table}{header}{columns}}, $columns{$col_id});

	}

	# Data for the nutrition table body

	defined $product_ref->{nutriments} or $product_ref->{nutriments} = {};

	my @unknown_nutriments = ();
	my %seen_unknown_nutriments = ();
	foreach my $nid (keys %{$product_ref->{nutriments}}) {

		next if (($nid =~ /_/) and ($nid !~ /_prepared$/));

		$nid =~ s/_prepared$//;

		if (    (not exists_taxonomy_tag("nutrients", "zz:$nid"))
			and (defined $product_ref->{nutriments}{$nid . "_label"})
			and (not defined $seen_unknown_nutriments{$nid}))
		{
			push @unknown_nutriments, $nid;
			$seen_unknown_nutriments{$nid} = 1;
		}
	}

	# Display estimate of fruits, vegetables, nuts from the analysis of the ingredients list
	my @nutriments = ();
	foreach my $nutriment (@{$nutriments_tables{$nutriment_table}}, @unknown_nutriments) {
		push @nutriments, $nutriment;
		if (($nutriment eq "fruits-vegetables-nuts-estimate-")) {
			push @nutriments, "fruits-vegetables-nuts-estimate-from-ingredients-";
		}
	}

	my $decf = get_decimal_formatter($lc);
	my $perf = get_percent_formatter($lc, 0);

	foreach my $nutriment (@nutriments) {

		next if $nutriment =~ /^\#/;
		my $nid = $nutriment;
		$nid =~ s/^(-|!)+//g;
		$nid =~ s/-$//g;

		next if $nid eq 'sodium';

		# Skip "energy-kcal" and "energy-kj" as we will display "energy" which has both
		next if (($nid eq "energy-kcal") or ($nid eq "energy-kj"));

		# Determine if the nutrient should be shown
		my $shown = 0;

		# Check if we have a value for the nutrient
		my $is_nutrient_with_value = (
			((defined $product_ref->{nutriments}{$nid}) and ($product_ref->{nutriments}{$nid} ne ''))
				or ((defined $product_ref->{nutriments}{$nid . "_100g"})
				and ($product_ref->{nutriments}{$nid . "_100g"} ne ''))
				or ((defined $product_ref->{nutriments}{$nid . "_prepared"})
				and ($product_ref->{nutriments}{$nid . "_prepared"} ne ''))
				or ((defined $product_ref->{nutriments}{$nid . "_modifier"})
				and ($product_ref->{nutriments}{$nid . "_modifier"} eq '-'))
				or ((defined $product_ref->{nutriments}{$nid . "_prepared_modifier"})
				and ($product_ref->{nutriments}{$nid . "_prepared_modifier"} eq '-'))
		);

		# Show rows that are not optional (id with a trailing -), or for which we have a value
		if (($nutriment !~ /-$/) or $is_nutrient_with_value) {
			$shown = 1;
		}

		# Hide rows that are not important when we don't have a value
		if ((($nutriment !~ /^!/) or ($product_ref->{id} eq 'search'))
			and not($is_nutrient_with_value))
		{
			$shown = 0;
		}

		# Show the UK nutrition score only if the country is matching
		# Always show the FR nutrition score (Nutri-Score)

		if ($nid =~ /^nutrition-score-(.*)$/) {
			# Always show the FR score and Nutri-Score
			if (($cc ne $1) and (not($1 eq 'fr'))) {
				$shown = 0;
			}

			# 2021-12: now not displaying the Nutrition scores and Nutri-Score in nutrition facts table (experimental)
			$shown = 0;
		}

		if ($shown) {

			# Level of the nutrient: 0 for main nutrients, 1 for sub-nutrients, 2 for sub-sub-nutrients
			my $level = 0;

			if ($nutriment =~ /^!?-/) {
				$level = 1;
				if ($nutriment =~ /^!?--/) {
					$level = 2;
				}
			}

			# Name of the nutrient

			my $name;
			my $unit = "g";

			if (exists_taxonomy_tag("nutrients", "zz:$nid")) {
				$name = display_taxonomy_tag($lc, "nutrients", "zz:$nid");
				$unit = get_property("nutrients", "zz:$nid", "unit:en") // 'g';
			}
			else {
				if (defined $product_ref->{nutriments}{$nid . "_label"}) {
					$name = $product_ref->{nutriments}{$nid . "_label"};
				}
				if (defined $product_ref->{nutriments}{$nid . "_unit"}) {
					$unit = $product_ref->{nutriments}{$nid . "_unit"};
				}
			}
			my @columns;
			my @extra_row_columns;

			my $extra_row = 0;    # Some rows will trigger an extra row (e.g. Salt adds Sodium)

			foreach my $col_id (@cols) {

				my $values;    # Value for row
				my $values2;    # Value for extra row (e.g. after the row for salt, we add an extra row for sodium)
				my $col_class = $columns{$col_id}{class};
				my $percent;
				my $percent_numeric_value;

				my $rdfa = '';    # RDFA property for row
				my $rdfa2 = '';    # RDFA property for extra row

				my $col_type;

				if ($col_id =~ /compare_(.*)/) {    #comparisons

					$col_type = "comparison";

					my $comparison_ref = $comparisons_ref->[$1];

					my $value = "";
					if (defined $comparison_ref->{nutriments}{$nid . "_100g"}) {
						# energy-kcal is already in kcal
						if ($nid eq 'energy-kcal') {
							$value = $comparison_ref->{nutriments}{$nid . "_100g"};
						}
						else {
							$value = $decf->format(g_to_unit($comparison_ref->{nutriments}{$nid . "_100g"}, $unit));
						}
					}
					# too small values are converted to e notation: 7.18e-05
					if (($value . ' ') =~ /e/) {
						# use %f (outputs extras 0 in the general case)
						$value = sprintf("%f", g_to_unit($comparison_ref->{nutriments}{$nid . "_100g"}, $unit));
					}

					# 0.045 g	0.0449 g

					$values = "$value $unit";
					if (   (not defined $comparison_ref->{nutriments}{$nid . "_100g"})
						or ($comparison_ref->{nutriments}{$nid . "_100g"} eq ''))
					{
						$values = '?';
					}
					elsif (($nid eq "energy") or ($nid eq "energy-from-fat")) {
						# Use the actual value in kcal if we have it
						my $value_in_kcal;
						if (defined $comparison_ref->{nutriments}{$nid . "-kcal" . "_100g"}) {
							$value_in_kcal = $comparison_ref->{nutriments}{$nid . "-kcal" . "_100g"};
						}
						# Otherwise convert the value in kj
						else {
							$value_in_kcal = g_to_unit($comparison_ref->{nutriments}{$nid . "_100g"}, 'kcal');
						}
						$values .= "<br>(" . sprintf("%d", $value_in_kcal) . ' kcal)';
					}

					$percent = $comparison_ref->{nutriments}{"${nid}_100g_%"};
					if ((defined $percent) and ($percent ne '')) {

						$percent_numeric_value = $percent;
						$percent = $perf->format($percent / 100.0);
						# issue 2273 -  minus signs are rendered with different characters in different locales, e.g. Finnish
						# so just test positivity of numeric value
						if ($percent_numeric_value > 0) {
							$percent = "+" . $percent;
						}
						# If percent is close to 0, just put "-"
						if (sprintf("%.0f", $percent_numeric_value) eq "0") {
							$percent = "-";
						}
					}
					else {
						$percent = undef;
					}

					if ($nid eq 'sodium') {
						if (   (not defined $comparison_ref->{nutriments}{$nid . "_100g"})
							or ($comparison_ref->{nutriments}{$nid . "_100g"} eq ''))
						{
							$values2 = '?';
						}
						else {
							$values2
								= ($decf->format(g_to_unit($comparison_ref->{nutriments}{$nid . "_100g"} * 2.5, $unit)))
								. " "
								. $unit;
						}
					}
					elsif ($nid eq 'salt') {
						if (   (not defined $comparison_ref->{nutriments}{$nid . "_100g"})
							or ($comparison_ref->{nutriments}{$nid . "_100g"} eq ''))
						{
							$values2 = '?';
						}
						else {
							$values2
								= ($decf->format(g_to_unit($comparison_ref->{nutriments}{$nid . "_100g"} / 2.5, $unit)))
								. " "
								. $unit;
						}
					}
					elsif ($nid eq 'nutrition-score-fr') {
						# We need to know the category in order to select the right thresholds for the nutrition grades
						# as it depends on whether it is food or drink

						# if it is a category stats, the category id is the id field
						if (    (not defined $product_ref->{categories_tags})
							and (defined $product_ref->{id})
							and ($product_ref->{id} =~ /^en:/))
						{
							$product_ref->{categories} = $product_ref->{id};
							compute_field_tags($product_ref, "en", "categories");
						}

						if (defined $product_ref->{categories_tags}) {

							my $nutriscore_grade = compute_nutriscore_grade(
								$product_ref->{nutriments}{$nid . "_100g"},
								is_beverage_for_nutrition_score($product_ref),
								is_water_for_nutrition_score($product_ref)
							);

							$values2 = uc($nutriscore_grade);
						}
					}
				}
				else {
					$col_type = "normal";
					my $value_unit = "";

					# Nutriscore: per serving = per 100g
					if (($nid =~ /(nutrition-score(-\w\w)?)/)) {
						# same Nutri-Score for 100g / serving and prepared / as sold
						$product_ref->{nutriments}{$nid . "_" . $col_id} = $product_ref->{nutriments}{$1 . "_100g"};
					}

					# We need to know if the column corresponds to a prepared value, in order to be able to retrieve the right modifier
					my $prepared = '';
					if ($col_id =~ /prepared/) {
						$prepared = "_prepared";
					}

					if (   (not defined $product_ref->{nutriments}{$nid . "_" . $col_id})
						or ($product_ref->{nutriments}{$nid . "_" . $col_id} eq ''))
					{
						if (    (defined $product_ref->{nutriments}{$nid . $prepared . "_modifier"})
							and ($product_ref->{nutriments}{$nid . $prepared . "_modifier"} eq '-'))
						{
							# The nutrient is not indicated on the package, display a minus sign
							$value_unit = '-';
						}
						else {
							$value_unit = '?';
						}
					}
					else {

						# this is the actual value on the package, not a computed average. do not try to round to 2 decimals.
						my $value;

						# energy-kcal is already in kcal
						if ($nid eq 'energy-kcal') {
							$value = $product_ref->{nutriments}{$nid . "_" . $col_id};
						}
						else {
							$value = $decf->format(g_to_unit($product_ref->{nutriments}{$nid . "_" . $col_id}, $unit));
						}

						# too small values are converted to e notation: 7.18e-05
						if (($value . ' ') =~ /e/) {
							# use %f (outputs extras 0 in the general case)
							$value = sprintf("%f", g_to_unit($product_ref->{nutriments}{$nid . "_" . $col_id}, $unit));
						}

						$value_unit = "$value $unit";

						if (defined $product_ref->{nutriments}{$nid . $prepared . "_modifier"}) {
							$value_unit
								= $product_ref->{nutriments}{$nid . $prepared . "_modifier"} . " " . $value_unit;
						}

						if (($nid eq "energy") or ($nid eq "energy-from-fat")) {
							# Use the actual value in kcal if we have it
							my $value_in_kcal;
							if (defined $product_ref->{nutriments}{$nid . "-kcal" . "_" . $col_id}) {
								$value_in_kcal = $product_ref->{nutriments}{$nid . "-kcal" . "_" . $col_id};
							}
							# Otherwise convert the value in kj
							else {
								$value_in_kcal = g_to_unit($product_ref->{nutriments}{$nid . "_" . $col_id}, 'kcal');
							}
							$value_unit .= "<br>(" . sprintf("%d", $value_in_kcal) . ' kcal)';
						}
					}

					if ($nid eq 'sodium') {
						my $salt;
						if (defined $product_ref->{nutriments}{$nid . "_" . $col_id}) {
							$salt = $product_ref->{nutriments}{$nid . "_" . $col_id} * 2.5;
						}
						if (exists $product_ref->{nutriments}{"salt" . "_" . $col_id}) {
							$salt = $product_ref->{nutriments}{"salt" . "_" . $col_id};
						}
						if (defined $salt) {
							$salt = $decf->format(g_to_unit($salt, $unit));
							if ($col_id eq '100g') {
								$rdfa2 = "property=\"food:saltEquivalentPer100g\" content=\"$salt\"";
							}
							$salt .= " " . $unit;
						}
						else {
							$salt = "?";
						}
						$values2 = $salt;
					}
					elsif ($nid eq 'salt') {
						my $sodium;
						if (defined $product_ref->{nutriments}{$nid . "_" . $col_id}) {
							$sodium = $product_ref->{nutriments}{$nid . "_" . $col_id} / 2.5;
						}
						if (exists $product_ref->{nutriments}{"sodium" . "_" . $col_id}) {
							$sodium = $product_ref->{nutriments}{"sodium" . "_" . $col_id};
						}
						if (defined $sodium) {
							$sodium = $decf->format(g_to_unit($sodium, $unit));
							if ($col_id eq '100g') {
								$rdfa2 = "property=\"food:sodiumEquivalentPer100g\" content=\"$sodium\"";
							}
							$sodium .= " " . $unit;
						}
						else {
							$sodium = "?";
						}
						$values2 = $sodium;
					}
					elsif ($nid eq 'nutrition-score-fr') {
						# We need to know the category in order to select the right thresholds for the nutrition grades
						# as it depends on whether it is food or drink

						# if it is a category stats, the category id is the id field
						if (    (not defined $product_ref->{categories_tags})
							and (defined $product_ref->{id})
							and ($product_ref->{id} =~ /^en:/))
						{
							$product_ref->{categories} = $product_ref->{id};
							compute_field_tags($product_ref, "en", "categories");
						}

						if (defined $product_ref->{categories_tags}) {

							if ($col_id ne "std") {

								my $nutriscore_grade = compute_nutriscore_grade(
									$product_ref->{nutriments}{$nid . "_" . $col_id},
									is_beverage_for_nutrition_score($product_ref),
									is_water_for_nutrition_score($product_ref)
								);

								$values2 = uc($nutriscore_grade);
							}
						}
					}
					elsif ($col_id eq $product_ref->{nutrition_data_per}) {
						# % DV ?
						if (    (defined $product_ref->{nutriments}{$nid . "_value"})
							and (defined $product_ref->{nutriments}{$nid . "_unit"})
							and ($product_ref->{nutriments}{$nid . "_unit"} eq '% DV'))
						{
							$value_unit
								.= ' ('
								. $product_ref->{nutriments}{$nid . "_value"} . ' '
								. $product_ref->{nutriments}{$nid . "_unit"} . ')';
						}
					}

					if (($col_id eq '100g') and (defined $product_ref->{nutriments}{$nid . "_" . $col_id})) {
						my $property = $nid;
						$property =~ s/-([a-z])/ucfirst($1)/eg;
						$property .= "Per100g";
						$rdfa = " property=\"food:$property\" content=\""
							. $product_ref->{nutriments}{$nid . "_" . $col_id} . "\"";
					}

					$values = $value_unit;
				}

				my $cell_data_ref = {
					value => $values,
					rdfa => $rdfa,
					class => $col_class,
					percent => $percent,
					type => $col_type,
				};

				# Add evaluation
				if (defined $percent_numeric_value) {

					my $nutrient_evaluation = get_property("nutrients", "zz:$nid", "evaluation:en")
						;    # Whether the nutrient is considered good or not

					# Determine if the value of this nutrient compared to other products is good or not

					if (defined $nutrient_evaluation) {

						if (   (($nutrient_evaluation eq "good") and ($percent_numeric_value >= 10))
							or (($nutrient_evaluation eq "bad") and ($percent_numeric_value <= -10)))
						{
							$cell_data_ref->{evaluation} = "good";
						}
						elsif ((($nutrient_evaluation eq "bad") and ($percent_numeric_value >= 10))
							or (($nutrient_evaluation eq "good") and ($percent_numeric_value <= -10)))
						{
							$cell_data_ref->{evaluation} = "bad";
						}
					}
				}

				push(@columns, $cell_data_ref);

				push(
					@extra_row_columns,
					{
						value => $values2,
						rdfa => $rdfa2,
						class => $col_class,
						percent => $percent,
						type => $col_type,
					}
				);

				if (defined $values2) {
					$extra_row = 1;
				}
			}

			# Add the row data to the template
			push @{$template_data_ref->{nutrition_table}{rows}},
				{
				nid => $nid,
				level => $level,
				name => $name,
				columns => \@columns,
				};

			# Add an extra row for specific nutrients
			# 2021-12: There may not be a lot of value to display an extra sodium or salt row,
			# tentatively disabling it. Keeping code in place in case we want to re-enable it under some conditions.
			if (0 and (defined $extra_row)) {
				if ($nid eq 'sodium') {

					push @{$template_data_ref->{nutrition_table}{rows}},
						{
						name => lang("salt_equivalent"),
						nid => "salt_equivalent",
						level => 1,
						columns => \@extra_row_columns,
						};
				}
				elsif ($nid eq 'salt') {

					push @{$template_data_ref->{nutrition_table}{rows}},
						{
						name => display_taxonomy_tag($lc, "nutrients", "zz:sodium"),
						nid => "sodium",
						level => 1,
						columns => \@extra_row_columns,
						};
				}
				elsif ($nid eq 'nutrition-score-fr') {

					push @{$template_data_ref->{nutrition_table}{rows}},
						{
						name => "Nutri-Score",
						nid => "nutriscore",
						level => 1,
						columns => \@extra_row_columns,
						};
				}
			}
		}
	}

	return $template_data_ref;
}

=head2 display_nutrition_table ( $product_ref, $comparisons_ref )

Generates HTML to display a nutrition table.

Use  data produced by data_to_display_nutrition_table

=head3 Arguments

=head4 Product reference $product_ref

=head4 Comparisons reference $product_ref

Reference to an array with nutrition facts for 1 or more categories.

=head3 Return values

HTML for the nutrition table.

=cut

sub display_nutrition_table ($product_ref, $comparisons_ref) {

	my $html = '';

	my $template_data_ref = data_to_display_nutrition_table($product_ref, $comparisons_ref);

	process_template('web/pages/product/includes/nutrition_facts_table.tt.html', $template_data_ref, \$html)
		|| return "template error: " . $tt->error();

	return $html;
}




1;

