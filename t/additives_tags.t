#!/usr/bin/perl -w

use strict;
use warnings;

use utf8;

use Test::More;
use Log::Any::Adapter 'TAP';

use ProductOpener::Tags qw/:all/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::Products qw/:all/;

# dummy product for testing

my @tests = (
[ { lc => "en", ingredients_text => "water, sugar, tea, lemon juice, flavouring, acidity regulator (330, 331), vitamin C, antioxidant (304)" }, [ "en:e330", "en:e331", "en:e304" ] ], 
[ { lc => "en", ingredients_text => "REAL SUGARCANE, SALT, ANTIOXIDANT (INS 300), ACIDITY REGULATOR (INS 334), STABILIZER (INS 440, INS 337), WATER (FOR MAINTAINING DESIRED BRIX), CONTAINS PERMITTED NATURAL FLAVOUR & NATURAL IDENTICAL COLOURING SUBSTANCES (INS 141[i])" }, [ "en:e300", "en:e334", "en:e440", "en:e337", "en:e141" ] ], 
[ { lc => "fr", ingredients_text => "Stabilisants: (SIN450i, SIN450iii), antioxydant (SIN316), Agent de conservation: (SIN250)." }, [ "en:e450i", "en:e450iii", "en:e316", "en:e250" ] ], 
[ { lc => "fr", ingredients_text => "Laitue, Carmine" }, [ ] ], 
[ { lc => "fr", ingredients_text => "poudres à lever (carbonates acides d’ammonium et de sodium, acide citrique)" }, ["en:e503ii", "en:e500ii", "en:e330" ] ], 
[ { lc => "fr", ingredients_text => "Saumon Atlantique* 97% (salmo salar), sel. poissons. Saumon élevé en/au : voir sur la face avant. INFORMATIONS : A consommerjusqu'au / NO de lot : voir sur la face avant. A conserver entre OOC et +40C avant et" }, [ ] ], 
[ { lc => "fr", ingredients_text => "Liste des ingrédients : viande de porc, sel, lactose, épices, sucre, dextrose, ail, conservateurs : nitrate de potassium et nitrite de sodium, ferments, boyau naturel de porc. Poudre de fleurage : talc et carbonate de calcium. 164 g de viande de porc utilisée poudre 100 g de produit fini. Substances ou produits provoquant des allergies ou intolérances : Lait" }, [ "en:e252", "en:e250", "en:e553b", "en:e170" ] ], 
[ { lc => "fr", ingredients_text => "conservateurs: nitrate de potassium et nitrite de sodium" }, [ "en:e252", "en:e250" ] ], 

# currently does not pass
#[ { lc => "en", ingredients_text => "INGREDIENTS: Parboiled rice, (enriched with iron (Ferric Orthophosphate), Niacin, Thiamine (Thiamine Mononitrate), Folic Acid, Chicken Base (Containing Modified Food Starch, Salt, Hydrolyzed Soy Protein. Sugar, Onion, Garlic, Herbs and Spices And Natural Chicken Skin), Dehydrated Bell Peppers and Onion, Spices (Including Paprika, Turmeric And Spice Extracts), Olive Oil, FD&C Yellow#5 and #6, FD&C Red #40 Lake And Silicon Dioxide For Anti Caking." }, [ ""] ], 

[ { lc => "en", ingredients_text => "FD&C Red #40 and silicon dioxide" }, [ "en:e129" ] ], 

[ { lc => "pl", ingredients_text => "przeciwutleniacz E385" }, [ "en:e385" ] ], 
[ { lc => "pl", ingredients_text => "mięso wieprzowe, meso wołowe, sól, białko sojowe, dekstroza, przyprawy (zawierają seler i gorczyce), ekstrakt przypraw, przeciwutleniacz E301; barwnik E120, substancja konserwująca E250, kultury starterowe. Otoczone żelatyna wieprzowa, pieprz kolorowy 6,5% (czarny biały, zielony, różowy), substancja konserwująca: E202. Do wywożenia 100 g produktu zużyto 114 g mięsa wieprzowego i 2 g mięsa wołowego." }, [ "en:e301", "en:e120", "en:e250", "en:e202" ] ], 
[ { lc => "pl", ingredients_text => "Mięso wieprzowe (75%), woda, sól spożywcza, skrobia modyfikowana, białko wieprzowe cebula suszona, przyprawy, smalec wieprzowy, stabilizatory: difosforany, wzmacniacz smaku glutaminian monosodowy." }, [ "en:e14xx", "en:e450", "en:e621" ] ], 
[ { lc => "pl", ingredients_text => "45% płaty ze śledzia atlantyckiego (Clupea harengus)* (śledź, sól, regulator kwasowości: kwas octowy), woda, 7,5% cebula marynowana, 5% marchew gotowana, sól, ocet spirytusowy, papryka konserwowa czerwona, gorczyca, cukier, regulator kwasowości (octany sodu), glukoza, substancja słodząca (sacharyny), aromat. Po otwarciu - produkt przeznaczony do bezpośredniego spożycia. Produkt może zawierać gluten. *Złowiono w Północno-Wschodnim Atlantyku (FAO 27) w Morzu Północnym (1), w Morzu Norweskim (2), w Morzu Celtyckim (3), w Skagerrak i Kattegat (8), w Morzu lrlandzkim (11), w Morzu Bałtyckim (13) za pomocą włoków pelagicznych (A), okrężnic (B). Właściwe oznakowanie podobszaru połowu i kategorii narzędzia połowowego - patrz nadruk za datą terminu przydatności do spożycia." }, [ "en:e260", "en:e262", "en:e954" ] ], 
[ { lc => "pl", ingredients_text => "woda, mleczan magnezu, regulatory kwasowości: kwas cytrynowy i cytryniany sodu; dwutlenek węgla, barwnik; koncentrat z czarnej marchwi; naturalny aromat, ekstrakt z guarany, ekstrakt z żeń-szenia (0,01%), ekstrakt z jagód acai (0,01%), ekstrakt z miechunki peruwiańskiej (0,01%); substancje słodzące: sukraloza, acesulfam K; przeciwutleniacz: kwas askorbinowy; substancje wzbogacające: witaminy: niacyna, kwas pantotenowy, witamina B6, biotyna; glukonian cynku, seleniar (IV) sodu." }, [ "en:e329","en:e330","en:e331","en:e290","en:e955","en:e950","en:e300" ] ], 
[ { lc => "pl", ingredients_text => "Mąka pszenna, cukier 22,1% , olej palmowy, syrop glukozowo-fruktozowy, pełne mleko w proszku, substancje spulchniające (węglany amonu, węglany sodu, difosforany), jaja w proszku, sól, emulgator (stearoilomleczan sodu), aromat. Może zawierać sezam i orzechy." }, [ "en:e503", "en:e500", "en:e450", "en:e481" ] ], 
[ { lc => "pl", ingredients_text => "Mleczna baza [syrop glukozowy, oleje roślinne (kokosowy, z ziaren palmowych w zmiennych proporcjach), mleko w proszku odtłuszczone (5%), serwatka (z mleka) w proszku, regulatory kwasowości: fosforan dipotasowy, cytrynian trisodowy, białka mleka, substancja przeciwzbrylajaca: dwutlenek krzemu], cukier, kawa rozpuszczalna (8,7%), kawa zbożowa rozpuszczalna (ekstrakt prażonego jęczmienia i żyta) (6%), węglan magnezu, mleko w proszku pełne (1%), aromat. Produkt może zawierać soję." }, [ "en:e340ii", "en:e331iii", "en:e551" ] ], 
[ { lc => "pl", ingredients_text => "regulatory kwasowości: kwas cytrynowy i cytryniany sodu." }, [ "en:e330","en:e331" ] ], 
);

foreach my $test_ref (@tests) {

	my $product_ref = $test_ref->[0];
	my $expected_tags = $test_ref->[1];

	$product_ref->{categories_tags} = ["en:debug"];
	$product_ref->{"ingredients_text_" . $product_ref->{lc}} = $product_ref->{ingredients_text};

	extract_ingredients_classes_from_text($product_ref);

	is_deeply ($product_ref->{additives_original_tags}, 
		$expected_tags) or diag explain $product_ref;
}

done_testing();
