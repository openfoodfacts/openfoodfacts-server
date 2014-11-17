#!/usr/bin/perl

use CGI::Carp qw(fatalsToBrowser);

use strict;
use utf8;

use Blogs::Config qw/:all/;
use Blogs::Store qw/:all/;
use Blogs::Products qw/:all/;

use CGI qw/:cgi :form escapeHTML/;


my $debug = 1;

my $code = param('code');
my $path = product_path($code);
my $imgid = param('imgid');
my $angle = param('angle');
my $normalize = param('normalize');
my $white_magic = param('white_magic');

$debug and print STDERR "product_image_rotate.pl - code: $code  - imgid: $imgid - angle: $angle - normalize: $normalize\n";

if ((not defined $imgid) or (not defined $angle) or ($imgid !~ /^[0-9]+$/)) {
	exit(0);
}

my $image = Image::Magick->new;			
my $x = $image->Read("$data_root/html/images/products/$path/$imgid.${crop_size}.jpg");
if ("$x") {
	print STDERR "product_image_rotate.pl - could not read $data_root/html/images/products/$path/$imgid.${crop_size}.jpg: $x\n";
}
$image->Rotate($angle);


if ($normalize eq 'checked') {
	$image->Normalize( channel=>'RGB' );
	if ("$x") {
		print STDERR "product_image_rotate.pl - could not normalize: $x\n";
	}		
}
print header("Content-Type" => "image/jpeg");
binmode STDOUT;
print $image->ImageToBlob(magick=>'jpeg');

print STDERR "product_image_rotate.pl - ok\n";

exit(0);
