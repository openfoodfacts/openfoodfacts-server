'use strict';
\$(function() {
  var alerts = \$('.alert-box.store-state');
  \$.each(alerts, function( index, value ) {
    var display = \$.cookie('state_' + value.id);
    if (display !== undefined) {
      value.style.display = display;
    } else {
      value.style.display = 'block';
    }
  });
  alerts.on('close.fndtn.alert', function(event) {
    \$.cookie('state_' + \$(this)[0].id, 'none', { path: '/', expires: 365, domain: '$server_domain' });
  });
});



\$('#manage_images_accordion').on('toggled', function (event, accordion) {

	toggle_manage_images_buttons();
});



\$("#delete_images").click({},function(event) {

  event.stopPropagation();
  event.preventDefault();
  
  
  if (! \$("#delete_images").hasClass("disabled")) {
  
    \$("#delete_images").addClass("disabled");
    \$("#move_images").addClass("disabled");
  
   \$('div[id="moveimagesmsg"]').html('<img src="/images/misc/loading2.gif" /> ' + lang().product_js_deleting_images);
   \$('div[id="moveimagesmsg"]').show();
  
    var imgids = '';
    var i = 0;
    \$( "#manage .ui-selected"  ).each(function() {
      var imgid = \$( this ).attr('id');
      imgid = imgid.replace("manage_","");#$html .= "<p>" . Dumper($template_data_ref) . "</p>";
      imgids += imgid + ',';
      i++;
  });
    if (i) {
      // remove trailing comma
      imgids = imgids.substring(0, imgids.length - 1);
    }
  
   \$("#product_form").ajaxSubmit({
  
    url: "/cgi/product_image_move.pl",
    data: { code: code, move_to_override: "trash", imgids : imgids },
    dataType: 'json',
    beforeSubmit: function(a,f,o) {
    },
    success: function(data) {
  
    if (data.error) {
      \$('div[id="moveimagesmsg"]').html(lang().product_js_images_delete_error + ' - ' + data.error);
    }
    else {
      \$('div[id="moveimagesmsg"]').html(lang().product_js_images_deleted);
    }
    \$([]).selectcrop('init_images',data.images);
    \$(".select_crop").selectcrop('show');
  
    },
    error : function(jqXHR, textStatus, errorThrown) {
    \$('div[id="moveimagesmsg"]').html(lang().product_js_images_delete_error + ' - ' + textStatus);
    },
    complete: function(XMLHttpRequest, textStatus) {
  
    }
   });
  
  }
  
});


\$("#move_images").click({},function(event) {
  
  event.stopPropagation();
  event.preventDefault();
  
  
  if (! \$("#move_images").hasClass("disabled")) {
  
    \$("#delete_images").addClass("disabled");
    \$("#move_images").addClass("disabled");
  
   \$('div[id="moveimagesmsg"]').html('<img src="/images/misc/loading2.gif" /> ' + lang().product_js_moving_images);
   \$('div[id="moveimagesmsg"]').show();
  
    var imgids = '';
    var i = 0;
    \$( "#manage .ui-selected"  ).each(function() {
      var imgid = \$( this ).attr('id');
      imgid = imgid.replace("manage_","");
      imgids += imgid + ',';
      i++;
    });
    if (i) {
      // remove trailing comma
      imgids = imgids.substring(0, imgids.length - 1);
    }
  
   \$("#product_form").ajaxSubmit({
  
      url: "/cgi/product_image_move.pl",
      data: { code: code, move_to_override: \$("#move_to").val(), copy_data_override: \$("#copy_data").prop( "checked" ), imgids : imgids },
      dataType: 'json',
      beforeSubmit: function(a,f,o) {
      },
      success: function(data) {
    
      if (data.error) {
        \$('div[id="moveimagesmsg"]').html(lang().product_js_images_move_error + ' - ' + data.error);
      }
      else {
        \$('div[id="moveimagesmsg"]').html(lang().product_js_images_moved + ' &rarr; ' + data.link);
      }
      \$([]).selectcrop('init_images',data.images);
      \$(".select_crop").selectcrop('show');
    
      },
      error : function(jqXHR, textStatus, errorThrown) {
      \$('div[id="moveimagesmsg"]').html(lang().product_js_images_move_error + ' - ' + textStatus);
      },
      complete: function(XMLHttpRequest, textStatus) {
        \$("#move_images").addClass("disabled");
        \$("#move_images").addClass("disabled");
        \$( "#manage .ui-selected"  ).first().each(function() {
          \$("#move_images").removeClass("disabled");
          \$("#move_images").removeClass("disabled");
        });
      }
   });
  
  }
  
});

\$(document).foundation({
  tab: {
    callback : function (tab) {

\$('.tabs').each(function(i, obj) {
\$(this).removeClass('active');
});

      var id = tab[0].id;	 // e.g. tabs_front_image_en_tab
  var lc = id.replace(/.*(..)_tab/, "\$1");
  \$(".tabs_" + lc).addClass('active');

\$(document).foundation('tab', 'reflow');

    }
  }
});

\$('#no_nutrition_data').change(function() {
	if (\$(this).prop('checked')) {
		\$('#nutrition_data_table input').prop('disabled', true);
		\$('#nutrition_data_table select').prop('disabled', true);
		\$('#multiple_nutrition_data').prop('disabled', true);
		\$('#multiple_nutrition_data').prop('checked', false);
		\$('#nutrition_data_table input.nutriment_value').val('');
		\$('#nutrition_data_table').hide();
	} else {
		\$('#nutrition_data_table input').prop('disabled', false);
		\$('#nutrition_data_table select').prop('disabled', false);
		\$('#multiple_nutrition_data').prop('disabled', false);
		\$('#nutrition_data_table').show();
	}
	update_nutrition_image_copy();
	\$(document).foundation('equalizer', 'reflow');
});


\$('#$nutrition_data').change(function() {
	if (\$(this).prop('checked')) {
		\$('#$nutrition_data_instructions').show();
		\$('.$nutriment_col_class').show();
	} else {
		\$('#$nutrition_data_instructions').hide();
		\$('.$nutriment_col_class').hide();
		\$('.nutriment_value_$product_type_as_sold_or_prepared').val('');
	}
	update_nutrition_image_copy();
	\$(document).foundation('equalizer', 'reflow');
});

\$('input[name=$nutrition_data_per]').change(function() {
	if (\$('input[name=$nutrition_data_per]:checked').val() == '100g') {
		\$('#${nutrition_data}_100g').show();
		\$('#${nutrition_data}_serving').hide();
	} else {
		\$('#${nutrition_data}_100g').hide();
		\$('#${nutrition_data}_serving').show();
	}
	update_nutrition_image_copy();
	\$(document).foundation('equalizer', 'reflow');
});