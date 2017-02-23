#!/usr/bin/perl

use CGI::Carp qw(fatalsToBrowser);

use strict;
use utf8;

binmode(STDOUT, ":encoding(UTF-8)");

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Mail qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::Images qw/:all/;


use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON;
use Time::Local;

$lc = "fr";

my %openfood_nutrients = (
" polyunsaturated fatty acids" => "polyunsaturated-fat",
"biotin" => "biotin",
"calcium" => "calcium",
"carbohydrates" => "carbohydrates",
"cholesterol" => "cholesterol",
"energy" => "energy",
"fat" => "fat",
"fiber" => "fiber",
"folic acid" => "vitamin-b9",
"fructose" => "fructose",
"glucose" => "glucose",
"iodine" => "iodine",
"iron" => "iron",
"lactose" => "lactose",
"magnesium" => "magnesium",
"monounsaturated fatty acids" => "monounsaturated-fat",
"omega-3 fatty acids" => "omega-3-fat",
"phosphorus" => "phosphorus",
"polyols" => "polyols",
"protein" => "proteins",
"provitamin a (β-carotene)" => "beta-carotene",
"saccharose" => "sucrose",
"salt" => "salt",
"saturated fat" => "saturated-fat",
"selenium" => "selenium",
"sodium" => "sodium",
"sugars" => "sugars",
"vitamin a" => "vitamin-a",
"vitamin b1 (thiamin)" => "vitamin-b1",
"vitamin b12 (cobalamin)" => "vitamin-b12",
"vitamin b2 (riboflavin)" => "vitamin-b2",
"vitamin b3 (niacin)" => "vitamin-pp",
"vitamin b5 (panthothenic acid)" => "pantothenic-acid",
"vitamin b6 (pyridoxin)" => "vitamin-b6",
"vitamin c (ascorbic acid)" => "vitamin-c",
"vitamin d (cholacalciferol)" => "vitamin-d",
"vitamin e (tocopherol)" => "vitamin-e",
"vitamin k" => "vitamin-k",
"zinco" => "zinc",
);

my @ch_brands = qw(
Migros	752
Coop	147
M-budget	129
M-classic	108
Anna-s-best	96
Nestle	74
Leger	68
Naturaplan	67
Migros-bio	47
Subito	35
Unilever	32
Knorr	30
Kellogg-s	29
Emmi	29
Cornatur	28
Elsa	28
Alnatura	27
Ferrero	26
Coca-cola	26
Barilla	24
Bischofszell	23
Denner	22
Coop-naturaplan	22
Jowa	20
Cailler	19
Coop-qualite-prix	17
Lu	17
Betty-bossi	17
Lidl	16
Heinz	15
Nutella	15
Midor	15
Frey	15
Zweifel	13
Lipton	13
Pelican	13
Danone	13
Moleson	12
Lindt	12
Valflora	11
Carrefour	11
Mars	11
Bjorg	10
Thomy	10
Farmer	10
Migros-selection	10
Marque-repere	10
Mondelez	10
Ramseier	9
Ovomaltine	9
Andros	9
Bonne-maman	9
Maggi	8
Casino	8
Kinder	8
Evian	8
Kraft-foods	8
Prix-garantie	8
Denny-s	8
Karma	8
Milka	7
Kellogs	7
Volvic	7
Wander	7
Henniez	7
Haribo	7
Balisto	7
Farmer-s-best	7
Cremo	6
Innocent	6
Dr-oetker	6
Fleury-michon	6
Aproz	6
Qualite-prix	6
Delica	6
Ricola	6
Rivella	6
Bel	6
Red-bull	5
Buitoni	5
Actilife	5
Harrys	5
Findus-suisse	5
El-mundo	5
Patissier	5
Mondelez-international	5
Ben-jerry-s	5
Bell	5
Maille	5
M-bio	5
Oh	5
Old-el-paso	5
Delicorn	5
Dar-vida	5
Milbona	5
Nespresso	5
Longobardi	4
Sun-queen	4
Nescafe	4
Auchan	4
Bigler-ag	4
Michel	4
American-favorites	4
Uncle-ben-s	4
Herta	4
Del-lago	4
Rapelli	4
Lackerli-huus	4
Wernli	4
Granini	4
M-m-s	4
Villars	4
Nesquik	4
Yoplait	4
Perle-de-lait	4
Betty-bossy	4
Panzani	4
Pasquier	3
Kiri	3
Valser	3
Suter-viandes-sa	3
Micarna	3
Soja-line	3
Jogurtpur	3
Hug	3
Ponti	3
Polli	3
Fanta	3
Pringles	3
Nectaflor	3
Bon-chef	3
Optigal	3
Hero	3
Tuc	3
Fine-food	3
Schweppes	3
Natur-aktiv	3
Delicious	3
Celnat	3
Malbuner	3
Vittel	3
Nestle-waters	3
Volg	3
Combino	3
Aha	3
Camille-bloch	3
Banago	3
Naturafarm	3
Naturaplan-coop	3
St-michel	3
Migros-m-classic	3
Bioneo	3
Kambly	3
Primeal	3
Movenpick	3
Gerble	3
Terrasuisse	3
Milco	3
Jacquet	3
Nestea	3
Coca-cola-life	3
Coop-naturaplan-bio	3
Agnesi	3
Galbani	3
Cenovis	3
Lindt-excellence	3
Seeberger	3
Roland	3
Imex-ag	2
Bigler	2
Paturages	2
Groupe-carrefour	2
Babybel	2
Cantadou	2
Blevita	2
Philadelphia	2
Grafschafter	2
Condy	2
Belvita	2
Milupa	2
Mister-rice	2
Kagi	2
Schar	2
Fromarsac	2
Knusperone	2
Toni	2
Cora	2
Chavroux	2
Familia	2
Toblerone	2
Charal	2
V2tobacco	2
Chop-stick	2
Rama	2
Coraya	2
Nixe	2
Armando-de-angelis-pastaio	2
Cristaline	2
Sanpellegrino	2
A-vogel	2
Stimorol	2
Perrier	2
Crusti-croc	2
Freshona	2
Kelloggs	2
Gold	2
Brioche-pasquier	2
Alfredo	2
Arkina	2
Bn	2
Ragusa	2
Tic-tac	2
Haco	2
Choco-krispies	2
Petit-navire	2
Pim-s	2
Weleda	2
Jurasel	2
Tipiak	2
Crunch	2
Jordans	2
Bonvalle	2
Badoit	2
Trident	2
Tradition	2
Heidi	2
Crea-d-or	2
Weightwatchers	2
Migros-tradition	2
Coop-prix-garantie	2
Frey-migros	2
Soya-life	2
Migros-classic	2
Wasa	2
Starbucks	2
Biomilk	2
Mirador	2
Belbake	2
Twix	2
Minute-maid	2
Morga	2
Cristallina	2
Schnitzer	2
Becel	2
Bio-natur-plus-manor-food	2
Mcvitie-s	2
Crealine	2
Trs	2
Milsani	2
Picard	2
San-pellegrino	2
Whaou	2
Tartare	2
Migro	2
La-vie-claire	2
Lustucru	2
Allos	2
Rice-krispies	2
Kellog-s	2
Smacks	2
Al-fez	2
Chocoladefabriken-lindt-sprungli-ag	2
Chio	2
Costa	2
Frosta	2
Optimum-nutrition	2
Isola-bio	2
U	2
Faverger	2
Ikea	2
Famille-mary	1
M-classic-migros	1
Dumet	1
Leibniz	1
Feldschlosshen	1
Disch	1
Migros-terrasuisse	1
Agri-natura	1
Mosterei-mohl-ag	1
Hug-familie	1
Bannholz	1
Compal	1
Hiru-nestle	1
Clipper	1
Perldor	1
Montandon	1
Le-sucre	1
Tante-agathe	1
Confiland-s-a-r-l	1
Ivoria	1
Lozenges	1
Flying-power	1
Andalusien-sauce	1
Adelholzener	1
Maestade	1
Desse-alpina	1
Allegra	1
Gewurzmuhle-brecht	1
Gatorade	1
Bonne-maman-erdbeeren	1
Holzofenbrot-ips	1
San-benedetto	1
Betty-bissi	1
Bella-riviera	1
Vitalgrana	1
A-8362-furstenfeld	1
Frank-s-naturprodukte-gmbh	1
Hcl-f-57400-sarrebourg	1
Traditional-japanese-starch	1
Monini	1
Thomi	1
Colgate-total-original	1
Fol-epi	1
Himmelbauer	1
Pancroc	1
Eichhof-lager	1
Tea-time	1
Prix-garantie-coop	1
Stock	1
Giandor	1
Taunoma	1
Alesto	1
Avopri	1
Majestic	1
Miami	1
Chocolat-bernrain	1
Scotti-biolover	1
Aperitiv	1
Kneipp	1
National	1
Mwbrands-ets-paul-paulet	1
Nos-regions-ont-du-talent	1
Bell-sa	1
Valflora-migros	1
La-tourangelle	1
Quinuareal	1
Maizena	1
Ecomil	1
Tresor	1
Activia	1
Butter	1
Cidre-bouche	1
Selection-intermarche	1
Lowcarb-one	1
Confi-swiss	1
La-fauconnerie	1
Kitkat	1
Olivia-marino-pavesi	1
Orangina	1
Flying-dog	1
Confiserie-firenze	1
Maribel	1
La-espanola	1
Saint-louis	1
Lipton-ice-tea	1
Kraft	1
Well-active	1
Camille-bloch-sa	1
Reis-drink	1
La-vache-qui-rit	1
Kasegenuss	1
Soja-line-migros	1
Mccormick	1
Eve	1
Valpibio	1
Cardinal	1
Optimys	1
Hellema	1
Bounty	1
Oliver-s-toast	1
Petit-ecolier	1
Migros-leger	1
Migros-m-budget	1
Loue	1
Fitness	1
M	1
Muller-nahrungsmittel-ag	1
Dolce-gusto	1
Mars-chocolat-france	1
Yupi	1
Findus	1
Original-knacki	1
Mimare	1
Sennerei-bachtel	1
Hipp	1
Weinlanderbrot	1
La-ferme-biologique	1
Frigor	1
Carrefour-bio	1
Suisse	1
Pierre-schmidt	1
Romanette	1
Klostergarten	1
Cucina	1
Klostergarden	1
Prince	1
Migros-excellence-elsa	1
Le-bon-paris	1
Afiro	1
Alpenmark	1
Hepar	1
Cristal	1
Propiedad-de	1
Vacherin-mont-d-or	1
Arborio	1
Bongrain	1
Italiamo	1
Antico-modena	1
Le-sapalet-sarl	1
Le-parfait	1
Alter-eco	1
Elmex	1
Ritz	1
Colussi-group	1
Purina	1
Coop-prix-garantis	1
Darvida	1
V6	1
Paysan-breton	1
Pere-michel	1
Ultje	1
Qualite-et-prix-coop	1
Sonnenkorn	1
Creme-d-or	1
Hacienda-don-pablo	1
Tea-time-migros	1
Monster-energy	1
Stalder	1
La-laitiere	1
Arizona	1
Cracotte	1
Chocolats-villars	1
Original-wagner	1
Frisco-nestle	1
Lactalis-nestle	1
Xilito	1
Dymatize-nutrition	1
Alpro	1
Pain-creation	1
Hafer-flocken	1
Bufala	1
Choc-midor	1
Procter-gamble	1
Crownfield	1
Triballat-noyal	1
Fini	1
Valais	1
Muraca	1
Ederki	1
Markal	1
Beutelsacher	1
Les-confitures-a-l-ancienne	1
Migro-bio	1
Hollywood	1
Naturis	1
Nutri-k	1
Paniflor	1
Chabrior	1
Jelly-belly	1
Sponser	1
Orlait	1
Slimline	1
Das-schweizer-ei	1
Crespo	1
Betty-bossi-coop	1
Epi-d-or	1
Cmi-carrefour-marchandises-internationales	1
Ice-tea	1
Carambar	1
Belte	1
Lovechock	1
Don-pollo	1
Nestle-dessert	1
Danao	1
Le-lait-d-ici	1
Monster	1
Candia	1
Optimiser	1
Oswald	1
President	1
Saison	1
Corny	1
Coop-lifestyle	1
Thai	1
Maestrani	1
Giuseppe-citterio	1
Grill-mi	1
Jelly-belly-candy-company	1
Florales-4-lagig	1
Jules-destrooper	1
Notre-jardin	1
Alvalle	1
La-vosgienne	1
Pure-fruits	1
Super-bock	1
Ombia	1
Mattinella	1
Ricore	1
Swiss-alpina	1
Cpw	1
De-martins	1
Bio-organic	1
Pralina	1
Nakd-by-natural-balance-foods	1
Coop-naturalplan	1
Idenat	1
Daim	1
Antipasti	1
Lakerol	1
Maltesers	1
No-butter	1
Kern-sammet-ag	1
Icts-ag	1
Globus	1
Holderhof	1
Jakobs	1
Snack-fun	1
Samai-snacks	1
Alpenhaus	1
Henri-raffin	1
Nutrifrais-sa	1
Optonia	1
Raccard	1
Regal-soupe	1
Domino	1
Party	1
Fruit-d-or-pro-activ	1
Fattorie-osella	1
Cristalp	1
Le-beurre	1
Mindor	1
Edeka	1
Canderel	1
Ferero	1
Appenzellerbier	1
Naturkostbar	1
Delisse	1
Mifloc	1
All-bran	1
Vitalgeback	1
Cereal-partners	1
Zibu	1
Tossolia	1
Duc-de-coeur	1
Bisson	1
Hartl-85	1
Charles-alice	1
Les-croises	1
Kikkoman	1
Granola	1
Ebly	1
Gerber	1
Lepetit	1
Pouce	1
Agrupacion-de-cooperativas-valle-del-jerte	1
Joya	1
Munz	1
Tropicana	1
Alpina-savoie	1
Vitasia	1
Mont-asie	1
Cocacola	1
Old-holborn-yellow	1
Jafaden	1
Cauvin	1
Cipf-codipal	1
Kellog	1
Sel-des-alpes	1
Cuvee-st-sebastien	1
Cote-d-or	1
Hofer-kg	1
Biotta	1
Ocean-spray	1
Bischofszell-migros	1
Las-coronas	1
Migros-actilife	1
Harvest-basket	1
La-fina	1
Brasserie-lefebvre	1
Joya-soya	1
Ramseirer	1
Le-conserve-della-nonna	1
Pitch	1
Twinings	1
Rio-mare	1
Dymatise-nutrition	1
Nacional	1
Tyrrells	1
The-bridge	1
Volvic-juicy	1
Bischfszel	1
Bio-village	1
Mort-subite	1
Hirz-nestle	1
Leclerc	1
Golden-minis	1
Aptamil	1
Saint-agur	1
Buon-gusto	1
Ital-lemon	1
Teisseire	1
Minis	1
Samai	1
Alleskleber	1
Hirtz	1
Iseree	1
Emco	1
Migros-gold	1
Patrimoine-gourmand	1
Agrupacion-de-cooperativas-valle-del-jerte-s-coop-l	1
Kania	1
Sprite	1
Fromagerie-arnaud	1
Knusperone-aldi	1
Scamark-filiale-e-leclerc	1
Le-gruyere-switzerland-aoc	1
Vichy	1
Migros-grey	1
Alprose	1
Ramseier-suisse-ag	1
Spitzbuben	1
Labeyrie	1
Cope	1
Dawa	1
Carrefour-discount	1
Gautschi	1
Fromagerie-du-moleson	1
Bufidus	1
Cooper	1
Enervit	1
Coop-natura-plan	1
Handelmaier	1
Favarger	1
Belle-france	1
Babylove	1
Les-mousquetaires	1
Kingfrais	1
Aarberg	1
Nature-cie	1
Rocky-mountain	1
Dragibus-soft	1
Caotina	1
Aldi	1
Bonherba	1
Xenia	1
Calvinus-les-freres-papinot	1
Bonduelle	1
Agricola-tre-valli-soc-coop	1
Foodex	1
Aldi-studio	1
Gran-pavesi	1
Roberto	1
Special-k	1
Vegiline	1
Bischofszell-nahrungsmittel-ag	1
Oasis	1
Epagny-sa	1
Mibona	1
Baroni	1
Leader-price	1
Pro-montagna	1
Damalis-ag	1
D-aucy	1
Angelo-parodi	1
Pere-dodu	1
Chambon	1
Seven-up-international	1
Lobo-2-in-1	1
Sol	1
Estavayer-lait-sa	1
Bacardi	1
Trolli	1
Cook	1
Nature-active-bio	1
Cenovis-ag	1
Desperados	1
Maitre-jean-pierre	1
Parmareggio	1
Finest-bakery	1
Le-pain-des-fleurs	1
H-j-heinz-company	1
Abtei	1
Delacre	1
Brewdog	1
Colussi-s-p-a	1
Laboratoire-granion	1
Mavita	1
Tablette-d-or	1
309-honey	1
Rude-health	1
Materne	1
Swiss-diva	1
Pom-potes	1
Salakis	1
Lowenbrau	1
Spitz	1
Rigoni-di-asiago	1
Coop-fine-food	1
Amora	1
Doritos	1
Alnatura-migros	1
Naturaplam	1
Saint-alby	1
Kaugummi	1
Magnum	1
P-tits-heinz	1
Migros-france	1
Excellence	1
Nissin	1
La-belle-iloise	1
Les-2-vaches	1
Wenga	1
Stonyfield-france	1
Gelatelli	1
Incarom	1
Iswari	1
St-dalfour	1
Mei-yang	1
Maitre-prunille	1
Taifun	1
Gryson-belgium	1
De-la-region	1
Winston	1
Jfd-jus-frais-developpement	1
Clairefontaine	1
Lavalia	1
Feldschlosschen-boisson-sa	1
Flamant-vert	1
Vico	1
Stork	1
Super-aravis-la-clusaz	1
Intersnack-france	1
Nestle-nutrition	1
Delix	1
Fairglobe	1
Pure-via-stevia	1
Quaker	1
Pepsico	1
Krisprolls	1
Dragibus	1
Citric	1
Petit-billy	1
Alnatura-bio7-initiative	1
Harvin	1
Qnt	1
M-clasic	1
Boursault	1
Generous	1
Somona	1
Maitres-laitiers	1
Gerlinea	1
Budget-migros	1
Cool-qualite-prix	1
Almare-seafood	1
Americain-favorites	1
Casa-azzurra	1
Snickers	1
Cadbury	1
Green-shoot	1
Aldi-einkauf-gmbh-compagnie-ohg	1
Saldac	1
Avia-triada	1
Giralp	1
Michel-et-augustin	1
Argeta	1
Le-comptoir-de-mathilde	1
La-boulangere	1
Produits-blancs	1
Biberli	1
Thai-kitchen	1
Tree	1
Ecm-spa-milano-italia	1
Mcsoyana	1
Fromagerie-moleson	1
Bonneterre	1
Heineken	1
Damhert-nutrition	1
Mc-vitie-s	1
Heudebert	1
Jean-herve	1
Oishi	1
Lactel	1
Charles-antona	1
Le-cesarin	1
Bertschi-cafe	1
Mondelez-france	1
Candia-grandlait	1
Gusto-del-sol	1
Nescafe-dolce-gusto	1
Weetabix	1
Plaza-del-sol	1
Ficello	1
Emscha	1
Caprice-des-dieux	1
Lindt-sprungli	1
Eric-bur	1
Lima	1
Cosi-com-e	1
Banania	1
Old-elpaso	1
Penne-pomodoro-e-basilico	1
Pancho-villa	1
Oreo	1
El-almendro	1
Vanadis	1
Val-d-arve	1
Hirz	1
Belherbal	1
Cafe-royal	1
Food-and-good	1
Fonte-tavina	1
Erboristi-lendi	1
Bonfon	1
Leocrema	1
Paniflor-l-andouille-suisse	1
Nutella-go	1
Star	1
Castello	1
Merci	1
Two-hands	1
Orgran	1
Saint-mamet	1
Miel-l-apiculteur	1
Hot-chipotle-bbq-sauce	1
كوكا-كولا	1
Coca-cola-zero	1
Riche-vallee	1
Sojasun	1
St-moret	1
Leffe	1
Milfina	1
Skai	1
Dlp-distribution-leader-price	1
Seba-aproz	1
Groupe-casino	1
Le-gaulois	1
Zacapa	1
Heio	1
Kimura	1
La-collezione-d-italia	1
Floralp	1
Weider	1
Lanvin	1
Legusto	1
Natur-aktiv-aldi-sud	1
La-mortuacienne	1
Goldfein	1
Toffifee	1
Neutrogena	1
Nendaz	1
Nairns	1
Emile-noel	1
Olivier-co	1
Blini	1
Oldelpaso	1
Klene	1
Fromagerie-du-presbytere	1
Traditions-d-asie	1
Six-fortune	1
Coco-pops	1
French-s	1
Primas-tiefkuhlprodukte	1
Bouton-d-or	1
Michel-bolard	1
Baeilla	1
Chef-select	1
Barilla-mulino-bianco	1
Sanbitter	1
Innocent-super-smoothie	1
Pizzeria	1
Costa-ligure	1
Capri-sonne	1
Modifast	1
Morand	1
Vahine	1
Peter-moller	1
Natine-lea-nature	1
Coop-bety-bossy	1
Marmor-migros	1
Bio	1
Selection-du-fromager-des-halles	1
Bloch	1
Le-petit-marseillais	1
Jean-rene-germanier	1
Alnavit	1
Elsa-migros	1
Vollkor	1
Bebe	1
Choceur	1
Lakshmi	1
Rapilait	1
Primagusto	1
Mbudget	1
Mister-choc	1
Utz	1
Bernard-michaud	1
Oecoplan	1
Coop-karma	1
Rians	1
Leerdammer	1
Fromagerie-bel	1
R1	1
Mifroma	1
Taste-of-nature	1
Coop-betty-bossi	1
Happy-harvest	1
Merkur-kafee	1
Bio-primo	1
Ital-d-oro	1
Le-bistronome	1
Nature-activ	1
Mulino-bianco	1
Westcliff	1
Hilcona	1
Nestea-cocacolacompagny	1
Bio-migros	1
Filippi

115 Betty_Bossi
coop
74 Emmi
65 Barilla
58 Bon_Chef
45 Cailler
41 Altanatura
40 Bell
40 Hero
36 Dr.Oetker
31 Farmer
30 Actilife
28 Findus
25 Blévita
24 Agnesi
23 Heinz
21 Andros
21 Belle_France
21 Bonne_Maman
21 Condy
21 Cornatur
19 Blue_Elephant
17 Haribo
16 Coca-Cola

American_Favorites
 Balisto
 Bischofszell
 Bonherba
 Café_de_Paris
 Café_Royal
 Goldkenn
 Brioche_Pasquier
 Chop_Stick
 De_Cecco
 Delizio
 Ferrero
 Galbani
 Creazioni_d’Italia
 Ben_&_Jerry’s
 Creme_d’Or
 Glacetta
 Gomz
 Gran_Cereale
 Gran_Pavesi
 CreamAmore
 Granini
 Buitoni
 Easy_Soup
 Favorit
 Fleury_Michon
 Giovanni_Rana
 Gold_Star
 Assugrin
 Cirio
 Citterio
 Créa_d’Or
 Elsa
 
7up
Ben_&_Jerry's
BERTOLLI
Academia_Barilla
Armando_de_Angelis
boursin
Brossard
Casa_Giuliana
Colman's
Confiland
Coppenrath
Creazioni_d'Italia
Cuida_Té
DelMonte
Del_Monte
Docteur_Gab's
Dr._Oetker
Dr._Watson's
Filippo_Berio
Fiorentini
Fisherman's_Friend
Garofalo
Garbit
Gérard_Bertrand
Giraudet
Giotto
Grand-Mère
Grande_caffè
Griesson
Häagen-Dazs
Harry
Hugo_Reitzel
iglo
Jack_Daniel's
Jamadu
Jaillance
Jean-Louis
Jean_Martin
J.P._CHENET
Justin_bridou
Kühne
Larry's
La_Sensuelle
Le_Brebisane
Leisi
Le_patron
Le_petit_chevrier
le_petit_dessert
Les_compagnons_du_miel
Lieber's
liebig
lotus
madrange
Maçarico
MAÎTRE_DE_CHAIS
Marie
Martini
MClassic
Megastar
mentos
Meßmer
Motta
MyMuesli2Go
Namaste_India
nimm2
noblesse
olo
olz
ottiger
Patak's
PrixGarantie
PR!X_Garantie
Qualité_&_Prix
rana
Red_Band
Sabo
SACLÀ_ITALIA
Saitaku
Sandro_Vanini
Sarasay
Saupiquet
SAVEURS_&_TERROIR
Schwarztee
Schweizer
Silivri
SMIRNOFF
Snasseff
Sperlari
Spur
ST._DALFOUR
Storck
Strongbow
Stubb's
TAMTAM
TEEKANNE
Tetley
The_green_Fairy
Thé_Symphonie
Ticinella
Twinnings_of_London
Valaisanne
Veganz
Walkers
YOGI_TEA 
 
);

my @brands_regexps = ();

foreach my $brand (sort ({ length($b) <=> length($a)  } @ch_brands)) {
	next if $brand =~ /^\d+$/;
	$brand = lc($brand);
	# - can match non words characters
	$brand =~ s/(-|_)/\\W/g;
	# accents
	$brand =~ s/a/\(a|à|á|â|ã|ä|å\)/ig;
	$brand =~ s/c/\(c|ç\)/ig;
	$brand =~ s/e/\(e|è|é|ê|ë\)/ig;
	$brand =~ s/i/\(i|ì|í|î|ï\)/ig;
	$brand =~ s/n/\(n|ñ\)/ig;
	$brand =~ s/o/\(o|ò|ó|ô|õ|ö\)/ig;
	$brand =~ s/u/\(u|ù|ú|û|ü\)/ig;
	$brand =~ s/y/\(y|ý|ÿ\)/ig;
	$brand =~ s/oe/\(oe|œ|Œ\)/ig;
	$brand =~ s/ae/\(ae|æ|Æ\)/ig;
	
	push @brands_regexps, $brand;
}

my %nutrients_names = ();

$User_id = 'openfood-ch-import';

my $editor_user_id = 'openfood-ch-import';

my $dir = $ARGV[0];
$dir =~ s/\/$//;

my $photo_user_id = $ARGV[1];

$User_id = 'openfood-ch-import';
$photo_user_id = "openfood-ch-import";
$editor_user_id = "openfood-ch-import";

not defined $photo_user_id and die;

print "uploading json and photos from dir $dir\n";

my $i = 0;
my $j = 0;
my %codes = ();
my $current_code = undef;
my $previous_code = undef;
my $last_imgid = undef;

my $current_product_ref = undef;

my @fields = qw(product_name generic_name quantity packaging brands categories labels origins manufacturing_places emb_codes link expiration_date purchase_places stores countries  );

my @param_sorted_langs = qw(fr en de it);

my %global_params = (
	lc => 'fr',
	countries => "Suisse",
);

$lc = 'fr';

my $comment = "openfood.ch data import";

my $time = time();

my $i = 0;
my $existing = 0;
my $new = 0;
my $differing = 0;
my %differing_fields = ();
my %edited_fields = ();
my @edited = ();
my %edited = ();

my $testing = 0;

if (opendir (DH, "$dir/json")) {
	foreach my $file (sort { $a <=> $b } readdir(DH)) {
	
		#next if $file gt "2013-07-13 11.02.07";
		#next if $file le "DSC_1783.JPG";
	
		if ($file =~ /\.json/i) {
		
			$i++;
		
			open (my $in, "<", "$dir/json/$file") or die "cannot read $dir/json/$file : $! \n";
			my $json = join("",(<$in>));
			close $in;
			
			#print $json;
			
			my @modified_fields;
			my @images_ids;
			
			my $openfood_ref = decode_json($json);
			my $openfood_id = $openfood_ref->{data}{id};
			my $openfood_product_ref = $openfood_ref->{data}{attributes};
			my $code = $openfood_product_ref->{barcode};
			
			#next if $openfood_id ne "15675";
			
			print "product $i - openfood_id: $openfood_id - code: $code\n";
			
			#$openfood_id < 7486 and next;
			
			my $product_ref = product_exists($code); # returns 0 if not
			
			if (not $product_ref) {
				print "- does not exist in OFF yet\n";
				$new++;
				if (1 and (not $product_ref)) {
					print "product code $code does not exist yet, creating product\n";
					$User_id = $photo_user_id;
					$product_ref = init_product($code);
					$product_ref->{interface_version_created} = "import_openfood_ch.pl - version 2017/02/06";
					$product_ref->{lc} = $global_params{lc};
					delete $product_ref->{countries};
					delete $product_ref->{countries_tags};
					delete $product_ref->{countries_hierarchy};					
					#store_product($product_ref, "Creating product (import_openfood_ch.pl bulk upload) - " . $comment );					
				}				
				
			}
			else {
				print "- already exists in OFF\n";
				$existing++;
			}
			
			
			# First load the global params, then apply the product params on top
			my %params = %global_params;
			
			my %openfood_language_specific_fields = (
				'name' => 'product_name',
			);
			
			foreach my $field (sort keys %openfood_language_specific_fields) {
			
				my $off_field = $openfood_language_specific_fields{$field};

				# ingredients: "farine d'epeautre 89% (Allemagne), graisse de palme, sésame 3% (Egypte), sel marin, extrait de malt d'orge, levure. Traitement en surface: hydroxyde de sodium E 524. ",
				# ingredients-translations: {
				#	de: "Dinkelmehl 89% (Deutschland), Palmfett, Sesam 3% (Ägypten), Meersalz, Gerstenmalzextrakt, Hefe. Oberflächenbehandlung: Natriumhydroxid E 524. ",
				#	fr: "farine d'epeautre 89% (Allemagne), graisse de palme, sésame 3% (Egypte), sel marin, extrait de malt d'orge, levure. Traitement en surface: hydroxyde de sodium E 524. ",
				#	it: "farina di spelta 89% (Germania), grasso di palma, sesamo 3% (Egitto), sale marino, estratto di malto di orzo, lievito. Sostanza per il trattamento in superficie: idrossido di sodio E 524"				
				
				if (defined $openfood_product_ref->{$field}) {
					$params{$off_field} = $openfood_product_ref->{$field};
					if (ref ($params{$off_field}) eq 'ARRAY') {
						$params{$off_field} = join(', ', @{$params{$off_field}});
					}					
					print "set $field to $params{$field}\n";
					
					if (defined $openfood_product_ref->{$field . "-translations"}) {
					
						foreach my $language (@param_sorted_langs) {
						
							if (defined $openfood_product_ref->{$field . "-translations"}{$language}) {
								$params{$off_field . "_" . $language} = $openfood_product_ref->{$field . "-translations"}{$language};
								if (ref ($params{$off_field . "_" . $language}) eq 'ARRAY') {
									$params{$off_field . "_" . $language} = join(', ', @{$params{$off_field . "_" . $language}});
								}
								
				if ($field eq 'name') {
				foreach my $regexp (@brands_regexps) {
					if ($params{$off_field . "_" . $language} =~ /^($regexp)\b/i) {
						my $brand = $1;
						my $product_name = $';
						$product_name =~ s/^\W+//;
						print "found brand $brand - product $product_name - in name $openfood_product_ref->{name} \n";
						$params{$off_field . "_" . $language} = $product_name;
						last;
					}
				}
				}
								
								print "set " . $off_field . "_" . $language . " to " . $params{$off_field . "_" . $language} . "\n";
							}
						}
					}
					
					# override value with main language
					if (defined $params{$off_field . "_" . $global_params{lc}}) {
						$params{$off_field} = $params{$off_field . "_" . $global_params{lc}}
					}
				}			
			
			}


			
			
			# Create or update fields
			
			my @param_fields = ();
			
			my @fields = @ProductOpener::Config::product_fields;
			foreach my $field ('product_name') {
			
				if (defined $language_fields{$field}) {
					foreach my $display_lc (@param_sorted_langs) {
						push @param_fields, $field . "_" . $display_lc;
					}
				}
				else {
					push @param_fields, $field;
				}
			}
	
					
			foreach my $field (@param_fields) {
				
				if (defined $params{$field}) {				

				
					{
						# non-tag field
						my $new_field_value = $params{$field};
						my $normalized_new_field_value = $new_field_value;
						
						
						# existing value?
						if ((defined $product_ref->{$field}) and ($product_ref->{$field} !~ /^\s*$/)) {
							my $current_value = $product_ref->{$field};
							$current_value =~ s/\s+$//g;
							$current_value =~ s/^\s+//g;							
												
							if (lc($current_value) ne lc($normalized_new_field_value)) {
								print "differing value for product code $code - field $field - existing value: $product_ref->{$field} (normalized: $current_value) - new value: $new_field_value - https://world.openfoodfacts.org/product/$code \n";
								$differing++;
								$differing_fields{$field}++;
								
								# see bug https://github.com/openfoodfacts/openfoodfacts-server/issues/649
								if (($field eq "product_name_fr") and (($current_value eq $params{"product_name_de"}))) {
									print "overwrite FR value currently set to DE value - code $code - openfoodid $openfood_id - new fr value: $new_field_value - old value: $current_value\n";
									$product_ref->{$field} = $new_field_value;
									push @modified_fields, $field;
									$edited_fields{$field}++;
								}
								elsif (($field eq "product_name_fr") and (($current_value eq $params{"product_name_en"}))) {
									print "overwrite FR value currently set to EN value - code $code - openfoodid $openfood_id - new fr value: $new_field_value - old value: $current_value\n";
									$product_ref->{$field} = $new_field_value;
									push @modified_fields, $field;
									$edited_fields{$field}++;
								}
								elsif (($field eq "product_name_fr") and (($current_value eq $params{"product_name_it"}))) {
									print "overwrite FR value currently set to IT value - code $code - openfoodid $openfood_id - new fr value: $new_field_value - old value: $current_value\n";
									$product_ref->{$field} = $new_field_value;
									push @modified_fields, $field;
									$edited_fields{$field}++;
								}								
							}
						}
						else {
							print "setting previously unexisting value for product code $code - field $field - value: $new_field_value\n";
							$product_ref->{$field} = $new_field_value;
							push @modified_fields, $field;
							$edited_fields{$field}++;	
						}
					}					
				}
			}
			
			
			$User_id = $editor_user_id;
			
			if ((not $testing) and ((scalar keys @modified_fields) > 0)) {
			
			
			# For fields that can have different values in different languages, copy the main language value to the non suffixed field
			
			foreach my $field (keys %language_fields) {
				if ($field !~ /_image/) {
					if (defined $product_ref->{$field . "_$product_ref->{lc}"}) {
						$product_ref->{$field} = $product_ref->{$field . "_$product_ref->{lc}"};
					}
				}
			}			
			
				print "Saving product $code\n";
				store_product($product_ref, "Editing product (import_openfood_ch_name_translations.pl bulk import) - " . $comment );
				
				push @edited, $code;
				$edited{$code}++;
				
				$i > 10000000 and last;
			}
			
			#last;
		}  # if $file =~ json
			
	}
	closedir DH;
}
else {
	print STDERR "Could not open dir $dir/json : $!\n";
}

print "$i products\n";
print "$new new products\n";
print "$existing existing products\n";
print "$differing differing values\n\n";

foreach my $field (sort keys %differing_fields) {
	print "field $field - $differing_fields{$field} differing values\n";
}
print "\n\n";

print ((scalar @edited) . " edited products\n");
print ((scalar keys %edited) . " editions\n");

foreach my $field (sort keys %edited_fields) {
	print "field $field - $edited_fields{$field} editions\n";
}



#print "\n\nlist of nutrient names:\n\n";
#foreach my $name (sort keys %nutrients_names) {
#	print $name . "\n";
#}
