#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test::More;
use Log::Any::Adapter 'TAP';

use ProductOpener::KnowledgePanels qw/:all/;

is(
	ProductOpener::KnowledgePanels::convert_multiline_string_to_singleline('
test
muti-line string
a slash A / B and anti-slash \
HTML <a href="https://url.com">test</a>
'),
	'"\ntest\nmuti-line string\na slash A / B and anti-slash \\\\\nHTML <a href=\"https://url.com\">test</a>\n"'
);

is(
	ProductOpener::KnowledgePanels::convert_multiline_string_to_singleline(
		'<a href="https://agribalyse.ademe.fr/app/aliments/[% product.ecoscore_data.agribalyse.code %]">'),
	'"<a href=\"https://agribalyse.ademe.fr/app/aliments/[% product.ecoscore_data.agribalyse.code %]\">"'
);

done_testing();
