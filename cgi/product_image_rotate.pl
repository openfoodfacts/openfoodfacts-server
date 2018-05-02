#!/usr/bin/perl -w

# This file is part of Product Opener.
# 
# Product Opener
# Copyright (C) 2011-2018 Association Open Food Facts
# Contact: contact@openfoodfacts.org
# Address: 21 rue des Iles, 94100 Saint-Maur des Fossés, France
# 
# Product Opener is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
# 
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

use Modern::Perl '2012';
use utf8;

use CGI::Carp qw(fatalsToBrowser);

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Products qw/:all/;

use CGI qw/:cgi :form escapeHTML/;


my $debug = 1;

my $code = normalize_code(param('code'));
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
my $x = $image->Read("$www_root/images/products/$path/$imgid.${crop_size}.jpg");
if ("$x") {
	print STDERR "product_image_rotate.pl - could not read $www_root/images/products/$path/$imgid.${crop_size}.jpg: $x\n";
}
$image->Rotate($angle);


if ($normalize eq 'checked') {
	$image->Normalize( channel=>'RGB' );
	if ("$x") {
		print STDERR "product_image_rotate.pl - could not normalize: $x\n";
	}		
}

use Apache2::Const 'OK';

my $r = shift;
$r->content_type( 'image/jpeg' );
$r->print( $image->ImageToBlob(magick=>'jpeg') );

print STDERR "product_image_rotate.pl - ok\n";

return OK;


exit(0);
