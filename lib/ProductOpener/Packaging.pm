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
		
		foreach my $tagid (keys %{$translations_to{$taxonomy}}) {
			
			# Skip entries that are just synonyms	
			next if (defined $just_synonyms{$taxonomy}{$tagid});
			
			foreach my $language (keys %{$translations_to{$taxonomy}{$tagid}}) {
				
				defined $packaging_taxonomies_regexps{$taxonomy}{$language} or $packaging_taxonomies_regexps{$taxonomy}{$language} = [];
				
				# the synonyms also contain the main translation as the first entry
				
				my $language_tagid = get_string_id_for_lang($language, $translations_to{$taxonomy}{$tagid}{$language});

				foreach my $synonym (@{$synonyms_for{$taxonomy}{$language}{$language_tagid}}) {
					
					push @{$packaging_taxonomies_regexps{$taxonomy}{$language}}, [$tagid, $synonym];
					
					if ((my $unaccented_synonym = unac_string_perl($synonym)) ne $synonym) {
						
						push @{$packaging_taxonomies_regexps{$taxonomy}{$language}}, [$tagid, $unaccented_synonym];
					}
				}				
				
				# Also add extended synonyms
				if (defined $synonyms_for_extended{$taxonomy}{$language}{$language_tagid}) {
					foreach my $synonym (keys %{$synonyms_for_extended{$taxonomy}{$language}{$language_tagid}}) {
						
						push @{$packaging_taxonomies_regexps{$taxonomy}{$language}}, [$tagid, $synonym];
						
						if ((my $unaccented_synonym = unac_string_perl($synonym)) ne $synonym) {
							
							push @{$packaging_taxonomies_regexps{$taxonomy}{$language}}, [$tagid, $unaccented_synonym];
						}
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

=cut

sub parse_packaging_from_text_phrase($$) {
	
	my $text = shift;
	my $text_language = shift;
	
	$log->debug("parse_packaging_from_text_phrase - start", { text => $text, text_language => $text_language }) if $log->is_debug();
	
	# Also try to match the canonicalized form so that we can match the extended synonyms that are only available in canonicalized form
	my $textid = get_string_id_for_lang($text_language, $text);	
	
	my $packaging_ref = {};
	
	foreach my $property ("shape", "material", "recycling") {
		
		my $tagtype = $packaging_taxonomies{$property};
		
		foreach my $language ($text_language, "xx") {
			
			if (defined $packaging_taxonomies_regexps{$tagtype}{$language}) {
				
				foreach my $regexp_ref (@{$packaging_taxonomies_regexps{$tagtype}{$language}}) {
					
					my ($tagid, $regexp) = @$regexp_ref;
										
					if ($text =~ /\b($regexp)\b/i) {
						
						my $before = $`;
						
						$log->debug("parse_packaging_from_text_phrase - regexp match", { before => $before, text => $text, language => $language, tagid => $tagid, regexp => $regexp }) if $log->is_debug();
						
						# If we already have a value for the property,
						# apply the new value only if it is a child of the existing value
						# e.g. if we already have "plastic", we can override it with "PET"
						if ((not defined $packaging_ref->{$property})
							or (is_a($tagtype, $tagid, $packaging_ref->{$property}))) {
							
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
					}
					elsif ($textid =~ /(^|-)($regexp)(-|$)/) {
						if ((not defined $packaging_ref->{$property})
							or (is_a($tagtype, $tagid, $packaging_ref->{$property}))) {
							
							$packaging_ref->{$property} = $tagid;
						}					
					}
				}
			}
		}
	}
		
	$log->debug("parse_packaging_from_text_phrase - result", { text => $text, text_language => $text_language, packaging_ref => $packaging_ref }) if $log->is_debug();
	
	return $packaging_ref;
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
					
					# If there is an existing value for the property,
					# check if it is either a child or a parent of the value extracted from the packaging text
					if ((defined $existing_packaging_ref->{$property}) and ($existing_packaging_ref->{$property} ne "en:unknown")
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

