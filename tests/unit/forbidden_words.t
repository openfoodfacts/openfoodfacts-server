#!/usr/bin/perl -w

use utf8;
use ProductOpener::PerlStandards;
use feature qw(signatures);
no warnings qw(experimental::signatures);

use Test2::V0;

use ProductOpener::ForbiddenWords qw(
	check_forbidden_words
	contains_forbidden_words
	is_barcode_allowed
	get_forbidden_words_list
	get_forbidden_words_regexp
	$ALL_FORBIDDEN_WORDS_REGEXP_STR
);

# --- contains_forbidden_words tests ---

subtest 'French profanity, slurs and vandalism' => sub {
	ok(contains_forbidden_words('sexe amour pipi caca bite cul gazi', 'fr'), 'childish vandalism in French');
	ok(contains_forbidden_words("C'est de la grosse MERDE", 'fr'), 'uppercase insult');
	ok(contains_forbidden_words("Espèce d'enfoiré", 'fr'), 'accented insult');
	ok(contains_forbidden_words("espece d'enfoire", 'fr'), 'unaccented insult');
	ok(contains_forbidden_words('gros connard', 'fr'), 'connard');
	ok(contains_forbidden_words('petite salope', 'fr'), 'salope');
	ok(contains_forbidden_words('quel bâtard', 'fr'), 'batard with circumflex');
	ok(contains_forbidden_words('quel batard', 'fr'), 'batard unaccented');
	ok(contains_forbidden_words('va te faire enculer', 'fr'), 'enculer');
	ok(contains_forbidden_words('gros enculé', 'fr'), 'encule with acute accent');
	ok(contains_forbidden_words('fils de pute', 'fr'), 'multi-word fils de pute');
	ok(contains_forbidden_words('nique ta mère', 'fr'), 'multi-word nique ta mere');
	ok(contains_forbidden_words('trou du cul', 'fr'), 'multi-word trou du cul');
	ok(contains_forbidden_words('sac à merde', 'fr'), 'multi-word sac a merde');
	ok(contains_forbidden_words('Gros étron puant', 'fr'), 'étron with accent');
};

subtest 'English profanity and slurs' => sub {
	ok(contains_forbidden_words('What the fuck is this', 'en'), 'fuck');
	ok(contains_forbidden_words('Piece of shit', 'en'), 'shit');
	ok(contains_forbidden_words('Total bullshit', 'en'), 'bullshit');
	ok(contains_forbidden_words('Stupid bitch', 'en'), 'bitch');
	ok(contains_forbidden_words('Shut up asshole', 'en'), 'asshole');
	ok(contains_forbidden_words('Fucking ridiculous', 'en'), 'fucking');
	ok(contains_forbidden_words('You bastard', 'en'), 'bastard');
	ok(contains_forbidden_words('Shut up dickhead', 'en'), 'dickhead');
	ok(contains_forbidden_words('Total motherfucker', 'en'), 'motherfucker');
};

subtest 'Other European languages (Spanish, German, Italian)' => sub {
	ok(contains_forbidden_words('Vaya mierda', 'es'), 'Spanish mierda');
	ok(contains_forbidden_words('Eres un gilipollas', 'es'), 'Spanish gilipollas');
	ok(contains_forbidden_words('Du Arschloch', 'de'), 'German arschloch');
	ok(contains_forbidden_words('Das ist scheisse', 'de'), 'German scheisse');
	ok(contains_forbidden_words('Che cazzo', 'it'), 'Italian cazzo');
	ok(contains_forbidden_words('Sei uno stronzo', 'it'), 'Italian stronzo');
};

subtest 'False positive protection (legitimate food terms)' => sub {
	ok(!contains_forbidden_words('Chocolate Bites 100g', 'en'), 'English bites');
	ok(!contains_forbidden_words('Pretzel Bites', 'en'), 'Pretzel bites');
	ok(!contains_forbidden_words('Energy Bites Peanut Butter', 'en'), 'Energy bites');
	ok(!contains_forbidden_words('Extra Virgin Olive Oil', 'en'), 'Virgin olive oil');
	ok(!contains_forbidden_words('Arroz con leche', 'es'), 'Spanish con');
	ok(!contains_forbidden_words('Tortilla con cebolla', 'es'), 'Spanish con');
	ok(!contains_forbidden_words('Classic Cocktails', 'en'), 'Classic & cocktails');
	ok(!contains_forbidden_words('Peacock brand jasmine rice', 'en'), 'Peacock');
	ok(!contains_forbidden_words('Apple Tart', 'en'), 'Tart');
	ok(!contains_forbidden_words('Chicken breast fillets', 'en'), 'Chicken breast');
	ok(!contains_forbidden_words('Cheese balls', 'en'), 'Cheese balls');
	ok(!contains_forbidden_words('Meat balls in tomato sauce', 'en'), 'Meat balls');
	ok(!contains_forbidden_words('Jerk Chicken Seasoning', 'en'), 'Jerk chicken');
	ok(!contains_forbidden_words('Spotted Dick Traditional Pudding', 'en'), 'Spotted Dick');
	ok(!contains_forbidden_words('Bloody Mary Mix', 'en'), 'Bloody Mary');
	ok(!contains_forbidden_words("Gerbe d'Or Biscuits", 'fr'), "Gerbe d'or");
	ok(!contains_forbidden_words('Olive Tanche de Nyons', 'fr'), 'Olive tanche');
	ok(!contains_forbidden_words('Ménage à Trois Red Wine', 'en'), 'Ménage à trois wine');
	ok(!contains_forbidden_words('Cassonade de canne', 'fr'), 'Cassonade');
	ok(!contains_forbidden_words('Passion fruit juice', 'en'), 'Passion fruit');
	ok(!contains_forbidden_words('Verre en plastique', 'fr'), 'Verre');
	ok(!contains_forbidden_words('potassium sorbate [to retard spoilage], xanthan gum', 'en'), 'retard spoilage preservative');
	ok(!contains_forbidden_words('potassium sorbate [to [retard] spoilage], xanthan gum', 'en'), 'bracketed retard spoilage');
	ok(!contains_forbidden_words('Calcium propionate added to retard staling', 'en'), 'retard staling');
	ok(!contains_forbidden_words('', 'en'), 'empty string');
	ok(!contains_forbidden_words(undef, 'en'), 'undef string');
};

# --- check_forbidden_words tests on product structures ---

subtest 'check_forbidden_words on clean product' => sub {
	my $product = {
		product_name => 'Pain au chocolat',
		ingredients_text => 'Farine de blé, beurre, chocolat, sucre, levure, sel',
		brands => 'Monoprix Gourmet',
		lang => 'fr',
		data_quality_warnings_tags => [],
	};
	check_forbidden_words($product);
	is($product->{data_quality_warnings_tags}, [], 'clean product has no warning tags');
};

subtest 'check_forbidden_words on product with forbidden name' => sub {
	my $product = {
		product_name => 'sexe amour pipi caca bite cul gazi',
		lang => 'fr',
		data_quality_warnings_tags => [],
	};
	check_forbidden_words($product);
	ok(grep({ $_ eq 'en:product-name-contains-forbidden-words' } @{$product->{data_quality_warnings_tags}}),
		'flagged with product-name-contains-forbidden-words');
	ok(grep({ $_ eq 'en:forbidden-words-warnings' } @{$product->{data_quality_warnings_tags}}),
		'flagged with forbidden-words-warnings');
	ok(!grep({ $_ eq 'en:ingredients-contain-forbidden-words' } @{$product->{data_quality_warnings_tags}}),
		'not flagged for ingredients');
};

subtest 'check_forbidden_words on localized product name' => sub {
	my $product = {
		product_name => 'Sausages',
		product_name_fr => 'Saucisses de merde',
		data_quality_warnings_tags => [],
	};
	check_forbidden_words($product);
	ok(grep({ $_ eq 'en:product-name-contains-forbidden-words' } @{$product->{data_quality_warnings_tags}}),
		'flagged localized product name');
	ok(grep({ $_ eq 'en:forbidden-words-warnings' } @{$product->{data_quality_warnings_tags}}),
		'flagged with parent warning tag');
};

subtest 'check_forbidden_words on forbidden ingredients' => sub {
	my $product = {
		product_name => 'Nutella',
		ingredients_text => 'Sugar, palm oil, what the fuck, hazelnuts',
		lang => 'en',
		data_quality_warnings_tags => [],
	};
	check_forbidden_words($product);
	ok(grep({ $_ eq 'en:ingredients-contain-forbidden-words' } @{$product->{data_quality_warnings_tags}}),
		'flagged ingredients-contain-forbidden-words');
	ok(grep({ $_ eq 'en:forbidden-words-warnings' } @{$product->{data_quality_warnings_tags}}),
		'flagged with parent warning tag');
	ok(!grep({ $_ eq 'en:product-name-contains-forbidden-words' } @{$product->{data_quality_warnings_tags}}),
		'not flagged for product name');
};

subtest 'check_forbidden_words on forbidden brand' => sub {
	my $product = {
		product_name => 'T-Shirt',
		brands => 'Connard & Cie',
		lang => 'fr',
		data_quality_warnings_tags => [],
	};
	check_forbidden_words($product);
	ok(grep({ $_ eq 'en:brands-contain-forbidden-words' } @{$product->{data_quality_warnings_tags}}),
		'flagged brands-contain-forbidden-words');
	ok(grep({ $_ eq 'en:forbidden-words-warnings' } @{$product->{data_quality_warnings_tags}}),
		'flagged with parent warning tag');
};

subtest 'ALL_FORBIDDEN_WORDS_REGEXP_STR edit rule regexp' => sub {
	ok(defined $ALL_FORBIDDEN_WORDS_REGEXP_STR, 'regexp string is defined');
	my $re = qr/$ALL_FORBIDDEN_WORDS_REGEXP_STR/i;
	like('Caca', $re, 'matches Caca');
	like('merde', $re, 'matches merde');
	like('gros enculé', $re, 'matches accented enculé');
	like('gros encule', $re, 'matches unaccented encule');
	like('fuck this', $re, 'matches fuck');
	unlike('Chocolate bites', $re, 'does not match bites');
	unlike('Extra virgin olive oil', $re, 'does not match virgin');
};

subtest 'Allowlist barcodes and patterns' => sub {
	# Real novelty product barcodes from BigQuery list
	ok(is_barcode_allowed('5410293620116'), 'couilles de singe barcode is allowed');
	ok(is_barcode_allowed('3760182600142'), 'vin de merde barcode is allowed');
	ok(is_barcode_allowed('5902837741031'), 'fucking delicious cookie barcode is allowed');
	ok(!is_barcode_allowed('9999999999999'), 'random barcode is not allowed');

	# Product with allowed barcode bypasses warning tags completely
	my $allowed_product = {
		code => '5410293620116',
		product_name => 'Couilles de singe',
		ingredients_text => 'Sucre, sirop de glucose, arome',
		brands => 'Couilles de singe',
		lang => 'fr',
		data_quality_warnings_tags => [],
	};
	check_forbidden_words($allowed_product);
	is($allowed_product->{data_quality_warnings_tags}, [], 'allowed barcode product has no warnings');

	# Allowlist patterns
	ok(!contains_forbidden_words('Chocolat noir au cacao pur', 'fr'), 'cacao is allowed');
	ok(!contains_forbidden_words('Salade de pissenlits et cornichons', 'fr'), 'pissenlits is allowed');
	ok(!contains_forbidden_words('Pain fesse traditionnel', 'fr'), 'pain fesse is allowed');
	ok(!contains_forbidden_words('Traditional spotted dick pudding', 'en'), 'spotted dick is allowed');

	# Country rule: German turkey ("Pute")
	ok(!contains_forbidden_words('Sandwich Pute', 'de', 'en:germany'), 'German Pute in Germany is allowed');
	ok(!contains_forbidden_words('Putenbrust geräuchert', 'de', 'en:germany'), 'German Putenbrust is allowed');
	ok(contains_forbidden_words('Sale pute', 'fr', 'en:france'), 'French insult is flagged');
};

subtest 'check_forbidden_words skipping when all ingredients are recognized' => sub {
	my $product = {
		product_name => 'Clean bread',
		ingredients_text => 'Farine, sel, potassium sorbate',
		unknown_ingredients_n => 0,
		known_ingredients_n => 3,
		ingredients_n => 3,
		lang => 'fr',
		data_quality_warnings_tags => [],
	};
	check_forbidden_words($product);
	is($product->{data_quality_warnings_tags}, [], 'skips ingredients when 100% recognized and no other languages');
};

done_testing();
