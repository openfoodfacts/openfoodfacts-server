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

ProductOpener::Images - adds, processes, manages and displays product photos

=head1 DESCRIPTION

C<ProductOpener::Images> is used to:
- upload product images
- select and crop product images
- run OCR on images
- display product images

=head1 Product images on disk

Product images are stored in html/images/products/[product barcode split with slashes]/

For each product, this directory contains:

=over

=item [image number].[extension].orig (e.g. 1.jpg.orig, 2.jpg.orig etc.)

Original images uploaded by users or imported

=item [image number].jpg

Same image saved as JPEG with specific settings, and after some minimal processing (auto orientation, removing EXIF data, flattening PNG images to remove transparency).

Those images are not displayed on the web site (except on the product edit form), but can be selected and cropped.

=item [image number].[100|400].jpg

Same image saved with a maximum width and height of 100 and 400 pixels. Those thumbnails are used in the product edit form to show the available images.

=item [image number].json

OCR output from Google Cloud Vision.

When a new image is uploaded, a symbolic link to it is created in /new_images.
This triggers a script to generate and save the OCR: C<run_cloud_vision_ocr.pl>.

=item [front|ingredients|nutrition|packaging]_[2 letter language code].[product revision].[full|100|200|400].jpg

Cropped and selected image for the front of the product, the ingredients list, the nutrition facts table, and the packaging information / recycling instructions,
in 4 different sizes (full size, 100 / 200 / 400 pixels maximum width or height).

The product revision is a number that is incremented for each change to the product (each image upload and each image selection are also individual changes that
create a new revision).

The selected images are shown on the website, in the app etc.

When a new image is selected for a given field (e.g. ingredients) and language (e.g. French), the existing selected images are kept.
(e.g. we can have ingredients_fr.21.100.jpg and a new ingredients_fr.28.100.jpg).

Previously selected images are shown only when people access old product revisions.

Cropping coordinates for all revisions are stored in the "images" field of the product, so we could regenerate old selected and cropped images on demand.

=back

=cut

package ProductOpener::Images;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&display_search_image_form
		&process_search_image_form

		&get_code_and_imagefield_from_file_name
		&get_imagefield_from_string
		&get_image_type_and_image_lc_from_imagefield
		&is_protected_image
		&process_image_upload
		&process_image_upload_using_filehandle
		&process_image_move
		&delete_uploaded_image_and_associated_selected_images

		&same_image_generation_parameters
		&normalize_generation_ref
		&process_image_crop
		&process_image_unselect

		&scan_code

		&display_select_manage
		&display_select_crop
		&display_select_crop_init

		&get_image_url
		&get_image_in_best_language
		&add_images_urls_to_product
		&data_to_display_image

		&display_image

		&select_ocr_engine
		&extract_text_from_image
		&send_image_to_cloud_vision

		@CLOUD_VISION_FEATURES_FULL
		@CLOUD_VISION_FEATURES_TEXT

		%valid_image_types
		$valid_image_types_regexp

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Store qw/get_string_id_for_lang store_object retrieve_object/;
use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/%BASE_DIRS ensure_dir_created_or_die/;
use ProductOpener::Products qw/:all/;

use CGI qw/:cgi :form escapeHTML/;

use Image::Magick;
use Barcode::ZBar;
use Imager;
use Imager::zxing;
use Image::OCR::Tesseract 'get_ocr';

use ProductOpener::Products qw/:all/;
use ProductOpener::Lang qw/$lc  %Lang lang/;
use ProductOpener::Display qw/:all/;
use ProductOpener::HTTP qw/single_param create_user_agent/;
use ProductOpener::URL qw/format_subdomain/;
use ProductOpener::Users qw/%User/;
use ProductOpener::Text qw/remove_tags_and_quote/;
use ProductOpener::ProductSchemaChanges;    # needed for convert_schema_1001_to_1002_refactor_images_object()
use ProductOpener::Booleans qw/normalize_boolean/;
use ProductOpener::ProductsFeatures qw/feature_enabled/;

use boolean ':all';
use Data::DeepAccess qw(deep_exists deep_get deep_set);
use IO::Compress::Gzip qw(gzip $GzipError);
use Log::Any qw($log);
use Encode;
use JSON::MaybeXS;
use MIME::Base64;
use File::Copy qw/move/;
use Clone qw/clone/;
use boolean;

=head1 SUPPORTED IMAGE TYPES

gif, jpeg, jpf, png, heic

=cut

my $supported_extensions = "gif|jpeg|jpg|png|heic";

=head2 VALID IMAGE TYPES

Depending on the product type, different image types are allowed.
e.g. food, pet food and beauty products have an "ingredients" image type.

=cut

%valid_image_types = (
	front => 1,
	packaging => 1
);

if (feature_enabled("ingredients")) {
	$valid_image_types{ingredients} = 1;
}

if (feature_enabled("nutrition")) {
	$valid_image_types{nutrition} = 1;
}

my $valid_image_types_string = join("|", sort keys %valid_image_types);
$valid_image_types_regexp = qr/$valid_image_types_string/;

=head1 FUNCTIONS

=head2 get_image_type_and_image_lc_from_imagefield ($imagefield)

We used to identify selected images with a field called "imagefield" which was of the form [image type]_[language code].
In some very old products revisions (e.g. from 2012), we had values with only the image type (e.g. "front").

This function splits the field name into its components, and is used to maintain backward compatibility.

=head3 Arguments

=head4 $imagefield e.g. "front_fr"

=head3 Return values

$image_type e.g. "front"
$image_lc e.g. "fr"

=cut

sub get_image_type_and_image_lc_from_imagefield ($imagefield) {

	my $image_type = undef;
	my $image_lc = undef;

	if ($imagefield =~ /^($valid_image_types_regexp)(?:_(\w\w))?$/) {
		$image_type = $1;
		$image_lc = $2;
	}

	return ($image_type, $image_lc);
}

sub display_select_manage ($object_ref) {

	my $id = "manage";

	my $html = <<HTML
<div class=\"select_crop select_manage\" id=\"$id\"></div>
<hr class="floatclear" />
HTML
		;

	return $html;
}

=head2 display_select_crop ($object_ref, $image_type, $image_lc, $language, $request_ref) {

This function is used in the product edit form to display the select cropper with the images that are already uploaded.

=cut

sub display_select_crop ($object_ref, $image_type, $image_lc, $language, $request_ref) {

	my $message = $Lang{"protected_image_message"}{$lc};
	my $id = $image_type . "_" . $image_lc;

	my $note = '';
	if (defined $Lang{"image_" . $image_type . "_note"}{$lc}) {
		$note = "<p class=\"note\">&rarr; " . $Lang{"image_" . $image_type . "_note"}{$lc} . "</p>";
	}

	my $label = $Lang{"image_" . $image_type}{$lc};

	my $html = '';
	if (    is_protected_image($object_ref, $image_type, $image_lc)
		and (not $User{moderator})
		and (not $request_ref->{admin}))
	{
		$html .= <<HTML;
<p>$message</p>
<label for="$id">$label (<span class="tab_language">$language</span>)</label>
<div class=\"select_crop\" id=\"$id\" data-info="protect"></div>
HTML
	}
	else {
		$html .= <<HTML;
	<label for="$id">$label (<span class="tab_language">$language</span>)</label>
$note
<div class=\"select_crop\" id=\"$id\"></div>
<hr class="floatclear" />
HTML
	}

	my @fields = qw(imgid x1 y1 x2 y2);
	foreach my $field (@fields) {
		my $value = "";
		if (defined $object_ref->{"$id.$field"}) {
			$value = $object_ref->{"$id.$field"};
		}
		$html
			.= '<input type="hidden" name="'
			. "${id}_$field"
			. '" id="'
			. "${id}_$field"
			. '" value="'
			. $value . '" />' . "\n";
	}

	my $image_url = '';

	my $image_ref = deep_get($object_ref, "images", "selected", $image_type, $image_lc);

	if (defined $image_ref) {
		$image_ref->{id} = $image_type . "_" . $image_lc;
		$image_url = get_image_url($object_ref, $image_ref, $display_size);
		# Keep only the filename
		$image_url =~ s/.*\///;
	}

	$html
		.= '<input type="hidden" name="'
		. "${id}_display_url"
		. '" id="'
		. "${id}_display_url"
		. '" value="'
		. $image_url . '" />' . "\n";

	return $html;
}

=head2 display_select_crop_init ($object_ref)

This function is used to generate the code to initialize the select cropper in the product edit form with the images that are already uploaded.

=cut

sub display_select_crop_init ($object_ref) {

	$log->debug("display_select_crop_init", {object_ref => $object_ref}) if $log->is_debug();

	my $path = product_path($object_ref);

	# Generate JSON data for uploaded images
	my $uploaded_images_ref = deep_get($object_ref, "images", "uploaded");
	my @images = ();

	if (defined $uploaded_images_ref) {

		foreach my $imgid (
			sort {$uploaded_images_ref->{$a}{uploaded_t} <=> $uploaded_images_ref->{$b}{uploaded_t}}
			keys %$uploaded_images_ref
			)
		{

			my $uploader = $uploaded_images_ref->{$imgid}{uploader};
			my $uploaded_date = display_date($uploaded_images_ref->{$imgid}{uploaded_t});

			push @images,
				{
				imgid => $imgid,
				thumb_url => "$imgid.$thumb_size.jpg",
				crop_url => "$imgid.$crop_size.jpg",
				display_url => "$imgid.$display_size.jpg",
				uploader => "$uploader",
				uploaded => "$uploaded_date",
				};

		}
	}

	my $images_json = JSON::MaybeXS->new->encode(\@images);

	return <<HTML

	\$([]).selectcrop('init_images', $images_json);
	\$(".select_crop").selectcrop('init', {img_path : "//images.$server_domain/images/products/$path/"});
	\$(".select_crop").selectcrop('show');

HTML
		;
}

sub scan_code ($file) {

	my $code = undef;

	# print STDERR "scan_code file: $file\n";

	# obtain image data
	my $magick = Image::Magick->new();
	my $imagemagick_error = $magick->Read($file);
	local $log->context->{file} = $file;

	# ImageMagick can trigger an exception for some images that it can read anyway
	# Exception codes less than 400 are warnings and not errors (see https://www.imagemagick.org/script/perl-magick.php#exceptions )
	# e.g. Exception 365: CorruptImageProfile `xmp' @ warning/profile.c/SetImageProfileInternal/1704
	if (($imagemagick_error) and ($imagemagick_error =~ /(\d+)/) and ($1 >= 400)) {
		$log->warn("cannot read file to scan barcode", {error => $imagemagick_error}) if $log->is_warn();
	}
	else {
		# create a reader/decoder
		my $scanner = Barcode::ZBar::ImageScanner->new();

		# configure the reader/decoder
		$scanner->parse_config("enable");

		# wrap image data
		my $image = Barcode::ZBar::Image->new();
		$image->set_format('Y800');

		for (my $i = 1; $i <= 4; $i++) {

			$image->set_size($magick->Get(qw(columns rows)));
			my $raw = $magick->ImageToBlob(magick => 'GRAY', depth => 8);
			$image->set_data($raw);

			# scan the image for barcodes
			my $n = $scanner->scan_image($image);

			# extract results
			foreach my $symbol ($image->get_symbols()) {

				$code = $symbol->get_data();
				my $type = $symbol->get_type();
				$log->debug("barcode found", {code => $code, type => $type}) if $log->is_debug();
				# print STDERR "scan_code code found: $code\n";

				if (($code !~ /^\d+|(?:[\^(\N{U+001D}\N{U+241D}]|https?:\/\/).+$/)) {
					$code = undef;
					next;
				}
				last;
			}

			if (defined $code) {
				last;
			}

			$magick->Rotate(degrees => 90);
		}
	}

	if (not(defined $code)) {
		my $decoder = Imager::zxing::Decoder->new();
		$decoder->set_formats("DataMatrix|QRCode|MicroQRCode|DataBar|DataBarExpanded");

		my $imager = Imager->new();
		$imager->read(file => $file)
			or die "Cannot read $file: ", $imager->errstr;
		my @results = $decoder->decode($imager);
		# extract results
		foreach my $result (@results) {
			if (not($result->is_valid())) {
				next;
			}

			$code = $result->text();
			my $type = $result->format();
			$log->debug("barcode found", {code => $code, type => $type}) if $log->is_debug();
			# print STDERR "scan_code code found: $code\n";
			if (($code !~ /^\d+|(?:[\^(\N{U+001D}\N{U+241D}]|https?:\/\/).+$/)) {
				$code = undef;
				next;
			}
			last;
		}
	}

	if (defined $code) {
		$code = normalize_code($code);
		# print STDERR "scan_code return code: $code\n";
	}

	return $code;
}

sub display_search_image_form ($id, $request_ref) {

	my $html = '';

	my $product_image_with_barcode = $Lang{product_image_with_barcode}{$lc};
	$product_image_with_barcode =~ s/( |\&nbsp;)?:$//;

	my $template_data_ref = {
		product_image_with_barcode => $product_image_with_barcode,
		id => $id,
	};

	# Do not load jquery file upload twice, if it was loaded by another form

	if ($request_ref->{scripts} !~ /jquery.fileupload.js/) {

		$request_ref->{scripts} .= <<JS
<script type="text/javascript" src="/js/dist/jquery.iframe-transport.js"></script>
<script type="text/javascript" src="/js/dist/jquery.fileupload.js"></script>
<script type="text/javascript" src="/js/dist/load-image.all.min.js"></script>
<script type="text/javascript" src="/js/dist/canvas-to-blob.js"></script>
JS
			;

	}

	$request_ref->{initjs} .= <<JS

\/\/ start off canvas blocks for small screens

    \$('#imgupload_search_$id').fileupload({
		sequentialUploads: true,
        dataType: 'json',
        url: '/cgi/product.pl',
		formData : [{name: 'jqueryfileupload', value: 1}, {name: 'action', value: 'process'}, {name: 'type', value:'search_or_add'}],
		resizeMaxWidth : 2000,
		resizeMaxHeight : 2000,
        done: function (e, data) {
			if (data.result.location) {
				\$(location).attr('href',data.result.location);
			}
			if (data.result.error) {
				\$("#imgsearcherror_$id").html(data.result.error);
				\$("#imgsearcherror_$id").show();
			}
        },
		fail : function (e, data) {
			\$("#imgsearcherror_$id").show();
        },
		always : function (e, data) {
			\$("#progressbar_$id").hide();
			\$("#imgsearchbutton_$id").show();
			\$("#imgsearchmsg_$id").hide();
        },
		start: function (e, data) {
			\$("#imgsearchbutton_$id").hide();
			\$("#imgsearcherror_$id").hide();
			\$("#imgsearchmsg_$id").show();
			\$("#progressbar_$id").show();
			\$("#progressmeter_$id").css('width', "0%");

		},
            sent: function (e, data) {
                if (data.dataType &&
                        data.dataType.substr(0, 6) === 'iframe') {
                    // Iframe Transport does not support progress events.
                    // In lack of an indeterminate progress bar, we set
                    // the progress to 100%, showing the full animated bar:
                    \$("#progressmeter_$id").css('width', "100%");
                }
            },
            progress: function (e, data) {

                   \$("#progressmeter_$id").css('width', parseInt(data.loaded / data.total * 100, 10) + "%");
					\$("#imgsearchdebug_$id").html(data.loaded + ' / ' + data.total);

            }

    });

\/\/ end off canvas blocks for small screens

JS
		;

	process_template('web/common/includes/display_search_image_form.tt.html', $template_data_ref, \$html, $request_ref)
		|| return "template error: " . $tt->error();

	return $html;
}

sub process_search_image_form ($filename_ref) {

	my $imgid = "imgupload_search";
	my $file = undef;
	my $code = undef;
	if ($file = single_param($imgid)) {
		if ($file =~ /\.($supported_extensions)$/i) {

			$log->debug("processing image search form", {imgid => $imgid, file => $file}) if $log->is_debug();

			my $extension = lc($1);
			my $filename = get_string_id_for_lang("no_language", remote_addr() . '_' . $`);

			ensure_dir_created_or_die($BASE_DIRS{CACHE_TMP});
			open(my $out, ">", "$BASE_DIRS{CACHE_TMP}/$filename.$extension");
			while (my $chunk = <$file>) {
				print $out $chunk;
			}
			close($out);

			$code = scan_code("$BASE_DIRS{CACHE_TMP}/$filename.$extension");
			if (defined $code) {
				$code = normalize_code($code);
			}
			${$filename_ref} = "$BASE_DIRS{CACHE_TMP}/$filename.$extension";
		}
	}
	return $code;
}

=head2 get_code_and_imagefield_from_file_name ( $l $filename )

This function is used to guess if an image is the front of the product,
its list of ingredients, or the nutrition facts table, based on the filename.

It is used in particular for bulk upload of photos sent by manufacturers.
The file names have many different formats, but they very often include the barcode of the product,
and sometimes an indication of what the image is.

Producers are advised to use the [front|ingredients|nutrition|packaging]_[language code] format,
but in practice we receive many other names.

The %file_names_to_imagefield_regexps structure below contains some patterns
used to guess what the image is about.

=cut

# the regexps apply to canonicalized strings
# i.e. lowercased / unaccented strings in most European languages
my %file_names_to_imagefield_regexps = (

	en => [["ingredients" => "ingredients"], ["nutrition" => "nutrition"],],
	es => [["ingredientes" => "ingredients"], ["nutricion" => "nutrition"],],
	fr => [["ingredients" => "ingredients"], ["nutrition" => "nutrition"],],
);

sub get_code_and_imagefield_from_file_name ($l, $filename) {

	my $code;
	my $imagefield;

	# codes with spaces
	# 4 LR GROS LOUE_3 251 320 080 419_3D avant.png
	$filename =~ s/(\d) (\d)/$1$2/g;

	# Look for the barcode
	if ($filename =~ /(\d{8}\d*)/) {
		$code = $1;
		# Make sure it's not a date like 20200201..
		# e.g. IMG_20200810_111131.jpg
		if ($filename =~ /(^|[^0-9])20(18|19|(2[0-9]))(0|1)/) {
			$code = undef;
		}
		else {
			$code = normalize_code($code);
		}
	}

	# Check for a specified imagefield

	$filename =~ s/(table|nutrition(_|-)table)/nutrition/i;

	if ($filename =~ /(($valid_image_types_regexp)((_|-)\w\w\b)?)/i) {
		$imagefield = lc($1);
		$imagefield =~ s/-/_/;
	}
	# If the photo file name is just the barcode + some stopwords, assume it is the front image
	# but [code]_2.jpg etc. should not be considered the front image
	elsif (($filename =~ /^\d{8}\d*(-|_|\.| )*(photo|visuel|image)?(-|_|\.| )*\d*\.($supported_extensions)$/i)
		and not($filename =~ /^\d{8}\d*(-|_|\.| )+\d{1,2}\.($supported_extensions)$/i))
	{    # [code] + number between 0 and 99
		$imagefield = "front";
	}
	elsif (defined $file_names_to_imagefield_regexps{$l}) {

		my $filenameid = get_string_id_for_lang($l, $filename);

		foreach my $regexp_ref (@{$file_names_to_imagefield_regexps{$l}}) {
			my $regexp = $regexp_ref->[0];
			if ($filenameid =~ /$regexp/) {
				$imagefield = $regexp_ref->[1];
				last;
			}
		}
	}

	if (not defined $imagefield) {
		$imagefield = "other";
	}

	$log->debug("get_code_and_imagefield_from_file_name",
		{l => $l, filename => $filename, code => $code, imagefield => $imagefield})
		if $log->is_debug();

	return ($code, $imagefield);
}

sub get_imagefield_from_string ($l, $filename) {

	my $imagefield;

	# Check for a specified imagefield

	$filename =~ s/(table|nutrition(_|-)table)/nutrition/i;

	if ($filename =~ /(($valid_image_types_regexp)((_|-)\w\w\b)?)/i) {
		$imagefield = lc($1);
		$imagefield =~ s/-/_/;
	}
	elsif (defined $file_names_to_imagefield_regexps{$l}) {

		my $filenameid = get_string_id_for_lang($l, $filename);

		foreach my $regexp_ref (@{$file_names_to_imagefield_regexps{$l}}) {
			my $regexp = $regexp_ref->[0];
			if ($filenameid =~ /$regexp/) {
				$imagefield = $regexp_ref->[1];
				last;
			}
		}
	}

	if (not defined $imagefield) {
		$imagefield = "other";
	}

	$log->debug("get_imagefield_from_string", {l => $l, filename => $filename, imagefield => $imagefield})
		if $log->is_debug();

	return $imagefield;
}

sub get_selected_image_uploader ($product_ref, $image_type, $image_lc) {

	# Retrieve the product's image data
	my $imgid = deep_get($product_ref, "images", "selected", $image_type, $image_lc, "imgid");

	# Retrieve the uploader of the image
	if (defined $imgid) {
		my $uploader = deep_get($product_ref, "images", "uploaded", $imgid, "uploader");
		return $uploader;
	}

	return;
}

sub is_protected_image ($product_ref, $image_type, $image_lc) {

	my $selected_uploader = get_selected_image_uploader($product_ref, $image_type, $image_lc);
	my $owner = $product_ref->{owner};

	if (    (not $server_options{producers_platform})
		and (defined $owner)
		and (defined $selected_uploader)
		and ($selected_uploader eq $owner))
	{
		return 1;    #image should be protected
	}

	return 0;    # image should not be protected
}

=head2 generate_resized_images ($path, $filename, $image_source, $sizes_ref, @sizes)

This function generates resized images from the original image.

For uploaded images, we resize to 100 and 400 pixels maximum width or height.

For selected images, we resize to 100, 200, and 400 pixels maximum width or height.

=head3 Arguments

=head4 $path

The path to the image directory (e.g. html/images/products/1234567890123/).

=head4 $filename

The name of the image file (without the extension).

=head4 $image_source

The source image object (Image::Magick).

=head4 $sizes_ref

A reference to a hash that will be filled with the sizes of the generated images.

=head4 @sizes

An array of sizes to generate. The sizes are the maximum width or height of the image.

=head3 Return values

The function returns the error code from ImageMagick if there was an error writing the image.

=cut

sub generate_resized_images ($path, $filename, $image_source, $sizes_ref, @sizes) {

	my $full_width = $image_source->Get('width');
	my $full_height = $image_source->Get('height');

	$sizes_ref->{full} = {w => $full_width, h => $full_height};

	my $imagemagick_error;    # returned to caller if we cannot write the resized images

	foreach my $max (@sizes) {

		my ($w, $h) = ($full_width, $full_height);
		if ($w > $h) {
			if ($w > $max) {
				$h = $h * $max / $w;
				$w = $max;
			}
		}
		else {
			if ($h > $max) {
				$w = $w * $max / $h;
				$h = $max;
			}
		}
		my $geometry = $w . 'x' . $h;
		my $img = $image_source->Clone();
		$img->Resize(geometry => "$geometry^");
		$img->Extent(
			geometry => "$geometry",
			gravity => "center"
		);
		_set_magickal_options($img, $w);

		$imagemagick_error = $img->Write("jpeg:$path/$filename.$max.jpg");
		if (($imagemagick_error) and ($imagemagick_error =~ /(\d+)/) and ($1 >= 400))
		{    # ImageMagick returns a string starting with a number greater than 400 for errors
			$log->warn(
				"could not write jpeg",
				{
					path => "jpeg:$path/$filename.$max.jpg",
					error => $imagemagick_error
				}
			) if $log->is_warn();
			last;
		}
		else {
			$log->debug("jpeg written", {path => "jpeg:$path/$filename.$max.jpg"})
				if $log->is_debug();
		}

		$sizes_ref->{$max} = {w => $img->Get('width'), h => $img->Get('height')};
	}

	return $imagemagick_error;
}

=head2 process_image_upload ( $product_ref, $imagefield, $user_id, $time, $comment, $imgid_ref, $debug_string_ref )

Process an image uploaded to a product (from the web site, from the API, or from an import):

- Read the image
- Create a JPEG version
- Create resized versions
- Store the image in the product data

=head3 Arguments

=head4 Product ref $product_ref

=head4 Image field $imagefield

Indicates what the image is and its language, or indicate a path to the image file
(for imports and when uploading an image with a barcode)

Format: [front|ingredients|nutrition|packaging|other]_[2 letter language code]

=head4 User id $user_id

=head4 Timestamp of the image $time

=head4 Comment $comment

=head4 Reference to an image id $img_id

Used to return the number identifying the image to the caller.

=head4 Debug string reference $debug_string_ref

Used to return some debug information to the caller.

=head3 Return values

-2: imgupload field not set
-3: we have already received an image with this file size
-4: the image is too small
-5: the image file cannot be read by ImageMagick

=cut

sub process_image_upload ($product_ref, $imagefield, $user_id, $time, $comment, $imgid_ref, $debug_string_ref) {

	# $time = shift  ->  usually current time (images just uploaded), except for images moved from another product
	# $imgid_ref = shift  ->  to return the imgid (new image or existing image)
	# $debug_string_ref = shift  ->  to return debug information to clients

	$log->debug("process_image_upload", {product_id => $product_ref->{id}, imagefield => $imagefield})
		if $log->is_debug();

	# debug message passed back to apps in case of an error

	$$debug_string_ref = "product_id: $product_ref->{id} - user_id: $user_id - imagefield: $imagefield";

	my $filehandle;

	my $tmp_filename;
	if ($imagefield =~ /\//) {
		# For imports, the imagefield is an absolute path to the image file
		# For images that have already been read by the barcode scanner, the imagefield is also an absolute path to the image file
		$tmp_filename = $imagefield;
		$imagefield = 'search';

		if ($tmp_filename) {
			open($filehandle, "<", "$tmp_filename")
				or $log->error("Could not read file", {path => $tmp_filename, error => $!});
		}
	}
	else {
		# For image uploads (CGI form or API <= v2), the image data is multipart form data encoded field
		$filehandle = single_param('imgupload_' . $imagefield);
		if (!$filehandle) {
			# mobile app may not set language code
			my $old_imagefield = $imagefield;
			$old_imagefield =~ s/_\w\w$//;
			$filehandle = single_param('imgupload_' . $old_imagefield);

			if (!$filehandle) {
				# producers platform: name="files[]"
				$filehandle = single_param("files[]");
			}
		}

		if (!$filehandle) {
			$log->debug("imgupload field not set", {field => "imgupload_$imagefield"}) if $log->is_debug();
			$$debug_string_ref .= " - no image file for field name imgupload_$imagefield";
			return -2;
		}
	}

	return process_image_upload_using_filehandle($product_ref, $filehandle, $user_id, $time, $comment, $imgid_ref,
		$debug_string_ref);
}

=head2 process_image_upload_using_filehandle ($product_ref, $filehandle, $user_id, $time, $comment, $imgid_ref, $debug_string_ref)

This function processes an image uploaded to a product using a file handle.

It is called by:

- the process_image_upload() function above when the image is uploaded with a CGI multipart form data encoded field (product form + API <= v2)
- APIProductImagesUpload.pm for API v3

=head3 Arguments

=head4 Product ref $product_ref

=head4 File handle $filehandle to the image data

=head4 User id $user_id

=head4 Timestamp of the image $time

=head4 Comment $comment

=head4 Reference to an image id $imgid_ref

Used to return the number identifying the image to the caller.

=head4 Debug string reference $debug_string_ref

Used to return some debug information to the caller.

=head3 Return values

-2: imgupload field not set
-3: we have already received an image with this file size
-4: the image is too small
-5: the image file cannot be read by ImageMagick

=cut

sub process_image_upload_using_filehandle ($product_ref, $filehandle, $user_id, $time, $comment, $imgid_ref,
	$debug_string_ref)
{

	local $log->context->{uploader} = $user_id;
	local $log->context->{filehandle} = $filehandle;
	local $log->context->{filename} = $filehandle . "";
	local $log->context->{time} = $time;

	my $bogus_imgid;
	not defined $imgid_ref and $imgid_ref = \$bogus_imgid;

	my $product_id = $product_ref->{id};
	my $path = product_path($product_ref);
	my $imgid = -1;

	my $extension = 'jpg';

	my $file = undef;

	# Check if we have already received this image before
	my $images_ref = retrieve_object("$BASE_DIRS{PRODUCTS}/$path/images");
	defined $images_ref or $images_ref = {};

	my $file_size = -s $filehandle;

	if (($file_size > 0) and (defined $images_ref->{$file_size})) {
		$log->debug(
			"we have already received an image with the same size",
			{file_size => $file_size, imgid => $images_ref->{$file_size}}
		) if $log->is_debug();
		${$imgid_ref} = $images_ref->{$file_size};
		$$debug_string_ref
			.= " - we have already received an image with this file size: $file_size - imgid: $$imgid_ref";
		return -3;
	}

	if ($filehandle) {
		$log->debug("processing uploaded file", {filehandle => $filehandle}) if $log->is_debug();

		# We may have a "blob" without file name and extension
		# extension was initialized to jpg and we will let ImageMagick read it anyway if it's something else.

		if ($filehandle =~ /\.($supported_extensions)$/i) {
			$extension = lc($1);
			$extension eq 'jpeg' and $extension = 'jpg';
		}

		my $filename = get_string_id_for_lang("no_language", remote_addr() . '_' . $`);

		$imgid = ($product_ref->{max_imgid} || 0) + 1;

		# if for some reason the images directories were not created at product creation (it can happen if the images directory's permission / ownership are incorrect at some point)
		# create them

		# Create the directories for the product
		my $target_image_dir = "$BASE_DIRS{PRODUCTS_IMAGES}/$path";
		ensure_dir_created_or_die($target_image_dir);

		my $lock_path = "$target_image_dir/$imgid.lock";
		while ((-e $lock_path) or (-e "$target_image_dir/$imgid.jpg")) {
			$imgid++;
			$lock_path = "$target_image_dir/$imgid.lock";
		}

		mkdir($lock_path, 0755)
			or $log->warn("could not create lock file for the image", {path => $lock_path, error => $!});

		local $log->context->{imgid} = $imgid;
		$log->debug("new imgid: ", {imgid => $imgid, extension => $extension}) if $log->is_debug();

		my $img_orig = "$target_image_dir/$imgid.$extension.orig";
		$log->debug("writing the original image", {img_orig => $img_orig}) if $log->is_debug();
		open(my $out, ">", $img_orig)
			or $log->warn("could not open image path for saving", {path => $img_orig, error => $!});
		while (my $chunk = <$filehandle>) {
			print $out $chunk;
		}
		close($out);

		# Read the image

		my $source = Image::Magick->new;
		my $imagemagick_error = $source->Read($img_orig);
		if (($imagemagick_error) and ($imagemagick_error =~ /(\d+)/) and ($1 >= 400))
		{    # ImageMagick returns a string starting with a number greater than 400 for errors
			$log->error("cannot read image",
				{path => "$target_image_dir/$imgid.$extension", error => $imagemagick_error});
			$$debug_string_ref .= " - could not read image: $imagemagick_error";
			return -5;
		}

		$source->AutoOrient();
		$source->Strip();    #remove orientation data and all other metadata (EXIF)

		# remove the transparency when there is an alpha channel (e.g. in PNG files) by adding a white background
		if ($source->Get('matte')) {
			$log->debug("png file, trying to remove the alpha background") if $log->is_debug();
			my $bg = Image::Magick->new;
			$bg->Set(size => $source->Get('width') . "x" . $source->Get('height'));
			$bg->ReadImage('canvas:white');
			$bg->Composite(compose => 'Over', image => $source);
			$source = $bg;
		}

		my $img_jpg = "$target_image_dir/$imgid.jpg";

		$source->Set('quality', 95);
		$imagemagick_error = $source->Write("jpeg:$img_jpg");
		# We also check for the existence of the image file as sometimes ImageMagick does not return an error
		# but does not write the file (e.g. conversion from pdf to jpg)
		if (($imagemagick_error) or (!-e $img_jpg)) {
			$log->error("cannot write image", {path => $img_jpg, error => $imagemagick_error});
			$$debug_string_ref .= " - could not write image: $imagemagick_error";
			return -5;
		}

		# Check that we don't already have the image
		my $size_orig = -s $img_orig;
		my $size_jpg = -s $img_jpg;

		local $log->context->{img_size_orig} = $size_orig;
		local $log->context->{img_size_jpg} = $size_jpg;

		$$debug_string_ref .= " - size of image file received: $size_orig - saved jpg: $size_jpg";

		$log->debug("comparing existing images with size of new image",
			{img_orig => $img_orig, size_orig => $size_orig, img_jpg => $img_jpg, size_jpg => $size_jpg})
			if $log->is_debug();
		for (my $i = 0; $i < $imgid; $i++) {

			# We did not store original files sizes in images.json and original files in [imgid].[extension].orig before July 2020,
			# but we stored original PNG files before they were converted to JPG in [imgid].png
			# We compare both the sizes of the original files and the converted files

			my @existing_images = ("$target_image_dir/$i.jpg");
			if (-e "$target_image_dir/$i.$extension.orig") {
				push @existing_images, "$target_image_dir/$i.$extension.orig";
			}
			if (($extension ne "jpg") and (-e "$target_image_dir/$i.$extension")) {
				push @existing_images, "$target_image_dir/$i.$extension";
			}

			foreach my $existing_image (@existing_images) {

				my $existing_image_size = -s $existing_image;

				foreach my $size ($size_orig, $size_jpg) {

					$log->debug(
						"comparing image",
						{
							existing_image_index => $i,
							existing_image => $existing_image,
							existing_image_size => $existing_image_size
						}
					) if $log->is_debug();
					if ((defined $existing_image_size) and ($existing_image_size == $size)) {
						$log->debug(
							"image with same size detected",
							{
								existing_image_index => $i,
								existing_image => $existing_image,
								existing_image_size => $existing_image_size
							}
						) if $log->is_debug();
						# check the image was stored inside the
						# product, it is sometimes missing
						# (e.g. during crashes)
						if (deep_exists($product_ref, "images", "uploaded", $i)) {
							$log->debug("unlinking image",
								{imgid => $imgid, file => "$target_image_dir/$imgid.$extension"})
								if $log->is_debug();
							unlink $img_orig;
							unlink $img_jpg;
							rmdir("$target_image_dir/$imgid.lock");
							${$imgid_ref} = $i;
							$$debug_string_ref .= " - we already have an image with this file size: $size - imgid: $i";
							return -3;
						}
						# else {
						# 	print STDERR "missing image $i in product, keeping image $imgid\n";
						# }
					}
				}
			}
		}

		# Check the image is big enough so that we do not get thumbnails from other sites
		if (
			(($source->Get('width') < 640) and ($source->Get('height') < 160))
			and (  (not defined $options{users_who_can_upload_small_images})
				or (not defined $options{users_who_can_upload_small_images}{$user_id}))
			)
		{
			unlink "$target_image_dir/$imgid.$extension";
			rmdir("$target_image_dir/$imgid.lock");
			$$debug_string_ref
				.= " - image too small - width: " . $source->Get('width') . " - height: " . $source->Get('height');
			return -4;
		}

		# Generate resized versions
		my $size_ref = {};
		$imagemagick_error
			= generate_resized_images($target_image_dir, $imgid, $source, $size_ref, $thumb_size, $crop_size);

		if (not $imagemagick_error) {

			# Update the product image data
			$log->debug("update the product image data", {imgid => $imgid, product_id => $product_id})
				if $log->is_debug();

			deep_set(
				$product_ref,
				'images',
				'uploaded',
				$imgid,
				{
					uploader => $user_id,
					uploaded_t => $time,
					sizes => $size_ref,
				}
			);

			if ((not defined $product_ref->{max_imgid}) or ($imgid > $product_ref->{max_imgid})) {
				$product_ref->{max_imgid} = $imgid;
			}
			my $store_comment = "new image $imgid";
			if ((defined $comment) and ($comment ne '')) {
				$store_comment .= ' - ' . $comment;
			}
			$log->debug("storing product", {product_id => $product_id}) if $log->is_debug();
			store_product($user_id, $product_ref, $store_comment);

			# Create a link to the image in /new_images so that it can be batch processed by OCR
			# and computer vision algorithms

			(-e "$BASE_DIRS{CACHE_NEW_IMAGES}") or mkdir("$BASE_DIRS{CACHE_NEW_IMAGES}", 0755);
			my $code = $product_id;
			$code =~ s/.*\///;
			symlink("$target_image_dir/$imgid.jpg",
				"$BASE_DIRS{CACHE_NEW_IMAGES}/" . time() . "." . $code . "." . $imgid . ".jpg");

			# Save the image file size so that we can skip the image before processing it if it is uploaded again
			$images_ref->{$size_orig} = $imgid;
			store_object("$BASE_DIRS{PRODUCTS}/$path/images", $images_ref);
		}
		else {
			# Could not read image
			$$debug_string_ref .= " - could not read image : $imagemagick_error";
			$imgid = -5;
		}

		rmdir("$target_image_dir/$imgid.lock");

		# make sure to close the file so that it does not stay in /tmp forever
		my $tmpfilename = tmpFileName($filehandle);
		$log->debug("unlinking image", {filehandle => $filehandle, tmpfilename => $tmpfilename}) if $log->is_debug();
		unlink($tmpfilename);
	}
	else {
		$log->debug("no image filehandle") if $log->is_debug();
		$$debug_string_ref .= " - no image filehandle";
		$imgid = -2;
	}

	$log->debug("upload processed", {imgid => $imgid}) if $log->is_debug();

	${$imgid_ref} = $imgid;

	return $imgid;
}

=head2 remove_images_by_prefix ( $product_ref, $prefix )

This function removes images files from a product by a given prefix (matching uploaded images or selected images).
The image files are moved to a deleted directory.

=head3 Arguments

=head4 $product_ref

A reference to the product data structure.

=head4 $prefix

The prefix of the images to be removed.

For uploaded images, the prefix is the imgid.

For selected images, the prefix is the image type and language code + the product revision.
 e.g. "ingredients_en.5" or "nutrition_fr.6".

=cut

sub remove_images_by_prefix($product_ref, $prefix) {

	my $code = $product_ref->{code};
	my $path = product_path($product_ref);

	# We move deleted images to the deleted.images dir
	my $images_glob = "$BASE_DIRS{PRODUCTS_IMAGES}/$path/$prefix.*";
	my $deleted_images_dir = "$BASE_DIRS{DELETED_IMAGES}/$code";
	ensure_dir_created_or_die($deleted_images_dir);

	$log->debug(
		"moving images to deleted images directory",
		{
			images_glob => $images_glob,
			destination_dir => $deleted_images_dir
		}
	) if $log->is_debug();

	my @files = glob($images_glob);
	move($_, $deleted_images_dir) for @files;

	return;
}

=head2 delete_uploaded_image_and_associated_selected_images ( $product_ref, $imgid )

This function deletes an uploaded image and its associated selected images.

Note: the corresponding product is not saved by this function, it should be saved by the caller.
We do not save it in this function so that we can delete multiple images and save the updated product only once.

=head3 Arguments

=head4 $product_ref

A reference to the product data structure.

=head4 $imgid

The image id to be deleted.

=head3 Return values

1: success
-1: image not found

=cut

sub delete_uploaded_image_and_associated_selected_images($product_ref, $imgid) {

	# Check if the image exists
	if (not defined $product_ref->{images}{uploaded}{$imgid}) {
		$log->error("image not found", {imgid => $imgid, product_id => $product_ref->{id}})
			if $log->is_error();
		return -1;
	}

	# Uploaded images start with [imgid].
	remove_images_by_prefix($product_ref, $imgid);
	delete $product_ref->{images}{uploaded}{$imgid};

	# If we delete an image, we also unselect the images that were selected / cropped from it
	if (exists $product_ref->{images}{selected}) {
		# Go through all image types and languages
		foreach my $image_type (keys %{$product_ref->{images}{selected}}) {
			foreach my $image_lc (keys %{$product_ref->{images}{selected}{$image_type}}) {
				if ($product_ref->{images}{selected}{$image_type}{$image_lc}{imgid} eq $imgid) {

					my $rev = $product_ref->{images}{selected}{$image_type}{$image_lc}{rev};

					# Unselect the image
					process_image_unselect($product_ref, $image_type, $image_lc);
					$log->debug(
						"Image ${image_type}_${image_lc} unselected because the source image $imgid was deleted", {})
						if $log->is_debug();

					# Delete the associated image files
					my $id = $image_type . '_' . $image_lc;
					remove_images_by_prefix($product_ref, "$id.$rev");
				}
			}
		}
	}

	return 1;
}

=head2 process_image_move ( $user_id, $code, $imgids, $move_to, $ownerid )

This function moves images from one product to another, or to the trash.

=head3 Arguments

=head4 $user_id

The user id of the person moving the image.

=head4 $code

The code of the product from which the image is moved.

=head4 $imgids

The image ids to be moved, in a comma-separated list.

=head4 $move_to

The product code to which the image is moved, or 'trash' if the image is deleted.

=head4 $ownerid

The owner id of the product from which the image is moved.

=head3 Return values

The function returns an error message if there was an error, or undef if the operation was successful.

=cut

sub process_image_move ($user_id, $code, $imgids, $move_to, $ownerid) {

	# move images only to trash or another valid barcode (number)
	if (($move_to ne 'trash') and (not is_valid_code($move_to))) {
		return "invalid barcode number: $move_to";
	}

	my $product_id = product_id_for_owner($ownerid, $code);
	my $move_to_id = product_id_for_owner($ownerid, $move_to);

	$log->debug("process_image_move - start", {product_id => $product_id, imgids => $imgids, move_to_id => $move_to_id})
		if $log->is_debug();

	my $path = product_path_from_id($product_id);

	my $product_ref = retrieve_product($product_id);
	defined $product_ref->{images} or $product_ref->{images} = {};

	# New product to which the images are moved
	my $move_to_product_ref;

	if ($move_to ne "trash") {
		# Retrieve the product to which the images are moved
		$move_to_product_ref = retrieve_product($move_to_id);

		if (not $move_to_product_ref) {
			$log->info("move_to product code does not exist yet, creating product", {code => $move_to_id});
			$move_to_product_ref = init_product($user_id, $ownerid, $move_to_id, "en:world");
			$move_to_product_ref->{lc} = $lc;
			store_product($user_id, $move_to_product_ref, "Creating product (image move)");
		}
	}

	# iterate on each images

	my @image_queue = split(/,/, $imgids);

	while (@image_queue) {

		my $imgid = shift @image_queue;
		next if ($imgid !~ /^\d+$/);

		# check the imgid exists
		if (defined $product_ref->{images}{uploaded}{$imgid}) {

			my $ok = 1;

			my $new_imgid;
			my $debug;

			if ($move_to ne "trash") {
				$ok = process_image_upload(
					$move_to_product_ref,
					"$BASE_DIRS{PRODUCTS_IMAGES}/$path/$imgid.jpg",
					$product_ref->{images}{uploaded}{$imgid}{uploader},
					$product_ref->{images}{uploaded}{$imgid}{uploaded_t},
					"image moved from product $code on $server_domain by $user_id -- uploader: $product_ref->{images}{uploaded}{$imgid}{uploader} - time: $product_ref->{images}{uploaded}{$imgid}{uploaded_t}",
					\$new_imgid,
					\$debug
				);
				if ($ok < 0) {
					$log->error(
						"could not move image to other product",
						{
							source_path => "$BASE_DIRS{PRODUCTS_IMAGES}/$path/$imgid.jpg",
							move_to => $move_to,
							old_code => $code,
							ownerid => $ownerid,
							user_id => $user_id,
							result => $ok
						}
					);
				}
				else {
					$log->debug(
						"moved image to other product",
						{
							source_path => "$BASE_DIRS{PRODUCTS_IMAGES}/$path/$imgid.jpg",
							move_to => $move_to,
							old_code => $code,
							ownerid => $ownerid,
							user_id => $user_id,
							result => $ok
						}
					);
				}
			}
			else {
				$log->debug(
					"moved image to trash",
					{
						source_path => "$BASE_DIRS{PRODUCTS_IMAGES}/$path/$imgid.jpg",
						old_code => $code,
						ownerid => $ownerid,
						user_id => $user_id,
						result => $ok
					}
				);
			}

			# Don't delete images to be moved if they weren't moved correctly
			if ($ok) {
				# Delete images (move them to the deleted.images dir)
				delete_uploaded_image_and_associated_selected_images($product_ref, $imgid);
			}
		}
		else {
			return "imgid $imgid not found in product $product_id";
		}
	}

	store_product($user_id, $product_ref, "Moved images $imgids to $move_to");

	$log->debug("process_image_move - end", {product_id => $product_id, imgids => $imgids, move_to_id => $move_to_id})
		if $log->is_debug();

	return;
}

=head2 same_image_generation_parameters ( $generation_1_ref, $generation_2_ref )

This function checks if the image generation parameters are the same for two images.

It is useful to avoid selecting the same image with the same parameters twice.

=head3 Arguments

=head4 $generation_1_ref

A reference to the first image generation parameters.

=head4 $generation_2_ref

A reference to the second image generation parameters.

=head3 Return values

1: the image generation parameters are the same

0: the image generation parameters are different

=cut

sub same_image_generation_parameters($generation_1_ref, $generation_2_ref) {

	# Notes: we can be passed undef hashes, empty hashes, or hashes with undef values
	# We want to check that the existing and defined keys in one hash are the same as the other

	# Normalized structures:
	my %keys1 = ();
	if (defined $generation_1_ref) {
		foreach my $key (keys %{$generation_1_ref}) {
			if (defined $generation_1_ref->{$key}) {
				$keys1{$key} = 1;
			}
		}
	}
	my %keys2 = ();
	if (defined $generation_2_ref) {
		foreach my $key (keys %{$generation_2_ref}) {
			if (defined $generation_2_ref->{$key}) {
				$keys2{$key} = 1;
			}
		}
	}

	# Check that the keys are the same
	foreach my $key (keys %keys1) {
		if ((not defined $keys2{$key}) or ($keys1{$key} ne $keys2{$key})) {
			return 0;
		}
	}
	foreach my $key (keys %keys2) {
		if ((not defined $keys1{$key}) or ($keys2{$key} ne $keys1{$key})) {
			return 0;
		}
	}

	return 1;
}

=head2 normalize_generation_ref ( $generation_ref )

This function normalizes the generation_ref so that we store only useful values.

- If the image is not rotated, we don't store the angle.
- If the image is not cropped, we don't store the coordinates.
- If the image is not normalized, we don't store the normalize value.
- If the image is not processed white magic, we don't store the white magic value.

If generation_ref is empty, we return an undef value

=head3 Arguments

=head4 $generation_ref

A reference to the image generation parameters.

=head3 Return values

A reference to the normalized generation_ref.

Or undef if the generation_ref is empty.

=cut

sub normalize_generation_ref($generation_ref) {

	my $new_generation_ref = {};

	if (defined $generation_ref) {
		if ((defined $generation_ref->{angle}) and ($generation_ref->{angle} % 360 != 0)) {
			$new_generation_ref->{angle} = $generation_ref->{angle} % 360;    # Force integer
		}
		# Keep the boolean values only if they are true
		if ((defined $generation_ref->{normalize}) and (isTrue($generation_ref->{normalize}))) {
			$new_generation_ref->{normalize} = true;
		}
		if ((defined $generation_ref->{white_magic}) and (isTrue($generation_ref->{white_magic}))) {
			$new_generation_ref->{white_magic} = true;
		}
		# When the image is not cropped, we can have 0 or -1 for all coordinates
		if (    (defined $generation_ref->{x1})
			and (defined $generation_ref->{y1})
			and (defined $generation_ref->{x2})
			and (defined $generation_ref->{y2})
			and (($generation_ref->{x1} != $generation_ref->{x2}) and ($generation_ref->{y1} != $generation_ref->{y2})))
		{
			$new_generation_ref->{coordinates_image_size}
				= ($generation_ref->{coordinates_image_size} || $crop_size) . '';    # Force string
																					 # Also make sure we store integers
			$new_generation_ref->{x1} = int($generation_ref->{x1});
			$new_generation_ref->{y1} = int($generation_ref->{y1});
			$new_generation_ref->{x2} = int($generation_ref->{x2});
			$new_generation_ref->{y2} = int($generation_ref->{y2});
		}
	}

	if (scalar keys %{$new_generation_ref} == 0) {
		return;
	}
	return $new_generation_ref;
}

=head2 process_image_crop ( $user_id, $product_ref, $image_type, $image_lc, $imgid, $angle, $normalize, $white_magic, $x1, $y1, $x2, $y2, $coordinates_image_size )

Select and possibly crop an uploaded image to represent the front, ingredients, nutrition or packaging image in a specific language.

=head2 Return values

 1: crop done
-1: image not found
-2: image cannot be read

=cut

sub process_image_crop ($user_id, $product_ref, $image_type, $image_lc, $imgid, $generation_ref) {
	my $product_id = $product_ref->{_id};
	my $id = $image_type . "_" . $image_lc;

	$log->debug(
		"process_image_crop - start",
		{
			product_id => $product_id,
			imgid => $imgid,
			generation_ref => $generation_ref,
		}
	) if $log->is_debug();

	# Assign values from the generation_ref
	my $angle = $generation_ref->{angle} || 0;
	my $normalize = normalize_boolean($generation_ref->{normalize});
	my $white_magic = normalize_boolean($generation_ref->{white_magic});
	my $coordinates_image_size = $generation_ref->{coordinates_image_size} || $crop_size;
	my $x1 = $generation_ref->{x1} || -1;
	my $y1 = $generation_ref->{y1} || -1;
	my $x2 = $generation_ref->{x2} || -1;
	my $y2 = $generation_ref->{y2} || -1;

	# The crop coordinates used to be in reference to a smaller image (400x400)
	# -> $coordinates_image_size = $crop_size
	# they are now in reference to the full image
	# -> $coordinates_image_size = "full"

	# The new product_multilingual.pl form will set $coordinates_image_size to "full"
	# the current Android app will not send it, and it will send coordinates related to the ".400" image
	# that has a max width and height of 400 pixels

	# There was an issue saving coordinates_image_size for some products
	# if any coordinate is above the $crop_size, then assume it was on the full size

	if (($coordinates_image_size eq 'full') and (($x2 > $crop_size) or ($y2 > $crop_size))) {
		$coordinates_image_size = "full";
		$log->debug(
			"process_image_crop - coordinates_image_size not set or set to crop_size and x2 or y2 greater than crop_size, setting to full",
			{generation_ref => $generation_ref, coordinates_image_size => $coordinates_image_size}
		) if $log->is_debug();
	}

	my $path = product_path_from_id($product_id);

	# Check that we are not selecting an image that is already selected with the same source image and selection parameters
	my $already_selected_image_ref = deep_get($product_ref, "images", "selected", $image_type, $image_lc);
	if (    (defined $already_selected_image_ref)
		and ($already_selected_image_ref->{imgid} == $imgid)
		and same_image_generation_parameters($already_selected_image_ref->{generation}, $generation_ref))
	{

		$log->debug("process_image_crop - image already selected with same imgid and selection parameters")
			if $log->is_debug();
		# We don't consider it an error, but we do not generate a new selected image
		return 1;
	}

	my $code = $product_id;
	$code =~ s/.*\///;

	my $rev = $product_ref->{rev} + 1;    # For naming images

	my $source_path = "$BASE_DIRS{PRODUCTS_IMAGES}/$path/$imgid.jpg";

	local $log->context->{code} = $code;
	local $log->context->{product_id} = $product_id;
	local $log->context->{id} = $id;
	local $log->context->{imgid} = $imgid;
	local $log->context->{source_path} = $source_path;

	$log->trace("cropping image") if $log->is_trace();

	# Check if the image exists in the uploaded images
	if (not defined $product_ref->{images}{uploaded}{$imgid}) {
		$log->error("image not found", {product_id => $product_id, imgid => $imgid}) if $log->is_error();
		return -1;
	}

	my $source = Image::Magick->new;
	my $imagemagick_error = $source->Read($source_path);

	# Check that we could read the image
	if (($imagemagick_error) and ($imagemagick_error =~ /(\d+)/) and ($1 >= 400)) {
		$log->error("cannot read image", {path => $source_path, error => $imagemagick_error}) if $log->is_error();
		return -2;
	}

	($imagemagick_error) and $log->error("cannot read image", {path => $source_path, error => $imagemagick_error});

	if ($angle != 0) {
		$source->Rotate($angle);
	}

	# Crop the image
	my $ow = $source->Get('width');
	my $oh = $source->Get('height');
	my $w = $product_ref->{images}{uploaded}{$imgid}{sizes}{$coordinates_image_size}{w};
	my $h = $product_ref->{images}{uploaded}{$imgid}{sizes}{$coordinates_image_size}{h};

	if (($angle % 180) == 90) {
		my $z = $w;
		$w = $h;
		$h = $z;
	}

	#print STDERR "image_crop.pl - source_path: $source_path - product_id: $product_id - imgid: $imgid - crop_size: $crop_size - x1: $x1, y1: $y1, x2: $x2, y2: $y2, w: $w, h: $h\n";

	$log->trace("calculating geometry",
		{crop_size => $crop_size, x1 => $x1, y1 => $y1, x2 => $x2, y2 => $y2, w => $w, h => $h})
		if $log->is_trace();

	my $ox1 = int($x1 * $ow / $w);
	my $oy1 = int($y1 * $oh / $h);
	my $ox2 = int($x2 * $ow / $w);
	my $oy2 = int($y2 * $oh / $h);

	my $nw = $ox2 - $ox1;    # new width
	my $nh = $oy2 - $oy1;

	my $geometry = "${nw}x${nh}\+${ox1}\+${oy1}";
	$log->debug("geometry calculated",
		{geometry => $geometry, ox1 => $ox1, oy1 => $oy1, ox2 => $ox2, oy2 => $oy2, w => $w, h => $h})
		if $log->is_debug();
	if ($nw > 0) {    # image not cropped
		my $imagemagick_error = $source->Crop(geometry => $geometry);
		($imagemagick_error)
			and $log->error("could not crop to geometry", {geometry => $geometry, error => $imagemagick_error});
	}

	# add auto trim to remove white borders (e.g. from some producers that send us images with white borders)

	$source->Trim();

	$nw = $source->Get('width');
	$nh = $source->Get('height');

	$geometry =~ s/\+/-/g;

	my $filename = "$id.$imgid";

	if (isTrue($white_magic)) {
		$filename .= ".white";

		my $image = $source;

		$log->debug("magic") if $log->is_debug();

		$image->Normalize(channel => 'RGB');

		my $w = $image->Get('width');
		my $h = $image->Get('height');
		my $background = Image::Magick->new();
		$background->Set(size => '2x2');
		my $imagemagick_error = $background->ReadImage('xc:white');
		my @rgb;
		@rgb = $image->GetPixel(x => 0, y => 0);
		$background->SetPixel(x => 0, y => 0, color => \@rgb);

		@rgb = $image->GetPixel(x => $w - 1, y => 0);
		$background->SetPixel(x => 1, y => 0, color => \@rgb);

		@rgb = $image->GetPixel(x => 0, y => $h - 1);
		$background->SetPixel(x => 0, y => 1, color => \@rgb);

		@rgb = $image->GetPixel(x => $w - 1, y => $h - 1);
		$background->SetPixel(x => 1, y => 1, color => \@rgb);

		$background->Resize(geometry => "${w}x${h}!");

		my $bg_path = "$BASE_DIRS{PRODUCTS_IMAGES}/$path/$imgid.${crop_size}.background.jpg";
		$log->debug("writing background image to file", {width => $background->Get('width'), path => $bg_path})
			if $log->is_debug();
		$imagemagick_error = $background->Write("jpeg:${bg_path}");
		$imagemagick_error
			and $log->error("could write background image", {path => $bg_path, error => $imagemagick_error});

		#$image->Negate();
		#$background->Modulate(brightness=>95);
		#$background->Negate();
		#$imagemagick_error = $image->Composite(image=>$background, compose=>"Divide");

		#$background->Modulate(brightness=>130);
		$imagemagick_error = $image->Composite(image => $background, compose => "Minus");
		$imagemagick_error and $log->error("magic composide failed", {error => $imagemagick_error});

		$image->Negate();

		# Remove dark corners
		if (1) {
			$imagemagick_error
				= $image->FloodfillPaint(x => 1, y => 1, fill => "#ffffff", fuzz => "5%", bordercolor => "#ffffff");
			$imagemagick_error = $image->FloodfillPaint(
				x => $w - 1,
				y => 1,
				fill => "#ffffff",
				fuzz => "5%",
				bordercolor => "#ffffff"
			);
			$imagemagick_error = $image->FloodfillPaint(
				x => 1,
				y => $h - 1,
				fill => "#ffffff",
				fuzz => "5%",
				bordercolor => "#ffffff"
			);
			$imagemagick_error = $image->FloodfillPaint(
				x => $w - 1,
				y => $h - 1,
				fill => "#ffffff",
				fuzz => "5%",
				bordercolor => "#ffffff"
			);
		}
		elsif (0) {    # use trim instead
					   # $imagemagick_error = $image->Trim(fuzz=>"5%"); # fuzz factor does not work...
		}

		$imagemagick_error and $log->error("could not floodfill", {error => $imagemagick_error});

	}

	if (isTrue($normalize)) {
		$source->Normalize(channel => 'RGB');
	}

	# Keep only one image, and overwrite previous images
	# ! cached images... add a version number
	$filename = $id . "." . $rev;

	_set_magickal_options($source, undef);
	my $full_path = "$BASE_DIRS{PRODUCTS_IMAGES}/$path/$filename.full.jpg";
	local $log->context->{full_path} = $full_path;
	$imagemagick_error = $source->Write("jpeg:${full_path}");
	($imagemagick_error)
		and $log->error("could not write JPEG file", {path => $full_path, error => $imagemagick_error});

	# Re-read cropped image
	my $cropped_source = Image::Magick->new;
	$imagemagick_error = $cropped_source->Read($full_path);
	($imagemagick_error)
		and $log->error("could not re-read the cropped image", {path => $full_path, error => $imagemagick_error});

	my $img2 = $cropped_source->Clone();
	my $window = $nw;
	($nh > $nw) and $window = $nh;
	$window = int($window / 3) + 1;

	$log->debug("generating resized versions") if $log->is_debug();

	# Generate resized versions

	my $sizes_ref = {};
	generate_resized_images("$BASE_DIRS{PRODUCTS_IMAGES}/$path/",
		$filename, $cropped_source, $sizes_ref, $thumb_size, $small_size, $display_size);

	# Create a new $generation_ref, so that we can put only values we want to keep
	my $new_generation_ref = normalize_generation_ref(
		{
			angle => $angle,
			x1 => $x1,
			y1 => $y1,
			x2 => $x2,
			y2 => $y2,
			coordinates_image_size => $coordinates_image_size,
			normalize => $normalize,
			white_magic => $white_magic,
		}
	);

	my $image_ref = {
		imgid => $imgid,
		rev => $rev,
		sizes => $sizes_ref
	};

	if (defined $new_generation_ref) {
		$image_ref->{generation} = $new_generation_ref;
	}

	# Update the product image data
	deep_set($product_ref, "images", "selected", $image_type, $image_lc, $image_ref);

	store_product($user_id, $product_ref, "new image $id : $imgid.$rev");

	$log->trace("image crop done") if $log->is_trace();

	return 1;
}

sub process_image_unselect ($product_ref, $image_type, $image_lc) {
	local $log->context->{product_id} = $product_ref->{product}{_id};
	local $log->context->{image_type} = $image_type;
	local $log->context->{image_lc} = $image_lc;

	$log->debug("unselecting image") if $log->is_debug();

	if (deep_exists($product_ref, "images", "selected", $image_type, $image_lc)) {
		delete $product_ref->{images}{selected}{$image_type}{$image_lc};
	}

	# Delete the image_type key if there are no languages left
	if (   (not defined $product_ref->{images}{selected}{$image_type})
		or (scalar keys %{$product_ref->{images}{selected}{$image_type}} == 0))
	{
		delete $product_ref->{images}{selected}{$image_type};
	}

	$log->debug("unselected image") if $log->is_debug();
	return;
}

sub _set_magickal_options ($magick, $width) {

	# https://www.smashingmagazine.com/2015/06/efficient-image-resizing-with-imagemagick/

	if (defined $width) {
		$magick->Set(thumbnail => $width);
	}

	$magick->Set(filter => 'Triangle');
	$magick->Set(support => 2);
	$magick->Set(unsharp => '0.25x0.25+8+0.065');
	$magick->Set(dither => 'None');
	$magick->Set(posterize => 136);
	$magick->Set(quality => 82);
	$magick->Set('jpeg:fancy-upsampling' => 'off');
	$magick->Set('png:compression-filter' => 5);
	$magick->Set('png:compression-level' => 9);
	$magick->Set('png:compression-strategy' => 1);
	$magick->Set('png:exclude-chunk' => 'all');
	$magick->Set(interlace => 'none');
	# $magick->Set(colorspace => 'sRGB');
	$magick->Strip();

	return;
}

=head2 get_image_url ($product_ref, $image_ref, $size)

Return the URL of the image in the requested size.

Note: $image_ref in selected.images.[image type].[image code] does not contain the id field with the image type and language code (which are keys)
It must be added to the image_ref before calling this function.

=cut

sub get_image_url ($product_ref, $image_ref, $size) {

	my $path = product_path($product_ref);
	my $rev = $image_ref->{rev};
	my $id = $image_ref->{id};    # contains [image_type]_[lc]
	return unless ((defined $rev) && (defined $id));

	my $url = "$images_subdomain/images/products/$path/$id.$rev.$size.jpg";

	return $url;
}

=head2 get_image_in_best_language ($product_ref, $image_type, $target_lc)

We return the image object in the best language available for the image type,
in the order of preference:
- $target_lc
- main language of the product
- English
- any other available language (if any), in alphabetical order

=head3 Arguments

- $product_ref: the product reference
- $image_type: the image type (front, ingredients, nutrition, packaging)
- $target_lc: the target language code
- $image_lc_ref: a reference to return the language code of the image (optional)

=head3 Return values

- the image reference in the best language available, with an added "id"
  field containing the image type and language code (e.g. "front_en")

The language code of the best language is set in $image_lc_ref (if provided)

=cut

sub get_image_in_best_language ($product_ref, $image_type, $target_lc, $image_lc_ref = undef) {

	my @languages = ($target_lc, $product_ref->{lang} || $product_ref->{lc}, 'en');

	my $image_ref;
	my $image_lc;

	foreach my $language (@languages) {
		$image_ref = deep_get($product_ref, "images", "selected", $image_type, $language);
		if (defined $image_ref) {
			$image_lc = $language;
			last;
		}
	}

	if (not defined $image_ref) {
		# No image found in the preferred languages, we try to find one in any other language
		my $selected_images_ref = deep_get($product_ref, "images", "selected", $image_type);
		if (defined $selected_images_ref) {
			foreach my $language (sort keys %{$selected_images_ref}) {
				$image_ref = $selected_images_ref->{$language};
				$image_lc = $language;
				last;
			}
		}
	}

	$log->debug("get_image_in_best_language",
		{image_type => $image_type, target_lc => $target_lc, image_lc => $image_lc, image_ref => $image_ref})
		if $log->is_debug();

	if (defined $image_ref) {
		# The product image object does not contain the image_type and language code
		# as they are specified as keys in the images.selected hash
		# So we create a clone and add an id field containing [image_type]_[lc] to the image object so that we can later construct the image filename
		my $image_clone_ref = clone($image_ref);
		$image_clone_ref->{id} = $image_type . "_" . $image_lc;

		# Return the language of the image that was selected
		if (defined $image_lc_ref) {
			$$image_lc_ref = $image_lc;
		}

		return ($image_clone_ref);
	}
	return;
}

=head2 add_images_urls_to_product ($product_ref, $target_lc, $specific_image_type = undef)

Add fields like image_[front|ingredients|nutrition|packaging]_[url|small_url|thumb_url] to a product object.

If it exists, the image for the target language will be returned, otherwise we will return the image
in the main language of the product.

=head3 Parameters

=head4 $product_ref

Reference to a complete product a subfield.

=head4 $target_lc

2 language code of the preferred language for the product images.

=head4 $specific_image_type

Optional parameter to specify the type of image to add. Default is to add all types.

=cut

sub add_images_urls_to_product ($product_ref, $target_lc, $specific_image_type = undef) {

	if (defined $product_ref->{images}) {

		# If we do not have the "uploaded" or "selected" key, we may be getting an image object with an old schema
		# e.g. when we get partial product data from MongoDB or off-query
		# when reading a full product with retrieve_product(), the conversion should already have been done
		# try to convert it to the new schema
		if (not defined $product_ref->{images}{uploaded} and not defined $product_ref->{images}{selected}) {
			ProductOpener::ProductSchemaChanges::convert_schema_1001_to_1002_refactor_images_object($product_ref);
		}

		my $images_subdomain = format_subdomain('images');

		my $path = product_path($product_ref);

		# If $image_type is specified (e.g. "front" when we display a list of products), only compute the image for this type
		my @image_types;
		if (defined $specific_image_type) {
			@image_types = ($specific_image_type);
		}
		else {
			@image_types = ('front', 'ingredients', 'nutrition', 'packaging');
		}

		foreach my $image_type (@image_types) {

			# Compute the URLs for the best image
			my $image_ref = get_image_in_best_language($product_ref, $image_type, $target_lc);

			if (defined $image_ref) {

				$product_ref->{"image_" . $image_type . "_url"}
					= get_image_url($product_ref, $image_ref, $display_size);

				$product_ref->{"image_" . $image_type . "_small_url"}
					= get_image_url($product_ref, $image_ref, $small_size);

				$product_ref->{"image_" . $image_type . "_thumb_url"}
					= get_image_url($product_ref, $image_ref, $thumb_size);

				if ($image_type eq 'front') {
					# front image is product image
					$product_ref->{image_url} = $product_ref->{"image_" . $image_type . "_url"};
					$product_ref->{image_small_url} = $product_ref->{"image_" . $image_type . "_small_url"};
					$product_ref->{image_thumb_url} = $product_ref->{"image_" . $image_type . "_thumb_url"};
				}

				# Also build selected_images with URLs for each language for which we have images
				# compute selected image for each product language
				foreach my $image_lc (keys %{$product_ref->{images}{selected}{$image_type}}) {
					# The product image object does not contain the image_type and language code
					# as they are specified as keys in the images.selected hash
					# So we create a clone and add an id field containing [image_type]_[lc] to the image object so that we can later construct the image filename
					my $selected_image_ref = clone($product_ref->{images}{selected}{$image_type}{$image_lc});
					$selected_image_ref->{id} = $image_type . "_" . $image_lc;
					$product_ref->{selected_images}{$image_type}{display}{$image_lc}
						= get_image_url($product_ref, $selected_image_ref, $display_size);
					$product_ref->{selected_images}{$image_type}{small}{$image_lc}
						= get_image_url($product_ref, $selected_image_ref, $small_size);
					$product_ref->{selected_images}{$image_type}{thumb}{$image_lc}
						= get_image_url($product_ref, $selected_image_ref, $thumb_size);
				}
			}

		}

	}

	return;
}

=head2 data_to_display_image ( $product_ref, $image_type, $target_lc )

Generates a data structure to display a product image.

The resulting data structure can be passed to a template to generate HTML or the JSON data for a knowledge panel.

=head3 Arguments

=head4 Product reference $product_ref

=head4 Image type $image_type: one of [front|ingredients|nutrition|packaging]

=head4 Language code $target_lc

=head3 Return values

- Reference to a data structure with needed data to display.
- undef if no image is available for the requested image type

=cut

sub data_to_display_image ($product_ref, $image_type, $target_lc) {

	my $image_lc;
	my $image_ref = get_image_in_best_language($product_ref, $image_type, $target_lc, \$image_lc);
	my $image_data_ref;

	if (defined $image_ref) {
		my $id = $image_ref->{id};
		my $alt = remove_tags_and_quote($product_ref->{product_name}) . ' - ' . lang($image_type . '_alt');

		if ($image_lc ne $target_lc) {
			$alt .= ' - ' . $image_lc;
		}

		$image_data_ref = {
			type => $image_type,
			lc => $image_lc,
			alt => $alt,
			sizes => {},
			id => $id,
		};

		foreach my $size ($thumb_size, $small_size, $display_size, "full") {
			if (defined $image_ref->{sizes}{$size}) {
				$image_data_ref->{sizes}{$size} = {
					url => get_image_url($product_ref, $image_ref, $size),
					w => $image_ref->{sizes}{$size}{w},
					h => $image_ref->{sizes}{$size}{h},
				};
			}
		}
	}

	return $image_data_ref;
}

=head2 display_image ( $product_ref, $image_type, $target_lc, $size )

Generate the HTML code to display a product image.

=head3 Arguments

=head4 Product reference $product_ref

=head4 Image type $image_type: one of [front|ingredients|nutrition|packaging]

=head4 Language code $target_lc

=head4 Size $size: one of $thumb_size, $small_size, $display_size

=head3 Return values

- HTML code to display the image

=cut

sub display_image ($product_ref, $image_type, $target_lc, $size) {

	my $html = '';

	my $image_lc;
	my $image_ref = get_image_in_best_language($product_ref, $image_type, $target_lc, \$image_lc);

	my $image_url;

	if (defined $image_ref) {
		$image_url = get_image_url($product_ref, $image_ref, $size);
	}
	# For the front image in thumb size, if we don't have an image, we display a product silhouette
	elsif (($image_type eq 'front') and ($size eq $thumb_size)) {
		$image_url = "$static_subdomain/images/svg/product-silhouette.svg";
		$image_ref = {
			sizes => {
				$thumb_size => {w => $thumb_size, h => $thumb_size}
			}
		};
	}

	if (defined $image_url) {

		my $alt
			= remove_tags_and_quote($product_ref->{product_name} || '') . ' - '
			. lang($image_type . '_alt') . ' - '
			. ($image_lc || '');

		my $template_data_ref = {
			'alt' => $alt,
			'src' => $image_url,
			'w' => $image_ref->{sizes}{$size}{w},
			'h' => $image_ref->{sizes}{$size}{h}
		};

		# See if we have a x2 image for high resolution displays
		my $size2 = $size * 2;

		if (defined $image_ref->{sizes}{$size2}) {
			$template_data_ref->{srcset} = get_image_url($product_ref, $image_ref, $size2);
		}
		else {
			$template_data_ref->{srcset} = '';
		}

		$html .= <<HTML
<img src="$template_data_ref->{src}" width="$template_data_ref->{w}" height="$template_data_ref->{h}" alt="$template_data_ref->{alt}" loading="lazy" $template_data_ref->{srcset} />
HTML
			;

	}

	return $html;
}

# Use google cloud vision output to determine of the image should be rotated

sub compute_orientation_from_cloud_vision_annotations ($annotations_ref) {

	if (    (defined $annotations_ref)
		and (defined $annotations_ref->{responses})
		and (defined $annotations_ref->{responses}[0])
		and (defined $annotations_ref->{responses}[0]{fullTextAnnotation})
		and (defined $annotations_ref->{responses}[0]{fullTextAnnotation}{pages})
		and (defined $annotations_ref->{responses}[0]{fullTextAnnotation}{pages}[0])
		and (defined $annotations_ref->{responses}[0]{fullTextAnnotation}{pages}[0]{blocks}))
	{

		my $blocks_ref = $annotations_ref->{responses}[0]{fullTextAnnotation}{pages}[0]{blocks};

		# compute the number of blocks in each orientation
		my %orientations = (0 => 0, 90 => 0, 180 => 0, 270 => 0);
		my $total = 0;

		foreach my $block_ref (@{$blocks_ref}) {
			next if $block_ref->{blockType} ne "TEXT";

			my $x_center
				= (   $block_ref->{boundingBox}{vertices}[0]{x}
					+ $block_ref->{boundingBox}{vertices}[1]{x}
					+ $block_ref->{boundingBox}{vertices}[2]{x}
					+ $block_ref->{boundingBox}{vertices}[3]{x})
				/ 4;

			my $y_center
				= (   $block_ref->{boundingBox}{vertices}[0]{y}
					+ $block_ref->{boundingBox}{vertices}[1]{y}
					+ $block_ref->{boundingBox}{vertices}[2]{y}
					+ $block_ref->{boundingBox}{vertices}[3]{y})
				/ 4;

			# Check where the first corner is compared to the center.
			# If the image is correctly oriented, the first corner is at the top left

			if ($block_ref->{boundingBox}{vertices}[0]{x} < $x_center) {
				if ($block_ref->{boundingBox}{vertices}[0]{y} < $y_center) {
					$orientations{0}++;
				}
				else {
					$orientations{270}++;
				}
			}
			else {
				if ($block_ref->{boundingBox}{vertices}[0]{y} < $y_center) {
					$orientations{90}++;
				}
				else {
					$orientations{180}++;
				}
			}
			$total++;
		}

		foreach my $orientation (keys %orientations) {
			if ($orientations{$orientation} > ($total * 0.90)) {
				return $orientation;
			}
		}
	}

	return;
}

=head2 select_ocr_engine ($requested_ocr_engine)

Select the OCR engine to use based on the requested OCR engine and the available engines.

If the requested OCR engine is not available, we return the first available one.

=head3 Arguments

=head4 $requested_ocr_engine

Either 'tesseract' or 'google_cloud_vision'.

=head3 Return values

- 'google_cloud_vision' if Google Cloud Vision API key is available
- 'tesseract' if Tesseract OCR is available
- undef if no OCR engine is available

=cut

sub select_ocr_engine($requested_ocr_engine) {

	my $ocr_engine;

	if ($requested_ocr_engine eq 'tesseract') {
		$ocr_engine = 'tesseract' if $ProductOpener::Config::tesseract_ocr_available;
	}
	elsif ($requested_ocr_engine eq 'google_cloud_vision') {
		$ocr_engine = 'google_cloud_vision' if $ProductOpener::Config::google_cloud_vision_api_key;
	}

	# Default to google cloud vision if available, otherwise tesseract if available, otherwise return undef
	if (not defined $ocr_engine) {
		if ($ProductOpener::Config::google_cloud_vision_api_key) {
			$ocr_engine = 'google_cloud_vision';
		}
		elsif ($ProductOpener::Config::tesseract_ocr_available) {
			$ocr_engine = 'tesseract';
		}
	}

	$log->debug("select_ocr_engine", {requested_ocr_engine => $requested_ocr_engine, ocr_engine => $ocr_engine})
		if $log->is_debug();

	return $ocr_engine;
}

=head2 extract_text_from_image( $product_ref, $id, $field, $ocr_engine, $results_ref )

Perform OCR for a specific image (either a source image, or a selected image) and return the results.

OCR can be performed with a locally installed Tesseract, or through Google Cloud Vision.

In the case of Google Cloud Vision, we also store the results of the OCR as a JSON file (requested through HTTP by Robotoff).

=head3 Arguments

=head4 product reference $product_ref

=head4 id of the image $id

Either a number like 1, 2 etc. to perform the OCR on a source image (1.jpg, 2.jpg) or a field name
in the form of [front|ingredients|nutrition|packaging]_[2 letter language code].

If $id is a field name, the last selected image for that field is used.

=head4 field name $field

Field to update in the product object.
e.g. ingredients_text_from_image, nutrition_text_from_image, packaging_text_from_image

=head4 Requested OCR engine $requested_ocr_engine

Either "tesseract" or "google_cloud_vision".
Note: if the requested OCR engine is not available, we will select the first available one.

=head4 Results reference $results_ref

A hash reference to store the results.

=cut

sub extract_text_from_image ($product_ref, $image_type, $image_lc, $field, $requested_ocr_engine, $results_ref) {

	delete $product_ref->{$field};

	my $ocr_engine = select_ocr_engine($requested_ocr_engine);

	# Return if the OCR engine is undef
	if (not defined $ocr_engine) {
		$results_ref->{error} = "no OCR engine available";
		return;
	}

	my $path = product_path($product_ref);
	$results_ref->{status} = 1;    # 1 = nok, 0 = ok
	$results_ref->{ocr_engine} = $ocr_engine;

	my $image_ref = deep_get($product_ref, "images", "selected", $image_type, $image_lc);

	my $filename = '';
	if (defined $image_ref) {
		$filename = $image_type . '_' . $image_lc . '.' . $image_ref->{rev};
	}
	else {
		$results_ref->{error} = "no image found - image_type: $image_type, image_lc: $image_lc";
		return;
	}

	my $image = "$BASE_DIRS{PRODUCTS_IMAGES}/$path/$filename.full.jpg";
	my $image_url = "$images_subdomain/images/products/$path/$filename.full.jpg";

	my $text;

	$log->debug("extracting text from image",
		{image_type => $image_type, image_lc => $image_lc, ocr_engine => $ocr_engine})
		if $log->is_debug();

	if ($ocr_engine eq 'tesseract') {

		my $lan;

		if (defined $ProductOpener::Config::tesseract_ocr_available_languages{$image_lc}) {
			$lan = $ProductOpener::Config::tesseract_ocr_available_languages{$image_lc};
		}
		elsif (defined $ProductOpener::Config::tesseract_ocr_available_languages{$product_ref->{lc}}) {
			$lan = $ProductOpener::Config::tesseract_ocr_available_languages{$product_ref->{lc}};
		}
		elsif (defined $ProductOpener::Config::tesseract_ocr_available_languages{en}) {
			$lan = $ProductOpener::Config::tesseract_ocr_available_languages{en};
		}

		$log->debug("extracting text with tesseract",
			{lc => $lc, lan => $lan, image_type => $image_type, image_lc => $image_lc, image => $image})
			if $log->is_debug();

		if (defined $lan) {
			$text = decode utf8 => get_ocr($image, undef, $lan);

			if ((defined $text) and ($text ne '')) {
				$results_ref->{$field} = $text;
			}
		}
		else {
			$log->warn("no available tesseract dictionary",
				{lc => $lc, lan => $lan, image_type => $image_type, image_lc => $image_lc})
				if $log->is_warn();
			$results_ref->{error} = "no available tesseract dictionary";
		}
	}
	elsif ($ocr_engine eq 'google_cloud_vision') {

		# Check the API key is defined
		if (not $ProductOpener::Config::google_cloud_vision_api_key) {
			$results_ref->{error} = "no google cloud vision API key";
			return;
		}

		my $json_file = "$BASE_DIRS{PRODUCTS_IMAGES}/$path/$filename.json.gz";
		open(my $gv_logs, ">>:encoding(UTF-8)", "$BASE_DIRS{LOGS}/cloud_vision.log");
		my $cloudvision_ref = send_image_to_cloud_vision($image, $json_file, \@CLOUD_VISION_FEATURES_TEXT, $gv_logs);
		close $gv_logs;

		if (    (defined $cloudvision_ref->{responses})
			and (defined $cloudvision_ref->{responses}[0])
			and (defined $cloudvision_ref->{responses}[0]{fullTextAnnotation})
			and (defined $cloudvision_ref->{responses}[0]{fullTextAnnotation}{text}))
		{

			$log->debug("text found in google cloud vision response") if $log->is_debug();

			$results_ref->{$field} = $cloudvision_ref->{responses}[0]{fullTextAnnotation}{text};
			$results_ref->{$field . "_annotations"} = $cloudvision_ref;

			# Note: if the product is not stored, this will not be saved
			$product_ref->{images}{selected}{$image_type}{$image_lc}{orientation}
				= compute_orientation_from_cloud_vision_annotations($cloudvision_ref);
		}
	}

	# Check if we were able to get ocr text
	if (defined $results_ref->{$field}) {
		$product_ref->{images}{selected}{$image_type}{$image_lc}{ocr} = 1;
		$results_ref->{status} = 0;
	}
	else {
		$product_ref->{images}{selected}{$image_type}{$image_lc}{ocr} = 0;
	}

	return;
}

@CLOUD_VISION_FEATURES_FULL = (
	# DOCUMENT_TEXT_DETECTION does not bring significant advantages
	# See https://github.com/openfoodfacts/openfoodfacts-server/issues/9723
	{type => 'TEXT_DETECTION'},
	# Disable other Cloud Vision temporarily to save credits
	# {type => 'LOGO_DETECTION'},
	# {type => 'LABEL_DETECTION'},
	# {type => 'SAFE_SEARCH_DETECTION'},
	# {type => 'FACE_DETECTION'},
);

@CLOUD_VISION_FEATURES_TEXT = ({type => 'TEXT_DETECTION'});

=head2 send_image_to_cloud_vision ($image_path, $json_file, $features_ref, $gv_logs)

Call to Google Cloud vision API

=head3 Arguments

=head4 $image_path - str path to image

=head4 $json_file - str path to the file where we will store OCR result as gzipped JSON

=head4 $features_ref - hash reference - the "features" parameter of Google Cloud Vision

This determine which detection will be performed.
Remember each feature is a cost.

C<@CLOUD_VISION_FEATURES_FULL> and C<@CLOUD_VISION_FEATURES_TEXT> are two constant you can use.

=head4 $gv_logs - file handle

A file where we write additional logs, specific to the service.

=head3 Response

Return JSON content of the response.

=cut

sub send_image_to_cloud_vision ($image_path, $json_file, $features_ref, $gv_logs) {

	my $url
		= $ProductOpener::Config::google_cloud_vision_api_url . "?key="
		. $ProductOpener::Config::google_cloud_vision_api_key;

	# If we already have a CloudVision result JSON file that is less than 1 month old, we return it
	# instead of sending the image to the API. This is in particular useful for integration tests
	# that make the same request multiple times.

	if (-e $json_file) {
		my $mtime = (stat($json_file))[9];
		my $age = time() - $mtime;
		if ($age < 30 * 24 * 60 * 60) {    # less than 30 days old
			print($gv_logs "CV:getting existing cached JSON file for $url\n");
			$log->debug("using cached cloud vision result", {path => $json_file, age => $age}) if $log->is_debug();
			open(my $IN, "<:raw", $json_file) or die "Could not read $json_file: $!\n";
			# use an eval block to catch errors in the JSON decoding in case the file is corrupted
			my $response;
			eval {
				my $gzip_handle = IO::Uncompress::Gunzip->new($IN)
					or die "Cannot create gzip filehandle: $GzipError\n";
				my $json_response = do {local $/; <$gzip_handle>};
				$gzip_handle->close;
				close $IN;
				$response = decode_json($json_response);
			};
			if (defined $response) {
				return $response;
			}
		}
	}

	print($gv_logs "CV:sending to $url\n");

	my $ua = create_user_agent();

	open(my $IMAGE, "<", $image_path) || die "Could not read $image_path: $!\n";
	binmode($IMAGE);
	local $/;
	my $image_data = do {local $/; <$IMAGE>};    # https://www.perlmonks.org/?node_id=287647
	close $IMAGE;

	my $api_request_ref = {
		requests => [
			{
				features => $features_ref,
				# image => { source => { imageUri => $image_url}}
				image => {content => encode_base64($image_data)},
			}
		]
	};
	my $json = encode_json($api_request_ref);

	my $request = HTTP::Request->new(POST => $url);
	$request->header('Content-Type' => 'application/json');
	$request->content($json);

	my $cloud_vision_response = $ua->request($request);
	# $log->debug("google cloud vision response", { json_response => $cloud_vision_response->decoded_content, api_token => $ProductOpener::Config::google_cloud_vision_api_key });

	my $cloudvision_ref = undef;
	if ($cloud_vision_response->is_success) {

		$log->debug("request to google cloud vision was successful for $image_path") if $log->is_debug();

		my $json_response = $cloud_vision_response->decoded_content(charset => 'UTF-8');

		$cloudvision_ref = decode_json($json_response);

		# Adding creation timestamp, to know when the OCR has been generated
		$cloudvision_ref->{created_at} = time();

		$log->debug("saving google cloud vision json response to file", {path => $json_file}) if $log->is_debug();

		if (open(my $OUT, ">:raw", $json_file)) {
			my $gzip_handle = IO::Compress::Gzip->new($OUT)
				or die "Cannot create gzip filehandle: $GzipError\n";
			my $encoded_json = encode_json($cloudvision_ref);
			$gzip_handle->print($encoded_json);
			$gzip_handle->close;

			print($gv_logs "--> cloud vision success for $image_path\n");
		}
		else {
			$log->error("Cannot write $json_file: $!\n");
			print($gv_logs "Cannot write $json_file: $!\n");
		}

	}
	else {
		$log->warn(
			"google cloud vision request not successful",
			{
				code => $cloud_vision_response->code,
				image_path => $image_path,
				response => $cloud_vision_response->message
			}
		) if $log->is_warn();
		print $gv_logs "error\t"
			. $image_path . "\t"
			. $cloud_vision_response->code . "\t"
			. $cloud_vision_response->message . "\n";
	}
	return $cloudvision_ref;

}

1;
