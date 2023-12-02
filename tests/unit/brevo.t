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

# Mock the LWP::UserAgent module
my $mocked_ua = Test::MockModule->new('LWP::UserAgent');
$mocked_ua->mock(
    'request' => sub {
        my ($request) = @_;
        return HTTP::Response->new("200", "OK", HTTP::Headers->new(), '{"status": "success"}');
    }
);


# Test the add_contact_to_list function

    my $email = 'abc@example.com';
    my $username = 'elly';
    my $cc = 'world';
    my $lc = 'english';

# my $dump_path = File::Temp->newdir();
# my @responses = (
# 	HTTP::Response->new("200", "OK", HTTP::Headers->new(), '{"status": "success"}'),
# );
# # start fake server
# my $httpd = fake_http_server(8881, $dump_path, \@responses);

# Call the function
my $result = add_contact_to_list($email, $username, $cc, $lc); 
diag("Result: $result");

ok($result, 'Contact added successfully');

$mocked_ua->unmock_all();

done_testing();
 