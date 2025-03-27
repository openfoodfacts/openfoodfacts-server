#!/usr/bin/perl -w

use strict;
use warnings;

use utf8;

use JSON;

use Log::Any::Adapter 'TAP', filter => "none";

my $input_dir = "/srv/off/imports/codeonline";
my $output_dir = "/srv2/off/imports/codeonline";

my $usage = <<TXT
Split the GS1 Code Online Food monthly export in JSON format in individual JSON files (1 per product)

The files need to be stored in $input_dir
with a filename of the form opendatags1_fr_[YYYYMM].json

Usage:

split_gs1_codeonline_json.pl [YYYYMM]

TXT
	;

my $date = $ARGV[0];

if (not defined $date) {

	print STDERR "Error in command line arguments:\n\n$usage";
	exit();
}

my $input_file = $input_dir . "/opendatags1_fr_$date.json";
$output_dir .= "/$date";

print STDERR "processing $input_file in $output_dir\n";

if (!-e $output_dir) {
	mkdir($output_dir, oct(755)) or die("Cannot create $output_dir : $!\n");
}

my $json = JSON->new->allow_nonref->canonical;

open(my $gs1, "<:encoding(UTF-8)", $input_file) or die("Cannot open $input_file: $!\n");
local $/;    #Enable 'slurp' mode
my $gs1_product_ref = $json->decode(<$gs1>);
close($gs1);

print scalar(@{$gs1_product_ref}) . " products\n\n";

for (my $i = 0; $i < scalar(@{$gs1_product_ref}); $i++) {

	open(my $out, ">:encoding(UTF-8)", "$output_dir/" . $gs1_product_ref->[$i]{tradeItem}{gtin} . ".json");
	print $out $json->pretty->encode($gs1_product_ref->[$i]);
	print "\n";
	close $out;

}
