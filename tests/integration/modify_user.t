#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use ProductOpener::APITest qw/construct_test_url create_user new_client wait_application_ready/;
use ProductOpener::Test qw/remove_all_users/;
use ProductOpener::TestDefaults qw/%default_user_form/;

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
	preferred_language => "fr",
	country => "en:france",
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
like($response_check->content, qr/value=.fr.\s+selected/, "new language saved");
like($response_check->content, qr/value=.en:france.\s+selected/, "new country saved");

done_testing();
