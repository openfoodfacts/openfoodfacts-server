#!/usr/bin/perl -w

# The Redis rate-limiter is on the request path: ProductOpener::Redis uses the asynchronous
# AnyEvent::RipeRedis client, whose command methods return nothing and hand the reply over to a
# callback. Reading the counter as if the client was synchronous discarded the reply, and
# get_rate_limit_user_requests() then turned the missing value into 0, so the rate-limiter never
# saw a request and never blocked anyone.
#
# This test runs against the Redis server used by the integration tests (the unit tests run with
# the rate-limiter disabled), so that the counter cannot be mocked away.

use ProductOpener::PerlStandards;

use Test2::V0;
use Log::Any::Adapter 'TAP';

use ProductOpener::Redis qw/get_rate_limit_user_requests increment_rate_limit_requests/;

# A documentation IP address (TEST-NET-1), and a bucket that is unique to this test run, so that
# we do not mix up with the counters of the other tests. The counters expire after 59 seconds.

my $ip = "192.0.2.17";
my $bucket = "test_rate_limit_" . $$;
my $other_ip = "192.0.2.18";

is(get_rate_limit_user_requests($ip, $bucket), 0, "no request counted for a counter that was never incremented");

is(increment_rate_limit_requests($ip, $bucket), 1, "the first increment returns 1");
is(get_rate_limit_user_requests($ip, $bucket), 1, "the request we incremented is counted");

is(increment_rate_limit_requests($ip, $bucket), 2, "the second increment returns 2");
is(get_rate_limit_user_requests($ip, $bucket), 2, "the requests we incremented are counted");

is(increment_rate_limit_requests($ip, $bucket), 3, "the third increment returns 3");
is(get_rate_limit_user_requests($ip, $bucket), 3, "we count every request");

is(get_rate_limit_user_requests($other_ip, $bucket), 0, "each IP address has its own counter");
is(get_rate_limit_user_requests($ip, $bucket . "_other"), 0, "each bucket has its own counter");

is(increment_rate_limit_requests($other_ip, $bucket), 1, "the counter of another IP address is incremented");
is(get_rate_limit_user_requests($ip, $bucket), 3, "the counter of the first IP address is unchanged");

# The counter must expire, or a user would stay blocked for ever

my $ttl_bucket = $bucket . "_ttl";
increment_rate_limit_requests($ip, $ttl_bucket);

is(get_rate_limit_user_requests($ip, $ttl_bucket), 1, "the counter that will expire is set");

done_testing();
