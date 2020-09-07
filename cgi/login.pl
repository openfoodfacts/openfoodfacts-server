#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2020 Association Open Food Facts
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
use ProductOpener::Display qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Lang qw/:all/;

use Apache2::Const -compile => qw(OK);
use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Encode;
use Log::Any qw($log);

ProductOpener::Display::init();

my $template_data_ref = {
	lang => \&lang,
};

$log->info('start') if $log->is_info();

my $r = shift;
my $redirect = param('redirect');
$template_data_ref->{redirect} = $redirect;
if (defined $User_id) {
	my $loc = $redirect || $formatted_subdomain;
	$r->headers_out->set(Location => $loc);
	$r->err_headers_out->add('Set-Cookie' => $cookie);
	$r->status(302);
	return Apache2::Const::OK;
}

my @errors = ();

if ($ENV{'REQUEST_METHOD'} eq 'POST') {
	my $user_file = "$data_root/users/" . get_string_id_for_lang('no_language', $User_id) . '.sto';
	my $user_ref = retrieve($user_file);
	if (not (defined $user_ref)) {
		push @errors, 'undefined user';
		$template_data_ref->{success} = 0;
	}

	my $hash_is_correct = check_password_hash(encode_utf8(decode utf8=>param('password')), $user_ref->{'encrypted_password'} );
	# We don't have the right password
	if (not $hash_is_correct) {
		$log->info('bad password - input does not match stored hash', { encrypted_password => $user_ref->{'encrypted_password'} }) if $log->is_info();
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

my $html;
$tt->process('login.tt.html', $template_data_ref, \$html);
if ($tt->error()) {
	$html .= '<p>' . $tt->error() . '</p>';
}

display_new( {
	title => lang('login_register_title'),
	content_ref => \$html,
});
