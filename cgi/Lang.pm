# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2015 Association Open Food Facts
# Contact: contact@openfoodfacts.org
# Address: 21 rue des Iles, 94100 Saint-Maur des Fossés, France
#
# Product Opener is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

package Blogs::Lang;

BEGIN
{
	use vars       qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	require Exporter;
	@ISA = qw(Exporter);
	@EXPORT = qw();	# symbols to export by default
	@EXPORT_OK = qw(

					$lang
					$langlang

					$lc
					$lclc

					%tag_type_singular
					%tag_type_from_singular
					%tag_type_plural
					%tag_type_from_plural
					%Lang
					%CanonicalLang
					%Langs
					@Langs

					&lang
					%lang_lc


					);	# symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;
use strict;
use utf8;

use Blogs::SiteLang qw/:all/;

use Blogs::Store qw/:all/;



%lang_lc = (
ar => 'ar',
de => 'de',
cs => 'cs',
es => 'es',
en => 'en',
it => 'it',
fi => 'fi',
fr => 'fr',
el => 'el',
he => 'he',
ja => 'ja',
ko => 'ko',
nl => 'nl',
nl_be => 'nl_be',
ru => 'ru',
pl => 'pl',
pt => 'pt',
pt_pt => 'pt_pt',
ro => 'ro',
th => 'th',
vi => 'vi',
zh => 'zh',
);

%Langs = (
'ar'=>'العربية',
'da'=>'Dansk',
'de'=>'Deutsch',
'es'=>'Español',
'en'=>'English',
'it'=>'Italiano',
'fi'=>'Suomi',
'fr'=>'Français',
'el'=>'Ελληνικά',
'he'=>'עברית',
'ja'=>'日本語',
'ko'=>'한국어',
'nl'=>'Nederlands',
'nl_be' => 'Nederlands',
'ru'=>'Русский',
'pl'=>'Polski',
'pt'=>'Português',
'pt_pt'=>'Português',
'ro' => 'Română',
'th' => 'ไทย',
'vi'=>'Tiếng Việt',
'zh'=>'中文',
);

@Langs = sort keys %Langs;


# Tags types to path components in URLS: in ascii, lowercase, unaccented, transliterated (in Roman characters)

# Please do not add accents and caps in the strings below.

%tag_type_singular = (
products => {
	fr => 'produit',
	de => 'produkt',
	en => 'product',
	el => 'προιον',
	es => 'producto',
	it => 'prodotto',
#	ru => 'продукт',
    ro => 'produs',
	ar => 'mountaj',
	pt => 'produto',
	he => 'mozar',
	nl => 'product',
	nl_be => 'product',
},
brands => {
	fr => 'marque',
	de => 'marke', # lowercase for URLs
	en => 'brand',
	es => 'marca',
	el => 'μαρκα',
	it => 'marca',
	ro => 'marca',
#	ru => 'марка',
	ar => '3alama-tijariya', # need to be in ascii: letters A to Z
	pt => 'marca',
	he => 'mutag',
	nl => 'merk',
	nl_be => 'merk',
},
categories => {
	fr => 'categorie',
	de => 'kategorie',
	en => 'category',
	es => 'categoria',
	el => 'κατηγορια',
	it => 'categoria',
	ro => 'categorie',
#	ru => 'категория',
	ar => 'atassnifate',
	pt => 'categoria',
	he => 'categoria',
	nl => 'categorie',
	nl_be => 'categorie',
},
pnns_groups_1 => {
	en => 'pnns-group-1',
},
pnns_groups_2 => {
	en => 'pnns-group-2',
},
packaging => {
	fr => 'conditionnement',
	de => 'verpackung',
	en => 'packaging',
	es => 'envase',
	el => 'συσκευασια',
	it => 'imballaggio',
	ro => 'ambalaj',
#	ru => 'упаковка',
	ar => 'ata3bia',
	pt => 'embalagem',
	he => 'ariza',
	nl => 'verpakking',
	nl_be => 'verpakking',
},
emb_codes => {
	fr => 'code-emballeur',
	de => 'produzenten-code',
	en => 'packager-code',
	es => 'codigo-de-envasador',
	el => 'κωδικός συσκευαστη',
	it => 'codice-imballaggio',
	ro => 'cod-de-ambalare',
#	ru => 'код',
	ar => 'ramz-el-mou3abi',
	pt => 'codigo-do-empacotador',
	pt_pt => 'codigo-de-embalador',
	he => 'cod-emb',
	nl => 'verpakkerscode',
	nl_be => 'verpakkerscode',
},
cities => {
	fr => 'commune',
	de => 'stadt',
	en => 'city',
	it => 'citta',
	es => 'ciudad',
	el => 'πολη',
	ro => 'oras',
#	ru => 'город',
	ar => 'almoudoun',
	pt => 'cidade',
	he => 'ir',
	nl => 'stad',
	nl_be => 'stad',
},
origins => {
	fr => 'origine',
	de => 'herkunft',
	en => 'origin',
	el => 'προελευση',
	it => 'origine',
	es => 'origen',
	ro => 'provenienta',
#	ru => 'источник',
	ar => 'almassdar',
	pt => 'origem',
	he => 'makor',
	nl => 'herkomst',
	nl_be => 'herkomst',
},
manufacturing_places => {
	fr => 'lieu-de-fabrication',
	de => 'herstellungsort',
	en => 'manufacturing-place',
	es => 'lugar-de-fabricacion',
	el => 'τοπος παρασκευης',
	pt_pt => 'local-de-fabrico',
	ro => 'locatia-de-fabricatie',
	nl => 'productielocatie',
	nl_be => 'productielocatie',
},
purchase_places => {
	fr => 'lieu-de-vente',
	de => 'verkaufsort',
	en => 'purchase-place',
	el => 'τοπος αγορας',
	it => 'luogo-d-acquisto',
	es => 'sitio-de-compra',
	ro => 'locatia-de-achizitie',
#	ru => 'где-куплено',
	ar => 'nikate-alBay3',
	pt => 'local-de-compra',
	he => 'mekom-harekhisha',
	nl => 'verkooplocatie',
	nl_be => 'verkooplocatie',
},
stores => {
	fr => 'magasin',
	de => 'geschaeft',
	en => 'store',
	it => 'negozio',
	el => 'καταστημα',
	es => 'tienda',
	ro => 'magazin',
#	ru => 'магазин',
	ar => 'almatajir',
	pt => 'loja',
	he => 'khanut',
	nl => 'winkel',
	nl_be => 'winkel',
},
countries => {
	fr => 'pays',
	de => 'land',
	en => 'country',
	el => 'χωρα',
	es => 'pais',
	he => 'medina',
	pt => 'país',
	ro => 'tara',
	nl => 'land',
	nl_be => 'land',
},
ingredients => {
	fr => 'ingredient',
	de => 'zutat',
	en => 'ingredient',
	es => 'ingrediente',
	el => 'συστατικο',
	it => 'ingrediente',
	ro => 'ingredient',
#	ru => 'состав',
	ar => 'almoukawinate',
	pt => 'ingrediente',
	he => 'markivim',
	nl => 'ingrediënt',
	nl_be => 'ingrediënt',
},
labels => {
	fr => 'label',
	de => 'label',
	en => 'label',
	el => 'ετικετα',
	es => 'etiqueta',
	it => 'etichetta',
    ro => 'eticheta',
#	ru => 'этикетка',
	ar => 'al3alama',
	pt => 'etiqueta',
	he => 'tavit',
	nl => 'keurmerk',
	nl_be => 'label',
},
nutriments => {
	fr => 'nutriment',
	de => 'naehrstoff',
	en => 'nutrient',
	el => 'θρεπτικο συστατικο',
	es => 'nutriente',
	it => 'nutriente',
	ro => 'nutriente',
#	ru => 'пищевая-ценность',
	ar => 'ghithae',
	pt => 'nutriente',
	he => 'arakhim-tzunatiyim',
	nl => 'voedingsstof',
	nl_be => 'voedingsstof',
},
traces => {
	fr => 'trace',
	de => 'spur',
	en => 'trace',
	es => 'traza',
	el => 'ιχνος',
	it => 'traccia',
	ro => 'urma',
#	ru => 'содержит',
	ar => 'athar',
	pt => 'traco',
	pt_pt => 'vestigio',
	he => 'ikvot',
	nl => 'spoor',
	nl_be => 'spoor',
},
users => {
	fr => 'contributeur',
	de => 'beitragszahler',
	en => 'contributor',
	es => 'contribuyente',
	el => 'συντελεστης',
	it => 'contributore',
	ro => 'contributor',
#	ru => 'участник',
	ar => 'almousstakhdimoun',
	pt => 'colaborador',
	he => 'torem',
	nl => 'gebruiker',
	nl_be => 'gebruiker',
},
photographers => {
	fr => 'photographe',
	de => 'fotograf',
	en => 'photographer',
	el => 'φωτογραφος',
	ar => 'moussawir' ,
	pt => 'fotografo',
	ro => 'fotograf',
	es => 'fotografo',
	he => 'tzalam',
	nl => 'fotograaf',
	nl_be => 'fotograaf',
},
editors => {
	fr => 'editeur',
	en => 'editor',
},
informers => {
	fr => 'informateur',
	de => 'informant',
	en => 'informer',
	el => 'πληροφοριοδοτης',
	ar => 'moukhbir',
	pt => 'informante',
	pt_pt => 'informador',
	ro => 'informator',
	es => 'informante',
	he => 'meyadea',
	nl => 'informant',
	nl_be => 'informant',
},
correctors => {
	fr => 'correcteur',
	de => 'korrekteur',
	en => 'corrector',
	ar => 'moussahih',
	el => 'διορθωτης',
	pt => 'corretor',
	pt_pt => 'revisor',
	ro => 'corector',
	es => 'corrector',
	he => 'metaken',
	nl => 'corrector',
	nl_be => 'corrector',
},
checkers => {
	fr => 'verificateur',
	de => 'pruefer',
	en => 'checker',
	el => 'ελεγκτης',
	ar => 'mourakib',
	pt => 'verificador',
	ro => 'verificator',
	es => 'verificador',
	he => 'bodek',
	nl => 'verificateur',
	nl_be => 'verificateur',
},
states => {
	fr => 'etat',
    de => 'status',
	en => 'state',
	el => 'κατασταση',
#	ar => 'الحاله',
	pt => 'estado',
	ro => 'status',
	es => 'estado',
	he => 'matzav',
	nl => 'status',
	nl_be => 'status',
},
additives => {
	fr => 'additif',
	de => 'zusatzstoff',
	en => 'additive',
	es => 'aditivo',
	el => 'προσθετο',
	it => 'additivo',
	ro => 'aditiv',
#	ru => 'добавка',
	ar => 'mouthafat',
	pt => 'aditivo',
	he => 'tosefet',
	nl => 'additief',
	nl_be => 'additief',
},
ingredients_from_palm_oil => {
	fr => "ingredients-issus-de-l-huile-de-palme",
	de => "zutaten-aus-palmoel",
	en => "ingredients-from-palm-oil",
	el => 'συστατικα απο φοινικελαιο',
	ro => 'ingrediente-din-ulei-de-palmier',
#	ru => "вещества-из-пальмового-масла",
	ar => 'mawad-mousstakhraja-min-zayt-nakhil',
	pt => 'ingredientes-de-oleo-de-palma',
	es => 'ingredientes-con-aceite-de-palma',
	he => 'rekhivim-mishemen-dkalim',
	nl => 'ingredienten-uit-palmolie',
	nl_be => 'ingredienten-uit-palmolie',
},
ingredients_that_may_be_from_palm_oil => {
	fr => "ingredients-pouvant-etre-issus-de-l-huile-de-palme",
	de => "zutaten-die-möglicherweise-palmoel-beinhalten",
	en => "ingredients-that-may-be-from-palm-oil",
	el => 'συστατικα ισως προερχομενα απο φοινικελαιο',
	ro => 'ingerdiente-care-ar-putea-fi-din-ulei-de-palmier',
#	ru => "вещества-возможно-из-пальмового-масла",
	ar => 'mawad-kad-takoun-mousstakhraja-mina-nakhil',
	pt => 'ingredientes-que-podem-ser-de-oleo-de-palma',
	es => 'ingredientes-que-pueden-proceder-de-aceite-de-palma',
	he => 'rekhivim-sheasuyim-lihiyot-mishemen-dkalim',
	nl => 'ingredienten-die-mogelijk-palmolie-bevatten',
	nl_be => 'ingredienten-die-mogelijk-palmolie-bevatten',

},
allergens => {
	fr => 'allergene',
	de => 'allergen',
	en => 'allergen',
	es => 'alergeno',
	el => 'αλλεργιογονο',
	it => 'allergene',
	ro => 'alergen',
	ru => 'аллерген',
	ar => 'moussabib-hassassiya',
	pt => 'alergenico',
	he => 'khomer-alergeni',
	nl => 'allergeen',
	nl_be => 'allergeen',
},
missions => {
	fr => 'mission',
	en => 'mission',
	es => 'mision',
	el => 'αποστολη',
	de => 'mission',
	it => 'scopo',
	ro => 'misiune',
#	ru => 'назначение',
	ar => 'mouhima',
	pt => 'missao',
	he => 'messima',
	nl => 'missie',
	nl_be => 'missie',
},
nutrient_levels => {
	en => 'nutrient-level',
	de => 'naehrwert-stufe',
	fr => 'repere-nutritionnel',
	es => 'valor-nutricional',
	el => 'επιπεδο θρεπτικων ουσιων',
	he => 'ramat-khomrey-hamazon',
	pt => 'nivel-nutricional',
	ro => 'valoare-nutritionala',
	nl => 'voedingswaarde',
	nl_be => 'nutritionele waarde',
},
known_nutrients => {
	en => 'known-nutrient',
	de => 'bekannte-naehrwerte',
	fr => 'nutriment-connu',
	es => 'nutriente-conocido',
	el => 'γνωστη θρεπτικη ουσια',
	pt => 'nutriente-conhecido',
	he => 'khomrey-mazon-yeduim',
	ro => 'nutrienti-cunoscuti',
	nl => 'bekende-ingredienten',
	nl_be => 'gekende-ingredienten',
},
unknown_nutrients => {
	en => 'unknown-nutrient',
	de => 'unbekannte-naehrwerte',
	fr => 'nutriment-inconnus',
	es => 'nutriente-desconocido',
	el => 'αγνωστη θρεπτικη ουσια',
	pt => 'nutriente-desconhecido',
	he => 'khmorey-mazon-bilti-yeduim',
	ro => 'nutrienti-necunoscuti',
	nl => 'onbekende-ingredienten',
	nl_be => 'onbekende-ingredienten',
},
entry_dates => {
	en => "entry-date",
	fr => "date-d-ajout",
	el => "ημερομηνια εισαγωγης",
	nl => "datum-toegevoegd",
	nl_be => "datum-toegevoegd",
},
last_edit_dates => {
	en => "last-edit-date",
	fr => "date-de-derniere-modification",
	el => "ημερομηνια τελευταιας τροποποιησης",
	nl => "datum-laatste-wijziging",
	nl_be => "datum-laatste-wijziging",
},
nutrition_grades => {
	en => "nutrition-grade",
	fr => "note-nutritionnelle",
	el => "επιπεδο/βαθμολογια θρεπτικοτητας",
	nl => "voedingsgraad",
	nl_be => "voedingsgraad",
},

# do not translate code and debug
codes => {
	en => "code",
},

debug => {
	en => "debug",
},

# end - do not translate

);

# Note: a lot of plurals are currently missing below, commented-out are the singulars that need to be changed to plurals

# Please do not add accents and caps in the strings below.

%tag_type_plural = (
products => {
	fr => 'produits',
	de => 'produkte',
	el => 'προιοντα',
	en => 'products',
	es => 'productos',
	it => 'prodotti',
#	ar => 'mountaj',
	pt => 'produtos',
	ro => 'produse',
#	he => 'mozar',
	nl => 'producten',
	nl_be => 'producten',
},
brands => {
	fr => 'marques',
	de => 'marken',
	en => 'brands',
	es => 'marcas',
	el => 'μαρκες',
	it => 'marcas',
	ro => 'marci',
#	ru => 'марка',
#	ar =>'3alama-tijariya', # need to be in ascii: letters A to Z
	pt => 'marcas',
#	he => 'mutag',
	nl => 'merken',
	nl_be => 'merken',
},
categories => {
	fr => 'categories',
	de => 'kategorien',
	en => 'categories',
	es => 'categorias',
	el => 'κατηγοριες',
	it => 'categorias',
#	ru => 'категория',
    ro => 'categorii',
#	ar =>  'atassnifate',
	pt => 'categorias',
#	he => 'categoria',
	nl => 'categorieën',
	nl_be => 'categorieën',
},
pnns_groups_1 => {
	en => 'pnns-groups-1',
},
pnns_groups_2 => {
	en => 'pnns-groups-2',
},
packaging => {
	fr => 'conditionnements',
	de => 'verpackungen',
	en => 'packaging',
	el => 'συσκευασιες',
	es => 'envase',
#	it => 'imballaggio',
#	ru => 'упаковка',
#	ar => 'ata3bia',
	pt => 'embalagens',
#	he => 'ariza',
	ro => 'ambalaje',
	nl => 'verpakkingen',
	nl_be => 'verpakkingen',
},
emb_codes => {
	fr => 'codes-emballeurs',
	de => 'produzenten-codes',
	en => 'packager-codes',
	el => 'κωδικοι συσκευαστη',
	es => 'codigos-de-envasadores',
#	it => 'codice-imballaggio',
#	ru => 'код',
#	ar => 'ramz-el-mou3abi',
	pt => 'codigos-do-empacotador',
	pt_pt => 'codigos-de-embalador',
	ro => 'coduri-de-ambalare',
#	he => 'cod-emb',
	nl => 'verpakkerscodes',
	nl_be => 'verpakkerscodes',
},
cities => {
	fr => 'communes',
	de => 'staedte',
	en => 'cities',
	el => 'πολεις',
#	it => 'citta',
	es => 'ciudades',
#	ru => 'город',
#	ar => 'almoudoun',
	pt => 'cidades',
	ro => 'orase',
#	he => 'ir',
	nl => 'steden',
	nl_be => 'steden',
},
origins => {
	fr => 'origines',
	de => 'herkuenfte',
	en => 'origins',
	el => 'προελευσεις',
#	it => 'origine',
	es => 'origenes',
#	ru => 'источник',
#	ar => 'almassdar',
	pt => 'origens',
	ro => 'origini',
#	he => 'makor',
	nl => 'herkomst',
	nl_be => 'herkomst',
},
manufacturing_places => {
	fr => 'lieux-de-fabrication',
	de => 'herstellungsorte',
	en => 'manufacturing-places',
	el => 'τοποι παρασκευης',
	es => 'lugares-de-fabricacion',
	pt_pt => 'locais-de-fabrico',
	ro => 'locatii-de-fabricare',
	nl => 'productielocaties',
	nl_be => 'productielocaties',
},
purchase_places => {
	fr => 'lieux-de-vente',
	de => 'verkaufsorte',
	en => 'purchase-places',
	el => 'τοποι αγορας',
#	it => 'luogo-d-acquisto',
	es => 'sitios-de-compra',
#	ru => 'где-куплено',
#	ar => 'nikate-alBay3',
	pt => 'locais-de-compra',
#	he => 'mekom-harekhisha',
	ro => 'locatii-de-achizitie',
	nl => 'verkooplocaties',
	nl_be => 'verkooplocaties',
},
stores => {
	fr => 'magasins',
	de => 'geschaefte',
	en => 'stores',
	el => 'καταστηματα',
#	it => 'negozio',
	es => 'tiendas',
#	ru => 'магазин',
#	ar => 'almatajir',
	pt => 'lojas',
#	he => 'khanut',
	ro => 'magazine',
	nl => 'winkels',
	nl_be => 'winkels',
},
countries => {
	fr => 'pays',
	de => 'länder',
	en => 'countries',
	es => 'paises',
	el => 'χωρες',
	he => 'medina',
	pt => 'paises',
	ro => 'tari',
	nl => 'landen',
	nl_be => 'landen',
},
ingredients => {
	fr => 'ingredients',
	de => 'zutaten',
	en => 'ingredients',
	el => 'συστατικα',
	es => 'ingredientes',
	it => 'ingredientes',
#	ru => 'состав',
#	ar => 'almoukawinate',
	pt => 'ingredientes',
#	he => 'markivim',
	ro => 'ingrediente',
	nl => 'ingrediënten',
	nl_be => 'ingrediënten',
},
labels => {
	fr => 'labels',
	de => 'labels',
	en => 'labels',
	el => 'ετικετες',
	es => 'etiquetas',
	it => 'etichettas',
#	ru => 'этикетка',
#	ar => 'al3alama',
	pt => 'etiquetas',
#	he => 'tavit',
	ro => 'etichete',
	nl => 'keurmerken',
	nl_be => 'labels',
},
nutriments => {
	fr => 'nutriments',
	de => 'naehrstoffe',
	en => 'nutrients',
	es => 'nutrientes',
	el => 'θρεπτικα συστατικα',
	it => 'nutrientes',
#	ru => 'пищевая-ценность',
#	ar => 'ghithae',
	pt => 'nutrientes',
#	he => 'arakhim-tzunatiyim',
	ro => 'nutrienti',
	nl => 'voedingsstoffen',
	nl_be => 'voedingsstoffen',
},
traces => {
	fr => 'traces',
	de => 'spuren',
	en => 'traces',
	el => 'ιχνη',
	es => 'trazas',
#	it => 'traccia',
#	ru => 'содержит',
#	ar => 'athar',
	pt => 'tracos',
	pt_pt => 'vestigios',
#	he => 'ikvot',
	ro => 'urme',
	nl => 'sporen',
	nl_be => 'sporen',
},
users => {
	fr => 'contributeurs',
	de => 'beitragszahler',
	en => 'contributors',
	es => 'contribuyentes',
	el => 'χρηστες',
#	it => 'contributore',
#	ru => 'участник',
#	ar => 'almousstakhdimoun',
	pt => 'colaboradores',
#	he => 'torem',
    ro => 'contributori',
	nl => 'gebruikers',
	nl_be => 'gebruikers',
},
photographers => {
	fr => 'photographes',
	de => 'fotografen',
	en => 'photographers',
	el => 'φωτογραφοι',
#	ar => 'moussawir' ,
	pt => 'fotografos',
	es => 'fotografos',
#	he => 'tzalam',
    ro => 'fotografi',
	nl => 'fotografen',
	nl_be => 'fotografen',
},
editors => {
	fr => 'editeurs',
	en => 'editors',
},
informers => {
	fr => 'informateurs',
	de => 'informanten',
	en => 'informers',
	el => 'πληροφοριοδοτες',
#	ar => 'moukhbir',
	pt => 'informantes',
	pt_pt => 'informadores',
	es => 'informantes',
#	he => 'meyadea',
    ro => 'informatori',
	nl => 'informanten',
	nl_be => 'informanten',
},
correctors => {
	fr => 'correcteurs',
	de => 'korrektoren',
	en => 'correctors',
	el => 'διορθωτες',
#	ar => 'moussahih',
	pt => 'corretores',
	pt_pt => 'revisores',
	es => 'correctores',
#	he => 'metaken',
    ro => 'corectori',
	nl => 'correctoren',
	nl_be => 'correctoren',
},
checkers => {
	fr => 'verificateurs',
	de => 'pruefer',
	en => 'checkers',
	el => 'ελεγκτες',
#	ar => 'mourakib',
	pt => 'verificadores',
	es => 'verificadores',
#	he => 'bodek',
    ro => 'verificatori',
	nl => 'verificateurs',
	nl_be => 'verificateurs',
},
states => {
	fr => 'etats',
    de => 'status',
	en => 'states',
	el => 'καταστασεις',
#	ar => 'الحاله',
	pt => 'estados',
	es => 'estados',
#	he => 'matzav',
    ro => 'statusuri',
	nl => 'statussen',
	nl_be => 'statussen',
},
additives => {
	fr => 'additifs',
	de => 'zusatzstoffe',
	en => 'additives',
	el => 'προσθετα',
	es => 'aditivos',
#	it => 'additivo',
#	ru => 'добавка',
#	ar => 'mouthafat',
	pt => 'aditivos',
#	he => 'tosefet',
    ro => 'aditivi',
	nl => 'additieven',
	nl_be => 'additieven',
},
ingredients_from_palm_oil => {
	fr => "ingredients-issus-de-l-huile-de-palme",
	de => 'zutaten-aus-Palmoel',
	el => 'συστατικα από φοινικελαιο',
	en => "ingredients-from-palm-oil",
#	ru => "вещества-из-пальмового-масла",
	ar => 'mawad-mousstakhraja-min-zayt-nakhil',
	pt => 'ingredientes-de-oleo-de-palma',
	es => 'ingredientes-con-aceite-de-palma',
	he => 'rekhivim-mishemen-dkalim',
	ro => 'ingrediente-din-ulei-de-palmier',
	nl => 'ingredienten-uit-palmolie',
	nl_be => 'ingredienten-uit-palmolie',
},
ingredients_that_may_be_from_palm_oil => {
	fr => "ingredients-pouvant-etre-issus-de-l-huile-de-palme",
	de => 'zutaten-die-möglicherweise-Palmoel-beinhalten',
	en => "ingredients-that-may-be-from-palm-oil",
	el => 'συστατικα πιθανως προερχομενα από φοινικελαιο',
#	ru => "вещества-возможно-из-пальмового-масла",
	ar => 'mawad-kad-takoun-mousstakhraja-mina-nakhil',
	pt => 'ingredientes-que-podem-ser-de-oleo-de-palma',
	es => 'ingredientes-que-pueden-proceder-de-aceite-de-palma',
	he => 'rekhivim-sheasuyim-lihiyot-mishemen-dkalim',
	ro => 'ingrediente-care-ar-putea-fi-din-ulei-de-palmier',
	nl => 'ingredienten-die-mogelijk-palmolie-bevatten',
	nl_be => 'ingredienten-die-mogelijk-palmolie-bevatten',
},
allergens => {
	fr => 'allergenes',
	de => 'allergene',
	en => 'allergens',
	es => 'alergenos',
	el => 'αλλεργιογονα',
#	it => 'allergene',
	ru => 'аллергены',
#	ar => 'moussabib-hassassiya',
	pt => 'alergenicos',
#	he => 'khomer-alergeni',
    ro => 'alergeni',
	nl => 'allergenen',
	nl_be => 'allergenen',
},
missions => {
	fr => 'missions',
	de => 'missionen',
	en => 'missions',
	el => 'αποστολες',
	es => 'misiones',
#	it => 'scopo',
#	ru => 'назначение',
#	ar => 'mouhima',
	pt => 'missoes',
#	he => 'messima',
    ro => 'misiuni',
	nl => 'missies',
	nl_be => 'missies',
},
nutrient_levels => {
	en => 'nutrient-levels',
	de => 'naehrwert-Stufen',
	fr => 'reperes-nutritionnels',
	el => 'επιπεδα θρεπτικων ουσιων',
	es => 'valores-nutricionales',
#	he => 'ramat-khomrey-hamazon',
	pt => 'valores-nutricionais',
	ro => 'valori-nutritionale',
	nl => 'voedingswaarden',
	nl_be => 'nutritionele waarden',
},
known_nutrients => {
	en => 'known-nutrients',
	de => 'bekannte-Naehrwerte',
	fr => 'nutriments-connus',
	el => 'γνωστες θρεπτικες ουσιες',
	es => 'nutrientes-conocidos',
	pt => 'nutrientes-conhecidos',
	he => 'khomrey-mazon-yeduim',
	ro => 'nutrienti-cunoscuti',
	nl => 'bekende ingrediënten',
	nl_be => 'gekende ingrediënten',
},
unknown_nutrients => {
	en => 'unknown-nutrients',
	de => 'unbekannte-Naerhwerte',
	fr => 'nutriments-inconnus',
	el => 'αγνωστες θρεπτικες ουσιες',
	es => 'nutrientes-desconocidos',
	pt => 'nutrientes-desconhecidos',
	he => 'khmorey-mazon-bilti-yeduim',
	ro => 'nutrienti-necunoscuti',
	nl => 'onbekende ingredienten',
	nl_be => 'onbekende ingredienten',
},
entry_dates => {
	en => "entry-dates",
	fr => "dates-d-ajout",
	el => "ημερομηνιες εισαγωγης",
	nl => "toevoeg-datums",
	nl_be => "toevoeg-datums",
},
last_edit_dates => {
	en => "last-edit-dates",
	fr => "dates-de-derniere-modification",
	el => "ημερομηνιες τελευταιας τροποποιησης",
	nl => "laatste-wijziging-datums",
	nl_be => "laatste-wijziging-datums",
},
nutrition_grades => {
	en => "nutrition-grades",
	fr => "notes-nutritionnelles",
	el => "επιπεδα/βαθμολογιες θρεπτικοτητας",
	nl => "voedingsgraden",
	nl_be => "voedingsgraden",
},
# do not translate code and debug
codes => {
	en => "codes",
},

debug => {
	en => "debug",
},
);


# Below this point, non-Roman characters can be used

%Lang = (

lang_de => {
	de => 'Deutsch',
	fr => 'Allemand',
	en => 'German',
	el => 'Γερμανικα',
	es => 'Alemán',
	it => 'Tedesco',
	ru => 'Russisch',
	ar => 'الالمانية',
	pt => 'Alemão',
	ro => 'Germană',
	he => 'גרמנית',
	nl => 'Duits',
	nl_be => 'Duits',
},

lang_es => {
	es => 'Español',
	fr => 'Espagnol',
	en => 'Spanish',
	el => 'Ισπανικα',
	de => 'Spanisch',
	it => 'Spagnolo',
	ru => 'Ruso',
	ar => 'الاسبانية',
	pt => 'Espanhol',
	ro => 'Spaniolă',
	he => 'ספרדית',
	nl => 'Spaans',
	nl_be => 'Spaans',
},

lang_el => {
	es => 'Griego',
	fr => 'Grec',
	en => 'Greek',
	el => 'Ελληνικά',
	de => 'Griechisch',
	it => 'Greco',
	ru => 'гре́ческий язы́к',
	pt => 'Grego',
	nl => 'Grieks',
	nl_be => 'Grieks',
},

lang_en => {
	fr => 'Anglais',
	en => 'English',
	de => 'Englisch',
	el => 'Αγγλικα',
	es => 'Inglés',
	it => 'Inglese',
	ru => 'Russian',
	ar => 'الانجليزية',
	pt => 'Inglês',
	ro => 'Engleză',
	he => 'אנגלית',
	nl => 'Engels',
	nl_be => 'Engels',
},

lang_fr => {
	fr => 'Français',
	en => 'French',
	de => 'Französisch',
	es => 'Francés',
	el => 'Γαλλικα',
	it => 'Francese',
	ru => 'Russe',
	ar => 'الفرنسية',
	pt => 'Francês',
	ro => 'Franceză',
	he => 'צרפתית',
	nl => 'Frans',
	nl_be => 'Frans',
},

lang_it => {
	it => 'Italiano',
	fr => 'Italien',
	en => 'Italian',
	el => 'Ιταλικα',
	es => 'Italiano',
	ru => 'Russo',
	de => 'Italienisch',
	ar => 'الايطالية',
	pt => 'Italiano',
	ro => 'Italiană',
	he => 'איטלקית',
	nl => 'Italiaans',
	nl_be => 'Italiaans',
},

lang_ja => {
	en => 'Japanese',
	fr => 'Japonais',
	ja => '日本語',
	es => 'Japonés',
	el => 'Ιαπωνικα',
	de => 'Japanisch',
	it => 'Giapponese',
	ru => 'япо́нский язы́к',
	pt => 'Japonês',
	nl => 'Japans',
	nl_be => 'Japans',
},

lang_ko => {
	en => 'Korean',
	fr => 'Coréen',
	ko => '한국어',
	es => 'Coreano',
	el => 'Κορεατικα',
	de => 'Koreanisch',
	it => 'Coreano',
	ru => 'коре́йский язы́к',
	pt => 'Coreano',
	nl => 'Koreaans',
	nl_be => 'Koreaans',
},

lang_nl => {
	nl => 'Nederlands',
	nl_be => 'Nederlands',
	fr => 'Néerlandais',
	en => 'Dutch',
	el => 'Ολλανδικα',
	de => 'Niederländisch',
	es => 'Neerlandés',
	it => 'Olandese',
	ar => 'الهولندية',
	pt => 'Holandês',
	ro => 'Olandeză',
	he => 'הולנדית',
},

lang_pl => {
	pl => 'Polski',
	fr => 'Polonais',
	da => 'Polsk',
	en => 'Polish',
	el => 'Πολωνικα',
	de => 'Polnisch',
	es => 'Polaco',
	it => 'Polacco',
	ar => 'البولندية',
	pt => 'Polonês',
	pt_pt => 'Polaco',
	ro => 'Poloneză',
	he => 'פולנית',
	nl => 'Pools',
	nl_be => 'Pools',
},

lang_pt => {
	pt => 'Português',
	fr => 'Portugais',
	en => 'Portuguese',
	el => 'Πορτογαλικα',
	de => 'Portugiesisch',
	es => 'Portugués',
	it => 'Portoghese',
	ar => 'البرتغالية',
	he => 'פורטוגלית',
	ro => 'Portugheză',
	nl => 'Portugees',
	nl_be => 'Portugees',
},

lang_th => {
	en => 'Thai',
	fr => 'Thaï',
	th => 'ไทย',
	es => 'Tailandés',
	el => 'Ταυλανδεζικα',
	de => 'Thai',
	it => 'Tailandese',
	ru => 'та́йский',
	pt => 'Tailandês',
	nl => 'Thai',
	nl_be => 'Thai',
},

lang_vi => {
	vi => 'Tiếng Việt',
	fr => 'Vietnamien',
	da => 'Vietnamesisk',
	en => 'Vietnamese',
	es => 'Vietnamita',
	el => 'Βιετναμεζικα',
	de => 'Vietnamesisch',
	it => 'Vietnamita',
	ar => 'الفيتنامية',
	pt => 'Vietnamita',
	ro => 'Vietnameză',
	he => 'וייטנאמית',
	nl => 'Vietnamees',
	nl_be => 'Vietnamees',
	ru => 'вьетна́мский язы́к',
},

lang_zh => {
	en => 'Chinese',
	de => 'Chinesisch',
	fr => 'Chinois',
	el => 'Κινεζικα',
	zh => '中文',
	es => 'Chino',
	ar => 'الصينية',
	pt => 'Chinês',
	ro => 'Chineză',
	he => 'סינית',
	nl => 'Chinees',
	nl_be => 'Chinees',
	ru => 'кита́йский язы́к',
},

lang_ru => {
	fr => 'Russe',
	en => 'Russian',
	el => 'Ρωσικα',
	de => 'Russisch',
	es => 'Ruso',
	it => 'Russo',
	ar => 'الروسية',
	pt => 'Russo',
	ro => 'Rusă',
	he => 'רוסית',
	nl => 'Russisch',
	nl_be => 'Russisch',
	ru => 'ру́сский язы́к',
},

lang_he => {
	ar => 'العبرية',
	de => 'Hebräisch',
	en => 'Hebrew',
	es => 'Hebreo',
	fr => 'Hébreu',
	el => 'Εβραικα',
	he => 'עברית',
	it => 'Ebraico',
	nl => 'Hebreeuws',
	nl_be => 'Hebreeuws',
	pl => 'Hebrajski',
	pt => 'Hebraica',
	pt_pt => 'Hebraico',
	ro => 'Ebraică',
	ru => 'Иврит',
	vi => 'Hebrew',
	zh => '希伯来',
},

lang_ro => {
	fr => 'Roumain',
	en => 'Romanian',
	ro => 'Română',
	es => 'Rumano',
	el => 'Ρουμανικα',
	it => 'Rumeno',
	nl => 'Roemeens',
	nl_be => 'Roemeens',
	de => 'Rumänisch',
	ru => 'румы́нский язы́к',
	pt => 'Romeno',
},

lang_nl_be => {
	nl => 'Nederlands',
	nl_be => 'Nederlands',
	fr => 'Néerlandais',
	en => 'Dutch',
	el => 'Ολλανδικα',
	de => 'Niederländisch',
	es => 'Neerlandés',
	it => 'Olandese',
	ar => 'الهولندية',
	pt => 'Holandês',
	ro => 'Olandeză',
	he => 'הולנדית',
},

lang_other => {
	ar => 'لغات اخرى',
	de => 'andere Sprache',
	el => 'αλλες γλωσσες',
	en => 'other language',
	es => 'otro idioma',
	fr => 'autre langue',
	he => 'שפה אחרת',
	it => 'altra lingua',
	nl => 'andere taal',
	nl_be => 'andere taal',
	pt => 'outro idioma',
	ro => 'altă limbă',
	ru => 'другой язык',
},

lang => {
	fr => 'Langue principale sur l\'emballage du produit',
	en => 'Main language on the product',
	it => 'Lingua principale sull\'imballaggio del prodotto',
	es => 'Idioma principal en el producto',
	el => 'Κυρια γλωσσα του προιοντος',
	de => 'Hauptsprache auf dem Produkt',
	ro => 'Limba principală de pe produs',
	ru => 'Основной язык продукта',
	ar => 'اللغه الرئيسية علي المنتج',
	pt => 'Idioma principal no produto',
	he => 'השפה העיקרית על המוצר',
	nl => 'Hoofdtaal op de verpakking van het product',
	nl_be => 'Hoofdtaal op de verpakking van het product',
},

site_name => {
	de => 'Open Food Facts',
	cs => 'Open Food Facts',
	es => 'Open Food Facts',
	en => 'Open Food Facts',
	it => 'Open Food Facts',
	fi => 'Open Food Facts',
	fr => 'Open Food Facts',
	el => 'Open Food Facts',
	he => 'Open Food Facts',
	ja => 'Open Food Facts',
	ko => 'Open Food Facts',
	nl => 'Open Food Facts',
	nl_be => 'Open Food Facts',
	ru => 'Open Food Facts',
	pl => 'Open Food Facts',
	pt => 'Open Food Facts',
	ro => 'Open Food Facts',
	th => 'Open Food Facts',
	vi => 'Open Food Facts',
	zh => 'Open Food Facts',

},

site_description => {
	ru => "Совместная, открытая и свободная база данных об ингридиентах, питательности и другой информации по пищевым продуктам мира",
	fr => "Ingrédients, composition nutritionnelle et information sur les produits alimentaires du monde entier dans une base de données libre et ouverte",
	en => "A collaborative, free and open database of ingredients, nutrition facts and information on food products from around the world",
	el => " Μια συνεργατική, ελεύθερη και ανοιχτή βάση δεδομένων πάνω στα συστατικά, θρεπτικά δεδομένα και πληροφορίες για τρόφιμα σε όλο τον κόσμο",
	de => "Zutaten, Nährwertangaben und weitere Informationen über Nahrungsmittel aus der ganzen Welt in einer offenen und freien Datenbank",
	es => "Ingredientes, información nutricional e información sobre los alimentos del mundo entero en una base de datos libre y abierta",
	it => "Ingredienti, composizione nutrizionale e informazioni sui prodotti alimentari del mondo intero su una base di dati libera e aperta",
	ar => "مكونات, قيمة غذائية و معلومات حول المنتجات الغذائية في العالم الكل في قاعدة بيانات حرة و مفتوحة",
	pt => 'Uma base de dados aberta e colaborativa sobre ingredientes, informações nutricionais e alimentos de todo o mundo',
	ro => 'O bază de date liberă, colaborativă și deschisă de ingrediente, valori nutriționale și informații despre produsele alimentare din toată lumea',
	he => "מסד נתונים שיתופי, חופשי ופתוח של רכיבים, הרכבים תזונתיים ומידע על מוצרי מזון מכל רחבי העולם.",
	nl => 'Ingrediënten, voedingswaarden en informatie over voedingsproducten uit de hele wereld in een open en vrije databank',
	nl_be => 'Ingrediënten, nutritionele waarden en informatie over voedingsproducten uit de hele wereld in een open en vrije databank',
},

product_description => {
	en => "Ingredients, allergens, additives, nutrition facts, labels, origin of ingredients and information on product %s",
	fr => "Ingrédients, allergènes, additifs, composition nutritionnelle, labels, origine des ingrédients et informations du produit %s",
	nl => "Ingrediënten, allergenen, additieven, voedingswaarden, keurmerken, herkomst ingrediënten en informatie van product %s",
	nl_be => "Ingrediënten, allergenen, additieven, nutritionele waarden, keurmerken, herkomst ingrediënten en informatie van product %s",
},

og_image_url => {
	fr => 'http://fr.openfoodfacts.org/images/misc/openfoodfacts-logo-fr-356.png',
	en => 'http://world.openfoodfacts.org/images/misc/openfoodfacts-logo-en-356.png',
	es => 'http://es.openfoodfacts.org/images/misc/openfoodfacts-logo-es-356.png',
	el => 'http://es.openfoodfacts.org/images/misc/openfoodfacts-logo-es-356.png',
	it => 'http://it.openfoodfacts.org/images/misc/openfoodfacts-logo-it-356.png',
	de => 'http://de.openfoodfacts.org/images/misc/openfoodfacts-logo-de-356.png',
	ar => 'http://world.openfoodfacts.org/images/misc/openfoodfacts-logo-ar-356.png',
	pt => 'http://world.openfoodfacts.org/images/misc/openfoodfacts-logo-pt-356.png',
	ro => 'http://ro.openfoodfacts.org/images/misc/openfoodfacts-logo-356.png',
	he => 'http://world.openfoodfacts.org/images/misc/openfoodfacts-logo-he-356.png',
	nl => 'http://nl.openfoodfacts.org/images/misc/openfoodfacts-logo-nl-356.png',
	nl_be => 'http://be_nl.openfoodfacts.org/images/misc/openfoodfacts-logo-nl-356.png',
	pl => 'http://world.openfoodfacts.org/images/misc/openfoodfacts-logo-ru-356.png',
	ru => 'http://world.openfoodfacts.org/images/misc/openfoodfacts-logo-pl-356.png',
	zh => 'http://world.openfoodfacts.org/images/misc/openfoodfacts-logo-zh-356.png',
},

twitter_account => {
	fr => 'OpenFoodFactsFr',
	en => 'OpenFoodFacts',
	de => 'OpenFoodFactsDe',
	es => 'OpenFoodFactsEs',
	el => 'OpenFoodFactsEs',
	it => 'OpenFoodFactsIt',
	ja => 'OpenFoodFactsJp',
	ar => 'OpenFoodFactsAr',
	ro => 'OpenFoodFacts',
	pt => 'OpenFoodFactsPt',
	nl => 'OpenFoodFactsNl',
	nl_be => 'OpenFoodFactsNl',
},

twitter_account_by_country => {
	en => 'OpenFoodFacts',
	es => 'OpenFoodFactsEs',
	de => 'OpenFoodFactsDe',
	fr => 'OpenFoodFactsFr',
	it => 'OpenFoodFactsIt',
	jp => 'OpenFoodFactsJp',
	nl => 'OpenFoodFactsNl',
	nl_be => 'OpenFoodFactsNl',
	pt => 'OpenFoodFactsPt',
	uk => 'OpenFoodFactsUk',
},

facebook_page => {
	en => 'https://www.facebook.com/OpenFoodFacts',
	fr => 'https://www.facebook.com/OpenFoodFacts.fr',
},

products => {

	ar => 'المنتوجات',
	de => 'Produkte',
    cs => 'Výrobky', #cs-CHECK - Please check and remove this comment
	es => 'productos',
	en => 'products',
	it => 'prodotti',
    fi => 'tuotteet', #fi-CHECK - Please check and remove this comment
	fr => 'produits',
	el => 'προιοντα',
	he => 'מוצרים',
    ja => 'プロダクト', #ja-CHECK - Please check and remove this comment
    ko => '제품', #ko-CHECK - Please check and remove this comment
	nl => 'producten',
	nl_be => 'producten',
	ru => 'продукты',
    pl => 'produkty', #pl-CHECK - Please check and remove this comment
	pt => 'produtos',
	ro => 'produse',
    th => 'ผลิตภัณฑ์', #th-CHECK - Please check and remove this comment
    vi => 'sản phẩm', #vi-CHECK - Please check and remove this comment
    zh => '制品', #zh-CHECK - Please check and remove this comment

},

add_user => {
	ru => 'Зарегистрироваться',
	fr => "S'inscrire",
	en => "Register",
	it => "Registrarsi",
	el => 'Εγγραφη χρηστη',
	es => 'Registrarse',
	de => 'Anmelden',
	ar => 'التسجيل',
	pt => 'Registre-se',
	pt_pt => 'Registe-se',
	ro => 'Înregistrare',
	he => 'הרשמה',
	nl => 'Registreren',
	nl_be => 'Registreren',
},

edit_user => {
	fr => 'Paramètres du compte',
	en => 'Account parameters',
	da => 'Konto parametre',
	es => 'Parámetros de la cuenta',
	el => 'Ρυθμίσεις λογαριασμου',
	it => 'Parametri account',
	de => "Benutzerangaben",
	ar => 'إعدادات المستخدم',
	pt => 'Parâmetros de conta',
	ro => 'Parametrii contului',
	he => 'משתני החשבון',
	nl => 'Accountinstellingen',
	nl_be => 'Accountinstellingen',
	zh => '账户选项',
	ru => 'Параметры учётной записи',
},

delete_user => {
	fr => 'Effacer un utilisateur',
	en => 'Delete an user',
	el => 'Διαγραφη χρηστη',
	es => 'Eliminar un usuario',
	it => 'Cancellazione account',
	de => "Benutzer löschen",
	ar => 'حذف المستخدم',
	pt => 'apagar usuário',
	pt_pt => 'Apagar utilizador',
	ro => 'Ștergere utilizator',
	he => 'מחיקת משתמש',
	nl => 'Verwijder gebruiker',
	nl_be => 'Verwijder gebruiker',
},

add_user_confirm => {
	fr => '<p>Merci de votre inscription. Vous pouvez maintenant vous identifier sur le site pour ajouter et modifier des produits.</p>',
	en => '<p>Thanks for joining. You can now sign-in on the site to add and edit products.</p>',
	da => '<p>Tak for tilmeldelsen. Du kan nu logge på på webstedet for at tilføje og redigere produkter.</p>',
	el => '<p> Ευχαριστούμε που επισκεφθήκατε τη σελίδα μας. Τώρα μπορείτε να εγγραφείτε για να προσθέσετε και να επεξεργαστείτε προϊόντα.</p>',
	es => '<p>Gracias por registrarse. A partir de ahora puede identificarse en el sitio para añadir o modificar productos.<p>',
	de => '<p>Vielen Dank für ihre Registrierung. Sie können sich jetzt auf der Seite anmelden um Produkte hinzuzufügen oder abzuändern.</p>',
	it => '<p>Grazie per la vostra iscrizione. Da adesso potete identificarvi sul sito per aggiungere e/o modificare dei prodotti.</p>',
	ar => '<p>شكرا على انضمامك إلينا ، يمكتك الآن تسجيل دخولك و إضافة  أو تعديل المنتجات.</p>',
	pt => '<p>Obrigado pela sua inscrição. Pode aceder ao site para adicionar ou editar produtos.</p>',
	ro => '<p>Vă mulțumim pentru înscriere. De acum vă puteți autentifica pe site pentru a adăuga și modifica produse.</p>',
	he => '<p>תודה לך על הצטרפותך. מעכשיו תהיה לך אפשרות להיכנס לאתר כדי להוסיף ולערוך מוצרים.</p>',
	nl => '<p>Bedankt voor uw inschrijving. U kan nu inloggen op de site om producten toe te voegen of te bewerken.</p>',
	nl_be => '<p>Bedankt voor uw inschrijving. U kan nu inloggen op de site om producten toe te voegen of te bewerken.</p>',
	ru => '<p>Спасибо, что присоединились! Теперь вы можете войти на сайт, чтобы,добавить или изменить продукты.</p>',
},

add_user_email_subject => {
	fr => 'Merci de votre inscription sur Open Food Facts',
	en => 'Thanks for joining Open Food Facts',
	el => 'Ευχαριστούμε που επισκεφθήκατε το Open Food Facts',
	de => 'Vielen Dank für ihre Anmeldung auf Open Food Facts',
	es => 'Gracias por registrarse en Open Food Facts',
	it => 'Grazie per la vostra iscrizione a Open Food Facts',
	ar => 'شكرا على انضمامك لموقعنا Open Food Facts',
	pt => 'Obrigado por se juntar ao Open Food Facts',
	ro => 'Vă mulțumim pentru înscrierea la Open Food Facts',
	he => 'תודה לך על הצטרפותך ל־Open Food Facts',
	nl => 'Bedankt voor uw inschrijving op Open Food Facts',
	nl_be => 'Bedankt voor uw inschrijving op Open Food Facts',
},

add_user_email_body => {
	fr =>
'Bonjour <NAME>,

Merci beaucoup de votre inscription sur http://openfoodfacts.org
Voici un rappel de votre identifiant :

Nom d\'utilisateur : <USERID>

Vous pouvez maintenant vous identifier sur le site pour ajouter et modifier des produits.

Vous pouvez également rejoindre le groupe des contributeurs sur Facebook :
https://www.facebook.com/groups/356858984359591/

et/ou la liste de discussion en envoyant un e-mail vide à off-fr-subscribe\@openfoodfacts.org

Open Food Facts est un projet collaboratif auquel vous pouvez apporter bien plus que des produits : votre enthousiasme et vos idées !
Vous pouvez en particulier partager vos suggestions sur le forum des idées :
https://openfoodfactsfr.uservoice.com/

Et ma boîte mail est bien sûr grande ouverte pour toutes vos remarques, questions ou suggestions.

Merci beaucoup et à bientôt !

Stéphane
http://openfoodfacts.org
http://twitter.com/OpenFoodFactsFr
',

	it =>
'Buongiorno <NAME>,

Grazie per essersi  iscritto su http://openfoodfacts.org

Ecco un riassunto dei vostri dati identificativi:

Nome d\'utilizzatore: <USERID>

Adesso potete identificarvi sul sito per aggiungere e modificare dei prodotti.

Potete ugualmente raggiungere il gruppo dei contribuenti su Facebook:
https://www.facebook.com/groups/447693908583938/

Open Food Facts è un progetto di collaborazione al quale potete aggiungere ben più che dei prodotti: il vostro entusiasmo e le vostre idee.
https://openfoodfacts.uservoice.com/

La mia casella mail è abbastanza grande e aperta per tutti i vostri suggerimenti, commenti e domande. (in English / en français se possibile...)

Grazie!

Stéphane
http://openfoodfacts.org
http://twitter.com/OpenFoodFactsIt
',

	en =>
'Hello <NAME>,

Thanks a lot for joining http://openfoodfacts.org
Here is your user name:

User name: <USERID>

You can now sign in on the site to add and edit products.

You can also join the Facebook group for contributors:
https://www.facebook.com/groups/374350705955208/

Open Food Facts is a collaborative project to which you can bring much more than new products: your energy, enthusiasm and ideas!
You can also share your suggestions on the idea forum:
http://openfoodfacts.uservoice.com/

And my mailbox is of course wide open for your comments, questions and ideas.

Thank you very much!

Stéphane
http://openfoodfacts.org
http://twitter.com/OpenFoodFacts
',

el =>
'Καλωσόρισατε <NAME>,

Ευχαριστούμε πολύ που επισκεφθήκατε το http://openfoodfacts.org
Το user name σας είναι:

User name: <USERID>

Μπορείτε τώρα να εγγραφείτε στη σελίδα μας και εν συνεχεία να προσθέσετε και να επεξεργαστείτε προϊόντα.

Μπορείτε επίσης να εγγραφείτε στο Facebook group των συντελεστών μας:
https://www.facebook.com/groups/374350705955208/

Το Open Food Facts είναι ένα συνεργατικό εγχείρημα στο οποίο μπορείτε επίσης να συμβάλλετε με την ενέργεια, τον ενθουσιασμό και τις ιδέες σας!
Μπορείτε επίσης να μοιραστείτε τις προτάσεις σας στο idea forum:
http://openfoodfacts.uservoice.com/

Και φυσικά το mailbox μου είναι πάντα ανοιχτό για τα σχόλια και παρατηρήσεις, τις ερωτήσεις και τις ιδέες σας.

Σας ευχαριστώ πάρα πολύ!

Stéphane
http://openfoodfacts.org
http://twitter.com/OpenFoodFacts
',
	es =>
'Buenos días <NAME>,

Muchas gracias por registrarse en http://openfoodfacts.org
Su nombre de usuario es:

Nombre de usuario: <USERID>

A partir de ahora podrá identificarse en el sitio para añadir y editar productos.

Si lo desea, también podrá unirse al grupo de Facebook para usuarios en español:
https://www.facebook.com/groups/470069256354172/

Open Food Facts es un proyecto colaborativo al que puede aportar mucho más que información sobre los productos:  ¡Su energía, su entusiasmo y sus ideas!
También podrá  compartir sus sugerencias en el foro de nuevas ideas:
http://openfoodfacts.uservoice.com/

Y por supuesto, mi correo electrónico está disponible para todos los comentarios, ideas o preguntas que le puedan surgir.

¡Muchas gracias!

Stéphane
http://openfoodfacts.org
http://twitter.com/OpenFoodFactsEs
',

	de =>
'Hallo <NAME>,

Vielen Dank, dass Sie http://openfoodfacts.org beigetreten sind.
Hier finden Sie Ihren Benutzernamen:

Benutzername: <USERID>

Sie können sich jetzt auf der Seite anmelden und Produkte hinzufügen oder abändern.

Sie können auch der Facebookgruppe für Unterstützer beitreten:
https://www.facebook.com/groups/488163711199190/

Open Food Facts ist ein gemeinschaftliches Projekt zu dem Sie noch viel mehr als neue Produkte beitragen können: Ihre Energie, Ihren Enthusiasmus und neue Ideen!
Auf dem Ideenforum können Sie ihre Vorschläge mit uns teilen:
http://openfoodfacts.uservoice.com/

Und meine Mailbox ist selbstverständlich immer offen für Kommentare, Fragen und Ideen.

Vielen herzlichen Dank!

Stéphane
http://openfoodfacts.org
http://twitter.com/OpenFoodFactsDe
',

	pt =>
'Olá <NAME>,

Muito obrigado por se juntar ao http://world.openfoodfacts.org
Esse é o seu nome de usuário:

Nome de usuário: <USERID>

Você pode aceder ao site para adicionar ou editar produtos.

Você também pode entrar no grupo de colaboradores no Facebook:
https://www.facebook.com/groups/374350705955208/

O Open Food Facts é um projeto colaborativo para o qual você pode trazer muito mais que novos produtos: sua energia, entusiasmo e ideias!
Você também pode compartilhar suas sugestões no fórum de ideias:
http://openfoodfacts.uservoice.com/

E minha caixa de email está totalmente aberta para seus comentários, questões e ideias.

Muito obrigado!

Stéphane
http://openfoodfacts.org
http://twitter.com/OpenFoodFactsPt
',

	pt_pt =>
'Olá <NAME>,

Muito obrigado por se juntar ao http://world.openfoodfacts.org
Este é o seu nome de utilizador:

Nome de utilizador: <USERID>

Pode aceder ao site para adicionar ou editar produtos.

Também pode entrar no grupo de colaboradores no Facebook:
https://www.facebook.com/groups/374350705955208/

O Open Food Facts é um projeto colaborativo para o qual você pode trazer muito mais que novos produtos: a sua energia, entusiasmo e ideias!
Pode partilhar as suas sugestões no fórum de ideias:
http://openfoodfacts.uservoice.com/

E a minha caixa de email está totalmente aberta para os seus comentários, questões e ideias.

Muito obrigado!

Stéphane
http://openfoodfacts.org
http://twitter.com/OpenFoodFactsPt
',

	he =>
'שלום <NAME>,

תודה רבה לך על הצטרפותך ל־http://openfoodfacts.org
להלן שם המשתמש שלך:

שם משתמש: <USERID>

מעתה ניתן להיכנס לאתר כדי להוסיף או לערוך מוצרים.

ניתן להצטרף גם לקבוצת הפייסבוק למתנדבים:
https://www.facebook.com/groups/374350705955208/

מיזם Open Food Facts הנו שיתופי ומאפשר לך להוסיף הרבה יותר מאשר רק מוצרים חדשים: האנרגיה, ההתלהבות והרעיונות שלך!
ניתן גם לשתף את הצעותיך בפורום הרעיונות:
http://openfoodfacts.uservoice.com/

וכתובת הדוא״ל שלי כמובן פתוחה לרווחה להצעות, שאלות ורעיונות.

תודה רבה לך!

סטפן
http://openfoodfacts.org
http://twitter.com/OpenFoodFacts
',

	nl =>
'Hallo <NAME>,

Hartelijk bedankt voor je inschrijving op http://openfoodfacts.org
Dit is je gebruikersnaam :

Gebruikersnaam : <USERID>

Je kan nu inloggen op de site om producten toe te voegen of te bewerken.

Je kan ook lid worden van onze facebookgroep voor gebruikers:
https://www.facebook.com/groups/356858984359591/

Open Food Facts is een open source-project waaraan je veel meer dan enkel producten kan toevoegen: je energie, enthousiasme en ideeën!

Je kan uw suggesties delen op het ideeënforum:
https://openfoodfactsfr.uservoice.com/

En mijn mailbox staat natuurlijk open voor al je opmerkingen, vragen of suggesties.

Hartelijk bedankt en tot binnenkort!

Stéphane
http://openfoodfacts.org
http://twitter.com/OpenFoodFactsNl
',

	nl_be =>
'Hallo <NAME>,

Hartelijk bedankt voor uw inschrijving op http://openfoodfacts.org
Dit is uw gebruikersnaam :

Gebruikersnaam : <USERID>

U kunt nu inloggen op de site om producten toe te voegen of te bewerken.

U kunt ook lid worden van onze facebookgroep voor gebruikers:
https://www.facebook.com/groups/356858984359591/

Open Food Facts is een open source-project waaraan u veel meer dan enkel producten kan toevoegen: uw energie, enthousiasme en ideeën!

U kunt uw suggesties delen op het ideeënforum:
https://openfoodfactsfr.uservoice.com/

En mijn mailbox staat natuurlijk open voor al uw opmerkingen, vragen of suggesties.

Hartelijk bedankt en tot binnenkort!

Stéphane
http://openfoodfacts.org
http://twitter.com/OpenFoodFactsNl
',

},

reset_password_email_subject => {
	fr => 'Réinitialisation de votre mot de passe sur Open Food Facts',
	de => 'Setze dein Passwort auf Open Food Facts zurück',
	en => 'Reset of your password on Open Food Facts',
	es => 'Cambio de la contraseña de su cuenta en Open Food Facts',
	pt => 'Modifique a sua senha do Open Food Facts',
	pt_pt => 'Alteração da sua palavra-passe no Open Food Facts',
	ro => 'Resetarea parolei dumneavoastră pe Open Food Facts',
	he => 'איפוס הססמה שלך ב־Open Food Facts',
	nl => 'Wijziging van je wachtwoord op Open Food Facts',
	nl_be => 'Wijziging van uw paswoord op Open Food Facts',
},

reset_password_email_body => {
	fr =>
'Bonjour <NAME>,

Vous avez demandé une réinitialisation de votre mot de passe sur http://openfoodfacts.org

pour l\'utilisateur : <USERID>

Si vous voulez poursuivre cette réinitialisation, cliquez sur le lien ci-dessous.
Si vous n\'êtes pas à l\'origine de cette demande, vous pouvez ignorer ce message.

<RESET_URL>

A bientôt,

Stéphane
http://openfoodfacts.org
',

	de =>
'Hallo <NAME>,

du hast eine Passwort-Zurücksetzung auf http://openfoodfacts.org

für folgenden Benutzer angefordert: <USERID>

Um die Passwort-Zurücksetzung abzuschließen, klicke auf den Link unten.
Falls du keine Zurücksetzung angefordert hast, ignoriere diese E-Mail einfach.

<RESET_URL>

Mit freundlichen Grüßen

Stephane
http://openfoodfacts.org
',

	en =>
'Hello <NAME>,

You asked for your password to be reset on http://openfoodfacts.org

for the username: <USERID>

To continue the password reset, click on the link below.
If you did not ask for the password reset, you can ignore this message.

<RESET_URL>

See you soon,

Stephane
http://openfoodfacts.org
',

	es =>
'Buenos días <NAME>,

Ha solicitado el cambio de contraseña en http://openfoodfacts.org

para la cuenta de usuario: <USERID>

Para continuar con el cambio de la contraseña, haga clic en el enlace de abajo.
Si por el contrario no desea cambiar la contraseña, ignore este mensaje.

<RESET_URL>

Esperamos verle pronto de nuevo,

Stephane
http://openfoodfacts.org
',

	ar =>
'مرحبا <NAME>،
لقد طلبت إعادة تعين كلمة المرور الخاصة بك للموقع  http://openfoodfacts.org
لإسم المستخدم  <USERID> :

لمواصلة إعادة تعيين كلمة المرور، انقر على الرابط أدناه.
إذا كنت لم تطلب إعادة تعيين كلمة المرور، يمكنك تجاهل هذه الرسالة.

<RESET_URL>

الي اللقاء،

ستيفان
http://openfoodfacts.org
',

	pt =>
'Olá <NAME>,

Você pediu para modificar sua senha do  http://openfoodfacts.org

para o nome de usuário: <USERID>

Para continuar com a modificação de senha, clique no link abaixo.
Se você não pediu para modificar sua senha, você pode ignorar essa mensagem.

<RESET_URL>

Até logo

Stephane
http://openfoodfacts.org
',

	pt_pt =>
'Olá <NAME>,

Pediu para alteração a sua palavra-passe no http://openfoodfacts.org

para o nome de utilizador: <USERID>

Para continuar com a alteração da palavra-passe, clique no link abaixo.
Se não pediu para a sua alteração, ignore esta mensagem.

<RESET_URL>

Até logo,

Stephane
http://openfoodfacts.org
',

	he =>
'שלום <NAME>,

ביקשת לאפס את ססמת המשתמש שלך ב־http://openfoodfacts.org

עבור המשתמש: <USERID>

כדי להמשיך בתהליך איפוס הססמה עליך ללחוץ על הקישור שלהלן.
אם לא ביקשת לאפס את הססמה, ניתן להתעלם מהודעה זו.

<RESET_URL>

נתראה בקרוב,

סטפן
http://openfoodfacts.org
',

	nl =>
'Hallo <NAME>,

Je hebt gevraagd je wachtwoord te wijzigen op http://openfoodfacts.org

voor de gebruikersnaam: <USERID>

Om je wachtwoord te wijzigen, klik op onderstaande link.
Indien je je wachtwoord niet wenst te wijzigen, dan mag je dit bericht negeren.

<RESET_URL>

Tot ziens,

Stephane
http://openfoodfacts.org
',

	nl_be =>
'Hallo <NAME>,

U hebt gevraagd uw paswoord te wijzigen op http://openfoodfacts.org

voor de gebruikersnaam: <USERID>

Om uw paswoord te wijzigen, klik op onderstaande link.
Indien u uw paswoord niet wenst te wijzigen, mag u dit bericht negeren.

<RESET_URL>

Tot ziens,

Stephane
http://openfoodfacts.org
',
},


edit_user_confirm => {
	fr => '<p>Les paramètres de votre compte ont bien été modifiés.</p>',
	de => '<p>Deine Benutzereinstellungen wurden geändert.</p>',
	ar => '<p>لقد تم تعديل إعداداتكم بنجاح</p>',
	en => '<p>Your account parameters have been changed.</p>',
	da => '<p>Dine konto parametre er blevet ændret.</p>',
	el => '<p>Οι ρυθμίσεις του λογαριασμού σας έχουν αλλάξει.</p>',
	es => '<p>Los datos de su cuenta han sido modificados correctamente.</p>',
	it => '<p>I parametri del suo account sono stati modificati.</p>',
	pt => '<p>Os dados de sua conta foram modificados.</p>',
	pt_pt => '<p>As informações da sua conta foram modificados.</p>',
	ro => '<p>Parametrii contului dumneavoastră au fost schimbați.</p>',
	he => '<p>משתני החשבון שלך הוחלפו.</p>',
	nl => '<p>Je accountinstellingen werden succesvol gewijzigd</p>',
	nl_be => '<p>Uw accountinstellingen werden succesvol gewijzigd</p>',
	ru => '<p>Параметры вашей учётной записи были изменены.</p>',
},

edit_profile => {
	fr => "Modifier votre profil public",
	de => "Bearbeite dein öffentliches Profil",
	en => "Edit your public profile",
	es => "Edite su perfil público",
	el => "Επεξεργαστείτε το προφίλ σας",
	it => "Modificare il vostro profilo pubblico",
	ar => 'تعديل إعداداتك الشخصية',
	pt => 'Edite seu perfil público',
	pt_pt => 'Edite o seu perfil público',
	ro => 'Modificați profilul public',
	he => "עריכת הפרופיל הציבורי שלך",
	nl => 'Je publiek profiel aanpassen',
	nl_be => 'Uw publiek profiel aanpassen',
},

edit_profile_msg => {
	fr => "Les informations ci-dessous figurent dans votre profil public.",
	de => "Die Informationen unten sind in deinem öffentlichen Profil sichtbar.",
	en => "Information below is visible in your public profile.",
	el => "Η παρακάτω πληροφορία είναι ορατή στο δημόσιο προφιλ σας.",
	es => "La información que se encuentra debajo estará disponible en su perfil público.",
	it => "Le informazioni qui sotto appaiono nel vostro profilo pubblico.",
	ar => 'هذه المعلومات تظهر في صفحتك و يطلع عليها كل المستخدمون',
	pt => 'As informações abaixo estão visíveis no seu perfil público',
	ro => 'Informația următoare este vizibilă în profilul dumneavoastră public',
	he => "המידע שלהלן מופיע בפרופיל הציבורי שלך.",
	nl => 'De onderstaande informatie is zichtbaar op je publiek profiel',
	nl_be => 'De onderstaande informatie is zichtbaar op uw publiek profiel',
},

edit_profile_confirm => {
	fr => "Les modifications de votre profil public ont été enregistrées.",
	de => "Die Änderungen an deinem öffentlichen Profil wurden gespeichert.",
	en => "Changes to your public profile have been saved.",
	el => "Οι αλλαγές στο δημόσιο προφιλ σας εχουν αποθηκευτει.",
	es => "Los cambios en su perfil público han sido guardados.",
	it => "Le modifiche del suo profilo pubblico sono state registrate.",
	ar => 'لقد تم تعديل بياناتكم بنجاح',
	pt => 'As modificações no seu perfil público foram salvas.',
	pt_pt => 'As modificações ao seu perfil público foram guardadas.',
	ro => 'Modificările asupra profilului public au fost salvate.',
	he => "השינויים לפרופיל הציבורי שלך נשמרו.",
	nl => 'De aanpassingen aan je publiek profiel werden opgeslagen',
	nl_be => 'De aanpassingen aan uw publiek profiel werden opgeslagen',
	ru => 'Изменения в вашем публичном профиле сохранены.',
},

session_title => {

	ar => 'تسجيل الدخول',
	de => 'Anmelden',
    cs => 'Podepiš', #cs-CHECK - Please check and remove this comment
	es => 'Iniciar sesión',
	en => 'Sign-in',
	it => 'connettersi',
    fi => 'Kirjaudu sisään', #fi-CHECK - Please check and remove this comment
	fr => 'Se connecter',
	el => 'Εγγραφη',
	he => 'כניסה',
    ja => 'ログイン', #ja-CHECK - Please check and remove this comment
    ko => '로그인에', #ko-CHECK - Please check and remove this comment
	nl => 'Aanmelden',
	nl_be => 'Aanmelden',
    ru => 'Войти в систему', #ru-CHECK - Please check and remove this comment
    pl => 'Zaloguj', #pl-CHECK - Please check and remove this comment
	pt => 'Iniciar sessão',
	ro => 'Autentificare',
    th => 'Sign-in', #th-CHECK - Please check and remove this comment
    vi => 'Đăng nhập', #vi-CHECK - Please check and remove this comment
    zh => '登入', #zh-CHECK - Please check and remove this comment

},

login_register_title => {

	ar => 'تسجيل الدخول',
	de => 'Anmelden',
    cs => 'Podepiš', #cs-CHECK - Please check and remove this comment
	es => 'Iniciar sesión',
	en => 'Sign-in',
	it => 'connettersi',
    fi => 'Kirjaudu sisään', #fi-CHECK - Please check and remove this comment
	fr => 'Se connecter',
	el => 'Εγγραφη',
	he => 'כניסה',
    ja => 'ログイン', #ja-CHECK - Please check and remove this comment
    ko => '로그인에', #ko-CHECK - Please check and remove this comment
	nl => 'Aanmelden',
	nl_be => 'Aanmelden',
    ru => 'Войти в систему', #ru-CHECK - Please check and remove this comment
    pl => 'Zaloguj', #pl-CHECK - Please check and remove this comment
	pt => 'Iniciar sessão',
	ro => 'Autentificare',
    th => 'Sign-in', #th-CHECK - Please check and remove this comment
    vi => 'Đăng nhập', #vi-CHECK - Please check and remove this comment
    zh => '登入', #zh-CHECK - Please check and remove this comment

},

login_username_email => {
	ar =>   "اسم الدخول او البريد الالكتروني :",
	de => 'Benutzername oder E-Mail-Adresse:',
    cs => 'Uživatelské jméno nebo e-mailová adresa:', #cs-CHECK - Please check and remove this comment
	es => "Nombre de usuario o dirección de correo electrónico:",
	en => "Username or e-mail address:",
	da => 'Brugernavn eller e-mail adresse',
    it => 'Nome utente o indirizzo e-mail:', #it-CHECK - Please check and remove this comment
    fi => 'Käyttäjätunnus tai sähköpostiosoite:', #fi-CHECK - Please check and remove this comment
	fr => "Nom d'utilisateur ou adresse e-mail :",
	el => "Username ή διεύθυνση e-mail:",
	he => "שם משתמש או כתובת דוא״ל:",
    ja => 'ユーザー名または電子メールアドレス：', #ja-CHECK - Please check and remove this comment
    ko => '아이디 나 이메일 주소 :', #ko-CHECK - Please check and remove this comment
	nl => 'Gebruikersnaam of e-mailadres',
	nl_be => 'Gebruikersnaam of e-mailadres',
	#ru => 'Имя пользователя или адрес эл. почты',
    ru => 'Имя пользователя или адрес электронной почты:', #ru-CHECK - Please check and remove this comment
    pl => 'Nazwa użytkownika lub adres e-mail:', #pl-CHECK - Please check and remove this comment
	pt => 'Nome de usuário e e-mail:',
	pt_pt => 'Nome de utilizador ou e-mail:',
	ro => 'Numele de utilizator sau adresa de e-mail:',
    th => 'ชื่อผู้ใช้หรืออีเมลที่อยู่:', #th-CHECK - Please check and remove this comment
    vi => 'Tên đăng nhập hoặc địa chỉ email:', #vi-CHECK - Please check and remove this comment
    zh => '用户名或电子邮件地址：', #zh-CHECK - Please check and remove this comment
},

login_to_add_products => {
	fr => <<HTML
<p>Vous devez vous connecter pour pouvoir ajouter ou modifier un produit.</p>

<p>Si vous n'avez pas encore de compte sur Open Food Facts, vous pouvez <a href="http://fr.openfoodfacts.org/cgi/user.pl">vous inscrire en 30 secondes</a>.</p>
HTML
,
	de => <<HTML
<p>Bitte melde dich an, um ein Produkt hinzuzufügen oder zu bearbeiten.</p>

<p>Wenn du noch kein Benutzerkonto auf Open Food Facts hast, dann kannst du dich <a href="/cgi/user.pl">innerhalb von 30 Sekunden anmelden</a>.</p>
HTML
,
	en => <<HTML
<p>Please sign-in to add or edit a product.</p>

<p>If you do not yet have an account on Open Food Facts, you can <a href="/cgi/user.pl">register in 30 seconds</a>.</p>
HTML
,
el => <<HTML
<p>Παρακαλώ εγγραφείτε για να προσθέσετε ή να επεξεργαστείτε προϊόντα.</p>

<p> Αν δεν έχετε ακόμα λογαριασμό στο Open Food Facts, μπορείτε να <a href="/cgi/user.pl">register in 30 seconds</a>.</p>
HTML
,
ar => <<HTML
<p>الرجاء تسجيل الدخول لإضافة أو تعديل المنتج.</p>
<p>إذا لم يكن لديك حساب حتى الآن على Open Food Facts، يمكنك <a href="/cgi/user.pl">التسجيل في 30 ثانية</a>.</p>
HTML
,
	pt => <<HTML
<p>Por favor autentique-se para adicionar ou editar um produto.</p>

<p>Se você ainda não possui uma conta no Open Food Facts, você pode <a href="/cgi/user.pl">registrar-se em 30 segundos</a>.</p>
HTML
,
	pt_pt => <<HTML
<p>Por favor efectue login para adicionar ou editar um produto.</p>

<p>Se ainda não possui uma conta no Open Food Facts, pode <a href="/cgi/user.pl">registar-se em 30 segundos</a>.</p>
HTML
,
	he => <<HTML
<p>נא להיכנס כדי להוסיף או לערוך מוצר.</p>

<p>אם עדיין אין לך חשבון ב־Open Food Facts, יש לך אפשרות <a href="/cgi/user.pl">להירשם תוך 30 שניות</a>.</p>
HTML
,
	nl => <<HTML
<p>Je moet je aanmelden om producten toe te voegen of te bewerken.</p>

<p>Als je nog geen account hebt op Open Food Facts, kan je <a href="/cgi/user.pl">je registreren in 30 seconden</a>.</p>
HTML
,
	nl_be => <<HTML
<p>U moet zich aanmelden om producten toe te voegen of te bewerken.</p>

<p>Als u nog geen account hebt op Open Food Facts, kan u <a href="/cgi/user.pl">zich registreren in 30 seconden</a>.</p>
HTML
,

},

login_to_add_and_edit_products => {
    ar => 'تسجيل الدخول لإضافة أو تحرير المنتجات.', #ar-CHECK - Please check and remove this comment
	de => "Melde dich an, um ein Produkt hinzuzufügen oder zu bearbeiten.",
    cs => 'Sign-in přidat nebo upravit výrobky.', #cs-CHECK - Please check and remove this comment
	es => "Conéctate para añadir o modificar productos.",
	en => "Sign-in to add or edit products.",
	it => "Connettersi per aggiungere o modificare delle schede.",
    fi => 'Kirjaudu sisään lisätä tai muokata tuotteita.', #fi-CHECK - Please check and remove this comment
	fr => "Connectez-vous pour ajouter des produits ou modifier leurs fiches.",
	el => "Εγγραφείτε για να προσθέσετε ή να επεξεργαστείτε προϊόντα.",
	he => "נא להיכנס כדי להוסיף או לערוך מוצרים.",
    ja => 'サインイン製品を追加または編集します。', #ja-CHECK - Please check and remove this comment
    ko => '로그인에 추가하거나 편집 제품.', #ko-CHECK - Please check and remove this comment
	nl => "Meld je aan om producten toe te voegen of te bewerken.",
	nl_be => "Meld u aan om producten toe te voegen of te bewerken.",
    ru => 'Войдите в систему, чтобы добавить или изменить продукты.', #ru-CHECK - Please check and remove this comment
    pl => 'Zaloguj się, aby dodać lub edytować produkty.', #pl-CHECK - Please check and remove this comment
	pt => "Inicie uma sessão para adicionar ou editar produtos.",
	ro => "Autentificați-vă pentru a adăuga sau modifica produse.",
    th => 'ลงชื่อเข้าใช้เพื่อเพิ่มหรือแก้ไขผลิตภัณฑ์', #th-CHECK - Please check and remove this comment
    vi => 'Đăng nhập để thêm hoặc chỉnh sửa sản phẩm.', #vi-CHECK - Please check and remove this comment
    zh => '登录到添加或编辑产品。', #zh-CHECK - Please check and remove this comment
},

login_not_registered_yet => {

    ar => 'لم تسجل حتى الآن؟', #ar-CHECK - Please check and remove this comment
	de => "Noch nicht registriert?",
    cs => 'Ještě nejste zaregistrován?', #cs-CHECK - Please check and remove this comment
	es => "¿Todavía no te has registrado?",
	en => "Not registered yet?",
	it => "Non ancora iscritta/o?",
    fi => 'Etkö ole vielä rekisteröitynyt?', #fi-CHECK - Please check and remove this comment
	fr => "Pas encore inscrit(e) ?",
	el => "Δεν έχετε εγγραφεί ακόμα;",
	he => "לא נרשמת עדיין?",
    ja => 'まだ登録されていませんか？', #ja-CHECK - Please check and remove this comment
    ko => '아직 등록하지?', #ko-CHECK - Please check and remove this comment
	nl => "Nog niet geregistreerd?",
	nl_be => "Nog niet geregistreerd?",
    ru => 'Еще не зарегистрированы?', #ru-CHECK - Please check and remove this comment
    pl => 'Nie jesteś jeszcze zarejestrowany?', #pl-CHECK - Please check and remove this comment
	pt => "Ainda não é registrado?",
	ro => "Nu v-ați înregistrat încă?",
    th => 'ไม่ได้ลงทะเบียนหรือยัง', #th-CHECK - Please check and remove this comment
    vi => 'Không đăng ký chưa?', #vi-CHECK - Please check and remove this comment
    zh => '尚未注册？', #zh-CHECK - Please check and remove this comment

},

login_create_your_account => {

	ar => 'أنشئ حسابك.', #ar-CHECK - Please check and remove this comment
	de => "Erstelle ein Benutzerkonto.",
	cs => 'Vytvořte si svůj účet.', #cs-CHECK - Please check and remove this comment
	es => "Crea tu cuenta.",
	en => "Create your account.",
	it => "Creare il proprio account.",
	fi => 'Luo tilisi.', #fi-CHECK - Please check and remove this comment
	fr => "Créez votre compte.",
	el => "τη δημιουργία του λογαριασμού σας .",
	he => "ניתן ללחוץ כאן ליצירת חשבון חדש",
	ja => 'あなたのアカウントを作成します。', #ja-CHECK - Please check and remove this comment
	ko => '여러분의 계정을 만들어보세요.', #ko-CHECK - Please check and remove this comment
	nl => "Creëer je account",
	nl_be => "Creëer uw account",
	ru => 'Создайте свой аккаунт.', #ru-CHECK - Please check and remove this comment
	pl => 'Utwórz swoje konto.', #pl-CHECK - Please check and remove this comment
	pt => "Criar uma conta.",
	ro => "Creați-vă contul.",
	th => 'สร้างบัญชีของคุณ', #th-CHECK - Please check and remove this comment
	vi => 'Tạo tài khoản của bạn.', #vi-CHECK - Please check and remove this comment
	zh => '创建您的帐户。', #zh-CHECK - Please check and remove this comment

},


login_register_content => {
	fr => <<HTML
<p>Connectez-vous pour ajouter des produits ou modifier leurs fiches.</p>

<form method="post" action="/cgi/session.pl">
Nom d'utilisateur ou adresse e-mail :<br />
<input type="text" name="user_id" tabindex="1" style="width:220px;" /><br />
Mot de passe<br />
<input type="password" name="password" tabindex="2" style="width:220px;" /><br />
<input type="checkbox" name="remember_me" value="on" tabindex="3" /><label>Se souvenir de moi</label><br />
<input type="submit" tabindex="4" name=".submit" value="Se connecter" class="button small" />
</form>
<p>Pas encore inscrit(e) ? <a href="/cgi/user.pl">Créez votre compte</a>.</p>
HTML
,

	de => <<HTML
<p>Melde dich an, um ein Produkt hinzuzufügen oder zu bearbeiten.</p>

<form method="post" action="/cgi/session.pl">
Benutzername oder E-Mail-Adresse:<br />
<input type="text" name="user_id" tabindex="1" style="width:220px;" /><br />
Passwort<br />
<input type="password" name="password" tabindex="2" style="width:220px;" /><br />
<input type="checkbox" name="remember_me" value="on" tabindex="3" /><label>Angemeldet bleiben</label><br />
<input type="submit" tabindex="4" name=".submit" value="Sign-in" class="button small" />
</form>
<p>Noch nicht registriert? <a href="/cgi/user.pl">Erstelle ein Benutzerkonto</a>.</p>
HTML
,
el => <<HTML
<p>Εγγραφείτε για να προσθέσετε ή να επεξεργαστείτε προϊόντα.</p>

<form method="post" action="/cgi/session.pl">
Username ή διεύθυνση e-mail:<br />
<input type="text" name="user_id" tabindex="1" style="width:220px;" /><br />
Password<br />
<input type="password" name="password" tabindex="2" style="width:220px;" /><br />
<input type="checkbox" name="remember_me" value="on" tabindex="3" /><label>Remember me</label><br />
<input type="submit" tabindex="4" name=".submit" value="Sign-in" class="button small" />
</form>
<p>Δεν έχετε εγγραφεί ακόμα; <a href="/cgi/user.pl">Create your account</a>.</p>
HTML
,


en => <<HTML
<p>Sign-in to add or edit products.</p>

<form method="post" action="/cgi/session.pl">
Username or e-mail address:<br />
<input type="text" name="user_id" tabindex="1" style="width:220px;" /><br />
Password<br />
<input type="password" name="password" tabindex="2" style="width:220px;" /><br />
<input type="checkbox" name="remember_me" value="on" tabindex="3" /><label>Remember me</label><br />
<input type="submit" tabindex="4" name=".submit" value="Sign-in" class="button small" />
</form>
<p>Not registered yet? <a href="/cgi/user.pl">Create your account</a>.</p>
HTML
,

	es => <<HTML
<p>Conéctate para añadir o modificar productos.</p>

<form method="post" action="/cgi/session.pl">
Nombre de usuario o dirección de correo electrónico:<br />
<input type="text" name="user_id" tabindex="1" style="width:220px;" /><br />
Contraseña<br />
<input type="password" name="password" tabindex="2" style="width:220px;" /><br />
<input type="checkbox" name="remember_me" value="on" tabindex="3" /><label>Mantenerme conectado</label><br />
<input type="submit" tabindex="4" name=".submit" value="Sign-in" class="button small" />
</form>
<p>¿Todavía no te has registrado? <a href="/cgi/user.pl">Crea tu cuenta</a>.</p>
HTML
,

	it => <<HTML
<p>Connettersi per aggiungere o modificare delle schede.</p>

<form method="post" action="/cgi/session.pl">
Nom d'utilisateur ou adresse e-mail :<br />
<input type="text" name="user_id" tabindex="1" style="width:220px;" /><br />
Mot de passe<br />
<input type="password" name="password" tabindex="2" style="width:220px;" /><br />
<input type="checkbox" name="remember_me" value="on" tabindex="3" /><label>Mantenere la connessione</label><br />
<input type="submit" tabindex="4" name=".submit" value="Connettersi" class="button small" />
</form>
<p>Non ancora iscritta/o? <a href="/cgi/user.pl">Creare il proprio account</a>.</p>
HTML
,

	pt => <<HTML
<p>Inicie uma sessão para adicionar ou editar produtos.</p>

<form method="post" action="/cgi/session.pl">
Nome de usuário ou endereço de email:<br />
<input type="text" name="user_id" tabindex="1" style="width:220px;" /><br />
Senha<br />
<input type="password" name="password" tabindex="2" style="width:220px;" /><br />
<input type="checkbox" name="remember_me" value="on" tabindex="3" /><label>Lembre-se de mim</label><br />
<input type="submit" tabindex="4" name=".submit" value="Sign-in" class="button small" />
</form>
<p>Ainda não é registrado? <a href="/cgi/user.pl">Criar uma conta</a>.</p>
HTML
,

	pt_pt => <<HTML
<p>Inicie sessão para adicionar ou editar produtos.</p>

<form method="post" action="/cgi/session.pl">
Nome de utilizador ou endereço de e-mail:<br />
<input type="text" name="user_id" tabindex="1" style="width:220px;" /><br />
Palavra-passe<br />
<input type="password" name="password" tabindex="2" style="width:220px;" /><br />
<input type="checkbox" name="remember_me" value="on" tabindex="3" /><label>Manter sessão iniciada</label><br />
<input type="submit" tabindex="4" name=".submit" value="Sign-in" class="button small" />
</form>
<p>Ainda não está registado? <a href="/cgi/user.pl">Criar uma conta</a>.</p>
HTML
,

	ro => <<HTML
<p>Autentificați-vă pentru a adăuga sau modifica produse.</p>

<form method="post" action="/cgi/session.pl">
Numele de utilizator sau adresa de e-mail:<br />
<input type="text" name="user_id" tabindex="1" style="width:220px;" /><br />
Parola<br />
<input type="password" name="password" tabindex="2" style="width:220px;" /><br />
<input type="checkbox" name="remember_me" value="on" tabindex="3" /><label>Ține-mă minte</label><br />
<input type="submit" tabindex="4" name=".submit" value="Autentificare" class="button small" />
</form>
<p>Nu v-ați înregistrat încă? <a href="/cgi/user.pl">Creați-vă contul</a>.</p>
HTML
,

	he => <<HTML
<p>נא להיכנס כדי להוסיף או לערוך מוצרים.</p>

<form method="post" action="/cgi/session.pl">
שם משתמש או כתובת דוא״ל:<br />
<input type="text" name="user_id" tabindex="1" style="width:220px;" /><br />
ססמה<br />
<input type="password" name="password" tabindex="2" style="width:220px;" /><br />
<input type="checkbox" name="remember_me" value="on" tabindex="3" /><label>שמירת הפרטים שלי</label><br />
<input type="submit" tabindex="4" name=".submit" value="כניסה" class="button small" />
</form>
<p>לא נרשמת עדיין? <a href="/cgi/user.pl">ניתן ללחוץ כאן ליצירת חשבון חדש</a>.</p>
HTML
,

	nl => <<HTML
<p>Meld je aan om producten toe te voegen of te bewerken.</p>

<form method="post" action="/cgi/session.pl">
Gebruikersnaam of e-mailadres:<br />
<input type="text" name="user_id" tabindex="1" style="width:220px;" /><br />
Wachtwoord<br />
<input type="password" name="password" tabindex="2" style="width:220px;" /><br />
<input type="checkbox" name="remember_me" value="on" tabindex="3" /><label>Aangemeld blijven</label><br />
<input type="submit" tabindex="4" name=".submit" value="Sign-in" class="button small" />
</form>
<p>Nog niet geregistreerd?<a href="/cgi/user.pl">Creëer uw account</a>.</p>
HTML
,

	nl_be => <<HTML
<p>Meld u aan om producten toe te voegen of te bewerken.</p>

<form method="post" action="/cgi/session.pl">
Gebruikersnaam of e-mailadres:<br />
<input type="text" name="user_id" tabindex="1" style="width:220px;" /><br />
Paswoord<br />
<input type="password" name="password" tabindex="2" style="width:220px;" /><br />
<input type="checkbox" name="remember_me" value="on" tabindex="3" /><label>Aangemeld blijven</label><br />
<input type="submit" tabindex="4" name=".submit" value="Sign-in" class="button small" />
</form>
<p>Nog niet geregistreerd?<a href="/cgi/user.pl">Creëer uw account</a>.</p>
HTML
,

},

top_title => {
	fr => "",
	es => "",
	pt => '',
	he => "",
	nl => "",
	nl_be => "",
},
top_content => {
	fr => <<HTML
HTML
,
	es => <<HTML
HTML
,
	pt => <<HTML
,
	he => <<HTML
HTML
,
	nl => <<HTML
HTML
,
	nl_be => <<HTML
HTML
,
},

on_the_blog_title => {
	fr => "Actualité",
	de => "Neuigkeiten",
	en => "News",
	el => "Νέα",
	es => "Noticias",
	it => "Attualità",
	ar => "الاخبار",
	pt => 'Notícias',
	ro => 'Noutăți',
	he => "חדשות",
	nl => 'Nieuws',
	nl_be => 'Nieuws',
},
on_the_blog_content => {
	en => <<HTML
<p>To learn more about Open Food Facts, visit <a href="http://en.blog.openfoodfacts.org">our blog</a>!</p>
<p>Recent news:</p>
HTML
,
el => <<HTML
<p>Για να μάθετε περισσότερα για το Open Food Facts, επισκεφθείτε <a href="http://en.blog.openfoodfacts.org">our blog</a>!</p>
<p>Πρόσφατα νέα:</p>
HTML
,
	de => <<HTML
<p>Um mehr über Open Food Facts zu erfahren, besuche <a href="http://en.blog.openfoodfacts.org">unseren Blog</a>!</p>
<p>Aktuelle Neuigkeiten:</p>
HTML
,
	fr => <<HTML
<p>Pour découvrir les nouveautés et les coulisses d'Open Food Facts, venez sur <a href="http://fr.blog.openfoodfacts.org">le blog</a> !</p>
<p>C'est nouveau :</p>
HTML
,
	es => <<HTML
<p>Descubre las novedades y muchas cosas más, visitando<a href="http://fr.blog.openfoodfacts.org">el blog (en francés)</a> !</p>
<p>Estas son las novedades:</p>
HTML
,
	it => <<HTML
<p>Per scoprire le novità e il dietro le quinte di Open Food Facts, venite su su<a href="http://fr.blog.openfoodfacts.org">le blog</a> !</p>
<p>Qui sono le novità:</p>
HTML
,
	pt =><<HTML
<p>Para saber mais sobre o Open Food Facts, visite o <a href="http://en.blog.openfoodfacts.org">nosso blog</a>!</p>
<p>Notícias recentes:</p>
HTML
,
	he => <<HTML
<p>למידע נוסף על Open Food Facts, ניתן לבקר ב<a href="http://en.blog.openfoodfacts.org">בלוג שלנו</a>(באנגלית)!</p>
<p>חדשות עדכניות:</p>
HTML
,
	nl => <<HTML
<p>Om meer te weten te komen over Open Food Facts, bezoek <a href="http://en.blog.openfoodfacts.org">onze blog</a>!</p>
<p>Dit is nieuw:</p>
HTML
,

	nl_be => <<HTML
<p>Om meer te weten te komen over Open Food Facts, bezoek <a href="http://en.blog.openfoodfacts.org">onze blog</a>!</p>
<p>Dit is nieuw:</p>
HTML
,

},

bottom_title => {
	fr => "Partez en mission",
	xes => "Participa en la misión",
	xit => "Partite in missione",
	xpt => "Participe na missão",
	ro => 'Participați la misiune',
	he => "הרתמו למשימה",
	nl => 'Neem deel aan de missie',
	nl_be => 'Neem deel aan de missie',
},

bottom_content => {
	fr => <<HTML
<a href="http://fr.openfoodfacts.org/mission/releveur-d-empreintes">
<img src="/images/misc/mission-releveur-d-empreintes.png" width="265" height="222" />
</a>
<p>Contribuez à Open Food Facts en ajoutant des produits et gagnez
des étoiles en remplissant <a href="/missions">les missions</a> !</p>
HTML
,
	xes => <<HTML
<a href="http://es.openfoodfacts.org/mision/determinar-la-huella-de-carbono">
<img src="/images/misc/mision-determinar-la-huella-de-carbono.png" width="265" height="222" />
</a>
<p>Contribuye a Open Food Facts añadiendo productos y gana estrellas participando en <a href="/missions">las misiones</a> !</p>
HTML
,
	xpt => <<HTML
<a href="http://es.openfoodfacts.org/mision/determinar-la-huella-de-carbono">
<img src="/images/misc/mision-determinar-la-huella-de-carbono.png" width="265" height="222" />
</a>
<p>Contribua para o Open Food Facts adicionando produtos e ganhe estrelas participando em <a href="/missions">missões</a> !</p>
HTML
,
	nl => <<HTML
<a href="http://nl.openfoodfacts.org/missie/onthul-de-ecologische-voetafdruk">
<img src="/images/misc/mission-releveur-d-empreintes.png" width="265" height="222" />
</a>
<p>Werk mee aan Open Food Facts door producten toe te voegen en win sterren door deel te nemen <a href="/missions">aan de missies</a> !</p>
HTML
,

	nl_be => <<HTML
<a href="http://nl.openfoodfacts.org/missie/onthul-de-ecologische-voetafdruk">
<img src="/images/misc/mission-releveur-d-empreintes.png" width="265" height="222" />
</a>
<p>Werk mee aan Open Food Facts door producten toe te voegen en win sterren door deel te nemen <a href="/missions">aan de missies</a> !</p>
HTML
,

},

language => {
	fr => 'fr-FR',
	de => 'de-DE',
	en => 'en-US',
	es => 'es-ES',
	el => 'el-GR',
	it => 'it-IT',
	ar => 'ar-AR',
	pt => 'pt-BR',
	pt_pt => 'pt-PT',
	ro => 'ro-RO',
	he => 'he-IL',
	nl => 'nl-NL',
	nl_be => 'nl-BE',
},

facebook_locale => {
	fr => 'fr_FR',
	en => 'en_US',
	es => 'es_ES',
	el => 'el-GR',
	it => 'it_IT',
	de => 'de_DE',
	pt => 'pt_BR',
	pt_pt => 'pt_PT',
	ro => 'ro_RO',
	ar => 'ar_AR',
	he => 'he_IL',
	nl_be => 'nl_BE',
	nl => 'nl_NL',
	#ok what do i put here for brazil ?
#For brazil it is pt_BR
},

username_or_email => {
	fr => 'Nom d\'utilisateur ou adresse e-mail',
	de => 'Benutzername oder E-Mail-Adresse',
	en => 'Username or email address',
	es => 'Nombre de usuario o dirección de correo electrónico',
	el => 'Όνομα χρήστη ή διεύθυνση email',
	it => 'Username o indirizzo e-mail',
	pt => 'Nome de usuário ou endereço de email',
	pt_pt => 'Nome de utilizador ou endereço de e-mail',
	ro => 'Numele de utilizator sau adresa de e-mail',
	he => 'שם משתמש או כתובת דוא״ל',
	nl => 'Gebruikersnaam of e-mailadres',
	nl_be => 'Gebruikersnaam of e-mailadres',
},

password => {
	fr => 'Mot de passe :',
	de => 'Passwort:',
	en => 'Password:',
	es => 'Contraseña:',
	el => 'Κωδικός χρήστη (password)',
	it => 'Password:',
	pt => 'Senha',
	pt_pt => 'Palavra-passe',
	ro => 'Parola',
	he => 'ססמה:',
	nl => 'Wachtwoord',
	nl_be => 'Paswoord',
},

remember_me => {

    ar => 'تذكرني', #ar-CHECK - Please check and remove this comment
	de => 'Angemeldet bleiben',
    cs => 'Zapamatuj si mě', #cs-CHECK - Please check and remove this comment
	es => 'Mantenerme conectado',
	en => 'Remember me',
	it => 'Ricordami',
    fi => 'Muista minut', #fi-CHECK - Please check and remove this comment
	fr => 'Se souvenir de moi',
	el => 'Θυμήσου με',
	he => 'שמירת הפרטים שלי',
    ja => '私を覚えてますか', #ja-CHECK - Please check and remove this comment
    ko => '저를 기억', #ko-CHECK - Please check and remove this comment
	nl => 'Aangemeld blijven',
	nl_be => 'Aangemeld blijven',
    ru => 'Запомнить меня', #ru-CHECK - Please check and remove this comment
    pl => 'Zapamiętaj mnie', #pl-CHECK - Please check and remove this comment
	pt => 'Lembre-se de mim',
	pt_pt => 'Manter sessão iniciada',
	ro => 'Ține-mă minte',
    th => 'จำข้อมูลไว้', #th-CHECK - Please check and remove this comment
    vi => 'Ghi nhớ tôi', #vi-CHECK - Please check and remove this comment
    zh => '记得我', #zh-CHECK - Please check and remove this comment

},

login_and_add_product => {
	fr => 'Se connecter et ajouter le produit',
	de => 'Einloggen und ein Produkt hinzufügen',
	en => 'Sign-in and add the product',
	es => 'Inicia la sesión y añade el producto',
	el => 'Εγγραφείτε και προσθέστε προϊόντα',
	it => 'Connettersi e aggiungere prodotto',
	ar => 'تسجيل الدخول لاضافه منتج',
	pt => 'Ligue-se e adicione o produto',
	pt_pt => 'Inicie sessão e adicione o produto',
	ro => 'Autentificați-vă și adăugați produsul',
	he => 'ניתן להיכנס ולהוסיף את המוצר',
	nl => 'Inloggen en het product toevoegen',
	nl_be => 'Inloggen en het product toevoegen',
},

login_and_edit_product => {
	fr => 'Se connecter et modifier la fiche du produit',
	de => 'Einloggen und das Produkt bearbeiten',
	en => 'Sign-in and edit the product',
	es => 'Inicia la sesión y modifica el producto',
	el => 'Εγγραφείτε και επεξεργαστείτε προϊόντα',
	it => 'Connettersi e modificare la scheda prodotto',
	pt => 'Ligue-se e edite o produto',
	pt_pt => 'Inicie sessão e edite o produto',
	ro => 'Autentificați-vă și modificați produsul',
	he => 'כניסה ועריכת המוצר',
	nl => 'Inloggen en het product bewerken',
	nl_be => 'Inloggen en het product bewerken',
},

pages => {

	ar => "الصفحات:",
	de => 'Seiten: ',
    cs => 'Stránky:', #cs-CHECK - Please check and remove this comment
	es => "Páginas:",
	en => "Pages:",
	it => "Pagine:",
    fi => 'Sivuja:', #fi-CHECK - Please check and remove this comment
	fr => "Pages : ",
	el => 'Σελίδες',
	he => "עמודים:",
    ja => 'ページ：', #ja-CHECK - Please check and remove this comment
    ko => '페이지 :', #ko-CHECK - Please check and remove this comment
	nl => 'Pagina\'s',
	nl_be => 'Pagina\'s',
    ru => 'Страницы:', #ru-CHECK - Please check and remove this comment
    pl => 'Strony:', #pl-CHECK - Please check and remove this comment
	pt => 'Páginas:',
	ro => 'Pagini',
    th => 'หน้า:', #th-CHECK - Please check and remove this comment
    vi => 'Pages:', #vi-CHECK - Please check and remove this comment
    zh => '页数：', #zh-CHECK - Please check and remove this comment

},

previous => {
	fr => "Précédente",
	de => 'Vorherige',
	en => "Previous",
	es => "Anterior",
	el => 'Προηγούμενο',
	it => "Precedente",
	pt => 'Anterior',
	ro => 'Anterior',
	he => "הקודם",
	nl => 'Vorige',
	nl_be => 'Vorige',
},

next => {

    ar => 'التالى', #ar-CHECK - Please check and remove this comment
	de => 'Nächste',
    cs => 'Další', #cs-CHECK - Please check and remove this comment
	es => "Siguiente",
	en => "Next",
	it => "Successiva",
    fi => 'Seuraava', #fi-CHECK - Please check and remove this comment
	fr => "Suivante",
	el => 'Επόμενο',
	he => "הבא",
    ja => '次', #ja-CHECK - Please check and remove this comment
    ko => '다음', #ko-CHECK - Please check and remove this comment
	nl => 'Volgende',
	nl_be => 'Volgende',
    ru => 'Следующий', #ru-CHECK - Please check and remove this comment
    pl => 'Następny', #pl-CHECK - Please check and remove this comment
	pt => 'Próxima',
	ro => 'Următoarea',
    th => 'ถัดไป', #th-CHECK - Please check and remove this comment
    vi => 'Kế tiếp', #vi-CHECK - Please check and remove this comment
    zh => '下一个', #zh-CHECK - Please check and remove this comment

},

page_x_out_of_y => {
	fr => "Page %d sur %d.",
	de => 'Seite %d von %d',
	en => "Page %d out of %d.",
	el => "Σελίδα %d από %d.",
	es => "Página %d de %d.",
	it => "Pagina %d di %d.",
	pt => 'Página %d de %d',
	ro => 'Pagina %d din %d',
	he => "עמוד %d מתוך %d.",
	nl => 'Pagina %d van %d.',
	nl_be => 'Pagina %d van %d.',
},

edit => {
	fr => 'modifier',
	de => 'bearbeiten',
	en => 'edit',
	el => 'επεξεργασία',
	es => 'modificar',
	pt => 'editar',
	ro => 'modificare',
	he => 'עריכה',
	nl => 'bewerken',
	nl_be => 'bewerken',
},

hello => {

	ar => 'مرحبا',
	de => 'Hallo',
    cs => 'Ahoj', #cs-CHECK - Please check and remove this comment
	es => 'Buenos días',
	en => 'Hello',
	it => 'Ciao',
    fi => 'Hei', #fi-CHECK - Please check and remove this comment
	fr => 'Bonjour',
	el => 'Γειά σας',
	he => 'שלום',
    ja => 'こんにちは', #ja-CHECK - Please check and remove this comment
    ko => '안녕하세요.', #ko-CHECK - Please check and remove this comment
	nl => 'Hallo',
	nl_be => 'Hallo',
    ru => 'Здравствуйте', #ru-CHECK - Please check and remove this comment
    pl => 'Halo', #pl-CHECK - Please check and remove this comment
	pt => 'Olá',
	ro => 'Salut',
    th => 'สวัสดี', #th-CHECK - Please check and remove this comment
    vi => 'Xin chào', #vi-CHECK - Please check and remove this comment
    zh => '你好', #zh-CHECK - Please check and remove this comment

},

goodbye => {

	ar => 'مع السلامه!',
	de => 'Auf Wiedersehen !',
    cs => 'Uvidíme se brzy!', #cs-CHECK - Please check and remove this comment
	es => '¡Hasta pronto!',
	en => 'See you soon!',
	it => 'A presto!',
    fi => 'Nähdään pian!', #fi-CHECK - Please check and remove this comment
	fr => 'A bientôt !',
	el => 'Αντίο',
	he => 'להתראות!',
    ja => 'また近いうちにお会いしましょう​​！', #ja-CHECK - Please check and remove this comment
    ko => '곧 당신을 참조하십시오!', #ko-CHECK - Please check and remove this comment
	nl => 'Tot ziens',
	nl_be => 'Tot ziens',
    ru => 'Увидимся!', #ru-CHECK - Please check and remove this comment
    pl => 'Do zobaczenia wkrótce!', #pl-CHECK - Please check and remove this comment
	pt => 'Até logo!',
	ro => 'La revedere!',
    th => 'เห็นคุณเร็ว ๆ นี้!', #th-CHECK - Please check and remove this comment
    vi => 'Hẹn gặp lại!', #vi-CHECK - Please check and remove this comment
    zh => '再见！', #zh-CHECK - Please check and remove this comment

},

sep => {
	fr => ' ',
	en => '',
	es => '',
	el => '',
	pt => '',
	he => '',
	nl => '',
	nl_be => '',
	de => '',
},

connected_with_facebook => {
	fr => "Vous êtes connecté via votre compte Facebook.",
	de => 'Du bist verbunden zu deinem Facebook-Account.',
	en => "You are connected with your Facebook account.",
	es => "Estás conectado a través de tu cuenta en Facebook.",
	el => "Είστε συνδεδεμένοι με τον λογαριασμό σας στο Facebook .",
	it => "Siete connessi attraverso il vostro profilo Facebook",
	pt => 'Você está ligado através de sua conta do Facebook',
	pt_pt => 'Você está autenticado através da sua conta do Facebook',
	ro => 'Sunteți conectat cu contul de Facebook.',
	he => "נכנסת לחשבון הפייסבוק שלך.",
	nl => 'Je bent verbonden via je Facebookaccount',
	nl_be => 'U bent verbonden via uw Facebookaccount',
},

you_are_connected_as_x => {
	fr => "Vous êtes connecté en tant que %s.",
	de => 'Du bist verbunden als %s',
	en => "You are connected as %s.",
	es => "Estás conectado como %s.",
	el => "Είστε συνδεδεμένοι ως %s .",
	it => "Siete connessi come %s.",
	pt => 'Você está ligado como %s',
	pt_pt => 'Você está autenticado como %s.',
	ro => 'Sunteți conectat cu %s.',
	he => "נכנסת בשם %s",
	nl => 'Je bent verbonden als %s',
	nl_be => 'U bent verbonden als %s',
},

signout => {
	fr => "Se déconnecter",
	de => 'Ausloggen',
	en => "Sign-out",
	es => "Cerrar sesión",
	el => "Διαγραφή",
	it => "Disconnettersi",
	pt => 'Sair',
	pt_pt => 'Terminar sessão',
	ro => 'Deconectare',
	he => "יציאה",
	nl => 'Afmelden',
	nl_be => 'Afmelden',
},

error_invalid_address => {
	fr => "Adresse invalide.",
	de => 'Ungültige Adresse.',
	en => "Invalid address.",
	es => "Dirección inválida.",
	el => "Λανθασμένη διεύθυνση .",
	pt => 'Endereço inválido',
	ro => 'Adresă invalidă.',
	he => "הכתובת שגויה.",
	nl => 'Ongeldig adres',
	nl_be => 'Ongeldig adres',
},


name => {
	fr => "Nom",
	en => "Name",
	de => "Name",
	es => "Nombre",
	el => "Όνομα",
	it => "Nome",
	pt => 'Nome',
	ro => 'Nume',
	he => "שם",
	nl => 'Naam',
	nl_be => 'Naam',
},


email => {
	fr => "Adresse e-mail",
	de => "E-Mail-Adresse",
	en => "e-mail address",
	es => "Dirección de correo electrónico",
	el => "Διεύθυνση e-mail",
	it => "Indirizzo e-mail",
	pt => 'Endereço de e-mail',
	ro => 'Adresa de e-mail',
	he => "כתובת דוא״ל",
	nl => 'E-mailadres',
	nl_be => 'E-mailadres',
},

username => {
	fr => "Nom d'utilisateur",
	de => "Benutzername",
	en => "User name",
	el => "Όνομα χρήστη",
	es => "Nombre de usuario",
	it => "Nome dell'utilizzatore",
	pt => 'Nome de usuário',
	pt_pt => 'Nome de utilizador',
	ro => 'Nume de utilizator',
	he => "שם משתמש",
	nl => 'Gebruikersnaam',
	nl_be => 'Gebruikersnaam',
	ru => 'Имя пользователя',
},

username_info => {
	fr => "(lettres non accentuées, chiffres et/ou tirets)",
	de => '(Buchstaben ohne Umlaute, Zahlen und/oder Bindestriche)',
	en => '(non-accented letters, digits and/or dashes)',
	da => '(almindelige bogstaver, tal og/eller bindestreger)',
	es => "(letras no acentuadas, números y/o guiones)",
	el => "(μη τονισμένα γράμματα, αριθμοί και/ή παύλες)",
	it => "(lettere non accentate, numeri e/o trattini)",
	pt => '(letras não acentuadas, digitos e/ou traços)',
	ro => '(litere neaccentuate, cifre și/sau liniuțe)',
	he => "(אותיות לטיניות קטנות, ספרות ו/או מקפים)",
	nl => '(letters zonder accenten, cijfers en/of streepjes)',
	nl_be => '(letters zonder accenten, cijfers en/of streepjes)',
},

twitter => {
	fr => "Nom d'utilisateur Twitter (optionel)",
	de => 'Twitter Benutzername (optional)',
	en => "Twitter username (optional)",
	es => "Nombre de usuario en Twitter (opcional)",
	el => "Twitter username",
	it => "Nome dâutilizzatore su Twitter (facoltativo)",
	pt => 'Nome de usuário no Twitter (opcional)',
	pt_pt => 'Nome de utilizador no Twitter (opcional)',
	ro => 'Numele de utilizator Twitter (opțional)',
	he => "שם משתמש בטוויטר",
	nl => 'Gebruikersnaam Twitter (optioneel)',
	nl_be => 'Gebruikersnaam Twitter (optioneel)',
},

password => {
    ar => 'كلمة السر', #ar-CHECK - Please check and remove this comment
	de => "Passwort",
    cs => 'Heslo', #cs-CHECK - Please check and remove this comment
	es => "Contraseña",
	en => "Password",
	it => "Password",
    fi => 'Salasana', #fi-CHECK - Please check and remove this comment
	fr => "Mot de passe",
	el => "Κωδικός χρήστη",
	he => "ססמה",
    ja => 'パスワード', #ja-CHECK - Please check and remove this comment
    ko => '암호', #ko-CHECK - Please check and remove this comment
	nl => 'Wachtwoord',
	nl_be => 'Paswoord',
    ru => 'Пароль', #ru-CHECK - Please check and remove this comment
    pl => 'Hasło', #pl-CHECK - Please check and remove this comment
	pt => 'Senha',
	ro => 'Parola',
    th => 'รหัสผ่าน', #th-CHECK - Please check and remove this comment
    vi => 'Mật khẩu', #vi-CHECK - Please check and remove this comment
    zh => '密码', #zh-CHECK - Please check and remove this comment
},

password_confirm => {
	fr => "Confirmation du mot de passe",
	de => 'Passwort bestätigen',
	en => "Confirm password",
	el => "Επιβεβαιωστε τον κωδικό χρήστη",
	es => "Confirmar la contraseña",
	it => "Conferma la password",
	pt => 'Confirme sua senha',
	pt_pt => 'Confirme a palavra-passe',
	ro => 'Confirmare parolă',
	he => "אימות הססמה",
	nl => 'Bevestig wachtwoord',
	nl_be => 'Bevestig paswoord',
},

unsubscribe_info => {
	fr => "Vous pouvez vous désabonner de la lettre d'information à tout moment et facilement.",
	de => 'Du kannst die Liste jederzeit deabonnieren.',
	en => "You can unsubscribe from the lists at any time.",
	es => "Puedes darte de baja de las listas cuando lo desees.",
	el => "Μπορείτε να διαγραφείτε από τις λίστες οποιαδήποτε στιγμή.",
	it => "In qualsiasi momento e facilmente potete cancellarvi dalla lettera d'informazioni",
	pt => 'Você pode anular as inscrições das listas a qualquer momento',
	pt_pt => 'Pode anular as suas inscrições nas listas a qualquer momento',
	ro => 'Vă puteți dezabona de la liste în orice moment.',
	he => "ניתן לבטל את המינוי מרשימות אלה בכל עת.",
	nl => 'Je kan zich makkelijk en op elk moment uitschrijven voor de nieuwsbrief',
	nl_be => 'U kan zich makkelijk en op elk moment uitschrijven voor de nieuwsbrief',
},

website => {
	fr => "Adresse de blog ou de site web",
	de => 'Seiten- oder Blogadresse',
	en => "Site or blog address",
	el => "Ιστοσελίδα ή διεύθυνση ιστολογίου (blog)",
	es => "Dirección del blog o del sitio web",
	it => "Indirizzo del blog o del sito web",
	pt => 'Endereço do seu site ou blog',
	ro => 'Adresă site sau blog',
	he => "כתובת אתר או בלוג",
	nl => 'Adres van website of blog',
	nl_be => 'Adres van website of blog',
},


about => {
	fr => "Présentation",
	de => 'Über uns',
	en => 'About me',
	da => 'Om mig',
	el => "Για εμάς",
	es => "Presentación",
	it => "Mi presento",
	pt => 'Sobre mim',
	ro => 'Despre mine',
	he => "פרטים עלי",
	nl => 'Over mij',
	nl_be => 'Over mij',
	zh => '个人信息',
	ru => 'Обо мне',
},

error_no_name => {
	fr => "Vous devez entrer un nom, prénom ou pseudonyme.",
	de => 'Sie müssen einen Namen oder Spitznamen angeben.',
	en => "You need to enter a name or nickname.",
	el => "Πρέπει να εισάγετε ένα όνομα ή ψευδώνυμο.",
	es => "Debes escribir un nombre o seudónimo.",
	it => "Immetti nome, cognome o pseudonimo",
	pt => 'Você precisa incluir um nome ou apelido',
	pt_pt => 'Você precisa de inserir um nome ou apelido',
	ro => 'Trebuie să introduceți un nume sau un pseudonim.',
	he => "עליך לרשום שם או כינוי.",
	nl => 'Vul een naam of pseudoniem in',
	nl_be => 'Vul een naam of bijnaam in',
},

error_invalid_email => {
	fr => "L'adresse e-mail est invalide.",
	de => 'Ungültige E-Mail-Adresse',
	en => "Invalid e-mail address",
	el => "Άκυρη διεύθυνση e-mail",
	es => "La dirección de correo electrónico no es válida",
	it => "Indirizzo e-mail non valido",
	pt => 'Endereço de e-mail inválido',
	ro => 'Adresă de e-mail invalidă',
	he => "כתובת הדוא״ל שגויה",
	nl => 'Ongeldig e-mailadres',
	nl_be => 'Ongeldig e-mailadres',
},


error_email_already_in_use => {
	fr => "L'adresse e-mail est déjà utilisée par un autre utilisateur. Peut-être avez-vous déjà un autre compte ? Vous pouvez <a href=\"/cgi/reset_password.pl\">réinitialiser le mot de passe</a> de votre autre compte.",
	de => 'Die angegebene E-Mail-Adresse ist bereits in Verwendung. Möglicherweise habane Sie schon ein Konto? Sie können das Passwort ihres Kontos <a href=\"/cgi/reset_password.pl\">zurücksetzen</a>.',
	en => "The e-mail address is already used by another user. Maybe you already have an account? You can  <a href=\"/cgi/reset_password.pl\">reset the password</a> of your other account.",
	el => "Η διεύθυνση e-mail χρησιμοποιείται ήδη από άλλο χρήστη. Μήπως έχετε ήδη λογαριασμό; Μπορείτε  <a href=\"/cgi/reset_password.pl\">reset the password</a> of your other account.",
	es => "La dirección de correo electrónico ya está siendo utilizada por otro usuario. Tal vez, haya creado ya una cuenta. Aquí puede  <a href=\"/cgi/reset_password.pl\">restablecer la contraseña</a> de la otra cuenta.",
	it => "L'inidirzzo e-mail è già in uso. Hai un altro account di posta? Puoi <a href=\"/cgi/reset_password.pl\">reinserire la password<a> dell'altro account.",
	pt => 'Esse endereço de email já está sendo utilizado por outro usuário. Talvez você já tenha uma conta? Você pode <a href=\"/cgi/reset_password.pl\">modificar a senha</a> da sua outra conta.',
	pt_pt => 'Este endereço de email já está a ser utilizado por outro utilizador. Talvez já tenha uma conta? Pode <a href=\"/cgi/reset_password.pl\">alerar a palavra-passe</a> da sua outra conta.',
	ro => 'Adresa de email este deja folosită de către un alt utilizator. Poate că deja aveți un cont? Vă puteți <a href=\"/cgi/reset_password.pl\">reseta parola</a> celuilalt cont.',
	he => "כתובת הדוא״ל כבר בשימוש על־ידי משתמש אחר. אולי כבר יש לך חשבון? ניתן <a href=\"/cgi/reset_password.pl\">לאפס את הססמה</a> לחשבון שלך.",
	nl_be => "Dit e-mailadres wordt al gebruikt door een andere gebruiker. Misschien heb je al een account? Je kan het paswoord van je andere account <a href=\"/cgi/reset_password.pl\">resetten</a>.",
	nl => "Dit e-mailadres wordt al gebruikt door een andere gebruiker. Misschien heeft u al een account? U kunt het wachtwoord van uw andere account  <a href=\"/cgi/reset_password.pl\">resetten</a>.",
},

error_no_username => {
	fr => "Vous devez entrer un nom d'utilisateur.",
	en => "You need to enter a user name",
	el => "Πρέπει να εισάγετε ένα όνομα χρήστη",
	de => "Sie müssen einen Benutzernamen eingeben",
	es => "Necesitas introducir un nombre de usuario",
	it => "Inserisci il nome dell'utilizzatore/username",
	pt => 'Você precisa incluir um nome de usuário',
	pt_pt => 'Precisa de inserir um nome de utilizador',
	ro => 'Trebuie să introduceți un nume de utilizator',
	he => "עליך לרשום שם משתמש",
	nl => 'Je moet een gebruikersnaam invoeren',
	nl_be => 'U moet een gebruikersnaam ingeven',
},

error_username_not_available => {
	fr => "Ce nom d'utilisateur existe déjà, choisissez en un autre.",
	de => 'Dieser Benutzername wird bereits benutzt, bitte wählen Sie einen anderen.',
	en => "This username already exists, please choose another.",
	el => "Αυτό το όνομα χρήστη χρησιμοποιείται ήδη, παρακαλώ επιλέξτε κάποιο άλλο",
	es => "El nombre de usuario que ha escogido ya existe, por favor escoja otro.",
	it => "Questo username esiste già, per favore prova con un altro",
	pt => 'Esse nome de usuário já existe, por favor escolha outro',
	pt_pt => 'Este nome de utilizador já existe, escolha outro por favor',
	ro => 'Acest nume de utilizator există deja, vă rog alegeți altul.',
	he => "שם משתמש זה כבר קיים, נא לבחור באחד אחר.",
	nl => 'Deze gebruikersnaam bestaat reeds, kies een andere',
	nl_be => 'Deze gebruikersnaam bestaat reeds, gelieve een andere te kiezen',
	ru => 'Это имя пользователя уже существует, выберите другое.',
},

error_invalid_username => {
	fr => "Le nom d'utilisateur doit être composé de lettres minuscules sans accents, de tirets et/ou de chiffres.",
	de => 'Der Benutzername darf nur Buchstaben ohne Umlaute, Zahlen und Bindestriche enthalten.',
	en => "The user name must contain only unaccented letters, digits and dashes.",
	el => "Το όνομα χρήστη πρέπει να περιέχει μόνο μη τονισμένες λέξεις, ψηφία και παύλες",
	es => "El nombre de usuario debe contener sólo caracteres sin acentuar, dígitos y guiones.",
	it => "Lo username può contenere solo caratteri senza accento, trattini e cifre",
	pt => "O nome de usuário deve conter somente letras não acentuadas, dígitos e traços.",
	pt_pt => "O nome de utilizador deve conter apenas letras não acentuadas, dígitos e traços.",
	ro => 'Numele de utilizator trebuie să conțină doar litere neaccentuate, cifre și liniuțe.',
	he => "שם המשתמש יכול להכיל רק אותיות לטיניות קטנות, ספרות ומקפים.",
	nl => 'De gebruikersnaam mag enkel kleine letters zonder accenten, streepjes en/of cijfers bevatten',
	nl_be => 'De gebruikersnaam mag enkel kleine letters zonder accenten, streepjes en/of cijfers bevatten',
},

error_invalid_password => {
	fr => "Le mot de passe doit comporter au moins 6 caractères.",
	de => "Das Passwort muss mindestens 6 Zeichen lang sein.",
	en => "The password needs to be a least 6 characters long.",
	el => "Ο κωδικός χρήστη (password) πρέπει να περιέχει τουλάχιστον 6 χαρακτήρες",
	es => "La contraseña debe contener al menos 6 caracteres.",
	it => "La password deve contenere almeno 6 caratteri",
	pt => 'A senha deve conter pelo menos 6 caracteres',
	pt_pt => 'A palavra-passe deve conter pelo menos 6 caracteres',
	ro => 'Parola trebuie să fie lungă de cel puțin 6 caractere.',
	he => "הססמה חייבת להיות באורך של 6 תווים לפחות.",
	nl => 'Het wachtwoord moet uit minstens 6 tekens bestaan',
	nl_be => 'Het paswoord moet uit minstens 6 tekens bestaan',
},

error_different_passwords => {
	fr => "Le mot de passe et sa confirmation sont différents.",
	de => 'Die Passwort und die Wiederholung müssen übereinstimmen.',
	en => "The password and confirmation password are different.",
	es => "La contraseña y su confirmación son diferentes.",
	el => "To password και το confirmation password είναι διαφορετικά",
	it => "La password non corrisponde",
	pt => 'A senha e a senha de confirmação são diferentes',
	pt_pt => 'As palavras-passe são diferentes.',
	ro => 'Parola și parola de confirmare sunt diferite.',
	he => "הססמה ואימות הססמה אינם זהים.",
	nl => 'Het wachtwoord stemt niet overeen met de bevestiging',
	nl_be => 'Het paswoord stemt niet overeen met de bevestiging',
},

error_invalid_user => {
	fr => "Impossible de lire l'utilisateur.",
	de => 'Ungültiger Benutzer',
	en => "Invalid user.",
	el => "Μη έγκυρος χρήστης.",
	es => "Usuario no válido.",
	it => "Utilizzatore non valido",
	pt => 'Usuário inválido',
	pt_pt => 'Utilizador inválido',
	ro => 'Utilizator invalid.',
	he => "משתמש שגוי.",
	nl => 'Ongeldige gebruiker',
	nl_be => 'Ongeldige gebruiker',
},

error_no_permission => {
	fr => "Permission refusée.",
	en => "Permission denied.",
	el => "Άρνηση άδειας.",
	de => "Zugriff verweigert.",
	es => "Permiso denegado.",
	it => "Permesso rifiutato",
	pt => "Permissão negada",
	ro => 'Acces refuzat.',
	he => "ההרשאה נדחתה",
	nl => 'Toegang geweigerd',
	nl_be => 'Toegang geweigerd',
},

correct_the_following_errors => {
	fr => "Merci de corriger les erreurs suivantes :",
	en => "Please correct the following errors:",
	el => "Παρακαλώ διορθώστε τα παρακάτω σφάλματα:",
	de => "Bitte korrigieren Sie die folgenden Fehler:",
	es => "Por favor, corrija los siguientes errores:",
	it => "Correggere gli errori seguenti, grazie",
	pt => 'Por favor corrija os seguintes erros:',
	ro => 'Vă rugăm corectați erorile următoare:',
	he => "נא לתקן את השגיאות הבאות:",
	nl => 'Gelieve de volgende fouten te verbeteren',
	nl_be => 'Gelieve de volgende fouten te verbeteren',
},

error_database => {
	fr => "Une erreur est survenue en lisant la base de données, essayez de recharger la page.",
	de => "Beim Lesen der Daten ist ein Fehler aufgetreten, bitte aktualisieren Sie die Seite.",
	en => "An error occured while reading the data, try to refresh the page.",
	el => "Σφάλμα κατά την ανάγνωση των δεδομένων, προσπαθήστε να ξαναφορτώσετε τη σελίδα.",
	es => "Se produjo un error durante la lectura de la base de datos, intente recargar la página.",
	it => "Un errore è occorso durante la lettura dei dati, prova a ricaricare la pagina",
	pt => "Ocorreu um erro durante a leitura dos dados, tente atualizar a página.",
	ro => "A apărut o eroare în timp ce citeam datele, încercați să reîncărcați pagina.",
	he => "אירעה שגיאה בעת קריאת הנתונים, נא לנסות לרענן את העמוד.",
	nl => 'Er is een fout opgetreden tijdens het lezen van de gegevens, gelieve de pagina opnieuw te laden',
	nl_be => 'Er is een fout opgetreden tijdens het lezen van de gegevens, gelieve de pagina opnieuw te laden',
	# zh => '',
	ru => 'Произошла ошибка при чтении данных, попробуйте обновить страницу.',
},

no_products => {
	fr => "Pas de produits.",
	de => "Keine Produkte.",
	en => "No products.",
	el => "Κανένα προϊόν.",
	es => "No hay productos.",
	it => "Nessun prodotto",
	pt => "Não há produtos.",
	ro => "Nici un produs.",
	he => "אין מוצרים.",
	nl => 'Geen producten',
	nl_be => 'Geen producten',
	# zh => '',
},

'1_product' => {
	fr => "1 produit",
	de => "1 Produkt",
	en => "1 product",
	da => '1 produkt',
	el => "1 προϊόν",
	es => "1 producto",
	it => "1 prodotto",
	pt => "1 produto",
	ro => "1 produs",
	he => "מוצר 1",
	nl => "1 product",
	nl_be => "1 product",
	ru => '1 продукт',
},

n_products => {

    ar => '%d المنتجات', #ar-CHECK - Please check and remove this comment
	de => "%d Produkte",
    cs => '%d produktů', #cs-CHECK - Please check and remove this comment
	es => "%d productos",
	en => "%d products",
	it => "%d prodotti",
    fi => '%d tuotteet', #fi-CHECK - Please check and remove this comment
	fr => "%d produits",
	el => "%d Προϊόντα",
	he => "%d מוצרים",
    ja => '%d 製品', #ja-CHECK - Please check and remove this comment
    ko => '%d 제품', #ko-CHECK - Please check and remove this comment
	nl => "%d producten",
	nl_be => "%d producten",
    ru => '%d продуктов', #ru-CHECK - Please check and remove this comment
    pl => '%d produkty', #pl-CHECK - Please check and remove this comment
	pt => "%d produtos",
	ro => "%d produse",
    th => '%d ผลิตภัณฑ์', #th-CHECK - Please check and remove this comment
    vi => '%d sản phẩm', #vi-CHECK - Please check and remove this comment
    zh => '%d 个产品', #zh-CHECK - Please check and remove this comment

},

signin_before_submit => {
	fr => "Si vous êtes déjà inscrit sur <SITE>, identifiez-vous (\"Se connecter\" dans la colonne de droite) avant de remplir ce formulaire.",
	de => "Wenn Sie bereits ein Benutzerkonto auf <SITE> haben, melden Sie sich bitte an, bevor sie das Formular ausfüllen.",
	en => "If you already have an account on <SITE>, please sign-in before filling this form.",
	el => "Εαν έχετε ήδη ένα λογαριασμό στο <SITE>, παρακαλώ εγγραφείτε πριν συμπληρώσετε αυτή τη φόρμα.",
	es => "Si ya tiene una cuenta en <SITE>, por favor, inicie la sesión antes de rellenar este formulario.",
	it => "Se siete già iscritti su <SITE>, per favore identificatevi prima di compilare questo formulario",
	pt =>"Se você já possui uma conta no <SITE>, por favor entre antes de preencher este formulário.",
	pt_pt =>"Se já possui uma conta no <SITE>, inicie a sessão antes de preencher este formulário.",
	ro => "Dacă deja aveți un cont pe <SITE>, vă rog autentificați-vă înainte de a completa acest formular.",
	he => "אם כבר יש לך חשבון ב־<SITE>, נא להיכנס בטרם מילוי הטופס הזה.",
	nl => "Indien je al een account hebt op <SITE>, meld je dan eerst aan voordat je dit formulier invult",
	nl_be => "Indien u al een account heeft op <SITE>, gelieve u dan eerst aan te melden voordat u dit formulier invult",
	# zh => '',
},


error_bad_login_password => {
	fr => "Mauvais nom d'utilisateur ou mot de passe. <a href=\"/cgi/reset_password.pl\">Mot de passe oublié ?</a>",
	de=> "Ungültiger Benutzername oder Passwort. <a href=\"/cgi/reset_password.pl\">Passwort vergessen?</a>",
	en => "Incorrect user name or password. <a href=\"/cgi/reset_password.pl\">Forgotten password?</a>",
	el => "Λάθος όνομα χρήστη ή κωδικός πρόσβασης. <a href=\"/cgi/reset_password.pl\">Ξεχάσατε το κωδικό χρήστη;</a>",
	es => "Nombre de usuario o contraseña incorecto/a. <a href=\"/cgi/reset_password.pl\">¿Olvidaste tu contraseña?</a>",
	it => "Username o password sbagliate.  <a href=\"/cgi/reset_password.pl\">Password dimenticata? </a>",
	pt =>"Nome de usuário ou senha incorretos. <a href=\"/cgi/reset_password.pl\">Esqueceu sua senha?</a>",
	pt_pt =>"Nome de utilizador ou palavra-passe incorretos. <a href=\"/cgi/reset_password.pl\">Esqueceu-se da sua palavra-passe?</a>",
	ro => 'Nume de utilizator sau parolă incorectă. <a href=\"/cgi/reset_password.pl\">Parolă uitată?</a>',
	he => "שם המשתמש או הססמה שגויים. <a href=\"/cgi/reset_password.pl\">שכחת את הססמה?</a>",
	nl => "Gebruikersnaam of wachtwoord ongeldig. <a href=\"/cgi/reset_password.pl\">Wachtwoord vergeten?</a>",
	nl_be => "Gebruikersnaam of paswoord ongeldig. <a href=\"/cgi/reset_password.pl\">Paswoord vergeten?</a>",
	# zh => '',
},

subscribe => {
	fr => 'S\'abonner',
	de => 'Abonnieren',
	en => 'Subscribe',
	el => "Εγγραφείτε",
	es => 'Suscribir',
	it => 'Aderire',
	pt => 'Subscrever',
	ro => 'Abonare',
	he => 'מינוי',
	nl => 'Abonneren',
	nl_be => 'Abonneren',
	# zh => '',
},

unsubscribe => {
	fr => 'Se désabonner',
	de => 'Deabonnieren',
	en => 'Unsubscribe',
	el => "Διαγραφείτε",
	es => 'Darse de baja',
	it => 'Cancellarsi',
	pt => 'Desinscrever',
	ro => 'Dezabonare',
	he => 'ביטול המינוי',
	nl => 'Uitschrijven',
	nl_be => 'Uitschrijven',
	# zh => '',
},

_and_ => {
	fr => ' et ',
	de => ' und ',
	en => ' and ',
	da => ' og ',
	el => ' και ',
	es => ' y ',
	cs => ' a ',
	it => ' e ',
	pt => ' e ',
	ro => ' și ',
	he => ' וגם ',
	nl => ' en ',
	nl_be => ' en ',
	zh => ' 以及 ',
	ru => ' и ',
	id => ' dan ',
},

reset_password =>  {
	fr => 'Réinitialiser le mot de passe',
	de => 'Passwort zurücksetzen',
	en => 'Reset password',
	el => 'Ανάκληση κωδικού χρήστη ',
	es => 'Restablecer la contraseña',
	it => 'Modificare la password',
	pt => 'Alterar a palavra-passe',
	ro => 'Resetare parolă',
	he => 'איפוס הססמה',
	nl => 'Wachtwoord resetten',
	nl_be => 'Paswoord resetten',
},

userid_or_email => {
	fr => 'Nom d\'utilisateur ou adresse e-mail : ',
	de => 'Benutzername oder E-Mail-Adresse: ',
	en => 'Username or e-mail address: ',
	el => ' Όνομα χρήστη ή διεύθυνση e-mail: ',
	es => 'Nombre de usuario o dirección de correo electrónico: ',
	it => 'Nome d\'utilizzatore o indirizzo e-mail',
	pt => 'Nome de usuário ou endereço de e-mail',
	pt_pt => 'Nome de utilizador ou endereço de e-mail',
	ro => 'Nume de utilizator sau adresa de e-mail',
	he => 'שם משתמש או כתובת דוא״ל: ',
	nl => 'Gebruikersnaam of e-mailadres: ',
	nl_be => 'Gebruikersnaam of e-mailadres: ',
},

reset_password_reset =>  {
	fr => 'Votre mot de passe a été changé. Vous pouvez maintenant vous identifier avec ce mot de passe.',
	de => 'Ihr Passwort wurden geändert. Sie können sich nun mit dem neuen Passwort anmelden.',
	en => 'Your password has been changed. You can now log-in with this password.',
	el => 'Ο κωδικός χρήστη έχει αλλάξει. Μπορείτε τώρα να συνδεθείτε με τον νέο κωδικό ',
	es => 'La contraseña ha sido cambiada correctamente. Ahora puede iniciar la sesión con la nueva contraseña.',
	it => 'La password è stata modificata. Potete ora identificarvi con la nuova password.',
	pt => 'Sua senha foi modificada. Você pode iniciar sua sessão com a nova senha.',
	pt_pt => 'A sua palavra-passe foi modificada. Pode iniciar a sua sessão com a nova palavra-passe.',
	ro => 'Parola a fost schimbată. De acum vă puteți autentifica cu această parolă.',
	he => 'הססמה שלך הוחלפה. מעתה ניתן להיכנס עם ססמה זו.',
	nl => 'Je wachtwoord werd gewijzigd. Je kan zich nu aanmelden met het nieuwe wachtwoord.',
	nl_be => 'Uw paswoord werd gewijzigd. U kan zich nu aanmelden met het nieuwe paswoord.',
	ru => 'Ваш пароль изменён. Теперь можете войти с этим паролем.',
},

reset_password_send_email =>  {
	fr => 'Un e-mail avec un lien pour vous permettre de changer le mot de passe a été envoyé à l\'adresse e-mail associée à votre compte.',
	de => 'Eine E-Mail mit einem Zurücksetzungslink für Ihr Passwort wurde zu der von Ihnen angegebenen E-Mail-Adresse verschickt.',
	en => 'An email with a link to reset your password has been sent to the e-mail address associated with your account.',
	el => 'Ένα email με το link για την ανάκληση του κωδικού χρήστη σας έχει σταλεί στην διεύθυνση ηλεκτρονικού ταχυδρομείου που έχετε συνδέσει σε αυτό το λογαριασμό.  ',
es => 'Se ha enviado un correo electrónico con un enlace para que pueda cambiar la contraseña asociada a su cuenta.',
	it => 'Una mail con un link per consentirvi di cambiare la password è stata inviata all\' indirizzo e-mail associato al vostro account.' ,
	pt => 'Um e-mail com um link para repor a sua senha foi enviado para o endereço de e-mail associado com a sua conta',
	ro => 'Un e-mail cu un link pentru resetarea parolei v-a fost trimis la adresa de e-mail asociată cu contul dumneavoastră.',
	he => 'הודעה עם קישור לאיפוס הססמה שלך נשלחה לכתובת הדוא״ל המשויכת עם החשבון שלך.',
	nl => 'Er werd een e-mail verstuurd met een link om je paswoord te resetten naar het e-mailadres dat verbonden is aan je account.',
	nl_be => 'Er werd een e-mail verstuurd met een link om uw paswoord te resetten naar het e-mailadres dat verbonden is aan uw account.',
	ru => 'Письмо со ссылкой для сброса пароля выслано на адрес эл. почты, связанный с,вашей учётной записью.',
},

reset_password_send_email_msg =>  {
	fr => 'Si vous avez oublié votre mot de passe, indiquez votre nom d\'utilisateur ou votre e-mail pour recevoir les instructions pour le réinitialiser.',
	en => 'If you have forgotten your password, fill-in your username or e-mail address to receive instructions for resetting your password.',
	el => 'Αν έχετε ξεχάσει τον κωδικό χρήστη. συμπληρώστε το όνομα χρήστη ή τη διεύθυνση ηλεκτρονικού ταχυδρομείου προκειμένου να λάβετε οδηγίες ανάκλησης του κωδικού σας.',
es => 'Si ha olvidado su contraseña, introduzca su nombre de usuario o su dirección de correo electrónico donde recibirá las instrucciones necesarias para restablecerla.',
	it => 'Se avete scordato la password, indicate il vostro username o la vostra e-mail per ricevere le istruzioni per reimpostarla.',
	pt => 'Caso você tenha esquecido sua senha, preencha seu nome de usuário ou endereço de e-mail para receber instruções de como modificar a sua senha.',
	pt_pt => 'Caso se tenha esquecido da sua palavra-passe, preencha o seu nome de utilizador ou endereço de e-mail para receber instruções para repor mesma.',
	ro => 'Dacă v-ați uitat parola, completați numele de utilizator sau adresa de e-mail pentru a primi instrucțiuni despre resetarea parolei.',
	he => 'אם שכחת את הססמה שלך, נא למלא את שם המשתמש או את כתובת הדוא״ל שלך כדי לקבל הנחיות לאיפוס הססמה שלך.',
	nl => 'Indien je je paswoord vergeten bent, vul dan je gebruikersnaam of e-mailadres in en ontvang instructies om je paswoord te resetten.',
	nl_be => 'Indien u uw paswoord vergeten bent, vul dan uw gebruikersnaam of e-mailadres in en ontvang instructies om uw paswoord te resetten.',
	de => 'Falls Sie Ihr Passwort vergessen haben, geben Sie bitte Ihren Benutzernamen oder Ihre E-Mail-Adresse ein, um die Anweisungen für das Zurücksetzen Ihres Passworts zu bekommen',
},

reset_password_reset_msg =>  {
	fr => 'Entrez un nouveau mot de passe.',
	en => 'Enter a new password.',
	el => 'Εισάγετε νέο κωδικό χρήστη.',
	es => 'Introduzca una nueva contraseña.',
	it => 'Introdurre una nuova password' ,
	ar => 'ادخل كلمه مرور جديده',
	pt => 'Insira a nova senha',
	pt_pt => 'Insira a nova palavra-passe',
	ro => 'Introduceți o parolă nouă.',
	he => 'נא לרשום ססמה חדשה.',
	nl => 'Voer een nieuw paswoord in',
	nl_be => 'Voer een nieuw paswoord in',
	de => 'bitte ein anderes Passwort einfügen',
},

error_reset_unknown_email =>  {
	fr => 'Il n\'existe pas de compte avec cette adresse e-mail',
	en => 'There is no account with this email',
	el => 'Δεν υπάρχει λογαριασμός με αυτό το email',
	es => 'No existe ninguna cuenta asociada a este correo electrónico',
	it => 'Non esiste un account associato a questa e-mail',
	pt => 'Nâo há conta associada a esse e-mail',
	pt_pt => 'Nâo há conta associada a este e-mail',
	ro => 'Nu există nici un cont cu această adresă de e-mail',
	he => 'אין חשבון עם כתובת דוא״ל שכזו',
	nl => 'Er is geen account aan dit e-mailadres verbonden',
	nl_be => 'Er is geen account aan dit e-mailadres verbonden',
	de => 'Kein Benutzerkonto mit dieser E-Mail-Adresse ist vorhanden',
	ru => 'Нет учётной записи с этим адресом эл. почты',
},

error_reset_unknown_id =>  {
	fr => 'Ce nom d\'utilisateur n\'existe pas.',
	en => 'This username does not exist.',
	el => 'Αυτό το όνομα χρήστη δεν υπάρχει.',
	es => 'El nombre de usuario no existe.',
	it => 'Questo nome d\'utilizzatore/username non esiste',
	ar => 'اسم المستخدم غير موجود',
	pt => 'Esse nome de usuário não existe.',
	pt_pt => 'Este nome de utilizador não existe.',
	ro => 'Acest nume de utilizator nu există.',
	he => 'שם משתמש זה לא קיים.',
	nl => 'Deze gebruikersnaam bestaat niet',
	nl_be => 'Deze gebruikersnaam bestaat niet',
	de => 'Dieser Benutzername ist nicht gültig',
	ru => 'Такого имени пользователя не существует.',
},

error_reset_invalid_token =>  {
	fr => 'Le lien de réinitialisation de mot de passe est invalide ou a expiré.',
	en => 'The reset password link is invalid or has expired.',
	el => 'Ο σύνδεσμος ανάκτησης κωδικού χρήστη δεν είναι έγκυρος ή έχει λήξει.',
	es => 'El enlace para restablecer la contraseña no es válido o ha caducado.',
	it => 'Il link per resettare la password non è valido oppure è scaduto' ,
	pt => 'O link para modificar a senha é inválido ou expirou.',
	pt_pt => 'O link para modificar a palavra-passe é inválido ou expirou.',
	ro => 'Link-ul pentru resetarea parolei este invalid sau a expirat.',
	he => 'הקישור לאיפוס הססמה שגוי או שתוקפו פג.',
	nl => 'De link om je paswoord te resetten is ongeldig of bestaat niet meer',
	nl_be => 'De link om uw paswoord te resetten is ongeldig of bestaat niet meer',
	de => 'Das Link für das Zurücksetzen Ihres Passworts ist entweder ungültig oder ist abgelaufen',
},

error_reset_already_connected =>  {
	fr => 'Vous avez déjà une session ouverte.',
	en => 'You are already signed in.',
	el => 'Είσαστε ήδη εγγεγραμμένος.',
	es => 'Ya tiene una sesión abierta.',
	it => 'Avete già una sessione aperta',
	pt => 'Você já tem uma sessão aberta',
	pt_pt => 'Você já tem uma sessão iniciada',
	ro => 'Sunteți deja autentificați',
	he => 'כבר נכנסת.',
	nl => 'Je bent reeds aangemeld',
	nl_be => 'U bent reeds aangemeld',
	de => 'Sie sind schon eingeloggt',
	ru => 'Вы уже вошли.',
},

lang => {
	fr => 'Langue principale',
	en => 'Main language',
	el => 'Κύρια γλώσσα',
	es => 'Idioma principal',
	it => 'Lingua principale',
	ar => 'اللغه الرئيسيه',
	pt => 'Idioma principal',
	ro => 'Limba principală',
	he => 'השפה העיקרית',
	nl => 'Hoofdtaal',
	nl_be => 'Hoofdtaal',
	de => 'Hauptsprache',
},

lang_note => {
	fr => 'Langue la plus utilisée et la plus mise en avant sur le produit',
	en => 'Language most present and most highlighted on the product',
	el => 'Κύρια γλώσσα του προϊόντος',
	es => 'Idioma más utilizado en la mayor parte del producto',
	it => 'La lingua maggiormente utilizzata sul prodotto',
	pt => 'Idioma mais presente no produto',
	ro => 'Limba cea mai prezentă și mai evidentă pe produs',
	he => 'השפה המשמעותית והמודגשת ביותר על המוצר',
	nl => 'De taal die het meest gebruikt wordt op het product',
	nl_be => 'De taal die het meest gebruikt wordt op het product',
	de => 'Lieblingssprache für dieses Produkt',
},

expiration_date => {

    ar => 'أفضل قبل التاريخ', #ar-CHECK - Please check and remove this comment
	de => 'Mindestens haltbar bis Datum',
    cs => 'Nejlepší před datem', #cs-CHECK - Please check and remove this comment
	es => 'Fecha límite de consumo',
	en => 'Best before date',
	da => 'Mindst holdbar til',
	it => 'Da utilizzare entro',
    fi => 'Parasta ennen', #fi-CHECK - Please check and remove this comment
	fr => 'Date limite de consommation',
	el => 'Ανάλωση κατά προτίμηση',
	he => 'תאריך אחרון לשימוש',
    ja => '賞味期限', #ja-CHECK - Please check and remove this comment
    ko => '날짜 이전 최고', #ko-CHECK - Please check and remove this comment
	nl => 'Houdbaarheidsdatum',
	nl_be => 'Houdbaarheidsdatum',
	ru => 'Срок годности',
    pl => 'Najlepiej spożyć przed datą', #pl-CHECK - Please check and remove this comment
	pt => 'Data de validade',
	ro => 'A se consuma de preferință înainte de',
    th => 'ที่ดีที่สุดก่อนวันที่', #th-CHECK - Please check and remove this comment
    vi => 'Tốt nhất trước ngày', #vi-CHECK - Please check and remove this comment
    zh => '此日期前最佳', #zh-CHECK - Please check and remove this comment

},

expiration_date_note => {
	fr => "La date limite permet de repérer les changements des produits dans le temps et d'identifier la plus récente version.",
	en => "The expiration date is a way to track product changes over time and to identify the most recent version.",
	el => "H ημερομηνία λήξης είναι ένας τρόπος παρακολούθησης των αλλαγών σε ένα προϊόν συναρτήσει του χρόνου και εξεύρεσης της πιο πρόσφατης παρτίδας.",
	es => "La fecha límite de consumo permite seguir los cambios que se han ido produciendo en los productos a lo largo del tiempo y también identificar la versión más reciente.",
	it => "La data di scadenza permette di tracciare le modifiche dei prodotti nel tempo e riconoscere la versione più recente.",
	pt => 'A data de validade é uma forma de rastrear mudanças no produto ao longo do tempo e identificar sua versão mais recente.',
	pt_pt => 'A data de validade é uma forma de registar mudanças no produto ao longo do tempo e identificar a sua versão mais recente.',
	ro => 'Data de expirare este o modalitate de a urmări schimbările produsului de-a lungul timpului și pentru a identifica cea mai recentă versiune.',
	he => "תאריך התפוגה היא דרך נוספת לעקוב אחר שינויים במוצרים במשך הזמן ולזהות את הגרסה העדכנית ביותר.",
	nl => 'Dankzij de houdbaarheidsdatum is het mogelijk om veranderingen van het product over een bepaalde periode waar te nemen en om de meest recente versie te bepalen.',
	nl_be => 'Dankzij de houdbaarheidsdatum is het mogelijk om veranderingen van het product over een bepaalde periode waar te nemen en om de meest recente versie te bepalen.',
	de => 'Das Ablaufdatum ist eine Möglichkeit, um Produktänderungen im Verlauf der Zeit zu folgen, und nun die aktuellste Version zu identifizieren.',
},

product_name => {

    ar => 'اسم المنتج', #ar-CHECK - Please check and remove this comment
	de => 'Produktname',
    cs => 'Jméno výrobku', #cs-CHECK - Please check and remove this comment
	es => "Nombre del producto",
	en => "Product name",
	da => 'Produktnavn',
	it => "Nome del prodotto",
    fi => 'Tuotteen nimi', #fi-CHECK - Please check and remove this comment
	fr => "Nom du produit",
	el => "Όνομα προϊόντος",
	he => "שם המוצר",
    ja => '製品名', #ja-CHECK - Please check and remove this comment
    ko => '제품 이름', #ko-CHECK - Please check and remove this comment
	nl => 'Productnaam',
	nl_be => 'Productnaam',
    ru => 'Наименование товара', #ru-CHECK - Please check and remove this comment
    pl => 'Nazwa produktu', #pl-CHECK - Please check and remove this comment
	pt => 'Nome do produto',
	ro => 'Numele produsului',
    th => 'ชื่อสินค้า', #th-CHECK - Please check and remove this comment
    vi => 'Tên sản phẩm', #vi-CHECK - Please check and remove this comment
    zh => '产品名称', #zh-CHECK - Please check and remove this comment

},
product_name_example => {
	fr => "Kinder Bueno White",
	en => "Kinder Bueno White",
	el => "Kinder Bueno White",
	es => "Kinder Bueno White",
	it => "Kinder Bueno White",
	pt => 'Kinder Bueno White',
	ro => 'Kinder Bueno White',
	de => 'Kinder Bueno White',
	he => "קינדר בואנו לבן",
	nl => 'Kinder Bueno White',
	nl_be => 'Kinder Bueno White',
},

generic_name => {

    ar => 'اسم شائع', #ar-CHECK - Please check and remove this comment
	de => 'Allgemeiner Name',
    cs => 'Běžné jméno', #cs-CHECK - Please check and remove this comment
	es => "Denominación general",
	en => "Common name",
	it => "Nome generico",
    fi => 'Yleisnimi', #fi-CHECK - Please check and remove this comment
	fr => "Dénomination générique",
	el => "Κοινό/Γενικό όνομα",
	he => "שם נפוץ",
    ja => '一般名', #ja-CHECK - Please check and remove this comment
    ko => '일반 이름', #ko-CHECK - Please check and remove this comment
	nl => 'Algemene benaming',
	nl_be => 'Algemene benaming',
    ru => 'Имя нарицательное', #ru-CHECK - Please check and remove this comment
    pl => 'Nazwa zwyczajowa', #pl-CHECK - Please check and remove this comment
	pt => 'Nome genérico',
	ro => 'Numele general',
    th => 'ชื่อสามัญ', #th-CHECK - Please check and remove this comment
    vi => 'Tên thường gặp', #vi-CHECK - Please check and remove this comment
    zh => '统称', #zh-CHECK - Please check and remove this comment

},
generic_name_example => {
	fr => "Barre chocolatée au lait et aux noisettes",
	en => "Chocolate bar with milk and hazelnuts",
	el => "Μπάρα σοκολάτας με γάλα και φουντούκια",
	es => "Tableta de chocolate con leche y avellanas",
	it => "Tavoletta di cioccolato al latte con nocciole",
	pt => 'Barra de chocolate com leite e avelãs',
	ro => 'Baton de ciocolată cu lapte și alune',
	he => "חטיף שוקולד עם חלב ושקדים",
	nl => 'Chocoladereep met melkchocolade en hazelnoten',
	nl_be => 'Chocoladereep met melkchocolade en hazelnoten',
	de => 'Schokoladenriegel mit Milch und Haselnuß',
	ru => 'Шоколадная плитка с молоком и фундуком',
},
brands => {

    ar => 'العلامات التجارية', #ar-CHECK - Please check and remove this comment
	de => "Marken",
    cs => 'Značky', #cs-CHECK - Please check and remove this comment
	es => "Marcas",
	en => "Brands",
	it => "Marche",
    fi => 'Tuotemerkit', #fi-CHECK - Please check and remove this comment
	fr => "Marques",
	el => "Μάρκες",
	he => 'מותגים',
    ja => 'ブランド', #ja-CHECK - Please check and remove this comment
    ko => '브랜드', #ko-CHECK - Please check and remove this comment
	nl => 'Merken',
	nl_be => 'Merken',
    ru => 'Бренды', #ru-CHECK - Please check and remove this comment
    pl => 'Marki', #pl-CHECK - Please check and remove this comment
	pt => 'Marcas',
	ro => 'Mărci',
    th => 'แบรนด์', #th-CHECK - Please check and remove this comment
    vi => 'Thương hiệu', #vi-CHECK - Please check and remove this comment
    zh => '品牌', #zh-CHECK - Please check and remove this comment

},
brands_example => {
	fr => "Kinder Bueno White, Kinder Bueno, Kinder, Ferrero",
	en => "Kinder Bueno White, Kinder Bueno, Kinder, Ferrero",
	es => "Kinder Bueno White, Kinder Bueno, Kinder, Ferrero",
	el => "Kinder Bueno White, Kinder Bueno, Kinder, Ferrero",
	it => "Kinder Bueno, Kinder, Ferrero",
	pt => 'Kinder Bueno White, Kinder Bueno, Ferrero',
	ro => 'Kinder Bueno White, Kinder Bueno, Kinder, Ferrero',
	he => "קינדר בואנו לבן, קינדר בואנו, פררו",
	nl => "Kinder Bueno White, Kinder Bueno, Kinder, Ferrero",
	nl_be => "Kinder Bueno White, Kinder Bueno, Kinder, Ferrero",
	de => "Kinder Bueno White, Kinder Bueno, Kinder, Ferrero",
},

quantity => {

    ar => 'كمية', #ar-CHECK - Please check and remove this comment
	de => "Menge",
    cs => 'Množství', #cs-CHECK - Please check and remove this comment
	es => "Cantidad",
	en => "Quantity",
	it => "Quantità",
    fi => 'Määrä', #fi-CHECK - Please check and remove this comment
	fr => "Quantité",
	da => 'Mængde',
	el => "Ποσότητα",
	he => "כמות",
    ja => '数量', #ja-CHECK - Please check and remove this comment
    ko => '양', #ko-CHECK - Please check and remove this comment
	nl => "Hoeveelheid",
	nl_be => "Hoeveelheid",
    ru => 'Количество', #ru-CHECK - Please check and remove this comment
    pl => 'Ilość', #pl-CHECK - Please check and remove this comment
	pt => "Quantidade",
	ro => 'Cantitate',
    th => 'ปริมาณ', #th-CHECK - Please check and remove this comment
    vi => 'Số lượng', #vi-CHECK - Please check and remove this comment
    zh => '数量', #zh-CHECK - Please check and remove this comment

},
quantity_example => {
	fr => "2 l, 250 g, 1 kg, 25 cl",
	en => "2 l, 250 g, 1 kg, 25 cl, 6 fl oz, 1 pound",
	el => "2 l, 250 g, 1 kg, 25 cl, 250 ml, 6 fl oz",
	es => "2 l, 250 g, 1 kg, 25 cl",
	it => "2 l, 250 g, 1 kg, 25 cl",
	pt => '2 l, 250 g, 1 kg, 250 ml',
	ro => '2 l, 250 g, 1 kg, 250 ml',
	he => "2 1, 250 ג, 1 ק״ג, 250 מ״ל",
	nl => "2 l, 250 g, 1 kg, 25 cl",
	nl_be => "2 l, 250 g, 1 kg, 25 cl",
	de => "2 l, 250 g, 1 kg, 25 cl",
},

packaging => {

    ar => 'التعبئة والتغليف', #ar-CHECK - Please check and remove this comment
	de => "Verpackung",
    cs => 'Obal', #cs-CHECK - Please check and remove this comment
	es => "Envases",
	en => "Packaging",
	it => "Confezionamento",
    fi => 'Pakkaus', #fi-CHECK - Please check and remove this comment
	fr => "Conditionnement",
	el => "Συσκευασία",
	he => "אריזה",
    ja => 'パッケージング', #ja-CHECK - Please check and remove this comment
    ko => '포장', #ko-CHECK - Please check and remove this comment
	nl => "Verpakking",
	nl_be => "Verpakking",
    ru => 'Упаковка', #ru-CHECK - Please check and remove this comment
    pl => 'Opakowania', #pl-CHECK - Please check and remove this comment
	pt => "Embalagem",
	ro => 'Ambalare',
    th => 'บรรจุภัณฑ์', #th-CHECK - Please check and remove this comment
    vi => 'Bao bì', #vi-CHECK - Please check and remove this comment
    zh => '包装', #zh-CHECK - Please check and remove this comment

},

packaging_note => {
	fr => "Type de conditionnement, format, matière",
	en => "Packaging type, format, material",
	el => "Τύπος συσκευασίας, μορφή/σχήμα, υλικό",
	es => "Tipo de envase, formato, material",
	it => "Tipo di confezione, formato, materiale",
	pt => "Tipo de embalagem, formato, material",
	ro => 'Tipul de ambalaj, format, material',
	he => "סוג האריזה, מבנה, חומר",
	nl => "Soort verpakking, formaat, materiaal",
	nl_be => "Soort verpakking, formaat, materiaal",
	de => "Verpackungsart, Format, Material",
},

packaging_example => {
	fr => "Frais, Conserve, Sous-vide, Surgelé, Bouteille, Bocal, Boîte, Verre, Plastique, Carton...",
	en => "Fresh, Canned, Frozen, Bottle, Box, Glass, Plastic...",
	el => "Φρέσκο, Κονσερβοποιημένο, Κατεψυγμένο, Φιάλη, Γυαλί, Πλαστικό...",
	es => "Fresco, En conserva, Al vacío, Congelado, Botella, Tarro, Caja, Vidrio, Plástico, Cartón...",
	pt => "Fresco, Conserva, Vácuo, Congelado, Garrafa, Copo, Caixa, Vidro, Plástico, Cartão...",
	it => "Fresco, Conserva/Lattina, Sottovuoto, Surgelato, Bottiglia, Vasetto, Barattolo, Vetro, Plastica, Cartone",
	ro => 'Proaspăt, Conservat, Înghețat, Îmbuteliat, Cutie, Sticlă, Plastic...',
	he => "טרי, בקופסת שימורים, קפוא, בקבוק, קופסה, זכוכית, פלסטיק...",
	nl => "Vers, Blik, Vacuüm, Diepgevroren, Fles, Bokaal, Doos, Glas, Plastiek, Karton, ...",
	nl_be => "Vers, Conserve, Vacuüm, Diepgevroren, Fles, Bokaal, Doos, Glas, Plastiek, Karton, ...",
	de => "Frisch, Konserve, Tiefkühlware, Flasche, Packung, Glas, Kunststoff, Karton, ...",
},

categories => {

    ar => 'الفئات', #ar-CHECK - Please check and remove this comment
	de => "Kategorien",
    cs => 'Kategorie', #cs-CHECK - Please check and remove this comment
	es => "Categorías",
	en => "Categories",
	it => "Categorie",
    fi => 'Luokat', #fi-CHECK - Please check and remove this comment
	fr => "Catégories",
	el => "Κατηγορίες",
	he => "קטגוריות",
    ja => 'カテゴリー', #ja-CHECK - Please check and remove this comment
    ko => '카테고리', #ko-CHECK - Please check and remove this comment
	nl => "Categorieën",
	nl_be => "Categorieën",
    ru => 'Категории', #ru-CHECK - Please check and remove this comment
    pl => 'Kategorie', #pl-CHECK - Please check and remove this comment
	pt => "Categorias",
	ro => 'Categorii',
    th => 'หมวดหมู่', #th-CHECK - Please check and remove this comment
    vi => 'Thể loại', #vi-CHECK - Please check and remove this comment
    zh => '分类', #zh-CHECK - Please check and remove this comment

},

categories_example => {
	fr => "Sardines à l'huile d'olive, Mayonnaises allégées, Jus d'orange à base de concentré",
	en => "Sardines in olive oil, Orange juice from concentrate",
	el => "Σαρδέλες σε ελαιόλαδο, Χυμός πορτοκάλι από συμπυκνωμένο",
	es => "Sardinas en aceite de oliva, Mayonesa ligera, Zumo de naranja procedente de concentrado",
	it => "Sardine in olio di oliva, Succo d'arancia a base di concentrato",
	pt => "Sardinha em óleo de oliva, Suco de laranja concentrado",
	pt_pt => "Sardinha em azeite, Sumo de laranja concentrado",
	ro => 'Sardine în ulei de măsline, Suc de portocale pe bază de concentrat',
	he => "סרדינים בשמן זית, מיץ תפוזים עשוי רכז",
	nl => "Sardines in olijfolie, Lightmayonaise, Sinaasappelsap op basis van geconcentreerd sap",
	nl_be => "Sardines in olijfolie, Lightmayonaise, Sinaasappelsap op basis van geconcentreerd sap",
	de => "Sardinen in Olivenöl, Orangensaft aus Orangensaftkonzentrat",
},

categories_note => {
	fr => "Il suffit d'indiquer la catégorie la plus spécifique, les catégories \"parentes\" seront ajoutées automatiquement.",
	en => "Indicate only the most specific category. \"Parents\" categories will be automatically added.",
	el => "Αναφέρετε μόνο την πιο εξειδικευμένη κατηγορία. \"Parents\" κατηγορίες θα προστεθούν αυτόματα.",
	es => "Indicar sólo la categoría más específica. Las categorías \"Padres\" serán añadidas automáticamente.",
	pt => "Indicar apenas a categoria mais específica. As categorias \"Pai\" serão adicionadas automaticamente.",
	it => "Indicare solo la categoria più specifica, le categorie \"Principali\" saranno aggiunte automaticamente",
	ro => "Indicați doar categoria cea mai specifică. Categorile \"Părinte\" vor fi adăugate automat.",
	he => "ציון הקטגוריה החשובה ביותר. קטגוריות „הורים“ יתווספו אוטומטית.",
	nl => "Duidt enkel de meest specifieke categorie aan. De \"verwante\" categorieën worden automatisch toegevoegd.",
	nl_be => "Duidt enkel de meest specifieke categorie aan. De \"verwante\" categorieën worden automatisch toegevoegd.",
	de => "Geben Sie nur die am zutreffende Kategorie an, die \"Vorfahr-\" Kategorien werden automatisch hinzugefügt.",
},

pnns_groups_1 => {
	en => "PNNS groups 1",
},
pnns_groups_2 => {
	en => "PNNS groups 2",
},

labels => {
	fr => "Labels, certifications, récompenses",
	en => "Labels, certifications, awards",
	el => "Ετικέτες, πιστοποιητικά, βραβεία",
	es => "Etiquetas, certificaciones, premios",
	pt => "Etiquetas, certificações, prêmios",
	ro => 'Etichete, certificări, premii',
	it => "Etichette, certificazioni, premi",
	he => "תוויות, אישורים, פרסים",
	nl => "Keurmerken, certificaten, prijzen",
	nl_be => "Labels, certificaten, prijzen",
	de => "Labels, Zertifizierungen, Preise",
},

labels_example => {
	fr => "AB, Bio européen, Max Havelaar, Label Rouge, IGP, AOP, Saveur de l'Année 2012...",
	en => "Organic", # "Fairtrade USA, Fair trade, TransFair...",
	el => "Βιολογικό/Οργανικό/Ολοκληρωμένης Διαχείρισης, Δικαίου Εμπορίου, Π.Ο.Π., Π.Γ.Ε, Χωρίς γλουτένη, Ελεύθερο Γενετικών Τροποποιημένων/Non GMO, Βραβείο γεύσης...",
	es => "Ecológico, Fairtrade-Max Havelaar, I.G.P., D.O.P., Sabor del año 2012...",
	pt => "Ecológico, Comércio Justo, Sabor do Ano 2012...",
	pt_pt => "Ecológico, Produto do Ano 2012, sem glúten, ...",
	ro => 'Bio',
	it => "IGP, IGT, DOP, Bio, Ecologico, Non OGM, gluten-free",
	he => "אורגני", "סחר הוגן, מיוצר בישראל",
	nl => "EKO, Max Havelaar, Label Rouge, Organisch, Glutenvrij, Smaak van het jaar 2012, ...",
	nl_be => "AB, Max Havelaar, Label Rouge, Organisch, Glutenvrij, Smaak van het jaar 2012, ...",
	de => "Bio, Fairtrade-Max Havelaar, demeter, vegan, Glutenfrei, ...",
},

labels_note => {
	fr => "Indiquez les labels les plus spécifiques. Les catégories \"parentes\" comme 'Bio' ou 'Commerce équitable' seront ajoutées automatiquement.",
	en => "Indicate only the most specific labels. \"Parents\" labels will be added automatically.",
	el => "Αναφέρετε μόνο την πιο εξειδικευμένη κατηγορία. \"Parents\" κατηγορίες θα προστεθούν αυτόματα.",
	pt => "Indicar apenas a categoria mais específica. As categorias \"Pai\" serão adicionadas automaticamente.",
	es => "Indicar sólo las etiquetas más específicas. Las categorías \"Padres\" como 'Eco' o 'Comercio Justo' serán añadidas automáticamente.",
	it => "Indicare solo le etichette più specifiche. Le categorie maggiori come 'Eco' o 'Commercio equo-solidale' saranno aggiunte in automatico.",
	ro => "Indicați doar eticheta cea mai specifică. Etichetele \"Părinte\" vor fi adăugate automat.",
	he => "יש לציין את התוויות הייחודיות בלבד. תוויות „הורים“ יתווספו אוטומטית.",
	nl => "Duid enkel de meest specifieke keurmerken aan. De \"verwante\" categorieën zoals 'Bio of ' Fair trade' worden automatisch toegevoegd",
	nl_be => "Duid enkel de meest specifieke labels aan. De \"verwante\" categorieën zoals 'Bio of ' Fair trade' worden automatisch toegevoegd",
	de => "Geben Sie nur die am besten zutreffenden Labels an, die \"Vorfahr-\" Labels werden automatisch hinzugefügt.",
},

origins => {
    ar => 'أصل المكونات', #ar-CHECK - Please check and remove this comment
	de => "Herkunft der Zutaten",
    cs => 'Původ přísad', #cs-CHECK - Please check and remove this comment
	es => "Origen de los ingredientes",
	en => "Origin of ingredients",
    it => 'Origine degli ingredienti', #it-CHECK - Please check and remove this comment
    fi => 'Alkuperä ainesosien', #fi-CHECK - Please check and remove this comment
	fr => "Origine des ingrédients",
	el => "Προέλευση των συστατικών",
	he => 'מקור הרכיבים',
    ja => '成分の起源', #ja-CHECK - Please check and remove this comment
    ko => '성분의 유래', #ko-CHECK - Please check and remove this comment
	nl => "Herkomst van de ingrediënten",
	nl_be => "Herkomst van de ingrediënten",
    ru => 'Происхождение ингредиентов', #ru-CHECK - Please check and remove this comment
    pl => 'Pochodzenie składników',
    # pt => "Origem do produto", Manual translation
    pt => 'Origem dos ingredientes', #pt-CHECK - Please check and remove this comment
	ro => "Originea ingredientelor",
    th => 'แหล่งที่มาของวัตถุดิบ', #th-CHECK - Please check and remove this comment
    vi => 'Nguồn gốc của các thành phần', #vi-CHECK - Please check and remove this comment
    zh => '配料原产地', #zh-CHECK - Please check and remove this comment
},

origins_example => {
	fr => "Vallée des Baux-de-Provence, Provence, France",
	en => "California, USA",
	el => "Μέτσοβο, Ήπειρος, Ελλάδα",
	es => "Montilla, Córdoba (provincia), Andalucía, España",
	pt => "Ribeira Grande, São Miguel, Açores, Portugal",
	he => "נס ציונה, ישראל",
	nl => "Leuven, Vlaams-Brabant, België",
	nl_be => "Haarlem, Nederland",
	de => "Bayerisch, Allgäu, Schwäbisch-Hällisch",
},

origins_note_xxx => {
	fr => "Indiquer l'origine des ingrédients",
	en => "",
	el => "Αναφέρετε την προέλευση των συστατικών",
	es => "Indicar el origen de los ingredientes",
	pt => "Indicar nas duas entradas a origem indicada na etiqueta e possivelmente o seu tipo",
	ro => "Indicați originea ingredientelor",
	nl => "Geef de herkomst van de ingrediënten weer",
	nl_be => "Geef de herkomst van de ingrediënten weer",
	de => "Herkunft der Zutaten kennzeichnen",
},

manufacturing_places => {
	fr => "Lieux de fabrication ou de transformation",
	en => "Manufacturing or processing places",
	el => "Τόπος παραγωγής ή επεξεργασίας",
	es => "Lugares de fabricación o de transformación",
	pt_pt => "Locais de fabrico ou de transformação",
	ro => "Locurile de fabricare sau procesare",
	nl => "Locaties van productie of verwerking",
	nl_be => "Locaties van productie of verwerking",
	de => "Herstellungs- oder Umwandlungsorte",
},


manufacturing_places_example => {
	fr => "Provence, France",
	en => "Montana, USA",
	el => "Θεσσαλονίκη, Ελλάδα",
	es => "Andalucía, España",
	pt => "Lisboa, Portugal",
	nl => "Leuven, België",
	nl_be => "Haarlem, Nederland",
	de => "Allgäu, Deutschland",

},

emb_codes => {
	fr => "Code emballeur (EMB) ou embouteilleur",
	en => "EMB code",
	el => "Κωδικός παραγωγού ή εμφιαλωτή",
	es => "Código de envasador",
	pt => "Código do embalador",
	de => "Produzenten Code",
	nl => "Verpakkerscode",
	nl_be => "Verpakkerscode",
},

emb_codes_example => {
	fr => "EMB 53062, FR 62.448.034 CE, 84 R 20, 33 RECOLTANT 522 ",
	en => "EMB code",
	es => "EMB 53062, FR 62.448.034 CE, 84 R 20, 33 RECOLTANT 522 ",
	pt => "PT ILT 40 CE",
	nl => "EMB code, FR 62.448.034 CE, 84 R 20.",
	nl_be => "EMB code, FR 62.448.034 CE, 84 R 20.",
	de => "DE BY117 EG, FR 62.448.034 CE, 84 R 20, 33 RECOLTANT 522",
},

emb_codes_note => {
	fr => "En France, code commençant par EMB suivi de 5 chiffres (code INSEE de la commune) et éventuellement d'une lettre qui identifie l'entreprise qui a conditionné le produit.<br/>
Dans d'autres pays d'Europe, code précédé de \"e\". Ou dans un ovale, 2 initiales du pays suivi d'un nombre et de CE.<br/>
Pour le vin et l'alcool, code sur la capsule au dessus du bouchon.",
	en => "In Europe, code in an ellipse with the 2 country initials followed by a number and CE.",
	el => "Στην Ευρώπη, κωδικός μέσα σε οβάλ με τα 2 πρώτα αρχικά της χώρας συνοδευόμενο με έναν αριθμό και CE.",
es => "En Francia, el código que empieza por EMB seguido de 5 cifras (código del INSEE de la comuna) y, en ocasiones, una letra que identifica la empresa envasadora del producto.<br/>
En otros países europeos, el código precedido por \"e\". O en una elipse, dos letras correspondientes al país seguidas de un número y de las letras CE.<br/>",
	pt => "Na Europa, o código vem normalmente numa oval, com 2 letras correspondentes ao país, seguido de um número e das letras CE.",
	nl => "In Europa, de code in een ovaal met de 2 letters van het land gevolgd door een cijfer en de letters CE.",
	nl_be => "In Europa, de code in een ovaal met de 2 letters van het land gevolgd door een cijfer en de letters CE.",
	de => "In Europa befindet sich der Code in einer Ellipse mit zwei stelligen Ländercode gefolgt mit einer Nummer und EG (EG-Herkunftskennzeichnung).",
},

link => {

    ar => 'رابط لصفحة المنتج على الموقع الرسمي للمنتج', #ar-CHECK - Please check and remove this comment
	de => "Link zur Produktseite auf der offiziellen Seite des Herstellers",
    cs => 'Odkaz na stránku produktu na oficiálních stránkách výrobce', #cs-CHECK - Please check and remove this comment
	es => "Enlace a la página del producto en el sitio oficial del fabricante",
	en => "Link to the product page on the official site of the producer",
    it => 'Link alla pagina del prodotto sul sito ufficiale del produttore', #it-CHECK - Please check and remove this comment
    fi => 'Linkki tuotesivulle virallisella sivustolla tuottajan', #fi-CHECK - Please check and remove this comment
	fr => "Lien vers la page du produit sur le site officiel du fabricant",
	el => "Link στη σελίδα του προϊόντος στο επίσημο site του παραγωγού",
	he => "קישור לעמוד המוצר באתר הרשמי של היצרן",
    ja => '生産者の公式サイト上の製品ページへのリンク', #ja-CHECK - Please check and remove this comment
    ko => '생산자의 공식 사이트의 제품 페이지에 링크', #ko-CHECK - Please check and remove this comment
	nl => "Link naar de pagina van het product op de officiële site van de producent",
	nl_be => "Link naar de pagina van het product op de officiële site van de producent",
    ru => 'Ссылка на страницу продукта на официальном сайте производителя', #ru-CHECK - Please check and remove this comment
    pl => 'Link do strony produktu na oficjalnej stronie producenta', #pl-CHECK - Please check and remove this comment
	pt => "Link da página oficial do produto do fabricante",
	ro => "Legătură către pagina produsului de pe site-ul oficial al producătorului",
    th => 'เชื่อมโยงไปยังหน้าสินค้าบนเว็บไซต์อย่างเป็นทางการของผู้ผลิต', #th-CHECK - Please check and remove this comment
    vi => 'Liên kết với các trang sản phẩm trên trang web chính thức của nhà sản xuất', #vi-CHECK - Please check and remove this comment
    zh => '链接到产品页上的生产者的官方网站', #zh-CHECK - Please check and remove this comment

},

purchase_places => {

    ar => 'المدينة والولاية وبلد الشراء', #ar-CHECK - Please check and remove this comment
	de => "Stadt und Land des Ankaufs",
    cs => 'Město, stát a země nákupu', #cs-CHECK - Please check and remove this comment
	es => "Sitios de compra",
	en => "City, state and country where purchased",
    it => 'Città, provincia e paese di acquisto', #it-CHECK - Please check and remove this comment
    fi => 'Kaupungin, valtion ja ostomaassa', #fi-CHECK - Please check and remove this comment
	fr => "Ville et pays d'achat",
	el => "Πόλη και κράτος αγοράς",
	he => "עיר/מושב/קיבוץ/כפר בהם נרכש המוצר",
    ja => '市、州、購入した国', #ja-CHECK - Please check and remove this comment
    ko => '도시, 주 및 구매의 나라', #ko-CHECK - Please check and remove this comment
	nl => "Stad en land van aankoop",
	nl_be => "Stad en land van aankoop",
    ru => 'Город, область и страна покупки', #ru-CHECK - Please check and remove this comment
    pl => 'Miasto, województwo i kraj zakupu', #pl-CHECK - Please check and remove this comment
	pt => "Cidade, estado e país onde foi comprado",
	ro => "Oraș, județ și țara de achiziție",
    th => 'เมืองรัฐและประเทศที่ซื้อ', #th-CHECK - Please check and remove this comment
    vi => 'Thành phố, tiểu bang và quốc gia mua hàng', #vi-CHECK - Please check and remove this comment
    zh => '市，州和购买国', #zh-CHECK - Please check and remove this comment

},

purchase_places_note => {
	fr => "Indiquez le lieu où vous avez acheté ou vu le produit (au moins le pays)",
	en => "Indicate where you bought or saw the product (at least the country)",
	el => "Παρακαλώ υποδείξτε που αγοράσατε ή είδατε το προϊόν (τουλάχιστον τη χώρα)",
es => "Indica donde compraste o viste el producto (al menos el país)",
	pt => "Indicar onde comprou ou viu o produto (pelo menos o país)",
	ro => "Indicați unde ați achiziționat sau ați văzut produsul (cel puțin țara)",
	he => "ציון היכן המוצר נרכש או נצפה (לפחות ברמת העיר)",
	nl => "Geef de plaats aan waar je het product gekocht of gezien heeft (ten minste het land)",
	nl_be => "Geef de plaats aan waar u het product gekocht of gezien heeft (ten minste het land)",
	de => "Bitte geben Sie den Ort ein, wobei Sie das Produkt gekauft oder gesehen haben (das Land zumindest)",
},

stores => {
	fr => "Magasins",
	en => "Stores",
	es => "Tiendas",
	el => "Καταστήματα",
pt => "Lojas",
	ro => "Magazine",
	he => "חנויות",
	nl => "Winkels",
	nl_be => "Winkels",
	de => "Läden",
},

stores_note => {
	fr => "Enseigne du magasin où vous avez acheté ou vu le produit",
	en => "Name of the shop or supermarket chain",
	el => "Επωνυμία καταστήματος ή αλυσίδας supermarket",
es => "Nombre de la tienda o cadena de supermercados",
	pt => "Nome da loja ou rede de supermercados",
	ro => "Numele magazinului sau al lanțului de magazine",
	he => "שם החנות או רשת חנויות המזון",
	nl => "Naam van de winkel of supermarktketen waar je het product gekocht of gezien hebt",
	nl_be => "Naam van de winkel of supermarktketen waar u het product gekocht of gezien heeft",
	de => "Name des Geschäfts, wo Sie das Produkt gekauft oder gesehen haben",
},

countries => {

    ar => 'بلدان بيع', #ar-CHECK - Please check and remove this comment
    de => 'Vertriebsländer', #de-CHECK - Please check and remove this comment
    cs => 'Země prodeje', #cs-CHECK - Please check and remove this comment
	es => "Países de venta",
	en => "Countries where sold",
    it => 'Paesi di vendita', #it-CHECK - Please check and remove this comment
    fi => 'Maat myyntiehdot', #fi-CHECK - Please check and remove this comment
	fr => "Pays de vente",
	el => "Χώρες όπου πωλείται",
	he => "ארצות בהן נמכר",
    ja => '販売の国', #ja-CHECK - Please check and remove this comment
    ko => '판매의 나라', #ko-CHECK - Please check and remove this comment
	nl => "Verkooplanden",
	nl_be => "Landen van verkoop",
    ru => 'Страны продажи', #ru-CHECK - Please check and remove this comment
    pl => 'Kraje sprzedaż', #pl-CHECK - Please check and remove this comment
	pt => "Países onde é vendido",
	ro => "Țările unde se vinde",
    th => 'ประเทศของการขาย', #th-CHECK - Please check and remove this comment
    vi => 'Các quốc gia bán', #vi-CHECK - Please check and remove this comment
    zh => '销售的国家', #zh-CHECK - Please check and remove this comment

},

countries_note => {
	fr => "Pays dans lesquels le produit est largement distribué (hors magasins spécialisés dans l'import)",
	en => "Countries where the product is widely available (non including stores specialising in foreign products)",
	el => "Χώρες όπου το προϊόν είναι ευρέως διαθέσιμο (εξαιρουμένων των καταστημάτων που εξειδικεύονται στην πώληση ξένων προϊόντων",
es => "Países en los que el producto está ampliamente disponible (no se incluyen las tiendas especializadas en productos extranjeros)",
	pt => "Países onde o produto é amplamente distribuído (não incluir lojas especializadas em produtos estrangeiros)",
	ro => "Țările unde produsul este disponibil pe scară largă (ne-incluzând magazinele specializate în produse străine)",
	he => "מדינות בהן המוצר זמין לרווחה (לא כולל חנויות המתמחות במוצרים מיובאים)",
	nl => "Landen waar het product op grote schaal beschikbaar is (behalve winkels gespecialiseerd in import)",
	nl_be => "Landen waar het product op grote schaal beschikbaar is (behalve winkels gespecialiseerd in import)",
	de => "Länder, in denen das Produkt weit verbreitet ist (Spezialgeschäfte für ausländische Waren nicht eingeschlossen)",
},

remember_purchase_places_and_stores => {
	fr => 'Se souvenir du lieu d\'achat et du magasin pour les prochains ajouts de produits',
	el => "Θυμήσου τον τόπο αγοράς και αποθήκευσε για τις επόμενες προσθήκες προϊόντων",
en => 'Remember the place of purchase and store for the next product adds',
	es => 'Recordar el lugar de compra y la tienda para los nuevos productos que se van a añadir en el futuro',
	pt => 'Lembrar o lugar de compra e loja para os próximos produtos a serem adicionados',
	ro => "Ține minte locul de achiziție și magazinul pentru următoarele adăugări de produse",
	he => 'שמירת מקור הרכישה ואת החנות להוספות המוצרים הבאות',
	nl => "De locatie van aankoop en de winkel onthouden voor het toevoegen van nieuwe producten",
	nl_be => "De locatie van aankoop en de winkel onthouden voor het toevoegen van nieuwe producten",
	de => "Laden und Einkaufsort für die nächsten Produkte speichern",
},

product_characteristics => {

    ar => 'خصائص المنتج', #ar-CHECK - Please check and remove this comment
	de => "Produkteigenschaften",
    cs => 'Vlastnosti výrobku', #cs-CHECK - Please check and remove this comment
	es => "Características del producto",
	en => "Product characteristics",
    it => 'Caratteristiche del prodotto', #it-CHECK - Please check and remove this comment
    fi => 'Tuotteen ominaisuudet', #fi-CHECK - Please check and remove this comment
	fr => "Caractéristiques du produit",
	el => 'Χαρακτηριστικά του προϊόντος',
	he => "מאפייני המוצר",
    ja => '製品の特徴', #ja-CHECK - Please check and remove this comment
    ko => '제품 특징', #ko-CHECK - Please check and remove this comment
	nl => "Eigenschappen van het product",
	nl_be => "Eigenschappen van het product",
	ru => "Характеристики продукта",
    pl => 'Charakterystyka produktu', #pl-CHECK - Please check and remove this comment
	pt => "Características do produto",
	ro => "Caracteristicile produslui",
    th => 'ลักษณะสินค้า', #th-CHECK - Please check and remove this comment
    vi => 'Đặc tính sản phẩm', #vi-CHECK - Please check and remove this comment
    zh => '产品特点', #zh-CHECK - Please check and remove this comment

},

product_image => {
	fr => "Photo du produit",
	en => "Product picture",
    el => 'Φωτογραφία του προϊόντος',
    es => "Imagen del producto",
	pt => "Imagem do produto",
	ro => "Imaginea produsului",
	he => "תמונת המוצר",
	nl => "Foto van het product",
	nl_be => "Foto van het product",
	de => "Foto des Produkts",
	ru => "изображение продукта",
},

image_front => {
	fr => "Photo du produit (recto)",
	en => "Front picture",
	el => "Φωτογραφία εμπρόσθιας επιφάνειας",
	es => "Imagen frontal del producto",
	pt => "Imagem frontal do produto",
	ro => "Imaginea din față",
	he => "תמונה קדמית",
	nl => "Foto van het product (voorkant)",
	nl_be => "Foto van het product (voorzijde)",
	de => "Foto des Produkts (Vorderseite)",
},

image_ingredients => {

    ar => 'صورة للقائمة المكونات', #ar-CHECK - Please check and remove this comment
	de => "Foto der Zutatenliste",
    cs => 'Obrázek seznamu složek', #cs-CHECK - Please check and remove this comment
	es => "Imagen con los ingredientes del producto",
	en => "Ingredients picture",
    it => 'Immagine della lista degli ingredienti', #it-CHECK - Please check and remove this comment
    fi => 'Kuva ainesosaluettelon', #fi-CHECK - Please check and remove this comment
	fr => "Photo de la liste des ingrédients",
	el => "Φωτογραφία συστατικών",
	he => "תמונת הרכיבים",
    ja => '成分のリストの写真', #ja-CHECK - Please check and remove this comment
    ko => '성분 목록의 그림', #ko-CHECK - Please check and remove this comment
	nl => "Foto van de ingrediëntenlijst",
	nl_be => "Foto van de ingrediëntenlijst",
    ru => 'Изображение списке ингредиентов', #ru-CHECK - Please check and remove this comment
    pl => 'Zdjęcie wykazie składników', #pl-CHECK - Please check and remove this comment
	pt => "Imagem com os ingredientes do produto",
	ro => "Imaginea cu ingredientele",
    th => 'รูปภาพของรายชื่อของส่วนผสม', #th-CHECK - Please check and remove this comment
    vi => 'Hình ảnh trong danh sách các thành phần', #vi-CHECK - Please check and remove this comment
    zh => '图片配料表中', #zh-CHECK - Please check and remove this comment

},

image_nutrition => {
	fr => "Photo des informations nutritionnelles",
	en => "Nutrition facts picture",
	el => "Φωτογραφία θρεπτικών συστατικών",
	es => "Imagen con la información nutricional del producto",
	pt => "Imagem com a informação nutricional do produto",
	ro => "Imaginea cu valori nutriționale",
	he => "תמונת הרכיבים",
	nl => "Foto van de voedingswaardetabel",
	nl_be => "Foto van de nutritionële informatie",
	de => "Foto der Nährwertinformationen",
},

# MOBILESTRING

ingredients => {

    ar => 'المكونات', #ar-CHECK - Please check and remove this comment
	de => "Zutaten",
    cs => 'Složení', #cs-CHECK - Please check and remove this comment
	es => "Ingredientes",
	en => "Ingredients",
    it => 'Ingredienti', #it-CHECK - Please check and remove this comment
    fi => 'Ainekset', #fi-CHECK - Please check and remove this comment
	fr => "Ingrédients",
	el => "Συστατικά",
	he => "רכיבים",
    ja => '材料', #ja-CHECK - Please check and remove this comment
    ko => '성분', #ko-CHECK - Please check and remove this comment
	nl => "Ingrediënten",
	nl_be => "Ingrediënten",
	ru => "Ингредиенты",
    pl => 'Składniki', #pl-CHECK - Please check and remove this comment
	pt => "Ingredientes",
 	ro => "Ingrediente",
    th => 'ส่วนผสม', #th-CHECK - Please check and remove this comment
    vi => 'Thành phần', #vi-CHECK - Please check and remove this comment
    zh => '主料', #zh-CHECK - Please check and remove this comment

},

image_ingredients_note => {
	fr => "Si elle est suffisamment nette et droite, les ingrédients peuvent être extraits automatiquement de la photo.",
	en => "If the picture is neat enough, the ingredients can be extracted automatically",
	el => "Εάν η φωτογραφία είναι καθαρή, τα συστατικά μπορούν να εξαχθούν αυτόματα",
	es => "Si la imagen es buena y lo suficientemente nítida, los ingredientes se pueden extraer de forma automática.",
	pt => "Se as imagens forem boas e nítidas, os ingredientes podem ser extraídos automaticamente.",
	ro => "Dacă este suficient de clară și dreaptă, ingredientele ar putea fi extrase automat din fotografie.",
	he => "אם התמונה ברורה ובהירה מספיק, ניתן לחלץ את הרכיבים מהתמונה אוטומטית. (לא עובד בעברית)",
	nl => "Als de foto voldoende scherp en recht is, kunnen de ingrediënten automatisch uit de foto afgeleid worden.",
	nl_be => "Als de foto voldoende scherp en recht is, kunnen de ingrediënten automatisch uit de foto afgeleid worden.",
	de => "Ist das Foto klar und genau, dann können die Zutaten automatisch extrahiert werden.",
},

# MOBILESTRING

ingredients_text => {

    ar => 'قائمة المكونات', #ar-CHECK - Please check and remove this comment
	de => "Zutatenliste",
    cs => 'Seznam Složení', #cs-CHECK - Please check and remove this comment
	es => "Lista de ingredientes",
	en => "Ingredients list",
    it => 'Lista degli ingredienti', #it-CHECK - Please check and remove this comment
    fi => 'Ainesosaluettelon', #fi-CHECK - Please check and remove this comment
	fr => "Liste des ingrédients",
	el => "Λίστα συστατικών",
	he => "רשימת רכיבים",
    ja => '成分リスト', #ja-CHECK - Please check and remove this comment
    ko => '성분 목록', #ko-CHECK - Please check and remove this comment
	nl => "Ingrediëntenlijst",
	nl_be => "Ingrediëntenlijst",
	ru => "список ингредиентов",
    pl => 'Lista składników', #pl-CHECK - Please check and remove this comment
	pt => "Lista de ingredientes",
	ro => "Lista de ingrediente",
    th => 'ส่วนผสมรายการ', #th-CHECK - Please check and remove this comment
    vi => 'Danh sách các thành phần', #vi-CHECK - Please check and remove this comment
    zh => '配料清单', #zh-CHECK - Please check and remove this comment

},

ingredients_text_note => {
	fr => "Conserver l'ordre, indiquer le % lorsqu'il est précisé, séparer par une virgule ou - , Utiliser les ( ) pour  les ingrédients d'un ingrédient, indiquer les allergènes entre _ : farine de _blé_",
	en => "Keep the order, indicate the % when specified, separate with a comma or - , use ( ) for ingredients of an ingredient, surround allergens with _ e.g. _milk_",
	el => "Παρακαλούμε τηρήστε τη σωστή σειρά, υποδείξτε το ποσοστό % όταν αναφέρεται, διαχωρίστε με κόμμα ή με χρήση παύλας - , χρησιμοποιείστε ( ) για τα επιμέρους συστατικά ενός κύριου συστατικού, περιβάλλετε τα αλλεργιογόνα με _ π.χ. _γάλα_",
	es => "Conservar el orden, indicar el % cuando se especifique, separar por una coma y poner entre paréntesis ( ) los ingredientes que componen otro ingrediente",
	pt => "Manter a ordem de listagem, indicar a % quando especificado, separar com uma vírgula (,) ou hífen (-) , usar parênteses ( ) para ingredientes compostos de outros ingredientes",
	ro => "Mențineți ordinea, indicați % unde este precizat, separați cu o virgulă sau - , folosiți () pentru ingredientele unui ingredient",
	he => "יש לשמור על הסדר, לציין את הסמין % כשזה צוין, להפריד עם פסיק או -, להשתמש ב־( ) לתת־רכיבים של רכיב",
	nl => "Behoudt de volgorde, geef het % indien vermeld, scheiden door middel van een komma of '-' , gebruik de ( ) voor de ingrediënten van een ingrediënt, vermeldt de allergenen tussen '_' zoals bijvoorbeeld _melk_",
	nl_be => "Behoudt de volgorde, geef het % indien vermeld, scheiden door middel van een komma of '-' , gebruik de ( ) voor de ingrediënten van een ingrediënt, vermeldt de allergenen tussen '_' zoals bijvoorbeeld _melk_",
	de => "Sortierung behalten, % anzeigen falls vorhanden, mit Komma oder - trennen, für die Zutaten eines Zutats () verwenden, Allergen zwischen _ anzeigen: zum Beispiel _Milch_",
},

ingredients_text_display_note => {

    ar => 'يتم سرد المكونات في الترتيب من حيث الأهمية (كمية).', #ar-CHECK - Please check and remove this comment
	de => "Die Zutaten sind nach Ausmaß/Menge sortiert",
    cs => 'Ingredience jsou uvedeny v pořadí podle důležitosti (množství).', #cs-CHECK - Please check and remove this comment
	es => "Los ingredientes se enumeran por orden de importancia (cantidad).",
	en => "Ingredients are listed in order of importance (quantity).",
    it => 'Gli ingredienti sono elencati in ordine di importanza (quantità).', #it-CHECK - Please check and remove this comment
    fi => 'Ainesosat on lueteltu tärkeysjärjestyksessä (määrä).', #fi-CHECK - Please check and remove this comment
	fr => "Les ingrédients sont listés par ordre d'importance (quantité).",
	el => "Τα συστατικά αναγράφονται με σειρά σημασίας (ποσότητα)",
	he => "רכיבים רשומים לפי סדר חשיבותם (כמות).",
    ja => '成分は重要度（量）の順に表示されます。', #ja-CHECK - Please check and remove this comment
    ko => '성분 중요성 (수량)의 순서로 나열되어 있습니다.', #ko-CHECK - Please check and remove this comment
	nl => "De ingrediënten worden geordend volgens belangrijkheid (hoeveelheid).",
	nl_be => "De ingrediënten worden geordend volgens belangrijkheid (hoeveelheid).",
    ru => 'Ингредиенты перечислены в порядке важности (количество).', #ru-CHECK - Please check and remove this comment
    pl => 'Składniki wymienione są w kolejności ważności (ilość).', #pl-CHECK - Please check and remove this comment
	pt => "Os ingredientes estão listados pela ordem de importância (quantidade).",
	ro => "Ingredientele sunt listate în ordinea importanței (cantitate).",
    th => 'ส่วนผสมมีการระบุไว้ในลำดับความสำคัญ (ปริมาณ)', #th-CHECK - Please check and remove this comment
    vi => 'Các thành phần được liệt kê theo thứ tự tầm quan trọng (số lượng).', #vi-CHECK - Please check and remove this comment
    zh => '成分重要性排列（量）。', #zh-CHECK - Please check and remove this comment

},

ingredients_text_example => {
	fr => "Céréales 85,5% (farine de _blé_, farine de _blé_ complet 11%), extrait de malt (orge), cacao 4,8%, vitamine C",
	en => "Cereals 85.5% (_wheat_ flour, whole-_wheat_ flour 11%), malt extract, cocoa 4,8%, ascorbic acid",
	el => "Δημητριακά 85.5% (_σταρένιο_ αλεύρι, _σταρένιο_ αλεύρι ολικής άλεσης 11%),εκχύλισμα βύνης, κακάο 4,8%, ασκορβικό οξύ",
	es => "Cereales 85.5% (harina de _trigo_, harina de _trigo_ integral 11%), extracto de malta (cebada), cacao 4,8%, ácido ascórbico",
	pt => "Cereais 85.5% (farinha de _trigo_, farinha integral 11%), extrato de malta (cevada), cacau 4,8%, vitamina C",
	pt_pt => "Cereais 85.5% (farinha de _trigo_, farinha integral 11%), extrato de malte (cevada), cacau 4,8%, vitamina C",
	he => "דגנים 85.5% (קמח חיטה, קמח מחיטה מלאה 11%), תמצית לתת, קקאו 4.8%, חומצה אסקורבית",
	nl => "Granen 85.5% (_tarwe_bloem, volkoren _tarwe_bloem 11%), moutextract (gerst), cacao 4,8%, vitamine C",
	nl_be => "Granen 85.5% (_tarwe_bloem, volkoren _tarwe_bloem 11%), moutextract (gerst), cacao 4,8%, vitamine C",
	de => "Getreide 85,5% (_Weizen_mehl, _Vollkorn_mehl 11%), Malzextrakt (Gerste), Kakao 4,8%, Vitamine C",
},

allergens => {
	en => 'Substances or products causing allergies or intolerances',
	ga => 'Substaintí nó táirgí is cúis le hailléirgí nó le héadulaingtí',
	de => 'Stoffe oder Erzeugnisse, die Allergien oder Unverträglichkeiten auslösen',
	da => 'Stoffer eller produkter, der forårsager allergier eller intolerans',
	el => 'Oυσιες ή προϊοντα που προκαλούν αλλεργιες ή δυσανεξιες',
	es => 'Sustancias o productos que causan alergias o intolerancias',
	fi => 'Allergioita tai intoleransseja aiheuttavat aineet ja tuotteet',
	fr => 'Substances ou produits provoquant des allergies ou intolérances',
	it => 'Sostanze o prodotti che provocano allergie o intolleranze',
	nl => 'Stoffen of producten die allergieën of intoleranties veroorzaken',
	nl_be => 'Stoffen of producten die allergieën of intoleranties veroorzaken',
	pt => 'Substâncias ou produtos que provocam alergias ou intolerâncias',
	sv => 'ämnen eller produkter som orsakar allergi eller intolerans',
	lv => 'Vielas vai produkti, kas izraisa alerģiju vai nepanesamību',
	cs => 'Látky nebo produkty vyvolávající alergie nebo nesnášenlivost',
	et => 'Allergiat või talumatust tekitavad ained või tooted',
	hu => 'Allergiát vagy intoleranciát okozó anyagok és termékek',
	pl => 'Substancje lub produkty powodujące alergie lub reakcje nietolerancji',
	sl => 'Snovi ali proizvodi, ki povzročajo alergije ali preobčutljivosti',
	lt => 'Alergijas arba netoleravimą sukeliančios medžiagos arba produktai',
	mt => 'Sustanzi jew prodotti li jikkawżaw allerġiji jew intolleranzi',
	sk => 'Látky alebo výrobky spôsobujúce alergie alebo neznášanlivosť',
	ro => 'Substanțe sau produse care cauzează alergii sau intoleranțe',
	bg => 'вещества или продукти, причиняващи алергии или непоносимост',
	ar => 'مستأرج',
	jp => '食餌性アレルゲン',
	th => 'สารก่อภูมิแพ้อาหาร',
	zh => '食物过敏原',
},

traces => {
	fr => "Traces éventuelles",
	en => "Traces",
	el => "Ίχνη",
	es => "Trazas",
	pt => "Vestígios",
	ro => "Urme",
	he => "עקבות",
	nl => "Sporen",
	nl_be => "Sporen",
	de => "Spuren",
},

traces_note => {
	fr => 'Indiquer les ingrédients des mentions "Peut contenir des traces de", "Fabriqué dans un atelier qui utilise aussi" etc.',
	en => 'Indicate ingredients from mentions like "May contain traces of", "Made in a factory that also uses" etc.',
	el => 'Παρακαλούμε υποδείξτε συστατικά με ενδείξεις όπως "Μπορεί να περιέχει ίχνη από", "Παρασκευάζεται σε εργοστάσιο που επίσης γίνεται επεξεργασία" κλπ',
	es => 'Son los ingredientes que aparecen mencionados como "Puede contener trazas de", "Elaborado en una factoría que también usa", etc.',
	pt => 'Indicar os ingredientes que sejam mencionados como "Pode conter traços de", "Fabricado em ambiente que também usa", etc',
	pt_pt => 'Indicar os ingredientes que sejam mencionados como "Pode conter vestígios de", "Fabricado em ambiente que também usa", etc.',
	ro => 'Indicați ingredientele din mențiuni ca de exemplu "Ar putea conține urme de", "Produse într-o fabrică care produce și" etc.',
	he => 'ציון מרכיבים מאזכורים שונים כגון "עלול להכיל עקבות של", "נוצר במפעל המשתמש ב..." וכו׳',
	nl => 'Geef de ingrediënten met de vermelding "Kan sporen bevatten van", "Geproduceerd in een fabriek waar ook X verwerkt wordt',
	nl_be => 'Geef de ingrediënten met de vermelding "Kan sporen bevatten van", "Geproduceerd in een fabriek waar ook X verwerkt wordt',
	de => 'Die Zutaten von Erwähnungen wie "Kann Spuren enthalten", "Hergestellt in einer fabrik, die auch verwendet" vormerken',
},

traces_example => {
	fr => 'Lait, Gluten, Arachide, Fruits à coque',
	en => "Milk, Gluten, Nuts",
	el => "Γάλα, Γλουτένη, Καρποί",
	es => "Leche, Gluten, Cacahuetes, Nueces",
	pt => "Leite, Glúten, Amendoim, Nozes",
	ro => "Lapte, Gluten, Alune, Nuci",
	he => "חלב, גלוטן, אגוזים",
	nl => "Melk, Gluten, Noten",
	nl_be => "Melk, Gluten, Noten",
	de => "Milch, Gluten, Erdnuss, Nussschalen",
},

serving_size => {

    ar => 'حجم الحصة', #ar-CHECK - Please check and remove this comment
	de => "Portiongröße",
    cs => 'Velikost porce', #cs-CHECK - Please check and remove this comment
	es => "Tamaño de la porción",
	en => "Serving size",
    it => 'Porzioni', #it-CHECK - Please check and remove this comment
    fi => 'Palvelevat koko', #fi-CHECK - Please check and remove this comment
	fr => "Taille d'une portion",
	el => "Μέγεθος μερίδας",
	he => "גודל ההגשה",
    ja => '一人前の分量', #ja-CHECK - Please check and remove this comment
    ko => '서빙 사이즈', #ko-CHECK - Please check and remove this comment
	nl => "Grootte van een portie",
	nl_be => "Grootte van een portie",
    ru => 'Размер порции', #ru-CHECK - Please check and remove this comment
    pl => 'Porcja', #pl-CHECK - Please check and remove this comment
	pt => "Tamanho da porção",
	ro => "Cantitatea unei porții",
    th => 'ที่ให้บริการขนาด', #th-CHECK - Please check and remove this comment
    vi => 'Kích thước phục vụ', #vi-CHECK - Please check and remove this comment
    zh => '份量', #zh-CHECK - Please check and remove this comment

},

serving_size_example => {
	fr => '30 g, 2 biscuits 60 g, 5 cl, un verre 20 cl',
	en => "60 g, 12 oz, 20cl, 2 fl oz",
	el => "30 g, 2 μπισκότα 60 gr, 12 oz, 20cl, 2 fl oz",
	es => '30 g, 2 galletas 60 g, 5 cl, un vaso 20 cl',
	pt => "30 g, 2 bolachas 60 g, 5 cl, um copo 200 ml",
	ro => "30 g, 2 biscuiți 60 g, 5 cl, un pahar 200 ml",
	he => "30 ג, 2 אונקיות, 20 סנטיליטר, 2 אונקיות נוזל",
	nl => "30 g, 2 koekjes 60 g, 5 cl, een glas 20 cl",
	nl_be => "30 g, 2 koekjes 60 g, 5 cl, een glas 20 cl",
	de => "30 g, 2 Keks 60g, 5 cl, ein Glas 20 cl",
},

# MOBILESTRING

nutrition_data => {
    ar => 'حقائق غذائية', #ar-CHECK - Please check and remove this comment
	de => "Nährwertinformationen",
    cs => 'Nutriční hodnoty', #cs-CHECK - Please check and remove this comment
	es => "Información nutricional",
	en => "Nutrition facts",
    it => 'Informazioni nutrizionali', #it-CHECK - Please check and remove this comment
    fi => 'Ravintosisältö', #fi-CHECK - Please check and remove this comment
	fr => "Informations nutritionnelles",
	el => "Διατροφικά στοιχεία",
	he => "מפרט תזונתי",
    ja => '栄養成分表', #ja-CHECK - Please check and remove this comment
    ko => '영양 성분 표시', #ko-CHECK - Please check and remove this comment
	nl => "Voedselwaarden",
	nl_be => "Nutritionele informatie",
    ru => 'Пищевая ценность', #ru-CHECK - Please check and remove this comment
    pl => 'Wartości odżywcze',
	pt => "Informação nutricional",
	ro => "Valori nutriționale",
    th => 'ข้อมูลโภชนาการ', #th-CHECK - Please check and remove this comment
    vi => 'Giá trị dinh dưỡng', #vi-CHECK - Please check and remove this comment
    zh => '营养成分', #zh-CHECK - Please check and remove this comment
},

nutrition_data_note => {
	fr => "Si elle est suffisamment nette et droite, les informations nutritionnelles peuvent être extraites automatiquement de la photo.",
	en => "If the picture is sufficiently sharp and level, nutrition facts can be automatically extracted from the picture.",
	el => "Εάν η φωτογραφία είναι καθαρή, τα διατροφικά στοιχεία μπορούν αυτόματα να εξαχθούν από αυτή",
	es => "Si la imagen es lo suficientemente nítida, la información nutricional puede ser extraída automáticamente.",
	pt => "Se a imagem for suficientemente nítida, a informação nutricional pode ser extraída automaticamente.",
	ro => "Dacă fotografia este suficient de clară și dreaptă, informația nutrițională poate fi extrasă automat din imagine.",
	he => "אם התמונה חדה מספיק ובכיוון נכון, ניתן לחלץ את הפרטים התזונתיים מהתמונה עצמה (עדיין לא זמין בעברית).",
	nl => "Als de foto voldoende scherp en recht is, dan kunnen de voedingswaarden automatisch uit de foto afgeleid worden",
	nl_be => "Als de foto voldoende scherp en recht is, kan de nutritionele informatie automatisch uit de foto afgeleid worden",
	de => "Ist das Foto klar und genau, dann können die Nährwertinformationen automatisch extrahiert werden.",
},

no_nutrition_data => {
	fr => "Les informations nutritionnelles ne sont pas mentionnées sur le produit.",
	en => "Nutrition facts are not specified on the product.",
	el => "Τα διατροφικά δεδομένα δεν αναγράφονται σε αυτό το προϊόν",
	es => "El producto no trae información nutricional.",
	pt => "Informação nutricional não especificada no produto.",
	ro => "Valorile nutriționale nu sunt specificate pe produs.",
	he => "המפרט התזונתי אינו מצוין על המוצר.",
	nl => "De voedingswaarden zijn niet op het product vermeld",
	nl_be => "De nutritionele informatie wordt niet op het product vermeld",
	de => "Die Nährwertinformationen sind auf dem produkt nicht erwähnt",
},

nutrition_data_table_note => {
	fr => "Le tableau liste par défaut les nutriments les plus couramment indiqués. Laissez le champ vide s'il n'est pas présent sur l'emballage.<br />Vous pouvez ajouter d'autres nutriments
(vitamines, minéraux, cholestérol, oméga 3 et 6 etc.) en tapant les premières lettres de leur nom dans la dernière ligne du tableau.",
	en => "The table lists by default nutriments that are often specified. Leave the field blank if it's not on the label.<br/>You can add extra nutriments (vitamins, minerals, cholesterol etc.)
by typing the first letters of their name in the last row of the table.",
 el => "Ο παρών πίνακας αναγράφει προεπιλεγμένα θρεπτικά συστατικά που συχνά αναφέρονται. Αφήστε το πεδίο κενό αν δεν υπάρχουν στην ετικέτα .<br/>Μπορείτε να προσθέσετε επιπλέον θρεπτικά συστατικά (βιταμίνες, μέταλλα, χοληστερόλη, κλπ)
συμπληρώνοντας τα πρώτα γράμματα του ονόματός τους στην τελευταία σειρά του πίνακα.",
	es => "La tabla muestra por defecto los nutrientes que aparecen con mayor frecuencia. Deja el campo en blanco si no está presente en el envase. <br />Se pueden agregar nutrientes adicionales (vitaminas, minerales, colesterol, ácidos grasos omega 3 y 6, etc.) al teclear las primeras letras del nombre en la última fila de la tabla.",
	pt => "A tabela mostra por defeito os nutrientes que aparecem com maior frequência. Deixar o campo em branco se não estiver especificado na embalagem. <br />É possível adicionar outros nutrientes (vitaminas, minerais, colesterol, ácidos gordos ómega 3 e 6, etc.) ao digitar as primeiras letras do nome na última linha da tabela.",
	ro => "Tabelul listează implicit nutrienții care sunt specificați mai des. Lăsați câmpul liber dacă nu se regăsește pe etichetă.<br/>Puteți adăuga extra nutrienți (vitamine, minerale, colesterol etc.) tastând primele litere din numele lor în ultimul rând din tabel.",
	he => "הטבלה מציגה כבררת מחדל את המפרט התזונתי כפי שמופיע בדרך כלל. ניתן להשאיר את השדה ריק אם אינו מופיע על התווית.<br/>ניתן להוסיף פריטי תזונה נוספים (ויטמינים, מינרלים, כולסטרול וכו׳)
על־ידי הקלדת האותיות הראשונות של שמם בשורה האחרונה של הטבלה.",
	nl => "De tabel bevat automatisch de voedingsstoffen die het meest vermeld worden. Laat het veld leeg indien het niet vermeld staat op de verpakking.>br />Je kan andere voedingsstoffen (vitamines, mineralen, cholesterol, omega 3 en 6 etc.) toevoegen door de eerste letters van hun naam in de laatste rij van de tabel in te voeren.",
	nl_be => "De tabel lijst automatisch de voedingsstoffen op die het vaakst vermeld worden. Laat het veld leeg indien het niet vermeld staat op de verpakking.>br />U kunt andere voedingsstoffen (vitamines, mineralen, cholesterol, omega 3 en 6 etc.) toevoegen door de eerste letters van hun naam in de laatste rij van de tabel in te voeren.",
	de => "Die Tabelle listet häufige Nährstoffe. Das Feld einfach leer lassen, falls Nährstoffe auf der Verpackung nicht gelistet sind.<br />Weitere Nährstoffe (Vitaminen, Mineralstoffen, Cholesterin, Omega-3, Omega-6, usw.) können beim Eintippen ihrer ersten Zeichen in der letzten Zeile der Tabelle einfach hinzugefügt werden.",
},

nutrition_data_average => {
	fr => "Composition nutritionnelle moyenne pour les %d produits de la catégorie %s dont les informations nutritionnelles sont connues (sur un total de  %d produits).",
	en => "Average nutrition facts for the %d products of the %s category for which nutrition facts are known (out of %d products).",
	el => "Μέσα διατροφικά στοιχεία για το %d των προϊόντων από το %s της κατηγορίας για την οποία τα διατροφικά δεδομένα είναι γνωστά (από το %d των προϊόντων).",
	es => "Valores nutricionales medios para los %d productos de la categoría %s para los que se especifican los valores nutricionales (de un total de %d productos).",
	pt => "Valores nutricionais médios...",
	ro => "Valorile nutriționale medii pentru %d produse din categoria %s pentru care valorile nutriționale sunt cunoscute (din %d produse).",
	he => "מפרט תזונתי ממוצע עבור %d מוצרים מהקטגוריה %s שעבורם המפרט התזונתי ידוע (מתוך %d מוצרים).",
	nl => "Gemiddelde voedingswaarden voor de %d producten van de categorie %s waarvan de voedingswaarden bekend zijn (op een totaal van %d producten).",
	nl_be => "Gemiddelde nutritionele samenstelling voor de %d producten van de categorie %s waarvan de nutritionele informatie bekend is (op een totaal van %d producten).",
	de => "Durchschnittliche Nährwertzusammensetzung für die %d Produkte von der Kategorie %s, deren Nährwertinformationen bekannt sind (auf %d Produkte insgesamt).",
},

nutrition_data_table => {

    ar => 'حقائق غذائية', #ar-CHECK - Please check and remove this comment
	de => "Nährwertzusammensetzung",
    cs => 'Nutriční hodnoty', #cs-CHECK - Please check and remove this comment
	es => "Información nutricional",
	en => "Nutrition facts",
    it => 'Informazioni nutrizionali', #it-CHECK - Please check and remove this comment
    fi => 'Ravintosisältö', #fi-CHECK - Please check and remove this comment
	fr => "Composition nutritionnelle",
	el => "Διατροφικά δεδομένα",
	he => "מפרט תזונתי",
    ja => '栄養成分表', #ja-CHECK - Please check and remove this comment
    ko => '영양 성분 표시', #ko-CHECK - Please check and remove this comment
	nl => "Voedigswaarden",
	nl_be => "Nutritionele samenstelling",
    ru => 'Пищевая ценность', #ru-CHECK - Please check and remove this comment
    pl => 'Wartości odżywcze',
	pt => "Informação nutricional",
	ro => "Valori nutriționale",
    th => 'ข้อมูลโภชนาการ', #th-CHECK - Please check and remove this comment
    vi => 'Giá trị dinh dưỡng', #vi-CHECK - Please check and remove this comment
    zh => '营养成分', #zh-CHECK - Please check and remove this comment

},

#	(non breaking-spaces are needed below)
nutrition_data_per_100g => {

    ar => '100 غرام / 100 مل', #ar-CHECK - Please check and remove this comment
	de => "für 100 g / 100 ml",
    cs => 'na 100 g / 100 ml', #cs-CHECK - Please check and remove this comment
	es => "por 100 g / 100 ml",
	en => "for 100 g / 100 ml",
    it => 'per 100 g / 100 ml', #it-CHECK - Please check and remove this comment
    fi => '100 g / 100 ml', #fi-CHECK - Please check and remove this comment
	fr => "pour 100 g / 100 ml",
	el => "για 100 g / 100 ml",
	he => "ל־100 גרם / 100 מ״ל",
    ja => '100グラム/ 100mlで用', #ja-CHECK - Please check and remove this comment
    ko => '100G / 100 ㎖ ', #ko-CHECK - Please check and remove this comment
	nl => "voor 100 g / 100 ml",
	nl_be => "voor 100 g / 100 ml",
    ru => 'за 100 г / 100 мл', #ru-CHECK - Please check and remove this comment
    pl => 'do 100 g / 100 ml', #pl-CHECK - Please check and remove this comment
	pt => "por 100 g / 100 ml",
	ro => "pentru 100 g / 100 ml",
    th => 'สำหรับ 100 กรัม / 100 มล.', #th-CHECK - Please check and remove this comment
    vi => 'cho 100 g / 100 ml', #vi-CHECK - Please check and remove this comment
    zh => '100g / 100ml的', #zh-CHECK - Please check and remove this comment

},

nutrition_data_per_serving => {

    ar => 'لكل وجبة', #ar-CHECK - Please check and remove this comment
	de => "pro Schnitte",
    cs => 'v jedné porci', #cs-CHECK - Please check and remove this comment
	es => "por porción",
	en => "per serving",
    it => 'per porzione', #it-CHECK - Please check and remove this comment
    fi => 'annosta kohti', #fi-CHECK - Please check and remove this comment
	fr => "par portion",
	el => "ανά μερίδα",
	he => "לכל הגשה",
    ja => '一食当たり', #ja-CHECK - Please check and remove this comment
    ko => '인분', #ko-CHECK - Please check and remove this comment
	nl => "per portie",
	nl_be => "per portie",
    ru => 'на порцию', #ru-CHECK - Please check and remove this comment
    pl => 'porcji', #pl-CHECK - Please check and remove this comment
	pt => "por porção",
	ro => "per porție",
    th => 'ต่อการให้บริการ', #th-CHECK - Please check and remove this comment
    vi => 'mỗi khẩu', #vi-CHECK - Please check and remove this comment
    zh => '每服', #zh-CHECK - Please check and remove this comment

},

nutrition_data_compare_percent => {
	fr => "Différence en %",
	en => "% of difference",
	da => "% af forskel",
	el => "Διαφορά στο %",
	es => "Diferencia en %",
	pt => "% em comparação",
	ro => "Diferența în %",
	cs => "% se liší",
	he => "% שינוי",
	nl => "Verschil in %",
	nl_be => "Verschil in %",
	de => "Unterschied in %",
},

nutrition_data_comparison_with_categories => {
	fr => "Comparaison avec les valeurs moyennes des produits de même catégorie :",
	en => "Comparison to average values of products in the same category:",
	el => "Σύγκριση με το μέσο όρο της αξίας των προϊόντων της ίδιας κατηγορίας",
	es => "Comparación con los valοres medios de los productos pertenecientes a la misma categoría:",
	pt => "Comparação com os valores médios dos produtos pertencentes à mesma categoria:",
	ro => "Comparație cu valorile medii ale produselor din aceeași categorie:",
	he => "השוואה לערכים הממוצעים של מוצרים באותה הקטגוריה:",
	nl => "Vergelijking met de gemiddelde waarden van producten uit dezelfde categorie:",
	nl_be => "Vergelijking met de gemiddelde waarden van producten uit dezelfde categorie:",
	de => "Vergleich mit den durchschnittlichen Werte von Produkten gleicher Kategorie:",
	ru => 'Сравнение со средними значениями продуктов из той же категории:',
},

nutrition_data_comparison_with_categories_note => {
	fr => "A noter : pour chaque nutriment, la moyenne n'est pas celle de tous les produits de la catégorie, mais des produits pour lesquels la quantité du nutriment est connue.",
	en => "Please note: for each nutriment, the average is computed for products for which the nutriment quantity is known, not on all products of the category.",
	el => "Παρακαλώ σημειώστε: για κάθε ένα θρεπτικό συστατικό, ο μέσος όρος είναι υπολογισμένος για προϊόντα των οποίων η ποσότητα των θρεπτικών συστατικών είναι γνωστή, όχι για όλα τα προϊόντα της κατηγορίας.",
	es => "Nota: para cada nutriente, el promedio no es el de todos los productos de la categoría, sino el de todos los productos para los cuales se especifica la cantidad de nutrientes.",
	pt => "Nota: para cada nutriente, a média tem em conta somente os produtos cuja quantidade dos nutrientes é conhecida, e não para todos os produtos da categoria.",
	ro => "De notat: pentru fiecare nutrient, media este calculată pentru produsele pentru care cantitatea nutrientului este cunoscută, nu pentru toate produsele din categorie.",
	he => "לתשומת לבך: עבור כל מרכיב תזונתי, הממוצע מחושב לפי מוצרים שההרכב התזונתי שלהם ידוע, לא לפי כלל המוצרים בקטגוריה.",
	nl => "NB: voor elke voedingsstof is het gemiddelde niet dat van alle producten uit de categorie, maar dat van de producten waarvoor de hoeveelheid van de voedingsstof bekend is.",
	nl_be => "Noteer: voor elke voedingsstof is het gemiddelde niet dat van alle producten uit de categorie, maar dat van de producten waarvoor de hoeveelheid van de voedingsstof bekend is.",
	de => "Hinweis: Der Durchschnitt für jeden Nährstoff wird anhand derjenigen Produkte berechnet, für diese der Wert bekannt ist, nicht als Durchschnitt über alle Produkte.",
},

nutrition_data_compare_value => {
	fr => "valeur pour 100 g/ 100 ml",
	en => "value for 100 g / 100 ml",
	el => "αξία για 100 g / 100 ml",
	es => "valor para 100 g/ 100 ml",
	pt => "valor para 100 g / 100 ml",
	ro => "valoare pentru 100 g / 100 ml",
	he => "ערך ל־100 גרם / 100 מ״ל",
	nl => "waarde voor 100 g / 100 ml",
	nl_be => "waarde voor 100 g / 100 ml",
	de => "Wert pro 100 g / 100 ml",
},

nutrition_data_per_mean => {
	fr => "Moyenne",
	en => "Mean",
	nl => "Gemiddelde",
	nl_be => "Gemiddelde",
},

nutrition_data_per_std => {

    ar => 'الانحراف المعياري', #ar-CHECK - Please check and remove this comment
	de => "Standardabweichung",
    cs => 'Standardní odchylka', #cs-CHECK - Please check and remove this comment
	es => "Desviación estándar",
	en => "Standard deviation",
    it => 'Deviazione standard', #it-CHECK - Please check and remove this comment
    fi => 'Keskihajonta', #fi-CHECK - Please check and remove this comment
	fr => "Ecart type",
	el => "Τυπική απόκλιση",
	he => "סטיית תקן",
    ja => '標準偏差', #ja-CHECK - Please check and remove this comment
    ko => '표준 편차', #ko-CHECK - Please check and remove this comment
	nl => "Standaardafwijking",
	nl_be => "Standaardafwijking",
    ru => 'Стандартное отклонение', #ru-CHECK - Please check and remove this comment
    pl => 'Odchylenie standardowe', #pl-CHECK - Please check and remove this comment
	pt => "Desvio padrão",
	ro => "Deviația standard",
    th => 'ส่วนเบี่ยงเบนมาตรฐาน', #th-CHECK - Please check and remove this comment
    vi => 'Độ lệch chuẩn', #vi-CHECK - Please check and remove this comment
    zh => '标准差', #zh-CHECK - Please check and remove this comment
},

nutrition_data_per_min => {
	fr => "Minimum",
	en => "Minimum",
	el => "Ελάχιστο",
	es => "Mínimo",
	pt => "Mínimo",
	ro => "Minimum",
	he => "לכל הפחות",
	nl => "Minimum",
	nl_be => "Minimum",
	de => "Minimum",
},

nutrition_data_per_5 => {
	fr => "5<sup>e</sup> centile",
	en => "5<sup>th</supe> centile",
	es => "Percentil 5",
	pt => "5<sup>o</sup> percentil",
	ro => "Al 5-lea procent",
	he => "עד 5 אחוז",
	nl => "5<sup>e</sup> percentiel",
	nl_be => "5<sup>e</sup> percentiel",
	de => "5. Quantil",
},

nutrition_data_per_10 => {
	fr => "10ème centile",
	en => "10th centile",
	es => "Percentil 10",
	pt => "10<sup>o</sup> percentil",
	ro => "Al 10-lea procent",
	he => "עד 10 אחוז",
	nl => "10<sup>e</sup> percentiel",
	nl_be => "10<sup>e</sup> percentiel",
	de => "10. Quantil",
},
nutrition_data_per_50 => {
	fr => "Médiane",
	en => "Median",
	el => "Μέσος",
	es => "Mediana",
	pt => "Mediana",
	ro => "Median",
	he => "חצי",
	nl => "Mediaan",
	nl_be => "Mediaan",
	de => "Medianwert",
},

nutrition_data_per_90 => {
	fr => "90ème centile",
	en => "90th centile",
	es => "Percentil 90",
	pt => "90<sup>o</sup> percentil",
	ro => "Al 90-lea procent",
	he => "עד 90 אחוז",
	nl => "90<sup>e</e> percentiel",
	nl_be => "90<sup>e</e> percentiel",
	de => "90. Quantil",
},

nutrition_data_per_95 => {
	fr => "95<sup>e</sup> centile",
	en => "95<sup>th</supe> centile",
	es => "Percentil 95",
	pt => "95<sup>o</sup> percentil",
	ro => "Al 95-lea procent",
	he => "עד 95 אחוז",
	nl => "95<sup>e</sup>e percentiel",
	de => "95. Quantil",
},

nutrition_data_per_max => {
	fr => "Maximum",
	en => "Maximum",
	el => "Μέγιστο",
	es => "Máximo",
	pt => "Máximo",
	ro => "Maximum",
	he => "לכל היותר",
	nl => "Maximum",
	nl_be => "Maximum",
	de => "Maximum",
},

nutrition_data_table_sub => {
	fr => "dont",
	en => "-",
	es => "-",
	de => "davon",
	nl => "waarvan",
	nl_be => "waarvan",
},

ecological_data_table => {
	fr => 'Impact écologique',
	en => 'Ecological footprint',
	el => "Οικολογικό αποτύπωμα",
	es => 'Huella ecológica',
	pt => 'Pegada ecológica',
	ro => "Impact ecologic",
	he => 'טביעת רגל אקולוגית',
	it => 'Impronta ecologica',
	nl => "Ecologische impact",
	nl_be => "Ecologische impact",
	de => "Ökologischer Fußabdruck",
},

ecological_data_table_note => {
	fr => "Si l'empreinte carbone est présente sur l'emballage (rarement actuellement), elle est à indiquer pour la même quantité que pour la composition nutritionnelle.",
	en => "If the carbon footprint is specified on the label (rarely at this time), indicate it for the same quantity than the nutritional composition.",
	el => "Αν το αποτύπωμα άνθρακα είναι αποσαφηνισμένο στην ετικέτα (προς το παρόν όχι συχνά απαντώμενο), υποδείξτε το για την ίδια ποσότητα όπως και για τη διατροφική σύνθεση.",
	es => "Si aparece en el envase la huella de carbono (muy raro en la actualidad), indicarla por la misma cantidad que la información nutricional.",
	pt => "Se a pegada de carbono é especificada na embalagem (muito raro hoje em dia), indique-a para a mesma quantidade que para a composição nutricional.",
	ro => "Dacă amprenta de carbon este specificată pe etichetă (rar acum), indicați-o pentru aceeași cantitate ca și compoziția nutrițională.",
	he => "אם טביעת הרגל של הפחמן מצוינת על התווית (נדיר בימינו אנו), כדאי לציין אותה עבור כמות מסוימת מאשר את התרכובת התזונתית.",
	nl => "Als de ecologische voetafdruk op het etiket vermeld wordt (momenteel is dat zelden), geef ze dan voor dezelfde hoeveelheid als voor de nutritionele samenstelling",
	nl_be => "Als de ecologische voetafdruk op het etiket vermeld wordt (momenteel is dat zelden), geef ze dan voor dezelfde hoeveelheid als voor de nutritionele samenstelling",
	de => "Falls der CO₂-Fußabdruck auf der Verpackung angegeben ist (derzeit ist das selten der Fall), dann ist dieser für die selbe Menge der anderen Nährwertangaben einzutragen.",
},

example => {
	fr => "Exemple :",
	en => "Example:",
	el => "Παράδειγμα:",
	es => "Ejemplo:",
	pt => "Exemplo:",
	ro => "Exemplu:",
	he => "דוגמה:",
	it => "Esempio:",
	nl => "Voorbeeld:",
	nl_be => "Voorbeeld:",
	de => "Beispiel:",
},

examples => {
	fr => "Exemples :",
	en => "Examples:",
	el => "Παραδείγματα:",
	es => "Ejemplos:",
	pt => "Exemplos:",
	he => "דוגמאות:",
	ro => "Exemple:",
	it => "Esempi:",
	nl => "Voorbeelden:",
	nl_be => "Voorbeelden:",
	de => "Beispiele:",
},

brands_tagsinput => {
	fr => "ajouter une marque",
	en => 'add a brand',
	da => 'tilføje et mærke',
	el => "προσθέστε μια μάρκα",
	es => "añadir una marca",
	pt => "adicionar uma marca",
	ro => "adăugați o marcă",
	he => "הוספת מותג",
	nl => "een merk toevoegen",
	nl_be => "een merk toevoegen",
	de => "Marke hinzufügen",
	zh => '添加品牌',
},


packaging_tagsinput => {
	fr => "ajouter",
	en => "add a type, shape or material",
	el => "προσθέστε έναν τύπο, σχήμα ή υλικό",
	es => "añadir un tipo, forma o material",
	pt => "adicionar um tipo, forma ou material",
	ro => "adăugați un tip, formă sau material",
	he => "הוספת סוג, צורה או חומר",
	nl => "een soort, vorm of materiaal toevoegen",
	nl_be => "een soort, vorm of materiaal toevoegen",
	de => "Art, Form oder Material hinzufügen",
	zh => '添加类型，外形或材料',
	ru => 'добавить тип, форму или материал',
},

categories_tagsinput => {
	fr => "ajouter une catégorie",
	en => 'add a category',
	da => 'tilføje en kategori',
	el => "προσθέστε μια κατηγορία",
	es => "añadir una categoría",
	pt => "adicionar uma categoria",
	ro => "adugați o categorie",
	he => "הוספת קטגוריה",
	nl => "een categorie toevoegen",
	nl_be => "een categorie toevoegen",
	de => "Kategorie hinzufügen",
	zh => '添加类别',
	ru => 'Добавить категорию',
},

labels_tagsinput => {
	fr => "ajouter un label",
	en => 'add a label',
	da => 'tilføje en etiket',
	el => "προσθέστε μια ετικέτα",
	es => "añadir una etiqueta",
	pt => "adicionar uma etiqueta",
	ro => "adăugați o etichetă",
	he => "הוספת תווית",
	nl => "een keurmerk toevoegen",
	nl_be => "een label toevoegen",
	de => "Label hinzufügen",
	zh => '添加标签',
},

origins_tagsinput => {
	fr => "ajouter une origine",
	en => 'add an origin',
	da => 'tilføje en oprindelse',
	el => "προσθέστε την καταγωγή",
	es => "añadir un origen",
	pt => "adicionar uma origem",
	ro => "adăugați o origine",
	he => "הוספת מקור",
	nl => "herkomst toevoegen",
	nl_be => "herkomst toevoegen",
	de => "Herkunft hinzufügen",
	zh => "添加来源",
},

manufacturing_places_tagsinput => {
	fr => "ajouter un lieu",
	en => 'add a place',
	da => 'tilføj et sted',
	el => "προσθέστε ένα τόπο",
	es => "añadir un lugar",
	pt => "adicionar um local",
	ro => "adăugați un loc",
	he => "הוספת מיקום",
	nl => "een locatie toevoegen",
	nl_be => "een locatie toevoegen",
	de => "Ort hinzufügen",
	zh => '添加地点',
	ru => 'добавить место',
},

purchase_places_tagsinput => {
	fr => "ajouter un lieu",
	en => "add a place",
	el => "προσθέστε ένα τόπο",
es => "añadir un lugar",
	pt => "adicionar um local",
	ro => "adăugați un loc",
	he => "הוספת מיקום",
	nl => "een locatie toevoegen",
	nl_be => "een locatie toevoegen",
	de => "Ort hinzufügen",
},

stores_tagsinput => {
	fr => "ajouter un magasin",
	en => "add a store",
	da => 'tilføje en butik',
	el => "προσθέστε ένα καταστημα",
	es => "añadir una tienda",
	pt => "adicionar uma loja",
	ro => "adăugați un magazin",
	he => "הוספת חנות",
	nl => "een winkel toevoegen",
	nl_be => "een winkel toevoegen",
	de => "Laden hinzufügen",
	zh => '添加商店',
	ru => 'добавить магазин',
},

# MOBILESTRING

fixme_product => {

    ar => 'إذا كانت البيانات غير مكتملة أو غير صحيحة، يمكنك إكمال أو تصحيحها عن طريق تحرير هذه الصفحة.', #ar-CHECK - Please check and remove this comment
	de => "Sollten die die Informationen auf diese Seite unvollständig oder falsch sein, dann können Sie diese vervollständigen oder korrigieren.",
    cs => 'Je-li údaje neúplné nebo nesprávné, můžete doplnit nebo opravit úpravou na tuto stránku.', #cs-CHECK - Please check and remove this comment
	es => "Si la información está incompleta o es incorrecta, puedes completarla o corregirla editando esta página.",
	en => "If the data is incomplete or incorrect, you can complete or correct it by editing this page.",
    it => 'Se i dati sono corretti, è possibile completare o correggerla modificando questa pagina.', #it-CHECK - Please check and remove this comment
    fi => 'Jos tiedot ovat puutteellisia tai virheellisiä, voit täydentää tai korjata sen muokkaamalla tätä sivua.', #fi-CHECK - Please check and remove this comment
	fr => "Si les informations sont incomplètes ou incorrectes, vous pouvez les complèter ou les corriger en modifiant cette fiche.",
	el => "Αν τα δεδομένα είναι εσφαλμένα ή ελλειπή, μπορείτε να τα συμπληρώσετε ή να τα διορθώσετε επεξεργάζοντας αυτή τη σελίδα .",
	he => "אם המידע חלקי או שגוי, ניתן להשלים או לתקן אותו על־ידי עריכת עמוד זה.",
    ja => 'データが不完全または間違っている場合は、完了するか、このページを編集して、それを修正することができます。', #ja-CHECK - Please check and remove this comment
    ko => '데이터가 불완전하거나 부정확 한 경우, 당신은 완료하거나 문서를 편집하여 수정할 수 있습니다.', #ko-CHECK - Please check and remove this comment
	nl => "Indien de informatie onvolledig of foutief is, kan je ze op deze pagina aanvullen of corrigeren.",
	nl_be => "Indien de informatie onvolledig of foutief is, kunt u ze op deze pagina aanvullen of corrigeren.",
    ru => 'Если данные неполными или неверными, вы можете завершить или исправить его, отредактировав эту страницу.', #ru-CHECK - Please check and remove this comment
    pl => 'Jeśli dane są niepełne lub błędne, można uzupełnienie lub poprawienie go do tej wersji.', #pl-CHECK - Please check and remove this comment
	pt => "Se a informação está incompleta ou incorrecta, podes completá-la ou corrigí-la editando esta página.",
	ro => "Dacă datele sunt incomplete sau incorecte, le puteți completa sau corecta modificând această pagină.",
    th => 'หากข้อมูลที่ไม่สมบูรณ์หรือไม่ถูกต้องคุณสามารถดำเนินการหรือแก้ไขได้โดยการแก้ไขหน้านี้', #th-CHECK - Please check and remove this comment
    vi => 'Nếu dữ liệu không đầy đủ hoặc không chính xác, bạn có thể hoàn thành hoặc sửa nó bằng cách chỉnh sửa trang này.', #vi-CHECK - Please check and remove this comment
    zh => '如果数据不完整或不正确，就可以完成或编辑该页面进行纠正。', #zh-CHECK - Please check and remove this comment

},

alcohol_warning => {
	fr => "L'abus d'alcool est dangereux pour la santé. A consommer avec modération.",
	en => "Excess drinking is harmful for health.",
	el => "Η υπερβολική κατανάλωση αλκοόλ είναι επιβλαβής για την υγεία.",
	es => "El exceso de alcohol es perjudicial para la salud. Consúmelo con moderación.",
	pt => "Excesso de álcool é pregudicial para a saúde. Seja responsável. Beba com moderação.",
	ro => "Consumul excesiv de alcool este dăunător sănătății",
	he => "שתייה מוגזמת של אלכוהול עשויה לפגוע בבריאות.",
	nl => "Overmatig alcoholgebruik schaadt de gezondheid. Drink met mate.",
	nl_be => "Overmatig alcoholgebruik schaadt de gezondheid. Drink met mate.",
	de => "Der Missbrauch von Alkohol gefährdet Ihre Gesundheit, mit Bedacht genießen.",
},

warning_3rd_party_content => {
	fr => "Les informations doivent provenir de l'emballage du produit (et non d'autres sites ou du site du fabricant), et vous devez avoir pris vous-même les photos.<br/>
→ <a href=\"https://openfoodfactsfr.uservoice.com/knowledgebase/articles/59183\" target=\"_blank\">Pourquoi est-ce important ?</a>",
	en => "Information and data must come from the product package and label (and not from other sites or the manufacturer's site), and you must have taken the pictures yourself.<br/>
→ <a href=\"\">Why it matters</a>",
el => "Η πληροφορία και τα δεδομένα πρέπει να προέρχονται από την συσκευασία και ετικέτα του προϊόντος (και όχι από άλλες ιστοσελίδες συμπεριλαμβανομένης και της ιστοσελίδας του παραγωγού), και οι φωτογραφίες θα πρέπει να έχουν ληφθεί από εσάς.<br/>
→ <a href=\"\">Why it matters</a>",
	es => "La información debe provenir del propio envase del producto (y no de otros sitios o del sitio web del fabricante), y las fotografías deben haber sido tomadas por usted mismo/a.<br/>
→ <a href=\"\">¿Por qué es importante?</a>",
	pt_pt => "A informação deve ser proveniente da embalabem e do rótulo do produto (e não de outros locais ou da página web do fabricante), e as fotografias devem ser tiradas por si mesmo.<br/>
→ <a href=\"\">Porque é que é importante?</a>",
	ro => "Informația și datele trebuie să provină de pe pachetul și eticheta produsului (nu de pe alte site-uri sau de pe site-ul producătorului), iar fotografia trebuie să fie făcută de voi înșivă.<br/>
→ <a href=\"\">De ce contează?</a>",
	he => "יש להשתמש במידע ובנתונים המופיעים על אריזת המוצר לרבות התווית (ולא מאתרים אחרים או מאתר היצרן), נוסף על כך יש להשתמש בתמונות שצולמו על ידיך בלבד.<br/>",
	nl => "De informatie moet afkomstig zijn van de productverpakking (en niet van een andere site of de site van de producent), en je moet de foto's zelf gemaakt hebben.",
	nl_be => "De informatie moet afkomstig zijn van de verpakking van het product (en niet van een andere site of de site van de producent), en u moet de foto's zelf getrokken hebben.",
	de => "Die Informationen müssen aus der Produktverpackung stammen (nicht von anderen Webseiten oder der Webseite des Herstellers) und die Fotos müssen von Ihnen selbst gemacht worden sein.<br/>
→ <a href=\"https://openfoodfactsfr.uservoice.com/knowledgebase/articles/59183\" target=\"_blank\" hreflang=\"fr\">Warum ist das wichtig?</a>",
},

front_alt => {

    ar => 'نتاج', #ar-CHECK - Please check and remove this comment
	de => "Produkt",
    cs => 'Produkt', #cs-CHECK - Please check and remove this comment
es => "Producto",
	en => "Product",
    it => 'Prodotto', #it-CHECK - Please check and remove this comment
    fi => 'Tuote', #fi-CHECK - Please check and remove this comment
	fr => "Produit",
	el => "Προϊόν",
	he => "מוצר",
    ja => '製品', #ja-CHECK - Please check and remove this comment
    ko => '생성물', #ko-CHECK - Please check and remove this comment
    nl => 'Product',
    nl_be => 'Product',
    ru => 'Продукт', #ru-CHECK - Please check and remove this comment
    pl => 'Produkt', #pl-CHECK - Please check and remove this comment
	pt => "Produto",
	ro => "Produs",
    th => 'สินค้า', #th-CHECK - Please check and remove this comment
    vi => 'Sản phẩm', #vi-CHECK - Please check and remove this comment
    zh => '产品', #zh-CHECK - Please check and remove this comment


},

ingredients_alt => {

	ar => 'المكونات', #ar-CHECK - Please check and remove this comment
	de => "Zutaten",
	cs => 'Složení', #cs-CHECK - Please check and remove this comment
es => "Ingredientes",
	en => "Ingredients",
	it => 'Ingredienti', #it-CHECK - Please check and remove this comment
	fi => 'Ainekset', #fi-CHECK - Please check and remove this comment
	fr => "Ingrédients",
	el => "Συστατικά",
	he => "רכיבים",
	ja => '材料', #ja-CHECK - Please check and remove this comment
	ko => '성분', #ko-CHECK - Please check and remove this comment
	nl => "Ingrediënten",
	nl_be => "Ingrediënten",
	ru => 'Ингредиенты', #ru-CHECK - Please check and remove this comment
	pl => 'Składniki', #pl-CHECK - Please check and remove this comment
	pt => "Ingredientes",
	ro => "Ingrediente",
	th => 'ส่วนผสม', #th-CHECK - Please check and remove this comment
	vi => 'Thành phần', #vi-CHECK - Please check and remove this comment
	zh => '主料', #zh-CHECK - Please check and remove this comment

},

nutrition_alt => {

    ar => 'حقائق غذائية', #ar-CHECK - Please check and remove this comment
	de => "Nährwertinformationen",
    cs => 'Nutriční hodnoty', #cs-CHECK - Please check and remove this comment
	es => "Información nutricional",
	en => "Nutrition facts",
    it => 'Informazioni nutrizionali', #it-CHECK - Please check and remove this comment
    fi => 'Ravintosisältö', #fi-CHECK - Please check and remove this comment
	fr => "Informations nutritionnelles",
	el => "Διατροφικά στοιχεία",
	he => "מפרט תזונתי",
    ja => '栄養成分表', #ja-CHECK - Please check and remove this comment
    ko => '영양 성분 표시', #ko-CHECK - Please check and remove this comment
	nl => "Voedingswaarden",
	nl_be => "Nutritionele informatie",
    ru => 'Пищевая ценность', #ru-CHECK - Please check and remove this comment
    pl => 'Wartości odżywcze', #pl-CHECK - Please check and remove this comment
	pt => "Informação nutricional",
	ro => "Valori nutriționale",
    th => 'ข้อมูลโภชนาการ', #th-CHECK - Please check and remove this comment
    vi => 'Giá trị dinh dưỡng', #vi-CHECK - Please check and remove this comment
    zh => '营养成分', #zh-CHECK - Please check and remove this comment

},

# will be used in sentences like "for products from the yogurts category",
for => {
	fr => 'pour',
	en => 'for',
	el => "για",
	es => 'para',
	pt => 'para',
	ro => "pentru",
	he => 'עבור',
	nl => "voor",
	nl_be => "voor",
	de => "für",
},

brands_products => {
	fr => "Les produits de la marque %s",
	en => "Products from the %s brand",
	el => "Προϊόντα από την %s μάρκα",
	es => "Productos de la marca %s",
	pt => "Produtos da marca %s",
	ro => "Produse de la marca %s",
	he => "מוצרים מבית המותג %s",
	nl => "Producten van het merk %s",
	nl_be => "Producten van het merk %s",
	de => "Die Produkte von der Marke %s",
},

categories_products => {
	fr => "Les produits de la catégorie %s",
	en => "Products from the %s category",
	el => "Προϊόντα από την %s κατηγορία",
	es => "Productos de la categoría %s",
	pt => "Produtos da categoria %s",
	ro => "Produse din categoria %s",
	he => "מוצרים מהקטגוריה %s",
	nl => "Producten van de categorie %s",
	nl_be => "Producten van de categorie %s",
	de => "Die Produkte von der Kategorie %s",
},

emb_codes_products => {
	fr => "Les produits dont le code emballeur est %s",
	en => "Products with the emb code %s",
	el => "Προϊόντα με τον κωδικό συσκευασίας %s",
	es => "Productos con código de envasador %s",
	pt => "Produtos com o código de embalador %s",
	nl => "Producten met verpakkerscode %s",
	nl_be => "Producten met verpakkerscode %s",
	de => "Die Produkte mit Verpackungscode %s",
},

cities_products => {
	fr => "Les produits dont la commune d'emballage est %s",
	en => "Products packaged in the city of %s",
	el => "Προϊόντα συσκευασμένα στην πόλη %s",
	es => "Productos envasados en el municipio de %s",
	pt => "Produtos embalados na cidade de %s",
	ro => "Produse împachetate în orașul %s",
	he => "מוצרים שנארזו בעיר %s",
	nl => "Producten verpakt in de stad %s",
	nl_be => "Producten verpakt in de stad %s",
	de => "Produkte verpackt in der Stadt %s",
},

packaging_products => {
	fr => "Les produits avec le conditionnement %s",
	en => "Products with a %s packaging",
	el => "Προϊόντα με %s συσκευασία",
	es => "Productos con envase %s",
	pt => "Produtos com embalagem em %s",
	ro => "Produse cu ambalaj de %s",
	he => "מוצרים באריזה מסוג %s",
	nl => "Producten met een verpakking van %s",
	nl_be => "Producten met een verpakking van %s",
	de => "Produkte mit der Verpackung %s",
},

origins_products => {
	fr => "Les produits dont l'origine des ingrédients est %s",
	en => "Products with ingredients originating from %s",
	el => "Προϊόντα με συστατικά προερχόμενα από %s",
	es => "Productos originarios de %s",
	pt => "Produtos originários de %s",
	ro => "Produse cu ingrediente originare din %s",
	he => "מוצרים שמקורם %s",
	nl => "Producten waarvan de ingrediënten afkomstig zijn uit %s",
	nl_be => "Producten waarvan de ingrediënten afkomstig zijn uit %s",
	de => "Produkte, deren Herkunft der Zutaten %s ist, ",
},

emb_code_products => {
	fr => "Les produits emballés par l'entreprise dont le code emballeur est %s",
	en => "Products packaged by the company with emb code %s",
	el => "Προϊόντα συσκευασμένα από την εταιρεία με κωδικό συσκευασίας %s",
	es => "Productos envasados por la empresa con código de envasado %s",
	pt => "Produtos embalados pela empresa com o código de embalador %s",
	nl => "Producten verpakt door het bedrijf met de verpakkerscode %s",
	nl_be => "Producten verpakt door het bedrijf met de verpakkerscode %s",
	de => "Produkte verpackt vom UNternehmen dessen Produzenten-Code ist %s",
},

manufacturing_places_products => {
	fr => "Les produits par lieu de fabrication ou transformation :  %s",
	en => "Products manufactured or processed in %s",
	el => "Προϊόντα παρασκευασμένα ή επεξεργασμένα σε %s",
	es => "Productos fabricados o transformados en  %s",
	ro => "Produse fabricate sau procesate în %s",
	pt => "Produtos fabricados ou transformados em %s",
	nl => "Producten geproduceerd of verwerkt in %s",
	nl_be => "Producten geproduceerd of verwerkt in %s",
	de => "Produkte nach Herstellungs- oder Verwandlungsort: %s",
},

purchase_places_products => {
	fr => "Les produits par lieu de vente :  %s",
	en => "Products sold in %s",
	el => "Προϊόντα πωλούμενα ανά σημείο πώλησης: %s",
	es => "Productos vendidos en %s",
	pt => "Produtos vendidos em %s",
	ro => "Produse vândute în %s",
	he => "מוצרים שנמכרים ב%s",
	nl => "Producten verkocht in %s",
	nl_be => "Producten verkocht in %s",
	de => "Produkte nach Verkaufsort: %s",
},

stores_products => {
	fr => "Les produits par magasin : %s",
	en => "Products sold at %s",
	el => "Προϊόντα πωλούμενα ανά κατάστημα: %s",
	es => "Productos vendidos en el comercio %s",
	pt => "Produtos vendidos na loja:  %s",
	ro => "Produse vândute la %s",
	he => "מוצרים שנמכרים אצל",
	nl => "Producten verkocht in %s",
	nl_be => "Producten verkocht in %s",
	de => "Produkte nach Laden: %s",
},

countries_products => {
	fr => "Les produits vendus dans le pays : %s",
	en => "Products sold in %s",
	el => "Προϊόντα πωλούμενα στις χώρες: %s",
	es => "Productos vendidos en %s",
	pt => "Produtos vendidos no país : %s", # we have 3 prepositions (em, na, no) depending on the country; opting for the same logic as the French translation
	ro => "Produse vândute în %s",
	he => "מוצרים שנמכרים ב%s",
	nl => "Producten verkocht in %s",
	nl_be => "Producten verkocht in %s",
	de => "Produkte verkauft im Land: %s",
},

ingredients_products => {
	fr => "Les produits qui contiennent l'ingrédient %s",
	en => "Products that contain the ingredient %s",
	el => "Προϊόντα που περιέχουν τα συστατικά %s",
	es => "Productos que contienen el ingrediente %s",
	pt => "Produtos que contêm o ingrediente %s",
	ro => "Produse care conțin ingredientul %s",
	he => "מוצרים המכילים את הרכיב %s",
	nl => "Producten met het ingrediënt %s",
	nl_be => "Producten met het ingrediënt %s",
	de => "Produkte mit Zutaten %s",
},

labels_products => {
	fr => "Les produits qui possèdent le label %s",
	en => "Products that have the label %s",
	el => "Προϊόντα που έχουν την ετικέτα %s",
	es => "Productos con la etiqueta %s",
	pt => "Produtos com a etiqueta %s",
	ro => "Produse care au eticheta %s",
	he => "מוצרים הנושאים את התווית %s",
	nl => "Producten met het keurmerk %s",
	nl_be => "Producten met het label %s",
	de => "Produkte mit Label %s",
},

nutriments_products => {
	fr => "Les produits qui contiennent le nutriment %s",
	en => "Products that contain the nutriment %s",
	el => "Προϊόντα που περιέχουν το θρεπτικό συστατικό %s",
	es => "Productos que contienen el nutriente %s",
	pt => "Produtos que contêm o nutriente %s",
	ro => "Produse care conțin nutrientul %s",
	he => "מוצרים המכילים את הרכיב התזונתי %s",
	nl => "Producten met de voedingsstof %s",
	nl_be => "Producten met de voedingsstof %s",
	de => "Produkte mit Nährstoff %s",
},

users_products => {
	fr => "Les produits ajoutés par %s",
	en => "Products added by %s",
	el => "Προϊόντα που προστέθηκαν από %s",
	es => "Productos añadidos por %s",
	pt => "Produtos adicionados por %s",
	ro => "Produse adăugate de %s",
	he => "מוצרים שנוספו על־ידי %s",
	nl => "Producten toegevoegd door %s",
	nl_be => "Producten toegevoegd door %s",
	de => "Produkte, die von %s hinzugefügt wurden",
	fi => "Tuotteen lisäsi %s",
},

users_add_products => {
	fr => "Les produits qui ont été ajoutés par le contributeur %s",
	en => "Products that were added by the user %s",
	el => "Προϊόντα που προστέθηκαν από το χρήστη %s",
	es => "Productos que fueron añadidos por el usuario %s",
	pt_pt => "Produtos que foram adicionados pelo utilizador %s",
	ro => "Produse care au fost adăugate de către utilizatorul %s",
	he => "מוצרים שנוספו על־ידי המשתמש %s",
	nl => "Producten die toegevoegd werden door gebruiker %s",
	nl_be => "Producten die toegevoegd werden door gebruiker %s",
	de => "Produkte, die von dem Mitwirkenden %s hinzugefügt wurden",
},

users_edit_products => {
	fr => "Les produits qui ont été modifiés par le contributeur %s",
	en => "Products that were edited by the user %s",
	el => "Προϊόντα που επεξεργάστηκαν από το χρήστη %s",
	es => "Productos que fueron editados por el usuario %s",
	pt_pt => "Produtos que foram editados pelo utilizador %s",
	ro => "Produse care au fost modificate de către utilizatorul %s",
	he => "מוצרים שנערכו על־ידי המשתמש %s",
	nl => "Producten die aangepast werden door gebruiker %s",
	nl_be => "Producten die aangepast werden door gebruiker %s",
	de => "Produkte, die von dem Mitwirkenden %s verändert wurden",
},

brands_s => {
	fr => "marque",
	en => "brand",
	el => "μαρκα",
	es => "marca",
	pt => "marca",
	ro => "marcă",
	he => "מותג",
	nl => "merk",
	nl_be => "merk",
	de => "Marke",
},

brands_p => {
	fr => "marques",
	de => "Marken",
	el => "μαρκες",
	en => "brands",
	es => "marcas",
	ro => "mărci",
	he => "מותגים",
	nl => "merken",
	nl_be => "merken",
},

categories_s => {
	fr => "catégorie",
	en => "category",
	el => "κατηγορία",
	es => "categoría",
	pt => "categoria",
	ro => "categorie",
	he => "קטגוריה",
	nl => "categorie",
	nl_be => "categorie",
	de => "Kategorie",
},

categories_p => {
	fr => "catégories",
	de => "Kategorien",
	el => "κατηγορίες",
	en => "categories",
	es => "categorías",
	pt => "categorias",
	ro => "categorii",
	he => "קטגוריות",
	nl => "categorieën",
	nl_be => "categorieën",
},

pnns_groups_1_s => {
	en => "PNNS group 1",
},

pnns_groups_1_p => {
	en => "PNNS groups 1",
},

pnns_groups_2_s => {
	en => "PNNS group 2",
},

pnns_groups_2_p => {
	en => "PNNS groups 2",
},

emb_codes_s => {
	fr => "code emballeur",
	en => "packager code",
	el => "κωδικός συσκευαστή",
	es => "código de envasador",
	pt => "código de embalador",
	ro => "codul ambalatorului",
	nl => "verpakkerscode",
	nl_be => "verpakkerscode",
	de => "Produzenten-Code",
},

emb_codes_p => {
	fr => "codes emballeurs",
	en => "packager codes",
	el => "κωδικοί συσκευαστή",
	es => "códigos de envasadores",
	pt => "códigos de embalador",
	ro => "codurile ambalatorului",
	nl => "verpakkerscodes",
	nl_be => "verpakkerscodes",
	de => "Produzenten-Codes",
},

cities_s => {
	fr => "commune d'emballage",
	en => "packaging city",
	el => "τόπος συσκευασίας",
	es => "Municipio de envasado",
	pt => "cidade de embalamento",
	ro => "orașul de împachetare",
	he => "עיר האריזה",
	nl => "verpakkingstad",
	nl_be => "stad van verpakking",
	de => "Verpackungsort",
},

cities_p => {
	fr => "communes d'emballage",
	en => "packaging cities",
	el => "τόποι συσκευασίας",
	es => "Municipios de envasado",
	pt => "cidades de embalamento",
	ro => "orașele de împachetare",
	he => "ערי האריזה",
	nl => "verpakkingsteden",
	nl_be => "steden van verpakking",
	de => "Verpackungsorte",
},

purchase_places_s => {
	fr => "lieu de vente",
	en => "purchase place",
	el => "τόπος αγοράς",
	es => "lugar de compra",
	pt => "local de compra",
	ro => "locația de cumpărare",
	he => "מקום הרכישה",
	nl => "verkooplocatie",
	nl_be => "verkooplocatie",
	de => "Verkaufsort",
},

purchase_places_p => {
	fr => "lieux de vente",
	en => "purchase places",
	el => "τόποι αγοράς",
	es => "lugares de compra",
	pt => "locais de compra",
	ro => "locațiile de cumpărare",
	he => "מקומות הרכישה",
	nl => "verkooplocaties",
	nl_be => "verkoopslocaties",
	de => "Verkaufsorte",
},

manufacturing_places_s => {
	fr => "lieu de fabrication ou de transformation",
	en => "manufacturing or processing place",
	el => "τόπος παρασκευής ή επεξεργασίας",
	es => "lugar de fabricación o de transformación",
	ro => "locul de fabricație sau de procesare",
	pt => "local de fabrico",
	nl => "productie- of verwerkingslocatie",
	nl_be => "productie- of verwerkingslocatie",
	de => "Herkunfts- oder Verwandlungsort",
},

manufacturing_places_p => {
	fr => "lieux de fabrication ou de transformation",
	en => "manufacturing or processing places",
	el => "τόποι παρασκευής ή επεξεργασίας",
	es => "lugares de fabricación o de transformación",
	ro => "locul de fabricație sau de procesare",
	pt => "locais de fabrico",
	nl => "productie- of verwerkingslocaties",
	nl_be => "productie- of verwerkingslocaties",
	de => "Herkunfts- oder Verwandlungsorte",
},

stores_s => {
	fr => "magasin",
	en => "store",
	el => "καταστημα",
	es => "tienda",
	pt => "loja",
	ro => "magazin",
	he => "חנות",
	nl => "winkel",
	nl_be => "winkel",
	de => "Laden",
},

stores_p => {
	fr => "magasins",
	en => "stores",
	el => "καταστηματα",
	es => "tiendas",
	pt => "lojas",
	ro => "magazine",
	he => "חנויות",
	nl => "winkels",
	nl_be => "winkels",
	de => "Läden",
},

countries_s => {
	fr => "pays",
	en => "country",
	el => "χωρα",
	es => "país",
	pt => "país",
	ro => "țară",
	he => "מדינה",
	nl => "land",
	nl_be => "land",
	de => "Land",
},

countries_p => {
	fr => "pays",
	en => "countries",
	el => "χωρες",
	es => "países",
	pt => "países",
	ro => "țări",
	he => "מדינות",
	nl => "landen",
	nl_be => "landen",
	de => "Länder",
},

packaging_s => {
	fr => "conditionnement",
	en => "packaging",
	el => "συσκευασία",
	es => "envase",
	pt => "embalagem",
	ro => "ambalare",
	he => "אריזה",
	nl => "verpakking",
	nl_be => "verpakking",
	de => "Verpackung",
},

packaging_p => {
	fr => "conditionnements",
	en => "packaging",
	el => "συσκευασίες",
	es => "envases",
	pt => "embalagens",
	ro => "ambalaje",
	he => "אריזה",
	nl => "verpakking",
	de => "Verpackungen",
},

origins_s => {
	fr => "origine des ingrédients",
	en => "origin of ingredients",
	el => "προέλευση συστατικών",
	es => "origen",
	pt => "origem",
	ro => "originea ingredientelor",
	he => "מקור",
	nl => "herkomst van de ingrediënten",
	nl_be => "herkomst van de ingrediënten",
	de => "Zutatenherkunft",
},

origins_p => {
	fr => "origines des ingrédients",
	en => "origins of ingredients",
	el => "προελευσεις συστατικών",
	es => "orígenes",
	pt => "origens",
	ro => "originile ingredientelor",
	he => "מקורות",
	nl => "herkomst",
	nl_be => "herkomst",
	de => "Zutatenherkünfte",
},

emb_code_s => {
	fr => "code emballeur (EMB)",
	en => "EMB code",
	el => "Κωδικός συσκευαστή",
	es => "código de envasador (EMB)",
	pt => "código de embalador",
	nl => "verpakkerscode",
	nl_be => "verpakkerscode",
	de => "Produzenten-Code",
},

emb_code_p => {
	fr => "codes emballeurs (EMB)",
	en => "EMB codes",
	el => "Κωδικοί συσκευαστών",
	es => "códigos de envasador (EMB)",
	pt => "códigos de embalador",
	nl => "verpakkerscodes",
	nl_be => "verpakkerscodes",
	de => "Produzenten-Codes",
},

ingredients_s => {
	fr => "ingrédient",
	en => "ingredient",
	el => "συστατικό",
	es => "ingrediente",
	pt => "ingrediente",
	ro => "ingredient",
	he => "רכיב",
	nl => "ingrediënt",
	nl_be => "ingrediënt",
	de => "Zutat",
},

ingredients_p => {
	fr => "ingrédients",
	en => "ingredients",
	el => "συστατικά",
	es => "ingredientes",
	pt => "ingredientes",
	ro => "ingrediente",
	he => "רכיבים",
	nl => "ingrediënten",
	nl_be => "ingrediënten",
	de => "Zutaten",
},

traces_s => {
	fr => "trace",
	en => "trace",
	es => "traza",
	el => "ίχνος",
	pt => "traço",
	pt_pt => "vestígio",
	ro => "urmă",
	he => "עקבה",
	nl => "spoor",
	nl_be => "spoor",
	de => "Spur",
},

traces_p => {
	fr => "traces",
	en => "traces",
	es => "trazas",
	el => "ίχνη",
	pt => "traços",
	pt_pt => "vestígios",
	ro => "urme",
	he => "עקבות",
	nl => "sporen",
	nl_be => "sporen",
	de => "Spuren",
},

labels_s => {
	fr => "label",
	en => "label",
	es => "etiqueta",
	el => "ετικέτα",
	pt => "etiqueta",
	ro => "etichetă",
	he => "תווית",
	nl => "keurmerk",
	nl_be => "label",
	de => "Label",
},

labels_p => {
	fr => "labels",
	en => "labels",
	el => "ετικέτες",
	es => "etiquetas",
	pt => "etiquetas",
	ro => "etichete",
	he => "תוויות",
	nl => "keurmerken",
	nl_be => "labels",
	de => "Labels",
},

nutriments_s => {
	fr => "nutriment",
	en => "nutriment",
	es => "nutriente",
	el => "θρεπτικό συστατικό",
	pt => "nutriente",
	ro => "nutrient",
	he => "רכיב תזונתי",
	nl => "voedingsstof",
	nl_be => "voedingsstof",
	de => "Nährstoff",
},

nutriments_p => {
	fr => "nutriments",
	en => "nutriments",
	el => "θρεπτικά συστατικά",
	es => "nutrientes",
	pt => "nutrientes",
	ro => "nutriente",
	he => "רכיבים תזונתיים",
	nl => "voedingsstoffen",
	nl_be => "voedingsstoffen",
	de => "Nährstoffe",
},

known_nutrients_s => {
	fr => "nutriment connu",
	en => "known nutrient",
	el => "γνωστό θρεπτικό συστατικό",
	es => "nutriente conocido",
	pt => "nutriente conhecido",
	ro => "nutrient cunoscut",
	he => "מרכיב תזונתי ידוע",
	nl => "bekende voedingsstof",
	nl_be => "gekende voedingsstof",
	de => "bekannter Nährstoff",
},

known_nutrients_p => {
	fr => "nutriments connus",
	en => "known nutrients",
	el => "γνωστά θρεπτικά συστατικά",
	es => "nutrientes conocidos",
	pt => "nutrientes conhecidos",
	ro => "nutriente cunoscute",
	he => "מרכיבים תזונתיים ידועים",
	nl => "bekende voedingsstoffen",
	nl_be => "gekende voedingsstoffen",
	de => "bekannte Nährstoffe",
},

unknown_nutrients_s => {
	fr => "nutriment inconnu",
	en => "unknown nutrient",
	el => "άγνωστο θρεπτικό συστατικό",
	es => "nutriente desconocido",
	pt => "nutriente desconhecido",
	ro => "nutrint necunoscut",
	he => "מרכיב תזונתי בלתי ידוע",
	nl => "onbekende voedingsstof",
	nl_be => "onbekende voedingsstof",
	de => "unbekannter Nährstoff",
},

unknown_nutrients_p => {
	fr => "nutriments inconnus",
	en => "unknown nutrients",
	el => "άγνωστα θρεπτικά συστατικά",
	es => "nutrientes desconocidos",
	pt => "nutrientes desconhecidos",
	ro => "nutriente necunoscute",
	he => "מרכיבים תזונתיים בלתי ידועים",
	nl => "onbekende voedingsstoffen",
	nl_be => "onbekende voedingsstoffen",
	de => "unbekannte Nährstoffe",
},

entry_dates_s => {
	fr => "Date d'ajout",
	el => "Ημερομηνία εισόδου",
	en => "Entry date",
	nl => "Datum toegevoegd",
	nl_be => "Datum toegevoegd",
},

entry_dates_p => {
	fr => "Dates d'ajout",
	el => "Ημερομηνίες εισόδου",
	en => "Entry dates",
	nl => "Datums toegevoegd",
	nl_be => "Datums toegevoegd",
},

last_edit_dates_s => {
	en => "Last edit date",
	el => "Ημερομηνία τελευταίας τροποποίησης",
	fr => "Date de dernière modification",
	nl => "Laatste wijzigingsdatum",
	nl_be => "Laatste wijzigingsdatum",
},

last_edit_dates_p => {
	en => "Last edit dates",
	el => "Ημερομηνίες τελευταίας τροποποίησης",
	fr => "Dates de dernière modification",
	nl => "Laatste wijzigingsdatums",
	nl_be => "Laatste wijzigingsdatums",
},

nutrition_grades_s => {
	en => "Nutrition grade",
	el => "Διατροφική σημείωση",
	fr => "Note nutritionnelle",
	nl => "Voedingsgraad",
	nl_be => "Voedingsgraad",
},

nutrition_grades_p => {
	en => "Nutrition grades",
	el => "Διατροφικές σημειώσεις",
	fr => "Notes nutritionnelles",
	nl => "Voedingsgraden",
	nl_be => "Voedingsgraden",
},

nutrient_levels_s => {
	fr => "repère nutritionnel",
	en => "nutrient level",
	es => "valor nutricional",
	el => "διατροφικός δείκτης",
	pt => "valor nutricional",
	ro => "valoare nutrițională",
	he => "רמת המרכיב התזונתי",
	nl => "voedingswaarde",
	nl_be => "voedingswaarde",
	de => "Nahrungsbedarf",
},

nutrient_levels_p => {
	fr => "repères nutritionnels",
	en => "nutrient levels",
	es => "valores nutricionales",
	el => "διατροφικοί δείκτες",
	pt => "valores nutricionais",
	ro => "valori nutriționale",
	he => "רמות המרכיבים התזונתיים",
	nl => "voedingswaarden",
	nl_be => "voedingswaarden",
	de => "Nahrungsbedarf",
},

nutrient_levels_info => {

    ar => 'مستويات المواد الغذائية ل 100 غرام', #ar-CHECK - Please check and remove this comment
	de => "Nahrungsbedarf pro 100 g",
    cs => 'Nutriční hodnoty pro 100 g', #cs-CHECK - Please check and remove this comment
	es => "Valores nutricionales por 100 g",
	en => "Nutrient levels for 100 g",
    it => 'I livelli di nutrienti per 100 g', #it-CHECK - Please check and remove this comment
    fi => 'Ravinnepitoisuudet 100 g', #fi-CHECK - Please check and remove this comment
	fr => "Repères nutritionnels pour 100 g",
 	el => "Διατροφικοί δείκτες ανά 100 g",
	he => "רמות המרכיבים התזונתיים ל־100 גרם",
    ja => '100グラムのための栄養レベル', #ja-CHECK - Please check and remove this comment
    ko => '100g에 대한 영양 수준', #ko-CHECK - Please check and remove this comment
	nl => "Voedingswaarden per 100 g",
	nl_be => "Voedingswaarden per 100 g",
    ru => 'Питательные уровни 100 г', #ru-CHECK - Please check and remove this comment
    pl => 'Żywnościowe poziomy 100 g', #pl-CHECK - Please check and remove this comment
	pt => "Valores nutricionais por 100 g",
	ro => "Valori nutriționale pentru 100g",
    th => 'ระดับสารอาหารสำหรับ 100 กรัม', #th-CHECK - Please check and remove this comment
    vi => 'Mức độ dinh dưỡng cho 100 g', #vi-CHECK - Please check and remove this comment
    zh => '营养水平于100g', #zh-CHECK - Please check and remove this comment

},

nutrient_levels_link => {
	fr => "/reperes-nutritionnels",
	en => "/nutrient-levels",
},

users_s => {
	fr => "contributeur",
	de => 'Mitwirkende',
	el => "συντελεστής",
	en => 'contributor',
	es => 'contribuyente',
	pt => 'colaborador',
	it => 'contributore',
	ro => "contributor",
	he => 'תורם',
	nl => "gebruiker",
	nl_be => "gebruiker",
},

users_p => {
	fr => "contributeurs",
	de => 'Mitwirkende',
	el => "συντελεστές",
	en => 'contributors',
	es => 'contribuyentes',
	pt => 'colaboradores',
	it => 'contributori',
	ro => "contributori",
	he => 'תורמים',
	nl => "gebruikers",
	nl_be => "gebruikers",
},
photographers_s => {
	fr => 'photographe',
	en => 'photographer',
	el => "φωτογράφος",
	es => 'fotógrafo',
	pt => 'fotógrafo',
	ro => "fotograf",
	he => 'צלם',
	nl => "fotograaf",
	nl_be => "fotograaf",
	de => "Fotograf",
},
photographers_p => {
	fr => 'photographes',
	en => 'photographers',
	el => "φωτογράφοι",
	es => 'fotógrafos',
	pt => 'fotógrafos',
	ro => "fotografi",
	he => 'צלמים',
	nl => "fotografen",
	nl_be => "fotografen",
	de => "Fotografen",
},
editors_s => {
	fr => 'éditeur',
	en => 'editor',
},
editors_p => {
	fr => 'éditeurs',
	en => 'editors',
},
informers_s => {
	fr => 'informateurs',
	en => 'informers',
	el => "πληροφοριοδότης",
	es => 'informante',
	pt => 'informante',
	pt_pt => 'informador',
	ro => "informator",
	he => 'מודיע',
	nl => "informant",
	nl_be => "informant",
	de => "Informant",
},
informers_p => {
	fr => 'informateurs',
	en => 'informers',
	el => "πληροφοριοδότες",
	es => 'informantes',
	pt => 'informantes',
	pt_pt => 'informadores',
	ro => "informatori",
	he => 'מודיעים',
	nl => "informanten",
	nl_be => "informanten",
	de => "Informanten",
},
correctors_s => {
	fr => 'correcteur',
	en => 'corrector',
	el => "διορθωτής",
	es => 'corrector',
	pt => 'corretor',
	pt_pt => 'revisor',
	ro => "corector",
	he => 'מתקן',
	nl => "verbeteraar",
	nl_b => "corrector",
	de => "Korrektor",
},
correctors_p => {
	fr => 'correcteurs',
	en => 'correctors',
	el => "διορθωτές",
	es => 'correctores',
	pt => 'corretores',
	pt_pt => 'revisores',
	ro => "corectori",
	he => 'מתקנים',
	nl => "verbeteraren",
	nl_be => "correctoren",
	de => "Korrektoren",
},
checkers_s => {
	fr => 'vérificateur',
	en => 'checker',
	el => "ελεγκτής",
	es => 'verificador',
	pt => 'verificador',
	ro => "verificator",
	he => 'בודק',
	nl => "controleur",
	nl_be => "verificateur",
	de => "Prüfer",
},
checkers_p => {
	fr => 'vérificateurs',
	en => 'checkers',
	el => "ελεγκτές",
	es => 'verificadores',
	pt => 'verificadores',
	ro => "verificatori",
	he => 'בודקים',
	nl => "controleurs",
	nl_be => "verificateurs",
	de => "Prüfer",
},
states_s => {
	fr => 'état',
	en => 'state',
	el => "κατασταση",
	es => 'estado',
	pt => 'estado',
	ro => "status",
	he => 'מצב',
	nl => "status",
	nl_be => "status",
	de => "Stand",
},
states_p => {
	fr => 'états',
	en => 'states',
	el => "καταστάσεις",
	es => 'estados',
	pt => 'estados',
	ro => "statusuri",
	he => 'מצבים',
	nl => "statussen",
	nl_be => "statussen",
	de => "Stände",
},
ingredients_p => {
	fr => 'ingrédient',
	el => "συστατικό",
de => 'Zutat',
	en => 'ingredient',
	es => 'ingrediente',
	pt => 'ingrediente',
	ro => "ingredient",
	it => 'ingredient',
	he => 'רכיב',
	nl => "ingrediënt",
	nl_be => "ingrediënt",
},
ingredients_p => {
	fr => 'ingrédients',
	de => 'Zutaten',
	el => "συστατικά",
	en => 'ingredients',
	es => 'ingredientes',
	pt => 'ingredientes',
	ro => "ingrediente",
	it => 'ingredientes',
	he => 'רכיבים',
	nl => "ingrediënten",
	nl_be => "ingrediënten",
},

allergens_s => {
	fr => 'allergène',
	de => 'allergen',
	el => "αλλεργιονο",
	en => 'allergen',
	es => 'alergeno',
	it => 'allergene',
#	ru => 'аллергены',
	ar => 'moussabib-hassassiya',
	pt => 'alergenico',
	pt_pt => 'alergéneo',
	ro => 'alergen',
	he => 'khomer-alergeni',
	nl => "allergeen",
	nl_be => "allergeen",
},

allergens_p => {
	fr => 'allergènes',
	de => 'allergene',
	en => 'allergens',
	el => "αλλεργιογόνα",
	es => 'alergenos',
#	it => 'allergene',
#	ru => 'аллергены',
#	ar => 'moussabib-hassassiya',
	pt => 'alergenicos',
	pt_pt => 'alergéneos',
	ro => 'alergeni',
#	he => 'khomer-alergeni',
	nl => "allergenen",
	nl_be => "allergenen",
},

additives_s => {
	fr => "additif",
	en => "additive",
	el => "πρόσθετο",
	es => "aditivo",
	pt => "aditivo",
	ro => "aditiv",
	he => "תוסף",
	nl => "additief",
	nl_be => "additief",
	de => "Zusatzstoff",
	zh => "添加剂",
},

additives_p => {
	fr => "additifs",
	en => "additives",
	es => "aditivos",
	el => "πρόσθετα",
	pt => "aditivos",
	ro => "aditivi",
	he => "תוספים",
	nl => "additieven",
	nl_be => "additieven",
	de => "Zusatzstoffe",
	zh => "添加剂",
},

ingredients_from_palm_oil_s => {
	fr => "ingrédient issu de l'huile de palme",
	en => "ingredient from palm oil",
	el => "συστατικό προερχόμενο από φοινικέλαιο",
	es => "ingrediente procedente de aceite de palma",
	pt_pt => "ingrediente proveniente de óleo de palma",
	ro => "ingredient din ulei de palmier",
	he => "רכיב משמן דקלים",
	nl => "ingrediënt uit palmolie",
	nl_be => "ingrediënt uit palmolie",
	de => "Zutat aus Palmöl",
},

ingredients_from_palm_oil_p => {
	fr => "ingrédients issus de l'huile de palme",
	en => "ingredients from palm oil",
	el => "συστατικά προερχόμενα από φοινικέλαιο",
	es => "ingredientes procedentes de aceite de palma",
	pt_pt => "ingredientes a partir de óleo de palma",
	ro => "ingrediente din ulei de palmier",
	he => "רכיבים משמן דקלים",
	nl => "ingrediënten uit palmolie",
	nl_be => "ingrediënten uit palmolie",
	de => "Zutaten aus Palmöl",
},

ingredients_that_may_be_from_palm_oil_s => {
	fr => "ingrédient pouvant être issu de l'huile de palme",
	en => "ingredient that may be from palm oil",
	el => "συστατικό πιθανώς προερχόμενο από φοινικέλαιο",
	es => "ingrediente que puede proceder de aceite de palma",
	pt_pt => "ingrediente que pode partir de óleo de palma",
	ro => "ingredient care ar putea proveni din ulei de palmier",
	he => "רכיב שעשוי להיות משמן דקלים",
	nl => "ingrediënt dat mogelijk palmolie bevat",
	nl_be => "ingrediënt dat mogelijk palmolie bevat",
	de => "Zutat, die möglicherweise aus Palmöl stammt",
},

ingredients_that_may_be_from_palm_oil_p => {
	fr => "ingrédients pouvant être issus de l'huile de palme",
	en => "ingredients that may be from palm oil",
	el => "συστατικά πιθανώς προερχόμενα από φοινικέλαιο",
	es => "ingredientes que pueden proceder de aceite de palma",
	pt_pt => "ingredientes que podem partir de óleo de palma",
	ro => "ingrediente care ar putea proveni din ulei de palmier",
	he => "רכיבים שעשויים להיות משמן דקלים",
	nl => "ingrediënten die mogelijk palmolie bevatten",
	nl_be => "ingrediënten die mogelijk palmolie bevatten",
	de => "Zutaten, die möglicherweise aus Palmöl stammen",
},

ingredients_from_or_that_may_be_from_palm_oil_s => {
	fr => "ingrédient issu ou pouvant être issu de l'huile de palme",
	en => "ingredient from or that may be from palm oil",
	el => "συστατικό προερχόμενο από/πιθανώς από φοινικέλαιο",
	es => "ingrediente que procede o puede proceder de aceite de palma",
	pt_pt => "ingrediente a partir ou que pode partir de óleo de palma",
	ro => "ingredient care ar putea fi din sau ar putea proveni din ulei de palmier",
	he => "רכיבים שעשויים או מיוצרים משמן דקלים",
	nl => "ingrediënt dat (mogelijk) palmolie bevat",
	nl_be => "ingrediënt dat (mogelijk) palmolie bevat",
	de => "Zutat, die (möglicherweise) aus Palmöl stammt",
},

ingredients_from_or_that_may_be_from_palm_oil_p => {
	fr => "ingrédients issus ou pouvant être issus de l'huile de palme",
	en => "ingredients from or that may be from palm oil",
	el => "συστατικά προερχόμενα από/πιθανώς από φοινικέλαιο",
	es => "ingredientes que proceden o pueden proceder de aceite de palma",
	pt_pt => "ingredientes a partir ou que podem partir de óleo de palma",
	ro => "ingrediente care ar putea fi din sau ar putea proveni din ulei de palmier",
	he => "רכיבים שעשויים או מיוצרים משמן דקלים",
	nl => "ingrediënten die (mogelijk) palmolie bevatten",
	nl_be => "ingrediënten die (mogelijk) palmolie bevatten",
	de => "Zutaten, die (möglicherweise) aus Palmöl stammen",
},

codes_s => {
	en => "Code",
},

codes_p => {
	en => "Codes",
},

debug_s => {
	en => "debug",
},

debug_p => {
	en => "debug",
},

add_product => {

    ar => 'إضافة منتج', #ar-CHECK - Please check and remove this comment
	de => 'Ein Produkt hinzufügen',
    cs => 'Přidat produkt', #cs-CHECK - Please check and remove this comment
	es => 'Añadir un producto',
	en => 'Add a product',
	da => 'Tilføj et produkt',
    it => 'Aggiungi un prodotto', #it-CHECK - Please check and remove this comment
    fi => 'Lisää tuote', #fi-CHECK - Please check and remove this comment
	fr => 'Ajouter un produit',
	el => "Προσθέστε ένα προϊόν",
	he => 'הוספת מוצר',
    ja => '製品を追加', #ja-CHECK - Please check and remove this comment
    ko => '제품 추가', #ko-CHECK - Please check and remove this comment
	nl => "Product toevoegen",
	nl_be => "Product toevoegen",
	ru => 'Добавить продукт',
    pl => 'Dodaj produkt',
	pt => 'Adicionar um produto',
	ro => "Adăugare produs",
    th => 'เพิ่มสินค้า', #th-CHECK - Please check and remove this comment
    vi => 'Thêm một sản phẩm', #vi-CHECK - Please check and remove this comment
	zh => '添加商品',

},

barcode_number => {
	fr => 'Chiffres du code barre :',
	en => 'Barcode number:',
	el => "Κωδικός Barcode",
	da => 'Stregkode nummer:',
	es => 'Cifras del código de barras :',
	pt => 'Número do código de barras:',
	ro => "Numărul din codul de bare:",
	he => 'מספר ברקוד:',
	nl => "Barcodenummer:",
	nl_be => "Nummer van de barcode:",
	de => "Barcode-Nummer:",
	zh => "条形码数字",
},

barcode => {
	ar => 'الباركود', #ar-CHECK - Please check and remove this comment
	de => 'Barcode',
	cs => 'Barcode', #cs-CHECK - Please check and remove this comment
	es => 'Código de barras',
	en => 'Barcode',
	da => 'Stregkode',
	it => 'Barcode', #it-CHECK - Please check and remove this comment
	fi => 'Viivakoodi', #fi-CHECK - Please check and remove this comment
	fr => 'Code barre',
	el => "Barcode",
	he => 'ברקוד',
	ja => 'バーコード', #ja-CHECK - Please check and remove this comment
	ko => '바코드', #ko-CHECK - Please check and remove this comment
	nl => "Barcode",
	nl_be => "Barcode",
	ru => 'Штрих-код',
	pl => 'Barcode', #pl-CHECK - Please check and remove this comment
	pt => 'Código de barras',
	ro => "Codul de bare",
	th => 'บาร์โค้ด', #th-CHECK - Please check and remove this comment
	vi => 'Barcode', #vi-CHECK - Please check and remove this comment
	zh => "条形码",
},

or => {
	fr => 'ou :',
	en => 'or :',
	el => "ή",
	es => 'o :',
	pt => 'ou :',
	ro => "sau:",
	de => 'oder :',
	he => 'או:',
	nl => "of",
	nl_be => "of",
#	id => "",
},

no_barcode => {

    ar => 'المنتج دون الباركود', #ar-CHECK - Please check and remove this comment
	de => 'Produkt ohne Barcode',
	cs => "Produkt bez čárového kódu",
	es => 'Producto sin código de barras',
	en => 'Product without barcode',
    it => 'Prodotto senza codice a barre', #it-CHECK - Please check and remove this comment
	fi => "Tuote ilman viivakoodia",
	fr => 'Produit sans code barre',
	el => "Προϊόν χωρίς barcode",
	he => 'מוצר ללא ברקוד',
    ja => 'バーコードのない商品', #ja-CHECK - Please check and remove this comment
    ko => '바코드가없는 제품', #ko-CHECK - Please check and remove this comment
	nl => "Product zonder barcode",
	nl_be => "Product zonder barcode",
	ru => "Продукт без штрих-кода",
    pl => 'Towar bez kodów kreskowych', #pl-CHECK - Please check and remove this comment
	pt => 'Produto sem código de barras',
	ro => "Produs fără cod de bare",
    th => 'สินค้าโดยไม่มีบาร์โค้ด', #th-CHECK - Please check and remove this comment
    vi => 'Sản phẩm mà không cần mã vạch', #vi-CHECK - Please check and remove this comment
    zh => '产品无条码', #zh-CHECK - Please check and remove this comment

},

add => {
	ar => 'إضافة', #ar-CHECK - Please check and remove this comment
	de => 'Hinzufügen',
	cs => 'Přidat', #cs-CHECK - Please check and remove this comment
	es => 'Añadir',
	en => 'Add',
	it => 'Aggiungi',
	fi => 'Lisätä', #fi-CHECK - Please check and remove this comment
	fr => 'Ajouter',
	el => "Προσθέστε",
	he => 'הוספה',
	ja => '加えます', #ja-CHECK - Please check and remove this comment
	ko => '추가', #ko-CHECK - Please check and remove this comment
	nl => "Toevoegen",
	nl_be => "Toevoegen",
	ru => 'Добавить',
	pl => 'Dodać', #pl-CHECK - Please check and remove this comment
	pt => 'Adicionar',
	ro => "Adaugă",
	th => 'เพิ่ม', #th-CHECK - Please check and remove this comment
	vi => 'Thêm vào', #vi-CHECK - Please check and remove this comment
	zh => '添加',
	id => "Tambahkan",
},

product_image_with_barcode => {

    ar => 'صورة مع الباركود:', #ar-CHECK - Please check and remove this comment
	de => 'Produktfoto mit Barcode:',
    cs => 'Foto s čárovým kódem:', #cs-CHECK - Please check and remove this comment
	es => 'Imagen con código de barras:',
	en => 'Picture with barcode:',
    it => 'Foto con codice a barre:', #it-CHECK - Please check and remove this comment
    fi => 'Kuva viivakoodi:', #fi-CHECK - Please check and remove this comment
    fr => 'Photo avec code-barre:',
	el => "Εικόνα προϊόντος με barcode",
	he => 'תמונת המוצר עם ברקוד:',
    ja => 'バーコード付き写真：', #ja-CHECK - Please check and remove this comment
    ko => '바코드 사진 :', #ko-CHECK - Please check and remove this comment
	nl => "Foto van het product met barcode",
	nl_be => "Foto van het product met barcode",
    ru => 'Фото со штрих-кодом:', #ru-CHECK - Please check and remove this comment
    pl => 'Zdjęcie z kodem kreskowym:', #pl-CHECK - Please check and remove this comment
	pt => 'Imagem com o código de barras:',
	ro => "Imaginea produsului cu codul de bare:",
    th => 'ภาพถ่ายที่มีบาร์โค้ด:', #th-CHECK - Please check and remove this comment
    vi => 'Ảnh với mã vạch:', #vi-CHECK - Please check and remove this comment
    zh => '照片条码：', #zh-CHECK - Please check and remove this comment

},

send_image => {

    ar => 'إرسال صورة...', #ar-CHECK - Please check and remove this comment
	de => "Foto hochladen...",
    cs => 'Odeslat obrázek...', #cs-CHECK - Please check and remove this comment
	es => 'Enviar una imagen...',
	en => 'Send a picture...',
	it => 'Invia una photo...',
    fi => 'Lähetä kuva...', #fi-CHECK - Please check and remove this comment
	fr => 'Envoyer une image...',
	el => "Ανεβάστε μια εικόνα...",
	he => 'שליחת תמונה...',
    ja => '画像を送信...', #ja-CHECK - Please check and remove this comment
    ko => '사진을 보내기를...', #ko-CHECK - Please check and remove this comment
	nl => "Foto uploaden...",
	nl_be => "Een foto versturen...",
	ru => 'Отправить изображение...',
    pl => 'Wyślij zdjęcie...', #pl-CHECK - Please check and remove this comment
	pt => 'Enviar uma imagem...',
	ro => "Trimiteți o imagine...",
    th => 'ส่งภาพ...', #th-CHECK - Please check and remove this comment
    vi => 'Gửi một bức ảnh...', #vi-CHECK - Please check and remove this comment
    zh => '发送图片...', #zh-CHECK - Please check and remove this comment

},

sending_image => {
	fr => 'Image en cours d\'envoi',
	en => 'Sending image',
	el => "Τρέχουσα εικόνα σε αποστολή",
	es => 'Enviando la imagen',
	pt => 'A enviar a imagem',
	ro => "Imagine în curs de trimitere",
	he => 'התמונה נשלחת',
	nl => "Foto wordt geupload",
	nl_be => "De foto wordt verzonden",
	de => "Das Foto wird hochgeladen",
},

send_image_error => {
	fr => 'Erreur lors de l\'envoi',
	en => 'Upload error',
	el => "Σφάλμα κατά την αποστολή",
	es => 'Error al enviar',
	pt => 'Erro ao enviar a imagem',
	ro => "Eroare de transmisie",
	he => 'ההעלאה נכשלה',
	nl => "Fout bij het uploaden",
	nl_be => "Fout bij het verzenden",
	de => 'Beim Hochladen ist ein Fehler aufgetreten',
	ru => 'Ошибка загрузки',
},

edit_product => {

    ar => 'تعديل المنتج', #ar-CHECK - Please check and remove this comment
	de => 'Produkt bearbeiten',
    cs => 'Upravit produkt', #cs-CHECK - Please check and remove this comment
	es => 'Modifica un producto',
	en => 'Edit a product',
	it => 'Modifica un prodotto',
    fi => 'Muokkaa tuote', #fi-CHECK - Please check and remove this comment
	fr => 'Modifier un produit',
	el => "Τροποποιήστε ένα προϊόν",
	he => 'עריכת מוצר',
    ja => '製品を編集', #ja-CHECK - Please check and remove this comment
    ko => '제품을 편집', #ko-CHECK - Please check and remove this comment
	nl => 'Product aanpassen',
	nl_be => 'Product aanpassen',
    ru => 'Редактировать продукт', #ru-CHECK - Please check and remove this comment
    pl => 'Edycja produkt', #pl-CHECK - Please check and remove this comment
	pt => 'Editar um produto',
	ro => "Modificare produs",
    th => 'แก้ไขสินค้า', #th-CHECK - Please check and remove this comment
    vi => 'Chỉnh sửa sản phẩm', #vi-CHECK - Please check and remove this comment
    zh => '编辑产品', #zh-CHECK - Please check and remove this comment

},

edit_product_page => {

    ar => 'تحرير الصفحة', #ar-CHECK - Please check and remove this comment
	de => 'Produkt bearbeiten',
    cs => 'Upravit stránku', #cs-CHECK - Please check and remove this comment
	es => 'Modifica la página',
	en => 'Edit the page',
	it => 'Modifica la pagina',
    fi => 'Muokkaa sivua', #fi-CHECK - Please check and remove this comment
	fr => 'Modifier la fiche',
	el => "Τροποποιήστε το αρχείο",
	he => 'עריכת העמוד',
    ja => 'ページを編集します', #ja-CHECK - Please check and remove this comment
    ko => '페이지를 편집', #ko-CHECK - Please check and remove this comment
	nl => 'Productpagina aanpassen',
	nl_be => 'Productpagina aanpassen',
    ru => 'Редактировать страницу', #ru-CHECK - Please check and remove this comment
    pl => 'Edytuj stronę', #pl-CHECK - Please check and remove this comment
	pt => 'Editar a página',
	ro => "Modificare pagină",
    th => 'แก้ไขหน้า', #th-CHECK - Please check and remove this comment
    vi => 'Chỉnh sửa trang', #vi-CHECK - Please check and remove this comment
    zh => '编辑页面', #zh-CHECK - Please check and remove this comment

},

delete_product_page => {

    ar => 'حذف الصفحة', #ar-CHECK - Please check and remove this comment
	de => 'Formular löschen',
    cs => 'Smazat stránku', #cs-CHECK - Please check and remove this comment
	es => 'Elimina la página',
	en => 'Delete the page',
    it => 'Eliminare pagina', #it-CHECK - Please check and remove this comment
    fi => 'Poista sivu', #fi-CHECK - Please check and remove this comment
	fr => 'Supprimer la fiche',
	el => "Διαγράψτε το αρχείο",
	he => 'מחיקת העמוד',
    ja => 'ページを削除', #ja-CHECK - Please check and remove this comment
    ko => '페이지 삭제', #ko-CHECK - Please check and remove this comment
	nl => 'Pagina verwijderen',
	nl_be => 'Pagina verwijderen',
    ru => 'Удалить страницу', #ru-CHECK - Please check and remove this comment
    pl => 'Usuń strony', #pl-CHECK - Please check and remove this comment
	pt => 'Eliminar a página',
	ro => "Ștergere pagină",
    th => 'ลบหน้า', #th-CHECK - Please check and remove this comment
    vi => 'Xóa trang', #vi-CHECK - Please check and remove this comment
    zh => '删除页面', #zh-CHECK - Please check and remove this comment

},


delete_product => {
	fr => 'Supprimer un produit',
	en => 'Delete a product',
	el => "Διαγράψτε το προϊόν",
	es => 'Elimina un producto',
	pt => 'Eliminar um produto',
	ro => "Ștergere produs",
	he => 'מחיקת מוצר',
	nl => 'Product verwijderen',
	nl_be => 'Product verwijderen',
	de => 'Produkt löschen',
},

search => {

    ar => 'بحث', #ar-CHECK - Please check and remove this comment
	de => 'Suchen',
    cs => 'Vyhledávání', #cs-CHECK - Please check and remove this comment
	es => 'Buscar',
	en => 'Search',
    it => 'Ricerca', #it-CHECK - Please check and remove this comment
    fi => 'Haku', #fi-CHECK - Please check and remove this comment
	fr => 'Rechercher',
	el => "Αναζήτηση",
	he => 'חיפוש',
    ja => '検索', #ja-CHECK - Please check and remove this comment
    ko => '수색', #ko-CHECK - Please check and remove this comment
	nl => 'Zoeken',
	nl_be => 'Zoeken',
    ru => 'Поиск', #ru-CHECK - Please check and remove this comment
    pl => 'Poszukiwanie', #pl-CHECK - Please check and remove this comment
	pt => 'Procurar',
	ro => "Căutare",
    th => 'ค้นหา', #th-CHECK - Please check and remove this comment
    vi => 'Tìm kiếm', #vi-CHECK - Please check and remove this comment
    zh => '搜索', #zh-CHECK - Please check and remove this comment

},

search_title => {
	fr => 'Rechercher un produit, une marque, un ingrédient, un nutriment etc.',
	en => 'Search a product, brand, ingredient, nutriment etc.',
	el => "Αναζητήστε ένα προϊόν, συστατικό, θρεπτικό συστατικό κλπ",
	es => 'Busca un producto, marca, ingrediente, nutriente, etc.',
	pt => 'Procurar um produto, marca, ingrediente, nutriente, etc.',
	ro => "Căutați un produs, marcă, ingredient, nutrient etc.",
	he => 'חיפוש מוצר, מותג, רכיב, מרכיב תזונתי וכו׳',
	nl => 'Een product, een merk, een ingrediënt, een voedingsstof, etc. zoeken.',
	nl_be => 'Een product, een merk, een ingrediënt, een voedingsstof, etc. zoeken.',
	de => 'Produkt, Marke, Zutat, Nährstoff usw. suchen',
},

product_added => {

    ar => 'وأضاف المنتج على', #ar-CHECK - Please check and remove this comment
	de => 'Produkt hinzugefügt am',
    cs => 'Produkt přidán', #cs-CHECK - Please check and remove this comment
	es => 'Producto añadido el',
	en => 'Product added on',
    it => 'Prodotto aggiunto il', #it-CHECK - Please check and remove this comment
    fi => 'Tuote lisätty', #fi-CHECK - Please check and remove this comment
	fr => 'Produit ajouté le',
	el => "Προϊόν προστέθηκε το",
	he => 'המוצר נוסף ב־',
    # ja => '製品は2014年12月2日に追加されました', - Please check and remove this comment
    # ko => '제품 2014년 12월 2일에 추가' - Please check and remove this comment
	nl => 'Product toegevoegd op',
	nl_be => 'Product toegevoegd op',
    ru => 'Добавить новый продукт на', #ru-CHECK - Please check and remove this comment
    pl => 'Produkt został dodany dnia', #pl-CHECK - Please check and remove this comment
	pt => 'Produto adicionado a',
	ro => "Produs adăugat în",
    th => 'สินค้าเข้ามาเมื่อ', #th-CHECK - Please check and remove this comment
    vi => 'Sản phẩm thêm vào', #vi-CHECK - Please check and remove this comment
    zh => '产品附加值上', #zh-CHECK - Please check and remove this comment

},

by => {

    ar => 'بواسطة', #ar-CHECK - Please check and remove this comment
	de => 'von',
    cs => 'podle', #cs-CHECK - Please check and remove this comment
	es => 'por',
	en => 'by',
    it => 'da', #it-CHECK - Please check and remove this comment
    fi => 'mennessä', #fi-CHECK - Please check and remove this comment
	fr => 'par',
	el => "από/για",
	he => 'על־ידי',
    ja => 'によって', #ja-CHECK - Please check and remove this comment
    ko => '로', #ko-CHECK - Please check and remove this comment
	nl => "door",
	nl_be => "door",
    ru => 'по', #ru-CHECK - Please check and remove this comment
    pl => 'przez', #pl-CHECK - Please check and remove this comment
	pt => 'por',
	ro => "de către",
    th => 'โดย', #th-CHECK - Please check and remove this comment
    vi => 'qua', #vi-CHECK - Please check and remove this comment
    zh => '由', #zh-CHECK - Please check and remove this comment

},

missions => {
	fr => 'Missions',
	el => "Αποστολές",
	en => 'Missions',
	es => 'Misiones',
	pt => 'Missões',
	ro => "Misiuni",
	he => 'משימות',
	nl => "Missies",
	nl_be => "Missies",
	de => 'Missionen',
},


mission_ => {
	fr => 'Mission : ',
	en => 'Mission: ',
	el => "Αποστολή:",
	es => 'Misión: ',
	pt => 'Missão: ',
	ro => "Misiune: ",
	he => 'משימה: ',
	nl => "Missie: ",
	nl_be => "Missie: ",
	de => 'Mission:',
},

completed_n_missions => {
	fr => 'a accompli %d missions :',
	en => 'completed %d missions:',
	el => "ολοκληρώθηκαν %d αποστολές:",
	es => 'completadas %d misiones:',
	pt => 'completou %d missões:',
	ro => "a terminat %d misiuni:",
	he => 'הושלמו %d משימות:',
	nl => "%s missies voltooid",
	de => 'hat %d Missionen erfüllt:',
},

mission_goal => {
	fr => 'Objectif :',
	en => 'Goal:',
	el => "Στόχος:",
	es => 'Objetivo:',
	pt => 'Objetivo:',
	ro => "Obiectiv:",
	he => 'יעד:',
	nl => "Doel:",
	nl_be => "Doel:",
	de => 'Ziel:',
},

mission_accomplished_by => {
	fr => 'Cette mission a été accomplie par :',
	en => 'This mission has been completed by:',
	el => "Αυτή η αποστολή ολοκληρώθηκε από:",
	es => 'Esta misión ha sido completada por:',
	pt => 'Esta missão foi completa por:',
	ro => "Această misiune a fost terminată de către:",
	he => 'משימה זאת הושלמה על־ידי:',
	nl => 'Deze missie werd voltooid door:',
	nl_be => 'Deze missie werd voltooid door:',
	de => 'Diese Mission wurde erfüllt von:',
},

mission_accomplished_by_n => {
	fr => 'Accomplie par %d personnes.',
	en => 'Completed by %d persons.',
	el => "Ολοκληρώθηκαν από %d άτομα.",
	es => 'Completada por %d personas.',
	pt => 'Completa por %d pessoas.',
	ro => "Terminată de către %d persoane.",
	he => 'הושלמה על־ידי %d משתמשים.',
	nl => 'Voltooid door %d personen',
	nl_be => 'Voltooid door %d personen',
	de => 'wurde von %d Personen erfüllt.',
},

mission_accomplished_by_nobody => {
	fr => 'Soyez le premier à accomplir cette mission!',
	en => 'Be the first to complete this mission!',
	da => 'Vær den første til at fuldføre denne mission!',
	el => "Γίνετε ο πρώτος που θα ολοκληρώσει αυτή την αποστολή!",
	es => '¡Sé el primero en cumplir esta misión!',
	pt => 'Seja o primeiro a completar esta missão!',
	ro => "Fii primul care termină această misiune!",
	he => 'משימה זו טרם הושלמה, קדימה, קטן עליך!',
	nl => 'Wees de eerste om deze missie te voltooien!',
	nl_be => 'Wees de eerste om deze missie te voltooien!',
	de => 'Sei der/die Erste, diese Mission zu erfüllen!',
},

all_missions => {
	fr => 'Toutes les missions',
	en => 'All missions',
	el => "Όλες οι αποστολές",
	es => 'Todas las misiones',
	pt => 'Todas as missões',
	ro => "Toate misiunile",
	he => 'כל המשימות',
	nl => 'Alle missies',
	nl_be => 'Alle missies',
	de => 'Alle Missionen',
	da => 'Alle missioner',
},

salt_equivalent => {
	fr => 'équivalent sel',
	en => 'salt equivalent',
	el => "Ισοδύναμο σε αλάτι",
	es => 'equivalente en sal',
	pt => 'equivalente em sal',
	ro => "echivalentul de sare",
	he => 'תחליף מלח',
	nl => 'equivalent zout',
	nl_be => 'equivalent zout',
	de => 'Salz Äquivalent',
},

additives_3 => {
	fr => 'Additif alimentaire interdit en Europe. A éviter absolument.',
	el => "Πρόσθετο τροφίμων απαγορευμένο στην Ευρώπη. Να αποφευχθεί απολύτως. ",
	es => 'Aditivo alimentario prohibido en Europa. Evítalo completamente.',
	pt => 'Aditivo alimentar proibido na Europa. A evitar completamente.',
	ro => "Aditiv alimentar interzis în Europa. De evitat complet.",
	nl => 'Voedingsadditief verboden in Europa. Absoluut te vermijden.',
	nl_be => 'Voedingsadditief verboden in Europa. Absoluut te vermijden.',
	de => 'In Europa verbotener Lebensmittelzusatzstoff. Absolut vermeiden.',
},

additives_2 => {
	fr => 'Additif alimentaire à risque. A éviter.',
	el => "Πρόσθετο τροφίμων όχι απολύτως ασφαλές. Να αποφευχθεί. ",
	es => 'Aditivo alimentario con riesgo. A evitar.',
	ro => "Aditiv alimentar riscant. De evitat.",
	pt => 'Aditivo alimentar com riscos. A evitar.',
	nl => 'Risicovol voedingsadditief. Te vermijden.',
	nl_be => 'Risicovol voedingsadditief. Te vermijden.',
	de => 'Lebensmittelzusatzstoff mit Risiko. Vermeiden.',
},

additives_1 => {
	fr => 'Additif alimentaire potentiellement à risque. A limiter.',
	el => "Πρόσθετο τροφίμων πιθανώς όχι απολύτως ασφαλές. Να περιοριστεί η χρήση του. ",
	es => 'Aditivo alimentario con riesgo potencial. A limitar.',
	ro => "Aditiv alimentar potențial riscant. De limitat.",
	pt => 'Aditivo alimentar potencialmente com risco . A limitar.',
	nl => 'Mogelijk risicovol voedingsadditief. Beperken.',
	nl_be => 'Mogelijk risicovol voedingsadditief. Beperken.',
	de => 'Lebensmittelzusatzstoff möglicherweise mit Risiko. Vermeiden.',
},

licence_accept => {
	fr => 'En ajoutant des informations et/ou des photographies, vous acceptez de placer irrévocablement votre contribution sous licence <a href="http://opendatacommons.org/licenses/dbcl/1.0/">Database Contents Licence 1.0</a>
pour les informations et sous licence <a href="http://creativecommons.org/licenses/by-sa/3.0/deed.fr">Creative Commons Paternité - Partage des conditions initiales à l\'identique 3.0</a> pour les photos.
Vous acceptez d\'être crédité par les ré-utilisateurs par un lien vers le produit auquel vous contribuez.',
	en => 'By adding information, data and/or images, you accept to place irrevocably your contribution under the <a href="http://opendatacommons.org/licenses/dbcl/1.0/">Database Contents Licence 1.0</a> licence
for information and data, and under the <a href="http://creativecommons.org/licenses/by-sa/3.0/deed.en">Creative Commons Attribution - ShareAlike 3.0</a> licence for images.
You accept to be credited by re-users by a link to the product your are contributing to.',
el => 'Προσθέτοντας πληροφορία, δεδομενα ή/και φωτογραφίες, αποδέχεστε αμετάκλητα ότι αποδέχεστε τη <a href="http://opendatacommons.org/licenses/dbcl/1.0/">Database Contents Licence 1.0</a> άδεια για πληροφορία και δεδομένα, και υπό the <a href="http://creativecommons.org/licenses/by-sa/3.0/deed.en">Creative Commons Attribution - ShareAlike 3.0</a> άδεια για τις εικόνες.
Αποδέχεστε ότι το περιεχόμενο αποδίδεται σε εσάς σε περίπτωση επαναχρησιμοποίησης των δεδομένων μέσω σύνδεσης με το προϊόν με το οποίο έχετε συμβάλλει.',
	es => 'Al adjuntar información, datos y/o imágenes, acepta que su contribución sea añadida de forma irrevocable bajo la licencia <a href="http://opendatacommons.org/licenses/dbcl/1.0/">Database Contents Licence 1.0</a>
para la información y datos, y bajo la licencia<a href="http://creativecommons.org/licenses/by-sa/3.0/deed.en">Creative Commons Attribution - ShareAlike 3.0</a> para las imágenes.
También acepta recibir el reconocimiento por la reutilización de los datos mediante un enlace al producto al que ha contribuído.',
	pt_pt => 'Ao adicionar informações e/ou imagens, você aceita irrevogavelmente a sua contribuição sob a licença <a href="http://opendatacommons.org/licenses/dbcl/1.0/">Database Contents Licence 1.0</a>
pelas informações, e sob a licença <a href="http://creativecommons.org/licenses/by-sa/3.0/deed.en">Creative Commons Attribution - ShareAlike 3.0</a> para as imagens.
Você aceita ser creditado por reutilizadores por um link para o produto que está a contribuir.',
	ro => 'Adăugând informații, date și/sau imagini, acceptați să vă faceți contribuția disponibilă sub licența pentru informație și date <a href="http://opendatacommons.org/licenses/dbcl/1.0/">Database Contents Licence 1.0</a>, și sub licența pentru imagini <a href="http://creativecommons.org/licenses/by-sa/3.0/deed.en">Creative Commons Attribution - ShareAlike 3.0</a>.
Acceptați să fiți creditat pentru re-utilizări cu un link către produsul la care contribuiți.',
	nl => 'Door informatie, data en/of beelden toe te voegen, aanvaard je dat je bijdrage onherroeplijk geplaatst wordt onder de <a href="http://opendatacommons.org/licenses/dbcl/1.0/">Database Contents Licence 1.0</a> licentie
voor informatie en data, en onder de <a href="http://creativecommons.org/licenses/by-sa/3.0/deed.en">Creative Commons Attribution - ShareAlike 3.0</a> licentie voor beelden.
Je aanvaard ook dat je gecrediteerd kan worden door hergebruikers via een link naar het product waar je tot bijgedragen hebt.',
	nl_be => 'Door informatie, data en/of beelden toe te voegen, aanvaardt u dat uw bijdrage onherroeplijk geplaatst wordt onder de <a href="http://opendatacommons.org/licenses/dbcl/1.0/">Database Contents Licence 1.0</a> licentie
voor informatie en data, en onder de <a href="http://creativecommons.org/licenses/by-sa/3.0/deed.en">Creative Commons Attribution - ShareAlike 3.0</a> licentie voor beelden.
U aanvaardt ook dat u gecrediteerd kan worden door hergebruikers via een link naar het product waar u tot bijgedragen hebt.',
	de => 'Durch das Eingeben von Daten und Hinzufügen von Fotos erklären Sie sich unwiderruflich damit einverstanden, Ihre Beteiligung für die Informationen unter der Lizenz <a href="http://opendatacommons.org/licenses/dbcl/1.0/" hreflang="en">Database Contents Licence 1.0</a>
 beizutragen und für die Fotos unter den Lizenz <a href="http://creativecommons.org/licenses/by-sa/3.0/deed.de">Creative Commons Attribution - ShareAlike 3.0</a> zu veröffentlichen.
Sie stimmen damit zu, von anderen Projekten, dei diese Daten nutzen, mit einem Link zu den von Ihnen bearbeiteten Produkten kreditiert zu werden.',
},

tag_belongs_to => {
	fr => 'Fait partie de :',
	en => 'Belongs to:',
	el => 'Ανήκει σε :',
	es => 'Pertenece a:',
	pt => 'Pertence a:',
	ro => "Aparține de:",
	he => 'שייך ל־:',
	nl => 'Behoort tot:',
	nl_be => 'Behoort tot:',
	de => 'Gehört:',
},

tag_contains => {
	fr => 'Contient :',
	en => 'Contains:',
	el => 'Περιέχει :',
	es => 'Contiene:',
	pt => 'Contém:',
	ro => "Conține",
	he => 'מכיל:',
	nl => 'Bevat:',
	nl_be => 'Bevat:',
	de => "Enthält:",
},

newsletter_description => {
	fr => "S'inscrire à la lettre d'information (2 e-mails par mois maximum)",
	en => "Subscribe to the newsletter (2 emails per month maximum)",
	el => 'Εγγραφείτε στο newsletter (2 emails το μήνα maximum) ',
	es => "Suscribirse al boletín informativo (2 correos electrónicos al mes como mucho)",
	pt => "Subscreva ao boletim de notícias (2 e-mails no máximo por mês)",
	pt_pt => "Subscreva o boletim de notícias (2 e-mails no máximo por mês)",
	ro => "Abonare la buletinul informativ (maxim 2 email-uri pe lună)",
	he => "הרשמה לרשימת הדיוור (2 הודעות דוא״ל בחודש לכל היותר, באנגלית)",
	nl => 'Inschrijven voor de nieuwsbrief (maximum 2 e-mails per maand)',
	nl_be => 'Inschrijven voor de nieuwsbrief (maximum 2 e-mails per maand)',
	de => "Newsletter abonnieren (maximum 2 E-Mails pro Monat)",
},

search_products => {
	fr => "Recherche de produits",
	en => "Products search",
	el => "Αναζήτηση προϊόντων",
	es => "Búsqueda de productos",
	pt => "Procura de produtos",
	ro => "Căutare produse",
	he => "חיפוש מוצרים",
	nl => 'Producten zoeken',
	nl_be => 'Producten zoeken',
	de => "Produkt-Suche",
},

search_terms => {
	fr => "Termes de recherche",
	en => "Search terms",
	el => 'Αναζήτηση όρων',
	es => "Palabras a buscar",
	pt => "Termos de pesquisa",
	ro => "Termeni de căutare",
	he => "מילות חיפוש",
	nl => 'Zoektermen',
	nl_be => 'Zoektermen',
	de => "Suchkriterien",
},

search_terms_note => {
	fr => "Recherche les mots présents dans le nom du produit, le nom générique, les marques, catégories, origines et labels",
	en => "Search for words present in the product name, generic name, brands, categories, origins and labels",
	el => 'Αναζητήστε λέξεις στο όνομα του προϊόντος, στη μάρκα, στις κατηγορίες, στις ετικέτες και στην προέλευση',
	es => 	"Busca las palabras presentes en el nombre del producto, la denominación general, las marcas, las categorías, los orígenes y las etiquetas",
	pt_pt => "Procurar os termos no nome do produto, nome genérico, marcas, categorias, origens e etiquetas",
	ro => "Căutați după cuvinte prezente în numele produsului, numele generic, mărci, categorii, origini și etichete",
	he=> "חיפוש אחר מילים מתוך שם המוצר, שמו הכללי, מותגים, קטגוריות, מקורות ותוויות",
	nl => 'Zoek naar woorden in de naam van het product, de algemene benaming, de merken, de categorieën, de herkomst en de labels',
	nl_be => 'Zoek naar woorden in de naam van het product, de algemene benaming, de merken, de categorieën, de herkomst en de labels',
	de => "Die Suche erfolgt durch die Anpassung mit Produktnamen, allgemeinem Namen, Marken, Kategorien, Herkunft und Labels",
},

search_tag => {
	fr => "choisir un critère...",
	en => "choose a criterion...",
	el => 'επιλέξτε ένα κριτήριο...',
	es => "escoge un criterio...",
	pt => "escolhe um critério...",
	ro => "alegeți un criteriu...",
	he => "בחירת קריטריון...",
	nl => "kies een criterium...",
	nl_be => "kies een criterium...",
	de => "Kriterium auswählen...",
	ru => 'выбор критерия...',
},

search_nutriment => {
	fr => "choisir un nutriment...",
	en => "choose a nutriment...",
	el => 'επιλέξτε ένα θρεπτικό συστατικό...',
	es => "escoge un nutriente...",
	pt => "escolhe um nutriente...",
	ro => "alegeți un nutrient...",
	he => "בחירת  מרכיב תזונתי...",
	nl => "kies een voedingsstof",
	nl_be => "kies een voedingsstof",
	de => "Nährstoff auswählen...",
},

search_tags => {
	fr => "Critères",
	en => "Criteria",
	el => 'Κριτήρια',
	es => "Criterios",
	pt => "Critérios",
	ro => "Criteriu",
	he => "קריטריונים",
	nl => "Criteria",
	nl_be => "Criteria",
	de => "Kriterien",
},

search_nutriments => {
	fr => "Nutriments",
	en => "Nutriments",
	el => 'Θρεπτικά συστατικά',
	es => "Nutrientes",
	pt => "Nutrientes",
	ro => "Nutrienți",
	he => "מרכיבים תזונתיים",
	nl => "Voedingsstoffen",
	nl_be => "Voedingsstoffen",
	de => "Nährstoffe",
},

search_contains => {
	fr => "contient",
	en => "contains",
	el => 'περιέχει',
	es => "contiene",
	pt => "contém",
	ro => "conține",
	he => "מכיל",
	nl => "bevat",
	nl_be => "bevat",
	de => "enthält",
},
search_does_not_contain => {
	fr => "ne contient pas",
	en => "does not contain",
	el => 'δεν περιέχει',
	es => "no contiene",
	pt => "não contém",
	ro => "nu conține",
	he => "אינו מכיל",
	nl => "bevat geen",
	nl_be => "bevat geen",
	de => "enthält nicht",
},
search_value => {
	fr => "valeur",
	en => "value",
	nl => "waarde",
	nl_be => "waarde",
},
search_or => {
	fr => "ou",
	en => "or",
	el => 'ή',
	es => "o",
	pt => "ou",
	ro => "sau",
	he => "או",
	nl => "of",
	nl_be => "of",
	de => "oder",
},
search_page_size => {
	fr => "Résultats par page",
	en => "Results per page",
	el => 'Αριθμός αποτελεσμάτων ανά σελίδα',
	es => "Resultados por página",
	pt => "Resultados por página",
	ro => "Rezultate per pagină",
	he => "מספר התוצאות לפי עמוד",
	nl => "Resultaten per pagina",
	nl_be => "Resultaten per pagina",
	de => "Ergebnisse pro Seite",
},
sort_by => {
	fr => "Trier par",
	en => "Sort by",
	el => 'Ταξινομήστε ανά ',
	es => "Ordenar por",
	pt => "Ordenar por",
	ro => "Ordonează după",
	he => "סידור לפי",
	nl => "Ordenen volgens",
	nl_be => "Ordenen volgens",
	de => "Sortieren nach",
},
sort_popularity => {
	fr => "Popularité",
	en => "Popularity",
	el => 'Δημοφιλία',
	es => "Popularidad",
	pt => "Popularidade",
	ro => "Popularitate",
	nl => "Populariteit",
	nl_be => "Populariteit",
	de => "Popularität",
},
sort_product_name => {
	fr => "Nom du produit",
	en => "Product name",
	el => 'Όνομα προϊόντος',
	es => "Nombre del producto",
	pt => "Nome do produto",
	ro => "Numele produsului",
	he => "שם המוצר",
	nl => "Productnaam",
	nl_be => "Productnaam",
	de => "Produktname",
},
sort_created_t => {
	fr => "Date d'ajout",
	en => "Add date",
    el => 'Ημερομηνία προσθήκης',
	es => "Fecha de creación",
	pt => "Data de criação",
	ro => "Data adăugării",
	he => "הוספת תאריך",
	nl => "Toevoegdatum",
	nl_be => "Datum van toevoeging",
	de => "Zusatzdatum",
	ru => 'Добавить дату',
},
sort_modified_t => {
	fr => "Date de modification",
	en => "Edit date",
	el => 'Ημερομηνία τροποποίησης',
	es => "Fecha de modificación",
	pt => "Data de modificação",
	ro => "Data modificării",
	he => "עריכת התאריך",
	nl => "Aanpassingsdatum",
	nl_be => "Datum van aanpassing",
	de => "Verarbeitungsdatum",
},

search_button => {
	fr => "Rechercher",
	en => "Search",
	el => 'Αναζήτηση',
	de => "Suchen",
	es => "Buscar",
	pt => "Procurar",
	ro => "Căutare",
	he => "חיפוש",
	nl => "Zoeken",
	nl_be => "Zoeken",
},

search_edit => {
	fr => "Modifier les critères de recherche",
	en => "Change search criteria",
	el => 'Αλλάξτε κριτήρια αναζήτησης',
	es => "Cambiar los criterios de búsqueda",
	pt => "Modificar os critérios da pesquisa",
	ro => "Schimbă criteriile de căutare",
	he => "החלפת קריטריוני החיפוש",
	nl => "Wijzig de zoekcriteria",
	nl_be => "Wijzig de zoekcriteria",
	de => "Suchkriterien bearbeiten",
	ru => 'Изменить критерии поиска',
},

search_link => {
	fr => "Lien permanent vers ces résultats, partageable par e-mail et les réseaux sociaux",
	en => "Permanent link to these results, shareable by e-mail and on social networks",
	el => 'Μόνιμος σύνδεσμος σε αυτά τα αποτελέσματα, μπορείτε να τον μοιραστείτε μέσω e-mail και στα κοινωνικά δίκτυα',
	es => "Enlace permanente a estos resultados, para poderse compartir a través del correo electrónico y redes sociales",
	ro => "Link permanent la aceste rezultate, transmisibil prin e-mail și pe rețele sociale",
	he => "קישור ישיר לתוצאות אלו, ניתן להעברה בדוא״ל וברשתות חברתיות",
	nl => "Permanente link naar deze resultaten, deelbaar via e-mail of de sociale media",
	nl_be => "Permanente link naar deze resultaten, deelbaar via e-mail of de sociale media",
	de => "Zitierfähiger Permanentlink zu diesen Suchergebnissen, kann über E-Mail und in sozialen Netzwerken geteilt werden",
},

search_graph_link => {
	fr => "Lien permanent vers ce graphique, partageable par e-mail et les réseaux sociaux",
	en => "Permanent link to this graph, shareable by e-mail and on social networks",
	el => 'Μόνιμος σύνδεσμος σε αυτo τo γράφημα, μπορείτε να τον μοιραστείτε μέσω e-mail και στα κοινωνικά δίκτυα',
	es => "Enlace permanente a este gráfico, para poderse compartir a través del correo electrónico y redes sociales",
	pt => "Link permanente para este gráfico, para poder partilhar através do e-mail ou das redes sociais",
	ro => "Link permanent la acest grafic, transmisibil prin e-mail și pe rețele sociale",
	he => "קישור ישיר לתוצאות אלו, ניתן להעברה בדוא״ל וברשתות חברתיות",
	nl => "Permanente link naar deze grafiek, deelbaar via e-mail of de sociale media",
	nl_be => "Permanente link naar deze grafiek, deelbaar via e-mail of de sociale media",
	de => "Zitierfähiger Permanentlink zu dieser Grafik, kann über E-Mail und in sozialen Netzwerken geteilt werden",
},

search_graph_title => {
	fr => "Visualiser les résultats sous forme de graphique",
	en => "Display results on a graph",
	el => 'Δείξε αποτελέσματα με γράφημα',
	es => "Ver los resultados de forma gráfica",
	pt => "Ver os resultados sob a forma de um gráfico",
	ro => "Afișarea rezultatelor pe un grafic",
	he => "הצגת תוצאות בתרשים",
	nl => "Geef de resultaten weer in een grafiek",
	nl_be => "Geef de resultaten weer in een grafiek",
	de => "Ergebnisse in einer Grafik anzeigen",
},

search_graph_2_axis => {
	fr => "Graphique sur 2 axes",
	en => "Scatter plot",
	el => 'Γράφημα με 2 άξονες',
	es => "Gráfico en 2 ejes",
	pt => "Gráfico de dispersão",
	ro => "Grafic pe 2 axe",
	he => "פיזור התוואי",
	nl => "Grafiek met 2 assen",
	nl_be => "Grafiek met 2 assen",
	de => "Grafik mit 2 Achsen",
},

search_graph_note => {
	fr => "Le graphique ne montrera que les produits pour lesquels les valeurs representées sont connues.",
	en => "The graph will show only products for which displayed values are known.",
	el => 'Το γράφημα αυτό θα δείξει μόνο προϊόντα για τα οποία οι αντιπροσωπευόμενες τιμές είναι γνωστές ',
	es => "El gráfico mostrará solamente los productos para los cuales los valores representados son conocidos.",
	pt_pt => "O gráfico mostrará apenas os produtos cujos valores representados são conhecidos.",
	ro => "Graficul va arăta numai produse pentru care valorile afișate sunt cunoscute.",
	he => "התרשים יציג אך ורק מוצרים שהערכים שלהם ידועים.",
	nl => "De grafiek geeft enkel producten weer waarvan de afgebeelde waarden gekend zijn.",
	nl_be => "De grafiek geeft enkel producten weer waarvan de afgebeelde waarden gekend zijn.",
	de => "Die Grafik zeigt nur die Produkte an, wofür gezeichnete Werte bekannt sind.",
},

graph_title => {
	fr => "Titre du graphique",
	en => "Graph title",
	el => 'Τίτλος γραφήματος ',
	es => "Título del gráfico",
	pt => "Título de gráfico",
	ro => "Titlul graficului",
	he => "כותרת התרשים",
	nl => "Titel van de grafiek",
	nl_be => "Titel van de grafiek",
	de => "Titel der Grafik",
},

graph_count => {
	fr => "%d produits correspondent aux critères de recherche, dont %i produits avec des valeurs définies pour les axes du graphique.",
	en => "%d products match the search criterias, of which %i products have defined values for the graph's axis.",
	el => "%d των προϊόντων πληρούν τα κριτήρια αναζήτησης, από τα οποία %i των προϊόντων έχουν καθορισμένες τιμές για τους άξονες του γραφήματος.",
	es => "%d productos coinciden con los criterios de búsqueda, de los cuales %i productos tienen valores definidos en los ejes del gráfico.",
	pt => "%d produtos coincidem com os critérios de pesquisa, dos quais %i produtos têm valores definidos para os eixos do gráfico.",
	ro => "%d produse se potrivesc criteriilor de căutare, din care %i produse au valori definite pentru axele graficului",
	he => "%d מוצרים תואמים את קריטריוני החיפוש, מתוכם ל־%i מוצרים יש ערכים מוגדרים עבור צירי התרשים.",
	nl => "%d producten stemmen overeen met uw zoekcriteria, waarvan %i producten gedefinieerde waarden hebben voor de assen van de grafiek.",
	nl_be => "%d producten stemmen overeen met uw zoekcriteria, waarvan %i producten gedefinieerde waarden hebben voor de assen van de grafiek.",
	de => "%d Produkte entsprechen Ihren Suchkriterien, davon %i Produkte, für welche Werte für die Diagramm-Achsen definiert wurden.",
},

data_source => {
	fr => "Source des données",
	en => "Data source",
	el => 'Πηγή δεδομένων ',
	es => "Origen de los datos",
	pt => "Origem dos dados",
	ro => "Sursa de date",
	nl => "Gegevensbron",
	nl_be => "Bron van de gegevens",
	de => "Datenquelle",
},

search_map_link => {
	fr => "Lien permanent vers cette carte, partageable par e-mail et les réseaux sociaux",
	en => "Permanent link to this map, shareable by e-mail and on social networks",
	el => 'Μόνιμος σύνδεσμος σε αυτo το χάρτη, μπορείτε να τον μοιραστείτε μέσω e-mail και στα κοινωνικά δίκτυα',
	es => "Enlace permanente a esta mapa, para poderse compartir a través del correo electrónico y redes sociales",
	pt => "Link permanente para este mapa, para poder partilhar através do e-mail ou das redes sociais",
	ro => "Link permanent la această hartă, transmisibil prin e-mail și pe rețele sociale",
	he => "קישור קבוע למפה זו, ניתן לשתף בדוא״ל וברשתות חברתיות",
	nl => "Permanente link naar deze kaart, deelbaar via e-mail of de sociale media",
	nl_be => "Permanente link naar deze kaart, deelbaar via e-mail of de sociale media",
	de => "Zitierfähiger Permanentlink zu dieser Karte, kann über E-Mail und in sozialen Netzwerken geteilt werden",
},

search_map_title => {
	fr => "Visualiser les résultats sous forme de carte",
	en => "Display results on a map",
	el => 'Δείξε αποτελέσματα πάνω σε χάρτη',
	es => "Ver los resultados sobre una mapa",
	pt => "Ver os resultados num mapa",
	ro => "Afișare rezultate pe o hartă",
	he => "הצגת תוצאות על מפה",
	nl => "Geef de resultaten weer op de kaart",
	nl_be => "Geef de resultaten weer op de kaart",
	de => "Ergebnisse im Kartenformat anzeigen",
},

search_map_note => {
	fr => "La carte ne montrera que les produits pour lesquels le lieu de fabrication ou d'emballage est connu.",
	en => "The map will show only products for which the production place is known.",
	el => 'Ο χάρτης θα δείξει μονο προϊόντα για τα οποία ο τόπος παραγωγής είναι γνωστός.',
	es => "El mapa mostrará solamente los productos para los cuales se conoce el lugar de fabricación o de envasado.",
	pt => "O mapa mostrará apenas os produtos cujos locais de produção ou embalamento são conhecidos.",
	ro => "Harta va arăta numai produsele pentru care locul de producție este cunoscut.",
	he => "המפה תציג אך ורק מוצרים שמיקום הייצור שלהם ידוע.",
	nl => "De kaart toont enkel de producten waarvan de productielocatie bekend is.",
	nl_be => "De kaart toont enkel de producten waarvan de productielocatie gekend is.",
	de => "Die Karte zeigt nur die Produkte an, wofür der Herstellungs- oder Verpackungsort bekannt ist",
},

map_title => {
	fr => "Titre de la carte",
	en => "Map title",
	el => 'Τίτλος χάρτη',
	es => "Título del mapa",
	pt => "Título do mapa",
	ro => "Titlul hărții",
	he => "כותרת המפה",
	nl => "Titel van de kaart",
	nl_be => "Titel van de kaart",
	de => "Titel der karte",
},

map_count => {
	fr => "%d produits correspondent aux critères de recherche, dont %i produits pour lesquels le lieu de fabrication ou d'emballage est connu.",
	en => "%d products match the search criterias, of which %i products have a known production place.",
	el => "%d των προϊόντων πληρούν τα κριτήρια αναζήτησης, από τα οποία %i των προϊόντων έχουν γνωστό τόπο παραγωγής.",
	es => "%d productos coinciden con los criterios de búsqueda, de los cuales %i productos tienen valores definidos.",
	pt => "%d produtos coincidem com os critérios de pesquisa, dos quais %i produtos têm um local de fabrico ou embalamento conhecido.",
	ro => "%d produse corespund criteriilor de căutare, din care %i produse au un loc de producție cunoscut.",
	he => "%d מוצרים תואמים לקריטריוני החיפוש, מתוכם ל־%i מהמוצרים מקום הייצור ידוע.",
	nl => "%d producten stemmen overeen met uw zoekcriteria, waaronder %i producten waarvan de productielocatie of de locatie van verpakking gekend is.",
	nl_be => "%d producten stemmen overeen met uw zoekcriteria, waaronder %i producten waarvan de productielocatie of de locatie van verpakking gekend is.",
	de => "%d Produkte entsprechen Ihren Suchkriterien, davon %i Produkte, wofür der Herstellungs- oder Verpackungsort bekannt ist.",
},


search_series_default => {

    ar => 'غيرها من المنتجات', #ar-CHECK - Please check and remove this comment
	de => "Andere Produkte",
    cs => 'Další produkty', #cs-CHECK - Please check and remove this comment
	es => 'Otros productos',
	en => 'Other products',
    it => 'Altri prodotti', #it-CHECK - Please check and remove this comment
    fi => 'Muut tuotteet', #fi-CHECK - Please check and remove this comment
	fr => 'Autres produits',
	el => 'Άλλα προϊόντα',
	he => 'מוצרים אחרים',
    ja => 'その他の製品', #ja-CHECK - Please check and remove this comment
    ko => '기타 제품', #ko-CHECK - Please check and remove this comment
	nl => "Andere producten",
	nl_be => "Andere producten",
    ru => 'Другие продукты', #ru-CHECK - Please check and remove this comment
    pl => 'Inne produkty', #pl-CHECK - Please check and remove this comment
	pt => 'Outros produtos',
	ro => "Alte produse",
    th => 'สินค้าอื่น ๆ', #th-CHECK - Please check and remove this comment
    vi => 'Các sản phẩm khác', #vi-CHECK - Please check and remove this comment
    zh => '其他产品', #zh-CHECK - Please check and remove this comment

},

search_series => {
	fr => 'Utiliser une couleur différente pour les produits :',
	en => 'Use a different color for the following products:',
	el => 'Χρησιμοποίησε διαφορετικό χρώμα για τα ακόλουθα προϊόντα:',
	es => 'Utiliza un color diferente para los siguientes productos:',
	pt => 'Utilizar uma cor diferente para os seguintes produtos:',
	ro => "Folosește o culoare diferită pentru următoarele produse:",
	he => 'שימוש בצבע שונה עבור המוצרים הבאים:',
	nl => "Gebruik een andere kleur voor de volgende producten:",
	nl_be => "Gebruik een andere kleur voor de volgende producten:",
	de => "Unterschiedliche Farben für die folgenden Produkte verwenden:",
},

search_series_nutrition_grades => {
	fr => "Utiliser les couleurs des notes nutritionnelles",
	en => "Use nutrition grades colors",
	nl => "Gebruik voedingsgraadkleuren",
	nl_be => "Gebruik voedingsgraadkleuren",
},

search_series_organic => {
	fr => 'Bio',
	en => 'Organic',
	el => 'Βιολογικό/Οργανικό',
	es => 'Ecológico',
	pt => 'Orgânico',
	ro => "Bio",
	he => 'אורגני',
	nl => "Bio",
	nl_be => "Bio",
	de => "Bio",
},

search_series_organic_label => {
	fr => 'bio',
	en => 'organic',
	el => 'Βιολογικό/Οργανικό',
	es => 'Ecológico',
	pt => 'orgânico',
	ro => "bio",
	nl => "bio",
	nl_be => "bio",
	de => "Bio",
},

search_series_fairtrade => {

    ar => 'معرض تجاري', #ar-CHECK - Please check and remove this comment
	de => "Fair Trade",
    cs => 'Férový Obchod', #cs-CHECK - Please check and remove this comment
	es => 'Comercio justo',
	en => 'Fair trade',
    it => 'Commercio Equo', #it-CHECK - Please check and remove this comment
    fi => 'Reilu kauppa', #fi-CHECK - Please check and remove this comment
	fr => 'Commerce équitable',
	el => 'Δικαίου εμπορίου',
	he => 'סחר הוגן',
    ja => '公正取引', #ja-CHECK - Please check and remove this comment
    ko => '공정 거래', #ko-CHECK - Please check and remove this comment
	nl => "Fair trade",
	nl_be => "Fair trade",
    ru => 'Честная Сделка', #ru-CHECK - Please check and remove this comment
    pl => 'Targi', #pl-CHECK - Please check and remove this comment
	pt => 'Comércio justo',
	ro => "Comerț echitabil",
    th => 'งานออกร้าน', #th-CHECK - Please check and remove this comment
    vi => 'Trao Đổi Công Bằng', #vi-CHECK - Please check and remove this comment
    zh => '公平贸易', #zh-CHECK - Please check and remove this comment

},

search_series_fairtrade_label => {
	fr => 'commerce-equitable',
	en => 'fair-trade',
	el => 'Δικαίου-εμπορίου',
	es => 'comercio-justo',
	pt => 'comércio-justo',
	ro => "comerț-echitabil",
	he => 'סחר-הוגן',
	nl => "fair-trade",
	nl_be => "fair-trade",
	de => "Fair Trade",
},

search_series_with_sweeteners => {
	fr => 'Avec édulcorants',
	en => 'With sweeteners',
	el => 'Με προσθήκη γλυκαντικών',
	es => 'Con edulcorantes',
	pt => 'Com edulcorantes',
	ro => "Cu îndulcitori",
	he => 'עם ממתיקים',
	nl => "Met zoetstoffen",
	nl_be => "Met zoetstoffen",
	de => "Mit Süßstoff",
},

number_of_additives => {
	fr => "Nombre d'additifs",
	en => "Number of additives",
	el => 'Αριθμός προσθέτων',
	es => "Número de aditivos",
	pt => "Número de aditivos",
	ro => "Numărul de aditivi",
	he => "מספר התוספים",
	nl => "Aantal additieven",
	nl_be => "Aantal additieven",
	de => "Zusatzstoff-Anzahl",
},

number_of_products => {

    ar => 'عدد من المنتجات', #ar-CHECK - Please check and remove this comment
	de => "Produktanzahl",
    cs => 'Počet výrobků', #cs-CHECK - Please check and remove this comment
	es => "Número de productos",
	en => "Number of products",
    it => 'Numero di prodotti', #it-CHECK - Please check and remove this comment
    fi => 'Tuotteiden määrä', #fi-CHECK - Please check and remove this comment
	fr => "Nombre de produits",
	el => 'Αριθμός προϊόντων',
    he => 'מספר המוצרים',
    ja => '製品数', #ja-CHECK - Please check and remove this comment
    ko => '제품 수', #ko-CHECK - Please check and remove this comment
	nl => "Aantal producten",
	nl_be => "Aantal producten",
    ru => 'Количество продуктов', #ru-CHECK - Please check and remove this comment
    pl => 'Liczba produktów', #pl-CHECK - Please check and remove this comment
	pt => "Número de produtos",
	ro => "Numărul produselor",
    th => 'จำนวนของผลิตภัณฑ์', #th-CHECK - Please check and remove this comment
    vi => 'Số lượng sản phẩm', #vi-CHECK - Please check and remove this comment
    zh => '产品编号', #zh-CHECK - Please check and remove this comment

},

search_graph => {
	fr => 'Graphique',
	en => 'Graph',
	el => 'Γράφημα',
	es => 'Gráfico',
	pt => 'Gráfico',
	ro => "Grafic",
	he => 'תרשים',
	nl => "Grafiek",
	nl_be => "Grafiek",
	de => "Grafik",
},

search_map => {
	fr => 'Carte',
	en => 'Map',
	el => 'Χάρτης',
	es => 'Mapa',
	pt => 'Mapa',
	ro => "Hartă",
	he => 'מפה',
	nl => "Kaart",
	nl_be => "Kaart",
	de => "Karte",
},

search_list_choice => {

    ar => 'النتائج في قائمة من المنتجات', #ar-CHECK - Please check and remove this comment
    de => 'Ergebnisse in einer Liste der Produkte', #de-CHECK - Please check and remove this comment
    cs => 'Výsledky v seznamu výrobků,', #cs-CHECK - Please check and remove this comment
    es => 'Resultados en una lista de productos', #es-CHECK - Please check and remove this comment
	en => "Results in a list of products",
    it => 'Risultati in un elenco di prodotti', #it-CHECK - Please check and remove this comment
    fi => 'Tulokset tuotteiden luetteloon', #fi-CHECK - Please check and remove this comment
	fr => "Résultats sous forme de liste de produits",
    el => 'Τα αποτελέσματα σε μια λίστα προϊόντων', #el-CHECK - Please check and remove this comment
    he => 'תוצאות ברשימת מוצרים',
    ja => '製品のリストでの結果', #ja-CHECK - Please check and remove this comment
    ko => '제품 목록에서 결과', #ko-CHECK - Please check and remove this comment
    nl => 'Resulteert in een lijst van producten',
    nl_be => 'Resulteert in een lijst van producten',
    ru => 'Результаты в списке продуктов', #ru-CHECK - Please check and remove this comment
    pl => 'Wyniki w liście produktów', #pl-CHECK - Please check and remove this comment
    pt => 'Os resultados em uma lista de produtos', #pt-CHECK - Please check and remove this comment
    ro => 'Conduce la o listă de produse', #ro-CHECK - Please check and remove this comment
    th => 'ผลในรายการของผลิตภัณฑ์', #th-CHECK - Please check and remove this comment
    vi => 'Kết quả trong một danh mục sản phẩm', #vi-CHECK - Please check and remove this comment
    zh => '结果在产品列表', #zh-CHECK - Please check and remove this comment
},

search_graph_choice => {

    ar => 'النتائج على الرسم البياني', #ar-CHECK - Please check and remove this comment
    de => 'Ergebnisse in einem Diagramm', #de-CHECK - Please check and remove this comment
    cs => 'Výsledky na grafu', #cs-CHECK - Please check and remove this comment
    es => 'Resultados en un gráfico', #es-CHECK - Please check and remove this comment
	en => "Results on a graph",
    it => 'Risultati su un grafico', #it-CHECK - Please check and remove this comment
    fi => 'Tulokset kuvaajan', #fi-CHECK - Please check and remove this comment
	fr => "Résultats sur un graphique",
    el => 'Αποτελέσματα σε γράφημα', #el-CHECK - Please check and remove this comment
    he => 'תוצאות על תרשים',
    ja => 'グラフ上の結果', #ja-CHECK - Please check and remove this comment
    ko => '그래프에 결과', #ko-CHECK - Please check and remove this comment
    nl => 'Resultatengrafiek',
    nl_be => 'Resultatengrafiek',
    ru => 'Результаты на графике', #ru-CHECK - Please check and remove this comment
    pl => 'Wyniki na wykresie', #pl-CHECK - Please check and remove this comment
    pt => 'Resultados em um gráfico', #pt-CHECK - Please check and remove this comment
    ro => 'Rezultatele pe un grafic', #ro-CHECK - Please check and remove this comment
    th => 'ผลบนกราฟ', #th-CHECK - Please check and remove this comment
    vi => 'Kết quả trên một đồ thị', #vi-CHECK - Please check and remove this comment
    zh => '结果在图上', #zh-CHECK - Please check and remove this comment

},

search_map_choice => {

    ar => 'النتائج على خريطة', #ar-CHECK - Please check and remove this comment
    de => 'Treffer auf Karte anzeigen', #de-CHECK - Please check and remove this comment
    cs => 'Výsledky na mapě', #cs-CHECK - Please check and remove this comment
    es => 'Resultados en el mapa', #es-CHECK - Please check and remove this comment
	en => "Results on a map",
    it => 'I risultati su una mappa', #it-CHECK - Please check and remove this comment
    fi => 'Tulokset kartalla', #fi-CHECK - Please check and remove this comment
	fr => "Résultats sur une carte",
    el => 'Αποτελέσματα στο χάρτη', #el-CHECK - Please check and remove this comment
    he => 'תוצאות על מפה',
    ja => '地図上の検索結果', #ja-CHECK - Please check and remove this comment
    ko => '지도 결과', #ko-CHECK - Please check and remove this comment
    nl => 'Resultaten op een kaart',
    nl_be => 'Resultaten op een kaart',
    ru => 'Результаты на карте', #ru-CHECK - Please check and remove this comment
    pl => 'Wyniki na mapie', #pl-CHECK - Please check and remove this comment
    pt => 'Resultados em um mapa', #pt-CHECK - Please check and remove this comment
    ro => 'Rezultate pe o hartă', #ro-CHECK - Please check and remove this comment
    th => 'ผลบนแผนที่', #th-CHECK - Please check and remove this comment
    vi => 'Kết quả trên bản đồ', #vi-CHECK - Please check and remove this comment
    zh => '结果在地图上', #zh-CHECK - Please check and remove this comment

},

search_graph_instructions => {
	en => "Select what you want to graph on the horizontal axis to obtain a histogram, or select two axis to
get a cloud of products (scatter plot).",
	fr => "Choisissez ce que vous voulez représenter sur l'axe horizontale du graphique pour obtenir un histogramme, et
sur les deux axes pour obtenir un nuage de produits.",
	nl => "Kies wat je wil plotten op de horizontale as om een histogram te krijgen, of kies twee assen om een productenwolk te tonen.",
	nl_be => "Kies wat je wil plotten op de horizontale as om een histogram te krijgen, of kies twee assen om een productenwolk te tonen.",
},

search_download_choice => {
	fr => "Télécharger les résultats",
	en => "Download results",
	el => "Κατεβάστε αποτελέσματα",
	es => "Descargar los resultados",
	pt => "Transferir os resultados",
	ro => "Descărcați rezultatele",
	nl => "Download de resultaten",
	nl_be => "Download de resultaten",
	de => "Ergebnisse herunterladen",
	ar => 'تحميل النتائج', #ar-CHECK - Please check and remove this comment
	cs => 'Výsledky ke stažení', #cs-CHECK - Please check and remove this comment
	it => 'Scarica i risultati', #it-CHECK - Please check and remove this comment
	fi => 'Lataa tulokset', #fi-CHECK - Please check and remove this comment
	he => 'הורדת התוצאות',
	ja => 'ダウンロード結果', #ja-CHECK - Please check and remove this comment
	ko => '다운로드 결과', #ko-CHECK - Please check and remove this comment
	ru => 'Скачать результаты', #ru-CHECK - Please check and remove this comment
	pl => 'Pobierz wyniki',
	th => 'ผลการดาวน์โหลด', #th-CHECK - Please check and remove this comment
	vi => 'Tải xuống kết quả', #vi-CHECK - Please check and remove this comment
	zh => '下载结果', #zh-CHECK - Please check and remove this comment
},


search_title_graph => {
	fr => 'Graphique des résultats',
	en => 'Results graph',
	el => 'Γράφημα αποτελεσμάτων',
	es => 'Gráfico de los resultatdos',
	pt => 'Gráfico dos resultados',
	ro => "Graficul cu rezultate",
	he => 'תרשים התוצאות',
	nl => "Resultatengrafiek",
	nl_be => "Resultatengrafiek",
	de => "Ergebnisgrafik",
	ar => 'النتائج الرسم البياني', #ar-CHECK - Please check and remove this comment
	cs => 'Výsledky graf', #cs-CHECK - Please check and remove this comment
	it => 'Risultati grafico', #it-CHECK - Please check and remove this comment
	fi => 'Tulokset kaavio', #fi-CHECK - Please check and remove this comment
	ja => '結果グラフ', #ja-CHECK - Please check and remove this comment
	ko => '결과 그래프', #ko-CHECK - Please check and remove this comment
	ru => 'Результаты график', #ru-CHECK - Please check and remove this comment
	pl => 'Wykres wyników',
	th => 'กราฟผล', #th-CHECK - Please check and remove this comment
	vi => 'Kết quả đồ thị', #vi-CHECK - Please check and remove this comment
	zh => '结果图', #zh-CHECK - Please check and remove this comment
},

search_title_map => {
	fr => 'Carte des résultats',
	en => 'Results map',
	el => 'Χάρτης αποτελεσμάτων',
	es => 'Mapa de los resultatdos',
	pt => 'Mapa dos resultados',
	ro => "Harta cu rezultate",
	he => 'מפת התוצאות',
	nl => "Resultatenkaart",
	nl_be => "Resultatenkaart",
	de => "Ergebniskarte",
	ar => 'النتائج الخريطة', #ar-CHECK - Please check and remove this comment
	cs => 'Mapa výsledky', #cs-CHECK - Please check and remove this comment
	it => 'Risultati mappa', #it-CHECK - Please check and remove this comment
	fi => 'Tulokset kartta', #fi-CHECK - Please check and remove this comment
	ja => '結果マップ', #ja-CHECK - Please check and remove this comment
	ko => '결과지도', #ko-CHECK - Please check and remove this comment
	ru => 'Результаты на карте', #ru-CHECK - Please check and remove this comment
	pl => 'Mapa wyników',
	th => 'แผนที่ผล', #th-CHECK - Please check and remove this comment
	vi => 'Kết quả bản đồ', #vi-CHECK - Please check and remove this comment
	zh => '效果图', #zh-CHECK - Please check and remove this comment
},

search_results => {
	fr => "Résultats de la recherche",
	en => "Search results",
	el => 'Αναζήτηση αποτελεσμάτων',
	es => "Resultados de la búsqueda",
	pt => "Resultados da pesquisa",
	ro => "Rezultatele căutării",
	he => "תוצאות החיפוש",
	nl => "Zoekresultaten",
	nl_be => "Zoekresultaten",
	de => "Suchergebnisse",
},

search_download_results => {
	fr => "Télécharger les résultats au format CSV (Excel, OpenOffice)",
	en => "Download results in CSV format (Excel, OpenOffice)",
	el => "Κατεβάστε αποτελέσματα σε μορφή CSV (Excel, OpenOffice)",
	es => "Descargar los resultados en formato CSV (Excel, OpenOffice)",
	pt => "Transferir os resultados em formato CSV (Excel, OpenOffice)",
	ro => "Descărcați rezultatele în format CSV (Excel, OpenOffice)",
	he => "הורדת התוצאות במבנה CSV (Excel, LibreOffice)",
	nl => "Download de resultaten in CSV-formaat (Excel, OpenOffice)",
	nl_be => "Download de resultaten in CSV-formaat (Excel, OpenOffice)",
	de => "Ergebnisse in CSV-Format herunterladen (Excel, OpenOffice)",
},

search_download_results_description => {
	fr => "Jeu de caractère : Unicode (UTF-8). Séparateur : tabulation (tab).",
	en => "Character set: Unicode (UTF-8)). Separator: tabulation (tab).",
	el => "Πίνακες χαρακτηρων: Unicode (UTF-8)). Οριοθέτης: tabulation (tab).",
	es => "Juego de caractéres: Unicode (UTF-8)). Separador: tabulador (tab).",
	pt => "Mapa de caracteres: Unicode (UTF-8). Separador: tabulação (TAB).",
	ro => "Set de caractere: Unicode (UTF-8). Separator: tabulare (tab).",
	he => "ערכת תווים: יוניקוד (UTF-8). הפרדה: טאב (tab)",
	nl => "Tekenset: Unicode (UTF-8). Separator: tab (tab)",
	nl_be => "Tekenset: Unicode (UTF-8). Separator: tab (tab)",
	de => "Zeichenset: Unicode (UTF-8). Trenner: Tabulator (tab-Taste).",
},

search_flatten_tags => {
	fr => "(Optionnel) - Créer une colonne pour chaque :",
	en => '(Optional) - Create a column for every:',
	da => '(Valgfrit) - Opret en kolonne for hver:',
	el => "(Προαιρετικό) - Δημιούργησε μία στήλη για κάθε:",
	cs => "(Nepovinné) - Vytvořit sloupec pro každý:",
	es => "(Opcional) - Crear una columna para cada:",
	pt => "(Opcional) - Criar uma coluna para cada:",
	ro => "(Opțional) - Crează o coloană pentru fiecare:",
	he => "(רשות) - יצירת עמודה בכל:",
	nl => "(Optioneel) - Een kolom creëren voor elke:",
	nl_be => "(Optioneel) - Een kolom creëren voor elke:",
	de => "(optional) - Spalte erstellen für jede(s)/n:",
	id => "(Opsional) - Buat seuah kolom untuk setiap:",
},

search_download_button => {

    ar => 'تحميل', #ar-CHECK - Please check and remove this comment
	de => "Herunterladen",
    cs => 'Ke stažení', #cs-CHECK - Please check and remove this comment
	es => "Descargar",
	en => "Download",
    it => 'Scarica', #it-CHECK - Please check and remove this comment
    fi => 'Lataa', #fi-CHECK - Please check and remove this comment
	fr => "Télécharger",
	el => "Download",
	he => "הורדה",
    ja => 'ダウンロード', #ja-CHECK - Please check and remove this comment
    ko => '다운로드', #ko-CHECK - Please check and remove this comment
	nl => "Downloaden",
	nl_be => "Downloaden",
    ru => 'Скачать', #ru-CHECK - Please check and remove this comment
    pl => 'Pobierz', #pl-CHECK - Please check and remove this comment
	pt => "Transferir",
	ro => "Descarcă",
    th => 'ดาวน์โหลด', #th-CHECK - Please check and remove this comment
    vi => 'Tải về', #vi-CHECK - Please check and remove this comment
    zh => '下载', #zh-CHECK - Please check and remove this comment

},

axis_x => {
	fr => "Axe horizontal",
	en => "Horizontal axis",
	es => "Eje horizontal",
	el => "Οριζόντιος άξονας",
	pt => "Eixo horizontal",
	ro => "Axa orizontală",
	he => "ציר אופקי",
	nl => "Horizontale as",
	nl_be => "Horizontale as",
	de => "X-Achse",
},

axis_y => {
	fr => "Axe vertical",
	da => 'Lodret akse',
	en => "Vertical axis",
	el => "Κατακόρυφος άξονας",
	es => "Eje vertical",
	pt => "Eixo vertical",
	ro => "Axa verticală",
	he => "ציר אנכי",
	nl => "Verticale as",
	nl_be => "Verticale as",
	de => "Y-Achse",
	ru => 'Вертикальная ось',
},

search_generate_graph => {
	fr => "Générer le graphique",
	en => "Generate graph",
	el => "Δημιουργησε γραφημα",
	es => "Generar el gráfico",
	pt => "Gerar o gráfico",
	ro => "Generare grafic",
	he => "יצירת תרשים",
	nl => "De grafiek maken",
	nl_be => "De grafiek maken",
	de => "Grafik erzeugen",
},

search_graph_warning => {
	fr => "Note : ce graphique a été généré par un utilisateur du site Open Food Facts. Le titre, les produits representés et les axes de représentation ont été choisis par l'auteur du graphique.",
	en => "Note: this is a user generated graph. The title, represented products and axis of visualization have been chosen by the author of the graph.",
	el => "Σημείωση: αυτό είναι είναι ένα γράφημα φτιαγμένο από  χρήστη. Ο τίτλος, τα παρουσιαζόμενα προϊόντα και η παρουσίαση των αξόνων έχουν επιλεχθεί από το δημιουργό του γραφήματος.",
	es => "Nota: Este gráfico fue generado por un usuario de Open Food Facts. El título, los productos representados y los ejes de la representación han sido escogidos por el autor del gráfico.",
	pt_pt => "Nota: Este gráfico foi gerado por um utilizador do Open Food Facts. O título, os produtos representados e os eixos de visualização foram escolhidos pelo autor do gráfico.",
	ro => "Notă: acesta este un grafic generat de un utilizator. Titlul, produsele reprezentate și axa de vizualizare au fost alese de către autorul graficului.",
	he => "לתשומת לבך: תרשים זה נוצר על־ידי משתמש. הכותרת, המוצרים המיוצגים והציר נבחרו כולם על־ידי יוצר התרשים.",
	nl => "Opmerking: deze grafiek werd gemaakt door een gebruiker van Open Food Facts. De titel, de afgebeelde producten en de assen werden gekozen door de maker van de grafiek.",
	nl_be => "Opmerking: deze grafiek werd gemaakt door een gebruiker van Open Food Facts. De titel, de afgebeelde producten en de assen werden gekozen door de maker van de grafiek.",
	de => "Bemerkung: diese Grafik wurde von einem Benutzer der Open Food Facts Gemeinschaft erzeugt. Der Titel, die ang ezeigten Produkte und die Achsen wurden von dem Benutzer selbst ausgewählt.",
},

search_generate_map => {
	fr => "Générer la carte",
	en => "Generate the map",
	el => "Δημιουργήστε το χάρτη",
	es => "Generar la mapa",
	pt => "Gerar o mapa",
	ro => "Generează harta",
	he => "יצירת מפה",
	nl => "De kaart maken",
	nl_be => "De kaart maken",
	de => "Karte erzeugen",
},

search_graph_blog => {
	fr => "<p>→ en savoir plus sur les graphiques d'Open Food Facts : <a href=\"http://fr.blog.openfoodfacts.org/news/des-graphiques-en-3-clics\">Des graphiques en 3 clics</a> (blog).</p>",
	en => "",
	el => "<p>Για να μάθετε περισσότερα για τα γραφήματα του Open Food Facts: <a href=\"http://fr.blog.openfoodfacts.org/news/des-graphiques-en-3-clics\">Τα γραφήματα σε 3 κλικς (στα γαλλικά)</a> (blog).</p>",
	es => "<p>→ para saber más acerca de los gráficos de Open Food Facts: <a href=\"http://fr.blog.openfoodfacts.org/news/des-graphiques-en-3-clics\">Los gráficos en 3 clics (en francés)</a> (blog).</p>",
	pt => "<p>→ para saber mais acerca dos gráficos do Open Food Facts: <a href=\"http://fr.blog.openfoodfacts.org/news/des-graphiques-en-3-clics\">Gráficos em 3 cliques (en francês)</a> (blog).</p>",
	ro => "<p>→ pentru a afla mai multe despre graficele de pe Open Food Facts : <a href=\"http://fr.blog.openfoodfacts.org/news/des-graphiques-en-3-clics\">Graficele în 3 click-uri (în franceză)</a> (blog).</p>",
	nl => "<p>→ meer weten over de grafieken van Open Food Facts: <a href=\"http://fr.blog.openfoodfacts.org/news/des-graphiques-en-3-clics\">Grafieken in drie muisklikken</a> (blog).</p>",
	nl_be => "<p>→ meer weten over de grafieken van Open Food Facts: <a href=\"http://fr.blog.openfoodfacts.org/news/des-graphiques-en-3-clics\">Grafieken in drie muisklikken</a> (blog).</p>",
	de => "<p>→ mehr über Open Food Facts Grafiken erfahren: <a href=\"http://fr.blog.openfoodfacts.org/news/des-graphiques-en-3-clics\">Grafiken in 3-Click</a> (blog).</p>",
},

advanced_search_old => {
	fr => "Recherche avancée, graphiques et carte",
	en => "Advanced search and graphs",
	el => "Προηγμένη αναζήτηση, γραφήματα και χάρτες",
	es => "Búsqueda avanzada y gráficos",
	pt => "Pesquisa avançada e gráficos",
	ro => "Căutare și grafice avansate",
	he => "חיפוש מתקדם ותרשימים",
	nl => "Geavanceerd zoeken, grafieken en kaart",
	nl_be => "Geavanceerd zoeken, grafieken en kaart",
	de => "Erweiterte Suche, Grafiken und Karten",
},

advanced_search => {
	fr => "Recherche avancée",
	en => "Advanced search",
	es => "Búsqueda avanzada",
	pt => "Pesquisa avançada",
	nl => "Geavanceerd zoeken",
	nl_be => "Geavanceerd zoeken",
	de => "Erweiterte Suche",
},

graphs_and_maps => {
	fr => "Graphiques et cartes",
	en => "Graphs and maps",
	es => "Gráficos",
	pt => "Gráficos",
	nl => "Grafieken en kaart",
	nl_be => "Grafieken en kaart",
	de => "Grafiken und Karten",
},

edit_comment => {
	fr => "Description de vos changements",
	en => "Changes summary",
	el => "Περίληψη αλλαγών",
	es => "Descripción de los cambios",
	pt => "Resumo das suas edições",
	ro => "Sumarul schimbărilor",
	he => "תקציר השינויים",
	nl => "Overzicht van de wijzigingen",
	nl_be => "Overzicht van de wijzigingen",
	de => "Bearbeitung begründen",
	ru => 'Сводка изменений',
},

delete_comment => {
	fr => "Raison de la suppression",
	en => "Reason for removal",
	da => 'Årsag til fjernelse',
	el => "Αιτία διαγραφής",
	es => "Motivo de la eliminación",
	pt => "Motivo para a eliminacão",
	ro => "Motivul ștergerii",
	he => "הסיבה להסרה",
	nl => "Reden voor verwijdering",
	nl_be => "Reden voor verwijdering",
	de => "Löschung begründen",
},

history => {
	fr => "Historique des modifications",
	en => "Changes history",
	el => "Ιστορικό τροποποιήσεων",
	es => "Historial de revisiones",
	pt => "Historial das edições",
	ro => "Istoricul schimbărilor",
	he => "היסטוריית השינויים",
	nl => "Wijzigingsschiedenis",
	nl_be => "Wijzigingsschiedenis",
	de => "Historie der Veränderungen",
	ru => 'История изменений',
},

new_code => {
	fr => "Une erreur de code barre ? Vous pouvez entrer le bon ici :",
	en => "If the barcode is not correct, please correct it here:",
	el => "Αν το barcode δεν είναι σωστό, παρακαλώ διορθώστε το εδώ:",
	es => "Si el código de barras no es correcto, por favor corrígelo aquí:",
	pt => "O código de barras está errado? Corrige-o aqui, por favor:",
	ro => "Dacă codul de bare nu este corect, sunteți rugat să-l corectați aici:",
	he => "אם הברקוד לא נכון, נא לתקן אותו כאן:",
	nl => "Een foutieve barcode? Type hier de correcte code:",
	nl_be => "Een foutieve barcode? Geef hier de correcte code in:",
	de => "Barcode ist fehlerhaft? Bitte einfach hier korrigieren:",
},

new_code_note => {
	fr => "Pour les produits sans code barre, un code interne est attribué automatiquement.",
	en => "For products without a barcode, an internal code is automatically set.",
	el => "Για προϊόντα χωρίς barcode, καθορίζεται αυτομάτως ένας εσωτερικός κώδικας ",
	es => "A los productos sin código de barras se les asignará automáticamente un código interno.",
	pt => "Para os produtos sem código de barras, um código interno é atribuido automaticamente.",
	ro => "Pentru produsele fără un cod de bare, un cod intern este înregistrat.",
	he => "למוצרים ללא ברקוד, מוגדר קוד פנימי אוטומטית.",
	nl => "Producten zonder barcode krijgen automatisch een interne code.",
	nl_be => "Producten zonder barcode krijgen automatisch een interne code.",
	de => "Produkte ohne Barcode werden automatisch mit einem internen Code gestampelt.",
},

error_new_code_already_exists => {
	fr => "Un produit existe déjà avec le nouveau code",
	en => "A product already exists with the new code",
	el => "Υπάρχει ήδη προϊόν με το νέο κώδικα ",
	es => "Ya existe un producto con el nuevo código",
	pt => "Já existe um produto com este novo código",
	ro => "Un produs cu noul cod deja există",
	he => "כבר קיים מוצר עם הקוד החדש",
	nl => "Er bestaat reeds een product met de nieuwe code",
	nl_be => "Er bestaat reeds een product met de nieuwe code",
	de => "Ein Produkt mit diesem neuen Code ist schon vorhanden",
},

product_js_uploading_image => {

    ar => 'تحميل الصور', #ar-CHECK - Please check and remove this comment
	de => "Das Foto wird hochgeladen",
    cs => 'Nahrávání image', #cs-CHECK - Please check and remove this comment
	es => "Cargando la imagen",
	en => "Uploading image",
    it => 'Immagine Caricamento', #it-CHECK - Please check and remove this comment
    fi => 'Lataaminen kuva', #fi-CHECK - Please check and remove this comment
	fr => "Image en cours d'envoi",
	el => "Η εικόνα αποστέλλεται",
	he => "התמונה נשלחת",
    ja => 'アップロード画像', #ja-CHECK - Please check and remove this comment
    ko => '업로드 이미지', #ko-CHECK - Please check and remove this comment
	nl => "De foto wordt verzonden",
	nl_be => "De foto wordt verzonden",
    ru => 'Загрузка изображений', #ru-CHECK - Please check and remove this comment
    pl => 'Przesyłanie obrazu', #pl-CHECK - Please check and remove this comment
	pt => "Enviando a imagem",
	pt_pt => "A enviar a imagem",
	ro => "Îmaginea se transmite",
    th => 'ภาพที่อัพโหลด', #th-CHECK - Please check and remove this comment
    vi => 'Hình ảnh tải lên', #vi-CHECK - Please check and remove this comment
    zh => '上传图片', #zh-CHECK - Please check and remove this comment

},

product_js_image_received => {
	fr => "Image reçue",
	en => "Image received",
	el => "Η εικόνα ελήφθη",
	es => "La imagen ha sido recibida",
	pt => "Imagem recebida",
	ro => "Imagine recepționată",
	he => "התמונה התקבלה",
	nl => "Foto ontvangen",
	nl_be => "Foto ontvangen",
	de => "Foto erfolgreich hochgeladen",
},

product_js_image_upload_error => {
	fr => "Erreur lors de l'envoi de l'image",
	en => "Error while uploading image",
	el => "Σφάλμα κατά την αποστολή της εικόνας",
	es => "Se ha producido un error al enviar la imagen",
	pt => "Houve um erro durante o envio da imagem",
	ro => "Eroare în timpul transmiterii imaginii",
	he => "העלאת התמונה נכשלה",
	nl => "Fout tijdens het uploaden van de foto",
	nl_be => "Fout tijdens het uploaden van de foto",
	de => "Ein Fehler ist während des Hochladens des Fotos aufgetreten",
},

product_js_deleting_images => {

	en => "Deleting images",
 	fr => "Images en cours de suppression",
 	nl => "Foto's aan het verwijderen",
 	nl_be => "Foto's aan het verwijderen",
},

product_js_images_deleted => {
	fr => "Images supprimées",
	en => "Images deleted",
	nl => "Foto's verwijderd",
	nl_be => "Foto's verwijderd",
},

product_js_images_delete_error => {
	fr => "Erreur lors de la suppresion des images",
	en => "Errors while deleting images",
	nl => "Fouten tijdens verwijderen foto's",
	nl_be => "Fouten tijdens verwijderen foto's",
},

product_js_moving_images => {

	en => "Moving images",
 	fr => "Images en cours de déplacement",
	nl => "Foto's aan het verplaatsen",
	nl_be => "Foto's aan het verplaatsen",
},

product_js_images_moved => {
	fr => "Images déplacées",
	en => "Images moved",
	nl => "Foto's verplaatst",
	nl_be => "Foto's verplaatst",
},

product_js_images_move_error => {
	fr => "Erreur lors du déplacement des images",
	en => "Errors while moving images",
	nl => "Fouten tijdens het verplaatsen foto's",
	nl_be => "Fouten tijdens het verplaatsen foto's",
},


product_js_image_rotate_and_crop => {
	fr => "Redressez l'image si nécessaire, puis cliquez et glissez pour sélectionner la zone d'intérêt :",
	en => "Rotate the image if necessary, then click and drag to select the interesting zone:",
	el => "Περιστρέψτε την εικόνα αν είναι απαραίτητο, εν συνεχεία κλικαρετε και σύρετε για να επιλέξετε την περιοχή που σας ενδιαφέρει ",
	es => "Rota la imagen si es necesario, después haz clic y arrastra para seleccionar la zona de interés:",
	pt => "Rode a imagem se necessário, depois clique e arraste para seleccionar a zona pretendida:",
	ro => "Rotiți imaginea dacă este necesar, apoi dați click și trageți pentru a selecta zona de interes:",
	he => "הטיית התמונה אם יש צורך בכך ולאחר מכן ניתן ללחוץ ולגרור כדי לבחור את האזור המעניין:",
	nl => "Draai indien nodig de foto, klik en sleep om de beoogde zone te selecteren:",
	nl_be => "Draai indien nodig de foto, klik en sleep om de beoogde zone te selecteren:",
	de => "Drehen Sie das Bild, falls notwendig. Anschließend können Sie das Bild durch Klicken und Ziehen mit der Maus zuschneiden:",
},

product_js_image_rotate_left => {

    ar => 'دوران لليسار', #ar-CHECK - Please check and remove this comment
	de => "Nach Links drehen",
    cs => 'Otočit doleva', #cs-CHECK - Please check and remove this comment
	es => "Girar a la izquierda",
	en => "Rotate left",
    it => 'Ruota a sinistra', #it-CHECK - Please check and remove this comment
    fi => 'Kierrä vasemmalle', #fi-CHECK - Please check and remove this comment
	fr => "Pivoter à gauche",
	el => "Περιστροφή αριστερά",
	he => "הטייה לשמאל",
    ja => '左を回して', #ja-CHECK - Please check and remove this comment
    ko => '회전 왼쪽', #ko-CHECK - Please check and remove this comment
	nl => "Draai naar links",
	nl_be => "Naar links draaien",
    ru => 'Поворот влево', #ru-CHECK - Please check and remove this comment
    pl => 'Obróć w lewo', #pl-CHECK - Please check and remove this comment
	pt => "Rodar para a esquerda",
	ro => "Rotire la stânga",
    th => 'หมุนซ้าย', #th-CHECK - Please check and remove this comment
    vi => 'Xoay trái', #vi-CHECK - Please check and remove this comment
    zh => '向左旋转', #zh-CHECK - Please check and remove this comment

},

product_js_image_rotate_right => {

    ar => 'تدوير الحق', #ar-CHECK - Please check and remove this comment
	de => "Nach Rechts drehen",
    cs => 'Otočit doprava', #cs-CHECK - Please check and remove this comment
	es => "Girar a la derecha",
	en => "Rotate right",
    it => 'Ruota a destra', #it-CHECK - Please check and remove this comment
    fi => 'Kierrä oikealle', #fi-CHECK - Please check and remove this comment
	fr => "Pivoter à droite",
	el => "Περιστροφή δεξιά",
	he => "הטייה לימין",
    ja => '右に回転', #ja-CHECK - Please check and remove this comment
    ko => '오른쪽으로 회전', #ko-CHECK - Please check and remove this comment
	nl => "Draai naar rechts",
	nl_be => "Naar rechts draaien",
    ru => 'Повернуть вправо', #ru-CHECK - Please check and remove this comment
    pl => 'Obróć w prawo', #pl-CHECK - Please check and remove this comment
	pt => "Rodar para a direita",
	ro => "Rotire la dreapta",
    th => 'หมุนขวา', #th-CHECK - Please check and remove this comment
    vi => 'Xoay phải', #vi-CHECK - Please check and remove this comment
    zh => '右移', #zh-CHECK - Please check and remove this comment

},

product_js_image_normalize => {
	fr => "Equilibrage des couleurs",
	en => "Normalize colors",
	el => "Εξισορρόπηση χρώματος",
	es => "Equilibra los colores",
	pt => "Normalizar as cores",
	ro => "Normalizare culori",
	he => "איזון הצבעים",
	nl => "Kleurbalans corrigeren",
	nl_be => "Kleurbalans corrigeren",
	de => "Farbenwiedergabe korrigieren",
},

product_js_image_open_full_size_image => {
	fr => "Voir la photo en grand dans une nouvelle fenêtre",
	en => "Open the picture in original size in a new windows",
	el => "Ανοίξτε την εικόνα σε μεγάλο μέγεθος σε νέο παράθυρο",
	es => "Abrir la imagen en su tamaño original en una nueva ventana",
	pt => "Abrir a imagem no tamanho original numa nova janela",
	ro => "Deschide imaginea în dimensiunea originală într-o fereastră nouă",
	nl => "De foto in het groot of in een nieuw venster bekijken",
	nl_be => "De foto in het groot of in een nieuw venster bekijken",
	de => "Das Foto in Großformat in einem neuen Fenster anzeigen",
},

product_js_image_white_magic => {
	fr => "Photo sur fond blanc : essayer d'enlever le fond",
	en => "Photo on white background: try to remove the background",
	el => "Φωτογραφία σε λευκό background:Προσπαθήστε να αφαιρέσετε το background",
es => "Foto sobre fondo blanco: prueba a eliminar el fondo",
	pt => "Fotografia sobre fundo branco: tentar eliminar o fundo",
	ro => "Fotografie pe fundal alb: încearcă să ștergi fundalul",
	he => "תמונה עם רקע לבן: לנסות להסיר את הרקע",
	nl => "Foto op een witte achtergrond: probeer de achtergrond te verwijderen",
	nl_be => "Foto op een witte achtergrond: probeer de achtergrond te verwijderen",
	de => "Foto auf weißem Hintergrund: probieren, den Hintergrund zu entfernen",
},

product_js_image_save => {
	fr => "Valider et/ou recadrer l'image",
	en => "Validate and/or resize image",
	da => 'Validere og/eller ændre størrelsen på billedet',
	el => "Επιβεβαιώστε και/ή αναπροσαρμόστε το μέγεθος της εικόνας",
	es => "Validar y/o recortar la imagen",
	pt => "Validar e/ou redimensionar a imagem",
	ro => "Validează și/sau redimensionează imaginea",
	he => "אימות ו/או שינוי גודל התמונה",
	nl => "De foto goedkeuren en/of verkleinen",
	nl_be => "De foto valideren en/of verkleinen",
	de => "Das Foto genehmigen und/oder ausrichten",
},

product_js_image_saving => {
	fr => "Image en cours d'enregistrement",
	en => "Saving image",
	el => "Η εικόνα αποθηκεύεται",
	es => "La imagen está siendo guardada",
	pt => "A guardar imagem",
	ro => "Imaginea se salvează",
	he => "התמונה נשמרת",
	nl => "De foto wordt opgeslagen",
	nl_be => "De foto wordt opgeslagen",
	de => "Das Foto wird gespeichert",
},

product_js_image_saved => {
	fr => "Image enregistrée.",
	en => "Image saved",
	el => "Η εικόνα αποθηκεύτηκε",
	es => "Imagen guardada",
	pt => "Imagem guardada",
	ro => "Imagine salvată",
	he => "התמונה נשמרה",
	nl => "Foto opgeslagen",
	nl_be => "Foto opgeslagen",
	de => "Foto gespeichert",
},

product_js_current_image => {
	fr => "Image actuelle :",
	en => "Current image:",
	el => "Παρούσα εικόνα:",
	es => "Imagen actual:",
	pt => "Imagem atual:",
	ro => "Imaginea curentă:",
	he => "התמונה הנוכחית:",
	nl => "Huidige foto:",
	nl_be => "Huidige foto:",
	de => "Aktuelles Foto:",
},

product_js_extract_ingredients => {

    ar => 'استخراج المكونات من الصورة', #ar-CHECK - Please check and remove this comment
	de => "Die Zutaten des Fotos extrahieren",
    cs => 'Výpis přísady z obrázku', #cs-CHECK - Please check and remove this comment
	es => "Extraer los ingredientes de la imagen",
	en => "Extract the ingredients from the picture",
    it => 'Estrarre gli ingredienti della foto', #it-CHECK - Please check and remove this comment
    fi => 'Ote ainesosat kuva', #fi-CHECK - Please check and remove this comment
	fr => "Extraire les ingrédients de l'image",
	el => "Εξάγετε τα συστατικά από την εικόνα",
	he => "חילוץ הרכיבים מהתמונה",
    ja => '画像から成分を抽出します', #ja-CHECK - Please check and remove this comment
    ko => '사진에서 성분을 추출', #ko-CHECK - Please check and remove this comment
	nl => "Detecteer de ingrediënten op de foto",
	nl_be => "Detecteer de ingrediënten op de foto",
    ru => 'Выписка ингредиенты, указанные на картинке', #ru-CHECK - Please check and remove this comment
    pl => 'Wyodrębnić składniki z obrazka', #pl-CHECK - Please check and remove this comment
	pt => "Extrair os ingredientes da imagem",
	ro => "Extrage ingredientele din imagine:",
    th => 'สารสกัดจากส่วนผสมจากภาพ', #th-CHECK - Please check and remove this comment
    vi => 'Trích xuất các thành phần từ các hình ảnh', #vi-CHECK - Please check and remove this comment
    zh => '提取图像中的成分', #zh-CHECK - Please check and remove this comment

},

product_js_extracting_ingredients => {
	fr => "Extraction des ingrédients en cours",
	el => "Εξαγωγή συστατικών σε εξέλιξη",
	en => "Extracting ingredients",
	es => "Extrayendo los ingredientes",
	pt => "Extraindo os ingredientes",
	pt_pt => "A extrair os ingredientes",
	ro => "Extrag ingredientele",
	he => "הרכיבים מחולצים",
	nl => "Bezig de ingrediënten te detecteren",
	nl_be => "Bezig de ingrediënten te detecteren",
	de => "Zutaten werden extrahiert",
},

product_js_extracted_ingredients_ok => {
	fr => "Le texte des ingrédients a été extrait. La reconnaissance du texte n'est pas toujours parfaite, merci de vérifier le texte ci-dessous et de corriger les éventuelles erreurs.",
	en => "Ingredients text has been extracted. Text recognition is not perfect, so please check the text below and correct errors if needed.",
el => "Το κείμενο των συστατικών έχει εξαχθει. Η αναγνωριση του κειμένου δεν είναι τέλεια, παρακαλούμε ελεγξτε το κείμενο και διορθώστε ενδεχόμενα σφάλματα αν αυτό είναι απαραίτητο.",
	es => "Se ha extraído el texto de los ingredientes. El reconocimiento de texto no siempre es perfecto. Por favor revisa el texto extraído y corrige los errores si es necesario.",
	pt => "A lista de ingredientes foi extraída. O reconhecimento do texto não é sempre perfeito. Por favor verifique o texto extraído e corrija os erros se necessário.",
	ro => "Textul cu ingrediente a fost extras. Recunoașterea de text nu este perfectă, deci sunteți rugați să verificați textul de mai jos și să corectați erorile dacă este necesar.",
	he => "טקסט הרכיבים חולץ. מנגנון זיהוי הטקסט אינו מושלם ולכן מומלץ לבדוק אם הטקסט שלהלן נכון ולתקן את הטעויות במידת הצורך.",
	nl => "De tekst met de ingrediënten is gedetecteerd. De tekstherkenning is niet altijd perfect, dus controleer de tekst hieronder en verbeter eventuele fouten.",
	nl_be => "De tekst met de ingrediënten werd gedetecteerd. De tekstherkenning is niet altijd perfect, gelieve de tekst hieronder te controleren en eventuele fouten te verbeteren.",
	de => "Die angegebenen Zutaten wurden extrahiert. Da die Texterkennung nicht immer richtig ist, bitten wir Sie, den untenstehenden Text zu überprüfen und möglicherweise vorhandene Fehler zu korrigieren.",
},

product_js_extracted_ingredients_nok => {
	fr => "Le texte des ingrédients n'a pas pu être extrait. Vous pouvez essayer avec une image plus nette, de meilleure résolution, ou un meilleur cadrage du texte.",
	en => "Ingredients text could not be extracted. Try with a sharper image, with higher resolution or a better framing of the text.",
	el => "Δεν ήταν δυνατόν να εξαχθεί το κείμενο των συστατικών. Παρακαλούμε ξαναπροσπαθήστε με μια πιο καθαρή εικόνα, καλύτερη ανάλυση ή καλύτερη διαμόρφωση κειμένου .",
	es => "No se puede extraer el texto de los ingredientes. Prueba con una imagen más nítida, con mayor resolución o con un mejor encuadre del texto.",
	pt => "Não foi possível extrair a lista de ingredientes. Tente de novo com uma imagem mais nítida, com maior resolução ou melhor enquadramento do texto.",
	ro => "Textul cu ingrediente nu a putut fi extras. Încercați cu o imagine mai clară, cu o rezoluție mai mare sau o mai bună încadrare a textului.",
	he => "לא ניתן לחלץ את טקסט הרכיבים. כדאי לנסות עם תמונה חדה יותר ברזולוציה גבוהה יותר או במסגור טוב יותר של הטקסט.",
	nl => "De tekst met de ingrediënten kon niet gedetecteerd worden. Je kan het opnieuw proberen met een scherpere foto, of met een foto met een hogere resolutie of een betere kadrering van de tekst",
	nl_be => "De tekst met de ingrediënten kon niet gedetecteerd worden. U kunt het opnieuw proberen met een scherpere foto, of met een foto met een hogere resolutie of een betere kadrering van de tekst",
	de => "Die Angaben der Zutaten konnten nicht extrahiert werden. Sie können es mit einem schärferen Bild, mit höherer Auflösung, oder durch eine bessere Bildeinstellung erneut probieren.",
},

product_js_upload_image => {
	ar => 'اضف صورة', #ar-CHECK - Please check and remove this comment
	de => "Foto hochladen",
	cs => 'Přidat obrázek', #cs-CHECK - Please check and remove this comment
	es => "Añadir una imagen",
	en => "Add a picture",
	da => 'Tilføj et billede',
	it => 'Aggiungere un immagine', #it-CHECK - Please check and remove this comment
	fi => 'Lisää kuva', #fi-CHECK - Please check and remove this comment
	fr => "Envoyer une image",
	el => "Προσθέστε μια εικόνα",
	he => "הוספת תמונה",
	ja => '画像を追加', #ja-CHECK - Please check and remove this comment
	ko => '사진 추가', #ko-CHECK - Please check and remove this comment
	nl => "Voeg een foto toe",
	nl_be => "Voeg een foto toe",
	ru => 'Добавить изображение',
	pl => 'Dodaj obrazek', #pl-CHECK - Please check and remove this comment
	pt => "Adicionar uma imagem",
	ro => "Agaugă o imagine",
	th => 'เพิ่มรูปภาพ', #th-CHECK - Please check and remove this comment
	vi => 'Thêm một hình ảnh', #vi-CHECK - Please check and remove this comment
	zh => '添加图片',

},

product_js_upload_image_note => {
	fr => "→ Avec Chrome, Firefox et Safari, vous pouvez sélectionner plusieurs images (produit, ingrédients, infos nutritionnelles etc.) en cliquant avec la touche Ctrl enfoncée, pour les envoyer toutes en même temps.",
	en => "→ With Chrome, Firefox and Safari, you can select multipe pictures (product, ingredients, nutrition facts etc.) by clicking them while holding the Ctrl key pressed to add them all in one shot.",
	da => '→ Med Chrome, Firefox og Safari, kan du vælge flere billeder (produkt, ingredienser, ernæringsindhold) ved at klikke på dem, mens du holder Ctrl-tasten nede for at tilføje dem alle i en omgang.',
	el => "→ Με τους Chrome, Firefox and Safari, μπορείτε να επιλεξετε πολλαπλές εικόνες (προϊόν, συστατικά, θρεπτικά συστατικά κλπ.) κλικάροντάς τες ενώ ταυτόχρονα κρατάτε το πλήκτρο Ctrl πατημένο προκειμένου να τις προσθέσετε όλες μαζί ταυτόχρονα.",
	es => "→ Con Chrome, Firefox y Safari, puedes seleccionar varias imágenes al mismo tiempo (producto, ingredientes, información nutricional, etc.) manteniendo pulsada la tecla Ctrl y haciendo clic sobre las imágenes que quieras seleccionar para enviarlas todas a la vez.",
	pt => "→ Com o Chrome, Firefox e Safari, pode seleccionar várias imagens ao memsmo tempo (produto, ingredientes, informação nutricional, etc.) clicando nelas enquando a tecla Ctrl estiver premida, para as adicionar de uma só vez.",
	ro => "→ Cu Chrome, Firefox și Safari, puteți selecta mai multe imagini (produs, ingrediente, valori nutriționale etc.). Dați click pe ele în timp ce țineți apăsați tasta Ctrl pentru a le adăuga pe toate în același timp.",
	he => "← עם כרום, פיירפוקס וספארי, ניתן לבחור מספר תמונות (מוצר, רכיבים, מפרט תזונתי) על ידי לחיצה עליהן בעת החזקת המקש Ctrl כדי להוסיף את כולן באותה התמונה.",
	nl => "→ Met Chrome, Firefox en Safari kan je verschillende foto's (product, ingrediënten, voedingswaarden, etc.) selecteren door tijdens het klikken de Ctrl-toets ingedrukt te houden om ze in één keer verzenden.",
	nl_be => "→ Met Chrome, Firefox en Safari kunt u verschillende foto's (product, ingrediënten, nutritionele informatie, etc.) selecteren door tijdens het klikken de Ctrl-toets ingedrukt te houden om ze in één keer verzenden.",
	de => "→ Mit Chrome, Firefox und Safari können Sie einfach durch die Benutzung der Strg-Taste mehrere Fotos auswählen (Produkt, Zutaten, Nährwertinformationen, usw.), um diese einmalig hochzuladen.",
},

image_upload_error_image_already_exists => {

    ar => 'وقد تم إرسال هذه الصورة.', #ar-CHECK - Please check and remove this comment
	de => "Dieses Foto wurde schon hochgeladen.",
    cs => 'Tento obrázek již byla odeslána.', #cs-CHECK - Please check and remove this comment
    es => 'Esta imagen ya ha sido enviado.', #es-CHECK - Please check and remove this comment
	en => "This picture has already been sent.",
    it => 'Questa immagine è già stato inviato.', #it-CHECK - Please check and remove this comment
    fi => 'Tämä kuva on jo lähetetty.', #fi-CHECK - Please check and remove this comment
	fr => "Cette photo a déjà été envoyée.",
	el => "Αυτή ή εικόνα έχει ήδη σταλεί",
    he => 'תמונה זו כבר נשלחה.',
    ja => 'この画像は、すでに送信されています。', #ja-CHECK - Please check and remove this comment
    ko => '이 사진은 이미 보냈습니다.', #ko-CHECK - Please check and remove this comment
    nl => 'Deze foto werd reeds geupload.',
    nl_be => 'Deze foto werd reeds geupload.',
    ru => 'Эта картина уже было отправлено.', #ru-CHECK - Please check and remove this comment
    pl => 'To zdjęcie zostało już wysłane.', #pl-CHECK - Please check and remove this comment
    pt => 'A imagem já foi enviada.', #pt-CHECK - Please check and remove this comment
    ro => 'Această imagine a fost deja trimis.', #ro-CHECK - Please check and remove this comment
    th => 'ภาพนี้ได้ถูกส่งไป', #th-CHECK - Please check and remove this comment
    vi => 'Bức ảnh này đã được gửi đến.', #vi-CHECK - Please check and remove this comment
    zh => '这张照片已经送到。', #zh-CHECK - Please check and remove this comment

},

image_upload_error_image_too_small => {
	fr => "La photo est trop petite. Attention à ne pas envoyer de photos prises sur Internet. Merci de n'envoyer que vos propres photos.",
	en => "The picture is too small. Please do not upload pictures found on the Internet and only send photos you have taken yourself.",
	el => "Αυτη η εικονα είναι πολύ μικρή. Παρακαλούμε μην ανεβάζετε φωτογραφίες που αντλήσατε από το διαδίκτυο και στείλτε αποκλειστικά φωτογραφίες που τραβήξατε εσείς",
	de => "Das Foto ist zu klein. Bitte beachten Sie, dass Sie kein Foto aus dem Internet, sondern nur Ihre eigenen Fotos hochladen dürfen.",
	nl => "De foto is te klein. Stuur alsjeblieft geen foto's op, die je op Internet hebt gevonden. Upload alleen foto's, die je zelf hebt gemaakt.",
	nl_be => "De foto is te klein. Stuur alstublieft geen foto's op, die u op Internet heeft gevonden. Upload alleen foto's, die u zelf heeft gemaakt.",
},

product_add_nutrient => {
	fr => "Ajouter un nutriment",
	en => "Add a nutrient",
	da => 'Tilføj et næringsstof',
	el => "Προσθέστε ένα θρεπτικό συστατικό",
	es => "Añade un nutriente",
	pt => "Adicionar um nutriente",
	ro => "Adăugați un nutrient",
	nl => "Een voedingsstof toevoegen",
	nl_be => "Een voedingsstof toevoegen",
	de => "Nährstoff hinzufügen",
	zh => '添加营养成分',
},

product_changes_saved => {
	fr => "Les modifications ont été enregistrées.",
	en => "Changes saved.",
	el => "Οι αλλαγές αποθηκεύτηκαν",
	es => "Los cambios han sido guardados.",
	pt => "As modificações foram guardadas.",
	ro => "Schimbările au fost salvate.",
	he => "השינויים נשמרו.",
	nl => "De wijzigingen werden opgeslagen.",
	nl_be => "De wijzigingen werden opgeslagen.",
	de => "Veränderungen wurden gespeichert.",
	ru => 'Изменения сохранены.',
},

see_product_page => {

    ar => 'راجع صفحة المنتج', #ar-CHECK - Please check and remove this comment
	de => "Produktdetails ansehen",
    cs => 'Podívejte se na produktovou stránku', #cs-CHECK - Please check and remove this comment
	es => "Ver la página del producto",
	en => "See the product page",
    it => 'Vedere la pagina del prodotto', #it-CHECK - Please check and remove this comment
    fi => 'Katso tuotteen sivulle', #fi-CHECK - Please check and remove this comment
	fr => "Voir la fiche du produit",
	el => "Βλπ τη σελίδα του προϊόντος",
	he => "הצגת עמוד המוצר",
    ja => '製品ページを参照してください。', #ja-CHECK - Please check and remove this comment
    ko => '제품 페이지를 참조하십시오', #ko-CHECK - Please check and remove this comment
	nl => "De pagina van het product bekijken",
	nl_be => "De pagina van het product bekijken",
    ru => 'Смотрите страницу продукта', #ru-CHECK - Please check and remove this comment
    pl => 'Zobacz stronę produktu', #pl-CHECK - Please check and remove this comment
	pt => "Ver a página do produto",
	ro => "Vedeți pagina produsului",
    th => 'ดูหน้าสินค้า', #th-CHECK - Please check and remove this comment
    vi => 'Xem trang sản phẩm', #vi-CHECK - Please check and remove this comment
    zh => '看到产品页面', #zh-CHECK - Please check and remove this comment

},

products_with_nutriments => {
	fr => "avec informations<br/>nutritionnelles",
	en => "with nutrition facts",
	el => "με διατροφικά δεδομένα",
	es => "con información nutricional",
	pt => "com informacão nutricional",
	ro => "cu valori nutriționale",
	he => "עם מפרט תזונתי",
	nl => "met voedingswaarden",
	nl_be => "met nutritionele informatie",
	de => "mit Nährwertinformationen",
},

tagstable_search => {
	fr => "Recherche :",
	en => "Search:",
	el => "Αναζήτηση:",
	es => "Buscar:",
	pt => "Procurar:",
	ro => "Căutare:",
	he => "חיפוש:",
	nl => "Zoeken:",
	nl_be => "Zoeken:",
	de => "Suche:",
},

tagstable_filtered => {
	fr => "parmi _MAX_",
	en => "out of _MAX_",
	el => "από _MAX_",
	es => "fuera de _MAX_",
	pt => "de_MAX_",
	ro => "din _MAX_",
	he => "מתוך _MAX_",
	nl => "tussen _MAX_",
	nl_be => "tussen _MAX_",
	de => "auf _MAX_",
},

search_ingredients => {
	ar => 'المكونات', #ar-CHECK - Please check and remove this comment
	de => "Zutaten",
	cs => 'Složení', #cs-CHECK - Please check and remove this comment
	es => "Ingredientes",
	en => "Ingredients",
	it => 'Ingredienti', #it-CHECK - Please check and remove this comment
	fi => 'Ainekset', #fi-CHECK - Please check and remove this comment
	fr => "Ingrédients",
	el => "Συστατικά",
	he => "רכיבים",
	ja => '材料', #ja-CHECK - Please check and remove this comment
	ko => '성분', #ko-CHECK - Please check and remove this comment
	nl => "Ingrediënten",
	nl_be => "Ingrediënten",
	ru => 'Ингредиенты', #ru-CHECK - Please check and remove this comment
	pl => 'Składniki', #pl-CHECK - Please check and remove this comment
	pt => "Ingredientes",
	ro => "Ingrediente",
	th => 'ส่วนผสม', #th-CHECK - Please check and remove this comment
	vi => 'Thành phần', #vi-CHECK - Please check and remove this comment
	zh => '主料', #zh-CHECK - Please check and remove this comment

},

search_with => {
	fr => 'Avec',
	en => 'With',
	es => 'Con',
	de => 'Mit',
	el => "Με",
	pt => 'Com',
	ro => "Cu",
	he => 'עם',
	nl => "Met",
	nl_be => "Met",
},

search_without => {
	fr => 'Sans',
	en => 'Without',
	es => 'Sin',
	el => "Χωρίς",
	de => 'Ohne',
	pt => 'Sem',
	ro => "Fără",
	he => 'ללא',
	nl => "Zonder",
	nl_be => "Zonder",
},

search_indifferent => {
	fr => 'Indifférent',
	en => 'Indifferent',
	el => "Αδιάφορο",
	es => 'Indiferente',
	pt => 'Indiferente',
	ro => "Indiferent",
	he => 'ללא שינוי',
	nl => "Niet van belang",
	nl_be => "Onbepaald",
	de => "Gleichgültig",
},

products_you_edited => {
	fr => "Les produits que vous avez ajoutés ou modifiés",
	en => "Products you added or edited",
	da => 'Produkter, du har tilføjet eller redigeret',
	el => "Προϊόντα που προσθέσατε ή επεξεργαστήκατε",
	es => "Productos que has añadido o modificado",
	pt => "Produtos que adicionou ou editou",
	ro => "Produse adăugate sau modificate de dumneavoastră",
	he => "משתנים שהוספת או ערכת",
	nl => "De producten die je toegevoegd of aangepast hebt",
	nl_be => "De producten die u toegevoegd of aangepast heeft",
	de => "Produkte, die sie hinzugefûgt oder bearbeitet haben",
},

incomplete_products_you_added => {
	fr => "Les produits que vous avez ajoutés qui sont à compléter",
	en => "Products you added that need to be completed",
	el => "Προϊόντα που προσθέσατε και απαιτούν συμπλήρωση",
	es => "Productos añadidos por usted que necesitan ser completados",
	ro => "Produse adăugate de dumneavoastră care trebuie completate",
	pt => "Produtos adicionados por si que precisam de ser completados",
	nl => "Producten die je toegevoegd hebt en nog onvolledig zijn",
	nl_be => "Producten die u toegevoegd heeft en nog onvolledig zijn",
	de => "Von Ihnen hinzugefügte Produkte, die Weiterverarbeitung benötigen",
},

edit_settings => {
	fr => "Modifier les paramètres de votre compte",
	en => "Change your account parameters",
	el => "Αλλάξτε τις παραμέτρους του λογαριασμού σας",
	es => "Cambiar la configuración de la cuenta",
	pt => "Mudar os parâmetros da conta",
	ro => "Schimbați parametrii contului",
	he => "החלפת משתני החשבון שלך",
	nl => "Wijzig de parameters van je account",
	nl_be => "Wijzig de parameters van uw account",
	de => "Konteneinstellungen bearbeiten",
	ru => 'Изменить параметры вашей учётной записи',
},

list_of_x => {

    ar => 'قائمة %s', #ar-CHECK - Please check and remove this comment
	de => "Liste von %s",
    cs => 'Seznam %s', #cs-CHECK - Please check and remove this comment
	es => "Lista de %s",
	en => "List of %s",
    it => 'Elenco dei %s', #it-CHECK - Please check and remove this comment
    fi => 'Luettelo %s', #fi-CHECK - Please check and remove this comment
	fr => "Liste des %s",
	el => "Λίστα από %s",
	he => "רשימה של %s",
    ja => '%s一覧', #ja-CHECK - Please check and remove this comment
    ko => '%s 목록', #ko-CHECK - Please check and remove this comment
	nl => "Lijst van %s",
	nl_be => "Lijst van %s",
    ru => 'Список %s', #ru-CHECK - Please check and remove this comment
    pl => 'Lista %s', #pl-CHECK - Please check and remove this comment
	pt => "Lista de %s",
	ro => "Listă de %s",
    th => 'รายการ %s', #th-CHECK - Please check and remove this comment
    vi => 'Danh sách %s', #vi-CHECK - Please check and remove this comment
    zh => '%s 名单', #zh-CHECK - Please check and remove this comment

},

change_uploaded_images => {
	fr => "Images téléchargées",
	en => "Uploaded images",
	el => "Aνεβάστε εικόνες",
	es => "Imágenes subidas",
	pt => "Imagens enviadas",
	ro => "Imagini încărcate",
	he => "תמונות שהועלו",
	nl => "Geüploade foto's",
	nl_be => "Geüploade foto's",
	de => "Hochgeladene Fotos",
	ru => 'Загруженные изображения',
},

change_selected_images => {
	fr => "Images sélectionnées",
	en => "Selected images",
	el => "Επιλεγμενες εικονες",
	es => "Imágenes seleccionadas",
	pt => "Imagens selecionadas",
	ro => "Imagini selectate",
	he => "תמונות נבחרות",
	nl => "Geselecteerde foto's",
	nl_be => "Geselecteerde foto's",
	de => "Ausgewählte Fotos",
},

change_fields => {
	fr => "Informations",
	en => "Data",
	el => "Δεδομένα",
	es => "Informaciones",
	pt => "Informações",
	ro => "Date",
	he => "נתונים",
	nl => "Gegevens",
	nl_be => "Gegevens",
	de => "Informationen",
},

change_nutriments => {

    ar => 'اغذية', #ar-CHECK - Please check and remove this comment
	de => "Nährstoffe",
    cs => 'Živin', #cs-CHECK - Please check and remove this comment
	es => "Nutrientes",
	en => "Nutriments",
    it => 'Nutriments', #it-CHECK - Please check and remove this comment
    fi => 'Ravinteet', #fi-CHECK - Please check and remove this comment
	fr => "Nutriments",
	el => "Θρεπτικά συστατικά",
	he => "מפרט תזונתי",
    ja => '栄養素', #ja-CHECK - Please check and remove this comment
    ko => '영양물', #ko-CHECK - Please check and remove this comment
	nl => "Voedingsstoffen",
	nl_be => "Voedingsstoffen",
    ru => 'Питательные вещества', #ru-CHECK - Please check and remove this comment
    pl => 'Odżywcze', #pl-CHECK - Please check and remove this comment
	pt => "Nutrientes",
	ro => "Nutrienți",
    th => 'nutriments', #th-CHECK - Please check and remove this comment
    vi => 'Nguồn Thực Phẩm', #vi-CHECK - Please check and remove this comment
    zh => '营养素', #zh-CHECK - Please check and remove this comment

},

diff_add => {
	fr => 'Ajout :',
	en => 'Added:',
	el => "Προστέθηκε:",
	es => 'Añadido:',
	pt => 'Adicionado:',
	ro => "Adăugate:",
	he => 'נוסף:',
	nl => "Toevoeging:",
	nl_be => "Toevoeging:",
	de => "Neu:",
	zh => "已添加:",
	ru => 'Добавлено:',
},

diff_change => {
	fr => 'Changement :',
	en => 'Changed:',
    el => "Τροποποιήθηκε:",
	es => 'Cambiado:',
	pt => 'Alterado:',
	ro => "Schimbate:",
	he => 'השתנה:',
	nl => "Wijziging:",
	nl_be => "Wijziging:",
	de => "Verändert:",
	ru => 'Изменено:',
},

diff_delete => {
	fr => 'Suppression :',
	en => 'Deleted:',
    el => "Διαγράφηκε:",
	es => 'Eliminado:',
	pt => 'Alterado:',
	ro => "Șterse:",
	he => 'נמחק:',
	nl => "Verwijdering:",
	nl_be => "Verwijdering:",
	de => "Gelöscht:",
},


# states
state => {
	fr => 'Etat',
	en => 'State',
    el => "Κατάσταση",
	es => 'Estado',
	pt => 'Estado',
	ro => "Status",
	he => 'מצב',
	nl => "Status",
	nl_be => "Status",
	de => "Stand",
},

save => {

    ar => 'حفظ', #ar-CHECK - Please check and remove this comment
	de => "Speichern",
    cs => 'Save', #cs-CHECK - Please check and remove this comment
	es => "Guardar",
	en => "Save",
    it => 'Salva', #it-CHECK - Please check and remove this comment
    fi => 'Tallenna', #fi-CHECK - Please check and remove this comment
	fr => "Enregistrer",
    el => "Αποθήκευση",
	he => "שמירה",
    ja => '保存', #ja-CHECK - Please check and remove this comment
    ko => '저장', #ko-CHECK - Please check and remove this comment
	nl => "Opslaan",
	nl_be => "Opslaan",
    ru => 'Сохранить', #ru-CHECK - Please check and remove this comment
    pl => 'Zapisz', #pl-CHECK - Please check and remove this comment
	pt => "Salvar",
	ro => "Salvare",
    th => 'บันทึก', #th-CHECK - Please check and remove this comment
    vi => 'Lưu', #vi-CHECK - Please check and remove this comment
    zh => '保存', #zh-CHECK - Please check and remove this comment

},
saving => {
	fr => "Informations en cours d'enregistrement.",
	en => "Saving.",
    el => "Τα δεδομένα αποθηκεύονται.",
	es => "Los datos están siendo guardados",
	pt => "Os dados estão a ser guardados",
	ro => "Salvez.",
	he => "בהליכי שמירה.",
	nl => "De gegevens worden opgeslagen.",
	nl_be => "De gegevens worden opgeslagen.",
	de => "Daten werden gespeichert.",
},
saved => {
	fr => "Informations enregistrées.",
	en => "Saved.",
    el => "Τα δεδομένα έχουν αποθηκευτεί.",
	es => "Los datos han sido guardados.",
	pt => "Os dados foram guardados.",
	ro => "Salvat.",
	he => "השמירה הצליחה.",
	nl => "De gegevens werden opgeslagen.",
	nl_be => "De gegevens werden opgeslagen.",
	de => "Daten wurden gespeichert.",
},
not_saved => {
	fr => "Erreur d'enregistrement, merci de réessayer.",
	en => "Error while saving, please retry.",
    el => "Σφάλμα κατά την αποθήκευση, παρακαλώ προσπαθήστε πάλι.",
	es => "Se ha producido un error guardando los datos, por favor inténtelo de nuevo.",
	pt => "Ocorreu um erro ao guardar os dados, por favor tente de novo.",
	ro => "Eroare de salvare, vă rog reîncercați.",
	he => "אירעה שגיאה במהלך השמירה, נא לנסות שוב.",
	nl => "Fout tijdens het opslaan, gelieve opnieuw te proberen",
	nl_be => "Fout tijdens het opslaan, gelieve opnieuw te proberen",
	de => "Speicherproblem aufgetreten, bitte probieren Sie noch einmal .",
},

view => {
	fr => "voir",
	en => "view",
    el => "Βλέπε",
	es => "ver",
	pt => "ver",
	ro => "vedere",
	he => "צפייה",
	nl => "bekijken",
	nl_be => "bekijken",
	de => "ansehen",
},

no_product_for_barcode => {
	fr => "Il n'y a pas de produit référencé pour le code barre %s.",
	en => "No product listed for barcode %s.",
    el => "Δεν υπάρχει προϊόν με barcode %s",
	es => "No existe ningún producto con el código de barras %s.",
	pt => "Não existe nenhum produto com o código de barras %s.",
	ro => "Nici un produs listat pentru codul de bare %s",
	he => "לא נרשמו מוצרים על הברקוד %s",
	nl => "Er is geen product gevonden voor de barcode %s.",
	nl_be => "Er is geen product gevonden voor de barcode %s.",
	de => "Kein Produkt ist mit dem Barcode %s referenziert.",
},

products_stats => {
	fr => "Evolution du nombre de produits sur Open Food Facts",
	en => "Evolution of the number of products on Open Food Facts",
    el => "Εξέλιξη του αριθμού των προϊόντων στο Open Food Facts",
	es => "Evolución del número de productos en Open Food Facts",
	pt => "Evolução do número de produtos no Open Food Facts",
	ro => "Evoluția numărului de produse pe Open Food Facts",
	he => "התפתחות מספר המוצרים ב־Open Food Facts",
	nl => "Evolutie van het aantal producten op Open Food Facts",
	nl_be => "Evolutie van het aantal producten op Open Food Facts",
	de => "Entwicklung der Zahl von Produkten auf Open Food Facts",
},

products_stats_created_t => {

    ar => 'المنتجات', #ar-CHECK - Please check and remove this comment
	de => "Produkte",
    cs => 'Produkty', #cs-CHECK - Please check and remove this comment
	es => "Productos",
	en => "Products",
    it => 'Prodotti', #it-CHECK - Please check and remove this comment
    fi => 'Tuotteet', #fi-CHECK - Please check and remove this comment
	fr => "Produits",
    el => "Προϊόντα",
	he => "מוצרים",
    ja => 'プロダクト', #ja-CHECK - Please check and remove this comment
    ko => '제품', #ko-CHECK - Please check and remove this comment
	nl => "Producten",
	nl_be => "Producten",
    ru => 'Продукты', #ru-CHECK - Please check and remove this comment
    pl => 'Produkty', #pl-CHECK - Please check and remove this comment
	pt => "Produtos",
	ro => "Produse",
    th => 'ผลิตภัณฑ์', #th-CHECK - Please check and remove this comment
    vi => 'Sản phẩm', #vi-CHECK - Please check and remove this comment
    zh => '制品', #zh-CHECK - Please check and remove this comment
},

products_stats_completed_t => {
	fr => "Produits avec fiche complète",
	en => "Products with complete information",
	el => "Προϊόντα με πλήρως συμπληρωμένη πληροφορία",
	es => "Productos con los datos completados",
	pt => "Produtos com informação completa",
	ro => "Produse cu informații complete",
	he => "מוצרים עם פרטים מלאים",
	nl => "Producten met volledige informatie",
	nl_be => "Producten met volledige informatie",
	de => "Produkte mit vollständigen Informationen",
},


months => {
	fr => "['Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre']",
	da => "['Januar', 'Februar', 'Marts', 'April', 'Maj', 'Juni', 'Juli', 'August', 'September', 'Oktober', 'November', 'December']",
	en => "['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']",
	el => "['Ιανουάριος', 'Φεβρουάριος', 'Μάρτιος', 'Απρίλιος', 'Μάιος', 'Ιούνιος', 'Ιούλιος', 'Αύγουστος', 'Σεπτέμβριος', 'Οκτώβριος', 'Νοέμβριος', 'Δεκέμβριος']",
	es => "['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre']",
	pt => "['janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro']",
	ro => "['Ianuarie', 'Februarie', 'Martie', 'Aprilie', 'Mai', 'Iunie', 'Iulie', 'August', 'Septembrie', 'Octombrie', 'Noiembrie', 'Decembrie']",
	de => "['Januar', 'Februar', 'März', 'April', 'Mai', 'Juni', 'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember']",
	cs => "['Leden','Únor','Březen','Duben','Květen','Červen','Červenec','Srpen','Září','Říjen','Listopad','Prosinec']",
	zh => "['一月', '二月', '三月', '四月', '五月', '六月', '七月', '八月', '九月', '十月', '十一月', '十二月']",
	ja => "['一月', '二月', '三月', '四月', '五月', '六月', '七月', '八月', '九月', '十月', '十一月', '十二月']",
	he => "['ינואר','פברואר','מרץ','אפריל','מאי','יוני','יולי','אוגוס','ספטמבר','אוקטובר','נובמבר','דצמבר']",
	nl => "['Januari', 'Februari', 'Maart', 'April', 'Mei', 'Juni', 'Juli', 'Augustus', 'September', 'Oktober', 'November', 'December']",
	nl_be => "['Januari', 'Februari', 'Maart', 'April', 'Mei', 'Juni', 'Juli', 'Augustus', 'September', 'Oktober', 'November', 'December']",
	ru => "['Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь', 'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь']",
},

weekdays => {
	fr => "['Dimanche', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi']",
	el => "['Κυριακή', 'Δευτέρα', 'Τρίτη', 'Τετάρτη', 'Πέμπτη', 'Παρασκευή', 'Σάββατο']",
	en => "['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']",
	da => "['Søndag' 'Mandag', 'Tirsdag', 'Onsdag', 'Torsdag', 'Fredag', 'Lørdag']",
	es => "['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado']",
	pt => "['domingo', 'segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado']",
	ro => "['Duminică', 'Luni', 'Marți', 'Miercuri', 'Joi', 'Vineri', 'Sâmbătă']",
	de => "['Sonntag', 'Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag']",
	cs => "['Neděle','Pondělí','Úterý','Středa','Čtvrtek','Pátek','Sobota']",
	zh => "['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六']",
	ja => "['日曜日', '月曜日', '火曜日', '水曜日', '木曜日', '金曜日', '土曜日']",
	he => "['ראשון','שני','שלישי','רביעי','חמישי','שישי','שבת']",
	nl => "['Zondag', Maandag', 'Dinsdag', 'Woensdag', 'Donderdag', 'Vrijdag', 'Zaterdag']",
	nl_be => "['Zondag', Maandag', 'Dinsdag', 'Woensdag', 'Donderdag', 'Vrijdag', 'Zaterdag']",

},

# traffic lights for fat, sugars, salt etc.
nutrient_in_quantity => {
	en => '%s in %s',
	fr => '%s en %s',
	el => '%s σε %s',
	es => '%s en %s',
	pt => '%s em %s',
	ro => '%s în %s',
	he => '%s ב־%s',
	nl => '%s in %s',
	nl_be => '%s in %s',
	de => '%s in %s',
	ru => '%s в %s',
},
low => {
	en => "low",
	fr => "faible",
	el => 'χαμηλός',
	es => "bajo",
	pt => "baixo",
	ro => 'mic',
	he => "נמוכה",
	nl => "laag",
	nl_be => "laag",
	de => "gering",
},
low_quantity => {
	en => "low quantity",
	el => 'μικρή ποσότητα',
	fr => "faible quantité",
	es => "cantidad baja",
	pt => "quantidade baixa",
	ro => 'cantitate mică',
	he => "כמות נמוכה",
	nl => "kleine hoeveelheid",
	nl_be => "kleine hoeveelheid",
	de => "geringe Menge",
},
moderate => {
	en => "moderate",
	el => 'μέτριος',
	fr => "modéré",
	es => "moderado",
	pt => "moderado",
	ro => 'moderat',
	he => "בינונית",
	nl => "gemiddeld",
	nl_be => "gemiddeld",
	de => "durchschnittlich",
},
moderate_quantity => {

    ar => 'كمية معتدلة', #ar-CHECK - Please check and remove this comment
	de => "Durchschnittliche Menge",
    cs => 'mírné množství', #cs-CHECK - Please check and remove this comment
	es => "cantidad moderada",
	en => "moderate quantity",
    it => 'modica quantità', #it-CHECK - Please check and remove this comment
    fi => 'kohtalainen määrä', #fi-CHECK - Please check and remove this comment
	fr => "quantité modérée",
	el => 'μέτρια ποσότητα',
	he => "כמות בינונית",
    ja => '適度な量', #ja-CHECK - Please check and remove this comment
    ko => '적당한 양', #ko-CHECK - Please check and remove this comment
	nl => "gemiddelde hoeveelheid",
	nl_be => "gemiddelde hoeveelheid",
    ru => 'умеренное количество', #ru-CHECK - Please check and remove this comment
    pl => 'umiarkowana ilość', #pl-CHECK - Please check and remove this comment
	pt => "quantidade moderada",
	ro => "cantitate moderată",
    th => 'ปริมาณปานกลาง', #th-CHECK - Please check and remove this comment
    vi => 'số lượng vừa phải', #vi-CHECK - Please check and remove this comment
    zh => '数量适中', #zh-CHECK - Please check and remove this comment

},
high => {
	en => "high",
	el => 'υψηλός',
	fr => "élevé",
	es => "elevado",
	pt => "elevado",
	ro => "mare",
	he => "גדולה",
	nl => "hoog",
	nl_be => "hoog",
	de => "hoch",
},
high_quantity => {

    ar => 'كمية عالية', #ar-CHECK - Please check and remove this comment
	de => "große Menge",
    cs => 'vysoké množství', #cs-CHECK - Please check and remove this comment
	es => "cantidad elevada",
	en => "high quantity",
    it => 'elevata quantità', #it-CHECK - Please check and remove this comment
    fi => 'suuri määrä', #fi-CHECK - Please check and remove this comment
	fr => "quantité élevée",
	el => 'υψηλή ποσότητα',
	he => "כמות גדולה",
    ja => '多量', #ja-CHECK - Please check and remove this comment
    ko => '높은 양', #ko-CHECK - Please check and remove this comment
	nl => "grote hoeveelheid",
	nl_be => "grote hoeveelheid",
    ru => 'высокое количество', #ru-CHECK - Please check and remove this comment
    pl => 'wysoka ilość', #pl-CHECK - Please check and remove this comment
	pt => "quantidade elevada",
	ro => "cantitate mare",
    th => 'ปริมาณสูง', #th-CHECK - Please check and remove this comment
    vi => 'lượng cao', #vi-CHECK - Please check and remove this comment
    zh => '高量', #zh-CHECK - Please check and remove this comment

},

risk_level => {
	en => 'Risk',
	el => 'Κίνδυνος',
	fr => 'Risques',
	es => 'Riesgos',
	pt => 'Riscos',
	ro => 'Risc',
	he => 'סיכון',
	nl => "Risico's",
	nl_be => "Risico's",
	de => "Risiko",
},

risk_level_3 => {

    ar => 'مخاطر عالية', #ar-CHECK - Please check and remove this comment
	de => "Hohes Risiko",
    cs => 'Vysoké riziko', #cs-CHECK - Please check and remove this comment
	es => 'Riesgos elevados',
	en => 'High risks',
    it => 'Alti rischi', #it-CHECK - Please check and remove this comment
    fi => 'Korkea riski', #fi-CHECK - Please check and remove this comment
	fr => 'Risques élevés',
	el => 'Υψηλός κίνδυνος',
	he => 'סיכונים גבוהים',
    ja => '高リスク', #ja-CHECK - Please check and remove this comment
    ko => '높은 위험', #ko-CHECK - Please check and remove this comment
	nl => "Hoge risico's",
	nl_be => "Hoge risico's",
    ru => 'Высокие риски', #ru-CHECK - Please check and remove this comment
    pl => 'Wysokie ryzyko', #pl-CHECK - Please check and remove this comment
	pt => 'Riscos elevados',
	ro => 'Risc mare',
    th => 'ความเสี่ยงสูง', #th-CHECK - Please check and remove this comment
    vi => 'Rủi ro cao', #vi-CHECK - Please check and remove this comment
    zh => '高风险', #zh-CHECK - Please check and remove this comment
},

risk_level_2  => {

    ar => 'مخاطر معتدلة', #ar-CHECK - Please check and remove this comment
	de => "Mittleres Risiko",
    cs => 'Moderovat rizika', #cs-CHECK - Please check and remove this comment
	es => 'Riesgos moderados',
	en => 'Moderate risks',
    it => 'Rischi moderati', #it-CHECK - Please check and remove this comment
    fi => 'Kohtalainen riski', #fi-CHECK - Please check and remove this comment
	fr => 'Risques modérés',
	el => 'Μέτριος κίνδυνος',
	he => 'סיכונים בינוניים',
    ja => '中程度のリスク', #ja-CHECK - Please check and remove this comment
    ko => '보통 위험', #ko-CHECK - Please check and remove this comment
	nl => "Gemiddelde risico's",
	nl_be => "Gemiddelde risico's",
    ru => 'Умеренные риски', #ru-CHECK - Please check and remove this comment
    pl => 'Umiarkowane ryzyko', #pl-CHECK - Please check and remove this comment
	pt => 'Riscos moderados',
	ro => 'Risc moderat',
    th => 'ความเสี่ยงปานกลาง', #th-CHECK - Please check and remove this comment
    vi => 'Rủi ro vừa phải', #vi-CHECK - Please check and remove this comment
    zh => '中等风险', #zh-CHECK - Please check and remove this comment

},

risk_level_1  => {

    ar => 'مخاطر منخفضة', #ar-CHECK - Please check and remove this comment
	de => "Niedriges Risiko",
    cs => 'Nízké riziko', #cs-CHECK - Please check and remove this comment
	es => 'Riesgos bajos',
	en => 'Low risks',
    it => 'Rischi bassi', #it-CHECK - Please check and remove this comment
    fi => 'Matala riski', #fi-CHECK - Please check and remove this comment
	fr => 'Risques faibles',
	el => 'Χαμηλός κίνδυνος',
	he => 'סיכונים נמוכים',
    ja => '低リスク', #ja-CHECK - Please check and remove this comment
    ko => '낮은 위험', #ko-CHECK - Please check and remove this comment
	nl => "Lage risico's",
	nl_be => "Lage risico's",
    ru => 'Низкие риски', #ru-CHECK - Please check and remove this comment
    pl => 'Niskie ryzyko', #pl-CHECK - Please check and remove this comment
	pt => 'Riscos baixos',
	ro => 'Risc scăzut',
    th => 'ความเสี่ยงต่ำ', #th-CHECK - Please check and remove this comment
    vi => 'Rủi ro thấp', #vi-CHECK - Please check and remove this comment
    zh => '低风险', #zh-CHECK - Please check and remove this comment

},

risk_level_0  => {
	en => 'To be completed',
	el => 'Προς συμπλήρωση',
	fr => 'A renseigner',
	es => 'Para completar',
	pt => 'Para completar',
	ro => 'De completat',
	he => 'להשלמה',
	nl => "Aan te vullen",
	nl_be => "Te vervolledigen",
	de => "Auszufüllen",
},

select_country => {

    ar => 'بلد', #ar-CHECK - Please check and remove this comment
	de => "Land",
    cs => 'Země', #cs-CHECK - Please check and remove this comment
	es => 'País',
	en => 'Country',
    it => 'Paese', #it-CHECK - Please check and remove this comment
    fi => 'Maa', #fi-CHECK - Please check and remove this comment
	fr => 'Pays',
	el => 'Χώρα',
	he => 'מדינה',
    ja => 'カントリー', #ja-CHECK - Please check and remove this comment
    ko => '국가', #ko-CHECK - Please check and remove this comment
	nl => "Land",
	nl_be => "Land",
    ru => 'Страна', #ru-CHECK - Please check and remove this comment
    pl => 'Kraj', #pl-CHECK - Please check and remove this comment
	pt => 'País',
	ro => 'Țara',
    th => 'ประเทศ', #th-CHECK - Please check and remove this comment
    vi => 'Nước', #vi-CHECK - Please check and remove this comment
    zh => '国家', #zh-CHECK - Please check and remove this comment

},

select_lang => {

    ar => 'لغة', #ar-CHECK - Please check and remove this comment
    de => 'Sprache', #de-CHECK - Please check and remove this comment
    cs => 'Jazyk', #cs-CHECK - Please check and remove this comment
	es => 'Idioma',
	en => 'Language',
	it => 'Lingua',
    fi => 'Kieli', #fi-CHECK - Please check and remove this comment
	fr => 'Langue',
    el => 'Γλώσσα', #el-CHECK - Please check and remove this comment
    he => 'שפה',
    ja => '言語', #ja-CHECK - Please check and remove this comment
    ko => '언어', #ko-CHECK - Please check and remove this comment
    nl => 'Taal', #nl-CHECK - Please check and remove this comment
    nl_be => 'Taal', #nl-CHECK - Please check and remove this comment
    ru => 'Язык', #ru-CHECK - Please check and remove this comment
    pl => 'Język', #pl-CHECK - Please check and remove this comment
	pt => 'Idioma',
	ro => 'Limba',
    th => 'ภาษา', #th-CHECK - Please check and remove this comment
    vi => 'Ngôn ngữ', #vi-CHECK - Please check and remove this comment
    zh => '语言', #zh-CHECK - Please check and remove this comment

},


view_products_from_the_entire_world => {

    ar => 'عرض جميع المنتجات مطابقة من كل أنحاء العالم', #ar-CHECK - Please check and remove this comment
	de => "Entsprechende Produkte in der ganzen Welt anschauen",
    cs => 'Zobrazit všechny odpovídající produkty z celého světa', #cs-CHECK - Please check and remove this comment
	es => "Ver los productos de todo el mundo",
	en => "View matching products from the entire world",
	da => 'Vis matchende produkter fra hele verden',
    it => 'Guarda tutti i prodotti corrispondenti da tutto il mondo', #it-CHECK - Please check and remove this comment
    fi => 'Näytä kaikki vastaavat tuotteet koko muusta maailmasta', #fi-CHECK - Please check and remove this comment
	fr => "Voir les produits correspondants du monde entier",
	el => 'Δείτε αντίστοιχα προϊόντα από όλο τον κόσμο',
	he => "צפייה במוצרים תואמים מכל העולם",
    ja => '全世界からすべてのマッチした製品を見ます', #ja-CHECK - Please check and remove this comment
    ko => '전 세계에서 일치하는 모든 제품보기', #ko-CHECK - Please check and remove this comment
	nl => "Vergelijkbare producten uit de hele wereld bekijken",
	nl_be => "Overeenkomstige producten uit de hele wereld bekijken",
    ru => 'Просмотреть все соответствующие продукты со всего мира', #ru-CHECK - Please check and remove this comment
    pl => 'Zobacz wszystkie pasujące produkty z całego świata', #pl-CHECK - Please check and remove this comment
	pt => "Ver produtos de todo o mundo",
	ro => 'Vedeți produsele corespunzătoare din toată lumea',
    th => 'ดูผลิตภัณฑ์ทั้งหมดของการจับคู่จากทั่วโลก', #th-CHECK - Please check and remove this comment
    vi => 'Xem tất cả các sản phẩm phù hợp với từ toàn thế giới', #vi-CHECK - Please check and remove this comment
    zh => '查看所有匹配的产品从整个世界', #zh-CHECK - Please check and remove this comment

},

view_list_for_products_from_the_entire_world => {
	en => "View the list for matching products from the entire world",
	da => 'Vis listen for at matchede produkter fra hele verden',
	el => 'Δείτε τη λίστα αντίστοιχων προϊόντων από όλο τον κόσμο',
	es => "Ver la lista de los productos especificados de todo el mundo",
	fr => "Voir la liste pour les produits correspondants du monde entier",
	pt => "Ver lista de produtos correspondentes do mundo inteiro",
	ro => "Vedeți lista produselor corespunzătoare din toată lumea",
	he => "צפייה ברשימה של מוצרים תואמים מכל העולם",
	nl => "De lijst met vergelijkbare producten uit de hele wereld bekijken",
	nl_be => "De lijst met overeenkomstige producten uit de hele wereld bekijken",
	de => "Liste von entsprechenden Produkten in der ganzen Welt anschauen",
},

view_results_from_the_entire_world => {

    ar => 'عرض النتائج من كل أنحاء العالم', #ar-CHECK - Please check and remove this comment
	de => "Weltweite Ergebnisse anschauen",
    cs => 'Zobrazit výsledky z celého světa', #cs-CHECK - Please check and remove this comment
	es => "Ver los resultados de todo el mundo",
	en => "View results from the entire world",
	da => 'Vis resultater fra hele verden',
    it => 'Visualizza i risultati di tutto il mondo', #it-CHECK - Please check and remove this comment
    fi => 'Näytä tulokset koko maailmasta', #fi-CHECK - Please check and remove this comment
	fr => "Voir les résultats du monde entier",
	el => 'Δείτε αποτελέσματα από όλο τον κόσμο',
	he => "צפייה בתוצאות מכל העולם",
    ja => '全世界からの眺め結果', #ja-CHECK - Please check and remove this comment
    ko => '전 세계에서보기 결과', #ko-CHECK - Please check and remove this comment
	nl => "De resultaten van de hele wereld bekijken",
	nl_be => "De resultaten van de hele wereld bekijken",
    ru => 'Посмотреть результаты со всего мира', #ru-CHECK - Please check and remove this comment
    pl => 'Zobacz wyniki z całego świata', #pl-CHECK - Please check and remove this comment
	pt => "Ver resultados de todo o mundo",
	ro => "Vedeți rezultatele din toată lumea",
    th => 'ผลการมุมมองจากคนทั้งโลก', #th-CHECK - Please check and remove this comment
    vi => 'Xem kết quả từ toàn thế giới', #vi-CHECK - Please check and remove this comment
    zh => '从整个世界的查看结果', #zh-CHECK - Please check and remove this comment

},

explore_products_by => {

    ar => 'الكشف إلى المنتجات...', #ar-CHECK - Please check and remove this comment
	de => "Produkte nach Kriterium anzeigen...",
    cs => 'Rozpis do výrobků...', #cs-CHECK - Please check and remove this comment
	es => "Explorar los productos por...",
	en => "Drilldown into products by...",
    it => 'Drill-down nei prodotti da...', #it-CHECK - Please check and remove this comment
    fi => 'Yksityiskohtien tarkastelu osaksi tuotteet...', #fi-CHECK - Please check and remove this comment
	fr => "Explorer les produits par...",
	el => 'Δείτε προϊόντα ανά...',
    he => 'חקירת מוצרים לפי…',
    ja => 'によって製品にドリルダウン...', #ja-CHECK - Please check and remove this comment
    ko => '에 의해 제품에 드릴...', #ko-CHECK - Please check and remove this comment
	nl => "Doorzoek de producten volgens...",
	nl_be => "Doorzoek de producten volgens...",
    ru => 'Развернутый в продукты с...', #ru-CHECK - Please check and remove this comment
    pl => 'Drążenia do produktów...', #pl-CHECK - Please check and remove this comment
	pt => "Explorar os produtos por...",
	ro => "Explorați produsele după...",
    th => 'เจาะลึกลงไปในผลิตภัณฑ์โดย...', #th-CHECK - Please check and remove this comment
    vi => 'Drilldown thành các sản phẩm của...', #vi-CHECK - Please check and remove this comment
    zh => '钻取到的产品通过...', #zh-CHECK - Please check and remove this comment

},

show_category_stats => {
	en => "Show detailed stats",
	el => 'Δείξε λεπτομερή στατιστικά',
	es => "Mostrar las informaciones estadísticas",
	fr => "Afficher les informations statistiques",
	pt => "Mostrar estatísticas detalhadas",
	ro => "Arată statistici detaliate",
	nl => "De gedetailleerde statistieken weergeven",
	nl_be => "De gedetailleerde statistieken weergeven",
	de => "Detaillierte Statistiken anzeigen",
},

show_category_stats_details => {
	en => "standard deviation, minimum, maximum, 10th and 90th percentiles",
	el => 'τυπική απόκλιση, ελάχιστο, μέγιστο, 10ο και 90ο εκατοστημόριο',
	es => "desviación estándar, mínimo, máximo, percentiles 10 y 90",
	pt => "desvio padrão, mínimo, máximo, 10<sup>o</sup> percentil e 90<sup>o</sup>",
	ro => "deviația standard, minimum, maximum, al 10-lea și al 90-lea procent",
	fr => "écart type, minimum, maximum, 10ème et 90ème centiles",
	nl => "standaardafwijking, minimum, maximum, 10e en 90e percentiel",
	nl_be => "standaardafwijking, minimum, maximum, 10e en 90e percentiel",
	de => "Standardabweichung, Minimum, Maximum, 10. und 90. Quantil",
},

names => {
	en => "Names",
	el => 'Ονόματα',
	fr => "Noms",
	es => "Nombres",
	de => "Namen",
	pt => "Nomes",
	ro => "Nume",
	nl => "Namen",
	nl_be => "Namen",
},

css => {
	fr => <<CSS
CSS
,
	es => <<CSS
CSS

,
el => <<CSS
CSS
,

	nl => <<CSS
CSS
,
	nl_be => <<CSS
CSS
,
	en => <<CSS
CSS
,
	pt => <<CSS
CSS
,
	ro => <<CSS
CSS
,
	de => <<CSS
CSS
,
},

header => {
	fr => <<HEADER
<meta property="fb:admins" content="706410516" />
<meta property="og:site_name" content="Open Food Facts - l'information alimentaire ouverte"/>

<script type="text/javascript">
  var uvOptions = {};
  (function() {
	var uv = document.createElement('script'); uv.type = 'text/javascript'; uv.async = true;
	uv.src = ('https:' == document.location.protocol ? 'https://' : 'http://') + 'widget.uservoice.com/Mjjw72JUjigdFxd4qo6wQ.js';
	var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(uv, s);
  })();
</script>
HEADER
,
	en => <<HEADER
<meta property="fb:admins" content="706410516" />
<meta property="og:site_name" content="Open Food Facts - the free and open food products information database"/>

<script type="text/javascript">
  var uvOptions = {};
  (function() {
	var uv = document.createElement('script'); uv.type = 'text/javascript'; uv.async = true;
	uv.src = ('https:' == document.location.protocol ? 'https://' : 'http://') + 'widget.uservoice.com/jQrwafQ94nbEbRWsznm6Q.js';
	var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(uv, s);
  })();
</script>


HEADER
,
	es => <<HEADER
<meta property="fb:admins" content="706410516" />
<meta property="og:site_name" content="Open Food Facts - la información alimentaria libre"/>

<script type="text/javascript">
  var uvOptions = {};
  (function() {
	var uv = document.createElement('script'); uv.type = 'text/javascript'; uv.async = true;
	uv.src = ('https:' == document.location.protocol ? 'https://' : 'http://') + 'widget.uservoice.com/jQrwafQ94nbEbRWsznm6Q.js';
	var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(uv, s);
  })();
</script>


HEADER
,

el => <<HEADER
<meta property="fb:admins" content="706410516" />
<meta property="og:site_name" content="Open Food Facts - informações abertas de alimentos"/>

<script type="text/javascript">
  var uvOptions = {};
  (function() {
	var uv = document.createElement('script'); uv.type = 'text/javascript'; uv.async = true;
	uv.src = ('https:' == document.location.protocol ? 'https://' : 'http://') + 'widget.uservoice.com/jQrwafQ94nbEbRWsznm6Q.js';
	var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(uv, s);
  })();
</script>


HEADER
,
	ro => <<HEADER
<meta property="fb:admins" content="706410516" />
<meta property="og:site_name" content="Open Food Facts - baza de date liberă și deschisă cu informații despre produse alimentare"/>

<script type="text/javascript">
  var uvOptions = {};
  (function() {
	var uv = document.createElement('script'); uv.type = 'text/javascript'; uv.async = true;
	uv.src = ('https:' == document.location.protocol ? 'https://' : 'http://') + 'widget.uservoice.com/jQrwafQ94nbEbRWsznm6Q.js';
	var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(uv, s);
  })();
</script>


HEADER
,
	nl => <<HEADER
<meta property="fb:admins" content="706410516" />
<meta property="og:site_name" content="Open Food Facts - de vrije databank voor voedingsmiddelen"/>

<script type="text/javascript">
  var uvOptions = {};
  (function() {
	var uv = document.createElement('script'); uv.type = 'text/javascript'; uv.async = true;
	uv.src = ('https:' == document.location.protocol ? 'https://' : 'http://') + 'widget.uservoice.com/Mjjw72JUjigdFxd4qo6wQ.js';
	var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(uv, s);
  })();
</script>
HEADER
,
	nl_be => <<HEADER
<meta property="fb:admins" content="706410516" />
<meta property="og:site_name" content="Open Food Facts - de vrije databank voor voedingsmiddelen"/>

<script type="text/javascript">
  var uvOptions = {};
  (function() {
	var uv = document.createElement('script'); uv.type = 'text/javascript'; uv.async = true;
	uv.src = ('https:' == document.location.protocol ? 'https://' : 'http://') + 'widget.uservoice.com/Mjjw72JUjigdFxd4qo6wQ.js';
	var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(uv, s);
  })();
</script>
HEADER
,
	de => <<HEADER
<meta property="fb:admins" content="706410516" />
<meta property="og:site_name" content="Open Food Facts - die offene und kostenlose Nahrungsinformationsdatenbank"/>

<script type="text/javascript">
  var uvOptions = {};
  (function() {
	var uv = document.createElement('script'); uv.type = 'text/javascript'; uv.async = true;
	uv.src = ('https:' == document.location.protocol ? 'https://' : 'http://') + 'widget.uservoice.com/Mjjw72JUjigdFxd4qo6wQ.js';
	var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(uv, s);
  })();
</script>
HEADER
,
},


menu => {
	fr => <<HTML
<ul>
<li><a href="/a-propos" title="En savoir plus sur Open Food Facts">A propos</a></li>
<li><a href="/mode-d-emploi" title="Pour bien démarrer en deux minutes">Mode d'emploi</a></li>
<li><a href="/contact" title="Des questions, remarques ou suggestions ?">Contact</a></li>
</ul>
HTML
,
	en => <<HTML
<ul>
<li><a href="/about" title="More info about Open Food Facts">About</a></li>
<li><a href="/quickstart-guide" title="How to add products in 2 minutes">Quickstart guide</a></li>
<li><a href="/contact" title="Questions, comments or suggestions?">Contact</a></li>
</ul>
HTML
,
el => <<HTML
<ul>
<li><a href="/about" title="More info about Open Food Facts">About</a></li>
<li><a href="/quickstart-guide" title="How to add products in 2 minutes">Quickstart guide</a></li>
<li><a href="/contact" title="Questions, comments or suggestions?">Contact</a></li>
</ul>
HTML
,
	es => <<HTML
<ul>
<li><a href="/acerca-de" title="Más información acerca de Open Food Facts">Acerca de</a></li>
<li><a href="/guia-de-inicio-rapido" title="Cómo añadir productos en 2 minutos">Guía de inicio rápido</a></li>
<li><a href="/contacto" title="Preguntas, comentarios o sugerencias?">Contacto</a></li>
</ul>
HTML
,
	he => <<HTML
<ul>
<li><a href="/about" title="מידע נוסף על Open Food Facts">על אודות</a></li>
<li><a href="/quickstart-guide" title="איך להוסיף מוצרים ב־2 דקות">מדריך זריז למתחילים</a></li>
<li><a href="/contact" title="שאלותת הערות או הצעות??">יצירת קשר</a></li>
</ul>
HTML
,
	pt => <<HTML
<ul>
<li><a href="/about" title="Mais informação sobre o Open Food Facts">Acerca de</a></li>
<li><a href="/quickstart-guide" title="Como adicionar produtos em 2 minutos">Guia de início rápido</a></li>
<li><a href="/contact" title="Perguntas, comentários ou sugestões?">Contacto</a></li>
</ul>
HTML
,
	ro => <<HTML
<ul>
<li><a href="/about" title="Mai multe informații despre Open Food Facts">About</a></li>
<li><a href="/quickstart-guide" title="Cum să adăugați produse în 2 minute">Ghid de start rapid</a></li>
<li><a href="/contact" title="Întrebări, comentarii sau sugestii?">Contact</a></li>
</ul>
HTML
,
	nl => <<HTML
<ul>
<li><a href="/a-propos" title="Meer weten over Open Food Facts">A propos</a></li>
<li><a href="/mode-d-emploi" title="Hoe producten toevoegen in twee minuten">Gebruiksaanwijzing</a></li>
<li><a href="/contact" title="Vragen, opmerkingen of suggesties?">Contact</a></li>
</ul>
HTML
,
	nl_be => <<HTML
<ul>
<li><a href="/a-propos" title="Meer weten over Open Food Facts">A propos</a></li>
<li><a href="/mode-d-emploi" title="Hoe producten toevoegen in twee minuten">Gebruiksaanwijzing</a></li>
<li><a href="/contact" title="Vragen, opmerkingen of suggesties?">Contact</a></li>
</ul>
HTML
,

	de => <<HTML
<ul>
<li><a href="/a-propos" title="Mehr über Open Food Facts erfahren">A propos</a></li>
<li><a href="/mode-d-emploi" title="In knapp 2 Minuten einfach starten">Benutzung</a></li>
<li><a href="/contact" title="Fragen, Bemerkungen oder Hinweise?">Kontakt</a></li>
</ul>
HTML
,
},

tagline => {

    ar => 'Open Food Facts بجمع المعلومات والبيانات على المنتجات الغذائية من جميع أنحاء العالم.', #ar-CHECK - Please check and remove this comment
	de => "Open Food Facts erfasst Nahrungsmittel aus der ganzen Welt.",
    cs => 'Open Food Facts shromažďuje informace a údaje o potravinářské výrobky z celého světa.', #cs-CHECK - Please check and remove this comment
	es => "Open Food Facts recopila información sobre los productos alimenticios de todo el mundo.",
	en => "Open Food Facts gathers information and data on food products from around the world.",
    it => 'Open Food Facts raccoglie informazioni e dati sui prodotti alimentari provenienti da tutto il mondo.', #it-CHECK - Please check and remove this comment
    fi => 'Open Food Facts kerää tietoja elintarvikkeiden tuotteita ympäri maailmaa.', #fi-CHECK - Please check and remove this comment
	fr => "Open Food Facts répertorie les produits alimentaires du monde entier.",
	el => "Το Open Food Facts συγκεντρώνει πληροφορίες και δεδομένα για τρόφιμα από όλο τον κόσμο.",
	he => "המיזם Open Food Facts אוסף מידע ונתונים על מוצרי מזון מכל רחבי העולם.",
    ja => 'Open Food Facts は、世界中から食料品の情報やデータを収集します。', #ja-CHECK - Please check and remove this comment
    ko => 'Open Food Facts 은 세계 각국에서 식품 제품에 대한 정보와 데이터를 수집합니다.', #ko-CHECK - Please check and remove this comment
	nl => "Open Food Facts inventariseert alle voedingsmiddelen uit de hele wereld.",
	nl_be => "Open Food Facts inventariseert alle voedingsmiddelen uit de hele wereld.",
    ru => 'Open Food Facts собирает информацию и данные о пищевых продуктах по всему миру.', #ru-CHECK - Please check and remove this comment
    pl => 'Open Food Facts gromadzi informacje i dane dotyczące produktów spożywczych z całego świata.', #pl-CHECK
    pt => "O Open Food Facts coleciona informação de produtos alimentares de todo o mundo.",
	ro => "Open Food Facts adună informații și date despre produse alimentare din întreaga lume.",
    th => 'Open Food Facts รวบรวมข้อมูลและข้อมูลเกี่ยวกับผลิตภัณฑ์อาหารจากทั่วโลก', #th-CHECK - Please check and remove this comment
    vi => 'Open Food Facts tập hợp thông tin và dữ liệu về các sản phẩm thực phẩm từ khắp nơi trên thế giới.', #vi-CHECK - Please check and remove this comment
    zh => 'Open Food Facts 来自世界各地收集有关食品的信息和数据。', #zh-CHECK - Please check and remove this comment

},

column_obsolete_do_not_translate_for_reference_only => {

	fr => <<HTML
<a href="/"><img id="logo" src="/images/misc/openfoodfacts-logo-fr.png" width="178" height="141" alt="Open Food Facts" /></a>

<p>Open Food Facts répertorie les produits alimentaires du monde entier.</p>

<select_country>

<p>
→ <a href="/marques">Marques</a><br />
→ <a href="/categories">Catégories</a><br/>
→ <a href="/additifs">Additifs</a><br/>
</p>

<p>
Les informations sur les aliments
sont collectées de façon collaborative et mises à disposition de tous
dans une base de données ouverte et gratuite.</p>

<p>Application mobile disponible pour iPhone et iPad sur l'App Store :</p>

<a href="https://itunes.apple.com/fr/app/open-food-facts/id588797948"><img src="/images/misc/Available_on_the_App_Store_Badge_FR_135x40.png" alt="Disponible sur l'App Store" width="135" height="40" /></a><br/>

<p>pour Android sur Google Play :</p>

<a href="https://play.google.com/store/apps/details?id=org.openfoodfacts.scanner"><img src="/images/misc/android-app-on-google-play-en_app_rgb_wo_135x47.png" alt="Disponible sur Google Play" width="135" height="47" /></a><br/>
<a href="http://world.openfoodfacts.org/files/off.apk">apk</a>

<p>pour Windows Phone :</p>

<a href="http://www.windowsphone.com/fr-fr/store/app/openfoodfacts/5d7cf939-cfd9-4ac0-86d7-91b946f4df34"><img src="/images/misc/154x40_WP_Store_blk.png" alt="Windows Phone Store" width="154" height="40" /></a><br/>

<br/>

<p>Retrouvez-nous aussi sur :</p>

<p>
→ <a href="http://fr.wiki.openfoodfacts.org">le wiki</a><br />
→ <a href="http://twitter.com/openfoodfactsfr">Twitter</a><br/>
→ <a href="https://plus.google.com/u/0/b/102622509148794386660/102622509148794386660/">Google+</a><br />
→ <a href="https://www.facebook.com/OpenFoodFacts.fr">Facebook</a><br />
+ <a href="https://www.facebook.com/groups/356858984359591/">groupe des contributeurs</a><br />
→ <a href="mailto:off-fr-subscribe\@openfoodfacts.org">envoyez un e-mail vide</a> pour
vous abonner à la liste de discussion<br/>
</p>

<br />
HTML
,

	en => <<HTML
<a href="/"><img id="logo" src="/images/misc/openfoodfacts-logo-en.png" width="178" height="144" alt="Open Food Facts" /></a>

<p>Open Food Facts gathers information and data on food products from around the world.</p>

<select_country>

<p>
→ <a href="/brands">Brands</a><br />
→ <a href="/categories">Categories</a><br/>
</p>

<p>Food product information (photos, ingredients, nutrition facts etc.) is collected in a collaborative way
and is made available to everyone and for all uses in a free and open database.</p>


<p>Find us also on:</p>

<p>
→ <a href="http://en.wiki.openfoodfacts.org">our wiki</a><br />
→ <a href="http://twitter.com/openfoodfacts">Twitter</a><br/>
→ <a href="https://plus.google.com/u/0/110748322211084668559/">Google+</a><br />
→ <a href="https://www.facebook.com/OpenFoodFacts">Facebook</a><br />
+ <a href="https://www.facebook.com/groups/374350705955208/">contributors group</a><br />
</p>

<p>iPhone and iPad app on the App Store:</p>

<a href="https://itunes.apple.com/en/app/open-food-facts/id588797948"><img src="/images/misc/Available_on_the_App_Store_Badge_EN_135x40.png" alt="Available on the App Store" width="135" height="40" /></a><br/>

<p>Android app on Google Play:</p>

<a href="https://play.google.com/store/apps/details?id=org.openfoodfacts.scanner"><img src="/images/misc/android-app-on-google-play-en_app_rgb_wo_135x47.png" alt="Available on Google Play" width="135" height="47" /></a><br/>
<a href="http://world.openfoodfacts.org/files/off.apk">apk</a>

<p>Windows Phone app:</p>

<a href="http://www.windowsphone.com/en-us/store/app/openfoodfacts/5d7cf939-cfd9-4ac0-86d7-91b946f4df34"><img src="/images/misc/154x40_WP_Store_blk.png" alt="Windows Phone Store" width="154" height="40" /></a><br/>


HTML
,

el => <<HTML
<a href="/"><img id="logo" src="/images/misc/openfoodfacts-logo-en.png" width="178" height="144" alt="Open Food Facts" /></a>

<p>Το Open Food Facts συγκεντρώνει πληροφορίες και δεδομένα για τρόφιμα από όλο τον κόσμο. </p>

<select_country>

<p>
→ <a href="/brands">Brands</a><br />
→ <a href="/categories">Categories</a><br/>
</p>

<p> Οι πληροφορίες για κάθε προϊόν (φωτογραφίες, σύσταση, θρεπτικά συστατικά κλπ.) συγκεντρώνονται συλλογικά και είναι διαθέσιμα ελεύθερα σε όλους για οποιαδήποτε χρήση με τη μορφή ελεύθερης και ανοιχτής βάσης δεδομένων. </p>


<p>Βρείτε μας επίσης σε:</p>

<p>
→ <a href="http://en.wiki.openfoodfacts.org">our wiki</a><br />
→ <a href="http://twitter.com/openfoodfacts">Twitter</a><br/>
→ <a href="https://plus.google.com/u/0/110748322211084668559/">Google+</a><br />
→ <a href="https://www.facebook.com/OpenFoodFacts">Facebook</a><br />
+ <a href="https://www.facebook.com/groups/374350705955208/">contributors group</a><br />
</p>

<p>iPhone and iPad app στο App Store:</p>

<a href="https://itunes.apple.com/en/app/open-food-facts/id588797948"><img src="/images/misc/Available_on_the_App_Store_Badge_EN_135x40.png" alt="Available on the App Store" width="135" height="40" /></a><br/>

<p>Android app στο Google Play:</p>

<a href="https://play.google.com/store/apps/details?id=org.openfoodfacts.scanner"><img src="/images/misc/android-app-on-google-play-en_app_rgb_wo_135x47.png" alt="Available on Google Play" width="135" height="47" /></a><br/>
<a href="http://world.openfoodfacts.org/files/off.apk">apk</a>

<p>Windows Phone app:</p>

<a href="http://www.windowsphone.com/en-us/store/app/openfoodfacts/5d7cf939-cfd9-4ac0-86d7-91b946f4df34"><img src="/images/misc/154x40_WP_Store_blk.png" alt="Windows Phone Store" width="154" height="40" /></a><br/>


HTML
,

# Arabic

ar => <<HTML
<a href="/"><img id="logo" src="/images/misc/openfoodfacts-logo-ar.png" width="178" height="148" alt="Open Food Facts" /></a>

<p>Open Food Facts gathers information and data on food products from around the world.</p>

<select_country>

<p>
→ <a href="/brands">Brands</a><br />
→ <a href="/categories">Categories</a><br/>
</p>

<p>Food product information (photos, ingredients, nutrition facts etc.) is collected in a collaborative way
and is made available to everyone and for all uses in a free and open database.</p>

<p>Find us also on:</p>

<p>
→ <a href="http://en.wiki.openfoodfacts.org">our wiki</a><br />
→ <a href="http://twitter.com/openfoodfacts">Twitter</a><br/>
→ <a href="https://plus.google.com/u/0/110748322211084668559/">Google+</a><br />
→ <a href="https://www.facebook.com/OpenFoodFacts">Facebook</a><br />
+ <a href="https://www.facebook.com/groups/374350705955208/">contributors group</a><br />
</p>

<p>iPhone and iPad app on the App Store:</p>

<a href="https://itunes.apple.com/en/app/open-food-facts/id588797948"><img src="/images/misc/Available_on_the_App_Store_Badge_EN_135x40.png" alt="Available on the App Store" width="135" height="40" /></a><br/>

<p>Android app on Google Play:</p>

<a href="https://play.google.com/store/apps/details?id=org.openfoodfacts.scanner"><img src="/images/misc/android-app-on-google-play-en_app_rgb_wo_135x47.png" alt="Available on Google Play" width="135" height="47" /></a><br/>
<a href="http://world.openfoodfacts.org/files/off.apk">apk</a>

<p>Windows Phone app:</p>

<a href="http://www.windowsphone.com/en-us/store/app/openfoodfacts/5d7cf939-cfd9-4ac0-86d7-91b946f4df34"><img src="/images/misc/154x40_WP_Store_blk.png" alt="Windows Phone Store" width="154" height="40" /></a><br/>


HTML
,

	de => <<HTML
<a href="/"><img id="logo" src="/images/misc/openfoodfacts-logo-de.png" width="178" height="142" alt="Open Food Facts" /></a>

<p>Open Food Facts erfasst Nahrungsmittel aus der ganzen Welt.</p>

<select_country>

<p>
→ <a href="/marken">Marken</a><br />
→ <a href="/kategorien">Kategorien</a><br/>
</p>

<p>
Die Informationen über die Produkte (Fotos, Inhaltsstoffe, Zusammensetzung, etc.) werden gemeinsam gesammelt, für alle frei zugänglich gemacht und können danach für jegliche Nutzung verwendet werden. Die Datenbank ist offen, frei und gratis.</p>


<p>Wir sind auch zu finden auf:</p>

<p>
→ <a href="http://en.wiki.openfoodfacts.org">our wiki</a><br />
→ <a href="http://twitter.com/openfoodfactsde">Twitter</a><br/>
→ <a href="https://plus.google.com/u/0/110748322211084668559/">Google+</a><br />
→ <a href="https://www.facebook.com/OpenFoodFacts">Facebook</a><br />
+ <a href="https://www.facebook.com/groups/488163711199190/">Gruppe der Unterstützer</a><br />
</p>


<p>iPhone and iPad app on the App Store:</p>

<a href="https://itunes.apple.com/en/app/open-food-facts/id588797948"><img src="/images/misc/Available_on_the_App_Store_Badge_EN_135x40.png" alt="Available on the App Store" width="135" height="40" /></a><br/>

<p>Android app on Google Play:</p>

<a href="https://play.google.com/store/apps/details?id=org.openfoodfacts.scanner"><img src="/images/misc/android-app-on-google-play-en_app_rgb_wo_135x47.png" alt="Available on Google Play" width="135" height="47" /></a><br/>
<a href="http://world.openfoodfacts.org/files/off.apk">apk</a>

<p>Windows Phone app:</p>

<a href="http://www.windowsphone.com/en-us/store/app/openfoodfacts/5d7cf939-cfd9-4ac0-86d7-91b946f4df34"><img src="/images/misc/154x40_WP_Store_blk.png" alt="Windows Phone Store" width="154" height="40" /></a><br/>

HTML
,

	es => <<HTML
<a href="/"><img id="logo" src="/images/misc/openfoodfacts-logo-es.png" width="178" height="141" alt="Open Food Facts" /></a>

<p>Open Food Facts recopila información sobre los productos alimenticios de todo el mundo.</p>

<select_country>

<p>
→ <a href="/marcas">Marcas</a><br />
→ <a href="/categorias">Categorías</a><br/>
</p>

<p>
La información sobre los alimentos (imágenes, ingredientes, composición nutricional etc.)
se reúne de forma colaborativa y es puesta a disposición de todo el mundo
para cualquier uso en una base de datos abierta, libre y gratuita.
</p>


<p>Puedes encontrarnos también en :</p>

<p>
→ <a href="http://en.wiki.openfoodfacts.org">Nuestra wiki (inglés)</a><br />
→ <a href="http://twitter.com/openfoodfactses">Twitter</a><br/>
→ <a href="https://plus.google.com/u/0/b/102622509148794386660/">Google+</a><br />
→ <a href="https://www.facebook.com/OpenFoodFacts.fr">Facebook (en francés)</a><br />
+ <a href="https://www.facebook.com/groups/470069256354172/">Grupo de los contribuidores en Facebook (en español)</a><br />
</p>


<p>Aplicación para móviles disponible para iPhone e iPad en la App Store:</p>

<a href="https://itunes.apple.com/en/app/open-food-facts/id588797948"><img src="/images/misc/Available_on_the_App_Store_Badge_EN_135x40.png" alt="Disponible en la App Store" width="135" height="40" /></a><br/>

<p>para Android en Google Play:</p>

<a href="https://play.google.com/store/apps/details?id=org.openfoodfacts.scanner"><img src="/images/misc/android-app-on-google-play-en_app_rgb_wo_135x47.png" alt="Disponible en Google Play" width="135" height="47" /></a><br/>
<a href="http://world.openfoodfacts.org/files/off.apk">apk</a>

<p>para Windows Phone:</p>

<a href="http://www.windowsphone.com/en-us/store/app/openfoodfacts/5d7cf939-cfd9-4ac0-86d7-91b946f4df34"><img src="/images/misc/154x40_WP_Store_blk.png" alt="Windows Phone Store" width="154" height="40" /></a><br/>


HTML
,

#PT-BR

	pt => <<HTML
<a href="/"><img id="logo" src="/images/misc/openfoodfacts-logo-pt.png" width="178" height="143" alt="Open Food Facts" /></a>

<p>O Open Food Facts coleciona informação de produtos alimentares de todo o mundo.</p>

<select_country>

<p>
→ <a href="/marcas">Marcas</a><br />
→ <a href="/categorias">Categorias</a><br/>
</p>

<p>Informações de produtos alimentares (fotos, ingredientes, informações nutricionais etc.) são coletadas de forma colaborativa e são disponibilizadas para todas as pessoas e para todos os usos em uma base de dados livre e aberta.</p>

<p>Encontre-nos também em:</p>

<p>
→ <a href="http://en.wiki.openfoodfacts.org">nossa wiki</a><br />
→ <a href="http://twitter.com/openfoodfacts">Twitter</a><br/>
→ <a href="https://plus.google.com/u/0/110748322211084668559/">Google+</a><br />
→ <a href="https://www.facebook.com/OpenFoodFacts">Facebook</a><br />
+ <a href="https://www.facebook.com/groups/420574551372737/">grupo de colaboradores</a><br />
</p>

<p>Aplicativo para iPhone e iPad na App Store:</p>

<a href="https://itunes.apple.com/en/app/open-food-facts/id588797948"><img src="/images/misc/Available_on_the_App_Store_Badge_EN_135x40.png" alt="Available on the App Store" width="135" height="40" /></a><br/>

<p>Aplicativo Android no Google Play:</p>

<a href="https://play.google.com/store/apps/details?id=org.openfoodfacts.scanner"><img src="/images/misc/android-app-on-google-play-en_app_rgb_wo_135x47.png" alt="Available on Google Play" width="135" height="47" /></a><br/>
<a href="http://world.openfoodfacts.org/files/off.apk">apk</a>

<p>Aplicativo Windows Phone:</p>

<a href="http://www.windowsphone.com/en-us/store/app/openfoodfacts/5d7cf939-cfd9-4ac0-86d7-91b946f4df34"><img src="/images/misc/154x40_WP_Store_blk.png" alt="Windows Phone Store" width="154" height="40" /></a><br/>

HTML
,

#PT-PT

	pt_pt => <<HTML
<a href="/"><img id="logo" src="/images/misc/openfoodfacts-logo-pt.png" width="178" height="143" alt="Open Food Facts" /></a>

<p>O Open Food Facts agrega informação de produtos alimentares de todo o mundo.</p>

<select_country>

<p>
→ <a href="/marcas">Marcas</a><br />
→ <a href="/categorias">Categorias</a><br/>
</p>

<p>Informações de produtos alimentares (fotos, ingredientes, informações nutricionais etc.) são agregadas de forma colaborativa e disponibilizadas para todas as pessoas e para todos os usos, através de uma base de dados livre e aberta.</p>

<p>Encontre-nos também em:</p>

<p>
→ <a href="http://en.wiki.openfoodfacts.org">nossa wiki</a><br />
→ <a href="http://twitter.com/openfoodfacts">Twitter</a><br/>
→ <a href="https://plus.google.com/u/0/110748322211084668559/">Google+</a><br />
→ <a href="https://www.facebook.com/OpenFoodFacts">Facebook</a><br />
+ <a href="https://www.facebook.com/groups/420574551372737/">grupo de colaboradores</a><br />
</p>

<p>Aplicação para iPhone e iPad na App Store:</p>

<a href="https://itunes.apple.com/en/app/open-food-facts/id588797948"><img src="/images/misc/Available_on_the_App_Store_Badge_EN_135x40.png" alt="Available on the App Store" width="135" height="40" /></a><br/>

<p>Aplicação para Android no Google Play:</p>

<a href="https://play.google.com/store/apps/details?id=org.openfoodfacts.scanner"><img src="/images/misc/android-app-on-google-play-en_app_rgb_wo_135x47.png" alt="Available on Google Play" width="135" height="47" /></a><br/>
<a href="http://world.openfoodfacts.org/files/off.apk">apk</a>

<p>Aplicação para Windows Phone:</p>

<a href="http://www.windowsphone.com/en-us/store/app/openfoodfacts/5d7cf939-cfd9-4ac0-86d7-91b946f4df34"><img src="/images/misc/154x40_WP_Store_blk.png" alt="Windows Phone Store" width="154" height="40" /></a><br/>

HTML
,

	ro => <<HTML
<a href="/"><img id="logo" src="/images/misc/openfoodfacts-logo-en.png" width="178" height="144" alt="Open Food Facts" /></a>

<p>Open Food Facts adună informații și date despre produse alimentare din întreaga lume.</p>

<select_country>

<p>
→ <a href="/marci">Mărci</a><br />
→ <a href="/categorii">Categorii</a><br/>
</p>

<p>Informațiile despre produsele alimentare (fotografii, ingrediente, valori nutriționale etc.) sunt adunate într-un mod
colaborativ și sunt puse la dispoziția tuturor și pentru toate utilizările într-o bază de date liberă și deschisă.</p>

<p>Ne găsiți și pe:</p>

<p>
→ <a href="http://en.wiki.openfoodfacts.org">wiki-ul nostru</a><br />
→ <a href="http://twitter.com/openfoodfacts">Twitter</a><br/>
→ <a href="https://plus.google.com/u/0/110748322211084668559/">Google+</a><br />
→ <a href="https://www.facebook.com/OpenFoodFacts">Facebook</a><br />
+ <a href="https://www.facebook.com/groups/374350705955208/">grupul contributorilor</a><br />
</p>

<p>Aplicația pentru iPhone și iPad din App Store:</p>

<a href="https://itunes.apple.com/en/app/open-food-facts/id588797948"><img src="/images/misc/Available_on_the_App_Store_Badge_EN_135x40.png" alt="Disponibilă în App Store" width="135" height="40" /></a><br/>

<p>Aplicația pentru Android din Google Play:</p>

<a href="https://play.google.com/store/apps/details?id=org.openfoodfacts.scanner"><img src="/images/misc/android-app-on-google-play-en_app_rgb_wo_135x47.png" alt="Disponibilă în Google Play" width="135" height="47" /></a><br/>
<a href="http://world.openfoodfacts.org/files/off.apk">apk</a>

<p>Aplicația pentru Windows Phone:</p>

<a href="http://www.windowsphone.com/en-us/store/app/openfoodfacts/5d7cf939-cfd9-4ac0-86d7-91b946f4df34"><img src="/images/misc/154x40_WP_Store_blk.png" alt="Windows Phone Store" width="154" height="40" /></a><br/>


HTML
,

	he => <<HTML
<a href="/"><img id="logo" src="/images/misc/openfoodfacts-logo-he.png" width="178" height="143" alt="Open Food Facts" /></a>

<p>המיזם Open Food Facts אוסף מידע ונתונים על מוצרי מזון מכל רחבי העולם.</p>

<select_country>

<p>
← <a href="/brands">מותגים</a><br />
← <a href="/categories">קטגוריות</a><br/>
</p>

<p>המידע על מוצרי המזון (תמונות, רכיבים, מפרט תזונתי וכו׳) נאסף באופן שיתופי
ונגיש לציבור הרחב לכל שימוש שהוא במסד נתונים חופשי ופתוח.</p>


<p>ניתן למצוא אותנו בערוצים הבאים:</p>

<p>
← <a href="http://en.wiki.openfoodfacts.org">הוויקי שלנו</a><br />
← <a href="http://twitter.com/openfoodfacts">טוויטר</a><br/>
← <a href="https://plus.google.com/u/0/110748322211084668559/">Google+</a><br />
← <a href="https://www.facebook.com/OpenFoodFacts">פייסבוק</a><br />
+ <a href="https://www.facebook.com/groups/374350705955208/">קבוצת התורמים</a><br />
</p>

<p>יישום ל־iPhone ול־iPad ב־App Store:</p>

<a href="https://itunes.apple.com/en/app/open-food-facts/id588797948"><img src="/images/misc/Download_on_the_App_Store_Badge_HB_135x40_1113.png" alt="זמין להורדה מה־App Store" width="135" height="40" /></a><br/>

<p>יישום לאנדרויד ב־Google Play:</p>

<a href="https://play.google.com/store/apps/details?id=org.openfoodfacts.scanner"><img src="/images/misc/android-app-on-google-play-en_app_rgb_wo_135x47.png" alt="Available on Google Play" width="135" height="47" /></a><br/>
<a href="http://world.openfoodfacts.org/files/off.apk">apk</a>

<p>יישום ל־Windows Phone:</p>

<a href="http://www.windowsphone.com/en-us/store/app/openfoodfacts/5d7cf939-cfd9-4ac0-86d7-91b946f4df34"><img src="/images/misc/154x40_WP_Store_blk.png" alt="החנות של Windows Phone" width="154" height="40" /></a><br/>


HTML
,
	nl => <<HTML
<a href="/"><img id="logo" src="/images/misc/openfoodfacts-logo-en.png" width="178" height="144" alt="Open Food Facts" /></a>

<p>Open Food Facts inventariseert alle voedingsmiddelen uit de hele wereld.</p>

<select_country>

<p>
→ <a href="/brands">Merken</a><br />
→ <a href="/categories">Categorieën</a><br/>
</p>

<p>De informatie over de voedingsmiddelen (foto's, ingrediënten, nutritionele informatie, etc.) wordt via een opensourcesysteem verzameld en voor iedereen en alle toepassingen ter beschikking gesteld in een open en gratis databank.</p>


<p>Vind ons ook terug op:</p>

<p>
→ <a href="http://en.wiki.openfoodfacts.org">onze wiki</a><br />
→ <a href="http://twitter.com/openfoodfacts">Twitter</a><br/>
→ <a href="https://plus.google.com/u/0/110748322211084668559/">Google+</a><br />
→ <a href="https://www.facebook.com/OpenFoodFacts">Facebook</a><br />
+ <a href="https://www.facebook.com/groups/374350705955208/">gebruikersgroep</a><br />
</p>

<p>iPhone en iPad app in de App Store:</p>

<a href="https://itunes.apple.com/en/app/open-food-facts/id588797948"><img src="/images/misc/Available_on_the_App_Store_Badge_EN_135x40.png" alt="Beschikbaar in de App Store" width="135" height="40" /></a><br/>

<p>Android app op Google Play:</p>

<a href="https://play.google.com/store/apps/details?id=org.openfoodfacts.scanner"><img src="/images/misc/android-app-on-google-play-en_app_rgb_wo_135x47.png" alt="Beschikbaar op Google Play" width="135" height="47" /></a><br/>
<a href="http://world.openfoodfacts.org/files/off.apk">apk</a>

<p>Windows Phone app:</p>

<a href="http://www.windowsphone.com/en-us/store/app/openfoodfacts/5d7cf939-cfd9-4ac0-86d7-91b946f4df34"><img src="/images/misc/154x40_WP_Store_blk.png" alt="Windows Phone Store" width="154" height="40" /></a><br/>


HTML
,
	nl_be => <<HTML
<a href="/"><img id="logo" src="/images/misc/openfoodfacts-logo-en.png" width="178" height="144" alt="Open Food Facts" /></a>

<p>Open Food Facts inventariseert alle voedingsmiddelen uit de hele wereld.</p>

<select_country>

<p>
→ <a href="/brands">Merken</a><br />
→ <a href="/categories">Categorieën</a><br/>
</p>

<p>De informatie over de voedingsmiddelen (foto's, ingrediënten, nutritionele informatie, etc.) wordt via een opensourcesysteem verzameld en voor iedereen en alle toepassingen ter beschikking gesteld in een open en gratis databank.</p>


<p>Vind ons ook terug op:</p>

<p>
→ <a href="http://en.wiki.openfoodfacts.org">onze wiki</a><br />
→ <a href="http://twitter.com/openfoodfacts">Twitter</a><br/>
→ <a href="https://plus.google.com/u/0/110748322211084668559/">Google+</a><br />
→ <a href="https://www.facebook.com/OpenFoodFacts">Facebook</a><br />
+ <a href="https://www.facebook.com/groups/374350705955208/">gebruikersgroep</a><br />
</p>

<p>iPhone en iPad app in de App Store:</p>

<a href="https://itunes.apple.com/en/app/open-food-facts/id588797948"><img src="/images/misc/Available_on_the_App_Store_Badge_EN_135x40.png" alt="Beschikbaar in de App Store" width="135" height="40" /></a><br/>

<p>Android app op Google Play:</p>

<a href="https://play.google.com/store/apps/details?id=org.openfoodfacts.scanner"><img src="/images/misc/android-app-on-google-play-en_app_rgb_wo_135x47.png" alt="Beschikbaar op Google Play" width="135" height="47" /></a><br/>
<a href="http://world.openfoodfacts.org/files/off.apk">apk</a>

<p>Windows Phone app:</p>

<a href="http://www.windowsphone.com/en-us/store/app/openfoodfacts/5d7cf939-cfd9-4ac0-86d7-91b946f4df34"><img src="/images/misc/154x40_WP_Store_blk.png" alt="Windows Phone Store" width="154" height="40" /></a><br/>


HTML
,

},


footer => {
	fr => <<HTML

<a href="http://fr.openfoodfacts.org/mentions-legales">Mentions légales</a> -
<a href="http://fr.openfoodfacts.org/conditions-d-utilisation">Conditions d'utilisation</a> -
<a href="http://fr.openfoodfacts.org/qui-sommes-nous">Qui sommes nous ?</a> -
<a href="http://fr.openfoodfacts.org/questions-frequentes">Questions fréquentes</a> -
<a href="https://openfoodfactsfr.uservoice.com/">Forum des idées</a> -
<a href="http://fr.blog.openfoodfacts.org">Blog</a> -
<a href="http://fr.openfoodfacts.org/presse-et-blogs">Presse, Blogs et Présentations</a>
HTML
,

	en => <<HTML
<a href="http://world.openfoodfacts.org/legal">Legal</a> -
<a href="http://world.openfoodfacts.org/terms-of-use">Terms of Use</a> -
<a href="http://world.openfoodfacts.org/who-we-are">Who we are</a> -
<a href="http://world.openfoodfacts.org/faq">Frequently Asked Questions</a> -
<a href="https://openfoodfacts.uservoice.com/">Ideas Forum</a> -
<a href="http://en.blog.openfoodfacts.org">Blog</a> -
<a href="http://world.openfoodfacts.org/press-and-blogs">Press and Blogs</a>
HTML
,

el => <<HTML
<a href="http://world.openfoodfacts.org/legal">Legal</a> -
<a href="http://world.openfoodfacts.org/terms-of-use">Terms of Use</a> -
<a href="http://world.openfoodfacts.org/who-we-are">Who we are</a> -
<a href="http://world.openfoodfacts.org/faq">Frequently Asked Questions</a> -
<a href="https://openfoodfacts.uservoice.com/">Ideas Forum</a> -
<a href="http://en.blog.openfoodfacts.org">Blog</a> -
<a href="http://world.openfoodfacts.org/press-and-blogs">Press and Blogs</a>
HTML
,

	es => <<HTML
<a href="http://world.openfoodfacts.org/legal">Aviso legal (inglés)</a> -
<a href="http://world.openfoodfacts.org/terms-of-use">Condiciones de uso (inglés)</a> -
<a href="http://world.openfoodfacts.org/who-we-are">¿Quiénes somos? (inglés)</a> -
<a href="http://world.openfoodfacts.org/faq">Preguntas frecuentes (inglés)</a> -
<a href="https://openfoodfacts.uservoice.com/">Foro de ideas (inglés)</a> -
<a href="http://fr.blog.openfoodfacts.org">Blog (francés)</a> -
<a href="http://world.openfoodfacts.org/press-and-blogs">Prensa, blogs y presentaciones (inglés)</a>
HTML
,

	pt => <<HTML
<a href="http://world.openfoodfacts.org/legal">Legal</a> -
<a href="http://world.openfoodfacts.org/terms-of-use">Termos de utilização</a> -
<a href="http://world.openfoodfacts.org/who-we-are">Quem somos</a> -
<a href="http://world.openfoodfacts.org/faq">FAQ</a> -
<a href="https://openfoodfacts.uservoice.com/">Fórum de ideias</a> -
<a href="http://en.blog.openfoodfacts.org">Blog</a> -
<a href="http://pt.openfoodfacts.org/imprensa-e-blogs">Imprensa e blogs</a>
HTML
,
	he => <<HTML
<a href="http://world.openfoodfacts.org/legal">מידע משפטי</a> -
<a href="http://world.openfoodfacts.org/terms-of-use">תנאי השימוש</a> -
<a href="http://world.openfoodfacts.org/who-we-are">מי אנחנו</a> -
<a href="http://world.openfoodfacts.org/faq">שאלות נפוצות</a> -
<a href="https://openfoodfacts.uservoice.com/">פורום הרעיונות</a> -
<a href="http://en.blog.openfoodfacts.org">בלוג</a> -
<a href="http://world.openfoodfacts.org/press-and-blogs">עתונות ובלוגים</a>
HTML
,
	nl => <<HTML

<a href="http://world.openfoodfacts.org/legal">Wettelijke bepalingen</a> -
<a href="http://world.openfoodfacts.org/terms-of-use">Gebruiksvoorwaarden</a> -
<a href="http://world.openfoodfacts.org/who-we-are">Wie zijn wij?</a> -
<a href="http://world.openfoodfacts.org/faq">Veelgestelde vragen</a> -
<a href="https://openfoodfacts.uservoice.com/">Ideeënforum</a> -
<a href="http://en.blog.openfoodfacts.org">Blog</a> -
<a href="http://world.openfoodfacts.org/press-and-blogs">Pers, Blogs en Presentaties</a>
HTML
,

	nl_be => <<HTML

<a href="http://world.openfoodfacts.org/legal">Wettelijke bepalingen</a> -
<a href="http://world.openfoodfacts.org/terms-of-use">Gebruiksvoorwaarden</a> -
<a href="http://world.openfoodfacts.org/who-we-are">Wie zijn wij?</a> -
<a href="http://world.openfoodfacts.org/faq">Veelgestelde vragen</a> -
<a href="https://openfoodfacts.uservoice.com/">Ideeënforum</a> -
<a href="http://en.blog.openfoodfacts.org">Blog</a> -
<a href="http://world.openfoodfacts.org/press-and-blogs">Pers, Blogs en Presentaties</a>
HTML
,

	de => <<HTML
<a href="http://fr.openfoodfacts.org/mentions-legales">AGB</a> -
<a href="http://fr.openfoodfacts.org/conditions-d-utilisation">Nutzungsbedingungen</a> -
<a href="http://fr.openfoodfacts.org/qui-sommes-nous">Wer sind wir?</a> -
<a href="http://fr.openfoodfacts.org/questions-frequentes">Häufig gestellte Fragen</a> -
<a href="https://openfoodfactsfr.uservoice.com/">Ideenforen</a> -
<a href="http://fr.blog.openfoodfacts.org">Blog</a> -
<a href="http://fr.openfoodfacts.org/presse-et-blogs">Presse, Blogs und Präsentationen</a>
HTML
,
},


# MOBILESTRING

app_please_take_pictures => {
	fr => <<HTML
<p>Ce produit n'est pas encore dans la base d'Open Food Facts. Pourriez-vous s'il vous plait prendre des photos
du produit, du code barre, de la liste des ingrédients et du tableau nutritionnel pour qu'il soit ajouté sur <a href="http://fr.openfoodfacts.org" target="_blank">Open Food Facts</a> ?</p>
<p>Merci d'avance !</p>
HTML
,
	en => <<HTML
<p>This product is not yet in the Open Food Facts database. Could you please take some pictures of the product, barcode, ingredients list and nutrition facts to add it on <a href="http://world.openfoodfacts.org" target="_blank">Open Food Facts</a>?</p>
<p>Thanks in advance!</p>
HTML
,
el => <<HTML
<p>Αυτό το προϊόν δεν έχει καταχωρηθεί ακόμα στη βάση δεδομένων του Open Food Facts. Παρακαλώ αν θέλετε προσθέστε φωτογραφίες του προϊόντος, του barcode, των διατροφικών στοιχείων και των συστατικών του στο <a href="http://world.openfoodfacts.org" target="_blank">Open Food Facts</a>?</p>
<p>Ευχαριστούμε εκ των προτέρων!</p>
HTML
,
	es => <<HTML
<p>Este producto aún no está en la base de datos de Open Food Facts. ¿Podrías tomar algunas fotos del producto, su código de barras, ingredientes e información nutricional para agregarlo a <a href="http://es.openfoodfacts.org" target="_blank">Open Food Facts</a>?</p>
<p>¡Gracias desde ya!</p>
HTML
,
	pt => <<HTML
<p>Este produto não se encontra ainda na base de dados do Open Food Facts. Será possível tirares fotografias do produtos, código de barras, ingredientes e informação nutricional para juntar ao <a href="http://pt.openfoodfacts.org" target="_blank">Open Food Facts</a>?</p>
<p>Desde já muito obrigado!</p>
HTML
,
	pt_pt => <<HTML
<p>Este produto não se encontra ainda na base de dados do Open Food Facts. Será possível tirar fotografias do produto, dos código de barras, dos ingredientes e da informação nutricional para juntar ao <a href="http://pt.openfoodfacts.org" target="_blank">Open Food Facts</a>?</p>
<p>Desde já muito obrigado!</p>
HTML
,
	ro => <<HTML
<p>Acest produs încă nu se află în baza de date Open Food Facts. Puteți face câteva fotografii cu produsul, codul de bare, lista de ingrediente și valorile nutriționale pentru a-l adăuga la <a href="http://world.openfoodfacts.org" target="_blank">Open Food Facts</a>?</p>
<p>Vă mulțumim în avans!</p>
HTML
,
	de => <<HTML
<p>Dieses Produkt existiert noch nicht in der Open Food Facts Datenbank. Können Sie bitte Fotos des Produktes, des Strichcodes, der Zutatenliste und der Nährwertsangaben machen, damit es zu <a href="http://fr.openfoodfacts.org" target="_blank">Open Food Facts</a> hinzugefügt werden kann?</p>
<p>Danke vielmals im Voraus!</p>
HTML
,
	it => <<HTML
<p>Questo prodotto non é ancora nel database di OFF. Puoi per favore fare una foto del prodotto, del codice a barre, della lista degli ingredienti e della tabella nutrizionale perché possa essere aggiunta su <a href="http://it.openfoodfacts.org" target="_blank">Open Food Facts</a>.</p>
<p>Grazie anticipatamente.</p>
HTML
,
	he => <<HTML
<p>מוצר זה לא נמצא עדיין במסד הנתונים של Open Food Facts. האם יתאפשר לך לצלם מספר תמונות של המוצר, הברקוד, רשימת הרכיבים והמפרט התזונתי כדי להוסיף אותם ל־<a href="http://il.openfoodfacts.org" target="_blank">Open Food Facts</a>?</p>
<p>תודה מראש!</p>
HTML
,

	nl => <<HTML
<p>Dit product bestaat nog niet in de Open Food Facts Database. Kan je alsjeblieft foto's maken van het product, de barcode, de ingredientenlijst en de voedingswaarden, zodat het aan <a href="http://fr.openfoodfacts.org" target="_blank">Open Food Facts</a> toegevoegd kan worden?</p>
<p>Alvast hartelijk bedankt!</p>
HTML
,
	nl_be => <<HTML
<p>Dit product bestaat nog niet in de Open Food Facts Database. Kunt u alstublieft foto's maken van het product, de barcode, de ingredientenlijst en de voedingswaarden, zodat het aan <a href="http://fr.openfoodfacts.org" target="_blank">Open Food Facts</a> toegevoegd kan worden?</p>
<p>Alvast hartelijk bedankt!</p>
HTML
,

},

# MOBILESTRING

app_you_can_add_pictures => {
	ar => "يمكنك إضافة صور",
	de => "Sie können Bilder hinzufügen:",
    cs => 'Můžete přidat obrázky:', #cs-CHECK - Please check and remove this comment
	es => "Puedes agregar imágenes:",
	en => "You can add pictures:",
	it => 'Puoi aggiungere una foto:',
    fi => 'Voit lisätä kuvia:', #fi-CHECK - Please check and remove this comment
	fr => "Vous pouvez ajouter des photos :",
	el => "Μπορείτε να προσθέσετε φωτογραφίες:",
	he => "ניתן להוסיף תמונות:",
    ja => 'あなたは写真を追加することができます。', #ja-CHECK - Please check and remove this comment
    ko => '당신은 사진을 추가 할 수 있습니다 :', #ko-CHECK - Please check and remove this comment
    nl => 'Je kan foto\'s toevoegen:',
    nl_be => 'U kunt foto\'s toevoegen:',
    ru => 'Вы можете добавить фотографии:', #ru-CHECK - Please check and remove this comment
    pl => 'Możesz dodać zdjęcia:', #pl-CHECK - Please check and remove this comment
	pt => "Pode adicionar imagens:",
	ro => "Puteți adăuga imagini:",
    th => 'คุณสามารถเพิ่มรูปภาพ:', #th-CHECK - Please check and remove this comment
    vi => 'Bạn có thể thêm hình ảnh:', #vi-CHECK - Please check and remove this comment
    zh => '您可以添加图片：', #zh-CHECK - Please check and remove this comment
},


app_take_a_picture => {
    ar => "التقاط صورة",
    de => "Machen Sie ein Foto",
    cs => 'Vyfotit', #cs-CHECK - Please check and remove this comment
    es => "Saca una foto",
    en => "Take a picture",
    it => "Scattare una foto",
    fi => 'Ota kuva', #fi-CHECK - Please check and remove this comment
    fr => "Prendre une photo",
    el => "Τραβήξτε μια φωτογραφία",
    he => "צילום תמונה",
    ja => '写真を撮ります', #ja-CHECK - Please check and remove this comment
    ko => '사진을 촬영', #ko-CHECK - Please check and remove this comment
    nl => 'Maak foto',
    nl_be => 'Maak foto',
    ru => 'Сфотографировать', #ru-CHECK - Please check and remove this comment
    pl => 'Zrób zdjęcie',
    pt => "Tire uma foto",
    ro => "Faceți o fotografie",
    th => 'การถ่ายภาพ', #th-CHECK - Please check and remove this comment
    vi => 'Chụp ảnh', #vi-CHECK - Please check and remove this comment
    zh => '拍照', #zh-CHECK - Please check and remove this comment
},

# MOBILESTRING

app_take_a_picture_note => {
	ar => "ملاحظة: يتم نشر الصور التي ترسلها تحت رخصة حرة سمات الإبداعية العموم والمشاركة على قدم المساواة.",
	fr => "Note : les photos que vous envoyez sont publiées sous la licence libre Creative Commons Attribution et Partage à l'identique.",
	en => "Note: the pictures you send are published under the free licence Creative Commons Attribution and ShareAlike.",
	el => "Σημείωση: Οι φωτογραφίες που στέλνετε δημοσιεύονται υπό από την ελεύθερη άδεια Creative Commons Attribution and ShareAlike.",
	es => "Nota: las imagenes que envías son publicadas bajo la licencia libre Creative Commons Attribution y ShareAlike.",
	de => "Anmerkung: Die Bilder, die Sie gesendet haben, werden mit der gebührenfreien Lizenz Creative Commons Attribution and ShareAlike veröffentlicht.",
	he => "לתשומת לבך: התמונות שנשלחות מפורסמות תחת תנאי הרישיון Creative Commons Attribution and ShareAlike.",
	it => "Nota: le foto che inviate sono pubblicate sotto libera licenza Creative Commons Attribution e ShareAlike.",
	nl => "NB: de foto's die je upload, worden gepubliceerd onder de vrije licentie Creative Commons Attribution and ShareAlike.",
	nl_be => "NB: de foto's die u upload, worden gepubliceerd onder de vrije licentie Creative Commons Attribution and ShareAlike.",
	pt => "Nota: as fotos que envia são publicadas sob a licença livre Creative Commons Attribution e ShareAlike.",
	ro => "Notă: fotografiile trimise sunt publicate sub o licență liberă Creative Commons Attribution and ShareAlike.",
},

unknown => {

    ar => 'غير معروف', #ar-CHECK - Please check and remove this comment
	de => "Unbekannt",
    cs => 'Neznámo', #cs-CHECK - Please check and remove this comment
	es => "Desconocido",
	en => "Unknown",
    it => 'Sconosciuto', #it-CHECK - Please check and remove this comment
    fi => 'Tuntematon', #fi-CHECK - Please check and remove this comment
	fr => "Inconnu",
	el => "Άγνωστος",
	he => "לא ידוע",
    ja => '不明', #ja-CHECK - Please check and remove this comment
    ko => '알 수없는', #ko-CHECK - Please check and remove this comment
    nl => 'Onbekend',
    nl_be => 'Onbekend',
    ru => 'Неизвестный', #ru-CHECK - Please check and remove this comment
    pl => 'Nieznany', #pl-CHECK - Please check and remove this comment
	pt => "Desconhecido",
	ro => "Necunoscut",
    th => 'ไม่ทราบ', #th-CHECK - Please check and remove this comment
    vi => 'Không biết', #vi-CHECK - Please check and remove this comment
    zh => '未知', #zh-CHECK - Please check and remove this comment

},

points_ranking_users_and_countries => {

    ar => 'ترتيب المساهمين والدول', #ar-CHECK - Please check and remove this comment
    de => 'Rangfolge der Beitragszahler und Ländern', #de-CHECK - Please check and remove this comment
    cs => 'Pořadí přispěvatelů a zemí', #cs-CHECK - Please check and remove this comment
    es => 'Ranking de los contribuyentes y de los países', #es-CHECK - Please check and remove this comment
	en => "Ranking of contributors and countries",
    it => 'Classifica dei collaboratori e dei paesi', #it-CHECK - Please check and remove this comment
    fi => 'Ranking avustajat ja maiden', #fi-CHECK - Please check and remove this comment
	fr => "Classement des contributeurs et des pays",
	el => "Κατάταξη συντελεστών και χωρών",
    he => 'דירוג של תורמים ומדינות',
    ja => '貢献者や国のランキング', #ja-CHECK - Please check and remove this comment
    ko => '참여자 국가의 순위', #ko-CHECK - Please check and remove this comment
    nl => 'Ordening van medewerkers en landen',
    nl_be => 'Ordening van medewerkers en landen',
    ru => 'Рейтинг вкладчиков и стран', #ru-CHECK - Please check and remove this comment
    pl => 'Ranking autorów i krajów', #pl-CHECK - Please check and remove this comment
    pt => 'Ranking dos contribuintes e países', #pt-CHECK - Please check and remove this comment
    ro => 'Clasament de contribuitori și țări', #ro-CHECK - Please check and remove this comment
    th => 'การจัดอันดับของผู้และประเทศ', #th-CHECK - Please check and remove this comment
    vi => 'Xếp hạng các đóng góp và các nước', #vi-CHECK - Please check and remove this comment
    zh => '排名贡献者和国家', #zh-CHECK - Please check and remove this comment

},

points_ranking => {
	ar => 'تصنيف', #ar-CHECK - Please check and remove this comment
	de => 'Rang', #de-CHECK - Please check and remove this comment
	cs => 'Žebříček', #cs-CHECK - Please check and remove this comment
	es => 'Clasificación', #es-CHECK - Please check and remove this comment
	en => "Ranking",
	it => 'Posto', #it-CHECK - Please check and remove this comment
	fi => 'Sijoitus', #fi-CHECK - Please check and remove this comment
	fr => "Classement",
	el => "Κατάταξη",
	he => 'דירוג',
	ja => 'ランキング', #ja-CHECK - Please check and remove this comment
	ko => '순위', #ko-CHECK - Please check and remove this comment
	nl => 'Ordening',
	nl_be => 'Ordening',
	ru => 'Ранжирование', #ru-CHECK - Please check and remove this comment
	pl => 'Ranking', #pl-CHECK - Please check and remove this comment
	pt => 'Posição', #pt-CHECK - Please check and remove this comment
	ro => 'Clasament', #ro-CHECK - Please check and remove this comment
	th => 'การจัดอันดับ', #th-CHECK - Please check and remove this comment
	vi => 'Xếp hạng', #vi-CHECK - Please check and remove this comment
	zh => '排行', #zh-CHECK - Please check and remove this comment
},

openfoodhunt_points => {
	en => "It's <a href=\"/open-food-hunt-2015\">Open Food Hunt</a> on Open Food Facts from Saturday February 21st 2015 to Sunday March 1st 2015! Contributors are awarded
Explorer points for products they add and Ambassador points for new contributors they recruit. Points are updated every 30 minutes.",
el => "Είναι <a href=\"/open-food-hunt-2015\">Open Food Hunt</a> στο Open Food Facts από το Σάββατο 21 Φεβρουαρίου 2015 μέχρι Κυριακή 1 Μαρτίου 2015! Οι συντελεστές κερδίζουν
Explorer points για προϊόντα που προσθέτουν και Ambassador points για καινούριους συντελεστές που στρατολογούν. Το σκορ την βαθμολογίας ενημερώνεται κάθε 30 λεπτά.",
	fr => "C'est l'<a href=\"/open-food-hunt-2015\">Open Food Hunt</a> sur Open Food Facts du samedi 21 février 2015 au dimanche 1er mars 2015 ! Les contributeurs reçoivent
des points Explorateurs pour les produits qu'ils ajoutent, et des points Ambassadeurs pour les nouveaux contributeurs qu'ils recrutent. Les points sont mis à jour toutes
les 30 minutes.",
	nl => "Het is <a href=\"/open-food-hunt-2015\">Open Food Hunt</a> op Open Food Facts van zaterdag 21 februari 2015 tot zondag 1 maart 2015 ! De deelnemers ontvangen Onderkkerspunten voor de producten die ze toevoegen, en Ambassadeurspunten voor nieuwe deelnemers, die ze aanbrengen. De punten worden elke 30 minuten geupdate.",
	nl_be => "Het is <a href=\"/open-food-hunt-2015\">Open Food Hunt</a> op Open Food Facts van zaterdag 21 februari 2015 tot zondag 1 maart 2015 ! De deelnemers ontvangen Onderkkerspunten voor de producten die ze toevoegen, en Ambassadeurspunten voor nieuwe deelnemers, die ze aanbrengen. De punten worden elke 30 minuten geupdate.",

},

points_user => {
	en => "%s is an Explorer for %d countries and an Ambassador for %d countries.",
	el => "Ο %s είναι Explorer για %d χώρες και Ambassador για %d χώρες.",
	fr => "%s est un Explorateur de %d pays et un Ambassadeur de %d countries.",
	nl => "%s is een Ontdekker van %d landen en een Ambassadeur van %d landen.",
	nl_be => "%s is een Ontdekker van %d landen en een Ambassadeur van %d landen.",
},

points_all_users => {
	en => "There are Explorers for %d countries and Ambassadors for %d countries.",
	el => "Υπάρχει Explorer για %d χώρες και Ambassador για %d χώρες.",
	fr => "Il y a des Explorateurs de %d pays et des Ambassadeurs de %d countries.",
	nl => "Er zijn Ontdekkers voor %d landen en Ambassadeurs voor %d landen.",
	nl_be => "Er zijn Ontdekkers voor %d landen en Ambassadeurs voor %d landen.",
},

points_country => {
	en => "%s has %d Explorers and %d Ambassadors.",
	el => "%s έχει Explorers και %s Ambassadors.",
	fr => "%s a %d Explorateurs et %d Ambassadeurs.",
	nl => "%s heeft %d Ontdekkers et %d Ambassadeurs.",
	nl_be => "%s heeft %d Ontdekkers et %d Ambassadeurs.",
},

points_all_countries => {
	en => "There are %d Explorers and %d Ambassadors.",
	el => "Υπάρχουν %d Explorers και %d Ambassadors.",
	fr => "Il y a %d Explorateurs et %d Ambassadeurs.",
	nl => "Er zijn %d Ontdekkers et %d Ambassadeurs.",
	nl_be => "Er zijn %d Ontdekkers et %d Ambassadeurs.",
},

menu => {
    ar => 'قائمة الطعام', #ar-CHECK - Please check and remove this comment
    de => 'Menü', #de-CHECK - Please check and remove this comment
    cs => 'Menu', #cs-CHECK - Please check and remove this comment
    es => 'Menú', #es-CHECK - Please check and remove this comment
    en => 'Menu', #en-CHECK - Please check and remove this comment
    it => 'Menu', #it-CHECK - Please check and remove this comment
    fi => 'Valikko', #fi-CHECK - Please check and remove this comment
    fr => 'Menu', #fr-CHECK - Please check and remove this comment
    el => 'Μενού', #el-CHECK - Please check and remove this comment
    he => 'תפריט',
    ja => 'メニュー', #ja-CHECK - Please check and remove this comment
    ko => '메뉴', #ko-CHECK - Please check and remove this comment
    nl => 'Menu',
    nl_be => 'Menu',
    ru => 'Меню', #ru-CHECK - Please check and remove this comment
    pl => 'Menu',
    pt => 'Menu', #pt-CHECK - Please check and remove this comment
    ro => 'Meniu', #ro-CHECK - Please check and remove this comment
    th => 'เมนู', #th-CHECK - Please check and remove this comment
    vi => 'Thực đơn', #vi-CHECK - Please check and remove this comment
    zh => '菜单', #zh-CHECK - Please check and remove this comment
},

#FRONTPAGE (it goes until ENDFRONTPAGE)
menu_discover => {
    ar => 'إكتشف', #ar-CHECK - Please check and remove this comment
    de => 'Entdecken', #de-CHECK - Please check and remove this comment
    cs => 'Objevte', #cs-CHECK - Please check and remove this comment
    es => 'Descubrir', #es-CHECK - Please check and remove this comment
    en => 'Discover', #en-CHECK - Please check and remove this comment
    it => 'Scopri', #it-CHECK - Please check and remove this comment
    fi => 'Löydä', #fi-CHECK - Please check and remove this comment
    fr => 'Découvrir', #fr-CHECK - Please check and remove this comment
    el => 'Ανακαλύψτε', #el-CHECK - Please check and remove this comment
    he => 'לגלות',
    ja => 'ディスカバー', #ja-CHECK - Please check and remove this comment
    ko => '발견', #ko-CHECK - Please check and remove this comment
    nl => 'Ontdek',
    nl_be => 'Ontdek',
    ru => 'Узнайте', #ru-CHECK - Please check and remove this comment
    pl => 'Odkryj',
    pt => 'Descubra', #pt-CHECK - Please check and remove this comment
    ro => 'Descoperiți', #ro-CHECK - Please check and remove this comment
    th => 'ค้นพบ', #th-CHECK - Please check and remove this comment
    vi => 'Khám phá', #vi-CHECK - Please check and remove this comment
    zh => '发现', #zh-CHECK - Please check and remove this comment
},

menu_discover_link => {
	en => "/discover",
	es => "/descubrir",
	fr => "/decouvrir",
},

menu_contribute => {
    ar => 'المساهمة', #ar-CHECK - Please check and remove this comment
    de => 'Beitragen', #de-CHECK - Please check and remove this comment
    cs => 'Přispět', #cs-CHECK - Please check and remove this comment
    es => 'Contribuir', #es-CHECK - Please check and remove this comment
    en => 'Contribute', #en-CHECK - Please check and remove this comment
    it => 'Contribuire', #it-CHECK - Please check and remove this comment
    fi => 'Avusta', #fi-CHECK - Please check and remove this comment
    fr => 'Contribuer', #fr-CHECK - Please check and remove this comment
    el => 'Συμβάλλετε', #el-CHECK - Please check and remove this comment
    he => 'לתרום',
    ja => '貢献します', #ja-CHECK - Please check and remove this comment
    ko => '기부', #ko-CHECK - Please check and remove this comment
    nl => 'Bijdragen',
    nl_be => 'Bijdragen',
    ru => 'Способствовать', #ru-CHECK - Please check and remove this comment
    pl => 'Wnieś wkład',
    pt => 'Contribuir', #pt-CHECK - Please check and remove this comment
    ro => 'Contribuiți', #ro-CHECK - Please check and remove this comment
    th => 'สนับสนุน', #th-CHECK - Please check and remove this comment
    vi => 'Góp phần', #vi-CHECK - Please check and remove this comment
    zh => '贡献', #zh-CHECK - Please check and remove this comment
},

menu_contribute_link => {
	en => "/contribute",
	fr => "/contribuer",
},

menu_add_a_product => {
    ar => 'إضافة منتج', #ar-CHECK - Please check and remove this comment
	de => 'Ein Produkt hinzufügen',
    cs => 'Přidat produkt', #cs-CHECK - Please check and remove this comment
	es => 'Añadir un producto',
	en => 'Add a product',
	da => 'Tilføj et produkt',
    it => 'Aggiungi un prodotto', #it-CHECK - Please check and remove this comment
    fi => 'Lisää tuote', #fi-CHECK - Please check and remove this comment
	fr => 'Ajouter un produit',
	el => "Προσθέστε ένα προϊόν",
	he => 'הוספת מוצר',
    ja => '製品を追加', #ja-CHECK - Please check and remove this comment
	ko => '제품 추가', #ko-CHECK - Please check and remove this comment
	nl => "Product toevoegen",
	nl_be => "Product toevoegen",
	ru => 'Добавить продукт',
	pl => 'Dodaj produkt',
	pt => 'Adicionar um produto',
	ro => "Adăugare produs",
	th => 'เพิ่มสินค้า', #th-CHECK - Please check and remove this comment
	vi => 'Thêm một sản phẩm', #vi-CHECK - Please check and remove this comment
	zh => '添加商品',
},

menu_add_a_product_link => {
	en => "/add-a-product",
	fr => "/ajouter-un-produit",
},

footer_tagline => {
	en => 'A collaborative, free and open database of food products from around the world.',
    ar => 'قاعدة بيانات التعاونية وحرة ومفتوحة للمنتجات الغذائية من جميع أنحاء العالم.', #ar-CHECK - Please check and remove this comment
    de => 'Eine gemeinsame, freie und offene Datenbank von Lebensmittelprodukten aus der ganzen Welt.', #de-CHECK - Please check and remove this comment
    cs => 'Spolupracovní, svobodné a otevřené databáze potravinářských výrobků z celého světa.', #cs-CHECK - Please check and remove this comment
    es => 'Una base de datos colaborativa, libre y abierto de los productos alimenticios de todo el mundo.', #es-CHECK - Please check and remove this comment
    it => 'Un database collaborativo, libero e aperto di prodotti alimentari provenienti da tutto il mondo.', #it-CHECK - Please check and remove this comment
    fi => 'Yhteistyöhön, vapaa ja avoin tietokanta elintarvikkeita ympäri maailmaa.', #fi-CHECK - Please check and remove this comment
	fr => 'Une base de données collaborative, libre et ouverte des produits alimentaires du monde entier.', #fr-CHECK - Please check and remove this comment
    el => 'Μια συλλογική, ελεύθερη και ανοιχτή βάση δεδομένων των προϊόντων τροφίμων από όλο τον κόσμο.', #el-CHECK - Please check and remove this comment
    he => 'מסד נתונים חופשי, פתוח ושיתופי של מוצרי מזון מכל רחבי העולם.',
    ja => '世界中から食品の、共同自由で開かれたデータベース。', #ja-CHECK - Please check and remove this comment
    ko => '세계 각국에서 식품의 협업 무료 오픈 데이터베이스.', #ko-CHECK - Please check and remove this comment
    nl => 'Een gezamenlijke, vrije en open database van voedingsmiddelen uit de hele wereld.',
    nl_be => 'Een gezamenlijke, vrije en open database van voedingsmiddelen uit de hele wereld.',
    ru => 'Совместной, бесплатно и открыть базу данных продуктов питания со всего мира.', #ru-CHECK - Please check and remove this comment
    pl => 'Wspólna, wolna i otwarta baza produktów spożywczych z całego świata.',
    pt => 'Um banco de dados colaborativo, livre e aberto de produtos alimentares de todo o mundo.', #pt-CHECK - Please check and remove this comment
    ro => 'O bază de date colaborativă, liberă și deschisă a produselor alimentare din întreaga lume.', #ro-CHECK - Please check and remove this comment
    th => 'การทำงานร่วมกันของฐานข้อมูลฟรีและเปิดของผลิตภัณฑ์อาหารจากทั่วโลก', #th-CHECK - Please check and remove this comment
    vi => 'Một cơ sở dữ liệu hợp tác, tự do và cởi mở của các sản phẩm thực phẩm từ khắp nơi trên thế giới.', #vi-CHECK - Please check and remove this comment
    zh => '食品来自世界各地的协作，自由和开放的数据库。', #zh-CHECK - Please check and remove this comment
    id => 'Sebuah basis data bahan, fakta nutrisi dan informasi pada makanan dari seluruh dunia, yang kolaboratif, bebas dan terbuka',
},

footer_legal => {
    ar => 'يذكر قانونية', #ar-CHECK - Please check and remove this comment
    de => 'Gesetzliche Hinweise', #de-CHECK - Please check and remove this comment
    cs => 'Právní zmínky', #cs-CHECK - Please check and remove this comment
    es => 'Menciones legales', #es-CHECK - Please check and remove this comment
    en => 'Legal', #en-CHECK - Please check and remove this comment
    it => 'Menzioni legali', #it-CHECK - Please check and remove this comment
    fi => 'Oikeudellinen mainitsee', #fi-CHECK - Please check and remove this comment
    fr => 'Mentions légales', #fr-CHECK - Please check and remove this comment
    el => 'Νομική αναφέρει', #el-CHECK - Please check and remove this comment
    he => 'מידע משפטי',
    ja => '法的には言及します', #ja-CHECK - Please check and remove this comment
    ko => '법적 언급', #ko-CHECK - Please check and remove this comment
    nl => 'Wettelijke vermeldingen',
    nl_be => 'Wettelijke vermeldingen',
    ru => 'Юридическая', #ru-CHECK - Please check and remove this comment
    pl => 'Nota prawna',
    pt => 'Menções legais', #pt-CHECK - Please check and remove this comment
    ro => 'Mențiuni legale', #ro-CHECK - Please check and remove this comment
    th => 'กฎหมายระบุว่า', #th-CHECK - Please check and remove this comment
    vi => 'Pháp đề cập đến', #vi-CHECK - Please check and remove this comment
    zh => '法律提及', #zh-CHECK - Please check and remove this comment
},

footer_legal_link => {
	en => '/legal',
	fr => '/mentions-legales',
},

footer_terms => {
    ar => 'شروط الاستخدام', #ar-CHECK - Please check and remove this comment
    de => 'Nutzungsbedingungen', #de-CHECK - Please check and remove this comment
    cs => 'Podmínky použití', #cs-CHECK - Please check and remove this comment
    es => 'Condiciones de uso', #es-CHECK - Please check and remove this comment
    en => 'Terms of use', #en-CHECK - Please check and remove this comment
    it => 'Condizioni d\'uso', #it-CHECK - Please check and remove this comment
    fi => 'Käyttöehdot', #fi-CHECK - Please check and remove this comment
    fr => 'Conditions d\'utilisation', #fr-CHECK - Please check and remove this comment
    el => 'Όροι χρήσης', #el-CHECK - Please check and remove this comment
    he => 'תנאי שימוש',
    ja => '利用規約', #ja-CHECK - Please check and remove this comment
    ko => '이용 약관', #ko-CHECK - Please check and remove this comment
    nl => 'Gebruiksvoorwaarden',
    nl_be => 'Gebruiksvoorwaarden',
    ru => 'Условия использования', #ru-CHECK - Please check and remove this comment
    pl => 'Zasady korzystania',
    pt => 'Termos de uso', #pt-CHECK - Please check and remove this comment
    ro => 'Condiții de utilizare', #ro-CHECK - Please check and remove this comment
    th => 'ข้อกำหนดการใช้งาน', #th-CHECK - Please check and remove this comment
    vi => 'Điều khoản sử dụng', #vi-CHECK - Please check and remove this comment
    zh => '使用条款', #zh-CHECK - Please check and remove this comment
},
footer_terms_link => {
	en => '/terms-of-use',
	fr => '/conditions-d-utilisation',
},

footer_data => {
    ar => 'معطيات', #ar-CHECK - Please check and remove this comment
    de => 'Daten', #de-CHECK - Please check and remove this comment
    cs => 'Údaje', #cs-CHECK - Please check and remove this comment
    es => 'Datos', #es-CHECK - Please check and remove this comment
    en => 'Data', #en-CHECK - Please check and remove this comment
    it => 'Dati', #it-CHECK - Please check and remove this comment
    fi => 'Data', #fi-CHECK - Please check and remove this comment
    fr => 'Données', #fr-CHECK - Please check and remove this comment
    el => 'Δεδομένα', #el-CHECK - Please check and remove this comment
    he => 'נתונים',
    ja => 'データ', #ja-CHECK - Please check and remove this comment
    ko => '데이터', #ko-CHECK - Please check and remove this comment
    nl => 'Gegevens',
    nl_be => 'Gegevens',
    ru => 'Данные', #ru-CHECK - Please check and remove this comment
    pl => 'Dane',
    pt => 'Dados', #pt-CHECK - Please check and remove this comment
    ro => 'Date', #ro-CHECK - Please check and remove this comment
    th => 'ข้อมูล', #th-CHECK - Please check and remove this comment
    vi => 'Dữ liệu', #vi-CHECK - Please check and remove this comment
    zh => '数据', #zh-CHECK - Please check and remove this comment
},
footer_data_link => {
	en => '/data', # use /data for all languages
},

footer_install_the_app => {
    ar => 'تثبيت التطبيق', #ar-CHECK - Please check and remove this comment
    de => 'Installieren Sie die App', #de-CHECK - Please check and remove this comment
    cs => 'Nainstalujte aplikaci', #cs-CHECK - Please check and remove this comment
    es => 'Instalar la aplicación', #es-CHECK - Please check and remove this comment
    en => 'Install the app', #en-CHECK - Please check and remove this comment
    it => 'Installare l\'app', #it-CHECK - Please check and remove this comment
    fi => 'Asenna sovellus', #fi-CHECK - Please check and remove this comment
    fr => 'Installez l\'app', #fr-CHECK - Please check and remove this comment
    el => 'Εγκαταστήστε το app', #el-CHECK - Please check and remove this comment
    he => 'התקנת היישום',
    ja => 'アプリをインストール', #ja-CHECK - Please check and remove this comment
    ko => '응용 프로그램을 설치', #ko-CHECK - Please check and remove this comment
    nl => 'Installeer de app',
    nl_be => 'Installeer de app',
    ru => 'Установить приложение', #ru-CHECK - Please check and remove this comment
    pl => 'Zainstaluj aplikację',
    pt => 'Instale o aplicativo', #pt-CHECK - Please check and remove this comment
    ro => 'Instalați aplicația', #ro-CHECK - Please check and remove this comment
    th => 'ติดตั้ง app', #th-CHECK - Please check and remove this comment
    vi => 'Cài đặt ứng dụng', #vi-CHECK - Please check and remove this comment
    zh => '安装应用程序', #zh-CHECK - Please check and remove this comment
},
android_app_link => {
	en => 'https://play.google.com/store/apps/details?id=org.openfoodfacts.scanner',
},

ios_app_link => {
	en => 'https://itunes.apple.com/en/app/open-food-facts/id588797948',
	fr => 'https://itunes.apple.com/fr/app/open-food-facts/id588797948',
},
windows_phone_app_link => {
	en => 'http://www.windowsphone.com/en-us/store/app/openfoodfacts/5d7cf939-cfd9-4ac0-86d7-91b946f4df34',
	fr => 'http://www.windowsphone.com/fr-fr/store/app/openfoodfacts/5d7cf939-cfd9-4ac0-86d7-91b946f4df34',
},
android_apk_app_link => {
	en => 'http://world.openfoodfacts.org/files/off.apk',
},
android_app_badge => {
	en => '<img src="/images/misc/android-app-on-google-play-en_app_rgb_wo_135x47.png" alt="Available on Google Play" width="135" height="47" />',
	fr => '<img src="/images/misc/android-app-on-google-play-en_app_rgb_wo_135x47.png" alt="Disponible sur Google Play" width="135" height="47" />',
},
ios_app_badge => {
	en => '<img src="/images/misc/Available_on_the_App_Store_Badge_EN_135x40.png" alt="Available on the App Store" width="135" height="40" />',
	fr => '<img src="/images/misc/Available_on_the_App_Store_Badge_FR_135x40.png" alt="Disponible sur l\'App Store" width="135" height="40" />',
},
windows_phone_app_badge => {
	en => '<img src="/images/misc/154x40_WP_Store_blk.png" alt="Windows Phone Store" width="154" height="40" />',
},
android_apk_app_badge => {
	en => '<img src="/images/misc/android-apk.112x40.png" alt="Android APK" />',
},
footer_discover_the_project => {
	ar => 'اكتشاف المشروع', #ar-CHECK - Please check and remove this comment
	de => 'Entdecken Sie das Projekt', #de-CHECK - Please check and remove this comment
	cs => 'Objevte projekt', #cs-CHECK - Please check and remove this comment
	es => 'Descubra el proyecto', #es-CHECK - Please check and remove this comment
	en => 'Discover the project',
	it => 'Scopri il progetto', #it-CHECK - Please check and remove this comment
	fi => 'Tutustu hanke', #fi-CHECK - Please check and remove this comment
	fr => 'Découvrez le projet',
	el => 'Ανακαλύψτε το έργο', #el-CHECK - Please check and remove this comment
	he => 'לגלות עוד על המיזם',
	ja => 'プロジェクトを発見', #ja-CHECK - Please check and remove this comment
	ko => '프로젝트보세요', #ko-CHECK - Please check and remove this comment
	nl => 'Ontdek het project',
	nl_be => 'Ontdek het project',
	ru => 'Откройте для себя проект', #ru-CHECK - Please check and remove this comment
	pl => 'Odkryj projekt', #pl-CHECK - Please check and remove this comment
	pt => 'Descubra o projeto', #pt-CHECK - Please check and remove this comment
	ro => 'Descoperiți proiectul', #ro-CHECK - Please check and remove this comment
	th => 'ค้นพบโครงการ', #th-CHECK - Please check and remove this comment
	vi => 'Khám phá những dự án', #vi-CHECK - Please check and remove this comment
	zh => '探索项目', #zh-CHECK - Please check and remove this comment
},
footer_who_we_are => {
    ar => 'من نحن', #ar-CHECK - Please check and remove this comment
    de => 'Wer wir sind', #de-CHECK - Please check and remove this comment
    cs => 'Kdo jsme', #cs-CHECK - Please check and remove this comment
    es => 'Quienes somos', #es-CHECK - Please check and remove this comment
    en => 'Who we are', #en-CHECK - Please check and remove this comment
    it => 'Chi siamo', #it-CHECK - Please check and remove this comment
    fi => 'Keitä me olemme', #fi-CHECK - Please check and remove this comment
    fr => 'Qui sommes nous ?', #fr-CHECK - Please check and remove this comment
    el => 'Ποιοι είμαστε', #el-CHECK - Please check and remove this comment
    he => 'מי אנחנו',
    ja => '私たちは誰ですか', #ja-CHECK - Please check and remove this comment
    ko => '누가 우리가', #ko-CHECK - Please check and remove this comment
    nl => 'Wie zijn wij?',
    nl_be => 'Wie zijn wij?',
    ru => 'Кто мы', #ru-CHECK - Please check and remove this comment
    pl => 'Kim jesteśmy',
    pt => 'Quem somos?', #pt-CHECK - Please check and remove this comment
    ro => 'Cine suntem noi', #ro-CHECK - Please check and remove this comment
    th => 'เราคือใคร', #th-CHECK - Please check and remove this comment
    vi => 'Chúng ta là ai', #vi-CHECK - Please check and remove this comment
    zh => '我们是谁', #zh-CHECK - Please check and remove this comment
},
footer_who_we_are_link => {
	en => '/who-we-are',
	fr => '/qui-sommes-nous',
},
footer_faq => {
	ar => 'أسئلة مكررة', #ar-CHECK - Please check and remove this comment
	de => 'Häufig gestellte Fragen', #de-CHECK - Please check and remove this comment
	cs => 'Často kladené otázky', #cs-CHECK - Please check and remove this comment
	es => 'Preguntas frecuentes', #es-CHECK - Please check and remove this comment
	en => 'Frequently asked questions',
	it => 'Domande frequenti', #it-CHECK - Please check and remove this comment
	fi => 'Usein kysyttyjä kysymyksiä', #fi-CHECK - Please check and remove this comment
	fr => 'Questions fréquentes',
	el => 'Συχνές ερωτήσεις', #el-CHECK - Please check and remove this comment
	he => 'שאלות נפוצות',
	ja => 'よくある質問', #ja-CHECK - Please check and remove this comment
	ko => '자주 묻는 질문', #ko-CHECK - Please check and remove this comment
	nl => 'Veel gestelde vragen',
	nl_be => 'Veel gestelde vragen',
	ru => 'Часто задаваемые вопросы', #ru-CHECK - Please check and remove this comment
	pl => 'Często Zadawane Pytania', #pl-CHECK - Please check and remove this comment
	pt => 'Perguntas frequentes', #pt-CHECK - Please check and remove this comment
	ro => 'Întrebări frecvente', #ro-CHECK - Please check and remove this comment
	th => 'คำถามที่พบบ่อย', #th-CHECK - Please check and remove this comment
	vi => 'Câu hỏi thường gặp', #vi-CHECK - Please check and remove this comment
	zh => '常问问题', #zh-CHECK - Please check and remove this comment
},
footer_faq_link => {
	en => '/faq',
	fr => '/questions-frequentes',
	# nl => '/veel-gevraagd', #nl-CHECK - Please check and remove this comment
	# nl_be => '/veel-gevraagd', #nl_be-CHECK - Please check and remove this comment
},
footer_blog => {

    ar => 'وOpen Food Facts بلوق', #ar-CHECK - Please check and remove this comment
    de => 'Die Open Food Facts blog', #de-CHECK - Please check and remove this comment
    cs => 'Open Food Facts blog', #cs-CHECK - Please check and remove this comment
    es => 'El blog Open Food Facts', #es-CHECK - Please check and remove this comment
	en => 'Open Food Facts blog',
    it => 'Il blog Open Food Facts', #it-CHECK - Please check and remove this comment
    fi => 'Open Food Facts blogi', #fi-CHECK - Please check and remove this comment
	fr => "Le blog d'Open Food Facts",
    el => 'Το Open Food Facts το blog', #el-CHECK - Please check and remove this comment
    he => 'הבלוג של Open Food Facts',
    ja => 'Open Food Facts のブログ', #ja-CHECK - Please check and remove this comment
    ko => 'Open Food Facts 블로그', #ko-CHECK - Please check and remove this comment
    nl => 'De Open Food Facts blog',
    nl_be => 'De Open Food Facts blog',
    ru => 'Open Food Facts в блоге', #ru-CHECK - Please check and remove this comment
    pl => 'Open Food Facts blog', #pl-CHECK - Please check and remove this comment
    pt => 'O blog Open Food Facts', #pt-CHECK - Please check and remove this comment
    ro => 'Open Food Facts blog', #ro-CHECK - Please check and remove this comment
    th => 'Open Food Facts บล็อก', #th-CHECK - Please check and remove this comment
    vi => 'Các Open Food Facts blog', #vi-CHECK - Please check and remove this comment
    zh => '在 Open Food Facts 博客', #zh-CHECK - Please check and remove this comment

},
footer_blog_link => {
	en => 'http://en.blog.openfoodfacts.org',
	fr => 'http://fr.blog.openfoodfacts.org',
	#nl => 'http://nl.blog.openfoodfacts.org', #nl-CHECK - Add when necessary
	#nl_be => 'http://nl.blog.openfoodfacts.org', #nl_be-CHECK - Add when necessary
},
footer_press => {
    ar => 'صحافة', #ar-CHECK - Please check and remove this comment
    de => 'Presse', #de-CHECK - Please check and remove this comment
    cs => 'Lis', #cs-CHECK - Please check and remove this comment
    es => 'Prensa', #es-CHECK - Please check and remove this comment
    en => 'Press', #en-CHECK - Please check and remove this comment
    it => 'Stampa', #it-CHECK - Please check and remove this comment
    fi => 'Lehdistö', #fi-CHECK - Please check and remove this comment
    fr => 'Presse', #fr-CHECK - Please check and remove this comment
    el => 'Πρέσα', #el-CHECK - Please check and remove this comment
    he => 'מידע לעתונאים',
    ja => 'プレス', #ja-CHECK - Please check and remove this comment
    ko => '프레스', #ko-CHECK - Please check and remove this comment
    nl => 'Pers',
    nl_be => 'Pers',
    ru => 'Пресс', #ru-CHECK - Please check and remove this comment
    pl => 'Prasa',
    pt => 'Imprensa', #pt-CHECK - Please check and remove this comment
    ro => 'Presa', #ro-CHECK - Please check and remove this comment
    th => 'กด', #th-CHECK - Please check and remove this comment
    vi => 'Báo chí', #vi-CHECK - Please check and remove this comment
    zh => '按', #zh-CHECK - Please check and remove this comment
},

footer_press_link => {
	en => '/press',
	fr => '/presse',
	#nl-CHECK nl => '/pers' - add when relevant?
	#nl_be-CHECK nl_be => '/pers' - add when relevant?
},

footer_join_the_community => {
    ar => 'الانضمام إلى المجتمع', #ar-CHECK - Please check and remove this comment
    de => 'Der Community beitreten', #de-CHECK - Please check and remove this comment
    cs => 'Připojte se ke komunitě', #cs-CHECK - Please check and remove this comment
    es => 'Únete a la comunidad', #es-CHECK - Please check and remove this comment
    en => 'Join the community', #en-CHECK - Please check and remove this comment
    it => 'Entra nella community', #it-CHECK - Please check and remove this comment
    fi => 'Liity yhteisöön', #fi-CHECK - Please check and remove this comment
    fr => 'Rejoignez la communauté', #fr-CHECK - Please check and remove this comment
    el => 'Γίνετε μέλος της κοινότητας', #el-CHECK - Please check and remove this comment
    he => 'הצטרפות לקהילה',
    ja => 'コミュニティに参加', #ja-CHECK - Please check and remove this comment
    ko => '커뮤니티에 참여', #ko-CHECK - Please check and remove this comment
    nl => 'Word lid van de community',
    nl_be => 'Word lid van de community',
    ru => 'Присоединяйтесь к сообществу', #ru-CHECK - Please check and remove this comment
    pl => 'Dołącz do społeczności',
    pt => 'Junte-se à comunidade', #pt-CHECK - Please check and remove this comment
    ro => 'Alăturați-vă comunității', #ro-CHECK - Please check and remove this comment
    th => 'เข้าร่วมกับชุมชน', #th-CHECK - Please check and remove this comment
    vi => 'Tham gia cộng đồng', #vi-CHECK - Please check and remove this comment
    zh => '加入社区', #zh-CHECK - Please check and remove this comment
},
# Join us on Slack
footer_join_us_on => {
	ar => 'الانضمام إلينا على٪ الصورة %s:', #ar-CHECK - Please check and remove this comment
	de => 'Begleiten Sie uns auf %s:', #de-CHECK - Please check and remove this comment
	cs => 'Přidejte se k nám na %s:', #cs-CHECK - Please check and remove this comment
	es => 'Únase a nosotros en %s:', #es-CHECK - Please check and remove this comment
	en => 'Join us on %s:', #en-CHECK - Please check and remove this comment
	it => 'Unisciti a noi su %s:', #it-CHECK - Please check and remove this comment
	fi => 'Liity meihin %s:', #fi-CHECK - Please check and remove this comment
	fr => 'Rejoignez-nous sur %s:', #fr-CHECK - Please check and remove this comment
	el => 'Ελάτε μαζί μας στο %s:', #el-CHECK - Please check and remove this comment
	he => 'ניתן להצטרף אלינו ב־%s:',
	ja => 'の上ご参加ください。%s:', #ja-CHECK - Please check and remove this comment
	ko => '의 고객 센터 %s:', #ko-CHECK - Please check and remove this comment
	nl => 'Kom erbij op %s:', #nl-CHECK - Please check and remove this comment
	nl_be => 'Kom erbij op %s:', #nl-CHECK - Please check and remove this comment
	ru => 'Присоединяйтесь к нам на %s:', #ru-CHECK - Please check and remove this comment
	pl => 'Dołącz do nas na %s:',
	pt => 'Junte-se a %s:', #pt-CHECK - Please check and remove this comment
	ro => 'Alătură-te nouă pe %s:', #ro-CHECK - Please check and remove this comment
	th => 'ร่วมกับเราใน %s:', #th-CHECK - Please check and remove this comment
	vi => 'Tham gia với chúng tôi trên %s:', #vi-CHECK - Please check and remove this comment
	zh => '加入我们的 ％s：', #zh-CHECK - Please check and remove this comment
},

footer_and_the_facebook_group => {
	#ar => 'وجماعة الفيسبوك للمساهمين', ar-CHECK - Please check and remove this comment
	#de => 'und die Facebook-Gruppe für Mitwirkende', de-CHECK - Please check and remove this comment
	#cs => 'a skupina Facebook pro přispěvatele', cs-CHECK - Please check and remove this comment
	#es => 'y el grupo de Facebook para los contribuyentes', es-CHECK - Please check and remove this comment
		en => 'and the <a href="https://www.facebook.com/groups/374350705955208/">Facebook group for contributors</a>',
	#it => 'e il gruppo di Facebook per i collaboratori', #t-CHECK - Please check and remove this comment
	#fi => 'ja Facebook-ryhmä osallistujien', fi-CHECK - Please check and remove this comment
		fr => 'et le <a href="https://www.facebook.com/groups/356858984359591/">groupe Facebook des contributeurs</a>',
	#el => 'και η ομάδα στο Facebook για τους συνεισφέροντες', el-CHECK - Please check and remove this comment
	he => 'וה<a href="https://www.facebook.com/groups/374350705955208/">קבוצה</a> בפייסבוק למתנדבים',
	#ja => 'と貢献者のためのFacebookのグループ', ja-CHECK - Please check and remove this comment
	#ko => '및 참여자에 대한 페이스 북 그룹', ko-CHECK - Please check and remove this comment
	#nl => 'en de Facebook-groep voor medewerkers',
	#nl_be => 'en de Facebook-groep voor medewerkers',
	#ru => 'и группа Facebook для авторов', ru-CHECK - Please check and remove this comment
	#pl => 'i grupa Facebook dla kontrybutorow',
	#pt => 'e do grupo de Facebook para os contribuintes', pt-CHECK - Please check and remove this comment
	ro => 'și <a href="https://www.facebook.com/groups/374350705955208/">grupul de Facebook pentru contribuitori</a>',
	#th => 'และกลุ่ม Facebook สำหรับผู้ร่วมสมทบ', th-CHECK - Please check and remove this comment
	#vi => 'và các nhóm Facebook cho người đóng góp', vi-CHECK - Please check and remove this comment
	#zh => '和Facebook群组贡献者', zh-CHECK - Please check and remove this comment
},

footer_follow_us => {
	en => <<HTML
Follow us on <a href="http://twitter.com/openfoodfacts">Twitter</a>,
<a href="https://www.facebook.com/OpenFoodFacts">Facebook</a> and
<a href="https://plus.google.com/u/0/110748322211084668559/">Google+</a>
HTML
,
	fr => <<HTML
Suivez nous sur <a href="http://twitter.com/openfoodfactsfr">Twitter</a>,
<a href="https://www.facebook.com/OpenFoodFacts.fr">Facebook</a> et
<a href="https://plus.google.com/u/0/b/102622509148794386660/">Google+</a>

HTML
,
	nl => <<HTML
Suivez nous sur <a href="http://twitter.com/openfoodfactsnl">Twitter</a>,
<a href="https://www.facebook.com/OpenFoodFacts">Facebook</a> et
<a href="https://plus.google.com/u/0/b/102622509148794386660/">Google+</a>

HTML
,
	nl_be => <<HTML
Suivez nous sur <a href="http://twitter.com/openfoodfactsnl">Twitter</a>,
<a href="https://www.facebook.com/OpenFoodFacts">Facebook</a> et
<a href="https://plus.google.com/u/0/b/102622509148794386660/">Google+</a>

HTML
,

	ro => <<HTML
Urmăriți-ne pe <a href="http://twitter.com/openfoodfacts">Twitter</a>,
<a href="https://www.facebook.com/OpenFoodFacts">Facebook</a> și
<a href="https://plus.google.com/u/0/110748322211084668559/">Google+</a>
HTML
,
},


search_a_product_placeholder => {
    ar => 'ابحث عن منتج', #ar-CHECK - Please check and remove this comment
    de => 'Artikel suchen', #de-CHECK - Please check and remove this comment
    cs => 'Vyhledat produkt', #cs-CHECK - Please check and remove this comment
    es => 'Buscar artículo', #es-CHECK - Please check and remove this comment
    en => 'Search a product', #en-CHECK - Please check and remove this comment
    it => 'Ricercare un prodotto', #it-CHECK - Please check and remove this comment
    fi => 'Etsi tuote', #fi-CHECK - Please check and remove this comment
    fr => 'Chercher un produit', #fr-CHECK - Please check and remove this comment
    el => 'Αναζήτηση προϊόντος', #el-CHECK - Please check and remove this comment
    he => 'חיפוש מוצר',
    ja => '製品を検索します', #ja-CHECK - Please check and remove this comment
    ko => '제품 검색', #ko-CHECK - Please check and remove this comment
    nl => 'Zoek een product',
    nl_be => 'Zoek een product',
    ru => 'Поиск продукта', #ru-CHECK - Please check and remove this comment
    pl => 'Wyszukaj produkt',
    pt => 'Procurar um produto', #pt-CHECK - Please check and remove this comment
    ro => 'Căutați un produs', #ro-CHECK - Please check and remove this comment
    th => 'ค้นหาสินค้า', #th-CHECK - Please check and remove this comment
    vi => 'Tìm kiếm một sản phẩm', #vi-CHECK - Please check and remove this comment
    zh => '搜索产品', #zh-CHECK - Please check and remove this comment
},

search_criteria => {
    ar => 'اختر المنتجات ذات العلامات التجارية المحددة، والفئات، والعلامات، أصول المكونات، وأماكن تصنيع الخ', #ar-CHECK - Please check and remove this comment
    de => 'Wählen Sie die Produkte mit spezifischen Marken, Kategorien, Etiketten, Herkunft der Zutaten, Herstellung Plätze usw.', #de-CHECK - Please check and remove this comment
    cs => 'Vyberte produkty s konkrétními značkami, kategorií, štítky, původ surovin, výrobních míst atd', #cs-CHECK - Please check and remove this comment
	es => 'Seleccione los productos con marcas específicas, categorías, etiquetas, orígenes de ingredientes, lugares de fabricación, etc.', #es-CHECK - Please check and remove this comment
	en => 'Select products with specific brands, categories, labels, origins of ingredients, manufacturing places etc.',
	it => 'Scegli prodotti con marche specifiche, categorie, etichette, le origini degli ingredienti, luoghi di produzione ecc', #it-CHECK - Please check and remove this comment
	fi => 'Valitse tuotteet, joilla on erityisiä merkkejä, luokat, tarrat, alkuperä ainesosien, valmistuksen paikoissa jne', #fi-CHECK - Please check and remove this comment
	fr => "Sélectionner les produits suivant leur marque, catégories, labels, origines des ingrédients, lieux de fabrication etc.",
	el => 'Επιλέξτε προϊόντα με συγκεκριμένες μάρκες, κατηγορίες, ετικέτες, την προέλευση των συστατικών, χώρους παραγωγής κ.λπ.', #el-CHECK - Please check and remove this comment
    he => 'ניתן לבחור במוצרים ממותגים מסוימים, קטגוריות, תוויות, מקורות של מרכיבים, מקומות ייצור וכו׳  ',
    ja => '特定のブランド、カテゴリ、ラベル、成分の起源、製造所等を有する製品を選択', #ja-CHECK - Please check and remove this comment
    ko => '등 특정 브랜드, 종류, 라벨, 재료의 기원, 제조 장소와 제품 선택', #ko-CHECK - Please check and remove this comment
    nl => 'Kies producten met specifieke merken, categorieën, labels, de herkomst van de ingrediënten, productie plaatsen etc.',
    nl_be => 'Kies producten met specifieke merken, categorieën, labels, de herkomst van de ingrediënten, productie plaatsen etc.',
    ru => 'Выберите продукты с конкретных марок, категорий, этикетки, происхождение ингредиентов, производственных местах и ​​т.д.', #ru-CHECK - Please check and remove this comment
    pl => 'Wybierz produkty ze wzgledu na marki, kategorie, etykiety, pochodzenie składników, miejsca produkcyjne itp',
    pt => 'Selecione os produtos com marcas específicas, categorias, etiquetas, origens de ingredientes, locais de produção, etc.', #pt-CHECK - Please check and remove this comment
    ro => 'Alege produse cu marci specifice, categorii, etichete, originea de ingrediente, locuri de producție etc.', #ro-CHECK - Please check and remove this comment
    th => 'เลือกผลิตภัณฑ์ที่มีแบรนด์ที่เฉพาะเจาะจงประเภท, ป้าย, ต้นกำเนิดของส่วนผสมสถ​​านที่ผลิต ฯลฯ', #th-CHECK - Please check and remove this comment
    vi => 'Chọn các sản phẩm có thương hiệu cụ thể, chủng loại, nhãn, nguồn gốc nguyên liệu, nơi sản xuất vv', #vi-CHECK - Please check and remove this comment
    zh => '具体的品牌，类别，标签，成分来源，生产场所等选择产品', #zh-CHECK - Please check and remove this comment
},

logo => {
	en => 'openfoodfacts-logo-en-178x150.png',
	ar => 'openfoodfacts-logo-ar-178x150.png',
	de => 'openfoodfacts-logo-de-178x150.png',
	es => 'openfoodfacts-logo-es-178x150.png',
	fr => 'openfoodfacts-logo-fr-178x150.png',
	he => 'openfoodfacts-logo-he-178x150.png',
	nl => 'openfoodfacts-logo-nl-178x150.png',
	nl_be => 'openfoodfacts-logo-nl-178x150.png',
	pl => 'openfoodfacts-logo-pl-178x150.png',
	pt => 'openfoodfacts-logo-pt-178x150.png',
	ru => 'openfoodfacts-logo-ru-178x150.png',
	vi => 'openfoodfacts-logo-vi-178x150.png',
	zh => 'openfoodfacts-logo-zh-178x150.png',
},

logo2x => {
	en => 'openfoodfacts-logo-en-356x300.png',
	ar => 'openfoodfacts-logo-ar-356x300.png',
	de => 'openfoodfacts-logo-de-356x300.png',
	es => 'openfoodfacts-logo-es-356x300.png',
	fr => 'openfoodfacts-logo-fr-356x300.png',
	he => 'openfoodfacts-logo-he-356x300.png',
	nl => 'openfoodfacts-logo-nl-356x300.png',
	nl_be => 'openfoodfacts-logo-nl-356x300.png',
	pl => 'openfoodfacts-logo-pl-356x300.png',
	pt => 'openfoodfacts-logo-pt-356x300.png',
	ru => 'openfoodfacts-logo-ru-356x300.png',
	vi => 'openfoodfacts-logo-vi-356x300.png',
	zh => 'openfoodfacts-logo-zh-356x300.png',
},


search_tools => {
    ar => 'أدوات البحث', #ar-CHECK - Please check and remove this comment
    de => 'Suchwerkzeuge', #de-CHECK - Please check and remove this comment
    cs => 'Vyhledávací nástroje', #cs-CHECK - Please check and remove this comment
    es => 'Herramientas de búsqueda', #es-CHECK - Please check and remove this comment
    en => 'Search tools', #en-CHECK - Please check and remove this comment
    it => 'Strumenti di ricerca', #it-CHECK - Please check and remove this comment
    fi => 'Hakutyökalut', #fi-CHECK - Please check and remove this comment
    fr => 'Outils de recherche', #fr-CHECK - Please check and remove this comment
    el => 'Εργαλεία αναζήτησης', #el-CHECK - Please check and remove this comment
    he => 'כלי חיפוש',
    ja => '検索ツール', #ja-CHECK - Please check and remove this comment
    ko => '검색 도구', #ko-CHECK - Please check and remove this comment
    nl => 'Zoekfuncties',
    nl_be => 'Zoekfuncties',
    ru => 'Инструменты поиска', #ru-CHECK - Please check and remove this comment
    pl => 'Narzędzia wyszukiwania',
    pt => 'Ferramentas de pesquisa', #pt-CHECK - Please check and remove this comment
    ro => 'Instrumente de căutare', #ro-CHECK - Please check and remove this comment
    th => 'เครื่องมือค้นหา', #th-CHECK - Please check and remove this comment
    vi => 'Công cụ tìm kiếm', #vi-CHECK - Please check and remove this comment
    zh => '搜索工具', #zh-CHECK - Please check and remove this comment
},

manage_images => {
	en => 'Manage images',
	fr => 'Gérer les images',
	nl => 'Beheer de foto\'s',
	nl_be => 'Beheer de foto\'s',
},

manage_images_info => {
	en => 'You can select one or more images and then:',
	fr => 'Vous pouvez sélectionner une ou plusieurs images et ensuite:',
	nl => 'Je kan één of meer foto\'s kiezen en vervolgens:',
	nl_be => 'U kunt één of meer foto\'s kiezen en vervolgens:',
},

delete_the_images => {
	en => 'Delete the images',
	fr => 'Supprimer les images',
	nl => 'Verwijder de foto\'s',
	nl_be => 'Verwijder de foto\'s',
},

move_images_to_another_product => {
	en => 'Move the images to another product',
	fr => 'Déplacer les images sur un autre produit',
	nl => 'Verplaats de foto\'s naar een ander product',
	nl_be => 'Verplaats de foto\'s naar een ander product',
},

copy_data => {
	en => "Copy data from current product to new product",
	fr => "Copier les données du produit actuel sur le nouveau",
	nl => "Kopieer de productendata naar het nieuwe product",
	nl_be => "Kopieer de productendata naar het nieuwe product",
},


#ENDFRONTPAGE

);


my @debug_taxonomies = ("categories", "labels", "additives");

foreach my $taxonomy (@debug_taxonomies) {

	foreach my $suffix ("prev", "next", "debug") {
	
		foreach my $field ("", "_s", "_p") {
			$Lang{$taxonomy . "_$suffix" . $field } = { en => get_fileid($taxonomy) . "-$suffix" };
			print STDERR " Lang{ " . $taxonomy . "_$suffix" . $field  . "} = { en => " . get_fileid($taxonomy) . "-$suffix } \n";
		}
		
		$tag_type_singular{$taxonomy . "_$suffix"} = { en => get_fileid($taxonomy) . "-$suffix" };
		$tag_type_plural{$taxonomy . "_$suffix"} = { en => get_fileid($taxonomy) . "-$suffix" };
	}
}




foreach my $l (@Langs) {

	my $short_l = undef;
	if ($l =~ /_/) {
		$short_l = $`;  # pt_pt
	}

	foreach my $type (keys %tag_type_singular) {

		if (not defined $tag_type_singular{$type}{$l}) {
			if ((defined $short_l) and (defined $tag_type_singular{$type}{$short_l})) {
				$tag_type_singular{$type}{$l} = $tag_type_singular{$type}{$short_l};
			}
			else {
				$tag_type_singular{$type}{$l} = $tag_type_singular{$type}{en};
			}
		}
	}

	foreach my $type (keys %tag_type_plural) {
		if (not defined $tag_type_plural{$type}{$l}) {
			if ((defined $short_l) and (defined $tag_type_plural{$type}{$short_l})) {
				$tag_type_plural{$type}{$l} = $tag_type_plural{$type}{$short_l};
			}
			else {
				$tag_type_plural{$type}{$l} = $tag_type_plural{$type}{en};
			}
		}
	}

	$tag_type_from_singular{$l} or $tag_type_from_singular{$l} = {};
	$tag_type_from_plural{$l} or $tag_type_from_plural{$l} = {};


	foreach my $type (keys %tag_type_singular) {
			$tag_type_from_singular{$l}{$tag_type_singular{$type}{$l}} = $type;
	}

	foreach my $type (keys %tag_type_plural) {
			$tag_type_from_plural{$l}{$tag_type_plural{$type}{$l}} = $type;
			#print "tag_type_from_plural{$l}{$tag_type_plural{$type}{$l}} = $type;\n";
	}

}

# same logic can be implemented by creating the missing values for all keys
sub lang($) {

	my $s = shift;

	my $short_l = undef;
	if ($lang =~ /_/) {
		$short_l = $`,  # pt_pt
	}

	if ((defined $langlang) and (defined $Lang{$s}{$langlang})) {
		return $Lang{$s}{$langlang};
	}
	elsif (defined $Lang{$s}{$lang}) {
		return $Lang{$s}{$lang};
	}
	elsif ((defined $short_l) and (defined $Lang{$s}{$short_l}) and ($Lang{$s}{$short_l} ne '')) {
		return $Lang{$s}{$short_l};
	}
	elsif ((defined $Lang{$s}{en}) and ($Lang{$s}{en} ne '')) {
		return $Lang{$s}{en};
	}
	elsif (defined $Lang{$s}{fr}) {
		return $Lang{$s}{fr};
	}
	else {
		return '';
	}
}


# Load overrides from %SiteLang

print "SiteLang - overrides \n";


foreach my $key (keys %SiteLang) {
	print "SiteLang{$key} \n";

	$Lang{$key} = {};
	foreach my $l (keys %{$SiteLang{$key}}) {
		$Lang{$key}{$l} = $SiteLang{$key}{$l};
		print "SiteLang{$key}{$l} \n";
	}
}


foreach my $l (@Langs) {
	$CanonicalLang{$l} = {};	 # To map 'a-completer' to 'A compléter',
}

foreach my $key (keys %Lang) {
	next if $key =~ /^bottom_title|bottom_content$/;
	if ((defined $Lang{$key}{fr}) or (defined $Lang{$key}{en})) {
		foreach my $l (@Langs) {

			my $short_l = undef;
			if ($l =~ /_/) {
				$short_l = $`,  # pt_pt
			}

			if (not defined $Lang{$key}{$l}) {
				if ((defined $short_l) and (defined $Lang{$key}{$short_l})) {
					$Lang{$key}{$l} = $Lang{$key}{$short_l};
				}
				elsif (defined $Lang{$key}{en}) {
					$Lang{$key}{$l} = $Lang{$key}{en};
				}
				else {
					$Lang{$key}{$l} = $Lang{$key}{fr};
				}
			}

			my $tagid = get_fileid($Lang{$key}{$l});

			$CanonicalLang{$l}{$tagid} = $Lang{$key}{$l};
		}
	}
}


1;