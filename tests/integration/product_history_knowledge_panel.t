#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use ProductOpener::APITest qw/create_user edit_product get_page new_client wait_application_ready/;
use ProductOpener::Test qw/remove_all_products remove_all_users/;
use ProductOpener::TestDefaults qw/%default_product_form %default_user_form/;

use JSON::MaybeXS qw/decode_json/;
use Storable qw(dclone);

wait_application_ready(__FILE__);
remove_all_products();
remove_all_users();

my $ua = new_client();
create_user($ua, \%default_user_form);

my $code = '200000000101';

# Create a product, then edit it, with comments that need to be escaped in the knowledge panel JSON
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
	is(scalar @rows, 2, 'table has one row per revision');

	# most recent revision first
	is($rows[0]{values}[0]{text}, "2", 'first row is the most recent revision');
	like($rows[0]{values}[0]{url}, qr/^http.*\/product\/$code.*\?rev=2$/, 'revision cell links to the revision');
	like($rows[0]{values}[2]{text}, qr/^tests/, 'contributor is the user who made the edit');
	like($rows[0]{values}[2]{url}, qr/^http.*\/tests$/, 'contributor cell links to the contributor page');
	like($rows[0]{values}[4]{text}, qr/second edit$/, 'comment of the most recent revision');

	is($rows[1]{values}[0]{text}, "1", 'second row is the first revision');
	like($rows[1]{values}[4]{text}, qr/first 'version' with/, 'backticks in comments are replaced');
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
