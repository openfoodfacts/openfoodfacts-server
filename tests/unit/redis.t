use Modern::Perl '2017';
use utf8;

use Test2::V0;
use Data::Dumper;
$Data::Dumper::Terse = 1;
use Test2::Plugin::UTF8;
use Log::Any::Adapter 'TAP';

use ProductOpener::Redis qw/process_xread_stream_reply/;

subtest 'user deletion from redis to minion' => sub {
	# Mock reply data
	my $mock_reply = [
		['user-deleted', [['message_id_1', ['userName', 'user1']], ['message_id_2', ['userName', 'user2']],]],
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
