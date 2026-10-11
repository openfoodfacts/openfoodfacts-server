#!/usr/bin/perl -w

# cgi/sugar_random.pl reads the X-Site-Lang header and uses it as a directory name below
# $BASE_DIRS{PRIVATE_DATA}/sugar/. nginx sets that header from the site name for the howmuchsugar
# virtual hosts, but the script is served by the other virtual hosts as well, and those pass the
# headers of the request through, so the value has to be checked before it goes into a path.
#
# Note: the howmuchsugar data files are not part of the test environment, so a request with a valid
# language code still ends in the "Cannot open sugar/products_ids.sto" error. What is checked here
# is that a valid code is not turned away by the new check, and that a code that walks out of the
# sugar directory is.

use ProductOpener::PerlStandards;

use Test2::V0;

use ProductOpener::APITest qw/new_client construct_test_url wait_application_ready/;

wait_application_ready(__FILE__);

my $ua = new_client();

# A language code goes through the check and on to the data file

foreach my $lang ('en', 'fr') {
	my $response = $ua->get(construct_test_url('/cgi/sugar_random.pl'), 'X-Site-Lang' => $lang);
	isnt($response->code, 400, "the language code '$lang' is accepted");
}

# A value that walks out of the sugar directory is refused

foreach my $case (
	["../../../../etc/passwd", 'a path traversal'],
	["../en", 'a relative directory'],
	["en/../../en", 'a traversal in the middle'],
	["en/en/en", 'a deeper path'],
	["", 'an empty value'],
	["EN", 'an uppercase code'],
	["e n", 'a code with a space'],
	) {

	my ($lang, $desc) = @{$case};

	my $response = $ua->get(construct_test_url('/cgi/sugar_random.pl'), 'X-Site-Lang' => $lang);
	is($response->code, 400, "$desc is refused with a 400: '$lang'");
}

# The refused value is not echoed back with the path it built, which would answer the question the
# traversal asks: does this file exist

my $response = $ua->get(construct_test_url('/cgi/sugar_random.pl'), 'X-Site-Lang' => '../../../../etc/passwd');
my $body = $response->decoded_content // '';
unlike($body, qr/products_ids\.sto/, "the refused value is not echoed back with the path it built");
unlike($body, qr/passwd/, "the refused value is not echoed back at all");

done_testing();