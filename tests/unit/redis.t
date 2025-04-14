use Modern::Perl '2017';
use utf8;

use Test2::V0;
use Data::Dumper;
$Data::Dumper::Terse = 1;
use Test2::Plugin::UTF8;
use Log::Any::Adapter 'TAP';

use ProductOpener::Redis qw/process_xread_stream_reply/;
use ProductOpener::Config qw/%oidc_options/;
use ProductOpener::Auth qw/get_keycloak_level/;

subtest 'user registration from redis to minion' => sub {
	# Mock reply data
	my $mock_reply = [
		[
			'user-registered',
			[
				['message_id_1', ['userName', 'user1', 'newsletter', '']],
				['message_id_2', ['userName', 'user2', 'newsletter', 'subscribe']],
			]
		],
		['other-stream', [['message_id_3', ['key', 'value']],]]
	];

	# Mock Minion queue
	my $call_count_welcome = 0;
	my $call_count_newsletter = 0;
	my $user1_called = 0;
	my $user2_called = 0;
	my $import_module = mock 'Minion' => (
		override => [
			'enqueue' => sub {
				my ($client, $topic, $tasks_ref) = @_;
				if ($topic eq 'welcome_user') {
					++$call_count_welcome;
				}
				elsif ($topic eq 'subscribe_user_newsletter') {
					++$call_count_newsletter;
				}
				else {
					return;
				}

				my @tasks = @{$tasks_ref};
				my $task = $tasks[0];
				if ($task->{userid} eq 'user1') {
					++$user1_called;
				}
				elsif ($task->{userid} eq 'user2') {
					++$user2_called;
				}
			},
		]
	);

	# Need to mock keycloak->create_or_update_user for unit test
	my $create_or_update_user_called = 0;
	my $keycloak_mock = mock 'ProductOpener::Keycloak' => (
		override => [
			'create_or_update_user' => sub {
				++$create_or_update_user_called;
				return;
			}
		]
	);

	# Call the subroutine with the mock data
	my $result = process_xread_stream_reply($mock_reply);

	# Verify the result
	is($call_count_welcome, 2, 'process_xread_stream_reply caused 2 calls to Minion->enqueue for the welcome_user job');
	is($call_count_newsletter, 1,
		'process_xread_stream_reply caused 1 calls to Minion->enqueue for the subscribe_user_newsletter job');
	is($user1_called, 1, 'process_xread_stream_reply called Minion->enqueue with user1');
	is($user2_called, 2, 'process_xread_stream_reply called Minion->enqueue with user2');

	if (get_keycloak_level() < 5) {
		is($create_or_update_user_called, 2, 'create_or_update_user for each user');
	}
};

subtest 'user deletion from redis to minion' => sub {
	# Mock reply data
	my $mock_reply = [
		[
			'user-deleted',
			[
				['message_id_1', ['userName', 'user1', 'newUserName', 'anonymous-123']],
				['message_id_2', ['userName', 'user2', 'newUserName', 'anonymous-234']],
			]
		],
		['other-stream', [['message_id_3', ['key', 'value']],]]
	];

	# Mock Minion queue
	my $call_count = 0;
	my $user1_called = 0;
	my $user2_called = 0;
	my $import_module = mock 'Minion' => (
		override => [
			'enqueue' => sub {
				my ($client, $topic, $tasks_ref) = @_;
				if ($topic ne 'delete_user') {
					return;
				}

				++$call_count;

				my @tasks = @{$tasks_ref};
				my $task = $tasks[0];
				if ($task->{userid} eq 'user1') {
					++$user1_called;
				}
				elsif ($task->{userid} eq 'user2') {
					++$user2_called;
				}
			},
		]
	);

	# Call the subroutine with the mock data
	my $result = process_xread_stream_reply($mock_reply);

	# Verify the result
	is($call_count, 2, 'process_xread_stream_reply caused 2 calls to Minion->enqueue');
	is($user1_called, 1, 'process_xread_stream_reply called Minion->enqueue with user1');
	is($user2_called, 1, 'process_xread_stream_reply called Minion->enqueue with user2');
};

done_testing();
