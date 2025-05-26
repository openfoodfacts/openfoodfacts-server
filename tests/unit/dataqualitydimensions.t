#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test2::V0;
use Data::Dumper;
$Data::Dumper::Terse = 1;

use ProductOpener::DataQualityDimensions qw/compute_accuracy_score compute_completeness_score/;
use ProductOpener::Tags qw/has_tag/;

#################################
####     A C C U R A C Y     ####
#################################

sub compute_and_test_accuracy ($$$) {
    my $product_ref = shift;
    my $score = shift;
    my $with = shift;
    my $percent = $score * 100.0;
    compute_accuracy_score($product_ref);
    my $message = sprintf('%s is %g%% accurate', $with, $percent);
    is($product_ref->{data_quality_dimensions}{accuracy}{overall}, $score, $message);

    return;
}

my $product_ref = {};
compute_and_test_accuracy($product_ref, "0.00", 'accuracy - score - empty product');
is(has_tag($product_ref, "data_quality_info", "en:photo-and-data-checked-by-an-experienced-contributor"), 0, "accuracy - tags - checked 0");
is(has_tag($product_ref, "data_quality_info", "en:photo-and-data-to-be-checked-by-an-experienced-contributor"), 1, "accuracy - tags - to be checked 1");

$product_ref = { checked => 'on' };
compute_and_test_accuracy($product_ref, "1.00", 'accuracy - score - all filled');
is(has_tag($product_ref, "data_quality_info", "en:photo-and-data-checked-by-an-experienced-contributor"), 1, "accuracy - tags - checked 1");
is(has_tag($product_ref, "data_quality_info", "en:photo-and-data-to-be-checked-by-an-experienced-contributor"), 0, "accuracy - tags - to be checked 0");

#################################
#### C O M P L E T E N E S S ####
#################################

sub compute_and_test_completeness($$$) {
	my $product_ref = shift;
	my $score = shift;
	my $with = shift;
	my $percent = $score * 100.0;
	compute_completeness_score($product_ref);
	my $message = sprintf('%s is %g%% complete', $with, $percent);
	is($product_ref->{data_quality_dimensions}{completeness}{overall}, $score, $message);

	return;
}

$product_ref = {countries_tags => ['en:spain'], languages_codes => {'es' => 1}};
compute_and_test_completeness($product_ref, "0.00", 'completeness - score - empty product');
is(has_tag($product_ref, "data_quality_info", "en:ingredients-es-photo-selected"), 0, "completeness - tags - empty product does not have en:ingredients-es-photo-selected tag");
is(has_tag($product_ref, "data_quality_info", "en:ingredients-es-photo-to-be-selected"), 1, "completeness - tags - empty product has en:ingredients-es-photo-to-be-selected tag");
is(has_tag($product_ref, "data_quality_info", "en:ingredients-es-completed"), 0, "completeness - tags - empty product does not have en:ingredients-es-completed tag");
is(has_tag($product_ref, "data_quality_info", "en:ingredients-es-to-be-completed"), 1, "completeness - tags - empty product has en:ingredients-es-to-be-completed tag");

is(has_tag($product_ref, "data_quality_info", "en:nutrition-photo-selected"), 0, "completeness - tags - empty product does not have en:nutrition-photo-selected tag");
is(has_tag($product_ref, "data_quality_info", "en:nutrition-photo-to-be-selected"), 1, "completeness - tags - empty product has en:nutrition-photo-to-be-selected tag");
is(has_tag($product_ref, "data_quality_info", "en:categories-completed"), 0, "completeness - tags - empty product does not have en:categories-completed tag");
is(has_tag($product_ref, "data_quality_info", "en:categories-to-be-completed"), 1, "completeness - tags - empty product has en:categories-to-be-completed tag");
is(has_tag($product_ref, "data_quality_info", "en:nutriments-completed"), 0, "completeness - tags - empty product does not have en:nutriments-completed tag");
is(has_tag($product_ref, "data_quality_info", "en:nutriments-to-be-completed"), 1, "completeness - tags - empty product has en:nutriments-to-be-completed tag");

is(has_tag($product_ref, "data_quality_info", "en:packaging-photo-selected"), 0, "completeness - tags - empty product does not have en:packaging-photo-selected tag");
is(has_tag($product_ref, "data_quality_info", "en:packaging-photo-to-be-selected"), 1, "completeness - tags - empty product has en:packaging-photo-to-be-selected tag");
is(has_tag($product_ref, "data_quality_info", "en:packagings-completed"), 0, "completeness - tags - empty product does not have en:packagings-completed tag");
is(has_tag($product_ref, "data_quality_info", "en:packagings-to-be-completed"), 1, "completeness - tags - empty product has en:packagings-to-be-completed tag");
is(has_tag($product_ref, "data_quality_info", "en:emb-codes-completed"), 0, "completeness - tags - empty product does not have en:emb-codes-completed tag");
is(has_tag($product_ref, "data_quality_info", "en:emb-codes-to-be-completed"), 1, "completeness - tags - empty product has en:emb-codes-to-be-completed tag");

is(has_tag($product_ref, "data_quality_info", "en:front-photo-selected"), 0, "completeness - tags - empty product does not have en:front-photo-selected tag");
is(has_tag($product_ref, "data_quality_info", "en:front-photo-to-be-selected"), 1, "completeness - tags - empty product has en:front-photo-to-be-selected tag");
is(has_tag($product_ref, "data_quality_info", "en:product-name-completed"), 0, "completeness - tags - empty product does not have en:product-name-completed tag");
is(has_tag($product_ref, "data_quality_info", "en:product-name-to-be-completed"), 1, "completeness - tags - empty product has en:product-name-to-be-completed tag");
is(has_tag($product_ref, "data_quality_info", "en:quantity-completed"), 0, "completeness - tags - empty product does not have en:quantity-completed tag");
is(has_tag($product_ref, "data_quality_info", "en:quantity-to-be-completed"), 1, "completeness - tags - empty product has en:quantity-to-be-completed tag");
is(has_tag($product_ref, "data_quality_info", "en:brands-completed"), 0, "completeness - tags - empty product does not have en:brands-completed tag");
is(has_tag($product_ref, "data_quality_info", "en:brands-to-be-completed"), 1, "completeness - tags - empty product has en:brands-to-be-completed tag");
is(has_tag($product_ref, "data_quality_info", "en:expiration-date-completed"), 0, "completeness - tags - empty product does not have en:expiration-date-completed tag");
is(has_tag($product_ref, "data_quality_info", "en:expiration-date-to-be-completed"), 1, "completeness - tags - empty product has en:expiration-date-to-be-completed tag");

$product_ref = { images => { ingredients_sl => {} }, languages_codes => {'sl' => 1} };
compute_and_test_completeness($product_ref, "0.08", 'completeness - score - product with 1 selected ingredients image and 1 lang');

$product_ref = { images => { ingredients_sl => {} }, languages_codes => {'hr' => 1, 'sl' => 1} };
compute_and_test_completeness($product_ref, "0.07", 'completeness - score - product with 1 selected ingredients image and 2 langs');

$product_ref = { images => { front_cs => {}, ingredients_cs => {}, nutrition_cs => {}, packaging_cs => {}}, languages_codes => {'cs' => 1} };
compute_and_test_completeness($product_ref, "0.31",
	'completeness - score - product with all 4 selected images and 1 lang');

$product_ref = { images => { front_cs => {}, ingredients_cs => {}, ingredients_sk => {}, nutrition_cs => {}, packaging_cs => {}}, languages_codes => {'cs' => 1, 'sk' => 1} };
compute_and_test_completeness($product_ref, "0.33",
	'completeness - score - product with all 4 selected images in 1 lang and 1 selected ingredients images in another lang');

$product_ref = {
    brands => 'qux',
    categories => 'quux',
    countries => ['en:italy'], # needed for emb_codes
    emb_codes => 'corge',
    expiration_date => 'grault',
    ingredients_text_it => 'garply',
    languages_codes => {'it' => 1}, # needed for ingredients_text_it
    packagings => 'baz',
    product_name => 'foo',
    quantity => 'bar'
};
compute_and_test_completeness($product_ref, "0.54", 'completeness - score - product with all string fields');

$product_ref = {no_nutrition_data => 'on', nutriments => {}};
compute_and_test_completeness($product_ref, "0.18", 'completeness - score - product with no_nutrition_data and no nutriments');

$product_ref = {nutriments => {}};
compute_and_test_completeness($product_ref, "0.00", 'completeness - score - product without nutriments but no nutrition data is not on');

$product_ref = {nutriments => {carbohydrates => 2}};
compute_and_test_completeness($product_ref, "0.09", 'completeness - score - product with nutriments');

$product_ref = {nutriments => {
	"fruits-vegetables-nuts-estimate-from-ingredients_100g" => 0,
	"fruits-vegetables-nuts-estimate-from-ingredients_serving" => 0,
	"nova-group" => 4,
	"nova-group_100g" => 4,
	"nova-group_serving" => 4
}};
compute_and_test_completeness($product_ref, "0.00", 'completeness - score - NOVA and estimated % of fruits and vegetables are ignored when determining if the nutrients are completed');
is(has_tag($product_ref, "data_quality_info", "en:nutriments-to-be-completed"), 1, "completeness - tags - product with nova or estimated % in nutriments has en:nutriments-to-be-completed tag");
is(has_tag($product_ref, "data_quality_info", "en:nutriments-completed"), 0, "completeness - tags - product with nova or estimated % in nutriments does not have en:nutriments-completed tag");



$product_ref = {
    brands => 'qux',
    categories => 'quux',
    countries_tags => ['en:hungary'], # needed for emb_codes
    emb_codes => 'corge',
    expiration_date => 'grault',
    images => { front_hu => {}, ingredients_hu => {}, nutrition_hu => {}, packaging_hu => {} },
    ingredients_text_hu => 'garply',
    languages_codes => {'hu' => 1}, # needed for ingredients_text_hu
    nutriments => {carbohydrates => 2},
    packagings => 'baz',
    product_name => 'foo',
    quantity => 'bar'
};

compute_and_test_completeness($product_ref, "1.00", 'completeness - score - product all fields');

is(has_tag($product_ref, "data_quality_info", "en:ingredients-hu-photo-selected"), 1, "completeness - tags - completed product has en:ingredients-hu-photo-selected tag");
is(has_tag($product_ref, "data_quality_info", "en:ingredients-hu-photo-to-be-selected"), 0, "completeness - tags - completed product does not have en:ingredients-hu-photo-to-be-selected tag");
is(has_tag($product_ref, "data_quality_info", "en:ingredients-hu-completed"), 1, "completeness - tags - completed product has en:ingredients-hu-completed tag");
is(has_tag($product_ref, "data_quality_info", "en:ingredients-hu-to-be-completed"), 0, "completeness - tags - completed product does not have en:ingredients-hu-to-be-completed tag");

is(has_tag($product_ref, "data_quality_info", "en:nutrition-photo-selected"), 1, "completeness - tags - completed product has en:nutrition-photo-selected tag");
is(has_tag($product_ref, "data_quality_info", "en:nutrition-photo-to-be-selected"), 0, "completeness - tags - completed product does not have en:nutrition-photo-to-be-selected tag");
is(has_tag($product_ref, "data_quality_info", "en:categories-completed"), 1, "completeness - tags - completed product has en:categories-completed tag");
is(has_tag($product_ref, "data_quality_info", "en:categories-to-be-completed"), 0, "completeness - tags - completed product does not have en:categories-to-be-completed tag");
is(has_tag($product_ref, "data_quality_info", "en:nutriments-completed"), 1, "completeness - tags - completed product has en:nutriments-completed tag");
is(has_tag($product_ref, "data_quality_info", "en:nutriments-to-be-completed"), 0, "completeness - tags - completed product does not have en:nutriments-to-be-completed tag");

is(has_tag($product_ref, "data_quality_info", "en:packaging-photo-selected"), 1, "completeness - tags - completed product has en:packaging-photo-selected tag");
is(has_tag($product_ref, "data_quality_info", "en:packaging-photo-to-be-selected"), 0, "completeness - tags - completed product does not have en:packaging-photo-to-be-selected tag");
is(has_tag($product_ref, "data_quality_info", "en:packagings-completed"), 1, "completeness - tags - completed product has en:packagings-completed tag");
is(has_tag($product_ref, "data_quality_info", "en:packagings-to-be-completed"), 0, "completeness - tags - completed product does not have en:packagings-to-be-completed tag");
is(has_tag($product_ref, "data_quality_info", "en:emb-codes-completed"), 1, "completeness - tags - completed product has en:emb-codes-completed tag");
is(has_tag($product_ref, "data_quality_info", "en:emb-codes-to-be-completed"), 0, "completeness - tags - completed product does not have en:emb-codes-to-be-completed tag");

is(has_tag($product_ref, "data_quality_info", "en:front-photo-selected"), 1, "completeness - tags - completed product has en:front-photo-selected tag");
is(has_tag($product_ref, "data_quality_info", "en:front-photo-to-be-selected"), 0, "completeness - tags - completed product does not have en:front-photo-to-be-selected tag");
is(has_tag($product_ref, "data_quality_info", "en:product-name-completed"), 1, "completeness - tags - completed product has en:product-name-completed tag");
is(has_tag($product_ref, "data_quality_info", "en:product-name-to-be-completed"), 0, "completeness - tags - completed product does not have en:product-name-to-be-completed tag");
is(has_tag($product_ref, "data_quality_info", "en:quantity-completed"), 1, "completeness - tags - completed product has en:quantity-completed tag");
is(has_tag($product_ref, "data_quality_info", "en:quantity-to-be-completed"), 0, "completeness - tags - completed product does not have en:quantity-to-be-completed tag");
is(has_tag($product_ref, "data_quality_info", "en:brands-completed"), 1, "completeness - tags - completed product has en:brands-completed tag");
is(has_tag($product_ref, "data_quality_info", "en:brands-to-be-completed"), 0, "completeness - tags - completed product does not have en:brands-to-be-completed tag");
is(has_tag($product_ref, "data_quality_info", "en:expiration-date-completed"), 1, "completeness - tags - completed product has en:expiration-date-completed tag");
is(has_tag($product_ref, "data_quality_info", "en:expiration-date-to-be-completed"), 0, "completeness - tags - completed product does not have en:expiration-date-to-be-completed tag");

done_testing();
