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
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Mail qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::Images qw/:all/;

use Apache2::RequestRec ();
use Apache2::Const ();

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;

use OAuth::Lite2::Util qw(encode_param decode_param build_content);

ProductOpener::Display::init();

try {
my $r = shift;
my $header = $r->headers_in->get('Authentication');
if (!$header) {
	# 401?
}

# https://github.com/lyokato/p5-oauth-lite2/blob/master/lib/OAuth/Lite2/ParamMethod/AuthHeader.pm
$header =~ s/^\s*(Bearer)\s+([^\s\,]*)//;
my $token = $2;
my $params = Hash::MultiValue->new;
$header =~ s/^\s*(Bearer)\s*([^\s\,]*)//;

if ($header) {
	$header =~ s/^\s*\,\s*//;
	for my $attr (split /,\s*/, $header) {
		my ($key, $val) = split /=/, $attr, 2;
		$val =~ s/^"//;
		$val =~ s/"$//;
		$params->add($key, decode_param($val));
	}
}

# https://github.com/ritou/p5-oidc-lite/blob/master/lib/Plack/Middleware/Auth/OIDC/ProtectedResource.pm
OAuth::Lite2::Server::Error::InvalidRequest->throw unless $token;

my $dh = ProductOpener::OIDC::Server::DataHandler->new();
my $access_token = $dh->get_access_token($token);

OAuth::Lite2::Server::Error::InvalidToken->throw unless $access_token;

Carp::croak "OIDC::Lite::Server::DataHandler::get_access_token doesn't return OAuth::Lite2::Model::AccessToken" unless $access_token->isa("OAuth::Lite2::Model::AccessToken");

unless ($access_token->created_on + $access_token->expires_in > time()) {
	OAuth::Lite2::Server::Error::ExpiredToken->throw;
}

my $auth_info = $dh->get_auth_info_by_id($access_token->auth_id);
OAuth::Lite2::Server::Error::InvalidToken->throw unless $auth_info;
Carp::croak "OIDC::Lite::Server::DataHandler::get_auth_info_by_id doesn't return OIDC::Lite::Model::AuthInfo" unless $auth_info->isa("OIDC::Lite::Model::AuthInfo");

$dh->validate_client_by_id($auth_info->client_id) or OAuth::Lite2::Server::Error::InvalidToken->throw;

$dh->validate_user_by_id($auth_info->user_id) or OAuth::Lite2::Server::Error::InvalidToken->throw;

my $domain = 'accounts.' . $server_domain;
my $uri = 'https://' . $domain;

my %result = (

	iss => $uri,
	authorization_endpoint => $uri . '/cgi/oidc/authorize.pl',
	token_endpoint => $uri . '/cgi/oidc/token.pl',
	userinfo_endpoint => $uri . '/cgi/oidc/userinfo.pl',
	jwks_uri => $uri . '/cgi/oidc/jwks.pl',
	scopes_supported => [ 'openid', 'profile', 'email', 'api' ],
	subject_types_supported => [ 'public' ],
	token_endpoint_auth_methods_supported => [ 'client_secret_basic' ],
	response_modes_supported => [ 'query', 'fragment' ],

);

my $data =  encode_json(\%result);
	
print "Content-Type: application/json; charset=UTF-8\r\nAccess-Control-Allow-Origin: *\r\n\r\n" . $data;
return;
}
catch {
if ($_->isa("OAuth::Lite2::Server::Error")) {
	my @params;
	push(@params, sprintf(q{error="%s"}, $_->type));
	push(@params, sprintf(q{error_description="%s"}, $_->description)) if $_->description;
	return [ $_->code, [ "WWW-Authenticate" => "Bearer " . join(', ', @params) ], [  ] ];

} else {
	# rethrow
	die $_;
}
}
