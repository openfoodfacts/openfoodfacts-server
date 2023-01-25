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

ProductOpener::Food - functions related to food products and nutrition

=head1 DESCRIPTION

The C<ProductOpener::FoodGroups> module contains functions to determine a product
food group. Food groups are a 3 level hierarchy of groups that are used by researchers
(in particular researches from the EREN team that created the Nutri-Score).

In France, food groups are referred to as "PNNS groups" (PNNS stands for "Programme National Nutrition et Santé").

=cut

package ProductOpener::FoodGroups;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&compute_food_groups

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Store qw/:all/;
use ProductOpener::Config qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Food qw/:all/;

use Log::Any qw($log);

# Note: the %pnns structure is a hash of sub-groups (aka "PNNS groups 2") to groups (aka "PNNN groups 1").
# The structure is used by compute_pnns_groups() that will be replaced by compute_food_groups()
# The %pnns structure will be replaced by the new food_groups taxonomy.

my %pnns = (

	"Fruits" => "Fruits and vegetables",
	"Dried fruits" => "Fruits and vegetables",
	"Vegetables" => "Fruits and vegetables",
	"Soups" => "Fruits and vegetables",

	"Cereals" => "Cereals and potatoes",
	"Bread" => "Cereals and potatoes",
	"Potatoes" => "Cereals and potatoes",
	"Legumes" => "Cereals and potatoes",
	"Breakfast cereals" => "Cereals and potatoes",

	"Dairy desserts" => "Milk and dairy products",
	"Cheese" => "Milk and dairy products",
	"Ice cream" => "Milk and dairy products",
	"Milk and yogurt" => "Milk and dairy products",

	"Offals" => "Fish Meat Eggs",
	"Processed meat" => "Fish Meat Eggs",
	"Eggs" => "Fish Meat Eggs",
	"Fish and seafood" => "Fish Meat Eggs",
	"Meat" => "Fish Meat Eggs",

	"Chocolate products" => "Sugary snacks",
	"Sweets" => "Sugary snacks",
	"Biscuits and cakes" => "Sugary snacks",
	"Pastries" => "Sugary snacks",

	"Nuts" => "Salty snacks",
	"Appetizers" => "Salty snacks",
	"Salty and fatty products" => "Salty snacks",

	"Fats" => "Fat and sauces",
	"Dressings and sauces" => "Fat and sauces",

	"Pizza pies and quiches" => "Composite foods",
	"One-dish meals" => "Composite foods",
	"Sandwiches" => "Composite foods",

	"Artificially sweetened beverages" => "Beverages",
	"Unsweetened beverages" => "Beverages",
	"Sweetened beverages" => "Beverages",
	"Fruit juices" => "Beverages",
	"Fruit nectars" => "Beverages",
	"Waters and flavored waters" => "Beverages",
	"Teas and herbal teas and coffees" => "Beverages",
	"Plant-based milk substitutes" => "Beverages",

	"Alcoholic beverages" => "Alcoholic beverages",

	"unknown" => "unknown",

);

foreach my $group (keys %pnns) {
	$pnns{get_string_id_for_lang("en", $group)} = get_string_id_for_lang("en", $pnns{$group});
}

=head1 FUNCTIONS

=head2 compute_pnns_groups ( $product_ref )

Compute the PNNS groups of a product from its categories.

This function will ultimately be replaced by compute_food_groups().

For a time, we will compute both the old PNNS groups and the new food groups, so that we can compare the results.

=head3 Arguments

=head4 product reference $product_ref

=head3 Return values

=cut

sub compute_pnns_groups ($product_ref) {

	delete $product_ref->{pnns_groups_1};
	delete $product_ref->{pnns_groups_1_tags};
	delete $product_ref->{pnns_groups_2};
	delete $product_ref->{pnns_groups_2_tags};

	if ((not defined $product_ref->{categories}) or ($product_ref->{categories} eq "")) {
		$product_ref->{pnns_groups_2} = "unknown";
		$product_ref->{pnns_groups_2_tags} = ["unknown", "missing-category"];
		$product_ref->{pnns_groups_1} = "unknown";
		$product_ref->{pnns_groups_1_tags} = ["unknown", "missing-category"];
		return;
	}

	# compute PNNS groups 2 and 1

	foreach my $categoryid (reverse @{$product_ref->{categories_tags}}) {
		if (    (defined $properties{categories}{$categoryid})
			and (defined $properties{categories}{$categoryid}{"pnns_group_2:en"}))
		{

			# skip the sweetened / unsweetened if it is alcoholic
			next
				if (
				(has_tag($product_ref, 'categories', 'en:alcoholic-beverages'))
				and (  ($categoryid eq 'en:sweetened-beverages')
					or ($categoryid eq 'en:artificially-sweetened-beverages')
					or ($categoryid eq 'en:unsweetened-beverages'))
				);

			# skip the category en:sweetened-beverages if we have the category en:artificially-sweetened-beverages
			next
				if (($categoryid eq 'en:sweetened-beverages')
				and has_tag($product_ref, 'categories', 'en:artificially-sweetened-beverages'));

			# skip waters and flavored waters if we have en:artificially-sweetened-beverages or en:sweetened-beverages
			next
				if (
				(
					   ($properties{categories}{$categoryid}{"pnns_group_2:en"} eq "Waters and flavored waters")
					or ($properties{categories}{$categoryid}{"pnns_group_2:en"} eq "Teas and herbal teas and coffees")
				)

				and (  has_tag($product_ref, 'categories', 'en:sweetened-beverages')
					or has_tag($product_ref, 'categories', 'en:artificially-sweetened-beverages'))
				);

			$product_ref->{pnns_groups_2} = $properties{categories}{$categoryid}{"pnns_group_2:en"};
			$product_ref->{pnns_groups_2_tags} = [get_string_id_for_lang("en", $product_ref->{pnns_groups_2}), "known"];

			# Let waters and teas take precedence over unsweetened-beverages
			if ($properties{categories}{$categoryid}{"pnns_group_2:en"} ne "Unsweetened beverages") {
				last;
			}
		}
	}

	if (defined $product_ref->{pnns_groups_2}) {
		if (defined $pnns{$product_ref->{pnns_groups_2}}) {
			$product_ref->{pnns_groups_1} = $pnns{$product_ref->{pnns_groups_2}};
			$product_ref->{pnns_groups_1_tags} = [get_string_id_for_lang("en", $product_ref->{pnns_groups_1}), "known"];
		}
		else {
			$log->warn("no pnns group 1 for pnns group 2", {pnns_group_2 => $product_ref->{pnns_groups_2}})
				if $log->is_warn();
		}
	}
	else {
		# We have a category for the product, but no PNNS groups are associated with this category or a parent category

		$product_ref->{pnns_groups_2} = "unknown";
		$product_ref->{pnns_groups_2_tags} = ["unknown", "missing-association"];
		$product_ref->{pnns_groups_1} = "unknown";
		$product_ref->{pnns_groups_1_tags} = ["unknown", "missing-association"];
	}
	return;
}

=head2 compute_food_groups ( $product_ref )

Compute the food groups of a product from its categories.

=head3 Arguments

=head4 product reference $product_ref

=head3 Return values

The lowest level food group is stored in $product_ref->{food_group}

All levels food groups are stored in $product_ref->{food_groups_tags}

=cut

sub compute_food_groups ($product_ref) {

	$product_ref->{nutrition_score_beverage} = is_beverage_for_nutrition_score($product_ref);

	# Temporarily change categories (backup old one in original_categories_tags)
	temporarily_change_categories_for_food_groups_computation($product_ref);

	delete $product_ref->{food_groups};

	# Find the first category with a defined value for the property

	if (defined $product_ref->{categories_tags}) {
		foreach my $categoryid (reverse @{$product_ref->{categories_tags}}) {
			if (    (defined $properties{categories}{$categoryid})
				and (defined $properties{categories}{$categoryid}{"food_groups:en"}))
			{
				$product_ref->{food_groups} = $properties{categories}{$categoryid}{"food_groups:en"};
				$log->debug("found food group for category",
					{category_id => $categoryid, food_groups => $product_ref->{food_groups}})
					if $log->is_debug();
				last;
			}
		}
	}

	# Compute the food groups tags, including parents, in food_groups_tags
	$product_ref->{food_groups_tags} = [gen_tags_hierarchy_taxonomy("en", "food_groups", $product_ref->{food_groups})];

	# Compute old PNNS groups tags, for comparison.
	# Will eventually be removed.
	compute_pnns_groups($product_ref);

	# Put back the original categories_tags so that they match what is in the taxonomy field
	# if there is a mistmatch it can cause tags to be added multiple times (e.g. with imports)
	if (defined $product_ref->{original_categories_tags}) {
		$product_ref->{categories_tags} = [@{$product_ref->{original_categories_tags}}];
		delete $product_ref->{original_categories_tags};
	}
	return;
}

=head2 temporarily_change_categories_for_food_groups_computation ( $product_ref )

Food groups are derived from categories.
In order to account to some subtleties (categories in OFF are manually entered and may have a broad and imprecise scope:
e.g. what is a beverage?), this function has some rules to temporarily change categories, so that:

- only products that matche the precise definition of a beverage according to the Nutri-Score formula are counted as beverages
(e.g. a beverage with more than 80% milk is not counted as beverage)
- alcoholic beverages with less than 1% alcohol are not counted as alcoholic beverages
- beverages with sweeteners / added sugar are automatically categorized as artificially sweetened / sweetened beverages

=head3 Arguments

=head4 product reference $product_ref

=head3 Return values

Categories can be added or removed in $product_ref->{categories_tags}

Original categories are saved in $product_ref->{original_categories_tags}

=cut

sub temporarily_change_categories_for_food_groups_computation ($product_ref) {

	# Only add or remove categories tags temporarily for determining the food groups / PNNS groups
	# save the original value

	if (defined $product_ref->{categories_tags}) {
		$product_ref->{original_categories_tags} = [@{$product_ref->{categories_tags}}];
	}

	# For Open Food Facts, add special categories for beverages that are computed from
	# nutrition facts (alcoholic or not) or the ingredients (sweetened, artificially sweetened or unsweetened)
	# those tags are only added to categories_tags (searchable in Mongo)
	# and not to the categories_hierarchy (displayed on the web site and in the product edit form)
	# Those extra categories are also used to determined the French PNNS food groups

	# Note: the code below is the code that was used to compute PNNS groups.

	# A lot of it is outdated and may be simplified, especially when we completely remove PNNS groups
	# and keep only the new food groups.

	# Some of the code may also be removed if we achieve a similar effect through the upcoming product rules.

	if (    ($product_ref->{nutrition_score_beverage})
		and (not has_tag($product_ref, "categories", "en:instant-beverages")))
	{

		if (defined $product_ref->{nutriments}{"alcohol_100g"}) {
			if ($product_ref->{nutriments}{"alcohol_100g"} < 1) {
				if (has_tag($product_ref, "categories", "en:alcoholic-beverages")) {
					remove_tag($product_ref, "categories", "en:alcoholic-beverages");
				}

				if (not has_tag($product_ref, "categories", "en:non-alcoholic-beverages")) {
					add_tag($product_ref, "categories", "en:non-alcoholic-beverages");
				}
			}
			else {
				if (not has_tag($product_ref, "categories", "en:alcoholic-beverages")) {
					add_tag($product_ref, "categories", "en:alcoholic-beverages");
				}

				if (has_tag($product_ref, "categories", "en:non-alcoholic-beverages")) {
					remove_tag($product_ref, "categories", "en:non-alcoholic-beverages");
				}
			}
		}
		else {
			if (    (not has_tag($product_ref, "categories", "en:non-alcoholic-beverages"))
				and (not has_tag($product_ref, "categories", "en:alcoholic-beverages")))
			{
				add_tag($product_ref, "categories", "en:non-alcoholic-beverages");
			}
		}

		if (
			(
				   not(has_tag($product_ref, "categories", "en:alcoholic-beverages"))
				or has_tag($product_ref, "categories", "en:fruit-juices")
				or has_tag($product_ref, "categories", "en:fruit-nectars")
			)
			)
		{

			if (has_tag($product_ref, "categories", "en:sodas")
				and (not has_tag($product_ref, "categories", "en:diet-sodas")))
			{
				if (not has_tag($product_ref, "categories", "en:sweetened-beverages")) {
					add_tag($product_ref, "categories", "en:sweetened-beverages");
				}
				if (has_tag($product_ref, "categories", "en:unsweetened-beverages")) {
					remove_tag($product_ref, "categories", "en:unsweetened-beverages");
				}
			}

			if ($product_ref->{with_sweeteners}) {
				if (not has_tag($product_ref, "categories", "en:artificially-sweetened-beverages")) {
					add_tag($product_ref, "categories", "en:artificially-sweetened-beverages");
				}
				if (has_tag($product_ref, "categories", "en:unsweetened-beverages")) {
					remove_tag($product_ref, "categories", "en:unsweetened-beverages");
				}
			}

			# fix me: ingredients are now partly taxonomized

			# All the conditions below for sugars will be replaced by only 1 condition on "en:added-sugar"
			# once https://github.com/openfoodfacts/openfoodfacts-server/pull/6181 is deployed.

			if (

				(
					   has_tag($product_ref, "ingredients", "sucre")
					or has_tag($product_ref, "ingredients", "sucre-de-canne")
					or has_tag($product_ref, "ingredients", "sucre-de-canne-roux")
					or has_tag($product_ref, "ingredients", "sucre-caramelise")
					or has_tag($product_ref, "ingredients", "sucre-de-canne-bio")
					or has_tag($product_ref, "ingredients", "sucres")
					or has_tag($product_ref, "ingredients", "pur-sucre-de-canne")
					or has_tag($product_ref, "ingredients", "sirop-de-sucre-inverti")
					or has_tag($product_ref, "ingredients", "sirop-de-sucre-de-canne")
					or has_tag($product_ref, "ingredients", "sucre-bio")
					or has_tag($product_ref, "ingredients", "sucre-de-canne-liquide")
					or has_tag($product_ref, "ingredients", "sucre-de-betterave")
					or has_tag($product_ref, "ingredients", "sucre-inverti")
					or has_tag($product_ref, "ingredients", "canne-sucre")
					or has_tag($product_ref, "ingredients", "sucre-glucose-fructose")
					or has_tag($product_ref, "ingredients", "glucose-fructose-et-ou-sucre")
					or has_tag($product_ref, "ingredients", "sirop-de-glucose")
					or has_tag($product_ref, "ingredients", "glucose")
					or has_tag($product_ref, "ingredients", "sirop-de-fructose")
					or has_tag($product_ref, "ingredients", "saccharose")
					or has_tag($product_ref, "ingredients", "sirop-de-fructose-glucose")
					or has_tag($product_ref, "ingredients", "sirop-de-glucose-fructose-de-ble-et-ou-de-mais")
					or has_tag($product_ref, "ingredients", "sugar")
					or has_tag($product_ref, "ingredients", "sugars")
					or has_tag($product_ref, "ingredients", "en:sugar")
					or has_tag($product_ref, "ingredients", "en:glucose")
					or has_tag($product_ref, "ingredients", "en:fructose")
				)
				)
			{

				if (not has_tag($product_ref, "categories", "en:sweetened-beverages")) {
					add_tag($product_ref, "categories", "en:sweetened-beverages");
				}
				if (has_tag($product_ref, "categories", "en:unsweetened-beverages")) {
					remove_tag($product_ref, "categories", "en:unsweetened-beverages");
				}
			}
			else {
				# 2019-01-08: adding back the line below which was previously commented
				# add check that we do have an ingredient list
				if (
						(not has_tag($product_ref, "categories", "en:sweetened-beverages"))
					and (not has_tag($product_ref, "categories", "en:artificially-sweetened-beverages"))
					and (not has_tag($product_ref, "quality", "en:ingredients-100-percent-unknown"))
					and (not has_tag($product_ref, "quality", "en:ingredients-90-percent-unknown"))
					and (not has_tag($product_ref, "quality", "en:ingredients-80-percent-unknown"))
					and (not has_tag($product_ref, "quality", "en:ingredients-70-percent-unknown"))
					and (not has_tag($product_ref, "quality", "en:ingredients-60-percent-unknown"))
					and (not has_tag($product_ref, "quality", "en:ingredients-50-percent-unknown"))
					and

					(($product_ref->{lc} eq 'en') or ($product_ref->{lc} eq 'fr'))
					and ((defined $product_ref->{ingredients_text}) and (length($product_ref->{ingredients_text}) > 3))
					)
				{

					if (not has_tag($product_ref, "categories", "en:unsweetened-beverages")) {
						add_tag($product_ref, "categories", "en:unsweetened-beverages");
					}
				}
				else {
					# remove unsweetened-beverages category that may have been added before
					# we cannot trust it if we do not have a correct ingredients list
					if (has_tag($product_ref, "categories", "en:unsweetened-beverages")) {
						remove_tag($product_ref, "categories", "en:unsweetened-beverages");
					}
				}
			}
		}
	}
	else {
		# remove sub-categories for beverages that are not considered beverages for PNNS / Nutriscore
		if (has_tag($product_ref, "categories", "en:alcoholic-beverages")) {
			remove_tag($product_ref, "categories", "en:alcoholic-beverages");
		}
		if (has_tag($product_ref, "categories", "en:non-alcoholic-beverages")) {
			remove_tag($product_ref, "categories", "en:non-alcoholic-beverages");
		}
		if (has_tag($product_ref, "categories", "en:sweetened-beverages")) {
			remove_tag($product_ref, "categories", "en:sweetened-beverages");
		}
		if (has_tag($product_ref, "categories", "en:artificially-sweetened-beverages")) {
			remove_tag($product_ref, "categories", "en:artificially-sweetened-beverages");
		}
		if (has_tag($product_ref, "categories", "en:unsweetened-beverages")) {
			remove_tag($product_ref, "categories", "en:unsweetened-beverages");
		}
	}
	return;
}

1;
