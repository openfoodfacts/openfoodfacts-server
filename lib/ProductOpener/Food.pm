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

		%cc_nutriment_table
		%nutriments_tables

		%other_nutriments_lists
		%nutriments_lists

		@nutrient_levels

		%categories_nutriments_per_country

		&normalize_nutriment_value_and_modifier
		&assign_nid_modifier_value_and_unit

		&canonicalize_nutriment

		&fix_salt_equivalent

		&is_beverage_for_nutrition_score_2021
		&is_beverage_for_nutrition_score_2023
		&is_fat_oil_nuts_seeds_for_nutrition_score
		&is_water_for_nutrition_score
		&is_cheese_for_nutrition_score
		&is_fat_for_nutrition_score

		&compute_nutriscore
		&compute_nutriscore
		&compute_nova_group
		&compute_serving_size_data
		&compute_unknown_nutrients
		&compute_nutrient_levels
		&compute_units_of_alcohol
		&compute_estimated_nutrients

		&compare_nutriments

		&special_process_product

		&extract_nutrition_from_image

		&default_unit_for_nid

		&create_nutrients_level_taxonomy

		&assign_categories_properties_to_product

		&assign_nutriments_values_from_request_parameters

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Store qw/:all/;
use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Nutriscore qw/:all/;
use ProductOpener::Numbers qw/:all/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::Text qw/:all/;
use ProductOpener::FoodGroups qw/:all/;
use ProductOpener::Units qw/:all/;
use ProductOpener::Products qw(&remove_fields);
use ProductOpener::Display qw/single_param/;
use ProductOpener::APIProductWrite qw/skip_protected_field/;
use ProductOpener::NutritionEstimation qw/:all/;

use Hash::Util;
use Encode;
use URI::Escape::XS;

use CGI qw/:cgi :form escapeHTML/;

use Data::DeepAccess qw(deep_set deep_get);
use Storable qw/dclone/;

use Log::Any qw($log);

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
			}
		}
	}
}

# Load nutrient stats for all categories and countries
# the stats are displayed on category pages and used in product pages,
# as well as in data quality checks and improvement opportunity detection

if (opendir(my $dh, "$BASE_DIRS{PRIVATE_DATA}/categories_stats")) {
	foreach my $file (readdir($dh)) {
		if ($file =~ /categories_nutriments_per_country.(\w+).sto$/) {
			my $country_cc = $1;
			$categories_nutriments_per_country{$country_cc}
				= retrieve(
				"$BASE_DIRS{PRIVATE_DATA}/categories_stats/categories_nutriments_per_country.$country_cc.sto");
		}
	}
	closedir $dh;
}

# Unicode category 'Punctuation, Dash', SWUNG DASH and MINUS SIGN
my $dashes = qr/(?:\p{Pd}|\N{U+2053}|\N{U+2212})/i;

=head2 normalize_nutriment_value_and_modifier ( $value_ref, $modifier_ref )

Each nutrient value is entered as a string (by users on the product edit form,
or through the API). The string value may not always be numeric (e.g. it can include a < sign).

This function normalizes the string value to remove signs, and stores extra information in the "modifier" field.

=head3 Arguments

=head4 string value reference $value_ref

Input string value reference. The value will be normalized.

=head4 modifier reference $modifier_ref

Output modifier reference.

=head3 Possible return values

=head4 value

- 0 if the input value indicates traces
- Number (as a string)
- undef for 'NaN' (not a number, sometimes sent by broken API clients)

=head4 modifier

<, >, ≤, ≥, ~ character sign, for lesser, greater, lesser or equal, greater or equal, and about
- (minus sign) character when the input value is - (or other dashes) : indicates that the value is not present on the package

=cut

sub normalize_nutriment_value_and_modifier ($value_ref, $modifier_ref) {

	${$modifier_ref} = undef;

	return if not defined ${$value_ref};

	# empty or null value
	if ((${$value_ref} =~ /^\s*$/) or (lc(${$value_ref}) =~ /nan/)) {
		${$value_ref} = undef;
	}
	# < , >, etc. signs
	elsif (${$value_ref} =~ /(\&lt;=|<=|\N{U+2264})( )?/) {
		${$value_ref} =~ s/(\&lt;=|<=|\N{U+2264})( )?//;
		${$modifier_ref} = "\N{U+2264}";
	}
	elsif (${$value_ref} =~ /(\&lt;|<|max|maxi|maximum|inf|inférieur|inferieur|less|less than|menos|menor|inferior)( )?/i) {
		${$value_ref} =~ s/(\&lt;|<|max|maxi|maximum|inf|inférieur|inferieur|less|less than|menos|menor|inferior)( )?//i;
		${$modifier_ref} = '<';
	}
	elsif (${$value_ref} =~ /(\&gt;=|>=|\N{U+2265})/) {
		${$value_ref} =~ s/(\&gt;=|>=|\N{U+2265})( )?//;
		${$modifier_ref} = "\N{U+2265}";
	}
	elsif (${$value_ref} =~ /(\&gt;|>|min|mini|minimum|greater|more|more than|más|mayor|superior)/i) {
		${$value_ref} =~ s/(\&gt;|>|min|mini|minimum|greater|more|more than|más|mayor|superior)( )?//i;
		${$modifier_ref} = '>';
	}
	elsif (${$value_ref} =~ /(env|environ|about|~|≈|aprox|alrededor)/i) {
		${$value_ref} =~ s/(env|environ|about|~|≈|aprox|alrededor)( )?//i;
		${$modifier_ref} = '~';
	}
	elsif (${$value_ref} =~ /(trace|traces|traza|trazas)/i) {
		${$value_ref} = 0;
		${$modifier_ref} = '~';
	}
	# - indicates that there is no value specified on the package
	elsif (${$value_ref} =~ /^\s*$dashes\s*$/) {
		${$value_ref} = undef;
		${$modifier_ref} = '-';
	}

	# Remove extra spaces
	if (defined ${$value_ref}) {
		${$value_ref} =~ s/^\s+//;
		${$value_ref} =~ s/\s+$//;
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

=head2 assign_nid_modifier_value_and_unit ($product_ref, $nid, $modifier, $value, $unit)

Assign a value with a unit and an optional modifier (< or ~) to a nutrient in the nutriments structure.

=head3 Parameters

=head4 $product_ref

=head4 $nid 

Nutrient id, possibly suffixed with "_prepared"

=head4 value

=head4 unit

=cut

sub assign_nid_modifier_value_and_unit ($product_ref, $nid, $modifier, $value, $unit) {

	# Get the nutrient id in the nutrients taxonomy from the nid (without a prefix and possibly suffixed by _prepared)
	my $nutrient_id = "zz:" . $nid;
	$nutrient_id =~ s/_prepared$//;

	# We can have only a modifier with value '-' to indicate that we have no value

	if ((defined $modifier) and ($modifier ne '')) {
		$product_ref->{nutriments}{$nid . "_modifier"} = $modifier;
	}
	else {
		delete $product_ref->{nutriments}{$nid . "_modifier"};
	}

	if ((defined $value) and ($value ne '')) {

		# empty unit?
		if ((not defined $unit) or ($unit eq "")) {
			$unit = default_unit_for_nid($nid);
		}

		$value = convert_string_to_number($value);

		$product_ref->{nutriments}{$nid . "_unit"} = $unit;
		$product_ref->{nutriments}{$nid . "_value"} = $value;
		# Convert values passed in international units IU or % of daily value % DV to the default unit for the nutrient
		if (    ((uc($unit) eq 'IU') or (uc($unit) eq 'UI'))
			and (defined get_property("nutrients", $nutrient_id, "iu_value:en")))
		{
			$value = $value * get_property("nutrients", $nutrient_id, "iu_value:en");
			$unit = get_property("nutrients", $nutrient_id, "unit:en");
		}
		elsif ((uc($unit) eq '% DV') and (defined get_property("nutrients", $nutrient_id, "dv_value:en"))) {
			$value = $value / 100 * get_property("nutrients", $nutrient_id, "dv_value:en");
			$unit = get_property("nutrients", $nutrient_id, "unit:en");
		}

		if ($nid =~ /^water-hardness(_prepared)?$/) {
			$product_ref->{nutriments}{$nid} = unit_to_mmoll($value, $unit) + 0;
		}
		elsif ($nid =~ /^energy-kcal(_prepared)?/) {

			# energy-kcal is stored in kcal
			$product_ref->{nutriments}{$nid} = unit_to_kcal($value, $unit) + 0;
		}
		else {
			$product_ref->{nutriments}{$nid} = unit_to_g($value, $unit) + 0;
		}

	}
	else {
		# We do not have a value for the nutrient
		delete $product_ref->{nutriments}{$nid . "_value"};
		# Delete other fields dervied from the value
		delete $product_ref->{nutriments}{$nid};
		delete $product_ref->{nutriments}{$nid . "_100g"};
		delete $product_ref->{nutriments}{$nid . "_serving"};
		# Delete modifiers (e.g. < sign), unless it is '-' which indicates that the field does not exist on the packaging
		if ((defined $modifier) and ($modifier ne '-')) {
			delete $product_ref->{nutriments}{$nid . "_modifier"};
		}
	}

	return;
}

# For fat, saturated fat, sugars, salt: https://www.diw.de/sixcms/media.php/73/diw_wr_2010-19.pdf
@nutrient_levels = (['fat', 3, 20], ['saturated-fat', 1.5, 5], ['sugars', 5, 12.5], ['salt', 0.3, 1.5],);

#
# -sugars : sub-nutriment
# -- : sub-sub-nutriment
# vitamin-a- : do not show by default in the form
# !proteins : important, always show even if value has not been entered

%cc_nutriment_table = (
	default => "europe",
	ca => "ca",
	ru => "ru",
	us => "us",
	hk => "hk",
	jp => "jp",
);

=head2 %nutriments_tables

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
%nutriments_tables = (
	europe => [
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
			'--polyunsaturated-fat-', '-omega-3-fat-',
			'--alpha-linolenic-acid-', '--eicosapentaenoic-acid-',
			'--docosahexaenoic-acid-', '-omega-6-fat-',
			'--linoleic-acid-', '--arachidonic-acid-',
			'--gamma-linolenic-acid-', '--dihomo-gamma-linolenic-acid-',
			'-omega-9-fat-', '--oleic-acid-',
			'--elaidic-acid-', '--gondoic-acid-',
			'--mead-acid-', '--erucic-acid-',
			'--nervonic-acid-', '-trans-fat-',
			'-cholesterol-', '!carbohydrates',
			'!-sugars', '--added-sugars-',
			'--sucrose-', '--glucose-',
			'--fructose-', '--lactose-',
			'--maltose-', '--maltodextrins-',
			'-starch-', '-polyols-',
			'--erythritol-', '!fiber',
			'-soluble-fiber-', '-insoluble-fiber-',
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
			'taurine-', 'ph-',
			'fruits-vegetables-nuts-', 'fruits-vegetables-nuts-dried-',
			'fruits-vegetables-nuts-estimate-', 'collagen-meat-protein-ratio-',
			'cocoa-', 'chlorophyl-',
			'carbon-footprint-', 'carbon-footprint-from-meat-or-fish-',
			'nutrition-score-fr-', 'nutrition-score-uk-',
			'glycemic-index-', 'water-hardness-',
			'choline-', 'phylloquinone-',
			'beta-glucan-', 'inositol-',
			'carnitine-', 'sulphate-',
			'nitrate-',
		)
	],
	ca => [
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
			'-monounsaturated-fat-', '-polyunsaturated-fat-',
			'-omega-3-fat-', '--alpha-linolenic-acid-',
			'--eicosapentaenoic-acid-', '--docosahexaenoic-acid-',
			'-omega-6-fat-', '--linoleic-acid-',
			'--arachidonic-acid-', '--gamma-linolenic-acid-',
			'--dihomo-gamma-linolenic-acid-', '-omega-9-fat-',
			'--oleic-acid-', '--elaidic-acid-',
			'--gondoic-acid-', '--mead-acid-',
			'--erucic-acid-', '--nervonic-acid-',
			'-trans-fat', 'cholesterol',
			'!carbohydrates', '-fiber',
			'--soluble-fiber-', '--insoluble-fiber-',
			'-sugars', '--added-sugars-',
			'--sucrose-', '--glucose-',
			'--fructose-', '--lactose-',
			'--maltose-', '--maltodextrins-',
			'-starch-', '-polyols-',
			'-erythritol-', '!proteins',
			'-casein-', '-serum-proteins-',
			'-nucleotides-', 'salt',
			'-added-salt-', 'sodium',
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
			'fruits-vegetables-nuts-dried-', 'fruits-vegetables-nuts-estimate-',
			'collagen-meat-protein-ratio-', 'cocoa-',
			'chlorophyl-', 'carbon-footprint-',
			'carbon-footprint-from-meat-or-fish-', 'nutrition-score-fr-',
			'nutrition-score-uk-', 'glycemic-index-',
			'water-hardness-', 'choline-',
			'phylloquinone-', 'beta-glucan-',
			'inositol-', 'carnitine-',
			'sulphate-', 'nitrate-',
		)
	],
	ru => [
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
			'-monounsaturated-fat-', '-polyunsaturated-fat-',
			'-omega-3-fat-', '--alpha-linolenic-acid-',
			'--eicosapentaenoic-acid-', '--docosahexaenoic-acid-',
			'-omega-6-fat-', '--linoleic-acid-',
			'--arachidonic-acid-', '--gamma-linolenic-acid-',
			'--dihomo-gamma-linolenic-acid-', '-omega-9-fat-',
			'--oleic-acid-', '--elaidic-acid-',
			'--gondoic-acid-', '--mead-acid-',
			'--erucic-acid-', '--nervonic-acid-',
			'-trans-fat-', '-cholesterol-',
			'!carbohydrates', '-sugars',
			'--added-sugars-', '--sucrose-',
			'--glucose-', '--fructose-',
			'--lactose-', '--maltose-',
			'--maltodextrins-', '-starch-',
			'-polyols-', '--erythritol-',
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
			'ph-', 'fruits-vegetables-nuts-',
			'fruits-vegetables-nuts-dried-', 'fruits-vegetables-nuts-estimate-',
			'collagen-meat-protein-ratio-', 'cocoa-',
			'chlorophyl-', 'carbon-footprint-',
			'carbon-footprint-from-meat-or-fish-', 'nutrition-score-fr-',
			'nutrition-score-uk-', 'glycemic-index-',
			'water-hardness-', 'choline-',
			'phylloquinone-', 'beta-glucan-',
			'inositol-', 'carnitine-',
			'sulphate-', 'nitrate-',
		)
	],
	us => [
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
			'--melissic-acid-', '-monounsaturated-fat-',
			'-polyunsaturated-fat-', '-omega-3-fat-',
			'--alpha-linolenic-acid-', '--eicosapentaenoic-acid-',
			'--docosahexaenoic-acid-', '-omega-6-fat-',
			'--linoleic-acid-', '--arachidonic-acid-',
			'--gamma-linolenic-acid-', '--dihomo-gamma-linolenic-acid-',
			'-omega-9-fat-', '--oleic-acid-',
			'--elaidic-acid-', '--gondoic-acid-',
			'--mead-acid-', '--erucic-acid-',
			'--nervonic-acid-', '-trans-fat',
			'cholesterol', 'salt-',
			'-added-salt-', 'sodium',
			'!carbohydrates', '-fiber',
			'--soluble-fiber-', '--insoluble-fiber-',
			'-sugars', '--added-sugars',
			'--sucrose-', '--glucose-',
			'--fructose-', '--lactose-',
			'--maltose-', '--maltodextrins-',
			'-starch-', '-polyols-',
			'-erythritol-', '!proteins',
			'-casein-', '-serum-proteins-',
			'-nucleotides-', 'alcohol',
			'#vitamins', 'vitamin-a-',
			'beta-carotene-', 'vitamin-d',
			'vitamin-e-', 'vitamin-k-',
			'vitamin-c-', 'vitamin-b1-',
			'vitamin-b2-', 'vitamin-pp-',
			'vitamin-b6-', 'vitamin-b9-',
			'folates-', 'vitamin-b12-',
			'biotin-', 'pantothenic-acid-',
			'#minerals', 'silica-',
			'bicarbonate-', 'potassium',
			'chloride-', 'calcium',
			'phosphorus-', 'iron',
			'magnesium-', 'zinc-',
			'copper-', 'manganese-',
			'fluoride-', 'selenium-',
			'chromium-', 'molybdenum-',
			'iodine-', 'caffeine-',
			'taurine-', 'ph-',
			'fruits-vegetables-nuts-', 'fruits-vegetables-nuts-dried-',
			'fruits-vegetables-nuts-estimate-', 'collagen-meat-protein-ratio-',
			'cocoa-', 'chlorophyl-',
			'carbon-footprint-', 'carbon-footprint-from-meat-or-fish-',
			'nutrition-score-fr-', 'nutrition-score-uk-',
			'glycemic-index-', 'water-hardness-',
			'sulfate-', 'nitrate-',
		)
	],
	us_before_2017 => [
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
			'-monounsaturated-fat-', '-polyunsaturated-fat-',
			'-omega-3-fat-', '--alpha-linolenic-acid-',
			'--eicosapentaenoic-acid-', '--docosahexaenoic-acid-',
			'-omega-6-fat-', '--linoleic-acid-',
			'--arachidonic-acid-', '--gamma-linolenic-acid-',
			'--dihomo-gamma-linolenic-acid-', '-omega-9-fat-',
			'--oleic-acid-', '--elaidic-acid-',
			'--gondoic-acid-', '--mead-acid-',
			'--erucic-acid-', '--nervonic-acid-',
			'-trans-fat', 'cholesterol',
			'salt-', 'sodium',
			'!carbohydrates', '-fiber',
			'--soluble-fiber-', '--insoluble-fiber-',
			'-sugars', '--sucrose-',
			'--glucose-', '--fructose-',
			'--lactose-', '--maltose-',
			'--maltodextrins-', '-starch-',
			'-polyols-', '--erythritol-',
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
			'fruits-vegetables-nuts-dried-', 'fruits-vegetables-nuts-estimate-',
			'collagen-meat-protein-ratio-', 'cocoa-',
			'chlorophyl-', 'carbon-footprint-',
			'carbon-footprint-from-meat-or-fish-', 'nutrition-score-fr-',
			'nutrition-score-uk-', 'glycemic-index-',
			'water-hardness-', 'choline-',
			'phylloquinone-', 'beta-glucan-',
			'inositol-', 'carnitine-',
			'sulfate-', 'nitrate-',
		)
	],
	hk => [
		(
			'!energy-kj', '!energy-kcal', '!proteins', '!fat',
			'-saturated-fat', '-polyunsaturated-fat-', '-monounsaturated-fat-', '-trans-fat',
			'cholesterol', '!carbohydrates', '-sugars', '-fiber',
			'salt-', 'sodium', '#vitamins', 'vitamin-a',
			'vitamin-d-', 'vitamin-c', 'vitamin-b1-', 'vitamin-b2-',
			'vitamin-pp-', 'vitamin-b6-', 'vitamin-b9-', 'folates-',
			'vitamin-b12-', '#minerals', 'calcium', 'potassium-',
			'phosphorus-', 'iron', 'alcohol', 'nutrition-score-fr-',
			'sulphate-', 'nitrate-',
		)
	],
	jp => [
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
			'--polyunsaturated-fat-', '-omega-3-fat-',
			'--alpha-linolenic-acid-', '--eicosapentaenoic-acid-',
			'--docosahexaenoic-acid-', '-omega-6-fat-',
			'--linoleic-acid-', '--arachidonic-acid-',
			'--gamma-linolenic-acid-', '--dihomo-gamma-linolenic-acid-',
			'-omega-9-fat-', '--oleic-acid-',
			'--elaidic-acid-', '--gondoic-acid-',
			'--mead-acid-', '--erucic-acid-',
			'--nervonic-acid-', '-trans-fat-',
			'cholesterol-', '!carbohydrates',
			'-sugars-', '-fiber-',
			'-soluble-fiber-', '-insoluble-fiber-',
			'!salt', '-added-salt-',
			'#sodium-', 'alcohol',
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
			'taurine-', 'ph-',
			'fruits-vegetables-nuts-', 'fruits-vegetables-nuts-dried-',
			'fruits-vegetables-nuts-estimate-', 'collagen-meat-protein-ratio-',
			'cocoa-', 'chlorophyl-',
			'carbon-footprint-', 'carbon-footprint-from-meat-or-fish-',
			'nutrition-score-fr-', 'nutrition-score-uk-',
			'glycemic-index-', 'water-hardness-',
			'choline-', 'phylloquinone-',
			'beta-glucan-', 'inositol-',
			'carnitine-', 'sulphate-',
			'nitrate-',
		)
	],
);

# Compute the list of nutriments that are not shown by default so that they can be suggested

foreach my $region (keys %nutriments_tables) {

	$nutriments_lists{$region} = [];
	$other_nutriments_lists{$region} = [];

	foreach (@{$nutriments_tables{$region}}) {

		my $nutriment = $_;    # copy instead of alias

		if ($nutriment =~ /-$/) {
			$nutriment = $`;
			$nutriment =~ s/^(-|!)+//g;
			push @{$other_nutriments_lists{$region}}, $nutriment;
		}

		next if $nutriment =~ /\#/;

		$nutriment =~ s/^(-|!)+//g;
		$nutriment =~ s/-$//g;
		push @{$nutriments_lists{$region}}, $nutriment;
	}
}

# nutrient levels

$log->info("Initializing nutrient levels") if $log->is_info();
foreach my $l (@Langs) {

	$lc = $l;
	$lang = $l;

	foreach my $nutrient_level_ref (@nutrient_levels) {
		my ($nid, $low, $high) = @{$nutrient_level_ref};

		foreach my $level ('low', 'moderate', 'high') {
			my $fmt = lang("nutrient_in_quantity");
			my $nutrient_name = display_taxonomy_tag($lc, "nutrients", "zz:$nid");
			my $level_quantity = lang($level . "_quantity");
			if ((not defined $fmt) or (not defined $nutrient_name) or (not defined $level_quantity)) {
				next;
			}

			my $tag = sprintf($fmt, $nutrient_name, $level_quantity);
			my $tagid = get_string_id_for_lang($lc, $tag);
			$canon_tags{$lc}{nutrient_levels}{$tagid} = $tag;
			# print "nutrient_levels : lc: $lc - tagid: $tagid - tag: $tag\n";
		}
	}
}

$log->debug("Nutrient levels initialized") if $log->is_debug();

=head2 canonicalize_nutriment ( $product_ref )

Canonicalizes the nutrients input by the user in the nutrition table product edit. 
This sub converts these nutrients (which are arguments to this function), into a recognizable/standard form.

=head3 Parameters

Two strings are passed,
$target_lc: The language in which the nutriment is (example: "en", "fr")
$nutrient: The nutrient that needs to be canonicalized. (the user input nutrient, example: "AGS", "unsaturated-fat")

=head3 Return values

Returns the $nid (a string)

Example: For the parameter "dont saturés", we get the $nid as "saturated fat"

=cut

sub canonicalize_nutriment ($target_lc, $nutrient) {

	my $nid = canonicalize_taxonomy_tag($target_lc, "nutrients", $nutrient);

	if ($nid =~ /^zz:/) {
		# Recognized nutrients start with zz: -> remove zz: to get the nid
		$nid = $';
	}
	else {
		# Unrecognized nutrients start with the language code (e.g. fr:)
		# -> turn it to fr-
		$nid = get_string_id_for_lang($lc, $nid);
	}
	return $nid;
}

=head2 is_beverage_for_nutrition_score_2021 ( $product_ref )

Determines if a product should be considered as a beverage for Nutri-Score computations,
based on the product categories.

2021 Nutri-Score: Dairy drinks are not considered as beverages if they have at least 80% of milk.

=cut

sub is_beverage_for_nutrition_score_2021 ($product_ref) {

	my $is_beverage = 0;

	if (has_tag($product_ref, "categories", "en:beverages")) {

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

	if (has_tag($product_ref, "categories", "en:beverages")) {

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

=head2 special_process_product ( $ingredients_ref )

Computes food groups, and whether a product is to be considered a beverage for the Nutri-Score.

Ingredients analysis (extract_ingredients_from_text) needs to be done before calling this function?

=cut

sub special_process_product ($product_ref) {

	assign_categories_properties_to_product($product_ref);

	compute_food_groups($product_ref);

	return;
}

sub fix_salt_equivalent ($product_ref) {

	# EU fixes the conversion: sodium = salt / 2.5 (instead of 2.54 previously)

	foreach my $product_type ("", "_prepared") {

		# use the salt value by default
		if (    (defined $product_ref->{nutriments}{'salt' . $product_type . "_value"})
			and ($product_ref->{nutriments}{'salt' . $product_type . "_value"} ne ''))
		{
			assign_nid_modifier_value_and_unit(
				$product_ref,
				'sodium' . $product_type,
				$product_ref->{nutriments}{'salt' . $product_type . '_modifier'},
				$product_ref->{nutriments}{'salt' . $product_type . "_value"} / 2.5,
				$product_ref->{nutriments}{'salt' . $product_type . '_unit'}
			);
		}
		elsif ( (defined $product_ref->{nutriments}{'sodium' . $product_type . "_value"})
			and ($product_ref->{nutriments}{'sodium' . $product_type . "_value"} ne ''))
		{
			assign_nid_modifier_value_and_unit(
				$product_ref,
				'salt' . $product_type,
				$product_ref->{nutriments}{'sodium' . $product_type . '_modifier'},
				$product_ref->{nutriments}{'sodium' . $product_type . "_value"} * 2.5,
				$product_ref->{nutriments}{'sodium' . $product_type . '_unit'}
			);
		}
	}

	return;
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

# Canonicalize the entries, in case the canonical entry changed
foreach my $category_ref (@fruits_vegetables_nuts_by_category_sorted_2021) {
	$category_ref->[0] = canonicalize_taxonomy_tag("en", "categories", $category_ref->[0]);
}

=head2 compute_nutriscore_2021_fruits_vegetables_nuts_colza_walnut_olive_oil($product_ref, $prepared)

Compute the fruit % according to the Nutri-Score rules

<b>Warning</b> Also modifies product_ref->{misc_tags}

=head3 return

The fruit ratio

=cut

sub compute_nutriscore_2021_fruits_vegetables_nuts_colza_walnut_olive_oil ($product_ref, $prepared) {

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

	if (defined $product_ref->{nutriments}{"fruits-vegetables-nuts-dried" . $prepared . "_100g"}) {
		$fruits = 2 * $product_ref->{nutriments}{"fruits-vegetables-nuts-dried" . $prepared . "_100g"};
		add_tag($product_ref, "misc", "en:nutrition-fruits-vegetables-nuts-dried");

		if (defined $product_ref->{nutriments}{"fruits-vegetables-nuts" . $prepared . "_100g"}) {
			$fruits += $product_ref->{nutriments}{"fruits-vegetables-nuts" . $prepared . "_100g"};
			add_tag($product_ref, "misc", "en:nutrition-fruits-vegetables-nuts");
		}

		$fruits
			= $fruits * 100 / (100 + $product_ref->{nutriments}{"fruits-vegetables-nuts-dried" . $prepared . "_100g"});
	}
	elsif (defined $product_ref->{nutriments}{"fruits-vegetables-nuts" . $prepared . "_100g"}) {
		$fruits = $product_ref->{nutriments}{"fruits-vegetables-nuts" . $prepared . "_100g"};
		add_tag($product_ref, "misc", "en:nutrition-fruits-vegetables-nuts");
	}
	elsif (defined $product_ref->{nutriments}{"fruits-vegetables-nuts-estimate" . $prepared . "_100g"}) {
		$fruits = $product_ref->{nutriments}{"fruits-vegetables-nuts-estimate" . $prepared . "_100g"};
		$product_ref->{nutrition_score_warning_fruits_vegetables_nuts_estimate} = 1;
		add_tag($product_ref, "misc", "en:nutrition-fruits-vegetables-nuts-estimate");
	}
	# Use the estimate from the ingredients list if we have one
	elsif (
			(not defined $fruits)
		and
		(defined $product_ref->{nutriments}{"fruits-vegetables-nuts-estimate-from-ingredients" . $prepared . "_100g"})
		)
	{
		$fruits = $product_ref->{nutriments}{"fruits-vegetables-nuts-estimate-from-ingredients" . $prepared . "_100g"};
		$product_ref->{nutrition_score_warning_fruits_vegetables_nuts_estimate_from_ingredients} = 1;
		$product_ref->{nutrition_score_warning_fruits_vegetables_nuts_estimate_from_ingredients_value} = $fruits;
		add_tag($product_ref, "misc", "en:nutrition-fruits-vegetables-nuts-estimate-from-ingredients");
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

# Canonicalize the entries, in case the canonical entry changed
foreach my $category_ref (@fruits_vegetables_legumes_by_category_if_no_ingredients_specified_sorted) {
	$category_ref->[0] = canonicalize_taxonomy_tag("en", "categories", $category_ref->[0]);
}

=head2 compute_nutriscore_2023_fruits_vegetables_legumes($product_ref, $prepared)

Compute the % of fruits, vegetables and legumes for the Nutri-Score 2023 algorithm.

Differences with the 2021 version:
- we use only the estimate from the ingredients or a conservative estimate from the product category
- we do not use values estimated by users from ingredients list: too difficult to know what should be included or not

=head3 Arguments

=head4 $product_ref - ref to the product

=head4 $prepared - string contains either "" or "-prepared"

=cut

sub compute_nutriscore_2023_fruits_vegetables_legumes ($product_ref, $prepared) {

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

	my $fruits_vegetables_legumes = deep_get($product_ref, "nutriments",
		"fruits-vegetables-legumes-estimate-from-ingredients" . $prepared . "_100g");

	# First get a conservative estimate from the ingredients list
	if (defined $fruits_vegetables_legumes) {
		$product_ref->{nutrition_score_warning_fruits_vegetables_legumes_estimate_from_ingredients} = 1;
		$product_ref->{nutrition_score_warning_fruits_vegetables_legumes_estimate_from_ingredients_value}
			= $fruits_vegetables_legumes;
		add_tag($product_ref, "misc", "en:nutrition-fruits-vegetables-legumes-estimate-from-ingredients");
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

=head2 saturated_fat_ratio( $nutriments_ref, $prepared )

Compute saturated_fat_ratio as needed for nutriscore

=head3 Arguments

=head4 $nutriments_ref - ref to the nutriments of a product

Reference to either the "nutriments" or "nutriments_estimated" structure.

=head4 $prepared - string contains either "" or "prepared"

=cut

sub saturated_fat_ratio ($nutriments_ref, $prepared) {

	my $saturated_fat = $nutriments_ref->{"saturated-fat" . $prepared . "_100g"};
	my $fat = $nutriments_ref->{"fat" . $prepared . "_100g"};
	my $saturated_fat_ratio = 0;
	if ((defined $saturated_fat) and ($saturated_fat > 0)) {
		if ($fat <= 0) {
			$fat = $saturated_fat;
		}
		$saturated_fat_ratio = $saturated_fat / $fat * 100;    # in %
	}
	return $saturated_fat_ratio;
}

=head2 saturated_fat_0_because_of_fat_0($nutriments_ref, $prepared)

Detect if we are in the special case where we can detect saturated fat is 0 because fat is 0

=head3 Arguments

=head4 $nutriments_ref - ref to the nutriments of a product

Reference to either the "nutriments" or "nutriments_estimated" structure.

=head4 $prepared - string contains either "" or "prepared"

=cut

sub saturated_fat_0_because_of_fat_0 ($nutriments_ref, $prepared) {
	my $fat = $nutriments_ref->{"fat" . $prepared . "_100g"};
	return ((!defined $nutriments_ref->{"saturated-fat" . $prepared . "_100g"}) && (defined $fat) && ($fat == 0));
}

=head2 sugar_0_because_of_carbohydrates_0($nutriments_ref, $prepared) {

Detect if we are in the special case where we can detect sugars are 0 because carbohydrates are 0

=head3 Arguments

=head4 $nutriments_ref - ref to the nutriments of a product

Reference to either the "nutriments" or "nutriments_estimated" structure.

=head4 $prepared - string contains either "" or "prepared"

=cut

sub sugar_0_because_of_carbohydrates_0 ($nutriments_ref, $prepared) {
	my $carbohydrates = $nutriments_ref->{"carbohydrates" . $prepared . "_100g"};
	return (   (!defined $nutriments_ref->{"sugars" . $prepared . "_100g"})
			&& (defined $carbohydrates)
			&& ($carbohydrates == 0));
}

=head2 compute_nutriscore_data( $products_ref, $prepared, $nutriments_field )

Compute data for nutriscore computation.

<b>Warning:</b> it also modifies $product_ref

=head3 Arguments

=head4 $nutriments_ref - ref to the nutriments of a product

Reference to either the "nutriments" or "nutriments_estimated" structure.

=head4 $prepared - string contains either "" or "prepared"

=head4 $fruits - float - fruit % estimation

=head4

=head3 return

Ref to a mapping suitable to call compute_nutriscore_score_and_grade

=cut

sub compute_nutriscore_data ($product_ref, $prepared, $nutriments_field, $version = "2021") {

	my $nutriments_ref = $product_ref->{$nutriments_field};

	my $nutriscore_data_ref;

	# The 2021 and 2023 version of the Nutri-Score need different nutrients
	if ($version eq "2021") {
		# fruits, vegetables, nuts, olive / rapeseed / walnut oils - 2021
		my $fruits_vegetables_nuts_colza_walnut_olive_oils
			= compute_nutriscore_2021_fruits_vegetables_nuts_colza_walnut_olive_oil($product_ref, $prepared);

		my $is_fat = is_fat_for_nutrition_score($product_ref);

		$nutriscore_data_ref = {
			is_beverage => $product_ref->{nutrition_score_beverage},
			is_water => is_water_for_nutrition_score($product_ref),
			is_cheese => is_cheese_for_nutrition_score($product_ref),
			is_fat => $is_fat,

			energy => $nutriments_ref->{"energy" . $prepared . "_100g"},
			sugars => $nutriments_ref->{"sugars" . $prepared . "_100g"},
			saturated_fat => $nutriments_ref->{"saturated-fat" . $prepared . "_100g"},
			sodium => (
				(defined $nutriments_ref->{"sodium" . $prepared . "_100g"})
				? $nutriments_ref->{"sodium" . $prepared . "_100g"} * 1000
				: undef
			),    # in mg,

			fruits_vegetables_nuts_colza_walnut_olive_oils => $fruits_vegetables_nuts_colza_walnut_olive_oils,
			fiber => (
				(defined $nutriments_ref->{"fiber" . $prepared . "_100g"})
				? $nutriments_ref->{"fiber" . $prepared . "_100g"}
				: 0
			),
			proteins => $nutriments_ref->{"proteins" . $prepared . "_100g"},
		};

		if ($is_fat) {
			# Add the fat and saturated fat / fat ratio
			$nutriscore_data_ref->{fat} = $nutriments_ref->{"fat" . $prepared . "_100g"};
			$nutriscore_data_ref->{saturated_fat_ratio} = saturated_fat_ratio($nutriments_ref, $prepared);
		}
	}
	else {
		# fruits, vegetables, legumes - 2023
		my $fruits_vegetables_legumes = compute_nutriscore_2023_fruits_vegetables_legumes($product_ref, $prepared);

		my $is_fat_oil_nuts_seeds = is_fat_oil_nuts_seeds_for_nutrition_score($product_ref);
		my $is_beverage = is_beverage_for_nutrition_score_2023($product_ref);

		$nutriscore_data_ref = {
			is_beverage => $is_beverage,
			is_water => is_water_for_nutrition_score($product_ref),
			is_cheese => is_cheese_for_nutrition_score($product_ref),
			is_fat_oil_nuts_seeds => $is_fat_oil_nuts_seeds,
			is_red_meat_product => is_red_meat_product_for_nutrition_score($product_ref),

			energy => $nutriments_ref->{"energy" . $prepared . "_100g"},
			sugars => $nutriments_ref->{"sugars" . $prepared . "_100g"},
			saturated_fat => $nutriments_ref->{"saturated-fat" . $prepared . "_100g"},
			salt => $nutriments_ref->{"salt" . $prepared . "_100g"},

			fruits_vegetables_legumes => $fruits_vegetables_legumes,
			fiber => (
				(defined $nutriments_ref->{"fiber" . $prepared . "_100g"})
				? $nutriments_ref->{"fiber" . $prepared . "_100g"}
				: 0
			),
			proteins => $nutriments_ref->{"proteins" . $prepared . "_100g"},
		};

		if ($is_fat_oil_nuts_seeds) {
			# Add the fat and saturated fat / fat ratio
			$nutriscore_data_ref->{fat} = $nutriments_ref->{"fat" . $prepared . "_100g"};
			$nutriscore_data_ref->{saturated_fat_ratio} = saturated_fat_ratio($nutriments_ref, $prepared);
			# Compute the energy from saturates
			if (defined $nutriscore_data_ref->{saturated_fat}) {
				$nutriscore_data_ref->{energy_from_saturated_fat} = $nutriscore_data_ref->{saturated_fat} * 37;
			}
		}

		if ($is_beverage) {
			if (defined $product_ref->{with_non_nutritive_sweeteners}) {
				$nutriscore_data_ref->{with_non_nutritive_sweeteners} = $product_ref->{with_non_nutritive_sweeteners};
			}
		}
	}

	# tweak data to take into account special cases

	# if sugar is undefined but carbohydrates is 0, set sugars to 0
	if (sugar_0_because_of_carbohydrates_0($nutriments_ref, $prepared)) {
		$nutriscore_data_ref->{sugars} = 0;
	}
	# if saturated_fat is undefined but fat is 0, set saturated_fat to 0
	# as well as saturated_fat_ratio
	if (saturated_fat_0_because_of_fat_0($nutriments_ref, $prepared)) {
		$nutriscore_data_ref->{saturated_fat} = 0;
		$nutriscore_data_ref->{saturated_fat_ratio} = 0;
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

	# strip nutriments / score-type fields from the product
	remove_fields(
		$product_ref->{nutriments},
		[
			"nutrition-score", "nutrition-score_100g",
			"nutrition-score_serving", "nutrition-score-fr",
			"nutrition-score-fr_100g", "nutrition-score-fr_serving",
			"nutrition-score-uk", "nutrition-score-uk_100g",
			"nutrition-score-uk_serving"
		]
	);

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

=head2 check_availability_of_nutrients_needed_for_nutriscore ($product_ref)

Check that we know or can estimate the nutrients needed to compute the Nutri-Score of the product.

=head3 Return values

=head4 $nutrients_available 0 or 1

=head4 $prepared "" or "_prepared"

Suffix to indicate if the Nutri-Score should be computed on prepared values

=head4 $nutriments_field "nutriments" or "nutriments_estimated"

Indicates which nutrients fields were used to compute the Nutri-Score.

=cut

sub check_availability_of_nutrients_needed_for_nutriscore ($product_ref) {

	my $nutrients_available = 1;

	# do not compute a score for dehydrated products to be rehydrated (e.g. dried soups, powder milk)
	# unless we have nutrition data for the prepared product
	# same for en:chocolate-powders, en:dessert-mixes and en:flavoured-syrups

	my $prepared = '';

	foreach my $category_tag (
		"en:dried-products-to-be-rehydrated", "en:cocoa-and-chocolate-powders",
		"en:dessert-mixes", "en:flavoured-syrups",
		"en:instant-beverages"
		)
	{

		if (has_tag($product_ref, "categories", $category_tag)) {

			if ((defined $product_ref->{nutriments}{"energy_prepared_100g"})) {
				$product_ref->{nutrition_score_debug}
					= "using prepared product data for category $category_tag" . " - ";
				$prepared = '_prepared';
				add_tag($product_ref, "misc", "en:nutrition-grade-computed-for-prepared-product");
			}
			else {
				$product_ref->{"nutrition_grades_tags"} = ["unknown"];
				$product_ref->{nutrition_score_debug}
					= "no score for category $category_tag without data for prepared product" . " - ";
				add_tag($product_ref, "misc", "en:nutriscore-missing-prepared-nutrition-data");
				$nutrients_available = 0;
			}
			last;
		}
	}

	# Track the number of key nutrients present
	my $key_nutrients = 0;

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
		# foreach my $nid ("energy", "saturated-fat", "sugars", "sodium", "fiber", "proteins") {

		foreach my $nid ("energy", "fat", "saturated-fat", "sugars", "sodium", "proteins") {
			# If we don't set the 100g figure then this should flag the item as not enough data
			if (not defined $product_ref->{nutriments}{$nid . $prepared . "_100g"}) {
				# we have two special case where we can deduce data
				next
					if (
					(
						($nid eq "saturated-fat")
						&& saturated_fat_0_because_of_fat_0($product_ref->{nutriments}, $prepared)
					)
					|| (($nid eq "sugars") && sugar_0_because_of_carbohydrates_0($product_ref->{nutriments}, $prepared))
					);
				$product_ref->{"nutrition_grades_tags"} = ["unknown"];
				add_tag($product_ref, "misc", "en:nutrition-not-enough-data-to-compute-nutrition-score");
				$product_ref->{nutrition_score_debug} .= "missing " . $nid . $prepared . "_100g - ";
				add_tag($product_ref, "misc", "en:nutriscore-missing-nutrition-data");
				add_tag($product_ref, "misc", "en:nutriscore-missing-nutrition-data-$nid");
				$nutrients_available = 0;
			}
			else {
				$key_nutrients++;
			}
		}

		# some categories of products do not have fibers > 0.7g (e.g. sodas)
		# for others, display a warning when the value is missing
		# do not display a warning if fibers are not specified on the product ('-' modifier)
		if (    (not defined $product_ref->{nutriments}{"fiber" . $prepared . "_100g"})
			and (not defined $product_ref->{nutriments}{"fiber" . $prepared . "_modifier"})
			and not(has_tag($product_ref, "categories", "en:sodas")))
		{
			$product_ref->{nutrition_score_warning_no_fiber} = 1;
			add_tag($product_ref, "misc", "en:nutrition-no-fiber");
		}
	}

	# Remove ending -
	$product_ref->{nutrition_score_debug} =~ s/ - $//;

	# By default we use the "nutriments" hash as a source (specified nutrients),
	# but if we don't have specified nutrients, we can use use the "nutriments_estimated" hash if it exists.
	# If we have some specified nutrients but are missing required nutrients for the Nutri-Score,
	# we do not use estimated nutrients, in order to encourage users to complete the nutrition facts
	# (that we know exist, and that we may even have a photo for).
	# If we don't have nutrients at all (or the no nutriments checkbox is checked),
	# we can use estimated nutrients for the Nutri-Score.
	my $nutriments_field = "nutriments";

	if (    (defined $product_ref->{"nutrition_grades_tags"})
		and (($product_ref->{"nutrition_grades_tags"}[0] eq "unknown"))
		and (($key_nutrients == 0) or ($product_ref->{no_nutrition_data}))
		and ($prepared eq '')
		and (defined $product_ref->{nutriments_estimated}))
	{
		$nutriments_field = "nutriments_estimated";
		$product_ref->{nutrition_score_warning_nutriments_estimated} = 1;
		add_tag($product_ref, "misc", "en:nutriscore-using-estimated-nutrition-facts");
		$product_ref->{"nutrition_grades_tags"} = [];

		# Delete the warning for missing fiber, as we will get fiber from the estimate
		delete $product_ref->{nutrition_score_warning_no_fiber};

		$nutrients_available = 1;
	}

	return ($nutrients_available, $prepared, $nutriments_field);
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

		# Fields used to display the Nutri-Score score inside nutrition facts table
		# and to compute averages etc. for categories
		$product_ref->{nutriments}{"nutrition-score-fr_100g"} = $nutriscore_score;
		$product_ref->{nutriments}{"nutrition-score-fr"} = $nutriscore_score;

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

=head2 compute_nutriscore( $product_ref )

Determines if we have enough data to compute the Nutri-Score (category + nutrition facts),
and if the Nutri-Score is applicable to the product the category.

Populates the data structure needed to compute the Nutri-Score and computes it.

=cut

sub compute_nutriscore ($product_ref, $current_version = "2021") {

	# Initialize values

	$product_ref->{nutrition_score_debug} = '';

	# Remove any previously existing Nutri-Score related fields
	remove_nutriscore_fields($product_ref);

	my ($category_available, $nutriscore_applicable, $not_applicable_category)
		= is_nutriscore_applicable_to_the_product_categories($product_ref);

	my ($nutrients_available, $prepared, $nutriments_field)
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
			}
		);

		if (defined $not_applicable_category) {
			deep_set($product_ref, "nutriscore", $version, "not_applicable_category", $not_applicable_category);
		}

		# Populate the data structure that will be passed to Food::Nutriscore
		deep_set($product_ref, "nutriscore", $version, "data",
			compute_nutriscore_data($product_ref, $prepared, $nutriments_field, $version));

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

sub compute_serving_size_data ($product_ref) {

	# identify products that do not have comparable nutrition data
	# e.g. products with multiple nutrition facts tables
	# except in some cases like breakfast cereals
	# bug #1145
	# old

	# Delete old fields
	(defined $product_ref->{not_comparable_nutrition_data}) and delete $product_ref->{not_comparable_nutrition_data};
	(defined $product_ref->{multiple_nutrition_data}) and delete $product_ref->{multiple_nutrition_data};

	(defined $product_ref->{product_quantity}) and delete $product_ref->{product_quantity};
	if ((defined $product_ref->{quantity}) and ($product_ref->{quantity} ne "")) {
		my $product_quantity = normalize_quantity($product_ref->{quantity});
		if (defined $product_quantity) {
			$product_ref->{product_quantity} = $product_quantity;
		}
	}

	if ((defined $product_ref->{serving_size}) and ($product_ref->{serving_size} ne "")) {
		$product_ref->{serving_quantity} = normalize_serving_size($product_ref->{serving_size});
	}
	else {
		(defined $product_ref->{serving_quantity}) and delete $product_ref->{serving_quantity};
		(defined $product_ref->{serving_size})
			and ($product_ref->{serving_size} eq "")
			and delete $product_ref->{serving_size};
	}

	# Record if we have nutrient values for as sold or prepared types,
	# so that we can check the nutrition_data and nutrition_data_prepared boxes if we have data
	my %nutrition_data = ();
	my $serving_quantity = $product_ref->{serving_quantity};

	foreach my $product_type ("", "_prepared") {

		# Energy
		# Before November 2019, we only had one energy field with an input value in kJ or in kcal, and internally it was converted to kJ
		# In Europe, the energy is indicated in both kJ and kcal, but there isn't a straightforward conversion between the 2: the energy is computed
		# by summing some nutrients multiplied by an energy factor. That means we need to store both the kJ and kcal values.
		# see bug https://github.com/openfoodfacts/openfoodfacts-server/issues/2396

		# If we have a value for energy-kj, use it for energy
		if (defined $product_ref->{nutriments}{"energy-kj" . $product_type . "_value"}) {
			if (not defined $product_ref->{nutriments}{"energy-kj" . $product_type . "_unit"}) {
				$product_ref->{nutriments}{"energy-kj" . $product_type . "_unit"} = "kJ";
			}
			assign_nid_modifier_value_and_unit(
				$product_ref,
				"energy" . $product_type,
				$product_ref->{nutriments}{"energy-kj" . $product_type . "_modifier"},
				$product_ref->{nutriments}{"energy-kj" . $product_type . "_value"},
				$product_ref->{nutriments}{"energy-kj" . $product_type . "_unit"}
			);
		}
		# Otherwise use the energy-kcal value for energy
		elsif (defined $product_ref->{nutriments}{"energy-kcal" . $product_type}) {
			if (not defined $product_ref->{nutriments}{"energy-kcal" . $product_type . "_unit"}) {
				$product_ref->{nutriments}{"energy-kcal" . $product_type . "_unit"} = "kcal";
			}
			assign_nid_modifier_value_and_unit(
				$product_ref,
				"energy" . $product_type,
				$product_ref->{nutriments}{"energy-kcal" . $product_type . "_modifier"},
				$product_ref->{nutriments}{"energy-kcal" . $product_type . "_value"},
				$product_ref->{nutriments}{"energy-kcal" . $product_type . "_unit"}
			);
		}
		# Otherwise, if we have a value and a unit for the energy field, copy it to either energy-kj or energy-kcal
		elsif ( (defined $product_ref->{nutriments}{"energy" . $product_type . "_value"})
			and (defined $product_ref->{nutriments}{"energy" . $product_type . "_unit"}))
		{

			my $unit = lc($product_ref->{nutriments}{"energy" . $product_type . "_unit"});

			assign_nid_modifier_value_and_unit(
				$product_ref,
				"energy-$unit" . $product_type,
				$product_ref->{nutriments}{"energy" . $product_type . "_modifier"},
				$product_ref->{nutriments}{"energy" . $product_type . "_value"},
				$product_ref->{nutriments}{"energy" . $product_type . "_unit"}
			);
		}

		if (not defined $product_ref->{"nutrition_data" . $product_type . "_per"}) {
			$product_ref->{"nutrition_data" . $product_type . "_per"} = '100g';
		}

		if ($product_ref->{"nutrition_data" . $product_type . "_per"} eq 'serving') {

			foreach my $nid (keys %{$product_ref->{nutriments}}) {
				if (   ($product_type eq "") and ($nid =~ /_/)
					or (($product_type eq "_prepared") and ($nid !~ /_prepared$/)))
				{

					next;
				}
				$nid =~ s/_prepared$//;

				my $value = $product_ref->{nutriments}{$nid . $product_type};
				$product_ref->{nutriments}{$nid . $product_type . "_serving"} = $value;
				$product_ref->{nutriments}{$nid . $product_type . "_serving"}
					=~ s/^(<|environ|max|maximum|min|minimum)( )?//;
				$product_ref->{nutriments}{$nid . $product_type . "_serving"} += 0.0;
				delete $product_ref->{nutriments}{$nid . $product_type . "_100g"};

				my $unit = get_property("nutrients", "zz:$nid", "unit:en")
					;    # $unit will be undef if the nutrient is not in the taxonomy
				print STDERR "nid: $nid - unit: $unit\n";

				# If the nutrient has no unit (e.g. pH), or is a % (e.g. "% vol" for alcohol), it is the same regardless of quantity
				# otherwise we adjust the value for 100g
				if ((defined $unit) and (($unit eq '') or ($unit =~ /^\%/))) {
					$product_ref->{nutriments}{$nid . $product_type . "_100g"} = $value + 0.0;
				}
				# Don't adjust the value for 100g if the serving quantity is 5 or less
				elsif ((defined $serving_quantity) and ($serving_quantity > 5)) {
					$product_ref->{nutriments}{$nid . $product_type . "_100g"}
						= sprintf("%.2e", $value * 100.0 / $product_ref->{serving_quantity}) + 0.0;

					# Record that we have a nutrient value for this product type (with a unit, not NOVA, alcohol % etc.)
					$nutrition_data{$product_type} = 1;
				}

			}
		}
		else {

			foreach my $nid (keys %{$product_ref->{nutriments}}) {
				if (   ($product_type eq "") and ($nid =~ /_/)
					or (($product_type eq "_prepared") and ($nid !~ /_prepared$/)))
				{

					next;
				}
				$nid =~ s/_prepared$//;

				$product_ref->{nutriments}{$nid . $product_type . "_100g"}
					= $product_ref->{nutriments}{$nid . $product_type};
				$product_ref->{nutriments}{$nid . $product_type . "_100g"}
					=~ s/^(<|environ|max|maximum|min|minimum)( )?//;
				$product_ref->{nutriments}{$nid . $product_type . "_100g"} += 0.0;
				delete $product_ref->{nutriments}{$nid . $product_type . "_serving"};

				my $unit = get_property("nutrients", "zz:$nid", "unit:en")
					;    # $unit will be undef if the nutrient is not in the taxonomy

				# If the nutrient has no unit (e.g. pH), or is a % (e.g. "% vol" for alcohol), it is the same regardless of quantity
				# otherwise we adjust the value for the serving quantity
				if ((defined $unit) and (($unit eq '') or ($unit =~ /^\%/))) {
					$product_ref->{nutriments}{$nid . $product_type . "_serving"}
						= $product_ref->{nutriments}{$nid . $product_type} + 0.0;
				}
				elsif ((defined $product_ref->{serving_quantity}) and ($product_ref->{serving_quantity} > 0)) {

					$product_ref->{nutriments}{$nid . $product_type . "_serving"} = sprintf("%.2e",
						$product_ref->{nutriments}{$nid . $product_type} / 100.0 * $product_ref->{serving_quantity})
						+ 0.0;

					# Record that we have a nutrient value for this product type (with a unit, not NOVA, alcohol % etc.)
					$nutrition_data{$product_type} = 1;
				}

			}

		}

		# Carbon footprint

		if (defined $product_ref->{nutriments}{"carbon-footprint-from-meat-or-fish_100g"}) {

			if (defined $product_ref->{serving_quantity}) {
				$product_ref->{nutriments}{"carbon-footprint-from-meat-or-fish_serving"} = sprintf("%.2e",
						  $product_ref->{nutriments}{"carbon-footprint-from-meat-or-fish_100g"} / 100.0
						* $product_ref->{serving_quantity}) + 0.0;
			}

			if (defined $product_ref->{product_quantity}) {
				$product_ref->{nutriments}{"carbon-footprint-from-meat-or-fish_product"} = sprintf("%.2e",
						  $product_ref->{nutriments}{"carbon-footprint-from-meat-or-fish_100g"} / 100.0
						* $product_ref->{product_quantity}) + 0.0;
			}
		}

		if (defined $product_ref->{nutriments}{"carbon-footprint-from-known-ingredients_100g"}) {

			if (defined $product_ref->{serving_quantity}) {
				$product_ref->{nutriments}{"carbon-footprint-from-known-ingredients_serving"} = sprintf("%.2e",
						  $product_ref->{nutriments}{"carbon-footprint-from-known-ingredients_100g"} / 100.0
						* $product_ref->{serving_quantity}) + 0.0;
			}

			if (defined $product_ref->{product_quantity}) {
				$product_ref->{nutriments}{"carbon-footprint-from-known-ingredients_product"} = sprintf("%.2e",
						  $product_ref->{nutriments}{"carbon-footprint-from-known-ingredients_100g"} / 100.0
						* $product_ref->{product_quantity}) + 0.0;
			}
		}
	}

	# If we have nutrient data for as sold or prepared, make sure the checkbox are ticked
	foreach my $product_type (sort keys %nutrition_data) {
		if (   (not defined $product_ref->{"nutrition_data" . $product_type})
			or ($product_ref->{"nutrition_data" . $product_type} ne "on"))
		{
			$product_ref->{"nutrition_data" . $product_type} = 'on';
		}
	}

	return;
}

sub compute_unknown_nutrients ($product_ref) {

	$product_ref->{unknown_nutrients_tags} = [];

	foreach my $nid (keys %{$product_ref->{nutriments}}) {

		next if $nid =~ /_/;

		if ((not exists_taxonomy_tag("nutrients", "zz:$nid")) and (defined $product_ref->{nutriments}{$nid . "_label"}))
		{
			push @{$product_ref->{unknown_nutrients_tags}}, $nid;
		}
	}

	return;
}

sub compute_nutrient_levels ($product_ref) {

	#$product_ref->{nutrient_levels_debug} .= " -- start ";

	$product_ref->{nutrient_levels_tags} = [];
	$product_ref->{nutrient_levels} = {};

	return
		if ((not defined $product_ref->{categories}) or ($product_ref->{categories} eq ''))
		;    # need categories hierarchy in order to identify drinks

	# do not compute a score for dehydrated products to be rehydrated (e.g. dried soups, powder milk)
	# unless we have nutrition data for the prepared product

	my $prepared = "";

	if (has_tag($product_ref, "categories", "en:dried-products-to-be-rehydrated")) {

		if ((defined $product_ref->{nutriments}{"energy_prepared_100g"})) {
			$prepared = '_prepared';
		}
		else {
			return;
		}
	}

	# do not compute a score for coffee, tea etc.

	if (defined $options{categories_exempted_from_nutrient_levels}) {

		foreach my $category_id (@{$options{categories_exempted_from_nutrient_levels}}) {

			if (has_tag($product_ref, "categories", $category_id)) {
				$product_ref->{"nutrition_grades_tags"} = ["not-applicable"];
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

		if (    (defined $product_ref->{nutriments}{$nid . $prepared . "_100g"})
			and ($product_ref->{nutriments}{$nid . $prepared . "_100g"} ne ''))
		{

			if ($product_ref->{nutriments}{$nid . $prepared . "_100g"} < $low) {
				$product_ref->{nutrient_levels}{$nid} = 'low';
			}
			elsif ($product_ref->{nutriments}{$nid . $prepared . "_100g"} > $high) {
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
		#$product_ref->{nutrient_levels_debug} .= " -- nid: $nid - low: $low - high: $high - level: " . $product_ref->{nutrient_levels}{$nid} . " -- value: " . $product_ref->{nutriments}{$nid . "_100g"} . " --- ";

	}

	return;
}

=head2 create_nutrients_level_taxonomy ()

C<create_nutrients_level_taxonomy()> creates the source file for the nutrients level
taxonomy: /taxonomies/nutrient_levels.txt

It creates entries such as "High in saturated fat" in all languages.

=cut

sub create_nutrients_level_taxonomy() {

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

	open(my $OUT, ">:encoding(UTF-8)", "$data_root/taxonomies/nutrient_levels.txt");
	print $OUT <<TXT
# nutrient levels taxonomy generated automatically by Food.pm

TXT
		;
	print $OUT $nutrient_levels_taxonomy;
	close $OUT;

	return;
}

=head2 compute_units_of_alcohol ($product_ref, $serving_size_in_ml)

calculate the number of units of alcohol in one serving of an alcoholic beverage.
(https://en.wikipedia.org/wiki/Unit_of_alcohol)

=cut

sub compute_units_of_alcohol ($product_ref, $serving_size_in_ml) {

	if (    (defined $product_ref)
		and (defined $serving_size_in_ml)
		and (defined $product_ref->{nutriments}{'alcohol'})
		and (has_tag($product_ref, 'categories', 'en:alcoholic-beverages')))
	{
		return $serving_size_in_ml * ($product_ref->{nutriments}{'alcohol'} / 1000.0);
	}
	else {
		return;
	}
}

sub compare_nutriments ($a_ref, $b_ref) {

	# $a_ref can be a product, a category, ajr etc. -> needs {nutriments}{$nid} values

	my %nutriments = ();

	foreach my $nid (keys %{$b_ref->{nutriments}}) {
		next if $nid !~ /_100g$/;
		$log->trace("compare_nutriments", {nid => $nid}) if $log->is_trace();
		if ($b_ref->{nutriments}{$nid} ne '') {
			$nutriments{$nid} = $b_ref->{nutriments}{$nid};
			if (    ($b_ref->{nutriments}{$nid} > 0)
				and (defined $a_ref->{nutriments}{$nid})
				and ($a_ref->{nutriments}{$nid} ne ''))
			{
				$nutriments{"${nid}_%"}
					= ($a_ref->{nutriments}{$nid} - $b_ref->{nutriments}{$nid}) / $b_ref->{nutriments}{$nid} * 100;
			}
			$log->trace("compare_nutriments",
				{nid => $nid, value => $nutriments{$nid}, percent => $nutriments{"$nid.%"}})
				if $log->is_trace();
		}
	}

	return \%nutriments;

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
	remove_fields($product_ref->{nutriments}, ["nova-group", "nova-group_100g", "nova-group_serving"]);

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

	$product_ref->{nutriments}{"nova-group"} = $product_ref->{nova_group};
	$product_ref->{nutriments}{"nova-group_100g"} = $product_ref->{nova_group};
	$product_ref->{nutriments}{"nova-group_serving"} = $product_ref->{nova_group};

	# Store nova_groups as a string

	$product_ref->{nova_groups} = $product_ref->{nova_group};
	$product_ref->{nova_groups} .= "";
	$product_ref->{nova_groups_tags} = [canonicalize_taxonomy_tag("en", "nova_groups", $product_ref->{nova_groups})];

	# Keep the ingredients / categories markers for the resulting nova group
	$product_ref->{nova_groups_markers} = \%nova_groups_markers;

	return;
}

sub extract_nutrition_from_image ($product_ref, $id, $ocr_engine, $results_ref) {

	extract_text_from_image($product_ref, $id, "nutrition_text_from_image", $ocr_engine, $results_ref);

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

=head2 assign_nutriments_values_from_request_parameters ( $product_ref, $nutriment_table, $can_edit_owner_fields )

This function reads the nutriment values passed to the product edit form, or the product edit API,
and assigns them to the product.

=cut

sub assign_nutriments_values_from_request_parameters ($product_ref, $nutriment_table, $can_edit_owner_fields = 0) {

	# Nutrition data

	$log->debug("Nutrition data") if $log->is_debug();

	# Note: browsers do not send any value for checkboxes that are unchecked,
	# so the web form also has a field (suffixed with _displayed) to allow us to uncheck the box.

	# API:
	# - check: no_nutrition_data is passed "on" or 1
	# - uncheck: no_nutrition_data is passed an empty value ""
	# - no action: the no_nutrition_data field is not sent, and no_nutrition_data_displayed is not sent
	#
	# Web:
	# - check: no_nutrition_data is passed "on"
	# - uncheck: no_nutrition_data is not sent but no_nutrition_data_displayed is sent

	foreach my $checkbox ("no_nutrition_data", "nutrition_data", "nutrition_data_prepared") {

		if (defined single_param($checkbox)) {
			$product_ref->{$checkbox} = remove_tags_and_quote(decode utf8 => single_param($checkbox));
		}
		elsif (defined single_param($checkbox . "_displayed")) {
			$product_ref->{$checkbox} = "";
		}
	}

	# Assign all the nutrient values

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
			$log->debug("unknown_nutriment", {nid => $nid}) if $log->is_debug();
		}
	}

	# It is possible to add nutrients that we do not know about
	# by using parameters like new_0, new_1 etc.
	my @new_nutriments = ();
	my $new_max = remove_tags_and_quote(single_param('new_max')) || 0;
	for (my $i = 1; $i <= $new_max; $i++) {
		push @new_nutriments, "new_$i";
	}

	# If we have only 1 of the salt and sodium values,
	# delete any existing values for the other one,
	# and it will be computed from the one we have
	foreach my $product_type ("", "_prepared") {
		my $saltnid = "salt${product_type}";
		my $sodiumnid = "sodium${product_type}";

		my $salt = single_param("nutriment_${saltnid}");
		my $sodium = single_param("nutriment_${sodiumnid}");

		if ((defined $sodium) and (not defined $salt)) {
			delete $product_ref->{nutriments}{$saltnid};
			delete $product_ref->{nutriments}{$saltnid . "_unit"};
			delete $product_ref->{nutriments}{$saltnid . "_value"};
			delete $product_ref->{nutriments}{$saltnid . "_modifier"};
			delete $product_ref->{nutriments}{$saltnid . "_label"};
			delete $product_ref->{nutriments}{$saltnid . "_100g"};
			delete $product_ref->{nutriments}{$saltnid . "_serving"};
		}
		elsif ((defined $salt) and (not defined $sodium)) {
			delete $product_ref->{nutriments}{$sodiumnid};
			delete $product_ref->{nutriments}{$sodiumnid . "_unit"};
			delete $product_ref->{nutriments}{$sodiumnid . "_value"};
			delete $product_ref->{nutriments}{$sodiumnid . "_modifier"};
			delete $product_ref->{nutriments}{$sodiumnid . "_label"};
			delete $product_ref->{nutriments}{$sodiumnid . "_100g"};
			delete $product_ref->{nutriments}{$sodiumnid . "_serving"};
		}
	}

	foreach my $nutriment (@{$nutriments_tables{$nutriment_table}}, @unknown_nutriments, @new_nutriments) {
		next if $nutriment =~ /^\#/;

		my $nid = $nutriment;
		$nid =~ s/^(-|!)+//g;
		$nid =~ s/-$//g;

		next if $nid =~ /^nutrition-score/;

		# Only moderators can update values for fields sent by the producer
		if (skip_protected_field($product_ref, $nid, $can_edit_owner_fields)) {
			next;
		}

		# Unit and label are the same for as sold and prepared nutrition table
		my $enid = encodeURIComponent($nid);
		my $unit = remove_tags_and_quote(decode utf8 => single_param("nutriment_${enid}_unit"));
		my $label = remove_tags_and_quote(decode utf8 => single_param("nutriment_${enid}_label"));

		# We can have nutrient values for the product as sold, or prepared
		foreach my $product_type ("", "_prepared") {

			# do not delete values if the nutriment is not provided
			next if (not defined single_param("nutriment_${enid}${product_type}"));

			my $value = remove_tags_and_quote(decode utf8 => single_param("nutriment_${enid}${product_type}"));

			# energy: (see bug https://github.com/openfoodfacts/openfoodfacts-server/issues/2396 )
			# 1. if energy-kcal or energy-kj is set, delete existing energy data
			if (($nid eq "energy-kj") or ($nid eq "energy-kcal")) {
				delete $product_ref->{nutriments}{"energy${product_type}"};
				delete $product_ref->{nutriments}{"energy_unit"};
				delete $product_ref->{nutriments}{"energy_label"};
				delete $product_ref->{nutriments}{"energy${product_type}_value"};
				delete $product_ref->{nutriments}{"energy${product_type}_modifier"};
				delete $product_ref->{nutriments}{"energy${product_type}_100g"};
				delete $product_ref->{nutriments}{"energy${product_type}_serving"};
			}
			# 2. if the nid passed is just energy, set instead energy-kj or energy-kcal using the passed unit
			elsif (($nid eq "energy") and ((lc($unit) eq "kj") or (lc($unit) eq "kcal"))) {
				$nid = $nid . "-" . lc($unit);
				$log->debug("energy without unit, set nid with unit instead", {nid => $nid, unit => $unit})
					if $log->is_debug();
			}

			if ($nid eq 'alcohol') {
				$unit = '% vol';
			}

			# New label?
			my $new_nid;
			if ((defined $label) and ($label ne '')) {
				$new_nid = canonicalize_nutriment($lc, $label);
				$log->debug("unknown nutrient", {nid => $nid, lc => $lc, canonicalize_nutriment => $new_nid})
					if $log->is_debug();

				if ($new_nid ne $nid) {
					delete $product_ref->{nutriments}{$nid};
					delete $product_ref->{nutriments}{$nid . "_unit"};
					delete $product_ref->{nutriments}{$nid . "_label"};
					delete $product_ref->{nutriments}{$nid . $product_type . "_value"};
					delete $product_ref->{nutriments}{$nid . $product_type . "_modifier"};
					delete $product_ref->{nutriments}{$nid . $product_type . "_100g"};
					delete $product_ref->{nutriments}{$nid . $product_type . "_serving"};
					$log->debug("unknown nutrient", {nid => $nid, lc => $lc, known_nid => $new_nid})
						if $log->is_debug();
					$nid = $new_nid;
				}
				$product_ref->{nutriments}{$nid . "_label"} = $label;
			}

			# Set the nutrient values
			my $modifier;
			normalize_nutriment_value_and_modifier(\$value, \$modifier);
			assign_nid_modifier_value_and_unit($product_ref, $nid . ${product_type}, $modifier, $value, $unit);
		}

		# If we don't have a value for the product and the prepared product, delete the unit and label
		if (    (not defined $product_ref->{nutriments}{$nid})
			and (not defined $product_ref->{nutriments}{$nid . "_prepared"}))
		{
			delete $product_ref->{nutriments}{$nid . "_unit"};
			delete $product_ref->{nutriments}{$nid . "_label"};
		}
	}

	if ((defined $product_ref->{no_nutrition_data}) and ($product_ref->{no_nutrition_data} eq 'on')) {

		# Delete all non-carbon-footprint nids.
		foreach my $key (keys %{$product_ref->{nutriments}}) {
			next if $key =~ /_/;
			next if $key eq 'carbon-footprint';

			delete $product_ref->{nutriments}{$key};
			delete $product_ref->{nutriments}{$key . "_unit"};
			delete $product_ref->{nutriments}{$key . "_value"};
			delete $product_ref->{nutriments}{$key . "_modifier"};
			delete $product_ref->{nutriments}{$key . "_label"};
			delete $product_ref->{nutriments}{$key . "_100g"};
			delete $product_ref->{nutriments}{$key . "_serving"};
		}
	}
	return;
}

=head2 compute_estimated_nutrients ( $product_ref )

Compute estimated nutrients from ingredients.

If we have a high enough confidence (95% of the ingredients (by quantity) have a known nutrient profile),
we store the result in the nutriments_estimated hash.

=cut

sub compute_estimated_nutrients ($product_ref) {
	my $results_ref = estimate_nutrients_from_ingredients($product_ref->{ingredients});

	# only take the result if we have at least 95% of ingredients with nutrients
	if (($results_ref->{total} > 0) and (($results_ref->{total_with_nutrients} / $results_ref->{total}) >= 0.95)) {
		$product_ref->{nutriments_estimated} = {};
		while (my ($nid, $value) = each(%{$results_ref->{nutrients}})) {
			$product_ref->{nutriments_estimated}{$nid . '_100g'} = $value;
		}
	}
	else {
		delete $product_ref->{nutriments_estimated};
	}

	return $results_ref;
}

1;
