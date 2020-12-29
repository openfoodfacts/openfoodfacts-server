#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2020 Association Open Food Facts
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

my $title = lang("import_data_file_title");
my $html = '';
my $js = '';

local $log->context->{type} = $type;
local $log->context->{action} = $action;

if (not defined $Owner_id) {
	display_error(lang("no_owner_defined"), 200);
}

if ($action eq "process") {

	# Process uploaded files

	my $file = param('file_input_data');
	my $filename = decode utf8=>param('file_input_data');

	my %data = ();

	if ($filename =~ /\.(xlsx|csv|tsv)$/i) {


		my $extension = lc($1) ;
		$filename = $`;
		my $uploaded_t = time();
		my $file_id = $uploaded_t . '-' . get_string_id_for_lang("no_language", $filename);

		$log->debug("processing upload form", { filename => $filename, file_id => $file_id, extension => $extension }) if $log->is_debug();

		(-e "$data_root/import_files") or mkdir("$data_root/import_files", 0755);
		(-e "$data_root/import_files/${Owner_id}") or mkdir("$data_root/import_files/${Owner_id}", 0755);

		open (my $out, ">", "$data_root/import_files/${Owner_id}/$file_id.$extension") ;
		while (my $chunk = <$file>) {
			print $out $chunk;
		}
		close ($out);

		%data = (
			location => "$formatted_subdomain/cgi/import_file_select_format.pl?file_id=$file_id&action=display",
		);

		# Keep track of uploaded files attributes and status

		my $import_files_ref = retrieve("$data_root/import_files/${Owner_id}/import_files.sto");
		if (not defined $import_files_ref) {
			$import_files_ref = {};
		}

		$import_files_ref->{$file_id} = {
			filename => $filename,
			extension => $extension,
			uploaded_t => $uploaded_t,
		};

		store("$data_root/import_files/${Owner_id}/import_files.sto", $import_files_ref);

	}
	else {
		%data = ( error => 'File type is not supported' );
	}

	my $data = encode_json(\%data);

	$log->debug("import_file_upload.pl JSON data output", { data => $data }) if $log->is_debug();

	print header( -type => 'application/json', -charset => 'utf-8' ) . $data;
	exit();

}
else {

	# Display upload info and form

	# Passing values to the template
	my $template_data_ref = {
		lang => \&lang,
		display_icon => \&display_icon,
		id => "data",
		url => "/cgi/import_file_upload.pl",
	};

	$tt->process('import_file_upload.tt.html', $template_data_ref, \$html);
	$tt->process('import_file_upload.tt.js', $template_data_ref, \$js);

	$initjs .= $js;


	$scripts .= <<HTML
<script type="text/javascript" src="/js/dist/jquery.iframe-transport.js"></script>
<script type="text/javascript" src="/js/dist/jquery.fileupload.js"></script>
HTML
;

	display_new( {
		title=>$title,
		content_ref=>\$html,
	});
}

exit(0);

