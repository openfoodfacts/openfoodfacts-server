#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2019 Association Open Food Facts
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

use Modern::Perl '2017';
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
use Log::Any qw($log);

ProductOpener::Display::init();

my $type = param('type') || 'add';
my $action = param('action') || 'display';

my $code = normalize_code(param('code'));
my $imgid = param('imgid');
my $angle = param('angle');
my $id = param('id');
my ($x1,$y1,$x2,$y2) = (param('x1'),param('y1'),param('x2'),param('y2'));
my $normalize = param('normalize');
my $white_magic = param('white_magic');

$log->debug("start", { code => $code, imgid => $imgid, x1 => $x1, y1 => $y1, x2 => $x2, y2 => $y2 }) if $log->is_debug();

if (not defined $code) {

	exit(0);
}

# Check if we have a picture from the manufacturer

my $product_ref = retrieve_product($code);

if ((defined $product_ref) and (has_tag($product_ref,"data_sources","producers")) and (defined $product_ref->{images}) and (defined $product_ref->{images}{$id})
	and (referer() !~ /\/cgi\/product.pl/)) {
	print STDERR "product_image_crop.pl - skip image id $id for product code $code (data from producer) - referer: " . referer() . "\n";
}
elsif ((defined $User_id) and (($User_id eq 'kiliweb')) or (remote_addr() eq "207.154.237.7")) {
	# Skip images selected by Yuka -> they have already been selected through the upload if they were the first
	# otherwise we can have images selected twice, once with the right language (set for the upload with the cc field), and another time with fr
	# Yuka may not be passing the user_id for the crop, use the ip 207.154.237.7

	# 2019/08/28: accept images if there is already an image selected for the language
	if ((defined $product_ref) and (defined $product_ref->{images}) and (defined $product_ref->{images}{$imgid})) {
		$product_ref = process_image_crop($code, $id, $imgid, $angle, $normalize, $white_magic, $x1, $y1, $x2, $y2);
	}
}
else {
	$product_ref = process_image_crop($code, $id, $imgid, $angle, $normalize, $white_magic, $x1, $y1, $x2, $y2);
}

my $data =  encode_json({ status => 'status ok',
		image => {
				display_url=> "$id." . $product_ref->{images}{$id}{rev} . ".$display_size.jpg",
		},
		imagefield=>$id,
});

$log->debug("JSON data output", { data => $data }) if $log->is_debug();

print header( -type => 'application/json', -charset => 'utf-8' ) . $data;


exit(0);

