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
my $id = single_param('id');

my $product_id = product_id_for_owner($Owner_id, $code);
my $product_ref = retrieve_product($product_id);

$log->debug("start", {code => $code, id => $id}) if $log->is_debug();

if (not defined $code) {

	exit(0);
}

if (not is_protected_image($product_ref, $id) or $User{moderator}) {
	$product_ref = process_image_unselect($User_id, $product_id, $id);
}

my $data = encode_json({status_code => 0, status => 'status ok', imagefield => $id});

$log->debug("JSON data output", {data => $data}) if $log->is_debug();

print header(-type => 'application/json', -charset => 'utf-8') . $data;

exit(0);

