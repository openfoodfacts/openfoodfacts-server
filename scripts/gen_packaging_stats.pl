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
                            materials_inherited => .. # stats for inherited (parents) materials (e.g. plastic for PET)
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

use Modern::Perl '2017';
use utf8;

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Data qw/:all/;

use File::Path qw(mkpath);
use JSON::PP;
use Data::DeepAccess qw(deep_exists deep_get deep_set deep_val);

# Output will be in the $data_root/data/categories_stats directory

(-e "$data_root/data")
	or mkdir("$data_root/data", oct(755))
	or die("Could not create target directory $data_root/data : $!\n");
(-e "$data_root/data/categories_stats")
	or mkdir("$data_root/data/categories_stats", oct(755))
	or die("Could not create target directory $data_root/data/categories_stats : $!\n");

my $query_ref = {'empty' => {"\$ne" => 1}, 'obsolete' => {"\$ne" => 1}};

$query_ref->{misc_tags} = 'en:packagings-with-weights';

my $fields_ref = {
    countries_tags => 1,
    categories_tags => 1,
    packagings => 1,
};

# 300 000 ms timeout so that we can export the whole database
# 5mins is not enough, 50k docs were exported
my $cursor = get_products_collection(3 * 60 * 60 * 1000)->query($query_ref)
	->sort({created_t => 1})->fields($fields_ref);

$cursor->immortal(1);

my $total = 0;

my $packagings_stats_ref = {};

# Go through all products
while (my $product_ref = $cursor->next) {
	$total++;

    # Generate stats for all countries + en:world (products from all countries)
    if (not defined $product_ref->{countries_tags}) {
        $product_ref->{countries_tags} = [];
    }
    push @{$product_ref->{countries_tags}}, "en:world";

    foreach my $country (@{$product_ref->{countries_tags}}) {

        # Generate stats for all categories + all (products from all categories)
        if (not defined $product_ref->{categories_tags}) {
            $product_ref->{categories_tags} = [];
        }
        push @{$product_ref->{categories_tags}}, "all";

        foreach my $category (@{$product_ref->{categories_tags}}) {

            # Go through all packaging components
            if (not defined $product_ref->{packagings}) {
                $product_ref->{packagings} = [];
            }

            foreach my $packaging_ref (@{$product_ref->{packagings}}) {
                my $shape = $packaging_ref->{shape} || "en:unknown";
                my $material = $packaging_ref->{material} || "en:unknown";
                deep_val($packagings_stats_ref, ("countries", $country, "categories", $category, "shapes", $shape, "materials", $material )) += 1;
                deep_val($packagings_stats_ref, ("countries", $country, "categories", $category, "shapes", "all", "materials", $material )) += 1;
                deep_val($packagings_stats_ref, ("countries", $country, "categories", $category, "shapes", $shape, "materials", "all" )) += 1;
                deep_val($packagings_stats_ref, ("countries", $country, "categories", $category, "shapes", "all", "materials", "all" )) += 1;
            }
        }

    }

}

store("$data_root/data/categories_stats/categories_packagings_stats.sto", $packagings_stats_ref);

binmode STDOUT, ":encoding(UTF-8)";
if (open(my $JSON, ">", "$www_root/data/categories_packagings_stats.json")) {
    print $JSON encode_json($packagings_stats_ref);
    close($JSON);
}

exit(0);

