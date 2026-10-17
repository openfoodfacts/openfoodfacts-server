use ProductOpener::PerlStandards;
use Test2::V0;
use ProductOpener::Tags qw(canonicalize_taxonomy_tag is_a);
use ProductOpener::Ingredients qw(parse_ingredients_text_service);

for my $fruit ('apple', 'orange', 'blueberry') {
	for my $name ("$fruit juice concentrate", "$fruit juice concentrates") {
		is(
			canonicalize_taxonomy_tag('en', 'ingredients', $name),
			"en:concentrated-$fruit-juice",
			"$name identifies concentrated juice"
		);
	}
	is(
		canonicalize_taxonomy_tag('en', 'ingredients', "$fruit juice from concentrate"),
		"en:$fruit-juice-from-concentrate",
		'juice from concentrate retains its identity'
	);
	ok(is_a('ingredients', "en:concentrated-$fruit-juice", "en:$fruit-juice"),
		'the concentrate retains its juice parent');
	my $product = {lc => 'en', ingredients_text => "$fruit juice concentrate"};
	parse_ingredients_text_service($product, {}, []);
	is(
		[map {$_->{id}} @{$product->{ingredients}}],
		["en:concentrated-$fruit-juice"],
		'parsing preserves the concentrate identity'
	);
}

done_testing;
