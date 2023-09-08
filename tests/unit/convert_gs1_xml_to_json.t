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
    my $file = $`;  # remove xml extension
    my $json_file = "$input_dir/$file.json";

    convert_gs1_xml_file_to_json("$input_dir/$file.xml", $json_file);

    if (open(my $json_fh, "<:encoding(UTF-8)", $json_file)) {
        local $/;    #Enable 'slurp' mode
        my $json = JSON->new->allow_nonref->canonical;
			my $json_ref = $json->decode(<$json_fh>);
            #compare_to_expected_results($json_ref, "$expected_result_dir/$file.json", $update_expected_results);

            my $messages_ref = [];
            my $products_ref = [];
            read_gs1_json_file("$expected_result_dir/$file.json", $products_ref, $messages_ref);

            compare_to_expected_results($products_ref, "$expected_result_dir/$file.products.json", $update_expected_results);

            unlink($json_file);
    }
    else {
        fail("Could not read $json_file");
    }
}




done_testing();
