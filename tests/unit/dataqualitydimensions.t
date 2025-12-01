#!/usr/bin/perl -w
use ProductOpener::PerlStandards;

use Test2::V0;
use Data::Dumper;
$Data::Dumper::Terse = 1;

use ProductOpener::DataQualityDimensions qw/compute_accuracy_score compute_completeness_score/;
use ProductOpener::Tags qw/has_tag/;

#################################
####     H E L P E R S      ####
#################################

sub compute_and_test_accuracy($product_ref, $score, $with) {
	my $percent = $score * 100.0;
	compute_accuracy_score($product_ref);
	my $message = sprintf('%s is %g%% accurate', $with, $percent);
	is($product_ref->{data_quality_dimensions}{accuracy}{overall}, $score, $message);
	return;
}

sub compute_and_test_completeness($product_ref, $score, $with) {
	my $percent = $score * 100.0;
	compute_completeness_score($product_ref);
	my $message = sprintf('%s is %g%% complete', $with, $percent);
	is($product_ref->{data_quality_dimensions}{completeness}{overall}, $score, $message);
	return;
}

sub check_tags($product_ref, $field, %expectations) {
	for my $tag (keys %expectations) {
		my $expected = $expectations{$tag};
		is(has_tag($product_ref, "data_quality_completeness", $tag), $expected, "$field - tag $tag expected $expected");
	}
	return;
}

#################################
####     A C C U R A C Y     ####
#################################

my $product_ref = {};
compute_and_test_accuracy($product_ref, "0.00", 'accuracy - score - empty product');
check_tags(
	$product_ref,
	"accuracy",
	(
		"en:photo-and-data-checked-by-an-experienced-contributor" => 0,
		"en:photo-and-data-to-be-checked-by-an-experienced-contributor" => 1,
	)
);

$product_ref = {checked => 'on'};
compute_and_test_accuracy($product_ref, "1.00", 'accuracy - score - all filled');
check_tags(
	$product_ref,
	"accuracy",
	(
		"en:photo-and-data-checked-by-an-experienced-contributor" => 1,
		"en:photo-and-data-to-be-checked-by-an-experienced-contributor" => 0,
	)
);

#################################
#### C O M P L E T E N E S S ####
#################################

# empty product baseline
$product_ref = {countries_tags => ['en:spain'], languages_codes => {'es' => 1}};
compute_and_test_completeness($product_ref, "0.00", 'completeness - score - empty product');
check_tags(
	$product_ref,
	"completeness",
	(
		"en:ingredients-es-photo-selected" => 0,
		"en:ingredients-es-photo-to-be-selected" => 1,
		"en:ingredients-es-completed" => 0,
		"en:ingredients-es-to-be-completed" => 1,
		"en:nutrition-photo-selected" => 0,
		"en:nutrition-photo-to-be-selected" => 1,
		"en:categories-completed" => 0,
		"en:categories-to-be-completed" => 1,
		"en:nutriments-completed" => 0,
		"en:nutriments-to-be-completed" => 1,
		"en:packaging-photo-selected" => 0,
		"en:packaging-photo-to-be-selected" => 1,
		"en:packagings-completed" => 0,
		"en:packagings-to-be-completed" => 1,
		"en:traceability-codes-completed" => 0,
		"en:traceability-codes-to-be-completed" => 0,    # applies only for EU + animal origin categories
		"en:front-photo-selected" => 0,
		"en:front-photo-to-be-selected" => 1,
		"en:product-name-completed" => 0,
		"en:product-name-to-be-completed" => 1,
		"en:quantity-completed" => 0,
		"en:quantity-to-be-completed" => 1,
		"en:brands-completed" => 0,
		"en:brands-to-be-completed" => 1,
		"en:expiration-date-completed" => 0,
		"en:expiration-date-to-be-completed" => 1,
	)
);

# incremental completeness tests
compute_and_test_completeness({images => {selected => {front => {sl => {}}}}, languages_codes => {'sl' => 1}},
	"0.08", 'product with 1 selected ingredients image and 1 lang');

compute_and_test_completeness(
	{images => {selected => {ingredients => {sl => {}}}}, languages_codes => {'hr' => 1, 'sl' => 1}},
	"0.07", 'product with 1 selected ingredients image and 2 langs');

compute_and_test_completeness(
	{
		images => {
			selected =>
				{front => {cs => {}}, ingredients => {cs => {}}, nutrition => {cs => {}}, packaging => {cs => {}}}
		},
		languages_codes => {'cs' => 1}
	},
	"0.33",
	'product with all 4 selected images and 1 lang, no food of animal origin category'
);

compute_and_test_completeness(
	{
		images => {
			selected => {
				front => {cs => {}},
				ingredients => {cs => {}, sk => {}},
				nutrition => {cs => {}},
				packaging => {cs => {}}
			}
		},
		languages_codes => {'cs' => 1, 'sk' => 1}
	},
	"0.36",
	'product with all 4 selected images in 1 lang and 1 ingredients image in another lang, no food of animal origin category'
);

compute_and_test_completeness(
	{
		brands => 'qux',
		categories => 'meats',
		countries => ['en:italy'],
		emb_codes => 'corge',
		expiration_date => 'grault',
		ingredients_text_it => 'garply',
		languages_codes => {'it' => 1},
		packagings => 'baz',
		product_name => 'foo',
		quantity => 'bar'
	},
	"0.58",
	'product with all string fields, no food of animal origin category'
);

compute_and_test_completeness({no_nutrition_data => 'on', nutriments => {}},
	"0.20", 'product with no_nutrition_data and no nutriments and not from animal origin category');

compute_and_test_completeness({nutriments => {}}, "0.00", 'product without nutriments but no nutrition data is not on');

compute_and_test_completeness({nutriments => {carbohydrates => 2}},
	"0.10", 'product with nutriments and not from animal origin category');

$product_ref = {
	nutriments => {
		"fruits-vegetables-nuts-estimate-from-ingredients_100g" => 0,
		"fruits-vegetables-nuts-estimate-from-ingredients_serving" => 0,
		"nova-group" => 4,
		"nova-group_100g" => 4,
		"nova-group_serving" => 4
	}
};
compute_and_test_completeness($product_ref, "0.00", 'NOVA and fruit/veg estimates ignored in completeness');
check_tags(
	$product_ref,
	"completeness",
	(
		"en:nutriments-to-be-completed" => 1,
		"en:nutriments-completed" => 0,
	)
);

# fully complete product
$product_ref = {
	brands => 'qux',
	categories_tags => ['en:meats-and-their-products'],
	categories => 'Meats and their products',
	countries_tags => ['en:hungary'],
	emb_codes => 'corge',
	expiration_date => 'grault',
	images => {
		selected => {front => {hu => {}}, ingredients => {hu => {}}, nutrition => {hu => {}}, packaging => {hu => {}}}
	},
	ingredients_text_hu => 'garply',
	languages_codes => {'hu' => 1},
	nutriments => {carbohydrates => 2},
	packagings => 'baz',
	product_name => 'foo',
	quantity => 'bar'
};
compute_and_test_completeness($product_ref, "1.00", 'completeness - product all fields');
check_tags(
	$product_ref,
	"completeness",
	(
		"en:ingredients-hu-photo-selected" => 1,
		"en:ingredients-hu-photo-to-be-selected" => 0,
		"en:ingredients-hu-completed" => 1,
		"en:ingredients-hu-to-be-completed" => 0,
		"en:nutrition-photo-selected" => 1,
		"en:nutrition-photo-to-be-selected" => 0,
		"en:categories-completed" => 1,
		"en:categories-to-be-completed" => 0,
		"en:nutriments-completed" => 1,
		"en:nutriments-to-be-completed" => 0,
		"en:packaging-photo-selected" => 1,
		"en:packaging-photo-to-be-selected" => 0,
		"en:packagings-completed" => 1,
		"en:packagings-to-be-completed" => 0,
		"en:traceability-codes-completed" => 1,
		"en:traceability-codes-to-be-completed" => 0,
		"en:front-photo-selected" => 1,
		"en:front-photo-to-be-selected" => 0,
		"en:product-name-completed" => 1,
		"en:product-name-to-be-completed" => 0,
		"en:quantity-completed" => 1,
		"en:quantity-to-be-completed" => 0,
		"en:brands-completed" => 1,
		"en:brands-to-be-completed" => 0,
		"en:expiration-date-completed" => 1,
		"en:expiration-date-to-be-completed" => 0,
	)
);

done_testing();
