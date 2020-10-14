// This file is part of Product Opener.
//
// Product Opener
// Copyright (C) 2011-2020 Association Open Food Facts
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
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

/*eslint dot-location: ["error", "property"]*/
/*eslint no-console: "off"*/
/*global lang admin otherNutriments Tagify*/
/*global toggle_manage_images_buttons */ // These are weird.
/*exported add_line upload_image update_image update_nutrition_image_copy*/

//Polyfill, just in case
if (!Array.isArray) {
  Array.isArray = function (arg) {
    return Object.prototype.toString.call(arg) === '[object Array]';
  };
}

var code;
var current_cropbox;
var images = [];
var imgids = {};
var img_path;
var angles = {};
var imagefield_imgid = {};
var imagefield_url = {};
var use_low_res_images = false;

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

    var $newTh = $clone;
    var newLcID = $newTh.attr('id').replace(/new_lc/, lc);
    $newTh.attr('id', newLcID);

    $clone.attr('data-language', lc);

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

  update_move_data_and_images_to_main_language_message();

  $(document).foundation('tab', 'reflow');
}

function select_nutriment(event,ui) {


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

	var id = parseInt($("#new_max").val(), 10) + 1;
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


		if (angle === 90) {
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

  // load small 400 pixels image if the use_low_res_images checkbox is checked

  var image_size = '';
  var cropimgdiv_style = '';
  var coordinates_image_size = "full";

  if ( $("#use_low_res_images_" + imagefield).is(':checked')) {
      image_size = '.400';
      cropimgdiv_style = 'style="max-width:400px"';
      coordinates_image_size = "400";
  }

	var html = '';

  html += '<div class="command">' + lang().product_js_image_rotate_and_crop + '</div>';

  html += '<div class="row"><div class="small-6 medium-7 large-8 columns">';
	html += '<div class="command"><a id="rotate_left_' + imagefield + '" class="small button" type="button">' + lang().product_js_image_rotate_left + '</a> &nbsp;';
	html += '<a id="rotate_right_' + imagefield + '" class="small button" type="button">' + lang().product_js_image_rotate_right + '</a>';
	html += '<br><a href="' + img_path + image.imgid + '.jpg" target="_blank">' + lang().product_js_image_open_full_size_image + '</a>';
  html += '<br/><input type="checkbox" id="zoom_on_wheel_' + imagefield +'" name="zoom_on_wheel_' + imagefield +'" value="">';
  html += '<label for="zoom_on_wheel_' + imagefield +'" style="margin-top:0px;">' + lang().product_js_zoom_on_wheel + '</label>';
	html += '</div>';
  html += '</div><div class="small-6 medium-5 large-4 columns" style="float:right">';

	html += '<div class="cropbutton_' + imagefield + '"></div>';
	html += '<div class="cropbuttonmsg_' + imagefield + '" class="ui-state-highlight ui-corner-all" style="padding:2px;margin-top:10px;margin-bottom:10px;display:none" ></div>';
  html += '</div></div>';
	html += '<div id="cropimgdiv_' + imagefield + '" class="cropimgdiv" ' + cropimgdiv_style + '><img src="' + img_path + image.imgid + image_size +'.jpg" id="' + 'crop_' + imagefield + '"/></div>';

  html += '<div class="row"><div class="small-6 medium-7 large-8 columns">';
	html += '<input type="checkbox" id="normalize_' + imagefield + '" onchange="update_image(\'' + imagefield + '\');blur();" /><label for="normalize_' + imagefield + '">' + lang().product_js_image_normalize + '</label><br/>';
	html +=	'<input type="checkbox" id="white_magic_' + imagefield + '" style="display:inline" /><label for="white_magic_' + imagefield
		+ '" style="display:inline">' + lang().product_js_image_white_magic + '</label>';
  html += '</div><div class="small-6 medium-5 large-4 columns" style="float:right;padding-top:1rem">';
	html += '<div class="cropbutton_' + imagefield + '"></div>';
	html += '<div class="cropbuttonmsg_' + imagefield + '" class="ui-state-highlight ui-corner-all" style="padding:2px;margin-top:10px;margin-bottom:10px;display:none" ></div>';
  html += '</div></div>';

	if (current_cropbox) {
		$('div[id="' + current_cropbox + '"]').html('');
	}
	current_cropbox = 'cropbox_' + imagefield;
	$('div[id="cropbox_' + imagefield +'"]').html(html);
	$('div[id="cropimgdiv_' + imagefield +'"]').height($('div[id="cropimgdiv_' + imagefield +'"]').width());

	$("#white_magic_" + imagefield).change(function() {
			$('.cropbuttonmsg_' + imagefield).hide();
	} );

  var crop_button = 'crop_' + imagefield + '_button';
  $('.cropbutton_' + imagefield).html('<button class="' + crop_button + ' small button" type="button">' + lang().product_js_image_save + '</button>');
  $("." + crop_button).click({imagefield:imagefield},function(event) {
    event.stopPropagation();
    event.preventDefault();

    var selection = $('img#crop_' + imagefield ).cropper('getData');

    if (! selection) {
      selection = {'x1':-1,'y1':-1,'x2':-1,'y2':-1};
    }
    // alert(event.data.imagefield);
    $("." + crop_button).blur();
    $('.cropbutton_' + imagefield).hide();
    $('.cropbuttonmsg_' + imagefield).html('<img src="/images/misc/loading2.gif" /> ' + lang().product_js_image_saving);
    $('.cropbuttonmsg_' + imagefield).show();
    $.post(
      '/cgi/product_image_crop.pl',
      {
        code: code, id: imagefield, imgid: imagefield_imgid[imagefield],
        x1:selection.x, y1:selection.y, x2:selection.x + selection.width, y2:selection.y + selection.height,
        coordinates_image_size : coordinates_image_size,
        angle:angles[imagefield], normalize:$("#normalize_" + imagefield).prop('checked'),
        white_magic: $("#white_magic_" + imagefield).prop('checked')
      },
      null,
      'json'
    )
      .done(function(data) {
        imagefield_url[imagefield] = data.image.display_url;
        update_display(imagefield, false);
        $('.cropbuttonmsg_' + imagefield).html(lang().product_js_image_saved);
      })
      .fail(function() {
        $('.cropbuttonmsg_' + imagefield).html(lang().not_saved);
      })
      .always(function() {
        $('.cropbutton_' + imagefield).show();
        $(document).foundation('equalizer', 'reflow');
      });
  });

  $('img#crop_' + imagefield).on('ready', function () {
    $("#rotate_left_" + imagefield).attr("disabled", false);
    $("#rotate_right_" + imagefield).attr("disabled", false);
    $("." + crop_button).attr("disabled", false);
  });
  $("#rotate_left_" + imagefield).attr("disabled", true);
  $("#rotate_right_" + imagefield).attr("disabled", true);
  $("." + crop_button).attr("disabled", true);

	$("#rotate_left_" + imagefield).click({imagefield:imagefield, angle:-90}, rotate_image);
	$("#rotate_right_" + imagefield).click({imagefield:imagefield, angle:90}, rotate_image);

  $('img#crop_' + imagefield).click(function() {
    $('img#crop_' + imagefield ).cropper('clear');
  });

	$('img#crop_' + imagefield).cropper({
		"viewMode" : 2, "guides": false, "autoCrop": false, "zoomable": true, "zoomOnWheel": false, "zoomOnTouch": false, "toggleDragModeOnDblclick": true, "checkCrossOrigin" : false
	});

	$("#zoom_on_wheel_" + imagefield).change(function() {
    var zoomOnWheel = $("#zoom_on_wheel_" + imagefield).is(':checked');
    $('img#crop_' + imagefield).cropper('destroy').cropper({
      "viewMode" : 2, "guides": false, "autoCrop": false, "zoomable": true, "zoomOnWheel": zoomOnWheel, "zoomOnTouch": false, "toggleDragModeOnDblclick": true, "checkCrossOrigin": false
	});	} );

	$(document).foundation('equalizer', 'reflow');
}

// https://jsperf.com/jquery-visibility-test
$.fn.isVisible = function() {
  return $.expr.filters.visible(this[0]);
};
function update_nutrition_image_copy() {

	// width big enough to display a copy next to nutrition table?
  if ($("#nutrition_data_table").isVisible() && $('#nutrition').width() - $('#nutrition_data_table').width() > 405) {
    $('#nutrition_image_copy').css("left", $('#nutrition_data_table').width() + 10).show();
	}
	else {
		$('#nutrition_image_copy').hide();
	}
}


function update_display(imagefield, first_display) {

	var display_url = imagefield_url[imagefield];

	if (display_url) {
		
		var imagetype = imagefield.replace(/_\w\w$/, '');

		var html = lang().product_js_current_image + '<br/><img src="' + img_path + display_url + '" />';
		html += '<div class="button_div" id="unselectbuttondiv_' + imagefield + '"><button id="unselectbutton_' + imagefield + '" class="small button" type="button">' + lang().product_js_unselect_image + '</button></div>';

		if (stringStartsWith(imagefield, 'nutrition')) {
			// width big enough to display a copy next to nutrition table?
			if ($('#nutrition').width() - $('#nutrition_data_table').width() > 405) {

				if ((! first_display) || ($('#nutrition_image_copy').html() === '')) {
					$('#nutrition_image_copy').html('<img src="' + img_path + display_url + '" />').css("left", $('#nutrition_data_table').width() + 10);
				}
			}
		}

		if ((imagetype == 'ingredients') || (imagetype == 'packaging')) {

			html += '<div id="ocrbutton_loading_' + imagefield + '"></div><div class="button_div" id="ocrbuttondiv_' + imagefield + '">'
			+ ' <button id="ocrbuttongooglecloudvision_' + imagefield + '" class="small button" type="button">' + lang()["product_js_extract_" + imagetype] + '</button></div>';

			var full_url = display_url.replace(/\.400\./, ".full.");
			$('#' + imagefield + '_image_full').html('<img src="' + img_path + full_url + '" class="' + imagetype + '_image_full"/>');
			

			$('div[id="display_' + imagefield +'"]').html(html);

			$("#ocrbuttongooglecloudvision_" + imagefield).click({imagefield:imagefield},function(event) {
				event.stopPropagation();
				event.preventDefault();
				// alert(event.data.imagefield);
				$('div[id="ocrbutton_loading_' + imagefield +'"]').html('<img src="/images/misc/loading2.gif" /> ' + lang()["product_js_extracting_" + imagetype]).show();
				$('div[id="ocrbuttondiv_' + imagefield +'"]').hide();
				$.post(
					'/cgi/' + imagetype + '.pl',
					{code: code, id: imagefield, process_image:1, ocr_engine:"google_cloud_vision" },
					null,
					'json'
				)
					.done(function(data) {
						$('div[id="ocrbuttondiv_' + imagefield +'"]').show();
						if (data.status === 0) {
							$('div[id="ocrbutton_loading_' + imagefield +'"]').html(lang()["product_js_extracted_" + imagetype + "_ok"]);
							var text_id = imagefield.replace(imagetype, imagetype + "_text");
							$("#" + text_id).val(data[imagetype + "_text_from_image"]);
						}
						else {
							$('div[id="ocrbutton_loading_' + imagefield +'"]').html(lang()["product_js_extracted_" + imagetype + "_nok"]);
						}
					})
					.fail(function() {
						$('div[id="ocrbuttondiv_' + imagefield +'"]').show();
						$('div[id="ocrbutton_loading_' + imagefield +'"]').html(lang().job_status_failed);
					})
					.always(function() {
						$(document).foundation('equalizer', 'reflow');
					});

				//$(document).foundation('equalizer', 'reflow');
			});

		} else {
			
			$('div[id="display_' + imagefield +'"]').html(html);
			
		}

		$("#unselectbutton_" + imagefield).click({imagefield:imagefield},function(event) {
			event.stopPropagation();
			event.preventDefault();
			// alert(event.data.imagefield);
			$('div[id="unselectbuttondiv_' + imagefield +'"]').html('<img src="/images/misc/loading2.gif" /> ' + lang().product_js_unselecting_image);
			$.post(
				'/cgi/product_image_unselect.pl',
				{code: code, id: imagefield },
				null, 
				'json'
			)
				.done(function(data) {
					if (data.status_code === 0) {
						$('div[id="unselectbuttondiv_' + imagefield +'"]').html(lang().product_js_unselected_image_ok);
						delete imagefield_url[imagefield];
					}
					else {
						$('div[id="unselectbuttondiv_' + imagefield +'"]').html(lang().product_js_unselected_image_nok);
					}
					update_display(imagefield, false);
					$('div[id="display_' + imagefield +'"]').html('');
				})
				.fail(function() {
					$('div[id="unselectbuttondiv_' + imagefield +'"]').html(lang().product_js_unselected_image_nok);
				})
				.always(function() {
					$(document).foundation('equalizer', 'reflow');
				});

			//$(document).foundation('equalizer', 'reflow');

		});

	}

	$(document).foundation('equalizer', 'reflow');
}

function initializeTagifyInputs() {
	document.
		querySelectorAll("input.tagify-me").
		forEach((input) => initializeTagifyInput(input));
}

const maximumRecentEntriesPerTag = 3;
function initializeTagifyInput(el) {
	const input = new Tagify(el, {
		autocomplete: true,
		whitelist: get_recents(el.id) || [],
		dropdown: {
			enabled: 0
		}
	});

	let abortController;
	input.on("input", function (event) {
		const value = event.detail.value;
		input.settings.whitelist = []; // reset the whitelist

		if (el.dataset.autocomplete && el.dataset.autocomplete !== "") {
			// https://developer.mozilla.org/en-US/docs/Web/API/AbortController/abort
			if (abortController) {
				abortController.abort();
			}

			abortController = new AbortController();

			fetch(el.dataset.autocomplete + "term=" + value, {
				signal: abortController.signal
			}).
				then((RES) => RES.json()).
				then(function (whitelist) {
					input.settings.whitelist = whitelist;
					input.dropdown.show.call(input, value); // render the suggestions dropdown
				});
		}
	});

	input.on("add", function (event) {
		let obj;

		try {
			obj = JSON.parse(window.localStorage.getItem("po_last_tags"));
		} catch (err) {
			if (err.name == "NS_ERROR_FILE_CORRUPTED") {
				obj = null;
			}
		}

		const tag = event.detail.data.value;
		if (obj === null) {
			obj = {};
			obj[el.id] = [tag];
		} else if (obj[el.id] === null || !Array.isArray(obj[el.id])) {
			obj[el.id] = [tag];
		} else {
			if (obj[el.id].indexOf(tag) != -1) {
				return;
			}

			if (obj[el.id].length >= maximumRecentEntriesPerTag) {
				obj[el.id].pop();
			}

			obj[el.id].unshift(tag);
		}

		try {
			window.localStorage.setItem("po_last_tags", JSON.stringify(obj));
		} catch (err) {
			if (err.name == "NS_ERROR_FILE_CORRUPTED") {
				// Don't to anything
			}
		}

		input.settings.whitelist = obj[el.id]; // reset the whitelist
	});

	document.
		getElementById("product_form").
		addEventListener("submit", function () {
			el.value = input.value.map((obj) => obj.value).join(",");
		});
}

function get_recents(tagfield) {
	let obj;
	try {
		obj = JSON.parse(window.localStorage.getItem("po_last_tags"));
	} catch (e) {
		if (e.name == "NS_ERROR_FILE_CORRUPTED") {
			obj = null;
		}
	}

	if (
		obj !== null &&
		typeof obj[tagfield] !== "undefined" &&
		obj[tagfield] !== null
	) {
		return obj[tagfield];
	}

	return [];
}

(function( $ ){

	initializeTagifyInputs();

  if (typeof $.cookie('use_low_res_images') !== "undefined") {
      use_low_res_images = true;
  }

	var settings = {
		'thumb_width' : 100,
		'thumb_height' : 100
	};

	var methods = {
    init : function( options ) {

		// Create some defaults, extending them with any options that were provided
		settings = $.extend( settings, options);
		img_path = settings.img_path;
		code = $("input:hidden[name=\"code\"]", $(this).closest("form")).val();

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

			$.each(images, function(index, image) {
				var selected = '';
				imgids[image.imgid] = index;
				if (($("input:hidden[name=\"" + id + ".imgid\"]").val()) == image.imgid) {
					selected = ' ui-selected';
				}
				html += '<li id="' + id + '_' + image.imgid + '" class="ui-state-default ui-selectee' + selected + '">';
				html += '<img src="' + settings.img_path + image.thumb_url +'" title="'  + image.uploaded + ' - ' + image.uploader + '"/>';

				if ((stringStartsWith(id, 'manage')) && (admin)) {
					html += '<div class="show_for_manage_images">' + image.uploaded + '<br/>' + image.uploader + '</div>';
				}

				html += '</li>';
			});
			html += '</ul>';

			if (! stringStartsWith(id, 'manage')) {

      html += '<div style="clear:both" class="command upload_image_div">';
			html += '<a href="#" class="button small expand" id="imgsearchbutton_' + id + '"> '
+ '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class="icon"><circle cx="12" cy="12" r="3.2"/><path d="M9 2L7.17 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2h-3.17L15 2H9zm3 15c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5z"/><path d="M0 0h24v24H0z" fill="none"/></svg>'
+ lang().product_js_upload_image
+ '<input type="file" accept="image/*" class="img_input" name="imgupload_' + id + '" id="imgupload_' + id
+ '" data-url="/cgi/product_image_upload.pl" multiple '
+ 'style="position: absolute;right:0;bottom:0;top:0;cursor:pointer;opacity:0;font-size:40px;"/>'
+ '</a>'
+ '</div>'
+ '<p class="note">' + lang().product_js_upload_image_note + '</p>'
+ '<div id="progressbar_' + id + '" class="progress" style="display:none">'
+  '<span id="progressmeter_' + id + '" class="meter" style="width:0%"></span>'
+ '</div>'
+ '<div id="imgsearchmsg_' + id + '" data-alert class="alert-box info" style="display:none">' + lang().product_js_uploading_image
+ '<a href="#" class="close">&times;</a>'
+ '</div>'
+ '<div id="imgsearcherror_' + id + '" data-alert class="alert-box alert" style="display:none">' + lang().product_js_image_upload_error
+ '<a href="#" class="close">&times;</a>'
+ '</div>';


      html += '<input type="checkbox" class="use_low_res_images" name="use_low_res_images_' + id + '" id="use_low_res_images_' + id + '">';
      html += '<label for="use_low_res_images_' + id + '">' + lang().product_js_use_low_res_images + '</label>';

      html += '<div class="row">';
			html += '<div class="columns small-12 medium-12 large-6 xlarge-8"><div class="cropbox" id="cropbox_' + id +'"></div></div>';
			html += '<div class="columns small-12 medium-12 large-6 xlarge-4"><div class="display" id="display_' + id +'"></div></div>';
      html += '</div>';
			}

			$this.html(html);

      if (use_low_res_images) {
          $("#use_low_res_images_" + id).prop("checked", true);
      }

      $("#use_low_res_images_" + id).change(function() {
        use_low_res_images = $("#use_low_res_images_" + id).is(':checked');
        if (use_low_res_images) {
          $.cookie('use_low_res_images', '1', { expires: 180, path: '/' });
        }
        else {
          $.removeCookie('use_low_res_images', { path: '/'});
        }
        $(".use_low_res_images").each(function() {
          $(this).prop( "checked", use_low_res_images );
        });
      });

      $(document).foundation('equalizer', 'reflow');

			if (! stringStartsWith(id, 'manage')) {

			update_display(id, true);



	var imagefield = id;

   $('#imgupload_' + id).fileupload({
        sequentialUploads: true,
        dataType: 'json',
        url: '/cgi/product_image_upload.pl',
		formData : [{name: 'jqueryfileupload', value: 1}, {name: 'imagefield', value: imagefield}, {name: 'code', value: code}, {name: 'source', value: 'product_edit_form'}],
		resizeMaxWidth : 2000,
		resizeMaxHeight : 2000,


        done: function (e, data) {

			if (data.result) {
			if (data.result.image) {
	$("#imgsearchmsg_" + imagefield).html(lang().product_js_image_received);
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
			$("#imgsearchmsg_" + imagefield).html('<img src="/images/misc/loading2.gif" /> ' + lang().product_js_uploading_image).show();
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

  $('#back-btn').click(function() {
	window.location.href = window.location.origin + '/product/' + window.code;
  });

  initLanguageAdding();

  update_move_data_and_images_to_main_language_message();

  $("#lang").change(update_move_data_and_images_to_main_language_message);

})( jQuery );

function update_move_data_and_images_to_main_language_message () {

  var main_language_id = $("#lang").val();
  var main_language_text = $("#lang option:selected").text();
  $('.main_language').text(main_language_text);
  $('.move_data_and_images_to_main_language').each(function() {
    var divid = $(this).attr('id');
    if (divid === "move_" + main_language_id + "_data_and_images_to_main_language_div") {
      $(this).hide();
    }
    else {
      $(this).show();
    }
  });

  $('.move_data_and_images_to_main_language_checkbox').each(function() {

    var divradioid = $(this).attr('id') + "_radio";

    var $th = $(this);
    if ( $(this).is(':checked')) {
        $("#" + divradioid).show();
    }
    else {
       $("#" + divradioid).hide();
    }

    $th.change(function() {
      var divradioid = $(this).attr('id') + "_radio";
      if ( $(this).is(':checked')) {
          $("#" + divradioid).show();
      }
      else {
         $("#" + divradioid).hide();
      }
    }
    );

  });
}

function initLanguageAdding() {
  const Lang = lang();
  const placeholder = Lang.add_language;
  const languages = convertTranslationsToLanguageList(Lang);

  const existingLanguages = [];
  const tabs = document.querySelectorAll('li.tabs:not([data-language="new_lc"]):not(.tabs_new)');
  // eslint-disable-next-line guard-for-in
  for (let i = 0; i < tabs.length; ++i) {
    existingLanguages.push(tabs[i].dataset.language);
  }

  // eslint-disable-next-line no-unused-vars
  const unusedLanguages = languages.filter(function(value) {
    return !existingLanguages.includes(value.id);
  });

  $(".select_add_language").select2({
    placeholder: placeholder,
    allowClear: true,
    data: unusedLanguages
  }).on("select2:select", function (e) {
    var lc = e.params.data.id;
    var language = e.params.data.text;
    add_language_tab(lc, language);
    $('.select_add_language option[value=' + lc + ']').remove();
    $(this).val("").trigger("change");
    var new_sorted_langs = $("#sorted_langs").val() + "," + lc;
    $("#sorted_langs").val(new_sorted_langs);
  });
}

function convertTranslationsToLanguageList(Lang) {
  const results = [];

  // eslint-disable-next-line guard-for-in
  for (var k in Lang) {
    if (k.startsWith('language_')) {
      const language = convertTranslationToLanguage(Lang, k);
      if (language) {
        results.push(language);
      }
    }
  }

  const locale = document.querySelector('html').lang;

  return results.sort(function (a, b) {
    return a.text.localeCompare(b.text, locale);
  });
}

function convertTranslationToLanguage(Lang, translation) {
  const match = translation.match(/^language_([a-z]{2,})$/);
  if (match) {
    return { id: match[1], text: Lang[translation] };
  }
}
