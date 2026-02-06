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

=head1 NAME

ProductOpener::DataQualityDimensions - compute score for each dimensions

=head1 DESCRIPTION

C<ProductOpener::DataQualityDimensions> is a submodule of C<ProductOpener::DataQuality>.

It compute score for each dimensions.

=cut

package ProductOpener::DataQualityDimensions;

use ProductOpener::PerlStandards;
use Exporter qw(import);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&compute_accuracy_score
		&compute_completeness_score
		&compute_dimensions_score
	);
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use ProductOpener::DataQualityFood qw(is_european_product);
use ProductOpener::Tags qw(add_tag get_all_tags_having_property);

=head1 FUNCTIONS

=head2 compute_accuracy_score

This function computes the accuracy score of the product data.
It checks if the product has a name, brand, quantity, packaging, and image.
It calculates the accuracy score as a percentage of the total number of fields checked.

=head3 Arguments

=head4 $product_ref

A hash reference to the product data.

=head3 Return value

Returns nothing.

=cut

sub compute_accuracy_score($product_ref) {

	my $accuracy_count = 0;
	my $accuracy_total = 0;

	if ((defined $product_ref->{checked}) and ($product_ref->{checked} eq 'on')) {
		add_tag($product_ref, "data_quality_completeness", "en:photo-and-data-checked-by-an-experienced-contributor");
		$accuracy_count++;
	}
	else {
		add_tag($product_ref, "data_quality_completeness",
			"en:photo-and-data-to-be-checked-by-an-experienced-contributor");
	}
	$accuracy_total++;

	my $accuracy_score = $accuracy_total != 0 ? ($accuracy_count / $accuracy_total) : 0;
	$product_ref->{"data_quality_dimensions"}{accuracy}{overall} = sprintf("%.2f", $accuracy_score);

	return;
}

=head1 FUNCTIONS

=head2 compute_completeness_score

This function computes the completeness score of the product data.
It checks if the product has a name, brand, quantity, packaging, and image.
It calculates the completeness score as a percentage of the total number of fields checked.

=head3 Arguments

=head4 $product_ref

A hash reference to the product data.

=head3 Return value

Returns nothing.

=cut

sub compute_completeness_score($product_ref) {

	# 1-ingredients
	# per languages "languages_codes"
	my @lang_codes = keys %{$product_ref->{languages_codes}};
	@lang_codes = sort @lang_codes;

	my $completeness_ingredients_count = 0;
	my $completeness_ingredients_total = 0;
	foreach my $lang_code (@lang_codes) {
		# 1-1- Photos
		if (defined $product_ref->{images}{selected}{ingredients}{$lang_code}) {
			add_tag($product_ref, "data_quality_completeness", "en:ingredients-$lang_code-photo-selected");
			$completeness_ingredients_count++;
		}
		else {
			add_tag($product_ref, "data_quality_completeness", "en:ingredients-$lang_code-photo-to-be-selected");
		}
		$completeness_ingredients_total++;
		# 1-2- ingredients_text field is filled
		if (defined $product_ref->{"ingredients_text_$lang_code"}
			&& $product_ref->{"ingredients_text_$lang_code"} ne '')
		{
			add_tag($product_ref, "data_quality_completeness", "en:ingredients-$lang_code-completed");
			# the following is needed for the KnowledgePanelsIngredients and web_html.t tests
			add_tag($product_ref, "data_quality_completeness", "en:ingredients-completed-at-least-for-one-language");
			$completeness_ingredients_count++;
		}
		else {
			add_tag($product_ref, "data_quality_completeness", "en:ingredients-$lang_code-to-be-completed");
		}
		$completeness_ingredients_total++;
	}

	# 2-nutrition
	my $completeness_nutrition_count = 0;
	my $completeness_nutrition_total = 0;
	# 2-1- photo
	if (defined $product_ref->{images}{selected}{nutrition}
		&& scalar keys %{$product_ref->{images}{selected}{nutrition}} > 0)
	{
		add_tag($product_ref, "data_quality_completeness", "en:nutrition-photo-selected");
		$completeness_nutrition_count++;
	}
	elsif ( (defined $product_ref->{no_nutrition_data})
		and ($product_ref->{no_nutrition_data} eq 'on'))
	{
		$completeness_nutrition_count++;
	}
	else {
		add_tag($product_ref, "data_quality_completeness", "en:nutrition-photo-to-be-selected");
	}
	$completeness_nutrition_total++;
	# 2-2- category
	if ((defined $product_ref->{categories}) and ($product_ref->{categories} ne '')) {
		add_tag($product_ref, "data_quality_completeness", "en:categories-completed");
		$completeness_nutrition_count++;
	}
	else {
		add_tag($product_ref, "data_quality_completeness", "en:categories-to-be-completed");
	}
	$completeness_nutrition_total++;
	# 2-3- nutriments
	if (
		(
			(
				(defined $product_ref->{nutriments})
				# we have at least on valid nutrient (not counting nova and fruits-vegetables-*-estimates
				and (scalar grep {$_ !~ /^(nova|fruits-vegetables)/} keys %{$product_ref->{nutriments}}) > 0
			)
		)
		or ((defined $product_ref->{no_nutrition_data}) and ($product_ref->{no_nutrition_data} eq 'on'))
		)
	{
		add_tag($product_ref, "data_quality_completeness", "en:nutriments-completed");
		$completeness_nutrition_count++;
	}
	else {
		add_tag($product_ref, "data_quality_completeness", "en:nutriments-to-be-completed");
	}
	$completeness_nutrition_total++;

	# 3-packaging
	my $completeness_packaging_count = 0;
	my $completeness_packaging_total = 0;
	# 3-1- photo
	if (defined $product_ref->{images}{selected}{packaging}
		&& scalar keys %{$product_ref->{images}{selected}{packaging}} > 0)
	{
		add_tag($product_ref, "data_quality_completeness", "en:packaging-photo-selected");
		$completeness_packaging_count++;
	}
	else {
		add_tag($product_ref, "data_quality_completeness", "en:packaging-photo-to-be-selected");
	}
	$completeness_packaging_total++;
	# 3-2- packagings field is filled
	if (defined $product_ref->{packagings} && $product_ref->{packagings} ne '') {
		add_tag($product_ref, "data_quality_completeness", "en:packagings-completed");
		$completeness_packaging_count++;
	}
	else {
		add_tag($product_ref, "data_quality_completeness", "en:packagings-to-be-completed");
	}
	$completeness_packaging_total++;
	# 3-3- emb_codes (only for products with animal origin)
	my $european_product = is_european_product($product_ref);
	my $animal_origin_categories = get_all_tags_having_property($product_ref, "categories", "food_of_animal_origin:en");
	my $is_animal_origin = (scalar keys %{$animal_origin_categories}) > 0;

	if ($european_product && $is_animal_origin) {
		if (defined $product_ref->{emb_codes} && $product_ref->{emb_codes} ne '') {
			add_tag($product_ref, "data_quality_completeness", "en:traceability-codes-completed");
			$completeness_packaging_count++;
		}
		else {
			add_tag($product_ref, "data_quality_completeness", "en:traceability-codes-to-be-completed");
		}
		$completeness_packaging_total++;
	}

	# 4-general information
	my $completeness_general_information_count = 0;
	my $completeness_general_information_total = 0;
	# 4-1- photo
	if (defined $product_ref->{images}{selected}{front} && scalar keys %{$product_ref->{images}{selected}{front}} > 0) {
		add_tag($product_ref, "data_quality_completeness", "en:front-photo-selected");
		$completeness_general_information_count++;
	}
	else {
		add_tag($product_ref, "data_quality_completeness", "en:front-photo-to-be-selected");
	}
	$completeness_general_information_total++;
	# 4-2- name
	if (defined $product_ref->{product_name} && $product_ref->{product_name} ne '') {
		add_tag($product_ref, "data_quality_completeness", "en:product-name-completed");
		$completeness_general_information_count++;
	}
	else {
		add_tag($product_ref, "data_quality_completeness", "en:product-name-to-be-completed");
	}
	$completeness_general_information_total++;
	# 4-3- quantity
	if (defined $product_ref->{quantity} && $product_ref->{quantity} ne '') {
		add_tag($product_ref, "data_quality_completeness", "en:quantity-completed");
		$completeness_general_information_count++;
	}
	else {
		add_tag($product_ref, "data_quality_completeness", "en:quantity-to-be-completed");
	}
	$completeness_general_information_total++;
	# 4-4- brand
	if (defined $product_ref->{brands} && $product_ref->{brands} ne '') {
		add_tag($product_ref, "data_quality_completeness", "en:brands-completed");
		$completeness_general_information_count++;
	}
	else {
		add_tag($product_ref, "data_quality_completeness", "en:brands-to-be-completed");
	}
	$completeness_general_information_total++;
	# 4-4- expiration_date
	if (defined $product_ref->{expiration_date} && $product_ref->{expiration_date} ne '') {
		add_tag($product_ref, "data_quality_completeness", "en:expiration-date-completed");
		$completeness_general_information_count++;
	}
	else {
		add_tag($product_ref, "data_quality_completeness", "en:expiration-date-to-be-completed");
	}
	$completeness_general_information_total++;

	# Compute completeness score
	my $completeness_ingredients_score
		= $completeness_ingredients_total != 0
		? ($completeness_ingredients_count / $completeness_ingredients_total)
		: 0;
	$product_ref->{"data_quality_dimensions"}{completeness}{ingredients}
		= sprintf("%.2f", $completeness_ingredients_score);

	my $completeness_nutrition_score
		= $completeness_nutrition_total != 0
		? ($completeness_nutrition_count / $completeness_nutrition_total)
		: 0;
	$product_ref->{"data_quality_dimensions"}{completeness}{nutrition} = sprintf("%.2f", $completeness_nutrition_score);

	my $completeness_packaging_score
		= $completeness_packaging_total != 0
		? ($completeness_packaging_count / $completeness_packaging_total)
		: 0;
	$product_ref->{"data_quality_dimensions"}{completeness}{packaging} = sprintf("%.2f", $completeness_packaging_score);

	my $completeness_general_information_score
		= $completeness_general_information_total != 0
		? ($completeness_general_information_count / $completeness_general_information_total)
		: 0;
	$product_ref->{"data_quality_dimensions"}{completeness}{general_information}
		= sprintf("%.2f", $completeness_general_information_score);

	# Compute overall completeness score
	my $completeness_score = (
		(
				  $completeness_ingredients_count
				+ $completeness_nutrition_count
				+ $completeness_packaging_count
				+ $completeness_general_information_count
		) / (
			$completeness_ingredients_total
				+ $completeness_nutrition_total
				+ $completeness_packaging_total
				+ $completeness_general_information_total
		)
	);
	$product_ref->{"data_quality_dimensions"}{completeness}{overall} = sprintf("%.2f", $completeness_score);

	return;
}

=head1 FUNCTIONS

=head2 compute_dimensions_score

This function computes the score for each dimension of the product data quality.
It calculates scores for accuracy, completeness, uniqueness, consistency, timeliness, and validity.

=head3 Arguments

=head4 $product_ref

A hash reference to the product data.

=head3 Return value

Returns nothing.

=cut

sub compute_dimensions_score($product_ref) {

	# compute score for accuracy
	compute_accuracy_score($product_ref);

	# compute score for completeness
	compute_completeness_score($product_ref);

	# compute score for uniqueness
	# TODO

	# compute score for consistency
	# TODO

	# compute score for timeliness
	# TODO

	# compute score for validity
	# TODO

	return;
}

1;
