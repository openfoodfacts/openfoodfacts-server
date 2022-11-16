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

use ProductOpener::PerlStandards;
use Exporter qw< import >;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&capture_ouputs
		&compare_arr
		&compare_to_expected_results
		&compare_array_to_expected_results
		&compare_csv_file_to_expected_results
		&create_sto_from_json
		&init_expected_results
		&normalize_org_for_test_comparison
		&normalize_product_for_test_comparison
		&normalize_products_for_test_comparison
		&normalize_user_for_test_comparison
		&remove_all_products
		&remove_all_users
		&remove_all_orgs
		&check_not_production
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use IO::Capture::Stdout::Extended;
use IO::Capture::Stderr::Extended;
use ProductOpener::Config qw/:all/;
use ProductOpener::Data qw/execute_query get_products_collection/;
use ProductOpener::Store "store";

use Carp qw/confess/;
use Data::DeepAccess qw(deep_exists deep_get deep_set);
use Getopt::Long;
use Test::More;
use JSON "decode_json";
use File::Basename "fileparse";
use File::Path qw/make_path remove_tree/;
use Path::Tiny qw/path/;

use Log::Any qw($log);

=head2 init_expected_results($filepath)
Handles test options around expected_results initialization

For many tests, we compare results from the API, with expected results.
It enables quick updates on changes, while still getting control.

There are two modes: one to update expected results, and one to test against them.

=head3 Parameters

=head4 String $filepath
The path of the file containing the tetst.
Generally should be <pre>__FILE__</pre> within the test.


=head3 return list

A list of $test_id, $test_dir, $expected_result_dir, $update_expected_results

=cut

sub init_expected_results ($filepath) {

	my ($test_id, $test_dir) = fileparse($filepath, qr/\.[^.]+$/);
	my $expected_result_dir = "$test_dir/expected_test_results/$test_id";

	my $usage = <<TXT

The expected results of the test $test_id are saved in $expected_result_dir

To verify differences and update the expected test results,
actual test results can be saved by passing --update-expected-results

The directory will be created if it does not already exist.

TXT
		;

	my $update_expected_results;

	GetOptions("update-expected-results" => \$update_expected_results)
		or confess("Error in command line arguments.\n\n" . $usage);

	# ensure boolean
	$update_expected_results = !!$update_expected_results;

	if (($update_expected_results) and (!-e $expected_result_dir)) {
		mkdir($expected_result_dir, 0755) or confess("Could not create $expected_result_dir directory: $!\n");
	}

	return ($test_id, $test_dir, $expected_result_dir, $update_expected_results);
}

=head2 check_not_production ()

Fail unless we have less than 1000 products in database.

This is a simple heuristic to ensure we are not in a production database

=cut

sub check_not_production() {
	my $products_count = execute_query(
		sub {
			return get_products_collection()->count_documents({});
		}
	);
	unless ((0 <= $products_count) && ($products_count < 1000)) {
		confess("Refusing to run destructive test on a DB of more than 1000 items\n");
	}
}

=head2 remove_all_products ()

For integration tests, we need to start from an empty database, so that the results of the tests
are not affected by previously existing content.

This function should only be called by tests, and never on production environments.

=cut

sub remove_all_products () {

	# Important: check we are not on a prod database
	check_not_production();
	# clean database
	execute_query(
		sub {
			return get_products_collection()->delete_many({});
		}
	);
	# clean files
	remove_tree("$data_root/products", {keep_root => 1, error => \my $err});
	if (@$err) {
		confess("not able to remove some products directories: " . join(":", @$err));
	}
}

=head2 remove_all_users ()

For integration tests, we need to start from an empty user base

This function should only be called by tests, and never on production environments.

=cut

sub remove_all_users () {
	# Important: check we are not on a prod database
	check_not_production();
	# clean files
	# clean files
	remove_tree("$data_root/users", {keep_root => 1, error => \my $err});
	if (@$err) {
		confess("not able to remove some users directories: " . join(":", @$err));
	}
}

=head2 remove_all_orgs ()

For integration tests, we need to start from an empty organizations base

This function should only be called by tests, and never on production environments.

=cut

sub remove_all_orgs () {
	# Important: check we are not on a prod database
	check_not_production();
	# clean files
	remove_tree("$data_root/orgs", {keep_root => 1, error => \my $err});
	if (@$err) {
		confess("not able to remove some orgs directories: " . join(":", @$err));
	}
}

=head2 capture_ouputs ($meth)

Capturing out / err with Stdout/Stderr::Extended
while following Capture::Tiny style

This function can help you verify a command did not output errors,
or verify something is present in its input / output

=head3 Example usage

    my ($out, $err, $csv_result) = capture_ouputs (sub {
        return scalar load_csv_or_excel_file($my_excel);
    });

=head3 Arguments

=head4 $meth - pointer to a sub

Method to run while capturing outputs - it should not take any parameter.

=head3 Return value

Returns an array with std output, std error, result of the method as array.

=cut

sub capture_ouputs ($meth) {

	my $out = IO::Capture::Stdout::Extended->new();
	my $err = IO::Capture::Stderr::Extended->new();
	$out->start();
	$err->start();
	# call in array context
	my @result = $meth->();
	$out->stop();
	$err->stop();
	return ($out, $err, @result);
}

# Ensure expected_results_dir exists or reset it if needed
sub ensure_expected_results_dir ($expected_results_dir, $update_expected_results) {

	if ($update_expected_results) {
		# Reset the expected results dir
		if (-e $expected_results_dir) {
			remove_tree("$expected_results_dir", {error => \my $err});
			if (@$err) {
				confess("not able to remove some result directories: " . join(":", @$err));
			}
		}
		make_path($expected_results_dir);
	}
	elsif (!-e $expected_results_dir) {
		confess("Expected results dir not found at $expected_results_dir");
	}
	return 1;
}

=head2 compare_to_expected_results($object_ref, $expected_results_file, $update_expected_results) {

Compare an object (e.g. product data or an API result) to expected results.

The expected result is stored as a JSON file.

This is so that we can easily see diffs with git diffs.

=head3 Arguments

=head4 $object_ref - reference to an object (e.g. $product_ref)

=head4 $expected_results_file - path to the file with stored results

=head4 $update_expected_results - flag to indicate to save test results as expected results

Tests will always pass when this flag is passed,
and the new expected results can be diffed / committed in GitHub.

=cut

sub compare_to_expected_results ($object_ref, $expected_results_file, $update_expected_results) {

	my $json = JSON->new->allow_nonref->canonical;

	if ($update_expected_results) {
		open(my $result, ">:encoding(UTF-8)", $expected_results_file)
			or confess("Could not create $expected_results_file: $!");
		print $result $json->pretty->encode($object_ref);
		close($result);
	}
	else {
		# Compare the result with the expected result

		if (open(my $expected_result, "<:encoding(UTF-8)", $expected_results_file)) {

			local $/;    #Enable 'slurp' mode
			my $expected_object_ref = $json->decode(<$expected_result>);
			is_deeply($object_ref, $expected_object_ref) or diag explain $object_ref;
		}
		else {
			fail("could not load $expected_results_file");
			diag explain $object_ref;
		}
	}

	return 1;
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

Tests will pass when this flag is passed, and the new expected results can be diffed / committed in GitHub.

=cut

sub compare_csv_file_to_expected_results ($csv_file, $expected_results_dir, $update_expected_results) {

	# Read the CSV file

	my $csv = Text::CSV->new({binary => 1, sep_char => "\t"})    # should set binary attribute.
		or die "Cannot use CSV: " . Text::CSV->error_diag();

	open(my $io, '<:encoding(UTF-8)', $csv_file) or confess("Could not open " . $csv_file . ": $!");

	# first line contains headers
	my $columns_ref = $csv->getline($io);
	$csv->column_names(@{$columns_ref});

	# csv --> array
	my @data = ();

	while (my $product_ref = $csv->getline_hr($io)) {
		push @data, $product_ref;
	}
	close($io);
	compare_array_to_expected_results(\@data, $expected_results_dir, $update_expected_results);
	return 1;
}

=head2 compare_array_to_expected_results($array_ref, $expected_results_dir, $update_expected_results)

Compare an array containing product data (e.g. the result of a CSV export) to expected results.

The expected results are stored as individual JSON files for each of the product,
in files named [barcode].json, with a flat key/value pairs structure corresponding to the CSV columns.

This is so that we can easily see diffs with git diffs:
- we know how many products are affected
- we see individual diffs with the field name

=head3 Arguments

=head4 $array_ref - reference to array of elements to compare

=head4 $expected_results_dir - directory containing the individual JSON files

=head4 $update_expected_results - flag to indicate to save test results as expected results

Tests will always pass when this flag is passed,
and the new expected results can be diffed / committed in GitHub.

=cut

sub compare_array_to_expected_results ($array_ref, $expected_results_dir, $update_expected_results) {

	ensure_expected_results_dir($expected_results_dir, $update_expected_results);

	my $json = JSON->new->allow_nonref->canonical;
	my %codes = ();

	foreach my $product_ref (@$array_ref) {

		my $code = $product_ref->{code};
		$codes{$code} = 1;

		# Update the expected results if the --update parameter was set

		if ($update_expected_results) {
			open(my $result, ">:encoding(UTF-8)", "$expected_results_dir/$code.json")
				or confess("Could not create $expected_results_dir/$code.json: $!\n");
			print $result $json->pretty->encode($product_ref);
			close($result);
		}

		# Otherwise compare the result with the expected result

		elsif (open(my $expected_result, "<:encoding(UTF-8)", "$expected_results_dir/$code.json")) {

			local $/;    #Enable 'slurp' mode
			my $expected_product_ref = $json->decode(<$expected_result>);
			is_deeply($product_ref, $expected_product_ref) or diag explain $product_ref;
		}
		else {
			diag explain $product_ref;
			fail("could not load $expected_results_dir/$code.json");
		}
	}

	# Check that we are not missing products

	opendir(my $dh, $expected_results_dir)
		or confess("Could not open the $expected_results_dir directory: $!\n");

	my @missed = ();
	foreach my $file (sort(readdir($dh))) {

		if ($file =~ /(\d+)\.json$/) {
			my $code = $1;
			if (!exists $codes{$code}) {
				push @missed, $code;
			}
		}
	}
	if (@missed) {
		fail("Products " . join(", ", @missed) . " not found in array");
	}
	else {
		pass("All products found in array");
	}

	return 1;
}

=head2 create_sto_from_json(json_path, sto_path)

Create a sto file from a json structure

This might be handy to store data for a test in a readable mode
whereas you need it as a sto for your test.

=head3 Arguments

=head4 json_path

Path of source json file

=head4 sto_path

Path of target sto file

=cut

sub create_sto_from_json ($json_path, $sto_path) {

	my $data = decode_json(path($json_path)->slurp_raw());
	store($sto_path, $data);
	return;
}

# this method is an helper method for normalize_product_for_test_comparison
# $item_ref is a product hash ref, or subpart there of
# $subfields_ref is an array of arrays of keys.
# Each array of key leads to a sub array of $item_ref, but the last which is target element.
# _sub_items will reach every targeted elements, running through all sub-arrays

sub _sub_items ($item_ref, $subfields_ref) {

	if (scalar @$subfields_ref == 0) {
		return $item_ref;
	}
	else {
		# get first level
		my @result = ();
		my @key = split(/\./, shift(@$subfields_ref));
		if (deep_exists($item_ref, @key)) {
			# only support array for now
			my @sub_items = deep_get($item_ref, @key);
			for my $sub_item (@sub_items) {
				# recurse
				push @result, @{_sub_items($sub_item, $subfields_ref)};
			}
		}
		return @result;
	}
}

=head2 normalize_object_for_test_comparison($object_ref, $specification_ref)

Normalize an object to be able to compare them across tests runs.

We remove some fields and sort some lists.

=head3 Arguments

=head4 $object_ref - Hash ref containing information

=head4 $specification_ref - Hash ref of specification of transforms

fields_ignore_content - array of fields which content should be ignored
because they vary from test to test.
Stars means there is a table of elements and we want to run through all (hash not supported yet)

fields_sort - array of fields which content needs to be sorted to have predictable results

=cut

sub normalize_object_for_test_comparison ($object_ref, $specification_ref) {
	if (defined($specification_ref->{fields_ignore_content})) {
		my @fields_ignore_content = @{$specification_ref->{fields_ignore_content}};

		my @key;
		for my $field_ic (@fields_ignore_content) {
			# stars permits to loop subitems
			my @subfield = split(/\.\*\./, $field_ic);
			my $final_field = pop @subfield;
			for my $item (_sub_items($object_ref, \@subfield)) {
				@key = split(/\./, $final_field);
				if (deep_exists($item, @key)) {
					deep_set($item, @key, "--ignore--");
				}
			}
		}
	}
	if (defined($specification_ref->{fields_sort})) {
		my @fields_sort = @{$specification_ref->{fields_sort}};
		my @key;
		for my $field_s (@fields_sort) {
			@key = split(/\./, $field_s);
			if (deep_exists($object_ref, @key)) {
				my @sorted = sort @{deep_get($object_ref, @key)};
				deep_set($object_ref, @key, \@sorted);
			}
		}
	}
	return;
}

=head2 normalize_product_for_test_comparison($product_ref)

Normalize a product to be able to compare them across tests runs.

We remove time dependent fields and sort some lists.

=head3 Arguments

=head4 product_ref - Hash ref containing product information

=cut

sub normalize_product_for_test_comparison ($product_ref) {
	my %specification = (
		fields_ignore_content => [
			qw(
				last_modified_t created_t owner_fields
				entry_dates_tags last_edit_dates_tags
				sources.*.import_t
			)
		],
		fields_sort => ["_keywords"],
	);

	return normalize_object_for_test_comparison($product_ref, \%specification);
}

=head2 normalize_products_for_test_comparison(array_ref)

Like normalize_product_for_test_comparison for a list of products

=head3 Arguments

=head4 array_ref

Array of products

=cut

sub normalize_products_for_test_comparison ($array_ref) {

	for my $product_ref (@$array_ref) {
		normalize_product_for_test_comparison($product_ref);
	}
	return;
}

=head2 normalize_user_for_test_comparison($user_ref)

Normalize a user to be able to compare them across tests runs.

We remove time dependent fields, password (which encryption use salt) and sort some lists.

=head3 Arguments

=head4 user_ref - Hash ref containing user information

=cut

sub normalize_user_for_test_comparison ($user_ref) {
	my %specification = (fields_ignore_content => [qw(registered_t user_sessions encrypted_password ip)],);

	normalize_object_for_test_comparison($user_ref, \%specification);
	return;
}

=head2 normalize_org_for_test_comparison($org_ref)

Normalize a org to be able to compare them across tests runs.

We remove time dependent fields, password (which encryption use salt) and sort some lists.

=head3 Arguments

=head4 org_ref - Hash ref containing org information

=cut

sub normalize_org_for_test_comparison ($org_ref) {
	my %specification = (fields_ignore_content => ["created_t"],);

	normalize_object_for_test_comparison($org_ref, \%specification);
	return;
}

1;
