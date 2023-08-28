#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test::More;
use ProductOpener::APITest qw/:all/;
use ProductOpener::Test qw/:all/;
use ProductOpener::TestDefaults qw/:all/;

remove_all_users();
wait_application_ready();
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
	like($response->content, qr/\Q$word\E/i, "the word is in the page")
		;    #checking word by word if they match what is saved in the preference page
}

done_testing();
