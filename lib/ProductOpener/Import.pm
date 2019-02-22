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

package ProductOpener::Import;

use utf8;
use Modern::Perl '2012';
use Exporter    qw< import >;

use Log::Any qw($log);


BEGIN
{
	use vars       qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@EXPORT = qw();            # symbols to export by default
	@EXPORT_OK = qw(

		%fields
		@fields
		%products
	
		&assign_value
		
		&get_list_of_files
		
		&load_csv_file
		
		&load_xml_file
		
		&print_csv_file
		&print_stats
		
		&match_taxonomy_tags
		&assign_countries_for_product
		&assign_main_language_of_product
		
		&clean_fields
		&clean_weights
		&clean_fields_for_all_products
		
		$lc
		%global_params
		
		@xml_errors
		
					);	# symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Tags qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;
use Time::Local;
use Data::Dumper;

use Text::CSV;

%fields = ();
@fields = ();
%products = ();
@xml_errors = ();

my $mode = "append";


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
	
	if ((defined $product_ref->{$field}) and ($product_ref->{$field} ne "") and ($mode eq "append")
		and ($product_ref->{$field} ne $value)) {
		
		if (exists $tags_fields{$field}) {
			if ($target =~ /^!/) {
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
	}
	else {
		$product_ref->{$field} = $value;
	}
}


sub apply_global_params($) {

	my $product_ref = shift;
	
	$mode = "append";
	

	foreach my $field (sort keys %global_params) {
		
		assign_value($product_ref, $field, $global_params{$field});
	}
}

sub apply_global_params_to_all_products() {
	
	$mode = "append";
	
	foreach my $code (sort keys %products) {
		apply_global_params($products{$code});
	}
}


# some producers send us data for products in different languages sold in different markets

sub assign_main_language_of_product($$$) {

	my $product_ref = shift;
	my $lcs_ref = shift;
	my $default_lc = shift;
	
	if ((not defined $product_ref->{lc}) or (not defined $product_ref->{"product_name_" . $product_ref->{lc}})) {
	
		foreach my $possible_lc (@$lcs_ref) {
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
}

sub assign_countries_for_product($$$) {

	my $product_ref = shift;
	my $lcs_ref = shift;
	my $default_country = shift;
		
	foreach my $possible_lc (keys %$lcs_ref) {
		if (defined $product_ref->{"product_name_" . $possible_lc}) {
			assign_value($product_ref,"countries", $lcs_ref->{$possible_lc});
			$log->info("assign_countries_for_product: found lc - assigning value", { lc => $possible_lc, countries => $lcs_ref->{$possible_lc}}) if $log->is_info();			
		}
	}
	
	if (not defined $product_ref->{countries}) {
		assign_value($product_ref,"countries", $default_country);
		$log->info("assign_countries_for_product: assigning default value", { countries => $default_country}) if $log->is_info();	
	}
}



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
			elsif ($value =~ /^((e|emb)(\s|-|\.)*(\d{5})(\s|-|\.)*(\w)?)$/i) {
				assign_value($product_ref,"emb_codes", $value);
				$log->info("match_taxonomy_tags: found packaging code - assigning value", { source => $source, value => $value, target => "emb_codes"}) if $log->is_info();		
			}
		}
	}
}


sub split_allergens($) {
	my $allergens = shift;
	
	# simple allergen (not an enumeration) -> return _$allergens_
	if (($allergens !~ /,/)
		and (not ($allergens =~ / et /i))) {
		return "_" . $allergens . "_";
	}
	else {
		return $allergens;
	}
}



sub clean_weights($) {

	my $product_ref = shift;
	
	# normalize weights
	
	foreach my $field ("quantity", "serving_size", "net_weight", "drained_weight", "total_weight", "volume") {
	
		# normalize unit
		if (defined $product_ref->{$field . "_unit"}) {
			$product_ref->{$field . "_unit"} =~ s/gr/g/i;
			if ($product_ref->{$field . "_unit"} !~ /^(kJ|L)$/) {
				$product_ref->{$field . "_unit"} = lc($product_ref->{$field . "_unit"});
			}
		}
	
		# combine value and unit
		if ((not defined $product_ref->{$field})
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
			$product_ref->{$field} =~ s/(\d|[\)])( )?(g|gramme|grammes|gr)(\.)?/$1 g/i;
			$product_ref->{$field} =~ s/(\d)( )?(ml|millilitres)(\.)?/$1 ml/i;
			$product_ref->{$field} =~ s/(litre|litres|liter|liters|lt)\b/l/i;
			$product_ref->{$field} =~ s/kilogramme|kilogrammes|kgs/kg/i;			
			$product_ref->{$field} =~ s/(\d)(\s)*(kg|g|gr|mg|µg|oz|l|dl|cl|ml|(fl(\.?)(\s)?oz))e?\b/lc("$1 $3")/ieg;
			# 250 GR -> 250 g
			$product_ref->{$field} =~ s/(\d) gr\b/$1 g/g;
			
			$product_ref->{$field} =~ s/\.0 / /;			
						
			# 6x90g
			$product_ref->{$field} =~ s/(\d)(\s*)x(\s*)(\d)/$1 x $4/i;

			# kge 
			$product_ref->{$field} =~ s/(\d\s(\w+))e$/$1 e/;

			# remove the e
			$product_ref->{$field} =~ s/ e\b//g;
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
	
	
	# empty or uncomplete quantity, but net_weight etc. present
	if ((not defined $product_ref->{quantity}) or ($product_ref->{quantity} eq "") 
		or (($lc eq "fr") and ($product_ref->{quantity} =~ /^\d+ tranche([[:alpha:]]*)$/)) # French : "6 tranches épaisses"
		) {
		
		# See if we have other quantity related values: net_weight_value	net_weight_unit	drained_weight_value	drained_weight_unit	volume_value	volume_unit

		my $extra_quantity;
		
		foreach my $field ("net_weight", "drained_weight", "total_weight", "volume") {
			if ((defined $product_ref->{$field}) and ($product_ref->{$field} ne "")
				and ($product_ref->{$field} =~ /^\d/) ) {	# make sure we have a number
				$extra_quantity = $product_ref->{$field};
				last;
			}		
		}
		
		if (defined $extra_quantity) {
			if ((defined $product_ref->{quantity}) and ($product_ref->{quantity} ne "")) {
				$product_ref->{quantity} .= " ($extra_quantity)";
			}
			else {
				assign_value($product_ref, 'quantity', $extra_quantity);
			}
		}
	}
}



sub clean_fields($) {

	my $product_ref = shift;
	
	foreach my $field (@fields) {
	
		if (defined $product_ref->{$field}) {
		
			$product_ref->{$field} =~ s/(\&nbsp)|(\xA0)/ /g;
			$product_ref->{$field} =~ s/’/'/g;
			
			# Remove extra line feeds
			$product_ref->{$field} =~ s/<br( )?(\/)?>/\n/ig;
			$product_ref->{$field} =~ s/\r\n/\n/g;
			$product_ref->{$field} =~ s/\n\./\n/g;			
			$product_ref->{$field} =~ s/\n\n(\n+)/\n\n/g;
			$product_ref->{$field} =~ s/^\.$//;
			$product_ref->{$field} =~ s/^(\.|\s)+//;
			$product_ref->{$field} =~ s/\s*$//;
			$product_ref->{$field} =~ s/^\s*//;
			$product_ref->{$field} =~ s/(\s|-|_|;|,)*$//;
		
		
			if ($product_ref->{$field} =~ /^(\s|-|\.|_)$/) {
				$product_ref->{$field} = "";
			}
			
			# tag fields: turn separators to commas
			# Sans conservateur / Sans huile de palme
			# ! packaging codes can have / :  ES 12.06648/C CE
			if (exists $tags_fields{$field}) {
				$product_ref->{$field} =~ s/\s?(;|( \/ )|\n)+\s?/, /g;
			}
			
			
			# Lowercase fields in ALL CAPS
			if ($field =~ /^(ingredients_text|product_name|generic_name)/) {
				if (($product_ref->{$field} =~ /[A-Z]{4}/)
					# and ($product_ref->{$field} !~ /[a-z]/)
					) {
					$product_ref->{$field} = ucfirst(lc($product_ref->{$field}));
				}
			}
			
			
			# Ingredients
			
			if ($field =~ /^ingredients_text/) {
			
				# Traces de<b> fruits à coque </b>

				$product_ref->{$field} =~ s/<strong>/<b>/g;
				$product_ref->{$field} =~ s/<\/strong>/<\/b>/g;
			
				$product_ref->{$field} =~ s/(<b><u>|<u><b>)/<b>/g;
				$product_ref->{$field} =~ s/(<\b><\u>|<\u><\b>)/<\b>/g;
				$product_ref->{$field} =~ s/<u>/<b>/g;
				$product_ref->{$field} =~ s/<\/u>/<\/b>/g;
				$product_ref->{$field} =~ s/<em>/<b>/g;
				$product_ref->{$field} =~ s/<\/em>/<\/b>/g;				
				$product_ref->{$field} =~ s/<b>\s+/ <b>/g;
				$product_ref->{$field} =~ s/\s+<\/b>/<\/b> /g;

				# empty tags
				$product_ref->{$field} =~ s/<b>\s+<\/b>/ /g;
				$product_ref->{$field} =~ s/<b><\/b>//g;
				# _fromage_ _de chèvre_
				$product_ref->{$field} =~ s/<\/b>(| )<b>/$1/g;
				
				# d_'œufs_
				# _lait)_
				$product_ref->{$field} =~ s/<b>'(\w)/$1'<b>/g;
				$product_ref->{$field} =~ s/(\w)<\/b>/<b>$1/g;
				

				# $log->debug("clean_fields - ingredients_text - 1", { field=>$field, value=>$product_ref->{$field} }) if $log->is_debug();

				
				# extrait de malt d'<b>orge - </b>sel 
				$product_ref->{$field} =~ s/ -( |)<\/b>/<\/b> -$1/g;
				
				$product_ref->{$field} =~ s/<b>(.*?)<\/b>/split_allergens($1)/iesg;
				$product_ref->{$field} =~ s/<b>|<\/b>//g;

				
				if ($field eq "ingredients_text_fr") {
				
					# $log->debug("clean_fields - ingredients_text - 2", { field=>$field, value=>$product_ref->{$field} }) if $log->is_debug();

					# remove single sentence that say allergens are in bold (in Casino data)
					$product_ref->{$field} =~ s/(Les |l')?(information|ingrédient|indication)(s?) ([^\.,]*) (personnes )?((allergiques( (ou|et) intolérant(e|)s)?)|(intolérant(e|)s( (ou|et) allergiques)?))(\.)?//i;
					$product_ref->{$field} = ucfirst($product_ref->{$field});
					
					# $log->debug("clean_fields - ingredients_text - 3", { field=>$field, value=>$product_ref->{$field} }) if $log->is_debug();

					# Missing spaces
					# Poire Williams - sucre de canne - sucre - gélifiant : pectines de fruits - acidifiant : acide citrique.Préparée avec 55 g de fruits pour 100 g de produit fini.Teneur totale en sucres 56 g pour 100 g de produit fini.Traces de _fruits à coque_ et de _lait_..
					$product_ref->{$field} =~ s/\.([A-Z][a-z])/\. $1/g;
					
					# $log->debug("clean_fields - ingredients_text - 4", { field=>$field, value=>$product_ref->{$field} }) if $log->is_debug();
					
				}
				
				# persil- poivre blanc -ail
				$product_ref->{$field} =~ s/(\w|\*)- /$1 - /g;
				$product_ref->{$field} =~ s/ -(\w)/ - $1/g;
			
				#_oeuf 8_%
				$product_ref->{$field} =~ s/_([^_,-;]+) (\d*\.?\d+\s?\%?)_/_$1_ $2/g;
				
				# _d'arachide_
				# morceaux _d’amandes_ grillées
				if (($field =~ /_fr/) or (($lc eq 'fr') and ($field !~ /_\w\w$/))) {
					$product_ref->{$field} =~ s/_(d|l)('|’)([^_,-;]+)_/$1'_$2_/ig;
				}
			}			
			
			if ($field =~ /^nutrition_grade_/) {
				$product_ref->{$field} = lc($product_ref->{$field});
			}
			
			# remove N/A, NA etc.
			$product_ref->{$field} =~ s/(^|,)\s*((n(\/|\.)?a(\.)?)|(not applicable)|non)\s*(,|$)//ig;
			
			if (($field =~ /_fr/) or ((defined $product_ref->{lc}) and ($product_ref->{lc} eq 'fr') and ($field !~ /_\w\w$/))) {
				$product_ref->{$field} =~ s/^\s*(aucun(e)|autre logo|non)?\s*$//ig;
			}
			
			$product_ref->{$field} =~ s/,(\s*),/,/g;
			$product_ref->{$field} =~ s/\.(\.+)$/\./;
			$product_ref->{$field} =~ s/(\s|-|;|,)*$//;
			$product_ref->{$field} =~ s/^(\s|-|;|,)+//;
			$product_ref->{$field} =~ s/^(\s|-|;|,|_)+$//;			
			
			# remove empty values for tag fields
			if (exists $tags_fields{$field}) {
				$product_ref->{$field} =~ s/^(,|;|-|_|\/|\\|#|:|\s)+$//;
			}
		
		}
	}
	
	clean_weights($product_ref);
}


sub clean_fields_for_all_products() {

	foreach my $code (sort keys %products) {
		clean_fields($products{$code});
	}
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
	
	my $product_ref;
	
	
	if (defined $code) {
		$product_ref = get_or_create_product_for_code($code);
	}
	
	$log->info("parsing xml file with XML::Rules", { file => $file, xml_rules => $xml_rules_ref }) if $log->is_info();

	my $parser = XML::Rules->new(rules => $xml_rules_ref);
	
	my $xml_ref;

	eval { $xml_ref = $parser->parse_file( $file);	};
	
	if ($@ ne "") {
		$log->error("error parsing xml file with XML::Rules", { file => $file, error=>$@ }) if $log->is_error();
		push @xml_errors, $file;
		#exit;
	}
	
	$log->trace("XML::Rules output", { file => $file, xml_ref => $xml_ref }) if $log->is_trace();
	
	$log->info("Mapping XML fields", { file => $file }) if $log->is_info();
	
#		my @xml_fields_mapping = (
#
#			# get the code first
#			
#			["fields.AL_CODE_EAN.FR", "code"],
#			["ProductCode", "producer_version_id"],			
#			["fields.AL_INGREDIENT.*", "ingredients_text_*"],

	# $code = undef;

	foreach my $field_mapping_ref (@$xml_fields_mapping_ref) {
		my $source = $field_mapping_ref->[0];
		my $target = $field_mapping_ref->[1];
		
		$log->trace("source", { source=>$source, target=>$target }) if $log->is_trace();
		
		my $current_tag = $xml_ref;
		
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
					$tag_target =~ s/\*/$tag/;
					$tag_target = lc($tag_target);
					print STDERR "* tag key: $tag - target: $tag_target\n";
					if ((defined $current_tag->{$tag}) and (not ref($current_tag->{$tag})) and ($current_tag->{$tag} ne '')) {
						print STDERR "$tag value is a scalar: $current_tag->{$tag}, assign value to $tag_target\n";
						if ($tag_target eq 'code') {
							$code = $current_tag->{$tag};

							$product_ref = get_or_create_product_for_code($code);
						}						
						assign_value($product_ref, $tag_target, $current_tag->{$tag});
						
						if ($tag_target eq 'emb_codes') {
							print STDERR "emb_codes : " . $product_ref->{$tag_target} . "\n";
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
						
						if ($target =~ /^(.*)_([^_]+)$/) {
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
	}
	
	return 0;
}


sub load_csv_file($) {

	my $options_ref = shift;
	
	my $file = $options_ref->{file};
	my $encoding = $options_ref->{encoding};
	my $separator = $options_ref->{separator};
	my $skip_lines = $options_ref->{skip_lines};
	my $skip_non_existing_products = $options_ref->{skip_non_existing_products};
	my $skip_empty_codes = $options_ref->{skip_empty_codes};
	my @csv_fields_mapping = @{$options_ref->{csv_fields_mapping}};
		
	# e.g. load_csv_file($file, "UTF-8", "\t", 4);
	
	$log->info("Loading CSV file", { file => $file }) if $log->is_info();
	
	my $csv = Text::CSV->new ( { binary => 1 , sep_char => $separator } )  # should set binary attribute.
                 or die "Cannot use CSV: ".Text::CSV->error_diag ();

	open (my $io, "<:encoding($encoding)", $file) or die("Could not open $file: $!");
	
	my $i = 0;	# line number	
	
	if (defined $skip_lines) {
		for ($i = 0; $i < $skip_lines; $i++) {
			$csv->getline ($io);
		}
	}

	my $headers_ref = $csv->getline ($io);
	$i++;
	
	$log->info("CSV headers", { file => $file, headers_ref=>$headers_ref }) if $log->is_info();
	
	$csv->column_names($headers_ref);
	
	my $product_ref;

	while (my $csv_product_ref = $csv->getline_hr ($io)) {
	
		$i++; # line number
	
		my $code = undef;	# code must be first
		
		my $seen_energy_kj = 0;

		foreach my $field_mapping_ref (@csv_fields_mapping) {
		
			my $source_field = $field_mapping_ref->[0];
			my $target_field = $field_mapping_ref->[1];
						
			$log->info("Field mapping", { source_field => $source_field, source_field_value => $csv_product_ref->{$source_field}, target_field=>$target_field }) if $log->is_info();
		
			if (defined $csv_product_ref->{$source_field}) {
				# print STDERR "defined source field $source_field: " . $csv_product_ref->{$source_field} . "\n";
				
				my $value = $csv_product_ref->{$source_field};
				
				if ($target_field eq 'code') {
					$code = $value;
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
				else {
					assign_value($product_ref, $target_field, $value);									
				}

			}
			else {
				$log->error("undefined source field", { line => $i, source_field=>$source_field, csv_product_ref=>$csv_product_ref }) if $log->is_error();
				die;				
			}
		}
	
	}
}





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
		push @$list_ref, $arg;
	}
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
	
	foreach my $code (sort {$products{$a} <=> $products{$b}} keys %products) {
	
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
	
	}

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
}





1;

