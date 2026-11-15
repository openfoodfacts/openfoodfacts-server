#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use Test2::Tools::Mock qw(mock);

use ProductOpener::Test qw/compare_to_expected_results init_expected_results/;
use ProductOpener::Display;
use ProductOpener::Lang qw/$lc/;
use ProductOpener::LoadData qw/load_data/;
use ProductOpener::KnowledgePanelsProduct qw/create_product_card_panel create_sources_manufacturer_panel/;

load_data();

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

my $mock = mock 'ProductOpener::KnowledgePanelsProduct';

my %default_product = (
	code => "120989380970",
	conservation_conditions => "Keep in a cool place",
	conservation_conditions_en => "Keep refrigerated",
	customer_service_en => "Call us",
	owner => "org-test-org",
);

my %default_options = (activate_knowledge_panel_product_information => 1);

my @tests = (
	{id => "flag_off", options => {activate_knowledge_panel_product_information => 0}},
	{id => "flag_on_with_fields"},
	{
		id => "flag_on_without_fields",
		product => {conservation_conditions => undef, conservation_conditions_en => undef, customer_service_en => ''}
	},
	{
		id => "language_fallback",
		lc => "fr",
		product => {conservation_conditions_fr => '', customer_service => "Appelez-nous"}
	},
	{id => "owner_org"},
	{id => "owner_org_missing", product => {owner => "org-unknown"}},
	{id => "owner_not_org", product => {owner => "some-user"}},
	{id => "producers_platform", options => {producers_platform => 1}},
	{
		id => "free_text_escaping",
		product => {
			conservation_conditions_en => "Keep `cool` \"dry\"\ here\n// and there",
			owner => "org-test-org",
		},
		org_name => "Org `quoted`",
	},
);

my %results;

foreach my $test_ref (@tests) {
	my %product
		= (%default_product, %{$test_ref->{product} // {}}, knowledge_panels_en => {}, knowledge_panels_fr => {});
	my %options = (%default_options, %{$test_ref->{options} // {}});
	my $target_lc = $test_ref->{lc} // "en";
	$lc = $target_lc;

	$mock->override(
		retrieve_org => sub ($org_id) {
			return $org_id eq 'test-org' ? {name => $test_ref->{org_name} // "Test org"} : undef;
		}
	);

	create_product_card_panel(\%product, $target_lc, "world", \%options, {});
	create_sources_manufacturer_panel(\%product, $target_lc, "world", \%options, {});

	$results{$test_ref->{id}} = $product{"knowledge_panels_$target_lc"};
}

compare_to_expected_results(\%results, "$expected_result_dir/product_information_panels.json",
	$update_expected_results, {id => "product_information_panels"});

done_testing();
