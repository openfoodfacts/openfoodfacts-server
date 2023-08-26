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
		&get_selected_image_uploader
		&is_protected_image
		&process_image_upload
		&process_image_move

		&process_image_crop
		&process_image_unselect

		&scan_code

		&display_select_manage
		&display_select_crop
		&display_select_crop_init

		&display_image
		&display_image_thumb

		&extract_text_from_image
		&send_image_to_cloud_vision
		&send_image_to_robotoff

		@CLOUD_VISION_FEATURES_FULL
		@CLOUD_VISION_FEATURES_TEXT

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Store qw/:all/;
use ProductOpener::Config qw/:all/;
use ProductOpener::Products qw/:all/;

use CGI qw/:cgi :form escapeHTML/;

use Image::Magick;
use Graphics::Color::RGB;
use Graphics::Color::HSL;
use Barcode::ZBar;
use Image::OCR::Tesseract 'get_ocr';

use ProductOpener::Products qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::URL qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Text qw/:all/;
use Data::DeepAccess qw(deep_get);

use IO::Compress::Gzip qw(gzip $GzipError);
use Log::Any qw($log);
use Encode;
use JSON::PP;
use MIME::Base64;
use LWP::UserAgent;
use File::Copy;

=head1 SUPPORTED IMAGE TYPES

gif, jpeg, jpf, png, heic

=cut

my $supported_extensions = "gif|jpeg|jpg|png|heic";

=head1 FUNCTIONS

=cut

sub display_select_manage ($object_ref) {

	my $id = "manage";

	my $html = <<HTML
<div class=\"select_crop select_manage\" id=\"$id\"></div>
<hr class="floatclear" />
HTML
		;

	return $html;
}

sub display_select_crop ($object_ref, $id_lc, $language) {

	# $id_lc = shift  ->  id_lc = [front|ingredients|nutrition|packaging]_[new_]?[lc]
	my $id = $id_lc;

	my $imagetype = $id_lc;
	my $display_lc = $lc;

	if ($id_lc =~ /^(.*?)_(new_)?(.*)$/) {
		$imagetype = $1;
		$display_lc = $3;
	}

	my $note = '';
	if (defined $Lang{"image_" . $imagetype . "_note"}{$lang}) {
		$note = "<p class=\"note\">&rarr; " . $Lang{"image_" . $imagetype . "_note"}{$lang} . "</p>";
	}

	my $label = $Lang{"image_" . $imagetype}{$lang};

	my $html = <<HTML
<label for="$id">$label (<span class="tab_language">$language</span>)</label>
$note
<div class=\"select_crop\" id=\"$id\"></div>
<hr class="floatclear" />
HTML
		;

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
	my $size = $display_size;
	my $product_ref = $object_ref;
	my $display_url = '';
	if (    (defined $product_ref->{images})
		and (defined $product_ref->{images}{$id})
		and (defined $product_ref->{images}{$id}{sizes})
		and (defined $product_ref->{images}{$id}{sizes}{$size}))
	{
		$display_url = "$id." . $product_ref->{images}{$id}{rev} . ".$display_size.jpg";
	}
	$html
		.= '<input type="hidden" name="'
		. "${id}_display_url"
		. '" id="'
		. "${id}_display_url"
		. '" value="'
		. $display_url . '" />' . "\n";

	return $html;
}

sub display_select_crop_init ($object_ref) {

	$log->debug("display_select_crop_init", {object_ref => $object_ref}) if $log->is_debug();

	my $path = product_path($object_ref);

	my $images = '';

	defined $object_ref->{images} or $object_ref->{images} = {};

	# Construct an array of images that we can sort by upload time
	# The imgid number is incremented by 1 for each new image, but when we move images
	# from one product to another, they might not be sorted by upload time.

	my @images = ();

	# There may be occasions where max_imgid was not incremented correctly (e.g. a crash)
	# so we add 5 to it to check if we have other images to show
	for (my $imgid = 1; $imgid <= (($object_ref->{max_imgid} || 0) + 5); $imgid++) {
		if (defined $object_ref->{images}{$imgid}) {
			push @images, $imgid;
		}
	}

	foreach my $imgid (sort {$object_ref->{images}{$a}{uploaded_t} <=> $object_ref->{images}{$b}{uploaded_t}} @images) {
		my $uploader = $object_ref->{images}{$imgid}{uploader};
		my $uploaded_date = display_date($object_ref->{images}{$imgid}{uploaded_t});

		$images .= <<JS
{
	imgid: "$imgid",
	thumb_url: "$imgid.$thumb_size.jpg",
	crop_url: "$imgid.$crop_size.jpg",
	display_url: "$imgid.$display_size.jpg",
	uploader: "$uploader",
	uploaded: "$uploaded_date",
},
JS
			;
	}

	$images =~ s/,\n?$//;

	return <<HTML

	\$([]).selectcrop('init_images', [
		$images
	]);
	\$(".select_crop").selectcrop('init', {img_path : "/images/products/$path/"});
	\$(".select_crop").selectcrop('show');

HTML
		;

}

sub scan_code ($file) {

	my $code = undef;

	# create a reader
	my $scanner = Barcode::ZBar::ImageScanner->new();

	print STDERR "scan_code file: $file\n";

	# configure the reader
	$scanner->parse_config("enable");

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
				print STDERR "scan_code code found: $code\n";

				if (($code !~ /^\d+|(?:[\^(\N{U+001D}\N{U+241D}]|https?:\/\/).+$/)) {
					$code = undef;
					next;
				}
				last;
			}

			if (defined $code) {
				$code = normalize_code($code);
				last;
			}
			else {
				$magick->Rotate(degrees => 90);
			}

		}
	}
	print STDERR "scan_code return code: $code\n";

	return $code;
}

sub display_search_image_form ($id) {

	my $html = '';

	my $product_image_with_barcode = $Lang{product_image_with_barcode}{$lang};
	$product_image_with_barcode =~ s/( |\&nbsp;)?:$//;

	my $template_data_ref = {
		product_image_with_barcode => $product_image_with_barcode,
		id => $id,
	};

	# Do not load jquery file upload twice, if it was loaded by another form

	if ($scripts !~ /jquery.fileupload.js/) {

		$scripts .= <<JS
<script type="text/javascript" src="/js/dist/jquery.iframe-transport.js"></script>
<script type="text/javascript" src="/js/dist/jquery.fileupload.js"></script>
<script type="text/javascript" src="/js/dist/load-image.all.min.js"></script>
<script type="text/javascript" src="/js/dist/canvas-to-blob.js"></script>
JS
			;

	}

	$initjs .= <<JS

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

	process_template('web/common/includes/display_search_image_form.tt.html', $template_data_ref, \$html)
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

			(-e "$data_root/tmp") or mkdir("$data_root/tmp", 0755);
			open(my $out, ">", "$data_root/tmp/$filename.$extension");
			while (my $chunk = <$file>) {
				print $out $chunk;
			}
			close($out);

			$code = scan_code("$data_root/tmp/$filename.$extension");
			if (defined $code) {
				$code = normalize_code($code);
			}
			${$filename_ref} = "$data_root/tmp/$filename.$extension";
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

	if ($filename =~ /((front|ingredients|nutrition|packaging)((_|-)\w\w\b)?)/i) {
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

	if ($filename =~ /((front|ingredients|nutrition|packaging)((_|-)\w\w\b)?)/i) {
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

sub get_selected_image_uploader ($product_ref, $imagefield) {

	# Retrieve the product's image data
	my $imgid = deep_get($product_ref, "images", $imagefield, "imgid");

	# Retrieve the uploader of the image
	if (defined $imgid) {
		my $uploader = deep_get($product_ref, "images", $imgid, "uploader");
		return $uploader;
	}

	return;
}

sub is_protected_image ($product_ref, $imagefield) {

	my $selected_uploader = get_selected_image_uploader($product_ref, $imagefield);
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

=head2 process_image_upload ( $product_id, $imagefield, $user_id, $time, $comment, $imgid_ref, $debug_string_ref )

Process an image uploaded to a product (from the web site, from the API, or from an import):

- Read the image
- Create a JPEG version
- Create resized versions
- Store the image in the product data

=head3 Arguments

=head4 Product id $product_id

=head4 Image field $imagefield

Indicates what the image is and its language.

Format: [front|ingredients|nutrition|packaging|other]_[2 letter language code]

=head4 User id $user_id

=head4 Timestamp of the image $time

=head4 Comment $comment

=head4 Reference to an image id $img_id

Used to return the number identifying the image to the caller.

=head4 Debug string reference $debug_string_ref

Used to return some debug information to the caller.


=cut

sub process_image_upload ($product_id, $imagefield, $user_id, $time, $comment, $imgid_ref, $debug_string_ref) {

	# $time = shift  ->  usually current time (images just uploaded), except for images moved from another product
	# $imgid_ref = shift  ->  to return the imgid (new image or existing image)
	# $debug_string_ref = shift  ->  to return debug information to clients

	$log->debug("process_image_upload", {product_id => $product_id, imagefield => $imagefield}) if $log->is_debug();

	# The product_id can be prefixed by a server (e.g. off:[code]) with a different $www_root
	my $product_www_root = www_root_for_product_id($product_id);
	my $product_data_root = data_root_for_product_id($product_id);

	# debug message passed back to apps in case of an error

	my $debug = "product_id: $product_id - user_id: $user_id - imagefield: $imagefield";

	my $bogus_imgid;
	not defined $imgid_ref and $imgid_ref = \$bogus_imgid;

	my $path = product_path_from_id($product_id);
	my $imgid = -1;

	my $new_product_ref = {};

	my $file = undef;
	my $extension = 'jpg';

	# Image that was already read by barcode scanner: can't read it again
	my $tmp_filename;
	if ($imagefield =~ /\//) {
		$tmp_filename = $imagefield;
		$imagefield = 'search';

		if ($tmp_filename) {
			open($file, q{<}, "$tmp_filename")
				or $log->error("Could not read file", {path => $tmp_filename, error => $!});
			if ($tmp_filename =~ /\.($supported_extensions)$/i) {
				$extension = lc($1);
			}
		}
	}
	else {
		$file = single_param('imgupload_' . $imagefield);
		if (!$file) {
			# mobile app may not set language code
			my $old_imagefield = $imagefield;
			$old_imagefield =~ s/_\w\w$//;
			$file = single_param('imgupload_' . $old_imagefield);

			if (!$file) {
				# producers platform: name="files[]"
				$file = single_param("files[]");
			}
		}
	}

	local $log->context->{imagefield} = $imagefield;
	local $log->context->{uploader} = $user_id;
	local $log->context->{file} = $file;
	local $log->context->{time} = $time;

	# Check if we have already received this image before
	my $images_ref = retrieve("$product_data_root/products/$path/images.sto");
	defined $images_ref or $images_ref = {};

	my $file_size = -s $file;

	if (($file_size > 0) and (defined $images_ref->{$file_size})) {
		$log->debug(
			"we have already received an image with the same size",
			{file_size => $file_size, imgid => $images_ref->{$file_size}}
		) if $log->is_debug();
		${$imgid_ref} = $images_ref->{$file_size};
		$debug .= " - we have already received an image with this file size: $file_size - imgid: $$imgid_ref";
		${$debug_string_ref} = $debug;
		return -3;
	}

	if ($file) {
		$log->debug("processing uploaded file", {file => $file}) if $log->is_debug();

		# We may have a "blob" without file name and extension
		# extension was initialized to jpg and we will let ImageMagick read it anyway if it's something else.

		if ($file =~ /\.($supported_extensions)$/i) {
			$extension = lc($1);
			$extension eq 'jpeg' and $extension = 'jpg';
		}

		my $filename = get_string_id_for_lang("no_language", remote_addr() . '_' . $`);

		my $current_product_ref = retrieve_product($product_id);
		$imgid = $current_product_ref->{max_imgid} + 1;

		# if for some reason the images directories were not created at product creation (it can happen if the images directory's permission / ownership are incorrect at some point)
		# create them

		# Create the directories for the product
		foreach my $current_dir ($product_www_root . "/images/products") {
			(-e "$current_dir") or mkdir($current_dir, 0755);
			foreach my $component (split("/", $path)) {
				$current_dir .= "/$component";
				(-e "$current_dir") or mkdir($current_dir, 0755);
			}
		}

		my $lock_path = "$product_www_root/images/products/$path/$imgid.lock";
		while ((-e $lock_path) or (-e "$product_www_root/images/products/$path/$imgid.jpg")) {
			$imgid++;
			$lock_path = "$product_www_root/images/products/$path/$imgid.lock";
		}

		mkdir($lock_path, 0755)
			or $log->warn("could not create lock file for the image", {path => $lock_path, error => $!});

		local $log->context->{imgid} = $imgid;
		$log->debug("new imgid: ", {imgid => $imgid, extension => $extension}) if $log->is_debug();

		my $img_orig = "$product_www_root/images/products/$path/$imgid.$extension.orig";
		open(my $out, ">", $img_orig)
			or $log->warn("could not open image path for saving", {path => $img_orig, error => $!});
		while (my $chunk = <$file>) {
			print $out $chunk;
		}
		close($out);

		# Read the image

		my $source = Image::Magick->new;
		my $imagemagick_error = $source->Read($img_orig);
		if (($imagemagick_error) and ($imagemagick_error =~ /(\d+)/) and ($1 >= 400))
		{    # ImageMagick returns a string starting with a number greater than 400 for errors
			$log->error("cannot read image",
				{path => "$product_www_root/images/products/$path/$imgid.$extension", error => $imagemagick_error});
			$debug .= " - could not read image: $imagemagick_error";
			${$debug_string_ref} = $debug;
			return -5;
		}

		$source->AutoOrient();
		$source->Strip();    #remove orientation data and all other metadata (EXIF)

		# remove the transparency for PNG files
		if ($extension eq "png") {
			$log->debug("png file, trying to remove the alpha background") if $log->is_debug();
			my $bg = Image::Magick->new;
			$bg->Set(size => $source->Get('width') . "x" . $source->Get('height'));
			$bg->ReadImage('canvas:white');
			$bg->Composite(compose => 'Over', image => $source);
			$source = $bg;
		}

		my $img_jpg = "$product_www_root/images/products/$path/$imgid.jpg";

		$source->Set('quality', 95);
		$imagemagick_error = $source->Write("jpeg:$img_jpg");
		# We also check for the existence of the image file as sometimes ImageMagick does not return an error
		# but does not write the file (e.g. conversion from pdf to jpg)
		if (($imagemagick_error) or (!-e $img_jpg)) {
			$log->error("cannot write image", {path => $img_jpg, error => $imagemagick_error});
			$debug .= " - could not write image: $imagemagick_error";
			${$debug_string_ref} = $debug;
			return -5;
		}

		# Check that we don't already have the image
		my $size_orig = -s $img_orig;
		my $size_jpg = -s $img_jpg;

		local $log->context->{img_size_orig} = $size_orig;
		local $log->context->{img_size_jpg} = $size_jpg;

		$debug .= " - size of image file received: $size_orig - saved jpg: $size_jpg";

		$log->debug("comparing existing images with size of new image",
			{img_orig => $img_orig, size_orig => $size_orig, img_jpg => $img_jpg, size_jpg => $size_jpg})
			if $log->is_debug();
		for (my $i = 0; $i < $imgid; $i++) {

			# We did not store original files sizes in images.sto and original files in [imgid].[extension].orig before July 2020,
			# but we stored original PNG files before they were converted to JPG in [imgid].png
			# We compare both the sizes of the original files and the converted files

			my @existing_images = ("$product_www_root/images/products/$path/$i.jpg");
			if (-e "$product_www_root/images/products/$path/$i.$extension.orig") {
				push @existing_images, "$product_www_root/images/products/$path/$i.$extension.orig";
			}
			if (($extension ne "jpg") and (-e "$product_www_root/images/products/$path/$i.$extension")) {
				push @existing_images, "$product_www_root/images/products/$path/$i.$extension";
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
						my $product_ref = retrieve_product($product_id);
						if (    (defined $product_ref)
							and (defined $product_ref->{images})
							and (exists $product_ref->{images}{$i}))
						{
							$log->debug(
								"unlinking image",
								{imgid => $imgid, file => "$product_www_root/images/products/$path/$imgid.$extension"}
							) if $log->is_debug();
							unlink $img_orig;
							unlink $img_jpg;
							rmdir("$product_www_root/images/products/$path/$imgid.lock");
							${$imgid_ref} = $i;
							$debug .= " - we already have an image with this file size: $size - imgid: $i";
							${$debug_string_ref} = $debug;
							return -3;
						}
						else {
							print STDERR "missing image $i in product.sto, keeping image $imgid\n";
						}
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
			unlink "$product_www_root/images/products/$path/$imgid.$extension";
			rmdir("$product_www_root/images/products/$path/$imgid.lock");
			$debug .= " - image too small - width: " . $source->Get('width') . " - height: " . $source->Get('height');
			${$debug_string_ref} = $debug;
			return -4;
		}

		# Generate resized versions

		$new_product_ref->{"images.$imgid.w"} = $source->Get('width');
		$new_product_ref->{"images.$imgid.h"} = $source->Get('height');

		foreach my $max ($thumb_size, $crop_size) {

			my ($w, $h) = ($source->Get('width'), $source->Get('height'));
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
			my $img = $source->Clone();
			$img->Resize(geometry => "$geometry^");
			$img->Extent(
				geometry => "$geometry",
				gravity => "center"
			);
			_set_magickal_options($img, $w);

			$imagemagick_error = $img->Write("jpeg:$product_www_root/images/products/$path/$imgid.$max.jpg");
			if (($imagemagick_error) and ($imagemagick_error =~ /(\d+)/) and ($1 >= 400))
			{    # ImageMagick returns a string starting with a number greater than 400 for errors
				$log->warn(
					"could not write jpeg",
					{
						path => "jpeg:$product_www_root/images/products/$path/$imgid.$max.jpg",
						error => $imagemagick_error
					}
				) if $log->is_warn();
				last;
			}
			else {
				$log->info("jpeg written", {path => "jpeg:$product_www_root/images/products/$path/$imgid.$max.jpg"})
					if $log->is_info();
			}

			$new_product_ref->{"images.$imgid.$max"} = "$imgid.$max";
			$new_product_ref->{"images.$imgid.$max.w"} = $img->Get('width');
			$new_product_ref->{"images.$imgid.$max.h"} = $img->Get('height');

		}

		if (not $imagemagick_error) {

			# Update the product image data
			$log->debug("update the product image data", {imgid => $imgid, product_id => $product_id})
				if $log->is_debug();
			my $product_ref = retrieve_product($product_id);

			if (not defined $product_ref) {
				$log->debug("product could not be loaded", {imgid => $imgid, product_id => $product_id})
					if $log->is_debug();
			}

			defined $product_ref->{images} or $product_ref->{images} = {};
			$product_ref->{images}{$imgid} = {
				uploader => $user_id,
				uploaded_t => $time,
				sizes => {
					full => {w => $new_product_ref->{"images.$imgid.w"}, h => $new_product_ref->{"images.$imgid.h"}},
				},
			};

			foreach my $max ($thumb_size, $crop_size) {

				$product_ref->{images}{$imgid}{sizes}{$max} = {
					w => $new_product_ref->{"images.$imgid.$max.w"},
					h => $new_product_ref->{"images.$imgid.$max.h"}
				};

			}
			if ($imgid > $product_ref->{max_imgid}) {
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

			(-e "$product_data_root/new_images") or mkdir("$product_data_root/new_images", 0755);
			my $code = $product_id;
			$code =~ s/.*\///;
			symlink("$product_www_root/images/products/$path/$imgid.jpg",
				"$product_data_root/new_images/" . time() . "." . $code . "." . $imagefield . "." . $imgid . ".jpg");

			# Save the image file size so that we can skip the image before processing it if it is uploaded again
			$images_ref->{$size_orig} = $imgid;
			store("$product_data_root/products/$path/images.sto", $images_ref);
		}
		else {
			# Could not read image
			$debug .= " - could not read image : $imagemagick_error";
			$imgid = -5;
		}

		rmdir("$product_www_root/images/products/$path/$imgid.lock");

		# make sure to close the file so that it does not stay in /tmp forever
		my $tmpfilename = tmpFileName($file);
		$log->debug("unlinking image", {file => $file, tmpfilename => $tmpfilename}) if $log->is_debug();
		unlink($tmpfilename);
	}
	else {
		$log->debug("imgupload field not set", {field => "imgupload_$imagefield"}) if $log->is_debug();
		$debug .= " - no image file for field name imgupload_$imagefield";
		$imgid = -2;
	}

	$log->info("upload processed", {imgid => $imgid, imagefield => $imagefield}) if $log->is_info();

	if ($imgid > 0) {
		${$imgid_ref} = $imgid;
	}
	else {
		${$imgid_ref} = $imgid;
		# Pass back a debug message
		${$debug_string_ref} = $debug;
	}

	return $imgid;
}

sub process_image_move ($user_id, $code, $imgids, $move_to, $ownerid) {

	# move images only to trash or another valid barcode (number)
	if (($move_to ne 'trash') and ($move_to !~ /^((off|obf|opf|opff):)?\d+$/)) {
		return "invalid barcode number: $move_to";
	}

	my $product_id = product_id_for_owner($ownerid, $code);
	my $move_to_id = product_id_for_owner($ownerid, $move_to);

	$log->debug("process_image_move - start", {product_id => $product_id, imgids => $imgids, move_to_id => $move_to_id})
		if $log->is_debug();

	my $path = product_path_from_id($product_id);

	my $product_ref = retrieve_product($product_id);
	defined $product_ref->{images} or $product_ref->{images} = {};

	# iterate on each images

	foreach my $imgid (split(/,/, $imgids)) {

		next if ($imgid !~ /^\d+$/);

		# check the imgid exists
		if (defined $product_ref->{images}{$imgid}) {

			my $ok = 1;

			my $new_imgid;
			my $debug;

			if ($move_to =~ /^((off|obf|opf|opff):)?\d+$/) {
				$ok = process_image_upload(
					$move_to_id,
					"$www_root/images/products/$path/$imgid.jpg",
					$product_ref->{images}{$imgid}{uploader},
					$product_ref->{images}{$imgid}{uploaded_t},
					"image moved from product $code on $server_domain by $user_id -- uploader: $product_ref->{images}{$imgid}{uploader} - time: $product_ref->{images}{$imgid}{uploaded_t}",
					\$new_imgid,
					\$debug
				);
				if ($ok < 0) {
					$log->error(
						"could not move image to other product",
						{
							source_path => "$www_root/images/products/$path/$imgid.jpg",
							move_to => $move_to,
							old_code => $code,
							ownerid => $ownerid,
							user_id => $user_id,
							result => $ok
						}
					);
				}
				else {
					$log->info(
						"moved image to other product",
						{
							source_path => "$www_root/images/products/$path/$imgid.jpg",
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
				$log->info(
					"moved image to trash",
					{
						source_path => "$www_root/images/products/$path/$imgid.jpg",
						old_code => $code,
						ownerid => $ownerid,
						user_id => $user_id,
						result => $ok
					}
				);
			}

			# Don't delete images to be moved if they weren't moved correctly
			if ($ok) {
				# Delete images (move them to the deleted.images dir

				-e "$data_root/deleted.images" or mkdir("$data_root/deleted.images", 0755);

				File::Copy->import(qw( move ));

				$log->info(
					"moving source image to deleted images directory",
					{
						source_path => "$www_root/images/products/$path/$imgid.jpg",
						destination_path => "$data_root/deleted.images/product.$code.$imgid.jpg"
					}
				);

				move("$www_root/images/products/$path/$imgid.jpg",
					"$data_root/deleted.images/product.$code.$imgid.jpg");
				move(
					"$www_root/images/products/$path/$imgid.$thumb_size.jpg",
					"$data_root/deleted.images/product.$code.$imgid.$thumb_size.jpg"
				);
				move(
					"$www_root/images/products/$path/$imgid.$crop_size.jpg",
					"$data_root/deleted.images/product.$code.$imgid.$crop_size.jpg"
				);

				delete $product_ref->{images}{$imgid};

			}

		}

	}

	store_product($user_id, $product_ref, "Moved images $imgids to $move_to");

	$log->debug("process_image_move - end", {product_id => $product_id, imgids => $imgids, move_to_id => $move_to_id})
		if $log->is_debug();

	return 0;
}

sub process_image_crop ($user_id, $product_id, $id, $imgid, $angle, $normalize, $white_magic, $x1, $y1, $x2, $y2,
	$coordinates_image_size)
{

	$log->debug(
		"process_image_crop - start",
		{
			product_id => $product_id,
			imgid => $imgid,
			x1 => $x1,
			y1 => $y1,
			x2 => $x2,
			y2 => $y2,
			coordinates_image_size => $coordinates_image_size
		}
	) if $log->is_debug();

	# The crop coordinates used to be in reference to a smaller image (400x400)
	# -> $coordinates_image_size = $crop_size
	# they are now in reference to the full image
	# -> $coordinates_image_size = "full"

	# There was an issue saving coordinates_image_size for some products
	# if any coordinate is above the $crop_size, then assume it was on the full size

	if (not defined $coordinates_image_size) {
		if (($x2 <= $crop_size) and ($y2 <= $crop_size)) {
			$coordinates_image_size = $crop_size;
			$log->debug(
				"process_image_crop - coordinates_image_size not set and x2 and y2 less than crop_size, setting to crop_size",
				{$coordinates_image_size => $coordinates_image_size}
			) if $log->is_debug();
		}
		else {
			$coordinates_image_size = "full";
			$log->debug(
				"process_image_crop - coordinates_image_size not set and x2 or y2 greater than crop_size, setting to full",
				{$coordinates_image_size => $coordinates_image_size}
			) if $log->is_debug();
		}
	}
	else {
		$log->debug("process_image_crop - coordinates_image_size set",
			{$coordinates_image_size => $coordinates_image_size})
			if $log->is_debug();
	}

	my $path = product_path_from_id($product_id);

	my $code = $product_id;
	$code =~ s/.*\///;

	my $new_product_ref = retrieve_product($product_id);
	my $rev = $new_product_ref->{rev} + 1;    # For naming images

	# The product_id can be prefixed by a server (e.g. off:[code]) with a different $www_root
	my $product_www_root = www_root_for_product_id($product_id);

	my $source_path = "$product_www_root/images/products/$path/$imgid.jpg";

	local $log->context->{code} = $code;
	local $log->context->{product_id} = $product_id;
	local $log->context->{id} = $id;
	local $log->context->{imgid} = $imgid;
	local $log->context->{source_path} = $source_path;

	$log->trace("cropping image") if $log->is_trace();

	my $proceed_with_edit = process_product_edit_rules($new_product_ref);

	$log->debug("edit rules processed", {proceed_with_edit => $proceed_with_edit}) if $log->is_debug();

	if (not $proceed_with_edit) {

		my $data = encode_json({status => 'status not ok - edit against edit rules'});

		$log->debug("JSON data output", {data => $data}) if $log->is_debug();

		print header(-type => 'application/json', -charset => 'utf-8') . $data;

		exit;
	}

	my $source = Image::Magick->new;
	my $imagemagick_error = $source->Read($source_path);
	($imagemagick_error) and $log->error("cannot read image", {path => $source_path, error => $imagemagick_error});

	if ($angle != 0) {
		$source->Rotate($angle);
	}

	# Crop the image
	my $ow = $source->Get('width');
	my $oh = $source->Get('height');
	my $w = $new_product_ref->{images}{$imgid}{sizes}{$coordinates_image_size}{w};
	my $h = $new_product_ref->{images}{$imgid}{sizes}{$coordinates_image_size}{h};

	if (($angle % 180) == 90) {
		my $z = $w;
		$w = $h;
		$h = $z;
	}

	print STDERR
		"image_crop.pl - imgid: $imgid - crop_size: $crop_size - x1: $x1, y1: $y1, x2: $x2, y2: $y2, w: $w, h: $h\n";
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

	if ((defined $white_magic) and (($white_magic eq 'checked') or ($white_magic eq 'true'))) {
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

		my $bg_path = "$product_www_root/images/products/$path/$imgid.${crop_size}.background.jpg";
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
		#$image->Normalize( channel=>'RGB' );

		#$imagemagick_error = $image->Composite(image=>$background, compose=>"Screen");
		#$image->Negate();

		if (0) {    # Too slow, could work well with some tuning...
			my $original = $image->Clone();
			my @white = (1, 1, 1);

			my $distance = sub ($a, $b) {

				my $d
					= ($a->[0] - $b->[0]) * ($a->[0] - $b->[0])
					+ ($a->[1] - $b->[1]) * ($a->[1] - $b->[1])
					+ ($a->[2] - $b->[2]) * ($a->[2] - $b->[2]);
				return $d;
			};

			my @q = (
				[0, 0],
				[0, $h - 1],
				[0, int($h / 2)],
				[int($w / 2), 0],
				[int($w / 2), $h - 1],
				[$w - 1, 0],
				[$w - 1, $h - 1],
				[$w - 1, int($h / 2)]
			);
			my $max_distance = 0.015 * 0.015;
			my $i = 0;
			my %seen;
			while (@q) {
				my $p = pop @q;
				my ($x, $y) = @{$p};
				$seen{$x . ',' . $y} and next;
				$seen{$x . ',' . $y} = 1;
				(($x < 0) or ($x >= $w) or ($y < 0) or ($y > $h)) and next;
				@rgb = $image->GetPixel(x => $x, y => $y);
				#if (($rgb[0] == 1) and ($rgb[1] == 1) and ($rgb[2] == 1)) {
				#	next;
				#}
				$image->SetPixel(x => $x, y => $y, color => \@white);
				($distance->(\@rgb, [$original->GetPixel(x => $x + 1, y => $y)]) <= $max_distance)
					and push @q, [$x + 1, $y];
				($distance->(\@rgb, [$original->GetPixel(x => $x - 1, y => $y)]) <= $max_distance)
					and push @q, [$x - 1, $y];
				($distance->(\@rgb, [$original->GetPixel(x => $x, y => $y + 1)]) <= $max_distance)
					and push @q, [$x, $y + 1];
				($distance->(\@rgb, [$original->GetPixel(x => $x, y => $y - 1)]) <= $max_distance)
					and push @q, [$x, $y - 1];

				($distance->(\@rgb, [$original->GetPixel(x => $x + 1, y => $y + 1)]) <= $max_distance)
					and push @q, [$x + 1, $y + 1];
				($distance->(\@rgb, [$original->GetPixel(x => $x - 1, y => $y - 1)]) <= $max_distance)
					and push @q, [$x - 1, $y - 1];
				($distance->(\@rgb, [$original->GetPixel(x => $x - 1, y => $y + 1)]) <= $max_distance)
					and push @q, [$x - 1, $y + 1];
				($distance->(\@rgb, [$original->GetPixel(x => $x + 1, y => $y - 1)]) <= $max_distance)
					and push @q, [$x + 1, $y - 1];
				$i++;
				($i % 10000) == 0 and $log->debug("white color detection",
					{i => $i, x => $x, y => $y, r => $rgb[0], g => $rgb[1], b => $rgb[2], width => $w, height => $h});
			}
		}

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

		if (0) {
			my $n = 10;
			for (my $i = 0; $i <= $n; $i++) {
				$imagemagick_error = $image->FloodfillPaint(
					x => int($i * ($w - 1) / $n),
					y => 0,
					fill => "#ffffff",
					fuzz => "5%",
					xbordercolor => "#ffffff"
				);
				$imagemagick_error = $image->FloodfillPaint(
					x => int($i * ($w - 1) / $n),
					y => $h - 2,
					fill => "#ffffff",
					fuzz => "5%",
					xbordercolor => "#ffffff"
				);
			}
			$n = 10;
			for (my $i = 0; $i <= $n; $i++) {
				$imagemagick_error = $image->FloodfillPaint(
					y => int($i * ($h - 1) / $n),
					x => 0,
					fill => "#ffffff",
					fuzz => "5%",
					xbordercolor => "#ffffff"
				);
				$imagemagick_error = $image->FloodfillPaint(
					y => int($i * ($h - 1) / $n),
					x => $w - 2,
					fill => "#ffffff",
					fuzz => "5%",
					xbordercolor => "#ffffff"
				);
			}
		}
		#$image->Deskew();

		$imagemagick_error and $log->error("could not floodfill", {error => $imagemagick_error});

	}

	if ((defined $normalize) and (($normalize eq 'checked') or ($normalize eq 'true'))) {
		$source->Normalize(channel => 'RGB');
		$filename .= ".normalize";
	}

	# Keep only one image, and overwrite previous images
	# ! cached images... add a version number
	$filename = $id . "." . $rev;

	_set_magickal_options($source, undef);
	my $full_path = "$product_www_root/images/products/$path/$filename.full.jpg";
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

	if (0) {    # too slow, not very effective
		$log->trace("performing adaptive threshold") if $log->is_trace();

		$img2->AdaptiveThreshold(width => $window, height => $window);
		$img2->Write("jpeg:$product_www_root/images/products/$path/$filename.full.lat.jpg");
	}

	$log->debug("generating resized versions") if $log->is_debug();

	# Generate resized versions

	foreach my $max ($thumb_size, $small_size, $display_size) {    # $zoom_size -> too big?

		my ($w, $h) = ($nw, $nh);
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
		my $geometry2 = $w . 'x' . $h;
		my $img = $cropped_source->Clone();
		$img->Resize(geometry => "$geometry2^");
		$img->Extent(
			geometry => "$geometry2",
			gravity => "center"
		);
		_set_magickal_options($img, $w);

		my $final_path = "$product_www_root/images/products/$path/$filename.$max.jpg";
		my $imagemagick_error = $img->Write("jpeg:${final_path}");
		if (($imagemagick_error) and ($imagemagick_error =~ /(\d+)/) and ($1 >= 400))
		{    # ImageMagick returns a string starting with a number greater than 400 for errors
			$log->error("could not write final cropped image", {path => $final_path, error => $imagemagick_error})
				if $log->is_error();
		}
		else {
			$log->info("wrote final cropped image", {path => $final_path}) if $log->is_info();
		}

		# temporary fields
		$new_product_ref->{"images.$id.$max"} = "$filename.$max";
		$new_product_ref->{"images.$id.$max.w"} = $img->Get('width');
		$new_product_ref->{"images.$id.$max.h"} = $img->Get('height');

	}

	# Update the product image data
	my $product_ref = retrieve_product($product_id);
	defined $product_ref->{images} or $product_ref->{images} = {};
	$product_ref->{images}{$id} = {
		imgid => $imgid,
		rev => $rev,
		angle => $angle,
		x1 => $x1,
		y1 => $y1,
		x2 => $x2,
		y2 => $y2,
		coordinates_image_size => $coordinates_image_size,
		geometry => $geometry,
		normalize => $normalize,
		white_magic => $white_magic,
		sizes => {
			full => {w => $nw, h => $nh},
		}
	};

	foreach my $max ($thumb_size, $small_size, $display_size) {    # $zoom_size
		$product_ref->{images}{$id}{sizes}{$max}
			= {w => $new_product_ref->{"images.$id.$max.w"}, h => $new_product_ref->{"images.$id.$max.h"}};
	}

	store_product($user_id, $product_ref, "new image $id : $imgid.$rev");

	$log->trace("image crop done") if $log->is_trace();
	return $product_ref;
}

sub process_image_unselect ($user_id, $product_id, $id) {

	my $path = product_path_from_id($product_id);

	local $log->context->{product_id} = $product_id;
	local $log->context->{id} = $id;

	$log->info("unselecting image") if $log->is_info();

	# Update the product image data
	my $product_ref = retrieve_product($product_id);
	defined $product_ref->{images} or $product_ref->{images} = {};
	if (defined $product_ref->{images}{$id}) {
		delete $product_ref->{images}{$id};
	}

	# also remove old images without language id (selected before product pages became multilingual)

	if ($id =~ /(.*)_(.*)/) {
		$id = $1;
		my $id_lc = $2;

		if ($product_ref->{lc} eq $id_lc) {
			if (defined $product_ref->{images}{$id}) {
				delete $product_ref->{images}{$id};
			}
		}
	}

	store_product($user_id, $product_ref, "unselected image $id");

	$log->debug("unselected image") if $log->is_debug();
	return $product_ref;
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

# TODO: This function should be removed once we switch to knowledge pages to display
sub display_image_thumb ($product_ref, $id_lc) {

	# $id_lc = shift  ->  id_lc = [front|ingredients|nutrition|packaging]_[lc]

	my $imagetype = $id_lc;
	my $display_lc = $lc;

	if ($id_lc =~ /^(.*)_(.*)$/) {
		$imagetype = $1;
		$display_lc = $2;
	}

	my $html = '';

	my $css = "";

	# Gray out images of obsolete products
	if ((defined $product_ref->{obsolete}) and ($product_ref->{obsolete})) {
		$css = 'style="filter: grayscale(100%)"';
	}

	# first try the requested language
	my @display_ids = ($imagetype . "_" . $display_lc);

	# next try the main language of the product
	if ($product_ref->{lc} ne $display_lc) {
		push @display_ids, $imagetype . "_" . $product_ref->{lc};
	}

	# last try the field without a language (for old products without updated images)
	push @display_ids, $imagetype;

	my $images_subdomain = format_subdomain('images');
	my $static_subdomain = format_subdomain('static');
	foreach my $id (@display_ids) {

		if (    (defined $product_ref->{images})
			and (defined $product_ref->{images}{$id})
			and (defined $product_ref->{images}{$id}{sizes})
			and (defined $product_ref->{images}{$id}{sizes}{$thumb_size}))
		{

			my $path = product_path($product_ref);
			my $rev = $product_ref->{images}{$id}{rev};
			my $alt = remove_tags_and_quote($product_ref->{product_name}) . ' - ' . $Lang{$imagetype . '_alt'}{$lang};

			$html .= <<HTML
<img src="$images_subdomain/images/products/$path/$id.$rev.$thumb_size.jpg" width="$product_ref->{images}{$id}{sizes}{$thumb_size}{w}" height="$product_ref->{images}{$id}{sizes}{$thumb_size}{h}" srcset="$images_subdomain/images/products/$path/$id.$rev.$small_size.jpg 2x" alt="$alt" loading="lazy" $css/>
HTML
				;

			last;
		}
	}

	# No image
	if ($html eq '') {

		$html = <<HTML
<img src="$static_subdomain/images/svg/product-silhouette.svg" style="width:$thumb_size;height:$thumb_size">
</img>
HTML
			;
	}

	return $html;
}

sub display_image ($product_ref, $id_lc, $size) {

	# $id_lc = shift  ->  id_lc = [front|ingredients|nutrition|packaging]_[lc]
	# $size  = shift  ->  currently = $small_size , 200px

	my $html = '';

	my $imagetype = $id_lc;
	my $display_lc = $lc;

	if ($id_lc =~ /^(.*)_(.*)$/) {
		$imagetype = $1;
		$display_lc = $2;
	}

	# first try the requested language
	my @display_ids = ($imagetype . "_" . $display_lc);

	# next try the main language of the product
	if ($product_ref->{lc} ne $display_lc) {
		push @display_ids, $imagetype . "_" . $product_ref->{lc};
	}

	# last try the field without a language (for old products without updated images)
	push @display_ids, $imagetype;

	foreach my $id (@display_ids) {

		if (    (defined $product_ref->{images})
			and (defined $product_ref->{images}{$id})
			and (defined $product_ref->{images}{$id}{sizes})
			and (defined $product_ref->{images}{$id}{sizes}{$size}))
		{

			my $path = product_path($product_ref);
			my $rev = $product_ref->{images}{$id}{rev};
			my $alt = remove_tags_and_quote($product_ref->{product_name}) . ' - ' . $Lang{$imagetype . '_alt'}{$lang};
			if ($id eq ($imagetype . "_" . $display_lc)) {
				$alt
					= remove_tags_and_quote($product_ref->{product_name}) . ' - '
					. $Lang{$imagetype . '_alt'}{$lang} . ' - '
					. $display_lc;
			}
			elsif ($id eq ($imagetype . "_" . $product_ref->{lc})) {
				$alt
					= remove_tags_and_quote($product_ref->{product_name}) . ' - '
					. $Lang{$imagetype . '_alt'}{$lang} . ' - '
					. $product_ref->{lc};
			}

			if (not defined $product_ref->{jqm}) {
				my $noscript = "<noscript>";

				# add srcset with 2x image only if the 2x image exists
				my $srcset = '';
				if (defined $product_ref->{images}{$id}{sizes}{$display_size}) {
					$srcset = "srcset=\"/images/products/$path/$id.$rev.$display_size.jpg 2x\"";
				}

				$html .= <<HTML
<img class="hide-for-xlarge-up" src="/images/products/$path/$id.$rev.$size.jpg" $srcset width="$product_ref->{images}{$id}{sizes}{$size}{w}" height="$product_ref->{images}{$id}{sizes}{$size}{h}" alt="$alt" itemprop="thumbnail" loading="lazy" />
HTML
					;

				$srcset = '';
				if (defined $product_ref->{images}{$id}{sizes}{$zoom_size}) {
					$srcset = "srcset=\"/images/products/$path/$id.$rev.$zoom_size.jpg 2x\"";
				}

				$html .= <<HTML
<img class="show-for-xlarge-up" src="/images/products/$path/$id.$rev.$display_size.jpg" $srcset width="$product_ref->{images}{$id}{sizes}{$display_size}{w}" height="$product_ref->{images}{$id}{sizes}{$display_size}{h}" alt="$alt" itemprop="thumbnail" loading="lazy" />
HTML
					;

				if (($size eq $small_size) and (defined $product_ref->{images}{$id}{sizes}{$display_size})) {

					my $title = lang($id . '_alt');

					my $full_image_url = "/images/products/$path/$id.$product_ref->{images}{$id}{rev}.full.jpg";
					my $representative_of_page = '';
					if ($id eq 'front') {
						$representative_of_page = 'true';
					}
					else {
						$representative_of_page = 'false';
					}

					$noscript .= "</noscript>";
					$html = $html . $noscript;
					$html = <<"HTML"
<a data-reveal-id="drop_$id" class="th">
$html
</a>
<div id="drop_$id" class="reveal-modal" data-reveal aria-labelledby="modalTitle_$id" aria-hidden="true" role="dialog" about="$full_image_url" >
<h2 id="modalTitle_$id">$title</h2>
<img src="$full_image_url" alt="$alt" itemprop="contentUrl" loading="lazy" />
<a class="close-reveal-modal" aria-label="Close" href="#">&#215;</a>
<meta itemprop="representativeOfPage" content="$representative_of_page"/>
<meta itemprop="license" content="https://creativecommons.org/licenses/by-sa/3.0/"/>
<meta itemprop="caption" content="$alt"/>
</div>
<meta itemprop="imgid" content="$id"/>
HTML
						;

				}

			}
			else {
				# jquery mobile for Cordova app
				$html .= <<HTML
<img src="/images/products/$path/$id.$rev.$size.jpg" width="$product_ref->{images}{$id}{sizes}{$size}{w}" height="$product_ref->{images}{$id}{sizes}{$size}{h}" alt="$alt" />
HTML
					;
			}

			last;
		}

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

=head4 OCR engine $ocr_engine

Either "tesseract" or "google_cloud_vision"

=head4 Results reference $results_ref

A hash reference to store the results.

=cut

sub extract_text_from_image ($product_ref, $id, $field, $ocr_engine, $results_ref) {

	delete $product_ref->{$field};

	my $path = product_path($product_ref);
	$results_ref->{status} = 1;    # 1 = nok, 0 = ok

	my $filename = '';

	my $lc = $product_ref->{lc};

	if ($id =~ /_(\w\w)$/) {
		$lc = $1;
	}

	my $size = 'full';
	if (    (defined $product_ref->{images})
		and (defined $product_ref->{images}{$id})
		and (defined $product_ref->{images}{$id}{sizes})
		and (defined $product_ref->{images}{$id}{sizes}{$size}))
	{
		$filename = $id . '.' . $product_ref->{images}{$id}{rev};
	}
	else {
		return;
	}

	my $image = "$www_root/images/products/$path/$filename.full.jpg";
	my $image_url = format_subdomain('static') . "/images/products/$path/$filename.full.jpg";

	my $text;

	$log->debug("extracting text from image", {id => $id, ocr_engine => $ocr_engine}) if $log->is_debug();

	if ($ocr_engine eq 'tesseract') {

		my $lan;

		if (defined $ProductOpener::Config::tesseract_ocr_available_languages{$lc}) {
			$lan = $ProductOpener::Config::tesseract_ocr_available_languages{$lc};
		}
		elsif (defined $ProductOpener::Config::tesseract_ocr_available_languages{$product_ref->{lc}}) {
			$lan = $ProductOpener::Config::tesseract_ocr_available_languages{$product_ref->{lc}};
		}
		elsif (defined $ProductOpener::Config::tesseract_ocr_available_languages{en}) {
			$lan = $ProductOpener::Config::tesseract_ocr_available_languages{en};
		}

		$log->debug("extracting text with tesseract", {lc => $lc, lan => $lan, id => $id, image => $image})
			if $log->is_debug();

		if (defined $lan) {
			$text = decode utf8 => get_ocr($image, undef, $lan);

			if ((defined $text) and ($text ne '')) {
				$results_ref->{$field} = $text;
				$results_ref->{status} = 0;
			}
		}
		else {
			$log->warn("no available tesseract dictionary", {lc => $lc, lan => $lan, id => $id}) if $log->is_warn();
		}
	}
	elsif ($ocr_engine eq 'google_cloud_vision') {

		my $json_file = "$www_root/images/products/$path/$filename.json.gz";
		open(my $gv_logs, ">>:encoding(UTF-8)", "$data_root/logs/cloud_vision.log");
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
			$results_ref->{status} = 0;
			$product_ref->{images}{$id}{ocr} = 1;
			$product_ref->{images}{$id}{orientation}
				= compute_orientation_from_cloud_vision_annotations($cloudvision_ref);
		}
		else {
			$product_ref->{images}{$id}{ocr} = 0;
		}
	}
	return;
}

@CLOUD_VISION_FEATURES_FULL = (
	{type => 'TEXT_DETECTION'},
	{type => 'LOGO_DETECTION'},
	{type => 'LABEL_DETECTION'},
	{type => 'SAFE_SEARCH_DETECTION'},
	{type => 'FACE_DETECTION'},
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
	print($gv_logs "CV:sending to $url\n");

	my $ua = LWP::UserAgent->new();

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
	# $log->info("google cloud vision response", { json_response => $cloud_vision_response->decoded_content, api_token => $ProductOpener::Config::google_cloud_vision_api_key });

	my $cloudvision_ref = undef;
	if ($cloud_vision_response->is_success) {

		$log->info("request to google cloud vision was successful for $image_path") if $log->is_info();

		my $json_response = $cloud_vision_response->decoded_content(charset => 'UTF-8');

		$cloudvision_ref = decode_json($json_response);

		# Adding creation timestamp, to know when the OCR has been generated
		$cloudvision_ref->{created_at} = time();

		$log->info("saving google cloud vision json response to file", {path => $json_file}) if $log->is_info();

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

=head2 send_image_to_robotoff ($code, $image_url, $json_url, $api_server_domain)

Send a notification about a new image (already gone through OCR) to Robotoff

=head3 Arguments

=head4 $code - product code

=head4 $image_url - public url of the image

=head4 $json_url - public url of OCR result as JSON

=head4 $api_server_domain - the API url for this product opener instance

=head3 Response

Return Robotoff HTTP::Response object.

=cut

sub send_image_to_robotoff ($code, $image_url, $json_url, $api_server_domain) {

	my $ua = LWP::UserAgent->new();

	my $robotoff_response = $ua->post(
		$robotoff_url . "/api/v1/images/import",
		{
			'barcode' => $code,
			'image_url' => $image_url,
			'ocr_url' => $json_url,
			'server_domain' => $api_server_domain,
		}
	);

	if ($robotoff_response->is_success) {
		$log->info("request to robotoff was successful") if $log->is_info();
	}
	else {
		$log->warn(
			"robotoff request not successful",
			{
				code => $robotoff_response->code,
				response => $robotoff_response->message,
				status_line => $robotoff_response->status_line
			}
		) if $log->is_warn();
	}
	return $robotoff_response;
}

1;
