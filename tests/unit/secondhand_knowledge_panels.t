#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test2::V0;
use Log::Any::Adapter 'TAP';

use ProductOpener::Config qw/:all/;
use ProductOpener::KnowledgePanels;

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

done_testing();
