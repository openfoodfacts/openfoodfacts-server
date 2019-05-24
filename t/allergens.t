#!/usr/bin/perl -w

use strict;
use warnings;
use utf8;

use Test::More;
use Log::Any::Adapter 'TAP';

use ProductOpener::Products qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Ingredients qw/:all/;

# dummy product for testing

my $product_ref = {
	lc => "fr", lang => "fr",
	ingredients_text_fr => "Eau, LAIT, farine de BLE, sucre, sel, _oeufs_, moutarde, _crustacés_, fruits à coque, _céleri_, POISSON, crème de cassis. Contient mollusques. Peut contenir des traces d'arachide, de _soja_, de LUPIN, et de sésame "
};

compute_languages($product_ref);
detect_allergens_from_text($product_ref);

diag explain $product_ref->{allergens_tags};

is_deeply($product_ref->{allergens_tags}, [
'en:gluten',
'en:celery',
'en:crustaceans',
'en:eggs',
'en:fish',
'en:milk',
'en:molluscs',
'en:mustard',
'en:nuts',
]
) || diag explain $product_ref->{allergens_tags};

is_deeply($product_ref->{traces_tags},  [
'en:lupin',
'en:peanuts',
'en:sesame-seeds',
'en:soybeans',
]
);

$product_ref = {
	lc => "fr", lang => "fr",
	ingredients_text_fr => "Farine (blé), graines [sésame], condiments (moutarde), sucre de canne, lait de coco"
};

compute_languages($product_ref);
detect_allergens_from_text($product_ref);

is_deeply($product_ref->{allergens_tags}, [
"en:gluten",
"en:mustard",
"en:sesame-seeds",
]
);

is_deeply($product_ref->{traces_tags},  [
]
);

is($product_ref->{ingredients_text_with_allergens_fr},
'Farine (<span class="allergen">blé</span>), graines [<span class="allergen">sésame</span>], condiments (<span class="allergen">moutarde</span>), sucre de canne, lait de coco'
);


$product_ref = {
	lc => "fr", lang => "fr",
	ingredients_text_fr => "Farine de blé et de lupin, épices (soja, moutarde et céleri), crème de cassis, traces de fruits à coques, d'arachide et de poisson"
};

compute_languages($product_ref);
detect_allergens_from_text($product_ref);

is_deeply($product_ref->{allergens_tags}, [
"en:gluten",
"en:celery",
"en:lupin",
"en:mustard",
"en:soybeans",
]
);

is_deeply($product_ref->{traces_tags},  [
"en:fish",
"en:nuts",
"en:peanuts",
]
);

is($product_ref->{ingredients_text_with_allergens_fr},
'Farine de <span class="allergen">blé</span> et de <span class="allergen">lupin</span>, épices (<span class="allergen">soja</span>, <span class="allergen">moutarde</span> et <span class="allergen">céleri</span>), crème de cassis, traces de <span class="allergen">fruits à coques</span>, d\'<span class="allergen">arachide</span> et de <span class="allergen">poisson</span>'
);


$product_ref = {
	lc => "fr", lang => "fr",
	ingredients_text_fr => "Garniture 61% : sauce tomate 32% (purée de tomate, eau, farine de blé, sel, amidon de maïs), mozzarella 26%, chiffonnade de jambon cuit standard 21% (jambon de porc, eau, sel, dextrose, sirop de glucose, stabilisant : E451, arômes naturels, gélifiant : E407, lactose, bouillon de porc, antioxydant : E316, conservateur : E250, ferments), champignons de Paris 15% (champignons, extrait naturel de champignon concentré), olives noires avec noyau (stabilisant : E579), roquette 0,6%, basilic et origan. Pourcentages exprimés sur la garniture. Pâte 39% : farine de blé, eau, levure boulangère, sel, farine de blé malté.",
};

compute_languages($product_ref);
detect_allergens_from_text($product_ref);

is_deeply($product_ref->{allergens_tags}, [
'en:gluten',
'en:milk',
]
);

is_deeply($product_ref->{traces_tags},  [
]
);

is($product_ref->{ingredients_text_with_allergens_fr},
'Garniture 61% : sauce tomate 32% (purée de tomate, eau, farine de <span class="allergen">blé</span>, sel, amidon de maïs), <span class="allergen">mozzarella</span> 26%, chiffonnade de jambon cuit standard 21% (jambon de porc, eau, sel, dextrose, sirop de glucose, stabilisant : E451, arômes naturels, gélifiant : E407, <span class="allergen">lactose</span>, bouillon de porc, antioxydant : E316, conservateur : E250, ferments), champignons de Paris 15% (champignons, extrait naturel de champignon concentré), olives noires avec noyau (stabilisant : E579), roquette 0,6%, basilic et origan. Pourcentages exprimés sur la garniture. Pâte 39% : farine de blé, eau, levure boulangère, sel, farine de blé malté.'
);


$product_ref = {
	lc => "fr", lang => "fr",
	ingredients_text_fr => "Traces éventuelles de céréales contenant du gluten, fruits à coques, arachide, soja et oeuf.",
};

compute_languages($product_ref);
detect_allergens_from_text($product_ref);

is_deeply($product_ref->{allergens_tags}, [
]
);

is_deeply($product_ref->{traces_tags},  [
'en:gluten',
'en:eggs',
'en:nuts',
'en:peanuts',
'en:soybeans',
]
);


$product_ref = {
	lc => "fr", lang => "fr",
	ingredients_text_fr => "Noix de Saint-Jacques"
};

compute_languages($product_ref);
detect_allergens_from_text($product_ref);

diag explain $product_ref->{allergens_tags};

is_deeply($product_ref->{allergens_tags}, [
'en:molluscs',
]
);


$product_ref = {
        lc => "fr", lang => "fr",
        ingredients_text_fr => "Noix de St-Jacques"
};

compute_languages($product_ref);
detect_allergens_from_text($product_ref);

diag explain $product_ref->{allergens_tags};

is_deeply($product_ref->{allergens_tags}, [
'en:molluscs',
]
);


$product_ref = {
        lc => "fr", lang => "fr",
        ingredients_text_fr => "Saint Jacques"
};

compute_languages($product_ref);
detect_allergens_from_text($product_ref);

diag explain $product_ref->{allergens_tags};

is_deeply($product_ref->{allergens_tags}, [
'en:molluscs',
]
);


$product_ref = {
        lc => "fr", lang => "fr",
        ingredients_text_fr => "St Jacques"
};

compute_languages($product_ref);
detect_allergens_from_text($product_ref);

diag explain $product_ref->{allergens_tags};

is_deeply($product_ref->{allergens_tags}, [
'en:molluscs',
]
);


$product_ref = {
        lc => "fr", lang => "fr",
        ingredients_text_fr => "Farine de blé 97%"
};

compute_languages($product_ref);
detect_allergens_from_text($product_ref);

diag explain $product_ref->{allergens_tags};

is_deeply($product_ref->{allergens_tags}, [
'en:gluten',
]
);

is($product_ref->{ingredients_text_with_allergens_fr},
'Farine de <span class="allergen">blé</span> 97%'
);

$product_ref = {
        lc => "fr", lang => "fr",
        ingredients_text_fr => "Farine de blé 97%"
};

compute_languages($product_ref);
detect_allergens_from_text($product_ref);

diag explain $product_ref->{allergens_tags};

is_deeply($product_ref->{allergens_tags}, [
'en:gluten',
]
);

is($product_ref->{ingredients_text_with_allergens_fr},
'Farine de <span class="allergen">blé</span> 97%'
);


$product_ref = {
        lc => "fr", lang => "fr",
        ingredients_text_fr => "Farine de blé 97%",
	allergens => "Sulfites",
};

compute_languages($product_ref);
detect_allergens_from_text($product_ref);

diag explain $product_ref->{allergens_tags};

is_deeply($product_ref->{allergens_tags}, [
'en:gluten',
'en:sulphur-dioxide-and-sulphites',
]
);





done_testing();
