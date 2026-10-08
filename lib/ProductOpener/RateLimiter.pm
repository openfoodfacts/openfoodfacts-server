#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2026 Association Open Food Facts
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

package ProductOpener::RateLimiter;

use ProductOpener::PerlStandards;

use Exporter qw< import >;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	require Exporter;
	@ISA = qw(Exporter);
	@EXPORT_OK = qw(
		&account_request_for_rate_limiting
		&move_rate_limit_accounting
		&set_rate_limit_bucket
		&set_rate_limit_attributes
		&check_and_update_rate_limits
	);
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use CGI qw(remote_addr);
use Log::Any qw($log);
use Net::CIDR qw/cidrlookup/;

use ProductOpener::Config qw/:all/;
use ProductOpener::Redis qw/decrement_rate_limit_requests get_rate_limit_user_requests increment_rate_limit_requests/;

our $ratelimiter_log = Log::Any->get_logger(category => 'ratelimiter');

# The rate-limiter counts the requests of each IP address in buckets, one counter per bucket and
# per minute, and sets rate_limiter_blocking when the caller has reached the limit of the bucket.
#
# The accounting is done in ProductOpener::Display::init_request(), which every cgi/*.pl script
# calls, and not only in the request router: the bucket of a route was the only thing that set it,
# and only 5 of the 52 cgi/*.pl scripts go through the router, so the counters did not count
# anything else (the API v0/v2 scripts, the producers platform scripts, the OCR scripts...).
# This module is separate from ProductOpener::Routing because Routing.pm imports Display.pm.

=head2 set_rate_limit_bucket ($request_ref)

Set the rate-limit bucket of the request, and move the accounting to it if the request has already
been accounted for in another bucket (the bucket of a route is set after init_request() has run).

Returns the bucket that is now set.

=cut

sub set_rate_limit_bucket ($request_ref, $bucket) {

	if (    defined $request_ref->{rate_limiter_bucket}
		and ($request_ref->{rate_limiter_bucket} ne $bucket)
		and (defined $request_ref->{rate_limiter_accounted_bucket}))
	{
		# The request was counted in another bucket: move the count, so that the counters of both
		# buckets add up to the number of requests that were made
		my $ip_address = remote_addr();
		decrement_rate_limit_requests($ip_address, $request_ref->{rate_limiter_accounted_bucket});
		increment_rate_limit_requests($ip_address, $bucket);
		$request_ref->{rate_limiter_accounted_bucket} = $bucket;
	}

	$request_ref->{rate_limiter_bucket} = $bucket;

	return $bucket;
}

=head2 set_rate_limit_attributes ($request_ref, $ip)

Set attributes related to rate-limiting in the request object:

- rate_limiter_user_requests: the number of requests performed by the user for the current minute
- rate_limiter_limit: the maximum number of requests allowed for the current minute
- rate_limiter_blocking: 1 if the user has reached the rate-limit, 0 otherwise

=cut

sub set_rate_limit_attributes ($request_ref, $ip) {
	$request_ref->{rate_limiter_user_requests} = undef;
	$request_ref->{rate_limiter_limit} = undef;
	$request_ref->{rate_limiter_blocking} = 0;

	my $rate_limit_bucket = $request_ref->{rate_limiter_bucket};

	if (not defined $rate_limit_bucket) {
		# The request is not rate-limited
		return;
	}
	$request_ref->{rate_limiter_user_requests} = get_rate_limit_user_requests($ip, $rate_limit_bucket);

	my $limit;

	if ($rate_limit_bucket eq "search") {
		$limit = $options{rate_limit_search};
	}
	elsif ($rate_limit_bucket eq "product") {
		$limit = $options{rate_limit_product};
	}
	elsif ($rate_limit_bucket eq "facet_products") {
		if ($request_ref->{is_crawl_bot}) {
			$limit = $options{rate_limit_facet_products_crawl_bot};
		}
		elsif (defined $request_ref->{user_id}) {
			$limit = $options{rate_limit_facet_products_registered};
		}
		else {
			$limit = $options{rate_limit_facet_products_unregistered};
		}
	}
	elsif ($rate_limit_bucket eq "facet_tags") {
		if ($request_ref->{is_crawl_bot}) {
			$limit = $options{rate_limit_facet_tags_crawl_bot};
		}
		elsif (defined $request_ref->{user_id}) {
			$limit = $options{rate_limit_facet_tags_registered};
		}
		else {
			$limit = $options{rate_limit_facet_tags_unregistered};
		}
	}
	else {
		# Every other bucket (the default one, and the ones a route or a script sets) shares the
		# limit of the "other" bucket, which is not set by default: the request is counted, but
		# not blocked, until an operator sets $options{rate_limit_other}
		$limit = $options{rate_limit_other};
	}
	$request_ref->{rate_limiter_limit} = $limit;

	if (
		# if $limit is not defined, the rate-limiter is disabled for this route and/or user
		defined $limit
		and defined $request_ref->{rate_limiter_user_requests}
		and $request_ref->{rate_limiter_user_requests} >= $limit
		)
	{
		my $block_message = "Rate-limiter blocking: the user has reached the rate-limit";
		# Check if rate-limit blocking is enabled
		if ($rate_limiter_blocking_enabled) {
			# Check that the ip is not local (e.g. integration tests)
			if ($ip eq "127.0.0.1") {
				# The IP address is local, we don't block the request
				$block_message
					= "Rate-limiter blocking is disabled for local IP addresses, but the user has reached the rate-limit";
			}
			# Check that the ip is not in the OFF private network
			elsif ($ip =~ /^10\.1\./) {
				# The IP address is in the OFF private network, we don't block the request
				$block_message
					= "Rate-limiter blocking is disabled for the OFF private network, but the user has reached the rate-limit";
			}
			# Check that the IP address is not in the allow list
			elsif (defined $options{rate_limit_allow_list}{$ip}) {
				# The IP address is in the allow list, we don't block the request
				$block_message
					= "Rate-limiter blocking is disabled for the user, but the user has reached the rate-limit";
			}
			else {
				# The user has reached the rate-limit, we block the request
				$request_ref->{rate_limiter_blocking} = 1;

				# Unless the IP is in an allowed block
				if (defined $options{rate_limit_allow_list_blocks}) {
					if (Net::CIDR::cidrlookup($ip, @{$options{rate_limit_allow_list_blocks}})) {
						$request_ref->{rate_limiter_blocking} = 0;
						$block_message
							= "Rate-limiter blocking is disabled for the user, but the user has reached the rate-limit and the IP address is in an allowed block";
					}
				}
			}
		}
		else {
			# Rate-limit blocking is disabled, we just log a warning
			$block_message = "Rate-limiter blocking is disabled, but the user has reached the rate-limit";
		}
		$ratelimiter_log->info(
			$block_message,
			{
				ip => $ip,
				rate_limit_bucket => $rate_limit_bucket,
				user_requests => $request_ref->{rate_limiter_user_requests},
				limit => $limit,
				user_agent => $request_ref->{user_agent},
			}
		) if $ratelimiter_log->is_info();
	}
	return;
}

=head2 account_request_for_rate_limiting($request_ref)

Count the request in the rate-limit bucket of the request, and set the rate-limiter attributes.

A request without a bucket is counted in the "other" bucket: every request is accounted for, and a
route that wants a different bucket sets it afterwards (see set_rate_limit_bucket()).

Returns 1 if the request was counted, 0 if it was not (no-index page, or rate-limiter disabled).

=cut

sub account_request_for_rate_limiting ($request_ref) {

	# There is no need to account a request for a no-index page: it is an empty page returned to
	# known web crawlers
	return 0 if $request_ref->{no_index};

	# Count the request even if it has no bucket, so that no entry point is left unaccounted
	$request_ref->{rate_limiter_bucket} //= "other";

	my $ip_address = remote_addr();

	# Set rate-limiter related request attributes
	set_rate_limit_attributes($request_ref, $ip_address);

	# Increment the number of requests performed by the user for the current minute
	increment_rate_limit_requests($ip_address, $request_ref->{rate_limiter_bucket});
	$request_ref->{rate_limiter_accounted_bucket} = $request_ref->{rate_limiter_bucket};

	return 1;
}

=head2 move_rate_limit_accounting($request_ref)

Keep the rate-limiter attributes in sync after the bucket of the request was changed, so that the
limit that is checked is the one of the new bucket.

=cut

sub move_rate_limit_accounting ($request_ref) {

	# The request has not been accounted for (init_request() was not called, as in the route tests):
	# count it now, in the bucket the route has set
	if (not defined $request_ref->{rate_limiter_accounted_bucket}) {
		account_request_for_rate_limiting($request_ref);
		return;
	}

	# The count has been moved to the new bucket by set_rate_limit_bucket(): only the limit to
	# check changes
	set_rate_limit_attributes($request_ref, remote_addr());
}

=head2 check_and_update_rate_limits($request_ref)

Set the rate-limiter attributes and count the request. Kept as the entry point used by
ProductOpener::Display::init_request() and by cgi/search.pl.

=cut

sub check_and_update_rate_limits($request_ref) {

	account_request_for_rate_limiting($request_ref);
}

1;
