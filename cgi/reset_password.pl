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
use ProductOpener::Images qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Mail qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::URL qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Encode;
use Log::Any qw($log);

ProductOpener::Display::init();

my $template_data_ref = {
	lang => \&lang,
};

my $type = param('type') || 'send_email';
my $action = param('action') || 'display';

my $id = param('userid_or_email');

$log->info("start", { type => $type, action => $action, userid_or_email => $id }) if $log->is_info();

my @errors = ();

my $email_ref = undef;
my $userid = undef;

my $html = '';

if (defined $User_id) {
	display_error($Lang{error_reset_already_connected}{$lang}, undef);
}

if ($action eq 'process') {

	if ($type eq 'send_email') {

	# Is it an email?

		if ($id =~ /\@/) {
			my $emails_ref = retrieve("$data_root/users_emails.sto");
			if (not defined $emails_ref->{$id}) {
				push @errors, $Lang{error_reset_unknown_email}{$lang};
			}
			else {
				$email_ref = $emails_ref->{$id};
			}
		}
		else {
			$id = get_string_id_for_lang("no_language", $id);
			if (! -e "$data_root/users/$id.sto") {
				push @errors, $Lang{error_reset_unknown_id}{$lang};
			}
			else {
				$userid = $id;
			}
		}

	}
	elsif (($type eq 'reset') and (defined param('resetid'))) {

		if (length(param('password')) < 6) {
			push @errors, $Lang{error_invalid_password}{$lang};
		}

		if (param('password') ne param('confirm_password')) {
			push @errors, $Lang{error_different_passwords}{$lang};
		}

	}
	else {
		display_error(lang("error_invalid_address"), 404);
	}


	if ($#errors >= 0) {
		$action = 'display';
	}
}

$template_data_ref->{action} = $action;
$template_data_ref->{type} = $type;


if ($action eq 'display') {
	push @{$template_data_ref->{errors}}, @errors;
}

elsif ($action eq 'process') {

	if ($type eq 'send_email') {

		my @userids = ();
		if (defined $email_ref) {
			@userids = @{$email_ref};
		}
		elsif (defined $userid) {
			@userids = ($userid);
		}

		my $i = 0;

		foreach my $userid (@userids) {

			my $user_ref = retrieve("$data_root/users/$userid.sto");
			if (defined $user_ref) {

				$user_ref->{token_t} = time();
				$user_ref->{token} = generate_token(64);
				$user_ref->{token_ip} = remote_addr();

				store("$data_root/users/$userid.sto", $user_ref);

				my $url = format_subdomain($subdomain) . "/cgi/reset_password.pl?type=reset&resetid=$userid&token=" . $user_ref->{token};

				my $email = lang("reset_password_email_body");
				$email =~ s/<USERID>/$userid/g;
				$email =~ s/<RESET_URL>/$url/g;
				send_email($user_ref, lang("reset_password_email_subject"), $email);

				$i++;
			}
		}

		$template_data_ref->{i} = $i;

	}
	elsif ($type eq 'reset') {
		my $userid = get_string_id_for_lang("no_language", param('resetid'));
		my $user_ref = retrieve("$data_root/users/$userid.sto");
		if (defined $user_ref) {

			if ((param('token') eq $user_ref->{token}) and (time() < ($user_ref->{token_t} + 86400*3))) {
				
				$template_data_ref->{user_token} = "defined";

				$user_ref->{encrypted_password} = create_password_hash( encode_utf8 (decode utf8=>param('password')) );

				delete $user_ref->{token};

				store("$data_root/users/$userid.sto", $user_ref);

			}
			else {
				display_error($Lang{error_reset_invalid_token}{$lang}, undef);
			}
		}
	}


}

$tt->process('reset_password.tt.html', $template_data_ref, \$html);
$html .= "<p>" . $tt->error() . "</p>";

display_new( {

	title=> $Lang{'reset_password'}{$lang},
	content_ref=>\$html,
#	full_width=>1,
});

