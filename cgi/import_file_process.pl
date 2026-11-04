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
use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Store qw/get_string_id_for_lang retrieve store/;
use ProductOpener::Display qw/:all/;
use ProductOpener::HTTP qw/single_param/;
use ProductOpener::Users qw/$Org_id $Owner_id $User_id/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Lang qw/$lc lang/;
use ProductOpener::Mail qw/:all/;
use ProductOpener::Producers
	qw/convert_file get_minion get_selectable_import_fields is_import_field_allowed load_csv_or_excel_file normalize_column_name/;
use ProductOpener::Orgs qw/update_last_import_type/;

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

my $request_ref = ProductOpener::Display::init_request();

my $title = lang("import_file_status_title");
my $html = '';
my $js = '';
my $template_data_ref;

# Decode and validate the column mapping before anything else: each field name becomes the
# header row of the converted CSV, and import_csv_file reads that row to tell whether a cell
# is product text, an organization attribution or a local file path. The server, not the
# client, decides which fields an import may target, so only the fields the mapping
# interface offers to this user are accepted.

my $columns_fields_json = single_param("columns_fields_json");
my $columns_fields_ref = eval {decode_json($columns_fields_json)};

if ((not defined $columns_fields_ref) or (ref($columns_fields_ref) ne "HASH")) {
	display_error_and_exit($request_ref, "Invalid columns_fields_json parameter.", 400);
}

my $selectable_fields_ref = get_selectable_import_fields();
my @invalid_columns;
my @non_selectable_fields;

foreach my $column (keys %$columns_fields_ref) {

	# A column must map to an object: the code below and convert_file() both expect that
	if (ref($columns_fields_ref->{$column}) ne "HASH") {
		$log->error("rejected a column whose mapping is not an object", {column => $column})
			if $log->is_error();
		push @invalid_columns, escapeHTML($column);
		next;
	}

	my $field = $columns_fields_ref->{$column}{field};
	next if not defined $field;

	if ((ref $field) or (not is_import_field_allowed($field, $selectable_fields_ref))) {
		$log->error(
			"rejected a column mapped to a field that is not selectable",
			{column => $column, field => ref($field) ? ref($field) : $field}
		) if $log->is_error();
		push @non_selectable_fields, escapeHTML(ref($field) ? $column : $field);
	}
}

if (@invalid_columns) {
	# Do not echo an unbounded list back to the caller
	splice(@invalid_columns, 10) if scalar(@invalid_columns) > 10;
	display_error_and_exit(
		$request_ref,
		"Invalid columns_fields_json parameter: these columns are not mapping objects: " . join(", ", @invalid_columns),
		400
	);
}

if (@non_selectable_fields) {
	# Do not echo an unbounded list of field names back to the caller
	splice(@non_selectable_fields, 10) if scalar(@non_selectable_fields) > 10;
	display_error_and_exit($request_ref,
		"Some columns are mapped to fields that cannot be imported: " . join(", ", @non_selectable_fields), 400);
}

if (not defined $Owner_id) {
	display_error_and_exit($request_ref, lang("no_owner_defined"), 200);
}

my $import_files_ref = retrieve("$BASE_DIRS{IMPORT_FILES}/${Owner_id}/import_files.sto");
if (not defined $import_files_ref) {
	$import_files_ref = {};
}

my $file_id = get_string_id_for_lang("no_language", single_param('file_id'));

local $log->context->{file_id} = $file_id;

my $file;
my $extension;

if (defined $import_files_ref->{$file_id}) {
	$extension = $import_files_ref->{$file_id}{extension};
	$file = "$BASE_DIRS{IMPORT_FILES}/${Owner_id}/$file_id.$extension";
}
else {
	$log->debug("File not found in import_files.sto", {file_id => $file_id}) if $log->is_debug();
	display_error_and_exit($request_ref, "File not found.", 404);
}

$log->debug("File found in import_files.sto",
	{file_id => $file_id, file => $file, extension => $extension, import_file => $import_files_ref->{$file_id}})
	if $log->is_debug();

# Store user columns to OFF fields matches so that they can be reused for the next imports

my $all_columns_fields_ref = retrieve("$BASE_DIRS{IMPORT_FILES}/${Owner_id}/all_columns_fields.sto");
if (not defined $all_columns_fields_ref) {
	$all_columns_fields_ref = {};
}

my $results_ref = load_csv_or_excel_file($file);

if ($results_ref->{error}) {
	display_error_and_exit($request_ref, $results_ref->{error}, 200);
}

my $headers_ref = $results_ref->{headers};
my $rows_ref = $results_ref->{rows};

foreach my $field (keys %$columns_fields_ref) {
	delete $columns_fields_ref->{$field}{numbers};
	delete $columns_fields_ref->{$field}{letters};
	delete $columns_fields_ref->{$field}{both};
	delete $columns_fields_ref->{$field}{min};
	delete $columns_fields_ref->{$field}{max};
	delete $columns_fields_ref->{$field}{n};

	my $column_id = get_string_id_for_lang("no_language", normalize_column_name($field));

	$all_columns_fields_ref->{$column_id} = $columns_fields_ref->{$field};

	$log->debug("Field in columns_field_json",
		{field => $field, column_id => $column_id, value => $columns_fields_ref->{$field}})
		if $log->is_debug();
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

store("$BASE_DIRS{IMPORT_FILES}/${Owner_id}/all_columns_fields.sto", $all_columns_fields_ref);

# Default values: use the language and country of the interface
my $default_values_ref = {
	lc => $lc,
	countries => $request_ref->{cc},
};

$results_ref = convert_file($default_values_ref, $file, $columns_fields_file, $converted_file);

$import_files_ref->{$file_id}{imports}{$import_id}{converted_t} = time();

if ($results_ref->{error}) {
	$import_files_ref->{$file_id}{imports}{$import_id}{convert_error} = $results_ref->{error};
	store("$BASE_DIRS{IMPORT_FILES}/${Owner_id}/import_files.sto", $import_files_ref);
	display_error_and_exit($request_ref, $results_ref->{error}, 200);
}

my $args_ref = {
	user_id => $User_id,
	org_id => $Org_id,
	owner_id => $Owner_id,
	csv_file => $converted_file,
	file_id => $file_id,
	import_id => $import_id,
	comment => "Import from producers platform",
	images_download_dir => "$BASE_DIRS{IMPORT_FILES}/${Owner_id}/downloaded_images",
};

if (defined $Org_id) {
	$args_ref->{source_id} = "org-" . $Org_id;
	$args_ref->{source_name} = $Org_id;

	# We currently do not have organization profiles to differentiate producers, apps, labels databases, other databases
	# in the mean time, use a naming convention:  label-something, database-something and treat
	# everything else as a producers
	if ($Org_id =~ /^app-/) {
		$args_ref->{manufacturer} = 0;
		$args_ref->{global_values} = {data_sources => "Apps, " . $Org_id, imports => $import_id};
	}
	if ($Org_id =~ /^database-/) {
		$args_ref->{manufacturer} = 0;
		$args_ref->{global_values} = {data_sources => "Databases, " . $Org_id, imports => $import_id};
	}
	elsif ($Org_id =~ /^label-/) {
		$args_ref->{manufacturer} = 0;
		$args_ref->{global_values} = {data_sources => "Labels, " . $Org_id, imports => $import_id};
	}
	else {
		$args_ref->{manufacturer} = 1;
		$args_ref->{global_values} = {data_sources => "Producers, Producer - " . $Org_id, imports => $import_id};
	}

}
else {
	$args_ref->{no_source} = 1;
}

my $job_id = get_minion()->enqueue(import_csv_file => [$args_ref] => {queue => $server_options{minion_local_queue}});

$import_files_ref->{$file_id}{imports}{$import_id}{job_id} = $job_id;

store("$BASE_DIRS{IMPORT_FILES}/${Owner_id}/import_files.sto", $import_files_ref);

update_last_import_type($Org_id, 'CSV');

$template_data_ref->{process_file_id} = $file_id;
$template_data_ref->{process_import_id} = $import_id;
$template_data_ref->{link} = "/cgi/import_file_job_status.pl?file_id=$file_id&import_id=$import_id";

process_template('web/pages/import_file_process/import_file_process.tt.html', $template_data_ref, \$html, $request_ref);
process_template('web/pages/import_file_process/import_file_process.tt.js', $template_data_ref, \$js, $request_ref);

$request_ref->{initjs} .= $js;

$request_ref->{scripts} .= <<HTML
<script type="text/javascript" src="/js/dist/jquery.iframe-transport.js"></script>
<script type="text/javascript" src="/js/dist/jquery.fileupload.js"></script>
HTML
	;

$request_ref->{title} = $title;
$request_ref->{content_ref} = \$html;
display_page($request_ref);

exit(0);
