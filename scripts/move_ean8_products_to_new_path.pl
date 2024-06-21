#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2019 Association Open Food Facts
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

use CGI::Carp qw(fatalsToBrowser);

# use ProductOpener::PerlStandards;
# not available in old versions of ProductOpener running on obf, opf, opff

use 5.24.0;
use strict;
use warnings;
use feature (qw/signatures :5.24/);
use utf8;

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Mail qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Data qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;

use Data::Dumper;

sub normalize_code_zeroes($code) {

	# Remove leading zeroes
	$code =~ s/^0+//;
	
	# Add leading zeroes to have at least 13 digits
	while (length($code) < 13) {
		$code = "0" . $code;
	}

	# Remove leading zeroes for EAN8s
	if ((length($code) eq 13) and ($code =~ /^00000/)) {
		$code = $';
	}	

	return $code;
}

# This script includes a new_split_code() function so that we can run it even if Products.pm split_code() is old
# This is useful in particular for preparations before the move, e.g. to see which products would be affected

sub is_valid_code ($code) {
	# Return an empty string if $code is undef
	return '' if !defined $code;
	return $code =~ /^\d{4,24}$/;
}

sub new_split_code ($code) {

	# Require at least 4 digits (some stores use very short internal barcodes, they are likely to be conflicting)
	if (not is_valid_code($code)) {
		return "invalid";
	}

	# Pad code with 0s if it has less than 13 digits
	while (length($code) < 13) {
		$code = "0" . $code;
	}

	# First splits into 3 sections of 3 numbers and the last section with the remaining numbers
	my $path = $code;
	if ($code =~ /^(.{3})(.{3})(.{3})(.*)$/) {
		$path = "$1/$2/$3/$4";
	}
	return $path;
}

sub new_product_path_from_id ($product_id) {

	my $product_id_without_server = $product_id;
	$product_id_without_server =~ s/(.*)://;

	if (    (defined $server_options{private_products})
		and ($server_options{private_products})
		and ($product_id_without_server =~ /\//))
	{
		return $` . "/" . new_split_code($');
	}
	else {
		return new_split_code($product_id_without_server);
	}

}

# Get a list of all products

use Getopt::Long;

my @products = ();
my $move = 0;

GetOptions('products=s' => \@products, 'move' => \$move);
@products = split(/,/, join(',', @products));

my $d = 0;

if (scalar $#products < 0) {
	# Look for products with EAN8 codes directly in the product root

	my $dh;

	opendir $dh, "$data_root/products" or die "could not open $data_root/products directory: $!\n";
	foreach my $dir (sort readdir($dh)) {
		chomp($dir);

		if ($dir =~ /^\d\d\d$/) {

			# We can have products with 9 to 12 digits that have a split path but that were not padded with 0s
			# e.g. 000/001/112/22/ should be moved to 000/000/011/1222/
			opendir my $dh2, "$data_root/products/$dir"
				or die "could not open $data_root/products/$dir directory: $!\n";
			foreach my $dir2 (sort readdir($dh2)) {
				chomp($dir2);
				if ($dir2 =~ /^\d\d\d$/) {
					opendir my $dh3, "$data_root/products/$dir/$dir2"
						or die "could not open $data_root/products/$dir/$dir2 directory: $!\n";
					foreach my $dir3 (sort readdir($dh3)) {
						chomp($dir3);
						if ($dir3 =~ /^\d\d\d$/) {
							opendir my $dh4, "$data_root/products/$dir/$dir2/$dir3"
								or die "could not open $data_root/products/$dir/$dir2/$dir3 directory: $!\n";
							foreach my $dir4 (sort readdir($dh4)) {
								chomp($dir4);
								# We should have 4 digits or more (for codes with more than 13 digits)
								if (($dir4 =~ /\d/) and ($dir4 !~ /^\d\d\d\d/)) {

									if (-e "$data_root/products/$dir/$dir2/$dir3/$dir4/product.sto") {
										push @products, "$dir/$dir2/$dir3/$dir4";
										print "nested dir with less than 13 digits: $dir/$dir2/$dir3/$dir4\n";
										$d++;
										(($d % 1000) == 1) and print STDERR "$d products - $dir/$dir2/$dir3/$dir4\n";
									}
								}
							}
							closedir $dh4;
						}

					}
					closedir $dh3;
				}
			}
			closedir $dh2;

		}
		else {
			# Product directories at the root, with a different number than 3 digits
			if (-e "$data_root/products/$dir/product.sto") {
				push @products, $dir;
				$d++;
				(($d % 1000) == 1) and print STDERR "$d products - $dir\n";
			}
		}
	}
	closedir $dh;
}

my $count = $#products;
my $i = 0;

print STDERR "$count products to update\n";

my $products_collection = get_products_collection();

my $invalid = 0;
my $moved = 0;
my $not_moved = 0;
my $same_path = 0;
my $changed_code = 0;

foreach my $old_path (@products) {

	my $code = $old_path;
	# remove / if any
	$code =~ s/\///g;

	my $new_code = normalize_code_zeroes($code);

	my $product_id = product_id_for_owner(undef, $new_code);

	my $path = new_product_path_from_id($product_id);

	if ($path eq "invalid") {
		$invalid++;
		print STDERR "invalid path for code $code (old path: $old_path)\n";
	}
	elsif ($path ne $old_path) {

		if (not -e "$data_root/products/$path") {
			print STDERR "$path does not exist, moving $old_path\n";
			$moved++;

			if ($move) {

				my $prefix_path = $path;
				$prefix_path =~ s/\/[^\/]+$//;    # remove the last subdir: we'll move it
				ensure_dir_created_or_die("$data_root/products/$prefix_path");
				ensure_dir_created_or_die("$www_root/images/products/$prefix_path");

				if (    (!-e "data_root/products/$path")
					and (!-e "$www_root/images/products/$path"))
				{
					# File::Copy move() is intended to move files, not
					# directories. It does work on directories if the
					# source and target are on the same file system
					# (in which case the directory is just renamed),
					# but fails otherwise.
					# An alternative is to use File::Copy::Recursive
					# but then it will do a copy even if it is the same
					# file system...
					# Another option is to call the system mv command.
					#
					# use File::Copy;

					File::Copy::Recursive->import(qw( dirmove ));

					print STDERR ("moving product data $data_root/products/$old_path to $data_root/products/$path\n");

					dirmove("$data_root/products/$old_path", "$data_root/products/$path")
						or print STDERR ("could not move product data: $!\n");

					print STDERR (
						"moving product images $www_root/images/products/$old_path to $www_root/images/products/$path\n"
					);

					dirmove("$www_root/images/products/$old_path", "$www_root/images/products/$path")
						or print STDERR ("could not move product images: $!\n");

				}
			}
		}
		else {
			print STDERR "$path exist, not moving $old_path\n";
			$not_moved++;
		}

	if ($new_code ne $code) {
		$changed_code++;
		print STDERR "changed code from $code to $new_code\n";
	}

	}
	else {
		print STDERR "new $path is the same as old $old_path\n";
		$same_path++;
	}
}

print STDERR "$count products at the root - $i products not empty or deleted\n";
print STDERR "invalid code: $invalid\n";
print STDERR "moved: $moved\n";
print STDERR "not moved: $not_moved\n";
print STDERR "same path: $same_path\n";
print STDERR "changed code: $changed_code\n";

exit(0);

