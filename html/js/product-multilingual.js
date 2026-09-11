// This file is part of Product Opener.
//
// Product Opener
// Copyright (C) 2011-2026 Association Open Food Facts
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
/*global lang admin initializeTagifyInput other_nutrients:writable trackMatomoEvent*/ // we change other_nutrients to remove nutrients when they are added
/* exported upload_image update_nutrition_image_copy */

//Polyfill, just in case
if (!Array.isArray) {
    Array.isArray = function (arg) {
        return Object.prototype.toString.call(arg) === '[object Array]';
    };
}

let code;
let current_cropbox;
let images = [];
const imgids = {};
let img_path;
const imagefield_url = {};
// The <image-editor> elements emitted by the server (one per .select_crop field),
// detached when the field is re-rendered and re-appended in the crop box.
const image_editors = {};
let use_low_res_images = false;

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

        // Clean up detached editors for the template placeholder (new_lc) to
        // avoid keeping duplicate hidden hosts after cloning. The clone
        // carries its own <image-editor> elements; template entries like
        // front_new_lc, ingredients_new_lc etc. are no longer needed.
        for (const key in image_editors) {
            if (Object.hasOwn(image_editors, key) && key.includes('new_lc')) {
                delete image_editors[key];
            }
        }

        window.imageFieldUI.init($(".select_crop").filter(":visible"));
        window.imageFieldUI.show($(".select_crop").filter(":visible"));

    });

    update_move_data_and_images_to_main_language_message();

    $(document).foundation('tab', 'reflow');
}

function change_image(imagefield, imgid) {

    // load small 400 pixels image if the use_low_res_images checkbox is checked
    let image_size = '';
    let coordinates_image_size = "full";
    if ($("#use_low_res_images_" + imagefield).is(':checked')) {
        image_size = '.400';
        coordinates_image_size = "400";
    }

    // Unload the image editor previously displayed in a crop box
    if (current_cropbox) {
        const editor = $('div[id="' + current_cropbox + '"]').find('image-editor')[0];
        editor?.unload?.();
    }
    current_cropbox = 'cropbox_' + imagefield;

    // Load the image in the <image-editor> web component of the crop box
    $('div[id="' + current_cropbox + '"]').find('image-editor').each(function () {
        if (this.loadImage) {
            this.loadImage({ imgid: imgid, image_size: image_size, coordinates_image_size: coordinates_image_size, imagefield: imagefield });
        }
    });

    $(document).foundation('equalizer', 'reflow');
}

// Listen for images saved by the <image-editor> web component and update the
// displayed image accordingly.
document.addEventListener('crop-saved', function (event) {
    const imagefield = event.detail.imagefield;
    imagefield_url[imagefield] = event.detail.display_url;
    update_display(imagefield, false, false);
});

// https://jsperf.com/jquery-visibility-test
$.fn.isVisible = function () {
    return $.expr.filters.visible(this[0]);
};

function update_nutrition_image_copy() {
    const nutrition_table_width = Math.ceil($('#nutrition_data_table')[0].getBoundingClientRect().width);
    const nutrition_width = Math.floor($('#nutrition')[0].getBoundingClientRect().width);

    // width big enough to display a copy next to nutrition table?
    
    if ($("#nutrition_data_table").isVisible() && nutrition_width - nutrition_table_width > 405) {
        const position = $('html[dir=rtl]').length ? 'right' : 'left';
        $('#nutrition_image_copy').css(position, nutrition_table_width + 10).show();
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
            const nutrition_table_width = Math.ceil($('#nutrition_data_table')[0].getBoundingClientRect().width);
            const nutrition_width = Math.floor($('#nutrition')[0].getBoundingClientRect().width);

            // width big enough to display a copy next to nutrition table?
            if (nutrition_width - nutrition_table_width > 405) {


                if ((!first_display) || ($('#nutrition_image_copy').html() === '')) {
                    $('#nutrition_image_copy').html('<img src="' + img_path + display_url + '" />').css("left", nutrition_table_width + 10);
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
        forEach((input) => initializeTagifyInput(input, maximumRecentEntriesPerTag)); // defined in tagify-init.js

    // Before submitting the form, we need to convert the Tagify values (array of objects) to a simple comma-separated string
    document.
        getElementById("product_form").
        addEventListener("submit", function () {
            document.
                querySelectorAll("input.tagify-me").
                forEach((input) => {
                    // Parse the Tagify value (JSON string) into an array of objects
                    const tagifyValues = JSON.parse(input.value || "[]");
                    // Map the objects to their `value` property and join them into a string
                    input.value = tagifyValues.map((obj) => obj.value).join(",");
                });
        });
}

const maximumRecentEntriesPerTag = 10;

(function ($) {

    initializeTagifyInputs();

    if (typeof $.cookie('use_low_res_images') !== "undefined") {
        use_low_res_images = true;
    }

    let settings = {
        'thumb_width': 100,
        'thumb_height': 100
    };

    // Image field management: the thumbnail list, the upload UI and the display
    // panel that surround the crop editor. The cropping itself is handled by the
    // <image-editor> web component (html/js/image-editor.js).
    // Exposed as window.imageFieldUI for the initialization script emitted by
    // display_select_crop_init (Images.pm).
    function imageFieldsInit($fields, options) {

        // Create some defaults, extending them with any options that were provided
        settings = $.extend(settings, options);
        img_path = settings.img_path;
        code = $("#code").val();
        code = code.replace(/\s/g, '');

        $fields.each(function () {

            // If the field hasn't been initialized yet
            if (!$(this).data('imagefield-init')) {

                $(this).data('imagefield-init', true);
                imagefield_url[$(this).attr('id')] = $("#" + $(this).attr('id') + '_display_url').val();

            }
        });
    }

    function imageFieldsSetImages(images_data) {

        images = images_data;

        //$("#add_nutriment").change(add_nutriment);
    }

    function imageFieldsAddImage(image_data) {
        images.push(image_data);
    }

    function imageFieldsShow($fields) {

        $fields.each(function () {

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
                        html += '<li id="' + id + '_' + image.imgid + '" class="ui-state-default ui-selectee' + selected + '" tabindex="0">';
                        html += '<img src="' + settings.img_path + image.thumb_url + '" title="' + escapeHtml(image.uploaded) + ' - ' + escapeHtml(image.uploader) + '"/>';

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

                // The <image-editor> web component is emitted by the server inside the
                // .select_crop div (for non-protected fields): detach it so that it is
                // not destroyed when the field is re-rendered, and re-append it in the
                // crop box below.
                const editor = $this.find('image-editor')[0];
                if (editor) {
                    image_editors[id] = editor;
                    editor.remove();
                }

                $this.html(html);

                if ((data_info === undefined || !stringStartsWith(data_info, "protect")) && image_editors[id]) {
                    $('div[id="cropbox_' + id + '"]').append(image_editors[id]);
                }

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
                                    imageFieldsAddImage(data.result.image);
                                    imageFieldsShow($(".select_crop"));

                                    $('#' + imagefield + '_' + data.result.image.imgid).addClass("ui-selected").siblings().removeClass("ui-selected");
                                    change_image(imagefield, data.result.image.imgid);
                                    trackMatomoEvent('product', 'image upload', imagefield);
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

                            // showing the message "image received" once user uploads the image
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
                            $("#progressmeter_" + imagefield).css('width', Number.parseInt(data.loaded / data.total * 100, 10) + "%");
                        }

                    });

                }

            });




            $(".single-selectable li").off("click").on("click", function () {
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

            // Keyboard operability for the thumbnail list (WCAG 2.1.1): the items
            // are focusable (tabindex="0") and Enter / Space activate them like a click.
            $(".single-selectable li").off("keydown").on("keydown", function (event) {
                if (event.key === "Enter" || event.key === " ") {
                    event.preventDefault();
                    $(this).trigger("click");
                }
            });

            $(document).foundation('equalizer', 'reflow');

            return $fields;
        }

    // Expose the functions for the initialization script emitted by
    // display_select_crop_init (Images.pm).
    window.imageFieldUI = {
        init: imageFieldsInit,
        setImages: imageFieldsSetImages,
        addImage: imageFieldsAddImage,
        show: imageFieldsShow,
    };

    $('#back-btn').click(function () {
        window.location.href = window.location.origin + '/product/' + encodeURIComponent(code);
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

    for (const k in Lang) {
        if (Object.hasOwn(Lang, k) && k.startsWith('language_')) {
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

    // Select2 for adding nutrients

    $('#add_nutrient_select').select2({
      placeholder: lang().product_js_add_a_nutrient,
      data: other_nutrients, // Use the other_nutrients array to populate the dropdown
      allowClear: true
    }); 
    $('#add_nutrient_select').val(null).trigger('change');

    $("#add_nutrient_select").on("select2:select", function (e) {
        // get the selected id, and show the corresponding row with id "nutrient_<id>_tr"
        // move the corresponding row to the bottom of the table, just before the add_nutrient_tr row
        const id = e.params.data.id;
        const nutrientRow = $('#nutrient_' + id + '_tr');
        const inputRow = $('#add_nutrient_tr');
        nutrientRow.insertBefore(inputRow);
        nutrientRow.show();

        // remove the selected nutrient from the other_nutrients array
        other_nutrients = other_nutrients.filter(function (item) {
            return item.id !== id;
        });
        // update the select2 dropdown
        $(this).empty().select2({
            placeholder: lang().product_js_add_a_nutrient,
            data: other_nutrients, // Use the other_nutrients array to populate the dropdown
            allowClear: true
        });
        $('#add_nutrient_select').val(null).trigger('change');
    });
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

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;


    return div.innerHTML;
}

async function performImageAction(loadingMsg, successMsg, errorMsg, moveTo, copyData = null) {

    const deleteBtn = document.getElementById('delete_images');
    const moveBtn = document.getElementById('move_images');
    const msgDiv = document.querySelector('div[id="moveimagesmsg"]');

    deleteBtn.classList.add('disabled');
    moveBtn.classList.add('disabled');

    msgDiv.innerHTML = '<img src="/images/misc/loading2.gif" /> ' + escapeHtml(loadingMsg);
    msgDiv.style.display = 'block';
    msgDiv.style.opacity = '1';

    const formData = new FormData(document.getElementById('product_form'));
    formData.append('code', code);
    formData.append('move_to_override', moveTo);
    if (copyData !== null) {
        formData.append('copy_data_override', copyData);
    }

    formData.append('imgids', get_list_of_imgids());

    try {
        const response = await fetch("/cgi/product_image_move.pl", {
            method: "POST",
            body: formData
        });

        if (!response.ok) {
            throw new Error(response.statusText);
        }

        const data = await response.json();

        if (data.error) {
            msgDiv.innerHTML = escapeHtml(errorMsg) + ' - ' + escapeHtml(data.error);
            msgDiv.style.opacity = '1';
        } else {
            const linkHtml = data.code ? ` &rarr; <a href="${encodeURI(data.url)}">${escapeHtml(data.code)}</a>` : '';
            msgDiv.innerHTML = escapeHtml(successMsg) + linkHtml;
            msgDiv.style.opacity = '1';
        }
        window.imageFieldUI.setImages(data.images);
        window.imageFieldUI.show($(".select_crop"));
    } catch (error) {
        msgDiv.innerHTML = escapeHtml(errorMsg) + ' - ' + escapeHtml(error.message);
        msgDiv.style.opacity = '1';
    } finally {
        setTimeout(() => {
            msgDiv.style.opacity = '0';
        }, 1700);
        setTimeout(() => {
            msgDiv.style.display = 'none';
        }, 2000);
        toggle_manage_images_buttons();
    }
}

$("#delete_images").click({}, function (event) {

    event.stopPropagation();
    event.preventDefault();

    if ($("#delete_images").hasClass("disabled")) {
      return;
    }

    performImageAction(lang().product_js_deleting_images, lang().product_js_images_deleted, lang().product_js_images_delete_error, "trash");
});

$("#move_images").click({}, function (event) {

    event.stopPropagation();
    event.preventDefault();

    if ($("#move_images").hasClass("disabled")) {
      return;
    }

    performImageAction(lang().product_js_moving_images, lang().product_js_images_moved, lang().product_js_images_move_error, document.getElementById('move_to').value, document.getElementById('copy_data').checked);
});

// Nutrition facts

$(function () {

    // Nutrition input set checkboxes
    // For each element with the class nutrition_input_set,
    // we use the id of the checkbox nutrition_input_sets_${preparation}_${per}_shown
    // to show or hide the input set column cells with the class nutrition_input_sets_${preparation}_${per}

    $('.nutrition_input_set').on('change', function() {
        const id = $(this).attr('id');
        // remove _shown at the end
        const input_set_class = id.replace(/_shown$/, '');
        if ($(this).prop('checked')) {
            $('.' + input_set_class).show();
        } else {
            $('.' + input_set_class).hide();
            // clear the values: inputs with class nutrient_value that are inside a cell with the input_set_class
            $('.' + input_set_class + ' input.nutrient_value').val('');
        }
        
        
        // Recalculate nutrition image position after table resize
        setTimeout(update_nutrition_image_copy, 50);
        
        
    });

    $('#no_nutrition_data').on('change', function() {
        if ($(this).prop('checked')) {
            $('#nutrition_data_div').hide();
        } else {
            $('#nutrition_data_div').show();
        }
    });

    // If we have global nutrient unit select boxes, when their value changes, we update all the nutrient unit select boxes for all input sets
    // The global unit selectors have the class global_nutrient_unit and an id of the form global_nutrient_[% nutrient.nid %]_unit
    // The input set unit selectors have a class of the form nutrient_[% nutrient.nid %]_unit
    $('.global_nutrient_unit').on('change', function() {
        const id = $(this).attr('id');
        const nutrient_id = id.replace(/^global_nutrient_/, '').replace(/_unit$/, '');
        const new_unit = $(this).val();
        $('.nutrient_' + nutrient_id + '_unit').val(new_unit);
        // trigger a change event on the unit select boxes so that any dependent code is executed
        $('.nutrient_' + nutrient_id + '_unit').trigger('change');
    });

});

// eslint-disable-next-line max-params
function show_warning(should_show, input_id, nutrient_id, per, preparation, warning_message){
    const question_mark_id = `#nutrient_question_mark_${nutrient_id}_${preparation}_${per}`;
    const warning_id = `#nutrient_sugars_warning_${nutrient_id}_${preparation}_${per}`;
    
    if(should_show) {
        $(input_id).css("background-color", "rgb(255 237 235)");
        $(question_mark_id).css("display", "inline-table");
        $(warning_id).text(warning_message);
    }
    // clear the warning only if the warning message we don't show is the same as the existing warning
    // so that we don't remove a warning on sugars > 100g if we change carbohydrates
    else if (warning_message == $(warning_id).text()) {
        $(input_id).css("background-color", "white");
        $(question_mark_id).css("display", "none");
    }
}

function get_nutrient_unit(nutrient_id) {
    // line selector case (user chooses a unit from a list for the whole row of the nutrient)
    const select = $(`#global_nutrient_${nutrient_id}_unit`);
    if (select.length) {
        
        return select.val();
    }
    // per-cell selector case (user chooses a unit from a list for one particular cell)
    const selectPerCell = $(`#nutrient_${nutrient_id}_tr select.nutrient_unit`).first();
    if (selectPerCell.length) {
        return selectPerCell.val();
    }
    // fixed unit case (for nutrients with only one unit, e.g. kJ for energy-kj)
    
    return $(`#nutrient_${nutrient_id}_tr .nutrient_unit`).first().text().trim();
}

function get_nutrient_value(nutrient_id, per, preparation, wanted_unit) {

    const input_id = `#nutrition_input_sets_${preparation}_${per}_nutrients_${nutrient_id}_value_string`;

    let value = Number.parseFloat(($(input_id).val() || '').replace(',', '.'));
    
    if (!Number.isNaN(value)) {
        const current_unit = get_nutrient_unit(nutrient_id);

        const factor = {
            'g': 1,
            'mg': 0.001,
            'µg': 0.000001
        };

        if (factor[current_unit] !== null && factor[wanted_unit] !== null) {
            value *= (factor[current_unit] / factor[wanted_unit]);
        }

        return value;
    }
}

function check_nutrient(nutrient_id, per, preparation, id) {
    // check the changed nutrient value
    const nutrient_value = $('#' + id).val().replace(',', '.').replace(/^(<|>|~)/, '');
    const nutrient_unit = get_nutrient_unit(nutrient_id);

    // define the max valid value
    let max;
    const per_serving = (per === "serving");  // true if "serving", false if "100g"
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
        is_above_or_below_max = (Number.isNaN(nutrient_value) && nutrient_value != '-') || nutrient_value < 0 || nutrient_value > max;
        // if the nutrition facts are indicated per serving, the value can be above 100
        if ((nutrient_value > max) && per_serving && !percent) {
            is_above_or_below_max = false;
        }
        show_warning(is_above_or_below_max, "#"+id, nutrient_id, per, preparation, lang().product_js_enter_value_between_0_and_max.replace('{max}', max));
    }

    // check that nutrients are sound (e.g. sugars is not above carbohydrates)
    // but only if the changed nutrient does not have a warning
    // otherwise we may clear the sugars or saturated-fat warning
    if (! is_above_or_below_max) {
        const fat_value = get_nutrient_value("fat", per, preparation, nutrient_unit);
        const carbohydrates_value = get_nutrient_value("carbohydrates", per, preparation, nutrient_unit);
        const sugars_value = get_nutrient_value("sugars", per, preparation, nutrient_unit);
        const saturated_fats_value = get_nutrient_value("saturated-fat", per, preparation, nutrient_unit);

        const is_sugars_above_carbohydrates = Number.parseFloat(carbohydrates_value) < Number.parseFloat(sugars_value);
        const sugars_input_id = `nutrition_input_sets_${preparation}_${per}_nutrients_sugars_value_string`;
        show_warning(is_sugars_above_carbohydrates, sugars_input_id, "sugars", per, preparation, lang().product_js_sugars_warning);

        const is_fat_above_saturated_fats = Number.parseFloat(fat_value) < Number.parseFloat(saturated_fats_value);
        const saturated_fat_input_id = `nutrition_input_sets_${preparation}_${per}_nutrients_saturated-fat_value_string`;
        show_warning(is_fat_above_saturated_fats, saturated_fat_input_id, "saturated-fat", per, preparation, lang().product_js_saturated_fat_warning);
    }
}

$(function () {
    $('.nutrient_value').each(function () {
        // looking at the template of nutrient inputs, their ids are
        // nutrition_input_sets_[preparation]_[per]_nutrients_[nutrient id]_value_string
        const id = this.id;
        const idParts = this.id.split('_');
        // preparation can be "as_sold" of "prepared"
        // so the index of the nutrient id and of the preparation can vary because of preparation
        // the index of "nutrients" is used to retrieve the id and the per values
        const nutrientIndex = idParts.indexOf('nutrients');

        if (nutrientIndex === -1) {
            // we can't analyze it because we can't get nutrient_id, per and preparation
            return;
        }

        const nutrient_id = idParts[nutrientIndex + 1]; // nutrient id is after "nutrients" (index can vary depending on preparation)
        const per = idParts[nutrientIndex - 1];        // per value is before "nutrients" (index can vary depending on preparation)
        const preparation = idParts.slice(3, nutrientIndex - 1).join('_'); 

        this.oninput = function() {
            check_nutrient(nutrient_id, per, preparation, id);
        };
        check_nutrient(nutrient_id, per, preparation, id);
    });

    $('.nutrient_unit').on('change', function () {
        // Only re-check the nutrient row(s) whose unit actually changed,
        // plus the related nutrients used in cross-checks (fat/carbs/sugars/saturated-fat)
        const $tr = $(this).closest('tr');
        const trId = $tr.attr('id'); // e.g. "nutrient_sugars_tr"
        const nutrient_id = trId ? trId.replace(/^nutrient_/, '').replace(/_tr$/, '') : null;

        const related = ['fat', 'carbohydrates', 'sugars', 'saturated-fat'];
        let idsToRecheck = [];
        if (nutrient_id && related.includes(nutrient_id)) {
            idsToRecheck = related;
        }
        else if (nutrient_id) {
            idsToRecheck = [nutrient_id];
        }

        idsToRecheck.forEach(function (id) {
            $(`.nutrient_value[id*="_nutrients_${id}_value_string"]`).trigger('input');
        });
    });
    
    }
);
