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
use ProductOpener::Store qw/get_string_id_for_lang retrieve/;
use ProductOpener::Display qw/:all/;
use ProductOpener::HTTP qw/single_param/;
use ProductOpener::Users qw/$Owner_id/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Lang qw/$lc lang/;
use ProductOpener::Mail qw/:all/;
use ProductOpener::Producers
	qw/generate_import_export_columns_groups_for_select2 init_columns_fields_match load_csv_or_excel_file/;
use ProductOpener::Tags qw(%language_fields display_taxonomy_tag);
use ProductOpener::Web qw(get_languages_options_list);

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

my $action = single_param('action') || 'display';

my $request_ref = ProductOpener::Display::init_request();

my $title = '';
my $html = '';
my $js = '';
my $template_data_ref = {};

if (not defined $Owner_id) {
	display_error_and_exit($request_ref, lang("no_owner_defined"), 200);
}

my $import_files_ref = retrieve("$BASE_DIRS{IMPORT_FILES}/${Owner_id}/import_files.sto");
if (not defined $import_files_ref) {
	$import_files_ref = {};
}

my $param_file_id = single_param('file_id');
my $file_id = get_string_id_for_lang("no_language", $param_file_id);

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

if ($action eq "display") {

	my $results_ref = load_csv_or_excel_file($file);

	if ($results_ref->{error}) {
		display_error_and_exit($request_ref, $results_ref->{error}, 200);
	}

	my $headers_ref = $results_ref->{headers};
	my $rows_ref = $results_ref->{rows};

	# Analyze the headers column names and rows content to pre-assign fields to columns

	$log->debug("before init_columns_fields_match", {lc => $lc}) if $log->is_debug();

	my $columns_fields_ref = init_columns_fields_match($headers_ref, $rows_ref);

	# Create an options array for select2

	$log->debug("before generate_import_export_columns_groups_for_select2", {lc => $lc}) if $log->is_debug();

	my $select2_options_ref = generate_import_export_columns_groups_for_select2([$lc]);

	$log->debug("after generate_import_export_columns_groups_for_select2", {lc => $lc}) if $log->is_debug();

	# Upload a file

	my $selected_columns_count
		= sprintf(lang("import_file_selected_columns"), '<span class="selected_columns"></span>', @$headers_ref + 0);

	my $field_on_site = sprintf(lang("field_on_site"), lang("site_name"));

	my @table_data_rows;
	my $col = 0;

	foreach my $column (@$headers_ref) {

		my $examples = "";
		my $instructions = "";

		foreach my $example (@{$columns_fields_ref->{$column}{examples}}) {
			$examples .= $example . "\n";
		}

		# We don't need the examples anymore
		delete $columns_fields_ref->{$column}{examples};

		if ($examples ne "") {
			$examples = "<p>" . lang("examples") . "</p>\n<pre>$examples</pre>\n";
		}
		else {
			$examples = "<p>" . lang("empty_column") . "</p>\n";
			$instructions = lang("empty_column_description");
		}

		# Only numbers? Display min and max-height
		if ((defined $columns_fields_ref->{$column}{min}) and ($columns_fields_ref->{$column}{letters} == 0)) {
			$examples
				.= "<br><p>"
				. lang("min") . " "
				. $columns_fields_ref->{$column}{min} . "<br>"
				. lang("max") . " "
				. $columns_fields_ref->{$column}{max} . "</p>";
		}

		my $column_without_tags = $column;
		$column_without_tags =~ s/<(([^>]|\n)*)>//g;

		push(
			@table_data_rows,
			{
				col => $col,
				examples => $examples,
				instructions => $instructions,
				column_without_tags => $column_without_tags,
			}
		);
		$col++;
	}

	my $columns_json = to_json($headers_ref);
	my $columns_fields_json = to_json($columns_fields_ref);
	my $select2_options_json = to_json($select2_options_ref);

	$template_data_ref->{columns_json} = $columns_json;
	$template_data_ref->{columns_fields_json} = $columns_fields_json;
	$template_data_ref->{select2_options_json} = $select2_options_json;
	$template_data_ref->{import_file_rows_columns}
		= sprintf(lang("import_file_rows_columns"), @$rows_ref + 0, @$headers_ref + 0);
	$template_data_ref->{table_data_rows} = \@table_data_rows;
	$template_data_ref->{selected_columns_count} = $selected_columns_count;
	$template_data_ref->{field_on_site} = $field_on_site;
	$template_data_ref->{file_id} = $file_id;

	# List of all languages for the template to display a dropdown for fields that are language specific
	$template_data_ref->{lang_options} = get_languages_options_list($lc);
	$template_data_ref->{language_fields} = [keys %language_fields];

	process_template('web/pages/import_file_select_format/import_file_select_format.tt.html',
		$template_data_ref, \$html);
	process_template('web/pages/import_file_select_format/import_file_select_format.tt.js', $template_data_ref, \$js);
	$request_ref->{initjs} .= $js;

	$request_ref->{title} = $title;
	$request_ref->{content_ref} = \$html;
	display_page($request_ref);
}

exit(0);
