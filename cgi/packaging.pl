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
use ProductOpener::Packaging qw/:all/;

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
my $annotations = param('annotations') | 0;

if (not defined $ocr_engine) {
	$ocr_engine = "tesseract";
	# $ocr_engine = "google_cloud_vision";
}

$log->debug("start", { code => $code, id => $id }) if $log->is_debug();

if (not defined $code) {

	exit(0);
}

my $product_id = product_id_for_owner($Owner_id, $code);
my $product_ref = retrieve_product($product_id);

my $results_ref = {};

if (($id =~ /^packaging/) and (param('process_image'))) {
	extract_packaging_from_image($product_ref, $id, $ocr_engine, $results_ref);
	if ($results_ref->{status} == 0) {
		$results_ref->{packaging_text_from_image} =~ s/\n/ /g;
		if (not $annotations) {
			delete $results_ref->{packaging_text_from_image_annotations};
		}
	}
}
my $data =  encode_json($results_ref);

$log->debug("JSON data output", { data => $data }) if $log->is_debug();

print header ( -charset=>'UTF-8', -access_control_allow_origin => '*' ) . $data;


exit(0);

