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

ProductOpener::EnvironmentalScore - compute the EnvironmentalScore environmental grade of a food product

=head1 SYNOPSIS

C<ProductOpener::EnvironmentalScore> is used to compute the EnvironmentalScore environmental grade
of a food product.

=head1 DESCRIPTION

The modules implements the Environmental-Score computation as defined by a collective that Open Food Facts is part of.

It is based on the French AgriBalyse V3 database that contains environmental impact values for 2500 food product categories.

AgriBalyse provides Life Cycle Analysis (LCA) values for food products categories,
and some adjustments to the score are made for actual specific products using data about labels, origins of ingredients, packagings etc.

=cut

package ProductOpener::EnvironmentalScore;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

use Log::Any qw($log);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(

		&load_agribalyse_data
		&load_environmental_score_data
		&compute_environmental_score
		&localize_environmental_score

		&is_environmental_score_extended_data_more_precise_than_agribalyse

		%agribalyse

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/get_string_id_for_lang/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Packaging qw/:all/;
use ProductOpener::Ingredients qw/has_specific_ingredient_property/;

use Storable qw(dclone freeze);
use Text::CSV();
use Math::Round;
use Data::DeepAccess qw(deep_get deep_exists);

my $agribalyse_data_loaded = 0;
my $environmental_score_data_loaded = 0;

%agribalyse = ();

=head1 VARIABLES

=head2 %environmental_score_countries_enabled

List of countries for which we are going to compute and display the Environmental-Score.

The list is different from %environmental_score_countries that can contain more countries for which we have some
data to compute the Environmental-Score (e.g. distances).

2021-10-28: we will now enable Environmental-Score for all available countries,
so this list will be overrode when we load the Environmental-Score data.

=cut

my @environmental_score_countries_enabled_sorted = qw(be ch de es fr ie it lu nl uk);
my %environmental_score_countries_enabled;

foreach my $country (@environmental_score_countries_enabled_sorted) {
	$environmental_score_countries_enabled{$country} = 1;
}

=head1 FUNCTIONS

=head2 load_agribalyse_data()

Loads the AgriBalyse database.

=cut

sub load_agribalyse_data() {

	my $agribalyse_details_by_step_csv_file
		= $data_root . "/external-data/environmental_score/agribalyse/AGRIBALYSE_vf.csv.2";

	my $rows_ref = [];

	my $encoding = "UTF-8";

	open(my $version_file,
		"<:encoding($encoding)", $data_root . '/external-data/environmental_score/agribalyse/AGRIBALYSE_version.txt')
		or die($!);
	chomp(my $agribalyse_version = <$version_file>);
	close($version_file);

	$log->debug("opening agribalyse CSV file",
		{file => $agribalyse_details_by_step_csv_file, version => $agribalyse_version})
		if $log->is_debug();

	my $csv_options_ref = {binary => 1, sep_char => ","};    # should set binary attribute.

	my $csv = Text::CSV->new($csv_options_ref)
		or die("Cannot use CSV: " . Text::CSV->error_diag());

	if (open(my $io, "<:encoding($encoding)", $agribalyse_details_by_step_csv_file)) {

		my $row_ref;

		# Skip 3 first lines
		$csv->getline($io);
		$csv->getline($io);
		$csv->getline($io);

		while ($row_ref = $csv->getline($io)) {
			$agribalyse{$row_ref->[0]} = {
				code => $row_ref->[0],    # Agribalyse code = Ciqual code
				name_fr => $row_ref->[4],    # Nom du Produit en Français
				name_en => $row_ref->[5],    # LCI Name
				dqr => $row_ref->[6],    # DQR (data quality rating)
										 # warning: the AGB file has a hidden H column
				ef_agriculture => $row_ref->[8] + 0,    # Agriculture
				ef_processing => $row_ref->[9] + 0,    # Transformation
				ef_packaging => $row_ref->[10] + 0,    # Emballage
				ef_transportation => $row_ref->[11] + 0,    # Transport
				ef_distribution => $row_ref->[12] + 0,    # Supermarché et distribution
				ef_consumption => $row_ref->[13] + 0,    # Consommation
				ef_total => $row_ref->[14] + 0,    # Total
				co2_agriculture => $row_ref->[15] + 0,    # Agriculture
				co2_processing => $row_ref->[16] + 0,    # Transformation
				co2_packaging => $row_ref->[17] + 0,    # Emballage
				co2_transportation => $row_ref->[18] + 0,    # Transport
				co2_distribution => $row_ref->[19] + 0,    # Supermarché et distribution
				co2_consumption => $row_ref->[20] + 0,    # Consommation
				co2_total => $row_ref->[21] + 0,    # Total
				version => $agribalyse_version
			};
		}
	}
	else {
		die("Could not open agribalyse CSV $agribalyse_details_by_step_csv_file: $!");
	}

	$agribalyse_data_loaded = 1;

	return;
}

my %environmental_score_data = (origins => {},);

my %environmental_score_countries = ();

=head2 load_environmental_score_data_origins_of_ingredients_distances ( $product_ref )

Loads origins of ingredients distances data needed to compute the Environmental-Score.

=cut

sub load_environmental_score_data_origins_of_ingredients_distances() {

	my $errors = 0;

	my $csv_options_ref = {binary => 1, sep_char => ","};    # should set binary attribute.
	my $csv = Text::CSV->new($csv_options_ref)
		or die("Cannot use CSV: " . Text::CSV->error_diag());

	my $csv_file = $data_root . "/external-data/environmental_score/data/distances.csv";
	my $encoding = "UTF-8";

	$log->debug("opening environmental_score origins distances CSV file", {file => $csv_file}) if $log->is_debug();

	if (open(my $io, "<:encoding($encoding)", $csv_file)) {

		my @countries = ();

		# Headers: ISO Country Code,	Country (english),	Country (french),	AD,	AL,	AT,	AX,	BA,	BE,	BG,  ...
		my $header_row_ref = $csv->getline($io);

		for (my $i = 3; $i < (scalar @{$header_row_ref}); $i++) {
			$countries[$i] = lc($header_row_ref->[$i]);
			if ($countries[$i] eq 'gb') {
				$countries[$i] = 'uk';
			}
			$environmental_score_countries{$countries[$i]} = 1;
			# Score 0 for unknown origin
			$environmental_score_data{origins}{"en:unknown"}{"transportation_score_" . $countries[$i]} = 0;
		}
		# Score 0 for unspecified request country (world)
		$environmental_score_data{origins}{"en:unknown"}{"transportation_score_world"} = 0;
		my @environmental_score_countries_sorted = sort keys %environmental_score_countries;

		%environmental_score_countries_enabled = %environmental_score_countries;
		@environmental_score_countries_enabled_sorted = @environmental_score_countries_sorted;

		$environmental_score_data{origins}{"en:world"} = $environmental_score_data{origins}{"en:unknown"};
		$environmental_score_data{origins}{"en:european-union-and-non-european-union"}
			= $environmental_score_data{origins}{"en:unknown"};

		$log->debug(
			"environmental_score origins distances CSV file - countries header row",
			{environmental_score_countries_sorted => \@environmental_score_countries_sorted}
		) if $log->is_debug();

		my $row_ref;

		while ($row_ref = $csv->getline($io)) {

			my $origin = $row_ref->[0];

			next if ((not defined $origin) or ($origin eq ""));

			my $origin_id_exists_in_taxonomy;
			my $origin_id = canonicalize_taxonomy_tag("en", "origins", $origin, \$origin_id_exists_in_taxonomy);

			if (not $origin_id_exists_in_taxonomy) {

				$log->error(
					"environmental_score origin does not exist in taxonomy",
					{origin => $origin, origin_id => $origin_id}
				) if $log->is_error();
				$errors++;
			}

			$environmental_score_data{origins}{$origin_id} = {
				name_en => $row_ref->[1],
				name_fr => $row_ref->[2],
			};

			for (my $i = 3; $i < (scalar @{$row_ref}); $i++) {
				my $value = $row_ref->[$i];
				if ($value eq "") {
					$value = 0;
				}
				$environmental_score_data{origins}{$origin_id}{"transportation_score_" . $countries[$i]} = $value;
			}
			# Score 0 for unspecified request country (world)
			$environmental_score_data{origins}{$origin_id}{"transportation_score_world"} = 0;

			$log->debug(
				"environmental_score origins CSV file - row",
				{
					origin => $origin,
					origin_id => $origin_id,
					environmental_score_data => $environmental_score_data{origins}{$origin_id}
				}
			) if $log->is_debug();
		}

		if ($errors) {
			#die("$errors unrecognized origins in CSV $csv_file");
		}
	}
	else {
		die("Could not open environmental_score origins distances CSV $csv_file: $!");
	}
	return;
}

=head2 load_environmental_score_data_origins_of_ingredients( $product_ref )

Loads origins of ingredients data needed to compute the Environmental-Score.

Data contains:
- EPI score for each origin
- Original transportation score for France, as defined in Environmental-Score original specification
(distances in distances.csv have been recomputed in a slightly different way, and the 
scores for France slightly differ from the original ones)

=cut

sub load_environmental_score_data_origins_of_ingredients() {

	# First load transportation data from the distances.csv file

	load_environmental_score_data_origins_of_ingredients_distances();

	my $errors = 0;

	my $csv_options_ref = {binary => 1, sep_char => ","};    # should set binary attribute.
	my $csv = Text::CSV->new($csv_options_ref)
		or die("Cannot use CSV: " . Text::CSV->error_diag());

	my $csv_file = $data_root . "/external-data/environmental_score/data/fr_countries.csv";
	my $encoding = "UTF-8";

	$log->debug("opening environmental_score origins CSV file", {file => $csv_file}) if $log->is_debug();

	if (open(my $io, "<:encoding($encoding)", $csv_file)) {

		# headers: Pays	"Score Politique environnementale"	Score Transport - France	"Score Transport - Belgique"	"Score Transport - Allemagne"	"Score Transport - Irlande"	Score Transport - Italie	"Score Transport - Luxembourg"	"Score Transport - Pays-Bas"	"Score Transport - Espagne"	"Score Transport - Suisse"

		my $header_row_ref = $csv->getline($io);

		$environmental_score_data{origins}{"en:unknown"}{epi_score} = 0;

		$environmental_score_data{origins}{"en:world"} = $environmental_score_data{origins}{"en:unknown"};
		$environmental_score_data{origins}{"en:european-union-and-non-european-union"}
			= $environmental_score_data{origins}{"en:unknown"};

		my $row_ref;

		while ($row_ref = $csv->getline($io)) {

			my $origin = $row_ref->[0];

			next if ((not defined $origin) or ($origin eq ""));

			my $origin_id_exists_in_taxonomy;
			my $origin_id = canonicalize_taxonomy_tag("fr", "origins", $origin, \$origin_id_exists_in_taxonomy);

			if (not $origin_id_exists_in_taxonomy) {

				# Environmental-Score entries like "Macedonia [FYROM]": remove the [..] part
				# but keep it in the first try, as it is needed to distinguish "Congo [DRC]" and "Congo [Republic]"
				if ($origin =~ /^(.*)\[(.*)\]/) {
					$origin_id = canonicalize_taxonomy_tag("fr", "origins", $1, \$origin_id_exists_in_taxonomy);
					if (not $origin_id_exists_in_taxonomy) {
						$origin_id = canonicalize_taxonomy_tag("fr", "origins", $2, \$origin_id_exists_in_taxonomy);
					}
				}
			}

			# La Guyane Française -> Guyane Française
			if (not $origin_id_exists_in_taxonomy) {

				if ($origin =~ /^(la|les|l'|le)\s?(.*)$/i) {
					$origin_id = canonicalize_taxonomy_tag("fr", "origins", $2, \$origin_id_exists_in_taxonomy);
				}
			}

			if (not $origin_id_exists_in_taxonomy) {

				$log->error(
					"environmental_score origin does not exist in taxonomy",
					{origin => $origin, origin_id => $origin_id}
				) if $log->is_error();
				$errors++;
			}

			$environmental_score_data{origins}{$origin_id}{epi_score} = $row_ref->[1];

			# Override data for France from distances.csv with the original French Environmental-Score data for France
			$environmental_score_data{origins}{$origin_id}{"transportation_score_fr"} = $row_ref->[2];

			$log->debug(
				"environmental_score origins CSV file - row",
				{
					origin => $origin,
					origin_id => $origin_id,
					environmental_score_data => $environmental_score_data{origins}{$origin_id}
				}
			) if $log->is_debug();
		}

		if ($errors) {
			#die("$errors unrecognized origins in CSV $csv_file");
		}

		$environmental_score_data{origins}{"en:unspecified"} = $environmental_score_data{origins}{"en:unknown"};
	}
	else {
		die("Could not open environmental_score origins CSV $csv_file: $!");
	}
	return;
}

=head2 load_environmental_score_data_packaging( $product_ref )

Loads packaging data needed to compute the Environmental-Score.

=cut

sub load_environmental_score_data_packaging() {

	my $errors = 0;

	my $csv_options_ref = {binary => 1, sep_char => ","};    # should set binary attribute.
	my $csv = Text::CSV->new($csv_options_ref)
		or die("Cannot use CSV: " . Text::CSV->error_diag());

	# Packaging materials

	# Eco_score_Calculateur.csv is not up to date anymore, instead use a copy of the table in
	# https://docs.score-environnemental.com/methodologie/produit/emballages/score-par-materiaux
	# my $csv_file = $data_root . "/external-data/environmental_score/data/Eco_score_Calculateur.csv.11";
	my $csv_file = $data_root . "/external-data/environmental_score/data/fr_packaging_materials.csv";
	my $encoding = "UTF-8";

	$environmental_score_data{packaging_materials} = {};

	# We will also add the data as a property to the packaging_materials taxonomy so that we can use the get_inherited_property function
	defined $properties{"packaging_materials"} or $properties{"packaging_materials"} = {};

	$log->debug("opening environmental_score materials CSV file", {file => $csv_file}) if $log->is_debug();

	if (open(my $io, "<:encoding($encoding)", $csv_file)) {

		my $row_ref;

		# Skip first line
		$csv->getline($io);

		# headers: Matériaux,Score

		while ($row_ref = $csv->getline($io)) {

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

			my $material_id_exists_in_taxonomy;
			my $material_id
				= canonicalize_taxonomy_tag("fr", "packaging_materials", $material, \$material_id_exists_in_taxonomy);

			if (not $material_id_exists_in_taxonomy) {
				$log->error(
					"environmental_score material does not exist in taxonomy",
					{material => $material, material_id => $material_id}
				) if $log->is_error();
				$errors++;
			}

			# combine material + shape
			if (defined $shape) {
				$material_id = $material_id . "." . $shape;
			}

			$environmental_score_data{packaging_materials}{$material_id} = {
				name_fr => $row_ref->[0],    # Matériaux
				score => $row_ref->[1],    # Score
			};

			(defined $properties{"packaging_materials"}{$material_id})
				or $properties{"packaging_materials"}{$material_id} = {};
			$properties{"packaging_materials"}{$material_id}{"environmental_score_score:en"}
				= $environmental_score_data{packaging_materials}{$material_id}{score};

			$log->debug(
				"environmental_score materials CSV file - row",
				{
					material => $material,
					material_id => $material_id,
					environmental_score_data => $environmental_score_data{packaging_materials}{$material_id}
				}
			) if $log->is_debug();
		}

		if ($errors) {
			die("$errors unrecognized materials in CSV $csv_file");
		}

		# Extra assignments

		# "Bouteille PET transparente",62.5
		# "Bouteille PET coloré ou opaque",50
		# "Bouteille PET Biosourcé",75
		# "Bouteille rPET transparente (100%)",100

		# We assign the same score to some target material.shape as a source material.shape
		# Use English names for source / target shapes and materials
		# they will be canonicalized with the taxonomies
		my @assignments = (
			{
				target_shape => "bottle",
				target_material => "opaque pet",
				source_shape => "bottle",
				source_material => "colored pet"
			},
			{
				target_shape => "bottle",
				target_material => "polyethylene terephthalate",
				source_shape => "bottle",
				source_material => "colored pet"
			},
			# Assign transparent rPET bottle score to rPET
			{
				target_shape => "bottle",
				target_material => "rpet",
				source_shape => "bottle",
				source_material => "transparent rpet"
			},
			{
				target_material => "plastic",
				source_material => "other plastics"
			},
		);

		foreach my $assignment_ref (@assignments) {

			# We canonicalize the names given in the assignments, as the taxonomies can change over time, including the canonical names
			my $target_material
				= canonicalize_taxonomy_tag_or_die("en", "packaging_materials", $assignment_ref->{target_material},);

			my $source_material
				= canonicalize_taxonomy_tag_or_die("en", "packaging_materials", $assignment_ref->{source_material},);

			my $target = $target_material;
			my $source = $source_material;

			if (defined $assignment_ref->{target_shape}) {
				my $target_shape
					= canonicalize_taxonomy_tag_or_die("en", "packaging_shapes", $assignment_ref->{target_shape},);

				my $source_shape
					= canonicalize_taxonomy_tag_or_die("en", "packaging_shapes", $assignment_ref->{source_shape},);

				$target .= '.' . $target_shape;
				$source .= '.' . $source_shape;
			}

			if (defined $environmental_score_data{packaging_materials}{$source}) {
				$environmental_score_data{packaging_materials}{$target}
					= $environmental_score_data{packaging_materials}{$source};
				$properties{packaging_materials}{$target}{"environmental_score_score:en"}
					= $environmental_score_data{packaging_materials}{$source}{"score"};
			}
			else {
				die("source of assignement $source does not have Environmental-Score data");
			}
		}
	}
	else {
		die("Could not open environmental_score materials CSV $csv_file: $!");
	}

	$log->debug("environmental_score packaging_materials data",
		{packaging_materials => $environmental_score_data{packaging_materials}})
		if $log->is_debug();

	# Packaging shapes / formats

	$csv_file = $data_root . "/external-data/environmental_score/data/Eco_score_Calculateur.csv.12";
	$csv_file = $data_root . "/external-data/environmental_score/data/fr_packaging_shapes.csv";
	$encoding = "UTF-8";

	$environmental_score_data{packaging_shapes} = {};

	# We will also add the data as a property to the packaging_shapes taxonomy so that we can use the get_inherited_property function
	defined $properties{"packaging_shapes"} or $properties{"packaging_shapes"} = {};

	$log->debug("opening environmental_score shapes CSV file", {file => $csv_file}) if $log->is_debug();

	if (open(my $io, "<:encoding($encoding)", $csv_file)) {

		my $row_ref;

		# Skip first line
		$csv->getline($io);

		# headers: Format,Ratio

		while ($row_ref = $csv->getline($io)) {

			my $shape = $row_ref->[0];

			# skip empty lines and comments
			next if ((not defined $shape) or ($shape eq "")) or ($shape =~ /^#/);

			# Special cases

			# skip ondulated cardboard (should be a material)
			next if ($shape eq "Carton ondulé");

			my $shape_id_exists_in_taxonomy;
			my $shape_id = canonicalize_taxonomy_tag("fr", "packaging_shapes", $shape, \$shape_id_exists_in_taxonomy);

			# Handle special cases that are not recognized by the packaging shapes taxonomy
			# conserve is used in preservation taxonomy, but it may be a packaging
			if ($shape_id =~ /^fr:conserve/i) {
				$shape_id = "en:can";
				$shape_id_exists_in_taxonomy = 1;
			}

			if (not $shape_id_exists_in_taxonomy) {
				$log->error("environmental_score shape does not exist in taxonomy",
					{shape => $shape, shape_id => $shape_id})
					if $log->is_error();
				$errors++;
			}

			$environmental_score_data{packaging_shapes}{$shape_id} = {
				name_fr => $row_ref->[0],    # Format
				ratio => $row_ref->[1],    # Ratio
			};

			# if the ratio has a comma (0,2), turn it to a dot (0.2)
			$environmental_score_data{packaging_shapes}{$shape_id}{ratio} =~ s/,/\./;

			(defined $properties{"packaging_shapes"}{$shape_id}) or $properties{"packaging_shapes"}{$shape_id} = {};
			$properties{"packaging_shapes"}{$shape_id}{"environmental_score_ratio:en"}
				= $environmental_score_data{packaging_shapes}{$shape_id}{ratio};

			$log->debug(
				"environmental_score shapes CSV file - row",
				{
					shape => $shape,
					shape_id => $shape_id,
					environmental_score_data => $environmental_score_data{packaging_shapes}{$shape_id}
				}
			) if $log->is_debug();
		}

		if ($errors) {
			die("$errors unrecognized shapes in CSV $csv_file");
		}

		# Extra assignments

		$environmental_score_data{packaging_shapes}{"en:can"}
			= $environmental_score_data{packaging_shapes}{"en:drink-can"};
		$properties{"packaging_shapes"}{"en:can"}{"environmental_score_ratio:en"}
			= $environmental_score_data{packaging_shapes}{"en:can"}{ratio};

		$environmental_score_data{packaging_shapes}{"en:card"}
			= $environmental_score_data{packaging_shapes}{"en:backing"};
		$properties{"packaging_shapes"}{"en:card"}{"environmental_score_ratio:en"}
			= $environmental_score_data{packaging_shapes}{"en:backing"}{ratio};

		$environmental_score_data{packaging_shapes}{"en:label"}
			= $environmental_score_data{packaging_shapes}{"en:sheet"};
		$properties{"packaging_shapes"}{"en:label"}{"environmental_score_ratio:en"}
			= $environmental_score_data{packaging_shapes}{"en:sheet"}{ratio};

		$environmental_score_data{packaging_shapes}{"en:spout"}
			= $environmental_score_data{packaging_shapes}{"en:bottle-cap"};
		$properties{"packaging_shapes"}{"en:spout"}{"environmental_score_ratio:en"}
			= $environmental_score_data{packaging_shapes}{"en:bottle-cap"}{ratio};

		$environmental_score_data{packaging_shapes}{"xx:elo-pak"}
			= $environmental_score_data{packaging_shapes}{"en:tetra-pak"};
		$properties{"packaging_shapes"}{"xx:elo-pak"}{"environmental_score_ratio:en"}
			= $environmental_score_data{packaging_shapes}{"en:tetra-pak"}{ratio};
	}
	else {
		die("Could not open environmental_score shapes CSV $csv_file: $!");
	}

	$log->debug("environmental_score packaging_shapes data",
		{packaging_materials => $environmental_score_data{packaging_shapes}})
		if $log->is_debug();
	return;
}

=head2 load_environmental_score_data( $product_ref )

Loads data needed to compute the Environmental-Score.

=cut

sub load_environmental_score_data() {

	load_environmental_score_data_origins_of_ingredients();
	load_environmental_score_data_packaging();

	$environmental_score_data_loaded = 1;
	return;
}

=head2 compute_environmental_score( $product_ref )

C<compute_environmental_score()> computes the Environmental-Score of a food product, and stores the details of the computation.

=head3 Arguments

=head4 Product reference $product_ref

=head3 Return values

The Environmental-Score score and computations details are stored in the product reference passed as input parameter.

Returned values:

- environmental_score_score : numeric Environmental-Score value
- environmental_score_grade : corresponding A to E grade
- environmental_score_data : Environmental-Score computation details

=cut

sub compute_environmental_score ($product_ref) {

	# Some test cases do not load the Environmental-Score data (e.g. food.t) as they don't test the Environmental-Score
	# but compute_environmental_score() is still called by specific_processes_for_food_product($product_ref);
	# So we check if the data is loaded, and do not compute the Environmental-Score if not loaded
	if (not($environmental_score_data_loaded and $agribalyse_data_loaded)) {
		$log->warn("Environmental-Score data not loaded, cannot compute Environmental-Score") if $log->is_warn();
		return;
	}

	my $old_environmental_score_data = $product_ref->{environmental_score_data};
	my $old_agribalyse = $old_environmental_score_data->{agribalyse};
	my $old_environmental_score_grade = $old_environmental_score_data->{grade};
	my $old_environmental_score_score = $old_environmental_score_data->{score};
	my $old_previous_data = $old_environmental_score_data->{previous_data};

	delete $product_ref->{environmental_score_grade};
	delete $product_ref->{environmental_score_score};
	delete $product_ref->{downgraded};

	$product_ref->{environmental_score_data} = {adjustments => {},};

	remove_tag($product_ref, "misc", "en:environmental-score-computed");
	remove_tag($product_ref, "misc", "en:environmental-score-missing-data-warning");
	remove_tag($product_ref, "misc", "en:environmental-score-missing-data-no-packagings");
	foreach my $missing (qw(labels origins packagings)) {
		remove_tag($product_ref, "misc", "en:environmental-score-missing-data-" . $missing);
	}
	remove_tag($product_ref, "misc", "en:environmental-score-no-missing-data");
	remove_tag($product_ref, "misc", "en:environmental-score-not-applicable");
	remove_tag($product_ref, "misc", "en:environmental-score-changed");
	remove_tag($product_ref, "misc", "en:environmental-score-grade-changed");
	remove_tag($product_ref, "misc", "en:environmental-score-score-above-100");
	remove_tag($product_ref, "misc", "en:environmental-score-downgraded");

	# Check if we have extended environmental_score_data from the impact estimator
	# Remove any misc "en:environmental-score-extended-data-version-[..]" tags
	if (defined $product_ref->{misc_tags}) {
		foreach my $tag (@{$product_ref->{misc_tags}}) {
			if ($tag =~ /^en:environmental-score-extended-data/) {
				remove_tag($product_ref, "misc", $tag);
			}
		}
	}

	# 2024/12 ecoscore fields were renamed to environmental_score fields
	# remove ecoscore fields

	delete $product_ref->{ecoscore_grade};
	delete $product_ref->{ecoscore_score};

	delete $product_ref->{ecoscore_data};

	remove_tag($product_ref, "misc", "en:ecoscore-computed");
	remove_tag($product_ref, "misc", "en:ecoscore-missing-data-warning");
	remove_tag($product_ref, "misc", "en:ecoscore-missing-data-no-packagings");
	foreach my $missing (qw(labels origins packagings)) {
		remove_tag($product_ref, "misc", "en:ecoscore-missing-data-" . $missing);
	}
	remove_tag($product_ref, "misc", "en:ecoscore-no-missing-data");
	remove_tag($product_ref, "misc", "en:ecoscore-not-applicable");
	remove_tag($product_ref, "misc", "en:ecoscore-changed");
	remove_tag($product_ref, "misc", "en:ecoscore-grade-changed");
	remove_tag($product_ref, "misc", "en:ecoscore-score-above-100");
	remove_tag($product_ref, "misc", "en:ecoscore-downgraded");

	# Special case for waters and sodas: disable the Environmental-Score

	my @categories_without_environmental_score
		= ("en:waters", "en:sodas", "en:energy-drinks", "en:fresh-vegetables", "en:fresh-fruits");
	my $category_without_environmental_score;

	foreach my $category (@categories_without_environmental_score) {
		if (has_tag($product_ref, 'categories', $category)) {
			$category_without_environmental_score = $category;
			last;
		}
	}

	# Always compute the bonuses and maluses, even for categories that don't have Environmental-Score
	# (e.g. sodas, spring water)

	compute_environmental_score_production_system_adjustment($product_ref);
	compute_environmental_score_threatened_species_adjustment($product_ref);
	compute_environmental_score_origins_of_ingredients_adjustment($product_ref);
	compute_environmental_score_packaging_adjustment($product_ref);

	if ($category_without_environmental_score) {
		$product_ref->{environmental_score_data}{environmental_score_not_applicable_for_category}
			= $category_without_environmental_score;
		$product_ref->{environmental_score_data}{status} = "unknown";
		$product_ref->{environmental_score_tags} = ["not-applicable"];
		$product_ref->{environmental_score_grade} = "not-applicable";
		$product_ref->{environmental_score_data}{grade} = "not-applicable";

		add_tag($product_ref, "misc", "en:environmental-score-not-applicable");
		add_tag($product_ref, "misc", "en:environmental-score-not-computed");
	}
	else {
		# Compute the LCA Environmental-Score based on AgriBalyse

		compute_environmental_score_agribalyse($product_ref);

		# Compute the final Environmental-Score and assign the A to E grade

		# We need an AgriBalyse category match to compute the Environmental-Score
		# Note: the score can be 0
		if (defined $product_ref->{environmental_score_data}{agribalyse}{score}) {

			$product_ref->{environmental_score_data}{status} = "known";

			my $missing_data_warning;

			$product_ref->{environmental_score_data}{scores} = {};
			$product_ref->{environmental_score_data}{grades} = {};

			# Compute the Environmental-Score for all countries + world (with 0 for the transportation bonus)
			foreach my $cc (@environmental_score_countries_enabled_sorted, "world") {

				$product_ref->{environmental_score_data}{"scores"}{$cc}
					= $product_ref->{environmental_score_data}{agribalyse}{score};

				$log->debug("compute_environmental_score - agribalyse score",
					{cc => $cc, agribalyse_score => $product_ref->{environmental_score_data}{agribalyse}{score}})
					if $log->is_debug();

				# Add adjustments (maluses or bonuses)

				my $bonus = 0;

				foreach my $adjustment (keys %{$product_ref->{environmental_score_data}{adjustments}}) {

					my $value;
					if (    (defined $cc)
						and (defined $product_ref->{environmental_score_data}{adjustments}{$adjustment}{"values"})
						and (defined $product_ref->{environmental_score_data}{adjustments}{$adjustment}{"values"}{$cc}))
					{
						$value = $product_ref->{environmental_score_data}{adjustments}{$adjustment}{"values"}{$cc};
					}
					elsif (defined $product_ref->{environmental_score_data}{adjustments}{$adjustment}{"value"}) {
						$value = $product_ref->{environmental_score_data}{adjustments}{$adjustment}{"value"};
					}

					if (defined $value) {
						$bonus += $value;
						$log->debug(
							"compute_environmental_score - add adjustment",
							{
								adjustment => $adjustment,
								value => $value
							}
						) if $log->is_debug();
					}
					if (defined $product_ref->{environmental_score_data}{adjustments}{$adjustment}{warning}) {
						$missing_data_warning = 1;
					}
				}

				# The sum of the bonuses is capped at 25
				if ($bonus > 25) {
					$bonus = 25;
				}

				$product_ref->{environmental_score_data}{"scores"}{$cc} += $bonus;

				# Assign A+ to F grade
				# SI(AO3>=90;"A+";SI(AO3>=75;"A";SI(AO3>=60;"B";SI(AO3>=45;"C";SI(AO3>=30;"D";SI(AO3>=15;"E";"F"))))));"")

				if ($product_ref->{environmental_score_data}{"scores"}{$cc} >= 90) {
					$product_ref->{environmental_score_data}{"grades"}{$cc} = "a-plus";
				}
				elsif ($product_ref->{environmental_score_data}{"scores"}{$cc} >= 75) {
					$product_ref->{environmental_score_data}{"grades"}{$cc} = "a";
				}
				elsif ($product_ref->{environmental_score_data}{"scores"}{$cc} >= 60) {
					$product_ref->{environmental_score_data}{"grades"}{$cc} = "b";
				}
				elsif ($product_ref->{environmental_score_data}{"scores"}{$cc} >= 45) {
					$product_ref->{environmental_score_data}{"grades"}{$cc} = "c";
				}
				elsif ($product_ref->{environmental_score_data}{"scores"}{$cc} >= 30) {
					$product_ref->{environmental_score_data}{"grades"}{$cc} = "d";
				}
				elsif ($product_ref->{environmental_score_data}{"scores"}{$cc} >= 15) {
					$product_ref->{environmental_score_data}{"grades"}{$cc} = "e";
				}
				else {
					$product_ref->{environmental_score_data}{"grades"}{$cc} = "f";
				}

				$log->debug(
					"compute_environmental_score - final score and grade",
					{
						score => $product_ref->{environmental_score_data}{"scores"}{$cc},
						grade => $product_ref->{environmental_score_data}{"grades"}{$cc}
					}
				) if $log->is_debug();
			}

			# The following values correspond to the Environmental-Score for France.
			# at run-time, they may be changed to the values for a specific country
			# after localize_environmental_score() is called

			# The environmental_score_tags used for the /environmental_score facet and the environmental_score_score used for sorting by Environmental-Score
			# can only have 1 value.
			# Unfortunately there is a MongoDB index limit and we cannot create a different set of field
			# for each country.

			$product_ref->{environmental_score_data}{"score"}
				= $product_ref->{environmental_score_data}{"scores"}{"fr"};
			$product_ref->{environmental_score_data}{"grade"}
				= $product_ref->{environmental_score_data}{"grades"}{"fr"};
			$product_ref->{"environmental_score_score"} = $product_ref->{environmental_score_data}{"scores"}{"fr"};
			$product_ref->{"environmental_score_grade"} = $product_ref->{environmental_score_data}{"grades"}{"fr"};
			$product_ref->{"environmental_score_tags"} = [$product_ref->{environmental_score_grade}];

			if ($product_ref->{environmental_score_data}{"downgraded"}) {
				add_tag($product_ref, "misc", "en:environmental-score-downgraded");
			}
			if (
				(
					$product_ref->{environmental_score_data}{scores}{fr_orig}
					// $product_ref->{environmental_score_data}{scores}{fr}
				) > 100
				)
			{
				add_tag($product_ref, "misc", "en:environmental-score-score-above-100");
			}

			if ($missing_data_warning) {
				$product_ref->{environmental_score_data}{missing_data_warning} = 1;
				add_tag($product_ref, "misc", "en:environmental-score-missing-data-warning");

				# add facets for missing data
				foreach my $missing (qw(labels origins packagings)) {
					if (deep_exists($product_ref, "environmental_score_data", "missing", $missing)) {
						add_tag($product_ref, "misc", "en:environmental-score-missing-data-" . $missing);
					}
				}

				# environmental-score-missing-data-packagings will also be triggered when we have some packaging data that is not complete
				# e.g. we have a shape like "bottle" but no associated material
				# also add a facet when we have no packaging information at all
				my $packaging_warning
					= deep_get($product_ref, qw(environmental_score_data adjustments packaging warning));
				if ((defined $packaging_warning) and ($packaging_warning eq "packaging_data_missing")) {
					add_tag($product_ref, "misc", "en:environmental-score-missing-data-no-packagings");
				}

			}

			add_tag($product_ref, "misc", "en:environmental-score-computed");
		}
		else {
			# No AgriBalyse category match
			$product_ref->{environmental_score_data}{missing_agribalyse_match_warning} = 1;
			$product_ref->{environmental_score_data}{status} = "unknown";
			$product_ref->{environmental_score_tags} = ["unknown"];
			$product_ref->{environmental_score_grade} = "unknown";
			$product_ref->{environmental_score_data}{grade} = "unknown";

			add_tag($product_ref, "misc", "en:environmental-score-not-computed");
		}
	}

	# Track if environmental_score has changed through different Agribalyse versions
	# Don't overwrite previous_data from before. This should be manually cleared
	# before each version upgrade
	if (defined $old_previous_data) {
		$product_ref->{environmental_score_data}{previous_data} = $old_previous_data;
		$old_environmental_score_grade = $old_previous_data->{grade};
		$old_environmental_score_score = $old_previous_data->{score};
	}
	if (defined $old_environmental_score_score || defined $product_ref->{environmental_score_score}) {
		if (!defined $old_environmental_score_score
			|| $old_environmental_score_score != $product_ref->{environmental_score_score})
		{
			if (!defined $old_previous_data && defined $old_agribalyse) {
				$product_ref->{environmental_score_data}{previous_data} = {
					grade => $old_environmental_score_grade,
					score => $old_environmental_score_score,
					agribalyse => $old_agribalyse
				};
			}
			add_tag($product_ref, "misc", "en:environmental-score-changed");
			if (!defined $old_environmental_score_grade
				|| $old_environmental_score_grade ne $product_ref->{environmental_score_grade})
			{
				add_tag($product_ref, "misc", "en:environmental-score-grade-changed");
			}
		}
	}

	# Before 2025, the Environmental Score was called the Eco-Score.
	# to ease the transition, we copy environmental_score_tags to eco_score_tags
	# so that queries to MongoDB and off-query do not have to change
	if (defined $product_ref->{environmental_score_tags}) {
		$product_ref->{ecoscore_tags} = $product_ref->{environmental_score_tags};
	}

	return;
}

=head2 compute_environmental_score_agribalyse ( $product_ref )

C<compute_environmental_score()> computes the Life Cycle Analysis (LCA) part of the Environmental-Score,
based on the French AgriBalyse database.

=head3 Arguments

=head4 Product reference $product_ref

=head3 Return values

The LCA score and computations details are stored in the product reference passed as input parameter.

Returned values:

$product_ref->{agribalyse} hash with:
- 

$product_ref->{environmental_score_data}{missing} hash with:
- categories if the product does not have a category
- agb_category if the product does not have an Agribalyse match
or proxy match for at least one of its categories.

=cut

sub compute_environmental_score_agribalyse ($product_ref) {

	$product_ref->{environmental_score_data}{agribalyse} = {};

	# Check the input data

	# Check if one of the product categories has an Agribalyse match or proxy match

	my $agb;    # match or proxy match
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
			$product_ref->{environmental_score_data}{agribalyse} = $agribalyse{$agb_match};
			$product_ref->{environmental_score_data}{agribalyse}{agribalyse_food_code} = $agb_match;
			$agb = $agb_match;
		}
		elsif ($agb_proxy_match) {
			$product_ref->{environmental_score_data}{agribalyse} = $agribalyse{$agb_proxy_match};
			$product_ref->{environmental_score_data}{agribalyse}{agribalyse_proxy_food_code} = $agb_proxy_match;
			$agb = $agb_proxy_match;
		}
		else {
			defined $product_ref->{environmental_score_data}{missing}
				or $product_ref->{environmental_score_data}{missing} = {};
			$product_ref->{environmental_score_data}{missing}{agb_category} = 1;
		}
	}
	else {
		defined $product_ref->{environmental_score_data}{missing}
			or $product_ref->{environmental_score_data}{missing} = {};
		$product_ref->{environmental_score_data}{missing}{categories} = 1;
	}

	# Compute the Environmental-Score on a 0 to 100 scale

	if ($agb) {

		if (not defined $agribalyse{$agb}{ef_total}) {
			$log->error("compute_environmental_score - ef_total missing for category",
				{agb => $agb, agribalyse => $agribalyse{$agb}})
				if $log->is_error();
		}
		else {
			# Formula to transform the Environmental Footprint single score to a 0 to 100 scale
			# Note: EF score are for mPt / kg in Agribalyse, we need it in micro points per 100g

			# Milk is considered to be a beverage
			if (has_tag($product_ref, 'categories', 'en:beverages')
				or (has_tag($product_ref, 'categories', 'en:milks')))
			{
				# Beverages case: score = -36*\ln(x+1)+150score=− 36 * ln(x+1) + 150
				$product_ref->{environmental_score_data}{agribalyse}{is_beverage} = 1;
				$product_ref->{environmental_score_data}{agribalyse}{score}
					= 0 + round(-36 * log($agribalyse{$agb}{ef_total} * (1000 / 10) + 1) + 150);
			}
			else {
				# 2021-02-17: new updated formula: 100-(20 * ln(10*x+1))/ln(2+ 1/(100*x*x*x*x))  - with x in MPt / kg.
				$product_ref->{environmental_score_data}{agribalyse}{is_beverage} = 0;
				$product_ref->{environmental_score_data}{agribalyse}{score} = 0 + round(
					100 - 20 * log(10 * $agribalyse{$agb}{ef_total} + 1) / log(
						2 + 1 / (
								  100 * $agribalyse{$agb}{ef_total}
								* $agribalyse{$agb}{ef_total}
								* $agribalyse{$agb}{ef_total}
								* $agribalyse{$agb}{ef_total}
						)
					)
				);
			}
			if ($product_ref->{environmental_score_data}{agribalyse}{score} < 0) {
				$product_ref->{environmental_score_data}{agribalyse}{score} = 0;
			}
			elsif ($product_ref->{environmental_score_data}{agribalyse}{score} > 100) {
				$product_ref->{environmental_score_data}{agribalyse}{score} = 100;
			}
		}
	}
	else {
		$product_ref->{environmental_score_data}{agribalyse}{warning} = "missing_agribalyse_match";
	}
	return;
}

=head2 compute_environmental_score_production_system_adjustment ( $product_ref )

Computes an adjustment (bonus or malus) based on production system of the product (e.g. organic).

=head3 Arguments

=head4 Product reference $product_ref

=head3 Return values

The adjustment value and computations details are stored in the product reference passed as input parameter.

Returned values:

$product_ref->{adjustments}{production_system} hash with:
- 

$product_ref->{environmental_score_data}{missing} hash with:

=head3 Notes

This function tests the presence of specific labels and categories that should not be renamed.
They are listed in the t/environmental_score.t test file so that the test fail if they are renamed.

The labels are listed in the Environmental-Score documentation:
https://docs.score-environnemental.com/methodologie/produit/label

=cut

my @production_system_labels = (
	["fr:nature-et-progres", 20],
	["fr:bio-coherence", 20],
	["en:demeter", 20],

	["fr:ab-agriculture-biologique", 15],
	["en:eu-organic", 15],
	# Environmental-Score documentation: "Techniques de pêche durables : ligne et hameçon, pêche à la canne, casier, pêche à pied."
	["en:sustainable-fishing-method", 15],

	["fr:haute-valeur-environnementale", 10],
	["en:utz-certified", 10],
	["en:rainforest-alliance", 10],
	["en:fairtrade-international", 10],
	["fr:bleu-blanc-coeur", 10],
	["fr:label-rouge", 10],
	["en:sustainable-seafood-msc", 10],
	["en:responsible-aquaculture-asc", 10],
);

my $production_system_labels_initialized = 0;

sub init_production_system_labels () {

	return if $production_system_labels_initialized;

	# Canonicalize the labels
	foreach my $label_ref (@production_system_labels) {

		# Canonicalize the label ids in case the normalized id changed
		$label_ref->[0] = canonicalize_taxonomy_tag("en", "labels", $label_ref->[0]);
	}
	$production_system_labels_initialized = 1;

	return;
}

sub compute_environmental_score_production_system_adjustment ($product_ref) {

	init_production_system_labels();

	$product_ref->{environmental_score_data}{adjustments}{production_system} = {value => 0, labels => []};

	foreach my $label_ref (@production_system_labels) {

		my ($label, $value) = @$label_ref;

		if (
			has_tag($product_ref, "labels", $label)
			# Label Rouge labels is counted only for beef, veal and lamb
			and (  ($label ne "fr:label-rouge")
				or (has_tag($product_ref, "categories", "en:beef"))
				or (has_tag($product_ref, "categories", "en:veal-meat"))
				or (has_tag($product_ref, "categories", "en:lamb-meat")))
			)
		{

			push @{$product_ref->{environmental_score_data}{adjustments}{production_system}{labels}}, $label;

			# Don't count the points for en:eu-organic if we already have fr:ab-agriculture-biologique
			# and for ASC if we already have MSC
			if (
				(
					($label ne "en:eu-organic")
					or not(has_tag($product_ref, "labels", "fr:ab-agriculture-biologique"))
				)
				and (($label ne "en:sustainable-seafood-msc")
					or not(has_tag($product_ref, "labels", "en:sustainable-fishing-method")))
				and (
					($label ne "en:responsible-aquaculture-asc")
					or not(has_tag($product_ref, "labels", "en:sustainable-seafood-msc")
						or has_tag($product_ref, "labels", "en:sustainable-fishing-method"))
				)
				)
			{
				$product_ref->{environmental_score_data}{adjustments}{production_system}{value} += $value;
			}
		}

		if ($product_ref->{environmental_score_data}{adjustments}{production_system}{value} > 20) {
			$product_ref->{environmental_score_data}{adjustments}{production_system}{value} = 20;
		}
	}

	# No labels warning
	if ($product_ref->{environmental_score_data}{adjustments}{production_system}{value} == 0) {
		$product_ref->{environmental_score_data}{adjustments}{production_system}{warning} = "no_label";
		defined $product_ref->{environmental_score_data}{missing}
			or $product_ref->{environmental_score_data}{missing} = {};
		$product_ref->{environmental_score_data}{missing}{labels} = 1;
	}
	return;
}

=head2 compute_environmental_score_threatened_species_adjustment ( $product_ref )

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

sub compute_environmental_score_threatened_species_adjustment ($product_ref) {

	$product_ref->{environmental_score_data}{adjustments}{threatened_species} = {};

	# Products that contain palm oil that is not certified RSPO

	if ((has_tag($product_ref, "ingredients_analysis", "en:palm-oil"))
		and not(has_tag($product_ref, "labels", "en:roundtable-on-sustainable-palm-oil")))
	{

		$product_ref->{environmental_score_data}{adjustments}{threatened_species}{value} = -10;
		$product_ref->{environmental_score_data}{adjustments}{threatened_species}{ingredient} = "en:palm-oil";
	}

	# No ingredients warning
	if ((not defined $product_ref->{ingredients}) or (scalar @{$product_ref->{ingredients}} == 0)) {
		$product_ref->{environmental_score_data}{adjustments}{threatened_species}{warning} = "ingredients_missing";
		defined $product_ref->{environmental_score_data}{missing}
			or $product_ref->{environmental_score_data}{missing} = {};
		$product_ref->{environmental_score_data}{missing}{ingredients} = 1;
	}
	return;
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

sub aggregate_origins_of_ingredients ($default_origins_ref, $aggregated_origins_ref, $ingredients_ref) {

	# The ingredients array contains sub-ingredients in nested ingredients

	foreach my $ingredient_ref (@$ingredients_ref) {

		my $ingredient_origins_ref;

		# If the ingredient has specified origins, use them
		if (defined $ingredient_ref->{origins}) {
			$ingredient_origins_ref = [split(/,/, $ingredient_ref->{origins})];
			$log->debug("aggregate_origins_of_ingredients - ingredient has specified origins",
				{ingredient_id => $ingredient_ref->{id}, ingredient_origins_ref => $ingredient_origins_ref})
				if $log->is_debug();
		}
		# Otherwise, if the ingredient has sub ingredients, use the origins of the sub ingredients
		elsif (defined $ingredient_ref->{ingredients}) {
			$log->debug("aggregate_origins_of_ingredients - ingredient has subingredients",
				{ingredient_id => $ingredient_ref->{id}})
				if $log->is_debug();
			aggregate_origins_of_ingredients($default_origins_ref, $aggregated_origins_ref,
				$ingredient_ref->{ingredients});
		}
		# Else use default origins
		else {
			$ingredient_origins_ref = $default_origins_ref;
			$log->debug("aggregate_origins_of_ingredients - use default origins",
				{ingredient_id => $ingredient_ref->{id}, ingredient_origins_ref => $ingredient_origins_ref})
				if $log->is_debug();
		}

		# If we are not using the origins of the sub ingredients,
		# aggregate the origins of the ingredient
		if (defined $ingredient_origins_ref) {
			$log->debug("aggregate_origins_of_ingredients - adding origins",
				{ingredient_id => $ingredient_ref->{id}, ingredient_origins_ref => $ingredient_origins_ref})
				if $log->is_debug();
			foreach my $origin_id (@$ingredient_origins_ref) {
				if (not defined $environmental_score_data{origins}{$origin_id}) {

					# If the origin is a child of a country, use the country
					my $country_code = get_inherited_property("origins", $origin_id, "country_code_2:en");

					if (
						(defined $country_code)
						and (
							defined $environmental_score_data{origins}
							{canonicalize_taxonomy_tag("en", "origins", $country_code)})
						)
					{
						$origin_id = canonicalize_taxonomy_tag("en", "origins", $country_code);
					}
					else {
						$origin_id = "en:unknown";
					}
				}
				defined $aggregated_origins_ref->{$origin_id} or $aggregated_origins_ref->{$origin_id} = 0;
				$aggregated_origins_ref->{$origin_id}
					+= $ingredient_ref->{percent_estimate} / scalar(@$ingredient_origins_ref);
			}
		}
	}
	return;
}

=head2 get_country_origin_from_origins ( $origins_ref )

Given a list of origins, return the country for the first origin that is a country or a child of a country.

=cut

sub get_country_origin_from_origins ($origins_ref) {

	foreach my $origin_id (@$origins_ref) {

		# If the origin is a child of a country, use the country
		my $country_code = get_inherited_property("origins", $origin_id, "country_code_2:en");

		if (    (defined $country_code)
			and (defined $environmental_score_data{origins}{canonicalize_taxonomy_tag("en", "origins", $country_code)}))
		{
			return canonicalize_taxonomy_tag("en", "origins", $country_code);
		}
	}
	return;
}

=head2 compute_environmental_score_origins_of_ingredients_adjustment ( $product_ref )

Computes adjustments(bonus or malus for transportation + EPI / Environmental Performance Index) 
according to the countries of origin of the ingredients.

The transportation bonus or malus is computed for all the countries where the Environmental-Score is enabled.

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

Note: the country EPI is not taken into account if the product already has a bonus for the production system.

=cut

sub compute_environmental_score_origins_of_ingredients_adjustment ($product_ref) {

	# First parse the "origins" field to see which countries are listed
	# Ignore entries that are not recognized or that do not have Environmental-Score values (only countries and continents)

	my @origins_from_origins_field = ();

	if (defined $product_ref->{origins_tags}) {
		foreach my $origin_id (@{$product_ref->{origins_tags}}) {
			if (defined $environmental_score_data{origins}{$origin_id}) {
				push @origins_from_origins_field, $origin_id;
			}
		}
	}

	# Check if we have categories with an origins:en property (e.g. French wines -> origins:en:france)
	my @origins_from_categories = ();

	if (defined $product_ref->{categories_tags}) {
		foreach my $category (@{$product_ref->{categories_tags}}) {
			my $origin_id = get_property("categories", $category, "origins:en");
			if (defined $origin_id) {
				# There may be multiple comma separated origins, and they might not be canonical
				# so we split them and canonicalize them
				push @origins_from_categories,
					map ({canonicalize_taxonomy_tag("en", "origins", $_)} split(',', $origin_id));
			}
		}
	}
	my $origin_from_categories = get_country_origin_from_origins(\@origins_from_categories);
	if (defined $origin_from_categories) {
		@origins_from_categories = ($origin_from_categories);
	}

	# If we don't have ingredients, check if we have an origin for a specific ingredient
	# (e.g. we have the label "French eggs" even though we don't have ingredients)
	if (    (scalar @origins_from_origins_field == 0)
		and ((not defined $product_ref->{ingredients}) or (scalar @{$product_ref->{ingredients}} == 0)))
	{
		my $origin_id = has_specific_ingredient_property($product_ref, undef, "origins");
		if ((defined $origin_id) and (defined $environmental_score_data{origins}{$origin_id})) {
			push @origins_from_origins_field, $origin_id;
		}
	}

	# If we have origins from the origins field and from the categories, we will use the origins from the origins field
	my $default_origins_ref = \@origins_from_categories;

	if (scalar @origins_from_origins_field == 0) {
		@origins_from_origins_field = ("en:unknown");
	}
	else {
		$default_origins_ref = \@origins_from_origins_field;
	}

	if (scalar @origins_from_categories == 0) {
		@origins_from_categories = ("en:unknown");
	}

	$log->debug(
		"compute_environmental_score_origins_of_ingredients_adjustment - origins field",
		{
			origins_tags => $product_ref->{origins_tags},
			origins_from_origins_field => \@origins_from_origins_field,
			origins_from_categories => \@origins_from_categories
		}
	) if $log->is_debug();

	# Sum the % values/estimates of all ingredients by origins

	my %aggregated_origins = ();

	if ((defined $product_ref->{ingredients}) and (scalar @{$product_ref->{ingredients}} > 0)) {
		aggregate_origins_of_ingredients($default_origins_ref, \%aggregated_origins, $product_ref->{ingredients});
	}
	else {
		# If we don't have ingredients listed, apply the origins from the origins field
		# using a dummy ingredient

		aggregate_origins_of_ingredients($default_origins_ref, \%aggregated_origins, [{percent_estimate => 100}]);
	}

	# Compute the transportation and EPI values and a sorted list of aggregated origins

	my @aggregated_origins = ();
	my %transportation_scores;

	# We will compute a transportation score for all countries, and have a 0 transportation score and bonus for world
	foreach my $cc (@environmental_score_countries_enabled_sorted, "world") {
		$transportation_scores{$cc} = 0;
	}
	my $epi_score = 0;

	foreach my $origin_id (
		sort ({($aggregated_origins{$b} <=> $aggregated_origins{$a}) || ($a cmp $b)} keys %aggregated_origins))
	{

		my $percent = $aggregated_origins{$origin_id};

		push @aggregated_origins, {origin => $origin_id, percent => $percent};

		if (not defined $environmental_score_data{origins}{$origin_id}{epi_score}) {
			$log->error(
				"compute_environmental_score_origins_of_ingredients_adjustment - missing epi_score",
				{origin_id => $origin_id, origin_data => $environmental_score_data{origins}{$origin_id}}
			) if $log->is_error();
		}

		$epi_score += $environmental_score_data{origins}{$origin_id}{epi_score} * $percent / 100;
		foreach my $cc (@environmental_score_countries_enabled_sorted) {
			$transportation_scores{$cc}
				+= ($environmental_score_data{origins}{$origin_id}{"transportation_score_" . $cc} // 0)
				* $percent / 100;
		}
	}

	my $epi_value = $epi_score / 10 - 5;

	$log->debug("compute_environmental_score_origins_of_ingredients_adjustment - aggregated origins",
		{aggregated_origins => \@aggregated_origins})
		if $log->is_debug();

	# EPI score is not counted if we already have a bonus for the production system
	# In this case, we set the EPI score to 0
	if ($product_ref->{environmental_score_data}{adjustments}{production_system}{value} > 0) {
		$epi_score = 0;
		$epi_value = 0;
	}

	$product_ref->{environmental_score_data}{adjustments}{origins_of_ingredients} = {
		origins_from_origins_field => \@origins_from_origins_field,
		origins_from_categories => \@origins_from_categories,
		aggregated_origins => \@aggregated_origins,
		epi_score => 0 + $epi_score,
		epi_value => 0 + round($epi_value),
	};

	$product_ref->{environmental_score_data}{adjustments}{origins_of_ingredients}{"transportation_scores"}
		= \%transportation_scores;
	$product_ref->{environmental_score_data}{adjustments}{origins_of_ingredients}{"transportation_values"} = {};
	$product_ref->{environmental_score_data}{adjustments}{origins_of_ingredients}{"values"} = {};

	foreach my $cc (@environmental_score_countries_enabled_sorted, "world") {
		$product_ref->{environmental_score_data}{adjustments}{origins_of_ingredients}{"transportation_values"}{$cc}
			= 0 + round($transportation_scores{$cc} / 6.66);
		$product_ref->{environmental_score_data}{adjustments}{origins_of_ingredients}{"values"}{$cc}
			= 0 + round($epi_value)
			+ $product_ref->{environmental_score_data}{adjustments}{origins_of_ingredients}{"transportation_values"}
			{$cc};
	}

	# Add a warning if the only origin is en:unknown
	if (($#aggregated_origins == 0) and ($aggregated_origins[0]{origin} eq "en:unknown")) {
		$product_ref->{environmental_score_data}{adjustments}{origins_of_ingredients}{warning}
			= "origins_are_100_percent_unknown";
		defined $product_ref->{environmental_score_data}{missing}
			or $product_ref->{environmental_score_data}{missing} = {};
		$product_ref->{environmental_score_data}{missing}{origins} = 1;
	}
	return;
}

=head2 compute_environmental_score_packaging_adjustment ( $product_ref )

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

sub compute_environmental_score_packaging_adjustment ($product_ref) {

	$log->debug("compute_environmental_score_packaging_adjustment - packagings data structure",
		{packagings => $product_ref->{packagings}})
		if $log->is_debug();

	# Sum the scores of all packagings components
	# Create a copy of the packagings structure, so that we can add Eco-score elements to it

	my $warning;

	# If we do not have packagings info, return the maximum malus
	if ((not defined $product_ref->{packagings}) or (scalar @{$product_ref->{packagings}} == 0)) {
		$product_ref->{environmental_score_data}{adjustments}{packaging} = {value => -15,};
		# indicate that we are missing key data
		# this is to indicate to 3rd party that the computed Environmental-Score should not be displayed without warnings
		$product_ref->{environmental_score_data}{missing_key_data} = 1;
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

				my $ratio = get_inherited_property("packaging_shapes", $packaging_ref->{shape},
					"environmental_score_ratio:en");
				if (defined $ratio) {
					$packaging_ref->{environmental_score_shape_ratio} = $ratio + 0;
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

			if (not defined $packaging_ref->{environmental_score_shape_ratio}) {
				# No shape specified, or no Eco-score score for it, use a ratio of 1
				$packaging_ref->{environmental_score_shape_ratio} = 1;
			}

			# Material

			if (defined $packaging_ref->{material}) {

				# For aluminium, we need to differentiate heavy and light aluminium based on the shape
				if ($packaging_ref->{material} eq "en:aluminium") {

					my $weight = "thin";

					if (defined $packaging_ref->{shape}) {
						$weight = get_inherited_property("packaging_shapes", $packaging_ref->{shape}, "weight:en");
						$log->debug("aluminium", {weight => $weight, shape => $packaging_ref->{shape}})
							if $log->is_debug();
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

				my $score = get_inherited_property(
					"packaging_materials",
					$packaging_ref->{material},
					"environmental_score_score:en"
				);
				if (defined $score) {
					$packaging_ref->{environmental_score_material_score} = $score + 0;
				}
				else {
					if (not defined $warning) {
						$warning = "unscored_material";
					}
				}

				# Check if there is a shape-specific material score (e.g. PEHD bottle)
				if (defined $packaging_ref->{shape}) {
					my $shape_specific_score = get_inherited_property(
						"packaging_materials",
						$packaging_ref->{material} . '.' . $packaging_ref->{shape},
						"environmental_score_score:en"
					);
					if (defined $shape_specific_score) {
						$packaging_ref->{environmental_score_material_score} = $shape_specific_score + 0;
						$packaging_ref->{material_shape} = $packaging_ref->{material} . '.' . $packaging_ref->{shape};
					}
				}

				# Check if the material is non recyclable and non biodegradable
				my $non_recyclable_and_non_biodegradable = get_inherited_property(
					"packaging_materials",
					$packaging_ref->{material},
					"non_recyclable_and_non_biodegradable:en"
				);
				if (defined $non_recyclable_and_non_biodegradable) {
					$packaging_ref->{non_recyclable_and_non_biodegradable} = $non_recyclable_and_non_biodegradable;
					if (    ($non_recyclable_and_non_biodegradable ne "no")
						and ($packaging_ref->{environmental_score_shape_ratio} >= 1))
					{
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

			if (not defined $packaging_ref->{environmental_score_material_score}) {
				# No material specified, or no Eco-score score for it, use a score of 0
				$packaging_ref->{environmental_score_material_score} = 0;
			}

			# Multiply the shape ratio and the material score

			$packaging_score
				+= (100 - $packaging_ref->{environmental_score_material_score})
				* $packaging_ref->{environmental_score_shape_ratio};
		}

		$packaging_score = 100 - $packaging_score;

		my $value = 0 + round($packaging_score / 10 - 10);
		if ($value < -15) {
			$value = -15;
		}

		$product_ref->{environmental_score_data}{adjustments}{packaging} = {
			packagings => $packagings_ref,
			score => $packaging_score,
			value => $value,
			non_recyclable_and_non_biodegradable_materials => $non_recyclable_and_non_biodegradable_materials,
		};
	}

	if (defined $warning) {
		$product_ref->{environmental_score_data}{adjustments}{packaging}{warning} = $warning;
		defined $product_ref->{environmental_score_data}{missing}
			or $product_ref->{environmental_score_data}{missing} = {};
		$product_ref->{environmental_score_data}{missing}{packagings} = 1;
	}
	return;
}

=head2 localize_environmental_score ( $cc, $product_ref)

The Environmental-Score and some of its components depend on the country of the consumer,
as we take transportation to the consumer into account.

We compute the Environmental-Score for all countries, and this function copies the values
for a specific country to the main Environmental-Score fields.

Note: even if we could not compute the Environmental-Score (because of a missing category),
we still localize the origins of ingredients, so that it can be displayed
in separate knowledge panels.

=head3 Arguments

=head4 Country code of the request $cc

=head4 Product reference $product_ref

=head3 Return values

The adjustment value and computations details are stored in the product reference passed as input parameter.


=cut

sub localize_environmental_score ($request_cc, $product_ref) {

	# Localize the Environmental-Score fields that depends on the country of the request

	if (defined $product_ref->{environmental_score_data}) {

		# Localize the final score

		# If we have specific Environmental-Score and origins of ingredients adjustment for the country, use it,
		# otherwise use the world values
		my $cc = $request_cc;
		if (not defined $product_ref->{environmental_score_data}{"scores"}{$cc}) {
			$cc = "world";
		}

		if (defined $product_ref->{environmental_score_data}{"scores"}{$cc}) {
			$product_ref->{environmental_score_data}{"score"} = $product_ref->{environmental_score_data}{"scores"}{$cc};
			$product_ref->{environmental_score_data}{"grade"} = $product_ref->{environmental_score_data}{"grades"}{$cc};

			$product_ref->{"environmental_score_score"} = $product_ref->{environmental_score_data}{"score"};
			$product_ref->{"environmental_score_grade"} = $product_ref->{environmental_score_data}{"grade"};
			$product_ref->{"environmental_score_tags"} = [$product_ref->{environmental_score_grade}];
		}
		# Localize the origins of ingredients data

		if (defined $product_ref->{environmental_score_data}{adjustments}{origins_of_ingredients}) {

			$product_ref->{environmental_score_data}{adjustments}{origins_of_ingredients}{"value"}
				= $product_ref->{environmental_score_data}{adjustments}{origins_of_ingredients}{"values"}{$cc};

			$product_ref->{environmental_score_data}{adjustments}{origins_of_ingredients}{"transportation_score"}
				= $product_ref->{environmental_score_data}{adjustments}{origins_of_ingredients}
				{"transportation_scores"}{$cc};

			$product_ref->{environmental_score_data}{adjustments}{origins_of_ingredients}{"transportation_value"}
				= $product_ref->{environmental_score_data}{adjustments}{origins_of_ingredients}
				{"transportation_values"}{$cc};

			# For each origin, we also add its score (EPI + transporation to country of request)
			# so that clients can show which ingredients contributes the most to the origins of ingredients bonus / malus

			if (
				defined $product_ref->{environmental_score_data}{adjustments}{origins_of_ingredients}
				{aggregated_origins})
			{

				foreach my $origin_ref (
					@{$product_ref->{environmental_score_data}{adjustments}{origins_of_ingredients}{aggregated_origins}}
					)
				{

					my $origin_id = $origin_ref->{origin};
					$origin_ref->{epi_score} = $environmental_score_data{origins}{$origin_id}{epi_score};
					$origin_ref->{transportation_score}
						= $environmental_score_data{origins}{$origin_id}{"transportation_score_" . $cc};
				}
			}
		}
	}
	return;
}

=head2 environmental_score_extended_data_expected_error (  $product_ref)

Expected error of the Environmental-Score extended data from the impact estimator,
based on % of uncharacterized ingredients and standard deviation.

=head3 Arguments

=head4 Product reference $product_ref

=head3 Return values

The expected error as float.

=cut

sub environmental_score_extended_data_expected_error ($product_ref) {

	# Parameters of the surface, as generated by
	# https://github.com/openfoodfacts/off-product-environmental-impact/blob/master/analysis/colab/OFF%20impact%20estimator.ipynb
	my @p = [
		0.16537831, 0.2269159, 0.04220039, -0.01991893, 0.44583949, -0.06321924,
		-0.37268731, 0.12465602, -0.09215003, 0.06000644
	];

	my $stddev = $product_ref->{environmental_score_extended_data}{ef_single_score_log_stddev};
	my $unchar = $product_ref->{environmental_score_extended_data}{mass_ratio_uncharacterized};

	return
		  $p[0]
		+ $p[1] * $unchar
		+ $p[2] * $stddev
		+ $p[3] * $unchar * $stddev
		+ $p[4] * $unchar * $unchar
		+ $p[5] * $stddev * $stddev
		+ $p[6] * $unchar * $unchar * $unchar
		+ $p[7] * $unchar * $unchar * $stddev
		+ $p[8] * $unchar * $stddev * $stddev
		+ $p[9] * $stddev * $stddev * $stddev;

}

sub is_environmental_score_extended_data_more_precise_than_agribalyse ($product_ref) {

	# Check that the product has both Agribalyse and Impact Estimator data

	my $agribalyse_score = deep_get($product_ref, qw(agribalyse ef_agriculture));
	my $estimated_score
		= deep_get($product_ref, qw(environmental_score_extended_data impact likeliest_impacts EF_single_score));

	if ((defined $agribalyse_score) and (defined $estimated_score)) {

		my $expected_error = environmental_score_extended_data_expected_error($product_ref);
		my $relative_difference = (log($estimated_score) - log($agribalyse_score)) / log($estimated_score);

		$log->debug(
			"is_environmental_score_extended_data_more_precise_than_agribalyse",
			{
				agribalyse_score => $agribalyse_score,
				estimated_score => $estimated_score,
				expected_error => $expected_error,
				relative_difference => $relative_difference,
				more_precise => ($expected_error < abs($relative_difference))
			}
		) if $log->is_debug();

		return ($expected_error < abs($relative_difference));
	}
	else {
		return 0;
	}
}

1;

