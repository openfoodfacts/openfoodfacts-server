#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test2::V0;
use Log::Any::Adapter 'TAP';

use ProductOpener::Lang qw/$lc/;
use ProductOpener::KnowledgePanels qw/create_maintain_card_panel/;
use ProductOpener::Test qw/init_expected_results compare_to_expected_results/;

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

{
	# a special code with no eparnonnosressources property used by mocking
	my $no_epargnonsnosressources_link = "2000000000001";

	my $tag_mock = mock 'ProductOpener::KnowledgePanels' => (
		override => [
			'get_inherited_property_from_categories_tags' => sub {
				my ($product_ref, $inherited_property_name) = @_;
				# validate argument
				is($inherited_property_name, "epargnonsnosressources_fr_link:en");
				# mock, returning undef for no_epargnonsnosressources_link code
				if ($product_ref->{code} eq $no_epargnonsnosressources_link) {
					return (undef, undef);
				}
				else {
					return ("https://epargnonsnosressources.gouv.fr/entretien/centrale-vapeur-ou-fer-a-repasser/",
						"en:irons-ironing-systems");
				}
			},
			'display_taxonomy_tag_name' => sub {
				my ($lc, $taxonomy, $tagid) = @_;
				is($lc, "fr");
				is($taxonomy, "categories");
				is($tagid, "en:test-category");
				return "Test category";
			},
		]
	);

	my $only_code_and_kp_fr = bag {
		item 'code';
		item 'knowledge_panels_fr';
		end();
	};

	my $base_product_ref = {
		code => "3000000000042",
		categories_hierarchy => ["en:generic", "en:test-category"],
		knowledge_panels_fr => {}
	};

	# edge cases
	# not for food
	my $product_ref = {%$base_product_ref};
	is(create_maintain_card_panel($product_ref, "fr", "fr", {product_type => 'food'}, {}), 0);
	is($product_ref, $base_product_ref);
	# must have a category
	$product_ref = {%$base_product_ref, categories_hierarchy => []};
	is(create_maintain_card_panel($product_ref, "fr", "fr", {product_type => 'product'}, {}), 0);
	is($product_ref, {%$base_product_ref, categories_hierarchy => []});
	# only for france
	$product_ref = {%$base_product_ref};
	is(create_maintain_card_panel({}, "fr", "es", {product_type => 'product'}, {}), 0);
	is($product_ref, $base_product_ref);
	# no property, no panel
	$product_ref = {%$base_product_ref, code => $no_epargnonsnosressources_link};
	is(create_maintain_card_panel($product_ref, "fr", "es", {product_type => 'product'}, {}), 0);
	is($product_ref, {%$base_product_ref, code => $no_epargnonsnosressources_link});
	# working tests
	$lc = "fr";    # set global lc because templates use this…
	$product_ref = {%$base_product_ref};
	is(create_maintain_card_panel($product_ref, 'fr', 'fr', {product_type => 'product'}, {}), 1);
	is(
		{%$product_ref, knowledge_panels_fr => "ignore"},
		{%$base_product_ref, knowledge_panels_fr => "ignore"},
		"Only knowlegde_panels_fr differs"
	);
	compare_to_expected_results(
		$product_ref->{knowledge_panels_fr},
		$expected_result_dir . "/epargnonsnosressources.json",
		$update_expected_results, {id => "epargnonsnosressources"}
	);
}
# reset qlobal language code
$lc = "en";

done_testing();

