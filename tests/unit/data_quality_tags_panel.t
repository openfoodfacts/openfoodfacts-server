#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test::More;
use Log::Any::Adapter 'TAP';

use ProductOpener::Display;

use ProductOpener::Test qw/:all/;
use ProductOpener::TestDefaults qw/:all/;

use ProductOpener::KnowledgePanelsContribution qw/:all/;

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

my @tests = (
	{
		id => "no_tag_no_error_no_panel",
		desc => "No quality errors means no panel",
		tag_type => "data_quality_errors",
		product => {data_quality_errors_tags => []},
	},
	{
		id => "no_user_no_panel",
		desc => "No panel if user is not logged in",
		tag_type => "data_quality_errors",
		product => {data_quality_errors_tags => ["en:energy-value-in-kcal-does-not-match-value-in-kj"]},
		options => {user_logged_in => undef},
	},
	{
		id => "not_web_no_panel",
		tag_type => "data_quality_errors",
		desc => "No panel if not from web",
		product => {data_quality_errors_tags => ["en:energy-value-in-kcal-does-not-match-value-in-kj"]},
		options => {knowledge_panels_client => "mobile"},
	},
	{
		id => "one_error_one_action",
		desc => "A panel with one error of one action type",
		tag_type => "data_quality_errors",
		product => {data_quality_errors_tags => ["en:energy-value-in-kcal-does-not-match-value-in-kj"]},
	},
	{
		id => "one_warning_one_action",
		desc => "A panel with one warning of one action type",
		tag_type => "data_quality_warnings",
		product =>
			{data_quality_warnings_tags => ["en:nutri-score-score-from-producer-does-not-match-calculated-score"]},
	},
	{
		id => "one_info",
		desc => "A panel with one info",
		tag_type => "data_quality_info",
		product => {data_quality_info_tags => ["en:nutrition-data-prepared"]},
	},
	{
		id => "one_error_no_action",
		tag_type => "data_quality_errors",
		desc => "A panel with one error and no action",
		product => {data_quality_errors_tags => ["en:nutri-score-grade-from-label-does-not-match-calculated-grade"]},
	},
	{
		id => "many_error_many_actions",
		desc => "A panel with multiple actions and multiple errors",
		tag_type => "data_quality_errors",
		product => {
			data_quality_errors_tags => [
				"en:energy-value-in-kcal-does-not-match-value-in-kj",
				"en:nutrition-saturated-fat-greater-than-fat",
				"en:nutrition-sugars-plus-starch-greater-than-carbohydrates",
				"en:detected-category-from-name-and-ingredients-may-be-missing-baby-milks",
				"en:nutri-score-grade-from-label-does-not-match-calculated-grade",
			]
		},
	},
	{
		id => "errors_but_no_actions",
		desc => "A panel for a product with errors but no actions",
		tag_type => "data_quality_errors",
		product => {data_quality_errors_tags => ["en:nutri-score-grade-from-label-does-not-match-calculated-grade",]},
	},
	{
		id => "warnings_inherited_description",
		desc => "A panel for a product with warnings that have an inherited description",
		tag_type => "data_quality_warnings",
		product => {data_quality_warnings_tags => ["en:all-but-one-ingredient-with-specified-percent",]},
	}
	# FIXME: add test on show_to ?
);

my %default_options = (user_logged_in => 1, knowledge_panels_client => 'web');

foreach my $test_ref (@tests) {
	my $test_id = $test_ref->{id};
	my %product = (%default_product, %{$test_ref->{product} // {}});
	my %options = (%default_options, %{$test_ref->{options} // {}});
	# set language
	$ProductOpener::Display::lc = "en";
	# run
	create_data_quality_panel($test_ref->{tag_type}, \%product, "en", "world", \%options);
	my $panels_ref = $product{"knowledge_panels_en"};
	compare_to_expected_results($panels_ref, "$expected_result_dir/$test_id.json", $update_expected_results, $test_ref);
}

done_testing();
