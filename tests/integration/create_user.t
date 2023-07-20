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
like($response->content, qr/\Q$words[0]\E/i, "the email entered is well saved"); #checking if the email is in the webpage and matching what we have entered in the sign up form
like($response->content, qr/\Q$words[1]\E/i, "the userid entered is well saved"); #checking if the userid is in the webpage and matching what we have entered in the sign up form
like($response->content, qr/\Q$words[2]\E/i, "the name entered is well saved"); #checking if the name is in the webpage and matching what we have entered in the sign up form

done_testing();
