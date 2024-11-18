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

# find all dirs in /srv/opf/products/other-flavors-codes

my $dh;

my @dirs_existing_in_off;
my @dirs_not_existing_in_off;

opendir $dh, "/srv/opf/products/other-flavors-codes"
	or die "could not open /srv/opf/products directory: $!\n";
foreach my $dir (sort readdir($dh)) {
	chomp($dir);
	# Check it is a directory
	next if not -d "/srv/opf/products/other-flavors-codes/$dir";
	print STDERR "dir: $dir\n";

	if ($dir =~ /^(\d\d\d)(\d\d\d)(\d\d\d)(\d+)$/) {
		# check if the dir exists in /srv/off/products
		if (-e "/srv/off/products/$1/$2/$3/$4") {
			push @dirs_existing_in_off, $dir;
			print STDERR "dir exists in /srv/off/products/$1/$2/$3/$4\n";
		}
		else {
			push @dirs_not_existing_in_off, $dir;
			print STDERR "dir does not exist in /srv/off/products/$1/$2/$3/$4\n";
			if ($move) {
				move_product_dir_to_off($1, $2, $3, $4);
			}
		}
	}
}

$BASE_DIRS{OFF_PRODUCTS} = "/srv/off/products";
$BASE_DIRS{OFF_PRODUCTS_IMAGES} = "/srv/off/html/images/products";

sub move_product_dir_to_off ($dir, $dir2, $dir3, $dir4) {
	# move .sto files
	print STDERR
		"moving /srv/opf/products/other-flavors-codes/$dir$dir2$dir3$dir4 to /srv/off/products/$dir/$dir2/$dir3/$dir4\n";
	#ensure_dir_created_or_die("/srv/off/products/$dir/$dir2/$dir3");
	# if there is an existing off directory for this product, move it to deleted-off-products-codes-replaced-by-other-flavors
	if (0 and -e "/srv/off/products/$dir/$dir2/$dir3/$dir4") {
		print STDERR "moving existing product on OFF\n";
		if (
			dirmove(
				"/srv/off/products/deleted-off-products-codes-replaced-by-other-flavors/$dir$dir2$dir3$dir4",
				"/srv/off/products/$dir/$dir2/$dir3/$dir4"
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
	if (
		dirmove(
			"/srv/opf/products/other-flavors-codes/$dir$dir2$dir3$dir4", "/srv/off/products/$dir/$dir2/$dir3/$dir4"
		)
		)
	{
		print STDERR
			"moved /srv/opf/products/other-flavors-codes/$dir$dir2$dir3$dir4 to /srv/off/products/$dir/$dir2/$dir3/$dir4\n";
	}
	else {
		print STDERR
			"could not move /srv/opf/products/other-flavors-codes/$dir$dir2$dir3$dir4 to /srv/off/products/$dir/$dir2/$dir3/$dir4: $!\n";
		die;
	}

	# move images if they exist
	if (-e "/srv/opf/html/images/products/other-flavors-codes/$dir$dir2$dir3$dir4") {
		print STDERR "moving images from /srv/opf/html/images/products/other-flavors-codes/$dir$dir2$dir3$dir4\n";
		#ensure_dir_created_or_die("/srv/off/html/images/products/$dir/$dir2/$dir3");
		# if there is an existing off directory for this product, move it to deleted-off-products-codes-replaced-by-other-flavors
		if (0 and -e "/srv/off/html/images/products/$dir/$dir2/$dir3/$dir4") {
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
				"/srv/opf/html/images/products/other-flavors-codes/$dir$dir2$dir3$dir4",
				"/srv/off/html/images/products/$dir/$dir2/$dir3/$dir4"
			)
			)
		{
			print STDERR
				"moved /srv/opf/html/images/products/other-flavors-codes/$dir$dir2$dir3$dir4 to /srv/off/html/images/products/$dir/$dir2/$dir3/$dir4\n";
		}
		else {
			print STDERR
				"could not move /srv/opf/html/images/products/other-flavors-codes/$dir$dir2$dir3$dir4 to /srv/off/html/images/products/$dir/$dir2/$dir3/$dir4: $!\n";
			die;
		}
	}
	die;
	return;
}

print STDERR "dirs existing in off: " . scalar(@dirs_existing_in_off) . "\n";
print STDERR "dirs not existing in off: " . scalar(@dirs_not_existing_in_off) . "\n";

exit(0);

