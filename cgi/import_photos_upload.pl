#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2019 Association Open Food Facts
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

use Modern::Perl '2017';
use utf8;

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

ProductOpener::Display::init();

my $type = param('type') || 'upload';
my $action = param('action') || 'display';

my $title = lang("import_photos_title");
my $html = '';

local $log->context->{type} = $type;
local $log->context->{action} = $action;

if (not defined $Owner_id) {
	display_error(lang("no_owner_defined"), 200);
}


else {

	# Display upload info and form


	# Upload a file

	$html .= "<p>" . lang("import_photos_description") . "</p>\n";
	$html .= "<p>" . lang("import_photos_format_1") . " " . lang("import_photos_format_2") . "</p>\n";
	$html .= "<ul>"
	. "<li>" . lang("import_photos_format_barcode") . "</li>"
	. "<li>" . lang("import_photos_format_front") . "</li>"
	. "<li>" . lang("import_photos_format_ingredients") . "</li>"
	. "<li>" . lang("import_photos_format_nutrition") . "</li>"
	. "</ul>";

	$html .=<<HTML
      <form
        id="fileupload"
        action="/cgi/product_image_upload.pl"
        method="POST"
        enctype="multipart/form-data"
      >

        <!-- The fileupload-buttonbar contains buttons to add/delete files and start/cancel the upload -->
        <div class="row fileupload-buttonbar">
          <div class="large-7 columns">
            <!-- The fileinput-button span is used to style the file input field as button -->
            <span class="button small btn-success fileinput-button">
              @{[ display_icon('add') ]}
              <span>$Lang{add_photos}{$lang}</span>
              <input type="file" name="files[]" multiple accept="image/*" data-url="/cgi/product_image_import.pl" />
            </span>
            <button type="submit" class="button small btn-primary start">
              @{[ display_icon('arrow_upward') ]}
              <span>$Lang{start_upload}{$lang}</span>
            </button>
            <button type="reset" class="button small btn-warning cancel alert">
              @{[ display_icon('cancel') ]}
              <span>$Lang{cancel_upload}{$lang}</span>
            </button>
            <!-- The global file processing state -->
            <span class="fileupload-process"></span>
          </div>
          <!-- The global progress state -->
          <div class="large-5 columns fileupload-progress fade">
            <!-- The global progress bar -->
            <div
              class="progress progress-striped active"
              role="progressbar"
              aria-valuemin="0"
              aria-valuemax="100"
            >
              <div
                class="progress-bar progress-bar-success meter"
                style="width:0%;"
              ></div>
            </div>
            <!-- The extended global progress state -->
            <div class="progress-extended">&nbsp;</div>
          </div>
        </div>
        <!-- The table listing the files available for upload/download -->
        <table role="presentation" class="table table-striped">
          <tbody class="files"></tbody>
        </table>
      </form>

	<div id="empty_space_for_equalizer" style="height:200px;width:100px;">&nbsp;</div>

HTML
;

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
              <td>
                  {\% if (!i && !o.options.autoUpload) { \%}
                      <button class="button tiny btn-primary start" disabled>
                          @{[ display_icon('arrow_upward') ]}
                          <span>$Lang{start}{$lang}</span>
                      </button>
                  {\% } \%}
                  {\% if (!i) { \%}
                      <button class="button tiny btn-warning cancel alert">
                          @{[ display_icon('cancel') ]}
                          <span>$Lang{cancel}{$lang}</span>
                      </button>
                  {\% } \%}
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
              <td>
                  {\% if (file.deleteUrl) { \%}
                  {\% } else { \%}
                      <button class="button tiny btn-warning cancel">
                          @{[ display_icon('cancel') ]}
                          <span>$Lang{close}{$lang}</span>
                      </button>
                  {\% } \%}
              </td>
          </tr>
      {\% } \%}
    </script>

    <!-- The Templates plugin is included to render the upload/download listings -->
    <script src="https://blueimp.github.io/JavaScript-Templates/js/tmpl.min.js"></script>
    <!-- The Load Image plugin is included for the preview images and image resizing functionality -->
    <script src="https://blueimp.github.io/JavaScript-Load-Image/js/load-image.all.min.js"></script>
    <!-- The Canvas to Blob plugin is included for image resizing functionality -->
    <script src="https://blueimp.github.io/JavaScript-Canvas-to-Blob/js/canvas-to-blob.min.js"></script>

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

  // Initialize the jQuery File Upload widget:
  \$('#fileupload').fileupload({
    sequentialUploads: true,
    // Uncomment the following to send cross-domain cookies:
    xhrFields: {withCredentials: true}
  });

  // Enable iframe cross-domain access via redirect option:
  \$('#fileupload').fileupload(
    'option',
    'redirect',
    window.location.href.replace(/\\/[^/]*\$/, '/cors/result.html?\%s')
  );

  if (false) {

  } else {
    // Load existing files:
    \$('#fileupload').addClass('fileupload-processing');
    \$.ajax({
      // Uncomment the following to send cross-domain cookies:
      //xhrFields: {withCredentials: true},
      url: \$('#fileupload').fileupload('option', 'url'),
      dataType: 'json',
      maxFileSize: 10000000,
      acceptFileTypes: /(\.|\\/)(gif|jpe?g|png)\$/i,
      context: \$('#fileupload')[0]
    })
      .always(function() {
        \$(this).removeClass('fileupload-processing');
      })
      .done(function(result) {
        \$(this)
          .fileupload('option', 'done')
          // eslint-disable-next-line new-cap
          .call(this, \$.Event('done'), { result: result });
      });
  }

\$('#fileupload')
    .bind('fileuploadadd', function (e, data) {
	\$(document).foundation('equalizer', 'reflow');
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

	display_new( {
		title=>$title,
		content_ref=>\$html,
	});
}

exit(0);

