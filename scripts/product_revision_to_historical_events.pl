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
use Modern::Perl '2017';
use utf8;

use ProductOpener::Config qw/$server_domain %options/;
use ProductOpener::Store qw/store retrieve/;
use ProductOpener::Orgs qw/list_org_ids retrieve_org/;
use ProductOpener::Users qw/retrieve_user/;
use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::CRM qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Data qw/:all/;
use Encode;
use JSON;
use LWP::Simple;
use Data::Dumper;

my $query_ref = {};
$query_ref->{'empty'} = {"\$ne" => 1};
$query_ref->{'obsolete'} = {"\$ne" => 1};

# fields to retrieve
my $fields_ref = {
    code => 1,
};

my $socket_timeout_ms = 6000 ; # 3 * 60 * 60 * 60000;    # 3 hours
my $products_collection = get_products_collection({timeout => $socket_timeout_ms});
my $products_count = $products_collection->count_documents($query_ref);
my $cursor = $products_collection->query($query_ref)->sort({created_t => 1})->fields($fields_ref);
$cursor->immortal(1);

my $total = 0;

while (my $product_ref = $cursor->next and $total < 1) {
    $total++;

    my $product_id = $product_ref->{code};
    my $path = product_path_from_id($product_id);
    if ($total % 1 == 0) {
        print STDERR "$total / $products_count processed\n\n";
    }

    my $product = retrieve_product($product_id);
    my $changes = retrieve("$BASE_DIRS{PRODUCTS}/$path/changes.sto");

    say Dumper $changes;
    # print Dumper $fst_rev;
    
    # JSONL
    foreach my $change (@{$changes}) {
        print encode_json({
            ts => $change->{t},
            barcode => $product_id,
            userid => $change->{userid},
            comment => $change->{comment},
            flavor => $options{product_type},

        }) . "\n";
    }
}