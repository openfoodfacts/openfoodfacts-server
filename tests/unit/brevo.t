use ProductOpener::PerlStandards;
use Test2::V0;
use HTTP::Response;
use HTTP::Headers;
use JSON;
use Test::Fake::HTTPD qw/run_http_server/;
use ProductOpener::Brevo qw/$brevo_api_key $list_id add_contact_to_list/;
use ProductOpener::APITest qw/:all/;
use ProductOpener::Test qw/:all/;
use File::Temp ();

no warnings qw(experimental::signatures);

# Stores what will be sent to the mocked Brevo API
my $request_headers;
my $request_content;

# Mock needed functions to simulate the Brevo API
sub do_mock ($brevo_api_key, $list_id, $code, $msg, $response) {
	# reset results holders
	$request_headers = undef;
	$request_content = undef;
	# Mock $ProductOpener::Brevo::get_brevo_api_key
	my $mocked_brevo = mock 'ProductOpener::Brevo' => (
		override => [
			'get_brevo_api_key' => sub {
				return $brevo_api_key;
			},
			'get_list_id' => sub {
				return $list_id;
			},
		],
	);

	# Mock LWP::UserAgent to check our request parameters to brevo are correct and simulate a success
	my $mocked_ua = mock 'LWP::UserAgent' => (
		override => [
			'request' => sub {
				my ($self, $request) = @_;
				# store sent request to verify it in test
				$request_headers = $request->headers();
				$request_content = $request->content;
				return HTTP::Response->new($code, $msg, HTTP::Headers->new(), $response);
			}
		]
	);
	return ($mocked_ua, $mocked_brevo);
}
# unmocking
sub do_unmock (@mocks) {
	foreach my $mock (@mocks) {
		$mock = undef;
	}
	return;
}

# we use same values for tests
my $expected_headers = {
	'::std_case' => {'api-key' => 'Api-Key'},
	'accept' => 'application/json',
	'api-key' => 'abcdef1234',
	'content-length' => 123,
	'content-type' => 'application/json',
};
my $expected_content = {
	email => 'abc@example.com',
	attributes => {USERNAME => 'elly', COUNTRY => 'world', LANGUAGE => 'english'},
	listIds => ["123456789"],
};

# Test the add_contact_to_list function
{
	my @mocks = do_mock("abcdef1234", "123456789", "200", "OK", '{"status": "success"}');

	# Call the function
	my $result = add_contact_to_list('abc@example.com', 'elly', 'world', 'english');

	is($result, 1, 'Contact added successfully');

	# Verify what we have sent to Brevo
	is($request_headers, $expected_headers, 'Verify request headers for good request');
	is(decode_json($request_content), $expected_content, 'Verify request content for good request');

	do_unmock(@mocks);

}

# Test with a bad response
{
	my @mocks = do_mock("abcdef1234", "123456789", "500", "Internal Server Error", '{"status": "error"}');

	# Call the function
	my $result = add_contact_to_list('abc@example.com', 'elly', 'world', 'english');

	is($result, 0, 'Contact not added due to bad response');
	# Verify the sent data structures using is
	is($request_headers, $expected_headers, 'Verify request headers for bad request');
	is(decode_json($request_content), $expected_content, 'Verify request content for bad request');

	do_unmock(@mocks);
}

# test everything ok without a key
{
	my @mocks = do_mock(undef, "123456789", "200", "OK", '{"status": "success"}');

	# Call the function
	my $result = add_contact_to_list('abc@example.com', 'elly', 'world', 'english');

	is($result, -1, 'API not called due to no key');
	# Verify the sent data structures using is
	is($request_headers, undef, 'Verify no brevo call for no key');
	is($request_content, undef, 'Verify no brevo call for no key (content)');

	do_unmock(@mocks);
}

done_testing();
