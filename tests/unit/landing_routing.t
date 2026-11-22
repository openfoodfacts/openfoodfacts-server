#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use Log::Any::Adapter 'TAP';

use ProductOpener::Config qw/%server_options/;
use ProductOpener::Routing;
use ProductOpener::Texts qw/%texts/;

my $cookie_value;
my $skip_value;

my $routing_mock = mock 'ProductOpener::Routing' => (
	override => [
		cookie => sub {return $cookie_value;},
		single_param => sub {return $skip_value;},
	]
);

my @tests = (
	{
		name => 'first visit with landing available',
		texts => {en => 'landing.html'},
		expected => 'landing',
	},
	{
		name => 'landing falls back to English',
		lc => 'fr',
		texts => {en => 'landing.html'},
		expected => 'landing',
	},
	{
		name => 'landing available in requested language',
		lc => 'fr',
		texts => {fr => 'landing.html'},
		expected => 'landing',
	},
	{
		name => 'landing missing',
		expected => 'index',
	},
	{
		name => 'landing unavailable in requested language and English',
		lc => 'fr',
		texts => {es => 'landing.html'},
		expected => 'index',
	},
	{
		name => 'producers platform keeps its homepage',
		private_products => 1,
		texts => {en => 'landing.html'},
		expected => 'index-pro',
	},
	{
		name => 'visitor has already seen the landing',
		cookie => '1',
		texts => {en => 'landing.html'},
		expected => 'index',
	},
	{
		name => 'visitor skips the landing',
		skip => '1',
		texts => {en => 'landing.html'},
		expected => 'index',
	},
	{
		name => 'paginated homepage does not show the landing',
		page => 2,
		texts => {en => 'landing.html'},
		expected => 'index',
	},
);

foreach my $test (@tests) {
	local $texts{landing};
	local $server_options{private_products} = $test->{private_products} // 0;

	if (exists $test->{texts}) {
		$texts{landing} = $test->{texts};
	}
	else {
		delete $texts{landing};
	}

	$cookie_value = $test->{cookie};
	$skip_value = $test->{skip};

	my $request_ref = {
		lc => $test->{lc} // 'en',
		param => {},
		stats => {},
	};

	if (exists $test->{page}) {
		$request_ref->{param}{page} = $test->{page};
	}

	ProductOpener::Routing::index_route($request_ref);

	is($request_ref->{text}, $test->{expected}, $test->{name});
}

done_testing();
