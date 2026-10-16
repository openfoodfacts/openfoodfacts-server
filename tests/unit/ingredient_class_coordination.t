use ProductOpener::PerlStandards;
use Test2::V0;
use ProductOpener::Ingredients qw(parse_ingredients_text_service extract_additives_from_text);

sub parse ($text) {
	my $product = {lc => 'en', ingredients_text => $text};
	parse_ingredients_text_service($product, {}, []);
	return $product->{ingredients};
}

sub additives ($lc, $text) {
	my $product = {lc => $lc, ingredients_text => $text};
	extract_additives_from_text($product);
	return $product;
}

for my $text ('Minerals & Vitamins', 'Minerals and Vitamins', 'Vitamins and Minerals') {
	my $ingredients = parse($text);
	is([sort map {$_->{id}} @$ingredients], ['en:minerals', 'en:vitamins'], "$text contains sibling classes");
	is([grep {exists $_->{ingredients}} @$ingredients], [], "$text has no invented class-to-class hierarchy");
}

for my $text ('Minerals & Vitamins & Amino acids', 'Amino acids and Minerals and Vitamins') {
	my $classes = parse($text);
	is(
		[sort map {$_->{id}} @$classes],
		['en:amino-acids', 'en:minerals', 'en:vitamins'],
		"$text contains sibling classes"
	);
	is([grep {exists $_->{ingredients}} @$classes], [], "$text has no invented class-to-class hierarchy");
}
is(
	[map {$_->{id}} @{parse('Thickeners and stabilisers and emulsifiers')}],
	['en:thickener', 'en:stabiliser', 'en:emulsifier'],
	'a chain of classes keeps each of them'
);
is(
	[sort map {$_->{id}} @{parse("Minerals\x{a0}and\x{a0}Vitamins")}],
	['en:minerals', 'en:vitamins'],
	'non-breaking spaces do not hide a class'
);

my $embedded = parse('Meat; Amino acids, Minerals & Vitamins; Thickeners');
is(
	[map {$_->{id}} @$embedded],
	['en:meat', 'en:amino-acids', 'en:minerals', 'en:vitamins', 'en:thickener'],
	'classes remain peers between other ingredients'
);

my $recipes
	= parse('With Grilled Tuna Ingredients: Meat; Amino acids, Minerals & Vitamins; Thickeners; '
		. 'Non-artificial coloursWith Grilled Salmon Ingredients: Meat; Minerals & Vitamins; '
		. 'SugarsWith Grilled Cod Ingredients: Meat; Minerals & Vitamins; Sugar');
is(
	[map {$_->{id}} grep {$_->{id} eq 'en:minerals' || $_->{id} eq 'en:vitamins'} @$recipes],
	['en:minerals', 'en:vitamins', 'en:minerals', 'en:vitamins', 'en:minerals', 'en:vitamins'],
	'each Fancy Feast recipe keeps coordinated classes at the same level'
);

my $minerals = parse('Minerals (calcium carbonate, magnesium carbonate)');
is($minerals->[0]{id}, 'en:minerals', 'a genuine mineral class remains recognised');
is(
	[map {$_->{id}} @{$minerals->[0]{ingredients}}],
	['en:e170i', 'en:e504i'],
	'explicit class contents retain their parent'
);

is(
	[map {$_->{id}} @{parse('Meat and animal derivatives')}],
	['en:meat-and-animal-derivatives'],
	'declared compounds remain intact'
);
is(
	[map {$_->{id}} @{parse('Vitamins: vitamin E, biotin')}],
	['en:vitamins', 'en:vitamin-e', 'en:biotin'],
	'vitamin enumerations retain their existing interpretation'
);

is(additives('en', 'Minerals & Vitamins')->{minerals_tags},
	['en:mineral'], 'a coordinated class keeps its nutrient tags');
my $amino_acids = additives('en', 'Amino acids and Minerals');
is($amino_acids->{additives_tags}, ['en:amino-acids'], 'the first coordinated class keeps its additive tag');
is($amino_acids->{additives_n}, 1, 'the first coordinated class is counted');
for my $case (
	['de', 'Zucker, Antioxidationsmittel und Säuerungsmittel (Ascorbinsäure)', ['en:e300']],
	['it', 'Antiossidante e acidificante: acido ascorbico, acido citrico', ['en:e300', 'en:e330']],
	)
{
	my ($lc, $text, $tags) = @$case;
	is(additives($lc, $text)->{additives_tags}, $tags, "$text keeps its additives");
}

done_testing;
