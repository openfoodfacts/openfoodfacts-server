#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2019 Association Open Food Facts
# Contact: contact@openfoodfacts.org
# Address: 21 rue des Iles, 94100 Saint-Maur des Fossés, France
#
# Product Opener is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

use Modern::Perl '2017';
use utf8;

binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");

use CGI::Carp qw(fatalsToBrowser);

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Mail qw/:all/;
use ProductOpener::Producers qw/:all/;

use Apache2::RequestRec ();
use Apache2::Const ();

use CGI qw/:cgi :form escapeHTML :cgi-lib/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON;
use Log::Any qw($log);
use Spreadsheet::CSV();
use Text::CSV();

ProductOpener::Display::init();

my $title = '';
my $html = '';

if (not defined $owner) {
	display_error(lang("no_owner_defined"), 200);
}

my $exports_ref = retrieve("$data_root/export_files//$owner/exports.sto");
if (not defined $exports_ref) {
	$exports_ref = {};
}

my $started_t = time();
my $export_id = $started_t;

my $exported_file = "$data_root/export_files/$owner/export.$export_id.exported.csv";

$exports_ref->{$export_id} = {
	started_t => $started_t,
	exported_file => $exported_file,
};

# First export the data locally

my $args_ref = {
	user_id => $User_id,
	org_id => $Org_id,
	owner => $owner,
	csv_file => $exported_file,
	export_id => $export_id,
	query => { owner => $owner},
	comment => "Import from producers platform",
};

if (defined $Org_id) {
	$args_ref->{manufacturer} = 1;
	$args_ref->{source_id} = $Org_id;
}
else {
	$args_ref->{no_source} = 1;
}

my $local_export_job_id = $minion->enqueue(export_csv_file => [$args_ref]
	=> { queue => $server_options{minion_local_queue}});

$args_ref->{export_job_id} = $local_export_job_id;

my $remote_import_job_id = $minion->enqueue(import_csv_file => [$args_ref]
	=> { queue => $server_options{minion_export_queue}, parents => [$local_export_job_id]});

$exports_ref->{$export_id}{local_export_job_id} = $local_export_job_id;
$exports_ref->{$export_id}{remote_import_job_id} = $remote_import_job_id;

(-e "$data_root/export_files") or mkdir("$data_root/export_files", 0755);
(-e "$data_root/export_files/$owner") or mkdir("$data_root/export_files/$owner", 0755);

store("$data_root/export_files/$owner/exports.sto", $exports_ref);

$html .= "<p>local export job_id: " . $local_export_job_id . "</p>";

$html .= "<a href=\"/cgi/export_job_status.pl?export_id=$export_id\">status</a>";

$html .= "<p>remote import job_id: " . $remote_import_job_id . "</p>";

$html .= "<a href=\"/cgi/export_job_status.pl?export_id=$export_id\">status</a>";

$html .= "Poll: <div id=\"poll\"></div> Result:<div id=\"result\"></div>";

$initjs .= <<JS

var poll_n = 0;
var timeout = 5000;
var job_info_state;

(function poll() {
  \$.ajax({
    url: '/cgi/export_job_status.pl?export_id=$export_id',
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
})();
JS
;

display_new( {
	title=>$title,
	content_ref=>\$html,
});




exit(0);

