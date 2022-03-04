﻿# This file is part of Product Opener.
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

use Test::More;
use File::Path qw/make_path remove_tree/;

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

=head2 compare_csv_file_to_expected_results($csv_file, $expected_results_dir, $update_expected_results)

Compare a CSV file containing product data (e.g. the result of a CSV export) to expected results.

The expected results are stored as individual JSON files for each of the product,
in files named [barcode].json, with a flat key/value pairs structure corresponding to the CSV columns.

This is so that we can easily see diffs with git diffs:
- we know how many products are affected
- we see individual diffs with the field name

=head3 Arguments

=head4 $csv_file - CSV file to compare

=head4 $expected_results_dir - directory containing the individual JSON files

=head4 $update_expected_results - flag to indicate to save test results as expected results

Tests will pass when this flag is passed, and the new expected results can be diffed / commited in GitHub.

=cut

sub compare_csv_file_to_expected_results($$$) {

    my $csv_file = shift;
    my $expected_results_dir = shift;
    my $update_expected_results = shift;

    # Create the expected results dir
    if ($update_expected_results) {
        if (-e $expected_results_dir) {
            remove_tree("$expected_results_dir", {error => \my $err});
            if (@$err) {
                die("not able to remove some products directories: ". join(":", @$err));
            }
        }
        make_path($expected_results_dir);
    }

    # Read the CSV file

    my $csv = Text::CSV->new ( { binary => 1 , sep_char => "\t" } )  # should set binary attribute.
                or die "Cannot use CSV: ".Text::CSV->error_diag ();

    open (my $io, '<:encoding(UTF-8)', $csv_file) or die("Could not open " . $csv_file . ": $!");

    # first line contains headers
    my $columns_ref = $csv->getline ($io);
    $csv->column_names (@{$columns_ref});

    my $json = JSON->new->allow_nonref->canonical;
    my %codes = ();

    while (my $product_ref = $csv->getline_hr ($io)) {

        my $code = $product_ref->{code};
        $codes{$code} = 1;

        # Update the expected results if the --update parameter was set
        
        if (defined $update_expected_results) {
            open (my $result, ">:encoding(UTF-8)", "$expected_results_dir/$code.json") or die("Could not create $expected_results_dir/$code.json: $!\n");
            print $result $json->pretty->encode($product_ref);
            close ($result);
        }

        # Otherwise compare the result with the expected result
        
        elsif (open (my $expected_result, "<:encoding(UTF-8)", "$expected_results_dir/$code.json")) {

            local $/; #Enable 'slurp' mode
            my $expected_product_ref = $json->decode(<$expected_result>);
            is_deeply ($product_ref, $expected_product_ref) or diag explain $product_ref;
        }
        else {
            diag explain $product_ref;
            fail("could not load $expected_results_dir/$code.json");
        }    
    }

    # Check that we are not missing products

    opendir (my $dh, $expected_results_dir) or die("Could not open the $expected_results_dir directory: $!\n");

    foreach my $file (sort(readdir($dh))) {
        
        if ($file =~ /(\d+)\.json$/) {
            my $code = $1;
            ok(exists $codes{$code}, "product code $code exists in CSV export $csv_file");
        }
    }
}

1;
