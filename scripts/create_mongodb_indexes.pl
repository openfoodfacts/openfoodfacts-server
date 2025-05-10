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

my @index_list = ();

sub add_index {
	push(@index_list, \@_);
	return 1;
}

add_index('_keywords', 1, 'last_modified_t', -1);
add_index('_keywords', 1, 'unique_scans_n', -1);
add_index('additives_tags', 1, 'last_modified_t', -1);
add_index('allergens_tags', 1, 'last_modified_t', -1);
add_index('amino_acids_tags', 1, 'last_modified_t', -1);
add_index('brands_tags', 1, 'last_modified_t', -1);
add_index('categories_properties_tags', 1, 'last_modified_t', -1);
add_index('categories_tags', 1, 'last_modified_t', -1);
add_index('checkers_tags', 1, 'last_modified_t', -1);
add_index('cities_tags', 1, 'last_modified_t', -1);
add_index('code', 1);
add_index('codes_tags', 1, 'last_modified_t', -1);
add_index('correctors_tags', 1, 'last_modified_t', -1);
add_index('countries_tags', 1, 'created_t', -1);
add_index('countries_tags', 1, 'last_modified_t', -1);
add_index('countries_tags', 1, 'popularity_key', -1);
add_index('countries_tags', 1, 'sortkey', -1);
add_index('created_t', 1);
add_index('creator', 1, 'last_modified_t', -1);
add_index('data_quality_bugs_tags', 1, 'last_modified_t', -1);
add_index('data_quality_errors_tags', 1, 'last_modified_t', -1);
add_index('data_quality_info_tags', 1, 'last_modified_t', -1);
add_index('data_quality_tags', 1, 'last_modified_t', -1);
add_index('data_quality_warnings_tags', 1, 'last_modified_t', -1);
add_index('data_sources_tags', 1, 'last_modified_t', -1);
add_index('debug_tags', 1, 'last_modified_t', -1);
add_index('environmental_score_score', -1);
add_index('environmental_score_tags', 1, 'last_modified_t', -1);
add_index('editors_tags', 1, 'last_modified_t', -1);
add_index('emb_codes_tags', 1, 'last_modified_t', -1);
add_index('entry_dates_tags', 1, 'last_modified_t', -1);
add_index('food_groups_tags', 1, 'last_modified_t', -1);
add_index('informers_tags', 1, 'last_modified_t', -1);
add_index('ingredients_analysis_tags', 1, 'last_modified_t', -1);
add_index('ingredients_from_palm_oil_tags', 1, 'last_modified_t', -1);
add_index('ingredients_tags', 1, 'last_modified_t', -1);
add_index('labels_tags', 1, 'last_modified_t', -1);
add_index('languages_tags', 1, 'last_modified_t', -1);
add_index('last_edit_dates_tags', 1, 'last_modified_t', -1);
add_index('last_modified_t', -1);
add_index('lc', 1);
add_index('manufacturing_places_tags', 1, 'last_modified_t', -1);
add_index('minerals_tags', 1, 'last_modified_t', -1);
add_index('misc_tags', 1, 'last_modified_t', -1);
add_index('nova_groups_tags', 1, 'last_modified_t', -1);
add_index('nucleotides_tags', 1, 'last_modified_t', -1);
add_index('nutriscore_score_opposite', -1);
add_index('nutrition_grades_tags', 1, 'last_modified_t', -1);
add_index('origins_tags', 1, 'last_modified_t', -1);
add_index('other_nutritional_substances_tags', 1, 'last_modified_t', -1);
add_index('owners_tags', 1, 'last_modified_t', -1);
add_index('packaging_tags', 1, 'last_modified_t', -1);
add_index('photographers_tags', 1, 'last_modified_t', -1);
add_index('popularity_key', -1);
add_index('popularity_tags', 1, 'last_modified_t', -1);
add_index('purchase_places_tags', 1, 'last_modified_t', -1);
add_index('states_tags', 1, 'last_modified_t', -1);
add_index('stores_tags', 1, 'last_modified_t', -1);
add_index('teams_tags', 1, 'last_modified_t', -1);
add_index('traces_tags', 1, 'last_modified_t', -1);
add_index('unique_scans_n', -1);
add_index('users_tags', 1, 'last_modified_t', -1);
add_index('vitamins_tags', 1, 'last_modified_t', -1);

# The following were found in this file but are not in production
# If any need to be added then a corresponding number of the above must be removed

#add_index('creator_tags', 1, 'last_modified_t', -1);
#add_index('ingredients_n_tags', 1, 'last_modified_t', -1);
#add_index('ingredients_that_may_be_from_palm_oil_tags', 1, 'last_modified_t', -1);
#add_index('last_image_dates_tags', 1, 'last_modified_t', -1);
#add_index('nutrient_levels_tags', 1, 'last_modified_t', -1);
#add_index('pnns_groups_1_tags', 1, 'last_modified_t', -1);
#add_index('pnns_groups_2_tags', 1, 'last_modified_t', -1);
#add_index('unknown_nutrients_tags', 1, 'last_modified_t', -1);
#add_index('owner', 1, 'countries_tags', 1, 'last_modified_t', -1);

die "Cannot have more than 63 indexes" if (@index_list > 63);

# Note need to disable timeout below as index creation can take a long time
my $indexes = get_products_collection({timeout => 0})->indexes;

# Drop indexes not in the list
my $result = $indexes->list;
while (my $existing_index = $result->next) {
	next if ($existing_index->{'name'} eq '_id_');
	my $existing_keys = join(',', %{$existing_index->{'key'}});
	my $match = 0;
	foreach my $new_index (@index_list) {
		my $new_keys = join(',', @{$new_index});
		if ($new_keys eq $existing_keys) {
			$match = 1;
			# Remove from list if already exists
			@index_list = grep {$_ != $new_index} @index_list;
			last;
		}
	}
	if (!$match) {
		print "Dropping index: $existing_index->{'name'}\n";
		# Note, this will fail if another index is still being built
		$indexes->drop_one($existing_index->{'name'});
	}
}

foreach my $new_index (@index_list) {
	my $new_keys = join(',', @{$new_index});
	print "Creating index: $new_keys\n";
	eval {
		$indexes->create_one($new_index, {background => 1});
		1;
	} or do {
		# Timeouts are expected on large databases. The index build will continue in the background
		if ($@ !~ m/MongoDB::NetworkTimeout/) {
			print "$@\n";
		}
	}
}

exit(0);
