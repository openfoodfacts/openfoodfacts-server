# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2020 Association Open Food Facts
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

ProductOpener::ForestFootprint - compute the forest footprint of a food product

=head1 SYNOPSIS

C<ProductOpener::Ecoscore> is used to compute the forest footprint of a food product.

=head1 DESCRIPTION

The modules implements the forest footprint computation as defined by the French NGO Envol Vert.

The computation is based on the amount of soy needed to produce the ingredients,
and the risk that thay soy contributed to deforestation.

=cut

package ProductOpener::ForestFootprint;

use utf8;
use Modern::Perl '2017';
use Exporter    qw< import >;

use Log::Any qw($log);

BEGIN
{
	use vars       qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(

		&load_forest_footprint_data
		&compute_forest_footprint

		);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;

use ProductOpener::Config qw/:all/;
use ProductOpener::Tags qw/:all/;

use Storable qw(dclone freeze);
use Text::CSV();

my %forest_footprint_data = (ingredients => []);

=head1 FUNCTIONS

=head2 load_forest_footprint_data ()

Loads data needed to compute the forest footprint.

=cut

sub load_forest_footprint_data() {

	my $errors = 0;

	my $csv_options_ref = { binary => 1, sep_char => "," };    # should set binary attribute.
	my $csv = Text::CSV->new ( $csv_options_ref )
		or die("Cannot use CSV: " . Text::CSV->error_diag ());
		
	my $csv_file = $data_root . "/forest-footprint/envol-vert/Empreinte Forêt - Envol Vert - OFF.csv.0";
	my $encoding = "UTF-8";
	
	$log->debug("opening forest footprint CSV file", { file => $csv_file }) if $log->is_debug();
	
	my @rows = ();

	if (open (my $io, "<:encoding($encoding)", $csv_file)) {

		my $row_ref;

		# Load the complete file as the data for each ingredient is in columns and not in rows

		while ($row_ref = $csv->getline ($io)) {
			
			push @rows, $row_ref;
		}
		
		# 1st column: title
		# 2nd column: unit
		# Each of the following columns contains data for a specific ingredient type with specific conditions on categories, labels, origins etc.
		# The 3rd column is the most generic (e.g. "chicken"), and the columns on the right are the most specific (e.g. "organic chicken with AB label")
		
		# We are going to create an array of ingredient types starting with the ones that are the most on the right,
		# as we can select them and stop matching if their conditions are met.
		
		my @types = ();
		my $errors = 0;
		
		for (my $i = scalar(@{$rows[0]}) - 1; $i >= 2; $i--) {
			
			my %type = (
				name => $rows[0][$i],
				transformation_factor => $rows[5][$i],
				soy_feed_factor => $rows[6][$i],
				soy_yield => $rows[7][$i],
				deforestation_risk => $rows[8][$i],
				conditions => [],
			);
			
			# Conditions are on 2 lines, each of the form:
			# [tagtype]_[language code]:[tag value],[tag value..] ; [other tagtype values]
			# e.g. "labels_fr:volaille française,igp,aop,poulet français ; origins_fr:france"
			foreach my $j (2,3) {
				next if $rows[$j][$i] eq "";
				
				my @tags = ();
				
				foreach my $tagtype_values (split(/;/, $rows[$j][$i])) {
					if ($tagtype_values =~ /(\S+)_([a-z][a-z]):(.*)/) {
						my ($tagtype, $language, $values) = ($1, $2, $3);
						
						foreach my $value (split(/,/, $values)) {
							my $tagid = canonicalize_taxonomy_tag($language, $tagtype, $value);
							
							if (not exists_taxonomy_tag($tagtype, $tagid)) {
							
								$log->error("forest footprint condition does not exist in taxonomy", { tagtype => $tagtype, tagid => $tagid}) if $log->is_error();
								$errors++;
							}
							else {
								push @tags, [$tagtype, $tagid];
							}
						}
					}
				}
				
				if (scalar @tags > 0) {
					push @{$type{conditions}}, \@tags;
				}
			}
			
			push @types, \%type;
		}
		
		my $ingredients_category_data_ref = { category => "chicken", ingredients => ["en:chicken"], types => \@types };
		
		push @{$forest_footprint_data{ingredients_categories}}, $ingredients_category_data_ref;

		$log->debug("forest footprint CSV data", { csv_file => $csv_file, ingredients_category_data_ref => $ingredients_category_data_ref }) if $log->is_debug();
		
		if ($errors) {
			#die("$errors unrecognized tags in CSV $csv_file");
		}
	}
	else {
		die("Could not open forest footprint CSV $csv_file: $!");
	}
}



=head2 compute_forest_footprint ( $product_ref )

C<compute_forest_footprint()> computes the forest footprint of a food product, and stores the details of the computation.

=head3 Arguments

=head4 Product reference $product_ref

=head3 Return values

The forest footprint and computations details are stored in the product reference passed as input parameter.

Returned values:

- ecoscore_score : numeric Eco-Score value
- ecoscore_grade : corresponding A to E grade
- forest_footprint_data : forest footprint computation details

=cut

sub compute_forest_footprint($) {

	my $product_ref = shift;
	
	$product_ref->{forest_footprint_data} = {
		ingredients => [],
	};
	
	if (defined $product_ref->{ingredients}) {
		$product_ref->{forest_footprint_data}{ingredients} = [];
		compute_footprints_of_ingredients($product_ref->{forest_footprint_data}{ingredients}, $product_ref->{ingredients});
	}
}


=head2 compute_footprints_of_ingredients ( $footprints_ref, $ingredients_ref )

Computes the forest footprints of the ingredients.

The function is recursive and may call itself for sub-ingredients.

=head3 Arguments

=head4 Footprints reference $footprints_ref

Data structure to which we will add the forest footprints for the ingredients specified in $ingredients_ref

=head4 Ingredients reference $ingredients_ref

Ingredients reference that may contains an ingredients structure for sub-ingredients.

=head3 Return values

The footprints are stored in $footprints_ref

=cut

sub compute_footprints_of_ingredients($$);

sub compute_footprints_of_ingredients($$) {
	
	my $footprints_ref = shift;
	my $ingredients_ref = shift;
	
	# The ingredients array contains sub-ingredients in nested ingredients properties
	# and they are also listed at the end on the ingredients array, without the rank property
	# For this aggregation, we want to use the nested sub-ingredients,
	# and ignore the same sub-ingredients listed at the end
	my $ranked = 0;
	
	foreach my $ingredient_ref (@$ingredients_ref) {
		
		my $ingredient_origins_ref;
		
		# If we are at the first level of the ingredients array,
		# ingredients have a rank, except the sub-ingredients listed at the end
		if ($ingredient_ref->{rank}) {
			$ranked = 1;
		}
		elsif ($ranked) {
			# The ingredient does not have a rank, but a previous ingredient had one:
			# we are at the first level of the ingredients array,
			# and we are at the end where the sub-ingredients have been added
			last;
		}
		
		# Check if the ingredient belongs to one of the ingredients categories for which their is a forest footprint
		
		$log->debug("compute_footprints_of_ingredients - checking ingredient match", { ingredient_id => $ingredient_ref->{id} }) if $log->is_debug();		
		
		my $current_ingredient_category;
		
		foreach my $ingredients_category_ref (@{$forest_footprint_data{ingredients_categories}}) {
			
			$log->debug("compute_footprints_of_ingredients - checking ingredient match - category", { ingredient_id => $ingredient_ref->{id}, category => $ingredients_category_ref->{category} }) if $log->is_debug();
			
			foreach my $category_ingredient_id (@{$ingredients_category_ref->{ingredients}}) {
				
				$log->debug("compute_footprints_of_ingredients - checking ingredient match - category - category_ingredient", { ingredient_id => $ingredient_ref->{id}, category_ingredient_id => $category_ingredient_id }) if $log->is_debug();
				
				if (is_a("ingredients", $ingredient_ref->{id}, $category_ingredient_id)) {
					$log->debug("compute_footprints_of_ingredients - ingredient match", { ingredient_id => $ingredient_ref->{id}, category_ingredient_id => $category_ingredient_id }) if $log->is_debug();
					
					my $footprint_ref = {
						category => $ingredients_category_ref->{category},
						category_ingredient_id => $category_ingredient_id,
						ingredient_id => $ingredient_ref->{id},
					};
					
					push @$footprints_ref, $footprint_ref;
					
					last;
				}
			}
			
			if (defined $current_ingredient_category) {
				last;
			}
		}
		
		# If the ingredient does not belong to one of the ingredients categories with a forest footprint
		# try the sub ingredients
		if ((not defined $current_ingredient_category) and (defined $ingredient_ref->{ingredients})) {
			$log->debug("compute_footprints_of_ingredients - ingredient has subingredients", { ingredient_id => $ingredient_ref->{id} }) if $log->is_debug();
			compute_footprints_of_ingredients($footprints_ref, $ingredient_ref->{ingredients});
		}
		
	}
}


1;

