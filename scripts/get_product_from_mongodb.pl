#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Products qw/:all/;

use JSON::MaybeXS;
use Getopt::Long;

my $json = JSON::MaybeXS->new->allow_nonref->canonical;

# Get the product code from command line argument
my $code = shift @ARGV;

if (!$code) {
	die "Usage: $0 <product_code>\n";
}

# Retrieve the product from MongoDB
my $product_ref = retrieve_product($code);

if (!$product_ref) {
	die "Product with code $code not found\n";
}

# Dump the product to STDOUT as JSON
print $json->pretty->encode($product_ref);
