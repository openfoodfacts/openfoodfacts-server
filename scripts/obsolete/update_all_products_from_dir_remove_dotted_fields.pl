#!/usr/bin/perl

use CGI::Carp qw(fatalsToBrowser);

use Modern::Perl '2015';
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

use Data::Dumper;


# Get a list of all products

use Getopt::Long;

my @products = ();


GetOptions ( 'products=s' => \@products);
@products = split(/,/,join(',',@products));


sub find_products($$) {

	my $dir = shift;
	my $code = shift;

	opendir DH, "$dir" or die "could not open $dir directory: $!\n";
	foreach my $file (readdir(DH)) {
		chomp($file);
		#print "file: $file\n";
		if ($file eq 'product.sto') {
			push @products, $code;
			#print "code: $code\n";
		}
		else {
			$file =~ /\./ and next;
			if (-d "$dir/$file") {
				find_products("$dir/$file","$code$file");
			}
		}
	}
	closedir DH;
}


if (scalar $#products < 0) {
	find_products("$data_root/products",'');
}





my $count = $#products;
my $i = 0;
my $updated = 0;

my %codes = ();
	
	print STDERR "$count products to update\n";
	
	foreach my $code (@products) {

		#next if ($code ne "4072700318675");
		
		my $path = product_path($code);
		
		
		#my $product_ref = retrieve_product($code);
		my $product_ref = retrieve("$data_root/products/$path/product.sto") or print "not defined $data_root/products/$path/product.sto\n";

		if ((defined $product_ref)) {

			my $update = 0;
			foreach my $k (keys %{$product_ref}) {
				$k =~ /\./ and $update = 1;
			}

			
			if (exists $product_ref->{"countries.20131226"}) {
				delete $product_ref->{"countries.20131226"};
			}
			if (exists $product_ref->{"countries.20131227"}) {
                                delete $product_ref->{"countries.20131227"};
                        }
			if (exists $product_ref->{"countries.beforescanbot"}) {
                                delete $product_ref->{"countries.beforescanbot"};
                        }
			if (exists $product_ref->{"traces.tags"}) {
                                delete $product_ref->{"traces.tags"};
                        }
			if (exists $product_ref->{"categories.tags"}) {
                                delete $product_ref->{"categories.tags"};
                        }
                        if (exists $product_ref->{"packaging.tags"}) {
                                delete $product_ref->{"packaging.tags"};
                        }
                        if (exists $product_ref->{"labels.tags"}) {
                                delete $product_ref->{"labels.tags"};
                        }
                        if (exists $product_ref->{"origins.tags"}) {
                                delete $product_ref->{"origins.tags"};
                        }
                        if (exists $product_ref->{"brands.tags"}) {
                                delete $product_ref->{"brands.tags"};
                        }


			$i++;
			$codes{$code} = 1;
			
			if ($update) {
				store("$data_root/products/$path/product.sto", $product_ref);	
				$updated++;
			}
		}
	}

print STDERR "$count products to update - $i products not empty or deleted - $updated product with dotted fields\n";
print STDERR "scalar keys codes : " . (scalar keys %codes) . "\n";

exit(0);

