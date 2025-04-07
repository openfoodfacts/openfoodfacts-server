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
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::HTTP qw/write_cors_headers single_param/;
use ProductOpener::Users qw/$User_id %User/;
use ProductOpener::Lang qw/lang/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::MaybeXS;
use Log::Any qw($log);

my $request_ref = ProductOpener::Display::init_request();

my $html = '';
my $template_data_ref = {};

$template_data_ref->{user_id} = $User_id;

if (defined $User_id) {

	$template_data_ref->{user_name} = $User{name};

	my $next_action = single_param('next_action');
	my $code = single_param('code');
	my $r = shift;
	my $referer = $r->headers_in->{Referer};
	my $url;

	if ((defined $next_action) and ($code =~ /^(\d+)$/)) {
		if ($next_action eq 'product_add') {
			$url = "/cgi/product.pl?type=add&code=$code";
		}
		elsif ($next_action eq 'product_edit') {
			$url = "/cgi/product.pl?type=edit&code=$code";
		}
	}
	elsif ( (defined $referer)
		and ($referer =~ /^https?:\/\/$subdomain\.$server_domain/)
		and (not($referer =~ /(?:login|session|user|reset_password)\.pl/)))
	{
		$url = $referer;
	}

	if (defined $url) {

		$log->info("redirecting after login", {url => $url}) if $log->is_info();

		$r->err_headers_out->add('Set-Cookie' => $request_ref->{cookie});
		$r->headers_out->set(Location => "$url");
		$r->status(302);
		return 302;
	}
}

if (single_param('jqm')) {

	my %response;
	if (defined $User_id) {
		$response{user_id} = $User_id;
		$response{name} = $User{name};
	}
	else {
		$response{error} = "undefined user";
	}
	my $data = encode_json(\%response);

	write_cors_headers();
	print header(-type => 'application/json', -charset => 'utf-8') . $data;

}
else {
	my $template;
	my $action = param('length');

	if ((defined $action) and ($action eq 'logout')) {
		# The user is signing out
		$template = "signed_out";
		# Set a specific title for sign out
		$request_ref->{title} = lang('sign_out');
	}
	elsif (defined $User_id) {
		# The user is signed in
		$template = "signed_in";
		# Set an empty title to prevent "Sign in" from showing when already signed in
		$request_ref->{title} = '';
	}
	else {
		# The user is signing in: display the login form
		$template = "sign_in_form";
		# Set sign in title only when actually signing in
		$request_ref->{title} = lang('sign_in');
	}

	process_template("web/pages/session/$template.tt.html", $template_data_ref, \$html)
		or $html = "<p>" . $tt->error() . "</p>";

	$request_ref->{content_ref} = \$html;
	display_page($request_ref);
}
