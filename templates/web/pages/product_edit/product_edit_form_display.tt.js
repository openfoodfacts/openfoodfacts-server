
console.log("Try 04");

[% FOREACH nutrition IN nutrition_products %]

	$('#[% nutrition.nutrition_data %]').change(function() {
		if ($(this).prop('checked')) {
			$('#[% nutrition.nutrition_data_instructions %]').show();
			$('.[% nutrition.nutriment_col_class %]').show();
		} else {
			$('#[% nutrition.nutrition_data_instructions %]').hide();
			$('.[% nutrition.nutriment_col_class %]').hide();
			$('.nutriment_value_[% nutrition.product_type_as_sold_or_prepared %]').val('');
		}
		update_nutrition_image_copy();
		$(document).foundation('equalizer', 'reflow');
	});

	$('input[name=[% nutrition.nutrition_data_per %]]').change(function() {
		if ($('input[name=[% nutrition.nutrition_data_per %]]:checked').val() == '100g') {
			$('#$[% nutrition.nutrition_data %]_100g').show();
			$('#$[% nutrition.nutrition_data %]_serving').hide();
		} else {
			$('#$[% nutrition.nutrition_data %]_100g').hide();
			$('#$[% nutrition.nutrition_data %]_serving').show();
		}
		update_nutrition_image_copy();
		$(document).foundation('equalizer', 'reflow');
	});

[% END %]

/*
$('#manage_images_accordion').on('toggled', function (event, accordion) {

	toggle_manage_images_buttons();
});



$("#delete_images").click({},function(event) {

event.stopPropagation();
event.preventDefault();


if (! $("#delete_images").hasClass("disabled")) {

	$("#delete_images").addClass("disabled");
	$("#move_images").addClass("disabled");

 $('div[id="moveimagesmsg"]').html('<img src="/images/misc/loading2.gif" /> ' + lang().product_js_deleting_images);
 $('div[id="moveimagesmsg"]').show();

	var imgids = '';
	var i = 0;
	$( "#manage .ui-selected"  ).each(function() {
		var imgid = $( this ).attr('id');
		imgid = imgid.replace("manage_","");
		imgids += imgid + ',';
		i++;
});
	if (i) {
		// remove trailing comma
		imgids = imgids.substring(0, imgids.length - 1);
	}

 $("#product_form").ajaxSubmit({

  url: "/cgi/product_image_move.pl",
  data: { code: code, move_to_override: "trash", imgids : imgids },
  dataType: 'json',
  beforeSubmit: function(a,f,o) {
  },
  success: function(data) {

	if (data.error) {
		$('div[id="moveimagesmsg"]').html(lang().product_js_images_delete_error + ' - ' + data.error);
	}
	else {
		$('div[id="moveimagesmsg"]').html(lang().product_js_images_deleted);
	}
	$([]).selectcrop('init_images',data.images);
	$(".select_crop").selectcrop('show');

  },
  error : function(jqXHR, textStatus, errorThrown) {
	$('div[id="moveimagesmsg"]').html(lang().product_js_images_delete_error + ' - ' + textStatus);
  },
  complete: function(XMLHttpRequest, textStatus) {

	}
 });

}

});



$("#move_images").click({},function(event) {

event.stopPropagation();
event.preventDefault();


if (! $("#move_images").hasClass("disabled")) {

	$("#delete_images").addClass("disabled");
	$("#move_images").addClass("disabled");

 $('div[id="moveimagesmsg"]').html('<img src="/images/misc/loading2.gif" /> ' + lang().product_js_moving_images);
 $('div[id="moveimagesmsg"]').show();

	var imgids = '';
	var i = 0;
	$( "#manage .ui-selected"  ).each(function() {
		var imgid = $( this ).attr('id');
		imgid = imgid.replace("manage_","");
		imgids += imgid + ',';
		i++;
});
	if (i) {
		// remove trailing comma
		imgids = imgids.substring(0, imgids.length - 1);
	}

$("#product_form").ajaxSubmit({

  url: "/cgi/product_image_move.pl",
  data: { code: code, move_to_override: $("#move_to").val(), copy_data_override: $("#copy_data").prop( "checked" ), imgids : imgids },
  dataType: 'json',
  beforeSubmit: function(a,f,o) {
  },
  success: function(data) {

	if (data.error) {
		$('div[id="moveimagesmsg"]').html(lang().product_js_images_move_error + ' - ' + data.error);
	}
	else {
		$('div[id="moveimagesmsg"]').html(lang().product_js_images_moved + ' &rarr; ' + data.link);
	}
	$([]).selectcrop('init_images',data.images);
	$(".select_crop").selectcrop('show');

  },
  error : function(jqXHR, textStatus, errorThrown) {
	$('div[id="moveimagesmsg"]').html(lang().product_js_images_move_error + ' - ' + textStatus);
  },
  complete: function(XMLHttpRequest, textStatus) {
		$("#move_images").addClass("disabled");
		$("#move_images").addClass("disabled");
		$( "#manage .ui-selected"  ).first().each(function() {
			$("#move_images").removeClass("disabled");
			$("#move_images").removeClass("disabled");
		});
	}
 });

}

});

$('#no_nutrition_data').change(function() {
	if ($(this).prop('checked')) {
		$('#nutrition_data_table input').prop('disabled', true);
		$('#nutrition_data_table select').prop('disabled', true);
		$('#multiple_nutrition_data').prop('disabled', true);
		$('#multiple_nutrition_data').prop('checked', false);
		$('#nutrition_data_table input.nutriment_value').val('');
		$('#nutrition_data_table').hide();
	} else {
		$('#nutrition_data_table input').prop('disabled', false);
		$('#nutrition_data_table select').prop('disabled', false);
		$('#multiple_nutrition_data').prop('disabled', false);
		$('#nutrition_data_table').show();
	}
	update_nutrition_image_copy();
	$(document).foundation('equalizer', 'reflow');
});



$( ".nutriment_label" ).autocomplete({
	source: otherNutriments,
	select: select_nutriment,
	//change: add_line
});

$("#nutriment_sodium").change( function () {
	swapSalt($("#nutriment_sodium"), $("#nutriment_salt"), 2.5);
}
);

$("#nutriment_salt").change( function () {
	swapSalt($("#nutriment_salt"), $("#nutriment_sodium"), 1/2.5);
}
);

$("#nutriment_sodium_prepared").change( function () {
	swapSalt($("#nutriment_sodium_prepared"), $("#nutriment_salt_prepared"), 2.5);
}
);

$("#nutriment_salt_prepared").change( function () {
	swapSalt($("#nutriment_salt_prepared"), $("#nutriment_sodium_prepared"), 1/2.5);
}
);

function swapSalt(from, to, multiplier) {
	var source = from.val().replace(",", ".");
	var regex = /^(.*?)([\\d]+(?:\\.[\\d]+)?)(.*?)\$/g;
	var match = regex.exec(source);
	if (match) {
		var target = match[1] + (parseFloat(match[2]) * multiplier) + match[3];
		to.val(target);
	} else {
		to.val(from.val());
	}
}

$("#nutriment_sodium_unit").change( function () {
	$("#nutriment_salt_unit").val( $("#nutriment_sodium_unit").val());
}
);

$("#nutriment_salt_unit").change( function () {
	$("#nutriment_sodium_unit").val( $("#nutriment_salt_unit").val());
}
);

$("#nutriment_new_0_label").change(add_line);
$("#nutriment_new_1_label").change(add_line);


var parent_width = $("#fixed_bar").parent().width();
$("#fixed_bar").width(parent_width);

$(window).resize(
	function() {
		var parent_width = $("#fixed_bar").parent().width();
		$("#fixed_bar").width(parent_width);
	}
)

*/