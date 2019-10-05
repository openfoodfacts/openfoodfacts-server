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
use ProductOpener::Producers qw/:all/;

use Apache2::RequestRec ();
use Apache2::Const ();

use CGI qw/:cgi :form escapeHTML :cgi-lib/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON;
use Log::Any qw($log);
use Spreadsheet::CSV();
use Text::CSV();

ProductOpener::Display::init();

my $title = '';
my $html = '';

if (not defined $owner) {
	display_error(lang("no_owner_defined"), 200);
}

my $import_files_ref = retrieve("$data_root/import_files/$owner/import_files.sto");
if (not defined $import_files_ref) {
	$import_files_ref = {};
}

my $file_id = get_string_id_for_lang("no_language", param('file_id'));

local $log->context->{file_id} = $file_id;

my $file;
my $extension;

if (defined $import_files_ref->{$file_id}) {
	$extension = $import_files_ref->{$file_id}{extension};
	$file = "$data_root/import_files/$owner/$file_id.$extension";
}
else {
	$log->debug("File not found in import_files.sto", { file_id => $file_id }) if $log->is_debug();
	display_error("File not found.", 404);
}

$log->debug("File found in import_files.sto", { file_id => $file_id,  file => $file, extension => $extension, import_file => $import_files_ref->{$file_id} }) if $log->is_debug();

# Store user columns to OFF fields matches so that they can be reused for the next imports

my $all_columns_fields_ref = retrieve("$data_root/import_files/$owner/all_columns_fields.sto");
if (not defined $all_columns_fields_ref) {
	$all_columns_fields_ref = {};
}

my $results_ref = load_csv_or_excel_file($file);

if ($results_ref->{error}) {
	display_error($results_ref->{error}, 200);
}

my $headers_ref = $results_ref->{headers};
my $rows_ref = $results_ref->{rows};

my $columns_fields_json = param("columns_fields_json");
my $columns_fields_ref = decode_json($columns_fields_json);

foreach my $field (keys %$columns_fields_ref) {
	delete $columns_fields_ref->{$field}{numbers};
	delete $columns_fields_ref->{$field}{letters};
	delete $columns_fields_ref->{$field}{both};

	$all_columns_fields_ref->{get_string_id_for_lang("no_language", $field)} = $columns_fields_ref->{$field};
}

defined $import_files_ref->{$file_id}{imports} or $import_files_ref->{$file_id}{imports} = {};

my $started_t = time();
my $import_id = $started_t;

my $columns_fields_file = "$file.import.$import_id.columns_fields.sto";
my $converted_file = "$file.import.$import_id.converted.csv";

$import_files_ref->{$file_id}{imports}{$import_id} = {
	started_t => $started_t,
	columns_fields => $columns_fields_file,
	converted_file => $converted_file,
};

store($columns_fields_file, $columns_fields_ref);

store("$data_root/import_files/$owner/all_columns_fields.sto", $all_columns_fields_ref);

# Default values: use the language and country of the interface
my $default_values_ref = {
	lc => $lc,
	countries => $cc,
};

my $results_ref = convert_file($default_values_ref, $file, $columns_fields_file, $converted_file);

$import_files_ref->{$file_id}{imports}{$import_id}{converted_t} = time();

if ($results_ref->{error}) {
	$import_files_ref->{$file_id}{imports}{$import_id}{convert_error} = $results_ref->{error};
	store("$data_root/import_files/$owner/import_files.sto", $import_files_ref);
	display_error($results_ref->{error}, 200);
}

my $args_ref = {
	user_id => $User_id,
	org_id => $Org_id,
	owner => $owner,
	csv_file => $converted_file,
	file_id => $file_id,
	import_id => $import_id,
	comment => "Import from producers platform",
};

if (defined $Org_id) {
	$args_ref->{manufacturer} = 1;
	$args_ref->{source_id} = $Org_id;
	$args_ref->{global_values} = { data_sources => "Producers, Producer - " . $Org_id};
}
else {
	$args_ref->{no_source} = 1;
}

my $job_id = $minion->enqueue(import_csv_file => [$args_ref] => { queue => $server_options{minion_local_queue}});

$import_files_ref->{$file_id}{imports}{$import_id}{job_id} = $job_id;

store("$data_root/import_files/$owner/import_files.sto", $import_files_ref);

$html .= "<p>job_id: " . $results_ref->{job_id} . "</p>";

$html .= "<a href=\"/cgi/import_file_job_status.pl?file_id=$file_id&import_id=$import_id\">status</a>";



$html .= "Poll: <div id=\"poll\"></div> Result:<div id=\"result\"></div>";

$initjs .= <<JS

var poll_n = 0;
var timeout = 5000;
var job_info_state;

(function poll() {
  \$.ajax({
    url: '/cgi/import_file_job_status.pl?file_id=$file_id&import_id=$import_id',
    success: function(data) {
      \$('#result').html(data.job_info.state);
	  job_info_state = data.job_info.state;
    },
    complete: function() {
      // Schedule the next request when the current one's complete
	  if (job_info_state == "inactive") {
		setTimeout(poll, timeout);
		timeout += 1000;
	}
	  poll_n++;
	  \$('#poll').html(poll_n);
    }
  });
})();
JS
;

display_new( {
	title=>$title,
	content_ref=>\$html,
});




exit(0);

