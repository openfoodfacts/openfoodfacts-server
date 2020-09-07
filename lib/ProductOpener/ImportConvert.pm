# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2020 Association Open Food Facts
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

# This package is used to convert CSV or XML file sent by producers to
# an Open Food Facts CSV file that can be loaded with import_csv_file.pl / Import.pm

=head1 NAME

ProductOpener::ImportConvert - help to convert product data files from producers to the Open Food Facts format.

=head1 SYNOPSIS

C<ProductOpener::ImportConvert> provides functions to load and process CSV and XML files to
convert the product data they contain to a format that can be imported on Open Food Facts.

    use ProductOpener::ImportConvert qw/:all/;

..


=head1 DESCRIPTION

..

=cut

package ProductOpener::ImportConvert;

use utf8;
use Modern::Perl '2017';
use Exporter    qw< import >;

use Log::Any qw($log);

use Storable qw(dclone);
use Text::Fuzzy;

BEGIN
{
	use vars       qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(

		%fields
		@fields
		%products

		&assign_value
		&remove_value

		&get_list_of_files

		&load_csv_file

		&load_xml_file

		&print_csv_file
		&print_stats

		&match_taxonomy_tags
		&match_specific_taxonomy_tags
		&match_labels_in_product_name
		&assign_countries_for_product
		&assign_main_language_of_product

		&assign_quantity_from_field

		&clean_fields
		&clean_weights
		&clean_fields_for_all_products

		&extract_nutrition_facts_from_text

		%global_params

		@xml_errors

		);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::Food qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;
use Time::Local;
use Data::Dumper;
use Text::CSV;
use HTML::Entities qw(decode_entities);

%fields = ();
@fields = ();
%products = ();
@xml_errors = ();

my $mode = "append";

=head1 FUNCTIONS

=cut

sub get_or_create_product_for_code($) {

	my $code = shift;

	if (not defined $code) {
		die("Undefined code $code");
	}
	elsif ($code eq "") {
		die("Empty code $code");
	}
	elsif ($code !~ /^\d+$/) {
		die("Invalid code $code");
	}

	if (not defined $products{$code}) {
		$products{$code} = {};
		assign_value($products{$code}, 'code', $code);
		apply_global_params($products{$code});
	}
	return $products{$code};
}

sub assign_value($$$) {

	my $product_ref = shift;
	my $target = shift;
	my $value = shift;

	my $field = $target;

	# empty value? skip

	if ((not defined $value) or ($value =~ /^(\s|\.|\\|\/)*$/)) {
		return;
	}

	# !categories : only add the value if it exists in the corresponding tags taxonomy
	if ($target =~ /^!/) {
		$field = $';
	}

	if (not defined $product_ref) {
		die("product_ref is undef");
	}

	if (not exists $fields{$field}) {
		$fields{$field} = 1;
		push @fields, $field;
	}

	if (($field =~ /_value$/) and (defined $value)) {
		# nutrients: remove useless 0
		# 2482.0000   39.8000
		$value =~ s/(\.|\,)(0+)$//;
		$value =~ s/(\.|\,)(\d*[1-9])0+$/$1$2/;
	}

	if ((defined $product_ref->{$field}) and ($product_ref->{$field} ne "") and ($mode eq "append")
		and ($product_ref->{$field} ne $value)) {

		if (exists $tags_fields{$field}) {
			if ($target =~ /^!/) {
				# only add the field if it exists in the taxonomy
				my $canon_tagid = canonicalize_taxonomy_tag($product_ref->{lc}, $field, $value);
				if (exists_taxonomy_tag($field, $canon_tagid)) {
					$product_ref->{$field} .= ", " . $value;
				}
			}
			else {
				$product_ref->{$field} .= ", " . $value;
			}
		}
		# language field?
		elsif (($field =~ /^(.+)_(\w\w)$/) and (defined $language_fields{$1})) {
			$product_ref->{$field} .= "\n" . $value;
		}
		# we have a different value that we cannot append, replace it
		else {
			$product_ref->{$field} = $value;
		}
	}
	else {
		$product_ref->{$field} = $value;
	}

	return;
}


sub remove_value($$$) {

	my $product_ref = shift;
	my $target = shift;
	my $value = shift;

	my $field = $target;

	if (defined $product_ref->{$field}) {
		$field =~ s/(, )?$value//ig;
	}

	return;
}


sub apply_global_params($) {

	my $product_ref = shift;

	$mode = "append";


	foreach my $field (sort keys %global_params) {

		assign_value($product_ref, $field, $global_params{$field});
	}

	return;
}

sub apply_global_params_to_all_products() {

	$mode = "append";

	foreach my $code (sort keys %products) {
		apply_global_params($products{$code});
	}

	return;
}


# some producers send us data for products in different languages sold in different markets

sub assign_main_language_of_product($$$) {

	my $product_ref = shift;
	my $lcs_ref = shift;
	my $default_lc = shift;

	if ((not defined $product_ref->{lc}) or (not defined $product_ref->{"product_name_" . $product_ref->{lc}})) {

		foreach my $possible_lc (@{$lcs_ref}) {
			if ((defined $product_ref->{"product_name_" . $possible_lc}) and ($product_ref->{"product_name_" . $possible_lc} !~ /^\s*$/)) {
				$log->info("assign_main_language_of_product: assigning value", { lc => $possible_lc}) if $log->is_info();
				assign_value($product_ref, "lc", $possible_lc);
				last;
			}
		}
	}

	if (not defined $product_ref->{lc}) {
		$log->info("assign_main_language_of_product: assigning default value", { lc => $default_lc}) if $log->is_info();
		assign_value($product_ref, "lc", $default_lc);
	}

	return;
}

sub assign_countries_for_product($$$) {

	my $product_ref = shift;
	my $lcs_ref = shift;
	my $default_country = shift;

	foreach my $possible_lc (keys %{$lcs_ref}) {
		if (defined $product_ref->{"product_name_" . $possible_lc}) {
			assign_value($product_ref,"countries", $lcs_ref->{$possible_lc});
			$log->info("assign_countries_for_product: found lc - assigning value", { lc => $possible_lc, countries => $lcs_ref->{$possible_lc}}) if $log->is_info();
		}
	}

	if (not defined $product_ref->{countries}) {
		assign_value($product_ref,"countries", $default_country);
		$log->info("assign_countries_for_product: assigning default value", { countries => $default_country}) if $log->is_info();
	}

	return;
}


# Match all tags that exist in a taxonomy. Needs the input field to be split, so there must be separators.

sub match_taxonomy_tags($$$$) {

	my $product_ref = shift;
	my $source = shift;
	my $target = shift;
	my $options_ref = shift;

	# logo ab
	# logo bio européen : nl-bio-01 agriculture pays bas      1

	# try to parse some fields to find tags
	#match_taxonomy_tags($product_ref, "spe_bio_fr", "labels",
	#{
	#	split => ',|\/|\r|\n|\+|:|;|\b(logo|picto)\b',
	#	# stopwords =>
	#}
	#);

	if ((defined $product_ref->{$source}) and ($product_ref->{$source} ne "")) {

		$log->trace("match_taxonomy_tags: init", { source => $source, value => $product_ref->{$source}, target => $target}) if $log->is_trace();

		my @values = ($product_ref->{$source});
		if ((defined $options_ref) and (defined $options_ref->{split}) and ($options_ref->{split} ne "")) {
			@values = split(/$options_ref->{split}/i, $product_ref->{$source});
		}
		foreach my $value (@values) {

			next if not defined $value;

			# remove stopwords
			if (defined $options_ref->{stopwords}) {
				my $stopwords = $options_ref->{stopwords};
				$value =~ s/\b$stopwords\b//ig;
			}

			$value =~ s/^\s+//;
			$value =~ s/\s+$//;

			my $canon_tag = canonicalize_taxonomy_tag($product_ref->{lc}, $target, $value);
			$log->trace("match_taxonomy_tags: split value", { value => $value, canon_tag => $canon_tag}) if $log->is_trace();


			if (exists_taxonomy_tag($target, $canon_tag)) {

				assign_value($product_ref, $target, $canon_tag);
				$log->info("match_taxonomy_tags: assigning value", { source => $source, value => $canon_tag, target => $target}) if $log->is_info();
			}
			# try to see if we have a packager code
			# e.g. from Carrefour: Fabriqué en France par EMB 29181 (F) ou EMB 86092A (G) pour Interdis.
			elsif (($value =~ /^((e|emb)(\s|-|\.)*(\d{5})(\s|-|\.)*(\w)?)$/i)
				or ($value =~ /([a-z][a-z])(\s|\.|-)+\d\d(\s|\.|-)+\d\d\d(\s|\.|-)+\d\d\d(\s|\.|-)+(ce|ec|eg)/i)) {
				assign_value($product_ref,"emb_codes", $value);
				$log->info("match_taxonomy_tags: found packaging code - assigning value", { source => $source, value => $value, target => "emb_codes"}) if $log->is_info();
			}
		}
	}

	return;
}


# Match only specific tags (e.g. "organic" + "label rouge" in product name)

sub match_specific_taxonomy_tags($$$$) {

	my $product_ref = shift;
	my $source = shift;
	my $target = shift;
	my $tags_ref = shift;

	my $tag_lc = $product_ref->{lc};

	$log->trace("match_specific_taxonomy_tags - start", { source => $source, source_value => $product_ref->{$source}, target => $target, tag_lc => $tag_lc, tags_ref => $tags_ref}) if $log->is_trace();

	if ((defined $product_ref->{$source}) and ($product_ref->{$source} ne "")) {

		foreach my $tagid (@{$tags_ref}) {

			$log->trace("match_specific_taxonomy_tags - looping through tags", { tagid => $tagid}) if $log->is_trace();

			if (defined $translations_to{$target}{$tagid}{$tag_lc}) {

				# the synonyms below also contain the main translation as the first entry

				my $tag_lc_tagid = get_string_id_for_lang($tag_lc, $translations_to{$target}{$tagid}{$tag_lc});

				my @synonyms = ();

				foreach my $synonym (@{$synonyms_for{$target}{$tag_lc}{$tag_lc_tagid}}) {
					push @synonyms, $synonym;
				}

				my $tag_regexp = "";
				foreach my $synonym (sort { length($b) <=> length($a) } @synonyms) {
					# simple singulars and plurals
					my $singular = $synonym;
					$synonym =~ s/s$//;
					$tag_regexp .= '|' . $synonym . '|' . $synonym . 's'  ;

					my $unaccented_synonym = unac_string_perl($synonym);
					if ($unaccented_synonym ne $synonym) {
						$tag_regexp .= '|' . $unaccented_synonym . '|' . $unaccented_synonym . 's';
					}

				}
				$tag_regexp =~ s/^\|//;

				$log->trace("match_specific_taxonomy_tags - regexp", { tag_regexp => $tag_regexp}) if $log->is_trace();
				$log->trace("match_specific_taxonomy_tags - source value", { source_value => $product_ref->{$source}}) if $log->is_trace();

				if ($product_ref->{$source} =~ /\b(${tag_regexp})\b/i) {
					$log->info(
						"match_specific_taxonomy_tags: assigning value",
						{   matching => $1,
							source   => $source,
							value    => $tagid,
							target   => $target
						}
					) if $log->is_info();
					assign_value($product_ref, $target, $tagid);
				}
			}
		}
	}

	return;
}

sub match_labels_in_product_name($) {

	my $product_ref = shift;
	my $tag_lc = $product_ref->{lc};

	my @tags = qw(en:organic en:fair-trade);

	if ($tag_lc eq "fr") {
		# current canonical name for Label Rouge is en:label-rouge which is weird and may change
		push @tags, qw(en:label-rouge fr:label-rouge fr:bleu-blanc-coeur);
	}

	match_specific_taxonomy_tags($product_ref, "product_name_" . $tag_lc, "labels", \@tags);

	return;
}


sub split_allergens($) {
	my $allergens = shift;

	# simple allergen (not an enumeration) -> return _$allergens_
	if (($allergens !~ /,/)
		and (not ($allergens =~ / (et|and) /i))) {
		return "_" . $allergens . "_";
	}
	else {
		return $allergens;
	}
}



=head2 assign_quantity_from_field ( $product_ref, $field )

Look for a quantity in a field like a product name.
Assign it to the quantity and remove it from the field.

=cut

sub assign_quantity_from_field($$) {

	my $product_ref = shift;
	my $field = shift;

	if ((defined $product_ref->{$field}) and ((not defined $product_ref->{quantity}) or ($product_ref->{quantity} eq ""))) {

		if ($product_ref->{$field} =~ /\b\(?((\d+)\s?x\s?)?(\d+\.?\,?\d*)\s?(g|gr|kg|kgr|l|cl|ml|dl)\s?(x\s?(\d+))?\)?\s*$/i) {

			my $before = $`;

			# If we have something too complex, don't do anything
			# e.g. Barres de Céréales (8+4) x 25g

			# if we have a single x or a * before, skip
			if (not (
				($before =~ /(\sx|\*)\s*$/i)
					)) {

				$product_ref->{$field} = $before;

				if (defined $2) {
					assign_value($product_ref, "quantity", $2 . " X " . $3 . " " . $4);
				}
				elsif (defined $6) {
					assign_value($product_ref, "quantity", $6 . " X " . $3 . " " . $4);
				}
				else {
					assign_value($product_ref, "quantity", $3 . " " . $4);
				}

				$product_ref->{$field} =~ s/\s+$//;
			}
		}

	}

	return;
}


sub clean_weights($) {

	my $product_ref = shift;

	# normalize weights

	foreach my $field ("quantity", "serving_size", "net_weight", "drained_weight", "total_weight", "volume") {

		# normalize unit
		if (defined $product_ref->{$field . "_unit"}) {

			if ($product_ref->{$field . "_unit"} =~ /^(-|n\/a|na|nr|ns|\.)*$/i) {
				delete $product_ref->{$field . "_unit"};
			}
			else {
				$product_ref->{$field . "_unit"} =~ s/grammes/g/i;
				$product_ref->{$field . "_unit"} =~ s/grams/g/i;
				$product_ref->{$field . "_unit"} =~ s/grm/g/i;
				$product_ref->{$field . "_unit"} =~ s/gr/g/i;
				if ($product_ref->{$field . "_unit"} !~ /^(kJ|L)$/) {
					$product_ref->{$field . "_unit"} = lc($product_ref->{$field . "_unit"});
				}
			}
		}

		# we can be passed values in a specific unit (e.g. quantity_in_mg)
		if (not defined $product_ref->{$field}) {
			foreach my $u ('kg', 'g', 'mg', 'mcg', 'l', 'dl', 'cl', 'ml') {
				if ((defined $product_ref->{$field . "_value_in_" . $u})
					and ($product_ref->{$field . "_value_in_" . $u} ne "")) {
					assign_value($product_ref, $field . "_value", $product_ref->{$field . "_value_in_" . $u});
					assign_value($product_ref, $field . "_unit", $u);
					last;
				}
			}
		}

		# if we have a value but no unit, assume the unit is grams for weights, if the value is greater than 20 and less than 5000
		if ((defined $product_ref->{$field . "_value"})
			and ($product_ref->{$field . "_value"} ne "")
			and ((not defined $product_ref->{$field . "_unit"})
				or ($product_ref->{$field . "_unit"} eq ""))
			and ($product_ref->{$field . "_value"} > 20)
			and ($product_ref->{$field . "_value"} < 2000)
			and ($field =~ /weight/)) {
			assign_value($product_ref, $field . "_unit", "g");
		}

		# We may be passed quantity_value_unit, in that case assign it to quantity
		if ((not defined $product_ref->{$field})
			and (defined $product_ref->{$field . "_value_unit"})
			and ($product_ref->{$field . "_value_unit"} ne "")) {

			assign_value($product_ref, $field, $product_ref->{$field . "_value_unit"});
		}

		# for quantity and serving_size, we might have 3 values:
		# - a quantity with a non normalized unit ("2 biscuits)
		# - a value and a unit ("30 g")
		# in this case, we can combine them: "2 biscuits (30 g)"

		if ((($field eq "quantity") or ($field eq "serving_size"))
			and (defined $product_ref->{$field}) and ($product_ref->{$field} ne "")
			and (defined $product_ref->{$field . "_value"}) and ($product_ref->{$field . "_value"} ne "")
			and (defined $product_ref->{$field . "_unit"})

			# check we have not already combined the value and unit
			and (not (index($product_ref->{$field}, $product_ref->{$field . "_value"} . " " . $product_ref->{$field . "_unit"}) >= 0)) ) {

			assign_value($product_ref, $field, $product_ref->{$field} . " (" . $product_ref->{$field . "_value"} . " " . $product_ref->{$field . "_unit"} . ")" );
		}
		elsif ((not defined $product_ref->{$field})
			and (defined $product_ref->{$field . "_value"})
			and ($product_ref->{$field . "_value"} ne "")
			and (defined $product_ref->{$field . "_unit"}) ) {

			assign_value($product_ref, $field, $product_ref->{$field . "_value"} . " " . $product_ref->{$field . "_unit"});
		}

		if (defined $product_ref->{$field}) {
			# 2295[GR]
			# 200 (2x100)[GR]
			# (2x230g[GR]
			$product_ref->{$field} =~ s/g\[gr\]/g/ig;
			$product_ref->{$field} =~ s/(\d|[\)])\s?\[(\w+)\]/lc("$1 $2")/ieg;

			# 420g -> 420 g
			$product_ref->{$field} =~ s/(\d|[\)])( )?(grms|grm|grams|grammes|gramme|gr|g)(\.)?/$1 g/i;
			$product_ref->{$field} =~ s/(\d)( )?(ml|millilitres)(\.)?/$1 ml/i;
			$product_ref->{$field} =~ s/(litre|litres|liter|liters|lt)\b/l/i;
			$product_ref->{$field} =~ s/kilogramme|kilogrammes|kgs|kgrs|kgr/kg/i;
			$product_ref->{$field} =~ s/(\d)(\s)*(kg|g|gr|mg|µg|oz|l|dl|cl|ml|(fl(\.?)(\s)?oz))e?\b/lc("$1 $3")/ieg;
			# 250 GR -> 250 g
			$product_ref->{$field} =~ s/(\d) gr\b/$1 g/g;

			# 2.00 2,0 etc.
			$product_ref->{$field} =~ s/(\d)(\.|,)(0+)( |$)/$1$4/;

			# 6x90g
			$product_ref->{$field} =~ s/(\d)(\s*)x(\s*)(\d)/$1 x $4/i;

			# kge -> kg e
			# but 1 pièce
			$product_ref->{$field} =~ s/(\d\s(\w?\w?\w?))e$/$1 e/;

			# remove the e
			$product_ref->{$field} =~ s/ e\b//g;

			# 1 units (with units in plural)
			$product_ref->{$field} =~ s/^1 (unit|piece|pièce)s$/1 $1/ig;
		}

	}

	# parse total weight

	# carrefour
	# poids net = poids égoutté = 450 g [zemetro]
	# poids net : 240g (3x80ge)       2
	# poids net égoutté : 150g[zemetro]       2
	# poids net : 320g [zemetro] poids net égoutté : 190g contenance : 370ml  2
	# poids net total : 200g [zemetro] poids net égoutté : 140g contenance 212ml

	my %regexps = (
fr => {
net_weight => '(poids )?net( total)?',
drained_weight => '(poids )?(net )?(égoutté|egoutte)',
volume => '(volume|contenance)( net|nette)?( total)?',
},

# Peso neto: 480 g (6 x 80 g) Peso neto escurrido: 336 g (6x56 g)

es => {
net_weight => '(peso )?neto( total)?',
drained_weight => '(peso )?(neto )?(escurrido)',
#volume => '(volume|contenance)( net|nette)?( total)?',
},

	);

	if (defined $product_ref->{total_weight}) {

		$log->debug("clean_weights", { lc => $product_ref->{lc}, total_weight => $product_ref->{total_weight} }) if $log->is_debug();

		if ((defined $product_ref->{lc}) and (defined $regexps{$product_ref->{lc}})) {
			foreach my $field ("net_weight", "drained_weight", "volume") {
				if ((not defined $product_ref->{$field})
					and (defined $regexps{$product_ref->{lc}}{$field})) {

					my $regexp = $regexps{$product_ref->{lc}}{$field};

					if ($product_ref->{total_weight} =~ /$regexp/i ) {

						my $after = $';
						# match number with unit

						$log->debug("clean_weights - matched", { field => $field, after => $after }) if $log->is_debug();

						if ($after =~ /\s?:?\s?(\d[0-9\.\,]+\s*(\w+))/i) {
							assign_value($product_ref, $field, $1);
						}
					}
				}
			}
		}
	}

	# Casino : the format field assigned to quantity contains sometimes dates or other entries
	# Remove the quantity if it does not look like a valid quantity

	if (defined $product_ref->{quantity}) {
		# Dates
		if ($product_ref->{quantity} =~ /^'?\s*\d\d\.\d\d\.\d\d\d\d\s*$/) {
			delete $product_ref->{quantity};
		}

		# 1/2 , 3/4
		if ($product_ref->{quantity} =~ /^'?\s*\d+((\/)\d+)\s*$/i) {
			delete $product_ref->{quantity};
		}

		# No numbers (e.g. "sachet", "bouteille")
		if ($product_ref->{quantity} !~ /[1-9]/) {
			delete $product_ref->{quantity};
		}
	}


	my $normalized_quantity;
	if (defined $product_ref->{quantity}) {
		$normalized_quantity = normalize_quantity($product_ref->{quantity});
	}

	# empty or incomplete quantity, but net_weight etc. present
	if ((not defined $product_ref->{quantity}) or ($product_ref->{quantity} eq "") or (not defined $normalized_quantity)
		or (($product_ref->{lc} eq "fr") and ($product_ref->{quantity} =~ /^\d+ tranche([[:alpha:]]*)$/)) # French : "6 tranches épaisses"
		or ($product_ref->{quantity} =~ /^\(.+\)$/)     #  (4 x 125 g)
		) {

		# See if we have other quantity related values: net_weight_value	net_weight_unit	drained_weight_value	drained_weight_unit	volume_value	volume_unit

		my $extra_quantity;

		foreach my $field ("net_weight", "drained_weight", "total_weight", "volume") {
			if ((defined $product_ref->{$field}) and ($product_ref->{$field} ne "")
				and ($product_ref->{$field} =~ /^\d/) ) {   # make sure we have a number
				$extra_quantity = $product_ref->{$field};
				last;
			}
		}

		if (defined $extra_quantity) {
			if ((defined $product_ref->{quantity}) and ($product_ref->{quantity} ne "")) {
				if ($product_ref->{quantity} =~ /^\(.+\)$/) {
					$product_ref->{quantity} = $extra_quantity . " " . $product_ref->{quantity};
				}
				else {
					$product_ref->{quantity} .= " ($extra_quantity)";
				}
			}
			else {
				assign_value($product_ref, 'quantity', $extra_quantity);
			}
		}
	}

	return;
}


=head2 clean_fields ( $imported_product_ref )

This function:
- extracts values from some fields to populate other fields
(e.g. the quantity can be passed in the product name)
- split some field values (e.g. remove the brand from the product name)
- cleans the fields

Warning: this function is intended to be applied only to imported product data.
It should not be used on general products, as some of the cleaning may be too aggressive in the general case.
e.g. if the ingredients field is of the form "something Ingredients: list of ingredients", then
"something" is assigned to the generic name of the product.

=cut

sub clean_fields($) {

	my $product_ref = shift;

	$log->debug("clean_fields - start", {  }) if $log->is_debug();

	foreach my $field (keys %{$product_ref}) {

		# If we have generic_name but not product_name, also assign generic_name to product_name
		if (($field =~ /^generic_name_(\w\w)$/) and (not defined $product_ref->{"product_name_" . $1})) {
			$product_ref->{"product_name_" . $1} = $product_ref->{"generic_name_" . $1};
		}
	}

	# Quantity in the product name?
	assign_quantity_from_field($product_ref, "product_name_" . $product_ref->{lc});

	# Populate the quantity / weight fields from their quantity_value_unit, quantity_value, quantity_unit etc. components
	clean_weights($product_ref);

	foreach my $field (keys %{$product_ref}) {

		# Split the generic name from the ingredient list
		# Warning: this should be done only once, on the producers platform, when we import product data from a producer
		# It should not be done again when we import product data from the producers platform to the public database
		if (($server_options{producers_platform}) and ($field =~ /^ingredients_text_(\w\w)/)) {
			my $ingredients_lc = $1;
			split_generic_name_from_ingredients($product_ref, $ingredients_lc);
		}

		if ($field =~ /^product_name_(\w\w)/) {
			# Remove brand from product name
			if (defined $product_ref->{brands}) {
				foreach my $brand (split(/,/, $product_ref->{brands})) {
					$brand =~ s/^\s+//;
					$brand =~ s/\s+$//;
					$product_ref->{$field} =~ s/\s+$brand$//i;
				}
			}
		}
	}

	foreach my $field (keys %{$product_ref}) {

		$log->debug("clean_fields", { field=>$field, value=>$product_ref->{$field} }) if $log->is_debug();

		# HTML entities
		# e.g. P&acirc;tes alimentaires cuites aromatis&eacute;es au curcuma
		if ($product_ref->{$field} =~ /\&/) {
			$product_ref->{$field} = decode_entities($product_ref->{$field});
		}

		$product_ref->{$field} =~ s/(\&nbsp)|(\xA0)/ /g;
		$product_ref->{$field} =~ s/’/'/g;

		$product_ref->{$field} =~ s/<p>|<\/p>/\n/ig;

		# Remove extra line feeds
		$product_ref->{$field} =~ s/<br( )?(\/)?>/\n/ig;
		$product_ref->{$field} =~ s/\r\n/\n/g;
		$product_ref->{$field} =~ s/\n\./\n/g;
		$product_ref->{$field} =~ s/\n\n(\n+)/\n\n/g;

		# Turn line feeds to spaces for some fields

		if (($field =~ /product_name/) or ($field =~ /generic_name/)) {
			$product_ref->{$field} =~ s/\n/ /g;
		}

		# Remove starting / ending spaces and punctuation

		$product_ref->{$field} =~ s/^\.$//;
		$product_ref->{$field} =~ s/^(\.|\s)+//;
		$product_ref->{$field} =~ s/\s*$//;
		$product_ref->{$field} =~ s/^\s*//;
		$product_ref->{$field} =~ s/(\s|-|_|;|,)*$//;

		if ($product_ref->{$field} =~ /^(\s|-|\.|_)$/) {
			$product_ref->{$field} = "";
		}

		# bad EMB codes (followed by a city) (e.g. Sainte-Lucie)
		#
		if ($field eq "emb_codes") {
			# Remove anything that starts with 4 letters
			# EMB 60282A - Gouvieux (Oise, France)
			$product_ref->{$field} =~ s/\s*(\s-|,)\s+([[:alpha:]]{4}).*//;

			# FR 62.907.030 EC (DANS UN OVALE)
			$product_ref->{$field} =~ s/\(?dans un ovale\)?//ig;
		}

		# Origin of ingredients that contains other things than tags (e.g. Leroux)
		# FRANCE, La chicorée LEROUX est semée, cultivée et produite en France

		if ($field eq "origins") {
			my $canon_tagid = canonicalize_taxonomy_tag($product_ref->{lc}, "countries", $product_ref->{$field});
			if (not exists_taxonomy_tag("countries", $canon_tagid)) {
				assign_value($product_ref, "origin_" . $product_ref->{lc}, $product_ref->{$field});
				delete $product_ref->{$field};
			}
		}

		# tag fields: turn separators to commas
		# Sans conservateur / Sans huile de palme
		# ! packaging codes can have / :  ES 12.06648/C CE
		if (exists $tags_fields{$field}) {
			$product_ref->{$field} =~ s/\s?(;|( \/ )|\n)+\s?/, /g;
		}


		# Lowercase fields in ALL CAPS
		if ($field =~ /^(ingredients_text|product_name|generic_name|brands)/) {
			if (($product_ref->{$field} =~ /[A-Z]{4}/)
				and ($product_ref->{$field} !~ /[a-z]/)
				) {
				$product_ref->{$field} = ucfirst(lc($product_ref->{$field}));
				$log->debug("clean_fields - after lowercase", { field=>$field, value=>$product_ref->{$field} }) if $log->is_debug();
			}
		}


		# Ingredients

		if ($field =~ /^ingredients_text/) {

			# Farine de<STRONG> <i>blé</i> </STRONG> - sucre

			# Traces de<b> fruits à coque </b>

			$product_ref->{$field} =~ s/(<(b|u|i|em|strong)>)+/<b>/ig;
			$product_ref->{$field} =~ s/(<\/(b|u|i|em|strong)>)+/<\/b>/ig;

			$product_ref->{$field} =~ s/<b>\s+/ <b>/ig;
			$product_ref->{$field} =~ s/\s+<\/b>/<\/b> /ig;

			# empty tags
			$product_ref->{$field} =~ s/<b>\s+<\/b>/ /ig;
			$product_ref->{$field} =~ s/<b><\/b>//ig;
			# _fromage_ _de chèvre_
			$product_ref->{$field} =~ s/<\/b>(| )<b>/$1/ig;

			# d_'œufs_
			# _lait)_
			$product_ref->{$field} =~ s/<b>'(\w)/$1'<b>/ig;
			$product_ref->{$field} =~ s/(\)|\]|\*)<\/b>/<\/b>$1/ig;

			# extrait de malt d'<b>orge - </b>sel
			$product_ref->{$field} =~ s/ -( |)<\/b>/<\/b> -$1/ig;

			$log->debug("clean_fields - ingredients_text - 1", { field=>$field, value=>$product_ref->{$field} }) if $log->is_debug();


			$product_ref->{$field} =~ s/<b>(.*?)<\/b>/split_allergens($1)/iesg;
			$product_ref->{$field} =~ s/<b>|<\/b>//ig;

			$log->debug("clean_fields - ingredients_text - 2", { field=>$field, value=>$product_ref->{$field} }) if $log->is_debug();


			if ($field eq "ingredients_text_fr") {

				# remove single sentence that say allergens are in bold (in Casino data)
				$product_ref->{$field} =~ s/(Les |l')?(information|ingrédient|indication)(s?) ([^\.,]*) (personnes )?((allergiques( (ou|et) intolérant(e|)s)?)|(intolérant(e|)s( (ou|et) allergiques)?))(\.)?//i;
				$product_ref->{$field} = ucfirst($product_ref->{$field});

				$log->debug("clean_fields - ingredients_text - 3", { field=>$field, value=>$product_ref->{$field} }) if $log->is_debug();

				# Missing spaces
				# Poire Williams - sucre de canne - sucre - gélifiant : pectines de fruits - acidifiant : acide citrique.Préparée avec 55 g de fruits pour 100 g de produit fini.Teneur totale en sucres 56 g pour 100 g de produit fini.Traces de _fruits à coque_ et de _lait_..
				$product_ref->{$field} =~ s/\.([A-Z][a-z])/\. $1/g;

				$log->debug("clean_fields - ingredients_text - 4", { field=>$field, value=>$product_ref->{$field} }) if $log->is_debug();

			}

			# persil- poivre blanc -ail
			$product_ref->{$field} =~ s/(\w|\*)- /$1 - /g;
			$product_ref->{$field} =~ s/ -(\w)/ - $1/g;

			#_oeuf 8_%
			$product_ref->{$field} =~ s/_([^_,-;]+) (\d*\.?\d+\s?\%?)_/_$1_ $2/g;

			# _d'arachide_
			# morceaux _d’amandes_ grillées
			if (($field =~ /_fr/) or ((defined $product_ref->{lc}) and ($product_ref->{lc} eq 'fr') and ($field !~ /_\w\w$/))) {
				$product_ref->{$field} =~ s/_(d|l)('|’)([^_,-;]+)_/$1'_$2_/ig;
			}
		}

		if ($field =~ /^ingredients_text_(\w\w)/) {
			my $ingredients_lc = $1;
			$log->debug("clean_fields - before clean_ingredients_text_for_lang ", { field=>$field, value=>$product_ref->{$field} }) if $log->is_debug();
			$product_ref->{$field} = clean_ingredients_text_for_lang($product_ref->{$field}, $ingredients_lc);
			$log->debug("clean_fields - after clean_ingredients_text_for_lang ", { field=>$field, value=>$product_ref->{$field} }) if $log->is_debug();

		}

		if ($field =~ /^nutrition_grade_/) {
			$product_ref->{$field} = lc($product_ref->{$field});
		}

		# remove N, N/A, NA etc.
		# but not "no", "none" that are useful values (e.g. for specific labels "organic:no", allergens : "none")
		$product_ref->{$field} =~ s/(^|,)\s*((n(\/|\.)?a(\.)?)|(not applicable)|unknown|inconnu|inconnue|non renseigné|non applicable|nr|n\/r)\s*(,|$)//ig;
		
		# remove none except for allergens and traces
		if ($field !~ /allergens|traces/) {
			$product_ref->{$field} =~ s/(^|,)\s*(none|aucun|aucune|aucun\(e\))\s*(,|$)//ig;			
		}

		if (($field =~ /_fr/) or ((defined $product_ref->{lc}) and ($product_ref->{lc} eq 'fr') and ($field !~ /_\w\w$/))) {
			$product_ref->{$field} =~ s/^\s*(autre logo)?\s*$//ig;
		}

		$product_ref->{$field} =~ s/ +/ /g;
		$product_ref->{$field} =~ s/,(\s*),/,/g;
		$product_ref->{$field} =~ s/\.(\.+)$/\./;
		$product_ref->{$field} =~ s/(\s|-|;|,)*$//;
		$product_ref->{$field} =~ s/^(\s|-|;|,|\.)+//;
		$product_ref->{$field} =~ s/^(\s|-|;|,|_)+$//;

		# remove empty values for tag fields
		if (exists $tags_fields{$field}) {
			$product_ref->{$field} =~ s/^(,|;|-|_|\/|\\|#|:|\.|\s)+$//;
		}

		# Remove tags
		$product_ref->{$field} =~ s/<(([^>]|\n)*)>//g;

		# Remove whitespace
		$product_ref->{$field} =~ s/^\s+|\s+$//g;
	}

	match_labels_in_product_name($product_ref);

	return;
}


sub clean_fields_for_all_products() {

	foreach my $code (sort keys %products) {
		clean_fields($products{$code});
	}

	return;
}


sub load_xml_file($$$$) {

	my $file = shift;
	my $xml_rules_ref = shift;
	my $xml_fields_mapping_ref = shift;
	my $code = shift; # can be undef or passed if we already know it from the file name

	# try to guess the code from the file name
	if ((not defined $code) and ($file =~ /\D(\d{13})\D/)) {
		$code = $1;
		$log->info("inferring code from file name", { code => $code, file => $file }) if $log->is_info();

	}

	if (defined $code) {
		$code = normalize_code($code);
	}

	$log->info("parsing xml file with XML::Rules", { file => $file, xml_rules => $xml_rules_ref }) if $log->is_info();

	my $parser = XML::Rules->new(rules => $xml_rules_ref);

	my $xml_ref;

	eval { $xml_ref = $parser->parse_file($file); };

	if ($@ ne "") {
		$log->error("error parsing xml file with XML::Rules", { file => $file, error=>$@ }) if $log->is_error();
		push @xml_errors, $file;
		#exit;
	}

	$log->trace("XML::Rules output", { file => $file, xml_ref => $xml_ref }) if $log->is_trace();

	# Skip empty XML files
	if (not defined $xml_ref) {
		return;
	}

	if ($log->is_trace()) {
		binmode STDOUT, ":encoding(UTF-8)";
		open (my $OUT_JSON, ">", "$www_root/data/import_debug_xml.json");
		print $OUT_JSON encode_json($xml_ref);
		close ($OUT_JSON);
	}

	# Some producers (e.g. Auchan) have multiple product codes in one file, with multiple label field values,
	# but without an actual id to make the mapping.

#<ProductFolder Name="Auchan Cremes Dessert Autres Parfums"/>
#-<TradeItems>
#<TradeItem Ean7="" Gtin="3596710402274" Brand="AUCHAN" Packing="" Format="" DenominationCommerciale="CREME DESSERT spÃ©culoos 4X125G"/>
#<TradeItem Ean7="" Gtin="3596710402281" Brand="AUCHAN" Packing="" Format="" DenominationCommerciale="CREME DESSERT baba au rhum 4X125G"/>
#<TradeItem Ean7="" Gtin="3596710406074" Brand="AUCHAN" Packing="" Format="" DenominationCommerciale="CREME DESSERT PISTACHE 4X125G"/>
#<TradeItem Ean7="" Gtin="3596710402250" Brand="AUCHAN" Packing="" Format="" DenominationCommerciale="CREME DESSERT chocolat caramel 4X125G"/>
#<TradeItem Ean7="" Gtin="3596710402267" Brand="AUCHAN" Packing="" Format="" DenominationCommerciale="CREME DESSERT chocolat blanc 4X125G"/>
#<TradeItem Ean7="" Gtin="3596710016495" Brand="AUCHAN" Packing="" Format="" DenominationCommerciale="CREM DESS CAFE 4X125G"/>
#</TradeItems>
# ...
#+<Etiquette localId="347348" name="Crème Dessert Café Auchan x4">
#-<Etiquette localId="347381" name="Crème Dessert Chocolat Caramel Auchan x4">
#<SectionEtiquetage>Crème Dessert Chocolat Caramel Auchan x4</SectionEtiquetage>
#<ConditionnementConcerne>Chocolat Caramel x 4</ConditionnementConcerne>
#<DenominationCommerciale>Crème dessert Caram'choc</DenominationCommerciale>
#<DenominationLegale>Crème dessert aromatisée caramel chocolat</DenominationLegale>

#			multiple_codes => {
#				codes => codes,	# all sub fields will be moved to the root of the split children
#				fuzzy_match => "etiquettes",	# if exists, specify a field that depends on the child
#				fuzzy_from => "DenominationCommerciale", # value from "codes" that will be fuzzy matched to find the id for "fuzzy_match" hash
#			},

	my @xml_refs = ();

	# Multiple products in an array?

	if ($xml_fields_mapping_ref->[0][0] eq "multiple_products") {

		my $array = $xml_fields_mapping_ref->[0][1];

		$log->info("Split multiple products", { file => $file, array => $array }) if $log->is_info();

		if (defined $xml_ref->{$array}) {
			my $i = 1;
			foreach my $new_product_ref (@{$xml_ref->{$array}}) {

				$log->info("Split multiple products - i: " . $i++) if $log->is_info();

				push @xml_refs, $new_product_ref;
			}
		}

		shift @{$xml_fields_mapping_ref};

	}


	# Multiple variant of one product, with different codes?
	elsif ($xml_fields_mapping_ref->[0][0] eq "multiple_codes") {

		$log->info("Split multiple codes (product variants)", { file => $file }) if $log->is_info();

		my $codes = $xml_fields_mapping_ref->[0][1]{codes};

		# fuzzy match?

		my @fuzzy_match_keys = ();
		my @fuzzy_match_keysid = ();
		my $fuzzy_match;

		if (defined $xml_fields_mapping_ref->[0][1]{fuzzy_match}) {

			$fuzzy_match = $xml_fields_mapping_ref->[0][1]{fuzzy_match};
			if (defined $xml_ref->{$fuzzy_match}) {
				@fuzzy_match_keys = sort keys %{$xml_ref->{$fuzzy_match}};
				@fuzzy_match_keysid = map { get_string_id_for_lang("no_language", $_) } @fuzzy_match_keys;
			}
		}

		if (defined $xml_ref->{$codes}) {
			foreach my $new_code (sort keys %{$xml_ref->{$codes}}) {

				$new_code = normalize_code($new_code);

				$log->info("Split multiple products - code", { code => $new_code }) if $log->is_info();

				my $new_xml_ref = dclone($xml_ref);

				$new_xml_ref->{code} = $new_code;
				foreach my $field (sort keys %{$xml_ref->{$codes}{$new_code}}) {

					$log->info("Split multiple products - copy field", { code => $new_code, field => $field }) if $log->is_info();

					$new_xml_ref->{$field} = $xml_ref->{$codes}{$new_code}{$field};
				}

				# Fuzzy matching in other part of the XML file
				if (defined $xml_fields_mapping_ref->[0][1]{fuzzy_from}) {

					my $fuzzy_from = $xml_fields_mapping_ref->[0][1]{fuzzy_from};

					$log->info("Fuzzy match", { fuzzy_from => $fuzzy_from }) if $log->is_info();

					if (defined $new_xml_ref->{$fuzzy_from}) {
						my $tf = Text::Fuzzy->new (get_string_id_for_lang("no_language", $new_xml_ref->{$fuzzy_from}));
						my $nearestid = $tf->nearest (\@fuzzy_match_keysid);
						my $nearest = $fuzzy_match_keys[$nearestid];
						$log->info("Fuzzy match found", { fuzzy_from => $fuzzy_from, value => $new_xml_ref->{$fuzzy_from}, nearest => $nearest }) if $log->is_info();

						foreach my $field (sort keys %{$xml_ref->{$fuzzy_match}{$nearest}}) {

							$log->info("Fuzzy match - copy field", { field => $field }) if $log->is_info();

							$new_xml_ref->{$field} = $xml_ref->{$fuzzy_match}{$nearest}{$field};
						}

					}
				}

				push @xml_refs, $new_xml_ref;
			}
		}

		shift @{$xml_fields_mapping_ref};

	}

	else {
		push @xml_refs, $xml_ref;
	}

	$log->info("Mapping XML fields", { file => $file }) if $log->is_info();

#		my @xml_fields_mapping = (
#
#			# get the code first
#
#			["fields.AL_CODE_EAN.FR", "code"],
#			["ProductCode", "producer_version_id"],
#			["fields.AL_INGREDIENT.*", "ingredients_text_*"],

	# $code = undef;

	my $i = 1;

	foreach my $xml_ref (@xml_refs) {

	my $product_ref;

	if (defined $code) {
		$product_ref = get_or_create_product_for_code($code);
	}

	foreach my $field_mapping_ref (@{$xml_fields_mapping_ref}) {
		my $source = $field_mapping_ref->[0];
		my $target = $field_mapping_ref->[1];

		$log->trace("source $i", { source=>$source, target=>$target }) if $log->is_trace();

		my $current_tag = $xml_ref;

		print STDERR "\nsource: $source\n";

		foreach my $source_tag (split(/\./, $source)) {
			print STDERR "source_tag: $source_tag\n";

			# commands

			# 	["[delete_except]", "producer|emb_codes|origin"],

			if ($source_tag eq '[delete_except]') {
				my $regexp = $target;
				foreach my $field ( sort keys %{$product_ref}) {
					next if $field eq 'code';
					next if $field =~ /$regexp/i;
					$log->trace("deleting existing field", { field=>$field }) if $log->is_trace();
					delete $product_ref->{$field};
				}
			}

			# multiple values in different languages

			elsif ($source_tag eq '*') {
				foreach my $tag ( keys %{$current_tag}) {
					my $tag_target = $target;

					# special case where we have something like allergens.nuts = traces
					if ($tag_target eq "value_as_target_and_source_as_value") {
						print STDERR "* tag key: $tag - target: $tag_target\n";
						if ((defined $current_tag->{$tag}) and (not ref($current_tag->{$tag})) and ($current_tag->{$tag} ne '')) {
							print STDERR "assign $tag to $current_tag->{$tag}\n";

							assign_value($product_ref, $current_tag->{$tag}, $tag);
						}
					}
					else {

						$tag_target =~ s/\*/$tag/;
						$tag_target = lc($tag_target);
						print STDERR "* tag key: $tag - target: $tag_target\n";
						if ((defined $current_tag->{$tag}) and (not ref($current_tag->{$tag})) and ($current_tag->{$tag} ne '')) {
							print STDERR "$tag value is a scalar: $current_tag->{$tag}, assign value to $tag_target\n";
							if ($tag_target eq 'code') {
								$code = $current_tag->{$tag};

								$code = normalize_code($code);
								$product_ref = get_or_create_product_for_code($code);
							}
							assign_value($product_ref, $tag_target, $current_tag->{$tag});

							if ($tag_target eq 'emb_codes') {
								print STDERR "emb_codes : " . $product_ref->{$tag_target} . "\n";
							}
						}
					}
				}
				last;
			}

			# Array - e.g. ["nutrients.ENERKJ.[0].RoundValue", "nutriments.energy_kJ"],

			elsif ($source_tag =~ /^\[(\d+)\]$/) {
				my $i = $1;
				if ((ref($current_tag) eq 'ARRAY') and (defined $current_tag->[$i])) {
					print STDERR "going down to array element $source_tag - $i\n";
					$current_tag = $current_tag->[$i];
				}
			}

			# Array with several versions identified by a number, take the highest one
			# <ADO LIB="JUS DE RAISIN" LIB2="Pur jus de raisin 1L" ADO="01" SECT_OQALI="Jus et nectars"
			# ["ADO.[max.ADO].COMP.ING", "ingredients_text_fr"],

			elsif ($source_tag =~ /^\[max:([^\]]+)\]$/) {
				my $version = $1;
				if (ref($current_tag) eq 'ARRAY') {
					my $max = undef;
					my $max_version_ref = undef;
					foreach my $version_ref (@{$current_tag}) {
						if ((defined $version_ref->{$version}) and (not defined $max) or ($version_ref->{$version} > $max)) {
							$max = $version_ref->{$version};
							$max_version_ref = $version_ref;
						}
					}
					if (defined $max_version_ref) {
						print STDERR "going down to array element $source_tag - version $max\n";
						$current_tag = $max_version_ref;
					}
				}
			}

			elsif (defined $current_tag->{$source_tag}) {
				if ((ref($current_tag->{$source_tag}) eq 'HASH') or (ref($current_tag->{$source_tag}) eq 'ARRAY')) {
					print STDERR "going down to hash $source_tag\n";
					$current_tag = $current_tag->{$source_tag};
				}
				elsif ((defined $current_tag->{$source_tag}) and (not ref($current_tag->{$source_tag})) and ($current_tag->{$source_tag} ne '')) {

					my $value = $current_tag->{$source_tag};

					print STDERR "$source_tag is a scalar: $value, assign value to $target\n";
					if ($target eq 'code') {
						$code = $value;
						$code = normalize_code($code);
						$product_ref = get_or_create_product_for_code($code);
					}

					my $seen_energy_kj = 0;

					if ($target =~ /^nutriments.(.*)/) {
						$target = $1;

						# skip energy in kcal if we already have energy in kJ
						if (($seen_energy_kj) and ($target =~ /kcal/i)) {
							next;
						}

						if ($target =~ /kj/i) {
							$seen_energy_kj = 1;
						}

						$value =~ s/,/\./;

						if ($target =~ /^(.*)_value$/) {
							assign_value($product_ref, $target, $value);
						}
						elsif ($target =~ /^(.*)_unit$/) {
							assign_value($product_ref, $target, $value);
						}
						elsif ($target =~ /^(.*)_([^_]+)$/) {
								$target = $1;
								my $unit = $2;
								assign_value($product_ref, $target . "_value", $value);
								if ($value ne "") {
									assign_value($product_ref, $target . "_unit", $unit);
								}
								else {
									assign_value($product_ref, $target . "_unit", "");
								}
						}
						else {
							assign_value($product_ref, $target . "_value", $value);
						}
					}
					else {
						assign_value($product_ref, $target, $value);
					}
				}
			}
			else {
				last;
			}
		}

		$i++;
	}

	} #foreach @xml_refs

	return 0;
}


sub load_csv_file($) {

	my $options_ref = shift;

	my $file = $options_ref->{file};
	my $encoding = $options_ref->{encoding};
	my $separator = $options_ref->{separator};
	my $skip_lines = $options_ref->{skip_lines};
	my $skip_lines_after_header = $options_ref->{skip_lines_after_header};
	my $skip_non_existing_products = $options_ref->{skip_non_existing_products};
	my $skip_empty_codes = $options_ref->{skip_empty_codes};
	my @csv_fields_mapping = @{$options_ref->{csv_fields_mapping}};

	# e.g. load_csv_file($file, "UTF-8", "\t", 4);

	$log->info("Loading CSV file", { file => $file }) if $log->is_info();

	my $csv_options_ref = { binary => 1 , sep_char => $separator };

	if (defined $options_ref->{escape_char}) {
		$csv_options_ref->{escape_char} = $options_ref->{escape_char};
	}

	my $csv = Text::CSV->new ( $csv_options_ref )  # should set binary attribute.
                 or die "Cannot use CSV: " . Text::CSV->error_diag ();

	open (my $io, "<:encoding($encoding)", $file) or die("Could not open $file: $!");

	my $i = 0;    # line number

	if (defined $skip_lines) {
		$log->info("Skipping $skip_lines lines before header") if $log->is_info();
		for ($i = 0; $i < $skip_lines; $i++) {
			$csv->getline ($io);
		}
	}

	#my $headers_ref = $csv->getline ($io);
	$i++;

	$csv->header ($io, { detect_bom => 1 });

	if (defined $skip_lines_after_header) {
		$log->info("Skipping $skip_lines_after_header lines after header") if $log->is_info();
		for (my $j = 0; $j < $skip_lines_after_header; $j++) {
			$csv->getline ($io);
			$i++;
		}
	}

	#$log->info("CSV headers", { file => $file, headers_ref=>$headers_ref }) if $log->is_info();

	#$csv->column_names($headers_ref);

	my $product_ref;

	while (my $csv_product_ref = $csv->getline_hr ($io)) {

		$i++; # line number

		$log->info("Reading line $i") if $log->is_info();

		my $code = undef;    # code must be first

		my $seen_energy_kj = 0;

		foreach my $field_mapping_ref (@csv_fields_mapping) {

			my $source_field = $field_mapping_ref->[0];
			my $target_field = $field_mapping_ref->[1];

			# $log->info("Field mapping", { source_field => $source_field, source_field_value => $csv_product_ref->{$source_field}, target_field=>$target_field }) if $log->is_info();

			# There can be other conditions:
			# ["quantity", "nutriments.energy_kJ", ["Nutriment", "Energie"], ["Taille de la portion", "100.0000"], ["Unité", "Kilojoules (kj)"] ],

			my $match = 1;
			my $condition = 2;

			while (($match) and (defined $field_mapping_ref->[$condition])) {

				my $source_condition_field = $field_mapping_ref->[$condition][0];
				my $source_condition_value = $field_mapping_ref->[$condition][1];

				if ((not defined $csv_product_ref->{$source_condition_field})
					or ($csv_product_ref->{$source_condition_field} ne $source_condition_value)) {
					$match = 0;
				}

				$condition++;
			}

			if (defined $csv_product_ref->{$source_field}) {

				if ($match) {
					# print STDERR "defined source field $source_field: " . $csv_product_ref->{$source_field} . "\n";

					my $value = $csv_product_ref->{$source_field};

					if ($target_field eq 'code') {
						$code = $value;
						$code = normalize_code($code);
						print STDERR "reading product code $code\n";

						if ((defined $options_ref->{skip_invalid_codes}) and ($code !~ /^\d+$/)) {
							print STDERR "skipping invalid code\n";
							last;
						}
						elsif ((defined $skip_non_existing_products) and ($skip_non_existing_products) and (not exists $products{$code})) {
							print STDERR "skipping non existing product\n";
							last;
						}
						elsif ((defined $skip_empty_codes) and ((not defined $code) or ($code eq ""))) {
							print STDERR "skipping empty code\n";
							last;
						}
						else {
							$product_ref = get_or_create_product_for_code($code);
						}
					}

					# ["URL", "download_to:/srv/off/imports/ferrero/images/"],
					# https://secure.equadis.com/Equadis/MultimediaFileViewer?thumb=true&idFile=601231&file=10210/8076800105735.JPG
					# -> remove thumb=true to get the full image

					elsif ($target_field =~ /^download_to:/) {

						my $dir = $';
						$dir =~ s/\/$//;

						my $file =  $csv_product_ref->{$source_field};
						$file =~ s/.*\///;

						$file =~ s/[^A-Za-z0-9-_\.]/_/g;

						# get big images from equadis
						$csv_product_ref->{$source_field} =~ s/thumb=true&//;

						# do not download again images that we already have
						# but try again if the size is 0

						if ((! -e "$dir/$file") or ((-s "$dir/$file") < 10000)) {

							print STDERR "downloading image: wget $csv_product_ref->{$source_field} -O $dir/$file\n";
							system("wget \"" . $csv_product_ref->{$source_field} . "\" -O $dir/$file");
							sleep 2;    # there seems to be some limit as we received 403 Forbidden responses
						}
					}

					# ["Energie kJ", "nutriments.energy_kJ"],

					elsif ($target_field =~ /^nutriments.(.*)/) {
						$target_field = $1;

						# skip energy in kcal if we already have energy in kJ
						if (($seen_energy_kj) and ($target_field =~ /kcal/i)) {
							next;
						}

						if ($target_field =~ /kj/i) {
							$seen_energy_kj = 1;
						}

						if ($target_field =~ /^(.*)_([^_]+)$/) {
								$target_field = $1;
								my $unit = $2;
								assign_value($product_ref, $target_field . "_value", $value);
								if ($value ne "") {
									assign_value($product_ref, $target_field . "_unit", $unit);
								}
								else {
									assign_value($product_ref, $target_field . "_unit", "");
								}
						}
						else {
							assign_value($product_ref, $target_field . "_value", $value);
						}
					}
					# ["organic", "labels_y_en:organic"],	# Y or N
					elsif ($target_field =~ /^(.*)_(y|yes|o|oui|1)_(.*)$/) {
						my $tagtype = $1;
						my $condition = $2;
						my $tag_value = $3;
						if ($value =~ /^$condition$/i) {
							assign_value($product_ref, $tagtype, $tag_value);
						}
					}
					else {
						assign_value($product_ref, $target_field, $value);
					}
				}
			}
			else {
				$log->error("undefined source field", { line => $i, source_field=>$source_field, csv_product_ref=>$csv_product_ref }) if $log->is_error();
				die;
			}
		}

	}

	return;
}

sub recursive_list($$);
sub recursive_list($$) {

	my $list_ref = shift;
	my $arg = shift;

	if (-d $arg) {

		my $dir = $arg;

		print STDERR "Opening dir $dir\n";

		if (opendir (DH, "$dir")) {
			foreach my $file (sort { $a cmp $b } readdir(DH)) {

				next if (($file eq '.') or ($file eq '..'));

				recursive_list($list_ref, $dir . "/" . $file);
			}
		}

		closedir (DH);
	}
	else {
		push @{$list_ref}, $arg;
	}

	return;
}

sub get_list_of_files(@) {

	# Read the list of files or directories passed as parameters

	my @files_and_dirs = @_;
	my @files = ();

	foreach my $arg (@files_and_dirs) {

		print STDERR "arg: $arg\n";

		recursive_list(\@files, $arg);
	}

	return @files;
}



sub print_csv_file() {

	my $csv_out = Text::CSV->new ( { binary => 1 , sep_char => "\t" } )  # should set binary attribute.
                 or die "Cannot use CSV: ".Text::CSV->error_diag ();

	print join("\t", @fields) . "\n";

	foreach my $code (sort keys %products) {

		my @values = ();
		my $product_ref = $products{$code};

		foreach my $field (@fields) {
			if (defined $product_ref->{$field}) {
				push @values, $product_ref->{$field};
			}
			else {
				push @values, "";
			}
		}

		$csv_out->print (*STDOUT, \@values) ;
		print "\n";

		print STDERR "code: $code\n";
	}

	return;
}


sub print_stats() {

	my %existing_values = ();
	my $i = 0;

	foreach my $code (sort keys %products) {

		my $product_ref = $products{$code};

		foreach my $field (@fields) {
			if ((defined $product_ref->{$field}) and ($product_ref->{$field} ne "")) {
				defined $existing_values{$field} or $existing_values{$field} = 0;
				$existing_values{$field}++;
			}
		}
		$i++;
	}

	print STDERR "products:\t$i\n";
	foreach my $field (@fields) {
		if (defined $existing_values{$field}) {
			print STDERR "$field:\t$existing_values{$field}\n";
		}
	}

	return;
}


=head2 extract_nutrition_facts_from_text ( LC, TEXT, NUTRIENTS_REF )

C<extract_nutrition_facts_from_text()> extract nutrition facts from a text
blob and return a hash structure that maps Open Food Facts nutrient ids
to the value, unit and modifier.

=head3 Arguments

=head4 LC - Language code

The language the text is in.

=head4 TEXT - Language code

The text that contains the nutrition facts.

=head4 NUTRIENTS_REF

Reference to a hash that will be used to return structured data for the nutrition facts
found in the text.

=head4 NUTRITION_DATA_PER_REF - Per 100g or per serving

Reference to a scalar that will be set to the serving size if the nutrition facts are indicated per serving.

=head4 SERVING_SIZE_REF - Serving size

Reference to a scalar that will be set to the serving size if the nutrition facts are indicated per serving.

=cut

sub extract_nutrition_facts_from_text($$$$$) {

	my $text_lc = shift;
	my $text = shift;
	my $nutrients_ref = shift;
	my $nutrition_data_per_ref = shift;
	my $serving_size_ref = shift;

	if ((defined $text) and ($text ne "")) {

		# Match "per serving" at the start of the text

		if ($text_lc eq "en") {
			if ($text =~ /^\s*(for|per) ((1|a|one) )?serving (of )?\(? ?(\d+((\.|,)\d+)? ?(g|kg|mg|µg|l|dl|cl|ml))/i) {
				${$nutrition_data_per_ref} = "serving";
				${$serving_size_ref} = $5;
			}
		}
		elsif ($text_lc eq "fr") {
			if ($text =~ /^\s*(à la |a la |pour |par |)(1 |une )?portion (de |d'environ )?\(? ?(\d+((\.|,)\d+)? ?(g|kg|mg|µg|l|dl|cl|ml))/i) {
				${$nutrition_data_per_ref} = "serving";
				${$serving_size_ref} = $4;
			}
			# Pour un carré de 10.7g :
			if ($text =~ /^\s*(pour )(\D+) ?(de |d'environ )?\(? ?(\d+((\.|,)\d+)? ?(g|kg|mg|µg|l|dl|cl|ml))/i) {
				${$nutrition_data_per_ref} = "serving";
				${$serving_size_ref} = $4;
			}
		}

		foreach my $nid (sort keys %Nutriments) {

			next if $nid =~ /^#/;

			next if not defined $Nutriments{$nid}{$text_lc};

			# Create a list of synonyms of the nutrient name in the text language

			my $nid_lc = lc($Nutriments{$nid}{$text_lc});
			my $nid_lc_unaccented = unac_string_perl($nid_lc);
			my @synonyms = ($nid_lc);
			if ($nid_lc ne $nid_lc_unaccented) {
				push @synonyms, $nid_lc_unaccented;
			}
			if (defined $Nutriments{$nid}{$text_lc  . "_synonyms"}) {
				foreach my $synonym (@{$Nutriments{$nid}{$text_lc . "_synonyms"}}) {
					push @synonyms, $synonym;
					my $synonym_unaccented = unac_string_perl($synonym);
					if ($synonym_unaccented ne $synonym) {
						push @synonyms, $synonym_unaccented;
					}
				}
			}

			my $value;
			my $unit;
			my $modifier = "";

			foreach my $synonym (@synonyms) {

				# Energy (kJ) -> escape parenthesis
				$synonym =~ s/\(/\\\(/;
				$synonym =~ s/\)/\\\)/;

				# Vitamine D µg  0.4 soit 8  % des AQR*

				if ($text =~ /\b$synonym\s*\(?(g|kg|mg|µg|l|dl|cl|ml|kj|kcal)\b\)?(\s|:)*(<|~)?(\s)*(\d+((\.|\,)\d+)?)/i) {
					$unit = $1;
					$value = $5;
					if ((defined $3) and ($3 ne "")) {
						$modifier = $3;
					}
					last;
				}
				# .36
				if ($text =~ /\b$synonym\s*\(?(g|kg|mg|µg|l|dl|cl|ml|kj|kcal)\b\)?(\s|:)*(<|~)?(\s)*(((\.|\,)\d+))/i) {
					$unit = $1;
					$value = "0" . $5;
					if ((defined $3) and ($3 ne "")) {
						$modifier = $3;
					}
					last;
				}
				elsif ($text =~ /\b$synonym \(?(g|kg|mg|µg|l|dl|cl|ml|kj|kcal)\b\)?(\s|:)*(<|~)?(\s)*(traces)/i) {
					$unit = $1;
					$value = 0;
					$modifier = "~";
					last;
				}
				elsif ($text =~ /\b$synonym \(?(g|kg|mg|µg|l|dl|cl|ml|kj|kcal)\b\)?(\s|:)*(<|~)?(\s)*(exempt)/i) {
					$unit = $1;
					$value = 0;
					last;
				}
				elsif ($text =~ /\b$synonym(\s|:)*(<|~)?(\s)*(\d+((\.|\,)\d+)?)\s*\(?(g|kg|mg|µg|l|dl|cl|ml|kj|kcal)\b\)?/i) {
					$value = $4;
					$unit = $7;
					if ((defined $2) and ($2 ne "")) {
						$modifier = $2;
					}
					last;
				}
				elsif ($text =~ /\b$synonym(\s|:)+(<|~)?(\s)*(traces)/i) {
					$value = 0;
					$unit = "g";
					$modifier = "~";
					last;
				}
				# missing unit... assume g ?
				elsif ($text =~ /\b$synonym(\s|:)+(<|~)?(\s)*(\d+((\.|\,)\d+)?)\s*\(?(g|kg|mg|µg|l|dl|cl|ml|kj|kcal)?\)?\b/i) {
					$value = $4;
					$unit = "g";
					if ((defined $2) and ($2 ne "")) {
						$modifier = $2;
					}
					if (($nid eq "energy-kj") or ($nid eq "energy")) {
						$unit = "kJ";
					}
					elsif ($nid eq "energy-kcal") {
						$unit = "kcal";
					}
					last;
				}

			}

			if (($nid eq 'energy') and (defined $value) and (defined $unit)) {
				if (lc($unit) eq "kj") {
					$nid = "energy-kj";
				}
				elsif (lc($unit) eq "kcal") {
					$nid = "energy-kcal";
				}
			}

			if (($nid eq 'energy-kj') and (not defined $value)) {
				if ($text =~ /\b(\d+)(\s?)kJ/i) {
					$value = $1;
					$unit = "kJ";
				}
			}

			if (($nid eq 'energy-kcal') and (not defined $value)) {
				if ($text =~ /\b(\d+)(\s?)kcal/i) {
					$value = $1;
					$unit = "kcal";
				}
			}

			if (defined $value) {
				$nutrients_ref->{$nid} = [$value, $unit, $modifier];
			}
		}
	}

	return;
}



1;

