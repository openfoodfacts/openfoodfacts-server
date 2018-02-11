#!/usr/bin/perl

use Modern::Perl '2012';
use utf8;

use CGI::Carp qw(fatalsToBrowser);

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Products qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use Log::Any qw($log);

my $code = normalize_code(param('code'));
my $path = product_path($code);
my $imgid = param('imgid');
my $angle = param('angle');
my $normalize = param('normalize');
my $white_magic = param('white_magic');

$log->debug("product_image_rotate.pl - start", { code => $code, imgid => $imgid, angle => $angle, normalize => $normalize }) if $log->is_debug();

if ((not defined $imgid) or (not defined $angle) or ($imgid !~ /^[0-9]+$/)) {
	exit(0);
}

my $image = Image::Magick->new;			
my $x = $image->Read("$www_root/images/products/$path/$imgid.${crop_size}.jpg");
if ("$x") {
	$log->error("product_image_rotate.pl - could not read image", { path => "$www_root/images/products/$path/$imgid.${crop_size}.jpg", status => $x }) if $log->is_error();
}
$image->Rotate($angle);


if ($normalize eq 'checked') {
	$image->Normalize( channel=>'RGB' );
	if ("$x") {
		$log->error("product_image_rotate.pl - could not normalize image", { status => $x }) if $log->is_error();
	}		
}

use Apache2::Const 'OK';

my $r = shift;
$r->content_type( 'image/jpeg' );
$r->print( $image->ImageToBlob(magick=>'jpeg') );

$log->info("product_image_rotate.pl - ok");

return OK;


exit(0);
