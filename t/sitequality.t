#!/usr/bin/perl -w

use Modern::Perl '2012';

use Test::More;
use Log::Any::Adapter 'TAP';

use ProductOpener::SiteQuality qw/:all/;
use ProductOpener::Tags qw/:all/;

sub check_quality_and_test_product_has_quality_tag($$$$) {
	my $product_ref = shift;
	my $tag = shift;
	my $reason = shift;
	my $yesno = shift;
	ProductOpener::SiteQuality::check_quality($product_ref);
	if ($yesno){
		ok( has_tag($product_ref, 'quality', $tag), $reason );
	}
	else {
		ok( !has_tag($product_ref, 'quality', $tag), $reason );
	}
}

sub product_with_energy_has_quality_tag($$$) {
	my $energy = shift;
	my $reason = shift;
	my $yesno = shift;

	my $product_ref = {
		lc => "de",
		nutriments => {
			energy => $energy
		}
	};

	check_quality_and_test_product_has_quality_tag($product_ref, 'illogically-high-energy-value', $reason, $yesno);
}

sub product_with_code_has_quality_tag($$$$) {
	my $code = shift;
	my $tag = shift;
	my $reason = shift;
	my $yesno = shift;

	my $product_ref = {
		code => $code
	};

	check_quality_and_test_product_has_quality_tag($product_ref, $tag, $reason, $yesno);
}

# illogically-high-energy-value - does not add tag, if there is no nutriments.
my $product_ref_without_nutriments = {
	lc => "de"
};
check_quality_and_test_product_has_quality_tag($product_ref_without_nutriments, 'illogically-high-energy-value', 'product does not have illogically-high-energy-value tag as it has no nutrients', 0);

# illogically-high-energy-value - does not add tag, if there is no energy.
my $product_ref_without_energy_value = {
	lc => "de",
	nutriments => {}
};
check_quality_and_test_product_has_quality_tag($product_ref_without_energy_value, 'illogically-high-energy-value', 'product does not have illogically-high-energy-value tag as it has no energy_value', 0);

# illogically-high-energy-value - does not add tag, if energy_value is below 3800 - 3799
product_with_energy_has_quality_tag(3799, 'product does not have illogically-high-energy-value tag as it has an energy_value below 3800: 3799', 0);

# illogically-high-energy-value - does not add tag, if energy_value is below 3800 - 40
product_with_energy_has_quality_tag(40, 'product does not have illogically-high-energy-value tag as it has an energy_value below 3800: 40', 0);

# illogically-high-energy-value - does not add tag, if energy_value is equal 3800
product_with_energy_has_quality_tag(3800, 'product does not have illogically-high-energy-value tag as it has an energy_value of 3800: 40', 0);

# illogically-high-energy-value - does add tag, if energy_value is above 3800
product_with_energy_has_quality_tag(3801, 'product does have illogically-high-energy-value tag as it has an energy_value of 3800: 3801', 1);

# gs1-issn-prefix
product_with_code_has_quality_tag('977000000000', 'gs1-issn-prefix', 'product with GTIN-12 has gs1-issn-prefix tag because of the barcode prefix 977', 1);
product_with_code_has_quality_tag('9770000000000', 'gs1-issn-prefix', 'product with GTIN-13 has gs1-issn-prefix tag because of the barcode prefix 977', 1);
product_with_code_has_quality_tag('976000000000', 'gs1-issn-prefix', 'product with GTIN-12 has no gs1-issn-prefix tag because of the barcode prefix 976', 0);
product_with_code_has_quality_tag('9760000000000', 'gs1-issn-prefix', 'product with GTIN-13 has no gs1-issn-prefix tag because of the barcode prefix 976', 0);

# gs1-isbn-prefix
product_with_code_has_quality_tag('978000000000', 'gs1-isbn-prefix', 'product with GTIN-12 has gs1-isbn-prefix tag because of the barcode prefix 978', 1);
product_with_code_has_quality_tag('9780000000000', 'gs1-isbn-prefix', 'product with GTIN-13 has gs1-isbn-prefix tag because of the barcode prefix 978', 1);
product_with_code_has_quality_tag('979000000000', 'gs1-isbn-prefix', 'product with GTIN-12 has gs1-isbn-prefix tag because of the barcode prefix 979', 1);
product_with_code_has_quality_tag('9790000000000', 'gs1-isbn-prefix', 'product with GTIN-13 has gs1-isbn-prefix tag because of the barcode prefix 979', 1);
product_with_code_has_quality_tag('976000000000', 'gs1-isbn-prefix', 'product with GTIN-12 has no gs1-isbn-prefix tag because of the barcode prefix 976', 0);
product_with_code_has_quality_tag('9760000000000', 'gs1-isbn-prefix', 'product with GTIN-13 has no gs1-isbn-prefix tag because of the barcode prefix 976', 0);

# gs1-refund-prefix
product_with_code_has_quality_tag('980000000000', 'gs1-refund-prefix', 'product with GTIN-12 has gs1-refund-prefix tag because of the barcode prefix 980', 1);
product_with_code_has_quality_tag('9800000000000', 'gs1-refund-prefix', 'product with GTIN-13 has gs1-refund-prefix tag because of the barcode prefix 980', 1);
product_with_code_has_quality_tag('976000000000', 'gs1-refund-prefix', 'product with GTIN-12 has no gs1-refund-prefix tag because of the barcode prefix 976', 0);
product_with_code_has_quality_tag('9760000000000', 'gs1-refund-prefix', 'product with GTIN-13 has no gs1-refund-prefix tag because of the barcode prefix 976', 0);

# gs1-coupon-common-currency-area-prefix
product_with_code_has_quality_tag('981000000000', 'gs1-coupon-common-currency-area-prefix', 'product with GTIN-12 has gs1-coupon-common-currency-area-prefix tag because of the barcode prefix 981', 1);
product_with_code_has_quality_tag('9810000000000', 'gs1-coupon-common-currency-area-prefix', 'product with GTIN-13 has gs1-coupon-common-currency-area-prefix tag because of the barcode prefix 981', 1);
product_with_code_has_quality_tag('982000000000', 'gs1-coupon-common-currency-area-prefix', 'product with GTIN-12 has gs1-coupon-common-currency-area-prefix tag because of the barcode prefix 982', 1);
product_with_code_has_quality_tag('9820000000000', 'gs1-coupon-common-currency-area-prefix', 'product with GTIN-13 has gs1-coupon-common-currency-area-prefix tag because of the barcode prefix 982', 1);
product_with_code_has_quality_tag('983000000000', 'gs1-coupon-common-currency-area-prefix', 'product with GTIN-12 has gs1-coupon-common-currency-area-prefix tag because of the barcode prefix 983', 1);
product_with_code_has_quality_tag('9830000000000', 'gs1-coupon-common-currency-area-prefix', 'product with GTIN-13 has gs1-coupon-common-currency-area-prefix tag because of the barcode prefix 983', 1);
product_with_code_has_quality_tag('984000000000', 'gs1-coupon-common-currency-area-prefix', 'product with GTIN-12 has gs1-coupon-common-currency-area-prefix tag because of the barcode prefix 984', 1);
product_with_code_has_quality_tag('9840000000000', 'gs1-coupon-common-currency-area-prefix', 'product with GTIN-13 has gs1-coupon-common-currency-area-prefix tag because of the barcode prefix 984', 1);
product_with_code_has_quality_tag('976000000000', 'gs1-coupon-common-currency-area-prefix', 'product with GTIN-12 has no gs1-coupon-common-currency-area-prefix tag because of the barcode prefix 976', 0);
product_with_code_has_quality_tag('9760000000000', 'gs1-coupon-common-currency-area-prefix', 'product with GTIN-13 has no gs1-coupon-common-currency-area-prefix tag because of the barcode prefix 976', 0);

# gs1-future-coupon-prefix
product_with_code_has_quality_tag('985000000000', 'gs1-future-coupon-prefix', 'product with GTIN-12 has gs1-future-coupon-prefix tag because of the barcode prefix 985', 1);
product_with_code_has_quality_tag('9850000000000', 'gs1-future-coupon-prefix', 'product with GTIN-13 has gs1-future-coupon-prefix tag because of the barcode prefix 985', 1);
product_with_code_has_quality_tag('986000000000', 'gs1-future-coupon-prefix', 'product with GTIN-12 has gs1-future-coupon-prefix tag because of the barcode prefix 986', 1);
product_with_code_has_quality_tag('9860000000000', 'gs1-future-coupon-prefix', 'product with GTIN-13 has gs1-future-coupon-prefix tag because of the barcode prefix 986', 1);
product_with_code_has_quality_tag('987000000000', 'gs1-future-coupon-prefix', 'product with GTIN-12 has gs1-future-coupon-prefix tag because of the barcode prefix 987', 1);
product_with_code_has_quality_tag('9870000000000', 'gs1-future-coupon-prefix', 'product with GTIN-13 has gs1-future-coupon-prefix tag because of the barcode prefix 987', 1);
product_with_code_has_quality_tag('988000000000', 'gs1-future-coupon-prefix', 'product with GTIN-12 has gs1-future-coupon-prefix tag because of the barcode prefix 988', 1);
product_with_code_has_quality_tag('9880000000000', 'gs1-future-coupon-prefix', 'product with GTIN-13 has gs1-future-coupon-prefix tag because of the barcode prefix 988', 1);
product_with_code_has_quality_tag('989000000000', 'gs1-future-coupon-prefix', 'product with GTIN-12 has gs1-future-coupon-prefix tag because of the barcode prefix 989', 1);
product_with_code_has_quality_tag('9890000000000', 'gs1-future-coupon-prefix', 'product with GTIN-13 has gs1-future-coupon-prefix tag because of the barcode prefix 989', 1);
product_with_code_has_quality_tag('976000000000', 'gs1-future-coupon-prefix', 'product with GTIN-12 has no gs1-future-coupon-prefix tag because of the barcode prefix 976', 0);
product_with_code_has_quality_tag('9760000000000', 'gs1-future-coupon-prefix', 'product with GTIN-13 has no gs1-future-coupon-prefix tag because of the barcode prefix 976', 0);

# gs1-coupon-prefix
product_with_code_has_quality_tag('990000000000', 'gs1-coupon-prefix', 'product with GTIN-12 has gs1-coupon-prefix tag because of the barcode prefix 99', 1);
product_with_code_has_quality_tag('9900000000000', 'gs1-coupon-prefix', 'product with GTIN-13 has gs1-coupon-prefix tag because of the barcode prefix 99', 1);
product_with_code_has_quality_tag('976000000000', 'gs1-coupon-prefix', 'product with GTIN-12 has no gs1-coupon-prefix tag because of the barcode prefix 976', 0);
product_with_code_has_quality_tag('9760000000000', 'gs1-coupon-prefix', 'product with GTIN-13 has no gs1-coupon-prefix tag because of the barcode prefix 976', 0);

done_testing();
