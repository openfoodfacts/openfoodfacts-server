
=head1 NAME

ProductOpener::Redis - functions to integrate with redis

=head1 DESCRIPTION

C<ProductOpener::Redis> is handling pushing info to Redis
to communicate updates to all services, including search-a-licious,
as well as receiving updates from other services like Keycloak.

=cut

package ProductOpener::Redis;

use ProductOpener::Config qw/:all/;
use ProductOpener::PerlStandards;
use Exporter qw< import >;
use Encode;
use JSON::PP;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&subscribe_to_redis_streams
		&push_to_redis_stream
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use Log::Any qw/$log/;
use ProductOpener::Config qw/$redis_url/;
use AnyEvent;
use AnyEvent::RipeRedis;

=head2 $redis_client
The connection to redis
=cut

my $redis_client;

# tracking if we already displayed a warning
my $sent_warning_about_missing_redis_url = 0;

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

	_read_user_deleted_stream('$');

	return;
}

sub _read_user_deleted_stream($search_from) {
	$log->info("Reading from Redis", {stream => 'user-deleted', search_from => $search_from}) if $log->is_info();
	$redis_client->xread(
		'BLOCK' => 0,
		'STREAMS' => 'user-deleted',
		$search_from,
		sub {
			my ($reply, $err) = @_;
			if ($err) {
				$log->warn("Error reading from Redis", {error => $err}) if $log->is_warn();
				return;
			}

			if ($reply) {
				# TODO: The message should be updated to be real JSON string in openfoodfacts-auth. Then, modify this to parse the JSON.
				# $search_from = $message_id;
			}

			_read_user_deleted_stream($search_from);
			return;
		}
	);

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

sub push_to_redis_stream ($user_id, $product_ref, $action, $comment, $diffs) {

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
		# we where deconnected, try again
		$log->info("Trying to reconnect to Redis");
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
				'code',
				Encode::encode_utf8($product_ref->{code}),
				'flavor',
				Encode::encode_utf8($options{current_server}),
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

1;
