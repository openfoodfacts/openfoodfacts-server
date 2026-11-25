#!/usr/bin/perl -w

# A session was only removed from the user data when the account opened more than 10 of them:
# signing out expired the cookie, but the same cookie authenticated again because the server side
# entry was still there. A credential change did not remove them either, and nothing shortened the
# life of a stored session.

use ProductOpener::PerlStandards;

use Test2::V0;

use ProductOpener::APITest qw/construct_test_url login new_client wait_application_ready create_user/;
use ProductOpener::Test qw/remove_all_users/;
use ProductOpener::TestDefaults qw/%default_user_form/;
use ProductOpener::Config qw/:all/;
use ProductOpener::Users qw/is_stale_user_session retrieve_user_preferences remove_all_user_sessions/;

# Note: the "tests" user is created in the test environment, we log in as that user. The test must
# not call remove_all_users(), or it would remove the user it needs.
wait_application_ready(__FILE__);
remove_all_users();

my $ua = new_client();

my %create_user_args = (%default_user_form, (email => 'bob@example.com'));
create_user($ua, \%create_user_args);

my $test_user_id = "tests";
my $test_user_password = 'testtest';

# Log in, and keep the session cookie so we can replay it after signing out

my $ua = new_client();
login($ua, $test_user_id, $test_user_password);

my $response = $ua->get(construct_test_url('/cgi/auth.pl'));
is($response->code, 200, "the session authenticates") or diag($response->status_line);

# The session cookie is a CGI cookie holding the session key and the user id, as a flat string
my ($session_cookie_value);
$ua->cookie_jar->scan(
	sub {
		my (undef, $name, $value) = @_;
		$session_cookie_value = $value if $name eq 'session';
	}
);
ok(defined $session_cookie_value, "the login set a session cookie")
	or diag("no session cookie");
# CGI serialises the cookie as name&value pairs joined by &
my ($user_session) = ($session_cookie_value // '') =~ /user_session&([^&]*)/;
ok(defined $user_session, "the session cookie contains a session");

# The session is stored server side

my $user_ref = retrieve_user_preferences($test_user_id);
ok(defined $user_ref, "the user data was loaded");
ok(defined $user_ref->{user_sessions}{$user_session}, "the session is stored for the user");
like($user_ref->{user_sessions}{$user_session}{time}, qr/^\d+$/, "the session has a timestamp");

# Signing out deletes it, and replaying the cookie does not authenticate any more

$response = $ua->post(construct_test_url('/cgi/session.pl'), [length => 'logout']);
$response = $ua->get(construct_test_url('/cgi/auth.pl'));
is($response->code, 403, "the session does not authenticate after signing out");

$user_ref = retrieve_user_preferences($test_user_id);
is($user_ref->{user_sessions}{$user_session}, undef, "the session is not stored any more")
	or diag("the sessions are still: " . join(",", keys %{$user_ref->{user_sessions} // {}}));

# A session that is older than the maximum lifetime is refused

my $now = time();

is(is_stale_user_session({time => $now}), 0, "a session that was just opened is not stale");
is(is_stale_user_session({time => $now - 60}), 0, "a recent session is not stale");
is(is_stale_user_session({time => $now - $options{user_session_max_lifetime} - 60}),
	1, "a session older than the maximum lifetime is stale");
is(is_stale_user_session({time => $now - $options{user_session_max_lifetime} + 60}),
	0, "a session just under the maximum lifetime is not stale");
# A session stored without a timestamp is not refused: it was written before we recorded one
is(is_stale_user_session({}), 0, "a session without a timestamp is not stale");
is(is_stale_user_session(undef), 0, "an undefined session is not stale");

# Changing the password removes every session

$ua = new_client();
login($ua, $test_user_id, $test_user_password);
my ($other_value);
$ua->cookie_jar->scan(
	sub {
		my (undef, $name, $value) = @_;
		$other_value = $value if $name eq 'session';
	}
);
my ($other_session) = ($other_value // '') =~ /user_session&([^&]*)/;
ok(defined $other_session, "the second login set a session");

$user_ref = retrieve_user_preferences($test_user_id);
my $sessions_before = scalar keys %{$user_ref->{user_sessions} // {}};
ok($sessions_before > 0, "at least one session is stored for the user");

is(remove_all_user_sessions($test_user_id), $sessions_before, "every session of the user was removed");

$user_ref = retrieve_user_preferences($test_user_id);
is(scalar keys %{$user_ref->{user_sessions} // {}}, 0, "no session is left for the user");

# A session that was stored before the password change does not authenticate any more
$ua = new_client();
$response
	= $ua->get(construct_test_url('/cgi/auth.pl', 'world') . "?user_session=$other_session&user_id=$test_user_id");
is($response->code, 403, "the removed session does not authenticate");

done_testing();
