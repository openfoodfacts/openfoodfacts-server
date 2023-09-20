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

use CGI qw/:cgi :form escapeHTML charset/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Log::Any qw($log);

my $type = param('type') || 'add';
my $action = param('action') || 'display';

# If the "Create user" form was submitted from the product edit page
# save the password parameter and unset it so that the ProductOpener::Display::init()
# function does not try to authenticate the user (which does not exist yet) with that password

my $new_user_password;
if (($type eq "add") and (defined param('prdct_mult'))) {

	$new_user_password = param('password');
	param("password", "");
}

ProductOpener::Display::init();

my $userid = get_fileid(param('userid'), 1);

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
		ProductOpener::Users::check_user_form($user_ref, \@errors);
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

if (($action eq "display") or ($action eq "none")) {

	if ($#errors >= 0) {
		$html .= "
		<div class='alert-box alert'>
			<p>
				<b>$Lang{correct_the_following_errors}{$lang}</b>
			</p>
		";
		foreach my $error (@errors) {
			$html .= "$error<br />";
		}
		$html .= '</div>';
	}
}

if ($action eq 'display') {

	if ($server_domain =~ /\.org\b/) {
		# in production, temporarily redirect to open food facts
		my $location = "https://$cc-$lc.openfoodfacts.org/cgi/user.pl";
		my $r = shift;
		$r->headers_out->set(Location =>$location);
		$r->status(307);
		return 307;
	}

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

	$html .= start_form()
	. "<table>";

	$html .= ProductOpener::Users::display_user_form($user_ref,\$scripts);
	$html .= ProductOpener::Users::display_user_form_optional($user_ref);
	$html .= ProductOpener::Users::display_user_form_admin_only($user_ref);

	if ($admin) {
		$html .= "\n<tr><td colspan=\"2\">" . checkbox(-name=>'delete', -label=>lang("delete_user")) . "</td></tr>";
	}

	$html .= "\n<tr><td>"
	. hidden(-name=>'action', -value=>'process', -override=>1)
	. hidden(-name=>'type', -value=>$type, -override=>1)
	. hidden(-name=>'userid', -value=>$userid, -override=>1)
	. submit(-class=>'button')
	. "</td></tr>\n</table>"
	. end_form();

}
elsif ($action eq 'process') {

	my $dialog = '_user_confirm';
	if (($server_domain =~ /\.org\b/) and ($type eq 'add')) {
		# in production, temporarily redirect to open food facts
		my $location = "https://$cc-$lc.openfoodfacts.org/cgi/user.pl";
		my $r = shift;
		$r->headers_out->set(Location =>$location);
		$r->status(307);
		return 307;
	}
	elsif (($type eq 'add') or ($type =~ /^edit/)) {
		if ( ProductOpener::Users::process_user_form($user_ref) ) {
			$dialog = '_user_confirm_no_mail';
		}
	}
	elsif ($type eq 'delete') {
		ProductOpener::Users::delete_user($user_ref);
	}

	$html .= lang($type . $dialog);

	if (($type eq 'add') or ($type eq 'edit')) {

		# Do not display donate link on producers platform
		if (not $server_options{producers_platform}) {
			$html .= "<h3>" . lang("you_can_also_help_us") . "</h3>\n";
			$html .= "<p>" . lang("bottom_content") . "</p>\n";
		}
	}
}

if ($debug) {
	$html .= "<p>type: $type action: $action userid: $userid</p>";
}

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
	display_new( {
		title=>lang($type . '_user'),
		content_ref=>\$html,
		full_width=>$full_width,
	});
}
