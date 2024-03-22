#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test::More;
use Test::Number::Delta relative => 1.001;
use Test::Files;
use File::Spec;
use Log::Any::Adapter 'TAP';

use Log::Any qw($log);

use JSON;

use ProductOpener::Config qw/:all/;
use ProductOpener::GS1 qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Test qw/:all/;

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

# Check that the GS1 nutrient codes are associated with existing OFF nutrient ids.

foreach my $gs1_nutrient (sort keys %{$ProductOpener::GS1::gs1_maps{nutrientTypeCode}}) {

	if (not exists_taxonomy_tag("nutrients", "zz:" . $ProductOpener::GS1::gs1_maps{nutrientTypeCode}{$gs1_nutrient})) {
		$log->warn(
			"mapping for GS1 nutrient does not exist in OFF",
			{gs1_nutrient => $gs1_nutrient, mapping => $ProductOpener::GS1::gs1_maps{nutrientTypeCode}{$gs1_nutrient}}
		) if $log->is_warn();
	}
}

if (!-e $expected_result_dir) {
	mkdir($expected_result_dir, 0755) or die("Could not create $expected_result_dir directory: $!\n");
}

my $json = JSON->new->allow_nonref->canonical;

my $dh;

opendir($dh, $expected_result_dir) or die("Could not open the $expected_result_dir directory: $!\n");

foreach my $file (sort(readdir($dh))) {

	next if $file !~ /\.json$/;

	# skip expected test results
	next if $file =~ /\.off\.json$/;

	my $testid = $`;

	init_csv_fields();

	my $products_ref = [];
	my $messages_ref = [];
	read_gs1_json_file("$expected_result_dir/$file", $products_ref, $messages_ref);

	# Save the result

	if ($update_expected_results) {
		open(my $result, ">:encoding(UTF-8)", "$expected_result_dir/$testid.off.json")
			or die("Could not create $expected_result_dir/$testid.off.json: $!\n");
		print $result $json->pretty->encode($products_ref);
		close($result);
	}

	# Compare the result with the expected result

	if (open(my $expected_result, "<:encoding(UTF-8)", "$expected_result_dir/$testid.off.json")) {

		local $/;    #Enable 'slurp' mode
		my $expected_products_ref = $json->decode(<$expected_result>);
		is_deeply($products_ref, $expected_products_ref) or diag explain $products_ref;
	}
	else {
		fail("could not load $expected_result_dir/$testid.off.json");
		diag explain $products_ref;
	}

	# Write the XML confirmation message

	# Always use the same seed, so that the random instance identifier is always the same
	srand(1);

	# my $expected_gs1_confirmation_file = "$expected_result_dir/CIC_${instance_identifier}.xml";
	my $expected_gs1_confirmation_file = "$expected_result_dir/$testid.off.gs1_confirmation.xml";

	my $test_time = 1650902728;

	my ($confirmation_instance_identifier, $xml) = generate_gs1_confirmation_message($messages_ref->[0], $test_time);

	if ($update_expected_results) {
		open(my $file, ">:encoding(UTF-8)", $expected_gs1_confirmation_file) or die("Could not create $file: $!\n");
		print $file $xml;
		close $file;
	}
	else {
		# Check the xml generated match the content of the saved confirmation file
		file_ok($expected_gs1_confirmation_file, $xml, "confirmation xml for $testid");
	}
}

is(print_unknown_entries_in_gs1_maps(), 0);

done_testing();
