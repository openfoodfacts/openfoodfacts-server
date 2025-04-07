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

=encoding UTF-8

=head1 NAME

ProductOpener::Ingredients - process and analyze ingredients lists

=head1 SYNOPSIS

C<ProductOpener::Ingredients> processes, normalize, parses and analyze
ingredients lists to extract and recognize individual ingredients,
additives and allergens, and to compute product properties related to
ingredients (is the product vegetarian, vegan, does it contain palm oil etc.)

    use ProductOpener::Ingredients qw/:all/;

	[..]

	clean_ingredients_text($product_ref);

	extract_ingredients_from_text($product_ref);

	extract_additives_from_text($product_ref);

	detect_allergens_from_text($product_ref);

=head1 DESCRIPTION

[..]

=cut

package ProductOpener::Ingredients;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(

		&parse_ingredients_text_service
		&extend_ingredients_service
		&estimate_ingredients_percent_service

		&extract_ingredients_from_image

		&separate_additive_class

		&split_generic_name_from_ingredients
		&clean_ingredients_text_for_lang
		&cut_ingredients_text_for_lang
		&clean_ingredients_text
		&select_ingredients_lc

		&detect_allergens_from_text
		&get_allergens_taxonomyid

		&normalize_a_of_b
		&normalize_enumeration

		&extract_additives_from_text
		&extract_ingredients_from_text
		&preparse_ingredients_text

		&flatten_sub_ingredients

		&compute_ingredients_percent_min_max_values
		&delete_ingredients_percent_values
		&compute_ingredients_percent_estimates

		&estimate_nutriscore_2021_milk_percent_from_ingredients
		&estimate_nutriscore_2023_red_meat_percent_from_ingredients

		&has_specific_ingredient_property

		&init_origins_regexps
		&match_ingredient_origin
		&parse_origins_from_text

		&assign_property_to_ingredients

		&get_ingredients_with_property_value
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;
use experimental 'smartmatch';

use ProductOpener::Store qw/get_string_id_for_lang unac_string_perl/;
use ProductOpener::Config qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Products qw/remove_fields/;
use ProductOpener::URL qw/:all/;
use ProductOpener::Images qw/extract_text_from_image/;
use ProductOpener::Lang qw/$lc %Lang lang/;
use ProductOpener::Units qw/normalize_quantity/;
use ProductOpener::Food qw/is_fat_oil_nuts_seeds_for_nutrition_score/;

use Encode;
use Clone qw(clone);

use LWP::UserAgent;
use Encode;
use JSON::MaybeXS;
use Log::Any qw($log);
use List::MoreUtils qw(uniq);
use Data::DeepAccess qw(deep_get deep_exists);

# MIDDLE DOT with common substitutes (BULLET variants, BULLET OPERATOR and DOT OPERATOR (multiplication))
# U+00B7 "·" (Middle Dot). Is a common character in Catalan. To avoid to break ingredients,
#  spaces are added before and after the symbol hereafter.
# U+2022 "•" (Bullet)
# U+2023 "‣" (Triangular Bullet )
# U+25E6 "◦" (White Bullet)
# U+2043 "⁃" (Hyphen Bullet)
# U+204C "⁌" (Black Leftwards Bullet)
# U+204D "⁍" (Black Rightwards Bullet)
# U+2219 "∙" (Bullet Operator )
# U+22C5 "⋅" (Dot Operator)
# U+30FB "・" (Katakana Middle Dot)
my $middle_dot
	= qr/(?: \N{U+00B7} |\N{U+2022}|\N{U+2023}|\N{U+25E6}|\N{U+2043}|\N{U+204C}|\N{U+204D}|\N{U+2219}|\N{U+22C5}|\N{U+30FB})/i;

# Unicode category 'Punctuation, Dash', SWUNG DASH and MINUS SIGN
my $dashes = qr/(?:\p{Pd}|\N{U+2053}|\N{U+2212})/i;

# ',' and synonyms - COMMA, SMALL COMMA, FULLWIDTH COMMA, IDEOGRAPHIC COMMA, SMALL IDEOGRAPHIC COMMA, HALFWIDTH IDEOGRAPHIC COMMA, ARABIC COMMA
my $commas = qr/(?:\N{U+002C}|\N{U+FE50}|\N{U+FF0C}|\N{U+3001}|\N{U+FE51}|\N{U+FF64}|\N{U+060C})/i;

# '.' and synonyms - FULL STOP, SMALL FULL STOP, FULLWIDTH FULL STOP, IDEOGRAPHIC FULL STOP, HALFWIDTH IDEOGRAPHIC FULL STOP
my $stops = qr/(?:\N{U+002E}|\N{U+FE52}|\N{U+FF0E}|\N{U+3002}|\N{U+FE61})/i;

# '(' and other opening brackets ('Punctuation, Open' without QUOTEs)
# U+201A "‚" (Single Low-9 Quotation Mark)
# U+201E "„" (Double Low-9 Quotation Mark)
# U+276E "❮" (Heavy Left-Pointing Angle Quotation Mark Ornament)
# U+2E42 "⹂" (Double Low-Reversed-9 Quotation Mark)
# U+301D "〝" (Reversed Double Prime Quotation Mark)
# U+FF08 "（" (Fullwidth Left Parenthesis) used in some countries (Japan)
my $obrackets = qr/(?![\N{U+201A}|\N{U+201E}|\N{U+276E}|\N{U+2E42}|\N{U+301D}|\N{U+FF08}])[\p{Ps}]/i;

# ')' and other closing brackets ('Punctuation, Close' without QUOTEs)
# U+276F "❯" (Heavy Right-Pointing Angle Quotation Mark Ornament )
# U+301E "⹂" (Double Low-Reversed-9 Quotation Mark)
# U+301F "〟" (Low Double Prime Quotation Mark)
# U+FF09 "）" (Fullwidth Right Parenthesis) used in some countries (Japan)
my $cbrackets = qr/(?![\N{U+276F}|\N{U+301E}|\N{U+301F}|\N{U+FF09}])[\p{Pe}]/i;

# U+FF0F "／" (Fullwidth Solidus) used in some countries (Japan)
my $separators_except_comma = qr/(;|:|$middle_dot|\[|\{|\(|\N{U+FF08}|( $dashes ))|(\/|\N{U+FF0F})/i
	;    # separators include the dot . followed by a space, but we don't want to separate 1.4 etc.

my $separators = qr/($stops\s|$commas|$separators_except_comma)/i;

# Symbols to indicate labels like organic, fairtrade etc.
my @symbols = ('\*\*\*', '\*\*', '\*', '°°°', '°°', '°', '\(1\)', '\(2\)', '¹', '²');
my $symbols_regexp = join('|', @symbols);

# do not add sub ( ) in the regexps below as it would change which parts gets matched in $1, $2 etc. in other regexps that use those regexps
# put the longest strings first, so that we can match "possible traces" before "traces"
my %may_contain_regexps = (

	en =>
		"it may contain traces of|possible traces|traces|may also contain|also may contain|may contain|may be present|Produced in a factory handling",
	bg => "продуктът може да съдържа следи от|mоже да съдържа следи от|може да съдържа",
	bs => "može da sadrži",
	ca => "pot contenir",
	cs => "může obsahovat|může obsahovat stopy",
	da => "produktet kan indeholde|kan indeholde spor af|kan indeholde spor|eventuelle spor|kan indeholde|mulige spor",
	de => "Kann enthalten|Kann Spuren|Spuren|Kann Anteile|Anteile|Kann auch|Kann|Enthält möglicherweise",
	el => "Μπορεί να περιέχει ίχνη από",
	es => "puede contener huellas de|puede contener trazas de|puede contener|trazas|traza",
	et => "võib sisaldada vähesel määral|võib sisaldada|võib sisalda",
	fi =>
		"saattaa sisältää pienehköjä määriä muita|saattaa sisältää pieniä määriä muita|saattaa sisältää pienehköjä määriä|saattaa sisältää pieniä määriä|voi sisältää vähäisiä määriä|saattaa sisältää hivenen|saattaa sisältää pieniä|saattaa sisältää jäämiä|sisältää pienen määrän|jossa käsitellään myös|saattaa sisältää myös|joka käsittelee myös|jossa käsitellään|saattaa sisältää",
	fr =>
		"peut également contenir|peut contenir|qui utilise|utilisant|qui utilise aussi|qui manipule|manipulisant|qui manipule aussi|traces possibles|traces d'allergènes potentielles|trace possible|traces potentielles|trace potentielle|traces éventuelles|traces eventuelles|trace éventuelle|trace eventuelle|traces|trace|Traces éventuelles de|Peut contenir des traces de",
	hr =>
		"mogući ostaci|mogući sadržaj|mogući tragovi|može sadržavati|može sadržavati alergene u tragovima|može sadržavati tragove|može sadržavati u tragovima|može sadržati|može sadržati tragove|proizvod može sadržavati|proizvod može sadržavati tragove",
	hu => "tartalmazhat",
	is => "getur innihaldið leifar|gæti innihaldið snefil|getur innihaldið",
	it =>
		"Pu[òo] contenere tracce di|pu[òo] contenere|che utilizza anche|possibili tracce|eventuali tracce|possibile traccia|eventuale traccia|tracce|traccia",
	lt => "sudėtyje gali būti|gali būti",
	lv => "var saturēt|sastāva var but",
	mk => "Производот може да содржи",
	nl =>
		"Dit product kan sporen van|bevat mogelijk sporen van|Kan sporen bevatten van|Kan sporen van|bevat mogelijk|sporen van|Geproduceerd in ruimtes waar|Kan ook",
	nb =>
		"kan inneholde spor av|kan forekomme spor av|kan inneholde spor|kan forekomme spor|kan inneholde|kan forekomme",
	pl =>
		"może zawierać śladowe ilości|produkt może zawierać|może zawierać alergeny|może zawierać ślady|może zawierać|możliwa obecność|możliwa obecność|w produkcie możliwa obecność|wyprodukowano w zakładzie przetwarzającym",
	pt => "pode conter vestígios de|pode conter",
	ro => "poate con[țţt]ine urme de|poate con[țţt]ine|poate con[țţt]in|produsul poate conţine urme de",
	rs => "može sadržati tragove",
	ru => "Могут содержаться следы",
	sk => "výrobok môže obsahovat|môže obsahovať",
	sl => "lahko vsebuje sledi",
	sv =>
		"denna produkt kan innethalla spar av|kan innehålla små mängder|kan innehålla spår av|innehåller spår av|kan innehålla spår|kan innehålla",
);

my %contains_regexps = (

	en => "contains",
	bg => "съдържа",
	ca => "conté",
	da => "indeholder",
	es => "contiene",
	et => "sisaldab",
	fr => "contient",
	hr => "sadrže",
	it => "contengono",
	lt => "yra",
	nl => "bevat",
	pl => "zawiera|zawierają",
	ro => "con[țţt]ine|con[țţt]in",
	sv => "innehåller",
);

my %contains_or_may_contain_regexps = (
	allergens => \%contains_regexps,
	traces => \%may_contain_regexps,
);

my %allergens_stopwords = ();

my %allergens_regexps = ();

# Needs to be called after Tags.pm has loaded taxonomies

=head1 FUNCTIONS

=head2 init_allergens_regexps () - initialize regular expressions needed for ingredients parsing

This function initializes regular expressions needed to parse traces and allergens in ingredients lists.

=cut

sub init_allergens_regexps() {

	# Allergens stopwords

	foreach my $key (sort keys %{$stopwords{"allergens"}}) {
		if ($key =~ /\.strings/) {
			my $allergens_lc = $`;
			$allergens_stopwords{$allergens_lc} = join('|', uniq(@{$stopwords{"allergens"}{$key}}));
			#print STDERR "allergens_regexp - $allergens_lc - " . $allergens_stopwords{$allergens_lc} . "\n";
		}
	}

	# Allergens

	foreach my $allergens_lc (uniq(keys %contains_regexps, keys %may_contain_regexps)) {

		my @allergenssuffixes = ();

		# Add synonyms in target language
		if (defined $translations_to{allergens}) {
			foreach my $allergen (keys %{$translations_to{allergens}}) {
				if (defined $translations_to{allergens}{$allergen}{$allergens_lc}) {
					# push @allergenssuffixes, $translations_to{allergens}{$allergen}{$allergens_lc};
					# the synonyms below also contain the main translation as the first entry

					my $allergens_lc_allergenid
						= get_string_id_for_lang($allergens_lc, $translations_to{allergens}{$allergen}{$allergens_lc});

					foreach my $synonym (@{$synonyms_for{allergens}{$allergens_lc}{$allergens_lc_allergenid}}) {
						# Change parenthesis to dots
						# e.g. chemical formula in Open Beauty Facts ingredients
						$synonym =~ s/\(/./g;
						$synonym =~ s/\)/./g;
						push @allergenssuffixes, $synonym;
					}
				}
			}
		}

		$allergens_regexps{$allergens_lc} = "";

		foreach my $suffix (sort {length($b) <=> length($a)} @allergenssuffixes) {
			# simple singulars and plurals
			my $singular = $suffix;
			$suffix =~ s/s$//;
			$allergens_regexps{$allergens_lc} .= '|' . $suffix . '|' . $suffix . 's';

			my $unaccented_suffix = unac_string_perl($suffix);
			if ($unaccented_suffix ne $suffix) {
				$allergens_regexps{$allergens_lc} .= '|' . $unaccented_suffix . '|' . $unaccented_suffix . 's';
			}

		}
		$allergens_regexps{$allergens_lc} =~ s/^\|//;
	}

	return;
}

# Abbreviations that contain dots.
# The dots interfere with the parsing: replace them with the full name.

my %abbreviations = (

	all => [
		["B. actiregularis", "bifidus actiregularis"],    # Danone trademark
		["B. lactis", "bifidobacterium lactis"],
		["L. acidophilus", "lactobacillus acidophilus"],
		["L. bulgaricus", "lactobacillus bulgaricus"],
		["L. delbrueckii subsp. bulgaricus", "lactobacillus bulgaricus"],
		["Lactobacillus delbrueckii subsp. bulgaricus", "lactobacillus bulgaricus"],
		["L. casei", "lactobacillus casei"],
		["L. lactis", "lactobacillus lactis"],
		["L. delbrueckii subsp. lactis", "lactobacillus lactis"],
		["Lactobacillus delbrueckii subsp. lactis", "lactobacillus lactis"],
		["L. plantarum", "lactobacillus plantarum"],
		["L. reuteri", "lactobacillus reuteri"],
		["L. rhamnosus", "lactobacillus rhamnosus"],
		["S. thermophilus", "streptococcus thermophilus"],
	],

	en => [
		["w/o", "without"],
		["w/", "with "],    # note trailing space
		["vit.", "vitamin"],
		["i.a.", "inter alia"],

	],

	ca => [["vit.", "vitamina"], ["m.g.", "matèria grassa"]],

	da => [
		["bl. a.", "blandt andet"],
		["inkl.", "inklusive"],
		["mod.", "modificeret"],
		["past.", "pasteuriserede"],
		["pr.", "per"],
	],

	de => [["vit.", "vitamin"],],

	es => [["vit.", "vitamina"], ["m.g.", "materia grasa"]],

	fi => [["mikro.", "mikrobiologinen"], ["mm.", "muun muassa"], ["sis.", "sisältää"], ["n.", "noin"],],

	fr => [["vit.", "Vitamine"], ["Mat. Gr.", "Matières Grasses"],],

	hr => [
		["temp.", "temperaturi"],
		["konc.", "koncentrirani"],
		["m.m.", "mliječne masti"],
		["regul. kisel.", "regulator kiselosti"],
		["reg. kis.", "regulator kiselosti"],
		["sv.", "svinjsko"],
		["zgrud.", "zgrudnjavanja"],
	],

	nb => [
		["bl. a.", "blant annet"],
		["inkl.", "inklusive"],
		["papr.", "paprika"],
		["fullherdet kokos - og rapsolje", "fullherdet kokosolje og fullherdet rapsolje"],
		["kons.middel", "konserveringsmiddel"],
		["surhetsreg.midde", "surhetsregulerende middel"],
		["mod.", "modifisert"],
		["fort.middel", "fortykningsmiddel"],
		["veg.", "vegetabilsk"],
	],

	ru => [
		["в/с", "высшего сорта"],    # or "высший сорт". = top grade, superfine. applied to flour.
		["х/п", "хлебопекарная"],    # bakery/baking, also for flour.
	],

	sv => [
		["bl. a.", "bland annat"],
		["förtjockn.medel", "förtjockningsmedel"],
		["inkl.", "inklusive"],
		["kons.medel", "konserveringsmedel"],
		["max.", "maximum"],
		["mikrob.", "mikrobiellt"],
		["min.", "minimum"],
		["mod.", "modifierad"],
		["past.", "pastöriserad"],
		["stabil.", "stabiliseringsämne"],
		["surhetsreg.", "surhetsreglerande"],
		["veg.", "vegetabilisk"],
		["ca.", "cirka"],
	],
);

my %of = (
	en => " of ",
	ca => " de ",
	da => " af ",
	de => " von ",
	es => " de ",
	fr => " de la | de | du | des | d'| de l'",
	is => " af ",
	it => " di | d'",
	nl => " van ",
	nb => " av ",
	sv => " av ",
);

my %from = (
	en => " from ",
	da => " fra ",
	de => " aus ",
	es => " de ",
	fr => " de la | de | du | des | d'| de l'",
	it => " dal | della | dalla | dagli | dall'",
	nl => " uit ",
	pl => " z | ze ",
	sv => " från ",
);

my %and = (
	en => " and ",
	br => " ha | hag ",
	ca => " i ",
	cs => " a ",
	da => " og ",
	de => " und ",
	el => " και ",
	es => " y ",    # Spanish "e" before "i" and "hi" is handled by preparse_text()
	et => " ja ",
	fi => " ja ",
	fr => " et ",
	gl => " e ",
	hr => " i ",
	hu => " és ",
	id => " dan ",
	is => " og ",
	it => " e ",
	lt => " ir ",
	lv => " un ",
	mg => " sy ",
	ms => " dan ",
	nl => " en ",
	nb => " og ",
	nn => " og ",
	oc => " e ",
	pl => " i ",
	pt => " e ",
	ro => " și | şi ",
	ru => " и ",
	sk => " a ",
	sl => " in ",
	sq => " dhe ",
	sv => " och ",
	tl => " at ",
	tr => " ve ",
	uk => " i ",
	uz => " va ",
	vi => " và ",
	yo => " ati ",
);

my %and_of = (
	en => " and of ",
	ca => " i de ",
	da => " og af ",
	de => " und von ",
	es => " y de ",
	fr => " et de la | et de l'| et du | et des | et d'| et de ",
	is => " og af ",
	it => " e di | e d'",
	nb => " og av ",
	sv => " och av ",
);

my %and_or = (
	en => " and | or | and/or | and / or ",
	da => " og | eller | og/eller | og / eller ",
	de => " und | oder | und/oder | und / oder ",
	es => " y | e | o | y/o | y / o ",
	fi => " ja | tai | ja/tai | ja / tai ",
	fr => " et | ou | et/ou | et / ou ",
	hr => " i | ili | i/ili | i / ili ",
	is => " og | eða | og/eða | og / eða ",
	it => " e | o | e/o | e / o",
	ja => "又は",    # or
	nl => " en/of | en / of ",
	nb => " og | eller | og/eller | og / eller ",
	pl => " i | oraz | lub | albo ",
	ru => " и | или | и/или | и / или ",
	sv => " och | eller | och/eller | och / eller ",
);

my %the = (
	en => " the ",
	es => " el | la | los | las ",
	fr => " le | la | les | l'",
	it => " il | lo | la | i | gli | le | l'",
	nl => " de | het ",
);

# Strings to identify phrases like "75g per 100g of finished product"
my %per = (
	en => " per | for ",
	da => " per ",
	es => " por | por cada ",
	fr => " pour | par ",
	hr => " na ",
	it => " per ",
	nl => " per ",
	sv => "((?: bär)|(?:\, varav tillsatt socker \\d+\\s*g))? per ",
);

my $one_hundred_grams_or_ml = '100\s*(?:g|gr|ml)';

my %of_finished_product = (
	en => " of (?:finished )?product",
	es => " de producto(?: terminado| final)?",
	fr => " (?:de|sur) produit(?: fini)?",
	hr => " (?:gotovog )?proizvoda",
	it => " di prodotto(?: finito)?",
	nl => " van het volledige product",
	sv => " sylt",
);

=head1 FUNCTIONS

=head2 init_percent_or_quantity_regexps($ingredients_lc) - initialize regular expressions needed for ingredients parsing

This function creates regular expressions that match quantities or percent of an ingredient,
including localized strings like "minimum"

=cut

# prepared with
my %prepared_with = (
	en => "(?:made|prepared|produced) with",
	da => "fremstillet af",
	es => "elabora con",
	fr => "(?:(?:é|e)labor(?:é|e)|fabriqu(?:é|e)|pr(?:é|e)par(?:é|e)|produit)(?:e)?(?:s)? (?:avec|à partir)",
	hr => "(?:proizvedeno od|sadrži)",
	nl => "bereid met",
	sv => "är",
);

my %min_regexp = (
	en => "min|min\.|minimum",
	ca => "min|min\.|mín|mín\.|mínim|minim",
	cs => "min|min\.",
	es => "min|min\.|mín|mín\.|mínimo|minimo|minimum",
	fr => "min|min\.|mini|minimum",
	hr => "min|min\.|mini|minimum",
	pl => "min|min\.|minimum",
);

my %max_regexp = (
	en => "max|max\.|maximum",
	ca => "max|max\.|màxim",
	cs => "max|max\.",
	es => "max|max\.|máximo",
	fr => "max|max\.|maxi|maximum",
	hr => "max|max\.|maxi|maximum",
	pl => "max|max\.|maximum",
);

# Words that can be ignored after a percent
# e.g. 50% du poids total, 30% of the total weight
# groups need to be non-capturing: prefixed with (?:

my %ignore_strings_after_percent = (
	en => "of (?:the )?(?:total weight|grain is wholegrain rye)",
	es => "(?:en el chocolate(?: con leche)?)",
	fi => "jauhojen määrästä",
	fr => "(?:dans le chocolat(?: (?:blanc|noir|au lait))?)|(?:du poids total|du poids)",
	sv => "fetthalt",
);

my %percent_or_quantity_regexps = ();

sub init_percent_or_quantity_regexps($ingredients_lc) {

	if (not exists $percent_or_quantity_regexps{$ingredients_lc}) {

		my $prepared_with = $prepared_with{$ingredients_lc} || '',

			my $min_regexp = $min_regexp{$ingredients_lc} || '';

		my $max_regexp = $max_regexp{$ingredients_lc} || '';

		my $ignore_strings_after_percent = $ignore_strings_after_percent{$ingredients_lc} || '';

		# Regular expression to find percent or quantities
		# $percent_or_quantity_regexp has 2 capturing group: one for the number, and one for the % sign or the unit
		$percent_or_quantity_regexps{$ingredients_lc} = '(?:' . "(?:$prepared_with )" . ' )?'   # optional produced with
			. '(?:>|' . $max_regexp . '|<|' . $min_regexp . '|\s|\.|:)*'    # optional maximum, minimum, and separators
			. '(?:\d+(?:[,.]\d+)?\s*-\s*?)?'    # number+hyphens, first part (10-) of "10-12%"
			. '(\d+(?:(?:\,|\.)\d+)?)\s*'    # number, possibly with a dot or comma
			. '(\%|g|gr|mg|kg|ml|cl|dl|l)\s*'    # % or unit
			. '(?:' . $min_regexp . '|' . $max_regexp . '|'    # optional minimum, optional maximum
			. $ignore_strings_after_percent . '|\s|\)|\]|\}|\*)*';    # strings that can be ignored
	}

	return;
}

# Labels that we want to recognize in the ingredients
# e.g. "fraises issues de l'agriculture biologique"

# Put composed labels like fair-trade-organic first
# There is no need to add labels in every language, synonyms are used automatically
my @labels = (
	"en:fair-trade-organic", "en:organic",
	"en:fair-trade", "en:pgi",
	"en:pdo", "fr:label-rouge",
	"en:sustainable-seafood-msc", "en:responsible-aquaculture-asc",
	"fr:aoc", "en:vegan",
	"en:vegetarian", "nl:beter-leven-1-ster",
	"nl:beter-leven-2-ster", "nl:beter-leven-3-ster",
	"en:halal", "en:kosher",
	"en:fed-without-gmos", "fr:crc",
	"en:without-gluten", "en:sustainable-farming",
	"en:krav",
);
my %labels_regexps = ();

# Needs to be called after Tags.pm has loaded taxonomies

=head2 init_labels_regexps () - initialize regular expressions needed for ingredients parsing

This function creates regular expressions that match all variations of labels
that we want to recognize in ingredients lists, such as organic and fair trade.

=cut

sub init_labels_regexps() {

	foreach my $labelid (@labels) {

		# Canonicalize the label ids in case the normalized id changed
		$labelid = canonicalize_taxonomy_tag("en", "labels", $labelid);

		foreach my $label_lc (keys %{$translations_to{labels}{$labelid}}) {

			# the synonyms below also contain the main translation as the first entry

			my $label_lc_labelid = get_string_id_for_lang($label_lc, $translations_to{labels}{$labelid}{$label_lc});

			my @synonyms = ();

			foreach my $synonym (@{$synonyms_for{labels}{$label_lc}{$label_lc_labelid}}) {
				push @synonyms, $synonym;

				# In Spanish, when preparsing ingredients text, we will replace " e " by " y ".
				# also replace and / or by and to match labels

				my $synonym2 = $synonym;
				# replace "and / or" by "and"
				# except if followed by a separator, a digit, or "and", to avoid false positives
				my $and_or = ' - ';
				my $and = $and{$label_lc} || " and ";
				my $and_without_spaces = $and;
				$and_without_spaces =~ s/^ //;
				$and_without_spaces =~ s/ $//;
				if (defined $and_or{$label_lc}) {
					$and_or = $and_or{$label_lc};
					$synonym2 =~ s/($and_or)(?!($and_without_spaces |\d|$separators))/$and/ig;
					if ($synonym2 ne $synonym) {
						push @synonyms, $synonym2;
					}
				}
			}

			# also add the xx: entries and synonyms
			if (($label_lc ne "xx") and (defined $translations_to{labels}{$labelid}{"xx"})) {
				my $label_xx_labelid = get_string_id_for_lang("xx", $translations_to{labels}{$labelid}{"xx"});

				foreach my $synonym (@{$synonyms_for{labels}{"xx"}{$label_xx_labelid}}) {
					push @synonyms, $synonym;
				}
			}

			my $label_regexp = "";
			foreach my $synonym (sort {length($b) <=> length($a)} @synonyms) {

				# IGP - Indication Géographique Protégée -> IGP: Indication Géographique Protégée
				$synonym =~ s/ - /\( - |: | : \)/g;

				# simple singulars and plurals
				my $singular = $synonym;
				$synonym =~ s/s$//;
				$label_regexp .= '|' . $synonym . '|' . $synonym . 's';

				my $unaccented_synonym = unac_string_perl($synonym);
				if ($unaccented_synonym ne $synonym) {
					$label_regexp .= '|' . $unaccented_synonym . '|' . $unaccented_synonym . 's';
				}

			}
			$label_regexp =~ s/^\|//;
			defined $labels_regexps{$label_lc} or $labels_regexps{$label_lc} = {};
			$labels_regexps{$label_lc}{$labelid} = $label_regexp;
			#print STDERR "labels_regexps - label_lc: $label_lc - labelid: $labelid - regexp: $label_regexp\n";
		}
	}

	return;
}

# Ingredients processing regexps

my %ingredients_processing_regexps = ();

sub init_ingredients_processing_regexps() {

	# Create a list of regexps with each synonyms of all ingredients processes
	%ingredients_processing_regexps = %{
		generate_regexps_matching_taxonomy_entries(
			"ingredients_processing",
			"list_of_regexps",
			{
				#add_simple_plurals => 1,
				#add_simple_singulars => 1,
				match_space_with_dash => 1,
			}
		)
	};

	return;
}

# Origins processing regexps

my %origins_regexps = ();

sub init_origins_regexps() {

	# Create a list of regexps with each synonyms of all ingredients processes
	%origins_regexps = %{
		generate_regexps_matching_taxonomy_entries(
			"origins",
			"unique_regexp",
			{
				match_space_with_dash => 1,
			}
		)
	};

	return;
}

# Additives classes regexps

my %additives_classes_regexps = ();

sub init_additives_classes_regexps() {

	# Create a regexp with all synonyms of all additives classes
	%additives_classes_regexps = %{
		generate_regexps_matching_taxonomy_entries(
			"additives_classes",
			"unique_regexp",
			{
				add_simple_plurals => 1,
				add_simple_singulars => 1,
				# 2022-09-22: not sure if the following is still needed
				# before refactoring, we had a comment about not turning
				# "vitamin A" into "vitamin : A", but it does not happen
				# skip_entries_matching => '/^en:vitamins$/',
			}
		)
	};

	return;
}

if ((keys %labels_regexps) > 0) {exit;}

sub extract_ingredients_from_image ($product_ref, $id, $ocr_engine, $results_ref) {

	my $lc = $product_ref->{lc};

	if ($id =~ /_(\w\w)$/) {
		$lc = $1;
	}

	extract_text_from_image($product_ref, $id, "ingredients_text_from_image", $ocr_engine, $results_ref);

	# remove nutrition facts etc.
	if (($results_ref->{status} == 0) and (defined $results_ref->{ingredients_text_from_image})) {

		$results_ref->{ingredients_text_from_image_orig} = $product_ref->{ingredients_text_from_image};
		$results_ref->{ingredients_text_from_image}
			= cut_ingredients_text_for_lang($results_ref->{ingredients_text_from_image}, $lc);
	}

	return;
}

=head2 has_specific_ingredient_property ( product_ref, searched_ingredient_id, property )

Check if the specific ingredients structure (extracted from the end of the ingredients list and product labels)
contains a property for an ingredient. (e.g. do we have an origin specified for a specific ingredient)

=head3 Arguments

=head4 product_ref

=head4 searched_ingredient_id

If the ingredient_id parameter is undef, then we return the value for any specific ingredient.
(useful for products for which we do not have ingredients, but for which we have a label like "French eggs":
we can still derive the origin of the ingredients, e.g. for the Environmental-Score)

=head4 property

e.g. "origins"

=head3 Return values

=head4 value

- undef if we don't have a specific ingredient with the requested property matching the requested ingredient
- otherwise the value for the matching specific ingredient

=cut

sub has_specific_ingredient_property ($product_ref, $searched_ingredient_id, $property) {

	my $value;

	# If we have specific ingredients, check if we have a parent of searched ingredient
	if (defined $product_ref->{specific_ingredients}) {
		foreach my $specific_ingredient_ref (@{$product_ref->{specific_ingredients}}) {
			my $specific_ingredient_id = $specific_ingredient_ref->{id};
			if (
				(
					defined $specific_ingredient_ref->{$property}
				)    # we have a value for the property for the specific ingredient
					 # and we did not target a specific ingredient, or this is equivalent to the searched ingredient
				and (  (not defined $searched_ingredient_id)
					or (is_a("ingredients", $searched_ingredient_id, $specific_ingredient_id)))
				)
			{

				if (not defined $value) {
					$value = $specific_ingredient_ref->{$property};
				}
				elsif ($specific_ingredient_ref->{$property} ne $value) {
					$log->warn(
						"has_specific_ingredient_property: different values for property",
						{
							searched_ingredient_id => $searched_ingredient_id,
							property => $property,
							current_value => $value,
							specific_ingredient_id => $specific_ingredient_id,
							new_value => $specific_ingredient_ref->{$property}
						}
					) if $log->is_warn();
				}
			}
		}
	}

	return $value;
}

=head2 add_properties_from_specific_ingredients ( product_ref )

Go through the ingredients structure, and add properties to ingredients that match specific ingredients
for which we have extra information (e.g. origins from a label).

=cut

sub add_properties_from_specific_ingredients ($product_ref) {

	return if not defined $product_ref->{ingredients};

	# Traverse the ingredients tree, breadth first
	my @ingredients = @{$product_ref->{ingredients}};

	while (@ingredients) {

		# Remove and process the first ingredient
		my $ingredient_ref = shift @ingredients;
		my $ingredientid = $ingredient_ref->{id};

		# Add sub-ingredients at the beginning of the ingredients array
		if (defined $ingredient_ref->{ingredients}) {

			unshift @ingredients, @{$ingredient_ref->{ingredients}};
		}

		foreach my $property (qw(origins)) {
			my $property_value = has_specific_ingredient_property($product_ref, $ingredientid, $property);
			if ((defined $property_value) and (not defined $ingredient_ref->{$property})) {
				$ingredient_ref->{$property} = $property_value;
			}
		}
	}
	return;
}

=head2 add_percent_max_for_ingredients_from_nutrition_facts ( $product_ref )

Add a percent_max value for salt and sugar ingredients, based on the nutrition facts.

=cut

sub add_percent_max_for_ingredients_from_nutrition_facts ($product_ref) {

	# Check if we have values for salt and sugar in the nutrition facts
	my @ingredient_max_values = ();
	my $sugars_100g = deep_get($product_ref, qw(nutriments sugars_100g));
	if (defined $sugars_100g) {
		push @ingredient_max_values, {ingredientid => "en:sugar", value => $sugars_100g};
	}
	my $salt_100g = deep_get($product_ref, qw(nutriments salt_100g));
	if (defined $salt_100g) {
		push @ingredient_max_values, {ingredientid => "en:salt", value => $salt_100g};
	}

	if (scalar @ingredient_max_values) {

		# Traverse the ingredients tree, depth first

		my @ingredients = @{$product_ref->{ingredients}};

		while (@ingredients) {

			# Remove and process the first ingredient
			my $ingredient_ref = shift @ingredients;
			my $ingredientid = $ingredient_ref->{id};

			# Add sub-ingredients at the beginning of the ingredients array
			if (defined $ingredient_ref->{ingredients}) {

				unshift @ingredients, @{$ingredient_ref->{ingredients}};
			}

			foreach my $ingredient_max_value_ref (@ingredient_max_values) {
				my $value = $ingredient_max_value_ref->{value};
				if (is_a("ingredients", $ingredient_ref->{id}, $ingredient_max_value_ref->{ingredientid})) {
					if (not defined $ingredient_ref->{percent_max}) {
						$ingredient_ref->{percent_max} = $value;
					}
				}

			}
		}
	}
	return;
}

=head2 add_specific_ingredients_from_labels ( product_ref )

Check if the product has labels that indicate properties (e.g. origins) for specific ingredients.

e.g.

en:French pork
fr:Viande Porcine Française, VPF, viande de porc française, Le Porc Français, Porc Origine France, porc français, porc 100% France
origins:en: en:france
ingredients:en: en:pork

This function extracts those mentions and adds them to the specific_ingredients structure.

=head3 Return values

=head4 specific_ingredients structure

Array of specific ingredients.

=head4 

=cut

sub add_specific_ingredients_from_labels ($product_ref) {

	if (defined $product_ref->{labels_tags}) {
		foreach my $labelid (@{$product_ref->{labels_tags}}) {
			my $ingredients = get_property("labels", $labelid, "ingredients:en");
			if (defined $ingredients) {
				my $origins = get_property("labels", $labelid, "origins:en");

				if (defined $origins) {

					my $ingredient_id = canonicalize_taxonomy_tag("en", "ingredients", $ingredients);

					my $specific_ingredients_ref = {
						id => $ingredient_id,
						ingredient => $ingredients,
						label => $labelid,
						origins => join(",", map {canonicalize_taxonomy_tag("en", "origins", $_)} split(/,/, $origins))
					};

					push @{$product_ref->{specific_ingredients}}, $specific_ingredients_ref;
				}
			}
		}
	}
	return;
}

=head2 parse_specific_ingredients_from_text ( product_ref, $text, $percent_or_quantity_regexp, $per_100g_regexp )

Lists of ingredients sometime include extra mentions for specific ingredients
at the end of the ingredients list. e.g. "Prepared with 50g of fruits for 100g of finished product".

This function extracts those mentions and adds them to the specific_ingredients structure.

This function is also used to parse the origins of ingredients field.

=head3 Arguments

=head4 product_ref

=head4 text $text

=head4 percent regular expression $percent_or_quantity_regexp

Used to find % values, language specific.

Pass undef in order to skip % recognition. This is useful if we know the text is only for the origins of ingredients.

=head4 per_100g regular expression $per_100g_regexp

=head3 Return values

=head4 specific_ingredients structure

Array of specific ingredients.

=head4 

=cut

sub parse_specific_ingredients_from_text ($product_ref, $text, $percent_or_quantity_regexp, $per_100g_regexp) {

	my $ingredients_lc = get_or_select_ingredients_lc($product_ref);

	# Go through the ingredient lists multiple times
	# as long as we have one match
	my $ingredient = "start";

	# total or minimum
	my %minimum_or_total = (
		en => "min|minimum|total",
		es => "total",
		fr => "min|minimum|minimal|minimale|total|totale",
		hr => "najmanje|najviše",
		sv => "total",
	);
	my $minimum_or_total = $minimum_or_total{$ingredients_lc} || '';

	# followed by an ingredient (e.g. "total content of fruit")
	my %content_of_ingredient = (
		en => "(?:(?:$minimum_or_total) )?content",
		es => "contenido(?: (?:$minimum_or_total))",
		fr => "(?:teneur|taux)(?: (?:$minimum_or_total))?(?: en)?",   # need to have " en" as it's not in the $of regexp
		hr => "ukupni(?: udio)?|udio",
		sv => "(?:(?:$minimum_or_total) )?mängd",
	);
	my $content_of_ingredient = $content_of_ingredient{$ingredients_lc};

	my $of = $of{$ingredients_lc} || ' ';    # default to space in order to not match an empty string

	# following an ingredient (e.g. "milk content")
	# include space if mandatory
	my %ingredient_content = (
		en => " content",
		sv => "mängd"
	);
	my $ingredient_content = $ingredient_content{$ingredients_lc};

	my $prepared_with = $prepared_with{$ingredients_lc} || '';

	while ($ingredient) {

		# Initialize values
		$ingredient = undef;
		my $matched_ingredient_ref = {};
		my $matched_text;
		my ($percent_or_quantity_value, $percent_or_quantity_unit);
		my $origins;

		# Note: in regular expressions below, use non-capturing groups (starting with (?: )
		# for all groups, except groups that capture actual data: ingredient name, percent, origins

		# Regexps should match until we reach a , . ; - or the end of the text

		$log->debug("parse_specific_ingredients_from_text - text: $text") if $log->is_debug();

		# text in this order: ingredient - quantity - percent
		# e.g.
		# - minimum content of fruit : 150g
		# - fruit content: minimum 80%
		# - total fruit content: 150g per 100g
		if (
			(defined $percent_or_quantity_regexp)
			and (
				(
					# fruit content: 50%, minimum fruit content 40g per 100g
					# sv: Fruktmängd: 50g per 100g (no space)

					(defined $ingredient_content)
					# optional minimum, followed by ingredient, content, : and/or spaces, percent or quantity, optional per 100g, separator
					and ($text
						=~ /((?:^|;|,|\.| - )\s*)(?:(?:$minimum_or_total) )?\s*([^,.;]+?)\s*(?:$ingredient_content)(?::|\s)+$percent_or_quantity_regexp\s*(?:$per_100g_regexp)?(?:;|,|\.| - |$)/i
					)

				)
				or (
					# minimum content of fruit: 150% / content of fruit: 150g per 100g of finished product
					# (fr) teneur en citron de 40%
					(defined $content_of_ingredient)
					and (
						# content, of or : or space, ingredient, percent or quantity, optional per 100g, separator
						$text
						=~ /((?:^|;|,|\.| - )\s*)(?:$content_of_ingredient)(?:$of|\s|:)+([^,.;]+?)(?:$of|\s)+$percent_or_quantity_regexp\s*(?:$per_100g_regexp)?(?:;|,|\.| - |$)/i
					)
				)

			)
			)
		{
			$log->debug("parse_specific_ingredients_from_text - text in this order: ingredient - quantity - percent")
				if $log->is_debug();

			my $before = $1;
			$ingredient = $2;
			# 2 groups captured by $percent_or_quantity_regexp:
			$percent_or_quantity_value = $3;
			$percent_or_quantity_unit = $4;
			$matched_text = $&;
			# Remove the matched text
			$text = $` . $1 . ' ' . $';

			$log->debug("parse_specific_ingredients_from_text - ingredient: $ingredient") if $log->is_debug();
			$log->debug("parse_specific_ingredients_from_text - percent_or_quantity_value: $percent_or_quantity_value")
				if $log->is_debug();
			$log->debug("parse_specific_ingredients_from_text - percent_or_quantity_unit: $percent_or_quantity_unit")
				if $log->is_debug();
		}
		# text in this order: quantity - ingredient - percent
		# e.g.
		# - 75g of tomatoes per 100g
		# - prepared with 60g of fruits
		# - prepared with 40g of fruits per 100g of finished product
		elsif (
			(
					(defined $percent_or_quantity_regexp)
				and (defined $of)
				and ($of ne "")
				and (defined $per_100g_regexp)
				and ($per_100g_regexp ne "")
			)
			and (
				# if the string does not start with "prepared with", it needs to finish with "per 100g",
				# otherwise we will match items that could be part of the ingredients list such as "75% of tomatoes

				# prepared with, percent, ingredient, optional per 100g, separator
				# $of needs to be first in (?:$of|\s|:) so that " of " is matched by it, instead of the ingredient capturing group
				(
						(defined $prepared_with)
					and ($prepared_with ne "")
					and ($text
						=~ /((?:^|;|,|\.| - )\s*)$prepared_with(?:$of|\s|:)+$percent_or_quantity_regexp(?:$of|\s|:)+\s*([^,.;]+?)\s*(?:$per_100g_regexp)?(?:;|,|\.| - |$)/i
					)
				)
				or
				# percent, ingredient, per 100g, separator
				(
					$text
					=~ /((?:^|;|,|\.| - )\s*)$percent_or_quantity_regexp(?:$of|\s|:)+\s*([^,.;]+?)\s*(?:$per_100g_regexp)(?:;|,|\.| - |$)/i
				)
			)
			)
		{
			$log->debug("parse_specific_ingredients_from_text - text in this order: quantity - ingredient - percent")
				if $log->is_debug();

			my $before = $1;
			# 2 groups captured by $percent_or_quantity_regexp:
			$percent_or_quantity_value = $2;
			$percent_or_quantity_unit = $3;
			$ingredient = $4;    # ([^,.;]+?)
			$matched_text = $&;
			# Remove the matched text
			$text = $` . $1 . ' ' . $';

			$log->debug("parse_specific_ingredients_from_text - ingredient: $ingredient") if $log->is_debug();
			$log->debug("parse_specific_ingredients_from_text - percent_or_quantity_value: $percent_or_quantity_value")
				if $log->is_debug();
			$log->debug("parse_specific_ingredients_from_text - percent_or_quantity_unit: $percent_or_quantity_unit")
				if $log->is_debug();
		}

		if (($ingredients_lc eq "en") || ($ingredients_lc eq "fr")) {
			# Origin of the milk: United Kingdom
			# Origine du Cacao: Pérou
			if (match_origin_of_the_ingredient_origin($ingredients_lc, \$text, $matched_ingredient_ref)) {
				$origins = $matched_ingredient_ref->{origins};
				$ingredient = $matched_ingredient_ref->{ingredient};
				$matched_text = $matched_ingredient_ref->{matched_text};
				# Remove extra spaces
				$ingredient =~ s/\s+$//;
			}
		}

		# If we found an ingredient, save it in specific_ingredients
		if (defined $ingredient) {
			my $ingredient_id
				= get_taxonomyid($ingredients_lc,
				canonicalize_taxonomy_tag($ingredients_lc, "ingredients", $ingredient));

			# remove starting or ending separators in matched text
			$matched_text =~ s/^(;|,|\.| - |\s)+//;
			$matched_text =~ s/(;|,|\.| - |\s)+$//;
			$matched_text =~ s/^\s+//;

			# remove ending separators for ingredient
			$ingredient =~ s/(:|\s)*$//;

			my $specific_ingredients_ref = {
				id => $ingredient_id,
				ingredient => $ingredient,
				text => $matched_text,
			};

			# Add percent and quantity fields

			if (defined $percent_or_quantity_value) {
				my ($percent, $quantity, $quantity_g)
					= get_percent_or_quantity_and_normalized_quantity($percent_or_quantity_value,
					$percent_or_quantity_unit);

				defined $percent and $specific_ingredients_ref->{percent} = $percent + 0;
				defined $quantity and $specific_ingredients_ref->{quantity} = $quantity;
				defined $quantity_g and $specific_ingredients_ref->{quantity_g} = $quantity_g + 0;

			}

			# Add origin field

			my $and_or = $and_or{$ingredients_lc};

			defined $origins
				and $specific_ingredients_ref->{origins}
				= join(",",
				map {canonicalize_taxonomy_tag($ingredients_lc, "origins", $_)} split(/,|$and_or/, $origins));

			push @{$product_ref->{specific_ingredients}}, $specific_ingredients_ref;
		}
	}

	return $text;
}

# Note: in regular expressions below, use non-capturing groups (starting with (?: )
# for all groups, except groups that capture actual data: ingredient name, percent, origins

# Regexps should match until we reach a . ; or the end of the text

sub match_ingredient_origin ($ingredients_lc, $text_ref, $matched_ingredient_ref) {

	my $origins_regexp = $origins_regexps{$ingredients_lc};
	my $and_or = $and_or{$ingredients_lc} || ',';
	my $from = $from{$ingredients_lc} || ':';

	# Strawberries: Spain, Italy and Portugal
	# Strawberries from Spain, Italy and Portugal
	if (defined $origins_regexp) {
		if ($$text_ref
			=~ /\s*([^,.;:]+)(?::|$from)\s*((?:$origins_regexp)(?:(?:,|$and_or)(?:\s?)(?:$origins_regexp))*)\s*(?:,|;|\.| - |$)/i
			)
		{
			# Note: the regexp above does not currently match multiple origins with commas (e.g. "Origins of milk: UK, UE")
			# in order to not overmatch something like "Origin of milk: UK, some other mention."
			# In the future, we could try to be smarter and match more if we can recognize the next words exist in the origins taxonomy.

			$matched_ingredient_ref->{ingredient} = $1;
			$matched_ingredient_ref->{origins} = $2;
			$matched_ingredient_ref->{matched_text} = $&;

			# Remove the matched text
			$$text_ref = $` . ' ' . $';

			return 1;
		}
		# Try to match without a "from" marker (e.g. "Strawberry France")
		elsif ($$text_ref
			=~ /\s*([^,.;:]+)\s+((?:$origins_regexp)(?:(?:,|$and_or)(?:\s?)(?:$origins_regexp))*)\s*(?:,|;|\.| - |$)/i)
		{
			# Note: the regexp above does not currently match multiple origins with commas (e.g. "Origins of milk: UK, UE")
			# in order to not overmatch something like "Origin of milk: UK, some other mention."
			# In the future, we could try to be smarter and match more if we can recognize the next words exist in the origins taxonomy.

			$matched_ingredient_ref->{ingredient} = $1;
			$matched_ingredient_ref->{origins} = $2;
			$matched_ingredient_ref->{matched_text} = $&;

			# keep the matched ingredient only if it is a known ingredient in the taxonomy, in order to avoid false positives
			# e.g. "something made in France" should not be turned into ingredient "something made in" + origin "France"
			if (
				not(
					exists_taxonomy_tag(
						"ingredients",
						canonicalize_taxonomy_tag(
							$ingredients_lc, "ingredients", $matched_ingredient_ref->{ingredient}
						)
					)
				)
				)
			{
				$matched_ingredient_ref = {};
			}
			else {
				# Remove the matched text
				$$text_ref = $` . ' ' . $';

				return 1;
			}
		}
	}
	return 0;
}

sub match_origin_of_the_ingredient_origin ($ingredients_lc, $text_ref, $matched_ingredient_ref) {

	my %origin_of_the_regexp_in_lc = (
		en => "(?:origin of (?:the )?)",
		al => "(?:vendi i origjinës)",
		bg => "(?:страна на произход)",
		cs => "(?:země původu)",
		ca => "(?:origen)",
		es => "(?:origen)",
		fr => "(?:origine (?:de |du |de la |des |de l'))",
		hr => "(?:zemlja (?:porijekla|podrijetla|porekla))",
		hu => "(?:származási hely)",
		it => "(?:paese di (?:molitura|coltivazione del grano))",
		pl => "(?:kraj pochodzenia)",
		ro => "(?:tara de origine)",
		rs => "(?:zemlja porekla)",
		uk => "(?:kраїна походження)",
	);

	my $origin_of_the_regexp = $origin_of_the_regexp_in_lc{$ingredients_lc} || $origin_of_the_regexp_in_lc{en};
	my $origins_regexp = $origins_regexps{$ingredients_lc};
	my $and_or = $and_or{$ingredients_lc} || ',';

	# Origin of the milk: United Kingdom.
	if (
		$origins_regexp
		and ($$text_ref
			=~ /\s*${origin_of_the_regexp}([^,.;:]+)(?::| )+((?:$origins_regexp)(?:(?:,|$and_or)(?:\s?)(?:$origins_regexp))*)\s*(?:,|;|\.| - |$)/i
		)
		)
	{

		$matched_ingredient_ref->{ingredient} = $1;
		$matched_ingredient_ref->{origins} = $2;
		$matched_ingredient_ref->{matched_text} = $&;

		# Remove the matched text
		$$text_ref = $` . ' ' . $';

		# replace and / or
		#$matched_ingredient_ref->{origins} =~ s/($origins_regexp)(?:$and_or)($origins_regexp)/$1,$2/g;

		return 1;
	}
	return 0;
}

=head2 parse_processing_from_ingredient ( $ingredients_lc, $ingredient )

This function extract processing method from one ingredient.
If processing methods are found and remaining ingredient text exists without the processing method,
then, it returns:
	- $processing (concatenate if more than one), 
	- $ingredient (without processing) and 
	- $ingredient_id (without processing)
If it does not result in known ingredient, then it returns the same but unchanged.

=head3 Arguments

=head4 ingredients_lc

language abbreviation (en for English, for example)

=head4 ingredient

string ("pear", for example)

=head3 Return values

=head4 processings_ref

reference to an array of processings

=head4 ingredient

updated ingredient without processing methods

=head4 ingredient_id

English first element for that ingredient (en:pear, for example)

=head4 ingredient_recognized

0 or 1

=cut

sub parse_processing_from_ingredient ($ingredients_lc, $ingredient) {
	my $ingredient_recognized = 0;
	my @processings = ();
	my $debug_parse_processing_from_ingredient = 0;

	# do not match anything if we don't have a translation for "and"
	my $and = $and{$ingredients_lc} || " will not match ";

	# canonicalize_taxonomy_tag also remove stopwords, etc.
	my $ingredient_id = canonicalize_taxonomy_tag($ingredients_lc, "ingredients", $ingredient);

	# return if ingredient exists as is
	if (exists_taxonomy_tag("ingredients", $ingredient_id)) {
		$ingredient_recognized = 1;
	}
	else {

		my $found_a_known_ingredient = 0;
		my $new_ingredient = $ingredient;
		my @new_processings = ();
		my $removed_a_processing = 1;    # remove prefixes / suffixes one by one
		while ($removed_a_processing) {
			$removed_a_processing = 0;

			# First pass: match all prefixes / suffixes at the start and at the end of the ingredient
			# Second pass: possibly match inside the ingredient (e.g. "soupe déshydratée de légumes" -> "soupe de légumes")
			# Don't mix the two passes in order to avoid removing processings that are part of actual ingredients
			# e.g. "pur jus de fruits" -> we don't want to remove "jus" before "pur", so that we can stop at "jus de fruits"

			foreach my $pass ("start_and_end", "inside") {

				# Skip the second pass if we already matched a processing ($removed_a_processing = 1) or if found a known ingredient ($found_a_known_ingredient = 1)
				if ((not $removed_a_processing) and (not $found_a_known_ingredient)) {

					foreach my $ingredient_processing_regexp_ref (@{$ingredients_processing_regexps{$ingredients_lc}}) {
						my $regexp = $ingredient_processing_regexp_ref->[1];

						$debug_parse_processing_from_ingredient
							and $log->trace("processing - checking processing regexps",
							{new_ingredient => $new_ingredient, regexp => $regexp})
							if $log->is_trace();

						if (
							(
								($pass eq "start_and_end") and (
									# match before or after the ingredient, require a space
									(
										#($ingredients_lc =~ /^(en|es|it|fr)$/)
										(
											   ($ingredients_lc eq 'ar')
											or ($ingredients_lc eq 'bg')
											or ($ingredients_lc eq 'bs')
											or ($ingredients_lc eq 'ca')
											or ($ingredients_lc eq 'cs')
											or ($ingredients_lc eq 'el')
											or ($ingredients_lc eq 'en')
											or ($ingredients_lc eq 'es')
											or ($ingredients_lc eq 'fr')
											or ($ingredients_lc eq 'hr')
											or ($ingredients_lc eq 'it')
											or ($ingredients_lc eq 'mk')
											or ($ingredients_lc eq 'pl')
											or ($ingredients_lc eq 'sl')
											or ($ingredients_lc eq 'sr')
										)
										and ($new_ingredient =~ /(^($regexp)\b|\b($regexp)$)/i)
									)

									#  match before or after the ingredient, does not require a space
									or (
										(
											   ($ingredients_lc eq 'de')
											or ($ingredients_lc eq 'hu')
											or ($ingredients_lc eq 'ja')
											or ($ingredients_lc eq 'nl')
										)
										and ($new_ingredient =~ /(^($regexp)|($regexp)$)/i)
									)

									# match after the ingredient, does not require a space
									# match before the ingredient, require a space
									or (
										(
											   ($ingredients_lc eq 'da')
											or ($ingredients_lc eq 'fi')
											or ($ingredients_lc eq 'nb')
											or ($ingredients_lc eq 'no')
											or ($ingredients_lc eq 'nn')
											or ($ingredients_lc eq 'sv')
										)
										and ($new_ingredient =~ /(^($regexp)\b|($regexp)$)/i)
									)
								)
							)
							or (($pass eq "inside") and ($new_ingredient =~ /\b$regexp\b/i))
							)
						{
							$new_ingredient = $` . $';

							$debug_parse_processing_from_ingredient and $log->debug(
								"processing - found processing",
								{
									ingredient => $ingredient,
									new_ingredient => $new_ingredient,
									processing => $ingredient_processing_regexp_ref->[0],
									regexp => $regexp
								}
							) if $log->is_debug();

							$removed_a_processing = 1;

							push @new_processings, $ingredient_processing_regexp_ref->[0];

							# remove starting or ending " and "
							# viande traitée en salaison et cuite -> viande et
							$new_ingredient =~ s/($and)+$//i;
							$new_ingredient =~ s/^($and)+//i;
							# trim leading and trailing whitespaces or hyphens
							$new_ingredient =~ s/(\s|-)+$//;
							$new_ingredient =~ s/^(\s|-)+//;
							# remove extra spaces
							$new_ingredient =~ s/\s+/ /g;

							# Stop if we now have a known ingredient.
							# e.g. "jambon cru en tranches" -> keep "jambon cru".
							my $new_ingredient_id
								= canonicalize_taxonomy_tag($ingredients_lc, "ingredients", $new_ingredient);

							if (exists_taxonomy_tag("ingredients", $new_ingredient_id)) {
								$debug_parse_processing_from_ingredient and $log->debug(
									"processing - found existing ingredient, stop matching",
									{
										ingredient => $ingredient,
										new_ingredient => $new_ingredient,
										new_ingredient_id => $new_ingredient_id
									}
								) if $log->is_debug();

								$found_a_known_ingredient = 1;
							}
							else {
								$debug_parse_processing_from_ingredient
									and $log->debug(
									"processing - NOT found existing ingredient >$new_ingredient_id<, stop matching")
									if $log->is_debug();
							}

							last;
						}
					}
				}
			}
		}
		if ($found_a_known_ingredient) {

			my $new_ingredient_id = canonicalize_taxonomy_tag($ingredients_lc, "ingredients", $new_ingredient);
			if (exists_taxonomy_tag("ingredients", $new_ingredient_id)) {
				$debug_parse_processing_from_ingredient and $log->debug(
					"processing - found existing ingredient after removing processing",
					{
						ingredient => $ingredient,
						new_ingredient => $new_ingredient,
						new_ingredient_id => $new_ingredient_id,
						new_processings => \@new_processings,
					}
				) if $log->is_debug();
				$ingredient = $new_ingredient;
				$ingredient_id = $new_ingredient_id;
				$ingredient_recognized = 1;
				@processings = @new_processings;
			}
			else {
				$debug_parse_processing_from_ingredient and $log->debug(
					"processing - did not find existing ingredient after removing processing",
					{
						ingredient => $ingredient,
						new_ingredient => $new_ingredient,
						new_ingredient_id => $new_ingredient_id,
						new_processinsg => \@new_processings,
					}
				) if $log->is_debug();
			}
		}
	}

	$debug_parse_processing_from_ingredient
		and $log->debug(
		"processing - return",
		{
			processings => \@processings,
			ingredient => $ingredient,
			ingredient_id => $ingredient_id,
			ingredient_recognized => $ingredient_recognized
		}
		) if $log->is_debug();

	return (\@processings, $ingredient, $ingredient_id, $ingredient_recognized);
}

=head2 parse_origins_from_text ( product_ref, $text, $ingredients_lc)

This function parses the origins of ingredients field to extract the origins of specific ingredients.
The origins are stored in the specific_ingredients structure of the product.

Note: this function is similar to parse_specific_ingredients_from_text() that operates on ingredients lists.
The difference is that parse_specific_ingredients_from_text() only extracts and recognizes text that is
an extra mention at the end of an ingredient list (e.g. "Origin of strawberries: Spain"),
while parse_origins_from_text() will also recognize text like "Strawberries: Spain".

=head3 Arguments

=head4 product_ref

=head4 text $text

=head4 $ingredients_lc : language for the origins text

In most cases it is the same as $product_ref->{ingredients_lc}, except if there are no ingredients listed,
in which case we can have origins listed in the main language of the product.

=head3 Return values

=head4 specific_ingredients structure

Array of specific ingredients.

=head4 

=cut

sub parse_origins_from_text ($product_ref, $text, $ingredients_lc) {

	# Normalize single quotes
	$text =~ s/’/'/g;

	# Go through the ingredient lists multiple times
	# as long as we have one match
	my $matched_ingredient = "start";

	while ($matched_ingredient) {

		# Initialize values
		$matched_ingredient = undef;
		my $matched_ingredient_ref = {};
		my $origins;

		# Call match functions to look for different ways to specify origins etc.

		foreach my $match_function_ref (\&match_origin_of_the_ingredient_origin, \&match_ingredient_origin) {
			if ($match_function_ref->($ingredients_lc, \$text, $matched_ingredient_ref)) {

				my $matched_text = $matched_ingredient_ref->{matched_text};
				my $ingredient = $matched_ingredient_ref->{ingredient};
				my $ingredient_id
					= get_taxonomyid($ingredients_lc,
					canonicalize_taxonomy_tag($ingredients_lc, "ingredients", $ingredient));

				# Remove extra spaces
				$ingredient =~ s/\s+$//;
				$matched_text =~ s/^\s+//;

				my $specific_ingredients_ref = {
					id => $ingredient_id,
					ingredient => $ingredient,
					text => $matched_text,
				};

				if (defined $matched_ingredient_ref->{origins}) {
					my $and_or = $and_or{$ingredients_lc};
					$specific_ingredients_ref->{origins} = join(",",
						map {canonicalize_taxonomy_tag($ingredients_lc, "origins", $_)}
							split(/,|$and_or/, $matched_ingredient_ref->{origins}));
				}

				push @{$product_ref->{specific_ingredients}}, $specific_ingredients_ref;

				$matched_ingredient = $ingredient;
				last;
			}
		}
	}

	return $text;
}

=head2 select_ingredients_lc ($product_ref)

Select, set and return the `ingredients_lc` field in $product_ref.

This is the language that will be used to parse ingredients. We first check that ingredients_text_{lang}
exists and is non-empty for the product main language (`lc`), and return it if it does.
Otherwise we look at all languages defined in `languages_codes` for a non-empty `ingredients_text_lang`.

If we find a language with non empty ingredients in ingredients_text_{lang}:
- we copy the value to the `ingredients_text` field in the product
- we set the `ingredients_lc` field in the product and return it,
otherwise we unset it.

=head3 Arguments

=head4 $product_ref

=head3 Return values

=head4 ingredients_lc

Language code for ingredients parsing.

=cut

sub select_ingredients_lc ($product_ref) {
	# Get all languages that have ingredients_text_{lang} defined, capture the language code
	# Note: we don't use language_codes here, as it might not have been computed if we are called from a service
	# with minimal product data
	my @ingredients_text_fields = sort grep {/^ingredients_text_(\w\w)$/} (keys %$product_ref);

	# Put the main language first
	unshift @ingredients_text_fields, "ingredients_text_" . $product_ref->{lc};

	$log->debug("select_ingredients_lc - ingredients_text_fields",
		{ingredients_text_fields => \@ingredients_text_fields})
		if $log->is_debug();

	foreach my $ingredient_text_field (@ingredients_text_fields) {
		if (    (defined $product_ref->{$ingredient_text_field})
			and ($product_ref->{$ingredient_text_field} ne ""))
		{
			$product_ref->{ingredients_text} = $product_ref->{$ingredient_text_field};
			my $language = substr($ingredient_text_field, -2);
			$product_ref->{ingredients_lc} = $language;
			return $language;
		}
	}

	# If we have ingredients_text set (but no ingredients_text_{lang}), we use the main language of the product
	# This might happen with very old revisions before we had language specific fields
	# or in unit test cases
	if (    (defined $product_ref->{ingredients_text})
		and ($product_ref->{ingredients_text} ne "")
		and (defined $product_ref->{lc}))
	{
		$product_ref->{ingredients_lc} = $product_ref->{lc};
		return $product_ref->{lc};
	}
	delete $product_ref->{ingredients_lc};
	return;
}

=head2 get_or_select_ingredients_lc ($product_ref)

Return the ingredients_lc field if already set, otherwise call select_ingredients_lc() to select it.

This function is used in ingredients related services, to ensure that the ingredients_lc field is set.

=cut

sub get_or_select_ingredients_lc ($product_ref) {
	return $product_ref->{ingredients_lc} || select_ingredients_lc($product_ref);
}

=head2 get_percent_or_quantity_and_normalized_quantity($percent_or_quantity_value, $percent_or_quantity_unit)

Used to assign percent or quantity for strings parsed with $percent_or_quantity_regexp.

=head3 Arguments

=head4 percent_or_quantity_value

=head4 percent_or_quantity_unit

=head3 Return values

If the percent_or_quantity_unit is %, we return a defined value for percent, otherwise we return quantity and quantity_g

=head4 percent

=head4 quantity

If the unit is not %, quantity is a concatenation of the quantity value and unit

=head4 quantity_g

Normalized quantity in grams.

=head3 Example

$ingredient = "100% cocoa";	# or "milk 10cl"

if ($ingredient =~ /\s$percent_or_quantity_regexp$/i) {
	$percent_or_quantity_value = $1;
	$percent_or_quantity_unit = $2;

	my ($percent, $quantity, $quantity_g)
		= get_percent_or_quantity_and_normalized_quantity($percent_or_quantity_value, $percent_or_quantity_unit);

=cut

sub get_percent_or_quantity_and_normalized_quantity ($percent_or_quantity_value, $percent_or_quantity_unit) {

	my ($percent, $quantity, $quantity_g);

	if ($percent_or_quantity_unit =~ /\%/) {
		$percent = $percent_or_quantity_value;
	}
	else {
		$quantity = $percent_or_quantity_value . " " . $percent_or_quantity_unit;
		$quantity_g = normalize_quantity($quantity);
	}

	return ($percent, $quantity, $quantity_g);
}

=head2 parse_ingredients_text_service ( $product_ref, $updated_product_fields_ref, $errors_ref )

Parse the ingredients_text field to extract individual ingredients.

This function is a product service that can be run through ProductOpener::ApiProductServices

=head3 Arguments

=head4 $product_ref

product object reference

=head4 $updated_product_fields_ref

reference to a hash of product fields that have been created or updated

=head4 $errors_ref

reference to an array of error messages

=cut

sub parse_ingredients_text_service ($product_ref, $updated_product_fields_ref, $errors_ref) {

	my $debug_ingredients = 0;

	delete $product_ref->{ingredients};

	# indicate that the service is creating the "ingredients" structure
	$updated_product_fields_ref->{ingredients} = 1;

	my $ingredients_lc = get_or_select_ingredients_lc($product_ref);

	if (   (not defined $product_ref->{ingredients_text})
		or ($product_ref->{ingredients_text} eq "")
		or (not defined $ingredients_lc))
	{
		$log->debug(
			"parse_ingredients_text_service - missing ingredients_text or ingredients_lc",
			{ingredients_text => $product_ref->{ingredients_text}, ingredients_lc => $ingredients_lc}
		) if $log->is_debug();
		if ((not defined $product_ref->{ingredients_text}) or ($product_ref->{ingredients_text} eq "")) {

			push @{$errors_ref},
				{
				message => {id => "missing_field"},
				field => {
					id => "ingredients_text",
					impact => {id => "skipped_service"},
					service => {id => "parse_ingredients_text"}
				}
				};
		}
		if (not defined $ingredients_lc) {
			push @{$errors_ref},
				{
				message => {id => "missing_field"},
				field => {
					id => "ingredients_lc",
					impact => {id => "skipped_service"},
					service => {id => "parse_ingredients_text"}
				}
				};
		}

		return;
	}

	my $text = $product_ref->{ingredients_text};

	$log->debug("extracting ingredients from text", {text => $text}) if $log->is_debug();

	$text = preparse_ingredients_text($ingredients_lc, $text);

	$log->debug("preparsed ingredients from text", {text => $text}) if $log->is_debug();

	# Remove allergens and traces that have been preparsed
	# jus de pomme, eau, sucre. Traces possibles de c\x{e9}leri, moutarde et gluten.",
	# -> jus de pomme, eau, sucre. Traces éventuelles : céleri, Traces éventuelles : moutarde, Traces éventuelles : gluten.

	my $traces = $Lang{traces}{$ingredients_lc};
	my $allergens = $Lang{allergens}{$ingredients_lc};
	$text =~ s/\b($traces|$allergens)\s?:\s?([^,\.]+)//ig;

	# unify newline feeds to \n
	$text =~ s/\r\n/\n/g;
	$text =~ s/\R/\n/g;

	# remove ending . and ending whitespaces
	$text =~ s/(\s|\.)+$//;

	# initialize the structure to store the parsed ingredients and specific ingredients
	$product_ref->{ingredients} = [];

	# farine (12%), chocolat (beurre de cacao (15%), sucre [10%], protéines de lait, oeuf 1%) - émulsifiants : E463, E432 et E472 - correcteurs d'acidité : E322/E333 E474-E475, acidifiant (acide citrique, acide phosphorique) - sel : 1% ...

	# assume commas between numbers are part of the name
	# e.g. en:2-Bromo-2-Nitropropane-1,3-Diol, Bronopol
	# replace by a lower comma ‚

	$text =~ s/(\d),(\d)/$1‚$2/g;

	my $and = $and{$ingredients_lc} || " and ";

	my $per = $per{$ingredients_lc} || ' per ';
	my $of_finished_product = $of_finished_product{$ingredients_lc} || '';
	my $per_100g_regexp = "(${per}|\/)${one_hundred_grams_or_ml}(?:$of_finished_product)?";

	my $percent_or_quantity_regexp = $percent_or_quantity_regexps{$ingredients_lc};

	# Extract phrases related to specific ingredients at the end of the ingredients list
	$text = parse_specific_ingredients_from_text($product_ref, $text, $percent_or_quantity_regexp, $per_100g_regexp);

=head2 analyze_ingredient_function($analyze_ingredients_self, $ingredients_ref, $parent_ref, $level, $s)

This function is used to analyze the ingredients text and extract individual ingredients.
It identifies one ingredient at a time, and calls itself recursively to identify other ingredients and sub ingredients

=head3 Arguments

=head4 $analyze_ingredients_self

Reference to itself in order to call itself recursively

=head4 $ingredients_ref

Reference to an array of ingredients that will be filled with the extracted ingredients

=head4 $parent_ref

Reference to the parent ingredient (if any)

=head4 $level

Level of depth of sub ingredients

=head4 $s

Text to analyze

=cut

	my $analyze_ingredients_function = sub ($analyze_ingredients_self, $ingredients_ref, $parent_ref, $level, $s) {

		# print STDERR "analyze_ingredients level $level: $s\n";

		my $last_separator = undef;    # default separator to find the end of "acidifiants : E330 - E472"

		my $after = '';
		my $before = '';
		my $between = '';
		my $between_level = $level;
		my $percent_or_quantity_value = undef;
		my $percent_or_quantity_unit = undef;
		my $origin = undef;
		my $labels = undef;
		my $vegan = undef;
		my $vegetarian = undef;
		my @processings = ();

		$debug_ingredients and $log->debug("analyze_ingredients_function", {string => $s}) if $log->is_debug();
		# find the first separator or ( or [ or : etc.
		if ($s =~ $separators) {

			$before = $`;
			my $sep = $1;
			$after = $';

			$debug_ingredients
				and $log->debug("found the first separator",
				{string => $s, before => $before, sep => $sep, after => $after})
				if $log->is_debug();

			# If the first separator is a column : or a start of parenthesis etc. we may have sub ingredients

			if ($sep =~ /(:|\[|\{|\(|\N{U+FF08})/i) {

				# Single separators like commas and dashes
				my $match = '.*?';    # non greedy match
				my $ending = $last_separator;
				if (not defined $ending) {
					$ending = "$commas|;|:|( $dashes )";
				}
				$ending .= '|$';

				# For parenthesis etc. we will try to find the corresponding ending parenthesis
				if ($sep eq '(') {
					$ending = '\)';
					# Match can include groups with embedded parenthesis
					$match = '([^\(\)]|(\([^\(\)]+\)))*';
				}
				elsif ($sep eq '[') {
					$ending = '\]';
				}
				elsif ($sep eq '{') {
					$ending = '\}';
				}
				# brackets type used in some countries (Japan) "（" and "）"
				elsif ($sep =~ '\N{U+FF08}') {
					$ending = '\N{U+FF09}';
				}

				$ending = '(' . $ending . ')';

				$debug_ingredients and $log->debug("try to match until the ending separator",
					{sep => $sep, ending => $ending, after => $after})
					if $log->is_debug();

				# try to match until the ending separator
				if ($after =~ /^($match)$ending/i) {

					# We have found sub-ingredients
					$between = $1;
					$after = $';

					# Remove dot at the end
					# e.g. (Contains milk.) -> Contains milk.
					$between =~ s/(\s|\.)+$//;

					$debug_ingredients and $log->debug("parse_ingredients_text - sub-ingredients found: $between")
						if $log->is_debug();

					# percent followed by a separator, assume the percent applies to the parent (e.g. tomatoes)
					# tomatoes (64%, origin: Spain)
					# tomatoes (145g per 100g of finished product)
					if (($between =~ $separators) and ($` =~ /^$percent_or_quantity_regexp$/i)) {
						$percent_or_quantity_value = $1;
						$percent_or_quantity_unit = $2;
						# remove what is before the first separator
						$between =~ s/(.*?)$separators//;
						$debug_ingredients
							and $log->debug(
							"separator found after percent",
							{
								between => $between,
								percent_or_quantity_value => $percent_or_quantity_value,
								percent_or_quantity_unit => $percent_or_quantity_unit
							}
							) if $log->is_debug();
					}

					# sel marin (France, Italie)
					# -> if we have origins, put "origins:" before
					if (
						(
							($between =~ /$separators|$and/)
							and (
								exists_taxonomy_tag(
									"origins", canonicalize_taxonomy_tag($ingredients_lc, "origins", $`)
								)
							)
						)
						or ($between =~ /産|製造/)
						)
					{
						# prepend "origins:" in the beginning of the text, that will be reused below
						$between = "origins:" . $between;
					}

					# allergens or traces
					# single allergen in parenthesis, for example: Krupica od durum pšenice (gluten) -> durum wheat semolina (gluten)
					# more than a single allergen is handle just after
					# in Japanese, 豚肉を含む (contains (を含む) pork (豚肉))
					# 一部に卵・小麦・乳成分・大豆を含む (contains (を含む) parts of (一部に), eggs, wheat, milk, soybeans (卵・小麦・乳成分・大豆)
					# 香料(乳由来) (Spices (from milk origin))
					my $cano = canonicalize_taxonomy_tag($ingredients_lc, "allergens", $between);
					$log->debug("parse_ingredients_text - BEFORE $cano.")
						if $log->is_debug();
					$log->debug("parse_ingredients_text - BEFORE2 $ingredients_lc:$between.")
						if $log->is_debug();
					if (
						(
							# only one sub-ingredient
							($between !~ /$separators|$and/)
							and (
								(
									# The ingredient in parenthesis is in the allergens taxonomy
									exists_taxonomy_tag("allergens",
										canonicalize_taxonomy_tag($ingredients_lc, "allergens", $between))
									# The ingredient in parenthesis is the actual allergen, not an ingredient that contains the allergen
									# e.g. in the allergens taxonomy, "cheese" and "parmigiano" are synonyms of "en:milk"
									# because they contain the allergen milk
									# but we don't want to turn "cheese (parmigiano)" to "cheese".
									# The regexp below only contain the main allergen names, not ingredients that contain that allergen
									and (canonicalize_taxonomy_tag($ingredients_lc, "ingredients", $between)
										=~ /^en:(celery|crustacean|egg|fish|gluten|lactose|lupin-bean|lupin|milk|mollusc|mustard|nut|peanut|sesame|sesame-seeds|soy|soya|sulfite|e220)$/
									)
									# Also check that the parent ingredient is not just a label
									# so that we don't transform "MSC (fish)" to just "MSC" with a fish allergen.
									and (
										not exists_taxonomy_tag(
											"labels", canonicalize_taxonomy_tag($ingredients_lc, "labels", $before)
										)
									)
								)
							)
						)
						or ($between =~ /を含む|由来/)
						)
					{
						# prepend ">allergens<:" in the beginning of the text, that will be reused below
						# avoid "allergens:" to avoid false positive (for example, "salt, egg, spice.
						#   allergen advice: for allergens including cereals containing gluten, see ingredients
						#   in bold. May contain traces of nuts.")
						$between = ">allergens<:" . $between;

						$log->debug(
							"parse_ingredients_text - sub-ingredients: single allergen or keyword for allergen.")
							if $log->is_debug();
					}

					# # allergens or traces
					# # 香料(小麦, 大豆) -> Flavoring (wheat, soybean)
					# # 1- first occurence is allergen
					# if (
					# 	($between =~ /$separators|$and/)
					# 	and (
					# 		exists_taxonomy_tag(
					# 			"allergens", canonicalize_taxonomy_tag($ingredients_lc, "allergens", $`)
					# 		)
					# 	)
					# 	)
					# {
					# 	$log->debug("parse_ingredients_text - sub-ingredients: first word is an allergen.")
					# 		if $log->is_debug();

					# 	# 2- all elements should be allergens
					# 	# to avoid false positive. Because allergen can be ingredient (eggs, for example)
					# 	my @between_to_array = split /$separators|$and/, $between;
					# 	my $all_allergens = 1;
					# 	my $exist_allergen_bool;
					# 	foreach my $between_element (@between_to_array) {
					# 		$exist_allergen_bool = exists_taxonomy_tag("allergens",
					# 			canonicalize_taxonomy_tag($ingredients_lc, "allergens", $`));
					# 		if (defined $exist_allergen_bool && !$exist_allergen_bool) {
					# 			$all_allergens = 0;

					# 			$log->debug(
					# 				"parse_ingredients_text - sub-ingredients: further words are not all allergens or are not known."
					# 			) if $log->is_debug();
					# 		}
					# 	}
					# 	if ($all_allergens == 1) {
					# 		# prepend "allergens:" in the beginning of the text, that will be reused below
					# 		$between = "allergens:" . $between;

					# 		$log->debug(
					# 			"parse_ingredients_text - sub-ingredients: further words are allergens as well.")
					# 			if $log->is_debug();
					# 	}

					# }

					$debug_ingredients and $log->debug(
						"initial processing of percent and origins",
						{
							between => $between,
							after => $after,
							percent_or_quantity_value => $percent_or_quantity_value,
							percent_or_quantity_unit => $percent_or_quantity_unit
						}
					) if $log->is_debug();

					if (    ($between =~ $separators)
						and ($` !~ /\s*(origin|origins|origine|alkuperä|ursprung)\s*/i)
						and ($` !~ /\s*(allergens)\s*/i)
						and ($between !~ /^$percent_or_quantity_regexp$/i))
					{
						$between_level = $level + 1;
						$log->debug(
							"parse_ingredients_text - sub-ingredients: between contains a separator and is not origin nor allergen nor has percent",
							{between => $between}
						) if $log->is_debug();
					}
					else {
						# no separator found : 34% ? or single ingredient
						$log->debug(
							"parse_ingredients_text - sub-ingredients: between does not contain a separator or is origin or allergen or has percent",
							{between => $between}
						) if $log->is_debug();

						if ($between =~ /^$percent_or_quantity_regexp(?:$per_100g_regexp)?$/i) {

							$percent_or_quantity_value = $1;
							$percent_or_quantity_unit = $2;
							$log->debug(
								"parse_ingredients_text - sub-ingredients: between is a percent",
								{
									between => $between,
									percent_or_quantity_value => $percent_or_quantity_value,
									percent_or_quantity_unit => $percent_or_quantity_unit
								}
							) if $log->is_debug();
							$between = '';
						}
						else {
							# label? (organic)
							# origin? (origine : France)
							# allergens? (豚肉を含む) - (contains (を含む) pork (豚肉)) - in Japanese allergens are not separated from the ingredients list
							$log->debug("parse_ingredients_text - sub-ingredients: label? origin? allergen? ($between)")
								if $log->is_debug();

							# try to remove the origin and store it as property
							if ($between
								=~ /\s*(?:de origine|d'origine|origine|origin|origins|alkuperä|ursprung|oorsprong)\s?:?\s?\b(.*)$/i
								)
							{
								$log->debug("parse_ingredients_text - sub-ingredients: contains origin in $between")
									if $log->is_debug();

								$between = '';
								# rm first occurence (origin:)
								my $origin_string = $1;

								# rm additional parenthesis and its content that are sub-ingredient of origing (not parsed for now)
								# example: "トマト (輸入又は国産 (未満 5%))"" (i.e., "Tomatoes (imported or domestically produced (less than 5%)))"")
								$origin_string =~ s/\s*\([^)]*\)//g;

								if ($ingredients_lc eq 'ja') {
									# rm all occurences at the end of words (ブラジル産、エチオピア産)
									$origin_string =~ s/(産|製造)//g;
									# remove "and more" その他
									$origin_string =~ s/(?: and )?その他//g;
								}

								# d'origine végétale -> not a geographic origin, add en:vegan
								if ($origin_string =~ /vegetal|végétal/i) {
									$vegan = "en:yes";
									$vegetarian = "en:yes";
								}
								else {

									$origin = join(",",
										map {canonicalize_taxonomy_tag($ingredients_lc, "origins", $_)}
											split(/$commas|$and/, $origin_string));
								}
							}
							# try to remove the allergens and store them as allergens
							# in Japanese allergens are not separated from the ingredients list, instead they are in parenthesis.
							if ($between =~ /\s*(?:>allergens<:)(.*)$/i) {
								$log->debug("parse_ingredients_text - sub-ingredients: contains allergens in $between")
									if $log->is_debug();

								$between = '';
								# rm first occurence (allergens:)
								my $allergen_string = $1;

								if ($ingredients_lc eq 'ja') {
									# if allergens are listed at the end of ingredients list
									# it starts by 一部に
									# it ends by を含む
									$allergen_string =~ s/(一部に|を含む|由来)//g;
								}

								$allergens = join(",",
									map {canonicalize_taxonomy_tag($ingredients_lc, "allergens", $_)}
										split(/$commas|$and|\N{U+30FB}/, $allergen_string));

								if ((defined $product_ref->{"allergens"}) and ($product_ref->{"allergens"} ne "")) {
									$product_ref->{"allergens"} = $product_ref->{"allergens"} . ", " . $allergens;
								}
								else {
									$product_ref->{"allergens"} = $allergens;
								}

								$log->debug("parse_ingredients_text - sub-ingredients: allergens. $allergens")
									if $log->is_debug();

								$log->debug("parse_ingredients_text - sub-ingredients: allergens in product. ",
									$product_ref->{"allergens"})
									if $log->is_debug();

								$log->debug("parse_ingredients_text - sub-ingredients: traces in product. ",
									$product_ref->{"traces"})
									if $log->is_debug();

								$between = '';

							}

							else {
								$log->debug(
									"parse_ingredients_text - sub-ingredients: origin not explicitly written in: $between"
								) if $log->is_debug();

								# origins:   Fraise (France)
								my $originid = canonicalize_taxonomy_tag($ingredients_lc, "origins", $between);
								if (exists_taxonomy_tag("origins", $originid)) {
									$origin = $originid;
									$debug_ingredients
										and
										$log->debug("between is an origin", {between => $between, origin => $origin})
										if $log->is_debug();
									$between = '';
									$log->debug(
										"parse_ingredients_text - sub-ingredients: between is an origin: $between")
										if $log->is_debug();
								}
								# put origins first because the country can be associated with the label "Made in ..."
								# Skip too short entries (1 or 2 letters) to avoid false positives
								elsif (length($between) >= 3) {

									my $labelid = canonicalize_taxonomy_tag($ingredients_lc, "labels", $between);
									if (exists_taxonomy_tag("labels", $labelid)) {
										if (defined $labels) {
											$labels .= ", " . $labelid;
										}
										else {
											$labels = $labelid;
										}

										# some labels are in fact ingredients. e.g. "sustainable palm oil"
										# in that case, add the corresponding ingredient

										my $label_ingredient_id
											= get_inherited_property("labels", $labelid, "ingredients:en");

										$debug_ingredients and $log->debug(
											"between is a known label",
											{
												between => $between,
												label => $labelid,
												label_ingredient_id => $label_ingredient_id
											}
										) if $log->is_debug();

										if (defined $label_ingredient_id) {
											$between = $label_ingredient_id;
										}
										else {
											$between = '';
										}
									}
									else {

										# processing method?
										my $processingid
											= canonicalize_taxonomy_tag($ingredients_lc, "ingredients_processing",
											$between);
										if (exists_taxonomy_tag("ingredients_processing", $processingid)) {
											push @processings, $processingid;
											$debug_ingredients and $log->debug("between is a processing",
												{between => $between, processing => $processingid})
												if $log->is_debug();
											$between = '';
										}
									}

								}
							}

							# for a single ingredient, we used to stay at same level
							# now consider that it is a sub-ingredient anyway:
							$between_level = $level + 1;
						}
					}
				}
				else {
					# ! could not find the ending separator
					$debug_ingredients and $log->debug("could not find an ending separator") if $log->is_debug();
				}
			}
			else {
				# simple separator
				$last_separator = $sep;
			}

			if ($after =~ /^$percent_or_quantity_regexp($separators|$)/i) {
				$percent_or_quantity_value = $1;
				$percent_or_quantity_unit = $2;
				$after = $';
				$debug_ingredients
					and $log->debug(
					"after started with a percent",
					{
						after => $after,
						percent_or_quantity_value => $percent_or_quantity_value,
						percent_or_quantity_unit => $percent_or_quantity_unit
					}
					) if $log->is_debug();
			}
		}
		else {
			# no separator found: only one ingredient
			$debug_ingredients and $log->debug("no separator found, only one ingredient", {string => $s})
				if $log->is_debug();
			$before = $s;
		}

		# remove ending parenthesis
		$before =~ s/(\),\],\])*//;
		# trim leading and trailing whitespaces or hyphens
		$before =~ s/(\s|-)+$//;
		$before =~ s/^(\s|-)+//;

		$debug_ingredients and $log->debug("processed first separator",
			{string => $s, before => $before, between => $between, after => $after})
			if $log->is_debug();

		my @ingredients = ();

		# 2 known ingredients separated by "and" ? -> split them in 2 ingredients
		# We do not split if we found only 1 ingredient, as the "and" could be part of the processing
		# e.g. "cut and fried potatoes" should not be split to "cut" + "fried potatoes"
		if ($before =~ /$and/i) {

			my $ingredient = $before;
			my $ingredient1 = $`;
			my $ingredient2 = $';

			# check if the whole ingredient is an ingredient
			my $canon_ingredient = canonicalize_taxonomy_tag($ingredients_lc, "ingredients", $before);

			if (not exists_taxonomy_tag("ingredients", $canon_ingredient)) {

				$debug_ingredients
					and $log->debug(
					"parse_ingredient_text - and - whole ingredient >$before< containing 'and' is unknown ingredient")
					if $log->is_debug();

				# Create a copy of $ingredients1 and $ingredients2, as we will remove percents to $ingredientX,
				# but we will push $ingredientX_orig if it is a known ingredient after we remove the processing
				my $ingredient1_orig = $ingredient1;
				my $ingredient2_orig = $ingredient2;

				my $ingredients_recognized = 0;

				foreach ($ingredient1, $ingredient2) {
					# Remove percent
					$_ =~ s/\s$percent_or_quantity_regexp$//i;

					# Check if we recognize the ingredient
					(undef, undef, undef, my $is_recognized) = parse_processing_from_ingredient($ingredients_lc, $_);

					$ingredients_recognized += $is_recognized;
				}
				# Did we recognize the two ingredients?
				if ($ingredients_recognized == 2) {

					push @ingredients, ($ingredient1_orig, $ingredient2_orig);
				}
				else {
					$debug_ingredients
						and $log->debug("parse_ingredient_text - and - at least one ingredient of >$before< is unknown")
						if $log->is_debug();
				}
			}
		}

		if (scalar @ingredients == 0) {

			# if we have nothing before, then we can be in the case where between applies to the last ingredient
			# e.g. if we have "Vegetables (97%) (Potatoes, Tomatoes)"
			if (($before =~ /^\s*$/) and ($between !~ /^\s*$/) and ((scalar @{$ingredients_ref}) > 0)) {
				my $last_ingredient = (scalar @{$ingredients_ref}) - 1;
				$debug_ingredients and $log->debug("between applies to last ingredient",
					{between => $between, last_ingredient => $ingredients_ref->[$last_ingredient]{text}})
					if $log->is_debug();

				(defined $ingredients_ref->[$last_ingredient]{ingredients})
					or $ingredients_ref->[$last_ingredient]{ingredients} = [];
				$analyze_ingredients_self->(
					$analyze_ingredients_self, $ingredients_ref->[$last_ingredient]{ingredients},
					$parent_ref, $between_level, $between
				);
			}

			if ($before !~ /^\s*$/) {
				push @ingredients, $before;
			}
		}

		my $i = 0;    # Counter for ingredients, used to know if it is the last ingredient

		# Note: we use a while loop instead of a foreach as we may modify the array @ingredients when we split ingredients
		$debug_ingredients
			and
			$log->debug("initial number of ingredients", {count => scalar @ingredients, ingredients => \@ingredients})
			if $log->is_debug();
		while (@ingredients) {

			my $ingredient = shift @ingredients;
			chomp($ingredient);

			$debug_ingredients and $log->debug("analyzing ingredient", {ingredient => $ingredient})
				if $log->is_debug();

			# Repeat the removal of parts of the ingredient (that corresponds to labels, origins, processing, % etc.)
			# as long as we have removed something and that we haven't recognized the ingredient

			my $current_ingredient = '';
			my $skip_ingredient = 0;
			my $ingredient_recognized = 0;
			my $ingredient_id;

			while (($ingredient ne $current_ingredient) and (not $ingredient_recognized) and (not $skip_ingredient)) {

				$current_ingredient = $ingredient;

				# Strawberry 10.3%
				if ($ingredient =~ /\s$percent_or_quantity_regexp$/i) {
					$percent_or_quantity_value = $1;
					$percent_or_quantity_unit = $2;
					$debug_ingredients and $log->debug(
						"percent found after",
						{
							ingredient => $ingredient,
							percent_or_quantity_value => $percent_or_quantity_value,
							percent_or_quantity_unit => $percent_or_quantity_unit,
							new_ingredient => $`
						}
					) if $log->is_debug();
					$ingredient = $`;
				}

				# 50% beef, 20g of oranges
				# 90% boeuf, 100% pur jus de fruit, 45% de matière grasses
				my $of = $of{$ingredients_lc} || ' ';    # default to space in order to not match an empty string
				if ($ingredient =~ /^\s*$percent_or_quantity_regexp(?:$of|\s)+/i) {
					$percent_or_quantity_value = $1;
					$percent_or_quantity_unit = $2;
					$debug_ingredients and $log->debug(
						"percent found before",
						{
							ingredient => $ingredient,
							percent_or_quantity_value => $percent_or_quantity_value,
							percent_or_quantity_unit => $percent_or_quantity_unit,
							new_ingredient => $'
						}
					) if $log->is_debug();
					$ingredient = $';
				}

				# remove * and other chars before and after the name of ingredients
				$ingredient =~ s/(\s|\*|\)|\]|\}|$stops|$dashes|')+$//;
				$ingredient =~ s/^(\s|\*|\)|\]|\}|$stops|$dashes|')+//;

				$ingredient =~ s/\s*(\d+((\,|\.)\d+)?)\s*\%\s*$//;

				# try to remove the origin and store it as property
				if ($ingredient =~ /\b(de origine|d'origine|origine|origin|alkuperä|iz)\s?:?\s?\b/i) {
					$ingredient = $`;
					my $origin_string = $';
					# d'origine végétale -> not a geographic origin, add en:vegan
					if ($origin_string =~ /vegetal|végétal/i) {
						$vegan = "en:yes";
						$vegetarian = "en:yes";
					}
					else {
						$origin = join(",",
							map {canonicalize_taxonomy_tag($ingredients_lc, "origins", $_)}
								split(/,/, $origin_string));
					}
				}

				# Check if we have an ingredient + some specific labels like organic and fair-trade.
				# If we do, remove the label from the ingredient and add the label to labels
				if (defined $labels_regexps{$ingredients_lc}) {
					# start with uncomposed labels first, so that we decompose "fair-trade organic" into "fair-trade, organic"
					foreach my $labelid (reverse @labels) {
						my $regexp = $labels_regexps{$ingredients_lc}{$labelid};
						#$debug_ingredients and $log->trace("checking labels regexps",
						#	{ingredient => $ingredient, labelid => $labelid, regexp => $regexp})
						#	if $log->is_trace();
						if ((defined $regexp) and ($ingredient =~ /\b($regexp)\b/i)) {

							my $label = $1;

							if (defined $labels) {
								$labels .= ", " . $labelid;
							}
							else {
								$labels = $labelid;
							}

							# Remove stopwords after or before the label
							# e.g. "Abricots from sustainable farming" -> "Abricots" + "from" + "sustainable farming" -> "Abricots"
							my $before_the_label = $`;
							my $after_the_label = $';

							$before_the_label
								= remove_stopwords_from_start_or_end_of_string("labels", $ingredients_lc,
								$before_the_label);

							# Don't remove stopwords on $after_the_label, as it can remove words we want to keep
							# e.g. "Cacao issu de l'agriculture biologique de Madagascar": need to keep "de" in "Cacao de Madagascar"

							$ingredient = $before_the_label . ' ' . $after_the_label;
							$ingredient =~ s/\s+/ /g;

							# If we matched a label, but no ingredient
							if ($ingredient =~ /^\s*$/) {
								# If the ingredient is just the label + sub ingredients (e.g. "vegan (orange juice)")
								# then we replace the now empty ingredient by the sub ingredients
								if ((defined $between) and ($between !~ /^\s*$/)) {
									$ingredient = $between;
									$between = '';
								}
								else {
									# Otherwise we leave the label in place, so that it can be parsed as a non-ingredient specific label
									$ingredient = $label;
								}
							}
							$debug_ingredients
								and $log->debug("found label", {ingredient => $ingredient, labelid => $labelid})
								if $log->is_debug();
						}
					}
				}

				$ingredient =~ s/^\s+//;
				$ingredient =~ s/\s+$//;

				$ingredient_id = canonicalize_taxonomy_tag($ingredients_lc, "ingredients", $ingredient);

				if (exists_taxonomy_tag("ingredients", $ingredient_id)) {
					$ingredient_recognized = 1;
					$debug_ingredients and $log->trace("ingredient recognized", {ingredient_id => $ingredient_id})
						if $log->is_trace();
				}
				else {

					$debug_ingredients
						and $log->trace("ingredient not recognized", {ingredient_id => $ingredient_id})
						if $log->is_trace();

					# Try to see if we have an origin somewhere
					# Build an array of origins / ingredients possibilities

					my @maybe_origins_ingredients = ();

					# California almonds
					if (($ingredients_lc eq "en") and ($ingredient =~ /^(\S+) (.+)$/)) {
						push @maybe_origins_ingredients, [$1, $2];
					}
					# South Carolina black olives
					if (($ingredients_lc eq "en") and ($ingredient =~ /^(\S+ \S+) (.+)$/)) {
						push @maybe_origins_ingredients, [$1, $2];
					}
					if (($ingredients_lc eq "en") and ($ingredient =~ /^(\S+ \S+ \S+) (.+)$/)) {
						push @maybe_origins_ingredients, [$1, $2];
					}

					# Currently does not work: pitted California prunes

					# Oranges from Florida
					if (defined $from{$ingredients_lc}) {
						my $from = $from{$ingredients_lc};
						if ($ingredient =~ /^(.+)($from)(.+)$/i) {
							push @maybe_origins_ingredients, [$3, $1];
						}
					}

					foreach my $maybe_origin_ingredient_ref (@maybe_origins_ingredients) {

						my ($maybe_origin, $maybe_ingredient) = @{$maybe_origin_ingredient_ref};

						# skip origins that are too small (avoid false positives with country initials etc.)
						next if (length($maybe_origin) < 4);

						my $origin_id = canonicalize_taxonomy_tag($ingredients_lc, "origins", $maybe_origin);
						if ((exists_taxonomy_tag("origins", $origin_id)) and ($origin_id ne "en:unknown")) {

							$debug_ingredients and $log->debug(
								"ingredient includes known origin",
								{
									ingredient => $ingredient,
									new_ingredient => $maybe_ingredient,
									origin_id => $origin_id
								}
							) if $log->is_debug();

							$origin = $origin_id;
							$ingredient = $maybe_ingredient;
							$ingredient_id = canonicalize_taxonomy_tag($ingredients_lc, "ingredients", $ingredient);
							last;
						}
					}

					# Try to remove ingredients processing "cooked rice" -> "rice"
					if (defined $ingredients_processing_regexps{$ingredients_lc}) {
						(my $new_processings_ref, $ingredient, $ingredient_id, $ingredient_recognized)
							= parse_processing_from_ingredient($ingredients_lc, $ingredient);
						# Add the newly extracted processings to possibly already existing processings
						push @processings, @$new_processings_ref;
					}

					# Unknown ingredient, check if it is a label
					# -> treat as a label only if there are no sub-ingredients
					if ((not $ingredient_recognized) and ($between eq "") and (length($ingredient) > 5)) {
						# Avoid matching single letters or too short abbreviations, bug #3300

						# We need to be careful with stopwords, "produit" was a stopword,
						# and "France" matched "produit de France" / made in France (bug #2927)
						my $label_id = canonicalize_taxonomy_tag($ingredients_lc, "labels", $ingredient);
						if (exists_taxonomy_tag("labels", $label_id)) {

							# Add the label to the product
							add_tags_to_field($product_ref, $ingredients_lc, "labels", $label_id);

							$ingredient_recognized = 1;

							# some labels are in fact ingredients. e.g. "sustainable palm oil"
							# in that case, add the corresponding ingredient

							my $label_ingredient_id = get_inherited_property("labels", $label_id, "ingredients:en");

							$debug_ingredients and $log->debug(
								"between is a known label",
								{
									between => $between,
									label => $label_id,
									label_ingredient_id => $label_ingredient_id
								}
							) if $log->is_debug();

							if (defined $label_ingredient_id) {

								# The label is specific to an ingredient

								$ingredient_id = $label_ingredient_id;

								if (defined $labels) {
									$labels .= ", " . $label_id;
								}
								else {
									$labels = $label_id;
								}

								$debug_ingredients and $log->debug(
									"unknown ingredient is a label, add label and add corresponding ingredient",
									{
										ingredient => $ingredient,
										label_id => $label_id,
										ingredient_id => $ingredient_id
									}
								) if $log->is_debug();
							}
							else {
								# The label is not specific to an ingredient

								$skip_ingredient = 1;
								$debug_ingredients and $log->debug(
									"unknown ingredient is a label, add label and skip ingredient",
									{ingredient => $ingredient, label_id => $label_id}
								) if $log->is_debug();
							}
						}
					}

					if (not $ingredient_recognized) {
						# Check if it is a phrase we want to ignore
						# NB: If these match, the whole ingredient is ignored, so they're not suitable for ignoring *part* of an ingredient.

						# Remove some sentences
						my %ignore_regexps = (
							'bs' => [
								'u promjenljivom odnosu',    # in a variable ratio
							],

							'da' => [
								'^Mælkechokoladen indeholder (?:også andre vegetabilske fedtstoffer end kakaosmør og )?mindst',
							],

							'de' => [
								'^in ver[äa]nderlichen Gewichtsanteilen$',
								'^Unter Schutzatmosph.re verpackt$',
								'Fett gedruckte Zutaten enthalten allergene Inhaltsstoffe',    # allergens are in bold
							],

							'en' => [
								# breaking this regexp into the comma separated combinations (because each comma makes a new ingredient):
								# (allerg(en|y) advice[:!]? )?(for allergens[,]? )?(including cereals containing gluten, )?see ingredients (highlighted )?in bold
								# We can't just trim it from the end of the ingredients, because trace allergens can come after it.
								'^(!|! )?allerg(en|y) advice([:!]? for allergens)?( including cereals containing gluten)?( see ingredients (highlighted )?in bold)?$',
								'^for allergens( including cereals containing gluten)?( see ingredients (highlighted )?in bold)?$',
								'^including cereals containing gluten( see ingredients (highlighted )?in bold)?$',
								'^see ingredients in bold$',
								'^in var(iable|ying) proportions$',
								'^dietary advice[:]?$',
								'^in milk chocolate cocoa solids',
								'^the milk chocolate contains vegetable fats in addition to cocoa butter and cocoa solids',
								'^meat content',
								'^packaged in a protective atmosphere',
							],

							'fr' => [
								'(\%|pourcentage|pourcentages) (.*)(exprim)',
								'pour( | faire | fabriquer )100'
								,    # x g de XYZ ont été utilisés pour fabriquer 100 g de ABC
								'contenir|présence',    # présence exceptionnelle de ... peut contenir ... noyaux etc.
								'^soit ',    # soit 20g de beurre reconstitué
								'en proportions variables',
								'en proportion variable',
								'^équivalent ',    # équivalent à 20% de fruits rouges
								'^malgré ',    # malgré les soins apportés...
								'^il est possible',    # il est possible qu'il contienne...
								'^(facultatif|facultative)'
								,    # sometime indicated by producers when listing ingredients is not mandatory
								'^(éventuellement|eventuellement)$'
								,    # jus de citrons concentrés et, éventuellement, gélifiant : pectine de fruits.
								'^(les )?informations ((en (gras|majuscule|italique))|soulign)'
								,    # Informations en gras destinées aux personnes allergiques.
								'^(pour les )?allerg[èe]nes[:]?$',    # see english above.
								'^y compris les cereales contenant du gluten$',
								'^voir (les )?ingr[ée]dients (indiqu[ée]s )?en gras$',
								'^(les allerg[èe]nes )?sont indiques en gras$',
								'^Conditionné[es]* sous atmosphère',    # ... protectrice/contrôlée/modifiée/etc
							],

							'fi' => [
								'^(?:Täysjyvää|Kauraa) \d{1,3}\s*% leivän viljasta ja \d{1,3}\s*% leivän painosta$',
								'^jyviä ja siemeniä \d{1,3}\s*% leivontaan käytettyjen jauhojen määrästä$',
								'^(?:Täysjyvä(?:ruista|ä)|Kauraa) \d{1,3}\s*% viljaraaka-aineesta',
								'^Lihaa? ja lihaan verrattav(?:at|ia) valmistusaine(?:et|ita)',
								'^Maitosuklaa sisältää maidon kiinteitä aineita vähintään',
								'^Leivontaan käytetyistä viljasta \d{1,3}\s*% on ruista$',
								'^(?:Maito|Tummassa )?suklaassa(?: kaakaota)? vähintään',
								'^(?:Jauhelihapihvin )?(?:Suola|Liha|Rasva)pitoisuus',
								'^sisältää kaakaovoin lisäksi muita kasvirasvoja$',
								'^Vähintään \d{1,3}\s*% kaakaota maitosuklaassa$',
								'^(?:Täysmehu|hedelmä|ruis)(?:osuus|pitoisuus)',
								'(?:saattaa|voi) sisältää (?:ruotoja|luuta)$',
								'^Sisältää \d{1,3}\s*% (?:siemeniä|kauraa)$',
								'^Maitosuklaa sisältää kaakaota vähintään',
								'^vastaa \d{1,3}\s*% viljaraaka-aineista$',
								'^Kuorta ei ole tarkoitettu syötäväksi$',
								'^Kollageeni\/liha-proteiinisuhde alle',
								'^Valmistettu (?:myllyssä|tehtaassa)'
								,    # Valmistettu myllyssä, jossa käsitellään vehnää.
								'^Kuiva-aineiden täysjyväpitoisuus',
								'^Tuote on valmistettu linjalla'
								,    # Tuote on valmistettu linjalla, jossa käsitellään myös muita viljoja.
								'^jota käytetään leivonnassa'
								,    # Sisältää pienen määrän vehnää, jota käytetään leivonnassa alus- ja päällijauhona.
								'^Leivottu tuotantolinjalla'
								,    # Leivottu tuotantolinjalla, jossa käsitellään myös muita viljoja.
								'^vastaa 100 g porkkanaa$',
								'^Tuotteessa mustikkaa$',
								'vaihtelevina osuuksina',
								'^lakritsin osuudesta$',
								'^Kaakaota vähintään',
								'^(?:Maito)?rasvaa',
								'^täysjyväsisältö',
							],

							'hr' => [
								'^u tragovima$',    # in traces
								'čokolada sadrži biljne masnoće uz kakaov maslac'
								,    #  Chocolate contains vegetable fats along with cocoa butter
								'minimalno \d{1,3}\s*% mliječne masti i do \d{1,3}\s*% vode'
								,    # minimum 82% milk fat and up to 16% water
								'može imati štetno djelovanje na aktivnosti pažnju djece'
								,    # can have a detrimental effect on children's attention activities (E122)
								'označene podebljano',    # marked in bold
								'sastojci (su )otisnuti',    # ingredients written in bold are allergens
								'sastojci otisnuti'
								, # ingredients written in bold are allergens: Alergeni sastojci su otisnuti debljim slovima
								'savjet kod alergije',    # allergy advice
								'u čokoladi kakaovi dijelovi'
								, # Cocoa parts in chocolate 48%. Usually at the end of the ingredients list. Chocolate can contain many sub-ingredients (cacao, milk, sugar, etc.)
								'u promjenjivim omjerima|u promjenjivim udjelima|u promijenljivom udjelu'
								,    # in variable proportions
								'uključujući žitarice koje sadrže gluten',    # including grains containing gluten
								'za alergene',    # for allergens

							],

							'it' => ['^in proporzion[ei] variabil[ei]$',],

							'ja' => [
								'その他',    # etc.
							],

							'nb' => ['^Pakket i beskyttende atmosfære$', '^Minst \d+ ?% kakao',],

							'nl' => [
								'^allergie.informatie$', 'in wisselende verhoudingen',
								'harde fractie', 'o\.a\.',
								'en',
							],

							'pl' => [
								'^czekolada( deserowa)?: masa kakaowa min(imum)?$',
								'^masa kakaowa( w czekoladzie mlecznej)? min(imum)?$',
								'^masa mleczna min(imum)?$',
								'^zawartość tłuszczu$',
								'^(?>\d+\s+g\s+)?(?>\w+\s?)*?100\s?g(?> \w*)?$'
								,    # "pomidorów zużyto na 100 g produktu"
								'^\w*\s?z \d* g (?>\w+\s?)*?100\s?g\s(?>produktu)?$'
								,    # "Sporządzono z 40 g owoców na 100 g produktu"
								'^(?>\d+\s+g\s+)?(?>\w+\s?)*?ze\s+\d+\s?g(?>\s+\w*)*$' # "produktu wyprodukowano ze 133 g mięsa wieprzowego"
							],

							'ro' => [
								'in proporţie variabilă',
								'Informatiile scrise cu majuscule sunt destinate persoanelor cu intolerante sau alergice',
								'Ambalat in atmosfera protectoare',
								'poate con(ț|t)ine urme de',    # can contain traces of
							],

							'ru' => [
								'^россия$', '^состав( продукта)?$',
								'^энергетическая ценность$', '^калорийность$',
								'^углеводы$', '^не менее$',
								'^средние значения$', '^содержат$',
								'^идентичный натуральному$', '^(g|ж|ул)$'
							],

							'sl' => [
								'lahko vsebuje',
								'lahko vsebuje sledi',    # may contain traces
							],

							'sv' => [
								'^Minst \d{1,3}\s*% kakao I chokladen$',
								'^Mjölkchokladen innehåller minst',
								'^Kakaohalt i chokladen$',
								'varierande proportion',
								'kan innehålla ben$',
								'^Kakao minst',
								'^fetthalt',
							],

						);
						if (defined $ignore_regexps{$ingredients_lc}) {
							foreach my $regexp (@{$ignore_regexps{$ingredients_lc}}) {
								if ($ingredient =~ /$regexp/i) {

									$debug_ingredients and $log->debug(
										"unknown ingredient matches a phrase to ignore",
										{ingredient => $ingredient, regexp => $regexp}
									) if $log->is_debug();

									$skip_ingredient = 1;
									$ingredient_recognized = 1;
									last;
								}
							}
						}
					}

					if (not $ingredient_recognized) {
						# 2 ingredients separated by "and" ? -> split them in 2 ingredients
						# We split if we find at least 1 known ingredient
						# We might have some false positives as "and" could be part of processing
						if ($ingredient =~ /$and/i) {

							my $ingredient1 = $`;
							my $ingredient2 = $';

							$debug_ingredients
								and $log->debug(
								"parse_ingredient_text - and - whole ingredient >$ingredient< containing 'and' is still an unknown ingredient"
								) if $log->is_debug();

							# Create a copy of $ingredients1 and $ingredients2, as we will remove percents to $ingredientX,
							# but we will push $ingredientX_orig if it is a known ingredient after we remove the processing
							my $ingredient1_orig = $ingredient1;
							my $ingredient2_orig = $ingredient2;

							my $ingredients_recognized = 0;

							foreach ($ingredient1, $ingredient2) {
								# Remove percent
								$_ =~ s/\s$percent_or_quantity_regexp$//i;

								# Check if we recognize the ingredient
								(undef, undef, undef, my $is_recognized)
									= parse_processing_from_ingredient($ingredients_lc, $_);

								$ingredients_recognized += $is_recognized;
							}
							# Did we recognize one of the two ingredients?
							if ($ingredients_recognized >= 1) {
								$debug_ingredients
									and $log->debug("parse_ingredient_text - split $ingredient1 - $ingredient2")
									if $log->is_debug();
								$ingredient = $ingredient1_orig;
								$ingredient_id = canonicalize_taxonomy_tag($ingredients_lc, "ingredients", $ingredient);
								unshift @ingredients, "$ingredient2_orig";
							}
							else {
								$debug_ingredients
									and $log->debug(
									"parse_ingredient_text - and - both ingredients of >$before< are unknown")
									if $log->is_debug();

							}
						}
					}
				}
			}

			if (not $skip_ingredient) {

				# If we have a parent ingredient, check if "parent ingredient + child ingredient" is a known ingredient
				# e.g. "vegetal oil (palm, rapeseed)" -> if we have "palm" as the child, try to transform it in "palm vegetal oil"

				if (defined $parent_ref) {

					# Generate the text for the canonicalized parent ingredient (so that we don't get percentages, labels etc. in it)
					my $parent_ingredient_text
						= display_taxonomy_tag($ingredients_lc, "ingredients", $parent_ref->{id});

					my $parent_plus_child_ingredient_text;

					if ($ingredients_lc eq "en") {
						# oil (palm) -> palm oil
						$parent_plus_child_ingredient_text = $ingredient . ' ' . $parent_ingredient_text;
					}
					else {
						# huile (palme) -> huile palme
						$parent_plus_child_ingredient_text = $parent_ingredient_text . ' ' . $ingredient;
					}

					# Check if the parent + child ingredient is a known ingredient
					my $exists_in_taxonomy;
					my $parent_plus_child_ingredient_id
						= canonicalize_taxonomy_tag($ingredients_lc, "ingredients", $parent_plus_child_ingredient_text,
						\$exists_in_taxonomy);

					if ($exists_in_taxonomy) {
						$ingredient_id = $parent_plus_child_ingredient_id;
						$log->debug(
							"parse_ingredient_text - parent + child ingredient recognized",
							{
								parent => $parent_ingredient_text,
								child => $ingredient,
								parent_plus_child_ingredient_text => $parent_plus_child_ingredient_text,
								parent_plus_child_ingredient_id => $parent_plus_child_ingredient_id
							}

						) if $log->is_debug();
					}
				}

				my %ingredient = (
					id => get_taxonomyid($ingredients_lc, $ingredient_id),
					text => $ingredient
				);

				my $is_in_taxonomy = exists_taxonomy_tag("ingredients", $ingredient_id) ? 1 : 0;
				$ingredient{is_in_taxonomy} = $is_in_taxonomy;

				if (defined $percent_or_quantity_value) {
					my ($percent, $quantity, $quantity_g)
						= get_percent_or_quantity_and_normalized_quantity($percent_or_quantity_value,
						$percent_or_quantity_unit);
					if (defined $percent) {
						$ingredient{percent} = $percent + 0;
					}
					if (defined $quantity) {
						$ingredient{quantity} = $quantity;
					}
					if (defined $quantity_g) {
						$ingredient{quantity_g} = $quantity_g;
					}
				}
				if (defined $origin) {
					$ingredient{origins} = $origin;
				}

				if (defined $vegan) {
					$ingredient{vegan} = $vegan;
				}
				if (defined $vegetarian) {
					$ingredient{vegetarian} = $vegetarian;
				}

				if (defined $labels) {
					$ingredient{labels} = $labels;

					# If we have a label for the ingredient that indicates if it is vegan or not, override the value
					if ($labels =~ /\ben:vegan\b/) {
						$ingredient{vegan} = "en:yes";
						$ingredient{vegetarian} = "en:yes";
					}
					if ($labels =~ /\ben:vegetarian\b/) {
						$ingredient{vegetarian} = "en:yes";
					}
				}

				if (scalar @processings) {
					# TODO: we could keep the array of processings instead of creating a comma separated list
					# we should do it together with other fields like origins and labels, and provide backward compatibility
					# for API v3 and below
					$ingredient{processing} = join(',', @processings);
					# reset @processings because for "a and b" we don't want to reuse for b the same processing as a
					@processings = ();
				}

				if ($ingredient ne '') {

					# ingredients tags that are too long (greater than 1024, mongodb max index key size)
					# will cause issues for the mongodb ingredients_tags index, just drop them

					if (length($ingredient{id}) < 500) {
						push @{$ingredients_ref}, \%ingredient;

						if ($between ne '') {
							# Ingredient has sub-ingredients

							# we may have separated 2 ingredients:
							# e.g. "salt and acid (acid citric)" -> salt + acid
							# the sub ingredients only apply to the last ingredient

							if ((scalar @ingredients) == 0) {
								$ingredient{ingredients} = [];
								$analyze_ingredients_self->(
									$analyze_ingredients_self,
									$ingredient{ingredients},
									$ingredients_ref->[-1],
									$between_level, $between
								);
							}
						}
					}
				}
			}

			$i++;
		}

		if ($after ne '') {
			$analyze_ingredients_self->($analyze_ingredients_self, $ingredients_ref, $parent_ref, $level, $after);
		}

	};

	$analyze_ingredients_function->($analyze_ingredients_function, $product_ref->{ingredients}, undef, 0, $text);

	$log->debug("ingredients: ", {ingredients => $product_ref->{ingredients}}) if $log->is_debug();

	return;
}

=head2 extend_ingredients_service ( $product_ref, $updated_product_fields_ref, $errors_ref )

After the nested ingredients structure has been built with the parse_ingredients_text_service,
this service adds some properties to the ingredients:

- Origins, labels etc. that have been extracted from other fields
- Ciqual and Ecobalyse codes

=head3 Arguments

=head4 $product_ref

product object reference

=head4 $updated_product_fields_ref

reference to a hash of product fields that have been created or updated

=head4 $errors_ref

reference to an array of error messages

=cut

sub extend_ingredients_service ($product_ref, $updated_product_fields_ref, $errors_ref) {

	# Do nothing and return if we don't have the ingredients structure
	return if not defined $product_ref->{ingredients};

	# indicate that the service is modifying the "ingredients" structure
	$updated_product_fields_ref->{ingredients} = 1;

	# Add properties like origins from specific ingredients extracted from labels or the end of the ingredients list
	add_properties_from_specific_ingredients($product_ref);

	# Add Ciqual codes
	# Used in particular for ingredients estimation from nutrients
	assign_property_to_ingredients($product_ref);

	return;
}

=head2 flatten_sub_ingredients ( product_ref )

Flatten the nested list of ingredients.

=cut

sub flatten_sub_ingredients ($product_ref) {

	my $rank = 1;

	# The existing first level ingredients will be ranked
	my $first_level_ingredients_n = scalar @{$product_ref->{ingredients}};

	for (my $i = 0; $i < @{$product_ref->{ingredients}}; $i++) {

		# We will copy the sub-ingredients of an ingredient at the end of the ingredients array
		# and if they contain sub-ingredients themselves, they will be also processed with
		# this for loop.

		if (defined $product_ref->{ingredients}[$i]{ingredients}) {
			$product_ref->{ingredients}[$i]{has_sub_ingredients} = "yes";
			push @{$product_ref->{ingredients}}, @{clone $product_ref->{ingredients}[$i]{ingredients}};
		}
		if ($i < $first_level_ingredients_n) {
			# Add a rank for all first level ingredients
			$product_ref->{ingredients}[$i]{rank} = $rank++;
		}

		# Delete the sub-ingredients, as they have been pushed at the end of the list
		delete $product_ref->{ingredients}[$i]{ingredients};
	}
	return;
}

=head2 compute_ingredients_tags ( product_ref )

Go through the nested ingredients and:

Compute ingredients_original_tags and ingredients_tags.

Compute the total % of "leaf" ingredients (without sub-ingredients) with a specified %, and unspecified %.

- ingredients_with_specified_percent_n : number of "leaf" ingredients with a specified %
- ingredients_with_specified_percent_sum : % sum of "leaf" ingredients with a specified %
- ingredients_with_unspecified_percent_n
- ingredients_with_unspecified_percent_sum	

=cut

sub compute_ingredients_tags ($product_ref) {

	# Delete ingredients related fields
	# They will be recreated, unless the ingredients list was deleted
	remove_fields(
		$product_ref,
		[
			"ingredients_hierarchy", "ingredients_tags",
			"ingredients_original_tags", "ingredients_n",
			"known_ingredients_n", "unknown_ingredients_n",
			"ingredients_n_tags", "ingredients_with_specified_percent_n",
			"ingredients_with_unspecified_percent_n", "ingredients_with_specified_percent_sum",
			"ingredients_with_unspecified_percent_sum"
		]
	);

	return if not defined $product_ref->{ingredients};

	$product_ref->{ingredients_tags} = [];
	$product_ref->{ingredients_original_tags} = [];

	$product_ref->{ingredients_with_specified_percent_n} = 0;
	$product_ref->{ingredients_with_unspecified_percent_n} = 0;
	$product_ref->{ingredients_with_specified_percent_sum} = 0;
	$product_ref->{ingredients_with_unspecified_percent_sum} = 0;

	# Traverse the ingredients tree, breadth first

	my @ingredients = @{$product_ref->{ingredients}};

	my $ingredients_n = 0;
	my $known_ingredients_n = 0;

	while (@ingredients) {

		my $ingredient_ref = shift @ingredients;

		push @{$product_ref->{ingredients_original_tags}}, $ingredient_ref->{id};

		# Count ingredients and unknown ingredients
		$ingredients_n += 1;
		$known_ingredients_n += $ingredient_ref->{is_in_taxonomy};

		if (defined $ingredient_ref->{ingredients}) {

			push @ingredients, @{$ingredient_ref->{ingredients}};
		}
		else {
			# Count specified percent only for ingredients that do not have sub ingredients
			if (defined $ingredient_ref->{percent}) {
				$product_ref->{ingredients_with_specified_percent_n} += 1;
				$product_ref->{ingredients_with_specified_percent_sum} += $ingredient_ref->{percent};
			}
			else {
				$product_ref->{ingredients_with_unspecified_percent_n} += 1;
				if (defined $ingredient_ref->{percent_estimate}) {
					$product_ref->{ingredients_with_unspecified_percent_sum} += $ingredient_ref->{percent_estimate};
				}
			}
		}
	}

	$product_ref->{ingredients_n} = $ingredients_n;
	$product_ref->{known_ingredients_n} = $known_ingredients_n;
	$product_ref->{unknown_ingredients_n} = $ingredients_n - $known_ingredients_n;

	# ingredients_original_tags contains the ingredients that are listed in the ingredients list
	# ingredients_tags also contains the parent ingredients (from the ingredients taxonomy)
	# Note: we used to also compute a field ingredients_hierarchy that contained exactly the same information as ingredients_tags
	# we now remove it, and the API will add it back for backward compatibility depending on API version

	my $ingredients_lc = get_or_select_ingredients_lc($product_ref);

	$product_ref->{"ingredients_tags"} = [
		gen_ingredients_tags_hierarchy_taxonomy(
			$ingredients_lc, join(", ", @{$product_ref->{ingredients_original_tags}})
		)
	];

	if ($product_ref->{ingredients_text} ne "") {

		my $d = int(($product_ref->{ingredients_n} - 1) / 10);
		my $start = $d * 10 + 1;
		my $end = $d * 10 + 10;

		$product_ref->{ingredients_n_tags} = [$product_ref->{ingredients_n} . "", "$start" . "-" . "$end"];
		# ensure $product_ref->{ingredients_n} is last used as an int so that it is not saved as a strings
		$product_ref->{ingredients_n} += 0;
	}

	return;
}

=head2 extract_ingredients_from_text ( product_ref )

This function calls:

- parse_ingredients_text_service() to parse the ingredients text in the main language of the product
to extract individual ingredients and sub-ingredients

- compute_ingredients_percent_min_max_values() to create the ingredients array with nested sub-ingredients arrays

- compute_ingredients_tags() to create a flat array ingredients_original_tags and ingredients_tags (with parents)

- analyze_ingredients_service() to analyze ingredients to see the ones that are vegan, vegetarian, from palm oil etc.
and to compute the resulting value for the complete product

=cut

sub extract_ingredients_from_text ($product_ref) {

	delete $product_ref->{ingredients_percent_analysis};

	# The specific ingredients array will contain indications regarding the percentage,
	# origins, labels etc. of specific ingredients. Those information may come from:
	# - the origin of ingredients field ("origin")
	# - labels (e.g. "British eggs")
	# - the end of the list of the ingredients. e.g. "Origin of the rice: Thailand"

	$product_ref->{specific_ingredients} = [];

	# It is possible that we could have origins info listed without having ingredients listed
	# (also in unit tests)
	# so we fall back to the main language of the product in that case
	my $origin_lc = get_or_select_ingredients_lc($product_ref) || $product_ref->{lc};

	# Ingredients origins may be listed in the origin field
	# e.g. "Origin of the rice: Thailand."
	if (defined $product_ref->{"origin_" . $origin_lc}) {
		parse_origins_from_text($product_ref, $product_ref->{"origin_" . $origin_lc}, $origin_lc);
	}

	# Add specific ingredients from labels
	add_specific_ingredients_from_labels($product_ref);

	# Parse the ingredients list to extract individual ingredients and sub-ingredients
	# to create the ingredients array with nested sub-ingredients arrays

	parse_ingredients_text_service($product_ref, {}, []);

	if (defined $product_ref->{ingredients}) {

		# - Add properties like origins from specific ingredients extracted from labels or the end of the ingredients list
		# - Obtain Ciqual codes ready for ingredients estimation from nutrients
		extend_ingredients_service($product_ref, {}, []);

		# Compute minimum and maximum percent ranges and percent estimates for each ingredient and sub ingredient
		estimate_ingredients_percent_service($product_ref, {}, []);

		estimate_nutriscore_2021_fruits_vegetables_nuts_percent_from_ingredients($product_ref);
		estimate_nutriscore_2023_fruits_vegetables_legumes_percent_from_ingredients($product_ref);
	}
	else {
		remove_fields(
			$product_ref,
			[
				# assign_property_to_ingredients - may have been introduced in previous version
				"ingredients_without_ciqual_codes",
				"ingredients_without_ciqual_codes_n",
			]
		);
		remove_fields(
			$product_ref->{nutriments},
			[
				# estimate_nutriscore_2021_fruits_vegetables_nuts_percent_from_ingredients - may have been introduced in previous version
				"fruits-vegetables-nuts-estimate-from-ingredients_100g",
				"fruits-vegetables-nuts-estimate-from-ingredients_serving",
				"fruits-vegetables-legumes-estimate-from-ingredients_100g",
				"fruits-vegetables-legumes-estimate-from-ingredients_serving",
				"fruits-vegetables-nuts-estimate-from-ingredients-prepared_100g",
				"fruits-vegetables-nuts-estimate-from-ingredients-prepared_serving",
				"fruits-vegetables-legumes-estimate-from-ingredients-prepared_100g",
				"fruits-vegetables-legumes-estimate-from-ingredients-prepared_serving",
			]
		);
	}

	# Keep the nested list of sub-ingredients, but also copy the sub-ingredients at the end for apps
	# that expect a flat list of ingredients

	compute_ingredients_tags($product_ref);

	# Analyze ingredients to see the ones that are vegan, vegetarian, from palm oil etc.
	# and compute the resulting value for the complete product

	analyze_ingredients_service($product_ref, {}, []);

	# Delete specific ingredients if empty
	if ((exists $product_ref->{specific_ingredients}) and (scalar @{$product_ref->{specific_ingredients}} == 0)) {
		delete $product_ref->{specific_ingredients};
	}

	return;
}

sub assign_property_to_ingredients ($product_ref) {
	# If the ingredient list is not defined, the function immediately returns
	return if not defined $product_ref->{ingredients};

	# ------------------------------------ PART 1 : Getting CIQUAL codes ------------------------------------ #
	# Retrieves a unique and sorted list of ingredients missing Ciqual codes
	my @ingredients_without_ciqual_codes = uniq(sort(get_missing_ciqual_codes($product_ref->{ingredients})));

	# Stores this list in the product under the key 'ingredients_without_ciqual_codes'
	$product_ref->{ingredients_without_ciqual_codes} = \@ingredients_without_ciqual_codes;

	# Also stores the total number of ingredients without Ciqual codes
	$product_ref->{ingredients_without_ciqual_codes_n} = @ingredients_without_ciqual_codes + 0.0;

	# ------------------------------------ PART 2 : Getting Ecobalyse ids ------------------------------------ #
	# Retrieves a unique and sorted list of ingredients missing Ecobalyse ids
	my @ingredients_without_ecobalyse_ids = uniq(sort(get_missing_ecobalyse_ids($product_ref->{ingredients})));

	# Stores this list in the product under the key 'ingredients_without_ecobalyse_ids'
	$product_ref->{ingredients_without_ecobalyse_ids} = \@ingredients_without_ecobalyse_ids;

	# Also stores the total number of ingredients without Ecobalyse ids
	$product_ref->{ingredients_without_ecobalyse_ids_n} = @ingredients_without_ecobalyse_ids + 0.0;

	return;
}

=head2 get_missing_ciqual_codes ($ingredients_ref)

Assign a ciqual_food_code or a ciqual_proxy_food_code to ingredients and sub ingredients.

=head3 Arguments

=head4 $ingredients_ref

reference to an array of ingredients

=head3 Return values

=head4 @ingredients_without_ciqual_codes

=cut

sub get_missing_ciqual_codes ($ingredients_ref) {
	my @ingredients_without_ciqual_codes = ();
	foreach my $ingredient_ref (@{$ingredients_ref}) {

		# Also add sub-ingredients
		if (defined $ingredient_ref->{ingredients}) {
			push(@ingredients_without_ciqual_codes, get_missing_ciqual_codes($ingredient_ref->{ingredients}));
		}

		# Assign a ciqual_food_code or a ciqual_proxy_food_code to the ingredient
		delete $ingredient_ref->{ciqual_food_code};
		delete $ingredient_ref->{ciqual_proxy_food_code};

		my $ciqual_food_code = get_inherited_property("ingredients", $ingredient_ref->{id}, "ciqual_food_code:en");
		if (defined $ciqual_food_code) {
			$ingredient_ref->{ciqual_food_code} = $ciqual_food_code;
		}
		else {
			my $ciqual_proxy_food_code
				= get_inherited_property("ingredients", $ingredient_ref->{id}, "ciqual_proxy_food_code:en");
			if (defined $ciqual_proxy_food_code) {
				$ingredient_ref->{ciqual_proxy_food_code} = $ciqual_proxy_food_code;
			}
			else {
				push(@ingredients_without_ciqual_codes, $ingredient_ref->{id});
			}
		}
	}

	return @ingredients_without_ciqual_codes;
}

=head2 get_missing_ecobalyse_ids ($ingredients_ref)

Assign a ecobalyse_code or a ecobalyse_proxy_code to ingredients and sub ingredients. (NOTE : this is a first version that'll soon be improved)

=head3 Arguments

=head4 $ingredients_ref

reference to an array of ingredients

=head3 Return values

=head4 @ingredients_without_ecobalyse_ids

=cut

sub get_missing_ecobalyse_ids ($ingredients_ref) {
	my @ingredients_without_ecobalyse_ids = ();
	foreach my $ingredient_ref (@{$ingredients_ref}) {

		# Also add sub-ingredients
		if (defined $ingredient_ref->{ingredients}) {
			push(@ingredients_without_ecobalyse_ids, get_missing_ecobalyse_ids($ingredient_ref->{ingredients}));
		}

		# Assign a ecobalyse_code or a ecoalyse_proxy_code to the ingredient
		delete $ingredient_ref->{ecobalyse_code};
		delete $ingredient_ref->{ecobalyse_proxy_code};

		# We are now looking for the appropriate ecobalyse id :
		# ecobalyse_origins_france_label_organic (if the product comes from france, and is organic)
		# ecobalyse_origins_european-union_label_organic (if the product comes from europe, and is organic)
		# ecobalyse_label_organic (if the product is organic)
		# ecobalyse_origins_france (if the product comes from france)
		# ecobalyse_origins_european-union (if the product comes from the Europe region)
		# ecobalyse (else)

		# List of suffixes
		my @suffixes = ();
		# If the ingredient is both organic and French...
		if (    (defined $ingredient_ref->{labels})
			and ($ingredient_ref->{labels} =~ /\ben:organic\b/)
			and (defined $ingredient_ref->{origins})
			and (get_geographical_area($ingredient_ref->{origins}) eq "fr"))
		{
			push @suffixes, "_labels_en_organic_origins_en_france";
			push @suffixes, "_labels_en_organic_origins_en_european_union";
		}
		# If the ingredient is both organic and European...
		if (    (defined $ingredient_ref->{labels})
			and ($ingredient_ref->{labels} =~ /\ben:organic\b/)
			and (defined $ingredient_ref->{origins})
			and (get_geographical_area($ingredient_ref->{origins}) eq "eu"))
		{
			push @suffixes, "_labels_en_organic_origins_en_european_union";
		}
		# If the ingredient is organic...
		if ((defined $ingredient_ref->{labels}) and ($ingredient_ref->{labels} =~ /\ben:organic\b/)) {
			push @suffixes, "_labels_en_organic";
		}
		# If the ingredient is French...
		if ((defined $ingredient_ref->{origins}) and (get_geographical_area($ingredient_ref->{origins}) eq "fr")) {
			push @suffixes, "_origins_en_france";
			push @suffixes, "_origins_en_european_union";
		}
		# If the ingredient is European...
		if ((defined $ingredient_ref->{origins}) and (get_geographical_area($ingredient_ref->{origins}) eq "eu")) {
			push @suffixes, "_origins_en_european_union";
		}
		push @suffixes, '';

		# First try an exact match, and then a proxy match
		foreach my $prefix ("ecobalyse", "ecobalyse_proxy") {
			# Loop through each suffix to retrieve ecobalyse code
			foreach my $suffix (@suffixes) {
				# Construct the property name using the prefix and suffix
				my $property_name = $prefix . $suffix . ":en";

				# Attempt to retrieve the ecobalyse code for the current property name
				my $ecobalyse_code = get_inherited_property("ingredients", $ingredient_ref->{id}, $property_name);

				if (defined $ecobalyse_code) {
					# Assign the ecobalyse code if found
					$ingredient_ref->{ecobalyse_code} = $ecobalyse_code;
					last;
				}
			}
			# Exit the loop if a valid ecobalyse code was found
			last if defined $ingredient_ref->{ecobalyse_code};
		}

		# If no ecobalyse code was found, add ingredient ID to list of missing codes
		if (!defined $ingredient_ref->{ecobalyse_code}) {
			push(@ingredients_without_ecobalyse_ids, $ingredient_ref->{id});
		}

		#ecobalyse:en
		#ecobalyse_labels_en_organic:en
		#ecobalyse_origins_en_france:en
		#ecobalyse_origins_en_european_union:en
		#ecobalyse_labels_en_organic_origins_en_france:en
	}
	return @ingredients_without_ecobalyse_ids;
}

=head2 get_geographical_area ($originid)

Retrieve the geographical area for ecobalyse. (NOTE : this is a first version that'll soon be improved)

=head3 Arguments

=head4 $originid

reference to the name of the country 

=head3 Return values

=head4 $ecobalyse_area

=cut

sub get_geographical_area ($originid) {
	# Getting information about the country
	my $ecobalyse_area = "";
	my $ecobalyse_is_part_of_eu_result = get_inherited_property("countries", $originid, "ecobalyse_is_part_of_eu");
	if (defined $ecobalyse_is_part_of_eu_result
		&& $ecobalyse_is_part_of_eu_result eq "yes")
	{
		$ecobalyse_area = "eu";
	}
	if ($originid eq "en:france") {
		$ecobalyse_area = "fr";
	}

	return $ecobalyse_area;
}

=head2 estimate_ingredients_percent_service ( $product_ref, $updated_product_fields_ref, $errors_ref )

Compute minimum and maximum percent ranges and percent estimates for each ingredient and sub ingredient.

This function is a product service that can be run through ProductOpener::ApiProductServices

=head3 Arguments

=head4 $product_ref

product object reference

=head4 $updated_product_fields_ref

reference to a hash of product fields that have been created or updated

=head4 $errors_ref

reference to an array of error messages

=cut 

sub estimate_ingredients_percent_service ($product_ref, $updated_product_fields_ref, $errors_ref) {

	# Do nothing and return if we don't have the ingredients structure
	return if not defined $product_ref->{ingredients};

	# Add a percent_max value for salt and sugar ingredients, based on the nutrition facts.
	add_percent_max_for_ingredients_from_nutrition_facts($product_ref);

	# Compute the min and max range for each ingredient
	if (compute_ingredients_percent_min_max_values(100, 100, $product_ref->{ingredients}) < 0) {

		# The computation yielded seemingly impossible values, delete the values
		delete_ingredients_percent_values($product_ref->{ingredients});
		$product_ref->{ingredients_percent_analysis} = -1;
	}
	else {
		$product_ref->{ingredients_percent_analysis} = 1;
	}

	remove_tag($product_ref, "misc", "en:some-ingredients-with-specified-percent");
	remove_tag($product_ref, "misc", "en:all-ingredients-with-specified-percent");
	remove_tag($product_ref, "misc", "en:at-least-5-ingredients-with-specified-percent");
	remove_tag($product_ref, "misc", "en:at-least-10-ingredients-with-specified-percent");

	# Count ingredients with specified percent
	my ($ingredients_n, $ingredients_with_specified_percent_n, $total_specified_percent)
		= count_ingredients_with_specified_percent($product_ref->{ingredients});
	if ($ingredients_with_specified_percent_n > 0) {
		add_tag($product_ref, "misc", "en:some-ingredients-with-specified-percent");
		if ($ingredients_with_specified_percent_n == $ingredients_n) {
			add_tag($product_ref, "misc", "en:all-ingredients-with-specified-percent");
		}
		if ($ingredients_with_specified_percent_n >= 5) {
			add_tag($product_ref, "misc", "en:at-least-5-ingredients-with-specified-percent");
			if ($ingredients_with_specified_percent_n >= 10) {
				add_tag($product_ref, "misc", "en:at-least-10-ingredients-with-specified-percent");
			}
		}
	}

	# Estimate the percent values for each ingredient for which we don't have a specified percent
	compute_ingredients_percent_estimates(100, $product_ref->{ingredients});

	# Indicate which fields were created or updated
	$updated_product_fields_ref->{ingredients} = 1;
	$updated_product_fields_ref->{ingredients_percent_analysis} = 1;

	return;
}

=head2 count_ingredients_with_specified_percent($product_ref)

Count ingredients with specified percent, including sub-ingredients.

=head3 Return values

=head4 $ingredients_n

Number of ingredients.

=head4 $ingredients_with_specified_percent_n

Number of ingredients with a specified percent value.

=head4 $total_specified_percent

Sum of the specified percent values.

Note: this can be greater than 100 if percent values are specified for ingredients and their sub ingredients.

=cut

sub count_ingredients_with_specified_percent ($ingredients_ref) {

	my ($ingredients_n, $ingredients_with_specified_percent_n, $total_specified_percent) = (0, 0, 0);

	if (defined $ingredients_ref) {
		foreach my $ingredient_ref (@{$ingredients_ref}) {
			$ingredients_n++;
			if (defined $ingredient_ref->{percent}) {
				$ingredients_with_specified_percent_n++;
				$total_specified_percent += $ingredient_ref->{percent};
			}
			if (defined $ingredient_ref->{ingredients}) {
				my (
					$sub_ingredients_n,
					$sub_ingredients_with_specified_percent_n,
					$sub_ingredients_total_specified_percent
				) = count_ingredients_with_specified_percent($ingredient_ref->{ingredients});
				$ingredients_n += $sub_ingredients_n;
				$ingredients_with_specified_percent_n += $sub_ingredients_with_specified_percent_n;
				$total_specified_percent += $sub_ingredients_total_specified_percent;
			}
		}
	}

	return ($ingredients_n, $ingredients_with_specified_percent_n, $total_specified_percent);
}

=head2 delete_ingredients_percent_values ( ingredients_ref )

This function deletes the percent_min and percent_max values of all ingredients.

It is called if the compute_ingredients_percent_min_max_values() encountered impossible
values (e.g. "Water, Sugar 80%" -> Water % should be greater than 80%, but the
total would be more than 100%)

The function is recursive to also delete values for sub-ingredients.

=cut

sub delete_ingredients_percent_values ($ingredients_ref) {

	foreach my $ingredient_ref (@{$ingredients_ref}) {

		delete $ingredient_ref->{percent_min};
		delete $ingredient_ref->{percent_max};

		if (defined $ingredient_ref->{ingredients}) {
			delete_ingredients_percent_values($ingredient_ref->{ingredients});
		}
	}

	return;
}

=head2 compute_ingredients_percent_min_max_values ( total_min, total_max, ingredients_ref )

This function computes the possible minimum and maximum ranges for the percent
values of each ingredient and sub-ingredients.

Ingredients lists sometimes specify the percent value for some ingredients,
but usually not all. This functions computes minimum and maximum percent
values for all other ingredients.

Ingredients list are ordered by descending order of quantity.

This function is recursive and it calls itself for each ingredients with sub-ingredients.

=head3 Arguments

=head4 total_min - the minimum percent value of the total of all the ingredients in ingredients_ref

0 when the function is called on all ingredients of a product, but can be different than 0 if called on sub-ingredients of an ingredient that has a minimum value set.

=head4 total_max - the maximum percent value of all ingredients passed in ingredients_ref

100 when the function is called on all ingredients of a product, but can be different than 0 if called on sub-ingredients of an ingredient that has a maximum value set.

=head4 ingredient_ref : nested array of ingredients and sub-ingredients

=head3 Return values

=head4 Negative value - analysis error

The analysis encountered an impossible value.
e.g. "Flour, Sugar 80%": The % of Flour must be greated to the % of Sugar, but the sum would then be above 100%.

Or there were too many loops to analyze the values.

=head4 0 or positive value - analysis ok

The return value is the number of times we adjusted min and max values for ingredients and sub ingredients.

=cut

sub compute_ingredients_percent_min_max_values ($total_min, $total_max, $ingredients_ref) {

	init_percent_values($total_min, $total_max, $ingredients_ref);

	my $changed = 1;
	my $changed_total = 0;

	my $i = 0;

	while ($changed) {
		my $changed_max = set_percent_max_values($total_min, $total_max, $ingredients_ref);
		# bail out if there was an error / impossible values
		($changed_max < 0) and return -1;

		my $changed_min = set_percent_min_values($total_min, $total_max, $ingredients_ref);
		($changed_min < 0) and return -1;

		my $changed_sub_ingredients = set_percent_sub_ingredients($ingredients_ref);
		($changed_sub_ingredients < 0) and return -1;

		$changed = $changed_min + $changed_max + $changed_sub_ingredients;

		$changed_total += $changed;

		$i++;

		# bail out if we loop too much
		if ($i > 5) {

			$log->debug(
				"compute_ingredients_percent_min_max_values - too many loops, bail out",
				{
					ingredients_ref => $ingredients_ref,
					total_min => $total_min,
					total_max => $total_max,
					changed_total => $changed_total
				}
			) if $log->is_debug();
			return -1;
		}
	}

	$log->debug(
		"compute_ingredients_percent_min_max_values - done",
		{
			ingredients_ref => $ingredients_ref,
			total_min => $total_min,
			total_max => $total_max,
			changed_total => $changed_total
		}
	) if $log->is_debug();

	return $changed_total;
}

=head2 init_percent_values($total_min, $total_max, $ingredients_ref)

Initialize the percent, percent_min and percent_max value for each ingredient in list.

$ingredients_ref is the list of ingredients (as hash), where parsed percent are already set.

$total_min and $total_max might be set if we have a parent ingredient and are parsing a sub list.

When a percent is specifically set, use this value for percent_min and percent_max.

Warning: percent listed for sub-ingredients can be absolute (e.g. "Sugar, fruits 40% (pear 30%, apple 10%)")
or they can be relative to the parent ingredient (e.g. "Sugar, fruits 40% (pear 75%, apple 25%)".
We try to detect those cases and rescale the percent accordingly.

Otherwise use 0 for percent_min and total_max for percent_max.

=cut

sub init_percent_values ($total_min, $total_max, $ingredients_ref) {
	# Set maximum percentages if defined in the taxonomy (only do this for top-level ingredients)
	if ($total_max == 100) {
		set_percent_max_from_taxonomy($ingredients_ref);
	}

	# Determine if percent listed are absolute (default) or relative to a parent ingredient

	# Check if all ingredients have a set quantity
	# and compute the sum of all percents and quantities

	my $percent_sum = 0;
	my $all_ingredients_have_a_set_percent = 1;
	my $quantity_sum = 0;
	my $all_ingredients_have_a_set_quantity = 1;
	foreach my $ingredient_ref (@{$ingredients_ref}) {
		if (defined $ingredient_ref->{percent}) {
			$percent_sum += $ingredient_ref->{percent};
		}
		else {
			$all_ingredients_have_a_set_percent = 0;
		}

		if (defined $ingredient_ref->{quantity_g}) {
			$quantity_sum += $ingredient_ref->{quantity_g};
		}
		else {
			$all_ingredients_have_a_set_quantity = 0;
		}
	}

	my $percent_mode;

	# If the parent ingredient percent is known (total_min = total_max)
	# and we have set quantity for all ingredients,
	# we will need to scale the quantities to get actual percent values
	# This is the case in particular for recipes that can be specified in grams with a total greater than 100g
	# So we start supposing it's grams (as if it's percent it will also work).

	# In scale_percents or scale_grams mode, the percent/quantity sum must be greater than 0
	if (($total_min == $total_max) and ($all_ingredients_have_a_set_percent) and ($percent_sum > 0)) {
		$percent_mode = "scale_percents";
	}
	elsif (($total_min == $total_max) and ($all_ingredients_have_a_set_quantity) and ($quantity_sum > 0)) {
		$percent_mode = "scale_grams";
	}
	elsif ($percent_sum > $total_max) {
		$percent_mode = "relative";    # percents are relative to the parent ingredient
	}
	else {
		$percent_mode = "absolute";    # percents are absolute (relative to the whole product)
	}

	$log->debug(
		"init_percent_values - percent mode",
		{
			percent_mode => $percent_mode,
			ingredients_ref => $ingredients_ref,
			total_min => $total_min,
			total_max => $total_max,
			percent_sum => $percent_sum,
			all_ingredients_have_a_set_percent => $all_ingredients_have_a_set_percent,
			quantity_sum => $quantity_sum,
			all_ingredients_have_a_set_quantity => $all_ingredients_have_a_set_quantity,
		}
	) if $log->is_debug();

	# Go through each ingredient to set percent_min, percent_max, and if we can an absolute percent

	foreach my $ingredient_ref (@{$ingredients_ref}) {
		if (   ((defined $ingredient_ref->{percent}) and ($ingredient_ref->{percent} > 0))
			or ($percent_mode eq "scale_grams"))
		{
			# There is a specified percent for the ingredient (or we can derive it from grams)

			if ($percent_mode eq "scale_percents") {
				# The parent percent is known, and we have set values for the percent of all ingredients
				# We can scale the percent of the ingredients so that their sum matches the parent percent
				my $percent = $ingredient_ref->{percent} * $total_max / $percent_sum;
				$ingredient_ref->{percent} = $percent;
				$ingredient_ref->{percent_min} = $percent;
				$ingredient_ref->{percent_max} = $percent;
			}
			elsif ($percent_mode eq "scale_grams") {
				# Convert gram values to percent
				my $percent = $ingredient_ref->{quantity_g} * $total_max / $quantity_sum;
				$ingredient_ref->{percent} = $percent;
				$ingredient_ref->{percent_min} = $percent;
				$ingredient_ref->{percent_max} = $percent;
			}
			elsif (($percent_mode eq "absolute") or ($total_min == $total_max)) {
				# We can assign an absolute percent to the ingredient because
				# 1. the percent mode is absolute
				# or 2. we have a specific percent for the parent ingredient
				# so we can rescale the relative percent of the ingredient to make it absolute
				my $percent
					= ($percent_mode eq "absolute")
					? $ingredient_ref->{percent}
					: $ingredient_ref->{percent} * $total_max / 100;
				$ingredient_ref->{percent} = $percent;
				$ingredient_ref->{percent_min} = $percent;
				$ingredient_ref->{percent_max} = $percent;
			}
			else {
				# The percent mode is relative and we do not have a specific percent for the parent ingredient
				# We cannot compute an absolute percent for the ingredient, but we can apply the relative percent
				# to percent_min and percent_max
				$ingredient_ref->{percent_min} = $ingredient_ref->{percent} * $total_min / 100;
				$ingredient_ref->{percent_max} = $ingredient_ref->{percent} * $total_max / 100;
				# The absolute percent is unknown, delete it
				delete $ingredient_ref->{percent};
			}
		}
		else {
			if (not defined $ingredient_ref->{percent_min}) {
				$ingredient_ref->{percent_min} = 0;
			}
			if ((not defined $ingredient_ref->{percent_max}) or ($ingredient_ref->{percent_max} > $total_max)) {
				$ingredient_ref->{percent_max} = $total_max;
			}
		}
	}

	$log->debug("init_percent_values - result", {ingredients_ref => $ingredients_ref}) if $log->is_debug();

	return;
}

=head2 set_percent_max_from_taxonomy ( ingredients_ref )

Set the percentage maximum for ingredients like flavouring where this is defined
on the Ingredients taxonomy. The percent_max will not be applied in the following cases:

 - if applying the percent_max would mean that it is not possible for the ingredient
   total to add up to 100%
 - If a later ingredient has a higher percentage than the percent_max of the restricted ingredient

=cut

sub set_percent_max_from_taxonomy ($ingredients_ref) {
	# Exit if the first ingredient is constrained
	if (!@{$ingredients_ref}
		|| defined get_inherited_property("ingredients", $ingredients_ref->[0]{id}, "percent_max:en"))
	{
		return;
	}

	# Loop backwards through ingredients, checking that we don't set a percent_max that
	# would be lower than the defined percentage of any ingredient that comes afterwards
	my $highest_later_percent = 0;
	for (my $index = scalar @{$ingredients_ref} - 1; $index > 0; $index--) {
		my $ingredient = $ingredients_ref->[$index];
		my $current_percent = $ingredient->{percent};
		if (defined $current_percent) {
			if ($current_percent > $highest_later_percent) {
				$highest_later_percent = $current_percent;
			}
		}
		else {
			# See if taxonomy defines a maximum percent
			my $percent_max = get_inherited_property("ingredients", $ingredient->{id}, "percent_max:en");
			if (defined $percent_max and $percent_max >= $highest_later_percent) {
				# Maximum percantage for ingredients like flavourings
				$ingredient->{percent_max} = $percent_max;
			}
		}
	}

	# Loop forwards through the ingredients to make sure that the maximum
	# does not limit preceding ingredients where percent is specified
	my $remaining_percent = 100;
	for my $ingredient (@{$ingredients_ref}) {
		my $defined_percent = $ingredient->{percent};
		if (!defined $defined_percent) {
			my $percent_max = $ingredient->{percent_max};
			if (defined $percent_max && $percent_max < $remaining_percent) {
				delete $ingredient->{percent_max};
			}
			last;
		}
		else {
			$remaining_percent = $remaining_percent - $defined_percent;
		}
	}

	return;
}

sub set_percent_max_values ($total_min, $total_max, $ingredients_ref) {

	my $changed = 0;

	my $current_max = $total_max;
	my $sum_of_mins_before = 0;
	my $sum_of_maxs_before = 0;

	my $i = 0;
	my $n = scalar @{$ingredients_ref};

	foreach my $ingredient_ref (@{$ingredients_ref}) {

		$i++;

		# The max of an ingredient must be lower or equal to
		# the max of the ingredient that appear before.
		if ($ingredient_ref->{percent_max} > $current_max) {
			$ingredient_ref->{percent_max} = $current_max;
			$changed++;
		}
		else {
			$current_max = $ingredient_ref->{percent_max};
		}

		# The max of an ingredient must be lower or equal to
		# the total max minus the sum of the minimums of all
		# other ingredients

		my $sum_of_mins_after = 0;
		for (my $j = $i; $j < $n; $j++) {
			$sum_of_mins_after += $ingredients_ref->[$j]{percent_min};
		}
		my $max_percent_max = $total_max - $sum_of_mins_before - $sum_of_mins_after;

		if (($max_percent_max >= 0) and ($ingredient_ref->{percent_max} > $max_percent_max)) {
			$ingredient_ref->{percent_max} = $max_percent_max;
			$changed++;
		}

		# For lists like  "Beans (52%), Tomatoes (33%), Water, Sugar, Cornflour, Salt, Spirit Vinegar"
		# we can set a maximum on Sugar, Cornflour etc. that takes into account that all ingredients
		# that appear before will have an higher quantity.
		# e.g. the percent max of Water to be set to 100 - 52 -33 = 15%
		# the max of sugar to be set to 15 / 2 = 7.5 %
		# the max of cornflour to be set to 15 / 3 etc.

		if ($i > 2) {    # This rule applies to the third ingredient and ingredients after
						 # We check that the current ingredient + the ingredient before it have a max
						 # inferior to the ingredients before, divided by 2.
						 # Then we do the same with 3 ingredients instead of 2, then 4 etc.
			for (my $j = 2; $j + 1 < $i; $j++) {
				my $max = $total_max - $sum_of_mins_before;
				for (my $k = $j; $k + 1 < $i; $k++) {
					$max += $ingredients_ref->[$i - $k]{percent_min};
				}
				$max = $max / $j;
				if ($ingredient_ref->{percent_max} > $max + 0.1) {
					$ingredient_ref->{percent_max} = $max;
					$changed++;
				}
			}
		}

		# The min of an ingredient must be greater or equal to
		# the total min minus the sum of the maximums of all
		# ingredients that appear before, divided by the number of
		# ingredients that appear after + the current ingredient

		my $min_percent_min = ($total_min - $sum_of_maxs_before) / (1 + $n - $i);

		if ($ingredient_ref->{percent_min} < $min_percent_min - 0.1) {

			# Bail out if the values are not possible
			if (($min_percent_min > $total_min) or ($min_percent_min > $ingredient_ref->{percent_max})) {
				$log->debug(
					"set_percent_max_values - impossible value, bail out",
					{
						ingredients_ref => $ingredients_ref,
						total_min => $total_min,
						min_percent_min => $min_percent_min
					}
				) if $log->is_debug();
				return -1;
			}

			$ingredient_ref->{percent_min} = $min_percent_min;
			$changed++;
		}

		$sum_of_mins_before += $ingredient_ref->{percent_min};
		$sum_of_maxs_before += $ingredient_ref->{percent_max};
	}

	return $changed;
}

sub set_percent_min_values ($total_min, $total_max, $ingredients_ref) {

	my $changed = 0;

	my $current_min = 0;
	my $sum_of_mins_after = 0;
	my $sum_of_maxs_after = 0;

	my $i = 0;
	my $n = scalar @{$ingredients_ref};

	foreach my $ingredient_ref (reverse @{$ingredients_ref}) {

		$i++;

		# The min of an ingredient must be greater or equal to the mean of the
		# ingredient that appears after.
		if ($ingredient_ref->{percent_min} < $current_min) {
			$ingredient_ref->{percent_min} = $current_min;
			$changed++;
		}
		else {
			$current_min = $ingredient_ref->{percent_min};
		}

		# The max of an ingredient must be lower or equal to
		# the total max minus the sum of the minimums of all
		# the ingredients after, divided by the number of
		# ingredients that appear before + the current ingredient

		my $max_percent_max = ($total_max - $sum_of_mins_after) / (1 + $n - $i);

		if ($ingredient_ref->{percent_max} > $max_percent_max + 0.1) {

			# Bail out if the values are not possible
			if (($max_percent_max > $total_max) or ($max_percent_max < $ingredient_ref->{percent_min})) {
				$log->debug(
					"set_percent_max_values - impossible value, bail out",
					{
						ingredients_ref => $ingredients_ref,
						total_min => $total_min,
						max_percent_max => $max_percent_max
					}
				) if $log->is_debug();
				return -1;
			}

			$ingredient_ref->{percent_max} = $max_percent_max;
			$changed++;
		}

		# The min of the ingredient must be greater or equal
		# to the total min minus the sum of the maximums of all the other ingredients

		my $sum_of_maxs_before = 0;
		for (my $j = 0; $j < ($n - $i); $j++) {
			$sum_of_maxs_before += $ingredients_ref->[$j]{percent_max};
		}
		my $min_percent_min = $total_min - $sum_of_maxs_before - $sum_of_maxs_after;

		if (($min_percent_min > 0) and ($ingredient_ref->{percent_min} < $min_percent_min - 0.1)) {

			# Bail out if the values are not possible
			if (($min_percent_min > $total_min) or ($min_percent_min > $ingredient_ref->{percent_max})) {
				$log->debug(
					"set_percent_max_values - impossible value, bail out",
					{
						ingredients_ref => $ingredients_ref,
						total_min => $total_min,
						min_percent_min => $min_percent_min
					}
				) if $log->is_debug();
				return -1;
			}

			$ingredient_ref->{percent_min} = $min_percent_min;
			$changed++;
		}

		$sum_of_mins_after += $ingredient_ref->{percent_min};
		$sum_of_maxs_after += $ingredient_ref->{percent_max};
	}

	return $changed;
}

sub set_percent_sub_ingredients ($ingredients_ref) {

	my $changed = 0;

	my $i = 0;
	my $n = scalar @{$ingredients_ref};

	foreach my $ingredient_ref (@{$ingredients_ref}) {

		$i++;

		if (defined $ingredient_ref->{ingredients}) {

			# Set values for sub-ingredients from ingredient values

			$changed += compute_ingredients_percent_min_max_values(
				$ingredient_ref->{percent_min},
				$ingredient_ref->{percent_max},
				$ingredient_ref->{ingredients}
			);

			# Set values for ingredient from sub-ingredients values

			my $total_min = 0;
			my $total_max = 0;

			foreach my $sub_ingredient_ref (@{$ingredient_ref->{ingredients}}) {

				$total_min += $sub_ingredient_ref->{percent_min};
				$total_max += $sub_ingredient_ref->{percent_max};
			}

			if ($ingredient_ref->{percent_min} < $total_min - 0.1) {
				$ingredient_ref->{percent_min} = $total_min;
				$changed++;
			}
			if ($ingredient_ref->{percent_max} > $total_max + 0.1) {
				$ingredient_ref->{percent_max} = $total_max;
				$changed++;
			}

			$log->debug("set_percent_sub_ingredients", {ingredient_ref => $ingredient_ref, changed => $changed})
				if $log->is_debug();

		}
	}

	return $changed;
}

=head2 compute_ingredients_percent_estimates ( total, ingredients_ref )

This function computes a possible estimate for the percent values of each ingredient and sub-ingredients.

The sum of all estimates must be 100%, and the estimates try to match the min and max constraints computed previously with the compute_ingredients_percent_min_max_values() function.

=head3 Arguments

=head4 total - the total of all the ingredients in ingredients_ref

100 when the function is called on all ingredients of a product, but can be different than 100 if called on sub-ingredients of an ingredient.

=head4 ingredient_ref : nested array of ingredients and sub-ingredients

=head3 Return values

=cut

sub compute_ingredients_percent_estimates ($total, $ingredients_ref) {

	my $current_total = 0;
	my $i = 0;
	my $n = scalar(@{$ingredients_ref});

	foreach my $ingredient_ref (@{$ingredients_ref}) {

		$i++;

		# Last ingredient?
		if ($i == $n) {
			$ingredient_ref->{percent_estimate} = $total - $current_total;
		}
		# Specified percent
		elsif (defined $ingredient_ref->{percent}) {
			if ($ingredient_ref->{percent} <= $total - $current_total) {
				$ingredient_ref->{percent_estimate} = $ingredient_ref->{percent};
			}
			else {
				$ingredient_ref->{percent_estimate} = $total - $current_total;
			}
		}
		else {

			# Take the middle of the possible range

			my $max = $total - $current_total;
			my $min = 0;
			if ((defined $ingredient_ref->{percent_max}) and ($ingredient_ref->{percent_max} < $max)) {
				$max = $ingredient_ref->{percent_max};
			}
			if (defined $ingredient_ref->{percent_min}) {
				$min = $ingredient_ref->{percent_min};
			}
			$ingredient_ref->{percent_estimate} = ($max + $min) / 2;
		}

		$current_total += $ingredient_ref->{percent_estimate};

		if (defined $ingredient_ref->{ingredients}) {
			compute_ingredients_percent_estimates($ingredient_ref->{percent_estimate}, $ingredient_ref->{ingredients});
		}
	}

	$log->debug("compute_ingredients_percent_estimates - done", {ingredients_ref => $ingredients_ref})
		if $log->is_debug();
	return;
}

=head2 analyze_ingredients_service ( $product_ref, $updated_product_fields_ref, $errors_ref )

Analyzes ingredients to see the ones that are vegan, vegetarian, from palm oil etc.
and computes the resulting value for the complete product.

The results are overridden by labels like "Vegan", "Vegetarian" or "Palm oil free"

Results are stored in the ingredients_analysis_tags array.

This function is a product service that can be run through ProductOpener::ApiProductServices

=head3 Arguments

=head4 $product_ref

product object reference

=head4 $updated_product_fields_ref

reference to a hash of product fields that have been created or updated

=head4 $errors_ref

reference to an array of error messages

=cut

sub analyze_ingredients_service ($product_ref, $updated_product_fields_ref, $errors_ref) {

	# Delete any existing values for the ingredients analysis fields
	delete $product_ref->{ingredients_analysis};
	delete $product_ref->{ingredients_analysis_tags};

	# and indicate that the service is creating or updatiing them
	$updated_product_fields_ref->{ingredients_analysis} = 1;
	$updated_product_fields_ref->{ingredients_analysis_tags} = 1;

	my @properties = ("from_palm_oil", "vegan", "vegetarian");
	my %properties_unknown_tags = (
		"from_palm_oil" => "en:palm-oil-content-unknown",
		"vegan" => "en:vegan-status-unknown",
		"vegetarian" => "en:vegetarian-status-unknown",
	);

	# Structure to store the result of the ingredient analysis for each property
	my $ingredients_analysis_properties_ref = {};

	# Store the lists of ingredients that resulted in a product being non vegetarian/vegan/palm oil free
	my $ingredients_analysis_ref = {};

	if ((defined $product_ref->{ingredients}) and ((scalar @{$product_ref->{ingredients}}) > 0)) {

		foreach my $property (@properties) {

			# Ingredient values for the property
			my %values = ();

			# Traverse the ingredients tree, breadth first

			my @ingredients = @{$product_ref->{ingredients}};

			while (@ingredients) {

				# Remove and process the first ingredient
				my $ingredient_ref = shift @ingredients;
				my $ingredientid = $ingredient_ref->{id};

				# Add sub-ingredients at the beginning of the ingredients array
				if (defined $ingredient_ref->{ingredients}) {

					unshift @ingredients, @{$ingredient_ref->{ingredients}};
				}

				# We may already have a value. e.g. for "matières grasses d'origine végétale" or "gélatine (origine végétale)"
				my $value = $ingredient_ref->{$property};

				if (not defined $value) {

					$value = get_inherited_property("ingredients", $ingredientid, $property . ":en");

					if (defined $value) {
						$ingredient_ref->{$property} = $value;
					}
					else {
						if (not(exists_taxonomy_tag("ingredients", $ingredientid))) {
							$values{unknown_ingredients} or $values{unknown_ingredients} = [];
							push @{$values{unknown_ingredients}}, $ingredientid;
						}

						# additives classes in ingredients are functions of a more specific ingredient
						# if we don't have a property value for the ingredient class
						# then ignore the additive class instead of considering the property undef
						elsif (exists_taxonomy_tag("additives_classes", $ingredientid)) {
							$value = "ignore";
							#$ingredient_ref->{$property} = $value;
						}
					}
				}

				# if the property value is "maybe" and the ingredient has sub-ingredients,
				# we ignore the ingredient and only look at its sub-ingredients (already added)
				# e.g. "Vegetable oil (rapeseed oil, ...)""
				if (    (defined $value)
					and ($value eq "maybe")
					and (defined $ingredient_ref->{ingredients}))
				{
					$value = "ignore";
				}

				not defined $value and $value = "undef";

				defined $values{$value} or $values{$value} = [];
				push @{$values{$value}}, $ingredientid;

				# print STDERR "ingredientid: $ingredientid - property: $property - value: $value\n";
			}

			# Compute the resulting property value for the product
			my $property_value;

			if ($property =~ /^from_/) {

				my $from_what = $';
				my $from_what_with_dashes = $from_what;
				$from_what_with_dashes =~ s/_/-/g;

				# For properties like from_palm, one positive ingredient triggers a positive result for the whole product
				# We assume that all the positive ingredients have been marked as yes or maybe in the taxonomy
				# So all known ingredients without a value for the property are assumed to be negative

				# value can can be "ignore"

				if (defined $values{yes}) {
					# One yes ingredient -> yes for the whole product
					$property_value = "en:" . $from_what_with_dashes;    # en:palm-oil
					$ingredients_analysis_ref->{$property_value} = $values{yes};
				}
				elsif (defined $values{maybe}) {
					# One maybe ingredient -> maybe for the whole product
					$property_value = "en:may-contain-" . $from_what_with_dashes;    # en:may-contain-palm-oil
					$ingredients_analysis_ref->{$property_value} = $values{maybe};
				}
				# If some ingredients are not recognized, there is a possibility that they could be palm oil or contain palm oil
				# As there are relatively few ingredients with palm oil, we assume we are able to recognize them with the taxonomy
				# and that unrecognized ingredients do not contain palm oil.
				# --> We mark the product as palm oil free
				# Exception: If there are lots of unrecognized ingredients though (e.g. more than 1 third), it may be that the ingredients list
				# is bogus (e.g. OCR errors) and the likelyhood of missing a palm oil ingredient increases.
				# --> In this case, we mark the product as palm oil content unknown
				elsif (defined $values{unknown_ingredients}) {
					# Some ingredients were not recognized
					$log->debug(
						"analyze_ingredients - unknown ingredients",
						{
							unknown_ingredients_n => (scalar @{$values{unknown_ingredients}}),
							ingredients_n => (scalar(@{$product_ref->{ingredients}}))
						}
					) if $log->is_debug();
					my $unknown_rate
						= (scalar @{$values{unknown_ingredients}}) / (scalar @{$product_ref->{ingredients}});
					# for palm-oil, as there are few products containing it, we consider status to be unknown only if there is more than 30% unknown ingredients (which may indicates bogus ingredient list, eg. OCR errors)
					if (($from_what_with_dashes eq "palm-oil") and ($unknown_rate <= 0.3)) {
						$property_value = "en:" . $from_what_with_dashes . "-free";    # en:palm-oil-free
					}
					else {
						$property_value = $properties_unknown_tags{$property};    # en:palm-oil-content-unknown
					}
					# In all cases, keep track of the unknown ingredients
					$ingredients_analysis_ref->{$properties_unknown_tags{$property}} = $values{unknown_ingredients};
				}
				else {
					# no yes, maybe or unknown ingredients
					$property_value = "en:" . $from_what_with_dashes . "-free";    # en:palm-oil-free
				}
			}
			else {

				# For properties like vegan or vegetarian, one negative ingredient triggers a negative result for the whole product
				# Known ingredients without a value for the property: we do not make any assumption
				# We assume that all the positive ingredients have been marked as yes or maybe in the taxonomy
				# So all known ingredients without a value for the property are assumed to be negative

				if (defined $values{no}) {
					# One no ingredient -> no for the whole product
					$property_value = "en:non-" . $property;    # en:non-vegetarian
					$ingredients_analysis_ref->{$property_value} = $values{no};
				}
				elsif (defined $values{"undef"}) {
					# Some ingredients were not recognized or we do not have a property value for them
					$property_value = $properties_unknown_tags{$property};    # en:vegetarian-status-unknown
					$ingredients_analysis_ref->{$property_value} = $values{"undef"};
				}
				elsif (defined $values{maybe}) {
					# One maybe ingredient -> maybe for the whole product
					$property_value = "en:maybe-" . $property;    # en:maybe-vegetarian
					$ingredients_analysis_ref->{$property_value} = $values{maybe};
				}
				else {
					# all ingredients known and with a value, no no or maybe value -> yes
					$property_value = "en:" . $property;    # en:vegetarian
				}

				# In all cases, keep track of unknown ingredients so that we can display unknown ingredients
				# even if some ingredients also triggered non-vegan or non-vegetarian
				if (defined $values{"undef"}) {
					$ingredients_analysis_ref->{$properties_unknown_tags{$property}} = $values{"undef"};
				}
			}

			$property_value =~ s/_/-/g;

			$ingredients_analysis_properties_ref->{$property} = $property_value;
		}
	}

	# Apply labels overrides
	# also apply labels overrides if we don't have ingredients at all
	if (has_tag($product_ref, "labels", "en:palm-oil-free")) {
		$ingredients_analysis_properties_ref->{from_palm_oil} = "en:palm-oil-free";
	}

	if (has_tag($product_ref, "labels", "en:vegan")) {
		$ingredients_analysis_properties_ref->{vegan} = "en:vegan";
		$ingredients_analysis_properties_ref->{vegetarian} = "en:vegetarian";
	}
	elsif (has_tag($product_ref, "labels", "en:non-vegan")) {
		$ingredients_analysis_properties_ref->{vegan} = "en:non-vegan";
	}

	if (has_tag($product_ref, "labels", "en:vegetarian")) {
		$ingredients_analysis_properties_ref->{vegetarian} = "en:vegetarian";
	}
	elsif (has_tag($product_ref, "labels", "en:non-vegetarian")) {
		$ingredients_analysis_properties_ref->{vegetarian} = "en:non-vegetarian";
		$ingredients_analysis_properties_ref->{vegan} = "en:non-vegan";
	}

	# Create ingredients_analysis_tags array

	if (scalar keys %$ingredients_analysis_properties_ref) {
		$product_ref->{ingredients_analysis_tags} = [];
		$product_ref->{ingredients_analysis} = {};

		foreach my $property (@properties) {
			my $property_value = $ingredients_analysis_properties_ref->{$property};
			if (defined $property_value) {
				# Store the property value in the ingredients_analysis_tags list
				push @{$product_ref->{ingredients_analysis_tags}}, $property_value;
				# Store the list of ingredients that caused a product to be non vegan/vegetarian/palm oil free
				if (defined $ingredients_analysis_ref->{$property_value}) {
					$product_ref->{ingredients_analysis}{$property_value}
						= $ingredients_analysis_ref->{$property_value};
				}

				# Also store the list of ingredients that are not recognized
				if (defined $ingredients_analysis_ref->{$properties_unknown_tags{$property}}) {
					$product_ref->{ingredients_analysis}{$properties_unknown_tags{$property}}
						= $ingredients_analysis_ref->{$properties_unknown_tags{$property}};
				}
			}
		}
	}

	# Uncomment the following line to add an extra field with more data for debugging purposes
	#$product_ref->{ingredients_analysis_debug} = $ingredients_analysis_ref;
	return;
}

# function to normalize strings like "Carbonate d'ammonium" in French
# x is the prefix
# y can contain de/d' (of in French)
sub normalize_fr_a_de_b ($a, $b) {

	$a =~ s/\s+$//;
	$b =~ s/^\s+//;

	$b =~ s/^(de |d')//;

	if ($b =~ /^(a|e|i|o|u|y|h)/i) {
		return $a . " d'" . $b;
	}
	else {
		return $a . " de " . $b;
	}
}

# This function removes labels like "organic" from ingredients, so that we can check if they exist
# with canonicalize_taxonomy_tag. The labels can be parsed out when doing ingredients analysis.

sub remove_parsable_labels ($ingredients_lc, $ingredient) {
	if ($ingredients_lc eq "en") {
		$ingredient =~ s/(?:organic |fair trade )*//ig;
	}
	elsif ($ingredients_lc eq "fr") {
		$ingredient =~ s/(?: bio| biologique| équitable|s|\s|' . $symbols_regexp . ')//ig;
	}
	return $ingredient;
}

=head2 normalize_a_of_b ( $lc, $a, $b, $of_bool, $alternate_names_ref = undef )

This function is called by normalize_enumeration()

Given a category ($a) and a type ($b), it will return the ingredient that result from the combination of these two.

English: oil, olive -> olive oil
Croatian: ječmeni, slad -> ječmeni slad
French: huile, olive -> huile d'olive
Russian: масло растительное, пальмовое -> масло растительное оливковое

=head3 Arguments

=head4 lc

language abbreviation (en for English, for example)

=head4 $a

string, category as defined in %ingredients_categories_and_types, example: 'oil' for 'oil (sunflower, olive and palm)'

=head4 $b

string, type as defined in %ingredients_categories_and_types, example: 'sunflower' or 'olive' or 'palm' for 'oil (sunflower, olive and palm)'

=head4 $of_bool - indicate if we want to construct entries like "<category> of <type>"

e.g. in French we combine "huile" and "olive" to "huile d'olive"
but we combine "poivron" and "rouge" to "poivron rouge".

=head4 $alternate_names_ref

Reference to an array of alternate names for the category

=head3 Return value

=head4 combined $a and $b (or $b and $a, depending of the language), that is expected to be an ingredient

string, comma-joined category and type, example: 'palm vegetal oil' or 'sunflower vegetal oil' or 'olive vegetal oil'

=cut

sub normalize_a_of_b ($ingredients_lc, $a, $b, $of_bool, $alternate_names_ref = undef) {

	$a =~ s/\s+$//;
	$b =~ s/^\s+//;

	my $a_of_b;

	if (($ingredients_lc eq "en") or ($ingredients_lc eq "hr")) {
		# start by "with" (example: "mlijeko (s 1.0% mliječne masti)"), in which case it $b should be added after $a
		# start by "with etc." should be added at the end of the previous ingredient
		my %with = (hr => '(s | sa )',);
		my $with = $with{$ingredients_lc} || " will not match ";
		if ($b =~ /^$with/i) {
			$a_of_b = $a . " " . $b;
		}
		else {
			$a_of_b = $b . " " . $a;
		}
	}
	elsif ($ingredients_lc eq "es") {
		$a_of_b = $a . " de " . $b;
	}
	elsif ($ingredients_lc eq "fr") {
		$b =~ s/^(de |d')//;

		if (($b =~ /^(a|e|i|o|u|y|h)/i) && ($of_bool == 1)) {
			$a_of_b = $a . " d'" . $b;
		}
		elsif ($of_bool == 1) {
			$a_of_b = $a . " de " . $b;
		}
		else {
			$a_of_b = $a . " " . $b;
		}
	}
	elsif (($ingredients_lc eq "de") or ($ingredients_lc eq "ru") or ($ingredients_lc eq "pl")) {
		$a_of_b = $a . " " . $b;
	}
	else {
		die("unsupported language in normalize_a_of_b: $ingredients_lc, $a, $b");
	}

	# If we have alternate categories, check if $a_of_b is an existing taxonomy entry,
	# otherwise check if we have entries with one of the alternate categories

	if (defined $alternate_names_ref) {

		my $name_exists;
		# remove labels like "organic", "fairtrade": they can be parsed out when doing ingredients analysis
		# TODO: use the labels regexps instead
		my $a_of_b_copy = remove_parsable_labels($ingredients_lc, $a_of_b);
		canonicalize_taxonomy_tag($ingredients_lc, "ingredients", $a_of_b_copy, \$name_exists);
		print STDERR "a: $a - b: $b - $a_of_b: $a_of_b - a_of_b_copy: $a_of_b_copy: - $name_exists\n";

		if (not $name_exists) {
			foreach my $alternate_name (@{$alternate_names_ref}) {
				my $alternate_name_copy
					= $alternate_name;    # make a copy so that we can modify it without changing the array entry
				$alternate_name_copy =~ s/<type>/$b/;
				my $alternate_name_exists;
				canonicalize_taxonomy_tag($ingredients_lc, "ingredients", $alternate_name_copy,
					\$alternate_name_exists);
				print STDERR
					"alternate_name: $alternate_name - alternate_name_copy: $alternate_name_copy: - $alternate_name_exists\n";
				if ($alternate_name_exists) {
					$a_of_b = $alternate_name_copy;
					last;
				}
			}
		}
	}

	return $a_of_b;
}

=head2 normalize_enumeration ($ingredients_lc, $category, $types, $of_bool, $alternate_names_ref = undef, $do_not_output_parent = undef)


This function is called by develop_ingredients_categories_and_types()

Some ingredients are specified by an ingredient "category" (e.g. "oil") and a "types" string (e.g. "sunflower, palm").

This function combines the category to all elements of the types string
$category = "Vegetal oil" and $types = "palm, sunflower and olive"
will return
"vegetal oil (palm vegetal oil, sunflower vegetal oil, olive vegetal oil)"

=head3 Arguments

=head4 lc

language abbreviation (en for English, for example)

=head4 category

string, as matched from definition in %ingredients_categories_and_types, example: 'Vegetal oil' for 'Vegetal oil (sunflower, olive and palm)'

=head4 types

string, as matched from definition in %ingredients_categories_and_types, example: 'sunflower, olive and palm' for 'Vegetal oil (sunflower, olive and palm)'

=head4 $of_bool - indicate if we want to construct entries like "<category> of <type>"

e.g. in French we combine "huile" and "olive" to "huile d'olive"
but we combine "poivron" and "rouge" to "poivron rouge".

=head4 $alternate_names_ref

Reference to an array of alternate names for the category

=head4 $do_not_output_parent - indicate if we want to output the parent ingredient

e.g. for "carbonates d'ammonium et de sodium", we want only "carbonates d'ammonium, carbonates de sodium"
and not "carbonates (carbonates d'ammonium, carbonates de sodium)" as "carbonates" is another additive

=head3 Return value

=head4 Transformed ingredients list text

string, with the type + a list of comma-joined category with all elements of the types
example: 'vegetal oils (sunflower vegetal oil, olive vegetal oil, palm vegetal oil)'

=cut

sub normalize_enumeration (
	$ingredients_lc, $category, $types, $of_bool,
	$alternate_names_ref = undef,
	$do_not_output_parent = undef
	)
{
	$log->debug("normalize_enumeration", {category => $category, types => $types}) if $log->is_debug();

	# If there is a trailing space, save it and output it
	my $trailing_space = "";
	if ($types =~ /\s+$/) {
		$trailing_space = " ";
	}

	# do not match anything if we don't have a translation for "and"
	my $and = $and{$ingredients_lc} || " will not match ";

	my @list = split(/$obrackets|$cbrackets|\/| \/ | $dashes |$commas |$commas|$and/i, $types);

	# If we have a percent or quantity, we output it only for the parent
	my $category_without_percent_or_quantity = $category;
	my $percent_or_quantity_regexp = $percent_or_quantity_regexps{$ingredients_lc};
	$category_without_percent_or_quantity =~ s/$percent_or_quantity_regexp//ig;

	my $list = join(
		", ",
		map {
			normalize_a_of_b($ingredients_lc, $category_without_percent_or_quantity, $_, $of_bool, $alternate_names_ref)
		} @list
	);

	unless ($do_not_output_parent) {
		$list = $category . " (" . $list . ")";
	}

	return $list . $trailing_space;
}

# iodure et hydroxide de potassium
sub normalize_fr_a_et_b_de_c ($a, $b, $c) {

	return normalize_fr_a_de_b($a, $c) . ", " . normalize_fr_a_de_b($b, $c);
}

sub normalize_additives_enumeration ($ingredients_lc, $enumeration) {

	$log->debug("normalize_additives_enumeration", {enumeration => $enumeration}) if $log->is_debug();

	# do not match anything if we don't have a translation for "and"
	my $and = $and{$ingredients_lc} || " will not match ";

	my @list = split(/$obrackets|$cbrackets|\/| \/ | $dashes |$commas |$commas|$and/i, $enumeration);

	return join(", ", map {"E" . $_} @list);
}

sub normalize_vitamin ($lc, $a) {

	$log->debug("normalize vitamin", {vitamin => $a}) if $log->is_debug();
	$a =~ s/\s+$//;
	$a =~ s/^\s+//;

	# does it look like a vitamin code?
	if ($a =~ /^[a-z][a-z]?-? ?\d?\d?$/i) {
		($lc eq 'ca') and return "vitamina $a";
		($lc eq 'es') and return "vitamina $a";
		($lc eq 'fr') and return "vitamine $a";
		($lc eq 'fi') and return "$a-vitamiini";
		($lc eq 'it') and return "vitamina $a";
		($lc eq 'nl') and return "vitamine $a";
		($lc eq 'is') and return "$a-vítamín";
		($lc eq 'pl') and return "witamina $a";
		return "vitamin $a";
	}
	else {
		return $a;
	}
}

sub normalize_vitamins_enumeration ($lc, $vitamins_list) {

	# do not match anything if we don't have a translation for "and"
	my $and = $and{$lc} || " will not match ";

	# The ?: makes the group non-capturing, so that the split does not create an extra item for the group
	my @vitamins = split(/(?:\(|\)|\/| \/ | - |, |,|$and)+/i, $vitamins_list);

	$log->debug("splitting vitamins", {vitamins_list => $vitamins_list, vitamins => \@vitamins}) if $log->is_debug();

	# first output "vitamines," so that the current additive class is set to "vitamins"
	my $split_vitamins_list;

	if ($lc eq 'da' || $lc eq 'nb' || $lc eq 'sv') {$split_vitamins_list = "vitaminer"}
	elsif ($lc eq 'de' || $lc eq 'it') {$split_vitamins_list = "vitamine"}
	elsif ($lc eq 'ca') {$split_vitamins_list = "vitamines"}
	elsif ($lc eq 'es') {$split_vitamins_list = "vitaminas"}
	elsif ($lc eq 'fr') {$split_vitamins_list = "vitamines"}
	elsif ($lc eq 'fi') {$split_vitamins_list = "vitamiinit"}
	elsif ($lc eq 'nl') {$split_vitamins_list = "vitaminen"}
	elsif ($lc eq 'is') {$split_vitamins_list = "vítamín"}
	elsif ($lc eq 'pl') {$split_vitamins_list = "witaminy"}
	else {$split_vitamins_list = "vitamins"}

	$split_vitamins_list .= ", " . join(", ", map {normalize_vitamin($lc, $_)} @vitamins);

	$log->debug("vitamins split", {input => $vitamins_list, output => $split_vitamins_list}) if $log->is_debug();

	return $split_vitamins_list;
}

sub normalize_allergen ($type, $lc, $allergen) {

	# $type  ->  allergens or traces

	$log->debug("normalize allergen", {allergen => $allergen})
		if $log->is_debug();

	my $of = ' - ';
	if (defined $of{$lc}) {
		$of = $of{$lc};
	}
	my $and_of = ' - ';
	if (defined $and_of{$lc}) {
		$and_of = $and_of{$lc};
	}

	# "de moutarde" -> moutarde
	# "et de la moutarde" -> moutarde

	$allergen = " " . $allergen;
	$allergen =~ s/^($and_of|$of)\b//;
	$allergen =~ s/\s+$//;
	$allergen =~ s/^\s+//;

	return $Lang{$type}{$lc} . " : " . $allergen;
}

sub normalize_allergens_enumeration ($type, $lc, $before, $allergens_list, $after) {

	# $type    ->  allergens or traces
	# $before  ->  may contain an opening parenthesis

	$log->debug("splitting allergens", {input => $allergens_list, before => $before, after => $after})
		if $log->is_debug();

	# do not match anything if we don't have a translation for "and"
	my $and = $and{$lc} || " will not match ";

	$log->debug("splitting allergens", {input => $allergens_list}) if $log->is_debug();

	# remove stopwords at the end
	# e.g. Kann Spuren von Senf und Sellerie enthalten.
	if (defined $allergens_stopwords{$lc}) {
		my $stopwords = $allergens_stopwords{$lc};
		$allergens_list =~ s/( ($stopwords)\b)+(\.|$)/$3/ig;
	}

	$log->debug("splitting allergens after removing stopwords", {input => $allergens_list}) if $log->is_debug();

	my @allergens = split(/\(|\)|\/| \/ | - |, |,|$and/i, $allergens_list);

	my $split_allergens_list = " " . join(", ", map {normalize_allergen($type, $lc, $_)} @allergens) . ".";
	# added ending . to facilite matching and removing when parsing ingredients

	# if there was a closing parenthesis after, remove it only if there is an opening parenthesis before
	# e.g. contains (milk) -> contains milk
	# but: (contains milk) -> (contains milk)

	if ((defined $after) and ($after eq ')') and ($before !~ /\(/)) {
		$split_allergens_list .= $after;
	}

	$log->debug("allergens split", {input => $allergens_list, output => $split_allergens_list}) if $log->is_debug();

	return $split_allergens_list;
}

# Ingredients: list of ingredients -> phrases followed by a colon, dash, or line feed

my %phrases_before_ingredients_list = (

	ar => ['المكونات',],

	az => ['Tarkibi',],

	bg => ['Съставки', 'Състав',],

	bs => ['Sastoji',],

	ca => ['Ingredient(s)?', 'composició',],

	cs => ['složení',],

	da => ['ingredienser', 'indeholder', 'Sammensætning',],

	de => ['Zusammensetzung', 'zutat(en)?',],

	el => ['Συστατικά', 'Σύνθεση',],

	en => ['composition', 'ingredient(s?)',],

	es => ['composición', 'ingredientes',],

	et => ['koostisosad', 'Koostis',],

	fi => ['aine(?:kse|s?osa)t(?:\s*\/\s*ingredienser)?', 'ainesosia', 'valmistusaineet', 'Kokoonpano', 'koostumus',],

	fr => [
		'ingr(e|é)dient(s?)',
		'Quels Ingr(e|é)dients ?',    # In Casino packagings
		'composition',    # pet food
	],

	hr =>
		['HR BiH', 'HR/BIH', 'naziv', 'naziv proizvoda', 'popis sastojaka', 'sastav', 'sastojci', 'sastojci/sestavine'],

	hu => ['(ö|ő|o)sszetev(ö|ő|o)k', 'összetétel',],

	id => ['komposisi',],

	is => ['innihald(?:slýsing|sefni)?', 'inneald',],

	it => ['ingredienti', 'composizione',],

	ja => ['原材料名',],

	kk => ['курамы',],

	ko => ['配料',],

	ky => ['курамы',],

	lt => ['Sudedamosios dalys', 'Sudėtis',],

	lv => ['sast[āäa]v(s|da[ļl]as)',],

	mk => ['Состојки',],

	md => ['(I|i)ngrediente',],

	nl => ['(I|i)ngredi(e|ë)nten', 'samenstelling', 'bestanddelen'],

	nb => ['Ingredienser',],

	no => ['Sammensetning',],

	pl => ['sk[łl]adniki', 'skład',],

	pt => ['ingredientes', 'composição',],

	ro => ['(I|i)ngrediente', 'compozi(ţ|ț)ie',],

	ru => ['состав', 'coctab', 'Ингредиенты',],

	sk => ['obsahuje', 'zloženie',],

	sl => ['(S|s)estavine', 'Sestava',],

	sq => ['P[eë]rb[eë]r[eë]sit',],

	sr => ['Sastojci',],

	sv => ['ingredienser', 'innehåll(er)?', 'Sammansättning',],

	tg => ['Таркиб',],

	th => ['ส่วนประกอบ', 'ส่วนประกอบที่สำคัญ',],

	tr => ['Bileşim', '(İ|i)çindekiler', 'içeriği',],

	uz => ['tarkib', 'Mahsulot tarkibi',],

	zh => ['配料', '成份',],

);

# INGREDIENTS followed by lowercase list of ingredients

my %phrases_before_ingredients_list_uppercase = (

	en => ['INGREDIENT(S)?', 'COMPOSITION',],

	bg => ['СЪСТАВ',],

	ca => ['INGREDIENT(S)?',],

	cs => ['SLOŽENÍ',],

	da => ['INGREDIENSER', 'ZUSAMMENSETZUNG', 'SAMMENSÆTNING',],

	de => ['ZUTAT(EN)?', 'ZUSAMMENSETZUNG',],

	el => ['ΣΥΣΤΑΤΙΚΑ', 'ΣΎΝΘΕΣΗ',],

	es => ['COMPOSICIÓN', 'INGREDIENTE(S)?',],

	et => ['KOOSTIS',],

	fi => ['AINE(?:KSE|S?OSA)T(?:\s*\/\s*INGREDIENSER)?', 'KOKOONPANO', 'VALMISTUSAINEET',],

	fr => ['INGR(E|É)(D|0|O)IENTS', 'COMPOSITION'],

	hr => ['SASTAV',],

	hu => ['(Ö|O|0)SSZETEVOK', 'ÖSSZETÉTEL',],

	is => ['INNIHALD(?:SLÝSING|SEFNI)?', 'INNEALD',],

	it => ['INGREDIENTI(\s*)', 'COMPOSIZIONE'],

	lt => ['SUDĖTIS',],

	lv => ['SASTĀVS',],

	nb => ['INGREDIENSER',],

	nl => ['INGREDI(E|Ë)NTEN(\s*)', 'INGREDIENSER', 'SAMENSTELLING',],

	no => ['SAMMENSETNING',],

	pl => ['SKŁADNIKI(\s*)', 'SKŁAD',],

	pt => ['COMPOSIÇÃO', 'INGREDIENTES(\s*)', 'COMPOSIÇÃO',],

	ro => ['COMPOZIȚIE',],

	ru => ['COCTАB', 'СОСТАВ',],

	sk => ['ZLOŽENIE',],

	sl => ['SESTAVINE', 'SESTAVA',],

	sv => ['INGREDIENSER', 'INNEHÅLL(ER)?', 'SAMMANSÄTTNING',],

	tr => ['BİLEŞİM',],

	uz => ['ІHГРЕДІЄНТИ',],

	uz => ['TARKIB',],

	vi => ['TH(A|À)NH PH(A|Â)N',],

);

my %phrases_after_ingredients_list = (

	# TODO: Introduce a common list for kcal

	al => [
		't(e|ë) ruhet n(e|ë)',    # store in
	],

	bg => [
		'да се съхранява (в закрити|на сухо)',    # store in ...
		'Аналитични съставки',    # pet food
		'Неотворен',    # before opening ...
		'След отваряне'    # after opening ...
	],

	ca => ['envasat en atmosfera protectora', 'conserveu-los en un lloc fresc i sec',],

	cs => [
		'analytické složky',    # pet food
		'doporu)c|č)eny zp(u|ů)sob p(r|ř)(i|í)pravy',
		'minim(a|á)ln(i|í) trvanlivost do',    # Expiration date
		'po otev(r|ř)en(i|í)',    # After opening
		'V(ý|y)(ž|z)ivov(e|é) (ú|u)daje ve 100 g',
		'skladujte v suchu',    # keep in dried place
	],

	da => [
		'(?:gennemsnitlig )?n(æ|ae)rings(?:indhold|værdi|deklaration)',
		'analytiske bestanddele',    # pet food
		'beskyttes',
		'nettovægt', 'åbnet',
		'holdbarhed efter åbning', 'mindst holdbar til',
		'opbevar(?:ing|res)?', '(?:for )?allergener',
		'produceret af', 'tilberedning(?:svejledning)?',
	],

	de => [
		'analytische bestandteile',    # pet food
		'Ern(â|a|ä)hrungswerte',
		'Mindestens altbar bis',
		'Mindestens haltbar bis',
		'davon ges(â|a|ä)tigte Fettsäuren',
		'davon Zuckerarten',
		'davon ges(â|a|ä)ttigte',
		'Durchschnittlich enthalten 100 (ml|g)',
		'Durchschnittliche N(â|a|ä)hrwerte',
		'DURCHSCHNITTLICHE NÄHRWERTE',
		'Durchschnittliche N(â|a|ä)hrwert(angaben|angabe)',
		# 'Kakao: \d\d\s?% mindestens.', # allergens can appear after.
		'N(â|a|ä)hrwert(angaben|angabe|information|tabelle)',    #Nährwertangaben pro 100g
		'N(â|a|ä)hrwerte je',
		'Nâhrwerte',
		'(Ungeöffnet )?mindestens',
		'(k[uü]hl|bei Zimmertemperatur) und trocken lagern',
		'Rinde nicht zum Verzehr geeignet.',
		'Vor W(â|a|ä)rme und Feuchtigkeit sch(u|ü)tzen',
		'Unge(ö|o)ffnet (bei max.|unter)',
		'Unter Schutzatmosphäre verpackt',
		'verbrauchen bis',
		'Vor und nach dem Öffnen',    # keep in dried place
		'Vor Wärme geschützt (und trocken )?lagern',
		'Vorbereitung Tipps',
		'zu verbrauchen bis',
		'100 (ml|g) enthalten durchschnittlich',
		'\d\d\d\sg\s\w*\swerden aus\s\d\d\d\sg\s\w*\shergestellt'
		,    # 100 g Salami werden aus 120 g Schweinefleisch hergestellt.
		'Alle Zutaten sind aus biologischem Anbau',
		'außer die mit * markierten Bestandteile'
	],

	el => [
		'Αναλυτικές συστατικές',    # pet food
		'ΔΙΑΘΡΕΠΤΙΚΗ ΕΠΙΣΗΜΑΝΣΗ',    #Nutritional labelling
		'ΔΙΤΡΟΦΙΚΕΣ ΠΗΡΟΦΟΡΙΕΣ',
	],

	en => [
		'adds a trivial amount',    # e.g. adds a trivial amount of added sugars per serving
		'after opening',
		'analytical constituents',    # pet food
									  #'Best before',
		'keep cool and dry',
		'Can be stored unopened at room temperature',
		'instruction',
		'nutrition(al)? (as sold|facts|information|typical|value[s]?)',
		# "nutrition advice" seems to appear before ingredients rather than after.
		# "nutritional" on its own would match the ingredient "nutritional yeast" etc.
		'of whlch saturates',
		'of which saturates',
		'of which saturated fat',
		'((\d+)(\s?)kJ\s+)?(\d+)(\s?)kcal',
		'once opened[,]? (consume|keep|refrigerate|store|use)',
		'packed in a modified atmosphere',
		'(Storage( instructions| conditions)?[: ]+)?Store in a cool[,]? dry place',
		'(dist(\.)?|distributed|sold)(\&|and|sold| )* (by|exclusively)',
		#'See bottom of tin',
	],

	es => [
		'componentes analíticos',    # pet food
		'valores nutricionales',
		'modo de preparacion',
		'informaci(o|ó)n nutricional',
		'valor energ(e|é)tico',
		'condiciones de conservaci(o|ó)n',
		#'pa(i|í)s de transformaci(o|ó)n',
		'cons[eé]rv(ar|ese) en( un)? lug[ae]r (fresco y seco|seco y fresco)',
		'contiene azúcares naturalmente presentes',
		'distribuido por',    # distributed for
		'de los cuales az(u|ú)cares',
		'de las cuales saturadas',
		'envasado',    # Packaging in protective atmosphere.
		'Mantener en lugar fresco y seco',
		'obtenga más información',    # get more information
		'protegido de la luz',
		'conser(y|v)ar entre',
		'una vez abierto',
		'conservaci(o|ó)n:',
		'consumir? preferentemente antes del',
		#Envasado por:
	],

	et => [
		'analüütilised komponendid',    # pet food
		'parim enne',    # best before
	],

	fi => [
		'100 g:aan tuotetta käytetään',
		'analyyttiset ainesosat',    # pet food
		'Energiaa per',
		'Kypsennys',
		'Makeisten sekoitussuhde voi vaihdella',
		'Pakattu suojakaasuun',
		'Parasta ennen',
		'Viimeinen käyttöpäivä',
		'(?:Keskimääräinen )?Ravinto(?:arvo|sisältö)',
		'Sisältää aluspaperin',
		'Suositellaan säilytettäväksi',
		'Säily(?:tettävä|tetään|tys|y)',
		'Tämä tuote on tehty ihmisille',
		'Valmist(?:aja:|us)',
	],

	fr => [
		'constituants analytiques',    # pet food
		'valeur(s?) (e|é)nerg(e|é)tique',
		'valeur(s?) nutritives',
		'valeur nutritive',
		'valeurs mo(y|v)ennes',
		'valeurs nutritionelles moyennes',
		'valeur nutritionnelle mo(y|v)enne',
		'valeur nutritionnelle',
		'(va(l|t)eurs|informations|d(e|é)claration|analyse|rep(e|è)res) (nutritionnel)(s|le|les)?',
		'(a|à) consommer de pr[ée]f[ée]rence',
		'(a|à) consommer de',
		'(a|à) cons.de préférence avant',
		'(a|à) consommer (cuit|rapidement|dans|jusqu)',
		'(a|à)[ ]?conserver (entre|dans|de|au|a|à)',
		'Allergènes: voir les ingrédients en gras',
		'Attention: les enfants en bas âge risquent de',
		'apr(e|è)s (ouverture|achat)',
		'apport de r(e|é)ference pour un adulte type',
		'caractéristiques nu(t|f)ritionnelles',
		'Conditionné sous vide',
		'(conseil|conseils) de pr(e|é)paration',
		'(conditions|conseils) de conservation',
		'conseil d\'utilisation',
		'conserver dans un endroit',
		'conservation[ ]?:',
		'Croûte en matière plastique non comestible',
		'dans le compartiment (a|à) gla(c|ç)ons',
		'de préférence avant le',
		'dont sucres',
		'dont acides (gras|ras) satur(e|é)s',
		'Fabriquee à partir de fruits entiers',
		'Fabriqué dans un atelier qui utilise',
		'garder dans un endroit frais et sec',
		'information nutritionnelle',
		'((\d+)(\s?)kJ\s+)?(\d+)(\s?)kcal',
		'la pr(e|é)sence de vide',    # La présence de vide au fond du pot est due au procédé de fabrication.
		'Modes de pr(e|é)paration',
		'Mode de pr(e|é)paration',
		'moyennes pour 100(g|ml)',
		'Naturellement riche en fibres',
		'ne jamais recongeler un produit décongelé',
		'nutritionnelles mo(y|v)ennes'
		,    # in case of ocr issue on the first word "valeurs" v in case the y is cut halfway
		'nutritionnelles pour 100(g|ml)',    #Arôme Valeum nutritionnelles pour 100g: Energie
		'Nutrition pour 100 (g|ml)',
		'pensez au tri',
		'Peux contenir des morceaux de noyaux',
		'pour en savoir plus',
		'pr(e|é)paration au four',
		'Prépar(e|é)e? avec',
		'(produit )?(a|à) protéger de ',    # humidité, chaleur, lumière etc.
		'(produit )?conditionn(e|é) sous atmosph(e|è)re protectrice',
		'N(o|ò)us vous conseillons',
		'Non ouvert,',
		'Sans conservateur',    # remark: also label
		'(Utilisation: |Préparation: )?Servir frais',
		'Temps de Cuisson',
		'tenir à l\'abri',
		'Teneur en matière grasse',
		'(Chocolat: )?teneur en cacao',
		'Teneur totale en sucres',
		# Belgian products often mix languages and thus can have ending phrases in dutch
		'Gemiddelde voedingswaarde',
		#'Pour votre santé',
		#'La certification Fairtrade assure',
		#Préparation:
		#'ne pas laisser les enfants' # Ne pas laisser les enfants de moins de 36 mols sans surveillance avec le bouchon dévissable. BT Daonan ar
		#`etten/Matières grasses`, # (Vetten mais j'avais Netten/Matières grasses)
		#'dont sucres',
		#'dontSUcres',
		#'waarvan suikers/
		#`verzadigde vetzuren/ acides gras saturés`,
		#`Conditionné par`,
	],

	hr => [
		'(prije otvaranja )?((č|Č|c|C|ć|Ć)uvati|(č|Č|c|C|ć|Ć)uvajte)',    # store in...
		'analitički sastav',    # pet food
		'izvaditi',    # remove from the refrigerator half an hour before consumption
		'način pripreme',    # preparation
		'(najbolje )upotrijebiti',    # best before
		'nakon otvaranja',    # after opening
		'neotvoreno',    # not opened can be stored etc.
		'neto koli(č|Č|c|C|ć|Ć)ina',    # net weigth
		'nije potrebno kuhati',    # no need to keep
		'pakirano',    # packed in a ... atmosphere (Pakirano/Pakovano u)
		'pakiranje sadrži',    # pack contains x portions
		'prekomjerno konzumiranje',    # excessive consumption can have a laxative effect
		'preporučuje se',    # preparation
		'Prijedlog za serviranje',    # Proposal for serving
		'priprema(:| obroka)',    # meal preparation
		'proizvod je termički obrađen-pasteriziran',    # pasteurized
		'proizvod sadrži sumporni dioksid',    # The product contains sulfur dioxide
		'proizvođač',    # producer
		'prosječn(a|e) (hranjiva|hranjive|nutritivne) (vrijednost|vrijednosti)',    # Average nutritional value
		'(protresti )prije (i poslije )otvaranja',    # shake before opening
		'suha tvar min',    # dry matter min 9%
		'unato(č|Č|c|C|ć|Ć) vi(š|Š|s|S)estrukim kontrolama',    # despite numerous controls ...
		'upotreba u jelima',    # meal preparation
		'upozorenje',    # warning
		'uputa',    # instructions
		'upute za upotrebu',    # instructions
		'uvjeti čuvanja',    # storage conditions
		'uvoznik [i distributer ]za',    # importer
		'vakuumirana',    # Vacuumed
		'vrijeme kuhanja',    # Cooking time
		'zbog (mutan|prisutnosti)',    # Due to ...
	],

	hu => [
		'Atlagos tápérték 100g termékben',
		'((száraz|hűvös|(közvetlen )?napfénytől védett)[, ]*)+helyen tárolandó',    # store in cool/dry/etc
		'elemzési összetevők',    # pet food
		'hűvös, száraz helyen, közvetlen napfénytől védve tárolja',    # store in cool dry place away from the sunlight
		'bontatlan csomagolásban',    # keep in a closed/dark place
		'tárolás',    # conservation
	],

	is => ['n(æ|ae)ringargildi', 'geymi(st|ð) á', 'eftir opnum', 'aðferð',],

	it => [
		'componenti analitici',    # pet food
		'Confezionato in atmosfera protettiva',    # Packaged in a protective atmosphere
		'(dopo l\'apertura )?Conservare in (frigo|luogo)',
		'consigli per la preparazione',
		'Da consumarsi',    # best before
		'di cui zuccheri',
		'MODALITA D\'USO',
		'MODALITA DI CONSERVAZIONE',
		'Preparazione:',
		'Una volta aperto',    # once opened...
		'Valori nutritivi',
		'valori nutrizionali',
	],

	ja => [
		'栄養価',    # nutritional value
		'内容量',    # weight
		'賞味期限',    # best before
	],

	lt => [
		'analizinės sudėties',    # pet food
		'geriausias iki',    # best before
		'tinka vartoti iki',    # valid until
		'data ant pakuotės',    #date on package
		'laikyti sausoje vietoje',    #Keep in dry place
		'',
	],

	lv => [
		'uzglabāt sausā vēsā vietā',    # keep in dry place
		'analītiskā sastāva',    # pet food
	],

	mk => [
		'Да се чува на темно место и на температура до',    # Store in a dark place at a temperature of up to
	],

	nb => ['netto(?:innhold|vekt)', 'oppbevar(?:ing|es)', 'næringsinnh[oa]ld', 'kjølevare',],

	nl => [
		'analytische bestanddelen',    # pet food
		'Beter Leven keurmerk 1 ster.',
		'Beter Leven keurmerk 3 sterren',
		'Bewaren bij kamertemperatuur',
		'Cacao: ten minste ',
		'(koel en )?droog bewaren',
		'E = door EU goedgekeurde hulpstof',
		'E door EU goedgekeurde hulpstoffen',
		'"E"-nummers zijn door de EU goedgekeurde hulpstoffen',
		'gemiddelde voedingswaarden',
		'Gemiddeldevoedingswaardel',
		'gemiddelde voedingswaarde per 100 g',
		'Na openen beperkt houdbaar',
		'Ongeopend, ten minste houdbaar tot:',
		'o.a.',
		'te bewaren op een koele en droge plaats',    # keep in dry place
		'ten minste',
		'ten minste houdbaar tot',
		'Van nature rijk aan vezels',
		'Verpakt onder beschermende atmosfeer',
		'voedingswaarden',
		'voedingswaarde',
		'Voor allergenen: zie ingrediëntenlijst, in vet gemarkeerd',
		'voorbereidingstips',
		#'waarvan suikers',
		'waarvan toegevoegde',
		'Witte chocolade: ten minste',
	],

	pl => [
		'przechowywać w chlodnym i ciemnym miejscu',    #keep in a dry and dark place
		'przechowywać w chłodnym i suchym miejscu',    #keep in a dry place
		'n(a|o)jlepiej spożyć przed',    #Best before
		'Przechowywanie',
		'pakowan(o|y|e) w atmosferze ochronnej',    # Packaged in protective environment
		'składniki analityczne',    # pet food
	],

	pt => [
		'constituintes analíticos',    # pet food
		'conservar em local (seco e )?fresco',
		'conservar em lugar fresco',
		'dos quais a(ç|c)(u|ü)ares',
		'dos quais a(ç|c)(u|ü)cares',
		'embalado',    # Packaging in protective atmosphere.
		'informa(ç|c)(a|ã)o nutricional',
		'modo de prepara(ç|c)(a|ã)o',
		'a consumir de prefer(e|ê)ncia antes do',
		'consumir de prefer(e|ê)ncia antes do',
	],

	ro => [
		'constituenți analitici',    # pet food
		'declaratie nutritional(a|ă)',
		'a si pastra la frigider dup(a|ă) deschidere',
		'a se agita inainte de deschidere',
		'a se păstra la loc uscat şi răcoros',    # Store in a dry and cool place
		'a sè păstra la temperaturi până la',    # Store at temperatures up to
		'Valori nutritionale medii',
		'a se p[ăa]stra la',    # store in...
	],

	rs => [
		'(č|Č|c|C|ć|Ć)uvati na (hladnom|suvom|temperaturi od)',    # Store in a cool and dry place
		'napomena za potrošače',    # note for consumers
		'pakovano',    # packed in a protective atmosphere
		'proizvodi i puni',    # Produced and filled
		'upotrebljivo',    # keep until
		'najbolje (upotrijebiti|upotrebiti) do',    # keep until
	],

	ru => [
		'Аналитические компоненты',    # pet food
		'xранить в сухом',    # store in a dry place
	],

	sk => [
		'analytické zložky',    # pet food
		'skladovanie',    # store at
		'spotrebujte do',    # keep until
	],

	sl => [
		'analitska sestava',    # pet food
		'hraniti',    # Store in a cool and dry place
		'opozorilo',    # warning
		'pakirano v kontrolirani atmosferi',    # packed in a ... atmosphere
		'porabiti',    # keep until
		'predlog za serviranje ',    # serving suggestion
		'prosječne hranjive vrijednosti 100 g proizvoda',    # average nutritional value of 100 g of product
		'uvoznik',    # imported/distributed by
	],

	sv => [
		'analytiska beståndsdelar',    # pet food
		'närings(?:deklaration|innehåll|värde)', '(?:bör )?förvar(?:ing|as?)',
		'till(?:agning|redning)', 'produkten innehåller',
		'serveringsförslag', 'produkterna bör',
		'bruksanvisning', 'källsortering',
		'anvisningar', 'skyddas mot',
		'uppvärmning', 'återvinning',
		'hållbarhet', 'producerad',
		'upptining', 'o?öppnad',
		'bevaras', 'kylvara',
		'tappat',
	],

	tr => [
		'analitik bileşenler',    # pet food
	],

	uk => [
		'Зберігати в сухому',    # store in dry place
		'kраще спожити',    # best before
	],

	vi => ['GI(Á|A) TR(Ị|I) DINH D(Ư|U)(Ỡ|O)NG (TRONG|TRÊN)',],
);

# turn demi - écrémé to demi-écrémé
my %prefixes_before_dash = (fr => ['demi', 'saint',],);

# phrases that can be removed
my %ignore_phrases = (
	de => [
		'\d\d?\s?%\sFett\si(\.|,)\s?Tr(\.|,)?',    # 45 % Fett i.Tr.
		'inklusive',
	],
	en => ['not applicable',],
	fr => ['non applicable|non concerné',],
	hr => [
		'u gotovom proizvodu',    # 5%* ... % u gotovom proizvodu
		'za više informacija posjetiti stranicu ra\.org',
	],
	hu => [
		'Valamennyi százalékos adat a késztermékre vonatkozik',    # All percentages refer to the finished product.
	]

);

=head2 split_generic_name_from_ingredients ( product_ref language_code )

Some producers send us an ingredients list that starts with the generic name followed by the actual ingredients list.

e.g. "Pâtes de fruits aromatisées à la fraise et à la canneberge, contenant de la maltodextrine et de l'acérola. Source de vitamines B1, B6, B12 et C.  Ingrédients : Pulpe de fruits 50% (poire William 25%, fraise 15%, canneberge 10%), sucre, sirop de glucose de blé, maltodextrine 5%, stabilisant : glycérol, gélifiant : pectine, acidifiant : acide citrique, arôme naturel de fraise, arôme naturel de canneberge, poudre d'acérola (acérola, maltodextrine) 0,4%, vitamines : B1, B6 et B12. Fabriqué dans un atelier utilisant: GLUTEN*, FRUITS A COQUE*. * Allergènes"

This function splits the list to put the generic name in the generic_name_[lc] field and the ingredients list
in the ingredients_text_[lc] field.

If there is already a generic name, it is not overridden.

WARNING: This function should be called only during the import of data from producers.
It should not be called on lists that can be the result of an OCR, as there is no guarantee that the text before the ingredients list is the generic name.
It should also not be called when we import product data from the producers platform to the public database.

=cut

sub split_generic_name_from_ingredients ($product_ref, $language) {

	if (    (defined $phrases_before_ingredients_list{$language})
		and (defined $product_ref->{"ingredients_text_$language"}))
	{

		$log->debug("split_generic_name_from_ingredients",
			{language => $language, "ingredients_text_$language" => $product_ref->{"ingredients_text_$language"}})
			if $log->is_debug();

		foreach my $regexp (@{$phrases_before_ingredients_list{$language}}) {
			if ($product_ref->{"ingredients_text_$language"} =~ /(\s*)\b($regexp(\s*)(-|:|\r|\n)+(\s*))/is) {

				my $generic_name = $`;
				$product_ref->{"ingredients_text_$language"} = ucfirst($');

				if (
					($generic_name ne '')
					and (  (not defined $product_ref->{"generic_name_$language"})
						or ($product_ref->{"generic_name_$language"} eq ""))
					)
				{
					$product_ref->{"generic_name_$language"} = $generic_name;
					$log->debug("split_generic_name_from_ingredients",
						{language => $language, generic_name => $generic_name})
						if $log->is_debug();
				}
				last;
			}
		}
	}

	return;
}

=head2 clean_ingredients_text_for_lang ( product_ref language_code )

Perform some cleaning of the ingredients list.

The operations included in the cleaning must be 100% safe.

The function can be applied multiple times on the ingredients list.

=cut

sub clean_ingredients_text_for_lang ($text, $language) {

	$log->debug("clean_ingredients_text_for_lang - start", {language => $language, text => $text}) if $log->is_debug();

	# Remove phrases before ingredients list, but only when they are at the very beginning of the text

	foreach my $regexp (@{$phrases_before_ingredients_list{$language}}) {
		if ($text =~ /^(\s*)\b($regexp(\s*)(-|:|\r|\n)+(\s*))/is) {

			$text = ucfirst($');
		}
	}

	# turn demi - écrémé to demi-écrémé

	if (defined $prefixes_before_dash{$language}) {

		foreach my $prefix (@{$prefixes_before_dash{$language}}) {
			$text =~ s/\b($prefix) - (\w)/$1-$2/is;
		}
	}

	# Non language specific cleaning
	# Try to add missing spaces around dashes - separating ingredients

	# jus d'orange à base de concentré 14%- sucre
	$text =~ s/(\%)- /$1 - /g;

	# persil- poivre blanc -ail
	$text =~ s/(\w|\*)- /$1 - /g;
	$text =~ s/ -(\w)/ - $1/g;

	$text =~ s/^\s*(:|-)\s*//;
	$text =~ s/\s+$//;

	$log->debug("clean_ingredients_text_for_lang - done", {language => $language, text => $text}) if $log->is_debug();

	return $text;
}

=head2 cut_ingredients_text_for_lang ( product_ref language_code )

This function should be called once when getting text data from the OCR that includes an ingredients list.

It tries to remove phrases before and after the list that are not ingredients list.

It MUST NOT be applied multiple times on the ingredients list, as it could otherwise
remove parts of the ingredients list. (e.g. it looks for "Ingredients: " and remove everything before it.
If there are multiple "Ingredients:" listed, it would keep only the last one if called multiple times.

=cut

sub cut_ingredients_text_for_lang ($text, $language) {

	$log->debug("cut_ingredients_text_for_lang - start", {language => $language, text => $text}) if $log->is_debug();

	# Remove phrases before ingredients list lowercase

	$log->debug("cut_ingredients_text_for_lang - 1", {language => $language, text => $text}) if $log->is_debug();

	my $cut = 0;

	if (defined $phrases_before_ingredients_list{$language}) {

		foreach my $regexp (@{$phrases_before_ingredients_list{$language}}) {
			# The match before the regexp must be not greedy so that we don't cut too much
			# if we have multiple times "Ingredients:" (e.g. for products with 2 sub-products)
			if ($text =~ /^(.*?)\b$regexp(\s*)(-|:|\r|\n)+(\s*)/is) {
				$text = ucfirst($');
				$log->debug("removed phrases_before_ingredients_list",
					{removed => $1, kept => $text, regexp => $regexp})
					if $log->is_debug();
				$cut = 1;
				last;
			}
		}
	}

	# Remove phrases before ingredients list UPPERCASE

	$log->debug("cut_ingredients_text_for_lang - 2", {language => $language, text => $text}) if $log->is_debug();

	if ((not $cut) and (defined $phrases_before_ingredients_list_uppercase{$language})) {

		foreach my $regexp (@{$phrases_before_ingredients_list_uppercase{$language}}) {
			# INGREDIENTS followed by lowercase

			if ($text =~ /^(.*?)\b$regexp(\s*)(\s|-|:|\r|\n)+(\s*)(?=(\w?)(\w?)[a-z])/s) {
				$text =~ s/^(.*?)\b$regexp(\s*)(\s|-|:|\r|\n)+(\s*)(?=(\w?)(\w?)[a-z])//s;
				$text = ucfirst($text);
				$log->debug("removed phrases_before_ingredients_list_uppercase", {kept => $text, regexp => $regexp})
					if $log->is_debug();
				$cut = 1;
				last;
			}
		}
	}

	# Remove phrases after ingredients list

	$log->debug("cut_ingredients_text_for_lang - 3", {language => $language, text => $text}) if $log->is_debug();

	if (defined $phrases_after_ingredients_list{$language}) {

		foreach my $regexp (@{$phrases_after_ingredients_list{$language}}) {
			if ($text =~ /\*?\s*\b$regexp\b(.*)$/is) {
				$text = $`;
				$log->debug("removed phrases_after_ingredients_list", {removed => $1, kept => $text, regexp => $regexp})
					if $log->is_debug();
			}
		}
	}

	# Remove phrases

	$log->debug("cut_ingredients_text_for_lang - 4", {language => $language, text => $text}) if $log->is_debug();

	if (defined $ignore_phrases{$language}) {

		foreach my $regexp (@{$ignore_phrases{$language}}) {
			# substract regexp
			$text =~ s/\s*\b(?:$regexp)\s*/ /gi;
			# rm opened-closed parenthesis
			$text =~ s/\(\s?\)//g;
			# rm double commas
			$text =~ s/\s?,\s?,/,/g;
			# rm double spaces
			$text =~ s/\s+/ /g;
			# rm space before comma
			$text =~ s/\s,\s?/, /g;
		}
	}

	$log->debug("cut_ingredients_text_for_lang - 5", {language => $language, text => $text}) if $log->is_debug();

	$text = clean_ingredients_text_for_lang($text, $language);

	$log->debug("cut_ingredients_text_for_lang - done", {language => $language, text => $text}) if $log->is_debug();

	return $text;
}

sub clean_ingredients_text ($product_ref) {
	if (defined $product_ref->{languages_codes}) {

		foreach my $language (keys %{$product_ref->{languages_codes}}) {

			if (defined $product_ref->{"ingredients_text_" . $language}) {

				my $text = $product_ref->{"ingredients_text_" . $language};

				$text = clean_ingredients_text_for_lang($text, $language);

				if ($text ne $product_ref->{"ingredients_text_" . $language}) {

					my $time = time();

					# Keep a copy of the original ingredients list just in case
					$product_ref->{"ingredients_text_" . $language . "_ocr_" . $time}
						= $product_ref->{"ingredients_text_" . $language};
					$product_ref->{"ingredients_text_" . $language . "_ocr_" . $time . "_result"} = $text;
					$product_ref->{"ingredients_text_" . $language} = $text;
				}

				if ($language eq ($product_ref->{ingredients_lc} || $product_ref->{lc})) {
					$product_ref->{"ingredients_text"} = $product_ref->{"ingredients_text_" . $language};
				}
			}
		}
	}

	return;
}

sub is_compound_word_with_dash ($word_lc, $compound_word) {

	if (exists_taxonomy_tag("ingredients", canonicalize_taxonomy_tag($word_lc, "ingredients", $compound_word))) {
		$compound_word =~ s/ - /-/;
		return $compound_word;
	}
	else {
		return $compound_word;
	}
}

# additive class + additive (e.g. "colour caramel" -> "colour : caramel"
# warning: the additive class may also be the start of the name of an additive.
# e.g. "regulatory kwasowości: kwas cytrynowy i cytryniany sodu." -> "kwas" means acid / acidifier.
sub separate_additive_class ($ingredients_lc, $additive_class, $spaces, $colon, $after) {

	my $and = $and{$ingredients_lc} || " and ";

	# check that we have an additive after the additive class
	# keep only what is before the first separator
	$after =~ s/^$separators+//;
	#print STDERR "separate_additive_class - after 1 : $after\n";
	$after =~ s/^(.*?)$separators(.*)$/$1/;
	#print STDERR "separate_additive_class - after 2 : $after\n";

	# also look if we have additive 1 and additive 2
	my ($after1, $after2);
	if ($after =~ /$and/i) {
		$after1 = $`;
		$after2 = $`;
	}

	# also check that we are not separating an actual ingredient
	# e.g. acide acétique -> acide : acétique

	if (
		(
			not(
				exists_taxonomy_tag("ingredients",
					canonicalize_taxonomy_tag($ingredients_lc, "ingredients", $additive_class . " " . $after))
				or (
					(defined $after1)
					and exists_taxonomy_tag(
						"ingredients",
						canonicalize_taxonomy_tag($ingredients_lc, "ingredients", $additive_class . " " . $after1)
					)
				)
			)
		)
		and (
			# we use the ingredients taxonomy here as some additives like "soy lecithin" are currently in the ingredients taxonomy
			# but not in the additives taxonomy
			exists_taxonomy_tag("ingredients", canonicalize_taxonomy_tag($ingredients_lc, "ingredients", $after))
			or ((defined $after2)
				and
				exists_taxonomy_tag("ingredients", canonicalize_taxonomy_tag($ingredients_lc, "ingredients", $after2)))
		)
		)
	{
		#print STDERR "separate_additive_class - after is an additive\n";
		return $additive_class . " : ";
	}
	else {
		#print STDERR "separate_additive_class - after is not an additive\n";
		return $additive_class . $spaces . $colon;
	}
}

=head2 replace_additive ($number, $letter, $variant) - normalize the additive

This function is used inside regular expressions to turn additives to a normalized form.

Using a function to concatenate the E-number, letter and variant makes it possible 
to deal with undefined $letter or $variant without triggering an undefined warning.

=head3 Synopsis

	$text =~ s/(\b)e( |-|\.)?$additivesregexp(\b|\s|,|\.|;|\/|-|\\|$)/replace_additive($3,$6,$9) . $12/ieg;

=cut

sub replace_additive ($number, $letter, $variant) {

	# $number  ->  e.g. 160
	# $letter  ->  e.g. a
	# $variant ->  e.g. ii

	my $additive = "e" . $number;
	if (defined $letter) {
		$additive .= $letter;
	}
	if (defined $variant) {
		$variant =~ s/^\(//;
		$variant =~ s/\)$//;
		$additive .= $variant;
	}
	return $additive;
}

=head2 develop_ingredients_categories_and_types ( $ingredients_lc, $text ) - turn "oil (sunflower, olive and palm)" into "sunflower oil, olive oil, palm oil"

Some ingredients are specified by an ingredient "category" (e.g. "oil", "flavouring") and a "type" (e.g. "sunflower", "palm" or "strawberry", "vanilla").

Sometimes, the category is mentioned only once for several types:
"strawberry and vanilla flavourings", "vegetable oil (palm, sunflower)".

This function lists each individual ingredient: 
"oil (sunflower, olive and palm)" becomes "sunflower oil, olive oil, palm oil"

=head3 Arguments

=head4 Language

=head4 Ingredients list text

=head3 Return value

=head4 Transformed ingredients list text

=cut

=head3 %ingredients_categories_and_types

For each language, we list the categories and types of ingredients that can be combined when the ingredient list
contains something like "<category> (<type1>, <type2> and <type3>)"

We can also provide a list of alternate_names, so that we can have a category like "oils and fats" and generate
entries like "sunflower oil", "cocoa fat" when the ingredients list contains "oils and fats (sunflower, cocoa)".

Alternate names need to contain "<type>" which will be replaced by the type.

This can be especially useful in languages like German where we can create compound words with the type and the category*
like "Kokosnussöl" or "Sonnenblumenfett":

	de => [
		{
			categories => ["pflanzliches Fett", "pflanzliche Öle", "pflanzliche Öle und Fette", "Fett", "Öle"],
			types => ["Avocado", "Baumwolle", "Distel", "Kokosnuss", "Palm", "Palmkern", "Raps", "Shea", "Sonnenblumen",],
			# Kokosnussöl, Sonnenblumenfett
			alternate_names => ["<type>fett", "<type>öl"],
		},
	],

Simple plural (just an additional "s" at the end) will be added in the regexp.

Note that a "<categories> ([list of types])" enumeration will be developed only if all the types can be matched
to the specified types in ingredients_categories_and_types.

=cut

my %ingredients_categories_and_types = (

	en => [
		# flavours
		{
			# categories
			categories => ["flavouring",],
			# types
			types => ["natural", "nature identical",],
		},
		# oils
		{
			# categories
			categories => ["oil", "vegetable oil", "vegetal oil",],
			# types
			types =>
				["avocado", "coconut", "colza", "cottonseed", "olive", "palm", "rapeseed", "safflower", "sunflower",],
		},
	],

	de => [
		# oil and fat
		{
			categories => ["pflanzliches Fett", "pflanzliche Öle", "pflanzliche Öle und Fette", "Fett", "Öle"],
			types =>
				["Avocado", "Baumwolle", "Distel", "Kokosnuss", "Palm", "Palmkern", "Raps", "Shea", "Sonnenblumen",],
			# Kokosnussöl, Sonnenblumenfett
			alternate_names => ["<type>fett", "<type>öl"],
		},
		# plant protein
		{
			categories => ["pflanzliche Proteine", "Pflanzliches Eiweiß", "Pflanzliches Eiweiss"],
			types => [
				"Ackerbohnen", "Erbsen", "Hafer", "Kartoffel", "Kichererbsen", "Pilz",
				"Reis", "Soja", "Sonnenblumen", "Weizen"
			],
			# haferprotein
			alternate_names => ["<type>protein", "<type>eiweiß"],
		},
	],

	es => [
		# oils
		{
			categories => ["aceite", "aceite vegetal", "aceites vegetales"],
			types =>
				["aguacate", "coco", "colza", "girasol", "linaza", "nabina", "oliva", "palma", "palmiste", "soja",],
			alternate_names => ["aceite de <type>", "aceite d'<type>"],
		},
	],

	fr => [
		# huiles
		{
			categories => [
				# allow multiple types of oils in the category (e.g. "huiles et graisses"), with modifiers (e.g. "végétale")
				'(?:(?: et )?(?:huile|graisse|stéarine|matière\s? grasse)s?)+(?: (?:végétale|(?:partiellement |totalement |non(?:-| |))hydrogénée?)s?)*',
			],
			types => [
				"arachide", "avocat", "carthame", "chanvre",
				"coco", "colza", "coprah", "coton",
				"graines de colza", "illipe", "karité", "lin",
				"mangue", "noisette", "noix", "noyaux de mangue",
				"olive", "olive extra", "olive vierge", "olive extra vierge",
				"olive vierge extra", "palme", "palmiste", "pépins de raisin",
				"sal", "sésame", "soja", "tournesol",
				"tournesol oléique",
			],
			alternate_names => [
				"huile de <type>",
				"huile d'<type>",
				"matière grasse de <type>",
				"graisse de <type>",
				"stéarine de <type>"
			],
		},
		# (natural) extract
		{
			categories => ["extrait", "extrait naturel",],
			types => [
				"café", "chicorée", "curcuma", "houblon", "levure", "malt",
				"muscade", "poivre", "poivre noir", "romarin", "thé", "thé vert",
				"thym",
			]
		},
		# plant protein
		{
			categories => ["protéines végétales",],
			types => [
				"avoine", "blé", "champignon", "colza", "fève", "pois",
				"pois chiche", "pomme de terre", "riz", "soja", "tournesol",
			],
			alternate_names => ["protéine de <type>", "protéine d'<type>", "protéines de <type>", "protéines d'<type>"],
		},
		# lecithin
		{
			categories => ["lécithine",],
			types => ["colza", "soja", "soja sans ogm", "tournesol",]
		},
		# natural flavouring
		{
			categories => [
				"arôme naturel",
				"arômes naturels",
				"arôme artificiel",
				"arômes artificiels",
				"arômes naturels et artificiels", "arômes",
			],
			types => [
				"abricot", "ail", "amande", "amande amère",
				"agrumes", "aneth", "boeuf", "cacao",
				"cannelle", "caramel", "carotte", "carthame",
				"cassis", "céleri", "cerise", "curcuma",
				"cumin", "citron", "citron vert", "crustacés",
				"estragon", "fenouil", "figue", "fraise",
				"framboise", "fromage de chèvre", "fruit", "fruit de la passion",
				"fruits de la passion", "fruits de mer", "fumée", "gentiane",
				"herbes", "jasmin", "laurier", "lime",
				"limette", "mangue", "menthe", "menthe crêpue",
				"menthe poivrée", "muscade", "noix", "noix de coco",
				"oignon", "olive", "orange", "orange amère",
				"origan", "pamplemousse", "pamplemousse rose", "pêche",
				"piment", "pistache", "porc", "pomme",
				"poire", "poivre", "poisson", "poulet",
				"réglisse", "romarin", "rose", "rhum",
				"sauge", "saumon", "sureau", "thé",
				"thym", "vanille", "vanille de Madagascar", "autres agrumes",
			]
		},
		# chemical substances
		{
			categories => [
				"carbonate", "carbonates acides", "chlorure", "citrate",
				"iodure", "nitrate", "diphosphate", "diphosphate",
				"phosphate", "sélénite", "sulfate", "hydroxyde",
				"sulphate",
			],
			types => [
				"aluminium", "ammonium", "calcium", "cuivre", "fer", "magnésium",
				"manganèse", "potassium", "sodium", "zinc",
			],
			# avoid turning "carbonates d'ammonium et de sodium" into "carbonates (carbonates d'ammonium, carbonates de sodium)"
			# as "carbonates" is an additive
			do_not_output_parent => 1,
		},
		# peppers
		{categories => ["piment", "poivron"], types => ["vert", "jaune", "rouge",], of_bool => 0,},
	],

	lt => [
		#oils
		{
			categories => ["aliejai", "augaliniai aliejai",],
			types => ["palmių", "rapsų", "saulėgrąžų",],
		},
	],

	hr => [
		# cheeses
		{
			categories => ["sirevi",],
			types => ["polutvrdi", "meki",]
		},
		# coffees
		{
			categories => ["kave",],
			types => ["arabica", "robusta",]
		},
		# concentrated (juice)
		{
			categories =>
				["koncentrat soka", "koncentrati", "koncentrirane kaše", "koncentrirani sok od", "ugośćeni sok",],
			types => [
				"banana", "biljni", "breskva", "cikle", "crne mrkve", "crnog korijena",
				"guava", "hibiskusa", "jabuka", "limuna", "mango", "naranče",
				"voćni",
			]
		},
		# flavouring
		{
			categories => ["prirodna aroma", "prirodne arome",],
			types => ["citrusa sa ostalim prirodnim aromama", "limuna", "mente", "mente s drugim prirodnim aromama",]
		},
		# flours
		{
			categories => ["brašno",],
			types => ["pšenično bijelo tip 550", "pšenično polubijelo tip 850", "pšenično",]
		},
		# leaves
		{
			categories => ["list",],
			types => ["gunpowder", "Camellia sinensis", "folium",]
		},
		# malts
		{
			categories => ["slad",],
			types => ["ječmeni", "pšenični",]
		},
		# meats
		{
			categories => ["meso",],
			types => ["svinjsko", "goveđe",]
		},
		# milk
		{
			categories => ["mlijeko",],
			types => ["s 1.0% mliječne masti",]
		},
		# oils and fats
		{
			categories => ["biljna mast", "biljna ulja", "biljne masti", "ulja",],
			types => [
				"koskos", "kukuruzno u različitim omjerima",
				"palma", "palmina", "palmine", "repičina", "repičino", "sojino", "suncokretovo",
			]
		},
		# seeds
		{
			categories => ["sjemenke",],
			types => ["lan", "suncokret",]
		},
		# starchs
		{
			categories => ["škrob",],
			types => ["kukuruzni", "krumpirov",]
		}
	],

	pl => [
		# oils and fats
		{
			categories => [
				"olej",
				"olej roślinny",
				"oleje",
				"oleje roślinne",
				"tłuszcze",
				"tłuszcze roślinne",
				"tłuszcz roślinny",
			],
			types => [
				"rzepakowy", "z oliwek", "palmowy", "słonecznikowy",
				"kokosowy", "sojowy", "shea", "palmowy utwardzony",
				"palmowy nieutwardzony",
			],
		},
		# concentrates
		{
			categories => [
				"koncentraty",
				"koncentraty roślinne",
				"soki z zagęszczonych soków z",
				"soki owocowe", "przeciery", "przeciery z", "soki owocowe z zagęszczonych soków owocowych",
			],
			types => [
				"jabłek", "pomarańczy", "marchwi", "bananów", "brzoskwiń", "gujawy",
				"papai", "ananasów", "mango", "marakui", "liczi", "kiwi",
				"limonek", "jabłkowy", "marchwiowy", "bananowy", "pomarańczowy"
			],
		},
		# flours
		{
			categories => ["mąki", "mąka"],
			types => [
				"pszenna", "kukurydziana", "ryżowa", "pszenna pełnoziarnista",
				"orkiszowa", "żytnia", "jęczmienna", "owsiana",
				"jaglana", "gryczana",
			],
		},
		#meat
		{
			categories => ["mięso", "mięsa"],
			types => ["wieprzowe", "wołowe", "drobiowe", "z kurczaka", "z indyka", "cielęce"],
		},
	],

	ru => [
		# oils
		{
			categories => ['масло(?: растительное)?',],
			types => [
				"Подсолнечное", "Пальмовое", "Рапсовое", "Кокосовое", "горчицы", "Соевое",
				"Пальмоядровое", "Оливковое", "пальм",
			],
		},
	],

);

sub develop_ingredients_categories_and_types ($ingredients_lc, $text) {
	$log->debug("develop_ingredients_categories_and_types", {ingredients_lc => $ingredients_lc, text => $text})
		if $log->is_debug();

	if (defined $ingredients_categories_and_types{$ingredients_lc}) {

		my $percent_or_quantity_regexp = $percent_or_quantity_regexps{$ingredients_lc};
		# Make the 2 capture groups (for number and for % or unit, starting with (\d and (\% non capturing
		$percent_or_quantity_regexp =~ s/\(\\/\(?:\\/g;

		foreach my $categories_and_types_ref (@{$ingredients_categories_and_types{$ingredients_lc}}) {
			my $category_regexp = "";
			foreach my $category (@{$categories_and_types_ref->{categories}}) {
				$category_regexp .= '|' . $category . '|' . $category . 's';
				my $unaccented_category = unac_string_perl($category);
				if ($unaccented_category ne $category) {
					$category_regexp .= '|' . $unaccented_category . '|' . $unaccented_category . 's';
				}
			}
			$category_regexp =~ s/^\|//;

			if ($ingredients_lc eq "en") {
				$category_regexp = '(?:organic |fair trade )*(?:' . $category_regexp . ')(?:' . $symbols_regexp . ')*';
			}
			elsif ($ingredients_lc eq "fr") {
				$category_regexp
					= '(?:' . $category_regexp . ')(?: bio| biologique| équitable|s|\s|' . $symbols_regexp . ')*';
			}
			else {
				$category_regexp = '(?:' . $category_regexp . ')(?:' . $symbols_regexp . ')*';
			}

			# Also match % after the category (e.g. "vegetal oil 45% (palm, rapeseed)"
			$category_regexp .= '\s*(?:' . $percent_or_quantity_regexp . ')?';

			my $type_regexp = "";
			foreach my $type (@{$categories_and_types_ref->{types}}) {
				$type_regexp .= '|' . $type . '|' . $type . 's';
				my $unaccented_type = unac_string_perl($type);
				if ($unaccented_type ne $type) {
					$type_regexp .= '|' . $unaccented_type . '|' . $unaccented_type . 's';
				}
			}
			$type_regexp =~ s/^\|//;

			#$log->debug("develop_ingredients_categories_and_types", { category_regexp => $category_regexp, type_regexp => $type_regexp}) if $log->is_debug();

			my $of_bool = 1;
			if (defined $categories_and_types_ref->{of_bool}) {
				$of_bool = $categories_and_types_ref->{of_bool};
			}

			# arôme naturel de citron-citron vert et d'autres agrumes
			# -> separate types
			$text =~ s/($type_regexp)-($type_regexp)/$1, $2/ig;

			my $and = ' - ';
			if (defined $and{$ingredients_lc}) {
				$and = $and{$ingredients_lc};
			}
			my $of = ' - ';
			if (defined $of{$ingredients_lc}) {
				$of = $of{$ingredients_lc};
			}
			my $and_of = ' - ';
			if (defined $and_of{$ingredients_lc}) {
				$and_of = $and_of{$ingredients_lc};
			}
			my $and_or = ' - ';
			if (defined $and_or{$ingredients_lc}) {
				$and_or = $and_or{$ingredients_lc};
			}

			if (   ($ingredients_lc eq "en")
				or ($ingredients_lc eq "de")
				or ($ingredients_lc eq "hr")
				or ($ingredients_lc eq "ru")
				or ($ingredients_lc eq "pl"))
			{
				# vegetable oil (palm, sunflower and olive) -> palm vegetable oil, sunflower vegetable oil, olive vegetable oil
				# nNte: not using the /x modifier to put spaces in the regexp, as it doesn't work if the interpolated variables contain spaces themselves...
				$text
					=~ s/($category_regexp)(?::|\(|\[| | $of )+((($type_regexp)($symbols_regexp|\s)*(\s|\/|\s\/\s|\s-\s|,|,\s|$and|$of|$and_of|$and_or)+)+($type_regexp)($symbols_regexp|\s)*)\b(\s?(\)|\]))?/normalize_enumeration($ingredients_lc,$1,$2,$of_bool, $categories_and_types_ref->{alternate_names},$categories_and_types_ref->{do_not_output_parent})/ieg;

				# vegetable oil (palm) -> palm vegetable oil
				$text
					=~ s/($category_regexp)\s?(?:\(|\[)\s?($type_regexp)\b(\s?(\)|\]))/normalize_enumeration($ingredients_lc,$1,$2,$of_bool,$categories_and_types_ref->{alternate_names},$categories_and_types_ref->{do_not_output_parent})/ieg;
				# vegetable oil: palm
				$text
					=~ s/($category_regexp)\s?(?::)\s?($type_regexp)(?=$separators|.|$)/normalize_enumeration($ingredients_lc,$1,$2,$of_bool,$categories_and_types_ref->{alternate_names},$categories_and_types_ref->{do_not_output_parent})/ieg;

				# ječmeni i pšenični slad (barley and wheat malt) -> ječmeni slad, pšenični slad
				$text
					=~ s/((?:(?:$type_regexp)(?: |\/| \/ | - |,|, |$and|$of|$and_of|$and_or)+)+(?:$type_regexp))\s*($category_regexp)/normalize_enumeration($ingredients_lc,$2,$1,$of_bool,$categories_and_types_ref->{alternate_names},$categories_and_types_ref->{do_not_output_parent})/ieg;
			}
			elsif ($ingredients_lc eq "fr") {
				# arôme naturel de pomme avec d'autres âromes
				$text =~ s/ (ou|et|avec) (d')?autres / et /g;

				$text
					=~ s/($category_regexp) et ($category_regexp)(?:$of)?($type_regexp)/normalize_fr_a_et_b_de_c($1, $2, $3)/ieg;

				# Carbonate de magnésium, fer élémentaire -> should not trigger carbonate de fer élémentaire. Bug #3838
				# TODO 18/07/2020 remove when we have a better solution
				$text =~ s/fer (é|e)l(é|e)mentaire/fer_élémentaire/ig;

				# $text =~ s/($category_regexp)(?::|\(|\[| | de | d')+((($type_regexp)($symbols_regexp|\s)*( |\/| \/ | - |,|, | et | de | et de | et d'| d')+)+($type_regexp)($symbols_regexp|\s)*)\b(\s?(\)|\]))?/normalize_enumeration($ingredients_lc,$1,$2,$of_bool, $categories_and_types_ref->{alternate_names})/ieg;
				# Huiles végétales de palme, de colza et de tournesol
				# warning: Nutella has "huile de palme, noisettes" -> we do not want "huiles de palme, huile de noisettes"
				# require a " et " and/or " de " at the end of the enumeration
				#
				$text
					=~ s/($category_regexp)(?::| | de | d')+((($type_regexp)($symbols_regexp|\s)*( |\/| \/ | - |,|, | et | de | et de | et d'| d')+)*($type_regexp)($symbols_regexp|\s)*( |\/| \/ | - |,|, )*( et | de | et de | et d'| d'| d'autres | et d'autres )( |\/| \/ | - |,|, )*($type_regexp)($symbols_regexp|\s)*)\b/normalize_enumeration($ingredients_lc,$1,$2,$of_bool, $categories_and_types_ref->{alternate_names},$categories_and_types_ref->{do_not_output_parent})/ieg;

				# Huiles végétales (palme, colza et tournesol)
				$text
					=~ s/($category_regexp)(?:\(|\[)(?:de |d')?((($type_regexp)($symbols_regexp|\s)*( |\/| \/ | - |,|, | et | de | et de | et d'| d')+)+($type_regexp)($symbols_regexp|\s)*)\b(\s?(\)|\]))/normalize_enumeration($ingredients_lc,$1,$2,$of_bool, $categories_and_types_ref->{alternate_names},$categories_and_types_ref->{do_not_output_parent})/ieg;

				$text =~ s/fer_élémentaire/fer élémentaire/ig;

				# huile végétale (colza)
				$text
					=~ s/($category_regexp)\s?(?:\(|\[)\s?($type_regexp)\b(\s?(\)|\]))/normalize_enumeration($ingredients_lc,$1,$2,$of_bool, $categories_and_types_ref->{alternate_names}, $categories_and_types_ref->{do_not_output_parent})/ieg;
				# huile végétale : colza,
				$text
					=~ s/($category_regexp)\s?(?::)\s?($type_regexp)(?=$separators|.|$)/normalize_enumeration($ingredients_lc,$1,$2,$of_bool, $categories_and_types_ref->{alternate_names}, $categories_and_types_ref->{do_not_output_parent})/ieg;
			}
		}

		# Some additives have "et" in their name: need to recombine them

		if ($ingredients_lc eq "fr") {

			# Sels de sodium et de potassium de complexes cupriques de chlorophyllines,

			my $info = <<INFO
Complexe cuivrique des chlorophyllines avec sels de sodium et de potassium,
oxyde et hydroxyde de fer rouge,
oxyde et hydroxyde de fer jaune et rouge,
Tartrate double de sodium et de potassium,
Éthylènediaminetétraacétate de calcium et de disodium,
Phosphate d'aluminium et de sodium,
Diphosphate de potassium et de sodium,
Tripoliphosphates de sodium et de potassium,
Sels de sodium de potassium et de calcium d'acides gras,
Mono- et diglycérides d'acides gras,
Esters acétiques des mono- et diglycérides,
Esters glycéroliques de l'acide acétique et d'acides gras,
Esters glycéroliques de l'acide citrique et d'acides gras,
Esters monoacétyltartriques et diacétyltartriques,
Esters mixtes acétiques et tartriques des mono- et diglycérides d'acides gras,
Esters lactyles d'acides gras du glycérol et du propane-1,
Silicate double d'aluminium et de calcium,
Silicate d'aluminium et calcium,
Silicate d'aluminium et de calcium,
Silicate double de calcium et d'aluminium,
Glycine et son sel de sodium,
Cire d'abeille blanche et jaune,
Acide cyclamique et ses sels,
Saccharine et ses sels,
Acide glycyrrhizique et sels,
Sels et esters de choline,
Octénylesuccinate d'amidon et d'aluminium,
INFO
				;

			# Phosphate d'aluminium et de sodium --> E541. Should not be split.

			$text
				=~ s/(di|tri|tripoli|)(phosphate|phosphates) d'aluminium,\s?(di|tri|tripoli)?(phosphate|phosphates) de sodium/$1phosphate d'aluminium et de sodium/ig;

			# Sels de sodium et de potassium de complexes cupriques de chlorophyllines -> should not be split...
			$text =~ s/(sel|sels) de sodium,\s?(sel|sels) de potassium/sels de sodium et de potassium/ig;
		}
	}

	return $text;
}

=head2 preparse_ingredients_text ($ingredients_lc, $text) - normalize the ingredient list to make parsing easier

This function transform the ingredients list in a more normalized list that is easier to parse.

It does the following:

- Normalize quote characters
- Replace abbreviations by their full name
- Remove extra spaces in compound words width dashes (e.g. céléri - rave -> céléri-rave)
- Split vitamins enumerations
- Normalize additives and split additives enumerations
- Split other enumerations (e.g. oils, some minerals)
- Split allergens and traces
- Deal with signs like * to indicate labels (e.g. *: Organic)

=head3 Arguments

=head4 Language

=head4 Ingredients list text

=head3 Return value

=head4 Transformed ingredients list text

=cut

sub preparse_ingredients_text ($ingredients_lc, $text) {

	not defined $text and return;

	$log->debug("preparse_ingredients_text", {text => $text}) if $log->is_debug();

	# if we're called twice with the same input in succession, such as in update_all_products.pl,
	# cache the result, so we can instantly return the 2nd time.
	state $prev_lc = '';
	state $prev_text = '';
	state $prev_return = '';

	if (($ingredients_lc eq $prev_lc) && ($text eq $prev_text)) {
		return $prev_return;
	}

	$prev_lc = $ingredients_lc;
	$prev_text = $text;

	if ((scalar keys %labels_regexps) == 0) {
		init_labels_regexps();
		init_ingredients_processing_regexps();
		init_additives_classes_regexps();
		init_allergens_regexps();
		init_origins_regexps();
	}

	init_percent_or_quantity_regexps($ingredients_lc);

	my $and = $and{$ingredients_lc} || " and ";
	my $and_without_spaces = $and;
	$and_without_spaces =~ s/^ //;
	$and_without_spaces =~ s/ $//;

	my $of = ' - ';
	if (defined $of{$ingredients_lc}) {
		$of = $of{$ingredients_lc};
	}

	my $and_of = ' - ';
	if (defined $and_of{$ingredients_lc}) {
		$and_of = $and_of{$ingredients_lc};
	}

	# Spanish "and" is y or e when before "i" or "hi"
	# E can also be in a vitamin enumeration (vitamina B y E)
	# colores E (120, 124 y 125)
	# color E 120

	# replace "and / or" by "and"
	# except if followed by a separator, a digit, or "and", to avoid false positives
	my $and_or = ' - ';
	if (defined $and_or{$ingredients_lc}) {
		$and_or = $and_or{$ingredients_lc};
		$text =~ s/($and_or)(?!($and_without_spaces |\d|$separators))/$and/ig;
	}

	$text =~ s/\&quot;/"/g;
	$text =~ s/\&lt;/</g;
	$text =~ s/\&gt;/>/g;
	$text =~ s/\&apos;/'/g;
	$text =~ s/’/'/g;

	# turn special chars to spaces
	$text =~ s/[\000-\037]/ /g;

	# zero width space
	$text =~ s/\x{200B}/-/g;

	# vegetable oil (coconut & rapeseed)
	# turn & to and
	$text =~ s/ \& /$and/g;

	# number + gr / grams -> g
	$text =~ s/(\d\s*)(gr|gram|grams)\b/$1g/ig;
	if ($ingredients_lc eq 'fr') {
		$text =~ s/(\d\s*)(gramme|grammes)\b/$1g/ig;
	}

	# Farine de blé 56 g* ; beurre concentré 25 g* (soit 30 g* en beurre reconstitué); sucre 22 g* ; œufs frais 2 g
	# 56 g -> 56%
	$text =~ s/(\d| )g(\*)/$1g/ig;

	# transform 0,2% into 0.2%
	$text =~ s/(\d),(\d+)( )?(\%|g\b)/$1.$2\%/ig;
	$text =~ s/—/-/g;
	# transform 0,1-0.2% into 0.1-0.2%
	$text =~ s/(\d),(\d+( )?-( )?\d)/$1.$2/ig;

	# abbreviations, replace language specific abbreviations first
	foreach my $abbreviations_lc ($ingredients_lc, "all") {
		if (defined $abbreviations{$abbreviations_lc}) {
			foreach my $abbreviation_ref (@{$abbreviations{$abbreviations_lc}}) {
				my $source = $abbreviation_ref->[0];
				my $target = $abbreviation_ref->[1];
				$source =~ s/\. /(\\.| |\\. )/g;
				if ($source =~ /\.$/) {
					$source =~ s/\.$/(\\. | |\\.)/;
					$target .= " ";
				}
				$text =~ s/(\b|^)$source(?= |\b|$)/$target/ig;
			}
		}
	}

	# remove extra spaces in compound words width dashes
	# e.g. céleri - rave -> céleri-rave

	# céleri - rave 3.9% -> stop at numbers
	$text
		=~ s/((^|$separators)([^,;\-\/\.0-9]+?) - ([^,;\-\/\.0-9]+?)(?=[0-9]|$separators|$))/is_compound_word_with_dash($ingredients_lc,$1)/ieg;

	# vitamins...
	# vitamines A, B1, B2, B5, B6, B9, B12, C, D, H, PP et E (lactose, protéines de lait)

	my $split_vitamins = sub ($vitamin, $list) {

		my $return = '';
		foreach my $vitamin_code (split(/(\W|\s|-|n|;|et|and)+/, $list)) {
			next if $vitamin_code =~ /^(\W|\s|-|n|;|et|and)*$/;
			$return .= $vitamin . " " . $vitamin_code . " - ";
		}
		return $return;
	};

	# vitamin code: 1 or 2 letters followed by 1 or 2 numbers (e.g. PP, B6, B12)
	# $text =~ s/(vitamin|vitamine)(s?)(((\W+)((and|et) )?(\w(\w)?(\d+)?)\b)+)/$split_vitamins->($1,$3)/eig;

	# 2018-03-07 : commenting out the code above as we are now separating vitamins from additives,
	# and PP, B6, B12 etc. will be listed as synonyms for Vitamine PP, Vitamin B6, Vitamin B12 etc.
	# we will need to be careful that we don't match a single letter K, E etc. that is not a vitamin, and if it happens, check for a "vitamin" prefix

	# colorants alimentaires E (124,122,133,104,110)
	my $roman_numerals = "i|ii|iii|iv|v|vi|vii|viii|ix|x|xi|xii|xii|xiv|xv";
	my $additivesregexp;
	# special cases, when $and (" a ", " e " or " i ") conflict with variants (E470a, E472e or E451i or E451(i))
	# in these cases, we fetch variant only if there is no space before
	# E470a	 -> ok, E470 a -> not ok, E470 a, -> ok
	# E451i -> ok, E451 i -> not ok, E451 i, -> ok
	if ($and eq " a " || $and eq " e ") {
		# based on $additivesregexp below in the else, with following modifications
		# no space before abcdefgh
		$additivesregexp
			= '(\d{3}|\d{4})((-|\.)?([abcdefgh]))?(( |,|.)?((' . $roman_numerals . ')|\((' . $roman_numerals . ')\)))?';
	}
	elsif ($and eq " i ") {
		# based on $additivesregexp below in the else, with following modifications
		# no space before i
		$additivesregexp
			= '(\d{3}|\d{4})(( |-|\.)?([abcdefgh]))?((-|\.)?(('
			. $roman_numerals . ')|\(('
			. $roman_numerals
			. ')\)))?';
	}
	else {
		$additivesregexp
			= '(\d{3}|\d{4})(( |-|\.)?([abcdefgh]))?(( |-|\.)?(('
			. $roman_numerals . ')|\(('
			. $roman_numerals
			. ')\)))?';
	}

	$text
		=~ s/\b(e|ins|sin|i-n-s|s-i-n|i\.n\.s\.?|s\.i\.n\.?)(:|\(|\[| | n| nb|#|°)+((($additivesregexp)( |\/| \/ | - |,|, |$and))+($additivesregexp))\b(\s?(\)|\]))?/normalize_additives_enumeration($ingredients_lc,$3)/ieg;

	# in India: INS 240 instead of E 240, bug #1133)
	# also INS N°420, bug #3618
	# Russian е (!= e), https://github.com/openfoodfacts/openfoodfacts-server/issues/4931
	$text =~ s/\b(е|ins|sin|i-n-s|s-i-n|i\.n\.s\.?|s\.i\.n\.?)( |-| n| nb|#|°|'|"|\.|\W)*(\d{3}|\d{4})/E$3/ig;

	# E 240, E.240, E-240..
	# E250-E251-E260
	$text =~ s/-e( |-|\.)?($additivesregexp)/- E$2/ig;
	# do not turn E172-i into E172 - i
	$text =~ s/e( |-|\.)?($additivesregexp)-(e)/E$2 - E/ig;

	# Canonicalize additives to remove the dash that can make further parsing break
	# Match E + number + letter a to h + i to xv, followed by a space or separator
	# $3 would be either \d{3} or \d{4} in $additivesregexp
	# $6 would be ([abcdefgh]) in $additivesregexp
	# $9 would be (( |-|\.)?((' . $roman_numerals . ')|\((' . $roman_numerals . ')\))) in $additivesregexp
	# $12 would be (\b|\s|,|\.|;|\/|-|\\|\)|\]|$)
	$text =~ s/(\b)e( |-|\.)?$additivesregexp(\b|\s|,|\.|;|\/|-|\\|\)|\]|$)/replace_additive($3,$6,$9) . $12/ieg;

	# E100 et E120 -> E100, E120
	$text =~ s/\be($additivesregexp)$and/e$1, /ig;
	$text =~ s/${and}e($additivesregexp)/, e$1/ig;

	# E100 E122 -> E100, E122
	$text =~ s/\be($additivesregexp)\s+e(?=\d)/e$1, e/ig;

	# ! caramel E150d -> caramel - E150d -> e150a - e150d ...
	$text =~ s/(caramel|caramels)(\W*)e150/e150/ig;

	# stabilisant e420 (sans : ) -> stabilisant : e420
	# but not acidifier (pectin) : acidifier : (pectin)

	# additive class + additive (e.g. "colour caramel" -> "colour : caramel"
	# warning: the additive class may also be the start of the name of an additive.
	# e.g. "regulatory kwasowości: kwas cytrynowy i cytryniany sodu." -> "kwas" means acid / acidifier.
	if (defined $additives_classes_regexps{$ingredients_lc}) {
		my $regexp = $additives_classes_regexps{$ingredients_lc};
		# negative look ahead so that the additive class is not preceded by other words
		# e.g. "de l'acide" should not match "acide"
		$text =~ s/(?<!\w( |'))\b($regexp)(\s+)(:?)(?!\(| \()/separate_additive_class($ingredients_lc,$2,$3,$4,$')/ieg;
	}

	# dash with 1 missing space
	$text =~ s/(\w)- /$1 - /ig;
	$text =~ s/ -(\w)/ - $1/ig;

	# mono-glycéride -> monoglycérides
	$text =~ s/\b(mono|di)\s?-\s?([a-z])/$1$2/ig;
	$text =~ s/\bmono\s-\s/mono- /ig;
	$text =~ s/\bmono\s/mono- /ig;
	#  émulsifiant mono-et diglycérides d'acides gras
	$text =~ s/(mono$and_without_spaces )/mono- $and_without_spaces /ig;

	# acide gras -> acides gras
	$text =~ s/acide gras/acides gras/ig;
	$text =~ s/glycéride /glycérides /ig;

	# !! mono et diglycérides ne doit pas donner mono + diglycérides : keep the whole version too.
	# $text =~ s/(,|;|:|\)|\(|( - ))(.+?)( et )(.+?)(,|;|:|\)|\(|( - ))/$1$3_et_$5$6 , $1$3 et $5$6/ig;

	# e432 et lécithines -> e432 - et lécithines
	$text =~ s/ - et / - /ig;

	# print STDERR "additives: $text\n\n";

	#$product_ref->{ingredients_text_debug} = $text;

	# separator followed by and
	# aceite de girasol (70%) y aceite de oliva virgen (30%)
	$text =~ s/($cbrackets)$and/$1, /ig;

	$log->debug("preparse_ingredients_text - before language specific preparsing", {text => $text}) if $log->is_debug();

	if ($ingredients_lc eq 'de') {
		# deletes comma in "Bienenwachs, weiß und gelb" since it is just one ingredient
		$text =~ s/Bienenwachs, weiß und gelb/Bienenwachs weiß und gelb/ig;
		# deletes brackets in "Bienenwachs, weiß und gelb" since it is just one ingredient
		$text =~ s/Bienenwachs \(weiß und gelb\)/Bienenwachs weiß und gelb/ig;
	}
	elsif ($ingredients_lc eq 'es') {

		# Special handling for sal as it can mean salt or shorea robusta
		# aceites vegetales (palma, shea, sal (shorea robusta), hueso de mango)
		$text =~ s/\bsal \(shorea robusta\)/shorea robusta/ig;
		$text =~ s/\bshorea robusta \(sal\)/shorea robusta/ig;
	}
	elsif ($ingredients_lc eq 'fi') {

		# Organic label can appear as a part of a longer word.
		# Separate it so it can be detected
		$text =~ s/\b(luomu)\B/$1 /ig;
	}
	elsif ($ingredients_lc eq 'fr') {

		# huiles de palme et de

		# carbonates d'ammonium et de sodium

		# carotène et extraits de paprika et de curcuma

		# Minéraux (carbonate de calcium, chlorures de calcium, potassium et magnésium, citrates de potassium et de sodium, phosphate de calcium,
		# sulfates de fer, de zinc, de cuivre et de manganèse, iodure de potassium, sélénite de sodium).

		# graisses végétales de palme et de colza en proportion variable
		# remove stopwords
		$text =~ s/( en)? proportion(s)? variable(s)?//i;

		# Ingrédient(s) : lentilles vertes* - *issu(e)(s) de l'agriculture biologique.
		# -> remove the parenthesis

		$text =~ s/dient\(s\)/dients/ig;
		$text =~ s/\bissu(\(e\))?(\(s\))?/issu/ig;
	}
	elsif ($ingredients_lc eq 'pl') {

		# remove stopwords
		$text =~ s/w? (zmiennych|różnych)? proporcjach?//i;

	}

	$text = develop_ingredients_categories_and_types($ingredients_lc, $text);

	# vitamines A, B1, B2, B5, B6, B9, B12, C, D, H, PP et E
	# vitamines (A, B1, B2, B5, B6, B9, B12, C, D, H, PP et E)

	my @vitaminssuffixes = (
		"a", "rétinol", "b", "b1",
		"b2", "b3", "b4", "b5",
		"b6", "b7", "b8", "b9",
		"b10", "b11", "b12", "thiamine",
		"riboflavine", "niacine", "pyridoxine", "cobalamine",
		"biotine", "acide pantothénique", "acide folique", "c",
		"acide ascorbique", "d", "d2", "d3",
		"cholécalciférol", "e", "tocophérol", "alphatocophérol",
		"alpha-tocophérol", "f", "h", "k",
		"k1", "k2", "k3", "p",
		"pp",
	);
	my $vitaminsprefixregexp = "vit|vit\.|vitamine|vitamines";

	# Add synonyms in target language
	if (defined $translations_to{vitamins}) {
		foreach my $vitamin (keys %{$translations_to{vitamins}}) {
			if (defined $translations_to{vitamins}{$vitamin}{$ingredients_lc}) {
				push @vitaminssuffixes, $translations_to{vitamins}{$vitamin}{$ingredients_lc};
			}
		}
	}

	# Add synonyms in target language
	my $vitamin_in_lc
		= get_string_id_for_lang($ingredients_lc, display_taxonomy_tag($ingredients_lc, "ingredients", "en:vitamins"));
	$vitamin_in_lc =~ s/^\w\w://;

	if (    (defined $synonyms_for{ingredients})
		and (defined $synonyms_for{ingredients}{$ingredients_lc})
		and (defined $synonyms_for{ingredients}{$ingredients_lc}{$vitamin_in_lc}))
	{
		foreach my $synonym (@{$synonyms_for{ingredients}{$ingredients_lc}{$vitamin_in_lc}}) {
			$vitaminsprefixregexp .= '|' . $synonym;
		}
	}

	my $vitaminssuffixregexp = "";
	foreach my $suffix (@vitaminssuffixes) {
		$vitaminssuffixregexp .= '|' . $suffix;
		# vitamines [E, thiamine (B1), riboflavine (B2), B6, acide folique)].
		# -> also put (B1)
		$vitaminssuffixregexp .= '|\(' . $suffix . '\)';

		my $unaccented_suffix = unac_string_perl($suffix);
		if ($unaccented_suffix ne $suffix) {
			$vitaminssuffixregexp .= '|' . $unaccented_suffix;
		}
		if ($suffix =~ /[a-z]\d/) {

			$suffix =~ s/([a-z])(\d)/$1 $2/;
			$vitaminssuffixregexp .= '|' . $suffix;
			$suffix =~ s/ /-/;
			$vitaminssuffixregexp .= '|' . $suffix;

		}

	}
	$vitaminssuffixregexp =~ s/^\|//;

	#$log->debug("vitamins regexp", { regex => "s/($vitaminsprefixregexp)(:|\(|\[| )?(($vitaminssuffixregexp)(\/| \/ | - |,|, | et | and | y ))+/" }) if $log->is_debug();
	#$log->debug("vitamins text", { vitaminssuffixregexp => $vitaminssuffixregexp }) if $log->is_debug();

	# vitamines (B1, acide folique (B9)) <-- we need to match (B9) which is not followed by a \b boundary, hence the ((\s?((\)|\]))|\b)) in the regexp below

	$text
		=~ s/($vitaminsprefixregexp)(:|\(|\[| )+((($vitaminssuffixregexp)( |\/| \/ | - |,|, |$and)+)+($vitaminssuffixregexp))((\s?((\)|\]))|\b))/normalize_vitamins_enumeration($ingredients_lc,$3)/ieg;

	# Allergens and traces
	# Traces de lait, d'oeufs et de soja.
	# Contains: milk and soy.

	# TODO: we should use the allergens:en: property from the ingredients.txt taxonomy instead of relying
	# on having extensive "non synonyms" (like fish species) in allergens.txt

	foreach my $allergens_type ("allergens", "traces") {

		if (defined $contains_or_may_contain_regexps{$allergens_type}{$ingredients_lc}) {

			my $contains_or_may_contain_regexp = $contains_or_may_contain_regexps{$allergens_type}{$ingredients_lc};
			my $allergens_regexp = $allergens_regexps{$ingredients_lc};

			# stopwords
			# e.g. Kann Spuren von Senf und Sellerie enthalten.
			my $stopwords = "";
			if (defined $allergens_stopwords{$ingredients_lc}) {
				$stopwords = $allergens_stopwords{$ingredients_lc};
			}

			# $contains_or_may_contain_regexp may be the end of a sentence, remove the beginning
			# e.g. this product has been manufactured in a factory that also uses...
			# Some text with comma May contain ... -> Some text with comma, May contain
			# ! does not work in German and languages that have words with a capital letter
			if ($ingredients_lc ne "de") {
				my $ucfirst_contains_or_may_contain_regexp = $contains_or_may_contain_regexp;
				$ucfirst_contains_or_may_contain_regexp =~ s/(^|\|)(\w)/$1 . uc($2)/ieg;
				$text =~ s/([a-z]) ($ucfirst_contains_or_may_contain_regexp)/$1, $2/g;
			}

			#$log->debug("allergens regexp", { regex => "s/([^,-\.;\(\)\/]*)\b($contains_or_may_contain_regexp)\b(:|\(|\[| |$and|$of)+((($allergens_regexp)( |\/| \/ | - |,|, |$and|$of|$and_of)+)+($allergens_regexp))\b(s?(\)|\]))?" }) if $log->is_debug();
			#$log->debug("allergens", { lc => $ingredients_lc, may_contain_regexps => \%may_contain_regexps, contains_or_may_contain_regexp => $contains_or_may_contain_regexp, text => $text }) if $log->is_debug();

			# warning: we should remove a parenthesis at the end only if we remove one at the beginning
			# e.g. contains (milk, eggs) -> contains milk, eggs
			# chocolate (contains milk) -> chocolate (contains milk)
			$text
				=~ s/([^,-\.;\(\)\/]*)\b($contains_or_may_contain_regexp)\b((:|\(|\[| |$of)+)((_?($allergens_regexp)_?\b((\s)($stopwords)\b)*( |\/| \/ | - |,|, |$and|$of|$and_of)+)*_?($allergens_regexp)_?)\b((\s)($stopwords)\b)*(\s?(\)|\]))?/normalize_allergens_enumeration($allergens_type,$ingredients_lc,$3,$5,$17)/ieg;
			# we may have added an extra dot in order to make sure we have at least one
			$text =~ s/\.\./\./g;
		}
	}

	# Try to find the signification of symbols like *
	# Jus de pomme*** 68%, jus de poire***32% *** Ingrédients issus de l'agriculture biologique
	# Pâte de cacao°* du Pérou 65 %, sucre de canne°*, beurre de cacao°*. °Issus de l'agriculture biologique (100 %). *Issus du commerce équitable (100 % du poids total avec 93 % SPP).
	#  riz* de Camargue IGP(1) (16,5%) (riz complet*, riz rouge complet*, huiles* (tournesol*, olive* vierge extra), sel marin. *issus de l'agriculture biologique. (1) IGP : Indication Géographique Protégée.

	if (defined $labels_regexps{$ingredients_lc}) {

		foreach my $symbol (@symbols) {
			# Find the last occurence of the symbol or symbol in parenthesis:  * (*)
			# we need a negative look ahead (?!\)) to make sure we match (*) completely (otherwise we would match *)
			if ($text =~ /^(.*)(\($symbol\)|$symbol)(?!\))\s*(:|=)?\s*/i) {
				my $after = $';
				#print STDERR "symbol: $symbol - after: $after\n";
				foreach my $labelid (@labels) {
					my $regexp = $labels_regexps{$ingredients_lc}{$labelid};
					if (defined $regexp) {
						#print STDERR "-- label: $labelid - regexp: $regexp\n";
						# try to also match optional precisions like "Issus de l'agriculture biologique (100 % du poids total)"
						# *Issus du commerce équitable (100 % du poids total avec 93 % SPP).
						if ($after =~ /^($regexp)\b\s*(\([^\)]+\))?\s*\.?\s*/i) {
							my $label = $1;
							$text
								=~ s/^(.*)(\($symbol\)|$symbol)(?!\))\s?(:|=)?\s?$label\s*(\([^\)]+\))?\s*\.?\s*/$1 /i;
							my $ingredients_lc_label = display_taxonomy_tag($ingredients_lc, "labels", $labelid);
							$text =~ s/$symbol/ $ingredients_lc_label /g;
							last;
						}
					}
				}
			}
		}
	}

	# remove extra spaces
	$text =~ s/\s(\s)+/ /g;
	$text =~ s/ (\.|,|;)( |$)/$1$2/g;
	$text =~ s/^(\s|\.|,|;|-)+//;
	$text =~ s/(\s|,|;|-)+$//;

	$log->debug("preparse_ingredients_text result", {text => $text}) if $log->is_debug();

	$prev_return = $text;
	return $text;
}

=head2 extract_additives_from_text ($product_ref) - extract additives from the ingredients text

This function extracts additives from the ingredients text and adds them to the product_ref in the additives_tags array.

TODO: this function is independent of the ingredient parsing, we should combine the two.

=head3 Arguments

=head4 Product reference

=cut

sub extract_additives_from_text ($product_ref) {

	# delete additive fields (including some old debug fields)

	foreach
		my $tagtype ('additives', 'additives_prev', 'additives_next', 'additives_old', 'old_additives', 'new_additives')
	{

		delete $product_ref->{$tagtype};
		delete $product_ref->{$tagtype . "_debug"};
		delete $product_ref->{$tagtype . "_n"};
		delete $product_ref->{$tagtype . "_tags"};
		delete $product_ref->{$tagtype . "_original_tags"};
		delete $product_ref->{$tagtype . "_debug_tags"};
	}

	# Delete old fields, can be removed once all products have been reprocessed
	delete $product_ref->{with_sweeteners};
	delete $product_ref->{without_non_nutritive_sweeteners};

	# Sweeteners fields will be added by count_sweeteners_and_non_nutritive_sweeteners() if we have an ingredient list
	delete $product_ref->{ingredients_sweeteners_n};
	delete $product_ref->{ingredients_non_nutritive_sweeteners_n};

	my $ingredients_lc = get_or_select_ingredients_lc($product_ref);

	if ((not defined $product_ref->{ingredients_text}) or (not defined $ingredients_lc)) {
		return;
	}

	my $text = preparse_ingredients_text($ingredients_lc, $product_ref->{ingredients_text});
	# do not match anything if we don't have a translation for "and"
	my $and = $and{$ingredients_lc} || " will not match ";
	$and =~ s/ /-/g;

	#  remove % / percent (to avoid identifying 100% as E100 in some cases)
	$text =~ s/(\d+((\,|\.)\d+)?)\s*\%$//g;

	my @ingredients = split($separators, $text);

	my @ingredients_ids = ();
	foreach my $ingredient (@ingredients) {
		my $ingredientid = get_string_id_for_lang($ingredients_lc, $ingredient);
		if ((defined $ingredientid) and ($ingredientid ne '')) {

			# split additives
			# caramel ordinaire et curcumine
			if ($ingredientid =~ /$and/i) {

				my $ingredientid1 = $`;
				my $ingredientid2 = $';

				#print STDERR "ingredients_classes - ingredient1: $ingredientid1 - ingredient2: $ingredientid2\n";

				# check if the whole ingredient is an additive
				my $canon_ingredient_additive = canonicalize_taxonomy_tag($ingredients_lc, "additives", $ingredientid);

				if (not exists_taxonomy_tag("additives", $canon_ingredient_additive)) {

					# otherwise check the 2 sub ingredients
					my $canon_ingredient_additive1
						= canonicalize_taxonomy_tag($ingredients_lc, "additives", $ingredientid1);
					my $canon_ingredient_additive2
						= canonicalize_taxonomy_tag($ingredients_lc, "additives", $ingredientid2);

					if (    (exists_taxonomy_tag("additives", $canon_ingredient_additive1))
						and (exists_taxonomy_tag("additives", $canon_ingredient_additive2)))
					{
						push @ingredients_ids, $ingredientid1;
						$ingredientid = $ingredientid2;
						#print STDERR "ingredients_classes - ingredient1: $ingredientid1 exists - ingredient2: $ingredientid2 exists\n";
					}
				}

			}

			push @ingredients_ids, $ingredientid;
			$log->debug("ingredient 3", {ingredient => $ingredient}) if $log->is_debug();
		}
	}

	my %all_seen = ();    # used to not tag "huile végétale" if we have seen "huile de palme" already

	# Additives using new global taxonomy

	foreach my $tagtype ('additives', 'additives_prev', 'additives_next') {

		next if (not exists $loaded_taxonomies{$tagtype});

		$product_ref->{$tagtype . '_tags'} = [];

		my $tagtype_suffix = $tagtype;
		$tagtype_suffix =~ s/[^_]+//;

		my $vitamins_tagtype = "vitamins" . $tagtype_suffix;
		my $minerals_tagtype = "minerals" . $tagtype_suffix;
		my $amino_acids_tagtype = "amino_acids" . $tagtype_suffix;
		my $nucleotides_tagtype = "nucleotides" . $tagtype_suffix;
		my $other_nutritional_substances_tagtype = "other_nutritional_substances" . $tagtype_suffix;
		$product_ref->{$vitamins_tagtype . '_tags'} = [];
		$product_ref->{$minerals_tagtype . '_tags'} = [];
		$product_ref->{$amino_acids_tagtype . '_tags'} = [];
		$product_ref->{$nucleotides_tagtype . '_tags'} = [];
		$product_ref->{$other_nutritional_substances_tagtype . '_tags'} = [];

		my $class = $tagtype;

		my %seen = ();
		my %seen_tags = ();

		# Keep track of mentions of the additive class (e.g. "coloring: X, Y, Z") so that we can correctly identify additives after
		my $current_additive_class = "ingredient";

		foreach my $ingredient_id (@ingredients_ids) {

			my $ingredient_id_copy = $ingredient_id
				;    # can be modified later: soy-lecithin -> lecithin, but we don't change values of @ingredients_ids

			my $match = 0;
			my $match_without_mandatory_class = 0;

			while (not $match) {

				# additive class?
				my $canon_ingredient_additive_class
					= canonicalize_taxonomy_tag($ingredients_lc, "additives_classes", $ingredient_id_copy);

				if (exists_taxonomy_tag("additives_classes", $canon_ingredient_additive_class)) {
					$current_additive_class = $canon_ingredient_additive_class;
					$log->debug("current additive class", {current_additive_class => $canon_ingredient_additive_class})
						if $log->is_debug();
				}

				# additive?
				my $canon_ingredient = canonicalize_taxonomy_tag($ingredients_lc, $tagtype, $ingredient_id_copy);
				# in Hong Kong, the E- can be omitted in E-numbers
				my $canon_e_ingredient
					= canonicalize_taxonomy_tag($ingredients_lc, $tagtype, "e" . $ingredient_id_copy);
				my $canon_ingredient_vitamins
					= canonicalize_taxonomy_tag($ingredients_lc, "vitamins", $ingredient_id_copy);
				my $canon_ingredient_minerals
					= canonicalize_taxonomy_tag($ingredients_lc, "minerals", $ingredient_id_copy);
				my $canon_ingredient_amino_acids
					= canonicalize_taxonomy_tag($ingredients_lc, "amino_acids", $ingredient_id_copy);
				my $canon_ingredient_nucleotides
					= canonicalize_taxonomy_tag($ingredients_lc, "nucleotides", $ingredient_id_copy);
				my $canon_ingredient_other_nutritional_substances
					= canonicalize_taxonomy_tag($ingredients_lc, "other_nutritional_substances", $ingredient_id_copy);

				$product_ref->{$tagtype} .= " [ $ingredient_id_copy -> $canon_ingredient ";

				if (defined $seen{$canon_ingredient}) {
					$product_ref->{$tagtype} .= " -- already seen ";
					$match = 1;
				}

				# For additives, first check if the current class is vitamins or minerals and if the ingredient
				# exists in the vitamins and minerals taxonomy

				elsif (
					(
						   ($current_additive_class eq "en:vitamins")
						or ($current_additive_class eq "en:minerals")
						or ($current_additive_class eq "en:amino-acids")
						or ($current_additive_class eq "en:nucleotides")
						or ($current_additive_class eq "en:other-nutritional-substances")
					)

					and (exists_taxonomy_tag("vitamins", $canon_ingredient_vitamins))
					)
				{
					$match = 1;
					$seen{$canon_ingredient} = 1;
					$product_ref->{$tagtype}
						.= " -> exists as a vitamin $canon_ingredient_vitamins and current class is $current_additive_class ";
					if (not exists $seen_tags{$vitamins_tagtype . '_tags' . $canon_ingredient_vitamins}) {
						push @{$product_ref->{$vitamins_tagtype . '_tags'}}, $canon_ingredient_vitamins;
						$seen_tags{$vitamins_tagtype . '_tags' . $canon_ingredient_vitamins} = 1;
					}
				}

				elsif ( ($current_additive_class eq "en:minerals")
					and (exists_taxonomy_tag("minerals", $canon_ingredient_minerals))
					and not($just_synonyms{"minerals"}{$canon_ingredient_minerals}))
				{
					$match = 1;
					$seen{$canon_ingredient} = 1;
					$product_ref->{$tagtype}
						.= " -> exists as a mineral $canon_ingredient_minerals and current class is $current_additive_class ";
					if (not exists $seen_tags{$minerals_tagtype . '_tags' . $canon_ingredient_minerals}) {
						push @{$product_ref->{$minerals_tagtype . '_tags'}}, $canon_ingredient_minerals;
						$seen_tags{$minerals_tagtype . '_tags' . $canon_ingredient_minerals} = 1;
					}
				}

				elsif (
					(exists_taxonomy_tag($tagtype, $canon_ingredient))
					# do not match synonyms
					and ($canon_ingredient !~ /^en:(fd|no|colour)/)
					)
				{

					$seen{$canon_ingredient} = 1;
					$product_ref->{$tagtype} .= " -> exists ";

					if (    (defined $properties{$tagtype}{$canon_ingredient})
						and (defined $properties{$tagtype}{$canon_ingredient}{"mandatory_additive_class:en"}))
					{

						my $mandatory_additive_class
							= $properties{$tagtype}{$canon_ingredient}{"mandatory_additive_class:en"};
						# make the comma separated list a regexp
						$product_ref->{$tagtype}
							.= " -- mandatory_additive_class: $mandatory_additive_class (current: $current_additive_class) ";
						$mandatory_additive_class =~ s/,/\|/g;
						$mandatory_additive_class =~ s/\s//g;
						if ($current_additive_class =~ /^$mandatory_additive_class$/) {
							if (not exists $seen_tags{$tagtype . '_tags' . $canon_ingredient}) {
								push @{$product_ref->{$tagtype . '_tags'}}, $canon_ingredient;
								$seen_tags{$tagtype . '_tags' . $canon_ingredient} = 1;
							}
							# success!
							$match = 1;
							$product_ref->{$tagtype} .= " -- ok ";
						}
						elsif ($ingredient_id_copy =~ /^e( |-)?\d/) {
							# id the additive is mentioned with an E number, tag it even if we haven't detected a mandatory class
							if (not exists $seen_tags{$tagtype . '_tags' . $canon_ingredient}) {
								push @{$product_ref->{$tagtype . '_tags'}}, $canon_ingredient;
								$seen_tags{$tagtype . '_tags' . $canon_ingredient} = 1;
							}
							# success!
							$match = 1;
							$product_ref->{$tagtype} .= " -- e-number ";

						}
						else {
							$match_without_mandatory_class = 1;
						}
					}
					else {
						if (not exists $seen_tags{$tagtype . '_tags' . $canon_ingredient}) {
							push @{$product_ref->{$tagtype . '_tags'}}, $canon_ingredient;
							$seen_tags{$tagtype . '_tags' . $canon_ingredient} = 1;
						}
						# success!
						$match = 1;
						$product_ref->{$tagtype} .= " -- ok ";
					}
				}

				# continue to try to match a known additive, mineral or vitamin
				if (not $match) {

					# check if it is mineral or vitamin, even if we haven't seen "minerals" or "vitamins" before
					if ((exists_taxonomy_tag("vitamins", $canon_ingredient_vitamins))) {
						$match = 1;
						$seen{$canon_ingredient} = 1;
						$product_ref->{$tagtype} .= " -> exists as a vitamin $canon_ingredient_vitamins ";
						if (not exists $seen_tags{$vitamins_tagtype . '_tags' . $canon_ingredient_vitamins}) {
							push @{$product_ref->{$vitamins_tagtype . '_tags'}}, $canon_ingredient_vitamins;
							$seen_tags{$vitamins_tagtype . '_tags' . $canon_ingredient_vitamins} = 1;
						}
						# set current class to vitamins
						$current_additive_class = "en:vitamins";
					}

					elsif ((exists_taxonomy_tag("minerals", $canon_ingredient_minerals))
						and not($just_synonyms{"minerals"}{$canon_ingredient_minerals}))
					{
						$match = 1;
						$seen{$canon_ingredient} = 1;
						$product_ref->{$tagtype} .= " -> exists as a mineral $canon_ingredient_minerals ";
						if (not exists $seen_tags{$minerals_tagtype . '_tags' . $canon_ingredient_minerals}) {
							push @{$product_ref->{$minerals_tagtype . '_tags'}}, $canon_ingredient_minerals;
							$seen_tags{$minerals_tagtype . '_tags' . $canon_ingredient_minerals} = 1;
						}
						$current_additive_class = "en:minerals";
					}

					if ((exists_taxonomy_tag("amino_acids", $canon_ingredient_amino_acids))) {
						$match = 1;
						$seen{$canon_ingredient} = 1;
						$product_ref->{$tagtype} .= " -> exists as a amino_acid $canon_ingredient_amino_acids ";
						if (not exists $seen_tags{$amino_acids_tagtype . '_tags' . $canon_ingredient_amino_acids}) {
							push @{$product_ref->{$amino_acids_tagtype . '_tags'}}, $canon_ingredient_amino_acids;
							$seen_tags{$amino_acids_tagtype . '_tags' . $canon_ingredient_amino_acids} = 1;
						}
						$current_additive_class = "en:amino-acids";
					}

					elsif ((exists_taxonomy_tag("nucleotides", $canon_ingredient_nucleotides))) {
						$match = 1;
						$seen{$canon_ingredient} = 1;
						$product_ref->{$tagtype} .= " -> exists as a nucleotide $canon_ingredient_nucleotides ";
						if (not exists $seen_tags{$nucleotides_tagtype . '_tags' . $canon_ingredient_nucleotides}) {
							push @{$product_ref->{$nucleotides_tagtype . '_tags'}}, $canon_ingredient_nucleotides;
							$seen_tags{$nucleotides_tagtype . '_tags' . $canon_ingredient_nucleotides} = 1;
						}
						$current_additive_class = "en:nucleotides";
					}

					elsif (
						(
							exists_taxonomy_tag(
								"other_nutritional_substances",
								$canon_ingredient_other_nutritional_substances
							)
						)
						)
					{
						$match = 1;
						$seen{$canon_ingredient} = 1;
						$product_ref->{$tagtype}
							.= " -> exists as a other_nutritional_substance $canon_ingredient_other_nutritional_substances ";
						if (
							not exists $seen_tags{
									  $other_nutritional_substances_tagtype . '_tags'
									. $canon_ingredient_other_nutritional_substances
							}
							)
						{
							push @{$product_ref->{$other_nutritional_substances_tagtype . '_tags'}},
								$canon_ingredient_other_nutritional_substances;
							$seen_tags{$other_nutritional_substances_tagtype . '_tags'
									. $canon_ingredient_other_nutritional_substances} = 1;
						}
						$current_additive_class = "en:other-nutritional-substances";
					}

					# in Hong Kong, the E- can be omitted in E-numbers

					elsif (
						(
							$canon_ingredient
							=~ /^en:(\d+)( |-)?([a-z])??(i|ii|iii|iv|v|vi|vii|viii|ix|x|xi|xii|xii|xiv|xv)?$/i
						)
						and (exists_taxonomy_tag($tagtype, $canon_e_ingredient))
						and ($current_additive_class ne "ingredient")
						)
					{

						$seen{$canon_e_ingredient} = 1;
						$product_ref->{$tagtype} .= " -> e-ingredient exists  ";

						if (not exists $seen_tags{$tagtype . '_tags' . $canon_e_ingredient}) {
							push @{$product_ref->{$tagtype . '_tags'}}, $canon_e_ingredient;
							$seen_tags{$tagtype . '_tags' . $canon_e_ingredient} = 1;
						}
						# success!
						$match = 1;
						$product_ref->{$tagtype} .= " -- ok ";
					}
				}

				# spellcheck
				my $spellcheck = 0;
				# 2019/11/10 - disable spellcheck of additives, as it is much too slow and make way too many calls to functions
				if (
						0
					and (not $match)
					and ($tagtype eq 'additives')
					and not $match_without_mandatory_class
					# do not correct words that are existing ingredients in the taxonomy
					and (
						not exists_taxonomy_tag(
							"ingredients",
							canonicalize_taxonomy_tag($ingredients_lc, "ingredients", $ingredient_id_copy)
						)
					)
					)
				{

					my ($corrected_canon_tagid, $corrected_tagid, $corrected_tag)
						= spellcheck_taxonomy_tag($ingredients_lc, $tagtype, $ingredient_id_copy);
					if (
							(defined $corrected_canon_tagid)
						and ($corrected_tag ne $ingredient_id_copy)
						and (exists_taxonomy_tag($tagtype, $corrected_canon_tagid))

						# false positives
						# proteinas -> proteinase
						# vitamine z -> vitamine c
						# coloré -> chlore
						# chlorela -> chlore

						and (not $corrected_tag =~ /^proteinase/)
						and (not $corrected_tag =~ /^vitamin/)
						and (not $corrected_tag =~ /^argent/)
						and (not $corrected_tag =~ /^chlore/)

						)
					{

						$product_ref->{$tagtype}
							.= " -- spell correction (lc: "
							. $ingredients_lc
							. "): $ingredient_id_copy -> $corrected_tag";
						print STDERR "spell correction (lc: "
							. $ingredients_lc
							. "): $ingredient_id_copy -> $corrected_tag - code: $product_ref->{code}\n";

						$ingredient_id_copy = $corrected_tag;
						$spellcheck = 1;
					}
				}

				if (    (not $match)
					and (not $spellcheck))
				{

					# try to shorten the ingredient to make it less specific, to see if it matches then
					# in last resort, try with the first (in French, Spanish) or last (in English) word only

					if (($ingredients_lc eq 'en') and ($ingredient_id_copy =~ /^([^-]+)-/)) {
						# soy-lecithin -> lecithin
						$ingredient_id_copy = $';
					}
					elsif ( (($ingredients_lc eq 'es') or ($ingredients_lc eq 'fr'))
						and ($ingredient_id_copy =~ /-([^-]+)$/))
					{
						# lecitina-de-girasol -> lecitina-de -> lecitina
						# lecithine-de-soja -> lecithine-de -> lecithine
						$ingredient_id_copy = $`;
					}
					else {
						# give up
						$match = 1;
					}
				}

				$product_ref->{$tagtype} .= " ] ";
			}
		}

		# Also generate a list of additives with the parents (e.g. E500ii adds E500)
		$product_ref->{$tagtype . '_original_tags'} = $product_ref->{$tagtype . '_tags'};
		$product_ref->{$tagtype . '_tags'}
			= [
			sort(
				gen_tags_hierarchy_taxonomy("en", $tagtype, join(', ', @{$product_ref->{$tagtype . '_original_tags'}})))
			];

		# No ingredients?
		if ($product_ref->{ingredients_text} eq '') {
			delete $product_ref->{$tagtype . '_n'};
		}
		else {
			# count the original list of additives, don't count E500ii as both E500 and E500ii
			if (defined $product_ref->{$tagtype . '_original_tags'}) {
				$product_ref->{$tagtype . '_n'} = scalar @{$product_ref->{$tagtype . '_original_tags'}};
			}
			else {
				delete $product_ref->{$tagtype . '_n'};
			}
		}

		# Delete debug info
		if (not has_tag($product_ref, "categories", 'en:debug')) {
			delete $product_ref->{$tagtype};
		}

		# Delete empty arrays
		# -> not active
		# -> may be dangerous if some apps rely on them existing even if empty

		if (0) {
			foreach my $array (
				$tagtype . '_tags',
				$tagtype . '_original_tags',
				$vitamins_tagtype . '_tags',
				$minerals_tagtype . '_tags',
				$amino_acids_tagtype . '_tags',
				$nucleotides_tagtype . '_tags',
				$other_nutritional_substances_tagtype . '_tags'
				)
			{
				if ((defined $product_ref->{$array}) and ((scalar @{$product_ref->{$array}}) == 0)) {
					delete $product_ref->{$array};
				}
			}
		}
	}

	# compute minus and debug values

	my $field = 'additives';

	# check if we have a previous or a next version and compute differences

	# previous version

	if (exists $loaded_taxonomies{$field . "_prev"}) {

		(defined $product_ref->{$field . "_debug_tags"}) or $product_ref->{$field . "_debug_tags"} = [];

		# compute differences
		foreach my $tag (@{$product_ref->{$field . "_tags"}}) {
			if (not has_tag($product_ref, $field . "_prev", $tag)) {
				my $tagid = $tag;
				$tagid =~ s/:/-/;
				push @{$product_ref->{$field . "_debug_tags"}}, "$tagid-added";
			}
		}
		foreach my $tag (@{$product_ref->{$field . "_prev_tags"}}) {
			if (not has_tag($product_ref, $field, $tag)) {
				my $tagid = $tag;
				$tagid =~ s/:/-/;
				push @{$product_ref->{$field . "_debug_tags"}}, "$tagid-removed";
			}
		}
	}
	else {
		delete $product_ref->{$field . "_prev_hierarchy"};
		delete $product_ref->{$field . "_prev_tags"};
	}

	# next version

	if (exists $loaded_taxonomies{$field . "_next"}) {

		(defined $product_ref->{$field . "_debug_tags"}) or $product_ref->{$field . "_debug_tags"} = [];

		# compute differences
		foreach my $tag (@{$product_ref->{$field . "_tags"}}) {
			if (not has_tag($product_ref, $field . "_next", $tag)) {
				my $tagid = $tag;
				$tagid =~ s/:/-/;
				push @{$product_ref->{$field . "_debug_tags"}}, "$tagid-will-remove";
			}
		}
		foreach my $tag (@{$product_ref->{$field . "_next_tags"}}) {
			if (not has_tag($product_ref, $field, $tag)) {
				my $tagid = $tag;
				$tagid =~ s/:/-/;
				push @{$product_ref->{$field . "_debug_tags"}}, "$tagid-will-add";
			}
		}
	}
	else {
		delete $product_ref->{$field . "_next_hierarchy"};
		delete $product_ref->{$field . "_next_tags"};
	}

	if (   (defined $product_ref->{ingredients_that_may_be_from_palm_oil_n})
		or (defined $product_ref->{ingredients_from_palm_oil_n}))
	{
		$product_ref->{ingredients_from_or_that_may_be_from_palm_oil_n}
			= $product_ref->{ingredients_that_may_be_from_palm_oil_n} + $product_ref->{ingredients_from_palm_oil_n};
	}

	# Determine if the product has sweeteners, and non nutritive sweeteners
	count_sweeteners_and_non_nutritive_sweeteners($product_ref);

	return;
}

=head2 count_sweeteners_and_non_nutritive_sweeteners

Check if the product contains sweeteners and non nutritive sweeteners (used for the Nutri-Score for beverages)

The NNS / Non nutritive sweeteners listed in the Nutri-Score Update report beverages_31 01 2023-voted
have been added as a non_nutritive_sweetener:en:yes property in the additives taxonomy.

=head3 Return values

The function sets the following fields in the product_ref hash.

If there are no ingredients specified for the product, the fields are not set.

=head4 ingredients_sweeteners_n

=head4 ingredients_non_nutritive_sweeteners_n

=cut

sub count_sweeteners_and_non_nutritive_sweeteners ($product_ref) {

	# Delete old fields, can be removed once all products have been reprocessed
	delete $product_ref->{with_sweeteners};
	delete $product_ref->{without_non_nutritive_sweeteners};

	# Set the number of sweeteners only if the product has specified ingredients
	if (not $product_ref->{ingredients_n}) {
		delete $product_ref->{ingredients_sweeteners_n};
		delete $product_ref->{ingredients_non_nutritive_sweeteners_n};
	}
	else {

		$product_ref->{ingredients_sweeteners_n} = 0;
		$product_ref->{ingredients_non_nutritive_sweeteners_n} = 0;

		# Go through additives and check if the product contains sweeteners and non-nutritive sweeteners
		if (defined $product_ref->{additives_tags}) {
			foreach my $additive (@{$product_ref->{additives_tags}}) {
				my $sweetener_property = get_inherited_property("additives", $additive, "sweetener:en") // "";
				if ($sweetener_property eq "yes") {
					$product_ref->{ingredients_sweeteners_n}++;
				}
				my $non_nutritive_sweetener_property
					= get_inherited_property("additives", $additive, "non_nutritive_sweetener:en") // "";
				if ($non_nutritive_sweetener_property eq "yes") {
					$product_ref->{ingredients_non_nutritive_sweeteners_n}++;
				}
			}
		}
	}

	return;
}

sub replace_allergen ($language, $product_ref, $allergen, $before) {

	my $ingredients_lc = get_or_select_ingredients_lc($product_ref);
	my $field = "allergens";

	my $traces_regexp = $may_contain_regexps{$language};

	if ((defined $traces_regexp) and ($before =~ /\b($traces_regexp)\b/i)) {
		$field = "traces";
	}

	# to build the product allergens list, just use the ingredients in the main language
	if ($language eq $ingredients_lc) {
		# skip allergens like "moutarde et céleri" (will be caught later by replace_allergen_between_separators)
		if (not(($language eq 'fr') and $allergen =~ / et /i)) {
			$product_ref->{$field . "_from_ingredients"} .= $allergen . ', ';
		}
	}

	return '<span class="allergen">' . $allergen . '</span>';
}

sub replace_allergen_in_caps ($language, $product_ref, $allergen, $before) {

	my $ingredients_lc = get_or_select_ingredients_lc($product_ref);
	my $field = "allergens";

	my $traces_regexp = $may_contain_regexps{$language};

	if ((defined $traces_regexp) and ($before =~ /\b($traces_regexp)\b/i)) {
		$field = "traces";
	}

	my $tagid = canonicalize_taxonomy_tag($language, "allergens", $allergen);

	if (exists_taxonomy_tag("allergens", $tagid)) {
		#$allergen = display_taxonomy_tag($product_ref->{lang},"allergens", $tagid);
		# to build the product allergens list, just use the ingredients in the main language
		if ($language eq $ingredients_lc) {
			$product_ref->{$field . "_from_ingredients"} .= $allergen . ', ';
		}
		return '<span class="allergen">' . $allergen . '</span>';
	}
	else {
		return $allergen;
	}
}

sub replace_allergen_between_separators ($language, $product_ref, $start_separator, $allergen, $end_separator, $before)
{
	my $ingredients_lc = get_or_select_ingredients_lc($product_ref);
	my $field = "allergens";

	#print STDERR "replace_allergen_between_separators - allergen: $allergen\n";

	my $stopwords = $allergens_stopwords{$language};

	#print STDERR "replace_allergen_between_separators - language: $language - allergen: $allergen\nstopwords: $stopwords\n";

	my $before_allergen = "";
	my $after_allergen = "";

	my $contains_regexp = $contains_regexps{$language} || "";
	my $may_contain_regexp = $may_contain_regexps{$language} || "";

	# allergen or trace?

	if ($allergen =~ /\b($contains_regexp|$may_contain_regexp)\b/i) {
		$before_allergen .= $` . $1;
		$allergen = $';
	}

	# Remove stopwords at the beginning or end
	if (defined $stopwords) {
		if ($allergen =~ /^((\s|\b($stopwords)\b)+)/i) {
			$before_allergen .= $1;
			$allergen =~ s/^(\s|\b($stopwords)\b)+//i;
		}
		if ($allergen =~ /((\s|\b($stopwords)\b)+)$/i) {
			$after_allergen .= $1;
			$allergen =~ s/(\s|\b($stopwords)\b)+$//i;
		}
	}

	if (($before . $before_allergen) =~ /\b($may_contain_regexp)\b/i) {
		$field = "traces";
		#print STDERR "traces (before_allergen: $before_allergen - before: $before)\n";
	}

	# Farine de blé 97%
	if ($allergen =~ /( \d)/) {
		$allergen = $`;
		$end_separator = $1 . $' . $end_separator;
	}

	#print STDERR "before_allergen: $before_allergen - allergen: $allergen\n";

	my $tagid = canonicalize_taxonomy_tag($language, "allergens", $allergen);

	#print STDERR "before_allergen: $before_allergen - allergen: $allergen - tagid: $tagid\n";

	if (($tagid ne "en:none") and (exists_taxonomy_tag("allergens", $tagid))) {
		#$allergen = display_taxonomy_tag($product_ref->{lang},"allergens", $tagid);
		# to build the product allergens list, just use the ingredients in the main language
		if ($language eq $ingredients_lc) {
			$product_ref->{$field . "_from_ingredients"} .= $allergen . ', ';
		}
		return
			  $start_separator
			. $before_allergen
			. '<span class="allergen">'
			. $allergen
			. '</span>'
			. $after_allergen
			. $end_separator;
	}
	else {
		return $start_separator . $before_allergen . $allergen . $after_allergen . $end_separator;
	}
}

=head2 detect_allergens_from_ingredients ( $product_ref )

Detects allergens from the ingredients extracted from the ingredients text,
using the "allergens:en" property associated to some ingredients in the
ingredients taxonomy.

This functions needs to be run after the $product_ref->{ingredients} array
is populated from the ingredients text.

It is called by detect_allergens_from_text().
Allergens are added to $product_ref->{"allergens_from_ingredients"} which
is then used by detect_allergens_from_text() to populate the allergens_tags field.

=cut

sub detect_allergens_from_ingredients ($product_ref) {

	# Check the allergens:en property of each ingredient

	$log->debug("detect_allergens_from_ingredients -- start", {ingredients => $product_ref->{ingredients}})
		if $log->is_debug();

	if (not defined $product_ref->{ingredients}) {
		return;
	}

	my @ingredients = (@{$product_ref->{ingredients}});

	while (@ingredients) {
		my $ingredient_ref = pop(@ingredients);
		if (defined $ingredient_ref->{ingredients}) {
			foreach my $sub_ingredient_ref (@{$ingredient_ref->{ingredients}}) {
				push @ingredients, $sub_ingredient_ref;
			}
		}
		my $allergens = get_inherited_property("ingredients", $ingredient_ref->{id}, "allergens:en");
		$log->debug(
			"detect_allergens_from_ingredients -- ingredient",
			{id => $ingredient_ref->{id}, allergens => $allergens}
		) if $log->is_debug();

		if (defined $allergens) {
			$product_ref->{"allergens_from_ingredients"} .= $allergens . ', ';
			$log->debug("detect_allergens_from_ingredients -- found allergen", {allergens => $allergens})
				if $log->is_debug();
		}
	}
	return;
}

=head2 get_allergens_taxonomyid ( $ingredients_lc, $ingredient_or_allergen )

In the allergens provided by users, we may get ingredients that are not in the allergens taxonomy,
but that are in the ingredients taxonomy and have an inherited allergens:en property.
(e.g. the allergens taxonomy has an en:fish entry, but users may indicate specific fish species)

This function tries to match the ingredient with an allergen in the allergens taxonomy,
and otherwise return the taxonomy id for the original ingredient.

=head3 Parameters

=head4 $ingredients_lc

The language code of $ingredient_or_allergen.

=head4 $ingredient_or_allergen

The ingredient or allergen to match. Can also be an ingredient id or allergens id prefixed with a language code.

=head3 Return value

The taxonomy id for the allergen, or the original ingredient if no allergen was found.

=cut

sub get_allergens_taxonomyid($ingredients_lc, $ingredient_or_allergen) {

	# Check if $ingredient_or_allergen is in the allergen taxonomy
	my $allergenid = canonicalize_taxonomy_tag($ingredients_lc, "allergens", $ingredient_or_allergen);
	if (exists_taxonomy_tag("allergens", $allergenid)) {
		return $allergenid;
	}
	else {
		# Check if $ingredient_or_allergen is in the ingredients taxonomy and has an inherited allergens:en: property
		my $ingredient_id = canonicalize_taxonomy_tag($ingredients_lc, "ingredients", $ingredient_or_allergen);
		my $allergens = get_inherited_property("ingredients", $ingredient_id, "allergens:en");
		if (defined $allergens) {
			if ($allergens =~ /,/) {
				# Currently we support only 1 allergen for a single ingredient
				$log->warn(
					"get_allergens_taxonomyid - multiple allergens for ingredient",
					{ingredient_or_allergen => $ingredient_or_allergen, allergens => $allergens}
				);
				$allergens = $`;
			}
			$allergenid = canonicalize_taxonomy_tag($ingredients_lc, "allergens", $allergens);
			if (exists_taxonomy_tag("allergens", $allergenid)) {
				return $allergenid;
			}
		}
	}

	# If we did not recognize the allergen, return the taxonomy id for the original tag
	return get_taxonomyid($ingredients_lc, $ingredient_or_allergen);
}

=head2 detect_allergens_from_text ( $product_ref )

This function:
- combines all the ways we have to detect allergens in order to populate
the allergens_tags and traces_tags fields.
- creates the ingredients_text_with_allergens_[lc] fields with added
HTML <span class="allergen"> tags

Allergens are recognized in the following ways:

1. using the list of ingredients that have been recognized through
ingredients analysis, by looking at the allergens:en property in the
ingredients taxonomy.
This is done with the function detect_allergens_from_ingredients()

2. when entered in ALL CAPS, or between underscores

3. when matching exact entries o synonyms of the allergens taxonomy

Allergens detected using 2. or 3. are marked with <span class="allergen">

=cut

sub detect_allergens_from_text ($product_ref) {

	$log->debug("detect_allergens_from_text - start", {}) if $log->is_debug();

	if ((scalar keys %allergens_stopwords) == 0) {
		init_allergens_regexps();
	}

	my $ingredients_lc = get_or_select_ingredients_lc($product_ref);

	# Keep allergens entered by users in the allergens and traces field

	foreach my $field ("allergens", "traces") {

		# new fields for allergens detected from ingredient list

		$product_ref->{$field . "_from_ingredients"} = "";
	}

	# Add allergens from the ingredients analysis
	detect_allergens_from_ingredients($product_ref);

	# Remove ingredients_text_with_allergens_* fields
	# they will be recomputed for existing ingredients languages

	foreach my $field (keys %$product_ref) {
		if ($field =~ /^ingredients_text_with_allergens/) {
			delete $product_ref->{$field};
		}
	}

	if (defined $product_ref->{languages_codes}) {

		foreach my $language (keys %{$product_ref->{languages_codes}}) {

			my $text = $product_ref->{"ingredients_text_" . $language};
			next if not defined $text;

			# do not match anything if we don't have a translation for "and"
			my $and = $and{$language} || " will not match ";
			my $of = ' - ';
			if (defined $of{$language}) {
				$of = $of{$language};
			}
			my $the = ' - ';
			if (defined $the{$language}) {
				$the = $the{$language};
			}

			my $traces_regexp = "traces";
			if (defined $may_contain_regexps{$language}) {
				$traces_regexp = $may_contain_regexps{$language};
			}

			$text =~ s/\&quot;/"/g;

			# allergens between underscores
			# _allergen_ + __allergen__ + ___allergen___

			$text =~ s/\b___([^,;_\(\)\[\]]+?)___\b/replace_allergen($language,$product_ref,$1,$`)/iesg;
			$text =~ s/\b__([^,;_\(\)\[\]]+?)__\b/replace_allergen($language,$product_ref,$1,$`)/iesg;
			$text =~ s/\b_([^,;_\(\)\[\]]+?)_\b/replace_allergen($language,$product_ref,$1,$`)/iesg;
			# _Weizen_eiweiß is not caught in last regex because of \b (word boundary).
			if ($language eq 'de') {
				$text =~ s/\b_([^,;_\(\)\[\]]+?)_/replace_allergen($language,$product_ref,$1,$`)/iesg;
			}

			# allergens in all caps, with other ingredients not in all caps

			if ($text =~ /[a-z]/) {
				# match ALL CAPS including space (but stop at the dash in "FRUITS A COQUE - Something")
				$text
					=~ s/\b([A-ZÌÒÁÉÍÓÚÝÂÊÎÔÛÃÑÕÄËÏÖŸÇŒß][A-ZÌÒÁÉÍÓÚÝÂÊÎÔÛÃÑÕÄËÏÖŸÇŒß]([A-ZÌÒÁÉÍÓÚÝÂÊÎÔÛÃÑÕÄËÏÖŸÇŒß' ]+))\b/replace_allergen_in_caps($language,$product_ref,$1,$`)/esg;
				# match ALL-CAPS including space and - (for NOIX DE SAINT-JACQUES)
				$text
					=~ s/\b([A-ZÌÒÁÉÍÓÚÝÂÊÎÔÛÃÑÕÄËÏÖŸÇŒß][A-ZÌÒÁÉÍÓÚÝÂÊÎÔÛÃÑÕÄËÏÖŸÇŒß]([A-ZÌÒÁÉÍÓÚÝÂÊÎÔÛÃÑÕÄËÏÖŸÇŒß'\- ]+))\b/replace_allergen_in_caps($language,$product_ref,$1,$`)/esg;
			}

			# allergens between separators

			# positive look ahead for the separators so that we can properly match the next word
			# match at least 3 characters so that we don't match the separator
			# Farine de blé 97% -> make numbers be separators
			$text
				=~ s/(^| - |_|\(|\[|\)|\]|,|$the|$and|$of|;|\.|$)((\s*)\w.+?)(?=(\s*)(^| - |_|\(|\[|\)|\]|,|$and|;|\.|\b($traces_regexp)\b|$))/replace_allergen_between_separators($language,$product_ref,$1, $2, "",$`)/iesg;

			# some allergens can be recognized in multiple ways.
			# e.g. _CELERY_ -> <span class="allergen"><span class="allergen"><span class="allergen">CELERI</span></span></span>
			$text =~ s/(<span class="allergen">)+/<span class="allergen">/g;
			$text =~ s/(<\/span>)+/<\/span>/g;

			$product_ref->{"ingredients_text_with_allergens_" . $language} = $text;

			if ($language eq $ingredients_lc) {
				$product_ref->{"ingredients_text_with_allergens"} = $text;
			}

		}
	}

	# If traces were entered in the allergens field, split them
	# Use the language the tag have been entered in

	my $traces_regexp;
	my $traces_lc = $product_ref->{traces_lc} || $product_ref->{lc};
	if ((defined $traces_lc) and (defined $may_contain_regexps{$traces_lc})) {
		$traces_regexp = $may_contain_regexps{$traces_lc};
	}

	if (    (defined $traces_regexp)
		and (defined $product_ref->{allergens})
		and ($product_ref->{allergens} =~ /\b($traces_regexp)\b\s*:?\s*/i))
	{
		if (defined $product_ref->{traces}) {
			$product_ref->{traces} .= ", " . $';
		}
		else {
			$product_ref->{traces} = $';
		}
		$product_ref->{allergens} = $`;
		$product_ref->{allergens} =~ s/\s+$//;
	}

	foreach my $field ("allergens", "traces") {

		# regenerate allergens and traces from the allergens_tags field so that it is prefixed with the values in the
		# main language of the product (which may be different than the $tag_lc language of the interface)

		my $tag_lc = $product_ref->{$field . "_lc"} || $product_ref->{lc} || "?";
		$product_ref->{$field . "_from_user"} = "($tag_lc) " . ($product_ref->{$field} // "");
		$product_ref->{$field . "_hierarchy"} = [gen_tags_hierarchy_taxonomy($tag_lc, $field, $product_ref->{$field})];
		$product_ref->{$field} = join(',', @{$product_ref->{$field . "_hierarchy"}});

		# concatenate allergens and traces fields from ingredients and entered by users

		$product_ref->{$field . "_from_ingredients"} =~ s/, $//;

		my $allergens = $product_ref->{$field . "_from_ingredients"};

		if ((defined $product_ref->{$field}) and ($product_ref->{$field} ne "")) {

			$allergens .= ", " . $product_ref->{$field};
		}

		$product_ref->{$field . "_hierarchy"}
			= [gen_tags_hierarchy_taxonomy($ingredients_lc || $product_ref->{lc}, $field, $allergens)];
		$product_ref->{$field . "_tags"} = [];
		# print STDERR "result for $field : ";
		foreach my $tag (@{$product_ref->{$field . "_hierarchy"}}) {
			push @{$product_ref->{$field . "_tags"}},
				get_allergens_taxonomyid($ingredients_lc || $product_ref->{lc}, $tag);
			# print STDERR " - $tag";
		}
		# print STDERR "\n";
	}

	$log->debug("detect_allergens_from_text - done", {}) if $log->is_debug();

	return;
}

=head2 add_ingredients_matching_function ( $ingredients_ref, $match_function_ref )

Recursive function to compute the percentage of ingredients that match a specific function.

The match function takes 2 arguments:
- ingredient id
- processing (comma separated list of ingredients_processing taxonomy entries)

Used to compute % of fruits and vegetables, % of milk etc. which is needed by some algorithm
like the Nutri-Score.

=head3 Return values

=head4 $percent

Sum of matching ingredients percent.

=head4 $water_percent

Percent of water (used to recompute the percentage for categories of products that are consumed after removing water)

=cut

sub add_ingredients_matching_function ($ingredients_ref, $match_function_ref) {

	my $percent = 0;
	my $water_percent = 0;

	foreach my $ingredient_ref (@{$ingredients_ref}) {

		my $sub_ingredients_percent = 0;
		my $sub_ingredients_water_percent = 0;

		my $ingredient_percent;
		if (defined $ingredient_ref->{percent}) {
			$ingredient_percent = $ingredient_ref->{percent};
		}
		elsif (defined $ingredient_ref->{percent_estimate}) {
			$ingredient_percent = $ingredient_ref->{percent_estimate};
		}

		my $match = $match_function_ref->($ingredient_ref->{id}, $ingredient_ref->{processing});

		# We have a match and a percent
		if (($match) and (defined $ingredient_percent)) {
			$percent += $ingredient_percent;
		}
		# The ingredient does not match,
		# or we don't have percent_estimate if the ingredient analysis failed because of seemingly impossible values
		# in that case, try to get the possible percent values in nested sub ingredients
		elsif (defined $ingredient_ref->{ingredients}) {
			($sub_ingredients_percent, $sub_ingredients_water_percent)
				= add_ingredients_matching_function($ingredient_ref->{ingredients}, $match_function_ref);
			$percent += $sub_ingredients_percent;
		}
		# Keep track of water
		if ((is_a("ingredients", $ingredient_ref->{id}, 'en:water')) and (defined $ingredient_percent)) {
			# Count water only in the ingredient if we have something like "flavored water 80% (water, flavour)"
			$water_percent += $ingredient_percent;
		}
		else {
			# We may have water in sub ingredients
			$water_percent += $sub_ingredients_water_percent;
		}

	}
	return ($percent, $water_percent);
}

=head2 estimate_ingredients_matching_function ( $product_ref, $match_function_ref, $nutrient_id = undef )

This function analyzes the ingredients to estimate the percentage of ingredients of a specific type
(e.g. fruits/vegetables/legumes for the Nutri-Score).

=head3 Parameters

=head4 $product_ref

=head4 $match_function_ref

Reference to a function that matches specific ingredients (e.g. fruits/vegetables/legumes)

=head4 $nutrient_id (optional)

If the $nutrient_id argument is defined, we also store the nutrient value in $product_ref->{nutriments}.

=head3 Return value

Estimated percentage of ingredients matching the function.

=cut

sub estimate_ingredients_matching_function ($product_ref, $match_function_ref, $nutrient_id = undef) {

	my ($percent, $water_percent);

	if ((defined $product_ref->{ingredients}) and ((scalar @{$product_ref->{ingredients}}) > 0)) {

		($percent, $water_percent)
			= add_ingredients_matching_function($product_ref->{ingredients}, $match_function_ref);

		$log->debug("estimate_ingredients_matching_function", {percent => $percent, water_percent => $water_percent})
			if $log->is_debug();

		# For product categories where water is not consumed (e.g canned vegetables),
		# we recompute the percent of matching ingredients in the product without water
		# en:canned-plant-based-foods may be a bit broad, as some canned vegetables are consumed with the sauce/water
		# en:canned-fruits are not included as those are often in syrup, which is consumed
		if (    (defined $water_percent)
			and ($water_percent > 0)
			and ($water_percent < 100)
			and (has_tag($product_ref, "categories", "en:canned-plant-based-foods"))
			and not(has_tag($product_ref, "categories", "en:canned-fruits")))
		{
			$percent = $percent * 100 / (100 - $water_percent);
		}
	}

	# If we have specific ingredients, check if we have a higher fruits / vegetables content
	if (defined $product_ref->{specific_ingredients}) {
		my $specific_ingredients_percent = 0;
		foreach my $ingredient_ref (@{$product_ref->{specific_ingredients}}) {
			my $ingredient_id = $ingredient_ref->{id};
			# We can have specific ingredients with % or grams
			my $percent_or_quantity_g = $ingredient_ref->{percent} || $ingredient_ref->{quantity_g};
			if (defined $percent_or_quantity_g) {

				if ($match_function_ref->($ingredient_id)) {
					$specific_ingredients_percent += $percent_or_quantity_g;
				}
			}
		}

		if (    ($specific_ingredients_percent > 0)
			and ((not defined $percent) or ($specific_ingredients_percent > $percent)))
		{
			$percent = $specific_ingredients_percent;
		}
	}

	if (defined $nutrient_id) {
		if (defined $percent) {
			$product_ref->{nutriments}{$nutrient_id . "_100g"} = $percent;
			$product_ref->{nutriments}{$nutrient_id . "_serving"} = $percent;
		}
		elsif (defined $product_ref->{nutriments}) {
			delete $product_ref->{nutriments}{$nutrient_id . "_100g"};
			delete $product_ref->{nutriments}{$nutrient_id . "_serving"};
		}
	}

	return $percent;
}

=head2 is_fruits_vegetables_nuts_olive_walnut_rapeseed_oils ( $ingredient_id, $processing = undef )

Determine if an ingredient should be counted as "fruits, vegetables, nuts, olive / walnut / rapeseed oils"
in Nutriscore 2021 algorithm.

- we use the nutriscore_fruits_vegetables_nuts:en property to identify qualifying ingredients
- we check that the parent of those ingredients is not a flour
- we check that the ingredient does not have a processing like en:powder

NUTRI-SCORE FREQUENTLY ASKED QUESTIONS - UPDATED 27/09/2022:

"However, fruits, vegetables and pulses that are subject to further processing (e.g. concentrated fruit juice
sugars, powders, freeze-drying, candied fruits, fruits in stick form, flours leading to loss of water) do not
count. As an example, corn in the form of popcorn or soy proteins cannot be considered as vegetables.
Regarding the frying process, fried vegetables which are thick and only partially dehydrated by the process
can be taken into account, whereas crisps which are thin and completely dehydrated are excluded."

=cut

my $further_processing_regexp = 'en:candied|en:flour|en:freeze-dried|en:powder';

sub is_fruits_vegetables_nuts_olive_walnut_rapeseed_oils ($ingredient_id, $processing = undef) {

	my $nutriscore_fruits_vegetables_nuts
		= get_inherited_property("ingredients", $ingredient_id, "nutriscore_fruits_vegetables_nuts:en");

	# Check that the ingredient is not further processed
	my $is_a_further_processed_ingredient = is_a("ingredients", $ingredient_id, "en:flour");

	my $further_processed = ((defined $processing) and ($processing =~ /\b($further_processing_regexp)\b/));

	return (
		(
					(defined $nutriscore_fruits_vegetables_nuts)
				and ($nutriscore_fruits_vegetables_nuts eq "yes")
				and (not $is_a_further_processed_ingredient)
				and (not $further_processed)
		)
			or 0
	);
}

=head2 estimate_nutriscore_2021_fruits_vegetables_nuts_percent_from_ingredients ( product_ref )

This function analyzes the ingredients to estimate the minimum percentage of
fruits, vegetables, nuts, olive / walnut / rapeseed oil, so that we can compute
the Nutri-Score fruit points if we don't have a value given by the manufacturer
or estimated by users.

Results are stored in $product_ref->{nutriments}{"fruits-vegetables-nuts-estimate-from-ingredients_100g"} (and _serving)

=cut

sub estimate_nutriscore_2021_fruits_vegetables_nuts_percent_from_ingredients ($product_ref) {

	return estimate_ingredients_matching_function(
		$product_ref,
		\&is_fruits_vegetables_nuts_olive_walnut_rapeseed_oils,
		"fruits-vegetables-nuts-estimate-from-ingredients"
	);

}

=head2 is_fruits_vegetables_legumes ( $ingredient_id, $processing = undef)

Determine if an ingredient should be counted as "fruits, vegetables, legumes"
in Nutriscore 2023 algorithm.

- we use the eurocode_2_group_1:en and eurocode_2_group_2:en  property to identify qualifying ingredients
- we check that the parent of those ingredients is not a flour
- we check that the ingredient does not have a processing like en:powder

1.2.2. Ingredients contributing to the "Fruit, vegetables and legumes" component

The list of ingredients qualifying for the "Fruit, vegetables and legumes" component has been revised
to include the following Eurocodes:
•
Vegetables groups
o 8.10 (Leaf vegetables);
o 8.15 (Brassicas);
o 8.20 (Stalk vegetables);
o 8.25 (Shoot vegetables);
o 8.30 (Onion-family vegetables);
o 8.38 (Root vegetables);
o 8.40 (Fruit vegetables);
o 8.42 (Flower-head vegetables);
o 8.45 (Seed vegetables and immature pulses);
o 8.50 (Edible fungi);
o 8.55 (Seaweeds and algae);
o 8.60 (Vegetable mixtures)
Fruits groups
o 9.10 (Malaceous fruit);
o 9.20 (Prunus species fruit);
o 9.25 (Other stone fruit);
o 9.30 (Berries);
o 9.40 (Citrus fruit);
o 9.50 (Miscellaneous fruit);
o 9.60 (Fruit mixtures).
Pulses groups
o 7.10 (Pulses).

Additionally, in the fats and oils category specifically, oils derived from ingredients in the list qualify
for the component (e.g. olive and avocado).

--

NUTRI-SCORE FREQUENTLY ASKED QUESTIONS - UPDATED 27/09/2022:

"However, fruits, vegetables and pulses that are subject to further processing (e.g. concentrated fruit juice
sugars, powders, freeze-drying, candied fruits, fruits in stick form, flours leading to loss of water) do not
count. As an example, corn in the form of popcorn or soy proteins cannot be considered as vegetables.
Regarding the frying process, fried vegetables which are thick and only partially dehydrated by the process
can be taken into account, whereas crisps which are thin and completely dehydrated are excluded."

=cut

my %fruits_vegetables_legumes_eurocodes = (
	"7.10" => 1,
	"8.10" => 1,
	"8.15" => 1,
	"8.20" => 1,
	"8.25" => 1,
	"8.30" => 1,
	"8.38" => 1,
	"8.40" => 1,
	"8.42" => 1,
	"8.45" => 1,
	"8.50" => 1,
	"8.55" => 1,
	"8.60" => 1,
	"9.10" => 1,
	"9.20" => 1,
	"9.25" => 1,
	"9.30" => 1,
	"9.40" => 1,
	"9.50" => 1,
	"9.60" => 1,
	"12.20" => 1,    # Herbs
);

sub is_fruits_vegetables_legumes ($ingredient_id, $processing = undef) {

	my $eurocode_2_group_1 = get_inherited_property("ingredients", $ingredient_id, "eurocode_2_group_1:en");
	my $eurocode_2_group_2 = get_inherited_property("ingredients", $ingredient_id, "eurocode_2_group_2:en");

	# Check that the ingredient is not further processed
	my $is_a_further_processed_ingredient = is_a("ingredients", $ingredient_id, "en:flour");

	my $further_processed = ((defined $processing) and ($processing =~ /\b($further_processing_regexp)\b/));

	return (
		(
			(
				# All fruits groups
				# TODO: check that we don't have entries under en:fruits that are in fact not listed in Eurocode 9 "Fruits and fruit products"
				((defined $eurocode_2_group_1) and ($eurocode_2_group_1 eq "9"))
					# Vegetables and legumes
					or ((defined $eurocode_2_group_2)
					and ($fruits_vegetables_legumes_eurocodes{$eurocode_2_group_2}))
			)
				and (not $is_a_further_processed_ingredient)
				and (not $further_processed)
		)
			or 0
	);
}

sub is_fruits_vegetables_legumes_for_fat_oil_nuts_seed ($ingredient_id, $processing = undef) {

	# for fat/oil/nuts/seeds products, oils of fruits and vegetables count for fruits and vegetables
	return (
		is_fruits_vegetables_legumes($ingredient_id, $processing)
			or (
			(
				   ($ingredient_id eq "en:olive-oil")
				or ($ingredient_id eq "en:avocado-oil")
			)
			)
			or 0
	);
}

=head2 estimate_nutriscore_2023_fruits_vegetables_legumes_percent_from_ingredients ( product_ref )

This function analyzes the ingredients to estimate the minimum percentage of
fruits, vegetables, legumes, so that we can compute the Nutri-Score (2023) fruit points.

Results are stored in $product_ref->{nutriments}{"fruits-vegetables-legumes-estimate-from-ingredients_100g"} (and _serving)

=cut

sub estimate_nutriscore_2023_fruits_vegetables_legumes_percent_from_ingredients ($product_ref) {

	# For fat/oil/nuts/seeds products, oils of fruits and vegetables count for fruits and vegetables
	my $matching_function_ref;
	if (is_fat_oil_nuts_seeds_for_nutrition_score($product_ref)) {
		$matching_function_ref = \&is_fruits_vegetables_legumes_for_fat_oil_nuts_seed;
	}
	else {
		$matching_function_ref = \&is_fruits_vegetables_legumes;
	}

	return estimate_ingredients_matching_function($product_ref, $matching_function_ref,
		"fruits-vegetables-legumes-estimate-from-ingredients",
	);
}

=head2 is_milk ( $ingredient_id, $processing = undef )

Determine if an ingredient should be counted as milk in Nutriscore 2021 algorithm

=cut

sub is_milk ($ingredient_id, $processing = undef) {

	return is_a("ingredients", $ingredient_id, "en:milk");
}

=head2 estimate_nutriscore_2021_milk_percent_from_ingredients ( product_ref )

This function analyzes the ingredients to estimate the percentage of milk in a product,
in order to know if a dairy drink should be considered as a food (at least 80% of milk) or a beverage.

Return value: estimated % of milk.

=cut

sub estimate_nutriscore_2021_milk_percent_from_ingredients ($product_ref) {

	return estimate_ingredients_matching_function($product_ref, \&is_milk);
}

=head2 is_red_meat ( $ingredient_id )

Determine if an ingredient should be counted as red meat in Nutriscore 2023 algorithm

=cut

sub is_red_meat ($ingredient_id, $ingredient_processing = undef) {

	my $red_meat_property = get_inherited_property("ingredients", $ingredient_id, "nutriscore_red_meat:en");
	if ((defined $red_meat_property) and ($red_meat_property eq "yes")) {
		return 1;
	}
	return 0;
}

=head2 estimate_nutriscore_2023_red_meat_percent_from_ingredients ( product_ref )

This function analyzes the ingredients to estimate the percentage of red meat,
so that we can determine if the maximum limit of 2 points for proteins
should be applied in the Nutri-Score 2023 algorithm.

=cut

sub estimate_nutriscore_2023_red_meat_percent_from_ingredients ($product_ref) {

	return estimate_ingredients_matching_function($product_ref, \&is_red_meat);
}

=head2 sub get_ingredients_with_property_value ($ingredients_ref, $property, $value)

Returns a list of ingredients that have a specific property value.

=cut

sub get_ingredients_with_property_value ($ingredients_ref, $property, $value) {

	my @matching_ingredients = ();

	foreach my $ingredient_ref (@{$ingredients_ref}) {

		my ($property_value, $matching_ingredient_id)
			= get_inherited_property_and_matching_tag("ingredients", $ingredient_ref->{id}, $property);
		if ((defined $property_value) and ($property_value eq $value)) {
			push @matching_ingredients, $matching_ingredient_id;
		}

		if (defined $ingredient_ref->{ingredients}) {
			push @matching_ingredients,
				get_ingredients_with_property_value($ingredient_ref->{ingredients}, $property, $value);
		}
	}

	return @matching_ingredients;
}

1;
