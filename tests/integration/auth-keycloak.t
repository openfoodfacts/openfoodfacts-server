#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use Log::Any::Adapter 'TAP';
use Log::Any qw($log);

use ProductOpener::APITest qw/:all/;
use ProductOpener::Test qw/:all/;
use ProductOpener::TestDefaults qw/:all/;
use ProductOpener::Auth qw/:all/;

use List::Util qw/first/;
use URI::Escape::XS qw/uri_unescape/;

wait_application_ready(__FILE__);
remove_all_products();
remove_all_users();

my $ua = new_client();

my %create_user_args = (%default_user_form, (email => 'bob@example.com'));
create_user($ua, \%create_user_args);

subtest 'user + password_signin' => sub {
	subtest 'with bad password' => sub {
		my ($user_ref, $refresh_token, $refresh_expires_at, $access_token, $access_expires_at, $id_token)
			= password_signin('tests', 'badpassword', {});
		is($user_ref, undef, 'user_ref is undefined');
		is($refresh_token, undef, 'refresh_token is undefined');
		is($refresh_expires_at, undef, 'refresh_expires_at is undefined');
		is($access_token, undef, 'access_token is undefined');
		is($access_expires_at, undef, 'access_expires_at is undefined');
		is($id_token, undef, 'id_token is undefined');
	};

	subtest 'with good password' => sub {
		my ($user_ref, $refresh_token, $refresh_expires_at, $access_token, $access_expires_at, $id_token)
			= password_signin('tests', 'testtest', {});
		is($user_ref->{userid}, 'tests', 'user_id matches the one we used');
		ok($refresh_token, 'refresh token is defined');
		ok($refresh_expires_at, 'refresh token expires_at is defined');
		ok($access_token, 'access token is defined');
		ok($access_expires_at, 'access token expires_at is defined');
		ok($id_token, 'id token is defined');
	};
};

subtest 'mail + password_signin' => sub {
	subtest 'with bad password' => sub {
		my ($user_ref, $refresh_token, $refresh_expires_at, $access_token, $access_expires_at, $id_token)
			= password_signin('bob@example.com', 'badpassword', {});
		is($user_ref, undef, 'user_ref is undefined');
		is($refresh_token, undef, 'refresh_token is undefined');
		is($refresh_expires_at, undef, 'refresh_expires_at is undefined');
		is($access_token, undef, 'access_token is undefined');
		is($access_expires_at, undef, 'access_expires_at is undefined');
		is($id_token, undef, 'id_token is undefined');
	};

	subtest 'with good password' => sub {
		my ($user_ref, $refresh_token, $refresh_expires_at, $access_token, $access_expires_at, $id_token)
			= password_signin('bob@example.com', 'testtest', {});
		is($user_ref->{userid}, 'tests', 'user_id matches the one we used');
		ok($refresh_token, 'refresh token is defined');
		ok($refresh_expires_at, 'refresh token expires_at is defined');
		ok($access_token, 'access token is defined');
		ok($access_expires_at, 'access token expires_at is defined');
		ok($id_token, 'id token is defined');
	};
};

done_testing();
