#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2024 Association Open Food Facts
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

use Modern::Perl '2017';
use utf8;

my $usage = <<TXT
count_product_contributions_by_year.pl - Count products contributions by year

Usage:

count_product_contributions_by_year.pl [--query filters]

Query filters:

--query some_field=some_value (e.g. categories_tags=en:beers)	filter the products (--query parameters can be repeated to have multiple filters)
--query some_field=-some_value	match products that don't have some_value for some_field
--query some_field=value1,value2	match products that have value1 and value2 for some_field (must be a _tags field)
--query some_field=value1\|value2	match products that have value1 or value2 for some_field (must be a _tags field)
TXT
	;

use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Store qw/retrieve store/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Images qw/process_image_crop/;
use ProductOpener::Lang qw/$lc/;
use ProductOpener::Mail qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Data qw/get_products_collection/;
use ProductOpener::LoadData qw/load_data/;
use ProductOpener::Redis qw/push_to_redis_stream/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::MaybeXS;
use Data::DeepAccess qw(deep_get deep_exists deep_set);
use Data::Compare;

use Log::Any::Adapter 'TAP';

use Getopt::Long;

my $query_params_ref = {};    # filters for mongodb query
my $all_owners = '';
my $obsolete = 0;
my $fix = 0;

GetOptions(
	"query=s%" => $query_params_ref,
	"all-owners" => \$all_owners,
	"obsolete" => \$obsolete,
	"fix" => \$fix,

) or die("Error in command line arguments:\n\n$usage");

# Get a list of all products
# Use query filters entered using --query categories_tags=en:plant-milks

# Build the mongodb query from the --query parameters
my $query_ref = {};

add_params_to_query($query_params_ref, $query_ref);

# On the producers platform, require --query owners_tags to be set, or the --all-owners field to be set.

if ((defined $server_options{private_products}) and ($server_options{private_products})) {
	if ((not $all_owners) and (not defined $query_ref->{owners_tags})) {
		print STDERR "On producers platform, --query owners_tags=... or --all-owners must be set.\n";
		exit();
	}
}

use Data::Dumper;
print STDERR "MongoDB query:\n" . Dumper($query_ref);

my $socket_timeout_ms = 2 * 60000;    # 2 mins, instead of 30s default, to not die as easily if mongodb is busy.

# Collection that will be used to iterate products
my $products_collection = get_products_collection({obsolete => $obsolete, timeout => $socket_timeout_ms});

my $current_products_collection = get_products_collection(
	{
		obsolete => 0,
		timeout => 10000
	}
);
my $obsolete_products_collection = get_products_collection(
	{
		obsolete => 1,
		timeout => 10000
	}
);

my $products_count = "";

eval {
	$products_count = $products_collection->count_documents($query_ref);

	print STDERR "$products_count documents to check.\n";
};

# only retrieve important fields
my $cursor = $products_collection->query($query_ref)->fields({_id => 1, code => 1, owner => 1});

$cursor->immortal(1);

my %products_edited = ();
my %products_added = ();
my %number_of_products = ();
my %new_editors = ();
my %active_editors = ();
my %editors_first_year = ();

my $i = 0;

while (my $product_ref = $cursor->next) {

	my $productid = $product_ref->{_id};
	my $code = $product_ref->{code};
	my $path = product_path($product_ref);

	# Retrieve the changes.sto file
	my $changes_ref = retrieve("$data_root/products/$path/changes.sto");
	if (defined $changes_ref) {

		my $first_change = 1;

		# Go through each change
		foreach my $change_ref (@{$changes_ref}) {
			# Get the timestamp and userid
			my $t = $change_ref->{t};
			my $userid = $change_ref->{userid} || "openfoodfacts-countributors";
			# Get the year
			my $year = (localtime($t))[5] + 1900;

			# First change: update products_added
			if ($first_change) {
				deep_set(\%products_added, $year, $code, 1);
				deep_set(\%products_added, "all", $code, 1);
				$first_change = 0;
			}

			# Update products_edited
			deep_set(\%products_edited, $year, $code, 1);
			deep_set(\%products_edited, "all", $code, 1);

			# Update the active editors
			deep_set(\%active_editors, $year, $userid, 1);
			deep_set(\%active_editors, "all", $userid, 1);

			# Update the first year of editors if the year is older than the current first year
			if (not defined $editors_first_year{$userid}) {
				$editors_first_year{$userid} = $year;
			}
			elsif ($year < $editors_first_year{$userid}) {
				$editors_first_year{$userid} = $year;
			}
		}
	}

	$i++;
	($i % 1000 == 0) and print STDERR "$i products checked\n";
}

# Compute the new editors by year
foreach my $userid (keys %editors_first_year) {
	$new_editors{$editors_first_year{$userid}}++;
	$new_editors{"all"}++;
}

# Print the active editors by year and for all years

print STDERR "Active editors by year:\n";
foreach my $year (sort keys %active_editors) {
	print STDERR "$year: " . (scalar keys %{$active_editors{$year}} || 0) . "\n";
}

# Print the new editors
print STDERR "New editors by year:\n";
foreach my $year (sort keys %new_editors) {
	print STDERR "$year: $new_editors{$year}\n";
}

# Print the products added by year
print STDERR "Products added by year:\n";
foreach my $year (sort keys %products_added) {
	print STDERR "$year: " . (scalar keys %{$products_added{$year}} || 0) . "\n";
}

# Print the products edited by year
print STDERR "Products edited by year:\n";
foreach my $year (sort keys %products_edited) {
	print STDERR "$year: " . (scalar keys %{$products_edited{$year}} || 0) . "\n";
}

# Compute the total number of products by year by summing the new products added in the year and previous years

foreach my $year (sort keys %products_added) {
	$number_of_products{$year} = 0;
	foreach my $year2 (sort keys %products_added) {
		next if $year2 eq "all";
		if (($year eq "all") or ($year2 <= $year)) {
			$number_of_products{$year} += scalar keys %{$products_added{$year2}};
		}
	}
}

# Print the total number of products by year
print STDERR "Total number of products by year:\n";
foreach my $year (sort keys %number_of_products) {
	print STDERR "$year: $number_of_products{$year}\n";
}

# Print all the stats by year in tab separated columns to STDOUT
print "year\tactive_editors\tnew_editors\tproducts_edited\tproducts_added\ttotal_products\n";
foreach my $year (sort keys %number_of_products) {
	print join("\t",
		$year, scalar keys %{$active_editors{$year}},
		$new_editors{$year},
		scalar keys %{$products_edited{$year}},
		scalar keys %{$products_added{$year}},
		$number_of_products{$year}) . "\n";
}

exit(0);
