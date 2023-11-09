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

use Modern::Perl '2012';
use utf8;

my $usage = <<TXT
revert_changes_from_user.pl

This script will revert products
to the most recent version before a given user changed the product.
Products that did not exist before will be deleted.
All changes done after the first edit of the user will also be deleted,
even if done by other users.

Usage:

revert_changes_from_user.pl --userid user_id --pretend

it is likely that the MongoDB cursor of products to be updated will expire, 
and the script will have to be re-run.

--pretend	do not actually update products
TXT
	;

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

my $pretend = '';
my $reverted_user_id = '';

GetOptions(
	"userid=s" => \$reverted_user_id,    # string
	"pretend" => \$pretend,
) or die("Error in command line arguments:\n\n$usage");

(length $reverted_user_id) or die("Please provide a userid:\n\n$usage");

# Get a list of all products to be reverted

my $query_ref = {};

$query_ref->{editors_tags} = $reverted_user_id;

my $products_collection = get_products_collection();

my $cursor = $products_collection->query($query_ref)->fields({code => 1});
$cursor->immortal(1);
my $count = $products_collection->count_documents($query_ref);

my $n = 0;    # how many product we impact
my $reverted = 0;    # how many product were reverted but still exists
my $deleted = 0;    # how many product were removed (added by target user)
my %lost_revs = ();    # how many revisions from other users we loose

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

	# product revision before any target user modifications
	my $previous_rev = 0;
	# track wether we are after the first change made by targeted user
	# to know if there are changes from other users
	my $after_first_change = 0;
	my $revs = 0;
	# the changes we want to keep
	my $new_changes_ref = [];

	# list of deleted revisions
	my %deleted_revs = ();

	# search for revisions to remove
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
		elsif ($after_first_change && (defined $change_ref->{userid})) {
			# track that we are loosing another user revision
			if (not(defined $lost_revs{$code})) {
				$lost_revs{$code} = 0;
			}
			$lost_revs{$code} += 1;
		}
		elsif (not $after_first_change) {
			# track revision before target user modifications
			$previous_rev = $change_ref->{rev};
			push @$new_changes_ref, $change_ref;
		}

		# We want to remove all changes done after targeted user first changed the product
		if ($after_first_change) {
			# some products seem to have the same rev multiple times in the changes history
			# avoid putting them twice
			if (not exists $deleted_revs{$rev}) {
				my $target = "$path/$rev.sto";
				$target =~ s/\//_/g;    # substitute "/" by _ to have a filename
				my $cmd = "mv $data_root/products/$path/$rev.sto $data_root/reverted_products/$target";
				print STDERR "$code - $cmd\n";
				if (not $pretend) {
					# move revision to reverted folder to keep track
					move("$data_root/products/$path/$rev.sto", "$data_root/reverted_products/$target")
						or die "Could not execute $cmd : $!\n";
				}
				# mark revision as removed
				$deleted_revs{$rev} = 1;
			}
		}
	}

	# We have moved all revisions we don't want and have a list in %deleted_revs
	# No update the product
	if ($after_first_change) {
		my $target = "$path/product.sto";
		$target =~ s/\//_/g;
		# keep a copy of current product
		my $cmd = "mv $data_root/products/$path/product.sto $data_root/reverted_products/$target";
		print STDERR "$code - $cmd\n";
		# move does not work for symlinks on different file systems
		#move("$data_root/products/$path/product.sto", "$data_root/reverted_products/$target") or die "Could not execute $cmd : $!\n";
		if (not $pretend) {
			(system($cmd) == 0) or die "Could not execute $cmd : $!\n";
		}
		# and a copy of changes.sto
		$target = "$path/changes.sto" . "." . time();
		$target =~ s/\//_/g;
		$cmd = "mv $data_root/products/$path/changes.sto $target";
		print STDERR "$code - $cmd\n";
		if (not $pretend) {
			move("$data_root/products/$path/changes.sto", "$data_root/reverted_products/$target")
				or die "Could not execute $cmd : $!\n";
		}
		# we had edits prior target user edits, rewind product to those changes
		if ($previous_rev > 0) {
			# restore revision prior to target user changes
			$cmd = "ln -s $previous_rev.sto $data_root/products/$path/product.sto";
			print STDERR "$code - $cmd\n";
			if (not $pretend) {
				symlink("$previous_rev.sto", "$data_root/products/$path/product.sto")
					or die "Could not execute $cmd : $!\n";
			}
			# restore changes.sto
			print STDERR "updating $data_root/products/$path/changes.sto\n";
			if (not $pretend) {
				store("$data_root/products/$path/changes.sto", $new_changes_ref);
			}
		}

		$n++;
	}

	# fetch product on disk
	$product_ref = retrieve_product($code);

	if ($pretend && $after_first_change && !(scalar @$new_changes_ref)) {
		# simulate product not present if we removed all revs (no new_changes_ref)
		$product_ref = undef;
	}

	if ((defined $product_ref) and ($code ne '')) {

		if (not $pretend) {
			# update the index
			# Make sure product code is saved as string and not a number
			# see bug #1077 - https://github.com/openfoodfacts/openfoodfacts-server/issues/1077
			# make sure that code is saved as a string, otherwise mongodb saves it as number, and leading 0s are removed
			$product_ref->{code} = $product_ref->{code} . '';
			$products_collection->replace_one({"id" => $product_ref->{_id}}, $product_ref, {upsert => 1});
		}

		$reverted++;

	}
	elsif ($code ne '') {
		# product was deleted by previous operations
		# remove it from mongodb
		print STDERR "$code - delete from mongodb\n";
		if (not $pretend) {
			$products_collection->delete_one({code => $code});
		}
		$deleted++;
	}

	$n > 1000 and last;

}

my $would = $pretend ? " would be" : "";
print "$n products$would updated\n";
print "$reverted products$would reverted\n";
print "$deleted products$would deleted\n";
if (scalar %lost_revs) {
	print "revisions$would lost: \n";
	while (my ($lost_code, $lost_num) = each(%lost_revs)) {
		print "- $lost_code: $lost_num\n";
	}
}

exit(0);

