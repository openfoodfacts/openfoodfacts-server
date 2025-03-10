#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test2::V0;
use Data::Dumper;
$Data::Dumper::Terse = 1;    # rm variable name
$Data::Dumper::Indent = 1;
$Data::Dumper::Sortkeys = 1;

use ProductOpener::Tags qw/has_tag/;
use ProductOpener::TaxonomiesEnhancer qw/check_ingredients_between_languages/;

# TESTS
my $product_ref = {ingredients_text_hr => "sredsvo za rahljenje",};
check_ingredients_between_languages($product_ref);
ok(!exists $product_ref->{"taxonomies_enhancer_tags"}, 'single unknown ingredient should be ignored')
	or diag Dumper $product_ref;

my $product_ref = {
	ingredients_text_hu =>
		"69% búzaliszt, ivóvíz, repceolaj, stabilizátor: glicerin; búzaglutén, savanyúságot szabályozó anyag: almasav; étkezési só, emulgeálószer: zsírsavak mono - és digliceridjei; dextróz, térfogatnövelő szer: nátrium-karbonátok; tartósítószerek: kalcium-propionát, kálium-szorbát; lisztkezelő szer: L-Cisztein.",
	ingredients_text_it => "",
};
check_ingredients_between_languages($product_ref);
ok(!exists $product_ref->{"taxonomies_enhancer_tags"}, 'empty list should be ignored') or diag Dumper $product_ref;

$product_ref = {
	ingredients_text_hr => "69% pšenično brašno, voda",
	ingredients_text_hu =>
		"69% búzaliszt, ivóvíz, repceolaj, stabilizátor: glicerin; búzaglutén, savanyúságot szabályozó anyag: almasav; étkezési só, emulgeálószer: zsírsavak mono - és digliceridjei; dextróz, térfogatnövelő szer: nátrium-karbonátok; tartósítószerek: kalcium-propionát, kálium-szorbát; lisztkezelő szer: L-Cisztein.",
};
check_ingredients_between_languages($product_ref);
ok(!exists $product_ref->{"taxonomies_enhancer_tags"}, 'truncated list should be ignored') or diag Dumper $product_ref;

# TESTS STOP WORDS BEFORE INGREDIENTS LIST
$product_ref = {
	ingredients_text_hu =>
		"69% búzaliszt, ivóvíz, repceolaj, stabilizátor: glicerin; búzaglutén, savanyúságot szabályozó anyag: almasav; étkezési só, emulgeálószer: zsírsavak mono - és digliceridjei; dextróz, térfogatnövelő szer: nátrium-karbonátok; tartósítószerek: kalcium-propionát, kálium-szorbát; lisztkezelő szer: L-Cisztein.",
	ingredients_text_sk =>
		"some unknown words for ingredient: 69% pšeničná múka, pitná voda, repkový olej, stabilizátor: glycerol; pšeničný glutén, regulátor kyslosti: kyselina jablčná; jedlá soľ, emulgátor: mono - a diglyceridy mastných kyselín; dextróza, kypriaca látka: uhličitany sodné; konzervačné látky: propionan vápenatý, sorban draselný; múku upravujúca látka: L-cystein.",
};
check_ingredients_between_languages($product_ref);
ok(has_tag($product_ref, "taxonomies_enhancer", "possible-stop-word-before-sk-some-unknown-words-for-ingredient"),
	'sk has one stop word before')
	or diag Dumper $product_ref;

$product_ref = {
	ingredients_text_hu =>
		"69% búzaliszt, ivóvíz, repceolaj, stabilizátor: glicerin; búzaglutén, savanyúságot szabályozó anyag: almasav; étkezési só, emulgeálószer: zsírsavak mono - és digliceridjei; dextróz, térfogatnövelő szer: nátrium-karbonátok; tartósítószerek: kalcium-propionát, kálium-szorbát; lisztkezelő szer: L-Cisztein.",
	ingredients_text_sk =>
		"product name or something. some unknown words for ingredient: 69% pšeničná múka, pitná voda, repkový olej, stabilizátor: glycerol; pšeničný glutén, regulátor kyslosti: kyselina jablčná; jedlá soľ, emulgátor: mono - a diglyceridy mastných kyselín; dextróza, kypriaca látka: uhličitany sodné; konzervačné látky: propionan vápenatý, sorban draselný; múku upravujúca látka: L-cystein.",
};
check_ingredients_between_languages($product_ref);
ok(has_tag($product_ref, "taxonomies_enhancer", "possible-stop-word-before-sk-some-unknown-words-for-ingredient"),
	'sk has one stop word before and only one')
	or diag Dumper $product_ref;

$product_ref = {
	ingredients_text_hr =>
		"some unknown words for ingredient in hr: 69% pšenično brašno, voda, repičino ulje, stabilizator. glicerol; pšenični gluten, regulator kiselosti: jabučna kiselina; kuhinjska sol, emulgator: mono - i digliceridi masnih kiselina; dekstroza, tvar za rahljenje: natrijevi karbonati; konzervansi: kalcijev propionat, kalijev sorbat; tvar za tretiranje brašna: L-cistein. Čuvati na suhom mjestu.",
	ingredients_text_hu =>
		"69% búzaliszt, ivóvíz, repceolaj, stabilizátor: glicerin; búzaglutén, savanyúságot szabályozó anyag: almasav; étkezési só, emulgeálószer: zsírsavak mono - és digliceridjei; dextróz, térfogatnövelő szer: nátrium-karbonátok; tartósítószerek: kalcium-propionát, kálium-szorbát; lisztkezelő szer: L-Cisztein.",
	ingredients_text_sk =>
		"some unknown words for ingredient: 69% pšeničná múka, pitná voda, repkový olej, stabilizátor: glycerol; pšeničný glutén, regulátor kyslosti: kyselina jablčná; jedlá soľ, emulgátor: mono - a diglyceridy mastných kyselín; dextróza, kypriaca látka: uhličitany sodné; konzervačné látky: propionan vápenatý, sorban draselný; múku upravujúca látka: L-cystein.",
};
check_ingredients_between_languages($product_ref);
ok(
	has_tag(
		$product_ref, "taxonomies_enhancer", "possible-stop-word-before-hr-some-unknown-words-for-ingredient-in-hr"
	),
	'hr has one stop word before and it is not influenced by other lang stop word before'
) or diag Dumper $product_ref;
ok(has_tag($product_ref, "taxonomies_enhancer", "possible-stop-word-before-sk-some-unknown-words-for-ingredient"),
	'sk has one stop word before and it is not influenced by other lang stop word before')
	or diag Dumper $product_ref;

$product_ref = {
	ingredients_text_hr =>
		"69% pšenično brašno, voda, repičino ulje, stabilizator. glicerol; pšenični gluten, regulator kiselosti: jabučna kiselina; kuhinjska sol, emulgator: mono - i digliceridi masnih kiselina; dekstroza, tvar za rahljenje: natrijevi karbonati; konzervansi: kalcijev propionat, kalijev sorbat; tvar za tretiranje brašna: L-cistein. Čuvati na suhom mjestu.",
	ingredients_text_hu =>
		"69% búzaliszt, ivóvíz, repceolaj, stabilizátor: glicerin; búzaglutén, savanyúságot szabályozó anyag: almasav; étkezési só, emulgeálószer: zsírsavak mono - és digliceridjei; dextróz, térfogatnövelő szer: nátrium-karbonátok; tartósítószerek: kalcium-propionát, kálium-szorbát; lisztkezelő szer: L-Cisztein.",
	ingredients_text_sk =>
		"some unknown words for ingredient: 69% pšeničná múka, pitná voda, repkový olej, stabilizátor: glycerol; pšeničný glutén, regulátor kyslosti: kyselina jablčná; jedlá soľ, emulgátor: mono - a diglyceridy mastných kyselín; dextróza, kypriaca látka: uhličitany sodné; konzervačné látky: propionan vápenatý, sorban draselný; múku upravujúca látka: L-cystein.",
};
check_ingredients_between_languages($product_ref);
ok(
	has_tag($product_ref, "taxonomies_enhancer", "possible-stop-word-before-sk-some-unknown-words-for-ingredient"),
	'sk has one stop word before and it is not influenced by having 2 languages without stopwords'
) or diag Dumper $product_ref;

$product_ref = {
	ingredients_text_hr =>
		"some unknown words for ingredient in hr: 69% pšenično brašno, voda, repičino ulje, stabilizator. glicerol; pšenični gluten, regulator kiselosti: jabučna kiselina; kuhinjska sol, emulgator: mono - i digliceridi masnih kiselina; dekstroza, tvar za rahljenje: natrijevi karbonati; konzervansi: kalcijev propionat, kalijev sorbat; tvar za tretiranje brašna: L-cistein. Čuvati na suhom mjestu.",
	ingredients_text_hu =>
		"69% búzaliszt, ivóvíz, repceolaj, stabilizátor: glicerin; búzaglutén, savanyúságot szabályozó anyag: almasav; étkezési só, emulgeálószer: zsírsavak mono - és digliceridjei; dextróz, térfogatnövelő szer: nátrium-karbonátok; tartósítószerek: kalcium-propionát, kálium-szorbát; lisztkezelő szer: L-Cisztein.",
	ingredients_text_sk =>
		"product name or something. some unknown words for ingredient: 69% pšeničná múka, pitná voda, repkový olej, stabilizátor: glycerol; pšeničný glutén, regulátor kyslosti: kyselina jablčná; jedlá soľ, emulgátor: mono - a diglyceridy mastných kyselín; dextróza, kypriaca látka: uhličitany sodné; konzervačné látky: propionan vápenatý, sorban draselný; múku upravujúca látka: L-cystein.",
};
check_ingredients_between_languages($product_ref);
ok(
	has_tag(
		$product_ref, "taxonomies_enhancer", "possible-stop-word-before-hr-some-unknown-words-for-ingredient-in-hr"
	),
	'hr has one stop word before and it is not influenced by other lang having a stop word before and a word before that stop word'
) or diag Dumper $product_ref;
ok(
	has_tag($product_ref, "taxonomies_enhancer", "possible-stop-word-before-sk-some-unknown-words-for-ingredient"),
	'sk has one stop word before and only one and it is not influenced by other lang having a stop word before'
) or diag Dumper $product_ref;

$product_ref = {
	ingredients_text_hr =>
		"some unknown words for ingredient in hr: 69% pšenično brašno, voda, repičino ulje, stabilizator. glicerol; pšenični gluten, regulator kiselosti: jabučna kiselina; kuhinjska sol, emulgator: mono - i digliceridi masnih kiselina; dekstroza, tvar za rahljenje: natrijevi karbonati; konzervansi: kalcijev propionat, kalijev sorbat; tvar za tretiranje brašna: L-cistein. Čuvati na suhom mjestu.",
	ingredients_text_hu =>
		"69% not-in-taxonomy, ivóvíz, repceolaj, stabilizátor: glicerin; búzaglutén, savanyúságot szabályozó anyag: almasav; étkezési só, emulgeálószer: zsírsavak mono - és digliceridjei; dextróz, térfogatnövelő szer: nátrium-karbonátok; tartósítószerek: kalcium-propionát, kálium-szorbát; lisztkezelő szer: L-Cisztein.",
};
check_ingredients_between_languages($product_ref);
ok(
	!exists $product_ref->{"taxonomies_enhancer_tags"},
	'stopword before but first ingredients is unknown in the reference language, hence it should be ignored + stopword after is not detected because ingredients taken in the order cannot be paired due to the additional stop word before'
) or diag Dumper $product_ref;

# TESTS STOP WORDS AFTER INGREDIENTS LIST
$product_ref = {
	ingredients_text_hu =>
		"69% búzaliszt, ivóvíz, repceolaj, stabilizátor: glicerin; búzaglutén, savanyúságot szabályozó anyag: almasav; étkezési só, zsírsavak mono - és digliceridjei; dextróz, térfogatnövelő szer: nátrium-karbonátok; tartósítószerek: kalcium-propionát, kálium-szorbát; lisztkezelő szer: L-Cisztein.",
	ingredients_text_pl =>
		"69% mąka pszenna, woda, olej rzepakowy, stabilizator: glicerol; gluten pszenny, regulator kwasowości: kwas jabłkowy; sól, mono - i diglicerydy kwasów tłuszczowych; glukoza, substancja spulchniająca: węglany sodu; substancje konserwujące: propionian wapnia, sorbinian potasu ; środek do przetwarzania mąki: L-cysteina.",
};
check_ingredients_between_languages($product_ref);
ok(!exists $product_ref->{"taxonomies_enhancer_tags"}, 'same list length, no missing stop words')
	or diag Dumper $product_ref;

$product_ref = {
	ingredients_text_hr =>
		"69% pšenično brašno, voda, repičino ulje, stabilizator. glicerol; pšenični gluten, regulator kiselosti: jabučna kiselina; kuhinjska sol, emulgator: mono - i digliceridi masnih kiselina; dekstroza, tvar za rahljenje: natrijevi karbonati; konzervansi: kalcijev propionat, kalijev sorbat; tvar za tretiranje brašna: L-cistein. Čuvati na suhom mjestu.",
	ingredients_text_hu =>
		"69% búzaliszt, ivóvíz, repceolaj, stabilizátor: glicerin; búzaglutén, savanyúságot szabályozó anyag: almasav; étkezési só, emulgeálószer: zsírsavak mono - és digliceridjei; dextróz, térfogatnövelő szer: nátrium-karbonátok; tartósítószerek: kalcium-propionát, kálium-szorbát; lisztkezelő szer: L-Cisztein.",
};
check_ingredients_between_languages($product_ref);
ok(has_tag($product_ref, "taxonomies_enhancer", "possible-stop-word-after-hr-čuvati-na-suhom-mjestu"),
	'hr has one stop word')
	or diag Dumper $product_ref;

$product_ref = {
	ingredients_text_hr =>
		"ingredient-in-hr: 69% pšenično brašno, voda, repičino ulje, stabilizator. glicerol; pšenični gluten, regulator kiselosti: jabučna kiselina; kuhinjska sol, emulgator: mono - i digliceridi masnih kiselina; dekstroza, tvar za rahljenje: natrijevi karbonati; konzervansi: kalcijev propionat, kalijev sorbat; tvar za tretiranje brašna: L-cistein. Čuvati na suhom mjestu.",
	ingredients_text_hu =>
		"69% búzaliszt, ivóvíz, repceolaj, stabilizátor: glicerin; búzaglutén, savanyúságot szabályozó anyag: almasav; étkezési só, emulgeálószer: zsírsavak mono - és digliceridjei; dextróz, térfogatnövelő szer: nátrium-karbonátok; tartósítószerek: kalcium-propionát, kálium-szorbát; lisztkezelő szer: L-Cisztein.",
};
check_ingredients_between_languages($product_ref);
ok(
	has_tag($product_ref, "taxonomies_enhancer", "possible-stop-word-before-hr-ingredient-in-hr"),
	'if 1 stop word before and 1 stop word after, then only stop word before should be seen'
) or diag Dumper $product_ref;

$product_ref = {
	ingredients_text_cs =>
		"69% pšeničná mouka, pitná voda, řepkový olej, stabilizátor: glycerol; pšeničný lepek, regulátor kyselosti: kyselina jablečná; jedlá sůl, emulgátor: mono - a diglyceridy mastných kyselin; dextróza, kypřící látka: uhličitany sodné; konzervanty: propionan vápenatý, sorban draselný; látka zlepšující mouku: L-cystein. Skladujte v suchu a chraňte před teplem.",
	ingredients_text_hr =>
		"69% pšenično brašno, voda, repičino ulje, stabilizator. glicerol; pšenični gluten, regulator kiselosti: jabučna kiselina; kuhinjska sol, emulgator: mono - i digliceridi masnih kiselina; dekstroza, tvar za rahljenje: natrijevi karbonati; konzervansi: kalcijev propionat, kalijev sorbat; tvar za tretiranje brašna: L-cistein. Čuvati na suhom mjestu.",
	ingredients_text_hu =>
		"69% búzaliszt, ivóvíz, repceolaj, stabilizátor: glicerin; búzaglutén, savanyúságot szabályozó anyag: almasav; étkezési só, emulgeálószer: zsírsavak mono - és digliceridjei; dextróz, térfogatnövelő szer: nátrium-karbonátok; tartósítószerek: kalcium-propionát, kálium-szorbát; lisztkezelő szer: L-Cisztein.",
	ingredients_text_pl =>
		"69% mąka pszenna, woda, olej rzepakowy, stabilizator: glicerol; gluten pszenny, regulator kwasowości: kwas jabłkowy; sól, emuglator: mono - i diglicerydy kwasów tłuszczowych; glukoza, substancja spulchniająca: węglany sodu; substancje konserwujące: propionian wapnia, sorbinian potasu ; środek do przetwarzania mąki: L-cysteina.",
	ingredients_text_ro =>
		"69% făină de grâu, apă, ulei de rapiță, stabilizator: glicerol; gluten din grâu, corector de aciditate: acid malic; sare, emulsifiant: mono - şi digliceride ale acizilor graşi; dextroză, agent de afanare: carbonați de sodiu ; conservanți: propionat de calciu, sorbat de potasiu; agent de tratare a făinii: L-cisteină.",
	ingredients_text_sk =>
		"69% pšeničná múka, pitná voda, repkový olej, stabilizátor: glycerol; pšeničný glutén, regulátor kyslosti: kyselina jablčná; jedlá soľ, emulgátor: mono - a diglyceridy mastných kyselín; dextróza, kypriaca látka: uhličitany sodné; konzervačné látky: propionan vápenatý, sorban draselný; múku upravujúca látka: L-cystein.",
};
check_ingredients_between_languages($product_ref);
ok(
	has_tag($product_ref, "taxonomies_enhancer", "possible-stop-word-after-cs-skladujte-v-suchu-a-chraňte-před-teplem"),
	'cs has one stop word'
) or diag Dumper $product_ref;
ok(has_tag($product_ref, "taxonomies_enhancer", "possible-stop-word-after-hr-čuvati-na-suhom-mjestu"),
	'hr has one stop word as well')
	or diag Dumper $product_ref;

$product_ref = {
	ingredients_text_sk =>
		"69% pšeničná múka, pitná voda, repkový olej, stabilizátor: glycerol; pšeničný glutén, regulátor kyslosti: kyselina jablčná; jedlá soľ, emulgátor: mono - a diglyceridy mastných kyselín; dextróza, kypriaca látka: uhličitany sodné; konzervačné látky: propionan vápenatý, sorban draselný; múku upravujúca látka: L-cystein.",
	ingredients_text_sl =>
		"69% pšenična moka, voda, olje oljne ogrščice, stabilizator: glicerol; pšenični gluten, sredstvo za uravnavanje kislosti: jabolčna kislina ; nejodirana sol, emulgator: mono - in diglicerid! maščobnih kislin; dekstroza, sredstvo za vzhajanje: natrijevi karbonati; konzervansa: kalcijev propionat , kalijev sorbat; sredstvo za obdelavo moke: L-cistein. Uporabno najmanj do: glej odtis na zadnji strani embalaže.",
};
check_ingredients_between_languages($product_ref);
ok(has_tag($product_ref, "taxonomies_enhancer", "possible-stop-word-after-sl-uporabno-najmanj-do"),
	'sl has one stop word')
	or diag Dumper $product_ref;
ok(!has_tag($product_ref, "taxonomies_enhancer", "possible-stop-word-after-sl-glej-odtis-na-zadnji-strani-embalaže"),
	'sl has only one stop word, second word is not reported')
	or diag Dumper $product_ref;

$product_ref = {
	ingredients_text_sk =>
		"69% pšeničná múka, pitná voda, repkový olej, stabilizátor: glycerol; pšeničný glutén, regulátor kyslosti: kyselina jablčná; jedlá soľ, emulgátor: mono - a diglyceridy mastných kyselín; dextróza, kypriaca látka: uhličitany sodné; konzervačné látky: propionan vápenatý, sorban draselný; múku upravujúca látka: L-cystein.",
	ingredients_text_hr =>
		"69% pšenično brašno, voda, repičino ulje, stabilizator. glicerol; pšenični gluten, regulator kiselosti: jabučna kiselina; kuhinjska sol, emulgator: mono - i digliceridi masnih kiselina; dekstroza, tvar za rahljenje: natrijevi karbonati; konzervansi: kalcijev propionat, kalijev sorbat; tvar za tretiranje brašna: L-cistein. Čuvati na suhom mjestu.",
	ingredients_text_sl =>
		"69% pšenična moka, voda, olje oljne ogrščice, stabilizator: glicerol; pšenični gluten, sredstvo za uravnavanje kislosti: jabolčna kislina ; nejodirana sol, emulgator: mono - in diglicerid! maščobnih kislin; dekstroza, sredstvo za vzhajanje: natrijevi karbonati; konzervansa: kalcijev propionat , kalijev sorbat; sredstvo za obdelavo moke: L-cistein. Uporabno najmanj do: glej odtis na zadnji strani embalaže.",
};
check_ingredients_between_languages($product_ref);
ok(has_tag($product_ref, "taxonomies_enhancer", "possible-stop-word-after-hr-čuvati-na-suhom-mjestu"),
	'hr is one of the 2 stop words with sl')
	or diag Dumper $product_ref;
ok(has_tag($product_ref, "taxonomies_enhancer", "possible-stop-word-after-sl-uporabno-najmanj-do"),
	'sl is one of the 2 stop words with hr')
	or diag Dumper $product_ref;
ok(!has_tag($product_ref, "taxonomies_enhancer", "possible-stop-word-after-sl-glej-odtis-na-zadnji-strani-embalaže"),
	'sl has only one stop word with hr, second word for sl is not reported')
	or diag Dumper $product_ref;

# TEST UNKNOWN INGREDIENTS
$product_ref = {
	ingredients_text_hr => "Secer.",
	ingredients_text_en => "Sugar",
};
check_ingredients_between_languages($product_ref);
ok(
	has_tag($product_ref, "taxonomies_enhancer", "ingredients-hr-secer-is-possible-typo-for-hr-šećer"),
	'typo should be fetched if both language are having single word although percentage of unknown ingredients is below the threshold'
) or diag Dumper $product_ref;

$product_ref = {
	ingredients_text_hr => "Sol, secer, jagoda.",
	ingredients_text_en => "Salt, sugar, strawberry.",
};
check_ingredients_between_languages($product_ref);
ok(has_tag($product_ref, "taxonomies_enhancer", "ingredients-hr-secer-is-possible-typo-for-hr-šećer"),
	'typo should be fetched')
	or diag Dumper $product_ref;

$product_ref = {
	ingredients_text_hr => "Sol, jaggery, jagoda.",
	ingredients_text_en => "Salt, jaggery, strawberry.",
};
check_ingredients_between_languages($product_ref);
ok(has_tag($product_ref, "taxonomies_enhancer", "ingredients-hr-jaggery-is-new-translation-for-en-jaggery"),
	'suggest Croatian translation for existing ingredient in English')
	or diag Dumper $product_ref;

$product_ref = {
	ingredients_text_en => "Salt, sugar, strawberry.",
	ingredients_text_hr => "Sol, secer, jagoda.",
	ingredients_text_pl => "sól, cukier, truskawka.",
};
check_ingredients_between_languages($product_ref);
ok(has_tag($product_ref, "taxonomies_enhancer", "ingredients-hr-secer-is-possible-typo-for-hr-šećer"),
	'typo should be fetched')
	or diag Dumper $product_ref;

$product_ref = {
	ingredients_text_en => "Salt, invert sugar solution, strawberry.",
	ingredients_text_hr => "Sol, newword, jagoda.",
	ingredients_text_pl => "sól, roztwór cukru inwertowanego, truskawka.",
};
check_ingredients_between_languages($product_ref);
ok(
	has_tag(
		$product_ref, "taxonomies_enhancer",
		"ingredients-hr-newword-is-new-translation-for-en-invert-sugar-solution"
	),
	'new translation for invert sugar solution in hr but known in 2 differents lang'
) or diag Dumper $product_ref;

$product_ref = {
	ingredients_text_en => "Salt, invert sugar solution, strawberry.",
	ingredients_text_hr => "Sol, mrkva, jagoda.",
};
check_ingredients_between_languages($product_ref);
ok(
	has_tag(
		$product_ref,
		"taxonomies_enhancer",
		"ingredients-taxonomy-between-invert-sugar-solution-id-en-invert-sugar-solution-and-mrkva-id-en-carrot-should-be-same-id"
	),
	'different ids between lang hr and en leading to taxonomy mismatch warning'
) or diag Dumper $product_ref;
$product_ref = {
	ingredients_text_en => "Salt, invert sugar solution, strawberry.",
	ingredients_text_hr => "Sol, mrkva, jagoda.",
	ingredients_text_pl => "sól, roztwór cukru inwertowanego, truskawka.",
};
check_ingredients_between_languages($product_ref);
ok(
	!exists $product_ref->{"taxonomies_enhancer_tags"},
	'more than 1 taxonomy mismatch found does not raise anything to prevent false positive for example ingredient list has been updated'
) or diag Dumper $product_ref;

$product_ref = {
	ingredients_text_fi =>
		"Sianliha, suola, maussteet, sokeri, dekstroosi, säilöntäaineet: E250, E252; kuusen savu. Pakattu suojakaasuun. Suolapitoisuus: 5,0%, voimakassuolainen. 100g: aan tuotetta käytetty 128g lihaa.",
	ingredients_text_sv =>
		"Svinkött, salt, kryddor, socker, dextros, konserveringsmedel: E250, E252; granrök. Förpackat i en skyddande atmosfär. Salthalt: 5,0%, kraftigt saltat. Till 100g vara har används 128g kött.",
};
check_ingredients_between_languages($product_ref);
ok(!exists $product_ref->{"taxonomies_enhancer_tags"}, 'fi-sv, last word of ingredient1 should be known to push tag')
	or diag Dumper $product_ref;

$product_ref = {
	ingredients_text_fi => "Sianliha",
	ingredients_text_sv => "Svinkött",
	taxonomies_enhancer_tags => ["no-matter-what"]
};
check_ingredients_between_languages($product_ref);
ok(!exists $product_ref->{"taxonomies_enhancer_tags"}, 'fi-sv, nothing to do, make sure that tags field is removed')
	or diag Dumper $product_ref;

$product_ref = {
	ingredients_text_de =>
		"Tomatenfruchtfleisch 40,9%, Wasser, Tomatenmarkkonzentrat 14%, Zwiebeln 12,5%, Sonnenblumenöl, Karotten 3,5%, Salz, natürliche Aromen, Zucker, Basilikum 0,2%, Knoblauch",
	ingredients_text_en =>
		"tomato pulp, onions, somenflower oil, carrots 3,5%, salt, natural flavors, sugar, bailic 0,2%, garlic,",
	ingredients_text_fr =>
		"Pulpe de tomate 40,9 %, eau, concentré de concentré de tomate 14 %, oignons, huile de tournesol, carottes 3,5 %, sel, arômes naturels, sucre, basilic 0, 2%, ail.",
	ingredients_text_ro => "",
};
check_ingredients_between_languages($product_ref);
ok(has_tag($product_ref, "taxonomies_enhancer", "ingredients-fr-basilic-0-is-possible-typo-for-fr-basilic"),
	'parsing promblem due to OCR resulting in space after comma')
	or diag Dumper $product_ref;

$product_ref = {
	ingredients_text_bg => "Пастьоризирано МЛЯКО, со…ктериални култури, мая.",
	ingredients_text_en =>
		"EN WYDOJONE Lactose free* UHT Milk. The fat content of 3,2%. Source of calcium. *The lactose content &lt; 0,01 g / 100 ml Milk is a valued element of a diet. Contains many necessary ingredients to maintain healthy body like protein and calcium. However, not everyone can consume milk or dairy products because of lactose intolerance naturally occurring sugar in its composition. Lactose intolerance is the inability to digest lactose. The alternative is a lactose free Milk.",
	ingredients_text_pl => "Mleko bez laktozy UHT. Zawartość tłuszczu 3,2%. Źródło wapnia.",
};
check_ingredients_between_languages($product_ref);
ok(
	!exists $product_ref->{"taxonomies_enhancer_tags"},
	'nothing is detected. PL: single unknown ingredient BG: couple of ingredient, 1 unrecognized EN: whole product text'
) or diag Dumper $product_ref;

$product_ref = {
	ingredients_text_da =>
		"_skummetmælk_, sukker, kakaosmør, vand, kakaomasse, kokosolie, glukosesirup, glukose-fruktosesirup, _sødmælkspulver_, vallepulver (_mælk_), _mælkefedt_, emulgatorer (E471, _sojalecithin_, E476), vaniljestang, stabilisatorer (E410, E412, E407), naturlig vaniljearoma (_mælk_), aroma, farvestof (E160a)",
	ingredients_text_de =>
		"entrahmte _Milch_, Zucker, Kakaobutter, Wasser, Kakaomasse, Kokosfett, Glukosesirup, Glukose-Fruktose-Sirup , _Vollmilchpulver_, _Molkenerzeugnis_, _Butterreinfett_, Emulgatoren (E471, Lecithine (_Soja_), E476), vermahlene Vanilleschoten, Stabilisatoren (E410, E412, E407), natürliches Vanillearoma (mit _Milch_), Aroma, Farbstoff (E160a)",
	ingredients_text_en =>
		"reconstituted skimmed  milk , sugar, cocoa butter', water, coconut oil, cocoa mass', glucose syrup, glucose-fructose syrup, whole  milk  powder, whey solids ( milk ), butter oil ( milk ), emulsifiers (soybean lecithin, e476, e471), exhausted vanilla bean pieces, stabilisers (e407, e410, e412), natural vanilla flavouring', (with milk), flavouring, colour (e160a)",
	ingredients_text_fr =>
		"LAIT écrémé réhydraté, sucre, beurre de cacao¹, eau, huile de coco, pâte de cacao¹, sirop de glucose, sirop de glucose-fructose, LAIT en poudre entier, LACTOSE et protéines de LAIT, BEURRE concentré, émulsifiants (lécithine de SOJA, E476, E471), gousses de vanille épuisées broyées, stabilisants (E407, E410, E412), arôme naturel de vanille¹ (dont LAIT), arôme, colorant (E160a). Peut contenir: amande. Sans gluten.",
	ingredients_text_hu =>
		"visszaállított sovány _tej_, cukor, kakaóvaj, víz, kakaómassza, kókuszolaj, glükózsirup, glükóz-fruktózszőrp, zsiros _tejpor_, _tejsavókészítmény_, _vajolaj_, emulgeálószerek (E471, _szójalecitin_, E476), vanílla darabkák, stabilizátorok (E410, E412, E407), természetes vanília aroma (_tejszármazékkal_), aromák, szinezék (E160a)",
	ingredients_text_it =>
		"_latte_ scremato reidratato, zucchero, burro di cacao, acqua, pasta di cacao, olio di cocco, sciroppo di glucosio, sciroppo di glucosio-fruttosio, _latte_ intero in polvere, _lattosio_ e proteine del _latte_, _burro_ concentrato, emulsionanti (E471, lecitina di _soia_, E476), baccelli di vaniglia, addensanti (E410, E412, E407), aroma naturale di vaniglia (contiene _latte_), aromi, coloranti (E160a)",
	ingredients_text_nl =>
		"gerehydrateerde magere _melk_, suiker, cacaoboter, water, cacaomassa, kokosolie, glucosestroop, glucose-fructosestroop, volle _melkpoeder_, _lactose_, _melkeiwitten_, _boterconcentraat_, emulgatoren (E471, _sojalecithine_, E476), uitgepuue gemalen vanillestokjes, stabilisatoren (E410, E412, E407), natuurlijk vanillearoma (met _melk_), aroma, kleurstof (E160a)",
	ingredients_text_sv =>
		"_skummjölk_, socker, kakaosmör, vatten, kakaomassa, kokosolja, glukossirap, glukos-fruktossirap, _helmjölkspulver_, vasslepulver (_mjölk_), _mjölkfett_, emulgeringsmedel (E471, _sojalecitin_, E476), vaniljstångbitar, stabiliseringsmedel (E410, E412, E407), naturlig vaniljarom (_mjölk_), arom, färgämne (E160a)",
};
check_ingredients_between_languages($product_ref);
ok(
	has_tag(
		$product_ref, "taxonomies_enhancer",
		"ingredients-hu-vanilla-darabkak-is-new-translation-for-en-exhausted-vanilla-pod"
	),
	'hu new translation'
) or diag Dumper $product_ref;
ok(has_tag($product_ref, "taxonomies_enhancer", "ingredients-hu-szinezek-is-possible-typo-for-hu-szinezek"),
	'hu 1/2 typo')
	or diag Dumper $product_ref;
ok(has_tag($product_ref, "taxonomies_enhancer", "ingredients-hu-glukozsirup-is-possible-typo-for-hu-glukozszirup"),
	'hu 2/2 typo')
	or diag Dumper $product_ref;

$product_ref = {
	ingredients_text_en => "spice extracts (including _celeriac_)",
	ingredients_text_pl => "ekstrakty przypraw (w tym _seler_)",
};
check_ingredients_between_languages($product_ref);
ok(
	has_tag(
		$product_ref,
		"taxonomies_enhancer",
		"ingredients-taxonomy-between-including-celeriac-id-en-celeriac-and-w-tym-seler-id-en-celery-should-be-same-id"
	),
	'en-pl, remove underscores'
) or diag Dumper $product_ref;

# TESTS RELATED TO EXISTING PRODUCTS
# example based on 0036595328366
$product_ref = {
	ingredients_text_cs =>
		"69% pšeničná mouka, pitná voda, řepkový olej, stabilizátor: glycerol; pšeničný lepek, regulátor kyselosti: kyselina jablečná; jedlá sůl, emulgátor: mono - a diglyceridy mastných kyselin; dextróza, kypřící látka: uhličitany sodné; konzervanty: propionan vápenatý, sorban draselný; látka zlepšující mouku: L-cystein. Skladujte v suchu a chraňte před teplem.",
	ingredients_text_hr =>
		"69% pšenično brašno, voda, repičino ulje, stabilizator. glicerol; pšenični gluten, regulator kiselosti: jabučna kiselina; kuhinjska sol, emulgator: mono - i digliceridi masnih kiselina; dekstroza, tvar za rahljenje: natrijevi karbonati; konzervansi: kalcijev propionat, kalijev sorbat; tvar za tretiranje brašna: L-cistein. Čuvati na suhom mjestu.",
	ingredients_text_hu =>
		"69% búzaliszt, ivóvíz, repceolaj, stabilizátor: glicerin; búzaglutén, savanyúságot szabályozó anyag: almasav; étkezési só, emulgeálószer: zsírsavak mono - és digliceridjei; dextróz, térfogatnövelő szer: nátrium-karbonátok; tartósítószerek: kalcium-propionát, kálium-szorbát; lisztkezelő szer: L-Cisztein.",
	ingredients_text_pl =>
		"69% mąka pszenna, woda, olej rzepakowy, stabilizator: glicerol; gluten pszenny, regulator kwasowości: kwas jabłkowy; sól, emuglator: mono - i diglicerydy kwasów tłuszczowych; glukoza, substancja spulchniająca: węglany sodu; substancje konserwujące: propionian wapnia, sorbinian potasu ; środek do przetwarzania mąki: L-cysteina.",
	ingredients_text_ro =>
		"69% făină de grâu, apă, ulei de rapiță, stabilizator: glicerol; gluten din grâu, corector de aciditate: acid malic; sare, emulsifiant: mono - ti digliceride ale acizilor graşi; dextroză, agent de afanare: carbonați de sodiu ; conservanți: propionat de calciu, sorbat de potasiu; agent de tratare a făinii: L-cisteină.",
	ingredients_text_sk =>
		"69% pšeničná múka, pitná voda, repkový olej, stabilizátor: glycerol; pšeničný glutén, regulátor kyslosti: kyselina jablčná; jedlá soľ, emulgátor: mono - a diglyceridy mastných kyselín; dextróza, kypriaca látka: uhličitany sodné; konzervačné látky: propionan vápenatý, sorban draselný; múku upravujúca látka: L-cystein.",
	ingredients_text_sl =>
		"69% pšenična moka, voda, olje oljne ogrščice, stabilizator: glicerol; pšenični gluten, sredstvo za uravnavanje kislosti: jabolčna kislina ; nejodirana sol, emulgator: mono - in diglicerid! maščobnih kislin; dekstroza, sredstvo za vzhajanje: natrijevi karbonati; konzervansa: kalcijev propionat , kalijev sorbat; sredstvo za obdelavo moke: L-cistein. Uporabno najmanj do: glej odtis na zadnji strani embalaže.",
};
check_ingredients_between_languages($product_ref);
ok(
	has_tag($product_ref, "taxonomies_enhancer", "possible-stop-word-after-cs-skladujte-v-suchu-a-chraňte-před-teplem"),
	'cs-hr-hu-pl-ro-sk-sl, cs stopword'
) or diag Dumper $product_ref;
ok(has_tag($product_ref, "taxonomies_enhancer", "possible-stop-word-after-sl-uporabno-najmanj-do"),
	'cs-hr-hu-pl-ro-sk-sl, sl stopword')
	or diag Dumper $product_ref;
ok(has_tag($product_ref, "taxonomies_enhancer", "possible-stop-word-after-hr-čuvati-na-suhom-mjestu"),
	'cs-hr-hu-pl-ro-sk-sl, hr stopword')
	or diag Dumper $product_ref;
ok(
	has_tag(
		$product_ref, "taxonomies_enhancer", "ingredients-sk-pšeničny-gluten-is-new-translation-for-en-wheat-gluten"
	),
	'cs-hr-hu-pl-ro-sk-sl, sk new translation'
) or diag Dumper $product_ref;
ok(
	has_tag(
		$product_ref, "taxonomies_enhancer",
		"ingredients-ro-carbonați-de-sodiu-is-possible-typo-for-ro-carbonati-de-sodiu"
	),
	'cs-hr-hu-pl-ro-sk-sl, ro typo in taxonomy'
) or diag Dumper $product_ref;
ok(has_tag($product_ref, "taxonomies_enhancer", "ingredients-pl-emuglator-is-possible-typo-for-pl-emulgator"),
	'cs-hr-hu-pl-ro-sk-sl, pl typo')
	or diag Dumper $product_ref;
ok(has_tag($product_ref, "taxonomies_enhancer", "ingredients-cs-konzervanty-is-possible-typo-for-cs-konzervant"),
	'cs-hr-hu-pl-ro-sk-sl, cs is missing a synonym or handle plural in product opener')
	or diag Dumper $product_ref;
ok(
	has_tag($product_ref, "taxonomies_enhancer", "ingredients-cs-kypřici-latka-is-possible-typo-for-cs-kypřici-latka"),
	'cs-hr-hu-pl-ro-sk-sl, cs missing declension'
) or diag Dumper $product_ref;
ok(
	has_tag(
		$product_ref, "taxonomies_enhancer",
		"ingredients-sk-konzervačne-latky-is-possible-typo-for-sk-konzervačna-latka"
	),
	'cs-hr-hu-pl-ro-sk-sl, sk missing declension'
) or diag Dumper $product_ref;
ok(
	has_tag(
		$product_ref,
		"taxonomies_enhancer",
		"ingredients-ro-monoti-digliceride-ale-acizilor-graşi-is-possible-typo-for-ro-mono-și-digliceride-ale-acizilor-grași"
	),
	'cs-hr-hu-pl-ro-sk-sl, ro typo or synonym'
) or diag Dumper $product_ref;
ok(
	has_tag(
		$product_ref, "taxonomies_enhancer",
		"ingredients-ro-agent-de-afanare-is-possible-typo-for-ro-agent-de-afanare"
	),
	'cs-hr-hu-pl-ro-sk-sl, ro typo or synonym again'
) or diag Dumper $product_ref;

# example based on 20201845
#   problem with english: some app translated in english from other languages. NOT producer translation.
#    for example: App translation (infood) probably based on RO:
#     ingredients_text_en => "water, wine vinegar, mustard seeds, [mustard husks], table salt, [acidifying]: citric acid, [natural flavors of cloves], cinnamon, ginger and tarragon, antioxidant: potassium metabisulphite, spice mixture",
#    versus Producer translation:
#     ingredients_text_en => "water, spirit vinegar, mustard seeds, husks of mustard seeds, salt, acidity regulator: citric acid, natural flavorings, antioxidant: potassium metabisulphite, turmeric",
#   in square brackets are unknown ingredients on the product
#   ingredients_text_es => "Agua, vinagre de alcohol, 24,5% semillas de mostaza, [cáscara de semillas de mostaza], sal          , acidulante: [ácido citico]   ; aromas                                                      , antioxidante: metabisulfito potásico ; especia.",
#   ingredients_text_hr => "Voda, alkoholni ocat   , 24,5% sjemenke gorušice   , [7,5% ljuske gorušice]          , kuhinjska sol, kiselina  : limunska kiselina; arome                                                       , antioksidans: kalijev metabisulfit   ; začin.",
#   ingredients_text_ro => "apă , oțet din vin     , [semințe de muştar]       , [coji de muştar]                , sare de masă , acidifiant: acid citric      , [arome naturale de cuişoare], scorțișoară, ghimbir și tarhon, antioxidant : metabisulfit de potasiu, amestec de condimente.",
#    RO has more ingredients
#    ES has a typo ácido citico -> Ácido cítrico
$product_ref = {
	ingredients_text_es =>
		"Agua, vinagre de alcohol, 24,5% semillas de mostaza, cáscara de semillas de mostaza, sal, acidulante: ácido citico; aromas, antioxidante: metabisulfito potásico; especia.",
	ingredients_text_hr =>
		"Voda, alkoholni ocat, 24,5% sjemenke gorušice, 7,5% ljuske gorušice, kuhinjska sol, kiselina: limunska kiselina; arome, antioksidans: kalijev metabisulfit; začin.",
	ingredients_text_ro =>
		"apă, oțet din vin, semințe de muştar, coji de muştar, sare de masă, acidifiant: acid citric, arome naturale de cuişoare, scorțișoară, ghimbir și tarhon, antioxidant: metabisulfit de potasiu, amestec de condimente.",
};
check_ingredients_between_languages($product_ref);
ok(has_tag($product_ref, "taxonomies_enhancer", "ingredients-es-acido-citico-is-possible-typo-for-es-acido-citrico"),
	'es-hr-ro, typo in es')
	or diag Dumper $product_ref;

# example based on 8000430133035
#   different lists, in this example fr is missing "presure" but there exists picture with fr ingredients list having "presure"
#   en:pasteurised-cow-s-milk and en:pasteurised-milk might be used indifferently in current taxonomy
#   my $product_ref = {
#       ingredients_text_cs => "",
#       ingredients_text_da => "Pasteuriseret _komælk_ , salt , microbiel løbe        , surhedsregulerende middel: citronsyre.",
#       ingredients_text_de => "Pasteurisierte _Milch_ , Salz , Lab                   , Säuerungsmittel          : Citronensäure.",
#       ingredients_text_en => "Pasteurised _milk_     , salt , vegetarian coagulant  , acidity regulator        : citric acid.",
#       ingredients_text_es => "_Leche_                , sal  , coagulante microbiano y corrector de acidez (ácido cítrico).",
#       ingredients_text_fi => "Pastöroitu _maito_     , suola, juoksute              , happamuudensäätöaine: sitruunahappo.",
#       ingredients_text_fr => "_Lait_ pasteurisé      , sel  , correcteur d'acidité acide citrique.",
#       ingredients_text_it => "",
#       ingredients_text_nl => "Gepasteuriseerde _melk_, zout , stremsel              , zuurtegraadregelaar citroenzuur.",
#       ingredients_text_pt => "_Leite_                , sal  , coalho                , regulador de acidez     : ácido cítrico.",
#       ingredients_text_ru => "Нормализованнов молоко , регулятор кислотности лимонная кислота, с использованием молокосвертывающего ферментного препарата микробного происхождения, рассол (вода питьевая, пищевая соль).",
#       ingredients_text_sv => "Pastöriserad _komjölk_ , salt , löpe                  , surhetsreglerande medel  : citronsyra.",
#   };
$product_ref = {
	ingredients_text_cs => "",
	ingredients_text_da => "Pasteuriseret _komælk_, salt, new-word, surhedsregulerende middel: citronsyre.",
	ingredients_text_de => "Pasteurisierte _Milch_, Salz, Lab, Säuerungsmittel: Citronensäure.",
	ingredients_text_en => "Pasteurised _milk_, salt, vegetarian coagulant, acidity regulator: citric acid.",
	ingredients_text_es => "_Leche_, sal, coagulante microbiano y corrector de acidez (ácido cítrico).",
	ingredients_text_fi => "Pastöroitu _maito_, suola, juoksute, happamuudensäätöaine: sitruunahappo.",
	ingredients_text_fr => "_Lait_ pasteurisé, sel, correcteur d'acidité acide citrique.",
	ingredients_text_it => "",
	ingredients_text_nl => "Gepasteuriseerde _melk_, zout, stremsel, zuurtegraadregelaar citroenzuur.",
	ingredients_text_pt => "_Leite_, sal, coalho, regulador de acidez: ácido cítrico.",
	ingredients_text_ru =>
		"Нормализованнов молоко, регулятор кислотности лимонная кислота, с использованием молокосвертывающего ферментного препарата микробного происхождения, рассол (вода питьевая, пищевая соль).",
	ingredients_text_sv => "Pastöriserad _komjölk_, salt, löpe, surhetsreglerande medel: citronsyra.",
};
check_ingredients_between_languages($product_ref);
ok(
	has_tag(
		$product_ref, "taxonomies_enhancer",
		"ingredients-da-pasteuriseret-komaelk-is-new-translation-for-en-pasteurised-cow-s-milk"
	),
	'cs-da-de-en-es-fi-fr-it-nl-pt-ru-sv, new word for da based on sv as well as en'
) or diag Dumper $product_ref;
ok(has_tag($product_ref, "taxonomies_enhancer", "ingredients-da-new-word-is-new-translation-for-en-coagulant"),
	'cs-da-de-en-es-fi-fr-it-nl-pt-ru-sv, new word for da based on es as well as en')
	or diag Dumper $product_ref;
ok(
	has_tag(
		$product_ref, "taxonomies_enhancer",
		"ingredients-da-pasteuriseret-komaelk-is-possible-typo-for-da-pasteuriseret-maelk"
	),
	'cs-da-de-en-es-fi-fr-it-nl-pt-ru-sv, typo in da based on fi as well as en'
) or diag Dumper $product_ref;

done_testing();
