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

my $type = param('type') || 'upload';
my $action = param('action') || 'display';

my $title = '';
my $html = '';

local $log->context->{type} = $type;
local $log->context->{action} = $action;

my $owner = "user-" . $User_id;
if (defined $Org_id) {
	$owner = "org-" . $Org_id;
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


if ($action eq "display") {

	# Spreasdsheet::CSV does not like CSV files with a BOM:
	# Wide character in print at /usr/local/share/perl/5.24.1/Spreadsheet/CSV.pm line 87.
	#

	# There are many issues with Spreadsheet::CSV handling of CSV files
	# (depending on whether there is a BOM, encoding, line endings etc.
	# -> use Spreadsheet::CSV only for Excel files
	# -> use Text::CSV directly for CSV files

	my $headers_ref = undef;
	my @rows = ();

	if (($extension eq "csv") or ($extension eq "tsv") or ($extension eq "txt")) {

		my $encoding = "UTF-8";

		$log->debug("opening CSV file", { file => $file, extension => $extension }) if $log->is_debug();

		my $csv_options_ref = { binary => 1 , sep_char => "\t" };

		my $csv = Text::CSV->new ( $csv_options_ref )  # should set binary attribute.
                 or die "Cannot use CSV: " . Text::CSV->error_diag ();

		open (my $io, "<:encoding($encoding)", $file) or die("Could not open CSV $file: $!");

		$headers_ref = [$csv->header ($io, { detect_bom => 1 })];

		while (my $row = $csv->getline ($io)) {
			push @rows, $row;
		}
	}
	else {
		$log->debug("opening Excel file", { file => $file, extension => $extension }) if $log->is_debug();

		open (my $io, "<", $file) or die("Could not open Excel $file: $!");

		my $csv_options_ref = { binary => 1 , sep_char => "\t" };

		my $csv = Spreadsheet::CSV->new();

		# Assume first line is headers line
		$headers_ref = $csv->getline ($io);

		if (not defined $headers_ref) {
			display_error("Unsupported file format (extension: $extension).", 200);
		}

		while (my $row = $csv->getline ($io)) {
			push @rows, $row;
		}
	}

	# Analyze the headers column names and rows content to pre-assign fields to columns

	my $columns_fields_ref = init_columns_fields_match($headers_ref, \@rows);
	my $columns_fields_json = to_json($columns_fields_ref);

	# Create an options array for select2

	my $select2_options_ref = generate_import_export_columns_groups_for_select2($options{import_export_fields_groups}, [ $lc ]);
	my $select2_options_json = to_json($select2_options_ref);

	# Number of pre-selected columns
	my $selected = 0;

	# Upload a file

	$html .= "<h1>" . lang("import_data_file_select_format_title") . "</h1>\n";
	$html .= "<p>" . lang("import_data_file_select_format_description") . "</p>\n";

	$html .= "<p>" . sprintf(lang("import_file_rows_columns"), @rows + 0, @$headers_ref + 0) . "</p>";

	my $selected_columns_count = sprintf(lang("import_file_selected_columns"), '<span class="selected_columns">' . $selected . '</span>', @$headers_ref + 0);

	$html .= start_multipart_form(-id=>"select_format_form") ;

	$html .= <<HTML
<input type="submit" class="button small" value="$Lang{import_data}{$lc}">
$selected_columns_count

<table id="select_fields">
<tr><th>Column in file</th><th colspan="2">Field on Open Food Facts</th></tr>
HTML
;

	my $col = 0;

	foreach my $column (@$headers_ref) {

		my $examples = "";

		foreach my $example (@{$columns_fields_ref->{$column}{examples}}) {
			$examples .= $example . "\n";
		}

		if ($examples ne "") {
			$examples = "<p>" . lang("examples") . "</p>\n<pre>$examples</pre>\n";
		}

		$html .= <<HTML
<tr id="column_$column" class="column_row"><td>$column</td>
<td>
<select class="select2_field" name="select_field_$column" id="select_field_$column" style="width:420px">
<option></option>
</select>
</td>
<td id="select_field_option_$column">
</td>
</tr>
<tr id="column_info_$column" class="column_info_row" style="display:none">
<td>
$examples
</td>
<td colspan="2" id="column_instructions_$column">
</td>
</tr>
HTML
;
		$column++;
	}

	$html .= <<HTML
</table>
<input type="hidden" name="columns_fields_json" id="columns_fields_json">
<input type="hidden" name="file_id" id="$file_id">

<input type="submit" class="button small" value="$Lang{import_data}{$lc}">
$selected_columns_count
HTML
;

	$html .= end_form();


	$scripts .= <<JS

JS
;

	$styles .= <<CSS
.select2-container--default .select2-results > .select2-results__options {
    max-height: 400px
}

pre {
	max-width:16em;
	overflow-x:auto;
}
CSS
;

	$initjs .= <<JS

var columns_fields = $columns_fields_json ;

var select2_options = $select2_options_json ;


function show_column_info(column) {

	\$('.column_info_row').hide();
	\$('#column_info_' + column).show();
}

\$('.column_row').click( function() {
	var column = this.id.replace(/column_/, '');
	show_column_info(column);
}
);

function init_select_field_option(column) {

	// Based on the field, display the different field options and instructions

	var field = columns_fields[column]["field"];

	var instructions = "";

	\$("#select_field_option_" + column).empty();

	if (field) {
		if (field.match(/_value_unit/)) {

			var select = '<select id="select_field_option_value_unit_' + column + '" name="select_field_option_value_unit_' + column + '" style="width:150px">'
			+ '<option></option>';

			if (field.match(/^energy/)) {
				select += '<option value="value_in_kj">$Lang{value_in_kj}{$lc}</option>'
				+ '<option value="value_in_kcal">$Lang{value_in_kcal}{$lc}</option>';
			}

			select += '<option value="value_unit">$Lang{value_unit}{$lc}</option>'
			+ '<option value="value">$Lang{value}{$lc}</option>'
			+ '<option value="unit">$Lang{unit}{$lc}</option>'
			+ '</select>';

			\$("#select_field_option_" + column).html(select);

			if (columns_fields[column]["value_unit"]) {
				\$('#select_field_option_value_unit_' + column).val(columns_fields[column]["value_unit"]);
			}

			\$('#select_field_option_value_unit_' + column).select2({
				placeholder: "$Lang{specify}{$lc}"
			}).on("select2:select", function(e) {
				var id = e.params.data.id;
				var column = this.id.replace(/select_field_option_value_unit_/, '');
				columns_fields[column]["value_unit"] = \$(this).val();
			}).on("select2:unselect", function(e) {
			});

			instructions += "<p>$Lang{value_unit_dropdown}{$lc}</p>"
			+ "<ul>"
			+ "<li>$Lang{value_unit_dropdown_value_specific_unit}{$lc}</li>"
			+ "<li>$Lang{value_unit_dropdown_value_unit}{$lc}</li>"
			+ "<li>$Lang{value_unit_dropdown_value}{$lc}</li>"
			+ "<li>$Lang{value_unit_dropdown_unit}{$lc}</li>"
			+ "</ul>";
		}
	}

	\$("#column_instructions_" + column).html(instructions);
}


function init_select_field() {

	var options = {
		placeholder: "$Lang{select_a_field}{$lc}",
		data:select2_options,
		allowClear: true
	};

	var column = this.id.replace(/select_field_/, '');

	\$(this).select2(options).on("select2:select", function(e) {
		var id = e.params.data.id;
		var column = this.id.replace(/select_field_/, '');
		columns_fields[column]["field"] = \$(this).val();
		init_select_field_option(column);
	}).on("select2:unselect", function(e) {
	});

	if (columns_fields[column]["field"]) {
		\$(this).val(columns_fields[column]["field"]);
		\$(this).trigger('change');
	}

	init_select_field_option(column);

}

\$('.select2_field').each(init_select_field);


\$( "#select_format_form" ).submit(function( event ) {
  \$('#columns_fields_json').val(JSON.stringify(columns_fields));
  //event.preventDefault();
});



JS
;

	display_new( {
		title=>$title,
		content_ref=>\$html,
	});
}
elsif ($action eq "process") {

	my $columns_fields_json = param("columns_fields_json");

	$html .= "<p>columns_fields_json:</p>" . $columns_fields_json;

	display_new( {
		title=>$title,
		content_ref=>\$html,
	});
}

exit(0);

