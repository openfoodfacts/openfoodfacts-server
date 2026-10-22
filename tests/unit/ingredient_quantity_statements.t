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
