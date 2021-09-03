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
		&localize_ecoscore
		
		%ecoscore_countries
		@ecoscore_countries_sorted
		%ecoscore_countries_enabled
		@ecoscore_countries_enabled_sorted

		);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Packaging qw/:all/;

use Storable qw(dclone freeze);
use Text::CSV();
use Math::Round;

my %agribalyse = ();

=head1 VARIABLES

=head2 %ecoscore_countries_enabled

List of countries for which we are going to compute and display the Eco-Score.

The list is different from %ecoscore_countries that can contain more countries for which we have some
data to compute the Eco-Score (e.g. distances).

=cut

@ecoscore_countries_enabled_sorted = qw(be ch de es fr ie it lu nl uk);

foreach my $country (@ecoscore_countries_enabled_sorted) {
	$ecoscore_countries_enabled{$country} = 1;
}

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
				code => $row_ref->[0], # Agribalyse code = Ciqual code
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
				co2_agriculture => $row_ref->[15], # Agriculture
				co2_processing => $row_ref->[16], # Transformation
				co2_packaging => $row_ref->[17], # Emballage
				co2_transportation => $row_ref->[18], # Transport
				co2_distribution => $row_ref->[19], # Supermarché et distribution
				co2_consumption => $row_ref->[20], # Consommation
				co2_total => $row_ref->[21], # Total				
			};
		}
	}
	else {
		die("Could not open agribalyse CSV $agribalyse_details_by_step_csv_file: $!");
	}
}


my %ecoscore_data = (
	origins => {},
);

%ecoscore_countries = ();


=head2 load_ecoscore_data_origins_of_ingredients_distances ( $product_ref )

Loads origins of ingredients distances data needed to compute the Eco-Score.

=cut

sub load_ecoscore_data_origins_of_ingredients_distances() {

	my $errors = 0;

	my $csv_options_ref = { binary => 1, sep_char => "," };    # should set binary attribute.
	my $csv = Text::CSV->new ( $csv_options_ref )
		or die("Cannot use CSV: " . Text::CSV->error_diag ());
		
	my $csv_file = $data_root . "/ecoscore/data/distances.csv";
	my $encoding = "UTF-8";
	
	$log->debug("opening ecoscore origins distances CSV file", { file => $csv_file }) if $log->is_debug();

	if (open (my $io, "<:encoding($encoding)", $csv_file)) {
		
		my @countries = ();

		# Headers: ISO Country Code,	Country (english),	Country (french),	AD,	AL,	AT,	AX,	BA,	BE,	BG,  ...
		my $header_row_ref = $csv->getline ($io);

		for (my $i = 3; $i < (scalar @{$header_row_ref}); $i++) {
			$countries[$i] = lc($header_row_ref->[$i]);
			if ($countries[$i] eq 'gb') {
				$countries[$i] = 'uk';
			}
			$ecoscore_countries{$countries[$i]} = 1;
			# Score 0 for unknown origin
			$ecoscore_data{origins}{"en:unknown"}{"transportation_score_" . $countries[$i]} = 0;
		}
		@ecoscore_countries_sorted = sort keys %ecoscore_countries;

		$ecoscore_data{origins}{"en:world"} = $ecoscore_data{origins}{"en:unknown"};
		$ecoscore_data{origins}{"en:european-union-and-non-european-union"} = $ecoscore_data{origins}{"en:unknown"};

		$log->debug("ecoscore origins distances CSV file - countries header row", { ecoscore_countries_sorted => \@ecoscore_countries_sorted }) if $log->is_debug();		

		my $row_ref;
		
		while ($row_ref = $csv->getline ($io)) {
			
			my $origin = $row_ref->[0];
			
			next if ((not defined $origin) or ($origin eq ""));
			
			my $origin_id = canonicalize_taxonomy_tag("en", "origins", $origin);
				
			if (not exists_taxonomy_tag("origins", $origin_id)) {
			
				$log->error("ecoscore origin does not exist in taxonomy", { origin => $origin, origin_id => $origin_id}) if $log->is_error();
				$errors++;
			}
		
			$ecoscore_data{origins}{$origin_id} = {
				name_en => $row_ref->[1],
				name_fr => $row_ref->[2],
			};
			
			for (my $i = 3; $i < (scalar @{$row_ref}); $i++) {
				$ecoscore_data{origins}{$origin_id}{"transportation_score_" . $countries[$i]} = $row_ref->[$i];
			}
			
			$log->debug("ecoscore origins CSV file - row", { origin => $origin, origin_id => $origin_id, ecoscore_data => $ecoscore_data{origins}{$origin_id}}) if $log->is_debug();
		}
		
		if ($errors) {
			#die("$errors unrecognized origins in CSV $csv_file");
		}
	}
	else {
		die("Could not open ecoscore origins distances CSV $csv_file: $!");
	}
}


=head2 load_ecoscore_data_origins_of_ingredients( $product_ref )

Loads origins of ingredients data needed to compute the Eco-Score.

Data contains:
- EPI score for each origin
- Original transportation score for France, as defined in Eco-Score original specification
(distances in distances.csv have been recomputed in a slightly different way, and the 
scores for France slightly differ from the original ones)

=cut

sub load_ecoscore_data_origins_of_ingredients() {

	# First load transportation data from the distances.csv file
	
	load_ecoscore_data_origins_of_ingredients_distances();

	my $errors = 0;

	my $csv_options_ref = { binary => 1, sep_char => "," };    # should set binary attribute.
	my $csv = Text::CSV->new ( $csv_options_ref )
		or die("Cannot use CSV: " . Text::CSV->error_diag ());
		
	my $csv_file = $data_root . "/ecoscore/data/fr_countries.csv";
	my $encoding = "UTF-8";
	
	$log->debug("opening ecoscore origins CSV file", { file => $csv_file }) if $log->is_debug();

	if (open (my $io, "<:encoding($encoding)", $csv_file)) {
		
		# headers: Pays	"Score Politique environnementale"	Score Transport - France	"Score Transport - Belgique"	"Score Transport - Allemagne"	"Score Transport - Irlande"	Score Transport - Italie	"Score Transport - Luxembourg"	"Score Transport - Pays-Bas"	"Score Transport - Espagne"	"Score Transport - Suisse"		

		my $header_row_ref = $csv->getline ($io);
		
		$ecoscore_data{origins}{"en:unknown"}{epi_score} = 0;

		$ecoscore_data{origins}{"en:world"} = $ecoscore_data{origins}{"en:unknown"};
		$ecoscore_data{origins}{"en:european-union-and-non-european-union"} = $ecoscore_data{origins}{"en:unknown"};

		my $row_ref;
		
		while ($row_ref = $csv->getline ($io)) {
			
			my $origin = $row_ref->[0];
			
			next if ((not defined $origin) or ($origin eq ""));
			
			my $origin_id = canonicalize_taxonomy_tag("fr", "origins", $origin);
			
			if (not exists_taxonomy_tag("origins", $origin_id)) {
				
				# Eco-Score entries like "Macedonia [FYROM]": remove the [..] part
				# but keep it in the first try, as it is needed to distinguish "Congo [DRC]" and "Congo [Republic]"
				if ($origin =~ /^(.*)\[(.*)\]/) {
					$origin_id = canonicalize_taxonomy_tag("fr", "origins", $1);
					if (not exists_taxonomy_tag("origins", $origin_id)) {
						$origin_id = canonicalize_taxonomy_tag("fr", "origins", $2);
					}
				}
			}
			
			# La Guyane Française -> Guyane Française
			if (not exists_taxonomy_tag("origins", $origin_id)) {
				
				if ($origin =~ /^(la|les|l'|le)\s?(.*)$/i) {
					$origin_id = canonicalize_taxonomy_tag("fr", "origins", $2);
				}
			}
				
			if (not exists_taxonomy_tag("origins", $origin_id)) {
			
				$log->error("ecoscore origin does not exist in taxonomy", { origin => $origin, origin_id => $origin_id}) if $log->is_error();
				$errors++;
			}
		
			$ecoscore_data{origins}{$origin_id}{epi_score} = $row_ref->[1];

			# Override data for France from distances.csv with the original French Eco-Score data for France
			$ecoscore_data{origins}{$origin_id}{"transportation_score_fr"} = $row_ref->[2];
			
			$log->debug("ecoscore origins CSV file - row", { origin => $origin, origin_id => $origin_id, ecoscore_data => $ecoscore_data{origins}{$origin_id}}) if $log->is_debug();
		}
		
		if ($errors) {
			#die("$errors unrecognized origins in CSV $csv_file");
		}
		
		$ecoscore_data{origins}{"en:unspecified"} = $ecoscore_data{origins}{"en:unknown"};
	}
	else {
		die("Could not open ecoscore origins CSV $csv_file: $!");
	}
}


=head2 load_ecoscore_data_packaging( $product_ref )

Loads packaging data needed to compute the Eco-Score.

=cut

sub load_ecoscore_data_packaging() {
	
	my $errors = 0;
	
	my $csv_options_ref = { binary => 1, sep_char => "," };    # should set binary attribute.
	my $csv = Text::CSV->new ( $csv_options_ref )
		or die("Cannot use CSV: " . Text::CSV->error_diag ());	

	# Packaging materials

	# Eco_score_Calculateur.csv is not up to date anymore, instead use a copy of the table in 
	# https://docs.score-environnemental.com/methodologie/produit/emballages/score-par-materiaux
	# my $csv_file = $data_root . "/ecoscore/data/Eco_score_Calculateur.csv.11";
	my $csv_file = $data_root . "/ecoscore/data/fr_packaging_materials.csv";
	my $encoding = "UTF-8";
		
	$ecoscore_data{packaging_materials} = {};
	
	# We will also add the data as a property to the packaging_materials taxonomy so that we can use the get_inherited_property function
	defined $properties{"packaging_materials"} or $properties{"packaging_materials"} = {};

	$log->debug("opening ecoscore materials CSV file", { file => $csv_file }) if $log->is_debug();

	if (open (my $io, "<:encoding($encoding)", $csv_file)) {

		my $row_ref;

		# Skip first line
		$csv->getline ($io);
		
		# headers: Matériaux,Score

		while ($row_ref = $csv->getline ($io)) {
			
			my $material = $row_ref->[0];
			
			next if ((not defined $material) or ($material eq ""));
			
			# Special cases
			$material =~ s/\(100\%\)//;
			$material =~ s/bisourcé/biosourcé/ig;
			$material =~ s/Aluminium \(léger < 60mm\)/Aluminium léger/ig;
			$material =~ s/Aluminium \(lourd > 60mm\)/Aluminium lourd/ig;
			$material =~ s/Bouteille PET coloré ou opaque/Bouteille PET coloré/ig;
			
			# The Eco-score specifies some materials that are in fact a combination of shape + material
			# e.g. "Bouteille PET" (PET bottle) is a separate entry from PET, with different scores.
			# We create special material.shape (e.g. en:plastic.bottle) entries that we will
			# use when computing the packaging scores.
			my $shape;
			if ($material =~ /^bouteille /i) {
				$shape = "en:bottle";
				$material = $';
			}
			if ($material =~ /^bouchon /i) {
				$shape = "en:bottle-cap";
				$material = $';
			}			
			
			my $material_id = canonicalize_taxonomy_tag("fr", "packaging_materials", $material);
			
			if (not exists_taxonomy_tag("packaging_materials", $material_id)) {
				$log->error("ecoscore material does not exist in taxonomy", { material => $material, material_id => $material_id}) if $log->is_error();
				$errors++;
			}
			
			# combine material + shape
			if (defined $shape) {
				$material_id = $material_id . "." . $shape;
			}
			
			$ecoscore_data{packaging_materials}{$material_id} = {
				name_fr => $row_ref->[0], # Matériaux
				score => $row_ref->[1], # Score
			};
			
			(defined $properties{"packaging_materials"}{$material_id}) or $properties{"packaging_materials"}{$material_id} = {};
			$properties{"packaging_materials"}{$material_id}{"ecoscore_score:en"} = $ecoscore_data{packaging_materials}{$material_id}{score};
			
			$log->debug("ecoscore materials CSV file - row", { material => $material, material_id => $material_id, ecoscore_data => $ecoscore_data{packaging_materials}{$material_id}}) if $log->is_debug();
		}
		
		if ($errors) {
			die("$errors unrecognized materials in CSV $csv_file");
		}
		
		# Extra assignments
		
		# "Bouteille PET transparente",62.5
		# "Bouteille PET coloré ou opaque",50
		# "Bouteille PET Biosourcé",75
		# "Bouteille rPET transparente (100%)",100
		
		$ecoscore_data{packaging_materials}{"en:opaque-pet.en:bottle"} = $ecoscore_data{packaging_materials}{"en:colored-pet.en:bottle"};
		$properties{"packaging_materials"}{"en:opaque-pet.en:bottle"}{"ecoscore_score:en"} = $ecoscore_data{packaging_materials}{"en:colored-pet.en:bottle"}{score};
		$ecoscore_data{packaging_materials}{"en:pet-polyethylene-terephthalate.en:bottle"} = $ecoscore_data{packaging_materials}{"en:colored-pet.en:bottle"};
		$properties{"packaging_materials"}{"en:pet-polyethylene-terephthalate.en:bottle"}{"ecoscore_score:en"} = $ecoscore_data{packaging_materials}{"en:colored-pet.en:bottle"}{score};
		
		# Assign transparent rPET bottle score to rPET
		$ecoscore_data{packaging_materials}{"en:rpet-recycled-polyethylene-terephthalate"} = $ecoscore_data{packaging_materials}{"en:transparent-rpet.en:bottle"};
		$properties{"packaging_materials"}{"en:rpet-recycled-polyethylene-terephthalate"}{"ecoscore_score:en"} = $ecoscore_data{packaging_materials}{"en:transparent-rpet.en:bottle"}{score};				
		
		$ecoscore_data{packaging_materials}{"en:plastic"} = $ecoscore_data{packaging_materials}{"en:other-plastics"};		
		$properties{"packaging_materials"}{"en:plastic"}{"ecoscore_score:en"} = $ecoscore_data{packaging_materials}{"en:plastic"}{score};
	}
	else {
		die("Could not open ecoscore materials CSV $csv_file: $!");
	}
	
	$log->debug("ecoscore packaging_materials data", { packaging_meterials => $ecoscore_data{packaging_materials} }) if $log->is_debug();
	
	# Packaging shapes / formats

	$csv_file = $data_root . "/ecoscore/data/Eco_score_Calculateur.csv.12";
	$csv_file = $data_root . "/ecoscore/data/fr_packaging_shapes.csv";
	$encoding = "UTF-8";
		
	$ecoscore_data{packaging_shapes} = {};
	
	# We will also add the data as a property to the packaging_shapes taxonomy so that we can use the get_inherited_property function
	defined $properties{"packaging_shapes"} or $properties{"packaging_shapes"} = {};	

	$log->debug("opening ecoscore shapes CSV file", { file => $csv_file }) if $log->is_debug();

	if (open (my $io, "<:encoding($encoding)", $csv_file)) {

		my $row_ref;

		# Skip first line
		$csv->getline ($io);
		
		# headers: Format,Ratio

		while ($row_ref = $csv->getline ($io)) {
			
			my $shape = $row_ref->[0];
			
			next if ((not defined $shape) or ($shape eq ""));
			
			# Special cases
			
			# skip ondulated cardboard (should be a material)
			next if ($shape eq "Carton ondulé");
			
			my $shape_id = canonicalize_taxonomy_tag("fr", "packaging_shapes", $shape);
			
			if (not exists_taxonomy_tag("packaging_shapes", $shape_id)) {
				$log->error("ecoscore shape does not exist in taxonomy", { shape => $shape, shape_id => $shape_id}) if $log->is_error();
				$errors++;
			}
			
			$ecoscore_data{packaging_shapes}{$shape_id} = {
				name_fr => $row_ref->[0], # Format
				ratio => $row_ref->[1], # Ratio
			};
			
			# if the ratio has a comma (0,2), turn it to a dot (0.2)
			$ecoscore_data{packaging_shapes}{$shape_id}{ratio} =~ s/,/\./;			
			
			(defined $properties{"packaging_shapes"}{$shape_id}) or $properties{"packaging_shapes"}{$shape_id} = {};
			$properties{"packaging_shapes"}{$shape_id}{"ecoscore_ratio:en"} = $ecoscore_data{packaging_shapes}{$shape_id}{ratio};
			
			$log->debug("ecoscore shapes CSV file - row", { shape => $shape, shape_id => $shape_id, ecoscore_data => $ecoscore_data{packaging_shapes}{$shape_id}}) if $log->is_debug();
		}
		
		if ($errors) {
			die("$errors unrecognized shapes in CSV $csv_file");
		}
		
		# Extra assignments
		
		$ecoscore_data{packaging_shapes}{"en:can"} = $ecoscore_data{packaging_shapes}{"en:drink-can"};
		$properties{"packaging_shapes"}{"en:can"}{"ecoscore_ratio:en"} = $ecoscore_data{packaging_shapes}{"en:can"}{ratio};
		
		$ecoscore_data{packaging_shapes}{"en:card"} = $ecoscore_data{packaging_shapes}{"en:backing"};
		$properties{"packaging_shapes"}{"en:card"}{"ecoscore_ratio:en"} = $ecoscore_data{packaging_shapes}{"en:backing"}{ratio};		
		
		$ecoscore_data{packaging_shapes}{"en:label"} = $ecoscore_data{packaging_shapes}{"en:sheet"};
		$properties{"packaging_shapes"}{"en:label"}{"ecoscore_ratio:en"} = $ecoscore_data{packaging_shapes}{"en:sheet"}{ratio};
	}
	else {
		die("Could not open ecoscore shapes CSV $csv_file: $!");
	}	
	
	$log->debug("ecoscore packaging_shapes data", { packaging_meterials => $ecoscore_data{packaging_shapes} }) if $log->is_debug();
}


=head2 load_ecoscore_data( $product_ref )

Loads data needed to compute the Eco-Score.

=cut

sub load_ecoscore_data() {

	load_ecoscore_data_origins_of_ingredients();
	load_ecoscore_data_packaging();
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
	
	delete $product_ref->{ecoscore_grade};
	delete $product_ref->{ecoscore_score};
	
	$product_ref->{ecoscore_data} = {
		adjustments => {},
	};

	# Check if we have extended ecoscore_data from the impact estimator
	# Remove any misc "en:ecoscore-extended-data-version-[..]" tags
	if (defined $product_ref->{misc_tags}) {
		foreach my $tag (@{$product_ref->{misc_tags}}) {
			if ($tag =~ /^en:ecoscore-extended-data/ ) {
				remove_tag($product_ref,"misc", $tag);
			}
		}
	}
	if (defined $product_ref->{ecoscore_extended_data}) {
		add_tag($product_ref,"misc","en:ecoscore-extended-data-computed");
		if (defined $product_ref->{ecoscore_extended_data_version}) {
			add_tag($product_ref,"misc","en:ecoscore-extended-data-version-" . get_string_id_for_lang("no_language", $product_ref->{ecoscore_extended_data_version}));
		}
	}
	else {
		add_tag($product_ref,"misc","en:ecoscore-extended-data-not-computed");
	}
	
	# Special case for waters and sodas: disable the Eco-Score
	
	my @categories_without_ecoscore = ("en:waters", "en:sodas", "en:energy-drinks", "en:fresh-vegetables", "en:fresh-fruits");
	my $category_without_ecoscore;
	
	foreach my $category (@categories_without_ecoscore) {
		if (has_tag($product_ref, 'categories', $category)) {
			$category_without_ecoscore = $category;
			last;
		}
	}
	
	if ($category_without_ecoscore) {
		$product_ref->{ecoscore_data}{ecoscore_not_applicable_for_category} = $category_without_ecoscore;
		$product_ref->{ecoscore_data}{status} = "unknown";
		$product_ref->{ecoscore_tags} = ["not-applicable"];
		$product_ref->{ecoscore_grade} = "not-applicable";
		
		add_tag($product_ref,"misc","en:ecoscore-not-applicable");
		add_tag($product_ref,"misc","en:ecoscore-not-computed");
		remove_tag($product_ref,"misc","en:ecoscore-computed");
		remove_tag($product_ref,"misc","en:ecoscore-missing-data-warning");
		remove_tag($product_ref,"misc","en:ecoscore-no-missing-data");
	}
	else {
		remove_tag($product_ref,"misc","en:ecoscore-not-applicable");
		
		# Compute the LCA Eco-Score based on AgriBalyse
		
		compute_ecoscore_agribalyse($product_ref);
		
		# Compute the bonuses and maluses
		
		compute_ecoscore_production_system_adjustment($product_ref);
		compute_ecoscore_threatened_species_adjustment($product_ref);
		compute_ecoscore_origins_of_ingredients_adjustment($product_ref);
		compute_ecoscore_packaging_adjustment($product_ref);
		
		# Compute the final Eco-Score and assign the A to E grade
		
		# We need an AgriBalyse category match to compute the Eco-Score
		if ($product_ref->{ecoscore_data}{agribalyse}{score}) {
			
			$product_ref->{ecoscore_data}{status} = "known";
			
			my $missing_data_warning;
			
			# Compute the Eco-Score for all countries + a default Eco-Score without transportation bonus/malus
			foreach my $cc (@ecoscore_countries_enabled_sorted, undef) {
				
				my $suffix = "";
				if (defined $cc) {
					$suffix .= "_" . $cc;
				}

				$product_ref->{ecoscore_data}{"score" . $suffix} = $product_ref->{ecoscore_data}{agribalyse}{score};
				
				$log->debug("compute_ecoscore - agribalyse score", { cc => $cc, agribalyse_score => $product_ref->{ecoscore_data}{agribalyse}{score} }) if $log->is_debug();
				
				# Add adjustments (maluses or bonuses)
				
				my $bonus = 0;
				
				foreach my $adjustment (keys %{$product_ref->{ecoscore_data}{adjustments}}) {
					
					my $value = "value";
					if ((defined $cc) and (defined $product_ref->{ecoscore_data}{adjustments}{$adjustment}{"value_" . $cc})) {
						$value = "value_" . $cc;
					}
					
					if (defined $product_ref->{ecoscore_data}{adjustments}{$adjustment}{$value}) {
						$bonus += $product_ref->{ecoscore_data}{adjustments}{$adjustment}{$value};
						$log->debug("compute_ecoscore - add adjustment", { adjustment => $adjustment, 
							$value => $product_ref->{ecoscore_data}{adjustments}{$adjustment}{$value} }) if $log->is_debug();
					}
					if (defined $product_ref->{ecoscore_data}{adjustments}{$adjustment}{warning}) {
						$missing_data_warning = 1;
					}
				}
				
				# The sum of the bonuses is capped at 25
				if ($bonus > 25) {
					$bonus = 25;
				}
				
				$product_ref->{ecoscore_data}{"score" . $suffix} += $bonus;
				
				# Assign A to E grade
				
				if ($product_ref->{ecoscore_data}{"score" . $suffix} >= 80) {
					$product_ref->{ecoscore_data}{"grade" . $suffix} = "a";
				}
				elsif ($product_ref->{ecoscore_data}{"score" . $suffix} >= 60) {
					$product_ref->{ecoscore_data}{"grade" . $suffix} = "b";
				}
				elsif ($product_ref->{ecoscore_data}{"score" . $suffix} >= 40) {
					$product_ref->{ecoscore_data}{"grade" . $suffix} = "c";
				}
				elsif ($product_ref->{ecoscore_data}{"score" . $suffix} >= 20) {
					$product_ref->{ecoscore_data}{"grade" . $suffix} = "d";
				}
				else {
					$product_ref->{ecoscore_data}{"grade" . $suffix} = "e";
				}
				
				# If a product has the grade A and it contains a non-biodegradable and non-recyclable material, downgrade to B
				if (($product_ref->{ecoscore_data}{"grade" . $suffix} eq "a")
					and ($product_ref->{ecoscore_data}{adjustments}{packaging}{non_recyclable_and_non_biodegradable_materials} > 0)) {
						
					$product_ref->{ecoscore_data}{"grade" . $suffix} = "b";
					$product_ref->{downgraded} = "non_recyclable_and_non_biodegradable_materials";
				}

				$log->debug("compute_ecoscore - final score and grade", { score => $product_ref->{"score" . $suffix}, grade => $product_ref->{"grade" . $suffix}}) if $log->is_debug();				
			}
			
			# The following values correspond to the Eco-Score for France.
			# at run-time, they may be changed to the values for a specific country
			# after localize_ecoscore() is called

			# The ecoscore_tags used for the /ecoscore facet and the ecoscore_score used for sorting by Eco-Score
			# can only have 1 value. 
			# Unfortunately there is a MongoDB index limit and we cannot create a different set of field
			# for each country.
			
			$product_ref->{"ecoscore_score"} = $product_ref->{ecoscore_data}{"score_fr"};
			$product_ref->{"ecoscore_grade"} = $product_ref->{ecoscore_data}{"grade_fr"};
			$product_ref->{"ecoscore_tags"} = [$product_ref->{ecoscore_grade}];			
			
			if ($missing_data_warning) {
				$product_ref->{ecoscore_data}{missing_data_warning} = 1;
				add_tag($product_ref,"misc","en:ecoscore-missing-data-warning");
				remove_tag($product_ref,"misc","en:ecoscore-no-missing-data");
			}
			else {
				remove_tag($product_ref,"misc","en:ecoscore-missing-data-warning");
				add_tag($product_ref,"misc","en:ecoscore-no-missing-data");
			}
			
			add_tag($product_ref,"misc","en:ecoscore-computed");
			remove_tag($product_ref,"misc","en:ecoscore-not-computed");		
		}
		else {
			# No AgriBalyse category match
			$product_ref->{ecoscore_data}{missing_agribalyse_match_warning} = 1;
			$product_ref->{ecoscore_data}{status} = "unknown";
			$product_ref->{ecoscore_tags} = ["unknown"];
			$product_ref->{ecoscore_grade} = "unknown";
			
			add_tag($product_ref,"misc","en:ecoscore-not-computed");
			remove_tag($product_ref,"misc","en:ecoscore-computed");
			remove_tag($product_ref,"misc","en:ecoscore-missing-data-warning");
			remove_tag($product_ref,"misc","en:ecoscore-no-missing-data");
		}
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
			$product_ref->{ecoscore_data}{agribalyse} = $agribalyse{$agb_match};
			$product_ref->{ecoscore_data}{agribalyse}{agribalyse_food_code} = $agb_match;
			$agb = $agb_match;
		}
		elsif ($agb_proxy_match) {
			$product_ref->{ecoscore_data}{agribalyse} = $agribalyse{$agb_proxy_match};
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
		
		if (not defined $agribalyse{$agb}{ef_total}) {
			$log->error("compute_ecoscore - ef_total missing for category", { agb => $agb, agribalyse => $agribalyse{$agb} }) if $log->is_error();
		}
		else {
			# Formula to transform the Environmental Footprint single score to a 0 to 100 scale
			# Note: EF score are for mPt / kg in Agribalyse, we need it in micro points per 100g
			
			# Milk is considered to be a beverage
			if (has_tag($product_ref, 'categories', 'en:beverages') or (has_tag($product_ref, 'categories', 'en:milks'))) {
				# Beverages case: score = -36*\ln(x+1)+150score=− 36 * ln(x+1) + 150
				$product_ref->{ecoscore_data}{agribalyse}{is_beverage} = 1;
				$product_ref->{ecoscore_data}{agribalyse}{score} = round(-36 * log($agribalyse{$agb}{ef_total} * (1000 / 10) + 1 ) + 150);
			}
			else {
				# 2021-02-17: new updated formula: 100-(20 * ln(10*x+1))/ln(2+ 1/(100*x*x*x*x))  - with x in MPt / kg.
				$product_ref->{ecoscore_data}{agribalyse}{is_beverage} = 0;
				$product_ref->{ecoscore_data}{agribalyse}{score} = round(100 - 20 * log(10 * $agribalyse{$agb}{ef_total} + 1)
					/ log(2 + 1 / (100 * $agribalyse{$agb}{ef_total} * $agribalyse{$agb}{ef_total} * $agribalyse{$agb}{ef_total} * $agribalyse{$agb}{ef_total})));
			}
			if ($product_ref->{ecoscore_data}{agribalyse}{score} < 0) {
				$product_ref->{ecoscore_data}{agribalyse}{score} = 0;
			}
			elsif ($product_ref->{ecoscore_data}{agribalyse}{score} > 100) {
				$product_ref->{ecoscore_data}{agribalyse}{score} = 100;
			}
		}
	}
	else {
		$product_ref->{ecoscore_data}{agribalyse}{warning} = "missing_agribalyse_match";
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
	
	# No labels warning
	if (not defined $product_ref->{ecoscore_data}{adjustments}{production_system}{label}) {
		$product_ref->{ecoscore_data}{adjustments}{production_system}{warning} = "no_label";
		defined $product_ref->{ecoscore_data}{missing} or $product_ref->{ecoscore_data}{missing} = {};
		$product_ref->{ecoscore_data}{missing}{labels} = 1;
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
	
	# No ingredients warning
	if ((not defined $product_ref->{ingredients}) or (scalar @{$product_ref->{ingredients}} == 0)) {
		$product_ref->{ecoscore_data}{adjustments}{threatened_species}{warning} = "ingredients_missing";
		defined $product_ref->{ecoscore_data}{missing} or $product_ref->{ecoscore_data}{missing} = {};
		$product_ref->{ecoscore_data}{missing}{ingredients} = 1;
	}
	
}


=head2 aggregate_origins_of_ingredients ( $default_origins_ref, $aggregated_origins_ref, $ingredient_ref )

Computes adjustments(bonus or malus for transportation + EPI / Environmental Performance Index) 
according to the countries of origin of the ingredients.

=head3 Arguments

=head4 Default origins reference: $default_origins_ref

Array of origins specified in the origins field, that we will use for ingredients that do not have a specific origin.

=head4 Aggregated origins reference $aggregated_origins_ref

Data structure to which we will add the percentages for the ingredient specified in $ingredient_ref

=head4 Ingredient reference $ingredient_ref

Ingredient reference that may contains an ingredients structure for sub-ingredients.

=head3 Return values

The percentages are stored in $aggregated_origins_ref

=cut

sub aggregate_origins_of_ingredients($$$);

sub aggregate_origins_of_ingredients($$$) {
	
	my $default_origins_ref = shift;
	my $aggregated_origins_ref = shift;
	my $ingredients_ref = shift;
	
	# The ingredients array contains sub-ingredients in nested ingredients
		
	foreach my $ingredient_ref (@$ingredients_ref) {
		
		my $ingredient_origins_ref;
		
		# If the ingredient has specified origins, use them
		if (defined $ingredient_ref->{origins}) {
			$ingredient_origins_ref = [split(/,/, $ingredient_ref->{origins})];
			$log->debug("aggregate_origins_of_ingredients - ingredient has specified origins", { ingredient_id => $ingredient_ref->{id}, ingredient_origins_ref => $ingredient_origins_ref }) if $log->is_debug();
		}
		# Otherwise, if the ingredient has sub ingredients, use the origins of the sub ingredients
		elsif (defined $ingredient_ref->{ingredients}) {
			$log->debug("aggregate_origins_of_ingredients - ingredient has subingredients", { ingredient_id => $ingredient_ref->{id} }) if $log->is_debug();
			aggregate_origins_of_ingredients($default_origins_ref, $aggregated_origins_ref, $ingredient_ref->{ingredients});
		}
		# Else use default origins
		else {
			$ingredient_origins_ref = $default_origins_ref;
			$log->debug("aggregate_origins_of_ingredients - use default origins", { ingredient_id => $ingredient_ref->{id}, ingredient_origins_ref => $ingredient_origins_ref }) if $log->is_debug();
		}
		
		# If we are not using the origins of the sub ingredients,
		# aggregate the origins of the ingredient
		if (defined $ingredient_origins_ref) {
			$log->debug("aggregate_origins_of_ingredients - adding origins", { ingredient_id => $ingredient_ref->{id}, ingredient_origins_ref => $ingredient_origins_ref }) if $log->is_debug();
			foreach my $origin_id (@$ingredient_origins_ref) {
				if (not defined $ecoscore_data{origins}{$origin_id}) {

					# If the origin is a child of a country, use the country
					my $country_code = get_inherited_property("origins", $origin_id, "country_code_2:en");

					if ((defined $country_code) and (defined $ecoscore_data{origins}{canonicalize_taxonomy_tag("en", "origins", $country_code)})) {
						$origin_id = canonicalize_taxonomy_tag("en", "origins", $country_code);
					}
					else {
						$origin_id = "en:unknown";
					}
				}
				defined $aggregated_origins_ref->{$origin_id} or $aggregated_origins_ref->{$origin_id} = 0;
				$aggregated_origins_ref->{$origin_id} += $ingredient_ref->{percent_estimate} / scalar(@$ingredient_origins_ref);
			}
		}
	}
}

=head2 compute_ecoscore_origins_of_ingredients_adjustment ( $product_ref )

Computes adjustments(bonus or malus for transportation + EPI / Environmental Performance Index) 
according to the countries of origin of the ingredients.

The transportation bonus or malus is computed for all the countries where the Eco-Score is enabled.

=head3 Arguments

=head4 Product reference $product_ref

=head3 Return values

The adjustment value and computations details are stored in the product reference passed as input parameter.

Returned values:

$product_ref->{adjustments}{origins_of_ingredients} hash with:
- value_[country code]: combined bonus or malus for transportation + EPI
- epi_value
- transportation_value_[country code]
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
		@origins_from_origins_field = ("en:unknown");
	}
	
	$log->debug("compute_ecoscore_origins_of_ingredients_adjustment - origins field", { origins_tags => $product_ref->{origins_tags}, origins_from_origins_field => \@origins_from_origins_field }) if $log->is_debug();
	
	# Sum the % values/estimates of all ingredients by origins
	
	my %aggregated_origins = ();
	
	if ((defined $product_ref->{ingredients}) and (scalar @{$product_ref->{ingredients}} > 0)) {
		aggregate_origins_of_ingredients(\@origins_from_origins_field, \%aggregated_origins , $product_ref->{ingredients});
	}
	else {
		# If we don't have ingredients listed, apply the origins from the origins field
		# using a dummy ingredient
		aggregate_origins_of_ingredients(\@origins_from_origins_field, \%aggregated_origins , [ { percent_estimate => 100} ]);
	}
	
	# Compute the transportation and EPI values and a sorted list of aggregated origins
	
	my @aggregated_origins = ();
	my %transportation_scores;
	foreach my $cc (@ecoscore_countries_enabled_sorted) {
		$transportation_scores{$cc} = 0;
	}
	my $epi_score = 0;
	
	foreach my $origin_id (sort ( { ($aggregated_origins{$b} <=> $aggregated_origins{$a}) || ($a cmp $b) } keys %aggregated_origins)) {
		
		my $percent = $aggregated_origins{$origin_id};
				
		push @aggregated_origins, { origin => $origin_id, percent => $percent };
		
		if (not defined $ecoscore_data{origins}{$origin_id}{epi_score}) {
			$log->error("compute_ecoscore_origins_of_ingredients_adjustment - missing epi_score", {  origin_id => $origin_id, origin_data => $ecoscore_data{origins}{$origin_id} } ) if $log->is_error();
		}
		
		$epi_score += $ecoscore_data{origins}{$origin_id}{epi_score} * $percent / 100;
		foreach my $cc (@ecoscore_countries_enabled_sorted) {
			$transportation_scores{$cc} += $ecoscore_data{origins}{$origin_id}{"transportation_score_" . $cc} * $percent / 100;
		}
	}
	
	my $epi_value = $epi_score / 10 - 5;
	
	$log->debug("compute_ecoscore_origins_of_ingredients_adjustment - aggregated origins", {  aggregated_origins => \@aggregated_origins } ) if $log->is_debug();

	$product_ref->{ecoscore_data}{adjustments}{origins_of_ingredients} = {
		origins_from_origins_field => \@origins_from_origins_field,		
		aggregated_origins => \@aggregated_origins,
		epi_score => $epi_score,
		epi_value => round($epi_value),
	};
	
	foreach my $cc (@ecoscore_countries_enabled_sorted) {
		$product_ref->{ecoscore_data}{adjustments}{origins_of_ingredients}{"transportation_score_" . $cc} = $transportation_scores{$cc};
		$product_ref->{ecoscore_data}{adjustments}{origins_of_ingredients}{"transportation_value_" . $cc} = round($transportation_scores{$cc} / 6.66);
		$product_ref->{ecoscore_data}{adjustments}{origins_of_ingredients}{"value_" . $cc} = round($epi_value)
			+ $product_ref->{ecoscore_data}{adjustments}{origins_of_ingredients}{"transportation_value_" . $cc};
	}
	
	# Add a warning if the only origin is en:unknown
	if (($#aggregated_origins == 0) and ($aggregated_origins[0]{origin} eq "en:unknown")) {
		$product_ref->{ecoscore_data}{adjustments}{origins_of_ingredients}{warning} = "origins_are_100_percent_unknown";
		defined $product_ref->{ecoscore_data}{missing} or $product_ref->{ecoscore_data}{missing} = {};
		$product_ref->{ecoscore_data}{missing}{origins} = 1;
	}
}


=head2 compute_ecoscore_packaging_adjustment ( $product_ref )

Computes adjustments (malus) based on the packaging of the product.

=head3 Arguments

=head4 Product reference $product_ref

=head3 Return values

The adjustment value and computations details are stored in the product reference passed as input parameter.

Returned values:

$product_ref->{adjustments}{packaging} hash with:
- value: malus for packaging
- packagings: details of the computation

=cut

sub compute_ecoscore_packaging_adjustment($) {

	my $product_ref = shift;
	
	$log->debug("compute_ecoscore_packaging_adjustment - packagings data structure", { packagings => $product_ref->{packagings} }) if $log->is_debug();
	
	# Sum the scores of all packagings components
	# Create a copy of the packagings structure, so that we can add Eco-score elements to it
	
	my $warning;
	
	# If we do not have packagings info, return the maximum malus, and indicate the product can contain non recyclable materials
	if ((not defined $product_ref->{packagings}) or (scalar @{$product_ref->{packagings}} == 0)) {
		$product_ref->{ecoscore_data}{adjustments}{packaging} = {
			value => -15,
			non_recyclable_and_non_biodegradable_materials => 1,
		};
		$warning = "packaging_data_missing";
	}
	else {

		my $packagings_ref = dclone($product_ref->{packagings});
		
		my $packaging_score = 0;
		
		my $non_recyclable_and_non_biodegradable_materials = 0;
		
		foreach my $packaging_ref (@$packagings_ref) {
			
			# We need to match the material and shape to the Eco-score materials and shapes.
			# We may have a child of the entries listed in the Eco-score data.
			
			# Shape is needed first, as it is used in the material section to determine if a non recyclable material has a ratio >= 1
			
			if (defined $packaging_ref->{shape}) {
				
				my $ratio = get_inherited_property("packaging_shapes", $packaging_ref->{shape}, "ecoscore_ratio:en");
				if (defined $ratio) {
					$packaging_ref->{ecoscore_shape_ratio} = $ratio;
				}
				else {
					if (not defined $warning) {
						$warning = "unscored_shape";
					}
				}
			}
			else {
				$packaging_ref->{shape} = "en:unknown";
				if (not defined $warning) {
					$warning = "unspecified_shape";
				}
			}
			
			if (not defined $packaging_ref->{ecoscore_shape_ratio}) {
				# No shape specified, or no Eco-score score for it, use a ratio of 1
				$packaging_ref->{ecoscore_shape_ratio} = 1;
			}		
			
			# Material
			
			if (defined $packaging_ref->{material}) {
				
				# For aluminium, we need to differentiate heavy and light aluminium based on the shape
				if ($packaging_ref->{material} eq "en:aluminium") {
					
					my $weight = "thin";
					
					if (defined $packaging_ref->{shape}) {
						$weight = get_inherited_property("packaging_shapes", $packaging_ref->{shape}, "weight:en");
						$log->debug("aluminium", {  weight => $weight, shape => $packaging_ref->{shape} } ) if $log->is_debug();
						if (not defined $weight) {
							$weight = "heavy";
						}
					}
					
					if ($weight eq "heavy") {
						$packaging_ref->{material} = "en:heavy-aluminium";
					}
					else {
						$packaging_ref->{material} = "en:light-aluminium";
					}
				}			
				
				my $score = get_inherited_property("packaging_materials", $packaging_ref->{material}, "ecoscore_score:en");
				if (defined $score) {
					$packaging_ref->{ecoscore_material_score} = $score;
				}
				else {
					if (not defined $warning) {
						$warning = "unscored_material";
					}
				}
				
				# Check if there is a shape-specific material score (e.g. PEHD bottle)
				if (defined $packaging_ref->{shape}) {
					my $shape_specific_score = get_inherited_property("packaging_materials", $packaging_ref->{material} . '.' . $packaging_ref->{shape} , "ecoscore_score:en");
					if (defined $shape_specific_score) {
						$packaging_ref->{ecoscore_material_score} = $shape_specific_score;
						$packaging_ref->{material_shape} = $packaging_ref->{material} . '.' . $packaging_ref->{shape};
					}
				}
				
				# Check if the material is non recyclable and non biodegradable
				my $non_recyclable_and_non_biodegradable = get_inherited_property("packaging_materials", $packaging_ref->{material}, "non_recyclable_and_non_biodegradable:en");
				if (defined $non_recyclable_and_non_biodegradable) {
					$packaging_ref->{non_recyclable_and_non_biodegradable} = $non_recyclable_and_non_biodegradable;
					if (($non_recyclable_and_non_biodegradable ne "no") and ($packaging_ref->{ecoscore_shape_ratio} >= 1)) {
						$non_recyclable_and_non_biodegradable_materials++;
					}
				}
			}
			else {
				$packaging_ref->{material} = "en:unknown";
				if (not defined $warning) {
					$warning = "unspecified_material";
				}
			}
			
			if (not defined $packaging_ref->{ecoscore_material_score}) {
				# No material specified, or no Eco-score score for it, use a score of 0
				$packaging_ref->{ecoscore_material_score} = 0;
			}

			# Multiply the shape ratio and the material score
			
			$packaging_score +=  (100 - $packaging_ref->{ecoscore_material_score}) * $packaging_ref->{ecoscore_shape_ratio};
		}
		
		$packaging_score = 100 - $packaging_score;
		
		my $value = round($packaging_score / 10 - 10);
		if ($value < -15) {
			$value = -15;
		}

		$product_ref->{ecoscore_data}{adjustments}{packaging} = {
			packagings => $packagings_ref,
			score => $packaging_score,
			value => $value,
			non_recyclable_and_non_biodegradable_materials => $non_recyclable_and_non_biodegradable_materials,
		};
	}
	
	if (defined $warning) {
		$product_ref->{ecoscore_data}{adjustments}{packaging}{warning} = $warning;
		defined $product_ref->{ecoscore_data}{missing} or $product_ref->{ecoscore_data}{missing} = {};
		$product_ref->{ecoscore_data}{missing}{packagings} = 1;		
	}
	
}


=head2 localize_ecoscore ( $cc, $product_ref)

The Eco-Score and some of its components depend on the country of the consumer,
as we take transportation to the consumer into account.

We compute the Eco-Score for all countries, and this function copies the values
for a specific country to the main Eco-Score fields.

=head3 Arguments

=head4 Country code of the request $cc

=head4 Product reference $product_ref

=head3 Return values

The adjustment value and computations details are stored in the product reference passed as input parameter.


=cut

sub localize_ecoscore ($$) {
	
	my $cc = shift;
	my $product_ref = shift;

	# Localize the Eco-Score fields that depends on the country of the request
	if (defined $product_ref->{"ecoscore_grade_" . $cc}) {
		$product_ref->{"ecoscore_grade"} = $product_ref->{"ecoscore_grade_" . $cc};
	}
	if (defined $product_ref->{"ecoscore_score_" . $cc}) {
		$product_ref->{"ecoscore_score"} = $product_ref->{"ecoscore_grade_" . $cc};
	}
	if ((defined $product_ref->{ecoscore_data}) and (defined  $product_ref->{ecoscore_data}{"score_" . $cc})) {
		
		$product_ref->{ecoscore_data}{"score"} = $product_ref->{ecoscore_data}{"score_" . $cc};
		$product_ref->{ecoscore_data}{"grade"} = $product_ref->{ecoscore_data}{"grade_" . $cc};

		$product_ref->{"ecoscore_score"} = $product_ref->{ecoscore_data}{"score"};
		$product_ref->{"ecoscore_grade"} = $product_ref->{ecoscore_data}{"grade"};
		$product_ref->{"ecoscore_tags"} = [$product_ref->{ecoscore_grade}];

		if (defined $product_ref->{ecoscore_data}{adjustments}{origins_of_ingredients}) {
	
			$product_ref->{ecoscore_data}{adjustments}{origins_of_ingredients}{"value"}
			= $product_ref->{ecoscore_data}{adjustments}{origins_of_ingredients}{"value_" . $cc};
			
			$product_ref->{ecoscore_data}{adjustments}{origins_of_ingredients}{"transportation_score"}
			= $product_ref->{ecoscore_data}{adjustments}{origins_of_ingredients}{"transportation_score_" . $cc};
			
			$product_ref->{ecoscore_data}{adjustments}{origins_of_ingredients}{"transportation_value"}
			= $product_ref->{ecoscore_data}{adjustments}{origins_of_ingredients}{"transportation_value_" . $cc};
		}
	}		
	
}

1;

