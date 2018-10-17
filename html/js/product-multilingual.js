// This file is part of Product Opener.
// 
// Product Opener
// Copyright (C) 2011-2018 Association Open Food Facts
// Contact: contact@openfoodfacts.org
// Address: 21 rue des Iles, 94100 Saint-Maur des Fossés, France
// 
// Product Opener is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
// 
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
// 
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

/*eslint no-console: "off"*/
/*global Lang admin otherNutriments*/
/*global toggle_manage_images_buttons ocr_button_div_original_html*/ // These are weird.
/*exported add_language_tab add_line upload_image update_image update_nutrition_image_copy*/

var code;
var current_cropbox;
var images = [];
var imgids = {};
var img_path;
var angles = {};
var imagefield_imgid = {};
var imagefield_url = {};

var units = [
	[ 'g', 'mg', "\u00B5g", '% DV' ],
	[ 'mol/l', 'moll/l', 'mmol/l', 'mval/l', 'ppm', "\u00B0rH", "\u00B0fH", "\u00B0e", "\u00B0dH", 'gpg' ],
	[ 'kJ', 'kcal' ],
];

function stringStartsWith (string, prefix) {
    return string.slice(0, prefix.length) == prefix;
}

function add_language_tab (lc, language) {
	
$('.tabs').each(function() {
	$(this).removeClass('active');
});
	
$('.new_lc').each(function() {

	var $clone = $(this).clone();
	
	var $th = $clone;
	var newID = $th.attr('id').replace(/new_lc/, lc);
	$th.attr('id', newID);
	
	$clone.addClass('tabs_' + lc).removeClass('tabs_new_lc');
		
	$clone.find('[id]').each(function() { 

		var $th = $(this);
		var newID = $th.attr('id').replace(/new_lc/, lc);
		$th.attr('id', newID);
		
	});	
	
	$clone.find('[for]').each(function() { 

		var $th = $(this);
		var newID = $th.attr('for').replace(/new_lc/, lc);
		$th.attr('for', newID);
		
	});		
	
	$clone.find('[name]').each(function() { 

		var $th = $(this);
		var newID = $th.attr('name').replace(/new_lc/, lc);
		$th.attr('name', newID);
	});
	
	$clone.find('[href]').each(function() { 

		var $th = $(this);
		var newID = $th.attr('href').replace(/new_lc/, lc);
		$th.attr('href', newID);
	});

	$clone.find('[lang]').each(function() {

		var $th = $(this);
		var newID = $th.attr('lang').replace(/new_lc/, lc);
		$th.attr('lang', newID);
	});
	
	$clone.find('.tab_language').each(function() { 

		$(this).html(language);
	});	
	
	$clone.insertBefore($(this));
	
	$clone.addClass('active').removeClass('new_lc').removeClass('hide');

	$(".select_crop").filter(":visible").selectcrop('init');
	$(".select_crop").filter(":visible").selectcrop('show');
	
});



$(document).foundation('tab', 'reflow');
}

function select_nutriment(ui) {


	//alert(ui.item.id + ' = ' + ui.item.value);
	//alert($("#add_nutriment").val());
	var id = $(this).attr('id');
	id = id.replace("_label", "");
	$('#' + id).focus();
	$('#' + id + '_unit').val(ui.item.unit);
	var unit = (ui.item.unit == '%' ? '%' : ui.item.unit).toLowerCase();
	var unitElement = $('#' + id + '_unit');
	var percentElement = $('#' + id + '_unit_percent');
	if (unit === '') {
		unitElement.hide();
		percentElement.hide();
	}
	else if (unit == '%') {
		unitElement.hide();
		percentElement.show();
	}
	else {
		unitElement.show();
		percentElement.hide();

		for (var entryIndex = 0; entryIndex < units.length; ++entryIndex) {
			var entry = units[entryIndex];
			for (var unitIndex = 0; unitIndex < entry.length; ++unitIndex) {
				var unitEntry = entry[unitIndex].toLowerCase();
				if (unitEntry == unit) {
					var domElement = unitElement[0];
					domElement.options.length = 0; // Remove current entries.
					for (var itemIndex = 0; itemIndex < entry.length; ++itemIndex) {
						var unitValue = entry[itemIndex];
						domElement.options[domElement.options.length] = new Option(unitValue, unitValue, false, unitValue.toLowerCase() == unit);
					}

					if (ui.item.iu) {
						domElement.options[domElement.options.length] = new Option('IU', 'IU', false, 'iu' == unit);
					}

					return;
				}
			}
		}
	}
}

function add_line() {

	$(this).unbind("change");
	$(this).unbind("autocompletechange");

	var id = parseInt($("#new_max").val()) + 1;
	$("#new_max").val(id);

	var newline = $("#nutriment_new_0_tr").clone();
	var newid = "nutriment_new_" + id;
	newline.attr('id', newid + "_tr");
	newline.find(".nutriment_label").attr("id",newid + "_label").attr("name",newid + "_label");
	newline.find(".nutriment_unit").attr("id",newid + "_unit").attr("name",newid + "_unit");
	newline.find(".nutriment_unit_percent").attr("id",newid + "_unit_percent").attr("name",newid + "_unit_percent");
	newline.find("#nutriment_new_0").attr("id",newid).attr("name",newid);
	newline.find("#nutriment_new_0_prepared").attr("id",newid + "_prepared").attr("name",newid + "_prepared");

	$('#nutrition_data_table > tbody:last').append(newline);
	newline.show();
	
	newline.find(".nutriment_label").autocomplete({
		source: otherNutriments,
		select: select_nutriment,
		//change: add_line
	});	
	
	// newline.find(".nutriment_label").bind("autocompletechange", add_line);
	newline.find(".nutriment_label").change(add_line);
	
	$(document).foundation('equalizer', 'reflow');
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
  beforeSubmit: function() {
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
  error : function() {
	$('div[id="uploadimagemsg_' + imagefield +'"]').html(Lang.image_upload_error);
  },
  complete: function() {
	$('.img_input').prop("disabled", false).show();
  }
 });
}


function init_image_area_select(imagefield) {
	
	$('img#crop_' + imagefield ).cropper({ "strict" : false, "guides" : false, "autoCrop" : false, "zoomable" : false, "mouseWheelZoom" : false, "touchDragZoom" : false, "toggleDragModeOnDblclick" : false, built: function () {
		$('img#crop_' + imagefield ).cropper('setDragMode', "crop");
	}});

}

function update_image(imagefield) {

	$('#crop_' + imagefield).attr("src","/cgi/product_image_rotate.pl?code=" + code + "&imgid=" + imagefield_imgid[imagefield]
		+ "&angle=" + angles[imagefield] + "&normalize=" + $("#normalize_" + imagefield).prop('checked')
		+ "&white_magic=" + $("#white_magic_" + imagefield).prop('checked')		);
	$('div[id="cropbuttonmsg_' + imagefield +'"]').hide();
}

function rotate_image(event) {

	var imagefield = event.data.imagefield;
	var angle = event.data.angle;
	angles[imagefield] += angle;
	angles[imagefield] = (360 + angles[imagefield]) % 360;

	$('img#crop_' + imagefield ).cropper('rotate',angle);
	
	//var selection = $('img#crop_' + imagefield ).cropper('getData'); 
	var selection = $('img#crop_' + imagefield ).cropper('getCropBoxData'); 
	
	selection.x = selection.left;
	selection.y = selection.top;
	
	console.log("selection - current - x:" + selection.x + " - y:" + selection.y + " - width:" + selection.width + " - height:" + selection.height);
	
	if (selection.width > 0) {
		var x1 = selection.x;
		var y1 = selection.y;
		var x2 = selection.x + selection.width;
		var y2 = selection.y + selection.height;

		var container = $('img#crop_' + imagefield ).cropper('getContainerData');
		var w = container.width;
		var h = container.height;
		console.log("selection - image - w:" + w + ' - h:' + h);
		

		if (angle == 90) {
			selection.x = h - y2;
			selection.y = x1;
			selection.width = y2 - y1;
			selection.height = x2 - x1;
		}
		else {
			selection.x = y1;
			selection.y = w - x2;
			selection.width = y2 - y1;
			selection.height = x2 - x1;
		}
		
		selection.left = selection.x;
		selection.top = selection.y;
		
		$('img#crop_' + imagefield ).cropper('setCropBoxData', selection);
		
		console.log("selection - new - x:" + selection.x + " - y:" + selection.y + " - width:" + selection.width + " - height:" + selection.height);	
	}

	
	event.stopPropagation();
	event.preventDefault();
}

function change_image(imagefield, imgid) {

	//alert("field: " + imagefield + " - imgid: " + imgid);
	
	var image = images[imgids[imgid]];
	angles[imagefield] = 0;
	imagefield_imgid[imagefield] = imgid;
	
	var html = '<div class="command">' + Lang.image_rotate_and_crop + '</div>';
	html += '<div class="command"><a id="rotate_left_' + imagefield + '" class="small button" type="button">' + Lang.image_rotate_left + '</a> &nbsp;';
	html += '<a id="rotate_right_' + imagefield + '" class="small button" type="button">' + Lang.image_rotate_right + '</a>';
	html += '</div>';
	html += '<div id="cropimgdiv_' + imagefield + '" style="width:100%;height:400px"><img src="' + img_path + image.crop_url +'" id="' + 'crop_' + imagefield + '"/></div>';
	html += '<a href="' + img_path + image.imgid + '.jpg" target="_blank">' + Lang.image_open_full_size_image + '</a><br/>';
	html += '<input type="checkbox" id="normalize_' + imagefield + '" onchange="update_image(\'' + imagefield + '\');blur();" /><label for="normalize_' + imagefield + '">' + Lang.image_normalize + '</label></div><br/>';	
	html +=	'<input type="checkbox" id="white_magic_' + imagefield + '" style="display:inline" /><label for="white_magic_' + imagefield 
		+ '" style="display:inline">' + Lang.image_white_magic + '</label>';
	html += '<div id="cropbutton_' + imagefield + '"></div>';
	html += '<div id="cropbuttonmsg_' + imagefield + '" class="ui-state-highlight ui-corner-all" style="padding:2px;margin-top:10px;margin-bottom:10px;display:none" ></div>';
	

	if (current_cropbox) {
		$('div[id="' + current_cropbox + '"]').html('');
	}
	current_cropbox = 'cropbox_' + imagefield;
	$('div[id="cropbox_' + imagefield +'"]').html(html);
	$('div[id="cropimgdiv_' + imagefield +'"]').height($('div[id="cropimgdiv_' + imagefield +'"]').width());
	
	$("#white_magic_" + imagefield).change(function() {
			$('div[id="cropbuttonmsg_' + imagefield +'"]').hide();
	} );
	
			var id = 'crop_' + imagefield + '_button';
			$('div[id="cropbutton_' + imagefield +'"]').html('<button id="' + id + '" class="small button" type="button">' + Lang.image_save + '</button>');
			$("#" + id).click({imagefield:imagefield},function(event) {
				event.stopPropagation();
				event.preventDefault();
				var imgid = imagefield_imgid[imagefield];
				
				var selection = $('img#crop_' + imagefield ).cropper('getData');

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
						x1:selection.x, y1:selection.y, x2:selection.x + selection.width, y2:selection.y + selection.height,
						angle:angles[imagefield], normalize:$("#normalize_" + imagefield).prop('checked'), 
						white_magic:$("#white_magic_" + imagefield).prop('checked') }, function(data) {
						
					imagefield_url[imagefield] = data.image.display_url;
					update_display(imagefield, false);
					$('div[id="cropbutton_' + imagefield +'"]').show();
					$('div[id="cropbuttonmsg_' + imagefield +'"]').html(Lang.image_saved);
					$(document).foundation('equalizer', 'reflow');
				}, 'json');
			});		
	
	$("#rotate_left_" + imagefield).click({imagefield:imagefield, angle:-90}, rotate_image);
	$("#rotate_right_" + imagefield).click({imagefield:imagefield, angle:90}, rotate_image);
	
	init_image_area_select(imagefield);
	
	$(document).foundation('equalizer', 'reflow');
}  



function update_nutrition_image_copy() {
	
	// width big enough to display a copy next to nutrition table?
	if ($('#nutrition').width() - $('#nutrition_data_table').width() > 405) {
	
		$('#nutrition_image_copy').css("left", $('#nutrition_data_table').width() + 10).show();
	}	
	else {
		$('#nutrition_image_copy').hide();
	}
}


function update_display(imagefield, first_display) {

	var display_url = imagefield_url[imagefield];
	
	if (display_url) {
	
	var html = Lang.current_image + '<br/><img src="' + img_path + display_url + '" />';
	html += '<div class="button_div" id="unselectbuttondiv_' + imagefield + '"><button id="unselectbutton_' + imagefield + '" class="small button" type="button">' + Lang.unselect_image + '</button></div>';
	if (stringStartsWith(imagefield, 'ingredients')) {
		html += '<div id="ocrbutton_loading_' + imagefield + '"></div><div class="button_div" id="ocrbuttondiv_' + imagefield + '"><button id="ocrbutton_' + imagefield + '" class="small button" type="button">' + Lang.extract_ingredients + '</button>'
		+ ' <button id="ocrbuttongooglecloudvision_' + imagefield + '" class="small button" type="button">' + 'Cloud Vision' + '</button></div>';
	}
	
	if (stringStartsWith(imagefield, 'nutrition')) {
		// width big enough to display a copy next to nutrition table?
		if ($('#nutrition').width() - $('#nutrition_data_table').width() > 405) {
		
			if ((! first_display) || ($('#nutrition_image_copy').html() === '')) {		
				$('#nutrition_image_copy').html('<img src="' + img_path + display_url + '" />').css("left", $('#nutrition_data_table').width() + 10);
			}
		}	
	}
	
	$('div[id="display_' + imagefield +'"]').html(html);
		
	$("#ocrbutton_" + imagefield).click({imagefield:imagefield},function(event) {
		event.stopPropagation();
		event.preventDefault();
		// alert(event.data.imagefield);
		
		$('div[id="ocrbutton_loading_' + imagefield +'"]').html('<img src="/images/misc/loading2.gif" /> ' + Lang.extracting_ingredients).show();
		$('div[id="ocrbuttondiv_' + imagefield +'"]').hide();
		$.post('/cgi/ingredients.pl',
				{code: code, id: imagefield, process_image:1, ocr_engine:"tesseract" }, function(data) {
				
			$('div[id="ocrbuttondiv_' + imagefield +'"]').show();
			if (data.status === 0) {
				$('div[id="ocrbutton_loading_' + imagefield +'"]').html(Lang.extracted_ingredients_ok);

				var ingredients_text_id = imagefield.replace("ingredients","ingredients_text");
				$("#" + ingredients_text_id).val(data.ingredients_text_from_image);
			}
			else {
				$('div[id="ocrbutton_loading_' + imagefield +'"]').html(ocr_button_div_original_html + Lang.extracted_ingredients_nok);
			}
			$(document).foundation('equalizer', 'reflow');
		}, 'json');
		
		$(document).foundation('equalizer', 'reflow');
		
	});
	$("#ocrbuttongooglecloudvision_" + imagefield).click({imagefield:imagefield},function(event) {
		event.stopPropagation();
		event.preventDefault();
		// alert(event.data.imagefield);
		$('div[id="ocrbutton_loading_' + imagefield +'"]').html('<img src="/images/misc/loading2.gif" /> ' + Lang.extracting_ingredients).show();
		$('div[id="ocrbuttondiv_' + imagefield +'"]').hide();
		$.post('/cgi/ingredients.pl',
				{code: code, id: imagefield, process_image:1, ocr_engine:"google_cloud_vision" }, function(data) {
				
			$('div[id="ocrbuttondiv_' + imagefield +'"]').show();
			if (data.status === 0) {
				$('div[id="ocrbutton_loading_' + imagefield +'"]').html(Lang.extracted_ingredients_ok);
				var ingredients_text_id = imagefield.replace("ingredients","ingredients_text");
				$("#" + ingredients_text_id).val(data.ingredients_text_from_image);
			}
			else {
				$('div[id="ocrbutton_loading_' + imagefield +'"]').html(Lang.extracted_ingredients_nok);
			}
			$(document).foundation('equalizer', 'reflow');
		}, 'json');
		
		$(document).foundation('equalizer', 'reflow');
		
	});	
	
	
	$("#unselectbutton_" + imagefield).click({imagefield:imagefield},function(event) {
		event.stopPropagation();
		event.preventDefault();
		// alert(event.data.imagefield);
		$('div[id="unselectbuttondiv_' + imagefield +'"]').html('<img src="/images/misc/loading2.gif" /> ' + Lang.unselecting_image);
		$.post('/cgi/product_image_unselect.pl',
				{code: code, id: imagefield }, function(data) {
				
			if (data.status_code === 0) {
				$('div[id="unselectbuttondiv_' + imagefield +'"]').html(Lang.unselected_image_ok);
				delete imagefield_url[imagefield];
			}
			else {
				$('div[id="unselectbuttondiv_' + imagefield +'"]').html(Lang.unselected_image_nok);
			}
			update_display(imagefield, false);
			$('div[id="display_' + imagefield +'"]').html('');
			$(document).foundation('equalizer', 'reflow');
		}, 'json');
		
		$(document).foundation('equalizer', 'reflow');
		
	});	
	
	}
	
	$(document).foundation('equalizer', 'reflow');
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
         
			var $this = $(this);
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
				html += '<li id="' + id + '_' + imgid + '" class="ui-state-default ui-selectee' + selected + '">';
				html += '<img src="' + settings.img_path + image.thumb_url +'" title="'  + image.uploaded + ' - ' + image.uploader + '"/>';
				
				if ((stringStartsWith(id, 'manage')) && (admin)) {
					html += '<div class="show_for_manage_images">' + image.uploaded + '<br/>' + image.uploader + '</div>';
				}
				
				html += '</li>';
			});
			html += '</ul>';					
						
			if (! stringStartsWith(id, 'manage')) {
			
			html += '<div style="clear:both" class="command upload_image_div">';
			html += '<a href="#" class="button small expand" id="imgsearchbutton_' + id + '"><i class="fi-camera"></i> ' + Lang.upload_image
+ '<input type="file" accept="image/*" capture="camera" class="img_input" name="imgupload_' + id + '" id="imgupload_' + id
+ '" data-url="/cgi/product_image_upload.pl" multiple '
+ 'style="position: absolute;right:0;bottom:0;top:0;cursor:pointer;opacity:0;font-size:40px;"/>' 
+ '</a>'
+ '</div>'
+ '<p class="note">' + Lang.upload_image_note + '</p>'
+ '<div id="progressbar_' + id + '" class="progress" style="display:none">'
+  '<span id="progressmeter_' + id + '" class="meter" style="width:0%"></span>'
+ '</div>'
+ '<div id="imgsearchmsg_' + id + '" data-alert class="alert-box info" style="display:none">' + Lang.uploading_image
+ '<a href="#" class="close">&times;</a>'
+ '</div>'
+ '<div id="imgsearcherror_' + id + '" data-alert class="alert-box alert" style="display:none">' + Lang.image_upload_error
+ '<a href="#" class="close">&times;</a>'
+ '</div>';
			

			html += '<div class="cropbox" id="cropbox_' + id +'"></div>';
			html += '<div class="display" id="display_' + id +'"></div>';
			
			
			}
			
			$this.html(html);

			if (! stringStartsWith(id, 'manage')) {
			
			update_display(id, true);
			


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
	$("#imgsearchmsg_" + imagefield).html(Lang.image_received);
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
		fail : function () {
			$("#imgsearcherror_" + imagefield).show();
        },
		always : function () {
			$("#progressbar_" + imagefield).hide();
			$("#imgsearchbutton_" + imagefield).show();
			$("#imgsearchmsg_" + imagefield).hide();
			$('.img_input').prop("disabled", false);			
        },
		start: function () {
			$("#imgsearchbutton_" + imagefield).hide();
			$("#imgsearcherror_" + imagefield).hide();
			$("#imgsearchmsg_" + imagefield).html('<img src="/images/misc/loading2.gif" /> ' + Lang.uploading_image).show();			
			$("#progressbar_" + imagefield).show();
			$("#progressmeter_" + imagefield).css('width', "0%");
			
			$('.img_input[name!="imgupload_' + imagefield + '"]').prop("disabled", true);
                    
		},
            sent: function (e, data) {
                if (data.dataType &&
                        data.dataType.substr(0, 6) === 'iframe') {
                    // Iframe Transport does not support progress events.
                    // In lack of an indeterminate progress bar, we set
                    // the progress to 100%, showing the full animated bar:
                    $("#progressmeter_" + imagefield).css('width', "100%");
                }
            },
            progress: function (e, data) {
				$("#progressmeter_" + imagefield).css('width', parseInt(data.loaded / data.total * 100, 10) + "%");
            }
		
    });			
			
		}
			
		});
		
		
		
		
		$(".single-selectable li").click(function() {
			var li_id = $(this).attr("id");
			var imagefield_imgid = li_id.split("_");
			var imagefield = imagefield_imgid[0] + "_" + imagefield_imgid[1];
			var imgid = imagefield_imgid[2];
			$("input:hidden[name=\"" + imagefield + ".imgid\"]").val(imgid);
			if ((stringStartsWith(imagefield, 'manage')) && ($("#manage_images_drop").hasClass("active"))) {
				$(this).toggleClass("ui-selected");
			}
			else {
				$(this).addClass("ui-selected").siblings().removeClass("ui-selected");
			}
			if (stringStartsWith(imagefield, 'manage')) {
				toggle_manage_images_buttons();
			} 
			else {
				change_image(imagefield, imgid);
			}
		});
		
		$(document).foundation('equalizer', 'reflow');
		
		return this;
    },

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
