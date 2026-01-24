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
use ProductOpener::Texts qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Mail qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::Ingredients qw/:all/;
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
my $num_moved = 0;
my $num_skipped = 0;
my $num_errors = 0;

GetOptions('move' => \$move,);

# Get MongoDB collections for OFF
my $off_products_collection;
my $off_obsolete_products_collection;
if ($move) {
	eval {
		$off_products_collection = get_products_collection({database => 'off'});
		$off_obsolete_products_collection = get_products_collection({database => 'off', obsolete => 1});
	};
	if ($@) {
		die "ERROR: Failed to connect to OFF MongoDB collections: $@\n";
	}
}

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
	my $code = "$dir$dir2$dir3$dir4";
	
	print STDERR "Processing product $code...\n";
	
	eval {
		# Ensure parent directories exist
		ensure_dir_created_or_die("/srv/off/products/$dir/$dir2/$dir3");
		
		# Move product data
		print STDERR "Moving /srv/opf/products/other-flavors-codes/$code to /srv/off/products/$dir/$dir2/$dir3/$dir4\n";
		
		if (dirmove("/srv/opf/products/other-flavors-codes/$code", "/srv/off/products/$dir/$dir2/$dir3/$dir4")) {
			print STDERR "Successfully moved product data for $code\n";
		}
		else {
			die "Failed to move product data: $!\n";
		}
		
		# Move images if they exist
		if (-e "/srv/opf/html/images/products/other-flavors-codes/$code") {
			print STDERR "Moving images for $code\n";
			ensure_dir_created_or_die("/srv/off/html/images/products/$dir/$dir2/$dir3");
			
			if (dirmove("/srv/opf/html/images/products/other-flavors-codes/$code", "/srv/off/html/images/products/$dir/$dir2/$dir3/$dir4")) {
				print STDERR "Successfully moved images for $code\n";
			}
			else {
				die "Failed to move images: $!\n";
			}
		}
		
		# Update MongoDB - add product to OFF collections
		my $product_ref = retrieve_product($code, "include_deleted");
		if (defined $product_ref) {
			if ($product_ref->{obsolete}) {
				$off_obsolete_products_collection->replace_one({_id => $code}, $product_ref, {upsert => 1});
			}
			else {
				$off_products_collection->replace_one({_id => $code}, $product_ref, {upsert => 1});
			}
			print STDERR "Updated MongoDB for product $code\n";
		}
		
		$num_moved++;
	};
	
	if ($@) {
		print STDERR "ERROR: Failed to move product $code: $@\n";
		$num_errors++;
	}
	
	return;
}

print STDERR "dirs existing in off: " . scalar(@dirs_existing_in_off) . "\n";
print STDERR "dirs not existing in off: " . scalar(@dirs_not_existing_in_off) . "\n";

if ($move) {
	print "\nMigration complete:\n";
	print "  Products moved: $num_moved\n";
	print "  Products skipped: $num_skipped\n";
	print "  Errors: $num_errors\n";
}
else {
	print "\nDry run complete. Use --move to actually move products.\n";
}

exit(0);

