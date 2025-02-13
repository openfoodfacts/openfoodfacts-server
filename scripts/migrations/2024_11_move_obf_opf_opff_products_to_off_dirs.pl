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

use ProductOpener::PerlStandards;

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
use ProductOpener::Orgs qw/:all/;
use ProductOpener::Paths qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;

use File::Copy::Recursive qw/dirmove/;

use Data::Dumper;

# Get a list of all products

use Getopt::Long;

my $move = 0;

GetOptions('move' => \$move,);

my @dirs_without_product_sto = ();
my @empty_dirs = ();
my @products_existing_on_off = ();
my @products_not_existing_on_off = ();
my @products_existing_on_off_but_deleted_on_off = ();
my @products_existing_on_off_but_deleted_locally = ();
my @products_existing_on_off_and_not_deleted_on_off_or_locally = ();

# We removed the other servers dirs from the base paths,
# but for this script, we need /srv/off/products and /srv/off/html/images/products

$BASE_DIRS{OFF_PRODUCTS} = "/srv/off/products";
$BASE_DIRS{OFF_PRODUCTS_IMAGES} = "/srv/off/html/images/products";

sub move_product_dir_to_off ($dir, $dir2, $dir3, $dir4) {
	# move .sto files
	print STDERR "moving $dir/$dir2/$dir3/$dir4\n";
	ensure_dir_created_or_die("/srv/off/products/$dir/$dir2/$dir3");
	# if there is an existing off directory for this product, move it to deleted-off-products-codes-replaced-by-other-flavors
	if (-e "/srv/off/products/$dir/$dir2/$dir3/$dir4") {
		print STDERR "moving existing product on OFF\n";
		if (
			dirmove(
				"/srv/off/products/$dir/$dir2/$dir3/$dir4",
				"/srv/off/products/deleted-off-products-codes-replaced-by-other-flavors/$dir$dir2$dir3$dir4"
			)
			)
		{
			print STDERR
				"moved /srv/off/products/$dir/$dir2/$dir3/$dir4 to /srv/off/products/deleted-off-products-codes-replaced-by-other-flavors/$dir$dir2$dir3$dir4\n";
		}
		else {
			print STDERR
				"could not move /srv/off/products/$dir/$dir2/$dir3/$dir4 to /srv/off/products/deleted-off-products-codes-replaced-by-other-flavors/$dir$dir2$dir3$dir4: $!\n";
			die;
		}
	}
	# move the directory to /srv/off/products
	if (dirmove("/mnt/$flavor/products/$dir/$dir2/$dir3/$dir4", "/srv/off/products/$dir/$dir2/$dir3/$dir4")) {
		print STDERR "moved /mnt/$flavor/products/$dir/$dir2/$dir3/$dir4 to /srv/off/products/$dir/$dir2/$dir3/$dir4\n";
	}
	else {
		print STDERR
			"could not move /mnt/$flavor/products/$dir/$dir2/$dir3/$dir4 to /srv/off/products/$dir/$dir2/$dir3/$dir4: $!\n";
		die;
	}

	# move images if they exist
	if (-e "/mnt/$flavor/images/products/$dir/$dir2/$dir3/$dir4") {
		print STDERR "moving images from /mnt/$flavor/images/products/$dir/$dir2/$dir3/$dir4\n";
		ensure_dir_created_or_die("/srv/off/html/images/products/$dir/$dir2/$dir3");
		# if there is an existing off directory for this product, move it to deleted-off-products-codes-replaced-by-other-flavors
		if (-e "/srv/off/html/images/products/$dir/$dir2/$dir3/$dir4") {
			print STDERR "moving existing product images on OFF\n";
			if (
				dirmove(
					"/srv/off/html/images/products/$dir/$dir2/$dir3/$dir4",
					"/srv/off/html/images/products/deleted-off-products-codes-replaced-by-other-flavors/$dir$dir2$dir3$dir4"
				)
				)
			{
				print STDERR
					"moved /srv/off/html/images/products/$dir/$dir2/$dir3/$dir4 to /srv/off/html/images/products/deleted-off-products-codes-replaced-by-other-flavors/$dir$dir2$dir3$dir4\n";
			}
			else {
				print STDERR
					"could not move /srv/off/html/images/products/$dir/$dir2/$dir3/$dir4 to /srv/off/html/images/products/deleted-off-products-codes-replaced-by-other-flavors/$dir$dir2$dir3$dir4: $!\n";
				die;
			}
		}
		if (
			dirmove(
				"/mnt/$flavor/images/products/$dir/$dir2/$dir3/$dir4",
				"/srv/off/html/images/products/$dir/$dir2/$dir3/$dir4"
			)
			)
		{
			print STDERR
				"moved /mnt/$flavor/images/products/$dir/$dir2/$dir3/$dir4 to /srv/off/html/images/products/$dir/$dir2/$dir3/$dir4\n";
		}
		else {
			print STDERR
				"could not move /mnt/$flavor/images/products/$dir/$dir2/$dir3/$dir4 to /srv/off/html/images/products/$dir/$dir2/$dir3/$dir4: $!\n";
			die;
		}
	}
	die;
	return;
}

sub check_if_we_can_move_product_dir_to_off ($dir, $dir2, $dir3, $dir4) {
	# Check if the product.sto file exists locally
	my $local_product_ref = retrieve("/mnt/$flavor/products/$dir/$dir2/$dir3/$dir4/product.sto");
	if ($local_product_ref) {
		# Check if the product exists on OFF
		my $off_product_ref = retrieve("/srv/off/products/$dir/$dir2/$dir3/$dir4/product.sto");
		if ($off_product_ref) {
			push @products_existing_on_off, "$dir/$dir2/$dir3/$dir4";
			# Check if the product is deleted on OFF
			if ($off_product_ref->{deleted}) {
				push @products_existing_on_off_but_deleted_on_off, "$dir/$dir2/$dir3/$dir4";
				if ($move) {
					move_product_dir_to_off($dir, $dir2, $dir3, $dir4);
				}
			}
			elsif ($local_product_ref->{deleted}) {
				push @products_existing_on_off_but_deleted_locally, "$dir/$dir2/$dir3/$dir4";
			}
			else {
				push @products_existing_on_off_and_not_deleted_on_off_or_locally, "$dir/$dir2/$dir3/$dir4";
			}
		}
		else {
			push @products_not_existing_on_off, "$dir/$dir2/$dir3/$dir4";
			if ($move) {
				move_product_dir_to_off($dir, $dir2, $dir3, $dir4);
			}
		}
	}
	else {
		push @dirs_without_product_sto, "$dir/$dir2/$dir3/$dir4";
		# Check if the dir is empty
		opendir my $dh, "/mnt/$flavor/products/$dir/$dir2/$dir3/$dir4" or die "Cannot open directory: $!";
		my @files = grep {$_ ne '.' && $_ ne '..'} readdir($dh);
		closedir $dh;
		if (scalar @files == 0) {
			push @empty_dirs, "$dir/$dir2/$dir3/$dir4";
		}
	}
	return;
}

my @products = ();

my $dh;

opendir $dh, "/mnt/$flavor/products"
	or die "could not open /mnt/$flavor/products directory: $!\n";
foreach my $dir (sort readdir($dh)) {
	chomp($dir);

	print STDERR "dir: $dir\n";

	# Check it is a directory
	next if not -d "/mnt/$flavor/products/$dir";
	next if ($dir =~ /codes/);

	if ($dir =~ /^\d\d\d$/) {

		opendir my $dh2, "/mnt/$flavor/products/$dir"
			or die "ERROR: could not open /mnt/$flavor/products/$dir directory: $!\n";
		foreach my $dir2 (sort readdir($dh2)) {
			chomp($dir2);
			if ($dir2 =~ /^\d\d\d$/) {
				opendir my $dh3, "/mnt/$flavor/products/$dir/$dir2"
					or die "ERROR: could not open /mnt/$flavor/products/$dir/$dir2 directory: $!\n";
				foreach my $dir3 (sort readdir($dh3)) {
					chomp($dir3);
					if ($dir3 =~ /^\d\d\d$/) {
						opendir my $dh4, "/mnt/$flavor/products/$dir/$dir2/$dir3"
							or die "ERROR: could not open /mnt/$flavor/products/$dir/$dir2/$dir3 directory: $!\n";
						foreach my $dir4 (sort readdir($dh4)) {
							chomp($dir4);
							# We should have 4 digits or more (for codes with more than 13 digits)
							if ($dir4 =~ /^\d+$/) {
								push @products, "$dir/$dir2/$dir3/$dir4";
								check_if_we_can_move_product_dir_to_off($dir, $dir2, $dir3, $dir4);
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
}
closedir $dh;

my $count = scalar @products;
print STDERR "Found $count products\n";

# Print the number of products in the different cases
print STDERR "Products not existing on OFF: " . scalar @products_not_existing_on_off . "\n";
print STDERR "Products existing on OFF: " . scalar @products_existing_on_off . "\n";
print STDERR "Products existing on OFF but deleted on OFF: "
	. scalar @products_existing_on_off_but_deleted_on_off . "\n";
print STDERR "Products existing on OFF but deleted locally: "
	. scalar @products_existing_on_off_but_deleted_locally . "\n";
print STDERR "Products existing on OFF and not deleted on OFF or locally: "
	. scalar @products_existing_on_off_and_not_deleted_on_off_or_locally . "\n";
print STDERR "Dirs without product.sto: " . scalar @dirs_without_product_sto . "\n";
print STDERR "Empty dirs: " . scalar @empty_dirs . "\n";

exit(0);

