#!/usr/bin/perl -w

# A return url (the "redirect" parameter of cgi/login.pl, the "return_url" parameter of the sign
# in, the return url of the sign out, and the referer of cgi/session.pl) is copied into a Location
# header, so it has to be one of our own urls. The check it was compared with was a prefix match
# without an end anchor, so a host suffixed to ours passed it.

use ProductOpener::PerlStandards;

use Test2::V0;
use URI::Escape::XS qw/uri_escape/;

use ProductOpener::APITest qw/construct_test_url login new_client wait_application_ready create_user/;
use ProductOpener::Test qw/remove_all_users/;
use ProductOpener::TestDefaults qw/%default_user_form/;
use ProductOpener::Auth qw/is_allowed_return_url/;
use ProductOpener::Config qw/$server_domain/;

wait_application_ready(__FILE__);
remove_all_users();

my $ua = new_client();

my %create_user_args = (%default_user_form, (email => 'bob@example.com'));
create_user($ua, \%create_user_args);

my $our_url = "https://world.$server_domain/cgi/product.pl";

# Urls of the site we serve are allowed

foreach my $url (
	$our_url,
	"https://world.$server_domain",
	"https://world.$server_domain/?code=1",
	"http://world.$server_domain/cgi/session.pl",    # http is accepted, as before
	"https://world.$server_domain:8080/cgi/product.pl",
	"https://fr.$server_domain/cgi/product.pl",    # a url on a language subdomain
	)
{
	ok(is_allowed_return_url($url), "'$url' is one of our urls");
}

# Urls that are not ours are refused. The first ones are the ones the prefix match accepted.
my $other_domain = $server_domain =~ s/openfoodfacts/openpetfoodfacts/;

my @refused = (
	["https://world.$server_domain.evil.example/steal", 'a host suffixed to ours'],
	["http://world.$server_domain.evil.example/", 'the same over http'],
	["https://world.$server_domain\@evil.example/", 'a userinfo part in front of another host'],
	["https://world.$server_domain%2eevil.example/", 'a percent encoded dot'],
	["https://evil.example/world.$server_domain", 'our domain as a path'],
	["https://evil.example/", 'another host'],
	['//world.' . $server_domain . '/cgi/product.pl', 'a protocol relative url'],
	["/cgi/product.pl", 'a relative url'],
	["javascript:alert(1)", 'a javascript url'],
	["", 'an empty url'],
	[undef, 'no url'],
	# only the subdomain of the request is accepted, not any of ours
	["https://world.$other_domain/cgi/product.pl", 'a url on another of our subdomains'],
);

foreach my $case (@refused) {
	my ($url, $desc) = @{$case};
	my $shown = defined $url ? $url : '(undef)';
	ok(not(is_allowed_return_url($url)), "$desc is refused: '$shown'");
}

# The subdomain is compared as a string, not inserted into a regex pattern: with a subdomain that
# contains a dot, a host that only looks like it matches must still be refused

ok(
	not(is_allowed_return_url("https://pro.world.$server_domain/cgi/product.pl")),
	'a url on the expected host of a dotted subdomain is not allowed'
);

# Through the endpoint: cgi/login.pl copied the redirect parameter into a Location header without
# any check at all

$ua = new_client();
login($ua, "tests", 'testtest');
# do not follow the redirect: we check the Location header of the response itself
$ua->max_redirect(0);

my $response = $ua->get(construct_test_url('/cgi/login.pl?redirect=' . uri_escape($our_url)));
is($response->header('Location'), $our_url, "login.pl redirects to our own url");

foreach my $target ("https://world.$server_domain.evil.example/steal", "https://evil.example/") {
	$response = $ua->get(construct_test_url('/cgi/login.pl?redirect=' . uri_escape($target)));
	my $location = $response->header('Location') // '';
	isnt($location, $target, "login.pl does not redirect to '$target'");
	isnt($location, $target . '/', "login.pl does not redirect to '$target/'");
}

done_testing();
