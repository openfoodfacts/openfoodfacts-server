/**
 * Handle the file upload logic
 *
 * As a file is uploaded, it send the data to the server in background.
 *
 * If the response is ok, it redirects to the location provided in response,
 * otherwise it handles error.
 *
 * It also handles displaying a progress bar.
 */
\$('#file_input_$id').fileupload({
	sequentialUploads: true,
	dataType: 'json',
	url: "/cgi/import_file_upload.pl",
	formData : [{name: 'action', value: 'process'}],
	done: function (e, data) {
		if (data.result.location) {
			\$(location).attr('href',data.result.location);
		}
		if (data.result.error) {
			\$("#file_input_button_$id").show();
			\$("#progressbar_$id").hide();
			\$("#file_input_error_$id").html(data.result.error);
			\$("#file_input_error_$id").show();
		}
	},
	fail : function (e, data) {
		\$("#file_input_error_$id").show();
		\$("#file_input_button_$id").show();
		\$("#file_input_msg_$id").hide();
	},
	always : function (e, data) {
		\$("#progressbar_$id").hide();
	},
	start: function (e, data) {
		\$("#file_input_button_$id").hide();
		\$("#file_input_error_$id").hide();
		\$("#file_input_msg_$id").show();
		\$("#progressbar_$id").show();
		\$("#progressmeter_$id").css('width', "0%");

	},
	sent: function (e, data) {
		if (data.dataType &&
				data.dataType.substr(0, 6) === 'iframe') {
			// Iframe Transport does not support progress events.
			// In lack of an indeterminate progress bar, we set
			// the progress to 100%, showing the full animated bar:
			\$("#progressmeter_$id").css('width', "100%");
		}
	},
	progress: function (e, data) {
		\$("#progressmeter_$id").css('width', parseInt(data.loaded / data.total * 100, 10) + "%");
		\$("#file_input_debug_$id").html(data.loaded + ' / ' + data.total);
	}
});


/**
 * Handles the drop zone logic
 *
 * It reuse the file upload component, so that all the same logic is applied.
 */
\$(function() {
	var dropZone = document.getElementById('dropZone_$id');
	var fileInput = document.getElementById('file_input_$id');

	dropZone.addEventListener('dragover', function(e) {
		e.preventDefault();
		dropZone.classList.add('dragover');
	});

	dropZone.addEventListener('dragleave', function(e) {
		e.preventDefault();
		dropZone.classList.remove('dragover');
	});

	dropZone.addEventListener('drop', function(e) {
		e.preventDefault();
		dropZone.classList.remove('dragover'); 

		var files = e.dataTransfer.files;
		if (files.length > 0) {
			fileInput.files = files;

		}
	});
});