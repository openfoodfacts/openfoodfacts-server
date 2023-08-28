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
use ProductOpener::Products qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Data qw/:all/;

# This script is run daily to remove empty products (without data or pictures)
# in particular products created by the button to add a product without a barcode

my $cursor = get_products_collection()->query({states_tags => "en:empty"})->fields({code => 1, empty => 1});
$cursor->immortal(1);
my $removed = 0;

while (my $product_ref = $cursor->next) {

	my $code = $product_ref->{code};

	#print STDERR "updating product $code\n";

	$product_ref = retrieve_product($code);

	if ((defined $product_ref) and ($code ne '')) {

		if (($product_ref->{empty} == 1) and (time() > $product_ref->{last_modified_t} + 86400)) {
			$product_ref->{deleted} = 'on';
			my $comment = "automatic removal of product without information or images";

			print STDERR "removing product code $code\n";
			$removed++;
		}
	}
	else {
		print "product $code : file not found\n";
	}

}

print STDERR "removed $removed products\n";

exit(0);

