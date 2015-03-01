package Blogs::Food;

######################################################################
#
#	Package	Food
#
#	Author:	Stephane Gigandet
#	Date:	20/01/12
#
######################################################################

BEGIN
{
	use vars       qw(@ISA @EXPORT @EXPORT_OK %EXPORT_Images);
	require Exporter;
	@ISA = qw(Exporter);
	@EXPORT = qw();            # symbols to export by default
	@EXPORT_OK = qw(
					%allergens
					%Nutriments
					@nutriments_table
					@other_nutriments
					@nutriments
					@nutrient_levels
	
					&unit_to_g
					&g_to_unit
					
					&canonicalize_nutriment
					
					&fix_salt_equivalent
					&compute_nutrition_score
					&compute_serving_size_data
					&compute_unknown_nutrients
					&compute_nutrient_levels
					
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
use strict;
use utf8;

use Blogs::Store qw/:all/;
use Blogs::Config qw/:all/;
use Blogs::Lang qw/:all/;

use Blogs::Tags qw/:all/;

use Hash::Util;

use JSON;
use Encode;

use CGI qw/:cgi :form escapeHTML/;



sub unit_to_g($$) {
	my $value = shift;
	my $unit = shift;
	$unit = lc($unit);
	
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


# allergens

%allergens = {
	fr => ["Anhydride sulfureux","Arachides","Céleri","Crustacés","Fruits à coque",
	"Gluten","Lait","Lupin","Mollusques",
	"Moutarde","Oeufs","Poisson","Sésame","Soja","Sulfites"],
	en => [],
},

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

@nutriments_table = qw(
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
vitamin-d-
vitamin-e-
vitamin-k-
vitamin-c-
vitamin-b1-
vitamin-b2-
vitamin-pp-
vitamin-b6-
vitamin-b9-
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
collagen-meat-protein-ratio-
carbon-footprint
nutrition-score-fr-
nutrition-score-uk-
);

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
},
energy	=> {
	fr => "Énergie",
	en => "Energy",
	es => "Energía",
	ar => "الطاقه",
	unit => 'kj',
	it => "Energia",
	pt => "Energia",
	de => "Energie",
	he => "אנרגיה - קלוריות",
	ga => "Fuinneamh",
	da => "Energi",
	el => "Ενέργεια",
	fi => "Energiav",
	nl => "Energie",
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
},
casein => {
	fr => 'Caséine',
	en => 'Casein',
},
nucleotides => {
	fr => 'Nucléotides',
	en => 'Nucleotides',
},
"serum-proteins" => {
	fr => "Protéines sériques",
	en => "Serum proteins",
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
},
sugars => {
	fr => "Sucres",
	en => "Sugars",
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
},
sucrose => {
	fr => 'Saccharose',
	en => 'Sucrose',
	es => 'Sacarosa',
	pt => 'Sacarose',
	he => 'סוכרוז',
	de => 'Saccharose',

},
glucose => {
	fr => 'Glucose',
	en => 'Glucose',
	pt => 'Glucose',
	es => 'Glucosa',
	he => 'גלוקוז',
	de => 'Traubenzucker',
},
fructose => {
	fr => 'Fructose',
	pt => 'Frutose',
	en => 'Fructose',
	es => 'Fructosa',
	he => 'פרוקטוז',
	de => 'Fruchtzucker',

},
lactose => {
	fr => 'Lactose',
	en => 'Lactose',
	pt => 'Lactose',
	es => 'Lactosa',
	he => 'לקטוז',
	de => 'Milchzucker',

},
maltose => {
	fr => 'Maltose',
	en => 'Maltose',
	pt => 'Maltose',
	es => 'Maltosa',
	he => 'מלטוז',
	de => 'Malzzucker',

},
maltodextrins => {
	fr => 'Maltodextrines',
	en => 'Maltodextrins',
	pt => 'Maltodextrinas',
	es => 'Maltodextrinas',
	he => 'מלטודקסטרינים',
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
	en => "Fat",
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
},
'saturated-fat' => {
	fr => "Acides gras saturés",
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
},
'butyric-acid' => {
	en => 'Butyric acid (4:0)',
	es => 'Ácido butírico (4:0)',
	pt => 'Ácido butírico (4:0)',
	fr => 'Acide butyrique (4:0)',
	he => 'חומצה בוטירית (4:0)',
},
'caproic-acid' => {
	en => 'Caproic acid (6:0)',
	es => 'Ácido caproico (6:0)',
	pt => 'Ácido capróico (6:0)',
	fr => 'Acide caproïque (6:0)',
	he => 'חומצה קפרואית (6:0)',
},
'caprylic-acid' => {
	en => 'Caprylic acid (8:0)',
	es => 'Ácido caprílico (8:0)',
	pt => 'Ácido caprílico (8:0)',
	fr => 'Acide caproïque (8:0)',
	he => 'חומצה קפרילית (8:0)',
},
'capric-acid' => {
	en => 'Capric acid (10:0)',
	es => 'Ácido cáprico (10:0)',
	pt => 'Ácido cáprico (10:0)',
	fr => 'Acide caprique (10:0)',
	he => 'חומצה קפרית (10:0)',
},
'lauric-acid' => {
	en => 'Lauric acid (12:0)',
	es => 'Ácido láurico (12:0)',
	pt => 'Ácido láurico (12:0)',
	fr => 'Acide laurique (12:0)',
	he => 'חומצה לאורית (12:0)',
},
'myristic-acid' => {
	en => 'Myristic acid (14:0)',
	es => 'Ácido mirístico (14:0)',
	pt => 'Ácido mirístico (14:0)',
	fr => 'Acide myristique (14:0)',
	he => 'חומצה מיריסטית (14:0)',
},
'palmitic-acid' => {
	en => 'Palmitic acid (16:0)',
	es => 'Ácido palmítico (16:0)',
	pt => 'Ácido palmítico (16:0)',
	fr => 'Acide palmitique (16:0)',
	he => 'חומצה פלמיטית (16:0)',
},
'stearic-acid' => {
	en => 'Stearic acid (18:0)',
	es => 'Ácido esteárico (18:0)',
	pt => 'Ácido esteárico (18:0)',
	fr => 'Acide stéarique (18:0)',
	he => 'חומצה סטארית (18:0)',
},
'arachidic-acid' => {
	en => 'Arachidic acid (20:0)',
	es => 'Ácido araquídico (20:0)',
	pt => 'Ácido araquídico (20:0)',
	fr => 'Acide arachidique / acide eicosanoïque (20:0)',
},
'behenic-acid' => {
	en => 'Behenic acid (22:0)',
	es => 'Ácido behénico (22:0)',
	pt => 'Ácido beénico (22:0)',
	fr => 'Acide béhénique (22:0)',
	he => 'חומצה בהנית (22:0)',
},
'lignoceric-acid' => {
	en => 'Lignoceric acid (24:0)',
	es => 'Ácido lignocérico (24:0)',
	pt => 'Ácido lignocérico (24:0)',
	fr => 'Acide lignocérique (24:0)',
},
'cerotic-acid' => {
	en => 'Cerotic acid (26:0)',
	es => 'Ácido cerótico (26:0)',
	pt => 'Ácido cerótico (26:0)',
	fr => 'Acide cérotique (26:0)',
},
'montanic-acid' => {
	en => 'Montanic acid (28:0)',
	es => 'Ácido montánico (28:0)',
	pt => 'Ácido montânico (28:0)',
	fr => 'Acide montanique (28:0)',
},
'melissic-acid' => {
	en => 'Melissic acid (30:0)',
	es => 'Ácido melísico (30:0)',
	pt => 'Ácido melíssico (30:0)',
	fr => 'Acide mélissique (30:0)',
},
'monounsaturated-fat' => {
	fr => "Acides gras monoinsaturés",
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
	en => "Omega 9 fatty acids",
	es => "Ácidos grasos Omega 9",
	it=> "Acidi grassi Omega 9",
	pt => "Ácidos Graxos Ômega 9",
	pt_pt => "Ácidos gordos Ómega 9",
	de => "Omega-9-Fettsäuren",
	he => "אומגה 9",
},
'oleic-acid' => {
	en => 'Oleic acid (18:1 n-9)',
	es => 'Ácido oleico (18:1 n-9)',
	pt => 'Ácido oleico (18:1 n-9)',
	fr => 'Acide oléique (18:1 n-9)',
	he => 'חומצה אולאית',
},
'elaidic-acid' => {
	en => 'Elaidic acid (18:1 n-9)',
	es => 'Ácido elaídico (18:1 n-9)',
	pt => 'Ácido elaídico (18:1 n-9)',
	fr => 'Acide élaïdique (18:1 n-9)',
},
'gondoic-acid' => {
	en => 'Gondoic acid (20:1 n-9)',
	es => 'Ácido gondoico (20:1 n-9)',
	pt => 'Ácido gondoico (20:1 n-9)',
	fr => 'Acide gadoléique (20:1 n-9)',
},
'mead-acid' => {
	en => 'Mead acid (20:3 n-9)',
	es => 'Ácido Mead (20:3 n-9)',
	pt => 'Ácido de Mead (20:3 n-9)',
	fr => 'Acide de Mead (20:3 n-9)',
},
'erucic-acid' => {
	en => 'Erucic acid (22:1 n-9)',
	es => 'Ácido erúcico (22:1 n-9)',
	pt => 'Ácido erúcico (22:1 n-9)',
	fr => 'Acide érucique (22:1 n-9)',
},
'nervonic-acid' => {
	en => 'Nervonic acid (24:1 n-9)',
	es => 'Ácido nervónico (24:1 n-9)',
	pt => 'Ácido nervônico (24:1 n-9)',
	pt_pt => 'Ácido nervónico (24:1 n-9)',
	fr => 'Acide nervonique (24:1 n-9)',
},
'polyunsaturated-fat' => {
	fr => "Acides gras polyinsaturés",
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
	en => "Omega 3 fatty acids",
	es => "Ácidos grasos Omega 3",
	it=> "Acidi grassi Omega 3",
	pt => "Ácidos graxos Ômega 3",
	pt_pt => "Ácidos gordos Ómega 3",
	de => "Omega-3-Fettsäuren",
	he => "אומגה 3",
},
'alpha-linolenic-acid' => {
	en => 'Alpha-linolenic acid / ALA (18:3 n-3)',
	es => 'Ácido alfa-linolénico / ALA (18:3 n-3)',
	pt => 'Ácido alfa-linolênico / ALA (18:3 n-3)',
	pt_pt => 'Ácido alfa-linolénico / ALA (18:3 n-3)',
	fr => 'Acide alpha-linolénique / ALA (18:3 n-3)',
},
'eicosapentaenoic-acid' => {
	en => 'Eicosapentaenoic acid / EPA (20:5 n-3)',
	es => 'Ácido eicosapentaenoico / EPA (20:5 n-3)',
	pt => 'Ácido eicosapentaenóico / EPA (20:5 n-3)',
	fr => 'Acide eicosapentaénoïque / EPA (20:5 n-3)',
},
'docosahexaenoic-acid' => {
	en => 'Docosahexaenoic acid / DHA (22:6 n-3)',
	es => 'Ácido docosahexaenoico / DHA (22:6 n-3)',
	pt => 'Ácido docosa-hexaenóico / DHA (22:6 n-3)',
	fr => 'Acide docosahexaénoïque / DHA (22:6 n-3)',
},
'omega-6-fat' => {
	fr => "Acides gras Oméga 6",
	en => "Omega 6 fatty acids",
	es => "Ácidos grasos Omega 6",
	it=> "Acidi grassi Omega 6",
	pt => "Ácidos Graxos Ômega 6",
	pt_pt => "Ácidos gordos Ómega 6",
	de => "Omega-6-Fettsäuren",
	he => "אומגה 6",
},
'linoleic-acid' => {
	en => 'Linoleic acid / LA (18:2 n-6)',
	es => 'Ácido linoleico / LA (18:2 n-6)',
	pt => 'Ácido linoleico / LA (18:2 n-6)',
	fr => 'Acide linoléique / LA (18:2 n-6)',
},
'arachidonic-acid' => {
	en => 'Arachidonic acid / AA / ARA (20:4 n-6)',
	es => 'Ácido araquidónico / AA / ARA (20:4 n-6)',
	pt => 'Ácido araquidônico / AA / ARA (20:4 n-6)',
	pt_pt => 'Ácido araquidónico / AA / ARA (20:4 n-6)',
	fr => 'Acide arachidonique / AA / ARA (20:4 n-6)',
	he => 'חומצה ארכידונית / AA / ARA (20:4 n-6)',
},
'gamma-linolenic-acid' => {
	en => 'Gamma-linolenic acid / GLA (18:3 n-6)',
	es => 'Ácido gamma-linolénico / GLA (18:3 n-6)',
	pt => 'Ácido gama-linolênico / GLA (18:3 n-6)',
	pt_pt => 'Ácido gama-linolénico / GLA (18:3 n-6)',
	fr => 'Acide gamma-linolénique / GLA (18:3 n-6)',
},
'dihomo-gamma-linolenic-acid' => {
	en => 'Dihomo-gamma-linolenic acid / DGLA (20:3 n-6)',
	es => 'Ácido dihomo-gamma-linolénico / DGLA (20:3 n-6)',
	pt => 'Ácido dihomo-gama-linolênico / DGLA (20:3 n-6)',
	pt_pt => 'Ácido dihomo-gama-linolénico / DGLA (20:3 n-6)',
	fr => 'Acide dihomo-gamma-linolénique / DGLA (20:3 n-6)',
},

'trans-fat' => {
	fr => "Acides gras trans",
	en => "Trans fat",
	es => "Grasas trans",
	it => "Acidi grassi trans",
	pt => "Gorduras trans",
	pt_pt => "Ácidos gordos trans",
	de => "Trans-Fettsäuren",
	he => "שומן טראנס - שומן בלתי רווי",
},
cholesterol => {
	fr => "Cholestérol",
	en => "Cholesterol",
	es => "Colesterol",
	ar=> "الكوليسترول ",
	unit => "mg",
	it=> "Colesterolo",
	pt => "Colesterol",
	de => "Cholesterin",
	he => "כולסטרול",
},
fiber => {
	fr => "Fibres alimentaires",
	en => "Dietary fiber",
	es => "Fibra alimentaria",
	it=> "Fibra alimentare",
	pt => "Fibra alimentar",
	de => "Ballaststoffe",
	he => "סיבים תזונתיים",
	ga => "Snáithín",
	da => "Kostfibre",
	el => "εδώδιμες ίνες",
	fi => "Ravintokuitu",
	nl => "Vezels",
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
},
sodium => {
	fr => "Sodium",
	en => "Sodium",
	es => "Sodio",
	ar => "الصوديوم",
	it => "Sodio",
	pt => "Sódio",
	de => "Natrium",
	he => "נתרן",
},
salt => {
	fr => "Sel",
	en => "Salt",
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
},
'salt-equivalent' => {
	fr => "Equivalent en sel",
	en => "Salt equivalent",
	es => "Equivalente en sal",
	pt => "Equivalente em sal",
	he => "תחליפי מלח",
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
	el => "Βιταμίνη",
	fi => "vitamiini",
	nl => "Vitamine",
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
	en => "Vitamin A",
	es => "Vitamina A (Retinol)",
	unit => "µg",
	dv => "1500",
	it => "Vitamina A (Retinolo)",
	pt => "Vitamina A",
	de => "Vitamin A (Retinol)",
	he => "ויטמין A (רטינול)",
	ga => "Vitimín A",
	el => "Βιταμίνη A",
	fi => "A-vitamiini",
	nl => "Vitamine A",
	lv => "A vitamīns",
	et => "Vitamiin A",
	hu => "A-vitamin",
	pl => "Witamina A",
	lt => "Vitaminas A",
	mt => "Vitamina A",
	sk => "Vitamín A",
	ro => "Vitamina A",
	bg => "Витамин A",
},
'vitamin-d' => {
	fr => "Vitamine D / D3 (cholécalciférol)",
	en => "Vitamin D",
	es => "Vitamina D",
	unit => "µg",
	dv => "40",
	it => "Vitamina D (colecalciferolo)",
	pt => "Vitamina D",
	de => "Vitamin D / D3 (Cholecalciferol)",
	he => "ויטמין D",
	ga => "Vitimín D",
	el => "Βιταμίνη D",
	fi => "D-vitamiini",
	nl => "Vitamine D",
	lv => "D vitamīns",
	et => "Vitamiin D",
	hu => "D-vitamin",
	pl => "Witamina D",
	lt => "Vitaminas D",
	mt => "Vitamina D",
	sk => "Vitamín D",
	ro => "Vitamina D",
	bg => "Витамин D",
},
'vitamin-e' => {
	fr => "Vitamine E (tocophérol)",
	en => "Vitamin E",
	es => "Vitamina E (a-tocoferol)",
	unit => "mg",
	dv => "20",
	it => "Vitamina E (Alfa-tocoferolo)",
	pt => "Vitamina E",
	de => "Vitamin E (Tocopherol)",
	he => "ויטמין E (אלפא טוקופרול)",
	ga => "Vitimín E",
	el => "Βιταμίνη E",
	fi => "E-vitamiini",
	nl => "Vitamine E",
	lv => "E vitamīns",
	et => "Vitamiin E",
	hu => "E-vitamin",
	pl => "Witamina E",
	lt => "Vitaminas E",
	mt => "Vitamina E",
	sk => "Vitamín E",
	ro => "Vitamina E",
	bg => "Витамин E",
},
'vitamin-k' => {
	fr => "Vitamine K",
	en => "Vitamin K",
	es => "Vitamina K",
	unit => "µg",
	dv => "80",
	it => "Vitamina K",
	pt => "Vitamina K",
	de => "Vitamin K",
	he => "ויטמין K (מנדיון)",
	ga => "Vitimín K",
	el => "Βιταμίνη K",
	fi => "K-vitamiini",
	nl => "Vitamine K",
	lv => "K vitamīns",
	et => "Vitamiin K",
	hu => "K-vitamin",
	pl => "Witamina K",
	lt => "Vitaminas K",
	mt => "Vitamina K",
	sk => "Vitamín K",
	ro => "Vitamina K",
	bg => "Витамин K",
},
'vitamin-c' => {
	fr => "Vitamine C (acide ascorbique)",
	en => "Vitamin C (ascorbic acid)",
	es => "Vitamina C (Ácido ascórbico)",
	unit => "mg",
	dv => "60",
	it => "Vitamina C (Acido ascorbico)",
	pt => "Vitamina C",
	de => "Vitamin C (Ascorbinsäure)",
	he => "ויטמין C (חומצה אסקורבית)",
	ga => "Vitimín C",
	el => "Βιταμίνη C",
	fi => "C-vitamiini",
	nl => "Vitamine C",
	lv => "C vitamīns",
	et => "Vitamiin C",
	hu => "C-vitamin",
	pl => "Witamina C",
	lt => "Vitaminas C",
	mt => "Vitamina C",
	sk => "Vitamín C",
	ro => "Vitamina C",
	bg => "Витамин C",
},
'vitamin-b1' => {
	fr => "Vitamine B1 (Thiamine)",
	en => "Vitamin B1 (Thiamin)",
	es => "Vitamina B1 (Tiamina)",
	unit => "mg",
	dv => "1.5",
	it => "Vitamina B1 (tiamina)",
	pt => "Vitamina B1 (Tiamina)",
	de => "Vitamin B1 (Thiamin)",
	he => "ויטמין B1 (תיאמין)",
	ga => "Vitimín B1 (Tiaimín)",
	el => "Βιταμίνη B1 (Θειαμίνη)",
	fi => "B1-vitamiini (Tiamiini)",
	nl => "Vitamine B1 (Thiamine)",
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
},
'vitamin-b2' => {
	fr => "Vitamine B2 (Riboflavine)",
	en => "Vitamin B2 (Riboflavin)",
	es => "Vitamina B2 (Riboflavina)",
	unit => "mg",
	dv => "1.7",
	it => "Vitamina B2 (Riboflavina)",
	pt => "Vitamina B2 (Riboflavina)",
	de => "Vitamin B2 (Riboflavin)",
	he => "ויטמין B2 (ריבופלבין)",
	ga => "Vitimín B2 (Ribeaflaivin)",
	el => "Βιταμίνη B2 (Ριβοφλαβίνη)",
	fi => "B2-vitamiini (Riboflaviini)",
	nl => "Vitamine B2 (Riboflavine)",
	lv => "B2 vitamīns (Riboflavīns)",
	et => "Vitamiin B2 (Riboflaviin)",
	hu => "B2-vitamin (Riboflavin)",
	pl => "Witamina B2 (Ryboflawina)",
	lt => "Vitaminas B2 (Riboflavinas)",
	mt => "Vitamina B2 (Riboflavina)",
	sk => "Vitamín B2",
	ro => "Vitamina B2 (Riboflavină)",
	bg => "Витамин B2 (Рибофлавин)",
},
'vitamin-pp' => {
	fr => "Vitamine B3 / Vitamine PP (Niacine)",
	en => "Vitamin B3 / Vitamin PP (Niacin)",
	es => "Vitamina B3 / Vitamina PP (Niacina)",
	unit => "mg",
	dv => "20",
	it => "Vitamina B3 / Vitamina PP (Niacina)",
	pt => "Vitamina B3 / Vitamina PP (Niacina)",
	de => "Vitamin B3 / Vitamin PP (Niacin)",
	he => "ויטמין B3 /ויטמין PP (ניאצין או חומצה ניקוטינית)",
	ga => "Niaicin",
	el => "Νιασίνη",
	fi => "Niasiini",
	nl => "Niacine",
	lv => "Niacīns",
	et => "Niatsiin",
	pl => "Niacyna",
	lt => "Niacinas",
	mt => "Niaċina",
	sk => "Niacín",
	ro => "Niacină",
	bg => "Ниацин",
},	
'vitamin-b6' => {
	fr => "Vitamine B6 (Pyridoxine)",
	en => "Vitamin B6 (Pyridoxin)",
	es => "Vitamina B6 (Piridoxina)",
	unit => "mg",
	dv => "2",
	it => "Vitamina B6 (piridoxina)",
	pt => "Vitamina B6 (Piridoxina)",
	de => "Vitamin B6 (Pyridoxin)",
	he => "ויטמין B6 (פירידוקסין)",
	ga => "Vitimín B6",
	el => "Βιταμίνη B6",
	fi => "B6-vitamiini",
	nl => "Vitamine B6",
	lv => "B6 vitamīns",
	et => "Vitamiin B6",
	hu => "B6-vitamin",
	pl => "Witamina B6",
	lt => "Vitaminas B6",
	sk => "Vitamín B6",
	ro => "Vitamina B6",
	bg => "Витамин B6",
},
'vitamin-b9' => {
	fr => "Vitamine B9 (Acide folique)",
	en => "Vitamin B9 (Folic acid)",
	es => "Vitamina B9 (Ácido fólico)",
	unit => "µg",
	dv => "400",
	it => "Vitamina B9 (Acido folico)",
	pt => "Vitamina B9 (Ácido Fólico)",
	de => "Vitamin B9 (Folsäure)",
	he => "ויטמין B9 (חומצה פולית)",
	ga => "Vitimín B9 (Aigéad fólach)",
	el => "Βιταμίνη B9 (Φολικό οξύ)",
	fi => "B9-vitamiini (Foolihappo)",
	nl => "Vitamine B9 (Foliumzuur)",
	lv => "B9 vitamīns (Folijskābe)",
	et => "Vitamiin B9 (Foolhape)",
	hu => "B9-vitamin (Folsav)",
	pl => "Witamina B9 (Kwas foliowy)",
	lt => "Vitaminas B9 (Folio rūgštis)",
	sk => "Vitamín B9 (Kyselina listová)",
	ro => "Vitamina B9 (Acid folic)",
	bg => "Витамин B9 (Фолиева киселина)",
},
'vitamin-b12' => {
	fr => "Vitamine B12 (cobalamine)",
	en => "Vitamin B12 (cobalamin)",
	es => "Vitamina B12 (Cianocobalamina)",
	unit => "µg",
	dv => "6",
	it => "Vitamina B12 (Cobalamina)",
	pt => "Vitamina B12 (Cobalamina)",
	de => "Vitamin B12 (Cobalamin)",
	he => "ויטמין B12 (ציאנוקובלאמין)",
	ga => "Vitimín B12",
	el => "Βιταμίνη B12",
	fi => "B12-vitamiini",
	nl => "Vitamine B12",
	lv => "B12 vitamīns",
	et => "Vitamiin B12",
	hu => "B12-vitamin",
	pl => "Witamina B12",
	lt => "Vitaminas B12",
	sk => "Vitamín B12",
	ro => "Vitamina B12",
	bg => "Витамин В12",
},
'biotin' => {
	fr => "Biotine (Vitamine B8 / B7 / H)",
	en => "Biotin",
	es => "Vitamina B7 (Biotina)",
	unit => "µg",
	dv => "300",
	it => "Vitamina B8/B7/H/I (Biotina)",
	pt => "Vitamina B7 (Biotina)",
	de => "Biotin (Vitamin B8 / B7 / H)",
	he => "ביוטין (ויטמין B7)",
	ga => "Bitin",
	el => "Βιοτίνη",
	fi => "Biotiini",
	nl => "Biotine",
	lv => "Biotīns",
	et => "Biotiin",
	pl => "Biotyna",
	lt => "Biotinas",
	sk => "Biotín",
	ro => "Biotină",
	bg => "Биотин",
},	
'pantothenic-acid' => {
	fr => "Acide pantothénique (Vitamine B5)",
	en => "Panthotenic acid (Vitamin B5)",
	es => "Vitamina B5 (Ácido pantoténico)",
	unit => "mg",
	dv => "10",
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
},	
'#minerals' => {
	fr => "Sels minéraux",
	en => "Minerals",
	es => "Sales minerales",
	it => "Sali minerali",
	pt => "Sais Minerais",
	de => "Minerals",
	he => "מינרלים",
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
},
bicarbonate => {
	fr => "Bicarbonate",
	en => "Bicarbonate",
	es => "Bicarbonato",
	unit => "mg",
	it => "Bicarbonato",
	pt => "Bicarbonato",
	de => "Bikarbonat",
	he => "ביקרבונט (מימן פחמתי)",
},
chloride => {
	fr => "Chlorure",
	en => "Chloride",
	es => "Cloro",
	unit => "mg",
	dv => "3400",
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
},
silica => {
	fr => "Silice",
	en => "Silica",
	es => "Sílice",
	unit => "mg",
	it => "Silicio",
	pt => "Sílica",
	de => "Kieselerde",
	he => "צורן דו־חמצני",
},
calcium => {
	fr => "Calcium",
	en => "Calcium",
	es => "Calcio",
	ar => "الكالسيوم",
	unit => "mg",
	dv => "1000",
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
},
phosphorus => {
	fr => "Phosphore",
	en => "Phosphorus",
	es => "Fósforo",
	ar => "الفوسفور",
	unit => "mg",
	dv => "1000",
	it => "Fosforo",
	pt => "Fósforo",
	de => "Phosphor",
	he => "זרחן",
	ga => "Fosfar",
	da => "Phosphor",
	el => "Φωσφόρος",
	fi => "Fosfori",
	nl => "Fosfor",
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
},
iron => {
	fr => "Fer",
	en => "Iron",
	es => "Hierro",
	unit => "mg",
	dv => "18",
	it => "Ferro",
	pt => "Ferro",
	de => "Eisen",
	he => "ברזל",
	ga => "Iarann",
	da => "Jern",
	el => "Σίδηρος",
	fi => "Rauta",
	nl => "IJzer",
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
},
magnesium => {
	fr => "Magnésium",
	en => "Magnesium",
	es => "Magnesio",
	unit => "mg",
	dv => "400",
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
},
zinc => {
	fr => "Zinc",
	en => "Zinc",
	es => "Zinc",
	unit => "mg",
	dv => "15",
	it => "Zinco",
	pt => "Zinco",
	de => "Zink",
	he => "אבץ",
	ga => "Sinc",
	da => "Zink",
	el => "Ψευδάργυρος",
	fi => "Sinkki",
	nl => "Zink",
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
},
copper => {
	fr => "Cuivre",
	en => "Copper",
	es => "Cobre",
	unit => "mg",
	dv => "2",
	it => "Rame",
	pt => "Cobre",
	de => "Kupfer",
	he => "נחושת",
	ga => "Copar",
	da => "Kobber",
	el => "Χαλκός",
	fi => "Kupari",
	nl => "Koper",
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
},
manganese => {
	fr => "Manganèse",
	en => "Manganese",
	es => "Manganeso",
	unit => "mg",
	dv => "2",
	it => "Manganese",
	pt => "Manganês",
	de => "Mangan",
	he => "מנגן",
	ga => "Mangainéis",
	da => "Mangan",
	el => "Μαγγάνιο",
	fi => "Mangaani",
	nl => "Mangaan",
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
},
selenium => {
	fr => "Sélénium",
	en => "Selenium",
	es => "Selenio",
	unit => "µg",
	dv => "70",
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
},
chromium => {
	fr => "Chrome",
	en => "Chromium",
	es => "Cromo",
	unit => "µg",
	dv => "120",
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
},
molybdenum => {
	fr => "Molybdène",
	en => "Molybdenum",
	es => "Molibdeno",
	unit => "µg",
	dv => "75",
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
},
iodine => {
	fr => "Iode",
	en => "Iodine",
	es => "Yodo",
	unit => "µg",
	dv => "150",
	it=> "Iodio",
	pt => "Iodo",
	de => "Jod",
	he => "יוד",
	ga => "Iaidín",
	da => "Jod",
	el => "Ιώδιο",
	fi => "Jodi",
	nl => "Jood",
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
},
caffeine => {
	fr => 'Caféine / Théine',
	en => 'Caffeine',
},
taurine => {
	fr => 'Taurine',
	en => 'Taurine',
},

ph => {
	en => "pH",
	unit => '',
},

"carbon-footprint" => {
	fr => "Empreinte carbone / émissions de CO2",
	en => "Carbon footprint / CO2 emissions",
	es => "Huella de carbono / Emisiones de CO2",
	unit => 'g',
	it=> "Emissioni di CO2 (impronta climatica)",
	pt => "Pegada de carbono / Emissões de CO<sub>2</sub>",
	de => "Carbon Footprint / CO2-Emissionen",
	he => "טביעת רגל פחמנית / פליטת פחמן דו־חמצני",
},
"fruits-vegetables-nuts" => {
	en => "Fruits, vegetables and nuts (minimum)",
	fr => "Fruits, légumes et noix (minimum)",
	unit => '%',
},
"collagen-meat-protein-ratio" => {
	en => "Collagen/Meat protein ratio (maximum)",
	fr => "Rapport collagène sur protéines de viande (maximum)",
	unit => "%",
},
"nutrition-score-uk" => {
	en => "Nutrition score - UK",
	unit => '',
},
"nutrition-score-fr" => {
	fr => "Score nutritionnel expérimental - France",
	en => "Experimental nutrition score",
	unit => '',
},

);


my $daily_values_us == <<XXX

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

foreach (@nutriments_table) {

	my $nutriment = $_;	# copy instead of alias
	
	if ($nutriment =~ /-$/) {
		$nutriment = $`;
		$nutriment =~ s/^(-|!)+//g;
		push @other_nutriments, $nutriment;
	}
	
	next if $nutriment =~ /\#/;
	
	$nutriment =~ s/^(-|!)+//g;
	$nutriment =~ s/-$//g;
	push @nutriments, $nutriment;
}


my %nutriments_labels = ();

foreach my $lc (@Langs) {

	$nutriments_labels{$lc} = ();

	foreach my $nid (keys %Nutriments) {
		my $label = $Nutriments{$nid}{$lc};
		next if not defined $label;
		$nutriments_labels{$lc}{get_fileid($label)} = $nid;
		#print STDERR "nutriments_labels : lc: $lc - label: $label - nid: $nid\n";
		
		my @labels = split(/\(|\/|\)/, $label);

		foreach my $sublabel ($label, @labels) {
			$sublabel = get_fileid($sublabel);
			if (length($sublabel) >= 2) {
				$nutriments_labels{$lc}{$sublabel} = $nid;
				#print STDERR "nutriments_labels : lc: $lc - sublabel: $sublabel - nid: $nid\n";
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

sub canonicalize_nutriment($) {

	my $label = shift;
	my $nid = get_fileid($label);
	if ($lc eq 'fr') {
		$nid =~ s/^dont-//;
	}
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
	return $nid;
	#print STDERR "canonicalize_nutriment : lc: $lc - label: $label - nid: $nid\n";
}


sub normalize_serving_size($) {

	my $serving = shift;
	
	my $q = 0;
	my $u;
	
	if ($serving =~ /((\d+)(\.|,)?(\d+))( )?(kg|g|mg|µg|oz|l|dl|cl|ml|(fl(\.?)( )?oz))/i) {
		$q = lc($1);
		$u = $6;
		$q =~ s/,/\./;
		$q = unit_to_g($q,$u);
	}
	
	# print STDERR "normalize_serving_size: serving: $serving - q: $q - u: $u \n";
	
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
	
	my $added_categories = '';
	
	if (has_tag($product_ref,"categories","en:beverages")) {
	
		if (defined $product_ref->{nutriments}{"alcohol_100g"}) {
			if (($product_ref->{nutriments}{"alcohol_100g"} < 1) and has_tag($product_ref,"categories","en:alcoholic-beverages")) {
				remove_tag($product_ref,"categories","en:alcoholic-beverages");	
				add_tag($product_ref,"categories","en:non-alcoholic-beverages");	
			}
			if (($product_ref->{nutriments}{"alcohol_100g"} >= 1) and not has_tag($product_ref,"categories","en:alcoholic-beverages")) {
				add_tag($product_ref,"categories","en:alcoholic-beverages");	
			}
		}
		else {
			if ((not has_tag($product_ref,"categories","en:non-alcoholic-beverages"))
				and (not has_tag($product_ref,"categories","en:alcoholic-beverages")) ) {
				add_tag($product_ref,"categories","en:non-alcoholic-beverages");	
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
				) {
				$added_categories .= ", en:sugared-beverages";
			}
			else {
				$added_categories .= ", en:non-sugared-beverages";
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
			print STDERR "warning, no pnns group 1 for pnns group 2 $product_ref->{pnns_groups_2}\n";
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
	if ((defined $product_ref->{nutriments}{'sodium'}) and ($product_ref->{nutriments}{'sodium'} ne '')) {
		$product_ref->{nutriments}{'salt'} = $product_ref->{nutriments}{'sodium'} * 2.54;
	}
	elsif ((defined $product_ref->{nutriments}{'salt'}) and ($product_ref->{nutriments}{'salt'} ne '')) {
		$product_ref->{nutriments}{'sodium'} = $product_ref->{nutriments}{'salt'} / 2.54;
	}	

}


# UK FSA scores thresholds



sub compute_nutrition_score($) {

	# compute UK FSA score (also in planned use in France)

	my $product_ref = shift;
	
	delete $product_ref->{nutrition_score_debug};
	delete $product_ref->{nutriments}{"nutrition-score"};
	delete $product_ref->{nutriments}{"nutrition-score_100g"};
	delete $product_ref->{nutriments}{"nutrition-score_serving"};
	
	# compute the score only if all values are known
	foreach my $nid ("energy", "saturated-fat", "sugars", "sodium", "fiber", "proteins") {
		if (not defined $product_ref->{nutriments}{$nid . "_100g"}) {
			$product_ref->{nutrition_score_debug} = "missing $nid";
			return;
		}
	}
	
	my $energy_points = int(($product_ref->{nutriments}{"energy_100g"} - 0.00001) / 335);
	$energy_points > 10 and $energy_points = 10;
	
	my $saturated_fat_points = int(($product_ref->{nutriments}{"saturated-fat_100g"} - 0.00001) / 1);
	$saturated_fat_points > 10 and $saturated_fat_points = 10;

	my $sugars_points = int(($product_ref->{nutriments}{"sugars_100g"} - 0.00001) / 4.5);
	$sugars_points > 10 and $sugars_points = 10;

	my $sodium_points = int(($product_ref->{nutriments}{"sodium_100g"} * 1000 - 0.00001) / 90);
	$sodium_points > 10 and $sodium_points = 10;	
	
	my $a_points = $energy_points + $saturated_fat_points + $sugars_points + $sodium_points;
	
# Pour les boissons, les grilles d’attribution des points pour l’énergie et les sucres simples ont été modifiées.
# ATTENTION, le lait, les laits végétaux ne sont pas compris dans le calcul des scores boissons. Ils relèvent du calcul général.

	my $fr_beverages_energy_points = int(($product_ref->{nutriments}{"energy_100g"} - 0.00001 + 30) / 30);
	$fr_beverages_energy_points > 10 and $fr_beverages_energy_points = 10;
	
	my $fr_beverages_sugars_points = int(($product_ref->{nutriments}{"sugars_100g"} - 0.00001 + 1.5) / 1.5);
	$fr_beverages_sugars_points > 10 and $fr_beverages_sugars_points = 10;	
	
# L’attribution des points pour les sucres prend en compte la présence d’édulcorants, pour lesquels la grille maintient les scores sucres simples à 1 (au lieu de 0).		
	
	if ((defined $product_ref->{with_sweeteners}) and ($fr_beverages_sugars_points == 0)) {
		$fr_beverages_sugars_points = 1;
	}
	
#Pour les boissons chaudes non sucrées (thé, café), afin de maintenir leur score à 0 (identique à l’eau), le score KJ a été maintenu à 0 si les sucres simples sont à 0.

	if (has_tag($product_ref, "categories", "en:hot-beverages") and (has_tag($product_ref, "categories", "en:coffees") or has_tag($product_ref, "categories", "en:teas"))) {
		if ($product_ref->{nutriments}{"sugars_100g"} == 0) {
			$fr_beverages_energy_points = 0;
		}
	}
	
	my $a_points_fr_beverages = $fr_beverages_energy_points + $saturated_fat_points + $fr_beverages_sugars_points + $sodium_points;
	
	# points for fruits, vegetables and nuts
	
	my $fruits = 0;
	if (defined $product_ref->{nutriments}{"fruits-vegetables-nuts_100g"}) {
		$fruits = $product_ref->{nutriments}{"fruits-vegetables-nuts_100g"};
	}
	# estimates by category of products. not exact values. it's important to distinguish only between the thresholds: 40, 60 and 80
	elsif (
		has_tag($product_ref, "categories", "en:fruit-juices")
		) {
		$fruits = "100";
	}
	elsif (
		has_tag($product_ref, "categories", "en:fruit-sauces")
		) {
		$fruits = "90";
	}		
	elsif (
		has_tag($product_ref, "categories", "en:vegetables")
		or has_tag($product_ref, "categories", "en:fruits")
		or has_tag($product_ref, "categories", "en:mushrooms")
		or has_tag($product_ref, "categories", "en:canned-fruits")
		or has_tag($product_ref, "categories", "en:frozen-fruits")
		) {
		$fruits = "90";
	}	
	elsif (has_tag($product_ref, "categories", "en:jams")
		) {
		$fruits = "50";
	}
	elsif (has_tag($product_ref, "categories", "en:fruits-based-foods")
		or has_tag($product_ref, "categories", "en:vegetables-based-foods")) {
		$fruits = 85;
	}
	$product_ref->{"fruits-vegetables-nuts_100g_estimate"} = $fruits;
	
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
	
	my $fiber_points = int(($product_ref->{nutriments}{"fiber_100g"} - 0.00001) / 0.7);
	$fiber_points > 5 and $fiber_points = 5;		

	my $proteins_points = int(($product_ref->{nutriments}{"proteins_100g"} - 0.00001) / 1.6);
	$proteins_points > 5 and $proteins_points = 5;		
	
	my $c_points = $fruits_points + $fiber_points + $proteins_points;

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
COMMENT
;

	my $saturated_fat_points_fr_matieres_grasses = int(($product_ref->{nutriments}{"saturated-fat_100g"} - 2.00001) / 4);
	$saturated_fat_points_fr_matieres_grasses < 0 and $saturated_fat_points_fr_matieres_grasses = 0;
	$saturated_fat_points_fr_matieres_grasses > 10 and $saturated_fat_points_fr_matieres_grasses = 10;
	
	my $a_points_fr_matieres_grasses = $energy_points + $saturated_fat_points_fr_matieres_grasses + $sugars_points + $sodium_points;

	my $a_points_fr = $a_points;
	
	if (has_tag($product_ref, "categories", "en:fats")) {
		$a_points_fr = $a_points_fr_matieres_grasses;
		$product_ref->{nutrition_score_debug} .= " -- in fats category";		
	}
	elsif (has_tag($product_ref, "categories", "en:beverages")
		and not (has_tag($product_ref, "categories", "en:plant-milks") or has_tag($product_ref, "categories", "en:milks"))) {
		$product_ref->{nutrition_score_debug} .= " -- in beverages category";
		
		$a_points_fr = $a_points_fr_beverages;
	}
	
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
	
	if ($a_points_fr < 11) {
		$fr_score -= $c_points;
	}
	elsif ($fruits_points == 5) {
		$fr_score -= $c_points;
	}
	else {
		if (has_tag($product_ref, "categories", "en:cheeses")) {
			$fr_score -= $c_points;
			$product_ref->{nutrition_score_debug} .= " -- in cheeses category";
		}
		else {
			$fr_score -= ($fruits_points + $fiber_points);
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
	
	if (has_tag($product_ref, "categories", "en:beverages")
		and not (has_tag($product_ref, "categories", "en:plant-milks") or has_tag($product_ref, "categories", "en:milks"))) {
		if ($fr_score <= 0) {
			$product_ref->{"nutrition_grade_fr"} = 'a';
		}
		elsif ($fr_score <= 4) {
			$product_ref->{"nutrition_grade_fr"} = 'b';
		}
		elsif ($fr_score <= 8) {
			$product_ref->{"nutrition_grade_fr"} = 'c';
		}
		elsif ($fr_score <= 11) {
			$product_ref->{"nutrition_grade_fr"} = 'd';
		}	
		else {
			$product_ref->{"nutrition_grade_fr"} = 'e';
		}	
	}
	else {
		if ($fr_score <= -2) {
			$product_ref->{"nutrition_grade_fr"} = 'a';
		}
		elsif ($fr_score <= 3) {
			$product_ref->{"nutrition_grade_fr"} = 'b';
		}
		elsif ($fr_score <= 11) {
			$product_ref->{"nutrition_grade_fr"} = 'c';
		}
		elsif ($fr_score <= 16) {
			$product_ref->{"nutrition_grade_fr"} = 'd';
		}	
		else {
			$product_ref->{"nutrition_grade_fr"} = 'e';
		}
	}
	
	
}


sub compute_serving_size_data($) {

	my $product_ref = shift;
	
	$product_ref->{serving_quantity} = normalize_serving_size($product_ref->{serving_size});
	
	#if ((defined $product_ref->{nutriments}) and (defined $product_ref->{nutriments}{'energy.unit'}) and ($product_ref->{nutriments}{'energy.unit'} eq 'kcal')) {
	#	$product_ref->{nutriments}{energy} = sprintf("%.0f", $product_ref->{nutriments}{energy} * 4.18);
	#	$product_ref->{nutriments}{'energy.unit'} = 'kj';
	#}
	
	if (not defined $product_ref->{nutrition_data_per}) {
		$product_ref->{nutrition_data_per} = '100g';
	}
	
	if ($product_ref->{nutrition_data_per} eq 'serving') {
	
		foreach my $nid (keys %{$product_ref->{nutriments}}) {
			next if $nid =~ /_/;
			$product_ref->{nutriments}{$nid . "_serving"} = $product_ref->{nutriments}{$nid};
			$product_ref->{nutriments}{$nid . "_serving"} =~ s/^(<|environ|max|maximum|min|minimum)( )?//;
			$product_ref->{nutriments}{$nid . "_serving"} += 0.0;
			$product_ref->{nutriments}{$nid . "_100g"} = '';
		
			if (($nid eq 'alcohol') or ($nid eq 'nutrition-score') or ($nid eq 'ph') or ($nid eq 'fruits-vegetables-nuts') or ($nid eq 'collagen-meat-protein-ratio')) {
				$product_ref->{nutriments}{$nid . "_100g"} = $product_ref->{nutriments}{$nid} + 0.0;
			}
			elsif ($product_ref->{serving_quantity} > 0) {
				
				$product_ref->{nutriments}{$nid . "_100g"} = sprintf("%.2e",$product_ref->{nutriments}{$nid} * 100.0 / $product_ref->{serving_quantity}) + 0.0;
			}
		}
	}

	else {
	
		foreach my $nid (keys %{$product_ref->{nutriments}}) {
			next if $nid =~ /_/;
			$product_ref->{nutriments}{$nid . "_100g"} = $product_ref->{nutriments}{$nid};
			$product_ref->{nutriments}{$nid . "_100g"} =~ s/^(<|environ|max|maximum|min|minimum)( )?//;
			$product_ref->{nutriments}{$nid . "_100g"} += 0.0;
			$product_ref->{nutriments}{$nid . "_serving"} = '';
			
			if (($nid eq 'alcohol') or ($nid =~ /^nutrition-score/) or ($nid eq 'ph') or ($nid eq 'fruits-vegetables-nuts') or ($nid eq 'collagen-meat-protein-ratio')) {
				$product_ref->{nutriments}{$nid . "_serving"} = $product_ref->{nutriments}{$nid} + 0.0;
			}			
			elsif ($product_ref->{serving_quantity} > 0) {
			
				$product_ref->{nutriments}{$nid . "_serving"} = sprintf("%.2e",$product_ref->{nutriments}{$nid} / 100.0 * $product_ref->{serving_quantity}) + 0.0;
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
		
	#return if ($product_ref->{lc} ne 'fr');	# need categories hierarchy in order to identify drinks
	
	#$product_ref->{nutrient_levels_debug} .= " -- start ";
	
	return if ($product_ref->{categories} eq '');	# need categories hierarchy in order to identify drinks
	
	$product_ref->{nutrient_levels_tags} = [];
	$product_ref->{nutrient_levels} = {};

	foreach my $nutrient_level_ref (@nutrient_levels) {
		my ($nid, $low, $high) = @$nutrient_level_ref;
		
		# divide low and high per 2 for drinks
		
		if (has_tag($product_ref, "categories", "en:beverages")) {
			$low = $low / 2;
			$high = $high / 2;		
		}
		
		if ((defined $product_ref->{nutriments}{$nid . "_100g"}) and ($product_ref->{nutriments}{$nid . "_100g"} ne '')) {
		
			if ($product_ref->{nutriments}{$nid . "_100g"} < $low) {
				$product_ref->{nutrient_levels}{$nid} = 'low';
			}
			elsif ($product_ref->{nutriments}{$nid . "_100g"} > $high) {
				$product_ref->{nutrient_levels}{$nid} = 'high';
			}
			else {
				$product_ref->{nutrient_levels}{$nid} = 'moderate';
			}
			push @{$product_ref->{nutrient_levels_tags}}, get_fileid(sprintf(lang("nutrient_in_quantity"), $Nutriments{$nid}{$lc}, lang($product_ref->{nutrient_levels}{$nid} . "_quantity")));
		
		}
		else {
			delete $product_ref->{nutrient_levels}{$nid};
		}
			#$product_ref->{nutrient_levels_debug} .= " -- nid: $nid - low: $low - high: $high - level: " . $product_ref->{nutrient_levels}{$nid} . " -- value: " . $product_ref->{nutriments}{$nid . "_100g"} . " --- ";
		
	}
	
}


sub compare_nutriments($$) {

	my $a_ref = shift; # can be a product, a category, ajr etc. -> needs {nutriments}{$nid} values
	my $b_ref = shift;	
	
	my %nutriments = ();
	
	foreach my $nid (keys %{$b_ref->{nutriments}}) {
		next if $nid !~ /_100g$/;
		# print STDERR "Food.pm - compare_nutriments - $nid\n";
		if ($b_ref->{nutriments}{$nid} ne '') {
			$nutriments{$nid} = $b_ref->{nutriments}{$nid};
			if (($b_ref->{nutriments}{$nid} > 0) and (defined $a_ref->{nutriments}{$nid}) and ($a_ref->{nutriments}{$nid} ne '')){
				$nutriments{"${nid}_%"} = ($a_ref->{nutriments}{$nid} - $b_ref->{nutriments}{$nid})/ $b_ref->{nutriments}{$nid} * 100;
			}
			# print STDERR "Food.pm - compare_nutriments - $nid : $nutriments{$nid} , " . $nutriments{"$nid.%"} . "%\n";
		}
	}
	
	return \%nutriments;
	
}



foreach my $key (keys %Nutriments) {
	if (not exists $Nutriments{$key}{unit}) {
		$Nutriments{$key}{unit} = 'g';
	}
	if (exists $Nutriments{$key}{fr}) {
		foreach my $l (@Langs) {
			next if $l eq 'fr';
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
	
	sub normalize_fr_ce_code($$) {
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
	}
	
	sub normalize_uk_ce_code($$) {
		my $countrycode = shift;
		my $code = shift;
		$countrycode = uc($countrycode);
		$code = uc($code);
		$code =~ s/\s|-|_|\.|\///g;
		return "$countrycode $code EC";
	}
	
	sub normalize_es_ce_code($$$$) {
		my $countrycode = shift;
		my $code1 = shift;
		my $code2 = shift;
		my $code3 = shift;
		$countrycode = uc($countrycode);
		$code3 = uc($code3);
		return "$countrycode $code1.$code2/$code3 CE";
	}	

	sub normalize_ce_code($$) {
		my $countrycode = shift;
		my $code = shift;
		$countrycode = uc($countrycode);
		$code = uc($code);
		return "$countrycode $code EC";
	}		
	
	# CE codes -- FR 67.145.01 CE
	#$codes =~ s/(^|,|, )(fr)(\s|-|_|\.)?((\d|\.|_|\s|-)+)(\.|_|\s|-)?(ce)?\b/$1 . normalize_fr_ce_code($2,$4)/ieg;	 # without CE, only for FR
	$codes =~ s/(^|,|, )(fr)(\s|-|_|\.)?((\d|\.|_|\s|-)+?)(\.|_|\s|-)?(ce|eec|ec|eg)\b/$1 . normalize_fr_ce_code($2,$4)/ieg;	
	
	$codes =~ s/(^|,|, )(uk)(\s|-|_|\.)?((\w|\.|_|\s|-)+?)(\.|_|\s|-)?(ce|eec|ec|eg)\b/$1 . normalize_uk_ce_code($2,$4)/ieg;	
	$codes =~ s/(^|,|, )(uk)(\s|-|_|\.|\/)*((\w|\.|_|\s|-|\/)+?)(\.|_|\s|-)?(ce|eec|ec|eg)\b/$1 . normalize_uk_ce_code($2,$4)/ieg;	
	
	# NO-RGSEAA-21-21552-SE -> ES 21.21552/SE
	
	
	$codes =~ s/(^|,|, )n(o|°|º)?(\s|-|_|\.)?rgseaa(\s|-|_|\.|:|;)*(\d\d)(\s|-|_|\.)?(\d+)(\s|-|_|\.|\/|\\)?(\w+)\b/$1 . normalize_es_ce_code('es',$5,$7,$9)/ieg;
	$codes =~ s/(^|,|, )(es)(\s|-|_|\.)?(\d\d)(\s|-|_|\.|:|;)*(\d+)(\s|-|_|\.|\/|\\)?(\w+)(\.|_|\s|-)?(ce|eec|ec|eg)?\b/$1 . normalize_es_ce_code('es',$4,$6,$8)/ieg;
	
	$codes =~ s/(^|,|, )(\w\w)(\s|-|_|\.|\/)*((\w|\.|_|\s|-|\/)+?)(\.|_|\s|-)?(ce|eec|ec|eg|we)\b/$1 . normalize_ce_code($2,$4)/ieg;	
	
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


1;

