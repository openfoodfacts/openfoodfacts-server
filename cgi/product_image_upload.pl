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
use ProductOpener::Paths qw/%BASE_DIRS ensure_dir_created/;
use ProductOpener::Texts qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::HTTP qw/single_param/;
use ProductOpener::Lang qw/$lc lang/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Users qw/$Org_id $Owner_id $User_id %User/;
use ProductOpener::Products qw/normalize_code/;
use ProductOpener::ProductImageUpload qw/import_product_image_file/;
use ProductOpener::Auth qw/enforce_scope_if_token_present/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::MaybeXS;
use Log::Any qw($log);

my $type = single_param('type') || 'add';
my $action = single_param('action') || 'display';
my $code = normalize_code(single_param('code'));
# For scan parties, we may get photos in sequence, with the barcode only in the first photo
my $previous_code = normalize_code(single_param('previous_code'));
my $previous_imgid = single_param('previous_imgid');
my $imagefield = single_param('imagefield');
my $delete = single_param('delete');

local $log->context->{upload_session} = int(rand(100000000));

$log->debug("start", {ip => remote_addr(), type => $type, action => $action, code => $code}) if $log->is_debug();

my $env = $ENV{QUERY_STRING};

$log->debug("calling init()", {query_string => $env});

my $request_ref = ProductOpener::Display::init_request();

enforce_scope_if_token_present($request_ref, 'products:write');

$log->debug(
	"parsing code",
	{
		subdomain => $request_ref->{subdomain},
		original_subdomain => $request_ref->{original_subdomain},
		user => $User_id,
		code => $code,
		previous_code => $previous_code,
		previous_imgid => $previous_imgid,
		cc => $request_ref->{cc},
		lc => $lc,
		imagefield => $imagefield,
		ip => remote_addr()
	}
) if $log->is_debug();

# Check that the image directory exists
ensure_dir_created($BASE_DIRS{PRODUCTS_IMAGES}) or display_error_and_exit($request_ref, "Missing path", 503);

# Producers platform: the input file name is files[]
# If no code and imagefield is passed, import_product_image_file() tries to guess it from the filename,
# then by scanning the barcode, then by using the previous code
my $file = single_param("files[]");

my $response_ref = import_product_image_file(
	{
		user_id => $User_id,
		org_id => $Org_id,
		owner_id => $Owner_id,
		moderator => $User{moderator},
		lc => $lc,
		country => $request_ref->{country},
		code => $code,
		imagefield => $imagefield,
		filename => defined($file) ? ($file . "") : "",
		filehandle => $file,
		tmp_file_prefix => remote_addr(),
		previous_code => $previous_code,
		previous_imgid => $previous_imgid,
		source => single_param('source'),
	}
);

my $data = encode_json($response_ref);

$log->debug("JSON data output", {data => $data}) if $log->is_debug();

print header(-type => 'application/json', -charset => 'utf-8') . $data;

exit(0);

