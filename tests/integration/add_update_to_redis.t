#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test::More;
use ProductOpener::APITest qw/:all/;
use ProductOpener::Test qw/:all/;
use ProductOpener::TestDefaults qw/:all/;

wait_application_ready();

remove_all_users();

remove_all_products();

my $test_ua = new_client();

my %create_user_args = (%default_user_form, (email => 'bob@gmail.com'));
create_user($test_ua, \%create_user_args);

my %product_form = (
	cc => "be",
	lc => "fr",
	code => "1234567890001",
	product_name => "Product name",
	categories => "Cookies",
	quantity => "250 g",
	serving_size => '20 g',
	ingredients_text_fr => "Farine de blé, eau, sel, sucre",
	labels => "Bio, Max Havelaar",
	nutriment_salt => '50.2',
	nutriment_salt_unit => 'mg',
	nutriment_sugars => '12.5'
);

my $url = construct_test_url("/cgi/product_jqm_multilingual.pl");
my $headers_in = {"Origin" => origin_from_url($url)};
# We use the logging mechanism to check that the product update is pushed to Redis
my $tail = tail_log_start();
my $response = $test_ua->post($url, Content => \%product_form, %$headers_in);
# Stop logging
my $logs = tail_log_read($tail);

# Check that the push_to_redis_stream function was called and that Redis connection was successful
ok($logs =~ /Pushing product update to Redis/, "pushing product update to Redis");
# Check that the Redis call didn't trigger an error
ok($logs =~ /Successfully pushed product update to Redis/, "successfully pushed product update to Redis");
ok($logs !~ /Failed to push product update to Redis/, "no failure when pushing product update to Redis");
done_testing();
