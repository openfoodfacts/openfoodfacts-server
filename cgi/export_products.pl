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
use boolean;

ProductOpener::Display::init();

my $action = param('action') || 'display';

my $title = lang("export_product_data_photos");
my $html = '';

if (not defined $Owner_id) {
	display_error(lang("no_owner_defined"), 200);
}

my $exports_ref = retrieve("$data_root/export_files/${Owner_id}/exports.sto");
if (not defined $exports_ref) {
	$exports_ref = {};
}

if ($action eq "display") {

	$html .= "<p>" . lang("producers_platform_licence") . "</p>";
	$html .= "<p>" . lang("export_product_data_photos_please_check") . "</p>";

	# Display button for moderators only

	if ($User{moderator}) {

	$html .= start_multipart_form(-id=>"export_products_form") ;

	$html .= <<HTML
<input type="submit" class="button small" value="$Lang{export_product_data_photos}{$lc}">
<input type="hidden" name="action" value="process">
HTML
;
	$html .= end_form();

	}
	else {
		$html .= "<p>" . lang("export_products_to_public_database_email") . "</p>";
	}

}

elsif (($action eq "process") and ($User{moderator})) {

	my $started_t = time();
	my $export_id = $started_t;

	my $exported_file = "$data_root/export_files/${Owner_id}/export.$export_id.exported.csv";

	$exports_ref->{$export_id} = {
		started_t => $started_t,
		exported_file => $exported_file,
	};

	# Set the user to the owner userid or org

	my $user_id = $User_id;
	if ($Owner_id =~ /^(org|user)-/) {
		$user_id = $';
	}

	# First export the data locally

	my $args_ref = {
		user_id => $user_id,
		org_id => $Org_id,
		owner_id => $Owner_id,
		csv_file => $exported_file,
		export_id => $export_id,
		query => { owner => $Owner_id, "data_quality_errors_producers_tags.0" => { '$exists' => false }},
		comment => "Import from producers platform",
		include_images_paths => 1,	# Export file paths to images
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
	(-e "$data_root/export_files/${Owner_id}") or mkdir("$data_root/export_files/${Owner_id}", 0755);

	store("$data_root/export_files/${Owner_id}/exports.sto", $exports_ref);

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

}

display_new( {
	title=>$title,
	content_ref=>\$html,
});

exit(0);

