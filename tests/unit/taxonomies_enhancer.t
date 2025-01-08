#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test2::V0;
use Log::Any::Adapter 'TAP';

use ProductOpener::TaxonomiesEnhancer qw/detect_taxonomy_translation_from_text/;


# example based on 0036595328366
# should detect stopwords
my $product_ref = {
	ingredients_text_cs => "69% pšeničná mouka , pitná voda, řepkový olej       , stabilizátor: glycerol; pšeničný lepek , regulátor kyselosti             : kyselina jablečná; jedlá sůl     , emulgátor    : mono - a diglyceridy mastných kyselin   ; dextróza , kypřící látka           : uhličitany sodné   ; konzervanty            : propionan vápenatý , sorban draselný  ; látka zlepšující mouku      : L-cystein. Skladujte v suchu a chraňte před teplem.",
	ingredients_text_hr => "69% pšenično brašno, voda      , repičino ulje      , stabilizator. glicerol; pšenični gluten, regulator kiselosti             : jabučna kiselina ; kuhinjska sol , emulgator    : mono - i digliceridi masnih kiselina    ; dekstroza, tvar za rahljenje       : natrijevi karbonati; konzervansi            : kalcijev propionat , kalijev sorbat   ; tvar za tretiranje brašna   : L-cistein. Čuvati na suhom mjestu.",
	ingredients_text_hu => "69% búzaliszt      , ivóvíz    , repceolaj          , stabilizátor: glicerin; búzaglutén     , savanyúságot szabályozó anyag   : almasav          ; étkezési só   , emulgeálószer: zsírsavak mono - és digliceridjei       ; dextróz  , térfogatnövelő szer     : nátrium-karbonátok ; tartósítószerek        : kalcium-propionát  , kálium-szorbát   ; lisztkezelő szer            : L-Cisztein.",
	ingredients_text_pl => "69% mąka pszenna   , woda      , olej rzepakowy     , stabilizator: glicerol; gluten pszenny , regulator kwasowości            : kwas jabłkowy    ; sól           , emuglator    : mono - i diglicerydy kwasów tłuszczowych; glukoza  , substancja spulchniająca: węglany sodu       ; substancje konserwujące: propionian wapnia  , sorbinian potasu ; środek do przetwarzania mąki: L-cysteina.",
	ingredients_text_ro => "69% făină de grâu  , apă       , ulei de rapiță     , stabilizator: glicerol; gluten din grâu, corector de aciditate           : acid malic       ; sare          , emulsifiant  : mono - şi digliceride ale acizilor graşi; dextroză , agent de afanare        : carbonați de sodiu ; conservanți            : propionat de calciu, sorbat de potasiu; agent de tratare a făinii   : L-cisteină.",
	ingredients_text_sk => "69% pšeničná múka  , pitná voda, repkový olej       , stabilizátor: glycerol; pšeničný glutén, regulátor kyslosti              : kyselina jablčná ; jedlá soľ     , emulgátor    : mono - a diglyceridy mastných kyselín   ; dextróza , kypriaca látka          : uhličitany sodné   ; konzervačné látky      : propionan vápenatý , sorban draselný  ; múku upravujúca látka       : L-cystein.",
	ingredients_text_sl => "69% pšenična moka  , voda      , olje oljne ogrščice, stabilizator: glicerol; pšenični gluten, sredstvo za uravnavanje kislosti: jabolčna kislina ; nejodirana sol, emulgator    : mono - in diglicerid! maščobnih kislin  ; dekstroza, sredstvo za vzhajanje   : natrijevi karbonati; konzervansa            : kalcijev propionat , kalijev sorbat   ; sredstvo za obdelavo moke   : L-cistein. Uporabno najmanj do: glej odtis na zadnji strani embalaže.",
};
detect_taxonomy_translation_from_text($product_ref);

# example based on 20201845
# should suggests translations
# problem with english: some app translated in english from other languages. NOT producer translation.
#  for example: App translation (infood) probably based on RO:
#   ingredients_text_en => "water, wine vinegar, mustard seeds, [mustard husks], table salt, [acidifying]: citric acid, [natural flavors of cloves], cinnamon, ginger and tarragon, antioxidant: potassium metabisulphite, spice mixture",
#  versus Producer translation:
#   ingredients_text_en => "water, spirit vinegar, mustard seeds, husks of mustard seeds, salt, acidity regulator: citric acid, natural flavorings, antioxidant: potassium metabisulphite, turmeric",
# in square brackets are unknown ingredients on the product
# ingredients_text_es => "Agua, vinagre de alcohol, 24,5% semillas de mostaza, [cáscara de semillas de mostaza], sal, acidulante: [ácido citico]; aromas, antioxidante: metabisulfito potásico; especia.",
# ingredients_text_hr => "Voda, alkoholni ocat, 24,5% sjemenke gorušice, [7,5% ljuske gorušice], kuhinjska sol, kiselina: limunska kiselina; arome, antioksidans: kalijev metabisulfit; začin.",
# ingredients_text_ro => "apă, oțet din vin, [semințe de muştar], [coji de muştar], sare de masă, acidifiant: acid citric, [arome naturale de cuişoare], scorțișoară, ghimbir și tarhon, antioxidant: metabisulfit de potasiu, amestec de condimente.",
#  RO has more ingredients
#  ES has a typo ácido citico -> Ácido cítrico
my $product_ref = {
	ingredients_text_es => "Agua, vinagre de alcohol, 24,5% semillas de mostaza, [cáscara de semillas de mostaza], sal, acidulante: [ácido citico]; aromas, antioxidante: metabisulfito potásico; especia.",
	ingredients_text_hr => "Voda, alkoholni ocat, 24,5% sjemenke gorušice, [7,5% ljuske gorušice], kuhinjska sol, kiselina: limunska kiselina; arome, antioksidans: kalijev metabisulfit; začin.",
    ingredients_text_ro => "apă, oțet din vin, [semințe de muştar], [coji de muştar], sare de masă, acidifiant: acid citric, [arome naturale de cuişoare], scorțișoară, ghimbir și tarhon, antioxidant: metabisulfit de potasiu, amestec de condimente.",
};


done_testing();
