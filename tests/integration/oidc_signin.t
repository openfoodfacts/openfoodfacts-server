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

wait_application_ready();

remove_all_users();

remove_all_products();

my $ua = new_client();
$ua->max_redirect(0);

my $url_signin = construct_test_url('/cgi/oidc_signin.pl', 'world-de');
my $response_signin = $ua->get($url_signin);

is($response_signin->code, 302, 'GET /cgi/oidc_signin.pl redirects');

my $location = $response_signin->header('Location');
my @url_parts = split qr/[?]/sxm, $location;
is(
	$url_parts[0],
	'http://keycloak:8080/realms/open-products-facts/protocol/openid-connect/auth',
	'Redirect to OIDC service'
);

my @raw_params = split qr/&/sxm, $url_parts[1];
my @params = map {my ($key, $value) = split qr/=/sxm; [uri_unescape($key), uri_unescape($value)]} @raw_params;

my $scope = first {$_->[0] eq 'scope'} @params;
is($scope->[1], 'openid+profile+offline_access', 'Scope includes openid, profile and offline_access');

my $response_type = first {$_->[0] eq 'response_type'} @params;
is($response_type->[1], 'code', 'Response type is code');

my $state = first {$_->[0] eq 'state'} @params;
ok($state->[1], 'State is set');

my $client_id = first {$_->[0] eq 'client_id'} @params;
is($client_id->[1], 'OFF', 'Client id is OFF');

my $redirect_uri = first {$_->[0] eq 'redirect_uri'} @params;
is($redirect_uri->[1], 'http://world.openfoodfacts.localhost/cgi/oidc_signin_callback.pl', 'Redirect uri is set');

done_testing();
