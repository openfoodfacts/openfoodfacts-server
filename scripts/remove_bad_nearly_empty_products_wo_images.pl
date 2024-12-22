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

use ProductOpener::PerlStandards;

my $usage = <<TXT
remove_bad_nearly_empty_products_wo_images.pl is a script to remove products 
with a data quality issue, few information & no image at all (excluding imports)

Usage:

remove_bad_nearly_empty_products_wo_images.pl [--test|--misc|--remove] [--ip ip-address]

Without arguments, the script will not work.
1. Start with --test to display the products that would be removed.
2. Then use --misc to add a tag to the products that would be removed.
3. Check the products with the misc tag: https://world.openfoodfacts.org/misc/en:bad-product-to-be-deleted
4. Check this list with the community, to be sure there is no side effect.
5. Use --remove to actually remove the products.

--ip is used to specify the IP address of the contributor.

TXT
	;

use CGI::Carp qw(fatalsToBrowser);

use ProductOpener::Config qw/:all/;
use ProductOpener::Products qw/retrieve_product store_product/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Data qw/get_products_collection/;

use Getopt::Long;

my ($test, $misc, $remove, $ip);

GetOptions(
	"help|h|?" => sub {print $usage; exit(0);},
	"remove" => \$remove,
	"test" => \$test,
	"misc" => \$misc,
	"ip=s" => \$ip,
);

if (!($test or $misc or $remove)) {
	if (($test and $misc) or ($test and $remove) or ($misc and $remove)) {
		die("You need to use either --test, --misc or --remove:\n\n$usage");
	}
	die("You need to use either --test, --misc or --remove:\n\n$usage");
}

# IP verification from https://stackoverflow.com/a/36760050
if ($ip ne "" and $ip !~ /^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}$/) {
	die("ip is not valid:\n\n$usage");
}

my $socket_timeout_ms = 2 * 60000;    # 2 mins, instead of 30s default, to not die as easily if mongodb is busy.
my $cursor = get_products_collection({timeout => $socket_timeout_ms})->query(
	{
		states_tags => 'en:photos-to-be-uploaded',
		data_quality_errors_tags => {'$exists' => 1, '$ne' => []},
		creator => {'$nin' => ['', 'usda-ndb-import', qr/^org-.*/]}
	}
)->fields({code => 1});
$cursor->immortal(1);

my $removed = 0;
my $product_nb = 0;

my $time = time();    # EPOCH time, eg. 1616425200
my $excluded_pr_since = (60 * 60 * 24 * 30);    # Exclude product that have entered in the last 30 days
print "time: " . $time . "; time - $excluded_pr_since: " . ($time - $excluded_pr_since) . "\n";

while (my $product_ref = $cursor->next) {

	printf("%5s - ", $product_nb);

	my $code = $product_ref->{code};

	$product_ref = retrieve_product($code);

	my $owner = defined($product_ref->{owner}) ? $product_ref->{owner} : '';
	my $creator = defined($product_ref->{creator}) ? $product_ref->{creator} : '';
	my $created_t = defined($product_ref->{created_t}) ? $product_ref->{created_t} : 0;
	my $last_modified_t = defined($product_ref->{last_modified_t}) ? $product_ref->{last_modified_t} : 0;
	my $last_image_t = defined($product_ref->{last_image_t}) ? $product_ref->{last_image_t} : "";
	my $first_quality_error
		= defined($product_ref->{data_quality_errors_tags}[0]) ? $product_ref->{data_quality_errors_tags}[0] : "-";
	my $time_ok
		= defined(($time - $excluded_pr_since) - $last_modified_t)
		? ($time - $excluded_pr_since) - $last_modified_t
		: 0;
	my $t_ok = defined(($time - $excluded_pr_since) - $created_t) ? ($time - $excluded_pr_since) - $created_t : 0;
	my $completeness = defined($product_ref->{completeness}) ? $product_ref->{completeness} : "99";
	my $err = "";

	if ((defined $product_ref) and ($code ne '')) {

		# Check few conditions: exclude products from owners, imports; completeness needs to be > 0.4
		$err = ($owner eq '') ? "" : "o";    # exclude products imported from the Pro platform
		$err .= ($creator ne 'usda-ndb-import') ? "" : "u";    # exclude USDA imports
		$err .= ($creator !~ /^org-.*/) ? "" : "p";    # exclude orgs like "org-database-usda"
		$err .= ($creator ne '') ? "" : "v";    #exclude products with no creator (bugs?)
		$err .= ($completeness < 0.4) ? "" : "c";    # exclude products which have a certain level of completeness
		$err .= ($last_image_t eq "") ? "" : "i";    # exclude products which have an image
		$err .= ($t_ok > 0) ? "" : "t";    #
		$err .= ($first_quality_error ne '-') ? "" : "q";    #

		if ($err eq "") {

			# Test before deleting the products; comment if you don't want it
			if ($misc) {
				add_tag($product_ref, "misc", 'en:bad-product-wo-image-to-be-deleted');    # Test before deleting
			}

			# Remove the product if --remove argument is set
			if ($remove) {
				# Modify `deleted` field to remove the product
				$product_ref->{deleted} = 'on';
				my $comment = "[remove_bad_nearly_empty_products_wo_images.pl] removal of product with "
					. "a data quality issue, few information & no image at all";
				store_product("remove-bad-products-wo-photos-bot", $product_ref, $comment);
				print "Removed ";
				sleep(1);    # Sleep for 1 second to avoid overloading the server
			}

			if ($test) {
				print "TB rmvd ";    # Meaning "to be removed"
			}

			$removed++;
		}
		else {
			print "NOT RMD ";    # Meaning "not removed"
		}

		# print and format debugging info, to allow quick analyse/debugging
		printf("%18s", $code);
		printf(", crtor: %15s", substr($creator, 0, 15));
		printf(", cmpltness: %3s", substr($completeness, 0, 3));
		printf(", owner: %5s", $owner);
		printf(", crted: %10s", $created_t);
		printf(", last_img: %10s", $last_image_t);
		printf(", last_modified: %10s", $last_modified_t);
		print ", t ok?: " . (($time - $excluded_pr_since > $created_t) ? "" : "-");
		printf("%-10s", $t_ok);
		print ", dq issues: " . substr($first_quality_error, 0, 12);
		print ", err: $err";
		print "\n";

	}
	else {
		print "product $code : file not found\n";
	}

	$product_nb++;

}

print "removed $removed products\n";

exit(0);
