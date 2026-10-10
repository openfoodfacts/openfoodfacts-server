#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test2::V0;
use Log::Any::Adapter 'TAP';

use ProductOpener::Config qw/:all/;
use ProductOpener::KnowledgePanels;
use ProductOpener::Lang qw/$lc/;
use ProductOpener::Web qw/display_knowledge_panel/;

$options{product_type} = 'product';

{
	my @created_panels;
	my $knowledge_panels_mock = mock 'ProductOpener::KnowledgePanels' => (
		override => [
			'display_taxonomy_tag_name' => sub {return "Test category";},
			'create_epargnonsnosressources_panel' => sub {return 0;},
			'create_qfdmo_fr_panel' => sub {return 0;},
			'create_panel_from_json_template' => sub {
				my ($panel_id, $template, $panel_data_ref) = @_;
				push @created_panels, {id => $panel_id, template => $template, data => {%$panel_data_ref}};
				return;
			},
		]
	);

	foreach my $product_ref ({knowledge_panels_en => {}}, {categories_tags => [], knowledge_panels_en => {}},) {
		@created_panels = ();
		is(ProductOpener::KnowledgePanels::create_secondhand_card_panel($product_ref, "en", "us", {}, {}),
			1, "create a secondhand card action without a category");
		is(
			\@created_panels,
			[
				{
					id => "secondhand_card",
					template => "api/knowledge-panels/secondhand/secondhand_card.tt.json",
					data => {has_category => 0}
				}
			],
			"create only the secondhand card action"
		);
	}

	@created_panels = ();
	my $product_ref = {categories_tags => ["en:test-category"], knowledge_panels_en => {}};
	is(ProductOpener::KnowledgePanels::create_secondhand_card_panel($product_ref, "en", "us", {}, {}),
		1, "create the secondhand card when a category is present");
	is(
		[map {$_->{id}} @created_panels],
		[
			"donated_products_fr_geev", "donated_products", "used_products_fr_backmarket", "used_products",
			"secondhand_card"
		],
		"create all secondhand panels"
	);
	is(
		$created_panels[-1]{data},
		{category_name => "Test category", has_category => 1},
		"pass the category data to the secondhand card"
	);
}

# Exercise the real JSON and HTML templates: the mocked tests above cannot
# detect a missing nudge or a broken link in the rendered card.
{
	local $lc = 'en';
	foreach my $categories (undef, []) {
		my $product_ref = {code => '1234567890123', knowledge_panels_en => {}};
		$product_ref->{categories_tags} = $categories if defined $categories;
		ProductOpener::KnowledgePanels::create_secondhand_card_panel($product_ref, 'en', 'us', {}, {lc => 'en'});
		my $panels_ref = $product_ref->{knowledge_panels_en};
		is(
			$panels_ref->{secondhand_card}{elements},
			[
				{
					element_type => 'action',
					action_element => {
						html => 'Add a category to discover secondhand options.',
						actions => ['add_categories'],
					},
				}
			],
			'uncategorized product exposes the category nudge as a Knowledge Panel action'
		);
		my $html = display_knowledge_panel($product_ref, $panels_ref, 'secondhand_card');
		like($html, qr/Add a category to discover secondhand options\./, 'render the nudge text');
		like(
			$html,
			qr{href="/cgi/product\.pl\?type=edit&code=1234567890123\#categories"},
			'link the action to the Categories field'
		);
		like($html, qr/>\s*Add a category\s*<\/a>/, 'render the category action button');
	}
}

done_testing();
