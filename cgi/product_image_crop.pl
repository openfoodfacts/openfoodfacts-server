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
use ProductOpener::Texts qw/:all/;
use ProductOpener::Display qw/init_request/;
use ProductOpener::HTTP qw/write_cors_headers single_param/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Users qw/$Owner_id $User_id %User/;
use ProductOpener::Images qw/is_protected_image process_image_crop get_image_type_and_image_lc_from_imagefield/;
use ProductOpener::Products
	qw/normalize_code product_data_is_protected product_id_for_owner retrieve_product process_product_edit_rules/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::MaybeXS;
use Log::Any qw($log);
use Data::DeepAccess qw(deep_get);

my $request_ref = ProductOpener::Display::init_request();

my $type = single_param('type') || 'add';
my $action = single_param('action') || 'display';

my $code = normalize_code(single_param('code'));

my $product_id = product_id_for_owner($Owner_id, $code);

my $imgid = single_param('imgid');
my $id = single_param('id');

my $generation_ref = {
	angle => single_param('angle'),
	coordinates_image_size => single_param('coordinates_image_size'),
	x1 => single_param('x1'),
	y1 => single_param('y1'),
	x2 => single_param('x2'),
	y2 => single_param('y2'),
	normalize => single_param('normalize'),
	white_magic => single_param('white_magic'),
};

$log->debug(
	"start",
	{
		code => $code,
		imgid => $imgid,
		generation_ref => $generation_ref,
	}
) if $log->is_debug();

if (not defined $code) {

	exit(0);
}

# Check if we have a picture from the manufacturer

my $product_ref = retrieve_product($product_id);

# the id field is of the form [image_type]_[image_lc]
my ($image_type, $image_lc) = get_image_type_and_image_lc_from_imagefield($id);
if (not defined $image_type) {
	my $data = encode_json(
		{
			status =>
				'status not ok - invalid image type (id field), must be of the form (front|ingredients|nutrition|packaging)_([a-z]{2})'
		}
	);

	$log->debug("JSON data output", {data => $data}) if $log->is_debug();

	print header(-type => 'application/json', -charset => 'utf-8') . $data;

	exit;
}

# Check edit rules
my $proceed_with_edit = process_product_edit_rules($product_ref);

$log->debug("edit rules processed", {proceed_with_edit => $proceed_with_edit}) if $log->is_debug();

if (not $proceed_with_edit) {

	my $data = encode_json({status => 'status not ok - edit against edit rules'});

	$log->debug("JSON data output", {data => $data}) if $log->is_debug();

	print header(-type => 'application/json', -charset => 'utf-8') . $data;

	exit;
}

# Do not allow edits / removal through API for data provided by producers (only additions for non existing fields)
# when the corresponding organization has the protect_data checkbox checked
my $protected_data = product_data_is_protected($product_ref);
my $return_code;

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
		and (not is_protected_image($product_ref, $image_type, $image_lc) or $User{moderator}))
	{
		$return_code = process_image_crop($User_id, $product_ref, $image_type, $image_lc, $imgid, $generation_ref);
	}
}
else {
	if (not is_protected_image($product_ref, $image_type, $image_lc) or $User{moderator}) {
		$return_code = process_image_crop($User_id, $product_ref, $image_type, $image_lc, $imgid, $generation_ref);
	}
}

my $data;

if (not defined $return_code) {
	$data = encode_json(
		{
			status => 'status not ok - image not selected',
			imagefield => $id,
		}
	);
}
elsif ($return_code < 0) {
	# -1: imgid not in uploaded images
	# -2: image cannot be read
	my $msg;
	if ($return_code == -1) {
		$msg = "status not ok - image not selected - imgid not in uploaded images";
	}
	elsif ($return_code == -2) {
		$msg = "status not ok - image not selected - image cannot be read";
	}
	$data = encode_json(
		{
			status => $msg,
			imagefield => $id,
		}
	);
}
else {
	my $rev = deep_get($product_ref, "images", "selected", $image_type, $image_lc, "rev");

	$data = encode_json(
		{
			status => 'status ok',
			image => {
				display_url => "$id." . $rev . ".$display_size.jpg",
			},
			imagefield => $id,
		}
	);
}

$log->debug("JSON data output", {data => $data}) if $log->is_debug();

write_cors_headers();

print header(
	-type => 'application/json',
	-charset => 'utf-8',
) . $data;

exit(0);

