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
use ProductOpener::Orgs qw/retrieve_org/;
use Storable qw(store);

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
            'number_of_data_quality_errors' => {
                '$sum' => { '$size' => '$data_quality_errors_tags' }
            },
            'number_of_data_quality_warnings' => {
                '$sum' => { '$size' => '$data_quality_warnings_tags' }
            },
            'number_of_products_without_nutriscore' => { 
                '$sum' => { 
                    '$cond' => [
                        { '$in' => ['en:nutriscore-not-computed', '$misc_tags'] }, 
                        1, 
                        0 
                    ] 
                }
            }
        }}
    ])->next;

    my $number_of_products_with_nutriscore = $org_data->{number_of_products} - ($org_data->{number_of_products_without_nutriscore} // 0);
    my $percentage_of_products_with_nutriscore = $org_data->{number_of_products} > 0 ? ($number_of_products_with_nutriscore / $org_data->{number_of_products}) * 100 : 0;

    my $data = {
        'products' => {
            'number_of_products' => $org_data->{number_of_products} // 0,
            'number_of_data_quality_errors' => $org_data->{number_of_data_quality_errors} // 0,
            'number_of_data_quality_warnings' => $org_data->{number_of_data_quality_warnings} // 0,
            'number_of_products_without_nutriscore' => $org_data->{number_of_products_without_nutriscore} // 0,
            'percentage_of_products_with_nutriscore' => $percentage_of_products_with_nutriscore
        },
    };

    $orgs_collection->update_one(
        { 'org_id' => $org_id },
        { '$set' => { 'data' => $data } },
        { 'upsert' => 1 }
    );

    my $org_file_path = "$BASE_DIRS{ORGS}/$org_id.sto";
    my $org_ref = retrieve_org($org_id);

    $org_ref->{'data'} = $data;

    store($org_ref, $org_file_path);
}

sub gather_org_data {
    my @orgs = $orgs_collection->find()->all();
	my $count = scalar @orgs;
	my $i = 0;

    foreach my $org (@orgs) {
        my $org_id = $org->{'org_id'};
        print "Processing organization $i/$count: $org_id\n";
        update_org_data($org_id);
        $i++;
    }
}

gather_org_data();

print "Organization data gathering completed.\n";