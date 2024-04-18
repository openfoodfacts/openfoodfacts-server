
var poll_n1 = 0;
var timeout1 = 5000;
var job_info_state1;

var poll_n2 = 0;
var timeout2 = 5000;
var job_info_state2;

var poll_n3 = 0;
var timeout3 = 5000;
var job_info_state3;

var minion_status = {
	"inactive" : [% lang("minion_status_inactive") %],
	"active" : [% lang("minion_status_active") %],
	"finished" : [% lang("minion_status_finished") %],
	"failed" : [% lang("minion_status_failed") %]
};

(function poll1() {
    \$.ajax({
      url: '/cgi/minion_job_status.pl?job_id=[% local_export_job_id %]',
      success: function(data) {
        \$('#result1').html(minion_status[data.job_info.state]);
        job_info_state1 = data.job_info.state;
      },
      complete: function() {
        // Schedule the next request when the current one's complete
        if ((job_info_state1 == "inactive") || (job_info_state1 == "active")) {
          setTimeout(poll1, timeout1);
          timeout1 += 1000;
      }
        poll_n1++;
      }
    });
  })();

  (function poll2() {
    \$.ajax({
      url: '/cgi/minion_job_status.pl?job_id=[% remote_import_job_id %]',
      success: function(data) {
        \$('#result2').html(minion_status[data.job_info.state]);
        job_info_state2 = data.job_info.state;
      },
      complete: function() {
        // Schedule the next request when the current one's complete
        if ((job_info_state2 == "inactive") || (job_info_state2 == "active")) {
          setTimeout(poll2, timeout2);
          timeout2 += 1000;
      }
        poll_n2++;
      }
    });
  })();

  (function poll3() {
    \$.ajax({
      url: '/cgi/minion_job_status.pl?job_id=[% local_export_status_job_id %]',
      success: function(data) {
        \$('#result3').html(minion_status[data.job_info.state]);
        job_info_state3 = data.job_info.state;
      },
      complete: function() {
        // Schedule the next request when the current one's complete
        if ((job_info_state3 == "inactive") || (job_info_state3 == "active")) {
          setTimeout(poll3, timeout3);
          timeout2 += 1000;
      }
        poll_n3++;
      }
    });
  })();
