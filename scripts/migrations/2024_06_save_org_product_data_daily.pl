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
use ProductOpener::Data qw/:all/;
use ProductOpener::Paths qw/%BASE_DIRS ensure_dir_created/;
use ProductOpener::Users qw/$Owner_id/;

# This script is run daily to gather organisation data 
# such as number of products, number of products with errors etc,

ensure_dir_created($BASE_DIRS{ORGS});

my $products_collection = get_products_collection();
my $orgs_collection = get_orgs_collection();

sub update_org_data {
    my $org_id = shift;

    my $org_data = $products_collection->aggregate([
        { '$match' => { 'owner' => $org_id } },
        { '$group' => {
            '_id' => '$owner',
            'number_of_products' => { '$sum' => 1 },
            'number_of_products_with_errors' => { 
                '$sum' => { '$cond' => [{ '$gt' => ['$errors', 0] }, 1, 0] }
            },
        }}
    ])->next;

    my $data = {
        'products' => {
            'number_of_products' => $org_data->{number_of_products} // 0,
            'number_of_products_with_errors' => $org_data->{number_of_products_with_errors} // 0,
        },
    };

    $orgs_collection->update_one(
        { 'org-id' => $org_id },
        { '$set' => { 'data' => $data } },
        { 'upsert' => 1 }
    );

    my $backup_file = "$BASE_DIRS{ORGS}/$org_id.sto";
    open my $fh, '>', $backup_file or die "Could not open file '$backup_file' $!";
    print $fh encode_json($data);
    close $fh;
}

sub gather_org_data {
    my $org_ids = $products_collection->distinct("owner");
	$products_collection->delete_many({"owner" => $Owner_id});
 
    foreach my $org_id (@$org_ids) {
        update_org_data($org_id);
    }
}

gather_org_data();

print "Organization data gathering completed.\n";