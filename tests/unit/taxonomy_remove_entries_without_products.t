#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use Data::Dumper;
$Data::Dumper::Terse = 1;
$Data::Dumper::Sortkeys = 1;
use Log::Any::Adapter 'TAP';

use File::Temp;

use ProductOpener::Test qw/compare_file_to_expected_results init_expected_results/;

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

# The script filters a taxonomy source file by removing the entries that have no product,
# using the products of the Open Food Facts export.
# We run it as a command line program on test fixtures, and compare the filtered taxonomy
# and the report it produces to the expected results.

my $input_dir = "$test_dir/inputs/$test_id";
$input_dir =~ s!//!/!g;
my $tmp_dir = File::Temp->newdir();

my $script = "scripts/taxonomies/remove_entries_without_products.pl";

if (!-e $script) {
	fail("script $script not found");
	note("run the tests from the root of the repository");
	done_testing();
	exit(0);
}

sub read_file ($path) {
	my $content = "";
	if (open(my $IN, "<:encoding(UTF-8)", $path)) {
		$content = join("", (<$IN>));
		close($IN);
	}
	return $content;
}

# Run the script on the test fixtures, and return the filtered taxonomy and the report.
sub run_script ($options_ref) {

	my $filtered_file = $tmp_dir->dirname . "/categories.filtered." . ($options_ref->{test_case_id} // "") . ".txt";
	my $report_file = $tmp_dir->dirname . "/report." . ($options_ref->{test_case_id} // "") . ".txt";

	my @args = (
		"perl", "-Ilib", $script, "--taxonomy-file",
		"$input_dir/categories.txt", "--jsonl-file", "$input_dir/products.jsonl", "--output-file",
		$filtered_file, "--report-file", $report_file,
	);
	# --quiet hides the list of the kept and removed entries, which we check in one test case
	push @args, "--quiet" if !$options_ref->{list_entries};
	foreach my $option (sort keys %$options_ref) {
		next if ($option eq "test_case_id" or $option eq "list_entries");
		my $value = $options_ref->{$option};
		if ($option eq "flag") {
			push @args, "--$value";
		}
		else {
			push @args, "--" . ($option =~ s/_/-/gr), $value;
		}
	}

	my $return_value = system(join(" ", @args));
	is($return_value, 0, "script exited successfully");

	return (read_file($filtered_file), read_file($report_file));
}

my @test_cases = (
	# Only the entries that have at least one product are kept.
	# Comments and section headers are always kept, and the blocks whose entry name cannot be
	# canonicalized (the synonyms: blocks at the top of the file) are kept by default.
	{test_case_id => "default", options => {}},
	# --drop-unresolved also removes the blocks whose entry name cannot be canonicalized
	{test_case_id => "drop-unresolved", options => {flag => "drop-unresolved"}},
	# --min-products=10 removes the entries that have between 1 and 9 products
	{test_case_id => "min-products", options => {min_products => 10}},
	# --keep always keeps the listed entries, even if they have no product
	{test_case_id => "keep", options => {keep => "en:cigarettes,en:kitchenware"}},
	# without --quiet, the report also lists the kept and removed entries, and the tagids
	# of the export that are not in the taxonomy
	{test_case_id => "list-entries", options => {list_entries => 1}},
);

foreach my $test_case_ref (@test_cases) {

	my $test_case_id = $test_case_ref->{test_case_id};

	subtest $test_case_id => sub {

		my $options_ref = {%{$test_case_ref->{options}}};
		$options_ref->{test_case_id} = $test_case_id;

		my ($filtered_taxonomy, $report) = run_script($options_ref);

		compare_file_to_expected_results(
			$filtered_taxonomy, "$expected_result_dir/$test_case_id.categories.txt",
			$update_expected_results, {desc => "$test_case_id filtered taxonomy"}
		);

		compare_file_to_expected_results($report, "$expected_result_dir/$test_case_id.report.txt",
			$update_expected_results, {desc => "$test_case_id report"});
	};
}

done_testing();
