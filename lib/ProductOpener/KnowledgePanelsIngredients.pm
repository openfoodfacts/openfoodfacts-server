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

ProductOpener::KnowledgePanelsIngredients - Generate knowledge panels to report a problem with the data or the product

=head1 SYNOPSIS

Knowledge panels to indicate how to report a problem with the product data,
or with the product (e.g. link to report to authorities like SignalConso in France)

=cut

package ProductOpener::KnowledgePanelsIngredients;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

use Log::Any qw($log);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&create_ingredients_list_panel
		&create_data_quality_panel
		&create_ingredients_panel
		&create_additives_panel
		&create_ingredients_analysis_panel
		&create_ingredients_rare_crops_panel
		&create_ingredients_added_sugars_panel
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::KnowledgePanels
	qw(create_panel_from_json_template add_taxonomy_properties_in_target_languages_to_object);
use ProductOpener::Tags qw(:all);
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::URL qw/format_subdomain/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Lang qw/f_lang f_lang_in_lc lang lang_in_other_lc/;

use Encode;
use Data::DeepAccess qw(deep_get);

=head2 create_ingredients_list_panel ( $product_ref, $target_lc, $target_cc, $options_ref )

Creates a panel with a list of ingredients as individual panels.

=head3 Arguments

=head4 product reference $product_ref

=head4 language code $target_lc

=head4 country code $target_cc

=cut

sub create_ingredients_list_panel ($product_ref, $target_lc, $target_cc, $options_ref, $request_ref) {

	$log->debug("create ingredients list panel", {code => $product_ref->{code}}) if $log->is_debug();

	# Create a panel only if the product has ingredients

	if ((defined $product_ref->{ingredients_tags}) and (scalar @{$product_ref->{ingredients_tags}} > 0)) {

		my $ingredient_i = 0;    # sequence number for ingredients
								 # creates each individual panels for each ingredient
		my @ingredients_panels_ids
			= create_ingredients_panels_recursive($product_ref, \$ingredient_i, 0, $product_ref->{ingredients},
			$target_lc, $target_cc, $options_ref, $request_ref);
		my $ingredients_list_panel_data_ref = {ingredients_panels_ids => \@ingredients_panels_ids};

		# create the panel that reference ingredients panels
		create_panel_from_json_template(
			"ingredients_list",
			"api/knowledge-panels/health/ingredients/ingredients_list.tt.json",
			$ingredients_list_panel_data_ref,
			$product_ref, $target_lc, $target_cc, $options_ref, $request_ref
		);

	}
	return;
}

sub create_ingredients_panels_recursive ($product_ref, $ingredient_i_ref, $level, $ingredients_ref, $target_lc,
	$target_cc, $options_ref, $request_ref)
{

	my @ingredients_panels_ids = ();

	foreach my $ingredient_ref (@$ingredients_ref) {

		push @ingredients_panels_ids,
			create_ingredient_panel($product_ref, $ingredient_i_ref, $level, $ingredient_ref, $target_lc, $target_cc,
			$options_ref, $request_ref);
		if (defined $ingredient_ref->{ingredients}) {
			push @ingredients_panels_ids,
				create_ingredients_panels_recursive($product_ref, $ingredient_i_ref, $level + 1,
				$ingredient_ref->{ingredients},
				$target_lc, $target_cc, $options_ref, $request_ref);
		}

	}

	return @ingredients_panels_ids;
}

sub create_ingredient_panel ($product_ref, $ingredient_i_ref, $level, $ingredient_ref, $target_lc, $target_cc,
	$options_ref, $request_ref)
{

	$$ingredient_i_ref++;
	my $ingredient_panel_id = "ingredient_" . $$ingredient_i_ref;

	my $ingredient_panel_data_ref
		= {ingredient_id => $ingredient_ref->{id}, level => $level, ingredient => $ingredient_ref};

	# Wikipedia abstracts, in target language or English

	my $target_lcs_ref = [$target_lc];
	if ($target_lc ne "en") {
		push @$target_lcs_ref, "en";
	}

	add_taxonomy_properties_in_target_languages_to_object($ingredient_panel_data_ref, "ingredients",
		$ingredient_ref->{id}, ["wikipedia_url", "wikipedia_title", "wikipedia_abstract"],
		$target_lcs_ref);

	# We check if the knowledge content for this ingredient (and language/country) is available.
	# If it is it will be displayed instead of the wikipedia extract
	my $ingredient_description = get_knowledge_content("ingredients", $ingredient_ref->{id}, $target_lc, $target_cc);

	if (defined $ingredient_description) {
		$ingredient_panel_data_ref->{ingredient_description} = $ingredient_description;
	}

	create_panel_from_json_template($ingredient_panel_id, "api/knowledge-panels/health/ingredients/ingredient.tt.json",
		$ingredient_panel_data_ref, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref);

	return $ingredient_panel_id;
}

sub create_ingredients_rare_crops_panel ($product_ref, $target_lc, $target_cc, $options_ref, $request_ref) {

	# Go through the ingredients structure, and check if they have the rare_crop:en:yes property
	my @rare_crops_ingredients
		= get_ingredients_with_property_value($product_ref->{ingredients}, "rare_crop:en", "yes");

	$log->debug("rare crops", {rare_crops_ingredients => \@rare_crops_ingredients}) if $log->is_debug();

	if ($#rare_crops_ingredients >= 0) {

		my $panel_data_ref = {ingredients_rare_crops => \@rare_crops_ingredients,};

		create_panel_from_json_template("ingredients_rare_crops",
			"api/knowledge-panels/health/ingredients/ingredients_rare_crops.tt.json",
			$panel_data_ref, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref);
	}
	return;
}

sub create_ingredients_added_sugars_panel ($product_ref, $target_lc, $target_cc, $options_ref, $request_ref) {

	# Go through the ingredients structure, and check if they have the added_sugar:en:yes property
	my @added_sugars_ingredients = get_ingredients_with_parent($product_ref->{ingredients}, "en:added-sugar");

	#Remove duplicates from list of sugars
	my %seen;
	@added_sugars_ingredients = grep {!$seen{$_}++} @added_sugars_ingredients;

	$log->debug("added sugars", {added_sugars_ingredients => \@added_sugars_ingredients})
		if $log->is_debug();

	if ($#added_sugars_ingredients >= 0) {

		# Estimate the % of added sugars
		my $added_sugars_percent_estimate = estimate_added_sugars_percent_from_ingredients($product_ref);

		# Get the % of added sugars from the nutrition facts if it is available
		my $added_sugars_percent_nutrition_facts = deep_get($product_ref, qw(nutriments added-sugars_100g));

		my $panel_data_ref = {
			ingredients_added_sugars => \@added_sugars_ingredients,
			added_sugars_percent_estimate => $added_sugars_percent_estimate,
			added_sugars_percent_nutrition_facts => $added_sugars_percent_nutrition_facts,
		};

		# Get the most specific category so that we can link to the category without added sugars
		# Skip products that are in the "en:sweeteners" category
		if (    (defined $product_ref->{categories_hierarchy})
			and (scalar @{$product_ref->{categories_hierarchy}} > 0)
			and not(has_tag($product_ref, "categories", "en:sweeteners")))
		{
			my $category_id;

			# Find the most specific taxonomy that exists in the categories taxonomy
			foreach my $category_id2 (reverse @{$product_ref->{categories_hierarchy}}) {
				if (exists_taxonomy_tag("categories", $category_id2)) {
					$category_id = $category_id2;
					last;
				}
			}

			if (defined $category_id) {

				my $no_sweeteners_link = canonicalize_taxonomy_tag_link($target_lc, 'ingredients', "en:sweetener");
				my $no_added_sugars_link = canonicalize_taxonomy_tag_link($target_lc, 'ingredients', "en:added-sugar");

				# Transform the last /[added-sugar] in /-[added-sugar]
				$no_sweeteners_link =~ s/\/([^\/]+)$/\/-$1/;
				$no_added_sugars_link =~ s/\/([^\/]+)$/\/-$1/;

				my $category_without_added_sugars_url
					= $request_ref->{formatted_subdomain}
					. "/facets"
					. canonicalize_taxonomy_tag_link($target_lc, 'categories', $category_id)
					. canonicalize_taxonomy_tag_link($target_lc, 'states', "en:ingredients-completed")
					. $no_added_sugars_link
					. $no_sweeteners_link;

				$panel_data_ref->{category_id} = $category_id;
				$panel_data_ref->{category_without_added_sugars_url} = $category_without_added_sugars_url;
			}
		}

		create_panel_from_json_template("ingredients_added_sugars",
			"api/knowledge-panels/health/ingredients/ingredients_added_sugars.tt.json",
			$panel_data_ref, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref);
	}
	return;
}

=head2 create_ingredients_panel ( $product_ref, $target_lc, $target_cc, $options_ref )

Creates a knowledge panel with the list of ingredients.

=head3 Arguments

=head4 product reference $product_ref

Loaded from the MongoDB database, Storable files, or the OFF API.

=head4 language code $target_lc

Returned attributes contain both data and strings intended to be displayed to users.
This parameter sets the desired language for the user facing strings.

=head4 country code $target_cc

=cut

sub create_ingredients_panel ($product_ref, $target_lc, $target_cc, $options_ref, $request_ref) {

	$log->debug("create ingredients panel", {code => $product_ref->{code}}) if $log->is_debug();

	# try to display ingredients in the requested language if available

	my $ingredients_text = $product_ref->{ingredients_text};
	my $ingredients_text_with_allergens = $product_ref->{ingredients_text_with_allergens};
	my $ingredients_text_lc = $product_ref->{ingredients_lc};

	if (    (defined $product_ref->{"ingredients_text" . "_" . $target_lc})
		and ($product_ref->{"ingredients_text" . "_" . $target_lc} ne ''))
	{
		$ingredients_text = $product_ref->{"ingredients_text" . "_" . $target_lc};
		$ingredients_text_with_allergens = $product_ref->{"ingredients_text_with_allergens" . "_" . $target_lc};
		$ingredients_text_lc = $target_lc;
	}

	my $title = "";
	if (!(defined $product_ref->{ingredients_n}) || ($product_ref->{ingredients_n} == 0)) {
		$title = lang("no_ingredient");
	}
	elsif ($product_ref->{ingredients_n} == 1) {
		$title = lang("one_ingredient");
	}
	else {
		$title = f_lang("f_ingredients_with_number", {number => $product_ref->{ingredients_n}});
	}

	my $panel_data_ref = {
		title => $title,
		ingredients_text => $ingredients_text,
		ingredients_text_with_allergens => $ingredients_text_with_allergens,
		ingredients_text_lc => $ingredients_text_lc,
	};

	if (defined $ingredients_text_lc) {
		$panel_data_ref->{ingredients_text_language}
			= display_taxonomy_tag($target_lc, 'languages', $language_codes{$ingredients_text_lc});
	}

	create_panel_from_json_template("ingredients", "api/knowledge-panels/health/ingredients/ingredients.tt.json",
		$panel_data_ref, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref);
	return;
}

=head2 create_additives_panel ( $product_ref, $target_lc, $target_cc, $options_ref )

Creates knowledge panels for additives.

=head3 Arguments

=head4 product reference $product_ref

=head4 language code $target_lc

=head4 country code $target_cc

=cut

sub create_additives_panel ($product_ref, $target_lc, $target_cc, $options_ref, $request_ref) {

	$log->debug("create additives panel", {code => $product_ref->{code}}) if $log->is_debug();

	# Create a panel only if the product has additives

	if ((defined $product_ref->{additives_tags}) and (scalar @{$product_ref->{additives_tags}} > 0)) {

		my $additives_panel_data_ref = {};

		foreach my $additive (@{$product_ref->{additives_tags}}) {

			my $additive_panel_id = "additive_" . $additive;

			my $additive_panel_data_ref = {additive => $additive,};

			# Wikipedia abstracts, in target language or English

			my $target_lcs_ref = [$target_lc];
			if ($target_lc ne "en") {
				push @$target_lcs_ref, "en";
			}

			add_taxonomy_properties_in_target_languages_to_object($additive_panel_data_ref, "additives", $additive,
				["wikipedia_url", "wikipedia_title", "wikipedia_abstract"],
				$target_lcs_ref);

			# We check if the knowledge content for this additive (and language/country) is available.
			# If it is it will be displayed instead of the wikipedia extract
			my $additive_description = get_knowledge_content("additives", $additive, $target_lc, $target_cc);

			if (defined $additive_description) {
				$additive_panel_data_ref->{additive_description} = $additive_description;
			}

			create_panel_from_json_template($additive_panel_id,
				"api/knowledge-panels/health/ingredients/additive.tt.json",
				$additive_panel_data_ref, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref);
		}

		create_panel_from_json_template("additives", "api/knowledge-panels/health/ingredients/additives.tt.json",
			$additives_panel_data_ref, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref);

	}
	return;
}

=head2 create_ingredients_analysis_panel ( $product_ref, $target_lc, $target_cc, $options_ref )

Creates a knowledge panel with the results of ingredients analysis.

=head3 Arguments

=head4 product reference $product_ref

Loaded from the MongoDB database, Storable files, or the OFF API.

=head4 language code $target_lc

Returned attributes contain both data and strings intended to be displayed to users.
This parameter sets the desired language for the user facing strings.

=head4 country code $target_cc

=cut

sub create_ingredients_analysis_panel ($product_ref, $target_lc, $target_cc, $options_ref, $request_ref) {

	$log->debug("create ingredients analysis panel", {code => $product_ref->{code}}) if $log->is_debug();

	# First create an ingredients analysis details sub-panel
	# It will be included in the ingredients analysis panel

	my $ingredients_analysis_details_data_ref = data_to_display_ingredients_analysis_details($product_ref);

	# When we don't have ingredients, we don't display the ingredients analysis details
	if (defined $ingredients_analysis_details_data_ref) {
		create_panel_from_json_template(
			"ingredients_analysis_details",
			"api/knowledge-panels/health/ingredients/ingredients_analysis_details.tt.json",
			$ingredients_analysis_details_data_ref,
			$product_ref,
			$target_lc,
			$target_cc,
			$options_ref,
			$request_ref
		);

		# If we have some unrecognized ingredients, create a call for help panel that will be displayed in the ingredients analysis details panel
		# + the panels specific to each property (vegan, vegetarian, palm oil free)
		if ($ingredients_analysis_details_data_ref->{unknown_ingredients}) {
			create_panel_from_json_template("ingredients_analysis_help",
				"api/knowledge-panels/health/ingredients/ingredients_analysis_help.tt.json",
				{}, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref);
		}
	}

	# Create the ingredients analysis panel

	my $ingredients_analysis_data_ref = data_to_display_ingredients_analysis($product_ref);

	if (defined $ingredients_analysis_data_ref) {

		foreach my $property_panel_data_ref (@{$ingredients_analysis_data_ref->{ingredients_analysis_tags}}) {

			my $property_panel_id = "ingredients_analysis_" . $property_panel_data_ref->{tag};

			create_panel_from_json_template($property_panel_id,
				"api/knowledge-panels/health/ingredients/ingredients_analysis_property.tt.json",
				$property_panel_data_ref, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref);
		}

		create_panel_from_json_template("ingredients_analysis",
			"api/knowledge-panels/health/ingredients/ingredients_analysis.tt.json",
			{}, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref);
	}
	return;
}

1;
