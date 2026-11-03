use ProductOpener::PerlStandards;
use Test2::V0;
use JSON::MaybeXS;
use Storable qw(dclone);
use ProductOpener::API qw(init_api_response);
use ProductOpener::APIProductServices qw(product_services_api);

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
	ingredients_text => "Composition : poulet, riz\nConstituants analytiques : protéines 8%, cendres brutes 2%, "
		. 'cellulose brute 1%',
};
my $sectioned = request($product,
	['parse_ingredients_text', 'extend_ingredients', 'estimate_ingredients_percent', 'analyze_ingredients']);
is($sectioned->{api_response}{errors}, [], 'composed ingredient services accept the sectioned product');
is(scalar @{$sectioned->{api_response}{product}{ingredients_sections} // []},
	2, 'default updated-field response exposes both sections');
ok($sectioned->{updated_product_fields}{ingredients_sections}, 'API tracks section output as updated');
unlike(JSON::MaybeXS->new->encode($sectioned->{api_response}),
	qr/"_body"/, 'public API does not expose temporary section parsing data');

my $replaced = dclone($sectioned->{body_json}{product});
$replaced->{ingredients_text} = 'sel';
my $replacement = request($replaced);
is($replacement->{body_json}{product}{ingredients_sections}, undef, 'API removes sections after source replacement');
ok($replacement->{updated_product_fields}{ingredients_sections}, 'API tracks removal of section output');
my $empty = dclone($replaced);
$empty->{ingredients_text} = '';
my $cleared = request($empty);
is($cleared->{body_json}{product}{ingredients_sections}, undef, 'API removes sections for empty source');

done_testing;
