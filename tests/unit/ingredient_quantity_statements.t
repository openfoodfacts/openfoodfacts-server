use ProductOpener::PerlStandards;
use Test2::V0;
use Storable qw(dclone);
use ProductOpener::Ingredients qw(parse_ingredients_text_service extract_ingredients_from_text);

sub parse ($lc, $text) {
	my $product = {lc => $lc, ingredients_text => $text, nutrition => {}};
	parse_ingredients_text_service($product, {}, []);
	return $product;
}

for my $case (
	[
		'fr',
		'carottes déshydratées 0,6% équivalent à 4% de carottes',
		'équivalent à 4% de carottes',
		'fr:carottes-deshydratees', 'carottes déshydratées'
	],
	[
		'en',
		'dried carrots 0.6% equivalent to 4% of carrots',
		'equivalent to 4% of carrots',
		'en:dried-carrot', 'dried carrots'
	],
	)
{
	my ($lc, $text, $annotation, $id, $name) = @$case;
	my $product = parse($lc, $text);
	my $ingredient = $product->{ingredients}[0];
	is(scalar @{$product->{ingredients}}, 1, 'equivalence does not create a second ingredient');
	is($ingredient->{id}, $id, 'equivalence preserves the existing processed-carrot identity');
	is($ingredient->{percent}, 0.6, 'declared dried percentage remains separate');
	is($ingredient->{text}, $name, 'the processed ingredient name survives the equivalence');
	is(
		$ingredient->{equivalents},
		[{id => 'en:carrot', text => $annotation, percent => 4}],
		'fresh equivalent is a separate typed annotation'
	);
	my $first = dclone($product->{ingredients});
	parse_ingredients_text_service($product, {}, []);
	is($product->{ingredients}, $first, 'equivalences are stable when reparsing');
	extract_ingredients_from_text($product);
	is($product->{ingredients_n}, 1, 'equivalent annotations are not counted as ingredients');
	is($product->{ingredients}[0]{equivalents}[0]{percent}, 4, 'estimation does not overwrite the equivalence');
	is($product->{ingredients}[0]{percent}, 0.6, 'estimation preserves the declared dried percentage');
}

for my $case (
	['fr', 'Tomates (148 g pour 100 g de Tomato Ketchup)', 148, {text => '100 g de Tomato Ketchup', quantity_g => 100}],
	[
		'en', 'Tomatoes (0.148 kg per 100 g of Tomato Ketchup)',
		148, {text => '100 g of Tomato Ketchup', quantity_g => 100}
	],
	['fr', 'Tomates (148 g pour 100 g)', 148, {text => '100 g', quantity_g => 100}],
	[
		'en', 'Milk (120 ml per 100 ml of finished product)',
		120, {text => '100 ml of finished product', quantity_ml => 100}
	],
	)
{
	my ($lc, $text, $quantity, $reference) = @$case;
	my $product = parse($lc, $text);
	my $ingredient = $product->{ingredients}[0];
	is(scalar @{$product->{ingredients}}, 1, 'reference statement does not create ingredients');
	my $quantity_field = exists $reference->{quantity_ml} ? 'quantity_ml' : 'quantity_g';
	is($ingredient->{$quantity_field}, $quantity, 'input quantity uses existing normalization');
	is($ingredient->{quantity_reference}, $reference, 'reference quantity and wording are preserved');
	is($ingredient->{percent}, undef, 'input-to-output ratio is not a declared percent');
	my $first = dclone($product->{ingredients});
	parse_ingredients_text_service($product, {}, []);
	is($product->{ingredients}, $first, 'quantity reference is stable when reparsing');
}

my $referenced = parse('en', 'tomatoes (148 g per 100 g), pork (200 g per 100 g of finished product)');
extract_ingredients_from_text($referenced);
is(
	[map {$_->{percent}} @{$referenced->{ingredients}}],
	[undef, undef],
	'input-to-output quantities are excluded from recipe-weight normalization'
);

my $ordinary = parse('en', 'carrots 60 g, tomatoes 40 g');
extract_ingredients_from_text($ordinary);
is([map {$_->{percent}} @{$ordinary->{ingredients}}], [60, 40], 'ordinary recipe quantities still normalize');

my $reset = parse('fr', 'carottes déshydratées 0,6% équivalent à 4% de carottes');
$reset->{ingredients_text} = 'sel';
my $updated = {};
parse_ingredients_text_service($reset, $updated, []);
is($reset->{ingredients}[0]{equivalents}, undef, 'replaced text clears the old equivalence');
ok($updated->{ingredients}, 'API service declares the updated ingredient structure');
$reset->{ingredients_text} = '';
parse_ingredients_text_service($reset, $updated, []);
is($reset->{ingredients}, undef, 'empty source clears quantity annotations with the ingredients');

done_testing;
