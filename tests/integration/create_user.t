#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use ProductOpener::APITest qw/:all/;
use ProductOpener::Test qw/remove_all_users/;
use ProductOpener::TestDefaults qw/%default_user_form/;
use ProductOpener::Config qw/:all/;
use ProductOpener::Users qw/retrieve_user/;
use ProductOpener::Paths qw/%BASE_DIRS/;

wait_application_ready(__FILE__);
remove_all_users();
# we need to create spam user log to be able to tail on it
open(my $log, ">>", "$BASE_DIRS{LOGS}/user_spam.log");
close($log);

my $ua = new_client();

my %create_user_args = (%default_user_form, (email => 'bob@example.com'));
create_user($ua, \%create_user_args);

# edit preference accessible
my $url = construct_test_url("/cgi/user.pl?type=edit&userid=tests", "world");
my $response = $ua->get($url);

#$DB::single = 1;
is($response->{_rc}, 200, "Status ok on creation");

#checking whether the preference were well saved
my @words = ('bob@example.com', $default_user_form{userid}, $default_user_form{name});

foreach my $word (@words) {
	like($response->content, qr/\Q$word\E/i, "the word $word is in the page")
		;    #checking word by word if they match what is saved in the preference page
}

# user can be loaded
my $user = retrieve_user($default_user_form{userid});
is($user->{email}, 'bob@example.com', "User sto created");

# try creating a spam user in a new browser
# it should be denied
$ua = new_client();
my $testnum = 1;
foreach my $args_ref (["name", "click http://test.com"], ["faxnumber", "0"]) {
	my ($arg_name, $arg_value) = @$args_ref;
	my $userid = "bob$testnum";
	my %create_user_args
		= (%default_user_form, ($arg_name => $arg_value, "userid" => $userid, email => "bob$testnum\@example.com"));
	my $logid = tail_log_start("$BASE_DIRS{LOGS}/user_spam.log");
	# Note this intentionally uses the legacy API to test for Spam.
	# Need to decide whether this test is needed when this is deprecated for Keycloak
	$response = create_user_legacy($ua, \%create_user_args);
	my $logged = tail_log_read($logid);
	like($response->content, qr/class="error_page"/, "Error in the page - $testnum");
	# user in spam log
	like($logged, qr/\b$userid\b/, "Error in spam log - $testnum");
	is(retrieve_user($userid), undef, "User not created - $testnum");
	$testnum++;
}

# Check copes with no country specified
$ua = new_client();
%create_user_args
	= (%default_user_form, (email => 'bobnocountry@example.com', userid => 'bobnocountry', country => ''));
create_user($ua, \%create_user_args);
$user = retrieve_user('bobnocountry');
is($user->{email}, 'bobnocountry@example.com', "User created");
is($user->{country}, "", "User created with no country");

done_testing();
