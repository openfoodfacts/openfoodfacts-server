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
use ProductOpener::Paths qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::HTTP qw/single_param/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Mail qw/send_email/;
use ProductOpener::Lang qw/$lc %Lang lang/;
use ProductOpener::URL qw/format_subdomain/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Encode;
use Log::Any qw($log);

my $request_ref = ProductOpener::Display::init_request();

my $template_data_ref = {lang => \&lang,};

my $type = single_param('type') || 'send_email';
my $action = single_param('action') || 'display';

my $id = single_param('userid_or_email');
my $resetid = single_param('resetid');

$log->info("start", {type => $type, action => $action, userid_or_email => $id, resetid => $resetid}) if $log->is_info();

my @errors = ();

my $user_ref = undef;

my $html = '';

if (defined $User_id) {
	display_error_and_exit($request_ref, $Lang{error_reset_already_connected}{$lc}, undef);
}

if ($action eq 'process') {

	if ($type eq 'send_email') {

		# Is it an email?

		if ($id =~ /\@/) {
			$user_ref = retrieve_user_by_email($id);
			if (not defined $user_ref) {
				push @errors, $Lang{error_reset_unknown_email}{$lc};
			}
		}
		else {
			$user_ref = retrieve_user($id);
			if (not defined $user_ref) {
				push @errors, $Lang{error_reset_unknown_id}{$lc};
			}
		}

	}
	elsif (($type eq 'reset') and (defined single_param('resetid'))) {

		if (length(single_param('password')) < 6) {
			push @errors, $Lang{error_invalid_password}{$lc};
		}

		if (single_param('password') ne single_param('confirm_password')) {
			push @errors, $Lang{error_different_passwords}{$lc};
		}

	}
	else {
		$log->debug("invalid address", {type => $type}) if $log->is_debug();
		display_error_and_exit($request_ref, lang("error_invalid_address"), 404);
	}

	if ($#errors >= 0) {
		$log->debug("errors", {errors => \@errors}) if $log->is_debug();
		$action = 'display';
	}
}

$template_data_ref->{action} = $action;
$template_data_ref->{type} = $type;

if ($action eq 'display') {
	push @{$template_data_ref->{errors}}, @errors;

	if ($type eq 'reset') {
		$template_data_ref->{token} = single_param('token');
		$template_data_ref->{resetid} = single_param('resetid');
	}
}

elsif ($action eq 'process') {

	if ($type eq 'send_email') {
		$template_data_ref->{status} = "error";

		if (defined $user_ref) {

			$user_ref->{token_t} = time();
			$user_ref->{token} = generate_token(64);
			$user_ref->{token_ip} = remote_addr();

			store_user_session($user_ref);
			my $userid = $user_ref->{userid};

			my $url
				= format_subdomain($subdomain)
				. "/cgi/reset_password.pl?type=reset&resetid=$userid&token="
				. $user_ref->{token};

			my $email = lang("reset_password_email_body");
			$email =~ s/<USERID>/$userid/g;
			$email =~ s/<RESET_URL>/$url/g;
			send_email($user_ref, lang("reset_password_email_subject"), $email);

			$template_data_ref->{status} = "email_sent";
		}
	}
	elsif ($type eq 'reset') {
		my $userid = single_param('resetid');
		my $user_ref = retrieve_user($userid);

		$log->debug("resetting password", {userid => $userid}) if $log->is_debug();

		$template_data_ref->{status} = "error";

		if (defined $user_ref) {

			if (    (defined $user_ref->{token})
				and (defined single_param('token'))
				and (single_param('token') eq $user_ref->{token})
				and (time() < ($user_ref->{token_t} + 86400 * 3)))
			{

				$log->debug("token is valid, updating password", {userid => $userid}) if $log->is_debug();

				$template_data_ref->{status} = "password_reset";

				$user_ref->{encrypted_password}
					= create_password_hash(encode_utf8(decode utf8 => single_param('password')));

				delete $user_ref->{token};

				store_user($user_ref);

			}
			else {
				$log->debug("token is invalid", {userid => $userid}) if $log->is_debug();
				display_error_and_exit($request_ref, $Lang{error_reset_invalid_token}{$lc}, undef);
			}
		}
	}
}

process_template('web/pages/reset_password/reset_password.tt.html', $template_data_ref, \$html)
	or $html = "<p>" . $tt->error() . "</p>";

$request_ref->{title} = $Lang{'reset_password'}{$lc};
$request_ref->{content_ref} = \$html;
display_page($request_ref);

