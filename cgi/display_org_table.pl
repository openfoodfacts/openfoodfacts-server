#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2023 Association Open Food Facts
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

use ProductOpener::PerlStandards;

use CGI::Carp qw(fatalsToBrowser);
use ProductOpener::Config qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::HTTP qw/single_param/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Data qw/:all/;
use ProductOpener::Users qw/$User_id %User/;
use Log::Any qw($log);

my $request_ref = ProductOpener::Display::init_request();

if ((not defined $User_id)) {
	$log->debug("undefined user", {User_id => $User_id}) if $log->is_debug();
	display_error_and_exit($request_ref, $Lang{error_no_permission}{$lc}, 401);
}

if ((not $request_ref->{admin}) and (not $User{pro_moderator})) {
	$log->debug("user does not have permission to view organisation list", {User_id => $User_id}) if $log->is_debug();
	display_error_and_exit($request_ref, $Lang{error_no_permission}{$lc}, 403);
}

my $orgs_collection = get_orgs_collection();
my @orgs;

my $name = single_param('name');
my $valid_org = single_param('valid_org');

my $query_ref = {};
my $template_data_ref = {};

$query_ref->{name} = qr/\Q$name\E/i if defined $name && $name ne '';
$query_ref->{valid_org} = $valid_org if defined $valid_org && $valid_org ne '';

$template_data_ref->{name} = $name;
$template_data_ref->{valid_org} = $valid_org;
$template_data_ref->{query_filters} = [] unless defined $template_data_ref->{query_filters};

@orgs = $orgs_collection->find($query_ref)->sort({created_t => -1})->all;

$template_data_ref->{orgs} = \@orgs;
$template_data_ref->{has_orgs} = scalar @orgs > 0;

my $html;
process_template('web/pages/dashboard/display_orgs_table.tt.html', $template_data_ref, \$html) or $html = '';
if ($tt->error()) {
	$html .= '<p>' . $tt->error() . '</p>';
}

$request_ref->{initjs} .= <<JS
let oTable = \$('#tagstable').DataTable({
	language: {
		search: "Search:",
		info: "_TOTAL_ labels",
		infoFiltered: " - out of _MAX_"
    },
	paging: true,
	order: [[ 0, "asc" ]],
	scrollX: true,
	dom: 'Bfrtip',
	buttons: [
        {
            extend: 'colvis',
            text: 'Column visibility',
            columns: ':gt(1)'
        }
    ]
});
JS
	;

$request_ref->{scripts} .= <<SCRIPTS
<script src="$static_subdomain/js/datatables.min.js"></script>
SCRIPTS
	;

$request_ref->{header} .= <<HEADER
<link rel="stylesheet" href="$static_subdomain/js/datatables.min.css">
<style>
   /* Custom styling for the column visibility buttons */
   .dt-button-collection .dt-button.active::before {
       content: "✔";
       display: inline-block;
       margin-right: 6px;
   }

   .dt-button-collection .dt-button::before {
       content: " ";
       display: inline-block;
       margin-right: 6px;
   }
</style>
HEADER
	;

$request_ref->{title} = lang("organization_list");
$request_ref->{content_ref} = \$html;
display_page($request_ref);
