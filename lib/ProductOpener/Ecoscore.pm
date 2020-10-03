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

ProductOpener::Ecoscore - compute the Ecoscore environemental grade of a food product

=head1 SYNOPSIS

C<ProductOpener::Ecoscore> is used to compute the Ecoscore environmental grade
of a food product.

=head1 DESCRIPTION

The modules implements the Eco-Score computation as defined by a collective that Open Food Facts is part of.

It is based on the French AgriBalyse V3 database that contains environmental impact values for 2500 food product categories.

AgriBalyse provides Life Cycle Analysis (LCA) values for food products categories,
and some adjustments to the score are made for actual specific products using data about labels, origins of ingredients, packagings etc.

=cut

package ProductOpener::Ecoscore;

use utf8;
use Modern::Perl '2017';
use Exporter    qw< import >;

use Log::Any qw($log);

BEGIN
{
	use vars       qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(

		&load_agribalyse_data
		&compute_ecoscore

		);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;

use ProductOpener::Config qw/:all/;
use ProductOpener::Tags qw/:all/;

use Text::CSV();

my %agribalyse = ();

=head1 FUNCTIONS

=head2 load_agribalyse_data( $product_ref )

Loads the AgriBalyse database.

=cut

sub load_agribalyse_data() {

	my $agribalyse_details_by_step_csv_file = $data_root . "/ecoscore/agribalyse/AGRIBALYSE3.0.1_vf.csv.2";
	
	my $headers_ref;
	my $rows_ref = [];

	my $encoding = "UTF-8";

	$log->debug("opening agribalyse CSV file", { file => $agribalyse_details_by_step_csv_file }) if $log->is_debug();

	my $csv_options_ref = { binary => 1, sep_char => "," };    # should set binary attribute.

	my $csv = Text::CSV->new ( $csv_options_ref )
		or die("Cannot use CSV: " . Text::CSV->error_diag ());

	if (open (my $io, "<:encoding($encoding)", $agribalyse_details_by_step_csv_file)) {

		my $row_ref;

		# Skip 3 first lines
		$csv->getline ($io);
		$csv->getline ($io);
		$csv->getline ($io);

		while ($row_ref = $csv->getline ($io)) {
			$agribalyse{$row_ref->[0]} = {
				name_fr => $row_ref->[4], # Nom du Produit en Français
				name_en => $row_ref->[5], # LCI Name
				dqr => $row_ref->[6], # DQR (data quality rating)
				# warning: the AGB file has a hidden H column
				ef_agriculture => $row_ref->[8], # Agriculture
				ef_processing => $row_ref->[9], # Transformation
				ef_packaging => $row_ref->[10], # Emballage
				ef_transportation => $row_ref->[11], # Transport
				ef_distribution => $row_ref->[12], # Supermarché et distribution
				ef_consumption => $row_ref->[13], # Consommation
				ef_total => $row_ref->[14], # Total
			};
		}
	}
	else {
		die("Could not open agribalyse CSV $agribalyse_details_by_step_csv_file: $!");
	}
}



=head2 compute_ecoscore( $product_ref )

C<compute_ecoscore()> computes the Eco-Score of a food product, and stores the details of the computation.

=head3 Arguments

=head4 Product reference $product_ref

=head3 Return values

The Eco-Score score and computations details are stored in the product reference passed as input parameter.

Returned values:

- ecoscore_score : numeric Eco-Score value
- ecoscore_grade : corresponding A to E grade
- ecoscore_data : Eco-Score computation details

=cut

sub compute_ecoscore($) {

	my $product_ref = shift;
	
	$product_ref->{ecoscore_data} = {};
	
	# Check the input data
	
	# Check if one of the product categories has an Agribalyse match or proxy match
	
	my $agb;	# match or proxy match
	my $agb_match;
	my $agb_proxy_match;
	
	if ((defined $product_ref->{categories_tags}) and (scalar @{$product_ref->{categories_tags}} > 0)) {
		
		# Start with most specific category first
		foreach my $category (reverse @{$product_ref->{categories_tags}}) {
			
			$agb_match = get_property("categories", $category, "agribalyse_food_code:en");
			last if $agb_match;
			
			if (not defined $agb_proxy_match) {
				$agb_proxy_match = get_property("categories", $category, "agribalyse_proxy_food_code:en");
			}
		}
		
		if ($agb_match) {
			$product_ref->{ecoscore_data}{agribalyse_food_code} = $agb_match;
			$agb = $agb_match;
		}
		elsif ($agb_proxy_match) {
			$product_ref->{ecoscore_data}{agribalyse_proxy_food_code} = $agb_proxy_match;
			$agb = $agb_proxy_match;
		}
		else {
			defined $product_ref->{ecoscore_data}{missing} or $product_ref->{ecoscore_data}{missing} = {};
			$product_ref->{ecoscore_data}{missing}{agb_category} = 1;
		}
	}
	else {
		defined $product_ref->{ecoscore_data}{missing} or $product_ref->{ecoscore_data}{missing} = {};
		$product_ref->{ecoscore_data}{missing}{categories} = 1;
	}
	
	# Compute the Eco-Score
	
	my $ecoscore_score;
	
	if ($agb) {
		$product_ref->{ecoscore_data}{agribalyse_food_name_fr} = $agribalyse{$agb}{name_fr};
		$product_ref->{ecoscore_data}{agribalyse_food_name_en} = $agribalyse{$agb}{name_en};
		$product_ref->{ecoscore_data}{agribalyse_ef_total} = $agribalyse{$agb}{ef_total};
		
		# Formula to transform the Environmental Footprint single score to a 0 to 100 scale
		# Note: EF score are for mPt / kg in Agribalyse, we need it in micro points per 100g
		$ecoscore_score = -15 * log($agribalyse{$agb}{ef_total} * $agribalyse{$agb}{ef_total} * (1000 * 1000 / 100) + 195 ) + 178;
	}
	else {
		# We need an AgriBalyse category match to compute the Eco-Score
		$product_ref->{ecoscore_data}{status} = "unknown";
	}
	
	if ($ecoscore_score) {
		$product_ref->{ecoscore_data}{status} = "known";
		$product_ref->{ecoscore_score} = $ecoscore_score;
		
		if ($product_ref->{ecoscore_score} >= 80) {
			$product_ref->{ecoscore_grade} = "a";
		}
		elsif ($product_ref->{ecoscore_score} >= 60) {
			$product_ref->{ecoscore_grade} = "b";
		}
		elsif ($product_ref->{ecoscore_score} >= 40) {
			$product_ref->{ecoscore_grade} = "c";
		}
		elsif ($product_ref->{ecoscore_score} >= 20) {
			$product_ref->{ecoscore_grade} = "d";
		}
		else {
			$product_ref->{ecoscore_grade} = "e";
		}
		$product_ref->{ecoscore_data}{score} = $product_ref->{ecoscore_score};
		$product_ref->{ecoscore_data}{grade} = $product_ref->{ecoscore_grade};
	}
	else {
		$product_ref->{ecoscore_data}{status} = "unknown";
	}
}


1;

