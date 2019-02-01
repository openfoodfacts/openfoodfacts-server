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
my $imagefield = param('imagefield');
my $delete = param('delete');

local $log->context->{upload_session} = int(rand(100000000));

$log->debug("start", { ip => remote_addr(), type => $type, action => $action, code => $code }) if $log->is_debug();

my $env = $ENV{QUERY_STRING};

$log->debug("calling init()", { query_string => $env });

ProductOpener::Display::init();

$log->debug("parsing code", { subdomain => $subdomain, original_subdomain => $original_subdomain, user => $User_id, code => $code, cc => $cc, lc => $lc, imagefield => $imagefield, ip => remote_addr() }) if $log->is_debug();

if ((not defined $code) or ($code eq '')) {
	
	$log->warn("no code");
	my %response = ( status => 'status not ok');
	$response{error} = "error - missing product code";
	my $data =  encode_json(\%response);		
	print header( -type => 'application/json', -charset => 'utf-8' ) . $data;	
	exit(0);
}

my $interface_version = '20120622';

# Create image directory if needed
if (! -e "$www_root/images") {
	mkdir ("$www_root/images", 0755);
}
if (! -e "$www_root/images/products") {
	mkdir ("$www_root/images/products", 0755);
}

if ($imagefield) {

	my $path = product_path($code);
	
	$log->debug("path determined", { imagefield => $imagefield, path => $path, delete => $delete });
	
	if ($path eq 'invalid') {
		# non numeric code was given
		$log->warn("no code", { code => $code });
		my %response = ( status => 'status not ok');
		$response{error} = "error - invalid product code: $code";
		my $data =  encode_json(\%response);		
		print header( -type => 'application/json', -charset => 'utf-8' ) . $data;
		exit(0);		
	}
	
	if ((not defined $delete) or ($delete ne 'on')) {
	
		my $product_ref = product_exists($code); # returns 0 if not
		
		if (not $product_ref) {
			$log->info("product code does not exist yet, creating product", { code => $code });
			$product_ref = init_product($code);
			$product_ref->{interface_version_created} = $interface_version;
			$product_ref->{lc} = $lc;
			store_product($product_ref, "Creating product (image upload)");
		}
		else {
			$log->info("product code already exists", { code => $code });
		}
		
		# Some apps may be passing a full locale like imagefield=front_pt-BR
		$imagefield =~ s/^(front|ingredients|nutrition)_(\w\w)-.*/$1_$2/;
		
		# For apps that do not specify the language associated with the image, try to assign one
		if ($imagefield =~ /^(front|ingredients|nutrition)$/) {
			# If the product exists, use the main language of the product
			# otherwise if the product was just created above, we will get the current $lc
			$imagefield .= "_" . $product_ref->{lc};
		}		
		
		my $imgid;
	
		my $imgid_returncode = process_image_upload($code, $imagefield, $User_id, time(), "image upload", \$imgid);
		
		$log->info("imgid created", { imgid => $imgid });
		
		
		my $data;

		if ($imgid_returncode < 0) {
			my %response = ( status => 'status not ok', imgid => $imgid_returncode);
			$response{error} = "error";
			($imgid_returncode == -2) and $response{error} = "field imgupload_$imagefield not set";
			($imgid_returncode == -3) and $response{error} = lang("image_upload_error_image_already_exists");
			($imgid_returncode == -4) and $response{error} = lang("image_upload_error_image_too_small");
			($imgid_returncode == -5) and $response{error} = "could not read image";
			
			$data =  encode_json(\%response);	
		}
		else {
		
			my $image_data_ref = {
				imgid=>$imgid,
				thumb_url=>"$imgid.${thumb_size}.jpg",
				crop_url=>"$imgid.${crop_size}.jpg",
			};
			
			
			if ($admin) {
				$product_ref = retrieve_product($code);
				$image_data_ref->{uploader} = $product_ref->{images}{$imgid}{uploader};
				$image_data_ref->{uploaded} = $product_ref->{images}{$imgid}{uploaded_t};
			}
		
			$data =  encode_json({ status => 'status ok',
					image => $image_data_ref,
					imagefield => $imagefield,
			});
			
			# If we don't have a picture for the imagefield yet, assign it
			# (can be changed by the user later if necessary)
			if ((($imagefield =~ /^front/) or ($imagefield =~ /^ingredients/) or ($imagefield =~ /^nutrition/)) and not defined $product_ref->{images}{$imagefield}) {
				process_image_crop($code, $imagefield, $imgid, 0, undef, undef, -1, -1, -1, -1);
			}
		}
		
		$log->debug("JSON data output", { data => $data }) if $log->is_debug();

		print header( -type => 'application/json', -charset => 'utf-8' ) . $data;

	}
	else {

			$log->warn("no image field defined");
			my %response = ( status => 'status not ok');
			$response{error} = "error - imagefield not defined";
			my $data =  encode_json(\%response);		
			print header( -type => 'application/json', -charset => 'utf-8' ) . $data;	

	}

}
else {
	$log->warn("no image field defined");
}


exit(0);

