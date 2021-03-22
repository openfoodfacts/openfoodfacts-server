#!/usr/bin/perl -w

use strict;
use warnings;
use utf8;

use Test::More;
use Test::Number::Delta relative => 1.001;
use Log::Any::Adapter 'TAP';

use Log::Any qw($log);

use JSON;
use Getopt::Long;

use ProductOpener::Config qw/:all/;
use ProductOpener::GS1 qw/:all/;
use ProductOpener::Food qw/:all/;

my $testdir = "import_gs1";

my $usage = <<TXT

The input test files and the expected results of the tests are saved in $data_root/t/expected_test_results/$testdir

To verify differences and update the expected test results, actual test results
can be saved to a directory by passing --results [path of results directory]

The directory will be created if it does not already exist.

TXT
;

# Check that the GS1 nutrient codes are associated with existing OFF nutrient ids.

foreach my $gs1_nutrient (sort keys %{$ProductOpener::GS1::gs1_maps{nutrientTypeCode}}) {
		
	if (not exists $Nutriments{$ProductOpener::GS1::gs1_maps{nutrientTypeCode}{$gs1_nutrient}}) {
		$log->warn("mapping for GS1 nutrient does not exist in OFF", 
			{ gs1_nutrient => $gs1_nutrient, mapping => $ProductOpener::GS1::gs1_maps{nutrientTypeCode}{$gs1_nutrient} }) if $log->is_warn();
	}
}


my $resultsdir;

GetOptions ("results=s"   => \$resultsdir)
  or die("Error in command line arguments.\n\n" . $usage);
  
if ((defined $resultsdir) and (! -e $resultsdir)) {
	mkdir($resultsdir, 0755) or die("Could not create $resultsdir directory: $!\n");
}

my $json = JSON->new->allow_nonref->canonical;

my $dh;

opendir ($dh, "$data_root/t/expected_test_results/$testdir") or die("Could not open the $data_root/t/expected_test_results/$testdir directory: $!\n");

foreach my $file (sort(readdir($dh))) {
	
	next if $file !~ /\.json$/;
	
	# skip expected test results
	next if $file =~ /\.off\.json$/;
	
	my $testid = $`;
	
	init_csv_fields();
	
	my $products_ref = [];
	my $product_ref = read_gs1_json_file("$data_root/t/expected_test_results/$testdir/$file", $products_ref);
	
	# Save the result
	
	if (defined $resultsdir) {
		open (my $result, ">:encoding(UTF-8)", "$resultsdir/$testid.off.json") or die("Could not create $resultsdir/$testid.off.json: $!\n");
		print $result $json->pretty->encode($product_ref);
		close ($result);		
	}
	
	# Compare the result with the expected result
	
	if (open (my $expected_result, "<:encoding(UTF-8)", "$data_root/t/expected_test_results/$testdir/$testid.off.json")) {

		local $/; #Enable 'slurp' mode
		my $expected_product_ref = $json->decode(<$expected_result>);
		is_deeply ($product_ref, $expected_product_ref) or diag explain $product_ref;
	}
	else {
		fail("could not load expected_test_results/$testdir/$testid.off.json");
		diag explain $product_ref;
	}
}

is(print_unknown_entries_in_gs1_maps(),0);

done_testing();
