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

use Modern::Perl '2012';
use utf8;

use CGI::Carp qw(fatalsToBrowser);

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Hydra qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;
use Log::Any qw($log);

ProductOpener::Display::init();
use ProductOpener::Lang qw/:all/;

sub _display_form($) {
	my $challenge = shift;

	my $html = <<HTML
	<p>$Lang{login_to_add_and_edit_products}{$lc}</p>

	<form method="post" action="/cgi/login.pl">
	<div class="row">
	<div class="small-12 columns">
		<label>$Lang{login_username_email}{$lc}
			<input type="text" name="user_id" autocomplete="username">
		</label>
	</div>
	<div class="small-12 columns">
		<label>$Lang{password}{$lc}
			<input type="password" name="password" autocomplete="current-password">
		</label>
	</div>
	<div class="small-12 columns">
		<label>
			<input type="checkbox" name="remember_me" value="on">
			$Lang{remember_me}{$lc}
		</label>
	</div>
	</div>
	<input type="submit" name=".submit" value="$Lang{login_register_title}{$lc}" class="button small">
	<input type="hidden" name="login_challenge" value="$challenge">
	</form>

HTML
;

	display_new( {
		title => lang('session_title'),
		content_ref => \$html
	});
}

if ($ENV{'REQUEST_METHOD'} eq 'GET') {
	# The challenge is used to fetch information about the login request from ORY Hydra.
	my $get_challenge = url_param('login_challenge');
	if ($get_challenge) {
		$log->info('received login GET for challenge', { challenge => $get_challenge }) if $log->is_info();
		my $get_login_response = get_login_request($get_challenge);
		$log->debug('received login response for challenge from ORY Hydra', { challenge => $get_challenge, get_login_response => $get_login_response }) if $log->is_debug();
		if ($get_login_response) {
			#  If hydra was already able to authenticate the user, skip will be true and we do not need to re-authenticate the user.
			if ($get_login_response->{skip}) {
				$log->info('accepting login challenge, because ORY Hydra asks us to skip login', { challenge => $get_challenge }) if $log->is_info();
				my $accept_login_response = accept_login_request($get_challenge, { subject => $get_login_response->{subject} });
				$log->debug('received accept login response for challenge from ORY Hydra', { challenge => $get_challenge, accept_login_response => $accept_login_response }) if $log->is_debug();
				if ($accept_login_response) {
					$log->info('login accepted by ORY Hydra, redirecting the user to the specified URL', { challenge => $get_challenge, redirect_to => $accept_login_response->{redirect_to} }) if $log->is_info();
					my $r = shift;
					$r->headers_out->set(Location => $accept_login_response->{redirect_to});
					$r->status(302);
					return 302;
				}
				else {
					die 'Could not talk to Hydra';
				}
			}
		}
	}

	_display_form($get_challenge);
}
elsif ($ENV{'REQUEST_METHOD'} eq 'POST') {
	my $post_challenge = param('login_challenge');
	$log->info('received login POST for challenge', { challenge => $post_challenge }) if $log->is_info();
	if (defined $User_id) { # Automagically set by ProductOpener::Users::init_user() through ProductOpener::Display::init()
		my $remember_me;
		if ((defined param('remember_me')) and (param('remember_me') eq 'on')) {
			$remember_me => $JSON::PP::true;
		}
		else {
			$remember_me => $JSON::PP::false;
		}

		$log->info('accepting login challenge, because ORY Hydra we have a user ID', { challenge => $post_challenge, user_id => $User_id }) if $log->is_info();
		my $accept_login_response = accept_login_request($post_challenge, { subject => $User_id, remember => $remember_me, remember_for => 3600 });
		$log->debug('received accept login response for challenge from ORY Hydra', { challenge => $post_challenge, accept_login_response => $accept_login_response }) if $log->is_debug();
		if ($accept_login_response) {
			$log->info('login accepted by ORY Hydra, redirecting the user to the specified URL:', { challenge => $post_challenge, redirect_to => $accept_login_response->{redirect_to} }) if $log->is_info();
			my $r = shift;
			$r->err_headers_out->add('Set-Cookie' => $cookie);
			$r->headers_out->set(Location => $accept_login_response->{redirect_to});
			$r->status(302);
			return 302;
		}
		else {
			die 'Could not talk to Hydra';
		}
	}

	_display_form($post_challenge);
}
else {
	my $r = shift;
	$r->status(405);
	return 405;
}

