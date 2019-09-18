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

package ProductOpener::Ingredients;

use utf8;
use Modern::Perl '2017';
use Exporter    qw< import >;

BEGIN
{
	use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@EXPORT = qw();            # symbols to export by default
	@EXPORT_OK = qw(
		&extract_ingredients_from_image

		&preparse_ingredients_text
		&extract_ingredients_from_text
		&analyze_ingredients
		&separate_additive_class

		&compute_carbon_footprint_from_ingredients
		&compute_carbon_footprint_from_meat_or_fish

		&clean_ingredients_text_for_lang
		&clean_ingredients_text

		&extract_ingredients_classes_from_text

		&detect_allergens_from_text

		&normalize_a_of_b
		&normalize_enumeration
	);	# symbols to export on request
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

# MIDDLE DOT with common substitutes (BULLET variants, BULLET OPERATOR and DOT OPERATOR (multiplication))
my $middle_dot = qr/(?:\N{U+00B7}|\N{U+2022}|\N{U+2023}|\N{U+25E6}|\N{U+2043}|\N{U+204C}|\N{U+204D}|\N{U+2219}|\N{U+22C5})/i;

# Unicode category 'Punctuation, Dash', SWUNG DASH and MINUS SIGN
my $dashes = qr/(?:\p{Pd}|\N{U+2053}|\N{U+2212})/i;

# ',' and synonyms - COMMA, SMALL COMMA, FULLWIDTH COMMA, IDEOGRAPHIC COMMA, SMALL IDEOGRAPHIC COMMA, HALFWIDTH IDEOGRAPHIC COMMA
my $commas = qr/(?:\N{U+002C}|\N{U+FE50}|\N{U+FF0C}|\N{U+3001}|\N{U+FE51}|\N{U+FF64})/i;

# '.' and synonyms - FULL STOP, SMALL FULL STOP, FULLWIDTH FULL STOP, IDEOGRAPHIC FULL STOP, HALFWIDTH IDEOGRAPHIC FULL STOP
my $stops = qr/(?:\N{U+002E}|\N{U+FE52}|\N{U+FF0E}|\N{U+3002}|\N{U+FE61})/i;

# '(' and other opening brackets ('Punctuation, Open' without QUOTEs)
my $obrackets = qr/(?![\N{U+201A}|\N{U+201E}|\N{U+276E}|\N{U+2E42}|\N{U+301D}])[\p{Ps}]/i;
# ')' and other closing brackets ('Punctuation, Close' without QUOTEs)
my $cbrackets = qr/(?![\N{U+276F}|\N{U+301E}|\N{U+301F}])[\p{Pe}]/i;

my $separators_except_comma = qr/(;|:|$middle_dot|\[|\{|\(|( $dashes ))|(\/)/i; # separators include the dot . followed by a space, but we don't want to separate 1.4 etc.

my $separators = qr/($stops\s|$commas|$separators_except_comma)/i;


# do not add sub ( ) in the regexps below as it would change which parts gets matched in $1, $2 etc. in other regexps that use those regexps
my %traces_regexps = (

	en => "traces|may contain",
	de => "Kann Spuren|Spuren",
	es => "puede contener|trazas|traza",
	fr => "peut contenir|qui utilise aussi|traces|traces possibles|traces éventuelles|trace|trace possible|trace éventuelle",
	it => "può contenere|puo contenere|che utilizza anche|tracce|possibili tracce|eventuali tracce|traccia|possibile traccia|eventuale traccia",

);

my %allergens_stopwords = (

	en => "and|of|this|product|other|made|manufactured|in|a|factory|which|also|uses",
	de => "enthalten|von|und",
	es => "y|de|que|contiene|contienen|otros",
	fr => "d'autres|autre|autres|ce|produit|est|fabriqué|élaboré|transformé|emballé|dans|un|atelier|une|usine|qui|utilise|aussi|également|céréale|céréales|farine|farines|extrait|extraits|graine|graines|traces|éventuelle|éventuelles|possible|possibles|peut|pourrait|contenir|contenant|contient|de|des|du|d'|l'|la|le|les|et",

);

# Semoule de blé dur de qualité supérieure, précuite à la vapeur :

my %abbreviations = (

fr => [
["Mat. Gr.", "Matières Grasses"]
],

);

my %of = (
	en => " of ",
	de => " von ",
	es => " de ",
	fr => " de | du | des | d'",
	it => " di | d'",
);

my %and_of = (
	en => " and of ",
	de => " und von ",
	es => " y de ",
	fr => " et de | et du | et des | et d'",
	it => " e di | e d'",
);

my %and_or = (
	en => " and | or | and/or | and / or ",
	de => " und | oder | und/oder | und / oder ",
	es => " y | o | y/o | y / o ",
	fr => " et | ou | et/ou | et / ou ",
	it => " e | o | e/o | e / o",
);


my %the = (
	en => " the ",
	es => " el | la | los | las ",
	fr => " le | la | les | l'",
	it => " il | lo | la | i | gli | le | l'",
);




# Labels that we want to recognize in the ingredients
# e.g. "fraises issues de l'agriculture biologique"

# Put composed labels like fair-trade-organic first
my @labels = ("en:fair-trade-organic", "en:organic", "en:fair-trade");
my %labels_regexps = ();

# Needs to be called after Tags.pm has loaded taxonomies

sub init_labels_regexps() {

	foreach my $labelid (@labels) {

		foreach my $label_lc (keys %{$translations_to{labels}{$labelid}}) {

			# the synonyms below also contain the main translation as the first entry

			my $label_lc_labelid = get_string_id_for_lang($label_lc, $translations_to{labels}{$labelid}{$label_lc});

			my @synonyms = ();

			foreach my $synonym (@{$synonyms_for{labels}{$label_lc}{$label_lc_labelid}}) {
				push @synonyms, $synonym;
			}

			my $label_regexp = "";
			foreach my $synonym (sort { length($b) <=> length($a) } @synonyms) {
				# simple singulars and plurals
				my $singular = $synonym;
				$synonym =~ s/s$//;
				$label_regexp .= '|' . $synonym . '|' . $synonym . 's'  ;

				my $unaccented_synonym = unac_string_perl($synonym);
				if ($unaccented_synonym ne $synonym) {
					$label_regexp .= '|' . $unaccented_synonym . '|' . $unaccented_synonym . 's';
				}

			}
			$label_regexp =~ s/^\|//;
			defined $labels_regexps{$label_lc} or $labels_regexps{$label_lc} = {};
			$labels_regexps{$label_lc}{$labelid} = $label_regexp;
			# print STDERR "labels_regexps - label_lc: $label_lc - labelid: $labelid - regexp: $label_regexp\n";
		}
	}
}

# Ingredients processing regexps

my %ingredients_processing_regexps = ();

sub init_ingredients_processing_regexps() {

	foreach my $ingredients_processing (sort { (length($b) <=> length($a)) || ($a cmp $b) } keys %{$translations_to{ingredients_processing}}) {

		foreach my $l (sort keys %{$translations_to{ingredients_processing}{$ingredients_processing}}) {

			defined $ingredients_processing_regexps{$l}  or $ingredients_processing_regexps{$l}  = [];

			my %synonyms = ();

			# the synonyms below also contain the main translation as the first entry

			my $l_ingredients_processing = get_string_id_for_lang($l, $translations_to{ingredients_processing}{$ingredients_processing}{$l});

			foreach my $synonym (sort @{$synonyms_for{ingredients_processing}{$l}{$l_ingredients_processing}}) {
				$synonyms{$synonym} = 1;
				# unaccented forms
				$synonyms{unac_string_perl($synonym)} = 1;
			}

			# Match the longest strings first
			my $regexp = join('|', sort { length($b) <=> length($a) } keys %synonyms);
			push @{$ingredients_processing_regexps{$l}}, [$ingredients_processing , $regexp];
			# print STDERR "ingredients_processing_regexps{$l}: ingredient_processing: $ingredient_processing - regexp: $regexp . "\n";
		}
	}
}


# Additives classes regexps

my %additives_classes_regexps = ();

sub init_additives_classes_regexps() {

	# Create a regexp with all synonyms of all additives classes
	my %additives_classes_synonyms = ();

	foreach my $additives_class (keys %{$translations_to{additives_classes}}) {

		# do not turn vitamin a in vitamin : a-z
		next if $additives_class eq "en:vitamins";

		foreach my $l (keys %{$translations_to{additives_classes}{$additives_class}}) {

			defined $additives_classes_synonyms{$l} or $additives_classes_synonyms{$l} = {};

			# the synonyms below also contain the main translation as the first entry

			my $l_additives_class = get_string_id_for_lang($l, $translations_to{additives_classes}{$additives_class}{$l});

			foreach my $synonym (@{$synonyms_for{additives_classes}{$l}{$l_additives_class}}) {
				$additives_classes_synonyms{$l}{$synonym} = 1;
				# simple singulars and plurals + unaccented forms
				$additives_classes_synonyms{$l}{unac_string_perl($synonym)} = 1;
				$synonym =~ s/s$//;
				$additives_classes_synonyms{$l}{$synonym} = 1;
				$additives_classes_synonyms{$l}{unac_string_perl($synonym)} = 1;
				$additives_classes_synonyms{$l}{$synonym . "s"} = 1;
				$additives_classes_synonyms{$l}{unac_string_perl($synonym . "s")} = 1;
			}
		}
	}

	foreach my $l (sort keys %additives_classes_synonyms) {
		# Match the longest strings first
		$additives_classes_regexps{$l} = join('|', sort { length($b) <=> length($a) } keys %{$additives_classes_synonyms{$l}});
		# print STDERR "additives_classes_regexps{$l}: " . $additives_classes_regexps{$l} . "\n";
	}
}

if ((keys %labels_regexps) > 0) { exit; }

# load ingredients classes
opendir(DH, "$data_root/ingredients") or $log->error("cannot open ingredients directory", { path => "$data_root/ingredients", error => $! });

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
			$ingredients_classes{$class}{$id} = {name=>$canon_name, id=>$id, other_names=>$other_names, level=>$level, description=>$desc, warning=>$warning};
		}
		#print STDERR "name: $canon_name\nother_names: $other_names\n";
		if (defined $other_names) {
			foreach my $other_name (split(/,/, $other_names)) {
				$other_name =~ s/^\s+//;
				$other_name =~ s/\s+$//;
				my $other_id = get_string_id_for_lang("no_language",$other_name);
				next if $other_id eq '';
				next if $other_name eq '';
				if (not defined $ingredients_classes{$class}{$other_id}) { # Take the first one
					$ingredients_classes{$class}{$other_id} = {name=>$other_name, id=>$id};
					#print STDERR "$id\t$other_id\n";
				}
			}
		}
	}
	close $IN;

	$ingredients_classes_sorted{$class} = [sort keys %{$ingredients_classes{$class}}];
}
closedir(DH);



sub compute_carbon_footprint_from_ingredients($) {

	my $product_ref = shift;

	if (defined $product_ref->{nutriments}) {
		delete $product_ref->{nutriments}{"carbon-footprint-from-known-ingredients_100g"};
	}

	remove_tag($product_ref, "misc", "en:environment-infocard");
	remove_tag($product_ref, "misc", "en:carbon-footprint-from-known-ingredients");

	delete $product_ref->{"carbon_footprint_from_known_ingredients_debug"};

	# Limit to France, as the carbon values from ADEME are intended for France
	if ((has_tag($product_ref, "countries", "en:france")) and (defined $product_ref->{ingredients})) {

		my $carbon_footprint = 0;
		my $carbon_percent = 0;

		foreach my $ingredient_ref (@{$product_ref->{ingredients}}) {

			$log->debug("carbon-footprint-from-known-ingredients_100g", { id =>  $ingredient_ref->{id} }) if $log->is_debug();

			if ((defined $ingredient_ref->{percent}) and ($ingredient_ref->{percent} > 0)) {

				$log->debug("carbon-footprint-from-known-ingredients_100g", { percent =>  $ingredient_ref->{percent} }) if $log->is_debug();

				my $carbon_footprint_ingredient = get_inherited_property('ingredients', $ingredient_ref->{id}, "carbon_footprint_fr_foodges_value:fr");

				if(defined $carbon_footprint_ingredient)
				{
					$carbon_footprint += $ingredient_ref->{percent} * $carbon_footprint_ingredient;
					$carbon_percent	+= $ingredient_ref->{percent};

					if (not defined $product_ref->{"carbon_footprint_from_known_ingredients_debug"}) {
						$product_ref->{"carbon_footprint_from_known_ingredients_debug"} = "";
					}
					$product_ref->{"carbon_footprint_from_known_ingredients_debug"} .= $ingredient_ref->{id}
					. " " . $ingredient_ref->{percent} . "% x $carbon_footprint_ingredient = " . $ingredient_ref->{percent} * $carbon_footprint_ingredient . " g - ";
				}
			}
		}

		if ($carbon_footprint > 0) {
			$product_ref->{nutriments}{"carbon-footprint-from-known-ingredients_100g"} = $carbon_footprint;
			$product_ref->{carbon_footprint_percent_of_known_ingredients} = $carbon_percent;

			defined $product_ref->{misc_tags} or $product_ref->{misc_tags} = [];
			add_tag($product_ref, "misc", "en:carbon-footprint-from-known-ingredients");
		}
	}
}


sub compute_carbon_footprint_from_meat_or_fish($) {

	my $product_ref = shift;

	if (defined $product_ref->{nutriments}) {
		delete $product_ref->{nutriments}{"carbon-footprint-from-meat-or-fish"};
		delete $product_ref->{nutriments}{"carbon-footprint-from-meat-or-fish_100g"};
		delete $product_ref->{nutriments}{"carbon-footprint-from-meat-or-fish_serving"};
		delete $product_ref->{nutriments}{"carbon-footprint-from-meat-or-fish_product"};
	}

	remove_tag($product_ref, "misc", "en:carbon-footprint-from-meat-or-fish");

	delete $product_ref->{"carbon_footprint_from_meat_or_fish_debug"};

	# Compute the carbon footprint from meat or fish ingredients, when the percentage is known

	#ingredients: [
	#{
	#rank: 1,
	#text: "Eau",
	#id: "en:water"
	#},
	#{
	#percent: "10.9",
	#text: "_saumon_",
	#rank: 2,
	#id: "en:salmon"
	#},
	my @parents = qw(
		en:beef-meat
		en:pork-meat
		en:veal-meat
		en:rabbit-meat
		en:chicken-meat
		en:turkey-meat
		en:smoked-salmon
		en:salmon
	);

	# Values from FoodGES

	my %carbon = (
		"en:beef-meat" => 35.8,
		"en:pork-meat" => 7.4,
		"en:veal-meat" => 20.5,
		"en:rabbit-meat" => 8.1,
		"en:chicken-meat" => 4.9,
		"en:turkey-meat" => 6.5,
		"en:smoked-salmon" => 5.5,
		"en:salmon" => 6.5,
		"en:smoked-trout" => 5.5,
		"en:trout" => 6.5,
	);

	# Limit to France, as the carbon values from ADEME are intended for France

	if ((has_tag($product_ref, "countries", "en:france")) and (defined $product_ref->{ingredients})) {

		my $carbon_footprint = 0;

		foreach my $ingredient_ref (@{$product_ref->{ingredients}}) {

			$log->debug("compute_carbon_footprint_from_meat_or_fish", { id =>  $ingredient_ref->{id} }) if $log->is_debug();

			if ((defined $ingredient_ref->{percent}) and ($ingredient_ref->{percent} > 0)) {

				$log->debug("compute_carbon_footprint_from_meat_or_fish", { percent =>  $ingredient_ref->{percent} }) if $log->is_debug();

				foreach my $parent (@parents) {
					if (is_a('ingredients', $ingredient_ref->{id}, $parent)) {
						$carbon_footprint += $ingredient_ref->{percent} * $carbon{$parent};
						$log->debug("found a parent with carbon footprint", { parent =>  $parent }) if $log->is_debug();

						if (not defined $product_ref->{"carbon_footprint_from_meat_or_fish_debug"}) {
							$product_ref->{"carbon_footprint_from_meat_or_fish_debug"} = "";
						}
						$product_ref->{"carbon_footprint_from_meat_or_fish_debug"} .= $ingredient_ref->{id} . " => " . $parent
						. " " . $ingredient_ref->{percent} . "% x $carbon{$parent} = " . $ingredient_ref->{percent} * $carbon{$parent} . " g - ";

						last;
					}
				}
			}
		}

		if ($carbon_footprint > 0) {
			$product_ref->{nutriments}{"carbon-footprint-from-meat-or-fish_100g"} = $carbon_footprint;
			$product_ref->{"carbon_footprint_from_meat_or_fish_debug"} =~ s/ - $//;
			defined $product_ref->{misc_tags} or $product_ref->{misc_tags} = [];
			add_tag($product_ref, "misc", "en:carbon-footprint-from-meat-or-fish");
		}
	}
}



sub extract_ingredients_from_image($$$$) {

	my $product_ref = shift;
	my $id = shift;
	my $ocr_engine = shift;
	my $results_ref = shift;

	my $lc = $product_ref->{lc};

	if ($id =~ /_(\w\w)$/) {
		$lc = $1;
	}

	extract_text_from_image($product_ref, $id, "ingredients_text_from_image", $ocr_engine, $results_ref);

	# remove nutrition facts etc.
	if (($results_ref->{status} == 0) and (defined $results_ref->{ingredients_text_from_image})) {

		$results_ref->{ingredients_text_from_image_orig} = $product_ref->{ingredients_text_from_image};
		$results_ref->{ingredients_text_from_image} = clean_ingredients_text_for_lang($results_ref->{ingredients_text_from_image}, $lc);

	}
}


# Words that can be ignored after a percent
# e.g. 50% du poids total, 30% of the total weight

my %ignore_strings_after_percent = (
	en => "of (the )?total weight",
	fr => "(min|min\.|mini|minimum)|(dans le chocolat( (blanc|noir|au lait))?)|(du poids total|du poids)",
);




sub extract_ingredients_from_text($) {

	my $product_ref = shift;
	my $path = product_path($product_ref->{code});

	return if not defined $product_ref->{ingredients_text};

	my $text = $product_ref->{ingredients_text};

	$log->debug("extracting ingredients from text", { text => $text }) if $log->is_debug();

	my $product_lc = $product_ref->{lc};

	$text = preparse_ingredients_text($product_lc, $text);

	$log->debug("preparsed ingredients from text", { text => $text }) if $log->is_debug();

	# Remove traces that have been preparsed
	# jus de pomme, eau, sucre. Traces possibles de c\x{e9}leri, moutarde et gluten.",
	# -> jus de pomme, eau, sucre. Traces éventuelles : céleri, Traces éventuelles : moutarde, Traces éventuelles : gluten.

	my $traces = $Lang{traces}{$product_lc};

	$text =~ s/\b($traces)\s?:\s?([^,\.]+)//ig;

	# unify newline feeds to \n
	$text =~ s/\r\n/\n/g;
	$text =~ s/\R/\n/g;

	# remove ending . and ending whitespaces
	$text =~ s/(\s|\.)+$//;

	# $product_ref->{ingredients_tags} = ["first-ingredient", "second-ingredient"...]
	# $product_ref->{ingredients}= [{id =>, text =>, percent => etc. }, ] # bio / équitable ?

	$product_ref->{ingredients} = [];
	$product_ref->{'ingredients_tags'} = [];

	# farine (12%), chocolat (beurre de cacao (15%), sucre [10%], protéines de lait, oeuf 1%) - émulsifiants : E463, E432 et E472 - correcteurs d'acidité : E322/E333 E474-E475, acidifiant (acide citrique, acide phosphorique) - sel : 1% ...

	my @ranked_ingredients = ();
	my @unranked_ingredients = ();
	my $level = 0;

	# Farine de blé 56 g* ; beurre concentré 25 g* (soit 30 g* en beurre reconstitué); sucre 22 g* ; œufs frais 2 g
	# 56 g -> 56%
	$text =~ s/(\d| )g(\*)/$1g/ig;

	# transform 0,2% into 0.2%
	$text =~ s/(\d),(\d+)( )?(\%|g\b)/$1.$2\%/ig;
	$text =~ s/—/-/g;

	# assume commas between numbers are part of the name
	# e.g. en:2-Bromo-2-Nitropropane-1,3-Diol, Bronopol
	# replace by a lower comma ‚

	$text =~ s/(\d),(\d)/$1‚$2/g;

	my $and = $Lang{_and_}{$product_lc};

	my $ignore_strings_after_percent = "";
	if (defined $ignore_strings_after_percent{$product_lc}) {
		$ignore_strings_after_percent = $ignore_strings_after_percent{$product_lc}
	}

	my $analyze_ingredients = sub($$$$$) {
		my $analyze_ingredients_self = shift;
		my $ranked_ingredients_ref = shift;
		my $unranked_ingredients_ref = shift;
		my $level = shift;
		my $s = shift;

		# print STDERR "analyze_ingredients level $level: $s\n";

		my $last_separator =  undef; # default separator to find the end of "acidifiants : E330 - E472"

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

		#print STDERR "s: $s\n";

		# find the first separator or ( or [ or :
		if ($s =~ $separators) {

			$before = $`;
			my $sep = $1;
			$after = $';

			# print STDERR "separator: $sep\tbefore: $before\tafter: $after\n";

			if ($sep =~ /(:|\[|\{|\()/i) {

				my $ending = $last_separator;
				if (not defined $ending) {
					$ending = ",|;|( $dashes )";
				}
				if ($sep eq '(') {
					$ending = '\)';
				}
				elsif ($sep eq '[') {
					$ending = '\]';
				}
				elsif ($sep eq '{') {
					$ending = '\}';
				}
				$ending .= '|$';
				$ending = '(' . $ending . ')';

				# print STDERR "special separator: $sep - ending: $ending - after: $after\n";

				# another separator before the ending separator ? we probably have several sub-ingredients
				if ($after =~ /^(.*?)$ending/i) {
					$between = $1;
					$after = $';

					# print STDERR "sub-ingredients - between: $between - after: $after\n";

					# sel marin (France, Italie)
					# -> if we have countries, put "origin:" before
					if (($between =~ $separators)
						and (exists_taxonomy_tag("countries", canonicalize_taxonomy_tag($product_lc, "countries", $`)))) {
						$between =~ s/^(.*?$separators)/origin:$1/;
					}

					# print STDERR "between: $between\n";

					# : is in $separators but we want to keep "origine : France"
					if (($between =~ $separators) and ($` !~ /\s*(origin|origine)\s*/i)) {
						$between_level = $level + 1;
					}
					else {
						# no separator found : 34% ? or single ingredient
						if ($between =~ /^\s*(\d+((\,|\.)\d+)?)\s*(\%|g)\s*$/i) {
							# print STDERR "percent found:  $1\%\n";
							$percent = $1;
							$between = '';
						}
						else {
							# label? (organic)
							# origin? (origine : France)

							# try to remove the origin and store it as property
							if ($between =~ /\s*(de origine|d'origine|origine|origin)\s?:?\s?\b(.*)$/i) {
								$between = '';
								my $origin_string = $2;
								# d'origine végétale -> not a geographic origin, add en:vegan
								if ($origin_string =~ /vegetal|végétal/i) {
									$vegan = "en:yes";
									$vegetarian = "en:yes";
								}
								else {
									$origin = $origin_string;
									$origin =~ s/^\s+//;
									$origin =~ s/\s+$//;
								}
							}
							else {

								# origin:   Fraise (France)
								my $countryid = canonicalize_taxonomy_tag($product_lc, "countries", $between);
								if (exists_taxonomy_tag("countries", $countryid)) {
									$origin = $countryid;
									$between = '';
								}
								# put origin first because the country can be associated with the label "Made in ..."
								else {

									my $labelid = canonicalize_taxonomy_tag($product_lc, "labels", $between);
									if (exists_taxonomy_tag("labels", $labelid)) {
										if (defined $labels) {
											$labels .= ", " . $labelid;
										}
										else {
											$labels = $labelid;
										}
										$between = '';
									}
								}
							}

							# single ingredient, stay at same level
							# print STDERR "single ingredient, stay at same level\n";
						}
					}
				}
				else {
					# print STDERR "could not find ending separator: $ending - after: $after\n"
					# ! could not find the ending separator
				}

			}
			else {
				# simple separator
				$last_separator = $sep;
			}

			if ($after =~ /^\s*(\d+((\,|\.)\d+)?)\s*(\%|g)\s*($ignore_strings_after_percent|\s|\)|\]|\}|\*)*($separators|$)/i) {
				# print STDERR "percent found: $after = $1 + $'\%\n";
				$percent = $1;
				$after = $';
			}
		}
		else {
			# no separator found: only one ingredient
			# print STDERR "no separator found: $s\n";
			$before = $s;
		}

		# remove ending parenthesis
		$before =~ s/(\),\],\])*//;

		my @ingredients = ();

		# 2 known ingredients separated by "and" ?
		if ($before =~ /$and/i) {

			my $ingredient = $before;
			my $ingredient1 = $`;
			my $ingredient2 = $';

			# Remove percent

			my $ingredient1_orig = $ingredient1;
			my $ingredient2_orig = $ingredient2;

			$ingredient =~ s/\s*(\d+((\,|\.)\d+)?)\s*(\%|g)\s*($ignore_strings_after_percent|\s|\)|\]|\}|\*)*$//i;
			$ingredient1 =~ s/\s*(\d+((\,|\.)\d+)?)\s*(\%|g)\s*($ignore_strings_after_percent|\s|\)|\]|\}|\*)*$//i;
			$ingredient2 =~ s/\s*(\d+((\,|\.)\d+)?)\s*(\%|g)\s*($ignore_strings_after_percent|\s|\)|\]|\}|\*)*$//i;

			# check if the whole ingredient is an ingredient
			my $canon_ingredient = canonicalize_taxonomy_tag($product_lc, "ingredients", $before);

			# print STDERR "before: $before - canon_ingredient: $canon_ingredient\n";

			if (not exists_taxonomy_tag("ingredients", $canon_ingredient)) {

				# otherwise check the 2 sub ingredients
				my $canon_ingredient1 = canonicalize_taxonomy_tag($product_lc, "ingredients", $ingredient1);
				my $canon_ingredient2 = canonicalize_taxonomy_tag($product_lc, "ingredients", $ingredient2);

				# print STDERR "canon_ingredient1 - $canon_ingredient1\n";
				# print STDERR "canon_ingredient2 - $canon_ingredient2\n";

				if ( (exists_taxonomy_tag("ingredients", $canon_ingredient1))
					and (exists_taxonomy_tag("ingredients", $canon_ingredient2)) ) {
					push @ingredients, $ingredient1_orig;
					push @ingredients, $ingredient2_orig;
				}
			}
		}

		if (scalar @ingredients == 0) {
			push @ingredients, $before;
		}

		foreach my $ingredient (@ingredients) {

			chomp($ingredient);

			# Strawberry 10.3%
			if ($ingredient =~ /\s*(\d+((\,|\.)\d+)?)\s*(\%|g)\s*($ignore_strings_after_percent|\s|\)|\]|\}|\*)*$/i) {
				# print STDERR "percent found: $before = $` + $1\%\n";
				$percent = $1;
				$ingredient = $`;
			}

			# 90% boeuf, 100% pur jus de fruit, 45% de matière grasses
			if ($ingredient =~ /^\s*(\d+((\,|\.)\d+)?)\s*(\%|g)\s*(pur|de|d')?\s*/i) {
				# print STDERR "'x% something' : percent found: $before = $' + $1\%\n";
				$percent = $1;
				$ingredient = $';
			}

			# remove * and other chars before and after the name of ingredients
			$ingredient =~ s/(\s|\*|\)|\]|\}|$stops|$dashes|')+$//;
			$ingredient =~ s/^(\s|\*|\)|\]|\}|$stops|$dashes|')+//;

			$ingredient =~ s/\s*(\d+((\,|\.)\d+)?)\s*\%\s*$//;

			# try to remove the origin and store it as property
			if ($ingredient =~ /\b(de origine|d'origine|origine|origin)\s?:?\s?\b/i) {
				$ingredient = $`;
				my $origin_string = $';
				# d'origine végétale -> not a geographic origin, add en:vegan
				if ($origin_string =~ /vegetal|végétal/i) {
					$vegan = "en:yes";
					$vegetarian = "en:yes";
				}
				else {
					$origin = $origin_string;
					$origin =~ s/^\s+//;
					$origin =~ s/\s+$//;
				}
			}

			if (defined $labels_regexps{$product_lc}) {
				# start with uncomposed labels first, so that we decompose "fair-trade organic" into "fair-trade, organic"
				foreach my $labelid (reverse @labels) {
					my $regexp = $labels_regexps{$product_lc}{$labelid};
					#print STDERR "labelid: $labelid - regexp: $regexp - ingredient: $ingredient\n";
					if ((defined $regexp) and ($ingredient =~ /\b($regexp)\b/i)) {
						if (defined $labels) {
							$labels .= ", " . $labelid;
						}
						else {
							$labels = $labelid;
						}
						$ingredient = $` . ' ' . $';
						$ingredient =~ s/\s+/ /g;
					}
				}
			}

			$ingredient =~ s/^\s+//;
			$ingredient =~ s/\s+$//;

			my $ingredient_id = canonicalize_taxonomy_tag($product_lc, "ingredients", $ingredient);
			my $skip_ingredient = 0;
			my $ingredient_recognized = 0;

			if (exists_taxonomy_tag("ingredients", $ingredient_id)) {
				$ingredient_recognized = 1;
			}
			else {

				# Try to remove ingredients processing "cooked rice" -> "rice"
				if (defined $ingredients_processing_regexps{$product_lc}) {
					my $matches = 0;
					my $new_ingredient = $ingredient;
					my $new_processing = '';
					foreach my $ingredient_processing_regexp_ref (@{$ingredients_processing_regexps{$product_lc}}) {
						my $regexp = $ingredient_processing_regexp_ref->[1];
						if ($new_ingredient =~ /\b($regexp)\b/i) {
							$new_ingredient = $` . $';
							print STDERR "ingredient $ingredient matches regexp for processing $processing : $regexp\n";
							print STDERR "new ingredient: $new_ingredient\n";
							$matches++;
							$new_processing .= ", " . $ingredient_processing_regexp_ref->[0];
						}
					}
					if ($matches) {
						# remove starting or ending " and "
						# viande traitée en salaison et cuite -> viande et
						$new_ingredient =~ s/($and)+$//i;
						$new_ingredient =~ s/^($and)+//i;
						my $new_ingredient_id = canonicalize_taxonomy_tag($product_lc, "ingredients", $new_ingredient);
						if (exists_taxonomy_tag("ingredients", $new_ingredient_id)) {
							print STDERR "new_ingredient_id $new_ingredient_id exists\n";
							$ingredient = $new_ingredient;
							$ingredient_id = $new_ingredient_id;
							$ingredient_recognized = 1;
							$processing .= $new_processing;
						}
						else {
							print STDERR "new_ingredient_id $new_ingredient_id does not exist\n";
						}
					}
				}

				if (not $ingredient_recognized) {
					# Unknown ingredient, check if it is a label
					my $label_id = canonicalize_taxonomy_tag($product_lc, "labels", $ingredient);
					if (exists_taxonomy_tag("labels", $label_id)) {
						# Add the label to the product
						add_tags_to_field($product_ref, $product_lc, "labels", $label_id);
						compute_field_tags($product_ref, $product_lc, "labels");
						$skip_ingredient = 1;
						$ingredient_recognized = 1;
					}
				}

				if (not $ingredient_recognized) {
					# Check if it is a phrase we want to ignore

					# Remove some sentences
					my %ignore_regexps = (
						'fr' => [
							'(\%|pourcentage|pourcentages) (.*)(exprim)',
							'(sur|de) produit fini',	# préparé avec 50g de fruits pour 100g de produit fini
							'pour( | faire | fabriquer )100',	# x g de XYZ ont été utilisés pour fabriquer 100 g de ABC
							'contenir|présence',	# présence exceptionnelle de ... peut contenir ... noyaux etc.
							'^soit ',	# soit 20g de beurre reconstitué
							'^équivalent ', # équivalent à 20% de fruits rouges
							'^malgré ', # malgré les soins apportés...
							'^il est possible', # il est possible qu'il contienne...
							'^(facultatif|facultative)', # sometime indicated by producers when listing ingredients is not mandatory
						],
					);
					if (defined $ignore_regexps{$product_lc}) {
						foreach my $regexp (@{$ignore_regexps{$product_lc}}) {
							if ($ingredient =~ /$regexp/i) {
								print STDERR "ignoring ingredient $ingredient - regexp $regexp\n";
								$skip_ingredient = 1;
								$ingredient_recognized = 1;
								last;
							}
						}
					}
				}
			}

			if (not $skip_ingredient) {

				my %ingredient = (
					id => $ingredient_id,
					text => $ingredient
				);

				# Record if the ingredient has sub-ingredients
				# useful for ingredients that are specified
				# like "vegetable oils (sunflower oil, palm oil)

				if ($between ne '') {
					$ingredient{has_sub_ingredients} = "yes";
				}

				if (defined $percent) {
					$ingredient{percent} = $percent;
				}
				if (defined $origin) {
					$ingredient{origin} = $origin;
				}
				if (defined $labels) {
					$ingredient{labels} = $labels;
				}
				if (defined $vegan) {
					$ingredient{vegan} = $vegan;
				}
				if (defined $vegetarian) {
					$ingredient{vegetarian} = $vegetarian;
				}
				if ($processing ne "") {
					$processing =~ s/^,\s?//;
					$ingredient{processing} = $processing;
				}

				if ($ingredient ne '') {

					# ingredients tags that are too long (greater than 1024, mongodb max index key size)
					# will cause issues for the mongodb ingredients_tags index, just drop them

					if (length($ingredient{id}) < 500) {
						if ($level == 0) {
							push @$ranked_ingredients_ref, \%ingredient;
						}
						else {
							push @$unranked_ingredients_ref, \%ingredient;
						}
					}
				}
			}

		}

		if ($between ne '') {
			$analyze_ingredients_self->($analyze_ingredients_self, $ranked_ingredients_ref, $unranked_ingredients_ref , $between_level, $between);
		}

		if ($after ne '') {
			$analyze_ingredients_self->($analyze_ingredients_self, $ranked_ingredients_ref, $unranked_ingredients_ref , $level, $after);
		}

	};

	$analyze_ingredients->($analyze_ingredients, \@ranked_ingredients, \@unranked_ingredients , 0, $text);

	for (my $i = 0; $i <= $#ranked_ingredients; $i++) {
		$ranked_ingredients[$i]{rank} = $i + 1;
	}

	foreach my $ingredient (@ranked_ingredients, @unranked_ingredients) {
		push @{$product_ref->{ingredients}}, $ingredient;
		push @{$product_ref->{ingredients_tags}}, $ingredient->{id};
	}

	my $field = "ingredients";

	$product_ref->{ingredients_original_tags} = $product_ref->{ingredients_tags};

	if (defined $taxonomy_fields{$field}) {
		$product_ref->{$field . "_hierarchy" } = [ gen_ingredients_tags_hierarchy_taxonomy($product_lc, join(", ", @{$product_ref->{ingredients_original_tags}} )) ];
		$product_ref->{$field . "_tags" } = [];
		my $unknown = 0;
		foreach my $tag (@{$product_ref->{$field . "_hierarchy" }}) {
			my $tagid = get_taxonomyid($product_lc, $tag);
			push @{$product_ref->{$field . "_tags" }}, $tagid;
			if (not exists_taxonomy_tag("ingredients", $tagid)) {
				$unknown++;
			}
		}
		$product_ref->{"unknown_ingredients_n" } = $unknown;
	}


	if ($product_ref->{ingredients_text} ne "") {

		$product_ref->{ingredients_n} = scalar @{$product_ref->{ingredients_original_tags}};

		my $d = int(($product_ref->{ingredients_n} - 1 ) / 10);
		my $start = $d * 10 + 1;
		my $end = $d * 10 + 10;

		$product_ref->{ingredients_n_tags} = [$product_ref->{ingredients_n} . "", "$start" . "-" . "$end"];
		# ensure $product_ref->{ingredients_n} is last used as an int so that it is not saved as a strings
		$product_ref->{ingredients_n} += 0;
	}
	else {
		delete $product_ref->{ingredients_n};
		delete $product_ref->{ingredients_n_tags};
	}

	analyze_ingredients($product_ref);
}


# Analyze ingredients to see the ones that are vegan, vegetarian, from palm oil etc.
# and compute the resulting value for the complete product

sub analyze_ingredients($) {

	my $product_ref = shift;

	delete $product_ref->{ingredients_analysis_tags};

	if ((scalar @{$product_ref->{ingredients}}) > 0) {

		my @properties = ("from_palm_oil", "vegan", "vegetarian");

		$product_ref->{ingredients_analysis_tags} = [];

		foreach my $property (@properties) {

			my %values = ( all_ingredients => 0, unknown_ingredients => 0);

			foreach my $ingredient_ref (@{$product_ref->{ingredients}}) {

				$values{all_ingredients}++;

				# We may already have a value. e.g. for "matières grasses d'origine végétale" or "gélatine (origine végétale)"
				my $value = $ingredient_ref->{$property};

				if (not defined $value) {

					my $ingredientid = $ingredient_ref->{id};
					$value = get_inherited_property("ingredients", $ingredientid, $property . ":en");

					if (defined $value) {
						$ingredient_ref->{$property} = $value;
					}
					else {
						if (not (exists_taxonomy_tag("ingredients", $ingredientid))) {
							$values{unknown_ingredients}++;
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
				if (($property eq "from_palm_oil") and (defined $value) and ($value eq "maybe")
					and (defined $ingredient_ref->{has_sub_ingredients}) and ($ingredient_ref->{has_sub_ingredients} eq "yes")) {
					$value = "ignore";
				}

				not defined $value and $value = "undef";

				defined $values{$value} or $values{$value} = 0;
				$values{$value}++;

				# print STDERR "ingredientid: $ingredientid - property: $property - value: $value\n";
			}

			if ($property =~ /^from_/) {

				my $from_what = $';

				# For properties like from_palm, one positive ingredient triggers a positive result for the whole product
				# We assume that all the positive ingredients have been marked as yes or maybe in the taxonomy
				# So all known ingredients without a value for the property are assumed to be negative

				# value can can be "ignore"

				if (defined $values{yes}) {
					# One yes ingredient -> yes for the whole product
					push @{$product_ref->{ingredients_analysis_tags}}, "en:" . $from_what ; # en:palm-oil
				}
				elsif (defined $values{maybe}) {
					# One maybe ingredient -> maybe for the whole product
					push @{$product_ref->{ingredients_analysis_tags}}, "en:may-contain-" . $from_what ; # en:may-contain-palm-oil
				}
				elsif ($values{unknown_ingredients} > 0) {
					# Some ingredients were not recognized
					push @{$product_ref->{ingredients_analysis_tags}}, "en:" . $from_what . "-content-unknown"; # en:palm-oil-content-unknown
				}
				else {
					# no yes, maybe or unknown ingredients
					push @{$product_ref->{ingredients_analysis_tags}}, "en:" . $from_what . "-free"; # en:palm-oil-free
				}
			}
			else {

				# For properties like vegan or vegetarian, one negative ingredient triggers a negative result for the whole product
				# Known ingredients without a value for the property: we do not make any assumption
				# We assume that all the positive ingredients have been marked as yes or maybe in the taxonomy
				# So all known ingredients without a value for the property are assumed to be negative

				if (defined $values{no}) {
					# One no ingredient -> no for the whole product
					push @{$product_ref->{ingredients_analysis_tags}}, "en:non-" . $property ; # en:non-vegetarian
				}
				elsif (defined $values{undef}) {
					# Some ingredients were not recognized or we do not have a property value for them
					push @{$product_ref->{ingredients_analysis_tags}}, "en:" . $property . "-status-unknown"; # en:vegetarian-status-unknown
				}
				elsif (defined $values{maybe}) {
					# One maybe ingredient -> maybe for the whole product
					push @{$product_ref->{ingredients_analysis_tags}}, "en:maybe-" . $property ; # en:maybe-vegetarian
				}
				else {
					# all ingredients known and with a value, no no or maybe value -> yes
					push @{$product_ref->{ingredients_analysis_tags}}, "en:" . $property ; # en:vegetarian
				}
			}

			for (my $i = 0; $i < scalar(@{$product_ref->{ingredients_analysis_tags}}); $i++) {
				$product_ref->{ingredients_analysis_tags}[$i] =~ s/_/-/g;
			}
		}
	}
}


# function to normalize strings like "Carbonate d'ammonium" in French
# x is the prefix
# y can contain de/d' (of in French)
sub normalize_fr_a_de_b($$) {

	my $a = shift;
	my $b = shift;

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

sub normalize_fr_a_de_enumeration {

	my $a = shift;

	return join(", ", map { normalize_fr_a_de_b($a, $_)} @_);
}

# English: oil, olive -> olive oil
# French: huile, olive -> huile d'olive

sub normalize_a_of_b($$$) {

	my $lc = shift;
	my $a = shift;
	my $b = shift;

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
}


# Vegetal oil (palm, sunflower and olive)
# -> palm vegetal oil, sunflower vegetal oil, olive vegetal oil

sub normalize_enumeration($$$) {

	my $lc = shift;
	my $type = shift;
	my $enumeration = shift;

	$log->debug("normalize_enumeration", { type => $type, enumeration => $enumeration }) if $log->is_debug();

	my $and = $Lang{_and_}{$lc};
	#my $enumeration_separators = $obrackets . '|' . $cbrackets . '|\/| \/ | ' . $dashes . ' |' . $commas . ' |' . $commas. '|'  . $Lang{_and_}{$lc};

	my @list = split(/$obrackets|$cbrackets|\/| \/ | $dashes |$commas |$commas|$and/i, $enumeration);

	return join(", ", map { normalize_a_of_b($lc, $type, $_)} @list);
}


# iodure et hydroxide de potassium
sub normalize_fr_a_et_b_de_c($$$) {

	my $a = shift;
	my $b = shift;
	my $c = shift;

	return normalize_fr_a_de_b($a, $c) . ", " . normalize_fr_a_de_b($b, $c);
}

sub normalize_additives_enumeration($$) {

	my $lc = shift;
	my $enumeration = shift;

	$log->debug("normalize_additives_enumeration", { enumeration => $enumeration }) if $log->is_debug();

	my $and = $Lang{_and_}{$lc};

	my @list = split(/$obrackets|$cbrackets|\/| \/ | $dashes |$commas |$commas|$and/i, $enumeration);

	return join(", ", map { "E" . $_} @list);
}


sub normalize_vitamin($$) {

	my $lc = shift;
	my $a = shift;

	$log->debug("normalize vitamin", { vitamin => $a }) if $log->is_debug();

	$a =~ s/\s+$//;
	$a =~ s/^\s+//;

	# does it look like a vitamin code?
	if ($a =~ /^[a-z][a-z]?-? ?\d?\d?$/i) {
		($lc eq 'es') and return "vitamina $a";
		($lc eq 'fr') and return "vitamine $a";
		return "vitamin $a";
	}
	else {
		return $a;
	}
}

sub normalize_vitamins_enumeration($$) {

	my $lc = shift;
	my $vitamins_list = shift;

	my $and = $Lang{_and_}{$lc};

	my @vitamins = split(/\(|\)|\/| \/ | - |, |,|$and/, $vitamins_list);

	$log->debug("splitting vitamins", { input => $vitamins_list }) if $log->is_debug();

	# first output "vitamines," so that the current additive class is set to "vitamins"
	my $split_vitamins_list;

	if ($lc eq 'es') { $split_vitamins_list = "vitaminas" }
	elsif ($lc eq 'fr') { $split_vitamins_list = "vitamines" }
	else { $split_vitamins_list = "vitamine" }

	$split_vitamins_list .= ", " . join(", ", map { normalize_vitamin($lc,$_)} @vitamins);

	$log->debug("vitamins split", { input => $vitamins_list, output => $split_vitamins_list }) if $log->is_debug();

	return $split_vitamins_list;
}


sub normalize_allergen($$$) {

	my $type = shift; # allergens or traces
	my $lc = shift;
	my $a = shift;

	$log->debug("normalize allergen", { allergen => $a }) if $log->is_debug();

	my $of = ' - ';
	if (defined $of{$lc}) {
		$of = $of{$lc};
	}

	# "de moutarde" -> moutarde
	$a = " " . $a;
	$a =~ s/^$of\b//;
	$a =~ s/\s+$//;
	$a =~ s/^\s+//;

	return $Lang{$type}{$lc} . " : " . $a;
}

sub normalize_allergens_enumeration($$$) {

	my $type = shift; # allergens or traces
	my $lc = shift;
	my $allergens_list = shift;

	my $and = $Lang{_and_}{$lc};

	$log->debug("splitting allergens", { input => $allergens_list }) if $log->is_debug();

	# remove stopwords at the end
	# e.g. Kann Spuren von Senf und Sellerie enthalten.
	if (defined $allergens_stopwords{$lc}) {
		my $stopwords = $allergens_stopwords{$lc};
		$allergens_list =~ s/( ($stopwords)\b)+(\.|$)/$3/ig;
	}

	$log->debug("splitting allergens after removing stopwords", { input => $allergens_list }) if $log->is_debug();

	my @allergens = split(/\(|\)|\/| \/ | - |, |,|$and/, $allergens_list);

	my $split_allergens_list =  " " . join(", ", map { normalize_allergen($type,$lc,$_)} @allergens) . ".";
	# added ending . to facilite matching and removing when parsing ingredients

	$log->debug("allergens split", { input => $allergens_list, output => $split_allergens_list }) if $log->is_debug();

	return $split_allergens_list;
}


my %phrases_before_ingredients_list = (

fr => [

'ingr(e|é)dients(\s*)(-|:|\r|\n)+',	# need a colon or a line feed
'Quels Ingr(e|é)dients ?', # In Casino packagings
'ingr(e|é)dient(\s*)(-|:|\r|\n)+',
'composition(\s*)(-|:|\r|\n)+',
#'ingr(e|é)dienits(\s*)(-|:|\r|\n)+',
#'rédients(\s*)(-|:|\r|\n)+', # in case OCR cuts the word https://world.openfoodfacts.org/product/4024297006305/mayonnaise-demeter-en-tube-naturata
],


de => [

'zutaten(\s*)(-|:|\r|\n)+',	# need a colon or a line feed
#@hangy Does that regex handle zutat: ?
],

es => [

'ingredientes(\s*)(\s|-|:|\r|\n)+',	# need a colon or a line feed

],

it => [

'ingredienti(\s*)(\s|-|:|\r|\n)+',	# need a colon or a line feed

],

cs => [
'složení(\s*)(\s|-|:|\r|\n)+',
'Složeni(\s*)(\s|-|:|\r|\n)+',
],

pt => [
'ingredientes(\s*)(\s|-|:|\r|\n)+',
],

pl => [
'składniki(\s*)(\s|-|:|\r|\n)+',
],

si => [
'sestavine(\s*)(\s|-|:|\r|\n)+',
],

it => [
'ingredienti(\s*)(\s|-|:|\r|\n)+',
],

nl => [
'ingredi(e|ë)nten(\s*)(\s|-|:|\r|\n)+',
],

de => [
'zutaten(\s*)(\s|-|:|\r|\n)+',
],

fi => [
'ainesosat(\s*)(\s|-|:|\r|\n)+',
],

sv => [
'ingredienser(\s*)(\s|-|:|\r|\n)+',
],

dk => [
'ingredienser(\s*)(\s|-|:|\r|\n)+',
],

ru => [
'Состав(\s*)(\s|-|:|\r|\n)+',
'Ингредиенты(\s*)(\s|-|:|\r|\n)+',
],

hr => [
'(ö|ő|o)sszetev(ö|ő|o)k(\s*)(\s|-|:|\r|\n)+',
],

el => [
'Συστατικά(\s|-|:|\r|\n)+',
],

);


my %phrases_before_ingredients_list_uppercase = (

fr => [

'INGR(E|É)(D|0|O)IENTS(\s*)(\s|-|:|\r|\n)+',	# need a colon or a line feed
'INGR(E|É)DIENT(\s*)(-|:|\r|\n)+',

],

cs => [
'SLOŽENÍ(\s*)(-|:|\r|\n)+',
],

de => [
'ZUTAT(EN)(\s*)(-|:|\r|\n)+',	# need a colon or a line feed
#@hangy Does that regex handle ZUTAT: ?
#'ZUTAT(\s*)(-|:|\r|\n)+',
],

es => [
'INGREDIENTES(\s*)(\s|-|:|\r|\n)+',
],


hu => [
'(Ö|O|0)SSZETEVOK(\s*)(\s|-|:|\r|\n)+',
],


pt => [

'INGREDIENTES(\s*)(\s|-|:|\r|\n)+',

],

pl => [
'SKŁADNIKI(\s*)(\s|-|:|\r|\n)+',
],

it => [

'INGREDIENTI(\s*)(\s|-|:|\r|\n)+',
],

nl => [
'INGREDI(E|Ë)NTEN(\s*)(\s|-|:|\r|\n)+',
],

de => [
'ZUTATEN(\s*)(\s|-|:|\r|\n)+',
],

fi => [
'AINESOTAT(\s*)(\s|-|:|\r|\n)+',
],

si => [
'SESTAVINE(\s*)(\s|-|:|\r|\n)+',
],

sv => [
'INGREDIENSER(\s*)(\s|-|:|\r|\n)+',
],

dk => [
'INGREDIENSER(\s*)(\s|-|:|\r|\n)+',
],

vi => [
'THANH PHAN(\s*)(\s|-|:|\r|\n)+',
],



);


my %phrases_after_ingredients_list = (

# TODO: Introduce a common list for kcal

fr => [

'(va(l|t)eurs|informations|d(e|é)claration|analyse|rep(e|è)res) (nutritionnel)',
'caractéristiques nu(t|f)ritionnelles',
'valeurs mo(y|v)ennes',
'valeurs nutritionelles moyennes',
'valeur nutritionnelle mo(y|v)enne',
'valeur nutritionnelle',
'information nutritionnelle',
'nutritionnelles mo(y|v)ennes', 	# in case of ocr issue on the first word "valeurs" v in case the y is cut halfway
'nutritionnelles pour 100(g|ml)', #Arôme Valeum nutritionnelles pour 100g: Energie
'moyennes pour 100(g|ml)',
'Nutrition pour 100 (g|ml)',
'valeur(s?) (e|é)nerg(e|é)tique',
'valeur(s?) nutritives',
'valeur nutritive',
'apport de r(e|é)ference pour un adulte type',
'((\d+)(\s?)kJ\s+)?(\d+)(\s?)kcal',
'(a|à) consommer de préférence',
'(a|à) consommer de',
'de préférence avant le',
'(a|à) cons.de préférence avant',
'(conseil|conseils) de pr(e|é)paration',
'(conditions|conseils) de conservation',
'conseil d\'utilisation',
'conservation:',
'(a|à) protéger de ', # humidité, chaleur, lumière etc.
'conditionn(e|é) sous atmosph(e|è)re protectrice',
'la pr(e|é)sence de vide',	# La présence de vide au fond du pot est due au procédé de fabrication.
'(a|à) consommer (cuit|rapidement|dans|jusqu)',
'(a|à) conserver (dans|de|a|à)',
'(a|à)conserver (dans|de|a|à)', #variation
'(a|à)conserver entre',
'apr(e|è)s (ouverture|achat)',
'dans le compartiment (a|à) gla(c|ç)ons',
'pr(e|é)paration au four',
'dont sucres',
'dont acides (gras|ras) satur(e|é)s',
'N(o|ò)us vous conseillons',
'ne jamais recongeler un produit décongelé',
'pensez au tri',
'tenir à l\'abri',
'Modes de pr(e|é)paration',
'Mode de pr(e|é)paration',
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

en => [

'nutritional values',
'after opening',
'nutrition values',
'of whlch saturates',
'of which saturates',
'of which saturated fat',
'((\d+)(\s?)kJ\s+)?(\d+)(\s?)kcal',
'once opened keep in the refrigerator',
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
'conservar en lug(a|e)r fresco y seco',
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

de => [
'Ern(â|a|ä)hrungswerte',
'Vorbereitung Tipps',
'Mindestens altbar bis',
'Mindestens haltbar bis',
'Durchschnittliche N(â|a|ä)hrwerte',
'DURCHSCHNITTLICHE NÄHRWERTE',
'Durchschnittliche N(â|a|ä)hrwert(angaben|angabe)',
'N(â|a|ä)hrwert(angaben|angabe|information|tabelle)', #Nährwertangaben pro 100g
'N(â|a|ä)hrwerte je',
'davon ges(â|a|ä)ttigte',
'Nâhrwerte',
'k(u|ü)hl und trocken lagern',
'Vor W(â|a|ä)rme und Feuchtigkeit sch(u|ü)tzen',
'Unge(ö|o)ffnet bei max.',
'zu verbrauchen bis',
'verbrauchen bis',
'100 (ml|g) enthalten durchschnittlich',
'Durchschnittlich enthalten 100 (ml|g)',
'davon ges(â|a|ä)tigte Fettsäuren',
'davon Zuckerarten',
],

nl => [
'voedingswaarden',
'voedingswaarde',
'voorbereidingstips',
'gemiddelde voedingswaarden',
'Gemiddeldevoedingswaardel',
'gemiddelde voedingswaarde per 100 g',
#'waarvan suikers',
],

it => [
'valori nutrizionali',
'consigli per la preparazione',
'di cui zuccheri',
'Valori nutritivi',
'Conservare in luogo fresco e asciutto',
'MODALITA D\'USO',
'MODALITA DI CONSERVAZIONE',
'Preparazione:',
],

cs => [
'doporučeny způsob přípravy',
],

ja => [
'栄養価',
],

pt => [
'conservar em local fresco',
'conservar em lugar fresco',
'dos quais a(ç|c)(u|ü)ares',
'dos quais a(ç|c)(u|ü)cares',
'informa(ç|c)(a|ã)o nutricional',
'modo de prepara(ç|c)(a|ã)o',
'a consumir de prefer(e|ê)ncia antes do',
'consumir de prefer(e|ê)ncia antes do',
],

pl => [
'przechowywać w chlodnym i ciemnym miejscu', #keep in a dry and dark place
'n(a|o)jlepiej spożyć przed', #Best before
'Przechowywanie',
],

ro => [
'declaratie nutritional(a|ă)',
'a si pastra la frigider dup(a|ă) deschidere',
'a se agita inainte de deschidere',
'Valori nutritionale medii',
],

cs => [
'V(ý|y)(ž|z)ivov(e|é) (ú|u)daje ve 100 g',
],

hr => [
'Atlagos tápérték 100g termékben',
],

el => [
'ΔΙΑΘΡΕΠΤΙΚΗ ΕΠΙΣΗΜΑΝΣΗ', #Nutritional labelling
'ΔΙΤΡΟΦΙΚΕΣ ΠΗΡΟΦΟΡΙΕΣ',
],

vi => [
'GI(Á|A) TR(Ị|I) DINH D(Ư|U)(Ỡ|O)NG (TRONG|TRÊN)',
],

dk => [
'N(æ|ae)ringsindhold',
],


);


# turn demi - écrémé to demi-écrémé
my %prefixes_before_dash  = (
fr => [
'demi',
'saint',
],
);


# phrases that can be removed
my %ignore_phrases = (
en => [
"na|n/a|not applicable",
],
fr => [
"non applicable|non concerné",
],

);


sub clean_ingredients_text_for_lang($$) {

	my $text = shift;
	my $language = shift;

	# turn demi - écrémé to demi-écrémé

	if (defined $prefixes_before_dash{$language}) {

		foreach my $prefix (@{$prefixes_before_dash{$language}}) {
			$text =~ s/\b($prefix) - (\w)/$1-$2/is;
		}
	}

	# Remove phrases before ingredients list lowercase

	$log->debug("clean_ingredients_text_for_lang - 1", { language=>$language, text=>$text }) if $log->is_debug();

	if (defined $phrases_before_ingredients_list{$language}) {

		foreach my $regexp (@{$phrases_before_ingredients_list{$language}}) {
			$text =~ s/^(.*)$regexp(\s*)//is;
		}
	}

	# Remove phrases before ingredients list UPPERCASE

	$log->debug("clean_ingredients_text_for_lang - 2", { language=>$language, text=>$text }) if $log->is_debug();

	if (defined $phrases_before_ingredients_list_uppercase{$language}) {

		foreach my $regexp (@{$phrases_before_ingredients_list_uppercase{$language}}) {
			# INGREDIENTS followed by lowercase
			$text =~ s/^(.*)$regexp(\s*)(?=(\w?)(\w?)[a-z])//s;
		}
	}

	# Remove phrases after ingredients list

	$log->debug("clean_ingredients_text_for_lang - 3", { language=>$language, text=>$text }) if $log->is_debug();

	if (defined $phrases_after_ingredients_list{$language}) {

		foreach my $regexp (@{$phrases_after_ingredients_list{$language}}) {
			$text =~ s/\s*$regexp(.*)$//is;
		}
	}

	# Remove phrases

	$log->debug("clean_ingredients_text_for_lang - 4", { language=>$language, text=>$text }) if $log->is_debug();

	if (defined $ignore_phrases{$language}) {

		foreach my $regexp (@{$ignore_phrases{$language}}) {
			$text =~ s/^\s*$regexp(\.)?\s*$//is;
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

	$log->debug("clean_ingredients_text_for_lang - 5", { language=>$language, text=>$text }) if $log->is_debug();

	return $text;
}



sub clean_ingredients_text($) {

	my $product_ref = shift;

	if (defined $product_ref->{languages_codes}) {

		foreach my $language (keys %{$product_ref->{languages_codes}}) {

			if (defined $product_ref->{"ingredients_text_" . $language }) {

				my $text = $product_ref->{"ingredients_text_" . $language };

				$text = clean_ingredients_text_for_lang($text, $language);

				if ($text ne $product_ref->{"ingredients_text_" . $language }) {

					my $time = time();

					# Keep a copy of the original ingredients list just in case
					$product_ref->{"ingredients_text_" . $language . "_ocr_" . $time} = $product_ref->{"ingredients_text_" . $language };
					$product_ref->{"ingredients_text_" . $language . "_ocr_" . $time . "_result"} = $text;
					$product_ref->{"ingredients_text_" . $language } = $text;
				}

				if ($language eq $product_ref->{lc}) {
					$product_ref->{"ingredients_text"} = $product_ref->{"ingredients_text_" . $language };
				}
			}
		}
	}
}


sub is_compound_word_with_dash($$) {

	my $word_lc = shift;
	my $compound_word = shift;

	print STDERR "compound_word: $compound_word\n";

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
sub separate_additive_class($$$$$) {

	my $product_lc = shift;
	my $additive_class = shift;
	my $spaces = shift;
	my $colon = shift;
	my $after = shift;

	my $and = $Lang{_and_}{$product_lc};

	# check that we have an additive after the additive class
	# keep only what is before the first separator
	$after =~ s/^$separators+//;
	#print STDERR "separate_additive_class - after 1 : $after\n";
	$after =~ s/^(.*?)$separators(.*)$/$1/;
	#print STDERR "separate_additive_class - after 2 : $after\n";

	# also look if we have additive 1 and additive 2
	my $after2;
	if ($after =~ /$and/) {
		$after2 = $`;
	}

	if (exists_taxonomy_tag("additives", canonicalize_taxonomy_tag($product_lc, "additives", $after) )
		or ((defined $after2) and exists_taxonomy_tag("additives", canonicalize_taxonomy_tag($product_lc, "additives", $after2) ))
	) {
		#print STDERR "separate_additive_class - after is an additive\n";
		return $additive_class . " : ";
	}
	else {
		#print STDERR "separate_additive_class - after is not an additive\n";
		return $additive_class . $spaces . $colon;
	}
}


sub preparse_ingredients_text($$) {

	my $product_lc = shift;
	my $text = shift;

	if ((scalar keys %labels_regexps) == 0) {
		init_labels_regexps();
		init_ingredients_processing_regexps();
		init_additives_classes_regexps();
	}

	my $and = $Lang{_and_}{$product_lc};
	my $of = ' - ';
	if (defined $of{$product_lc}) {
		$of = $of{$product_lc};
	}

	my $and_of = ' - ';
	if (defined $and_of{$product_lc}) {
		$and_of = $and_of{$product_lc};
	}

	# replace and / or by and
	my $and_or = ' - ';
	if (defined $and_or{$product_lc}) {
		$and_or = $and_or{$product_lc};
		$text =~ s/$and_or/$and/ig;
	}

	$text =~ s/\&quot;/"/g;
	$text =~ s/’/'/g;

	# turn special chars to spaces
	$text =~ s/[\000-\037]/ /g;

	# zero width space
	$text =~ s/\x{200B}/-/g;

	# abbreviations
	if (defined $abbreviations{$product_lc}) {
		foreach my $abbreviation_ref (@{$abbreviations{$product_lc}}) {
			my $source = $abbreviation_ref->[0];
			my $target = $abbreviation_ref->[1];
			$source =~ s/\./\\\./g;
			$text =~ s/$source/$target/ig;
		}
	}

	# remove extra spaces in compound words width dashes
	# e.g. céleri - rave -> céleri-rave

	# céleri - rave 3.9% -> stop at numbers
	$text =~ s/((^|$separators)([^,;\-\/\.0-9]+?) - ([^,;\-\/\.0-9]+?)(?=[0-9]|$separators|$))/is_compound_word_with_dash($product_lc,$1)/ieg;

	# vitamins...
	# vitamines A, B1, B2, B5, B6, B9, B12, C, D, H, PP et E (lactose, protéines de lait)

	my $split_vitamins = sub ($$) {
		my $vitamin = shift;
		my $list = shift;

		my $return = '';
		foreach my $vitamin_code (split (/(\W|\s|-|n|;|et|and)+/, $list)) {
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
	my $additivesregexp = '\d{3}( )?([abcdefgh])?(\))?(i|ii|iii|iv|v|vi|vii|viii|ix|x|xi|xii|xii|xiv|xv)?(\))?|\d{4}( )?([abcdefgh])?(\))?(i|ii|iii|iv|v|vi|vii|viii|ix|x|xi|xii|xii|xiv|xv)?(\))?';
	$text =~ s/\b(e|ins|sin)(:|\(|\[| )+((($additivesregexp)( |\/| \/ | - |,|, |$and)+)+($additivesregexp))\b(\s?(\)|\]))?/normalize_additives_enumeration($product_lc,$3)/ieg;

	# in India: INS 240 instead of E 240, bug #1133)
	$text =~ s/\b(ins|sin)( |-)?(\d)/E$3/ig;

	# E 240, E.240, E-240..
	# E250-E251-E260
	#$text =~ s/(\b|-)e( |-|\.)?(\d+)( )?([a-z])??(i|ii|iii|iv|v|vi|vii|viii|ix|x|xi|xii|xii|xiv|xv)?(\b|-)/$1 - e$3$5 - $7/ig;
	# add separations between all E340... "colorants naturels : rose E120, verte E161b, blanche : sans colorant"
	#$text =~ s/(\b|-)e( |-|\.)?(\d+)( )?([a-z])??(i|ii|iii|iv|v|vi|vii|viii|ix|x|xi|xii|xii|xiv|xv)?(\b|-)/$1 - e$3$5 - $7/ig;
	#$text =~ s/(\b|-)e( |-|\.)?(\d+)( )?([a-z])?(i|ii|iii|iv|v|vi|vii|viii|ix|x|xi|xii|xii|xiv|xv)?(\b|-)/$1 - e$3$5 - $7/ig;
	# ! [a-z] matches i... replacing in line above -- 2015/08/12
	#$text =~ s/(\b|-)e( |-|\.)?(\d+)( )?([abcdefgh])?(\))?(i|ii|iii|iv|v|vi|vii|viii|ix|x|xi|xii|xii|xiv|xv)?(\))?(\b|-)/$1 - e$3$5$7 - $9/ig;
	$text =~ s/-e( |-|\.)?($additivesregexp)/- E$2/ig;
	$text =~ s/e( |-|\.)?($additivesregexp)-/E$2 -/ig;

	# Canonicalize additives to remove the dash that can make further parsing break
	$text =~ s/(\b)e( |-|\.)?(\d+)()?([abcdefgh]?)(\))?((i|ii|iii|iv|v|vi|vii|viii|ix|x|xi|xii|xii|xiv|xv)?)(\))?(\b)/e$3$5$7/ig;

	# E100 et E120 -> E100, E120
	$text =~ s/\be($additivesregexp)$and/e$1, /ig;
	$text =~ s/${and}e($additivesregexp)/, e$1/ig;

	# E100 E122 -> E100, E122
	$text =~ s/\be($additivesregexp)\s+e(?=\d)/e$1, e/ig;

	# ! caramel E150d -> caramel - E150d -> e150a - e150d ...
	$text =~ s/(caramel|caramels)(\W*)e150/e150/ig;
	# e432 et lécithines -> e432 - et lécithines
	$text =~ s/ - et / - /ig;

	# stabilisant e420 (sans : ) -> stabilisant : e420
	# but not acidifier (pectin) : acidifier : (pectin)

	# FIXME : should use additives classes
	# ! in Spanish: colorante: caramelo was changed to colorant: e: caramelo
	$text =~ s/(conservateur|acidifiant|stabilisant|colorant|antioxydant|antioxygène|antioxygene|edulcorant|édulcorant|d'acidité|d'acidite|de goût|de gout|émulsifiant|emulsifiant|gélifiant|gelifiant|epaississant|épaississant|à lever|a lever|de texture|propulseur|emballage|affermissant|antiagglomérant|antiagglomerant|antimoussant|de charges|de fonte|d'enrobage|humectant|sequestrant|séquestrant|de traitement de la farine|de traitement de la farine|de traitement(?! de la farine))(s|)(\s)+(:)?(?!\(| \()/$1$2 : /ig;
	# citric acid natural flavor (may be a typo)
	$text =~ s/(natural flavor)(s)?(\s)?(:)?/: $1$2 : /ig;

	# additive class + additive (e.g. "colour caramel" -> "colour : caramel"
	# warning: the additive class may also be the start of the name of an additive.
	# e.g. "regulatory kwasowości: kwas cytrynowy i cytryniany sodu." -> "kwas" means acid / acidifier.
	if (defined $additives_classes_regexps{$product_lc}) {
		my $regexp = $additives_classes_regexps{$product_lc};
		#$text =~ s/\b($regexp)(\s)+(:)?(?!\(| \()/$1 : /ig;
		$text =~ s/\b($regexp)(\s+)(:?)(?!\(| \()/separate_additive_class($product_lc,$1,$2,$3,$')/ieg;
		#print STDERR "additives_classes_regexps result: $text\n";
	}

	# dash with 1 missing space
	$text =~ s/(\w)- /$1 - /ig;
	$text =~ s/ -(\w)/ - $1/ig;

	# mono-glycéride -> monoglycérides
	$text =~ s/(mono|di)-([a-z])/$1$2/ig;
	$text =~ s/\bmono - /mono- /ig;
	$text =~ s/\bmono /mono- /ig;
	#  émulsifiant mono-et diglycérides d'acides gras
	$text =~ s/(monoet )/mono- et /ig;

	# acide gras -> acides gras
	$text =~ s/acide gras/acides gras/ig;
	$text =~ s/glycéride /glycérides /ig;

	# !! mono et diglycérides ne doit pas donner mono + diglycérides : keep the whole version too.
	# $text =~ s/(,|;|:|\)|\(|( - ))(.+?)( et )(.+?)(,|;|:|\)|\(|( - ))/$1$3_et_$5$6 , $1$3 et $5$6/ig;

	# print STDERR "additives: $text\n\n";

	#$product_ref->{ingredients_text_debug} = $text;

	# separator followed by and
	# aceite de girasol (70%) y aceite de oliva virgen (30%)
	$text =~ s/($cbrackets)$and/$1, /ig;


	if ($product_lc eq 'fr') {

		# huiles de palme et de

		# carbonates d'ammonium et de sodium

		# carotène et extraits de paprika et de curcuma

		# Minéraux (carbonate de calcium, chlorures de calcium, potassium et magnésium, citrates de potassium et de sodium, phosphate de calcium,
		# sulfates de fer, de zinc, de cuivre et de manganèse, iodure de potassium, sélénite de sodium).

		# graisses végétales de palme et de colza en proportion variable
		# remove stopwords
		$text =~ s/( en)? proportion(s)? variable(s)?//i;

		# simple plural (just an additional "s" at the end) will be added in the regexp
		my @prefixes_suffixes_list = (
# huiles
[[
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
"arachide",
"avocat",
"chanvre",
"coco",
"colza",
"illipe",
"karité",
"lin",
"mangue",
"noisette",
"noix",
"olive",
"olive vierge",
"olive extra vierge",
"palme",
"palmiste",
"pépins de raisin",
"sal",
"sésame",
"soja",
"tournesol",
"tournesol oléique",
]
],


[[
"extrait",
"extrait naturel",
],
[
"café",
"chicorée",
"curcuma",
"houblon",
"levure",
"malt",
"muscade",
"poivre",
"poivre noir",
"romarin",
"thé",
"thé vert",
"thym",
]
],

[[
"lécithine",
],
[
"colza",
"soja",
"soja sans ogm",
"tournesol",
]
],

[
[
"arôme naturel",
"arômes naturels",
"arôme artificiel",
"arômes artificiels",
"arômes naturels et artificiels",
"arômes",
],
[
"abricot",
"ail",
"amande",
"amande amère",
"agrumes",
"aneth",
"boeuf",
"cacao",
"cannelle",
"caramel",
"carotte",
"carthame",
"cassis",
"céleri",
"cerise",
"curcuma",
"cumin",
"citron",
"citron vert",
"crustacés",
"estragon",
"fenouil",
"figue",
"fraise",
"framboise",
"fromage de chèvre",
"fruit",
"fruit de la passion",
"fruits de la passion",
"fruits de mer",
"fumée",
"gentiane",
"herbes",
"jasmin",
"laurier",
"lime",
"limette",
"mangue",
"menthe",
"menthe crêpue",
"menthe poivrée",
"muscade",
"noix",
"noix de coco",
"oignon",
"olive",
"orange",
"orange amère",
"origan",
"pamplemousse",
"pamplemousse rose",
"pêche",
"piment",
"pistache",
"porc",
"pomme",
"poire",
"poivre",
"poisson",
"poulet",
"réglisse",
"romarin",
"rose",
"rhum",
"sauge",
"saumon",
"sureau",
"thé",
"thym",
"vanille",
"vanille de Madagascar",
"autres agrumes",
]
],


[
[
"carbonate",
"carbonates acides",
"chlorure",
"citrate",
"iodure",
"nitrate",
"diphosphate",
"diphosphate",
"phosphate",
"sélénite",
"sulfate",
"hydroxyde",
"sulphate",
],
[
"aluminium",
"ammonium",
"calcium",
"cuivre",
"fer",
"magnésium",
"manganèse",
"potassium",
"sodium",
"zinc",
]
],

);

		foreach my $prefixes_suffixes_ref (@prefixes_suffixes_list) {

			my $prefixregexp = "";
			foreach my $prefix (@{$prefixes_suffixes_ref->[0]}) {
				$prefixregexp .= '|' . $prefix . '|' . $prefix . 's';
				my $unaccented_prefix = unac_string_perl($prefix);
				if ($unaccented_prefix ne $prefix) {
					$prefixregexp .= '|' . $unaccented_prefix . '|' . $unaccented_prefix . 's';
				}

			}
			$prefixregexp =~ s/^\|//;

			$prefixregexp = "(" . $prefixregexp . ")( bio| biologique| équitable)?";

			my $suffixregexp = "";
			foreach my $suffix (@{$prefixes_suffixes_ref->[1]}) {
				$suffixregexp .= '|' . $suffix . '|' . $suffix . 's';
				my $unaccented_suffix = unac_string_perl($suffix);
				if ($unaccented_suffix ne $suffix) {
					$suffixregexp .= '|' . $unaccented_suffix . '|' . $unaccented_suffix . 's';
				}

			}
			$suffixregexp =~ s/^\|//;

			# arôme naturel de citron-citron vert et d'autres agrumes
			# -> separate suffixes
			$text =~ s/($suffixregexp)-($suffixregexp)/$1, $2/g;

			# arôme naturel de pomme avec d'autres âromes
			$text =~ s/ (ou|et|avec) (d')?autres /, /g;

			$text =~ s/($prefixregexp) et ($prefixregexp) (de |d')?($suffixregexp)/normalize_fr_a_et_b_de_c($1, $4, $8)/ieg;

			# old:

			#$text =~ s/($prefixregexp) (\(|\[|de |d')?($suffixregexp) et (de |d')?($suffixregexp)(\)|\])?/normalize_fr_a_de_enumeration($1, $3, $5)/ieg;
			#$text =~ s/($prefixregexp) (\(|\[|de |d')?($suffixregexp), (de |d')?($suffixregexp) et (de |d')?($suffixregexp)(\)|\])?/normalize_fr_a_de_enumeration($1, $3, $5, $7)/ieg;
			#$text =~ s/($prefixregexp) (\(|\[|de |d')?($suffixregexp), (de |d')?($suffixregexp), (de |d')?($suffixregexp) et (de |d')?($suffixregexp)(\)|\])?/normalize_fr_a_de_enumeration($1, $3, $5, $7, $9)/ieg;
			#$text =~ s/($prefixregexp) (\(|\[|de |d')?($suffixregexp), (de |d')?($suffixregexp), (de |d')?($suffixregexp), (de |d')?($suffixregexp) et (de |d')?($suffixregexp)(\)|\])?/normalize_fr_a_de_enumeration($1, $3, $5, $7, $9, $11)/ieg;

			$text =~ s/($prefixregexp)\s?(:|\(|\[)\s?($suffixregexp)\b(\s?(\)|\]))?/normalize_enumeration($product_lc,$1,$5)/ieg;

			# Huiles végétales de palme, de colza et de tournesol
			$text =~ s/($prefixregexp)(:|\(|\[| | de | d')+((($suffixregexp)( |\/| \/ | - |,|, | et | de | et de | et d'| d')+)+($suffixregexp))\b(\s?(\)|\]))?/normalize_enumeration($product_lc,$1,$5)/ieg;
		}

		# Caramel ordinaire et curcumine
		# $text =~ s/ et /, /ig;
		# --> too dangerous, too many exceptions

		# Some additives have "et" in their name: need to recombine them

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

		$text =~ s/(di|tri|tripoli)?(phosphate|phosphates) d'aluminium,\s?(di|tri|tripoli)?(phosphate|phosphates) de sodium/$1phosphate d'aluminium et de sodium/ig;

		# Sels de sodium et de potassium de complexes cupriques de chlorophyllines -> should not be split...
		$text =~ s/(sel|sels) de sodium,\s?(sel|sels) de potassium/sels de sodium et de potassium/ig;

		# vitamines A, B1, B2, B5, B6, B9, B12, C, D, H, PP et E
		# vitamines (A, B1, B2, B5, B6, B9, B12, C, D, H, PP et E)

	}


	my @vitaminssuffixes = (
"a", "rétinol",
"b", "b1", "b2", "b3", "b4", "b5", "b6", "b7", "b8", "b9", "b10", "b11", "b12",
"thiamine",
"riboflavine",
"niacine",
"pyridoxine",
"cobalamine",
"biotine",
"acide pantothénique",
"acide folique",
"c", "acide ascorbique",
"d", "d2", "d3", "cholécalciférol",
"e", "tocophérol", "alphatocophérol", "alpha-tocophérol",
"f",
"h",
"k", "k1", "k2", "k3",
"p", "pp",
);
	my $vitaminsprefixregexp = "vitamine|vitamines";

	# Add synonyms in target language
	if (defined $translations_to{vitamins}) {
		foreach my $vitamin (keys %{$translations_to{vitamins}}) {
			if (defined $translations_to{vitamins}{$vitamin}{$product_lc}) {
				push @vitaminssuffixes, $translations_to{vitamins}{$vitamin}{$product_lc};
			}
		}
	}

	# Add synonyms in target language
	my $vitamin_in_lc = get_string_id_for_lang($product_lc, display_taxonomy_tag($product_lc, "ingredients", "en:vitamins"));
	$vitamin_in_lc =~ s/^\w\w://;

	if ((defined $synonyms_for{ingredients}) and (defined $synonyms_for{ingredients}{$product_lc}) and (defined $synonyms_for{ingredients}{$product_lc}{$vitamin_in_lc})) {
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
	#$log->debug("vitamins text", { text => $text }) if $log->is_debug();

	$text =~ s/($vitaminsprefixregexp)(:|\(|\[| )+((($vitaminssuffixregexp)( |\/| \/ | - |,|, |$and))+($vitaminssuffixregexp))\b(\s?(\)|\]))?/normalize_vitamins_enumeration($product_lc,$3)/ieg;


	# Allergens and traces
	# Traces de lait, d'oeufs et de soja.

	my $traces_regexp = $traces_regexps{$product_lc};

	if (defined $traces_regexp) {

		my @allergenssuffixes = ();

		# Add synonyms in target language
		if (defined $translations_to{allergens}) {
			foreach my $allergen (keys %{$translations_to{allergens}}) {
				if (defined $translations_to{allergens}{$allergen}{$product_lc}) {
					# push @allergenssuffixes, $translations_to{allergens}{$allergen}{$product_lc};
					# the synonyms below also contain the main translation as the first entry

					my $product_lc_allergenid = get_string_id_for_lang($product_lc, $translations_to{allergens}{$allergen}{$product_lc});

					foreach my $synonym (@{$synonyms_for{allergens}{$product_lc}{$product_lc_allergenid}}) {
						push @allergenssuffixes, $synonym;
				}
				}
			}
		}

		my $allergenssuffixregexp = "";
		foreach my $suffix (@allergenssuffixes) {
			# simple singulars and plurals
			my $singular = $suffix;
			$suffix =~ s/s$//;
			$allergenssuffixregexp .= '|' . $suffix . '|' . $suffix . 's'  ;

			my $unaccented_suffix = unac_string_perl($suffix);
			if ($unaccented_suffix ne $suffix) {
				$allergenssuffixregexp .= '|' . $unaccented_suffix . '|' . $unaccented_suffix . 's';
			}

		}
		$allergenssuffixregexp =~ s/^\|//;

		# stopwords
		# e.g. Kann Spuren von Senf und Sellerie enthalten.
		my $stopwords = "";
		if (defined $allergens_stopwords{$product_lc}) {
			$stopwords = $allergens_stopwords{$product_lc};
		}

		# $traces_regexp may be the end of a sentence, remove the beginning
		# e.g. this product has been manufactured in a factory that also uses...
		# Some text with comma May contain ... -> Some text with comma, May contain
		# ! does not work in German and languages that have words with a capital letter
		if ($product_lc ne "de") {
			my $ucfirst_traces_regexp = $traces_regexp;
			$ucfirst_traces_regexp =~ s/(^|\|)(\w)/$1 . uc($2)/ieg;
			$text =~ s/([a-z]) ($ucfirst_traces_regexp)/$1, $2/g;
		}

		#$log->debug("allergens regexp", { regex => "s/([^,-\.;\(\)\/]*)\b($traces_regexp)\b(:|\(|\[| |$and|$of)+((($allergenssuffixregexp)( |\/| \/ | - |,|, |$and|$of|$and_of)+)+($allergenssuffixregexp))\b(s?(\)|\]))?" }) if $log->is_debug();
		#$log->debug("allergens", { lc => $product_lc, traces_regexps => \%traces_regexps, traces_regexp => $traces_regexp, text => $text }) if $log->is_debug();

		$text =~ s/([^,-\.;\(\)\/]*)\b($traces_regexp)\b(:|\(|\[| |$of)+((($allergenssuffixregexp)( |\/| \/ | - |,|, |$and|$of|$and_of)+)*($allergenssuffixregexp))\b((\s)($stopwords))*(\s?(\)|\]))?/normalize_allergens_enumeration("traces",$product_lc,$4)/ieg;
		# we may have added an extra dot in order to make sure we have at least one
		$text =~ s/\.\./\./g;

	}


	# Try to find the signification of symbols like *
	# Jus de pomme*** 68%, jus de poire***32% *** Ingrédients issus de l'agriculture biologique
	# Pâte de cacao°* du Pérou 65 %, sucre de canne°*, beurre de cacao°*. °Issus de l'agriculture biologique (100 %). *Issus du commerce équitable (100 % du poids total avec 93 % SPP).

	if (defined $labels_regexps{$product_lc}) {
		my @symbols = ('\*\*\*', '\*\*', '\*', '°°°', '°°', '°');

		foreach my $symbol (@symbols) {
			# Find the last occurence of the symbol
			if ($text =~ /^(.*)$symbol\s*:?\s*/) {
				my $after = $';
				# print STDERR "symbol: $symbol - after: $after\n";
				foreach my $labelid (@labels) {
					my $regexp = $labels_regexps{$product_lc}{$labelid};
					if (defined $regexp) {
						# print STDERR "-- label: $labelid - regexp: $regexp\n";
						# try to also match optional precisions like "Issus de l'agriculture biologique (100 % du poids total)"
						# *Issus du commerce équitable (100 % du poids total avec 93 % SPP).
						if ($after =~ /^($regexp)\s*(\([^\)]+\))?\s*\.?\s*/i) {
							my $label = $1;
							$text =~ s/^(.*)$symbol\s?:?\s?$label\s*(\([^\)]+\))?\s*\.?\s*/$1 /i;
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
	$text =~ s/ (\.|,)( |$)/$1$2/g;
	$text =~ s/^\s+//;
	$text =~ s/\s+$//;

	return $text;
}



sub extract_ingredients_classes_from_text($) {

	my $product_ref = shift;
	my $path = product_path($product_ref->{code});
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
				my $canon_ingredient_additive = canonicalize_taxonomy_tag($product_ref->{lc}, "additives", $ingredientid);

				if (not exists_taxonomy_tag("additives", $canon_ingredient_additive)) {

					# otherwise check the 2 sub ingredients
					my $canon_ingredient_additive1 = canonicalize_taxonomy_tag($product_ref->{lc}, "additives", $ingredientid1);
					my $canon_ingredient_additive2 = canonicalize_taxonomy_tag($product_ref->{lc}, "additives", $ingredientid2);

					if ( (exists_taxonomy_tag("additives", $canon_ingredient_additive1))
						and (exists_taxonomy_tag("additives", $canon_ingredient_additive2)) ) {
							push @ingredients_ids, $ingredientid1;
							$ingredientid = $ingredientid2;
							#print STDERR "ingredients_classes - ingredient1: $ingredientid1 exists - ingredient2: $ingredientid2 exists\n";
					}
				}

			}

			push @ingredients_ids, $ingredientid;
			$log->debug("ingredient 3", { ingredient => $ingredient }) if $log->is_debug();
		}
	}

	#$product_ref->{ingredients_debug} = clone(\@ingredients);
	#$product_ref->{ingredients_ids_debug} = clone(\@ingredients_ids);

	my $with_sweeteners;

	my %all_seen = (); # used to not tag "huile végétale" if we have seen "huile de palme" already


	# Additives using new global taxonomy

	# delete old additive fields

	foreach my $tagtype ('additives', 'additives_prev', 'additives_next', 'old_additives', 'new_additives') {

		delete $product_ref->{$tagtype};
		delete $product_ref->{$tagtype . "_prev"};
		delete $product_ref->{$tagtype ."_prev_n"};
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

				my $ingredient_id_copy = $ingredient_id; # can be modified later: soy-lecithin -> lecithin, but we don't change values of @ingredients_ids

				my $match = 0;
				my $match_without_mandatory_class = 0;

				while (not $match) {

					# additive class?
					my $canon_ingredient_additive_class = canonicalize_taxonomy_tag($product_ref->{lc}, "additives_classes", $ingredient_id_copy);

					if (exists_taxonomy_tag("additives_classes", $canon_ingredient_additive_class )) {
						$current_additive_class = $canon_ingredient_additive_class;
						$log->debug("current additive class", { current_additive_class => $canon_ingredient_additive_class }) if $log->is_debug();
					}

					# additive?
					my $canon_ingredient = canonicalize_taxonomy_tag($product_ref->{lc}, $tagtype, $ingredient_id_copy);
					# in Hong Kong, the E- can be omitted in E-numbers
					my $canon_e_ingredient = canonicalize_taxonomy_tag($product_ref->{lc}, $tagtype, "e" . $ingredient_id_copy);
					my $canon_ingredient_vitamins = canonicalize_taxonomy_tag($product_ref->{lc}, "vitamins", $ingredient_id_copy);
					my $canon_ingredient_minerals = canonicalize_taxonomy_tag($product_ref->{lc}, "minerals", $ingredient_id_copy);
					my $canon_ingredient_amino_acids = canonicalize_taxonomy_tag($product_ref->{lc}, "amino_acids", $ingredient_id_copy);
					my $canon_ingredient_nucleotides = canonicalize_taxonomy_tag($product_ref->{lc}, "nucleotides", $ingredient_id_copy);
					my $canon_ingredient_other_nutritional_substances = canonicalize_taxonomy_tag($product_ref->{lc}, "other_nutritional_substances", $ingredient_id_copy);

					$product_ref->{$tagtype} .= " [ $ingredient_id_copy -> $canon_ingredient ";

					if (defined $seen{$canon_ingredient}) {
						$product_ref->{$tagtype} .= " -- already seen ";
						$match = 1;
					}

					# For additives, first check if the current class is vitamins or minerals and if the ingredient
					# exists in the vitamins and minerals taxonomy

					elsif ((($current_additive_class eq "en:vitamins") or ($current_additive_class eq "en:minerals")
						or ($current_additive_class eq "en:amino-acids") or ($current_additive_class eq "en:nucleotides")
						or ($current_additive_class eq "en:other-nutritional-substances"))

					and (exists_taxonomy_tag("vitamins", $canon_ingredient_vitamins))) {
						$match = 1;
						$seen{$canon_ingredient} = 1;
						$product_ref->{$tagtype} .= " -> exists as a vitamin $canon_ingredient_vitamins and current class is $current_additive_class ";
						if (not exists $seen_tags{$vitamins_tagtype . '_tags' . $canon_ingredient_vitamins}) {
							push @{$product_ref->{ $vitamins_tagtype . '_tags'}}, $canon_ingredient_vitamins;
							$seen_tags{$vitamins_tagtype . '_tags' . $canon_ingredient_vitamins} = 1;
						}
					}

					elsif (($current_additive_class eq "en:minerals") and (exists_taxonomy_tag("minerals", $canon_ingredient_minerals))
						and not ($just_synonyms{"minerals"}{$canon_ingredient_minerals})) {
						$match = 1;
						$seen{$canon_ingredient} = 1;
						$product_ref->{$tagtype} .= " -> exists as a mineral $canon_ingredient_minerals and current class is $current_additive_class ";
						if (not exists $seen_tags{$minerals_tagtype . '_tags' . $canon_ingredient_minerals}) {
							push @{$product_ref->{ $minerals_tagtype . '_tags'}}, $canon_ingredient_minerals;
							$seen_tags{$minerals_tagtype . '_tags' . $canon_ingredient_minerals} = 1;
						}
					}

					elsif ((exists_taxonomy_tag($tagtype, $canon_ingredient))
						# do not match synonyms
						and ($canon_ingredient !~ /^en:(fd|no|colour)/)
						) {

						$seen{$canon_ingredient} = 1;
						$product_ref->{$tagtype} .= " -> exists ";

						if ((defined $properties{$tagtype}{$canon_ingredient})
							and (defined $properties{$tagtype}{$canon_ingredient}{"mandatory_additive_class:en"})) {

							my $mandatory_additive_class = $properties{$tagtype}{$canon_ingredient}{"mandatory_additive_class:en"};
							# make the comma separated list a regexp
							$product_ref->{$tagtype} .= " -- mandatory_additive_class: $mandatory_additive_class (current: $current_additive_class) ";
							$mandatory_additive_class =~ s/,/\|/g;
							$mandatory_additive_class =~ s/\s//g;
							if ($current_additive_class =~ /^$mandatory_additive_class$/) {
								if (not exists $seen_tags{$tagtype . '_tags' . $canon_ingredient}) {
									push @{$product_ref->{ $tagtype . '_tags'}}, $canon_ingredient;
									$seen_tags{$tagtype . '_tags' . $canon_ingredient} = 1;
								}
								# success!
								$match = 1;
								$product_ref->{$tagtype} .= " -- ok ";
							}
							elsif ($ingredient_id_copy =~ /^e( |-)?\d/) {
								# id the additive is mentioned with an E number, tag it even if we haven't detected a mandatory class
								if (not exists $seen_tags{$tagtype . '_tags' . $canon_ingredient}) {
									push @{$product_ref->{ $tagtype . '_tags'}}, $canon_ingredient;
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
								push @{$product_ref->{ $tagtype . '_tags'}}, $canon_ingredient;
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
								push @{$product_ref->{ $vitamins_tagtype . '_tags'}}, $canon_ingredient_vitamins;
								$seen_tags{$vitamins_tagtype . '_tags' . $canon_ingredient_vitamins} = 1;
							}
							# set current class to vitamins
							$current_additive_class = "en:vitamins";
						}

						elsif ((exists_taxonomy_tag("minerals", $canon_ingredient_minerals))
							and not ($just_synonyms{"minerals"}{$canon_ingredient_minerals})) {
							$match = 1;
							$seen{$canon_ingredient} = 1;
							$product_ref->{$tagtype} .= " -> exists as a mineral $canon_ingredient_minerals ";
							if (not exists $seen_tags{$minerals_tagtype . '_tags' . $canon_ingredient_minerals}) {
								push @{$product_ref->{ $minerals_tagtype . '_tags'}}, $canon_ingredient_minerals;
								$seen_tags{$minerals_tagtype . '_tags' . $canon_ingredient_minerals} = 1;
							}
							$current_additive_class = "en:minerals";
						}

						if ((exists_taxonomy_tag("amino_acids", $canon_ingredient_amino_acids))) {
							$match = 1;
							$seen{$canon_ingredient} = 1;
							$product_ref->{$tagtype} .= " -> exists as a amino_acid $canon_ingredient_amino_acids ";
							if (not exists $seen_tags{$amino_acids_tagtype . '_tags' . $canon_ingredient_amino_acids}) {
								push @{$product_ref->{ $amino_acids_tagtype . '_tags'}}, $canon_ingredient_amino_acids;
								$seen_tags{$amino_acids_tagtype . '_tags' . $canon_ingredient_amino_acids} = 1;
							}
							$current_additive_class = "en:amino-acids";
						}

						elsif ((exists_taxonomy_tag("nucleotides", $canon_ingredient_nucleotides))) {
							$match = 1;
							$seen{$canon_ingredient} = 1;
							$product_ref->{$tagtype} .= " -> exists as a nucleotide $canon_ingredient_nucleotides ";
							if (not exists $seen_tags{$nucleotides_tagtype . '_tags' . $canon_ingredient_nucleotides}) {
								push @{$product_ref->{ $nucleotides_tagtype . '_tags'}}, $canon_ingredient_nucleotides;
								$seen_tags{$nucleotides_tagtype . '_tags' . $canon_ingredient_nucleotides} = 1;
							}
							$current_additive_class = "en:nucleotides";
						}

						elsif ((exists_taxonomy_tag("other_nutritional_substances", $canon_ingredient_other_nutritional_substances))) {
							$match = 1;
							$seen{$canon_ingredient} = 1;
							$product_ref->{$tagtype} .= " -> exists as a other_nutritional_substance $canon_ingredient_other_nutritional_substances ";
							if (not exists $seen_tags{$other_nutritional_substances_tagtype . '_tags' . $canon_ingredient_other_nutritional_substances}) {
								push @{$product_ref->{ $other_nutritional_substances_tagtype . '_tags'}}, $canon_ingredient_other_nutritional_substances;
								$seen_tags{$other_nutritional_substances_tagtype . '_tags' . $canon_ingredient_other_nutritional_substances} = 1;
							}
							$current_additive_class = "en:other-nutritional-substances";
						}

						# in Hong Kong, the E- can be omitted in E-numbers

						elsif (($canon_ingredient =~ /^en:(\d+)( |-)?([a-z])??(i|ii|iii|iv|v|vi|vii|viii|ix|x|xi|xii|xii|xiv|xv)?$/i)
							and (exists_taxonomy_tag($tagtype, $canon_e_ingredient))
							and ($current_additive_class ne "ingredient")) {

							$seen{$canon_e_ingredient} = 1;
							$product_ref->{$tagtype} .= " -> e-ingredient exists  ";

							if (not exists $seen_tags{$tagtype . '_tags' . $canon_e_ingredient}) {
								push @{$product_ref->{ $tagtype . '_tags'}}, $canon_e_ingredient;
								 $seen_tags{$tagtype . '_tags' . $canon_e_ingredient} = 1;
							}
							# success!
							$match = 1;
							$product_ref->{$tagtype} .= " -- ok ";
						}
					}

					# spellcheck
					my $spellcheck = 0;
					if ((not $match) and ($tagtype eq 'additives')
						and not $match_without_mandatory_class
						# do not correct words that are existing ingredients in the taxonomy
						and (not exists_taxonomy_tag("ingredients", canonicalize_taxonomy_tag($product_ref->{lc}, "ingredients", $ingredient_id_copy) ) ) ) {

						my ($corrected_canon_tagid, $corrected_tagid, $corrected_tag) = spellcheck_taxonomy_tag($product_ref->{lc}, $tagtype, $ingredient_id_copy);
						if ((defined $corrected_canon_tagid)
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

							) {

							$product_ref->{$tagtype} .= " -- spell correction (lc: " . $product_ref->{lc} . "): $ingredient_id_copy -> $corrected_tag";
							print STDERR "spell correction (lc: " . $product_ref->{lc} . "): $ingredient_id_copy -> $corrected_tag - code: $product_ref->{code}\n";

							$ingredient_id_copy = $corrected_tag;
							$spellcheck = 1;
						}
					}


					if ((not $match)
						and (not $spellcheck)) {

						# try to shorten the ingredient to make it less specific, to see if it matches then

						if (($product_ref->{lc} eq 'en') and ($ingredient_id_copy =~ /^([^-]+)-/)) {
							# soy lecithin -> lecithin
							$ingredient_id_copy = $';
						}
						elsif (($product_ref->{lc} eq 'fr') and ($ingredient_id_copy =~ /-([^-]+)$/)) {
							# lécithine de soja -> lécithine de -> lécithine
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
		$product_ref->{ $tagtype . '_original_tags'} = $product_ref->{ $tagtype . '_tags'};
		$product_ref->{ $tagtype . '_tags'} = [ sort(gen_tags_hierarchy_taxonomy("en", $tagtype, join(', ', @{$product_ref->{ $tagtype . '_original_tags'}})))];


		# No ingredients?
		if ($product_ref->{ingredients_text} eq '') {
			delete $product_ref->{$tagtype . '_n'};
		}
		else {
			# count the original list of additives, don't count E500ii as both E500 and E500ii
			if (defined $product_ref->{$tagtype . '_original_tags'}) {
				$product_ref->{$tagtype. '_n'} = scalar @{$product_ref->{ $tagtype . '_original_tags'}};
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
			foreach my $array ($tagtype . '_tags', $tagtype . '_original_tags',
				$vitamins_tagtype . '_tags', $minerals_tagtype . '_tags',
				$amino_acids_tagtype . '_tags', $nucleotides_tagtype . '_tags',
				$other_nutritional_substances_tagtype . '_tags') {
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

				if ((defined $ingredients_classes{$class}{$ingredient_id}) and (not defined $seen{$ingredients_classes{$class}{$ingredient_id}{id}})) {

					next if (($ingredients_classes{$class}{$ingredient_id}{id} eq 'huile-vegetale') and (defined $all_seen{"huile-de-palme"}));

					#$product_ref->{$tagtype . "_debug_ingredients_ids" } .= " -> exact match $ingredients_classes{$class}{$ingredient_id}{id} ";

					push @{$product_ref->{$tagtype . '_tags'}}, $ingredients_classes{$class}{$ingredient_id}{id};
					$seen{$ingredients_classes{$class}{$ingredient_id}{id}} = 1;
					$all_seen{$ingredients_classes{$class}{$ingredient_id}{id}} = 1;

				}
				else {

					#$product_ref->{$tagtype . "_debug_ingredients_ids" } .= " -> no exact match ";

					foreach my $id (@{$ingredients_classes_sorted{$class}}) {
						if (($ingredient_id =~ /^$id\b/) and (not defined $seen{$ingredients_classes{$class}{$id}{id}})) {

							next if (($ingredients_classes{$class}{$id}{id} eq 'huile-vegetale') and (defined $all_seen{"huile-de-palme"}));

							#$product_ref->{$tagtype . "_debug_ingredients_ids" } .= " -> match $id - $ingredients_classes{$class}{$id}{id} ";

							push @{$product_ref->{$tagtype . '_tags'}}, $ingredients_classes{$class}{$id}{id};
							$seen{$ingredients_classes{$class}{$id}{id}} = 1;
							$all_seen{$ingredients_classes{$class}{$id}{id}} = 1;
						}
					}
				}
			}
		}

		# No ingredients?
		if ($product_ref->{ingredients_text} eq '') {
			delete $product_ref->{$tagtype . '_n'};
		}
		else {
			$product_ref->{$tagtype . '_n'} = scalar @{$product_ref->{$tagtype . '_tags'}};
		}

		# Delete empty arrays
		# -> not active
		# -> may be dangerous if some apps rely on them existing even if empty

		if (0) {
			if ((defined $product_ref->{$tagtype . '_tags'}) and ((scalar @{$product_ref->{$tagtype . '_tags'}}) == 0)) {
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
			if (not has_tag($product_ref,$field . "_prev",$tag)) {
				my $tagid = $tag;
				$tagid =~ s/:/-/;
				push @{$product_ref->{$field . "_debug_tags"}}, "$tagid-added";
			}
		}
		foreach my $tag (@{$product_ref->{$field . "_prev_tags"}}) {
			if (not has_tag($product_ref,$field,$tag)) {
				my $tagid = $tag;
				$tagid =~ s/:/-/;
				push @{$product_ref->{$field . "_debug_tags"}}, "$tagid-removed";
			}
		}
	}
	else {
		delete $product_ref->{$field . "_prev_hierarchy" };
		delete $product_ref->{$field . "_prev_tags" };
	}

	# next version

	if (exists $loaded_taxonomies{$field . "_next"}) {

		(defined $product_ref->{$field . "_debug_tags"}) or $product_ref->{$field . "_debug_tags"} = [];

		# compute differences
		foreach my $tag (@{$product_ref->{$field . "_tags"}}) {
			if (not has_tag($product_ref,$field . "_next",$tag)) {
				my $tagid = $tag;
				$tagid =~ s/:/-/;
				push @{$product_ref->{$field . "_debug_tags"}}, "$tagid-will-remove";
			}
		}
		foreach my $tag (@{$product_ref->{$field . "_next_tags"}}) {
			if (not has_tag($product_ref,$field,$tag)) {
				my $tagid = $tag;
				$tagid =~ s/:/-/;
				push @{$product_ref->{$field . "_debug_tags"}}, "$tagid-will-add";
			}
		}
	}
	else {
		delete $product_ref->{$field . "_next_hierarchy" };
		delete $product_ref->{$field . "_next_tags" };
	}




	if ((defined $product_ref->{ingredients_that_may_be_from_palm_oil_n}) or (defined $product_ref->{ingredients_from_palm_oil_n})) {
		$product_ref->{ingredients_from_or_that_may_be_from_palm_oil_n} = $product_ref->{ingredients_that_may_be_from_palm_oil_n} + $product_ref->{ingredients_from_palm_oil_n};
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
}



sub replace_allergen($$$$) {
	my $language = shift;
	my $product_ref = shift;
	my $allergen = shift;
	my $before = shift;

	my $field = "allergens";

	my $traces_regexp = $traces_regexps{$language};

	if ((defined $traces_regexp) and ($before =~ /\b($traces_regexp)\b/i)) {
		$field = "traces";
	}

	# to build the product allergens list, just use the ingredients in the main language
	if ($language eq $product_ref->{lc}) {
		# skip allergens like "moutarde et céleri" (will be caught later by replace_allergen_between_separators)
		if (not (($language eq 'fr') and $allergen =~ / et /i)) {
			$product_ref->{$field . "_from_ingredients"} .= $allergen . ', ';
		}
	}

	return '<span class="allergen">' . $allergen . '</span>';
}


sub replace_allergen_in_caps($$$$) {
	my $language = shift;
	my $product_ref = shift;
	my $allergen = shift;
	my $before = shift;

	my $field = "allergens";

	my $traces_regexp = $traces_regexps{$language};

	if ((defined $traces_regexp) and ($before =~ /\b($traces_regexp)\b/i)) {
		$field = "traces";
	}

	my $tagid = canonicalize_taxonomy_tag($language,"allergens", $allergen);

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


sub replace_allergen_between_separators($$$$$$) {
	my $language = shift;
	my $product_ref = shift;
	my $start_separator = shift;
	my $allergen = shift;
	my $end_separator = shift;
	my $before = shift;

	my $field = "allergens";


	# print STDERR "replace_allergen_between_separators - allergen: $allergen\n";

	my $stopwords = $allergens_stopwords{$language};

	my $before_allergen = "";

	# Remove stopwords at the beginning or end
	if (defined $stopwords) {
		if ($allergen =~ /^((\s|\b($stopwords)\b)+)/i) {
			$before_allergen = $1;
			$allergen =~ s/^(\s|\b($stopwords)\b)+//i;
		}
		if ($allergen =~ /((\s|\b($stopwords)\b)+)$/i) {
			$before_allergen = $1;
			$allergen =~ s/(\s|\b($stopwords)\b)+$//i;
		}
	}

	my $traces_regexp = $traces_regexps{$language};

	if (($before . $before_allergen) =~ /\b($traces_regexp)\b/i) {
		$field = "traces";
		print STDERR "traces (before_allergen: $before_allergen - before: $before)\n";
	}

	# Farine de blé 97%
	if ($allergen =~ /( \d)/) {
		$allergen = $`;
		$end_separator = $1 . $' . $end_separator;
	}

	print STDERR "before_allergen: $before_allergen - allergen: $allergen\n";

	my $tagid = canonicalize_taxonomy_tag($language,"allergens", $allergen);

	print STDERR "before_allergen: $before_allergen - allergen: $allergen - tagid: $tagid\n";

	if (exists_taxonomy_tag("allergens", $tagid)) {
		#$allergen = display_taxonomy_tag($product_ref->{lang},"allergens", $tagid);
		# to build the product allergens list, just use the ingredients in the main language
		if ($language eq $product_ref->{lc}) {
			$product_ref->{$field . "_from_ingredients"} .= $allergen . ', ';
		}
		return $start_separator . $before_allergen . '<span class="allergen">' . $allergen . '</span>' . $end_separator;
	}
	else {
		return $start_separator . $before_allergen . $allergen . $end_separator;
	}
}


sub detect_allergens_from_text($) {

	my $product_ref = shift;
	my $path = product_path($product_ref->{code});

	# Keep allergens entered by users in the allergens and traces field

	foreach my $field ("allergens", "traces") {

		# new fields for allergens detected from ingredient list

		$product_ref->{$field . "_from_ingredients"} = "";
	}

	if (defined $product_ref->{languages_codes}) {

		foreach my $language (keys %{$product_ref->{languages_codes}}) {

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
			if (defined $traces_regexps{$language}) {
				$traces_regexp = $traces_regexps{$language};
			}

			my $text = $product_ref->{"ingredients_text_" . $language };
			$text =~ s/\&quot;/"/g;

			next if not defined $text;

			# allergens between underscores

			# print STDERR "current text 1: $text\n";

			$text =~ s/\b_([^,;_\(\)\[\]]+?)_\b/replace_allergen($language,$product_ref,$1,$`)/iesg;

			# allergens in all caps, with other ingredients not in all caps

			if ($text =~ /[a-z]/) {
				# match ALL CAPS including space (but stop at the dash in "FRUITS A COQUE - Something")
				$text =~ s/\b([A-ZÌÒÁÉÍÓÚÝÂÊÎÔÛÃÑÕÄËÏÖŸÇŒß][A-ZÌÒÁÉÍÓÚÝÂÊÎÔÛÃÑÕÄËÏÖŸÇŒß]([A-ZÌÒÁÉÍÓÚÝÂÊÎÔÛÃÑÕÄËÏÖŸÇŒß' ]+))\b/replace_allergen_in_caps($language,$product_ref,$1,$`)/esg;
				# match ALL-CAPS including space and - (for NOIX DE SAINT-JACQUES)
				$text =~ s/\b([A-ZÌÒÁÉÍÓÚÝÂÊÎÔÛÃÑÕÄËÏÖŸÇŒß][A-ZÌÒÁÉÍÓÚÝÂÊÎÔÛÃÑÕÄËÏÖŸÇŒß]([A-ZÌÒÁÉÍÓÚÝÂÊÎÔÛÃÑÕÄËÏÖŸÇŒß'\- ]+))\b/replace_allergen_in_caps($language,$product_ref,$1,$`)/esg;
			}

			# allergens between separators

			#print STDERR "current text 2: $text\n";
			# print STDERR "separators\n";

			# positive look ahead for the separators so that we can properly match the next word
			# match at least 3 characters so that we don't match the separator
			# Farine de blé 97% -> make numbers be separators
			$text =~ s/(^| - |_|\(|\[|\)|\]|,|$the|$and|$of|;|\.|$)((\s*)\w.+?)(?=(\s*)(^| - |_|\(|\[|\)|\]|,|$and|;|\.|\b($traces_regexp)\b|$))/replace_allergen_between_separators($language,$product_ref,$1, $2, "",$`)/iesg;

			$product_ref->{"ingredients_text_with_allergens_" . $language} = $text;

			if ($language eq $product_ref->{lc}) {
				$product_ref->{"ingredients_text_with_allergens"} = $text;
			}

		}
	}

	foreach my $field ("allergens", "traces") {

		# concatenate allergens and traces fiels from ingredients and entered by users

		$product_ref->{$field . "_from_ingredients"} =~ s/, $//;

		my $allergens = $product_ref->{$field . "_from_ingredients"};

		if ((defined $product_ref->{$field}) and ($product_ref->{$field} ne "")) {
			$allergens .= ", " . $product_ref->{$field};
		}

		$product_ref->{$field . "_hierarchy" } = [ gen_tags_hierarchy_taxonomy($product_ref->{lc}, $field, $allergens) ];
		$product_ref->{$field . "_tags" } = [];
		# print STDERR "result for $field : ";
		foreach my $tag (@{$product_ref->{$field . "_hierarchy" }}) {
			push @{$product_ref->{$field . "_tags" }}, get_taxonomyid($product_ref->{lc}, $tag);
			# print STDERR " - $tag";
		}
		# print STDERR "\n";
	}

}

1;
