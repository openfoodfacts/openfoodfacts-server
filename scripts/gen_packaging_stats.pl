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

=head1 NAME

gen_packaging_stats.pl - Generates aggregated data about the packaging components of products for a specific category in a specific country

=head1 DESCRIPTION

Aggregation counts are stored in a structure of the form:

{
    countries => {
        "en:world" => ..
        "en:france" => {
            categories => {
                "all" => .. # stats for all categories
                "en:yogourts" => {
                    shapes => {
                        "en:unknown" => ..
                        "all" => .. # stats for all shapes
                        "en:bottle" => {
                            materials_parents => .. # stats for parents materials (e.g. PET will also count for plastic)
                            materials => {
                                "all" => ..
                                "en:plastic" => 12, # number of products sold in France that are yogurts and that have a plastic bottle packaging component
                            }
                        },
                        ..
                    }					
                },
                ..
            }
        },
        ..
    }
}

=cut

use ProductOpener::PerlStandards;

use ProductOpener::PackagingStats qw/:all/;

generate_packaging_stats_for_query("packagings-with-weights", {misc_tags => 'en:packagings-with-weights'});
generate_packaging_stats_for_query("all", {});

exit(0);
