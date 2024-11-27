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

use CGI::Carp qw(fatalsToBrowser);

use ProductOpener::Config qw/:all/;
use ProductOpener::Products qw/retrieve_product store_product/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Data qw/get_products_collection/;

# This script is run to remove products with a data quality issue, 
# few information & no image at all (excluding imports)

my $cursor = get_products_collection()->query({
                data_quality_errors_tags => { '$ne' => undef }
                , data_quality_errors_tags => { '$ne' => "" }
                , data_quality_errors_tags => { '$ne' => [] }
                , states_tags => 'en:photos-to-be-uploaded'
        })->fields({code => 1});
$cursor->immortal(1);
my $removed = 0;
my $product_nb = 0;

my $time = time();
print "time: " . $time . "; time - + (60 * 60 * 24 * 30): " . ($time - + (60 * 60 * 24 * 30)) ."\n";

while (my $product_ref = $cursor->next) {

	printf ("%5s - ", $product_nb);

	my $code = $product_ref->{code};

	$product_ref = retrieve_product($code);

	my $owner = defined($product_ref->{owner}) ? $product_ref->{owner} : '';
	my $creator = defined($product_ref->{creator}) ? $product_ref->{creator} : '';
	my $last_modified_t = defined($product_ref->{last_modified_t}) ? $product_ref->{last_modified_t} : 0;
	my $last_image_t = defined($product_ref->{last_image_t}) ? $product_ref->{last_image_t} : 0;
	my $first_quality_error = defined($product_ref->{data_quality_errors_tags}[0]) ? $product_ref->{data_quality_errors_tags[0]} : "-";
	my $time_ok = defined(time() - $last_modified_t + (60 * 60 * 24 * 30)) ? (time() - $last_modified_t + (60 * 60 * 24 * 30)) : 0;
	my $completeness = defined($product_ref->{completeness}) ? $product_ref->{completeness} : "";


	if ((defined $product_ref) and ($code ne '')) {
	
		if (
			($owner eq '' or  $owner eq null)
			and ($creator ne 'usda-ndb-import')
			and ($creator !~ /^org-.*/)
			and ($product_ref->{completeness} < 0.4)
			and ($time > $last_modified_t + (60 * 60 * 24 * 30))
			) {

			#$product_ref->{deleted} = 'on';
			#add_tag($product_ref, "misc", 'en:bad-product-to-be-deleted'); # Test before deleting

			my $comment = "[remove_nearly_empty_products.pl] removal of product with a data quality issue, " .
							"few information & no image at all";

			# Save the product
			#store_product("remove-bad-products-wo-photos-bot", $product_ref, $comment);

			print "Removed ";

			$removed++;
		}
		else {
			print "NOT RMVD - ";
			print ($owner eq '' or  $owner eq null) ? "owner is empty - " : "owner is not empty - ";
		}

		# print debugging info
		printf ("%18s", $code);
		printf (", creator: %15s", substr($creator, 0, 15));
		printf (", cmpltness: %3s", $completeness);
		printf (", owner: %5s", $owner);
		printf (", last_img: %10s", $last_image_t);
		printf (", last_modified: %10s", $last_modified_t);
		#print ", time ok?: $time_ok";
		print ", time ok?: ";
		print (($time > $last_modified_t + (60 * 60 * 24 * 30)) ? "" : "-"); print $time_ok;
		print ", dq issues: " . substr($first_quality_error, 0, 12);
		print "\n";

	}
	else {
		print "product $code : file not found\n";
	}

$product_nb++;

}

print STDERR "removed $removed products\n";

exit(0);
