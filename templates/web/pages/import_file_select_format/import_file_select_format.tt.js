
var selected_columns = 0;
var columns = [% columns_json %];
var columns_fields = [% columns_fields_json %];
var select2_options = [% select2_options_json %];

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
});

function init_select_field_option(col) {

	// Based on the field, display the different field options and instructions

	var column = columns[col];

	var field = columns_fields[column]["field"];

	var instructions = "";

	\$("#select_field_option_" + col).empty();

	if (field) {

		[% FOREACH tagtype IN ["sources_fields", "categories", "labels"] %] 

			if (field ==  "[% tagtype %]_specific") {

				var input = '<input id="select_field_option_tag_' + col + '" name="select_field_option_tag_' + col +  '" placeholder= "[% lang("${tagtype}_s") %]" style="width:150px;margin-bottom:0;height:28px;">';

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

				instructions += "<p>[% lang('${tagtype}_specific_tag') %]</p>" + "<p>[% lang('${tagtype}_specific_tag_value') %]</p>";
		
			}
		[% END %]

		// Language specific fields: display a language picker
		if (field.match(/^([% FOREACH language_field IN language_fields %][% language_field %]|[% END %])\$/)) {
			var select = '<select class="select_language" id="select_field_option_lc_' + col + '" name="select_field_option_lc_' + col + '" style="width:150px">'
			[% FOREACH language IN lang_options %]
                select += '<option value="[% language.value %]">[% language.label %]</option>';
            [% END %]
			select += '</select>';
			\$("#select_field_option_" + col).html(select);

			// set selected value from default language, or field language
			var selected_lc = '[% lc %]';
			if (columns_fields[column]["lc"]) {
				selected_lc = columns_fields[column]["lc"];
			}
			else {
				columns_fields[column]["lc"] = selected_lc;
			}
			\$('#select_field_option_lc_' + col).val(selected_lc);

			// setup a select2 widget
			\$('#select_field_option_lc_' + col).select2({
				placeholder: "[% lang('specify') %]"
			}).on("select2:select", function(e) {
				var id = e.params.data.id;
				var col = this.id.replace(/select_field_option_lc_/, '');
				var column = columns[col];
				columns_fields[column]["lc"] = \$(this).val();
			}).on("select2:unselect", function(e) {
			});
		}

		if (field.match(/_value_unit/)) {

			var select = '<select id="select_field_option_value_unit_' + col + '" name="select_field_option_value_unit_' + col + '" style="width:150px">'
			+ '<option></option>';

			if (field.match(/^energy/)) {
				select += "<option value='value_in_kj'>[% lang('value_in_kj') %]</option>"
				+ "<option value='value_in_kcal'>[% lang('value_in_kcal') %]</option>";
			}
			else if (field.match(/weight/)) {
				select += "<option value='value_in_g'>[% lang('value_in_g') %]</option>";
			}
			else if (field.match(/volume/)) {
				select += "<option value='value_in_l'>[% lang('value_in_l') %]</option>"
				+ "<option value='value_in_dl'>[% lang('value_in_dl') %]</option>"
				+ "<option value='value_in_cl'>[% lang('value_in_cl') %]</option>"
				+ "<option value='value_in_ml'>[% lang('value_in_ml') %]</option>";
			}
			else if (field.match(/quantity/)) {
				select += "<option value='value_in_g'>[% lang('value_in_g') %]</option>"
				+ "<option value='value_in_l'>[% lang('value_in_l') %]</option>"
				+ "<option value='value_in_dl'>[% lang('value_in_dl') %]</option>"
				+ "<option value='value_in_cl'>[% lang('value_in_cl') %]</option>"
				+ "<option value='value_in_ml'>[% lang('value_in_ml') %]</option>";
			}
			else {
				select += "<option value='value_in_g'>[% lang('value_in_g') %]</option>"
				+ "<option value='value_in_mg'>[% lang('value_in_mg') %]</option>"
				+ "<option value='value_in_mcg'>[% lang('value_in_mcg') %]</option>"
				+ "<option value='value_in_iu'>[% lang('value_in_iu') %]</option>"
				+ "<option value='value_in_percent'>[% lang('value_in_percent') %]</option>";
			}

			select += "<option value='value_unit'>[% lang('value_unit') %]</option>"
			+ "<option value='value'>[% lang('value') %]</option>"
			+ "<option value='unit'>[% lang('unit') %]</option>"
			+ "</select>";

			\$("#select_field_option_" + col).html(select);

			if (columns_fields[column]["value_unit"]) {
				\$('#select_field_option_value_unit_' + col).val(columns_fields[column]["value_unit"]);
			}

			\$('#select_field_option_value_unit_' + col).select2({
				placeholder: "[% lang('specify') %]"
			}).on("select2:select", function(e) {
				var id = e.params.data.id;
				var col = this.id.replace(/select_field_option_value_unit_/, '');
				var column = columns[col];
				columns_fields[column]["value_unit"] = \$(this).val();
			}).on("select2:unselect", function(e) {
			});

			instructions += "<p>[% lang('value_unit_dropdown') %]'</p>"
			+ "<ul>"
			+ "<li>[% lang('value_unit_dropdown_value_specific_unit') %]</li>"
			+ "<li>[% lang('value_unit_dropdown_value_unit') %]</li>"
			+ "<li>[% lang('value_unit_dropdown_value') %]</li>"
			+ "<li>[% lang('value_unit_dropdown_unit') %]</li>"
			+ "</ul>";
		}
	}

}

function init_select_field() {
	var options = {
		placeholder: "[% lang('select_a_field') %]",
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