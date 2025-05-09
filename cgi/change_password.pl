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
use ProductOpener::Display qw/$tt display_page init_request process_template/;
use ProductOpener::HTTP qw/single_param/;
use ProductOpener::Users qw/$User_id check_password_hash create_password_hash retrieve_user store_user/;
use ProductOpener::Lang qw/lang/;

use Apache2::Const -compile => qw(OK);
use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Encode;
use Log::Any qw($log);

my $request_ref = ProductOpener::Display::init_request();

my $template_data_ref = {method => $ENV{'REQUEST_METHOD'}};

$log->info('start') if $log->is_info();
if (not defined $User_id) {
	my $r = shift;
	$r->headers_out->set(Location => '/cgi/login.pl?redirect=/cgi/change_password.pl');
	$r->status(307);
	return Apache2::Const::OK;
}

my @errors = ();

if ($ENV{'REQUEST_METHOD'} eq 'POST') {
	# TODO: This will change for Keycloak
	my $user_ref = retrieve_user($User_id);
	if (not(defined $user_ref)) {
		push @errors, 'undefined user';
		$template_data_ref->{success} = 0;
	}

	my $hash_is_correct = check_password_hash(encode_utf8(decode utf8 => single_param('current_password')),
		$user_ref->{'encrypted_password'});

	# We don't have the right password
	if (not $hash_is_correct) {
		$log->info(
			'bad password - input does not match stored hash',
			{encrypted_password => $user_ref->{'encrypted_password'}}
		) if $log->is_info();
		push @errors, lang('error_bad_login_password');
	}

	if (length(single_param('password')) < 6) {
		push @errors, lang('error_invalid_password');
	}

	if ((single_param('password')) ne (single_param('confirm_password'))) {
		push @errors, lang('error_different_passwords');
	}

	if (scalar(@errors) > 0) {
		$template_data_ref->{success} = 0;
	}
	else {
		$user_ref->{encrypted_password} = create_password_hash(encode_utf8(decode utf8 => single_param('password')));
		store_user($user_ref);
		$template_data_ref->{success} = 1;
	}
}

$template_data_ref->{errors} = \@errors;

my $html;
process_template('web/pages/change_password/change_password.tt.html', $template_data_ref, \$html) or $html = '';
if ($tt->error()) {
	$html .= '<p>' . $tt->error() . '</p>';
}

$request_ref->{title} = lang('change_password');
$request_ref->{content_ref} = \$html;
display_page($request_ref);
