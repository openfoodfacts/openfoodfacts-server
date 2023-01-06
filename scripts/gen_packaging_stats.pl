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

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Data qw/:all/;

use File::Path qw(mkpath);
use JSON::PP;
use Data::DeepAccess qw(deep_exists deep_get deep_set deep_val);

=head2 generate_packaging_stats_for_query($name, $query_ref)

Generate packaging stats for products matching a specific query.

Stats are saved in .sto format in $data_root/data/categories_stats/
and in JSON format in $www_root/data/categories_stats/

=head3 Arguments

=head4 name $name



=head4 query reference $query_ref

=cut

sub generate_packaging_stats_for_query ($name, $query_ref) {

	$query_ref->{'empty'} = {"\$ne" => 1};
	$query_ref->{'obsolete'} = {"\$ne" => 1};

	# fields to retrieve
	my $fields_ref = {
		countries_tags => 1,
		categories_tags => 1,
		packagings => 1,
	};

	my $socket_timeout_ms = 3 * 60 * 60 * 60000;    # 3 hours
	my $products_collection = get_products_collection($socket_timeout_ms);

	my $products_count = $products_collection->count_documents($query_ref);

	print STDERR "$name: $products_count products\n";

	my $cursor = $products_collection->query($query_ref)->sort({created_t => 1})->fields($fields_ref);

	$cursor->immortal(1);

	my $total = 0;

	my $packagings_stats_ref = {};

	# Go through all products
	while (my $product_ref = $cursor->next) {
		$total++;

		if ($total % 1000 == 0) {
			print STDERR "$name: $total / $products_count processed\n";
		}

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

					deep_val($packagings_stats_ref,
						("countries", $country, "categories", $category, "shapes", $shape, "materials", $material))
						+= 1;
					deep_val($packagings_stats_ref,
						("countries", $country, "categories", $category, "shapes", "all", "materials", $material))
						+= 1;
					deep_val($packagings_stats_ref,
						("countries", $country, "categories", $category, "shapes", $shape, "materials", "all"))
						+= 1;
					deep_val($packagings_stats_ref,
						("countries", $country, "categories", $category, "shapes", "all", "materials", "all"))
						+= 1;

					my @shape_parents = gen_tags_hierarchy_taxonomy("en", "packaging_shapes", $shape);
					my @material_parents = gen_tags_hierarchy_taxonomy("en", "packaging_materials", $material);

					# Also add stats to parent materials
					foreach my $material_parent (@material_parents, "all") {
						deep_val(
							$packagings_stats_ref,
							(
								"countries", $country, "categories", $category,
								"shapes", $shape, "materials_parents", $material_parent
							)
						) += 1;
						deep_val(
							$packagings_stats_ref,
							(
								"countries", $country, "categories", $category,
								"shapes", "all", "materials_parents", $material_parent
							)
						) += 1;
					}
				}
			}

		}

	}

	# Create directories for the output if they do not exist yet

	(-e "$data_root/data")
		or mkdir("$data_root/data", oct(755))
		or die("Could not create target directory $data_root/data : $!\n");
	(-e "$data_root/data/categories_stats")
		or mkdir("$data_root/data/categories_stats", oct(755))
		or die("Could not create target directory $data_root/data/categories_stats : $!\n");
	(-e "$www_root/data/categories_stats")
		or mkdir("$www_root/data/categories_stats", oct(755))
		or die("Could not create target directory $www_root/data/categories_stats : $!\n");

	# Perl structure in .sto format

	store("$data_root/data/categories_stats/categories_packagings_stats.$name.sto", $packagings_stats_ref);

	# JSON

	binmode STDOUT, ":encoding(UTF-8)";
	if (open(my $JSON, ">", "$www_root/data/categories_stats/categories_packagings_stats.$name.json")) {
		print $JSON encode_json($packagings_stats_ref);
		close($JSON);
	}

	return;
}

generate_packaging_stats_for_query("packagings-with-weights", {misc_tags => 'en:packagings-with-weights'});
generate_packaging_stats_for_query("all", {});

exit(0);

