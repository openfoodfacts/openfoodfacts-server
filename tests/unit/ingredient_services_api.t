use ProductOpener::PerlStandards;
use Test2::V0;
use JSON::MaybeXS;
use Storable qw(dclone);
use ProductOpener::API qw(init_api_response);
use ProductOpener::APIProductServices qw(product_services_api);
use ProductOpener::Ingredients qw(extract_ingredients_from_text);

sub request ($product, $services = ['parse_ingredients_text']) {
	my $request = {
		api_version => 3,
		lc => 'en',
		cc => 'world',
		body_json => {product => dclone($product), services => $services},
	};
	init_api_response($request);
	product_services_api($request);
	return $request;
}

my $quantity = request({lc => 'fr', ingredients_text => 'Tomates (148 g pour 100 g de Tomato Ketchup)'});
is($quantity->{api_response}{errors}, [], 'quantity statement is accepted by the API service');
is(
	$quantity->{api_response}{product}{ingredients}[0]{quantity_reference},
	{text => '100 g de Tomato Ketchup', quantity_g => 100},
	'default updated-field response retains quantity reference'
);

my $equivalent = request({lc => 'fr', ingredients_text => 'carottes déshydratées 0,6% équivalent à 4% de carottes'});
is($equivalent->{api_response}{product}{ingredients}[0]{equivalents}[0]{percent},
	4, 'default updated-field response retains equivalence');

my $product = {
	lc => 'fr',
	product_type => 'petfood',
	nutrition => {},
	ingredients_text => "Émincés au poulet : poulet 4%, eau.\nÉmincés à la dinde : dinde 4%, eau.",
	ingredients_percent_analysis => 1
};
my $recipes = request($product,
	['parse_ingredients_text', 'extend_ingredients', 'estimate_ingredients_percent', 'analyze_ingredients']);
is($recipes->{api_response}{errors}, [], 'composed ingredient services accept the sectioned product');
is(scalar @{$recipes->{api_response}{product}{ingredients_sections} // []},
	2, 'default updated-field response exposes both recipes');
is($recipes->{api_response}{product}{ingredients_percent_analysis},
	undef, 'API estimator does not return a global estimate for unweighted recipes');
ok($recipes->{updated_product_fields}{ingredients_sections}, 'API tracks section output as updated');
unlike(JSON::MaybeXS->new->encode($recipes->{api_response}),
	qr/"_body"/, 'public API does not expose temporary section parsing data');

my $inferred = request(
	{
		lc => 'en',
		product_type => 'petfood',
		ingredients_text => "chicken, oil\ncrude protein 8%\ncrude ash 2%\ncrude fibre 1%"
	}
);
like(JSON::MaybeXS->new->encode($inferred->{api_response}),
	qr/"inferred"\s*:\s*true/, 'inferred boundary is serialized as a JSON boolean');

my $replaced = dclone($recipes->{body_json}{product});
$replaced->{ingredients_text} = 'sel';
my $replacement = request($replaced);
is($replacement->{body_json}{product}{ingredients_sections}, undef, 'API removes sections after source replacement');
ok($replacement->{updated_product_fields}{ingredients_sections}, 'API tracks removal of section output');
my $empty = dclone($replaced);
$empty->{ingredients_text} = '';
my $cleared = request($empty);
is($cleared->{body_json}{product}{ingredients_sections}, undef, 'API removes sections for empty source');

my $previous = {
	lc => 'en',
	product_type => 'petfood',
	nutrition => {},
	ingredients_text => 'chicken 60%, water 40%. Meat content: 60%'
};
extract_ingredients_from_text($previous);
$previous->{ingredients_text}
	= 'With Chicken Ingredients: chicken 4%, water. With Turkey Ingredients: turkey 4%, water.';
my @quantitative = qw(specific_ingredients ingredients_with_specified_percent_n ingredients_with_specified_percent_sum
	ingredients_with_unspecified_percent_n ingredients_with_unspecified_percent_sum);

for my $services (['parse_ingredients_text'],
	['parse_ingredients_text', 'extend_ingredients', 'estimate_ingredients_percent', 'analyze_ingredients'])
{
	my $result = request($previous, $services);
	my $product = $result->{body_json}{product};
	is(
		[map {$product->{$_}} @quantitative],
		[(undef) x scalar @quantitative],
		'replacing a recipe invalidates old global quantities and total-content declarations'
	);
	is([grep {/specified-percent|estimated-ingredients-with/} @{$product->{misc_tags} // []}],
		[], 'replacing a recipe removes stale quantitative analysis tags');
	ok(!scalar(grep {!$result->{updated_product_fields}{$_}} (@quantitative, 'misc_tags')),
		'API reports every invalidated quantitative field');
}
extract_ingredients_from_text($previous);
is(
	[map {$previous->{$_}} @quantitative],
	[(undef) x scalar @quantitative],
	'full reanalysis also leaves unweighted global quantitative summaries indeterminate'
);
is([grep {/specified-percent|estimated-ingredients-with/} @{$previous->{misc_tags} // []}],
	[], 'full reanalysis removes obsolete quantitative tags');

done_testing;
