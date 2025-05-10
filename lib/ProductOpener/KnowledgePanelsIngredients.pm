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
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::KnowledgePanels
	qw(create_panel_from_json_template add_taxonomy_properties_in_target_languages_to_object);
use ProductOpener::Tags qw(:all);

use Encode;
use Data::DeepAccess qw(deep_get);

=head2 create_ingredients_list_panel ( $product_ref, $target_lc, $target_cc, $options_ref )

Creates a panel with a list of ingredients as individual panels.

=head3 Arguments

=head4 product reference $product_ref

=head4 language code $target_lc

=head4 country code $target_cc

=cut

sub create_ingredients_list_panel ($product_ref, $target_lc, $target_cc, $options_ref) {

	$log->debug("create ingredients list panel", {code => $product_ref->{code}}) if $log->is_debug();

	# Create a panel only if the product has ingredients

	if ((defined $product_ref->{ingredients_tags}) and (scalar @{$product_ref->{ingredients_tags}} > 0)) {

		my $ingredient_i = 0;    # sequence number for ingredients
								 # creates each individual panels for each ingredient
		my @ingredients_panels_ids
			= create_ingredients_panels_recursive($product_ref, \$ingredient_i, 0, $product_ref->{ingredients},
			$target_lc, $target_cc, $options_ref);
		my $ingredients_list_panel_data_ref = {ingredients_panels_ids => \@ingredients_panels_ids};

		# create the panel that reference ingredients panels
		create_panel_from_json_template(
			"ingredients_list",
			"api/knowledge-panels/health/ingredients/ingredients_list.tt.json",
			$ingredients_list_panel_data_ref,
			$product_ref, $target_lc, $target_cc, $options_ref
		);

	}
	return;
}

sub create_ingredients_panels_recursive ($product_ref, $ingredient_i_ref, $level, $ingredients_ref, $target_lc,
	$target_cc, $options_ref)
{

	my @ingredients_panels_ids = ();

	foreach my $ingredient_ref (@$ingredients_ref) {

		push @ingredients_panels_ids,
			create_ingredient_panel($product_ref, $ingredient_i_ref, $level, $ingredient_ref, $target_lc, $target_cc,
			$options_ref);
		if (defined $ingredient_ref->{ingredients}) {
			push @ingredients_panels_ids,
				create_ingredients_panels_recursive($product_ref, $ingredient_i_ref, $level + 1,
				$ingredient_ref->{ingredients},
				$target_lc, $target_cc, $options_ref);
		}

	}

	return @ingredients_panels_ids;
}

sub create_ingredient_panel ($product_ref, $ingredient_i_ref, $level, $ingredient_ref, $target_lc, $target_cc,
	$options_ref)
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
		$ingredient_panel_data_ref, $product_ref, $target_lc, $target_cc, $options_ref);

	return $ingredient_panel_id;
}

1;
