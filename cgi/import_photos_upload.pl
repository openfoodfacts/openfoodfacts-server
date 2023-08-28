#!/usr/bin/perl -w

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
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

use ProductOpener::PerlStandards;

binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");

use CGI::Carp qw(fatalsToBrowser);

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Mail qw/:all/;

use Apache2::RequestRec ();
use Apache2::Const ();

use CGI qw/:cgi :form escapeHTML :cgi-lib/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;
use Log::Any qw($log);

my $request_ref = ProductOpener::Display::init_request();

my $type = single_param('type') || 'upload';
my $action = single_param('action') || 'display';

my $title = lang("import_photos_title");
my $html = '';
my $js = '';
my $template_data_ref = {};

local $log->context->{type} = $type;
local $log->context->{action} = $action;

if (not defined $Owner_id) {
	display_error_and_exit(lang("no_owner_defined"), 200);
}

else {

	# Enable adding field values for photos uploaded

	my @add_fields
		= qw(brands categories packaging labels origins manufacturing_places emb_codes purchase_places stores countries);
	my %add_fields_labels = ();
	my @add_fields_options = {value => 'add_tag', label => lang("add_tag_field")};

	foreach my $field (@add_fields) {
		$add_fields_labels{$field} = ucfirst(lang($field . "_p"));
		push(
			@add_fields_options,
			{
				value => $field,
				label => $add_fields_labels{$field},
			}
		);
	}
	$add_fields_labels{add_tag} = lang("add_tag_field");

	my $i = 0;
	$template_data_ref->{i} = $i;
	$template_data_ref->{add_fields_options} = \@add_fields_options;

	$scripts .= <<JS
    <!-- The template to display files available for upload -->
    <script id="template-upload" type="text/x-tmpl">
      {\% for (var i=0, file; file=o.files[i]; i++) { \%}
          <tr class="template-upload fade">
              <td style="min-width:120px;">
                  <span class="preview"></span>
              </td>
              <td>
                  {\% if (window.innerWidth > 480 || !o.options.loadImageFileTypes.test(file.type)) { \%}
                      <span class="name">{\%=file.name\%}</span><br>
                  {\% } \%}
                  <strong class="error text-danger"></strong>
              </td>
              <td style="min-width:150px;">
                  <span class="size">Processing...</span><br>
                  <div class="progress progress-striped active" role="progressbar" aria-valuemin="0" aria-valuemax="100" aria-valuenow="0"><div class="progress-bar progress-bar-success meter" style="width:0\%;"></div></div>
              </td>
          </tr>
      {\% } \%}
    </script>
    <!-- The template to display files available for download -->
    <script id="template-download" type="text/x-tmpl">
      {\% for (var i=0, file; file=o.files[i]; i++) { \%}
          <tr class="template-download fade">
              <td style="min-width:120px;">
                  <span class="preview">
                      {\% if (file.thumbnailUrl) { \%}
                          <a href="{\%=file.url\%}" title="{\%=file.name\%}" download="{\%=file.name\%}" data-gallery><img src="{\%=file.thumbnailUrl\%}"></a>
                      {\% } \%}
                  </span>
              </td>
              <td>
                  {\% if (window.innerWidth > 480 || !file.thumbnailUrl) { \%}
                          {\% if (file.url) { \%}
                              <a href="{\%=file.url\%}" title="{\%=file.name\%}" download="{\%=file.name\%}" {\%=file.thumbnailUrl?'data-gallery':''\%}>{\%=file.name\%}</a><br>
                          {\% } else { \%}
                              <span>{\%=file.name\%}</span><br>
                          {\% } \%}
						  <span class="name">{\%=file.filename\%}</span>
                  {\% } \%}
                  {\% if (file.info) { \%}
                      <div><span class="label info">$Lang{info}{$lang}</span> {\%=file.info\%}</div>
                  {\% } \%}
                  {\% if (file.code_from_filename) { \%}
                      <div>$Lang{code_from_filename}{$lang} :</span> {\%=file.code_from_filename\%}</div>
                  {\% } \%}
                  {\% if (file.scanned_code) { \%}
                      <div>$Lang{scanned_code}{$lang} : {\%=file.scanned_code\%}</div>
                  {\% } \%}
                  {\% if (file.using_previous_code) { \%}
                      <div>$Lang{using_previous_code}{$lang} :</span> {\%=file.using_previous_code\%}</div>
                  {\% } \%}
                  {\% if (file.error) { \%}
                      <div><span class="label alert">$Lang{error}{$lang}</span> {\%=file.error\%}</div>
                  {\% } \%}
              </td>
              <td>
                  <span class="size">{\%=o.formatFileSize(file.size)\%}</span><br>
				  {\% if (!file.error) { \%}
                      $Lang{file_received}{$lang} </div>
                  {\% } \%}
              </td>
          </tr>
      {\% } \%}
    </script>

    <!-- The Templates plugin is included to render the upload/download listings -->
    <script src="/js/dist/tmpl.js"></script>
    <!-- The Load Image plugin is included for the preview images and image resizing functionality -->
    <script src="/js/dist/load-image.all.min.js"></script>
    <!-- The Canvas to Blob plugin is included for image resizing functionality -->
    <script src="/js/dist/canvas-to-blob.js"></script>

    <!-- The Iframe Transport is required for browsers without support for XHR file uploads -->
    <script src="/js/dist/jquery.iframe-transport.js"></script>
    <!-- The basic File Upload plugin -->
    <script src="/js/dist/jquery.fileupload.js"></script>
    <!-- The File Upload processing plugin -->
    <script src="/js/dist/jquery.fileupload-process.js"></script>
    <!-- The File Upload image preview & resize plugin -->
    <script src="/js/dist/jquery.fileupload-image.js"></script>
    <!-- The File Upload validation plugin -->
    <script src="/js/dist/jquery.fileupload-validate.js"></script>
    <!-- The File Upload user interface plugin -->
    <script src="/js/dist/jquery.fileupload-ui.js"></script>
JS
		;

	process_template('web/pages/import_photos_upload/import_photos_upload.tt.html', $template_data_ref, \$html)
		or $html = "<p>" . $tt->error() . "</p>";
	process_template('web/pages/import_photos_upload/import_photos_upload.tt.js', $template_data_ref, \$js)
		or $html = "<p>" . $tt->error() . "</p>";

	$initjs .= $js;

	$header .= <<HTML
<script>
// Keep track of codes that we have seen so that we can submit field values only once
var codes = {};

// We keep the last code recognized in an image to assign it to the next images
var previous_code = "";
var previous_imgid = "";

// We need to wait for one upload to be complete before submitting the next one
// so that we can pass the correct previous_code in the next request
var submitCount = 0;
var shouldStartIndex = 0;
var lastFileUploaded = -1;

function waitForPreviousUpload(submitIndex, callback) {
  if(shouldStartIndex === submitIndex && lastFileUploaded === shouldStartIndex-1) {
    callback()
    return;
  }
  setTimeout(function(){
    waitForPreviousUpload(submitIndex, callback)
  }, 500)
}

</script>


HTML
		;

	$initjs .= <<JS

/*
 * jQuery File Upload Demo
 * https://github.com/blueimp/jQuery-File-Upload
 *
 * Copyright 2010, Sebastian Tschan
 * https://blueimp.net
 *
 * Licensed under the MIT license:
 * https://opensource.org/licenses/MIT
 */

'use strict';

// Enable iframe cross-domain access via redirect option:
\$('#fileupload').fileupload({
	sequentialUploads: true,
	replaceFileInput : false,
	// Uncomment the following to send cross-domain cookies:
	xhrFields: {withCredentials: true},
	autoUpload: true
});


\$('#fileupload').bind('fileuploadsubmit', function (e, data) {

	var myIndex = submitCount++;
	var \$this = \$(this);

	console.log("submit - myIndex: " + myIndex + " - previous_code: " + previous_code);

	waitForPreviousUpload(myIndex, function() {
		shouldStartIndex++;
		console.log('starting upload #' + myIndex + " - previous_code: " + previous_code);
		// start upload

		data.formData = [
				{ name : "previous_code", value : previous_code},
				{ name : "previous_imgid", value : previous_imgid}
			];
		data.jqXHR = \$this.fileupload('send', data);
	})
	return false;
});

var images_processed = 0;

\$('#fileupload')
    .bind('fileuploadadd', function (e, data) { console.log("fileuploadadd"); })
    .bind('fileuploadstart', function (e, data) { console.log("fileuploadstart");})
    .bind('fileuploadprocessstart', function (e, data) { console.log("fileuploadstart"); \$(document).foundation('equalizer', 'reflow'); })
    .bind('fileuploadprocessstop', function (e, data) { console.log("fileuploadprocessstop"); \$(document).foundation('equalizer', 'reflow'); })
    .bind('fileuploadprocessalways', function (e, data) { console.log("fileuploadprocessalways"); images_processed++; if (images_processed % 20 === 0) { \$(document).foundation('equalizer', 'reflow'); }})
	.bind('fileuploadalways', function (e, data) {
		lastFileUploaded++;
		console.log("always - lastFileUploaded: " + lastFileUploaded);
		\$(document).foundation('equalizer', 'reflow');
});

\$('#tag_0').val("");
\$('#tagtype_0').val("add_tag");

\$('#fileupload')
    .bind('fileuploaddone', function (e, data) {
	if (data.result && data.result.files && data.result.files[0].scanned_code) {
		previous_code = data.result.files[0].scanned_code;
		// Store the imgid with the scanned barcode, so that if we have another image, we can select it as the front image
		if (data.result.image) {
			previous_imgid = data.result.image.imgid;
		}
		else {
			previous_imgid = "";
		}
	}
	else {
		previous_imgid = "";
	}

	console.log("fileuploaddone - previous_code: " + previous_code);

	if (data.result && data.result.files && data.result.files[0].code) {
		var code = data.result.files[0].code;
		console.log("code: " + code);
		if(typeof codes[code] === 'undefined') {
			codes[code] = true;

			var data = [
				{name : "code", value : code},
				{name : "comment", value : "fields added through photos upload on producer platform"}
			];

			var i = 0;
			var n = 0;
			while (\$('#tag_' + i).length > 0) {
				if ((\$('#tag_' + i).val() != '') && ((\$('#tagtype_' + i).val() != 'add_tag'))) {
					data.push({
						name : "add_" + \$('#tagtype_' + i).val(),
						value: \$('#tag_' + i).val()
					});
					n++;
				}
				i++;
			}

			console.log(data);

			if (n > 0) {
				\$.ajax({
					type: "GET",
					contentType: "application/json; charset=utf-8",
					url: "/cgi/product_jqm_multilingual.pl",
					data: data,
					success: function (result) {
						console.log("data sent");
					}
				});
			}
		}
	}

});

JS
		;

	$styles .= <<CSS

    <!-- CSS to style the file input field as button and adjust the Bootstrap progress bars -->

.fileinput-button {
  position: relative;
  overflow: hidden;
  display: inline-block;
}
.fileinput-button input {
  position: absolute;
  top: 0;
  right: 0;
  margin: 0;
  opacity: 0;
  -ms-filter: 'alpha(opacity=0)';
  font-size: 200px !important;
  direction: ltr;
  cursor: pointer;
}

/* Fixes for IE < 8 */
\@media screen\\9 {
  .fileinput-button input {
    filter: alpha(opacity=0);
    font-size: 100%;
    height: 100%;
  }
}

\@charset "UTF-8";
/*
 * jQuery File Upload UI Plugin CSS
 * https://github.com/blueimp/jQuery-File-Upload
 *
 * Copyright 2010, Sebastian Tschan
 * https://blueimp.net
 *
 * Licensed under the MIT license:
 * https://opensource.org/licenses/MIT
 */

.progress-animated .progress-bar,
.progress-animated .bar {
  background: url('/images/misc/progressbar.gif') !important;
  filter: none;
}
.fileupload-process {
  float: right;
  display: none;
}
.fileupload-processing .fileupload-process,
.files .processing .preview {
  display: block;
  width: 32px;
  height: 32px;
  background: url('/images/misc/loading3.gif') center no-repeat;
  background-size: contain;
}
.files audio,
.files video {
  max-width: 300px;
}
.toggle[type='checkbox'] {
  transform: scale(2);
  margin-left: 10px;
}

\@media (max-width: 767px) {
  .fileupload-buttonbar .btn {
    margin-bottom: 5px;
  }
  .fileupload-buttonbar .delete,
  .fileupload-buttonbar .toggle,
  .files .toggle,
  .files .btn span {
    display: none;
  }
  .files .name {
    width: 80px;
    word-wrap: break-word;
  }
  .files audio,
  .files video {
    max-width: 80px;
  }
  .files img,
  .files canvas {
    max-width: 100%;
  }
}

CSS
		;

	$request_ref->{title} = $title;
	$request_ref->{content_ref} = \$html;
	display_page($request_ref);
}

exit(0);

