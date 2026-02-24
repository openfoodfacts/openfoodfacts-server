#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test2::V0;
use Log::Any::Adapter 'TAP';

use ProductOpener::Lang qw/$lc/;
use ProductOpener::KnowledgePanels;
use ProductOpener::Test qw/init_expected_results compare_to_expected_results/;
use ProductOpener::Config qw/:all/;

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

{
	# a special code with no QFDMO category used by mocking
	my $no_qfdmo_code = "2000000000001";

	my $tag_mock = mock 'ProductOpener::KnowledgePanels' => (
		override => [
			'get_inherited_property_from_categories_tags' => sub {
				my ($product_ref, $inherited_property_name) = @_;
				# validate argument
				is($inherited_property_name, "qfdmo_id:fr");
				if ($product_ref->{code} eq $no_qfdmo_code) {
					return (undef, undef);
				}
				else {
					return ("test-category", "en:test-category");
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

	# edge cases
	# not for food
	my $product_ref = {};
	$options{product_type} = 'food';
	is(ProductOpener::KnowledgePanels::create_qfdmo_fr_panel($product_ref, "fr", "fr", {}, {}), 0);
	is($product_ref, {});
	# only for france
	$options{product_type} = 'product';
	is(ProductOpener::KnowledgePanels::create_qfdmo_fr_panel({}, "fr", "es", {}, {}), 0);
	is($product_ref, {});
	# no property, no panel
	$product_ref = {code => $no_qfdmo_code, knowledge_panels_fr => {}};
	is(ProductOpener::KnowledgePanels::create_qfdmo_fr_panel($product_ref, "fr", "es", {}, {}), 0);
	is([keys(%{$product_ref})], $only_code_and_kp_fr);
	is($product_ref->{knowledge_panels_fr}, {});
	# working tests
	$lc = "fr";    # set global lc because templates use this…
	$product_ref = {code => "2000000000052", knowledge_panels_fr => {}};
	is(ProductOpener::KnowledgePanels::create_qfdmo_fr_panel($product_ref, 'fr', 'fr', {}, {}), 1);
	is([keys(%{$product_ref})], $only_code_and_kp_fr);
	compare_to_expected_results(
		$product_ref->{knowledge_panels_fr},
		$expected_result_dir . "/qfdmo_reuse.json",
		$update_expected_results, {id => "qfdmo_reuse"}
	);
}
# reset qlobal language code
$lc = "en";

done_testing();

