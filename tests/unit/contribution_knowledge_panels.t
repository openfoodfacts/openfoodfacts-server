#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test::More;

use JSON;

use ProductOpener::Test qw/:all/;
use ProductOpener::Display;
use ProductOpener::KnowledgePanelsContribution qw/:all/;

# results of tests are json files
my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

# example product
my %default_product = (
	code => "120989380970",
	product_name => "dummy",
	data_quality_errors_tags =>
		["en:energy-value-in-kcal-does-not-match-value-in-kj", "en:nutrition-saturated-fat-greater-than-fat",],
	knowledge_panels_en => {},
);

# options ref
my %default_options = (
	user_logged_in => 1,
	knowledge_panels_client => "web",
);

my $default_lc = "en";
my $default_cc = "world";

# tests
my @tests = (
	{
		"desc" => "Non logged in users should not see contribution panel",
		"id" => "non_login_users_no_panel",
		"options" => {
			user_logged_in => 0
		}
	},
	{
		"desc" => "Contribution panel is not shown on mobile app",
		"id" => "app_no_panel",
		"options" => {
			knowledge_panels_client => "app",
		}
	},
	{
		"desc" => "If there are no errors, no quality error panel displayed",
		"id" => "no_quality_errors_no_panel",
		"product" => {
			data_quality_errors_tags => [],
		}
	},
	{
		"desc" => "Display of a data quality error panel for default product",
		"id" => "default_product_panel",
	},
);

my $json = JSON->new->allow_nonref->canonical;

foreach my $test_ref (@tests) {
	my $testid = $test_ref->{id};
	my %product = (%default_product, %{$test_ref->{product} // {}});
	my %options = (%default_options, %{$test_ref->{options} // {}});
	# set language
	$ProductOpener::Display::lc = "en";
	# run
	create_contribution_card_panel(
		\%product,
		$test_ref->{"lc"} // $default_lc,
		$test_ref->{"cc"} // $default_cc, \%options
	);
	# we are only interested in knowledge_panels
	my $panels_ref = $product{knowledge_panels_en};
	# compare to reference
	compare_to_expected_results($panels_ref, "$expected_result_dir/$testid.json", $update_expected_results, $test_ref);
}

done_testing();
