#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test::More;
use Log::Any::Adapter 'TAP';

use ProductOpener::Test qw/:all/;
use ProductOpener::TestDefaults qw/:all/;

use ProductOpener::ContributionKnowledgePanels qw/:all/;

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));


my @tests = (
    {
		id => "no_tag_no_error_no_panel",
		desc => "No quality errors means no panel",
        product => {data_quality_errors_tags => []},
	},
    {
		id => "no_user_no_panel",
		desc => "No panel if user is not logged in",
        product => {data_quality_errors_tags => ["en:energy-value-in-kcal-does-not-match-value-in-kj"]},
        options => {user_logged_in => undef},
	},
    {
		id => "not_web_no_panel",
		desc => "No panel if not from web",
        product => {data_quality_errors_tags => ["en:energy-value-in-kcal-does-not-match-value-in-kj"]},
        options => {knowledge_panels_client => "mobile"},
	},
    {
		id => "one_error_one_action",
		desc => "A panel with one error of one action type",
        product => {data_quality_errors_tags => ["en:energy-value-in-kcal-does-not-match-value-in-kj"]},
    },
    {
		id => "one_error_no_action",
		desc => "A panel with one error and no action",
        product => {data_quality_errors_tags => ["en:nutri-score-grade-from-label-does-not-match-calculated-grade"]},
    },
    {
		id => "many_error_many_actions",
		desc => "A panel with multiple actions and multiple errors",
        product => {data_quality_errors_tags => [
            "en:energy-value-in-kcal-does-not-match-value-in-kj",
            "en:nutrition-saturated-fat-greater-than-fat",
            "en:nutrition-sugars-plus-starch-greater-than-carbohydrates",
            "en:detected-category-from-name-and-ingredients-may-be-missing-baby-milks",
            "en:nutri-score-grade-from-label-does-not-match-calculated-grade",
        ]},
	},
    {
		id => "errors_but_no_actions",
		desc => "A panel for a product with errors but no actions",
        product => {data_quality_errors_tags => [
            "en:nutri-score-grade-from-label-does-not-match-calculated-grade",
        ]},
	}
    # FIXME: add test on show_to ?
    # TODO: add test where there is an error but no description ? (we have none yet)
);

my %default_options = (user_logged_in => 1, knowledge_panels_client => 'web');

foreach my $test_ref (@tests) {
    my $test_id = $test_ref->{id};
    my %product = (%default_product, %{$test_ref->{product} // {}});
    my %options = (%default_options, %{$test_ref->{options} // {}});
    create_data_quality_panel("data_quality_errors", \%product, "en", "world", \%options);
    my $panels_ref = $product{"knowledge_panels_en"};
    compare_to_expected_results($panels_ref, "$expected_result_dir/$test_id.json", $update_expected_results, $test_ref);
}

done_testing();