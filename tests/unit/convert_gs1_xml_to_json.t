#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use JSON;

use Test::More;
use Test::Number::Delta relative => 1.001;
use Log::Any::Adapter 'TAP';

use ProductOpener::GS1 qw/:all/;
use ProductOpener::Test qw/:all/;

use JSON "decode_json";

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

my $input_dir = "$test_dir/inputs/$test_id";

opendir(my $dh, $input_dir) or die("Could not open the $input_dir directory: $!\n");

foreach my $file (sort(readdir($dh))) {

	next if $file !~ /\.xml$/;
	my $file = $`;    # remove xml extension
	my $json_file = "$input_dir/$file.json";

	convert_gs1_xml_file_to_json("$input_dir/$file.xml", $json_file);

	if (open(my $json_fh, "<:encoding(UTF-8)", $json_file)) {
		local $/;    #Enable 'slurp' mode
		my $json = JSON->new->allow_nonref->canonical;
		my $json_ref = $json->decode(<$json_fh>);

        # First we compare the GS1 JSON to our expected results
        # the exact format of the JSON varies depending on whether it was generated with the Perl GS1.Pm module
        # or with the old nodejs convert_gs1_xml_to_json.js script.
		compare_to_expected_results($json_ref, "$expected_result_dir/$file.json",
			$update_expected_results, {desc => "convert GS1 xml to json: $file"});

		my $messages_ref = [];
		my $products_ref = [];
		read_gs1_json_file("$expected_result_dir/$file.json", $products_ref, $messages_ref);

        # Then we process the GS1 JSON to extract product data in OFF expected format
        # even if the JSON files were different, we should get exactly the same OFF products
        # as the GS1.pm JSON to OFF conversion should handle the syntax variations of the JSON files
		compare_to_expected_results(
			$products_ref, "$expected_result_dir/$file.products.json",
			$update_expected_results, {desc => "convert GS1 json to OFF: $file"}
		);

		unlink($json_file);
	}
	else {
		fail("Could not read $json_file");
	}
}

done_testing();
