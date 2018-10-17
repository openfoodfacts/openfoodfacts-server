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
	fr => "Alcool",
	en => "Alcohol",
	es => "Alcohol",
	ar=> "الكحوليات",
	unit => '% vol',
	it => "Alcol",
	pt => "Álcool",
	de => "Alkohol",
	he => "אלכוהול",
	ga => "Alcól",
	da => "Alkohol",
	el => "Αλκοόλη",
	fi => "Alkoholi",
	nl => "Alcohol",
	nl_be => "Alcohol",
	sv => "Alkohol",
	lv => "spirts",
	cs => "Alkohol",
	et => "Alkohol",
	hu => "Alkohol",
	pl => "Alkohol",
	sl => "Alkohol",
	lt => "Alkoholis",
	mt => "Alkoħol",
	sk => "Alkohol",
	ro => "Alcool",
	bg => "Алкохол",
	zh => "酒精度",
},
energy	=> {
	fr => "Énergie",
	fr_synonyms => ["valeurs énergétique", "valeur énergétique"],
	en => "Energy",
	es => "Energía",
	ar => "الطاقه",
	it => "Energia",
	pt => "Energia",
	de => "Energie",
	he => "אנרגיה - קלוריות",
	ga => "Fuinneamh",
	da => "Energi",
	el => "Ενέργεια",
	fi => "Energiav",
	nl => "Energie",
	nl_be => "Energie",
	sv => "Energi",
	lv => "Enerģētiskā vērtība",
	cs => "Energetická hodnota",
	et => "Energia",
	hu => "Energia",
	pl => "Wartość energetyczna",
	sl => "Energijska vrednost",
	lt => "Energinė vertė",
	mt => "Enerġija",
	sk => "Energetická hodnota",
	ro => "Valoarea energetică",
	bg => "Енергийна стойност",
	zh => "能量",
	ja => "エネルギー",
	
	unit => 'kj',
	unit_us => 'kcal',
	unit_ca => 'kcal',	
},
"energy-from-fat"	=> {
	fr => "Énergie provenant des graisses",
	en => "Energy from fat",
	
	unit => 'kj',
	unit_us => 'kcal',
	unit_ca => 'kcal',	
},
proteins => {
	fr => "Protéines",
	en => "Proteins",
	es => "Proteínas",
	ar => "البروتين",
	it => "Proteine",
	pt => "Proteínas",
	he => "חלבונים",
	ga => "Próitéin",
	de => "Eiweiß",
	da => "Protein",
	el => "Πρωτεΐνες",
	fi => "Proteiini",
	nl => "Eiwitten",
	nl_be => "Eiwitten",
	sv => "Protein",
	lv => "Olbaltumvielas",
	cs => "Bílkoviny",
	et => "Valgud",
	hu => "Fehérje",
	pl => "Białko",
	sl => "Beljakovine",
	lt => "Baltymai",
	mt => "Proteini",
	sk => "Bielkoviny",
	ro => "Proteine",
	bg => "Белтъци",
	zh => "蛋白质",
	ja => "たんぱく質",       
},
casein => {
pl => 'Kazeina',
eu => 'Kaseina',
he => 'קזאין',
fr => 'Caséine',
ko => '카세인',
es => 'Caseína',
it => 'Caseina',
de => 'Casein',
ja => 'カゼイン',
nl => 'Caseïne',
nl_be => 'Caseïne',
sv => 'Kasein',
ar => 'كازين',
pt => 'Caseína',
ru => 'Казеин',
hy => 'Կազեին',
sr_el => 'Kazein',
sr_ec => 'Казеин',
en => 'casein',
tr => 'Kazein',
ro => 'Cazeină',
ca => 'Caseïna',
fi => 'Kaseiini',
uk => 'Казеїн',
cy => 'Casein',
sl => 'Kazein',
nn => 'Kasein',
cs => 'Kasein',
io => 'Kazeino',
fa => 'کازئین',
da => 'Kasein',
kk_arab => 'كازەىين',
kk_cn => 'كازەىين',
kk_tr => 'Kazeïn',
kk_kz => 'Казеин',
kk_cyrl => 'Казеин',
kk_latn => 'Kazeïn',
kk => 'Казеин',
sr => 'казеин',
eo => 'Kazeino',
gl => 'Caseína',
be => 'Казеін',
nb => 'Kasein',
hu => 'Kazein',
sco => 'casein',
zh => '酪蛋白',
bg => 'Казеин',
id => 'Kasein',
ga => 'Cáiséin',
sh => 'Kazein',
scn => 'Caseina',
gsw => 'Casein',
},

nucleotides => {
	fr => 'Nucléotides',
	en => 'Nucleotides',
	nl => 'Nucleotiden',
	nl_be => 'Nucleotiden',
	el => "Νουκλεοτίδια",

},
"serum-proteins" => {
	fr => "Protéines sériques",
	en => "Serum proteins",
	nl => 'Plasmaproteïnen',
	nl_be => 'Plasmaproteïnen',
	el => "Πρωτεΐνες ορού",
},
carbohydrates => {
	fr => "Glucides",
	en => "Carbohydrate",
	es => "Hidratos de carbono",
	ar => "الكاربوهايدريد",
	it => "Carboidrati",
	pt => "Carboidratos",
	pt_pt => "Hidratos de carbono",
	de => "Kohlenhydrate",
	he => "פחמימות",
	ga => "Carbaihiodráit",
	da => "Kulhydrat",
	el => "Υδατάνθρακες",
	fi => "Hiilihydraatti",
	nl => "Koolhydraten",
	nl_be => "Koolhydraten",
	sv => "Kolhydrat",
	lv => "Ogļhidrāti",
	cs => "Sacharidy",
	et => "Süsivesikud",
	hu => "Szénhidrát",
	pl => "Węglowodany",
	sl => "Ogljikove hidrate",
	lt => "Angliavandeniai",
	mt => "Karboidrati",
	sk => "Sacharidy",
	ro => "gGlucide",
	bg => "Въглехидрати",
	zh => "碳水化合物",
	ja => "炭水化物",
},
sugars => {
	fr => "Sucres",
	fr_synonyms => ["sucre"],
	en => "Sugars",
	ja => "糖類",
	es => "Azúcares",
	ar => "السكر",
	it => "Zuccheri",
	pt => "Açúcares",
	de => "Zucker",
	he => "סוכר",
	ga => "Siúcraí",
	da => "Sukkerarter",
	el => "Σάκχαρα",
	fi => "Sokerit",
	nl => "Suikers",
	nl_be => "Suikers",
	sv => "Sockerarter",
	lv => "Cukuri",
	cs => "Cukryv",
	et => "Suhkrud",
	hu => "Cukrok",
	pl => "Cukry",
	sl => "Sladkorjev",
	lt => "Cukrūs",
	mt => "Zokkor",
	sk => "Cukry",
	ro => "Zaharuri",
	bg => "Захари",
	zh => "糖",
},
sucrose => {
	fr => 'Saccharose',
	en => 'Sucrose',
	es => 'Sacarosa',
	el => "Σουκρόζη",
	pt => 'Sacarose',
	he => 'סוכרוז',
	de => 'Saccharose',
	nl => 'Sucrose',
	nl_be => 'Sucrose',
},
glucose => {
	fr => 'Glucose',
	en => 'Glucose',
	el => "Γλυκόζη",
	pt => 'Glucose',
	es => 'Glucosa',
	he => 'גלוקוז',
	de => 'Traubenzucker',
	nl => 'Glucose',
	nl_be => 'Glucose',
},
fructose => {
	fr => 'Fructose',
	pt => 'Frutose',
	en => 'Fructose',
	es => 'Fructosa',
	el => "Φρουκτόζη",
	he => 'פרוקטוז',
	de => 'Fruchtzucker',
	nl => 'Fructose',
	nl_be => 'Fructose',

},
lactose => {
	fr => 'Lactose',
	en => 'Lactose',
	pt => 'Lactose',
	es => 'Lactosa',
	el => "Λακτόζη",
	he => 'לקטוז',
	de => 'Laktose',
	nl => 'Lactose',
	nl_be => 'Lactose',

},
maltose => {
	fr => 'Maltose',
	en => 'Maltose',
	el => "Μαλτόζη",
	pt => 'Maltose',
	es => 'Maltosa',
	he => 'מלטוז',
	de => 'Malzzucker',
	nl => 'Maltose',
	nl_be => 'Maltose',

},
maltodextrins => {
	fr => 'Maltodextrines',
	en => 'Maltodextrins',
	pt => 'Maltodextrinas',
	es => 'Maltodextrinas',
	el => "Μαλτοδεξτρίνες",
	he => 'מלטודקסטרינים',
	nl => 'Maltodextrine',
	nl_be => 'Maltodextrine',
},
starch => {
	fr => "Amidon",
	en => "Starch",
	es => "Almidón",
	it => "Amido",
	pt => "Amido",
	de => "Stärke",
	he => "עמילן",
	ga => "Stáirse",
	da => "Stivelse",
	el => "Άμυλο",
	fi => "Tärkkelys",
	nl => "Zetmeel",
	nl_be => "Zetmeel",
	sv => "Stärkelse",
	lv => "Ciete",
	cs => "Škrob",
	et => "Tärklis",
	hu => "Keményítő",
	pl => "Skrobia",
	sl => "Škroba",
	lt => "Krakmolo",
	mt => "Lamtu",
	sk => "Škrob",
	ro => "Amidon",
	bg => "Скорбяла",
},
polyols => {
	fr => "Polyols",
	en => "Sugar alcohols (Polyols)",
	es => "Azúcares alcohólicos (Polialcoholes)",
	it => "Polialcoli/polioli (alcoli degli zuccheri)",
	de => "mehrwertige Alkohole (Polyole)",
	pt => "Açúcares alcoólicos (poliálcools, polióis)",
	he => "סוכר אלכוהולי (פוליאול)",
	ga => "Polóil",
	da => "Polyoler",
	el => "Πολυόλες",
	fi => "Polyolit",
	nl => "Polyolen",
	nl_be => "Polyolen",
	sv => "Polyoler",
	lv => "Polioli",
	cs => "Polyalkoholy",
	et => "Polüoolid",
	hu => "Poliolok",
	pl => "Alkohole wielowodorotlenowe",
	sl => "Poliolov",
	lt => "Poliolių",
	mt => "Polioli",
	sk => "Alkoholické cukry (polyoly)",
	ro => "Polioli",
	bg => "Полиоли",
}, 
fat => {
	fr => "Matières grasses / Lipides",
	fr_synonyms => ["Matières grasses", "Matière grasse", "Lipides", "Graisses", "Graisse"],
	en => "Fat",
	ja => "脂質",
	es => "Grasas",
	ar=> "الدهون",
	it => "Grassi",
	pt => "Gorduras",
	pt_pt => "Lípidos",
	de => "Fett",
	he => "שומנים",
	ga => "Saill",
	da => "Fedt",
	el => "Λιπαρά",
	fi => "Rasva",
	nl => "Vetten",
	nl_be => "Vetten",
	sv => "Fett",
	lv => "Tauki",
	cs => "Tuky",
	et => "Rasvad",
	hu => "Zsír",
	pl => "Tłuszcz",
	sl => "Maščobe",
	lt => "Riebalai",
	mt => "Xaħmijiet",
	sk => "Tuky",
	ro => "Grăsimi",
	bg => "Мазнини",
	zh => "脂肪",
},
'saturated-fat' => {
	fr => "Acides gras saturés",
	fr_synonyms => ["Saturés", "AGS"],
	en => "Saturated fat",
	es => "Grasas saturadas",
	it =>"Acidi Grassi saturi",
	pt => "Gorduras saturadas",
	pt_pt => "Ácidos gordos saturados",
	de => "gesättigte Fettsäuren",
	he => "שומן רווי",
	ga => "sáSitheáin saill",
	da => "Mættede fedtsyrer",
	el => "Κορεσμένα λιπαρά",
	es => "Ácidos grasos saturados",
	fi => "Tyydyttyneet rasvat",
	nl => "Verzadigde vetzuren",
	nl_be => "Verzadigde vetzuren",
	sv => "Mättat fett",
	lv => "Piesātinātās taukskābes",
	cs => "Nasycené mastné kyseliny",
	et => "Küllastunud rasvhapped",
	hu => "Telített zsírsavak",
	pl => "Kwasy tłuszczowe nasycone",
	sl => "Nasičene maščobe",
	lt => "Sočiosios riebalų rūgštys",
	mt => "Saturati xaħmijiet",
	sk => "Nasýtené mastné kyseliny",
	ro => "Acizi grași saturați",
	bg => "Наситени мастни киселини",
	zh => "饱和脂肪",
},
'butyric-acid' => {
	en => 'Butyric acid (4:0)',
	es => 'Ácido butírico (4:0)',
	el => "Βουτυρικό οξύ (4:0)",
	pt => 'Ácido butírico (4:0)',
	fr => 'Acide butyrique (4:0)',
	he => 'חומצה בוטירית (4:0)',
	nl => 'Boterzuur (4:0)',
	nl_be => 'Boterzuur (4:0)',
},
'caproic-acid' => {
	en => 'Caproic acid (6:0)',
	es => 'Ácido caproico (6:0)',
	el => "Καπροϊκό οκύ (6:0)",
	pt => 'Ácido capróico (6:0)',
	fr => 'Acide caproïque (6:0)',
	he => 'חומצה קפרואית (6:0)',
	nl => 'Capronzuur (6:0)',
	nl_be => 'Capronzuur (6:0)',
},
'caprylic-acid' => {
	en => 'Caprylic acid (8:0)',
	es => 'Ácido caprílico (8:0)',
	el => 'Καπρυλικό οξύ (8:0)',
	pt => 'Ácido caprílico (8:0)',
	fr => 'Acide caproïque (8:0)',
	he => 'חומצה קפרילית (8:0)',
	nl => 'Octaanzuur (8:0)',
	nl_be => 'Octaanzuur (8:0)',
},
'capric-acid' => {
	en => 'Capric acid (10:0)',
	es => 'Ácido cáprico (10:0)',
	el => 'Καπρικό οξύ (10:0)',
	pt => 'Ácido cáprico (10:0)',
	fr => 'Acide caprique (10:0)',
	he => 'חומצה קפרית (10:0)',
	nl => 'Decaanzuur (10:0)',
	nl_be => 'Decaanzuur (10:0)',
},
'lauric-acid' => {
	en => 'Lauric acid (12:0)',
	es => 'Ácido láurico (12:0)',
	el => "Λαυρικό οξύ/n-δωδεκανοϊκό οξύ (12:0)",
	pt => 'Ácido láurico (12:0)',
	fr => 'Acide laurique (12:0)',
	he => 'חומצה לאורית (12:0)',
	nl => 'Laurinezuur (12:0)',
	nl_be => 'Laurinezuur (12:0)',
},
'myristic-acid' => {
	en => 'Myristic acid (14:0)',
	es => 'Ácido mirístico (14:0)',
	el => "Μυριστικό οξύ (14:0)",
	pt => 'Ácido mirístico (14:0)',
	fr => 'Acide myristique (14:0)',
	he => 'חומצה מיריסטית (14:0)',
	nl => 'Myristinezuur (14:0)',
},
'palmitic-acid' => {
	en => 'Palmitic acid (16:0)',
	es => 'Ácido palmítico (16:0)',
	el => "Παλμιτικό οξύ (16:0)",
	pt => 'Ácido palmítico (16:0)',
	fr => 'Acide palmitique (16:0)',
	he => 'חומצה פלמיטית (16:0)',
	nl => 'Palmitinezuur (16:0)',
	nl_be => 'Palmitinezuur (16:0)',
},
'stearic-acid' => {
	en => 'Stearic acid (18:0)',
	es => 'Ácido esteárico (18:0)',
	pt => 'Ácido esteárico (18:0)',
	el => "Στεατικό/Στεαρικό οξύ (18:0)",
	fr => 'Acide stéarique (18:0)',
	he => 'חומצה סטארית (18:0)',
	nl => 'Stearinezuur (18:0)',
	nl_be => 'Stearinezuur (18:0)',
},
'arachidic-acid' => {
	en => 'Arachidic acid (20:0)',
	es => 'Ácido araquídico (20:0)',
	el => 'Αραχιδικό οξύ (20:0)',
	pt => 'Ácido araquídico (20:0)',
	fr => 'Acide arachidique / acide eicosanoïque (20:0)',
	nl => 'Arachidinezuur (20:0)',
	nl_be => 'Arachidinezuur (20:0)',
},
'behenic-acid' => {
	en => 'Behenic acid (22:0)',
	es => 'Ácido behénico (22:0)',
	el => 'Βεχενικό οξύ/εικοσαδυενοϊκό οξύ (22:0)',
	pt => 'Ácido beénico (22:0)',
	fr => 'Acide béhénique (22:0)',
	he => 'חומצה בהנית (22:0)',
	nl => 'Beheenzuur (22:0)',
	nl_be => 'Beheenzuur (22:0)',
},
'lignoceric-acid' => {
	en => 'Lignoceric acid (24:0)',
	es => 'Ácido lignocérico (24:0)',
	el => 'Λιγνοκηρικό οξύ (24:0)',
	pt => 'Ácido lignocérico (24:0)',
	fr => 'Acide lignocérique (24:0)',
	nl => 'Lignocerinezuur (24:0)',
	nl_be => 'Lignocerinezuur (24:0)',
},
'cerotic-acid' => {
	en => 'Cerotic acid (26:0)',
	es => 'Ácido cerótico (26:0)',
	el => 'Κηροτικό οξύ (26:0)',
	pt => 'Ácido cerótico (26:0)',
	fr => 'Acide cérotique (26:0)',
	nl => 'Cerotinezuur (26:0)',
	nl_be => 'Cerotinezuur (26:0)',
},
'montanic-acid' => {
	en => 'Montanic acid (28:0)',
	es => 'Ácido montánico (28:0)',
	el => 'Μοντανικό οξύ (28:0)',
	pt => 'Ácido montânico (28:0)',
	fr => 'Acide montanique (28:0)',
	nl => 'Montaanzuur (28:0)',
	nl_be => 'Montaanzuur (28:0)',
},
'melissic-acid' => {
	en => 'Melissic acid (30:0)',
	es => 'Ácido melísico (30:0)',
	el => 'Μελισσικό οξύ (30:0)',
	pt => 'Ácido melíssico (30:0)',
	fr => 'Acide mélissique (30:0)',
	nl => 'Melissinezuur (30:0)',
	nl_be => 'Melissinezuur (30:0)',
},
'monounsaturated-fat' => {
	fr => "Acides gras monoinsaturés",
	fr_synonyms => ["Acides gras mono-insaturés"],
	en => "Monounsaturated fat",
	es => "Grasas monoinsaturadas",
	it=> "Acidi grassi monoinsaturi", 
	pt => "Gorduras monoinsaturadas",
	pt_pt => "Ácidos gordos monoinsaturados",
	de => "Einfach ungesättigte Fettsäuren",
	he => "שומן חד בלתי רווי",
	ga => "Monai-neamhsháitheáin saill",
	da => "Enkeltumættede fedtsyrer",
	el => "Μονοακόρεστα λιπαρά",
	fi => "Kertatyydyttymättömät rasvat",
	nl => "Enkelvoudig onverzadigde vetzuren",
	nl_be => "Enkelvoudig onverzadigde vetzuren",
	sv => "Enkelomättat fett",
	lv => "Mononepiesātinātās taukskābes",
	cs => "Mononenasycené mastné kyseliny",
	et => "Monoküllastumata rasvhapped",
	hu => "Egyszeresen telítetlen zsírsavak",
	pl => "Kwasy tłuszczowe jednonienasycone",
	sl => "Enkrat nenasičene maščobe",
	lt => "Mononesočiosios riebalų rūgštys",
	mt => "Mono-insaturati xaħmijiet",
	sk => "Mononenasýtené mastné kyseliny",
	ro => "Acizi grași mononesaturați",
	bg => "Мононенаситени мастни киселини",
},
'omega-9-fat' => {
	fr => "Acides gras Oméga 9",
	fr_synonyms => ["Oméga 9"],
	en => "Omega 9 fatty acids",
	es => "Ácidos grasos Omega 9",
	el => 'Ωμέγα-9 λιπαρά',
	it=> "Acidi grassi Omega 9",
	pt => "Ácidos Graxos Ômega 9",
	pt_pt => "Ácidos gordos Ómega 9",
	de => "Omega-9-Fettsäuren",
	he => "אומגה 9",
	nl => "Omega 9 vetzuren",
	nl_be => "Omega 9 vetzuren",
},
'oleic-acid' => {
	en => 'Oleic acid (18:1 n-9)',
	es => 'Ácido oleico (18:1 n-9)',
	el => 'Ολεϊκό οξύ (18:1 n-9)',
	pt => 'Ácido oleico (18:1 n-9)',
	fr => 'Acide oléique (18:1 n-9)',
	he => 'חומצה אולאית',
	nl => 'Oliezuur (18:1 n-9)',
	nl_be => 'Oliezuur (18:1 n-9)',
},
'elaidic-acid' => {
	en => 'Elaidic acid (18:1 n-9)',
	es => 'Ácido elaídico (18:1 n-9)',
	el => 'Ελαϊδικό οξύ (18:1 n-9)',
	pt => 'Ácido elaídico (18:1 n-9)',
	fr => 'Acide élaïdique (18:1 n-9)',
	nl => 'Elaïdinezuur (18:1 n-9)',
	nl_be => 'Elaïdinezuur (18:1 n-9)',
},
'gondoic-acid' => {
	en => 'Gondoic acid (20:1 n-9)',
	es => 'Ácido gondoico (20:1 n-9)',
	el => 'Γονδοϊκό οξύ (20:1 n-9)',
	pt => 'Ácido gondoico (20:1 n-9)',
	fr => 'Acide gadoléique (20:1 n-9)',
	nl => 'Eicoseenzuur (20:1 n-9)',
	nl_be => 'Eicoseenzuur (20:1 n-9)',
},
'mead-acid' => {
	en => 'Mead acid (20:3 n-9)',
	es => 'Ácido Mead (20:3 n-9)',
	el => 'Οξύ Mead (20:3 n-9)',
	pt => 'Ácido de Mead (20:3 n-9)',
	fr => 'Acide de Mead (20:3 n-9)',
	nl => 'Meadzuur (20:3 n-9)',
	nl_be => 'Meadzuur (20:3 n-9)',
},
'erucic-acid' => {
	en => 'Erucic acid (22:1 n-9)',
	es => 'Ácido erúcico (22:1 n-9)',
	el => 'Ερουκικό οξύ (22:1 n-9)',
	pt => 'Ácido erúcico (22:1 n-9)',
	fr => 'Acide érucique (22:1 n-9)',
	nl => 'Erucazuur (22:1 n-9)',
	nl_be => 'Erucazuur (22:1 n-9)',
},
'nervonic-acid' => {
	en => 'Nervonic acid (24:1 n-9)',
	es => 'Ácido nervónico (24:1 n-9)',
	el => 'Νερβονικό (24:1 n-9)',
	pt => 'Ácido nervônico (24:1 n-9)',
	pt_pt => 'Ácido nervónico (24:1 n-9)',
	fr => 'Acide nervonique (24:1 n-9)',
	nl => 'Nervonzuur (24:1 n-9)',
	nl_be => 'Nervonzuur (24:1 n-9)',
},
'polyunsaturated-fat' => {
	fr => "Acides gras polyinsaturés",
	fr_synonyms => ["Acides gras poly-insaturés"],
	en => "Polyunsaturated fat",
	es => "Grasas poliinsaturadas",
	it => "Acidi grassi polinsaturi",
	pt => "Gorduras poli-insaturadas",
	pt_pt => "Ácidos gordos polinsaturados",
	de => "Mehrfach ungesättigte Fettsäuren",
	he => "שומן רב בלתי רווי",
	ga => "Pola-neamhsháitheáin saill",
	da => "Flerumættede fedtsyrer",
	el => "Πολυακόρεστα λιπαρά",
	fi => "Monityydyttymättömät rasvat",
	nl => "Meervoudig onverzadigde vetzuren",
	nl_be => "Meervoudig onverzadigde vetzuren",
	sv => "Fleromättat fett",
	lv => "Polinepiesātinātās taukskābes",
	cs => "Polynenasycené mastné kyseliny",
	et => "Polüküllastumata rasvhapped",
	hu => "Többszörösen telítetlen zsírsavak",
	pl => "Kwasy tłuszczowe wielonienasycone",
	sl => "Večkrat nenasičene maščobe",
	lt => "Polinesočiosios riebalų rūgštys",
	mt => "Poli-insaturati xaħmijiet",
	sk => "Polynenasýtené mastné kyseliny",
	ro => "Acizi grași polinesaturați",
	bg => "Полиненаситени мастни киселини",
},
'omega-3-fat' => {
	fr => "Acides gras Oméga 3",
	fr_synonyms => ["Oméga 3"],
	en => "Omega 3 fatty acids",
	es => "Ácidos grasos Omega 3",
	el => 'Ωμέγα-3 λιπαρά',
	it=> "Acidi grassi Omega 3",
	pt => "Ácidos graxos Ômega 3",
	pt_pt => "Ácidos gordos Ómega 3",
	de => "Omega-3-Fettsäuren",
	he => "אומגה 3",
	nl => "Omega 3-vetzuren",
	nl_be => "Omega 3-vetzuren",
},
'alpha-linolenic-acid' => {
	en => 'Alpha-linolenic acid / ALA (18:3 n-3)',
	es => 'Ácido alfa-linolénico / ALA (18:3 n-3)',
	el => 'Α-λινολενικό οξύ/ ALA (18:3 n-3)',
	pt => 'Ácido alfa-linolênico / ALA (18:3 n-3)',
	pt_pt => 'Ácido alfa-linolénico / ALA (18:3 n-3)',
	fr => 'Acide alpha-linolénique / ALA (18:3 n-3)',
	nl => 'Alfa-linoleenzuur / ALA (18:3 n-3)',
	nl_be => 'Alfa-linoleenzuur / ALA (18:3 n-3)',
},
'eicosapentaenoic-acid' => {
	en => 'Eicosapentaenoic acid / EPA (20:5 n-3)',
	es => 'Ácido eicosapentaenoico / EPA (20:5 n-3)',
	el => 'Εικοσιπεντανοϊκο οξύ / EPA (20:5 n-3)',
	pt => 'Ácido eicosapentaenóico / EPA (20:5 n-3)',
	fr => 'Acide eicosapentaénoïque / EPA (20:5 n-3)',
	fr_synonyms => ["Oméga 3 EPA"],
	nl => 'Eicosapentaeenzuur / EPA (20:5 n-3)',
	nl_be => 'Eicosapentaeenzuur / EPA (20:5 n-3)',
},
'docosahexaenoic-acid' => {
	en => 'Docosahexaenoic acid / DHA (22:6 n-3)',
	es => 'Ácido docosahexaenoico / DHA (22:6 n-3)',
	el => 'Δοκοσαεξανοϊκο οξύ / DHA (22:6 n-3)',
	pt => 'Ácido docosa-hexaenóico / DHA (22:6 n-3)',
	fr => 'Acide docosahexaénoïque / DHA (22:6 n-3)',
	fr_synonyms => ["Oméga 3 DHA"],
	nl => 'Docosahexaeenzuur / DHA (22:6 n-3)',
	nl_be => 'Docosahexaeenzuur / DHA (22:6 n-3)',
},
'omega-6-fat' => {
	fr => "Acides gras Oméga 6",
	fr_synonyms => ["Oméga 6"],
	en => "Omega 6 fatty acids",
	es => "Ácidos grasos Omega 6",
	el => "Ωμέγα-6 λιπαρά",
	it=> "Acidi grassi Omega 6",
	pt => "Ácidos Graxos Ômega 6",
	pt_pt => "Ácidos gordos Ómega 6",
	de => "Omega-6-Fettsäuren",
	he => "אומגה 6",
	nl => 'Omega 6-vetzuren',
	nl_be => 'Omega 6-vetzuren',
},
'linoleic-acid' => {
	en => 'Linoleic acid / LA (18:2 n-6)',
	es => 'Ácido linoleico / LA (18:2 n-6)',
	el => 'Λινολεϊκό οξύ / LA (18:2 n-6)',
	pt => 'Ácido linoleico / LA (18:2 n-6)',
	fr => 'Acide linoléique / LA (18:2 n-6)',
	nl => 'Linolzuur / LA (18:2 n-6)',
	nl_be => 'Linolzuur / LA (18:2 n-6)',
},
'arachidonic-acid' => {
	en => 'Arachidonic acid / AA / ARA (20:4 n-6)',
	es => 'Ácido araquidónico / AA / ARA (20:4 n-6)',
	el => 'Αραχιδονικό οξύ / AA / ARA (20:4 n-6)',
	pt => 'Ácido araquidônico / AA / ARA (20:4 n-6)',
	pt_pt => 'Ácido araquidónico / AA / ARA (20:4 n-6)',
	fr => 'Acide arachidonique / AA / ARA (20:4 n-6)',
	he => 'חומצה ארכידונית / AA / ARA (20:4 n-6)',
	nl => 'Arachidonzuur / AA / ARA (20:4 n-6)',
	nl_be => 'Arachidonzuur / AA / ARA (20:4 n-6)',
},
'gamma-linolenic-acid' => {
	en => 'Gamma-linolenic acid / GLA (18:3 n-6)',
	es => 'Ácido gamma-linolénico / GLA (18:3 n-6)',
	el => 'Γ-λινολενικό οξύ / GLA (18:3 n-6)',
	pt => 'Ácido gama-linolênico / GLA (18:3 n-6)',
	pt_pt => 'Ácido gama-linolénico / GLA (18:3 n-6)',
	fr => 'Acide gamma-linolénique / GLA (18:3 n-6)',
	nl => 'Gamma-linoleenzuur / GLA (18:3 n-6)',
	nl_be => 'Gamma-linoleenzuur / GLA (18:3 n-6)',
},
'dihomo-gamma-linolenic-acid' => {
	en => 'Dihomo-gamma-linolenic acid / DGLA (20:3 n-6)',
	es => 'Ácido dihomo-gamma-linolénico / DGLA (20:3 n-6)',
	el => 'Διχομο-γ-λινολεϊκό οξύ / DGLA (20:3 n-6)',
	pt => 'Ácido dihomo-gama-linolênico / DGLA (20:3 n-6)',
	pt_pt => 'Ácido dihomo-gama-linolénico / DGLA (20:3 n-6)',
	fr => 'Acide dihomo-gamma-linolénique / DGLA (20:3 n-6)',
	nl => 'Dihomo-gammalinoleenzuur / DGLA (20:3 n-6)',
	nl_be => 'Dihomo-gammalinoleenzuur / DGLA (20:3 n-6)',
},

'trans-fat' => {
	fr => "Acides gras trans",
	en => "Trans fat",
	es => "Grasas trans",
	el => 'Τρανς λιπαρά',
	it => "Acidi grassi trans",
	pt => "Gorduras trans",
	pt_pt => "Ácidos gordos trans",
	de => "Trans-Fettsäuren",
	he => "שומן טראנס - שומן בלתי רווי",
	zh => "反式脂肪",
	nl => 'Transvetten',
	nl_be => 'Transvetten',
},
cholesterol => {
	fr => "Cholestérol",
	en => "Cholesterol",
	es => "Colesterol",
	el => 'Χοληστερόλη',
	ar=> "الكوليسترول ",
	unit => "mg",
	it=> "Colesterolo",
	pt => "Colesterol",
	de => "Cholesterin",
	he => "כולסטרול",
	zh => "胆固醇",
	nl => "Cholesterol",
	nl_be => "Cholesterol",
       ja => "コレステロール",
},
fiber => {
	fr => "Fibres alimentaires",
	fr_synonyms => ["fibres", "fibre", "fibre alimentaire"],
	en => "Dietary fiber",
	ja => "食物繊維",
	es => "Fibra alimentaria",
	it=> "Fibra alimentare",
	pt => "Fibra alimentar",
	de => "Ballaststoffe",
	he => "סיבים תזונתיים",
	ga => "Snáithín",
	da => "Kostfibre",
	el => "Εδώδιμες ίνες",
	fi => "Ravintokuitu",
	nl => "Vezels",
	nl_be => "Vezels",
	sv => "Fiber",
	lv => "Šķiedrvielas",
	cs => "Vláknina",
	et => "Kiudained",
	hu => "Rost",
	pl => "Błonnik",
	sl => "Prehranskih vlaknin",
	lt => "Skaidulinių medžiagų",
	mt => "Fibra alimentari",
	sk => "Vláknina",
	bg => "Влакнини",
	zh => "膳食纤维",
},
"soluble-fiber" => {
	fr => "Fibres solubles",
	en => "Soluble fiber",
},
"insoluble-fiber" => {
	fr => "Fibres insolubles",
	en => "Insoluble fiber",
},
sodium => {
	fr => "Sodium",
	en => "Sodium",
	el => "Νάτριο",
	es => "Sodio",
	ar => "الصوديوم",
	it => "Sodio",
	pt => "Sódio",
	de => "Natrium",
	he => "נתרן",
	zh => "钠",
	nl => "Natrium",
	nl_be => "Sodium",
	ja => "ナトリウム",
	unit_us => 'mg',	
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
	fi => "vitamiini",
	nl => "Vitamines",
	nl_be => "Vitamines",
	lv => "vitamīns",
	et => "Vitamiin",
	hu => "vitamin",
	pl => "Witamina",
	lt => "Vitaminas",
	mt => "Vitamina",
	sk => "Vitamín",
	ro => "Vitamina",
	bg => "Витамин",
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
	unit_us => '% DV',
	unit_ca => '% DV',		
},
'vitamin-d' => {
	fr => "Vitamine D / D3 (cholécalciférol)",
	fr_synonyms => ["Vitamine D", "Vitamine D3", "cholécalciférol"],
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
	ja => "ビタミン E",
	es => "Vitamina E (a-tocoferol)",
	it => "Vitamina E (Alfa-tocoferolo)",
	pt => "Vitamina E",
	de => "Vitamin E (Tocopherol)",
	he => "ויטמין E (אלפא טוקופרול)",
	ga => "Vitimín E",
	el => "Βιταμίνη E",
	fi => "E-vitamiini",
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
	fi => "K-vitamiini",
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
'vitamin-c' => {
	fr => "Vitamine C (acide ascorbique)",
	fr_synonyms => ["Vitamine C", "acide ascorbique"],	
	en => "Vitamin C (ascorbic acid)",
	es => "Vitamina C (Ácido ascórbico)",
	ja => "ビタミン C",
	it => "Vitamina C (Acido ascorbico)",
	pt => "Vitamina C",
	de => "Vitamin C (Ascorbinsäure)",
	he => "ויטמין C (חומצה אסקורבית)",
	ga => "Vitimín C",
	el => "Βιταμίνη C",
	fi => "C-vitamiini",
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
	unit_us => '% DV',
	unit_ca => '% DV',	
},
'vitamin-b1' => {
	fr => "Vitamine B1 (Thiamine)",
	fr_synonyms => ["Vitamine B1", "Thiamine"],	
	en => "Vitamin B1 (Thiamin)",
	es => "Vitamina B1 (Tiamina)",
	ja => "ビタミン B1",
	it => "Vitamina B1 (tiamina)",
	pt => "Vitamina B1 (Tiamina)",
	de => "Vitamin B1 (Thiamin)",
	he => "ויטמין B1 (תיאמין)",
	ga => "Vitimín B1 (Tiaimín)",
	el => "Βιταμίνη B1 (Θειαμίνη)",
	fi => "B1-vitamiini (Tiamiini)",
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
	es => "Vitamina B2 (Riboflavina)",
	ja => "ビタミン B2",
	it => "Vitamina B2 (Riboflavina)",
	pt => "Vitamina B2 (Riboflavina)",
	de => "Vitamin B2 (Riboflavin)",
	he => "ויטמין B2 (ריבופלבין)",
	ga => "Vitimín B2 (Ribeaflaivin)",
	el => "Βιταμίνη B2 (Ριβοφλαβίνη)",
	fi => "B2-vitamiini (Riboflaviini)",
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
	fr_synonyms => ["Vitamine B3", "Vitamine PP", "Niacine"],		
	en => "Vitamin B3 / Vitamin PP (Niacin)",
	es => "Vitamina B3 / Vitamina PP (Niacina)",
	ja => "ビタミン B3",
	it => "Vitamina B3 / Vitamina PP (Niacina)",
	pt => "Vitamina B3 / Vitamina PP (Niacina)",
	de => "Vitamin B3 / Vitamin PP (Niacin)",
	he => "ויטמין B3 /ויטמין PP (ניאצין או חומצה ניקוטינית)",
	ga => "Niaicin",
	el => "Νιασίνη",
	fi => "Niasiini",
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
	es => "Vitamina B6 (Piridoxina)",
	ja => "ビタミン B6",
	it => "Vitamina B6 (piridoxina)",
	pt => "Vitamina B6 (Piridoxina)",
	de => "Vitamin B6 (Pyridoxin)",
	he => "ויטמין B6 (פירידוקסין)",
	ga => "Vitimín B6",
	el => "Βιταμίνη B6",
	fi => "B6-vitamiini",
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
},
'vitamin-b9' => {
	fr => "Vitamine B9 (Acide folique)",
	fr_synonyms => ["Vitamine B9", "Acide folique"],	
	en => "Vitamin B9 (Folic acid)",
	es => "Vitamina B9 (Ácido fólico)",
	ja => "ビタミン B9 (葉酸)",
	it => "Vitamina B9 (Acido folico)",
	pt => "Vitamina B9 (Ácido Fólico)",
	de => "Vitamin B9 (Folsäure)",
	he => "ויטמין B9 (חומצה פולית)",
	ga => "Vitimín B9 (Aigéad fólach)",
	el => "Βιταμίνη B9 (Φολικό οξύ)",
	fi => "B9-vitamiini (Foolihappo)",
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
	fr => "Folates (folates totaux)",

	unit => "µg",
	dv => 400,	
	dv_2016 => 400,	
},
'vitamin-b12' => {
	fr => "Vitamine B12 (cobalamine)",
	fr_synonyms => ["Vitamine B12", "Cobalamine"],				
	en => "Vitamin B12 (cobalamin)",
	es => "Vitamina B12 (Cianocobalamina)",
	it => "Vitamina B12 (Cobalamina)",
	ja => "ビタミン B12",
	pt => "Vitamina B12 (Cobalamina)",
	de => "Vitamin B12 (Cobalamin)",
	he => "ויטמין B12 (ציאנוקובלאמין)",
	ga => "Vitimín B12",
	el => "Βιταμίνη B12",
	fi => "B12-vitamiini",
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
	fr_synonyms => ["Biotine", "Vitamine B8", "Vitamine B7", "Vitamine H"],				
	en => "Biotin",
	es => "Vitamina B7 (Biotina)",
	it => "Vitamina B8/B7/H/I (Biotina)",
	pt => "Vitamina B7 (Biotina)",
	de => "Biotin (Vitamin B8 / B7 / H)",
	ja => "ビタミン B8 / B7 / H",
	he => "ביוטין (ויטמין B7)",
	ga => "Bitin",
	el => "Βιοτίνη",
	fi => "Biotiini",
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
	fr_synonyms => ["Acide pantothénique", "Vitamine B5"],	
	en => "Pantothenic acid / Pantothenate (Vitamin B5)",
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
	fi => "Pantoteenihappo",
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
	it => "Sali minerali",
	pt => "Sais Minerais",
	de => "Minerals",
	he => "מינרלים",
	nl => "Mineralen",
	nl_be => "Mineralen",
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
	unit => "mg",
	it => "Bicarbonato",
	pt => "Bicarbonato",
	de => "Bikarbonat",
	he => "ביקרבונט (מימן פחמתי)",
	nl => "Bicarbonaat",
	nl_be => "Bicarbonaat",
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
	unit => "mg",
	it => "Silicio",
	pt => "Sílica",
	de => "Kieselerde",
	he => "צורן דו־חמצני",
	nl => "Silicium",
	nl_be => "Silicium",
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
	unit_us => '% DV',
	unit_ca => '% DV',		
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
	unit_us => '% DV',
	unit_ca => '% DV',	
},
magnesium => {
	fr => "Magnésium",
	en => "Magnesium",
	es => "Magnesio",
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
	fr => 'Caféine / Théine',
	en => 'Caffeine',
	el => "Καφεΐνη",
	nl => 'Cafeïne',
	nl_be => 'Cafeïne',
	pt => 'Cafeína',
},
taurine => {
zh_hans => '牛磺酸',
zh_hant => '牛磺酸',
zh_hk => '牛磺酸',
zh_cn => '牛磺酸',
zh_sg => '牛磺酸',
zh_tw => '牛磺酸',
pl => 'Tauryna',
wa => 'Torene',
ko => '타우린',
fr => 'Taurine',
he => 'טאורין',
es => 'Taurina',
hu => 'Taurin',
it => 'Taurina',
gl => 'Taurina',
et => 'Tauriin',
id => 'Taurina',
de => 'Taurin',
ja => 'タウリン',
vi => 'Taurine',
nl => 'Taurine',
nl_be => 'Taurine',
sv => 'Taurin',
pt => 'Taurina',
eo => 'Taŭrino',
sk => 'Taurín',
ru => 'таурин',
en => 'Taurine',
sr_el => 'Taurin',
sr_ec => 'Таурин',
tr => 'Taurin',
ro => 'Taurină',
ca => 'Taurina',
fi => 'Tauriini',
uk => 'Таурин',
sl => 'Tavrin',
cs => 'Taurin',
fa => 'تائورین',
bg => 'Таурин',
hr => 'Taurin',
da => 'Taurin',
sr => 'таурин',
zh => '牛磺酸',
nb => 'Taurin',
hy => 'Տաուրին',
sh => 'Taurin',
ar => 'التورين',
sq => 'taurin',
mk => 'Таурин',
el => 'Ταυρίνη',
en_ca => 'Taurine',
en_gb => 'Taurine',
pt_br => 'Taurina',
},

ph => {
	en => "pH",
	el => "pH",
	nl => "pH",
	nl_be => "pH",
	unit => '',
},

"carbon-footprint" => {
	fr => "Empreinte carbone / émissions de CO2",
	en => "Carbon footprint / CO2 emissions",
	es => "Huella de carbono / Emisiones de CO2",
	el => "Αποτύπωμα άνθρακα/Εκπομπές CO2",
	it=> "Emissioni di CO2 (impronta climatica)",
	pt => "Pegada de carbono / Emissões de CO<sub>2</sub>",
	de => "Carbon Footprint / CO2-Emissionen",
	he => "טביעת רגל פחמנית / פליטת פחמן דו־חמצני",
	nl => "Ecologische voetafdruk / CO2-uitstoot",
	nl_be => "Ecologische voetafdruk / CO2-uitstoot",
	unit => 'g',
},
'glycemic-index' => {
	en => 'Glycemic Index',
	de => 'Glykämischer Index',
	unit => '',
},
"water-hardness" => {
	en => 'Water hardness',
	fr => "Dureté de l'eau",
	ru => 'Жёсткость воды',
	de => 'Wasserhärte',
	unit => 'mmol/l',
},
"fruits-vegetables-nuts" => {
	en => "Fruits, vegetables and nuts (minimum)",
	fr => "Fruits, légumes et noix (minimum)",
	es => "Frutas, verduras y nueces (mínimo)",
	el => "Φρούτα, λαχανικά, καρποί (ελάχιστο)",
	nl => "Fruit, groenten en noten (minimum)",
	nl_be => "Fruit, groenten en noten (minimum)",
	de => "Obst, Gemüse und Nüsse (Minimum)",
	unit => '%',
},
"fruits-vegetables-nuts-estimate" => {
	en => "Fruits, vegetables and nuts (estimate from ingredients list)",
	fr => "Fruits, légumes et noix (estimation avec la liste des ingrédients)",
	es => "Frutas, verduras y nueces (estimación de la lista de ingredientes)",
	nl => "Fruit, groenten en noten (Schat uit ingrediëntenlijst)",
	nl_be => "Fruit, groenten en noten (Schat uit ingrediëntenlijst)",
	de => "Obst, Gemüse und Nüsse (Schätzung aus Zutatenliste)",
	unit => '%',
},
"collagen-meat-protein-ratio" => {
	en => "Collagen/Meat protein ratio (maximum)",
	fr => "Rapport collagène sur protéines de viande (maximum)",
	el => "Αναλογία κολλαγόνου/πρωτεΐνης κρέατος (μέγιστο)",
	es => "Relación tejido conjuntivo/proteínas de carne (máximo)",
	de => "Verhältnis Kollagen/Eiweiß",
	nl => "Verhouding collageen/eiwitten uit vlees (maximum)",
	nl_be => "Verhouding collageen/eiwitten uit vlees (maximum)",
	unit => "%",
},
cocoa => {
	en => "Cocoa (minimum)",
	de => "Kakao (Minimum)",
	es => "Cacao (mínimo)",
	fr => "Cacao (minimum)",
	nl => "Cacao (minimum)",
	pt => "Cacau (minimum)",
	unit => "%",
},
"nutrition-score-uk" => {
	en => "Nutrition score - UK",
	nl => "Voedingsscore - UK",
	nl_be => "Voedingsgraad",
	el => "Bαθμολογία θρεπτικής αξίας-UK",
	unit => '',
},
"nutrition-score-fr" => {
	fr => "Score nutritionnel - France",
	en => "Nutrition score - France",
	nl => "Voedingsscore - FR",
	el => "Βαθμολογία θρεπτικής αξίας-FR",
	unit => '',
},
"beta-carotene" => {
	de => "Beta-Carotin",
	en => "Beta carotene",
	es => "Beta caroteno",
	fr => "Bêta carotène",
	nl => "Bêta-caroteen",
	nl_be => "Bêta-caroteen",
},
"chlorophyl" => {
	de => "Chlorophyll",
	en => "Chlorophyl",
	nl => "Chlorofyl",
	nl_be => "Chlorofyl",
},
"nutrition-grade" => {
	fr => "Note nutritionnelle",
	en => "Nutrition grade",
},
choline => {
	en => "Choline"
},
phylloquinone => {
	en => "Vitamin K1 (Phylloquinone)",
	fr => "Vitamine K1"
},
"beta-glucan" => {
	en => "Beta-glucan",
	fr => "Bêta-glucanes"
},
inositol => {
	en => "Inositol"
},
carnitine => {
	en => "Carnitine"
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

