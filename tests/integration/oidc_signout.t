#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use Log::Any::Adapter 'TAP';
use Log::Any qw($log);

use ProductOpener::APITest qw/wait_application_ready new_client construct_test_url/;
use ProductOpener::Test qw/remove_all_products remove_all_users/;
use ProductOpener::TestDefaults qw/%default_product %default_product_form/;
use ProductOpener::Auth qw/get_token_using_password_credentials/;

use List::Util qw/first/;
use URI::Escape::XS qw/uri_unescape/;

wait_application_ready(__FILE__);
remove_all_products();
remove_all_users();

subtest 'Signout with incorrect Method' => sub {
	my $ua = new_client();
	$ua->max_redirect(0);

	my $url_signout = construct_test_url('/cgi/oidc_signout.pl', 'world');
	my $response_signout = $ua->get($url_signout);

	is($response_signout->code, 405, 'GET /cgi/oidc_signout.pl fails as the method is not allowed');
};

subtest 'Signout without being signed in without redirect URI' => sub {
	my $ua = new_client();
	$ua->max_redirect(0);

	my $url_signout = construct_test_url('/cgi/oidc_signout.pl', 'world');
	my $response_signout = $ua->post($url_signout);

	is($response_signout->code, 302, 'POST /cgi/oidc_signout.pl redirects');

	my $location = $response_signout->header('Location');
	is($location, 'http://world.openfoodfacts.localhost', 'Redirect to home page');
};

subtest 'Signout without being signed in with redirect URI on bad domain' => sub {
	my $ua = new_client();
	$ua->max_redirect(0);

	my $url_signout = construct_test_url('/cgi/oidc_signout.pl?return_url=http://leet.hacker.example.org/', 'world');
	my $response_signout = $ua->post($url_signout);

	is($response_signout->code, 302, 'POST /cgi/oidc_signout.pl redirects');

	my $location = $response_signout->header('Location');
	is($location, 'http://world.openfoodfacts.localhost', 'Redirect to home page');
};

done_testing();
