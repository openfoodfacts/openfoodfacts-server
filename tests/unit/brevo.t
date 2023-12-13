use ProductOpener::PerlStandards;
use Test::More;
use Test::MockModule;
use HTTP::Response;
use HTTP::Headers;
use JSON;
use Test::Fake::HTTPD qw/run_http_server/;
use ProductOpener::Brevo qw/:all/;
use ProductOpener::APITest qw/:all/;
use ProductOpener::Test qw/:all/;
use File::Temp ();

my ($brevo_api_key, $email, $username, $country, $language);

# Test the add_contact_to_list function
{
	my $request;

	# Mock $ProductOpener::Brevo::brevo_api_key
	my $mocked_brevo_api_key = Test::MockModule->new('ProductOpener::Brevo');
	$mocked_brevo_api_key->mock(
		'brevo_api_key' => sub {
			return $brevo_api_key;
		}
	);

	# Mock LWP::UserAgent
	my $mocked_ua = Test::MockModule->new('LWP::UserAgent');
	$mocked_ua->mock(
		'request' => sub {
			($request) = @_;
			# diag($request);
			return HTTP::Response->new("200", "OK", HTTP::Headers->new(), '{"status": "success"}');
		}
	);

	$brevo_api_key = 'abcdef1234';
	$email = 'abc@example.com';
	$username = 'elly';
	$country = 'world';
	$language = 'english';

	# Call the function
	my $result = add_contact_to_list($email, $username, $country, $language);
	diag("Result: $result");

	is($result, 1, 'Contact added successfully');
	is($brevo_api_key, 'abcdef1234', 'Verify brevo_api_key');

	my $ua = LWP::UserAgent->new;
	my $response = $ua->request($request);
	print to_json(decode_json($response->decoded_content), {pretty => 1});
	is_deeply(
		decode_json($response->decoded_content),
		{status => 'success'},
		'Verify response body is {"status": "success"}'
	);

	$mocked_ua->unmock_all();
	$mocked_brevo_api_key->unmock_all();
}

# Test with a bad response
{
	my $request;
	my $mocked_ua = Test::MockModule->new('LWP::UserAgent');
	$mocked_ua->mock(
		'request' => sub {
			($request) = @_;
			return HTTP::Response->new("500", "Internal Server Error", HTTP::Headers->new(), '{"status": "error"}');
		}
	);

	# Call the function
	my $result = add_contact_to_list($email, $username, $country, $language);
	diag("Result: $result");

	is($result, 0, 'Contact not added due to bad response');

	my $ua = LWP::UserAgent->new;
	my $response = $ua->request($request);
	print to_json(decode_json($response->decoded_content), {pretty => 1});
	is_deeply(
		decode_json($response->decoded_content),
		{status => 'error'},
		'Verify response body is {"status": "error"}'
	);
	$mocked_ua->unmock_all();
}

done_testing();
