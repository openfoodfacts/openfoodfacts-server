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
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

=head1 NAME

ProductOpener::ProductImageUpload - add an uploaded image file to a product, finding its barcode if needed

=head1 DESCRIPTION

Used by cgi/product_image_upload.pl (product image upload API v2, and the import photos page of the
producers platform) and by the import of photos from Google Drive folders (ProductOpener::Producers).

This module is loaded by the public site for every image upload: it must not load ProductOpener::Producers
or Minion (see lib/startup_apache2.pl and issue #7695).

=cut

package ProductOpener::ProductImageUpload;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(

		@photos_upload_add_fields
		&import_product_image_file
		&add_field_values_to_product

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/%BASE_DIRS ensure_dir_created_or_die/;
use ProductOpener::Store qw/get_string_id_for_lang/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Lang qw/lang/;
use ProductOpener::Display qw/display_date/;
use ProductOpener::Images
	qw/$valid_image_types_regexp get_code_and_imagefield_from_file_name is_protected_image process_image_crop process_image_upload scan_code/;
use ProductOpener::APIProductWrite qw/update_product_field_api_v2_and_cgi/;
use ProductOpener::Text qw/remove_tags_and_quote/;

use Data::DeepAccess qw(deep_exists);
use Encode qw/encode_utf8/;
use Log::Any qw($log);

=head1 FUNCTIONS

=head2 @photos_upload_add_fields

Fields that producers can add values to for all the products of the photos they upload
(on the import photos page, and when importing photos from a Google Drive folder).

=cut

@photos_upload_add_fields
	= qw(brands categories packaging labels origins manufacturing_places emb_codes purchase_places stores countries teams);

=head2 import_product_image_file ( $args_ref )

Add an image file uploaded by a user (on the producers platform, or through the product image upload API)
to a product.

If the product code is not specified, we try to get it:

=over

=item from the file name (e.g. 3001234567890.front_fr.jpg)

=item by scanning the barcode in the image

=item otherwise by using the code of the previous image (for producers that send a photo of the barcode, followed by photos of the other sides of the product)

=back

The product is created if it does not exist yet. If the image type (front, ingredients etc.) is known, the image is selected.

This function is used by cgi/product_image_upload.pl and by the import of photos from a Google Drive folder.

=head3 Arguments

A hash ref with:

=head4 user_id, org_id, owner_id - the user uploading the image and the owner of the product

=head4 moderator - 1 if the user is a moderator

=head4 lc - language of the interface, used to guess the image type from the file name

=head4 country - country of the request, used if the product is created

=head4 code, imagefield - optional: product code and image field (e.g. front_fr) if they are specified

=head4 filename - name of the uploaded file

=head4 file_path - path of the image file on disk, or:

=head4 filehandle - CGI file handle of the uploaded file (read with single_param("files[]"))

=head4 tmp_file_prefix - prefix of the temporary file in which a CGI uploaded file is copied to scan its barcode

=head4 previous_code, previous_imgid - code and image id of the previous image, if any

=head4 source - "product_edit_form" if the image is uploaded through the product edit form

=head4 add_field_values - optional array ref of hashes with a field and a value, added to the product

=head4 field_values_added_for_codes - hash ref of the codes for which the field values have already been added: field values are added only once per product

=head3 Return value

A hash ref with the response of the product image upload API (status, error, files array with the filename,
code, code_from_file_name, scanned_code, using_previous_code, error or info etc.)

=cut

sub import_product_image_file ($args_ref) {

	my $code = $args_ref->{code};
	my $imagefield = $args_ref->{imagefield};
	my $previous_code = $args_ref->{previous_code};
	my $previous_imgid = $args_ref->{previous_imgid};
	my $user_id = $args_ref->{user_id};
	my $tmp_filename;

	# Producers platform: the input file name is files[]
	# If no code and imagefield is passed, try to guess it from the filename

	my $code_specified = 1;
	my $filename;

	my $using_previous_code;
	my $scanned_code;
	my $code_from_file_name;

	if (not defined $code) {

		$code_specified = 0;

		$filename = $args_ref->{filename} // "";

		($code, $imagefield) = get_code_and_imagefield_from_file_name($args_ref->{lc}, $filename);

		if ($code) {
			$code_from_file_name = $code;
		}
		else {

			if ($filename =~ /\.(gif|jpeg|jpg|png|heic|heif)$/i) {

				$log->debug("scan barcode in image file", {filename => $filename}) if $log->is_debug();

				if (defined $args_ref->{file_path}) {
					$tmp_filename = $args_ref->{file_path};
				}
				elsif (defined $args_ref->{filehandle}) {
					my $file = $args_ref->{filehandle};
					my $extension = lc($1);
					$tmp_filename
						= get_string_id_for_lang("no_language", ($args_ref->{tmp_file_prefix} // '') . '_' . $`);

					ensure_dir_created_or_die($BASE_DIRS{CACHE_TMP});
					open(my $out, ">", "$BASE_DIRS{CACHE_TMP}/$tmp_filename.$extension");
					while (my $chunk = <$file>) {
						print $out $chunk;
					}
					close($out);
					$tmp_filename = "$BASE_DIRS{CACHE_TMP}/$tmp_filename.$extension";
				}

				if (defined $tmp_filename) {
					$code = scan_code($tmp_filename);
					if (defined $code) {
						$code = normalize_code($code);
						$scanned_code = $code;
					}
				}
			}

			# If we have a previous code, use it
			if ((not $code) and (defined $previous_code)) {
				$log->debug("no barcode found in image file, using previous code", {previous_code => $previous_code})
					if $log->is_debug();
				$code = $previous_code;
				$using_previous_code = $previous_code;
			}
		}
	}

	# The image file is on disk: we pass its path instead of the image field to process_image_upload()
	if (defined $args_ref->{file_path}) {
		$tmp_filename = $args_ref->{file_path};
	}

	my $response_ref = {
		files => [
			{
				filename => ($filename // '') . "",    # Make filename a scalar
			}
		],
	};

	if ((not defined $code) or ($code eq '')) {

		$log->warn("no code");
		$response_ref->{status} = 'status not ok';
		$response_ref->{error} = lang("image_upload_error_no_barcode_specified_or_found");
		if (not $code_specified) {
			# for jquery.fileupload-ui.js
			$response_ref->{files}[0]{error} = $response_ref->{error};
		}
		return $response_ref;
	}

	$response_ref->{code} = $code;

	my $product_id = product_id_for_owner($args_ref->{owner_id}, $code);

	my $interface_version = '20120622';

	if (not $imagefield) {

		$log->warn("no image field defined");
		$response_ref->{status} = 'status not ok';
		$response_ref->{error} = "error - imagefield not defined";
		return $response_ref;
	}

	$response_ref->{imagefield} = $imagefield;

	my $path = product_path_from_id($product_id);

	$log->debug("path determined", {imagefield => $imagefield, path => $path});

	if ($path eq 'invalid') {
		# non numeric code was given
		$log->warn("no code", {code => $code});
		$response_ref->{status} = 'status not ok';
		$response_ref->{error} = "error - invalid product code: $code";
		$response_ref->{files}[0]{error} = $response_ref->{error};
		return $response_ref;
	}

	my $product_ref = retrieve_product($product_id);

	if (not $product_ref) {
		$log->info("product code does not exist yet, creating product", {code => $code});
		$product_ref = init_product($user_id, $args_ref->{org_id}, $code, $args_ref->{country});
		$product_ref->{interface_version_created} = $interface_version;
		$product_ref->{lc} = $args_ref->{lc};
		store_product($user_id, $product_ref, "Creating product (image upload)");
	}
	else {
		$log->info("product code already exists", {code => $code});
	}

	my $proceed_with_edit = process_product_edit_rules($product_ref);
	$log->debug("edit rules processed", {proceed_with_edit => $proceed_with_edit}) if $log->is_debug();
	if (not $proceed_with_edit) {
		return {status => 'status not ok - edit against edit rules'};
	}

	my $product_name = remove_tags_and_quote(product_name_brand_quantity($product_ref));
	if ((not defined $product_name) or ($product_name eq "")) {
		$product_name = $code;
	}

	my $product_url = product_url($product_ref);

	$response_ref->{files}[0]{url} = $product_url;
	$response_ref->{files}[0]{name} = $product_name;

	# Some apps may be passing a full locale like imagefield=front_pt-BR
	$imagefield =~ s/^($valid_image_types_regexp)_(\w\w)-.*/$1_$2/;

	# For apps that do not specify the language associated with the image, try to assign one
	if ($imagefield =~ /^($valid_image_types_regexp)$/) {
		# If the product exists, use the main language of the product
		# otherwise if the product was just created above, we will get the current $lc
		$imagefield .= "_" . $product_ref->{lc};
	}

	$response_ref->{imagefield} = $imagefield;

	my $imgid;
	my $debug_string;

	my $imagefield_or_filename = $imagefield;
	(defined $tmp_filename) and $imagefield_or_filename = $tmp_filename;

	my $imgid_returncode
		= process_image_upload($product_ref, $imagefield_or_filename, $user_id, time(), "image upload", \$imgid,
		\$debug_string);

	$log->debug(
		"after process_image_upload",
		{
			imgid => $imgid,
			imagefield => $imagefield,
			imgid_returncode => $imgid_returncode,
			debug_string => $debug_string
		}
	) if $log->is_debug();

	# For backwards compatibility, if we have no imgid (if the image was not uploaded), we return the return code in the imgid field
	$response_ref->{imgid} = $imgid || $imgid_returncode;
	if ((defined $imgid) and ($imgid > 0)) {
		$response_ref->{files}[0]{thumbnailUrl} = "/images/products/$path/$imgid.$thumb_size.jpg";
	}

	if ($imgid_returncode < 0) {
		# Error during upload
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
		# Image uploaded successfully

		my $image_data_ref = {
			imgid => $imgid,
			thumb_url => "$imgid.${thumb_size}.jpg",
			crop_url => "$imgid.${crop_size}.jpg",
		};

		if ($args_ref->{moderator}) {
			$product_ref = retrieve_product($product_id);
			$image_data_ref->{uploader} = $product_ref->{images}{uploaded}{$imgid}{uploader};
			$image_data_ref->{uploaded} = display_date($product_ref->{images}{uploaded}{$imgid}{uploaded_t});
		}

		$response_ref->{status} = 'status ok';
		$response_ref->{image} = $image_data_ref;

		# Select the image
		if ($imagefield =~ /^($valid_image_types_regexp)_(\w\w)$/) {

			my $image_type = $1;
			my $image_lc = $2;
			# Changed 2020-03-05: overwrite already selected images
			# Changed 2020-04-20: don't overwrite selected images if the source is the product edit form
			if (
				(
					   (not defined $args_ref->{source})
					or ($args_ref->{source} ne "product_edit_form")
					or (not deep_exists($product_ref, "images", "selected", $image_type, $image_lc))
				)
				and (not is_protected_image($product_ref, $image_type, $image_lc) or $args_ref->{moderator})

				)
			{
				$log->debug("selecting image", {imgid => $imgid, image_type => $image_type, lc => $image_lc})
					if $log->is_debug();
				process_image_crop($user_id, $product_ref, $image_type, $image_lc, $imgid, undef);
			}
		}
		# If the image type is "other" and we don't have a front image, assign it
		# This is in particular for producers that send us many images without specifying their type: assume the first one is the front
		elsif (
			($imagefield =~ /^other/)
			and (
				(not deep_exists($product_ref, "images", "selected", "front", $product_ref->{lc}))
				or (    (defined $previous_imgid)
					and ($previous_imgid eq $product_ref->{images}{selected}{"front"}{$product_ref->{lc}}{imgid}))
			)
			)
		{
			$log->debug(
				"selecting front image as we don't have one",
				{
					imgid => $imgid,
					previous_imgid => $previous_imgid,
					imagefield => $imagefield,
					front_imagefield => "front_" . $product_ref->{lc}
				}
			) if $log->is_debug();
			process_image_crop($user_id, $product_ref, "front", $product_ref->{lc}, $imgid, undef);
		}
	}

	(defined $code) and $response_ref->{files}[0]{code} = $code;
	(defined $code_from_file_name) and $response_ref->{files}[0]{code_from_file_name} = $code_from_file_name;
	(defined $scanned_code) and $response_ref->{files}[0]{scanned_code} = $scanned_code;
	(defined $using_previous_code) and $response_ref->{files}[0]{using_previous_code} = $using_previous_code;

	# Add field values (e.g. a brand) to the product, once per product
	if (    (defined $args_ref->{add_field_values})
		and (scalar @{$args_ref->{add_field_values}})
		and (not $args_ref->{field_values_added_for_codes}{$code}))
	{
		$args_ref->{field_values_added_for_codes}{$code} = 1;
		add_field_values_to_product($product_id, $args_ref->{add_field_values},
			$user_id, $args_ref->{org_id}, $args_ref->{lc});
	}

	return $response_ref;
}

=head2 add_field_values_to_product ( $product_id, $field_values_ref, $user_id, $org_id, $target_lc )

Add values to tags fields of a product (e.g. add a brand), as done with add_[field] parameters
of the product write API v2 (cgi/product_jqm_multilingual.pl)

=head3 Arguments

=head4 $product_id

=head4 $field_values_ref - array ref of hashes with a field and a value

Fields that are not in @photos_upload_add_fields are ignored.

=head4 $user_id, $org_id

=head4 $target_lc - language of the values

=cut

sub add_field_values_to_product ($product_id, $field_values_ref, $user_id, $org_id, $target_lc) {

	my $product_ref = retrieve_product($product_id);
	return if not defined $product_ref;

	my %allowed_fields = map {$_ => 1} @photos_upload_add_fields;
	my $source = get_source_for_site_and_org($org_id);
	my $added = 0;

	foreach my $field_value_ref (@$field_values_ref) {
		my $field = $field_value_ref->{field};
		my $value = $field_value_ref->{value};
		next if (not defined $field) or (not $allowed_fields{$field}) or (not defined $value) or ($value eq '');

		# update_product_field_api_v2_and_cgi() expects UTF-8 encoded values, as they are when they come from CGI parameters
		update_product_field_api_v2_and_cgi($product_ref, $target_lc, $field, encode_utf8($value), $source, 1);
		$added++;
	}

	return if not $added;

	analyze_and_enrich_product_data($product_ref, {});

	store_product($user_id, $product_ref, "fields added through photos upload on producer platform");

	return;
}

1;
