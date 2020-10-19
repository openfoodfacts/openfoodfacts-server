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

use CGI::Carp qw(fatalsToBrowser);

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Orgs qw/:all/;

use CGI qw/:cgi :form escapeHTML charset/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Log::Any qw($log);

my $type = param('type') || 'add';
my $action = param('action') || 'display';

# Passing values to the template
my $template_data_ref = {
	lang => \&lang,
};

# If the "Create user" form was submitted from the product edit page
# save the password parameter and unset it so that the ProductOpener::Display::init()
# function does not try to authenticate the user (which does not exist yet) with that password

my $new_user_password;
if (($type eq "add") and (defined param('prdct_mult'))) {

	$new_user_password = param('password');
	param("password", "");
}

ProductOpener::Display::init();

my $userid = $User_id;

if (defined param('userid')) {
	$userid = get_fileid(param('userid'), 1);
}

$log->debug("user form - start", { type => $type, action => $action, userid => $userid, User_id => $User_id }) if $log->is_debug();

my $html = '';

my $user_ref = {};

if ($type =~ /^edit/) {
	$user_ref = retrieve("$data_root/users/$userid.sto");
	if (not defined $user_ref) {
		display_error($Lang{error_invalid_user}{$lang}, 404);
	}
}
else {
	$type = 'add';
}

if (($type =~ /^edit/) and ($User_id ne $userid) and not $admin) {
	display_error($Lang{error_no_permission}{$lang}, 403);
}

my $debug = 0;

my @errors = ();

if ($action eq 'process') {

	if ($type eq 'edit') {
		if (param('delete') eq 'on') {
			if ($admin) {
				$type = 'delete';
			}
			else {
				display_error($Lang{error_no_permission}{$lang}, 403);
			}
		}
	}

	if ($type eq 'edit_owner') {
		ProductOpener::Users::check_edit_owner($user_ref, \@errors);
	}
	else {
		ProductOpener::Users::check_user_form($type, $user_ref, \@errors);
	}

	if ($#errors >= 0) {
		if ($type eq 'edit_owner') {
			$action = 'none';
		}
		else {
			$action = 'display';
		}
	}
}

$template_data_ref->{action} = $action;
$template_data_ref->{errors} = \@errors;

$log->debug("user form - before display / process", { type => $type, action => $action, userid => $userid }) if $log->is_debug();

if ($action eq 'display') {

	$scripts .= <<SCRIPT
SCRIPT
;

	# We can pre-fill the form to create an account using the username and password
	# passed in a form to open a session.
	# e.g. when a non-logged user clicks on the "Edit product" button

	if (($type eq "add") and (defined param("user_id"))) {
		my $user_info = remove_tags_and_quote(param('user_id'));
		$user_info =~ /^(.+?)@/;
		if ( defined ($1) ){
			$user_ref->{email} = $user_info;
			$user_ref->{userid} = $1;
			$user_ref->{name} = $1;
			$user_ref->{password} = $new_user_password;
		}
		else{
			$user_ref->{userid} = $user_info;
			$user_ref->{name} = $user_info;
			$user_ref->{password} = $new_user_password;
		}
	}

	$template_data_ref->{display_user_form} = ProductOpener::Users::display_user_form($type, $user_ref,\$scripts);
	$template_data_ref->{display_user_form_optional} = ProductOpener::Users::display_user_form_optional($type, $user_ref);
	$template_data_ref->{display_user_form_admin_only} = ProductOpener::Users::display_user_form_admin_only($type, $user_ref);

	$template_data_ref->{admin} = $admin;

}
elsif ($action eq 'process') {

	if (($type eq 'add') or ($type =~ /^edit/)) {
		ProductOpener::Users::process_user_form($type, $user_ref);
	}
	elsif ($type eq 'delete') {
		ProductOpener::Users::delete_user($user_ref);
	}
	
	if ($type eq 'add') {

		$template_data_ref->{user_requested_org} = $user_ref->{requested_org};
	
		my $requested_org_ref = retrieve_org($user_ref->{requested_org});
		$template_data_ref->{add_user_existing_org} = sprintf(lang("add_user_existing_org"), org_name($requested_org_ref));

		$template_data_ref->{user_org} = $user_ref->{org};

		$template_data_ref->{server_options_producers_platform} = $server_options{producers_platform};
				
		my $pro_url = "https://" . $subdomain . ".pro." . $server_domain . "/";
		$template_data_ref->{add_user_pro_url} = sprintf(lang("add_user_you_can_edit_pro_promo"), $pro_url);

		$template_data_ref->{add_user_you_can_edit} = sprintf(lang("add_user_you_can_edit"), lang("get_the_app_link"));
		$template_data_ref->{add_user_join_the_project} = sprintf(lang("add_user_join_the_project"), lang("site_name"));
	}

}

$template_data_ref->{debug} = $debug;
$template_data_ref->{userid} = $userid;
$template_data_ref->{type} = $type;

my $full_width = 1;
if ($action ne 'display') {
	$full_width = 0;
}

if (($type eq "edit_owner") and ($action eq "process")) {
	$log->info("redirecting to / after changing owner", { }) if $log->is_info();

	my $r = shift;
	$r->headers_out->set(Location =>"/");
	$r->status(301);
	return 301;
}
else {
	
	my $title = lang($type . '_user_' . $action);

	$tt->process('user_form.tt.html', $template_data_ref, \$html);
	$html .= "<p>" . $tt->error() . "</p>";
	
	display_new( {
		title=>$title,
		content_ref=>\$html,
		full_width=>$full_width,
	});
}
