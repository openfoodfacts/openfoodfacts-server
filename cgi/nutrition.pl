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
use ProductOpener::Display qw/display_error_and_exit display_too_many_requests_page_and_exit init_request/;
use ProductOpener::HTTP qw/single_param/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Users qw/$Owner_id $User_id/;
use ProductOpener::Lang qw/$lc %Lang/;
use ProductOpener::Routing qw/check_and_update_rate_limits/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Products qw/normalize_code product_id_for_owner retrieve_product/;
use ProductOpener::Food qw/extract_nutrition_from_image/;
use ProductOpener::Images qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::MaybeXS;
use Log::Any qw($log);

my $request_ref = ProductOpener::Display::init_request();

# OCR can cost a call to the Google Cloud Vision API: only let a logged in user start one, and
# account the request against the "ocr" bucket before any work is done.
if (not defined $User_id) {
	display_error_and_exit($request_ref, $Lang{error_no_permission}{$lc}, 403);
}

$request_ref->{rate_limiter_bucket} = 'ocr';
if (not $rate_limiter_disabled) {
	check_and_update_rate_limits($request_ref);
	if ($request_ref->{rate_limiter_blocking}) {
		display_too_many_requests_page_and_exit();
	}
}

my $code = normalize_code(single_param('code'));
my $id = single_param('id');
my $ocr_engine = single_param('ocr_engine');
my $annotations = single_param('annotations') | 0;

$log->debug("start", {code => $code, id => $id}) if $log->is_debug();

if (not defined $code) {

	exit(0);
}

my $product_id = product_id_for_owner($Owner_id, $code);
my $product_ref = retrieve_product($product_id);

my $results_ref = {};

if (($id =~ /^nutrition_(\w\w)$/) and (single_param('process_image'))) {
	extract_nutrition_from_image($product_ref, "nutrition", $1, $ocr_engine, $results_ref, 1);
	if ($results_ref->{status} == 0) {
		if (not $annotations) {
			delete $results_ref->{nutrition_text_from_image_annotations};
		}
	}
}
my $data = encode_json($results_ref);

$log->debug("JSON data output", {data => $data}) if $log->is_debug();

print header (-charset => 'UTF-8') . $data;

exit(0);

