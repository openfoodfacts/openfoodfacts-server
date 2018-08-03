# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2018 Association Open Food Facts
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

package ProductOpener::Config;

use utf8;
use Modern::Perl '2012';
use Exporter    qw< import >;

BEGIN
{
	use vars       qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@EXPORT = qw();
	@EXPORT_OK = qw(
		%admins
		
		$server_domain
		@ssl_subdomains
		$data_root
		$www_root
		$reference_timezone
		$contact_email
		$admin_email
		
		$facebook_app_id
		$facebook_app_secret
		
		$csrf_secret
		
		$google_cloud_vision_api_key
		
		$crowdin_project_identifier
		$crowdin_project_key
		
		$mongodb
		$mongodb_host
	
		$google_analytics
		
		$thumb_size
		$crop_size
		$small_size
		$display_size
		$zoom_size
		
		$page_size
		
		%options
		
		%wiki_texts

		@product_fields
		@display_fields
		@drilldown_fields
		@taxonomy_fields
		
		%tesseract_ocr_available_languages
		
		%weblink_templates
		
		@edit_rules
		
	);
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}
use vars @EXPORT_OK ; # no 'my' keyword for these

use ProductOpener::Config2;

%admins = map { $_ => 1 } qw(
agamitsudo
bcatelin
beniben
bojackhorseman
hangy
javichu
kyzh
lucaa
scanparty-franprix-05-2016
sebleouf
segundo
stephane
tacinte
tacite
teolemon
twoflower
scanparty-franprix-05-2016
);

$options{users_who_can_upload_small_images} = {
map { $_ => 1 } qw(
systeme-u
)
};

@edit_rules = (

{
	name => "Edit Rules Testing",
	conditions => [
		["user_id", "editrulestest"],
	],
	actions => [
		["ignore_if_existing_ingredients_text_fr"],
		["warn_if_0_nutriment_fruits-vegetables-nuts"],
		["warn_if_greater_nutriment_fruits-vegetables-nuts", 0],
		["ignore_if_regexp_match_packaging", '\b(artikel|produit|producto|produkt|produkte)\b'],
	],
	notifications => [ qw (
		slack_channel_edit-alert
	)],
},

{
	name => "Yuka",
	conditions => [
		["user_id", "kiliweb"],
	],
	actions => [
		["warn_if_existing_brands"],
		["ignore_if_existing_ingredients_text"],
		["ignore_if_existing_ingredients_text_fr"],
		["ignore_if_0_nutriment_fruits-vegetables-nuts"],
		["ignore_if_greater_nutriment_fruits-vegetables-nuts", 0],
	],
	notifications => [ qw (
		slack_channel_edit-alert
	)],
},
{
        name => "Yuka - systeme-u",
        conditions => [
                ["user_id", "kiliweb"],
                ["in_editors_tags", "systeme-u"],
        ],
        actions => [
                ["ignore"],
        ],
        notifications => [ qw (
                slack_channel_edit-alert
        )],
},
{
        name => "stephane - systeme-u",
        conditions => [
                ["user_id", "stephane2"],
                ["in_editors_tags", "systeme-u"],
        ],
        actions => [
                ["ignore"],
        ],
        notifications => [ qw (
                slack_channel_edit-alert
        )],
},



{
	name => "Date Limite",
	conditions => [
		["user_id", "date-limite-app"],
	],
	actions => [
		["ignore_if_regexp_match_packaging", '\b(artikel|produit|producto|produkt|produkte)\b'],
	],
	notifications => [ qw (
		slack_channel_edit-alert
	)],
},

{
	name => "Fleury Michon",
	conditions => [
		["user_id_not", "fleury-michon"],
		["in_brands_tags", "fleury-michon"],
	],
	actions => [
		["warn"]
	],
	notifications => [ qw (
		slack_channel_edit-alert
	)],
},

);


# server constants
$server_domain = $ProductOpener::Config2::server_domain;
@ssl_subdomains = @ProductOpener::Config2::ssl_subdomains;
$mongodb = $ProductOpener::Config2::mongodb;
$mongodb_host = $ProductOpener::Config2::mongodb_host;

# server paths
$www_root = $ProductOpener::Config2::www_root;
$data_root = $ProductOpener::Config2::data_root;

$facebook_app_id = $ProductOpener::Config2::facebook_app_id;
$facebook_app_secret = $ProductOpener::Config2::facebook_app_secret;

$csrf_secret = $ProductOpener::Config2::csrf_secret;
$google_cloud_vision_api_key = $ProductOpener::Config2::google_cloud_vision_api_key;

$crowdin_project_identifier = $ProductOpener::Config2::crowdin_project_identifier;
$crowdin_project_key = $ProductOpener::Config2::crowdin_project_key;

$reference_timezone = 'Europe/Paris';

$contact_email = 'contact@openfoodfacts.org';
$admin_email = 'stephane@openfoodfacts.org';


$thumb_size = 100;
$crop_size = 400;
$small_size = 200;
$display_size = 400;
$zoom_size = 800;

$page_size = 20;


$google_analytics = <<HTML
<script type="text/javascript">

  var _gaq = _gaq || [];
  _gaq.push(['_setAccount', 'UA-31851927-1']);
  _gaq.push(['_setDomainName', 'openfoodfacts.org']);
  _gaq.push(['_trackPageview']);

  (function() {
    var ga = document.createElement('script'); ga.type = 'text/javascript'; ga.async = true;
    ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';
    var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(ga, s);
  })();

</script>
HTML
;

my @icons = (
	{ "platform" => "ios", "sizes" => "57x57", "src" => "https://static.$server_domain/images/favicon/apple-touch-icon-57x57.png" },
	{ "platform" => "ios", "sizes" => "60x60", "src" => "https://static.$server_domain/images/favicon/apple-touch-icon-60x60.png" },
	{ "platform" => "ios", "sizes" => "72x72", "src" => "https://static.$server_domain/images/favicon/apple-touch-icon-72x72.png" },
	{ "platform" => "ios", "sizes" => "76x76", "src" => "https://static.$server_domain/images/favicon/apple-touch-icon-76x76.png" },
	{ "platform" => "ios", "sizes" => "114x114", "src" => "https://static.$server_domain/images/favicon/apple-touch-icon-114x114.png" },
	{ "platform" => "ios", "sizes" => "120x120", "src" => "https://static.$server_domain/images/favicon/apple-touch-icon-120x120.png" },
	{ "platform" => "ios", "sizes" => "144x144", "src" => "https://static.$server_domain/images/favicon/apple-touch-icon-144x144.png" },
	{ "platform" => "ios", "sizes" => "152x152", "src" => "https://static.$server_domain/images/favicon/apple-touch-icon-152x152.png" },
	{ "platform" => "ios", "sizes" => "180x180", "src" => "https://static.$server_domain/images/favicon/apple-touch-icon-180x180.png" },
	{ "type" => "image/png", "src" => "https://static.$server_domain/images/favicon/favicon-32x32.png", "sizes" => "32x32" },
	{ "type" => "image/png", "src" => "https://static.$server_domain/images/favicon/android-chrome-192x192.png", "sizes" => "192x192" },
	{ "type" => "image/png", "src" => "https://static.$server_domain/images/favicon/favicon-96x96.png", "sizes" => "96x96" },
	{ "type" => "image/png", "src" => "https://static.$server_domain/images/favicon/favicon-16x16.png", "sizes" => "16x16" },
);

my @related_applications = (
	{ 'platform' => 'play', 'id' => 'org.openfoodfacts.scanner', 'url' => 'https://play.google.com/store/apps/details?id=org.openfoodfacts.scanner' },
	{ 'platform' => 'ios', 'id' => 'id588797948', 'url' => 'https://itunes.apple.com/app/id588797948' },
);

my $manifest;
$manifest->{icons} = \@icons;
$manifest->{related_applications} = \@related_applications;
$manifest->{theme_color} = '#ffffff';
$manifest->{background_color} = '#ffffff';
$options{manifest} = $manifest;

$options{mongodb_supports_sample} = 0;  # from MongoDB 3.2 onward
$options{display_random_sample_of_products_after_edits} = 0;  # from MongoDB 3.2 onward

$options{favicons} = <<HTML
<link rel="manifest" href="/cgi/manifest.pl">
<link rel="mask-icon" href="/images/favicon/safari-pinned-tab.svg" color="#5bbad5">
<link rel="shortcut icon" href="/images/favicon/favicon.ico">
<meta name="msapplication-TileColor" content="#da532c">
<meta name="msapplication-TileImage" content="/images/favicon/mstile-144x144.png">
<meta name="msapplication-config" content="/images/favicon/browserconfig.xml">
<meta name="_globalsign-domain-verification" content="2ku73dDL0bAPTj_s1aylm6vxvrBZFK59SfbH_RdUya" />
<meta name=“flattr:id” content=“dw637l”> 
HTML
;

$options{opensearch_image} = <<XML
<Image width="16" height="16" type="image/x-icon">https://static.$server_domain/images/favicon/favicon.ico</Image>
XML
;

$options{categories_exempted_from_nutriscore} = [qw(
en:baby-foods
en:baby-milks
en:alcoholic-beverages
en:waters
en:coffees
en:teas
fr:levure
fr:levures
en:honeys
en:vinegars
)];

$options{categories_exempted_from_nutrient_levels} = [qw(
en:baby-foods
en:baby-milks
en:alcoholic-beverages
en:coffees
en:teas
fr:levure
fr:levures
)];


$options{nova_groups_tags} = {

# start by assigning group 1

# 1st try to identify group 2 processed culinary ingredients

"categories/en:fats" => 2,
"categories/en:salts" => 2,
"categories/en:vinegars" => 2,
"categories/en:sugars" => 2,
"categories/en:honeys" => 2,
"categories/en:maple-syrups" => 2,

# group 3 tags will not be applied to food identified as group 2

# group 3 ingredients from nova paper

"ingredients/en:preservative" => 3,

"ingredients/en:salt" => 3,
"ingredients/en:sugar" => 3,
"ingredients/en:vegetal-oil" => 3,
"ingredients/en:butter" => 3,
"ingredients/en:honey" => 3,
"ingredients/en:maple-syrup" => 3,

# other ingredients that we can consider to be at least group 3

"ingredients/en:starch" => 3,
"ingredients/en:whey" => 4,



# group 3 categories from nova paper

"categories/en:wines" => 3,
"categories/en:beers" => 3,
"categories/en:ciders" => 3,
"categories/en:cheeses" => 3,

# other categories that we can consider to be at least group 3

"categories/en:prepared-meats" => 3,


# group 3 additives

"additives/en:e249" => 3, # potassium nitrite
"additives/en:e250" => 3, # sodium nitrite
"additives/en:e251" => 3, # potassium nitrate
"additives/en:e252" => 3, # sodium nitrite

# tags only found in group 4

"ingredients/en:colour" => 4,
"ingredients/en:colour-stabilizer" => 4,
"ingredients/en:flavour-enhancer" => 4,
"ingredients/en:sweetener" => 4,
"ingredients/en:carbonating-agent" => 4,
"ingredients/en:firming-agent" => 4,
"ingredients/en:bulking-agent" => 4,
"ingredients/en:anti-bulking-agent" => 4,
"ingredients/en:de-foaming-agent" => 4,
"ingredients/en:anti-caking-agent" => 4,
"ingredients/en:glazing-agent" => 4,
"ingredients/en:emulsifier" => 4,
"ingredients/en:sequestrant" => 4,
"ingredients/en:humectant" => 4,

# group 4 ingredients from nova paper

"ingredients/en:flavour" => 4,
"ingredients/en:casein" => 4,
"ingredients/en:lactose" => 4,
"ingredients/en:whey" => 4,
"ingredients/en:hydrogenated-oil" => 4,
"ingredients/en:hydrolysed-proteins" => 4,
"ingredients/en:maltodextrin" => 4,
"ingredients/en:invert-sugar" => 4,
"ingredients/en:high-fructose-corn-syrup" => 4,
"ingredients/en:glucose" => 4,

# other ingredients that we can consider as ultra-processed

"ingredients/en:dextrose" => 4,
"ingredients/en:milk-powder" => 4,
"ingredients/en:milk-proteins" => 4,
"ingredients/en:whey-proteins" => 4,


# group 4 categories from nova paper

"categories/en:sodas" => 4,
"categories/en:ice-creams" => 4,
"categories/en:chocolates" => 4,
"categories/en:candies" => 4,
"categories/en:sugary-snacks" => 4,
"categories/en:salty-snacks" => 4,
"categories/en:baby-milks" => 4,
"categories/en:sausages" => 4,
"categories/en:hard-liquors" => 4,

# additives that we can consider as ultra-processed (or a sufficient marker of ultra-processed food)

# all colors (should already be detected by the "color" class if it is specified in the ingredient list (e.g. "color: some additive")

"additives/en:e100", #Curcumin", #Turmeric extract", #curcuma extract
"additives/en:e106", #flavin mononucleotide", #phosphate lactoflavina
"additives/en:e101", #Riboflavin", #Vitamin B2", #Flavaxin", #Vitamin B 2", #Vitamin G", #Riboflavine", #Lactoflavine", #6\,7-Dimethyl-9-D-ribitylisoalloxazine", #7\,8-Dimethyl-10-ribitylisoalloxazine", #Lactoflavin", #7\,8-Dimethyl-10-(D-ribo-2\,3\,4\,5-tetrahydroxypentyl)isoalloxazine", #7\,8-Dimethyl-10-(D-ribo-2\,3\,4\,5-tetrahydroxypentyl)benzo[g]pteridine-2\,4(3H\,10H)-dione", #1-Deoxy-1-(7\,8-dimethyl-2\,4-dioxo-3\,4-dihydrobenzo[g]pteridin-10(2H)-yl)pentitol
"additives/en:e101a", #Riboflavin-5'-Phosphate
"additives/en:e102", #Tartrazine", #Yellow 5", #Yellow number 5", #Yellow no 5", #Yellow no5", #FD&C Yellow 5", #FD&C Yellow no 5", #FD&C Yellow no5", #FD and C Yellow no. 5", #FD and C Yellow 5
"additives/en:e103", #Alkannin
"additives/en:e104", #Quinoline yellow", #Quinoline Yellow WS", #C.I. 47005", #Food Yellow 13
"additives/en:e105", #E105 food additive
"additives/en:e107", #Yellow 2G
"additives/en:e110", #Sunset yellow FCF", #CI Food Yellow 3", #Orange Yellow S", #FD&C Yellow 6", #FD & C Yellow No.6", #FD and C Yellow No. 6", #Yellow No.6", #Yellow 6", #FD and C Yellow 6", #C.I. 15985
"additives/en:e111", #Orange GGN", #Alpha-naphthol", #Alpha-naphtol", #alpha-naphthol orange
"additives/en:e120", #Cochineal", #carminic acid", #carmines", #Natural Red 4", #Cochineal Red
"additives/en:e121", #Citrus Red 2
"additives/en:e122", #Azorubine", #carmoisine", #Food Red 3", #Brillantcarmoisin O", #Acid Red 14", #Azorubin S", #C.I. 14720
"additives/en:e123", #Amaranth", #FD&C Red 2
"additives/en:e124", #Ponceau 4r", #cochineal red a", #CI Food Red 7", #Brilliant Scarlet 4R
"additives/en:e125", #Scarlet GN", #C.I. Food Red 1", #Ponceau SX", #FD&C Red No. 4", #C.I. 14700
"additives/en:e126", #Ponceau 6R
"additives/en:e127", #Erythrosine", #FD&C Red 3", #FD & C Red No.3", #Red No. 3", #FD&C Red no3", #FD and C Red 3
"additives/en:e128", #Red 2G
"additives/en:e129", #Allura red ac", #Allura Red AC", #FD&C Red 40", #FD and C Red 40", #Red 40", #Red no40", #Red no. 40", #FD and C Red no. 40", #Food Red 17", #C.I. 16035
"additives/en:e130", #Indanthrene blue RS", #Indanthrone blue", #indanthrene
"additives/en:e131", #Patent blue v", #Food Blue 5", #Sulphan Blue", #Acid Blue 3", #L-Blau 3", #C-Blau 20", #Patentblau V", #Sky Blue", #C.I. 42051
"additives/en:e132", #Indigotine", #indigo carmine", #FD&C Blue 2", #FD and C Blue 2
"additives/en:e133", #Brilliant blue FCF", #FD&C Blue 1", #FD and C Blue 1", #Blue 1", #fd&c blue no. 1.
"additives/en:e140", #Chlorophylls and Chlorophyllins", #Chlorophyll c1
"additives/en:e141", #Copper complexes of chlorophylls and chlorophyllins", #Copper complexes of chlorophyll and chlorophyllins
"additives/en:e142", #Green s", #CI Food Green 4
"additives/en:e143", #Fast Green FCF", #Food green 3", #C.I. 42053", #Solid Green FCF", #Green 1724", #FD&C Green No. 3
"additives/en:e150", #Caramel
"additives/en:e150a", #Plain caramel", #caramel color", #caramel coloring
"additives/en:e150b", #Caustic sulphite caramel
"additives/en:e150c", #Ammonia caramel
"additives/en:e150d", #Sulphite ammonia caramel", #Sulfite ammonia caramel
"additives/en:e151", #Brilliant black bn", #black pn", #E 151", #C.I. 28440", #Brilliant Black PN", #Food Black 1", #Naphthol Black", #C.I. Food Brown 1", #Brilliant Black A
"additives/en:e152", #Black 7984", #Food Black 2", #carbon black
"additives/en:e153", #Vegetable carbon
"additives/en:e154", #Brown FK", #Kipper Brown 
"additives/en:e155", #Brown ht", #Chocolate brown HT
"additives/en:e15x", #E15x food additive
"additives/en:e160", #carotene
"additives/en:e160a", #Alpha-carotene", #Beta-carotene", #Gamma-carotene", #carotene
"additives/en:e160b", #Annatto", #bixin", #norbixin", #roucou", #achiote
"additives/en:e160c", #Paprika extract", #capsanthin", #capsorubin", #Paprika oleoresin
"additives/en:e160d", #Lycopene
"additives/en:e160e", #Beta-apo-8′-carotenal (c30)", #Apocarotenal", #Beta-apo-8'-carotenal", #C.I. Food orange 6", #E number 160E", #Trans-beta-apo-8'-carotenal", #C30H40O
"additives/en:e160f", #Ethyl ester of beta-apo-8'-carotenic acid (C 30)", #Ethyl ester of beta-apo-8'-carotenic acid ", #Food orange 7
"additives/en:e161", #Xanthophylls
"additives/en:e161a", #Flavoxanthin
"additives/en:e161b", #Lutein", #Mixed Carotenoids", #Xanthophyll", #SID548587
"additives/en:e161c", #Cryptoaxanthin", #Cryptoxanthin
"additives/en:e161d", #Rubixanthin
"additives/en:e161e", #Violaxanthin
"additives/en:e161f", #Rhodoxanthin
"additives/en:e161g", #Canthaxanthin
"additives/en:e161h", #Zeaxanthin
"additives/en:e161i", #Citranaxanthin
"additives/en:e161j", #Astaxanthin
"additives/en:e162", #Beetroot red", #betanin
"additives/en:e163", #Anthocyanins", #Anthocyanin
"additives/en:e163a", #Cyanidin
"additives/en:e163b", #Delphinidin
"additives/en:e163c", #Malvidin
"additives/en:e163d", #Pelargonidin
"additives/en:e163e", #Peonidin
"additives/en:e163f", #Petunidin
"additives/en:e164", #E164 food additive
"additives/en:e165", #E165 food additive
"additives/en:e166", #E166 food additive
"additives/en:e170", #Calcium carbonate", #CI Pigment White 18", #Chalk
"additives/en:e171", #Titanium dioxide
"additives/en:e172", #Iron oxides and iron hydroxides
"additives/en:e173", #Aluminium", #Aluminum", #element 13
"additives/en:e174", #Silver", #element 47
"additives/en:e175", #Gold", #Pigment Metal 3", #element 79
"additives/en:e180", #Litholrubine bk", #CI Pigment Red 57", #Rubinpigment", #Pigment Rubine", #Lithol rubine bk
"additives/en:e181", #Tannin
"additives/en:e182", #Orcein

# flavour enhancers

"additives/en:e421" => 4, #Mannitol
"additives/en:e620" => 4, #Glutamic acid, L(+)-
"additives/en:e621" => 4, #Monosodium L-glutamate
"additives/en:e622" => 4, #Monopotassium L-glutamate
"additives/en:e623" => 4, #Calcium di-L-glutamate
"additives/en:e624" => 4, #Monoammonium L-glutamate
"additives/en:e625" => 4, #Magnesium di-L-glutamate
"additives/en:e626" => 4, #Guanylic acid, 5'-
"additives/en:e627" => 4, #Disodium 5'-guanylate
"additives/en:e628" => 4, #Dipotassium 5'-guanylate
"additives/en:e629" => 4, #Calcium 5'-guanylate
"additives/en:e630" => 4, #Inosinic acid, 5'-
"additives/en:e631" => 4, #Disodium 5'-inosinate
"additives/en:e632" => 4, #Potassium 5’-inosinate
"additives/en:e633" => 4, #Calcium 5'-inosinate
"additives/en:e634" => 4, #Calcium 5'-ribonucleotides
"additives/en:e635" => 4, #Disodium 5'-ribonucleotides
"additives/en:e636" => 4, #Maltol
"additives/en:e637" => 4, #Ethyl maltol

# sweeteners

"additives/en:e420" => 4, #Sorbitol

"additives/en:e950" => 4, #Acesulfame potassium
"additives/en:e951" => 4, #Aspartame
"additives/en:e952" => 4, #Calcium cyclamate
"additives/en:e953" => 4, #Isomalt (Hydrogenated isomaltulose)
"additives/en:e954" => 4, #Calcium saccharin
"additives/en:e955" => 4, #Sucralose (Trichlorogalactosucrose)
"additives/en:e956" => 4, #Alitame
"additives/en:e957" => 4, #Thaumatin
"additives/en:e960" => 4, #Steviol glycosides
"additives/en:e961" => 4, #Neotame
"additives/en:e962" => 4, #Aspartame-acesulfame salt
"additives/en:e964" => 4, #Polyglycitol syrup
"additives/en:e965" => 4, #Maltitol
"additives/en:e966" => 4, #Lactitol
"additives/en:e967" => 4, #Xylitol
"additives/en:e968" => 4, #Erythritol
"additives/en:e969" => 4, #Advantame



"additives/en:e330" => 4,
"additives/en:e338" => 4,
"additives/en:e339" => 4,
"additives/en:e340" => 4,
"additives/en:e341" => 4,
"additives/en:e343" => 4,
"additives/en:e450" => 4,
"additives/en:e451" => 4,
"additives/en:e452" => 4,
"additives/en:e471" => 4,
"additives/en:e14xx" => 4,

};




%wiki_texts = (

"en/discover" => "https://en.wiki.openfoodfacts.org/Translations_-_Discover_page_-_English?action=raw",
"es/descubrir" => "https://en.wiki.openfoodfacts.org/Translations_-_Discover_page_-_Spanish?action=raw",
"fr/decouvrir" => "https://en.wiki.openfoodfacts.org/Translations_-_Discover_page_-_French?action=raw",
"he/discover" => "https://en.wiki.openfoodfacts.org/Translations_-_Discover_page_-_Hebrew?action=raw",
"ar/discover" => "https://en.wiki.openfoodfacts.org/Translations_-_Discover_page_-_Arabic?action=raw",
"pt/discover" => "https://en.wiki.openfoodfacts.org/Translations_-_Discover_page_-_Portuguese?action=raw",
"jp/discover" => "https://en.wiki.openfoodfacts.org/Translations_-_Discover_page_-_Japanese?action=raw",

"de/contribute" => "https://en.wiki.openfoodfacts.org/Translations_-_Contribute_page_-_German?action=raw",
"en/contribute" => "https://en.wiki.openfoodfacts.org/Translations_-_Contribute_page_-_English?action=raw",
"es/contribuir" => "https://en.wiki.openfoodfacts.org/Translations_-_Discover_page_-_Spanish?action=raw",
"fr/contribuer" => "https://en.wiki.openfoodfacts.org/Translations_-_Contribute_page_-_French?action=raw",
"nl/contribute" => "https://en.wiki.openfoodfacts.org/Translations_-_Contribute_page_-_Dutch?action=raw",

"en/press" => "https://en.wiki.openfoodfacts.org/Translations_-_Press_-_English?action=raw",
"fr/presse" => "https://en.wiki.openfoodfacts.org/Translations_-_Press_-_French?action=raw",
"el/press" => "https://en.wiki.openfoodfacts.org/Translations_-_Press_-_Greek?action=raw",

"en/code-of-conduct" => "https://en.wiki.openfoodfacts.org/Translations_-_Code_of_conduct_-_English?action=raw",
"fr/code-de-conduite" => "https://en.wiki.openfoodfacts.org/Translations_-_Code_of_conduct_-_French?action=raw",
"ja/code-of-conduct" => "https://en.wiki.openfoodfacts.org/Translations_-_Code_of_conduct_-_Japanese?action=raw",
"de/code-of-conduct" => "https://en.wiki.openfoodfacts.org/Translations_-_Code_of_conduct_-_German?action=raw",

"fr/notetondistrib" => "https://en.wiki.openfoodfacts.org/Translations_-_Vending_machines_-_French?action=raw",
"en/rateyourvendingmachine" => "https://en.wiki.openfoodfacts.org/Translations_-_Vending_machines_-_English?action=raw",

);


# fields for which we will load taxonomies

@taxonomy_fields = qw(states countries languages labels categories additives additives_classes vitamins minerals amino_acids nucleotides other_nutritional_substances allergens traces nutrient_levels misc ingredients nova_groups);


# fields in product edit form

@product_fields = qw(quantity packaging brands categories labels origins manufacturing_places emb_codes link expiration_date purchase_places stores countries  );


# fields shown on product page
# do not show purchase_places

@display_fields = qw(generic_name quantity packaging brands categories labels origins manufacturing_places emb_codes link stores countries);


# fields for drilldown facet navigation

@drilldown_fields = qw(
brands
categories
labels
packaging
origins
manufacturing_places
emb_codes
ingredients
additives
vitamins
minerals
amino_acids
nucleotides
other_nutritional_substances
allergens
traces
nova_groups
nutrition_grades
misc
languages
users
states
entry_dates
last_edit_dates
);


# for ingredients OCR, we use tesseract-ocr
# on debian, dictionaries are in /usr/share/tesseract-ocr/tessdata
# %tesseract_ocr_available_languages provides mapping between OFF 2 letter language codes
# and the available tesseract dictionaries
# Tesseract uses 3-character ISO 639-2 language codes
# all dictionaries: apt-get install tesseract-ocr-all

%tesseract_ocr_available_languages = (
	en => "eng",
	de => "deu",
	es => "spa",
	fr => "fra",
	it => "ita",
#	ja => "jpn", # not available with tesseract 2
	nl => "nld",
);

# weblink definitions for known tags, ie. wikidata:en:Q123 => https://www.wikidata.org/wiki/Q123

%weblink_templates = (

	'wikidata:en' => { href => 'https://www.wikidata.org/wiki/%s', text => 'Wikidata', parse => sub
	{
		my ($url) = @_;
		if ($url =~ /^https?:\/\/www.wikidata.org\/wiki\/(Q\d+)$/) {
			return $1
		}

		return;
	} },

);

# allow moving products to other instances of Product Opener on the same server
# e.g. OFF -> OBF
$options{other_servers} = {
obf =>
{
	name => "Open Beauty Facts",
	data_root => "/home/obf",
	www_root => "/home/obf/html",
	mongodb => "obf",
	domain => "openbeautyfacts.org",
},
off =>
{
	name => "Open Food Facts",
	data_root => "/home/off",
	www_root => "/home/off/html",
	mongodb => "off",
	domain => "openfoodfacts.org",
},
opf =>
{
	name => "Open Products Facts",
	data_root => "/home/opf",
	www_root => "/home/opf/html",
	mongodb => "opf",
	domain => "openproductsfacts.org",
},
opff =>
{
	prefix => "opff",
	name => "Open Pet Food Facts",
	data_root => "/home/opff",
	www_root => "/home/opff/html",
	mongodb => "opff",
	domain => "openpetfoodfacts.org",
}
};

1;
