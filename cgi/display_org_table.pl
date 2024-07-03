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
use ProductOpener::Lang qw/:all/;
use ProductOpener::Data qw/:all/;
use ProductOpener::Users qw/$User_id %User/;
use Log::Any qw($log);

my $request_ref = ProductOpener::Display::init_request();

if ((not defined $User_id)) {
	$log->debug("undefined user", {User_id => $User_id}) if $log->is_debug();
	display_error_and_exit($request_ref, $Lang{error_no_permission}{$lc}, 401);
}

if ((not $request_ref->{admin}) or (not $User{pro_moderator})) {
	$log->debug("user does not have permission to view organisation list", {User_id => $User_id}) if $log->is_debug();
	display_error_and_exit($request_ref, $Lang{error_no_permission}{$lc}, 403);
}

my $orgs_collection = get_orgs_collection();
my @orgs;


my $name = single_param('name');
my $valid_org = single_param('valid_org'); 

my $query_ref = {};
my $template_data_ref = {};

$query_ref->{name} = qr/\Q$name\E/i if defined $name;
$query_ref->{valid_org} = $valid_org if defined $valid_org;

$template_data_ref->{query_filters} = [] unless defined $template_data_ref->{query_filters};

@orgs = $orgs_collection->find($query_ref)->all;

$template_data_ref = {orgs => \@orgs};

my $html;
process_template('web/pages/dashboard/display_orgs_table.tt.html', $template_data_ref, \$html) or $html = '';
if ($tt->error()) {
	$html .= '<p>' . $tt->error() . '</p>';
}

$request_ref->{title} = "Organization List";
$request_ref->{content_ref} = \$html;
display_page($request_ref);
