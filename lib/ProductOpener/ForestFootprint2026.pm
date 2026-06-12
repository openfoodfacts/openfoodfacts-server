# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2026 Association Open Food Facts
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

ProductOpener::ForestFootprint2026 - compute the forest footprint of a food product using the 2026 algorithm

=head1 SYNOPSIS

C<ProductOpener::ForestFootprint2026> is used to compute the forest footprint of a food product
using the new 2026 algorithm based on direct ingredient-to-primary-ingredient mapping.

=head1 DESCRIPTION

The module implements a new forest footprint computation algorithm that differs from the original
ForestFootprint module. Instead of using soy-based calculations, it uses:

- Direct ingredient-to-ingredient_category mapping with equivalence factors
- Ingredient_category to primary_ingredient mapping with equivalence factors
- Origin-based footprint values for each primary ingredient (cocoa, coffee, palm-oil)
- Label-based risk reduction percentages

The computation formula is:
    footprint = percent_estimate * equivalence_ingredient * equivalence_ingredient_category * origin_footprint * (risk_factor / 100)

=cut

package ProductOpener::ForestFootprint2026;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

use Log::Any qw($log);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(

		&load_forest_footprint_2026_data
		&compute_forest_footprint_2026
		&get_forest_footprint_2026_ingredient_footprint

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Config qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::ProductsTags qw/:all/;

use Text::CSV();

my %forest_footprint_2026_data = (
	ingredients => {},
	ingredient_categories => {},
	primary_ingredients => {},
	labels_risk => {},
	origins_footprint => {},
);

# List of primary ingredients tracked by forest footprint 2026
my @primary_ingredients = qw(
	en:cocoa
	en:coffee
	en:palm-oil
);

# Thresholds for each primary ingredient (EF values for grades B, C, D)
my %grade_thresholds = (
	'en:cocoa' => {
		'B' => 0.065,
		'C' => 0.168,
		'D' => 0.168,
	},
	'en:coffee' => {
		'B' => 0.022,
		'C' => 0.044,
		'D' => 0.044,
	},
	'en:palm-oil' => {
		'B' => 0.003,
		'C' => 0.010,
		'D' => 0.010,
	},
);

=head1 FUNCTIONS

=head2 load_forest_footprint_2026_data ()

Loads data needed to compute the forest footprint using the 2026 algorithm.

=cut

sub load_forest_footprint_2026_data() {

	my $errors = 0;

	my $data_dir = "$data_root/external-data/forest-footprint/2026";

	load_ingredients_equivalence($data_dir);
	load_ingredient_categories_equivalence($data_dir);
	load_labels_risk($data_dir);
	load_origins_footprint($data_dir);

	$log->info("loaded forest footprint 2026 data",
		{ingredients => scalar(keys %{$forest_footprint_2026_data{ingredients}}),
			ingredient_categories => scalar(keys %{$forest_footprint_2026_data{ingredient_categories}}),
			labels_risk => scalar(keys %{$forest_footprint_2026_data{labels_risk}}),
			origins_footprint => scalar(keys %{$forest_footprint_2026_data{origins_footprint}}),})
		if $log->is_info();

	return;
}

sub load_ingredients_equivalence ($) {

	my ($data_dir) = @_;

	# Try loading populated file first, then fall back to original
	my $tsv_file = "$data_dir/ingredient.ingredient_category.equivalence.populated.tsv";
	if (not -e $tsv_file) {
		$tsv_file = "$data_dir/ingredient.ingredient_category.equivalence.tsv";
	}

	$log->debug("opening ingredients equivalence TSV file", {file => $tsv_file})
		if $log->is_debug();

	my $csv_options_ref = {binary => 1, sep_char => "\t"};
	my $csv = Text::CSV->new($csv_options_ref)
		or die("Cannot use CSV: " . Text::CSV->error_diag());

	if (open(my $io, "<:encoding(UTF-8)", $tsv_file)) {

		my $header_ref = $csv->getline($io);
		$csv->column_names(@$header_ref);

		while (my $row_ref = $csv->getline_hr($io)) {

			next if not defined $row_ref->{ingredient_fr};
			next if $row_ref->{ingredient_fr} eq "";

			my $ingredient_id = $row_ref->{ingredient_id};
			my $ingredient_fr = $row_ref->{ingredient_fr};
			my $ingredient_category_id = $row_ref->{ingredient_category_id};
			my $equivalence = _parse_decimal($row_ref->{equivalence});

			if ($ingredient_id eq "") {
				$log->warn("ingredient_fr has no ingredient_id", {ingredient_fr => $ingredient_fr})
					if $log->is_warn();
				next;
			}

			$forest_footprint_2026_data{ingredients}{$ingredient_id} = {
				ingredient_fr => $ingredient_fr,
				ingredient_category_id => $ingredient_category_id,
				equivalence => $equivalence,
			};
		}

		close($io);
	}
	else {
		die("Could not open ingredients equivalence TSV $tsv_file: $!");
	}

	return;
}

sub load_ingredient_categories_equivalence ($) {

	my ($data_dir) = @_;

	my $tsv_file = "$data_dir/ingredient_category.primary_ingredient.equivalence.populated.tsv";
	if (not -e $tsv_file) {
		$tsv_file = "$data_dir/ingredient_category.primary_ingredient.equivalence.tsv";
	}

	$log->debug("opening ingredient categories equivalence TSV file", {file => $tsv_file})
		if $log->is_debug();

	my $csv_options_ref = {binary => 1, sep_char => "\t"};
	my $csv = Text::CSV->new($csv_options_ref)
		or die("Cannot use CSV: " . Text::CSV->error_diag());

	if (open(my $io, "<:encoding(UTF-8)", $tsv_file)) {

		my $header_ref = $csv->getline($io);
		$csv->column_names(@$header_ref);

		while (my $row_ref = $csv->getline_hr($io)) {

			next if not defined $row_ref->{ingredient_category_fr};
			next if $row_ref->{ingredient_category_fr} eq "";

			my $ingredient_category_id = $row_ref->{ingredient_category_id};
			my $primary_ingredient_id = $row_ref->{primary_ingredient_id};
			my $equivalence = _parse_decimal($row_ref->{equivalence});

			if ($ingredient_category_id eq "") {
				$log->warn("ingredient_category_fr has no ingredient_category_id",
					{ingredient_category_fr => $row_ref->{ingredient_category_fr}})
					if $log->is_warn();
				next;
			}

			$forest_footprint_2026_data{ingredient_categories}{$ingredient_category_id} = {
				primary_ingredient_id => $primary_ingredient_id,
				equivalence => $equivalence,
			};
		}

		close($io);
	}
	else {
		die("Could not open ingredient categories equivalence TSV $tsv_file: $!");
	}

	return;
}

sub load_labels_risk ($) {

	my ($data_dir) = @_;

	my $tsv_file = "$data_dir/label.primary_ingredient.risk.populated.tsv";
	if (not -e $tsv_file) {
		$tsv_file = "$data_dir/label.primary_ingredient.risk.tsv";
	}

	$log->debug("opening labels risk TSV file", {file => $tsv_file})
		if $log->is_debug();

	my $csv_options_ref = {binary => 1, sep_char => "\t"};
	my $csv = Text::CSV->new($csv_options_ref)
		or die("Cannot use CSV: " . Text::CSV->error_diag());

	if (open(my $io, "<:encoding(UTF-8)", $tsv_file)) {

		my $header_ref = $csv->getline($io);
		$csv->column_names(@$header_ref);

		while (my $row_ref = $csv->getline_hr($io)) {

			next if not defined $row_ref->{label_fr};
			next if $row_ref->{label_fr} eq "";

			my $label_id = $row_ref->{label_id};

			if ($label_id eq "") {
				$log->warn("label_fr has no label_id", {label_fr => $row_ref->{label_fr}})
					if $log->is_warn();
				next;
			}

			$forest_footprint_2026_data{labels_risk}{$label_id} = {
				cocoa => _parse_decimal($row_ref->{"cocoa.footprint"}),
				coffee => _parse_decimal($row_ref->{"coffee.footprint"}),
				"palm-oil" => _parse_decimal($row_ref->{"palm-oil.footprint"}),
			};
		}

		close($io);
	}
	else {
		die("Could not open labels risk TSV $tsv_file: $!");
	}

	return;
}

sub load_origins_footprint ($) {

	my ($data_dir) = @_;

	my $tsv_file = "$data_dir/origin.primary_ingredient.footprint.populated.tsv";
	if (not -e $tsv_file) {
		$tsv_file = "$data_dir/origin.primary_ingredient.footprint.tsv";
	}

	$log->debug("opening origins footprint TSV file", {file => $tsv_file})
		if $log->is_debug();

	my $csv_options_ref = {binary => 1, sep_char => "\t"};
	my $csv = Text::CSV->new($csv_options_ref)
		or die("Cannot use CSV: " . Text::CSV->error_diag());

	if (open(my $io, "<:encoding(UTF-8)", $tsv_file)) {

		my $header_ref = $csv->getline($io);
		$csv->column_names(@$header_ref);

		while (my $row_ref = $csv->getline_hr($io)) {

			next if not defined $row_ref->{origin_fr};
			next if $row_ref->{origin_fr} eq "";

			my $origin_id = $row_ref->{origin_id};

			if ($origin_id eq "") {
				$log->warn("origin_fr has no origin_id", {origin_fr => $row_ref->{origin_fr}})
					if $log->is_warn();
				next;
			}

			$forest_footprint_2026_data{origins_footprint}{$origin_id} = {
				cocoa => _parse_decimal($row_ref->{"cocoa.footprint"}),
				coffee => _parse_decimal($row_ref->{"coffee.footprint"}),
				"palm-oil" => _parse_decimal($row_ref->{"palm-oil.footprint"}),
			};
		}

		close($io);
	}
	else {
		die("Could not open origins footprint TSV $tsv_file: $!");
	}

	return;
}

=head2 compute_forest_footprint_2026 ( $product_ref )

C<compute_forest_footprint_2026()> computes the forest footprint of a food product using the 2026 algorithm,
and stores the details of the computation.

=head3 Arguments

=head4 Product reference $product_ref

=head3 Return values

The forest footprint and computations details are stored in the product reference passed as input parameter.

Returned values:

- forest_footprint_2026 : forest footprint computation details

=cut

sub compute_forest_footprint_2026 ($product_ref) {

	# Initialize primary_ingredients structure directly
	$product_ref->{forest_footprint_2026} = {primary_ingredients => {}};

	# Initialize each primary ingredient
	foreach my $primary_id (@primary_ingredients) {
		$product_ref->{forest_footprint_2026}{primary_ingredients}{$primary_id} = {
			ingredients => [],
			footprint_per_kg => 0,
			grade => 'a',
		};
	}

	if (defined $product_ref->{ingredients}) {
		compute_footprints_of_ingredients_2026(
			$product_ref,
			$product_ref->{ingredients}
		);
	}

	# Calculate total footprint and grades
	my $has_ingredients = 0;
	foreach my $primary_id (@primary_ingredients) {
		my $primary_data = $product_ref->{forest_footprint_2026}{primary_ingredients}{$primary_id};
		if (scalar @{$primary_data->{ingredients}} > 0) {
			$has_ingredients = 1;
			# Calculate footprint for this primary ingredient
			$primary_data->{footprint_per_kg} = 0;
			foreach my $ingredient_ref (@{$primary_data->{ingredients}}) {
				$primary_data->{footprint_per_kg} += $ingredient_ref->{footprint_per_kg};
			}
			# Calculate grade for this primary ingredient
			$primary_data->{grade} = _get_grade_for_ef($primary_data->{footprint_per_kg}, $primary_id);
		}
	}

	if ($has_ingredients) {
		# Calculate overall total footprint
		$product_ref->{forest_footprint_2026}{total_footprint_per_kg} = 0;
		foreach my $primary_id (@primary_ingredients) {
			$product_ref->{forest_footprint_2026}{total_footprint_per_kg} += $product_ref->{forest_footprint_2026}{primary_ingredients}{$primary_id}{footprint_per_kg};
		}

		# Calculate overall grade
		my $grade = calculate_forest_footprint_2026_grade($product_ref);
		$product_ref->{forest_footprint_2026}{grade} = $grade;
	}
	else {
		delete $product_ref->{forest_footprint_2026};
	}

	return;
}

sub compute_footprints_of_ingredients_2026 ($product_ref, $ingredients_ref) {

	my $ranked = 0;

	my $ingredients_with_footprint = 0;

	foreach my $ingredient_ref (@$ingredients_ref) {

		if ($ingredient_ref->{rank}) {
			$ranked = 1;
		}
		elsif ($ranked) {
			last;
		}

		$log->debug("compute_footprints_of_ingredients_2026 - checking ingredient",
			{ingredient_id => $ingredient_ref->{id}})
			if $log->is_debug();

		if (defined $ingredient_ref->{ingredients}) {
			$log->debug("compute_footprints_of_ingredients_2026 - ingredient has subingredients",
				{ingredient_id => $ingredient_ref->{id}})
				if $log->is_debug();
			my $sub_ingredients_with_footprint
				= compute_footprints_of_ingredients_2026($product_ref, $ingredient_ref->{ingredients});
			if ($sub_ingredients_with_footprint > 0) {
				$ingredients_with_footprint += 1;
				next;
			}
		}

		my $ingredient_footprint_ref = get_forest_footprint_2026_ingredient_footprint($product_ref, $ingredient_ref);

		if (defined $ingredient_footprint_ref) {
			# Directly add to the appropriate primary_ingredient
			my $primary_id = $ingredient_footprint_ref->{primary_ingredient_id};

			# Find matching primary ingredient
			foreach my $primary (@primary_ingredients) {
				if ($primary_id =~ /cocoa/i && $primary eq 'en:cocoa') {
					push @{$product_ref->{forest_footprint_2026}{primary_ingredients}{$primary}{ingredients}}, $ingredient_footprint_ref;
					last;
				}
				elsif ($primary_id =~ /coffee/i && $primary eq 'en:coffee') {
					push @{$product_ref->{forest_footprint_2026}{primary_ingredients}{$primary}{ingredients}}, $ingredient_footprint_ref;
					last;
				}
				elsif ($primary_id =~ /palm/i && $primary eq 'en:palm-oil') {
					push @{$product_ref->{forest_footprint_2026}{primary_ingredients}{$primary}{ingredients}}, $ingredient_footprint_ref;
					last;
				}
			}

			$ingredients_with_footprint += 1;
		}
	}

	return $ingredients_with_footprint;
}

=head2 get_forest_footprint_2026_ingredient_footprint ( $product_ref, $ingredient_ref )

C<get_forest_footprint_2026_ingredient_footprint()> computes the forest footprint for a single ingredient.

=head3 Arguments

=head4 Product reference $product_ref

Used to determine labels and origins for risk factor.

=head4 Ingredient reference $ingredient_ref

The ingredient to compute the footprint for.

=head3 Return values

Returns a reference to a hash containing the footprint details, or undef if the ingredient
does not have a forest footprint.

=cut

sub get_forest_footprint_2026_ingredient_footprint {

	my ($product_ref, $ingredient_ref) = @_;

	my $ingredient_id = $ingredient_ref->{id};

	$log->debug("get_forest_footprint_2026_ingredient_footprint - checking ingredient",
		{ingredient_id => $ingredient_id})
		if $log->is_debug();

	if (not defined $ingredient_id) {
		return undef;
	}

	if (not exists $forest_footprint_2026_data{ingredients}{$ingredient_id}) {
		$log->debug("ingredient not in forest footprint 2026 data",
			{ingredient_id => $ingredient_id})
			if $log->is_debug();
		return undef;
	}

	my $ingredient_data = $forest_footprint_2026_data{ingredients}{$ingredient_id};

	my $ingredient_category_id = $ingredient_data->{ingredient_category_id};
	my $equivalence_ingredient = $ingredient_data->{equivalence};

	if (not exists $forest_footprint_2026_data{ingredient_categories}{$ingredient_category_id}) {
		$log->debug("ingredient category not in forest footprint 2026 data",
			{ingredient_category_id => $ingredient_category_id})
			if $log->is_debug();
		return undef;
	}

	my $category_data = $forest_footprint_2026_data{ingredient_categories}{$ingredient_category_id};

	my $primary_ingredient_id = $category_data->{primary_ingredient_id};
	my $equivalence_ingredient_category = $category_data->{equivalence};
	my $primary_ingredient = get_primary_ingredient_name($primary_ingredient_id);
	my $origin_footprint = get_origin_footprint($product_ref, $primary_ingredient);

	if (not defined $origin_footprint) {
		$log->debug("no origin footprint found", {primary_ingredient => $primary_ingredient})
			if $log->is_debug();
		return undef;
	}

	my $risk_factor = get_label_risk($product_ref, $primary_ingredient);

	my $percent = $ingredient_ref->{percent};
	if (not defined $percent) {
		$percent = $ingredient_ref->{percent_estimate};
	}
	if (not defined $percent) {
		$percent = 100;
	}

	my $footprint_per_kg = ($percent / 100) * $equivalence_ingredient * $equivalence_ingredient_category * $origin_footprint * $risk_factor;

	my $footprint_ref = {
		ingredient_id => $ingredient_id,
		ingredient_category_id => $ingredient_category_id,
		primary_ingredient_id => $primary_ingredient_id,
		percent => $percent,
		equivalence_ingredient => $equivalence_ingredient,
		equivalence_ingredient_category => $equivalence_ingredient_category,
		origin_footprint => $origin_footprint,
		risk_factor => $risk_factor,
		footprint_per_kg => $footprint_per_kg,
	};

	return $footprint_ref;
}

sub get_primary_ingredient_name ($) {

	my ($primary_ingredient_id) = @_;

	if ($primary_ingredient_id =~ /^en:(.+)$/) {
		my $name = $1;
		# Map ingredient names to footprint categories
		if ($name eq 'cacao') {
			return 'cocoa';  # cacao -> cocoa for footprint lookup
		}
		return $name;
	}

	return $primary_ingredient_id;
}

sub get_origin_footprint {

	my ($product_ref, $primary_ingredient) = @_;

	my $origins_tags = $product_ref->{origins_tags};

	if (not defined $origins_tags) {
		return 0;
	}

	foreach my $origin_tag (@$origins_tags) {
		if (exists $forest_footprint_2026_data{origins_footprint}{$origin_tag}) {
			my $origin_data = $forest_footprint_2026_data{origins_footprint}{$origin_tag};
			if (defined $origin_data->{$primary_ingredient}) {
				return $origin_data->{$primary_ingredient};
			}
		}
	}

	return 0;
}

sub get_label_risk {

	my ($product_ref, $primary_ingredient) = @_;

	my $labels_tags = $product_ref->{labels_tags};

	if (not defined $labels_tags) {
		return 1;
	}

	my $risk_factor = 1;

	foreach my $label_tag (@$labels_tags) {
		if (exists $forest_footprint_2026_data{labels_risk}{$label_tag}) {
			my $label_data = $forest_footprint_2026_data{labels_risk}{$label_tag};
			if (defined $label_data->{$primary_ingredient}) {
				my $label_risk = $label_data->{$primary_ingredient} / 100;
				if ($label_risk < $risk_factor) {
					$risk_factor = $label_risk;
				}
			}
		}
	}

	return $risk_factor;
}

sub _parse_decimal ($) {

	my ($value) = @_;

	if (not defined $value or $value eq "" or $value eq "#N/A") {
		return 0;
	}

	# Convert European decimal notation (comma) to dot notation
	$value =~ s/,/./g;

	# Remove any non-numeric characters except dot and minus
	$value =~ s/[^0-9\.\-]//g;

	return $value + 0;
}

=head2 calculate_forest_footprint_2026_grade ($product_ref)

C<calculate_forest_footprint_2026_grade()> calculates the forest footprint grade for a product.

Grades:
- a: Best (lowest environmental impact)
- d: Worst (highest environmental impact)
- "non calculé à ce jour": Not calculated (presence of unsupported ingredients)

=cut

sub calculate_forest_footprint_2026_grade ($) {

	my ($product_ref) = @_;

	# Data is already organized in primary_ingredients, just calculate overall grade

	# Check for non-calculated ingredients using ingredients_tags
	my $has_non_calculated_ingredient = 0;
	my $has_calculated_ingredient = 0;

	# Check if any calculated primary ingredients are present
	foreach my $primary_id (@primary_ingredients) {
		if (defined $product_ref->{forest_footprint_2026}{primary_ingredients}{$primary_id}{ingredients}
			&& scalar @{$product_ref->{forest_footprint_2026}{primary_ingredients}{$primary_id}{ingredients}} > 0) {
			$has_calculated_ingredient = 1;
			last;
		}
	}

	# Check for non-calculated ingredients in ingredients_tags
	if (defined $product_ref->{ingredients_tags}) {
		my @non_calculated_parents = qw(
			en:soy
			en:meat
			en:poultry
			en:beef
			en:pork
			en:lamb
			en:fish
			en:seafood
			en:milk
			en:cheese
			en:butter
			en:cream
			en:yogurt
			en:dairy
			en:egg
			en:corn
			en:rice
			en:cassava
			en:manioc
		);

		foreach my $tag (@{$product_ref->{ingredients_tags}}) {
			foreach my $parent (@non_calculated_parents) {
				if (is_a("ingredients", $tag, $parent)) {
					$has_non_calculated_ingredient = 1;
					last;
				}
			}
			last if $has_non_calculated_ingredient;
		}
	}

	# Rule 1: If presence of non-calculated ingredients + absence of calculated ingredients → "unknown"
	if ($has_non_calculated_ingredient && !$has_calculated_ingredient) {
		return "unknown";
	}

	# Rule 2 & 3: Determine final grade
	# Use the highest grade (worst) that applies
	my $final_grade = "";
	my $final_grade_score = -1;

	foreach my $primary_id (@primary_ingredients) {
		# Get the grade from the already-populated primary_ingredients structure
		my $grade = $product_ref->{forest_footprint_2026}{primary_ingredients}{$primary_id}{grade};
		my $grade_score = _grade_to_score($grade);

		# Only consider if this primary ingredient is present (has ingredients)
		if (defined $product_ref->{forest_footprint_2026}{primary_ingredients}{$primary_id}{ingredients}
			&& scalar @{$product_ref->{forest_footprint_2026}{primary_ingredients}{$primary_id}{ingredients}} > 0) {
			if ($grade_score > $final_grade_score) {
				$final_grade = $grade;
				$final_grade_score = $grade_score;
			}
		}
	}

	# If no calculated ingredients found (all EF = 0), return "a"
	if ($final_grade eq "") {
		return "a";
	}
	if ($final_grade eq "") {
		return "";
	}

	return lc($final_grade);
}

sub collect_all_ingredients {

	my ($ingredients_ref, $all_ingredients_ref) = @_;

	foreach my $ingredient_ref (@$ingredients_ref) {
		if (defined $ingredient_ref->{id}) {
			push @$all_ingredients_ref, $ingredient_ref->{id};
		}

		# Recursively collect sub-ingredients
		if (defined $ingredient_ref->{ingredients}) {
			collect_all_ingredients($ingredient_ref->{ingredients}, $all_ingredients_ref);
		}
	}
}

sub _get_grade_for_ef {

	my ($ef, $primary_id) = @_;

	# If no EF, return A
	if ($ef == 0) {
		return "a";
	}

	# Get thresholds for this primary ingredient
	my $thresholds = $grade_thresholds{$primary_id};
	if (not defined $thresholds) {
		return "";
	}

	# Apply thresholds: B < threshold_B, C < threshold_C, D >= threshold_C
	if ($ef < $thresholds->{'B'}) {
		return "b";
	}
	elsif ($ef < $thresholds->{'C'}) {
		return "c";
	}
	else {
		return "d";
	}
}

sub _grade_to_score {

	my ($grade) = @_;

	# Convert grade to numeric score for comparison
	# a=0 (best), b=1, c=2, d=3 (worst), ""=-1 (not applicable)
	if ($grade eq "a") {
		return 0;
	}
	elsif ($grade eq "b") {
		return 1;
	}
	elsif ($grade eq "c") {
		return 2;
	}
	elsif ($grade eq "d") {
		return 3;
	}
	else {
		return -1;
	}
}

1;