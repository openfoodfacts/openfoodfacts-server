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

use File::Copy (qw/move/);

use Data::Dumper;

sub normalize_code_zeroes($code) {

	# Remove leading zeroes
	$code =~ s/^0+//;

	# Add leading zeroes to have at least 13 digits
	if (length($code) < 13) {
		$code = "0" x (13 - length($code)) . $code;
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
	if (length($code) < 13) {
		$code = "0" x (13 - length($code)) . $code;
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

sub ensure_dir_created_or_die ($path, $mode = oct(755)) {
	# search base directory
	my $prefix;
	my $suffix;
	my @base_dirs = ($data_root, $www_root);
	foreach my $prefix_candidate (@base_dirs) {
		if ($path =~ /^$prefix_candidate/) {
			$prefix = $prefix_candidate;
			$suffix = $';
			last;
		}
	}
	if (!defined $prefix) {
		die("Could not create $path, no corresponding base directory found in " . join(":", @base_dirs));
		return;
	}
	# ensure the rest of the path
	foreach my $component (split(/\//, $suffix)) {
		$prefix .= "/$component";
		(-e $prefix) or mkdir($prefix);
	}
	return (-e $path);
}

sub product_dir_move($source, $target) {
	# If the source does not contain directories, use move() to move it directly
	# otherwise, create the target directory, go through all files in the source, and use move() to move them to the target, but do not move contained directories
	# then remove the source directory

	# First check if source contains directories
	my $contains_directories = 0;
	opendir my $dh, $source or die "could not open $source directory: $!\n";
	foreach my $dir (sort readdir($dh)) {
		chomp($dir);
		next if $dir eq '.';
		next if $dir eq '..';
		next if $dir =~ /\.lock/;	# lingering lock files
		if (-d "$source/$dir") {
			$contains_directories = 1;
			last;
		}
	}

	# If source does not contain directories, use move() to move it directly
	if (!$contains_directories) {
		return move($source, $target);
	}

	print STDERR "source $source contains directories, moving files instead of directory\n";

	# Otherwise, create the target directory
	ensure_dir_created_or_die($target);

	# Go through all files in the source
	opendir my $dh, $source or die "could not open $source directory: $!\n";
	foreach my $file (sort readdir($dh)) {
		chomp($file);
		# Move files and symbolic links
		if (!-d "$source/$file") {
			move("$source/$file", "$target/$file") or die "could not move $source/$file to $target/$file: $!\n";
		}
	}

	# Remove the source directory
	rmdir($source);

	return 1;
}

# Get a list of all products

use Getopt::Long;

my @products = ();
my $move = 0;
my $product_paths_containing_other_products = 0;

my $products_collection = get_products_collection();
my $obsolete_products_collection = get_products_collection({obsolete => 1});

GetOptions('products=s' => \@products, 'move' => \$move);
@products = split(/,/, join(',', @products));

my $d = 0;

open(my $log, ">>", "$data_root/logs/move_ean8_products_to_new_path.log");
print $log "move_ean8_products_to_new_path.pl started at " . localtime() . "\n";

open(my $csv, ">>", "$data_root/logs/move_ean8_products_to_new_path.csv");

ensure_dir_created_or_die("$data_root/products/invalid-codes");

if ((scalar @products) == 0) {
	# Look for products with EAN8 codes directly in the product root

	my $dh;

	opendir $dh, "$data_root/products" or die "could not open $data_root/products directory: $!\n";
	foreach my $dir (sort readdir($dh)) {
		chomp($dir);

		# Check it is a directory
		next if not -d "$data_root/products/$dir";
		next if ($dir eq "invalid-codes");

		if ($dir =~ /^\d\d\d$/) {

			# We can have products with 9 to 12 digits that have a split path but that were not padded with 0s
			# e.g. 000/001/112/22/ should be moved to 000/000/011/1222/
			opendir my $dh2, "$data_root/products/$dir"
				or die "ERROR: could not open $data_root/products/$dir directory: $!\n";
			foreach my $dir2 (sort readdir($dh2)) {
				chomp($dir2);
				if ($dir2 =~ /^\d\d\d$/) {
					opendir my $dh3, "$data_root/products/$dir/$dir2"
						or die "ERROR: could not open $data_root/products/$dir/$dir2 directory: $!\n";
					foreach my $dir3 (sort readdir($dh3)) {
						chomp($dir3);
						if ($dir3 =~ /^\d\d\d$/) {
							opendir my $dh4, "$data_root/products/$dir/$dir2/$dir3"
								or die "ERROR: could not open $data_root/products/$dir/$dir2/$dir3 directory: $!\n";
							my $level4_dirs = 0;
							foreach my $dir4 (sort readdir($dh4)) {
								chomp($dir4);
								# We should have 4 digits or more (for codes with more than 13 digits)
								if ($dir4 =~ /^\d+$/) {
									if ($dir4 !~ /^\d\d\d\d/) {

										if (-e "$data_root/products/$dir/$dir2/$dir3/$dir4/product.sto") {
											push @products, "$dir/$dir2/$dir3/$dir4";
											print STDERR
												"nested dir with less than 13 digits: $dir/$dir2/$dir3/$dir4\n";
											print $log "nested dir with less than 13 digits: $dir/$dir2/$dir3/$dir4\n";
											$d++;
											(($d % 1000) == 1)
												and print STDERR "$d products - $dir/$dir2/$dir3/$dir4\n";
										}
									}
									$level4_dirs++;
								}

							}
							closedir $dh4;

							# Check if there is a product.sto file in the directory (happens when the barcode has 9 digits: the path is split, but there is no leftover)
							if (-e "$data_root/products/$dir/$dir2/$dir3/product.sto") {

								print STDERR "nested dir with 9 digits: $dir/$dir2/$dir3\n";
								print $log "nested dir with 9 digits: $dir/$dir2/$dir3\n";

								if ($level4_dirs == 0) {
									push @products, "$dir/$dir2/$dir3";
									$d++;
									print STDERR
										"nested dir with 9 digits: $dir/$dir2/$dir3 --> does not have level 4 dirs, ok to move level 3 dir\n";
									print $log
										"nested dir with 9 digits: $dir/$dir2/$dir3 --> does not have level 4 dirs, ok to move level 3 dir\n";
								}
								else {
									push @products, "$dir/$dir2/$dir3";
									$d++;
									print STDERR
										"nested dir 9 with digits: $dir/$dir2/$dir3 --> has $level4_dirs level 4 dirs, need to move files instead of dir\n";
									print $log
										"nested dir with 9 digits: $dir/$dir2/$dir3 --> has $level4_dirs level 4 dirs, need to move files instead of dir\n";
									$product_paths_containing_other_products++;
								}
								$d++;
							}
						}

					}
					closedir $dh3;
				}
			}
			closedir $dh2;

		}
		# Don't move dirs with 1 or 2 digits
		elsif (($dir !~ /^\d\d?$/) and ($dir =~ /^\d+$/)) {
			# Product directories at the root, with a different number than 3 digits
			if (-e "$data_root/products/$dir/product.sto") {
				push @products, $dir;
				$d++;
				(($d % 1000) == 1) and print STDERR "$d products - $dir\n";
			}
		}
		elsif ($dir !~ /^\.+$/) {
			print STDERR "invalid code: $dir\n";
			print $log "invalid code: $dir\n";
			# Move the dir to $data_root/products/invalid-codes
			if ($move) {
				if (move("$data_root/products/$dir", "$data_root/products/invalid-codes/$dir")) {
					print STDERR "moved invalid code $dir to $data_root/products/invalid-codes\n";
					print $log "moved invalid code $dir to $data_root/products/invalid-codes\n";
				}
				else {
					print STDERR "could not move invalid code $dir to $data_root/products/invalid-codes\n";
					print $log "could not move invalid code $dir to $data_root/products/invalid-codes\n";
				}
				# Delete from mongodb
				$products_collection->delete_one({code => $dir});
				$obsolete_products_collection->delete_one({code => $dir});
			}
		}
	}
	closedir $dh;
}

my $count = scalar @products;

print STDERR "$count products to update\n";

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

	my $old_product_id = product_id_for_owner(undef, $code);
	my $product_id = product_id_for_owner(undef, $new_code);

	my $path = new_product_path_from_id($product_id);

	my $product_ref = retrieve_product($old_product_id, "include_deleted");

	my $deleted = $product_ref->{deleted} ? "deleted" : "";
	my $obsolete = $product_ref->{obsolete} ? "obsolete" : "";

	print $csv "$code\t$new_code\t$old_path\t$path\t$obsolete\t$deleted\n";

	if ($path eq "invalid") {
		$invalid++;
		print STDERR "invalid path for code $code (old path: $old_path)\n";
		print $log "invalid path for code $code (old path: $old_path)\n";
	}
	elsif ($path ne $old_path) {

		if (    (!-e "$data_root/products/$path")
			and (!-e "$www_root/images/products/$path"))
		{
			print STDERR "$code - $obsolete - $deleted - $path does not exist, moving $old_path\n";
			print $log "$code - $obsolete - $deleted - $path does not exist, moving $old_path\n";
			$moved++;

			if ($move) {

				my $prefix_path = $path;
				$prefix_path =~ s/\/[^\/]+$//;    # remove the last subdir: we'll move it
				ensure_dir_created_or_die("$data_root/products/$prefix_path");
				ensure_dir_created_or_die("$www_root/images/products/$prefix_path");

				if (    (!-e "$data_root/products/$path")
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

					# In this script, we want to avoid creating copies as we are using zfs, so we use File::Copy move()

					print STDERR ("moving product data $data_root/products/$old_path to $data_root/products/$path\n");
					print $log ("moving product data $data_root/products/$old_path to $data_root/products/$path\n");

					if (not product_dir_move("$data_root/products/$old_path", "$data_root/products/$path")) {
						print STDERR (
							"ERROR: could not move product data from $data_root/products/$old_path to $data_root/products/$path : $!\n"
						);
						print $log (
							"ERROR: could not move product data from $data_root/products/$old_path to $data_root/products/$path : $!\n"
						);
						$moved--;
						$not_moved++;
					}
					elsif (-e "$www_root/images/products/$old_path")	{

						print STDERR (
							"moving product images $www_root/images/products/$old_path to $www_root/images/products/$path\n"
						);

						print $log (
							"moving product images $www_root/images/products/$old_path to $www_root/images/products/$path\n"
						);

						if (
							not product_dir_move("$www_root/images/products/$old_path",
								"$www_root/images/products/$path"))
						{
							print STDERR (
								"ERROR: could not move product images from $www_root/images/products/$old_path to $www_root/images/products/$path : $!\n"
							);
							print $log (
								"ERROR: could not move product images from $www_root/images/products/$old_path to $www_root/images/products/$path : $!\n"
							);
						}

						# If the code changed, need to update the product .sto file and to remove the old code from MongoDB and to add the new code in MongoDB
						if ($new_code ne $code) {

							my $product_ref = retrieve_product($product_id, "include_deleted");
							$product_ref->{code} = $new_code . '';
							$product_ref->{id} = $product_ref->{code} . '';    # treat id as string;
							$product_ref->{_id} = $product_ref->{code} . '';    # treat id as string;
								# Delete the old code from MongoDB collections
							$products_collection->delete_one({code => $code});
							$obsolete_products_collection->delete_one({code => $code});
							# If the product is not deleted, store_product will add the new code to MongoDB
							store_product("fix-code-bot", $product_ref, "changed code from $code to $new_code");
							print STDERR "updated code from $code to $new_code in .sto file and MongoDB\n";
							print $log "updated code from $code to $new_code in .sto file and MongoDB\n";
						}
					}

				}
				#exit;
				#($moved % 10 == 0) and exit;
			}

			if ($new_code ne $code) {
				$changed_code++;
				print STDERR "changed code from $code to $new_code\n";
				print $log "changed code from $code to $new_code\n";
			}
		}
		else {
			print STDERR "new path exists, not moving $old_path to $path\n";
			print $log "new path exists, not moving $old_path to $path\n";
			$not_moved++;
		}

	}
	else {
		print STDERR "new $path is the same as old $old_path\n";
		print $log "new $path is the same as old $old_path\n";
		$same_path++;
	}
}

print STDERR "$count products at the root or not split into a 4 component path\n";
print STDERR "$product_paths_containing_other_products products paths containing other products\n";
print STDERR "invalid code: $invalid\n";
print STDERR "moved: $moved\n";
print STDERR "not moved: $not_moved\n";
print STDERR "same path: $same_path\n";
print STDERR "changed code: $changed_code\n";

exit(0);

