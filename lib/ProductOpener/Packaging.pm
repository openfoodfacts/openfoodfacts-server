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

=head1 NAME

ProductOpener::Packaging 

=head1 SYNOPSIS


=head1 DESCRIPTION


=cut

package ProductOpener::Packaging;

use utf8;
use Modern::Perl '2017';
use Exporter    qw< import >;

use Log::Any qw($log);

BEGIN
{
	use vars       qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(

		&extract_packaging_from_image
		&init_packaging_taxonomies_regexps
		&analyze_and_combine_packaging_data
		&parse_packaging_from_text_phrase
		&guess_language_of_packaging_text

		);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;

use ProductOpener::Config qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Store qw/:all/;


=head1 FUNCTIONS

=head2 extract_packagings_from_image( $product_ref $id $ocr_engine $results_ref )

Extract packaging data from packaging info / recycling instructions photo.

=cut

sub extract_packaging_from_image($$$$) {

	my $product_ref = shift;
	my $id = shift;
	my $ocr_engine = shift;
	my $results_ref = shift;

	my $lc = $product_ref->{lc};

	if ($id =~ /_(\w\w)$/) {
		$lc = $1;
	}

	extract_text_from_image($product_ref, $id, "packaging_text_from_image", $ocr_engine, $results_ref);

	# TODO: extract structured data from the text
	if (($results_ref->{status} == 0) and (defined $results_ref->{packaging_text_from_image})) {

		$results_ref->{packaging_text_from_image_orig} = $product_ref->{packaging_text_from_image};
	}

	return;
}

=head2 init_packaging_taxonomies_regexps()

This function creates regular expressions that match all variations of
packaging shapes, materials etc. that we want to recognize in packaging text.

=cut

my %packaging_taxonomies = (
	"shape" => "packaging_shapes",
	"material" => "packaging_materials",
	"recycling" => "packaging_recycling"
);

my %packaging_taxonomies_regexps = ();

sub init_packaging_taxonomies_regexps() {
	
	foreach my $taxonomy (values %packaging_taxonomies) {
		
		$packaging_taxonomies_regexps{$taxonomy} = {};	# keys: languages
		
		foreach my $tagid (get_all_taxonomy_entries($taxonomy)) {
			
			foreach my $language (keys %{$translations_to{$taxonomy}{$tagid}}) {
				
				defined $packaging_taxonomies_regexps{$taxonomy}{$language} or $packaging_taxonomies_regexps{$taxonomy}{$language} = [];

				foreach my $synonym (get_taxonomy_tag_synonyms($language, $taxonomy, $tagid)) {
					
					push @{$packaging_taxonomies_regexps{$taxonomy}{$language}}, [$tagid, $synonym];
					
					if ((my $unaccented_synonym = unac_string_perl($synonym)) ne $synonym) {
						
						push @{$packaging_taxonomies_regexps{$taxonomy}{$language}}, [$tagid, $unaccented_synonym];
					}
				}
			}
		}
		
		# We want to match the longest strings first
		
		foreach my $language (keys %{$packaging_taxonomies_regexps{$taxonomy}}) {
			@{$packaging_taxonomies_regexps{$taxonomy}{$language}}
				= sort { length($b->[1]) <=> length($a->[1]) } @{$packaging_taxonomies_regexps{$taxonomy}{$language}};
		}
		
		$log->debug("init_packaging_taxonomies_regexps - result", { taxonomy => $taxonomy, packaging_taxonomies_regexps => $packaging_taxonomies_regexps{$taxonomy}  }) if $log->is_debug();
	}
	
	# used only for debugging
	#store("packaging_taxonomies_regexps.sto", \%packaging_taxonomies_regexps);
}


=head2 parse_packaging_from_text_phrase($text, $text_language)

This function parses a single phrase (e.g. "5 25cl transparent PET bottles")
and returns a packaging object with properties like units, quantity, material, shape etc.

=head3 Parameters

=head4 $text text

If the text is prefixed by a 2-letter language code followed by : (e.g. fr:),
the language overrides the $text_language parameter (often set to the product language).

This is useful in particular for packaging tags fields added by Robotoff that are prefixed with the language.

It will also be useful when we taxonomize the packaging tags (not taxonomized as of 2022/03/04):
existing packaging tags will be prefixed by the product language.

=head4 $text_language default text language

Can be overriden if the text is prefixed with a language code (e.g. fr:boite en carton)

=head3 Return value

Packaging object (hash) reference with optional properties: recycling, material, shape

=cut

sub parse_packaging_from_text_phrase($$) {
	
	my $text = shift;
	my $text_language = shift;
	
	$log->debug("parse_packaging_from_text_phrase - start", { text => $text, text_language => $text_language }) if $log->is_debug();

	if ($text =~ /^([a-z]{2}):/) {
		$text_language = $1;
		$text = $';
	}
	
	# Also try to match the canonicalized form so that we can match the extended synonyms that are only available in canonicalized form
	my $textid = get_string_id_for_lang($text_language, $text);	
	
	my $packaging_ref = {};
	
	# Match recycling instructions first, as some of them can contain the name of materials
	# e.g. "recycle in paper bin", which should not imply that the material is paper (it could be cardboard)
	foreach my $property ("recycling", "material", "shape") {
		
		my $tagtype = $packaging_taxonomies{$property};
		
		foreach my $language ($text_language, "xx") {
			
			if (defined $packaging_taxonomies_regexps{$tagtype}{$language}) {
				
				foreach my $regexp_ref (@{$packaging_taxonomies_regexps{$tagtype}{$language}}) {
					
					my ($tagid, $regexp) = @$regexp_ref;

					my $matched = 0;
										
					if ($text =~ /\b($regexp)\b/i) {
						
						my $before = $`;
						$matched = 1;
						
						$log->debug("parse_packaging_from_text_phrase - regexp match", { before => $before, text => $text, language => $language, tagid => $tagid, regexp => $regexp }) if $log->is_debug();
						
						# If we already have a value for the property,
						# apply the new value only if it is a child of the existing value
						# e.g. if we already have "plastic", we can override it with "PET"
						# Special case for "cardboard" that can be both a shape (card) and a material (cardboard):
						# -> a new shape can be assigned. e.g. "carboard box" -> shape = box
						if ((not defined $packaging_ref->{$property})
							or (is_a($tagtype, $tagid, $packaging_ref->{$property}))
							or (($property eq "shape") and ($packaging_ref->{$property} eq "en:card"))
							) {
							
							$packaging_ref->{$property} = $tagid;
						}
						
						# If we have a shape, check if we have a quantity contained (volume or weight)
						# or if there is a number of units at the beginning
						
						if ($property eq "shape") {
							
							# Quantity contained: 25cl plastic bottle, plastic bottle (25cl)
							if ($text =~ /\b((\d+((\.|,)\d+)?)\s?(l|dl|cl|ml|g|kg))\b/i) {
								$packaging_ref->{quantity} = lc($1);
								$packaging_ref->{quantity_value} = lc($2);
								$packaging_ref->{quantity_unit} = lc($5);
								
								# Remove the quantity from $before so that we don't mistake it for a number of units
								$before =~ s/$1//g;
							}
							
							# Number of units: e.g. 4 plastic bottles (but we should not match the 2 in "2 PEHD plastic bottles")
							# match numbers starting with 1 to 9 to avoid matching 02 PEHD
							if ($before =~ /^([1-9]\d*) /) {
								if (not defined $packaging_ref->{number}) {
									$packaging_ref->{number} = $1;
								}
							}
						}

						# If we have a recycling instruction, check if we can infer the material from it
						# e.g. "recycle in glass bin" --> add the "en:glass" material

						if ($property eq "recycling") {
							my $material = get_inherited_property("packaging_recycling", $tagid, "packaging_materials:en");
							if ((defined $material) and (not defined $packaging_ref->{"material"})) {
								$packaging_ref->{"material"} = $material;
							}
						}
					}
					elsif ($textid =~ /(^|-)($regexp)(-|$)/) {

						$matched = 1;

						if ((not defined $packaging_ref->{$property})
							or (is_a($tagtype, $tagid, $packaging_ref->{$property}))) {
							
							$packaging_ref->{$property} = $tagid;

							# Try to remove the matched text
							# The challenge is that $regexp matches the normalized $textid
							# and we want to remove the corresponding unnormalized part in $text
							$regexp =~ s/-/\\W/g;
						}		
					}

					if ($matched) {
						# Remove the string that we have matched, so that when we match the "in the paper bin" recycling instruction,
						# we don't also match the "paper" material (it could be cardboard)
						# Exceptions:
						# - Do not remove "cardboard" as we do want to possibly match it as both a material and a shape
						# - Do not remove materials that begin with a number (e.g. "1 PET" in order to not remove the 1 in "1 PET bottle" which is more likely to be a number)
						if (($tagid ne "en:cardboard")
							and not (($regexp =~ /^\d/) and ($regexp =~ /^\d/)) ) {
							$text =~ s/\b($regexp)\b/ MATCHED /i;
							$textid = get_string_id_for_lang($text_language, $text);
							$log->debug("parse_packaging_from_text_phrase - removed match", { text => $text, textid => $textid, tagid => $tagid, regexp => $regexp }) if $log->is_debug();
						}
					}	
				}
			}
		}
	}
		
	$log->debug("parse_packaging_from_text_phrase - result", { text => $text, text_language => $text_language, packaging_ref => $packaging_ref }) if $log->is_debug();
	
	return $packaging_ref;
}


=head2 guess_language_of_packaging_text($text, \@potential_lcs)

Given a text like "couvercle en métal", this function tries to guess the language of the text based
on how well it matches the packaging taxonomies.

One use is to convert packaging tags for which we don't have a language to a version prefixed by the language.

Candidate languages are provided in an ordered list, and the function returns the one that matches more
properties (material, shape, recycling). In case of a draw, the priority is given according to the order of the list.

=head3 Parameters

=head4 $text text

=head4 \@potential_lcs reference to an ordered list of language codes

=head3 Return value

- undef if no match was found
- or language code of the better matching language

=cut

sub guess_language_of_packaging_text($$) {
	
	my $text = shift;
	my $potential_lcs_ref = shift;
	
	$log->debug("guess_language_of_packaging_text - start", { text => $text, potential_lcs_ref => $potential_lcs_ref }) if $log->is_debug();

	my $max_lc;
	my $max_properties = 0;

	foreach my $l (@$potential_lcs_ref) {
		my $packaging_ref = parse_packaging_from_text_phrase($text, $l);
		my $properties = scalar keys %$packaging_ref;

		# if no property was recognized and we still have no candidate,
		# try to see if the entry exists in the packaging taxonomy
		# (which includes preservation which will not be parsed by parse_packaging_from_text_phrase)

		if (($max_properties == 0) and ($properties == 0)) {
			my $tagid = canonicalize_taxonomy_tag($l, "packaging", $text);
			if (exists_taxonomy_tag("packaging", $tagid)) {
				$properties = 1;
			}
		}

		if ($properties > $max_properties) {
			$max_lc = $l;
			$max_properties = $properties;
			# If we have all properties, bail out
			if ($properties == 3) {
				last;
			}
		}
	}
	
	return $max_lc;
}	


=head2 analyze_and_combine_packaging_data($product_ref)

This function analyzes all the packaging information available for the product:

- the existing packagings data structure
- the packaging_text entered by users or retrieved from the OCR of recycling instructions
(e.g. "glass bottle to recycle, metal cap to discard")
- labels (e.g. FSC)
- the non-taxonomized packaging tags field

And combines them in an updated packagings data structure.

=cut

sub analyze_and_combine_packaging_data($) {
	
	my $product_ref = shift;
	
	$log->debug("analyze_and_combine_packaging_data - start", { existing_packagings => $product_ref->{packagings} }) if $log->is_debug();
	
	# Create the packagings data structure if it does not exist yet
	# otherwise, we will use and augment the existing data
	if (not defined $product_ref->{packagings}) {
		$product_ref->{packagings} = [];
	}
	
	# Parse the packaging_text and the packaging tags field
	
	my @phrases = ();
	
	my $number_of_packaging_text_entries = 0;
	
	# Packaging text field (populated by OCR of the packaging image and/or contributors or producers)
	if (defined $product_ref->{packaging_text}) {
		
		my @packaging_text_entries = split(/,|\n/, $product_ref->{packaging_text});
		push (@phrases, @packaging_text_entries);
		$number_of_packaging_text_entries = scalar @packaging_text_entries;
	}
	
	# Packaging tags field
	if (defined $product_ref->{packaging}) {
		
		# We sort the tags by length to have a greater chance of seeing more specific fields first
		# e.g. "plastic bottle", "plastic", "metal", "lid",
		# otherwise if we have "plastic", "lid", "metal", "plastic bottle"
		# it would result in "plastic" being combined with "lid", then "metal", then "plastic bottle".
		
		push (@phrases, sort ({ length($b) <=> length($a) } split(/,|\n/, $product_ref->{packaging})));
	}	
	
	# Add or merge packaging data from phrases to the existing packagings data structure
		
	my $i = 0;	
		
	foreach my $phrase (@phrases) {
		
		$i++;
		$phrase =~ s/^\s+//;
		$phrase =~ s/\s+$//;
		next if $phrase eq "";
		
		my $packaging_ref = parse_packaging_from_text_phrase($phrase, $product_ref->{lc});
		
		# If the shape is "capsule" and the product is in category "en:coffees", mark the shape as a "coffee capsule"
		if ((defined $packaging_ref->{"shape"}) and ($packaging_ref->{"shape"} eq "en:capsule")
			and (has_tag($product_ref, "categories", "en:coffees"))) {
			$packaging_ref->{"shape"} = "en:coffee-capsule";
		}

		# If we have a shape without a material, check if there is a default material for the shape
		# e.g. "en:Bubble wrap" has the property packaging_materials:en: en:plastic
		if ((defined $packaging_ref->{"shape"}) and (not defined $packaging_ref->{"material"})) {
			my $material = get_inherited_property("packaging_shapes", $packaging_ref->{"shape"}, "packaging_materials:en");
			if (defined $material) {
				$packaging_ref->{"material"} = $material;
			}
		}

		# If we have a material without a shape, check if there is a default shape for the material
		# e.g. "en:tetra-pak" has the shape "en:brick"
		if ((defined $packaging_ref->{"material"}) and (not defined $packaging_ref->{"shape"})) {
			my $shape = get_inherited_property("packaging_materials", $packaging_ref->{"material"}, "packaging_shapes:en");
			if (defined $shape) {
				$packaging_ref->{"shape"} = $shape;
			}
		}
		
		# For phrases corresponding to the packaging text field, mark the shape as en:unknown if it was not identified
		if (($i <= $number_of_packaging_text_entries) and (not defined $packaging_ref->{shape})) {
			$packaging_ref->{shape} = "en:unknown";
		}
		
		# Non empty packaging?
		if ((scalar keys %$packaging_ref) > 0) {
			
			# If we have an existing packaging that can correspond, augment it
			# otherwise, add one
			
			my $matching_packaging_ref;
			
			foreach my $existing_packaging_ref (@{$product_ref->{packagings}}) {
				
				my $match = 1;
				
				foreach my $property (sort keys %$packaging_ref) {
					
					my $tagtype = $packaging_taxonomies{$property};

					# $tagtype can be shape / material / recycling, or undef if the property is something else (e.g. a number of packagings)
					if (not defined $tagtype) {
						$match = 0;
						last;
					}
					
					# If there is an existing value for the property,
					# check if it is either a child or a parent of the value extracted from the packaging text
					elsif ((defined $existing_packaging_ref->{$property}) and ($existing_packaging_ref->{$property} ne "en:unknown")
						and ($existing_packaging_ref->{$property} ne $packaging_ref->{$property})
						and (not is_a($tagtype, $existing_packaging_ref->{$property}, $packaging_ref->{$property}))
						and (not is_a($tagtype, $packaging_ref->{$property}, $existing_packaging_ref->{$property})) ) {
						
						$match = 0;
						last;
					}
				}
				
				if ($match) {
					$matching_packaging_ref = $existing_packaging_ref;
					last;
				}
			}
			
			if (not defined $matching_packaging_ref) {
				# Add a new packaging
				$log->debug("analyze_and_combine_packaging_data - add new packaging", { packaging_ref => $packaging_ref }) if $log->is_debug();
				push @{$product_ref->{packagings}}, $packaging_ref;
			}
			else {
				# Merge data with matching packaging
				$log->debug("analyze_and_combine_packaging_data - merge with existing packaging", { packaging_ref => $packaging_ref, matching_packaging_ref => $matching_packaging_ref }) if $log->is_debug();
				foreach my $property (sort keys %$packaging_ref) {
					
					my $tagtype = $packaging_taxonomies{$property};
					
					# If we already have a value for the property,
					# apply the new value only if it is a child of the existing value
					# e.g. if we already have "plastic", we can override it with "PET"
					if ((not defined $matching_packaging_ref->{$property}) or ($matching_packaging_ref->{$property} eq "en:unknown")
						or (is_a($tagtype, $packaging_ref->{$property}, $matching_packaging_ref->{$property}))) {
						
						$matching_packaging_ref->{$property} = $packaging_ref->{$property};
					}
				}
			}
		}
	}
	
	$log->debug("analyze_and_combine_packaging_data - done", { packagings => $product_ref->{packagings} }) if $log->is_debug();
}

1;

