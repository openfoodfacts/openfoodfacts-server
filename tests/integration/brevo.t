use ProductOpener::PerlStandards;

use Test::More;
use Test::MockModule;
use HTTP::Headers;
use HTTP::Response;
use JSON;
use File::Temp ();
use File::Copy::Recursive qw(dircopy fcopy);

use ProductOpener::APITest qw/:all/;
use ProductOpener::Test qw/:all/;
use ProductOpener::TestDefaults qw/:all/;
use ProductOpener::Brevo qw/:all/; # Include the Brevo module
use Test::Fake::HTTPD qw/run_http_server/;
use Data::Dumper;


remove_all_users();
wait_application_ready();

my $ua = new_client();
my %create_user_args = (%default_user_form);
my $resp=create_user($ua, \%create_user_args);
ok(!html_displays_error($resp));

my $email = $default_user_form{email};
my $username = $default_user_form{userid};

my @responses = (
	HTTP::Response->new("200", "OK", HTTP::Headers->new(), '{"responses": [{}]}'),
	HTTP::Response->new("200", "OK", HTTP::Headers->new(), '{"contact": "success"}'),
);
my $dump_path = File::Temp->newdir();
# start fake server
my $httpd = fake_http_server(8881, $dump_path, \@responses);

 # Call the add_contact_to_list() function
   if (add_contact_to_list($email, $username, "en", "en")) {

    # Check if the contact is added successfully
    diag("Contact added to the list successfully");
}

# Get the contact info to verify it was added
my $contact_info = get_contact_info(1);
diag("Retrieved contact info: " . Dumper($contact_info));

    # Check if the contact info matches the expected values
    if(is($contact_info->{email}, $email, "Contact email matches")){
        diag("Contact got successfully");
    }

done_testing();
