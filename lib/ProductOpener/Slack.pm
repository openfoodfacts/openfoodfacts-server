# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2025 Association Open Food Facts
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

=head1 NAME

ProductOpener::Slack - Interact with the Slack API

=head1 SYNOPSIS

C<ProductOpener::Slack> is used to call the Slack API to send messages to a Slack channel.

    use ProductOpener::Slack qw/send_slack_message/;

    send_slack_message(
        channel => $slack_channel,
        username => $slack_username,
        text => $slack_text,
        icon_emoji => $slack_icon_emoji,
    );

=cut

package ProductOpener::Slack;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&send_slack_message
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::ConfigEnv qw/%slack_hook_urls/;

use CGI qw/:cgi :form escapeHTML/;
use Encode;
use JSON::MaybeXS;
use Log::Any qw($log);

use LWP::UserAgent;

=head1 FUNCTIONS

=head2 send_slack_message ($channel, $username, $text, $icon_emoji)

C<send_slack_message()> sends a message to a Slack channel.

=head3 returns - 1 if the message was sent successfully, 0 otherwise

=cut

sub send_slack_message ($channel, $username, $text, $icon_emoji) {
	if (not defined $slack_hook_urls{$channel} or $slack_hook_urls{$channel} eq '') {
		$log->warn('Slack webhook URL is not defined the channel, cannot send message to Slack', {channel => $channel})
			if $log->is_warn();
		return;
	}

	my $ua = LWP::UserAgent->new;
	my $req = HTTP::Request->new(POST => $slack_hook_urls{$channel});
	$req->header('Content-Type' => 'application/json');

	my $post_data = {
		channel => $channel,
		username => $username,
		text => $text,
		icon_emoji => $icon_emoji,
	};
	$req->content(encode_json($post_data));

	my $resp = $ua->request($req);
	if ($resp->is_success) {
		my $message = $resp->decoded_content;
		$log->debug('Message sent successfully', {reply => $message}) if $log->is_debug();
		return 1;
	}
	else {
		$log->info('HTTP error while posting message to Slack', {code => $resp, message => $resp->message})
			if $log->is_info();
		return 0;
	}
}

1;
