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

ProductOpener::NutritionCiqual - load data from the Ciqual nutritional database

=head1 DESCRIPTION

A copy of the Ciqual database is in external-data/ciqual/calnut

The present data and information are made available to the public by the French Agency for Food, Environmental and Occupational Health & Safety (ANSES).
They must not be reproduced in any form without clear indication of the source:

"Anses. 2020. Ciqual French food composition table."

https://ciqual.anses.fr/

=cut

package ProductOpener::NutritionCiqual;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

use Log::Any qw($log);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(

		&load_ciqual_data
		%ciqual_data

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Numbers qw/:all/;

use Storable qw(dclone freeze);
use Text::CSV();
use Data::DeepAccess qw(deep_get deep_exists);

=head1 VARIABLES

=head2 %ciqual_data

Hash table with the Ciqual ingredient id as a key, mapped to a hash of Open Food Facts nutrients id to values.

=cut

=head1 FUNCTIONS

=head2 load_ciqual_data()

Loads the Ciqual table + the Ciqual CALNUT extended table.

=cut

sub load_ciqual_data() {

	# First, load Ciqual table that contains some nutrients for all Ciqual categories
	load_ciqual_table();

	# Then, load the extended Ciqual CALNUT table that contains all nutrients but only for some Ciqual categories
	# If we have data in CALNUT, it overrides the possibly partial data we may have loaded from the Ciqual table
	load_ciqual_calnut_table();

	return;
}

# Unit factors used by both functions to load Ciqual and CALNUT tables

my %unit_factor = (
	'g' => 1,
	'mg' => 1000,
	'mcg' => 1000 * 1000,
	'µg' => 1000 * 1000,
	'kj' => 1,
	'kcal' => 1,
);

=head2 load_ciqual_table()

Loads the Ciqual table. Some Ciqual categories may have missing values for some nutrients.

=cut

sub load_ciqual_table() {
	my $ciqual_csv_file = $data_root . "/external-data/ciqual/ciqual/CIQUAL.csv";
	my $ciqual_version_file = $data_root . "/external-data/ciqual/ciqual/CIQUAL_version.txt";

	my $rows_ref = [];

	my $encoding = "UTF-8";

	open(my $version_file, "<:encoding($encoding)", $ciqual_version_file)
		or die("Cannot open $ciqual_version_file: " . $! . "\n");
	chomp(my $ciqual_version = <$version_file>);
	close($version_file);

	$log->debug("opening ciqual CSV file", {file => $ciqual_csv_file, version => $ciqual_version})
		if $log->is_debug();

	# alim_grp_code	alim_ssgrp_code	alim_ssssgrp_code	alim_grp_nom_eng	alim_ssgrp_nom_eng	alim_ssssgrp_nom_eng	alim_code	alim_nom_eng	alim_nom_sci	Energy, Regulation EU No 1169/2011 (kJ/100g)	Energy, Regulation EU No 1169/2011 (kcal/100g)	Energy, N x Jones' factor, with fibres (kJ/100g)	Energy, N x Jones' factor, with fibres (kcal/100g)	Water (g/100g)	Protein (g/100g)	Protein, crude, N x 6.25 (g/100g)	Carbohydrate (g/100g)	Fat (g/100g)	Sugars (g/100g)	fructose (g/100g)	galactose (g/100g)	glucose (g/100g)	lactose (g/100g)	maltose (g/100g)	sucrose (g/100g)	Starch (g/100g)	Fibres (g/100g)	Polyols (g/100g)	Ash (g/100g)	Alcohol (g/100g)	Organic acids (g/100g)	FA saturated (g/100g)	FA mono (g/100g)	FA poly (g/100g)	FA 4:0 (g/100g)	FA 6:0 (g/100g)	FA 8:0 (g/100g)	FA 10:0 (g/100g)	FA 12:0 (g/100g)	FA 14:0 (g/100g)	FA 16:0 (g/100g)	FA 18:0 (g/100g)	FA 18:1 n-9 cis (g/100g)	FA 18:2 9c,12c (n-6) (g/100g)	FA 18:3 c9,c12,c15 (n-3) (g/100g)	FA 20:4 5c,8c,11c,14c (n-6) (g/100g)	FA 20:5 5c,8c,11c,14c,17c (n-3) EPA (g/100g)	FA 22:6 4c,7c,10c,13c,16c,19c (n-3) DHA (g/100g)	Cholesterol (mg/100g)	Salt (g/100g)	Calcium (mg/100g)	Chloride (mg/100g)	Copper (mg/100g)	Iron (mg/100g)	Iodine (µg/100g)	Magnesium (mg/100g)	Manganese (mg/100g)	Phosphorus (mg/100g)	Potassium (mg/100g)	Selenium (µg/100g)	Sodium (mg/100g)	Zinc (mg/100g)	Retinol (µg/100g)	Beta-carotene (µg/100g)	Vitamin D (µg/100g)	Vitamin E (mg/100g)	Vitamin K1 (µg/100g)	Vitamin K2 (µg/100g)	Vitamin C (mg/100g)	Vitamin B1 or Thiamin (mg/100g)	Vitamin B2 or Riboflavin (mg/100g)	Vitamin B3 or Niacin (mg/100g)	Vitamin B5 or Pantothenic acid (mg/100g)	Vitamin B6 (mg/100g)	Vitamin B9 or Folate (µg/100g)	Vitamin B12 (µg/100g)

	my $csv_options_ref = {binary => 1, sep_char => "\t"};    # should set binary attribute.

	my $csv = Text::CSV->new($csv_options_ref)
		or die("Cannot use CSV: " . Text::CSV->error_diag());

	if (open(my $io, "<:encoding($encoding)", $ciqual_csv_file)) {

		my $header_row_ref = $csv->getline($io);

		# this array will contain hashmaps with a column number, corresponding nid and unit
		my @nutrients = ();
		my $col = 0;

		# read headers to populate @nutrients, corresponding to each columns
		foreach my $nutrient (@$header_row_ref) {
			# Energy, Regulation EU No 1169/2011 (kJ/100g)	Energy, Regulation EU No 1169/2011 (kcal/100g)
			# -> Energy
			$nutrient =~ s/^Energy.*\((.*)$/Energy ($1/;

			if ($nutrient =~ /\s+\((g|mg|mcg|kj|kcal)\/100g\)/) {
				my $nutrient_name = $`;
				my $unit = $1;

				# Check if we recognize the name of the ingredient
				my $exists_in_taxonomy;
				my $nid = canonicalize_taxonomy_tag("en", "nutrients", $nutrient_name, \$exists_in_taxonomy);
				if ($exists_in_taxonomy) {
					$nid =~ s/^zz://;
					push @nutrients,
						{
						col => $col,
						nid => $nid,
						unit => $unit,
						};
				}
				else {
					# TODO: some nutrients are not automatically recognized yet
					# (e.g. most fatty acids identified with column names like ag_18_3_a_lino_g)
					$log->warning("unrecognized column name (nutrient) in CIQUAL table", {column_name => $nutrient})
						if $log->is_error();
				}
			}
			$col++;
		}

		my $row_ref;

		while ($row_ref = $csv->getline($io)) {
			my $ciqual_id = $row_ref->[6];    # alim_code
			my $name_en = $row_ref->[7];    # FOOD_LABEL

			$ciqual_data{$ciqual_id} = {
				name_en => $name_en,
				nutrients => {}
			};

			# fetch each nutrients we need
			foreach my $nutrient_ref (@nutrients) {
				my $value = $row_ref->[$nutrient_ref->{col}];

				# convert values like < 0.2 to 0.2
				$value =~ s/^<\s+//;

				# convert "traces" to 0
				$value =~ s/^traces$/0/;

				# an empty value or a dash - indicates a missing value
				if (($value ne "") and ($value ne '-')) {
					$ciqual_data{$ciqual_id}{nutrients}{$nutrient_ref->{nid}}
						= convert_string_to_number($value) / $unit_factor{$nutrient_ref->{unit}};
				}
			}
		}
	}
	else {
		die("Could not open CIQUAL CSV $ciqual_csv_file: $!");
	}
	return;
}

=head2 load_ciqual_calnut_table()

Loads the extended Ciqual CALNUT table. The CALNUT table contains values for all nutrients (with missing values extrapolated),
but it does not contain data for all CIQUAL categories.

Documentation of Ciqual CALNUT: https://ciqual.anses.fr/cms/sites/default/files/inline-files/Table%20CALNUT%202020_doc_FR_2020%2007%2007.pdf

=cut

sub load_ciqual_calnut_table() {
	my $ciqual_csv_file = $data_root . "/external-data/ciqual/calnut/CALNUT.csv.0";
	my $ciqual_version_file = $data_root . "/external-data/ciqual/calnut/CALNUT_version.txt";

	my $rows_ref = [];

	my $encoding = "UTF-8";

	open(my $version_file, "<:encoding($encoding)", $ciqual_version_file)
		or die("Cannot open $ciqual_version_file: " . $! . "\n");
	chomp(my $ciqual_version = <$version_file>);
	close($version_file);

	$log->debug("opening ciqual CSV file", {file => $ciqual_csv_file, version => $ciqual_version})
		if $log->is_debug();

	# alim_code	FOOD_LABEL	HYPOTH	nrj_kj	nrj_kcal	eau_g	sel_g	sodium_mg	magnesium_mg	phosphore_mg	potassium_mg	calcium_mg	manganese_mg	fer_mg	cuivre_mg	zinc_mg	selenium_mcg	iode_mcg	proteines_g	glucides_g	sucres_g	fructose_g	galactose_g	lactose_g	glucose_g	maltose_g	saccharose_g	amidon_g	polyols_g	fibres_g	lipides_g	ags_g	agmi_g	agpi_g	ag_04_0_g	ag_06_0_g	ag_08_0_g	ag_10_0_g	ag_12_0_g	ag_14_0_g	ag_16_0_g	ag_18_0_g	ag_18_1_ole_g	ag_18_2_lino_g	ag_18_3_a_lino_g	ag_20_4_ara_g	ag_20_5_epa_g	ag_20_6_dha_g	retinol_mcg	beta_carotene_mcg	vitamine_d_mcg	vitamine_e_mg	vitamine_k1_mcg	vitamine_k2_mcg	vitamine_c_mg	vitamine_b1_mg	vitamine_b2_mg	vitamine_b3_mg	vitamine_b5_mg	vitamine_b6_mg	vitamine_b12_mcg	vitamine_b9_mcg	alcool_g	acides_organiques_g	cholesterol_mg	alim_grp_code	alim_grp_nom_fr	alim_ssgrp_code	alim_ssgrp_nom_fr	alim_ssssgrp_code	alim_ssssgrp_nom_fr

	my $csv_options_ref = {binary => 1, sep_char => ","};    # should set binary attribute.

	my $csv = Text::CSV->new($csv_options_ref)
		or die("Cannot use CSV: " . Text::CSV->error_diag());

	if (open(my $io, "<:encoding($encoding)", $ciqual_csv_file)) {

		my $header_row_ref = $csv->getline($io);

		# this array will contain hashmaps with a column number, corresponding nid and unit
		my @nutrients = ();
		my $col = 0;

		# read headers to populate @nutrients, corresponding to each columns
		foreach my $nutrient (@$header_row_ref) {
			# nrj_kj -> energy-kj_kj
			$nutrient =~ s/^nrj_(.*)$/energy-$1_$1/;

			if ($nutrient =~ /_(g|mg|mcg|kj|kcal)$/) {
				my $french_nutrient_name = $`;
				my $unit = $1;

				# Check if we recognize the name of the ingredient
				my $exists_in_taxonomy;
				my $nid = canonicalize_taxonomy_tag("fr", "nutrients", $french_nutrient_name, \$exists_in_taxonomy);
				if ($exists_in_taxonomy) {
					$nid =~ s/^zz://;
					push @nutrients,
						{
						col => $col,
						nid => $nid,
						unit => $unit,
						};
				}
				else {
					# TODO: some nutrients are not automatically recognized yet
					# (e.g. most fatty acids identified with column names like ag_18_3_a_lino_g)
					$log->warning("unrecognized column name (nutrient) in CIQUAL table", {column_name => $nutrient})
						if $log->is_error();
				}
			}
			$col++;
		}

		my $row_ref;

		while ($row_ref = $csv->getline($io)) {
			my $ciqual_id = $row_ref->[0];    # alim_code
			my $name_fr = $row_ref->[1];    # FOOD_LABEL
			my $hypothesis = $row_ref->[2];    # HYPOTH: LB / MB / UB  (lower bound, middle bound, upper bound)

			# We select the middle bound value
			next if $hypothesis ne "MB";

			$ciqual_data{$ciqual_id} = {
				name_fr => $name_fr,
				nutrients => {}
			};

			# fetch each nutrients we need
			foreach my $nutrient_ref (@nutrients) {
				$ciqual_data{$ciqual_id}{nutrients}{$nutrient_ref->{nid}}
					= convert_string_to_number($row_ref->[$nutrient_ref->{col}]) / $unit_factor{$nutrient_ref->{unit}};
			}
		}
	}
	else {
		die("Could not open CIQUAL CSV $ciqual_csv_file: $!");
	}
	return;
}

1;

