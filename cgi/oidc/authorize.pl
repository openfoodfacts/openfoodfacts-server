#!/usr/bin/perl -W

# This file is part of Product Opener.
# 
# Product Opener
# Copyright (C) 2011-2016 Association Open Food Facts
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
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

use CGI::Carp qw(fatalsToBrowser);

use strict;
use warnings;
use utf8;

use ProductOpener::Config qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Lang qw/:all/;

use Apache2::RequestRec ();
use Apache2::Const ();

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;

use OAuth::Lite2::Util qw/build_content/;
use ProductOpener::OIDC::Server::Request;
use ProductOpener::OIDC::Server::DataHandler;
use ProductOpener::OIDC::Server::Web::M::ResourceOwner;
use OIDC::Lite::Server::AuthorizationHandler;
use OIDC::Lite::Server::Scope;
use OIDC::Lite::Model::IDToken;

ProductOpener::Display::init();

my $RESPONSE_TYPES = [
	q{code}, q{id_token}, q{token},
	q{code id_token}, q{code token}, q{id_token token},
	q{code id_token token}
];

my $request = Apache2::RequestUtil->request();
my $method = $request->method();

my $title = 'OpenFoodFacts OpenID Connect';
my $html = '';
my $status = undef;

if ($method eq 'GET') {
	if ((not $User_id) or ($User_id eq 'unwanted-bot-id')) {
		($html, $status) = _add_login();
	}
	else {
		($html, $status) = _show_authorize();
	}
}
elsif ($method eq 'POST') {
	if ((not $User_id) or ($User_id eq 'unwanted-bot-id')) {
		($html, $status) = _add_login();
	}
	else {
		($html, $status) = _redirect();
	}
}
else {
	print header ( -status => '405 Method Not Allowed' );
	print header ( -allow => 'GET, POST' );
	exit(0);
}

display_new( {
	title => $title,
	content_ref => \$html,
	status => $status,
	full_width => 1,
});
exit(0);

sub _add_login() {

		my $status = '401 Unauthorized';

		my $html = <<HTML
<form method="post" action="/cgi/session.pl">
<div class="row">
<div class="small-12 columns">
	<label>$Lang{login_username_email}{$lc}
		<input type="text" name="user_id" />
	</label>
</div>
<div class="small-12 columns">
	<label>$Lang{password}{$lc}
		<input type="password" name="password" />
	</label>
</div>
<div class="small-12 columns">
	<label>
		<input type="checkbox" name="remember_me" value="on" />
		$Lang{remember_me}{$lc}
	</label>
</div>
</div>
<input type="submit" name=".submit" value="$Lang{login_register_title}{$lc}" class="button small" />
</form>

HTML
;

	return ($html, $status);
}

sub _show_authorize() {

	my $request_uri = $request->uri;
	my $dh = ProductOpener::OIDC::Server::DataHandler->new(
		request => ProductOpener::OIDC::Server::Request->new(),
	);
	my $ah = OIDC::Lite::Server::AuthorizationHandler->new(
		data_handler => $dh,
		response_types => $RESPONSE_TYPES,
	);

	eval {
		$ah->handle_request();
	};
	my $error;
	my $client_info = $dh->get_client_info();
	if ($error = $@) {
		my $html =_render_authorize({
				status => $error,
				request_uri => $request_uri,
				client_info => $client_info,
		});
		return ($html, undef);
	}

	# create array ref of returned user claims for display
	my $resource_owner_id = $dh->get_user_id_for_authorization;
	my @scopes = split(/\s/, url_param('scope'));
	my $claims = _get_resource_owner_claims($resource_owner_id, @scopes);

	# confirm screen
	my $html = _render_authorize({
			status => q{valid},
			scopes => \@scopes,
			request_uri => $request_uri,
			client_info => $client_info,
			claims => $claims,
	});

	return ($html, undef);

}

sub _redirect() {

	my $request_uri = $request->uri;
	my $dh = ProductOpener::OIDC::Server::DataHandler->new(
		request => ProductOpener::OIDC::Server::Request->new(),
	);
	my $ah = OIDC::Lite::Server::AuthorizationHandler->new(
		data_handler => $dh,
		response_types => $RESPONSE_TYPES,
	);

	my $res;
	eval {
		$ah->handle_request();
		if (param('user_action')) { # TODO: CSRF
			if( param('user_action') eq q{accept} ){
				$res = $ah->allow();		
			}else{
				$res = $ah->deny();
			}
		}else{
			return _show_authorize();
		}
	};
	my $error;
	my $client_info = $dh->get_client_info();
	if ($error = $@) {
		my $html =_render_authorize({
				status => $error,
				request_uri => $request_uri,
				client_info => $client_info,
		});
		return ($html, undef);
	}

	# create array ref of returned user claims for display
	my $resource_owner_id = $dh->get_user_id_for_authorization;
	my @scopes = split(/\s/, url_param('scope'));
	my $claims = _get_resource_owner_claims($resource_owner_id, @scopes);

	$res->{query_string} = build_content($res->{query});
	$res->{fragment_string} = build_content($res->{fragment});
	$res->{uri} = $res->{redirect_uri};
	if ($res->{query_string}) {
		$res->{uri} .= ($res->{uri} =~ /\?/) ? q{&} : q{?};
		$res->{uri} .= $res->{query_string};
	}
	if ($res->{fragment_string}) {
		$res->{uri} .= q{#}.$res->{fragment_string};
	}

	# confirm screen
	print header ( -location => $res->{uri} );
	return ('valid', 302);

}

sub _get_resource_owner_claims {
	my ($class, $resource_owner_id, @scopes) = @_;

	my $resource_owner_info = 
		ProductOpener::OIDC::Server::Web::M::ResourceOwner->find_by_id($resource_owner_id);
	my $requested_claims = OIDC::Lite::Server::Scope->to_normal_claims(\@scopes);
	my @claims;
	foreach my $claim (@{$requested_claims}) {
		if ($claim eq q{address}) {
			push (@claims, "$claim : ". encode_json($resource_owner_info->{$claim}));
		} else {
			push (@claims, "$claim : $resource_owner_info->{$claim}");
		}
	}
	return \@claims;
}

sub _render_authorize($) {

	my (%data) = @_;

	my $html = '<h2>Authorization Endpoint (Confirm)</h2>';
	if ($data{status} and $data{status} ne q{valid}) {
		$html .= '<div data-alert class="alert-box warning radius">' . $data{status} . '</div>';
	}
	
	if ($data{scopes}) {
		$html .= 'This client would to access your claims by following scopes.<ul>';
		for my $scope (%data{scopes}) {
			$html .= '<li>' . $scope . '</li>';
		}

		$html .= '</ul>';
	}

	$html .= start_form()
	. '<input class="alter button" type="submit" name="user_action" value="cancel">'
	. '<input class="success button" type="submit" name="user_action" value="accept">'
# TODO: CSRF
	. end_form();

	return $html;

}
