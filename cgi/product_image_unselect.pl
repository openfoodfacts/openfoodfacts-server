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

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;

ProductOpener::Display::init();

$debug = 1;

my $type = param('type') || 'add';
my $action = param('action') || 'display';

my $code = normalize_code(param('code'));
my $id = param('id');


$debug and print STDERR "product_image_unselect.pl - code: $code - id: $id\n";

if (not defined $code) {
	
	exit(0);
}

my $product_ref = process_image_unselect($code, $id);

my $data = encode_json({ status_code => 0, status => 'status ok', imagefield=>$id });

print STDERR "product_image_unselect - JSON data output: $data\n";

print header( -type => 'application/json', -charset => 'utf-8' ) . $data;


exit(0);

