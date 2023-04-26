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

function show_warning(should_show, nutirent_id, warning_message){
	if(should_show) {
		\$('#nutriment_'+nutirent_id).css("background-color", "rgb(255 237 235)");
		\$('#nutriment_question_mark_'+nutirent_id).css("display", "inline-table");
		\$('#nutriment_sugars_warning_'+nutirent_id).text(warning_message);
	}else {
		\$('#nutriment_'+nutirent_id).css("background-color", "white");
		\$('#nutriment_question_mark_'+nutirent_id).css("display", "none");
	}
}

var sugars_value;
var carbohydrates_value;
var saturated_fats_value;
var fat_value;

var required_nutrients_id = ['energy-kj', 'energy-kcal', 'fat', 'saturated-fat', 'sugars', 'carbohydrates', 'fiber', 'proteins', 'salt', 'sodium', 'alcohol'];

required_nutrients_id.forEach(nutirent_id => {
	\$('#nutriment_' + nutirent_id).on('input', function() {
		var nutrient_value = \$(this).val();
		var is_above_or_below_100 = isNaN(nutrient_value) || nutrient_value < 0 || nutrient_value > 100;
		show_warning(is_above_or_below_100, nutirent_id, "Please enter a value between 0 and 100");

		var crutial_nutrients = ['fat', 'saturated-fat', 'sugars', 'carbohydrates'];

		if (crutial_nutrients.includes(nutirent_id)) {
			switch(nutirent_id) {
				case "saturated-fat":
					saturated_fats_value = nutrient_value;
					break;
				case "sugars":
					sugars_value = nutrient_value;
					break;
				case "carbohydrates":
					carbohydrates_value = nutrient_value;
					break;
				case "fat":
					fat_value = nutrient_value;
					break;
			}
			
			if(!fat_value) {
				fat_value = \$('#nutriment_fat').val();
			}
			if(!carbohydrates_value){
				carbohydrates_value = \$('#nutriment_carbohydrates').val();
			}
			if(!sugars_value) {
				sugars_value = \$('#nutriment_sugars').val();
			}
			if(!saturated_fats_value) {
				saturated_fats_value = \$('#nutriment_saturated-fat').val();
			}

			var is_sugars_above_carbohydrates = carbohydrates_value < sugars_value;
			show_warning(is_sugars_above_carbohydrates, 'sugars', 'Sugars should not be higher than carbohydrates');

			var is_fat_above_saturated_fats = fat_value < saturated_fats_value;
			show_warning(is_fat_above_saturated_fats, 'saturated-fat', 'Saturated fats should not be higher than fat');
		}
	});
});
