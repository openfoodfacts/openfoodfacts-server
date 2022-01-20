#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test::More;
use Test::Number::Delta;
use Log::Any::Adapter 'TAP';

use ProductOpener::Products qw/:all/;

# code normalization
is( normalize_code('036000291452'), '0036000291452', 'should add leading 0 to valid UPC12' );
is( normalize_code('036000291455'), '036000291455', 'should not add 0 to invalid UPC12, just return as-is' );
is( normalize_code('4015533014963'), '4015533014963', 'should just return invalid EAN13' );
ok( !(defined normalize_code(undef)), 'undef should stay undef' );
is( normalize_code(' just a simple test 4015533014963 here we go '), '4015533014963', 'barcode should always be cleaned from anything but digits' );
is( normalize_code(' just a simple test 036000291452 here we go '), '0036000291452', 'should add leading 0 to cleaned valid UPC12' );
is( normalize_code(' just a simple test 036000291455 here we go '), '036000291455', 'should not add leading 0 to cleaned invalid UPC12' );

# product storage path
is( product_path_from_id('not a real code'), 'invalid', 'non digit code should return "invalid"' );
is( product_path_from_id('0123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789'), 'invalid', 'long code should return "invalid"' );
is( product_path_from_id('4015533014963'), '401/553/301/4963', 'code should be split in four parts' );

# compute_completeness_and_missing_tags
my $previous_ref = {};
sub compute_and_test_completeness($$$) {
	my $product_ref = shift;
	my $fraction = shift;
	my $with = shift;
	my $percent = $fraction * 100.0;
	compute_completeness_and_missing_tags($product_ref, $product_ref, $previous_ref);
	my $message = sprintf('%s is %g%% complete', $with, $percent);
	delta_ok( $product_ref->{completeness}, $fraction, $message );

	return;
}

my $step = 1.0/10.0; # Currently, we check for 10 properties.
my $product_ref = {};
compute_and_test_completeness($product_ref, 0.0, 'empty product');

$product_ref = {uploaded_images => {}, lc => 'de'};
$product_ref->{uploaded_images}->{foo} = 'bar';
compute_and_test_completeness($product_ref, $step * 0.5, 'product with at least one uploaded_images');

$product_ref = {uploaded_images => {}, selected_images => {}, lc => 'de'};
$product_ref->{uploaded_images}->{foo} = 'bar';
$product_ref->{selected_images}->{front_de} = 'bar';
compute_and_test_completeness($product_ref, $step * 0.5 + $step * 0.5 * 0.25, 'product with at least one uploaded_images and front');

$product_ref = {uploaded_images => {}, selected_images => {}, lc => 'de'};
$product_ref->{uploaded_images}->{foo} = 'bar';
$product_ref->{selected_images}->{front_de} = 'bar';
$product_ref->{selected_images}->{ingredients_de} = 'bar';
$product_ref->{selected_images}->{nutrition_de} = 'bar';
$product_ref->{selected_images}->{packaging_de} = 'bar';
compute_and_test_completeness($product_ref, $step, 'product with at least one uploaded_images and front/ingredients/nutrition/packaging selected');

my @string_fields = qw(product_name quantity packaging brands categories emb_codes expiration_date ingredients_text);
foreach my $field (@string_fields) {
	$product_ref = {$field => 'foo'};
	compute_and_test_completeness($product_ref, $step, "product with $field");
}

$product_ref = {};
foreach my $field (@string_fields) {
	$product_ref->{$field} = 'foo';
}

compute_and_test_completeness($product_ref, $step * (scalar @string_fields), 'product with all @string_fields');

$product_ref = {no_nutrition_data => 'on'};
compute_and_test_completeness($product_ref, $step, 'product with no_nutrition_data');

$product_ref = {nutriments => {}};
$product_ref->{nutriments}->{foo} = 'bar';
compute_and_test_completeness($product_ref, $step, 'product with at least one nutrient');

$product_ref = {nutriments => {},uploaded_images => {}, selected_images => {}, lc => 'de'};
$product_ref->{nutriments}->{foo} = 'bar';
$product_ref->{uploaded_images}->{foo} = 'bar';
$product_ref->{selected_images}->{front_de} = 'bar';
$product_ref->{selected_images}->{ingredients_de} = 'bar';
$product_ref->{selected_images}->{nutrition_de} = 'bar';
$product_ref->{selected_images}->{packaging_de} = 'bar';
$product_ref->{last_modified_t} = time();
foreach my $field (@string_fields) {
	$product_ref->{$field} = 'foo';
}

compute_and_test_completeness($product_ref, 1.0, 'product all fields');

# Test the function that recognizes the app and app uuid from changes and sets the app and userid

my @get_change_userid_or_uuid_tests = (

	{
		userid => undef,
		comment => "some random comment",
		expected_app => undef,
		expected_userid => "openfoodfacts-contributors",
	},
	{
		userid => "real-user",
		comment => "some random comment",
		expected_app => undef,
		expected_userid => "real-user",
	},	
	{
		userid => "stephane",
		comment => "Updated via Power User Script",
		expected_app => undef,
		expected_userid => "stephane",
	},
	{
		userid => "stephane",
		comment => "Official Open Food Facts Android app 3.6.6 (Added by a99a030f-c836-4551-9ec7-3d387f293e73)",
		expected_app => "off",
		expected_userid => "stephane",
	},
	{
		userid => undef,
		comment => "Official Open Food Facts Android app 3.6.6 (Added by a99a030f-c836-4551-9ec7-3d387f293e73)",
		expected_app => "off",
		expected_userid => "off.a99a030f-c836-4551-9ec7-3d387f293e73",
	},	
	{
		userid => "kiliweb",
		comment => "User : WjR3OExvb3M5dWNobU1Za29EUHJvdmtwN0p1SVh6MjNDZGdySVE9PQ",
		expected_app => "yuka",
		expected_userid => "yuka.WjR3OExvb3M5dWNobU1Za29EUHJvdmtwN0p1SVh6MjNDZGdySVE9PQ",
	},
	{
		userid => "prepperapp",
		comment => "Edited by a user of https://speisekammer-app.de",
		expected_app => "speisekammer",
		expected_userid => "prepperapp",
	},
	{
		userid => "scanfood",
		comment => "96ce87ae-2f2b-4fd6-90d2-7bfc4388d173-ScanFood",
		expected_app => "scanfood",
		expected_userid => "scanfood.96ce87ae-2f2b-4fd6-90d2-7bfc4388d173",
	},
);

foreach my $change_ref (@get_change_userid_or_uuid_tests) {

	$change_ref->{resulting_userid} = get_change_userid_or_uuid($change_ref);

	is ($change_ref->{app}, $change_ref->{expected_app}) or diag explain $change_ref;
	is ($change_ref->{resulting_userid}, $change_ref->{expected_userid}) or diag explain $change_ref;

}

done_testing();
