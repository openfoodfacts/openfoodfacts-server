#!/usr/bin/perl -w

# The OCR endpoints (cgi/ingredients.pl, cgi/nutrition.pl, cgi/packaging.pl) used to run OCR for
# anonymous callers: each request can cost a call to the Google Cloud Vision API, which is billed.
# They also accepted the OCR engine from a request parameter, so the caller chose who paid.

use ProductOpener::PerlStandards;

use Test2::V0;

use ProductOpener::APITest qw/construct_test_url login new_client wait_application_ready/;
use ProductOpener::Images ();

wait_application_ready(__FILE__);

my @paths = ('/cgi/ingredients.pl', '/cgi/nutrition.pl', '/cgi/packaging.pl');

my $query = 'code=3017620422002&id=ingredients_en&process_image=1';

# An anonymous caller is refused before any OCR is started

my $anonymous_ua = new_client();

foreach my $path (@paths) {
	my $response = $anonymous_ua->get(construct_test_url($path . '?' . $query));
	is($response->code, 403, "$path refuses an anonymous caller");
	like($response->decoded_content, qr/Permission denied/, "$path returns the permission error");
}

# A logged in caller gets past the check, and the OCR engine asked for in the request does not
# select the paid engine

my $ua = new_client();
login($ua, "tests", 'testtest');

foreach my $path (@paths) {
	my $response = $ua->get(construct_test_url($path . '?' . $query . '&ocr_engine=google_cloud_vision'));
	isnt($response->code, 403, "$path does not refuse a logged in caller asking for the paid OCR engine")
		or diag($response->status_line);
}

# The engine that was asked for in the request is ignored: select_ocr_engine() falls back to the
# engine the server wants when the requested one comes from a request parameter.

my $selected = ProductOpener::Images::select_ocr_engine('google_cloud_vision', 1);
my $selected_by_the_server = ProductOpener::Images::select_ocr_engine('google_cloud_vision', 0);

is($selected, $selected_by_the_server, "an engine asked for in a request is not honoured");
is(
	$selected,
	ProductOpener::Images::select_ocr_engine(undef, 0),
	"an engine asked for in a request falls back to the default one"
);

done_testing();
