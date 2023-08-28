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

#editing the user preferences
my %edit_form = (
	email => 'notbob@test.com',
	name => 'NotTest',
	userid => 'tests',
	pro_checkbox => 1,
	action => "process",
	type => "edit"

);
my $url_edit = construct_test_url("/cgi/user.pl", "world");
my $response_edit = $ua->post($url_edit, \%edit_form);

#checking if the changes were saved
my $url_check = construct_test_url("/cgi/user.pl?type=edit&userid=tests", "world");
my $response_check = $ua->get($url_check);
like($response_check->content, qr/notbob\@test\.com/, "the new email has been well saved");
like($response_check->content, qr/NotTest/, "the new name has been well saved");

done_testing();
