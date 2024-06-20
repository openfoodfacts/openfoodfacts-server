#!/usr/bin/perl -w

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
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

use ProductOpener::PerlStandards;
use ProductOpener::Data qw/get_products_collection/;
use Tie::IxHash qw/tie/;

my @index_list = ();

sub add_index {
	my %index_def;
	my $t = tie %index_def, 'Tie::IxHash';

	while (@_) {
        my $field = shift;
        my $direction = shift;
		$index_def{$field} = $direction;
	}
	push(@index_list, {keys => $t, options => {background => 1}});
	return 1;
}

my $indexes = get_products_collection()->indexes;

foreach my $tag (
	'additives_tags', 'allergens_tags',
	'brands_tags', 'categories_properties_tags',
	'categories_tags', 'checkers_tags',
	'cities_tags', 'codes_tags',
	'correctors_tags', 'countries_tags',
	'creator', 'creator_tags',
	'data_quality_bugs_tags', 'data_quality_errors_tags',
	'data_quality_info_tags', 'data_quality_tags',
	'data_quality_warnings_tags', 'data_sources_tags',
	'ecoscore_tags', 'editors_tags',
	'emb_codes_tags', 'entry_dates_tags',
	'food_groups_tags', 'informers_tags',
	'ingredients_analysis_tags', 'ingredients_from_palm_oil_tags',
	'ingredients_n_tags', 'ingredients_tags',
	'ingredients_that_may_be_from_palm_oil_tags', '_keywords',
	'labels_tags', 'languages_tags',
	'last_edit_dates_tags', 'last_image_dates_tags',
	'manufacturing_places_tags', 'minerals_tags',
	'misc_tags', 'nova_groups_tags',
	'nucleotides_tags', 'nutrient_levels_tags',
	'nutrition_grades_tags', 'origins_tags',
	'owners_tags', 'packaging_tags',
	'photographers_tags', 'pnns_groups_1_tags',
	'pnns_groups_2_tags', 'popularity_tags',
	'purchase_places_tags', 'states_tags',
	'stores_tags', 'teams_tags',
	'traces_tags', 'unknown_nutrients_tags'
	)
{
	add_index($tag, 1, 'last_modified_t', -1);
}

# Note that 'vitamins_tags' index wasn't being created before due to hitting the limit so have removed for now

add_index('code', 1);
add_index('created_t', -1);
add_index('ecoscore_score', -1);
add_index('last_modified_t', -1);
add_index('nutriscore_score_opposite', -1);
add_index('popularity_key', -1);
add_index('countries_tags', 1, 'created_t', -1);
add_index('countries_tags', 1, 'popularity_key', -1);
add_index('owner', 1, 'countries_tags', 1, 'last_modified_t', -1);
$indexes->create_many(@index_list);

exit(0);

