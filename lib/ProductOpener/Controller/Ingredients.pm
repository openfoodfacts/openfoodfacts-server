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

ProductOpener::Controller::Ingredients - handling HTTP requests related to ingredients

=cut

package ProductOpener::Controller::Ingredients;
use ProductOpener::PerlStandards;

=head2 display_nested_list_of_ingredients ( $ingredients_ref, $ingredients_text_ref, $ingredients_list_ref )

Recursive function to display how the ingredients were analyzed.
This function calls itself to display sub-ingredients of ingredients.

=head3 Parameters

=head4 $ingredients_ref (input)

Reference to the product's ingredients array or the ingredients array of an ingredient.

=head4 $ingredients_text_ref (output)

Reference to a list of ingredients in text format that we will reconstruct from the ingredients array.

=head4 $ingredients_list_ref (output)

Reference to an HTML list of ingredients in ordered nested list format that corresponds to the ingredients array.

=cut

sub display_nested_list_of_ingredients ($ingredients_ref, $ingredients_text_ref, $ingredients_list_ref) {

	${$ingredients_list_ref} .= "<ol id=\"ordered_ingredients_list\">\n";

	my $i = 0;

	foreach my $ingredient_ref (@{$ingredients_ref}) {

		$i++;

		($i > 1) and ${$ingredients_text_ref} .= ", ";

		my $ingredients_exists = exists_taxonomy_tag("ingredients", $ingredient_ref->{id});
		my $class = '';
		if (not $ingredients_exists) {
			$class = ' class="text_info unknown_ingredient"';
		}

		${$ingredients_text_ref} .= "<span$class>" . $ingredient_ref->{text} . "</span>";

		if (defined $ingredient_ref->{percent}) {
			${$ingredients_text_ref} .= " " . $ingredient_ref->{percent} . "%";
		}

		${$ingredients_list_ref}
			.= "<li>" . "<span$class>" . $ingredient_ref->{text} . "</span>" . " -> " . $ingredient_ref->{id};

		foreach my $property (
			qw(origin labels vegan vegetarian from_palm_oil ciqual_food_code ciqual_proxy_food_code percent_min percent percent_max)
			)
		{
			if (defined $ingredient_ref->{$property}) {
				${$ingredients_list_ref} .= " - " . $property . ":&nbsp;" . $ingredient_ref->{$property};
			}
		}

		if (defined $ingredient_ref->{ingredients}) {
			${$ingredients_text_ref} .= " (";
			display_nested_list_of_ingredients($ingredient_ref->{ingredients},
				$ingredients_text_ref, $ingredients_list_ref);
			${$ingredients_text_ref} .= ")";
		}

		${$ingredients_list_ref} .= "</li>\n";
	}

	${$ingredients_list_ref} .= "</ol>\n";

	return;
}

=head2 display_list_of_specific_ingredients ( $product_ref )

Generate HTML to display how the specific ingredients (e.g. mentions like "Total milk content: 90%")
were analyzed.

=head3 Parameters

=head4 $product_ref

=head3 Return value

Empty string if no specific ingredients were detected, or HTML describing the specific ingredients.

=cut

sub display_list_of_specific_ingredients ($product_ref) {

	if (not defined $product_ref->{specific_ingredients}) {
		return "";
	}

	my $html = "<ul id=\"specific_ingredients_list\">\n";

	foreach my $ingredient_ref (@{$product_ref->{specific_ingredients}}) {

		my $ingredients_exists = exists_taxonomy_tag("ingredients", $ingredient_ref->{id});
		my $class = '';
		if (not $ingredients_exists) {
			$class = ' class="unknown_ingredient"';
		}

		$html
			.= "<li>"
			. $ingredient_ref->{text} . "<br>"
			. "<span$class>"
			. $ingredient_ref->{ingredient}
			. "</span>" . " -> "
			. $ingredient_ref->{id};

		foreach my $property (qw(origin labels vegan vegetarian from_palm_oil percent_min percent percent_max)) {
			if (defined $ingredient_ref->{$property}) {
				$html .= " - " . $property . ":&nbsp;" . $ingredient_ref->{$property};
			}
		}

		$html .= "</li>\n";
	}

	$html .= "</ul>\n";

	return $html;
}

=head2 data_to_display_ingredients_analysis_details ( $product_ref )

Generates a data structure to display the details of ingredients analysis.

The resulting data structure can be passed to a template to generate HTML or the JSON data for a knowledge panel.

=head3 Arguments

=head4 Product reference $product_ref

=head3 Return values

Reference to a data structure with needed data to display.

=cut

sub data_to_display_ingredients_analysis_details ($product_ref) {

	# Do not display ingredients analysis details when we don't have ingredients

	if (   (not defined $product_ref->{ingredients})
		or (scalar @{$product_ref->{ingredients}} == 0))
	{
		return;
	}

	my $result_data_ref = {};

	my $ingredients_text_lc = $product_ref->{ingredients_lc};
	my $ingredients_text = "$ingredients_text_lc: ";
	my $ingredients_list = "";

	display_nested_list_of_ingredients($product_ref->{ingredients}, \$ingredients_text, \$ingredients_list);

	my $specific_ingredients = display_list_of_specific_ingredients($product_ref);

	if (($ingredients_text . $specific_ingredients) =~ /unknown_ingredient/) {
		$result_data_ref->{unknown_ingredients} = 1;
	}

	$result_data_ref->{ingredients_text} = $ingredients_text;
	$result_data_ref->{ingredients_list} = $ingredients_list;
	$result_data_ref->{specific_ingredients} = $specific_ingredients;

	return $result_data_ref;
}

=head2 display_ingredients_analysis_details ( $product_ref )

Generates HTML code with information on how the ingredient list was parsed and mapped to the ingredients taxonomy.

=cut

sub display_ingredients_analysis_details ($product_ref) {

	my $html = "";

	my $template_data_ref = data_to_display_ingredients_analysis_details($product_ref);

	if (defined $template_data_ref) {
		process_template('web/pages/product/includes/ingredients_analysis_details.tt.html', $template_data_ref, \$html)
			|| return "template error: " . $tt->error();
	}

	return $html;
}

=head2 data_to_display_ingredients_analysis ( $product_ref )

Generates a data structure to display the results of ingredients analysis.

The resulting data structure can be passed to a template to generate HTML or the JSON data for a knowledge panel.

=head3 Arguments

=head4 Product reference $product_ref

=head3 Return values

Reference to a data structure with needed data to display.

=cut

sub data_to_display_ingredients_analysis ($product_ref) {

	my $result_data_ref;

	# Populate the data templates needed to display the Nutri-Score and nutrient levels

	if (defined $product_ref->{ingredients_analysis_tags}) {

		$result_data_ref = {ingredients_analysis_tags => [],};

		foreach my $ingredients_analysis_tag (@{$product_ref->{ingredients_analysis_tags}}) {

			my $evaluation;
			my $icon = "";
			# $ingredients_analysis_tag is a tag like "en:palm-oil-free", "en:vegan-status-unknown", or "en:non-vegetarian"
			# we will derive from it the associated property e.g. "palm_oil", "vegan", "vegetarian"
			# and the tag corresponding to unknown status for the property e.g. "en:palm-oil-content-unknown", "en:vegan-status-unknown"
			# so that we can display unknown ingredients for the property even if the status is different than unknown
			my $property;
			my $property_unknown_tag;

			if ($ingredients_analysis_tag =~ /palm/) {

				# Set property and icon
				$property = "palm_oil_free";
				$property_unknown_tag = "en:palm-oil-content-unknown";
				$icon = "palm-oil";

				# Evaluation
				if ($ingredients_analysis_tag =~ /-free$/) {
					$evaluation = 'good';
				}
				elsif ($ingredients_analysis_tag =~ /unknown/) {
					$evaluation = 'unknown';
				}
				elsif ($ingredients_analysis_tag =~ /^en:may-/) {
					$evaluation = 'average';
				}
				else {
					$evaluation = 'bad';
				}
			}
			else {

				# Set property (e.g. vegan for the tag vegan or non-vegan) and icon
				if ($ingredients_analysis_tag =~ /vegan/) {
					$property = "vegan";
					$icon = "leaf";
				}
				elsif ($ingredients_analysis_tag =~ /vegetarian/) {
					$property = "vegetarian";
					$icon = "vegetarian";
				}
				$property_unknown_tag = "en:" . $property . "-status-unknown";

				# Evaluation
				if ($ingredients_analysis_tag =~ /^en:non-/) {
					$evaluation = 'bad';
				}
				elsif ($ingredients_analysis_tag =~ /^en:maybe-/) {
					$evaluation = 'average';
				}
				elsif ($ingredients_analysis_tag =~ /unknown/) {
					$evaluation = 'unknown';
				}
				else {
					$evaluation = 'good';
				}
			}

			# Generate the translation string id for the list of ingredients we will display
			my $ingredients_title_id;
			if ($evaluation eq "unknown") {
				$ingredients_title_id = "unrecognized_ingredients";
			}
			else {
				# convert analysis tag to a translation string id
				# eg. en:non-vegetarian property to non_vegetarian_ingredients translation string id
				$ingredients_title_id = lc($ingredients_analysis_tag) . "_ingredients";
				$ingredients_title_id =~ s/^en://;
				$ingredients_title_id =~ s/-/_/g;
			}

			push @{$result_data_ref->{ingredients_analysis_tags}},
				{
				tag => $ingredients_analysis_tag,
				property => $property,
				property_unknown_tag => $property_unknown_tag,
				evaluation => $evaluation,
				icon => $icon,
				title => display_taxonomy_tag($lc, "ingredients_analysis", $ingredients_analysis_tag),
				ingredients_title_id => $ingredients_title_id,
				};
		}
	}

	return $result_data_ref;
}

=head2 display_ingredients_analysis ( $product_ref )

Generates HTML code with icons that show if the product is vegetarian, vegan and without palm oil.

=cut

sub display_ingredients_analysis ($product_ref) {

	# Ingredient analysis

	my $html = "";

	my $template_data_ref = data_to_display_ingredients_analysis($product_ref);

	if (defined $template_data_ref) {
		process_template('web/pages/product/includes/ingredients_analysis.tt.html', $template_data_ref, \$html)
			|| return "template error: " . $tt->error();
	}

	return $html;
}

sub _format_comment ($comment) {

	$comment = lang($comment) if $comment eq 'product_created';

	$comment =~ s/^Modification :\s+//;
	if ($comment eq 'Modification :') {
		$comment = q{};
	}

	$comment =~ s/new image \d+( -)?//;

	return $comment;
}

1;

