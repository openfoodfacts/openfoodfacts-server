
console.log("Try 07");


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

		var x = \$('input[name=[% nutrition.nutrition_data_per %]]:checked').val();
		console.log(x);
		if (\$('input[name=[% nutrition.nutrition_data_per %]]:checked').val() == '100g') {
			console.log('yes');
			\$('#[% nutrition.nutrition_data %]_100g').show();
			\$('#[% nutrition.nutrition_data %]_serving').hide();
		} else {
			console.log("no");
			console.log('[% nutrition.nutrition_data %]_100g');
			console.log('[% nutrition.nutrition_data %]_serving');
			\$('#[% nutrition.nutrition_data %]_100g').hide();
			\$('#[% nutrition.nutrition_data %]_serving').show();
		}
		update_nutrition_image_copy();
		\$(document).foundation('equalizer', 'reflow');
	});

[% END %]
