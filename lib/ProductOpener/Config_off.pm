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
<meta name="flattr:id" content="dw637l"> 
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
"ingredients/en:vegetable-oil" => 3,
"ingredients/en:vegetal-oil" => 3,
"categories/en:fats" => 2,
"ingredients/en:butter" => 3,
"ingredients/en:honey" => 3,
"ingredients/en:maple-syrup" => 3,

# other ingredients that we can consider to be at least group 3

"ingredients/en:starch" => 3,
"ingredients/en:whey" => 4,
"ingredients/en:milk-powder" => 4,



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
"ingredients/en:flavouring" => 4,
"ingredients/en:casein" => 4,
"ingredients/en:lactose" => 4,
"ingredients/en:whey" => 4,
"ingredients/en:hydrogenated-oil" => 4,
"ingredients/en:hydrolysed-proteins" => 4,
"ingredients/en:maltodextrin" => 4,
"ingredients/en:invert-sugar" => 4,
"ingredients/en:high-fructose-corn-syrup" => 4,
"ingredients/en:glucose" => 4,
"ingredients/en:glucose-syrup" => 4,


# other ingredients that we can consider as ultra-processed

"ingredients/en:dextrose" => 4,
"ingredients/en:milk-powder" => 4,
"ingredients/en:milk-proteins" => 4,
"ingredients/en:whey-proteins" => 4,
"ingredients/en:lecithin" => 4,


# group 4 categories from nova paper
# some categories are mainly examples of products that are generally group 4
# -> assign them to group 3, and then ingredient detection can classify individual products in group 4

"categories/en:sodas" => 4,
"categories/en:ice-creams" => 3,
"categories/en:chocolates" => 3,
"categories/en:candies" => 4,
"categories/en:sugary-snacks" => 3,
"categories/en:salty-snacks" => 3,
"categories/en:baby-milks" => 3,
"categories/en:sausages" => 3,
"categories/en:hard-liquors" => 4,

# additives that we can consider as ultra-processed (or a sufficient marker of ultra-processed food)

# all colors (should already be detected by the "color" class if it is specified in the ingredient list (e.g. "color: some additive")

"additives/en:e100" => 4, #Curcumin" => 4, #Turmeric extract" => 4, #curcuma extract
"additives/en:e106" => 4, #flavin mononucleotide" => 4, #phosphate lactoflavina
"additives/en:e101" => 4, #Riboflavin" => 4, #Vitamin B2" => 4, #Flavaxin" => 4, #Vitamin B 2" => 4, #Vitamin G" => 4, #Riboflavine" => 4, #Lactoflavine" => 4, #6\,7-Dimethyl-9-D-ribitylisoalloxazine" => 4, #7\,8-Dimethyl-10-ribitylisoalloxazine" => 4, #Lactoflavin" => 4, #7\,8-Dimethyl-10-(D-ribo-2\,3\,4\,5-tetrahydroxypentyl)isoalloxazine" => 4, #7\,8-Dimethyl-10-(D-ribo-2\,3\,4\,5-tetrahydroxypentyl)benzo[g]pteridine-2\,4(3H\,10H)-dione" => 4, #1-Deoxy-1-(7\,8-dimethyl-2\,4-dioxo-3\,4-dihydrobenzo[g]pteridin-10(2H)-yl)pentitol
"additives/en:e101a" => 4, #Riboflavin-5'-Phosphate
"additives/en:e102" => 4, #Tartrazine" => 4, #Yellow 5" => 4, #Yellow number 5" => 4, #Yellow no 5" => 4, #Yellow no5" => 4, #FD&C Yellow 5" => 4, #FD&C Yellow no 5" => 4, #FD&C Yellow no5" => 4, #FD and C Yellow no. 5" => 4, #FD and C Yellow 5
"additives/en:e103" => 4, #Alkannin
"additives/en:e104" => 4, #Quinoline yellow" => 4, #Quinoline Yellow WS" => 4, #C.I. 47005" => 4, #Food Yellow 13
"additives/en:e105" => 4, #E105 food additive
"additives/en:e107" => 4, #Yellow 2G
"additives/en:e110" => 4, #Sunset yellow FCF" => 4, #CI Food Yellow 3" => 4, #Orange Yellow S" => 4, #FD&C Yellow 6" => 4, #FD & C Yellow No.6" => 4, #FD and C Yellow No. 6" => 4, #Yellow No.6" => 4, #Yellow 6" => 4, #FD and C Yellow 6" => 4, #C.I. 15985
"additives/en:e111" => 4, #Orange GGN" => 4, #Alpha-naphthol" => 4, #Alpha-naphtol" => 4, #alpha-naphthol orange
"additives/en:e120" => 4, #Cochineal" => 4, #carminic acid" => 4, #carmines" => 4, #Natural Red 4" => 4, #Cochineal Red
"additives/en:e121" => 4, #Citrus Red 2
"additives/en:e122" => 4, #Azorubine" => 4, #carmoisine" => 4, #Food Red 3" => 4, #Brillantcarmoisin O" => 4, #Acid Red 14" => 4, #Azorubin S" => 4, #C.I. 14720
"additives/en:e123" => 4, #Amaranth" => 4, #FD&C Red 2
"additives/en:e124" => 4, #Ponceau 4r" => 4, #cochineal red a" => 4, #CI Food Red 7" => 4, #Brilliant Scarlet 4R
"additives/en:e125" => 4, #Scarlet GN" => 4, #C.I. Food Red 1" => 4, #Ponceau SX" => 4, #FD&C Red No. 4" => 4, #C.I. 14700
"additives/en:e126" => 4, #Ponceau 6R
"additives/en:e127" => 4, #Erythrosine" => 4, #FD&C Red 3" => 4, #FD & C Red No.3" => 4, #Red No. 3" => 4, #FD&C Red no3" => 4, #FD and C Red 3
"additives/en:e128" => 4, #Red 2G
"additives/en:e129" => 4, #Allura red ac" => 4, #Allura Red AC" => 4, #FD&C Red 40" => 4, #FD and C Red 40" => 4, #Red 40" => 4, #Red no40" => 4, #Red no. 40" => 4, #FD and C Red no. 40" => 4, #Food Red 17" => 4, #C.I. 16035
"additives/en:e130" => 4, #Indanthrene blue RS" => 4, #Indanthrone blue" => 4, #indanthrene
"additives/en:e131" => 4, #Patent blue v" => 4, #Food Blue 5" => 4, #Sulphan Blue" => 4, #Acid Blue 3" => 4, #L-Blau 3" => 4, #C-Blau 20" => 4, #Patentblau V" => 4, #Sky Blue" => 4, #C.I. 42051
"additives/en:e132" => 4, #Indigotine" => 4, #indigo carmine" => 4, #FD&C Blue 2" => 4, #FD and C Blue 2
"additives/en:e133" => 4, #Brilliant blue FCF" => 4, #FD&C Blue 1" => 4, #FD and C Blue 1" => 4, #Blue 1" => 4, #fd&c blue no. 1.
"additives/en:e140" => 4, #Chlorophylls and Chlorophyllins" => 4, #Chlorophyll c1
"additives/en:e141" => 4, #Copper complexes of chlorophylls and chlorophyllins" => 4, #Copper complexes of chlorophyll and chlorophyllins
"additives/en:e142" => 4, #Green s" => 4, #CI Food Green 4
"additives/en:e143" => 4, #Fast Green FCF" => 4, #Food green 3" => 4, #C.I. 42053" => 4, #Solid Green FCF" => 4, #Green 1724" => 4, #FD&C Green No. 3
"additives/en:e150" => 4, #Caramel
"additives/en:e150a" => 4, #Plain caramel" => 4, #caramel color" => 4, #caramel coloring
"additives/en:e150b" => 4, #Caustic sulphite caramel
"additives/en:e150c" => 4, #Ammonia caramel
"additives/en:e150d" => 4, #Sulphite ammonia caramel" => 4, #Sulfite ammonia caramel
"additives/en:e151" => 4, #Brilliant black bn" => 4, #black pn" => 4, #E 151" => 4, #C.I. 28440" => 4, #Brilliant Black PN" => 4, #Food Black 1" => 4, #Naphthol Black" => 4, #C.I. Food Brown 1" => 4, #Brilliant Black A
"additives/en:e152" => 4, #Black 7984" => 4, #Food Black 2" => 4, #carbon black
"additives/en:e153" => 4, #Vegetable carbon
"additives/en:e154" => 4, #Brown FK" => 4, #Kipper Brown 
"additives/en:e155" => 4, #Brown ht" => 4, #Chocolate brown HT
"additives/en:e15x" => 4, #E15x food additive
"additives/en:e160" => 4, #carotene
"additives/en:e160a" => 4, #Alpha-carotene" => 4, #Beta-carotene" => 4, #Gamma-carotene" => 4, #carotene
"additives/en:e160b" => 4, #Annatto" => 4, #bixin" => 4, #norbixin" => 4, #roucou" => 4, #achiote
"additives/en:e160c" => 4, #Paprika extract" => 4, #capsanthin" => 4, #capsorubin" => 4, #Paprika oleoresin
"additives/en:e160d" => 4, #Lycopene
"additives/en:e160e" => 4, #Beta-apo-8′-carotenal (c30)" => 4, #Apocarotenal" => 4, #Beta-apo-8'-carotenal" => 4, #C.I. Food orange 6" => 4, #E number 160E" => 4, #Trans-beta-apo-8'-carotenal" => 4, #C30H40O
"additives/en:e160f" => 4, #Ethyl ester of beta-apo-8'-carotenic acid (C 30)" => 4, #Ethyl ester of beta-apo-8'-carotenic acid " => 4, #Food orange 7
"additives/en:e161" => 4, #Xanthophylls
"additives/en:e161a" => 4, #Flavoxanthin
"additives/en:e161b" => 4, #Lutein" => 4, #Mixed Carotenoids" => 4, #Xanthophyll" => 4, #SID548587
"additives/en:e161c" => 4, #Cryptoaxanthin" => 4, #Cryptoxanthin
"additives/en:e161d" => 4, #Rubixanthin
"additives/en:e161e" => 4, #Violaxanthin
"additives/en:e161f" => 4, #Rhodoxanthin
"additives/en:e161g" => 4, #Canthaxanthin
"additives/en:e161h" => 4, #Zeaxanthin
"additives/en:e161i" => 4, #Citranaxanthin
"additives/en:e161j" => 4, #Astaxanthin
"additives/en:e162" => 4, #Beetroot red" => 4, #betanin
"additives/en:e163" => 4, #Anthocyanins" => 4, #Anthocyanin
"additives/en:e163a" => 4, #Cyanidin
"additives/en:e163b" => 4, #Delphinidin
"additives/en:e163c" => 4, #Malvidin
"additives/en:e163d" => 4, #Pelargonidin
"additives/en:e163e" => 4, #Peonidin
"additives/en:e163f" => 4, #Petunidin
"additives/en:e164" => 4, #E164 food additive
"additives/en:e165" => 4, #E165 food additive
"additives/en:e166" => 4, #E166 food additive
"additives/en:e170" => 4, #Calcium carbonate" => 4, #CI Pigment White 18" => 4, #Chalk
"additives/en:e171" => 4, #Titanium dioxide
"additives/en:e172" => 4, #Iron oxides and iron hydroxides
"additives/en:e173" => 4, #Aluminium" => 4, #Aluminum" => 4, #element 13
"additives/en:e174" => 4, #Silver" => 4, #element 47
"additives/en:e175" => 4, #Gold" => 4, #Pigment Metal 3" => 4, #element 79
"additives/en:e180" => 4, #Litholrubine bk" => 4, #CI Pigment Red 57" => 4, #Rubinpigment" => 4, #Pigment Rubine" => 4, #Lithol rubine bk
"additives/en:e181" => 4, #Tannin
"additives/en:e182" => 4, #Orcein

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
	data_root => "/srv/obf",
	www_root => "/srv/obf/html",
	mongodb => "obf",
	domain => "openbeautyfacts.org",
},
off =>
{
	name => "Open Food Facts",
	data_root => "/srv/off",
	www_root => "/srv/off/html",
	mongodb => "off",
	domain => "openfoodfacts.org",
},
opf =>
{
	name => "Open Products Facts",
	data_root => "/srv/opf",
	www_root => "/srv/opf/html",
	mongodb => "opf",
	domain => "openproductsfacts.org",
},
opff =>
{
	prefix => "opff",
	name => "Open Pet Food Facts",
	data_root => "/srv/opff",
	www_root => "/srv/opff/html",
	mongodb => "opff",
	domain => "openpetfoodfacts.org",
}
};


$options{display_tag_additives} = [

	'@additives_classes',
	'wikipedia',
	'title:efsa_evaluation_overexposure_risk_title',
	'efsa_evaluation',
	'efsa_evaluation_overexposure_risk',	
	'efsa_evaluation_exposure_table',
#	'@efsa_evaluation_exposure_mean_greater_than_noael',
#	'@efsa_evaluation_exposure_95th_greater_than_noael',
#	'@efsa_evaluation_exposure_mean_greater_than_adi',
#	'@efsa_evaluation_exposure_95th_greater_than_adi',

];

1;
