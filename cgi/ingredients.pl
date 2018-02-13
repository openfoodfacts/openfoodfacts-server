#!/usr/bin/perl

use Modern::Perl '2012';
use utf8;

use CGI::Carp qw(fatalsToBrowser);

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Ingredients qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;
use Log::Any qw($log);

ProductOpener::Display::init();

my $code = normalize_code(param('code'));
my $id = param('id');

my $ocr_engine = param('ocr_engine');

if (not defined $ocr_engine) {
	$ocr_engine = "tesseract";
	# $ocr_engine = "google_cloud_vision";
}

$log->debug("start", { code => $code, id => $id }) if $log->is_debug();

if (not defined $code) {
	
	exit(0);
}
my $product_ref = retrieve_product($code);

my %results = ();

if (($id =~ /^ingredients/) and (param('process_image'))) {
	$results{status} = extract_ingredients_from_image($product_ref, $id, $ocr_engine);
	if ($results{status} == 0) {
		$results{ingredients_text_from_image} = $product_ref->{ingredients_text_from_image};
		$results{ingredients_text_from_image} =~ s/\n/ /g;
	}
}
my $data =  encode_json(\%results);

$log->debug("JSON data output", { data => $data }) if $log->is_debug();
	
print header ( -charset=>'UTF-8') . $data;


exit(0);

