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

ProductOpener::Ingredients - process and analyze ingredients lists

=head1 SYNOPSIS

C<ProductOpener::IngredientsStrings> contains some strings and regular expressions used in C<ProductOpener::Ingredients>.

=head1 DESCRIPTION

[..]

=cut

package ProductOpener::IngredientsStrings;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(

		$middle_dot
		$commas
		$dashes
		$stops
		$cbrackets
		$obrackets
		$separators_except_comma
		$separators
		@symbols
		$symbols_regexp

		%may_contain_regexps
		%contains_regexps
		%contains_or_may_contain_regexps

		%abbreviations
		%of
		%from
		%and
		%and_of
		%and_or
		%the
		%per
		$one_hundred_grams_or_ml
		%of_finished_product

		%prepared_with
		%min_regexp
		%max_regexp
		%ignore_strings_after_percent
		%percent_or_quantity_regexps

		&init_percent_or_quantity_regexps
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

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
$middle_dot
	= qr/(?: \N{U+00B7} |\N{U+2022}|\N{U+2023}|\N{U+25E6}|\N{U+2043}|\N{U+204C}|\N{U+204D}|\N{U+2219}|\N{U+22C5}|\N{U+30FB})/i;

# Unicode category 'Punctuation, Dash', SWUNG DASH and MINUS SIGN
$dashes = qr/(?:\p{Pd}|\N{U+2053}|\N{U+2212})/i;

# ',' and synonyms - COMMA, SMALL COMMA, FULLWIDTH COMMA, IDEOGRAPHIC COMMA, SMALL IDEOGRAPHIC COMMA, HALFWIDTH IDEOGRAPHIC COMMA, ARABIC COMMA
$commas = qr/(?:\N{U+002C}|\N{U+FE50}|\N{U+FF0C}|\N{U+3001}|\N{U+FE51}|\N{U+FF64}|\N{U+060C})/i;

# '.' and synonyms - FULL STOP, SMALL FULL STOP, FULLWIDTH FULL STOP, IDEOGRAPHIC FULL STOP, HALFWIDTH IDEOGRAPHIC FULL STOP
$stops = qr/(?:\N{U+002E}|\N{U+FE52}|\N{U+FF0E}|\N{U+3002}|\N{U+FE61})/i;

# '(' and other opening brackets ('Punctuation, Open' without QUOTEs)
# U+201A "‚" (Single Low-9 Quotation Mark)
# U+201E "„" (Double Low-9 Quotation Mark)
# U+276E "❮" (Heavy Left-Pointing Angle Quotation Mark Ornament)
# U+2E42 "⹂" (Double Low-Reversed-9 Quotation Mark)
# U+301D "〝" (Reversed Double Prime Quotation Mark)
# U+FF08 "（" (Fullwidth Left Parenthesis) used in some countries (Japan)
$obrackets = qr/(?![\N{U+201A}|\N{U+201E}|\N{U+276E}|\N{U+2E42}|\N{U+301D}|\N{U+FF08}])[\p{Ps}]/i;

# ')' and other closing brackets ('Punctuation, Close' without QUOTEs)
# U+276F "❯" (Heavy Right-Pointing Angle Quotation Mark Ornament )
# U+301E "⹂" (Double Low-Reversed-9 Quotation Mark)
# U+301F "〟" (Low Double Prime Quotation Mark)
# U+FF09 "）" (Fullwidth Right Parenthesis) used in some countries (Japan)
$cbrackets = qr/(?![\N{U+276F}|\N{U+301E}|\N{U+301F}|\N{U+FF09}])[\p{Pe}]/i;

# U+FF0F "／" (Fullwidth Solidus) used in some countries (Japan)
$separators_except_comma = qr/(;|:|$middle_dot|\[|\{|\(|\N{U+FF08}|( $dashes ))|(\/|\N{U+FF0F})/i
	;    # separators include the dot . followed by a space, but we don't want to separate 1.4 etc.

$separators = qr/($stops\s|$commas|$separators_except_comma)/i;

# Symbols to indicate labels like organic, fairtrade etc.
@symbols = ('\*\*\*', '\*\*', '\*', '°°°', '°°', '°', '\(1\)', '\(2\)', '¹', '²');
$symbols_regexp = join('|', @symbols);

# do not add sub ( ) in the regexps below as it would change which parts gets matched in $1, $2 etc. in other regexps that use those regexps
# put the longest strings first, so that we can match "possible traces" before "traces"
%may_contain_regexps = (

	en =>
		"it may contain traces of|possible traces|traces|may also contain|also may contain|may contain|may be present|Produced in a factory handling",
	bg => "продуктът може да съдържа следи от|mоже да съдържа следи от|може да съдържа|може да съдържа следи от",
	bs => "može da sadrži",
	ca => "pot contenir",
	cs => "může obsahovat|může obsahovat stopy",
	da =>
		"produktet kan indeholde|kan også indeholde bestanddele fra|kan indeholde spor af|kan indeholde spor|eventuelle spor|kan indeholde|mulige spor",
	de => "Kann enthalten|Kann Spuren|Spuren|Kann Anteile|Anteile|Kann auch|Kann|Enthält möglicherweise",
	el => "Μπορεί να περιέχει ίχνη από",
	es => "puede contener huellas de|puede contener trazas de|puede contener|trazas|traza",
	et => "võib sisaldada vähesel määral|võib sisaldada|võib sisalda|osakesi",
	fi =>
		"saattaa sisältää pienehköjä määriä muita|saattaa sisältää pieniä määriä muita|saattaa sisältää pienehköjä määriä|saattaa sisältää myös pieniä määriä|saattaa sisältää pieniä määriä|voi sisältää vähäisiä määriä|saattaa sisältää hivenen|saattaa sisältää pieniä|saattaa sisältää jäämiä|sisältää pienen määrän|jossa käsitellään myös|saattaa sisältää myös|joka käsittelee myös|jossa käsitellään|saattaa sisältää",
	fr =>
		"peut également contenir|peut contenir|qui utilise|utilisant|qui utilise aussi|qui manipule|manipulisant|qui manipule aussi|traces possibles|traces d'allergènes potentielles|trace possible|traces potentielles|trace potentielle|traces éventuelles|traces eventuelles|trace éventuelle|trace eventuelle|traces|trace|Traces éventuelles de|Peut contenir des traces de",
	hr =>
		"mogući ostaci|mogući sadržaj|mogući tragovi|može sadržavati|može sadržavati alergene u tragovima|može sadržavati tragove|može sadržavati u tragovima|može sadržati|može sadržati tragove|proizvod može sadržavati|proizvod može sadržavati tragove",
	hu => "nyomokban|tartalmazhat",
	is => "getur innihaldið leifar|gæti innihaldið snefil|getur innihaldið",
	it =>
		"Pu[òo] contenere tracce di|pu[òo] contenere|che utilizza anche|possibili tracce|eventuali tracce|possibile traccia|eventuale traccia|tracce|traccia",
	lt => "sudėtyje gali būti|Taip pat, gali būti|gali būti|dalių",
	lv => "alergēni|kupātdesiņa var|pārpalikumi|produkts var|dalinas|sastāva var but|var saturé|var satur[ēé]t",
	mk => "Производот може да содржи|може да содржи",
	nl =>
		"Dit product kan sporen van|bevat mogelijk sporen van|Kan sporen bevatten van|Kan sporen van|bevat mogelijk|sporen van|Geproduceerd in ruimtes waar|Kan ook",
	nb =>
		"kan inneholde spor av|kan forekomme spor av|kan inneholde spor|kan forekomme spor|kan inneholde|kan forekomme",
	pl =>
		"może zawierać śladowe ilości|produkt może zawierać|może zawierać alergeny|może zawierać ślady|może zawierać|możliwa obecność|możliwa obecność|w produkcie możliwa obecność|wyprodukowano w zakładzie przetwarzającym",
	pt => "pode conter vestígios de|pode conter",
	ro => "poate con[țţt]ine urme de|poate con[țţt]ine|poate con[țţt]in|produsul poate conţine urme de",
	ru => "Могут содержаться следы",
	sk => "výrobok môže obsahovat|môže obsahovať",
	sl => "lahko vsebuje sledi|lahko vsebuje sledove",
	sr => "može sadržati tragove",
	sv =>
		"denna produkt kan innet?h[åa]lla sp[åa]r av|kan innehålla små mängder|kan innehålla spår av|innehåller spår av|kan innehålla spår|kan innehålla",
);

%contains_regexps = (

	en => "contains",
	bg => "съдържа",
	ca => "conté",
	cs => "obsahují",
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

%contains_or_may_contain_regexps = (
	allergens => \%contains_regexps,
	traces => \%may_contain_regexps,
);

# Abbreviations that contain dots.
# The dots interfere with the parsing: replace them with the full name.

%abbreviations = (

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

%of = (
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

%from = (
	en => " from ",
	da => " fra ",
	de => " aus ",
	es => " de ",
	fr => " de la | de | du | des | d'| de l'",
	hr => " iz ",
	it => " dal | della | dalla | dagli | dall'",
	nl => " uit ",
	pl => " z | ze ",
	sv => " från ",
);

%and = (
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

%and_of = (
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

%and_or = (
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

%the = (
	en => " the ",
	es => " el | la | los | las ",
	fr => " le | la | les | l'",
	it => " il | lo | la | i | gli | le | l'",
	nl => " de | het ",
);

# Strings to identify phrases like "75g per 100g of finished product"
%per = (
	en => " per | for ",
	da => " per ",
	es => " por | por cada ",
	fr => " pour | par ",
	hr => " na ",
	it => " per ",
	nl => " per ",
	sv => "((?: bär)|(?:\, varav tillsatt socker \\d+\\s*g))? per ",
);

$one_hundred_grams_or_ml = '100\s*(?:g|gr|ml)';

%of_finished_product = (
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
%prepared_with = (
	en => "(?:made|prepared|produced) with",
	da => "fremstillet af",
	es => "elabora con",
	fr => "(?:(?:é|e)labor(?:é|e)|fabriqu(?:é|e)|pr(?:é|e)par(?:é|e)|produit)(?:e)?(?:s)? (?:avec|à partir)",
	hr => "(?:proizvedeno od|sadrži)",
	nl => "bereid met",
	sv => "är",
);

%min_regexp = (
	en => "min|min\.|minimum",
	ca => "min|min\.|mín|mín\.|mínim|minim",
	cs => "min|min\.",
	es => "min|min\.|mín|mín\.|mínimo|minimo|minimum",
	fr => "min|min\.|mini|minimum",
	hr => "min|min\.|mini|minimum",
	pl => "min|min\.|minimum",
);

%max_regexp = (
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

%ignore_strings_after_percent = (
	en => "of (?:the )?(?:total weight|grain is wholegrain rye)",
	es => "(?:en el chocolate(?: con leche)?)",
	fi => "jauhojen määrästä",
	fr => "(?:dans le chocolat(?: (?:blanc|noir|au lait))?)|(?:du poids total|du poids)",
	sv => "fetthalt",
);

%percent_or_quantity_regexps = ();

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
			. $ignore_strings_after_percent
			. '|\s|\)|\]|\}|(?:'
			. $symbols_regexp
			. '))*';    # strings that can be ignored
	}

	return;
}

1;
