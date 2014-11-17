#!/usr/bin/perl

use CGI::Carp qw(fatalsToBrowser);

use strict;
use utf8;

use Blogs::Config qw/:all/;
use Blogs::Store qw/:all/;
use Blogs::Index qw/:all/;
use Blogs::Display qw/:all/;
use Blogs::Tags qw/:all/;
use Blogs::Users qw/:all/;
use Blogs::Images qw/:all/;
use Blogs::Products qw/:all/;
use Blogs::Ingredients qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON;

Blogs::Display::init();

$debug = 1;


my $code = param('code');
my $id = param('id');

$debug and print STDERR "product_image.pl - code: $code\n";

if (not defined $code) {
	
	exit(0);
}
my $product_ref = retrieve_product($code);

my %results = ();

if (($id eq 'ingredients') and (param('process_image'))) {
	$results{status} = extract_ingredients_from_image($product_ref);
	if ($results{status} == 0) {
		$results{ingredients_text_from_image} = $product_ref->{ingredients_text_from_image};
		$results{ingredients_text_from_image} =~ s/\n/ /g;
	}
}
my $data =  encode_json(\%results);

print STDERR "ingredients.pl - JSON data output: $data\n";
	
print header ( -charset=>'UTF-8') . $data;


exit(0);

