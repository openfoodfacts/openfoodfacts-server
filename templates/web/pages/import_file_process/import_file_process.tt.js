
var poll_n = 0;
var timeout = 5000;
var job_info_state;

var statuses = {
	"inactive" : "[% lang("job_status_inactive") %]",
	"active" : "[% lang("job_status_active") %]",
	"finished" : "[% lang("job_status_finished") %]",
	"failed" : "[% lang("job_status_failed") %]",
};

(function poll() {
  \$.ajax({
    url: '/cgi/import_file_job_status.pl?file_id=[% process_file_id %]&import_id=[% process_import_id %]',
    success: function(data) {
      \$('#result').html(statuses[data.job_info.state]);
	  job_info_state = data.job_info.state;
    },
    complete: function() {
      // Schedule the next request when the current one's complete
	  if ((job_info_state == "inactive") || (job_info_state == "active")) {
		setTimeout(poll, timeout);
		timeout += 1000;
	}
	if (job_info_state == "finished") {
	}
	  poll_n++;
	  \$('#poll').html(poll_n);
    }
  });
})();
