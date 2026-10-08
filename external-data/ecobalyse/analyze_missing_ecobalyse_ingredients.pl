#!/usr/bin/perl -w

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
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# This script analyzes products to find ingredients that don't have
# ecobalyse_id or ecobalyse_proxy_id, counts their occurrences across
# products, aggregates their quantities, and outputs a TSV file sorted
# by descending aggregate quantity.
#
# Usage:
#   ./analyze_missing_ecobalyse_ingredients.pl --query categories_tags=en:beers --output results.tsv
#   ./analyze_missing_ecobalyse_ingredients.pl --query-codes-from-file codes.txt --output results.tsv
#   ./analyze_missing_ecobalyse_ingredients.pl --query categories_tags=en:plant-milks --count

use Modern::Perl '2017';
use utf8;

use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Store qw/retrieve_object store_object/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Data qw/get_products_collection/;
use ProductOpener::LoadData qw/load_data/;
use ProductOpener::Display qw/add_params_to_query/;

use Getopt::Long;
use Data::Dumper;

my $usage = <<TXT
analyze_missing_ecobalyse_ingredients.pl - Analyze ingredients missing ecobalyse IDs

Usage:

  ./analyze_missing_ecobalyse_ingredients.pl --query categories_tags=en:beers --output results.tsv

Options:
  --query field=value        Filter products (repeatable, e.g. categories_tags=en:beers)
  --query-codes-from-file    Read product codes from a text file (one per line)
  --count                    Only count matching products, don't process
  --output FILE              Output TSV file (default: stdout)
  --pretend                  Don't actually write output file
  --mongodb-to-mongodb       Read from and write to MongoDB only (no .sto files)
  --help                     Show this help

TXT
	;

my %query_params = ();
my $query_codes_from_file = '';
my $count = 0;
my $output_file = '';
my $pretend = 0;
my $mongodb_to_mongodb = 0;
my $help = 0;

GetOptions(
	"query=s%" => \%query_params,
	"query-codes-from-file=s" => \$query_codes_from_file,
	"count" => \$count,
	"output=s" => \$output_file,
	"pretend" => \$pretend,
	"mongodb-to-mongodb" => \$mongodb_to_mongodb,
	"help" => \$help,
) or die("Error in command line arguments:\n\n$usage");

if ($help) {
	print $usage;
	exit(0);
}

# Load taxonomies and data
load_data();

# Build MongoDB query from --query parameters
my $query_ref = {};
add_params_to_query(\%query_params, $query_ref);

if ($query_codes_from_file) {
	my @codes = ();
	open(my $in, "<", $query_codes_from_file) or die("Cannot read $query_codes_from_file: $!\n");
	while (<$in>) {
		if ($_ =~ /^(\d+)/) {
			push @codes, $1;
		}
	}
	close($in);
	$query_ref->{"code"} = {'$in' => \@codes};
}

print STDERR "MongoDB query:\n" . Dumper($query_ref);

my $socket_timeout_ms = 2 * 60000;    # 2 mins

my $products_collection = get_products_collection({timeout => $socket_timeout_ms});

my $products_count = 0;
eval {
	$products_count = $products_collection->count_documents($query_ref);
	print STDERR "$products_count documents to process.\n";
};

if ($count) {
	exit(0);
}

my $cursor;
if ($mongodb_to_mongodb) {
	$cursor = $products_collection->query($query_ref);
}
else {
	$cursor = $products_collection->query($query_ref)->fields({_id => 1, code => 1, owner => 1});
}
$cursor->immortal(1);

# Statistics hash: $stats{$ingredient_id}{count}, {quantity}, {in_taxonomy}
my %stats = ();
my $products_processed = 0;
my $products_with_ingredients = 0;
my $leaf_ingredients_total = 0;
my $leaf_ingredients_missing_ecobalyse = 0;

while (my $product_ref = $cursor->next) {
	$products_processed++;

	my $productid = $product_ref->{_id};
	my $code = $product_ref->{code};

	if (not defined $code) {
		print STDERR "\ncode field undefined for product id: $productid";
		next;
	}

	print STDERR "\rProcessing product $code ($products_processed / $products_count)";

	my $full_product_ref;
	if ($mongodb_to_mongodb) {
		$full_product_ref = $product_ref;
	}
	else {
		$full_product_ref = retrieve_product($productid);
	}

	next unless defined $full_product_ref;
	next unless defined $full_product_ref->{ingredients};
	next unless ref($full_product_ref->{ingredients}) eq 'ARRAY';

	$products_with_ingredients++;

	# Traverse ingredient tree to find leaf ingredients
	my @ingredients_queue = @{$full_product_ref->{ingredients}};

	while (@ingredients_queue) {
		my $ingredient_ref = shift @ingredients_queue;

		if (defined $ingredient_ref->{ingredients} && ref($ingredient_ref->{ingredients}) eq 'ARRAY') {
			# Has sub-ingredients, not a leaf
			push @ingredients_queue, @{$ingredient_ref->{ingredients}};
		}
		else {
			# This is a leaf ingredient
			$leaf_ingredients_total++;

			# Check if it has ecobalyse_id or ecobalyse_proxy_id
			my $has_ecobalyse
				= (defined $ingredient_ref->{ecobalyse_id} || defined $ingredient_ref->{ecobalyse_proxy_id});

			if (!$has_ecobalyse) {
				$leaf_ingredients_missing_ecobalyse++;

				my $ingredient_id = $ingredient_ref->{id};
				next unless defined $ingredient_id && $ingredient_id ne '';

				# Get quantity estimate
				my $quantity = $ingredient_ref->{quantity_estimate} // $ingredient_ref->{percent_estimate}
					// $ingredient_ref->{percent};
				$quantity = 0 unless defined $quantity;
				$quantity += 0;    # Ensure numeric

				# Check if in taxonomy
				my $in_taxonomy = exists_taxonomy_tag("ingredients", $ingredient_id) ? 1 : 0;

				# Accumulate stats
				$stats{$ingredient_id}{count}++;
				$stats{$ingredient_id}{quantity} += $quantity;
				$stats{$ingredient_id}{in_taxonomy} = $in_taxonomy;
			}
		}
	}
}

print STDERR "\n\nProcessed $products_processed products\n";
print STDERR "Products with ingredients: $products_with_ingredients\n";
print STDERR "Total leaf ingredients: $leaf_ingredients_total\n";
print STDERR "Leaf ingredients missing ecobalyse IDs: $leaf_ingredients_missing_ecobalyse\n";
print STDERR "Unique ingredient IDs missing ecobalyse: " . scalar(keys %stats) . "\n";

# Sort by aggregate quantity descending
my @sorted_ingredients = sort {$stats{$b}{quantity} <=> $stats{$a}{quantity}} keys %stats;

# Output TSV
my $output_fh;
if ($output_file) {
	if ($pretend) {
		print STDERR "Pretend mode: would write to $output_file\n";
		$output_fh = *STDOUT;
	}
	else {
		open($output_fh, '>:encoding(UTF-8)', $output_file) or die("Cannot open $output_file for writing: $!\n");
	}
}
else {
	$output_fh = *STDOUT;
}

# Header
print $output_fh "ingredient_id\tproducts_count\taggregate_quantity\tin_taxonomy\n";

for my $ingredient_id (@sorted_ingredients) {
	my $count = $stats{$ingredient_id}{count};
	my $quantity = $stats{$ingredient_id}{quantity};
	my $in_taxonomy = $stats{$ingredient_id}{in_taxonomy};
	printf $output_fh "%s\t%d\t%.2f\t%d\n", $ingredient_id, $count, $quantity, $in_taxonomy;
}

if ($output_file && !$pretend) {
	close($output_fh);
	print STDERR "Results written to $output_file\n";
}

print STDERR "Done.\n";

__END__
