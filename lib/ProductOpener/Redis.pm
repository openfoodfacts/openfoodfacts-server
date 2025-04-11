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
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

=head1 NAME

ProductOpener::Redis - functions to integrate with redis

=head1 DESCRIPTION

C<ProductOpener::Redis> is handling pushing info to Redis
to communicate updates to all services, including search-a-licious,
as well as receiving updates from other services like Keycloak.

=cut

package ProductOpener::Redis;

use ProductOpener::PerlStandards;
use Exporter qw< import >;
use Encode;
use JSON::MaybeXS;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&get_rate_limit_user_requests
		&increment_rate_limit_requests
		&subscribe_to_redis_streams
		&push_to_redis_stream

		&process_xread_stream_reply
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use Log::Any qw/$log/;
use ProductOpener::Config qw/:all/;
use ProductOpener::Minion qw/queue_job/;
use ProductOpener::Users qw/retrieve_user store_user/;
use ProductOpener::Text qw/remove_tags_and_quote/;
use ProductOpener::Store qw/get_string_id_for_lang/;
use AnyEvent;
use AnyEvent::RipeRedis;

=head2 $redis_client

The connection to redis

=cut

my $redis_client;

# tracking if we already displayed a warning
our $sent_warning_about_missing_redis_url = 0;

# Specific logger to track rate-limiter operations
our $ratelimiter_log = Log::Any->get_logger(category => 'ratelimiter');

=head2 init_redis($is_reconnect=0)

init $redis_client or re-init it if we where disconnected

it is uses  ProductOpener::Config2::redis_url

=cut

sub init_redis() {
	$log->debug("init_redis", {redis_url => $redis_url})
		if $log->is_debug();
	eval {
		my ($host, $port) = split /:/, $redis_url;
		$redis_client = AnyEvent::RipeRedis->new(
			host => $host,
			port => $port,
			# we don't want to sacrifice too much performance for redis problems
			cnx_timeout => 1,
			write_timeout => 1,
			on_connect => sub {
				$log->info("Connected to Redis") if $log->is_info();
			},

			on_disconnect => sub {
				$log->info("Disconnected from Redis") if $log->is_info();
			},

			on_error => sub {
				my $err = shift;

				$log->warn("Error from Redis", {error => $err}) if $log->is_warn();
			},
		);
	};
	if ($@) {
		$log->warn("Error connecting to Redis", {error => $@}) if $log->is_warn();
		$redis_client = undef;    # this ask for eventual reconnection
	}
	return;
}

=head2 subscribe_to_redis_streams ()

Subscribe to redis stream to be informed about user deletions.

=cut

sub subscribe_to_redis_streams () {
	if (!$redis_url) {
		# No Redis URL provided, we can't push to Redis
		if (!$sent_warning_about_missing_redis_url) {
			$log->warn("Redis URL not provided for streaming") if $log->is_warn();
			$sent_warning_about_missing_redis_url = 1;
		}
		return;
	}

	if (!defined $redis_client) {
		# we where deconnected, try again
		$log->info("Trying to reconnect to Redis") if $log->is_info();
		init_redis();
	}

	if (!defined $redis_client) {
		$log->warn("Can't connect to Redis") if $log->is_warn();
		return;
	}

	if ($oidc_options{keycloak_level} >= 4) {
		_read_user_streams('$');
	}

	return;
}

sub _read_user_streams($search_from) {
	# Listen for user-deleted events so that we can redact product contributions for this flavor
	my @streams = ('BLOCK', 0, 'STREAMS', 'user-deleted');
	# If this process handles global events then also listen for the user-registered events from Keycloak
	if ($process_global_redis_events) {
		push(@streams, 'user-registered');
		push(@streams, $search_from);
	}
	# Note the message index to search from is provided at the end of the list in the same order as the list of keys
	push(@streams, $search_from);

	$log->info("Reading from Redis", {streams => \@streams}) if $log->is_info();
	$redis_client->xread(
		@streams,
		sub {
			my ($reply_ref, $err) = @_;
			if ($err) {
				$log->warn("Error reading from Redis", {error => $err}) if $log->is_warn();
				return;
			}

			if ($reply_ref) {
				# Process any received messages
				my $last_processed_message_id = process_xread_stream_reply($reply_ref);
				if ($last_processed_message_id) {
					$search_from = $last_processed_message_id;
				}
			}

			# Start listening for the next batch of messages
			_read_user_streams($search_from);
			return;
		}
	);

	return;
}

sub process_xread_stream_reply($reply_ref) {
	my $last_processed_message_id;

	my @streams = @{$reply_ref};
	foreach my $stream_ref (@streams) {
		my @stream = @{$stream_ref};
		if ($stream[0] eq 'user-registered') {
			$last_processed_message_id = _process_registered_users_stream($stream[1]);
		}
		elsif ($stream[0] eq 'user-deleted') {
			$last_processed_message_id = _process_deleted_users_stream($stream[1]);
		}

	}

	return $last_processed_message_id,;
}

sub _process_registered_users_stream($stream_values_ref) {
	my $last_processed_message_id;

	foreach my $outer_ref (@{$stream_values_ref}) {
		my @outer = @{$outer_ref};
		my $message_id = $outer[0];
		my @values = @{$outer[1]};

		my %message_hash;
		for (my $i = 0; $i < scalar(@values); $i += 2) {
			my $key = $values[$i];
			my $value = $values[$i + 1];
			$message_hash{$key} = $value;
		}

		my $user_id = $message_hash{'userName'};
		my $newsletter = $message_hash{'newsletter'};
		my $requested_org = $message_hash{'requestedOrg'};
		my $email = $message_hash{'email'};
		my $clientId = $message_hash{'clientId'};

		$log->info("User registered", {user_id => $user_id, newsletter => $newsletter})
			if $log->is_info();

		# Create the user if they don't exist and set the properties
		my $user_ref = retrieve_user($user_id);
		unless ($user_ref) {
			# This doesn't set registered_t and other fields,
			# these are updated in Auth.pm when the user is redirected back to PO
			$user_ref = {
				userid => $user_id,
				name => $user_id
			};
		}
		$user_ref->{email} = $email;
		if (defined $requested_org) {
			$user_ref->{requested_org} = remove_tags_and_quote(decode utf8 => $requested_org);

			my $requested_org_id = get_string_id_for_lang("no_language", $user_ref->{requested_org});

			if ($requested_org_id ne "") {
				$user_ref->{requested_org_id} = $requested_org_id;
				$user_ref->{pro} = 1;
			}
		}
		store_user($user_ref);

		my $args_ref = {userid => $user_id};

		if (not defined $clientId or $clientId ne 'OFF_PRO') {
			# Don't send normal welcome email for users that sign-up via the pro platform
			queue_job(welcome_user => [$args_ref] => {queue => $server_options{minion_local_queue}});
		}

		# Subscribe to newsletter
		if (defined $newsletter and $newsletter eq 'subscribe') {
			queue_job(subscribe_user_newsletter => [$args_ref] => {queue => $server_options{minion_local_queue}});
		}

		# Register interest in joining an organization
		if (defined $requested_org) {
			queue_job(process_user_requested_org => [$args_ref] => {queue => $server_options{minion_local_queue}});
		}

		$last_processed_message_id = $message_id;
	}

	return $last_processed_message_id;
}

sub _process_deleted_users_stream($stream_values_ref) {
	my $last_processed_message_id;

	foreach my $outer_ref (@{$stream_values_ref}) {
		my @outer = @{$outer_ref};
		my $message_id = $outer[0];
		my @values = @{$outer[1]};

		my %message_hash;
		for (my $i = 0; $i < scalar(@values); $i += 2) {
			my $key = $values[$i];
			my $value = $values[$i + 1];
			$message_hash{$key} = $value;
		}

		$log->info("User deleted", {user_id => $message_hash{'userName'}}) if $log->is_info();

		my $args_ref = {
			userid => $message_hash{'userName'},
			newuserid => $message_hash{'newUserName'}
		};
		queue_job(delete_user => [$args_ref] => {queue => $server_options{minion_local_queue}});

		$last_processed_message_id = $message_id;
	}

	return $last_processed_message_id;
}

=head2 push_to_redis_stream ($user_id, $product_ref, $action, $comment, $diffs)

Add an event to Redis stream to inform that a product was updated.

=head3 Arguments

=head4 String $user_id

The user that updated the product.

=head4 Product Object $product_ref

The product that was updated.

=head4 String $action

The action that was performed on the product (either "updated" or "deleted").
A product creation is considered as an update.

=head4 String $comment

The user comment associated with the update.

=head4 HashRef $diffs

a hashref of the differences between the previous and new revision of the product.

=cut

sub push_to_redis_stream ($user_id, $product_ref, $action, $comment, $diffs, $timestamp = time()) {

	if (!$redis_url) {
		# No Redis URL provided, we can't push to Redis
		if (!$sent_warning_about_missing_redis_url) {
			$log->warn("Redis URL not provided for streaming") if $log->is_warn();
			$sent_warning_about_missing_redis_url = 1;
		}
		return;
	}

	my $error = "";
	if (!defined $redis_client) {
		# we were disconnected, try again
		$log->debug("Trying to reconnect to Redis") if $log->is_debug();
		init_redis();
	}
	if (defined $redis_client) {
		$log->debug("Pushing product update to Redis", {product_code => $product_ref->{code}}) if $log->is_debug();
		eval {
			my $cv = AE::cv;
			$redis_client->xadd(
				# name of the Redis stream
				$options{redis_stream_name},
				# We do not add a MAXLEN
				'MAXLEN', '~', '10000000',
				# We let Redis generate the id
				'*',
				# fields
				'timestamp', $timestamp,
				'code', Encode::encode_utf8($product_ref->{code}),
				'rev', Encode::encode_utf8($product_ref->{rev}),
				# product_type should be used over flavor (kept for backward compatibility)
				'product_type',
				$options{product_type},
				'flavor', $flavor,
				'user_id',
				Encode::encode_utf8($user_id),
				'action',
				Encode::encode_utf8($action),
				'comment',
				Encode::encode_utf8($comment),
				'diffs',
				encode_json($diffs),
				sub {
					my ($reply, $err) = @_;
					if (defined $err) {
						$log->warn("Error adding data to stream", {error => $err}) if $log->is_warn();
					}
					else {
						$log->info("Data added to stream with ID", {reply => $reply}) if $log->is_info();
					}

					$cv->send;
					return;
				}
			);
			$cv->recv;
		};
		$error = $@;
	}
	else {
		$error = "Can't connect to Redis";
	}
	if (!($error eq "")) {
		$log->error("Failed to push product update to Redis", {product_code => $product_ref->{code}, error => $error})
			if $log->is_warn();
		# ask for eventual reconnection for next call
		$redis_client = undef;
	}
	else {
		$log->debug("Successfully pushed product update to Redis", {product_code => $product_ref->{code}})
			if $log->is_debug();
	}

	return;
}

=head2 get_rate_limit_user_requests ($ip, $bucket)

Return the number of requests performed by the given user for the current minute for the given rate-limit bucket.
See https://redis.com/glossary/rate-limiting/ for more information.

If the rate-limiter is not configured or if an error occurs, returns undef.

=head3 Arguments

=head4 String $ip

The IP address of the user who is making the request.

=head4 String $bucket

The rate-limit bucket that is being requested.

=cut

sub get_rate_limit_user_requests ($ip, $bucket) {
	if (!$redis_url) {
		# No Redis URL provided, we can't get the remaining number of requests
		if (!$sent_warning_about_missing_redis_url) {
			$ratelimiter_log->warn("Redis URL not provided, rate-limiting is disabled") if $ratelimiter_log->is_warn();
			$sent_warning_about_missing_redis_url = 1;
		}
		return;
	}

	my $error = "";
	if (!defined $redis_client) {
		# we were disconnected, try again
		$ratelimiter_log->debug("Trying to reconnect to Redis") if $ratelimiter_log->is_debug();
		init_redis();
	}
	my $resp;
	if (defined $redis_client) {
		$ratelimiter_log->debug("Getting rate-limit user requests", {ip => $ip, bucket => $bucket})
			if $ratelimiter_log->is_debug();
		my $current_minute = int(time() / 60);
		eval {$resp = $redis_client->get("po-rate-limit:$ip:$bucket:$current_minute");};
		$error = $@;
	}
	else {
		$error = "Can't connect to Redis";
	}
	if (!($error eq "")) {
		$ratelimiter_log->error("Failed to get number of user requests logged by Redis rate-limiter", {error => $error})
			if $ratelimiter_log->is_warn();
		# ask for eventual reconnection for next call
		$redis_client = undef;
	}
	else {
		if (defined $resp) {
			$resp = int($resp);
		}
		else {
			$resp = 0;
		}
		$ratelimiter_log->debug("Number of user requests logged by Redis rate-limiter", {requests => $resp})
			if $ratelimiter_log->is_debug();
		return $resp;
	}

	return;
}

=head2 increment_rate_limit_requests ($ip, $bucket)

Increment the number of requests according to the Redis rate-limiter for the current minute for the given user and bucket.
The expiration of the counter is set to 59 seconds.
See https://redis.com/glossary/rate-limiting/ for more information.

=head3 Arguments

=head4 String $ip

The IP address of the user who is making the request.

=head4 String $bucket

The rate-limit bucket that is being requested.

=cut

sub increment_rate_limit_requests ($ip, $bucket) {
	if (!$redis_url) {
		# No Redis URL provided, we can't increment the number of requests
		if (!$sent_warning_about_missing_redis_url) {
			$ratelimiter_log->warn("Redis URL not provided, rate-limiting is disabled") if $ratelimiter_log->is_warn();
			$sent_warning_about_missing_redis_url = 1;
		}
		return;
	}

	my $error = "";
	if (!defined $redis_client) {
		# we were disconnected, try again
		$ratelimiter_log->debug("Trying to reconnect to Redis") if $ratelimiter_log->is_debug();
		init_redis();
	}
	if (defined $redis_client) {
		$ratelimiter_log->debug("Incrementing rate-limit requests", {ip => $ip, bucket => $bucket})
			if $ratelimiter_log->is_debug();
		my $current_minute = int(time() / 60);
		eval {
			# Use a MULTI/EXEC block to increment the counter and set the expiration atomically
			$redis_client->multi();
			$redis_client->incr("po-rate-limit:$ip:$bucket:$current_minute");
			$redis_client->expire("po-rate-limit:$ip:$bucket:$current_minute", 59);
			$redis_client->exec();
		};
		$error = $@;
	}
	else {
		$error = "Can't connect to Redis";
	}
	if (!($error eq "")) {
		$ratelimiter_log->error("Failed to increment number of requests from Redis rate-limiter", {error => $error})
			if $ratelimiter_log->is_error();
		# ask for eventual reconnection for next call
		$redis_client = undef;
	}
	else {
		$ratelimiter_log->debug("Incremented number of requests from Redis rate-limiter",
			{ip => $ip, bucket => $bucket})
			if $ratelimiter_log->is_debug();
	}

	return;

}

1;
