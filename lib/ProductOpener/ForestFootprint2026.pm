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
    footprint = percent_estimate * equivalence_ingredient * equivalence_ingredient_category * origin_footprint * risk_factor

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
use ProductOpener::Numbers qw/convert_string_to_number/;

use Text::CSV();
use Data::DeepAccess qw(deep_get);

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
# (grade A is only if value is 0)
my %grade_thresholds = (
	'en:cocoa' => {
		b => 0.065,
		c => 0.168,
	},
	'en:coffee' => {
		b => 0.022,
		c => 0.044,
	},
	'en:palm-oil' => {
		b => 0.003,
		c => 0.010,
	},
);

=head1 FUNCTIONS

=head2 load_forest_footprint_2026_data ()

Loads data needed to compute the forest footprint using the 2026 algorithm.

=cut

my $forest_footprint_data_loaded = 0;

sub load_forest_footprint_2026_data() {

	return if $forest_footprint_data_loaded;
	$forest_footprint_data_loaded = 1;

	my $errors = 0;

	my $data_dir = "$data_root/external-data/forest-footprint/2026";

	load_ingredients_equivalence($data_dir);
	load_ingredient_categories_equivalence($data_dir);
	load_labels_risk($data_dir);
	load_origins_footprint($data_dir);

	$log->info(
		"loaded forest footprint 2026 data",
		{
			ingredients => scalar(keys %{$forest_footprint_2026_data{ingredients}}),
			ingredient_categories => scalar(keys %{$forest_footprint_2026_data{ingredient_categories}}),
			labels_risk => scalar(keys %{$forest_footprint_2026_data{labels_risk}}),
			origins_footprint => scalar(keys %{$forest_footprint_2026_data{origins_footprint}}),
		}
	) if $log->is_info();

	return;
}

sub load_ingredients_equivalence ($data_dir) {

	my $tsv_file = "$data_dir/ingredient.ingredient_category.equivalence.tsv";

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
			my $equivalence = convert_string_to_number($row_ref->{equivalence});

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

sub load_ingredient_categories_equivalence ($data_dir) {

	my $tsv_file = "$data_dir/ingredient_category.primary_ingredient.equivalence.tsv";

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
			my $equivalence = convert_string_to_number($row_ref->{equivalence});

			if ($ingredient_category_id eq "") {
				$log->warn(
					"ingredient_category_fr has no ingredient_category_id",
					{ingredient_category_fr => $row_ref->{ingredient_category_fr}}
				) if $log->is_warn();
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

sub load_labels_risk ($data_dir) {

	my $tsv_file = "$data_dir/label.primary_ingredient.risk.tsv";

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
			my $primary_ingredient_id = $row_ref->{primary_ingredient_id};

			if ($label_id eq "") {
				$log->warn("label_fr has no label_id", {label_fr => $row_ref->{label_fr}})
					if $log->is_warn();
				next;
			}

			if ($primary_ingredient_id eq "") {
				$log->warn("label_fr has no primary_ingredient_id", {label_fr => $row_ref->{label_fr}})
					if $log->is_warn();
				next;
			}

			my $footprint = convert_string_to_number($row_ref->{footprint});

			$forest_footprint_2026_data{labels_risk}{$label_id}{$primary_ingredient_id} = $footprint;
		}

		close($io);
	}
	else {
		die("Could not open labels risk TSV $tsv_file: $!");
	}

	return;
}

sub load_origins_footprint ($data_dir) {

	my $tsv_file = "$data_dir/origin.primary_ingredient.footprint.tsv";

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

			# Get all columns named "[primary_ingredient].footprint" and store them in the origins_footprint hash
			foreach my $primary_ingredient (@primary_ingredients) {
				my $column_name = "$primary_ingredient.footprint";
				$column_name =~ s/^en://;
				if ($row_ref->{$column_name} ne '') {
					my $footprint = convert_string_to_number($row_ref->{$column_name});
					$forest_footprint_2026_data{origins_footprint}{$origin_id}{$primary_ingredient} = $footprint;
				}
			}
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
	foreach my $primary_ingredient_id (@primary_ingredients) {
		$product_ref->{forest_footprint_2026}{primary_ingredients}{$primary_ingredient_id} = {
			# this will accumulate a small structure for each (sub) ingredient found
			# linked with this primary_ingredient
			ingredients => [],
			footprint_per_kg => 0,
			grade => 'a',
		};
	}

	if (defined $product_ref->{ingredients}) {
		compute_footprints_of_ingredients_2026($product_ref, $product_ref->{ingredients});
	}

	# Calculate total footprint and grades
	my $has_ingredients = 0;
	foreach my $primary_ingredient_id (@primary_ingredients) {
		my $primary_data = $product_ref->{forest_footprint_2026}{primary_ingredients}{$primary_ingredient_id};
		if (scalar @{$primary_data->{ingredients}} > 0) {
			$has_ingredients = 1;
			# Calculate footprint for this primary ingredient
			$primary_data->{footprint_per_kg} = 0;
			foreach my $ingredient_ref (@{$primary_data->{ingredients}}) {
				$primary_data->{footprint_per_kg} += $ingredient_ref->{footprint_per_kg};
			}
			# Calculate grade for this primary ingredient
			$primary_data->{grade}
				= _get_grade_for_footprint($primary_ingredient_id, $primary_data->{footprint_per_kg});
		}
		else {
			# No ingredients for this primary ingredient, remove it from the structure
			delete $product_ref->{forest_footprint_2026}{primary_ingredients}{$primary_ingredient_id};
		}
	}

	if ($has_ingredients) {
		# Calculate overall total footprint
		$product_ref->{forest_footprint_2026}{total_footprint_per_kg} = 0;
		foreach my $primary_ingredient_id (keys %{$product_ref->{forest_footprint_2026}{primary_ingredients}}) {
			$product_ref->{forest_footprint_2026}{total_footprint_per_kg}
				+= $product_ref->{forest_footprint_2026}{primary_ingredients}{$primary_ingredient_id}{footprint_per_kg};
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

	my $ingredients_with_footprint = 0;

	foreach my $ingredient_ref (@$ingredients_ref) {

		$log->debug("compute_footprints_of_ingredients_2026 - checking ingredient",
			{ingredient_id => $ingredient_ref->{id}})
			if $log->is_debug();

		if (defined $ingredient_ref->{ingredients}) {
			$log->debug("compute_footprints_of_ingredients_2026 - ingredient has subingredients",
				{ingredient_id => $ingredient_ref->{id}})
				if $log->is_debug();
			# Note: calling this method will add the sub ingredient footprint information
			# to product primary_ingredients if it exists
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
			my $primary_ingredient_id = $ingredient_footprint_ref->{primary_ingredient_id};
			push @{$product_ref->{forest_footprint_2026}{primary_ingredients}{$primary_ingredient_id}{ingredients}},
				$ingredient_footprint_ref;
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

sub get_forest_footprint_2026_ingredient_footprint ($product_ref, $ingredient_ref) {

	my $ingredient_id = $ingredient_ref->{id};

	$log->debug("get_forest_footprint_2026_ingredient_footprint - checking ingredient",
		{ingredient_id => $ingredient_id})
		if $log->is_debug();

	if (not exists $forest_footprint_2026_data{ingredients}{$ingredient_id}) {
		$log->debug("ingredient not in forest footprint 2026 data", {ingredient_id => $ingredient_id})
			if $log->is_debug();
		return;
	}

	my $ingredient_data = $forest_footprint_2026_data{ingredients}{$ingredient_id};

	my $ingredient_category_id = $ingredient_data->{ingredient_category_id};
	my $equivalence_ingredient = $ingredient_data->{equivalence};

	if (not exists $forest_footprint_2026_data{ingredient_categories}{$ingredient_category_id}) {
		$log->debug(
			"ingredient category not in forest footprint 2026 data",
			{ingredient_category_id => $ingredient_category_id}
		) if $log->is_debug();
		return;
	}

	my $category_data = $forest_footprint_2026_data{ingredient_categories}{$ingredient_category_id};

	my $primary_ingredient_id = $category_data->{primary_ingredient_id};
	my $equivalence_ingredient_category = $category_data->{equivalence};

	my ($origin_id, $origin_footprint)
		= get_origin_footprint_data($product_ref, $ingredient_ref, $primary_ingredient_id);
	my ($label_id, $risk_factor) = get_label_risk_data($product_ref, $ingredient_ref, $primary_ingredient_id);

	my $percent = $ingredient_ref->{percent} // $ingredient_ref->{percent_estimate} // 0;

	my $transformation_factor = $equivalence_ingredient * $equivalence_ingredient_category;

	my $footprint_per_kg = ($percent / 100) * $transformation_factor * $origin_footprint * $risk_factor;

	my $footprint_ref = {
		ingredient_id => $ingredient_id,
		ingredient_category_id => $ingredient_category_id,
		primary_ingredient_id => $primary_ingredient_id,
		percent => $percent,
		equivalence_ingredient => $equivalence_ingredient,
		equivalence_ingredient_category => $equivalence_ingredient_category,
		transformation_factor => $transformation_factor,
		origin_id => $origin_id,
		origin_footprint => $origin_footprint,
		label_id => $label_id,
		risk_factor => $risk_factor,
		footprint_per_kg => $footprint_per_kg,
	};

	return $footprint_ref;
}

=head2 get_origin_footprint_data ($product_ref, $ingredient_ref, $primary_ingredient_id)

C<get_origin_footprint_data()> retrieves the origin footprint data for a given primary ingredient.

The origin can be specified in the ingredient's origins field or in the product's origins_tags.
If no origin is found, the en:unknown origin is used.

If multiple origins are specified, we keep the one with the highest footprint for the given primary ingredient.

=cut

sub get_origin_footprint_data ($product_ref, $ingredient_ref, $primary_ingredient_id) {

	my @origins = ();

	# Use ingredients specific origins if they exist
	if (defined $ingredient_ref->{origins}) {
		my @ingredient_origins = split /\s*,\s*/, $ingredient_ref->{origins};
		@origins = @ingredient_origins;
	}
	# Otherwise, use product level origins_tags if they exist
	elsif (defined $product_ref->{origins_tags}) {
		@origins = @{$product_ref->{origins_tags}};
	}

	# If no origins are specified, use en:unknown as the default origin
	if (scalar @origins == 0) {
		@origins = ("en:unknown");
	}

	my $highest_origin_id;
	my $highest_origin_footprint;

	# Search for the origin with the highest footprint for this primary ingredient
	foreach my $origin (@origins) {
		my $origin_footprint
			= deep_get(\%forest_footprint_2026_data, "origins_footprint", $origin, $primary_ingredient_id);
		if (    (defined $origin_footprint)
			and (not defined $highest_origin_footprint or ($origin_footprint > $highest_origin_footprint)))
		{
			$highest_origin_id = $origin;
			$highest_origin_footprint = $origin_footprint;
		}
	}

	return ($highest_origin_id, $highest_origin_footprint);
}

=head2 get_label_risk_data ($product_ref, $ingredient_ref, $primary_ingredient_id)

Determines if an ingredient has a label that reduces its risk factor, and returns the lowest risk factor among the labels.
Input risk factors are in % (100% means the label does not reduce the risk, 0% means the label completely eliminates the risk).

Labels can be product wide labels (in labels_tags), or ingredients specific labels (stored in the "labels" field for each ingredient in the ingredients structure)

=over

=item * Product reference $product_ref

Used to determine product-wide labels for risk factor.

=item * Primary ingredient id $primary_ingredient_id

The primary ingredient to check labels for.

=item * Ingredient reference $ingredient_ref

Used to determine ingredient-specific labels for risk factor.

=back

=cut

sub get_label_risk_data ($product_ref, $ingredient_ref, $primary_ingredient_id) {

	my $lowest_risk_factor = 1;
	my $lowest_label_id;

	my @labels = ();

	# Product level labels
	if (defined $product_ref->{labels_tags}) {
		push @labels, @{$product_ref->{labels_tags}};
	}

	# Ingredient specific labels
	if (defined $ingredient_ref->{labels}) {
		my @ingredient_labels = split /\s*,\s*/, $ingredient_ref->{labels};
		push @labels, @ingredient_labels;
	}

	# Loop through labels, keep label with lowest risk factor for this primary ingredient
	foreach my $label (@labels) {
		next if not defined $label or $label eq "";
		if (exists $forest_footprint_2026_data{labels_risk}{$label}) {
			my $label_data = $forest_footprint_2026_data{labels_risk}{$label};
			if (exists $label_data->{$primary_ingredient_id}) {
				my $label_risk = $label_data->{$primary_ingredient_id} / 100;
				if ($label_risk < $lowest_risk_factor) {
					$lowest_risk_factor = $label_risk;
					$lowest_label_id = $label;
				}
			}
		}
	}

	return ($lowest_label_id, $lowest_risk_factor);
}

=head2 calculate_forest_footprint_2026_grade ($product_ref)

C<calculate_forest_footprint_2026_grade()> calculates the forest footprint grade for a product.

Grades:
- a: Best (lowest environmental impact)
- d: Worst (highest environmental impact)

=cut

sub calculate_forest_footprint_2026_grade ($product_ref) {

	# Check for non-calculated ingredients using ingredients_tags
	my $has_non_calculated_ingredient = 0;
	my $has_calculated_ingredient = 0;

	# Check if any calculated primary ingredients are present
	foreach my $primary_ingredient_id (@primary_ingredients) {
		if (defined $product_ref->{forest_footprint_2026}{primary_ingredients}{$primary_ingredient_id}{ingredients}
			&& scalar @{$product_ref->{forest_footprint_2026}{primary_ingredients}{$primary_ingredient_id}{ingredients}}
			> 0)
		{
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

	# If presence of non-calculated ingredients + absence of calculated ingredients → "unknown"
	if ($has_non_calculated_ingredient && !$has_calculated_ingredient) {
		return "unknown";
	}

	# Determine final grade
	# Use the highest grade (worst) that applies
	my $final_grade = "a";

	foreach my $primary_ingredient_id (@primary_ingredients) {
		# Get the grade from the already-populated primary_ingredients structure
		my $grade
			= deep_get($product_ref, "forest_footprint_2026", "primary_ingredients", $primary_ingredient_id, "grade");

		if ((defined $grade) and ($grade gt $final_grade)) {
			$final_grade = $grade;
		}

	}

	return lc($final_grade);
}

sub _get_grade_for_footprint ($primary_ingredient_id, $footprint) {

	my $thresholds = $grade_thresholds{$primary_ingredient_id};

	my $grade;

	if ($footprint == 0) {
		$grade = "a";
	}
	elsif ($footprint < $thresholds->{b}) {
		$grade = "b";
	}
	elsif ($footprint < $thresholds->{c}) {
		$grade = "c";
	}
	else {
		$grade = "d";
	}

	return $grade;
}

1;
