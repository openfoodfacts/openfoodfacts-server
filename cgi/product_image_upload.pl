#!/usr/bin/perl

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

my $type = param('type') || 'add';
my $action = param('action') || 'display';
my $code = normalize_code(param('code'));
my $imagefield = param('imagefield');
my $delete = param('delete');

my $upload_session = int(rand(100000000));

print STDERR "product_image_upload.pl - upload_session: $upload_session - ip: " . remote_addr() . " - type: $type - action: $action - code: $code\n";

my $env = $ENV{QUERY_STRING};

print STDERR "product_image_upload.pl - upload_session: $upload_session - query string : $env - calling init()\n";


ProductOpener::Display::init();

$debug = 1;



print STDERR "product_image_upload.pl - subdomain: $subdomain - original_subdomain: $original_subdomain - upload_session: $upload_session - user: $User_id - code: $code - cc: $cc - lc: $lc - imagefield: $imagefield - ip: " . remote_addr() . "\n";

if ((not defined $code) or ($code eq '')) {
	
	print STDERR "product_image_upload.pl - no code\n";
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
	
	print STDERR "product_image_upload - upload_session: $upload_session- imagefield: $imagefield - delete: $delete\n";
	
	if ($path eq 'invalid') {
		# non numeric code was given
		print STDERR "product_image_upload.pl - invalid code\n";
		my %response = ( status => 'status not ok');
		$response{error} = "error - invalid product code: $code";
		my $data =  encode_json(\%response);		
		print header( -type => 'application/json', -charset => 'utf-8' ) . $data;
		exit(0);		
	}
	
	if ($delete ne 'on') {
	
		my $product_ref = product_exists($code); # returns 0 if not
		
		if (not $product_ref) {
			print STDERR "product_image_upload.pl - upload_session: $upload_session - product code $code does not exist yet, creating product\n";
			$product_ref = init_product($code);
			$product_ref->{interface_version_created} = $interface_version;
			$product_ref->{lc} = $lc;
			store_product($product_ref, "Creating product (image upload)");
		}
		else {
			print STDERR "product_image_upload.pl - upload_session: $upload_session - product code $code already exists\n";
		}
		
		# For apps that do not specify the language associated with the image, try to assign one
		if ($imagefield =~ /^(front|ingredients|nutrition)$/) {
			# If the product exists, use the main language of the product
			# otherwise if the product was just created above, we will get the current $lc
			$imagefield .= "_" . $product_ref->{lc};
		}		
		
		my $imgid;
	
		my $imgid_returncode = process_image_upload($code, $imagefield, $User_id, time(), "image upload", \$imgid);
		
			print STDERR "product_image_upload.pl - upload_session: $upload_session - imgid from process_image_upload: $imgid\n";
		
		
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
		
		print STDERR "product_image_upload - upload_session: $upload_session - JSON data output: $data\n";

		print header( -type => 'application/json', -charset => 'utf-8' ) . $data;

	}
	else {

			print STDERR "product_image_upload - upload_session: $upload_session - no imagefield\n";
			my %response = ( status => 'status not ok');
			$response{error} = "error - imagefield not defined";
			my $data =  encode_json(\%response);		
			print header( -type => 'application/json', -charset => 'utf-8' ) . $data;	

	}

}
else {
	print STDERR "product_image - upload_session: $upload_session - no imgid defined\n";
}


exit(0);

