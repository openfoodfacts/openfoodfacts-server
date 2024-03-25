#!/usr/bin/perl -w

# Tests to find HTML changes for different types of pages of the website

use ProductOpener::PerlStandards;

use Test::More;
use ProductOpener::APITest qw/:all/;
use ProductOpener::Test qw/:all/;
use ProductOpener::TestDefaults qw/:all/;

use File::Basename "dirname";

use Storable qw(dclone);

remove_all_users();

remove_all_products();

wait_application_ready();

my $ua = new_client();

my %create_user_args = (%default_user_form, (email => 'bob@gmail.com'));
create_user($ua, \%create_user_args);

# Note: expected results are stored in json files, see execute_api_tests
my $tests_ref = [
	{
		test_case => 'world-index',
		path => '/',
		expected_type => 'html',
	},
    {
        test_case => 'fr-index',
        subdomain => 'fr',
        path => '/',
        expected_type => 'html',
    },
];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
