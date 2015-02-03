package Blogs::Images;

######################################################################
#
#	Package	Images
#
#	Author:	Stephane Gigandet
#	Date:	06/08/10
#
######################################################################

BEGIN
{
	use vars       qw(@ISA @EXPORT @EXPORT_OK %EXPORT_Images);
	require Exporter;
	@ISA = qw(Exporter);
	@EXPORT = qw();            # symbols to export by default
	@EXPORT_OK = qw(
					&generate_banner
					&generate_mosaic_background
					&display_image_form
					&process_image_form
					
					&display_search_image_form
					&process_search_image_form
					
					&process_image_upload 
					&process_image_crop
					
					&scan_code
					
					&display_select_crop
					&display_select_crop_init
					
					&display_image
	
					);	# symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;
use strict;
use utf8;

use Blogs::Store qw/:all/;
use Blogs::Config qw/:all/;

use CGI qw/:cgi :form escapeHTML/;

use Image::Magick;
use Graphics::Color::RGB;
use Graphics::Color::HSL;
use Barcode::ZBar;
use Blogs::Products qw/:all/;
use Blogs::Lang qw/:all/;
use Blogs::Display qw/:all/;


my $debug = 1;

sub display_select_crop($$) {

	my $object_ref = shift;
	my $id = shift;	
		
	my $note = '';
	if (defined $Lang{"image_" . $id . "_note"}{$lang}) {
		$note = "<p class=\"note\">&rarr; " . $Lang{"image_" . $id . "_note"}{$lang} . "</label></p>";
	}
		
	my $html = <<HTML
<label for="$id">$Lang{"image_" . $id}{$lang}</label>
$note
<div class=\"select_crop\" id=\"$id\"></div>
<hr class="floatclear" />
HTML
;

	my @fields = qw(imgid x1 y1 x2 y2);
	foreach my $field (@fields) {
		$html .= '<input type="hidden" name="' . "${id}_$field" . '" id="' . "${id}_$field" . '" value="' . $object_ref->{"$id.$field"} . '" />' . "\n";
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
			$images .= <<JS
{imgid: "$imgid", thumb_url: "$imgid.$thumb_size.jpg", crop_url: "$imgid.$crop_size.jpg", display_url: "$imgid.$display_size.jpg"},
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
				print STDERR "Images::scan_code - found code: $code\n";
				last;
			}
			
			if (defined $code) {
				last;
			}
			else {
				$magick->Rotate(degrees => 90);
			}
			
		}
	}

	return $code;
}


sub display_search_image_form_old() {

	my $html = '';
	
	$html .= <<HTML
<label for="imgsearch">Image du produit avec code barre :</label>
<input type="file" accept="image/*" class="img_input" size="10" name="imgsearch" id="imgsearch" onchange="javascript:this.form.submit();" />				
HTML
;
	
	return $html;
}


sub display_search_image_form() {

	my $html = '';
	
	$html .= <<HTML
<div id="imgsearchdiv" class="small_buttons">
<label for="imgupload_search">$Lang{product_image_with_barcode}{$lang}</label>
<span class="btn btn-success fileinput-button" id="imgsearchbutton">
<span>$Lang{send_image}{$lang}</span>
<input type="file" accept="image/*" class="img_input" name="imgupload_search" id="imgupload_search" />
</span>
</div>
<br />


<div id="progressbar" class="progress" style="display:none;height:12px;"></div>
<div id="imgsearchmsg" class="ui-state-highlight " style="display:none">$Lang{sending_image}{$lang}</div>
<div id="imgsearcherror" class="ui-state-error " style="display:none">$Lang{send_image_error}{$lang}</div>

HTML
;

	if ($domain eq 'test.openfoodfacts.org') {
		$html .= <<HTML
<div id="imgsearchdebug"></div>		
HTML
;
	}

	$scripts .= <<JS
<script src="/js/jquery.iframe-transport.js"></script>
<script src="/js/jquery.fileupload.js"></script>	
<script src="/js/load-image.min.js"></script>
<script src="/js/canvas-to-blob.min.js"></script>
<script src="/js/jquery.fileupload-ip.js"></script>
JS
;

	$initjs .= <<JS
	
	\$('.fileinput-button').each(function () {
                    var input = \$(this).find('input:file').detach();
                    \$(this)
                        .button()
                        .append(input);
                });
	
	
    \$('#imgupload_search').fileupload({
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
				\$("#imgsearcherror").html(data.result.error);
				\$("#imgsearcherror").show();
			}
        },
		fail : function (e, data) {
			\$("#imgsearcherror").show();
        },
		always : function (e, data) {
			\$("#progressbar").hide();
			\$("#imgsearchbutton").show();
			\$("#imgsearchmsg").hide();
        },
		start: function (e, data) {
			\$("#imgsearchbutton").hide();
			\$("#imgsearcherror").hide();
			\$("#imgsearchmsg").show();
			\$("#progressbar").progressbar({value : 0 }).show();
                    
		},
            sent: function (e, data) {
                if (data.dataType &&
                        data.dataType.substr(0, 6) === 'iframe') {
                    // Iframe Transport does not support progress events.
                    // In lack of an indeterminate progress bar, we set
                    // the progress to 100%, showing the full animated bar:
                    \$("#progressbar").progressbar(
                            'option',
                            'value',
                            100
                        );
                }
            },
            progress: function (e, data) {

                    \$("#progressbar").progressbar(
                        'option',
                        'value',
                        parseInt(data.loaded / data.total * 100, 10)
                    );
					\$("#imgsearchdebug").html(data.loaded + ' / ' + data.total);
                
            }
		
    });	
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
			
			open (FILE, ">$data_root/tmp/$filename.$extension") ;
			while (<$file>) {
				print FILE;
			}
			close (FILE);
			
			$code = scan_code("$data_root/tmp/$filename.$extension");					
			$$filename_ref = "$data_root/tmp/$filename.$extension";
		}
	}	
	return $code;
}


sub process_image_upload($$) {

	my $code = shift;
	my $imagefield = shift;
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
				open ($file, "<$tmp_filename");
			}		
	}
	else {
		$file = param('imgupload_' . $imagefield);
	}
	

	if ($file) {
	
		print STDERR "Images.pm - process_image_upload - imagefield: $imagefield - file: $file\n";

	
		if ($file !~ /\.(gif|jpeg|jpg|png)$/i) {
			# We have a "blob" without file name and extension?
			# try to assume it is jpeg (and let ImageMagick read it anyway if it's something else)
			# $file .= ".jpg";
		}
		
		if (1 or ($file =~ /\.(gif|jpeg|jpg|png)$/i)) {
			print STDERR "Images.pm - process_image_upload - imagefield: $imagefield - file: $file - format ok\n";
			
			my $extension = lc($1) ;
			$extension eq 'jpeg' and $extension = 'jpg';
			$extension eq '' and $extension = 'jpg';
			my $filename = get_fileid(remote_addr(). '_' . $`);
			
			my $current_product_ref = retrieve_product($code);
			$imgid = $current_product_ref->{max_imgid} + 1;
			while (-e "$www_root/images/products/$path/$imgid.lock") {
				$imgid++;
			}
			mkdir ("$www_root/images/products/$path/$imgid.lock", 0755) or print STDERR "Images.pm - Error - Could not create lock $www_root/images/products/$path/$imgid.lock : $!\n";
			


			open (FILE, ">$www_root/images/products/$path/$imgid.$extension") or print STDERR "Images.pm - Error - Could not save $www_root/images/products/$path/$imgid.$extension : $!\n";
			while (<$file>) {
				print FILE;
			}
			close (FILE);


			
			
			# Keep original in case we need it later
			
			
			# Generate resized versions
					
			my $source = Image::Magick->new;			
			my $x = $source->Read("$www_root/images/products/$path/$imgid.$extension");
			$source->AutoOrient();
			$source->Strip(); #remove orientation data.
			
			# Save a .jpg if we were sent something else (always re-save as the image can be rotated)
			#if ($extension ne 'jpg') {
				$source->Set('quality',95);
				my $x = $source->Write("jpeg:$www_root/images/products/$path/$imgid.jpg");
			#}
			
			# Check that we don't already have the image

			my $size = -s "$www_root/images/products/$path/$imgid.$extension";
			#print STDERR "size of $www_root/images/products/$path/$imgid.$extension : $size \n" . (-s "$www_root/images/products/$path/$imgid.$extension") . "\n";
			for (my $i = 0; $i < $imgid; $i++) {
				#print STDERR "existing image $i - size: " . (-s "$www_root/images/products/$path/$i.$extension") . " -- $imgid size: $size\n";
				if ((-s "$www_root/images/products/$path/$i.$extension") == $size) {
					#print STDERR "image $imgid has same size than $www_root/images/products/$path/$i.$extension : deleting $www_root/images/products/$path/$imgid.$extension\n";
					unlink "$www_root/images/products/$path/$imgid.$extension";
					rmdir ("$www_root/images/products/$path/$imgid.lock");
					return -3;
				}
			}			
			
			("$x") and print STDERR "Images::generate_image - cannot read $www_root/images/products/$path/$imgid.$extension $x\n";

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
				$img->Set('quality',90);

				my $x = $img->Write("jpeg:$www_root/images/products/$path/$imgid.$max.jpg");
				if ("$x") {
					print STDERR "Index::download_image - could not write jpeg:$www_root/images/products/$path/$imgid.$max.jpg: $x\n";
				}
				else {
					print STDERR "Index::download_image - wrote jpeg:$www_root/images/products/$path/$imgid.$max.jpg\n";		
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
			store_product($product_ref, "new image $imgid");
			
			}
			else {
				$imgid = -2;
			}
			
			rmdir ("$www_root/images/products/$path/$imgid.lock");
		}
	}
	print STDERR "Index::download_image - return imgid: $imgid - imagefield: $imagefield\n";
	return $imgid;
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
	
	print STDERR "Images.pm - process_image_crop - imgid: $imgid\n";
			
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
	
	if ($white_magic eq 'checked') {
		$filename .= ".white";
	}	
	
	if ($white_magic eq 'checked') {

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
		my $x = $background->Write("jpeg:$www_root/images/products/$path/$imgid.${crop_size}.background.jpg");
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
 
		sub distance($$) {
			my $a = shift;
			my $b = shift;
			
			my $d = ($a->[0] - $b->[0]) * ($a->[0] - $b->[0]) + ($a->[1] - $b->[1]) * ($a->[1] - $b->[1]) + ($a->[2] - $b->[2]) * ($a->[2] - $b->[2]);
			return $d;
		}
 
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
			(distance(\@rgb, [$original->GetPixel(x=>$x+1,y=>$y)]) <= $max_distance) and push @q, [$x+1, $y];
			(distance(\@rgb, [$original->GetPixel(x=>$x-1,y=>$y)]) <= $max_distance) and push @q, [$x-1, $y];
			(distance(\@rgb, [$original->GetPixel(x=>$x,y=>$y+1)]) <= $max_distance) and push @q, [$x, $y+1];
			(distance(\@rgb, [$original->GetPixel(x=>$x,y=>$y-1)]) <= $max_distance) and push @q, [$x, $y-1];
			
			(distance(\@rgb, [$original->GetPixel(x=>$x+1,y=>$y+1)]) <= $max_distance) and push @q, [$x+1, $y+1];
			(distance(\@rgb, [$original->GetPixel(x=>$x-1,y=>$y-1)]) <= $max_distance) and push @q, [$x-1, $y-1];
			(distance(\@rgb, [$original->GetPixel(x=>$x-1,y=>$y+1)]) <= $max_distance) and push @q, [$x-1, $y+1];
			(distance(\@rgb, [$original->GetPixel(x=>$x+1,y=>$y-1)]) <= $max_distance) and push @q, [$x+1, $y-1];			
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
	
	
	if ($normalize eq 'checked') {
		$source->Normalize( channel=>'RGB' );
		$filename .= ".normalize";
	}
	
	# Keep only one image, and overwrite previous images
	# ! cached images... add a version number
	$filename = $id . "." . $rev;
	
	
	$source->Set('quality',95);
	my $x = $source->Write("jpeg:$www_root/images/products/$path/$filename.full.jpg");
	("$x") and print STDERR "Images::process_image_crop - could not write jpeg:$www_root/images/products/$path/$filename.full.jpg $x\n";
	
	# Re-read cropped image
	my $cropped_source = Image::Magick->new;
	$cropped_source->Read("$www_root/images/products/$path/$filename.full.jpg");
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
		$img->Set('quality',95);

		my $x = $img->Write("jpeg:$www_root/images/products/$path/$filename.$max.jpg");
		if ("$x") {
			print STDERR "Index::download_image - could not write jpeg:$www_root/images/products/$path/$filename.$max.jpg: $x\n";
		}
		else {
			print STDERR "Index::download_image - wrote jpeg:$www_root/images/products/$path/$filename.$max.jpg\n";		
		}
		
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



sub display_image($$$) {

	my $product_ref = shift;
	my $id = shift;
	my $size = shift;
	my $jqm = 0;
	
	my $html = '';
	
	if (0) {
	print STDERR "display_image - ($id, $size) - ";
	(defined $product_ref->{images}) and print STDERR "images ";
	(defined $product_ref->{images}{$id}) and print STDERR "$id ";
	(defined $product_ref->{images}{$id}{sizes}) and print STDERR "sizes ";
	(defined $product_ref->{images}{$id}{sizes}{$size}) and print STDERR "$size";
	print STDERR "\n";
	}
	
	if ((defined $product_ref->{images}) and (defined $product_ref->{images}{$id})
		and (defined $product_ref->{images}{$id}{sizes}) and (defined $product_ref->{images}{$id}{sizes}{$size})) {
	
		my $path = product_path($product_ref->{code});
		$html .= '<img src="/images/products/' . $path . '/' . $id . '.' . $product_ref->{images}{$id}{rev} . '.' . $size . '.jpg"'
			. ' width="' . $product_ref->{images}{$id}{sizes}{$size}{w} . '" height="' . $product_ref->{images}{$id}{sizes}{$size}{h} . '"'
			. ' alt="' . remove_tags_and_quote($product_ref->{product_name}) . ' - ' . $Lang{$id . '_alt'}{$lang} . '" />';
			
		if ((not defined $product_ref->{jqm}) and ($size eq $small_size) and (defined $product_ref->{images}{$id}{sizes}{$display_size}))  {
			$html = '<a href="/images/products/' . $path . '/' . $id . '.' . $product_ref->{images}{$id}{rev} . '.' . $display_size
			. '.jpg" class="nivoZoom topRight">' . $html . '</a>';
		}
	}

	
	return $html;
}




1;
