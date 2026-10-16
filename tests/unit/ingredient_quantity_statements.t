use ProductOpener::PerlStandards;
use Test2::V0;
use Storable qw(dclone);
use ProductOpener::Ingredients qw(parse_ingredients_text_service extract_ingredients_from_text flatten_sub_ingredients);

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

for my $case (
	['en', 'tomatoes 20% (148 g per 100 g of finished product), pork'],
	['en', 'tomatoes (148 g per 100 g of finished product) 20%'],
	['fr', 'Tomates 20 % (148 g pour 100 g de produit fini), porc'],
	)
{
	my $product = parse(@$case);
	is($product->{ingredients}[0]{percent}, 20, "$case->[1] keeps the declared percent");
	is($product->{ingredients}[0]{quantity_reference}, undef, "$case->[1] has no reference without its quantity");
}

for my $case (
	['en', 'Tomatoes (148 g per 100 g of finished product and salt)'],
	['en', 'Tomatoes (148 g per 100 g of finished product: salt)'],
	['en', 'Tomatoes (148 g per 100 g of finished product / salt)'],
	['fr', 'Tomates (148 g pour 100 g de produit fini et sel)'],
	['es', 'Tomate (148 g por 100 g de producto y sal)'],
	)
{
	my $product = parse(@$case);
	flatten_sub_ingredients($product);
	ok((grep {$_->{id} eq 'en:salt'} @{$product->{ingredients}}), "$case->[1] keeps the ingredient that follows");
}

for my $case (
	['fr', 'Tomates (148 g pour 1,5 kg de ketchup)', {text => '1,5 kg de ketchup', quantity_g => 1500}],
	['fr', 'Tomates (148 g pour 0,5 kg)', {text => '0,5 kg', quantity_g => 500}],
	['es', 'Tomate (148 g por 0,5 l)', {text => '0,5 l', quantity_ml => 500}],
	)
{
	my ($lc, $text, $reference) = @$case;
	my $ingredient = parse($lc, $text)->{ingredients}[0];
	is($ingredient->{quantity_g}, 148, "$text keeps the input quantity");
	is($ingredient->{quantity_reference}, $reference, "$text reads a decimal comma in the reference");
	is($ingredient->{ingredients}, undef, "$text has no sub-ingredient");
}

for my $case (
	['it', 'Pomodori (148 g per 100 g di prodotto finito)', '100 g di prodotto finito'],
	['nl', 'tomaten (148 g per 100 g van het volledige product)', '100 g van het volledige product'],
	['fr', 'Tomates (148 g pour 100 g sur produit fini)', '100 g sur produit fini'],
	['hr', 'rajčica (148 g na 100 g gotovog proizvoda)', '100 g gotovog proizvoda'],
	)
{
	my ($lc, $text, $reference) = @$case;
	my $ingredient = parse($lc, $text)->{ingredients}[0];
	is($ingredient->{quantity_reference}{text}, $reference, "$text uses the wording of its language");
}

for my $text ('Biotin (150 µg per 100 g)', 'Biotin (150 ug per 100 g)', "Biotin (150 \x{3bc}g per 100 g)") {
	my $ingredient = parse('en', $text)->{ingredients}[0];
	is($ingredient->{quantity_g}, 0.00015, "$text keeps the microgram quantity");
	is($ingredient->{quantity_reference}, {text => '100 g', quantity_g => 100}, "$text reads its reference");
}

my $second_group = parse('en', 'Tomatoes (organic) (148 g per 100 g of ketchup)');
flatten_sub_ingredients($second_group);
is([grep {defined} map {$_->{quantity}} @{$second_group->{ingredients}}],
	['148 g'], 'a statement without an ingredient of its own is not discarded');

my $dosages = parse('en', 'sucralose (20 mg/100 g, 5 mg per 25 g)');
is($dosages->{ingredients}[0]{quantity}, '20 mg/100g', 'a later statement does not replace the first quantity');

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

for my $case (
	['en', 'Tomatoes (148 g per 100 g of finished product and salt 2%)'],
	['fr', 'Tomates (148 g pour 100 g de produit fini et sel 2%)']
	)
{
	my $product = parse(@$case);
	my @nodes = @{$product->{ingredients}};
	my @salt;
	while (my $ingredient = shift @nodes) {
		push @salt, $ingredient if $ingredient->{id} eq 'en:salt';
		push @nodes, @{$ingredient->{ingredients} // []};
	}
	is([map {$_->{percent}} @salt], [2], 'a reference does not consume the next declared ingredient');
	unlike($product->{ingredients}[0]{quantity_reference}{text} // '',
		qr/\b(?:salt|sel)\b/, 'reference wording excludes an adjacent ingredient declaration');
}

is([map {$_->{id}} @{parse('fr', 'fraises, bio équivalent à 20% de fruits rouges')->{ingredients}}],
	['en:strawberry'], 'a label alone is not the name of an equivalence');

my $parenthesised = parse('en', 'sugar, dried carrots (0.6% equivalent to 4% of carrots), salt, water');
extract_ingredients_from_text($parenthesised);
ok($parenthesised->{ingredients}[1]{percent_estimate} > 0, 'a percent alone is not the name of an equivalence');

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
