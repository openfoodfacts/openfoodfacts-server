#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2018 Association Open Food Facts
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

use Modern::Perl '2012';
use utf8;

my $reverted_user_id = "equadis";

my $usage = <<TXT
revert_changes_from_user.pl

This script will revert products to the most recent version before a given user changed the product.
Products that did not exist before will be deleted.
All changes done after the first edit of the user will also be deleted, even if done by other users.

Usage:

update_all_products.pl --pretend

The key is used to keep track of which products have been updated. If there are many products and field to updates,
it is likely that the MongoDB cursor of products to be updated will expire, and the script will have to be re-run.

--pretend	do not actually update products
TXT
  ;

use CGI::Carp qw(fatalsToBrowser);

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
use JSON;
use File::Copy;

use Getopt::Long;

my @fields_to_update = ();
my $key;
my $index = '';
my $pretend = '';
my $process_ingredients = '';
my $compute_nutrition_score = '';
my $compute_nova = '';

GetOptions(
	"key=s" => \$key,    # string
	"pretend" => \$pretend,
) or die("Error in command line arguments:\n$\nusage");

# Get a list of all products to be reverted

my $query_ref = {};

$query_ref->{editors_tags} = $reverted_user_id;

print "Update key: $key\n\n";

my $products_collection = get_products_collection();

my $cursor = $products_collection->query($query_ref)->fields({code => 1});
$cursor->immortal(1);
my $count = $products_collection->count_documents($query_ref);

my $n = 0;
my $reverted = 0;
my $deleted = 0;

print STDERR "$count products to revert\n";

sleep(5);

if (!-e "$data_root/reverted_products") {
	mkdir("$data_root/reverted_products", oct(755)) or die("Could not create $data_root/reverted_products : $!\n");
}

while (my $product_ref = $cursor->next) {

	my $code = $product_ref->{code};
	my $path = product_path($product_ref);

	#next if $code ne "3073781181432";

	print STDERR "reverting product $code\n";

	if (!-e "$data_root/products/$path") {
		print STDERR "$data_root/products/$path does not exist, skipping\n";
		next;
	}

	my $changes_ref = retrieve("$data_root/products/$path/changes.sto");
	if (not defined $changes_ref) {
		$changes_ref = [];
	}

	my $previous_rev = 0;
	my $after_first_change = 0;
	my $revs = 0;

	my $new_changes_ref = [];

	my %deleted_revs = ();

	foreach my $change_ref (@$changes_ref) {
		$revs++;
		my $rev = $change_ref->{rev};
		if (not defined $rev) {
			$rev = $revs;    # was not set before June 2012
			$change_ref->{rev} = $rev;
		}

		if ((defined $change_ref->{userid}) and ($change_ref->{userid} eq $reverted_user_id)) {
			$after_first_change = 1;
		}
		elsif (not $after_first_change) {
			$previous_rev = $change_ref->{rev};
			push @$new_changes_ref, $change_ref;
		}

		if ($after_first_change) {
			# some products seem to have the same rev multiple times in the changes history
			if (not exists $deleted_revs{$rev}) {
				my $target = "$path/$rev.sto";
				$target =~ s/\//_/g;
				my $cmd = "mv $data_root/products/$path/$rev.sto $data_root/reverted_products/$target";
				print STDERR "$code - $cmd\n";
				if (not $pretend) {
					move("$data_root/products/$path/$rev.sto", "$data_root/reverted_products/$target")
					  or die "Could not execute $cmd : $!\n";
				}
				$deleted_revs{$rev} = 1;
			}
		}
	}

	if ($after_first_change) {
		my $target = "$path/product.sto";
		$target =~ s/\//_/g;
		my $cmd = "mv $data_root/products/$path/product.sto $data_root/reverted_products/$target";
		print STDERR "$code - $cmd\n";
		# move does not work for symlinks on different file systems
		#move("$data_root/products/$path/product.sto", "$data_root/reverted_products/$target") or die "Could not execute $cmd : $!\n";
		if (not $pretend) {
			(system($cmd) == 0) or die "Could not execute $cmd : $!\n";
		}

		$target = "$path/changes.sto" . "." . time();
		$target =~ s/\//_/g;
		$cmd = "mv $data_root/products/$path/changes.sto $target";
		print STDERR "$code - $cmd\n";
		if (not $pretend) {
			move("$data_root/products/$path/changes.sto", "$data_root/reverted_products/$target")
			  or die "Could not execute $cmd : $!\n";
		}

		if ($previous_rev > 0) {
			$cmd = "ln -s $previous_rev.sto $data_root/products/$path/product.sto";
			print STDERR "$code - $cmd\n";
			if (not $pretend) {
				symlink("$previous_rev.sto", "$data_root/products/$path/product.sto")
				  or die "Could not execute $cmd : $!\n";
			}

			print STDERR "updating $data_root/products/$path/changes.sto\n";
			if (not $pretend) {
				store("$data_root/products/$path/changes.sto", $new_changes_ref);
			}
		}

		$n++;
	}

	$product_ref = retrieve_product($code);

	if ((defined $product_ref) and ($code ne '')) {

		if (not $pretend) {

			# Make sure product code is saved as string and not a number
			# see bug #1077 - https://github.com/openfoodfacts/openfoodfacts-server/issues/1077
			# make sure that code is saved as a string, otherwise mongodb saves it as number, and leading 0s are removed
			$product_ref->{code} = $product_ref->{code} . '';
			$products_collection->replace_one({"id" => $product_ref->{_id}}, $product_ref, {upsert => 1});
		}

		$reverted++;

	}
	elsif ($code ne '') {
		print STDERR "$code - delete from mongodb\n";
		if (not $pretend) {
			$products_collection->delete_one({code => $code});
		}
		$deleted++;
	}

	$n > 1000 and last;

}

print "$n products updated (pretend: $pretend)\n";
print "$reverted products reverted (pretend: $pretend)\n";
print "$deleted products deleted (pretend: $pretend)\n";

exit(0);

