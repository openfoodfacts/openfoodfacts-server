#!/usr/bin/perl -w

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
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

use Modern::Perl '2017';
use utf8;

use ProductOpener::Config qw/:all/;
use ProductOpener::Export qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Products qw/:all/;

use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;
use Time::Local;
use Data::Dumper;
use Getopt::Long;
use CGI qw(:cgi :cgi-lib);
use ProductOpener::Data qw/:all/;

binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");

my $usage = <<TXT
export_products_data_and_images.pl exports product data and/or images for a sample of products,
with files in the native format used by Product Opener:

- a .tar.gz archive containing product data
- a .tar.gz archive containg product images

Those 2 files can be uncompressed in the "products" and "html/images/products" directories of
Product Opener.

The --query parameter allows to select only products that match a specific query.

The --query-codes-from-file parameter allows to specify a file containing barcodes (one barcode per line).

The --sample_mod [divisor],[remainder] parameter allows to get a sample of products,
based on a modulo of their creation timestamp.
e.g. --sample_mod 10000,0 will return about 1/10000th of the full database.

Usage:

export_products_data_and_images.pl --query field_name=field_value --query other_field_name=other_field_value
[--products-file=path to .tar.gz file] [--images-file=path to .tar.gz file]
TXT
	;

my %query_fields_values = ();
my $query_codes_from_file;
my $products_file;
my $images_file;
my $sample_mod;

GetOptions(
	"query=s%" => \%query_fields_values,
	"query-codes-from-file=s" => \$query_codes_from_file,
	"images-file=s" => \$images_file,
	"products-file=s" => \$products_file,
	"sample-mod=s" => \$sample_mod,

) or die("Error in command line arguments:\n\n$usage");

print STDERR "export_products_data_and_images.pl
- query fields values:
";

my $query_ref = {};
my $request_ref = {};

foreach my $field (sort keys %query_fields_values) {
	print STDERR "-- $field: $query_fields_values{$field}\n";
	param($field, $query_fields_values{$field});
}

# Construct the MongoDB query

add_params_to_query($request_ref, $query_ref);

use boolean;

# Substitute values like null or exists to mongodb query values
foreach my $field (sort keys %{$query_ref}) {
	if ($query_ref->{$field} eq 'null') {
		# $query_ref->{$field} = { '$exists' => false };
		$query_ref->{$field} = undef;
	}
	if ($query_ref->{$field} eq 'exists') {
		$query_ref->{$field} = {'$exists' => true};
	}
}

# transform file of code list to a mongodb query
if (defined $query_codes_from_file) {
	my @codes = ();
	open(my $in, "<", "$query_codes_from_file") or die("Cannot read $query_codes_from_file: $!\n");
	while (<$in>) {
		if ($_ =~ /^(\d+)/) {
			push @codes, $1;
		}
	}
	close($in);
	$query_ref->{"code"} = {'$in' => \@codes};
}

# Sample of products whose creation timestamp modulo a divisor is equal to a remainder
if (defined $sample_mod) {
	if ($sample_mod =~ /^(\d+),(\d+)$/) {
		my $divisor = $1 + 0;    # add 0 to turn scalar into number
		my $remainder = $2 + 0;
		$query_ref->{"created_t"} = {'$mod' => [$divisor, $remainder]};
	}
	else {
		die("--sample-mod argument must be of the form divisor],remainder (e.g. 10,0):\n\n$usage");
	}
}

use Data::Dumper;
print STDERR "MongoDB query:\n" . Dumper($query_ref) . "\n";

# harvest products'code from mongo db
my $cursor = get_products_collection({timeout => 3 * 60 * 60 * 1000})->query($query_ref)->fields({"code" => 1})
	->sort({code => 1});

$cursor->immortal(1);

# Create a list of directories to be exported

my $files = "";
my $i = 0;

while (my $product_ref = $cursor->next) {
	$files .= product_path_from_id($product_ref->{code}) . "\n";
	$i++;
}

print STDERR "$i products to export.\n";

# Save the list of directories to a tmp file so that we can pass it as a parameter to tar

my $tmp_file = "/tmp/export_products_data_and_images." . time() . ".txt";

open(my $out, ">", $tmp_file) or die("Could not open $tmp_file for writing: $!\n");
print $out $files;
close($out);

if (defined $products_file) {
	my $tar_cmd = "cvf";
	if ($products_file =~ /\.gz$/) {
		$tar_cmd = "cvfz";
	}
	print STDERR "Executing tar command: tar $tar_cmd $products_file -C $data_root/products -T $tmp_file\n";
	system('tar', $tar_cmd, $products_file, "-C", "$data_root/products", "-T", $tmp_file);
}

if (defined $images_file) {
	my $tar_cmd = "cvf";
	# Probably not a good idea to compress images, but allow it anyway
	if ($images_file =~ /\.gz$/) {
		$tar_cmd = "cvfz";
	}
	print STDERR "Executing tar command: tar $tar_cmd $images_file -C $www_root/images/products -T $tmp_file\n";
	system('tar', $tar_cmd, $images_file, "-C", "$www_root/images/products", "-T", $tmp_file);
}

print STDERR "$i products exported.\n";
