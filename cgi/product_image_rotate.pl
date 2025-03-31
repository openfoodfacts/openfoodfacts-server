#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2023 Association Open Food Facts
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

use ProductOpener::PerlStandards;

use CGI::Carp qw(fatalsToBrowser);

use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Products qw/normalize_code product_id_for_owner product_path_from_id/;
use ProductOpener::Display qw/init_request/;
use ProductOpener::HTTP qw/single_param/;
use ProductOpener::Users qw/$Owner_id/;

use Apache2::Const qw(OK HTTP_BAD_REQUEST HTTP_NOT_FOUND HTTP_INTERNAL_SERVER_ERROR);
use CGI qw/:cgi :form escapeHTML/;
use Log::Any qw($log);

my $request_ref = ProductOpener::Display::init_request();

my $code = normalize_code(single_param('code'));
my $product_id = product_id_for_owner($Owner_id, $code);
my $path = product_path_from_id($product_id);
my $imgid = single_param('imgid');
my $angle = single_param('angle');
my $normalize = single_param('normalize');
my $white_magic = single_param('white_magic');

$log->debug('start', {code => $code, imgid => $imgid, angle => $angle, normalize => $normalize})
	if $log->is_debug();    ## no critic (ProhibitPostfixControls)

my $r = shift;
if (
	   (not defined $imgid)
	or (not defined $angle)
	or ($imgid !~ /^\d+$/sx)
	or    ## no critic (RequireLineBoundaryMatching)
	($angle !~ /^(?:[\d]|[1-8][\d]|9[\d]|[12][\d]{2}|3[0-5][\d]|360)$/sx)
	)
{    ## no critic (RequireLineBoundaryMatching)
	$r->status(HTTP_BAD_REQUEST);
	return OK;
}

my $image = Image::Magick->new;
my $x = $image->Read("$BASE_DIRS{PRODUCTS_IMAGES}/$path/$imgid.${crop_size}.jpg");
if ("$x") {
	$log->error('could not read image',
		{path => "$BASE_DIRS{PRODUCTS_IMAGES}/$path/$imgid.${crop_size}.jpg", status => $x})
		if $log->is_error();    ## no critic (ProhibitPostfixControls)
	$r->status(HTTP_NOT_FOUND);
	return OK;
}

$image->Rotate($angle);

if ($normalize eq 'checked') {
	$image->Normalize(channel => 'RGB');
	if ("$x") {
		$log->error('could not normalize image', {status => $x})
			if $log->is_error();    ## no critic (ProhibitPostfixControls)
		$r->status(HTTP_INTERNAL_SERVER_ERROR);
		return OK;
	}
}

$r->content_type('image/jpeg');
$r->print($image->ImageToBlob(magick => 'jpeg'));

$log->info('ok');

return OK;
