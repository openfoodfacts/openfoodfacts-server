#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use ProductOpener::APITest qw/create_user construct_test_url edit_product login new_client wait_application_ready/;
use ProductOpener::Test qw/remove_all_products remove_all_users/;
use ProductOpener::TestDefaults qw/%default_product_form %default_user_form/;
use ProductOpener::Products qw/product_path retrieve_product/;
use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Store qw/retrieve_object store_object/;
use JSON::MaybeXS qw/decode_json/;

wait_application_ready(__FILE__);
remove_all_products();
remove_all_users();

my $bearer_ua = new_client();
create_user($bearer_ua, \%default_user_form);

my $code = '1234567890100';
foreach my $name ('first', 'second', 'third') {
	edit_product(
		$bearer_ua,
		{
			%default_product_form,
			code => $code,
			product_name => "History product $name",
			comment => "Comment $name",
		}
	);
}

# Make the fixture exercise legacy history records without rev and the
# metadata fields that are intentionally exposed by the API.
my $product_ref = retrieve_product($code);
my $changes_path = "$BASE_DIRS{PRODUCTS}/" . product_path($product_ref) . "/changes";
my $changes_ref = retrieve_object($changes_path);
delete $changes_ref->[0]{rev};
$changes_ref->[0]{comment} = 'Legacy comment';
$changes_ref->[2]{comment} = 'Updated ingredients';
$changes_ref->[2]{app_uuid} = 'fixture-uuid';
$changes_ref->[2]{app_version} = '1.2.0';
$changes_ref->[2]{clientid} = 'mobile';
store_object($changes_path, $changes_ref);

sub get_history ($ua, $query = '') {
	my $response = $ua->get(construct_test_url("/api/v3/product/$code/history$query"));
	my $body = eval {decode_json($response->decoded_content)};
	is($@, '', 'history response is valid JSON') if $response->code == 200;
	return ($response, $body);
}

my $anonymous_ua = new_client();
my ($response) = get_history($anonymous_ua);
is($response->code, 401, 'anonymous request requires authentication');

my ($bearer_response, $bearer_body) = get_history($bearer_ua);
is($bearer_response->code, 200, 'bearer-token request is accepted');
is($bearer_body->{code}, $code, 'response contains the normalized product code');
is($bearer_body->{total}, 3, 'total count is returned');
is([map {$_->{rev}} @{$bearer_body->{history}}], [3, 2, 1], 'revisions are latest-first and legacy rev is derived');
is($bearer_body->{history}[0]{comment}, 'Updated ingredients', 'comments are returned');
is($bearer_body->{history}[0]{app_uuid}, 'fixture-uuid', 'app UUID is returned');
is($bearer_body->{history}[0]{app_version}, '1.2.0', 'app version is returned');
is($bearer_body->{history}[0]{clientid}, 'mobile', 'client ID is returned');
ok(!exists $bearer_body->{history}[0]{diffs}, 'diffs are not returned');
ok(!exists $bearer_body->{history}[0]{ip}, 'IP addresses are not returned');
ok(!exists $bearer_body->{history}[0]{product}, 'product snapshots are not returned');

my $session_ua = new_client();
login($session_ua, $default_user_form{userid}, $default_user_form{password});
my ($session_response) = get_history($session_ua);
is($session_response->code, 200, 'session-cookie request is accepted for a normal user');

my ($page_response, $page_body) = get_history($bearer_ua, '?page=2&page_size=2');
is($page_response->code, 200, 'paginated request succeeds');
is($page_body->{page}, 2, 'page is returned');
is($page_body->{page_size}, 2, 'page size is returned');
is([map {$_->{rev}} @{$page_body->{history}}], [1], 'pagination returns the requested page');

my ($max_response, $max_body) = get_history($bearer_ua, '?page_size=1001');
is($max_response->code, 200, 'oversized page request succeeds');
is($max_body->{page_size}, 1000, 'page size is capped at 1000');

my ($invalid_response, $invalid_body) = get_history($bearer_ua, '?page=&page_size=');
is($invalid_response->code, 200, 'empty pagination values follow recent-changes behavior');
is($invalid_body->{page}, 0, 'empty page is coerced to zero');
is($invalid_body->{page_size}, 0, 'empty page size is coerced to zero');
is(scalar @{$invalid_body->{history}}, 0, 'zero-sized page has no entries');

my $unknown_response = $bearer_ua->get(construct_test_url('/api/v3/product/1234567890999/history'));
is($unknown_response->code, 404, 'unknown product returns 404');

done_testing();
