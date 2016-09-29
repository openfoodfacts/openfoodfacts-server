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
use Encode;

use ProductOpener::OIDC::Server;
use ProductOpener::OIDC::Server::Web::M::Client;

my $c = ProductOpener::OIDC::Server->new;

ProductOpener::Display::init();

my $RESPONSE_TYPES = [
	q{code}, q{id_token}, q{token},
	q{code id_token}, q{code token}, q{id_token token},
	q{code id_token token}
];

my $request = Apache2::RequestUtil->request();
my $method = $request->method();

my $title = 'OpenFoodFacts OpenID Clients';
my $html = '';
my $status = undef;

if ($method eq 'GET') {
	if ((not $User_id) or ($User_id eq 'unwanted-bot-id')) {
		($html, $status) = _add_login();
	}
	elsif (not $admin) {
		display_error($Lang{error_no_permission}{$lang}, 403);
		exit(0);
	}
	elsif (not param('id')) {
		($html, $status) = _show_list();
	}
	else {
		($html, $status) = _show_client(param('id'));
	}
}
elsif ($method eq 'POST') {
	if ((not $User_id) or ($User_id eq 'unwanted-bot-id')) {
		($html, $status) = _add_login();
	}
	elsif (not $admin) {
		display_error($Lang{error_no_permission}{$lang}, 403);
		exit(0);
	}
	elsif (not param('id')) {
		print header ( -status => '302 Moved Temporarily' );
		print header ( -location => '/cgi/oidc/clients.pl' );
		exit();
	}
	else {
		($html, $status) = _update_client(param('id'));
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

sub _show_list {

	my $html = '';
	my $clients = ProductOpener::OIDC::Server::Web::M::Client->find_all($c->clients);

use Data::Dumper;
	for my $client ($clients) {
		$html .= Dumper($client);
	}

	return ($html, undef);

}

sub _show_client {

	my ($client) = @_;

	return ('show client ' + $client, undef);

}

sub _update_client {

	my ($client) = @_;

	return ('update client ' + $client, undef);

}

