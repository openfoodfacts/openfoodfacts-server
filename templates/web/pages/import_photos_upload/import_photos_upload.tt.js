function modifyAddFieldValue(element, field_value_number){
	// Type of field
	var typeSelect = \$(element).find("#tagtype_0");
	typeSelect.attr("name", "tagtype_" + field_value_number);
	typeSelect.attr("id", "tagtype_" + field_value_number);
	typeSelect.val();

	// Value
	var tagContent = \$(element).find("#tag_0");
	tagContent.attr("name", "tag_" + field_value_number);
	tagContent.attr("id", "tag_" + field_value_number);
	tagContent.val("");

	return element;
}

function addAddFieldValue(target, field_values_number) {
	var addFieldValue1 = modifyAddFieldValue(\$(".add_field_values_row").first().clone(), field_values_number);

	\$(".add_field_values_row").last().after(addFieldValue1);
}

//On tag field value change
\$(document).on("change", ".tag-add-field-value > input", function(e){
    var field_value_number = parseInt(e.target.name.substr(e.target.name.length - 1));
    //If it's the last field value, add one more
    if(!isNaN(field_value_number) && \$("#tag_" + (field_value_number + 1).toString()).length === 0){
        addAddFieldValue(e.target, field_value_number + 1);
    }
});

\$(document).on("change", ".tag-add-field > select", function(e){
    var field_value_number = parseInt(e.target.name.substr(e.target.name.length - 1));
    //If it's the last field value, add one more
    if(!isNaN(field_value_number) && \$("#tag_" + (field_value_number + 1).toString()).length === 0){
        addAddFieldValue(e.target, field_value_number + 1);
    }
});


// Keep track of codes that we have seen so that we can submit field values only once
var codes = {};

// We keep the last code recognized in an image to assign it to the next images
var previous_code = "";
var previous_imgid = "";

// We need to wait for one upload to be complete before submitting the next one
// so that we can pass the correct previous_code in the next request
var submitCount = 0;
var shouldStartIndex = 0;
var lastFileUploaded = -1;

function waitForPreviousUpload(submitIndex, callback) {
  if(shouldStartIndex === submitIndex && lastFileUploaded === shouldStartIndex-1) {
    callback()
    return;
  }
  setTimeout(function(){
    waitForPreviousUpload(submitIndex, callback)
  }, 500)
}



/*
 * jQuery File Upload Demo
 * https://github.com/blueimp/jQuery-File-Upload
 *
 * Copyright 2010, Sebastian Tschan
 * https://blueimp.net
 *
 * Licensed under the MIT license:
 * https://opensource.org/licenses/MIT
 */

'use strict';

// Enable iframe cross-domain access via redirect option:
\$('#fileupload').fileupload({
	sequentialUploads: true,
	replaceFileInput : false,
	// Uncomment the following to send cross-domain cookies:
	xhrFields: {withCredentials: true},
	autoUpload: true
});


\$('#fileupload').bind('fileuploadsubmit', function (e, data) {

	var myIndex = submitCount++;
	var \$this = \$(this);

	console.log("submit - myIndex: " + myIndex + " - previous_code: " + previous_code);

	waitForPreviousUpload(myIndex, function() {
		shouldStartIndex++;
		console.log('starting upload #' + myIndex + " - previous_code: " + previous_code);
		// start upload

		data.formData = [
				{ name : "previous_code", value : previous_code},
				{ name : "previous_imgid", value : previous_imgid}
			];
		data.jqXHR = \$this.fileupload('send', data);
	})
	return false;
});

var images_processed = 0;

\$('#fileupload')
    .bind('fileuploadadd', function (e, data) { console.log("fileuploadadd"); })
    .bind('fileuploadstart', function (e, data) { console.log("fileuploadstart");})
    .bind('fileuploadprocessstart', function (e, data) { console.log("fileuploadstart"); \$(document).foundation('equalizer', 'reflow'); })
    .bind('fileuploadprocessstop', function (e, data) { console.log("fileuploadprocessstop"); \$(document).foundation('equalizer', 'reflow'); })
    .bind('fileuploadprocessalways', function (e, data) { console.log("fileuploadprocessalways"); images_processed++; if (images_processed % 20 === 0) { \$(document).foundation('equalizer', 'reflow'); }})
	.bind('fileuploadalways', function (e, data) {
		lastFileUploaded++;
		console.log("always - lastFileUploaded: " + lastFileUploaded);
		\$(document).foundation('equalizer', 'reflow');
});

\$('#tag_0').val("");
\$('#tagtype_0').val("add_tag");

\$('#fileupload')
    .bind('fileuploaddone', function (e, data) {
	if (data.result && data.result.files && data.result.files[0].scanned_code) {
		previous_code = data.result.files[0].scanned_code;
		// Store the imgid with the scanned barcode, so that if we have another image, we can select it as the front image
		if (data.result.image) {
			previous_imgid = data.result.image.imgid;
		}
		else {
			previous_imgid = "";
		}
	}
	else {
		previous_imgid = "";
	}

	console.log("fileuploaddone - previous_code: " + previous_code);

	if (data.result && data.result.files && data.result.files[0].code) {
		var code = data.result.files[0].code;
		console.log("code: " + code);
		if(typeof codes[code] === 'undefined') {
			codes[code] = true;

			var data = [
				{name : "code", value : code},
				{name : "comment", value : "fields added through photos upload on producer platform"}
			];

			var i = 0;
			var n = 0;
			while (\$('#tag_' + i).length > 0) {
				if ((\$('#tag_' + i).val() != '') && ((\$('#tagtype_' + i).val() != 'add_tag'))) {
					data.push({
						name : "add_" + \$('#tagtype_' + i).val(),
						value: \$('#tag_' + i).val()
					});
					n++;
				}
				i++;
			}

			console.log(data);

			if (n > 0) {
				\$.ajax({
					type: "GET",
					contentType: "application/json; charset=utf-8",
					url: "/cgi/product_jqm_multilingual.pl",
					data: data,
					success: function (result) {
						console.log("data sent");
					}
				});
			}
		}
	}

});