var ias;
var code;
var current_cropbox;
var images = [];
var imgids = {};
var img_path;
var angles = {};
var imagefield_imgid = {};
var imagefield_selection = {};
var imagefield_url = {};

function select_nutriment(event, ui) {


	//alert(ui.item.id + ' = ' + ui.item.value);
	//alert($("#add_nutriment").val());
	var id = $(this).attr('id');
	id = id.replace("_label", "");
	$('#' + id).focus();
	$('#' + id + '_unit').val(ui.item.unit);
}

function add_line(event, ui) {

	$(this).unbind("change");
	$(this).unbind("autocompletechange");

	var id = parseInt($("#new_max").val()) + 1;
	$("#new_max").val(id);

	var newline = $("#nutriment_new_0_tr").clone();
	var newid = "nutriment_new_" + id;
	newline.attr('id', newid + "_tr");
	newline.find(".nutriment_label").attr("id",newid + "_label").attr("name",newid + "_label");
	newline.find(".nutriment_unit").attr("id",newid + "_unit").attr("name",newid + "_unit");
	newline.find(".nutriment_value").attr("id",newid).attr("name",newid);

	$('#nutrition_data_table > tbody:last').append(newline);
	newline.show();
	
	newline.find(".nutriment_label").autocomplete({
		source: otherNutriments,
		select: select_nutriment,
		//change: add_line
	});	
	
	// newline.find(".nutriment_label").bind("autocompletechange", add_line);
	newline.find(".nutriment_label").change(add_line);
	
}

function upload_image (imagefield) {

 $('.img_input[name!="imgupload_' + imagefield + '"]').prop("disabled", true);
 $('.img_input[name="imgupload_' + imagefield + '"]').hide();
 $('div[id="uploadimagemsg_' + imagefield +'"]').html('<img src="/images/misc/loading2.gif" /> ' + Lang.uploading_image);
 $('div[id="uploadimagemsg_' + imagefield +'"]').show();

 $("#product_form").ajaxSubmit({

  url: "/cgi/product_image_upload.pl",
  data: { imagefield: imagefield },
  dataType: 'json',
  beforeSubmit: function(a,f,o) {
   //o.dataType = 'json';
  },
  success: function(data) {
	//alert(data.status);
	//alert("input:hidden[name=\"" + data.imagefield + ".imgid\"]");
	$('div[id="uploadimagemsg_' + imagefield +'"]').html(Lang.image_received);
	$("input:hidden[name=\"" + data.imagefield + ".imgid\"]").val(data.image.imgid);
	$([]).selectcrop('add_image',data.image);
	$(".select_crop").selectcrop('show');
	
	$('#' + imagefield + '_' + data.image.imgid).addClass("ui-selected").siblings().removeClass("ui-selected");
	change_image(imagefield, data.image.imgid);	
	
  },
  error : function(jqXHR, textStatus, errorThrown) {
	$('div[id="uploadimagemsg_' + imagefield +'"]').html(Lang.image_upload_error);
  },
  complete: function(XMLHttpRequest, textStatus) {
	$('.img_input').prop("disabled", false).show();
  }
 });
}

var x1,y1,x2,y2;

function init_image_area_select(imagefield) {

	if (ias) {
		ias.remove();
	}
	
	//$('div[id="cropbutton_' + imagefield +'"]').html('');
	//$('#crop_' + imagefield).html('');
	
	ias = $('img#crop_' + imagefield ).imgAreaSelect({
		parent: '#ias_' + imagefield,
		instance: true,
		handles: true,
		onSelectEnd: function (img, selection) {
			
			imagefield_selection[imagefield] = selection;
			
		}
	});


			


}

function update_image(imagefield) {

	$('#crop_' + imagefield).attr("src","/cgi/product_image_rotate.pl?code=" + code + "&imgid=" + imagefield_imgid[imagefield]
		+ "&angle=" + angles[imagefield] + "&normalize=" + $("#normalize_" + imagefield).attr('checked')
		+ "&white_magic=" + $("#white_magic_" + imagefield).attr('checked')		);
	$('div[id="cropbuttonmsg_' + imagefield +'"]').hide();
}

function rotate_image(event) {

	var imagefield = event.data.imagefield;
	var angle = event.data.angle;
	angles[imagefield] += angle;
	angles[imagefield] = (360 + angles[imagefield]) % 360;
	//$('#cropimgdiv_' + imagefield).rotate(angles[imagefield]);	
	
	//var transform = "rotate(" + angles[imagefield] + "deg)";
	//$('#cropimgdiv_' + imagefield).css("-moz-transform", transform);


		var selection = ias.getSelection();
		
		var w = $('#crop_' + imagefield).width();
		var h = $('#crop_' + imagefield).height();
		
		if (angle == 90) {
			x1 = h - selection.y2;
			y1 = selection.x1;
			x2 = h - selection.y1;
			y2 = selection.x2;
		}
		else {
			x1 = selection.y1;
			y1 = w - selection.x2;
			x2 = selection.y2;
			y2 = w - selection.x1;
		}



	//$('#ias_' + imagefield).html('');
	update_image(imagefield);
	
	//init_image_area_select(imagefield);

	ias.cancelSelection();
	ias.setOptions({ show: false });
	$('#crop_' + imagefield).attr("width",h);
	$('#crop_' + imagefield).attr("height",w);
	ias.update();
	ias.setOptions({ imageHeight : w, imageWidth : h });
	if ((selection.width > 0) && (selection.height > 0)) {		
		ias.setSelection(x1,y1,x2,y2);
		ias.update();
		ias.setOptions({ show: true });
	}

	ias.update();	
	
	selection = ias.getSelection();
	imagefield_selection[imagefield] = selection;
	
	event.stopPropagation();
	event.preventDefault();
}

function change_image(imagefield, imgid) {

	// alert("field: " + imagefield + " - imgid: " + imgid);
	
	var image = images[imgids[imgid]];
	angles[imagefield] = 0;
	imagefield_imgid[imagefield] = imgid;
	
	var html = '<div class="command">' + Lang.image_rotate_and_crop + '</div>';
	html += '<div class="small_buttons command"><a id="rotate_left_' + imagefield + '">' + Lang.image_rotate_left + '</a>';
	html += '<a id="rotate_right_' + imagefield + '">' + Lang.image_rotate_right + '</a>';
	html += '<input type="checkbox" id="normalize_' + imagefield + '" onchange="update_image(\'' + imagefield + '\');blur();" /><label for="normalize_' + imagefield + '">' + Lang.image_normalize + '</label></div>';
	html += '<div id="cropimgdiv_' + imagefield + '"><img src="' + img_path + image.crop_url +'" id="' + 'crop_' + imagefield + '"/></div>';
	html += '<a href="' + img_path + image.imgid + '.jpg" target="_blank">' + Lang.image_open_full_size_image + '</a><br/>';
	html +=	'<input type="checkbox" id="white_magic_' + imagefield + '" style="display:inline" /><label for="white_magic_' + imagefield 
		+ '" style="display:inline">' + Lang.image_white_magic + '</label>';
	html += '<div id="ias_' + imagefield + '"></div>';
	html += '<div id="cropbutton_' + imagefield + '" class="small_buttons"></div>';
	html += '<div id="cropbuttonmsg_' + imagefield + '" class="ui-state-highlight ui-corner-all" style="padding:2px;margin-top:10px;margin-bottom:10px;display:none" ></div>';
	
	if (ias) {
		ias.remove();
	}
	x1 = -1;
	if (current_cropbox) {
		$('div[id="' + current_cropbox + '"]').html('');
	}
	current_cropbox = 'cropbox_' + imagefield;
	$('div[id="cropbox_' + imagefield +'"]').html(html);
	
	$("#white_magic_" + imagefield).change(function(event) {
			$('div[id="cropbuttonmsg_' + imagefield +'"]').hide();
	} );
	
			var id = 'crop_' + imagefield + '_button';
			$('div[id="cropbutton_' + imagefield +'"]').html('<button id=' + id + '>' + Lang.image_save + '</button>');
			$("#" + id).button();
			$("#" + id).click({imagefield:imagefield,},function(event) {
				event.stopPropagation();
				event.preventDefault();
				var imgid = imagefield_imgid[imagefield];
				var selection = imagefield_selection[imagefield];
				if (! selection) {
					selection = {'x1':-1,'y1':-1,'x2':-1,'y2':-1};
				}
				// alert(event.data.imagefield);
				$("#" + id).blur();
				$('div[id="cropbutton_' + imagefield +'"]').hide();
				$('div[id="cropbuttonmsg_' + imagefield +'"]').html('<img src="/images/misc/loading2.gif" /> ' + Lang.image_saving);
				$('div[id="cropbuttonmsg_' + imagefield +'"]').show();
				$.post('/cgi/product_image_crop.pl',
						{code: code, id: imagefield , imgid: imgid,
						x1:selection.x1, y1:selection.y1, x2:selection.x2, y2:selection.y2,
						angle:angles[imagefield], normalize:$("#normalize_" + imagefield).attr('checked'), 
						white_magic:$("#white_magic_" + imagefield).attr('checked') }, function(data) {
						
					imagefield_url[imagefield] = data.image.display_url;
					update_display(imagefield);
					$('div[id="cropbutton_' + imagefield +'"]').show();
					$('div[id="cropbuttonmsg_' + imagefield +'"]').html(Lang.image_saved);
				}, 'json');
			});		
	
	$("#normalize_" + imagefield).button();
	$("#rotate_left_" + imagefield).button().click({imagefield:imagefield, angle:-90}, rotate_image);
	$("#rotate_right_" + imagefield).button().click({imagefield:imagefield, angle:90}, rotate_image);
	
	init_image_area_select(imagefield);
	
}  

function update_display(imagefield) {

	var display_url = imagefield_url[imagefield];
	
	if (display_url) {
	
	var html = Lang.current_image + '<br/><img src="' + img_path + display_url + '" />';
	if (imagefield == 'ingredients') {
		html += '<div id="ocrbuttondiv_' + imagefield + '" class="small_buttons"><button id="ocrbutton_' + imagefield + '">' + Lang.extract_ingredients + '</button>';
	}
	if (imagefield == 'nutrition') {
		// width big enough to display a copy next to nutrition table?
		if ($('#nutrition').width() - $('#nutrition_data_table').width() > 405) {
			$('#nutrition_image_copy').html('<img src="' + img_path + display_url + '" />').css("left", $('#nutrition_data_table').width() + 10);
		}
	}
	
	$('div[id="display_' + imagefield +'"]').html(html);
	$("#ocrbutton_" + imagefield).button();
	$("#ocrbutton_" + imagefield).click({imagefield:imagefield},function(event) {
		event.stopPropagation();
		event.preventDefault();
		// alert(event.data.imagefield);
		$('div[id="ocrbuttondiv_' + imagefield +'"]').html('<img src="/images/misc/loading2.gif" /> ' + Lang.extracting_ingredients);
		$.post('/cgi/ingredients.pl',
				{code: code, id: imagefield, process_image:1 }, function(data) {
				
			if (data.status == 0) {
				$('div[id="ocrbuttondiv_' + imagefield +'"]').html(Lang.extracted_ingredients_ok);
				$("#ingredients_text").val(data.ingredients_text_from_image);
			}
			else {
				$('div[id="ocrbuttondiv_' + imagefield +'"]').html(Lang.extracted_ingredients_nok);
			}
		}, 'json');
		
	});
	
	}
}


(function( $ ){

	var settings = {
		'thumb_width' : 100,
		'thumb_height' : 100
	};
	
	var methods = {
    init : function( options ) {
	
		// Create some defaults, extending them with any options that were provided
		settings = $.extend( settings, options);
		img_path = settings.img_path;		
		code = $("input:hidden[name=\"code\"]").val();
	
      return this.each(function(){
         
         var $this = $(this),
			data = $this.data('selectcrop')
			;
             //data = $this.data('tooltip'),
             //tooltip = $('<div />', {
             //  text : $this.attr('title')
             //});
         
         // If the plugin hasn't been initialized yet
         if ( ! data ) {
         
           /*
             Do more setup stuff here
           */

           $(this).data('selectcrop', {
			  init_id : $this.attr('id'),
              target : $this
           });
		   imagefield_url[$this.attr('id')] = $("#" + $this.attr('id') + '_display_url').val();

         }
       }); 
    },
	init_images : function ( images_data ) {
	
		images = images_data;		
		
		//$("#add_nutriment").change(add_nutriment);
	},
	add_image : function ( image_data) {
		images.push(image_data);
	},
    show : function( ) {
		
		this.each(function(){
         
			var $this = $(this),
				data = $this.data('selectcrop')
			;
			var id = $this.attr('id');			
			
			var html = '<ul class="ui-selectable single-selectable">';
			var imgid = '';
			
			$.each(images, function(index, image) {
				var selected = '';
				imgids[image.imgid] = index;
				if (($("input:hidden[name=\"" + id + ".imgid\"]").val()) == image.imgid) {
					selected = ' ui-selected';
					imgid = image.imgid;
				}
				html += '<li id="' + id + '_' + image.imgid + '" class="ui-state-default ui-selectee' + selected + '">';
				html += '<img src="' + settings.img_path + image.thumb_url +'" /></li>';
			});
			html += '</ul>';			
			
			html += '<div style="clear:both" class="command upload_image_div small_buttons">';
			html += '<span class="btn btn-success fileinput-button" id="imgsearchbutton_' + id + '">'
+ '<span>' + Lang.upload_image + '</span>'
+ '<input type="file" accept="image/*" class="img_input" name="imgupload_' + id + '" id="imgupload_' + id + '" data-url="/cgi/product_image_upload.pl" multiple/>'
+ '</span></div><br />'
+ '<p class="note">' + Lang.upload_image_note + '</p>'
+ '<div id="progressbar_' + id + '" class="progress" style="display:none;height:12px;"></div>'
+ '<div id="imgsearchmsg_' + id + '" class="ui-state-highlight ui-corner-all" style="display:none;margin-top:5px;">' + Lang.uploading_image + '</div>'
+ '<div id="imgsearcherror_' + id + '" class="ui-state-error ui-corner-all" style="display:none;margin-top:5px;">' + Lang.image_upload_error + '</div>';
			

		//	html += '<div id="uploadimagemsg_' + id + '" class="ui-state-highlight ui-corner-all" style="clear:both;padding:2px;margin-top:10px;margin-bottom:10px;display:none" ></div>';
			html += '<div class="cropbox" id="cropbox_' + id +'"></div>';
			html += '<div class="display" id="display_' + id +'"></div>';
			$this.html(html);			
			update_display(id);
			
			

	var imagefield = id;
		
   $('#imgupload_' + id).fileupload({
        dataType: 'json',
        url: '/cgi/product_image_upload.pl',
		formData : [{name: 'jqueryfileupload', value: 1}, {name: 'imagefield', value: imagefield}, {name: 'code', value: code} ],
		resizeMaxWidth : 2000,
		resizeMaxHeight : 2000,
		
		
        done: function (e, data) {

			if (data.result) {
			if (data.result.image) {
	$("#imgsearchmsg_" + imagefield).html('Image reçue');
	$("input:hidden[name=\"" + data.imagefield + ".imgid\"]").val(data.result.image.imgid);
	$([]).selectcrop('add_image',data.result.image);
	$(".select_crop").selectcrop('show');
	
	$('#' + imagefield + '_' + data.result.image.imgid).addClass("ui-selected").siblings().removeClass("ui-selected");
	change_image(imagefield, data.result.image.imgid);			
			}
		
			if (data.result.error) {
				$("#imgsearcherror_" + imagefield).html(data.result.error);
				$("#imgsearcherror_" + imagefield).show();
			}
			}
        },
		fail : function (e, data) {
			$("#imgsearcherror_" + imagefield).show();
        },
		always : function (e, data) {
			$("#progressbar_" + imagefield).hide();
			$("#imgsearchbutton_" + imagefield).show();
			$("#imgsearchmsg_" + imagefield).hide();
			$('.img_input').prop("disabled", false);			
        },
		start: function (e, data) {
			$("#imgsearchbutton_" + imagefield).hide();
			$("#imgsearcherror_" + imagefield).hide();
			$("#imgsearchmsg_" + imagefield).html('<img src="/images/misc/loading2.gif" /> Image en cours d\'envoi').show();
			$("#progressbar_" + imagefield).progressbar({value : 0 }).show();
			
			$('.img_input[name!="imgupload_' + imagefield + '"]').prop("disabled", true);
                    
		},
            sent: function (e, data) {
                if (data.dataType &&
                        data.dataType.substr(0, 6) === 'iframe') {
                    // Iframe Transport does not support progress events.
                    // In lack of an indeterminate progress bar, we set
                    // the progress to 100%, showing the full animated bar:
                    $("#progressbar_" + imagefield).progressbar(
                            'option',
                            'value',
                            100
                        );
                }
            },
            progress: function (e, data) {

                    $("#progressbar_" + imagefield).progressbar(
                        'option',
                        'value',
                        parseInt(data.loaded / data.total * 100, 10)
                    );
                
            }
		
    });			
			
		});
		
		$('.fileinput-button').each(function () {
                    var input = $(this).find('input:file').detach();
                    $(this)
                        .button()
                        .append(input);
                });

		
		
		
		
		$(".single-selectable li").click(function() {
			var li_id = $(this).attr("id");
			var imagefield_imgid = li_id.split("_");
			var imagefield = imagefield_imgid[0];
			var imgid = imagefield_imgid[1];
			$("input:hidden[name=\"" + imagefield + ".imgid\"]").val(imgid);
			$(this).addClass("ui-selected").siblings().removeClass("ui-selected");
			change_image(imagefield, imgid);
		});
		
		return this;
    },
    change_crop : function( x1, y1, x2, y2 ) { 
      // !!! 
    }	

  };


  $.fn.selectcrop = function( method ) {
    
    // Method calling logic
    if ( methods[method] ) {
      return methods[ method ].apply( this, Array.prototype.slice.call( arguments, 1 ));
    } else if ( typeof method === 'object' || ! method ) {
      return methods.init.apply( this, arguments );
    } else {
      $.error( 'Method ' +  method + ' does not exist on jQuery.selectcrop' );
    }    
  
  };

})( jQuery );