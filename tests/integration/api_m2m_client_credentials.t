#!/usr/bin/perl -w

# End-to-end coverage for M2M (client_credentials) API calls from an
# external app using only client_id + client secret, without user interaction.
#
# Seeds a dedicated confidential Keycloak client via
# ProductOpener::APITest::create_client_in_keycloak() (same pattern as
# create_user_in_keycloak()), then exercises product write, image upload
# and tag page rendering with the resulting service-account token and
# asserts app-<azp> attribution throughout.
#
# If the backend Keycloak admin client lacks the manage-clients role,
# dedicated seeding is skipped and the backend's own service account is
# used instead, so the M2M auth path is still covered.

use ProductOpener::PerlStandards;

use Test2::V0;
use Log::Any::Adapter 'TAP';
use Log::Any qw($log);

use ProductOpener::APITest qw/:all/;
use ProductOpener::Test qw/remove_all_products remove_all_users get_base64_image_data_from_file/;
use ProductOpener::Config qw/%oidc_options/;
use ProductOpener::Auth qw/get_token_using_client_credentials/;
use ProductOpener::Paths qw/%BASE_DIRS/;

use File::Basename qw/dirname/;
use JSON::MaybeXS qw(decode_json encode_json);
use MIME::Base64 qw(decode_base64);
use HTTP::Request::Common;

wait_application_ready(__FILE__);
remove_all_products();
remove_all_users();

my $test_client_id = 'test-m2m-client';

my ($m2m_client_id, $m2m_token, $seeded_client_ref);

subtest 'seed M2M client' => sub {
	my $client_ref = eval {create_client_in_keycloak($test_client_id);};
	if ($client_ref) {
		$seeded_client_ref = $client_ref;
		$m2m_client_id = $client_ref->{client_id};
		my $token_ref = get_token_using_client_credentials_for($m2m_client_id, $client_ref->{client_secret});
		$m2m_token = $token_ref->{access_token};
		ok($m2m_token, 'client_credentials token obtained for dedicated client');
	}
	elsif (($@ // '') =~ /\b403\b/) {
		diag("Dedicated client seeding not permitted ($@); falling back to backend service account");
		$m2m_client_id = $oidc_options{client_id};
		$m2m_token = get_token_using_client_credentials()->{access_token};
		ok($m2m_token, 'client_credentials token obtained for backend service account');
	}
	else {
		die $@ || 'create_client_in_keycloak failed without error';
	}
};

my $app_id = 'app-' . lc($m2m_client_id);

sub _jwt_payload ($jwt) {
	my ($payload_segment) = (split /\./, $jwt)[1];
	$payload_segment =~ tr/-_/+\//;
	$payload_segment .= '=' x ((4 - length($payload_segment) % 4) % 4);
	return decode_json(decode_base64($payload_segment));
}

subtest 'service-account token carries azp identity' => sub {
	my $claims_ref = _jwt_payload($m2m_token);
	is($claims_ref->{azp}, $m2m_client_id, 'azp is the client id');
	is(lc($claims_ref->{preferred_username}), 'service-account-' . lc($m2m_client_id),
		'username marks service account');
};

sub _m2m_ua () {
	my $ua = new_client();
	$ua->default_header('Authorization' => 'Bearer ' . $m2m_token);
	return $ua;
}

my $code = '9000000001011';

subtest 'M2M client creates product with app-<azp> attribution' => sub {
	my $ua = _m2m_ua();
	my $url = construct_test_url("/api/v3/product/$code");
	my $request = HTTP::Request::Common::PATCH(
		$url,
		Content => encode_json({product => {product_name => 'M2M test product'}}),
		'Content-Type' => 'application/json; charset=utf-8',
		'Origin' => origin_from_url($url),
		'Authorization' => 'Bearer ' . $m2m_token,
	);
	my $response = $ua->request($request);
	ok($response->is_success, 'product write succeeds') or diag($response->decoded_content);
	is($response->code, 200, 'product write returns 200');

	my $get_url = construct_test_url(
		"/api/v3/product/$code?fields=creator,created_by_client,last_modified_by_client,editors_tags");
	my $get_response = $ua->get($get_url, 'Authorization' => 'Bearer ' . $m2m_token);
	ok($get_response->is_success, 'product read succeeds') or diag($get_response->decoded_content);
	my $product_ref = decode_json($get_response->decoded_content)->{product};
	is($product_ref->{creator}, $app_id, 'creator is app-<azp>');
	is($product_ref->{created_by_client}, $m2m_client_id, 'created_by_client is azp');
	is($product_ref->{last_modified_by_client}, $m2m_client_id, 'last_modified_by_client is azp');
	ok((grep {$_ eq $app_id} @{$product_ref->{editors_tags} // []}), 'editors_tags contains app-<azp>');

	ok(!-e "$BASE_DIRS{USERS}/$app_id.sto", 'no user file created for synthetic client');
};

subtest 'M2M image upload attributes uploader to app-<azp>' => sub {
	my $sample_path = dirname(__FILE__) . '/inputs/upload_images/1.jpg';
	my $ua = _m2m_ua();
	my $url = construct_test_url("/api/v3/product/$code/images");
	my $response = $ua->post(
		$url,
		Content => encode_json({image_data_base64 => get_base64_image_data_from_file($sample_path)}),
		'Content-Type' => 'application/json; charset=utf-8',
		'Origin' => origin_from_url($url),
		'Authorization' => 'Bearer ' . $m2m_token,
	);
	ok($response->is_success, 'image upload succeeds') or diag($response->decoded_content);
	# The upload response echoes the product including the new uploaded image:
	# assert the uploader attribution right there (a later GET with field
	# selectors may legitimately omit the uploaded images structure).
	my $uploaded_ref = decode_json($response->decoded_content)->{product}{images}{uploaded} // {};
	my @mine = grep {($uploaded_ref->{$_}{uploader} // '') eq $app_id} keys %{$uploaded_ref};
	ok(scalar @mine > 0, 'uploaded image uploader is app-<azp>');
};

subtest 'users tag page renders for app-<azp> instead of 404' => sub {
	my $ua = _m2m_ua();
	my $response = $ua->get(construct_test_url("/facets/editors/$app_id"));
	is($response->code, 200, 'tag page returns 200');
	like($response->decoded_content, qr/\Q$m2m_client_id\E/, 'tag page mentions the client');
};

if (defined $seeded_client_ref) {
	delete_client_in_keycloak($test_client_id);
}

done_testing();
