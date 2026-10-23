use ProductOpener::PerlStandards;
use Test2::V0;
use JSON::MaybeXS;
use Time::HiRes qw(time);
use ProductOpener::Ingredients::Sections qw(split_ingredient_sections);
use ProductOpener::Ingredients qw(
	clean_ingredients_text parse_ingredients_text_service extract_ingredients_from_text
	extract_additives_from_text detect_allergens_from_text
);

open(my $input, '<:raw', 'tests/unit/inputs/ingredient_sections/products.json') or die $!;
my $cases = JSON::MaybeXS->new->utf8->decode(do {local $/; <$input>});
close($input) or die $!;
my %products = map {$_->{code} => $_} @$cases;

sub product ($code) {
	my $case = $products{$code};
	return {
		code => $code,
		lc => $case->{lc},
		product_type => 'petfood',
		ingredients_text => $case->{text},
		nutrition => {},
	};
}

sub analyze ($product) {
	clean_ingredients_text($product);
	extract_ingredients_from_text($product);
	extract_additives_from_text($product);
	detect_allergens_from_text($product);
	return;
}

sub nodes ($ingredients) {
	my @nodes;
	for my $ingredient (@{$ingredients // []}) {
		push @nodes, $ingredient, nodes($ingredient->{ingredients});
	}
	return @nodes;
}

my $salmon = product('4047777023111');
analyze($salmon);
is(
	[map {$_->{type}} @{$salmon->{ingredients_sections} // []}],
	['ingredients', 'analytical'],
	'characteristic untitled analytical data is separated'
);
is(($salmon->{ingredients_sections} // [])->[1]{inferred}, 1, 'untitled boundary is explicitly marked inferred');
my @oil = grep {$_->{id} eq 'en:salmon-fish-oil'} nodes($salmon->{ingredients});
is(scalar @oil, 1, 'salmon oil is recognised independently');
is($oil[0]{percent}, 10, 'salmon oil retains its declared percentage');
is($salmon->{minerals_tags}, [], 'analytical mineral values do not become additive mineral tags');

{
	my ($lc, $text, $description) = ('fr', 'protéines' . (' ' x 20000) . 'x', 'spaces after a nutrient');
	my $start = time;
	split_ingredient_sections($text, $lc);
	ok(time - $start < 1, "a long run of $description is split without rescanning it from each character");
}

for my $text ("cendres brutes 2%\ncellulose brute 1%", "protéines 8%\ncendres brutes 2%\ncendres brutes 1%") {
	my $control = {lc => 'fr', product_type => 'petfood', ingredients_text => $text};
	parse_ingredients_text_service($control, {}, []);
	is($control->{ingredients_sections},
		undef, 'ordinary ingredients and isolated nutrient words do not create sections');
}

my $english = {
	lc => 'en',
	product_type => 'petfood',
	ingredients_text => "chicken, salmon oil 10%\ncrude protein 8%\ncrude fat 7%\ncrude ash 2%\ncrude fibre 1%"
};
parse_ingredients_text_service($english, {}, []);
is(($english->{ingredients_sections} // [])->[1]{inferred}, 1, 'English analytical inference uses the same safeguards');

done_testing;
