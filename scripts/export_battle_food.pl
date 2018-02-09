#!/usr/bin/perl

use CGI::Carp qw(fatalsToBrowser);

use Modern::Perl '2012';
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
use ProductOpener::Lang qw/:all/;


use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON;

my @fields = qw(product_name generic_name quantity packaging brands categories origins labels emb_codes );
my %tags_fields = (packaging => 1, brands => 1, categories => 1, labels => 1, origins => 1, emb_codes=>1, cities=>1, traces => 1);


my @fields = qw (
code
creator
created_t
product_name
generic_name
quantity
packaging
brands 
categories 
origins
labels
emb_codes
cities
ingredients
traces
serving_size
images
);

my %langs = ();
my $total = 0;

my $fields_ref = {};
	
foreach my $field (@fields) {
	$fields_ref->{$field} = 1;
	if (defined $tags_fields{$field}) {
		$fields_ref->{$field . "_tags"} = 1;
	}
}

$fields_ref->{nutriments} = 1;


foreach my $l (values %lang_lc) {

	$lc = $l;
	$lang = $l;
	
	my $cursor = $products_collection->query({lc=>$lc})->fields($fields_ref)->sort({code=>1});
	my $count = $cursor->count();
	
	$langs{$l} = $count;
	$total += $count;
		
	print STDERR "lc: $lc - $count products\n";


	my @products = ();
	
	# Headers
	
	my $size = $display_size;
	my $id = 'front';
	
	my $n = 0;
		
	while (my $product_ref = $cursor->next) {
		
		if ((defined $product_ref->{images}) and (defined $product_ref->{images}{$id})
			and (defined $product_ref->{images}{$id}{sizes}) and (defined $product_ref->{images}{$id}{sizes}{$size})) {
		
			my $path = product_path($product_ref->{code});

			
			$product_ref->{image_url} = "https://$lc.openfoodfacts.org/images/products/$path/$id." . $product_ref->{images}{$id}{rev} . '.' . $display_size . '.jpg';
			$product_ref->{image_small_url} = "https://$lc.openfoodfacts.org/images/products/$path/$id." . $product_ref->{images}{$id}{rev} . '.' . $small_size . '.jpg';
			
			push @products, $product_ref;
		}		
		
		$n++;
		$n >= 10 and last;

	}


	open (my $OUT, ">:encoding(UTF-8)", "$www_root/data/$lang.openfoodfacts.org.products.battlefood.10.json");
	my $data =  encode_json(\@products);
	$data =~ s/\.100g/_100g/g;
	print $OUT  $data;		
	close $OUT;
	
}

exit(0);

