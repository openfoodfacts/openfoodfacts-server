[% FOREACH nutrition IN nutrition_products %]

	\$('#[% nutrition.nutrition_data %]').change(function() {
		if (\$(this).prop('checked')) {
			\$('#[% nutrition.nutrition_data_instructions %]').show();
			\$('.[% nutrition.nutriment_col_class %]').show();
		} else {
			\$('#[% nutrition.nutrition_data_instructions %]').hide();
			\$('.[% nutrition.nutriment_col_class %]').hide();
			\$('.nutriment_value_[% nutrition.product_type_as_sold_or_prepared %]').val('');
		}
		update_nutrition_image_copy();
		\$(document).foundation('equalizer', 'reflow');
	});

	\$('input[name=[% nutrition.nutrition_data_per %]]').change(function() {
		if (\$('input[name=[% nutrition.nutrition_data_per %]]:checked').val() == '100g') {
			\$('#[% nutrition.nutrition_data %]_100g').show();
			\$('#[% nutrition.nutrition_data %]_serving').hide();
		} else {
			\$('#[% nutrition.nutrition_data %]_100g').hide();
			\$('#[% nutrition.nutrition_data %]_serving').show();
		}
		update_nutrition_image_copy();
		\$(document).foundation('equalizer', 'reflow');
	});

[% END %]

\$('#no_nutrition_data').change(function() {
	if (\$(this).prop('checked')) {
		\$('#nutrition_data_div').hide();
	} else {
		\$('#nutrition_data_div').show();
	}
});

function show_warning(should_show, nutrient_id, warning_message){
	if(should_show) {
		\$('#nutriment_'+nutrient_id).css("background-color", "rgb(255 237 235)");
		\$('#nutriment_question_mark_'+nutrient_id).css("display", "inline-table");
		\$('#nutriment_sugars_warning_'+nutrient_id).text(warning_message);
	} else {
		// clear the warning only if the warning message we don't show is the same as the existing warning
		// so that we don't remove a warning on sugars > 100g if we change carbohydrates
		if (warning_message == \$('#nutriment_sugars_warning_'+nutrient_id).text()) {
			\$('#nutriment_'+nutrient_id).css("background-color", "white");
			\$('#nutriment_question_mark_'+nutrient_id).css("display", "none");
		}
	}
}

var required_nutrients_id = ['energy-kj', 'energy-kcal', 'fat', 'saturated-fat', 'sugars', 'carbohydrates', 'fiber', 'proteins', 'salt', 'sodium', 'alcohol'];

required_nutrients_id.forEach(nutrient_id => {
	\$('#nutriment_' + nutrient_id).on('input', function() {

		// check the changed nutrient value
		var nutrient_value = \$(this).val().replace(',','.');
		var is_above_or_below_100 = (isNaN(nutrient_value) && nutrient_value != '-') || nutrient_value < 0 || nutrient_value > 100;
		// if the nutrition facts are indicated per serving, the value can be above 100
		if ((nutrient_value > 100) && (\$('#nutrition_data_per_serving').is(':checked'))) {
			is_above_or_below_100 = false;
		}
		show_warning(is_above_or_below_100, nutrient_id, lang().product_js_enter_value_between_0_and_100);

		// check that nutrients are sound (e.g. sugars is not above carbohydrates)
		// but only if the changed nutrient does not have a warning
		// otherwise we may clear the sugars or saturated-fat warning
		if (! is_above_or_below_100) {
			var fat_value = \$('#nutriment_fat').val().replace(',','.');
			var carbohydrates_value = \$('#nutriment_carbohydrates').val().replace(',','.');
			var sugars_value = \$('#nutriment_sugars').val().replace(',','.');
			var saturated_fats_value = \$('#nutriment_saturated-fat').val().replace(',','.');
		
			var is_sugars_above_carbohydrates = parseFloat(carbohydrates_value) < parseFloat(sugars_value);
			show_warning(is_sugars_above_carbohydrates, 'sugars', lang().product_js_sugars_warning);
			
			var is_fat_above_saturated_fats = parseFloat(fat_value) < parseFloat(saturated_fats_value);
			show_warning(is_fat_above_saturated_fats, 'saturated-fat', lang().product_js_saturated_fat_warning);
		}
	});
});
