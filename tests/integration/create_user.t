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

done_testing();
