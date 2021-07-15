
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