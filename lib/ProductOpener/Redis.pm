
=head1 NAME

ProductOpener::Redis - functions to push information to redis

=head1 DESCRIPTION

C<ProductOpener::Redis> is handling pushing info to Redis
to communicate updates to all services, including search-a-licious.

=cut

package ProductOpener::Redis;

use ProductOpener::Config qw/:all/;
use ProductOpener::PerlStandards;
use Exporter qw< import >;
use Encode;
use JSON::MaybeXS;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&get_rate_limit_user_requests
		&increment_rate_limit_requests
		&push_to_redis_stream
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use Log::Any qw/$log/;
use ProductOpener::Config qw/$redis_url/;
use Redis;

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
		$redis_client = Redis->new(
			server => $redis_url,
			# we don't want to sacrifice too much performance for redis problems
			cnx_timeout => 1,
			write_timeout => 1,
		);
	};
	if ($@) {
		$log->warn("Error connecting to Redis", {error => $@}) if $log->is_warn();
		$redis_client = undef;    # this ask for eventual reconnection
	}
	return;
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
				'product_type', $options{product_type},
				'flavor', $flavor,
				'user_id', Encode::encode_utf8($user_id), 'action', Encode::encode_utf8($action),
				'comment', Encode::encode_utf8($comment), 'diffs', encode_json($diffs)
			);
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
