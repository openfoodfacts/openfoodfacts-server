# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2026 Association Open Food Facts
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

=encoding UTF-8

=head1 NAME

ProductOpener::Food - functions related to food products and nutrition

=head1 DESCRIPTION

C<ProductOpener::Food> contains functions specific to food products, in particular
related to nutrition facts. This module provides functions It does not contain functions related to ingredients which
are in the C<ProductOpener::Ingredients> module.

..

=cut

package ProductOpener::Food;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		%nutriments_labels

		%cc_nutrient_table
		%nutrients_tables
		%valid_nutrients

		%other_nutrients_lists
		%nutrients_lists

		@nutrient_levels

		&normalize_nutriment_value_and_modifier
		&assign_nid_modifier_value_and_unit

		&is_beverage_for_nutrition_score_2021
		&is_fat_oil_nuts_seeds_for_nutrition_score
		&is_water_for_nutrition_score

		&has_category_that_should_have_prepared_nutrition_data
		&check_availability_of_nutrients_needed_for_nutriscore
		&compute_nutriscore_data
		&compute_nutriscore
		&compute_nova_group
		&compute_nutrient_levels
		&evaluate_nutrient_level
		&compute_units_of_alcohol

		&compare_nutrients

		&extract_nutrition_from_image

		&default_unit_for_nid

		&create_nutrients_level_taxonomy

		&assign_categories_properties_to_product

		&check_nutriscore_categories_exist_in_taxonomy

		&get_nutrient_unit

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Store qw/get_string_id_for_lang retrieve/;
use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Lang qw/$lc %Lang %Langs lang/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Images qw/extract_text_from_image/;
use ProductOpener::Nutriscore qw/compute_nutriscore_score_and_grade/;
use ProductOpener::Numbers qw/:all/;
use ProductOpener::Ingredients
	qw/estimate_nutriscore_2021_milk_percent_from_ingredients estimate_nutriscore_2023_red_meat_percent_from_ingredients/;
use ProductOpener::Text qw/remove_tags_and_quote/;
use ProductOpener::FoodGroups qw/compute_food_groups/;
use ProductOpener::Units qw/:all/;
use ProductOpener::Products qw(&remove_fields);
use ProductOpener::HTTP qw/single_param/;
use ProductOpener::APIProductWrite qw/skip_protected_field/;
use ProductOpener::NutritionEstimation qw/estimate_nutrients_from_ingredients/;
use ProductOpener::Nutrition qw/:all/;

use Hash::Util;
use Encode;
use URI::Escape::XS;

use CGI qw/:cgi :form escapeHTML/;

use Data::DeepAccess qw(deep_set deep_get deep_exists);
use Storable qw/dclone/;

use Log::Any qw($log);

sub check_nutriscore_categories_exist_in_taxonomy() {

	# Normalize values listed in Config.pm

	# Canonicalize the list of categories used to compute Nutri-Score, so that Nutri-Score
	# computation does not change if we change the canonical English name of a category

	foreach my $categories_list_id (
		qw(
		categories_not_considered_as_beverages_for_nutriscore_2021
		categories_not_considered_as_beverages_for_nutriscore_2023
		categories_exempted_from_nutriscore
		categories_not_exempted_from_nutriscore
		categories_exempted_from_nutrient_levels
		)
		)
	{
		my $categories_list_ref = $options{$categories_list_id};
		if (defined $categories_list_ref) {
			foreach my $category_id (@{$categories_list_ref}) {
				$category_id = canonicalize_taxonomy_tag("en", "categories", $category_id);
				# Check that the entry exists
				if (not exists_taxonomy_tag("categories", $category_id)) {
					$log->error(
						"Category used in Nutri-Score and listed in Config.pm \$options\{$categories_list_id\} does not exist in the categories taxonomy.",
						{category_id => $category_id}
					) if $log->is_error();
					die(
						"Category used in Nutri-Score and listed in Config.pm \$options\{$categories_list_id\} does not exist in the categories taxonomy."
					);
				}
			}
		}
	}

	return;
}

=head2 default_unit_for_nid ( $nid)

Return the default unit that we convert everything to internally

=head3 Parameters

$nid: String

=head3 Return values

Default value for that certain unit

=cut

sub default_unit_for_nid ($nid) {

	$nid =~ s/_prepared//;

	my %default_unit_for_nid_map = (
		"energy-kj" => "kJ",
		"energy-kcal" => "kcal",
		"energy" => "kJ",
		"alcohol" => "% vol",
		"water-hardness" => "mmol/l"
	);

	if (exists($default_unit_for_nid_map{$nid})) {
		return $default_unit_for_nid_map{$nid};
	}
	elsif (($nid =~ /^fruits/) or ($nid =~ /^collagen/)) {
		return "%";
	}
	else {
		return "g";
	}
}

sub assign_nid_modifier_value_and_unit ($product_ref, $nid, $modifier, $value, $unit) {

	## FIXME
	## This is an old function called by code that was written for the old nutrition schema
	## It does nothing for now as we are migrating the code to use the new schema
	## It needs to be removed once the migration is complete

	die;

	return;
}

# For fat, saturated fat, sugars, salt: https://www.diw.de/sixcms/media.php/73/diw_wr_2010-19.pdf
@nutrient_levels = (['fat', 3, 20], ['saturated-fat', 1.5, 5], ['sugars', 5, 12.5], ['salt', 0.3, 1.5],);

#
# -sugars : sub-nutriment
# -- : sub-sub-nutriment
# vitamin-a- : do not show by default in the form
# !proteins : important, always show even if value has not been entered

%cc_nutrient_table = (
	off_default => "off_europe",
	off_ca => "off_ca",
	off_ru => "off_ru",
	off_us => "off_us",
	off_hk => "off_hk",
	off_jp => "off_jp",
	off_in => "off_in",
	opff_default => "opff_europe"
);

=head2 %nutrients_tables

An array that condition how nutrients are displayed.

It is a list of nutrients names with eventual prefixes and suffixes:

=over

=item C<#nutrient> a leading C<#> indicates a comment and will be ignored

=item C<!nutrient> a leading C<!> indicates an important nutrient, they should always be shown

=item The level of each nutrient is indicated by leading dashes before its id:

=over

=item C<nutrient> - no dash for top nutrients

=item C<-sub-nutrient> - for level 2

=item C<--sub-sub-nutrient> - for level 3, etc.

=back

=item C<nutrient-> a C<-> at the end indicates that the nutrient should be hidden and only shown if explicitly added.

=back

=cut

# http://healthycanadians.gc.ca/eating-nutrition/label-etiquetage/tips-conseils/nutrition-fact-valeur-nutritive-eng.php
%nutrients_tables = (
	off_europe => [
		(
			'!energy-kj', '!energy-kcal',
			'!energy-', '-energy-from-fat-',
			'!fat', '!-saturated-fat',
			'--butyric-acid-', '--caproic-acid-',
			'--caprylic-acid-', '--capric-acid-',
			'--lauric-acid-', '--myristic-acid-',
			'--palmitic-acid-', '--stearic-acid-',
			'--arachidic-acid-', '--behenic-acid-',
			'--lignoceric-acid-', '--cerotic-acid-',
			'--montanic-acid-', '--melissic-acid-',
			'-unsaturated-fat-', '--monounsaturated-fat-',
			'---omega-9-fat-', '--polyunsaturated-fat-',
			'---omega-3-fat-', '---omega-6-fat-',
			'--alpha-linolenic-acid-', '--eicosapentaenoic-acid-',
			'--docosahexaenoic-acid-', '--linoleic-acid-',
			'--arachidonic-acid-', '--gamma-linolenic-acid-',
			'--dihomo-gamma-linolenic-acid-', '--oleic-acid-',
			'--elaidic-acid-', '--gondoic-acid-',
			'--mead-acid-', '--erucic-acid-',
			'--nervonic-acid-', '-trans-fat-',
			'-cholesterol-', '!carbohydrates',
			'!-sugars', '--added-sugars-',
			'--sucrose-', '--glucose-',
			'--fructose-', '--galactose-',
			'--lactose-', '--maltose-',
			'--maltodextrins-', '-psicose-',
			'-starch-', '-polyols-',
			'--erythritol-', '--isomalt-',
			'--maltitol-', '--sorbitol-',
			'!fiber', '-soluble-fiber-',
			'--polydextrose-', '-insoluble-fiber-',
			'!proteins', '-casein-',
			'-serum-proteins-', '-nucleotides-',
			'!salt', '-added-salt-',
			'sodium', 'alcohol',
			'#vitamins', 'vitamin-a-',
			'beta-carotene-', 'vitamin-d-',
			'vitamin-e-', 'vitamin-k-',
			'vitamin-c-', 'vitamin-b1-',
			'vitamin-b2-', 'vitamin-pp-',
			'vitamin-b6-', 'vitamin-b9-',
			'folates-', 'vitamin-b12-',
			'biotin-', 'pantothenic-acid-',
			'#minerals', 'silica-',
			'bicarbonate-', 'potassium-',
			'chloride-', 'calcium-',
			'phosphorus-', 'iron-',
			'magnesium-', 'zinc-',
			'copper-', 'manganese-',
			'fluoride-', 'selenium-',
			'chromium-', 'molybdenum-',
			'iodine-', 'caffeine-',
			'taurine-', 'methylsulfonylmethane-',
			'ph-', '!fruits-vegetables-legumes-',
			'collagen-meat-protein-ratio-', 'cocoa-',
			'chlorophyl-', 'carbon-footprint-',
			'glycemic-index-', 'water-hardness-',
			'choline-', 'phylloquinone-',
			'beta-glucan-', 'inositol-',
			'carnitine-', 'sulphate-',
			'nitrate-', 'acidity-',
			'carbohydrates-total-',
		)
	],
	off_ca => [
		(
			'!energy-kcal', 'energy-',
			'!fat', '-saturated-fat',
			'--butyric-acid-', '--caproic-acid-',
			'--caprylic-acid-', '--capric-acid-',
			'--lauric-acid-', '--myristic-acid-',
			'--palmitic-acid-', '--stearic-acid-',
			'--arachidic-acid-', '--behenic-acid-',
			'--lignoceric-acid-', '--cerotic-acid-',
			'--montanic-acid-', '--melissic-acid-',
			'-unsaturated-fat-', '--monounsaturated-fat-',
			'---omega-9-fat-', '--polyunsaturated-fat-',
			'---omega-3-fat-', '---omega-6-fat-',
			'--alpha-linolenic-acid-', '--eicosapentaenoic-acid-',
			'--docosahexaenoic-acid-', '--linoleic-acid-',
			'--arachidonic-acid-', '--gamma-linolenic-acid-',
			'--dihomo-gamma-linolenic-acid-', '--oleic-acid-',
			'--elaidic-acid-', '--gondoic-acid-',
			'--mead-acid-', '--erucic-acid-',
			'--nervonic-acid-', '-trans-fat',
			'cholesterol', '!carbohydrates-total',
			'-fiber', '--soluble-fiber-',
			'---polydextrose-', '--insoluble-fiber-',
			'-sugars', '--added-sugars-',
			'--sucrose-', '--glucose-',
			'--fructose-', '--galactose-',
			'--lactose-', '--maltose-',
			'--maltodextrins-', '-psicose-',
			'-starch-', '-polyols-',
			'--erythritol-', '--isomalt-',
			'--maltitol-', '--sorbitol-',
			'!proteins', '-casein-',
			'-serum-proteins-', '-nucleotides-',
			'salt', '-added-salt-',
			'sodium', 'alcohol',
			'#vitamins', 'vitamin-a',
			'beta-carotene-', 'vitamin-d-',
			'vitamin-e-', 'vitamin-k-',
			'vitamin-c', 'vitamin-b1-',
			'vitamin-b2-', 'vitamin-pp-',
			'vitamin-b6-', 'vitamin-b9-',
			'folates-', 'vitamin-b12-',
			'biotin-', 'pantothenic-acid-',
			'#minerals', 'silica-',
			'bicarbonate-', 'potassium-',
			'chloride-', 'calcium',
			'phosphorus-', 'iron',
			'magnesium-', 'zinc-',
			'copper-', 'manganese-',
			'fluoride-', 'selenium-',
			'chromium-', 'molybdenum-',
			'iodine-', 'caffeine-',
			'taurine-', 'ph-',
			'!fruits-vegetables-legumes-', 'collagen-meat-protein-ratio-',
			'cocoa-', 'chlorophyl-',
			'carbon-footprint-', 'glycemic-index-',
			'water-hardness-', 'choline-',
			'phylloquinone-', 'beta-glucan-',
			'inositol-', 'carnitine-',
			'sulphate-', 'nitrate-',
			'acidity-', 'carbohydrates-',
		)
	],
	off_ru => [
		(
			'!proteins', '-casein-',
			'-serum-proteins-', '-nucleotides-',
			'!fat', '-saturated-fat',
			'--butyric-acid-', '--caproic-acid-',
			'--caprylic-acid-', '--capric-acid-',
			'--lauric-acid-', '--myristic-acid-',
			'--palmitic-acid-', '--stearic-acid-',
			'--arachidic-acid-', '--behenic-acid-',
			'--lignoceric-acid-', '--cerotic-acid-',
			'--montanic-acid-', '--melissic-acid-',
			'-unsaturated-fat-', '--monounsaturated-fat-',
			'---omega-9-fat-', '--polyunsaturated-fat-',
			'---omega-3-fat-', '---omega-6-fat-',
			'--alpha-linolenic-acid-', '--eicosapentaenoic-acid-',
			'--docosahexaenoic-acid-', '--linoleic-acid-',
			'--arachidonic-acid-', '--gamma-linolenic-acid-',
			'--dihomo-gamma-linolenic-acid-', '--oleic-acid-',
			'--elaidic-acid-', '--gondoic-acid-',
			'--mead-acid-', '--erucic-acid-',
			'--nervonic-acid-', '-trans-fat-',
			'-cholesterol-', '!carbohydrates',
			'-sugars', '--added-sugars-',
			'--sucrose-', '--glucose-',
			'--fructose-', '--galactose-',
			'--lactose-', '--maltose-',
			'--maltodextrins-', '-psicose-',
			'-starch-', '-polyols-',
			'--erythritol-', '--isomalt-',
			'--maltitol-', '--sorbitol-',
			'!energy-kj', '!energy-kcal',
			'energy-', '-energy-from-fat-',
			'fiber', 'salt',
			'-added-salt-', 'sodium',
			'alcohol', '#vitamins',
			'vitamin-a-', 'beta-carotene-',
			'vitamin-d-', 'vitamin-e-',
			'vitamin-k-', 'vitamin-c-',
			'vitamin-b1-', 'vitamin-b2-',
			'vitamin-pp-', 'vitamin-b6-',
			'vitamin-b9-', 'folates-',
			'vitamin-b12-', 'biotin-',
			'pantothenic-acid-', '#minerals',
			'silica-', 'bicarbonate-',
			'potassium-', 'chloride-',
			'calcium-', 'phosphorus-',
			'iron-', 'magnesium-',
			'zinc-', 'copper-',
			'manganese-', 'fluoride-',
			'selenium-', 'chromium-',
			'molybdenum-', 'iodine-',
			'caffeine-', 'taurine-',
			'ph-', '!fruits-vegetables-legumes-',
			'collagen-meat-protein-ratio-', 'cocoa-',
			'chlorophyl-', 'carbon-footprint-',
			'glycemic-index-', 'water-hardness-',
			'choline-', 'phylloquinone-',
			'beta-glucan-', 'inositol-',
			'carnitine-', 'sulphate-',
			'nitrate-', 'acidity-',
			'total-carboydrates-',
		)
	],
	off_us => [
		(
			'!energy-kcal', 'energy-',
			'-energy-from-fat-', '!fat',
			'-saturated-fat', '--butyric-acid-',
			'--caproic-acid-', '--caprylic-acid-',
			'--capric-acid-', '--lauric-acid-',
			'--myristic-acid-', '--palmitic-acid-',
			'--stearic-acid-', '--arachidic-acid-',
			'--behenic-acid-', '--lignoceric-acid-',
			'--cerotic-acid-', '--montanic-acid-',
			'--melissic-acid-', '-unsaturated-fat-',
			'--monounsaturated-fat-', '---omega-9-fat-',
			'--polyunsaturated-fat-', '---omega-3-fat-',
			'---omega-6-fat-', '--alpha-linolenic-acid-',
			'--eicosapentaenoic-acid-', '--docosahexaenoic-acid-',
			'--linoleic-acid-', '--arachidonic-acid-',
			'--gamma-linolenic-acid-', '--dihomo-gamma-linolenic-acid-',
			'--oleic-acid-', '--elaidic-acid-',
			'--gondoic-acid-', '--mead-acid-',
			'--erucic-acid-', '--nervonic-acid-',
			'-trans-fat', 'cholesterol',
			'salt-', '-added-salt-',
			'sodium', '!carbohydrates-total',
			'-fiber', '--soluble-fiber-',
			'---polydextrose-', '--insoluble-fiber-',
			'-sugars', '--added-sugars',
			'--sucrose-', '--glucose-',
			'--fructose-', '--galactose-',
			'--lactose-', '--maltose-',
			'--maltodextrins-', '-psicose-',
			'-starch-', '-polyols-',
			'--erythritol-', '--isomalt-',
			'--maltitol-', '--sorbitol-',
			'!proteins', '-casein-',
			'-serum-proteins-', '-nucleotides-',
			'alcohol', '#vitamins',
			'vitamin-a-', 'beta-carotene-',
			'vitamin-d', 'vitamin-e-',
			'vitamin-k-', 'vitamin-c-',
			'vitamin-b1-', 'vitamin-b2-',
			'vitamin-pp-', 'vitamin-b6-',
			'vitamin-b9-', 'folates-',
			'vitamin-b12-', 'biotin-',
			'pantothenic-acid-', '#minerals',
			'calcium', 'iron',
			'potassium', 'silica-',
			'bicarbonate-', 'chloride-',
			'phosphorus-', 'magnesium-',
			'zinc-', 'copper-',
			'manganese-', 'fluoride-',
			'selenium-', 'chromium-',
			'molybdenum-', 'iodine-',
			'caffeine-', 'taurine-',
			'ph-', '!fruits-vegetables-legumes-',
			'collagen-meat-protein-ratio-', 'cocoa-',
			'chlorophyl-', 'carbon-footprint-',
			'glycemic-index-', 'water-hardness-',
			'sulfate-', 'nitrate-',
			'acidity-', 'carbohydrates-',
			'melatonin-',
		)
	],
	off_us_before_2017 => [
		(
			'!energy', '-energy-from-fat',
			'!fat', '-saturated-fat',
			'--butyric-acid-', '--caproic-acid-',
			'--caprylic-acid-', '--capric-acid-',
			'--lauric-acid-', '--myristic-acid-',
			'--palmitic-acid-', '--stearic-acid-',
			'--arachidic-acid-', '--behenic-acid-',
			'--lignoceric-acid-', '--cerotic-acid-',
			'--montanic-acid-', '--melissic-acid-',
			'-unsaturated-fat-', '--monounsaturated-fat-',
			'---omega-9-fat-', '--polyunsaturated-fat-',
			'---omega-3-fat-', '---omega-6-fat-',
			'--alpha-linolenic-acid-', '--eicosapentaenoic-acid-',
			'--docosahexaenoic-acid-', \'--linoleic-acid-',
			'--arachidonic-acid-', '--gamma-linolenic-acid-',
			'--dihomo-gamma-linolenic-acid-', '--oleic-acid-',
			'--elaidic-acid-', '--gondoic-acid-',
			'--mead-acid-', '--erucic-acid-',
			'--nervonic-acid-', '-trans-fat',
			'cholesterol', 'salt-',
			'sodium', '!carbohydrates-total',
			'-fiber', '--soluble-fiber-',
			'---polydextrose-', '--insoluble-fiber-',
			'-sugars', '--sucrose-',
			'--glucose-', '--fructose-',
			'--lactose-', '--maltose-',
			'--maltodextrins-', '-psicose-',
			'-starch-', '-polyols-',
			'--erythritol-', '--isomalt-',
			'--maltitol-', '--sorbitol-',
			'!proteins', '-casein-',
			'-serum-proteins-', '-nucleotides-',
			'alcohol', '#vitamins',
			'vitamin-a', 'beta-carotene-',
			'vitamin-d-', 'vitamin-e-',
			'vitamin-k-', 'vitamin-c',
			'vitamin-b1-', 'vitamin-b2-',
			'vitamin-pp-', 'vitamin-b6-',
			'vitamin-b9-', 'folates-',
			'vitamin-b12-', 'biotin-',
			'pantothenic-acid-', '#minerals',
			'silica-', 'bicarbonate-',
			'potassium-', 'chloride-',
			'calcium', 'phosphorus-',
			'iron', 'magnesium-',
			'zinc-', 'copper-',
			'manganese-', 'fluoride-',
			'selenium-', 'chromium-',
			'molybdenum-', 'iodine-',
			'caffeine-', 'taurine-',
			'ph-', 'fruits-vegetables-nuts-',
			'fruits-vegetables-nuts-dried-', 'collagen-meat-protein-ratio-',
			'cocoa-', 'chlorophyl-',
			'carbon-footprint-', 'glycemic-index-',
			'water-hardness-', 'choline-',
			'phylloquinone-', 'beta-glucan-',
			'inositol-', 'carnitine-',
			'sulfate-', 'nitrate-',
			'acidity-', 'carbohydrates-',
		)
	],
	off_hk => [
		(
			'!energy-kj', '!energy-kcal', '!proteins', '!fat',
			'-saturated-fat', '-unsaturated-fat-', '--monounsaturated-fat-', '--monounsaturated-fat-',
			'-trans-fat', 'cholesterol', '!carbohydrates-total', '-sugars',
			'-fiber', 'salt-', 'sodium', '#vitamins',
			'vitamin-a', 'vitamin-d-', 'vitamin-c', 'vitamin-b1-',
			'vitamin-b2-', 'vitamin-pp-', 'vitamin-b6-', 'vitamin-b9-',
			'folates-', 'vitamin-b12-', '#minerals', 'calcium',
			'potassium-', 'phosphorus-', 'iron', 'alcohol',
			'sulphate-', 'nitrate-', 'acidity-', 'carbohydrates-',
		)
	],
	off_jp => [
		(
			'!energy-kj-', '!energy-kcal',
			'!energy-', '-energy-from-fat-',
			'!proteins', '-casein-',
			'-serum-proteins-', '-nucleotides-',
			'!fat', '-saturated-fat-',
			'--butyric-acid-', '--caproic-acid-',
			'--caprylic-acid-', '--capric-acid-',
			'--lauric-acid-', '--myristic-acid-',
			'--palmitic-acid-', '--stearic-acid-',
			'--arachidic-acid-', '--behenic-acid-',
			'--lignoceric-acid-', '--cerotic-acid-',
			'--montanic-acid-', '--melissic-acid-',
			'-unsaturated-fat-', '--monounsaturated-fat-',
			'---omega-9-fat-', '--polyunsaturated-fat-',
			'---omega-3-fat-', '---omega-6-fat-',
			'--alpha-linolenic-acid-', '--eicosapentaenoic-acid-',
			'--docosahexaenoic-acid-', '--linoleic-acid-',
			'--arachidonic-acid-', '--gamma-linolenic-acid-',
			'--dihomo-gamma-linolenic-acid-', '--oleic-acid-',
			'--elaidic-acid-', '--gondoic-acid-',
			'--mead-acid-', '--erucic-acid-',
			'--nervonic-acid-', '-trans-fat-',
			'cholesterol-', '!carbohydrates-total',
			'-sugars-', '-fiber-',
			'-soluble-fiber-', '--polydextrose-',
			'-insoluble-fiber-', '!salt',
			'-added-salt-', '#sodium-',
			'alcohol', '#vitamins',
			'vitamin-a-', 'beta-carotene-',
			'vitamin-d-', 'vitamin-e-',
			'vitamin-k-', 'vitamin-c-',
			'vitamin-b1-', 'vitamin-b2-',
			'vitamin-pp-', 'vitamin-b6-',
			'vitamin-b9-', 'folates-',
			'vitamin-b12-', 'biotin-',
			'pantothenic-acid-', '#minerals',
			'silica-', 'bicarbonate-',
			'potassium-', 'chloride-',
			'calcium-', 'phosphorus-',
			'iron-', 'magnesium-',
			'zinc-', 'copper-',
			'manganese-', 'fluoride-',
			'selenium-', 'chromium-',
			'molybdenum-', 'iodine-',
			'caffeine-', 'taurine-',
			'ph-', '!fruits-vegetables-legumes-',
			'collagen-meat-protein-ratio-', 'cocoa-',
			'chlorophyl-', 'carbon-footprint-',
			'glycemic-index-', 'water-hardness-',
			'choline-', 'phylloquinone-',
			'beta-glucan-', 'inositol-',
			'carnitine-', 'sulphate-',
			'nitrate-', 'acidity-',
			'carbohydrates-',
		)
	],
	off_in => [
		(
			'!energy-kj', '!energy-kcal',
			'!proteins', '-casein-',
			'-serum-proteins-', '-nucleotides-',
			'!fat', '-saturated-fat',
			'--butyric-acid-', '--caproic-acid-',
			'--caprylic-acid-', '--capric-acid-',
			'--lauric-acid-', '--myristic-acid-',
			'--palmitic-acid-', '--stearic-acid-',
			'--arachidic-acid-', '--behenic-acid-',
			'--lignoceric-acid-', '--cerotic-acid-',
			'--montanic-acid-', '--melissic-acid-',
			'-unsaturated-fat-', '--monounsaturated-fat-',
			'---omega-9-fat-', '--polyunsaturated-fat-',
			'---omega-3-fat-', '---omega-6-fat-',
			'--alpha-linolenic-acid-', '--eicosapentaenoic-acid-',
			'--docosahexaenoic-acid-', '--linoleic-acid-',
			'--arachidonic-acid-', '--gamma-linolenic-acid-',
			'--dihomo-gamma-linolenic-acid-', '--oleic-acid-',
			'--elaidic-acid-', '--gondoic-acid-',
			'--mead-acid-', '--erucic-acid-',
			'--nervonic-acid-', '-trans-fat-',
			'-cholesterol-', '-gamma-oryzanol-',
			'!carbohydrates', '-sugars',
			'--added-sugars-', '--sucrose-',
			'--glucose-', '--fructose-',
			'--galactose-', '--lactose-',
			'--maltose-', '--maltodextrins-',
			'-psicose-', '-starch-',
			'-polyols-', '--erythritol-',
			'--isomalt-', '--maltitol-',
			'--sorbitol-', '!fiber',
			'-soluble-fiber-', '--polydextrose-',
			'-insoluble-fiber-', '!salt',
			'-added-salt-', 'sodium',
			'alcohol', '#vitamins',
			'vitamin-a-', 'beta-carotene-',
			'vitamin-d-', 'vitamin-e-',
			'vitamin-k-', 'vitamin-c-',
			'vitamin-b1-', 'vitamin-b2-',
			'vitamin-pp-', 'vitamin-b6-',
			'vitamin-b9-', 'folates-',
			'vitamin-b12-', 'biotin-',
			'pantothenic-acid-', '#minerals',
			'silica-', 'bicarbonate-',
			'potassium-', 'chloride-',
			'calcium-', 'phosphorus-',
			'iron-', 'magnesium-',
			'zinc-', 'copper-',
			'manganese-', 'fluoride-',
			'selenium-', 'chromium-',
			'molybdenum-', 'iodine-',
			'caffeine-', 'taurine-',
			'ph-', '!fruits-vegetables-legumes-',
			'collagen-meat-protein-ratio-', 'cocoa-',
			'chlorophyl-', 'carbon-footprint-',
			'glycemic-index-', 'water-hardness-',
			'choline-', 'phylloquinone-',
			'beta-glucan-', 'inositol-',
			'carnitine-', 'sulphate-',
			'nitrate-', 'acidity-',
			'carbohydrates-total-',
		)
	],
	# https://eur-lex.europa.eu/eli/reg/2009/767/2018-12-26
	opff_europe => [
		(
			'!crude-fat', '!crude-protein', '!crude-ash', '!crude-fibre', '!moisture',
			# optional additives, alphabetical order
			'beta-carotene-', 'biotin-', 'calcium-', 'copper-', 'iodine-',
			'iron-', 'magnesium-', 'manganese-', 'omega-3-fat-', 'omega-6-fat-',
			'phosphorus-', 'potassium-', 'selenium-', 'sodium-', 'taurine-',
			'vitamin-a-', 'vitamin-c-', 'vitamin-d-', 'vitamin-e-', 'zinc-',
			# optional stricly pet food related, alphabetical order
			'ammonium-chloride-', 'calcium-iodate-anhydrous-',
			'cassia-gum-', 'choline-chloride-', 'copper-ii-sulphate-pentahydrate-',
			'iron-ii-sulphate-monohydrate-', 'manganous-sulphate-monohydrate-',
			'potassium-iodide-', 'sodium-selenite-', 'zinc-sulphate-monohydrate-',
			'!energy-kj', '!energy-kcal', 'protein-value-'
		)
	]
);

# Compute a hash of all nutrients that are valid in at least one region for the site flavor (opf, off, ...)
%valid_nutrients = ();

foreach my $region (keys %nutrients_tables) {
	# Use the flavor (off, opff) to select regions that start with the flavor
	next if $region !~ /^$flavor\_/;
	foreach (@{$nutrients_tables{$region}}) {
		my $nutriment = $_;    # copy instead of alias
		$nutriment =~ s/^(-|!)+//g;
		$nutriment =~ s/-$//g;
		$valid_nutrients{$nutriment} = 1 unless $nutriment =~ /\#/;
	}
}

# Compute the list of nutriments that are not shown by default so that they can be suggested

foreach my $region (keys %nutrients_tables) {

	$nutrients_lists{$region} = [];
	$other_nutrients_lists{$region} = [];

	foreach (@{$nutrients_tables{$region}}) {

		my $nutriment = $_;    # copy instead of alias

		if ($nutriment =~ /-$/) {
			$nutriment = $`;
			$nutriment =~ s/^(-|!)+//g;
			push @{$other_nutrients_lists{$region}}, $nutriment;
		}

		next if $nutriment =~ /\#/;

		$nutriment =~ s/^(-|!)+//g;
		$nutriment =~ s/-$//g;
		push @{$nutrients_lists{$region}}, $nutriment;
	}
}

=head2 is_beverage_for_nutrition_score_2021 ( $product_ref )

Determines if a product should be considered as a beverage for Nutri-Score computations,
based on the product categories.

2021 Nutri-Score: Dairy drinks are not considered as beverages if they have at least 80% of milk.

=cut

sub is_beverage_for_nutrition_score_2021 ($product_ref) {

	my $is_beverage = 0;

	if (   has_tag($product_ref, "categories", "en:beverages")
		or has_tag($product_ref, "categories", "en:beverage-preparations"))
	{

		$is_beverage = 1;

		if (defined $options{categories_not_considered_as_beverages_for_nutriscore_2021}) {

			foreach my $category_id (@{$options{categories_not_considered_as_beverages_for_nutriscore_2021}}) {

				if (has_tag($product_ref, "categories", $category_id)) {
					$is_beverage = 0;
					last;
				}
			}
		}

		# exceptions
		if (defined $options{categories_considered_as_beverages_for_nutriscore_2021}) {
			foreach my $category_id (@{$options{categories_considered_as_beverages_for_nutriscore_2021}}) {

				if (has_tag($product_ref, "categories", $category_id)) {
					$is_beverage = 1;
					last;
				}
			}
		}

		# dairy drinks need to have at least 80% of milk to be considered as food instead of beverages
		my $milk_percent = estimate_nutriscore_2021_milk_percent_from_ingredients($product_ref);

		if ((defined $milk_percent) and ($milk_percent >= 80)) {
			$log->debug("milk >= 80%", {milk_percent => $milk_percent}) if $log->is_debug();
			$is_beverage = 0;
		}
	}

	return $is_beverage;
}

=head2 is_beverage_for_nutrition_score_2023 ( $product_ref )

Determines if a product should be considered as a beverage for Nutri-Score computations,
based on the product categories.

2023 Nutri-Score: Milk and dairy drinks are considered beverages.

=cut

sub is_beverage_for_nutrition_score_2023 ($product_ref) {

	my $is_beverage = 0;

	if (   has_tag($product_ref, "categories", "en:beverages")
		or has_tag($product_ref, "categories", "en:beverage-preparations"))
	{

		$is_beverage = 1;

		if (defined $options{categories_not_considered_as_beverages_for_nutriscore_2023}) {

			foreach my $category_id (@{$options{categories_not_considered_as_beverages_for_nutriscore_2023}}) {

				if (has_tag($product_ref, "categories", $category_id)) {
					$is_beverage = 0;
					last;
				}
			}
		}
	}

	# exceptions
	if (defined $options{categories_considered_as_beverages_for_nutriscore_2023}) {
		foreach my $category_id (@{$options{categories_considered_as_beverages_for_nutriscore_2023}}) {

			if (has_tag($product_ref, "categories", $category_id)) {
				$is_beverage = 1;
				last;
			}
		}
	}

	return $is_beverage;
}

=head2 is_water_for_nutrition_score( $product_ref )

Determines if a product should be considered as water for Nutri-Score computations,
based on the product categories.

=cut

sub is_water_for_nutrition_score ($product_ref) {

	return (
		(has_tag($product_ref, "categories", "en:spring-waters"))
			and not(has_tag($product_ref, "categories", "en:flavored-waters")
			or has_tag($product_ref, "categories", "en:flavoured-waters"))
	);
}

=head2 is_cheese_for_nutrition_score( $product_ref )

Determines if a product should be considered as cheese for Nutri-Score computations,
based on the product categories.

=cut

sub is_cheese_for_nutrition_score ($product_ref) {

	return ((has_tag($product_ref, "categories", "en:cheeses"))
			and not(has_tag($product_ref, "categories", "fr:fromages-blancs")));
}

=head2 is_fat_for_nutrition_score( $product_ref )

Determines if a product should be considered as fat
for Nutri-Score (2021 version) computations, based on the product categories.

=cut

sub is_fat_for_nutrition_score ($product_ref) {

	return has_tag($product_ref, "categories", "en:fats");
}

=head2 is_fat_oil_nuts_seeds_for_nutrition_score( $product_ref )

Determines if a product should be considered as fats / oils / nuts / seeds
for Nutri-Score (2023 version) computations, based on the product categories.

From the 2022 main algorithm report update FINAL:

"This category includes fats and oils from plant or animal sources, including cream, margarines,
butters and oils (as the current situation).

Additionally, the following products are included in this category, using the Harmonized System
Nomenclature1 codes:
- Nuts: 0801 0802
- Processed nuts: 200811 200819
- Ground nuts: 1202
- Seeds: 1204 (linseed) 1206 (sunflower)1207 (other seeds)

Of note chestnuts are excluded from the category."

=cut

sub is_fat_oil_nuts_seeds_for_nutrition_score ($product_ref) {

	if (has_tag($product_ref, "categories", "en:chestnuts")) {
		return 0;
	}
	elsif (has_tag($product_ref, "categories", "en:fats")
		or has_tag($product_ref, "categories", "en:creams")
		or has_tag($product_ref, "categories", "en:seeds"))
	{
		return 1;
	}
	else {
		my ($hs_heading, $category_id) = get_inherited_property_from_categories_tags($product_ref, "wco_hs_heading:en");

		if (defined $hs_heading) {
			my ($hs_code, $category_id) = get_inherited_property_from_categories_tags($product_ref, "wco_hs_code:en");

			if (
				($hs_heading eq "08.01") or ($hs_heading eq "08.02")    # nuts
				or ((defined $hs_code) and (($hs_code eq "2008.11") or ($hs_code eq "2008.19")))    # processed nuts
				or ($hs_heading eq "12.02")    # peanuts
				or ($hs_heading eq "12.04") or ($hs_heading eq "12.06") or ($hs_heading eq "12.07")    # nuts
				)

			{
				return 1;
			}
		}
	}

	return 0;
}

=head2 is_red_meat_for_nutrition_score ( $product_ref )

Determines if a product should be considered as red meat for Nutri-Score (2023 version) computations,
based on the product categories and/or ingredients.

From the 2022 main algorithm report update FINAL:

"Regarding the Codex Alimentarius classifications, the entire group 08.0 (Meat and meat products,
including poultry and game and all its subgroups) is concerned, though not all food items in the
individual sub-groups are concerned, only those containing red meat (see above).
In the Harmonized System Classification, the codes correspond to the following:

Beef:
o 0201 Meat of bovine animals, fresh or chilled
o 0202 Meat of bovine animals, frozen
Pork
o 0203 Meat of swine, fresh, chilled or frozen
Lamb:
o 0204 Meat of sheep or goats, fresh, chilled or frozen
Horse
o 0205 Horse and equine meat
Game and venison
o 0208903000 Of game, other than of rabbits or hares
o 02089060 Fresh, chilled or frozen reindeer meat and edible offal thereof
Offals and processed meat (as red meat)
o 0206 Edible offal of bovine animals, swine, sheep, goats, horses, asses, mules or
hinnies, fresh, chilled or frozen
o 0210 Meat and edible offal, salted, in brine, dried or smoked; edible flours and meals
of meat or meat offal
o 1601 sausages
o 1602 Prepared or preserved meat, meat offal, blood or insects (excl. sausages and
similar products, and meat extracts and juices)
▪ All those from swine, lamb or beef even as mixtures"

=cut

sub is_red_meat_product_for_nutrition_score ($product_ref) {

	# Use the category HS code if all the corresponding products are considered red meat
	my ($hs_heading, $category_id) = get_inherited_property_from_categories_tags($product_ref, "wco_hs_heading:en");

	if (defined $hs_heading) {

		if (   ($hs_heading eq "02.01")
			or ($hs_heading eq "02.02")
			or ($hs_heading eq "02.03")
			or ($hs_heading eq "02.04")
			or ($hs_heading eq "02.05")
			or ($hs_heading eq "02.06"))
		{
			return 1;
		}
	}

	# Count the % of ingredients that is considered red meat
	# (for products for which we don't have a category, or too broad categories like "sausages" which could be from red meat or from poultry etc.)

	# We use a limit of 10%, in order not to include products that contain very little red meat (e.g. a pizza with cheese),
	# as it's not clear from the Nutri-Score report update if they should be considered "red meat products":
	# "Red meat products qualifying for this specific rule are products from beef, veal, swine and lamb"
	my $red_meat_percent = estimate_nutriscore_2023_red_meat_percent_from_ingredients($product_ref);
	if ((defined $red_meat_percent) and ($red_meat_percent > 10)) {
		return 1;
	}

	return 0;
}

# estimates by category of products. not exact values. For the Nutri-Score, it's important to distinguish only between the thresholds: 40, 60 and 80
# first entries match first, so we put potatoes before vegetables
my @fruits_vegetables_nuts_by_category_sorted_2021 = (
	["en:potatoes", 0],
	["en:sweet-potatoes", 0],
	["en:fruit-juices", 100],
	["en:vegetable-juices", 100],
	["en:mushrooms", 90],
	# 2019/08/31: olive oil, walnut oil and colza oil are now considered in the same fruits, vegetables and nuts category
	["en:olive-oils", 100],
	["en:walnut-oils", 100],
	# adding multiple wordings for colza/rapeseed oil in case we change it at some point
	["en:colza-oils", 100],
	["en:rapeseed-oils", 100],
	["en:rapeseeds-oils", 100],
	# nuts,
	# "Les fruits à coque comprennent :
	# Noix, noisettes, pistaches, noix de cajou, noix de pécan, noix de coco (cf. précisions ci-dessus),
	# arachides, amandes, châtaigne
	["en:walnuts", 100],
	["en:hazelnuts", 100],
	["en:pistachios", 100],
	["en:cashew-nuts", 100],
	["en:pecan-nuts", 100],
	["en:peanuts", 100],
	["en:almonds", 100],
	["en:chestnuts", 100],
	["en:coconuts", 100],
	["en:jams", 50],
	["en:fruit-sauces", 90],
	["en:fruits", 90],
	["en:vegetables", 90],
	["en:canned-fruits", 90],
	["en:frozen-fruits", 90],
	["en:fruits-based-foods", 85],
	["en:vegetables-based-foods", 85],
);

my $nutriscore_fruits_vegetables_nuts_by_category_sorted_2021_initialized = 0;

sub init_nutriscore_fruits_vegetables_nuts_by_category_sorted_2021() {

	return if $nutriscore_fruits_vegetables_nuts_by_category_sorted_2021_initialized;

	# Canonicalize the entries, in case the canonical entry changed
	foreach my $category_ref (@fruits_vegetables_nuts_by_category_sorted_2021) {
		$category_ref->[0] = canonicalize_taxonomy_tag("en", "categories", $category_ref->[0]);
	}

	$nutriscore_fruits_vegetables_nuts_by_category_sorted_2021_initialized = 1;

	return;
}

=head2 compute_nutriscore_2021_fruits_vegetables_nuts_colza_walnut_olive_oil($product_ref)

Compute the fruit % according to the Nutri-Score rules

<b>Warning</b> Also modifies product_ref->{misc_tags}

=head3 return

The fruit ratio

=cut

sub compute_nutriscore_2021_fruits_vegetables_nuts_colza_walnut_olive_oil ($product_ref) {

	init_nutriscore_fruits_vegetables_nuts_by_category_sorted_2021();

	my $fruits = undef;

	# Check if we have a category override:
	# - if the product is in a category that has no unprocessed fruits/vegetables/nuts (e.g. crisps), return 0
	# - if the product is in category that has only ingredients that are consired fruits/vegetables/nuts (e.g. olive oil), return 100
	my ($nutriscore_category_override_for_fruits_vegetables_legumes, $category_id)
		= get_inherited_property_from_categories_tags($product_ref,
		"nutriscore_category_override_for_fruits_vegetables_legumes:en");
	if (defined $nutriscore_category_override_for_fruits_vegetables_legumes) {

		# We are close to certain that those category overrides (either 0 or 100) are correct,
		# so we do not add a nutrition_score_warning_fruits_vegetables_legumes_from_category warning
		add_tag($product_ref, "misc", "en:nutrition-fruits-vegetables-nuts-from-category");
		my $category = $category_id;
		$category =~ s/:/-/;
		add_tag($product_ref, "misc", "en:nutrition-fruits-vegetables-nuts-from-category-$category");
		return $nutriscore_category_override_for_fruits_vegetables_legumes;
	}

	# For the Nutri-Score, we use the aggregated_set nutrients
	# We put prepared values in aggregated_set if we have prepared values.
	# If the aggregated set is for the product as sold even though we need prepared values for the product category,
	# we will not compute the Nutri-Score.

	my $fruits_vegetable_nuts
		= deep_get($product_ref, "nutrition", "aggregated_set", "nutrients", "fruits-vegetables-nuts", "value");
	my $fruits_vegetable_nuts_source
		= deep_get($product_ref, "nutrition", "aggregated_set", "nutrients", "fruits-vegetables-nuts", "source");
	my $fruits_vegetable_nuts_dried
		= deep_get($product_ref, "nutrition", "aggregated_set", "nutrients", "fruits-vegetables-nuts-dried", "value");

	if (defined $fruits_vegetable_nuts_dried) {
		$fruits = 2 * $fruits_vegetable_nuts_dried;
		add_tag($product_ref, "misc", "en:nutrition-fruits-vegetables-nuts-dried");

		if (defined $fruits_vegetable_nuts) {
			$fruits += $fruits_vegetable_nuts;
			add_tag($product_ref, "misc", "en:nutrition-fruits-vegetables-nuts");
		}

		$fruits = $fruits * 100 / (100 + $fruits_vegetable_nuts_dried);
	}
	elsif (defined $fruits_vegetable_nuts) {
		$fruits = $fruits_vegetable_nuts;
		if ($fruits_vegetable_nuts_source eq "estimate") {
			$product_ref->{nutrition_score_warning_fruits_vegetables_nuts_estimate_from_ingredients} = 1;
			$product_ref->{nutrition_score_warning_fruits_vegetables_nuts_estimate_from_ingredients_value} = $fruits;
			add_tag($product_ref, "misc", "en:nutrition-fruits-vegetables-nuts-estimate-from-ingredients");
		}
		else {
			add_tag($product_ref, "misc", "en:nutrition-fruits-vegetables-nuts");
		}
	}
	else {
		# estimates by category of products. not exact values. it's important to distinguish only between the thresholds: 40, 60 and 80
		foreach my $category_ref (@fruits_vegetables_nuts_by_category_sorted_2021) {

			my $category_id = $category_ref->[0];
			if (has_tag($product_ref, "categories", $category_id)) {
				$fruits = $category_ref->[1];
				$product_ref->{nutrition_score_warning_fruits_vegetables_nuts_from_category} = $category_id;
				$product_ref->{nutrition_score_warning_fruits_vegetables_nuts_from_category_value} = $fruits;
				add_tag($product_ref, "misc", "en:nutrition-fruits-vegetables-nuts-from-category");
				my $category = $category_id;
				$category =~ s/:/-/;
				add_tag($product_ref, "misc", "en:nutrition-fruits-vegetables-nuts-from-category-$category");
				last;
			}
		}

		# If we do not have a fruits estimate, use 0 and add a warning
		if (not defined $fruits) {
			$fruits = 0;
			$product_ref->{nutrition_score_warning_no_fruits_vegetables_nuts} = 1;
			add_tag($product_ref, "misc", "en:nutrition-no-fruits-vegetables-nuts");
		}
	}

	if (   (defined $product_ref->{nutrition_score_warning_no_fiber})
		or (defined $product_ref->{nutrition_score_warning_no_fruits_vegetables_nuts}))
	{
		add_tag($product_ref, "misc", "en:nutrition-no-fiber-or-fruits-vegetables-nuts");
	}
	else {
		add_tag($product_ref, "misc", "en:nutrition-all-nutriscore-values-known");
	}

	return $fruits;
}

# estimates by category of products. not exact values. For the Nutri-Score, it's important to distinguish only between the thresholds: 40, 60 and 80
# first entries match first, so we put potatoes before vegetables
my @fruits_vegetables_legumes_by_category_if_no_ingredients_specified_sorted = (
	["en:potatoes", 0],
	["en:sweet-potatoes", 0],
	["en:fruit-juices", 100],
	["en:vegetable-juices", 100],
	["en:fruit-sauces", 90],
	["en:vegetables", 90],
	["en:fruits", 90],
	["en:mushrooms", 90],
	["en:canned-fruits", 90],
	["en:frozen-fruits", 90],
	["en:jams", 50],
);

my $nutriscore_fruits_vegetables_nuts_by_category_sorted_2023_initialized = 0;

sub init_nutriscore_fruits_vegetables_legumes_by_category_sorted_2023() {

	return if $nutriscore_fruits_vegetables_nuts_by_category_sorted_2023_initialized;

	# Canonicalize the entries, in case the canonical entry changed
	foreach my $category_ref (@fruits_vegetables_legumes_by_category_if_no_ingredients_specified_sorted) {
		$category_ref->[0] = canonicalize_taxonomy_tag("en", "categories", $category_ref->[0]);
	}
	$nutriscore_fruits_vegetables_nuts_by_category_sorted_2023_initialized = 1;

	return;
}

=head2 compute_nutriscore_2023_fruits_vegetables_legumes($product_ref)

Compute the % of fruits, vegetables and legumes for the Nutri-Score 2023 algorithm.

Differences with the 2021 version:
- we use only the estimate from the ingredients or a conservative estimate from the product category
- we do not use values estimated by users from ingredients list: too difficult to know what should be included or not

=head3 Arguments

=head4 $product_ref - ref to the product

=head3 Return values

Return undef if no value could be computed or estimated.

=cut

sub compute_nutriscore_2023_fruits_vegetables_legumes ($product_ref) {

	init_nutriscore_fruits_vegetables_legumes_by_category_sorted_2023();

	# Check if we have a category override:
	# - if the product is in a category that has no unprocessed fruits/vegetables/nuts (e.g. crisps), return 0
	# - if the product is in category that has only ingredients that are consired fruits/vegetables/nuts (e.g. olive oil), return 100
	my ($nutriscore_category_override_for_fruits_vegetables_legumes, $category_id)
		= get_inherited_property_from_categories_tags($product_ref,
		"nutriscore_category_override_for_fruits_vegetables_legumes:en");
	if (defined $nutriscore_category_override_for_fruits_vegetables_legumes) {
		# We are close to certain that those category overrides (either 0 or 100) are correct,
		# so we do not add a nutrition_score_warning_fruits_vegetables_legumes_from_category warning
		add_tag($product_ref, "misc", "en:nutrition-fruits-vegetables-legumes-from-category");
		my $category = $category_id;
		$category =~ s/:/-/;
		add_tag($product_ref, "misc", "en:nutrition-fruits-vegetables-legumes-from-category-$category");
		return $nutriscore_category_override_for_fruits_vegetables_legumes
			+ 0;    # Add 0 to make the property value a number
	}

	my $fruits_vegetables_legumes
		= deep_get($product_ref, "nutrition", "aggregated_set", "nutrients", "fruits-vegetables-legumes", "value");

	if (defined $fruits_vegetables_legumes) {
		# Check if the source is estimated
		if (deep_get($product_ref, "nutrition", "aggregated_set", "nutrients", "fruits-vegetables-legumes", "source")
			eq "estimate")
		{
			$product_ref->{nutrition_score_warning_fruits_vegetables_legumes_estimate_from_ingredients} = 1;
			$product_ref->{nutrition_score_warning_fruits_vegetables_legumes_estimate_from_ingredients_value}
				= $fruits_vegetables_legumes;
			add_tag($product_ref, "misc", "en:nutrition-fruits-vegetables-legumes-estimate-from-ingredients");
		}
		else {
			add_tag($product_ref, "misc", "en:nutrition-fruits-vegetables-legumes");
		}
	}
	# if we do not have ingredients, try to use the product category
	else {
		foreach my $category_ref (@fruits_vegetables_legumes_by_category_if_no_ingredients_specified_sorted) {

			my $category_id = $category_ref->[0];
			if (has_tag($product_ref, "categories", $category_id)) {
				$fruits_vegetables_legumes = $category_ref->[1];
				$product_ref->{nutrition_score_warning_fruits_vegetables_legumes_from_category} = $category_id;
				$product_ref->{nutrition_score_warning_fruits_vegetables_legumes_from_category_value}
					= $fruits_vegetables_legumes;
				add_tag($product_ref, "misc", "en:nutrition-fruits-vegetables-legumes-from-category");
				my $category = $category_id;
				$category =~ s/:/-/;
				add_tag($product_ref, "misc", "en:nutrition-fruits-vegetables-legumes-from-category-$category");
				last;
			}
		}
	}

	return $fruits_vegetables_legumes;
}

=head2 saturated_fat_ratio( $nutrition_ref )

Compute saturated_fat_ratio as needed for nutriscore

=head3 Arguments

=head4 $nutrition_ref - ref to the nutrition of a product

=cut

sub saturated_fat_ratio ($nutrition_ref) {

	my $saturated_fat = deep_get($nutrition_ref, "aggregated_set", "nutrients", "saturated-fat", "value");
	my $fat = deep_get($nutrition_ref, "aggregated_set", "nutrients", "fat", "value");
	my $saturated_fat_ratio = 0;
	if ((defined $saturated_fat) and ($saturated_fat > 0)) {
		if ($fat <= 0) {
			$fat = $saturated_fat;
		}
		$saturated_fat_ratio = $saturated_fat / $fat * 100;    # in %
	}
	return $saturated_fat_ratio;
}

=head2 saturated_fat_0_because_of_fat_0 ($nutrition_ref)

Detect if we are in the special case where we can detect saturated fat is 0 because fat is 0

=head3 Arguments

=head4 $nutrition_ref - ref to the nutrition of a product

=cut

sub saturated_fat_0_because_of_fat_0 ($nutrition_ref) {
	my $saturated_fat = deep_get($nutrition_ref, "aggregated_set", "nutrients", "saturated-fat", "value");
	my $fat = deep_get($nutrition_ref, "aggregated_set", "nutrients", "fat", "value");
	return ((not defined $saturated_fat) && (defined $fat) && ($fat == 0));
}

=head2 sugar_0_because_of_carbohydrates_0 ($nutrition_ref)

Detect if we are in the special case where we can detect sugars are 0 because carbohydrates are 0

=head3 Arguments

=head4 $nutrition_ref - ref to the nutrition of a product

=cut

sub sugar_0_because_of_carbohydrates_0 ($nutrition_ref) {
	my $sugars = deep_get($nutrition_ref, "aggregated_set", "nutrients", "sugars", "value");
	my $carbohydrates = deep_get($nutrition_ref, "aggregated_set", "nutrients", "carbohydrates", "value");
	return ((not defined $sugars) && (defined $carbohydrates) && ($carbohydrates == 0));
}

=head2 compute_nutriscore_data( $products_ref, $preparation, $version )

Compute data for nutriscore computation.

<b>Warning:</b> it also modifies $product_ref

=head3 Arguments

=head4 $product_ref - ref to the product

=head4 $preparation - "as_sold" or "prepared"

=head4 $version - version of nutriscore to compute data for. Either "2021" or "2023". Default is "2021"

=head4

=head3 return

Ref to a mapping suitable to call compute_nutriscore_score_and_grade

=cut

sub compute_nutriscore_data ($product_ref, $preparation, $version = "2021") {

	my $nutriscore_data_ref;

	# If the preparation needed for the Nutri-Score does not match the aggregated set preparation,
	# we temporarily rename the aggregated set so that we get undef values for the nutrients
	my $aggregated_set_preparation = deep_get($product_ref, "nutrition", "aggregated_set", "preparation");
	if ((defined $aggregated_set_preparation) and ($preparation ne $aggregated_set_preparation)) {
		$product_ref->{nutrition}->{aggregated_set_temp_for_nutriscore}
			= $product_ref->{nutrition}->{aggregated_set};
		delete $product_ref->{nutrition}->{aggregated_set};
	}

	# The 2021 and 2023 version of the Nutri-Score need different nutrients
	if ($version eq "2021") {
		# fruits, vegetables, nuts, olive / rapeseed / walnut oils - 2021
		my $fruits_vegetables_nuts_colza_walnut_olive_oils
			= compute_nutriscore_2021_fruits_vegetables_nuts_colza_walnut_olive_oil($product_ref);

		my $is_fat = is_fat_for_nutrition_score($product_ref);

		my $sodium = deep_get($product_ref, "nutrition", "aggregated_set", "nutrients", "sodium", "value");
		my $fiber = deep_get($product_ref, "nutrition", "aggregated_set", "nutrients", "fiber", "value");

		$nutriscore_data_ref = {
			is_beverage => $product_ref->{nutrition_score_beverage},
			is_water => is_water_for_nutrition_score($product_ref),
			is_cheese => is_cheese_for_nutrition_score($product_ref),
			is_fat => $is_fat,

			energy => deep_get($product_ref, "nutrition", "aggregated_set", "nutrients", "energy", "value"),
			sugars => deep_get($product_ref, "nutrition", "aggregated_set", "nutrients", "sugars", "value"),
			saturated_fat =>
				deep_get($product_ref, "nutrition", "aggregated_set", "nutrients", "saturated-fat", "value"),
			sodium => (
				(defined $sodium)
				? $sodium * 1000
				: undef
			),    # in mg,

			fruits_vegetables_nuts_colza_walnut_olive_oils => $fruits_vegetables_nuts_colza_walnut_olive_oils,
			fiber => (
				(defined $fiber)
				? $fiber
				: 0
			),
			proteins => deep_get($product_ref, "nutrition", "aggregated_set", "nutrients", "proteins", "value"),
		};

		if ($is_fat) {
			# Add the fat and saturated fat / fat ratio
			$nutriscore_data_ref->{fat}
				= deep_get($product_ref, "nutrition", "aggregated_set", "nutrients", "fat", "value");
			$nutriscore_data_ref->{saturated_fat_ratio} = saturated_fat_ratio($product_ref->{nutrition});
		}
	}
	else {
		# fruits, vegetables, legumes - 2023
		my $fruits_vegetables_legumes
			= round_to_max_decimal_places(compute_nutriscore_2023_fruits_vegetables_legumes($product_ref), 1);

		my $is_fat_oil_nuts_seeds = is_fat_oil_nuts_seeds_for_nutrition_score($product_ref);
		my $is_beverage = is_beverage_for_nutrition_score_2023($product_ref);

		$nutriscore_data_ref = {
			is_beverage => $is_beverage,
			is_water => is_water_for_nutrition_score($product_ref),
			is_cheese => is_cheese_for_nutrition_score($product_ref),
			is_fat_oil_nuts_seeds => $is_fat_oil_nuts_seeds,
			is_red_meat_product => is_red_meat_product_for_nutrition_score($product_ref),

			energy => deep_get($product_ref, "nutrition", "aggregated_set", "nutrients", "energy", "value"),
			sugars => deep_get($product_ref, "nutrition", "aggregated_set", "nutrients", "sugars", "value"),
			saturated_fat =>
				deep_get($product_ref, "nutrition", "aggregated_set", "nutrients", "saturated-fat", "value"),
			salt => deep_get($product_ref, "nutrition", "aggregated_set", "nutrients", "salt", "value"),

			fruits_vegetables_legumes => $fruits_vegetables_legumes,
			fiber => deep_get($product_ref, "nutrition", "aggregated_set", "nutrients", "fiber", "value"),
			proteins => deep_get($product_ref, "nutrition", "aggregated_set", "nutrients", "proteins", "value"),
		};

		if ($is_fat_oil_nuts_seeds) {
			# Add the fat and saturated fat / fat ratio
			$nutriscore_data_ref->{fat}
				= deep_get($product_ref, "nutrition", "aggregated_set", "nutrients", "fat", "value");
			$nutriscore_data_ref->{saturated_fat_ratio}
				= round_to_max_decimal_places(saturated_fat_ratio($product_ref->{nutrition}), 1);
			# Compute the energy from saturates
			if (defined $nutriscore_data_ref->{saturated_fat}) {
				$nutriscore_data_ref->{energy_from_saturated_fat} = $nutriscore_data_ref->{saturated_fat} * 37;
			}
		}

		if ($is_beverage) {
			$nutriscore_data_ref->{non_nutritive_sweeteners} = $product_ref->{ingredients_non_nutritive_sweeteners_n};
		}
	}

	# tweak data to take into account special cases

	# if sugar is undefined but carbohydrates is 0, set sugars to 0
	if (sugar_0_because_of_carbohydrates_0($product_ref->{nutrition})) {
		$nutriscore_data_ref->{sugars} = 0;
	}
	# if saturated_fat is undefined but fat is 0, set saturated_fat to 0
	# as well as saturated_fat_ratio
	if (saturated_fat_0_because_of_fat_0($product_ref->{nutrition})) {
		$nutriscore_data_ref->{saturated_fat} = 0;
		$nutriscore_data_ref->{saturated_fat_ratio} = 0;
	}

	# Put back the original aggregated set if we had renamed it
	if (defined $product_ref->{nutrition}->{aggregated_set_temp_for_nutriscore}) {
		$product_ref->{nutrition}->{aggregated_set}
			= $product_ref->{nutrition}->{aggregated_set_temp_for_nutriscore};
		delete $product_ref->{nutrition}->{aggregated_set_temp_for_nutriscore};
	}

	return $nutriscore_data_ref;
}

=head2 remove_nutriscore_fields ( $product_ref )

=cut

sub remove_nutriscore_fields ($product_ref) {

	# remove direct fields from the product
	remove_fields(
		$product_ref,
		[
			"nutriscore",
			"nutrition_score_warning_no_fiber",
			"nutrition_score_warning_fruits_vegetables_nuts_estimate",
			"nutrition_score_warning_fruits_vegetables_nuts_from_category",
			"nutrition_score_warning_fruits_vegetables_nuts_from_category_value",
			"nutrition_score_warning_fruits_vegetables_nuts_estimate_from_ingredients",
			"nutrition_score_warning_fruits_vegetables_nuts_estimate_from_ingredients_value",
			"nutrition_score_warning_no_fruits_vegetables_nuts",
			"nutrition_score_warning_fruits_vegetables_legumes_estimate",
			"nutrition_score_warning_fruits_vegetables_legumes_from_category",
			"nutrition_score_warning_fruits_vegetables_legumes_from_category_value",
			"nutrition_score_warning_fruits_vegetables_legumes_estimate_from_ingredients",
			"nutrition_score_warning_fruits_vegetables_legumes_estimate_from_ingredients_value",
			"nutrition_score_warning_no_fruits_vegetables_legumes",
			"nutriscore_score",
			"nutriscore_score_opposite",
			"nutriscore_grade",
			"nutriscore_data",
			"nutriscore_points",
			"nutrition_grade_fr",
			"nutrition_grades",
			"nutrition_grades_tags",
			"nutriscore_tags",
			"nutriscore_2021_tags",
			"nutriscore_2023_tags",
		]
	);

	# remove misc_tags fields related to Nutri-Score
	if (defined $product_ref->{misc_tags}) {
		$product_ref->{misc_tags} = [grep {$_ !~ /^en:(nutriscore|nutrition)-/} @{$product_ref->{misc_tags}}];
	}

	return;
}

=head2 is_nutriscore_applicable_to_the_product_categories($product_ref)

Check that the product has a category, that we know if it is a beverage or not,
and that it is not in a category for which the Nutri-Score should not be computed
(e.g. food for babies)

=head3 Return values

=head4 $category_available - 0 or 1

=head4 $nutriscore_applicable - 0 or 1

=head4 $not_applicable_category - undef or category id

=cut

sub is_nutriscore_applicable_to_the_product_categories ($product_ref) {

	my $category_available = 1;
	my $nutriscore_applicable = 1;
	my $not_applicable_category = undef;

	# do not compute a score when we don't have a category
	if ((not defined $product_ref->{categories}) or ($product_ref->{categories} eq '')) {
		$product_ref->{"nutrition_grades_tags"} = ["unknown"];
		$product_ref->{nutrition_score_debug} = "no score when the product does not have a category" . " - ";
		add_tag($product_ref, "misc", "en:nutriscore-missing-category");
		$category_available = 0;
		$nutriscore_applicable = 0;
	}

	if (not defined $product_ref->{nutrition_score_beverage}) {
		$product_ref->{"nutrition_grades_tags"} = ["unknown"];
		$product_ref->{nutrition_score_debug} = "did not determine if it was a beverage" . " - ";
		add_tag($product_ref, "misc", "en:nutriscore-beverage-status-unknown");
		$nutriscore_applicable = 0;
	}

	# do not compute a score for coffee, tea etc. except ice teas etc.

	if (defined $options{categories_exempted_from_nutriscore}) {

		my $not_exempted = 0;

		foreach my $category_id (@{$options{categories_not_exempted_from_nutriscore}}) {

			if (has_tag($product_ref, "categories", $category_id)) {
				$not_exempted = 1;
				last;
			}
		}

		if (not $not_exempted) {

			foreach my $category_id (@{$options{categories_exempted_from_nutriscore}}) {

				if (has_tag($product_ref, "categories", $category_id)) {
					$product_ref->{"nutrition_grades_tags"} = ["not-applicable"];
					add_tag($product_ref, "misc", "en:nutriscore-not-applicable");
					$product_ref->{nutrition_score_debug} = "no nutriscore for category $category_id" . " - ";
					$product_ref->{nutriscore_data} = {nutriscore_not_applicable_for_category => $category_id};
					$nutriscore_applicable = 0;
					$not_applicable_category = $category_id;
					last;
				}
			}
		}
	}

	return ($category_available, $nutriscore_applicable, $not_applicable_category);
}

=head2 has_category_that_should_have_prepared_nutrition_data($product_ref)

Check if the product should have prepared nutrition data, based on its categories.

=head3 Arguments

=head4 $product_ref - ref to the product

=head3 Return values

=head4 $category_tag - undef or category tag

Return the product category tag that should have prepared nutrition data, or undef if none.

=cut

sub has_category_that_should_have_prepared_nutrition_data ($product_ref) {

	foreach my $category_tag (
		"en:dried-products-to-be-rehydrated", "en:cocoa-and-chocolate-powders",
		"en:dessert-mixes", "en:flavoured-syrups",
		"en:instant-beverages", "en:beverage-preparations"
		)
	{

		if (has_tag($product_ref, "categories", $category_tag)) {
			return $category_tag;
		}
	}
	return;
}

=head2 check_availability_of_nutrients_needed_for_nutriscore ($product_ref)

Check that we know or can estimate the nutrients needed to compute the Nutri-Score of the product.

To compute the Nutri-Score, we use the nutrition.aggregated_set 

=head3 Arguments

=head4 $product_ref - ref to the product

=head3 Return values

=head4 $nutrients_available 0 or 1

=head4 $preparation: "as_sold" or "prepared"

Indicates if the Nutri-Score should be computed on as sold or prepared values

=head4 $estimated: 0 or 1

Indicates if some of the nutrients needed were estimated

=cut

sub check_availability_of_nutrients_needed_for_nutriscore ($product_ref) {

	my $nutrients_available = 1;
	my $estimated = 0;

	# do not compute a score for dehydrated products to be rehydrated (e.g. dried soups, powder milk)
	# unless we have nutrition data for the prepared product
	# same for en:chocolate-powders, en:dessert-mixes and en:flavoured-syrups

	my $preparation = "as_sold";

	my $category_tag = has_category_that_should_have_prepared_nutrition_data($product_ref);

	if (defined $category_tag) {

		$preparation = "prepared";

		my $aggregated_set_preparation = deep_get($product_ref, "nutrition", "aggregated_set", "preparation");

		if ((defined $aggregated_set_preparation) and ($aggregated_set_preparation eq "prepared")) {
			$product_ref->{nutrition_score_debug} = "using prepared product data for category $category_tag" . " - ";
			add_tag($product_ref, "misc", "en:nutrition-grade-computed-for-prepared-product");
		}
		else {
			$product_ref->{"nutrition_grades_tags"} = ["unknown"];
			$product_ref->{nutrition_score_debug}
				= "no score for category $category_tag without data for prepared product" . " - ";
			add_tag($product_ref, "misc", "en:nutriscore-missing-prepared-nutrition-data");
			$nutrients_available = 0;
		}
	}

	# Track the number of key nutrients present and their source
	my $key_nutrients = 0;
	my %key_nutrients_sources = ();

	# Spring waters have grade A automatically, and have a different nutrition table without sugars etc.
	# do not display warnings about missing fiber and fruits

	if (
		not(
			(has_tag($product_ref, "categories", "en:spring-waters"))
			and not(has_tag($product_ref, "categories", "en:flavored-waters")
				or has_tag($product_ref, "categories", "en:flavoured-waters"))
		)
		)
	{
		# compute the score only if all values are known
		# for fiber, compute score without fiber points if the value is not known
		# or use an estimate if available
		# foreach my $nid ("energy", "saturated-fat", "sugars", "sodium", "fiber", "proteins") {

		foreach my $nid ("energy", "fat", "saturated-fat", "sugars", "sodium", "proteins") {
			# If we don't set the 100g figure then this should flag the item as not enough data
			if (not deep_exists($product_ref, "nutrition", "aggregated_set", "nutrients", $nid, "value")) {
				# we have two special cases where we can deduce data
				next
					if (
					(($nid eq "saturated-fat") && saturated_fat_0_because_of_fat_0($product_ref->{nutrition}))
					|| (($nid eq "sugars")
						&& sugar_0_because_of_carbohydrates_0($product_ref->{nutrition}))
					);
				$product_ref->{"nutrition_grades_tags"} = ["unknown"];
				add_tag($product_ref, "misc", "en:nutrition-not-enough-data-to-compute-nutrition-score");
				$product_ref->{nutrition_score_debug} .= "missing $preparation $nid - ";
				add_tag($product_ref, "misc", "en:nutriscore-missing-nutrition-data");
				add_tag($product_ref, "misc", "en:nutriscore-missing-nutrition-data-$nid");
				$nutrients_available = 0;
			}
			else {
				$key_nutrients++;
				my $source = deep_get($product_ref, "nutrition", "aggregated_set", "nutrients", $nid, "source");
				$key_nutrients_sources{$source} = [] unless exists $key_nutrients_sources{$source};
				push @{$key_nutrients_sources{$source}}, $nid;
				# Add misc tags for nutrients coming from estimated source
				if ($source eq "estimate") {
					add_tag($product_ref, "misc", "en:nutriscore-estimated-$nid");
					$product_ref->{nutrition_score_debug} .= "$preparation $nid estimated - ";
				}
			}
		}

		# some categories of products do not have fibers > 0.7g (e.g. sodas)
		# for others, display a warning when the value is missing
		my $fiber_source = deep_get($product_ref, "nutrition", "aggregated_set", "nutrients", "fiber", "source");
		if ((not deep_exists($product_ref, "nutrition", "aggregated_set", "nutrients", "fiber", "value"))
			and not(has_tag($product_ref, "categories", "en:sodas")))
		{
			$product_ref->{nutrition_score_warning_no_fiber} = 1;
			add_tag($product_ref, "misc", "en:nutriscore-missing-fiber");
		}
		# Add a misc tag when fiber is estimated
		elsif ((defined $fiber_source) and ($fiber_source eq "estimate")) {
			add_tag($product_ref, "misc", "en:nutriscore-estimated-fiber");
			$product_ref->{nutrition_score_debug} .= "$preparation fiber estimated - ";
			$estimated = 1;
		}
	}

	# Remove ending -
	$product_ref->{nutrition_score_debug} =~ s/ - $//;

	# If all key nutrients come from estimated nutrients, mark the product as such
	# If some but not all key nutrients come from estimated nutrients, we do not use estimated nutrients
	# in order to encourage users to complete the nutrition facts
	# (that we know exist, and that we may even have a photo for).
	# If we don't have nutrients at all (or the no nutriments checkbox is checked),
	# we can use estimated nutrients for the Nutri-Score, if the category does not require prepared nutrients.

	if (
		(
			not(    (defined $product_ref->{"nutrition_grades_tags"})
				and ($product_ref->{"nutrition_grades_tags"}[0] eq "unknown"))
		)
		and (exists $key_nutrients_sources{"estimate"})
		)
	{
		$estimated = 1;

		# Check if all key nutrients are from estimated source
		if ($key_nutrients == scalar @{$key_nutrients_sources{"estimate"}}) {
			$product_ref->{nutrition_score_warning_nutriments_estimated} = 1;
			add_tag($product_ref, "misc", "en:nutriscore-using-estimated-nutrition-facts");
		}
		else {
			# Some nutrients are estimated, some are not
			# Don't mix the sources to compute the Nutri-Score
			$product_ref->{"nutrition_grades_tags"} = ["unknown"];
			$product_ref->{nutrition_score_debug}
				.= "did not compute nutriscore because some nutrients are estimated and some are not" . " - ";
			add_tag($product_ref, "misc", "en:nutriscore-mixed-nutrition-facts-sources");
			$nutrients_available = 0;
			# Indicate which nutrients are estimated and missing in the other sources
			foreach my $nid (@{$key_nutrients_sources{"estimate"}}) {
				add_tag($product_ref, "misc", "en:nutrition-not-enough-data-to-compute-nutrition-score");
				$product_ref->{nutrition_score_debug} .= "missing $preparation $nid - ";
				add_tag($product_ref, "misc", "en:nutriscore-missing-nutrition-data");
				add_tag($product_ref, "misc", "en:nutriscore-missing-nutrition-data-$nid");
			}
		}
	}

	return ($nutrients_available, $preparation, $estimated);
}

=head2 set_fields_for_current_version_of_nutriscore($product_ref, $current_version, $nutriscore_score, $nutriscore_grade)

We may compute several versions of the Nutri-Score grade and score. One version is considered "current".
This function sets the product fields for the current version.

=cut

sub set_fields_for_current_version_of_nutriscore ($product_ref, $version, $nutriscore_score, $nutriscore_grade) {

	# Record which version is the current version
	$product_ref->{nutriscore_version} = $version;

	# Copy the Nutriscore data to nutriscore_data
	# to easily see diffs with previous Nutri-Score structure
	# (to be deleted once we are sure everything works,
	# we will generate the nutriscore_data fields on request
	# when asked through the API with an old API version)
	# Before 2023-08-29, we did not create a nutriscore_data structure when the Nutri-Score was not computed
	# so we do not copy the nutriscore data structure in that case.
	if ($product_ref->{nutriscore}{$version}{nutriscore_computed}) {
		$product_ref->{nutriscore_data} = dclone($product_ref->{nutriscore}{$version}{data});
		# The grade and score fields are now one level up (not in the data section)
		# copy them for backward compatibility
		$product_ref->{nutriscore_data}{grade} = $nutriscore_grade;
		$product_ref->{nutriscore_data}{score} = $nutriscore_score;
	}

	# Copy the resulting values to the main Nutri-Score fields
	if (defined $nutriscore_score) {
		$product_ref->{nutriscore_score} = $nutriscore_score;

		# In order to be able to sort by nutrition score in MongoDB,
		# we create an opposite of the nutrition score
		# as otherwise, in ascending order on nutriscore_score, we first get products without the nutriscore_score field
		# instead we can sort on descending order on nutriscore_score_opposite
		$product_ref->{nutriscore_score_opposite} = -$nutriscore_score;
	}
	$product_ref->{nutriscore_grade} = $nutriscore_grade;

	$product_ref->{"nutrition_grades_tags"} = [$nutriscore_grade];
	$product_ref->{"nutrition_grades"} = $nutriscore_grade;    # needed for the /nutrition-grade/unknown query
															   # (TODO at some point: remove the nutrition_grades field)

	# Gradually rename nutrition_grades_tags to nutriscore_tags
	$product_ref->{"nutriscore_tags"} = [$nutriscore_grade];

	# Legacy field, to be removed from the product and returned by the API on request / for older versions
	$product_ref->{"nutrition_grade_fr"} = $nutriscore_grade;

	return;
}

=head2 set_fields_comparing_nutriscore_versions($product_ref, $version1, $version2)

When we are migrating from one version of the Nutri-Score to another (e.g. 2021 vs 2023),
we may compute both version for a time. This function sets temporary fields to ease the comparison
of both versions.

Once the migration is complete, those fields will no longer be computed.

=cut

sub set_fields_comparing_nutriscore_versions ($product_ref, $version1, $version2) {

	my $nutriscore1 = $product_ref->{nutriscore}{$version1}{grade};
	my $nutriscore2 = $product_ref->{nutriscore}{$version2}{grade};

	# Set tags fields for both versions
	$product_ref->{"nutriscore_${version1}_tags"} = [$nutriscore1];
	$product_ref->{"nutriscore_${version2}_tags"} = [$nutriscore2];

	# Compare both versions, only if Nutri-Score has been computed in at least one version
	if (   (not $product_ref->{nutriscore}{$version1}{nutriscore_computed})
		or (not $product_ref->{nutriscore}{$version2}{nutriscore_computed}))
	{
		return;
	}

	if ($nutriscore1 eq $nutriscore2) {
		add_tag($product_ref, "misc", "en:nutriscore-$version1-same-as-$version2");
	}
	else {
		add_tag($product_ref, "misc", "en:nutriscore-$version1-different-from-$version2");
		if ($nutriscore1 lt $nutriscore2) {
			add_tag($product_ref, "misc", "en:nutriscore-$version1-better-than-$version2");
		}
		else {
			add_tag($product_ref, "misc", "en:nutriscore-$version1-worse-than-$version2");
		}
	}

	add_tag($product_ref, "misc", "en:nutriscore-$version1-$nutriscore1-$version2-$nutriscore2");

	return;
}

=head2 compute_nutriscore( $product_ref, $current_version = "2023" )

Determines if we have enough data to compute the Nutri-Score (category + nutrition facts),
and if the Nutri-Score is applicable to the product the category.

Populates the data structure needed to compute the Nutri-Score and computes it.

=cut

sub compute_nutriscore ($product_ref, $current_version = "2023") {

	# Initialize values

	$product_ref->{nutrition_score_debug} = '';

	# Remove any previously existing Nutri-Score related fields
	remove_nutriscore_fields($product_ref);

	my ($category_available, $nutriscore_applicable, $not_applicable_category)
		= is_nutriscore_applicable_to_the_product_categories($product_ref);

	my ($nutrients_available, $preparation, $estimated)
		= check_availability_of_nutrients_needed_for_nutriscore($product_ref);

	if (not($nutriscore_applicable and $nutrients_available)) {
		add_tag($product_ref, "misc", "en:nutriscore-not-computed");
	}
	else {
		add_tag($product_ref, "misc", "en:nutriscore-computed");
	}

	# 2023/08/10: compute both the 2021 and the 2023 versions of the Nutri-Score

	foreach my $version ("2021", "2023") {

		# Record if we have enough data to compute the Nutri-Score and if the Nutri-Score is applicable to the product categories
		deep_set(
			$product_ref,
			"nutriscore",
			$version,
			{
				"category_available" => $category_available,
				"nutriscore_applicable" => $nutriscore_applicable,
				"nutrients_available" => $nutrients_available,
				"nutriscore_computed" => $nutriscore_applicable * $nutrients_available,
				"preparation" => $preparation,
				"estimated" => $estimated,
			}
		);

		if (defined $not_applicable_category) {
			deep_set($product_ref, "nutriscore", $version, "not_applicable_category", $not_applicable_category);
		}

		# Populate the data structure that will be passed to Food::Nutriscore
		deep_set($product_ref, "nutriscore", $version, "data",
			compute_nutriscore_data($product_ref, $preparation, $version));

		# Compute the Nutri-Score
		my ($nutriscore_score, $nutriscore_grade);

		if (not $category_available) {
			$nutriscore_grade = "unknown";
		}
		elsif (not $nutriscore_applicable) {
			$nutriscore_grade = "not-applicable";
		}
		elsif (not $nutrients_available) {
			$nutriscore_grade = "unknown";
		}
		else {
			($nutriscore_score, $nutriscore_grade)
				= ProductOpener::Nutriscore::compute_nutriscore_score_and_grade(
				$product_ref->{nutriscore}{$version}{data}, $version);
		}

		# Populate the Nutri-Score fields for the current version
		if ($version eq $current_version) {

			set_fields_for_current_version_of_nutriscore($product_ref, $current_version, $nutriscore_score,
				$nutriscore_grade);
		}

		$product_ref->{nutriscore}{$version}{grade} = $nutriscore_grade;
		if (defined $nutriscore_score) {
			$product_ref->{nutriscore}{$version}{score} = $nutriscore_score;
		}
	}

	# 2023/08/17: as we are migrating from one version of the Nutri-Score to another, we set temporary fields
	# to compare both versions.
	set_fields_comparing_nutriscore_versions($product_ref, "2021", "2023");

	return;
}

=head2 compute_nutrient_levels ($product_ref)

Computes nutrient levels (low, moderate, high) for fat, saturated fat, sugars, salt/sodium and alcohol.
The nutrient levels are also known as nutrition traffic lights.

We use the aggregated set to compute the levels.

=cut

sub compute_nutrient_levels ($product_ref) {

	$product_ref->{nutrient_levels_tags} = [];
	$product_ref->{nutrient_levels} = {};

	# do not compute a score if we do not have an aggregated_set
	my $aggregated_set_ref = deep_get($product_ref, "nutrition", "aggregated_set");

	if (not defined $aggregated_set_ref) {
		$log->debug("no aggregated_set, cannot compute nutrient levels for product " . $product_ref->{_id})
			if $log->is_debug();
		return;
	}

	# need categories in order to identify drinks
	if ((not defined $product_ref->{categories}) or ($product_ref->{categories} eq '')) {
		$log->debug("no categories, cannot compute nutrient levels for product " . $product_ref->{_id})
			if $log->is_debug();
		return;
	}

	# do not compute a score for dehydrated products to be rehydrated (e.g. dried soups, powder milk)
	# unless we have nutrition data for the prepared product

	if (has_tag($product_ref, "categories", "en:dried-products-to-be-rehydrated")) {

		my $aggregated_state_preparation = deep_get($aggregated_set_ref, "preparation");

		if (not(defined $aggregated_state_preparation) or ($aggregated_state_preparation ne "prepared")) {
			$log->debug(
				"dehydrated product without prepared nutrition data, cannot compute nutrient levels for product "
					. $product_ref->{_id})
				if $log->is_debug();
			return;
		}
	}

	# do not compute a score for coffee, tea etc.

	if (defined $options{categories_exempted_from_nutrient_levels}) {

		foreach my $category_id (@{$options{categories_exempted_from_nutrient_levels}}) {

			if (has_tag($product_ref, "categories", $category_id)) {
				$log->debug("product in exempted category $category_id, cannot compute nutrient levels for product "
						. $product_ref->{_id})
					if $log->is_debug();
				return;
			}
		}
	}

	foreach my $nutrient_level_ref (@nutrient_levels) {
		my ($nid, $low, $high) = @{$nutrient_level_ref};

		# divide low and high per 2 for drinks

		if (has_tag($product_ref, "categories", "en:beverages")) {
			$low = $low / 2;
			$high = $high / 2;
		}

		my $value = deep_get($aggregated_set_ref, "nutrients", $nid, "value");

		if (defined $value) {

			if ($value < $low) {
				$product_ref->{nutrient_levels}{$nid} = 'low';
			}
			elsif ($value > $high) {
				$product_ref->{nutrient_levels}{$nid} = 'high';
			}
			else {
				$product_ref->{nutrient_levels}{$nid} = 'moderate';
			}
			push @{$product_ref->{nutrient_levels_tags}},
				'en:'
				. get_string_id_for_lang(
				"en",
				sprintf(
					$Lang{nutrient_in_quantity}{en},
					display_taxonomy_tag("en", "nutrients", "zz:$nid"),
					$Lang{$product_ref->{nutrient_levels}{$nid} . "_quantity"}{en}
				)
				);

		}
		else {
			delete $product_ref->{nutrient_levels}{$nid};
		}
	}

	return;
}

my %nutrient_level_evaluation_table = (
	low => "good",
	moderate => "average",
	high => "bad",
);

sub evaluate_nutrient_level ($nid, $nutrient_level) {
	# Will need different tables if we add nutrients that are good for you
	return $nutrient_level_evaluation_table{$nutrient_level} // 'unknown';
}

=head2 create_nutrients_level_taxonomy ()

C<create_nutrients_level_taxonomy()> creates the source file for the nutrients level
taxonomy: /taxonomies/nutrient_levels.txt

It creates entries such as "High in saturated fat" in all languages.

=cut

sub create_nutrients_level_taxonomy() {

	# We need the nutrients taxonomy to be loaded before generating the nutrient_levels taxonomy

	my $nutrient_levels_taxonomy = '';

	foreach my $nutrient_level_ref (@nutrient_levels) {
		my ($nid, $low, $high) = @{$nutrient_level_ref};
		foreach my $level ('low', 'moderate', 'high') {
			$nutrient_levels_taxonomy
				.= "\n"
				. 'en:'
				. sprintf(
				$Lang{nutrient_in_quantity}{en},
				display_taxonomy_tag("en", "nutrients", "zz:$nid"),
				$Lang{$level . "_quantity"}{en}
				) . "\n";
			foreach my $l (sort keys %Langs) {
				next if $l eq 'en';
				$nutrient_levels_taxonomy
					.= $l . ':'
					. sprintf(
					$Lang{nutrient_in_quantity}{$l},
					display_taxonomy_tag($l, "nutrients", "zz:$nid"),
					$Lang{$level . "_quantity"}{$l}
					) . "\n";
			}
		}
	}

	my $file = "$BASE_DIRS{TAXONOMIES_SRC}/nutrient_levels.txt";

	print STDERR "generate $file\n";

	open(my $OUT, ">:encoding(UTF-8)", $file)
		or die("Can't write $file: $!");
	print $OUT <<TXT
# nutrient levels taxonomy generated automatically by Food.pm from nutrients taxonomy + language translations (.po files)

TXT
		;
	print $OUT $nutrient_levels_taxonomy;
	close $OUT;

	return;
}

$log->debug("Nutrient levels initialized") if $log->is_debug();

=head2 compute_units_of_alcohol ($product_ref, $serving_size_in_ml)

calculate the number of units of alcohol in one serving of an alcoholic beverage.
(https://en.wikipedia.org/wiki/Unit_of_alcohol)

=cut

sub compute_units_of_alcohol ($product_ref, $serving_size_in_ml) {

	my $alcohol = deep_get($product_ref, "nutrition", "aggregated_set", "nutrients", "alcohol", "value");

	if (    (defined $product_ref)
		and (defined $serving_size_in_ml)
		and (defined $alcohol)
		and (has_tag($product_ref, 'categories', 'en:alcoholic-beverages')))
	{
		return $serving_size_in_ml * ($alcohol / 1000.0);
	}
	else {
		return;
	}
}

=head2 compare_nutrients ($a_ref, $b_ref)

For each comparable nutrient in both $a_ref and $b_ref, compute what percent the $a_ref value differs from the $b_ref value

=head3 Arguments

=head4 $a_ref - ref to a product, a category, ajr etc.

=head4 $b_ref - ref to a structure with nutrient values to compare to

=head3 Return values

=head4 $nutrients_ref - ref to a hash with the nutrient values from $b_ref and the percent difference between $a_ref and $b_ref values

=cut

sub compare_nutrients ($a_ref, $b_ref) {

	# $a_ref can be a product, a category, ajr etc. -> needs {nutrition}{aggregated_set}{$nid}{value}
	# $b_ref is the value references
	my $nutrients_ref = {};

	foreach my $nid (keys %{$b_ref->{values}}) {

		my $a_value = deep_get($a_ref, "nutrition", "aggregated_set", "nutrients", $nid, "value");
		my $b_value = $b_ref->{values}{$nid}{mean};

		$log->trace("compare_nutrients", {nid => $nid, a_value => $a_value, b_value => $b_value}) if $log->is_trace();

		if ($b_value ne '') {    # do the following if the comparison quantity exists, ie is not ""

			deep_set($nutrients_ref, $nid, "mean", $b_value);

			if (($b_value > 0) and (defined $a_value)) {
				# compute what percent the $a_ref value differs from the $b_ref value
				deep_set($nutrients_ref, ${nid}, "mean_percent", ($a_value - $b_value) / $b_value * 100);
			}
		}
	}

	return $nutrients_ref;

}

sub compute_nova_group ($product_ref) {

	# compute Nova group
	# https://archive.wphna.org/wp-content/uploads/2016/01/WN-2016-7-1-3-28-38-Monteiro-Cannon-Levy-et-al-NOVA.pdf

	# remove nova keys.
	remove_fields(
		$product_ref,
		[
			"nova_group_debug", "nova_group", "nova_groups", "nova_groups_tags",
			"nova_group_tags", "nova_groups_markers", "nova_group_error"
		]
	);

	$product_ref->{nova_group_debug} = "";

	# do not compute a score when it is not food
	if (has_tag($product_ref, "categories", "en:non-food-products")) {
		$product_ref->{nova_groups_tags} = ["not-applicable"];
		$product_ref->{nova_group_debug} = "no nova group for non food products";
		return;
	}

	# determination process:
	# - start by assigning group 1
	# - see if the group needs to be increased based on category, ingredients and additives

	$product_ref->{nova_group} = 1;

	# Record the "markers" (e.g. categories or ingredients) that indicate a specific NOVA group
	my %nova_groups_markers = ();

	# We currently have 2 sources for tags that can trigger a given NOVA group:
	# 1. tags specified in the %options of Config.pm
	# 2. tags in the categories, ingredients and additives taxonomy that have a nova:en property

	# We first generate lists of matching tags for each NOVA group, from the two sources

	my %matching_tags_for_groups = (2 => [], 3 => [], 4 => []);

	# Matching tags from options

	if (defined $options{nova_groups_tags}) {

		foreach my $tag (
			sort {($options{nova_groups_tags}{$a} <=> $options{nova_groups_tags}{$b}) || ($a cmp $b)}
			keys %{$options{nova_groups_tags}}
			)
		{

			if ($tag =~ /\//) {

				my $tagtype = $`;
				my $tagid = $';

				if (has_tag($product_ref, $tagtype, $tagid)) {
					push @{$matching_tags_for_groups{$options{nova_groups_tags}{$tag} + 0}}, [$tagtype, $tagid];
				}
			}
		}
	}

	# Matching tags from taxonomies

	foreach my $tagtype ("categories", "ingredients", "additives") {

		if ((defined $product_ref->{$tagtype . "_tags"}) and (defined $properties{$tagtype})) {

			foreach my $tagid (@{$product_ref->{$tagtype . "_tags"}}) {

				my $nova_group = get_property($tagtype, $tagid, "nova:en");

				if (defined $nova_group) {
					push @{$matching_tags_for_groups{$nova_group + 0}}, [$tagtype, $tagid];
				}
			}
		}
	}

	# Go through the nested ingredients structure to check if some ingredients
	# have a processing that has a nova:en: property
	if (defined $product_ref->{ingredients}) {
		# Create a copy of the ingredients structure to avoid modifying the original one
		my $ingredients_ref = dclone($product_ref->{ingredients});
		while (my $ingredient_ref = shift @{$ingredients_ref}) {
			if (defined $ingredient_ref->{processing}) {
				foreach my $processing (split(/,/, $ingredient_ref->{processing})) {
					my $nova_group = get_property("ingredients_processing", $processing, "nova:en");
					if (defined $nova_group) {
						push @{$matching_tags_for_groups{$nova_group + 0}}, ["ingredients", $ingredient_ref->{id}];
					}
				}
			}
			if (defined $ingredient_ref->{ingredients}) {
				push @{$ingredients_ref}, @{$ingredient_ref->{ingredients}};
			}
		}
	}

	# Assign the NOVA group based on matching tags (options in Config.pm and then taxonomies)
	# First identify group 2 foods, then group 3 and 4
	# Group 2 foods should not be moved to group 3
	# (e.g. sugar contains the ingredient sugar, but it should stay group 2)

	my %seen_markers = ();

	foreach my $nova_group (2, 3, 4) {
		foreach my $matching_tag_ref (@{$matching_tags_for_groups{$nova_group}}) {
			my ($tagtype, $tagid) = @$matching_tag_ref;
			if (
				($nova_group >= $product_ref->{nova_group})
				# don't move group 2 to group 3
				and not(($nova_group == 3) and ($product_ref->{nova_group} == 2))
				)
			{
				$product_ref->{nova_group} = $nova_group;
				defined $nova_groups_markers{$nova_group} or $nova_groups_markers{$nova_group} = [];
				# Make sure we don't record the same marker twice (e.g. once from Config.pm, and once from ingredients taxonomy)
				if (not exists $seen_markers{$tagtype . ':' . $tagid}) {
					push @{$nova_groups_markers{$nova_group}}, [$tagtype, $tagid];
					$seen_markers{$tagtype . ':' . $tagid} = 1;
				}
			}
		}
	}

	# Group 1
	# Unprocessed or minimally processed foods
	# The first NOVA group is of unprocessed or minimally processed foods. Unprocessed (or
	# natural) foods are edible parts of plants (seeds, fruits, leaves, stems, roots) or of animals
	# (muscle, offal, eggs, milk), and also fungi, algae and water, after separation from nature.
	# Minimally processed foods are natural foods altered by processes such as removal of
	# inedible or unwanted parts, drying, crushing, grinding, fractioning, filtering, roasting, boiling,
	# pasteurisation, refrigeration, freezing, placing in containers, vac uum packaging, or non-alcoholic
	# fermentation. None of these processes adds substances such as salt, sugar, oils
	# or fats to the original food.
	# The main purpose of the processes used in the production of group 1 foods is to extend the
	# life of unprocessed foods, allowing their storage for longer use, such as chilling, freezing,
	# drying, and pasteurising. Other purposes include facilitating or diversifying food preparation,
	# such as in the removal of inedible parts and fractioning of vegetables, the crushing or
	# grinding of seeds, the roasting of coffee beans or tea leaves, and the fermentation of milk
	# to make yoghurt.
	#
	# Group 1 foods include fresh, squeezed, chilled, frozen, or dried fruits and leafy and root
	# vegetables; grains such as brown, parboiled or white rice, corn cob or kernel, wheat berry or
	# grain; legumes such as beans of all types, lentils, chickpeas; starchy roots and tubers such
	# as potatoes and cassava, in bulk or packaged; fungi such as fresh or dried mushrooms;
	# meat, poultry, fish and seafood, whole or in the form of steaks, fillets and other cuts, or
	# chilled or frozen; eggs; milk, pasteurised or powdered; fresh or pasteurised fruit or vegetable
	# juices without added sugar, sweeteners or flavours; grits, flakes or flour made from corn,
	# wheat, oats, or cassava; pasta, couscous and polenta made with flours, flakes or grits and
	# water; tree and ground nuts and other oil seeds without added salt or sugar; spices such as
	# pepper, cloves and cinnamon; and herbs such as thyme and mint, fresh or dried;
	# plain yoghurt with no added sugar or artificial sweeteners added; tea, coffee, drinking water.
	# Group 1 also includes foods made up from two or more items in this group, such as dried
	# mixed fruits, granola made from cereals, nuts and dried fruits with no added sugar, honey or
	# oil; and foods with vitamins and minerals added generally to replace nutrients lost during
	# processing, such as wheat or corn flour fortified with iron or folic acid.
	# Group 1 items may infrequently contain additives used to preserve the properties of the
	# original food. Examples are vacuum-packed vegetables with added anti-oxidants, and ultra
	# -pasteurised milk with added stabilisers.

	# Group 2
	# Processed culinary ingredients
	# The second NOVA group is of processed culinary ingredients. These are substances
	# obtained directly from group 1 foods or from nature by processes such as pressing, refining,
	# grinding, milling, and spray drying.
	# The purpose of processing here is to make products used in home and restaurant kitchens
	# to prepare, season and cook group 1 foods and to make with them varied and enjoyable
	# hand-made dishes, soups and broths, breads, preserves, salads, drinks, desserts
	# and other culinary preparations.
	# Group 2 items are rarely consumed in the absence of group 1 foods. Examples are salt
	# mined or from seawater; sugar and molasses obtained from cane or beet; honey extracted
	# from combs and syrup from maple trees; vegetable oils crushed from olives or seeds; butter
	# and lard obtained from milk and pork; and starches extracted from corn and other plants.
	# Products consisting of two group 2 items, such as salted butter, group 2 items
	# with added vitamins or minerals, such as iodised salt, and vinegar made by acetic fermentation of wine
	# or other alcoholic drinks, remain in this group.
	# Group 2 items may contain additives used to preserve the product’s original properties.
	# Examples are vegetable oils with added anti-oxidants, cooking salt with added anti-humectants,
	# and vinegar with added preservatives that prevent microorganism proliferation.

	# Group 3
	# Processed foods
	# The third NOVA group is of processed foods. These are relatively simple products made by
	# adding sugar, oil, salt or other group 2 substances to group 1 foods.
	# Most processed foods have two or three ingredients. Processes include various preservation or cooking methods,
	# and, in the case of breads and cheese, non-alcoholic fermentation.
	# The main purpose of the manufacture of processed foods is to increase the durability of
	# group 1 foods,or to modify or enhance their sensory qualities.
	# Typical examples of processed foods are canned or bottled vegetables, fruits and legumes;
	# salted or sugared nuts and seeds; salted, cured, or smoked meats; canned fish; fruits in
	# syrup; cheeses and unpackaged freshly made breads
	# Processed foods may contain additives used to preserve their original properties or to resist
	# microbial contamination. Examples are fruits in syrup with added anti-oxidants, and dried
	# salted meats with added preservatives.
	# When alcoholic drinks are identified as foods, those produced by fermentation of group 1
	# foods such as beer, cider and wine, are classified here in Group 3.

	# Group 4
	# Ultra-processed food and drink products
	# The fourth NOVA group is of ultra-processed food and drink products. These are industrial
	# formulations typically with five or more and usually many ingredients. Such ingredients often
	# include those also used in processed foods, such as sugar, oils, fats, salt, anti-oxidants,
	# stabilisers, and preservatives. Ingredients only found in ultra-processed products include
	# substances not commonly used in culinary preparations, and additives whose purpose is to
	# imitate sensory qualities of group 1 foods or of culinary preparations of these foods, or to
	# disguise undesirable sensory qualities of the final product. Group 1 foods are a small
	# proportion of or are even absent from ultra-processed products.
	# Substances only found in ultra-processed products include some directly extracted from
	# foods, such as casein, lactose, whey, and gluten, and some derived from further processing
	# of food constituents, such as hydrogenated or interesterified oils, hydrolysed proteins, soy
	# protein isolate, maltodextrin, invert sugar and high fructose corn syrup.
	# Classes of additive only found in ultra-processed products include dyes and other colours
	# , colour stabilisers, flavours, flavour enhancers, non-sugar sweeteners, and processing aids such as
	# carbonating, firming, bulking and anti-bulking, de-foaming, anti-caking and glazing agents,
	# emulsifiers, sequestrants and humectants.
	# Several industrial processes with no domestic equivalents are used in the manufacture of
	# ultra-processed products, such as extrusion and moulding, and pre-processing for frying.
	# The main purpose of industrial ultra-processing is to create products that are ready to eat, to
	# drink or to heat, liable to replace both unprocessed or minimally processed foods that are
	# naturally ready to consume, such as fruits and nuts, milk and water, and freshly prepared
	# drinks, dishes, desserts and meals. Common attributes of ultra-processed products are
	# hyper-palatability, sophisticated and attractive packaging, multi-media and other aggressive
	# marketing to children and adolescents, health claims, high profitability, and branding and
	# ownership by transnational corporations.
	# Examples of typical ultra-processed products are: carbonated drinks; sweet or savoury
	# packaged snacks; ice-cream, chocolate, candies (confectionery); mass-produced packaged
	# breads and buns; margarines and spreads; cookies (biscuits), pastries, cakes, and cake
	# mixes; breakfast ‘cereals’, ‘cereal’and ‘energy’ bars; ‘energy’ drinks; milk drinks, ‘fruit’
	# yoghurts and ‘fruit’ drinks; cocoa drinks; meat and chicken extracts and ‘instant’ sauces;
	# infant formulas, follow-on milks, other baby products; ‘health’ and ‘slimmin
	# g’ products such as powdered or ‘fortified’ meal and dish substitutes; and many ready to
	# heat products including pre-prepared pies and pasta and pizza dishes; poultry and fish ‘nuggets’ and
	# ‘sticks’, sausages, burgers, hot dogs, and other reconstituted mea
	# t products, and powdered and packaged ‘instant’ soups, noodles and desserts.
	# When products made solely of group 1 or group 3 foods also contain cosmetic or sensory
	# intensifying additives, such as plain yoghurt with added artificialsweeteners, and brea
	# ds with added emulsifiers, they are classified here in group 4. When alcoholic drinks are
	# identified as foods, those produced by fermentation of group 1 foods followed by distillation
	# of the resulting alcohol, such as whisky, gin, rum, vodka, are classified in group 4.

	# If we don't have ingredients, only compute score for water, or when we have a group 2 category (e.g. sugars, vinegars, honeys)
	if ((not defined $product_ref->{ingredients_text}) or ($product_ref->{ingredients_text} eq '')) {

		# Exclude flavored waters
		if (
			has_tag($product_ref, 'categories', 'en:waters')
			and (
				not(   has_tag($product_ref, 'categories', 'en:flavored-waters')
					or has_tag($product_ref, 'categories', 'en:flavoured-waters'))
			)
			)
		{
			$product_ref->{nova_group} = 1;
		}
		elsif ($product_ref->{nova_group} != 2) {
			delete $product_ref->{nova_group};
			$product_ref->{nova_groups_tags} = ["unknown"];
			$product_ref->{nova_group_debug} = "no nova group when the product does not have ingredients";
			$product_ref->{nova_group_error} = "missing_ingredients";
			return;
		}
	}
	# Unless we found a marker for NOVA 4, do not compute a score if there are too many unknown ingredients:
	elsif ($product_ref->{nova_group} != 4) {

		# do not compute a score if we have too many unknown ingredients
		if (   has_tag($product_ref, "quality", "en:ingredients-100-percent-unknown")
			or has_tag($product_ref, "quality", "en:ingredients-90-percent-unknown")
			or has_tag($product_ref, "quality", "en:ingredients-80-percent-unknown")
			or has_tag($product_ref, "quality", "en:ingredients-70-percent-unknown")
			or has_tag($product_ref, "quality", "en:ingredients-60-percent-unknown")
			or has_tag($product_ref, "quality", "en:ingredients-50-percent-unknown"))
		{
			delete $product_ref->{nova_group};
			$product_ref->{nova_groups_tags} = ["unknown"];
			$product_ref->{nova_group_debug} = "no nova group if too many ingredients are unknown";
			$product_ref->{nova_group_error} = "too_many_unknown_ingredients";
			return;
		}

		if ($product_ref->{unknown_ingredients_n} > ($product_ref->{ingredients_n} / 2)) {
			delete $product_ref->{nova_group};
			$product_ref->{nova_groups_tags} = ["unknown"];
			$product_ref->{nova_group_debug}
				= "no nova group if too many ingredients are unknown: "
				. $product_ref->{unknown_ingredients_n}
				. " out of "
				. $product_ref->{ingredients_n};
			$product_ref->{nova_group_error} = "too_many_unknown_ingredients";
			return;
		}

		# do not compute a score when we don't have a category
		if ((not defined $product_ref->{categories}) or ($product_ref->{categories} eq '')) {
			delete $product_ref->{nova_group};
			$product_ref->{nova_groups_tags} = ["unknown"];
			$product_ref->{nova_group_debug} = "no nova group when the product does not have a category";
			$product_ref->{nova_group_error} = "missing_category";
			return;
		}
	}

	# Make sure that nova_group is stored as a number

	$product_ref->{nova_group} += 0;

	# Store nova_groups as a string

	$product_ref->{nova_groups} = $product_ref->{nova_group};
	$product_ref->{nova_groups} .= "";
	$product_ref->{nova_groups_tags} = [canonicalize_taxonomy_tag("en", "nova_groups", $product_ref->{nova_groups})];

	# Keep the ingredients / categories markers for the resulting nova group
	$product_ref->{nova_groups_markers} = \%nova_groups_markers;

	return;
}

sub extract_nutrition_from_image ($product_ref, $image_type, $image_lc, $ocr_engine, $results_ref) {

	extract_text_from_image($product_ref, $image_type, $image_lc, "nutrition_text_from_image", $ocr_engine,
		$results_ref);

	# clean and process text
	if (($results_ref->{status} == 0) and (defined $results_ref->{nutrition_text_from_image})) {

		# TODO: extract the nutrition facts values
	}

	return;
}

=head2 assign_categories_properties_to_product ( PRODUCT_REF )

Go through the categories of a product to apply category properties at the product level.
The most specific categories are checked first. If the category has
a value for the property, it is assigned to the product and the processing stop.

This function was first designed to assign a CIQUAL category to products, based on
the mapping of the Open Food Facts categories to the French CIQUAL categories.

It may be used for other properties in the future.

agribalyse_food_code:en:42501
agribalyse_proxy_food_code:en:43244

=cut

sub assign_categories_properties_to_product ($product_ref) {

	$product_ref->{categories_properties} = {};
	$product_ref->{categories_properties_tags} = [];

	# Simple properties

	push @{$product_ref->{categories_properties_tags}}, "all-products";

	if (defined $product_ref->{categories}) {
		push @{$product_ref->{categories_properties_tags}}, "categories-known";
	}
	else {
		push @{$product_ref->{categories_properties_tags}}, "categories-unknown";
	}

	foreach my $property ("agribalyse_food_code:en", "agribalyse_proxy_food_code:en", "ciqual_food_code:en") {

		my $property_name = $property;
		$property_name =~ s/:en$//;

		# Find the first category with a defined value for the property

		if (defined $product_ref->{categories_tags}) {
			foreach my $categoryid (reverse @{$product_ref->{categories_tags}}) {
				if (    (defined $properties{categories}{$categoryid})
					and (defined $properties{categories}{$categoryid}{$property}))
				{
					$product_ref->{categories_properties}{$property} = $properties{categories}{$categoryid}{$property};
					last;
				}
			}
		}

		if (defined $product_ref->{categories_properties}{$property}) {
			push @{$product_ref->{categories_properties_tags}},
				get_string_id_for_lang("no_language",
				$property_name . "-" . $product_ref->{categories_properties}{$property});
			push @{$product_ref->{categories_properties_tags}},
				get_string_id_for_lang("no_language", $property_name . "-" . "known");
		}
		else {
			push @{$product_ref->{categories_properties_tags}},
				get_string_id_for_lang("no_language", $property_name . "-" . "unknown");
		}
	}
	if (   (defined $product_ref->{categories_properties}{"agribalyse_food_code:en"})
		or (defined $product_ref->{categories_properties}{"agribalyse_proxy_food_code:en"}))
	{
		push @{$product_ref->{categories_properties_tags}},
			get_string_id_for_lang("no_language", "agribalyse" . "-" . "known");
		push @{$product_ref->{categories_properties_tags}},
			get_string_id_for_lang(
			"no_language",
			"agribalyse" . "-"
				. (
					   $product_ref->{categories_properties}{"agribalyse_food_code:en"}
					|| $product_ref->{categories_properties}{"agribalyse_proxy_food_code:en"}
				)
			);
	}
	else {
		push @{$product_ref->{categories_properties_tags}},
			get_string_id_for_lang("no_language", "agribalyse" . "-" . "unknown");
	}

	return;
}

=head2 get_nutrient_unit ( $nid, $cc )

Returns the unit of the nutrient.

We may have a unit specific to the country (e.g. US nutrition facts table using the International Unit for this nutrient, and Europe using mg)

=cut

sub get_nutrient_unit ($nid, $cc = undef) {
	my $unit;
	if ($cc) {
		$unit = get_property("nutrients", "zz:$nid", "unit_$cc:en");
		return $unit if $unit;
	}
	$unit = get_property("nutrients", "zz:$nid", "unit:en") // 'g';
	return $unit;
}

1;
