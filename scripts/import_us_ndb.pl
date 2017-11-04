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

$lc = "en";

my %ndb_nutrients = (
caffeine => "caffeine",
"calcium, ca" => "calcium",
"carbohydrate, by difference" => "carbohydrates",
cholesterol => "cholesterol",
"copper, cu" => "copper",
"energy"  => "energy",
"fatty acids, total monounsaturated"  => "monounsaturated-fat",
"fatty acids, total polyunsaturated"  => "polyunsaturated-fat",
"fatty acids, total saturated" => "saturated-fat",
"fatty acids, total trans" => "trans-fat",
"fiber, total dietary" => "fiber",
"folate, total" => "folates",
"folic acid" => "vitamin-b9",
"iron, fe" => "iron",
"lactose" => "lactose",
"magnesium, mg" => "magnesium",
"manganese, mn" => "manganese",
niacin => "vitamin-pp",
"pantothenic acid" => "pantothenic-acid",
"phosphorus, p" => "phosphorus",
"potassium, k" => "potassium",
protein => "proteins",
riboflavin => "vitamin-b2",
"selenium, se" => "selenium",
"sodium, na" => "sodium",
"sugars, total" => "sugars",
thiamin => "vitamin-b1",
"total lipid (fat)" => "fat",
"vitamin a, iu" => "vitamin-a",
"vitamin b-12" => "vitamin-b12",
"vitamin b-6" => "vitamin-b6",
"vitamin c, total ascorbic acid" => "vitamin-c",
"vitamin d" => "vitamin-d",
"vitamin k (phylloquinone)" => "vitamin-k",
"zinc, zn" => "zinc",

);

my @ch_brands = qw(


MEIJER
KROGER
ROUNDY'S
SHOPRITE
WHOLE_FOODS_MARKET
FOOD_CLUB
FOOD_LION
365_EVERYDAY_VALUE
SPARTAN
GREAT_VALUE
MARKET_PANTRY
HANNAFORD
AHOLD
ESSENTIAL_EVERYDAY
WEIS
WEIS_QUALITY
GIANT
HARRIS_TEETER
MCCORMICK
GIANT_EAGLE
TRADER_JOE'S
GOYA
HY-VEE
WESTERN_FAMILY
WEGMANS
VALU_TIME
HORMEL
TOPS
SIGNATURE_KITCHENS
WINCO_FOODS
CLOVER_VALLEY
SCHNUCKS
NICE!
BLUE_BUNNY
ARCHER_FARMS
GALERIE
DANNON
PRIVATE_SELECTION
RUSSELL_STOVER
OCEAN_SPRAY
WELCH'S
WILTON
SIMPLY_BALANCED
TILLAMOOK
GOLD_EMBLEM
BIG_Y
SNYDER'S_OF_HANOVER
RALEY'S
FULL_CIRCLE
DOLE
LIPTON
JELL-O
WINN_DIXIE
JENNIE-O
DEL_MONTE
BUSH'S_BEST
CLIF
IGA
LINDT
BOB'S_RED_MILL
WISH-BONE
TASTYKAKE
GHIRARDELLI_CHOCOLATE
SMART_SENSE
UTZ
HAGGEN
ZATARAIN'S
LANCE
AMY'S
WILD_HARVEST
LOWES_FOODS
BRACH'S
SIGNATURE
DELALLO
DEAN'S
KIKKOMAN
SARGENTO
JOHNVINCE_FOODS
ORGANIC_VALLEY
SIMPLE_TRUTH_ORGANIC
PUBLIX
BIG_WIN
FISHER
OUR_FAMILY
MARZETTI
SO_DELICIOUS_DAIRY_FREE
SHURFINE
THE_FRESH_MARKET
KIND
DUNCAN_HINES
O_ORGANICS
KINGS
THE_BAKERY
MOMENTUM_BRANDS
LITTLE_DEBBIE
NEWMAN'S_OWN
SILK
LAURA_LYNN
ARIZONA
DAILY_CHEF
KEY_FOOD
BEECH-NUT
LITEHOUSE
VALUED_NATURALS
H-E-B
ROLAND
KEMPS
HERR'S
LUNDS_&_BYERLYS
SPRINGFIELD
FULL_CIRCLE_MARKET
SIGNATURE_SELECT
FRANKFORD
BARILLA
MICHELINA'S
LUCERNE
TARGET_CORPORATION
HORIZON_ORGANIC
BREYERS
AUNT_MILLIE'S
OLD_ORCHARD
TURKEY_HILL
BROOKSHIRE'S
HIDDEN_VALLEY
FRESH_&_EASY
WHITE_ROSE
MRS._FRESHLEY'S
BUMBLE_BEE
INTERNATIONAL_DELIGHT
DIERBERGS
HAMMOND'S
LAWRY'S
STARKIST
FAMILY_GOURMET
HT_TRADERS
HARMONS
VEGA
DARIGOLD
NATURE'S_HARVEST
STARBUCKS
REFRESHE
CENTO
PEEPS
LALA
STONEWALL_KITCHEN
OLD_DUTCH
NATURE'S_PROMISE
PACIFIC
SOUTHERN_HOME
LANGERS
LEE_KUM_KEE
KOOL-AID
BOAR'S_HEAD
HOOD
RONZONI
MY_ESSENTIALS
CAPE_COD
FIELD_DAY
SUPER_CHILL
SMART_ONES
WELLSLEY_FARMS
VICTORIA
CADIA
MARKET_BASKET
BIRDS_EYE
SUJA
BADIA
ATKINS
BACK_TO_NATURE
BAKERY_FRESH_GOODNESS
BEN_&_JERRY'S
BERTOLLI
BUTTERBALL
JELLY_BELLY
BOB_EVANS
POWERBAR
FERRIS
PRICE_CHOPPER
EVOLUTION_FRESH
REESE
SHIRAKIKU
MT._OLIVE
MARKETSIDE
FIRST_STREET
SAFEWAY_KITCHENS
WINN-DIXIE
TORN_&_GLASSER
DEL_MONTE_QUALITY
SIMPLY_ROUNDY'S
TROLLI
ENTENMANN'S
HOSTESS
EARTHBOUND_FARM
CHOBANI
KNORR
KEN'S_STEAK_HOUSE
MANISCHEWITZ
PHILADELPHIA
SIMPLE_TRUTH
GORTON'S
ALLENS
K&G
ENJOY_LIFE
PALMER
ORTEGA
DIETZ_&_WATSON
CULINARY_CIRCLE
HAPPY_BABY
SAFFRON_ROAD
ANNIE'S
MARUCHAN
HANOVER
HONEY_STINGER
TOOTSIE
SIMPLY_ASIA
CLEAR_VALUE
SHOP_RITE
CASCADIAN_FARM
CREAMETTE
SAM'S_CHOICE
CHICKEN_OF_THE_SEA
GOOD_LIVIN'
BELL-VIEW
ASIAN_GOURMET
WALDEN_FARMS
AMERICA'S_CHOICE
EDEN
GOOD_&_DELISH
BUDDIG
GONZALEZ
STONYFIELD_ORGANIC
SHASTA
NATURAL_DIRECTIONS
TGI_FRIDAYS
IDAHOAN
CRYSTAL_LIGHT
PRESIDENT
TARGET
VLASIC
HYVEE
SUPERVALU
EMERALD
FRESH_GOURMET
DSD_MERCHANDISERS
MEZZETTA
GOOD_HEALTH
DYNASTY
LUNA
TALENTI
WORLD_MARKET
ARNIE'S
LA_PREFERIDA
MUSSELMAN'S
ARMOUR
TIC_TAC
IBERIA
GRACE
JACK_LINK'S
BEST_YET
EVOL
CRACKER_BARREL
WOODSTOCK
UDI'S
SPROUT
JOHNSONVILLE
STUBB'S
OLD_WISCONSIN
JEWEL_OSCO
SUNNY_D
LUCKY_LEAF
SARA_LEE
STATER_BROS.
FAYGO
KRUSTEAZ
EL_MEXICANO
TASTE_OF_INSPIRATIONS
CORNER_STORE
PIGGLY_WIGGLY
TAYLOR_FARMS
JAYS
BORDEN
HODGSON_MILL
SOUTHERN_GROVE
TOFT'S
IMAGINE
NISSIN
GEFEN
SABRA
CASA_CARDENAS
BROWNBERRY
BEST_FOODS
ALPINA
BENTON'S
RED_BARON
FANNIE_MAY
COUNTRY_KITCHEN
SPECIALLY_SELECTED
APPLE_&_EVE
HANSEN'S
AUNT_JEMIMA
FRENCH'S
JUICY_JUICE
SUNRISE
WISE
PARADE
CENTRELLA
CHILI'S
4C
TOO_GOOD_GOURMET
WALLABY_ORGANIC
LAND_O_LAKES
SUPERIOR_NUT_&_CANDY
NATURE'S_PATH_ORGANIC
SAN_GIORGIO
MADE_IN_NATURE
7_SELECT
THAT'S_SMART!
TACOMA_BOYS
SPICE_ISLANDS
CLASSICO
ROYAL
SUN-MAID
SIGNATURE_CAFE
GOOD_HUMOR
SUN_LUCK
GO_RAW
LUNDBERG
MAPLE_GROVE_FARMS_OF_VERMONT
NAKED
HOMEMADE
NATURE'S_EATS
ZONE_PERFECT
HERDEZ
CALIFIA_FARMS
CHI-CHI'S
GLUTINO
MARKETS_OF_MEIJER
BLUE_DIAMOND_ALMONDS
ATHENOS
SODASTREAM
BLUE_DIAMOND
HARRY_&_DAVID
ALESSI
CLEAR_AMERICAN
ELLA'S_KITCHEN
ARROWHEAD_MILLS
LOFTHOUSE_COOKIES
MUSCO_FAMILY_OLIVE_CO.
MELISSA'S
POMPEIAN
SANDERS
OVER_THE_TOP
RAGU
VOORTMAN
CELESTIAL_SEASONINGS
HELLMANN'S
PRINCE
JUSTIN'S
RACCONTO
KLONDIKE
PALMER'S_CANDIES
THE_GREEK_GODS
LIFEWAY
BEST_CHOICE
CAPRISUN
NATURE'S_PATH
STAR
CABOT
THE_SNACK_ARTIST
POST
ELMER_CHOCOLATE
SNAK_CLUB
POLAR
AIRHEADS
KC_MASTERPIECE
BOSTON_MARKET
SHUR_FINE
SIMPLY_ORGANIC
HEBERT
WAL-MART_STORES
FRIGO
LAKE_CHAMPLAIN_CHOCOLATES
LOFTHOUSE
UNCLE_RAY'S
FOSTER_FARMS
NALLEY
SKIPPY
STRAUB'S
NATURE'S_NECTAR
DISNEY
POPCHIPS
SEVERINO_HOMEMADE_PASTA
MIKE_AND_IKE
SAFEWAY
OPEN_NATURE
THEO
DEAN'S_COUNTRY_FRESH
CUMBERLAND_FARMS
MATERNE
LAKEWOOD
SEA_CUISINE
WELLSHIRE
MIO
CIRCLE_K
MILLVILLE
NATURE'S_GARDEN
COLAVITA
STREIT'S
URBAN_ACCENTS
SUNNYD
STORCK
ORCHARD_VALLEY_HARVEST
NAPOLEON
FRUIT2O
CONCORD_FOODS
MIZKAN
NOOSA
HOME_RUN_INN
LA_CROIX
WEBER
BRYAN
FLAVE!
GHIRARDELLI
VINTAGE
CHARMS
HARMONS_NEIGHBORHOOD_GROCER
RICHIN
FRONTERA
VERYFINE
EARTH'S_BEST
FOOD_SHOULD_TASTE_GOOD
ZIYAD
SEVERINO
THOMAS
SNACK_FACTORY
EARTHBOUND_FARM_ORGANIC
THORNTONS
HUDSONVILLE
PSST...
SAFEWAY_SELECT
BELGIOIOSO
PRICE_RITE
CULINARIA
FAREWAY
CVS_PHARMACY
CELEBRATION_BY_SWEETWORKS
GARDEIN
FOOD_FOR_LIFE
BALLREICH'S
CLANCY'S
RADZ
MARTIN'S
KING_ARTHUR_FLOUR
SUNNY_SELECT
LARABAR
B&G
LA_FE
FLORIDA'S_NATURAL
PEDDLER'S_PANTRY
CRYSTAL_FARMS
TOM'S
S._ROSEN'S
MUELLER'S
SWEET_BABY_RAY'S
KETTLE
SIMPLY_NATURE
ROCKSTAR
VAN'S
MARCZYK_FINE_FOODS
HADDON_HOUSE
FAGE
ORGANIC_PRAIRIE
GALBANI
MRS._FIELDS
ROYAL_SNACKS
FLIX_CANDY
SAVORY_FOODS
OWENS
MEIJER_ORGANICS
PURPLE_COW
CRESCENT
PICTSWEET
THE_BAKERY_BAKED_WITH_PRIDE
RESER'S_FINE_FOODS
MRS_DASH
FARAON
TRADER_GIOTTO'S
TASTY_BITE
LA_COSTENA
GLORY_FOODS
RED_GOLD
MEIJI
PEZ
YOCRUNCH
JUMEX
KATHY_KAYE
CHA-CHING
DIAMOND
ENGINE_2
NONNI'S
FRANK'S
MIDWOOD_BRANDS
BROWNWOOD_FARMS
FOLLOW_YOUR_HEART
JIMMY_DEAN
ZEVIA
SPECTRUM
HONEY_BUNCHES_OF_OATS
FOODTOWN
7-SELECT
ZICO
MAPLE_HILL_CREAMERY
DEMET'S
OLD_DOMINION_PEANUT_COMPANY
PALERMO'S
PRO_BAR
GREENBRIER_INTERNATIONAL
STONERIDGE
BETTER_MADE
BELLA_FAMIGLIA
STAUFFER'S
FRESH_FOODS_MARKET
GOLDEN_FLAKE
JLM
SWEET_SMILES
SPEEDY_CHOICE
PATAK'S
SEGGIANO
MAXWELL_HOUSE
BETTEROATS
HARIBO
BLACK_FOREST
NANCY'S
DE_CECCO
HAMMOND'S_CANDIES
FAIRWAY
THE_ESSENTIAL_BAKING_COMPANY
KLASS
HAPPYBABY_ORGANICS
PERDUE
TOFURKY
MONSTER
DEEP
NATURE'S_PLACE
KOWALSKI'S_MARKETS
BEAR_CREEK_COUNTRY_KITCHENS
SMITH'S
ROBERT_ROTHSCHILD_FARM
TORANI
NATURAL_NECTAR
WAYMOUTH_FARMS
SIMPLY_ENJOY
TAZO
KA-ME
BLACK_BEAR
FRONTIER
MISSION
GUSTO
CASCADIAN_FARM_ORGANIC
BIONATURAE
ALWAYS_SAVE
JO'S_CANDIES
SIGGI'S
TAMPICO
JONES_DAIRY_FARM
TERRA
BLUE_SKY
SIMPLY_INDULGENT_GOURMET
EMERIL'S
DRAGONFLY
NICKELODEON
STELLA
JOVIAL
BREAKSTONE'S
WYLER'S_LIGHT
YODER'S
BALL_PARK
MADHAVA
SWEET'S
LA_VICTORIA
CANDYRIFIC
BIG_K
S&W
ROCKY_MOUNTAIN_CHOCOLATE_FACTORY
MEIJER_NATURALS
SWEET_SHOP_USA
TABASCO
CHOCOLOVE
DUTCH_FARMS
MARINELA
KAHIKI
MIKE-SELL'S
DAVINCI
FIESTA!
SCHWARTZ_BROTHERS_BAKERY
VILLAGE_HEARTH
NAVITAS_NATURALS
TETLEY
JARRITOS
HILL_COUNTRY_FARE
CHUCKANUT_BAY
DREW'S
DIERBERGS_KITCHEN
STELLA_D'ORO
GOURMET_SELECT
S&B
WHITMAN'S
DARE
HAWAIIAN_SUN
HAPPY_TOT
NICKLES
RITTER_SPORT
JOSE_OLE
COOKED_PERFECT
ISOLA
CHEK
MOM'S_BEST_CEREALS
ANNIE_CHUN'S
SARTORI
AMERICAN_BEAUTY
CAKE_MATE
COLUMBIA_GORGE_ORGANIC
GOOD_SENSE
MAMMA_CHIA
BOTTICELLI
RUDI'S_ORGANIC_BAKERY
MOONSTRUCK
SUNBELT_BAKERY
SUNNYSIDE_FARMS
AMPORT_FOODS
HOUSE_FOODS
THE_DECORATED_COOKIE_COMPANY
COLUMBUS
HOFFMAN'S
HILCO
HEINEN'S
CHAOKOH
FOODHOLD
POWER_CRUNCH
BOULDER_CANYON
FESTIVAL
OLD_BAY
WORLD_FOOD_PRODUCTS
PEARSON'S
GRAETER'S
EL_GUAPO
CHOCEUR
TRUMOO
7-ELEVEN
DIVINE
BIMBO
GUMMI_BEARS
SCHAR
CLEARLY_ORGANIC
FRESCHETTA
MARGARET_HOLMES
EILLIEN'S_CANDIES
SETTON_FARMS
IMPERIAL_NUTS
KNUDSEN
ANGIE'S
WILD_OATS
SOBE
TRAPPEY'S
SMARTFOOD
RITROVO_SELECTIONS
GOLDEN_BOY
DUBBLE_BUBBLE
REESE'S
SPARKLING_ICE
SANTA'S_TREATS
LUNCHABLES
FLORA
PRICE_FIRST
STEPHEN'S
FOCO
MAUD_BORUP
HAPPYTOT_ORGANICS
PILLSBURY
MAZOLA
SUN-BIRD
BLAKE'S
ADIRONDACK_BEVERAGES
MARKET_DISTRICT
MRS_BAIRD'S
NATURE'S_RANCHER
COLLEGE_INN
GREEN_WAY
OLDE_CAPE_COD
ROTH
BROWN_&_HALEY
APPLEGATE_NATURALS
BAI
ORGANIC_VILLE
CRISP
ON-COR
P$$T...
EL_MONTEREY
GIA_RUSSA
CROWN_PRINCE
MAGNUM
LA_BREA_BAKERY
EARTH_BALANCE
HOUSE_OF_TSANG
WONDER
SIGNATURE_FARMS
BEL_GIOIOSO
TWO-BITE
TRULY_GOOD_FOODS
MORTON
OTTOGI
LACTAID
GEISHA
FERRERO_COLLECTION
MARIE'S
THE_BETTER_CHIP
DREAMHOUSE_FINE_FOODS
SANPELLEGRINO
CARDENAS
FARMLAND
TAI_PEI
REDNER'S_WAREHOUSE_MARKETS
TAZAH
ARIZONA_SNACK_COMPANY
GIANNA'S
JFC
DANIELE
LA_TORTILLA_FACTORY
NONGSHIM
MRS._RENFRO'S
DANONE
CONTADINA
VAN_DE_KAMP'S
MALT_O_MEAL
NORTH_STAR_TRADING_COMPANY
BARE
CEDAR'S
MAMA_TERE
MANITOU_TRADING_COMPANY

Trader-joe-s
Kraft
Pepperidge-farm
General-mills
Great-value
Kellogg-s
Nestle
Nabisco
Market-pantry
Barilla
Heinz
Kroger
Safeway
Campbell-s
Lindt
Kirkland
Kirkland-signature
365
Smucker-s
Lotao
Cake-boss
Hershey-s
Nature-valley
Ferrero
Coca-cola
Unilever
Dannon
Quaker
Chobani
The-laughing-cow
Stew-leonard-s
Organics
Betty-crocker
Skippy
Tropicana
Food-lion
Oreo
Kind
Bumble-bee-foods
Oscar-mayer
Organic-valley
Wilton
Little-debbie
Big-y
Safeway-kitchens
Jif
Stonyfield
V8
M-m-s
Safeway-select
Lipton
Starbucks
Tostitos
Trader-giotto-s
Yoplait
Nutella
Doritos
Minute-maid
Arizona
Lay-s
Mountain-dew
Mccormick
National
Brookside
Nissin
Reese-s
Celestial-seasonings
Tops
Planters
Fritolay
My-essentials
Cliff-bar
Pepsi
Crystal
Ocean-spray
Beaver
Inc
French-s
Wegmans
Annie-s
Mezzetta
Whole-foods
Giant
Rice-dream
Lucerne
Nice
Naked
Welch-s
Pringles
Maesri
Bob-s-red-mill
San-pellegrino
Schnucks
Sabra
ตราแม่ศรี
Essential-everyday
Best-foods
Blue-diamond-almonds
Jack-daniel-s
Gerber
Hidden-valley
Kettle-brand
Walmart
Red-baron
Pocky
Ghirardelli
Chef-boyardee
Mott-s
Mars
Aunt-jemina
Meijer
Glaceau
Kettle
Budweiser
Volpi
Conagra-foods
Natural-sins
Glico
Brown-cow
Honest-tea
Del-monte
Cabot
Snapple
Blue-diamond
Refreshe
Nature-s-path
California-premium
Hormel
Nongshim
Back-to-nature
Bertolli
Keebler
Clover-valley
Dole
Dietz-watson
Wallaby-organic
Beach-cliff
Hannaford
Knorr
Delish
I-can-t-believe-it-s-not-butter
Gatorade
Maranatha
Prego
Carr-s
Kern-s-nectar
Blue-diamond-growers-corporation
Almond-breeze
Hellmann-s
Goya
Go-raw
The-fremont-company
Mississippi-barbecue-sauce
Horizon-organic
Perrier
Clover-stornetta
Wholesome
Stonyfield-organic
Chicken-of-the-sea
Tronky
Maruchan
Dr-pepper
Columbus
Cheerios
Duke-s
Folgers
Annie-s-homegrown
Kinder
Raley-s
Bolthouse-farms
Crystal-geyser
Nappa-valley-bistro
Cap-n-crunch
Amy-s
Forager
Poland-spring
Price-chopper
Ozarka
Wellington
Snyder-s-of-hanover
Stonewall-kitchen
M-s
Ferrara
Canada-dry
Ken-s-steak-house
Brisk
Pillsbury
Private-selection
Crown-prince
Arrowhead
Classico
Mama
Culinary-circle
Green-giant
Post
The-fresh-market
Momofuku-milk-bar
Eureka-bar
Field-roast
Sainsbury-s
Honey-maid
Nissin-demae
Bonne-maman
Corona
Spam
Lindt-excellence
Earth-balance
Bush-s
Clif
Sunria
De-cecco
Rockstar
Morton
Orville-redenbacher-s
Bettys-reiskuche
Snack-factory
Aldi
Triscuit
Newtons
Thomas
Via-roma
Pace
S-pellegrino
Central-market
Heb
Jell-o
Sun-maid
Malt-o-meal
Manitoba-harvest
Crisco
Pacific
Coffeemate
Sunset
Ritz
Banana-moon
Community-grains
Hampton-creek
Steaz
Core-meal
Organic-marketside
Clif-bar
Clifbar
Dasani
Red-bull
Domino
A-1
The-garlic-survival-co
Perfect-bar
Oregon-fruit-products
Korea-yakult
Land-o-lakes
Peeled-snacks
Humboldt-honey
Con-agra
King-s-hawaiian
Jewel
Bragg
Quorn
Samyang
Wish-bone
Crystal-light
Healthy-choice
Drive-thru-tree
Dr-pepper-snapple-group
A-w
Marzetti
Zatarain-s
Price-first
Tesco
Altoids
Cascadian-farm
Kar-s
Vitasoy
Wei-chuan
Pompeian
Archer-farms
Reese
今麥郎
Krusteaz
Gallo-family
Uncle-ben-s
Ball-park
Delallo
Conagra
Horizon
Sweet-baby-ray-s
Alexia
Paldo
Bare
Vitacoco
Gold-emblem
Simply
Beaver-brand
Deep-river-snacks
Alive-and-radiant
Aquafina
Seven-sundays
Stretch-island-fruit-co
Mammoth-brewing-company
Jack-link-s
National-foods-ltd
Activia
Wholesome-farms
Juice-squeeze
Evian
Kerrygold
Crich
Chia-pod
Chex
Hail-merry
Spring-hill-jersey-cheese
Toll-house
Herdez
Edmond-fallot
Von-s
Clover
Fiber-one
Lenny-larry-s
The-hershey-company
Country-choice
Colombus
Mtn-dew
Orangina
Quaker-oats
Ronzoni
Berkeley-farms
Girl-scouts
Bar-harbor
Erewhon
Target
Cheetos
Hostess
Kashi
Knott-s
Dorset-cereals
Lion
Jml
Llc
Bear-naked
Hersey-s
Izze
Kern-s
Gold-medal
Purity-organic
Sonoma-harvest
Purity
Andean-dream
Sierra-mist
Ragu
365-everyday-value
Greyston-bakery
Greyston-foundation
Mt-olive
Polar
Kraft-foods
Bubblicious
Jinmailang
Jinmailang-nissin-food-co-ltd
Daiya
Wellshire
Clover-organic-farms
Sapporo
Town-house
Eastland
Caravelle
Indofood
Odwalla
Bumble-bee
Pamela-s
Wild-harvest
Asahi
Kellogs
King-oscar
Badia
Shedd-s-spread
Lu
Country-crock
Darigold
Frito-lay
Spectrum
Applegate-organics
Food-should-taste-good
Kirin
Nescafe
Nesquik
Silk
Hunt-s
Newman-s-own
Snip-chips
Hickory-farms
Organic-by-nature
Wedderspoon
Mission
Digiorno
Haribo
 
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

my %brands = ();
my $products_with_brand = 0;

open (my $IN, "<" , "/home/off/usda-ndb/brands.txt") or die("unable to read /data/off/us/brands.txt");
while (<$IN>) {
	# remove bad chars
	my $line = $_;
	$line =~ s/[^[:ascii:]]//g;
	if ($line =~ /^no manufacture/i) {
		next;
	}
	if ($line =~ /^(.*?)\t(.*?),/) {
		$brands{$2} = $1;
		#print "product number: $2 - brand: $1\n";
		$products_with_brand++;
	}
}
close $IN;
print "$products_with_brand products with brand\n";
#exit;


my %product_names = ();
my %potential_brands = ();

my %nutrients_names = ();
my %nutrients_ids = ();

$User_id = 'usda-ndb-import';

my $editor_user_id = 'usda-ndb-import';

my $dir = $ARGV[0];
$dir =~ s/\/$//;

my $photo_user_id = $ARGV[1];

$User_id = 'usda-ndb-import';
$photo_user_id = "usda-ndb-import";
$editor_user_id = "usda-ndb-import";

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
	lc => 'en',
	countries => "US",
);

$lc = 'en';

my $comment = "USDA National Nutrient Database https://ndb.nal.usda.gov/ndb/ data import";

my $time = time();

my $i = 0;
my $existing = 0;
my $new = 0;
my $differing = 0;
my %differing_fields = ();
my @edited = ();
my %edited = ();

my $testing = 0;

my $bad_files = "";

my %existing_fields = ();

my $total = 0;
my $no_upc = 0;

if (opendir (DH, "$dir")) {
	foreach my $file (sort { $a <=> $b } readdir(DH)) {
	
		#next if $file gt "2013-07-13 11.02.07";
		#next if $file le "DSC_1783.JPG";
	
		if ($file =~ /\.json/i) {
		
		
			open (my $in, "<", "$dir/$file") or die "cannot read $dir/$file : $! \n";
			my $json = join("",(<$in>));
			close $in;
			
			print reading "$file\n";
			
			#print $json;
			
			my @modified_fields;
			my @images_ids;
			
#    "report": {
#        "sr": "January, 2017",
#        "type": "Basic",
#        "food": {
#            "ndbno": "45155737",
#            "name": "RALEY'S, DARK CHOCOLATE BAR, UPC: 046567031705",			

			# Explanation of the different fields:
			# https://ndb.nal.usda.gov/ndb/doc/apilist/API-FOOD-REPORTV2.md
			
			my $field_description = <<TEXT
foods	the list of foods reported for a request
count	Number of foods requested and processed
notfound	Number of requested foods not found in the database
api	API Version
food	the food report
type	Report type
sr	Release version of the data being reported
desc	metadata elements for the food being reported
ndbno	NDB food number
name	food name
sd	short description
group	food group
sn	scientific name
cn	commercial name
manu	manufacturer
nf	nitrogen to protein conversion factor
cf	carbohydrate factor
ff	fat factor
pf	protein factor
r	refuse %
rd	refuse description
ds	database source: 'Branded Food Products' or 'Standard Reference'
ru	reporting unit: nutrient values are reported in this unit, usually gram (g) or milliliter (ml)
ing	ingredients (Branded Food Products report only)
desc	list of ingredients
upd	date ingredients were last updated by company
nutrient	metadata elements for each nutrient included in the food report
nutrient_id	nutrient number (nutrient_no) for the nutrient
name	nutrient name
sourcecode	list of source id's in the sources list referenced for this nutrient
unit	unit of measure for this nutrient
value	100 g equivalent value of the nutrient
dp	# of data points
se	standard error
measures	list of measures reported for a nutrient
label	name of the measure, e.g. "large"
eqv	equivalent of the measure expressed as an eunit
eunit	Unit in with the equivalent amount is expressed. Usually either gram (g) or milliliter (ml)
value	gram equivalent value of the measure
source	reference source, usually a bibliographic citation, for the food
title	name of reference
authors	authors of the report
vol	volume
iss	issue
year	publication year
start	start page
end	end page
footnote
idv	footnote id
desc	text of the foodnote
langual	LANGUAL codes assigned to the food
code	LANGUAL code
desc	description of the code			
TEXT
;			
			
			
			my $ndb_ref;


			eval { $ndb_ref = decode_json($json); };
			
			if (not defined $ndb_ref) {
				print "bad json file: $file\n";
				$bad_files .= $file . "\n";
			}
			
			my $ndb_id = $ndb_ref->{report}{food}{ndbno};
			my $ndb_product_ref = $ndb_ref->{report}{food};
			my $code = undef;
			my $name = $ndb_product_ref->{name};
			
			$total++;
			
			if ($name =~ /, UPC: (\d+)/) {
				$code = $1;
				$code = normalize_code($code);
				$name = $`;
				$ndb_product_ref->{name} = $`;
			}
			else {
				print "no upc / barcode for product ndbno $ndb_id - name: $name\n";
				$no_upc++;
				next;
			}
			
			#next if ($ndb_id !~ /^4504.76./);
			next if $code eq "0744473912254";
			
			$i++;

			next if $i <= 10000;
			#last if $i > 10000;
			next if $ndb_id <= 45180400;
			next if $ndb_id <= 45205042;
			next if $ndb_id <= 45205353;

			
			
			print "product $i - ndb_id: $ndb_id - code: $code\n";

			# $i <= 108514 and next;
			
			
			my $product_ref = product_exists($code); # returns 0 if not
			
			if (not $product_ref) {
				print "- does not exist in OFF yet\n";
				$new++;
				if (1 and (not $product_ref)) {
					print "product code $code does not exist yet, creating product\n";
					$User_id = $photo_user_id;
					$product_ref = init_product($code);
					$product_ref->{interface_version_created} = "import_us_ndb.pl - version 2017/03/04";
					$product_ref->{lc} = $global_params{lc};
					delete $product_ref->{countries};
					delete $product_ref->{countries_tags};
					delete $product_ref->{countries_hierarchy};					
					#store_product($product_ref, "Creating product (import_us_ndb.pl bulk upload) - " . $comment );					
				}				
				
			}
			else {
				print "- already exists in OFF\n";
				$existing++;
			}
			
			# images: uploads_production/image/data/15937/xlarge_7610807072198.jpg\?v\=1468391266
			
#images: [
#{
#categories: [
#"Ingredients list"
#],
#thumb: "https://d2v5oodgkvnw88.cloudfront.net/uploads_production/image/data/4036/thumb_myImage.jpg?v=1468842503",
#medium: "https://d2v5oodgkvnw88.cloudfront.net/uploads_production/image/data/4036/medium_myImage.jpg?v=1468842503",
#large: "https://d2v5oodgkvnw88.cloudfront.net/uploads_production/image/data/4036/large_myImage.jpg?v=1468842503",
#xlarge: "https://d2v5oodgkvnw88.cloudfront.net/uploads_production/image/data/4036/xlarge_myImage.jpg?v=1468842503"
#},			
			

			# which fields exist?
			
			foreach my $field (keys %{$ndb_product_ref}) {
				$existing_fields{$field}++;
			}
			
			
			# First load the global params, then apply the product params on top
			my %params = %global_params;
			
			if (defined $ndb_product_ref->{name}) {
				$params{product_name} = $ndb_product_ref->{name};
				print "set product_name to $params{product_name}\n";
				
				$product_names{$ndb_product_ref->{name}}++;
				
				if ($ndb_product_ref->{name} =~ /^'(.+)'/) {
					$potential_brands{$1}++;
				}
				elsif ($ndb_product_ref->{name} =~ /^"(.+)"/) {
					$potential_brands{$1}++;
				}
				elsif ($ndb_product_ref->{name} =~ /^([^,]+),/) {
					$potential_brands{$1}++;
				}
				
				# try to find a brand in the name
				
				my %this_product_brands = ();
				
				if (1) {
				foreach my $regexp (@brands_regexps) {
					if ($ndb_product_ref->{name} =~ /^($regexp)\b/i) {
						my $brand = $1;
						my $product_name = $';
						$product_name =~ s/^\W+//;
						$brand =~ s/,/ /g; # we can't have comma in the brands tags field
						print "found brand $brand - product $product_name - in name $ndb_product_ref->{name} \n";
						$params{product_name} = $product_name;
						$params{brands} = $brand;
						my $brand_id = get_fileid($brand);
						$this_product_brands{$brand_id} = 1;
						last;
					}
				}
				
				# got a manufacturer from the ndb web version?
				if (defined $brands{$ndb_id}) {
					my $manufacturer = $brands{$ndb_id};
					# remove manufacturer from name if it's there
					$params{product_name} =~ s/^$manufacturer\b//ie;
					$manufacturer =~ s/,/ /g; # we can't have comma in the brands tags field
					# add to brand
					my $manufacturer_id = get_fileid($manufacturer);
					if (not defined $this_product_brands{$manufacturer_id}) {
						$params{brands} .=  ", " . $manufacturer;
						$params{brands} =~ s/^, //;
					}
					
				}
				
				if (not defined $params{brands}) {
					print "no brand found in name $ndb_product_ref->{name} \n";
				}
				}
				
				$params{product_name} =~ s/^(,| |'|"|-|_)+//g;
				
				# uppercase first letter of each word
				$params{brands} = lc ($params{brands});
				$params{brands} =~ s/\b([a-z-_])/uc($1)/eg;
				$params{brands} =~ s/'S/'s/g;
				
				# uppercase first letter of each word
				$params{product_name} = lc ($params{product_name});
				$params{product_name} =~ s/\b([a-z-_])/uc($1)/eg;
				$params{product_name} =~ s/'S/'s/g;
				
				# copy value to main language				
				$params{"product_name_" . $global_params{lc}} = $params{product_name};
				
				
			}			
			
			if (defined $ndb_product_ref->{quantity}) {
				$params{quantity} = $ndb_product_ref->{quantity} . ' ' .  $ndb_product_ref->{unit};
				print "set quantity to $params{quantity}\n";
			}
			
#            "nutrients": [
#                {
#                    "nutrient_id": "208",
#                    "name": "Energy",
#                    "group": "Proximates",
#                    "unit": "kcal",
#                    "value": "535",
#                    "measures": [
#                        {
#                            "label": "BAR",
#                            "eqv": 43.0,
#                            "eunit": "g",
#                            "qty": 0.5,
#                            "value": "230"
#                        }
#                    ]
#                },			
			
			if ((defined $ndb_product_ref->{"nutrients"}) and (defined $ndb_product_ref->{"nutrients"}[0])
				 and (defined $ndb_product_ref->{"nutrients"}[0]{measures})
				  and (defined $ndb_product_ref->{"nutrients"}[0]{measures}[0]{eqv})){
				
				$params{serving_size} = $ndb_product_ref->{"nutrients"}[0]{measures}[0]{eqv} . " " . $ndb_product_ref->{"nutrients"}[0]{measures}[0]{eunit}
					. " (" . $ndb_product_ref->{"nutrients"}[0]{measures}[0]{qty} . ' ' . $ndb_product_ref->{"nutrients"}[0]{measures}[0]{label} . ")";
				#$params{serving_size} = $ndb_product_ref->{"portion-quantity"} . ' ' .  $ndb_product_ref->{"unit"};
				print "set serving_size to $params{serving_size}\n";
			}			
			
			my %ndb_language_specific_fields = (
				'ing' => 'ingredients_text',
			);
			
			my $updated = "";
			
			foreach my $field (sort keys %ndb_language_specific_fields) {
			
				my $off_field = $ndb_language_specific_fields{$field};

#            "ing": {
#                "desc": "DARK CHOCOLATE (COCOA MASS, SUGAR, COCOA BUTTER, SOY LECITHIN [EMULSIFIER], AND NATURAL VANILLA EXTRACT).",
#                "upd": "09/23/2016"
#            },				
				if (defined $ndb_product_ref->{$field}) {
					$params{$off_field} = $ndb_product_ref->{$field}{desc};
					if (defined $ndb_product_ref->{$field}{upd}) {
						$updated = $ndb_product_ref->{$field}{upd};
					}
					if (ref ($params{$off_field}) eq 'ARRAY') {
						$params{$off_field} = join(', ', @{$params{$off_field}});
					}					
					
					# lowercase ingredients
					$params{$off_field} = ucfirst(lc($params{$off_field}));
					
					print "set $field to $params{$field}\n";
					
					my $language = 'en';
					$params{$off_field . "_" . $language} = $params{$off_field};
					
				}			
			
			}


			
			
			# Create or update fields
			
			my @param_fields = ();
			
			my @fields = @ProductOpener::Config::product_fields;
			foreach my $field ('product_name', 'generic_name', @fields, 'serving_size', 'traces', 'ingredients_text','lang') {
			
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

				
					# for tag fields, only add entries to it, do not remove other entries
					
					if (defined $tags_fields{$field}) {
					
						my $current_field = $product_ref->{$field};

						my %existing = ();
						foreach my $tagid (@{$product_ref->{$field . "_tags"}}) {
							$existing{$tagid} = 1;
						}
						
						
						foreach my $tag (split(/,/, $params{$field})) {
		
							my $tagid;

							if (defined $taxonomy_fields{$field}) {
								$tagid = canonicalize_taxonomy_tag($params{lc}, $field, $tag);
							}
							else {
								$tagid = get_fileid($tag);
							}
							if (not exists $existing{$tagid}) {
								print "- adding $tagid to $field: $product_ref->{$field}\n";
								$product_ref->{$field} .= ", $tag";
							}
							
						}
						
						# next if ($code ne '3017620401473');
						
						
						if ($product_ref->{$field} =~ /^, /) {
							$product_ref->{$field} = $';
						}	
						
						if ($field eq 'emb_codes') {
							# French emb codes
							$product_ref->{emb_codes_orig} = $product_ref->{emb_codes};
							$product_ref->{emb_codes} = normalize_packager_codes($product_ref->{emb_codes});						
						}
						if ($current_field ne $product_ref->{$field}) {
							print "changed value for product code: $code - field: $field = $product_ref->{$field} - old: $current_field \n";
							compute_field_tags($product_ref, $field);
							push @modified_fields, $field;
						}
					
					}
					else {
						# non-tag field
						my $new_field_value = $params{$field};
						
						if (($field eq 'quantity') or ($field eq 'serving_size')) {
							
								# openfood.ch now seems to round values to the 1st decimal, e.g. 28.0 g
								$new_field_value =~ s/\.0 / /;					
						}

						my $normalized_new_field_value = $new_field_value;

						
						# existing value?
						if ((defined $product_ref->{$field}) and ($product_ref->{$field} !~ /^\s*$/)) {
							my $current_value = $product_ref->{$field};
							$current_value =~ s/\s+$//g;
							$current_value =~ s/^\s+//g;							
							
							# normalize current value
							if (($field eq 'quantity') or ($field eq 'serving_size')) {								
							
								$current_value =~ s/(\d)( )?(g|gramme|grammes|gr)(\.)?/$1 g/i;
								$current_value =~ s/(\d)( )?(ml|millilitres)(\.)?/$1 ml/i;
								$current_value =~ s/(\d)( )?cl/${1}0 ml/i;
								$current_value =~ s/(\d)( )?dl/${1}00 ml/i;
								$current_value =~ s/litre|litres|liter|liters/l/i;
								$current_value =~ s/(0)(,|\.)(\d)( )?(l)(\.)?/${3}00 ml/i;
								$current_value =~ s/(\d)(,|\.)(\d)( )?(l)(\.)?/${1}${3}00 ml/i;
								$current_value =~ s/(\d)( )?(l)(\.)?/${1}000 ml/i;
								$current_value =~ s/kilogramme|kilogrammes|kgs/kg/i;
								$current_value =~ s/(0)(,|\.)(\d)( )?(kg)(\.)?/${3}00 g/i;
								$current_value =~ s/(\d)(,|\.)(\d)( )?(kg)(\.)?/${1}${3}00 g/i;
								$current_value =~ s/(\d)( )?(kg)(\.)?/${1}000 g/i;
							}
							
							if ($field =~ /\ingredients/) {
							
								$current_value = get_fileid(lc($current_value));
								$current_value =~ s/\W+//g;
								$normalized_new_field_value = get_fileid(lc($normalized_new_field_value));
								$normalized_new_field_value =~ s/\W+//g;
								
							}
							
							if (lc($current_value) ne lc($normalized_new_field_value)) {
								print "differing value for product code $code - field $field - existing value: $product_ref->{$field} (normalized: $current_value) - new value: $new_field_value - https://world.openfoodfacts.org/product/$code \n";
								$differing++;
								$differing_fields{$field}++;								
							}
						}
						else {
							print "setting previously unexisting value for product code $code - field $field - value: $new_field_value\n";
							$product_ref->{$field} = $new_field_value;
							push @modified_fields, $field;
						}
					}					
				}
			}
			
			
			# Nutrients
			# {
			# name: "Matières grasses",
			# name-translations: {
			# de: "Fett",
			# en: "Fat",
			# fr: "Matières grasses",
			# it: "Grassi"
			# },
			# unit: "kJ",
			# order: 1,
			# per-hundred: "1530.0",
			
			if (defined $ndb_product_ref->{nutrients}) {
			
				if (not defined $product_ref->{nutrition_data_per}) {
					$product_ref->{nutrition_data_per} = "100g";
				}
				
				if ($product_ref->{nutrition_data_per} eq '100g') {
				
					if (not defined $product_ref->{nutriments}) {
						$product_ref->{nutriments} = {};
					}
					
#            "nutrients": [
#                {
#                    "nutrient_id": "208",
#                    "name": "Energy",
#                    "group": "Proximates",
#                    "unit": "kcal",
#                    "value": "535",
#                    "measures": [
#                        {
#                            "label": "BAR",
#                            "eqv": 43.0,
#                            "eunit": "g",
#                            "qty": 0.5,
#                            "value": "230"
#                        }
#                    ]
#                },					
			
					foreach my $nutrient_ref (@{$ndb_product_ref->{nutrients}}) {
						my $nutrient_name = lc($nutrient_ref->{"name"});
												
						$nutrients_names{$nutrient_name}++;
						$nutrients_ids{$nutrient_ref->{"nutrient_id"}}++;
						
						# %nutrients
						if (defined $ndb_nutrients{$nutrient_name}) {
							my $nid = $ndb_nutrients{$nutrient_name};
							$nid =~ s/^(-|!)+//g;
							$nid =~ s/-$//g;		
							
							
							# skip sodium if we have salt
							# ($nid eq 'sodium') and next;

							my $enid = encodeURIComponent($nid);
							my $value = $nutrient_ref->{"value"};
							# openfood.ch now seems to round values to the 1st decimal, e.g. 28.0 g
							$value =~ s/\.0$//;	
							my $unit = $nutrient_ref->{"unit"};
							

							my $value_new = $value;
							my $unit_new = $unit;
							
							if (((uc($unit) eq 'IU') or (uc($unit) eq 'UI')) and ($Nutriments{$nid}{iu} > 0)) {
									$value_new = $value * $Nutriments{$nid}{iu} ;
									$unit_new = $Nutriments{$nid}{unit};
							}
							
							my $value_g = unit_to_g($value_new, $unit_new);
							
							print "debug - nutrient - $value $unit -> $value_new $unit_new -> $value_g g\n";
							
							if ((not defined $product_ref->{nutriments}{$nid}) or ($product_ref->{nutriments}{$nid} eq "")) {
							
								$product_ref->{nutriments}{$nid . "_unit"} = $unit;		
								$product_ref->{nutriments}{$nid . "_value"} = $value;
								
								if (((uc($unit) eq 'IU') or (uc($unit) eq 'UI')) and ($Nutriments{$nid}{iu} > 0)) {
									$value = $value * $Nutriments{$nid}{iu} ;
									$unit = $Nutriments{$nid}{unit};
								}
								elsif (($unit eq '% DV') and ($Nutriments{$nid}{dv} > 0)) {
									$value = $value / 100 * $Nutriments{$nid}{dv} ;
									$unit = $Nutriments{$nid}{unit};
								}
								
								if ($nid eq 'water-hardness') {
									$product_ref->{nutriments}{$nid} = unit_to_mmoll($value, $unit);
								}
								else {
									$product_ref->{nutriments}{$nid} = unit_to_g($value, $unit);
								}							
								print "setting nutrient for code $code - nid $nid - value $value unit $unit = $product_ref->{nutriments}{$nid} \n";
								push @modified_fields, "nutrients.$nid";
							}
							else {
								if ($value_g != $product_ref->{nutriments}{$nid}) {
									print "differing nutrient for code $code - nid $nid - value $value unit $unit = $value_g differs from existing $product_ref->{nutriments}{$nid} \n"
								}
							}
						}
						else {
							print "unknown nutrient - $nutrient_name - \n";
						}
					}
				
				}
				else {
					# avoid mixing apple and oranges
					print "skipping nutrition data as product_ref->{nutrition_data_per} is set to " . $product_ref->{nutrition_data_per} . "\n";
				}
			}			
			
			
			if (scalar @modified_fields > 0) {
			
			# Process the fields

			# Food category rules for sweeetened/sugared beverages
			# French PNNS groups from categories
			
			if ($server_domain =~ /openfoodfacts/) {
				ProductOpener::Food::special_process_product($product_ref);
			}
			
			
			if ((defined $product_ref->{nutriments}{"carbon-footprint"}) and ($product_ref->{nutriments}{"carbon-footprint"} ne '')) {
				push @{$product_ref->{"labels_hierarchy" }}, "en:carbon-footprint";
				push @{$product_ref->{"labels_tags" }}, "en:carbon-footprint";
			}	
			
			if ((defined $product_ref->{nutriments}{"glycemic-index"}) and ($product_ref->{nutriments}{"glycemic-index"} ne '')) {
				push @{$product_ref->{"labels_hierarchy" }}, "en:glycemic-index";
				push @{$product_ref->{"labels_tags" }}, "en:glycemic-index";
			}
			
			# Language and language code / subsite
			
			if (defined $product_ref->{lang}) {
				$product_ref->{lc} = $product_ref->{lang};
			}
			
			if (not defined $lang_lc{$product_ref->{lc}}) {
				$product_ref->{lc} = 'xx';
			}	
			
			
			# For fields that can have different values in different languages, copy the main language value to the non suffixed field
			
			foreach my $field (keys %language_fields) {
				if ($field !~ /_image/) {
					if (defined $product_ref->{$field . "_$product_ref->{lc}"}) {
						$product_ref->{$field} = $product_ref->{$field . "_$product_ref->{lc}"};
					}
				}
			}
							

			if (not $testing) {							
				# Ingredients classes
				extract_ingredients_from_text($product_ref);
				extract_ingredients_classes_from_text($product_ref);

				compute_languages($product_ref); # need languages for allergens detection
				detect_allergens_from_text($product_ref);			
			}
			
			
#"sources": [
#{
#"id", "usda-ndb",
#"url", "https://ndb.nal.usda.gov/ndb/foods/show/58513?format=Abridged&reportfmt=csv&Qv=1" (direct product url if available)
#"import_t", "423423" (timestamp of import date)
#"fields" : ["product_name","ingredients","nutrients"]
#"images" : [ "1", "2", "3" ] (images ids)
#},
#{
#"id", "usda-ndb",
#"url", "https://ndb.nal.usda.gov/ndb/foods/show/58513?format=Abridged&reportfmt=csv&Qv=1" (direct product url if available)
#"import_t", "523423" (timestamp of import date)
#"fields" : ["ingredients","nutrients"]
#"images" : [ "4", "5", "6" ] (images ids)
#},			

			if (not defined $product_ref->{sources}) {
				$product_ref->{sources} = [];
			}
			
			push @{$product_ref->{sources}}, {
				id => "usda-ndb",
				url => "https://api.nal.usda.gov/ndb/reports/?ndbno=$ndb_id&type=f&format=json&api_key=DEMO_KEY",
				import_t => time(),
				fields => \@modified_fields,
				images => \@images_ids,	
			};

			
				
			$User_id = $editor_user_id;
			
			if (not $testing) {
			
				fix_salt_equivalent($product_ref);
					
				compute_serving_size_data($product_ref);
				
				compute_nutrition_score($product_ref);
				
				compute_nutrient_levels($product_ref);
				
				compute_unknown_nutrients($product_ref);			
			
				store_product($product_ref, "Editing product (import_us_ndb.pl bulk import) - " . $comment . " - upd: " . $updated);
				
				push @edited, $code;
				$edited{$code}++;
				
			}
			
			}
				# $i > 100 and last;
			
			#last;
		}  # if $file =~ json
			
	}
	closedir DH;
}
else {
	print STDERR "Could not open dir $dir : $!\n";
}

print "$i products\n";
print "$new new products\n";
print "$existing existing products\n";
print "$differing differing values\n\n";

print ((scalar @edited) . " edited products\n");
print ((scalar keys %edited) . " editions\n");

foreach my $field (sort keys %differing_fields) {
	print "field $field - $differing_fields{$field} differing values\n";
}

print "\n\nexisting fields with values:\n";

foreach my $field (sort {$existing_fields{$a} <=> $existing_fields{$b}} keys %existing_fields) {
	print $field . "\t" . $existing_fields{$field} . "\n";
}

print "\n\nlist of nutrient names:\n\n";
foreach my $name (sort keys %nutrients_names) {
	print $name . "\t" . $nutrients_names{$name} .  "\n";
}

print "\n\nbad files:\n\n" . $bad_files;


open (my OUT, ">", "product_names.txt");
foreach my $name (sort keys %product_names) {
	print $OUT $name . "\n";
}
close $OUT;


open ($OUT, ">", potential_brands.txt");
foreach my $name (sort {$potential_brands{$b} <=> $potential_brands{$a}} keys %potential_brands) {
	print $OUT $name . "\t" . $potential_brands{$name} . "\n";
}
close $OUT;


print "\nproducts:\ntotal: $total - with upc: $i - no upc: $no_upc\n"
