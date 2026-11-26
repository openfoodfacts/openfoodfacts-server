#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use ProductOpener::APITest
	qw/construct_test_url create_user edit_product get_page new_client origin_from_url wait_application_ready/;
use ProductOpener::Test qw/remove_all_products remove_all_users/;
use ProductOpener::TestDefaults qw/%default_product_form %default_user_form/;

use JSON::MaybeXS qw/decode_json encode_json/;
use HTTP::Request::Common;
use Storable qw(dclone);

wait_application_ready(__FILE__);
remove_all_products();
remove_all_users();

my $ua = new_client();
create_user($ua, \%default_user_form);

# 13 digits barcode, so that it is not normalized in urls
my $code = '2000000000101';

# Create a product, then edit it twice
edit_product(
	$ua,
	{
		%{dclone(\%default_product_form)},
		(
			code => $code,
			product_name => "Product with history",
			comment => 'first `version` with "quotes"',
		)
	}
);
edit_product(
	$ua,
	{
		code => $code,
		product_name => "Product with history - edited",
		comment => "second edit",
	}
);

# Third edit through the API v3, which stores the comment as is (product_jqm2.pl escapes quotes before saving),
# with characters that need to be escaped in the knowledge panel JSON: double quote, backslash and backtick
my $api_v3_comment = 'third edit with "quotes", a \\backslash and a `backtick`';
my $api_v3_url = construct_test_url("/api/v3/product/$code");
my $api_v3_response = $ua->request(
	PATCH(
		$api_v3_url,
		Content => encode_json({comment => $api_v3_comment, product => {quantity => "500 g"}}),
		"Content-Type" => "application/json; charset=utf-8",
		"Origin" => origin_from_url($api_v3_url),
	)
);
ok($api_v3_response->is_success, 'edit through the API v3') or diag $api_v3_response->decoded_content;

sub get_knowledge_panels ($client, $query) {
	my $response = get_page($client,
		"/api/v3/product/$code?fields=knowledge_panels&knowledge_panels_included=contribution_card$query");
	return decode_json($response->decoded_content)->{product}{knowledge_panels};
}

subtest 'History panel for logged in user when requested' => sub {
	my $panels_ref = get_knowledge_panels($ua, "&activate_knowledge_panel_product_history=1");
	my $panel_ref = $panels_ref->{product_history};

	ok(defined $panel_ref, 'product_history panel is created');
	ok(!exists $panel_ref->{template_error} && !exists $panel_ref->{json_error}, 'panel template is valid')
		or diag explain $panel_ref;

	ok(
		(
			grep {($_->{panel_element}{panel_id} // '') eq 'product_history'}
				@{$panels_ref->{contribution_card}{elements}}
		),
		'product_history panel is included in the contribution card'
	);

	my $table_ref = $panel_ref->{elements}[0]{table_element};
	is(scalar @{$table_ref->{columns}}, 5, 'table has 5 columns');

	my @rows = @{$table_ref->{rows}};
	is(scalar @rows, 3, 'table has one row per revision');

	# most recent revision first
	is($rows[0]{values}[0]{text}, "3", 'first row is the most recent revision');
	like($rows[0]{values}[0]{url}, qr/^http.*\/product\/$code.*\?rev=3$/, 'revision cell links to the revision');
	like($rows[0]{values}[2]{text}, qr/^tests/, 'contributor is the user who made the edit');
	like($rows[0]{values}[2]{url}, qr/^http.*\/tests$/, 'contributor cell links to the contributor page');
	# the double quote and the backslash are kept, the backticks are replaced
	is(
		$rows[0]{values}[4]{text},
		q{third edit with "quotes", a \backslash and a 'backtick'},
		'comment with characters that need to be escaped in JSON'
	);

	is($rows[1]{values}[0]{text}, "2", 'second row is the previous revision');
	like($rows[1]{values}[4]{text}, qr/second edit$/, 'comment of the previous revision');

	is($rows[2]{values}[0]{text}, "1", 'third row is the first revision');
};

subtest 'No history panel when not requested' => sub {
	my $panels_ref = get_knowledge_panels($ua, "");
	ok(!exists $panels_ref->{product_history}, 'product_history panel is not created');
};

subtest 'No history panel for anonymous users' => sub {
	my $panels_ref = get_knowledge_panels(new_client(), "&activate_knowledge_panel_product_history=1");
	ok(!exists $panels_ref->{product_history}, 'product_history panel is not created');
};

done_testing();
