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
use Data::Dumper;

my $action = param('action') || 'display';

ProductOpener::Display::init();

my $title = '';
my $html = '';
my $template_data_ref = {};

if (not defined $Owner_id) {
	display_error(lang("no_owner_defined"), 200);
}

my $import_files_ref = retrieve("$data_root/import_files/${Owner_id}/import_files.sto");
if (not defined $import_files_ref) {
	$import_files_ref = {};
}

my $param_file_id = param('file_id');
my $file_id = get_string_id_for_lang("no_language", $param_file_id);

local $log->context->{file_id} = $file_id;

my $file;
my $extension;

if (defined $import_files_ref->{$file_id}) {
	$extension = $import_files_ref->{$file_id}{extension};
	$file = "$data_root/import_files/${Owner_id}/$file_id.$extension";
}
else {
	$log->debug("File not found in import_files.sto", { file_id => $file_id }) if $log->is_debug();
	display_error("File not found.", 404);
}

$log->debug("File found in import_files.sto", { file_id => $file_id,  file => $file, extension => $extension, import_file => $import_files_ref->{$file_id} }) if $log->is_debug();


if ($action eq "display") {

	my $results_ref = load_csv_or_excel_file($file);

	if ($results_ref->{error}) {
		display_error($results_ref->{error}, 200);
	}

	my $headers_ref = $results_ref->{headers};
	my $rows_ref = $results_ref->{rows};

	# Analyze the headers column names and rows content to pre-assign fields to columns

	$log->debug("before init_columns_fields_match", { lc=>$lc }) if $log->is_debug();

	my $columns_fields_ref = init_columns_fields_match($headers_ref, $rows_ref);

	# Create an options array for select2

	$log->debug("before generate_import_export_columns_groups_for_select2", { lc=>$lc }) if $log->is_debug();

	my $select2_options_ref = generate_import_export_columns_groups_for_select2([ $lc ]);

	$log->debug("after generate_import_export_columns_groups_for_select2", { lc=>$lc }) if $log->is_debug();

	# Upload a file

	$html .= "<h1>" . lang("import_data_file_select_format_title") . "</h1>\n";
	$html .= "<p>" . lang("import_data_file_select_format_description") . "</p>\n";

	$html .= "<p>" . sprintf(lang("import_file_rows_columns"), @$rows_ref + 0, @$headers_ref + 0) . "</p>";

	my $selected_columns_count = sprintf(lang("import_file_selected_columns"), '<span class="selected_columns"></span>', @$headers_ref + 0);

	$html .= start_multipart_form(-id=>"select_format_form", -action=>"/cgi/import_file_process.pl") ;

	my $field_on_site = sprintf(lang("field_on_site"), lang("site_name"));

	$html .= <<HTML
<input type="submit" class="button small" value="$Lang{import_data}{$lc}">
$selected_columns_count

<table id="select_fields">
<tr><th>$Lang{column_in_file}{$lc}</th><th colspan="2">$field_on_site</th></tr>
HTML
;

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
			$examples .= "<br><p>" . lang("min") . " " . $columns_fields_ref->{$column}{min} . "<br>" . lang("max") . " " . $columns_fields_ref->{$column}{max} . "</p>";
		}
		
		my $column_without_tags = $column;
		$column_without_tags =~ s/<(([^>]|\n)*)>//g;

		push (@table_data_rows, {
			col => $col,
			examples => $examples,
			instructions => $instructions,
			column_without_tags => $column_without_tags,
		});

		$html .= <<HTML
<tr id="column_$col" class="column_row"><td>$column_without_tags</td>
<td>
<select class="select2_field" name="select_field_$col" id="select_field_$col" style="width:420px">
<option></option>
</select>
</td>
<td id="select_field_option_$col">
</td>
</tr>
<tr id="column_info_$col" class="column_info_row" style="display:none">
<td>
$examples
</td>
<td colspan="2" id="column_instructions_$col">
$instructions
</td>
</tr>
HTML
;
		$col++;
	}


	 
	 #$html .= "<p>" . Dumper($template_data_ref) . "</p>";

	$html .= <<HTML
</table>
<input type="hidden" name="columns_fields_json" id="columns_fields_json">
<input type="hidden" name="file_id" id="file_id" value="$file_id">

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

	# JSON structures to pass to the javascript

	my $columns_json = to_json($headers_ref);

	my $columns_fields_json = to_json($columns_fields_ref);

	my $select2_options_json = to_json($select2_options_ref);

	$template_data_ref->{columns_json} = $columns_json;
	$template_data_ref->{columns_fields_json} = $columns_fields_json;
	$template_data_ref->{select2_options_json} = $select2_options_json;

	$initjs .= <<JS
var selected_columns = 0;

var columns = $columns_json;

var columns_fields = $columns_fields_json ;

var select2_options = $select2_options_json ;

\$( '#select_format_form' ).submit(function( event ) {
  \$('#columns_fields_json').val(JSON.stringify(columns_fields));
});

function show_column_info(col) {

	\$('.column_info_row').hide();
	\$('#column_info_' + col).show();
}

\$('.column_row').click( function() {
	var col = this.id.replace(/column_/, '');
	show_column_info(col);
	\$(document).foundation('equalizer', 'reflow');
}
);

function init_select_field_option(col) {

	// Based on the field, display the different field options and instructions

	var column = columns[col];

	var field = columns_fields[column]["field"];

	var instructions = "";

	\$("#select_field_option_" + col).empty();

	if (field) {
JS
;

	foreach my $tagtype ("sources_fields", "categories", "labels") {

		my $tagtype_specific = $tagtype . "_specific";
		my $placeholder = $Lang{$tagtype . "_s"}{$lc};
		my $specific_tag = $Lang{$tagtype . "_specific_tag"}{$lc};
		my $specific_tag_value = $Lang{$tagtype . "_specific_tag_value"}{$lc};

		$initjs .= <<JS
		if (field == "$tagtype_specific") {

			var input = '<input id="select_field_option_tag_' + col + '" name="select_field_option_tag_' + col + '" placeholder="$placeholder" style="width:150px;margin-bottom:0;height:28px;">';

			\$("#select_field_option_" + col).html(input);

			if (columns_fields[column]["tag"]) {
				\$('#select_field_option_tag_' + col).val(columns_fields[column]["tag"]);
			}

			\$('#select_field_option_tag_' + col)
			.on("change", function(e) {
				var id = e.target.id;
				var col = this.id.replace(/select_field_option_tag_/, '');
				var column = columns[col];
				columns_fields[column]["tag"] = \$(this).val();
			});

			instructions += "<p>$specific_tag</p>"
			+ "<p>$specific_tag_value</p>";
		}
JS
;
	}

	$initjs .= <<JS
		else if (field.match(/_value_unit/)) {

			var select = '<select id="select_field_option_value_unit_' + col + '" name="select_field_option_value_unit_' + col + '" style="width:150px">'
			+ '<option></option>';

			if (field.match(/^energy/)) {
				select += '<option value="value_in_kj">$Lang{value_in_kj}{$lc}</option>'
				+ '<option value="value_in_kcal">$Lang{value_in_kcal}{$lc}</option>';
			}
			else if (field.match(/weight/)) {
				select += '<option value="value_in_g">$Lang{value_in_g}{$lc}</option>';
			}
			else if (field.match(/volume/)) {
				select += '<option value="value_in_l">$Lang{value_in_l}{$lc}</option>'
				+ '<option value="value_in_dl">$Lang{value_in_dl}{$lc}</option>'
				+ '<option value="value_in_cl">$Lang{value_in_cl}{$lc}</option>'
				+ '<option value="value_in_ml">$Lang{value_in_ml}{$lc}</option>';
			}
			else if (field.match(/quantity/)) {
				select += '<option value="value_in_g">$Lang{value_in_g}{$lc}</option>'
				+ '<option value="value_in_l">$Lang{value_in_l}{$lc}</option>'
				+ '<option value="value_in_dl">$Lang{value_in_dl}{$lc}</option>'
				+ '<option value="value_in_cl">$Lang{value_in_cl}{$lc}</option>'
				+ '<option value="value_in_ml">$Lang{value_in_ml}{$lc}</option>';
			}
			else {
				select += '<option value="value_in_g">$Lang{value_in_g}{$lc}</option>'
				+ '<option value="value_in_mg">$Lang{value_in_mg}{$lc}</option>'
				+ '<option value="value_in_mcg">$Lang{value_in_mcg}{$lc}</option>'
				+ '<option value="value_in_iu">$Lang{value_in_iu}{$lc}</option>'
				+ '<option value="value_in_percent">$Lang{value_in_percent}{$lc}</option>';
			}

			select += '<option value="value_unit">$Lang{value_unit}{$lc}</option>'
			+ '<option value="value">$Lang{value}{$lc}</option>'
			+ '<option value="unit">$Lang{unit}{$lc}</option>'
			+ '</select>';

			\$("#select_field_option_" + col).html(select);

			if (columns_fields[column]["value_unit"]) {
				\$('#select_field_option_value_unit_' + col).val(columns_fields[column]["value_unit"]);
			}

			\$('#select_field_option_value_unit_' + col).select2({
				placeholder: "$Lang{specify}{$lc}"
			}).on("select2:select", function(e) {
				var id = e.params.data.id;
				var col = this.id.replace(/select_field_option_value_unit_/, '');
				var column = columns[col];
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

	\$("#column_instructions_" + col).html(instructions);
}


function init_select_field() {

	var options = {
		placeholder: "$Lang{select_a_field}{$lc}",
		data:select2_options,
		allowClear: true
	};

	var col = this.id.replace(/select_field_/, '');
	var column = columns[col];

	\$(this).select2(options).on("select2:select", function(e) {
		var id = e.params.data.id;
		var col = this.id.replace(/select_field_/, '');
		var column = columns[col];
		if (! columns_fields[column]["field"]) {
			selected_columns++;
		}
		columns_fields[column]["field"] = \$(this).val();
		init_select_field_option(col);
		\$('.selected_columns').text(selected_columns);
	}).on("select2:unselect", function(e) {
		delete columns_fields[column]["field"];
		selected_columns--;
		\$('.selected_columns').text(selected_columns);
	});

	if (columns_fields[column]["field"]) {
		\$(this).val(columns_fields[column]["field"]);
		\$(this).trigger('change');
		selected_columns++;
	}

	init_select_field_option(col);

}



\$('.select2_field').each(init_select_field);

\$('.selected_columns').text(selected_columns);

JS
;

	$template_data_ref->{import_file_rows_columns} = sprintf(lang("import_file_rows_columns"), @$rows_ref + 0, @$headers_ref + 0);
	$template_data_ref->{selected_columns_count} = $selected_columns_count;
	$template_data_ref->{field_on_site} = $field_on_site;
	$template_data_ref->{table_data_rows} = \@table_data_rows;
	$template_data_ref->{file_id} = $file_id;



	process_template('web/pages/import_file_select_format/import_file_select_format.tt.html', $template_data_ref, \$html);

	display_page( {
		title=>$title,
		content_ref=>\$html,
	});
}


exit(0);

