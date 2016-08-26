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
use ProductOpener::Products qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON;

ProductOpener::Display::init();

$debug = 1;

my $type = param('type') || 'add';
my $action = param('action') || 'display';

my $code = normalize_code(param('code'));
my $imgid = param('imgid');
my $angle = param('angle');
my $id = param('id');
my ($x1,$y1,$x2,$y2) = (param('x1'),param('y1'),param('x2'),param('y2'));
my $normalize = param('normalize');
my $white_magic = param('white_magic');

$debug and print STDERR "product_image_crop.pl - code: $code - imgid: $imgid $x1,$y1 $x2,$y2\n";

if (not defined $code) {
	
	exit(0);
}

my $product_ref = process_image_crop($code, $id, $imgid, $angle, $normalize, $white_magic, $x1, $y1, $x2, $y2);

my $data =  encode_json({ status => 'status ok',
		image => {
				display_url=> "$id." . $product_ref->{images}{$id}{rev} . ".$display_size.jpg",
		},
		imagefield=>$id,
});

print STDERR "product_image_crop - JSON data output: $data\n";

print header() . $data;


exit(0);

