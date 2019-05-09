#!/usr/bin/perl -w

use Modern::Perl '2012';

use Test::More;
use Log::Any::Adapter 'TAP';

use ProductOpener::SiteQuality qw/:all/;
use ProductOpener::Tags qw/:all/;

# illogically-high-energy-value - does not add tag, if there is no nutriments.
my $product_ref_without_nutriments = {
	lc => "de"
};

ProductOpener::SiteQuality::check_quality($product_ref_without_nutriments);

ok( !has_tag($product_ref_without_nutriments, 'quality', 'illogically-high-energy-value'), 'product does not have illogically-high-energy-value tag as it has no nutrients' );

# illogically-high-energy-value - does not add tag, if there is no energy.
my $product_ref_without_energy_value = {
	lc => "de",
	nutriments => {}
};

ProductOpener::SiteQuality::check_quality($product_ref_without_energy_value);

ok( !has_tag($product_ref_without_energy_value, 'quality', 'illogically-high-energy-value'), 'product does not have illogically-high-energy-value tag as it has no energy_value' );

# illogically-high-energy-value - does not add tag, if energy_value is below 3800
my $product_ref_with_low_energy_value = {
	lc => "de",
	nutriments => {
		energy => 3799
	}
};

ProductOpener::SiteQuality::check_quality($product_ref_with_low_energy_value);

ok( !has_tag($product_ref_with_low_energy_value, 'quality', 'illogically-high-energy-value'), 'product does not have illogically-high-energy-value tag as it has an energy_value below 3800' );

# illogically-high-energy-value - does not add tag, if energy_value is equal 3800
my $product_ref_with_lowish_energy_value = {
	lc => "de",
	nutriments => {
		energy => 3800
	}
};

ProductOpener::SiteQuality::check_quality($product_ref_with_lowish_energy_value);

ok( !has_tag($product_ref_with_lowish_energy_value, 'quality', 'illogically-high-energy-value'), 'product does not have illogically-high-energy-value tag as it has an energy_value of 3800' );

# illogically-high-energy-value - does add tag, if energy_value is above 3800
my $product_ref_with_high_energy_value = {
	lc => "de",
	nutriments => {
		energy => 3801
	}
};

ProductOpener::SiteQuality::check_quality($product_ref_with_high_energy_value);

ok( has_tag($product_ref_with_high_energy_value, 'quality', 'illogically-high-energy-value'), 'product not have illogically-high-energy-value tag as it has an energy_value of 3801' );

done_testing();
