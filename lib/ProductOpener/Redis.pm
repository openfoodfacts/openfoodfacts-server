
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
use JSON::PP;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
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
my $sent_warning_about_missing_redis_url = 0;

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

sub push_to_redis_stream ($user_id, $product_ref, $action, $comment, $diffs) {

	if (!$redis_url) {
		# off search not activated
		if (!$sent_warning_about_missing_redis_url) {
			$log->warn("Redis URL not provided for search indexing") if $log->is_warn();
			$sent_warning_about_missing_redis_url = 1;
		}
		return;
	}

	my $error = "";
	if (!defined $redis_client) {
		# we where deconnected, try again
		$log->info("Trying to reconnect to redis");
		init_redis();
	}
	if (defined $redis_client) {
		$log->debug("Pushing to redis", {product_code => $product_ref->{code}}) if $log->is_debug();
		eval {
			$redis_client->xadd(
				# name of the Redis stream
				'product_update',
				# Only keep approximately 10000 events
				'MAXLEN', '~', '10000',
				# We let Redis generate the id
				'*',
				# fields
				'code', $product_ref->{code},
				'flavor', $options{current_server},
				'user_id', $user_id, 'action', $action,
				'comment', $comment, 'diffs', encode_json($diffs)
			);
		};
		$error = $@;
	}
	else {
		$error = "Can't connect to redis";
	}
	if (!($error eq "")) {
		$log->error("Failed to push to redis", {product_code => $product_ref->{code}, error => $error})
			if $log->is_warn();
		# ask for eventual reconnection for next call
		$redis_client = undef;
	}

	return;
}

1;
