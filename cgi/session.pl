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
use ProductOpener::Store qw/:all/;
use ProductOpener::Texts qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::HTTP qw/single_param/;
use ProductOpener::Users qw/$User_id %User/;
use ProductOpener::Lang qw/lang/;
use ProductOpener::Auth qw/
	access_to_protected_resource
	get_oidc_implementation_level
	is_allowed_return_url
	write_auth_deprecated_headers
	/;

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

my $r = shift || eval {Apache2::RequestUtil->request()};
my $subdomain = $request_ref->{subdomain};
my $referer = $request_ref->{referer} // ($r ? eval {$r->headers_in->{Referer}} : undef);

my $auth_scripts_pattern = qr/(?:login|session|user|reset_password|oidc_sign(?:in|out)(?:_callback)?)\.pl/;

my $return_url = single_param('return_url') // single_param('redirect');
if (defined $return_url && $return_url =~ m{^/(?!/|\\)}) {
	$return_url = $request_ref->{formatted_subdomain} . $return_url;
}

my $target_return_url;
if (    defined $return_url
	and is_allowed_return_url($return_url)
	and ($return_url !~ $auth_scripts_pattern))
{
	$target_return_url = $return_url;
}
elsif ( defined $referer
	and is_allowed_return_url($referer)
	and ($referer !~ $auth_scripts_pattern))
{
	$target_return_url = $referer;
}

if (defined $User_id && !single_param('jqm')) {

	$template_data_ref->{user_name} = $User{name};

	my $next_action = single_param('next_action');
	my $code = single_param('code');
	my $url;

	if ((defined $next_action) and ($code =~ /^(\d+)$/)) {
		if ($next_action eq 'product_add') {
			$url = "/cgi/product.pl?type=add&code=$code";
		}
		elsif ($next_action eq 'product_edit') {
			$url = "/cgi/product.pl?type=edit&code=$code";
		}
	}
	elsif (defined $target_return_url) {
		$url = $target_return_url;
	}

	if (defined $url) {

		$log->info("redirecting after login", {url => $url}) if $log->is_info();

		write_auth_deprecated_headers();
		if (defined $request_ref->{cookie} && $r) {
			$r->err_headers_out->add('Set-Cookie' => $request_ref->{cookie});
		}
		if ($r) {
			$r->headers_out->set(Location => "$url");
			$r->status(302);
		}
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

	write_auth_deprecated_headers();
	print header(-type => 'application/json', -charset => 'utf-8') . $data;
	return;
}
else {
	my $template;
	my $action = param('length');

	if ((defined $action) and ($action eq 'logout')) {
		# The user is signing out
		$template = "signed_out";
	}
	elsif (defined $User_id) {
		# The user is signed in
		$template = "signed_in";
		$request_ref->{title} = '';
	}
	elsif (get_oidc_implementation_level() >= 3) {
		# The user is signing in: redirect to Keycloak OIDC authentication flow
		if (defined $target_return_url) {
			$request_ref->{return_url} = $target_return_url;
		}
		else {
			delete $request_ref->{return_url};
		}

		write_auth_deprecated_headers();
		access_to_protected_resource($request_ref);
		return 302;
	}
	else {
		# The user is signing in: display the legacy login form
		$template = "sign_in_form";
		$template_data_ref->{redirect} = $target_return_url // $return_url;
		$request_ref->{title} = lang('sign_in');
	}

	process_template("web/pages/session/$template.tt.html", $template_data_ref, \$html)
		or $html = "<p>" . $tt->error() . "</p>";

	$request_ref->{content_ref} = \$html;

	write_auth_deprecated_headers();
	display_page($request_ref);
}
