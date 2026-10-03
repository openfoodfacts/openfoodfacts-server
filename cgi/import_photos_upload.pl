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
use ProductOpener::HTTP qw/single_param/;
use ProductOpener::Users qw/$Owner_id/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Lang qw/$lc %Lang lang/;
use ProductOpener::Mail qw/:all/;

use Apache2::RequestRec ();
use Apache2::Const ();

use CGI qw/:cgi :form escapeHTML :cgi-lib/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::MaybeXS;
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
	display_error_and_exit($request_ref, lang("no_owner_defined"), 200);
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

	$request_ref->{scripts} .= <<JS
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
                      <div><span class="label info">$Lang{info}{$lc}</span> {\%=file.info\%}</div>
                  {\% } \%}
                  {\% if (file.code_from_filename) { \%}
                      <div>$Lang{code_from_filename}{$lc} :</span> {\%=file.code_from_filename\%}</div>
                  {\% } \%}
                  {\% if (file.scanned_code) { \%}
                      <div>$Lang{scanned_code}{$lc} : {\%=file.scanned_code\%}</div>
                  {\% } \%}
                  {\% if (file.using_previous_code) { \%}
                      <div>$Lang{using_previous_code}{$lc} :</span> {\%=file.using_previous_code\%}</div>
                  {\% } \%}
                  {\% if (file.error) { \%}
                      <div><span class="label alert">$Lang{error}{$lc}</span> {\%=file.error\%}</div>
                  {\% } \%}
              </td>
              <td>
                  <span class="size">{\%=o.formatFileSize(file.size)\%}</span><br>
				  {\% if (!file.error) { \%}
                      $Lang{file_received}{$lc} </div>
                  {\% } \%}
              </td>
          </tr>
      {\% } \%}
    </script>

    <!-- The Templates plugin is included to render the upload/download listings -->
    <script src="$static_subdomain/js/dist/tmpl.js"></script>
    <!-- The Load Image plugin is included for the preview images and image resizing functionality -->
    <script src="$static_subdomain/js/dist/load-image.all.min.js"></script>
    <!-- The Canvas to Blob plugin is included for image resizing functionality -->
    <script src="$static_subdomain/js/dist/canvas-to-blob.js"></script>

    <!-- The Iframe Transport is required for browsers without support for XHR file uploads -->
    <script src="$static_subdomain/js/dist/jquery.iframe-transport.js"></script>
    <!-- The basic File Upload plugin -->
    <script src="$static_subdomain/js/dist/jquery.fileupload.js"></script>
    <!-- The File Upload processing plugin -->
    <script src="$static_subdomain/js/dist/jquery.fileupload-process.js"></script>
    <!-- The File Upload image preview & resize plugin -->
    <script src="$static_subdomain/js/dist/jquery.fileupload-image.js"></script>
    <!-- The File Upload validation plugin -->
    <script src="$static_subdomain/js/dist/jquery.fileupload-validate.js"></script>
    <!-- The File Upload user interface plugin -->
    <script src="$static_subdomain/js/dist/jquery.fileupload-ui.js"></script>
JS
		;

	process_template('web/pages/import_photos_upload/import_photos_upload.tt.html',
		$template_data_ref, \$html, $request_ref)
		or $html = "<p>" . $tt->error() . "</p>";
	process_template('web/pages/import_photos_upload/import_photos_upload.tt.js',
		$template_data_ref, \$js, $request_ref)
		or $html = "<p>" . $tt->error() . "</p>";

	$request_ref->{initjs} .= $js;


	$request_ref->{styles} .= <<CSS

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

