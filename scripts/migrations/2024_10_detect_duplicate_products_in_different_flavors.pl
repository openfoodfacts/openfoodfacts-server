#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Store qw/retrieve store/;
use ProductOpener::Data qw/get_products_collection/;

use Log::Any::Adapter 'TAP';

my $socket_timeout_ms = 2 * 60000;    # 2 mins, instead of 30s default, to not die as easily if mongodb is busy.

my %flavors = ();
my %scans = ();
my %product_names = ();
my %brands = ();

foreach my $flavor ("off", "obf", "opf", "opff") {
	my $products_collection = get_products_collection({database => $flavor, timeout => $socket_timeout_ms});

	my $cursor = $products_collection->query({})
		->fields({_id => 1, code => 1, owner => 1, product_name => 1, brands => 1, scans_n => 1});
	$cursor->immortal(1);

	while (my $product_ref = $cursor->next) {
		my $code = $product_ref->{code};
		$flavors{all}{$code}++;
		$flavors{$flavor}{$code}++;
		if ($product_ref->{scans_n} > $scans{$code}) {
			$scans{$code} = $product_ref->{scans_n};
		}
		if (not defined $product_names{$code}) {
			$product_names{$code} = $product_ref->{product_name};
		}
		if (not defined $brands{$code}) {
			$brands{$code} = $product_ref->{brands};
		}
	}
}

foreach my $flavor (keys %flavors) {
	print "Flavor $flavor\t" . scalar(keys %{$flavors{$flavor}}) . " products\n";
}

my $d = 0;

open(OUT, ">:encoding(UTF-8)", "/srv/off/html/files/duplicate_products.csv");
print OUT "code\tproduct_name\tbrands\tscans\toff\tobf\topf\topff\n";

my %urls = (
	off => "https://world.openfoodfacts.org",
	obf => "https://world.openbeautyfacts.org",
	opf => "https://world.openproductsfacts.org",
	opff => "https://world.openpetfoodfacts.org",
);

foreach my $code (sort keys %{$flavors{all}}) {
	next if $flavors{all}{$code} <= 1;
	print $code . "\t" . ($product_names{$code} || '') . "\t" . ($brands{$code} || '') . "\t" . ($scans{$code} || 0);
	print OUT $code . "\t"
		. ($product_names{$code} || '') . "\t"
		. ($brands{$code} || '') . "\t"
		. ($scans{$code} || 0);
	foreach $flavor ("off", "obf", "opf", "opff") {
		if ($flavors{$flavor}{$code}) {
			print "\t" . $flavor . " (" . $flavors{$flavor}{$code} . ")";
			print OUT "\t" . $urls{$flavor} . "/product/$code";
		}
		else {
			print "\t";
			print OUT "\t";
		}
	}
	print "\n";
	print OUT "\n";
	$d++;
}

print "\n\n" . $d . " duplicate products\n\n";
