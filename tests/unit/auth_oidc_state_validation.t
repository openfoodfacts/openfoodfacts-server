use Modern::Perl '2017';
use utf8;

use Test2::V0;

use ProductOpener::Auth ();

subtest 'missing state returns 400' => sub {
	my ($ok, $message, $status)
		= ProductOpener::Auth::_validate_oidc_state_and_nonce(undef, 'nonce-1', 'login');
	is($ok, 0, 'validation fails when state is missing');
	is($status, 400, 'missing state is a bad request');
	is($message, 'Missing OIDC state during login', 'message is explicit');
};

subtest 'missing nonce returns 400' => sub {
	my ($ok, $message, $status)
		= ProductOpener::Auth::_validate_oidc_state_and_nonce('state-1', undef, 'login');
	is($ok, 0, 'validation fails when nonce is missing');
	is($status, 400, 'missing nonce is a bad request');
	is($message, 'Missing OIDC nonce during login', 'message is explicit');
};

subtest 'nonce mismatch keeps current behavior' => sub {
	my ($ok, $message, $status)
		= ProductOpener::Auth::_validate_oidc_state_and_nonce('state-1', 'nonce-1', 'login');
	is($ok, 0, 'validation fails when state and nonce differ');
	is($status, 500, 'mismatch keeps current internal error semantics');
	is($message, 'Invalid Nonce during OIDC login', 'legacy error message is preserved');
};

subtest 'matching state and nonce is accepted' => sub {
	my ($ok, $message, $status)
		= ProductOpener::Auth::_validate_oidc_state_and_nonce('state-1', 'state-1', 'login');
	is($ok, 1, 'validation succeeds when state and nonce match');
	is($message, undef, 'no error message on success');
	is($status, undef, 'no status on success');
};

done_testing();
