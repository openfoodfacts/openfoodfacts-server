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
use Getopt::Long;

my $quiet;

GetOptions("quiet" => \$quiet)
	or die("Error in command line arguments: use --quiet to silence progress messages");

=head2 add_product_to_stats($name, $packagings_stats_ref, $product_ref)

Add data from all packagings of a product to stats for all its countries and categories combinations.

When $name is "packagings-with-weights", we store stats for weights, otherwise, we store only the number of products.

=cut

sub add_product_to_stats ($name, $packagings_stats_ref, $product_ref) {

	# Generate stats for all countries + en:world (products from all countries)
	# add a virtual en:world country to every products
	if (not defined $product_ref->{countries_tags}) {
		$product_ref->{countries_tags} = [];
	}
	push @{$product_ref->{countries_tags}}, "en:world";

	# Generate stats for all categories + all (products from all categories)
	if (not defined $product_ref->{categories_tags}) {
		$product_ref->{categories_tags} = [];
	}
	push @{$product_ref->{categories_tags}}, "all";

	# Go through all packaging components
	if (not defined $product_ref->{packagings}) {
		$product_ref->{packagings} = [];
	}

	foreach my $packaging_ref (@{$product_ref->{packagings}}) {
		my $shape = $packaging_ref->{shape} || "en:unknown";
		my $material = $packaging_ref->{material} || "en:unknown";
		my $weight = $packaging_ref->{weight_measured};

		my @shape_parents = gen_tags_hierarchy_taxonomy("en", "packaging_shapes", $shape);
		my @material_parents = gen_tags_hierarchy_taxonomy("en", "packaging_materials", $material);

		# We will generate stats for both shapes and shapes parents
		my @shapes_or_shapes_parents = (["shapes", [$shape, "all"]], ["shapes_parents", [@shape_parents, "all"]]);

		# We will generate stats for both materials and materials parents
		my @materials_or_materials_parents
			= (["materials", [$material, "all"]], ["materials_parents", [@material_parents, "all"]]);

		# Go through all countries
		foreach my $country (@{$product_ref->{countries_tags}}) {

			# Go through all categories (note: the product categories already contain all parent categories)
			foreach my $category (@{$product_ref->{categories_tags}}) {

				deep_val($packagings_stats_ref, ("countries", $country, "categories", $category, "n")) += 1;

				# Compute stats for shapes + shapes parents
				foreach my $shapes_or_shapes_parents_ref (@shapes_or_shapes_parents) {
					my ($shapes_or_shapes_parents, $shapes_ref) = @$shapes_or_shapes_parents_ref;

					foreach my $shape_value (@$shapes_ref) {

						deep_val(
							$packagings_stats_ref,
							(
								"countries", $country, "categories", $category,
								$shapes_or_shapes_parents, $shape_value, "n"
							)
						) += 1;

						# Compute stats for materials + materials parents
						foreach my $materials_or_materials_parents_ref (@materials_or_materials_parents) {
							my ($materials_or_materials_parents, $materials_ref) = @$materials_or_materials_parents_ref;

							foreach my $material_value (@$materials_ref) {

								deep_val(
									$packagings_stats_ref,
									(
										"countries", $country,
										"categories", $category,
										$shapes_or_shapes_parents, $shape_value,
										$materials_or_materials_parents, $material_value,
										"n"
									)
								) += 1;
								if (($name eq "packagings-with-weights") and (defined $weight)) {
									deep_val(
										$packagings_stats_ref,
										(
											"countries", $country,
											"categories", $category,
											$shapes_or_shapes_parents, $shape_value,
											$materials_or_materials_parents, $material_value,
											"weights", "values"
										)
									) .= $weight . ',';
								}
							}
						}
					}
				}
			}
		}
	}

	return;
}

=head2 compute_stats_for_all_weights ($packagings_stats_ref)

Add data from all packagings of a product to stats for all its countries and categories combinations.

=cut

sub compute_stats_for_all_weights ($packagings_stats_ref) {

	# Individual weights are stored in a nested hash with this structure:
	# ("countries", $country, "categories", $category, $shapes_or_shapes_parents, $shape_value, $materials_or_materials_parents, $material_value, "weights", "values"))

	foreach my $country_ref (values %{$packagings_stats_ref->{countries}}) {
		foreach my $category_ref (values %{$country_ref->{categories}}) {
			foreach my $shapes_or_shapes_parents ("shapes", "shapes_parents") {
				my $shapes_or_shapes_parents_ref = $category_ref->{$shapes_or_shapes_parents};
				foreach my $shape_ref (values %$shapes_or_shapes_parents_ref) {
					foreach my $materials_or_materials_parents ("materials", "materials_parents") {
						my $materials_or_materials_parents_ref = $shape_ref->{$materials_or_materials_parents};
						foreach my $material_ref (values %$materials_or_materials_parents_ref) {
							if (defined $material_ref->{weights}) {
								compute_stats_for_weights($material_ref->{weights});
							}
						}
					}
				}
			}
		}
	}

	return;
}

=head2 compute_stats_for_weights ($weights_ref)

Compute stats for weight values passed in $weights_ref->{values} in comma delimited format

=cut

sub compute_stats_for_weights ($weights_ref) {

	# Remove trailing comma
	$weights_ref->{values} =~ s/,$//;
	# Turn to array
	$weights_ref->{values} = [split(/,/, $weights_ref->{values})];

	$weights_ref->{n} = 0;
	$weights_ref->{sum} = 0;

	foreach my $value (@{$weights_ref->{values}}) {
		$weights_ref->{n}++;
		$weights_ref->{sum} += $value;
	}

	if ($weights_ref->{n} > 0) {
		$weights_ref->{mean} = $weights_ref->{sum} / $weights_ref->{n};
	}

	return;
}

=head2 remove_unpopular_categories_shapes_and_materials ($packagings_stats_ref, $min_products)

Remove stats for categories, shapes, and materials that have less than the required amount of product.

This is necessary to generate a smaller dataset that can be used to generate autocomplete suggestions
for packaging shapes and materials, given a country and a list of categories of the product.

Also remove shapes_parents and materials_parents

=head3 Arguments

=head4 $packagings_stats_ref

=head4 $min_products 

=cut

sub remove_unpopular_categories_shapes_and_materials ($packagings_stats_ref, $min_products) {

	foreach my $country_ref (values %{$packagings_stats_ref->{countries}}) {
		foreach my $category (keys %{$country_ref->{categories}}) {
			if ($country_ref->{categories}{$category}{n} < $min_products) {
				delete $country_ref->{categories}{$category};
				next;
			}
			my $category_ref = $country_ref->{categories}{$category};
			delete $category_ref->{shapes_parents};
			my $shapes_ref = $category_ref->{shapes};
			foreach my $shape (keys %$shapes_ref) {
				if ($shapes_ref->{$shape}{n} < $min_products) {
					delete $shapes_ref->{$shape};
					next;
				}
				my $shape_ref = $shapes_ref->{$shape};
				delete $shape_ref->{materials_parents};
				my $materials_ref = $shape_ref->{materials};
				foreach my $material (keys %$materials_ref) {
					if ($materials_ref->{$material}{n} < $min_products) {
						delete $materials_ref->{$material};
					}
				}
			}
		}
	}

	return;
}

=head2 store_stats($name, $packagings_stats_ref)

Store the stats in JSON format for internal use in Product Opener and store a copy in the static web directory

=cut

sub store_stats ($name, $packagings_stats_ref) {

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

	store_json("$data_root/data/categories_stats/categories_packagings_stats.$name.json", $packagings_stats_ref);

	store_json("$www_root/data/categories_stats/categories_packagings_stats.$name.json", $packagings_stats_ref);

	# special export for French yogurts for the "What's around my yogurt?" operation in January 2023
	# https://fr.openfoodfacts.org/categorie/desserts-lactes-fermentes/misc/en:packagings-with-weights
	store_json(
		"$www_root/data/categories_stats/categories_packagings_stats.fr.fermented-dairy-desserts.$name.json",
		$packagings_stats_ref->{countries}{"en:france"}{categories}{"en:fermented-dairy-desserts"}
	);

	return;
}

=head2 generate_packaging_stats_for_query($name, $query_ref)

Generate packaging stats for products matching a specific query.

Stats are saved in .json format in $data_root/data/categories_stats/
and in JSON format in $www_root/data/categories_stats/

=head3 Arguments

=head4 name $name

=head4 query reference $query_ref

=cut

sub generate_packaging_stats_for_query ($name, $query_ref) {

	# we will filter out empty and obsolete products
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

	$quiet or print STDERR "$name: $products_count products\n";

	my $cursor = $products_collection->query($query_ref)->sort({created_t => 1})->fields($fields_ref);

	$cursor->immortal(1);

	my $total = 0;

	my $packagings_stats_ref = {};

	# Go through all products
	while (my $product_ref = $cursor->next) {
		$total++;

		if ($total % 1000 == 0) {
			$quiet or print STDERR "$name: $total / $products_count processed\n";
		}

		add_product_to_stats($name, $packagings_stats_ref, $product_ref);
	}

	if ($name eq "packagings-with-weights") {
		# Compute stats for weights
		compute_stats_for_all_weights($packagings_stats_ref);
	}

	store_stats($name, $packagings_stats_ref);

	if ($name eq "all") {
		# Compute smaller stats where we keep only shapes and materials that are popular
		# This data is used for autocomplete suggestions in ProductOpener::APITaxonomySuggestions

		remove_unpopular_categories_shapes_and_materials($packagings_stats_ref, 5);
		store_stats($name . ".popular", $packagings_stats_ref);
	}

	return;
}

generate_packaging_stats_for_query("packagings-with-weights", {misc_tags => 'en:packagings-with-weights'});
generate_packaging_stats_for_query("all", {});

exit(0);
