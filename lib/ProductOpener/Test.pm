# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2020 Association Open Food Facts
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
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

=head1 NAME

ProductOpener::Test - utility functions used by unit and integration tests

=head1 DESCRIPTION

=cut

package ProductOpener::Test;

use utf8;
use Modern::Perl '2017';
use Exporter    qw< import >;

BEGIN
{
	use vars       qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(


		);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;

use ProductOpener::Config qw/:all/;
use ProductOpener::Data qw/execute_query get_products_collection/;

use File::Path qw/remove_tree/;

use Log::Any qw($log);


=head2 remove_all_products ()

For integration tests, we need to start from an empty database, so that the results of the tests
are not affected by previously existing content.

This function should only be called by tests, and never on production environments.

=cut

sub remove_all_products () {
    # check we are not on a prod database, by checking there are not more than 100 products
    my $products_count = execute_query(sub {
		return get_products_collection()->count_documents({});
	});
    unless ((0 <= $products_count) && ($products_count < 1000)) {
        die("Refusing to run destructive test on a DB of more than 100 items");
    }
    # clean database
    execute_query(sub {
		return get_products_collection()->delete_many({});
	});
    # clean files
    remove_tree("$data_root/products", {keep_root => 1, error => \my $err});
    if (@$err) {
        die("not able to remove some products directories: ". join(":", @$err));
    }
}

1;
