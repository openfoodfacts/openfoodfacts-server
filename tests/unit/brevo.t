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

my ($email, $username, $country, $language);

# Test the add_contact_to_list function
{
	my $request_content;

	# Mock $ProductOpener::Brevo::brevo_api_key
	my $mocked_brevo_api_key = Test::MockModule->new('ProductOpener::Brevo');
	$mocked_brevo_api_key->mock('brevo_api_key' => 'abcdef1234');

	# Mock LWP::UserAgent
	my $mocked_ua = Test::MockModule->new('LWP::UserAgent');
	$mocked_ua->mock(
		'request' => sub {

			my ($self, $request) = @_;
			diag("request headers", $request->as_string);
			$request_content = $request->content;
			return HTTP::Response->new("200", "OK", HTTP::Headers->new(), '{"status": "success"}');

		}
	);

	$email = 'abc@example.com';
	$username = 'elly';
	$country = 'world';
	$language = 'english';

	# Call the function
	my $result = add_contact_to_list($email, $username, $country, $language);
	diag("Result: $result");

	is($result, 1, 'Contact added successfully');

	my $expected_content
		= "{\"email\":\"abc\@example.com\",\"attributes\":{\"USERNAME\":\"elly\",\"COUNTRY\":\"world\",\"LANGUAGE\":\"english\"},\"listIds\":[$ProductOpener::Brevo::list_id]}";

	# Verify the decoded data structures using is_deeply
	is_deeply(decode_json($request_content), decode_json($expected_content), 'Verify request content');
	$mocked_ua->unmock_all();
	$mocked_brevo_api_key->unmock_all();
}

# Test with a bad response
{
	my $request_content;
	my $mocked_ua = Test::MockModule->new('LWP::UserAgent');
	$mocked_ua->mock(
		'request' => sub {
			my ($self, $request) = @_;
			$request_content = $request->content;

			return HTTP::Response->new("500", "Internal Server Error", HTTP::Headers->new(), '{"status": "error"}');
		}
	);

	# Call the function
	my $result = add_contact_to_list($email, $username, $country, $language);
	diag("Result: $result");

	is($result, 0, 'Contact not added due to bad response');
	my $expected_content
		= "{\"email\":\"abc\@example.com\",\"attributes\":{\"USERNAME\":\"elly\",\"COUNTRY\":\"world\",\"LANGUAGE\":\"english\"},\"listIds\":[$ProductOpener::Brevo::list_id]}";

	# Verify the decoded data structures using is_deeply
	is_deeply(decode_json($request_content), decode_json($expected_content), 'Verify request content');
	$mocked_ua->unmock_all();
}

done_testing();
