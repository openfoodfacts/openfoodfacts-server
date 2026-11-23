#!/usr/bin/perl -w

use ProductOpener::PerlStandards;
use utf8;

use Test2::V0;

use ProductOpener::Config qw/%server_options $query_url/;
use ProductOpener::Data qw/can_use_off_query/;
use CGI qw/param Delete/;

my $prev_query_url = $query_url;
my $prev_producers = $server_options{producers_platform};

$ProductOpener::Config::query_url = 'http://localhost:8000';
$server_options{producers_platform} = 0;

subtest "can_use_off_query defaults to 1 when off_query parameter is not passed" => sub {
	Delete('off_query');
	my $debug = '';
	is(can_use_off_query(\$debug), 1, 'enabled by default');
};

subtest "can_use_off_query returns 1 when off_query=1" => sub {
	param('off_query', '1');
	my $debug = '';
	is(can_use_off_query(\$debug), 1, 'enabled when off_query=1');
};

subtest "can_use_off_query returns 0 when off_query=0" => sub {
	param('off_query', '0');
	my $debug = '';
	is(can_use_off_query(\$debug), 0, 'disabled when off_query=0');
};

subtest "can_use_off_query returns 0 when query_url is not configured" => sub {
	Delete('off_query');
	$ProductOpener::Config::query_url = '';
	my $debug = '';
	is(can_use_off_query(\$debug), 0, 'disabled without query_url');
	$ProductOpener::Config::query_url = 'http://localhost:8000';
};

subtest "can_use_off_query returns 0 on producers platform" => sub {
	Delete('off_query');
	$server_options{producers_platform} = 1;
	my $debug = '';
	is(can_use_off_query(\$debug), 0, 'disabled on producers platform');
};

# Restore settings
$ProductOpener::Config::query_url = $prev_query_url;
$server_options{producers_platform} = $prev_producers;
Delete('off_query');

done_testing();
