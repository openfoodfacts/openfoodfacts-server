# This file is part of Product Opener.
# 
# Product Opener
# Copyright (C) 2011-2018 Association Open Food Facts
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

package ProductOpener::Food;

use utf8;
use Modern::Perl '2012';
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
	
					&unit_to_g
					&g_to_unit
					
					&unit_to_mmoll
					&mmoll_to_unit
					
					&normalize_quantity

					&canonicalize_nutriment
					
					&fix_salt_equivalent
					&compute_nutrition_score
					&compute_nutrition_grade
					&compute_nova_group
					&compute_serving_size_data
					&compute_unknown_nutrients
					&compute_nutrient_levels
					&compute_units_of_alcohol
					
					&compare_nutriments
					
					%packager_codes
					%geocode_addresses
					&normalize_packager_codes
					&get_canon_local_authority
					
					&special_process_product
					
					);	# symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;

use ProductOpener::Store qw/:all/;
use ProductOpener::Config qw/:all/;
use ProductOpener::Lang qw/:all/;

use ProductOpener::Tags qw/:all/;

use Hash::Util;

use CGI qw/:cgi :form escapeHTML/;

use Log::Any qw($log);

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
	
	$unit eq 'kcal' and return int($value * 4.184 + 0.5);
	$unit eq 'kg' and return $value * 1000;
	$unit eq 'mg' and return $value / 1000;
	$unit eq 'µg' and return $value / 1000000;
	$unit eq 'oz' and return $value * 28.349523125;

	$unit eq 'l' and return $value * 1000;
	$unit eq 'dl' and return $value * 100;
	$unit eq 'cl' and return $value * 10;	
	$unit eq 'fl oz' and return $value * 30;
	return $value + 0; # + 0 to make sure the value is treated as number (needed when outputting json and to store in mongodb as a number)
}


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
	
	$unit eq 'kcal' and return int($value / 4.184 + 0.5);
	$unit eq 'kg' and return $value / 1000;
	$unit eq 'mg' and return $value * 1000;
	$unit eq 'µg' and return $value * 1000000;
	$unit eq 'oz' and return $value / 28.349523125;
	
	$unit eq 'l' and return $value / 1000;
	$unit eq 'dl' and return $value / 100;
	$unit eq 'cl' and return $value / 10;		
	$unit eq 'fl oz' and return $value / 30;
	return $value + 0;
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
);

# http://healthycanadians.gc.ca/eating-nutrition/label-etiquetage/tips-conseils/nutrition-fact-valeur-nutritive-eng.php

%nutriments_tables = (

europe => [qw(
!energy
-energy-from-fat-
!fat
-saturated-fat
--butyric-acid-
--caproic-acid-
--caprylic-acid-
--capric-acid-
--lauric-acid-
--myristic-acid-
--palmitic-acid-
--stearic-acid-
--arachidic-acid-
--behenic-acid-
--lignoceric-acid-
--cerotic-acid-
--montanic-acid-
--melissic-acid-
-monounsaturated-fat-
-polyunsaturated-fat-
-omega-3-fat-
--alpha-linolenic-acid-
--eicosapentaenoic-acid-
--docosahexaenoic-acid-
-omega-6-fat-
--linoleic-acid-
--arachidonic-acid-
--gamma-linolenic-acid-
--dihomo-gamma-linolenic-acid-
-omega-9-fat-
--oleic-acid-
--elaidic-acid-
--gondoic-acid-
--mead-acid-
--erucic-acid-
--nervonic-acid-
-trans-fat-
-cholesterol-
!carbohydrates
-sugars
--sucrose-
--glucose-
--fructose-
--lactose-
--maltose-
--maltodextrins-
-starch-
-polyols-
fiber
!proteins
-casein-
-serum-proteins-
-nucleotides-
salt
sodium
alcohol
#vitamins
vitamin-a-
beta-carotene-
vitamin-d-
vitamin-e-
vitamin-k-
vitamin-c-
vitamin-b1-
vitamin-b2-
vitamin-pp-
vitamin-b6-
vitamin-b9-
folates-
vitamin-b12-
biotin-
pantothenic-acid-
#minerals
silica-
bicarbonate-
potassium-
chloride-
calcium-
phosphorus-
iron-
magnesium-
zinc-
copper-
manganese-
fluoride-
selenium-
chromium-
molybdenum-
iodine-
caffeine-
taurine-
ph-
fruits-vegetables-nuts-
fruits-vegetables-nuts-estimate-
collagen-meat-protein-ratio-
cocoa-
chlorophyl-
carbon-footprint
nutrition-score-fr-
nutrition-score-uk-
glycemic-index-
water-hardness-
choline-
phylloquinone-
beta-glucan-
inositol-
carnitine-
)
],

ca => [qw(
!energy
!fat
-saturated-fat
--butyric-acid-
--caproic-acid-
--caprylic-acid-
--capric-acid-
--lauric-acid-
--myristic-acid-
--palmitic-acid-
--stearic-acid-
--arachidic-acid-
--behenic-acid-
--lignoceric-acid-
--cerotic-acid-
--montanic-acid-
--melissic-acid-
-monounsaturated-fat-
-polyunsaturated-fat-
-omega-3-fat-
--alpha-linolenic-acid-
--eicosapentaenoic-acid-
--docosahexaenoic-acid-
-omega-6-fat-
--linoleic-acid-
--arachidonic-acid-
--gamma-linolenic-acid-
--dihomo-gamma-linolenic-acid-
-omega-9-fat-
--oleic-acid-
--elaidic-acid-
--gondoic-acid-
--mead-acid-
--erucic-acid-
--nervonic-acid-
-trans-fat
cholesterol
!carbohydrates
-fiber
--soluble-fiber-
--insoluble-fiber-
-sugars
--sucrose-
--glucose-
--fructose-
--lactose-
--maltose-
--maltodextrins-
-starch-
-polyols-
!proteins
-casein-
-serum-proteins-
-nucleotides-
salt
sodium
alcohol
#vitamins
vitamin-a
beta-carotene-
vitamin-d-
vitamin-e-
vitamin-k-
vitamin-c
vitamin-b1-
vitamin-b2-
vitamin-pp-
vitamin-b6-
vitamin-b9-
folates-
vitamin-b12-
biotin-
pantothenic-acid-
#minerals
silica-
bicarbonate-
potassium-
chloride-
calcium
phosphorus-
iron
magnesium-
zinc-
copper-
manganese-
fluoride-
selenium-
chromium-
molybdenum-
iodine-
caffeine-
taurine-
ph-
fruits-vegetables-nuts-
fruits-vegetables-nuts-estimate-
collagen-meat-protein-ratio-
cocoa-
chlorophyl-
carbon-footprint
nutrition-score-fr-
nutrition-score-uk-
glycemic-index-
water-hardness-
choline-
phylloquinone-
beta-glucan-
inositol-
carnitine-
)
],

ru => [qw(
!proteins
-casein-
-serum-proteins-
-nucleotides-
!fat
-saturated-fat
--butyric-acid-
--caproic-acid-
--caprylic-acid-
--capric-acid-
--lauric-acid-
--myristic-acid-
--palmitic-acid-
--stearic-acid-
--arachidic-acid-
--behenic-acid-
--lignoceric-acid-
--cerotic-acid-
--montanic-acid-
--melissic-acid-
-monounsaturated-fat-
-polyunsaturated-fat-
-omega-3-fat-
--alpha-linolenic-acid-
--eicosapentaenoic-acid-
--docosahexaenoic-acid-
-omega-6-fat-
--linoleic-acid-
--arachidonic-acid-
--gamma-linolenic-acid-
--dihomo-gamma-linolenic-acid-
-omega-9-fat-
--oleic-acid-
--elaidic-acid-
--gondoic-acid-
--mead-acid-
--erucic-acid-
--nervonic-acid-
-trans-fat-
-cholesterol-
!carbohydrates
-sugars
--sucrose-
--glucose-
--fructose-
--lactose-
--maltose-
--maltodextrins-
-starch-
-polyols-
!energy
-energy-from-fat-
fiber
salt
sodium
alcohol
#vitamins
vitamin-a-
beta-carotene-
vitamin-d-
vitamin-e-
vitamin-k-
vitamin-c-
vitamin-b1-
vitamin-b2-
vitamin-pp-
vitamin-b6-
vitamin-b9-
folates-
vitamin-b12-
biotin-
pantothenic-acid-
#minerals
silica-
bicarbonate-
potassium-
chloride-
calcium-
phosphorus-
iron-
magnesium-
zinc-
copper-
manganese-
fluoride-
selenium-
chromium-
molybdenum-
iodine-
caffeine-
taurine-
ph-
fruits-vegetables-nuts-
fruits-vegetables-nuts-estimate-
collagen-meat-protein-ratio-
cocoa-
chlorophyl-
carbon-footprint
nutrition-score-fr-
nutrition-score-uk-
glycemic-index-
water-hardness-
choline-
phylloquinone-
beta-glucan-
inositol-
carnitine-
)
],


us => [qw(
!energy
-energy-from-fat-
!fat
-saturated-fat
--butyric-acid-
--caproic-acid-
--caprylic-acid-
--capric-acid-
--lauric-acid-
--myristic-acid-
--palmitic-acid-
--stearic-acid-
--arachidic-acid-
--behenic-acid-
--lignoceric-acid-
--cerotic-acid-
--montanic-acid-
--melissic-acid-
-monounsaturated-fat-
-polyunsaturated-fat-
-omega-3-fat-
--alpha-linolenic-acid-
--eicosapentaenoic-acid-
--docosahexaenoic-acid-
-omega-6-fat-
--linoleic-acid-
--arachidonic-acid-
--gamma-linolenic-acid-
--dihomo-gamma-linolenic-acid-
-omega-9-fat-
--oleic-acid-
--elaidic-acid-
--gondoic-acid-
--mead-acid-
--erucic-acid-
--nervonic-acid-
-trans-fat
cholesterol
salt-
sodium
!carbohydrates
-fiber
--soluble-fiber-
--insoluble-fiber-
-sugars
--sucrose-
--glucose-
--fructose-
--lactose-
--maltose-
--maltodextrins-
-starch-
-polyols-
!proteins
-casein-
-serum-proteins-
-nucleotides-
alcohol
#vitamins
vitamin-a-
beta-carotene-
vitamin-d
vitamin-e-
vitamin-k-
vitamin-c-
vitamin-b1-
vitamin-b2-
vitamin-pp-
vitamin-b6-
vitamin-b9-
folates-
vitamin-b12-
biotin-
pantothenic-acid-
#minerals
silica-
bicarbonate-
potassium
chloride-
calcium
phosphorus-
iron
magnesium-
zinc-
copper-
manganese-
fluoride-
selenium-
chromium-
molybdenum-
iodine-
caffeine-
taurine-
ph-
fruits-vegetables-nuts-
fruits-vegetables-nuts-estimate-
collagen-meat-protein-ratio-
cocoa-
chlorophyl-
carbon-footprint
nutrition-score-fr-
nutrition-score-uk-
glycemic-index-
water-hardness-
)
],

us_before_2017 => [qw(
!energy
-energy-from-fat
!fat
-saturated-fat
--butyric-acid-
--caproic-acid-
--caprylic-acid-
--capric-acid-
--lauric-acid-
--myristic-acid-
--palmitic-acid-
--stearic-acid-
--arachidic-acid-
--behenic-acid-
--lignoceric-acid-
--cerotic-acid-
--montanic-acid-
--melissic-acid-
-monounsaturated-fat-
-polyunsaturated-fat-
-omega-3-fat-
--alpha-linolenic-acid-
--eicosapentaenoic-acid-
--docosahexaenoic-acid-
-omega-6-fat-
--linoleic-acid-
--arachidonic-acid-
--gamma-linolenic-acid-
--dihomo-gamma-linolenic-acid-
-omega-9-fat-
--oleic-acid-
--elaidic-acid-
--gondoic-acid-
--mead-acid-
--erucic-acid-
--nervonic-acid-
-trans-fat
cholesterol
salt-
sodium
!carbohydrates
-fiber
--soluble-fiber-
--insoluble-fiber-
-sugars
--sucrose-
--glucose-
--fructose-
--lactose-
--maltose-
--maltodextrins-
-starch-
-polyols-
!proteins
-casein-
-serum-proteins-
-nucleotides-
alcohol
#vitamins
vitamin-a
beta-carotene-
vitamin-d-
vitamin-e-
vitamin-k-
vitamin-c
vitamin-b1-
vitamin-b2-
vitamin-pp-
vitamin-b6-
vitamin-b9-
folates-
vitamin-b12-
biotin-
pantothenic-acid-
#minerals
silica-
bicarbonate-
potassium-
chloride-
calcium
phosphorus-
iron
magnesium-
zinc-
copper-
manganese-
fluoride-
selenium-
chromium-
molybdenum-
iodine-
caffeine-
taurine-
ph-
fruits-vegetables-nuts-
fruits-vegetables-nuts-estimate-
collagen-meat-protein-ratio-
cocoa-
chlorophyl-
carbon-footprint
nutrition-score-fr-
nutrition-score-uk-
glycemic-index-
water-hardness-
choline-
phylloquinone-
beta-glucan-
inositol-
carnitine-
)
],

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
	zh-CN => "酒精度",
	zh-HK => "酒精",
	zh-TW => "酒精",
	unit => '% vol',
},
energy => {
	ar => "الطاقه",
	bg => "Енергийна стойност",
	cs => "Energetická hodnota",
	da => "Energi",
	de => "Brennwert",
	el => "Ενέργεια",
	en => "Energy",
	es => "Energía",
	et => "Energia",
	fa => "انرژی",
	fi => "Energiav",
	fr => "Énergie",
	ga => "Fuinneamh",
	he => "אנרגיה - קלוריות",
	hu => "Energia",
	it => "Energia",
	ja => "エネルギー",
	lt => "Energinė vertė",
	lv => "Enerģētiskā vērtība",
	mt => "Enerġija",
	nl => "Energie",
	nl_be => "Energie",
	nb => "Energi",
	pl => "Wartość energetyczna",
	pt => "Energia",
	ro => "Valoarea energetică",
	rs => "Energetska vrednost",
	ru => "Энергетическая ценность",
	sk => "Energetická hodnota",
	sl => "Energijska vrednost",
	sv => "Energi",
	tr => "Enerji",
	zh => "能量",
	zh-CN => "能量",
	zh-HK => "能量",
	zh-TW => "能量",
	unit => 'kj',
	unit_ca => 'kcal',
	unit_us => 'kcal',
},
"energy-from-fat" => {
	cs => "Energie z tuku",
	de => "Brennwert aus Fetten",
	en => "Energy from fat",
	fr => "Énergie provenant des graisses",
	hu => "Energia zsírból",
	ja => "脂質からのエネルギー",
	pt => "Energia des gorduras",
	ru => "Энергетическая ценность жиров",
	zh => "来自脂肪的能量",
	zh-CN => "来自脂肪的能量",
	zh-HK => "來自脂肪的能量",
	zh-TW => "來自脂肪的能量",
	unit => 'kj',
	unit_us => 'kcal',
	unit_ca => 'kcal',
},
proteins => {
	ar => "البروتين",
	bg => "Белтъци",
	cs => "Bílkoviny",
	da => "Protein",
	de => "Eiweiß",
	el => "Πρωτεΐνες",
	en => "Proteins",
	es => "Proteínas",
	et => "Valgud",
	fa => "ﭘﺮﻭﺗﺌ‍ین",
	fi => "Proteiini",
	fr => "Protéines", "Protéine brute"
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
	zh-CN => "蛋白质",
	zh-HK => "蛋白質",
	zh-TW => "蛋白質",
},
casein => {
	ar => 'كازين',
	be => 'Казеін',
	bg => 'Казеин',
	ca => 'Caseïna',
	cs => 'Kasein',
	cy => 'Casein',
	da => 'Kasein',
	de => 'Casein',
	en => 'casein',
	eo => 'Kazeino',
	es => 'Caseína',
	eu => 'Kaseina',
	fa => 'کازئین',
	fi => 'Kaseiini',
	fr => 'Caséine',
	ga => 'Cáiséin',
	gl => 'Caseína',
	gsw => 'Casein',
	he => 'קזאין',
	hu => 'Kazein',
	hy => 'Կազեին',
	id => 'Kasein',
	io => 'Kazeino',
	it => 'Caseina',
	ja => 'カゼイン',
	kk => 'Казеин',
	kk_arab => 'كازەىين',
	kk_cn => 'كازەىين',
	kk_cyrl => 'Казеин',
	kk_kz => 'Казеин',
	kk_latn => 'Kazeïn',
	kk_tr => 'Kazeïn',
	ko => '카세인',
	nb => 'Kasein',
	nl => 'Caseïne',
	nl_be => 'Caseïne',
	nn => 'Kasein',
	pl => 'Kazeina',
	pt => 'Caseína',
	ro => 'Cazeină',
	ru => 'Казеин',
	scn => 'Caseina',
	sco => 'casein',
	sh => 'Kazein',
	sl => 'Kazein',
	sr => 'казеин',
	sr_ec => 'Казеин',
	sr_el => 'Kazein',
	sv => 'Kasein',
	tr => 'Kazein',
	uk => 'Казеїн',
	zh => "酪蛋白",
	zh => '酪蛋白',
	zh-CN => "酪蛋白",
	zh-HK => "酪蛋白",
	zh-TW => "酪蛋白",
},
nucleotides => {
        de => 'Nukleotide',
	fa => "نوکلئوتید",
	fr => 'Nucléotides',
	en => 'Nucleotides',
	hu => 'Nukleotidok',
	it => 'Nucleotidi',
	ru => 'Нуклеотиды',
	nl => 'Nucleotiden',
	nl_be => 'Nucleotiden',
	el => "Νουκλεοτίδια",
	ja => "ヌクレオチド",
        pt => "nucleotídeos",
	zh => "核苷酸",
	zh-TW => "核苷酸",
	zh-HK => "核苷酸",
	zh-CN => "核苷酸",
},
"serum-proteins" => {
        de => 'Serumprotein',
	el => "Πρωτεΐνες ορού",
	en => "Serum proteins",
	ru => "Сывороточные белки",
	fr => "Protéines sériques",
	it => "Sieroproteine",
	ja => "血清たんぱく質",
	nl => 'Plasmaproteïnen',
	nl_be => 'Plasmaproteïnen',
        pt => 'proteína plasmatica',
	zh => "血清蛋白",
	zh-CN => "血清蛋白",
	zh-HK => "血清蛋白",
	zh-TW => "血清蛋白",
},
carbohydrates => {
	ar => "الكاربوهايدريد",
	bg => "Въглехидрати",
	cs => "Sacharidy",
	da => "Kulhydrat",
	de => "Kohlenhydrate",
	el => "Υδατάνθρακες",
	en => "Carbohydrate",
	es => "Hidratos de carbono",
	et => "Süsivesikud",
	fa => "کربوهیدرات ها",
	fi => "Hiilihydraatti",
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
	ro => "gGlucide",
	rs => "Ugljeni hidrati",
	ru => "Углеводы",
	sk => "Sacharidy",
	sl => "Ogljikove hidrate",
	sv => "Kolhydrat",
	tr => "Karbonhidratlar",
	zh => "碳水化合物",
	zh-CN => "碳水化合物",
	zh-HK => "碳水化合物",
	zh-TW => "碳水化合物",
},
sugars => {
	ar => "السكر",
	bg => "Захари",
	cs => "Cukry",
	da => "Sukkerarter",
	de => "Zucker",
	el => "Σάκχαρα",
	en => "Sugars",
	es => "Azúcares",
	et => "Suhkrud",
	fa => "شکر",
	fi => "Sokerit",
	fr => "Sucres",
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
	rs => "Šećeri"
	ru => "Сахара",
	sk => "Cukry",
	sl => "Sladkorjev",
	sv => "Sockerarter",
	tr => "Şeker",
	zh => "糖",
	zh-CN => "糖",
	zh-HK => "糖",
	zh-TW => "糖",
},
sucrose => {
	cs => 'Sacharóza',
	de => 'Saccharose',
	el => "Σουκρόζη",
	en => 'Sucrose',
	es => 'Sacarosa',
	fa => "ساکارز",
	fr => 'Saccharose',
	he => 'סוכרוז',
	hu => 'Szacharóz',
	it => 'Saccarosio',
	ja => "スクロース",
	nl => 'Sucrose',
	nl_be => 'Sucrose',
	pt => 'Sacarose',
	rs => "Saharoza",
	ru => "Сахароза",
	zh => "蔗糖",
	zh-CN => "蔗糖",
	zh-HK => "蔗糖",
	zh-TW => "蔗糖",
},
glucose => {
	cs => 'Glukóza',
	de => 'Traubenzucker',
	el => "Γλυκόζη",
	en => 'Glucose',
	es => 'Glucosa',
	fr => 'Glucose',
	he => 'גלוקוז',
	hu => 'Glükóz',
	it => 'Glucosio',
	ja => "グルコース",
	nl => 'Glucose',
	nl_be => 'Glucose',
	pt => 'Glucose',
	ru => "Глюкоза (декстроза)",
	zh => "葡萄糖",
	zh-CN => "葡萄糖",
	zh-HK => "葡萄糖",
	zh-TW => "葡萄糖",
},
fructose => {
	de => 'Fruchtzucker',
	el => "Φρουκτόζη",
	en => 'Fructose',
	es => 'Fructosa',
	fr => 'Fructose',
	he => 'פרוקטוז',
	hu => 'Fruktóz',
	it => 'Fruttosio',
	ja => "果糖",
	nl => 'Fructose',
	nl_be => 'Fructose',
	pt => 'Frutose',
	rs => "Fruktoza"
	ru => "Фруктоза",
	zh => "果糖",
	zh-CN => "果糖",
	zh-HK => "果糖",
	zh-TW => "果糖",
},
lactose => {
	cs => 'Laktóza',
	de => 'Laktose',
	el => "Λακτόζη",
	en => 'Lactose',
	es => 'Lactosa',
	fr => 'Lactose',
	he => 'לקטוז',
	hu => 'Laktóz',
	it => 'Lattosio',
	ja => "乳糖",
	nl => 'Lactose',
	nl_be => 'Lactose',
	pt => 'Lactose',
	rs => "Laktoza",
	ru => "Лактоза",
	zh => "乳糖",
	zh-CN => "乳糖",
	zh-HK => "乳糖",
	zh-TW => "乳糖",
},
maltose => {
	de => 'Malzzucker',
	el => "Μαλτόζη",
	en => 'Maltose',
	es => 'Maltosa',
	fr => 'Maltose',
	he => 'מלטוז',
	hu => 'Maltóz',
	it => 'Maltosio',
	ja => "麦芽糖",
	nl => 'Maltose',
	nl_be => 'Maltose',
	pt => 'Maltose',
	ru => "Мальтоза",
	zh => "麦芽糖",
	zh-CN => "麦芽糖",
	zh-HK => "麥芽糖",
	zh-TW => "麥芽糖",
},
maltodextrins => {
        de => 'Maltodextrine',
	el => "Μαλτοδεξτρίνες",
	en => 'Maltodextrins',
	es => 'Maltodextrinas',
	fr => 'Maltodextrines',
	he => 'מלטודקסטרינים',
	hu => 'Maltodextrin',
	it => 'Maltodestrine',
	ja => "マルトデキストリン",
	nl => 'Maltodextrine',
	nl_be => 'Maltodextrine',
	pt => 'Maltodextrinas',
	ru => "Мальтодекстрин",
	zh => "麦芽糊精",
	zh-CN => "麦芽糊精",
	zh-HK => "麥芽糊精",
	zh-TW => "麥芽糊精",
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
	zh-CN => "淀粉",
	zh-HK => "澱粉",
	zh-TW => "澱粉",
},
polyols => {
	bg => "Полиоли",
	cs => "Polyalkoholy",
	da => "Polyoler",
	de => "mehrwertige Alkohole (Polyole)",
	el => "Πολυόλες",
	en => "Sugar alcohols (Polyols)",
	es => "Azúcares alcohólicos (Polialcoholes)",
	et => "Polüoolid",
	fi => "Polyolit",
	fr => "Polyols",
	ga => "Polóil",
	he => "סוכר אלכוהולי (פוליאול)",
	hu => "Poliolok",
	it => "Polialcoli/polioli (alcoli degli zuccheri)",
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
	zh-CN => "糖醇（多元醇）",
	zh-HK => "多元醇",
	zh-TW => "多元醇",
},
fat => {
	ar=> "الدهون",
	bg => "Мазнини",
	cs => "Tuky",
	da => "Fedt",
	de => "Fett",
	el => "Λιπαρά",
	en => "Fat",
	es => "Grasas",
	et => "Rasvad",
	fi => "Rasva",
	fr => "Matières grasses / Lipides",
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
	zh-CN => "脂肪",
	zh-HK => "脂肪",
	zh-TW => "脂肪",
},
'saturated-fat' => {
	bg => "Наситени мастни киселини",
	cs => "Nasycené mastné kyseliny",
	da => "Mættede fedtsyrer",
	de => "gesättigte Fettsäuren",
	el => "Κορεσμένα λιπαρά",
	en => "Saturated fat",
	es => "Grasas saturadas",
	es => "Ácidos grasos saturados",
	et => "Küllastunud rasvhapped",
	fi => "Tyydyttyneet rasvat",
	fr => "Acides gras saturés",
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
	zh-CN => "饱和脂肪",
	zh-HK => "飽和脂肪",
	zh-TW => "飽和脂肪",
},
'butyric-acid' => {
        de => 'Buttersäure (4:0)',
	el => "Βουτυρικό οξύ (4:0)",
	en => 'Butyric acid (4:0)',
	es => 'Ácido butírico (4:0)',
	fr => 'Acide butyrique (4:0)',
	he => 'חומצה בוטירית (4:0)',
	ja => '酪酸 (4:0)',
	nl => 'Boterzuur (4:0)',
	nl_be => 'Boterzuur (4:0)',
	pt => 'Ácido butírico (4:0)',
	ru => "Масляная кислота (4:0)",
	zh => "丁酸 (4:0)",
	zh-CN => "丁酸 (4:0)",
	zh-HK => "丁酸 (4:0)",
	zh-TW => "丁酸 (4:0)",
},
'caproic-acid' => {
        de => 'Capronsäure (6:0)',
	el => "Καπροϊκό οκύ (6:0)",
	en => 'Caproic acid (6:0)',
	es => 'Ácido caproico (6:0)',
	fr => 'Acide caproïque (6:0)',
	he => 'חומצה קפרואית (6:0)',
	ja => 'カプロン酸 (6:0)',
	nl => 'Capronzuur (6:0)',
	nl_be => 'Capronzuur (6:0)',
	pt => 'Ácido capróico (6:0)',
	ru => "Капроновая кислота (6:0)",
	zh => "己酸 (6:0)",
	zh-CN => "己酸 (6:0)",
	zh-HK => "己酸 (6:0)",
	zh-TW => "己酸 (6:0)",
},
'caprylic-acid' => {
        de => 'Caprylsäure (8:0)',
	el => 'Καπρυλικό οξύ (8:0)',
	en => 'Caprylic acid (8:0)',
	es => 'Ácido caprílico (8:0)',
	fr => 'Acide caproïque (8:0)',
	he => 'חומצה קפרילית (8:0)',
	ja => 'カプリル酸 (8:0)',
	nl => 'Octaanzuur (8:0)',
	nl_be => 'Octaanzuur (8:0)',
	pt => 'Ácido caprílico (8:0)',
	ru => "Каприловая кислота (8:0)",
	zh => "辛酸 (8:0)",
	zh-CN => "辛酸 (8:0)",
	zh-HK => "辛酸 (8:0)",
	zh-TW => "辛酸 (8:0)",
},
'capric-acid' => {
        de => 'Caprinsäure (10:0)',
	el => 'Καπρικό οξύ (10:0)',
	en => 'Capric acid (10:0)',
	es => 'Ácido cáprico (10:0)',
	fr => 'Acide caprique (10:0)',
	he => 'חומצה קפרית (10:0)',
	ja => 'カプリン酸 (10:0)',
	nl => 'Decaanzuur (10:0)',
	nl_be => 'Decaanzuur (10:0)',
	pt => 'Ácido cáprico (10:0)',
	ru => "Каприновая кислота (10:0)",
	zh => "癸酸 (10:0)",
	zh-CN => "癸酸 (10:0)",
	zh-HK => "癸酸 (10:0)",
	zh-TW => "癸酸 (10:0)",
},
'lauric-acid' => {
        de => 'Laurinsäure',
	el => "Λαυρικό οξύ/n-δωδεκανοϊκό οξύ (12:0)",
	en => 'Lauric acid (12:0)',
	es => 'Ácido láurico (12:0)',
	fr => 'Acide laurique (12:0)',
	he => 'חומצה לאורית (12:0)',
	nl => 'Laurinezuur (12:0)',
	nl_be => 'Laurinezuur (12:0)',
	pt => 'Ácido láurico (12:0)',
	ru => "Лауриновая кислота (12:0)",
	zh => "十二酸 (12:0)",
	zh-CN => "十二酸 (12:0)",
	zh-HK => "十二酸 (12:0)",
	zh-TW => "十二酸 (12:0)",
},
'myristic-acid' => {
        de => 'Myristinsäure (14:0)',
	el => "Μυριστικό οξύ (14:0)",
	en => 'Myristic acid (14:0)',
	es => 'Ácido mirístico (14:0)',
	fr => 'Acide myristique (14:0)',
	he => 'חומצה מיריסטית (14:0)',
	nl => 'Myristinezuur (14:0)',
	pt => 'Ácido mirístico (14:0)',
	ru => "Миристиновая кислота (14:0)",
	zh => "十四酸 (14:0)",
	zh-CN => "十四酸 (14:0)",
	zh-HK => "十四酸 (14:0)",
	zh-TW => "十四酸 (14:0)",
},
'palmitic-acid' => {
        de => 'Palitinsäure (16:0)',
	el => "Παλμιτικό οξύ (16:0)",
	en => 'Palmitic acid (16:0)',
	es => 'Ácido palmítico (16:0)',
	fr => 'Acide palmitique (16:0)',
	he => 'חומצה פלמיטית (16:0)',
	nl => 'Palmitinezuur (16:0)',
	nb => 'Palmitinsyre (16:0)',
	pt => 'Ácido palmítico (16:0)',
	ru => "Пальмитиновая кислота (16:0)",
	zh => "十六酸 (16:0)",
	zh-CN => "十六酸 (16:0)",
	zh-HK => "十六酸 (16:0)",
	zh-TW => "十六酸 (16:0)",
},
'stearic-acid' => {
        de => 'Stearinsäure (18:0)',
	el => "Στεατικό/Στεαρικό οξύ (18:0)",
	en => 'Stearic acid (18:0)',
	es => 'Ácido esteárico (18:0)',
	fr => 'Acide stéarique (18:0)',
	he => 'חומצה סטארית (18:0)',
	nl => 'Stearinezuur (18:0)',
	nl_be => 'Stearinezuur (18:0)',
	pt => 'Ácido esteárico (18:0)',
	ru => "Стеариновая кислота (18:0)",
	zh => "十八酸 (18:0)",
	zh-CN => "十八酸 (18:0)",
	zh-HK => "十八酸 (18:0)",
	zh-TW => "十八酸 (18:0)",
},
'arachidic-acid' => {
        de => 'Arachinsäure (20:0)',
	el => 'Αραχιδικό οξύ (20:0)',
	en => 'Arachidic acid (20:0)',
	es => 'Ácido araquídico (20:0)',
	fr => 'Acide arachidique / acide eicosanoïque (20:0)',
	nl => 'Arachidinezuur (20:0)',
	nl_be => 'Arachidinezuur (20:0)',
	pt => 'Ácido araquídico (20:0)',
	ru => "Арахиновая кислота (20:0)",
	zh => "二十酸 (20:0)",
	zh-CN => "二十酸 (20:0)",
	zh-HK => "二十酸 (20:0)",
	zh-TW => "二十酸 (20:0)",
},
'behenic-acid' => {
        de => 'Behensäure (22:0)',
	el => 'Βεχενικό οξύ/εικοσαδυενοϊκό οξύ (22:0)',
	en => 'Behenic acid (22:0)',
	es => 'Ácido behénico (22:0)',
	fr => 'Acide béhénique (22:0)',
	he => 'חומצה בהנית (22:0)',
	nl => 'Beheenzuur (22:0)',
	nl_be => 'Beheenzuur (22:0)',
	pt => 'Ácido beénico (22:0)',
	ru => "Бегеновая кислота (22:0)",
	zh => "二十二酸 (22:0)",
	zh-CN => "二十二酸 (22:0)",
	zh-HK => "二十二酸 (22:0)",
	zh-TW => "二十二酸 (22:0)",
},
'lignoceric-acid' => {
        de => 'Lignocerinsäure (24:0)',
	el => 'Λιγνοκηρικό οξύ (24:0)',
	en => 'Lignoceric acid (24:0)',
	es => 'Ácido lignocérico (24:0)',
	fr => 'Acide lignocérique (24:0)',
	nl => 'Lignocerinezuur (24:0)',
	nl_be => 'Lignocerinezuur (24:0)',
	pt => 'Ácido lignocérico (24:0)',
	ru => "Лигноцериновая кислота (24:0)",
	zh => "二十四酸 (24:0)",
	zh-CN => "二十四酸 (24:0)",
	zh-HK => "二十四酸 (24:0)",
	zh-TW => "二十四酸 (24:0)",
},
'cerotic-acid' => {
        de => 'Cerotinsäure (26:0)',
	el => 'Κηροτικό οξύ (26:0)',
	en => 'Cerotic acid (26:0)',
	es => 'Ácido cerótico (26:0)',
	fr => 'Acide cérotique (26:0)',
	nl => 'Cerotinezuur (26:0)',
	nl_be => 'Cerotinezuur (26:0)',
	pt => 'Ácido cerótico (26:0)',
	ru => "Церотиновая кислота (26:0)",
	zh => "二十六酸 (26:0)",
	zh-CN => "二十六酸 (26:0)",
	zh-HK => "二十六酸 (26:0)",
	zh-TW => "二十六酸 (26:0)",
},
'montanic-acid' => {
        de => 'Montansäure (28:0)',
	el => 'Μοντανικό οξύ (28:0)',
	en => 'Montanic acid (28:0)',
	es => 'Ácido montánico (28:0)',
	fr => 'Acide montanique (28:0)',
	nl => 'Montaanzuur (28:0)',
	nl_be => 'Montaanzuur (28:0)',
	pt => 'Ácido montânico (28:0)',
	ru => "Монтановая кислота (28:0)",
	zh => "二十八酸 (28:0)",
	zh-CN => "二十八酸 (28:0)",
	zh-HK => "二十八酸 (28:0)",
	zh-TW => "二十八酸 (28:0)",
},
'melissic-acid' => {
        de => 'Melissinsäure (30:0)',
	el => 'Μελισσικό οξύ (30:0)',
	en => 'Melissic acid (30:0)',
	es => 'Ácido melísico (30:0)',
	fr => 'Acide mélissique (30:0)',
	nl => 'Melissinezuur (30:0)',
	nl_be => 'Melissinezuur (30:0)',
	pt => 'Ácido melíssico (30:0)',
	ru => "Мелиссовая кислота (30:0)",
	zh => "三十酸 (30:0)",
	zh-CN => "三十酸 (30:0)",
	zh-HK => "三十酸 (30:0)",
	zh-TW => "三十酸 (30:0)",
},
'monounsaturated-fat' => {
	bg => "Мононенаситени мастни киселини",
	cs => "Mononenasycené mastné kyseliny",
	da => "Enkeltumættede fedtsyrer",
	de => "einfach ungesättigte Fettsäuren",
	el => "Μονοακόρεστα λιπαρά",
	en => "Monounsaturated fat",
	es => "Grasas monoinsaturadas",
	et => "Monoküllastumata rasvhapped",
	fi => "Kertatyydyttymättömät rasvat",
	fr => "Acides gras monoinsaturés",
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
	zh-CN => "单不饱和脂肪",
	zh-HK => "單元不飽和脂肪",
	zh-TW => "單元不飽和脂肪",
},
'omega-9-fat' => {
	de => "Omega-9-Fettsäuren",
	el => 'Ωμέγα-9 λιπαρά',
	en => "Omega 9 fatty acids",
	es => "Ácidos grasos Omega 9",
	fr => "Acides gras Oméga 9",
	he => "אומגה 9",
	hu => "Omega-9 zsírsavak",
	it=> "Acidi grassi Omega 9",
	nl => "Omega 9 vetzuren",
	nl_be => "Omega 9 vetzuren",
	pt => "Ácidos Graxos Ômega 9",
	pt_pt => "Ácidos gordos Ómega 9",
	ru => "Омега-9 жирные кислоты",
	zh => "Omega-9 脂肪酸",
	zh-CN => "Omega-9 脂肪酸",
	zh-HK => "Omega-9 脂肪酸",
	zh-TW => "Omega-9 脂肪酸",
},
'oleic-acid' => {
        de => 'Ölsäure (18:1 n-9)',
	el => 'Ολεϊκό οξύ (18:1 n-9)',
	en => 'Oleic acid (18:1 n-9)',
	es => 'Ácido oleico (18:1 n-9)',
	fr => 'Acide oléique (18:1 n-9)',
	he => 'חומצה אולאית',
	nl => 'Oliezuur (18:1 n-9)',
	nl_be => 'Oliezuur (18:1 n-9)',
	pt => 'Ácido oleico (18:1 n-9)',
	ru => "Олеиновая кислота (18:1 n-9)",
	zh => "油酸 (18:1 n-9)",
	zh-CN => "油酸 (18:1 n-9)",
	zh-HK => "油酸 (18:1 n-9)",
	zh-TW => "油酸 (18:1 n-9)",
},
'elaidic-acid' => {
        de => 'Elaidinsäure (18:1 n-9)',
	el => 'Ελαϊδικό οξύ (18:1 n-9)',
	en => 'Elaidic acid (18:1 n-9)',
	es => 'Ácido elaídico (18:1 n-9)',
	fr => 'Acide élaïdique (18:1 n-9)',
	nl => 'Elaïdinezuur (18:1 n-9)',
	nl_be => 'Elaïdinezuur (18:1 n-9)',
	pt => 'Ácido elaídico (18:1 n-9)',
	ru => "Элаидиновая кислота (18:1 n-9)",
	zh => "反油酸 (18:1 n-9)",
	zh-CN => "反油酸 (18:1 n-9)",
	zh-HK => "反油酸 (18:1 n-9)",
	zh-TW => "反油酸 (18:1 n-9)",
},
'gondoic-acid' => {
        de => 'Gondosäure (20:1 n-9)',
	el => 'Γονδοϊκό οξύ (20:1 n-9)',
	en => 'Gondoic acid (20:1 n-9)',
	es => 'Ácido gondoico (20:1 n-9)',
	fr => 'Acide gadoléique (20:1 n-9)',
	nl => 'Eicoseenzuur (20:1 n-9)',
	nl_be => 'Eicoseenzuur (20:1 n-9)',
	pt => 'Ácido gondoico (20:1 n-9)',
	ru => "Гондоиновая кислота (20:1 n-9)",
	zh => "11-二十碳烯酸 (20:1 n-9)",
	zh-CN => "11-二十碳烯酸 (20:1 n-9)",
	zh-HK => "11-二十碳烯酸 (20:1 n-9)",
	zh-TW => "11-二十碳烯酸 (20:1 n-9)",
},
'mead-acid' => {
        de => 'Mead'sche Säure (20:3 n-9)',
	el => 'Οξύ Mead (20:3 n-9)',
	en => 'Mead acid (20:3 n-9)',
	es => 'Ácido Mead (20:3 n-9)',
	fr => 'Acide de Mead (20:3 n-9)',
	nl => 'Meadzuur (20:3 n-9)',
	nl_be => 'Meadzuur (20:3 n-9)',
	pt => 'Ácido de Mead (20:3 n-9)',
	ru => "Мидовая кислота (20:3 n-9)",
	zh => "二十碳三烯酸 (20:3 n-9)",
	zh-CN => "二十碳三烯酸 (20:3 n-9)",
	zh-HK => "二十碳三烯酸 (20:3 n-9)",
	zh-TW => "二十碳三烯酸 (20:3 n-9)",
},
'erucic-acid' => {
        de => 'Erucasäure (18:1 n-9)',
	el => 'Ερουκικό οξύ (22:1 n-9)',
	en => 'Erucic acid (22:1 n-9)',
	es => 'Ácido erúcico (22:1 n-9)',
	fr => 'Acide érucique (22:1 n-9)',
	nl => 'Erucazuur (22:1 n-9)',
	nl_be => 'Erucazuur (22:1 n-9)',
	pt => 'Ácido erúcico (22:1 n-9)',
	ru => "Эруковая кислота (22:1 n-9)",
	zh => "芥酸 (22:1 n-9)",
	zh-CN => "芥酸 (22:1 n-9)",
	zh-HK => "芥酸 (22:1 n-9)",
	zh-TW => "芥酸 (22:1 n-9)",
},
'nervonic-acid' => {
        de => 'Nervonsäure (24:1 n-9)',
	el => 'Νερβονικό (24:1 n-9)',
	en => 'Nervonic acid (24:1 n-9)',
	es => 'Ácido nervónico (24:1 n-9)',
	fr => 'Acide nervonique (24:1 n-9)',
	nl => 'Nervonzuur (24:1 n-9)',
	nl_be => 'Nervonzuur (24:1 n-9)',
	pt => 'Ácido nervônico (24:1 n-9)',
	pt_pt => 'Ácido nervónico (24:1 n-9)',
	ru => "Нервоновая кислота (24:1 n-9)",
	zh => "二十四碳烯酸 (24:1 n-9)",
	zh-CN => "二十四碳烯酸 (24:1 n-9)",
	zh-HK => "二十四碳烯酸 (24:1 n-9)",
	zh-TW => "二十四碳烯酸 (24:1 n-9)",
},
'polyunsaturated-fat' => {
	bg => "Полиненаситени мастни киселини",
	cs => "Polynenasycené mastné kyseliny",
	da => "Flerumættede fedtsyrer",
	de => "mehrfach ungesättigte Fettsäuren",
	el => "Πολυακόρεστα λιπαρά",
	en => "Polyunsaturated fat",
	es => "Grasas poliinsaturadas",
	et => "Polüküllastumata rasvhapped",
	fi => "Monityydyttymättömät rasvat",
	fr => "Acides gras polyinsaturés",
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
	zh-CN => "多元不饱和酸",
	zh-HK => "多元不飽和酸",
	zh-TW => "多元不飽和酸",
},
'omega-3-fat' => {
	cs => "Omega 3 mastné kyseliny",
	de => "Omega-3-Fettsäuren",
	el => 'Ωμέγα-3 λιπαρά',
	en => "Omega 3 fatty acids",
	es => "Ácidos grasos Omega 3",
	fr => "Acides gras Oméga 3",
	he => "אומגה 3",
	hu => "Omega-3 zsírsavak",
	it=> "Acidi grassi Omega 3",
	nl => "Omega 3-vetzuren",
	nl_be => "Omega 3-vetzuren",
	pt => "Ácidos graxos Ômega 3",
	pt_pt => "Ácidos gordos Ómega 3",
	ru => "Омега-3 жирные кислоты",
	zh => "Omega 3 脂肪酸",
	zh-CN => "Omega 3 脂肪酸",
	zh-HK => "Omega 3 脂肪酸",
	zh-TW => "Omega 3 脂肪酸",
},
'alpha-linolenic-acid' => {
        de => 'A-Linolensäure (18:3 n-3)',
	el => 'Α-λινολενικό οξύ/ ALA (18:3 n-3)',
	en => 'Alpha-linolenic acid / ALA (18:3 n-3)',
	es => 'Ácido alfa-linolénico / ALA (18:3 n-3)',
	fr => 'Acide alpha-linolénique / ALA (18:3 n-3)',
	nl => 'Alfa-linoleenzuur / ALA (18:3 n-3)',
	nl_be => 'Alfa-linoleenzuur / ALA (18:3 n-3)',
	pt => 'Ácido alfa-linolênico / ALA (18:3 n-3)',
	pt_pt => 'Ácido alfa-linolénico / ALA (18:3 n-3)',
	ru => "Альфа-линоленовая кислота / (АЛК) (18:3 n-3)",
	zh => "α-亚麻酸 / ALA (18:3 n-3)",
	zh-CN => "α-亚麻酸 / ALA (18:3 n-3)",
	zh-HK => "α-亞麻酸 / ALA (18:3 n-3)",
	zh-TW => "α-亞麻酸 / ALA (18:3 n-3)",
},
'eicosapentaenoic-acid' => {
        de => 'Eicosapentaensäure (20:5 n-3)',
	el => 'Εικοσιπεντανοϊκο οξύ / EPA (20:5 n-3)',
	en => 'Eicosapentaenoic acid / EPA (20:5 n-3)',
	es => 'Ácido eicosapentaenoico / EPA (20:5 n-3)',
	fr => 'Acide eicosapentaénoïque / EPA (20:5 n-3)',
	nl => 'Eicosapentaeenzuur / EPA (20:5 n-3)',
	nl_be => 'Eicosapentaeenzuur / EPA (20:5 n-3)',
	pt => 'Ácido eicosapentaenóico / EPA (20:5 n-3)',
	ru => "Эйкозапентаеновая кислота / (ЭПК) (20:5 n-3)",
	zh => "二十碳五酸 / EPA (20:5 n-3)",
	zh-CN => "二十碳五酸 / EPA (20:5 n-3)",
	zh-HK => "二十碳五酸 / EPA (20:5 n-3)",
	zh-TW => "二十碳五酸 / EPA (20:5 n-3)",
},
'docosahexaenoic-acid' => {
        de => 'Docosahexaensäure (22:6 n-3)',
	el => 'Δοκοσαεξανοϊκο οξύ / DHA (22:6 n-3)',
	en => 'Docosahexaenoic acid / DHA (22:6 n-3)',
	es => 'Ácido docosahexaenoico / DHA (22:6 n-3)',
	fr => 'Acide docosahexaénoïque / DHA (22:6 n-3)',
	nl => 'Docosahexaeenzuur / DHA (22:6 n-3)',
	nl_be => 'Docosahexaeenzuur / DHA (22:6 n-3)',
	pt => 'Ácido docosa-hexaenóico / DHA (22:6 n-3)',
	ru => "Докозагексаеновая кислота / (ДГК) (22:6 n-3)",
	zh => "二十二碳六酸 / DHA (22:6 n-3)",
	zh-CN => "二十二碳六酸 / DHA (22:6 n-3)",
	zh-HK => "二十二碳六酸 / DHA (22:6 n-3)",
	zh-TW => "二十二碳六酸 / DHA (22:6 n-3)",
},
'omega-6-fat' => {
	de => "Omega-6-Fettsäuren",
	el => "Ωμέγα-6 λιπαρά",
	en => "Omega 6 fatty acids",
	es => "Ácidos grasos Omega 6",
	fr => "Acides gras Oméga 6",
	he => "אומגה 6",
	hu => "Omega-6 zsírsavak",
	it=> "Acidi grassi Omega 6",
	nl => 'Omega 6-vetzuren',
	nl_be => 'Omega 6-vetzuren',
	pt => "Ácidos Graxos Ômega 6",
	pt_pt => "Ácidos gordos Ómega 6",
	ru => "Омега-6 жирные кислоты",
	zh => "Omega 6 脂肪酸",
	zh-CN => "Omega 6 脂肪酸",
	zh-HK => "Omega 6 脂肪酸",
	zh-TW => "Omega 6 脂肪酸",
},
'linoleic-acid' => {
	el => 'Λινολεϊκό οξύ / LA (18:2 n-6)',
	en => 'Linoleic acid / LA (18:2 n-6)',
	es => 'Ácido linoleico / LA (18:2 n-6)',
	fr => 'Acide linoléique / LA (18:2 n-6)',
	nl => 'Linolzuur / LA (18:2 n-6)',
	nl_be => 'Linolzuur / LA (18:2 n-6)',
	pt => 'Ácido linoleico / LA (18:2 n-6)',
	ru => "Линолевая кислота / (ЛК) 18:2 (n−6)",
	zh => "亚油酸 / LA (18:2 n-6)",
	zh-CN => "亚油酸 / LA (18:2 n-6)",
	zh-HK => "亞油酸 / LA (18:2 n-6)",
	zh-TW => "亞油酸 / LA (18:2 n-6)",
},
'arachidonic-acid' => {
	el => 'Αραχιδονικό οξύ / AA / ARA (20:4 n-6)',
	en => 'Arachidonic acid / AA / ARA (20:4 n-6)',
	es => 'Ácido araquidónico / AA / ARA (20:4 n-6)',
	fr => 'Acide arachidonique / AA / ARA (20:4 n-6)',
	he => 'חומצה ארכידונית / AA / ARA (20:4 n-6)',
	nl => 'Arachidonzuur / AA / ARA (20:4 n-6)',
	nl_be => 'Arachidonzuur / AA / ARA (20:4 n-6)',
	pt => 'Ácido araquidônico / AA / ARA (20:4 n-6)',
	pt_pt => 'Ácido araquidónico / AA / ARA (20:4 n-6)',
	ru => "Арахидоновая кислота / (АК) 20:4 (n−6)",
	zh => "花生四烯酸 / AA / ARA (20:4 n-6)",
	zh-CN => "花生四烯酸 / AA / ARA (20:4 n-6)",
	zh-HK => "花生四烯酸 / AA / ARA (20:4 n-6)",
	zh-TW => "花生四烯酸 / AA / ARA (20:4 n-6)",
},
'gamma-linolenic-acid' => {
	el => 'Γ-λινολενικό οξύ / GLA (18:3 n-6)',
	en => 'Gamma-linolenic acid / GLA (18:3 n-6)',
	es => 'Ácido gamma-linolénico / GLA (18:3 n-6)',
	fr => 'Acide gamma-linolénique / GLA (18:3 n-6)',
	nl => 'Gamma-linoleenzuur / GLA (18:3 n-6)',
	nl_be => 'Gamma-linoleenzuur / GLA (18:3 n-6)',
	pt => 'Ácido gama-linolênico / GLA (18:3 n-6)',
	pt_pt => 'Ácido gama-linolénico / GLA (18:3 n-6)',
	ru => "γ-линоленовая кислота / (GLA) 18:3 (n−6)",
	zh => "γ-亚麻酸 / GLA (18:3 n-6)",
	zh-CN => "γ-亚麻酸 / GLA (18:3 n-6)",
	zh-HK => "γ-亞麻酸 / GLA (18:3 n-6)",
	zh-TW => "γ-亞麻酸 / GLA (18:3 n-6)",
},
'dihomo-gamma-linolenic-acid' => {
	el => 'Διχομο-γ-λινολεϊκό οξύ / DGLA (20:3 n-6)',
	en => 'Dihomo-gamma-linolenic acid / DGLA (20:3 n-6)',
	es => 'Ácido dihomo-gamma-linolénico / DGLA (20:3 n-6)',
	fr => 'Acide dihomo-gamma-linolénique / DGLA (20:3 n-6)',
	nl => 'Dihomo-gammalinoleenzuur / DGLA (20:3 n-6)',
	nl_be => 'Dihomo-gammalinoleenzuur / DGLA (20:3 n-6)',
	pt => 'Ácido dihomo-gama-linolênico / DGLA (20:3 n-6)',
	pt_pt => 'Ácido dihomo-gama-linolénico / DGLA (20:3 n-6)',
	ru => "Дигомо-γ-линоленовая кислота / (ДГДК) 20:3 (n−6)",
	zh => "二高-γ-亚麻酸 / DGLA (20:3 n-6)",
	zh-CN => "二高-γ-亚麻酸 / DGLA (20:3 n-6)",
	zh-HK => "二高-γ-亞麻酸 / DGLA (20:3 n-6)",
	zh-TW => "二高-γ-亞麻酸 / DGLA (20:3 n-6)",
},

'trans-fat' => {
	cs => "Trans tuky",
	de => "Trans-Fettsäuren",
	el => 'Τρανς λιπαρά',
	en => "Trans fat",
	es => "Grasas trans",
	fr => "Acides gras trans",
	he => "שומן טראנס - שומן בלתי רווי",
	it => "Acidi grassi trans",
	nl => 'Transvetten',
	nl_be => 'Transvetten',
	pt => "Gorduras trans",
	pt_pt => "Ácidos gordos trans",
	ru => "Транс-жиры",
	zh => "反式脂肪",
	zh-CN => "反式脂肪",
	zh-HK => "反式脂肪",
	zh-TW => "反式脂肪",
},
cholesterol => {
	ar=> "الكوليسترول ",
	cs => "Cholestrol",
	de => "Cholesterin",
	el => 'Χοληστερόλη',
	en => "Cholesterol",
	es => "Colesterol",
	fr => "Cholestérol",
	he => "כולסטרול",
	it=> "Colesterolo",
	ja => "コレステロール",
	nl => "Cholesterol",
	nl_be => "Cholesterol",
	pt => "Colesterol",
	ru => "Холестерин",
	tr => "Kolestrol",
	zh => "胆固醇",
	zh-CN => "胆固醇",
	zh-HK => "膽固醇",
	zh-TW => "膽固醇",
	unit => "mg",
},
fiber => {
	bg => "Влакнини",
	cs => "Vláknina",
	da => "Kostfibre",
	de => "Ballaststoffe",
	el => "Εδώδιμες ίνες",
	en => "Dietary fiber",
	es => "Fibra alimentaria",
	et => "Kiudained",
	fi => "Ravintokuitu",
	fr => "Fibres alimentaires",
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
	ru => "Пищевые волокна",
	sk => "Vláknina",
	sl => "Prehranskih vlaknin",
	sv => "Fiber",
	zh => "膳食纤维",
	zh-CN => "膳食纤维",
	zh-HK => "膳食纖維",
	zh-TW => "纖維",
},
"soluble-fiber" => {
        de => 'lösliche Ballaststoffe',
	en => "Soluble fiber",
	fr => "Fibres solubles",
	pt => "Fibra alimentar solúvel",
	ru => "Растворимые волокна",
	zh => "可溶性纤维",
	zh-CN => "可溶性纤维",
	zh-HK => "可溶性纖維",
	zh-TW => "可溶性纖維",
},
"insoluble-fiber" => {
        de => 'unlösliche Ballaststoffe',
	en => "Insoluble fiber",
	fr => "Fibres insolubles",
	pt => "Fibra alimentar insolúvel",
	ru => "Нерастворимые волокна",
	zh => "不可溶性纤维",
	zh-CN => "不可溶性纤维",
	zh-HK => "不可溶性纖維",
	zh-TW => "不可溶性纖維",
},
sodium => {
	ar => "الصوديوم",
	cs => "Sodík",
	de => "Natrium",
	el => "Νάτριο",
	en => "Sodium",
	es => "Sodio",
	fr => "Sodium",
	he => "נתרן",
	hu => "Nátrium",
	it => "Sodio",
	ja => "ナトリウム",
	nl => "Natrium",
	nl_be => "Sodium",
	pt => "Sódio",
	ru => "Натрий",
	unit_us => 'mg',
	zh => "钠",
	zh-CN => "钠",
	zh-HK => "鈉",
	zh-TW => "鈉",
},
salt => {
	bg => "Сол",
	cs => "Sůl",
	da => "Salt",
	de => "Salz",
	el => "Αλάτι",Sodium
	en => "Salt",
	es => "Sal",
	et => "Sool",
	fi => "Suola",
	fr => "Sel",
	ga => "Salann",
	he => "מלח",
	hu => "Só",
	it => "Sale",
	ja => "食塩相当量",
	lt => "Druska",
	lv => "Sāls",
	mt => "Melħ",
	nl => "Zout",
	nl_be => "Zout",
	nb => "Salt",
	pl => "Sól",
	pt => "Sal",
	ro => "Sare",
	ru => "Соль",
	sk => "Soľ",
	sl => "Sol",
	tr => "Tuz",
	zh => "盐",
	zh-CN => "盐",
	zh-HK => "鹽",
	zh-TW => "鹽",
},
'salt-equivalent' => {
	el => "Ισοδύναμο σε αλάτι",
	en => "Salt equivalent",
	es => "Equivalente en sal",
	fr => "Equivalent en sel",
	he => "תחליפי מלח",
	nl => "Equivalent in zout",
	nl_be => "Equivalent in zout",
	pt => "Equivalente em sal",
	ru => "Эквивалент соли",
	zh => "盐当量",
	zh-CN => "盐当量",
	zh-HK => "相當鹽含量",
	zh-TW => "相當鹽含量",
},
'#vitamins' => {
	ar => "الفايتمينات",
	bg => "Витамин",
	de => "Vitamine",
	el => "Βιταμίνες",
	en => "Vitamin",
	es => "Vitaminas",
	et => "Vitamiin",
	fi => "vitamiini",
	fr => "Vitamines",
	ga => "Vitimín",
	he => "ויטמינים",
	hu => "vitamin",
	it => "Vitamine",
	lt => "Vitaminas",
	lv => "vitamīns",
	mt => "Vitamina",
	nl => "Vitamines",
	nl_be => "Vitamines",
	pl => "Witamina",
	pt => "Vitaminas",
	ro => "Vitamina",
	ru => "Витамины",
	sk => "Vitamín",
	tr => "Vitamin",
	zh => "维生素",
	zh-CN => "维生素",
	zh-HK => "維他命",
	zh-TW => "維生素",
},
'vitamin-a' => {
	bg => "Витамин A",
	de => "Vitamin A (Retinol)",
	el => "Βιταμίνη A",
	en => "Vitamin A",
	es => "Vitamina A (Retinol)",
	et => "Vitamiin A",
	fi => "A-vitamiini",
	fr => "Vitamine A (rétinol)",
	ga => "Vitimín A",
	he => "ויטמין A (רטינול)",
	hu => "A-vitamin",
	it => "Vitamina A (Retinolo)",
	ja => "ビタミン A",
	lt => "Vitaminas A",
	lv => "A vitamīns",
	mt => "Vitamina A",
	nl => "Vitamine A",
	nl_be => "Vitamine A",
	pl => "Witamina A",
	pt => "Vitamina A",
	ro => "Vitamina A",
	ru => "Витамин A",
	sk => "Vitamín A",
	zh => "维生素 A",
	zh-CN => "维生素 A",
	zh-HK => "維他命 A",
	zh-TW => "維生素 A",

	unit => "µg",
	dv => "1500",
	unit_us => '% DV',
	unit_ca => '% DV',
},
'vitamin-d' => {
	bg => "Витамин D",
	de => "Vitamin D / D3 (Cholecalciferol)",
	el => "Βιταμίνη D",
	en => "Vitamin D",
	es => "Vitamina D",
	et => "Vitamiin D",
	fi => "D-vitamiini",
	fr => "Vitamine D / D3 (cholécalciférol)",
	ga => "Vitimín D",
	he => "ויטמין D",
	hu => "D-vitamin",
	it => "Vitamina D (colecalciferolo)",
	ja => "ビタミン D",
	lt => "Vitaminas D",
	lv => "D vitamīns",
	mt => "Vitamina D",
	nl => "Vitamine D",
	nl_be => "Vitamine D",
	pl => "Witamina D",
	pt => "Vitamina D",
	ro => "Vitamina D",
	ru => "Витамин D",
	sk => "Vitamín D",
	zh => "维生素 D",
	zh-CN => "维生素 D",
	zh-HK => "維他命 D",
	zh-TW => "維生素 D",
	dv => "40",
	unit => "µg",
},
'vitamin-d2' => {
	bg => "Витамин D2",
	de => "Vitamin D2 (Cholecalciferol)",
	el => "Βιταμίνη D2",
	en => "Vitamin D2 (ergocalciferol)",
	es => "Vitamina D2 (Ergocalciferol)",
	et => "Vitamiin D2 (ergokaltsiferool)",
	fi => "D2-vitamiini (ergokalsiferoli)",
	fr => "Vitamine D2 (ergocalciférol)",
	ga => "Vitimín D2",
	he => "ויטמין D2",
	hu => "D2-vitamin",
	it => "Vitamina D2 (ergocalciferolo)",
	ja => "ビタミン D2",
	lt => "Vitaminas D2 (ergokalciferoliu)",
	lv => "D2 vitamīns (ergokalciferols)",
	mt => "Vitamina D2",
	nl => "Vitamine D2 (ergocalciferol)",
	nl_be => "Vitamine D2 (ergocalciferol)",
	pl => "Witamina D2 (ergokalcyferol)",
	pt => "Vitamina D2 (ergocalciferol)",
	ro => "Vitamina D2 (ergocalciferol)",
	ru => "Витамин D2 (эргокальциферол)",
	sk => "Vitamín D2 (erkalciol)",
	zh => "维生素 D2",
	zh-CN => "维生素 D2",
	zh-HK => "維他命 D2",
	zh-TW => "維生素 D2",

	unit => "µg",
},

'vitamin-e' => {
	bg => "Витамин E",
	de => "Vitamin E (Tocopherol)",
	el => "Βιταμίνη E",
	en => "Vitamin E",
	es => "Vitamina E (a-tocoferol)",
	et => "Vitamiin E",
	fi => "E-vitamiini",
	fr => "Vitamine E (tocophérol)",
	ga => "Vitimín E",
	he => "ויטמין E (אלפא טוקופרול)",
	hu => "E-vitamin",
	it => "Vitamina E (Alfa-tocoferolo)",
	ja => "ビタミン E",
	lt => "Vitaminas E",
	lv => "E vitamīns",
	mt => "Vitamina E",
	nl => "Vitamine E",
	nl_be => "Vitamine E",
	pl => "Witamina E",
	pt => "Vitamina E",
	ro => "Vitamina E",
	ru => "Витамин E",
	sk => "Vitamín E",
	zh => "维生素 E",
	zh-CN => "维生素 E",
	zh-HK => "維他命 E",
	zh-TW => "維生素 E",

	dv => "20",
	unit => "mg",
},
'vitamin-k' => {
	bg => "Витамин K",
	de => "Vitamin K",
	el => "Βιταμίνη K",
	en => "Vitamin K",
	es => "Vitamina K",
	et => "Vitamiin K",
	fi => "K-vitamiini",
	fr => "Vitamine K",
	ga => "Vitimín K",
	he => "ויטמין K (מנדיון)",
	hu => "K-vitamin",
	it => "Vitamina K",
	ja => "ビタミン K",
	lt => "Vitaminas K",
	lv => "K vitamīns",
	mt => "Vitamina K",
	nl => "Vitamine K",
	nl_be => "Vitamine K",
	pl => "Witamina K",
	pt => "Vitamina K",
	ro => "Vitamina K",
	ru => "Витамин K",
	sk => "Vitamín K",
	zh => "维生素 K",
	zh-CN => "维生素 K",
	zh-HK => "維他命 K",
	zh-TW => "維生素 K",

	dv => "80",
	unit => "µg",
},
'vitamin-c' => {
	bg => "Витамин C",
	de => "Vitamin C (Ascorbinsäure)",
	el => "Βιταμίνη C",
	en => "Vitamin C (ascorbic acid)",
	es => "Vitamina C (Ácido ascórbico)",
	et => "Vitamiin C",
	fi => "C-vitamiini",
	fr => "Vitamine C (acide ascorbique)",
	ga => "Vitimín C",
	he => "ויטמין C (חומצה אסקורבית)",
	hu => "C-vitamin",
	it => "Vitamina C (Acido ascorbico)",
	ja => "ビタミン C",
	lt => "Vitaminas C",
	lv => "C vitamīns",
	mt => "Vitamina C",
	nl => "Vitamine C",
	nl_be => "Vitamine C",
	pl => "Witamina C",
	pt => "Vitamina C",
	ro => "Vitamina C",
	ru => "Витамин C (аскорбиновая кислота)",
	sk => "Vitamín C",
	zh => "维生素 C（抗坏血酸）",
	zh-CN => "维生素 C（抗坏血酸）",
	zh-HK => "維他命 C（抗壞血酸）",
	zh-TW => "維生素 C（抗壞血酸）",

	unit => "mg",
	dv => "60",
	unit_us => '% DV',
	unit_ca => '% DV',
},
'vitamin-b1' => {
	bg => "Витамин B1 (Тиамин)",
	de => "Vitamin B1 (Thiamin)",
	el => "Βιταμίνη B1 (Θειαμίνη)",
	en => "Vitamin B1 (Thiamin)",
	es => "Vitamina B1 (Tiamina)",
	et => "Vitamiin B1 (Tiamiin)",
	fi => "B1-vitamiini (Tiamiini)",
	fr => "Vitamine B1 (Thiamine)",
	ga => "Vitimín B1 (Tiaimín)",
	he => "ויטמין B1 (תיאמין)",
	hu => "B1-vitamin (Tiamin)",
	it => "Vitamina B1 (tiamina)",
	ja => "ビタミン B1",
	lt => "Vitaminas B1 (Tiaminas)",
	lv => "B1 vitamīns (Tiamīns)",
	mt => "Vitamina B1 (Tiamina)",
	nl => "Vitamine B1 (Thiamine)",
	nl_be => "Vitamine B1 (Thiamine)",
	nb => "Vitamine B1 (Thiamine)",
	pl => "Witamina B1 (Tiamina)",
	pt => "Vitamina B1 (Tiamina)",
	ro => "Vitamina B1 (Tiamină)",
	ru => "Витамин B1 (Тиамин)",
	sk => "Vitamín B1",
	sl => "Vitamin B1 (Tiamin)",
	zh => "维生素 B1（硫胺）",
	zh-CN => "维生素 B1（硫胺）",
	zh-HK => "維他命 B1（硫胺素）",
	zh-TW => "維生素 B1（硫胺素）",

	dv => "1.5",
	unit => "mg",
},
'vitamin-b2' => {
	bg => "Витамин B2 (Рибофлавин)",
	de => "Vitamin B2 (Riboflavin)",
	el => "Βιταμίνη B2 (Ριβοφλαβίνη)",
	en => "Vitamin B2 (Riboflavin)",
	es => "Vitamina B2 (Riboflavina)",
	et => "Vitamiin B2 (Riboflaviin)",
	fi => "B2-vitamiini (Riboflaviini)",
	fr => "Vitamine B2 (Riboflavine)",
	ga => "Vitimín B2 (Ribeaflaivin)",
	he => "ויטמין B2 (ריבופלבין)",
	hu => "B2-vitamin (Riboflavin)",
	it => "Vitamina B2 (Riboflavina)",
	ja => "ビタミン B2",
	lt => "Vitaminas B2 (Riboflavinas)",
	lv => "B2 vitamīns (Riboflavīns)",
	mt => "Vitamina B2 (Riboflavina)",
	nl => "Vitamine B2 (Riboflavine)",
	nl_be => "Vitamine B2 (Riboflavine)",
	pl => "Witamina B2 (Ryboflawina)",
	pt => "Vitamina B2 (Riboflavina)",
	ro => "Vitamina B2 (Riboflavină)",
	ru => "Витамин B2 (Рибофлавин)",
	sk => "Vitamín B2",
	zh => "维生素 B2（核黄素）",
	zh-CN => "维生素 B2（核黄素）",
	zh-HK => "維他命 B2（核黃素）",
	zh-TW => "維生素 B2（核黃素）",

	dv => "1.7",
	unit => "mg",
},
'vitamin-pp' => {
	bg => "Ниацин",
	de => "Vitamin B3 / Vitamin PP (Niacin)",
	el => "Νιασίνη",
	en => "Vitamin B3 / Vitamin PP (Niacin)",
	es => "Vitamina B3 / Vitamina PP (Niacina)",
	et => "Niatsiin",
	fi => "Niasiini",
	fr => "Vitamine B3 / Vitamine PP (Niacine)",
	ga => "Niaicin",
	he => "ויטמין B3 /ויטמין PP (ניאצין או חומצה ניקוטינית)",
	hu => "B3-vitamin / PP-vitamin (Niacin)",
	it => "Vitamina B3 / Vitamina PP (Niacina)",
	ja => "ビタミン B3",
	lt => "Niacinas",
	lv => "Niacīns",
	mt => "Niaċina",
	nl => "Niacine",
	nl_be => "Niacine",
	pl => "Niacyna",
	pt => "Vitamina B3 / Vitamina PP (Niacina)",
	ro => "Niacină",
	ru => "Ниацин / Витамин PP / Витамин B<sub>3</sub>>",
	sk => "Niacín",
	zh => "维生素 B3 / 维生素 PP（烟酸）",
	zh-CN => "维生素 B3 / 维生素 PP（烟酸）",
	zh-HK => "維他命 B3 / 維生素 PP（菸酸）",
	zh-TW => "維生素 B3 / 維生素 PP（菸酸）",

	dv => "20",
	unit => "mg",
},
'vitamin-b6' => {
	bg => "Витамин B6",
	de => "Vitamin B6 (Pyridoxin)",
	el => "Βιταμίνη B6",
	en => "Vitamin B6 (Pyridoxin)",
	es => "Vitamina B6 (Piridoxina)",
	et => "Vitamiin B6",
	fi => "B6-vitamiini",
	fr => "Vitamine B6 (Pyridoxine)",
	ga => "Vitimín B6",
	he => "ויטמין B6 (פירידוקסין)",
	hu => "B6-vitamin",
	it => "Vitamina B6 (piridoxina)",
	ja => "ビタミン B6",
	lt => "Vitaminas B6",
	lv => "B6 vitamīns",
	nl => "Vitamine B6",
	nl_be => "Vitamine B6",
	pl => "Witamina B6",
	pt => "Vitamina B6 (Piridoxina)",
	ro => "Vitamina B6",
	ru => "Витамин B6",
	sk => "Vitamín B6",
	zh => "维生素 B6",
	zh-CN => "维生素 B6",
	zh-HK => "維他命 B6",
	zh-TW => "維生素 B6",

	dv => "2",
	unit => "mg",
},
'vitamin-b9' => {
	bg => "Витамин B9 (Фолиева киселина)",
	de => "Vitamin B9 (Folsäure)",
	el => "Βιταμίνη B9 (Φολικό οξύ)",
	en => "Vitamin B9 (Folic acid / Folates)",
	es => "Vitamina B9 (Ácido fólico)",
	et => "Vitamiin B9 (Foolhape)",
	fi => "B9-vitamiini (Foolihappo)",
	fr => "Vitamine B9 (Acide folique)",
	ga => "Vitimín B9 (Aigéad fólach)",
	he => "ויטמין B9 (חומצה פולית)",
	hu => "B9-vitamin (Folsav)",
	it => "Vitamina B9 (Acido folico)",
	ja => "ビタミン B9 (葉酸)",
	lt => "Vitaminas B9 (Folio rūgštis)",
	lv => "B9 vitamīns (Folijskābe)",
	nl => "Vitamine B9 (Foliumzuur)",
	nl_be => "Vitamine B9 (Foliumzuur)",
	nb => "Vitamin B9 (Folsyre)",
	pl => "Witamina B9 (Kwas foliowy)",
	pt => "Vitamina B9 (Ácido Fólico)",
	ro => "Vitamina B9 (Acid folic)",
	ru => "Витамин B9 (Фолиевая кислота)",
	sk => "Vitamín B9 (Kyselina listová)",
	zh => "维生素 B9（叶酸）",
	zh-CN => "维生素 B9（叶酸）",
	zh-HK => "維他命 B9（葉酸）",
	zh-TW => "維生素 B9（葉酸）",

	dv => "400",
	unit => "µg",
},
'vitamin-b12' => {
	bg => "Витамин В12",
	de => "Vitamin B12 (Cobalamin)",
	el => "Βιταμίνη B12",
	en => "Vitamin B12 (cobalamin)",
	es => "Vitamina B12 (Cianocobalamina)",
	et => "Vitamiin B12",
	fi => "B12-vitamiini",
	fr => "Vitamine B12 (cobalamine)",
	ga => "Vitimín B12",
	he => "ויטמין B12 (ציאנוקובלאמין)",
	hu => "B12-vitamin",
	it => "Vitamina B12 (Cobalamina)",
	ja => "ビタミン B12",
	lt => "Vitaminas B12",
	lv => "B12 vitamīns",
	nl => "Vitamine B12",
	nl_be => "Vitamine B12",
	pl => "Witamina B12",
	pt => "Vitamina B12 (Cobalamina)",
	ro => "Vitamina B12",
	ru => "Витамин В12",
	sk => "Vitamín B12",
	zh => "维生素 B12",
	zh-CN => "维生素 B12",
	zh-HK => "維他命 B12",
	zh-TW => "維生素 B12",

	dv => "6",
	unit => "µg",
},
'biotin' => {
	bg => "Биотин",
	de => "Biotin (Vitamin B8 / B7 / H)",
	el => "Βιοτίνη",
	en => "Biotin",
	es => "Vitamina B7 (Biotina)",
	et => "Biotiin",
	fi => "Biotiini",
	fr => "Biotine (Vitamine B8 / B7 / H)",
	ga => "Bitin",
	he => "ביוטין (ויטמין B7)",
	hu => "Biotin (B7-vitamin)",
	it => "Vitamina B8/B7/H/I (Biotina)",
	ja => "ビタミン B8 / B7 / H",
	lt => "Biotinas",
	lv => "Biotīns",
	nl => "Biotine",
	nl_be => "Biotine",
	nb => "Bitin",
	pl => "Biotyna",
	pt => "Vitamina B7 (Biotina)",
	ro => "Biotină",
	ru => "Биотин",
	sk => "Biotín",
	zh => "生物素",
	zh-CN => "生物素",
	zh-HK => "生物素",
	zh-TW => "生物素",

	dv => "300",
	unit => "µg",
},
'pantothenic-acid' => {
	bg => "Пантотенова киселина",
	cs => "Kyselina pantothenová",
	da => "Pantothensyre",
	de => "Pantothensäure (Vitamin B5)",
	el => "Παντοθενικό οξύ",
	en => "Pantothenic acid / Pantothenate (Vitamin B5)",
	es => "Vitamina B5 (Ácido pantoténico)",
	et => "Pantoteenhape",
	fi => "Pantoteenihappo",
	fr => "Acide pantothénique (Vitamine B5)",
	ga => "Aigéad pantaitéineach",
	he => "חומצה פנטותנית (ויטמין B5)",
	hu => "Pantoténsav (B5-vitamin)",
	it => "Vitamina B5 (Acido pantotenico)",
	ja => "ビタミン B5",
	lt => "Pantoteno rūgštis",
	lv => "Pantotēnskābe",
	mt => "Aċidu Pantoteniku",
	nl => "Pantotheenzuur",
	nl_be => "Pantotheenzuur",
	nb => "Pantotensyre",
	pl => "Kwas pantotenowy",
	pt => "Vitamina B5 (Ácido Pantotênico)",
	pt_pt => "Vitamina B5 (ácido pantoténico)",
	ro => "Acid pantotenic",
	ru => "Пантотеновая кислота",
	sk => "Kyselina pantotenová",
	sl => "Pantotenska kislina",
	sv => "Pantotensyra",
	zh => "泛酸",
	zh-CN => "泛酸",
	zh-HK => "泛酸",
	zh-TW => "泛酸",

	dv => "10",
	unit => "mg",
},
'#minerals' => {
	cs => "Minerály",
	de => "Mineralien",
	el => "Ανόργανα άλατα",
	en => "Minerals",
	es => "Sales minerales",
	fr => "Sels minéraux",
	he => "מינרלים",
	hu => "Ásványi anyagok",
	it => "Sali minerali",
	nl => "Mineralen",
	nl_be => "Mineralen",
	pt => "Sais Minerais",
	ru => "Минералы",
	zh => "矿物质",
	zh-CN => "矿物质",
	zh-HK => "礦物質",
	zh-TW => "礦物質",
},
potassium => {
	bg => "Калий",
	cs => "Draslík",
	da => "Kalium",
	de => "Kalium",
	el => "Κάλιο",
	en => "Potassium",
	es => "Potasio",
	et => "Kaaliumv",
	fi => "Kalium",
	fr => "Potassium",
	ga => "Potaisiam",
	he => "אשלגן",
	hu => "Kálium",
	it => "Potassio",
	lt => "Kalis",
	lv => "Kālijs",
	mt => "Potassju",
	nl => "Kalium",
	nl_be => "Kalium",
	nb => "Kalium",
	pl => "Potas",
	pt => "Potássio",
	ro => "Potasiu",
	ru => "Калий",
	sk => "Draslík",
	sl => "Kalij",
	sv => "Kalium",
	zh => "钾",
	zh-CN => "钾",
	zh-HK => "鉀",
	zh-TW => "鉀",

	unit => "mg",
},
bicarbonate => {
	de => "Bikarbonat",
	el => "Διττανθρακικό",
	en => "Bicarbonate",
	es => "Bicarbonato",
	fr => "Bicarbonate",
	he => "ביקרבונט (מימן פחמתי)",
	hu => "Bikarbonát",
	it => "Bicarbonato",
	nl => "Bicarbonaat",
	nl_be => "Bicarbonaat",
	pt => "Bicarbonato",
	ru => "Бикарбонат",
	zh => "碳酸氢钠",
	zh-CN => "碳酸氢钠",
	zh-HK => "碳酸氫鈉",
	zh-TW => "碳酸氫鈉",

	unit => "mg",
},
chloride => {
	bg => "Хлорид",
	cs => "Chlor",
	da => "Chlorid",
	de => "Chlor",
	dv => "3400",
	el => "Χλώριο",
	en => "Chloride",
	es => "Cloro",
	et => "Kloriid",
	fi => "Kloridi",
	fr => "Chlorure",
	ga => "Clóiríd",
	he => "כלוריד",
	hu => "Klorid",
	it => "Cloruro",
	lt => "Chloridas",
	lv => "Hlorīdsv",
	mt => "Kloridu",
	nl => "Chloor",
	nl_be => "Chloor",
	nb => "Klorid",
	pl => "Chlor",
	pt => "Cloreto",
	ro => "Clorură",
	ru => "Хлорид",
	sk => "Chlorid",
	sl => "Klorid",
	sv => "Klorid",
	zh => "氯化物",
	zh-CN => "氯化物",
	zh-HK => "氯化物",
	zh-TW => "氯化物",

	unit => "mg",
},
silica => {
	de => "Kieselerde",
	el => "Πυρίτιο",
	en => "Silica",
	es => "Sílice",
	fr => "Silice",
	he => "צורן דו־חמצני",
	it => "Silicio",
	nl => "Silicium",
	nl_be => "Silicium",
	nb => "Silika",
	pt => "Sílica",
	ru => "Кремний",
	zh => "二氧化矽",
	zh-CN => "二氧化矽",
	zh-HK => "二氧化矽",
	zh-TW => "二氧化矽",

	unit => "mg",
},
calcium => {
	ar => "الكالسيوم",
	bg => "Калций",
	cs => "Vápník",
	de => "Kalzium",
	el => "Ασβέστιο",
	en => "Calcium",
	es => "Calcio",
	et => "Kaltsium",
	fi => "Kalsium",
	fr => "Calcium",
	ga => "Cailciam",
	he => "סידן",
	hu => "Kalcium",
	it => "Calcio",
	ja => "カルシウム",
	lt => "Kalcis",
	lv => "Kalcijs",
	mt => "Kalċju",
	nl => "Calcium",
	nl_be => "Calcium",
	nb => "Kalsium",
	pl => "Wapń",
	pt => "Cálcio",
	ro => "Calciu",
	ru => "Кальций",
	sk => "Vápnik",
	sl => "Kalcij",
	sv => "Kalcium",
	tr => "Kalsiyum",
	zh => "钙",
	zh-CN => "钙",
	zh-HK => "鈣",
	zh-TW => "鈣",

	unit => "mg",
	dv => "1000",
	unit_us => '% DV',
	unit_ca => '% DV',
},
phosphorus => {
	ar => "الفوسفور",
	bg => "Фосфор",
	cs => "Fosfor",
	da => "Phosphor",
	de => "Phosphor",
	el => "Φωσφόρος",
	en => "Phosphorus",
	es => "Fósforo",
	et => "Fosfor",
	fi => "Fosfori",
	fr => "Phosphore",
	ga => "Fosfar",
	he => "זרחן",
	hu => "Foszfor",
	it => "Fosforo",
	lt => "Fosforas",
	lv => "Fosfors",
	mt => "Fosfru",
	nl => "Fosfor",
	nl_be => "Fosfor",
	nb => "Fosfor",
	pl => "Fosfor",
	pt => "Fósforo",
	ro => "Fosfor",
	ru => "Фосфор",
	sk => "Fosfor",
	sl => "Fosfor",
	sv => "Fosfor",
	zh => "磷",
	zh-CN => "磷",
	zh-HK => "磷",
	zh-TW => "磷",

	dv => "1000",
	unit => "mg",
},
iron => {
	bg => "Желязо",
	cs => "Železo",
	da => "Jern",
	de => "Eisen",
	el => "Σίδηρος",
	en => "Iron",
	es => "Hierro",
	et => "Raud",
	fi => "Rauta",
	fr => "Fer",
	ga => "Iarann",
	he => "ברזל",
	hu => "Vas",
	it => "Ferro",
	ja => "鉄",
	lt => "Geležis",
	lv => "Dzelzs",
	mt => "Kalċju",
	nl => "IJzer",
	nl_be => "IJzer",
	nb => "Jern",
	pl => "Żelazo",
	pt => "Ferro",
	ro => "Fier",
	ru => "Железо",
	sk => "Železo",
	sl => "Železo",
	sv => "Järn",
	zh => "铁",
	zh-CN => "铁",
	zh-HK => "鐵",
	zh-TW => "鐵",

	dv => "18",
	unit => "mg",
	unit_ca => '% DV',
	unit_us => '% DV',
},
magnesium => {
	bg => "Магнезий",
	cs => "Hořčík",
	de => "Magnesium",
	el => "Μαγνήσιο",
	en => "Magnesium",
	es => "Magnesio",
	et => "Magneesium",
	fr => "Magnésium",
	ga => "Maignéisiam",
	he => "מגנזיום",
	hu => "Magnézium",
	it => "Magnesio",
	ja => "マグネシウム",
	lt => "Magnis",
	lv => "Magnijs",
	mt => "Manjesju",
	nl => "Magnesium",
	nl_be => "Magnesium",
	nb => "Magnesium",
	pl => "Magnez",
	pt => "Magnésio",
	ro => "Magneziu",
	ru => "Магний",
	sk => "Horčík",
	sl => "Magnezij",
	tr => "Magnezyum",
	zh => "镁",
	zh-CN => "镁",
	zh-HK => "鎂",
	zh-TW => "鎂",

	dv => "400",
	unit => "mg",
},
zinc => {
	bg => "Цинк",
	cs => "Zinek",
	da => "Zink",
	de => "Zink",
	el => "Ψευδάργυρος",
	en => "Zinc",
	es => "Zinc",
	et => "Tsink",
	fi => "Sinkki",
	fr => "Zinc", "Sulfate de zinc monohydraté"
	ga => "Sinc",
	he => "אבץ",
	hu => "Cink",
	it => "Zinco",
	ja => "亜鉛",
	lt => "Cinkas",
	lv => "Cinks",
	mt => "Żingu",
	nl => "Zink",
	nl_be => "Zink",
	nb => "Sink",
	pl => "Cynk",
	pt => "Zinco",
	ru => "Цинк",
	sk => "Zinok",
	sl => "Cink",
	sv => "Zink",
	zh => "锌",
	zh-CN => "锌",
	zh-HK => "鋅",
	zh-TW => "鋅",

	dv => "15",
	unit => "mg",
},
copper => {
	bg => "Мед",
	cs => "Měď",
	da => "Kobber",
	de => "Kupfer",
	el => "Χαλκός",
	en => "Copper",
	es => "Cobre",
	et => "Vask",
	fi => "Kupari",
	fr => "Cuivre", "Sulfate de cuivre pentahydraté",
	ga => "Copar",
	he => "נחושת",
	hu => "Réz",
	it => "Rame",
	lt => "Varis",
	lv => "Varš",
	mt => "Ram",
	nl => "Koper",
	nl_be => "Koper",
	nb => "Kobber",
	pl => "Miedź",
	pt => "Cobre",
	ro => "Cupru",
	ru => "Медь",
	sk => "Meď",
	sl => "Baker",
	sv => "Koppar",
	zh => "铜",
	zh-CN => "铜",
	zh-HK => "銅",
	zh-TW => "銅",
	dv => "2",
	unit => "mg",
},
manganese => {
	bg => "Манган",
	cs => "Mangan",
	da => "Mangan",
	de => "Mangan",
	el => "Μαγγάνιο",
	en => "Manganese",
	es => "Manganeso",
	et => "Mangaan",
	fi => "Mangaani",
	fr => "Manganèse", "Sulfate de manganèse monohydraté",
	ga => "Mangainéis",
	he => "מנגן",
	hu => "Mangán",
	it => "Manganese",
	lt => "Manganas",
	lv => "Mangāns",
	mt => "Manganis",
	nl => "Mangaan",
	nl_be => "Mangaan",
	nb => "Mangan",
	pl => "Mangan",
	pt => "Manganês",
	ro => "Mangan",
	ru => "Марганец",
	sk => "Mangán",
	sl => "Mangan",
	sv => "Mangan",
	zh => "锰",
	zh-CN => "锰",
	zh-HK => "錳",
	zh-TW => "錳",

	dv => "2",
	unit => "mg",
},
fluoride => {
	bg => "Флуорид",
	cs => "Fluor",
	da => "Fluorid",
	de => "Fluor",
	el => "Φθόριο",
	en => "Fluoride",
	es => "Flúor",
	et => "Fluoriid",
	fi => "Fluoridi",
	fr => "Fluorure",
	ga => "Fluairíd",
	he => "פלואוריד",
	hu => "Fluor",
	it => "Fluoro",
	lt => "Fluoridas",
	lv => "Fluorīds",
	mt => "Floridu",
	nl => "Fluor",
	nl_be => "Fluor",
	nb => "Fluor",
	pl => "Fluor",
	pt => "Fluoreto",
	ro => "Fluorură",
	ru => "Фторид",
	sk => "Fluorid",
	sl => "Fluorid",
	sv => "Fluorid",
	zh => "氟化物",
	zh-CN => "氟化物",
	zh-HK => "氟化物",
	zh-TW => "氟化物",

	unit => "mg",
},
selenium => {
	bg => "Селен",
	cs => "Selen",
	da => "Selen",
	de => "Selen",
	el => "Σελήνιο",
	en => "Selenium",
	es => "Selenio",
	et => "Seleen",
	fi => "Seleeni",
	fr => "Sélénium",
	ga => "Seiléiniam",
	he => "סלניום",
	hu => "Szelén",
	it => "Selenio",
	lt => "Selenas",
	lv => "Selēns",
	mt => "Selenju",
	nl => "Seleen",
	nl_be => "Seleen",
	nb => "Selen",
	pl => "Selen",
	pt => "Selênio",
	pt_pt => "Selénio",
	ro => "Seleniu",
	ru => "Селен",
	sk => "Selén",
	sl => "Selen",
	sv => "Selen",
	zh => "硒",
	zh-CN => "硒",
	zh-HK => "硒",
	zh-TW => "硒",
	dv => "70",

	unit => "µg",
},
chromium => {
	bg => "Хром",
	cs => "Chrom",
	da => "Chrom",
	de => "Chrom",
	el => "Χρώμιο",
	en => "Chromium",
	es => "Cromo",
	et => "Kroom",
	fi => "Kromi",
	fr => "Chrome",
	ga => "Cróimiam",
	he => "כרום",
	hu => "Króm",
	it => "Cromo",
	lt => "Chromas",
	lv => "Hroms",
	mt => "Kromju",
	nl => "Chroom",
	nl_be => "Chroom",
	pl => "Chrom",
	pt => "Cromo",
	pt_pt => "Crómio",
	ro => "Crom",
	ru => "Хром",
	sk => "Chróm",
	sl => "Krom",
	sv => "Krom",
	zh => "铬",
	zh-CN => "铬",
	zh-HK => "鉻",
	zh-TW => "鉻",

	dv => "120",
	unit => "µg",
},
molybdenum => {
	bg => "Молибден",
	cs => "Molybden",
	da => "Molybdæn",
	de => "Molybdän",
	el => "Μολυβδαίνιο",
	en => "Molybdenum",
	es => "Molibdeno",
	et => "Molübdeen",
	fi => "Molybdeeni",
	fr => "Molybdène",
	ga => "Molaibdéineam",
	he => "מוליבדן",
	hu => "Molibdén",
	it => "Molibdeno",
	lt => "Molibdenas",
	lv => "Molibdēns",
	mt => "Molibdenum",
	nl => "Molybdeen",
	nl_be => "Molybdeen",
	pl => "Molibden",
	pt => "Molibdênio",
	pt_pt => "Molibdénio",
	ro => "Molibden",
	ru => "Молибден",
	sk => "Molybdén",
	sl => "Molibden",
	sv => "Molybden",
	zh => "钼",
	zh-CN => "钼",
	zh-HK => "鉬",
	zh-TW => "鉬",

	dv => "75",
	unit => "µg",
},
iodine => {
	bg => "Йод",
	cs => "Jód",
	da => "Jod",
	de => "Jod",
	el => "Ιώδιο",
	en => "Iodine",
	es => "Yodo",
	et => "Jood",
	fi => "Jodi",
	fr => "Iode", "iodure de potassium",
	ga => "Iaidín",
	he => "יוד",
	hu => "Jód",
	it=> "Iodio",
	lt => "Jodas",
	lv => "Jods",
	mt => "Jodju",
	nl => "Jodium",
	nl_be => "Jodium",
	pl => "Jod",
	pt => "Iodo",
	ro => "Iod",
	ru => "Йод",
	sk => "Jód",
	sl => "Jod",
	sv => "Jod",
	zh => "碘",
	zh-CN => "碘",
	zh-HK => "碘",
	zh-TW => "碘",

	dv => "150",
	unit => "µg",
},
nitrates => {
	en => 'Nitrates',
	fr => 'Nitrates',
	hu => 'Nitrátok',
	nl => 'Nitraten',
        pt => 'Nitrato',
	ru => 'Нитраты',
	zh => "硝酸盐",
	zh-CN => "硝酸盐",
	zh-HK => "硝酸鹽",
	zh-TW => "硝酸鹽",

	unit => "mg",
},
sulfates => {
	en => 'Sulfates',
	fr => 'Sulfates',
	hu => 'Szulfátok',
	nl => 'Sulfaten',
        pt => 'Sulfato',
	ru => 'Сульфаты',
	zh => "硫酸盐",
	zh-CN => "硫酸盐",
	zh-HK => "硫酸鹽",
	zh-TW => "硫酸鹽",
	unit => "mg",
},
hydrogencarbonates => {
        de => 'Hydrogenkarbonat',
	en => 'Hydrogen carbonates',
	fr => 'Hydrogénocarbonates',
	hu => 'Hidrogén-karbonátok',
	nl => 'Waterstofcarbonaten',
        pt => 'carbonato hidrogenato',
	ru => 'Гидрокарбонаты',
	zh => "碳酸氢盐",
	zh-CN => "碳酸氢盐",
	zh-HK => "碳酸氫",
	zh-TW => "碳酸氫",

	unit => "mg",
},
caffeine => {
	cs => 'Kofein',
        de => 'Koffein',
	el => "Καφεΐνη",
	en => 'Caffeine',
	fr => 'Caféine / Théine',
	nl => 'Cafeïne',
	nl_be => 'Cafeïne',
	nb => 'Koffein',
	pt => 'Cafeína',
	ru => 'Кофеин',
	zh => "咖啡因",
	zh-CN => "咖啡因",
	zh-HK => "咖啡因",
	zh-TW => "咖啡因",
},
taurine => {
	ar => 'التورين',
	bg => 'Таурин',
	ca => 'Taurina',
	cs => 'Taurin',
	da => 'Taurin',
	de => 'Taurin',
	el => 'Ταυρίνη',
	en => 'Taurine',
	en_ca => 'Taurine',
	en_gb => 'Taurine',
	eo => 'Taŭrino',
	es => 'Taurina',
	et => 'Tauriin',
	fa => 'تائورین',
	fi => 'Tauriini',
	fr => 'Taurine',
	gl => 'Taurina',
	he => 'טאורין',
	hr => 'Taurin',
	hu => 'Taurin',
	hy => 'Տաուրին',
	id => 'Taurina',
	it => 'Taurina',
	ja => 'タウリン',
	ko => '타우린',
	mk => 'Таурин',
	nb => 'Taurin',
	nl => 'Taurine',
	nl_be => 'Taurine',
	nb => 'Taurin',
	pl => 'Tauryna',
	pt => 'Taurina',
	pt_br => 'Taurina',
	ro => 'Taurină',
	ru => 'Таурин',
	sh => 'Taurin',
	sk => 'Taurín',
	sl => 'Tavrin',
	sq => 'taurin',
	sr => 'таурин',
	sr_ec => 'Таурин',
	sr_el => 'Taurin',
	sv => 'Taurin',
	tr => 'Taurin',
	uk => 'Таурин',
	vi => 'Taurine',
	wa => 'Torene',
	zh => '牛磺酸',
	zh-CN => "牛磺酸",
	zh-HK => "牛磺酸",
	zh-TW => "牛磺酸",
	zh_cn => "牛磺酸",
	zh_hans => "牛磺酸",
	zh_hant => "牛磺酸",
	zh_hk => "牛磺酸",
	zh_sg => "牛磺酸",
	zh_tw => "牛磺酸",
},
ph => {
	da => "pH",
	de => "pH", "pH-Wert",
	el => "pH",
	en => "pH",
	it => "pH",
	hu => "pH",
	nl => "pH",
	nl_be => "pH",
	nb => "pH",
	zh => "pH",
	zh-CN => "pH",
	zh-HK => "pH",
	zh-TW => "pH",

	unit => '',
},
"carbon-footprint" => {
	cs => "Uhlíková stopa / Emise CO<sub>2</sub>",
	de => "Carbon Footprint / CO<sub>2</sub>-Emissionen",
	el => "Αποτύπωμα άνθρακα/Εκπομπές CO<sub>2</sub>",
	en => "Carbon footprint / CO<sub>2</sub> emissions",
	es => "Huella de carbono / Emisiones de CO<sub>2</sub>",
	fr => "Empreinte carbone / émissions de CO<sub>2</sub>",
	he => "טביעת רגל פחמנית / פליטת פחמן דו־חמצני",
	hu => "Ökológiai lábnyom / CO<sub>2</sub> kibocsájtás",
	it=> "Emissioni di CO2 (impronta climatica)",
	nl => "Ecologische voetafdruk / CO<sub>2</sub>-uitstoot",
	nl_be => "Ecologische voetafdruk / CO<sub>2</sub>-uitstoot",
	pt => "Pegada de carbono / Emissões de CO<sub>2</sub>",
	ru => "Углеродный отпечаток / CO<sub>2</sub> эмиссия",
	zh => "碳足迹 / 二氧化碳排放",
	zh-CN => "碳足迹 / 二氧化碳排放",
	zh-HK => "碳足跡 / 二氧化碳排放",
	zh-TW => "碳足跡 / 二氧化碳排放",

	unit => 'g',
},
"fruits-vegetables-nuts" => {
	de => "Obst, Gemüse und Nüsse (Minimum)",
	en => "Fruits, vegetables and nuts (minimum)",
	ru => "Фрукты, овощи и орехи (минимум)",
	fr => "Fruits, légumes et noix (minimum)",
	es => "Frutas, verduras y nueces (mínimo)",
	el => "Φρούτα, λαχανικά, καρποί (ελάχιστο)",
	hu => "Gyümölcsök, zöldségek és diófélék (minimum)",
	nl => "Fruit, groenten en noten (minimum)",
	nl_be => "Fruit, groenten en noten (minimum)",
        pt => "Frutas, legumes e nozes (mínimo)",
	zh-TW => "水果、蔬菜、堅果（最低限度）",
	zh-HK => "水果、蔬菜、堅果（最低限度）",
	zh-CN => "水果、蔬菜、坚果（最低限度）",
	zh => "水果、蔬菜、坚果（最低限度）",

	unit => '%',
},
"collagen-meat-protein-ratio" => {
	de => "Verhältnis Kollagen/Eiweiß",
	en => "Collagen/Meat protein ratio (maximum)",
	fr => "Rapport collagène sur protéines de viande (maximum)",
	el => "Αναλογία κολλαγόνου/πρωτεΐνης κρέατος (μέγιστο)",
	es => "Relación tejido conjuntivo/proteínas de carne (máximo)",
	nl => "Verhouding collageen/eiwitten uit vlees (maximum)",
	nl_be => "Verhouding collageen/eiwitten uit vlees (maximum)",
        pt => "Relação proteína de carne/proteína (máximo)",
	ru => "Коллаген/Мясной протеин соотношение (максимум)",
	zh-TW => "膠原蛋白/肉蛋白比（最高限度）",
	zh-HK => "膠原蛋白/肉蛋白比（最高限度）",
	zh-CN => "胶原蛋白/肉蛋白比（最高限度）",
	zh => "胶原蛋白/肉蛋白比（最高限度）",

	unit => "%",
},
cocoa => {
	cs => "Kakao (minimum)",
	de => "Kakao (Minimum)",
	en => "Cocoa (minimum)",
	es => "Cacao (mínimo)",
	fr => "Cacao (minimum)",
	hu => "Kakaó (minimum)",
	nl => "Cacao (minimum)",
	nb => "Kakao (minimum)",
	pt => "Cacau (minimum)",
	ru => "Какао (минимум)",
	zh => "可可（最低限度）",
	zh-CN => "可可（最低限度）",
	zh-HK => "可可（最低限度）",
	zh-TW => "可可（最低限度）",

	unit => "%",
},
"nutrition-score-uk" => {
        de => "Nährstoffpunkte - UK",
	el => "Bαθμολογία θρεπτικής αξίας-UK",
	en => "Nutrition score - UK",
	nl => "Voedingsgraad",
	nl_be => "Voedingsgraad",
        pt => "Pontos nutricionais - Reino Unido",
	ru => "Пищевая ценность - UK",
	zh => "营养评分 - 英国",
	zh-CN => "营养评分 - 英国",
	zh-HK => "營養評分 - 英國",
	zh-TW => "營養評分 - 英國",

	unit => '',
},
"nutrition-score-fr" => {
        de => "Nährstoffpunkte - Frankreich",
	el => "Βαθμολογία θρεπτικής αξίας - FR",
	en => "Experimental nutrition score",
	fr => "Score nutritionnel expérimental - France",
	nl => "Experimentele voedingsscore",
	nl_be => "Experimentele voedingsscore",
        pt => "Pontos nutricionais - França",
	ru => "Экспериментальная пищевая ценность - FR",
	zh => "营养评分 - 法国",
	zh-CN => "营养评分 - 法国",
	zh-HK => "營養評分 - 法國",
	zh-TW => "營養評分 - 法國",

	unit => '',
},
"beta-carotene" => {
	de => "Beta-Carotin",
	en => "Beta carotene",
	es => "Beta caroteno",
	fr => "Bêta carotène",
	hu => "Béta-karotin",
	nl => "Bêta-caroteen",
	nl_be => "Bêta-caroteen",
        pt => "Beta caroteno",
	ru => "Бета-каротин",
	zh => "β-胡萝卜素",
	zh-CN => "β-胡萝卜素",
	zh-HK => "β-胡蘿蔔素",
	zh-TW => "β-胡蘿蔔素",
},
"chlorophyl" => {
	de => "Chlorophyll",
	en => "Chlorophyl",
	hu => "Klorofill",
	nl => "Chlorofyl",
	nl_be => "Chlorofyl",
        pt => "Clorofila",
	ru => "Хлорофилл",
	zh => "叶绿素",
	zh-CN => "叶绿素",
	zh-HK => "葉綠素",
	zh-TW => "葉綠素",
},
"nutrition-grade" => {
        de => "Nährwertklasse",
	en => "Nutrition grade",
	fr => "Note nutritionnelle",
	ru => "Пищевой рейтинг",
        pt => "Classe nutricional",
	zh => "营养等级",
	zh-CN => "营养等级",
	zh-HK => "營養等級",
	zh-TW => "營養等級",
},
"UK units" => {
        de => "UK-Einheiten",
	en => "UK units",
        pt => "Unidades do Reino Unido",

	unit => ''",
},
"IE units" => {
        de => "IE-Einheiten",
	en => "IE units",
        pt => "Unidades da IE",

	unit => ''",
},
"AUS units" => {
        de => "AUS-Einheiten",
	en => "AUS units",
        pt => "Unidades da AUS",

	unit => ''",
},
"SA units" => {
        de => "SA-Einheiten",
	en => "SA units",
        pt => "Unidades da SA",

	unit => ''",
},
"Unité alcool" => {
        de => 'Alkoholeinheit',
	fr => "Unité alcool",

	unit => ''",
},
"IBU" => {
  de => "Internationale Bittereinheit",
  en => "International Bittering Unit",
  pt => "Medida do amargor internacional",
  ru => "Международная единица горечи",

  unit => "",
},
"cellulose" => {
	af => "Sellulose",
	ar => "سليولوز",
	az => "Sellüloza",
	be => "Цэлюлоза",
	be-tarask => "Цэлюлёза",
	bg => "Целулоза",
	bn => "সেলুলোজ",
	bs => "Celuloza",
	ca => "Cel·lulosa",
	cs => "Celulóza",
	cy => "Seliwlos",
	da => "Cellulose",
	de => "Zellulose",
	el => "Κυτταρίνη",
	en => "Cellulose",
	eo => "Celulozo",
	es => "Celulosa",
	et => "Tselluloos",
	eu => "Zelulosa",
	fa => "سلولز",
	fi => "Selluloosa",
	fr => "Cellulose", "Cellulose brute",
	ga => "Ceallalós",
	gl => "Celulosa",
	he => "תאית",
	hi => "सेलुलोस",
	hr => "Celuloza",
	ht => "Seliloz",
	hu => "Cellulóz,
	hy => "Բջջանյութ",
	id => "Selulosa",
	ie => "Cellulose",
	io => "Celuloso",
	is => "Sellulósi",
	it => "Cellulosa",
	ja => "セルロース",
	ka => "ცელულოზა",
	kk => "Жасұнық",
	ko => "셀룰로스",
	ku => "Seluloz",
	lt => "Celiuliozė",
	lv => "Celuloze",
	mk => "Целулоза",
	ml => "സെല്ലുലോസ്",
	mr => "सेल्युलोज",
	ms => "Selulosa",
	my => "ဆဲလျူလို့",
	nl => "Cellulose",
	nn => "Cellulose"
	nb => "Cellulose",
	oc => "Cellulòsa",
	pa => "ਸੈਲੂਲੋਜ਼",
	pl => "Celuloza",
	pt => "Celulose",
	qu => "Silulusa",
	ro => "Celuloză",
	ru => "Целлюлоза",
	sco => "Cellulose",
	sh => "Celuloza",
	sk => "Celulóza",
	sl => "Celuloza",
	sq => "Celuloza",
	sr => "Целулоза",
	su => "Selulosa",
	sv => "Cellulosa",
	ta => "மாவியம்",
	th => "เซลลูโลส",
	tr => "Selüloz",
	tt => "Tsellüloza",
	uk => "Целюлоза",
	vi => "Cellulose",
	xmf => "ცელულოზა",
	zh => "纤维素",
	zh-CN => "纤维素",
	unit => "%"
},
"ash" => {
	am => "አመድ",
	an => "Cenisa",
	ar => "رماد",
	arc => "ܩܛܡܐ",
	ay => "Qhilla",
	bat-smg => "Pelenā",
	bg => "Пепел",
	br => "Ludu",
	ca => "Cendra",
	cs => "Popel",
	da => "Aske",
	de => "Asche",
	diq => "Wele",
	en => "Ash", "Crude ash",
	es => "Ceniza",
	et => "Tuhk",
	eo => "Cindro",
	eu => "Errauts",
	fa => "خاکستر",
	fi => "Tuhka",
	fr => "Cendres brutes",
	gd => "Luath",
	gl => "Cinza",
	gn => "Tanimbu",
	got => "𐌰𐌶𐌲𐍉",
	he => "אפר",
	hr => "Pepeo",
	ht => "Sann",
	hu => "Hamu",
	io => "Cindro",
	it => "Cenere",
	kk => "Күл",
	ko => "재",
	ksh => "Eisch",
	la => "Cinis",
	lb => "Äschen",
	lmo => "Scender",
	lt => "Pelenai",
	nl => "As",
	nn => "Oske",
	nb => "Aske",
	oc => "Cendre",
	pl => "Popiół",
	pt => "Cinzas",
	qu => "Uchpa",
	ro => "Cenușă",
	ru => "Зола",
	sah => "Күл",
	scn => "Cìnniri",
	sco = "Ess",
	sk => "Popol",
	sn => "Dota",
	so => "Dambas",
	sr => "Пепео",
	sv => "Aska",
	tr => "Kül",
	uk => "Зола",
	vec => "Sènare"
	yi => "אש",
	zh => "粗灰分",
	zh-CN => "粗灰分",
	zh-yue => "灰",
	unit => "%"
},
"humidity" => {
	af => "Humiditeit",
	ar => "رطوبة",
	bat-smg => "Vilgšnībė",
	be => "Вільготнасць",
	ca => "Humitat",
	de => "Feuchtigkeit",
	el => "Υγρασία",
	en => "Humidity",
	es => "Humedad",
	et => "Niiskus",
	eu => "Hezetasun",
	fi => "Kosteus",
	fr => "Humidité",
	hr => "Vlaga",
	hu => "Nedvesség",
	ja => "水分",
	lt => "Drėgmė",
	oc => "Umiditat",
	pl => "Wilgoć",
        pt => "Húmidade",
	sh => "Vlaga",
	sn => "Hunyoro",
	sr => "Vlaga",
	sv => "Fukt",
	ta => "ஈரப்பசை",
	uk => "Вологість",
	ur => "نمی",
	zh => "湿度",
	zh-CN => "湿度",
	unit => "%"
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
	zh-CN => "胆碱",
	unit => "%"
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
	my $nid = get_fileid($label);
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

	$log->trace("nutriment canonicalized", { lc => $lc, label => $label, nid => $nid }) if $log->is_trace();
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
		$log->trace("initializing label", { lc => $lc, label => $label, nid => $nid }) if $log->is_trace();
		
		my @labels = split(/\(|\/|\)/, $label);

		foreach my $sublabel ($label, @labels) {
			$sublabel = canonicalize_nutriment($lc,$sublabel);
			if (length($sublabel) >= 2) {
				$nutriments_labels{$lc}{$sublabel} = $nid;
				$log->trace("initializing sublabel", { lc => $lc, sublabel => $sublabel, nid => $nid }) if $log->is_trace();
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


sub normalize_quantity($) {

	# return the size in g or ml for the whole product
	
	# 1 barquette de 40g
	# 20 tranches 500g
	# 6x90g --> return 540

	my $quantity = shift;
	
	my $q = undef;
	my $u = undef;
	
	if ($quantity =~ /(\d+)(\s)?(x|\*)(\s)?((\d+)(\.|,)?(\d+)?)(\s)?(kg|g|mg|µg|oz|l|dl|cl|ml|(fl(\.?)(\s)?oz))/i) {
		my $m = $1;
		$q = lc($5);
		$u = $10;
		$q =~ s/,/\./;
		$q = unit_to_g($q * $m, $u);
	}	
	elsif ($quantity =~ /((\d+)(\.|,)?(\d+)?)(\s)?(kg|g|mg|µg|oz|l|dl|cl|ml|(fl(\.?)(\s)?oz))/i) {
		$q = lc($1);
		$u = $6;
		$q =~ s/,/\./;
		$q = unit_to_g($q,$u);
	}
		
	return $q;
}


sub normalize_serving_size($) {

	my $serving = shift;
	
	my $q = 0;
	my $u;
	
	if ($serving =~ /((\d+)(\.|,)?(\d+)?)( )?(kg|g|mg|µg|oz|l|dl|cl|ml|(fl(\.?)( )?oz))/i) {
		$q = lc($1);
		$u = $6;
		$q =~ s/,/\./;
		$q = unit_to_g($q,$u);
	}
	
	$log->trace("serving size normalized", { serving => $serving, q => $q, u => $u }) if $log->is_trace();
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
"Sandwich" => "Composite foods",

"Artificially sweetened beverages" => "Beverages",
"Non-sugared beverages" => "Beverages",
"Sweetened beverages" => "Beverages",
"Fruit juices" => "Beverages",
"Fruit nectars" => "Beverages",

);

foreach my $group (keys %pnns) {
	$pnns{get_fileid($group)} = get_fileid($pnns{$group});
}


sub special_process_product($) {

	my $product_ref = shift;
	
	return if not defined $product_ref->{categories_tags};
	
	my $added_categories = '';
	
	if (has_tag($product_ref,"categories","en:beverages")) {
	
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
	
		if (not (has_tag($product_ref,"categories","en:alcoholic-beverages")
			or has_tag($product_ref,"categories","en:fruit-juices")
			or has_tag($product_ref,"categories","en:fruit-nectars") ) ) {
		
			if (has_tag($product_ref,"categories","en:sodas") and not has_tag($product_ref,"categories","en:diet-sodas")) {
				$added_categories .= ", en:sugared-beverages";
			}
			elsif ($product_ref->{with_sweeteners} 
				and not has_tag($product_ref,"categories","en:artificially-sweetened-drinks")) {
				$added_categories .= ", en:artificially-sweetened-drinks";
			}
			# fix me: ingredients are now partly taxonomized
			elsif (has_tag($product_ref, "ingredients", "sucre") or has_tag($product_ref, "ingredients", "sucre-de-canne")
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
				) {
				$added_categories .= ", en:sugared-beverages";
			}
			else {
				# at this time we can't rely on ingredients detection
				# $added_categories .= ", en:non-sugared-beverages";
			}
		}
	
	}
	
	if ($added_categories ne '') {
		my $field = 'categories';
		$product_ref->{$field . "_hierarchy" } = [ gen_tags_hierarchy_taxonomy($lc, $field, $product_ref->{$field} . $added_categories) ];
		$product_ref->{$field . "_tags" } = [];
		foreach my $tag (@{$product_ref->{$field . "_hierarchy" }}) {
			push @{$product_ref->{$field . "_tags" }}, get_taxonomyid($tag);
		}	
	}
	
	my $cat = <<CAT
<en:Beverages
en:Sugared beverages, Beverages with added sugar
fr:Boissons sucrées, Boissons avec du sucre ajouté
pnns_group_2:en:Sweetened beverages

<en:Beverages
en:Artificially sweetened beverages
fr:Boissons édulcorées, boissons aux édulcorants
pnns_group_2:en:Artificially sweetened beverages

<en:Beverages
en:Non-sugared beverages, beverages without added sugar
fr:Boissons non sucrées, boissons sans sucre ajouté
pnns_group_2:en:Non-sugared beverages

<en:Beverages
en:Alcoholic drinks, drinks with alcohol, alcohols
es:Bebidas alcohólicas
fr:Boissons alcoolisées, boisson alcoolisée, alcool, alcools	
CAT
;
	
	# compute PNNS groups 2 and 1
	
	delete $product_ref->{pnns_groups_1};
	delete $product_ref->{pnns_groups_1_tags};
	delete $product_ref->{pnns_groups_2};
	delete $product_ref->{pnns_groups_2_tags};
	
	foreach my $categoryid (reverse @{$product_ref->{categories_tags}}) {
		if ((defined $properties{categories}{$categoryid}) and (defined $properties{categories}{$categoryid}{"pnns_group_2:en"})) {
			$product_ref->{pnns_groups_2} = $properties{categories}{$categoryid}{"pnns_group_2:en"};
			$product_ref->{pnns_groups_2_tags} = [get_fileid($product_ref->{pnns_groups_2})];
			last;
		}
	}
	
	if (defined $product_ref->{pnns_groups_2}) {
		if (defined $pnns{$product_ref->{pnns_groups_2}}) {
			$product_ref->{pnns_groups_1} = $pnns{$product_ref->{pnns_groups_2}};
			$product_ref->{pnns_groups_1_tags} = [get_fileid($product_ref->{pnns_groups_1})];
		}
		else {
			$log->warn("no pnns group 1 for pnns group 2", { pnns_group_2 => $product_ref->{pnns_groups_2} }) if $log->is_warn();
		}
	}
	else {
		if (defined $product_ref->{categories}) {
			$product_ref->{pnns_groups_2} = "unknown";
			$product_ref->{pnns_groups_2_tags} = ["unknown"];
			$product_ref->{pnns_groups_1} = "unknown";
			$product_ref->{pnns_groups_1_tags} = ["unknown"];		
		}
	}
	
}



sub fix_salt_equivalent($) {

	my $product_ref = shift;
	
	# salt
	
	foreach my $product_type ("", "_prepared") {
		
		# use the salt value by default
		if ((defined $product_ref->{nutriments}{'salt'} . $product_type) and ($product_ref->{nutriments}{'salt' . $product_type} ne '')) {
			$product_ref->{nutriments}{'sodium' . $product_type} = $product_ref->{nutriments}{'salt' . $product_type} / 2.54;
		}	
		elsif ((defined $product_ref->{nutriments}{'sodium' . $product_type}) and ($product_ref->{nutriments}{'sodium' . $product_type} ne '')) {
			$product_ref->{nutriments}{'salt' . $product_type} = $product_ref->{nutriments}{'sodium' . $product_type} * 2.54;
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
);

	my @fruits_vegetables_nuts_by_category_sorted = sort { $fruits_vegetables_nuts_by_category{$b} <=> $fruits_vegetables_nuts_by_category{$a} } keys %fruits_vegetables_nuts_by_category;


sub compute_nutrition_score($) {

	# compute UK FSA score (also in planned use in France)

	my $product_ref = shift;
	
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
	delete $product_ref->{nutrition_score_warning_no_fruits_vegetables_nuts};

	defined $product_ref->{misc_tags} or $product_ref->{misc_tags} = [];
	
	$product_ref->{misc_tags} = ["en:nutriscore-not-computed"];
	
	my $prepared = '';

	# do not compute a score when we don't have a category
	if ((not defined $product_ref->{categories}) or ($product_ref->{categories} eq '')) {
			$product_ref->{"nutrition_grades_tags"} = [ "not-applicable" ];
			$product_ref->{nutrition_score_debug} = "no score when the product does not have a category";
			return;
	}	
	
	
	# do not compute a score for dehydrated products to be rehydrated (e.g. dried soups, powder milk)
	# unless we have nutrition data for the prepared product
	if (has_tag($product_ref, "categories", "en:dried-products-to-be-rehydrated")) {
	
			if ((defined $product_ref->{nutriments}{"energy_prepared_100g"})) {
				$product_ref->{nutrition_score_debug} = "using prepared product data for en:dried-products-to-be-rehydrated without data for prepared product";
				$prepared = '_prepared';
			}
			else {
				$product_ref->{"nutrition_grades_tags"} = [ "not-applicable" ];
				$product_ref->{nutrition_score_debug} = "no score for en:dried-products-to-be-rehydrated without data for prepared product";
				return;
			}
	}
	
	
	# do not compute a score for coffee, tea etc.
	
	if (defined $options{categories_exempted_from_nutriscore}) {
	
		foreach my $category_id (@{$options{categories_exempted_from_nutriscore}}) {
		
			if (has_tag($product_ref, "categories", $category_id)) {
				$product_ref->{"nutrition_grades_tags"} = [ "not-applicable" ];
				$product_ref->{nutrition_score_debug} = "no nutriscore for category $category_id";
				return;
			}
		}
	}	
	
	# compute the score only if all values are known
	# for fiber, compute score without fiber points if the value is not known
	# foreach my $nid ("energy", "saturated-fat", "sugars", "sodium", "fiber", "proteins") {
	foreach my $nid ("energy", "saturated-fat", "sugars", "sodium", "proteins") {
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
	
	if ($prepared ne '') {
		push @{$product_ref->{misc_tags}}, "en:nutrition-grade-computed-for-prepared-product";
	}
	
	
	my $energy_points = int(($product_ref->{nutriments}{"energy" . $prepared . "_100g"} - 0.00001) / 335);
	$energy_points > 10 and $energy_points = 10;
	
	my $saturated_fat_points = int(($product_ref->{nutriments}{"saturated-fat" . $prepared . "_100g"} - 0.00001) / 1);
	$saturated_fat_points > 10 and $saturated_fat_points = 10;

	my $sugars_points = int(($product_ref->{nutriments}{"sugars" . $prepared . "_100g"} - 0.00001) / 4.5);
	$sugars_points > 10 and $sugars_points = 10;

	my $sodium_points = int(($product_ref->{nutriments}{"sodium" . $prepared . "_100g"} * 1000 - 0.00001) / 90);
	$sodium_points > 10 and $sodium_points = 10;	
	
	my $a_points = $energy_points + $saturated_fat_points + $sugars_points + $sodium_points;
	
# Pour les boissons, les grilles d’attribution des points pour l’énergie et les sucres simples ont été modifiées.
# ATTENTION, le lait, les laits végétaux ne sont pas compris dans le calcul des scores boissons. Ils relèvent du calcul général.

	my $fr_beverages_energy_points = int(($product_ref->{nutriments}{"energy" . $prepared . "_100g"} - 0.00001 + 30) / 30);
	$fr_beverages_energy_points > 10 and $fr_beverages_energy_points = 10;
	
	my $fr_beverages_sugars_points = int(($product_ref->{nutriments}{"sugars" . $prepared . "_100g"} - 0.00001 + 1.5) / 1.5);
	$fr_beverages_sugars_points > 10 and $fr_beverages_sugars_points = 10;	
	
# L’attribution des points pour les sucres prend en compte la présence d’édulcorants, pour lesquels la grille maintient les scores sucres simples à 1 (au lieu de 0).		
	
	# not in new HCSP from 20150625
	#if ((defined $product_ref->{with_sweeteners}) and ($fr_beverages_sugars_points == 0)) {
	#	$fr_beverages_sugars_points = 1;
	#}
	
#Pour les boissons chaudes non sucrées (thé, café), afin de maintenir leur score à 0 (identique à l’eau), le score KJ a été maintenu à 0 si les sucres simples sont à 0.

	#if (has_tag($product_ref, "categories", "en:hot-beverages") and (has_tag($product_ref, "categories", "en:coffees") or has_tag($product_ref, "categories", "en:teas"))) {
	#	if ($product_ref->{nutriments}{"sugars_100g"} == 0) {
	#		$fr_beverages_energy_points = 0;
	#	}
	#}
	
	my $a_points_fr_beverages = $fr_beverages_energy_points + $saturated_fat_points + $fr_beverages_sugars_points + $sodium_points;
	
	# points for fruits, vegetables and nuts
		
	my $fruits = undef;
	if (defined $product_ref->{nutriments}{"fruits-vegetables-nuts" . $prepared . "_100g"}) {
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
			
		if (defined $fruits) {
			$product_ref->{"fruits-vegetables-nuts_100g_estimate"} = $fruits;
		}
		else {
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

	
	my $fruits_points = 0;
	
	if ($fruits > 80) {
		$fruits_points = 5;
	}
	elsif ($fruits > 60) {
		$fruits_points = 2;
	}
	elsif ($fruits > 40) {
		$fruits_points = 1;
	}
	
	# changes to the fiber scale
	my $fiber_points = 0;
	if ($product_ref->{nutriments}{"fiber" . $prepared . "_100g"} > 4.7) {
		$fiber_points = 5;
	}
	elsif ($product_ref->{nutriments}{"fiber" . $prepared . "_100g"} > 3.7) {
		$fiber_points = 4;
	}
	elsif ($product_ref->{nutriments}{"fiber" . $prepared . "_100g"} > 2.8) {
		$fiber_points = 3;
	}
	elsif ($product_ref->{nutriments}{"fiber" . $prepared . "_100g"} > 1.9) {
		$fiber_points = 2;
	}
	elsif ($product_ref->{nutriments}{"fiber" . $prepared . "_100g"} > 0.9) {
		$fiber_points = 1;
	}
	
	my $proteins_points = int(($product_ref->{nutriments}{"proteins" . $prepared . "_100g"} - 0.00001) / 1.6);
	$proteins_points > 5 and $proteins_points = 5;		
	
	

	my $fr_comment = <<COMMENT
1. Les fromages. Comme vous avez dû le constater, dans le calcul du score, si les points A dépassent 11, et si la teneur en 'fruits, légumes et noix' est inférieure à 80%, alors, on ne retranche pas au score les points des protéines.
Pour les fromages, qui ont des teneurs en protéines très importantes, mais qui dépassent très souvent le 11 en score 1, ce calcul est problématique.
Nous proposons donc, pour cette catégorie, de retrancher les points des protéines quel que soit le score A initial. 

2. Les matières grasses (margarine, huiles, crèmes fraiches). Le score tel qu'il est actuellement ne permet pas de différencier les différents types de matières grasses, etant donné qu'elles ont toutes un taux d'acides gras saturés (AGS) au dessus de 10g (soit le seuil maximal).
Dans leur cas, nous proposons un réajustement de la grille des AGS, par un pas ascendant homogène de 4 points, en démarrant un peu plus haut, à 5.
Soit la grille suivante :
0-5 g d'AGS/100g : 0 points
6-9 : 1 point
10-13: 2 points
14-17 : 3 points
18-21: 4 points
22-25 : 5 points
26-29 : 6 points
30-33 : 7 point
34-37 : 8 points
38-41 : 9 points
42 et plus : 10 points

3. Les boissons. Le score tel qu'il est nécessite une modification plus importante, dans la mesure où actuellement, il donne de meilleurs scores aux jus de fruits, et ne différencie pas l'eau des boissons édulcorées. Nous proposons que toutes les boissons autres que l'eau (contenant des sucres ou des édulcorants) soient dans une catégorie supérieure à l'eau (qui est classée verte). Nous ne disposons pour l'instant pas d'adaptations plus précises du score. 	

Nouveaux points: rapport AGS/lipides plutôt que AGS.

Tableau 11 Grille d’attribution des points pour une composante AGS/lipides totaux dans le cas particulier des matières grasses ajoutées
Points Ratio AGS/lipides totaux
0 <10
1 <16
2 <22
3 <28
4 <34
5 <40
6 <46
7 <52
8 <58
9 <64
10 ≥64

COMMENT
;


	my $saturated_fat = $product_ref->{nutriments}{"saturated-fat" . $prepared . "_100g"};
	my $fat = $product_ref->{nutriments}{"fat" . $prepared . "_100g"};
	my $saturated_fat_ratio = 0;
	if ($saturated_fat > 0) {
		if ($fat <= 0) {
			$fat = $saturated_fat;
		}
		$saturated_fat_ratio = $saturated_fat / $fat;
	}
	
	# my $saturated_fat_points_fr_matieres_grasses = int(($product_ref->{nutriments}{"saturated-fat_100g"} - 2.00001) / 4);
	my $saturated_fat_points_fr_matieres_grasses = int(($saturated_fat_ratio * 100 - 4) / 6);
	$saturated_fat_points_fr_matieres_grasses < 0 and $saturated_fat_points_fr_matieres_grasses = 0;
	$saturated_fat_points_fr_matieres_grasses > 10 and $saturated_fat_points_fr_matieres_grasses = 10;
	
	my $a_points_fr_matieres_grasses = $energy_points + $saturated_fat_points_fr_matieres_grasses + $sugars_points + $sodium_points;

	my $a_points_fr = $a_points;
	
	if (has_tag($product_ref, "categories", "en:fats")) {
		$a_points_fr = $a_points_fr_matieres_grasses;
		$product_ref->{nutrition_score_debug} .= " -- in fats category";		
	}

	# Nutriscore: milk and drinkable yogurts are not considered beverages
	
	if (has_tag($product_ref, "categories", "en:beverages")
		and not (has_tag($product_ref, "categories", "en:plant-milks")
			 or has_tag($product_ref, "categories", "en:milks")
			 or has_tag($product_ref, "categories", "en:dairy-drinks")
			 or has_tag($product_ref, "categories", "en:meal-replacement")
			 or has_tag($product_ref, "categories", "en:dairy-drinks-substitutes")
			)) {
		$product_ref->{nutrition_score_debug} .= " -- in beverages category - a_points_fr_beverage: $fr_beverages_energy_points (energy) + $saturated_fat_points (sat_fat) + $fr_beverages_sugars_points (sugars) + $sodium_points (sodium) = $a_points_fr_beverages - ";
		
		$a_points_fr = $a_points_fr_beverages;
	}
	
	my $c_points = $fruits_points + $fiber_points + $proteins_points;
	
	my $fsa_score = $a_points;
	my $fr_score = $a_points_fr;	
	
	#FSA
	
	if ($a_points < 11) {
		$fsa_score -= $c_points;
	}
	elsif ($fruits_points == 5) {
		$fsa_score -= $c_points;
	}
	else {
		$fsa_score -= ($fruits_points + $fiber_points);
	}
	
	# FR
	
	my $fruits_points_fr = $fruits_points;
	if (has_tag($product_ref, "categories", "en:beverages")) {
		$fruits_points_fr = 2 * $fruits_points;
	}
	
	my $c_points_fr = $fruits_points_fr + $fiber_points + $proteins_points;
	
	if ($a_points_fr < 11) {
		$fr_score -= $c_points_fr;
	}
	elsif ($fruits_points == 5) {
		$fr_score -= $c_points_fr;
	}
	else {
		if (has_tag($product_ref, "categories", "en:cheeses")) {
			$fr_score -= $c_points_fr;
			$product_ref->{nutrition_score_debug} .= " -- in cheeses category";
		}
		else {
			$fr_score -= ($fruits_points_fr + $fiber_points);
		}
	}	
	
	$product_ref->{nutriments}{"nutrition-score-uk"} = $fsa_score;
	$product_ref->{nutriments}{"nutrition-score-fr"} = $fr_score;
	
	$product_ref->{nutriments}{"nutrition-score-uk_100g"} = $product_ref->{nutriments}{"nutrition-score-uk"};
	delete $product_ref->{nutriments}{"nutrition-score-uk_serving"};
	$product_ref->{nutriments}{"nutrition-score-fr_100g"} = $product_ref->{nutriments}{"nutrition-score-fr"};
	delete $product_ref->{nutriments}{"nutrition-score-fr_serving"};
	
	$product_ref->{nutrition_score_debug} .= " -- energy $energy_points + sat-fat $saturated_fat_points + fr-sat-fat-for-fats $saturated_fat_points_fr_matieres_grasses + sugars $sugars_points + sodium $sodium_points - fruits $fruits\% $fruits_points - fiber $fiber_points - proteins $proteins_points -- fsa $fsa_score -- fr $fr_score";
	
	
	# Colored grades
	

#Vert : -15 à -2
#Jaune : de -1 à 3
#Orange : de 4 à 11
#Rose : de 12 à 16
#Rouge : 17 et au-delà.

# For beverages:
# -15 to -1
# 0	
# 1
# 2

#  3. Les boissons. Le score tel qu'il est nécessite une modification plus importante, dans la mesure où actuellement,
# il donne de meilleurs scores aux jus de fruits, et ne différencie pas l'eau des boissons édulcorées. 
# Nous proposons que toutes les boissons autres que l'eau (contenant des sucres ou des édulcorants) 
# soient dans une catégorie supérieure à l'eau (qui est classée verte). 
# Nous ne disposons pour l'instant pas d'adaptations plus précises du score.





	delete $product_ref->{"nutrition-grade-fr"};
	delete $product_ref->{"nutrition_grade_fr"};
	
	shift @{$product_ref->{misc_tags}};
	push @{$product_ref->{misc_tags}}, "en:nutriscore-computed";
	
	$product_ref->{"nutrition_grade_fr"} = compute_nutrition_grade($product_ref, $fr_score);
	
	$product_ref->{"nutrition_grades_tags"} = [$product_ref->{"nutrition_grade_fr"}];
	$product_ref->{"nutrition_grades"} = $product_ref->{"nutrition_grade_fr"};  # needed for the /nutrition-grade/unknown query

}


sub compute_nutrition_grade($$) {

	my $product_ref = shift;
	my $fr_score = shift;
	
	my $grade = "";

	if (has_tag($product_ref, "categories", "en:beverages")
		and not (has_tag($product_ref, "categories", "en:plant-milks")
		 or has_tag($product_ref, "categories", "en:milks")
		 or has_tag($product_ref, "categories", "en:dairy-drinks")
	)) {
		
# Tableau 6 : Seuils du score FSA retenus pour les boissons
# Classe du 5-C
# Bornes du score FSA
# A/Vert - Eaux minérales
# B/Jaune Min – 1
# C/Orange 2 – 5
# D/Rose 6 – 9
# E/Rouge 10 – Max		
		
		if (has_tag($product_ref, "categories", "en:mineral-waters")) {  
			$grade = 'a';
		}
		elsif ($fr_score <= 1) {
			$grade = 'b';
		}
		elsif ($fr_score <= 5) {
			$grade = 'c';
		}
		elsif ($fr_score <= 9) {
			$grade = 'd';
		}	
		else {
			$grade = 'e';
		}	
	}
	else {
	
# New grades from HCSP avis 20150602 hcspa20150625_infoqualnutprodalim.pdf
# Tableau 1 : Seuils du score FSA retenus pour le cas général
# Classe du 5-C
# Bornes du score FSA
# A/Vert Min - -1
# B/Jaune 0 – 2
# C/Orange 3 – 10
# D/Rose 11 – 18
# E/Rouge 19 – Max	
	
		if ($fr_score <= -1) {
			$grade = 'a';
		}
		elsif ($fr_score <= 2) {
			$grade = 'b';
		}
		elsif ($fr_score <= 10) {
			$grade = 'c';
		}
		elsif ($fr_score <= 18) {
			$grade = 'd';
		}	
		else {
			$grade = 'e';
		}
	}
}


sub compute_serving_size_data($) {

	my $product_ref = shift;
	
	# identify products that do not have comparable nutrition data
	# e.g. products with multiple nutrition facts tables
	# except in some cases like breakfast cereals
	# bug #1145
	# old
	
	# old fields
	(defined $product_ref->{not_comparable_nutrition_data}) and delete $product_ref->{not_comparable_nutrition_data};
	(defined $product_ref->{multiple_nutrition_data}) and delete $product_ref->{multiple_nutrition_data};

	(defined $product_ref->{product_quantity}) and delete $product_ref->{product_quantity};
	if ((defined $product_ref->{quantity}) and ($product_ref->{quantity} ne "")) {
		my $product_quantity = normalize_quantity($product_ref->{quantity});
		if (defined $product_quantity) {
			$product_ref->{product_quantity} = $product_quantity;
		}
	}
	
	$product_ref->{serving_quantity} = normalize_serving_size($product_ref->{serving_size});
	
	#if ((defined $product_ref->{nutriments}) and (defined $product_ref->{nutriments}{'energy.unit'}) and ($product_ref->{nutriments}{'energy.unit'} eq 'kcal')) {
	#	$product_ref->{nutriments}{energy} = sprintf("%.0f", $product_ref->{nutriments}{energy} * 4.18);
	#	$product_ref->{nutriments}{'energy.unit'} = 'kj';
	#}
	
	foreach my $product_type ("", "_prepared") {
	
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
				$product_ref->{nutriments}{$nid . $product_type . "_100g"} = '';
			
				if (($nid eq 'alcohol') or ((exists $Nutriments{$nid}) and (exists $Nutriments{$nid}{unit})
					and (($Nutriments{$nid}{unit} eq '') or ($Nutriments{$nid}{unit} eq '%')))) {
					$product_ref->{nutriments}{$nid . $product_type . "_100g"} = $product_ref->{nutriments}{$nid . $product_type} + 0.0;
				}
				elsif ($product_ref->{serving_quantity} > 0) {
					
					$product_ref->{nutriments}{$nid . $product_type . "_100g"} = sprintf("%.2e",$product_ref->{nutriments}{$nid . $product_type} * 100.0 / $product_ref->{serving_quantity}) + 0.0;
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
				$product_ref->{nutriments}{$nid . $product_type . "_serving"} = '';
				
				if (($nid eq 'alcohol') or ((exists $Nutriments{$nid . $product_type}) and (exists $Nutriments{$nid . $product_type}{unit})
					and (($Nutriments{$nid}{unit} eq '') or ($Nutriments{$nid}{unit} eq '%')))) {
					$product_ref->{nutriments}{$nid . $product_type . "_serving"} = $product_ref->{nutriments}{$nid . $product_type} + 0.0;
				}			
				elsif ($product_ref->{serving_quantity} > 0) {
				
					$product_ref->{nutriments}{$nid . $product_type . "_serving"} = sprintf("%.2e",$product_ref->{nutriments}{$nid . $product_type} / 100.0 * $product_ref->{serving_quantity}) + 0.0;
				}
				
			}	
		
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
	
	return if ($product_ref->{categories} eq '');	# need categories hierarchy in order to identify drinks
		
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
			# push @{$product_ref->{nutrient_levels_tags}}, get_fileid(sprintf(lang("nutrient_in_quantity"), $Nutriments{$nid}{$lc}, lang($product_ref->{nutrient_levels}{$nid} . "_quantity")));
			push @{$product_ref->{nutrient_levels_tags}}, 'en:' . get_fileid(sprintf($Lang{nutrient_in_quantity}{en}, $Nutriments{$nid}{en}, $Lang{$product_ref->{nutrient_levels}{$nid} . "_quantity"}{en}));
		
		}
		else {
			delete $product_ref->{nutrient_levels}{$nid};
		}
			#$product_ref->{nutrient_levels_debug} .= " -- nid: $nid - low: $low - high: $high - level: " . $product_ref->{nutrient_levels}{$nid} . " -- value: " . $product_ref->{nutriments}{$nid . "_100g"} . " --- ";
		
	}
	
}

# Create food taxonomy
# runs once at module initialization

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
		return "$countrycode $code1.$code2/$code3 CE";
	};	

	my $normalize_ce_code = sub ($$) {
		my $countrycode = shift;
		my $code = shift;
		$countrycode = uc($countrycode);
		$code = uc($code);
		return "$countrycode $code EC";
	};		
	
	# CE codes -- FR 67.145.01 CE
	#$codes =~ s/(^|,|, )(fr)(\s|-|_|\.)?((\d|\.|_|\s|-)+)(\.|_|\s|-)?(ce)?\b/$1 . $normalize_fr_ce_code->($2,$4)/ieg;	 # without CE, only for FR
	$codes =~ s/(^|,|, )(fr)(\s|-|_|\.)?((\d|\.|_|\s|-)+?)(\.|_|\s|-)?(ce|eec|ec|eg)\b/$1 . $normalize_fr_ce_code->($2,$4)/ieg;	
	
	$codes =~ s/(^|,|, )(uk)(\s|-|_|\.)?((\w|\.|_|\s|-)+?)(\.|_|\s|-)?(ce|eec|ec|eg)\b/$1 . $normalize_uk_ce_code->($2,$4)/ieg;	
	$codes =~ s/(^|,|, )(uk)(\s|-|_|\.|\/)*((\w|\.|_|\s|-|\/)+?)(\.|_|\s|-)?(ce|eec|ec|eg)\b/$1 . $normalize_uk_ce_code->($2,$4)/ieg;	
	
	# NO-RGSEAA-21-21552-SE -> ES 21.21552/SE
	
	
	$codes =~ s/(^|,|, )n(o|°|º)?(\s|-|_|\.)?rgseaa(\s|-|_|\.|:|;)*(\d\d)(\s|-|_|\.)?(\d+)(\s|-|_|\.|\/|\\)?(\w+)\b/$1 . $normalize_es_ce_code->('es',$5,$7,$9)/ieg;
	$codes =~ s/(^|,|, )(es)(\s|-|_|\.)?(\d\d)(\s|-|_|\.|:|;)*(\d+)(\s|-|_|\.|\/|\\)?(\w+)(\.|_|\s|-)?(ce|eec|ec|eg)?\b/$1 . $normalize_es_ce_code->('es',$4,$6,$8)/ieg;
	
	$codes =~ s/(^|,|, )(\w\w)(\s|-|_|\.|\/)*((\w|\.|_|\s|-|\/)+?)(\.|_|\s|-)?(ce|eec|ec|eg|we)\b/$1 . $normalize_ce_code->($2,$4)/ieg;	
	
	return $codes;
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
	$canon_local_authority = get_fileid($canon_local_authority);	
	
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
		
	# do not compute a score when we don't have ingredients
	if ((not defined $product_ref->{ingredients_text}) or ($product_ref->{ingredients_text} eq '')) {
			$product_ref->{nova_group_tags} = [ "not-applicable" ];
			$product_ref->{nova_group_debug} = "no nova group when the product does not have ingredients";
			return;
	}		
	
	# do not compute a score when we don't have a category
	if ((not defined $product_ref->{categories}) or ($product_ref->{categories} eq '')) {
			$product_ref->{nova_group_tags} = [ "not-applicable" ];
			$product_ref->{nova_group_debug} = "no nova group when the product does not have a category";
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
	
	
	
	$product_ref->{nutriments}{"nova-group"} = $product_ref->{nova_group};
	$product_ref->{nutriments}{"nova-group_100g"} = $product_ref->{nova_group};
	$product_ref->{nutriments}{"nova-group_serving"} = $product_ref->{nova_group};
	
	$product_ref->{nova_groups} = $product_ref->{nova_group};	
	$product_ref->{nova_groups_tags} = [ canonicalize_taxonomy_tag("en", "nova_groups", $product_ref->{nova_group}) ];
	

}





1;

