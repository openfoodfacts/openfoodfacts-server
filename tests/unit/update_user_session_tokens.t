#!/usr/bin/perl -w

# update_user_session_tokens() persists rotated OIDC tokens on an existing PO session
# after refresh_access_token() (openfoodfacts-auth#459).

use ProductOpener::PerlStandards;

use Test2::V0;

use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Users qw/store_user_preferences retrieve_user_preferences update_user_session_tokens/;

my $user_id = 'session-token-update-user';
my $session_id = 'session-token-update-sid';

sub remove_test_data {
	unlink("$BASE_DIRS{USERS}/$user_id.sto");
	return;
}

remove_test_data();

my $user_ref = {
	userid => $user_id,
	user_sessions => {
		$session_id => {
			ip => '127.0.0.1',
			time => time(),
			refresh_token => 'old-refresh',
			refresh_expires_at => time() + 1000,
			access_token => 'old-access',
			access_expires_at => time() + 60,
		},
	},
};
store_user_preferences($user_ref);

subtest 'updates tokens for an existing session' => sub {
	ok(update_user_session_tokens($user_ref, $session_id, 'new-refresh', time() + 2000, 'new-access', time() + 120),
		'returns success');

	my $stored = retrieve_user_preferences($user_id);
	is($stored->{user_sessions}{$session_id}{refresh_token}, 'new-refresh', 'refresh token updated');
	is($stored->{user_sessions}{$session_id}{access_token}, 'new-access', 'access token updated');
	ok($stored->{user_sessions}{$session_id}{refresh_expires_at} > time(), 'refresh expiry updated');
	ok($stored->{user_sessions}{$session_id}{access_expires_at} > time(), 'access expiry updated');
};

subtest 'rejects missing user or session' => sub {
	is(update_user_session_tokens(undef, $session_id, 'r', 1, 'a', 1), 0, 'undef user_ref');
	is(update_user_session_tokens($user_ref, undef, 'r', 1, 'a', 1), 0, 'undef session id');
	is(update_user_session_tokens($user_ref, 'unknown-session', 'r', 1, 'a', 1), 0, 'unknown session id');
};

remove_test_data();

done_testing();
