// This file is part of Product Opener.
//
// Product Opener
// Copyright (C) 2011-2023 Association Open Food Facts
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

/*eslint dot-location: "off"*/
/*eslint no-console: "off"*/
/*global lang admin otherNutriments Tagify*/
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
    ['g', 'mg', "\u00B5g", '% DV'],
    ['mol/l', 'moll/l', 'mmol/l', 'mval/l', 'ppm', "\u00B0rH", "\u00B0fH", "\u00B0e", "\u00B0dH", 'gpg'],
    ['kJ', 'kcal'],
];

function stringStartsWith(string, prefix) {
    return string.slice(0, prefix.length) == prefix;
}

function add_language_tab(lc, language) {

    $('.tabs').each(function () {
        $(this).removeClass('active');
    });

    $('.new_lc').each(function () {

        const $clone = $(this).clone();

        const $newTh = $clone;
        const newLcID = $newTh.attr('id').replace(/new_lc/, lc);
        $newTh.attr('id', newLcID);

        $clone.attr('data-language', lc);

        $clone.addClass('tabs_' + lc).removeClass('tabs_new_lc');

        $clone.find('[id]').each(function () {

            const $th = $(this);
            const newID = $th.attr('id').replace(/new_lc/, lc);
            $th.attr('id', newID);

        });

        $clone.find('[for]').each(function () {

            const $th = $(this);
            const newID = $th.attr('for').replace(/new_lc/, lc);
            $th.attr('for', newID);

        });

        $clone.find('[name]').each(function () {

            const $th = $(this);
            const newID = $th.attr('name').replace(/new_lc/, lc);
            $th.attr('name', newID);
        });

        $clone.find('[href]').each(function () {

            const $th = $(this);
            const newID = $th.attr('href').replace(/new_lc/, lc);
            $th.attr('href', newID);
        });

        $clone.find('[lang]').each(function () {

            const $th = $(this);
            const newID = $th.attr('lang').replace(/new_lc/, lc);
            $th.attr('lang', newID);
        });

        $clone.find('.tab_language').each(function () {

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

function select_nutriment(event, ui) {


    //alert(ui.item.id + ' = ' + ui.item.value);
    //alert($("#add_nutriment").val());
    let id = $(this).attr('id');
    id = id.replace("_label", "");
    $('#' + id).focus();
    $('#' + id + '_unit').val(ui.item.unit);
    const unit = (ui.item.unit == '%' ? '%' : ui.item.unit).toLowerCase();
    const unitElement = $('#' + id + '_unit');
    const percentElement = $('#' + id + '_unit_percent');
    if (unit === '') {
        unitElement.hide();
        percentElement.hide();
    } else if (unit == '%') {
        unitElement.hide();
        percentElement.show();
    } else {
        unitElement.show();
        percentElement.hide();

        for (let entryIndex = 0; entryIndex < units.length; ++entryIndex) {
            const entry = units[entryIndex];
            for (let unitIndex = 0; unitIndex < entry.length; ++unitIndex) {
                const unitEntry = entry[unitIndex].toLowerCase();
                if (unitEntry == unit) {
                    const domElement = unitElement[0];
                    domElement.options.length = 0; // Remove current entries.
                    for (let itemIndex = 0; itemIndex < entry.length; ++itemIndex) {
                        const unitValue = entry[itemIndex];
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

    const id = parseInt($("#new_max").val(), 10) + 1;
    $("#new_max").val(id);

    const newline = $("#nutriment_new_0_tr").clone();
    const newid = "nutriment_new_" + id;
    newline.attr('id', newid + "_tr");
    newline.find(".nutriment_label").attr("id", newid + "_label").attr("name", newid + "_label");
    newline.find(".nutriment_unit").attr("id", newid + "_unit").attr("name", newid + "_unit");
    newline.find(".nutriment_unit_percent").attr("id", newid + "_unit_percent").attr("name", newid + "_unit_percent");
    newline.find("#nutriment_new_0").attr("id", newid).attr("name", newid);
    newline.find("#nutriment_new_0_prepared").attr("id", newid + "_prepared").attr("name", newid + "_prepared");

    $('#nutrition_data_table > tbody:last').append(newline);
    newline.show();

    newline.find(".nutriment_label").autocomplete({
        source: otherNutriments,
        select: select_nutriment,
        //change: add_line
    });

    newline.find(".nutriment_label").change(add_line);

    $(document).foundation('equalizer', 'reflow');
}

function update_image(imagefield) {

    $('#crop_' + imagefield).attr("src", "/cgi/product_image_rotate.pl?code=" + code + "&imgid=" + imagefield_imgid[imagefield] +
        "&angle=" + angles[imagefield] + "&normalize=" + $("#normalize_" + imagefield).prop('checked') +
        "&white_magic=" + $("#white_magic_" + imagefield).prop('checked'));
    $('div[id="cropbuttonmsg_' + imagefield + '"]').hide();
}

function rotate_image(event) {

    const imagefield = event.data.imagefield;
    const angle = event.data.angle;
    angles[imagefield] += angle;
    angles[imagefield] = (360 + angles[imagefield]) % 360;

    $('img#crop_' + imagefield).cropper('rotate', angle);

    //var selection = $('img#crop_' + imagefield ).cropper('getData');
    const selection = $('img#crop_' + imagefield).cropper('getCropBoxData');

    selection.x = selection.left;
    selection.y = selection.top;

    console.log("selection - current - x:" + selection.x + " - y:" + selection.y + " - width:" + selection.width + " - height:" + selection.height);

    if (selection.width > 0) {
        const x1 = selection.x;
        const y1 = selection.y;
        const x2 = selection.x + selection.width;
        const y2 = selection.y + selection.height;

        const container = $('img#crop_' + imagefield).cropper('getContainerData');
        const w = container.width;
        const h = container.height;
        console.log("selection - image - w:" + w + ' - h:' + h);


        if (angle === 90) {
            selection.x = h - y2;
            selection.y = x1;
            selection.width = y2 - y1;
            selection.height = x2 - x1;
        } else {
            selection.x = y1;
            selection.y = w - x2;
            selection.width = y2 - y1;
            selection.height = x2 - x1;
        }

        selection.left = selection.x;
        selection.top = selection.y;

        $('img#crop_' + imagefield).cropper('setCropBoxData', selection);

        console.log("selection - new - x:" + selection.x + " - y:" + selection.y + " - width:" + selection.width + " - height:" + selection.height);
    }


    event.stopPropagation();
    event.preventDefault();
}

function change_image(imagefield, imgid) {

    //alert("field: " + imagefield + " - imgid: " + imgid);

    const image = images[imgids[imgid]];
    angles[imagefield] = 0;
    imagefield_imgid[imagefield] = imgid;

    // load small 400 pixels image if the use_low_res_images checkbox is checked

    let image_size = '';
    let cropimgdiv_style = '';
    let coordinates_image_size = "full";

    if ($("#use_low_res_images_" + imagefield).is(':checked')) {
        image_size = '.400';
        cropimgdiv_style = 'style="max-width:400px"';
        coordinates_image_size = "400";
    }

    let html = '';

    html += '<div class="command">' + lang().product_js_image_rotate_and_crop + '</div>';

    html += '<div class="row"><div class="small-6 medium-7 large-8 columns">';
    html += '<div class="command"><a id="rotate_left_' + imagefield + '" class="small button" type="button">' + lang().product_js_image_rotate_left + '</a> &nbsp;';
    html += '<a id="rotate_right_' + imagefield + '" class="small button" type="button">' + lang().product_js_image_rotate_right + '</a>';
    html += '<br><a href="' + img_path + image.imgid + '.jpg" target="_blank">' + lang().product_js_image_open_full_size_image + '</a>';
    html += '<br/><input type="checkbox" id="zoom_on_wheel_' + imagefield + '" name="zoom_on_wheel_' + imagefield + '" value="">';
    html += '<label for="zoom_on_wheel_' + imagefield + '" style="margin-top:0px;">' + lang().product_js_zoom_on_wheel + '</label>';
    html += '</div>';
    html += '</div><div class="small-6 medium-5 large-4 columns" style="float:right">';

    html += '<div class="cropbutton_' + imagefield + '"></div>';
    html += '<div class="cropbuttonmsg_' + imagefield + '" class="ui-state-highlight ui-corner-all" style="padding:2px;margin-top:10px;margin-bottom:10px;display:none" ></div>';
    html += '</div></div>';
    html += '<div id="cropimgdiv_' + imagefield + '" class="cropimgdiv" ' + cropimgdiv_style + '><img src="' + img_path + image.imgid + image_size + '.jpg" id="' + 'crop_' + imagefield + '"/></div>';

    html += '<div class="row"><div class="small-6 medium-7 large-8 columns">';
    html += '<input type="checkbox" id="normalize_' + imagefield + '" onchange="update_image(\'' + imagefield + '\');blur();" /><label for="normalize_' + imagefield + '">' + lang().product_js_image_normalize + '</label><br/>';
    html += '<input type="checkbox" id="white_magic_' + imagefield + '" style="display:inline" /><label for="white_magic_' + imagefield +
        '" style="display:inline">' + lang().product_js_image_white_magic + '</label>';
    html += '</div><div class="small-6 medium-5 large-4 columns" style="float:right;padding-top:1rem">';
    html += '<div class="cropbutton_' + imagefield + '"></div>';
    html += '<div class="cropbuttonmsg_' + imagefield + '" class="ui-state-highlight ui-corner-all" style="padding:2px;margin-top:10px;margin-bottom:10px;display:none" ></div>';
    html += '</div></div>';

    if (current_cropbox) {
        $('div[id="' + current_cropbox + '"]').html('');
    }
    current_cropbox = 'cropbox_' + imagefield;
    $('div[id="cropbox_' + imagefield + '"]').html(html);
    $('div[id="cropimgdiv_' + imagefield + '"]').height($('div[id="cropimgdiv_' + imagefield + '"]').width());

    $("#white_magic_" + imagefield).change(function () {
        $('.cropbuttonmsg_' + imagefield).hide();
    });

    const crop_button = 'crop_' + imagefield + '_button';
    $('.cropbutton_' + imagefield).html('<button class="' + crop_button + ' small button" type="button">' + lang().product_js_image_save + '</button>');
    $("." + crop_button).click({ imagefield: imagefield }, function (event) {
        event.stopPropagation();
        event.preventDefault();

        let selection = $('img#crop_' + imagefield).cropper('getData');

        if (!selection) {
            selection = { 'x1': -1, 'y1': -1, 'x2': -1, 'y2': -1 };
        }
        // alert(event.data.imagefield);
        $("." + crop_button).blur();
        $('.cropbutton_' + imagefield).hide();
        $('.cropbuttonmsg_' + imagefield).html('<img src="/images/misc/loading2.gif" /> ' + lang().product_js_image_saving);
        $('.cropbuttonmsg_' + imagefield).show();
        $.post(
            '/cgi/product_image_crop.pl', {
            code: code,
            id: imagefield,
            imgid: imagefield_imgid[imagefield],
            x1: selection.x,
            y1: selection.y,
            x2: selection.x + selection.width,
            y2: selection.y + selection.height,
            coordinates_image_size: coordinates_image_size,
            angle: angles[imagefield],
            normalize: $("#normalize_" + imagefield).prop('checked'),
            white_magic: $("#white_magic_" + imagefield).prop('checked')
        },
            null,
            'json'
        )
            .done(function (data) {
                imagefield_url[imagefield] = data.image.display_url;
                update_display(imagefield, false, false);
                $('.cropbuttonmsg_' + imagefield).html(lang().product_js_image_saved);
            })
            .fail(function () {
                $('.cropbuttonmsg_' + imagefield).html(lang().not_saved);
            })
            .always(function () {
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

    $("#rotate_left_" + imagefield).click({ imagefield: imagefield, angle: -90 }, rotate_image);
    $("#rotate_right_" + imagefield).click({ imagefield: imagefield, angle: 90 }, rotate_image);

    $('img#crop_' + imagefield).click(function () {
        $('img#crop_' + imagefield).cropper('clear');
    });

    $('img#crop_' + imagefield).cropper({
        "viewMode": 2,
        "guides": false,
        "autoCrop": false,
        "zoomable": true,
        "zoomOnWheel": false,
        "zoomOnTouch": false,
        "toggleDragModeOnDblclick": true,
        "checkCrossOrigin": false
    });

    $("#zoom_on_wheel_" + imagefield).change(function () {
        const zoomOnWheel = $("#zoom_on_wheel_" + imagefield).is(':checked');
        $('img#crop_' + imagefield).cropper('destroy').cropper({
            "viewMode": 2,
            "guides": false,
            "autoCrop": false,
            "zoomable": true,
            "zoomOnWheel": zoomOnWheel,
            "zoomOnTouch": false,
            "toggleDragModeOnDblclick": true,
            "checkCrossOrigin": false
        });
    });

    $(document).foundation('equalizer', 'reflow');
}

// https://jsperf.com/jquery-visibility-test
$.fn.isVisible = function () {
    return $.expr.filters.visible(this[0]);
};

function update_nutrition_image_copy() {
    // width big enough to display a copy next to nutrition table?
    if ($("#nutrition_data_table").isVisible() && $('#nutrition').width() - $('#nutrition_data_table').width() > 405) {
        const position = $('html[dir=rtl]').length ? 'right' : 'left';
        $('#nutrition_image_copy').css(position, $('#nutrition_data_table').width() + 10).show();
    } else {
        $('#nutrition_image_copy').hide();
    }
}

function update_display(imagefield, first_display, protected_product) {

    const display_url = imagefield_url[imagefield];

    if (display_url) {

        const imagetype = imagefield.replace(/_\w\w$/, '');

        let html = lang().product_js_current_image + '<br/><img src="' + img_path + display_url + '" />';
        // handling the display of unselect button
        if (!protected_product) {
            html += '<div class="button_div" id="unselectbuttondiv_' + imagefield + '"><button id="unselectbutton_' + imagefield + '" class="small button" type="button">' + lang().product_js_unselect_image + '</button></div>';
        }

        if (stringStartsWith(imagefield, 'nutrition')) {
            // width big enough to display a copy next to nutrition table?
            if ($('#nutrition').width() - $('#nutrition_data_table').width() > 405) {

                if ((!first_display) || ($('#nutrition_image_copy').html() === '')) {
                    $('#nutrition_image_copy').html('<img src="' + img_path + display_url + '" />').css("left", $('#nutrition_data_table').width() + 10);
                }
            }
        }

        if ((imagetype == 'ingredients') || (imagetype == 'packaging')) {

            html += '<div id="ocrbutton_loading_' + imagefield + '"></div><div class="button_div" id="ocrbuttondiv_' + imagefield + '">' +
                ' <button id="ocrbuttongooglecloudvision_' + imagefield + '" class="small button" type="button">' + lang()["product_js_extract_" + imagetype] + '</button></div>';

            const full_url = display_url.replace(/\.400\./, ".full.");
            $('#' + imagefield + '_image_full').html('<img src="' + img_path + full_url + '" class="' + imagetype + '_image_full"/>');

            $('div[id="display_' + imagefield + '"]').html(html);

            $("#ocrbuttongooglecloudvision_" + imagefield).click({ imagefield: imagefield }, function (event) {
                event.stopPropagation();
                event.preventDefault();
                // alert(event.data.imagefield);
                $('div[id="ocrbutton_loading_' + imagefield + '"]').html('<img src="/images/misc/loading2.gif" /> ' + lang()["product_js_extracting_" + imagetype]).show();
                $('div[id="ocrbuttondiv_' + imagefield + '"]').hide();
                $.post(
                    '/cgi/' + imagetype + '.pl', { code: code, id: imagefield, process_image: 1, ocr_engine: "google_cloud_vision" },
                    null,
                    'json'
                )
                    .done(function (data) {
                        $('div[id="ocrbuttondiv_' + imagefield + '"]').show();
                        if (data.status === 0) {
                            $('div[id="ocrbutton_loading_' + imagefield + '"]').html(lang()["product_js_extracted_" + imagetype + "_ok"]);
                            const text_id = imagefield.replace(imagetype, imagetype + "_text");
                            $("#" + text_id).val(data[imagetype + "_text_from_image"]);
                        } else {
                            $('div[id="ocrbutton_loading_' + imagefield + '"]').html(lang()["product_js_extracted_" + imagetype + "_nok"]);
                        }
                    })
                    .fail(function () {
                        $('div[id="ocrbuttondiv_' + imagefield + '"]').show();
                        $('div[id="ocrbutton_loading_' + imagefield + '"]').html(lang().job_status_failed);
                    })
                    .always(function () {
                        $(document).foundation('equalizer', 'reflow');
                    });

            });

        } else {

            $('div[id="display_' + imagefield + '"]').html(html);
        }

        $("#unselectbutton_" + imagefield).click({ imagefield: imagefield }, function (event) {
            event.stopPropagation();
            event.preventDefault();
            // alert(event.data.imagefield);
            $('div[id="unselectbuttondiv_' + imagefield + '"]').html('<img src="/images/misc/loading2.gif" /> ' + lang().product_js_unselecting_image);
            $.post(
                '/cgi/product_image_unselect.pl', { code: code, id: imagefield },
                null,
                'json'
            )
                .done(function (data) {
                    if (data.status_code === 0) {
                        $('div[id="unselectbuttondiv_' + imagefield + '"]').html(lang().product_js_unselected_image_ok);
                        delete imagefield_url[imagefield];
                    } else {
                        $('div[id="unselectbuttondiv_' + imagefield + '"]').html(lang().product_js_unselected_image_nok);
                    }
                    update_display(imagefield, false, protected_product);
                    $('div[id="display_' + imagefield + '"]').html('');
                })
                .fail(function () {
                    $('div[id="unselectbuttondiv_' + imagefield + '"]').html(lang().product_js_unselected_image_nok);
                })
                .always(function () {
                    $(document).foundation('equalizer', 'reflow');
                });

        });

    }

    $(document).foundation('equalizer', 'reflow');
}

function initializeTagifyInputs() {
    document.
        querySelectorAll("input.tagify-me").
        forEach((input) => initializeTagifyInput(input));
}

const maximumRecentEntriesPerTag = 10;

function initializeTagifyInput(el) {
    const input = new Tagify(el, {
        autocomplete: true,
        whitelist: get_recents(el.id) || [],
        dropdown: {
            highlightFirst: false,
            enabled: 0,
            maxItems: 100
        }
    });

    let abortController;
    let debounceTimer;
    const timeoutWait = 300;
    let value = "";

    function updateSuggestions(show) {
        if (value) {
            const lc = (/^\w\w:/).exec(value);
            const term = lc ? value.substring(lc[0].length) : value;
            if (show) {
                input.dropdown.show(term);
            }
        } else {
            input.whitelist = get_recents(el.id) || [];
            if (show) {
                input.dropdown.show();
            }
        }
    }

    function autocompleteWithSearch(newValue) {
        value = newValue;
        input.whitelist = null; // reset the whitelist

        if (el.dataset.autocomplete && el.dataset.autocomplete !== "") {
            clearTimeout(debounceTimer);

            debounceTimer = setTimeout(function () {
                // https://developer.mozilla.org/en-US/docs/Web/API/AbortController/abort
                if (abortController) {
                    abortController.abort();
                }

                abortController = new AbortController();

                fetch(el.dataset.autocomplete + "&string=" + value + "&get_synonyms=1", {
                    signal: abortController.signal
                }).
                    then((RES) => RES.json()).
                    then(function (json) {
                        const lc = (/^\w\w:/).exec(value);
                        let whitelist = json.suggestions;
                        if (lc) {
                            whitelist = whitelist.map(function (e) {
                                return {"value": lc + e, "searchBy": e};
                            });
                        }
                        const synonymMap = Object.create(null);
                        // eslint-disable-next-line guard-for-in
                        for (const k in json.matched_synonyms) {
                            synonymMap[json.matched_synonyms[k]] = k;
                        }
                        input.synonymMap = synonymMap;
                        input.whitelist = whitelist;
                        updateSuggestions(true); // render the suggestions dropdown
                    });
            }, timeoutWait);
        }
        updateSuggestions(true);
    }

    input.on("input", function (event) {
        autocompleteWithSearch(event.detail.value);
    });

    input.on("edit:input", function (event) {
        autocompleteWithSearch(event.detail.data.newValue);
    });

    input.on("edit:start", function (event) {
        autocompleteWithSearch(event.detail.data.value);
    });

    input.on("change", function () {
        value = "";
        updateSuggestions(false);
    });

    input.on("edit:updated", function () {
        value = "";
        updateSuggestions(false);
    });

    input.on("dropdown:show", function() {
        if (!input.synonymMap) {
            return;
        }
        $(input.DOM.dropdown).find("div.tagify__dropdown__item").each(function(_,e) {
            let synonymName = e.getAttribute("value");
            const lc = (/^\w\w:/).exec(synonymName);
            if (lc) {
                synonymName = synonymName.substring(3);
            }
            const canonicalName = input.synonymMap[synonymName];
            if (canonicalName && canonicalName !== synonymName) {
                e.innerHTML += " (&rarr; <i>" + canonicalName + "</i>)";
            }
        });
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
        } else if (obj[el.id].indexOf(tag) == -1) {
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

        value = "";
        updateSuggestions(false);
    });

    input.on("focus", function () {
        value = "";
        updateSuggestions(false);
    });

    input.on("blur", function () {
        value = "";
        updateSuggestions(false);
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

(function ($) {

    initializeTagifyInputs();

    if (typeof $.cookie('use_low_res_images') !== "undefined") {
        use_low_res_images = true;
    }

    let settings = {
        'thumb_width': 100,
        'thumb_height': 100
    };

    const methods = {
        init: function (options) {

            // Create some defaults, extending them with any options that were provided
            settings = $.extend(settings, options);
            img_path = settings.img_path;
            code = $("#code").val();
            code = code.replace(/\W/g, '');

            return this.each(function () {

                const $this = $(this),
                    data = $this.data('selectcrop');
                //data = $this.data('tooltip'),
                //tooltip = $('<div />', {
                //  text : $this.attr('title')
                //});

                // If the plugin hasn't been initialized yet
                if (!data) {

                    /*
                      Do more setup stuff here
                    */

                    $(this).data('selectcrop', {
                        init_id: $this.attr('id'),
                        target: $this
                    });
                    imagefield_url[$this.attr('id')] = $("#" + $this.attr('id') + '_display_url').val();

                }
            });
        },
        init_images: function (images_data) {

            images = images_data;

            //$("#add_nutriment").change(add_nutriment);
        },
        add_image: function (image_data) {
            images.push(image_data);
        },
        show: function () {

            this.each(function () {

                const $this = $(this);
                const id = $this.attr('id');
                const data_info = $this.attr("data-info");

                let html = '<ul class="ui-selectable single-selectable">';
                if (typeof data_info === "undefined" || !stringStartsWith(data_info, "protect")) {
                    $.each(images, function (index, image) {
                        let selected = '';
                        imgids[image.imgid] = index;
                        if (($("input:hidden[name=\"" + id + ".imgid\"]").val()) == image.imgid) {
                            selected = ' ui-selected';
                        }
                        html += '<li id="' + id + '_' + image.imgid + '" class="ui-state-default ui-selectee' + selected + '">';
                        html += '<img src="' + settings.img_path + image.thumb_url + '" title="' + image.uploaded + ' - ' + image.uploader + '"/>';

                        if ((stringStartsWith(id, 'manage')) && (admin)) {
                            html += '<div class="show_for_manage_images">' + image.uploaded + '<br/>' + image.uploader + '</div>';
                        }

                        html += '</li>';
                    });
                }
                html += '</ul>';

                if (!stringStartsWith(id, 'manage')) {

                    html += '<div style="clear:both" class="command upload_image_div">';
                    html += '<a class="button small expand" id="imgsearchbutton_' + id + '"> ' +
                        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class="icon"><circle cx="12" cy="12" r="3.2"/><path d="M9 2L7.17 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2h-3.17L15 2H9zm3 15c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5z"/><path d="M0 0h24v24H0z" fill="none"/></svg>' +
                        lang().product_js_upload_image +
                        '<input type="file" accept="image/*" class="img_input" name="imgupload_' + id + '" id="imgupload_' + id +
                        '" data-url="/cgi/product_image_upload.pl" multiple ' +
                        'style="position: absolute;right:0;bottom:0;top:0;cursor:pointer;opacity:0;width:100%;height:100%;"/>' +
                        '</a>' +
                        '</div>' +
                        '<p class="note">' + lang().product_js_upload_image_note + '</p>' +
                        '<div id="progressbar_' + id + '" class="progress" style="display:none">' +
                        '<span id="progressmeter_' + id + '" class="meter" style="width:0%"></span>' +
                        '</div>' +
                        '<div id="imgsearchmsg_' + id + '" data-alert class="alert-box info" style="display:none">' + lang().product_js_uploading_image +
                        '<a href="#" class="close">&times;</a>' +
                        '</div>';


                    if (typeof data_info === "undefined" || !stringStartsWith(data_info, "protect")) {
                        html += '<div id="imgsearcherror_' + id + '" data-alert class="alert-box alert" style="display:none">' + lang().product_js_image_upload_error +
                            '<a href="#" class="close">&times;</a>' +
                            '</div>';
                        html += '<input type="checkbox" class="use_low_res_images" name="use_low_res_images_' + id + '" id="use_low_res_images_' + id + '">';
                        html += '<label for="use_low_res_images_' + id + '">' + lang().product_js_use_low_res_images + '</label>';

                        html += '<div class="row">';
                        html += '<div class="columns small-12 medium-12 large-6 xlarge-8"><div class="cropbox" id="cropbox_' + id + '"></div></div>';
                        html += '<div class="columns small-12 medium-12 large-6 xlarge-4"><div class="display" id="display_' + id + '"></div></div>';
                        html += '</div>';
                    }
                    else {
                        html += '<div class="columns small-12 medium-12 large-6 xlarge-4"><div class="display" id="display_' + id + '"></div></div>';
                    }
                }

                $this.html(html);

                if (use_low_res_images) {
                    $("#use_low_res_images_" + id).prop("checked", true);
                }

                $("#use_low_res_images_" + id).change(function () {
                    use_low_res_images = $("#use_low_res_images_" + id).is(':checked');
                    if (use_low_res_images) {
                        $.cookie('use_low_res_images', '1', { expires: 180, path: '/' });
                    } else {
                        $.removeCookie('use_low_res_images', { path: '/' });
                    }
                    $(".use_low_res_images").each(function () {
                        $(this).prop("checked", use_low_res_images);
                    });
                });

                $(document).foundation('equalizer', 'reflow');

                if (!stringStartsWith(id, 'manage')) {

                    // handling the display of unselect button
                    if (typeof data_info === "undefined" || !stringStartsWith(data_info, "protect")) {
                        update_display(id, true, false);
                    }
                    else {
                        update_display(id, true, true);

                    }



                    const imagefield = id;

                    $('#imgupload_' + id).fileupload({
                        sequentialUploads: true,
                        dataType: 'json',
                        url: '/cgi/product_image_upload.pl',
                        formData: [{ name: 'jqueryfileupload', value: 1 }, { name: 'imagefield', value: imagefield }, { name: 'code', value: code }, { name: 'source', value: 'product_edit_form' }],
                        resizeMaxWidth: 2000,
                        resizeMaxHeight: 2000,


                        done: function (e, data) {

                            if (data.result) {
                                if (data.result.image) {
                                    $("#imgsearchmsg_" + imagefield).html(lang().product_js_image_received);
                                    $("input:hidden[name=\"" + data.imagefield + ".imgid\"]").val(data.result.image.imgid);
                                    $([]).selectcrop('add_image', data.result.image);
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
                        fail: function () {
                            $("#imgsearcherror_" + imagefield).show();
                        },
                        always: function () {
                            $("#progressbar_" + imagefield).hide();
                            $("#imgsearchbutton_" + imagefield).show();
                            $("#imgsearchmsg_" + imagefield).hide();

                            // showing the message "image recieved" once user uploads the image
                            if (typeof data_info === "string" && stringStartsWith(data_info, "protect")) {
                                $("#imgsearchmsg_" + imagefield).html(lang().product_js_image_received);
                                $("#imgsearchmsg_" + imagefield).show();
                            }
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




            $(".single-selectable li").click(function () {
                const li_id = $(this).attr("id");
                const imagefield_imgid = li_id.split("_");
                const imagefield = imagefield_imgid[0] + "_" + imagefield_imgid[1];
                const imgid = imagefield_imgid[2];
                $("input:hidden[name=\"" + imagefield + ".imgid\"]").val(imgid);
                if ((stringStartsWith(imagefield, 'manage')) && ($("#manage_images_drop").hasClass("active"))) {
                    $(this).toggleClass("ui-selected");
                } else {
                    $(this).addClass("ui-selected").siblings().removeClass("ui-selected");
                }
                if (stringStartsWith(imagefield, 'manage')) {
                    toggle_manage_images_buttons();
                } else {
                    change_image(imagefield, imgid);
                }
            });

            $(document).foundation('equalizer', 'reflow');

            return this;
        },

    };


    $.fn.selectcrop = function (method) {

        // Method calling logic
        if (methods[method]) {
            return methods[method].apply(this, Array.prototype.slice.call(arguments, 1));
        } else if (typeof method === 'object' || !method) {
            return methods.init.apply(this, arguments);
        } else {
            $.error('Method ' + method + ' does not exist on jQuery.selectcrop');
        }

    };

    $('#back-btn').click(function () {
        window.location.href = window.location.origin + '/product/' + window.code;
    });

    initLanguageAdding();

    update_move_data_and_images_to_main_language_message();

    $("#lang").change(update_move_data_and_images_to_main_language_message);

})(jQuery);

function update_move_data_and_images_to_main_language_message() {

    const main_language_id = $("#lang").val();
    const main_language_text = $("#lang option:selected").text();
    $('.main_language').text(main_language_text);
    $('.move_data_and_images_to_main_language').each(function () {
        const divid = $(this).attr('id');
        if (divid === "move_" + main_language_id + "_data_and_images_to_main_language_div") {
            $(this).hide();
        } else {
            $(this).show();
        }
    });

    $('.move_data_and_images_to_main_language_checkbox').each(function () {

        const divradioid = $(this).attr('id') + "_radio";

        const $th = $(this);
        if ($(this).is(':checked')) {
            $("#" + divradioid).show();
        } else {
            $("#" + divradioid).hide();
        }

        $th.change(function () {
            const divradioid = $(this).attr('id') + "_radio";
            if ($(this).is(':checked')) {
                $("#" + divradioid).show();
            } else {
                $("#" + divradioid).hide();
            }
        });

    });
}

function initLanguageAdding() {
    const Lang = lang();
    const placeholder = Lang.add_language;
    const languages = convertTranslationsToLanguageList(Lang);

    const existingLanguages = [];
    const tabs = document.querySelectorAll('li.tabs:not([data-language="new_lc"]):not(.tabs_new)');
    tabs.forEach((tab) => existingLanguages.push(tab.dataset.language));

    const unusedLanguages = languages.filter((value) => !existingLanguages.includes(value.id));

    $(".select_add_language").select2({
        placeholder: placeholder,
        allowClear: true,
        data: unusedLanguages
    }).on("select2:select", function (e) {
        const lc = e.params.data.id;
        const language = e.params.data.text;
        add_language_tab(lc, language);
        $('.select_add_language option[value=' + lc + ']').remove();
        $(this).val("").trigger("change");
        const new_sorted_langs = $("#sorted_langs").val() + "," + lc;
        $("#sorted_langs").val(new_sorted_langs);
    });
}

function convertTranslationsToLanguageList(Lang) {
    const results = [];

    // eslint-disable-next-line guard-for-in
    for (const k in Lang) {
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
    const match = (/^language_([a-z]{2,})$/).exec(translation);
    if (match) {
        return { id: match[1], text: Lang[translation] };
    }
}

$(function () {

    $('#no_nutrition_data').change(function () {
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


    $(".nutriment_label").autocomplete({
        source: otherNutriments,
        select: select_nutriment,
        //change: add_line
    });

    $("#nutriment_sodium").change(function () {
        swapSalt($("#nutriment_sodium"), $("#nutriment_salt"), 2.5);
    });

    $("#nutriment_salt").change(function () {
        swapSalt($("#nutriment_salt"), $("#nutriment_sodium"), 1 / 2.5);
    });

    $("#nutriment_sodium_prepared").change(function () {
        swapSalt($("#nutriment_sodium_prepared"), $("#nutriment_salt_prepared"), 2.5);
    });

    $("#nutriment_salt_prepared").change(function () {
        swapSalt($("#nutriment_salt_prepared"), $("#nutriment_sodium_prepared"), 1 / 2.5);
    });

    function swapSalt(from, to, multiplier) {
        const source = from.val().replace(",", ".");
        const regex = /^(.*?)(\d+(?:\.\d+)?)(.*?)$/g;
        const match = regex.exec(source);
        let target = match[1] + (parseFloat(match[2]) * multiplier) + match[3];

        if (match) {
            if (match[1] == ".") {
                const number = "0." + match[2];
                target = (parseFloat(number) * multiplier) + match[3];
            }

            to.val(target);
        } else {
            to.val(from.val());
        }
    }

    $("#nutriment_sodium_unit").change(function () {
        $("#nutriment_salt_unit").val($("#nutriment_sodium_unit").val());
    });

    $("#nutriment_salt_unit").change(function () {
        $("#nutriment_sodium_unit").val($("#nutriment_salt_unit").val());
    });

    $("#nutriment_new_0_label").change(add_line);
    $("#nutriment_new_1_label").change(add_line);

});

$(function () {
    const alerts = $('.alert-box.store-state');
    $.each(alerts, function (index, value) {
        const display = $.cookie('state_' + value.id);
        if (display) {
            value.style.display = display;
        } else {
            value.style.display = 'block';
        }
    });
    alerts.on('close.fndtn.alert', function () {
        $.cookie('state_' + $(this)[0].id, 'none', { path: '/', expires: 365, domain: '$server_domain' });
    });
});


$(document).foundation({
    tab: {
        callback: function (tab) {

            $('.tabs').each(function () {
                $(this).removeClass('active');
            });

            const id = tab[0].id; // e.g. tabs_front_image_en_tab
            // pragma warning disable S5852
            const lc = id.replace(/.*(..)_tab/, "$1");
            // pragma warning disable S5852
            $(".tabs_" + lc).addClass('active');

            $(document).foundation('tab', 'reflow');
        }
    }
});


// As the save bar is position:fixed, there is no way to get its width, width:100% will be relative to the viewport, and width:inherit does not work as well.
// Using javascript to set the width of the fixed bar at startup, and when the window is resized.

//var parent_width = $("#fixed_bar").parent().width();
//$("#fixed_bar").width(parent_width);

//$(window).resize(
//	function() {
//		parent_width = $("#fixed_bar").parent().width();
//		$("#fixed_bar").width(parent_width);
//	}
//);

// This function returns a comma separated list of the imgids of images selected in the manage images section
function get_list_of_imgids() {
    let list_of_imgids = '';
    let i = 0;
    $("#manage .ui-selected").each(function () {
        let imgid = $(this).attr('id');
        imgid = imgid.replace("manage_", "");
        list_of_imgids += imgid + ',';
        i += 1;
    });
    if (i) {
        // remove trailing comma
        list_of_imgids = list_of_imgids.slice(0, -1);
    }

    return list_of_imgids;
}

function toggle_manage_images_buttons() {
    $("#delete_images").addClass("disabled");
    $("#move_images").addClass("disabled");
    $("#manage .ui-selected").first().each(function () {
        $("#delete_images").removeClass("disabled");
        $("#move_images").removeClass("disabled");
    });
}

$('#manage_images_accordion').on('toggled', function () {
    toggle_manage_images_buttons();
});

$("#delete_images").click({}, function (event) {

    event.stopPropagation();
    event.preventDefault();

    if (!$("#delete_images").hasClass("disabled")) {

        $("#delete_images").addClass("disabled");
        $("#move_images").addClass("disabled");

        $('div[id="moveimagesmsg"]').html('<img src="/images/misc/loading2.gif" /> ' + lang().product_js_deleting_images);
        $('div[id="moveimagesmsg"]').show();

        get_list_of_imgids();

        $("#product_form").ajaxSubmit({

            url: "/cgi/product_image_move.pl",
            data: { code: code, move_to_override: "trash", imgids: get_list_of_imgids() },
            dataType: 'json',
            success: function (data) {

                if (data.error) {
                    $('div[id="moveimagesmsg"]').html(lang().product_js_images_delete_error + ' - ' + data.error);
                } else {
                    $('div[id="moveimagesmsg"]').html(lang().product_js_images_deleted);
                }
                $([]).selectcrop('init_images', data.images);
                $(".select_crop").selectcrop('show');

            },
            error: function (textStatus) {
                $('div[id="moveimagesmsg"]').html(lang().product_js_images_delete_error + ' - ' + textStatus);
            },
        });

    }

});

$("#move_images").click({}, function (event) {

    event.stopPropagation();
    event.preventDefault();

    if (!$("#move_images").hasClass("disabled")) {

        $("#delete_images").addClass("disabled");
        $("#move_images").addClass("disabled");

        $('div[id="moveimagesmsg"]').html('<img src="/images/misc/loading2.gif" /> ' + lang().product_js_moving_images);
        $('div[id="moveimagesmsg"]').show();

        get_list_of_imgids();

        $("#product_form").ajaxSubmit({

            url: "/cgi/product_image_move.pl",
            data: { code: code, move_to_override: $("#move_to").val(), copy_data_override: $("#copy_data").prop("checked"), imgids: get_list_of_imgids() },
            dataType: 'json',
            success: function (data) {

                if (data.error) {
                    $('div[id="moveimagesmsg"]').html(lang().product_js_images_move_error + ' - ' + data.error);
                } else {
                    $('div[id="moveimagesmsg"]').html(lang().product_js_images_moved + ' &rarr; ' + data.link);
                }
                $([]).selectcrop('init_images', data.images);
                $(".select_crop").selectcrop('show');

            },
            error: function (textStatus) {
                $('div[id="moveimagesmsg"]').html(lang().product_js_images_move_error + ' - ' + textStatus);
            },
            complete: function () {
                $("#move_images").addClass("disabled");
                $("#move_images").addClass("disabled");
                $("#manage .ui-selected").first().each(function () {
                    $("#move_images").removeClass("disabled");
                    $("#move_images").removeClass("disabled");
                });
            }
        });

    }

});

// Nutrition facts

$(function () {
    $('#nutrition_data').change(function() {
        if ($(this).prop('checked')) {
            $('#nutrition_data_instructions').show();
            $('.nutriment_col').show();
        } else {
            $('#nutrition_data_instructions').hide();
            $('.nutriment_col').hide();
            $('.nutriment_value_as_sold').val('');
        }
        update_nutrition_image_copy();
        $(document).foundation('equalizer', 'reflow');
    });

    $('input[name=nutrition_data_per]').change(function() {
        if ($('input[name=nutrition_data_per]:checked').val() == '100g') {
            $('#nutrition_data_100g').show();
            $('#nutrition_data_serving').hide();
        } else {
            $('#nutrition_data_100g').hide();
            $('#nutrition_data_serving').show();
        }
        update_nutrition_image_copy();
        $(document).foundation('equalizer', 'reflow');
    });

    $('#nutrition_data_prepared').change(function() {
        if ($(this).prop('checked')) {
            $('#nutrition_data_prepared_instructions').show();
            $('.nutriment_col_prepared').show();
        } else {
            $('#nutrition_data_prepared_instructions').hide();
            $('.nutriment_col_prepared').hide();
            $('.nutriment_value_prepared').val('');
        }
        update_nutrition_image_copy();
        $(document).foundation('equalizer', 'reflow');
    });

    $('input[name=nutrition_data_prepared_per]').change(function() {
        if ($('input[name=nutrition_data_prepared_per]:checked').val() == '100g') {
            $('#nutrition_data_prepared_100g').show();
            $('#nutrition_data_prepared_serving').hide();
        } else {
            $('#nutrition_data_prepared_100g').hide();
            $('#nutrition_data_prepared_serving').show();
        }
        update_nutrition_image_copy();
        $(document).foundation('equalizer', 'reflow');
    });

    $('#no_nutrition_data').change(function() {
        if ($(this).prop('checked')) {
            $('#nutrition_data_div').hide();
        } else {
            $('#nutrition_data_div').show();
        }
    });

});

function show_warning(should_show, nutrient_id, warning_message){
    if(should_show) {
        $('#nutriment_'+nutrient_id).css("background-color", "rgb(255 237 235)");
        $('#nutriment_question_mark_'+nutrient_id).css("display", "inline-table");
        $('#nutriment_sugars_warning_'+nutrient_id).text(warning_message);
    }
    // clear the warning only if the warning message we don't show is the same as the existing warning
    // so that we don't remove a warning on sugars > 100g if we change carbohydrates
    else if (warning_message == $('#nutriment_sugars_warning_'+nutrient_id).text()) {
        $('#nutriment_'+nutrient_id).css("background-color", "white");
        $('#nutriment_question_mark_'+nutrient_id).css("display", "none");
    }
}

function check_nutrient(nutrient_id) {
    // check the changed nutrient value
    const nutrient_value = $('#nutriment_' + nutrient_id).val().replace(',','.').replace(/^(<|>|~)/, '');
    const nutrient_unit = $('#nutriment_' + nutrient_id + '_unit').val();

    // define the max valid value
    let max;
    let percent;

    if (nutrient_id == 'energy-kj') {
        max = 3800;
    }
    else if (nutrient_id == 'energy-kcal') {
        max = 900;
    }
    else if (nutrient_id == 'alcohol') {
        max = 100;
        percent = true;
    }
    else if (nutrient_unit == 'g') {
        max = 100;
    }
    else if (nutrient_unit == 'mg') {
        max = 100 * 1000;
    }
    else if (nutrient_unit == 'µg') {
        max = 100 * 1000 * 1000;
    }

    let is_above_or_below_max;
    if (max) {
        is_above_or_below_max = (isNaN(nutrient_value) && nutrient_value != '-') || nutrient_value < 0 || nutrient_value > max;
        // if the nutrition facts are indicated per serving, the value can be above 100
        if ((nutrient_value > max) && ($('#nutrition_data_per_serving').is(':checked')) && !percent) {
            is_above_or_below_max = false;
        }
        show_warning(is_above_or_below_max, nutrient_id, lang().product_js_enter_value_between_0_and_max.replace('{max}', max));
    }

    // check that nutrients are sound (e.g. sugars is not above carbohydrates)
    // but only if the changed nutrient does not have a warning
    // otherwise we may clear the sugars or saturated-fat warning
    if (! is_above_or_below_max) {
        const fat_value = $('#nutriment_fat').val().replace(',','.');
        const carbohydrates_value = $('#nutriment_carbohydrates').val().replace(',','.');
        const sugars_value = $('#nutriment_sugars').val().replace(',','.');
        const saturated_fats_value = $('#nutriment_saturated-fat').val().replace(',','.');

        const is_sugars_above_carbohydrates = parseFloat(carbohydrates_value) < parseFloat(sugars_value);
        show_warning(is_sugars_above_carbohydrates, 'sugars', lang().product_js_sugars_warning);

        const is_fat_above_saturated_fats = parseFloat(fat_value) < parseFloat(saturated_fats_value);
        show_warning(is_fat_above_saturated_fats, 'saturated-fat', lang().product_js_saturated_fat_warning);
    }
}

$(function () {
    $('.nutriment_value_as_sold').each(function () {
        const nutrient_id = this.id.replace('nutriment_', '');
        this.oninput = function() {
            check_nutrient(nutrient_id);
        };
        check_nutrient(nutrient_id);
    });
    }
);
