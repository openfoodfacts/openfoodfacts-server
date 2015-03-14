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
	es => 'producto',
	it => 'prodotto',
#	ru => 'продукт',
    ro => 'produs',
	ar => 'mountaj',
	pt => 'produto',
	he => 'mozar',
	nl => 'product',
},
brands => { 
	fr => 'marque',
	de => 'marke', # lowercase for URLs
	en => 'brand',
	es => 'marca',
	it => 'marca',
	ro => 'marca',
#	ru => 'марка',
	ar => '3alama-tijariya', # need to be in ascii: letters A to Z
	pt => 'marca', 
	he => 'mutag',
	nl => 'merk',  
},
categories => {
	fr => 'categorie',
	de => 'kategorie',
	en => 'category',
	es => 'categoria',
	it => 'categoria',
	ro => 'categorie',
#	ru => 'категория',
	ar => 'atassnifate',
	pt => 'categoria',
	he => 'categoria',
	nl => 'categorie',    
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
	it => 'imballaggio',
	ro => 'ambalaj',
#	ru => 'упаковка',
	ar => 'ata3bia',
	pt => 'embalagem',
	he => 'ariza',  
	nl => 'verpakking',  
},
emb_codes => {
	fr => 'code-emballeur',
	de => 'produzenten-Code',
	en => 'packager-code',
	es => 'codigo-de-envasador',
	it => 'codice-imballaggio',
	ro => 'cod-de-ambalare',
#	ru => 'код',
	ar => 'ramz-el-mou3abi',
	pt => 'codigo-do-empacotador',
	pt_pt => 'codigo-de-embalador',
	he => 'cod-emb',   
	nl => 'verpakkerscode', 
},
cities => {
	fr => 'commune',
	de => 'stadt',
	en => 'city',
	it => 'citta',
	es => 'ciudad',
	ro => 'oras',
#	ru => 'город',
	ar => 'almoudoun',
	pt => 'cidade',
	he => 'ir',
	nl => 'stad',    
},
origins => { 
	fr => 'origine',
	de => 'herkunft',
	en => 'origin',
	it => 'origine',
	es => 'origen',
	ro => 'provenienta',
#	ru => 'источник',
	ar => 'almassdar',
	pt => 'origem',
	he => 'makor',  
	nl => 'herkomst',  
},
manufacturing_places => { 
	fr => 'lieu-de-fabrication',
	de => 'herstellungsort',
	en => 'manufacturing-place', 
	es => 'lugar-de-fabricacion',
	pt_pt => 'local-de-fabrico',
	ro => 'locatia-de-fabricatie',
	nl => 'productielocatie',
},
purchase_places => {
	fr => 'lieu-de-vente',
	de => 'verkaufsort',
	en => 'purchase-place',
	it => 'luogo-d-acquisto',
	es => 'sitio-de-compra',
	ro => 'locatia-de-achizitie',
#	ru => 'где-куплено',
	ar => 'nikate-alBay3',
	pt => 'local-de-compra',
	he => 'mekom-harekhisha',
	nl => 'verkoopslocatie',  
},
stores => { 
	fr => 'magasin',
	de => 'geschaeft',
	en => 'store',
	it => 'negozio',
	es => 'tienda',
	ro => 'magazin',
#	ru => 'магазин',
	ar => 'almatajir',
	pt => 'loja',
	he => 'khanut',
	nl => 'winkel', 
},
countries => { 
	fr => 'pays',
	de => 'land',
	en => 'country',
	es => 'pais',
	he => 'medina',
	pt => 'país',
	ro => 'tara',
	nl => 'land',
},
ingredients => { 
	fr => 'ingredient',
	de => 'zutat',
	en => 'ingredient',
	es => 'ingrediente',
	it => 'ingrediente',
	ro => 'ingredient',
#	ru => 'состав',
	ar => 'almoukawinate',
	pt => 'ingrediente',
	he => 'markivim', 
	nl => 'ingredient',
},
labels => { 
	fr => 'label',
	de => 'label',
	en => 'label',
	es => 'etiqueta',
	it => 'etichetta',
    ro => 'eticheta',
#	ru => 'этикетка',
	ar => 'al3alama',
	pt => 'etiqueta',
	he => 'tavit', 
	nl => 'label',
},
nutriments => {
	fr => 'nutriment',
	de => 'naehrstoff',
	en => 'nutrient',
	es => 'nutriente',
	it => 'nutriente',
	ro => 'nutriente',
#	ru => 'пищевая-ценность',
	ar => 'ghithae',
	pt => 'nutriente',
	he => 'arakhim-tzunatiyim', 
	nl => 'voedingsstof',
},
traces => { 
	fr => 'trace',
	de => 'spur',
	en => 'trace',
	es => 'traza',
	it => 'traccia',
	ro => 'urma',
#	ru => 'содержит',
	ar => 'athar',
	pt => 'traco',
	pt_pt => 'vestigio',
	he => 'ikvot', 
	nl => 'spoor',
},
users => {
	fr => 'contributeur',
	de => 'beitragszahler',
	en => 'contributor',
	es => 'contribuyente',
	it => 'contributore',
	ro => 'contributor',
#	ru => 'участник',
	ar => 'almousstakhdimoun',
	pt => 'colaborador',
	he => 'torem', 
	nl => 'gebruiker',
},
photographers => {
	fr => 'photographe',
	de => 'fotograf',
	en => 'photographer',
	ar => 'moussawir' ,
	pt => 'fotografo',
	ro => 'fotograf',
	es => 'fotografo',
	he => 'tzalam',
	nl => 'fotograaf',
},
informers => {
	fr => 'informateur',
	de => 'informant',
	en => 'informer',
	ar => 'moukhbir',
	pt => 'informante',
	pt_pt => 'informador',
	ro => 'informator',
	es => 'informante',
	he => 'meyadea', 
	nl => 'informant',
},
correctors => {
	fr => 'correcteur',
	de => 'korrekteur',
	en => 'corrector',
	ar => 'moussahih',
	pt => 'corretor',
	pt_pt => 'revisor',
	ro => 'corector',
	es => 'corrector',
	he => 'metaken', 
	nl => 'corrector',
},
checkers => {
	fr => 'verificateur',
	de => 'pruefer',
	en => 'checker',
	ar => 'mourakib',
	pt => 'verificador',
	ro => 'verificator',
	es => 'verificador',
	he => 'bodek', 
	nl => 'verificateur',
},
states => {
	fr => 'etat',
    de => 'status',
	en => 'state',
#	ar => 'الحاله',
	pt => 'estado',
	ro => 'status',
	es => 'estado',
	he => 'matzav', 
	nl => 'status',
},
additives => { 
	fr => 'additif',
	de => 'zusatzstoff',
	en => 'additive',
	es => 'aditivo',
	it => 'additivo',
	ro => 'aditiv',
#	ru => 'добавка',
	ar => 'mouthafat',
	pt => 'aditivo',
	he => 'tosefet',
	nl => 'additief', 
},
ingredients_from_palm_oil => {
	fr => "ingredients-issus-de-l-huile-de-palme",
	de => "zutaten-aus-palmoel",
	en => "ingredients-from-palm-oil",
	ro => 'ingrediente-din-ulei-de-palmier',
#	ru => "вещества-из-пальмового-масла",
	ar => 'mawad-mousstakhraja-min-zayt-nakhil',
	pt => 'ingredientes-de-oleo-de-palma',
	es => 'ingredientes-con-aceite-de-palma',
	he => 'rekhivim-mishemen-dkalim', 
	nl => 'ingredienten-uit-palmolie',
},
ingredients_that_may_be_from_palm_oil => {
	fr => "ingredients-pouvant-etre-issus-de-l-huile-de-palme",
	de => "zutaten-die-möglicherweise-palmoel-beinhalten",
	en => "ingredients-that-may-be-from-palm-oil",
	ro => 'ingerdiente-care-ar-putea-fi-din-ulei-de-palmier',
#	ru => "вещества-возможно-из-пальмового-масла",
	ar => 'mawad-kad-takoun-mousstakhraja-mina-nakhil',
	pt => 'ingredientes-que-podem-ser-de-oleo-de-palma',
	es => 'ingredientes-que-pueden-proceder-de-aceite-de-palma',
	he => 'rekhivim-sheasuyim-lihiyot-mishemen-dkalim', 
	nl => 'ingredienten-die-mogelijk-palmolie-bevatten',
},
allergens => { 
	fr => 'allergene',
	de => 'allergen',
	en => 'allergen',
	es => 'alergeno',
	it => 'allergene',
	ro => 'alergen',
#	ru => 'аллергены',
	ar => 'moussabib-hassassiya',
	pt => 'alergenico',
	he => 'khomer-alergeni', 
	nl => 'allergeen',
},
missions => { 
	fr => 'mission',
	en => 'mission',
	es => 'mision',
	de => 'mission',
	it => 'scopo',
	ro => 'misiune',
#	ru => 'назначение',
	ar => 'mouhima',
	pt => 'missao',
	he => 'messima', 
	nl => 'missie',
},
nutrient_levels => {
	en => 'nutrient-level',
	de => 'naehrwert-stufe',
	fr => 'repere-nutritionnel',
	es => 'valor-nutricional',
	he => 'ramat-khomrey-hamazon',
	pt => 'nivel-nutricional',
	ro => 'valoare-nutritionala',
	nl => 'voedingswaarde',
},
known_nutrients => {
	en => 'known-nutrient',
	de => 'bekannte-naehrwerte',
	fr => 'nutriment-connu',
	es => 'nutriente-conocido',
	pt => 'nutriente-conhecido',
	he => 'khomrey-mazon-yeduim',
	ro => 'nutrienti-cunoscuti',
	nl => 'gekende-ingredienten',
},
unknown_nutrients => {
	en => 'unknown-nutrient',
	de => 'unbekannte-naehrwerte',
	fr => 'nutriment-inconnus',
	es => 'nutriente-desconocido',
	pt => 'nutriente-desconhecido',
	he => 'khmorey-mazon-bilti-yeduim',
	ro => 'nutrienti-necunoscuti',
	nl => 'onbekende-ingredienten',
},
entry_dates => {
	en => "entry-date",
	fr => "date-d-ajout",
},
last_edit_dates => {
	en => "last-edit-date",
	fr => "date-de-derniere-modification",
},
nutrition_grades => {
	en => "nutrition-grade",
	fr => "note-nutritionnelle",
},

);

# Note: a lot of plurals are currently missing below, commented-out are the singulars that need to be changed to plurals

# Please do not add accents and caps in the strings below.

%tag_type_plural = (
products => { 
	fr => 'produits',
	de => 'produkte',
	en => 'products',
	es => 'productos',
	it => 'prodotti',
#	ar => 'mountaj',
	pt => 'produtos',
	ro => 'produse',
#	he => 'mozar',
	nl => 'producten',
},
brands => { 
	fr => 'marques',
	de => 'marken',
	en => 'brands',
	es => 'marcas',
	it => 'marcas',
	ro => 'marci',
#	ru => 'марка',
#	ar =>'3alama-tijariya', # need to be in ascii: letters A to Z
	pt => 'marcas', 
#	he => 'mutag', 
	nl => 'merken', 
},
categories => {
	fr => 'categories',
	de => 'kategorien',
	en => 'categories',
	es => 'categorias',
	it => 'categorias',
#	ru => 'категория',
    ro => 'categorii',
#	ar =>  'atassnifate',
	pt => 'categorias',
#	he => 'categoria',
	nl => 'categorieen',    
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
	es => 'envase',
#	it => 'imballaggio',
#	ru => 'упаковка',
#	ar => 'ata3bia',
	pt => 'embalagens',
#	he => 'ariza',
	ro => 'ambalaje',
	nl => 'verpakkingen',
},
emb_codes => {
	fr => 'codes-emballeurs',
	de => 'produzenten-codes',
	en => 'packager-codes',
	es => 'codigos-de-envasadores',
#	it => 'codice-imballaggio',
#	ru => 'код',
#	ar => 'ramz-el-mou3abi',
	pt => 'codigos-do-empacotador',
	pt_pt => 'codigos-de-embalador',
	ro => 'coduri-de-ambalare',
#	he => 'cod-emb',   
	nl => 'verpakkerscodes', 
},
cities => {
	fr => 'communes',
	de => 'staedte',
	en => 'cities',
#	it => 'citta',
	es => 'ciudades',
#	ru => 'город',
#	ar => 'almoudoun',
	pt => 'cidades',
	ro => 'orase',
#	he => 'ir',    
	nl => 'steden',
},
origins => { 
	fr => 'origines',
	de => 'herkuenfte',
	en => 'origins',
#	it => 'origine',
	es => 'origenes',
#	ru => 'источник',
#	ar => 'almassdar',
	pt => 'origens',
	ro => 'origini',
#	he => 'makor',  
	nl => 'herkomst',  
},
manufacturing_places => {
	fr => 'lieux-de-fabrication',
	de => 'herstellungsorte',
	en => 'manufacturing-places', 
	es => 'lugares-de-fabricacion',
	pt_pt => 'locais-de-fabrico',
	ro => 'locatii-de-fabricare',
	nl => 'productielocaties',
},
purchase_places => {
	fr => 'lieux-de-vente',
	de => 'verkaufsorte',
	en => 'purchase-places',
#	it => 'luogo-d-acquisto',
	es => 'sitios-de-compra',
#	ru => 'где-куплено',
#	ar => 'nikate-alBay3',
	pt => 'locais-de-compra',
#	he => 'mekom-harekhisha',
	ro => 'locatii-de-achizitie',
	nl => 'verkoopslocaties',
},
stores => { 
	fr => 'magasins',
	de => 'geschaefte',
	en => 'stores',
#	it => 'negozio',
	es => 'tiendas',
#	ru => 'магазин',
#	ar => 'almatajir',
	pt => 'lojas',
#	he => 'khanut',
	ro => 'magazine',
	nl => 'winkels',
},
countries => { 
	fr => 'pays',
	de => 'länder',
	en => 'countries',
	es => 'paises',
	he => 'medina',
	pt => 'paises',
	ro => 'tari',
	nl => 'landen',
},
ingredients => { 
	fr => 'ingredients',
	de => 'zutaten',
	en => 'ingredients',
	es => 'ingredientes',
	it => 'ingredientes',
#	ru => 'состав',
#	ar => 'almoukawinate',
	pt => 'ingredientes',
#	he => 'markivim',
	ro => 'ingrediente',
	nl => 'ingredienten',
},
labels => { 
	fr => 'labels',
	de => 'labels',
	en => 'labels',
	es => 'etiquetas',
	it => 'etichettas',
#	ru => 'этикетка',
#	ar => 'al3alama',
	pt => 'etiquetas',
#	he => 'tavit',
	ro => 'etichete',
	nl => 'labels',
},
nutriments => {
	fr => 'nutriments',
	de => 'naehrstoffe',
	en => 'nutrients',
	es => 'nutrientes',
	it => 'nutrientes',
#	ru => 'пищевая-ценность',
#	ar => 'ghithae',
	pt => 'nutrientes',
#	he => 'arakhim-tzunatiyim',
	ro => 'nutrienti',
	nl => 'voedingsstoffen',
},
traces => { 
	fr => 'traces',
	de => 'spuren',
	en => 'traces',
	es => 'trazas',
#	it => 'traccia',
#	ru => 'содержит',
#	ar => 'athar',
	pt => 'tracos',
	pt_pt => 'vestigios',
#	he => 'ikvot',
	ro => 'urme',
	nl => 'sporen',
},
users => {
	fr => 'contributeurs',
	de => 'beitragszahler',
	en => 'contributors',
	es => 'contribuyentes',
#	it => 'contributore',
#	ru => 'участник',
#	ar => 'almousstakhdimoun',
	pt => 'colaboradores',
#	he => 'torem',
    ro => 'contributori',
	nl => 'gebruikers',
},
photographers => {
	fr => 'photographes',
	de => 'fotografen',
	en => 'photographers',
#	ar => 'moussawir' ,
	pt => 'fotografos',
	es => 'fotografos',
#	he => 'tzalam',
    ro => 'fotografi',
	nl => 'fotografen',
},
informers => {
	fr => 'informateurs',
	de => 'informanten',
	en => 'informers',
#	ar => 'moukhbir',
	pt => 'informantes',
	pt_pt => 'informadores',
	es => 'informantes',
#	he => 'meyadea',
    ro => 'informatori',
	nl => 'informanten',
},
correctors => {
	fr => 'correcteurs',
	de => 'korrektoren',
	en => 'correctors',
#	ar => 'moussahih',
	pt => 'corretores',
	pt_pt => 'revisores',
	es => 'correctores',
#	he => 'metaken',
    ro => 'corectori',
	nl => 'correctoren',
},
checkers => {
	fr => 'verificateurs',
	de => 'pruefer',
	en => 'checkers',
#	ar => 'mourakib',
	pt => 'verificadores',
	es => 'verificadores',
#	he => 'bodek',
    ro => 'verificatori',
	nl => 'verificateurs',
},
states => {
	fr => 'etats',
    de => 'status',
	en => 'states',
#	ar => 'الحاله',
	pt => 'estados',
	es => 'estados',
#	he => 'matzav',
    ro => 'statusuri',
	nl => 'statussen',
},
additives => { 
	fr => 'additifs',
	de => 'zusatzstoffe',
	en => 'additives',
	es => 'aditivos',
#	it => 'additivo',
#	ru => 'добавка',
#	ar => 'mouthafat',
	pt => 'aditivos',
#	he => 'tosefet',
    ro => 'aditivi',
	nl => 'additieven',
},
ingredients_from_palm_oil => {
	fr => "ingredients-issus-de-l-huile-de-palme",
	de => 'zutaten-aus-Palmoel',
	en => "ingredients-from-palm-oil",
#	ru => "вещества-из-пальмового-масла",
	ar => 'mawad-mousstakhraja-min-zayt-nakhil',
	pt => 'ingredientes-de-oleo-de-palma',
	es => 'ingredientes-con-aceite-de-palma',
	he => 'rekhivim-mishemen-dkalim',
	ro => 'ingrediente-din-ulei-de-palmier',
	nl => 'ingredienten-uit-palmolie',
},
ingredients_that_may_be_from_palm_oil => {
	fr => "ingredients-pouvant-etre-issus-de-l-huile-de-palme",
	de => 'zutaten-die-möglicherweise-Palmoel-beinhalten',
	en => "ingredients-that-may-be-from-palm-oil",
#	ru => "вещества-возможно-из-пальмового-масла",
	ar => 'mawad-kad-takoun-mousstakhraja-mina-nakhil',
	pt => 'ingredientes-que-podem-ser-de-oleo-de-palma',
	es => 'ingredientes-que-pueden-proceder-de-aceite-de-palma',
	he => 'rekhivim-sheasuyim-lihiyot-mishemen-dkalim',
	ro => 'ingrediente-care-ar-putea-fi-din-ulei-de-palmier',
	nl => 'ingredienten-die-mogelijk-palmolie-bevatten',
},
allergens => { 
	fr => 'allergenes',
	de => 'allergene',
	en => 'allergens',
	es => 'alergenos',
#	it => 'allergene',
#	ru => 'аллергены',
#	ar => 'moussabib-hassassiya',
	pt => 'alergenicos',
#	he => 'khomer-alergeni',
    ro => 'alergeni',
	nl => 'allergenen',
},
missions => { 
	fr => 'missions',
	de => 'missionen',
	en => 'missions',
	es => 'misiones',
#	it => 'scopo',
#	ru => 'назначение',
#	ar => 'mouhima',
	pt => 'missoes',
#	he => 'messima',
    ro => 'misiuni',
	nl => 'missies',
},
nutrient_levels => {
	en => 'nutrient-levels',
	de => 'naehrwert-Stufen',
	fr => 'reperes-nutritionnels',
	es => 'valores-nutricionales',
#	he => 'ramat-khomrey-hamazon', 
	pt => 'valores-nutricionais',
	ro => 'valori-nutritionale',
	nl => 'voedingswaarden',
},
known_nutrients => {
	en => 'known-nutrients',
	de => 'bekannte-Naehrwerte',
	fr => 'nutriments-connus',
	es => 'nutrientes-conocidos',
	pt => 'nutrientes-conhecidos',
	he => 'khomrey-mazon-yeduim',
	ro => 'nutrienti-cunoscuti',
	nl => 'gekende ingredienten',
},
unknown_nutrients => {
	en => 'unknown-nutrients',
	de => 'unbekannte-Naerhwerte',
	fr => 'nutriments-inconnus',
	es => 'nutrientes-desconocidos',
	pt => 'nutrientes-desconhecidos', 
	he => 'khmorey-mazon-bilti-yeduim',
	ro => 'nutrienti-necunoscuti',
	nl => 'onbekende ingredienten',
},
entry_dates => {
	en => "entry-dates",
	fr => "dates-d-ajout",
},
last_edit_dates => {
	en => "last-edit-dates",
	fr => "dates-de-derniere-modification",
},
nutrition_grades => {
	en => "nutrition-grades",
	fr => "notes-nutritionnelles",
},
);


# Below this point, non-Roman characters can be used

%Lang = (

lang_de => { 
	de => 'Deutsch',
	fr => 'Allemand',
	en => 'German',
	es => 'Alemán',
	it => 'Tedesco',
	ru => 'Russisch',
	ar => 'الالمانية',
	pt => 'Alemão',
	ro => 'Germană',
	he => 'גרמנית',
	nl => 'Duits',
},

lang_es => { 
	es => 'Español',
	fr => 'Espagnol',
	en => 'Spanish',
	de => 'Spanisch',
	it => 'Spagnolo',
	ru => 'Ruso',
	ar => 'الاسبانية',
	pt => 'Espanhol',
	ro => 'Spaniolă',
	he => 'ספרדית',
	nl => 'Spaans',
},

lang_el => {
	en => 'Greek',
	fr => 'Grec',
	el => 'Ελληνικά',
},

lang_en => { 
	fr => 'Anglais',
	en => 'English',
	de => 'Englisch',
	es => 'Inglés',
	it => 'Inglese',
	ru => 'Russian',
	ar => 'الانجليزية',
	pt => 'Inglês',
	ro => 'Engleză',
	he => 'אנגלית',
	nl => 'Engels',
},

lang_fr => { 
	fr => 'Français',
	en => 'French',
	de => 'Französisch',
	es => 'Francés',
	it => 'Francese',
	ru => 'Russe',
	ar => 'الفرنسية',
	pt => 'Francês',
	ro => 'Franceză',
	he => 'צרפתית',
	nl => 'Frans',
},

lang_it => {
	it => 'Italiano',
	fr => 'Italien',
	en => 'Italian',
	es => 'Italiano',
	ru => 'Russo',
	de => 'Italienisch',
	ar => 'الايطالية',
	pt => 'Italiano',
	ro => 'Italiană',
	he => 'איטלקית',
	nl => 'Italiaans',
},

lang_ja => {
	en => 'Japanese',
	fr => 'Japonais',
	ja => '日本語',
},

lang_ko => {
	en => 'Korean',
	fr => 'Coréen',
	ko => '한국어',
},

lang_nl => {
	nl => 'Nederlands',
	fr => 'Néerlandais',
	en => 'Dutch',
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
	en => 'Polish',
	de => 'Polnisch',
	es => 'Polaco',
	it => 'Polacco',
	ar => 'البولندية',
	pt => 'Polonês',
	pt_pt => 'Polaco',
	ro => 'Poloneză',
	he => 'פולנית',
	nl => 'Pools',
},

lang_pt => { 
	pt => 'Português',
	fr => 'Portugais',
	en => 'Portuguese',
	de => 'Portugiesisch',
	es => 'Portugués',
	it => 'Portoghese',
	ar => 'البرتغالية',
	he => 'פורטוגלית',
	ro => 'Portugheză',
	nl => 'Portugees',
},

lang_th => {
	en => 'Thai',
	fr => 'Thaï',
	th => 'ไทย',
},

lang_vi => { 
	vi => 'Tiếng Việt',
	fr => 'Vietnamien',
	en => 'Vietnamese',
	es => 'Vietnamita',
	de => 'Vietnamesisch',
	it => 'Vietnamita',
	ar => 'الفيتنامية',
	pt => 'Vietnamita',
	ro => 'Vietnameză',
	he => 'וייטנאמית',
	nl => 'Vietnamees',
},

lang_zh => {
	en => 'Chinese',
	de => 'Chinesisch',
	fr => 'Chinois',
	zh => '中文',
	es => 'Chino',
	ar => 'الصينية',
	pt => 'Chinês',
	ro => 'Chineză',
	he => 'סינית',
	nl => 'Chinees',
},

lang_ru => {
	fr => 'Russe',
	en => 'Russian',
	de => 'Russisch',
	es => 'Ruso',
	it => 'Russo',
	ar => 'الروسية',
	pt => 'Russo',
	ro => 'Rusă',
	he => 'רוסית',
	nl => 'Russisch',
},

lang_he => {
	ar => 'العبرية',
	de => 'Hebräisch',
	en => 'Hebrew',
	es => 'Hebreo',
	fr => 'Hébreu',
	he => 'עברית',
	it => 'Ebraico',
	nl => 'Hebreeuws',
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
	it => 'Rumeno',
	nl => 'Roemeens',
},

lang_other => { 
	ru => 'другой язык', 
	fr => 'autre langue',
	en => 'other language',
	de => 'andere Sprache',
	es => 'otro idioma',
	it => 'altra lingua',
	ar => 'لغات اخرى',
	pt => 'outro idioma',
	ro => 'altă limbă',
	he => 'שפה אחרת',
	nl => 'andere taal',
},

lang => {  
	fr => 'Langue principale sur l\'emballage du produit',
	en => 'Main language on the product',
	it => 'Lingua principale sull\'imballaggio del prodotto',   
	es => 'Idioma principal en el producto',
	de => 'Hauptsprache auf dem Produkt',
	ro => 'Limba principală de pe produs',
	ru => 'Основной язык продукта',
	ar => 'اللغه الرئيسية علي المنتج',
	pt => 'Idioma principal no produto',
	he => 'השפה העיקרית על המוצר',
	nl => 'Hoofdtaal op de verpakking van het product',
},

site_name => {
	fr => 'Open Food Facts',
	en => 'Open Food Facts',
	es => 'Open Food Facts',
	de => 'Open Food Facts',
	ru => 'Open Food Facts',
	ar => 'Open Food Facts',
	pt => 'Open Food Facts',
	ro => 'Open Food Facts',
	he => 'Open Food Facts',
	nl => 'Open Food Facts',
},

site_description => { 
	ru => "Совместная, открытая и свободная база данных об ингридиентах, питательности и другой информации по пищевым продуктам мира", 
	fr => "Ingrédients, composition nutritionnelle et information sur les produits alimentaires du monde entier dans une base de données libre et ouverte",
	en => "A collaborative, free and open database of ingredients, nutrition facts and information on food products from around the world",
	de => "Zutaten, Nährwertangaben und weitere Informationen über Nahrungsmittel aus der ganzen Welt in einer offenen und freien Datenbank",
	es => "Ingredientes, información nutricional e información sobre los alimentos del mundo entero en una base de datos libre y abierta",
	it => "Ingredienti, composizione nutrizionale e informazioni sui prodotti alimentari del mondo intero su una base di dati libera e aperta",
	ar => "مكونات, قيمة غذائية و معلومات حول المنتجات الغذائية في العالم الكل في قاعدة بيانات حرة و مفتوحة",
	pt => 'Uma base de dados aberta e colaborativa sobre ingredientes, informações nutricionais e alimentos de todo o mundo',
	ro => 'O bază de date liberă, colaborativă și deschisă de ingrediente, valori nutriționale și informații despre produsele alimentare din toată lumea',
	he => "מסד נתונים שיתופי, חופשי ופתוח של רכיבים, הרכבים תזונתיים ומידע על מוצרי מזון מכל רחבי העולם.",
	nl => 'Ingrediënten, nutritionele samenstelling en informatie over voedingsmiddelen uit de hele wereld in een open en vrije databank',
},

og_image_url => {
	fr => 'http://fr.openfoodfacts.org/images/misc/openfoodfacts-logo-fr-356.png',
	en => 'http://world.openfoodfacts.org/images/misc/openfoodfacts-logo-en-356.png',
	es => 'http://es.openfoodfacts.org/images/misc/openfoodfacts-logo-es-356.png',
	it => 'http://it.openfoodfacts.org/images/misc/openfoodfacts-logo-it-356.png',
	de => 'http://de.openfoodfacts.org/images/misc/openfoodfacts-logo-de-356.png',
	ar => 'http://world.openfoodfacts.org/images/misc/openfoodfacts-logo-ar-356.png',
	pt => 'http://world.openfoodfacts.org/images/misc/openfoodfacts-logo-pt-356.png',
	ro => 'http://ro.openfoodfacts.org/images/misc/openfoodfacts-logo-356.png',
	he => 'http://world.openfoodfacts.org/images/misc/openfoodfacts-logo-he-356.png',
	nl => 'http://nl.openfoodfacts.org/images/misc/openfoodfacts-logo-nl-356.png',    
},

twitter_account => {
	fr => 'OpenFoodFactsFr',
	en => 'OpenFoodFacts',
	de => 'OpenFoodFactsDe',
	es => 'OpenFoodFactsEs',
	it => 'OpenFoodFactsIt',
	ar => 'OpenFoodFactsAr',
	ro => 'OpenFoodFacts',
	pt => 'OpenFoodFactsPt',
	nl => 'OpenFoodFactsNl',
},

products => {
	fr => 'produits',
	en => 'products',
	it => 'prodotti',
	pt => 'produtos',
	de => 'Produkte',
	es => 'productos',
	ru => 'продукты',
	ro => 'produse',
	ar => 'المنتوجات',
	he => 'מוצרים',
	nl => 'producten',
},

add_user => { 
	ru => 'Зарегистрироваться',
	fr => "S'inscrire",
	en => "Register",
	it => "Registrarsi",
	es => 'Registrarse',
	de => 'Anmelden',
	ar => 'التسجيل',
	pt => 'Registre-se',
	pt_pt => 'Registe-se',
	ro => 'Înregistrare',
	he => 'הרשמה',
	nl => 'Registreren',
},

edit_user => { 
	fr => 'Paramètres du compte',
	en => 'Account parameters',
	es => 'Parámetros de la cuenta',
	it => 'Parametri account',
	de => "Benutzerangaben",
	ar => 'إعدادات المستخدم',
	pt => 'Parâmetros de conta',
	ro => 'Parametrii contului',
	he => 'משתני החשבון',
	nl => 'Accountinstellingen',
},

delete_user => { 
	fr => 'Effacer un utilisateur',
	en => 'Delete an user',
	es => 'Eliminar un usuario',
	it => 'Cancellazione account',
	de => "Benutzer löschen",
	ar => 'حذف المستخدم',
	pt => 'apagar usuário',
	pt_pt => 'Apagar utilizador',
	ro => 'Ștergere utilizator',
	he => 'מחיקת משתמש',
	nl => 'Verwijder gebruiker',
},

add_user_confirm => { 
	fr => '<p>Merci de votre inscription. Vous pouvez maintenant vous identifier sur le site pour ajouter et modifier des produits.</p>',
	en => '<p>Thanks for joining. You can now sign-in on the site to add and edit products.</p>',
	es => '<p>Gracias por registrarse. A partir de ahora puede identificarse en el sitio para añadir o modificar productos.<p>',
	de => '<p>Vielen Dank für ihre Registrierung. Sie können sich jetzt auf der Seite anmelden um Produkte hinzuzufügen oder abzuändern.</p>',
	it => '<p>Grazie per la vostra iscrizione. Da adesso potete identificarvi sul sito per aggiungere e/o modificare dei prodotti.</p>',
	ar => '<p>شكرا على انضمامك إلينا ، يمكتك الآن تسجيل دخولك و إضافة  أو تعديل المنتجات.</p>',
	pt => '<p>Obrigado pela sua inscrição. Pode aceder ao site para adicionar ou editar produtos.</p>',
	ro => '<p>Vă mulțumim pentru înscriere. De acum vă puteți autentifica pe site pentru a adăuga și modifica produse.</p>',
	he => '<p>תודה לך על הצטרפותך. מעכשיו תהיה לך אפשרות להיכנס לאתר כדי להוסיף ולערוך מוצרים.</p>',
	nl => '<p>Bedankt voor uw inschrijving. U kan nu inloggen op de site om producten toe te voegen of te bewerken.</p>',
},

add_user_email_subject => { 
	fr => 'Merci de votre inscription sur Open Food Facts',
	en => 'Thanks for joining Open Food Facts',
	de => 'Vielen Dank für ihre Anmeldung auf Open Food Facts',
	es => 'Gracias por registrarse en Open Food Facts',
	it => 'Grazie per la vostra iscrizione a Open Food Facts',
	ar => 'شكرا على انضمامك لموقعنا Open Food Facts',
	pt => 'Obrigado por se juntar ao Open Food Facts',
	ro => 'Vă mulțumim pentru înscrierea la Open Food Facts',
	he => 'תודה לך על הצטרפותך ל־Open Food Facts',
	nl => 'Bedankt voor uw inschrijving op Open Food Facts',
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

Hartelijk bedankt voor uw inschrijving op http://openfoodfacts.org
Dit is uw gebruikersnaam :

Gebruikersnaam : <USERID>

U kan nu inloggen op de site om producten toe te voegen of te bewerken.

U kan ook lid worden van onze facebookgroep voor gebruikers:
https://www.facebook.com/groups/356858984359591/

Open Food Facts is een open source-project waaraan u veel meer dan enkel producten kan toevoegen: uw energie, enthousiasme en ideeën!

U kan uw suggesties delen op het ideeënforum:
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
	nl => 'Wijziging van uw paswoord op Open Food Facts',
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
	es => '<p>Los datos de su cuenta han sido modificados correctamente.</p>',
	it => '<p>I parametri del suo account sono stati modificati.</p>',
	pt => '<p>Os dados de sua conta foram modificados.</p>',
	pt_pt => '<p>As informações da sua conta foram modificados.</p>',
	ro => '<p>Parametrii contului dumneavoastră au fost schimbați.</p>',
	he => '<p>משתני החשבון שלך הוחלפו.</p>',
	nl => '<p>Uw accountinstellingen werden succesvol gewijzigd</p>',

},

edit_profile => {
	fr => "Modifier votre profil public",
	de => "Bearbeite dein öffentliches Profil",
	en => "Edit your public profile",
	es => "Edite su perfil público",
	it => "Modificare il vostro profilo pubblico",
	ar => 'تعديل إعداداتك الشخصية',
	pt => 'Edite seu perfil público',
	pt_pt => 'Edite o seu perfil público',
	ro => 'Modificați profilul public',
	he => "עריכת הפרופיל הציבורי שלך",
	nl => 'Uw publiek profiel aanpassen',
},  
	
edit_profile_msg => {
	fr => "Les informations ci-dessous figurent dans votre profil public.",
	de => "Die Informationen unten sind in deinem öffentlichen Profil sichtbar.",
	en => "Information below is visible in your public profile.",
	es => "La información que se encuentra debajo estará disponible en su perfil público.",
	it => "Le informazioni qui sotto appaiono nel vostro profilo pubblico.",
	ar => 'هذه المعلومات تظهر في صفحتك و يطلع عليها كل المستخدمون',
	pt => 'As informações abaixo estão visíveis no seu perfil público',
	ro => 'Informația următoare este vizibilă în profilul dumneavoastră public',
	he => "המידע שלהלן מופיע בפרופיל הציבורי שלך.",
	nl => 'De onderstaande informatie is zichtbaar op uw publiek profiel',
},

edit_profile_confirm => {
	fr => "Les modifications de votre profil public ont été enregistrées.",
	de => "Die Änderungen an deinem öffentlichen Profil wurden gespeichert.",
	en => "Changes to your public profile have been saved.",
	es => "Los cambios en su perfil público han sido guardados.",
	it => "Le modifiche del suo profilo pubblico sono state registrate.",
	ar => 'لقد تم تعديل بياناتكم بنجاح',
	pt => 'As modificações no seu perfil público foram salvas.',
	pt_pt => 'As modificações ao seu perfil público foram guardadas.',
	ro => 'Modificările asupra profilului public au fost salvate.',
	he => "השינויים לפרופיל הציבורי שלך נשמרו.",
	nl => 'De aanpassingen van uw publiek profiel werden opgeslagen',
},

session_title => {
	fr => 'Se connecter',
	de => 'Anmelden',
	en => 'Sign-in',
	es => 'Iniciar sesión',
	it => 'connettersi',
	ar => 'تسجيل الدخول',
	pt => 'Iniciar sessão',
	ro => 'Autentificare',
	he => 'כניסה',
	nl => 'Aanmelden',
},
	
login_register_title => {
	fr => 'Se connecter',
	de => 'Anmelden',
	en => 'Sign-in',
	es => 'Iniciar sesión',
	it => 'connettersi',
	ar => 'تسجيل الدخول',
	pt => 'Iniciar sessão',
	ro => 'Autentificare',
	he => 'כניסה',
	nl => 'Aanmelden',
},

login_username_email => {
	fr => "Nom d'utilisateur ou adresse e-mail :",
	de => 'Benutzername oder E-Mail-Adresse:',
	en => "Username or e-mail address:",
	es => "Nombre de usuario o dirección de correo electrónico:",
	ar =>   "اسم الدخول او البريد الالكتروني :",
	pt => 'Nome de usuário e e-mail:',
	pt_pt => 'Nome de utilizador ou e-mail:',
	ro => 'Numele de utilizator sau adresa de e-mail:',
	he => "שם משתמש או כתובת דוא״ל:",
	nl => 'Gebruikersnaam of e-mailadres',
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
<p>U moet zich aanmelden om producten toe te voegen of te bewerken.</p>

<p>Als u nog geen account hebt op Open Food Facts, kan u <a href="/cgi/user.pl">zich registreren in 30 seconden</a>.</p>
HTML
,

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
<input type="submit" tabindex="4" name=".submit" value="Se connecter" class="jbutton" />
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
<input type="submit" tabindex="4" name=".submit" value="Sign-in" class="jbutton" />
</form>
<p>Noch nicht registriert? <a href="/cgi/user.pl">Erstelle ein Benutzerkonto</a>.</p>
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
<input type="submit" tabindex="4" name=".submit" value="Sign-in" class="jbutton" />
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
<input type="submit" tabindex="4" name=".submit" value="Sign-in" class="jbutton" />
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
<input type="submit" tabindex="4" name=".submit" value="Connettersi" class="jbutton" />
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
<input type="submit" tabindex="4" name=".submit" value="Sign-in" class="jbutton" />
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
<input type="submit" tabindex="4" name=".submit" value="Sign-in" class="jbutton" />
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
<input type="submit" tabindex="4" name=".submit" value="Autentificare" class="jbutton" />
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
<input type="submit" tabindex="4" name=".submit" value="כניסה" class="jbutton" />
</form>
<p>לא נרשמת עדיין? <a href="/cgi/user.pl">ניתן ללחוץ כאן ליצירת חשבון חדש</a>.</p>
HTML
,

	nl => <<HTML
<p>Meld u aan om producten toe te voegen of te bewerken.</p>

<form method="post" action="/cgi/session.pl">
Gebruikersnaam of e-mailadres:<br />
<input type="text" name="user_id" tabindex="1" style="width:220px;" /><br />
Paswoord<br />
<input type="password" name="password" tabindex="2" style="width:220px;" /><br />
<input type="checkbox" name="remember_me" value="on" tabindex="3" /><label>Aangemeld blijven</label><br />
<input type="submit" tabindex="4" name=".submit" value="Sign-in" class="jbutton" />
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
},

on_the_blog_title => {
	fr => "Actualité",
	de => "Neuigkeiten",
	en => "News",
	es => "Noticias",
	it => "Attualità",
	ar => "الاخبار",
	pt => 'Notícias',
	ro => 'Noutăți',
	he => "חדשות",
	nl => 'Nieuws',
},  
on_the_blog_content => {
	en => <<HTML
<p>To learn more about Open Food Facts, visit <a href="http://en.blog.openfoodfacts.org">our blog</a>!</p>
<p>Recent news:</p>
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
},

bottom_title => {
	fr => "Partez en mission",
	xes => "Participa en la misión",
	xit => "Partite in missione",   
	xpt => "Participe na missão",
	ro => 'Participați la misiune',
	he => "הרתמו למשימה",
	nl => 'Neem deel aan de missie',
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
<p>Werk mee aan Open Food Facts door producten toe te voegen en win sterren door deel te nemen  <a href="/missions">aan de missies</a> !</p>
HTML
,
},

language => {
	fr => 'fr-FR',
	de => 'de-DE',
	en => 'en-US',
	es => 'es-ES',
	it => 'it-IT',
	ar => 'ar-AR',
	pt => 'pt-BR',
	pt_pt => 'pt-PT',
	ro => 'ro-RO',
	he => 'he-IL',
	nl => 'nl-BE',
},

facebook_locale => {
	fr => 'fr_FR',
	en => 'en_US',
	es => 'es_ES',
	it => 'it_IT',
	de => 'de_DE',
	pt => 'pt_BR',
	pt_pt => 'pt_PT',
	ro => 'ro_RO',
	ar => 'ar_AR',
	he => 'he_IL',
	nl => 'nl_BE',
	#ok what do i put here for brazil ?
#For brazil it is pt_BR
},

username_or_email => {
	fr => 'Nom d\'utilisateur ou adresse e-mail',
	de => 'Benutzername oder E-Mail-Adresse',
	en => 'Username or email address',
	es => 'Nombre de usuario o dirección de correo electrónico',
	it => 'Username o indirizzo e-mail',
	pt => 'Nome de usuário ou endereço de email', 
	pt_pt => 'Nome de utilizador ou endereço de e-mail',
	ro => 'Numele de utilizator sau adresa de e-mail',
	he => 'שם משתמש או כתובת דוא״ל',
	nl => 'Gebruikersnaam of e-mailadres',
},

password => {
	fr => 'Mot de passe :',
	de => 'Passwort:',
	en => 'Password:',
	es => 'Contraseña:',
	it => 'Password:',
	pt => 'Senha',
	pt_pt => 'Palavra-passe',
	ro => 'Parola',
	he => 'ססמה:',
	nl => 'Paswoord',
},

remember_me => {
	fr => 'Se souvenir de moi',
	de => 'Angemeldet bleiben',
	en => 'Remember me',
	es => 'Mantenerme conectado',
	it => 'Ricordami',
	pt => 'Lembre-se de mim',
	pt_pt => 'Manter sessão iniciada',
	ro => 'Ține-mă minte',
	he => 'שמירת הפרטים שלי',
	nl => 'Aangemeld blijven',
},

login_and_add_product => {
	fr => 'Se connecter et ajouter le produit',
	de => 'Einloggen und ein Produkt hinzufügen',
	en => 'Sign-in and add the product',
	es => 'Inicia la sesión y añade el producto',
	it => 'Connettersi e aggiungere prodotto',
	ar => 'تسجيل الدخول لاضافه منتج',
	pt => 'Ligue-se e adicione o produto',
	pt_pt => 'Inicie sessão e adicione o produto',
	ro => 'Autentificați-vă și adăugați produsul',
	he => 'ניתן להיכנס ולהוסיף את המוצר',
	nl => 'Inloggen en het product toevoegen',
},

login_and_edit_product => {
	fr => 'Se connecter et modifier la fiche du produit',
	de => 'Einloggen und das Produkt bearbeiten',
	en => 'Sign-in and edit the product',
	es => 'Inicia la sesión y modifica el producto',
	it => 'Connettersi e modificare la scheda prodotto',
	pt => 'Ligue-se e edite o produto',
	pt_pt => 'Inicie sessão e edite o produto',
	ro => 'Autentificați-vă și modificați produsul',
	he => 'כניסה ועריכת המוצר',
	nl => 'Inloggen en het product bewerken',
},

pages => {
	fr => "Pages : ",
	de => 'Seiten: ',
	en => "Pages:",
	es => "Páginas:",
	it => "Pagine:",
	ar => "الصفحات:",
	pt => 'Páginas:',
	ro => 'Pagini',
	he => "עמודים:",
	nl => 'Pagina\'s',
},

previous => {
	fr => "Précédente",
	de => 'Vorherige',
	en => "Previous",
	es => "Anterior",
	it => "Precedente",
	pt => 'Anterior',
	ro => 'Anterior',
	he => "הקודם",
	nl => 'Vorige',
},

next => {
	fr => "Suivante",
	de => 'Nächste',
	en => "Next",
	es => "Siguiente",
	it => "Successiva",
	pt => 'Próxima',
	ro => 'Următor',
	he => "הבא",
	nl => 'Volgende',
},

page_x_out_of_y => {
	fr => "Page %d sur %d.",
	de => 'Seite %d von %d',
	en => "Page %d out of %d.",
	es => "Página %d de %d.",
	it => "Pagina %d di %d.",
	pt => 'Página %d de %d',
	ro => 'Pagina %d din %d',
	he => "עמוד %d מתוך %d.",
	nl => 'Pagina %d van %d.',
},

edit => {
	fr => 'modifier',
	de => 'bearbeiten',
	en => 'edit',
	es => 'modificar',
	pt => 'editar',
	ro => 'modificare',
	he => 'עריכה',
	nl => 'Bewerken',
},

hello => {
	fr => 'Bonjour',
	en => 'Hello',
	de => 'Hallo',
	es => 'Buenos días',
	it => 'Ciao',
	ar => 'مرحبا',
	pt => 'Olá',
	ro => 'Salut',
	he => 'שלום',
	nl => 'Hallo',
},

goodbye => {
	fr => 'A bientôt !',
	de => 'Auf Wiedersehen !',
	en => 'See you soon!',
	es => '¡Hasta pronto!',
	it => 'A presto!',
	ar => 'مع السلامه!',
	pt => 'Até logo!',
	ro => 'La revedere!',
	he => 'להתראות!',
	nl => 'Tot ziens',
},

sep => {
	fr => ' ',
	en => '',
	es => '',
	pt => '',
	he => '',
	nl => '',
},

connected_with_facebook => {
	fr => "Vous êtes connecté via votre compte Facebook.",
	de => 'Du bist verbunden zu deinem Facebook-Account.',
	en => "You are connected with your Facebook account.",
	es => "Estás conectado a través de tu cuenta en Facebook.",
	it => "Siete connessi attraverso il vostro profilo Facebook",
	pt => 'Você está ligado através de sua conta do Facebook',
	pt_pt => 'Você está autenticado através da sua conta do Facebook',
	ro => 'Sunteți conectat cu contul de Facebook.',
	he => "נכנסת לחשבון הפייסבוק שלך.",
	nl => 'U bent verbonden via uw Facebookaccount',
},

you_are_connected_as_x => {
	fr => "Vous êtes connecté en tant que %s.",
	de => 'Du bist verbunden als %s',
	en => "You are connected as %s.",
	es => "Estás conectado como %s.",
	it => "Siete connessi come %s.",
	pt => 'Você está ligado como %s',
	pt_pt => 'Você está autenticado como %s.',
	ro => 'Sunteți conectat cu %s.',
	he => "נכנסת בשם %s",
	nl => 'U bent verbonden als %s',
},

signout => {
	fr => "Se déconnecter",
	de => 'Ausloggen',
	en => "Sign-out",
	es => "Cerrar sesión",
	it => "Disconnettersi",
	pt => 'Sair',
	pt_pt => 'Terminar sessão',
	ro => 'Deconectare',
	he => "יציאה",
	nl => 'Afmelden',
},

error_invalid_address => {
	fr => "Adresse invalide.",
	de => 'Ungültige Adresse.',
	en => "Invalid address.",
	es => "Dirección inválida.",
	pt => 'Endereço inválido',
	ro => 'Adresă invalidă.',
	he => "הכתובת שגויה.",
	nl => 'Ongeldig adres',
},


name => {
	fr => "Nom",
	en => "Name",
	de => "Name",
	es => "Nombre",
	it => "Nome",
	pt => 'Nome',
	ro => 'Nume',
	he => "שם",
	nl => 'Naam',
},


email => {
	fr => "Adresse e-mail",
	de => "E-Mail-Adresse",
	en => "e-mail address",
	es => "Dirección de correo electrónico",
	it => "Indirizzo e-mail",
	pt => 'Endereço de e-mail',
	ro => 'Adresa de e-mail',
	he => "כתובת דוא״ל",
	nl => 'E-mailadres',
},

username => {
	fr => "Nom d'utilisateur",
	de => "Benutzername",
	en => "User name",
	es => "Nombre de usuario",
	it => "Nome dell'utilizzatore",
	pt => 'Nome de usuário',
	pt_pt => 'Nome de utilizador',
	ro => 'Nume de utilizator',
	he => "שם משתמש",
	nl => 'Gebruikersnaam',
},

username_info => {
	fr => "(lettres non accentuées, chiffres et/ou tirets)",
	de => '(Buchstaben ohne Umlaute, Zahlen und/oder Bindestriche)',
	en => "(non-accented letters, digits and/or dashes)",
	es => "(letras no acentuadas, números y/o guiones)",
	it => "(lettere non accentate, numeri e/o trattini)",
	pt => '(letras não acentuadas, digitos e/ou traços)',
	ro => '(litere neaccentuate, cifre și/sau liniuțe)',
	he => "(אותיות לטיניות קטנות, ספרות ו/או מקפים)",
	nl => '(letters zonder accenten, cijfers en/of streepjes)',
},

twitter => {
	fr => "Nom d'utilisateur Twitter (optionel)",
	de => 'Twitter Benutzername (optional)',
	en => "Twitter username (optional)",
	es => "Nombre de usuario en Twitter (opcional)",
	it => "Nome dâutilizzatore su Twitter (facoltativo)",
	pt => 'Nome de usuário no Twitter (opcional)',
	pt_pt => 'Nome de utilizador no Twitter (opcional)',
	ro => 'Numele de utilizator Twitter (opțional)',
	he => "שם משתמש בטוויטר",
	nl => 'Gebruikersnaam Twitter (optioneel)',
},

password => {
	fr => "Mot de passe",
	de => "Passwort",
	en => "Password",
	es => "Contraseña",
	it => "Password",
	pt => 'Senha',
	pt_pt => 'Palavra-passe',
	ro => 'Parola',
	he => "ססמה",
	nl => 'Paswoord',
},

password_confirm => {
	fr => "Confirmation du mot de passe",
	de => 'Passwort bestätigen',
	en => "Confirm password",
	es => "Confirmar la contraseña",
	it => "Conferma la password",
	pt => 'Confirme sua senha',
	pt_pt => 'Confirme a palavra-passe',
	ro => 'Confirmare parolă',
	he => "אימות הססמה",
	nl => 'Bevestig paswoord',
},

unsubscribe_info => {
	fr => "Vous pouvez vous désabonner de la lettre d'information à tout moment et facilement.",
	de => 'Du kannst die Liste jederzeit deabonnieren.',
	en => "You can unsubscribe from the lists at any time.",
	es => "Puedes darte de baja de las listas cuando lo desees.",
	it => "In qualsiasi momento e facilmente potete cancellarvi dalla lettera d'informazioni",
	pt => 'Você pode anular as inscrições das listas a qualquer momento',
	pt_pt => 'Pode anular as suas inscrições nas listas a qualquer momento',
	ro => 'Vă puteți dezabona de la liste în orice moment.',
	he => "ניתן לבטל את המינוי מרשימות אלה בכל עת.",
	nl => 'U kan zich makkelijk en op elk moment uitschrijven voor de nieuwsbrief',
},

website => {
	fr => "Adresse de blog ou de site web",
	de => 'Seiten- oder Blogadresse',
	en => "Site or blog address",
	es => "Dirección del blog o del sitio web",
	it => "Indirizzo del blog o del sito web",
	pt => 'Endereço do seu site ou blog',
	ro => 'Adresă site sau blog',
	he => "כתובת אתר או בלוג",
	nl => 'Adres van website of blog',
},


about => {
	fr => "Présentation",
	de => 'Über uns',
	en => "About me",
	es => "Presentación",
	it => "Mi presento",
	pt => 'Sobre mim',
	ro => 'Despre mine',
	he => "פרטים עלי",
	nl => 'Over mij',
},

error_no_name => {
	fr => "Vous devez entrer un nom, prénom ou pseudonyme.",
	de => 'Sie müssen einen Namen oder Spitznamen angeben.',
	en => "You need to enter a name or nickname.",
	es => "Debes escribir un nombre o seudónimo.",
	it => "Immetti nome, cognome o pseudonimo",
	pt => 'Você precisa incluir um nome ou apelido',
	pt_pt => 'Você precisa de inserir um nome ou apelido',
	ro => 'Trebuie să introduceți un nume sau un pseudonim.',
	he => "עליך לרשום שם או כינוי.",
	nl => 'Vul een naam of bijnaam in',
},

error_invalid_email => {
	fr => "L'adresse e-mail est invalide.",
	de => 'Ungültige E-Mail-Adresse',
	en => "Invalid e-mail address",
	es => "La dirección de correo electrónico no es válida",
	it => "Indirizzo e-mail non valido",
	pt => 'Endereço de e-mail inválido',
	ro => 'Adresă de e-mail invalidă',
	he => "כתובת הדוא״ל שגויה",
	nl => 'Ongeldig e-mailadres',
},


error_email_already_in_use => {
	fr => "L'adresse e-mail est déjà utilisée par un autre utilisateur. Peut-être avez-vous déjà un autre compte ? Vous pouvez <a href=\"/cgi/reset_password.pl\">réinitialiser le mot de passe</a> de votre autre compte.",
	de => 'Die angegebene E-Mail-Adresse ist bereits in Verwendung. Möglicherweise habane Sie schon ein Konto? Sie können das Passwort ihres Kontos <a href=\"/cgi/reset_password.pl\">zurücksetzen</a>.',
	en => "The e-mail address is already used by another user. Maybe you already have an account? You can  <a href=\"/cgi/reset_password.pl\">reset the password</a> of your other account.",
	es => "La dirección de correo electrónico ya está siendo utilizada por otro usuario. Tal vez, haya creado ya una cuenta. Aquí puede  <a href=\"/cgi/reset_password.pl\">restablecer la contraseña</a> de la otra cuenta.",
	it => "L'inidirzzo e-mail è già in uso. Hai un altro account di posta? Puoi <a href=\"/cgi/reset_password.pl\">reinserire la password<a> dell'altro account.",
	pt => 'Esse endereço de email já está sendo utilizado por outro usuário. Talvez você já tenha uma conta? Você pode <a href=\"/cgi/reset_password.pl\">modificar a senha</a> da sua outra conta.',
	pt_pt => 'Este endereço de email já está a ser utilizado por outro utilizador. Talvez já tenha uma conta? Pode <a href=\"/cgi/reset_password.pl\">alerar a palavra-passe</a> da sua outra conta.',
	ro => 'Adresa de email este deja folosită de către un alt utilizator. Poate că deja aveți un cont? Vă puteți <a href=\"/cgi/reset_password.pl\">reseta parola</a> celuilalt cont.',
	he => "כתובת הדוא״ל כבר בשימוש על־ידי משתמש אחר. אולי כבר יש לך חשבון? ניתן <a href=\"/cgi/reset_password.pl\">לאפס את הססמה</a> לחשבון שלך.",
	nl => "Dit e-mailadres wordt al gebruikt door een andere gebruiker. Misschien hebt u al een account? U kan het paswoord van uw ander account  <a href=\"/cgi/reset_password.pl\">resetten</a> of your other account.",
},

error_no_username => {
	fr => "Vous devez entrer un nom d'utilisateur.",
	en => "You need to enter a user name",
	de => "Sie müssen einen Benutzernamen eingeben",
	es => "Necesitas introducir un nombre de usuario",
	it => "Inserisci il nome dell'utilizzatore/username",
	pt => 'Você precisa incluir um nome de usuário',
	pt_pt => 'Precisa de inserir um nome de utilizador',
	ro => 'Trebuie să introduceți un nume de utilizator',
	he => "עליך לרשום שם משתמש",
	nl => 'U moet een gebruikersnaam ingeven',
},

error_username_not_available => {
	fr => "Ce nom d'utilisateur existe déjà, choisissez en un autre.",
	de => 'Dieser Benutzername wird bereits benutzt, bitte wählen Sie einen anderen.',
	en => "This username already exists, please choose another.",
	es => "El nombre de usuario que ha escogido ya existe, por favor escoja otro.",
	it => "Questo username esiste già, per favore prova con un altro",   
	pt => 'Esse nome de usuário já existe, por favor escolha outro',  
	pt_pt => 'Este nome de utilizador já existe, escolha outro por favor',
	ro => 'Acest nume de utilizator există deja, vă rog alegeți altul.',
	he => "שם משתמש זה כבר קיים, נא לבחור באחד אחר.",
	nl => 'Deze gebruikersnaam bestaat reeds, gelieve een andere te kiezen',
},

error_invalid_username => {
	fr => "Le nom d'utilisateur doit être composé de lettres minuscules sans accents, de tirets et/ou de chiffres.",
	de => 'Der Benutzername darf nur Buchstaben ohne Umlaute, Zahlen und Bindestriche enthalten.',
	en => "The user name must contain only unaccented letters, digits and dashes.",
	es => "El nombre de usuario debe contener sólo caracteres sin acentuar, dígitos y guiones.",
	it => "Lo username può contenere solo caratteri senza accento, trattini e cifre",
	pt => "O nome de usuário deve conter somente letras não acentuadas, dígitos e traços.",
	pt_pt => "O nome de utilizador deve conter apenas letras não acentuadas, dígitos e traços.",
	ro => 'Numele de utilizator trebuie să conțină doar litere neaccentuate, cifre și liniuțe.',
	he => "שם המשתמש יכול להכיל רק אותיות לטיניות קטנות, ספרות ומקפים.",
	nl => 'De gebruikersnaam mag enkel kleine letters zonder accenten, streepjes en/of cijfers bevatten',
},

error_invalid_password => {
	fr => "Le mot de passe doit comporter au moins 6 caractères.",
	de => "Das Passwort muss mindestens 6 Zeichen lang sein.",
	en => "The password needs to be a least 6 characters long.",
	es => "La contraseña debe contener al menos 6 caracteres.",
	it => "La password deve contenere almeno 6 caratteri",
	pt => 'A senha deve conter pelo menos 6 caracteres',
	pt_pt => 'A palavra-passe deve conter pelo menos 6 caracteres',
	ro => 'Parola trebuie să fie lungă de cel puțin 6 caractere.',
	he => "הססמה חייבת להיות באורך של 6 תווים לפחות.",
	nl => 'Het paswoord moet uit minstens 6 tekens bestaan',
},

error_different_passwords => {
	fr => "Le mot de passe et sa confirmation sont différents.",
	de => 'Die Passwort und die Wiederholung müssen übereinstimmen.',
	en => "The password and confirmation password are different.",
	es => "La contraseña y su confirmación son diferentes.",
	it => "La password non corrisponde",
	pt => 'A senha e a senha de confirmação são diferentes',
	pt_pt => 'As palavras-passe são diferentes.',
	ro => 'Parola și parola de confirmare sunt diferite.',
	he => "הססמה ואימות הססמה אינם זהים.",
	nl => 'Het paswoord stemt niet overeen met de bevestiging',
},

error_invalid_user => {
	fr => "Impossible de lire l'utilisateur.",
	de => 'Ungültiger Benutzer',
	en => "Invalid user.",
	es => "Usuario no válido.",
	it => "Utilizzatore non valido",
	pt => 'Usuário inválido',
	pt_pt => 'Utilizador inválido',
	ro => 'Utilizator invalid.',
	he => "משתמש שגוי.",
	nl => 'Ongeldige gebruiker',
},

error_no_permission => {
	fr => "Permission refusée.",
	en => "Permission denied.",
	de => "Zugriff verweigert.",
	es => "Permiso denegado.",
	it => "Permesso rifiutato",
	pt => "Permissão negada",
	ro => 'Acces refuzat.',
	he => "ההרשאה נדחתה",
	nl => 'Toegang geweigerd',
},

correct_the_following_errors => {
	fr => "Merci de corriger les erreurs suivantes :",
	en => "Please correct the following errors:",
	de => "Bitte korrigieren Sie die folgenden Fehler:",
	es => "Por favor, corrija los siguientes errores:",
	it => "Correggere gli errori seguenti, grazie",
	pt => 'Por favor corrija os seguintes erros:',
	ro => 'Vă rugăm corectați erorile următoare:',
	he => "נא לתקן את השגיאות הבאות:",
	nl => 'Gelieve de volgende fouten te verbeteren',
},

error_database => {
	fr => "Une erreur est survenue en lisant la base de données, essayez de recharger la page.",
	de => "Beim Lesen der Daten ist ein Fehler aufgetreten, bitte aktualisieren Sie die Seite.",
	en => "An error occured while reading the data, try to refresh the page.",
	es => "Se produjo un error durante la lectura de la base de datos, intente recargar la página.",
	it => "Un errore è occorso durante la lettura dei dati, prova a ricaricare la pagina",
	pt => "Ocorreu um erro durante a leitura dos dados, tente atualizar a página.",
	ro => "A apărut o eroare în timp ce citeam datele, încercați să reîncărcați pagina.",
	he => "אירעה שגיאה בעת קריאת הנתונים, נא לנסות לרענן את העמוד.",
	nl => 'Er is een fout opgetreden tijdens het lezen van de gegevens, gelieve de pagina opnieuw te laden',
},

no_products => {
	fr => "Pas de produits.",
	de => "Keine Produkte.",
	en => "No products.",
	es => "No hay productos.",
	it => "Nessun prodotto",
	pt => "Não há produtos.",
	ro => "Nici un produs.",
	he => "אין מוצרים.",
	nl => 'Geen producten',
},

'1_product' => {
	fr => "1 produit :",
	de => "1 Produkt:",
	en => "1 product:",
	es => "1 producto:",
	it => "1 prodotto:",
	pt => "1 produto:",
	ro => "1 produs:",
	he => "מוצר 1:",
	nl => "1 product:",
},

n_products => {
	fr => "%d produits :",
	de => "%d Produkte:",
	en => "%d products:",
	es => "%d productos:",
	it => "%d prodotti:",
	pt => "%d produtos:",
	ro => "%d produse:",
	he => "%d מוצרים:",
	nl => "%d producten:",
},

signin_before_submit => {
	fr => "Si vous êtes déjà inscrit sur <SITE>, identifiez-vous (\"Se connecter\" dans la colonne de droite) avant de remplir ce formulaire.",
	de => "Wenn Sie bereits ein Benutzerkonto auf <SITE> haben, melden Sie sich bitte an, bevor sie das Formular ausfüllen.",
	en => "If you already have an account on <SITE>, please sign-in before filling this form.",
	es => "Si ya tiene una cuenta en <SITE>, por favor, inicie la sesión antes de rellenar este formulario.",
	it => "Se siete già iscritti su <SITE>, per favore identificatevi prima di compilare questo formulario",
	pt =>"Se você já possui uma conta no <SITE>, por favor entre antes de preencher este formulário.",
	pt_pt =>"Se já possui uma conta no <SITE>, inicie a sessão antes de preencher este formulário.",
	ro => "Dacă deja aveți un cont pe <SITE>, vă rog autentificați-vă înainte de a completa acest formular.",
	he => "אם כבר יש לך חשבון ב־<SITE>, נא להיכנס בטרם מילוי הטופס הזה.",
	nl => "Indien u al een account heeft op <SITE>, gelieve u dan eerst aan te melden voordat u dit formulier invult",
},


error_bad_login_password => {
	fr => "Mauvais nom d'utilisateur ou mot de passe. <a href=\"/cgi/reset_password.pl\">Mot de passe oublié ?</a>", 
	de=> "Ungültiger Benutzername oder Passwort. <a href=\"/cgi/reset_password.pl\">Passwort vergessen?</a>",
	en => "Incorrect user name or password. <a href=\"/cgi/reset_password.pl\">Forgotten password?</a>",
	es => "Nombre de usuario o contraseña incorecto/a. <a href=\"/cgi/reset_password.pl\">¿Olvidaste tu contraseña?</a>",
	it => "Username o password sbagliate.  <a href=\"/cgi/reset_password.pl\">Password dimenticata? </a>",
	pt =>"Nome de usuário ou senha incorretos. <a href=\"/cgi/reset_password.pl\">Esqueceu sua senha?</a>",
	pt_pt =>"Nome de utilizador ou palavra-passe incorretos. <a href=\"/cgi/reset_password.pl\">Esqueceu-se da sua palavra-passe?</a>",
	ro => 'Nume de utilizator sau parolă incorectă. <a href=\"/cgi/reset_password.pl\">Parolă uitată?</a>',
	he => "שם המשתמש או הססמה שגויים. <a href=\"/cgi/reset_password.pl\">שכחת את הססמה?</a>",
	nl => "Gebruikersnaam of paswoord ongeldig. <a href=\"/cgi/reset_password.pl\">Paswoord vergeten?</a>",
},

subscribe => {
	fr => 'S\'abonner',
	de => 'Abonnieren',
	en => 'Subscribe',
	es => 'Suscribir',
	it => 'Aderire',
	pt => 'Subscrever',
	ro => 'Abonare',
	he => 'מינוי',
	nl => 'Abonneren',
},

unsubscribe => {
	fr => 'Se désabonner',
	de => 'Deabonnieren',
	en => 'Unsubscribe',
	es => 'Darse de baja',
	it => 'Cancellarsi',
	pt => 'Desinscrever',
	ro => 'Dezabonare',
	he => 'ביטול המינוי',
	nl => 'Uitschrijven',
},

_and_ => {
	fr => ' et ',
	de => ' und ',
	en => ' and ',
	es => ' y ',
	cs => ' a ',
	it => ' e ',
	pt => ' e ',
	ro => ' și ',
	he => ' וגם ',
	nl => ' en ',
},

reset_password =>  {
	fr => 'Réinitialiser le mot de passe',
	de => 'Passwort zurücksetzen',
	en => 'Reset password',
	es => 'Restablecer la contraseña',
	it => 'Modificare la password',
	pt => 'Alterar a palavra-passe',
	ro => 'Resetare parolă',
	he => 'איפוס הססמה',
	nl => 'Paswoord resetten',
},

userid_or_email => {
	fr => 'Nom d\'utilisateur ou adresse e-mail : ',
	de => 'Benutzername oder E-Mail-Adresse: ',
	en => 'Username or e-mail address: ',
	es => 'Nombre de usuario o dirección de correo electrónico: ',
	it => 'Nome d\'utilizzatore o indirizzo e-mail',
	pt => 'Nome de usuário ou endereço de e-mail',
	pt_pt => 'Nome de utilizador ou endereço de e-mail',
	ro => 'Nume de utilizator sau adresa de e-mail',
	he => 'שם משתמש או כתובת דוא״ל: ',
	nl => 'Gebruikersnaam of e-mailadres: ',
},

reset_password_reset =>  {
	fr => 'Votre mot de passe a été changé. Vous pouvez maintenant vous identifier avec ce mot de passe.',
	de => 'Ihr Passwort wurden geändert. Sie können sich nun mit dem neuen Passwort anmelden.',
	en => 'Your password has been changed. You can now log-in with this password.',
	es => 'La contraseña ha sido cambiada correctamente. Ahora puede iniciar la sesión con la nueva contraseña.',
	it => 'La password è stata modificata. Potete ora identificarvi con la nuova password.',
	pt => 'Sua senha foi modificada. Você pode iniciar sua sessão com a nova senha.',
	pt_pt => 'A sua palavra-passe foi modificada. Pode iniciar a sua sessão com a nova palavra-passe.',
	ro => 'Parola a fost schimbată. De acum vă puteți autentifica cu această parolă.',
	he => 'הססמה שלך הוחלפה. מעתה ניתן להיכנס עם ססמה זו.',
	nl => 'Uw paswoord werd gewijzigd. U kan zich nu aanmelden met het nieuwe paswoord.',
},

reset_password_send_email =>  {
	fr => 'Un e-mail avec un lien pour vous permettre de changer le mot de passe a été envoyé à l\'adresse e-mail associée à votre compte.',
	de => 'Eine E-Mail mit einem Zurücksetzungslink für Ihr Passwort wurde zu der von Ihnen angegebenen E-Mail-Adresse verschickt.',
	en => 'An email with a link to reset your password has been sent to the e-mail address associated with your account.',
	es => 'Se ha enviado un correo electrónico con un enlace para que pueda cambiar la contraseña asociada a su cuenta.',
	it => 'Una mail con un link per consentirvi di cambiare la password è stata inviata all\' indirizzo e-mail associato al vostro account.' ,
	pt => 'Um e-mail com um link para repor a sua senha foi enviado para o endereço de e-mail associado com a sua conta',
	ro => 'Un e-mail cu un link pentru resetarea parolei v-a fost trimis la adresa de e-mail asociată cu contul dumneavoastră.',
	he => 'הודעה עם קישור לאיפוס הססמה שלך נשלחה לכתובת הדוא״ל המשויכת עם החשבון שלך.',
	nl => 'Er werd een e-mail verstuurd met een link om uw paswoord te resetten naar het e-mailadres dat verbonden is aan uw account.',
},

reset_password_send_email_msg =>  {
	fr => 'Si vous avez oublié votre mot de passe, indiquez votre nom d\'utilisateur ou votre e-mail pour recevoir les instructions pour le réinitialiser.',
	en => 'If you have forgotten your password, fill-in your username or e-mail address to receive instructions for resetting your password.',
	es => 'Si ha olvidado su contraseña, introduzca su nombre de usuario o su dirección de correo electrónico donde recibirá las instrucciones necesarias para restablecerla.',
	it => 'Se avete scordato la password, indicate il vostro username o la vostra e-mail per ricevere le istruzioni per reimpostarla.',
	pt => 'Caso você tenha esquecido sua senha, preencha seu nome de usuário ou endereço de e-mail para receber instruções de como modificar a sua senha.',
	pt_pt => 'Caso se tenha esquecido da sua palavra-passe, preencha o seu nome de utilizador ou endereço de e-mail para receber instruções para repor mesma.',
	ro => 'Dacă v-ați uitat parola, completați numele de utilizator sau adresa de e-mail pentru a primi instrucțiuni despre resetarea parolei.',
	he => 'אם שכחת את הססמה שלך, נא למלא את שם המשתמש או את כתובת הדוא״ל שלך כדי לקבל הנחיות לאיפוס הססמה שלך.',
	nl => 'Indien u uw paswoord vergeten bent,vul dan uw gebruikersnaam of e-mailadres in en ontvang instructies om uw paswoord te resetten.',
	de => 'Falls Sie Ihr Passwort vergessen haben, geben Sie bitte Ihren Benutzernamen oder Ihre E-Mail-Adresse ein, um die Anweisungen für das Zurücksetzen Ihres Passworts zu bekommen',
},

reset_password_reset_msg =>  {
	fr => 'Entrez un nouveau mot de passe.',
	en => 'Enter a new password.',
	es => 'Introduzca una nueva contraseña.',
	it => 'Introdurre una nuova password' ,
	ar => 'ادخل كلمه مرور جديده',
	pt => 'Insira a nova senha',
	pt_pt => 'Insira a nova palavra-passe',
	ro => 'Introduceți o parolă nouă.',
	he => 'נא לרשום ססמה חדשה.',
	nl => 'Voer een nieuw paswoord in',
	de => 'bitte ein anderes Passwort einfügen',
},

error_reset_unknown_email =>  {
	fr => 'Il n\'existe pas de compte avec cette adresse e-mail',
	en => 'There is no account with this email',
	es => 'No existe ninguna cuenta asociada a este correo electrónico',
	it => 'Non esiste un account associato a questa e-mail',    
	pt => 'Nâo há conta associada a esse e-mail',
	pt_pt => 'Nâo há conta associada a este e-mail',
	ro => 'Nu există nici un cont cu această adresă de e-mail',
	he => 'אין חשבון עם כתובת דוא״ל שכזו',
	nl => 'Er is geen account aan dit e-mailadres verbonden',
	de => 'Kein Benutzerkonto mit dieser E-Mail-Adresse ist vorhanden',
},

error_reset_unknown_id =>  {
	fr => 'Ce nom d\'utilisateur n\'existe pas.',
	en => 'This username does not exist.',
	es => 'El nombre de usuario no existe.',
	it => 'Questo nome d\'utilizzatore/username non esiste',
	ar => 'اسم المستخدم غير موجود',
	pt => 'Esse nome de usuário não existe.',
	pt_pt => 'Este nome de utilizador não existe.',
	ro => 'Acest nume de utilizator nu există.',
	he => 'שם משתמש זה לא קיים.',
	nl => 'Deze gebruikersnaam bestaat niet',
	de => 'Dieser Benutzername ist nicht gültig',
},

error_reset_invalid_token =>  {
	fr => 'Le lien de réinitialisation de mot de passe est invalide ou a expiré.',
	en => 'The reset password link is invalid or has expired.',
	es => 'El enlace para restablecer la contraseña no es válido o ha caducado.',
	it => 'Il link per resettare la password non è valido oppure è scaduto' , 
	pt => 'O link para modificar a senha é inválido ou expirou.',
	pt_pt => 'O link para modificar a palavra-passe é inválido ou expirou.',
	ro => 'Link-ul pentru resetarea parolei este invalid sau a expirat.',
	he => 'הקישור לאיפוס הססמה שגוי או שתוקפו פג.',
	nl => 'De link om uw paswoord te resetten is ongeldig of bestaat niet meer',
	de => 'Das Link für das Zurücksetzen Ihres Passworts ist entweder ungültig oder ist abgelaufen',
},

error_reset_already_connected =>  {
	fr => 'Vous avez déjà une session ouverte.',
	en => 'You are already signed in.',
	es => 'Ya tiene una sesión abierta.',
	it => 'Avete già una sessione aperta',
	pt => 'Você já tem uma sessão aberta',
	pt_pt => 'Você já tem uma sessão iniciada',
	ro => 'Sunteți deja autentificați',
	he => 'כבר נכנסת.',
	nl => 'U bent reeds aangemeld',
	de => 'Sie sind schon eingeloggt',
},

lang => {
	fr => 'Langue principale',
	en => 'Main language',
	es => 'Idioma principal',
	it => 'Lingua principale',
	ar => 'اللغه الرئيسيه',
	pt => 'Idioma principal',
	ro => 'Limba principală',
	he => 'השפה העיקרית',
	nl => 'Hoofdtaal',
	de => 'Hauptsprache',
},

lang_note => {
	fr => 'Langue la plus utilisée et la plus mise en avant sur le produit',
	en => 'Language most present and most highlighted on the product',
	es => 'Idioma más utilizado en la mayor parte del producto',
	it => 'La lingua maggiormente utilizzata sul prodotto',
	pt => 'Idioma mais presente no produto',
	ro => 'Limba cea mai prezentă și mai evidentă pe produs',
	he => 'השפה המשמעותית והמודגשת ביותר על המוצר',
	nl => 'De taal die het meest gebruikt wordt op het product',
	de => 'Lieblingssprache für dieses Produkt',
},    

expiration_date => {
	fr => 'Date limite de consommation',
	en => 'Best before date',
	es => 'Fecha límite de consumo',
	it => 'Da utilizzare entro',
	pt => 'Data de validade',
	ro => 'A se consuma de preferință înainte de',
	he => 'תאריך אחרון לשימוש',
	nl => 'Houdbaarheidsdatum',
	de => 'Mindestens haltbar bis Datum',
},

expiration_date_note => {
	fr => "La date limite permet de repérer les changements des produits dans le temps et d'identifier la plus récente version.",
	en => "The expiration date is a way to track product changes over time and to identify the most recent version.",
	es => "La fecha límite de consumo permite seguir los cambios que se han ido produciendo en los productos a lo largo del tiempo y también identificar la versión más reciente.",
	it => "La data di scadenza permette di tracciare le modifiche dei prodotti nel tempo e riconoscere la versione più recente.",
	pt => 'A data de validade é uma forma de rastrear mudanças no produto ao longo do tempo e identificar sua versão mais recente.',
	pt_pt => 'A data de validade é uma forma de registar mudanças no produto ao longo do tempo e identificar a sua versão mais recente.',
	ro => 'Data de expirare este o modalitate de a urmări schimbările produsului de-a lungul timpului și pentru a identifica cea mai recentă versiune.',
	he => "תאריך התפוגה היא דרך נוספת לעקוב אחר שינויים במוצרים במשך הזמן ולזהות את הגרסה העדכנית ביותר.",
	nl => 'Dankzij de houdbaarheidsdatum is het mogelijk om veranderingen van het product over een bepaalde periode waar te nemen en om de meest recente versie te bepalen.',
},

product_name => {
	fr => "Nom du produit",
	en => "Product name",
	es => "Nombre del producto",
	it => "Nome del prodotto",
	pt => 'Nome do produto',
	ro => 'Numele produsului',
	he => "שם המוצר",
	nl => 'Productnaam',
	de => 'Produktname',

},
product_name_example => {
	fr => "Kinder Bueno White",
	en => "Kinder Bueno White",
	es => "Kinder Bueno White",
	it => "Kinder Bueno White",
	pt => 'Kinder Bueno White',
	ro => 'Kinder Bueno White',
	de => 'Kinder Bueno White',
	he => "קינדר בואנו לבן",
	nl => 'Kinder Bueno White',
},

generic_name => {
	fr => "Dénomination générique",
	en => "Common name",
	es => "Denominación general",
	it => "Nome generico",
	pt => 'Nome genérico',
	ro => 'Numele general',
	he => "שם נפוץ",
	nl => 'Algemene benaming',
},
generic_name_example => {
	fr => "Barre chocolatée au lait et aux noisettes",
	en => "Chocolate bar with milk and hazelnuts",
	es => "Tableta de chocolate con leche y avellanas",
	it => "Tavoletta di cioccolato al latte con nocciole",
	pt => 'Barra de chocolate com leite e avelãs',
	ro => 'Baton de ciocolată cu lapte și alune',
	he => "חטיף שוקולד עם חלב ושקדים",
	nl => 'Chocoladereep met melkchocolade en hazelnoten',
},
brands => {
	fr => "Marques",
	en => "Brands",
	de => "Marken",
	es => "Marcas",
	it => "Marche",
	pt => 'Marcas',
	ro => 'Mărci',
	he => 'מותגים', 
	nl => 'Merken',
},
brands_example => {
	fr => "Kinder Bueno White, Kinder Bueno, Kinder, Ferrero",
	en => "Kinder Bueno White, Kinder Bueno, Kinder, Ferrero",
	es => "Kinder Bueno White, Kinder Bueno, Kinder, Ferrero",
	it => "Kinder Bueno, Kinder, Ferrero",
	pt => 'Kinder Bueno White, Kinder Bueno, Ferrero',
	ro => 'Kinder Bueno White, Kinder Bueno, Kinder, Ferrero',
	he => "קינדר בואנו לבן, קינדר בואנו, פררו",
	nl => "Kinder Bueno White, Kinder Bueno, Kinder, Ferrero",
	de => "Kinder Bueno White, Kinder Bueno, Kinder, Ferrero",
},

quantity => {
	fr => "Quantité",
	en => "Quantity",
	es => "Cantidad",
	it => "Quantità",
	pt => "Quantidade",
	ro => 'Cantitate',
	he => "כמות",
	nl => "Hoeveelheid",
	de => "Menge",
},
quantity_example => {
	fr => "2 l, 250 g, 1 kg, 25 cl",
	en => "2 l, 250 g, 1 kg, 25 cl, 6 fl oz, 1 pound",
	es => "2 l, 250 g, 1 kg, 25 cl",
	it => "2 l, 250 g, 1 kg, 25 cl",
	pt => '2 l, 250 g, 1 kg, 250 ml',
	ro => '2 l, 250 g, 1 kg, 250 ml',
	he => "2 1, 250 ג, 1 ק״ג, 250 מ״ל",
	nl => "2 l, 250 g, 1 kg, 25 cl",
	de => "2 l, 250 g, 1 kg, 25 cl",
},

packaging => {
	fr => "Conditionnement",
	en => "Packaging",
	es => "Envases",
	it => "Confezionamento",
	pt => "Embalagem",
	ro => 'Ambalare',
	he => "אריזה",
	nl => "Verpakking",
	de => "Verpackung",
},

packaging_note => {
	fr => "Type de conditionnement, format, matière",
	en => "Packaging type, format, material",
	es => "Tipo de envase, formato, material",
	it => "Tipo di confezione, formato, materiale",
	pt => "Tipo de embalagem, formato, material",
	ro => 'Tipul de ambalaj, format, material',
	he => "סוג האריזה, מבנה, חומר",
	nl => "Soort verpakking, formaat, materiaal",
},

packaging_example => {
	fr => "Frais, Conserve, Sous-vide, Surgelé, Bouteille, Bocal, Boîte, Verre, Plastique, Carton...",
	en => "Fresh, Canned, Frozen, Bottle, Box, Glass, Plastic...",
	es => "Fresco, En conserva, Al vacío, Congelado, Botella, Tarro, Caja, Vidrio, Plástico, Cartón...",
	pt => "Fresco, Conserva, Vácuo, Congelado, Garrafa, Copo, Caixa, Vidro, Plástico, Cartão...", 
	it => "Fresco, Conserva/Lattina, Sottovuoto, Surgelato, Bottiglia, Vasetto, Barattolo, Vetro, Plastica, Cartone",
	ro => 'Proaspăt, Conservat, Înghețat, Îmbuteliat, Cutie, Sticlă, Plastic...',
	he => "טרי, בקופסת שימורים, קפוא, בקבוק, קופסה, זכוכית, פלסטיק...",
	nl => "Vers, Conserve, Vacuüm, Diepgevroren, Fles, Bokaal, Doos, Glas, Plastiek, Karton, ...",
},

categories => {
	fr => "Catégories",
	en => "Categories",
	de => "Kategorien",
	es => "Categorías",
	it => "Categorie",
	pt => "Categorias",
	ro => 'Categorii',
	he => "קטגוריות",
	nl => "Categorieën",
},

categories_example => {
	fr => "Sardines à l'huile d'olive, Mayonnaises allégées, Jus d'orange à base de concentré",
	en => "Sardines in olive oil, Orange juice from concentrate",
	es => "Sardinas en aceite de oliva, Mayonesa ligera, Zumo de naranja procedente de concentrado",
	it => "Sardine in olio di oliva, Succo d'arancia a base di concentrato", 
	pt => "Sardinha em óleo de oliva, Suco de laranja concentrado",
	pt_pt => "Sardinha em azeite, Sumo de laranja concentrado",
	ro => 'Sardine în ulei de măsline, Suc de portocale pe bază de concentrat',
	he => "סרדינים בשמן זית, מיץ תפוזים עשוי רכז",
	nl => "Sardines in olijfolie, Lightmayonaise, Sinaasappelsap op basis van geconcentreerd sap",
	de => "Sardinen in Olivenöl, Orangensaft aus Orangensaftkonzentrat",
},

categories_note => {
	fr => "Il suffit d'indiquer la catégorie la plus spécifique, les catégories \"parentes\" seront ajoutées automatiquement.",
	en => "Indicate only the most specific category. \"Parents\" categories will be automatically added.",
	es => "Indicar sólo la categoría más específica. Las categorías \"Padres\" serán añadidas automáticamente.",
	pt => "Indicar apenas a categoria mais específica. As categorias \"Pai\" serão adicionadas automaticamente.",
	it => "Indicare solo la categoria più specifica, le categorie \"Principali\" saranno aggiunte automaticamente",
	ro => "Indicați doar categoria cea mai specifică. Categorile \"Părinte\" vor fi adăugate automat.",
	he => "ציון הקטגוריה החשובה ביותר. קטגוריות „הורים“ יתווספו אוטומטית.",
	nl => "Duidt enkel de meest specifieke categorie aan. De \"verwante\" categorieën worden automatisch toegevoegd.",
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
	es => "Etiquetas, certificaciones, premios",
	pt => "Etiquetas, certificações, prêmios",
	ro => 'Etichete, certificări, premii',
	it => "Etichette, certificazioni, premi",
	he => "תוויות, אישורים, פרסים",
	nl => "Labels, certificaten, prijzen",
	de => "Labels, Zertifizierungen, Preise",
},

labels_example => {
	fr => "AB, Bio européen, Max Havelaar, Label Rouge, IGP, AOP, Saveur de l'Année 2012...",
	en => "Organic", # "Fairtrade USA, Fair trade, TransFair...",
	es => "Ecológico, Fairtrade-Max Havelaar, I.G.P., D.O.P., Sabor del año 2012...",
	pt => "Ecológico, Comércio Justo, Sabor do Ano 2012...",
	pt_pt => "Ecológico, Produto do Ano 2012, sem glúten, ...",
	ro => 'Bio',
	it => "IGP, IGT, DOP, Bio, Ecologico, Non OGM, gluten-free",
	he => "אורגני", "סחר הוגן, מיוצר בישראל",
	nl => "AB, Max Havelaar, Label Rouge, Organisch, Glutenvrij, Smaak van het jaar 2012, ...",
},

labels_note => {
	fr => "Indiquez les labels les plus spécifiques. Les catégories \"parentes\" comme 'Bio' ou 'Commerce équitable' seront ajoutées automatiquement.",
	en => "Indicate only the most specific labels. \"Parents\" labels will be added automatically.",
	pt => "Indicar apenas a categoria mais específica. As categorias \"Pai\" serão adicionadas automaticamente.",
	es => "Indicar sólo las etiquetas más específicas. Las categorías \"Padres\" como 'Eco' o 'Comercio Justo' serán añadidas automáticamente.",
	it => "Indicare solo le etichette più specifiche. Le categorie maggiori come 'Eco' o 'Commercio equo-solidale' saranno aggiunte in automatico.",
	ro => "Indicați doar eticheta cea mai specifică. Etichetele \"Părinte\" vor fi adăugate automat.",
	he => "יש לציין את התוויות הייחודיות בלבד. תוויות „הורים“ יתווספו אוטומטית.",
	nl => "Duidt enkel de meest specifieke labels aan. De \"verwante\" categorieën zoals 'Bio of ' Fair trade' worden automatisch toegevoegd",
},

origins => {
	fr => "Origine des ingrédients",
	en => "Origin of ingredients",
	es => "Origen de los ingredientes",
	it => "Origine",
	pt => "Origem do produto",
	ro => "Originea ingredientelor",
	he => "מקור",
	nl => "Herkomst van de ingrediënten",
	de => "Herkunft der Zutaten",
},

origins_example => {
	fr => "Vallée des Baux-de-Provence, Provence, France",
	en => "California, USA",
	es => "Montilla, Córdoba (provincia), Andalucía, España",
	pt => "Ribeira Grande, São Miguel, Açores, Portugal",
	he => "נס ציונה, ישראל",
	nl => "Leuven, Vlaams-Brabant, België",
	de => "Bayerisch, Allgäu, Schwäbisch-Hällisch",
},

origins_note_xxx => {
	fr => "Indiquer l'origine des ingrédients",
	en => "",
	es => "Indicar el origen de los ingredientes",
	pt => "Indicar nas duas entradas a origem indicada na etiqueta e possivelmente o seu tipo",
	ro => "Indicați originea ingredientelor",
	nl => "Geef de herkomst van de ingrediënten weer",
	de => "Herkunft der Zutaten kennzeichnen",
},

manufacturing_places => {
	fr => "Lieux de fabrication ou de transformation",
	en => "Manufacturing or processing places",
	es => "Lugares de fabricación o de transformación",
	pt_pt => "Locais de fabrico ou de transformação",
	ro => "Locurile de fabricare sau procesare",
	nl => "Locaties van productie of verwerking",
	de => "Herstellungs- oder Umwandlungsorte",
},


manufacturing_places_example => {
	fr => "Provence, France",
	en => "Montana, USA",
	es => "Andalucía, España",
	pt => "Lisboa, Portugal",
	nl => "Leuven, België",
	de => "Allgäu, Deutschland",
},

emb_codes => {
	fr => "Code emballeur (EMB) ou embouteilleur",
	en => "EMB code",
	es => "Código de envasador",
	pt => "Código do embalador",
	de => "Produzenten Code",
	nl => "Verpakkerscode",
},

emb_codes_example => {
	fr => "EMB 53062, FR 62.448.034 CE, 84 R 20, 33 RECOLTANT 522 ",
	en => "EMB code",
	es => "EMB 53062, FR 62.448.034 CE, 84 R 20, 33 RECOLTANT 522 ",
	pt => "PT ILT 40 CE",
	nl => "EMB 53062, FR 62.448.034 CE, 84 R 20, 33 RECOLTANT 522",
	de => "EMB 53062, FR 62.448.034 CE, 84 R 20, 33 RECOLTANT 522",
},

emb_codes_note => {
	fr => "En France, code commençant par EMB suivi de 5 chiffres (code INSEE de la commune) et éventuellement d'une lettre qui identifie l'entreprise qui a conditionné le produit.<br/>
Dans d'autres pays d'Europe, code précédé de \"e\". Ou dans un ovale, 2 initiales du pays suivi d'un nombre et de CE.<br/>
Pour le vin et l'alcool, code sur la capsule au dessus du bouchon.",
	en => "In Europe, code in an ellipse with the 2 country initials followed by a number and CE.",
	es => "En Francia, el código que empieza por EMB seguido de 5 cifras (código del INSEE de la comuna) y, en ocasiones, una letra que identifica la empresa envasadora del producto.<br/>
En otros países europeos, el código precedido por \"e\". O en una elipse, dos letras correspondientes al país seguidas de un número y de las letras CE.<br/>",
	pt => "Na Europa, o código vem normalmente numa oval, com 2 letras correspondentes ao país, seguido de um número e das letras CE.",
	nl => "In Europa, de code in een ovaal met de 2 letters van het land gevolgd door een cijfer en de letters CE.",
},

link => {
	fr => "Lien vers la page du produit sur le site officiel du fabricant",
	en => "Link to the product page on the official site of the producer",
	es => "Enlace a la página del producto en el sitio oficial del fabricante",
	pt => "Link da página oficial do produto do fabricante",
	ro => "Legătură către pagina produsului de pe site-ul oficial al producătorului",
	he => "קישור לעמוד המוצר באתר הרשמי של היצרן",
	nl => "Link naar de pagina van het product op de officiële site van de producent",
	de => "Link zur Produktseite auf der offiziellen Seite des Herstellers",
},

purchase_places => {
	fr => "Ville et pays d'achat",
	en => "City, state and country where purchased",
	es => "Sitios de compra",
	pt => "Cidade, estado e país onde foi comprado",
	ro => "Oraș, județ și țara de achiziție",
	he => "עיר/מושב/קיבוץ/כפר בהם נרכש המוצר",
	nl => "Stad en land van aankoop",
	de => "Stadt und Land des Ankaufs",
},

purchase_places_note => {
	fr => "Indiquez le lieu où vous avez acheté ou vu le produit (au moins le pays)",
	en => "Indicate where you bought or saw the product (at least the country)",
	es => "Indica donde compraste o viste el producto (al menos el país)",
	pt => "Indicar onde comprou ou viu o produto (pelo menos o país)",
	ro => "Indicați unde ați achiziționat sau ați văzut produsul (cel puțin țara)",
	he => "ציון היכן המוצר נרכש או נצפה (לפחות ברמת העיר)",
	nl => "Geef de plaats aan waar u het product gekocht of gezien heeft (ten minste het land)",
	de => "Bitte geben Sie den Ort ein, wobei Sie das Produkt gekauft oder gesehen haben (das Land zumindest)",
},

stores => {
	fr => "Magasins",
	en => "Stores",
	es => "Tiendas",
	pt => "Lojas",
	ro => "Magazine",
	he => "חנויות",
	nl => "Winkels",
	de => "Läden",
},

stores_note => {
	fr => "Enseigne du magasin où vous avez acheté ou vu le produit",
	en => "Name of the shop or supermarket chain",
	es => "Nombre de la tienda o cadena de supermercados",
	pt => "Nome da loja ou rede de supermercados",
	ro => "Numele magazinului sau al lanțului de magazine",
	he => "שם החנות או רשת חנויות המזון",
	nl => "Naam van de winkel of supermarktketen waar u het product gekocht of gezien heeft",
	de => "Name des Geschäfts, wo Sie das Produkt gekauft oder gesehen haben",
},

countries => {
	fr => "Pays de vente",
	en => "Countries where sold",
	es => "Países de venta",
	pt => "Países onde é vendido",
	ro => "Țările unde se vinde",
	he => "ארצות בהן נמכר",
	nl => "Landen van verkoop",
	de => "Verkaufsland",
},

countries_note => {
	fr => "Pays dans lesquels le produit est largement distribué (hors magasins spécialisés dans l'import)",
	en => "Countries where the product is widely available (non including stores specialising in foreign products)",
	es => "Países en los que el producto está ampliamente disponible (no se incluyen las tiendas especializadas en productos extranjeros)",
	pt => "Países onde o produto é amplamente distribuído (não incluir lojas especializadas em produtos estrangeiros)",
	ro => "Țările unde produsul este disponibil pe scară largă (ne-incluzând magazinele specializate în produse străine)",
	he => "מדינות בהן המוצר זמין לרווחה (לא כולל חנויות המתמחות במוצרים מיובאים)",
	nl => "Landen waar het product op grote schaal beschikbaar is (behalve winkels gespecialiseerd in import)",
},

remember_purchase_places_and_stores => {
	fr => 'Se souvenir du lieu d\'achat et du magasin pour les prochains ajouts de produits',
	en => 'Remember the place of purchase and store for the next product adds',
	es => 'Recordar el lugar de compra y la tienda para los nuevos productos que se van a añadir en el futuro',
	pt => 'Lembrar o lugar de compra e loja para os próximos produtos a serem adicionados',
	ro => "Ține minte locul de achiziție și magazinul pentru următoarele adăugări de produse",
	he => 'שמירת מקור הרכישה ואת החנות להוספות המוצרים הבאות',
	nl => "De locatie van aankoop en de winkel onthouden voor het toevoegen van nieuwe producten",
	de => "Laden und Einkaufsort für die nächsten Produkte speichern",
},

product_characteristics => {
	fr => "Caractéristiques du produit",
	en => "Product characteristics",
	es => "Características del producto",
	pt => "Características do produto",
	ro => "Caracteristicile produslui",
	he => "מאפייני המוצר",
	nl => "Eigenschappen van het product",
	de => "Produkteigenschaften",
},

product_image => {
	fr => "Photo du produit",
	en => "Product picture",
	es => "Imagen del producto",
	pt => "Imagem do produto",
	ro => "Imaginea produsului",
	he => "תמונת המוצר",
	nl => "Foto van het product",
	de => "Foto des Produkts",
},

image_front => {
	fr => "Photo du produit (recto)",
	en => "Front picture",
	es => "Imagen frontal del producto",
	pt => "Imagem frontal do produto",
	ro => "Imaginea din față",
	he => "תמונה קדמית",
	nl => "Foto van het product (voorzijde)",
	de => "Foto des Produkts (Vorderseite)",
},

image_ingredients => {
	fr => "Photo de la liste des ingrédients",
	en => "Ingredients picture",
	es => "Imagen con los ingredientes del producto",
	pt => "Imagem com os ingredientes do produto",
	ro => "Imaginea cu ingredientele",
	he => "תמונת הרכיבים",
	nl => "Foto van de ingrediëntenlijst",
	de => "Foto der Zutatensliste",
},

image_nutrition => {
	fr => "Photo des informations nutritionnelles",
	en => "Nutrition facts picture",
	es => "Imagen con la información nutricional del producto",
	pt => "Imagem com a informação nutricional do produto",
	ro => "Imaginea cu valori nutriționale",
	he => "תמונת הרכיבים",
	nl => "Foto van de nutritionële informatie",
	de => "Foto der Nährwertinformationen",
},

ingredients => {
	fr => "Ingrédients",
	en => "Ingredients",
	es => "Ingredientes",
	pt => "Ingredientes",
	ro => "Ingrediente",
	de => "Zutaten",
	he => "רכיבים",
	nl => "Ingrediënten",
},

image_ingredients_note => {
	fr => "Si elle est suffisamment nette et droite, les ingrédients peuvent être extraits automatiquement de la photo.",
	en => "If the picture is neat enough, the ingredients can be extracted automatically",
	es => "Si la imagen es buena y lo suficientemente nítida, los ingredientes se pueden extraer de forma automática.",
	pt => "Se as imagens forem boas e nítidas, os ingredientes podem ser extraídos automaticamente.",
	ro => "Dacă este suficient de clară și dreaptă, ingredientele ar putea fi extrase automat din fotografie.",
	he => "אם התמונה ברורה ובהירה מספיק, ניתן לחלץ את הרכיבים מהתמונה אוטומטית. (לא עובד בעברית)",
	nl => "Als de foto voldoende scherp en recht is, kunnen de ingrediënten automatisch uit de foto afgeleid worden.",
	de => "Ist das Foto klar und genau, dann können die Zutaten automatisch extrahiert werden.", 
},

ingredients_text => {
	fr => "Liste des ingrédients",
	en => "Ingredients list",
	es => "Lista de ingredientes",
	pt => "Lista de ingredientes",
	ro => "Lista de ingrediente",
	he => "רשימת רכיבים",
	nl => "Ingrediëntenlijst",
	de => "Zutatensliste",
},

ingredients_text_note => {
	fr => "Conserver l'ordre, indiquer le % lorsqu'il est précisé, séparer par une virgule ou - , Utiliser les ( ) pour  les ingrédients d'un ingrédient, indiquer les allergènes entre _ : farine de _blé_",
	en => "Keep the order, indicate the % when specified, separate with a comma or - , use ( ) for ingredients of an ingredient, surround allergens with _ e.g. _milk_",
	es => "Conservar el orden, indicar el % cuando se especifique, separar por una coma y poner entre paréntesis ( ) los ingredientes que componen otro ingrediente",
	pt => "Manter a ordem de listagem, indicar a % quando especificado, separar com uma vírgula (,) ou hífen (-) , usar parênteses ( ) para ingredientes compostos de outros ingredientes",
	ro => "Mențineți ordinea, indicați % unde este precizat, separați cu o virgulă sau - , folosiți () pentru ingredientele unui ingredient",
	he => "יש לשמור על הסדר, לציין את הסמין % כשזה צוין, להפריד עם פסיק או -, להשתמש ב־( ) לתת־רכיבים של רכיב",
	nl => "Behoudt de volgorde, geef het % indien vermeld, scheiden door middel van een komma of '-' , gebruik de ( ) voor de ingrediënten van een ingrediënt, vermeldt de allergenen tussen '_' zoals bijvoorbeeld _melk_",
	de => "Sortierung behalten, % anzeigen falls vorhanden, mit Komma oder - trennen, für die Zutaten eines Zutats () verwenden, Allergen zwischen _ anzeigen: zum Beispiel _Milch_",
},

ingredients_text_display_note => {
	fr => "Les ingrédients sont listés par ordre d'importance (quantité).",
	en => "Ingredients are listed in order of importance (quantity).",
	es => "Los ingredientes se enumeran por orden de importancia (cantidad).",
	pt => "Os ingredientes estão listados pela ordem de importância (quantidade).",
	ro => "Ingredientele sunt listate în ordinea importanței (cantitate).",
	he => "רכיבים רשומים לפי סדר חשיבותם (כמות).",
	nl => "De ingrediënten worden geordend volgens belangrijkheid (hoeveelheid).",
	de => "Die Zutaten sind nach Ausmaß/Menge sortiert",
},

ingredients_text_example => {
	fr => "Céréales 85,5% (farine de _blé_, farine de _blé_ complet 11%), extrait de malt (orge), cacao 4,8%, vitamine C",
	en => "Cereals 85.5% (_wheat_ flour, whole-_wheat_ flour 11%), malt extract, cocoa 4,8%, ascorbic acid",
	es => "Cereales 85.5% (harina de _trigo_, harina de _trigo_ integral 11%), extracto de malta (cebada), cacao 4,8%, ácido ascórbico",
	pt => "Cereais 85.5% (farinha de _trigo_, farinha integral 11%), extrato de malta (cevada), cacau 4,8%, vitamina C",
	pt_pt => "Cereais 85.5% (farinha de _trigo_, farinha integral 11%), extrato de malte (cevada), cacau 4,8%, vitamina C",
	he => "דגנים 85.5% (קמח חיטה, קמח מחיטה מלאה 11%), תמצית לתת, קקאו 4.8%, חומצה אסקורבית",
        nl => "Granen 85.5% (_tarwe_bloem, volkoren _tarwe_bloem 11%), moutextract (gerst), cacao 4,8%, vitamine C",
	de => "Getreide 85,5% (_Weizen_mehl, _Vollkorn_mehl 11%), Malzextrakt (Gerste), Kakao 4,8%, Vitamine C",
},

allergens => { 
	en => 'Substances or products causing allergies or intolerances',
	ga => 'Substaintí nó táirgí is cúis le hailléirgí nó le héadulaingtí',
	de => 'Stoffe oder Erzeugnisse, die Allergien oder Unverträglichkeiten auslösen',
	da => 'Stoffer eller produkter, der forårsager allergier eller intolerans',
	el => 'ουσιεσ ή προϊοντα που προκαλουν αλλεργιεσ ή δυσανεξιεσ',
	es => 'Sustancias o productos que causan alergias o intolerancias',
	fi => 'Allergioita tai intoleransseja aiheuttavat aineet ja tuotteet',
	fr => 'Substances ou produits provoquant des allergies ou intolérances',
	it => 'Sostanze o prodotti che provocano allergie o intolleranze',
	nl => 'Stoffen of producten die allergieën of intoleranties veroorzaken',
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
	es => "Trazas",
	pt => "Vestígios",
	ro => "Urme",
	he => "עקבות",
	nl => "Sporen",
	de => "Spuren",
},

traces_note => {
	fr => 'Indiquer les ingrédients des mentions "Peut contenir des traces de", "Fabriqué dans un atelier qui utilise aussi" etc.',
	en => 'Indicate ingredients from mentions like "May contain traces of", "Made in a factory that also uses" etc.',
	es => 'Son los ingredientes que aparecen mencionados como "Puede contener trazas de", "Elaborado en una factoría que también usa", etc.',
	pt => 'Indicar os ingredientes que sejam mencionados como "Pode conter traços de", "Fabricado em ambiente que também usa", etc', 
	pt_pt => 'Indicar os ingredientes que sejam mencionados como "Pode conter vestígios de", "Fabricado em ambiente que também usa", etc.',
	ro => 'Indicați ingredientele din mențiuni ca de exemplu "Ar putea conține urme de", "Produse într-o fabrică care produce și" etc.',
	he => 'ציון מרכיבים מאזכורים שונים כגון "עלול להכיל עקבות של", "נוצר במפעל המשתמש ב..." וכו׳',
	nl => 'Geef de ingrediënten met de vermelding "Kan sporen bevatten van", "Geproduceerd in een fabriek waar ook X verwerkt wordt',
	de => 'Die Zutaten von Erwähnungen wie "Kann Spuren enthalten", "Hergestellt in einer fabrik, die auch verwendet" vormerken',
},

traces_example => {
	fr => 'Lait, Gluten, Arachide, Fruits à coque',
	en => "Milk, Gluten, Nuts",
	es => "Leche, Gluten, Cacahuetes, Nueces",
	pt => "Leite, Glúten, Amendoim, Nozes",
	ro => "Lapte, Gluten, Alune, Nuci",
	he => "חלב, גלוטן, אגוזים", 
	nl => "Melk, Gluten, Noten",
	de => "Milch, Gluten, Erdnuss, Nussschalen",
},

serving_size => {
	fr => "Taille d'une portion",
	en => "Serving size",
	es => "Tamaño de la porción",
	pt => "Tamanho da porção",
	ro => "Cantitatea unei porții",
	he => "גודל ההגשה",
	nl => "Grootte van een portie",
	de => "Portiongröße",
},

serving_size_example => {
	fr => '30 g, 2 biscuits 60 g, 5 cl, un verre 20 cl',
	en => "60 g, 12 oz, 20cl, 2 fl oz",
	es => '30 g, 2 galletas 60 g, 5 cl, un vaso 20 cl',
	pt => "30 g, 2 bolachas 60 g, 5 cl, um copo 200 ml",
	ro => "30 g, 2 biscuiți 60 g, 5 cl, un pahar 200 ml",
	he => "30 ג, 2 אונקיות, 20 סנטיליטר, 2 אונקיות נוזל",
	nl => "30 g, 2 koekjes 60 g, 5 cl, een glas 20 cl",
	de => "30 g, 2 Keks 60g, 5 cl, ein Glas 20 cl",
},

nutrition_data => {
	fr => "Informations nutritionnelles",
	en => "Nutrition facts",
	es => "Información nutricional",
	pt => "Informação nutricional",
	ro => "Valori nutriționale",
	he => "מפרט תזונתי",
	nl => "Nutritionele informatie",
	de => "Nährwertinformationen",
},

nutrition_data_note => {
	fr => "Si elle est suffisamment nette et droite, les informations nutritionnelles peuvent être extraites automatiquement de la photo.",
	en => "If the picture is sufficiently sharp and level, nutrition facts can be automatically extracted from the picture.",
	es => "Si la imagen es lo suficientemente nítida, la información nutricional puede ser extraída automáticamente.",
	pt => "Se a imagem for suficientemente nítida, a informação nutricional pode ser extraída automaticamente.",
	ro => "Dacă fotografia este suficient de clară și dreaptă, informația nutrițională poate fi extrasă automat din imagine.",
	he => "אם התמונה חדה מספיק ובכיוון נכון, ניתן לחלץ את הפרטים התזונתיים מהתמונה עצמה (עדיין לא זמין בעברית).",
	nl => "Als de foto voldoende scherp en recht is, kan de nutritionele informatie automatisch uit de foto afgeleid worden",
	de => "Ist das Foto klar und genau, dann können die Nährwertinformationen automatisch extrahiert werden.",
},

no_nutrition_data => {
	fr => "Les informations nutritionnelles ne sont pas mentionnées sur le produit.",
	en => "Nutrition facts are not specified on the product.",
	es => "El producto no trae información nutricional.",
	pt => "Informação nutricional não especificada no produto.",
	ro => "Valorile nutriționale nu sunt specificate pe produs.",
	he => "המפרט התזונתי אינו מצוין על המוצר.",
	nl => "De nutritionele informatie wordt niet op het product vermeld",
	de => "Die Nährwertinformationen sind auf dem produkt nicht erwähnt",
},

nutrition_data_table_note => {
	fr => "Le tableau liste par défaut les nutriments les plus couramment indiqués. Laissez le champ vide s'il n'est pas présent sur l'emballage.<br />Vous pouvez ajouter d'autres nutriments
(vitamines, minéraux, cholestérol, oméga 3 et 6 etc.) en tapant les premières lettres de leur nom dans la dernière ligne du tableau.",
	en => "The table lists by default nutriments that are often specified. Leave the field blank if it's not on the label.<br/>You can add extra nutriments (vitamins, minerals, cholesterol etc.)
by typing the first letters of their name in the last row of the table.",   
	es => "La tabla muestra por defecto los nutrientes que aparecen con mayor frecuencia. Deja el campo en blanco si no está presente en el envase. <br />Se pueden agregar nutrientes adicionales (vitaminas, minerales, colesterol, ácidos grasos omega 3 y 6, etc.) al teclear las primeras letras del nombre en la última fila de la tabla.",   
	pt => "A tabela mostra por defeito os nutrientes que aparecem com maior frequência. Deixar o campo em branco se não estiver especificado na embalagem. <br />É possível adicionar outros nutrientes (vitaminas, minerais, colesterol, ácidos gordos ómega 3 e 6, etc.) ao digitar as primeiras letras do nome na última linha da tabela.",
	ro => "Tabelul listează implicit nutrienții care sunt specificați mai des. Lăsați câmpul liber dacă nu se regăsește pe etichetă.<br/>Puteți adăuga extra nutrienți (vitamine, minerale, colesterol etc.) tastând primele litere din numele lor în ultimul rând din tabel.",
	he => "הטבלה מציגה כבררת מחדל את המפרט התזונתי כפי שמופיע בדרך כלל. ניתן להשאיר את השדה ריק אם אינו מופיע על התווית.<br/>ניתן להוסיף פריטי תזונה נוספים (ויטמינים, מינרלים, כולסטרול וכו׳)
על־ידי הקלדת האותיות הראשונות של שמם בשורה האחרונה של הטבלה.",
	nl => "De tabel lijst automatisch de voedingsstoffen op die het vaakst vermeld worden. Laat het veld leeg indien het niet vermeld staat op de verpakking.>br />U kan andere voedingsstoffen (vitamines, mineralen, cholesterol, omega 3 en 6 etc.) toevoegen door de eerste letters van hun naam in de laatste rij van de tabel in te voeren.",
},

nutrition_data_average => {
	fr => "Composition nutritionnelle moyenne pour les %d produits de la catégorie %s dont les informations nutritionnelles sont connues (sur un total de  %d produits).",
	en => "Average nutrition facts for the %d products of the %s category for which nutrition facts are known (out of %d products).",
	es => "Valores nutricionales medios para los %d productos de la categoría %s para los que se especifican los valores nutricionales (de un total de %d productos).",
	pt => "Valores nutricionais médios...",
	ro => "Valorile nutriționale medii pentru %d produse din categoria %s pentru care valorile nutriționale sunt cunoscute (din %d produse).",
	he => "מפרט תזונתי ממוצע עבור %d מוצרים מהקטגוריה %s שעבורם המפרט התזונתי ידוע (מתוך %d מוצרים).",
	nl => "Gemiddelde nutritionele samenstelling voor de %d producten van de categorie %s waarvan de nutritionele informatie bekend is (op een totaal van %d producten).",
},

nutrition_data_table => {
	fr => "Composition nutritionnelle",
	en => "Nutrition facts",
	es => "Información nutricional",
	pt => "Informação nutricional",
	ro => "Valori nutriționale",
	he => "מפרט תזונתי",
	nl => "Nutritionele samenstelling",
	de => "Nährwertzusammensetzung",
},

#	(non breaking-spaces are needed below)
nutrition_data_per_100g => {
	fr => "pour 100 g / 100 ml",
	en => "for 100 g / 100 ml",
	es => "por 100 g / 100 ml",
	pt => "por 100 g / 100 ml",
	ro => "pentru 100 g / 100 ml",
	he => "ל־100 גרם / 100 מ״ל",
	nl => "voor 100 g / 100 ml",
	de => "für 100 g / 100 ml",
},

nutrition_data_per_serving => {
	fr => "par portion",
	en => "per serving",
	es => "por porción",
	pt => "por porção",
	ro => "per porție",
	he => "לכל הגשה",
	nl => "per portie",
	de => "pro Schnitte",
},

nutrition_data_compare_percent => {
	fr => "Différence en %",
	en => "% of difference",
	es => "Diferencia en %",
	pt => "% em comparação",
	ro => "Diferența în %",
	cs => "% se liší",
	he => "% שינוי",
	nl => "Verschil in %",
	de => "Unterschied in %",
},

nutrition_data_comparison_with_categories => {
	fr => "Comparaison avec les valeurs moyennes des produits de même catégorie :",
	en => "Comparison to average values of products in the same category:",
	es => "Comparación con los valores medios de los productos pertenecientes a la misma categoría:",
	pt => "Comparação com os valores médios dos produtos pertencentes à mesma categoria:",
	ro => "Comparație cu valorile medii ale produselor din aceeași categorie:",
	he => "השוואה לערכים הממוצעים של מוצרים באותה הקטגוריה:",
	nl => "Vergelijking met de gemiddelde waarden van producten uit dezelfde categorie:",
},

nutrition_data_comparison_with_categories_note => {
	fr => "A noter : pour chaque nutriment, la moyenne n'est pas celle de tous les produits de la catégorie, mais des produits pour lesquels la quantité du nutriment est connue.",
	en => "Please note: for each nutriment, the average is computed for products for which the nutriment quantity is known, not on all products of the category.",
	es => "Nota: para cada nutriente, el promedio no es el de todos los productos de la categoría, sino el de todos los productos para los cuales se especifica la cantidad de nutrientes.",
	pt => "Nota: para cada nutriente, a média tem em conta somente os produtos cuja quantidade dos nutrientes é conhecida, e não para todos os produtos da categoria.",
	ro => "De notat: pentru fiecare nutrient, media este calculată pentru produsele pentru care cantitatea nutrientului este cunoscută, nu pentru toate produsele din categorie.",
	he => "לתשומת לבך: עבור כל מרכיב תזונתי, הממוצע מחושב לפי מוצרים שההרכב התזונתי שלהם ידוע, לא לפי כלל המוצרים בקטגוריה.",
	nl => "Noteer: voor elke voedingsstof is het gemiddelde niet dat van alle producten uit de categorie, maar dat van de producten waarvoor de hoeveelheid van de voedingsstof bekend is.",
},

nutrition_data_compare_value => {
	fr => "valeur pour 100 g/ 100 ml",
	en => "value for 100 g / 100 ml",
	es => "valor para 100 g/ 100 ml",
	pt => "valor para 100 g / 100 ml",
	ro => "valoare pentru 100 g / 100 ml",
	he => "ערך ל־100 גרם / 100 מ״ל",
	nl => "waarde voor 100 g / 100 ml",
},

nutrition_data_per_std => {
	fr => "Ecart type",
	en => "Standard deviation",
	es => "Desviación estándar",
	pt => "Desvio padrão",
	ro => "Deviația standard",
	he => "סטיית תקן",
	nl => "Standaardafwijking",
},

nutrition_data_per_min => {
	fr => "Minimum",
	en => "Minimum",
	es => "Mínimo",
	pt => "Mínimo",
	ro => "Minimum",
	he => "לכל הפחות",
	nl => "Minimum",
},

nutrition_data_per_5 => {
	fr => "5<sup>e</sup> centile",
	en => "5<sup>th</supe> centile",
	es => "Percentil 5",
	pt => "5<sup>o</sup> percentil",
	ro => "Al 5-lea procent",
	he => "עד 5 אחוז",
	nl => "5<sup>e</sup> percentiel",
},

nutrition_data_per_10 => {
	fr => "10ème centile",
	en => "10th centile",
	es => "Percentil 10",
	pt => "10<sup>o</sup> percentil",
	ro => "Al 10-lea procent",
	he => "עד 10 אחוז",
	nl => "10<sup>e</sup> percentiel",
},
nutrition_data_per_50 => {
	fr => "Médiane",
	en => "Median",
	es => "Mediana",
	pt => "Mediana",
	ro => "Median",
	he => "חצי",
	nl => "Mediaan",
},

nutrition_data_per_90 => {
	fr => "90ème centile",
	en => "90th centile",
	es => "Percentil 90",
	pt => "90<sup>o</sup> percentil",
	ro => "Al 90-lea procent",
	he => "עד 90 אחוז",
	nl => "90<sup>e</e> percentiel",
},

nutrition_data_per_95 => {
	fr => "95<sup>e</sup> centile",
	en => "95<sup>th</supe> centile",
	es => "Percentil 95",
	pt => "95<sup>o</sup> percentil",
	ro => "Al 95-lea procent",
	he => "עד 95 אחוז",
	nl => "95<sup>e</sup>e percentiel",
},

nutrition_data_per_max => {
	fr => "Maximum",
	en => "Maximum",
	es => "Máximo",
	pt => "Máximo",
	ro => "Maximum",
	he => "לכל היותר",
	nl => "Maximum",
},

nutrition_data_table_sub => {
	fr => "dont",
	en => "-",
	es => "-",
},

ecological_data_table => {
	fr => 'Impact écologique',
	en => 'Ecological footprint',
	es => 'Huella ecológica',
	pt => 'Pegada ecológica',
	ro => "Impact ecologic",
	he => 'טביעת רגל אקולוגית',
	it => 'Impronta ecologica',
	nl => "Ecologische impact",
},

ecological_data_table_note => {
	fr => "Si l'empreinte carbone est présente sur l'emballage (rarement actuellement), elle est à indiquer pour la même quantité que pour la composition nutritionnelle.",
	en => "If the carbon footprint is specified on the label (rarely at this time), indicate it for the same quantity than the nutritional composition.",
	es => "Si aparece en el envase la huella de carbono (muy raro en la actualidad), indicarla por la misma cantidad que la información nutricional.",
	pt => "Se a pegada de carbono é especificada na embalagem (muito raro hoje em dia), indique-a para a mesma quantidade que para a composição nutricional.",
	ro => "Dacă amprenta de carbon este specificată pe etichetă (rar acum), indicați-o pentru aceeași cantitate ca și compoziția nutrițională.",
	he => "אם טביעת הרגל של הפחמן מצוינת על התווית (נדיר בימינו אנו), כדאי לציין אותה עבור כמות מסוימת מאשר את התרכובת התזונתית.",
	nl => "Als de ecologische voetafdruk op het eticket vermeld wordt (momenteel is dat zelden), geef ze dan voor dezelfde hoeveelheid als voor de nutritionele samenstelling",
},

example => {
	fr => "Exemple :",
	en => "Example:",
	es => "Ejemplo:",
	pt => "Exemplo:",
	ro => "Exemplu:",
	he => "דוגמה:",
	it => "Esempio:",
	nl => "Voorbeeld:",
	de => "Beispiel:",
},

examples => {
	fr => "Exemples :",
	en => "Examples:",
	es => "Ejemplos:",
	pt => "Exemplos:",
	he => "דוגמאות:",
	ro => "Exemple:",
	it => "Esempi:",
	nl => "Voorbeelden:",
	de => "Beispiele:",
},

brands_tagsinput => {
	fr => "ajouter une marque",
	en => "add a brand",
	es => "añadir una marca",
	pt => "adicionar uma marca",
	ro => "adăugați o marcă",
	he => "הוספת מותג",
	nl => "een merk toevoegen",
	de => "Marke hinzufügen",
},


packaging_tagsinput => {
	fr => "ajouter",
	en => "add a type, shape or material",
	es => "añadir un tipo, forma o material",
	pt => "adicionar um tipo, forma ou material",
	ro => "adăugați un tip, formă sau material",
	he => "הוספת סוג, צורה או חומר",
	nl => "een soort, vorm of materiaal toevoegen",
},

categories_tagsinput => {
	fr => "ajouter une catégorie",
	en => "add a category",
	es => "añadir una categoría",
	pt => "adicionar uma categoria",
	ro => "adugați o categorie",
	he => "הוספת קטגוריה",
	nl => "een categorie toevoegen",
	de => "Kategorie hinzufügen",
},

labels_tagsinput => {
	fr => "ajouter un label",
	en => "add a label",
	es => "añadir una etiqueta",
	pt => "adicionar uma etiqueta",
	ro => "adăugați o etichetă",
	he => "הוספת תווית",
	nl => "een label toevoegen",
	de => "Label hinzufügen",
},

origins_tagsinput => {
	fr => "ajouter une origine",
	en => "add an origin",
	es => "añadir un origen",
	pt => "adicionar uma origem",
	ro => "adăugați o origine",
	he => "הוספת מקור",
	nl => "herkomst toevoegen",
	de => "Herkunft hinzufügen",
},

manufacturing_places_tagsinput => {
	fr => "ajouter un lieu",
	en => "add a place",
	es => "añadir un lugar",
	pt => "adicionar um local",
	ro => "adăugați un loc",
	he => "הוספת מיקום",
	nl => "een locatie toevoegen",
	de => "Ort hinzufügen",
},

purchase_places_tagsinput => {
	fr => "ajouter un lieu",
	en => "add a place",
	es => "añadir un lugar",
	pt => "adicionar um local",
	ro => "adăugați un loc",
	he => "הוספת מיקום",
	nl => "een locatie toevoegen",
	de => "Ort hinzufügen",
},

stores_tagsinput => {
	fr => "ajouter un magasin",
	en => "add a store",
	es => "añadir una tienda",
	pt => "adicionar uma loja",
	ro => "adăugați un magazin",
	he => "הוספת חנות",
	nl => "een winkel toevoegen",
	de => "Laden hinzufügen",
},
	
fixme_product => {
	fr => "Si les informations sont incomplètes ou incorrectes, vous pouvez les complèter ou les corriger en modifiant cette fiche.",
	en => "If the data is incomplete or incorrect, you can complete or correct it by editing this page.",
	es => "Si la información está incompleta o es incorrecta, puedes completarla o corregirla editando esta página.",
	pt => "Se a informação está incompleta ou incorrecta, podes completá-la ou corrigí-la editando esta página.",
	ro => "Dacă datele sunt incomplete sau incorecte, le puteți completa sau corecta modificând această pagină.",
	he => "אם המידע חלקי או שגוי, ניתן להשלים או לתקן אותו על־ידי עריכת עמוד זה.",
	nl => "Indien de informatie onvolledig of foutief is, kan u ze op deze pagina aanvullen of corrigeren.",
},

alcohol_warning => {
	fr => "L'abus d'alcool est dangereux pour la santé. A consommer avec modération.",
	en => "Excess drinking is harmful for health.",
	es => "El exceso de alcohol es perjudicial para la salud. Consúmelo con moderación.",
	pt => "Excesso de álcool é pregudicial para a saúde. Seja responsável. Beba com moderação.",
	ro => "Consumul excesiv de alcool este dăunător sănătății",
	he => "שתייה מוגזמת של אלכוהול עשויה לפגוע בבריאות.",
	nl => "Overmatig alcoholgebruik schaadt de gezondheid. Drink met mate.",
},

warning_3rd_party_content => {
	fr => "Les informations doivent provenir de l'emballage du produit (et non d'autres sites ou du site du fabricant), et vous devez avoir pris vous-même les photos.<br/>
→ <a href=\"https://openfoodfactsfr.uservoice.com/knowledgebase/articles/59183\" target=\"_blank\">Pourquoi est-ce important ?</a>",    
	en => "Information and data must come from the product package and label (and not from other sites or the manufacturer's site), and you must have taken the pictures yourself.<br/>
→ <a href=\"\">Why it matters</a>",
	es => "La información debe provenir del propio envase del producto (y no de otros sitios o del sitio web del fabricante), y las fotografías deben haber sido tomadas por usted mismo/a.<br/>
→ <a href=\"\">¿Por qué es importante?</a>",
	pt_pt => "A informação deve ser proveniente da embalabem e do rótulo do produto (e não de outros locais ou da página web do fabricante), e as fotografias devem ser tiradas por si mesmo.<br/>
→ <a href=\"\">Porque é que é importante?</a>",
	ro => "Informația și datele trebuie să provină de pe pachetul și eticheta produsului (nu de pe alte site-uri sau de pe site-ul producătorului), iar fotografia trebuie să fie făcută de voi înșivă.<br/>
→ <a href=\"\">De ce contează?</a>",
	he => "יש להשתמש במידע ובנתונים המופיעים על אריזת המוצר לרבות התווית (ולא מאתרים אחרים או מאתר היצרן), נוסף על כך יש להשתמש בתמונות שצולמו על ידיך בלבד.<br/>",
	nl => "De informatie moet afkomstig zijn van de verpakking van het product (en niet van een andere site of de site van de producent), en u moet de foto's zelf getrokken hebben.",
},

front_alt => {
	fr => "Produit",
	en => "Product",
	es => "Producto",
	pt => "Produto",
	ro => "Produs",
	he => "מוצר",
	de => "Produkt",
},

ingredients_alt => {
	fr => "Ingrédients",
	en => "Ingredients",
	es => "Ingredientes",
	pt => "Ingredientes",
	ro => "Ingrediente",
	he => "רכיבים",
	nl => "Ingrediënten",
	de => "Zutaten",
},

nutrition_alt => {
	fr => "Informations nutritionnelles",
	en => "Nutrition facts",
	es => "Información nutricional",
	pt => "Informação nutricional",
	ro => "Valori nutriționale",
	he => "מפרט תזונתי",
	nl => "Nutritionele informatie",
	de => "Nährwertinformationen",
},

# will be used in sentences like "for products from the yogurts category"
for => {
	fr => 'pour',
	en => 'for',
	es => 'para',
	pt => 'para',
	ro => "pentru",
	he => 'עבור',
	nl => "voor",
	de => "für",
},
	
brands_products => {
	fr => "Les produits de la marque %s",
	en => "Products from the %s brand",
	es => "Productos de la marca %s",
	pt => "Produtos da marca %s",
	ro => "Produse de la marca %s",
	he => "מוצרים מבית המותג %s",
	nl => "Producten van het merk %s",
	de => "Die Produkte von der Marke %s",
},

categories_products => {
	fr => "Les produits de la catégorie %s",
	en => "Products from the %s category",
	es => "Productos de la categoría %s",
	pt => "Produtos da categoria %s",
	ro => "Produse din categoria %s",
	he => "מוצרים מהקטגוריה %s",
	nl => "Producten van de categorie %s",
	de => "Die Produkte von der Kategorie %s",
},

emb_codes_products => {
	fr => "Les produits dont le code emballeur est %s",
	en => "Products with the emb code %s",
	es => "Productos con código de envasador %s",
	pt => "Produtos com o código de embalador %s",
	nl => "Producten met verpakkerscode %s",
	de => "Die Produkte mit Verpackungscode %s",
},

cities_products => {
	fr => "Les produits dont la commune d'emballage est %s",
	en => "Products packaged in the city of %s",
	es => "Productos envasados en el municipio de %s",
	pt => "Produtos embalados na cidade de %s",
	ro => "Produse împachetate în orașul %s",
	he => "מוצרים שנארזו בעיר %s",
	nl => "Producten verpakt in de stad %s",
	de => "Produkte verpackt in der Stadt %s",
},

packaging_products => {
	fr => "Les produits avec le conditionnement %s",
	en => "Products with a %s packaging",
	es => "Productos con envase %s",
	pt => "Produtos com embalagem em %s",
	ro => "Produse cu ambalaj de %s",
	he => "מוצרים באריזה מסוג %s",
	nl => "Producten met een verpakking van %s",
	de => "Produkte mit der Verpackung %s",
},

origins_products => {
	fr => "Les produits dont l'origine des ingrédients est %s",
	en => "Products with ingredients originating from %s",
	es => "Productos originarios de %s",
	pt => "Produtos originários de %s",
	ro => "Produse cu ingrediente originare din %s",
	he => "מוצרים שמקורם %s",
	nl => "Producten waarvan de ingrediënten afkomstig zijn uit %s",
	de => "Produkte, deren Herkunft der Zutaten %s ist, ",
},

emb_code_products => {
	fr => "Les produits emballés par l'entreprise dont le code emballeur est %s",
	en => "Products packaged by the company with emb code %s",
	es => "Productos envasados por la empresa con código de envasado %s",
	pt => "Produtos embalados pela empresa com o código de embalador %s",
	nl => "Producten verpakt door het bedrijf met de verpakkerscode %s",
},

manufacturing_places_products => {
	fr => "Les produits par lieu de fabrication ou transformation :  %s",
	en => "Products manufactured or processed in %s",
	es => "Productos fabricados o transformados en  %s",
	ro => "Produse fabricate sau procesate în %s",
	pt => "Produtos fabricados ou transformados em %s",
	nl => "Producten geproduceerd of verwerkt in %s",
},

purchase_places_products => {
	fr => "Les produits par lieu de vente :  %s",
	en => "Products sold in %s",
	es => "Productos vendidos en %s",
	pt => "Produtos vendidos em %s",
	ro => "Produse vândute în %s",
	he => "מוצרים שנמכרים ב%s",
	nl => "Producten verkocht in %s",
},

stores_products => {
	fr => "Les produits par magasin : %s",
	en => "Products sold at %s",
	es => "Productos vendidos en el comercio %s",
	pt => "Produtos vendidos na loja:  %s",
	ro => "Produse vândute la %s",
	he => "מוצרים שנמכרים אצל",
	nl => "Producten verkocht in %s",
},

countries_products => {
	fr => "Les produits vendus dans le pays : %s",
	en => "Products sold in %s",
	es => "Productos vendidos en %s",
	pt => "Produtos vendidos no país : %s", # we have 3 prepositions (em, na, no) depending on the country; opting for the same logic as the French translation
	ro => "Produse vândute în %s",
	he => "מוצרים שנמכרים ב%s",
	nl => "Producten verkocht in %s",
},

ingredients_products => {
	fr => "Les produits qui contiennent l'ingrédient %s",
	en => "Products that contain the ingredient %s",
	es => "Productos que contienen el ingrediente %s",
	pt => "Produtos que contêm o ingrediente %s",
	ro => "Produse care conțin ingredientul %s",
	he => "מוצרים המכילים את הרכיב %s",
	nl => "Producten met het ingrediënt %s",
},

labels_products => {
	fr => "Les produits qui possèdent le label %s",
	en => "Products that have the label %s",
	es => "Productos con la etiqueta %s",
	pt => "Produtos com a etiqueta %s",
	ro => "Produse care au eticheta %s",
	he => "מוצרים הנושאים את התווית %s",
	nl => "Producten met het label %s",
},

nutriments_products => {
	fr => "Les produits qui contiennent le nutriment %s",
	en => "Products that contain the nutriment %s",
	es => "Productos que contienen el nutriente %s",
	pt => "Produtos que contêm o nutriente %s",
	ro => "Produse care conțin nutrientul %s",
	he => "מוצרים המכילים את הרכיב התזונתי %s",
	nl => "Producten met de voedingsstof %s",
},

users_products => {
	fr => "Les produits ajoutés par %s",
	en => "Products added by %s",
	es => "Productos añadidos por %s",
	pt => "Produtos adicionados por %s",
	ro => "Produse adăugate de %s",
	he => "מוצרים שנוספו על־ידי %s",
	nl => "Producten toegevoegd door %s",
},

users_add_products => {
	fr => "Les produits qui ont été ajoutés par le contributeur %s",
	en => "Products that were added by the user %s",
	es => "Productos que fueron añadidos por el usuario %s",
	pt_pt => "Produtos que foram adicionados pelo utilizador %s",
	ro => "Produse care au fost adăugate de către utilizatorul %s",
	he => "מוצרים שנוספו על־ידי המשתמש %s",
	nl => "Producten die toegevoegd werden door gebruiker %s",
},

users_edit_products => {
	fr => "Les produits qui ont été modifiés par le contributeur %s",
	en => "Products that were edited by the user %s",
	es => "Productos que fueron editados por el usuario %s",
	pt_pt => "Produtos que foram editados pelo utilizador %s",
	ro => "Produse care au fost modificate de către utilizatorul %s",
	he => "מוצרים שנערכו על־ידי המשתמש %s",
	nl => "Producten die aangepast werden door gebruiker %s",
},

brands_s => {
	fr => "marque",
	en => "brand",
	es => "marca",
	pt => "marca",
	ro => "marcă",
	he => "מותג",
	nl => "merk",
},

brands_p => {
	fr => "marques",
	de => "Marken",
	en => "brands",
	es => "marcas",
	ro => "mărci",
	he => "מותגים",
	nl => "merken",
},

categories_s => {
	fr => "catégorie",
	en => "category",
	es => "categoría",
	pt => "categoria",
	ro => "categorie",
	he => "קטגוריה",
	nl => "categorie",
},

categories_p => {
	fr => "catégories",
	de => "Kategorien",
	en => "categories",
	es => "categorías",
	pt => "categorias",
	ro => "categorii",
	he => "קטגוריות",
	nl => "categorieën",
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
	es => "código de envasador",
	pt => "código de embalador",
	ro => "codul ambalatorului",
	nl => "verpakkerscode",
},

emb_codes_p => {
	fr => "codes emballeurs",
	en => "packager codes",
	es => "códigos de envasadores",
	pt => "códigos de embalador",
	ro => "codurile ambalatorului",
	nl => "verpakkerscodes",
},

cities_s => {
	fr => "commune d'emballage",
	en => "packaging city",
	es => "Municipio de envasado",
	pt => "cidade de embalamento",
	ro => "orașul de împachetare",
	he => "עיר האריזה",
	nl => "stad van verpakking",
},

cities_p => {
	fr => "communes d'emballage",
	en => "packaging cities",
	es => "Municipios de envasado",
	pt => "cidades de embalamento",
	ro => "orașele de împachetare",
	he => "ערי האריזה",
	nl => "steden van verpakking",
},

purchase_places_s => {
	fr => "lieu de vente",
	en => "purchase place",
	es => "lugar de compra",
	pt => "local de compra",
	ro => "locația de cumpărare",
	he => "מקום הרכישה",
	nl => "verkoopslocatie",
},

purchase_places_p => {
	fr => "lieux de vente",
	en => "purchase places",
	es => "lugares de compra",
	pt => "locais de compra",
	ro => "locațiile de cumpărare",
	he => "מקומות הרכישה",
	nl => "verkoopslocaties",
},

manufacturing_places_s => {
	fr => "lieu de fabrication ou de transformation",
	en => "manufacturing or processing place",
	es => "lugar de fabricación o de transformación",
	ro => "locul de fabricație sau de procesare",
	pt => "local de fabrico",
	nl => "productie- of verwerkingslocatie",
},

manufacturing_places_p => {
	fr => "lieux de fabrication ou de transformation",
	en => "manufacturing or processing places",
	es => "lugares de fabricación o de transformación",
	ro => "locul de fabricație sau de procesare",
	pt => "locais de fabrico",
	nl => "productie- of verwerkingslocaties",
},

stores_s => {
	fr => "magasin",
	en => "store",
	es => "tienda",
	pt => "loja",
	ro => "magazin",
	he => "חנות",
	nl => "winkel",
},

stores_p => {
	fr => "magasins",
	en => "stores",
	es => "tiendas",
	pt => "lojas",
	ro => "magazine",
	he => "חנויות",
	nl => "winkels",
},

countries_s => {
	fr => "pays",
	en => "country",
	es => "país",
	pt => "país",
	ro => "țară",
	he => "מדינה",
	nl => "land",
},

countries_p => {
	fr => "pays",
	en => "countries",
	es => "países",
	pt => "países",
	ro => "țări",
	he => "מדינות",
	nl => "landen",
},

packaging_s => {
	fr => "conditionnement",
	en => "packaging",
	es => "envase",
	pt => "embalagem",
	ro => "ambalare",
	he => "אריזה",
	nl => "verpakking",
},

packaging_p => {
	fr => "conditionnements",
	en => "packaging",
	es => "envases",
	pt => "embalagens",
	ro => "ambalaje",
	he => "אריזה",
	nl => "verpakking",
},

origins_s => {
	fr => "origine des ingrédients",
	en => "origin of ingredients",
	es => "origen",
	pt => "origem",
	ro => "originea ingredientelor",
	he => "מקור",
	nl => "herkomst van de ingrediënten",
},

origins_p => {
	fr => "origines des ingrédients",
	en => "origins of ingredients",
	es => "orígenes",
	pt => "origens",
	ro => "originile ingredientelor",
	he => "מקורות",
	nl => "herkomst",
},

emb_code_s => {
	fr => "code emballeur (EMB)",
	en => "EMB code",
	es => "código de envasador (EMB)",
	pt => "código de embalador",
	nl => "verpakkerscode",
},

emb_code_p => {
	fr => "codes emballeurs (EMB)",
	en => "EMB codes",
	es => "códigos de envasador (EMB)",
	pt => "códigos de embalador",
	nl => "verpakkerscodes",
},

ingredients_s => {
	fr => "ingrédient",
	en => "ingredient",
	es => "ingrediente",
	pt => "ingrediente",
	ro => "ingredient",
	he => "רכיב",
	nl => "ingrediënt",
},

ingredients_p => {
	fr => "ingrédients",
	en => "ingredients",
	es => "ingredientes",
	pt => "ingredientes",
	ro => "ingrediente",
	he => "רכיבים",
	nl => "ingrediënten",
},

traces_s => {
	fr => "trace",
	en => "trace",
	es => "traza",
	pt => "traço",
	pt_pt => "vestígio",
	ro => "urmă",
	he => "עקבה",
	nl => "spoor",
},

traces_p => {
	fr => "traces",
	en => "traces",
	es => "trazas",
	pt => "traços",
	pt_pt => "vestígios",
	ro => "urme",
	he => "עקבות",
	nl => "sporen",
},

labels_s => {
	fr => "label",
	en => "label",
	es => "etiqueta",
	pt => "etiqueta",
	ro => "etichetă",
	he => "תווית",
	nl => "label",
},

labels_p => {
	fr => "labels",
	en => "labels",
	es => "etiquetas",
	pt => "etiquetas",
	ro => "etichete",
	he => "תוויות",
	nl => "labels",
},

nutriments_s => {
	fr => "nutriment",
	en => "nutriment",
	es => "nutriente",
	pt => "nutriente",
	ro => "nutrient",
	he => "רכיב תזונתי",
	nl => "voedingsstof",
},

nutriments_p => {
	fr => "nutriments",
	en => "nutriments",
	es => "nutrientes",
	pt => "nutrientes",
	ro => "nutriente",
	he => "רכיבים תזונתיים",
	nl => "voedingsstoffen",
},

known_nutrients_s => {
	fr => "nutriment connu",
	en => "known nutrient",
	es => "nutriente conocido",
	pt => "nutriente conhecido",
	ro => "nutrient cunoscut",
	he => "מרכיב תזונתי ידוע",
	nl => "gekende voedingsstof",
},

known_nutrients_p => {
	fr => "nutriments connus",
	en => "known nutrients",
	es => "nutrientes conocidos",
	pt => "nutrientes conhecidos",
	ro => "nutriente cunoscute",
	he => "מרכיבים תזונתיים ידועים",
	nl => "gekende voedingsstoffen",
},

unknown_nutrients_s => {
	fr => "nutriment inconnu",
	en => "unknown nutrient",
	es => "nutriente desconocido",
	pt => "nutriente desconhecido",
	ro => "nutrint necunoscut",
	he => "מרכיב תזונתי בלתי ידוע",
	nl => "onbekende voedingsstof",
},

unknown_nutrients_p => {
	fr => "nutriments inconnus",
	en => "unknown nutrients",
	es => "nutrientes desconocidos",
	pt => "nutrientes desconhecidos",
	ro => "nutriente necunoscute",
	he => "מרכיבים תזונתיים בלתי ידועים",
	nl => "onbekende voedingsstoffen",
},

entry_dates_s => {
	fr => "Date d'ajout",
	en => "Entry date",
},

entry_dates_p => {
	fr => "Dates d'ajout",
	en => "Entry dates",
},

last_edit_dates_s => {
	en => "Last edit date",
	fr => "Date de dernière modification",
},

last_edit_dates_p => {
	en => "Last edit dates",
	fr => "Dates de dernière modification",
},

nutrition_grades_s => {
	en => "Nutrition grade",
	fr => "Note nutritionnelle",
},

nutrition_grades_p => {
	en => "Nutrition grades",
	fr => "Notes nutritionnelles",
},

nutrient_levels_s => {
	fr => "repère nutritionnel",
	en => "nutrient level",
	es => "valor nutricional",
	pt => "valor nutricional",
	ro => "valoare nutrițională",
	he => "רמת המרכיב התזונתי",
	nl => "voedingswaarde",
},

nutrient_levels_p => {
	fr => "repères nutritionnels",
	en => "nutrient levels",
	es => "valores nutricionales",
	pt => "valores nutricionais",
	ro => "valori nutriționale",
	he => "רמות המרכיבים התזונתיים",
	nl => "voedingswaarden",
},

nutrient_levels_info => {
	fr => "<a href=\"/reperes-nutritionnels\">Repères nutritionnels</a> pour 100 g :",
	en => "Nutrient levels for 100 g:",
	es => "<a href=\"/valores-nutricionales\">Valores nutricionales</a> por 100 g :",
	pt => "<a href=\"/valores-nutricionais\">Valores nutricionais</a> por 100 g:",
	ro => "Valori nutriționale pentru 100g:",
	he => "רמות המרכיבים התזונתיים ל־100 גרם:",
	nl => "<a href=\"/voedingswaarden\">Voedingswaarden</a> per 100 g :",
},

users_s => {
	fr => "contributeur",
	de => 'Mitwirkende',
	en => 'contributor',
	es => 'contribuyente',
	pt => 'colaborador',
	it => 'contributore',
	ro => "contributor",
	he => 'תורם',   
	nl => "gebruiker",
},

users_p => {
	fr => "contributeurs",
	de => 'Mitwirkende',
	en => 'contributors',
	es => 'contribuyentes',
	pt => 'colaboradores',
	it => 'contributori',
	ro => "contributori",
	he => 'תורמים', 
	nl => "gebruikers",
},
photographers_s => {
	fr => 'photographe',
	en => 'photographer',
	es => 'fotógrafo',
	pt => 'fotógrafo',
	ro => "fotograf",
	he => 'צלם',
	nl => "fotograaf",
},
photographers_p => {
	fr => 'photographes',
	en => 'photographers',
	es => 'fotógrafos',
	pt => 'fotógrafos',
	ro => "fotografi",
	he => 'צלמים',
	nl => "fotografen",
},
informers_s => {
	fr => 'informateurs',
	en => 'informers',
	es => 'informante',
	pt => 'informante',
	pt_pt => 'informador',
	ro => "informator",
	he => 'מודיע',
	nl => "informant",
},
informers_p => {
	fr => 'informateurs',
	en => 'informers',
	es => 'informantes',
	pt => 'informantes',
	pt_pt => 'informadores',
	ro => "informatori",
	he => 'מודיעים',
	nl => "informanten",
},
correctors_s => {
	fr => 'correcteur',
	en => 'corrector',
	es => 'corrector',
	pt => 'corretor',
	pt_pt => 'revisor',
	ro => "corector",
	he => 'מתקן',
	nl => "corrector",
},
correctors_p => {
	fr => 'correcteurs',
	en => 'correctors',
	es => 'correctores',
	pt => 'corretores',
	pt_pt => 'revisores',
	ro => "corectori",
	he => 'מתקנים',
	nl => "correctoren",
},
checkers_s => {
	fr => 'vérificateur',
	en => 'checker',
	es => 'verificador',
	pt => 'verificador',
	ro => "verificator",
	he => 'בודק',
	nl => "verificateur",
},
checkers_p => {
	fr => 'vérificateurs',
	en => 'checkers',
	es => 'verificadores',
	pt => 'verificadores',
	ro => "verificatori",
	he => 'בודקים',
	nl => "verificateurs",
},
states_s => {
	fr => 'état',
	en => 'state',
	es => 'estado',
	pt => 'estado',
	ro => "status",
	he => 'מצב',
	nl => "staat",
},
states_p => {
	fr => 'états',
	en => 'states',
	es => 'estados',
	pt => 'estados',
	ro => "statusuri",
	he => 'מצבים',
	nl => "statussen",
},
ingredients_p => { 
	fr => 'ingrédient',
	de => 'Zutat',
	en => 'ingredient',
	es => 'ingrediente',
	pt => 'ingrediente',
	ro => "ingredient",
	it => 'ingredient',
	he => 'רכיב',
	nl => "ingrediënt",
},
ingredients_p => { 
	fr => 'ingrédients',
	de => 'Zutaten',
	en => 'ingredients',
	es => 'ingredientes',
	pt => 'ingredientes',
	ro => "ingrediente",
	it => 'ingredientes',
	he => 'רכיבים',
	nl => "ingrediënten",
},

allergens_s => { 
	fr => 'allergène',
	de => 'allergen',
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
},

allergens_p => { 
	fr => 'allergènes',
	de => 'allergene',
	en => 'allergens',
	es => 'alergenos',
#	it => 'allergene',
#	ru => 'аллергены',
#	ar => 'moussabib-hassassiya',
	pt => 'alergenicos',
	pt_pt => 'alergéneos',
	ro => 'alergeni',
#	he => 'khomer-alergeni', 
	nl => "allergenen",
},

additives_s => {
	fr => "additif",
	en => "additive",
	es => "aditivo",
	pt => "aditivo",
	ro => "aditiv",
	he => "תוסף",
	nl => "additief",
},

additives_p => {
	fr => "additifs",
	en => "additives",
	es => "aditivos",
	pt => "aditivos",
	ro => "aditivi",
	he => "תוספים",
	nl => "additieven",
},

ingredients_from_palm_oil_s => {
	fr => "ingrédient issu de l'huile de palme",
	en => "ingredient from palm oil",
	es => "ingrediente procedente de aceite de palma",
	pt_pt => "ingrediente proveniente de óleo de palma",
	ro => "ingredient din ulei de palmier",
	he => "רכיב משמן דקלים",
	nl => "ingrediënt uit palmolie",
},

ingredients_from_palm_oil_p => {
	fr => "ingrédients issus de l'huile de palme",
	en => "ingredients from palm oil",
	es => "ingredientes procedentes de aceite de palma",
	pt_pt => "ingredientes a partir de óleo de palma",
	ro => "ingrediente din ulei de palmier",
	he => "רכיבים משמן דקלים",
	nl => "ingrediënten uit palmolie",
},

ingredients_that_may_be_from_palm_oil_s => {
	fr => "ingrédient pouvant être issu de l'huile de palme",
	en => "ingredient that may be from palm oil",
	es => "ingrediente que puede proceder de aceite de palma",
	pt_pt => "ingrediente que pode partir de óleo de palma",
	ro => "ingredient care ar putea proveni din ulei de palmier",
	he => "רכיב שעשוי להיות משמן דקלים",
	nl => "ingrediënt dat mogelijk palmolie bevat",
},

ingredients_that_may_be_from_palm_oil_p => {
	fr => "ingrédients pouvant être issus de l'huile de palme",
	en => "ingredients that may be from palm oil",
	es => "ingredientes que pueden proceder de aceite de palma",
	pt_pt => "ingredientes que podem partir de óleo de palma",
	ro => "ingrediente care ar putea proveni din ulei de palmier",
	he => "רכיבים שעשויים להיות משמן דקלים",
	nl => "ingrediënten die mogelijk palmolie bevatten",
},

ingredients_from_or_that_may_be_from_palm_oil_p => {
	fr => "ingrédients issus ou pouvant être issus de l'huile de palme",
	en => "ingredients from or that may be from palm oil",
	es => "ingredientes que proceden o pueden proceder de aceite de palma",
	pt_pt => "ingredientes a partir ou que podem partir de óleo de palma",
	ro => "ingrediente care ar putea fi din sau ar putea proveni din ulei de palmier",
	he => "רכיבים שעשויים או מיוצרים משמן דקלים",
	nl => "ingrediënten die (mogelijk) palmolie bevatten",
},

add_product => {
	fr => 'Ajouter un produit',
	en => 'Add a product',
	es => 'Añadir un producto',
	pt => 'Adicionar um produto',
	de => 'Ein Produkt hinzufügen',
	ro => "Adăugare produs",
	he => 'הוספת מוצר',
	nl => "Een product toevoegen",
},

barcode_number => {
	fr => 'Chiffres du code barre :',
	en => 'Barcode number:',
	es => 'Cifras del código de barras :',
	pt => 'Número do código de barras:',
	ro => "Numărul din codul de bare:",
	he => 'מספר ברקוד:',
	nl => "Nummer van de barcode",
},

barcode => {
	fr => 'Code barre',
	en => 'Barcode',
	de => 'Barcode',
	es => 'Código de barras',
	pt => 'Código de barras',
	ro => "Codul de bare",
	he => 'ברקוד',
	nl => "Barcode",
},

or => {
	fr => 'ou :',
	en => 'or :',
	es => 'o :',
	pt => 'ou :',
	ro => "sau:",
	de => 'oder :',
	he => 'או:',
	nl => "of",
},

no_barcode => {
	fr => 'Produit sans code barre',
	en => 'Product without barcode',
	de => 'Produkt ohne Barcode',
	es => 'Producto sin código de barras',
	pt => 'Produto sem código de barras',
	ro => "Produs fără cod de bare",
	he => 'מוצר ללא ברקוד',
	nl => "Product zonder barcode",
},

add => {
	fr => 'Ajouter',
	en => 'Add',
	es => 'Añadir',
	pt => 'Adicionar',
	ro => "Adaugă",
	de => 'Hinzufügen',
	he => 'הוספה',
	it => 'Aggiungi',
	nl => "Toevoegen",
},

product_image_with_barcode => {
	fr => 'Image du produit avec code barre :',
	en => 'Product picture with barcode:',
	de => 'Produktfoto mit Barcode:',
	es => 'Imagen del producto con código de barras:',
	pt => 'Imagem do produto com o código de barras:',
	ro => "Imaginea produsului cu codul de bare:",
	he => 'תמונת המוצר עם ברקוד:',
	nl => "Foto van het product met barcode",

},

send_image => {
	fr => 'Envoyer une image...',
	en => 'Send a picture...',
	es => 'Enviar una imagen...',
	pt => 'Enviar uma imagem...',
	ro => "Trimiteți o imagine...",
	he => 'שליחת תמונה...',
	it => 'Invia una photo...',
	nl => "Een foto versturen...",
},

sending_image => {
	fr => 'Image en cours d\'envoi',
	en => 'Sending image',
	es => 'Enviando la imagen',
	pt => 'A enviar a imagem',
	ro => "Imagine în curs de trimitere",
	he => 'התמונה נשלחת',
	nl => "De foto wordt verzonden",
},

send_image_error => {
	fr => 'Erreur lors de l\'envoi',
	en => 'Upload error',
	es => 'Error al enviar',
	pt => 'Erro ao enviar a imagem',
	ro => "Eroare de transmisie",
	he => 'ההעלאה נכשלה',
	nl => "Fout bij het verzenden",
},

edit_product => {
	fr => 'Modifier un produit',
	en => 'Edit a product',
	es => 'Modifica un producto',
	pt => 'Editar um produto',
	ro => "Modificare produs",
	he => 'עריכת מוצר',
	it => 'Modifica un prodotto',
	nl => 'Een product aanpassen',
},

edit_product_page => {
	fr => 'Modifier la fiche',
	en => 'Edit the page',
	es => 'Modifica la página',
	pt => 'Editar a página',
	ro => "Modificare pagină",
	he => 'עריכת העמוד',
	it => 'Modifica la pagina',
	nl => 'De pagina aanpassen',
},

delete_product_page => {
	fr => 'Supprimer la fiche',
	en => 'Delete the page',
	es => 'Elimina la página',
	pt => 'Eliminar a página',
	ro => "Ștergere pagină",
	he => 'מחיקת העמוד',
	nl => 'De pagina verwijderen',
},


delete_product => {
	fr => 'Supprimer un produit',
	en => 'Delete a product',
	es => 'Elimina un producto',
	pt => 'Eliminar um produto',
	ro => "Ștergere produs",
	he => 'מחיקת מוצר',
	nl => 'Een product verwijderen',
},

search => {
	fr => 'Rechercher',
	en => 'Search',
	es => 'Buscar',
	pt => 'Procurar',
	ro => "Căutare",
	he => 'חיפוש',
	nl => 'Zoeken',
},

search_title => {
	fr => 'Rechercher un produit, une marque, un ingrédient, un nutriment etc.',
	en => 'Search a product, brand, ingredient, nutriment etc.',
	es => 'Busca un producto, marca, ingrediente, nutriente, etc.',
	pt => 'Procurar um produto, marca, ingrediente, nutriente, etc.',
	ro => "Căutați un produs, marcă, ingredient, nutrient etc.",
	he => 'חיפוש מוצר, מותג, רכיב, מרכיב תזונתי וכו׳',
	nl => 'Een product, een merk, een ingrediënt, een voedingsstof, etc. zoeken.',
},

product_added => {
	fr => 'Produit ajouté le',
	en => 'Product added on',
	es => 'Producto añadido el',
	pt => 'Produto adicionado a',
	ro => "Produs adăugat în",
	he => 'המוצר נוסף ב־',
	nl => 'Product toegevoegd op',
},

by => {
	fr => 'par',
	en => 'by',
	es => 'por',
	pt => 'por',
	ro => "de către",
	he => 'על־ידי',
	nl => "door",
},

missions => {
	fr => 'Missions',
	en => 'Missions',
	es => 'Misiones',
	pt => 'Missões',
	ro => "Misiuni",
	he => 'משימות',
	nl => "Missies",
},


mission_ => {
	fr => 'Mission : ',
	en => 'Mission: ',
	es => 'Misión: ',
	pt => 'Missão: ',
	ro => "Misiune: ",
	he => 'משימה: ',
	nl => "Missie: ",
},

completed_n_missions => {
	fr => 'a accompli %d missions :',
	en => 'completed %d missions:',
	es => 'completadas %d misiones:',
	pt => 'completou %d missões:',
	ro => "a terminat %d misiuni:",
	he => 'הושלמו %d משימות:',
	nl => "%s missies voltooid",
},
	
mission_goal => {
	fr => 'Objectif :',
	en => 'Goal:',
	es => 'Objetivo:',
	pt => 'Objetivo:',
	ro => "Obiectiv:",
	he => 'יעד:',
	nl => "Doel:",
},

mission_accomplished_by => {
	fr => 'Cette mission a été accomplie par :',
	en => 'This mission has been completed by:',
	es => 'Esta misión ha sido completada por:',
	pt => 'Esta missão foi completa por:',
	ro => "Această misiune a fost terminată de către:",
	he => 'משימה זאת הושלמה על־ידי:',
	nl => 'Deze missie werd voltooid door:',
},

mission_accomplished_by_n => {
	fr => 'Accomplie par %d personnes.',
	en => 'Completed by %d persons.',
	es => 'Completada por %d personas.',
	pt => 'Completa por %d pessoas.',
	ro => "Terminată de către %d persoane.",
	he => 'הושלמה על־ידי %d משתמשים.',
	nl => 'Voltooid door %d personen',
},

mission_accomplished_by_nobody => {
	fr => 'Soyez le premier à accomplir cette mission!',
	en => 'Be the first to complete this mission!',
	es => '¡Sé el primero en cumplir esta misión!',
	pt => 'Seja o primeiro a completar esta missão!',
	ro => "Fii primul care termină această misiune!",
	he => 'משימה זו טרם הושלמה, קדימה, קטן עליך!',
	nl => 'Wees de eerste om deze missie te voltooien!',
},

all_missions => {
	fr => 'Toutes les missions',
	en => 'All missions',
	es => 'Todas las misiones',
	pt => 'Todas as missões',
	ro => "Toate misiunile",
	he => 'כל המשימות',
	nl => 'Alle missies',
	de => 'Alle Missionen',
},

salt_equivalent => {
	fr => 'équivalent sel',
	en => 'salt equivalent',
	es => 'equivalente en sal',
	pt => 'equivalente em sal',
	ro => "echivalentul de sare",
	he => 'תחליף מלח',
	nl => 'equivalent zout',
},

additives_3 => {
	fr => 'Additif alimentaire interdit en Europe. A éviter absolument.',
	es => 'Aditivo alimentario prohibido en Europa. Evítalo completamente.',
	pt => 'Aditivo alimentar proibido na Europa. A evitar completamente.',
	ro => "Aditiv alimentar interzis în Europa. De evitat complet.",
	nl => 'Voedingsadditief verboden in Europa. Absoluut te vermijden.',
},

additives_2 => {
	fr => 'Additif alimentaire à risque. A éviter.',
	es => 'Aditivo alimentario con riesgo. A evitar.',
	ro => "Aditiv alimentar riscant. De evitat.",
	pt => 'Aditivo alimentar com riscos. A evitar.',
	nl => 'Risicovol voedingsadditief. Te vermijden.',
},

additives_1 => {
	fr => 'Additif alimentaire potentiellement à risque. A limiter.',
	es => 'Aditivo alimentario con riesgo potencial. A limitar.',
	ro => "Aditiv alimentar potențial riscant. De limitat.",
	pt => 'Aditivo alimentar potencialmente com risco . A limitar.',
	nl => 'Mogelijk risicovol voedingsadditief. Beperken.',
},

licence_accept => {
	fr => 'En ajoutant des informations et/ou des photographies, vous acceptez de placer irrévocablement votre contribution sous licence <a href="http://opendatacommons.org/licenses/dbcl/1.0/">Database Contents Licence 1.0</a>
pour les informations et sous licence <a href="http://creativecommons.org/licenses/by-sa/3.0/deed.fr">Creative Commons Paternité - Partage des conditions initiales à l\'identique 3.0</a> pour les photos.
Vous acceptez d\'être crédité par les ré-utilisateurs par un lien vers le produit auquel vous contribuez.',
	en => 'By adding information, data and/or images, you accept to place irrevocably your contribution under the <a href="http://opendatacommons.org/licenses/dbcl/1.0/">Database Contents Licence 1.0</a> licence
for information and data, and under the <a href="http://creativecommons.org/licenses/by-sa/3.0/deed.en">Creative Commons Attribution - ShareAlike 3.0</a> licence for images.
You accept to be credited by re-users by a link to the product your are contributing to.',
	es => 'Al adjuntar información, datos y/o imágenes, acepta que su contribución sea añadida de forma irrevocable bajo la licencia <a href="http://opendatacommons.org/licenses/dbcl/1.0/">Database Contents Licence 1.0</a>
para la información y datos, y bajo la licencia<a href="http://creativecommons.org/licenses/by-sa/3.0/deed.en">Creative Commons Attribution - ShareAlike 3.0</a> para las imágenes.
También acepta recibir el reconocimiento por la reutilización de los datos mediante un enlace al producto al que ha contribuído.',
	pt_pt => 'Ao adicionar informações e/ou imagens, você aceita irrevogavelmente a sua contribuição sob a licença <a href="http://opendatacommons.org/licenses/dbcl/1.0/">Database Contents Licence 1.0</a>
pelas informações, e sob a licença <a href="http://creativecommons.org/licenses/by-sa/3.0/deed.en">Creative Commons Attribution - ShareAlike 3.0</a> para as imagens.
Você aceita ser creditado por reutilizadores por um link para o produto que está a contribuir.',
	ro => 'Adăugând informații, date și/sau imagini, acceptați să vă faceți contribuția disponibilă sub licența pentru informație și date <a href="http://opendatacommons.org/licenses/dbcl/1.0/">Database Contents Licence 1.0</a>, și sub licența pentru imagini <a href="http://creativecommons.org/licenses/by-sa/3.0/deed.en">Creative Commons Attribution - ShareAlike 3.0</a>.
Acceptați să fiți creditat pentru re-utilizări cu un link către produsul la care contribuiți.',
	nl => 'Door informatie, data en/of beelden toe te voegen, aanvaardt u dat uw bijdrage onherroeplijk geplaatst wordt onder de <a href="http://opendatacommons.org/licenses/dbcl/1.0/">Database Contents Licence 1.0</a> licentie
voor informatie en data, en onder de <a href="http://creativecommons.org/licenses/by-sa/3.0/deed.en">Creative Commons Attribution - ShareAlike 3.0</a> licentie voor beelden.
U aanvaardt ook dat u gecrediteerd kan worden door hergebruikers via een link naar het product waar u tot bijgedragen hebt.',
},

tag_belongs_to => {
	fr => 'Fait partie de :',
	en => 'Belongs to:',
	es => 'Pertenece a:',
	pt => 'Pertence a:',
	ro => "Aparține de:",
	he => 'שייך ל־:',
	nl => 'Behoort tot:',
},

tag_contains => {
	fr => 'Contient :',
	en => 'Contains:',
	es => 'Contiene:',
	pt => 'Contém:',
	ro => "Conține",
	he => 'מכיל:',
	nl => 'Bevat:',
	de => "Enthält:",
},

newsletter_description => {
	fr => "S'inscrire à la lettre d'information (2 e-mails par mois maximum)",
	en => "Subscribe to the newsletter (2 emails per month maximum)",
	es => "Suscribirse al boletín informativo (2 correos electrónicos al mes como mucho)",
	pt => "Subscreva ao boletim de notícias (2 e-mails no máximo por mês)",
	pt_pt => "Subscreva o boletim de notícias (2 e-mails no máximo por mês)",
	ro => "Abonare la buletinul informativ (maxim 2 email-uri pe lună)",
	he => "הרשמה לרשימת הדיוור (2 הודעות דוא״ל בחודש לכל היותר, באנגלית)",
	nl => 'Inschrijven voor de nieuwsbrief (maximum 2 e-mails per maand)',
	de => "Newsletter abonnieren (maximum 2 E-Mails pro Monat)",
},

search_products => {
	fr => "Recherche de produits",
	en => "Products search",
	es => "Búsqueda de productos",
	pt => "Procura de produtos",
	ro => "Căutare produse",
	he => "חיפוש מוצרים",
	nl => 'Producten zoeken',
	de => "Produkt-Suche",
},

search_terms => {
	fr => "Termes de recherche",
	en => "Search terms",
	es => "Palabras a buscar",
	pt => "Termos de pesquisa",
	ro => "Termeni de căutare",
	he => "מילות חיפוש",
	nl => 'Zoektermen',
	de => "Suchkriterien",
},

search_terms_note => {
	fr => "Recherche les mots présents dans le nom du produit, le nom générique, les marques, catégories, origines et labels",
	en => "Search for words present in the product name, generic name, brands, categories, origins and labels",
	es => "Busca las palabras presentes en el nombre del producto, la denominación general, las marcas, las categorías, los orígenes y las etiquetas",
	pt_pt => "Procurar os termos no nome do produto, nome genérico, marcas, categorias, origens e etiquetas",
	ro => "Căutați după cuvinte prezente în numele produsului, numele generic, mărci, categorii, origini și etichete",
	he=> "חיפוש אחר מילים מתוך שם המוצר, שמו הכללי, מותגים, קטגוריות, מקורות ותוויות",
	nl => 'Zoek naar woorden in de naam van het product, de algemene benaming, de merken, de categorieën, de herkomst en de labels',
	de => "Die Suche erfolgt durch die Anpassung mit Produktnamen, allgemeinem Namen, Marken, Kategorien, Herkunft und Labels",
},

search_tag => {
	fr => "choisir un critère...",
	en => "choose a criteria...",
	es => "escoge un criterio...",
	pt => "escolhe um critério...",
	ro => "alegeți un criteriu...",
	he => "בחירת קריטריון...",
	nl => "kies een criterium...",
	de => "Kriterium auswählen...",
},

search_nutriment => {
	fr => "choisir un nutriment...",
	en => "choose a nutriment...",
	es => "escoge un nutriente...",
	pt => "escolhe um nutriente...",
	ro => "alegeți un nutrient...",
	he => "בחירת  מרכיב תזונתי...",
	nl => "kies een voedingsstof",
	de => "Nährstoff auswählen...",
},

search_tags => {
	fr => "Critères",
	en => "Criteria",
	es => "Criterios",
	pt => "Critérios",
	ro => "Criteriu",
	he => "קריטריונים",
	nl => "Criteria",
	de => "Kriterien",
},

search_nutriments => {
	fr => "Nutriments",
	en => "Nutriments",
	es => "Nutrientes",
	pt => "Nutrientes",
	ro => "Nutrienți",
	he => "מרכיבים תזונתיים",
	nl => "Voedingsstoffen",
	de => "Nährstoff",
},

search_contains => {
	fr => "contient",
	en => "contains",
	es => "contiene",
	pt => "contém",
	ro => "conține",
	he => "מכיל",
	nl => "bevat",
	de => "enthält",
},
search_does_not_contain => {
	fr => "ne contient pas",
	en => "does not contain",
	es => "no contiene",
	pt => "não contém",
	ro => "nu conține",
	he => "אינו מכיל",
	nl => "bevat geen",
	de => "enthält nicht",
},
search_or => {
	fr => "ou",
	en => "or",
	es => "o",
	pt => "ou",
	ro => "sau",
	he => "או",
	nl => "of",
	de => "oder",
},
search_page_size => {
	fr => "Nombre de résultats par page",
	en => "Number of results by page",
	es => "Número de resultados por página",
	pt => "Número de resultados por página",
	ro => "Numărul de rezultate per pagină",
	he => "מספר התוצאות לפי עמוד",
	nl => "Aantal resultaten per pagina",
	de => "Anzahl der Ergebnisse pro Seite",
},
sort_by => {
	fr => "Trier par :",
	en => "Sort by:",
	es => "Ordenar por:",
	pt => "Ordenar por:",
	ro => "Ordonează după:",
	he => "סידור לפי:",
	nl => "Ordenen volgens:",
	de => "Sortieren nach:",
},
sort_popularity => {
	fr => "Popularité",
	en => "Popularity",
	es => "Popularidad",
	pt => "Popularidade",
	ro => "Popularitate",
	nl => "Populariteit",
	de => "Popularität",
},
sort_product_name => {
	fr => "Nom du produit",
	en => "Product name",
	es => "Nombre del producto",
	pt => "Nome do produto",
	ro => "Numele produsului",
	he => "שם המוצר",
	nl => "Productnaam",
	de => "Produktname",
},
sort_created_t => {
	fr => "Date d'ajout",
	en => "Add date",
	es => "Fecha de creación",
	pt => "Data de criação",
	ro => "Data adăugării",
	he => "הוספת תאריך",
	nl => "Datum van toevoeging",
},
sort_modified_t => {
	fr => "Date de modification",
	en => "Edit date",
	es => "Fecha de modificación",
	pt => "Data de modificação",
	ro => "Data modificării",
	he => "עריכת התאריך",
	nl => "Datum van aanpassing",
	de => "Verarbeitungsdatum",
},

search_button => {
	fr => "Rechercher",
	en => "Search",
	de => "Suchen",
	es => "Buscar",
	pt => "Procurar",
	ro => "Căutare",
	he => "חיפוש",
	nl => "Zoeken",
},

search_edit => {
	fr => "Modifier les critères de recherche",
	en => "Change search criteria",
	es => "Cambiar los criterios de búsqueda",
	pt => "Modificar os critérios da pesquisa",
	ro => "Schimbă criteriile de căutare",
	he => "החלפת קריטריוני החיפוש",
	nl => "Wijzig de zoekcriteria",
	de => "Suchkriterien bearbeiten",
},

search_link => {
	fr => "Lien permanent vers ces résultats, partageable par e-mail et les réseaux sociaux",
	en => "Permanent link to these results, shareable by e-mail and on social networks",
	es => "Enlace permanente a estos resultados, para poderse compartir a través del correo electrónico y redes sociales",
	ro => "Link permanent la aceste rezultate, transmisibil prin e-mail și pe rețele sociale",
	he => "קישור ישיר לתוצאות אלו, ניתן להעברה בדוא״ל וברשתות חברתיות",
	nl => "Permanente link naar deze resultaten, deelbaar via e-mail of de sociale media",
},

search_graph_link => {
	fr => "Lien permanent vers ce graphique, partageable par e-mail et les réseaux sociaux",
	en => "Permanent link to this graph, shareable by e-mail and on social networks",
	es => "Enlace permanente a este gráfico, para poderse compartir a través del correo electrónico y redes sociales",
	pt => "Link permanente para este gráfico, para poder partilhar através do e-mail ou das redes sociais",
	ro => "Link permanent la acest grafic, transmisibil prin e-mail și pe rețele sociale",
	he => "קישור ישיר לתוצאות אלו, ניתן להעברה בדוא״ל וברשתות חברתיות",
	nl => "Permanente link naar deze grafiek, deelbaar via e-mail of de sociale media",
},

search_graph_title => {
	fr => "Visualiser les résultats sous forme de graphique",
	en => "Display results on a graph",
	es => "Ver los resultados de forma gráfica",
	pt => "Ver os resultados sob a forma de um gráfico",
	ro => "Afișarea rezultatelor pe un grafic",
	he => "הצגת תוצאות בתרשים",
	nl => "Geef de resultaten weer in een grafiek",
	de => "Ergebnisse in einer Grafik anzeigen",
},

search_graph_2_axis => {
	fr => "Graphique sur 2 axes",
	en => "Scatter plot",
	es => "Gráfico en 2 ejes",
	pt => "Gráfico de dispersão",
	ro => "Grafic pe 2 axe",
	he => "פיזור התוואי",
	nl => "Grafiek met 2 assen",
	de => "Grafik mit 2 Achsen",
},

search_graph_note => {
	fr => "Le graphique ne montrera que les produits pour lesquels les valeurs representées sont connues.",
	en => "The graph will show only products for which displayed values are known.",
	es => "El gráfico mostrará solamente los productos para los cuales los valores representados son conocidos.",
	pt_pt => "O gráfico mostrará apenas os produtos cujos valores representados são conhecidos.",
	ro => "Graficul va arăta numai produse pentru care valorile afișate sunt cunoscute.",
	he => "התרשים יציג אך ורק מוצרים שהערכים שלהם ידועים.",
	nl => "De grafiek geeft enkel producten weer waarvan de afgebeelde waarden gekend zijn.",
},

graph_title => {
	fr => "Titre du graphique",
	en => "Graph title",
	es => "Título del gráfico",
	pt => "Título de gráfico",
	ro => "Titlul graficului",
	he => "כותרת התרשים",
	nl => "Titel van de grafiek",
	de => "Titel der Grafik",
},

graph_count => {
	fr => "%d produits correspondent aux critères de recherche, dont %i produits avec des valeurs définies pour les axes du graphique.",
	en => "%d products match the search criterias, of which %i products have defined values for the graph's axis.",
	es => "%d productos coinciden con los criterios de búsqueda, de los cuales %i productos tienen valores definidos en los ejes del gráfico.",
	pt => "%d produtos coincidem com os critérios de pesquisa, dos quais %i produtos têm valores definidos para os eixos do gráfico.",
	ro => "%d produse se potrivesc criteriilor de căutare, din care %i produse au valori definite pentru axele graficului",
	he => "%d מוצרים תואמים את קריטריוני החיפוש, מתוכם ל־%i מוצרים יש ערכים מוגדרים עבור צירי התרשים.",
	nl => "%d producten stemmen overeen met uw zoekcriteria, waarvan %i producten gedefinieerde waarden hebben voor de assen van de grafiek.",
},

data_source => {
	fr => "Source des données",
	en => "Data source",
	es => "Origen de los datos",
	pt => "Origem dos dados",
	ro => "Sursa de date",
	nl => "Bron van de gegevens",
	de => "Datenquelle",
},

search_map_link => {
	fr => "Lien permanent vers cette carte, partageable par e-mail et les réseaux sociaux",
	en => "Permanent link to this map, shareable by e-mail and on social networks",
	es => "Enlace permanente a esta mapa, para poderse compartir a través del correo electrónico y redes sociales",
	pt => "Link permanente para este mapa, para poder partilhar através do e-mail ou das redes sociais",
	ro => "Link permanent la această hartă, transmisibil prin e-mail și pe rețele sociale",
	he => "קישור קבוע למפה זו, ניתן לשתף בדוא״ל וברשתות חברתיות",
	nl => "Permanente link naar deze kaar, deelbaar via e-mail of de sociale media",
},

search_map_title => {
	fr => "Visualiser les résultats sous forme de carte",
	en => "Display results on a map",
	es => "Ver los resultados sobre una mapa",
	pt => "Ver os resultados num mapa",
	ro => "Afișare rezultate pe o hartă",
	he => "הצגת תוצאות על מפה",
	nl => "Geef de resultaten weer op de kaart",
	de => "Ergebnisse im Kartenformat anzeigen",
},

search_map_note => {
	fr => "La carte ne montrera que les produits pour lesquels le lieu de fabrication ou d'emballage est connu.",
	en => "The map will show only products for which the production place is known.",
	es => "El mapa mostrará solamente los productos para los cuales se conoce el lugar de fabricación o de envasado.",
	pt => "O mapa mostrará apenas os produtos cujos locais de produção ou embalamento são conhecidos.",
	ro => "Harta va arăta numai produsele pentru care locul de producție este cunoscut.",
	he => "המפה תציג אך ורק מוצרים שמיקום הייצור שלהם ידוע.",
	nl => "De kaart toont enkel de producten waarvan de productielocatie gekend is.",
	de => "Die Karte zeigt nur die Produkte an, wofür der Herstellungs- oder Verpackungsort bekannt ist",
},

map_title => {
	fr => "Titre de la carte",
	en => "Map title",
	es => "Título del mapa",
	pt => "Título do mapa",
	ro => "Titlul hărții",
	he => "כותרת המפה",
	nl => "Titel van de kaart",
	de => "Titel der karte",
},

map_count => {
	fr => "%d produits correspondent aux critères de recherche, dont %i produits pour lesquels le lieu de fabrication ou d'emballage est connu.",
	en => "%d products match the search criterias, of which %i products have a known production place.",
	es => "%d productos coinciden con los criterios de búsqueda, de los cuales %i productos tienen valores definidos.",
	pt => "%d produtos coincidem com os critérios de pesquisa, dos quais %i produtos têm um local de fabrico ou embalamento conhecido.",
	ro => "%d produse corespund criteriilor de căutare, din care %i produse au un loc de producție cunoscut.",
	he => "%d מוצרים תואמים לקריטריוני החיפוש, מתוכם ל־%i מהמוצרים מקום הייצור ידוע.",
	nl => "%d producten stemmen overeen met uw zoekcriteria, waaronder %i producten waarvan de productielocatie of de locatie van verpakking gekend is.",
},


search_series_default => {
	fr => 'Autres produits',
	en => 'Other products',
	es => 'Otros productos',
	pt => 'Outros produtos',
	ro => "Alte produse",
	he => 'מוצרים אחרים',
	nl => "Andere producten",
	de => "Andere Produkte",
},

search_series => {
	fr => 'Utiliser une couleur différente pour les produits :',
	en => 'Use a different color for the following products:',
	es => 'Utiliza un color diferente para los siguientes productos:',
	pt => 'Utilizar uma cor diferente para os seguintes produtos:',
	ro => "Folosește o culoare diferită pentru următoarele produse:",
	he => 'שימוש בצבע שונה עבור המוצרים הבאים:',
	nl => "Gebruik een andere kleur voor de volgende producten:",
	de => "Unterschiedliche Farben für die folgenden Produkte verwenden:",
},

search_series_nutrition_grades => {
	fr => "Utiliser les couleurs des notes nutritionnelles",
	en => "Use nutrition grades colors",
},

search_series_organic => {
	fr => 'Bio',
	en => 'Organic',
	es => 'Ecológico',
	pt => 'Orgânico',
	ro => "Bio",
	he => 'אורגני',
	nl => "Bio",
	de => "Bio",
},

search_series_organic_label => {
	fr => 'bio',
	en => 'organic',
	es => 'Ecológico',
	pt => 'orgânico',
	ro => "bio",
	nl => "bio",
	de => "Bio",
},

search_series_fairtrade => {
	fr => 'Commerce équitable',
	en => 'Fair trade',
	es => 'Comercio justo',
	pt => 'Comércio justo',
	ro => "Comerț echitabil",
	he => 'סחר הוגן',
	nl => "Fair trade",
	de => "Fair Trade",
},

search_series_fairtrade_label => {
	fr => 'commerce-equitable',
	en => 'fair-trade',
	es => 'comercio-justo',
	pt => 'comércio-justo',
	ro => "comerț-echitabil",
	he => 'סחר-הוגן',
	nl => "fair-trade",
	de => "Fair Trade",
},

search_series_with_sweeteners => {
	fr => 'Avec édulcorants',
	en => 'With sweeteners',
	es => 'Con edulcorantes',
	pt => 'Com edulcorantes',
	ro => "Cu îndulcitori",
	he => 'עם ממתיקים',
	nl => "Met zoetstoffen",
	de => "Mit Süßstoff",
},

number_of_additives => {
	fr => "Nombre d'additifs",
	en => "Number of additives",
	es => "Número de aditivos",
	pt => "Número de aditivos",
	ro => "Numărul de aditivi",
	he => "מספר התוספים",
	nl => "Aantal additieven",
	de => "Zusatzstoff-Anzahl",
},

number_of_products => {
	fr => "Nombre de produits",
	en => "Number of products",
	es => "Número de productos",
	pt => "Número de produtos",
	ro => "Numărul produselor",
	nl => "Aantal producten",
	de => "Produktanzahl",
},

search_graph => {
	fr => 'Graphique',
	en => 'Graph',
	es => 'Gráfico',
	pt => 'Gráfico',
	ro => "Grafic",
	he => 'תרשים',
	nl => "Grafiek",
	de => "Grafik",
},

search_map => {
	fr => 'Carte',
	en => 'Map',
	es => 'Mapa',
	pt => 'Mapa',
	ro => "Hartă",
	he => 'מפה',
	nl => "Kaart",
	de => "Karte",
},

search_title_graph => {
	fr => 'Graphique des résultats',
	en => 'Results graph',
	es => 'Gráfico de los resultatdos',
	pt => 'Gráfico dos resultados',
	ro => "Graficul cu rezultate",
	he => 'תרשים התוצאות',
	nl => "Grafiek van de resultaten",
	de => "Ergebnisgrafik",
},

search_title_map => {
	fr => 'Carte des résultats',
	en => 'Results map',
	es => 'Mapa de los resultatdos',
	pt => 'Mapa dos resultados',
	ro => "Harta cu rezultate",
	he => 'מפת התוצאות',
	nl => "Kaart van de resultaten",
	de => "Ergebniskarte",
},

search_results => {
	fr => "Résultats de la recherche",
	en => "Search results",
	es => "Resultados de la búsqueda",
	pt => "Resultados da pesquisa",
	ro => "Rezultatele căutării",
	he => "תוצאות החיפוש",
	nl => "Zoekresultaten",
	de => "Suchergebnisse",
},

search_download_results => {
	fr => "Télécharger les résultats au format CSV (Excel, OpenOffice)",
	en => "Download results in CSV format (Excel, OpenOffice)",
	es => "Descargar los resultados en formato CSV (Excel, OpenOffice)",
	pt => "Transferir os resultados em formato CSV (Excel, OpenOffice)",
	ro => "Descărcați rezultatele în format CSV (Excel, OpenOffice)",
	he => "הורדת התוצאות במבנה CSV (Excel, LibreOffice)",
	nl => "Download de resultaten in CSV-formaat (Excel, OpenOffice)",
	de => "Ergebnisse in CSV-Format herunterladen (Excel, OpenOffice)",
},

search_download_results_description => {
	fr => "Jeu de caractère : Unicode (UTF-8). Séparateur : tabulation (tab).",
	en => "Character set: Unicode (UTF-8)). Separator: tabulation (tab).",
	es => "Juego de caractéres: Unicode (UTF-8)). Separador: tabulador (tab).",
	pt => "Mapa de caracteres: Unicode (UTF-8). Separador: tabulação (TAB).",
	ro => "Set de caractere: Unicode (UTF-8). Separator: tabulare (tab).",
	he => "ערכת תווים: יוניקוד (UTF-8). הפרדה: טאב (tab)",
	nl => "Tekenset: Unicode (UTF-8). Separator: tab (tab)",
	de => "Zeichenset: Unicode (UTF-8). Trenner: Tabulator (tab-Taste).",
},

search_flatten_tags => {
	fr => "(Optionnel) - Créer une colonne pour chaque :",
	en => "(Optional) - Create a column for every:",
	cs => "(Nepovinné) - Vytvořit sloupec pro každý:",
	es => "(Opcional) - Crear una columna para cada:",
	pt => "(Opcional) - Criar uma coluna para cada:",
	ro => "(Opțional) - Crează o coloană pentru fiecare:",
	he => "(רשות) - יצירת עמודה בכל:",
	nl => "(Optioneel) - Een kolom creëren voor elke:",
	de => "(optional) - Spalte erstellen für jede(s)/n:",
},

search_download_button => {
	fr => "Télécharger",
	en => "Download",
	es => "Descargar",
	pt => "Transferir",
	ro => "Descarcă",
	he => "הורדה",
	nl => "Downloaden",
	de => "Herunterladen",
},

axis_x => {
	fr => "Axe horizontal",
	en => "Horizontal axis",
	es => "Eje horizontal",
	pt => "Eixo horizontal",
	ro => "Axa orizontală",
	he => "ציר אופקי",
	nl => "Horizontale as",
	de => "X-Achse",
},

axis_y => {
	fr => "Axe vertical",
	en => "Vertical axis",
	es => "Eje vertical",
	pt => "Eixo vertical",
	ro => "Axa verticală",
	he => "ציר אנכי",
	nl => "Verticale as",
	de => "Y-Achse",
},

search_generate_graph => {
	fr => "Générer le graphique",
	en => "Generate graph",
	es => "Generar el gráfico",
	pt => "Gerar o gráfico",
	ro => "Generare grafic",
	he => "יצירת תרשים",
	nl => "De grafiek maken",
	de => "Grafik erzeugen",
},

search_graph_warning => {
	fr => "Note : ce graphique a été généré par un utilisateur du site Open Food Facts. Le titre, les produits representés et les axes de représentation ont été choisis par l'auteur du graphique.",
	en => "Note: this is a user generated graph. The title, represented products and axis of visualization have been chosen by the author of the graph.",
	es => "Nota: Este gráfico fue generado por un usuario de Open Food Facts. El título, los productos representados y los ejes de la representación han sido escogidos por el autor del gráfico.",
	pt_pt => "Nota: Este gráfico foi gerado por um utilizador do Open Food Facts. O título, os produtos representados e os eixos de visualização foram escolhidos pelo autor do gráfico.",
	ro => "Notă: acesta este un grafic generat de un utilizator. Titlul, produsele reprezentate și axa de vizualizare au fost alese de către autorul graficului.",
	he => "לתשומת לבך: תרשים זה נוצר על־ידי משתמש. הכותרת, המוצרים המיוצגים והציר נבחרו כולם על־ידי יוצר התרשים.",
	nl => "Opmerking: deze grafiek werd gemaakt door een gebruiker van Open Food Facts. De titel, de afgebeelde producten en de assen werden gekozen door de maker van de grafiek.",
	de => "Bemerkung: diese Grafik wurde von einem Benutzer der Open Food Facts Gemeinschaft erzeugt. Der Titel, die ang ezeigten Produkte und die Achsen wurden von dem Benutzer selbst ausgewählt.",
},

search_generate_map => {
	fr => "Générer la carte",
	en => "Generate the map",
	es => "Generar la mapa",
	pt => "Gerar o mapa",
	ro => "Generează harta",
	he => "יצירת מפה",
	nl => "De kaart maken",
	de => "Karte erzeugen",
},

search_graph_blog => {
	fr => "<p>→ en savoir plus sur les graphiques d'Open Food Facts : <a href=\"http://fr.blog.openfoodfacts.org/news/des-graphiques-en-3-clics\">Des graphiques en 3 clics</a> (blog).</p>",
	en => "",
	es => "<p>→ para saber más acerca de los gráficos de Open Food Facts: <a href=\"http://fr.blog.openfoodfacts.org/news/des-graphiques-en-3-clics\">Los gráficos en 3 clics (en francés)</a> (blog).</p>",
	pt => "<p>→ para saber mais acerca dos gráficos do Open Food Facts: <a href=\"http://fr.blog.openfoodfacts.org/news/des-graphiques-en-3-clics\">Gráficos em 3 cliques (en francês)</a> (blog).</p>",
	ro => "<p>→ pentru a afla mai multe despre graficele de pe Open Food Facts : <a href=\"http://fr.blog.openfoodfacts.org/news/des-graphiques-en-3-clics\">Graficele în 3 click-uri (în franceză)</a> (blog).</p>",
	nl => "<p>→ meer weten over de grafieken van Open Food Facts: <a href=\"http://fr.blog.openfoodfacts.org/news/des-graphiques-en-3-clics\">Grafieken in drie muisklikken</a> (blog).</p>",
	de => "<p>→ mehr über Open Food Facts Grafiken erfahren: <a href=\"http://fr.blog.openfoodfacts.org/news/des-graphiques-en-3-clics\">Grafiken in 3-Click</a> (blog).</p>",
},

advanced_search => {
	fr => "Recherche avancée, graphiques et carte",
	en => "Advanced search and graphs",
	es => "Búsqueda avanzada y gráficos",
	pt => "Pesquisa avançada e gráficos",
	ro => "Căutare și grafice avansate",
	he => "חיפוש מתקדם ותרשימים",
	nl => "Geavanceerd zoeken, grafieken en kaart",
	de => "Erweiterte Suche, Grafiken und Karten",
},

edit_comment => {
	fr => "Description de vos changements",
	en => "Changes summary",
	es => "Descripción de los cambios",
	pt => "Resumo das suas edições",
	ro => "Sumarul schimbărilor",
	he => "תקציר השינויים",
	nl => "Overzicht van de wijzigingen",
	de => "Bearbeitung begründen",
},

delete_comment => {
	fr => "Raison de la suppression",
	en => "Reason for removal",
	es => "Motivo de la eliminación",
	pt => "Motivo para a eliminacão",
	ro => "Motivul ștergerii",
	he => "הסיבה להסרה",
	nl => "Reden voor verwijdering",
	de => "Löschung begründen",
},  

history => {
	fr => "Historique des modifications",
	en => "Changes history",
	es => "Historial de revisiones",
	pt => "Historial das edições",
	ro => "Istoricul schimbărilor",
	he => "היסטוריית השינויים",
	nl => "Geschiedenis van de wijzigingen",
	de => "Historie der Veränderungen",
},

new_code => {
	fr => "Une erreur de code barre ? Vous pouvez entrer le bon ici :",
	en => "If the barcode is not correct, please correct it here:",
	es => "Si el código de barras no es correcto, por favor corrígelo aquí:",
	pt => "O código de barras está errado? Corrige-o aqui, por favor:",
	ro => "Dacă codul de bare nu este corect, sunteți rugat să-l corectați aici:",
	he => "אם הברקוד לא נכון, נא לתקן אותו כאן:",
	nl => "Een foutieve barcode? Geef hier de correcte code in:",
	de => "Barcode ist fehlerhaft? Bitte einfach hier korrigieren:",
},

new_code_note => {
	fr => "Pour les produits sans code barre, un code interne est attribué automatiquement.",
	en => "For products without a barcode, an internal code is automatically set.",
	es => "A los productos sin código de barras se les asignará automáticamente un código interno.",
	pt => "Para os produtos sem código de barras, um código interno é atribuido automaticamente.",
	ro => "Pentru produsele fără un cod de bare, un cod intern este înregistrat.",
	he => "למוצרים ללא ברקוד, מוגדר קוד פנימי אוטומטית.",
	nl => "Producten zonder barcode krijgen automatisch een interne code.",
	de => "Produkte ohne Barcode werden automatisch mit einem internen Code gestampelt.",
},

error_new_code_already_exists => {
	fr => "Un produit existe déjà avec le nouveau code",
	en => "A product already exists with the new code",
	es => "Ya existe un producto con el nuevo código",
	pt => "Já existe um produto com este novo código",
	ro => "Un produs cu noul cod deja există",
	he => "כבר קיים מוצר עם הקוד החדש",
	nl => "Er bestaat reeds een product met de nieuwe code",
},

product_js_uploading_image => {
	fr => "Image en cours d'envoi",
	en => "Uploading image",
	es => "Cargando la imagen",
	pt => "Enviando a imagem",
	pt_pt => "A enviar a imagem",
	ro => "Îmaginea se transmite",
	he => "התמונה נשלחת",
	nl => "De foto wordt verzonden",
	de => "Das Foto wird hochgeladen",
},

product_js_image_received => {
	fr => "Image reçue",
	en => "Image received",
	es => "La imagen ha sido recibida",
	pt => "Imagem recebida",
	ro => "Imagine recepționată",
	he => "התמונה התקבלה",
	nl => "Foto ontvangen",
	de => "Foto erfolgreich hochgeladen",
},

product_js_image_upload_error => {
	fr => "Erreur lors de l'envoi de l'image",
	en => "Error while uploading image",
	es => "Se ha producido un error al enviar la imagen",
	pt => "Houve um erro durante o envio da imagem",
	ro => "Eroare în timpul transmiterii imaginii",
	he => "העלאת התמונה נכשלה",
	nl => "Fout tijdens het uploaden van de foto",
	de => "Ein Fehler ist während des Hochladens des Fotos aufgetreten",
},

product_js_image_rotate_and_crop => {
	fr => "Redressez l'image si nécessaire, puis cliquez et glissez pour sélectionner la zone d'intérêt :",
	en => "Rotate the image if necessary, then click and drag to select the interesting zone:",
	es => "Rota la imagen si es necesario, después haz clic y arrastra para seleccionar la zona de interés:",
	pt => "Rode a imagem se necessário, depois clique e arraste para seleccionar a zona pretendida:",
	ro => "Rotiți imaginea dacă este necesar, apoi dați click și trageți pentru a selecta zona de interes:",
	he => "הטיית התמונה אם יש צורך בכך ולאחר מכן ניתן ללחוץ ולגרור כדי לבחור את האזור המעניין:",
	nl => "Draai indien nodig de foto, klik en sleep om de beoogde zone te selecteren:",
},

product_js_image_rotate_left => {
	fr => "Pivoter à gauche",
	en => "Rotate left",
	es => "Girar a la izquierda",
	pt => "Rodar para a esquerda",
	ro => "Rotire la stânga",
	he => "הטייה לשמאל",
	nl => "Naar links draaien",
	de => "Nach Links drehen",
},

product_js_image_rotate_right => {
	fr => "Pivoter à droite",
	en => "Rotate right",
	es => "Girar a la derecha",
	pt => "Rodar para a direita",
	ro => "Rotire la dreapta",
	he => "הטייה לימין",
	nl => "Naar rechts draaien",
	de => "Nach Rechts drehen",
},

product_js_image_normalize => {
	fr => "Equilibrage des couleurs",
	en => "Normalize colors",
	es => "Equilibra los colores",
	pt => "Normalizar as cores",
	ro => "Normalizare culori",
	he => "איזון הצבעים",
	nl => "Kleurenbalans corrigeren",
	de => "Farbenwiedergabe korrigieren",
},

product_js_image_open_full_size_image => {
	fr => "Voir la photo en grand dans une nouvelle fenêtre",
	en => "Open the picture in original size in a new windows",
	es => "Abrir la imagen en su tamaño original en una nueva ventana",
	pt => "Abrir a imagem no tamanho original numa nova janela",
	ro => "Deschide imaginea în dimensiunea originală într-o fereastră nouă",
	nl => "De foto in het groot of in een nieuw venster bekijken",
	de => "Das Foto in Großformat in einem neuen Fenster anzeigen",
},

product_js_image_white_magic => {
	fr => "Photo sur fond blanc : essayer d'enlever le fond",
	en => "Photo on white background: try to remove the background",
	es => "Foto sobre fondo blanco: prueba a eliminar el fondo",
	pt => "Fotografia sobre fundo branco: tentar eliminar o fundo",
	ro => "Fotografie pe fundal alb: încearcă să ștergi fundalul",
	he => "תמונה עם רקע לבן: לנסות להסיר את הרקע",
	nl => "Foto op een witte achtergrond: probeer de achtergrond te verwijderen",
	de => "Foto auf weißem Hintergrund: probieren, den Hintergrund zu entfernen",
},

product_js_image_save => {
	fr => "Valider et/ou recadrer l'image",
	en => "Validate and/or resize image",
	es => "Validar y/o recortar la imagen",
	pt => "Validar e/ou redimensionar a imagem",
	ro => "Validează și/sau redimensionează imaginea",
	he => "אימות ו/או שינוי גודל התמונה",
	nl => "De foto valideren en/of verkleinen",
	de => "Das Foto genehmigen und/oder ausrichten",
},

product_js_image_saving => {
	fr => "Image en cours d'enregistrement",
	en => "Saving image",
	es => "La imagen está siendo guardada",
	pt => "A guardar imagem",
	ro => "Imaginea se salvează",
	he => "התמונה נשמרת",
	nl => "De foto wordt opgeslagen",
	de => "Das Foto wird gespeichert",
},

product_js_image_saved => {
	fr => "Image enregistrée.",
	en => "Image saved",
	es => "Imagen guardada",
	pt => "Imagem guardada",
	ro => "Imagine salvată",
	he => "התמונה נשמרה",
	nl => "Foto opgeslagen",
},

product_js_current_image => {
	fr => "Image actuelle :",
	en => "Current image:",
	es => "Imagen actual:",
	pt => "Imagem atual:",
	ro => "Imaginea curentă:",
	he => "התמונה הנוכחית:",
	nl => "Huidige foto:",
	de => "Aktuelles Foto:",
},

product_js_extract_ingredients => {
	fr => "Extraire les ingrédients de l'image",
	en => "Extract the ingredients from the picture",
	es => "Extraer los ingredientes de la imagen",
	pt => "Extrair os ingredientes da imagem",
	ro => "Extrage ingredientele din imagine:",
	he => "חילוץ הרכיבים מהתמונה",
	nl => "Detecteer de ingrediënten op de foto",
	de => "Die Zutaten des Fotos extrahieren",
},

product_js_extracting_ingredients => {
	fr => "Extraction des ingrédients en cours",
	en => "Extracting ingredients",
	es => "Extrayendo los ingredientes",
	pt => "Extraindo os ingredientes",
	pt_pt => "A extrair os ingredientes",
	ro => "Extrag ingredientele",
	he => "הרכיבים מחולצים",
	nl => "Ingrediënten aan het detecteren",
	de => "Die Extrahierung der Zutaten ist in Verarbeitung",
},

product_js_extracted_ingredients_ok => {
	fr => "Le texte des ingrédients a été extrait. La reconnaissance du texte n'est pas toujours parfaite, merci de vérifier le texte ci-dessous et de corriger les éventuelles erreurs.",
	en => "Ingredients text has been extracted. Text recognition is not perfect, so please check the text below and correct errors if needed.",
	es => "Se ha extraído el texto de los ingredientes. El reconocimiento de texto no siempre es perfecto. Por favor revisa el texto extraído y corrige los errores si es necesario.",
	pt => "A lista de ingredientes foi extraída. O reconhecimento do texto não é sempre perfeito. Por favor verifique o texto extraído e corrija os erros se necessário.",
	ro => "Textul cu ingrediente a fost extras. Recunoașterea de text nu este perfectă, deci sunteți rugați să verificați textul de mai jos și să corectați erorile dacă este necesar.",
	he => "טקסט הרכיבים חולץ. מנגנון זיהוי הטקסט אינו מושלם ולכן מומלץ לבדוק אם הטקסט שלהלן נכון ולתקן את הטעויות במידת הצורך.",
	nl => "De tekst met de ingrediënten werd gedetecteerd. De tekstherkenning is niet altijd perfect, gelieve de tekst hieronder te controleren en eventuele fouten te verbeteren.",
},

product_js_extracted_ingredients_nok => {
	fr => "Le texte des ingrédients n'a pas pu être extrait. Vous pouvez essayer avec une image plus nette, de meilleure résolution, ou un meilleur cadrage du texte.",
	en => "Ingredients text could not be extracted. Try with a sharper image, with higher resolution or a better framing of the text.",
	es => "No se puede extraer el texto de los ingredientes. Prueba con una imagen más nítida, con mayor resolución o con un mejor encuadre del texto.",
	pt => "Não foi possível extrair a lista de ingredientes. Tente de novo com uma imagem mais nítida, com maior resolução ou melhor enquadramento do texto.",
	ro => "Textul cu ingrediente nu a putut fi extras. Încercați cu o imagine mai clară, cu o rezoluție mai mare sau o mai bună încadrare a textului.",
	he => "לא ניתן לחלץ את טקסט הרכיבים. כדאי לנסות עם תמונה חדה יותר ברזולוציה גבוהה יותר או במסגור טוב יותר של הטקסט.",
	nl => "De tekst met de ingrediënten kon niet gedetecteerd worden. Je kan het opnieuw proberen met een scherpere foto, of met een foto met een hogere resolutie of een betere kadrering van de tekst",
},

product_js_upload_image => {
	fr => "Envoyer une image",
	en => "Add a picture",
	es => "Añadir una imagen",
	pt => "Adicionar uma imagem",
	ro => "Agaugă o imagine",
	he => "הוספת תמונה",
	nl => "Een foto toevoegen",
	de => "Foto hochladen",
},

product_js_upload_image_note => {
	fr => "→ Avec Chrome, Firefox et Safari, vous pouvez sélectionner plusieurs images (produit, ingrédients, infos nutritionnelles etc.) en cliquant avec la touche Ctrl enfoncée, pour les envoyer toutes en même temps.",
	en => "→ With Chrome, Firefox and Safari, you can select multipe pictures (product, ingredients, nutrition facts etc.) by clicking them while holding the Ctrl key pressed to add them all in one shot.",
	es => "→ Con Chrome, Firefox y Safari, puedes seleccionar varias imágenes al mismo tiempo (producto, ingredientes, información nutricional, etc.) manteniendo pulsada la tecla Ctrl y haciendo clic sobre las imágenes que quieras seleccionar para enviarlas todas a la vez.",
	pt => "→ Com o Chrome, Firefox e Safari, pode seleccionar várias imagens ao memsmo tempo (produto, ingredientes, informação nutricional, etc.) clicando nelas enquando a tecla Ctrl estiver premida, para as adicionar de uma só vez.",
	ro => "→ Cu Chrome, Firefox și Safari, puteți selecta mai multe imagini (produs, ingrediente, valori nutriționale etc.). Dați click pe ele în timp ce țineți apăsați tasta Ctrl pentru a le adăuga pe toate în același timp.",
	he => "← עם כרום, פיירפוקס וספארי, ניתן לבחור מספר תמונות (מוצר, רכיבים, מפרט תזונתי) על ידי לחיצה עליהן בעת החזקת המקש Ctrl כדי להוסיף את כולן באותה התמונה.",
	nl => "→ Met Chrome, Firefox en Safari kan je verschillende foto's (product, ingrediënten, nutritionele informatie, etc.) selecteren door tijdens het klikken de Ctrl-toets ingedrukt te houden om ze in één keer verzenden.",
	de => "Mit Chrome, Firefox und Safari können Sie einfach durch die Benutzung der Strg-Taste mehrere Fotos auswählen (Produkt, Zutaten, Nährwertinformationen, usw.), um diese einmalig hochzuladen.",
},

image_upload_error_image_already_exists => {
	fr => "Cette photo a déjà été envoyée.",
	en => "This picture has already been sent.",
	de => "Dieses Foto wurde schon hochgeladen.",
},

image_upload_error_image_too_small => {
	fr => "La photo est trop petite. Attention à ne pas envoyer de photos prises sur Internet. Merci de n'envoyer que vos propres photos.",
	en => "The picture is too small. Please do not upload pictures found on the Internet and only send photos you have taken yourself.",
	de => "Das Foto ist zu klein. Bitte beachten sie, kein Foto von dem Internet sondern nur Ihre eigenen Fotos hochzuladen.",
},

product_add_nutrient => {
	fr => "Ajouter un nutriment",
	en => "Add a nutrient",
	es => "Añade un nutriente",
	pt => "Adicionar um nutriente",
	ro => "Adăugați un nutrient", 
	nl => "Een voedingsstof toevoegen",
	de => "Nährstoff hinzufügen",
},

product_changes_saved => {
	fr => "Les modifications ont été enregistrées.",
	en => "Changes saved.",
	es => "Los cambios han sido guardados.",
	pt => "As modificações foram guardadas.",
	ro => "Schimbările au fost salvate.",
	he => "השינויים נשמרו.",
	nl => "De wijzigingen werden opgeslagen.",
	de => "Veränderungen wurden gespeichert.",
},

see_product_page => {
	fr => "Voir la fiche du produit",
	en => "See the product page",
	es => "Ver la página del producto",
	pt => "Ver a página do produto",
	ro => "Vedeți pagina produsului",
	he => "הצגת עמוד המוצר",
	nl => "De pagina van het product bekijken",
	de => "Produktdetails ansehen",
},

products_with_nutriments => {
	fr => "avec informations<br/>nutritionnelles",
	en => "with nutrition facts",
	es => "con información nutricional",
	pt => "com informacão nutricional",
	ro => "cu valori nutriționale",
	he => "עם מפרט תזונתי",
	nl => "met nutritionele informatie",
	de => "mit Nährwertinformationen",
},

tagstable_search => {
	fr => "Recherche :",
	en => "Search:",
	es => "Buscar:",
	pt => "Procurar:",
	ro => "Căutare:",
	he => "חיפוש:",
	nl => "Zoeken:",
	de => "Suche:",
},

tagstable_filtered => {
	fr => "parmi _MAX_",
	en => "out of _MAX_",
	es => "fuera de _MAX_",
	pt => "de_MAX_",
	ro => "din _MAX_",
	he => "מתוך _MAX_",
	nl => "tussen _MAX_",
	de => "auf _MAX_",
},

search_ingredients => {
	fr => "Ingrédients",
	en => "Ingredients",
	es => "Ingredientes",
	pt => "Ingredientes",
	ro => "Ingrediente",
	he => "רכיבים",
	nl => "Ingrediënten",
	de => "Zutaten",
},

search_with => {
	fr => 'Avec',
	en => 'With',
	es => 'Con',
	de => 'Mit',
	pt => 'Com',
	ro => "Cu",
	he => 'עם',
	nl => "Met",
},

search_without => {
	fr => 'Sans',
	en => 'Without',
	es => 'Sin',
	de => 'Ohne',
	pt => 'Sem',
	ro => "Fără",
	he => 'ללא',
	nl => "Zonder",
},

search_indifferent => {
	fr => 'Indifférent',
	en => 'Indifferent',
	es => 'Indiferente',
	pt => 'Indiferente',
	ro => "Indiferent",
	he => 'ללא שינוי',
	nl => "Onbepaald",
	de => "Gleichgültig",
},

products_you_edited => {
	fr => "Les produits que vous avez ajoutés ou modifiés",
	en => "Products you added or edited",
	es => "Productos que has añadido o modificado",
	pt => "Produtos que adicionou ou editou",
	ro => "Produse adăugate sau modificate de dumneavoastră",
	he => "משתנים שהוספת או ערכת",
	nl => "De producten die u toegevoegd of aangepast hebt",
	de => "Produkte, die sie hinzugefûgt oder bearbeitet haben",
},

incomplete_products_you_added => {
	fr => "Les produits que vous avez ajoutés qui sont à compléter",
	en => "Products you added that need to be completed",
	es => "Productos añadidos por usted que necesitan ser completados",
	ro => "Produse adăugate de dumneavoastră care trebuie completate",
	pt => "Produtos adicionados por si que precisam de ser completados",
	nl => "Producten die u toegevoegd hebt die nog onvolledig zijn",
},

edit_settings => {
	fr => "Modifier les paramètres de votre compte",
	en => "Change your account parameters",
	es => "Cambiar la configuración de la cuenta",
	pt => "Mudar os parâmetros da conta",
	ro => "Schimbați parametrii contului",
	he => "החלפת משתני החשבון שלך",
	nl => "Wijzig de parameters van uw account",
	de => "Konteneinstellungen bearbeiten",
},

list_of_x => {
	fr => "Liste des %s",
	en => "List of %s",
	es => "Lista de %s",
	pt => "Lista de %s",
	ro => "Listă de %s",
	he => "רשימה של %s",
	nl => "Lijst van %s",
	de => "Liste von %s",
},

change_uploaded_images => {
	fr => "Images téléchargées",
	en => "Uploaded images",
	es => "Imágenes subidas",
	pt => "Imagens enviadas",
	ro => "Imagini încărcate",
	he => "תמונות שהועלו",
	nl => "Geüploade foto's",
	de => "Hochgeladene Fotos",
},

change_selected_images => {
	fr => "Images sélectionnées",
	en => "Selected images",
	es => "Imágenes seleccionadas",
	pt => "Imagens selecionadas",
	ro => "Imagini selectate",
	he => "תמונות נבחרות",
	nl => "Geselecteerde foto's",
	de => "Ausgewählte Fotos",
},

change_fields => {
	fr => "Informations",
	en => "Data",
	es => "Informaciones",
	pt => "Informações",
	ro => "Date",
	he => "נתונים",
	nl => "Gegevens",
	de => "Informationen",
},

change_nutriments => {
	fr => "Nutriments",
	en => "Nutriments",
	es => "Nutrientes",
	pt => "Nutrientes",
	ro => "Nutrienți",
	he => "מפרט תזונתי",
	nl => "Voedingsstoffen",
	de => "Nährstoff",
},

diff_add => {
	fr => 'Ajout :',
	en => 'Added:',
	es => 'Añadido:',
	pt => 'Adicionado:',
	ro => "Adăugate:",
	he => 'נוסף:',
	nl => "Toevoeging:",
	de => "Neu:",
},

diff_change => {
	fr => 'Changement :',
	en => 'Changed:',
	es => 'Cambiado:',
	pt => 'Alterado:',
	ro => "Schimbate:",
	he => 'השתנה:',
	nl => "Wijziging:",
	de => "Verändert:",
},

diff_delete => {
	fr => 'Suppression :',
	en => 'Deleted:',
	es => 'Eliminado:',
	pt => 'Alterado:',
	ro => "Șterse:",
	he => 'נמחק:',
	nl => "Verwijdering:",
	de => "Gelöscht:",
},


# states
state => {
	fr => 'Etat',
	en => 'State',
	es => 'Estado',
	pt => 'Estado',
	ro => "Status",
	he => 'מצב',
	nl => "Status",
	de => "Stand",
},

save => {
	fr => "Enregistrer",
	en => "Save",
	es => "Guardar",
	pt => "Salvar",
	ro => "Salvare",
	he => "שמירה",
	nl => "Opslaan",
	de => "Speichern",
},
saving => {
	fr => "Informations en cours d'enregistrement.",
	en => "Saving.",
	es => "Los datos están siendo guardados",
	pt => "Os dados estão a ser guardados",
	ro => "Salvez.",
	he => "בהליכי שמירה.",
	nl => "De gegevens worden opgeslagen.",
	de => "Daten werden gespeichert.",
},
saved => {
	fr => "Informations enregistrées.",
	en => "Saved.",
	es => "Los datos han sido guardados.",
	pt => "Os dados foram guardados.",
	ro => "Salvat.",
	he => "השמירה הצליחה.",
	nl => "De gegevens werden opgeslagen.",
	de => "Daten wurden gespeichert.",
},
not_saved => {
	fr => "Erreur d'enregistrement, merci de réessayer.",
	en => "Error while saving, please retry.",
	es => "Se ha producido un error guardando los datos, por favor inténtelo de nuevo.",
	pt => "Ocorreu um erro ao guardar os dados, por favor tente de novo.",
	ro => "Eroare de salvare, vă rog reîncercați.",
	he => "אירעה שגיאה במהלך השמירה, נא לנסות שוב.",
	nl => "Fout tijdens het opslaan, gelieve opnieuw te proberen",
	de => "Speicherproblem aufgetreten, bitte probieren Sie noch einmal .",
},

view => {
	fr => "voir",
	en => "view",
	es => "ver",
	pt => "ver",
	ro => "vedere",
	he => "צפייה",
	nl => "bekijken",
	de => "ansehen",
},

no_product_for_barcode => {
	fr => "Il n'y a pas de produit référencé pour le code barre %s.",
	en => "No product listed for barcode %s.",
	es => "No existe ningún producto con el código de barras %s.",
	pt => "Não existe nenhum produto com o código de barras %s.",
	ro => "Nici un produs listat pentru codul de bare %s",
	he => "לא נרשמו מוצרים על הברקוד %s",
	nl => "Er werd geen product gevonden voor de barcode %s.",
	de => "Kein Produkt ist mit dem Barcode %s referenziert.",
},

products_stats => {
	fr => "Evolution du nombre de produits sur Open Food Facts",
	en => "Evolution of the number of products on Open Food Facts",
	es => "Evolución del número de productos en Open Food Facts",
	pt => "Evolução do número de produtos no Open Food Facts",
	ro => "Evoluția numărului de produse pe Open Food Facts",
	he => "התפתחות מספר המוצרים ב־Open Food Facts",
	nl => "Evolutie van het aantal producten op Open Food Facts",
	de => "Entwicklung der Zahl von Produkten auf Open Food Facts",
},

products_stats_created_t => {
	fr => "Produits",
	en => "Products",
	es => "Productos",
	pt => "Produtos",
	ro => "Produse",
	he => "מוצרים",
	nl => "Producten",
	de => "Produkte",
},

products_stats_completed_t => {
	fr => "Produits avec fiche complète",
	en => "Products with complete information",
	es => "Productos con los datos completados",
	pt => "Produtos com informação completa",
	ro => "Produse cu informații complete",
	he => "מוצרים עם פרטים מלאים",
	nl => "Producten met alle informatie",
	de => "Produkte mit vollständigen Informationen",
},


months => {
	fr => "['Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre']",
	en => "['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']",
	es => "['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre']",
	pt => "['janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro']",
	ro => "['Ianuarie', 'Februarie', 'Martie', 'Aprilie', 'Mai', 'Iunie', 'Iulie', 'August', 'Septembrie', 'Octombrie', 'Noiembrie', 'Decembrie']",
	de => "['Januar', 'Februar', 'März', 'April', 'Mai', 'Juni', 'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember']",
	cs => "['Leden','Únor','Březen','Duben','Květen','Červen','Červenec','Srpen','Září','Říjen','Listopad','Prosinec']",
	zh => "['一月', '二月', '三月', '四月', '五月', '六月', '七月', '八月', '九月', '十月', '十一月', '十二月']",
	ja => "['一月', '二月', '三月', '四月', '五月', '六月', '七月', '八月', '九月', '十月', '十一月', '十二月']",
	he => "['ינואר','פברואר','מרץ','אפריל','מאי','יוני','יולי','אוגוס','ספטמבר','אוקטובר','נובמבר','דצמבר']",
	nl => "['Januari', 'Februari', 'Maart', 'April', 'Mei', 'Juni', 'Juli', 'Augustus', 'September', 'Oktober', 'November', 'December']",
},

weekdays => {
	fr => "['Dimanche', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi']",
	en => "['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']",
	es => "['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado']",
	pt => "['domingo', 'segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado']",
	ro => "['Duminică', 'Luni', 'Marți', 'Miercuri', 'Joi', 'Vineri', 'Sâmbătă']",
	de => "['Sonntag', 'Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag']",
	cs => "['Neděle','Pondělí','Úterý','Středa','Čtvrtek','Pátek','Sobota']",
	zh => "['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六']",
	ja => "['日曜日', '月曜日', '火曜日', '水曜日', '木曜日', '金曜日', '土曜日']",
	he => "['ראשון','שני','שלישי','רביעי','חמישי','שישי','שבת']",
	nl => "['Zondag', Maandag', 'Dinsdag', 'Woensdag', 'Donderdag', 'Vrijdag', 'Zaterdag']",
},

# traffic lights for fat, sugars, salt etc.
nutrient_in_quantity => {
	en => '%s in %s',
	fr => '%s en %s',
	es => '%s en %s',
	pt => '%s em %s',
	ro => '%s în %s',
	he => '%s ב־%s',
	nl => '%s in %s',
	de => '%s in %s',
},
low => {
	en => "low",
	fr => "faible",
	es => "bajo",
	pt => "baixo",
	ro => 'mic',
	he => "נמוכה",
	nl => "laag",
	de => "gering",
},
low_quantity => {
	en => "low quantity",
	fr => "faible quantité",
	es => "cantidad baja",
	pt => "quantidade baixa",
	ro => 'cantitate mică',
	he => "כמות נמוכה",
	nl => "kleine hoeveelheid",
	de => "geringe Menge",
},
moderate => {
	en => "moderate",
	fr => "modéré",
	es => "moderado",
	pt => "moderado",
	ro => 'moderat',
	he => "בינונית",
	nl => "gemiddeld",
	de => "durchschnittlich",
},
moderate_quantity => {
	en => "moderate quantity",
	fr => "quantité modérée",
	es => "cantidad moderada",
	pt => "quantidade moderada",
	ro => "cantitate moderată",
	he => "כמות בינונית",
	nl => "gemiddelde hoeveelheid",
	de => "Durchschnittliche Menge",
},
high => {
	en => "high",
	fr => "élevé",
	es => "elevado",
	pt => "elevado",
	ro => "mare",
	he => "גדולה",
	nl => "hoog",
	de => "hoch",
},
high_quantity => {
	en => "high quantity",
	fr => "quantité élevée",
	es => "cantidad elevada",
	pt => "quantidade elevada",
	ro => "cantitate mare",
	he => "כמות גדולה",
	nl => "grote hoeveelheid",
	de => "große Menge",
},

risk_level => {
	en => 'Risk',
	fr => 'Risques',
	es => 'Riesgos',
	pt => 'Riscos',
	ro => 'Risc',
	he => 'סיכון',
	nl => "Risico's",
	de => "Risiko",
},

risk_level_3 => {
	en => 'High risks',
	fr => 'Risques élevés',
	es => 'Riesgos elevados',
	pt => 'Riscos elevados',
	ro => 'Risc mare',
	he => 'סיכונים גבוהים',
	nl => "Hoge risico's",
	de => "Hohes Risiko",
},

risk_level_2  => {
	en => 'Moderate risks',
	fr => 'Risques modérés',
	es => 'Riesgos moderados',
	pt => 'Riscos moderados',
	ro => 'Risc moderat',
	he => 'סיכונים בינוניים',
	nl => "Gemiddelde risico's",
	de => "Mittleres Risiko",
},

risk_level_1  => {
	en => 'Low risks',
	fr => 'Risques faibles',
	es => 'Riesgos bajos',
	pt => 'Riscos baixos',
	ro => 'Risc scăzut',
	he => 'סיכונים נמוכים',
	nl => "Lage risico's",
	de => "Niedriges Risiko",
},

risk_level_0  => {
	en => 'To be completed',
	fr => 'A renseigner',
	es => 'Para completar',
	pt => 'Para completar',
	ro => 'De completat',
	he => 'להשלמה',
	nl => "Te vervolledigen",
	de => "Auszufüllen",
},

select_country => {
	en => 'Country',
	es => 'País',
	fr => 'Pays',
	pt => 'País',
	ro => 'Țara',
	he => 'מדינה',
	nl => "Land",
	de => "Land",
},

view_products_from_the_entire_world => {
	en => "View matching products from the entire world",
	fr => "Voir les produits correspondants du monde entier",
	es => "Ver los productos de todo el mundo",
	pt => "Ver produtos de todo o mundo",
	ro => 'Vedeți produsele corespunzătoare din toată lumea',
	he => "צפייה במוצרים תואמים מכל העולם",
	nl => "Overeenkomstige producten uit de hele wereld bekijken",
	de => "Entsprechende Produkte in der ganzen Welt anschauen",
},

view_list_for_products_from_the_entire_world => {
	en => "View the list for matching products from the entire world",
	es => "Ver la lista de los productos especificados de todo el mundo",
	fr => "Voir la liste pour les produits correspondants du monde entier",
	pt => "Ver lista de produtos correspondentes do mundo inteiro",
	ro => "Vedeți lista produselor corespunzătoare din toată lumea",
	he => "צפייה ברשימה של מוצרים תואמים מכל העולם",
	nl => "De lijst met overeenkomstige producten uit de hele wereld bekijken",
	de => "Liste von entsprechenden Produkten in der ganzen Welt anschauen",
},

view_results_from_the_entire_world => {
	en => "View results from the entire world",
	fr => "Voir les résultats du monde entier",
	es => "Ver los resultados de todo el mundo",
	pt => "Ver resultados de todo o mundo",
	ro => "Vedeți rezultatele din toată lumea",
	he => "צפייה בתוצאות מכל העולם",    
	nl => "De resultaten van de hele wereld bekijken",
	de => "Weltweite Ergebnisse anschauen",
},

explore_products_by => {
	fr => "Explorer les produits par :",
	en => "Drilldown into products by:",
	es => "Explorar los productos por:",
	pt => "Explorar os produtos por:",
	ro => "Explorați produsele după:",
	nl => "Doorzoek de producten volgens:",
	de => "Produkte nach Kriterium anzeigen:",
},

show_category_stats => {
	en => "Show detailed stats",
	es => "Mostrar las informaciones estadísticas",
	fr => "Afficher les informations statistiques",
	pt => "Mostrar estatísticas detalhadas",
	ro => "Arată statistici detaliate",
	nl => "De gedetailleerde statistieken weergeven",
	de => "Detaillierte Statistiken anzeigen",
},

show_category_stats_details => {
	en => "standard deviation, minimum, maximum, 10th and 90th percentiles",
	es => "desviación estándar, mínimo, máximo, percentiles 10 y 90",
	pt => "desvio padrão, mínimo, máximo, 10<sup>o</sup> percentil e 90<sup>o</sup>",
	ro => "deviația standard, minimum, maximum, al 10-lea și al 90-lea procent",
	fr => "écart type, minimum, maximum, 10ème et 90ème centiles",
	nl => "standaardafwijking, minimum, maximum, 10e en 90e percentiel",
},

names => {
	en => "Names",
	fr => "Noms",
	es => "Nombres",
	de => "Namen",
	pt => "Nomes",
	ro => "Nume",
	nl => "Namen",
},

css => {
	fr => <<CSS
CSS
,
	es => <<CSS
CSS
,
	nl => <<CSS
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
	pt => <<HEADER
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
<meta property="og:site_name" content="Open Food Facts - de gratis databank voor voedingsmiddelen"/>

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
<li><a href="/mode-d-emploi" title="Hoe producten toevoegen in twee minuten">Mode d'emploi</a></li>
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

column => {

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
	de => <<HTML
<a href="http://fr.openfoodfacts.org/mentions-legales">Mentions légales</a> - 
<a href="http://fr.openfoodfacts.org/conditions-d-utilisation">Nutzungsbedingungen</a> -
<a href="http://fr.openfoodfacts.org/qui-sommes-nous">Wer sind wir?</a> -
<a href="http://fr.openfoodfacts.org/questions-frequentes">Häufig gestellte Fragen</a> -
<a href="https://openfoodfactsfr.uservoice.com/">Ideenforen</a> -
<a href="http://fr.blog.openfoodfacts.org">Blog</a> -
<a href="http://fr.openfoodfacts.org/presse-et-blogs">Presse, Blogs und Präsentationen</a>
HTML
,
},



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
},

app_you_can_add_pictures => {
	fr => "Vous pouvez ajouter des photos :",
	en => "You can add pictures:",
	es => "Puedes agregar imágenes:",
	pt => "Pode adicionar imagens:",
	ro => "Puteți adăuga imagini:",
	ar => "يمكنك إضافة صور",
	de => "Sie können Bilder hinzufügen:",
	it => 'Puoi aggiungere una foto:',
	he => "ניתן להוסיף תמונות:",
},
	

app_take_a_picture => {
	fr => "Prendre une photo",
	en => "Take a picture",
	es => "Saca una foto",
	pt => "Tire uma foto",
	ro => "Faceți o fotografie",
	ar => "التقاط صورة",
	de => "Machen Sie ein Foto",
	it => "Scattare una foto",  
	he => "צילום תמונה",
},

app_take_a_picture_note => {
	fr => "Note : les photos que vous envoyez sont publiées sous la licence libre Creative Commons Attribution et Partage à l'identique.",
	en => "Note: the pictures you send are published under the free licence Creative Commons Attribution and ShareAlike.",
	es => "Nota: las imagenes que envías son publicadas bajo la licencia libre Creative Commons Attribution y ShareAlike.",
	pt => "Nota: as fotos que envia são publicadas sob a licença livre Creative Commons Attribution e ShareAlike.",
	ro => "Notă: fotografiile trimise sunt publicate sub o licență liberă Creative Commons Attribution and ShareAlike.",
	ar => "ملاحظة: يتم نشر الصور التي ترسلها تحت رخصة حرة سمات الإبداعية العموم والمشاركة على قدم المساواة.",
	de => "Anmerkung: Die Bilder, die Sie gesendet haben, werden mit der gebührenfreien Lizenz Creative Commons Attribution and ShareAlike veröffentlicht.",
	it => "Nota: le foto che inviate sono pubblicate sotto libera licenza Creative Commons Attribution e ShareAlike.",
	he => "לתשומת לבך: התמונות שנשלחות מפורסמות תחת תנאי הרישיון Creative Commons Attribution and ShareAlike.", 
},

unknown => {
	fr => "Inconnu",
	en => "Unknown",
	es => "Desconocido",
	pt => "Desconhecido",
	ro => "Necunoscut",
	he => "לא ידוע",
	de => "Unbekannt",
},

points_ranking_users_and_countries => {
	en => "Ranking of contributors and countries",
	fr => "Classement des contributeurs et des pays",
},

points_ranking => {
	en => "Ranking",
	fr => "Classement",
},

openfoodhunt_points => {
	en => "It's <a href=\"/open-food-hunt-2015\">Open Food Hunt</a> on Open Food Facts from Saturday February 21st 2015 to Sunday March 1st 2015! Contributors are awarded
Explorer points for products they add and Ambassador points for new contributors they recruit. Points are updated every 30 minutes.",
	fr => "C'est l'<a href=\"/open-food-hunt-2015\">Open Food Hunt</a> sur Open Food Facts du samedi 21 février 2015 au dimanche 1er mars 2015 ! Les contributeurs reçoivent
des points Explorateurs pour les produits qu'ils ajoutent, et des points Ambassadeurs pour les nouveaux contributeurs qu'ils recrutent. Les points sont mis à jour toutes
les 30 minutes.",	
},

points_user => {
	en => "%s is an Explorer for %d countries and an Ambassador for %d countries.",
	fr => "%s est un Explorateur de %d pays et un Ambassadeur de %d countries.",
},

points_all_users => {
	en => "There are Explorers for %d countries and Ambassadors for %d countries.",
	fr => "Il y a des Explorateurs de %d pays et des Ambassadeurs de %d countries.",
},

points_country => {
	en => "%s has %d Explorers and %d Ambassadors.",
	fr => "%s a %d Explorateurs et %d Ambassadeurs.",
},

points_all_countries => {
	en => "There are %d Explorers and %d Ambassadors.",
	fr => "Il y a %d Explorateurs et %d Ambassadeurs.",
},


);


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
			print "tag_type_from_plural{$l}{$tag_type_plural{$type}{$l}} = $type;\n";
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
	$CanonicalLang{$l} = {};	 # To map 'a-completer' to 'A compléter'
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