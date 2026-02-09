#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use ProductOpener::APITest qw/:all/;
use ProductOpener::Test qw/:all/;
use ProductOpener::TestDefaults qw/:all/;
use Clone qw/clone/;

# Ensure application is ready
wait_application_ready(__FILE__);
remove_all_products();
remove_all_users();
remove_all_orgs();

# Create a normal (non-pro) user and remain logged in
my $ua = new_client();
my %user_form = (%{clone(\%default_user_form)});
my $resp = create_user($ua, \%user_form);
ok(!html_displays_error($resp), "created normal user without error");

# Request the producers index page
$resp = get_page($ua, "/index-pro");
ok($resp->is_success, "fetched index-pro page");
my $content = $resp->decoded_content;

like($content, qr/<div class="show-when-logged-in">.*?href="\/cgi\/user.pl".*?Register your organization.*?href="\/cgi\/user.pl".*?Link your user to an existing organization/s, "Register/Link buttons point to /cgi/user.pl for logged-in users");

done_testing();
