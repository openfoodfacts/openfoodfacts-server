# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2026 Association Open Food Facts
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
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

=head1 NAME

ProductOpener::APIProductImageUpload - implementation of WRITE API for uploading and deleting images

=head1 DESCRIPTION

=cut

package ProductOpener::APIProductImagesUpload;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

use Log::Any qw($log);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&delete_product_image_api
		&upload_product_image_api
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Config qw/:all/;
use ProductOpener::Users qw/$Org_id $Owner_id $User_id/;
use ProductOpener::Lang qw/$lc/;
use ProductOpener::Products qw/:all/;
use ProductOpener::API
	qw/add_error add_warning check_user_permission customize_response_for_product normalize_requested_code sanitize/;
use ProductOpener::Images qw/:all/;
use ProductOpener::URL qw(format_subdomain);
use ProductOpener::HTTP qw/request_param single_param redirect_to_url/;
use ProductOpener::APIProductWrite qw/update_images_selected/;

use Encode;
use MIME::Base64 qw(decode_base64);
use Clone qw/clone/;
use Data::DeepAccess qw(deep_get deep_set);

sub delete_product_image_api ($request_ref) {

	$log->debug("image_product_delete_api - start", {request => $request_ref}) if $log->is_debug();

	my $response_ref = $request_ref->{api_response};

	my $code = $request_ref->{code};

	# Check the product exists
	my $product_id = product_id_for_owner($Owner_id, $code);
	my $product_ref = retrieve_product($product_id);
	if (not defined $product_ref) {
		$log->error("image_product_delete_api - product not found", {code => $code}) if $log->is_error();
		add_error(
			$response_ref,
			{
				message => {id => "product_not_found"},
				field => {id => "code", value => $code},
				impact => {id => "failure"},
			},
			404
		);
		return;
	}

	# Check that the image exists
	my $imgid = $request_ref->{imgid};
	if (not defined $product_ref->{images}{uploaded}{$imgid}) {
		$log->error("image_product_delete_api - image not found", {code => $code, imgid => $imgid})
			if $log->is_error();
		add_error(
			$response_ref,
			{
				message => {id => "image_not_found"},
				field => {id => "imgid", value => $imgid},
				impact => {id => "failure"},
			},
			404
		);
		return;
	}

	# Check if the user has permission to delete the image
	if (check_user_permission($request_ref, $response_ref, "image_delete")) {
		$log->error("image_product_delete_api - user does not have permission to delete image", {code => $code})
			if $log->is_error();

		my $return_code = delete_uploaded_image_and_associated_selected_images($product_ref, $request_ref->{imgid});

		if ($return_code > 0) {
			store_product($User_id, $product_ref, "Deleted image $imgid");
		}
		else {
			$log->error(
				"image_product_delete_api - error deleting image",
				{code => $code, imgid => $imgid, return_code => $return_code}
			) if $log->is_error();
			add_error(
				$response_ref,
				{
					message => {id => "image_not_found"},
					field => {id => "imgid", value => $imgid},
					impact => {id => "failure"},
				}
			);
		}
	}

	return;
}

=head2 upload_product_image_api($request_ref)

Process API v3 product image upload requests.

=cut

sub upload_product_image_api ($request_ref) {

	$log->debug("image_product_upload_api - start", {request => sanitize($request_ref)}) if $log->is_debug();

	my $response_ref = $request_ref->{api_response};
	my $request_body_ref = $request_ref->{body_json};

	$log->debug("image_product_upload_api - body", {request_body => sanitize($request_body_ref)}) if $log->is_debug();

	my $error = 0;

	my $code = $request_ref->{code};
	my $product_ref;

	if (not defined $request_body_ref) {
		$log->error("image_product_upload_api - missing or invalid input body", {}) if $log->is_error();
		$error = 1;
	}
	elsif (not defined $request_body_ref->{image_data_base64}) {
		$log->error("image_product_upload_api - missing input image", {request_body => $request_body_ref})
			if $log->is_error();
		add_error(
			$response_ref,
			{
				message => {id => "missing_field"},
				field => {id => "image_data_base64"},
				impact => {id => "failure"},
			}
		);
		$error = 1;
	}
	else {

		# Load the product
		($code, my $ai_data_string) = &normalize_requested_code($request_ref->{code}, $response_ref);

		# Check if the code is valid
		if (not is_valid_code($code)) {

			$log->info("invalid code", {code => $code, original_code => $request_ref->{code}}) if $log->is_info();
			add_error(
				$response_ref,
				{
					message => {id => "invalid_code"},
					field => {id => "code", value => $request_ref->{code}},
					impact => {id => "failure"},
				}
			);
			$error = 1;
		}
		else {
			my $product_id = product_id_for_owner($Owner_id, $code);
			$product_ref = retrieve_product($product_id);
		}

	}

	# If we did not get a fatal error, we can upload the image to the product
	if (not $error) {

		if (not defined $product_ref) {
			# The product does not exist yet, we initialize it and it will be saved with the uploaded image
			$product_ref = init_product($User_id, $Org_id, $code, $request_ref->{country});
		}
		else {
			# There is an existing product
			# If the product has a product_type and it is not the product_type of the server, redirect to the correct server
			# unless we are on the pro platform

			if (    (not $server_options{private_products})
				and (defined $product_ref->{product_type})
				and ($product_ref->{product_type} ne $options{product_type}))
			{
				redirect_to_url($request_ref, 307,
						  format_subdomain($request_ref->{subdomain}, $product_ref->{product_type})
						. '/api/v3/product/'
						. $code);
			}
		}

		# Process edit rules

		$log->debug("phase 0 - checking edit rules", {code => $code}) if $log->is_debug();

		my $proceed_with_edit = process_product_edit_rules($product_ref);

		$log->debug("phase 0", {code => $code, proceed_with_edit => $proceed_with_edit}) if $log->is_debug();

		if (not $proceed_with_edit) {

			add_error(
				$response_ref,
				{
					message => {id => "edit_against_edit_rules"},
					field => {id => "product"},
					impact => {id => "failure"},
				},
				403
			);
		}
		else {

			# Update the product
			my $imgid;
			my $debug = '';

			# open a filehandle to the decoded image data
			my $image_data = decode_base64($request_body_ref->{image_data_base64});
			open(my $filehandle, '<', \$image_data);

			my $return_code
				= process_image_upload_using_filehandle($product_ref, $filehandle, $User_id, time(),
				"image upload API v3",
				\$imgid, \$debug);

			# A negative return code means that the image upload failed
			if ($return_code < 0) {
				# -3: we have already received an image with this file size
				# -4: the image is too small
				# -5: the image file cannot be read by ImageMagick

				$response_ref->{result} = {id => "image_not_uploaded"};

				if ($return_code == -3) {
					add_warning(
						$response_ref,
						{
							message => {id => "image_already_uploaded"},
							field => {id => "image_data_base64"},
							impact => {id => "warning"},
						}
					);
				}
				elsif ($return_code == -4) {
					add_error(
						$response_ref,
						{
							message => {id => "image_too_small"},
							field => {id => "image_data_base64"},
							impact => {id => "failure"},
						}
					);
				}
				elsif ($return_code == -5) {
					add_error(
						$response_ref,
						{
							message => {id => "unrecognized_value"},
							field => {id => "image_data_base64"},
							impact => {id => "failure"},
						}
					);
				}
			}
			else {
				$response_ref->{result} = {id => "image_uploaded"};
			}

			# Upload was successful (or we already have the same image), we return an images.uploaded object with the image
			if ($imgid > 0) {
				my $uploaded_image_ref = clone($product_ref->{images}{uploaded}{$imgid});
				# add the imgid to the image object
				$uploaded_image_ref->{imgid} = $imgid;
				deep_set($response_ref, "product", "images", "uploaded", $imgid, $uploaded_image_ref);

				# The API can also be called with a selected object to select the image that has been uploaded
				# If the selected object is not empty, we will update the product with the selected images
				if (defined $request_body_ref->{selected}) {
					my $selected_ref = $request_body_ref->{selected};
					# Add the newly uploaded imgid to the selected images
					foreach my $image_type (keys %$selected_ref) {
						foreach my $image_lc (keys %{$selected_ref->{$image_type}}) {
							$selected_ref->{$image_type}{$image_lc}{imgid} = $imgid;
						}
					}

					# Create the product.images.selected structure expected by update_images_selected
					$request_body_ref->{product} = {
						images => {
							selected => $selected_ref,
						}
					};
					update_images_selected($request_ref, $product_ref, $response_ref);
					deep_set($response_ref, "product", "images", "selected", $product_ref->{images}{selected});
				}
			}
		}
	}

	$log->debug("image_product_upload_api - stop", {request => sanitize($request_ref)}) if $log->is_debug();

	return;
}

1;
