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
use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Export qw/:all/;
use ProductOpener::Display qw/add_params_to_query/;
use ProductOpener::Products qw/product_path_from_id/;

use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::MaybeXS;
use Time::Local;
use Data::Dumper;
use Getopt::Long;
use CGI qw(:cgi :cgi-lib);
use ProductOpener::Data qw/get_products_collection/;

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
[--jsonl-file=path to jsonl.gz file] [--mongo-file=path to mongodbdump.gz file]
TXT
	;

my %query_fields_values = ();
my $query_codes_from_file;
my $products_file;
my $images_file;
my $jsonl_file;
my $mongo_file;
my $sample_mod;

GetOptions(
	"query=s%" => \%query_fields_values,
	"query-codes-from-file=s" => \$query_codes_from_file,
	"images-file=s" => \$images_file,
	"products-file=s" => \$products_file,
	"jsonl-file=s" => \$jsonl_file,
	"mongo-file=s" => \$mongo_file,
	"sample-mod=s" => \$sample_mod,

) or die("Error in command line arguments:\n\n$usage");

print STDERR "export_products_data_and_images.pl
- query fields values:
";

# build the query
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

# sto dupms
if ($products_file || $images_file) {
	# harvest products'code from mongo db
	my $cursor
		= get_products_collection({timeout => 3 * 60 * 60 * 1000})
		->query($query_ref)
		->fields({"code" => 1})
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
		print STDERR "Creating tar archive $products_file from $BASE_DIRS{PRODUCTS} using $tmp_file\n";
		eval {
			require Archive::Tar;
			require Cwd;
			require File::Find;
			open(my $list_fh, "<", $tmp_file) or die "Cannot read $tmp_file: $!";
			my @rel_paths = grep {$_ ne ""} map {chomp; $_} <$list_fh>;
			close($list_fh);
			my $cwd = Cwd::getcwd();
			chdir $BASE_DIRS{PRODUCTS} or die "Cannot chdir to $BASE_DIRS{PRODUCTS}: $!";
			my @all_files;
			File::Find::find(
				{
					wanted => sub {
						return if -d $_ && $_ eq ".";
						# Store relative path from $BASE_DIRS{PRODUCTS}
						my $rel = $File::Find::name;
						$rel =~ s|^\./||;
						push @all_files, $rel if -f $File::Find::name || -d $File::Find::name;
					},
					no_chdir => 0,
				},
				@rel_paths
			);
			# Fallback: if find collected nothing (e.g. empty dirs), add rel_paths directly
			if (!@all_files) {
				@all_files = @rel_paths;
			}
			my $tar = Archive::Tar->new;
			$tar->add_files(@all_files);
			my $compress = ($products_file =~ /\.gz$/) ? 1 : 0;
			$tar->write($products_file, $compress);
			chdir $cwd or die "Cannot chdir back to $cwd: $!";
		};
		if ($@) {
			warn "Failed to create tar $products_file: $@\n";
		}
	}

	if (defined $images_file) {
		print STDERR "Creating tar archive $images_file from $BASE_DIRS{PRODUCTS_IMAGES} using $tmp_file\n";
		eval {
			require Archive::Tar;
			require Cwd;
			require File::Find;
			open(my $list_fh, "<", $tmp_file) or die "Cannot read $tmp_file: $!";
			my @rel_paths = grep {$_ ne ""} map {chomp; $_} <$list_fh>;
			close($list_fh);
			my $cwd = Cwd::getcwd();
			chdir $BASE_DIRS{PRODUCTS_IMAGES} or die "Cannot chdir to $BASE_DIRS{PRODUCTS_IMAGES}: $!";
			my @all_files;
			File::Find::find(
				{
					wanted => sub {
						return if -d $_ && $_ eq ".";
						my $rel = $File::Find::name;
						$rel =~ s|^\./||;
						push @all_files, $rel if -f $File::Find::name || -d $File::Find::name;
					},
					no_chdir => 0,
				},
				@rel_paths
			);
			if (!@all_files) {
				@all_files = @rel_paths;
			}
			my $tar = Archive::Tar->new;
			$tar->add_files(@all_files);
			my $compress = ($images_file =~ /\.gz$/) ? 1 : 0;
			$tar->write($images_file, $compress);
			chdir $cwd or die "Cannot chdir back to $cwd: $!";
		};
		if ($@) {
			warn "Failed to create tar $images_file: $@\n";
		}
	}

	print STDERR "$i products exported.\n";
}

# mongodb dumps
if ($jsonl_file || $mongo_file) {
	my @mongo_args = ("--host", $mongodb_host, "--collection", "products", "--db", $mongodb);
	my $json = JSON->new->utf8->allow_nonref->canonical;
	my $query_str = $json->encode($query_ref);
	push(@mongo_args, "--query", "'$query_str'");
	if ($jsonl_file) {
		my $cmd = join(" ", ('mongoexport', @mongo_args, '|', 'gzip', '>', "'$jsonl_file'"));
		print(STDERR "Executing mongoexport command: $cmd\n");
		system($cmd);
	}
	if ($mongo_file) {
		my $cmd = join(" ", ('mongodump', @mongo_args, '--gzip', "--archive='$mongo_file'"));
		print(STDERR "Executing mongodump command: $cmd\n");
		system($cmd);
	}
}

