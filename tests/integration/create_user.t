#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test::More;
use ProductOpener::APITest qw/:all/;
use ProductOpener::Test qw/:all/;
use ProductOpener::TestDefaults qw/:all/;
use ProductOpener::Config qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Paths qw/:all/;

remove_all_users();
wait_application_ready();
# we need to create spam user log to be able to tail on it
open(my $log, ">>", "$BASE_DIRS{LOGS}/user_spam.log");
close($log);

my $ua = new_client();

my %create_user_args = (%default_user_form, (email => 'bob@test.com'));
create_user($ua, \%create_user_args);

# edit preference accessible
my $url = construct_test_url("/cgi/user.pl?type=edit&userid=tests", "world");
my $response = $ua->get($url);

#$DB::single = 1;
is $response->{_rc}, 200;

#checking whether the preference were well saved
my @words = ('bob@test.com', $default_user_form{userid}, $default_user_form{name});

foreach my $word (@words) {
	like($response->content, qr/\Q$word\E/i, "the word $word is in the page")
		;    #checking word by word if they match what is saved in the preference page
}

# user can be loaded
my $user = retrieve_user($default_user_form{userid});
is($user->{email}, 'bob@test.com', "User sto created");

# try creating a spam user in a new browser
# it should be denied
$ua = new_client();
my $testnum = 1;
foreach my $args_ref (["name", "click http://test.com"], ["faxnumber", "0"]) {
	my ($arg_name, $arg_value) = @$args_ref;
	my $userid = "bob$testnum";
	my %create_user_args
		= (%default_user_form, ($arg_name => $arg_value, "userid" => $userid, email => "bob$testnum\@test.com"));
	my $logid = tail_log_start("$BASE_DIRS{LOGS}/user_spam.log");
	$response = create_user($ua, \%create_user_args);
	my $logged = tail_log_read($logid);
	like($response->content, qr/class="error_page"/, "Error in the page - $testnum");
	# user in spam log
	like($logged, qr/\b$userid\b/, "Error in spam log - $testnum");
	is(undef, retrieve_user($userid), "User not created - $testnum");
	$testnum++;
}

done_testing();
