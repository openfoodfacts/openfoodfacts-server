#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test;
use Test::More;

use ProductOpener::APITest qw/:all/;
use ProductOpener::Test qw/:all/;

remove_all_users();
wait_dynamic_front();
my $ua = new_client();

create_user($ua, {});

# edit preference accessible
my $url = construct_test_url("/cgi/user.pl?type=edit&userid=test", "world");
my $response = $ua->get($url);

#$DB::single = 1;
is $response->{_rc}, 200;

done_testing();
