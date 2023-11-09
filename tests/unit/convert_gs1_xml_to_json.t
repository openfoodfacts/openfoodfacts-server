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

my $tmp_dir = File::Temp->newdir();

opendir(my $dh, $input_dir) or die("Could not open the $input_dir directory: $!\n");

foreach my $file (sort(readdir($dh))) {

	next if $file !~ /\.xml$/;
	my $file = $`;    # remove xml extension
	my $json_file = "$tmp_dir/$file.json";

	convert_gs1_xml_file_to_json("$input_dir/$file.xml", $json_file);

	if (open(my $json_fh, "<:encoding(UTF-8)", $json_file)) {
		my $json = JSON->new->allow_nonref->canonical;
		my $json_ref = $json->decode(join("", <$json_fh>));

		# First we compare the GS1 JSON to our expected results
		# the exact format of the JSON varies depending on whether it was generated with the Perl GS1.Pm module
		# or with the old nodejs convert_gs1_xml_to_json.js script.

		# In particular XML2JSON creates a hash for simple text values. Text values of tags are converted to $t properties.
		# e.g. <gtin>03449862093657</gtin>
		#
		# becomes:
		#
		# gtin: {
		#    $t: "03449865355608"
		# },
		#
		# There are also differences with arrays with one element that are moved one level
		# To see some sample differences, see this commit: https://github.com/openfoodfacts/openfoodfacts-server/pull/8976/commits/adb696d4d5ed6098f254f8a6a9537f727aa4311a#diff-e203f2af6fbc612b40c57a0439aa4145468d4c9028b462a084c8b77dd67d27a8

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
	}
	else {
		fail("Could not read $json_file");
	}
}

done_testing();
