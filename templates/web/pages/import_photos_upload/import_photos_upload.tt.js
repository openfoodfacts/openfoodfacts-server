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


// Import photos from a public Google Drive folder

var google_drive_import_job_status = {
	"inactive": "[% edq(lang('job_status_inactive')) %]",
	"active": "[% edq(lang('job_status_active')) %]",
	"finished": "[% edq(lang('job_status_finished')) %]",
	"failed": "[% edq(lang('job_status_failed')) %]"
};

var google_drive_import_code_sources = {
	"file_name": "[% edq(lang('code_from_filename')) %]",
	"scan": "[% edq(lang('scanned_code')) %]",
	"previous_photo": "[% edq(lang('using_previous_code')) %]"
};

function googleDriveImportEscape(text) {
	return \$('<div>').text(text === undefined || text === null ? "" : String(text)).html();
}

function displayGoogleDriveImportStatus(data) {

	var status = \$('#google_drive_import_status');
	var html = "";

	if (data.state) {
		html += "<p><strong>" + googleDriveImportEscape(google_drive_import_job_status[data.state] || data.state) + "</strong></p>";
	}

	if (data.error) {
		html += '<div class="alert-box alert">' + googleDriveImportEscape(data.error_message || data.error) + '</div>';
	}

	var progress = data["import"];

	if (progress) {
		if (progress.status === "listing") {
			html += "<p>[% edq(lang('google_drive_import_listing')) %]</p>";
		}
		if (progress.images_in_folder !== undefined) {
			html += "<p>[% edq(lang('google_drive_import_photos_in_folder')) %][% sep %]: " + progress.images_in_folder;
			if (progress.skipped_files) {
				html += "<br>[% edq(lang('google_drive_import_skipped_files')) %][% sep %]: " + progress.skipped_files;
			}
			html += "</p>";
		}
		if (progress.max_images) {
			html += '<div class="alert-box warning">[% edq(lang("google_drive_import_max_images")) %][% sep %]: ' + progress.max_images + '</div>';
		}
		if (progress.total) {
			var percent = Math.round(100 * progress.processed / progress.total);
			html += "<p>[% edq(lang('google_drive_import_photos_processed')) %][% sep %]: " + progress.processed + " / " + progress.total + "</p>"
				+ '<div class="progress" role="progressbar" aria-valuemin="0" aria-valuemax="100" aria-valuenow="' + percent + '">'
				+ '<span class="meter" style="width:' + percent + '%"></span></div>';
		}

		var rows = "";
		\$.each(progress.results || [], function (index, result) {
			rows += "<tr><td style=\"min-width:120px;\">";
			if (result.thumbnail_url) {
				rows += '<img src="' + googleDriveImportEscape(result.thumbnail_url) + '" alt="">';
			}
			rows += "</td><td>" + googleDriveImportEscape(result.file) + "</td><td>";
			if (result.code) {
				if (result.product_url) {
					rows += '<a href="' + googleDriveImportEscape(result.product_url) + '">' + googleDriveImportEscape(result.code) + '</a>';
				}
				else {
					rows += googleDriveImportEscape(result.code);
				}
				if (result.code_source) {
					rows += "<br><small>" + googleDriveImportEscape(google_drive_import_code_sources[result.code_source] || result.code_source) + "</small>";
				}
			}
			rows += "</td><td>";
			if (result.error) {
				rows += '<span class="label alert">[% edq(lang("error")) %]</span> ' + googleDriveImportEscape(result.error);
			}
			else if (result.info) {
				rows += '<span class="label info">[% edq(lang("info")) %]</span> ' + googleDriveImportEscape(result.info);
			}
			else {
				rows += "[% edq(lang('file_received')) %]";
			}
			rows += "</td></tr>";
		});
		\$('#google_drive_import_results').html(rows);
	}

	status.html(html);
	\$(document).foundation('equalizer', 'reflow');
}

function pollGoogleDriveImportStatus(job_id) {
	\$.getJSON("/cgi/import_photos_google_drive.pl", { action: "status", job_id: job_id }, function (data) {
		displayGoogleDriveImportStatus(data);
		if ((data.state === "inactive") || (data.state === "active")) {
			setTimeout(function () { pollGoogleDriveImportStatus(job_id); }, 3000);
		}
		else {
			\$('#google_drive_import_button').prop("disabled", false);
		}
	}).fail(function () {
		setTimeout(function () { pollGoogleDriveImportStatus(job_id); }, 10000);
	});
}

\$('#google_drive_import_form').on("submit", function (e) {
	e.preventDefault();

	var data = [
		{ name: "action", value: "start" },
		{ name: "folder_url", value: \$('#google_drive_folder_url').val() }
	];

	// Same field values as for the photos uploaded from the computer
	var i = 0;
	while (\$('#tag_' + i).length > 0) {
		data.push({ name: "tagtype_" + i, value: \$('#tagtype_' + i).val() });
		data.push({ name: "tag_" + i, value: \$('#tag_' + i).val() });
		i++;
	}

	\$('#google_drive_import_button').prop("disabled", true);
	\$('#google_drive_import_results').html("");
	displayGoogleDriveImportStatus({});

	\$.post("/cgi/import_photos_google_drive.pl", data, function (result) {
		if (result.job_id) {
			displayGoogleDriveImportStatus({ state: "inactive" });
			pollGoogleDriveImportStatus(result.job_id);
		}
		else {
			displayGoogleDriveImportStatus(result);
			\$('#google_drive_import_button').prop("disabled", false);
		}
	}, "json").fail(function () {
		displayGoogleDriveImportStatus({ error: "[% edq(lang('error')) %]" });
		\$('#google_drive_import_button').prop("disabled", false);
	});
});
