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

sub single_index($field, $direction) {
	my %index_def;
	my $t = tie %index_def, 'Tie::IxHash';
 
	$index_def{$field} = $direction;
	return { keys => $t, options => { background => 1 } }
}

sub dual_index($field1, $direction1, $field2, $direction2) {
	my %index_def;
	my $t = tie %index_def, 'Tie::IxHash';
 
	$index_def{$field1} = $direction1;
	$index_def{$field2} = $direction2;
	return { keys => $t, options => { background => 1 } }
}

sub triple_index($field1, $direction1, $field2, $direction2, $field3, $direction3) {
	my %index_def;
	my $t = tie %index_def, 'Tie::IxHash';
 
	$index_def{$field1} = $direction1;
	$index_def{$field2} = $direction2;
	$index_def{$field3} = $direction3;
	return { keys => $t, options => { background => 1 } }
}

my $indexes = get_products_collection()->indexes;

my @index_list = ();
foreach my $tag (
		'additives_tags',
		'allergens_tags',
		'brands_tags',
		'categories_properties_tags',
		'categories_tags',
		'checkers_tags',
		'cities_tags',
		'codes_tags',
		'correctors_tags',
		'countries_tags',
		'creator',
		'creator_tags',
		'data_quality_bugs_tags',
		'data_quality_errors_tags',
		'data_quality_info_tags',
		'data_quality_tags',
		'data_quality_warnings_tags',
		'data_sources_tags',
		'ecoscore_tags',
		'editors_tags',
		'emb_codes_tags',
		'entry_dates_tags',
		'food_groups_tags',
		'informers_tags',
		'ingredients_analysis_tags',
		'ingredients_from_palm_oil_tags',
		'ingredients_n_tags',
		'ingredients_tags',
		'ingredients_that_may_be_from_palm_oil_tags',
		'_keywords',
		'labels_tags',
		'languages_tags',
		'last_edit_dates_tags',
		'last_image_dates_tags',
		'manufacturing_places_tags',
		'minerals_tags',
		'misc_tags',
		'nova_groups_tags',
		'nucleotides_tags',
		'nutrient_levels_tags',
		'nutrition_grades_tags',
		'origins_tags',
		'owners_tags',
		'packaging_tags',
		'photographers_tags',
		'pnns_groups_1_tags',
		'pnns_groups_2_tags',
		'popularity_tags',
		'purchase_places_tags',
		'states_tags',
		'stores_tags',
		'teams_tags',
		'traces_tags',
		'unknown_nutrients_tags'
	) {
	push(@index_list, dual_index( $tag, 1, 'last_modified_t' , -1));
}
# Note that 'vitamins_tags' index wasn't being created before due to hitting the limit so have removed for now

push(@index_list, single_index( 'code', 1));
push(@index_list, single_index( 'created_t', -1));
push(@index_list, single_index( 'ecoscore_score', -1));
push(@index_list, single_index( 'last_modified_t', -1));
push(@index_list, single_index( 'nutriscore_score_opposite', -1));
push(@index_list, single_index( 'popularity_key', -1));
push(@index_list, dual_index( 'countries_tags', 1, 'created_t', -1));
push(@index_list, dual_index( 'countries_tags', 1, 'popularity_key', -1));
push(@index_list, triple_index('owner', 1, 'countries_tags', 1, 'last_modified_t', -1));

$indexes->create_many( @index_list);

exit(0);

