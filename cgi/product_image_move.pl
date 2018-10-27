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
my $imgids = param('imgids');
my $move_to = param('move_to_override');
if ($move_to ne 'trash') {
	$move_to = normalize_code($move_to);
}
my $copy_data = param('copy_data_override');

$log->debug("start", { ip => remote_addr(), type => $type, action => $action, code => $code, imgids => $imgids, move_to => $move_to, copy_data => $copy_data }) if $log->is_debug();

my $env = $ENV{QUERY_STRING};

$log->debug("calling init()", { query_string => $env });

ProductOpener::Display::init();

$log->debug("parsing code", { user => $User_id, code => $code, cc => $cc, lc => $lc, ip => remote_addr() }) if $log->is_debug();

if ((not defined $code) or ($code eq '')) {
	
	$log->warn("no code");
	my %response = ( status => 'status not ok');
	$response{error} = "error - missing product code";
	my $data =  encode_json(\%response);		
	print header( -type => 'application/json', -charset => 'utf-8' ) . $data;
	exit(0);
}

if ((not defined $move_to) or ($move_to eq '')) {
	
	$log->warn("no move_to code");
	my %response = ( status => 'status not ok');
	$response{error} = "error - missing move_to product code";
	my $data =  encode_json(\%response);		
	print header( -type => 'application/json', -charset => 'utf-8' ) . $data;
	exit(0);
}

if ($code eq $move_to) {
	
	$log->warn("code == move_to");
	my %response = ( status => 'status not ok');
	$response{error} = "error - cannot move images to same product";
	my $data =  encode_json(\%response);		
	print header( -type => 'application/json', -charset => 'utf-8' ) . $data;
	exit(0);
}



if ((not defined $imgids) or ($imgids eq '')) {
	
	$log->warn("no imgids");
	my %response = ( status => 'status not ok');
	$response{error} = "error - missing imgids";
	my $data =  encode_json(\%response);		
	print header( -type => 'application/json', -charset => 'utf-8' ) . $data;
	exit(0);
}

my $interface_version = '20150804';




my $path = product_path($code);

$log->info("checking path", { imgids => $imgids, move_to => $move_to });

if ($path eq 'invalid') {
	# non numeric code was given
	$log->warn("invalid code", { code => $code });
	my %response = ( status => 'status not ok');
	$response{error} = "error - invalid product code: $code";
	my $data =  encode_json(\%response);		
	print header( -type => 'application/json', -charset => 'utf-8' ) . $data;
	exit(0);		
}

my $product_ref = product_exists($code); # returns 0 if not

if (not $product_ref) {
	$log->warn("product does not exist", { code => $code });
	my %response = ( status => 'status not ok');
	$response{error} = "error - product does not exist: $code";
	my $data =  encode_json(\%response);		
	print header( -type => 'application/json', -charset => 'utf-8' ) . $data;
	exit(0);
}

my %response = ('status' => 'ok');

if ($move_to ne 'trash') {

	my $new_path = product_path($move_to);

	if ($new_path eq 'invalid') {
		# non numeric code was given
		$log->warn("invalid move_to code", { code => $code });
		my %response = ( status => 'status not ok');
		$response{error} = "error - invalid product move_to code: $move_to";
		my $data =  encode_json(\%response);		
		print header( -type => 'application/json', -charset => 'utf-8' ) . $data;
		exit(0);		
	}

	my $new_product_ref = product_exists($move_to); # returns 0 if not
	
	if (not $new_product_ref) {
		$log->info("new product code does not exist yet, creating product", { move_to => $move_to });
		$new_product_ref = init_product($move_to);
		$new_product_ref->{interface_version_created} = $interface_version;
		$new_product_ref->{lc} = $lc;
		
		if ($copy_data eq 'true') {
		
			$log->debug("copying data", { code => $code, move_to => $code });
			
			$product_ref = retrieve_product($code);
			my @fields = qw(product_name generic_name quantity packaging brands categories labels origins manufacturing_places emb_codes link expiration_date purchase_places stores countries allergens states  );

			use Clone 'clone';
			
			foreach my $field (@fields, 'nutrition_data_per', 'serving_size', 'traces', 'ingredients_text','lang','nutriments') {
				if (defined $product_ref->{$field}) {
					$new_product_ref->{$field} = clone($product_ref->{$field});
					
					if (defined $product_ref->{$field . "_tags"}) {
						$new_product_ref->{$field . "_tags"} = clone($product_ref->{$field . "_tags"});
					}
					if (defined $product_ref->{$field . "_hierarchy"}) {
						$new_product_ref->{$field . "_hierarchy"} = clone($product_ref->{$field . "_hierarchy"});
					}	
				}	
			}
		}
		
		store_product($new_product_ref, "Creating product (moving image from product $code");
	}
	else {
		$log->info("new product code already exists", { move_to => $move_to });
	}
	
	$response{url} = product_url($move_to);
	$response{link} = '<a href="' . $response{url} . '">' . $move_to . '</a>';
}

my $error = process_image_move($code, $imgids, $move_to, $User_id);

my $data;


if ($error) {
	$response{error} = $error;
	$response{status} = 'status not ok';
}


	my $product_ref = retrieve_product($code);

	defined $product_ref->{images} or $product_ref->{images} = {};
	
	$response{images} = [];
	
	for (my $imgid = 1; $imgid <= ($product_ref->{max_imgid} + 5); $imgid++) {
		if (defined $product_ref->{images}{$imgid}) {
			my $image_data_ref = {
				imgid => $imgid,
				thumb_url => "$imgid.$thumb_size.jpg",
				crop_url => "$imgid.$crop_size.jpg",
				display_url => "$imgid.$display_size.jpg",
			};
			
			if ($admin) {
				$image_data_ref->{uploader} = $product_ref->{images}{$imgid}{uploader};
				$image_data_ref->{uploaded} = display_date($product_ref->{images}{$imgid}{uploaded_t}) . ""; # trying to convert the object to a scalar
			}
			push @{$response{images}}, $image_data_ref;
		}
	}

# [Mon Mar 21 17:38:40 2016] [error] [Mon Mar 21 17:38:40 2016] -e: encountered object '24 ao\xc3\xbbt 2015 \xc3\xa0 20:32:45 CEST', but neither allow_blessed nor convert_blessed settings are enabled at /home/off/cgi/product_image_move.pl line 211.\n


$data =  encode_json(\%response);	

$log->debug("JSON data output", { data => $data }) if $log->is_debug();

print header( -type => 'application/json', -charset => 'utf-8' ) . $data;


exit(0);

