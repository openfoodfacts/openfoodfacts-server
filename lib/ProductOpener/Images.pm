# This file is part of Product Opener.
# 
# Product Opener
# Copyright (C) 2011-2016 Association Open Food Facts
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


package ProductOpener::Images;

use utf8;
use Modern::Perl '2012';
use Exporter    qw< import >;

BEGIN
{
	use vars       qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@EXPORT = qw();            # symbols to export by default
	@EXPORT_OK = qw(
					&generate_banner
					&generate_mosaic_background
					&display_image_form
					&process_image_form
					
					&display_search_image_form
					&process_search_image_form
					
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
	
					);	# symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;

use ProductOpener::Store qw/:all/;
use ProductOpener::Config qw/:all/;
use ProductOpener::Products qw/:all/;

use CGI qw/:cgi :form escapeHTML/;

use Image::Magick;
use Graphics::Color::RGB;
use Graphics::Color::HSL;
use Barcode::ZBar;
use ProductOpener::Products qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::URL qw/:all/;

my $debug = 1;


sub display_select_manage($) {

	my $object_ref = shift;
	my $id = "manage";
	
	my $html = <<HTML
<div class=\"select_crop select_manage\" id=\"$id\"></div>
<hr class="floatclear" />
HTML
;
	
	return $html;
}



sub display_select_crop($$) {

	my $object_ref = shift;
	my $id_lc = shift;	#  id_lc = [front|ingredients|nutrition]_[lc] 
	my $id = $id_lc;
	
	my $imagetype = $id_lc;
	my $display_lc = $lc;
	
	if ($id_lc =~ /^(.*)_(.*)$/) {
		$imagetype = $1;
		$display_lc = $2;
	}
		
	my $note = '';
	if (defined $Lang{"image_" . $imagetype . "_note"}{$lang}) {
		$note = "<p class=\"note\">&rarr; " . $Lang{"image_" . $imagetype . "_note"}{$lang} . "</p>";
	}
		
	my $html = <<HTML
<label for="$id">$Lang{"image_" . $imagetype}{$lang}</label>
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
		$html .= '<input type="hidden" name="' . "${id}_$field" . '" id="' . "${id}_$field" . '" value="' . $value . '" />' . "\n";
	}
	my $size = $display_size;
	my $product_ref = $object_ref;
	my $display_url = '';
	if ((defined $product_ref->{images}) and (defined $product_ref->{images}{$id})
		and (defined $product_ref->{images}{$id}{sizes}) and (defined $product_ref->{images}{$id}{sizes}{$size})) {
		$display_url = "$id." . $product_ref->{images}{$id}{rev} . ".$display_size.jpg";
	}
	$html .= '<input type="hidden" name="' . "${id}_display_url" . '" id="' . "${id}_display_url" . '" value="' . $display_url . '" />' . "\n";
	
	return $html;
}


sub display_select_crop_init($) {

	my $object_ref = shift;
	my $path = product_path($object_ref->{code});

	my $images = '';
	
	defined $object_ref->{images} or $object_ref->{images} = {};
	
	for (my $imgid = 1; $imgid <= ($object_ref->{max_imgid} + 5); $imgid++) {
		if (defined $object_ref->{images}{$imgid}) {
			my $admin_fields = '';
			if ($admin) {
				$admin_fields = ", uploader: '" . $object_ref->{images}{$imgid}{uploader} . "', uploaded: '" . display_date($object_ref->{images}{$imgid}{uploaded_t}) . "'";
			}
			$images .= <<JS
{imgid: "$imgid", thumb_url: "$imgid.$thumb_size.jpg", crop_url: "$imgid.$crop_size.jpg", display_url: "$imgid.$display_size.jpg" $admin_fields},
JS
;
		}
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


sub scan_code($) {

	my $file = shift;
	my $code = undef;
	
	# create a reader
	my $scanner = Barcode::ZBar::ImageScanner->new();

	# configure the reader
	$scanner->parse_config("enable");

	# obtain image data
	my $magick = Image::Magick->new();
	my $x = $magick->Read($file);
	if ("$x") {
		print STDERR "Images::scan_code - cannot read file $file : $x\n";
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
			# print STDERR "Images::scan_code - $n symbols found\n";

			# extract results
			foreach my $symbol ($image->get_symbols()) {

				$code = $symbol->get_data();
				my $type = $symbol->get_type();
				print STDERR "Images::scan_code - found code: $code - type: $type\n";
				if (($code !~ /^[0-9]+$/) or ($type eq 'QR-Code')) {
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

	return $code;
}




sub display_search_image_form($) {

	my $id = shift;

	my $html = '';
	
	my $product_image_with_barcode = $Lang{product_image_with_barcode}{$lang};
	$product_image_with_barcode =~ s/( |\&nbsp;)?:$//;
	
	$html .= <<HTML
<div id="imgsearchdiv_$id">

<a href="#" class="button small expand" id="imgsearchbutton_$id"><i class="fi-camera"></i> $product_image_with_barcode
<input type="file" accept="image/*" capture="camera" class="img_input" name="imgupload_search" id="imgupload_search_$id" style="position: absolute;
    right:0;
    bottom:0;
    top:0;
    cursor:pointer;
    opacity:0;
    font-size:40px;"/>
</a>
</div>

<div id="progressbar_$id" class="progress" style="display:none">
  <span id="progressmeter_$id" class="meter" style="width:0%"></span>
</div>

<div id="imgsearchmsg_$id" data-alert class="alert-box info" style="display:none">
  $Lang{sending_image}{$lang}
  <a href="#" class="close">&times;</a>
</div>

<div id="imgsearcherror_$id" data-alert class="alert-box alert" style="display:none">
  $Lang{send_image_error}{$lang}
  <a href="#" class="close">&times;</a>
</div>

HTML
;


	$scripts .= <<JS
<script src="/js/jquery.iframe-transport.min.js"></script>
<script src="/js/jquery.fileupload.min.js"></script>	
<script src="/js/load-image.min.js"></script>
<script src="/js/canvas-to-blob.min.js"></script>
<script src="/js/jquery.fileupload-ip.min.js"></script>
JS
;

	$initjs .= <<JS
	
\/\/ start off canvas blocks for small screens
	
    \$('#imgupload_search_$id').fileupload({
        dataType: 'json',
        url: '/cgi/product.pl',
		formData : [{name: 'jqueryfileupload', value: 1}],
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
	
	return $html;
}






sub process_search_image_form($) {
	
	my $filename_ref = shift;
	
	my $imgid = "imgupload_search";
	my $file = undef;
	my $code = undef;
	if ($file = param($imgid)) {
		if ($file =~ /\.(gif|jpeg|jpg|png)$/i) {
			
			print STDERR "Images.pm - process_search_image_form - imgid: $imgid - file: $file\n";
		
			my $extension = lc($1) ;
			my $filename = get_fileid(remote_addr(). '_' . $`);
			
			open (my $out, ">", "$data_root/tmp/$filename.$extension") ;
			while (my $chunk = <$file>) {
				print $out $chunk;
			}
			close ($out);
			
			$code = scan_code("$data_root/tmp/$filename.$extension");
			if (defined $code) {
				$code = normalize_code($code);
			}
			$$filename_ref = "$data_root/tmp/$filename.$extension";
		}
	}	
	return $code;
}


sub process_image_upload($$$$$$) {

	my $code = shift;
	my $imagefield = shift;
	my $userid = shift; 
	my $time = shift; # usually current time (images just uploaded), except for images moved from another product
	my $comment = shift;
	my $imgid_ref = shift; # to return the imgid (new image or existing image)
	
	my $bogus_imgid;
	not defined $imgid_ref and $imgid_ref = \$bogus_imgid;
	
	my $path = product_path($code);
	my $imgid = -1;
	
	my $new_product_ref = {};
	
	
	my $file = undef;
	
	# Image that was already read by barcode scanner: can't read it again
	my $tmp_filename;
	if ($imagefield =~ /\//) {
		$tmp_filename = $imagefield;
		$imagefield = 'search';
		
			if ($tmp_filename) {
				open ($file, q{<}, "$tmp_filename");
			}		
	}
	else {
		$file = param('imgupload_' . $imagefield);
		if (! $file) {
			# mobile app may not set language code
			my $old_imagefield = $imagefield;
			$old_imagefield =~ s/_\w\w$//;
			$file = param('imgupload_' . $old_imagefield);
		}
	}
	

	if ($file) {
	
		print STDERR "Images.pm - process_image_upload - imagefield: $imagefield - file: $file - uploader: $userid - time: $time\n";

	
		if ($file !~ /\.(gif|jpeg|jpg|png)$/i) {
			# We have a "blob" without file name and extension?
			# try to assume it is jpeg (and let ImageMagick read it anyway if it's something else)
			# $file .= ".jpg";
		}
		
		if (1 or ($file =~ /\.(gif|jpeg|jpg|png)$/i)) {
			print STDERR "Images.pm - process_image_upload - imagefield: $imagefield - file: $file - format ok\n";
			
			my $extension = 'jpg';
			if (defined $1) {
				$extension = lc($1) ;
			}
			$extension eq 'jpeg' and $extension = 'jpg';
			my $filename = get_fileid(remote_addr(). '_' . $`);
			
			my $current_product_ref = retrieve_product($code);
			$imgid = $current_product_ref->{max_imgid} + 1;
			
			# if for some reason the images directories were not created at product creation (it can happen if the images directory's permission / ownership are incorrect at some point)
			# create them
			
			# Create the directories for the product
			foreach my $current_dir  ($www_root . "/images/products") {
				(-e "$current_dir") or mkdir($current_dir, 0755);
				foreach my $component (split("/", $path)) {
					$current_dir .= "/$component";
					(-e "$current_dir") or mkdir($current_dir, 0755);
				}
			}
			
			
			while (-e "$www_root/images/products/$path/$imgid.lock") {
				$imgid++;
			}
			mkdir ("$www_root/images/products/$path/$imgid.lock", 0755) or print STDERR "Images.pm - Error - Could not create lock $www_root/images/products/$path/$imgid.lock : $!\n";
			


			open (my $out, ">", "$www_root/images/products/$path/$imgid.$extension") or print STDERR "Images.pm - Error - Could not save $www_root/images/products/$path/$imgid.$extension : $!\n";
			while (my $chunk = <$file>) {
				print $out $chunk;
			}
			close ($out);


			
			
			# Keep original in case we need it later
			
			
			# Generate resized versions
					
			my $source = Image::Magick->new;			
			my $x = $source->Read("$www_root/images/products/$path/$imgid.$extension");
			$source->AutoOrient();
			$source->Strip(); #remove orientation data and all other metadata (EXIF)
			
			# Save a .jpg if we were sent something else (always re-save as the image can be rotated)
			#if ($extension ne 'jpg') {
				$source->Set('quality',95);
				$x = $source->Write("jpeg:$www_root/images/products/$path/$imgid.jpg");
			#}
			
			# Check that we don't already have the image

			my $size = -s "$www_root/images/products/$path/$imgid.$extension";
			print STDERR "size of $www_root/images/products/$path/$imgid.$extension : $size \n" . (-s "$www_root/images/products/$path/$imgid.$extension") . "\n";
			for (my $i = 0; $i < $imgid; $i++) {
				print STDERR "existing image $i - size: " . (-s "$www_root/images/products/$path/$i.$extension") . " -- $imgid size: $size\n";
				if ((-s "$www_root/images/products/$path/$i.$extension") == $size) {
					print STDERR "image $imgid has same size $size than $www_root/images/products/$path/$i.$extension : deleting $www_root/images/products/$path/$imgid.$extension\n";
					unlink "$www_root/images/products/$path/$imgid.$extension";
					rmdir ("$www_root/images/products/$path/$imgid.lock");
					$$imgid_ref = $i;
					return -3;
				}
			}			
			
			("$x") and print STDERR "Images::generate_image - cannot read $www_root/images/products/$path/$imgid.$extension $x\n";

			# Check the image is big enough so that we do not get thumbnails from other sites
			if (($source->Get('width') < 640) and ($source->Get('height') < 160)) {
				unlink "$www_root/images/products/$path/$imgid.$extension";
				rmdir ("$www_root/images/products/$path/$imgid.lock");
				return -4;
			}
			
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
				$img->Resize(geometry=>"$geometry^");
				$img->Extent(geometry=>"$geometry",
					gravity=>"center");
				_set_magickal_options($img, $w);

				my $x = $img->Write("jpeg:$www_root/images/products/$path/$imgid.$max.jpg");
				if ("$x") {
					print STDERR "Images::process_image_upload - could not write jpeg:$www_root/images/products/$path/$imgid.$max.jpg: $x\n";
				}
				else {
					print STDERR "Images::process_image_upload - wrote jpeg:$www_root/images/products/$path/$imgid.$max.jpg\n";		
				}
				
				$new_product_ref->{"images.$imgid.$max"} = "$imgid.$max";
				$new_product_ref->{"images.$imgid.$max.w"} = $img->Get('width');
				$new_product_ref->{"images.$imgid.$max.h"} = $img->Get('height');

			}

			if (not "$x") {
			
			
			# Update the product image data
			my $product_ref = retrieve_product($code);
			defined $product_ref->{images} or $product_ref->{images} = {};
			$product_ref->{images}{$imgid} = {
				uploader => $userid,
				uploaded_t => $time,			
				sizes => {				
					full => {w => $new_product_ref->{"images.$imgid.w"}, h => $new_product_ref->{"images.$imgid.h"}},
				},
			};

			foreach my $max ($thumb_size, $crop_size) {
			
				$product_ref->{images}{$imgid}{sizes}{$max} =
					{w => $new_product_ref->{"images.$imgid.$max.w"}, h => $new_product_ref->{"images.$imgid.$max.h"}};
	
			}
			if ($imgid > $product_ref->{max_imgid}) {
				$product_ref->{max_imgid} = $imgid;
			}
			my $store_comment = "new image $imgid";
			if ((defined $comment) and ($comment ne '')) {
				$store_comment .= ' - ' . $comment;
			}
			store_product($product_ref, $store_comment);
			
			}
			else {
				# Could not read image
				$imgid = -5;
			}
			
			rmdir ("$www_root/images/products/$path/$imgid.lock");
		}
		
		# make sure to close the file so that it does not stay in /tmp forever
		#close ($file);
		#unlink($file);
		my $tmpfilename = tmpFileName($file);
		print STDERR "product_image_upload.pl -- unlinking $file - $tmpfilename\n";
		unlink ($tmpfilename);
		
	}
	else {
		print STDERR "Images::process_image_upload - field imgupload_$imagefield not set.\n";
		$imgid = -2;
	}
	print STDERR "Images::process_image_upload - return imgid: $imgid - imagefield: $imagefield\n";
	
	$$imgid_ref = $imgid;
	
	return $imgid;
}



sub process_image_move($$$$) {

	my $code = shift;
	my $imgids = shift;
	my $move_to = shift;
	my $userid = shift;

	my $path = product_path($code);
	
	my $product_ref = retrieve_product($code);
	defined $product_ref->{images} or $product_ref->{images} = {};
	
	# move images only to trash or another valid barcode (number)
	if (($move_to ne 'trash') and ($move_to !~ /^\d+$/)) {
		return "invalid barcode number: $move_to";
	}
	
	# iterate on each images
	
	
	foreach my $imgid (split(/,/, $imgids)) {
	
		next if ($imgid !~ /^\d+$/);
	
		# check the imgid exists
		if (defined $product_ref->{images}{$imgid}) {
		
			my $ok = 1;
	
			if ($move_to =~ /^\d+$/) {
				$ok = process_image_upload($move_to, "$www_root/images/products/$path/$imgid.jpg", $product_ref->{images}{$imgid}{uploader}, $product_ref->{images}{$imgid}{uploaded_t}, "image moved from product $code by $userid -- uploader: $product_ref->{images}{$imgid}{uploader} - time: $product_ref->{images}{$imgid}{uploaded_t}", undef);
				print STDERR "Images.pm - products_image_move - moving $www_root/images/products/$path/$imgid.jpg to $code by $userid - result: $ok (negative: error)\n";
			}
			
			# Don't delete images to be moved if they weren't moved correctly
			if ($ok) {
				# Delete images (move them to the deleted.images dir
				
				-e "$data_root/deleted.images" or mkdir("$data_root/deleted.images", 0755);
				
				use File::Copy;
				
				print STDERR "Images.pm - products_image_move - deleting  $www_root/images/products/$path/$imgid.jpg --> $data_root/deleted.images/product.$code.$imgid.jpg\n";
				
				move("$www_root/images/products/$path/$imgid.jpg", "$data_root/deleted.images/product.$code.$imgid.jpg");
				move("$www_root/images/products/$path/$imgid.$thumb_size.jpg", "$data_root/deleted.images/product.$code.$imgid.$thumb_size.jpg");
				move("$www_root/images/products/$path/$imgid.$crop_size.jpg", "$data_root/deleted.images/product.$code.$imgid.$crop_size.jpg");
				
				delete $product_ref->{images}{$imgid};				
			
			}
		
		}
	
	}
	
	store_product($product_ref, "Moved images $imgids to $move_to");
	
	return 0;
}


sub process_image_crop($$$$$$$$$$) {

	my $code = shift;
	my $id = shift;
	my $imgid = shift;
	my $angle = shift;
	my $normalize = shift;
	my $white_magic = shift;
	my $x1 = shift;
	my $y1 = shift;
	my $x2 = shift;
	my $y2 = shift;
	
	my $path = product_path($code);
	
	my $new_product_ref = retrieve_product($code);
	my $rev = $new_product_ref->{rev} + 1;	# For naming images
	
	print STDERR "Images.pm - process_image_crop - code: $code - id: $id - imgid: $imgid\n";
			
	my $source = Image::Magick->new;			
	my $x = $source->Read("$www_root/images/products/$path/$imgid.jpg");
	("$x") and print STDERR "Images::process_image_crop - cannot read $www_root/images/products/$path/$imgid.jpg $x\n";

	if ($angle != 0) {
		$source->Rotate($angle);
	}
	
	# Crop the image
	my $ow = $source->Get('width');
	my $oh = $source->Get('height');
	my $w = $new_product_ref->{images}{$imgid}{sizes}{$crop_size}{w};
	my $h = $new_product_ref->{images}{$imgid}{sizes}{$crop_size}{h};
	
	if (($angle % 180) == 90) {
		my $z = $w;
		$w = $h;
		$h = $z;
	}
	
	my $ox1 = int($x1 * $ow / $w);
	my $oy1 = int($y1 * $oh / $h);
	my $ox2 = int($x2 * $ow / $w);
	my $oy2 = int($y2 * $oh / $h);
	
	my $nw = $ox2 - $ox1; # new width
	my $nh = $oy2 - $oy1;
	
	my $geometry = "${nw}x${nh}\+${ox1}\+${oy1}";
	print STDERR "Images::process_image_crop - geometry: $geometry ($ox1,$oy1 - $ox2,$oy2) - w: $w - h: $h \n";
	if ($nw > 0) { # image not cropped
		my $x = $source->Crop(geometry=>$geometry);
		("$x") and print STDERR "Images::process_image_crop - could not crop to geometry: $geometry $x\n";
	}
	
	$nw = $source->Get('width');
	$nh = $source->Get('height');	
	
	$geometry =~ s/\+/-/g;
	
	my $filename = "$id.$imgid";
	
	if ((defined $white_magic) and (($white_magic eq 'checked') or ($white_magic eq 'true'))) {
		$filename .= ".white";

		my $image = $source;
	
		print STDERR "magic\n";

		$image->Normalize( channel=>'RGB' );

		
		my $w = $image->Get('width');
		my $h = $image->Get('height');
		my $background = Image::Magick->new();
		$background->Set(size=>'2x2');
		my $x = $background->ReadImage('xc:white');
		my @rgb;
		@rgb = $image->GetPixel(x=>0,y=>0);
		$background->SetPixel(x=>0,y=>0, color=>\@rgb);
			
		@rgb = $image->GetPixel(x=>$w-1,y=>0);
		$background->SetPixel(x=>1,y=>0, color=>\@rgb);
		
		@rgb = $image->GetPixel(x=>0,y=>$h-1);
		$background->SetPixel(x=>0,y=>1, color=>\@rgb);
		
		@rgb = $image->GetPixel(x=>$w-1,y=>$h-1);
		$background->SetPixel(x=>1,y=>1, color=>\@rgb);
		
		$background->Resize(geometry=>"${w}x${h}!");
		print STDERR "width " . $background->Get('width') . "\n";
		print STDERR "Writing: $www_root/images/products/$path/$imgid.${crop_size}.background.jpg\n";
		$x = $background->Write("jpeg:$www_root/images/products/$path/$imgid.${crop_size}.background.jpg");
		$x and print SDTERR "product_image_rotate.pl - could not write image : $x\n";
		

		#$image->Negate();
		#$background->Modulate(brightness=>95);
		#$background->Negate();
		#$x = $image->Composite(image=>$background, compose=>"Divide");
		

		#$background->Modulate(brightness=>130);
		$x = $image->Composite(image=>$background, compose=>"Minus");
		$x and print STDERR "product_image_rotate.pl - magic composite failed: $x \n";
		
		$image->Negate();
		#$image->Normalize( channel=>'RGB' );
		
		#$x = $image->Composite(image=>$background, compose=>"Screen");
		#$image->Negate();	
 
 
 
		if (0) { # Too slow, could work well with some tuning...
		my $original = $image->Clone();
		my @white = (1,1,1);
 
		my $distance = sub ($$) {
			my $a = shift;
			my $b = shift;
			
			my $d = ($a->[0] - $b->[0]) * ($a->[0] - $b->[0]) + ($a->[1] - $b->[1]) * ($a->[1] - $b->[1]) + ($a->[2] - $b->[2]) * ($a->[2] - $b->[2]);
			return $d;
		};
 
		my @q = ([0,0],[0,$h-1],[0,int($h/2)],[int($w/2),0],[int($w/2),$h-1],[$w-1,0],[$w-1,$h-1],[$w-1,int($h/2)]);
		my $max_distance = 0.015*0.015;
		my $i = 0;
		my %seen;
		while (@q) {
			my $p = pop @q;
			my ($x,$y) = @$p;
			$seen{$x . ',' . $y} and next;
			$seen{$x . ',' . $y} = 1;
			(($x < 0) or ($x >= $w) or ($y < 0) or ($y > $h)) and next;
			@rgb = $image->GetPixel(x=>$x,y=>$y);
			#if (($rgb[0] == 1) and ($rgb[1] == 1) and ($rgb[2] == 1)) {
			#	next;
			#}
			$image->SetPixel(x=>$x,y=>$y, color=>\@white);
			($distance->(\@rgb, [$original->GetPixel(x=>$x+1,y=>$y)]) <= $max_distance) and push @q, [$x+1, $y];
			($distance->(\@rgb, [$original->GetPixel(x=>$x-1,y=>$y)]) <= $max_distance) and push @q, [$x-1, $y];
			($distance->(\@rgb, [$original->GetPixel(x=>$x,y=>$y+1)]) <= $max_distance) and push @q, [$x, $y+1];
			($distance->(\@rgb, [$original->GetPixel(x=>$x,y=>$y-1)]) <= $max_distance) and push @q, [$x, $y-1];
			
			($distance->(\@rgb, [$original->GetPixel(x=>$x+1,y=>$y+1)]) <= $max_distance) and push @q, [$x+1, $y+1];
			($distance->(\@rgb, [$original->GetPixel(x=>$x-1,y=>$y-1)]) <= $max_distance) and push @q, [$x-1, $y-1];
			($distance->(\@rgb, [$original->GetPixel(x=>$x-1,y=>$y+1)]) <= $max_distance) and push @q, [$x-1, $y+1];
			($distance->(\@rgb, [$original->GetPixel(x=>$x+1,y=>$y-1)]) <= $max_distance) and push @q, [$x+1, $y-1];			
			$i++;
			($i % 10000) == 0 and print STDERR "$i - x,y: $x,$y - rgb: $rgb[0],$rgb[1],$rgb[2] - width,height: $w,$h\n";
		}
		}
		
		# Remove dark corners
		if (1) {
		$x = $image->FloodfillPaint(x=>1,y=>1,fill=>"#ffffff", fuzz=>"5%", bordercolor=>"#ffffff");
		$x = $image->FloodfillPaint(x=>$w-1,y=>1,fill=>"#ffffff", fuzz=>"5%", bordercolor=>"#ffffff");
		$x = $image->FloodfillPaint(x=>1,y=>$h-1,fill=>"#ffffff", fuzz=>"5%", bordercolor=>"#ffffff");
		$x = $image->FloodfillPaint(x=>$w-1,y=>$h-1,fill=>"#ffffff", fuzz=>"5%", bordercolor=>"#ffffff");
		}
		elsif (0) { # use trim instead
			# $x = $image->Trim(fuzz=>"5%"); # fuzz factor does not work...
		}

		if (0) {
		my $n = 10;
		for (my $i = 0; $i <= $n; $i++) {
			$x = $image->FloodfillPaint(x=>int($i*($w-1)/$n),y=>0,fill=>"#ffffff", fuzz=>"5%", xbordercolor=>"#ffffff");
			$x = $image->FloodfillPaint(x=>int($i*($w-1)/$n),y=>$h-2,fill=>"#ffffff", fuzz=>"5%", xbordercolor=>"#ffffff");
		}
		$n = 10;
		for (my $i = 0; $i <= $n; $i++) {
			$x = $image->FloodfillPaint(y=>int($i*($h-1)/$n),x=>0,fill=>"#ffffff", fuzz=>"5%", xbordercolor=>"#ffffff");
			$x = $image->FloodfillPaint(y=>int($i*($h-1)/$n),x=>$w-2,fill=>"#ffffff", fuzz=>"5%", xbordercolor=>"#ffffff");
		}	
		}
		#$image->Deskew();
		
		$x and print SDTERR "product_image_rotate.pl - could not floodfill : $x\n";

	}	
	
	
	if ((defined $normalize) and (($normalize eq 'checked') or ($normalize eq 'true'))) {
		$source->Normalize( channel=>'RGB' );
		$filename .= ".normalize";
	}
	
	# Keep only one image, and overwrite previous images
	# ! cached images... add a version number
	$filename = $id . "." . $rev;
	
	_set_magickal_options($source, undef);
	$x = $source->Write("jpeg:$www_root/images/products/$path/$filename.full.jpg");
	("$x") and print STDERR "Images::process_image_crop - could not write jpeg:$www_root/images/products/$path/$filename.full.jpg $x\n";
	
	# Re-read cropped image
	my $cropped_source = Image::Magick->new;
	$x = $cropped_source->Read("$www_root/images/products/$path/$filename.full.jpg");
	("$x") and print STDERR "Images::process_image_crop - cannot read $www_root/images/products/$path/$filename.full.jpg $x\n";

	my $img2 = $cropped_source->Clone();
	my $window = $nw;
	($nh > $nw) and $window = $nh;
	$window = int($window / 3) + 1;
	
	if (0) { # too slow, not very effective
	print STDERR "Images::process_image_crop - AdaptiveThreshold \n";
	
	$img2->AdaptiveThreshold(width=>$window, height=>$window);
	$img2->Write("jpeg:$www_root/images/products/$path/$filename.full.lat.jpg");
	}
	
	print STDERR "Images::process_image_crop - Generating resized versions\n";	
	
	# Generate resized versions
					
	foreach my $max ($thumb_size, $small_size, $display_size) { # $zoom_size -> too big?
			
		my ($w, $h) = ($nw,$nh);
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
		$img->Resize(geometry=>"$geometry2^");
		$img->Extent(geometry=>"$geometry2",
			gravity=>"center");
		_set_magickal_options($img, $w);

		my $x = $img->Write("jpeg:$www_root/images/products/$path/$filename.$max.jpg");
		if ("$x") {
			print STDERR "Index::download_image - could not write jpeg:$www_root/images/products/$path/$filename.$max.jpg: $x\n";
		}
		else {
			print STDERR "Index::download_image - wrote jpeg:$www_root/images/products/$path/$filename.$max.jpg\n";		
		}
		
		# temporary fields
		$new_product_ref->{"images.$id.$max"} = "$filename.$max";
		$new_product_ref->{"images.$id.$max.w"} = $img->Get('width');
		$new_product_ref->{"images.$id.$max.h"} = $img->Get('height');

	}			
			
	# Update the product image data
	my $product_ref = retrieve_product($code);
	defined $product_ref->{images} or $product_ref->{images} = {};
	$product_ref->{images}{$id} = {
		imgid => $imgid,
		rev => $rev,
		angle => $angle,
		x1 => $x1,
		y1 => $y1,
		x2 => $x2,
		y2 => $y2,
		geometry => $geometry,
		normalize => $normalize,
		white_magic => $white_magic,
		sizes => {
			full => {w => $nw, h => $nh},
		}
	};

	foreach my $max ($thumb_size, $small_size, $display_size) { # $zoom_size
		$product_ref->{images}{$id}{sizes}{$max} =
			{w => $new_product_ref->{"images.$id.$max.w"}, h => $new_product_ref->{"images.$id.$max.h"}};
	}

	store_product($product_ref, "new image $id : $imgid.$rev");

	print STDERR "Index::process_image_crop done\n";
	return $product_ref;
}

sub process_image_unselect($$) {

	my $code = shift;
	my $id = shift;
	
	my $path = product_path($code);
		
	print STDERR "Images.pm - process_image_unselect - id: $id\n";
			
	# Update the product image data
	my $product_ref = retrieve_product($code);
	defined $product_ref->{images} or $product_ref->{images} = {};
	if (defined $product_ref->{images}{$id}) {
		delete $product_ref->{images}{$id};
	}

	store_product($product_ref, "unselected image $id");

	print STDERR "Index::process_image_unselect done\n";
	return $product_ref;
}

sub _set_magickal_options($$) {

	# https://www.smashingmagazine.com/2015/06/efficient-image-resizing-with-imagemagick/
	my $magick = shift;
	my $width = shift;

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
	$magick->Set(colorspace => 'sRGB');
	$magick->Strip();

}

sub display_image_thumb($$) {

	my $product_ref = shift;
	my $id_lc = shift;	#  id_lc = [front|ingredients|nutrition]_[lc] 
	
	my $imagetype = $id_lc;
	my $display_lc = $lc;
	
	if ($id_lc =~ /^(.*)_(.*)$/) {
		$imagetype = $1;
		$display_lc = $2;
	}
	
	my $html = '';
	
	# first try the requested language
	my @display_ids = ($imagetype . "_" . $display_lc);
	
	# next try the main language of the product
	if ($product_ref->{lc} ne $display_lc) {
		push @display_ids, $imagetype . "_" . $product_ref->{lc};
	}
	
	# last try the field without a language (for old products without updated images)
	push @display_ids, $imagetype;
	
	my $static = format_subdomain('static');
	foreach my $id (@display_ids) {
	
		if ((defined $product_ref->{images}) and (defined $product_ref->{images}{$id})
			and (defined $product_ref->{images}{$id}{sizes}) and (defined $product_ref->{images}{$id}{sizes}{$thumb_size})) {
		
			my $path = product_path($product_ref->{code});
			my $rev = $product_ref->{images}{$id}{rev};
			my $alt = remove_tags_and_quote($product_ref->{product_name}) . ' - ' . $Lang{$imagetype . '_alt'}{$lang};

				
			$html .= <<HTML
<img src="$static/images/products/$path/$id.$rev.$thumb_size.jpg" width="$product_ref->{images}{$id}{sizes}{$thumb_size}{w}" height="$product_ref->{images}{$id}{sizes}{$thumb_size}{h}" srcset="$static/images/products/$path/$id.$rev.$small_size.jpg 2x" alt="$alt" />
HTML
;		

			last;
		}
	}
	
	# If we don't have an image, display Pacman
	if ($html eq '') {
	
		my @colors = qw(
ff6600
ffcc00
55d400
00ccff
0066ff
ff00cc
cc00ff		
);
		my $color_id = $product_ref->{code} % (scalar @colors);
		my $color = $colors[$color_id];
	
		$html = <<HTML
<div style="background-color:#$color">
<img src="$static/images/misc/pacman.svg" width="$thumb_size" height="$thumb_size" alt="Please add pictures of the product if you have it!" />
</div>
HTML
;
	}
	
	
	return $html;
}


sub display_image($$$) {

	my $product_ref = shift;
	my $id_lc = shift;	#  id_lc = [front|ingredients|nutrition]_[lc] 
	my $size = shift;  # currently = $small_size , 200px
	
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
	
	if ((defined $product_ref->{images}) and (defined $product_ref->{images}{$id})
		and (defined $product_ref->{images}{$id}{sizes}) and (defined $product_ref->{images}{$id}{sizes}{$size})) {
	
		my $path = product_path($product_ref->{code});
		my $rev = $product_ref->{images}{$id}{rev};
		my $alt = remove_tags_and_quote($product_ref->{product_name}) . ' - ' . $Lang{$imagetype . '_alt'}{$lang};

		if (not defined $product_ref->{jqm}) {
		
			# add srcset with 2x image only if the 2x image exists
			my $srcset = '';
			if (defined $product_ref->{images}{$id}{sizes}{$display_size}) {
				$srcset = "srcset=\"/images/products/$path/$id.$rev.$display_size.jpg 2x\"";
			}
			
			$html .= <<HTML
<img class="hide-for-xlarge-up" src="/images/products/$path/$id.$rev.$size.jpg" $srcset width="$product_ref->{images}{$id}{sizes}{$size}{w}" height="$product_ref->{images}{$id}{sizes}{$size}{h}" alt="$alt" itemprop="thumbnail" />
HTML
;

			$srcset = '';
			if (defined $product_ref->{images}{$id}{sizes}{$zoom_size}) {
				$srcset = "srcset=\"/images/products/$path/$id.$rev.$zoom_size.jpg 2x\"";
			}

			$html .= <<HTML
<img class="show-for-xlarge-up" src="/images/products/$path/$id.$rev.$display_size.jpg" $srcset width="$product_ref->{images}{$id}{sizes}{$display_size}{w}" height="$product_ref->{images}{$id}{sizes}{$display_size}{h}" alt="$alt" itemprop="thumbnail" />
HTML
;
				
			if (($size eq $small_size) and (defined $product_ref->{images}{$id}{sizes}{$display_size}))  {
			
				my $title = lang($id . '_alt');
				
				my $full_image_url = "/images/products/$path/$id.$product_ref->{images}{$id}{rev}.full.jpg";
				my $representative_of_page = '';
				if ($id eq 'front') {
					$representative_of_page = 'true';
				}
				else {
					$representative_of_page = 'false';
				}
				
				$html = <<HTML
<a data-reveal-id="drop_$id" class="th">
$html
</a>
<div id="drop_$id" class="reveal-modal" data-reveal aria-labelledby="modalTitle_$id" aria-hidden="true" role="dialog" about="$full_image_url" >
<h2 id="modalTitle_$id">$title</h2>
<img src="$full_image_url" alt="$alt" itemprop="contentUrl" />
<a class="close-reveal-modal" aria-label="Close" href="#">&#215;</a>
<meta itemprop="representativeOfPage" content="$representative_of_page"/>
<meta itemprop="license" content="https://creativecommons.org/licenses/by-sa/3.0/"/>
<meta itemprop="caption" content="$alt"/>
</div>
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

1;
