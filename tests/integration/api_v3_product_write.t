#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test::More;
use ProductOpener::APITest qw/:all/;
use ProductOpener::Test qw/:all/;
use ProductOpener::TestDefaults qw/:all/;

use File::Basename "dirname";

use Storable qw(dclone);

remove_all_users();

remove_all_products();

wait_dynamic_front();

my $ua = new_client();

my %create_user_args = (%default_user_form, (email => 'bob@gmail.com'));
create_user($ua, \%create_user_args);

my $tests_ref = [
	{
		test_case => 'get-unexisting-product',
		method => 'GET',
		path => '/api/v3/product/12345678',
	},
	{
		test_case => 'post-no-body',
		method => 'POST',
		path => '/api/v3/product/12345678',
	},
	{
		test_case => 'post-broken-json-body',
		method => 'POST',
		path => '/api/v3/product/12345678',
		body => 'not json'
	},
	{
		test_case => 'post-no-product',
		method => 'POST',
		path => '/api/v3/product/12345678',
		body => '{}'
	},
	{
		test_case => 'post-empty-product',
		method => 'POST',
		path => '/api/v3/product/12345678',
		body => '{"product":{}}'
	},
];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
