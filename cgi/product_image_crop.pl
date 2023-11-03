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
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::HTTP qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Products qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;
use Log::Any qw($log);

my $request_ref = ProductOpener::Display::init_request();

my $type = single_param('type') || 'add';
my $action = single_param('action') || 'display';

my $code = normalize_code(single_param('code'));

my $product_id = product_id_for_owner($Owner_id, $code);

my $imgid = single_param('imgid');
my $angle = single_param('angle');
my $id = single_param('id');
my ($x1, $y1, $x2, $y2) = (single_param('x1'), single_param('y1'), single_param('x2'), single_param('y2'));
my $normalize = single_param('normalize');
my $white_magic = single_param('white_magic');

# The new product_multilingual.pl form will set $coordinates_image_size to "full"
# the current Android app will not send it, and it will send coordinates related to the ".400" image
# that has a max width and height of 400 pixels
my $coordinates_image_size = single_param('coordinates_image_size') || $crop_size;

$log->debug(
	"start",
	{
		code => $code,
		imgid => $imgid,
		x1 => $x1,
		y1 => $y1,
		x2 => $x2,
		y2 => $y2,
		param_coordinates_image_size => single_param('coordinates_image_size'),
		coordinates_image_size => $coordinates_image_size
	}
) if $log->is_debug();

if (not defined $code) {

	exit(0);
}

# Check if we have a picture from the manufacturer

my $product_ref = retrieve_product($product_id);

# Do not allow edits / removal through API for data provided by producers (only additions for non existing fields)
# when the corresponding organization has the protect_data checkbox checked
my $protected_data = product_data_is_protected($product_ref);

if (    (defined $product_ref)
	and ($protected_data)
	and (defined $product_ref->{images})
	and (defined $product_ref->{images}{$id})
	and (referer() !~ /\/cgi\/product.pl/))
{
	$log->debug("do not select image: data_sources contains producers and referer is not the web product edit form",
		{code => $code, id => $id, referer => referer()})
		if $log->is_debug();
}
elsif ((defined $User_id) and (($User_id eq 'kiliweb')) or (remote_addr() eq "207.154.237.7")) {
	# Skip images selected by Yuka -> they have already been selected through the upload if they were the first
	# otherwise we can have images selected twice, once with the right language (set for the upload with the cc field), and another time with fr
	# Yuka may not be passing the user_id for the crop, use the ip 207.154.237.7

	# 2019/08/28: accept images if there is already an image selected for the language
	if (    (defined $product_ref)
		and (defined $product_ref->{images})
		and (defined $product_ref->{images}{$imgid})
		and (not is_protected_image($product_ref, $id) or $User{moderator}))
	{
		$product_ref
			= process_image_crop($User_id, $product_id, $id, $imgid, $angle, $normalize, $white_magic, $x1, $y1, $x2,
			$y2, $coordinates_image_size);
	}
}
else {
	if (not is_protected_image($product_ref, $id) or $User{moderator}) {
		$product_ref
			= process_image_crop($User_id, $product_id, $id, $imgid, $angle, $normalize, $white_magic, $x1, $y1, $x2,
			$y2, $coordinates_image_size);
	}
}

my $data = encode_json(
	{
		status => 'status ok',
		image => {
			display_url => "$id." . $product_ref->{images}{$id}{rev} . ".$display_size.jpg",
		},
		imagefield => $id,
	}
);

$log->debug("JSON data output", {data => $data}) if $log->is_debug();

write_cors_headers();
print header(-type => 'application/json', -charset => 'utf-8') . $data;

exit(0);

