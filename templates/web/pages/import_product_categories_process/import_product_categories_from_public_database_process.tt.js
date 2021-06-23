var poll_n = 0;
var timeout = 5000;
var job_info_state;

(function poll() {
  \$.ajax({
    url: '/cgi/import_products_categories_job_status.pl?import_id=[% import_id %]',
    success: function(data) {
      \$('#result').html(data.job_info.state);
	  job_info_state = data.job_info.state;
    },
    complete: function() {
      // Schedule the next request when the current one's complete
	  if (job_info_state == "inactive") {
		setTimeout(poll, timeout);
		timeout += 1000;
	}
	  poll_n++;
	  \$('#poll').html(poll_n);
    }
  });
});