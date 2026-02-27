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

ProductOpener::Stats - Compute stats for categories (nutrients, etc.)

=head1 DESCRIPTION

This module provides functions to compute and load stats for categories (nutrients, etc.)

=cut

package ProductOpener::Stats;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

use Log::Any qw($log);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(

		%categories_stats_per_country
		&load_categories_stats_per_country
		&add_product_value_to_stats
		&compute_stats_for_products

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Store qw(retrieve);

=head1 FUNCTIONS

=head2 add_product_value_to_stats ($values_ref, $key, $value)

This build a collection (C<$value_ref>) were for each nutrients (or other numeric attribute), C<$key>, we store the accumulate values for that nutrient (C<s>), number of instances <n> and each values C<array>).

We will then pass C<$values_ref> to C<compute_stats_for_products>.

=cut

sub add_product_value_to_stats ($values_ref, $key, $value) {

	if ((defined $value) and ($value ne '')) {

		if (not defined $values_ref->{$key}) {
			$values_ref->{$key} = {n => 0, s => 0, array => [], min => $value};
		}

		# We compute the min here as we need it for the min of graph scales
		# Complete stats including min are computed in compute_stats_for_products,
		# but we want to have a min even if there are not enough products to compute stats
		if ($value < $values_ref->{$key}{min}) {
			$values_ref->{$key}{min} = $value;
		}

		$values_ref->{$key}{n}++;
		$values_ref->{$key}{s} += $value + 0.0;
		push @{$values_ref->{$key}{array}}, $value + 0.0;

	}
	return 1;
}

=head2 compute_stats_for_products ($stats_ref, $values_ref, $count, $n, $min_products, $id)

=head3 Arguments

=head4 Stats reference $stats_ref

Where we will store the stats.

=head4 Values reference $values_ref

Values for some nutrients (or other numeric values),
with accumulated values and number of products considered
(it is different from C<$n> as some products might not have a value).
See C<add_product_value_to_stats>

=head4 Total number of products $count

Including products that have no values for the nutrients we are interested in.

=head4 Number of products with defined values for specified nutrients $n

=head4 Minimum number of products needed to compute stats $min_products

=head4 ID $id

E.g. category ID.

=cut

sub compute_stats_for_products ($stats_ref, $values_ref, $count, $n, $min_products, $id) {

	$stats_ref->{stats} = 1;
	$stats_ref->{values} = {};
	$stats_ref->{id} = $id;
	$stats_ref->{count} = $count;
	$stats_ref->{n} = $n;

	foreach my $key (keys %{$values_ref}) {

		next if ($values_ref->{$key}{n} < $min_products);

		# Compute the mean and standard deviation, without the bottom and top 5% (so that huge outliers
		# that are likely to be errors in the data do not completely overweight the mean and std)

		my @values = sort {$a <=> $b} @{$values_ref->{$key}{array}};
		my $nb_values = $#values + 1;
		my $kept_values = 0;
		my $sum_of_kept_values = 0;

		my $i = 0;
		foreach my $value (@values) {
			$i++;
			next if ($i <= $nb_values * 0.05);
			next if ($i >= $nb_values * 0.95);
			$kept_values++;
			$sum_of_kept_values += $value;
		}

		my $mean_for_kept_values = $sum_of_kept_values / $kept_values;

		$values_ref->{$key}{mean} = $mean_for_kept_values;

		my $sum_of_square_differences_for_kept_values = 0;
		$i = 0;
		foreach my $value (@values) {
			$i++;
			next if ($i <= $nb_values * 0.05);
			next if ($i >= $nb_values * 0.95);
			$sum_of_square_differences_for_kept_values
				+= ($value - $mean_for_kept_values) * ($value - $mean_for_kept_values);
		}
		my $std_for_kept_values = sqrt($sum_of_square_differences_for_kept_values / $kept_values);

		$values_ref->{$key}{std} = $std_for_kept_values;

		$stats_ref->{values}{$key} = {
			n => $values_ref->{$key}{n},
			mean => $values_ref->{$key}{mean},
			"100g" => sprintf("%.2e", $values_ref->{$key}{mean}) + 0.0,
			std => sprintf("%.2e", $values_ref->{$key}{std}) + 0.0,
			min => sprintf("%.2e", $values_ref->{$key}{array}[0]) + 0.0,
			max => sprintf("%.2e", $values_ref->{$key}{array}[$#{$values_ref->{$key}{array}}]) + 0.0,
			"10" => sprintf("%.2e", $values_ref->{$key}{array}[int(($values_ref->{$key}{n} - 1) * 0.10)]) + 0.0,
			"90" => sprintf("%.2e", $values_ref->{$key}{array}[int(($values_ref->{$key}{n}) * 0.90)]) + 0.0,
			"50" => sprintf("%.2e", $values_ref->{$key}{array}[int(($values_ref->{$key}{n}) * 0.50)]) + 0.0,
		};

		if ($key =~ /^energy/) {
			# We want round values for energy
			$stats_ref->{values}{$key}{"100g"} = int($stats_ref->{values}{$key}{"100g"} + 0.5);
			$stats_ref->{values}{$key}{std} = int($stats_ref->{values}{$key}{std} + 0.5);
		}
	}

	return;
}

=head2 load_categories_stats_per_country ($force_reload = 0)

Loads nutrient stats for all categories and countries.
If the data is already loaded, it does not reload it unless $force_reload is true.

The stats are displayed on category pages and used in product pages,
as well as in data quality checks and improvement opportunity detection.

In integration tests, there are no stats in the data directory, and it is difficult
to generate them on the fly as we need to stop and start Apache after to load them,
which is complex in the test framework with Docker.

So instead we load them from the test data directory.

=cut

sub load_categories_stats_per_country($force_reload = 0) {

	# If already loaded, do not reload unless forced
	return if (keys %categories_stats_per_country) and (not $force_reload);

	%categories_stats_per_country = ();

	my $dir = $BASE_DIRS{PRIVATE_DATA} . "/categories_stats";
	if (!-d $dir) {
		$dir = $BASE_DIRS{PRIVATE_DATA_TESTS} . "/categories_stats";
	}

	if (opendir(my $dh, $dir)) {
		$log->info("Loading categories stats per country from $dir");
		foreach my $file (sort readdir($dh)) {
			if ($file =~ /categories_stats_per_country.(\w+).sto$/) {
				my $country_cc = $1;
				$log->debug("Loading categories stats for country $country_cc");
				$categories_stats_per_country{$country_cc}
					= retrieve(
					"$BASE_DIRS{PRIVATE_DATA}/categories_stats/categories_stats_per_country.$country_cc.sto");
			}
		}
		closedir $dh;
	}
	return;
}

1;
