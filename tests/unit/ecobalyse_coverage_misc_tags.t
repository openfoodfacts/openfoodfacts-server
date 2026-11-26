#!/usr/bin/perl -w

# Tests for set_ecobalyse_coverage_misc_tags function

use Test2::V0;
use ProductOpener::PerlStandards;
use ProductOpener::Test qw/init_expected_results compare_to_expected_results/;
use ProductOpener::EnvironmentalImpact qw/set_ecobalyse_coverage_misc_tags/;
use ProductOpener::LoadData qw/load_data/;

load_data();

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

subtest "set_ecobalyse_coverage_misc_tags - 0%" => sub {
	my $product_ref = {
		environmental_impact => {
			ecobalyse_input => {
				ingredients_coverage_percent => 0,
			}
		},
		misc_tags => [],
	};
	set_ecobalyse_coverage_misc_tags($product_ref);
	is($product_ref->{misc_tags}, ["en:ecobalyse-ingredients-matched-between-0-and-9"], "0% maps to 0-9 range");
};

subtest "set_ecobalyse_coverage_misc_tags - 5%" => sub {
	my $product_ref = {
		environmental_impact => {
			ecobalyse_input => {
				ingredients_coverage_percent => 5,
			}
		},
		misc_tags => [],
	};
	set_ecobalyse_coverage_misc_tags($product_ref);
	is($product_ref->{misc_tags}, ["en:ecobalyse-ingredients-matched-between-0-and-9"], "5% maps to 0-9 range");
};

subtest "set_ecobalyse_coverage_misc_tags - 9%" => sub {
	my $product_ref = {
		environmental_impact => {
			ecobalyse_input => {
				ingredients_coverage_percent => 9,
			}
		},
		misc_tags => [],
	};
	set_ecobalyse_coverage_misc_tags($product_ref);
	is($product_ref->{misc_tags}, ["en:ecobalyse-ingredients-matched-between-0-and-9"], "9% maps to 0-9 range");
};

subtest "set_ecobalyse_coverage_misc_tags - 10%" => sub {
	my $product_ref = {
		environmental_impact => {
			ecobalyse_input => {
				ingredients_coverage_percent => 10,
			}
		},
		misc_tags => [],
	};
	set_ecobalyse_coverage_misc_tags($product_ref);
	is($product_ref->{misc_tags}, ["en:ecobalyse-ingredients-matched-between-10-and-19"], "10% maps to 10-19 range");
};

subtest "set_ecobalyse_coverage_misc_tags - 19%" => sub {
	my $product_ref = {
		environmental_impact => {
			ecobalyse_input => {
				ingredients_coverage_percent => 19,
			}
		},
		misc_tags => [],
	};
	set_ecobalyse_coverage_misc_tags($product_ref);
	is($product_ref->{misc_tags}, ["en:ecobalyse-ingredients-matched-between-10-and-19"], "19% maps to 10-19 range");
};

subtest "set_ecobalyse_coverage_misc_tags - 50%" => sub {
	my $product_ref = {
		environmental_impact => {
			ecobalyse_input => {
				ingredients_coverage_percent => 50,
			}
		},
		misc_tags => [],
	};
	set_ecobalyse_coverage_misc_tags($product_ref);
	is($product_ref->{misc_tags}, ["en:ecobalyse-ingredients-matched-between-50-and-59"], "50% maps to 50-59 range");
};

subtest "set_ecobalyse_coverage_misc_tags - 90%" => sub {
	my $product_ref = {
		environmental_impact => {
			ecobalyse_input => {
				ingredients_coverage_percent => 90,
			}
		},
		misc_tags => [],
	};
	set_ecobalyse_coverage_misc_tags($product_ref);
	is($product_ref->{misc_tags}, ["en:ecobalyse-ingredients-matched-between-90-and-100"], "90% maps to 90-100 range");
};

subtest "set_ecobalyse_coverage_misc_tags - 100%" => sub {
	my $product_ref = {
		environmental_impact => {
			ecobalyse_input => {
				ingredients_coverage_percent => 100,
			}
		},
		misc_tags => [],
	};
	set_ecobalyse_coverage_misc_tags($product_ref);
	is($product_ref->{misc_tags}, ["en:ecobalyse-ingredients-matched-between-90-and-100"], "100% maps to 90-100 range");
};

subtest "set_ecobalyse_coverage_misc_tags - replaces existing" => sub {
	my $product_ref = {
		environmental_impact => {
			ecobalyse_input => {
				ingredients_coverage_percent => 50,
			}
		},
		misc_tags => ["en:ecobalyse-ingredients-matched-between-0-and-9", "en:other-tag"],
	};
	set_ecobalyse_coverage_misc_tags($product_ref);
	is(
		$product_ref->{misc_tags},
		["en:other-tag", "en:ecobalyse-ingredients-matched-between-50-and-59"],
		"replaces existing ecobalyse coverage tags, keeps others"
	);
};

subtest "set_ecobalyse_coverage_misc_tags - no coverage data" => sub {
	my $product_ref = {
		environmental_impact => {
			ecobalyse_input => {},
		},
		misc_tags => ["en:some-tag"],
	};
	set_ecobalyse_coverage_misc_tags($product_ref);
	is($product_ref->{misc_tags}, ["en:some-tag"], "does nothing when no coverage data");
};

subtest "set_ecobalyse_coverage_misc_tags - no environmental_impact" => sub {
	my $product_ref = {misc_tags => ["en:some-tag"],};
	set_ecobalyse_coverage_misc_tags($product_ref);
	is($product_ref->{misc_tags}, ["en:some-tag"], "does nothing when no environmental_impact");
};

done_testing();
