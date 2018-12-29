#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2018 Association Open Food Facts
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

sub _display_form($$$$) {
	my $challenge = shift;
	my $requested_scope = shift;
	my $user = shift;
	my $client = shift;

	my $html = <<HTML
	<form method="post" action="/cgi/consent.pl">
	<div class="row">
HTML
;

	if ((defined $client->logo_uri) and ($client->logo_uri ne '')) {
		$html .= '<div class="small-12 columns"><img src="' . escapeHTML($client->logo_uri) . '"></div>';
	}

	my $display_client = $client->client_name;
	if ((not defined $display_client) or ($display_client eq '')) {
		$display_client = $client->client_id;
	}

	my $greeting = sprintf('Hi %s application <strong>%s</strong> wants access resources on your behalf and to:', escapeHTML($User_id),  escapeHTML($display_client));
	$html .= '<div class="small-12 columns"><p>' . $greeting . '</p></div>';

	$html .= '<div class="small-12 columns">';
	foreach my $scope (@{$requested_scope}) {
		$html .= <<HTML
		<label>
			<input type="checkbox" id="$scope" name="grant_scope" value="$scope">
			$scope
		</label>
		<br>
HTML
;
	}

	$html .=  '</div>';
	$html .= '<div class="small-12 columns"><p>Do you want to be asked next time when this application wants to access your data? The application will not be able to ask for more permissions without your consent.</p><ul>';

	if (defined $client->policy_url) {
		$html .= <<HTML
		<li>
			<a href="$client->policy_url">Policy</a>
		</li>
HTML
;
	}

	if (defined $client->tos_uri) {
		$html .= <<HTML
		<li>
			<a href="$client->tos_uri">Terms of Service</a>
		</li>
HTML
;
	}

	$html .= <<HTML
	<div class="small-12 columns">
		<label>
			<input type="checkbox" name="remember_me" value="on">
			$Lang{remember_me}{$lc}
		</label>
	</div>
	</div>
	<input type="submit" name="submit" value="$Lang{consent_allow_access}{$lc}" class="button small">
	<input type="submit" name="submit" value="$Lang{consent_deny_access}{$lc}" class="button small">
	<input type="hidden" name="challenge" value="$challenge">
	</form>
HTML
;

	display_new( {
		title => lang('session_title'),
		content_ref => \$html
	});
}

if (not defined $User_id) {
	my $r = shift;
	my $url = format_subdomain($subdomain) . '/cgi/session.pl';
	$r->headers_out->set(Location => $url);
	$r->status(302);
	return 302;
}
elsif ($ENV{'REQUEST_METHOD'} eq 'GET') {
	# The challenge is used to fetch information about the consent request from ORY Hydra.
	my $get_challenge = url_param('consent_challenge');
	if ($get_challenge) {
		$log->info('received consent GET for challenge', { challenge => $get_challenge }) if $log->is_info();
		my $get_consent_response = get_consent_request($get_challenge);
		$log->debug('received consent response for challenge from ORY Hydra', { challenge => $get_challenge, get_consent_response => $get_consent_response }) if $log->is_debug();
		if ($get_consent_response) {
			#  If a user has granted this application the requested scope, hydra will tell us to not show the UI.
			if ($get_consent_response->skip) {
				# We can grant all scopes that have been requested - hydra already checked for us that no additional scopes are requested accidentally.
				$log->info('accepting consent challenge, because ORY Hydra asks us to skip consent', { challenge => $get_challenge }) if $log->is_info();
				my $accept_consent_response = accept_consent_request($get_challenge,
					{
						grant_scope => $get_consent_response->requested_scope,
 						grant_access_token_audience => $get_consent_response->requested_access_token_audience
					});
				$log->debug('received accept consent response for challenge from ORY Hydra', { challenge => $get_challenge, accept_consent_response => $accept_consent_response }) if $log->is_debug();
				if ($accept_consent_response) {
					$log->info('consent accepted by ORY Hydra, redirecting the user to the specified URL', { challenge => $get_challenge, redirect_to => $accept_consent_response->redirect_to }) if $log->is_info();
					my $r = shift;
					$r->headers_out->set(Location => $accept_consent_response->redirect_to);
					$r->status(302);
					return 302;
				}
			}
			else {
				_display_form($get_challenge, \$get_consent_response->requested_scope, $get_consent_response->user, $get_consent_response->client);
			}
		}
	}
}
elsif ($ENV{'REQUEST_METHOD'} eq 'POST') {
	my $post_challenge = param('consent_challenge');
	my $user_action = param('submit');
	my @grant_scope = param('grant_scope');
	$log->info('received consent POST for challenge', { challenge => $post_challenge, user_action => $user_action, grant_scope => \@grant_scope }) if $log->is_info();
	# Let's see if the user decided to accept or reject the consent request..
	if ((not (defined $user_action)) || ($user_action eq 'Deny access'))
	{
		# Looks like the consent request was denied by the user
		$log->info('rejecting consent challenge on behalf of the user', { challenge => $post_challenge }) if $log->is_info();
		my $reject_consent_response = reject_consent_request($post_challenge, {
			error => 'access_denied',
			error_description => 'The resource owner denied the request'
		});
		$log->debug('received reject consent response for challenge from ORY Hydra', { challenge => $post_challenge, reject_consent_response => $reject_consent_response }) if $log->is_debug();
		if ($reject_consent_response) {
			$log->info('rejection accepted by ORY Hydra, redirecting the user to the specified URL', { challenge => $post_challenge, redirect_to => $reject_consent_response->redirect_to }) if $log->is_info();
			my $r = shift;
			$r->headers_out->set(Location => $reject_consent_response->redirect_to);
			$r->status(302);
			return 302;
		}
		else {
			die 'Could not talk to Hydra';
		}
	}

	# If we got to here, then the user was authenticated and selected 0..n scope(s).
	$log->info('received consent POST for challenge', { challenge => $post_challenge }) if $log->is_info();
		my $get_consent_response = get_consent_request($post_challenge);
		$log->debug('received consent response for challenge from ORY Hydra', { challenge => $post_challenge, get_consent_response => $get_consent_response }) if $log->is_debug();
		if ($get_consent_response) {
			$log->info('accepting consent challenge on behalf of the user', { challenge => $post_challenge, grant_scope => \@grant_scope }) if $log->is_info();
			my $remember_me;
			if ((defined param('remember_me')) and (param('remember_me') eq 'on')) {
				$remember_me => $JSON::PP::true;
			}
			else {
				$remember_me => $JSON::PP::false;
			}

			my $accept_consent_response = accept_consent_request($post_challenge, {
				grant_scope => \@grant_scope,
				grant_access_token_audience => $get_consent_response->requested_access_token_audience,
				remember => $remember_me,
				remember_for => 3600
			});
			$log->debug('received accept consent response for challenge from ORY Hydra', { challenge => $post_challenge, accept_consent_response => $accept_consent_response }) if $log->is_debug();
			if ($accept_consent_response) {
				$log->info('accepted consent accepted by ORY Hydra, redirecting the user to the specified URL', { challenge => $post_challenge, redirect_to => $accept_consent_response->redirect_to }) if $log->is_info();
			}
			else {
				die 'Could not talk to Hydra';
			}

			_display_form($post_challenge, \$get_consent_response->requested_scope, $get_consent_response->user, $get_consent_response->client);
		}
		else {
			die 'Could not talk to Hydra';
		}
}
else {
	my $r = shift;
	$r->status(405);
	return 405;
}
