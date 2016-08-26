#!/usr/bin/perl

use CGI::Carp qw(fatalsToBrowser);

use strict;
use utf8;

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Mail qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::Images qw/:all/;


use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON;

$User_id = 'stephane';

my $dir = $ARGV[0];
$dir =~ s/\/$//;

print "uploading photos from dir $dir\n";

my $i = 0;
my $j = 0;
my $exists = 0;

my %codes = ();
my $current_code = undef;
my $previous_code = undef;
my $last_imgid = undef;

my $current_product_ref = undef;

my @fields = qw(product_name generic_name quantity packaging brands categories labels origins manufacturing_places emb_codes link expiration_date purchase_places stores countries  );


my %params = (
	lc => 'en',
	countries => "UK",
	purchase_places => "London",
);

if (opendir (DH, "$dir")) {
	foreach my $file (sort readdir(DH)) {
		if ($file =~ /jpg/i) {
			my $code = scan_code("$dir/$file");
			print $file . "\tcode: " . $code . "\n";
			
			if ((defined $code) and (not defined $codes{$code})) {	# in some pictures we detect the wrong code, for a product we already scanned..
			# see http://world.openfoodfacts.org/cgi/product.pl?type=edit&code=5010663251270 -> a barely there code is still detected
						
				$codes{$code}++;
				
				if (($code ne $current_code)) {
				
					$j++;
				
					my $product_ref = product_exists($code);
					if ($product_ref) {
						$exists++;
						print "code $code exists\n";
					}
				}				
				
				$current_code = $code;
				

				
				 # returns 0 if not
				

			}
			
			$i++;
			
		} #jpg
		
	}
	closedir DH;
}
else {
	print STDERR "Could not open dir $dir: $!\n";
}

print "$i images - $j codes - $exists exists\n";
print (scalar (keys %codes)) . " codes\n";

