#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2024 Association Open Food Facts
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
use ProductOpener::Display qw/:all/;
use ProductOpener::HTTP qw/single_param/;
use ProductOpener::Users qw/$User_id check_password_hash retrieve_user/;
use ProductOpener::Lang qw/lang/;
use ProductOpener::Auth qw/password_signin access_to_protected_resource get_keycloak_level/;

use Apache2::Const -compile => qw(OK :http);
use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Encode;
use Log::Any qw($log);

my $request_ref = ProductOpener::Display::init_request();

$log->info('start') if $log->is_info();

my $r = shift;
my $redirect = single_param('redirect');

if (get_keycloak_level() < 5) {
	my $template_data_ref = {};
	$template_data_ref->{redirect} = $redirect;
	if (defined $User_id) {
		my $loc = $redirect || $formatted_subdomain . "/cgi/session.pl";
		$r->headers_out->set(Location => $loc);
		$r->err_headers_out->add('Set-Cookie' => $request_ref->{cookie});
		$r->status(302);
		return Apache2::Const::OK;
	}

	my @errors = ();

	if ($ENV{'REQUEST_METHOD'} eq 'POST') {
		my $user_ref = retrieve_user($User_id);
		if (not(defined $user_ref)) {
			push @errors, 'undefined user';
			$template_data_ref->{success} = 0;
		}

		my $hash_is_correct
			= check_password_hash(encode_utf8(decode utf8 => single_param('password')),
			$user_ref->{'encrypted_password'});

		# We don't have the right password
		if (not $hash_is_correct) {
			$log->info(
				'bad password - input does not match stored hash',
				{encrypted_password => $user_ref->{'encrypted_password'}}
			) if $log->is_info();
			push @errors, lang('error_bad_login_password');
		}

		if (scalar(@errors) > 0) {
			$template_data_ref->{success} = 0;
		}
		else {
			$template_data_ref->{success} = 1;
		}
	}

	$template_data_ref->{errors} = \@errors;

	# Display the sign in form
	my $html;
	process_template('web/pages/session/sign_in_form.tt.html', $template_data_ref, \$html) or $html = '';
	if ($tt->error()) {
		$html .= '<p>' . $tt->error() . '</p>';
	}

	$request_ref->{title} = lang('login_register_title');
	$request_ref->{content_ref} = \$html;
	display_page($request_ref);
}
else {
	my $loc = $redirect || $formatted_subdomain . "/cgi/session.pl";
	my $status_code = Apache2::Const::HTTP_BAD_REQUEST;
	my $final_status_set = 0;
	if (defined $User_id) {
		# User is already signed in via cookie or similar, as determined by init_request.
		$r->headers_out->set(Location => $loc);
		$status_code = Apache2::Const::HTTP_MOVED_TEMPORARILY;
		$final_status_set = 1;
	}

	if (not($final_status_set) and (not($ENV{'REQUEST_METHOD'} eq 'POST'))) {
		# After OIDC/Keycloak integration, the original login form is no longer used.
		# However, some external sites (ie. Hunger Games) may still be using it.
		$request_ref->{return_url} = single_param('redirect');
		access_to_protected_resource($request_ref);
		$final_status_set = 1;
	}

	if (not($final_status_set)) {
		my ($oidc_user_id, $refresh_token, $refresh_expires_at, $access_token, $access_expires_at, $id_token)
			= password_signin(encode_utf8(decode utf8 => single_param('user_id')),
			encode_utf8(decode utf8 => single_param('password')), $request_ref);
		if ($oidc_user_id) {
			$r->headers_out->set(Location => $loc);
			$status_code = Apache2::Const::HTTP_MOVED_TEMPORARILY;
		}
		else {
			$status_code = Apache2::Const::HTTP_UNAUTHORIZED;
		}

		$final_status_set = 1;
	}

	$r->err_headers_out->add('Set-Cookie' => $request_ref->{cookie});
	$r->status($status_code);
	return Apache2::Const::OK;
}
