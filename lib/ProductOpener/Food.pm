# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2019 Association Open Food Facts
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
related to nutrition facts. It does not contain functions related to ingredients which
are in the C<ProductOpener::Ingredients> module.

..

=cut

package ProductOpener::Food;

use utf8;
use Modern::Perl '2017';
use Exporter    qw< import >;

BEGIN
{
	use vars       qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@EXPORT = qw();	    # symbols to export by default
	@EXPORT_OK = qw(
					%Nutriments
					%nutriments_labels

					%cc_nutriment_table
					%nutriments_tables

					%other_nutriments_lists
					%nutriments_lists

					@nutrient_levels

					%categories_nutriments_per_country

					&normalize_nutriment_value_and_modifier
					&assign_nid_modifier_value_and_unit

					&get_nutrient_label

					&unit_to_g
					&g_to_unit

					&unit_to_mmoll
					&mmoll_to_unit

					&normalize_serving_size
					&normalize_quantity

					&canonicalize_nutriment

					&fix_salt_equivalent

					&is_beverage_for_nutrition_score
					&is_water_for_nutrition_score
					&is_cheese_for_nutrition_score
					&is_fat_for_nutrition_score

					&compute_nutriscore
					&compute_nutrition_score
					&compute_nova_group
					&compute_serving_size_data
					&compute_unknown_nutrients
					&compute_nutrient_levels
					&compute_units_of_alcohol
					&compute_carbon_footprint_infocard

					&compare_nutriments

					$ec_code_regexp
					%packager_codes
					%geocode_addresses
					&normalize_packager_codes
					&localize_packager_code
					&get_canon_local_authority

					&special_process_product

					&extract_nutrition_from_image

					&default_unit_for_nid

					&create_nutrients_level_taxonomy

					&assign_category_properties_to_product
					
					&remove_insignificant_digits

					);	# symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;

use ProductOpener::Store qw/:all/;
use ProductOpener::Config qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Nutriscore qw/:all/;

use Hash::Util;

use CGI qw/:cgi :form escapeHTML/;

use Log::Any qw($log);


=head2 remove_insignificant_digits($)

Some apps send us nutrient values that they have stored internally as
floating point numbers.

So we get values like:

2.9000000953674
1.6000000238419
0.89999997615814
0.359999990463256
2.5999999046326

On the other hand, when we get values like 2.0, 2.50 or 2.500,
we want to keep the trailing 0s.

The goal is to keep the precision if it makes sense. The tricky part
is that we do not know in advance how many significant digits we can have,
it varies from products to products, and even nutrients to nutrients.

The desired output is thus:

2.9000000953674 -> 2.9
1.6000000238419 -> 1.6
0.89999997615814 -> 0.9
0.359999990463256 -> 0.36
2.5999999046326 -> 2.6
2 -> 2
2.0 -> 2.0
2.000 -> 2.000
2.0001 -> 2
0.0001 -> 0.0001

=cut


sub remove_insignificant_digits($) {

	my $value = shift;
	
	# Make the value a string
	$value .= '';
	
	# Very small values may have been converted to scientific notation
	
	if ($value =~ /\.(\d*?[1-9]\d*?)0{3}/) {
		$value = $`. '.' . $1;
	}
	elsif ($value =~ /([1-9]0*)\.0{3}/) {
		$value = $`. $1;
	}
	elsif ($value =~ /\.(\d*)([0-8]+)9999/) {
		$value = $`. '.' . $1 . ($2 + 1);
	}
	elsif ($value =~ /\.9999/) {
		$value = $` + 1;
	}
	return $value;
}



# Load nutrient stats for all categories and countries
# the stats are displayed on category pages and used in product pages,
# as well as in data quality checks and improvement opportunity detection

if (opendir (my $dh, "$data_root/index")) {
	foreach my $file (readdir($dh)) {
		if ($file =~ /categories_nutriments_per_country.(\w+).sto$/) {
			my $country_cc = $1;
			$categories_nutriments_per_country{$country_cc} = retrieve("$data_root/index/categories_nutriments_per_country.$country_cc.sto");
		}
	}
	closedir $dh;
}


sub normalize_nutriment_value_and_modifier($$) {

	my $value_ref = shift;
	my $modifier_ref = shift;

	return if not defined $$value_ref;

	if ($$value_ref =~ /nan/i) {
		$$value_ref = '';
	}

	if ($$value_ref =~ /(\&lt;=|<=|\N{U+2264})( )?/) {
		$$value_ref =~ s/(\&lt;=|<=|\N{U+2264})( )?//;
		$modifier_ref = "\N{U+2264}";
	}
	if ($$value_ref =~ /(\&lt;|<|max|maxi|maximum|inf|inférieur|inferieur|less)( )?/) {
		$$value_ref =~ s/(\&lt;|<|min|minimum|max|maxi|maximum|environ)( )?//;
		$$modifier_ref = '<';
	}
	if ($$value_ref =~ /(\&gt;=|>=|\N{U+2265})/) {
		$$value_ref =~ s/(\&gt;=|>=|\N{U+2265})( )?//;
		$modifier_ref = "\N{U+2265}";
	}
	if ($$value_ref =~ /(\&gt;|>|min|mini|minimum|greater|more)/) {
		$$value_ref =~ s/(\&gt;|>|min|mini|minimum|greater|more)( )?//;
		$$modifier_ref = '>';
	}
	if ($$value_ref =~ /(env|environ|about|~|≈)/) {
		$$value_ref =~ s/(env|environ|about|~|≈)( )?//;
		$$modifier_ref = '~';
	}
	if ($$value_ref =~ /trace|traces/) {
		$$value_ref = 0;
		$$modifier_ref = '~';
	}
	if ($$value_ref !~ /\./) {
		$$value_ref =~ s/,/\./;
	}
}

# Return the default unit that we convert everything to internally

sub default_unit_for_nid($) {

	my $nid = shift;

	$nid =~ s/_prepared//;

	if ($nid eq "energy-kj") {
		return "kJ";
	}
	elsif ($nid eq "energy-kcal") {
		return "kcal";
	}
	elsif ($nid eq "energy") {
		return "kJ";
	}
	elsif ($nid eq "alcohol") {
		return "% vol";
	}
	elsif (($nid =~ /^fruits/) or ($nid =~ /^collagen/)) {
		return "%";
	}
	elsif ($nid eq 'water-hardness') {
		return "mmol/l";
	}
	else {
		return "g";
	}
}

sub assign_nid_modifier_value_and_unit($$$$$) {

	my $product_ref = shift;
	my $nid = shift;
	my $modifier = shift;
	my $value = shift;
	my $unit = shift;

	# empty unit?
	if ((not defined $unit) or ($unit eq "")) {
		$unit = default_unit_for_nid($nid);
	}

	$value =~ s/(\d) (\d)/$1$2/g;
	$value =~ s/,/./;
	$value += 0;

	if ((defined $modifier) and ($modifier ne '')) {
		$product_ref->{nutriments}{$nid . "_modifier"} = $modifier;
	}
	else {
		delete $product_ref->{nutriments}{$nid . "_modifier"};
	}
	$product_ref->{nutriments}{$nid . "_unit"} = $unit;
	$product_ref->{nutriments}{$nid . "_value"} = $value;

	if (((uc($unit) eq 'IU') or (uc($unit) eq 'UI')) and (exists $Nutriments{$nid}) and ($Nutriments{$nid}{iu} > 0)) {
		$value = $value * $Nutriments{$nid}{iu} ;
		$unit = $Nutriments{$nid}{unit};
	}
	elsif  ((uc($unit) eq '% DV') and (exists $Nutriments{$nid}) and ($Nutriments{$nid}{dv} > 0)) {
		$value = $value / 100 * $Nutriments{$nid}{dv} ;
		$unit = $Nutriments{$nid}{unit};
	}
	if ($nid eq 'water-hardness') {
		$product_ref->{nutriments}{$nid} = unit_to_mmoll($value, $unit) + 0;
	}
	else {
		$product_ref->{nutriments}{$nid} = unit_to_g($value, $unit) + 0;
	}

}

sub get_nutrient_label {
	my $nid = (shift(@_) // undef);
	my $flang = (shift(@_) // $lang);

	if (not defined $nid) {
		return;
	}
	if (defined $Nutriments{$nid}{$lang}) {
		return $Nutriments{$nid}{$lang};
	}
	elsif (defined $Nutriments{$nid}{$flang}) {
		return $Nutriments{$nid}{$flang};
	}
	else {
		return;
	}
}

=head2 unit_to_g($$)

Converts <xx><unit> into <xx>grams. Eg.:
unit_to_g(2,kg) => returns 2000
unit_to_g(520,mg) => returns 0.52

=cut

sub unit_to_g($$) {
	my $value = shift;
	my $unit = shift;
	$unit = lc($unit);

	if ($unit =~ /^(fl|fluid)(\.| )*(oz|once|ounce)/) {
		$unit = "fl oz";
	}

	(not defined $value) and return $value;

	$value =~ s/,/\./;
	$value =~ s/^(<|environ|max|maximum|min|minimum)( )?//;

	$value eq '' and return $value;

	(($unit eq 'kcal') or ($unit eq 'ккал')) and return int($value * 4.184 + 0.5);
	# kg = 公斤 - gōngjīn = кг
	(($unit eq 'kg') or ($unit eq "\N{U+516C}\N{U+65A4}") or ($unit eq 'кг')) and return $value * 1000;
	# 斤 - jīn = 500 Grams
	$unit eq "\N{U+65A4}" and return $value * 500;
	# mg = 毫克 - háokè = мг
	(($unit eq 'mg') or ($unit eq "\N{U+6BEB}\N{U+514B}") or ($unit eq 'мг')) and return $value / 1000;
	(($unit eq 'mcg') or ($unit eq 'µg')) and return $value / 1000000;
	$unit eq 'oz' and return $value * 28.349523125;

	# l = 公升 - gōngshēng = л = liter
	(($unit eq 'l') or ($unit eq "\N{U+516C}\N{U+5347}") or ($unit eq 'л')) and return $value * 1000;
	(($unit eq 'dl') or ($unit eq 'дл')) and return $value * 100;
	(($unit eq 'cl') or ($unit eq 'кл')) and return $value * 10;
	$unit eq 'fl oz' and return $value * 30;

	# return value without modification if it's already grams or 克 (kè) or 公克 (gōngkè) or г
	return $value + 0; # + 0 to make sure the value is treated as number
	# (needed when outputting json and to store in mongodb as a number)
}


=head2 g_to_unit($$)

Converts <xx>grams into <xx><unit>. Eg.:
g_to_unit(2000,kg) => returns 2
g_to_unit(0.52,mg) => returns 520

=cut

sub g_to_unit($$) {
	my $value = shift;
	my $unit = shift;
	$unit = lc($unit);

	if ((not defined $value) or ($value eq '')) {
		return "";
	}

	$unit eq 'fl. oz' and $unit = 'fl oz';
	$unit eq 'fl.oz' and $unit = 'fl oz';

	$value =~ s/,/\./;
	$value =~ s/^(<|environ|max|maximum|min|minimum)( )?//;

	$value eq '' and return $value;

	(($unit eq 'kcal') or ($unit eq 'ккал')) and return int($value / 4.184 + 0.5);
	# kg = 公斤 - gōngjīn = кг
	(($unit eq 'kg') or ($unit eq "\N{U+516C}\N{U+65A4}") or ($unit eq 'кг')) and return $value / 1000;
	# 斤 - jīn = 500 Grams
	$unit eq "\N{U+65A4}" and return $value / 500;
	# mg = 毫克 - háokè = мг
	(($unit eq 'mg') or ($unit eq "\N{U+6BEB}\N{U+514B}") or ($unit eq 'мг')) and return $value * 1000;
	(($unit eq 'mcg') or ($unit eq 'µg')) and return $value * 1000000;
	$unit eq 'oz' and return $value / 28.349523125;

	# l = 公升 - gōngshēng = л = liter
	(($unit eq 'l') or ($unit eq "\N{U+516C}\N{U+5347}") or ($unit eq 'л')) and return $value / 1000;
	(($unit eq 'dl') or ($unit eq 'дл')) and return $value / 100;
	(($unit eq 'cl') or ($unit eq 'кл')) and return $value / 10;
	$unit eq 'fl oz' and return $value / 30;

	# return value without modification if unit is already grams or 克 (kè) or 公克 (gōngkè) or г
	return $value + 0; # + 0 to make sure the value is treated as number
	# (needed when outputting json and to store in mongodb as a number)
}

sub unit_to_mmoll {
	my ($value, $unit) = @_;
	$unit = lc($unit);

	if ((not defined $value) or ($value eq '')) {
		return '';
	}

	$value =~ s/,/\./;
	$value =~ s/^(<|environ|max|maximum|min|minimum)( )?//;

	return $value * 1000 if $unit eq 'mol/l';
	return $value + 0 if $unit eq 'mmol/l';
	return $value / 2 if $unit eq 'mval/l';
	return $value / 100 if $unit eq 'ppm';
	return $value / 40.080 if $unit eq "\N{U+00B0}rh";
	return $value / 10.00 if $unit eq "\N{U+00B0}fh";
	return $value / 7.02 if $unit eq "\N{U+00B0}e";
	return $value / 5.6 if $unit eq "\N{U+00B0}dh";
	return $value / 5.847 if $unit eq 'gpg';
	return $value + 0;
}

sub mmoll_to_unit {
	my ($value, $unit) = @_;
	$unit = lc($unit);

	if ((not defined $value) or ($value eq '')) {
		return '';
	}

	$value =~ s/,/\./;
	$value =~ s/^(<|environ|max|maximum|min|minimum)( )?//;

	return $value / 1000 if $unit eq 'mol/l';
	return $value + 0 if $unit eq 'mmol/l';
	return $value * 2 if $unit eq 'mval/l';
	return $value * 100 if $unit eq 'ppm';
	return $value * 40.080 if $unit eq "\N{U+00B0}rh";
	return $value * 10.00 if $unit eq "\N{U+00B0}fh";
	return $value * 7.02 if $unit eq "\N{U+00B0}e";
	return $value * 5.6 if $unit eq "\N{U+00B0}dh";
	return $value * 5.847 if $unit eq 'gpg';
	return $value + 0;
}

# http://www.diw.de/sixcms/media.php/73/diw_wr_2010-19.pdf
@nutrient_levels = (
	['fat', 3, 20 ],
	['saturated-fat', 1.5, 5],
	['sugars', 5, 12.5],
	['salt', 0.3, 1.5],
);

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
);

# http://healthycanadians.gc.ca/eating-nutrition/label-etiquetage/tips-conseils/nutrition-fact-valeur-nutritive-eng.php

%nutriments_tables = (
	europe => [(
		'!energy-kj',
		'!energy-kcal',
		'energy-',
		'-energy-from-fat-',
		'!fat',
		'-saturated-fat',
		'--butyric-acid-',
		'--caproic-acid-',
		'--caprylic-acid-',
		'--capric-acid-',
		'--lauric-acid-',
		'--myristic-acid-',
		'--palmitic-acid-',
		'--stearic-acid-',
		'--arachidic-acid-',
		'--behenic-acid-',
		'--lignoceric-acid-',
		'--cerotic-acid-',
		'--montanic-acid-',
		'--melissic-acid-',
		'-monounsaturated-fat-',
		'-polyunsaturated-fat-',
		'-omega-3-fat-',
		'--alpha-linolenic-acid-',
		'--eicosapentaenoic-acid-',
		'--docosahexaenoic-acid-',
		'-omega-6-fat-',
		'--linoleic-acid-',
		'--arachidonic-acid-',
		'--gamma-linolenic-acid-',
		'--dihomo-gamma-linolenic-acid-',
		'-omega-9-fat-',
		'--oleic-acid-',
		'--elaidic-acid-',
		'--gondoic-acid-',
		'--mead-acid-',
		'--erucic-acid-',
		'--nervonic-acid-',
		'-trans-fat-',
		'-cholesterol-',
		'!carbohydrates',
		'-sugars',
		'--sucrose-',
		'--glucose-',
		'--fructose-',
		'--lactose-',
		'--maltose-',
		'--maltodextrins-',
		'-starch-',
		'-polyols-',
		'fiber',
		'--soluble-fiber-',
		'--insoluble-fiber-',
		'!proteins',
		'-casein-',
		'-serum-proteins-',
		'-nucleotides-',
		'salt',
		'sodium',
		'alcohol',
		'#vitamins',
		'vitamin-a-',
		'beta-carotene-',
		'vitamin-d-',
		'vitamin-e-',
		'vitamin-k-',
		'vitamin-c-',
		'vitamin-b1-',
		'vitamin-b2-',
		'vitamin-pp-',
		'vitamin-b6-',
		'vitamin-b9-',
		'folates-',
		'vitamin-b12-',
		'biotin-',
		'pantothenic-acid-',
		'#minerals',
		'silica-',
		'bicarbonate-',
		'potassium-',
		'chloride-',
		'calcium-',
		'phosphorus-',
		'iron-',
		'magnesium-',
		'zinc-',
		'copper-',
		'manganese-',
		'fluoride-',
		'selenium-',
		'chromium-',
		'molybdenum-',
		'iodine-',
		'caffeine-',
		'taurine-',
		'ph-',
		'fruits-vegetables-nuts-',
		'fruits-vegetables-nuts-dried-',
		'fruits-vegetables-nuts-estimate-',
		'collagen-meat-protein-ratio-',
		'cocoa-',
		'chlorophyl-',
		'carbon-footprint',
		'carbon-footprint-from-meat-or-fish-',
		'nutrition-score-fr-',
		'nutrition-score-uk-',
		'glycemic-index-',
		'water-hardness-',
		'choline-',
		'phylloquinone-',
		'beta-glucan-',
		'inositol-',
		'carnitine-',
	)],
	ca => [(
		'!energy-kcal',
		'energy-',
		'!fat',
		'-saturated-fat',
		'--butyric-acid-',
		'--caproic-acid-',
		'--caprylic-acid-',
		'--capric-acid-',
		'--lauric-acid-',
		'--myristic-acid-',
		'--palmitic-acid-',
		'--stearic-acid-',
		'--arachidic-acid-',
		'--behenic-acid-',
		'--lignoceric-acid-',
		'--cerotic-acid-',
		'--montanic-acid-',
		'--melissic-acid-',
		'-monounsaturated-fat-',
		'-polyunsaturated-fat-',
		'-omega-3-fat-',
		'--alpha-linolenic-acid-',
		'--eicosapentaenoic-acid-',
		'--docosahexaenoic-acid-',
		'-omega-6-fat-',
		'--linoleic-acid-',
		'--arachidonic-acid-',
		'--gamma-linolenic-acid-',
		'--dihomo-gamma-linolenic-acid-',
		'-omega-9-fat-',
		'--oleic-acid-',
		'--elaidic-acid-',
		'--gondoic-acid-',
		'--mead-acid-',
		'--erucic-acid-',
		'--nervonic-acid-',
		'-trans-fat',
		'cholesterol',
		'!carbohydrates',
		'-fiber',
		'--soluble-fiber-',
		'--insoluble-fiber-',
		'-sugars',
		'--sucrose-',
		'--glucose-',
		'--fructose-',
		'--lactose-',
		'--maltose-',
		'--maltodextrins-',
		'-starch-',
		'-polyols-',
		'!proteins',
		'-casein-',
		'-serum-proteins-',
		'-nucleotides-',
		'salt',
		'sodium',
		'alcohol',
		'#vitamins',
		'vitamin-a',
		'beta-carotene-',
		'vitamin-d-',
		'vitamin-e-',
		'vitamin-k-',
		'vitamin-c',
		'vitamin-b1-',
		'vitamin-b2-',
		'vitamin-pp-',
		'vitamin-b6-',
		'vitamin-b9-',
		'folates-',
		'vitamin-b12-',
		'biotin-',
		'pantothenic-acid-',
		'#minerals',
		'silica-',
		'bicarbonate-',
		'potassium-',
		'chloride-',
		'calcium',
		'phosphorus-',
		'iron',
		'magnesium-',
		'zinc-',
		'copper-',
		'manganese-',
		'fluoride-',
		'selenium-',
		'chromium-',
		'molybdenum-',
		'iodine-',
		'caffeine-',
		'taurine-',
		'ph-',
		'fruits-vegetables-nuts-',
		'fruits-vegetables-nuts-dried-',
		'fruits-vegetables-nuts-estimate-',
		'collagen-meat-protein-ratio-',
		'cocoa-',
		'chlorophyl-',
		'carbon-footprint',
		'carbon-footprint-from-meat-or-fish-',
		'nutrition-score-fr-',
		'nutrition-score-uk-',
		'glycemic-index-',
		'water-hardness-',
		'choline-',
		'phylloquinone-',
		'beta-glucan-',
		'inositol-',
		'carnitine-',
	)],
	ru => [(
		'!proteins',
		'-casein-',
		'-serum-proteins-',
		'-nucleotides-',
		'!fat',
		'-saturated-fat',
		'--butyric-acid-',
		'--caproic-acid-',
		'--caprylic-acid-',
		'--capric-acid-',
		'--lauric-acid-',
		'--myristic-acid-',
		'--palmitic-acid-',
		'--stearic-acid-',
		'--arachidic-acid-',
		'--behenic-acid-',
		'--lignoceric-acid-',
		'--cerotic-acid-',
		'--montanic-acid-',
		'--melissic-acid-',
		'-monounsaturated-fat-',
		'-polyunsaturated-fat-',
		'-omega-3-fat-',
		'--alpha-linolenic-acid-',
		'--eicosapentaenoic-acid-',
		'--docosahexaenoic-acid-',
		'-omega-6-fat-',
		'--linoleic-acid-',
		'--arachidonic-acid-',
		'--gamma-linolenic-acid-',
		'--dihomo-gamma-linolenic-acid-',
		'-omega-9-fat-',
		'--oleic-acid-',
		'--elaidic-acid-',
		'--gondoic-acid-',
		'--mead-acid-',
		'--erucic-acid-',
		'--nervonic-acid-',
		'-trans-fat-',
		'-cholesterol-',
		'!carbohydrates',
		'-sugars',
		'--sucrose-',
		'--glucose-',
		'--fructose-',
		'--lactose-',
		'--maltose-',
		'--maltodextrins-',
		'-starch-',
		'-polyols-',
		'!energy-kj',
		'!energy-kcal',
		'energy-',
		'-energy-from-fat-',
		'fiber',
		'salt',
		'sodium',
		'alcohol',
		'#vitamins',
		'vitamin-a-',
		'beta-carotene-',
		'vitamin-d-',
		'vitamin-e-',
		'vitamin-k-',
		'vitamin-c-',
		'vitamin-b1-',
		'vitamin-b2-',
		'vitamin-pp-',
		'vitamin-b6-',
		'vitamin-b9-',
		'folates-',
		'vitamin-b12-',
		'biotin-',
		'pantothenic-acid-',
		'#minerals',
		'silica-',
		'bicarbonate-',
		'potassium-',
		'chloride-',
		'calcium-',
		'phosphorus-',
		'iron-',
		'magnesium-',
		'zinc-',
		'copper-',
		'manganese-',
		'fluoride-',
		'selenium-',
		'chromium-',
		'molybdenum-',
		'iodine-',
		'caffeine-',
		'taurine-',
		'ph-',
		'fruits-vegetables-nuts-',
		'fruits-vegetables-nuts-dried-',
		'fruits-vegetables-nuts-estimate-',
		'collagen-meat-protein-ratio-',
		'cocoa-',
		'chlorophyl-',
		'carbon-footprint',
		'carbon-footprint-from-meat-or-fish-',
		'nutrition-score-fr-',
		'nutrition-score-uk-',
		'glycemic-index-',
		'water-hardness-',
		'choline-',
		'phylloquinone-',
		'beta-glucan-',
		'inositol-',
		'carnitine-',
	)],
	us => [(
		'!energy-kcal',
		'energy-',
		'-energy-from-fat-',
		'!fat',
		'-saturated-fat',
		'--butyric-acid-',
		'--caproic-acid-',
		'--caprylic-acid-',
		'--capric-acid-',
		'--lauric-acid-',
		'--myristic-acid-',
		'--palmitic-acid-',
		'--stearic-acid-',
		'--arachidic-acid-',
		'--behenic-acid-',
		'--lignoceric-acid-',
		'--cerotic-acid-',
		'--montanic-acid-',
		'--melissic-acid-',
		'-monounsaturated-fat-',
		'-polyunsaturated-fat-',
		'-omega-3-fat-',
		'--alpha-linolenic-acid-',
		'--eicosapentaenoic-acid-',
		'--docosahexaenoic-acid-',
		'-omega-6-fat-',
		'--linoleic-acid-',
		'--arachidonic-acid-',
		'--gamma-linolenic-acid-',
		'--dihomo-gamma-linolenic-acid-',
		'-omega-9-fat-',
		'--oleic-acid-',
		'--elaidic-acid-',
		'--gondoic-acid-',
		'--mead-acid-',
		'--erucic-acid-',
		'--nervonic-acid-',
		'-trans-fat',
		'cholesterol',
		'salt-',
		'sodium',
		'!carbohydrates',
		'-fiber',
		'--soluble-fiber-',
		'--insoluble-fiber-',
		'-sugars',
		'-added-sugars',
		'--sucrose-',
		'--glucose-',
		'--fructose-',
		'--lactose-',
		'--maltose-',
		'--maltodextrins-',
		'-starch-',
		'-polyols-',
		'!proteins',
		'-casein-',
		'-serum-proteins-',
		'-nucleotides-',
		'alcohol',
		'#vitamins',
		'vitamin-a-',
		'beta-carotene-',
		'vitamin-d',
		'vitamin-e-',
		'vitamin-k-',
		'vitamin-c-',
		'vitamin-b1-',
		'vitamin-b2-',
		'vitamin-pp-',
		'vitamin-b6-',
		'vitamin-b9-',
		'folates-',
		'vitamin-b12-',
		'biotin-',
		'pantothenic-acid-',
		'#minerals',
		'silica-',
		'bicarbonate-',
		'potassium',
		'chloride-',
		'calcium',
		'phosphorus-',
		'iron',
		'magnesium-',
		'zinc-',
		'copper-',
		'manganese-',
		'fluoride-',
		'selenium-',
		'chromium-',
		'molybdenum-',
		'iodine-',
		'caffeine-',
		'taurine-',
		'ph-',
		'fruits-vegetables-nuts-',
		'fruits-vegetables-nuts-dried-',
		'fruits-vegetables-nuts-estimate-',
		'collagen-meat-protein-ratio-',
		'cocoa-',
		'chlorophyl-',
		'carbon-footprint',
		'carbon-footprint-from-meat-or-fish-',
		'nutrition-score-fr-',
		'nutrition-score-uk-',
		'glycemic-index-',
		'water-hardness-',
	)],
	us_before_2017 => [(
		'!energy',
		'-energy-from-fat',
		'!fat',
		'-saturated-fat',
		'--butyric-acid-',
		'--caproic-acid-',
		'--caprylic-acid-',
		'--capric-acid-',
		'--lauric-acid-',
		'--myristic-acid-',
		'--palmitic-acid-',
		'--stearic-acid-',
		'--arachidic-acid-',
		'--behenic-acid-',
		'--lignoceric-acid-',
		'--cerotic-acid-',
		'--montanic-acid-',
		'--melissic-acid-',
		'-monounsaturated-fat-',
		'-polyunsaturated-fat-',
		'-omega-3-fat-',
		'--alpha-linolenic-acid-',
		'--eicosapentaenoic-acid-',
		'--docosahexaenoic-acid-',
		'-omega-6-fat-',
		'--linoleic-acid-',
		'--arachidonic-acid-',
		'--gamma-linolenic-acid-',
		'--dihomo-gamma-linolenic-acid-',
		'-omega-9-fat-',
		'--oleic-acid-',
		'--elaidic-acid-',
		'--gondoic-acid-',
		'--mead-acid-',
		'--erucic-acid-',
		'--nervonic-acid-',
		'-trans-fat',
		'cholesterol',
		'salt-',
		'sodium',
		'!carbohydrates',
		'-fiber',
		'--soluble-fiber-',
		'--insoluble-fiber-',
		'-sugars',
		'--sucrose-',
		'--glucose-',
		'--fructose-',
		'--lactose-',
		'--maltose-',
		'--maltodextrins-',
		'-starch-',
		'-polyols-',
		'!proteins',
		'-casein-',
		'-serum-proteins-',
		'-nucleotides-',
		'alcohol',
		'#vitamins',
		'vitamin-a',
		'beta-carotene-',
		'vitamin-d-',
		'vitamin-e-',
		'vitamin-k-',
		'vitamin-c',
		'vitamin-b1-',
		'vitamin-b2-',
		'vitamin-pp-',
		'vitamin-b6-',
		'vitamin-b9-',
		'folates-',
		'vitamin-b12-',
		'biotin-',
		'pantothenic-acid-',
		'#minerals',
		'silica-',
		'bicarbonate-',
		'potassium-',
		'chloride-',
		'calcium',
		'phosphorus-',
		'iron',
		'magnesium-',
		'zinc-',
		'copper-',
		'manganese-',
		'fluoride-',
		'selenium-',
		'chromium-',
		'molybdenum-',
		'iodine-',
		'caffeine-',
		'taurine-',
		'ph-',
		'fruits-vegetables-nuts-',
		'fruits-vegetables-nuts-dried-',
		'fruits-vegetables-nuts-estimate-',
		'collagen-meat-protein-ratio-',
		'cocoa-',
		'chlorophyl-',
		'carbon-footprint',
		'carbon-footprint-from-meat-or-fish-',
		'nutrition-score-fr-',
		'nutrition-score-uk-',
		'glycemic-index-',
		'water-hardness-',
		'choline-',
		'phylloquinone-',
		'beta-glucan-',
		'inositol-',
		'carnitine-',
	)],
	hk => [(
		'!energy-kj',
		'!energy-kcal',
		'!proteins',
		'!fat',
		'-saturated-fat',
		'-polyunsaturated-fat-',
		'-monounsaturated-fat-',
		'-trans-fat',
		'cholesterol',
		'!carbohydrates',
		'-sugars',
		'-fiber',
		'salt-',
		'sodium',
		'#vitamins',
		'vitamin-a',
		'vitamin-d-',
		'vitamin-c',
		'vitamin-b1-',
		'vitamin-b2-',
		'vitamin-pp-',
		'vitamin-b6-',
		'vitamin-b9-',
		'folates-',
		'vitamin-b12-',
		'#minerals',
		'calcium',
		'potassium-',
		'phosphorus-',
		'iron',
		'alcohol',
		'nutrition-score-fr-',
	)],
);



# fr_synonyms is used to parse plain text nutrition facts value

%Nutriments = (
	alcohol	=> {
		ar => "الكحوليات",
		bg => "Алкохол",
		cs => "Alkohol",
		da => "Alkohol",
		de => "Alkohol",
		el => "Αλκοόλη",
		en => "Alcohol",
		es => "Alcohol",
		et => "Alkohol",
		fa => "الکل",
		fi => "Alkoholi",
		fr => "Alcool",
		fr_synonyms => ["Titre volumique", "Titre vol."],
		ga => "Alcól",
		he => "אלכוהול",
		hu => "Alkohol",
		it => "Alcol",
		ja => "アルコール",
		lt => "Alkoholis",
		lv => "spirts",
		mt => "Alkoħol",
		nl => "Alcohol",
		nl_be => "Alcohol",
		nb => "Alkohol",
		pl => "Alkohol",
		pt => "Álcool",
		ro => "Alcool",
		rs => "Alkohol",
		ru => "Алкоголь",
		sk => "Alkohol",
		sl => "Alkohol",
		sv => "Alkohol",
		tr => "Alkol",
		zh => "酒精度",
		zh_CN => "酒精度",
		zh_HK => "酒精",
		zh_TW => "酒精",
		unit => "% vol",
	},
	energy	=> {
		ar => "الطاقه",
		bg => "Енергийна стойност",
		cs => "Energetická hodnota",
		da => "Energi",
		de => "Energie",
		el => "Ενέργεια",
		en => "Energy",
		es => "Energía",
		es_synonyms => ["Valor Energético"],
		et => "Energia",
		fa => "انرژی",
		fi => "Energia",
		fr => "Énergie",
		fr_synonyms => ["valeurs énergétique", "valeur énergétique"],
		ga => "Fuinneamh",
		he => "אנרגיה - קלוריות",
		hu => "Energia",
		it => "Energia",
		lt => "Energinė vertė",
		ja => "エネルギー",
		lv => "Enerģētiskā vērtība",
		mt => "Enerġija",
		nb => "Energi",
		nl => "Energie",
		nl_be => "Energie",
		pt => "Energia",
		pl => "Wartość energetyczna",
		ro => "Valoarea energetică",
		rs => "Energetska vrednost",
		ru => "Энергетическая ценность",
		sl => "Energijska vrednost",
		sk => "Energetická hodnota",
		sv => "Energi",
		tr => "Enerji",
		zh => "能量",
		zh_CN => "能量",
		zh_HK => "能量",
		zh_TW => "能量",

		unit => "kj",
		unit_us => "kcal",
		unit_ca => "kcal",
	},
	"energy-kj"	=> {
		ar => "الطاقه (kJ)",
		bg => "Енергийна стойност (kJ)",
		cs => "Energetická hodnota (kJ)",
		da => "Energi (kJ)",
		de => "Energie (kJ)",
		el => "Ενέργεια (kJ)",
		en => "Energy (kJ)",
		es => "Energía (kJ)",
		es_synonyms => ["Valor Energético (kJ)"],
		et => "Energia (kJ)",
		fa => "انرژی (kJ)",
		fi => "Energia (kJ)",
		fr => "Énergie (kJ)",
		fr_synonyms => ["valeurs énergétique (kJ)", "valeur énergétique (kJ)"],
		ga => "Fuinneamh (kJ)",
		he => "אנרגיה - קלוריות (kJ)",
		hu => "Energia (kJ)",
		it => "Energia (kJ)",
		lt => "Energinė vertė (kJ)",
		ja => "エネルギー (kJ)",
		lv => "Enerģētiskā vērtība (kJ)",
		mt => "Enerġija (kJ)",
		nb => "Energi (kJ)",
		nl => "Energie (kJ)",
		nl_be => "Energie (kJ)",
		pt => "Energia (kJ)",
		pl => "Wartość energetyczna (kJ)",
		ro => "Valoarea energetică (kJ)",
		rs => "Energetska vrednost (kJ)",
		ru => "Энергетическая ценность (kJ)",
		sl => "Energijska vrednost (kJ)",
		sk => "Energetická hodnota (kJ)",
		sv => "Energi (kJ)",
		tr => "Enerji (kJ)",
		zh => "能量 (kJ)",
		zh_CN => "能量 (kJ)",
		zh_HK => "能量 (kJ)",
		zh_TW => "能量 (kJ)",

		unit => "kj",
	},
	"energy-kcal"	=> {
		ar => "الطاقه (kcal)",
		bg => "Енергийна стойност (kcal)",
		cs => "Energetická hodnota (kcal)",
		da => "Energi (kcal)",
		de => "Energie (kcal)",
		el => "Ενέργεια (kcal)",
		en => "Energy (kcal)",
		es => "Energía (kcal)",
		es_synonyms => ["Valor Energético (kcal)"],
		et => "Energia (kcal)",
		fa => "انرژی (kcal)",
		fi => "Energia (kcal)",
		fr => "Énergie (kcal)",
		fr_synonyms => ["valeurs énergétique (kcal)", "valeur énergétique (kcal)"],
		ga => "Fuinneamh (kcal)",
		he => "אנרגיה - קלוריות (kcal)",
		hu => "Energia (kcal)",
		it => "Energia (kcal)",
		lt => "Energinė vertė (kcal)",
		ja => "エネルギー (kcal)",
		lv => "Enerģētiskā vērtība (kcal)",
		mt => "Enerġija (kcal)",
		nb => "Energi (kcal)",
		nl => "Energie (kcal)",
		nl_be => "Energie (kcal)",
		pt => "Energia (kcal)",
		pl => "Wartość energetyczna (kcal)",
		ro => "Valoarea energetică (kcal)",
		rs => "Energetska vrednost (kcal)",
		ru => "Энергетическая ценность (kcal)",
		sl => "Energijska vrednost (kcal)",
		sk => "Energetická hodnota (kcal)",
		sv => "Energi (kcal)",
		tr => "Enerji (kcal)",
		zh => "能量 (kcal)",
		zh_CN => "能量 (kcal)",
		zh_HK => "能量 (kcal)",
		zh_TW => "能量 (kcal)",

		unit => "kcal",
	},
	"energy-from-fat" => {
		cs => "Energie z tuku",
		de => "Brennwert aus Fetten",
		en => "Energy from fat",
		fi => "Energia rasvasta",
		fr => "Énergie provenant des graisses",
		hu => "Energia zsírból",
		ja => "脂質からのエネルギー",
		pt => "Energia des gorduras",
		ro => "Valoarea energetică din grăsimi",
		ru => "Энергетическая ценность жиров",
		zh => "来自脂肪的能量",
		zh_CN => "来自脂肪的能量",
		zh_HK => "來自脂肪的能量",
		zh_TW => "來自脂肪的能量",
		unit => "kj",
		unit_us => "kcal",
		unit_ca => "kcal",
	},
	proteins => {
		ar => "البروتين",
		bg => "Белтъци",
		cs => "Bílkoviny",
		da => "Protein",
		de => "Eiweiß",
		el => "Πρωτεΐνες",
		en => "Proteins",
		en_synonyms => ["Protein"],
		es => "Proteínas",
		et => "Valgud",
		fa => "ﭘﺮﻭﺗﺌ‍ین",
		fi => "Proteiinit",
		fi_synonyms => ["Proteiini"],
		fr => "Protéines",
		fr_synonyms => ["Protéine", "Protéine brute"],
		ga => "Próitéin",
		he => "חלבונים",
		hu => "Fehérje",
		it => "Proteine",
		ja => "たんぱく質",
		lt => "Baltymai",
		lv => "Olbaltumvielas",
		mt => "Proteini",
		nl => "Eiwitten",
		nl_be => "Eiwitten",
		nb => "Protein",
		pl => "Białko",
		pt => "Proteínas",
		ro => "Proteine",
		rs => "Proteini",
		ru => "Белки",
		sk => "Bielkoviny",
		sl => "Beljakovine",
		sv => "Protein",
		tr => "Protein",
		zh => "蛋白质",
		zh_CN => "蛋白质",
		zh_HK => "蛋白質",
		zh_TW => "蛋白質",
	},
	casein => {
		ar => "كازين",
		be => "Казеін",
		bg => "Казеин",
		ca => "Caseïna",
		cs => "Kasein",
		cy => "Casein",
		da => "Kasein",
		de => "Casein",
		en => "casein",
		eo => "Kazeino",
		es => "Caseína",
		eu => "Kaseina",
		fa => "کازئین",
		fi => "Kaseiini",
		fr => "Caséine",
		ga => "Cáiséin",
		gl => "Caseína",
		gsw => "Casein",
		he => "קזאין",
		hu => "Kazein",
		hy => "Կազեին",
		id => "Kasein",
		io => "Kazeino",
		it => "Caseina",
		ja => "カゼイン",
		kk => "Казеин",
		kk_arab => "كازەىين",
		kk_cn => "كازەىين",
		kk_cyrl => "Казеин",
		kk_kz => "Казеин",
		kk_latn => "Kazeïn",
		kk_tr => "Kazeïn",
		ko => "카세인",
		nb => "Kasein",
		nl => "Caseïne",
		nl_be => "Caseïne",
		nn => "Kasein",
		pl => "Kazeina",
		pt => "Caseína",
		ro => "Cazeină",
		ru => "Казеин",
		scn => "Caseina",
		sco => "casein",
		sh => "Kazein",
		sl => "Kazein",
		sr => "казеин",
		sr_ec => "Казеин",
		sr_el => "Kazein",
		sv => "Kasein",
		tr => "Kazein",
		uk => "Казеїн",
		zh => "酪蛋白",
		zh => "酪蛋白",
		zh_CN => "酪蛋白",
		zh_HK => "酪蛋白",
		zh_TW => "酪蛋白",
	},
	nucleotides => {
		de => "Nukleotide",
		fa => "نوکلئوتید",
		fi => "Nukleotidit",
		fr => "Nucléotides",
		en => "Nucleotides",
		hu => "Nukleotidok",
		it => "Nucleotidi",
		ru => "Нуклеотиды",
		nl => "Nucleotiden",
		nl_be => "Nucleotiden",
		el => "Νουκλεοτίδια",
		ja => "ヌクレオチド",
		pt => "nucleotídeos",
		ro => "Nucleotide",
		zh => "核苷酸",
		zh_TW => "核苷酸",
		zh_HK => "核苷酸",
		zh_CN => "核苷酸",
	},
	"serum-proteins" => {
		de => "Serumprotein",
		el => "Πρωτεΐνες ορού",
		en => "Serum proteins",
		fi => "Plasmaproteiinit",
		ru => "Сывороточные белки",
		fr => "Protéines sériques",
		it => "Sieroproteine",
		ja => "血清たんぱく質",
		nl => "Plasmaproteïnen",
		nl_be => "Plasmaproteïnen",
		pt => "proteína plasmatica",
		ro => "Proteine ​​serice",
		zh => "血清蛋白",
		zh_CN => "血清蛋白",
		zh_HK => "血清蛋白",
		zh_TW => "血清蛋白",
	},
	carbohydrates => {
		ar => "الكاربوهايدريد",
		bg => "Въглехидрати",
		cs => "Sacharidy",
		da => "Kulhydrat",
		de => "Kohlenhydrate",
		el => "Υδατάνθρακες",
		en => "Carbohydrates",
		en_synonyms => ["carbohydrate"],
		es => "Hidratos de carbono",
		es_synonyms => ["Glúcidos"],
		et => "Süsivesikud",
		fa => "کربوهیدرات ها",
		fi => "Hiilihydraatit",
		fi_synonyms => ["hiilihydraatti"],
		fr => "Glucides",
		ga => "Carbaihiodráit",
		he => "פחמימות",
		hu => "Szénhidrát",
		it => "Carboidrati",
		ja => "炭水化物",
		lt => "Angliavandeniai",
		lv => "Ogļhidrāti",
		mt => "Karboidrati",
		nl => "Koolhydraten",
		nl_be => "Koolhydraten",
		nb => "Karbohydrat",
		pl => "Węglowodany",
		pt => "Hidratos de carbono",
		pt_br => "Carboidratos",
		pt_pt => "Hidratos de carbono",
		ro => "Glucide",
		rs => "Ugljeni hidrati",
		ru => "Углеводы",
		sk => "Sacharidy",
		sl => "Ogljikove hidrate",
		sv => "Kolhydrat",
		tr => "Karbonhidratlar",
		zh => "碳水化合物",
		zh_CN => "碳水化合物",
		zh_HK => "碳水化合物",
		zh_TW => "碳水化合物",
	},
	sugars => {
		ar => "السكر",
		bg => "Захари",
		cs => "Cukry",
		da => "Sukkerarter",
		de => "Zucker",
		el => "Σάκχαρα",
		en => "Sugars",
		en_synonyms => ["Sugar"],
		es => "Azúcares",
		et => "Suhkrud",
		fa => "شکر",
		fi => "Sokerit",
		fi_synonyms => ["sokeri"],
		fr => "Sucres",
		fr_synonyms => ["sucre"],
		ga => "Siúcraí",
		he => "סוכר",
		hu => "Cukrok",
		it => "Zuccheri",
		ja => "糖類",
		lt => "Cukrūs",
		lv => "Cukuri",
		mt => "Zokkor",
		nl => "Suikers",
		nl_be => "Suikers",
		nb => "Sukkerarter",
		pl => "Cukry",
		pt => "Açúcares",
		ro => "Zaharuri",
		rs => "Šećeri",
		ru => "Сахара",
		sk => "Cukry",
		sl => "Sladkorjev",
		sv => "Sockerarter",
		tr => "Şeker",
		zh => "糖",
		zh_CN => "糖",
		zh_HK => "糖",
		zh_TW => "糖",
	},
	"added-sugars" => {
		en => "Added sugars",
		fr => "Sucres ajoutés",
	},
	sucrose => {
		cs => "Sacharóza",
		de => "Saccharose",
		el => "Σουκρόζη",
		en => "Sucrose",
		es => "Sacarosa",
		fa => "ساکارز",
		fi => "Sakkaroosi",
		fr => "Saccharose",
		he => "סוכרוז",
		hu => "Szacharóz",
		it => "Saccarosio",
		ja => "スクロース",
		nl => "Sucrose",
		nl_be => "Sucrose",
		pt => "Sacarose",
		ro => "Zaharoză",
		rs => "Saharoza",
		ru => "Сахароза",
		zh => "蔗糖",
		zh_CN => "蔗糖",
		zh_HK => "蔗糖",
		zh_TW => "蔗糖",
	},
	glucose => {
		cs => "Glukóza",
		de => "Traubenzucker",
		el => "Γλυκόζη",
		en => "Glucose",
		es => "Glucosa",
		fi => "Glukoosi",
		fr => "Glucose",
		he => "גלוקוז",
		hu => "Glükóz",
		it => "Glucosio",
		ja => "グルコース",
		nl => "Glucose",
		nl_be => "Glucose",
		pt => "Glucose",
		ro => "Glucoză",
		ru => "Глюкоза (декстроза)",
		zh => "葡萄糖",
		zh_CN => "葡萄糖",
		zh_HK => "葡萄糖",
		zh_TW => "葡萄糖",
	},
	fructose => {
		de => "Fruchtzucker",
		el => "Φρουκτόζη",
		en => "Fructose",
		es => "Fructosa",
		fi => "Fruktoosi",
		fr => "Fructose",
		he => "פרוקטוז",
		hu => "Fruktóz",
		it => "Fruttosio",
		ja => "果糖",
		nl => "Fructose",
		nl_be => "Fructose",
		pt => "Frutose",
		rs => "Fruktoza",
		ro => "Fructoză",
		ru => "Фруктоза",
		zh => "果糖",
		zh_CN => "果糖",
		zh_HK => "果糖",
		zh_TW => "果糖",
	},
	lactose => {
		cs => "Laktóza",
		de => "Laktose",
		el => "Λακτόζη",
		en => "Lactose",
		es => "Lactosa",
		fi => "Laktoosi",
		fi_synonyms => ["Maitosokeri"],
		fr => "Lactose",
		he => "לקטוז",
		hu => "Laktóz",
		it => "Lattosio",
		ja => "乳糖",
		nl => "Lactose",
		nl_be => "Lactose",
		pt => "Lactose",
		rs => "Laktoza",
		ro => "Lactoză",
		ru => "Лактоза",
		zh => "乳糖",
		zh_CN => "乳糖",
		zh_HK => "乳糖",
		zh_TW => "乳糖",
	},
	maltose => {
		de => "Malzzucker",
		el => "Μαλτόζη",
		en => "Maltose",
		es => "Maltosa",
		fi => "Maltoosi",
		fr => "Maltose",
		he => "מלטוז",
		hu => "Maltóz",
		it => "Maltosio",
		ja => "麦芽糖",
		nl => "Maltose",
		nl_be => "Maltose",
		pt => "Maltose",
		ro => "Maltoză",
		ru => "Мальтоза",
		zh => "麦芽糖",
		zh_CN => "麦芽糖",
		zh_HK => "麥芽糖",
		zh_TW => "麥芽糖",
	},
	maltodextrins => {
		de => "Maltodextrine",
		el => "Μαλτοδεξτρίνες",
		en => "Maltodextrins",
		es => "Maltodextrinas",
		fi => "Maltodekstriinit",
		fi_synonyms => ["Maltodekstriini"],
		fr => "Maltodextrines",
		he => "מלטודקסטרינים",
		hu => "Maltodextrin",
		it => "Maltodestrine",
		ja => "マルトデキストリン",
		nl => "Maltodextrine",
		nl_be => "Maltodextrine",
		pt => "Maltodextrinas",
		ro => "Maltodextrină",
		ru => "Мальтодекстрин",
		zh => "麦芽糊精",
		zh_CN => "麦芽糊精",
		zh_HK => "麥芽糊精",
		zh_TW => "麥芽糊精",
	},
	starch => {
		bg => "Скорбяла",
		cs => "Škrob",
		da => "Stivelse",
		de => "Stärke",
		el => "Άμυλο",
		en => "Starch",
		es => "Almidón",
		et => "Tärklis",
		fi => "Tärkkelys",
		fr => "Amidon",
		ga => "Stáirse",
		he => "עמילן",
		hu => "Keményítő",
		it => "Amido",
		ja => "でん粉",
		lt => "Krakmolo",
		lv => "Ciete",
		mt => "Lamtu",
		nl => "Zetmeel",
		nl_be => "Zetmeel",
		pl => "Skrobia",
		pt => "Amido",
		ro => "Amidon",
		rs => "Skrob",
		ru => "Крахмал",
		sk => "Škrob",
		sl => "Škroba",
		sv => "Stärkelse",
		zh => "淀粉",
		zh_CN => "淀粉",
		zh_HK => "澱粉",
		zh_TW => "澱粉",
	},
	polyols => {
		bg => "Полиоли",
		cs => "Polyalkoholy",
		da => "Polyoler",
		de => "mehrwertige Alkohole (Polyole)",
		de_synonyms => ["Polyole"],
		el => "Πολυόλες",
		en => "Sugar alcohols (Polyols)",
		en_synonyms => ["Polyols"],
		es => "Azúcares alcohólicos (Polialcoholes)",
		es_synonyms => ["Polialcoholes"],
		et => "Polüoolid",
		fi => "Polyolit",
		fr => "Polyols",
		ga => "Polóil",
		he => "סוכר אלכוהולי (פוליאול)",
		hu => "Poliolok",
		it => "Polialcoli/polioli (alcoli degli zuccheri)",
		it_synonyms => ["alcoli degli zuccheri"],
		ja => "糖アルコール (ポリオール)",
		lt => "Poliolių",
		lv => "Polioli",
		mt => "Polioli",
		nl => "Polyolen",
		nl_be => "Polyolen",
		pl => "Alkohole wielowodorotlenowe",
		pt => "Açúcares alcoólicos (poliálcools, polióis)",
		ro => "Polioli",
		ru => "Многоатомные спирты (полиолы)",
		sk => "Alkoholické cukry (polyoly)",
		sl => "Poliolov",
		sv => "Polyoler",
		zh => "糖醇（多元醇）",
		zh_CN => "糖醇（多元醇）",
		zh_HK => "多元醇",
		zh_TW => "多元醇",
	},
	fat => {
		ar=> "الدهون",
		bg => "Мазнини",
		cs => "Tuky",
		da => "Fedt",
		de => "Fett",
		el => "Λιπαρά",
		en => "Fat",
		en_synonyms => ["Total fat", "Lipids"],
		es => "Grasas",
		es_synonyms => ["Materias grasas"],
		et => "Rasvad",
		fi => "Rasvat",
		fr => "Matières grasses / Lipides",
		fr_synonyms => ["Matières grasses", "Matière grasse", "Lipides", "Graisses", "Graisse"],
		ga => "Saill",
		he => "שומנים",
		hu => "Zsír",
		it => "Grassi",
		ja => "脂質",
		lt => "Riebalai",
		lv => "Tauki",
		mt => "Xaħmijiet",
		nl => "Vetten",
		nl_be => "Vetten",
		nb => "Fett",
		pl => "Tłuszcz",
		pt => "Gorduras",
		pt_pt => "Lípidos",
		ro => "Grăsimi",
		rs => "Masti",
		ru => "Жиры",
		sk => "Tuky",
		sl => "Maščobe",
		sv => "Fett",
		zh => "脂肪",
		zh_CN => "脂肪",
		zh_HK => "脂肪",
		zh_TW => "脂肪",
	},
	'saturated-fat' => {
		en => "Saturated fat",
		bg => "Наситени мастни киселини",
		cs => "Nasycené mastné kyseliny",
		da => "Mættede fedtsyrer",
		de => "gesättigte Fettsäuren",
		el => "Κορεσμένα λιπαρά",
		es => "Grasas saturadas",
		es => "Ácidos grasos saturados",
		et => "Küllastunud rasvhapped",
		fi => "Tyydyttyneet rasvat",
		fr => "Acides gras saturés",
		fr_synonyms => ["Saturés", "AGS"],
		ga => "sáSitheáin saill",
		he => "שומן רווי",
		hu => "Telített zsírsavak",
		it =>"Acidi Grassi saturi",
		ja => "飽和脂肪",
		lt => "Sočiosios riebalų rūgštys",
		lv => "Piesātinātās taukskābes",
		mt => "Saturati xaħmijiet",
		nl => "Verzadigde vetzuren",
		nl_be => "Verzadigde vetzuren",
		nb => "Mettet fett",
		pl => "Kwasy tłuszczowe nasycone",
		pt => "Gorduras saturadas",
		pt_pt => "Ácidos gordos saturados",
		ro => "Acizi grași saturați",
		rs => "Zasićene masne kiseline",
		ru => "Насыщенные жиры",
		sk => "Nasýtené mastné kyseliny",
		sl => "Nasičene maščobe",
		sv => "Mättat fett",
		zh => "饱和脂肪",
		zh_CN => "饱和脂肪",
		zh_HK => "飽和脂肪",
		zh_TW => "飽和脂肪",
	},
	'butyric-acid' => {
		en => "Butyric acid (4:0)",
		de => "Buttersäure (4:0)",
		el => "Βουτυρικό οξύ (4:0)",
		es => "Ácido butírico (4:0)",
		fi => "Voihappo (4:0)",
		fi_synonyms => ["Butaanihappo (4:0)"],
		fr => "Acide butyrique (4:0)",
		he => "חומצה בוטירית (4:0)",
		ja => "酪酸 (4:0)",
		nl => "Boterzuur (4:0)",
		nl_be => "Boterzuur (4:0)",
		pt => "Ácido butírico (4:0)",
		ro => "Acid butiric (4:0)",
		ru => "Масляная кислота (4:0)",
		zh => "丁酸 (4:0)",
		zh_CN => "丁酸 (4:0)",
		zh_HK => "丁酸 (4:0)",
		zh_TW => "丁酸 (4:0)",
	},
	'caproic-acid' => {
		en => "Caproic acid (6:0)",
		de => "Capronsäure (6:0)",
		el => "Καπροϊκό οκύ (6:0)",
		es => "Ácido caproico (6:0)",
		fi => "Kapronihappo (6:0)",
		fr => "Acide caproïque (6:0)",
		he => "חומצה קפרואית (6:0)",
		ja => "カプロン酸 (6:0)",
		nl => "Capronzuur (6:0)",
		nl_be => "Capronzuur (6:0)",
		pt => "Ácido capróico (6:0)",
		ro => "Acid caproic (6:0)",
		ru => "Капроновая кислота (6:0)",
		zh => "己酸 (6:0)",
		zh_CN => "己酸 (6:0)",
		zh_HK => "己酸 (6:0)",
		zh_TW => "己酸 (6:0)",
	},
	'caprylic-acid' => {
		en => "Caprylic acid (8:0)",
		de => "Caprylsäure (8:0)",
		el => "Καπρυλικό οξύ (8:0)",
		es => "Ácido caprílico (8:0)",
		fi => "Kapryylihappo (8:0)",
		fr => "Acide caproïque (8:0)",
		he => "חומצה קפרילית (8:0)",
		ja => "カプリル酸 (8:0)",
		nl => "Octaanzuur (8:0)",
		nl_be => "Octaanzuur (8:0)",
		pt => "Ácido caprílico (8:0)",
		ro => "Acid caprilic (8:0)",
		ru => "Каприловая кислота (8:0)",
		zh => "辛酸 (8:0)",
		zh_CN => "辛酸 (8:0)",
		zh_HK => "辛酸 (8:0)",
		zh_TW => "辛酸 (8:0)",
	},
	'capric-acid' => {
		en => "Capric acid (10:0)",
		de => "Caprinsäure (10:0)",
		el => "Καπρικό οξύ (10:0)",
		es => "Ácido cáprico (10:0)",
		fi => "Kapriinihappo (10:0)",
		fr => "Acide caprique (10:0)",
		he => "חומצה קפרית (10:0)",
		ja => "カプリン酸 (10:0)",
		nl => "Decaanzuur (10:0)",
		nl_be => "Decaanzuur (10:0)",
		pt => "Ácido cáprico (10:0)",
		ro => "Acid capric (10:0)",
		ru => "Каприновая кислота (10:0)",
		zh => "癸酸 (10:0)",
		zh_CN => "癸酸 (10:0)",
		zh_HK => "癸酸 (10:0)",
		zh_TW => "癸酸 (10:0)",
	},
	'lauric-acid' => {
		en => "Lauric acid (12:0)",
		de => "Laurinsäure",
		el => "Λαυρικό οξύ/n-δωδεκανοϊκό οξύ (12:0)",
		es => "Ácido láurico (12:0)",
		fi => "Lauriinihappo (12:0)",
		fr => "Acide laurique (12:0)",
		he => "חומצה לאורית (12:0)",
		nl => "Laurinezuur (12:0)",
		nl_be => "Laurinezuur (12:0)",
		pt => "Ácido láurico (12:0)",
		ro => "Acid lauric (12:0)",
		ru => "Лауриновая кислота (12:0)",
		zh => "十二酸 (12:0)",
		zh_CN => "十二酸 (12:0)",
		zh_HK => "十二酸 (12:0)",
		zh_TW => "十二酸 (12:0)",
	},
	'myristic-acid' => {
		en => "Myristic acid (14:0)",
		de => "Myristinsäure (14:0)",
		el => "Μυριστικό οξύ (14:0)",
		es => "Ácido mirístico (14:0)",
		fi => "Myristiinihappo (14:0)",
		fr => "Acide myristique (14:0)",
		he => "חומצה מיריסטית (14:0)",
		nl => "Myristinezuur (14:0)",
		pt => "Ácido mirístico (14:0)",
		ro => "Acidul myristic (14:0)",
		ru => "Миристиновая кислота (14:0)",
		zh => "十四酸 (14:0)",
		zh_CN => "十四酸 (14:0)",
		zh_HK => "十四酸 (14:0)",
		zh_TW => "十四酸 (14:0)",
	},
	'palmitic-acid' => {
		en => "Palmitic acid (16:0)",
		de => "Palitinsäure (16:0)",
		el => "Παλμιτικό οξύ (16:0)",
		es => "Ácido palmítico (16:0)",
		fi => "Palmitiinihappo (16:0)",
		fr => "Acide palmitique (16:0)",
		he => "חומצה פלמיטית (16:0)",
		nl => "Palmitinezuur (16:0)",
		nb => "Palmitinsyre (16:0)",
		pt => "Ácido palmítico (16:0)",
		ro => "Acidul palmitic (16:0)",
		ru => "Пальмитиновая кислота (16:0)",
		zh => "十六酸 (16:0)",
		zh_CN => "十六酸 (16:0)",
		zh_HK => "十六酸 (16:0)",
		zh_TW => "十六酸 (16:0)",
	},
	'stearic-acid' => {
		en => "Stearic acid (18:0)",
		de => "Stearinsäure (18:0)",
		el => "Στεατικό/Στεαρικό οξύ (18:0)",
		es => "Ácido esteárico (18:0)",
		fi => "Steariinihappo (18:0)",
		fr => "Acide stéarique (18:0)",
		he => "חומצה סטארית (18:0)",
		nl => "Stearinezuur (18:0)",
		nl_be => "Stearinezuur (18:0)",
		pt => "Ácido esteárico (18:0)",
		ro => "Acid stearic (18:0)",
		ru => "Стеариновая кислота (18:0)",
		zh => "十八酸 (18:0)",
		zh_CN => "十八酸 (18:0)",
		zh_HK => "十八酸 (18:0)",
		zh_TW => "十八酸 (18:0)",
	},
	'arachidic-acid' => {
		en => "Arachidic acid (20:0)",
		de => "Arachinsäure (20:0)",
		el => "Αραχιδικό οξύ (20:0)",
		es => "Ácido araquídico (20:0)",
		fi => "Arakidihappo (20:0)",
		fi_synonyms => ["Eikosaanihappo (20:0)", "Ikosaanihappo (20:0)"],
		fr => "Acide arachidique / acide eicosanoïque (20:0)",
		nl => "Arachidinezuur (20:0)",
		nl_be => "Arachidinezuur (20:0)",
		pt => "Ácido araquídico (20:0)",
		ro => "Acid arachidic (20:0)",
		ru => "Арахиновая кислота (20:0)",
		zh => "二十酸 (20:0)",
		zh_CN => "二十酸 (20:0)",
		zh_HK => "二十酸 (20:0)",
		zh_TW => "二十酸 (20:0)",
	},
	'behenic-acid' => {
		en => "Behenic acid (22:0)",
		de => "Behensäure (22:0)",
		el => "Βεχενικό οξύ/εικοσαδυενοϊκό οξύ (22:0)",
		es => "Ácido behénico (22:0)",
		fi => "Beheenihappo (22:0)",
		fr => "Acide béhénique (22:0)",
		he => "חומצה בהנית (22:0)",
		nl => "Beheenzuur (22:0)",
		nl_be => "Beheenzuur (22:0)",
		pt => "Ácido beénico (22:0)",
		ro => "Acid behenic (22:0)",
		ru => "Бегеновая кислота (22:0)",
		zh => "二十二酸 (22:0)",
		zh_CN => "二十二酸 (22:0)",
		zh_HK => "二十二酸 (22:0)",
		zh_TW => "二十二酸 (22:0)",
	},
	'lignoceric-acid' => {
		en => "Lignoceric acid (24:0)",
		de => "Lignocerinsäure (24:0)",
		el => "Λιγνοκηρικό οξύ (24:0)",
		es => "Ácido lignocérico (24:0)",
		fi => "Lignoseriinihappo (24:0)",
		fr => "Acide lignocérique (24:0)",
		nl => "Lignocerinezuur (24:0)",
		nl_be => "Lignocerinezuur (24:0)",
		pt => "Ácido lignocérico (24:0)",
		ro => "Acidul lignoceric (24:0)",
		ru => "Лигноцериновая кислота (24:0)",
		zh => "二十四酸 (24:0)",
		zh_CN => "二十四酸 (24:0)",
		zh_HK => "二十四酸 (24:0)",
		zh_TW => "二十四酸 (24:0)",
	},
	'cerotic-acid' => {
		en => "Cerotic acid (26:0)",
		de => "Cerotinsäure (26:0)",
		el => "Κηροτικό οξύ (26:0)",
		es => "Ácido cerótico (26:0)",
		fi => "Keroottihappo (26:0)",
		fr => "Acide cérotique (26:0)",
		nl => "Cerotinezuur (26:0)",
		nl_be => "Cerotinezuur (26:0)",
		pt => "Ácido cerótico (26:0)",
		ro => "Acidul cerotic (26:0)",
		ru => "Церотиновая кислота (26:0)",
		zh => "二十六酸 (26:0)",
		zh_CN => "二十六酸 (26:0)",
		zh_HK => "二十六酸 (26:0)",
		zh_TW => "二十六酸 (26:0)",
	},
	'montanic-acid' => {
		en => "Montanic acid (28:0)",
		de => "Montansäure (28:0)",
		el => "Μοντανικό οξύ (28:0)",
		es => "Ácido montánico (28:0)",
		fi => "Montaanihappo (28:0)",
		fr => "Acide montanique (28:0)",
		nl => "Montaanzuur (28:0)",
		nl_be => "Montaanzuur (28:0)",
		pt => "Ácido montânico (28:0)",
		ro => "Acid montanic (28:0)",
		ru => "Монтановая кислота (28:0)",
		zh => "二十八酸 (28:0)",
		zh_CN => "二十八酸 (28:0)",
		zh_HK => "二十八酸 (28:0)",
		zh_TW => "二十八酸 (28:0)",
	},
	'melissic-acid' => {
		en => "Melissic acid (30:0)",
		de => "Melissinsäure (30:0)",
		el => "Μελισσικό οξύ (30:0)",
		es => "Ácido melísico (30:0)",
		fi => "Triakontaanihappo (30:0)",
		fr => "Acide mélissique (30:0)",
		nl => "Melissinezuur (30:0)",
		nl_be => "Melissinezuur (30:0)",
		pt => "Ácido melíssico (30:0)",
		ru => "Мелиссовая кислота (30:0)",
		zh => "三十酸 (30:0)",
		zh_CN => "三十酸 (30:0)",
		zh_HK => "三十酸 (30:0)",
		zh_TW => "三十酸 (30:0)",
	},
	'monounsaturated-fat' => {
		en => "Monounsaturated fat",
		bg => "Мононенаситени мастни киселини",
		cs => "Mononenasycené mastné kyseliny",
		da => "Enkeltumættede fedtsyrer",
		de => "einfach ungesättigte Fettsäuren",
		el => "Μονοακόρεστα λιπαρά",
		es => "Grasas monoinsaturadas",
		et => "Monoküllastumata rasvhapped",
		fi => "Kertatyydyttymättömät rasvat",
		fi_synonyms => ["Kertatyydyttymättömät rasvahapot", "Yksittäistyydyttymättömät rasvahapot"],
		fr => "Acides gras monoinsaturés",
		fr_synonyms => ["Acides gras mono-insaturés"],
		ga => "Monai-neamhsháitheáin saill",
		he => "שומן חד בלתי רווי",
		hu => "Egyszeresen telítetlen zsírsavak",
		it=> "Acidi grassi monoinsaturi",
		lt => "Mononesočiosios riebalų rūgštys",
		lv => "Mononepiesātinātās taukskābes",
		mt => "Mono-insaturati xaħmijiet",
		nl => "Enkelvoudig onverzadigde vetzuren",
		nl_be => "Enkelvoudig onverzadigde vetzuren",
		nb => "Enumettet fettsyre",
		pl => "Kwasy tłuszczowe jednonienasycone",
		pt => "Gorduras monoinsaturadas",
		pt_pt => "Ácidos gordos monoinsaturados",
		ro => "Acizi grași mononesaturați",
		ru => "Мононенасыщенные жиры",
		sk => "Mononenasýtené mastné kyseliny",
		sl => "Enkrat nenasičene maščobe",
		sv => "Enkelomättat fett",
		zh => "单不饱和脂肪",
		zh_CN => "单不饱和脂肪",
		zh_HK => "單元不飽和脂肪",
		zh_TW => "單元不飽和脂肪",
	},
	'omega-9-fat' => {
		de => "Omega-9-Fettsäuren",
		el => "Ωμέγα-9 λιπαρά",
		en => "Omega 9 fatty acids",
		es => "Ácidos grasos Omega 9",
		fi => "Omega-9-rasvahapot",
		fr => "Acides gras Oméga 9",
		fr_synonyms => ["Oméga 9"],
		he => "אומגה 9",
		hu => "Omega-9 zsírsavak",
		it=> "Acidi grassi Omega 9",
		nl => "Omega 9 vetzuren",
		nl_be => "Omega 9 vetzuren",
		pt => "Ácidos Graxos Ômega 9",
		pt_pt => "Ácidos gordos Ómega 9",
		ro => "Acizi grași omega-9",
		ru => "Омега-9 жирные кислоты",
		zh => "Omega-9 脂肪酸",
		zh_CN => "Omega-9 脂肪酸",
		zh_HK => "Omega-9 脂肪酸",
		zh_TW => "Omega-9 脂肪酸",
	},
	'oleic-acid' => {
		en => "Oleic acid (18:1 n-9)",
		de => "Ölsäure (18:1 n-9)",
		el => "Ολεϊκό οξύ (18:1 n-9)",
		es => "Ácido oleico (18:1 n-9)",
		fi => "Oleiinihappo (18:1 n-9)",
		fi_synonyms => ["Öljyhappo (18:1 n-9)"],
		fr => "Acide oléique (18:1 n-9)",
		he => "חומצה אולאית",
		nl => "Oliezuur (18:1 n-9)",
		nl_be => "Oliezuur (18:1 n-9)",
		pt => "Ácido oleico (18:1 n-9)",
		ro => "Acidul oleic (18:1 n-9)",
		ru => "Олеиновая кислота (18:1 n-9)",
		zh => "油酸 (18:1 n-9)",
		zh_CN => "油酸 (18:1 n-9)",
		zh_HK => "油酸 (18:1 n-9)",
		zh_TW => "油酸 (18:1 n-9)",
	},
	'elaidic-acid' => {
		en => "Elaidic acid (18:1 n-9)",
		de => "Elaidinsäure (18:1 n-9)",
		el => "Ελαϊδικό οξύ (18:1 n-9)",
		es => "Ácido elaídico (18:1 n-9)",
		fi => "Elaidiinihappo (18:1 n-9)",
		fr => "Acide élaïdique (18:1 n-9)",
		nl => "Elaïdinezuur (18:1 n-9)",
		nl_be => "Elaïdinezuur (18:1 n-9)",
		pt => "Ácido elaídico (18:1 n-9)",
		ro => "Acid elaidic (18:1 n-9)",
		ru => "Элаидиновая кислота (18:1 n-9)",
		zh => "反油酸 (18:1 n-9)",
		zh_CN => "反油酸 (18:1 n-9)",
		zh_HK => "反油酸 (18:1 n-9)",
		zh_TW => "反油酸 (18:1 n-9)",
	},
	'gondoic-acid' => {
		en => "Gondoic acid (20:1 n-9)",
		de => "Gondosäure (20:1 n-9)",
		el => "Γονδοϊκό οξύ (20:1 n-9)",
		es => "Ácido gondoico (20:1 n-9)",
		fi => "Eikoseenihappo (20:1 n-9)",
		fr => "Acide gadoléique (20:1 n-9)",
		nl => "Eicoseenzuur (20:1 n-9)",
		nl_be => "Eicoseenzuur (20:1 n-9)",
		pt => "Ácido gondoico (20:1 n-9)",
		ro => "Acidul gondoic (20:1 n-9)",
		ru => "Гондоиновая кислота (20:1 n-9)",
		zh => "11-二十碳烯酸 (20:1 n-9)",
		zh_CN => "11-二十碳烯酸 (20:1 n-9)",
		zh_HK => "11-二十碳烯酸 (20:1 n-9)",
		zh_TW => "11-二十碳烯酸 (20:1 n-9)",
	},
	'mead-acid' => {
		en => "Mead acid (20:3 n-9)",
		de => "Mead'sche Säure (20:3 n-9)",
		el => "Οξύ Mead (20:3 n-9)",
		es => "Ácido Mead (20:3 n-9)",
		fi => "Meadin happo (20:3 n-9)",
		fr => "Acide de Mead (20:3 n-9)",
		nl => "Meadzuur (20:3 n-9)",
		nl_be => "Meadzuur (20:3 n-9)",
		pt => "Ácido de Mead (20:3 n-9)",
		ru => "Мидовая кислота (20:3 n-9)",
		zh => "二十碳三烯酸 (20:3 n-9)",
		zh_CN => "二十碳三烯酸 (20:3 n-9)",
		zh_HK => "二十碳三烯酸 (20:3 n-9)",
		zh_TW => "二十碳三烯酸 (20:3 n-9)",
	},
	'erucic-acid' => {
		en => "Erucic acid (22:1 n-9)",
		de => "Erucasäure (18:1 n-9)",
		el => "Ερουκικό οξύ (22:1 n-9)",
		es => "Ácido erúcico (22:1 n-9)",
		fi => "Erukahappo (22:1 n-9)",
		fr => "Acide érucique (22:1 n-9)",
		nl => "Erucazuur (22:1 n-9)",
		nl_be => "Erucazuur (22:1 n-9)",
		pt => "Ácido erúcico (22:1 n-9)",
		ro => "Acid erucic (22:1 n-9)",
		ru => "Эруковая кислота (22:1 n-9)",
		zh => "芥酸 (22:1 n-9)",
		zh_CN => "芥酸 (22:1 n-9)",
		zh_HK => "芥酸 (22:1 n-9)",
		zh_TW => "芥酸 (22:1 n-9)",
	},
	'nervonic-acid' => {
		en => "Nervonic acid (24:1 n-9)",
		de => "Nervonsäure (24:1 n-9)",
		el => "Νερβονικό (24:1 n-9)",
		es => "Ácido nervónico (24:1 n-9)",
		fi => "Nervonihappo (24:1 n-9)",
		fr => "Acide nervonique (24:1 n-9)",
		nl => "Nervonzuur (24:1 n-9)",
		nl_be => "Nervonzuur (24:1 n-9)",
		pt => "Ácido nervônico (24:1 n-9)",
		pt_pt => "Ácido nervónico (24:1 n-9)",
		ro => "Acidul nervonic (24:1 n-9)",
		ru => "Нервоновая кислота (24:1 n-9)",
		zh => "二十四碳烯酸 (24:1 n-9)",
		zh_CN => "二十四碳烯酸 (24:1 n-9)",
		zh_HK => "二十四碳烯酸 (24:1 n-9)",
		zh_TW => "二十四碳烯酸 (24:1 n-9)",
	},
	'polyunsaturated-fat' => {
		en => "Polyunsaturated fat",
		bg => "Полиненаситени мастни киселини",
		cs => "Polynenasycené mastné kyseliny",
		da => "Flerumættede fedtsyrer",
		de => "mehrfach ungesättigte Fettsäuren",
		el => "Πολυακόρεστα λιπαρά",
		es => "Grasas poliinsaturadas",
		et => "Polüküllastumata rasvhapped",
		fi => "Monityydyttymättömät rasvat",
		fi_synonyms => ["Monityydyttymättömät rasvahapot"],
		fr => "Acides gras polyinsaturés",
		fr_synonyms => ["Acides gras poly-insaturés"],
		ga => "Pola-neamhsháitheáin saill",
		he => "שומן רב בלתי רווי",
		hu => "Többszörösen telítetlen zsírsavak",
		it => "Acidi grassi polinsaturi",
		lt => "Polinesočiosios riebalų rūgštys",
		lv => "Polinepiesātinātās taukskābes",
		mt => "Poli-insaturati xaħmijiet",
		nl => "Meervoudig onverzadigde vetzuren",
		nl_be => "Meervoudig onverzadigde vetzuren",
		nb => "Flerumettet fettsyrer",
		pl => "Kwasy tłuszczowe wielonienasycone",
		pt => "Gorduras poli-insaturadas",
		pt_pt => "Ácidos gordos polinsaturados",
		ro => "Acizi grași polinesaturați",
		ru => "Полиненасыщенные жиры",
		sk => "Polynenasýtené mastné kyseliny",
		sl => "Večkrat nenasičene maščobe",
		sv => "Fleromättat fett",
		zh => "多元不饱和酸",
		zh_CN => "多元不饱和酸",
		zh_HK => "多元不飽和酸",
		zh_TW => "多元不飽和酸",
	},
	'omega-3-fat' => {
		en => "Omega 3 fatty acids",
		cs => "Omega 3 mastné kyseliny",
		de => "Omega-3-Fettsäuren",
		el => "Ωμέγα-3 λιπαρά",
		es => "Ácidos grasos Omega 3",
		fi => "Omega-3-rasvahapot",
		fr => "Acides gras Oméga 3",
		fr_synonyms => ["Oméga 3"],
		he => "אומגה 3",
		hu => "Omega-3 zsírsavak",
		it=> "Acidi grassi Omega 3",
		nl => "Omega 3-vetzuren",
		nl_be => "Omega 3-vetzuren",
		pt => "Ácidos graxos Ômega 3",
		pt_pt => "Ácidos gordos Ómega 3",
		ro => "Acizi grași omega-3",
		ru => "Омега-3 жирные кислоты",
		zh => "Omega 3 脂肪酸",
		zh_CN => "Omega 3 脂肪酸",
		zh_HK => "Omega 3 脂肪酸",
		zh_TW => "Omega 3 脂肪酸",
	},
	'alpha-linolenic-acid' => {
		en => "Alpha-linolenic acid / ALA (18:3 n-3)",
		de => "A-Linolensäure (18:3 n-3)",
		el => "Α-λινολενικό οξύ/ ALA (18:3 n-3)",
		es => "Ácido alfa-linolénico / ALA (18:3 n-3)",
		fi => "Alfalinoleenihappo / ALA (18:3 n-3)",
		fr => "Acide alpha-linolénique / ALA (18:3 n-3)",
		nl => "Alfa-linoleenzuur / ALA (18:3 n-3)",
		nl_be => "Alfa-linoleenzuur / ALA (18:3 n-3)",
		pt => "Ácido alfa-linolênico / ALA (18:3 n-3)",
		pt_pt => "Ácido alfa-linolénico / ALA (18:3 n-3)",
		ro => "Acid alfa-linolenic / ALA (18:3 N-3)",
		ru => "Альфа-линоленовая кислота / (АЛК) (18:3 n-3)",
		zh => "α-亚麻酸 / ALA (18:3 n-3)",
		zh_CN => "α-亚麻酸 / ALA (18:3 n-3)",
		zh_HK => "α-亞麻酸 / ALA (18:3 n-3)",
		zh_TW => "α-亞麻酸 / ALA (18:3 n-3)",
	},
	'eicosapentaenoic-acid' => {
		en => "Eicosapentaenoic acid / EPA (20:5 n-3)",
		de => "Eicosapentaensäure (20:5 n-3)",
		el => "Εικοσιπεντανοϊκο οξύ / EPA (20:5 n-3)",
		es => "Ácido eicosapentaenoico / EPA (20:5 n-3)",
		fi => "Eikosapentaeenihappo / EPA (20:5 n-3)",
		fr => "Acide eicosapentaénoïque / EPA (20:5 n-3)",
		fr_synonyms => ["Oméga 3 EPA"],
		nl => "Eicosapentaeenzuur / EPA (20:5 n-3)",
		nl_be => "Eicosapentaeenzuur / EPA (20:5 n-3)",
		pt => "Ácido eicosapentaenóico / EPA (20:5 n-3)",
		ro => "Acid eicosapentaenoic / EPA (20: 5 n-3)",
		ru => "Эйкозапентаеновая кислота / (ЭПК) (20:5 n-3)",
		zh => "二十碳五酸 / EPA (20:5 n-3)",
		zh_CN => "二十碳五酸 / EPA (20:5 n-3)",
		zh_HK => "二十碳五酸 / EPA (20:5 n-3)",
		zh_TW => "二十碳五酸 / EPA (20:5 n-3)",
	},
	'docosahexaenoic-acid' => {
		en => "Docosahexaenoic acid / DHA (22:6 n-3)",
		de => "Docosahexaensäure (22:6 n-3)",
		el => "Δοκοσαεξανοϊκο οξύ / DHA (22:6 n-3)",
		es => "Ácido docosahexaenoico / DHA (22:6 n-3)",
		fi => "Dokosaheksaeenihappo / DHA (22:6 n-3)",
		fr => "Acide docosahexaénoïque / DHA (22:6 n-3)",
		fr_synonyms => ["Oméga 3 DHA"],
		nl => "Docosahexaeenzuur / DHA (22:6 n-3)",
		nl_be => "Docosahexaeenzuur / DHA (22:6 n-3)",
		pt => "Ácido docosa-hexaenóico / DHA (22:6 n-3)",
		ro => "Acid docosahexaenoic / DHA (22:6 n-3)",
		ru => "Докозагексаеновая кислота / (ДГК) (22:6 n-3)",
		zh => "二十二碳六酸 / DHA (22:6 n-3)",
		zh_CN => "二十二碳六酸 / DHA (22:6 n-3)",
		zh_HK => "二十二碳六酸 / DHA (22:6 n-3)",
		zh_TW => "二十二碳六酸 / DHA (22:6 n-3)",
	},
	'omega-6-fat' => {
		en => "Omega 6 fatty acids",
		de => "Omega-6-Fettsäuren",
		el => "Ωμέγα-6 λιπαρά",
		es => "Ácidos grasos Omega 6",
		fi => "Omega-6-rasvahapot",
		fr => "Acides gras Oméga 6",
		fr_synonyms => ["Oméga 6"],
		he => "אומגה 6",
		hu => "Omega-6 zsírsavak",
		it=> "Acidi grassi Omega 6",
		nl => "Omega 6-vetzuren",
		nl_be => "Omega 6-vetzuren",
		pt => "Ácidos Graxos Ômega 6",
		pt_pt => "Ácidos gordos Ómega 6",
		ro => "Acizi grași omega-6",
		ru => "Омега-6 жирные кислоты",
		zh => "Omega 6 脂肪酸",
		zh_CN => "Omega 6 脂肪酸",
		zh_HK => "Omega 6 脂肪酸",
		zh_TW => "Omega 6 脂肪酸",
	},
	'linoleic-acid' => {
		en => "Linoleic acid / LA (18:2 n-6)",
		el => "Λινολεϊκό οξύ / LA (18:2 n-6)",
		es => "Ácido linoleico / LA (18:2 n-6)",
		fi => "Linolihappo / LA (18:2 n-6)",
		fr => "Acide linoléique / LA (18:2 n-6)",
		nl => "Linolzuur / LA (18:2 n-6)",
		nl_be => "Linolzuur / LA (18:2 n-6)",
		pt => "Ácido linoleico / LA (18:2 n-6)",
		ro => "Acid linoleic / LA (18:2 n-6)",
		ru => "Линолевая кислота / (ЛК) 18:2 (n−6)",
		zh => "亚油酸 / LA (18:2 n-6)",
		zh_CN => "亚油酸 / LA (18:2 n-6)",
		zh_HK => "亞油酸 / LA (18:2 n-6)",
		zh_TW => "亞油酸 / LA (18:2 n-6)",
	},
	'arachidonic-acid' => {
		en => "Arachidonic acid / AA / ARA (20:4 n-6)",
		el => "Αραχιδονικό οξύ / AA / ARA (20:4 n-6)",
		es => "Ácido araquidónico / AA / ARA (20:4 n-6)",
		fi => "Arakidonihappo / AA / ARA (20:4 n-6)",
		fr => "Acide arachidonique / AA / ARA (20:4 n-6)",
		he => "חומצה ארכידונית / AA / ARA (20:4 n-6)",
		nl => "Arachidonzuur / AA / ARA (20:4 n-6)",
		nl_be => "Arachidonzuur / AA / ARA (20:4 n-6)",
		pt => "Ácido araquidônico / AA / ARA (20:4 n-6)",
		pt_pt => "Ácido araquidónico / AA / ARA (20:4 n-6)",
		ro => "Acid arachidonic / AA / ARA (20:4 n-6)",
		ru => "Арахидоновая кислота / (АК) 20:4 (n−6)",
		zh => "花生四烯酸 / AA / ARA (20:4 n-6)",
		zh_CN => "花生四烯酸 / AA / ARA (20:4 n-6)",
		zh_HK => "花生四烯酸 / AA / ARA (20:4 n-6)",
		zh_TW => "花生四烯酸 / AA / ARA (20:4 n-6)",
	},
	'gamma-linolenic-acid' => {
		en => "Gamma-linolenic acid / GLA (18:3 n-6)",
		el => "Γ-λινολενικό οξύ / GLA (18:3 n-6)",
		es => "Ácido gamma-linolénico / GLA (18:3 n-6)",
		fi => "Gammalinoleenihappo / GLA (18:3 n-6)",
		fi_synonyms => ["Gamoleenihappo"],
		fr => "Acide gamma-linolénique / GLA (18:3 n-6)",
		nl => "Gamma-linoleenzuur / GLA (18:3 n-6)",
		nl_be => "Gamma-linoleenzuur / GLA (18:3 n-6)",
		pt => "Ácido gama-linolênico / GLA (18:3 n-6)",
		pt_pt => "Ácido gama-linolénico / GLA (18:3 n-6)",
		ro => "Acid gama-linolenic / GLA (18:3 n-6)",
		ru => "γ-линоленовая кислота / (GLA) 18:3 (n−6)",
		zh => "γ-亚麻酸 / GLA (18:3 n-6)",
		zh_CN => "γ-亚麻酸 / GLA (18:3 n-6)",
		zh_HK => "γ-亞麻酸 / GLA (18:3 n-6)",
		zh_TW => "γ-亞麻酸 / GLA (18:3 n-6)",
	},
	'dihomo-gamma-linolenic-acid' => {
		en => "Dihomo-gamma-linolenic acid / DGLA (20:3 n-6)",
		el => "Διχομο-γ-λινολεϊκό οξύ / DGLA (20:3 n-6)",
		es => "Ácido dihomo-gamma-linolénico / DGLA (20:3 n-6)",
		fi => "Dihomo-gammalinoleenihappo / DGLA (20:3 n-6)",
		fr => "Acide dihomo-gamma-linolénique / DGLA (20:3 n-6)",
		nl => "Dihomo-gammalinoleenzuur / DGLA (20:3 n-6)",
		nl_be => "Dihomo-gammalinoleenzuur / DGLA (20:3 n-6)",
		pt => "Ácido dihomo-gama-linolênico / DGLA (20:3 n-6)",
		pt_pt => "Ácido dihomo-gama-linolénico / DGLA (20:3 n-6)",
		ro => "Acid dihomo-gamma-linolenic / DGLA (20:3 n-6)",
		ru => "Дигомо-γ-линоленовая кислота / (ДГДК) 20:3 (n−6)",
		zh => "二高-γ-亚麻酸 / DGLA (20:3 n-6)",
		zh_CN => "二高-γ-亚麻酸 / DGLA (20:3 n-6)",
		zh_HK => "二高-γ-亞麻酸 / DGLA (20:3 n-6)",
		zh_TW => "二高-γ-亞麻酸 / DGLA (20:3 n-6)",
	},

	'trans-fat' => {
		en => "Trans fat",
		cs => "Trans tuky",
		de => "Trans-Fettsäuren",
		el => "Τρανς λιπαρά",
		es => "Grasas trans",
		fi => "Transrasva",
		fi_synonyms => ["transrasvahappo"],
		fr => "Acides gras trans",
		he => "שומן טראנס - שומן בלתי רווי",
		hu => "Transz-zsírsav",
		it => "Acidi grassi trans",
		nl => "Transvetten",
		nl_be => "Transvetten",
		pt => "Gorduras trans",
		pt_pt => "Ácidos gordos trans",
		ro => "Acizi grași trans",
		ru => "Транс-жиры",
		zh => "反式脂肪",
		zh_CN => "反式脂肪",
		zh_HK => "反式脂肪",
		zh_TW => "反式脂肪",
	},
	cholesterol => {
		en => "Cholesterol",
		ar=> "الكوليسترول ",
		cs => "Cholestrol",
		de => "Cholesterin",
		el => "Χοληστερόλη",
		es => "Colesterol",
		fi => "Kolesteroli",
		fr => "Cholestérol",
		he => "כולסטרול",
		it=> "Colesterolo",
		ja => "コレステロール",
		nl => "Cholesterol",
		nl_be => "Cholesterol",
		pt => "Colesterol",
		ro => "Colesterol",
		ru => "Холестерин",
		tr => "Kolestrol",
		zh => "胆固醇",
		zh_CN => "胆固醇",
		zh_HK => "膽固醇",
		zh_TW => "膽固醇",
		unit => "mg",
	},
	fiber => {
		en => "Fibers",
		en_synonyms => ["Dietary fiber", "Fiber", "fibers", "dietary fibers"],
		bg => "Влакнини",
		cs => "Vláknina",
		da => "Kostfibre",
		de => "Ballaststoffe",
		el => "Εδώδιμες ίνες",
		es => "Fibra alimentaria",
		es_synonyms => ["Fibras alimentarias", "Fibras", "Fibra"],
		et => "Kiudained",
		fi => "Ravintokuidut",
		fi_synonyms => ["Ravintokuitu", "Kuitu", "Kuidut"],
		fr => "Fibres alimentaires",
		fr_synonyms => ["fibres", "fibre", "fibre alimentaire", "fibres alimentaires totales"],
		ga => "Snáithín",
		he => "סיבים תזונתיים",
		hu => "Rost",
		it=> "Fibra alimentare",
		ja => "食物繊維",
		lt => "Skaidulinių medžiagų",
		lv => "Šķiedrvielas",
		mt => "Fibra alimentari",
		nl => "Vezels",
		nl_be => "Vezels",
		nb => "Kostfiber",
		pl => "Błonnik",
		pt => "Fibra alimentar",
		ro => "Fibre",
		ru => "Пищевые волокна",
		sk => "Vláknina",
		sl => "Prehranskih vlaknin",
		sv => "Fiber",
		zh => "膳食纤维",
		zh_CN => "膳食纤维",
		zh_HK => "膳食纖維",
		zh_TW => "纖維",
	},
	"soluble-fiber" => {
		de => "lösliche Ballaststoffe",
		en => "Soluble fiber",
		fi => "Liukeneva kuitu",
		fr => "Fibres solubles",
		pt => "Fibra alimentar solúvel",
		ro => "Fibre solubile",
		ru => "Растворимые волокна",
		zh => "可溶性纤维",
		zh_CN => "可溶性纤维",
		zh_HK => "可溶性纖維",
		zh_TW => "可溶性纖維",
	},
	"insoluble-fiber" => {
		de => "unlösliche Ballaststoffe",
		en => "Insoluble fiber",
		fi => "Liukenematon kuitu",
		fr => "Fibres insolubles",
		pt => "Fibra alimentar insolúvel",
		ro => "Fibre insolubile",
		ru => "Нерастворимые волокна",
		zh => "不可溶性纤维",
		zh_CN => "不可溶性纤维",
		zh_HK => "不可溶性纖維",
		zh_TW => "不可溶性纖維",
	},
	sodium => {
		ar => "الصوديوم",
		cs => "Sodík",
		de => "Natrium",
		en => "Sodium",
		el => "Νάτριο",
		es => "Sodio",
		fi => "Natrium",
		fr => "Sodium",
		he => "נתרן",
		hu => "Nátrium",
		it => "Sodio",
		ja => "ナトリウム",
		nl => "Natrium",
		nl_be => "Sodium",
		pt => "Sódio",
		ro => "Sodiu",
		zh => "钠",
		zh_CN => "钠",
		zh_HK => "鈉",
		zh_TW => "鈉",

		unit_us => "mg",
	},
	salt => {
		fr => "Sel",
		en => "Salt",
		ja => "食塩相当量",
		es => "Sal",
		pt => "Sal",
		he => "מלח",
		de => "Salz",
		ga => "Salann",
		da => "Salt",
		el => "Αλάτι",
		fi => "Suola",
		fi_synonyms => ["Ruokasuola"],
		hu => "Só",
		it => "Sale",
		nl => "Zout",
		nl_be => "Zout",
		lv => "Sāls",
		cs => "Sůl",
		et => "Sool",
		pl => "Sól",
		sl => "Sol",
		lt => "Druska",
		mt => "Melħ",
		sk => "Soľ",
		ro => "Sare",
		bg => "Сол",
		zh => "食盐",
	},
	'salt-equivalent' => {
		fr => "Equivalent en sel",
		en => "Salt equivalent",
		es => "Equivalente en sal",
		el => "Ισοδύναμο σε αλάτι",
		fi => "Suolaekvivalentti",
		pt => "Equivalente em sal",
		he => "תחליפי מלח",
		nl => "Equivalent in zout",
		nl_be => "Equivalent in zout",
	},
	'#vitamins' => {
		fr => "Vitamines",
		en => "Vitamin",
		es => "Vitaminas",
		ar => "الفايتمينات",
		it => "Vitamine",
		pt => "Vitaminas",
		de => "Vitamine",
		he => "ויטמינים",
		ga => "Vitimín",
		el => "Βιταμίνες",
		fi => "Vitamiinit",
		fi_synonyms => ["Vitamiini"],
		nl => "Vitamines",
		nl_be => "Vitamines",
		lv => "vitamīns",
		et => "Vitamiin",
		hu => "vitamin",
		pl => "Witamina",
		lt => "Vitaminas",
		mt => "Vitamina",
		sk => "Vitamín",
		ro => "Vitamine",
		bg => "Витамин",
		zh => "维生素",
		zh_CN => "维生素",
		zh_HK => "維他命",
		zh_TW => "維生素",
	},
	'vitamin-a' => {
		fr => "Vitamine A (rétinol)",
		fr_synonyms => ["Vitamine A", "rétinol"],
		ja => "ビタミン A",
		en => "Vitamin A",
		es => "Vitamina A (Retinol)",
		it => "Vitamina A (Retinolo)",
		pt => "Vitamina A",
		de => "Vitamin A (Retinol)",
		he => "ויטמין A (רטינול)",
		ga => "Vitimín A",
		el => "Βιταμίνη A",
		fi => "A-vitamiini",
		nl => "Vitamine A",
		nl_be => "Vitamine A",
		lv => "A vitamīns",
		et => "Vitamiin A",
		hu => "A-vitamin",
		pl => "Witamina A",
		lt => "Vitaminas A",
		mt => "Vitamina A",
		sk => "Vitamín A",
		ro => "Vitamina A",
		bg => "Витамин A",
		zh => "维生素A",

		unit => "µg",
		dv => 1500,
		dv_2016 => "900 RAE", # ! not same unit
		iu => 0.3, # Vitamin A: 1 IU is the biological equivalent of 0.3 μg retinol, or of 0.6 μg beta-carotene.[6][7][a]
		unit_us => "% DV",
		unit_ca => "% DV",
	},
	'vitamin-d' => {
		fr => "Vitamine D / D3 (cholécalciférol)",
		fr_synonyms => ["Vitamine D", "Vitamine D3", "cholécalciférol", "calciférol", "Vitamine D (Calciférol)"],
		en => "Vitamin D",
		es => "Vitamina D",
		it => "Vitamina D (colecalciferolo)",
		pt => "Vitamina D",
		de => "Vitamin D / D3 (Cholecalciferol)",
		he => "ויטמין D",
		ja => "ビタミン D",
		ga => "Vitimín D",
		el => "Βιταμίνη D",
		fi => "D-vitamiini",
		nl => "Vitamine D",
		nl_be => "Vitamine D",
		lv => "D vitamīns",
		et => "Vitamiin D",
		hu => "D-vitamin",
		pl => "Witamina D",
		lt => "Vitaminas D",
		mt => "Vitamina D",
		sk => "Vitamín D",
		ro => "Vitamina D",
		bg => "Витамин D",
		zh => "维生素D",

		unit => "µg",
		dv => 40,
		dv_2016 => 20,
		iu => 0.025, # 1 IU is the biological equivalent of 25 ng cholecalciferol/ergocalciferol
	},
	'vitamin-e' => {
		fr => "Vitamine E (tocophérol)",
		fr_synonyms => ["Vitamine E", "tocophérol"],
		en => "Vitamin E",
		en_synonyms => ["Vitamin E", "Tocopherol"],
		ja => "ビタミン E",
		es => "Vitamina E (a-tocoferol)",
		it => "Vitamina E (Alfa-tocoferolo)",
		pt => "Vitamina E",
		de => "Vitamin E (Tocopherol)",
		he => "ויטמין E (אלפא טוקופרול)",
		ga => "Vitimín E",
		el => "Βιταμίνη E",
		fi => "E-vitamiini (Tokoferoli)",
		fi_synonyms => ["E-vitamiini", "Tokoferoli"],
		nl => "Vitamine E",
		nl_be => "Vitamine E",
		lv => "E vitamīns",
		et => "Vitamiin E",
		hu => "E-vitamin",
		pl => "Witamina E",
		lt => "Vitaminas E",
		mt => "Vitamina E",
		sk => "Vitamín E",
		ro => "Vitamina E",
		bg => "Витамин E",
		zh => "维生素E",

		unit => "mg",
		dv => 20,
		dv_2016 => 15,
		iu => 2/3, # 1 IU is the biological equivalent of about 0.667 mg d-alpha-tocopherol (2/3 mg exactly), or of 0.45 mg of dl-alpha-tocopherol acetate.[8][9]
	},
	'vitamin-k' => {
		fr => "Vitamine K",
		en => "Vitamin K",
		es => "Vitamina K",
		ja => "ビタミン K",
		it => "Vitamina K",
		pt => "Vitamina K",
		de => "Vitamin K",
		he => "ויטמין K (מנדיון)",
		ga => "Vitimín K",
		el => "Βιταμίνη K",
		fi => "K-vitamiinit",
		nl => "Vitamine K",
		nl_be => "Vitamine K",
		lv => "K vitamīns",
		et => "Vitamiin K",
		hu => "K-vitamin",
		pl => "Witamina K",
		lt => "Vitaminas K",
		mt => "Vitamina K",
		sk => "Vitamín K",
		ro => "Vitamina K",
		bg => "Витамин K",
		zh => "维生素K",

		unit => "µg",
		dv => 80,
		dv_2016 => 120,
	},
	'vitamin-k1' => {
		fr => "Vitamine K1",
		en => "Vitamin K1",
		en_synonyms => ["Vitamin K1", "Phylloquinone"],
		unit => "µg",
	},
	'vitamin-k2' => {
		fr => "Vitamine K2",
		en => "Vitamin K2",
		en_synonyms => ["Vitamin K2", "Menaquinone"],
		unit => "µg",
	},
	'vitamin-k3' => {
		fr => "Vitamine K3",
		en => "Vitamin K3",
		en_synonyms => ["Vitamin K3", "Menadione"],
		unit => "µg",
	},
	'vitamin-c' => {
		fr => "Vitamine C (acide ascorbique)",
		fr_synonyms => ["Vitamine C", "acide ascorbique"],
		en => "Vitamin C (ascorbic acid)",
		en_synonyms => ["Vitamin C", "Ascorbic acid"],
		es => "Vitamina C (Ácido ascórbico)",
		ja => "ビタミン C",
		it => "Vitamina C (Acido ascorbico)",
		pt => "Vitamina C",
		de => "Vitamin C (Ascorbinsäure)",
		he => "ויטמין C (חומצה אסקורבית)",
		ga => "Vitimín C",
		el => "Βιταμίνη C",
		fi => "C-vitamiini (Askorbiinihappo)",
		fi_synonyms => ["C-vitamiini", "Askorbiinihappo"],
		nl => "Vitamine C",
		nl_be => "Vitamine C",
		lv => "C vitamīns",
		et => "Vitamiin C",
		hu => "C-vitamin",
		pl => "Witamina C",
		lt => "Vitaminas C",
		mt => "Vitamina C",
		sk => "Vitamín C",
		ro => "Vitamina C",
		bg => "Витамин C",
		zh => "维生素C(抗坏血酸)",

		unit => "mg",
		dv => 60,
		dv_2016 => 90,
		iu => 0.05, # 1 IU is 50 μg L-ascorbic acid
		unit_us => "% DV",
		unit_ca => "% DV",
	},
	'vitamin-b1' => {
		fr => "Vitamine B1 (Thiamine)",
		fr_synonyms => ["Vitamine B1", "Thiamine"],
		en => "Vitamin B1 (Thiamin)",
		en_synonyms => ["Vitamin B1", "Thiamin"],
		es => "Vitamina B1 (Tiamina)",
		ja => "ビタミン B1",
		it => "Vitamina B1 (tiamina)",
		pt => "Vitamina B1 (Tiamina)",
		de => "Vitamin B1 (Thiamin)",
		he => "ויטמין B1 (תיאמין)",
		ga => "Vitimín B1 (Tiaimín)",
		el => "Βιταμίνη B1 (Θειαμίνη)",
		fi => "B1-vitamiini (Tiamiini)",
		fi_synonyms => ["B1-vitamiini", "Tiamiini"],
		nl => "Vitamine B1 (Thiamine)",
		nl_be => "Vitamine B1 (Thiamine)",
		lv => "B1 vitamīns (Tiamīns)",
		et => "Vitamiin B1 (Tiamiin)",
		hu => "B1-vitamin (Tiamin)",
		pl => "Witamina B1 (Tiamina)",
		sl => "Vitamin B1 (Tiamin)",
		lt => "Vitaminas B1 (Tiaminas)",
		mt => "Vitamina B1 (Tiamina)",
		sk => "Vitamín B1",
		ro => "Vitamina B1 (Tiamină)",
		bg => "Витамин B1 (Тиамин)",
		zh => "维生素B1(硫胺)",

		unit => "mg",
		dv_2016 => 1.2,
	},
	'vitamin-b2' => {
		fr => "Vitamine B2 (Riboflavine)",
		fr_synonyms => ["Vitamine B2", "Riboflavine"],
		en => "Vitamin B2 (Riboflavin)",
		en_synonyms => ["Vitamin B2", "Riboflavin"],
		es => "Vitamina B2 (Riboflavina)",
		ja => "ビタミン B2",
		it => "Vitamina B2 (Riboflavina)",
		pt => "Vitamina B2 (Riboflavina)",
		de => "Vitamin B2 (Riboflavin)",
		he => "ויטמין B2 (ריבופלבין)",
		ga => "Vitimín B2 (Ribeaflaivin)",
		el => "Βιταμίνη B2 (Ριβοφλαβίνη)",
		fi => "B2-vitamiini (Riboflaviini)",
		fi_synonyms => ["B2-vitamiini", "Riboflaviini"],
		nl => "Vitamine B2 (Riboflavine)",
		nl_be => "Vitamine B2 (Riboflavine)",
		lv => "B2 vitamīns (Riboflavīns)",
		et => "Vitamiin B2 (Riboflaviin)",
		hu => "B2-vitamin (Riboflavin)",
		pl => "Witamina B2 (Ryboflawina)",
		lt => "Vitaminas B2 (Riboflavinas)",
		mt => "Vitamina B2 (Riboflavina)",
		sk => "Vitamín B2",
		ro => "Vitamina B2 (Riboflavină)",
		bg => "Витамин B2 (Рибофлавин)",
		zh => "维生素B2(核黄素)",

		unit => "mg",
		dv => 1.7,
		dv_2016 => 1.3,
	},
	'vitamin-pp' => {
		fr => "Vitamine B3 / Vitamine PP (Niacine)",
		fr_synonyms => ["Vitamine B3", "Vitamine PP", "Niacine", "Vitamine B3 / PP (Niacine)"],
		en => "Vitamin B3 / Vitamin PP (Niacin)",
		en_synonyms => ["Vitamin B3", "Vitamin PP", "Niacin"],
		es => "Vitamina B3 / Vitamina PP (Niacina)",
		ja => "ビタミン B3",
		it => "Vitamina B3 / Vitamina PP (Niacina)",
		pt => "Vitamina B3 / Vitamina PP (Niacina)",
		de => "Vitamin B3 / Vitamin PP (Niacin)",
		he => "ויטמין B3 /ויטמין PP (ניאצין או חומצה ניקוטינית)",
		ga => "Niaicin",
		el => "Νιασίνη",
		fi => "B3-vitamiini (Niasiini)",
		fi_synonyms => ["B3-vitamiini", "Niasiini"],
		nl => "Niacine",
		nl_be => "Niacine",
		lv => "Niacīns",
		et => "Niatsiin",
		pl => "Niacyna",
		lt => "Niacinas",
		mt => "Niaċina",
		sk => "Niacín",
		ro => "Niacină",
		bg => "Ниацин",
		zh => "维生素B3(烟酸)",

		unit => "mg",
		dv => 20,
		dv_2016 => 16,
	},
	'vitamin-b6' => {
		fr => "Vitamine B6 (Pyridoxine)",
		fr_synonyms => ["Vitamine B6", "Pyridoxine"],
		en => "Vitamin B6 (Pyridoxin)",
		en_synonyms => ["Vitamin B6", "Pyridoxin"],
		es => "Vitamina B6 (Piridoxina)",
		ja => "ビタミン B6",
		it => "Vitamina B6 (piridoxina)",
		pt => "Vitamina B6 (Piridoxina)",
		de => "Vitamin B6 (Pyridoxin)",
		he => "ויטמין B6 (פירידוקסין)",
		ga => "Vitimín B6",
		el => "Βιταμίνη B6",
		fi => "B6-vitamiini (Pyridoksiini)",
		fi_synonyms => ["B6-vitamiini", "Pyridoksiini"],
		nl => "Vitamine B6",
		nl_be => "Vitamine B6",
		lv => "B6 vitamīns",
		et => "Vitamiin B6",
		hu => "B6-vitamin",
		pl => "Witamina B6",
		lt => "Vitaminas B6",
		sk => "Vitamín B6",
		ro => "Vitamina B6",
		bg => "Витамин B6",
		zh => "维生素B6",

		unit => "mg",
		dv => 2.0,
		dv_2016 => 1.7,
	},
	'vitamin-b9' => {
		fr => "Vitamine B9 (Acide folique)",
		fr_synonyms => ["Vitamine B9", "Acide folique", "Acide folique, équivalents alimentaires d'acide folique"],
		en => "Vitamin B9 (Folic acid)",
		en_synonyms => ["Vitamin B9", "Folic acid"],
		es => "Vitamina B9 (Ácido fólico)",
		ja => "ビタミン B9 (葉酸)",
		it => "Vitamina B9 (Acido folico)",
		pt => "Vitamina B9 (Ácido Fólico)",
		de => "Vitamin B9 (Folsäure)",
		he => "ויטמין B9 (חומצה פולית)",
		ga => "Vitimín B9 (Aigéad fólach)",
		el => "Βιταμίνη B9 (Φολικό οξύ)",
		fi => "B9-vitamiini (Foolihappo)",
		fi_synonyms => ["B9-vitamiini", "Foolihappo"],
		nl => "Vitamine B9 (Foliumzuur)",
		nl_be => "Vitamine B9 (Foliumzuur)",
		lv => "B9 vitamīns (Folijskābe)",
		et => "Vitamiin B9 (Foolhape)",
		hu => "B9-vitamin (Folsav)",
		pl => "Witamina B9 (Kwas foliowy)",
		lt => "Vitaminas B9 (Folio rūgštis)",
		sk => "Vitamín B9 (Kyselina listová)",
		ro => "Vitamina B9 (Acid folic)",
		bg => "Витамин B9 (Фолиева киселина)",
		zh => "维生素B9(叶酸)",

		unit => "µg",
		dv => 400,
		dv_2016 => 400,
	},
	# folates = total folates = naturally occuring folates + added folic acid
	'folates' => {
		en => "Folates (total folates)",
		en_synonyms => ["Folates", "Total folates"],
		fi => "Folaatit",
		fr => "Folates (folates totaux)",

		unit => "µg",
		dv => 400,
		dv_2016 => 400,
	},
	'vitamin-b12' => {
		fr => "Vitamine B12 (cobalamine)",
		fr_synonyms => ["Vitamine B12", "Cobalamine"],
		en => "Vitamin B12 (cobalamin)",
		en_synonyms => ["Vitamin B12", "Cobalamin"],
		es => "Vitamina B12 (Cianocobalamina)",
		it => "Vitamina B12 (Cobalamina)",
		ja => "ビタミン B12",
		pt => "Vitamina B12 (Cobalamina)",
		de => "Vitamin B12 (Cobalamin)",
		he => "ויטמין B12 (ציאנוקובלאמין)",
		ga => "Vitimín B12",
		el => "Βιταμίνη B12",
		fi => "B12-vitamiini (Kobalamiini)",
		fi_synonyms => ["B12-vitamiini", "Kobalamiini"],
		nl => "Vitamine B12",
		nl_be => "Vitamine B12",
		lv => "B12 vitamīns",
		et => "Vitamiin B12",
		hu => "B12-vitamin",
		pl => "Witamina B12",
		lt => "Vitaminas B12",
		sk => "Vitamín B12",
		ro => "Vitamina B12",
		bg => "Витамин В12",
		zh => "维生素B12",

		unit => "µg",
		dv => 6,
		dv_2016 => 2.4,
	},
	'biotin' => {
		fr => "Biotine (Vitamine B8 / B7 / H)",
		fr_synonyms => ["Biotine", "Vitamine B8", "Vitamine B7", "Vitamine H", "Vitamine B8 (H) (Biotine)"],
		en => "Biotin",
		es => "Vitamina B7 (Biotina)",
		it => "Vitamina B8/B7/H/I (Biotina)",
		pt => "Vitamina B7 (Biotina)",
		de => "Biotin (Vitamin B8 / B7 / H)",
		ja => "ビタミン B8 / B7 / H",
		he => "ביוטין (ויטמין B7)",
		ga => "Bitin",
		el => "Βιοτίνη",
		fi => "Biotiini (B7-vitamiini)",
		fi_synonyms => ["Biotiini", "B7-vitamiini"],
		nl => "Biotine",
		nl_be => "Biotine",
		lv => "Biotīns",
		et => "Biotiin",
		pl => "Biotyna",
		lt => "Biotinas",
		sk => "Biotín",
		ro => "Biotină",
		bg => "Биотин",
		zh => "生物素",

		unit => "µg",
		dv => 300,
		dv_2016 => 30,
	},
	'pantothenic-acid' => {
		fr => "Acide pantothénique (Vitamine B5)",
		fr_synonyms => ["Acide pantothénique", "Vitamine B5", "Vitamine B5 (Acide pantothénique)"],
		en => "Pantothenic acid / Pantothenate (Vitamin B5)",
		en_synonyms => ["Pantothenic acid", "Pantothenate", "Vitamin B5"],
		ja => "ビタミン B5",
		es => "Vitamina B5 (Ácido pantoténico)",
		it => "Vitamina B5 (Acido pantotenico)",
		pt => "Vitamina B5 (Ácido Pantotênico)",
		pt_pt => "Vitamina B5 (ácido pantoténico)",
		de => "Pantothensäure (Vitamin B5)",
		he => "חומצה פנטותנית (ויטמין B5)",
		ga => "Aigéad pantaitéineach",
		da => "Pantothensyre",
		el => "Παντοθενικό οξύ",
		fi => "Pantoteenihappo (B5-vitamiini)",
		fi_synonyms => ["Pantoteenihappo", "B5-vitamiini"],
		nl => "Pantotheenzuur",
		nl_be => "Pantotheenzuur",
		sv => "Pantotensyra",
		lv => "Pantotēnskābe",
		cs => "Kyselina pantothenová",
		et => "Pantoteenhape",
		hu => "Pantoténsav",
		pl => "Kwas pantotenowy",
		sl => "Pantotenska kislina",
		lt => "Pantoteno rūgštis",
		mt => "Aċidu Pantoteniku",
		sk => "Kyselina pantotenová",
		ro => "Acid pantotenic",
		bg => "Пантотенова киселина",

		unit => "mg",
		dv => 10,
		dv_2016 => 5,
	},
	'#minerals' => {
		fr => "Sels minéraux",
		en => "Minerals",
		es => "Sales minerales",
		el => "Ανόργανα άλατα",
		fi => "Kivennäisaineet",
		fi_synonyms =>  ["Kivennäisaine", "Kivennäiset", "Kivennäinen"],
		it => "Sali minerali",
		pt => "Sais Minerais",
		de => "Minerals",
		he => "מינרלים",
		nl => "Mineralen",
		nl_be => "Mineralen",
		ro => "Minerale",
	},
	potassium => {
		fr => "Potassium",
		en => "Potassium",
		es => "Potasio",
		unit => "mg",
		it => "Potassio",
		pt => "Potássio",
		de => "Kalium",
		he => "אשלגן",
		ga => "Potaisiam",
		da => "Kalium",
		el => "Κάλιο",
		fi => "Kalium",
		nl => "Kalium",
		nl_be => "Kalium",
		sv => "Kalium",
		lv => "Kālijs",
		cs => "Draslík",
		et => "Kaaliumv",
		hu => "Kálium",
		pl => "Potas",
		sl => "Kalij",
		lt => "Kalis",
		mt => "Potassju",
		sk => "Draslík",
		ro => "Potasiu",
		bg => "Калий",
		zh => "钾",
	},
	bicarbonate => {
		fr => "Bicarbonate",
		en => "Bicarbonate",
		es => "Bicarbonato",
		el => "Διττανθρακικό",
		fi => "Vetykarbonaatti",
		fi_synonyms => ["bikarbonaatti"],
		unit => "mg",
		it => "Bicarbonato",
		pt => "Bicarbonato",
		de => "Bikarbonat",
		he => "ביקרבונט (מימן פחמתי)",
		nl => "Bicarbonaat",
		nl_be => "Bicarbonaat",
		ro => "Bicarbonat",
	},
	chloride => {
		fr => "Chlorure",
		en => "Chloride",
		es => "Cloro",
		it => "Cloruro",
		pt => "Cloreto",
		de => "Chlor",
		he => "כלוריד",
		ga => "Clóiríd",
		da => "Chlorid",
		el => "Χλώριο",
		fi => "Kloridi",
		sv => "Klorid",
		lv => "Hlorīdsv",
		cs => "Chlor",
		et => "Kloriid",
		hu => "Klorid",
		pl => "Chlor",
		sl => "Klorid",
		lt => "Chloridas",
		mt => "Kloridu",
		sk => "Chlorid",
		ro => "Clorură",
		bg => "Хлорид",
		nl => "Chloor",
		nl_be => "Chloor",

		unit => "mg",
		dv => 3400,
		dv_2016 => 2300,
	},
	silica => {
		fr => "Silice",
		en => "Silica",
		es => "Sílice",
		el => "Πυρίτιο",
		fi => "Piioksidi",
		fi_synonyms => ["Silika"],
		it => "Silicio",
		pt => "Sílica",
		de => "Kieselerde",
		he => "צורן דו־חמצני",
		nl => "Silicium",
		nl_be => "Silicium",
		ro => "Dioxid de siliciu",

		unit => "mg",
	},
	calcium => {
		fr => "Calcium",
		en => "Calcium",
		ja => "カルシウム",
		es => "Calcio",
		ar => "الكالسيوم",
		it => "Calcio",
		pt => "Cálcio",
		de => "Kalzium",
		he => "סידן",
		ga => "Cailciam",
		el => "Ασβέστιο",
		fi => "Kalsium",
		sv => "Kalcium",
		lv => "Kalcijs",
		cs => "Vápník",
		et => "Kaltsium",
		hu => "Kalcium",
		pl => "Wapń",
		sl => "Kalcij",
		lt => "Kalcis",
		mt => "Kalċju",
		sk => "Vápnik",
		ro => "Calciu",
		bg => "Калций",
		zh => "鈣",
		nl => "Calcium",
		nl_be => "Calcium",

		unit => "mg",
		dv => 1000,
		dv_2016 => 1300,
		unit_us => "% DV",
		unit_ca => "% DV",
	},
	phosphorus => {
		fr => "Phosphore",
		en => "Phosphorus",
		es => "Fósforo",
		ar => "الفوسفور",
		it => "Fosforo",
		pt => "Fósforo",
		de => "Phosphor",
		he => "זרחן",
		ga => "Fosfar",
		da => "Phosphor",
		el => "Φωσφόρος",
		fi => "Fosfori",
		nl => "Fosfor",
		nl_be => "Fosfor",
		sv => "Fosfor",
		lv => "Fosfors",
		cs => "Fosfor",
		et => "Fosfor",
		hu => "Foszfor",
		pl => "Fosfor",
		sl => "Fosfor",
		lt => "Fosforas",
		mt => "Fosfru",
		sk => "Fosfor",
		ro => "Fosfor",
		bg => "Фосфор",
		zh => "磷",

		unit => "mg",
		dv => 1000,
		dv_2016 => 1250,
	},
	iron => {
		fr => "Fer",
		en => "Iron",
		ja => "鉄",
		es => "Hierro",
		it => "Ferro",
		pt => "Ferro",
		de => "Eisen",
		he => "ברזל",
		ga => "Iarann",
		da => "Jern",
		el => "Σίδηρος",
		fi => "Rauta",
		nl => "IJzer",
		nl_be => "IJzer",
		sv => "Järn",
		lv => "Dzelzs",
		cs => "Železo",
		et => "Raud",
		hu => "Vas",
		pl => "Żelazo",
		sl => "Železo",
		lt => "Geležis",
		mt => "Kalċju",
		sk => "Železo",
		ro => "Fier",
		bg => "Желязо",
		zh => "鐵",

		unit => "mg",
		dv => 18,
		dv_2016 => 18,
		unit_us => "% DV",
		unit_ca => "% DV",
	},
	magnesium => {
		fr => "Magnésium",
		en => "Magnesium",
		es => "Magnesio",
		fi => "Magnesium",
		it => "Magnesio",
		pt => "Magnésio",
		de => "Magnesium",
		he => "מגנזיום",
		ga => "Maignéisiam",
		el => "Μαγνήσιο",
		lv => "Magnijs",
		cs => "Hořčík",
		et => "Magneesium",
		hu => "Magnézium",
		pl => "Magnez",
		sl => "Magnezij",
		lt => "Magnis",
		mt => "Manjesju",
		sk => "Horčík",
		ro => "Magneziu",
		bg => "Магнезий",
		zh => "鎂",
		nl => "Magnesium",
		nl_be => "Magnesium",
		ja => "マグネシウム",

		unit => "mg",
		dv => 400,
		dv_2016 => 420,
	},
	zinc => {
		fr => "Zinc",
		en => "Zinc",
		es => "Zinc",
		it => "Zinco",
		pt => "Zinco",
		de => "Zink",
		he => "אבץ",
		ga => "Sinc",
		da => "Zink",
		el => "Ψευδάργυρος",
		fi => "Sinkki",
		nl => "Zink",
		nl_be => "Zink",
		ro => "Zinc",
		sv => "Zink",
		lv => "Cinks",
		cs => "Zinek",
		et => "Tsink",
		hu => "Cink",
		pl => "Cynk",
		sl => "Cink",
		lt => "Cinkas",
		mt => "Żingu",
		sk => "Zinok",
		bg => "Цинк",
		zh => "鋅",
		ja => "亜鉛",

		unit => "mg",
		dv => 15,
		dv_2016 => 11,
	},
	copper => {
		fr => "Cuivre",
		en => "Copper",
		es => "Cobre",
		it => "Rame",
		pt => "Cobre",
		de => "Kupfer",
		he => "נחושת",
		ga => "Copar",
		da => "Kobber",
		el => "Χαλκός",
		fi => "Kupari",
		nl => "Koper",
		nl_be => "Koper",
		sv => "Koppar",
		lv => "Varš",
		cs => "Měď",
		et => "Vask",
		hu => "Réz",
		pl => "Miedź",
		sl => "Baker",
		lt => "Varis",
		mt => "Ram",
		sk => "Meď",
		ro => "Cupru",
		bg => "Мед",

		unit => "mg",
		dv => 2,
		dv_2016 => 0.9,
	},
	manganese => {
		fr => "Manganèse",
		en => "Manganese",
		es => "Manganeso",
		it => "Manganese",
		pt => "Manganês",
		de => "Mangan",
		he => "מנגן",
		ga => "Mangainéis",
		da => "Mangan",
		el => "Μαγγάνιο",
		fi => "Mangaani",
		nl => "Mangaan",
		nl_be => "Mangaan",
		sv => "Mangan",
		lv => "Mangāns",
		cs => "Mangan",
		et => "Mangaan",
		hu => "Mangán",
		pl => "Mangan",
		sl => "Mangan",
		lt => "Manganas",
		mt => "Manganis",
		sk => "Mangán",
		ro => "Mangan",
		bg => "Манган",

		unit => "mg",
		dv => 2,
		dv_2016 => 2.3,
	},
	fluoride => {
		fr => "Fluorure",
		en => "Fluoride",
		es => "Flúor",
		unit => "mg",
		it => "Fluoro",
		pt => "Fluoreto",
		de => "Fluor",
		he => "פלואוריד",
		ga => "Fluairíd",
		da => "Fluorid",
		el => "Φθόριο",
		fi => "Fluoridi",
		sv => "Fluorid",
		lv => "Fluorīds",
		cs => "Fluor",
		et => "Fluoriid",
		hu => "Fluor",
		pl => "Fluor",
		sl => "Fluorid",
		lt => "Fluoridas",
		mt => "Floridu",
		sk => "Fluorid",
		ro => "Fluorură",
		bg => "Флуорид",
		nl => "Fluor",
		nl_be => "Fluor",
	},
	selenium => {
		fr => "Sélénium",
		en => "Selenium",
		es => "Selenio",
		it => "Selenio",
		pt => "Selênio",
		pt_pt => "Selénio",
		de => "Selen",
		he => "סלניום",
		ga => "Seiléiniam",
		da => "Selen",
		el => "Σελήνιο",
		fi => "Seleeni",
		nl => "Seleen",
		nl_be => "Seleen",
		sv => "Selen",
		lv => "Selēns",
		cs => "Selen",
		et => "Seleen",
		hu => "Szelén",
		pl => "Selen",
		sl => "Selen",
		lt => "Selenas",
		mt => "Selenju",
		sk => "Selén",
		ro => "Seleniu",
		bg => "Селен",
		zh => "硒",

		unit => "µg",
		dv => 70,
		dv_2016 => 55,
	},
	chromium => {
		fr => "Chrome",
		en => "Chromium",
		es => "Cromo",
		it => "Cromo",
		pt => "Cromo",
		pt_pt => "Crómio",
		de => "Chrom",
		he => "כרום",
		ga => "Cróimiam",
		da => "Chrom",
		el => "Χρώμιο",
		fi => "Kromi",
		nl => "Chroom",
		nl_be => "Chroom",
		sv => "Krom",
		lv => "Hroms",
		cs => "Chrom",
		et => "Kroom",
		hu => "Króm",
		pl => "Chrom",
		sl => "Krom",
		lt => "Chromas",
		mt => "Kromju",
		sk => "Chróm",
		ro => "Crom",
		bg => "Хром",

		unit => "µg",
		dv => 120,
		dv_2016 => 35,
	},
	molybdenum => {
		fr => "Molybdène",
		en => "Molybdenum",
		es => "Molibdeno",
		it => "Molibdeno",
		pt => "Molibdênio",
		pt_pt => "Molibdénio",
		de => "Molybdän",
		he => "מוליבדן",
		ga => "Molaibdéineam",
		da => "Molybdæn",
		el => "Μολυβδαίνιο",
		fi => "Molybdeeni",
		nl => "Molybdeen",
		nl_be => "Molybdeen",
		sv => "Molybden",
		lv => "Molibdēns",
		cs => "Molybden",
		et => "Molübdeen",
		hu => "Molibdén",
		pl => "Molibden",
		sl => "Molibden",
		lt => "Molibdenas",
		mt => "Molibdenum",
		sk => "Molybdén",
		ro => "Molibden",
		bg => "Молибден",

		unit => "µg",
		dv => 75,
		dv_2016 => 45,
	},
	iodine => {
		fr => "Iode",
		en => "Iodine",
		es => "Yodo",
		it=> "Iodio",
		pt => "Iodo",
		de => "Jod",
		he => "יוד",
		ga => "Iaidín",
		da => "Jod",
		el => "Ιώδιο",
		fi => "Jodi",
		nl => "Jodium",
		nl_be => "Jodium",
		sv => "Jod",
		lv => "Jods",
		cs => "Jód",
		et => "Jood",
		hu => "Jód",
		pl => "Jod",
		sl => "Jod",
		lt => "Jodas",
		mt => "Jodju",
		sk => "Jód",
		ro => "Iod",
		bg => "Йод",

		unit => "µg",
		dv => 150,
		dv_2016 => 150,
	},
	caffeine => {
		fr => "Caféine / Théine",
		en => "Caffeine",
		el => "Καφεΐνη",
		fi => "Kofeiini",
		nl => "Cafeïne",
		nl_be => "Cafeïne",
		pt => "Cafeína",
		ro => "Cafeină",

		unit => "mg",
	},
	taurine => {
		zh_hans => "牛磺酸",
		zh_hant => "牛磺酸",
		zh_hk => "牛磺酸",
		zh_cn => "牛磺酸",
		zh_sg => "牛磺酸",
		zh_tw => "牛磺酸",
		pl => "Tauryna",
		wa => "Torene",
		ko => "타우린",
		fi => "Tauriini",
		fr => "Taurine",
		he => "טאורין",
		es => "Taurina",
		hu => "Taurin",
		it => "Taurina",
		gl => "Taurina",
		et => "Tauriin",
		id => "Taurina",
		de => "Taurin",
		ja => "タウリン",
		vi => "Taurine",
		nl => "Taurine",
		nl_be => "Taurine",
		sv => "Taurin",
		pt => "Taurina",
		eo => "Taŭrino",
		sk => "Taurín",
		ru => "таурин",
		en => "Taurine",
		sr_el => "Taurin",
		sr_ec => "Таурин",
		tr => "Taurin",
		ro => "Taurină",
		ca => "Taurina",
		fi => "Tauriini",
		uk => "Таурин",
		sl => "Tavrin",
		cs => "Taurin",
		fa => "تائورین",
		bg => "Таурин",
		hr => "Taurin",
		da => "Taurin",
		sr => "таурин",
		zh => "牛磺酸",
		nb => "Taurin",
		hy => "Տաուրին",
		sh => "Taurin",
		ar => "التورين",
		sq => "taurin",
		mk => "Таурин",
		el => "Ταυρίνη",
		en_ca => "Taurine",
		en_gb => "Taurine",
		pt_br => "Taurina",
	},

	ph => {
		en => "pH",
		el => "pH",
		fi => "pH",
		nl => "pH",
		nl_be => "pH",
		unit => "",
	},

	"carbon-footprint" => {
		fr => "Empreinte carbone / émissions de CO2",
		en => "Carbon footprint / CO2 emissions",
		es => "Huella de carbono / Emisiones de CO2",
		el => "Αποτύπωμα άνθρακα/Εκπομπές CO2",
		fi => "Hiilijalanjälki / CO2-päästöt",
		it=> "Emissioni di CO2 (impronta climatica)",
		pt => "Pegada de carbono / Emissões de CO<sub>2</sub>",
		ro => "Amprentă carbon / Emisii CO2",
		de => "Carbon Footprint / CO2-Emissionen",
		he => "טביעת רגל פחמנית / פליטת פחמן דו־חמצני",
		nl => "Ecologische voetafdruk / CO2-uitstoot",
		nl_be => "Ecologische voetafdruk / CO2-uitstoot",
		unit => "g",
	},
	"carbon-footprint-from-meat-or-fish" => {
		fr => "Empreinte carbone de la viande ou du poisson",
		en => "Carbon footprint from meat or fish",
		fi => "Hiilijalanjälki lihasta tai kalasta",
		unit => "g",
	},


	'glycemic-index' => {
		en => "Glycemic Index",
		de => "Glykämischer Index",
		fi => "Glykeeminen indeksi",
		unit => "",
	},
	"water-hardness" => {
		en => "Water hardness",
		fi => "Veden kovuus",
		fr => "Dureté de l'eau",
		ro => "Duritatea apei",
		ru => "Жёсткость воды",
		de => "Wasserhärte",
		unit => "mmol/l",
	},
	"fruits-vegetables-nuts" => {
		en => "Fruits, vegetables, nuts and rapeseed, walnut and olive oils",
		en_synonyms => ["Fruits and vegetables", "Fruits, vegetables and nuts", "Fruits, vegetables, nuts"],
		fi => "Hedelmät, kasvikset, pähkinät ja rapsi-, saksanpähkinä- ja oliiviöljyt",
		fi_synonyms => ["Hedelmät ja kasvikset", "Hedelmät, kasvikset ja pähkinät"],
		fr => "Fruits, légumes, noix et huiles de colza, noix et olive",
		fr_synonyms => ["Fruits et légumes", "Fruits / légumes", "F&L", "Fruits, légumes et noix", "Fruits, légumes, noix", "Fruits, légumes, légumineuses, fruits à coques", "Fruits et Légumes, légumineuses et fruits à coque"],
		es => "Frutas, verduras y nueces",
		es_synonyms => ["Frutas, verduras, nueces", "FRUTAS/VERDURAS/NUEZ", "FRUTAS, VERDURAS y NUEZ"],
		el => "Φρούτα, λαχανικά, καρποί",
		nl => "Fruit, groenten en noten",
		nl_be => "Fruit, groenten en noten",
		ro => "Fructe, legume, nuci",
		de => "Obst, Gemüse und Nüsse",
		unit => "%",
	},
	"fruits-vegetables-nuts-dried" => {
		en => "Fruits, vegetables and nuts - dried",
		fi => "Kuivatut hedelmät, kasvikset ja pähkinät",
		fr => "Fruits, légumes et noix - séchés",
		ro => "Fructe, legume, nuci uscate",
		unit => "%",
	},
	"fruits-vegetables-nuts-estimate" => {
		en => "Fruits, vegetables, nuts and rapeseed, walnut and olive oils (manual estimate from ingredients list)",
		fi => "Hedelmät, kasvikset, pähkinät ja rapsi-, saksanpähkinä- ja oliiviöljyt (arvio ainesosaluettelosta)",
		fr => "Fruits, légumes, noix et huiles de colza, noix et olive (estimation manuelle avec la liste des ingrédients)",
		es => "Frutas, verduras y nueces (estimación de la lista de ingredientes)",
		nl => "Fruit, groenten en noten (Schat uit ingrediëntenlijst)",
		nl_be => "Fruit, groenten en noten (Schat uit ingrediëntenlijst)",
		de => "Obst, Gemüse und Nüsse (Schätzung aus Zutatenliste)",
		unit => "%",
	},
	
	"fruits-vegetables-nuts-estimate-from-ingredients" => {
		en => "Fruits, vegetables, nuts and rapeseed, walnut and olive oils (estimate from ingredients list analysis)",
		fr => "Fruits, légumes, noix et huiles de colza, noix et olive (estimation par analyse de la liste des ingrédients)",
		de => "Früchte, Gemüse, Nüsse und Raps, Walnuss- und Olivenöl (Schätzung aus der Analyse der Zutatenliste)",
		es => "Frutas, verduras, nueces y aceites de canola, nueces y oliva (estimado del análisis en la lista de ingredientes)",
		unit => "%",
	},
	"collagen-meat-protein-ratio" => {
		en => "Collagen/Meat protein ratio (maximum)",
		fr => "Rapport collagène sur protéines de viande (maximum)",
		el => "Αναλογία κολλαγόνου/πρωτεΐνης κρέατος (μέγιστο)",
		es => "Relación tejido conjuntivo/proteínas de carne (máximo)",
		de => "Verhältnis Kollagen/Eiweiß",
		fi => "Kollageeni/liha-proteiinisuhde (maksimi)",
		nl => "Verhouding collageen/eiwitten uit vlees (maximum)",
		nl_be => "Verhouding collageen/eiwitten uit vlees (maximum)",
		unit => "%",
	},
	cocoa => {
		en => "Cocoa (minimum)",
		de => "Kakao (Minimum)",
		es => "Cacao (mínimo)",
		fi => "Kaakao (minimi)",
		fr => "Cacao (minimum)",
		nl => "Cacao (minimum)",
		pt => "Cacau (minimum)",
		ro => "Cacao (minim)",
		unit => "%",
	},
	"nutrition-score-uk" => {
		en => "Nutrition score - UK",
		fi => "Ravintopisteet - UK",
		nl => "Voedingsscore - UK",
		nl_be => "Voedingsgraad",
		el => "Bαθμολογία θρεπτικής αξίας-UK",
		unit => "",
	},
	"nutrition-score-fr" => {
		fr => "Score nutritionnel - France",
		en => "Nutrition score - France",
		fi => "Ravintopisteet - Ranska",
		nl => "Voedingsscore - FR",
		el => "Βαθμολογία θρεπτικής αξίας-FR",
		unit => "",
	},
	"nova-group" => {
		en => "NOVA group",
		fi => "NOVA-ryhmä",
		fr => "Groupe NOVA",
		unit => "",
	},
	"beta-carotene" => {
		de => "Beta-Carotin",
		en => "Beta carotene",
		es => "Beta caroteno",
		fi => "Beetakaroteeni",
		fr => "Bêta carotène",
		nl => "Bêta-caroteen",
		nl_be => "Bêta-caroteen",
	},
	"chlorophyl" => {
		de => "Chlorophyll",
		en => "Chlorophyl",
		fi => "Lehtivihreä",
		fi_synonyms => ["Klorofylli"],
		nl => "Chlorofyl",
		nl_be => "Chlorofyl",
		ro => "Clorofilă",
	},
	"nutrition-grade" => {
		fr => "Note nutritionnelle",
		en => "Nutrition grade",
		fi => "Ravintoarvosana",
		ro => "Notă nutrițională",
	},
	"choline" => {
		ar => "كولين",
		bg => "Холин",
		bs => "Holin",
		ca => "Colina",
		da => "Cholin",
		de => "Cholin",
		en => "Choline",
		eo => "Kolino",
		es => "Colina",
		et => "Koliin",
		eu => "Kolina",
		fa => "کولین",
		fi => "Koliini",
		fr => "Choline",
		ga => "Coilín",
		gl => "Colina",
		he => "כולין",
		id => "Kolina",
		it => "Colina",
		ja => "コリン",
		kk => "Холин",
		lt => "Cholinas",
		nl => "Choline",
		pl => "Cholina",
		pt => "Colina",
		ru => "Холин",
		sh => "Holin",
		sk => "Cholín",
		sl => "Holin",
		sr => "Holin",
		sv => "Kolin",
		ta => "கோலின்",
		tr => "Kolin",
		tyv => "Холин",
		uk => "Холін",
		zh => "胆碱",
		zh_CN => "胆碱",
	},
	phylloquinone => {
		en => "Vitamin K1 (Phylloquinone)",
		fi => "K1-vitamiini (Fyllokinoni)",
		fi_synonyms => ["K1-vitamiini", "Fyllokinoni"],
		fr => "Vitamine K1",
		fr_synonyms => ["Vitamine K1", "Vitamine K1 (Phylloquinone)", "Vitamine K (Phylloquinone)"],
	},
	"beta-glucan" => {
		en => "Beta-glucan",
		fi => "Beetaglukaani",
		fr => "Bêta-glucanes"
	},
	inositol => {
		en => "Inositol",
		fi => "Inositoli"
	},
	carnitine => {
		en => "Carnitine",
		fi => "Karnitiini"
	}
);


my $daily_values_us = <<XXX

Percent Daily Values

http://ecfr.gpoaccess.gov/cgi/t/text/text-idx?c=ecfr&sid=ebf41b28ca63f43546dd9b6bf3f20330&rgn=div5&view=text&node=21:2.0.1.1.2&idno=21#21:2.0.1.1.2.1.1.6

Vitamin A, 5,000 International Units
# Vitamin A: 1 IU is the biological equivalent of 0.3 μg retinol, or of 0.6 μg beta-carotene[5][6]

Vitamin C, 60 milligrams

Calcium, 1,000 milligrams

Iron, 18 milligrams

Vitamin D, 400 International Units
# Vitamin D: 1 IU is the biological equivalent of 0.025 μg cholecalciferol/ergocalciferol

Vitamin E, 30 International Units
# Vitamin E: 1 IU is the biological equivalent of about 0.667 mg d-alpha-tocopherol (2/3 mg exactly), or of 1 mg of dl-alpha-tocopherol acetate

Vitamin K, 80 micrograms

Thiamin, 1.5 milligrams

Riboflavin, 1.7 milligrams

Niacin, 20 milligrams

Vitamin B6, 2.0 milligrams

Folate, 400 micrograms

Vitamin B12, 6 micrograms

Biotin, 300 micrograms

Pantothenic acid, 10 milligrams

Phosphorus, 1,000 milligrams

Iodine, 150 micrograms

Magnesium, 400 milligrams

Zinc, 15 milligrams

Selenium, 70 micrograms

Copper, 2.0 milligrams

Manganese, 2.0 milligrams

Chromium, 120 micrograms

Molybdenum, 75 micrograms

Chloride, 3,400 milligrams
XXX
;







# Compute the list of nutriments that are not shown by default so that they can be suggested

foreach my $region (keys %nutriments_tables) {

	$nutriments_lists{$region} = [];
	$other_nutriments_lists{$region} = [];

	foreach (@{$nutriments_tables{$region}}) {

		my $nutriment = $_;	# copy instead of alias

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

sub canonicalize_nutriment($$) {

	my $lc = shift;
	my $label = shift;
	my $nid = get_string_id_for_lang($lc, $label);
	if ($lc eq 'fr') {
		$nid =~ s/^dont-//;
	}
	if (defined $nutriments_labels{$lc}) {
		if (defined $nutriments_labels{$lc}{$nid}) {
			$nid = $nutriments_labels{$lc}{$nid};
		}
		elsif ($nid =~ /linole/) {
			my $nid2 = $nid;
			$nid2 =~ s/linolei/linoleni/;
			if (defined $nutriments_labels{$lc}{$nid2}) {
				$nid = $nutriments_labels{$lc}{$nid2};
			}
			else {
				$nid2 = $nid;
				$nid2 =~ s/linoleni/linolei/;
				if (defined $nutriments_labels{$lc}{$nid2}) {
					$nid = $nutriments_labels{$lc}{$nid2};
				}
			}
		}
	}

	#$log->trace("nutriment canonicalized", { lc => $lc, label => $label, nid => $nid }) if $log->is_trace();
	return $nid;

}



$log->info("initialize \%nutriments_labels");

foreach my $nid (keys %Nutriments) {

	foreach my $lc (sort keys %{$Nutriments{$nid}}) {

		# skip non language codes

		next if ($lc =~  /^unit/);
		next if ($lc =~  /^dv/);
		next if ($lc =~  /^iu/);

		my $label = $Nutriments{$nid}{$lc};
		next if not defined $label;
		defined $nutriments_labels{$lc} or $nutriments_labels{$lc} = {};
		$nutriments_labels{$lc}{canonicalize_nutriment($lc,$label)} = $nid;
		#$log->trace("initializing label", { lc => $lc, label => $label, nid => $nid }) if $log->is_trace();

		my @labels = split(/\(|\/|\)/, $label);

		foreach my $sublabel ($label, @labels) {
			$sublabel = canonicalize_nutriment($lc,$sublabel);
			if (length($sublabel) >= 2) {
				$nutriments_labels{$lc}{$sublabel} = $nid;
				#$log->trace("initializing sublabel", { lc => $lc, sublabel => $sublabel, nid => $nid }) if $log->is_trace();
			}
			if ($sublabel =~ /alpha-/) {
				$sublabel =~ s/alpha-/a-/;
				$nutriments_labels{$lc}{$sublabel} = $nid;
			}
			if ($sublabel =~ /^(acide-gras|acides-gras|acide|fatty-acids|fatty-acid)-/) {
				$sublabel = $';
				$nutriments_labels{$lc}{$sublabel} = $nid;
			}
		}
	}

}

my $international_units = qr/kg|g|mg|µg|oz|l|dl|cl|ml|(fl(\.?)(\s)?oz)/i;
# Chinese units: a good start is https://en.wikipedia.org/wiki/Chinese_units_of_measurement#Mass
my $chinese_units = qr/
	(?:[\N{U+6BEB}\N{U+516C}]?\N{U+514B})|  # 毫克 or 公克 or 克 or (克 kè is the Chinese word for gram)
	                                        #                      (公克 gōngkè is for "metric gram")
	(?:\N{U+516C}?\N{U+65A4})|              # 公斤 or 斤 or         (公斤 gōngjīn is a "metric kg")
	(?:[\N{U+6BEB}\N{U+516C}]?\N{U+5347})|  # 毫升 or 公升 or 升     (升 is liter)
	\N{U+5428}                              # 吨                    (ton?)
	/ix;
my $russian_units = qr/г|мг|кг|л|дл|кл|мл/i;
my $units = qr/$international_units|$chinese_units|$russian_units/i;


=head2 normalize_quantity($)

Return the size in g or ml for the whole product. Eg.:
normalize_quantity(1 barquette de 40g) returns 40
normalize_quantity(20 tranches 500g)   returns 500
normalize_quantity(6x90g)              returns 540
normalize_quantity(2kg)                returns 2000

=cut

sub normalize_quantity($) {

	my $quantity = shift;

	my $q = undef;
	my $u = undef;

	# 12 pots x125 g
	# 6 bouteilles de 33 cl
	# 6 bricks de 1 l
	# 10 unités, 170 g
	# 4 bouteilles en verre de 20cl
	if ($quantity =~ /(\d+)(\s(\p{Letter}| )+)?(\s)?( de | of |x|\*)(\s)?((\d+)(\.|,)?(\d+)?)(\s)?($units)/i) {
		my $m = $1;
		$q = lc($7);
		$u = $12;
		$q =~ s/,/\./;
		$q = unit_to_g($q * $m, $u);
	}
	elsif ($quantity =~ /((\d+)(\.|,)?(\d+)?)(\s)?($units)/i) {
		$q = lc($1);
		$u = $6;
		$q =~ s/,/\./;
		$q = unit_to_g($q,$u);
	}

	return $q;
}


=head2 normalize_serving_size($)

Returns the size in g or ml for the serving. Eg.:
normalize_serving_size(1 barquette de 40g) returns 40
normalize_serving_size(2.5kg)              returns 2500

=cut

sub normalize_serving_size($) {

	my $serving = shift;

	my $q = 0;
	my $u;

	if ($serving =~ /((\d+)(\.|,)?(\d+)?)( )?($units)\b/i) {
		$q = lc($1);
		$u = $6;
		$q =~ s/,/\./;
		$q = unit_to_g($q,$u);
	}

	#$log->trace("serving size normalized", { serving => $serving, q => $q, u => $u }) if $log->is_trace();
	return $q;
}


my %pnns = (

	"Fruits" => "Fruits and vegetables",
	"Dried fruits" => "Fruits and vegetables",
	"Vegetables" => "Fruits and vegetables",
	"Soups" => "Fruits and vegetables",

	"Cereals" => "Cereals and potatoes",
	"Bread" => "Cereals and potatoes",
	"Potatoes" => "Cereals and potatoes",
	"Legumes" => "Cereals and potatoes",
	"Breakfast cereals" => "Cereals and potatoes",

	"Dairy desserts" => "Milk and dairy products",
	"Cheese" => "Milk and dairy products",
	"Ice cream" => "Milk and dairy products",
	"Milk and yogurt" => "Milk and dairy products",

	"Offals" => "Fish Meat Eggs",
	"Processed meat" => "Fish Meat Eggs",
	"Eggs" => "Fish Meat Eggs",
	"Fish and seafood" => "Fish Meat Eggs",
	"Meat" => "Fish Meat Eggs",

	"Chocolate products" => "Sugary snacks",
	"Sweets" => "Sugary snacks",
	"Biscuits and cakes" => "Sugary snacks",
	"Pastries" => "Sugary snacks",

	"Nuts" => "Salty snacks",
	"Appetizers" => "Salty snacks",
	"Salty and fatty products" => "Salty snacks",

	"Fats" => "Fat and sauces",
	"Dressings and sauces" => "Fat and sauces",

	"Pizza pies and quiche" => "Composite foods",
	"One-dish meals" => "Composite foods",
	"Sandwiches" => "Composite foods",

	"Artificially sweetened beverages" => "Beverages",
	"Unsweetened beverages" => "Beverages",
	"Sweetened beverages" => "Beverages",
	"Fruit juices" => "Beverages",
	"Fruit nectars" => "Beverages",
	"Waters and flavored waters" => "Beverages",
	"Teas and herbal teas and coffees" => "Beverages",
	"Plant-based milk substitutes" => "Beverages",

	"unknown" => "unknown",

);

foreach my $group (keys %pnns) {
	$pnns{get_string_id_for_lang("en", $group)} = get_string_id_for_lang("en", $pnns{$group});
}


=head2 is_beverage_for_nutrition_score( $product_ref )

Determines if a product should be considered as a beverage for Nutri-Score computations,
based on the product categories.

=cut

sub is_beverage_for_nutrition_score($) {

	my $product_ref = shift;

	my $is_beverage = 0;

	if (has_tag($product_ref,"categories","en:beverages")) {

		$is_beverage = 1;

		if (defined $options{categories_not_considered_as_beverages_for_nutriscore}) {

			foreach my $category_id (@{$options{categories_not_considered_as_beverages_for_nutriscore}}) {

				if (has_tag($product_ref, "categories", $category_id)) {
					$is_beverage = 0;
					last;
				}
			}
		}

		# exceptions
		if (defined $options{categories_considered_as_beverages_for_nutriscore}) {
			foreach my $category_id (@{$options{categories_considered_as_beverages_for_nutriscore}}) {

				if (has_tag($product_ref, "categories", $category_id)) {
					$is_beverage = 1;
					last;
				}
			}
		}
	}

	return $is_beverage;
}


=head2 is_water_for_nutrition_score( $product_ref )

Determines if a product should be considered as water for Nutri-Score computations,
based on the product categories.

=cut

sub is_water_for_nutrition_score($) {

	my $product_ref = shift;

	return ((has_tag($product_ref, "categories", "en:spring-waters")) and not (has_tag($product_ref, "categories", "en:flavored-waters")));
}


=head2 is_cheese_for_nutrition_score( $product_ref )

Determines if a product should be considered as cheese for Nutri-Score computations,
based on the product categories.

=cut

sub is_cheese_for_nutrition_score($) {

	my $product_ref = shift;

	return ((has_tag($product_ref, "categories", "en:cheeses")) and not (has_tag($product_ref, "categories", "fr:fromages-blancs")));
}


=head2 is_fat_for_nutrition_score( $product_ref )

Determines if a product should be considered as fat for Nutri-Score computations,
based on the product categories.

=cut

sub is_fat_for_nutrition_score($) {

	my $product_ref = shift;

	return has_tag($product_ref, "categories", "en:fats");
}


sub special_process_product($) {

	my $product_ref = shift;

	assign_category_properties_to_product($product_ref);

	delete $product_ref->{pnns_groups_1};
	delete $product_ref->{pnns_groups_1_tags};
	delete $product_ref->{pnns_groups_2};
	delete $product_ref->{pnns_groups_2_tags};

	if ((not defined $product_ref->{categories}) or ($product_ref->{categories} eq "")) {
		$product_ref->{pnns_groups_2} = "unknown";
		$product_ref->{pnns_groups_2_tags} = ["unknown", "missing-category"];
		$product_ref->{pnns_groups_1} = "unknown";
		$product_ref->{pnns_groups_1_tags} = ["unknown", "missing-category"];
		return;
	}

	# Only add or remove categories tags temporarily for determining the PNNS groups
	# save the original value

	my @original_categories_tags = ();
	if (defined $product_ref->{categories_tags}) {
		@original_categories_tags = @{$product_ref->{categories_tags}};
	}

	# For Open Food Facts, add special categories for beverages that are computed from
	# nutrition facts (alcoholic or not) or the ingredients (sweetened, artificially sweetened or unsweetened)
	# those tags are only added to categories_tags (searchable in Mongo)
	# and not to the categories_hierarchy (displayed on the web site and in the product edit form)
	# Those extra categories are also used to determined the French PNNS food groups

	$product_ref->{nutrition_score_beverage} = is_beverage_for_nutrition_score($product_ref);

	if (($product_ref->{nutrition_score_beverage}) and (not has_tag($product_ref,"categories","en:instant-beverages"))) {

		if (defined $product_ref->{nutriments}{"alcohol_100g"}) {
			if ($product_ref->{nutriments}{"alcohol_100g"} < 1) {
				if (has_tag($product_ref, "categories", "en:alcoholic-beverages")) {
					remove_tag($product_ref, "categories", "en:alcoholic-beverages");
				}

				if (not has_tag($product_ref, "categories", "en:non-alcoholic-beverages")) {
					add_tag($product_ref, "categories", "en:non-alcoholic-beverages");
				}
			}
			else {
				if (not has_tag($product_ref, "categories", "en:alcoholic-beverages")) {
					add_tag($product_ref, "categories", "en:alcoholic-beverages");
				}

				if (has_tag($product_ref, "categories", "en:non-alcoholic-beverages")) {
					remove_tag($product_ref, "categories", "en:non-alcoholic-beverages");
				}
			}
		}
		else {
			if ((not has_tag($product_ref, "categories", "en:non-alcoholic-beverages"))
				and (not has_tag($product_ref, "categories", "en:alcoholic-beverages")) ) {
				add_tag($product_ref, "categories", "en:non-alcoholic-beverages");
			}
		}

		if ((not (has_tag($product_ref,"categories","en:alcoholic-beverages"))
			or has_tag($product_ref,"categories","en:fruit-juices")
			or has_tag($product_ref,"categories","en:fruit-nectars") ) ) {

			if (has_tag($product_ref,"categories","en:sodas") and (not has_tag($product_ref,"categories","en:diet-sodas"))) {
				if (not has_tag($product_ref,"categories","en:sweetened-beverages"))  {
					add_tag($product_ref, "categories", "en:sweetened-beverages");
				}
				if (has_tag($product_ref,"categories","en:unsweetened-beverages")) {
					remove_tag($product_ref, "categories", "en:unsweetened-beverages");
				}
			}

			if ($product_ref->{with_sweeteners}) {
				if (not has_tag($product_ref,"categories","en:artificially-sweetened-beverages")) {
					add_tag($product_ref, "categories", "en:artificially-sweetened-beverages");
				}
				if (has_tag($product_ref,"categories","en:unsweetened-beverages")) {
					remove_tag($product_ref, "categories", "en:unsweetened-beverages");
				}
			}
			# fix me: ingredients are now partly taxonomized

			if (

				(has_tag($product_ref, "ingredients", "sucre") or has_tag($product_ref, "ingredients", "sucre-de-canne")
				or has_tag($product_ref, "ingredients", "sucre-de-canne-roux") or has_tag($product_ref, "ingredients", "sucre-caramelise")
				or has_tag($product_ref, "ingredients", "sucre-de-canne-bio") or has_tag($product_ref, "ingredients", "sucres")
				or has_tag($product_ref, "ingredients", "pur-sucre-de-canne") or has_tag($product_ref, "ingredients", "sirop-de-sucre-inverti")
				or has_tag($product_ref, "ingredients", "sirop-de-sucre-de-canne") or has_tag($product_ref, "ingredients", "sucre-bio")
				or has_tag($product_ref, "ingredients", "sucre-de-canne-liquide") or has_tag($product_ref, "ingredients", "sucre-de-betterave")
				or has_tag($product_ref, "ingredients", "sucre-inverti") or has_tag($product_ref, "ingredients", "canne-sucre")
				or has_tag($product_ref, "ingredients", "sucre-glucose-fructose") or has_tag($product_ref, "ingredients", "glucose-fructose-et-ou-sucre")
				or has_tag($product_ref, "ingredients", "sirop-de-glucose") or has_tag($product_ref, "ingredients", "glucose")
				or has_tag($product_ref, "ingredients", "sirop-de-fructose") or has_tag($product_ref, "ingredients", "saccharose")
				or has_tag($product_ref, "ingredients", "sirop-de-fructose-glucose") or has_tag($product_ref, "ingredients", "sirop-de-glucose-fructose-de-ble-et-ou-de-mais")
				or has_tag($product_ref, "ingredients", "sugar") or has_tag($product_ref, "ingredients", "sugars")
				or has_tag($product_ref, "ingredients", "en:sugar")
				or has_tag($product_ref, "ingredients", "en:glucose")
				or has_tag($product_ref, "ingredients", "en:fructose")
				)
				) {

				if (not has_tag($product_ref,"categories","en:sweetened-beverages")) {
					add_tag($product_ref, "categories", "en:sweetened-beverages");
				}
				if (has_tag($product_ref,"categories","en:unsweetened-beverages")) {
					remove_tag($product_ref, "categories", "en:unsweetened-beverages");
				}
			}
			else {
				# 2019-01-08: adding back the line below which was previously commented
				# add check that we do have an ingredient list
				if (
					(not has_tag($product_ref,"categories","en:sweetened-beverages")) and
					(not has_tag($product_ref,"categories","en:artificially-sweetened-beverages")) and

					(not has_tag($product_ref,"quality","en:ingredients-100-percent-unknown")) and
					(not has_tag($product_ref,"quality","en:ingredients-90-percent-unknown")) and
					(not has_tag($product_ref,"quality","en:ingredients-80-percent-unknown")) and
					(not has_tag($product_ref,"quality","en:ingredients-70-percent-unknown")) and
					(not has_tag($product_ref,"quality","en:ingredients-60-percent-unknown")) and
					(not has_tag($product_ref,"quality","en:ingredients-50-percent-unknown")) and


					(($product_ref->{lc} eq 'en') or ($product_ref->{lc} eq 'fr'))
					and ((defined $product_ref->{ingredients_text}) and (length($product_ref->{ingredients_text}) > 3))) {

					if (not has_tag($product_ref,"categories","en:unsweetened-beverages")) {
						add_tag($product_ref, "categories", "en:unsweetened-beverages");
					}
				}
				else {
					# remove unsweetened-beverages category that may have been added before
					# we cannot trust it if we do not have a correct ingredients list
					if (has_tag($product_ref,"categories","en:unsweetened-beverages")) {
						remove_tag($product_ref, "categories", "en:unsweetened-beverages");
					}
				}
			}
		}
	}
	else {
		# remove sub-categories for beverages that are not considered beverages for PNNS / Nutriscore
		if (has_tag($product_ref, "categories", "en:alcoholic-beverages")) {
			remove_tag($product_ref, "categories", "en:alcoholic-beverages");
		}
		if (has_tag($product_ref, "categories", "en:non-alcoholic-beverages")) {
			remove_tag($product_ref, "categories", "en:non-alcoholic-beverages");
		}
		if (has_tag($product_ref,"categories","en:sweetened-beverages")) {
			remove_tag($product_ref, "categories", "en:sweetened-beverages");
		}
		if (has_tag($product_ref,"categories","en:artificially-sweetened-beverages")) {
			remove_tag($product_ref, "categories", "en:artificially-sweetened-beverages");
		}
		if (has_tag($product_ref,"categories","en:unsweetened-beverages")) {
			remove_tag($product_ref, "categories", "en:unsweetened-beverages");
		}
	}


	# compute PNNS groups 2 and 1

	foreach my $categoryid (reverse @{$product_ref->{categories_tags}}) {
		if ((defined $properties{categories}{$categoryid}) and (defined $properties{categories}{$categoryid}{"pnns_group_2:en"})) {

			# skip the sweetened / unsweetened if it is alcoholic
			next if (	(has_tag($product_ref, 'categories', 'en:alcoholic-beverages'))
				and (
					($categoryid eq 'en:sweetened-beverages')
					or ($categoryid eq 'en:artificially-sweetened-beverages')
					or ($categoryid eq 'en:unsweetened-beverages')
				)
				);


			# skip the category en:sweetened-beverages if we have the category en:artificially-sweetened-beverages
			next if (($categoryid eq 'en:sweetened-beverages') and has_tag($product_ref, 'categories', 'en:artificially-sweetened-beverages'));

			# skip waters and flavored waters if we have en:artificially-sweetened-beverages or en:sweetened-beverages
			next if (
				(($properties{categories}{$categoryid}{"pnns_group_2:en"} eq "Waters and flavored waters")
				or ($properties{categories}{$categoryid}{"pnns_group_2:en"} eq "Teas and herbal teas and coffees"))

				and ( has_tag($product_ref, 'categories', 'en:sweetened-beverages')
					or has_tag($product_ref, 'categories', 'en:artificially-sweetened-beverages')));

			$product_ref->{pnns_groups_2} = $properties{categories}{$categoryid}{"pnns_group_2:en"};
			$product_ref->{pnns_groups_2_tags} = [get_string_id_for_lang("en", $product_ref->{pnns_groups_2}), "known"];

			# Let waters and teas take precedence over unsweetened-beverages
			if ($properties{categories}{$categoryid}{"pnns_group_2:en"} ne "Unsweetened beverages") {
				last;
			}
		}
	}

	if (defined $product_ref->{pnns_groups_2}) {
		if (defined $pnns{$product_ref->{pnns_groups_2}}) {
			$product_ref->{pnns_groups_1} = $pnns{$product_ref->{pnns_groups_2}};
			$product_ref->{pnns_groups_1_tags} = [get_string_id_for_lang("en", $product_ref->{pnns_groups_1}), "known"];
		}
		else {
			$log->warn("no pnns group 1 for pnns group 2", { pnns_group_2 => $product_ref->{pnns_groups_2} }) if $log->is_warn();
		}
	}
	else {
		# We have a category for the product, but no PNNS groups are associated with this category or a parent category

		$product_ref->{pnns_groups_2} = "unknown";
		$product_ref->{pnns_groups_2_tags} = ["unknown", "missing-association"];
		$product_ref->{pnns_groups_1} = "unknown";
		$product_ref->{pnns_groups_1_tags} = ["unknown", "missing-association"];
	}

	# Put back the original categories_tags so that they match what is in the taxonomy field
	# if there is a mistmatch it can cause tags to be added multiple times (e.g. with imports)
	if (scalar @original_categories_tags) {
		$product_ref->{categories_tags} = \@original_categories_tags;
	}
}



sub fix_salt_equivalent($) {

	my $product_ref = shift;

	# salt

	# EU fixes the conversion: sodium = salt / 2.5 (instead of 2.54 previously)

	foreach my $product_type ("", "_prepared") {

		# use the salt value by default
		if ((defined $product_ref->{nutriments}{'salt' . $product_type . "_value"})
			and ($product_ref->{nutriments}{'salt' . $product_type . "_value"} ne '')) {
		assign_nid_modifier_value_and_unit(
			$product_ref,
			'sodium' . $product_type,
			$product_ref->{nutriments}{'salt' . $product_type . '_modifier'},
			$product_ref->{nutriments}{'salt' . $product_type . "_value"} / 2.5,
			$product_ref->{nutriments}{'salt' . $product_type . '_unit'} );
		}
		elsif ((defined $product_ref->{nutriments}{'sodium' . $product_type  . "_value"}) and ($product_ref->{nutriments}{'sodium' . $product_type . "_value"} ne '')) {
			assign_nid_modifier_value_and_unit(
			$product_ref,
			'salt' . $product_type,
			$product_ref->{nutriments}{'sodium' . $product_type . '_modifier'},
			$product_ref->{nutriments}{'sodium' . $product_type  . "_value"} * 2.5,
			$product_ref->{nutriments}{'sodium' . $product_type . '_unit'});
		}
	}
}


# UK FSA scores thresholds

# estimates by category of products. not exact values. it's important to distinguish only between the thresholds: 40, 60 and 80
my %fruits_vegetables_nuts_by_category = (
	"en:fruit-juices" => 100,
	"en:vegetable-juices" => 100,
	"en:fruit-sauces" => 90,
	"en:vegetables" => 90,
	"en:fruits" => 90,
	"en:mushrooms" => 90,
	"en:canned-fruits" => 90,
	"en:frozen-fruits" => 90,
	"en:jams" => 50,
	"en:fruits-based-foods" => 85,
	"en:vegetables-based-foods" => 85,
	# 2019/08/31: olive oil, walnut oil and colza oil are now considered in the same fruits, vegetables and nuts category
	"en:olive-oils" => 100,
	"en:walnut-oils" => 100,
	# adding multiple wordings for colza/rapeseed oil in case we change it at some point
	"en:colza-oils" => 100,
	"en:rapeseed-oils" => 100,
	"en:rapeseeds-oils" => 100,
	# nuts,
	# "Les fruits à coque comprennent :
	# Noix, noisettes, pistaches, noix de cajou, noix de pécan, noix de coco (cf. précisions ci-dessus),
	# arachides, amandes, châtaigne
	"en:walnuts" => 100,
	"en:hazelnuts" => 100,
	"en:pistachios" => 100,
	"en:cashew-nuts" => 100,
	"en:pecan-nuts" => 100,
	"en:peanuts" => 100,
	"en:almonds" => 100,
	"en:chestnuts" => 100,
	"en:coconuts" => 100,
);

my @fruits_vegetables_nuts_by_category_sorted = sort { $fruits_vegetables_nuts_by_category{$b} <=> $fruits_vegetables_nuts_by_category{$a} } keys %fruits_vegetables_nuts_by_category;


sub compute_nutrition_score($) {

	my $product_ref = shift;

	# Initialize values

	delete $product_ref->{nutrition_score_debug};
	delete $product_ref->{nutriments}{"nutrition-score"};
	delete $product_ref->{nutriments}{"nutrition-score_100g"};
	delete $product_ref->{nutriments}{"nutrition-score_serving"};
	delete $product_ref->{nutriments}{"nutrition-score-fr"};
	delete $product_ref->{nutriments}{"nutrition-score-fr_100g"};
	delete $product_ref->{nutriments}{"nutrition-score-fr_serving"};
	delete $product_ref->{nutriments}{"nutrition-score-uk"};
	delete $product_ref->{nutriments}{"nutrition-score-uk_100g"};
	delete $product_ref->{nutriments}{"nutrition-score-uk_serving"};
	delete $product_ref->{"nutrition_grade_fr"};
	delete $product_ref->{"nutrition_grades"};
	delete $product_ref->{"nutrition_grades_tags"};
	delete $product_ref->{nutrition_score_warning_no_fiber};
	delete $product_ref->{nutrition_score_warning_fruits_vegetables_nuts_estimate};
	delete $product_ref->{nutrition_score_warning_fruits_vegetables_nuts_from_category};
	delete $product_ref->{nutrition_score_warning_fruits_vegetables_nuts_from_category_value};
	delete $product_ref->{nutrition_score_warning_fruits_vegetables_nuts_estimate_from_ingredients};
	delete $product_ref->{nutrition_score_warning_fruits_vegetables_nuts_estimate_from_ingredients_value};
	delete $product_ref->{nutrition_score_warning_no_fruits_vegetables_nuts};
	delete $product_ref->{nutriscore_score};
	delete $product_ref->{nutriscore_grade};
	delete $product_ref->{nutriscore_data};
	delete $product_ref->{nutriscore_points};

	defined $product_ref->{misc_tags} or $product_ref->{misc_tags} = [];

	$product_ref->{misc_tags} = ["en:nutriscore-not-computed"];

	my $prepared = '';

	# do not compute a score when we don't have a category
	if ((not defined $product_ref->{categories}) or ($product_ref->{categories} eq '')) {
		$product_ref->{"nutrition_grades_tags"} = [ "not-applicable" ];
		$product_ref->{nutrition_score_debug} = "no score when the product does not have a category";
		return;
	}

	if (not defined $product_ref->{nutrition_score_beverage}) {
		$product_ref->{"nutrition_grades_tags"} = [ "not-applicable" ];
		$product_ref->{nutrition_score_debug} = "did not determine if it was a beverage";
		return;
	}


	# do not compute a score for dehydrated products to be rehydrated (e.g. dried soups, powder milk)
	# unless we have nutrition data for the prepared product
	# same for en:chocolate-powders, en:dessert-mixes and en:flavoured-syrups

	foreach my $category_tag ("en:dried-products-to-be-rehydrated", "en:chocolate-powders", "en:dessert-mixes", "en:flavoured-syrups", "en:instant-beverages") {

		if (has_tag($product_ref, "categories", $category_tag)) {

			if ((defined $product_ref->{nutriments}{"energy_prepared_100g"})) {
				$product_ref->{nutrition_score_debug} = "using prepared product data for category $category_tag";
				$prepared = '_prepared';
				last;
			}
			else {
				$product_ref->{"nutrition_grades_tags"} = [ "not-applicable" ];
				$product_ref->{nutrition_score_debug} = "no score for category $category_tag without data for prepared product";
				return;
			}
		}
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
					$product_ref->{"nutrition_grades_tags"} = [ "not-applicable" ];
					$product_ref->{nutrition_score_debug} = "no nutriscore for category $category_id";
					return;
				}
			}
		}
	}

	# Spring waters have grade A automatically, and have a different nutrition table without sugars etc.
	# do not display warnings about missing fiber and fruits

	if (not ((has_tag($product_ref, "categories", "en:spring-waters")) and not (has_tag($product_ref, "categories", "en:flavored-waters")))) {

		# compute the score only if all values are known
		# for fiber, compute score without fiber points if the value is not known
		# foreach my $nid ("energy", "saturated-fat", "sugars", "sodium", "fiber", "proteins") {

		foreach my $nid ("energy", "fat", "saturated-fat", "sugars", "sodium", "proteins") {
			if (not defined $product_ref->{nutriments}{$nid . $prepared . "_100g"}) {
				$product_ref->{"nutrition_grades_tags"} = [ "unknown" ];
				push @{$product_ref->{misc_tags}}, "en:nutrition-not-enough-data-to-compute-nutrition-score";
				if (not defined $product_ref->{nutriments}{"saturated-fat"  . $prepared . "_100g"}) {
					push @{$product_ref->{misc_tags}}, "en:nutrition-no-saturated-fat";
				}
				$product_ref->{nutrition_score_debug} .= "missing " . $nid . $prepared;
				return;
			}
		}

		# some categories of products do not have fibers > 0.7g (e.g. sodas)
		# for others, display a warning when the value is missing
		if ((not defined $product_ref->{nutriments}{"fiber" . $prepared . "_100g"})
			and not (has_tag($product_ref, "categories", "en:sodas"))) {
			$product_ref->{nutrition_score_warning_no_fiber} = 1;
			push @{$product_ref->{misc_tags}}, "en:nutrition-no-fiber";
		}
	}

	if ($prepared ne '') {
		push @{$product_ref->{misc_tags}}, "en:nutrition-grade-computed-for-prepared-product";
	}

	# Compute the fruit % according to the Nutri-Score rules

	my $fruits = undef;

	if (defined $product_ref->{nutriments}{"fruits-vegetables-nuts-dried" . $prepared . "_100g"}) {
		$fruits = 2 * $product_ref->{nutriments}{"fruits-vegetables-nuts-dried" . $prepared . "_100g"};
		push @{$product_ref->{misc_tags}}, "en:nutrition-fruits-vegetables-nuts-dried";

		if (defined $product_ref->{nutriments}{"fruits-vegetables-nuts" . $prepared . "_100g"}) {
			$fruits += $product_ref->{nutriments}{"fruits-vegetables-nuts" . $prepared . "_100g"};
			push @{$product_ref->{misc_tags}}, "en:nutrition-fruits-vegetables-nuts";
		}

		$fruits = $fruits * 100 / (100 + $product_ref->{nutriments}{"fruits-vegetables-nuts-dried" . $prepared . "_100g"});
	}
	elsif (defined $product_ref->{nutriments}{"fruits-vegetables-nuts" . $prepared . "_100g"}) {
		$fruits = $product_ref->{nutriments}{"fruits-vegetables-nuts" . $prepared . "_100g"};
		push @{$product_ref->{misc_tags}}, "en:nutrition-fruits-vegetables-nuts";
	}
	elsif (defined $product_ref->{nutriments}{"fruits-vegetables-nuts-estimate" . $prepared . "_100g"}) {
		$fruits = $product_ref->{nutriments}{"fruits-vegetables-nuts-estimate" . $prepared . "_100g"};
		$product_ref->{nutrition_score_warning_fruits_vegetables_nuts_estimate} = 1;
		push @{$product_ref->{misc_tags}}, "en:nutrition-fruits-vegetables-nuts-estimate";
	}
	# estimates by category of products. not exact values. it's important to distinguish only between the thresholds: 40, 60 and 80
	else {
		foreach my $category_id (@fruits_vegetables_nuts_by_category_sorted ) {

			if (has_tag($product_ref, "categories", $category_id)) {
				$fruits = $fruits_vegetables_nuts_by_category{$category_id};
				$product_ref->{nutrition_score_warning_fruits_vegetables_nuts_from_category} = $category_id;
				$product_ref->{nutrition_score_warning_fruits_vegetables_nuts_from_category_value} = $fruits_vegetables_nuts_by_category{$category_id};
				push @{$product_ref->{misc_tags}}, "en:nutrition-fruits-vegetables-nuts-from-category";
				my $category = $category_id;
				$category =~ s/:/-/;
				push @{$product_ref->{misc_tags}}, "en:nutrition-fruits-vegetables-nuts-from-category-$category";
				last;
			}
		}

		# Use the estimate from the ingredients list if we have one
		if ((not defined $fruits)
			and (defined $product_ref->{nutriments}{"fruits-vegetables-nuts-estimate-from-ingredients" . $prepared . "_100g"})) {
			$fruits = $product_ref->{nutriments}{"fruits-vegetables-nuts-estimate-from-ingredients" . $prepared . "_100g"};
			$product_ref->{nutrition_score_warning_fruits_vegetables_nuts_estimate_from_ingredients} = 1;
			$product_ref->{nutrition_score_warning_fruits_vegetables_nuts_estimate_from_ingredients_value} = $fruits;
			push @{$product_ref->{misc_tags}}, "en:nutrition-fruits-vegetables-nuts-estimate-from-ingredients";
		}

		if (not defined $fruits) {
			$fruits = 0;
			$product_ref->{nutrition_score_warning_no_fruits_vegetables_nuts} = 1;
			push @{$product_ref->{misc_tags}}, "en:nutrition-no-fruits-vegetables-nuts";
		}

	}

	if ((defined $product_ref->{nutrition_score_warning_no_fiber}) or (defined $product_ref->{nutrition_score_warning_no_fruits_vegetables_nuts})) {
		push @{$product_ref->{misc_tags}}, "en:nutrition-no-fiber-or-fruits-vegetables-nuts";
	}
	else {
		push @{$product_ref->{misc_tags}}, "en:nutrition-all-nutriscore-values-known";
	}

	my $saturated_fat = $product_ref->{nutriments}{"saturated-fat" . $prepared . "_100g"};
	my $fat = $product_ref->{nutriments}{"fat" . $prepared . "_100g"};
	my $saturated_fat_ratio = 0;
	if ((defined $saturated_fat) and ($saturated_fat > 0)) {
		if ($fat <= 0) {
			$fat = $saturated_fat;
		}
		$saturated_fat_ratio = $saturated_fat / $fat * 100;	# in %
	}

	# Populate the data structure that will be passed to Food::Nutriscore

	$product_ref->{nutriscore_data} = {
		is_beverage => $product_ref->{nutrition_score_beverage},
		is_water => is_water_for_nutrition_score($product_ref),
		is_cheese => is_cheese_for_nutrition_score($product_ref),
		is_fat => is_fat_for_nutrition_score($product_ref),

		energy => $product_ref->{nutriments}{"energy" . $prepared . "_100g"},
		sugars => $product_ref->{nutriments}{"sugars" . $prepared . "_100g"},
		saturated_fat => $product_ref->{nutriments}{"saturated-fat" . $prepared . "_100g"},
		saturated_fat_ratio => $saturated_fat_ratio,
		sodium => $product_ref->{nutriments}{"sodium" . $prepared . "_100g"} * 1000,	# in mg,

		fruits_vegetables_nuts_colza_walnut_olive_oils => $fruits,
		fiber => ((defined $product_ref->{nutriments}{"fiber" . $prepared . "_100g"}) ? $product_ref->{nutriments}{"fiber" . $prepared . "_100g"} : 0),
		proteins => $product_ref->{nutriments}{"proteins" . $prepared . "_100g"},
	};

	my ($nutriscore_score, $nutriscore_grade) = ProductOpener::Nutriscore::compute_nutriscore_score_and_grade($product_ref->{nutriscore_data});

	$product_ref->{nutriscore_score} = $nutriscore_score;
	$product_ref->{nutriscore_grade} = $nutriscore_grade;

	$product_ref->{nutriments}{"nutrition-score-fr_100g"} = $nutriscore_score;
	$product_ref->{nutriments}{"nutrition-score-fr"} = $nutriscore_score;

	$product_ref->{"nutrition_grade_fr"} = $nutriscore_grade;

	$product_ref->{"nutrition_grades_tags"} = [$product_ref->{"nutrition_grade_fr"}];
	$product_ref->{"nutrition_grades"} = $product_ref->{"nutrition_grade_fr"};  # needed for the /nutrition-grade/unknown query

	shift @{$product_ref->{misc_tags}};
	push @{$product_ref->{misc_tags}}, "en:nutriscore-computed";
}




sub compute_serving_size_data($) {

	my $product_ref = shift;

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
		(defined $product_ref->{serving_size}) and ($product_ref->{serving_size} eq "") and delete $product_ref->{serving_size};
	}

	# Record if we have nutrient values for as sold or prepared types,
	# so that we can check the nutrition_data and nutrition_data_prepared boxes if we have data
	my %nutrition_data = ();

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
			assign_nid_modifier_value_and_unit($product_ref, "energy" . $product_type,
				$product_ref->{nutriments}{"energy-kj" . $product_type . "_modifier"},
				$product_ref->{nutriments}{"energy-kj" . $product_type . "_value"},
				$product_ref->{nutriments}{"energy-kj" . $product_type . "_unit"});
		}
		# Otherwise use the energy-kcal value for energy
		elsif (defined $product_ref->{nutriments}{"energy-kcal" . $product_type }) {
			if (not defined $product_ref->{nutriments}{"energy-kcal" . $product_type . "_unit"}) {
				$product_ref->{nutriments}{"energy-kcal" . $product_type . "_unit"} = "kcal";
			}
			assign_nid_modifier_value_and_unit($product_ref, "energy" . $product_type,
				$product_ref->{nutriments}{"energy-kcal" . $product_type . "_modifier"},
				$product_ref->{nutriments}{"energy-kcal" . $product_type . "_value"},
				$product_ref->{nutriments}{"energy-kcal" . $product_type . "_unit"});		}
		# Otherwise, if we have a value and a unit for the energy field, copy it to either energy-kj or energy-kcal
		elsif ((defined $product_ref->{nutriments}{"energy" . $product_type . "_value"}) and (defined $product_ref->{nutriments}{"energy" . $product_type . "_unit"})) {

			my $unit = lc($product_ref->{nutriments}{"energy" . $product_type . "_unit"});

			assign_nid_modifier_value_and_unit($product_ref, "energy-$unit" . $product_type,
				$product_ref->{nutriments}{"energy" . $product_type . "_modifier"},
				$product_ref->{nutriments}{"energy" . $product_type . "_value"},
				$product_ref->{nutriments}{"energy" . $product_type . "_unit"});
		}

		if (not defined $product_ref->{"nutrition_data" . $product_type . "_per"}) {
			$product_ref->{"nutrition_data" . $product_type . "_per"} = '100g';
		}

		if ($product_ref->{"nutrition_data" . $product_type . "_per"} eq 'serving') {

			foreach my $nid (keys %{$product_ref->{nutriments}}) {
				if (($product_type eq "") and ($nid =~ /_/)
					or (($product_type eq "_prepared") and ($nid !~ /_prepared$/))) {

					next;
				}
				$nid =~ s/_prepared$//;

				$product_ref->{nutriments}{$nid . $product_type . "_serving"} = $product_ref->{nutriments}{$nid . $product_type};
				$product_ref->{nutriments}{$nid . $product_type . "_serving"} =~ s/^(<|environ|max|maximum|min|minimum)( )?//;
				$product_ref->{nutriments}{$nid . $product_type . "_serving"} += 0.0;
				delete $product_ref->{nutriments}{$nid . $product_type . "_100g"};

				if (($nid eq 'alcohol') or ((exists $Nutriments{$nid}) and (exists $Nutriments{$nid}{unit})
					and (($Nutriments{$nid}{unit} eq '') or ($Nutriments{$nid}{unit} eq '%')))) {
					$product_ref->{nutriments}{$nid . $product_type . "_100g"} = $product_ref->{nutriments}{$nid . $product_type} + 0.0;
				}
				elsif ((defined $product_ref->{serving_quantity}) and ($product_ref->{serving_quantity} > 0)) {

					$product_ref->{nutriments}{$nid . $product_type . "_100g"} = sprintf("%.2e",$product_ref->{nutriments}{$nid . $product_type} * 100.0 / $product_ref->{serving_quantity}) + 0.0;

					# Record that we have a nutrient value for this product type (with a unit, not NOVA, alcohol % etc.)
					$nutrition_data{$product_type} = 1;
				}

			}
		}
		else {

			foreach my $nid (keys %{$product_ref->{nutriments}}) {
				if (($product_type eq "") and ($nid =~ /_/)
					or (($product_type eq "_prepared") and ($nid !~ /_prepared$/))) {

					next;
				}
				$nid =~ s/_prepared$//;

				$product_ref->{nutriments}{$nid . $product_type . "_100g"} = $product_ref->{nutriments}{$nid . $product_type};
				$product_ref->{nutriments}{$nid . $product_type . "_100g"} =~ s/^(<|environ|max|maximum|min|minimum)( )?//;
				$product_ref->{nutriments}{$nid . $product_type . "_100g"} += 0.0;
				delete $product_ref->{nutriments}{$nid . $product_type . "_serving"};

				if (($nid eq 'alcohol') or ((exists $Nutriments{$nid . $product_type}) and (exists $Nutriments{$nid . $product_type}{unit})
					and (($Nutriments{$nid}{unit} eq '') or ($Nutriments{$nid}{unit} eq '%')))) {
					$product_ref->{nutriments}{$nid . $product_type . "_serving"} = $product_ref->{nutriments}{$nid . $product_type} + 0.0;
				}
				elsif ((defined $product_ref->{serving_quantity}) and ($product_ref->{serving_quantity} > 0)) {

					$product_ref->{nutriments}{$nid . $product_type . "_serving"} = sprintf("%.2e",$product_ref->{nutriments}{$nid . $product_type} / 100.0 * $product_ref->{serving_quantity}) + 0.0;

					# Record that we have a nutrient value for this product type (with a unit, not NOVA, alcohol % etc.)
					$nutrition_data{$product_type} = 1;
				}

			}

		}

		# Carbon footprint

		if (defined $product_ref->{nutriments}{"carbon-footprint-from-meat-or-fish_100g"}) {

			if (defined $product_ref->{serving_quantity}) {
				$product_ref->{nutriments}{"carbon-footprint-from-meat-or-fish_serving"}
				= sprintf("%.2e",$product_ref->{nutriments}{"carbon-footprint-from-meat-or-fish_100g"} / 100.0 * $product_ref->{serving_quantity}) + 0.0;
			}

			if (defined $product_ref->{product_quantity}) {
				$product_ref->{nutriments}{"carbon-footprint-from-meat-or-fish_product"}
				= sprintf("%.2e",$product_ref->{nutriments}{"carbon-footprint-from-meat-or-fish_100g"} / 100.0 * $product_ref->{product_quantity}) + 0.0;
			}
		}

		if (defined $product_ref->{nutriments}{"carbon-footprint-from-known-ingredients_100g"}) {

			if (defined $product_ref->{serving_quantity}) {
				$product_ref->{nutriments}{"carbon-footprint-from-known-ingredients_serving"}
				= sprintf("%.2e",$product_ref->{nutriments}{"carbon-footprint-from-known-ingredients_100g"} / 100.0 * $product_ref->{serving_quantity}) + 0.0;
			}

			if (defined $product_ref->{product_quantity}) {
				$product_ref->{nutriments}{"carbon-footprint-from-known-ingredients_product"}
				= sprintf("%.2e",$product_ref->{nutriments}{"carbon-footprint-from-known-ingredients_100g"} / 100.0 * $product_ref->{product_quantity}) + 0.0;
			}
		}
	}

	# If we have nutrient data for as sold or prepared, make sure the checkbox are ticked
	foreach my $product_type (sort keys %nutrition_data) {
		if ((not defined $product_ref->{"nutrition_data" . $product_type}) or ($product_ref->{"nutrition_data" . $product_type} ne "on")) {
			$product_ref->{"nutrition_data" . $product_type} = 'on';
		}
	}
}


sub compute_carbon_footprint_infocard($) {

	my $product_ref = shift;

	# compute the environment impact level
	# -> currently only for prepared meals

	# Limit to France, as the carbon values from ADEME are intended for France

	if (not ((has_tag($product_ref, "countries", "en:france")) and (defined $product_ref->{ingredients_text})
		and (length($product_ref->{ingredients_text}) > 5))) {
		delete $product_ref->{environment_impact_level};
		delete $product_ref->{environment_impact_level_tags};
		delete $product_ref->{environment_infocard};
		delete $product_ref->{environment_infocard_en};
		delete $product_ref->{environment_infocard_fr};
		return;
	}

	if (has_tag($product_ref, "categories", "en:meals")) {

		$product_ref->{environment_impact_level} = "en:low";

		if ((defined  $product_ref->{nutriments}) and (defined $product_ref->{nutriments}{"carbon-footprint-from-meat-or-fish_product"})) {

			if ($product_ref->{nutriments}{"carbon-footprint-from-meat-or-fish_product"} < 250) {
				$product_ref->{environment_impact_level} = "en:medium";
			}
			else {
				$product_ref->{environment_impact_level} = "en:high";
			}
		}

		$product_ref->{environment_impact_level_tags} = [$product_ref->{environment_impact_level}];
	}

	# compute the carbon footprint infocard when we have a carbon footprint from meat or fish

	if ((defined $product_ref->{nutriments}) and (defined $product_ref->{nutriments}{"carbon-footprint-from-meat-or-fish_product"})) {

		foreach my $lang ("en", "fr") {
			my $html = "<h2>" . $Lang{carbon_impact_from_meat_or_fish}{$lang} . "</h2>";

			$html .= "<ul>\n";

			$html .= "<li><b>" . (sprintf("%.2e", $product_ref->{nutriments}{"carbon-footprint-from-meat-or-fish_product"} / 1000) + 0.0)
				. " kg</b> " . $Lang{of_carbon_impact_from_meat_or_fish_for_whole_product}{$lang};

			if (defined $product_ref->{nutriments}{"carbon-footprint-from-meat-or-fish_serving"}) {
				$html .= " (<b>" .( sprintf("%.2e", $product_ref->{nutriments}{"carbon-footprint-from-meat-or-fish_serving"} / 1000) + 0.0)
				. " kg</b> " . $Lang{for_one_serving}{$lang} . ")";
			}

			$html .= "</li>\n";

			# COP 21 sustainable amount of CO2 per person per year: 2 tons
			my %sustainable = (annual => 2000 * 1000);
			$sustainable{daily} = $sustainable{annual} / 365;
			$sustainable{weekly} = $sustainable{daily} * 7;

			foreach my $period ("daily", "weekly") {

				$html .= "<li><b>" . (sprintf("%.2e", $product_ref->{nutriments}{"carbon-footprint-from-meat-or-fish_product"} / $sustainable{$period} * 100) + 0.0)
					. "%</b> " . $Lang{"of_sustainable_" . $period . "_emissions_of_1_person"}{$lang};

				if (defined $product_ref->{nutriments}{"carbon-footprint-from-meat-or-fish_serving"}) {
					$html .= " (<b>" .( sprintf("%.2e", $product_ref->{nutriments}{"carbon-footprint-from-meat-or-fish_serving"} / $sustainable{$period} * 100) + 0.0)
					. "%</b> " . $Lang{for_one_serving}{$lang} . ")";
				}

				$html .= "</li>\n";
			}

			$html .= "</ul>";

			$html .= "<br><br>";

			$html .= "<h3>" . $Lang{methodology}{$lang} . "</h3>"
			. "<p>" . $Lang{carbon_footprint_note_foodges_ademe}{$lang} . "</p>"
			. "<p>" . $Lang{carbon_footprint_note_sustainable_annual_emissions}{$lang} . "</p>"
			. "<p>" . $Lang{carbon_footprint_note_uncertainty}{$lang} . "</p>";

			$product_ref->{"environment_infocard_" . $lang} = $html;
		}

		# copy the main language
		if (defined $product_ref->{"environment_infocard_" . $product_ref->{lc}}) {
			$product_ref->{environment_infocard} = $product_ref->{"environment_infocard_" . $product_ref->{lc}};
		}
		else {
			$product_ref->{environment_infocard} = $product_ref->{environment_infocard_en};
		}
	}
}


sub compute_unknown_nutrients($) {

	my $product_ref = shift;

	$product_ref->{unknown_nutrients_tags} = [];

	foreach my $nid (keys %{$product_ref->{nutriments}}) {

		next if $nid =~ /_/;

		if ((not exists $Nutriments{$nid}) and (defined $product_ref->{nutriments}{$nid . "_label"})) {
			push @{$product_ref->{unknown_nutrients_tags}}, $nid;
		}
	}

}


sub compute_nutrient_levels($) {

	my $product_ref = shift;

	#$product_ref->{nutrient_levels_debug} .= " -- start ";

	$product_ref->{nutrient_levels_tags} = [];
	$product_ref->{nutrient_levels} = {};

	return if ((not defined $product_ref->{categories}) or ($product_ref->{categories} eq ''));	# need categories hierarchy in order to identify drinks

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
				$product_ref->{"nutrition_grades_tags"} = [ "not-applicable" ];
				return;
			}
		}
	}


	foreach my $nutrient_level_ref (@nutrient_levels) {
		my ($nid, $low, $high) = @$nutrient_level_ref;

		# divide low and high per 2 for drinks

		if (has_tag($product_ref, "categories", "en:beverages")) {
			$low = $low / 2;
			$high = $high / 2;
		}

		if ((defined $product_ref->{nutriments}{$nid . $prepared . "_100g"}) and ($product_ref->{nutriments}{$nid . $prepared . "_100g"} ne '')) {

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
				'en:' . get_string_id_for_lang("en", sprintf($Lang{nutrient_in_quantity}{en}, $Nutriments{$nid}{en}, $Lang{$product_ref->{nutrient_levels}{$nid} . "_quantity"}{en}));

		}
		else {
			delete $product_ref->{nutrient_levels}{$nid};
		}
			#$product_ref->{nutrient_levels_debug} .= " -- nid: $nid - low: $low - high: $high - level: " . $product_ref->{nutrient_levels}{$nid} . " -- value: " . $product_ref->{nutriments}{$nid . "_100g"} . " --- ";

	}

}


=head2 create_nutrients_level_taxonomy ()

C<create_nutrients_level_taxonomy()> creates the source file for the nutrients level
taxonomy: /taxonomies/nutrient_levels.txt

It creates entries such as "High in saturated fat" in all languages.

=cut

sub create_nutrients_level_taxonomy() {

	my $nutrient_levels_taxonomy = '';

	foreach my $nutrient_level_ref (@nutrient_levels) {
		my ($nid, $low, $high) = @$nutrient_level_ref;
		foreach my $level ('low', 'moderate', 'high') {
			$nutrient_levels_taxonomy .= "\n" . 'en:' . sprintf($Lang{nutrient_in_quantity}{en}, $Nutriments{$nid}{en}, $Lang{$level . "_quantity"}{en}) . "\n";
			foreach my $l (sort keys %Langs) {
				next if $l eq 'en';
				my $nutrient_l;
				if (defined $Nutriments{$nid}{$l}) {
					$nutrient_l = $Nutriments{$nid}{$l};
				}
				else {
					$nutrient_l = $Nutriments{$nid}{"en"};
				}
				$nutrient_levels_taxonomy .= $l . ':' . sprintf($Lang{nutrient_in_quantity}{$l}, $nutrient_l, $Lang{$level . "_quantity"}{$l}) . "\n";
			}
		}
	}

	open (my $OUT, ">:encoding(UTF-8)", "$data_root/taxonomies/nutrient_levels.txt");
	print $OUT <<TXT
# nutrient levels taxonomy generated automatically by Food.pm

TXT
;
	print $OUT $nutrient_levels_taxonomy;
	close $OUT;
}

sub compute_units_of_alcohol($$) {

	my ( $product_ref, $serving_size_in_ml ) = @_;

	if ( (defined $product_ref) and (defined $serving_size_in_ml)
		and (defined $product_ref->{nutriments}{'alcohol'})
		and (has_tag($product_ref, 'categories', 'en:alcoholic-beverages'))) {
		return $serving_size_in_ml * ($product_ref->{nutriments}{'alcohol'} / 1000.0);
	}
	else {
		return;
	}
}

sub compare_nutriments($$) {

	my $a_ref = shift; # can be a product, a category, ajr etc. -> needs {nutriments}{$nid} values
	my $b_ref = shift;

	my %nutriments = ();

	foreach my $nid (keys %{$b_ref->{nutriments}}) {
		next if $nid !~ /_100g$/;
		$log->trace("compare_nutriments", { nid => $nid }) if $log->is_trace();
		if ($b_ref->{nutriments}{$nid} ne '') {
			$nutriments{$nid} = $b_ref->{nutriments}{$nid};
			if (($b_ref->{nutriments}{$nid} > 0) and (defined $a_ref->{nutriments}{$nid}) and ($a_ref->{nutriments}{$nid} ne '')){
				$nutriments{"${nid}_%"} = ($a_ref->{nutriments}{$nid} - $b_ref->{nutriments}{$nid})/ $b_ref->{nutriments}{$nid} * 100;
			}
			$log->trace("compare_nutriments", { nid => $nid, value => $nutriments{$nid}, percent => $nutriments{"$nid.%"} }) if $log->is_trace();
		}
	}

	return \%nutriments;

}


foreach my $key (keys %Nutriments) {

	if (not exists $Nutriments{$key}{unit}) {
		$Nutriments{$key}{unit} = 'g';
	}
	if (exists $Nutriments{$key}{fr}) {
		foreach my $l (sort @Langs) {
			next if $l eq 'fr';
			# we should not use iu and dv as keys for international units and daily values as they are language codes too
			# FIXME / TODO : change key names in Food.pm
			next if $l eq 'iu';
			next if $l eq 'dv';
			my $short_l = undef;
			if ($l =~ /_/) {
				$short_l = $`,  # pt_pt
			}
			if (not exists $Nutriments{$key}{$l}) {
				if ((defined $short_l) and (exists $Nutriments{$key}{$short_l})) {
					$Nutriments{$key}{$l} = $Nutriments{$key}{$short_l};
				}
				elsif (exists $Nutriments{$key}{en}) {
					$Nutriments{$key}{$l} = $Nutriments{$key}{en};
				}
				else {
					$Nutriments{$key}{$l} = $Nutriments{$key}{fr};
				}
			}
		}
	}
}

Hash::Util::lock_keys(%Nutriments);

$ec_code_regexp = "ce|eec|ec|eg|we|ek|ey|eu|eü";

sub normalize_packager_codes($) {

	my $codes = shift;

	$codes = uc($codes);

	$codes =~ s/\/\///g;

	$codes =~ s/(^|,|, )(emb|e)(\s|-|_|\.)?(\d+)(\.|-|\s)?(\d+)(\.|_|\s|-)?([a-z]*)/$1EMB $4$6$8/ig;

	# FRANCE -> FR
	$codes =~ s/(^|,|, )(france)/$1FR/ig;

	# most common forms:
	# ES 12.06648/C CE
	# ES 26.00128/SS CE
	# UK DZ7131 EC (with sometime spaces but not always, can be a mix of letters and numbers)

	my $normalize_fr_ce_code = sub ($$) {
		my $countrycode = shift;
		my $number = shift;
		$countrycode = uc($countrycode);
		$number =~ s/\D//g;
		$number =~ s/^(\d\d)(\d\d\d)(\d)/$1.$2.$3/;
		$number =~ s/^(\d\d)(\d\d)/$1.$2/;
		# put leading 0s at the end
		$number =~ s/\.(\d)$/\.00$1/;
		$number =~ s/\.(\d\d)$/\.0$1/;
		return "$countrycode $number EC";
	};

	my $normalize_uk_ce_code = sub ($$) {
		my $countrycode = shift;
		my $code = shift;
		$countrycode = uc($countrycode);
		$code = uc($code);
		$code =~ s/\s|-|_|\.|\///g;
		return "$countrycode $code EC";
	};

	my $normalize_es_ce_code = sub ($$$$) {
		my $countrycode = shift;
		my $code1 = shift;
		my $code2 = shift;
		my $code3 = shift;
		$countrycode = uc($countrycode);
		$code3 = uc($code3);
		return "$countrycode $code1.$code2/$code3 EC";
	};

	my $normalize_ce_code = sub ($$) {
		my $countrycode = shift;
		my $code = shift;
		$countrycode = uc($countrycode);
		$code = uc($code);
		return "$countrycode $code EC";
	};

	my $normalize_lu_ce_code = sub ($$) {
		my $countrycode = shift;
		my $letters = shift;
		$letters = uc($letters);
		my $number = shift;
		$countrycode = uc($countrycode);
		return "$countrycode $letters$number EC";
	};

	my $normalize_rs_ce_code = sub ($$) {
		my $countrycode = shift;
		my $code = shift;
		$code = uc($code);
		return "$countrycode $code EC";
	};

	# CE codes -- FR 67.145.01 CE
	#$codes =~ s/(^|,|, )(fr)(\s|-|_|\.)?((\d|\.|_|\s|-)+)(\.|_|\s|-)?(ce)?\b/$1 . $normalize_fr_ce_code->($2,$4)/ieg;	 # without CE, only for FR
	$codes =~ s/(^|,|, )(fr)(\s|-|_|\.)?((\d|\.|_|\s|-)+?)(\.|_|\s|-)?($ec_code_regexp)\b/$1 . $normalize_fr_ce_code->($2,$4)/ieg;

	$codes =~ s/(^|,|, )(uk)(\s|-|_|\.)?((\w|\.|_|\s|-)+?)(\.|_|\s|-)?($ec_code_regexp)\b/$1 . $normalize_uk_ce_code->($2,$4)/ieg;
	$codes =~ s/(^|,|, )(uk)(\s|-|_|\.|\/)*((\w|\.|_|\s|-|\/)+?)(\.|_|\s|-)?($ec_code_regexp)\b/$1 . $normalize_uk_ce_code->($2,$4)/ieg;

	# NO-RGSEAA-21-21552-SE -> ES 21.21552/SE


	$codes =~ s/(^|,|, )n(o|°|º)?(\s|-|_|\.)?rgseaa(\s|-|_|\.|:|;)*(\d\d)(\s|-|_|\.)?(\d+)(\s|-|_|\.|\/|\\)?(\w+)\b/$1 . $normalize_es_ce_code->('es',$5,$7,$9)/ieg;
	$codes =~ s/(^|,|, )(es)(\s|-|_|\.)?(\d\d)(\s|-|_|\.|:|;)*(\d+)(\s|-|_|\.|\/|\\)?(\w+)(\.|_|\s|-)?($ec_code_regexp)?(?=,|$)/$1 . $normalize_es_ce_code->('es',$4,$6,$8)/ieg;

	# LU L-2 --> LU L2

	$codes =~ s/(^|,|, )(lu)(\s|-|_|\.|\/)*(\w)( |-|\.)(\d+)(\.|_|\s|-)?($ec_code_regexp)\b/$1 . $normalize_lu_ce_code->('lu',$4,$6)/ieg;

	# RS 731 -> RS 731 EC

	$codes =~ s/(^|,|, )(rs)(\s|-|_|\.|\/)*(\w+)(\.|_|\s|-)?($ec_code_regexp)?\b/$1 . $normalize_rs_ce_code->('rs',$4)/ieg;

	$codes =~ s/(^|,|, )(\w\w)(\s|-|_|\.|\/)*((\w|\.|_|\s|-|\/)+?)(\.|_|\s|-)?($ec_code_regexp)\b/$1 . $normalize_ce_code->($2,$4)/ieg;

	return $codes;
}

my %local_ec = (
	DE => "EG",
	EE => "EÜ",
	ES => "CE",
	FI => "EY",
	FR => "CE",
	IT => "CE",
	NL => "EG",
	PL => "WE",
	PT => "CE",
	UK => "EC",
);

sub localize_packager_code($) {

	my $code = shift;

	my $local_code = $code;

	if ($code =~ /^(\w\w) (.*) EC$/i) {

		my $country_code = uc($1);
		my $actual_code = $2;

		if (defined $local_ec{$country_code}) {
			$local_code = $country_code . " " . $actual_code . " " . $local_ec{$country_code};
		}
	}

	return $local_code;
}


# Load geocoded addresses


sub get_canon_local_authority($) {

	my $local_authority = shift;

	$local_authority =~ s/LB of/London Borough of/;
	$local_authority =~ s/CC/City Council/;
	$local_authority =~ s/MBC/Metropolitan Borough Council/;
	$local_authority =~ s/MDC/Metropolitan District Council/;
	$local_authority =~ s/BC/Borough Council/;
	$local_authority =~ s/DC/District Council/;
	$local_authority =~ s/RB/Regulatory Bureau/;
	$local_authority =~ s/Co (.*)/$1 Council/;

	my $canon_local_authority = $local_authority;
	$canon_local_authority =~ s/\b(london borough of|city|of|rb|bc|dc|mbc|mdc|cc|borough|metropolitan|district|county|co|council)\b/ /ig;
	$canon_local_authority =~ s/ +/ /g;
	$canon_local_authority =~ s/^ //;
	$canon_local_authority =~ s/ $//;
	$canon_local_authority = get_string_id_for_lang("en",$canon_local_authority);

	return $canon_local_authority;
}

if (-e "$data_root/packager-codes/packager_codes.sto") {
	my $packager_codes_ref = retrieve("$data_root/packager-codes/packager_codes.sto");
	%packager_codes = %{$packager_codes_ref};
}

if (-e "$data_root/packager-codes/geocode_addresses.sto") {
	my $geocode_addresses_ref = retrieve("$data_root/packager-codes/geocode_addresses.sto");
	%geocode_addresses = %{$geocode_addresses_ref};
}


sub compute_nova_group($) {

	# compute Nova group
	# http://archive.wphna.org/wp-content/uploads/2016/01/WN-2016-7-1-3-28-38-Monteiro-Cannon-Levy-et-al-NOVA.pdf

	my $product_ref = shift;

	delete $product_ref->{nova_group_debug};
	delete $product_ref->{nutriments}{"nova-group"};
	delete $product_ref->{nutriments}{"nova-group_100g"};
	delete $product_ref->{nutriments}{"nova-group_serving"};
	delete $product_ref->{nova_group};
	delete $product_ref->{nova_groups};
	delete $product_ref->{nova_groups_tags};

	$product_ref->{nova_group_debug} = "";

	# If we don't have ingredients, only compute score for water
	if ((not defined $product_ref->{ingredients_text}) or ($product_ref->{ingredients_text} eq '')) {

		# Exclude flavored waters
		if (has_tag($product_ref, 'categories', 'en:waters')
		    and (not has_tag($product_ref, 'categories', 'en:flavored-waters'))) {
			$product_ref->{nova_group} = 1;
			return;

		} else {
			$product_ref->{nova_group_tags} = [ "not-applicable" ];
			$product_ref->{nova_group_debug} = "no nova group when the product does not have ingredients";
			return;
		}
	}

	# do not compute a score when it is not food
	if (has_tag($product_ref,"categories","en:non-food-products")) {
			$product_ref->{nova_group_tags} = [ "not-applicable" ];
			$product_ref->{nova_group_debug} = "no nova group for non food products";
			return;
	}


	# determination process:
	# - start by assigning group 1
	# - see if the group needs to be increased based on category, ingredients and additives

	$product_ref->{nova_group} = 1;


	# $options{nova_groups_tags} = {
	#
	# # start by assigning group 1
	#
	# # 1st try to identify group 2 processed culinary ingredients
	#
	# "categories/en:fats" => 2,


	if (defined $options{nova_groups_tags}) {

		foreach my $tag (sort {$options{nova_groups_tags}{$a} <=> $options{nova_groups_tags}{$b}} keys %{$options{nova_groups_tags}}) {

			if ($tag =~ /\//) {

				my $tagtype = $`;
				my $tagid = $';

				if (has_tag($product_ref, $tagtype, $tagid)) {

					if ($options{nova_groups_tags}{$tag} > $product_ref->{nova_group}) {

						# only move group 1 product to group 3, not group 2
						if (not (($product_ref->{nova_group} == 2) and ($options{nova_groups_tags}{$tag} == 3))) {
							$product_ref->{nova_group_debug} .= " -- $tag : " . $options{nova_groups_tags}{$tag} ;
							$product_ref->{nova_group} = $options{nova_groups_tags}{$tag};
						}
					}
				}

			}
		}
	}

	# Also loop through ingredients to see if the ingredients taxonomy has associated minimum NOVA grades

	if ((defined $product_ref->{ingredients_tags}) and (defined $properties{ingredients})) {

		foreach my $ingredient_tag (@{$product_ref->{ingredients_tags}}) {

			if ( (defined $properties{ingredients})
				and (defined $properties{ingredients}{$ingredient_tag})
				and (defined $properties{ingredients}{$ingredient_tag}{"nova:en"})
				and ($properties{ingredients}{$ingredient_tag}{"nova:en"} > $product_ref->{nova_group}) ) {
				$product_ref->{nova_group_debug} .= " -- ingredient: $ingredient_tag : " . $properties{ingredients}{$ingredient_tag}{"nova:en"} ;
				$product_ref->{nova_group} = $properties{ingredients}{$ingredient_tag}{"nova:en"};
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


	# Unless we found a marker for NOVA 4, do not compute a score if there are too many unknown ingredients:

	if ($product_ref->{nova_group} != 4) {

		# do not compute a score if we have too many unknown ingredients
		if ( has_tag($product_ref,"quality","en:ingredients-100-percent-unknown") or
			has_tag($product_ref,"quality","en:ingredients-90-percent-unknown") or
			has_tag($product_ref,"quality","en:ingredients-80-percent-unknown") or
			has_tag($product_ref,"quality","en:ingredients-70-percent-unknown") or
			has_tag($product_ref,"quality","en:ingredients-60-percent-unknown") or
			has_tag($product_ref,"quality","en:ingredients-50-percent-unknown") )  {
				delete $product_ref->{nova_group};
				$product_ref->{nova_group_tags} = [ "not-applicable" ];
				$product_ref->{nova_group_debug} = "no nova group if too many ingredients are unknown";
				return;
		}

		if ($product_ref->{unknown_ingredients_n} > ($product_ref->{ingredients_n} / 2)) {
				delete $product_ref->{nova_group};
				$product_ref->{nova_group_tags} = [ "not-applicable" ];
				$product_ref->{nova_group_debug} = "no nova group if too many ingredients are unknown: "
					. $product_ref->{unknown_ingredients_n} . " out of " . $product_ref->{ingredients_n};
				return;
		}

		# do not compute a score when we don't have a category
		if ((not defined $product_ref->{categories}) or ($product_ref->{categories} eq '')) {
				delete $product_ref->{nova_group};
				$product_ref->{nova_group_tags} = [ "not-applicable" ];
				$product_ref->{nova_group_debug} = "no nova group when the product does not have a category";
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
	$product_ref->{nova_groups_tags} = [ canonicalize_taxonomy_tag("en", "nova_groups", $product_ref->{nova_groups}) ];
}


sub extract_nutrition_from_image($$$$) {

	my $product_ref = shift;
	my $id = shift;
	my $ocr_engine = shift;
	my $results_ref = shift;

	extract_text_from_image($product_ref, $id, "nutrition_text_from_image", $ocr_engine, $results_ref);

	# clean and process text
	if (($results_ref->{status} == 0) and (defined $results_ref->{nutrition_text_from_image})) {

		# TODO: extract the nutrition facts values
	}
}

=head2 assign_category_properties_to_product ( PRODUCT_REF )

Go through the categories of a product to apply category properties at the product level.
The most specific categories are checked first. If the category has
a value for the property, it is assigned to the product and the processing stop.

This function was first designed to assign a CIQUAL category to products, based on
the mapping of the Open Food Facts categories to the French CIQUAL categories.

It may be used for other properties in the future.
=cut

sub assign_category_properties_to_product($) {

	my $product_ref = shift;

	$product_ref->{category_properties} = {};

	foreach my $property ("ciqual_food_code:en:", "ciqual_food_name:en", "ciqual_food_name:fr") {

		# Find the first category with a defined value for the property

		if (defined $product_ref->{categories_tags}) {
			foreach my $categoryid (reverse @{$product_ref->{categories_tags}}) {
				if ((defined $properties{categories}{$categoryid}) and (defined $properties{categories}{$categoryid}{$property})) {
					$product_ref->{category_properties}{$property} = $properties{categories}{$categoryid}{$property};
					last;
				}
			}
		}

		# Create facet tags for some properties

		if ($property =~ /^(ciqual_food_name):en$/) {
			my $tagtype = $1;
			if (defined $product_ref->{category_properties}{$property}) {
				$product_ref->{$tagtype . "_tags"} = [get_string_id_for_lang("no_language", $product_ref->{category_properties}{$property})];
			}
			else {
				$product_ref->{$tagtype . "_tags"} = ["unknown"];
			}
		}

	}
}

1;
