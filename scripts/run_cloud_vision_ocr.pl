#!/usr/bin/perl -w

# This file is part of Product Opener.
# 
# Product Opener
# Copyright (C) 2011-2020 Association Open Food Facts
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

# This script is meant to be called through process_new_image_off.sh, itself run through an icrontab

use Modern::Perl '2017';
use utf8;

binmode(STDOUT, ":encoding(UTF-8)");

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;
use LWP::UserAgent;
use MIME::Base64;
use Log::Any qw($log);
use Log::Any::Adapter 'TAP';

# 1551113262.3302748614028.front_fr.30.jpg

open (my $LOG, ">>", "$data_root/logs/run_cloud_vision_ocr.log");

my $file = $ARGV[0];

my $destination = readlink $file;

if (not defined $destination) {
	$log->error("Error: destination is not a valid symlink to an image file", { file => $file, destination => $destination }) if $log->is_error();
	print $LOG "ERROR: file: $file -> destination: $destination is not a valid symlink to an image file\n";
	exit();
}

my $code;

if ($file =~ /^([^\.]*)\.(\d+)\./) {
	$code = $2;
}

my $path = $destination;
$path =~ s/.*\/images/\/images/;

my $auth = "";
if ($server_domain =~ /^dev\./) {
	$auth = "off:off@";
}

my $image_url = "https://" . $auth . "static." . $server_domain . $path;
my $json_url = $image_url;
$json_url =~ s/\.([^\.]+)$//;
$json_url .= ".json";

my $json_file = $destination;
$json_file =~ s/\.([^\.]+)$//;
$json_file .= ".json";


print $LOG "file: $file destination: $destination code: $code image_url: $image_url json_file: $json_file\n";


my $url = "https://vision.googleapis.com/v1/images:annotate?key=" . $ProductOpener::Config::google_cloud_vision_api_key;
# alpha-vision.googleapis.com/

my $ua = LWP::UserAgent->new();

open (my $IMAGE, "<", $file) || die "Could not read $file: $!\n";
binmode($IMAGE);
local $/;
my $image = <$IMAGE>;
close $IMAGE;

my $api_request_ref = {
	requests => [
		{   features => [
				{ type => 'TEXT_DETECTION' },
				{ type => 'LOGO_DETECTION' },
				{ type => 'LABEL_DETECTION' },
				{ type => 'SAFE_SEARCH_DETECTION' },
				{ type => 'FACE_DETECTION' }
				]
			,
			image => { content => encode_base64($image) }
		}
	]
};
my $json = encode_json($api_request_ref);
				
my $request = HTTP::Request->new(POST => $url);
$request->header( 'Content-Type' => 'application/json' );
$request->content( $json );

my $cloud_vision_response = $ua->request($request);

my $status;
	
if ($cloud_vision_response->is_success) {

	$log->info("request to google cloud vision was successful") if $log->is_info();

	my $json_response = $cloud_vision_response->decoded_content(charset => 'UTF-8');
	
	# my $cloudvision_ref = decode_json($json_response);

	# UTF-8 issue , see https://stackoverflow.com/questions/4572007/perl-lwpuseragent-mishandling-utf-8-response
	$json_response = decode("utf8", $json_response);

	open( my $OUT, ">:encoding(UTF-8)", $json_file )
		or die("Cannot write $json_file: $!\n");
	print $OUT $json_response;
	close $OUT;

	print $LOG "--> cloud vision success\n";
	
	# Call robotoff to process the image and/or json from Cloud Vision
	
	my $robotoff_response = $ua->post( $robotoff_url . "/api/v1/images/import", 
		{
			'barcode' => $code,
			'image_url' => $image_url,
			'ocr_url' => $json_url,
			'server_domain' => $auth . "api." . $server_domain
		}
	);


	if ($robotoff_response->is_success) {
		$log->info("request to robotoff was successful") if $log->is_info();
		print $LOG "--> robotoff success: " . $robotoff_response->decoded_content . "\n";
	}
	else {
		$log->warn("robotoff request not successful", { code => $robotoff_response->code, response => $robotoff_response->message, status_line => $robotoff_response->status_line }) if $log->is_warn();
		print $LOG "--> robotoff error: " . $robotoff_response->status_line . "\n";
	}	
	
	unlink($file);
}
else {
	$log->warn("google cloud vision request not successful", { code => $cloud_vision_response->code, response => $cloud_vision_response->message }) if $log->is_warn();
	print $LOG "--> cloud vision error: $cloud_vision_response->code $cloud_vision_response->message\n";
}

close $LOG;
