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
		&load_ecoscore_data
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


my %ecoscore_data = ();

=head2 load_ecoscore_data( $product_ref )

Loads data needed to compute the Eco-Score.

=cut

sub load_ecoscore_data() {

	my $ecoscore_origins_csv_file = $data_root . "/ecoscore/data/Eco_score_Calculateur.csv.9";
	
	my $headers_ref;
	my $rows_ref = [];

	my $encoding = "UTF-8";
	
	$ecoscore_data{origins} = {};

	$log->debug("opening ecoscore origins CSV file", { file => $ecoscore_origins_csv_file }) if $log->is_debug();

	my $csv_options_ref = { binary => 1, sep_char => "," };    # should set binary attribute.

	my $csv = Text::CSV->new ( $csv_options_ref )
		or die("Cannot use CSV: " . Text::CSV->error_diag ());

	if (open (my $io, "<:encoding($encoding)", $ecoscore_origins_csv_file)) {

		my $row_ref;

		# Skip first line
		$csv->getline ($io);
		
		# headers: Country,Pays,"Score Transport","Score EPI","Bonus transport","Bonus EPI",Région

		while ($row_ref = $csv->getline ($io)) {
			
			my $origin = $row_ref->[0];
			
			next if ((not defined $origin) or ($origin eq ""));
			
			my $origin_id = canonicalize_taxonomy_tag("en", "origins", $origin);
			
			$ecoscore_data{origins}{$origin_id} = {
				name_en => $row_ref->[0], # Country
				name_fr => $row_ref->[1], # Pays
				transportation_score => $row_ref->[2], # "Score Transport"
				epi_score => $row_ref->[3], # "Score EPI"
			};
			
			$log->debug("ecoscore origins CSV file - row", { origin => $origin, origin_id => $origin_id, ecoscore_data => $ecoscore_data{origins}{$origin_id}}) if $log->is_debug();
		}
	}
	else {
		die("Could not open ecoscore origins CSV $ecoscore_origins_csv_file: $!");
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
	
	$product_ref->{ecoscore_data} = {
		adjustments => {},
	};
	
	# Compute the LCA Eco-Score based on AgriBalyse
	
	compute_ecoscore_agribalyse($product_ref);
	
	# Compute the bonuses and maluses
	
	compute_ecoscore_production_system_adjustment($product_ref);
	compute_ecoscore_threatened_species_adjustment($product_ref);
	compute_ecoscore_origins_of_ingredients_adjustment($product_ref);
	
	# Compute the final Eco-Score and assign the A to E grade
	
	# We need an AgriBalyse category match to compute the Eco-Score
	if ($product_ref->{ecoscore_data}{agribalyse}{score}) {
		
		$product_ref->{ecoscore_data}{status} = "known";
		$product_ref->{ecoscore_score} = $product_ref->{ecoscore_data}{agribalyse}{score};
		
		$log->debug("compute_ecoscore - agribalyse score", { agribalyse_score => $product_ref->{ecoscore_data}{agribalyse}{score} }) if $log->is_debug();
		
		# Add adjustments (maluses or bonuses)
		
		foreach my $adjustment (keys %{$product_ref->{ecoscore_data}{adjustments}}) {
			if (defined $product_ref->{ecoscore_data}{adjustments}{$adjustment}{value}) {
				$product_ref->{ecoscore_score} += $product_ref->{ecoscore_data}{adjustments}{$adjustment}{value};
				$log->debug("compute_ecoscore - add adjustment", { adjustment => $adjustment, 
					value => $product_ref->{ecoscore_data}{adjustments}{$adjustment}{value} }) if $log->is_debug();
			}
		}
		
		# Assign A to E grade
		
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
		
		$log->debug("compute_ecoscore - final score and grade", { score => $product_ref->{ecoscore_score}, grade => $product_ref->{ecoscore_grade}}) if $log->is_debug();
	}
	else {
		# No AgriBalyse category match
		$product_ref->{ecoscore_data}{status} = "unknown";
	}
}


=head2 compute_ecoscore_agribalyse ( $product_ref )

C<compute_ecoscore()> computes the Life Cycle Analysis (LCA) part of the Eco-Score,
based on the French AgriBalyse database.

=head3 Arguments

=head4 Product reference $product_ref

=head3 Return values

The LCA score and computations details are stored in the product reference passed as input parameter.

Returned values:

$product_ref->{agribalyse} hash with:
- 

$product_ref->{ecoscore_data}{missing} hash with:
- categories if the product does not have a category
- agb_category if the product does not have an Agribalyse match
or proxy match for at least one of its categories.

=cut

sub compute_ecoscore_agribalyse($) {

	my $product_ref = shift;
	
	$product_ref->{ecoscore_data}{agribalyse} = {};
		
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
			$product_ref->{ecoscore_data}{agribalyse}{agribalyse_food_code} = $agb_match;
			$agb = $agb_match;
		}
		elsif ($agb_proxy_match) {
			$product_ref->{ecoscore_data}{agribalyse}{agribalyse_proxy_food_code} = $agb_proxy_match;
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
	
	# Compute the Eco-Score on a 0 to 100 scale
		
	if ($agb) {
		$product_ref->{ecoscore_data}{agribalyse}{agribalyse_food_name_fr} = $agribalyse{$agb}{name_fr};
		$product_ref->{ecoscore_data}{agribalyse}{agribalyse_food_name_en} = $agribalyse{$agb}{name_en};
		$product_ref->{ecoscore_data}{agribalyse}{agribalyse_ef_total} = $agribalyse{$agb}{ef_total};
		
		# Formula to transform the Environmental Footprint single score to a 0 to 100 scale
		# Note: EF score are for mPt / kg in Agribalyse, we need it in micro points per 100g
		$product_ref->{ecoscore_data}{agribalyse}{score} = -15 * log($agribalyse{$agb}{ef_total} * $agribalyse{$agb}{ef_total} * (1000 * 1000 / 100) + 220 ) + 180;
	}
}


=head2 compute_ecoscore_production_system_adjustment ( $product_ref )

Computes an adjustment (bonus or malus) based on production system of the product (e.g. organic).

=head3 Arguments

=head4 Product reference $product_ref

=head3 Return values

The adjustment value and computations details are stored in the product reference passed as input parameter.

Returned values:

$product_ref->{adjustments}{production_system} hash with:
- 

$product_ref->{ecoscore_data}{missing} hash with:

=head3 Notes

This function tests the presence of specific labels and categories that should not be renamed.
They are listed in the t/ecoscore.t test file so that the test fail if they are renamed.

=cut

my @production_system_labels = (
	["fr:nature-et-progres", 20],
	["fr:bio-coherence", 20],
	["en:demeter", 20],
	
	["fr:ab-agriculture-biologique", 15],
	["en:eu-organic", 15],
	
	["fr:haute-valeur-environnementale", 10],
	["en:utz-certified", 10],
	["en:rainforest-alliance", 10],
	["en:fairtrade-international", 10],
	["fr:bleu-blanc-coeur", 10],
	["fr:label-rouge", 10],
	["en:sustainable-seafood-msc", 10],
	["en:responsible-aquaculture-asc", 10],
);


sub compute_ecoscore_production_system_adjustment($) {

	my $product_ref = shift;
	
	$product_ref->{ecoscore_data}{adjustments}{production_system} = {};
		
	foreach my $label_ref (@production_system_labels) {
		
		my ($label, $value) = @$label_ref;
		
		if (has_tag($product_ref, "labels", $label)
			# Label Rouge labels is counted only for beef, veal and lamb
			and (($label ne "fr:label-rouge")
				or (has_tag($product_ref, "categories", "en:beef"))
				or (has_tag($product_ref, "categories", "en:veal-meat"))
				or (has_tag($product_ref, "categories", "en:lamb-meat")))) {
					
			$product_ref->{ecoscore_data}{adjustments}{production_system}{value} = $value;
			$product_ref->{ecoscore_data}{adjustments}{production_system}{label} = $label;
			
			last;
		}
	}
	
}


=head2 compute_ecoscore_threatened_species_adjustment ( $product_ref )

Computes an adjustment (malus) if the ingredients are harmful to threatened species.
e.g. threatened fishes, or ingredients like palm oil that threaten the habitat of threatened species.

=head3 Arguments

=head4 Product reference $product_ref

=head3 Return values

The adjustment value and computations details are stored in the product reference passed as input parameter.

Returned values:

$product_ref->{adjustments}{threatened_species} hash with:
- value: malus (-10 for palm oil)
- ingredient: the id of the ingredient responsible for the malus

=cut

sub compute_ecoscore_threatened_species_adjustment($) {

	my $product_ref = shift;
	
	$product_ref->{ecoscore_data}{adjustments}{threatened_species} = {};
	
	# Products that contain palm oil that is not certified RSPO
	
	if ((has_tag($product_ref, "ingredients_analysis", "en:palm-oil"))
		and not (has_tag($product_ref, "labels", "en:roundtable-on-sustainable-palm-oil"))) {
		
		$product_ref->{ecoscore_data}{adjustments}{threatened_species}{value} = -10;
		$product_ref->{ecoscore_data}{adjustments}{threatened_species}{ingredient} = "en:palm-oil";
	}
	
}


=head2 compute_ecoscore_origins_of_ingredients_adjustment ( $product_ref )

Computes adjustments(bonus or malus for transportation + EPI / Environmental Performance Index) 
according to the countries of origin of the ingredients.

=head3 Arguments

=head4 Product reference $product_ref

=head3 Return values

The adjustment value and computations details are stored in the product reference passed as input parameter.

Returned values:

$product_ref->{adjustments}{origins_of_ingredients} hash with:
- value: combined bonus or malus for transportation + EPI
- epi_value
- transportation_value
- aggregated origins: sorted array of origin + percent to show the % of ingredients by country used in the computation

=cut

sub compute_ecoscore_origins_of_ingredients_adjustment($) {

	my $product_ref = shift;
	
	# First parse the "origins" field to see which countries are listed
	# Ignore entries that are not recognized or that do not have Eco-Score values (only countries and continents)
	
	my @origins_from_origins_field = ();
	
	if (defined $product_ref->{origins_tags}) {
		foreach my $origin_id (@{$product_ref->{origins_tags}}) {
			if (defined $ecoscore_data{origins}{$origin_id}) {
				push @origins_from_origins_field, $origin_id;
			}
		}
	}
	
	if (scalar @origins_from_origins_field == 0) {
		@origins_from_origins_field = ("en:world");
	}
	
	$log->debug("compute_ecoscore_origins_of_ingredients_adjustment - origins field", { origins_tags => $product_ref->{origins_tags}, origins_from_origins_field => \@origins_from_origins_field }) if $log->is_debug();
	
	# Sum the % values/estimates of all ingredients by origins
	
	my %aggregated_origins = ();
	
	if (defined $product_ref->{ingredients}) {
		aggregate_origins_of_ingredients(\@origins_from_origins_field, \%aggregated_origins , $product_ref->{ingredients});
	}
	else {
		# If we don't have ingredients listed, apply the origins from the origins field
		# using a dummy ingredient
		aggregate_origins_of_ingredients(\@origins_from_origins_field, \%aggregated_origins , [ { percent_estimate => 100} ]);
	}
	
	# Compute the transportation and EPI values and a sorted list of aggregated origins
	
	my @aggregated_origins = ();
	my $transportation_score = 0;
	my $epi_score = 0;
	
	foreach my $origin_id (sort ( { ($aggregated_origins{$b} <=> $aggregated_origins{$a}) || ($a cmp $b) } keys %aggregated_origins)) {
		
		my $percent = $aggregated_origins{$origin_id};
		
		push @aggregated_origins, [ $origin_id, $percent ];
		
		$epi_score += $ecoscore_data{origins}{$origin_id}{epi_score} * $percent / 100;
		$transportation_score += $ecoscore_data{origins}{$origin_id}{transportation_score} * $percent / 100;
	}
	
	my $transportation_value = $transportation_score / 6.66;
	my $epi_value = $epi_score / 10 - 5;
	
	$log->debug("compute_ecoscore_origins_of_ingredients_adjustment - aggregated origins", {  aggregated_origins => \@aggregated_origins } ) if $log->is_debug();

	$product_ref->{ecoscore_data}{adjustments}{origins_of_ingredients} = {
		origins_from_origins_field => \@origins_from_origins_field,		
		aggregated_origins => \@aggregated_origins,
		transportation_score => $transportation_score,
		epi_score => $epi_score,
		transportation_value => $transportation_value,
		epi_value => $epi_value,
		value => $transportation_value + $epi_value,
	};	
	
}

sub aggregate_origins_of_ingredients($$$) {
	
	my $default_origins_ref = shift;
	my $aggregated_origins_ref = shift;
	my $ingredients_ref = shift;
	
	foreach my $ingredient_ref (@$ingredients_ref) {
		
		my $ingredient_origins_ref;
		
		# If the ingredient has an origin, use it
		if (defined $ingredient_ref->{origins}) {
			$ingredient_origins_ref = [split(/,/, $ingredient_ref->{origins})];
		}
		# Otherwise, if the ingredient has sub ingredients, use the origins of the sub ingredients
		elsif (defined $ingredient_ref->{ingredients}) {
			aggregate_origins_of_ingredients($default_origins_ref, $aggregated_origins_ref, $ingredient_ref->{ingredients});
		}
		# Else use default origins
		else {
			$ingredient_origins_ref = $default_origins_ref;
		}
		
		# If we are not using the origins of the sub ingredients,
		# aggregate the origins of the ingredient
		if (defined $ingredient_origins_ref) {
			foreach my $origin_id (@$ingredient_origins_ref) {
				defined $aggregated_origins_ref->{$origin_id} or $aggregated_origins_ref->{$origin_id} = 0;
				$aggregated_origins_ref->{$origin_id} += $ingredient_ref->{percent_estimate} / scalar(@$ingredient_origins_ref);
			}
		}
	}
}

1;

