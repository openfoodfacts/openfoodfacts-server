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

my $cursor = get_products_collection()->query(
	{ data_quality_errors_tags => { '$nin' => [undef, []] }
	 , states_tags => 'en:photos-to-be-uploaded' 
	}
	)->fields({code => 1});
$cursor->immortal(1);
my $removed = 0;

while (my $product_ref = $cursor->next) {

	my $code = $product_ref->{code};

	#print STDERR "updating product $code\n";

	$product_ref = retrieve_product($code);

	no warnings 'uninitialized';

	if ((defined $product_ref) and ($code ne '')) {
	
		if (1
			#and (defined $product_ref->{last_image_t})
			#and ($product_ref->{last_image_t} eq '')
			and ($product_ref->{owner} eq '')
			and ($product_ref->{creator} ne 'usda-ndb-import')
			and ($product_ref->{creator} !~ /^org-.*/)
			and ($product_ref->{completeness} < 0.4)
			and (time() > $product_ref->{last_modified_t} + (60 * 60 * 24 * 30))
			) {

			#$product_ref->{deleted} = 'on';
			add_tag($product_ref, "misc", 'en:bad-product-to-be-deleted'); # Test before deleting

			my $comment = "[remove_nearly_empty_products.pl] removal of product with a data quality issue, " .
							"few information & no image at all";

			# Save the product
			store_product("remove-bad-products-wo-photos-bot", $product_ref, $comment);

			print "Removed product $code, created by $product_ref->{creator}";
			print ", completeness: $product_ref->{completeness}";
			print ", quality issues: $product_ref->{data_quality_errors_tags}...\n";

			$removed++;
		}
	}
	else {
		#print "product $code : file not found\n";
	}

}

print STDERR "removed $removed products\n";

exit(0);
