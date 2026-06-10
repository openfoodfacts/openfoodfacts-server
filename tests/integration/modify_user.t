#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use ProductOpener::APITest qw/construct_test_url create_user new_client wait_application_ready/;
use ProductOpener::Test qw/remove_all_users/;
use ProductOpener::TestDefaults qw/%default_user_form/;
use ProductOpener::Users qw/retrieve_user/;

wait_application_ready(__FILE__);
remove_all_users();
my $ua = new_client();

my %create_user_args = (%default_user_form, (email => 'bob@example.com'));
create_user($ua, \%create_user_args);

#editing the user preferences as if via the API
my %edit_form = (
	email => 'notbob@example.com',
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
my $keycloak = ProductOpener::Keycloak->new();
my $user_ref = $keycloak->find_user_by_username('tests');

is($user_ref->{email}, 'notbob@example.com', "the new email has been well saved");
is($user_ref->{name}, 'NotTest', "the new name has been well saved");
is($user_ref->{preferred_language}, 'fr', "new language saved");
is($user_ref->{country}, 'en:france', "new country saved");

#editing the user preferences as if via the User Form (most fields no longer supplied)
%edit_form = (
	userid => 'tests',
	pro_checkbox => 1,
	pro => 1,
	display_barcode => 1,
	action => "process",
	type => "edit"
);
$response_edit = $ua->post($url_edit, \%edit_form);

#checking if the changes were saved
$user_ref = retrieve_user('tests');

is($user_ref->{pro}, 1, "pro flag changed");
is($user_ref->{display_barcode}, 1, "display barcode flag changed");
is($user_ref->{email}, 'notbob@example.com', "the new email has not been changed");
is($user_ref->{name}, 'NotTest', "the name has not been changed");
is($user_ref->{preferred_language}, 'fr', "language not changed");
is($user_ref->{country}, 'en:france', "country not changed");


done_testing();
