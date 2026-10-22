#!/usr/bin/perl -w

# A product field interpolated inside a backtick-delimited block of a knowledge panel template is
# escaped by convert_multiline_string_to_singleline() in ProductOpener::KnowledgePanels. That
# escaper handles quotes, backslashes and line breaks, but not tab and the other control
# characters, which JSON does not allow unescaped inside a string: the panel JSON then does not
# parse and the panel is replaced by a json_error entry.
#
# The response of the API itself stays valid JSON, because it is re-encoded after the panel has
# been built, so the check is on the panel content, not on the response.

use ProductOpener::PerlStandards;

use Test2::V0;
use JSON::MaybeXS;
use ProductOpener::APITest qw/edit_product login new_client construct_test_url wait_application_ready create_user/;
use ProductOpener::Test qw/remove_all_products/;
use ProductOpener::TestDefaults qw/%default_product_form %default_user_form/;

use Storable qw(dclone);

wait_application_ready(__FILE__);
remove_all_products();
remove_all_users();

my $ua = new_client();

my %create_user_args = (%default_user_form, (email => 'bob@example.com'));
create_user($ua, \%create_user_args);

login($ua, "tests", 'testtest');

# The serving_size panel template interpolates product.serving_size inside a backtick block, so
# the values below go through that escaper
my @cases = (
	["200000000501", '100 g', "a plain value"],
	["200000000502", "100 g\tper packet", "a value with a tab"],
	["200000000503", "100 g\x01per packet", "a value with a control character"],
	["200000000504", '100 g\\', "a value with a trailing backslash"],
	["200000000505", 'a\\"b', "a value with a backslash before a quote"],
);

foreach my $case (@cases) {
	my ($code, $serving_size, $desc) = @{$case};
	edit_product(
		$ua,
		{
			%{dclone(\%default_product_form)},
			code => $code,
			product_name => "Product $code",
			(countries => 'en:united-states'),
			ingredients_en => 'sugar, water',
			serving_size => $serving_size,
		}
	);

	my $response
		= $ua->get(construct_test_url("/api/v2/product/$code?fields=knowledge_panels&knowledge_panels_client=web"));
	is($response->code, 200, "$desc: the request is served");

	my $response_ref = eval {JSON::MaybeXS::decode_json($response->decoded_content)};
	if (not defined $response_ref) {
		fail("$desc: the response is valid JSON");
		next;
	}

	my $panel_ref = $response_ref->{product}{knowledge_panels}{serving_size};
	if (not defined $panel_ref) {
		diag("$desc: no serving_size panel");
		fail("$desc: the serving_size panel is built");
		next;
	}

	is($panel_ref->{json_error}, undef, "$desc: the panel JSON is valid")
		or diag("json_error: " . substr($panel_ref->{json_error}, 0, 120));
}

done_testing();
