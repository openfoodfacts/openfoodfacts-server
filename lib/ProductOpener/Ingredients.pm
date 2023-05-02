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

	extract_ingredients_classes_from_text($product_ref);

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
		&extract_ingredients_from_image

		&separate_additive_class

		&split_generic_name_from_ingredients
		&clean_ingredients_text_for_lang
		&cut_ingredients_text_for_lang
		&clean_ingredients_text

		&detect_allergens_from_text

		&normalize_a_of_b
		&normalize_enumeration

		&extract_ingredients_classes_from_text

		&extract_ingredients_from_text
		&preparse_ingredients_text
		&parse_ingredients_text
		&analyze_ingredients
		&flatten_sub_ingredients
		&compute_ingredients_tags

		&compute_ingredients_percent_values
		&init_percent_values
		&set_percent_min_values
		&set_percent_max_values
		&delete_ingredients_percent_values
		&compute_ingredients_percent_estimates

		&add_fruits
		&estimate_nutriscore_fruits_vegetables_nuts_value_from_ingredients

		&add_milk
		&estimate_milk_percent_from_ingredients

		&has_specific_ingredient_property

		&init_origins_regexps
		&match_ingredient_origin
		&parse_origins_from_text

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;
use experimental 'smartmatch';

use ProductOpener::Store qw/:all/;
use ProductOpener::Config qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::TagsEntries qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::URL qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Lang qw/:all/;

use Encode;
use Clone qw(clone);

use LWP::UserAgent;
use Encode;
use JSON::PP;
use Log::Any qw($log);
use List::MoreUtils qw(uniq);
use Test::More;

# MIDDLE DOT with common substitutes (BULLET variants, BULLET OPERATOR and DOT OPERATOR (multiplication))
my $middle_dot
	= qr/(?:\N{U+00B7}|\N{U+2022}|\N{U+2023}|\N{U+25E6}|\N{U+2043}|\N{U+204C}|\N{U+204D}|\N{U+2219}|\N{U+22C5})/i;

# Unicode category 'Punctuation, Dash', SWUNG DASH and MINUS SIGN
my $dashes = qr/(?:\p{Pd}|\N{U+2053}|\N{U+2212})/i;

# ',' and synonyms - COMMA, SMALL COMMA, FULLWIDTH COMMA, IDEOGRAPHIC COMMA, SMALL IDEOGRAPHIC COMMA, HALFWIDTH IDEOGRAPHIC COMMA, ARABIC COMMA
my $commas = qr/(?:\N{U+002C}|\N{U+FE50}|\N{U+FF0C}|\N{U+3001}|\N{U+FE51}|\N{U+FF64}|\N{U+060C})/i;

# '.' and synonyms - FULL STOP, SMALL FULL STOP, FULLWIDTH FULL STOP, IDEOGRAPHIC FULL STOP, HALFWIDTH IDEOGRAPHIC FULL STOP
my $stops = qr/(?:\N{U+002E}|\N{U+FE52}|\N{U+FF0E}|\N{U+3002}|\N{U+FE61})/i;

# '(' and other opening brackets ('Punctuation, Open' without QUOTEs)
my $obrackets = qr/(?![\N{U+201A}|\N{U+201E}|\N{U+276E}|\N{U+2E42}|\N{U+301D}|\N{U+FF08}])[\p{Ps}]/i;
# ')' and other closing brackets ('Punctuation, Close' without QUOTEs)
my $cbrackets = qr/(?![\N{U+276F}|\N{U+301E}|\N{U+301F}|\N{U+FF09}])[\p{Pe}]/i;

my $separators_except_comma = qr/(;|:|$middle_dot|\[|\{|\(|( $dashes ))|(\/)/i
	;    # separators include the dot . followed by a space, but we don't want to separate 1.4 etc.

my $separators = qr/($stops\s|$commas|$separators_except_comma)/i;

# do not add sub ( ) in the regexps below as it would change which parts gets matched in $1, $2 etc. in other regexps that use those regexps
# put the longest strings first, so that we can match "possible traces" before "traces"
my %may_contain_regexps = (

	en =>
		"it may contain traces of|possible traces|traces|may also contain|also may contain|may contain|may be present",
	bg => "продуктът може да съдържа следи от|може да съдържа следи от|може да съдържа",
	bs => "može da sadrži",
	cs => "může obsahovat|může obsahovat stopy",
	da => "produktet kan indeholde|kan indeholde spor af|kan indeholde spor|eventuelle spor|kan indeholde|mulige spor",
	de => "Kann enthalten|Kann Spuren|Spuren",
	es => "puede contener huellas de|puede contener trazas de|puede contener|trazas|traza",
	et => "võib sisaldada vähesel määral|võib sisaldada|võib sisalda",
	fi =>
		"saattaa sisältää pienehköjä määriä muita|saattaa sisältää pieniä määriä muita|saattaa sisältää pienehköjä määriä|saattaa sisältää pieniä määriä|voi sisältää vähäisiä määriä|saattaa sisältää hivenen|saattaa sisältää pieniä|saattaa sisältää jäämiä|sisältää pienen määrän|jossa käsitellään myös|saattaa sisältää myös|joka käsittelee myös|jossa käsitellään|saattaa sisältää",
	fr =>
		"peut également contenir|peut contenir|qui utilise|utilisant|qui utilise aussi|qui manipule|manipulisant|qui manipule aussi|traces possibles|traces d'allergènes potentielles|trace possible|traces potentielles|trace potentielle|traces éventuelles|traces eventuelles|trace éventuelle|trace eventuelle|traces|trace",
	hr => "Mogući sadržaj|može sadržavati|može sadržavati tragove|može sadržati|proizvod može sadržavati|sadrži",
	is => "getur innihaldið leifar|gæti innihaldið snefil|getur innihaldið",
	it =>
		"Pu[òo] contenere tracce di|pu[òo] contenere|che utilizza anche|possibili tracce|eventuali tracce|possibile traccia|eventuale traccia|tracce|traccia",
	lt => "sudėtyje gali būti",
	lv => "var saturēt",
	nl =>
		"Dit product kan sporen van|bevat mogelijk sporen van|Kan sporen bevatten van|Kan sporen van|bevat mogelijk|sporen van",
	nb =>
		"kan inneholde spor av|kan forekomme spor av|kan inneholde spor|kan forekomme spor|kan inneholde|kan forekomme",
	pl => "może zawierać śladowe ilości|produkt może zawierać|może zawierać",
	pt => "pode conter vestígios de|pode conter",
	ro => "poate con[țţt]ine urme de|poate con[țţt]ine|poate con[țţt]in",
	ru => "Могут содержаться следы",
	sk => "Môže obsahovať",
	sv => "kan innehålla små mängder|kan innehålla spår av|innehåller spår av|kan innehålla spår|kan innehålla",
);

my %contains_regexps = (

	en => "contains",
	bg => "съдържа",
	da => "indeholder",
	es => "contiene",
	et => "sisaldab",
	fr => "contient",
	it => "contengono",
	nl => "bevat",
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

	da => [["bl. a.", "blandt andet"], ["inkl.", "inklusive"], ["mod.", "modificeret"], ["past.", "pasteuriserede"],],

	en => [
		["w/o", "without"],
		["w/", "with "],    # note trailing space
		["vit.", "vitamin"],
		["i.a.", "inter alia"],

	],

	es => [["vit.", "vitamina"],],

	fi => [["mikro.", "mikrobiologinen"], ["mm.", "muun muassa"], ["sis.", "sisältää"], ["n.", "noin"],],

	fr => [["vit.", "Vitamine"], ["Mat. Gr.", "Matières Grasses"],],

	hr => [["temp.", "temperaturi"],],

	nb => [["bl. a.", "blant annet"], ["inkl.", "inklusive"], ["papr.", "paprika"],],

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
	fr => " de la | de | du | des | d'",
	is => " af ",
	it => " di | d'",
	nl => " van ",
	nb => " av ",
	sv => " av ",
);

my %from = (
	en => " from ",
	fr => " de la | de | du | des | d'",
);

my %and = (
	en => " and ",
	ca => " i ",
	da => " og ",
	de => " und ",
	es => " y ",    # Spanish "e" before "i" and "hi" is handled by preparse_text()
	et => " ja ",
	fi => " ja ",
	fr => " et ",
	hr => " i ",
	is => " og ",
	it => " e ",
	lt => " ir ",
	lv => " un ",
	nl => " en ",
	nb => " og ",
	pl => " i ",
	pt => " e ",
	ro => " și ",
	ru => " и ",
	sv => " och ",
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
	is => " og | eða | og/eða | og / eða ",
	it => " e | o | e/o | e / o",
	nl => " en/of | en / of ",
	nb => " og | eller | og/eller | og / eller ",
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

# Labels that we want to recognize in the ingredients
# e.g. "fraises issues de l'agriculture biologique"

# Put composed labels like fair-trade-organic first
my @labels = (
	"en:fair-trade-organic", "en:organic", "en:fair-trade", "en:pgi", "en:pdo", "fr:label-rouge",
	"en:sustainable-seafood-msc", "en:responsible-aquaculture-asc",
	"fr:aoc", "en:vegan", "en:vegetarian"
);
my %labels_regexps = ();

# Needs to be called after Tags.pm has loaded taxonomies

=head1 FUNCTIONS

=head2 init_labels_regexps () - initialize regular expressions needed for ingredients parsing

This function creates regular expressions that match all variations of labels
that we want to recognize in ingredients lists, such as organic and fair trade.

=cut

sub init_labels_regexps() {

	foreach my $labelid (@labels) {

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
				# skip_entries_matching => '/^en:vitamins$/',
			}
		)
	};

	return;
}

if ((keys %labels_regexps) > 0) {exit;}

# load ingredients classes
opendir(DH, "$data_root/ingredients")
	or $log->error("cannot open ingredients directory", {path => "$data_root/ingredients", error => $!});

foreach my $f (readdir(DH)) {
	# Skip entry if its not a valid file
	next if $f eq '.';
	next if $f eq '..';
	next if ($f !~ /\.txt$/);

	# Remove file extension
	my $class = $f;
	$class =~ s/\.txt$//;

	$ingredients_classes{$class} = {};

	open(my $IN, "<:encoding(UTF-8)", "$data_root/ingredients/$f");
	while (<$IN>) {
		# Skip EOF and lines prefixed with #
		chomp;
		next if /^\#/;

		my ($canon_name, $other_names, $misc, $desc, $level, $warning) = split("\t");
		my $id = get_string_id_for_lang("no_language", $canon_name);
		next if (not defined $id) or ($id eq '');
		(not defined $level) and $level = 0;

		# additives: always set level to 0 right now, until we have a better list
		$level = 0;

		if (not defined $ingredients_classes{$class}{$id}) {
			# E322 before E322(i) : E322 should be associated with "lecithine"
			$ingredients_classes{$class}{$id} = {
				name => $canon_name,
				id => $id,
				other_names => $other_names,
				level => $level,
				description => $desc,
				warning => $warning
			};
		}
		#print STDERR "name: $canon_name\nother_names: $other_names\n";
		if (defined $other_names) {
			foreach my $other_name (split(/,/, $other_names)) {
				$other_name =~ s/^\s+//;
				$other_name =~ s/\s+$//;
				my $other_id = get_string_id_for_lang("no_language", $other_name);
				next if $other_id eq '';
				next if $other_name eq '';
				if (not defined $ingredients_classes{$class}{$other_id}) {    # Take the first one
					$ingredients_classes{$class}{$other_id} = {name => $other_name, id => $id};
					#print STDERR "$id\t$other_id\n";
				}
			}
		}
	}
	close $IN;

	$ingredients_classes_sorted{$class} = [sort keys %{$ingredients_classes{$class}}];
}
closedir(DH);

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

my %min_regexp = (
	en => "min|min\.|minimum",
	es => "min|min\.|mín|mín\.|mínimo|minimo|minimum",
	fr => "min|min\.|mini|minimum",
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

=head2 has_specific_ingredient_property ( product_ref, searched_ingredient_id, property )

Check if the specific ingredients structure (extracted from the end of the ingredients list and product labels)
contains a property for an ingredient. (e.g. do we have an origin specified for a specific ingredient)

=head3 Arguments

=head4 product_ref

=head4 searched_ingredient_id

If the ingredient_id parameter is undef, then we return the value for any specific ingredient.
(useful for products for which we do not have ingredients, but for which we have a label like "French eggs":
we can still derive the origin of the ingredients, e.g. for the Eco-Score)

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

Go through the ingredients structure, and ad properties to ingredients that match specific ingredients
for which we have extra information (e.g. origins from a label).

=cut

sub add_properties_from_specific_ingredients ($product_ref) {

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
			my $property_value = has_specific_ingredient_property($product_ref, $ingredientid, "origins");
			if ((defined $property_value) and (not defined $ingredient_ref->{$property})) {
				$ingredient_ref->{$property} = $property_value;
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

	my $product_lc = $product_ref->{lc};

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

=head2 parse_specific_ingredients_from_text ( product_ref, $text, $percent_regexp )

Lists of ingredients sometime include extra mentions for specific ingredients
at the end of the ingredients list. e.g. "Prepared with 50g of fruits for 100g of finished product".

This function extracts those mentions and adds them to the specific_ingredients structure.

This function is also used to parse the origins of ingredients field.

=head3 Arguments

=head4 product_ref

=head4 text $text

=head4 percent regular expression $percent_regexp

Used to find % values, language specific.

Pass undef in order to skip % recognition. This is useful if we know the text is only for the origins of ingredients.

=head3 Return values

=head4 specific_ingredients structure

Array of specific ingredients.

=head4 

=cut

sub parse_specific_ingredients_from_text ($product_ref, $text, $percent_regexp) {

	my $product_lc = $product_ref->{lc};

	# Go through the ingredient lists multiple times
	# as long as we have one match
	my $ingredient = "start";

	while ($ingredient) {

		# Initialize values
		$ingredient = undef;
		my $matched_ingredient_ref = {};
		my $matched_text;
		my $percent;
		my $origins;

		# Note: in regular expressions below, use non-capturing groups (starting with (?: )
		# for all groups, except groups that capture actual data: ingredient name, percent, origins

		# Regexps should match until we reach a . ; or the end of the text

		if ($product_lc eq "en") {
			# examples:
			# Total Milk Content 73%.

			if (
				(defined $percent_regexp)
				and ($text
					=~ /\s*(?:total |min |minimum )?([^,.;]+?)\s+content(?::| )+$percent_regexp\s*(?:per 100\s*(?:g)(?:[^,.;-]*?))?(?:;|\.| - |$)/i
				)
				)
			{
				$percent = $2;    # $percent_regexp
				$ingredient = $1;
				$matched_text = $&;
				# Remove the matched text
				$text = $` . ' ' . $';
			}

			# Origin of the milk: United Kingdom
			elsif (match_origin_of_the_ingredient_origin($product_lc, \$text, $matched_ingredient_ref)) {
				$origins = $matched_ingredient_ref->{origins};
				$ingredient = $matched_ingredient_ref->{ingredient};
				$matched_text = $matched_ingredient_ref->{matched_text};
				# Remove extra spaces
				$ingredient =~ s/\s+$//;
			}
		}
		elsif ($product_lc eq "fr") {

			# examples:
			# Teneur en lait 25% minimum.
			# Teneur en lactose < 0,01 g/100 g.
			# Préparée avec 50 g de fruits pour 100 g de produit fini.

			if (
				(defined $percent_regexp)
				and ($text
					=~ /\s*(?:(?:préparé|prepare)(?:e|s|es)? avec)(?: au moins)?(?::| )+$percent_regexp (?:de |d')?([^,.;]+?)\s*(?:pour 100\s*(?:g)(?:[^,.;-]*?))?(?:;|\.| - |$)/i
				)
				)
			{
				$percent = $1;    # $percent_regexp
				$ingredient = $2;
				$matched_text = $&;
				# Remove the matched text
				$text = $` . ' ' . $';
			}

			# Teneur totale en sucres : 60 g pour 100 g de produit fini.
			# Teneur en citron de 100%
			elsif (
				(defined $percent_regexp)
				and ($text
					=~ /\s*teneur(?: min| minimum| minimale| totale)?(?: en | de | d'| du )([^,.;]+?)\s*(?:pour 100\s*(?:g)(?: de produit(?: fini)?)?)?(?: de)?(?::| )+$percent_regexp\s*(?:pour 100\s*(?:g)(?:[^,.;]*?))?(?:;|\.| - |$)/i
				)
				)
			{
				$percent = $2;    # $percent_regexp
				$ingredient = $1;
				$matched_text = $&;
				# Remove the matched text
				$text = $` . ' ' . $';
			}

			# Origine du Cacao: Pérou
			elsif (match_origin_of_the_ingredient_origin($product_lc, \$text, $matched_ingredient_ref)) {
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
				= get_taxonomyid($product_lc, canonicalize_taxonomy_tag($product_lc, "ingredients", $ingredient));

			$matched_text =~ s/^\s+//;

			my $specific_ingredients_ref = {
				id => $ingredient_id,
				ingredient => $ingredient,
				text => $matched_text,
			};

			my $and_or = $and_or{$product_lc};
			defined $percent and $specific_ingredients_ref->{percent} = $percent + 0;
			defined $origins
				and $specific_ingredients_ref->{origins}
				= join(",", map {canonicalize_taxonomy_tag($product_lc, "origins", $_)} split(/,|$and_or/, $origins));

			push @{$product_ref->{specific_ingredients}}, $specific_ingredients_ref;
		}
	}

	return $text;
}

# Note: in regular expressions below, use non-capturing groups (starting with (?: )
# for all groups, except groups that capture actual data: ingredient name, percent, origins

# Regexps should match until we reach a . ; or the end of the text

sub match_ingredient_origin ($product_lc, $text_ref, $matched_ingredient_ref) {

	my $origins_regexp = $origins_regexps{$product_lc};
	my $and_or = $and_or{$product_lc} || ',';
	my $from = $from{$product_lc} || ':';

	# Strawberries: Spain, Italy and Portugal
	# Strawberries from Spain, Italy and Portugal
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
					canonicalize_taxonomy_tag($product_lc, "ingredients", $matched_ingredient_ref->{ingredient})
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
	return 0;
}

sub match_origin_of_the_ingredient_origin ($product_lc, $text_ref, $matched_ingredient_ref) {

	my %origin_of_the_regexp_in_lc = (
		en => "(?:origin of (?:the )?)",
		fr => "(?:origine (?:de |du |de la |des |de l'))",
	);

	my $origin_of_the_regexp = $origin_of_the_regexp_in_lc{$product_lc} || $origin_of_the_regexp_in_lc{en};
	my $origins_regexp = $origins_regexps{$product_lc};
	my $and_or = $and_or{$product_lc} || ',';

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

=head2 parse_origins_from_text ( product_ref, $text)

This function parses the origins of ingredients field to extract the origins of specific ingredients.
The origins are stored in the specific_ingredients structure of the product.

Note: this function is similar to parse_specific_ingredients_from_text() that operates on ingredients lists.
The difference is that parse_specific_ingredients_from_text() only extracts and recognizes text that is
an extra mention at the end of an ingredient list (e.g. "Origin of strawberries: Spain"),
while parse_origins_from_text() will also recognize text like "Strawberries: Spain".

=head3 Arguments

=head4 product_ref

=head4 text $text

=head3 Return values

=head4 specific_ingredients structure

Array of specific ingredients.

=head4 

=cut

sub parse_origins_from_text ($product_ref, $text) {

	my $product_lc = $product_ref->{lc};

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
			if ($match_function_ref->($product_lc, \$text, $matched_ingredient_ref)) {

				my $matched_text = $matched_ingredient_ref->{matched_text};
				my $ingredient = $matched_ingredient_ref->{ingredient};
				my $ingredient_id
					= get_taxonomyid($product_lc, canonicalize_taxonomy_tag($product_lc, "ingredients", $ingredient));

				# Remove extra spaces
				$ingredient =~ s/\s+$//;
				$matched_text =~ s/^\s+//;

				my $specific_ingredients_ref = {
					id => $ingredient_id,
					ingredient => $ingredient,
					text => $matched_text,
				};

				if (defined $matched_ingredient_ref->{origins}) {
					my $and_or = $and_or{$product_lc};
					$specific_ingredients_ref->{origins} = join(",",
						map {canonicalize_taxonomy_tag($product_lc, "origins", $_)}
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

=head2 parse_ingredients_text ( product_ref )

Parse the ingredients_text field to extract individual ingredients.

=head3 Return values

=head4 ingredients structure

Nested structure of ingredients and sub-ingredients

=head4 

=cut

sub parse_ingredients_text ($product_ref) {

	my $debug_ingredients = 0;

	delete $product_ref->{ingredients};

	return if ((not defined $product_ref->{ingredients_text}) or ($product_ref->{ingredients_text} eq ""));

	my $text = $product_ref->{ingredients_text};

	$log->debug("extracting ingredients from text", {text => $text}) if $log->is_debug();

	my $product_lc = $product_ref->{lc};

	$text = preparse_ingredients_text($product_lc, $text);

	$log->debug("preparsed ingredients from text", {text => $text}) if $log->is_debug();

	# Remove allergens and traces that have been preparsed
	# jus de pomme, eau, sucre. Traces possibles de c\x{e9}leri, moutarde et gluten.",
	# -> jus de pomme, eau, sucre. Traces éventuelles : céleri, Traces éventuelles : moutarde, Traces éventuelles : gluten.

	my $traces = $Lang{traces}{$product_lc};
	my $allergens = $Lang{allergens}{$product_lc};
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

	my $and = $and{$product_lc} || " and ";

	my $min_regexp = "";
	if (defined $min_regexp{$product_lc}) {
		$min_regexp = $min_regexp{$product_lc};
	}
	my $ignore_strings_after_percent = "";
	if (defined $ignore_strings_after_percent{$product_lc}) {
		$ignore_strings_after_percent = $ignore_strings_after_percent{$product_lc};
	}

	my $percent_regexp
		= '(?:<|'
		. $min_regexp
		. '|\s|\.|:)*(\d+(?:(?:\,|\.)\d+)?)\s*(?:\%|g)\s*(?:'
		. $min_regexp . '|'
		. $ignore_strings_after_percent
		. '|\s|\)|\]|\}|\*)*';

	# Extract phrases related to specific ingredients at the end of the ingredients list
	$text = parse_specific_ingredients_from_text($product_ref, $text, $percent_regexp);

	my $analyze_ingredients_function = sub ($analyze_ingredients_self, $ingredients_ref, $level, $s) {

		# print STDERR "analyze_ingredients level $level: $s\n";

		my $last_separator = undef;    # default separator to find the end of "acidifiants : E330 - E472"

		my $after = '';
		my $before = '';
		my $between = '';
		my $between_level = $level;
		my $percent = undef;
		my $origin = undef;
		my $labels = undef;
		my $vegan = undef;
		my $vegetarian = undef;
		my $processing = '';

		$debug_ingredients and $log->debug("analyze_ingredients_function", {string => $s}) if $log->is_debug();

		# find the first separator or ( or [ or :
		if ($s =~ $separators) {

			$before = $`;
			my $sep = $1;
			$after = $';

			$debug_ingredients
				and $log->debug("found the first separator",
				{string => $s, before => $before, sep => $sep, after => $after})
				if $log->is_debug();

			# If the first separator is a column : or a start of parenthesis etc. we may have sub ingredients

			if ($sep =~ /(:|\[|\{|\()/i) {

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

					$debug_ingredients and $log->debug("found sub-ingredients", {between => $between, after => $after})
						if $log->is_debug();

					# percent followed by a separator, assume the percent applies to the parent (e.g. tomatoes)
					# tomatoes (64%, origin: Spain)

					if (($between =~ $separators) and ($` =~ /^$percent_regexp$/i)) {

						$percent = $1;
						# remove what is before the first separator
						$between =~ s/(.*?)$separators//;
						$debug_ingredients
							and $log->debug("separator found after percent", {between => $between, percent => $percent})
							if $log->is_debug();
					}

					# sel marin (France, Italie)
					# -> if we have origins, put "origins:" before
					if (    ($between =~ $separators)
						and (exists_taxonomy_tag("origins", canonicalize_taxonomy_tag($product_lc, "origins", $`))))
					{
						$between =~ s/^(.*?$separators)/origins:$1/;
					}

					$debug_ingredients and $log->debug("initial processing of percent and origins",
						{between => $between, after => $after, percent => $percent})
						if $log->is_debug();

					# : is in $separators but we want to keep "origine : France" or "min : 23%"
					if (    ($between =~ $separators)
						and ($` !~ /\s*(origin|origins|origine|alkuperä|ursprung)\s*/i)
						and ($between !~ /^$percent_regexp$/i))
					{
						$between_level = $level + 1;
						$debug_ingredients and $log->debug("between contains a separator", {between => $between})
							if $log->is_debug();
					}
					else {
						# no separator found : 34% ? or single ingredient
						$debug_ingredients
							and $log->debug("between does not contain a separator", {between => $between})
							if $log->is_debug();

						if ($between =~ /^$percent_regexp$/i) {

							$percent = $1;
							$debug_ingredients
								and $log->debug("between is a percent", {between => $between, percent => $percent})
								if $log->is_debug();
							$between = '';
						}
						else {
							# label? (organic)
							# origin? (origine : France)

							# try to remove the origin and store it as property
							if ($between
								=~ /\s*(de origine|d'origine|origine|origin|origins|alkuperä|ursprung|oorsprong)\s?:?\s?\b(.*)$/i
								)
							{
								$between = '';
								my $origin_string = $2;
								# d'origine végétale -> not a geographic origin, add en:vegan
								if ($origin_string =~ /vegetal|végétal/i) {
									$vegan = "en:yes";
									$vegetarian = "en:yes";
								}
								else {
									$origin = join(",",
										map {canonicalize_taxonomy_tag($product_lc, "origins", $_)}
											split(/,/, $origin_string));
								}
							}
							else {

								# origins:   Fraise (France)
								my $originid = canonicalize_taxonomy_tag($product_lc, "origins", $between);
								if (exists_taxonomy_tag("origins", $originid)) {
									$origin = $originid;
									$debug_ingredients
										and
										$log->debug("between is an origin", {between => $between, origin => $origin})
										if $log->is_debug();
									$between = '';
								}
								# put origins first because the country can be associated with the label "Made in ..."
								# Skip too short entries (1 or 2 letters) to avoid false positives
								elsif (length($between) >= 3) {

									my $labelid = canonicalize_taxonomy_tag($product_lc, "labels", $between);
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
											= canonicalize_taxonomy_tag($product_lc, "ingredients_processing",
											$between);
										if (exists_taxonomy_tag("ingredients_processing", $processingid)) {
											if (defined $processing) {
												$processing .= ", " . $processingid;
											}
											else {
												$processing = ${$processingid};
											}
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

			if ($after =~ /^$percent_regexp($separators|$)/i) {
				$percent = $1;
				$after = $';
				$debug_ingredients
					and $log->debug("after started with a percent", {after => $after, percent => $percent})
					if $log->is_debug();
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

		$debug_ingredients and $log->debug("processed first separator",
			{string => $s, before => $before, between => $between, after => $after})
			if $log->is_debug();

		my @ingredients = ();

		# 2 known ingredients separated by "and" ?
		if ($before =~ /$and/i) {

			my $ingredient = $before;
			my $ingredient1 = $`;
			my $ingredient2 = $';

			# Remove percent

			my $ingredient1_orig = $ingredient1;
			my $ingredient2_orig = $ingredient2;

			$ingredient =~ s/\s$percent_regexp$//i;
			$ingredient1 =~ s/\s$percent_regexp$//i;
			$ingredient2 =~ s/\s$percent_regexp$//i;

			# check if the whole ingredient is an ingredient
			my $canon_ingredient = canonicalize_taxonomy_tag($product_lc, "ingredients", $before);

			$debug_ingredients and $log->debug(
				"ingredient contains 'and', checking if it exists",
				{before => $before, canon_ingredient => $canon_ingredient}
			) if $log->is_debug();

			if (not exists_taxonomy_tag("ingredients", $canon_ingredient)) {

				# otherwise check the 2 sub ingredients
				my $canon_ingredient1 = canonicalize_taxonomy_tag($product_lc, "ingredients", $ingredient1);
				my $canon_ingredient2 = canonicalize_taxonomy_tag($product_lc, "ingredients", $ingredient2);

				$debug_ingredients and $log->debug(
					"ingredient containing 'and' did not exist. 2 known ingredients?",
					{
						before => $before,
						canon_ingredient => $canon_ingredient,
						canon_ingredient1 => $canon_ingredient1,
						canon_ingredient2 => $canon_ingredient2
					}
				) if $log->is_debug();

				if (    (exists_taxonomy_tag("ingredients", $canon_ingredient1))
					and (exists_taxonomy_tag("ingredients", $canon_ingredient2)))
				{
					push @ingredients, $ingredient1_orig;
					push @ingredients, $ingredient2_orig;
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
					$between_level, $between
				);
			}

			if ($before !~ /^\s*$/) {

				push @ingredients, $before;
			}
		}

		my $i = 0;    # Counter for ingredients, used to know if it is the last ingredient

		foreach my $ingredient (@ingredients) {

			chomp($ingredient);

			$debug_ingredients and $log->debug("analyzing ingredient", {ingredient => $ingredient}) if $log->is_debug();

			# Repeat the removal of parts of the ingredient (that corresponds to labels, origins, processing, % etc.)
			# as long as we have removed something and that we haven't recognized the ingredient

			my $current_ingredient = '';
			my $skip_ingredient = 0;
			my $ingredient_recognized = 0;
			my $ingredient_id;

			while (($ingredient ne $current_ingredient) and (not $ingredient_recognized) and (not $skip_ingredient)) {

				$current_ingredient = $ingredient;

				# Strawberry 10.3%
				if ($ingredient =~ /\s$percent_regexp$/i) {
					$percent = $1;
					$debug_ingredients and $log->debug("percent found after",
						{ingredient => $ingredient, percent => $percent, new_ingredient => $`})
						if $log->is_debug();
					$ingredient = $`;
				}

				# 90% boeuf, 100% pur jus de fruit, 45% de matière grasses
				if (
					$ingredient =~ m{^
									 \s*
									 ( \d+ ([,.] \d+)? )
									 \s*
									 (\%|g)
									 \s*

									 ( (?: pur | de ) \s | d' )?
									 \s*
									}sxmi
					)
				{
					$percent = $1;
					$debug_ingredients and $log->debug("percent found before",
						{ingredient => $ingredient, percent => $percent, new_ingredient => $'})
						if $log->is_debug();
					$ingredient = $';
				}

				# remove * and other chars before and after the name of ingredients
				$ingredient =~ s/(\s|\*|\)|\]|\}|$stops|$dashes|')+$//;
				$ingredient =~ s/^(\s|\*|\)|\]|\}|$stops|$dashes|')+//;

				$ingredient =~ s/\s*(\d+((\,|\.)\d+)?)\s*\%\s*$//;

				# try to remove the origin and store it as property
				if ($ingredient =~ /\b(de origine|d'origine|origine|origin|alkuperä)\s?:?\s?\b/i) {
					$ingredient = $`;
					my $origin_string = $';
					# d'origine végétale -> not a geographic origin, add en:vegan
					if ($origin_string =~ /vegetal|végétal/i) {
						$vegan = "en:yes";
						$vegetarian = "en:yes";
					}
					else {
						$origin = join(",",
							map {canonicalize_taxonomy_tag($product_lc, "origins", $_)} split(/,/, $origin_string));
					}
				}

				# Check if we have an ingredient + some specific labels like organic and fair-trade.
				# If we do, remove the label from the ingredient and add the label to labels
				if (defined $labels_regexps{$product_lc}) {
					# start with uncomposed labels first, so that we decompose "fair-trade organic" into "fair-trade, organic"
					foreach my $labelid (reverse @labels) {
						my $regexp = $labels_regexps{$product_lc}{$labelid};
						$debug_ingredients and $log->trace("checking labels regexps",
							{ingredient => $ingredient, labelid => $labelid, regexp => $regexp})
							if $log->is_trace();
						if ((defined $regexp) and ($ingredient =~ /\b($regexp)\b/i)) {
							if (defined $labels) {
								$labels .= ", " . $labelid;
							}
							else {
								$labels = $labelid;
							}
							$ingredient = $` . ' ' . $';
							$ingredient =~ s/\s+/ /g;

							# If the ingredient is just the label + sub ingredients (e.g. "vegan (orange juice)")
							# then we replace the now empty ingredient by the sub ingredients
							if (($ingredient =~ /^\s*$/) and (defined $between) and ($between ne "")) {
								$ingredient = $between;
								$between = '';
							}
							$debug_ingredients
								and $log->debug("found label", {ingredient => $ingredient, labelid => $labelid})
								if $log->is_debug();
						}
					}
				}

				$ingredient =~ s/^\s+//;
				$ingredient =~ s/\s+$//;

				$ingredient_id = canonicalize_taxonomy_tag($product_lc, "ingredients", $ingredient);

				if (exists_taxonomy_tag("ingredients", $ingredient_id)) {
					$ingredient_recognized = 1;
					$debug_ingredients and $log->trace("ingredient recognized", {ingredient_id => $ingredient_id})
						if $log->is_trace();
				}
				else {

					$debug_ingredients and $log->trace("ingredient not recognized", {ingredient_id => $ingredient_id})
						if $log->is_trace();

					# Try to see if we have an origin somewhere
					# Build an array of origins / ingredients possibilities

					my @maybe_origins_ingredients = ();

					# California almonds
					if (($product_lc eq "en") and ($ingredient =~ /^(\S+) (.+)$/)) {
						push @maybe_origins_ingredients, [$1, $2];
					}
					# South Carolina black olives
					if (($product_lc eq "en") and ($ingredient =~ /^(\S+ \S+) (.+)$/)) {
						push @maybe_origins_ingredients, [$1, $2];
					}
					if (($product_lc eq "en") and ($ingredient =~ /^(\S+ \S+ \S+) (.+)$/)) {
						push @maybe_origins_ingredients, [$1, $2];
					}

					# Currently does not work: pitted California prunes

					# Oranges from Florida
					if (defined $from{$product_lc}) {
						my $from = $from{$product_lc};
						if ($ingredient =~ /^(.+)($from)(.+)$/i) {
							push @maybe_origins_ingredients, [$3, $1];
						}
					}

					foreach my $maybe_origin_ingredient_ref (@maybe_origins_ingredients) {

						my ($maybe_origin, $maybe_ingredient) = @{$maybe_origin_ingredient_ref};

						# skip origins that are too small (avoid false positives with country initials etc.)
						next if (length($maybe_origin) < 4);

						my $origin_id = canonicalize_taxonomy_tag($product_lc, "origins", $maybe_origin);
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
							$ingredient_id = canonicalize_taxonomy_tag($product_lc, "ingredients", $ingredient);
							last;
						}
					}

					# Try to remove ingredients processing "cooked rice" -> "rice"
					if (defined $ingredients_processing_regexps{$product_lc}) {
						my $matches = 0;
						my $new_ingredient = $ingredient;
						my $new_processing = '';
						my $matching = 1;    # remove prefixes / suffixes one by one
						while ($matching) {
							$matching = 0;
							foreach
								my $ingredient_processing_regexp_ref (@{$ingredients_processing_regexps{$product_lc}})
							{
								my $regexp = $ingredient_processing_regexp_ref->[1];
								$debug_ingredients and $log->trace("checking processing regexps",
									{new_ingredient => $new_ingredient, regexp => $regexp})
									if $log->is_trace();

								if (
									# match before or after the ingredient, require a space
									(
										#($product_lc =~ /^(en|es|it|fr)$/)
										(
											   ($product_lc eq 'bs')
											or ($product_lc eq 'cs')
											or ($product_lc eq 'en')
											or ($product_lc eq 'es')
											or ($product_lc eq 'fr')
											or ($product_lc eq 'hr')
											or ($product_lc eq 'it')
											or ($product_lc eq 'mk')
											or ($product_lc eq 'pl')
											or ($product_lc eq 'sl')
											or ($product_lc eq 'sr')
										)
										and ($new_ingredient =~ /(^($regexp)\b|\b($regexp)$)/i)
									)

									#  match before or after the ingredient, does not require a space
									or (    (($product_lc eq 'de') or ($product_lc eq 'nl') or ($product_lc eq 'hu'))
										and ($new_ingredient =~ /(^($regexp)|($regexp)$)/i))

									# match after the ingredient, does not require a space
									# match before the ingredient, require a space
									or (    ($product_lc eq 'fi')
										and ($new_ingredient =~ /(^($regexp)\b|($regexp)$)/i))
									)
								{
									$new_ingredient = $` . $';

									$debug_ingredients and $log->debug(
										"found processing",
										{
											ingredient => $ingredient,
											new_ingredient => $new_ingredient,
											processing => $ingredient_processing_regexp_ref->[0],
											regexp => $regexp
										}
									) if $log->is_debug();

									$matching = 1;
									$matches++;
									$new_processing .= ", " . $ingredient_processing_regexp_ref->[0];

									# remove starting or ending " and "
									# viande traitée en salaison et cuite -> viande et
									$new_ingredient =~ s/($and)+$//i;
									$new_ingredient =~ s/^($and)+//i;
									$new_ingredient =~ s/(\s|-)+$//;
									$new_ingredient =~ s/^(\s|-)+//;

									# Stop if we now have a known ingredient.
									# e.g. "jambon cru en tranches" -> keep "jambon cru".
									my $new_ingredient_id
										= canonicalize_taxonomy_tag($product_lc, "ingredients", $new_ingredient);

									if (exists_taxonomy_tag("ingredients", $new_ingredient_id)) {
										$debug_ingredients and $log->debug(
											"found existing ingredient, stop matching",
											{
												ingredient => $ingredient,
												new_ingredient => $new_ingredient,
												new_ingredient_id => $new_ingredient_id
											}
										) if $log->is_debug();

										$matching = 0;
									}

									last;
								}
							}
						}
						if ($matches) {

							my $new_ingredient_id
								= canonicalize_taxonomy_tag($product_lc, "ingredients", $new_ingredient);
							if (exists_taxonomy_tag("ingredients", $new_ingredient_id)) {
								$debug_ingredients and $log->debug(
									"found existing ingredient after removing processing",
									{
										ingredient => $ingredient,
										new_ingredient => $new_ingredient,
										new_ingredient_id => $new_ingredient_id
									}
								) if $log->is_debug();
								$ingredient = $new_ingredient;
								$ingredient_id = $new_ingredient_id;
								$ingredient_recognized = 1;
								$processing .= $new_processing;
							}
							else {
								$debug_ingredients and $log->debug(
									"did not find existing ingredient after removing processing",
									{
										ingredient => $ingredient,
										new_ingredient => $new_ingredient,
										new_ingredient_id => $new_ingredient_id
									}
								) if $log->is_debug();
							}
						}
					}

					# Unknown ingredient, check if it is a label
					# -> treat as a label only if there are no sub-ingredients
					if ((not $ingredient_recognized) and ($between eq "") and (length($ingredient) > 5)) {
						# Avoid matching single letters or too short abbreviations, bug #3300

						# We need to be careful with stopwords, "produit" was a stopword,
						# and "France" matched "produit de France" / made in France (bug #2927)
						my $label_id = canonicalize_taxonomy_tag($product_lc, "labels", $ingredient);
						if (exists_taxonomy_tag("labels", $label_id)) {

							# Add the label to the product
							add_tags_to_field($product_ref, $product_lc, "labels", $label_id);

							$ingredient_recognized = 1;

							# some labels are in fact ingredients. e.g. "sustainable palm oil"
							# in that case, add the corresponding ingredient

							my $label_ingredient_id = get_inherited_property("labels", $label_id, "ingredients:en");

							$debug_ingredients and $log->debug(
								"between is a known label",
								{between => $between, label => $label_id, label_ingredient_id => $label_ingredient_id}
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
									{ingredient => $ingredient, label_id => $label_id, ingredient_id => $ingredient_id}
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

							'de' => ['^in ver[äa]nderlichen Gewichtsanteilen$', '^Unter Schutzatmosph.re verpackt$',],

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
								'(sur|de) produit fini',    # préparé avec 50g de fruits pour 100g de produit fini
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
								'^Valmistettu (?:myllyssä|tehtaassa)', # Valmistettu myllyssä, jossa käsitellään vehnää.
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
								'označene podebljano',    # marked in bold
								'savjet kod alergije',    # allergy advice
								'uključujući žitarice koje sadrže gluten',    # including grains containing gluten
								'za alergene',    # for allergens
							],

							'it' => ['^in proporzion[ei] variabil[ei]$',],

							'nb' => ['^Pakket i beskyttende atmosfære$',],

							'nl' => [
								'^allergie.informatie$', 'in wisselende verhoudingen',
								'harde fractie', 'o\.a\.',
								'en',
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
								'^Fruktmängd \d+\s*g per$',
								'^Kakaohalt i chokladen$',
								'varierande proportion',
								'^total mängd socker',
								'kan innehålla ben$',
								'^per 100 g sylt$',
								'^Kakao minst',
								'^fetthalt',
							],

						);
						if (defined $ignore_regexps{$product_lc}) {
							foreach my $regexp (@{$ignore_regexps{$product_lc}}) {
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
				}
			}

			if (not $skip_ingredient) {

				my %ingredient = (
					id => get_taxonomyid($product_ref->{lc}, $ingredient_id),
					text => $ingredient
				);

				if (defined $percent) {
					$ingredient{percent} = $percent + 0;
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

				if ($processing ne "") {
					$processing =~ s/^,\s?//;
					$ingredient{processing} = $processing;
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

							if ($i == $#ingredients) {
								$ingredient{ingredients} = [];
								$analyze_ingredients_self->(
									$analyze_ingredients_self, $ingredient{ingredients},
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
			$analyze_ingredients_self->($analyze_ingredients_self, $ingredients_ref, $level, $after);
		}

	};

	$analyze_ingredients_function->($analyze_ingredients_function, $product_ref->{ingredients}, 0, $text);

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
			"ingredients_tags, ingredients_original_tags", "ingredients_n",
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

	while (@ingredients) {

		my $ingredient_ref = shift @ingredients;

		push @{$product_ref->{ingredients_tags}}, $ingredient_ref->{id};

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

	my $field = "ingredients";

	$product_ref->{ingredients_original_tags} = $product_ref->{ingredients_tags};

	if (defined $taxonomy_fields{$field}) {
		$product_ref->{$field . "_hierarchy"} = [
			gen_ingredients_tags_hierarchy_taxonomy(
				$product_ref->{lc}, join(", ", @{$product_ref->{ingredients_original_tags}})
			)
		];
		$product_ref->{$field . "_tags"} = [];
		my $unknown = 0;
		my $known = 0;
		foreach my $tag (@{$product_ref->{$field . "_hierarchy"}}) {
			my $tagid = get_taxonomyid($product_ref->{lc}, $tag);
			push @{$product_ref->{$field . "_tags"}}, $tagid;
			if (exists_taxonomy_tag("ingredients", $tagid)) {
				$known++;
			}
			else {
				$unknown++;
			}
		}
		$product_ref->{"known_ingredients_n"} = $known;
		$product_ref->{"unknown_ingredients_n"} = $unknown;
	}

	if ($product_ref->{ingredients_text} ne "") {

		$product_ref->{ingredients_n} = scalar @{$product_ref->{ingredients_original_tags}};

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

- parse_ingredients_text() to parse the ingredients text in the main language of the product
to extract individual ingredients and sub-ingredients

- compute_ingredients_percent_values() to create the ingredients array with nested sub-ingredients arrays

- compute_ingredients_tags() to create a flat array ingredients_original_tags and ingredients_tags (with parents)

- analyze_ingredients() to analyze ingredients to see the ones that are vegan, vegetarian, from palm oil etc.
and to compute the resulting value for the complete product

=cut

sub extract_ingredients_from_text ($product_ref) {

	delete $product_ref->{ingredients_percent_analysis};

	# The specific ingredients array will contain indications regarding the percentage,
	# origins, labels etc. of specific ingredients. Those information may come from:
	# - the origin of ingredients field ("origin")
	# - labels (e.g. "British eggs")
	# - the end of the list of the ingredients. e.g. "Origin of the rice: Thailand"

	$product_ref->{specific_ingredients} = [];

	# Ingredients origins may be listed in the origin field
	# e.g. "Origin of the rice: Thailand."
	my $product_lc = $product_ref->{lc};
	if (defined $product_ref->{"origin_" . $product_lc}) {
		parse_origins_from_text($product_ref, $product_ref->{"origin_" . $product_lc});
	}

	# Add specific ingredients from labels
	add_specific_ingredients_from_labels($product_ref);

	# Parse the ingredients list to extract individual ingredients and sub-ingredients
	# to create the ingredients array with nested sub-ingredients arrays

	parse_ingredients_text($product_ref);

	if (defined $product_ref->{ingredients}) {

		# Add properties like origins from specific ingredients extracted from labels or the end of the ingredients list
		add_properties_from_specific_ingredients($product_ref);

		# Compute minimum and maximum percent ranges for each ingredient and sub ingredient

		if (compute_ingredients_percent_values(100, 100, $product_ref->{ingredients}) < 0) {

			# The computation yielded seemingly impossible values, delete the values
			delete_ingredients_percent_values($product_ref->{ingredients});
			$product_ref->{ingredients_percent_analysis} = -1;
		}
		else {
			$product_ref->{ingredients_percent_analysis} = 1;
		}

		compute_ingredients_percent_estimates(100, $product_ref->{ingredients});

		estimate_nutriscore_fruits_vegetables_nuts_value_from_ingredients($product_ref);

	}

	# Keep the nested list of sub-ingredients, but also copy the sub-ingredients at the end for apps
	# that expect a flat list of ingredients

	compute_ingredients_tags($product_ref);

	# Analyze ingredients to see the ones that are vegan, vegetarian, from palm oil etc.
	# and compute the resulting value for the complete product

	analyze_ingredients($product_ref);

	# Delete specific ingredients if empty
	if ((exists $product_ref->{specific_ingredients}) and (scalar @{$product_ref->{specific_ingredients}} == 0)) {
		delete $product_ref->{specific_ingredients};
	}

	return;
}

=head2 delete_ingredients_percent_values ( ingredients_ref )

This function deletes the percent_min and percent_max values of all ingredients.

It is called if the compute_ingredients_percent_values() encountered impossible
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

=head2 compute_ingredients_percent_values ( total_min, total_max, ingredients_ref )

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

sub compute_ingredients_percent_values ($total_min, $total_max, $ingredients_ref) {

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
				"compute_ingredients_percent_values - too many loops, bail out",
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
		"compute_ingredients_percent_values - done",
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

	my $percent_mode = "absolute";

	# Assume that percent listed is relative to the parent ingredient
	# if the sum of specified percents for the ingredients is greater than the percent max of the parent.

	my $percent_sum = 0;
	foreach my $ingredient_ref (@{$ingredients_ref}) {
		if (defined $ingredient_ref->{percent}) {
			$percent_sum += $ingredient_ref->{percent};
		}
	}

	if ($percent_sum > $total_max) {
		$percent_mode = "relative";
	}

	$log->debug(
		"init_percent_values - percent mode",
		{
			percent_mode => $percent_mode,
			ingredients_ref => $ingredients_ref,
			total_min => $total_min,
			total_max => $total_max,
			percent_sum => $percent_sum
		}
	) if $log->is_debug();

	# Go through each ingredient to set percent_min, percent_max, and if we can an absolute percent

	foreach my $ingredient_ref (@{$ingredients_ref}) {
		if (defined $ingredient_ref->{percent}) {
			# There is a specified percent for the ingredient.

			if (($percent_mode eq "absolute") or ($total_min == $total_max)) {
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

			$changed += compute_ingredients_percent_values(
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

The sum of all estimates must be 100%, and the estimates try to match the min and max constraints computed previously with the compute_ingredients_percent_values() function.

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

=head2 analyze_ingredients ( product_ref )

This function analyzes ingredients to see the ones that are vegan, vegetarian, from palm oil etc.
and computes the resulting value for the complete product.

The results are overrode by labels like "Vegan", "Vegetarian" or "Palm oil free"

Results are stored in the ingredients_analysis_tags array.

=cut

sub analyze_ingredients ($product_ref) {

	delete $product_ref->{ingredients_analysis};
	delete $product_ref->{ingredients_analysis_tags};

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

				# Vegetable oil (rapeseed oil, ...) : ignore "from_palm_oil:en:maybe" if the ingredient has sub-ingredients
				if (    ($property eq "from_palm_oil")
					and (defined $value)
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

				# In all cases, keep track of unknown ingredients so that we can display unknown ingredients
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

# English: oil, olive -> olive oil
# French: huile, olive -> huile d'olive
# Russian: масло растительное, пальмовое -> масло растительное оливковое

sub normalize_a_of_b ($lc, $a, $b) {

	$a =~ s/\s+$//;
	$b =~ s/^\s+//;

	if ($lc eq "en") {
		return $b . " " . $a;
	}
	elsif ($lc eq "es") {
		return $a . " de " . $b;
	}
	elsif ($lc eq "fr") {
		$b =~ s/^(de |d')//;

		if ($b =~ /^(a|e|i|o|u|y|h)/i) {
			return $a . " d'" . $b;
		}
		else {
			return $a . " de " . $b;
		}
	}
	elsif ($lc eq "ru") {
		return $a . " " . $b;
	}
}

# Vegetal oil (palm, sunflower and olive)
# -> palm vegetal oil, sunflower vegetal oil, olive vegetal oil

sub normalize_enumeration ($lc, $type, $enumeration) {

	$log->debug("normalize_enumeration", {type => $type, enumeration => $enumeration}) if $log->is_debug();

	# If there is a trailing space, save it and output it
	my $trailing_space = "";
	if ($enumeration =~ /\s+$/) {
		$trailing_space = " ";
	}

	my $and = $Lang{_and_}{$lc};
	#my $enumeration_separators = $obrackets . '|' . $cbrackets . '|\/| \/ | ' . $dashes . ' |' . $commas . ' |' . $commas. '|'  . $Lang{_and_}{$lc};

	my @list = split(/$obrackets|$cbrackets|\/| \/ | $dashes |$commas |$commas|$and/i, $enumeration);

	return join(", ", map {normalize_a_of_b($lc, $type, $_)} @list) . $trailing_space;
}

# iodure et hydroxide de potassium
sub normalize_fr_a_et_b_de_c ($a, $b, $c) {

	return normalize_fr_a_de_b($a, $c) . ", " . normalize_fr_a_de_b($b, $c);
}

sub normalize_additives_enumeration ($lc, $enumeration) {

	$log->debug("normalize_additives_enumeration", {enumeration => $enumeration}) if $log->is_debug();

	my $and = $Lang{_and_}{$lc};

	my @list = split(/$obrackets|$cbrackets|\/| \/ | $dashes |$commas |$commas|$and/i, $enumeration);

	return join(", ", map {"E" . $_} @list);
}

sub normalize_vitamin ($lc, $a) {

	$log->debug("normalize vitamin", {vitamin => $a}) if $log->is_debug();
	$a =~ s/\s+$//;
	$a =~ s/^\s+//;

	# does it look like a vitamin code?
	if ($a =~ /^[a-z][a-z]?-? ?\d?\d?$/i) {
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

	my $and = $Lang{_and_}{$lc};

	# The ?: makes the group non-capturing, so that the split does not create an extra item for the group
	my @vitamins = split(/(?:\(|\)|\/| \/ | - |, |,|$and)+/i, $vitamins_list);

	$log->debug("splitting vitamins", {vitamins_list => $vitamins_list, vitamins => \@vitamins}) if $log->is_debug();

	# first output "vitamines," so that the current additive class is set to "vitamins"
	my $split_vitamins_list;

	if ($lc eq 'da' || $lc eq 'nb' || $lc eq 'sv') {$split_vitamins_list = "vitaminer"}
	elsif ($lc eq 'de' || $lc eq 'it') {$split_vitamins_list = "vitamine"}
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

	my $and = $Lang{_and_}{$lc};

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

	da => ['ingredienser', 'indeholder',],

	de => ['Zusammensetzung', 'zutat(en)?',],

	el => ['Συστατικά',],

	en => ['composition', 'ingredient(s?)',],

	es => ['composición', 'ingredientes',],

	et => ['koostisosad',],

	fi => ['aine(?:kse|s?osa)t(?:\s*\/\s*ingredienser)?', 'ainesosia', 'valmistusaineet', 'koostumus',],

	fr => [
		'ingr(e|é)dient(s?)',
		'Quels Ingr(e|é)dients ?',    # In Casino packagings
		'composition',
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

	nl => ['ingredi(e|ë)nten', 'samenstelling', 'bestanddelen',],

	nb => ['Ingredienser',],

	pl => ['sk[łl]adniki', 'skład',],

	pt => ['ingredientes', 'composição',],

	ro => ['(I|i)ngrediente', 'compoziţie',],

	ru => ['состав', 'coctab', 'Ингредиенты',],

	si => ['sestavine',],

	sk => ['obsahuje', 'zloženie',],

	sl => ['vsebuje', '(S|s)estavine',],

	sq => ['P[eë]rb[eë]r[eë]sit',],

	sr => ['Sastojci',],

	sv => ['ingredienser', 'innehåll(er)?',],

	tg => ['Таркиб',],

	th => ['ส่วนประกอบ', 'ส่วนประกอบที่สำคัญ',],

	tr => ['(İ|i)çindekiler',],

	uz => ['tarkib',],

	zh => ['配料', '成份',],

);

# INGREDIENTS followed by lowercase list of ingredients

my %phrases_before_ingredients_list_uppercase = (

	en => ['INGREDIENT(S)?',],

	cs => ['SLOŽENÍ',],

	da => ['INGREDIENSER',],

	de => ['ZUTAT(EN)?',],

	el => ['ΣΥΣΤΑΤΙΚΑ'],

	es => ['INGREDIENTE(S)?',],

	fi => ['AINE(?:KSE|S?OSA)T(?:\s*\/\s*INGREDIENSER)?', 'VALMISTUSAINEET',],

	fr => ['INGR(E|É)(D|0|O)IENTS',],

	hu => ['(Ö|O|0)SSZETEVOK',],

	is => ['INNIHALD(?:SLÝSING|SEFNI)?', 'INNEALD',],

	it => ['INGREDIENTI(\s*)',],

	nb => ['INGREDIENSER',],

	nl => ['INGREDI(E|Ë)NTEN(\s*)',],

	nl => ['INGREDIENSER',],

	pl => ['SKŁADNIKI(\s*)',],

	pt => ['INGREDIENTES(\s*)',],

	ru => ['COCTАB',],

	si => ['SESTAVINE',],

	sv => ['INGREDIENSER', 'INNEHÅLL(ER)?',],

	uz => ['ІHГРЕДІЄНТИ',],

	uz => ['TARKIB',],

	vi => ['TH(A|À)NH PH(A|Â)N',],

);

my %phrases_after_ingredients_list = (

	# TODO: Introduce a common list for kcal

	bg => [
		'да се съхранява (в закрити|на сухо)',    # store in ...
	],

	cs => ['doporučeny způsob přípravy', 'V(ý|y)(ž|z)ivov(e|é) (ú|u)daje ve 100 g',],

	da => [
		'(?:gennemsnitlig )?n(æ|ae)rings(?:indhold|værdi|deklaration)',
		'tilberedning(?:svejledning)?',
		'holdbarhed efter åbning',
		'opbevar(?:ing|res)?',
		'(?:for )?allergener',
		'produceret af',
		'beskyttes', 'nettovægt', 'åbnet',
	],

	de => [
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
		'Kakao: \d\d\s?% mindestens.',
		'N(â|a|ä)hrwert(angaben|angabe|information|tabelle)',    #Nährwertangaben pro 100g
		'N(â|a|ä)hrwerte je',
		'Nâhrwerte',
		'(Ungeöffnet )?mindestens',
		'(k[uü]hl|bei Zimmertemperatur) und trocken lagern',
		'Rinde nicht zum Verzehr geeignet.',
		'Vor W(â|a|ä)rme und Feuchtigkeit sch(u|ü)tzen',
		'Unge(ö|o)ffnet bei max.',
		'Unter Schutzatmosphäre verpackt',
		'verbrauchen bis',
		'Vor Wärme geschützt (und trocken )?lagern',
		'Vorbereitung Tipps',
		'zu verbrauchen bis',
		'100 (ml|g) enthalten durchschnittlich',
		'\d\d\d\sg\s\w*\swerden aus\s\d\d\d\sg\s\w*\shergestellt'
		,    # 100 g Salami werden aus 120 g Schweinefleisch hergestellt.
	],

	el => [
		'ΔΙΑΘΡΕΠΤΙΚΗ ΕΠΙΣΗΜΑΝΣΗ',    #Nutritional labelling
		'ΔΙΤΡΟΦΙΚΕΣ ΠΗΡΟΦΟΡΙΕΣ',
	],

	en => [
		'after opening',
		'nutrition(al)? (as sold|facts|information|typical|value[s]?)',
		# "nutrition advice" seems to appear before ingredients rather than after.
		# "nutritional" on its own would match the ingredient "nutritional yeast" etc.
		'of whlch saturates',
		'of which saturates',
		'of which saturated fat',
		'((\d+)(\s?)kJ\s+)?(\d+)(\s?)kcal',
		'once opened[,]? (consume|keep|refrigerate|store|use)',
		'(Storage( instructions)?[: ]+)?Store in a cool[,]? dry place',
		'(dist(\.)?|distributed|sold)(\&|and|sold| )* (by|exclusively)',
		#'Best before',
		#'See bottom of tin',
	],

	es => [
		'valores nutricionales',
		'modo de preparacion',
		'informaci(o|ô)n nutricional',
		'valor energ(e|é)tico',
		'condiciones de conservaci(o|ó)n',
		#'pa(i|í)s de transformaci(o|ó)n',
		'cons[eé]rv(ar|ese) en( un)? lug[ae]r (fresco y seco|seco y fresco)',
		'de los cuates az(u|ü)cares',
		'de las cuales saturadas',
		'protegido de la luz',
		'conser(y|v)ar entre',
		'una vez abierto',
		'conservaci(o|ó)n:',
		'consumi preferentemente antes del',
		'consumir preferentemente antes del',
		#Envasado por:
	],

	et => [
		'parim enne',    # best before
	],

	fi => [
		'100 g:aan tuotetta käytetään',
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
		'conservation[ ]?:',
		'Croûte en matière plastique non comestible',
		'dans le compartiment (a|à) gla(c|ç)ons',
		'de préférence avant le',
		'dont sucres',
		'dont acides (gras|ras) satur(e|é)s',
		'Fabriquee à partir de fruits entiers',
		'Fabriqué dans un atelier qui utilise',
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
		'pr(e|é)paration au four',
		'Prépar(e|é)e? avec',
		'(produit )?(a|à) protéger de ',    # humidité, chaleur, lumière etc.
		'(produit )?conditionn(e|é) sous atmosph(e|è)re protectrice',
		'N(o|ò)us vous conseillons',
		'Non ouvert,',
		'Sans conservateur',
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
		'bez konzervans',    # without preservatives
		'Čuvati na (hladnom|sobnoj temperaturi|suhom|temperaturi)',    # store in...
		'Čuvati zatvoreno na',
		'Čuvati pri sobnoj temperaturi',
		'izvor dijetalnih vlakana',    # source of proteins
		'najbolje upotrijebiti do',    # best before
		'nakon otvaranja',    # after opening
		'pakirano u (kontroliranoj|zaštitnoj) atmosferi',    # packed in a ... atmosphere
		'proizvod je termički obrađen-pasteriziran',    # pasteurized
		'proizvođač',    # producer
		'prosječn(a|e) (hranjiva|hranjive|nutritivne) (vrijednost|vrijednosti)',    # Average nutritional value
		'protresti prije otvaranja',    # shake before opening
		'upotrijebiti do datuma',    # valid until
		'upozorenje',    # warning
		'uputa',    # instructions
		'uvjeti čuvanja',    # storage conditions
		'uvoznik za',    # importer
		'vakuumirana',    # Vacuumed
		'vrijeme kuhanja',    # Cooking time
		'zaštićena oznaka zemljopisnog podrijetla',    # ZOI/PDO
		'zbog (mutan|prisutnosti)',    # Due to ...
		'zemlja (porijekla|podrijetla|porekla)',    # country of origin
	],

	hu => [
		'Atlagos tápérték 100g termékben',
		'((száraz|hűvös|(közvetlen )?napfénytől védett)[, ]*)+helyen tárolandó',    # store in cool/dry/etc
	],

	is => ['n(æ|ae)ringargildi', 'geymi(st|ð) á', 'eftir opnum', 'aðferð',],

	it => [
		'valori nutrizionali',
		'consigli per la preparazione',
		'di cui zuccheri',
		'Valori nutritivi',
		'Conservare in luogo fresco e asciutto',
		'MODALITA D\'USO',
		'MODALITA DI CONSERVAZIONE',
		'Preparazione:',
		'Una volta aperto',    # once opened...
		'Da consumarsi preferibilmente entro',    # best before
	],

	ja => [
		'栄養価',    # nutritional value
		'内容量',    # weight
		'賞味期限',    # best before
	],

	lt => [
		'geriausias iki',    # best before
	],

	nb => ['netto(?:innhold|vekt)', 'oppbevar(?:ing|es)', 'næringsinnhold', 'kjølevare',],

	nl => [
		'bereid met',
		'Beter Leven keurmerk 1 ster.',
		'Beter Leven keurmerk 3 sterren',
		'Bewaren bij kamertemperatuur',
		'Cacao: ten minste ',
		'Droog bewaren',
		'E = door EU goedgekeurde hulpstof.',
		'E door EU goedgekeurde hulpstoffen',
		'"E"-nummers zijn door de EU goedgekeurde hulpstoffen',
		'gemiddelde voedingswaarden',
		'Gemiddeldevoedingswaardel',
		'gemiddelde voedingswaarde per 100 g',
		'Na openen beperkt houdbaar',
		'Ongeopend, ten minste houdbaar tot:',
		'o.a.',
		'ten minste',
		'ten minste houdbaar tot',
		'Van nature rijk aan vezels',
		'Verpakt onder beschermende atmosfeer',
		'voedingswaarden',
		'voedingswaarde',
		'Voor allergenen: zie ingrediëntenlijst, in vet gemarkeerd',
		'voorbereidingstips',
		#'waarvan suikers',
		'Witte chocolade: ten minste',
	],

	pl => [
		'przechowywać w chlodnym i ciemnym miejscu',    #keep in a dry and dark place
		'n(a|o)jlepiej spożyć przed',    #Best before
		'Przechowywanie',
	],

	pt => [
		'conservar em local (seco e )?fresco',
		'conservar em lugar fresco',
		'dos quais a(ç|c)(u|ü)ares',
		'dos quais a(ç|c)(u|ü)cares',
		'informa(ç|c)(a|ã)o nutricional',
		'modo de prepara(ç|c)(a|ã)o',
		'a consumir de prefer(e|ê)ncia antes do',
		'consumir de prefer(e|ê)ncia antes do',
	],

	ro => [
		'declaratie nutritional(a|ă)',
		'a si pastra la frigider dup(a|ă) deschidere',
		'a se agita inainte de deschidere',
		'Valori nutritionale medii',
		'a se p[ăa]stra la',    # store in...
	],

	sv => [
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

	vi => ['GI(Á|A) TR(Ị|I) DINH D(Ư|U)(Ỡ|O)NG (TRONG|TRÊN)',],
);

# turn demi - écrémé to demi-écrémé
my %prefixes_before_dash = (fr => ['demi', 'saint',],);

# phrases that can be removed
my %ignore_phrases = (
	de => [
		'\d\d?\s?%\sFett\si(\.|,)\s?Tr(\.|,)?',    # 45 % Fett i.Tr.
		"inklusive",
	],
	en => ["na|n/a|not applicable",],
	fr => ["non applicable|non concerné",],

);

=head2 validate_regular_expressions ( )

This function is used to check that all regular expressions / parts of
regular expressions used to parse ingredients are valid, without
unmatched parenthesis etc.

=cut

sub validate_regular_expressions() {

	my %regexps = (
		phrases_before_ingredients_list => \%phrases_before_ingredients_list,
		phrases_before_ingredients_list_uppercase => \%phrases_before_ingredients_list_uppercase,
		phrases_after_ingredients_list => \%phrases_after_ingredients_list,
		prefixes_before_dash => \%prefixes_before_dash,
		ignore_phrases => \%ignore_phrases,
	);

	foreach my $list (sort keys %regexps) {

		foreach my $language (sort keys %{$regexps{$list}}) {

			foreach my $regexp (@{$regexps{$list}{$language}}) {
				$log->debug("validate_regular_expressions", {list => $list, l => $language, regexp => $regexp})
					if $log->is_debug();
				eval {"test" =~ /$regexp/;};
				is($@, "");
			}
		}
	}

	return;
}

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
			if ($text =~ /\s*\b$regexp\b(.*)$/is) {
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
			$text =~ s/^\s*($regexp)(\.)?\s*$//is;
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

				if ($language eq $product_ref->{lc}) {
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
sub separate_additive_class ($product_lc, $additive_class, $spaces, $colon, $after) {

	my $and = $and{$product_lc} || " and ";

	# check that we have an additive after the additive class
	# keep only what is before the first separator
	$after =~ s/^$separators+//;
	#print STDERR "separate_additive_class - after 1 : $after\n";
	$after =~ s/^(.*?)$separators(.*)$/$1/;
	#print STDERR "separate_additive_class - after 2 : $after\n";

	# also look if we have additive 1 and additive 2
	my $after2;
	if ($after =~ /$and/i) {
		$after2 = $`;
	}

	# also check that we are not separating an actual ingredient
	# e.g. acide acétique -> acide : acétique

	if (
		(
			not exists_taxonomy_tag(
				"additives", canonicalize_taxonomy_tag($product_lc, "additives", $additive_class . " " . $after)
			)
		)
		and (
			exists_taxonomy_tag("additives", canonicalize_taxonomy_tag($product_lc, "additives", $after))
			or ((defined $after2)
				and exists_taxonomy_tag("additives", canonicalize_taxonomy_tag($product_lc, "additives", $after2)))
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

=head2 develop_ingredients_categories_and_types ( $product_lc, $text ) - turn "oil (sunflower, olive and palm)" into "sunflower oil, olive oil, palm oil"

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

# simple plural (just an additional "s" at the end) will be added in the regexp
my %ingredients_categories_and_types = (

	en => [
		# oils
		[
			# categories
			["oil", "vegetable oil", "vegetal oil",],
			# types
			["colza", "olive", "palm", "rapeseed", "sunflower",],
		],
	],

	fr => [
		# huiles
		[
			[
				"huile",
				"huile végétale",
				"huiles végétales",
				"matière grasse",
				"matières grasses",
				"matière grasse végétale",
				"matières grasses végétales",
				"graisse",
				"graisse végétale",
				"graisses végétales",
			],
			[
				"arachide", "avocat", "chanvre", "coco",
				"colza", "illipe", "karité", "lin",
				"mangue", "noisette", "noix", "noyaux de mangue",
				"olive", "olive extra", "olive vierge", "olive extra vierge",
				"olive vierge extra", "palme", "palmiste", "pépins de raisin",
				"sal", "sésame", "soja", "tournesol",
				"tournesol oléique",
			]
		],

		[
			["extrait", "extrait naturel",],
			[
				"café", "chicorée", "curcuma", "houblon", "levure", "malt",
				"muscade", "poivre", "poivre noir", "romarin", "thé", "thé vert",
				"thym",
			]
		],

		[["lécithine",], ["colza", "soja", "soja sans ogm", "tournesol",]],

		[
			[
				"arôme naturel",
				"arômes naturels",
				"arôme artificiel",
				"arômes artificiels",
				"arômes naturels et artificiels", "arômes",
			],
			[
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
		],

		[
			[
				"carbonate", "carbonates acides", "chlorure", "citrate",
				"iodure", "nitrate", "diphosphate", "diphosphate",
				"phosphate", "sélénite", "sulfate", "hydroxyde",
				"sulphate",
			],
			[
				"aluminium", "ammonium", "calcium", "cuivre", "fer", "magnésium",
				"manganèse", "potassium", "sodium", "zinc",
			]
		],
	],

	ru => [
		# oils
		[
			# categories
			["масло", "масло растительное",],
			# types
			[
				"Подсолнечное", "Пальмовое", "Рапсовое", "Кокосовое", "горчицы", "Соевое",
				"Пальмоядровое", "Оливковое", "пальм",
			],
		],
	],

);

# Symbols to indicate labels like organic, fairtrade etc.
my @symbols = ('\*\*\*', '\*\*', '\*', '°°°', '°°', '°', '\(1\)', '\(2\)', '¹', '²');
my $symbols_regexp = join('|', @symbols);

sub develop_ingredients_categories_and_types ($product_lc, $text) {

	if (defined $ingredients_categories_and_types{$product_lc}) {

		foreach my $categories_and_types_ref (@{$ingredients_categories_and_types{$product_lc}}) {

			my $category_regexp = "";
			foreach my $category (@{$categories_and_types_ref->[0]}) {
				$category_regexp .= '|' . $category . '|' . $category . 's';
				my $unaccented_category = unac_string_perl($category);
				if ($unaccented_category ne $category) {
					$category_regexp .= '|' . $unaccented_category . '|' . $unaccented_category . 's';
				}

			}
			$category_regexp =~ s/^\|//;

			if ($product_lc eq "en") {
				$category_regexp = '(?:organic |fair trade )*(?:' . $category_regexp . ')(?:' . $symbols_regexp . ')*';
			}
			elsif ($product_lc eq "fr") {
				$category_regexp
					= '(?:' . $category_regexp . ')(?: bio| biologique| équitable|s|\s|' . $symbols_regexp . ')*';
			}
			else {
				$category_regexp = '(?:' . $category_regexp . ')(?:' . $symbols_regexp . ')*';
			}

			my $type_regexp = "";
			foreach my $type (@{$categories_and_types_ref->[1]}) {
				$type_regexp .= '|' . $type . '|' . $type . 's';
				my $unaccented_type = unac_string_perl($type);
				if ($unaccented_type ne $type) {
					$type_regexp .= '|' . $unaccented_type . '|' . $unaccented_type . 's';
				}

			}
			$type_regexp =~ s/^\|//;

			# arôme naturel de citron-citron vert et d'autres agrumes
			# -> separate types
			$text =~ s/($type_regexp)-($type_regexp)/$1, $2/g;

			my $and = ' - ';
			if (defined $and{$product_lc}) {
				$and = $and{$product_lc};
			}
			my $of = ' - ';
			if (defined $of{$product_lc}) {
				$of = $of{$product_lc};
			}
			my $and_of = ' - ';
			if (defined $and_of{$product_lc}) {
				$and_of = $and_of{$product_lc};
			}
			my $and_or = ' - ';
			if (defined $and_or{$product_lc}) {
				$and_or = $and_or{$product_lc};
			}

			if (($product_lc eq "en") or ($product_lc eq "ru")) {

				# vegetable oil (palm, sunflower and olive)
				$text
					=~ s/($category_regexp)(?::|\(|\[| | $of )+((($type_regexp)($symbols_regexp|\s)*( |\/| \/ | - |,|, |$and|$of|$and_of|$and_or)+)+($type_regexp)($symbols_regexp|\s)*)\b(\s?(\)|\]))?/normalize_enumeration($product_lc,$1,$2)/ieg;

				# vegetable oil (palm)
				$text
					=~ s/($category_regexp)\s?(?:\(|\[)\s?($type_regexp)\b(\s?(\)|\]))/normalize_enumeration($product_lc,$1,$2)/ieg;
				# vegetable oil: palm
				$text
					=~ s/($category_regexp)\s?(?::)\s?($type_regexp)(?=$separators|$)/normalize_enumeration($product_lc,$1,$2)/ieg;
			}
			elsif ($product_lc eq "fr") {
				# arôme naturel de pomme avec d'autres âromes
				$text =~ s/ (ou|et|avec) (d')?autres /, /g;

				$text
					=~ s/($category_regexp) et ($category_regexp)(?:$of)?($type_regexp)/normalize_fr_a_et_b_de_c($1, $2, $3)/ieg;

				# Huiles végétales de palme, de colza et de tournesol
				# Carbonate de magnésium, fer élémentaire -> should not trigger carbonate de fer élémentaire. Bug #3838
				# TODO 18/07/2020 remove when we have a better solution
				$text =~ s/fer (é|e)l(é|e)mentaire/fer_élémentaire/ig;
				$text
					=~ s/($category_regexp)(?::|\(|\[| | de | d')+((($type_regexp)($symbols_regexp|\s)*( |\/| \/ | - |,|, | et | de | et de | et d'| d')+)+($type_regexp)($symbols_regexp|\s)*)\b(\s?(\)|\]))?/normalize_enumeration($product_lc,$1,$2)/ieg;
				$text =~ s/fer_élémentaire/fer élémentaire/ig;

				# huile végétale (colza)
				$text
					=~ s/($category_regexp)\s?(?:\(|\[)\s?($type_regexp)\b(\s?(\)|\]))/normalize_enumeration($product_lc,$1,$2)/ieg;
				# huile végétale : colza,
				$text
					=~ s/($category_regexp)\s?(?::)\s?($type_regexp)(?=$separators|$)/normalize_enumeration($product_lc,$1,$2)/ieg;
			}
		}

		# Some additives have "et" in their name: need to recombine them

		if ($product_lc eq "fr") {

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

=head2 preparse_ingredients_text ($product_lc, $text) - normalize the ingredient list to make parsing easier

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

sub preparse_ingredients_text ($product_lc, $text) {

	not defined $text and return;

	$log->debug("preparse_ingredients_text", {text => $text}) if $log->is_debug();

	# if we're called twice with the same input in succession, such as in update_all_products.pl,
	# cache the result, so we can instantly return the 2nd time.
	state $prev_lc = '';
	state $prev_text = '';
	state $prev_return = '';

	if (($product_lc eq $prev_lc) && ($text eq $prev_text)) {
		return $prev_return;
	}

	$prev_lc = $product_lc;
	$prev_text = $text;

	if ((scalar keys %labels_regexps) == 0) {
		init_labels_regexps();
		init_ingredients_processing_regexps();
		init_additives_classes_regexps();
		init_allergens_regexps();
		init_origins_regexps();
	}

	my $and = $and{$product_lc} || " and ";
	my $and_without_spaces = $and;
	$and_without_spaces =~ s/^ //;
	$and_without_spaces =~ s/ $//;

	my $of = ' - ';
	if (defined $of{$product_lc}) {
		$of = $of{$product_lc};
	}

	my $and_of = ' - ';
	if (defined $and_of{$product_lc}) {
		$and_of = $and_of{$product_lc};
	}

	# Spanish "and" is y or e when before "i" or "hi"
	# E can also be in a vitamin enumeration (vitamina B y E)
	# colores E (120, 124 y 125)
	# color E 120

	# replace "and / or" by "and"
	# except if followed by a separator, a digit, or "and", to avoid false positives
	my $and_or = ' - ';
	if (defined $and_or{$product_lc}) {
		$and_or = $and_or{$product_lc};
		$text =~ s/($and_or)(?!($and_without_spaces |\d|$separators))/$and/ig;
	}

	$text =~ s/\&quot;/"/g;
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
	if ($product_lc eq 'fr') {
		$text =~ s/(\d\s*)(gramme|grammes)\b/$1g/ig;
	}

	# Farine de blé 56 g* ; beurre concentré 25 g* (soit 30 g* en beurre reconstitué); sucre 22 g* ; œufs frais 2 g
	# 56 g -> 56%
	$text =~ s/(\d| )g(\*)/$1g/ig;

	# transform 0,2% into 0.2%
	$text =~ s/(\d),(\d+)( )?(\%|g\b)/$1.$2\%/ig;
	$text =~ s/—/-/g;

	# abbreviations, replace language specific abbreviations first
	foreach my $abbreviations_lc ($product_lc, "all") {
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
		=~ s/((^|$separators)([^,;\-\/\.0-9]+?) - ([^,;\-\/\.0-9]+?)(?=[0-9]|$separators|$))/is_compound_word_with_dash($product_lc,$1)/ieg;

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
	my $additivesregexp
		= '(\d{3}|\d{4})(( |-|\.)?([abcdefgh]))?(( |-|\.)?((' . $roman_numerals . ')|\((' . $roman_numerals . ')\)))?';

	$text
		=~ s/\b(e|ins|sin|i-n-s|s-i-n|i\.n\.s\.?|s\.i\.n\.?)(:|\(|\[| | n| nb|#|°)+((($additivesregexp)( |\/| \/ | - |,|, |$and))+($additivesregexp))\b(\s?(\)|\]))?/normalize_additives_enumeration($product_lc,$3)/ieg;

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
	if (defined $additives_classes_regexps{$product_lc}) {
		my $regexp = $additives_classes_regexps{$product_lc};
		# negative look ahead so that the additive class is not preceded by other words
		# e.g. "de l'acide" should not match "acide"
		$text =~ s/(?<!\w( |'))\b($regexp)(\s+)(:?)(?!\(| \()/separate_additive_class($product_lc,$2,$3,$4,$')/ieg;
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

	if ($product_lc eq 'de') {
		# deletes comma in "Bienenwachs, weiß und gelb" since it is just one ingredient
		$text =~ s/Bienenwachs, weiß und gelb/Bienenwachs weiß und gelb/ig;
		# deletes brackets in "Bienenwachs, weiß und gelb" since it is just one ingredient
		$text =~ s/Bienenwachs \(weiß und gelb\)/Bienenwachs weiß und gelb/ig;
	}
	elsif ($product_lc eq 'es') {

		# Special handling for sal as it can mean salt or shorea robusta
		# aceites vegetales (palma, shea, sal (shorea robusta), hueso de mango)
		$text =~ s/\bsal \(shorea robusta\)/shorea robusta/ig;
		$text =~ s/\bshorea robusta \(sal\)/shorea robusta/ig;
	}
	elsif ($product_lc eq 'fi') {

		# Organic label can appear as a part of a longer word.
		# Separate it so it can be detected
		$text =~ s/\b(luomu)\B/$1 /ig;
	}
	elsif ($product_lc eq 'fr') {

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

	$text = develop_ingredients_categories_and_types($product_lc, $text);

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
			if (defined $translations_to{vitamins}{$vitamin}{$product_lc}) {
				push @vitaminssuffixes, $translations_to{vitamins}{$vitamin}{$product_lc};
			}
		}
	}

	# Add synonyms in target language
	my $vitamin_in_lc
		= get_string_id_for_lang($product_lc, display_taxonomy_tag($product_lc, "ingredients", "en:vitamins"));
	$vitamin_in_lc =~ s/^\w\w://;

	if (    (defined $synonyms_for{ingredients})
		and (defined $synonyms_for{ingredients}{$product_lc})
		and (defined $synonyms_for{ingredients}{$product_lc}{$vitamin_in_lc}))
	{
		foreach my $synonym (@{$synonyms_for{ingredients}{$product_lc}{$vitamin_in_lc}}) {
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
		=~ s/($vitaminsprefixregexp)(:|\(|\[| )+((($vitaminssuffixregexp)( |\/| \/ | - |,|, |$and)+)+($vitaminssuffixregexp))((\s?((\)|\]))|\b))/normalize_vitamins_enumeration($product_lc,$3)/ieg;

	# Allergens and traces
	# Traces de lait, d'oeufs et de soja.
	# Contains: milk and soy.

	foreach my $allergens_type ("allergens", "traces") {

		if (defined $contains_or_may_contain_regexps{$allergens_type}{$product_lc}) {

			my $contains_or_may_contain_regexp = $contains_or_may_contain_regexps{$allergens_type}{$product_lc};
			my $allergens_regexp = $allergens_regexps{$product_lc};

			# stopwords
			# e.g. Kann Spuren von Senf und Sellerie enthalten.
			my $stopwords = "";
			if (defined $allergens_stopwords{$product_lc}) {
				$stopwords = $allergens_stopwords{$product_lc};
			}

			# $contains_or_may_contain_regexp may be the end of a sentence, remove the beginning
			# e.g. this product has been manufactured in a factory that also uses...
			# Some text with comma May contain ... -> Some text with comma, May contain
			# ! does not work in German and languages that have words with a capital letter
			if ($product_lc ne "de") {
				my $ucfirst_contains_or_may_contain_regexp = $contains_or_may_contain_regexp;
				$ucfirst_contains_or_may_contain_regexp =~ s/(^|\|)(\w)/$1 . uc($2)/ieg;
				$text =~ s/([a-z]) ($ucfirst_contains_or_may_contain_regexp)/$1, $2/g;
			}

			#$log->debug("allergens regexp", { regex => "s/([^,-\.;\(\)\/]*)\b($contains_or_may_contain_regexp)\b(:|\(|\[| |$and|$of)+((($allergens_regexp)( |\/| \/ | - |,|, |$and|$of|$and_of)+)+($allergens_regexp))\b(s?(\)|\]))?" }) if $log->is_debug();
			#$log->debug("allergens", { lc => $product_lc, may_contain_regexps => \%may_contain_regexps, contains_or_may_contain_regexp => $contains_or_may_contain_regexp, text => $text }) if $log->is_debug();

			# warning: we should remove a parenthesis at the end only if we remove one at the beginning
			# e.g. contains (milk, eggs) -> contains milk, eggs
			# chocolate (contains milk) -> chocolate (contains milk)
			$text
				=~ s/([^,-\.;\(\)\/]*)\b($contains_or_may_contain_regexp)\b((:|\(|\[| |$of)+)((_?($allergens_regexp)_?\b((\s)($stopwords)\b)*( |\/| \/ | - |,|, |$and|$of|$and_of)+)*_?($allergens_regexp)_?)\b((\s)($stopwords)\b)*(\s?(\)|\]))?/normalize_allergens_enumeration($allergens_type,$product_lc,$3,$5,$17)/ieg;
			# we may have added an extra dot in order to make sure we have at least one
			$text =~ s/\.\./\./g;
		}
	}

	# Try to find the signification of symbols like *
	# Jus de pomme*** 68%, jus de poire***32% *** Ingrédients issus de l'agriculture biologique
	# Pâte de cacao°* du Pérou 65 %, sucre de canne°*, beurre de cacao°*. °Issus de l'agriculture biologique (100 %). *Issus du commerce équitable (100 % du poids total avec 93 % SPP).
	#  riz* de Camargue IGP(1) (16,5%) (riz complet*, riz rouge complet*, huiles* (tournesol*, olive* vierge extra), sel marin. *issus de l'agriculture biologique. (1) IGP : Indication Géographique Protégée.

	if (defined $labels_regexps{$product_lc}) {

		foreach my $symbol (@symbols) {
			# Find the last occurence of the symbol or symbol in parenthesis:  * (*)
			# we need a negative look ahead (?!\)) to make sure we match (*) completely (otherwise we would match *)
			if ($text =~ /^(.*)(\($symbol\)|$symbol)(?!\))\s*(:|=)?\s*/i) {
				my $after = $';
				#print STDERR "symbol: $symbol - after: $after\n";
				foreach my $labelid (@labels) {
					my $regexp = $labels_regexps{$product_lc}{$labelid};
					if (defined $regexp) {
						#print STDERR "-- label: $labelid - regexp: $regexp\n";
						# try to also match optional precisions like "Issus de l'agriculture biologique (100 % du poids total)"
						# *Issus du commerce équitable (100 % du poids total avec 93 % SPP).
						if ($after =~ /^($regexp)\b\s*(\([^\)]+\))?\s*\.?\s*/i) {
							my $label = $1;
							$text
								=~ s/^(.*)(\($symbol\)|$symbol)(?!\))\s?(:|=)?\s?$label\s*(\([^\)]+\))?\s*\.?\s*/$1 /i;
							my $product_lc_label = display_taxonomy_tag($product_lc, "labels", $labelid);
							$text =~ s/$symbol/ $product_lc_label /g;
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

sub extract_ingredients_classes_from_text ($product_ref) {

	not defined $product_ref->{ingredients_text} and return;

	my $text = preparse_ingredients_text($product_ref->{lc}, $product_ref->{ingredients_text});
	my $and = $Lang{_and_}{$product_ref->{lc}};
	$and =~ s/ /-/g;

	#  remove % / percent (to avoid identifying 100% as E100 in some cases)
	$text =~ s/(\d+((\,|\.)\d+)?)\s*\%$//g;

	my @ingredients = split($separators, $text);

	my @ingredients_ids = ();
	foreach my $ingredient (@ingredients) {
		my $ingredientid = get_string_id_for_lang($product_ref->{lc}, $ingredient);
		if ((defined $ingredientid) and ($ingredientid ne '')) {

			# split additives
			# caramel ordinaire et curcumine
			if ($ingredientid =~ /$and/i) {

				my $ingredientid1 = $`;
				my $ingredientid2 = $';

				#print STDERR "ingredients_classes - ingredient1: $ingredientid1 - ingredient2: $ingredientid2\n";

				# check if the whole ingredient is an additive
				my $canon_ingredient_additive
					= canonicalize_taxonomy_tag($product_ref->{lc}, "additives", $ingredientid);

				if (not exists_taxonomy_tag("additives", $canon_ingredient_additive)) {

					# otherwise check the 2 sub ingredients
					my $canon_ingredient_additive1
						= canonicalize_taxonomy_tag($product_ref->{lc}, "additives", $ingredientid1);
					my $canon_ingredient_additive2
						= canonicalize_taxonomy_tag($product_ref->{lc}, "additives", $ingredientid2);

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

	# delete old additive fields

	foreach my $tagtype ('additives', 'additives_prev', 'additives_next', 'old_additives', 'new_additives') {

		delete $product_ref->{$tagtype};
		delete $product_ref->{$tagtype . "_prev"};
		delete $product_ref->{$tagtype . "_prev_n"};
		delete $product_ref->{$tagtype . "_tags"};
	}

	delete $product_ref->{new_additives_debug};

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
					= canonicalize_taxonomy_tag($product_ref->{lc}, "additives_classes", $ingredient_id_copy);

				if (exists_taxonomy_tag("additives_classes", $canon_ingredient_additive_class)) {
					$current_additive_class = $canon_ingredient_additive_class;
					$log->debug("current additive class", {current_additive_class => $canon_ingredient_additive_class})
						if $log->is_debug();
				}

				# additive?
				my $canon_ingredient = canonicalize_taxonomy_tag($product_ref->{lc}, $tagtype, $ingredient_id_copy);
				# in Hong Kong, the E- can be omitted in E-numbers
				my $canon_e_ingredient
					= canonicalize_taxonomy_tag($product_ref->{lc}, $tagtype, "e" . $ingredient_id_copy);
				my $canon_ingredient_vitamins
					= canonicalize_taxonomy_tag($product_ref->{lc}, "vitamins", $ingredient_id_copy);
				my $canon_ingredient_minerals
					= canonicalize_taxonomy_tag($product_ref->{lc}, "minerals", $ingredient_id_copy);
				my $canon_ingredient_amino_acids
					= canonicalize_taxonomy_tag($product_ref->{lc}, "amino_acids", $ingredient_id_copy);
				my $canon_ingredient_nucleotides
					= canonicalize_taxonomy_tag($product_ref->{lc}, "nucleotides", $ingredient_id_copy);
				my $canon_ingredient_other_nutritional_substances
					= canonicalize_taxonomy_tag($product_ref->{lc}, "other_nutritional_substances",
					$ingredient_id_copy);

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
							canonicalize_taxonomy_tag($product_ref->{lc}, "ingredients", $ingredient_id_copy)
						)
					)
					)
				{

					my ($corrected_canon_tagid, $corrected_tagid, $corrected_tag)
						= spellcheck_taxonomy_tag($product_ref->{lc}, $tagtype, $ingredient_id_copy);
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
							. $product_ref->{lc}
							. "): $ingredient_id_copy -> $corrected_tag";
						print STDERR "spell correction (lc: "
							. $product_ref->{lc}
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

					if (($product_ref->{lc} eq 'en') and ($ingredient_id_copy =~ /^([^-]+)-/)) {
						# soy-lecithin -> lecithin
						$ingredient_id_copy = $';
					}
					elsif ( (($product_ref->{lc} eq 'es') or ($product_ref->{lc} eq 'fr'))
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

	foreach my $class (sort keys %ingredients_classes) {

		my $tagtype = $class;

		if ($tagtype eq 'additives') {
			$tagtype = 'additives_old';
		}

		$product_ref->{$tagtype . '_tags'} = [];

		# skip palm oil classes if there is a palm oil free label
		if (($class =~ /palm/) and has_tag($product_ref, "labels", 'en:palm-oil-free')) {

		}
		else {

			my %seen = ();

			foreach my $ingredient_id (@ingredients_ids) {

				#$product_ref->{$tagtype . "_debug_ingredients_ids" } .=  " ; " . $ingredient_id . " ";

				if (    (defined $ingredients_classes{$class}{$ingredient_id})
					and (not defined $seen{$ingredients_classes{$class}{$ingredient_id}{id}}))
				{

					next
						if (($ingredients_classes{$class}{$ingredient_id}{id} eq 'huile-vegetale')
						and (defined $all_seen{"huile-de-palme"}));

					#$product_ref->{$tagtype . "_debug_ingredients_ids" } .= " -> exact match $ingredients_classes{$class}{$ingredient_id}{id} ";

					push @{$product_ref->{$tagtype . '_tags'}}, $ingredients_classes{$class}{$ingredient_id}{id};
					$seen{$ingredients_classes{$class}{$ingredient_id}{id}} = 1;
					$all_seen{$ingredients_classes{$class}{$ingredient_id}{id}} = 1;

				}
				else {

					#$product_ref->{$tagtype . "_debug_ingredients_ids" } .= " -> no exact match ";

					foreach my $id (@{$ingredients_classes_sorted{$class}}) {

						if (index($ingredient_id, $id) == 0) {
							# only compile the regex if we can't avoid it
							if (    ($ingredient_id =~ /^$id\b/)
								and (not defined $seen{$ingredients_classes{$class}{$id}{id}}))
							{

								next
									if (($ingredients_classes{$class}{$id}{id} eq 'huile-vegetale')
									and (defined $all_seen{"huile-de-palme"}));

								#$product_ref->{$tagtype . "_debug_ingredients_ids" } .= " -> match $id - $ingredients_classes{$class}{$id}{id} ";

								push @{$product_ref->{$tagtype . '_tags'}}, $ingredients_classes{$class}{$id}{id};
								$seen{$ingredients_classes{$class}{$id}{id}} = 1;
								$all_seen{$ingredients_classes{$class}{$id}{id}} = 1;
							}
						}

					}
				}
			}
		}

		# No ingredients?
		if ((defined $product_ref->{ingredients_text}) and ($product_ref->{ingredients_text} eq '')) {
			delete $product_ref->{$tagtype . '_n'};
		}
		else {
			$product_ref->{$tagtype . '_n'} = scalar @{$product_ref->{$tagtype . '_tags'}};
		}

		# Delete empty arrays
		# -> not active
		# -> may be dangerous if some apps rely on them existing even if empty

		if (0) {
			if ((defined $product_ref->{$tagtype . '_tags'}) and ((scalar @{$product_ref->{$tagtype . '_tags'}}) == 0))
			{
				delete $product_ref->{$tagtype . '_tags'};
			}
		}
	}

	if (defined $product_ref->{additives_old_tags}) {
		for (my $i = 0; $i < (scalar @{$product_ref->{additives_old_tags}}); $i++) {
			$product_ref->{additives_old_tags}[$i] = 'en:' . $product_ref->{additives_old_tags}[$i];
		}
	}

	# keep the old additives for France until we can fix the new taxonomy matching to support all special cases
	# e.g. lecithine de soja
	#if ($product_ref->{lc} ne 'fr') {
	#	$product_ref->{additives_tags} = $product_ref->{new_additives_tags};
	#	$product_ref->{additives_tags_n} = $product_ref->{new_additives_tags_n};
	#}

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

	delete $product_ref->{with_sweeteners};
	if (defined $product_ref->{'additives_tags'}) {
		foreach my $additive (@{$product_ref->{'additives_tags'}}) {
			my $e = $additive;
			$e =~ s/\D//g;
			if (($e >= 950) and ($e <= 968)) {
				$product_ref->{with_sweeteners} = 1;
				last;
			}
		}
	}

	return;
}

sub replace_allergen ($language, $product_ref, $allergen, $before) {

	my $field = "allergens";

	my $traces_regexp = $may_contain_regexps{$language};

	if ((defined $traces_regexp) and ($before =~ /\b($traces_regexp)\b/i)) {
		$field = "traces";
	}

	# to build the product allergens list, just use the ingredients in the main language
	if ($language eq $product_ref->{lc}) {
		# skip allergens like "moutarde et céleri" (will be caught later by replace_allergen_between_separators)
		if (not(($language eq 'fr') and $allergen =~ / et /i)) {
			$product_ref->{$field . "_from_ingredients"} .= $allergen . ', ';
		}
	}

	return '<span class="allergen">' . $allergen . '</span>';
}

sub replace_allergen_in_caps ($language, $product_ref, $allergen, $before) {

	my $field = "allergens";

	my $traces_regexp = $may_contain_regexps{$language};

	if ((defined $traces_regexp) and ($before =~ /\b($traces_regexp)\b/i)) {
		$field = "traces";
	}

	my $tagid = canonicalize_taxonomy_tag($language, "allergens", $allergen);

	if (exists_taxonomy_tag("allergens", $tagid)) {
		#$allergen = display_taxonomy_tag($product_ref->{lang},"allergens", $tagid);
		# to build the product allergens list, just use the ingredients in the main language
		if ($language eq $product_ref->{lc}) {
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
		if ($language eq $product_ref->{lc}) {
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
			$product_ref->{"allergens_from_ingredients"} = $allergens . ', ';
			$log->debug("detect_allergens_from_ingredients -- found allergen", {allergens => $allergens})
				if $log->is_debug();
		}
	}
	return;
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

			my $and = $Lang{_and_}{$language};
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

			if ($language eq $product_ref->{lc}) {
				$product_ref->{"ingredients_text_with_allergens"} = $text;
			}

		}
	}

	# If traces were entered in the allergens field, split them
	# Use the language the tag have been entered in

	my $traces_regexp;
	if (defined $may_contain_regexps{$product_ref->{traces_lc} || $product_ref->{lc}}) {
		$traces_regexp = $may_contain_regexps{$product_ref->{traces_lc} || $product_ref->{lc}};
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

		$product_ref->{$field . "_hierarchy"} = [gen_tags_hierarchy_taxonomy($product_ref->{lc}, $field, $allergens)];
		$product_ref->{$field . "_tags"} = [];
		# print STDERR "result for $field : ";
		foreach my $tag (@{$product_ref->{$field . "_hierarchy"}}) {
			push @{$product_ref->{$field . "_tags"}}, get_taxonomyid($product_ref->{lc}, $tag);
			# print STDERR " - $tag";
		}
		# print STDERR "\n";
	}

	$log->debug("detect_allergens_from_text - done", {}) if $log->is_debug();

	return;
}

=head2 add_fruits ( $ingredients_ref )

Recursive function to compute the % of fruits, vegetables, nuts and olive/walnut/rapeseed oil
for Nutri-Score computation.

=cut

sub add_fruits ($ingredients_ref) {

	my $fruits = 0;

	foreach my $ingredient_ref (@{$ingredients_ref}) {

		my $nutriscore_fruits_vegetables_nuts
			= get_inherited_property("ingredients", $ingredient_ref->{id}, "nutriscore_fruits_vegetables_nuts:en");

		if ((defined $nutriscore_fruits_vegetables_nuts) and ($nutriscore_fruits_vegetables_nuts eq "yes")) {

			if (defined $ingredient_ref->{percent}) {
				$fruits += $ingredient_ref->{percent};
			}
			elsif (defined $ingredient_ref->{percent_min}) {
				$fruits += $ingredient_ref->{percent_min};
			}
			# We may not have percent_min if the ingredient analysis failed because of seemingly impossible values
			# in that case, try to get the possible percent values in nested sub ingredients
			elsif (defined $ingredient_ref->{ingredients}) {
				$fruits += add_fruits($ingredient_ref->{ingredients});
			}
		}
		elsif (defined $ingredient_ref->{ingredients}) {
			$fruits += add_fruits($ingredient_ref->{ingredients});
		}
		$log->debug("add_fruits ingredient, current total",
			{ingredient_id => $ingredient_ref->{id}, current_fruits => $fruits})
			if $log->is_debug();
	}

	$log->debug("add_fruits result", {fruits => $fruits}) if $log->is_debug();

	return $fruits;
}

=head2 estimate_nutriscore_fruits_vegetables_nuts_value_from_ingredients ( product_ref )

This function analyzes the ingredients to estimate the minimum percentage of
fruits, vegetables, nuts, olive / walnut / rapeseed oil, so that we can compute
the Nutri-Score fruit points if we don't have a value given by the manufacturer
or estimated by users.

Results are stored in $product_ref->{nutriments}{"fruits-vegetables-nuts-estimate-from-ingredients_100g"} (and _serving)

=cut

sub estimate_nutriscore_fruits_vegetables_nuts_value_from_ingredients ($product_ref) {

	if (defined $product_ref->{nutriments}) {
		delete $product_ref->{nutriments}{"fruits-vegetables-nuts-estimate-from-ingredients_100g"};
		delete $product_ref->{nutriments}{"fruits-vegetables-nuts-estimate-from-ingredients_serving"};
	}

	if ((defined $product_ref->{ingredients}) and ((scalar @{$product_ref->{ingredients}}) > 0)) {

		(defined $product_ref->{nutriments}) or $product_ref->{nutriments} = {};

		$product_ref->{nutriments}{"fruits-vegetables-nuts-estimate-from-ingredients_100g"}
			= add_fruits($product_ref->{ingredients});
	}

	# If we have specific ingredients, check if we have a higher fruits / vegetables content
	if (defined $product_ref->{specific_ingredients}) {
		my $fruits = 0;
		foreach my $ingredient_ref (@{$product_ref->{specific_ingredients}}) {
			my $ingredient_id = $ingredient_ref->{id};
			if (defined $ingredient_ref->{percent}) {
				my $nutriscore_fruits_vegetables_nuts
					= get_inherited_property("ingredients", $ingredient_id, "nutriscore_fruits_vegetables_nuts:en");

				if ((defined $nutriscore_fruits_vegetables_nuts) and ($nutriscore_fruits_vegetables_nuts eq "yes")) {
					$fruits += $ingredient_ref->{percent};
				}
			}
		}

		if (
			($fruits > 0)
			and (  (not defined $product_ref->{nutriments}{"fruits-vegetables-nuts-estimate-from-ingredients_100g"})
				or ($fruits > $product_ref->{nutriments}{"fruits-vegetables-nuts-estimate-from-ingredients_100g"}))
			)
		{
			$product_ref->{nutriments}{"fruits-vegetables-nuts-estimate-from-ingredients_100g"} = $fruits;
		}
	}

	if (defined $product_ref->{nutriments}{"fruits-vegetables-nuts-estimate-from-ingredients_100g"}) {
		$product_ref->{nutriments}{"fruits-vegetables-nuts-estimate-from-ingredients_serving"}
			= $product_ref->{nutriments}{"fruits-vegetables-nuts-estimate-from-ingredients_100g"};
	}

	return;
}

=head2 add_milk ( $ingredients_ref )

Recursive function to compute the % of milk for Nutri-Score computation.

=cut

sub add_milk ($ingredients_ref) {

	my $milk = 0;

	foreach my $ingredient_ref (@{$ingredients_ref}) {

		if (is_a("ingredients", $ingredient_ref->{id}, "en:milk")) {

			if (defined $ingredient_ref->{percent}) {
				$milk += $ingredient_ref->{percent};
			}
			elsif (defined $ingredient_ref->{percent_min}) {
				$milk += $ingredient_ref->{percent_min};
			}
			# We may not have percent_min if the ingredient analysis failed because of seemingly impossible values
			# in that case, try to get the possible percent values in nested sub ingredients
			elsif (defined $ingredient_ref->{ingredients}) {
				$milk += add_milk($ingredient_ref->{ingredients});
			}
		}
		elsif (defined $ingredient_ref->{ingredients}) {
			$milk += add_milk($ingredient_ref->{ingredients});
		}

		$log->debug("add_milk ingredient, current total",
			{ingredient_id => $ingredient_ref->{id}, current_milk => $milk})
			if $log->is_debug();
	}

	$log->debug("add_milk result", {milk => $milk}) if $log->is_debug();

	return $milk;
}

=head2 estimate_milk_percent_from_ingredients ( product_ref )

This function analyzes the ingredients to estimate the minimum percentage of milk in a product,
in order to know if a dairy drink should be considered as a food (at least 80% of milk) or a beverage.

Return value: estimated % of milk.

=cut

sub estimate_milk_percent_from_ingredients ($product_ref) {

	my $milk_percent = 0;

	if ((defined $product_ref->{ingredients}) and ((scalar @{$product_ref->{ingredients}}) > 0)) {

		$log->debug("milk percent - start", {milk_percent => $milk_percent}) if $log->is_debug();
		$milk_percent = add_milk($product_ref->{ingredients});
	}

	$log->debug("milk percent", {milk_percent => $milk_percent}) if $log->is_debug();

	return $milk_percent;
}

1;
