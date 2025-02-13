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

print STDERR "generating stats for $input_file in $output_dir\n";

my $json = JSON->new->allow_nonref->canonical;

open(my $gs1, "<:encoding(UTF-8)", $input_file) or die("Cannot open $input_file: $!\n");
local $/;    #Enable 'slurp' mode
my $gs1_product_ref = $json->decode(<$gs1>);
close($gs1);

print scalar(@{$gs1_product_ref}) . " products\n\n";

my %owners = ();
my %providers = ();
my %glns = ();

for (my $i = 0; $i < scalar(@{$gs1_product_ref}); $i++) {

	#   "tradeItem" : {
	#      "brandOwner" : {
	#         "gln" : "3010217600105",
	#         "partyName" : "MATERNE SAS"
	#      },
	#      "gdsnTradeItemClassification" : {
	#         "gpcCategoryCode" : "10000207"
	#      },
	#      "gtin" : "03021760292280",
	#      "informationProviderOfTradeItem" : {
	#         "gln" : "3010217600020",
	#         "partyName" : "MATERNE"
	#      },

	my $tradeitem_ref = $gs1_product_ref->[$i]{tradeItem};

	my $owner_gln = $tradeitem_ref->{brandOwner}{gln};
	my $owner = $tradeitem_ref->{brandOwner}{partyName};

	my $provider_gln = $tradeitem_ref->{informationProviderOfTradeItem}{gln};
	my $provider = $tradeitem_ref->{informationProviderOfTradeItem}{partyName};

	$owners{$owner_gln}++;
	$providers{$provider_gln}++;

	defined $glns{$owner_gln} or $glns{$owner_gln} = {};
	defined $glns{$provider_gln} or $glns{$provider_gln} = {};

	if (length($owner) >= 2) {
		defined $glns{$owner_gln}{$owner} or $glns{$owner_gln}{$owner} = 1;
		$glns{$owner_gln}{$owner}++;
	}

	if (length($provider) >= 2) {
		defined $glns{$provider_gln}{$provider} or $glns{$provider_gln}{$provider} = 1;
		$glns{$provider_gln}{$provider}++;
	}
}

print scalar(@{$gs1_product_ref}) . " products\n\n";

print "\n" . scalar(keys %owners) . " owners\n\n";

foreach my $owner (sort {$owners{$a} <=> $owners{$b}} keys %owners) {
	print "owner: $owner\t" . $owners{$owner} . " products\n";
}

print "\n" . scalar(keys %providers) . " providers\n\n";

foreach my $provider (sort {$providers{$a} <=> $providers{$b}} keys %providers) {

	my $name = "";
	if (defined $glns{$provider}) {
		my @names = sort ({$glns{$provider}{$b} <=> $glns{$provider}{$a}} keys %{$glns{$provider}});
		$name = $names[0];
	}

	print "provider: $provider\t" . $name . "\t" . $providers{$provider} . " products\n";
}
