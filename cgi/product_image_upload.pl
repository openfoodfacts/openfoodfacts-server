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
use ProductOpener::Lang qw/:all/;
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

my $type = param('type') || 'add';
my $action = param('action') || 'display';
my $code = normalize_code(param('code'));
# For scan parties, we may get photos in sequence, with the barcode only in the first photo
my $previous_code = normalize_code(param('previous_code'));
my $previous_imgid = param('previous_imgid');
my $imagefield = param('imagefield');
my $delete = param('delete');

local $log->context->{upload_session} = int(rand(100000000));

$log->debug("start", { ip => remote_addr(), type => $type, action => $action, code => $code }) if $log->is_debug();

my $env = $ENV{QUERY_STRING};

$log->debug("calling init()", { query_string => $env });

ProductOpener::Display::init();

$log->debug("parsing code", { subdomain => $subdomain, original_subdomain => $original_subdomain, user => $User_id, code => $code, previous_code => $previous_code, previous_imgid => $previous_imgid, cc => $cc, lc => $lc, imagefield => $imagefield, ip => remote_addr() }) if $log->is_debug();

# By default, don't select images uploaded (e.g. through the product edit form)

my $select_image = 0;

# Producers platform: the input file name is files[]
# If no code and imagefield is passed, try to guess it from the filename

my $code_specified = 1;
my $filename;
my $tmp_filename;

my $using_previous_code;
my $scanned_code;
my $code_from_file_name;

if (not defined $code) {

	$code_specified = 0;

	my $file = param("files[]");
	$filename = $file . "";

	($code, $imagefield) = get_code_and_imagefield_from_file_name($lc, $filename);

	if ($code) {
		$code_from_file_name = $code;
	}
	else {

		if ($file =~ /\.(gif|jpeg|jpg|png|heic)$/i) {

			$log->debug("scan barcode in image file", { file => $file }) if $log->is_debug();

			my $extension = lc($1) ;
			$tmp_filename = get_string_id_for_lang("no_language", remote_addr(). '_' . $`);

			(-e "$data_root/tmp") or mkdir("$data_root/tmp", 0755);
			open (my $out, ">", "$data_root/tmp/$tmp_filename.$extension") ;
			while (my $chunk = <$file>) {
				print $out $chunk;
			}
			close ($out);

			$code = scan_code("$data_root/tmp/$tmp_filename.$extension");
			if (defined $code) {
				$code = normalize_code($code);
				$scanned_code = $code;
			}
			$tmp_filename = "$data_root/tmp/$tmp_filename.$extension";
		}

		# If we have a previous code, use it
		if ((not $code) and (defined $previous_code)) {
			$log->debug("no barcode found in image file, using previous code", { previous_code => $previous_code }) if $log->is_debug();
			$code = $previous_code;
			$using_previous_code = $previous_code;
		}
	}

	if ($code) {
		if ((defined $imagefield) and ($imagefield !~ /\//) and ($imagefield !~ /^other/)) {
			$select_image = 1;
		}
	}
}


my $response_ref = {
	files => [{
			filename => $filename . "",	# Make filename a scalar
	}],
};

if ((not defined $code) or ($code eq '')) {

	$log->warn("no code");
	$response_ref->{status} = 'status not ok';
	$response_ref->{error} = lang("image_upload_error_no_barcode_specified_or_found");
	if (not $code_specified) {
		# for jquery.fileupload-ui.js
		$response_ref->{files}[0]{error} = $response_ref->{error};
	}
	my $data =  encode_json($response_ref);
	print header( -type => 'application/json', -charset => 'utf-8' ) . $data;
	exit(0);
}

$response_ref->{code} = $code;

my $product_id = product_id_for_owner($Owner_id, $code);

my $interface_version = '20120622';

# Create image directory if needed
if (! -e "$www_root/images") {
	mkdir ("$www_root/images", 0755);
}
if (! -e "$www_root/images/products") {
	mkdir ("$www_root/images/products", 0755);
}

if ($imagefield) {

	$response_ref->{imagefield} = $imagefield;

	my $path = product_path_from_id($product_id);

	$log->debug("path determined", { imagefield => $imagefield, path => $path, delete => $delete });

	if ($path eq 'invalid') {
		# non numeric code was given
		$log->warn("no code", { code => $code });
		$response_ref->{status} = 'status not ok';
		$response_ref->{error} = "error - invalid product code: $code";
		$response_ref->{files}[0]{error} = $response_ref->{error};
		my $data =  encode_json($response_ref);
		print header( -type => 'application/json', -charset => 'utf-8' ) . $data;
		exit(0);
	}

	if ((not defined $delete) or ($delete ne 'on')) {

		my $product_ref = product_exists($product_id); # returns 0 if not

		if (not $product_ref) {
			$log->info("product code does not exist yet, creating product", { code => $code });
			$product_ref = init_product($User_id, $Org_id, $code, $country);
			$product_ref->{interface_version_created} = $interface_version;
			$product_ref->{lc} = $lc;
			store_product($product_ref, "Creating product (image upload)");
		}
		else {
			$log->info("product code already exists", { code => $code });
		}
		
		my $product_name =  remove_tags_and_quote(product_name_brand_quantity($product_ref));
		if ((not defined $product_name) or ($product_name eq "")) {
			$product_name = $code;
		}

		my $product_url = product_url($product_ref);	
		
		$response_ref->{files}[0]{url} = $product_url;
		$response_ref->{files}[0]{name} = $product_name;

		# Some apps may be passing a full locale like imagefield=front_pt-BR
		$imagefield =~ s/^(front|ingredients|nutrition|packaging|other)_(\w\w)-.*/$1_$2/;

		# For apps that do not specify the language associated with the image, try to assign one
		if ($imagefield =~ /^(front|ingredients|nutrition|packaging|other)$/) {
			# If the product exists, use the main language of the product
			# otherwise if the product was just created above, we will get the current $lc
			$imagefield .= "_" . $product_ref->{lc};
		}
		
		$response_ref->{imagefield} = $imagefield;

		my $imgid;
		my $debug_string;

		my $imagefield_or_filename = $imagefield;
		(defined $tmp_filename) and $imagefield_or_filename = $tmp_filename;

		my $imgid_returncode = process_image_upload($product_id, $imagefield_or_filename, $User_id, time(), "image upload", \$imgid, \$debug_string);

		$log->debug("after process_image_upload", { imgid => $imgid, imagefield => $imagefield, $imgid_returncode => $imgid_returncode, debug_string => $debug_string }) if $log->is_debug();
		
		$response_ref->{imgid} = $imgid;
		if ($imgid > 0) {
			$response_ref->{files}[0]{thumbnailUrl} = "/images/products/$path/$imgid.$thumb_size.jpg";
		}

		if ($imgid_returncode < 0) {
			$response_ref->{status} = 'status not ok';
			$response_ref->{error} = "error";
			($imgid_returncode == -2) and $response_ref->{error} = "field imgupload_$imagefield not set";
			($imgid_returncode == -3) and $response_ref->{error} = lang("image_upload_error_image_already_exists");
			($imgid_returncode == -4) and $response_ref->{error} = lang("image_upload_error_image_too_small");
			($imgid_returncode == -5) and $response_ref->{error} = lang("image_upload_error_could_not_read_image");

			if (not $code_specified) {
				# for jquery.fileupload-ui.js
				if ($imgid_returncode == -3) {
					$response_ref->{files}[0]{info} = $response_ref->{error};
				}
				else {
					$response_ref->{files}[0]{error} = $response_ref->{error};
				}
			}

			if (defined $debug_string) {
				$response_ref->{debug} = $debug_string;
			}
		}
		else {

			my $image_data_ref = {
				imgid=>$imgid,
				thumb_url=>"$imgid.${thumb_size}.jpg",
				crop_url=>"$imgid.${crop_size}.jpg",
			};

			if ($User{moderator}) {
				$product_ref = retrieve_product($product_id);
				$image_data_ref->{uploader} = $product_ref->{images}{$imgid}{uploader};
				$image_data_ref->{uploaded} = $product_ref->{images}{$imgid}{uploaded_t};
			}

			my $product_name =  remove_tags_and_quote(product_name_brand_quantity($product_ref));
			if ((not defined $product_name) or ($product_name eq "")) {
				$product_name = $code;
			}

			my $product_url = product_url($product_ref);

			$response_ref->{status} = 'status ok';
			$response_ref->{image} = $image_data_ref;

			# Select the image
			if (($imagefield =~ /^(front|ingredients|nutrition|packaging)_/)
				# Changed 2020-03-05: overwrite already selected images
				# and ((not defined $product_ref->{images}{$imagefield}) or ($select_image))
				# Changed 2020-04-20: don't overwrite selected images if the source is the product edit form
				and ((not defined param('source')) or (param('source') ne "product_edit_form") or (not defined $product_ref->{images}{$imagefield}))
				) {
				$log->debug("selecting image", { imgid => $imgid, imagefield => $imagefield}) if $log->is_debug();
				process_image_crop($product_id, $imagefield, $imgid, 0, undef, undef, -1, -1, -1, -1, "full");
			}
			# If the image type is "other" and we don't have a front image, assign it
			# This is in particular for producers that send us many images without specifying their type: assume the first one is the front
			elsif (($imagefield =~ /^other/) and ((not defined $product_ref->{images}{"front_" . $product_ref->{lc}})
				or ((defined $previous_imgid) and ($previous_imgid eq $product_ref->{images}{"front_" . $product_ref->{lc}}{imgid})))
				) {
				$log->debug("selecting front image as we don't have one", { imgid => $imgid, previous_imgid => $previous_imgid, imagefield => $imagefield, front_imagefield => "front_" . $product_ref->{lc}}) if $log->is_debug();
				process_image_crop($product_id, "front_" . $product_ref->{lc}, $imgid, 0, undef, undef, -1, -1, -1, -1, "full");
			}
			else {
				$log->debug("not selecting as front image", { imgid => $imgid, previous_imgid => $previous_imgid, imagefield => $imagefield, front_imagefield => "front_" . $product_ref->{lc},
					front_image => $product_ref->{images}{"front_" . $product_ref->{lc}} }) if $log->is_debug();
			}
		}

		(defined $code) and $response_ref->{files}[0]{code} = $code;
		(defined $code_from_file_name) and $response_ref->{files}[0]{code_from_file_name} = $code_from_file_name;
		(defined $scanned_code) and $response_ref->{files}[0]{scanned_code} = $scanned_code;
		(defined $using_previous_code) and $response_ref->{files}[0]{using_previous_code} = $using_previous_code;

		my $data = encode_json($response_ref);

		$log->debug("JSON data output", { data => $data }) if $log->is_debug();

		print header( -type => 'application/json', -charset => 'utf-8' ) . $data;

	}
	else {

			$log->warn("no image field defined");
			$response_ref->{status} = 'status not ok';
			$response_ref->{error} = "error - imagefield not defined";
			my $data =  encode_json($response_ref);
			print header( -type => 'application/json', -charset => 'utf-8' ) . $data;
	}

}
else {
	$log->warn("no image field defined");
}


exit(0);

