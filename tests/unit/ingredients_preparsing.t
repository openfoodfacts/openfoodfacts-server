#!/usr/bin/perl -w

# Tests of Ingredients::preparse_ingredients_text()

use Modern::Perl '2017';
use utf8;

use Test2::V0;
use Log::Any::Adapter 'TAP';

use ProductOpener::Products qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Test qw/compare_to_expected_results init_expected_results/;
use ProductOpener::Ingredients
	qw/normalize_a_of_b normalize_enumeration preparse_ingredients_text separate_additive_class/;

#use Log::Any::Adapter 'TAP', filter => "none";

is(normalize_a_of_b("en", "oil", "olive", 1), "olive oil");
is(normalize_a_of_b("es", "aceta", "oliva", 1), "aceta de oliva");
is(normalize_a_of_b("fr", "huile végétale", "olive", 1), "huile végétale d'olive");

is(normalize_enumeration("en", "phosphates", "calcium and sodium", 1),
	"phosphates (calcium phosphates, sodium phosphates)");
is(
	normalize_enumeration("en", "vegetal oil", "sunflower, palm", 1),
	"vegetal oil (sunflower vegetal oil, palm vegetal oil)"
);
is(
	normalize_enumeration("fr", "huile", "colza, tournesol et olive", 1),
	"huile (huile de colza, huile de tournesol, huile d'olive)"
);

is(separate_additive_class("fr", "colorant", " ", "", "naturel"), "colorant ");
is(separate_additive_class("fr", "colorant", " ", "", "carmins"), "colorant : ");
is(separate_additive_class("fr", "colorant", " ", "", "E120, sel"), "colorant : ");
is(separate_additive_class("fr", "colorant", " ", "", "E120 et E150b"), "colorant : ");
is(separate_additive_class("fr", "colorant", " ", "", "caramel au sulfite d'ammonium"), "colorant : ");
is(separate_additive_class("fr", "colorant", " ", "", "caramel au sulfite d'ammonium et rocou"), "colorant : ");

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

my @tests = (
	{
		id => '1',
		lc => 'fr',
		ingredients_text => 'Sel marin, blé, lécithine de soja'
	},
	{
		id => '2',
		lc => 'fr',
		ingredients_text => 'Vitamine A'
	},
	{
		id => '3',
		lc => 'fr',
		ingredients_text => 'Vitamines A, B et C'
	},
	{
		id => '4',
		lc => 'fr',
		ingredients_text => 'Vitamines (B1, B2, B6, PP)'
	},
	{
		id => '5',
		lc => 'fr',
		ingredients_text => 'Huile de palme'
	},
	{
		id => '6',
		lc => 'fr',
		ingredients_text => 'Huile (palme)'
	},
	{
		id => '7',
		lc => 'fr',
		ingredients_text => 'Huile (palme, colza)'
	},
	{
		id => '8',
		lc => 'fr',
		ingredients_text => 'Huile (palme et colza)'
	},
	{
		id => '9',
		lc => 'fr',
		ingredients_text => 'Huiles végétales de palme et de colza'
	},
	{
		id => '10',
		lc => 'fr',
		ingredients_text => 'Huiles végétales de palme et d\'olive'
	},
	{
		id => '11',
		lc => 'fr',
		ingredients_text => 'Huiles végétales de palme, de colza et de tournesol'
	},
	{
		id => '12',
		lc => 'fr',
		ingredients_text => 'Huiles végétales de palme, de colza, de tournesol'
	},
	{
		id => '13',
		lc => 'fr',
		ingredients_text => 'Huiles végétales de palme, de colza et d\'olive en proportion variable'
	},
	{
		id => '14',
		lc => 'fr',
		ingredients_text => 'Huiles végétales de palme, de colza et d\'olive'
	},
	{
		id => '15',
		lc => 'fr',
		ingredients_text => 'phosphate et sulfate de calcium'
	},
	{
		id => '16',
		lc => 'fr',
		ingredients_text => 'sulfates de calcium et potassium'
	},
	{
		id => '17',
		lc => 'fr',
		ingredients_text => 'chlorures (sodium et potassium)'
	},
	{
		id => '18',
		lc => 'fr',
		ingredients_text => 'chlorures (sodium, potassium)'
	},
	{
		id => '19',
		lc => 'fr',
		ingredients_text => 'fraises 30%'
	},
	{
		id => '20',
		lc => 'fr',
		ingredients_text =>
			'Marmelade d\'oranges 41% (sirop de glucose-fructose, sucre, pulpe d\'orange 4.5%, jus d\'orange concentré 1.4% (équivalent jus d\'orange 7.8%), pulpe d\'orange concentrée 0.6% (équivalent pulpe d\'orange 2.6%), gélifiant (pectines), acidifiant (acide citrique), correcteurs d\'acidité (citrate de calcium, citrate de sodium), arôme naturel d\'orange, épaississant (gomme xanthane)), chocolat 24.9% (sucre, pâte de cacao, beurre de cacao, graisses végétales (illipe, mangue, sal, karité et palme en proportions variables), arôme, émulsifiant (lécithine de soja), lactose et protéines de lait), farine de blé, sucre, oeufs, sirop de glucose-fructose, huile de colza, poudre à lever (carbonate acide d\'ammonium, diphosphate disodique, carbonate acide de sodium), sel, émulsifiant (lécithine de soja).'
	},
	{
		id => '21',
		lc => 'fr',
		ingredients_text => 'graisses végétales (illipe, mangue, sal, karité et palme en proportions variables)'
	},
	{
		id => '22',
		lc => 'fr',
		ingredients_text => 'graisses végétales (illipe, mangue, palme)'
	},
	{
		id => '23',
		lc => 'fr',
		ingredients_text => 'graisses végétales (illipe)'
	},
	{
		id => '24',
		lc => 'fr',
		ingredients_text => 'graisses végétales (illipe et sal)'
	},
	{
		id => '25',
		lc => 'fr',
		ingredients_text => 'gélifiant pectine'
	},
	{
		id => '26',
		lc => 'fr',
		ingredients_text => 'gélifiant (pectine)'
	},
	{
		id => '27',
		lc => 'fr',
		ingredients_text => 'agent de traitement de la farine (acide ascorbique)'
	},
	{
		id => '28',
		lc => 'fr',
		ingredients_text => 'lait demi-écrémé'
	},
	{
		id => '29',
		lc => 'fr',
		ingredients_text => 'Saveur vanille : lait demi-écrémé 77%, sucre'
	},
	{
		id => '30',
		lc => 'fr',
		ingredients_text => 'colorants alimentaires E (124,122,133,104,110)'
	},
	{
		id => '31',
		lc => 'fr',
		ingredients_text => 'INS 240,241,242b'
	},
	{
		id => '32',
		lc => 'fr',
		ingredients_text => 'colorants E (124, 125, 120 et 122'
	},
	{
		id => '33',
		lc => 'fr',
		ingredients_text => 'E250-E251'
	},
	{
		id => '34',
		lc => 'fr',
		ingredients_text => 'E250-E251-E260'
	},
	{
		id => '35',
		lc => 'fr',
		ingredients_text => 'E 250b-E251-e.260(ii)'
	},
	{
		id => '36',
		lc => 'fr',
		ingredients_text => 'émulsifiants : E463, E432 et E472 - correcteurs d\'acidité : E322/E333 E474-E475'
	},
	{
		id => '37',
		lc => 'fr',
		ingredients_text => 'E100 E122'
	},
	{
		id => '38',
		lc => 'fr',
		ingredients_text => 'E103 et E140'
	},
	{
		id => '39',
		lc => 'fr',
		ingredients_text => 'E103 ET E140'
	},
	{
		id => '40',
		lc => 'fr',
		ingredients_text => 'curcumine et E140'
	},
	{
		id => '41',
		lc => 'fr',
		ingredients_text => 'E140 et tartrazine'
	},
	{
		id => '42',
		lc => 'fr',
		ingredients_text => 'Acide citrique, colorant : e120, vitamine C, E-500'
	},
	{
		id => '43',
		lc => 'fr',
		ingredients_text => 'poudres à lever (carbonates acides d’ammonium et de sodium, acide citrique)'
	},
	{
		id => '44',
		lc => 'en',
		ingredients_text => 'REAL SUGARCANE, SALT, ANTIOXIDANT (INS 300), INS 334, INS345'
	},
	{
		id => '45',
		lc => 'es',
		ingredients_text => 'colores E (120, 124 y 125)'
	},
	{
		id => '46',
		lc => 'es',
		ingredients_text => 'Leche desnatada de vaca, enzima lactasa y vitaminas A, D, E y ácido fólico.'
	},
	{
		id => '47',
		lc => 'es',
		ingredients_text =>
			'Leche desnatada, leche desnatada en polvo, zumo de lima, almidón de maíz, extracto de ginseng 0,19%, aromas, fermentos lácticos con Lcasei, colorante: caramelo natural, edulcorantes: sucralosa y acesulfamo K, estabilizante: goma xantana, vitaminas: D, B6, ácido fólico y B12 Origen de la feche. España. Preparación: Agitar antes de abrir.'
	},
	{
		id => '48',
		lc => 'es',
		ingredients_text =>
			'edulcorantes (acesulfamo K y sucralosa) y vitaminas (riboflavina (vitamina B2) y cianocobalamina vitamina B12))'
	},
	{
		id => '49',
		lc => 'es',
		ingredients_text => 'aceites vegetales [aceite de girasol (70%) y aceite de oliva virgen (30%)] y sal'
	},
	{
		id => '50',
		lc => 'es',
		ingredients_text => 'Trazas de cacahuete, huevo y frutos de cáscara.'
	},
	{
		id => '51',
		lc => 'es',
		ingredients_text =>
			'sal y acidulante (ácido cítrico). Puede contener trazas de cacahuete, huevo y frutos de cáscara.'
	},
	{
		id => '52',
		lc => 'da',
		ingredients_text => 'bl. a. inkl. mod. past. emulgator E322 E103, E140, E250 og E100'
	},
	{
		id => '53',
		lc => 'nb',
		ingredients_text => 'bl. a. inkl. E322 E103, E140, E250 og E100'
	},
	{
		id => '54',
		lc => 'sv',
		ingredients_text => 'bl. a. förtjockn.medel inkl. emulgeringsmedel E322 E103, E140, E250 och E100'
	},
	{
		id => '55',
		lc => 'da',
		ingredients_text =>
			'Vitaminer A, B og C. Vitaminer (B2, E, D), Hvede**. Indeholder mælk. Kan indeholde spor af soja, mælk, mandler og sesam. ** = Økologisk'
	},
	{
		id => '56',
		lc => 'is',
		ingredients_text => 'Vítamín (B2, E og D). Getur innihaldið hnetur, soja og mjólk í snefilmagni.'
	},
	{
		id => '57',
		lc => 'nb',
		ingredients_text =>
			'Vitaminer A, B og C. Vitaminer (B2, E, D). Kan inneholde spor av andre nøtter, soya og melk.'
	},
	{
		id => '58',
		lc => 'sv',
		ingredients_text =>
			'Vitaminer (B2, E och D), Vete*. Innehåller hasselnötter. Kan innehålla spår av råg, jordnötter, mandel, hasselnötter, cashewnötter och valnötter. *Ekologisk'
	},
	{
		id => '59',
		lc => 'fi',
		ingredients_text => 'Vitamiinit A, B ja C'
	},
	{
		id => '60',
		lc => 'fi',
		ingredients_text => 'Vitamiinit (B1, B2, B6)'
	},
	{
		id => '61',
		lc => 'fi',
		ingredients_text => 'mansikat 30%'
	},
	{
		id => '62',
		lc => 'fi',
		ingredients_text => 'sakeuttamisaine pektiini'
	},
	{
		id => '63',
		lc => 'fi',
		ingredients_text => 'sakeuttamisaine (pektiini)'
	},
	{
		id => '64',
		lc => 'fi',
		ingredients_text => 'jauhonparanne (askorbiinihappo)'
	},
	{
		id => '65',
		lc => 'fi',
		ingredients_text => 'E250-E251'
	},
	{
		id => '66',
		lc => 'fi',
		ingredients_text => 'E250-E251-E260'
	},
	{
		id => '67',
		lc => 'fi',
		ingredients_text => 'E 250b-E251-e.260(ii)'
	},
	{
		id => '68',
		lc => 'fi',
		ingredients_text => 'E100 E122'
	},
	{
		id => '69',
		lc => 'fi',
		ingredients_text => 'E103 ja E140'
	},
	{
		id => '70',
		lc => 'fi',
		ingredients_text => 'E103 JA E140'
	},
	{
		id => '71',
		lc => 'fi',
		ingredients_text => 'kurkumiini ja E140'
	},
	{
		id => '72',
		lc => 'fi',
		ingredients_text => 'E140 ja karoteeni'
	},
	{
		id => '73',
		lc => 'fi',
		ingredients_text => 'omenamehu, vesi, sokeri. jossa käsitellään myös maitoa.'
	},
	{
		id => '74',
		lc => 'fi',
		ingredients_text => 'omenamehu, vesi, sokeri. Saattaa sisältää pieniä määriä selleriä, sinappia ja vehnää.'
	},
	{
		id => '75',
		lc => 'fi',
		ingredients_text => 'omenamehu, vesi, sokeri. Saattaa sisältää pienehköjä määriä selleriä, sinappia ja vehnää.'
	},
	{
		id => '76',
		lc => 'fi',
		ingredients_text => 'luomurypsiöljy, luomu kaura, vihreä luomutee'
	},
	{
		id => '77',
		lc => 'fr',
		ingredients_text => 'arôme naturel de citron-citron vert et d\'autres agrumes'
	},
	{
		id => '78',
		lc => 'fr',
		ingredients_text => 'arômes naturels de citron et de limette'
	},
	{
		id => '79',
		lc => 'fr',
		ingredients_text => 'arôme naturel de pomme avec d\'autres arômes naturels'
	},
	{
		id => '80',
		lc => 'fr',
		ingredients_text => 'jus de pomme, eau, sucre. Traces de lait.'
	},
	{
		id => '81',
		lc => 'fr',
		ingredients_text => 'jus de pomme, eau, sucre. Traces possibles de céleri, moutarde et gluten.'
	},
	{
		id => '82',
		lc => 'fr',
		ingredients_text => 'jus de pomme, eau, sucre. Traces possibles de céleri, de moutarde et gluten.'
	},
	{
		id => '83',
		lc => 'fr',
		ingredients_text => 'Traces de moutarde'
	},
	{
		id => '84',
		lc => 'fr',
		ingredients_text => 'Sucre de canne Traces éventuelles d\'oeufs'
	},
	{
		id => '85',
		lc => 'fr',
		ingredients_text => 'huile végétale de tournesol et/ou colza'
	},
	{
		id => '86',
		lc => 'de',
		ingredients_text => 'Zucker. Kann Spuren von Sellerie.'
	},
	{
		id => '87',
		lc => 'de',
		ingredients_text => 'Zucker. Kann Spuren von Senf und Sellerie.'
	},
	{
		id => '88',
		lc => 'de',
		ingredients_text => 'Zucker. Kann Spuren von Senf und Sellerie enthalten'
	},
	{
		id => '89',
		lc => 'it',
		ingredients_text => 'Puo contenere tracce di frutta a guscio, sesamo, soia e uova'
	},
	{
		id => '90',
		lc => 'it',
		ingredients_text => 'Il prodotto può contenere tracce di GRANO, LATTE, UOVA, FRUTTA A GUSCIO e SOIA.'
	},
	{
		id => '91',
		lc => 'fr',
		ingredients_text => 'Jus de pomme*** 68%, jus de poire***32% *** Ingrédients issus de l\'agriculture biologique'
	},
	{
		id => '92',
		lc => 'fr',
		ingredients_text =>
			'Pâte de cacao°* du Pérou 65 %, sucre de canne°*, beurre de cacao°*, sel *, lait °. °Issus de l\'agriculture biologique (100 %). *Issus du commerce équitable (100 % du poids total avec 93 % SPP).'
	},
	{
		id => '93',
		lc => 'fr',
		ingredients_text =>
			'pâte de cacao* de Madagascar 75%, sucre de canne*, beurre de cacao*. * issus du commerce équitable et de l\'agriculture biologique (100% du poids total).'
	},
	{
		id => '94',
		lc => 'fr',
		ingredients_text =>
			'Céleri - rave 21% - Eau, légumes 33,6% (carottes, céleri - rave, poivrons rouges 5,8% - haricots - petits pois bio - haricots verts - courge - radis, pommes de terre - patates - fenouil - cerfeuil tubéreux - persil plat)'
	},
	{
		id => '95',
		lc => 'fr',
		ingredients_text =>
			'poudres à lever : carbonates d\'ammonium - carbonates de sodium - phosphates de calcium, farine, sel'
	},
	{
		id => '96',
		lc => 'en',
		ingredients_text => 'FD&C Red #40 Lake and silicon dioxide'
	},
	{
		id => '97',
		lc => 'fr',
		ingredients_text => 'Lait pasteurisé à 1,1% de Mat. Gr.'
	},
	{
		id => '98',
		lc => 'fr',
		ingredients_text => 'matière grasse végétale (palme) raffinée'
	},
	{
		id => '99',
		lc => 'fr',
		ingredients_text => 'huile d\'olive vierge, origan'
	},
	{
		id => '100',
		lc => 'fr',
		ingredients_text => 'huile de tournesol, cacao maigre en poudre 5.2%'
	},
	{
		id => '101',
		lc => 'pl',
		ingredients_text => 'regulatory kwasowości: kwas cytrynowy i cytryniany sodu.'
	},
	{
		id => '102',
		lc => 'de',
		ingredients_text =>
			'Wasser, Kohlensäure, Farbstoff Zuckerkulör E 150d, Süßungsmittel Aspartam* und Acesulfam-K, Säuerungsmittel Phosphorsäure und Citronensäure, Säureregulator Natriumcitrat, Aroma Koffein, Aroma. enthält eine Phenylalaninquelle'
	},
	{
		id => '103',
		lc => 'de',
		ingredients_text => 'Farbstoffe Betenrot, Paprikaextrakt, Kurkumin'
	},
	{
		id => '104',
		lc => 'de',
		ingredients_text =>
			'Zucker, Glukosesirup, Glukose-Fruktose-Sirup, Stärke, 8,5% Süßholzsaft, brauner Zuckersirup, modifizierte Stärke, Aromen, pflanzliches Öl (Sonnenblume), Überzugsmittel: Bienenwachs, weiß und gelb'
	},
	{
		id => '105',
		lc => 'de',
		ingredients_text =>
			'Zucker, Glukosesirup, Glukose-Fruktose-Sirup, Stärke, 8,5% Süßholzsaft, brauner Zuckersirup, modifizierte Stärke, Aromen, pflanzliches Öl (Sonnenblume), Überzugsmittel: Bienenwachs (weiß und gelb)'
	},
	{
		id => '106',
		lc => 'fr',
		ingredients_text => 'graisse végétale bio (colza)'
	},
	{
		id => '107',
		lc => 'fr',
		ingredients_text =>
			'huiles végétales* (huile de tournesol*, huile de colza*). *Ingrédients issus de l\'agriculture biologique'
	},
	{
		id => '108',
		lc => 'fr',
		ingredients_text => 'huile biologique (tournesol, olive)'
	},
	{
		id => '109',
		comment => "xyz: test an unrecognized oil -> do not change",
		lc => 'fr',
		ingredients_text => 'huile biologique (tournesol, xyz)'
	},
	{
		id => '110',
		lc => 'fr',
		ingredients_text => 'huiles biologiques (tournesol, olive)'
	},
	{
		id => '111',
		lc => 'fr',
		ingredients_text => 'huiles (tournesol*, olive). * : bio'
	},
	{
		id => '112',
		lc => 'fr',
		ingredients_text => 'huiles* (tournesol*, olive vierge extra), sel marin. *issus de l\'agriculture biologique.'
	},
	{
		id => '113',
		lc => 'fr',
		ingredients_text => 'riz de Camargue (1), sel. (1): IGP : Indication Géographique Protégée.'
	},
	{
		id => '114',
		lc => 'fr',
		ingredients_text =>
			'cacao (1), sucre (2), beurre de cacao (1). (1) : Commerce équitable. (2) Issue de l\'agriculture biologique.'
	},
	{
		id => '115',
		lc => 'fr',
		ingredients_text =>
			'Céréales 63,7% (BLE complet 50,5%*, semoule de maïs*), sucre*, sirop de BLE*, cacao maigre en poudre 3,9%*, cacao en poudre 1,7%*, sel, arôme naturel. *Ingrédients issus de l\'agriculture biologique.'
	},
	{
		id => '116',
		lc => 'fr',
		ingredients_text => 'émulsifiant : mono - et diglycérides d\'acides gras.'
	},
	{
		id => '117',
		lc => 'fr',
		ingredients_text => 'Sucre. Fabriqué dans un atelier qui utilise des fruits à coques.'
	},
	{
		id => '118',
		lc => 'fr',
		ingredients_text => 'Sucre. Fabriqué dans un atelier utilisant des fruits à coques et du sésame.'
	},
	{
		id => '119',
		lc => 'fr',
		ingredients_text => 'Sucre. Fabriqué dans un atelier qui manipule du lait, de la moutarde et du céleri.'
	},
	{
		id => '120',
		lc => 'fr',
		ingredients_text => 'Sucre. Peut contenir des fruits à coques et du sésame.'
	},
	{
		id => '121',
		lc => 'en',
		ingredients_text => 'vegetable oil (coconut & rapeseed)'
	},
	{
		id => '122',
		lc => 'fr',
		ingredients_text => 'Masse de cacao°, Quinoa° (1,8%). °Produits issus de l\'agriculture biologique.'
	},
	{
		id => '123',
		lc => 'de',
		ingredients_text => 'Emulgator (Sojalecithine, Mono - und Diglyceride von Speisefettsäuren, Sorbitantristearat)'
	},
	{
		id => '124',
		lc => 'fr',
		ingredients_text => 'Tomates* (20%). *Ingrédients Bio'
	},
	{
		id => '125',
		lc => 'fr',
		ingredients_text => 'Tomates* (20%). *Ingrédients biologiques'
	},
	{
		id => '126',
		lc => 'fr',
		ingredients_text =>
			'Chocolat. Contient du lait et des noisettes. Peut contenir du blé, du soja et des crustacés.'
	},
	{
		id => '127',
		lc => 'en',
		ingredients_text => 'Chocolate. Contains milk, hazelnuts and other nuts. May contain celery and mustard.'
	},
	{
		id => '128',
		lc => 'fr',
		ingredients_text =>
			'phosphates d\'ammonium et de calcium, Phosphate d\'aluminium et de sodium, diphosphate d\'aluminium et de sodium'
	},
	{
		id => '129',
		lc => 'fr',
		ingredients_text => 'Ingrédient(s) : lentilles vertes* - *issu(e)(s) de l\'agriculture biologique.'
	},
	{
		id => '130',
		lc => 'en',
		ingredients_text => 'S. thermophilus, L casei, L.bulgaricus'
	},
	{
		id => '131',
		lc => 'fr',
		ingredients_text =>
			'jus de citron*. *Ingrédients issus de l\'agriculture biologique Peut contenir : œuf, moutarde, graine de sésame, poisson,soja, lait,fruits à coque, céleri.'
	},
	{
		id => '132',
		lc => 'fr',
		ingredients_text =>
			'Farine, levure. Peut contenir des traces de _soja_, _amandes_, _noisettes_ et _noix de cajou_.'
	},
	{
		id => '133',
		lc => 'es',
		ingredients_text => 'Agua, aceite de girasol*. * Ingredientes ecológicos.'
	},
	{
		id => '134',
		lc => 'es',
		ingredients_text => 'Agua, aceite de girasol*, arroz* (5 %). (*) Ingredientes ecológicos.'
	},
	{
		id => '135',
		lc => 'es',
		ingredients_text =>
			'Tofu* 88% (agua, habas de soja*). *cumple con el reglamento de agricultura ecológica CE 2092/91'
	},
	{
		id => '136',
		lc => 'es',
		ingredients_text => 'agua, almendra* (5,5%). *= procedentes de la agricultura ecológica'
	},
	{
		id => '137',
		comment => "test for bug #3273 that introduced unwanted separators before natural flavor",
		lc => 'en',
		ingredients_text => 'non-gmo natural flavor'
	},
	{
		id => '138',
		lc => 'en',
		ingredients_text => 'vit. e, vitamins b2, B3 and K, vit d, vit a & c, vit. B12'
	},
	{
		id => '139',
		lc => 'fr',
		ingredients_text => 'vit. pp, vit c, vit. a et b6'
	},
	{
		id => '140',
		lc => 'pl',
		ingredients_text => 'witaminy A i D'
	},
	{
		id => '141',
		lc => 'fr',
		ingredients_text =>
			'colorant de surface : caramel ordinaire, agent de traitement de farine (E300), acide citrique'
	},
	{
		id => '142',
		lc => 'es',
		ingredients_text =>
			'Agua, edulcorantes (INS420, INS 960, INS N\'952, INS N°954, INS°950, INS N 955), conservantes (INS.218, INS #202, INS N 216).'
	},
	# Spanish Vitamin E can be mistaken for "e" meaning "and"
	{
		id => '143',
		lc => 'es',
		ingredients_text => 'Vitamina E y C'
	},
	{
		id => '144',
		lc => 'es',
		ingredients_text => 'color E 124'
	},
	{
		id => '145',
		lc => 'es',
		ingredients_text => 'colores E (124, 125)'
	},
	{
		id => '146',
		lc => 'it',
		ingredients_text => 'vitamine A, B, E e K'
	},
	# Additives normalization
	{
		id => '147',
		lc => 'en',
		ingredients_text => 'E 102, E-104 color, E-101(i), E101 (ii), E160a(iv), e172-i, E-160 i'
	},
	{
		id => '148',
		lc => 'fr',
		ingredients_text => 'E102-E1400'
	},
	{
		id => '149',
		lc => 'de',
		ingredients_text => 'E172i-E174ii, E102(i)-E101i'
	},
	{
		id => '150',
		lc => 'fr',
		ingredients_text => 'correcteurs d\'acidité : E322/E333 E474-E475'
	},
	{
		id => '151',
		lc => 'es',
		ingredients_text => 'E-330; E-331; Estabilizantes (E-327; E-418)'
	},
	{
		id => '152',
		lc => 'es',
		ingredients_text => 'E120 color'
	},
	{
		id => '153',
		lc => 'es',
		ingredients_text => 'E172-i'
	},
	{
		id => '154',
		lc => 'es',
		ingredients_text => 'E172 i'
	},
	{
		id => '155',
		lc => 'es',
		ingredients_text => '(E172i)'
	},
	{
		id => '156',
		lc => 'es',
		ingredients_text => 'E102(i)-E101i'
	},
	{
		id => '157',
		lc => 'es',
		ingredients_text => 'E102(i)'
	},
	{
		id => '158',
		lc => 'es',
		ingredients_text => 'S.I.N.:160 b'
	},
	{
		id => '159',
		lc => 'pt',
		ingredients_text => 'estabilizadores (E 422, E 412)'
	},
	{
		id => '160',
		lc => 'es',
		ingredients_text => 'contiene apio y derivados de leche'
	},
	{
		id => '161',
		lc => 'fr',
		ingredients_text => 'E160a(ii)'
	},
	{
		id => '162',
		lc => 'fr',
		ingredients_text => '(E160a-ii)'
	},
	{
		id => '163',
		lc => 'fr',
		ingredients_text => 'colorant (E160a(ii))'
	},
	{
		id => '164',
		comment => "# do not separate acide acétique into acide : acétique",
		lc => 'fr',
		ingredients_text => 'Esters glycéroliques de l\'acide acétique et d\'acides gras'
	},
	{
		id => '165',
		lc => 'fr',
		ingredients_text => 'acide acétique'
	},
	# russian abbreviations
	{
		id => '166',
		lc => 'ru',
		ingredients_text => 'мука пшеничная х/п в/с'
	},
	# w/ with and w/o without abbreviations
	{
		id => '167',
		lc => 'en',
		ingredients_text => 'Organic garbanzo beans (cooked w/o salt), water'
	},
	{
		id => '168',
		lc => 'en',
		ingredients_text => 'sugar, cocoa (processed w/alkali), egg yolk'
	},
	# * ingrédient issu..
	{
		id => '169',
		lc => 'fr',
		ingredients_text => 'LAIT entier pasteurisé*. *ingrédient issu de l\'agriculture biologique.'
	},
	{
		id => '170',
		lc => 'fr',
		ingredients_text => 'vitamines B1, B6, B9, PP et E'
	},
	{
		id => '171',
		lc => 'fr',
		ingredients_text => 'vitamines (B1, acide folique (B9))'
	},
	# (origins, contains milk)
	{
		id => '172',
		lc => 'en',
		ingredients_text => 'Chocolate (Italy, contains milk)'
	},
	{
		id => '173',
		lc => 'en',
		ingredients_text => 'Chocolate (contains milk)'
	},
	{
		id => '174',
		lc => 'en',
		ingredients_text => 'Chocolate. Contains (milk)'
	},
	# ¹ and ² symbols
	{
		id => '175',
		lc => 'fr',
		ingredients_text =>
			'Sel, sucre², graisse de palme¹, amidons¹ (maïs¹, pomme de terre¹), oignon¹ : 8,9%, ail¹, oignon grillé¹ : 1,4%, épices¹ et aromate¹ (livèche¹ : 0,4%, curcuma¹, noix de muscade¹), carotte¹ : 0,5%. Peut contenir : céleri, céréales contenant du gluten, lait, moutarde, œuf, soja. ¹Ingrédients issus de l\'Agriculture Biologique. ² Ingrédients issus du commerce équitable'
	},
	{
		id => '176',
		comment => "# Russian е character",
		lc => 'ru',
		ingredients_text => 'е322, Куркумины e100, е-1442, (е621)'
	},
	# New ingredients categories + types : generalized from French to other languages
	{
		id => '177',
		lc => 'fr',
		ingredients_text => 'huiles végétales (palme, olive et tournesol)'
	},
	{
		id => '178',
		lc => 'fr',
		ingredients_text => 'huile végétale : colza'
	},
	{
		id => '179',
		lc => 'fr',
		ingredients_text => 'huile végétale : colza, fraises'
	},
	{
		id => '180',
		lc => 'fr',
		ingredients_text => 'huile végétale : colza et tomates'
	},
	{
		id => '181',
		lc => 'en',
		ingredients_text => 'vegetable oil: sunflower'
	},
	{
		id => '182',
		lc => 'en',
		ingredients_text => 'vegetable oil (palm)'
	},
	{
		id => '183',
		lc => 'en',
		ingredients_text => 'vegetable oils (palm, olive)'
	},
	{
		id => '184',
		lc => 'en',
		ingredients_text => 'organic vegetable oils (sunflower, colza and rapeseed)'
	},
	# used to have bad output: sunflower vegetable oils, colza vegetable oilsand strawberry
	{
		id => '185',
		lc => 'en',
		ingredients_text => 'vegetable oils : sunflower, colza and strawberry'
	},
	# Polish oils
	{
		id => '186',
		lc => 'pl',
		ingredients_text => 'oleje roślinne (słonecznikowy)'
	},
	{
		id => '187',
		lc => 'pl',
		ingredients_text => 'oleje roślinne: słonecznikowy'
	},
	{
		id => '188',
		lc => 'pl',
		ingredients_text => 'oleje roślinne (słonecznikowy, rzepakowy)'
	},
	{
		id => '189',
		lc => 'pl',
		ingredients_text => 'oleje roślinne (sojowy, słonecznikowy, kokosowy, rzepakowy) w zmiennych proporcjach'
	},
	# Polish meats
	{
		id => '190',
		lc => 'pl',
		ingredients_text => 'tłuszcze roślinne (palmowy nieutwardzony, shea)'
	},
	# Polish juices and concentrates
	{
		id => '191',
		lc => 'pl',
		ingredients_text => 'tłuszcze roślinne (kokosowy i palmowy) w zmiennych proporcjach'
	},
	{
		id => '192',
		lc => 'pl',
		ingredients_text => 'mięso (wołowe, wieprzowe, cielęce)'
	},
	{
		id => '193',
		lc => 'pl',
		ingredients_text => 'przeciery z (jabłek, bananów, marchwi)'
	},
	# Russian oils (more tests needed)
	{
		id => '194',
		lc => 'ru',
		ingredients_text => 'масло (Подсолнечное)'
	},
	{
		id => '195',
		lc => 'ru',
		ingredients_text => 'Масло (подсолнечное)'
	},
	{
		id => '196',
		lc => 'ru',
		ingredients_text => 'масло растительное (подсолнечное, соевое)'
	},
	# grammes -> g
	{
		id => '197',
		lc => 'fr',
		ingredients_text => 'Teneur en fruits: 50gr pour 100 grammes'
	},
	# test conflicts between the word "and" in some languages and additives variants. With letters i or e or a.
	{
		id => '198',
		lc => 'hr',
		ingredients_text => 'bojilo: E 150a, tvari za rahljenje: E 500 i E 503, sol.'
	},
	{
		id => '199',
		lc => 'hr',
		ingredients_text => 'bojilo: E 150a, tvari za rahljenje: E 500 i, E 503, sol.'
	},
	{
		id => '200',
		lc => 'hr',
		ingredients_text => 'bojilo: E 150a, tvari za rahljenje: E 500(i), E 503, sol.'
	},
	{
		id => '201',
		lc => 'hr',
		ingredients_text => 'bojilo: E 150a, tvari za rahljenje: E 500i, E 503, sol.'
	},
	{
		id => '202',
		lc => 'it',
		ingredients_text => 'formaggio, E 472 e, E470a.'
	},
	{
		id => '203',
		lc => 'it',
		ingredients_text => 'formaggio, E 472 e E470a.'
	},
	{
		id => '204',
		lc => 'sk',
		ingredients_text => 'syr, E470 a E470a, mlieko.'
	},
	# normalize category and types
	{
		id => '205',
		lc => 'fr',
		ingredients_text => 'Piments (vert, rouge, jaune)'
	},
	{
		id => '206',
		lc => 'de',
		ingredients_text => 'pflanzliches Fett (Kokosnuss, Palmkern)'
	},
	{
		id => '207',
		lc => 'de',
		ingredients_text => 'pflanzliche Öle und Fette (Raps, Palm, Shea, Sonnenblumen)'
	},
	{
		id => '208',
		lc => 'fr',
		ingredients_text => 'Huiles végétales de palme, de colza et de tournesol'
	},
	{
		id => '209',
		lc => 'fr',
		ingredients_text => 'arôme naturel de pomme avec d\'autres âromes'
	},
	{
		id => '210',
		lc => 'fr',
		ingredients_text => 'Carbonate de magnésium, fer élémentaire'
	},
	{
		id => '211',
		lc => 'fr',
		ingredients_text => 'huile végétale (colza)'
	},
	{
		id => '212',
		lc => 'fr',
		ingredients_text => 'huile végétale : colza'
	},
	{
		id => '213',
		lc => 'hr',
		ingredients_text => 'ječmeni i pšenični slad'
	},
	{
		id => '214',
		lc => 'hr',
		ingredients_text => 'ječmeni, ječmeni i pšenični slad'
	},
	{
		id => '215',
		lc => 'hr',
		ingredients_text => 'Pasterizirano mlijeko (s 1.0% mliječne masti)'
	},
	{
		id => '216',
		lc => 'en',
		ingredients_text => 'Vegetal oil (sunflower, olive and palm)'
	},
	{
		id => '217',
		lc => 'en',
		ingredients_text => 'vegetable oil (palm)'
	},
	{
		id => '218',
		lc => 'en',
		ingredients_text => 'vegetable oil: palm'
	},
	{
		id => '219',
		lc => 'fr',
		ingredients_text => 'protéines végétales (soja, blé)'
	},
	{
		id => '220',
		lc => 'de',
		ingredients_text => 'pflanzliche Proteine (Erbsen, Sonnenblumen)'
	},
	# Should not develop the enumeration if it contains unknown types (like "sel" here)
	{
		id => '221',
		lc => 'fr',
		ingredients_text => 'Piments (vert, rouge, jaune, sel)'
	},
	{
		id => '222',
		lc => 'fr',
		ingredients_text => 'Huile de palme, noisettes et tournesol'
	},
	{
		id => '223',
		lc => 'fr',
		ingredients_text => 'Huile de palme, noisettes'
	},
	{
		id => '224',
		lc => 'fr',
		ingredients_text => 'arôme naturel de citron, citron vert et d\'autres agrumes'
	},
	{
		id => '225',
		lc => 'fr',
		ingredients_text => 'Huiles végétales (colza, palme)',
	},
	{
		id => '226',
		lc => 'fr',
		ingredients_text => 'Huiles végétales 54.5% (colza, palme)',
	},
	{
		id => '227',
		lc => 'fr',
		ingredients_text => 'Huiles végétales non hydrogénées (colza, palme)',
	},
	{
		id => '228',
		lc => 'fr',
		ingredients_text => 'Huiles végétales bio (olive, palme, tournesol)',
	},
	{
		id => '229',
		lc => 'ru',
		ingredients_text => 'Масло (Пальмовое), масло растительное (подсолнечное, соевое)',
	},
	# additive class + additive
	# émulsifiant e471, émulsifiant lécithine de soja
	{
		id => '230',
		lc => 'fr',
		ingredients_text =>
			'émulsifiant e471, émulsifiant lécithine de soja, acidifiant acide citrique, acidifiant e330, emulsifiant lecithine de tournesol, émulsifiant lécithine',
	},
);

foreach my $test_ref (@tests) {

	my $testid = $test_ref->{id};
	my $l = $test_ref->{lc};    # Language
	my $ingredients_text = $test_ref->{ingredients_text};
	my $preparsed = preparse_ingredients_text($l, $ingredients_text);
	$test_ref->{preparsed_ingredients_text} = $preparsed;

	compare_to_expected_results($test_ref, "$expected_result_dir/$testid.json", $update_expected_results);
}

done_testing();
