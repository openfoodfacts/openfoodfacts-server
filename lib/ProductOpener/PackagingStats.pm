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

ProductOpener::PackagingStats 

=head1 DESCRIPTION

Generates aggregated data about the packaging components of products for a specific category in a specific country

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

package ProductOpener::PackagingStats;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

use Log::Any qw($log);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(

		&generate_packaging_stats_for_query
		&add_product_components_to_stats
		&compute_stats_for_all_weights
		&compute_stats_for_values
		&remove_unpopular_categories_shapes_and_materials
		&remove_packagings_materials_stats_for_unpopular_categories
		&store_stats
		&export_product_packaging_components_to_csv
		&add_product_materials_to_stats
		&compute_stats_for_all_materials

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::PerlStandards;

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Data qw/:all/;
use ProductOpener::Packaging qw/:all/;

use File::Path qw(mkpath);
use JSON::PP;
use Data::DeepAccess qw(deep_exists deep_get deep_set deep_val);
use Text::CSV;

=head2 add_product_components_to_stats($name, $packagings_stats_ref, $product_ref)

Add data from all packagings of a product to stats for all its countries and categories combinations.

When $name is "packagings-with-weights", we store stats for weights, otherwise, we store only the number of products.

=cut

sub add_product_components_to_stats ($name, $packagings_stats_ref, $product_ref) {

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

Compute stats (means etc.) for packaging components, aggregated at the countries, categories, shapes and materials levels

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
								compute_stats_for_values($material_ref->{weights});
							}
						}
					}
				}
			}
		}
	}

	return;
}

=head2 compute_stats_for_values ($values_ref)

Compute stats for values (e.g. weights or percent) passed in $values_ref->{values} in comma delimited format

=cut

sub compute_stats_for_values ($values_ref) {

	# Remove trailing comma
	$values_ref->{values} =~ s/,$//;
	# Turn to array
	$values_ref->{values} = [split(/,/, $values_ref->{values})];

	$values_ref->{n} = 0;
	$values_ref->{sum} = 0;

	foreach my $value (@{$values_ref->{values}}) {
		$values_ref->{n}++;
		$values_ref->{sum} += $value;
	}

	if ($values_ref->{n} > 0) {
		$values_ref->{mean} = $values_ref->{sum} / $values_ref->{n};
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

=head2 remove_packagings_materials_stats_for_unpopular_categories ($packagings_materials_stats_ref, $min_products)

Remove packaging materials stats for categories that have less than the required amount of product.

=head3 Arguments

=head4 $packagings_materials_stats_ref

=head4 $min_products 

=cut

sub remove_packagings_materials_stats_for_unpopular_categories ($packagings_materials_stats_ref, $min_products) {

	foreach my $country_ref (values %{$packagings_materials_stats_ref->{countries}}) {
		foreach my $category (keys %{$country_ref->{categories}}) {
			if ((deep_get($country_ref, "categories", $category, "materials", "all", "n") || 0) < $min_products) {
				delete $country_ref->{categories}{$category};
			}
		}
	}

	return;
}

=head2 store_stats($name, $packagings_stats_ref, $packagings_materials_stats_ref)

Store the stats in JSON format for internal use in Product Opener and store a copy in the static web directory

=cut

sub store_stats ($name, $packagings_stats_ref, $packagings_materials_stats_ref) {

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

	# Packaging stats for packaging components
	store_json("$data_root/data/categories_stats/categories_packagings_stats.$name.json", $packagings_stats_ref);
	store_json("$www_root/data/categories_stats/categories_packagings_stats.$name.json", $packagings_stats_ref);

	# Packaging stats for products
	store_json("$data_root/data/categories_stats/categories_packagings_materials_stats.$name.json",
		$packagings_materials_stats_ref);
	store_json("$www_root/data/categories_stats/categories_packagings_materials_stats.$name.json",
		$packagings_materials_stats_ref);

	# special export for French yogurts for the "What's around my yogurt?" operation in January 2023
	# https://fr.openfoodfacts.org/categorie/desserts-lactes-fermentes/misc/en:packagings-with-weights
	store_json(
		"$www_root/data/categories_stats/categories_packagings_stats.fr.fermented-dairy-desserts.$name.json",
		$packagings_stats_ref->{countries}{"en:france"}{categories}{"en:fermented-dairy-desserts"}
	);

	return;
}

=head2 export_product_packaging_components_to_csv($csv, $filehandle, $product_ref)

Export each packaging component of the product as one line in the CSV file.

=cut

sub export_product_packaging_components_to_csv ($csv, $filehandle, $product_ref) {

	# Go through all packaging components
	if (defined $product_ref->{packagings}) {

		my $countries_tags;
		if (defined $product_ref->{countries_tags}) {
			$countries_tags = join(",", @{$product_ref->{countries_tags}});
		}

		my $categories_tags;
		if (defined $product_ref->{categories_tags}) {
			$categories_tags = join(",", @{$product_ref->{categories_tags}});
		}

		foreach my $packaging_ref (@{$product_ref->{packagings}}) {

			my $weight = $packaging_ref->{weight_specified} // $packaging_ref->{weight_measured};

			my @values = (
				$product_ref->{code}, $countries_tags,
				$categories_tags, $packaging_ref->{number_of_units},
				$packaging_ref->{shape}, $packaging_ref->{material},
				get_parent_material($packaging_ref->{material}), $packaging_ref->{recycling},
				$packaging_ref->{weight}, $packaging_ref->{weight_measured},
				$packaging_ref->{weight_specified}, $packaging_ref->{quantity_per_unit},
			);

			$csv->print($filehandle, \@values);
		}
	}

	return;
}

=head2 add_product_materials_to_stats($name, $packagings_stats_ref, $product_ref)

Add aggregated (by parent materials) data for all packagings of a product to stats for all its countries and categories combinations.

=cut

sub add_product_materials_to_stats ($name, $packagings_materials_stats_ref, $product_ref) {

	# Go through all parent materials
	if (not defined $product_ref->{packagings_materials}) {
		$product_ref->{packagings_materials} = {};
	}

	my $total_weight_100g = deep_get($product_ref, "packagings_materials", "all", "weight_100g");

	foreach my $material ("en:paper-or-cardboard", "en:plastic", "en:glass", "en:metal", "en:unknown", "all") {

		my $material_ref = $product_ref->{packagings_materials}{$material};
		# packagings_materials is of the form:
		# [parent material] -> { weight => .., weight_100g => .., weight_percent => .. }

		# Go through all countries
		foreach my $country (@{$product_ref->{countries_tags}}) {

			# Go through all categories (note: the product categories already contain all parent categories)
			foreach my $category (@{$product_ref->{categories_tags}}) {

				# Increment the number of products that have the parent material
				if (defined $material_ref) {
					deep_val($packagings_materials_stats_ref,
						("countries", $country, "categories", $category, "materials", $material, "n"))
						+= 1;
				}

				# If we have a weight percent, or a weight of packaging per 100g of product,
				# for at least one material (in which case it will be in the "all" material too)
				# then we record values for all materials (with value 0 if we don't have the material
				# or we don't have a value for the material)

				if ($total_weight_100g) {

					my $weight_100g = deep_get($product_ref, "packagings_materials", $material, "weight_100g");

					# Record if the product has the material (100) or not (0)
					deep_val(
						$packagings_materials_stats_ref,
						(
							"countries", $country, "categories", $category,
							"materials", $material, "products_percent", "values"
						)
					) .= ($weight_100g ? 100 : 0) . ",";

					# Record the weight per 100g of product, for all products, even if they don't contain the material
					# Useful to say that on average a product of a specific category has X g of glass and Y g of metal
					# even if most of them are either in glass, or in metal, but not both
					deep_val(
						$packagings_materials_stats_ref,
						(
							"countries", $country, "categories", $category,
							"materials", $material, "weight_100g", "values"
						)
					) .= ($weight_100g // 0) . ",";

					# Record the weight per 100g of product, for all products that contain the material
					# Useful to compare products that do have the material
					if (defined $weight_100g) {
						deep_val(
							$packagings_materials_stats_ref,
							(
								"countries", $country, "categories", $category,
								"materials", $material, "weight_100g_material", "values"
							)
						) .= $weight_100g . ",";
					}
				}
			}
		}
	}

	return;
}

=head2 compute_stats_for_all_materials ($packagings_materials_stats_ref)

Compute stats (means etc.) for packaging materials, aggregated at the countries, categories and materials levels

=cut

sub compute_stats_for_all_materials ($packagings_materials_stats_ref, $delete_values = 1) {

	foreach my $country_ref (values %{$packagings_materials_stats_ref->{countries}}) {
		foreach my $category_ref (values %{$country_ref->{categories}}) {
			foreach my $material_ref (values %{$category_ref->{materials}}) {
				foreach my $field ("products_percent", "weight_100g", "weight_100g_material") {
					if (defined $material_ref->{$field}) {
						# Compute stats
						compute_stats_for_values($material_ref->{$field});
						# Delete individual values
						if ($delete_values) {
							delete $material_ref->{$field}{values};
						}
					}
				}
			}
		}
	}

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

sub generate_packaging_stats_for_query ($name, $query_ref, $quiet = 0) {

	# we will filter out empty and obsolete products
	$query_ref->{'empty'} = {"\$ne" => 1};
	$query_ref->{'obsolete'} = {"\$ne" => 1};

	# fields to retrieve
	my $fields_ref = {
		code => 1,
		countries_tags => 1,
		categories_tags => 1,
		packagings => 1,
		packagings_materials => 1,
		product_quantity => 1,
	};

	my $socket_timeout_ms = 3 * 60 * 60 * 60000;    # 3 hours
	my $products_collection = get_products_collection({timeout => $socket_timeout_ms});

	my $products_count = $products_collection->count_documents($query_ref);

	$quiet or print STDERR "$name: $products_count products\n";

	my $cursor = $products_collection->query($query_ref)->sort({created_t => 1})->fields($fields_ref);

	$cursor->immortal(1);

	my $total = 0;

	my $packagings_stats_ref
		= {};    # Stats for shapes and materials, with input at the level of each packaging component of each product
	my $packagings_materials_stats_ref = {};    # Stats for parent materials, with input at the level of each product

	# Export packaging components of all products to a CSV file
	my $filehandle;
	my $filename = "$www_root/data/$name.csv";
	open($filehandle, ">:encoding(UTF-8)", $filename)
		or die("Could not write " . $filename . " : $!\n");
	my $csv = Text::CSV->new(
		{
			eol => "\n",
			sep => "\t",
			quote_space => 0,
			binary => 1
		}
	) or die "Cannot use CSV: " . Text::CSV->error_diag();

	# Print the header line with fields names
	$csv->print(
		$filehandle,
		[
			"code", "countries_tags", "categories_tags", "number_of_units",
			"shape", "material", "parent_material", "recycling",
			"weight", "weight_measured", "weight_specified", "quantity_per_unit"
		]
	);

	# Go through all products
	while (my $product_ref = $cursor->next) {
		$total++;

		if ($total % 1000 == 0) {
			$quiet or print STDERR "$name: $total / $products_count processed\n";
		}
		export_product_packaging_components_to_csv($csv, $filehandle, $product_ref);

		# Generate stats for all countries + en:world (products from all countries)
		# add a virtual en:world country to every product
		if (not defined $product_ref->{countries_tags}) {
			$product_ref->{countries_tags} = [];
		}
		push @{$product_ref->{countries_tags}}, "en:world";

		# Generate stats for all categories + all (products from all categories)
		if (not defined $product_ref->{categories_tags}) {
			$product_ref->{categories_tags} = [];
		}
		push @{$product_ref->{categories_tags}}, "all";

		add_product_components_to_stats($name, $packagings_stats_ref, $product_ref);

		add_product_materials_to_stats($name, $packagings_materials_stats_ref, $product_ref);
	}

	if ($name eq "packagings-with-weights") {
		# Compute stats for weights
		compute_stats_for_all_weights($packagings_stats_ref);
	}

	# Compute stats for materials
	compute_stats_for_all_materials($packagings_materials_stats_ref);

	store_stats($name, $packagings_stats_ref, $packagings_materials_stats_ref);

	# Compute smaller stats where we keep only shapes and materials that are popular
	# This data is used for autocomplete suggestions in ProductOpener::APITaxonomySuggestions

	remove_unpopular_categories_shapes_and_materials($packagings_stats_ref, 5);
	remove_packagings_materials_stats_for_unpopular_categories($packagings_materials_stats_ref, 5);
	store_stats($name . ".popular", $packagings_stats_ref, $packagings_materials_stats_ref);

	return;
}

1;

