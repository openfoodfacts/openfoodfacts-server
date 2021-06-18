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
}
);


function init_select_field_option(col) {

	// Based on the field, display the different field options and instructions

	var column = columns[col];

	var field = columns_fields[column]["field"];

	var instructions = "";

	\$("#select_field_option_" + col).empty();

	if (field) {

		["sources_fields", "categories", "labels"].forEach((tagtype) => {

			var tagtype_specific = tagtype + "_specific";
			var placeholder = [% lang(tagtype + "_s") %];
			var specific_tag = [% lang(tagtype + "_specific_tag") %];
			var specific_tag_value = [% lang(tagtype + "_specific_tag_value") %];


			if (field == "tagtype_specific") {

				var input = '<input id="select_field_option_tag_' + col + '" name="select_field_option_tag_' + col + '" placeholder="placeholder" style="width:150px;margin-bottom:0;height:28px;">';

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

				instructions += "<p>specific_tag</p>"
				+ "<p>specific_tag_value</p>";
			}

		},

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

}