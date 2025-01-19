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

ProductOpener::TaxonomiesEnhancer - analyze ingredients and other fields to enrich the taxonomies

=head1 SYNOPSIS

C<ProductOpener::TaxonomiesEnhancer> analyze
analyze ingredients and other fields to enrich the taxonomies

    use ProductOpener::TaxonomiesEnhancer qw/:all/;

	[..]

	check_ingredients_between_languages($product_ref);

=head1 DESCRIPTION

[..]

=cut

package ProductOpener::TaxonomiesEnhancer;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&check_ingredients_between_languages
	);
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}
use vars @EXPORT_OK;

use List::Util qw(any);
use Log::Log4perl qw(get_logger);
use Text::Levenshtein qw(distance);

use ProductOpener::Ingredients qw/parse_ingredients_text_service/;
use ProductOpener::Tags qw/add_tag get_taxonomy_tag_synonyms is_a/;

# Configure Log4perl
Log::Log4perl->init(\<<'EOL');
# log4perl.logger                   = DEBUG, Screen
log4perl.logger                   = INFO, Screen
log4perl.appender.Screen          = Log::Log4perl::Appender::Screen
log4perl.appender.Screen.stderr   = 1
log4perl.appender.Screen.layout   = Log::Log4perl::Layout::PatternLayout
log4perl.appender.Screen.layout.ConversionPattern = %d %p %m %n
EOL

my $log = get_logger();

=head2 flatten_ingredients ( ingredients )

This function recursively flattens a nested list of ingredients. 
If an ingredient contains sub-ingredients, they are flattened into a single-level array.

=head3 Arguments

=head4 ingredients

An array reference of ingredients that may contain nested sub-ingredients.

=head3 Return value

An array of flattened ingredients, each represented as a hash reference.

=cut

sub flatten_ingredients {
	my ($ingredients) = @_;
	my @flat_list;

	foreach my $ingredient (@{$ingredients}) {
		$ingredient->{id} =~ s/_//g;
		$ingredient->{text} =~ s/_//g;

		push @flat_list,
			{
			id => $ingredient->{id},
			is_in_taxonomy => $ingredient->{is_in_taxonomy},
			text => $ingredient->{text},
			};

		# If the ingredient contains sub-ingredients, flatten them
		if (exists $ingredient->{ingredients}) {
			push @flat_list, flatten_ingredients($ingredient->{ingredients});
		}
	}

	return @flat_list;
}

=head2 parse_ingredients_for_language ( ingredients_hash, key )

This function parses and flattens the ingredient list for a specific language based on the provided key.

=head3 Arguments

=head4 ingredients_hash

A hash reference to the product data containing the ingredient text for various languages.

=head4 key

A string representing the language-specific ingredient text key (e.g., "ingredients_text_cs").

=head3 Return value

This function does not return a value but modifies the product reference to store the flattened ingredient list under a new key (e.g., "ingredients_cs").

=cut

sub parse_ingredients_for_language {
	my ($ingredients_hash, $key) = @_;

	# Extract language code from key (for example, 'ingredients_text_cs' -> 'cs')
	my $lang = ($key =~ s/^ingredients_text_//r);

	# Apply parse on given lang
	$ingredients_hash->{"ingredients_lc"} = $lang;
	$ingredients_hash->{"ingredients_text"} = lc($ingredients_hash->{"ingredients_text_" . $lang});

	parse_ingredients_text_service($ingredients_hash, {}, []);

	# For simplicity, flatten the parsed ingredient list (from sub list to single level list)
	my @flat_ingredients = flatten_ingredients($ingredients_hash->{"ingredients"});

	$ingredients_hash->{$lang} = \@flat_ingredients;

	# Deleting unnecessary keys created by the parse_ingredients_text_service, ensure they exist before deletion
	delete $ingredients_hash->{"ingredients"} if exists $ingredients_hash->{"ingredients"};
	delete $ingredients_hash->{"ingredients_lc"} if exists $ingredients_hash->{"ingredients_lc"};
	delete $ingredients_hash->{"ingredients_text"} if exists $ingredients_hash->{"ingredients_text"};
	delete $ingredients_hash->{"ingredients_text_" . $lang} if exists $ingredients_hash->{"ingredients_text_" . $lang};

	return;
}

=head2 not_enough_known_ingredients ( ingredients1, ingredients2 )

This function checks if all or a certain percentage of ingredients in the first language (reference) overlap with ingredients in second language (to analyze).

=head3 Arguments

=head4 ingredients1

An array reference of ingredients in the first language (reference).

=head4 ingredients2

An array reference of ingredients in the second language (to analyze).

=head3 Return value

Returns 1 if the overlap of ingredients between the two lists is below a certain threshold, otherwise returns 0.

=cut

sub not_enough_known_ingredients {
	my ($ingredients1, $ingredients2) = @_;

	if (@$ingredients1 == 0 || @$ingredients2 == 0) {
		$log->debug(
			"check_ingredients_between_languages > not_enough_known_ingredients -   one of the ingredients list is empty"
		) if $log->is_debug();
		return 1;
	}

	# Product with 1 ingredient would be under the threshold defined below
	if (@$ingredients1 > 1) {
		my $min_known_percentage = 0.5;
		my $known_count = 0;
		for my $i (0 .. $#$ingredients1) {
			if (any {$_->{id} eq $ingredients1->[$i]{id}} @$ingredients2) {
				$known_count++;
			}
		}
		# Length of ingredients1 cannot be zero, see above
		my $known_percentage = $known_count / @$ingredients1;
		if ($known_percentage < $min_known_percentage) {
			$log->debug(
				"check_ingredients_between_languages > not_enough_known_ingredients -   too much unknown ingredient between ingredients1 and ingredients2"
			) if $log->is_debug();
			return 1;
		}
	}

	return 0;

}

=head2 detect_missing_stop_words_before_list ( ingredients1, ingredients2, lang1, lang2, missing_stop_words_before )

This function detects missing stop words before the first known ingredient in a list of ingredients.

=head3 Arguments

=head4 ingredients1

An array reference of ingredients in the first language (reference).

=head4 ingredients2

An array reference of ingredients in the second language (to analyze).

=head4 lang1

A string representing the language code for the first language.

=head4 lang2

A string representing the language code for the second language.

=head4 missing_stop_words_before

A hash reference to store the missing stop words before the first known ingredient.

=head3 Return value

This function does not return a value but modifies the `missing_stop_words_before` hash reference to store the missing stop words.

=cut

sub detect_missing_stop_words_before_list {
	my ($ingredients1, $ingredients2, $lang1, $lang2, $missing_stop_words_before) = @_;

	$log->debug(
		"check_ingredients_between_languages > detect_missing_stop_words_before_list - start, lang1: $lang1, lang2: $lang2"
	) if $log->is_debug();

	# Return if first ingredient in ingredients1 is unknown or first ingredient in ingredients2 is known
	if (!$ingredients1->[0]{is_in_taxonomy} || $ingredients2->[0]{is_in_taxonomy}) {
		$log->debug(
			"check_ingredients_between_languages > detect_missing_stop_words_before_list -   first ingredient in ingredients1 ($ingredients1->[0]{id}) is unknown (is_in_taxonomy => $ingredients1->[0]{is_in_taxonomy}) or first ingredient in ingredients2 is known (is_in_taxonomy => $ingredients2->[0]{is_in_taxonomy})"
		) if $log->is_debug();
		return;
	}

	# Iterate on all first unknown ingredient from ingredients2 until we find first ingredients1
	my $previous_ingredients_object;
	foreach my $i (0 .. $#$ingredients2) {
		$log->debug(
			"check_ingredients_between_languages > detect_missing_stop_words_before_list -   search for first known ingredient in ingredients1: $ingredients2->[$i]{text}"
		) if $log->is_debug();
		# based on previous return condition, first iteration will be else
		if ($ingredients2->[$i]{id} eq $ingredients1->[0]{id}) {
			unless (exists $missing_stop_words_before->{$previous_ingredients_object->{id}}) {
				$log->debug(
					"check_ingredients_between_languages > detect_missing_stop_words_before_list -   adding stopword before, first time: $previous_ingredients_object->{id}"
				) if $log->is_debug();
				$missing_stop_words_before->{$lang2} = $previous_ingredients_object->{id};
			}
			last;
		}
		else {
			$previous_ingredients_object = $ingredients2->[$i];
		}
	}

	return;
}

=head2 get_ingredient_index ( ingredients, ingredient_id )

This function finds the index of a specific ingredient in a list of ingredients based on its ID.

=head3 Arguments

=head4 ingredients

An array reference of ingredients, where each ingredient is represented as a hash reference.

=head4 ingredient_id

A string representing the ID of the ingredient to find.

=head3 Return value

Returns the index of the ingredient if found, otherwise returns -1.

=cut

sub get_ingredient_index {
	my ($ingredients, $ingredient_id) = @_;

	my $index = -1;

	foreach my $i (0 .. $#{$ingredients}) {
		if ($ingredients->[$i]{id} eq $ingredient_id) {
			$index = $i;
			last;
		}
	}
	return $index;
}

=head2 detect_missing_stop_words_after_list ( ingredients1, ingredients2, lang1, lang2, missing_stop_words_after )

This function detects missing stop words after the last known ingredient in a list of ingredients.

=head3 Arguments

=head4 ingredients1

An array reference of ingredients in the first language (reference).

=head4 ingredients2

An array reference of ingredients in the second language (to analyze).

=head4 lang1

A string representing the language code for the first language.

=head4 lang2

A string representing the language code for the second language.

=head4 missing_stop_words_after

A hash reference to store the missing stop words after the last known ingredient.

=head3 Return value

This function does not return a value but modifies the `missing_stop_words_after` hash reference to store the missing stop words.

=cut

sub detect_missing_stop_words_after_list {
	my ($ingredients1, $ingredients2, $lang1, $lang2, $missing_stop_words_after) = @_;

	$log->debug(
		"check_ingredients_between_languages > detect_missing_stop_words_after_list - start, lang1: $lang1, lang2: $lang2"
	) if $log->is_debug();

	# Check if all known ingredients up to len(lang2) have the same ID at the same position
	my $translation_difference_count = 0;
	my $translation_difference_accepted_percentage = 0.5;
	for my $i (0 .. $#$ingredients2) {
		# Lower than last index of ingredients1
		if ($i <= $#$ingredients1) {
			if (   $ingredients1->[$i]{is_in_taxonomy}
				&& $ingredients2->[$i]{is_in_taxonomy}
				&& $ingredients1->[$i]{id} ne $ingredients2->[$i]{id})
			{
				$translation_difference_count += 1;
			}
		}
	}
	if (scalar(@{$ingredients1}) > 0
		&& $translation_difference_count / scalar(@{$ingredients1}) > $translation_difference_accepted_percentage)
	{
		$log->debug(
			"check_ingredients_between_languages > detect_missing_stop_words_after_list -   too much difference between languages to raise warning. diff/total > tolerance: $translation_difference_count / $#$ingredients1 = "
				. $translation_difference_count / $#$ingredients1 . " > "
				. $translation_difference_accepted_percentage)
			if $log->is_debug();
		return;
	}

	# Check if the ingredient at position len(lang1) + 1 in lang2 is unknown, if unknown, then it is a possible stop word
	# Last word of ingredients1 should be known
	if (   @$ingredients2 > @$ingredients1
		&& $ingredients1->[-1]{is_in_taxonomy}
		&& !$ingredients2->[@$ingredients1]{is_in_taxonomy})
	{
		my $unknown_ingredient_object = $ingredients2->[@$ingredients1];
		$log->debug(
			"check_ingredients_between_languages > detect_missing_stop_words_after_list -   should push $unknown_ingredient_object->{id}"
		) if $log->is_debug();

		if (exists $missing_stop_words_after->{$lang2}) {
			my $index_existing_value = get_ingredient_index($ingredients2, $missing_stop_words_after->{$lang2});
			my $index_new_value = get_ingredient_index($ingredients2, $unknown_ingredient_object->{id});

			$log->debug(
				"check_ingredients_between_languages > detect_missing_stop_words_after_list -   adding stopword after, not first time: previously: $missing_stop_words_after->{$lang2} (index: $index_existing_value), newly: $unknown_ingredient_object->{id} ($index_new_value), check index"
			) if $log->is_debug();

			if ($index_new_value < $index_existing_value) {
				$missing_stop_words_after->{$lang2} = $unknown_ingredient_object->{id};
			}
		}
		else {
			$log->debug(
				"check_ingredients_between_languages > detect_missing_stop_words_after_list -   adding stopword after, first time: $unknown_ingredient_object->{id}"
			) if $log->is_debug();
			$missing_stop_words_after->{$lang2} = $unknown_ingredient_object->{id};
		}
	}

	return;
}

=head2 remove_duplicates ( @array )

This function removes duplicate elements from an array.

=head3 Arguments

=head4 @array

An array of elements from which duplicates need to be removed.

=head3 Return value

Returns an array with duplicate elements removed.

=cut

sub remove_duplicates {
	my (@array) = @_;

	my %seen;
	my @unique_array;

	foreach my $element (@array) {
		unless ($seen{$element}) {
			push @unique_array, $element;
			$seen{$element} = 1;
		}
	}

	return @unique_array;
}

=head2 find_smallest_value_key ( hashmap )

This function finds the key with the smallest value in a hashmap. If multiple keys have the same smallest value, it returns the first key in alphabetical order.

=head3 Arguments

=head4 hashmap

A hash reference where the keys are strings and the values are numeric.

=head3 Return value

Returns the key with the smallest value. If multiple keys have the same smallest value, returns the first key in alphabetical order.

=cut

sub find_smallest_value_key {
	my ($hashmap) = @_;

	my $smallest_value = undef;
	my $smallest_key = undef;

	foreach my $key (keys %$hashmap) {
		$log->debug(
			"check_ingredients_between_languages > find_smallest_value_key - next key: $key. Distance: $hashmap->{$key}"
		) if $log->is_debug();
		if (!defined $smallest_value || $hashmap->{$key} < $smallest_value) {
			$smallest_value = $hashmap->{$key};
			$smallest_key = $key;
		}
		elsif ($hashmap->{$key} == $smallest_value) {
			my ($ingredient_a, $ingredient_b) = get_sorted_strings($smallest_key, $key);
			$smallest_value = $hashmap->{$ingredient_a};
			$smallest_key = $ingredient_a;
		}
	}

	return $smallest_key;
}

=head2 get_sorted_strings ( string1, string2 )

This function returns two strings in alphabetical order.

=head3 Arguments

=head4 string1

A string to be compared.

=head4 string2

A string to be compared.

=head3 Return value

Returns a list of two strings sorted in lexicographical order.

=cut

sub get_sorted_strings {
	my ($string1, $string2) = @_;

	if ($string1 lt $string2) {
		return ($string1, $string2);
	}
	else {
		return ($string2, $string1);
	}
}

=head2 detect_missing_ingredients ( ingredients1, ingredients2, lang1, lang2, missing_ingredients, ingredients_typo, mismatch_in_taxonomy )

This function detects missing ingredients and potential typos between two lists of ingredients in different languages.

=head3 Arguments

=head4 ingredients1

An array reference of ingredients in the first language (reference).

=head4 ingredients2

An array reference of ingredients in the second language (to analyze).

=head4 lang1

A string representing the language code for the first language.

=head4 lang2

A string representing the language code for the second language.

=head4 missing_ingredients

A hash reference to store missing ingredients.

=head4 ingredients_typo

A hash reference to store potential typos in ingredients.

=head4 mismatch_in_taxonomy

A hash reference to store mismatches in the taxonomy between the two languages.

=head3 Return value

This function does not return a value but modifies the `missing_ingredients`, `ingredients_typo`, and `mismatch_in_taxonomy` hash references to store the detected issues.

=cut

sub detect_missing_ingredients {
	my ($ingredients1, $ingredients2, $lang1, $lang2, $missing_ingredients, $ingredients_typo, $mismatch_in_taxonomy)
		= @_;

	$log->debug(
		"check_ingredients_between_languages > detect_missing_ingredients - start,  lang1 is $lang1, lang2 is $lang2")
		if $log->is_debug();

	foreach my $i (0 .. $#$ingredients1) {
		if ($ingredients1->[$i]{is_in_taxonomy} && !$ingredients2->[$i]{is_in_taxonomy}) {
			$log->debug(
				"check_ingredients_between_languages > detect_missing_ingredients -   $lang1:$ingredients1->[$i]{text} is in the taxonomy but not $ingredients2->[$i]{id}"
			) if $log->is_debug();

			my $unknown_ingredient_object = $ingredients2->[$i];

			my @synonyms = get_taxonomy_tag_synonyms($lang2, "ingredients", $ingredients1->[$i]{id});

			if (!@synonyms) {
				if (exists $missing_ingredients->{$unknown_ingredient_object->{id}}) {
					my ($id_a, $id_b) = get_sorted_strings($missing_ingredients->{$unknown_ingredient_object->{id}},
						$ingredients1->[$i]{id});

					$log->debug(
						"check_ingredients_between_languages > detect_missing_ingredients -   adding missing ingredient, additional time: $id_a"
					) if $log->is_debug();
					$missing_ingredients->{$unknown_ingredient_object->{id}} = $id_a;
				}
				else {
					$log->debug(
						"check_ingredients_between_languages > detect_missing_ingredients -   adding missing ingredient, first time: $unknown_ingredient_object->{id}"
					) if $log->is_debug();
					$missing_ingredients->{$unknown_ingredient_object->{id}} = $ingredients1->[$i]{id};
				}
			}
			# prevent to divide by zero
			elsif (length($unknown_ingredient_object->{text}) > 0) {
				my @unique_synonyms = remove_duplicates(@synonyms);
				$log->debug("check_ingredients_between_languages > detect_missing_ingredients -   retrieved "
						. scalar(@unique_synonyms)
						. " unique synonyms: "
						. join(", ", @unique_synonyms))
					if $log->is_debug();
				# Levenshtein distance for each synonym
				#  acceptance of 40%, for example in Croatian: secer -> šećer
				my %synonym_distance;
				foreach my $synonym (@unique_synonyms) {
					my $lev_distance = distance($unknown_ingredient_object->{text}, $synonym);
					$synonym_distance{$synonym} = $lev_distance / length($unknown_ingredient_object->{text});
					$log->debug(
						"check_ingredients_between_languages > detect_missing_ingredients -   levenshtein synonyms distance between the ingredient $unknown_ingredient_object->{text} and the synonym $synonym is $lev_distance"
					) if $log->is_debug();
				}

				my $key_for_smallest_levenshtein_value = find_smallest_value_key(\%synonym_distance);
				$log->debug(
					"check_ingredients_between_languages > detect_missing_ingredients -   levenshtein synonyms smallest distance: $key_for_smallest_levenshtein_value"
				) if $log->is_debug();

				if (defined $key_for_smallest_levenshtein_value) {
					my $smallest_levenshtein_value = $synonym_distance{$key_for_smallest_levenshtein_value};

					if ($smallest_levenshtein_value <= 0.4) {
						$log->debug(
							"check_ingredients_between_languages > detect_missing_ingredients:   the key with the smallest value is '$key_for_smallest_levenshtein_value' and its value is $smallest_levenshtein_value, which is equal to or less than the threshold."
						) if $log->is_debug();
						unless (exists $ingredients_typo->{$unknown_ingredient_object->{text}}) {
							$key_for_smallest_levenshtein_value =~ s/\s+/-/g;
							$log->debug(
								"check_ingredients_between_languages > detect_missing_ingredients -   adding it to ingredients_typo, first time $unknown_ingredient_object->{text}"
							) if $log->is_debug();
							$ingredients_typo->{$unknown_ingredient_object->{id}}
								= $lang2 . ":" . lc($key_for_smallest_levenshtein_value);
						}
					}
				}
			}
		}

		# Check if both are in the taxonomy but with a different id
		elsif ($ingredients1->[$i]{is_in_taxonomy}
			&& $ingredients2->[$i]{is_in_taxonomy}
			&& $ingredients1->[$i]{id} ne $ingredients2->[$i]{id})
		{
			$log->debug(
				"check_ingredients_between_languages > detect_missing_ingredients -     different id between ingredients $ingredients1->[$i]{id} and $ingredients2->[$i]{id}"
			) if $log->is_debug();

			# Ignore if ids are different but have a child/parent relation
			if (   !(is_a("ingredients", $ingredients1->[$i]{id}, $ingredients2->[$i]{id}))
				&& !(is_a("ingredients", $ingredients2->[$i]{id}, $ingredients1->[$i]{id})))
			{
				$log->debug(
					"check_ingredients_between_languages > detect_missing_ingredients -     different id between ingredients and no relation between them"
				) if $log->is_debug();

				my $text_and_id1 = $ingredients1->[$i]{text} . "-id:" . $ingredients1->[$i]{id};
				my $text_and_id2 = $ingredients2->[$i]{text} . "-id:" . $ingredients2->[$i]{id};

				my ($text_and_id_a, $text_and_id_b) = get_sorted_strings($text_and_id1, $text_and_id2);

				$text_and_id_a =~ s/\s+/-/g;
				unless (exists $mismatch_in_taxonomy->{$text_and_id_a}) {
					$text_and_id_b =~ s/\s+/-/g;
					$mismatch_in_taxonomy->{$text_and_id_a} = $text_and_id_b;
				}
			}
		}
	}

	return;
}

=head2 check_ingredients_between_languages ( product_ref )

This function extracts data for each language from the provided product reference.
It then detects failed extractions (missing stop words) and identifies missing translations.

=head3 Arguments

=head4 product_ref

A reference to the product data, which is expected to be a hash reference containing the necessary information.

=head3 Return value

This function does not return any value. It performs the extraction and detection internally.

=cut

sub check_ingredients_between_languages {
	my ($product_ref) = @_;

	$log->debug("check_ingredients_between_languages - start $product_ref->{code}") if $log->is_debug();

	delete $product_ref->{"taxonomies_enhancer_tags"} if exists $product_ref->{"taxonomies_enhancer_tags"};

	# Create a new hash for ingredients_text_<something> fields to not impact $product_ref
	my %ingredients_hash;
	foreach my $key (keys %{$product_ref}) {
		# ingredients_text_fi yes, ingredients_text_with_allergens_fi no
		if ($key =~ /^ingredients_text_[a-z]{2}$/) {
			$ingredients_hash{$key} = $product_ref->{$key};
			$log->debug("Added key: $key with value: $product_ref->{$key}") if $log->is_debug();
		}
	}

	# Process each key in the product reference to parse ingredients for each language
	foreach my $key (keys %ingredients_hash) {
		parse_ingredients_for_language(\%ingredients_hash, $key);
	}
	# keep only lang code and remove any "allergens", "labels", "labels_lc", "labels_tags", "labels_hierarchy" that might be in the hashmap
	foreach my $key (keys %ingredients_hash) {
		delete $ingredients_hash{$key} unless $key =~ /^[a-z]{2}$/;
	}

	my %missing_stop_words_after;
	my %missing_stop_words_before;
	my %missing_ingredients;
	my %ingredients_typo;
	my %mismatch_in_taxonomy;

	foreach my $lang1 (keys %ingredients_hash) {
		foreach my $lang2 (keys %ingredients_hash) {
			$log->debug(
				"check_ingredients_between_languages -   next iteration lang1 (ref): $lang1 and lang2 (analyzed): $lang2"
			) if $log->is_debug();

			# Reminder: ingredients1 is the reference and missing stop words or missing ingredients are searched into ingredients2 only
			next
				if $lang1 eq $lang2
				|| not_enough_known_ingredients($ingredients_hash{$lang1}, $ingredients_hash{$lang2});

			if (@{$ingredients_hash{$lang2}} > @{$ingredients_hash{$lang1}}) {
				detect_missing_stop_words_before_list(
					$ingredients_hash{$lang1},
					$ingredients_hash{$lang2},
					$lang1, $lang2, \%missing_stop_words_before
				);

				# If a stop word before has been found, there cannot be a 1 to 1 ingredients mapping with other language, hence, no need to call the function
				if (!$missing_stop_words_before{$lang2}) {
					detect_missing_stop_words_after_list(
						$ingredients_hash{$lang1},
						$ingredients_hash{$lang2},
						$lang1, $lang2, \%missing_stop_words_after
					);
				}

			}

			if (@{$ingredients_hash{$lang1}} == @{$ingredients_hash{$lang2}}) {
				detect_missing_ingredients(
					$ingredients_hash{$lang1},
					$ingredients_hash{$lang2},
					$lang1, $lang2, \%missing_ingredients, \%ingredients_typo, \%mismatch_in_taxonomy
				);
			}
		}
	}

	foreach my $lang (keys %missing_stop_words_before) {
		$log->debug(
			"check_ingredients_between_languages - detected: en:possible-stop-word-before-$missing_stop_words_before{$lang}"
		) if $log->is_debug();
		add_tag($product_ref, "taxonomies_enhancer", "en:possible-stop-word-before-$missing_stop_words_before{$lang}");
	}
	foreach my $lang (keys %missing_stop_words_after) {
		$log->debug(
			"check_ingredients_between_languages - detected: en:possible-stop-word-after-$missing_stop_words_after{$lang}"
		) if $log->is_debug();
		add_tag($product_ref, "taxonomies_enhancer", "en:possible-stop-word-after-$missing_stop_words_after{$lang}");
	}
	foreach my $new_ingredient_id (keys %missing_ingredients) {
		$log->debug(
			"check_ingredients_between_languages - detected: en:ingredients-$new_ingredient_id-is-new-translation-for-$missing_ingredients{$new_ingredient_id}"
		) if $log->is_debug();
		add_tag($product_ref, "taxonomies_enhancer",
			"en:ingredients-$new_ingredient_id-is-new-translation-for-$missing_ingredients{$new_ingredient_id}");
	}
	foreach my $ingredient_with_typo (keys %ingredients_typo) {
		$log->debug(
			"check_ingredients_between_languages - detected: en:ingredients-$ingredient_with_typo-is-possible-typo-for-$ingredients_typo{$ingredient_with_typo}"
		) if $log->is_debug();
		add_tag($product_ref, "taxonomies_enhancer",
			"en:ingredients-$ingredient_with_typo-is-possible-typo-for-$ingredients_typo{$ingredient_with_typo}");
	}
	# ignore if there are too many discrepencies found, it might be comparison of old ingredient list in a lang and new ingredient list in other lang, example 8014190017627
	if (scalar(keys %mismatch_in_taxonomy) < 2) {
		foreach my $ingredient_id1 (keys %mismatch_in_taxonomy) {
			$log->debug(
				"check_ingredients_between_languages - detected: en:ingredients-taxonomy-between-$ingredient_id1-and-$mismatch_in_taxonomy{$ingredient_id1}-should-be-same-id"
			) if $log->is_debug();
			add_tag($product_ref, "taxonomies_enhancer",
				"en:ingredients-taxonomy-between-$ingredient_id1-and-$mismatch_in_taxonomy{$ingredient_id1}-should-be-same-id"
			);
		}
	}

	return;
}

1;
