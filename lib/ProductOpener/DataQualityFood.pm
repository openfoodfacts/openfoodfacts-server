# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2023 Association Open Food Facts
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

=head1 NAME

ProductOpener::DataQualityFood - check the quality of data for food products

=head1 DESCRIPTION

C<ProductOpener::DataQualityFood> is a submodule of C<ProductOpener::DataQuality>.

It implements quality checks that are specific to food products.

When the type of products is set to food, C<ProductOpener::DataQuality::check_quality()>
calls C<ProductOpener::DataQualityFood::check_quality()>, which in turn calls
all the functions of the submodule.

=cut

package ProductOpener::DataQualityFood;

use ProductOpener::PerlStandards;
use Exporter qw(import);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&check_quality_food
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use ProductOpener::Config qw(:all);
use ProductOpener::Store qw(get_string_id_for_lang);
use ProductOpener::Tags qw(:all);
use ProductOpener::Food qw(%categories_nutriments_per_country);
use ProductOpener::EnvironmentalScore qw(is_environmental_score_extended_data_more_precise_than_agribalyse);
use ProductOpener::Units qw(extract_standard_unit);

use Data::DeepAccess qw(deep_exists);

use Log::Any qw($log);

=head1 HARDCODED BRAND LISTS

The module has 4 hardcoded lists of brands: @baby_food_brands, @cigarette_brands, @petfood_brands and @beauty_brands

We will probably create a brands taxonomy at some point, which will allow us to remove those hardcoded lists.

=cut

my @baby_food_brands = qw(
	Gallia
	Bledina
	Modilac
	Guigoz
	Milumel
	Hipp
	Babybio
	Novalac
	Premibio
	Picot
	Bledilait
	Carrefour-baby
	Pommette
	Laboratoires-guigoz
	Nidal
	Lactel-eveil
	Holle
	Mots-d-enfants
	Laboratoire-guigoz
	Bledidej
	Bebe-nestle
	Laboratoire-gallia
	Gilbert
	Hipp-biologique
	U-tout-petits
	Milupa
	Nestle-bebe
	Blediner
	Guiguoz
	Laboratoires-picot
	Nutricia
	P-tit-souper
	P-tit-dej-croissance
	P-tit-dej
	Sodiaal
	Premichevre
	Auchan-baby
	Aptamil
	Candia-croissance
	Lactel-lait-pour-nourrisson
	Croissance
	Biostime
	Premilait
	Envia
	Babysoif
	Capricare
	France-lait
	Candia-baby
	Physiolac
	Topfer
	Nutrilac
);

my @cigarette_brands = qw(
	A-Mild
	Absolute-Mild
	Access-Mild
	Akhtamar
	Alain-Delon
	Apache
	Ararat
	Ashford
	Avolution
	Bahman
	Basic
	Belomorkanal
	Benson-&-Hedges
	Bentoel
	Berkeley
	Bintang-Buana
	Bond-Street
	Bristol
	Cabin
	Cambridge
	Camel
	Canadian-Classics
	Capri
	Capstan
	Carroll's
	Caster
	Cavanders
	Chancellor
	Charminar
	Charms
	Chesterfield
	Chunghwa
	Clas-Mild
	Classic-Filter-Kings
	Clavo
	Cleopatra
	Club
	Club-Mild
	Cohiba
	Cool
	Country
	Craven-A
	Crossroads
	Crystal
	Dakota
	Davidoff
	Deluxe-Tenor
	Derby
	Djarum-Black
	Djarum-Vanilla
	Dji-Sam-Soe-234
	Dominant
	Doral
	Double-Happiness
	Du-Maurier
	Duke
	Dunhill
	Eclipse
	Elita
	Embassy
	Envio-Mild
	Ernte-23
	Esse
	Eve
	Everest
	Extreme-Mild
	f6
	Fatima
	Fellas-Mild
	Fix-Mild
	Fixation
	Flair
	Flake
	Fortuna
	Four-Square
	FS1
	Galan
	Garni
	Gauloises
	Geo-Mild
	Gitanes
	GL
	Gold-Flake
	Golden-Bat
	GT
	Gudang-Garam
	HB
	Hits-Mild
	Hongtashan
	Hope
	India-Kings
	Insignia
	Intro
	Java
	Jazy-Mild
	Joged
	Player's
	June
	Karo
	Kent
	King's
	Kool
	Krong-Thip
	L&M
	L.A.-Lights
	Lambert-&-Butler
	Lark
	LD
	Legend
	Liggett-Select
	Lips
	Longbeach
	Lucky-Strike
	Main
	Marlboro
	Maraton
	Masis
	Master-Mild
	Matra
	Maverick
	Max
	Maxus
	Mayfair
	MayPole
	Memphis
	Merit
	Mevius
	Mild-Formula
	Minak-Djinggo
	Misty
	Mocne
	Moments
	Mondial
	More
	MS
	Muratti
	Natural-American-Spirit
	Navy-Cut
	Neo-Mild
	Neslite
	Newport
	Next
	Nikki-Super
	Niko-International
	Nil
	Niu-Niu
	NO.10
	Noblesse
	North-Pole
	NOY
	Nuu-Mild
	One-Mild
	Pall-Mall
	Panama
	Parisienne
	Parliament
	Peace
	Pensil-Mas
	Peter-Stuyvesant
	Pianissimo-Peche
	Platinum
	Players
	Polo-Mild
	Popularne
	Prima
	Prince
	Pueblo
	Pundimas
	Pyramid
	Rambler
	Rawit
	Red-&-White
	Red-Mild
	Regal
	Regent
	Relax-Mild
	Richmond
	Romeo-y-Julieta
	Rothmans
	Royal
	Saat
	Salem
	Sampoerna-Hijau
	Sakura
	Scissors
	Score-Mild
	Sejati
	Senior-Service
	Seven-Stars
	Shaan
	Silk-Cut
	Slic-Mild
	Smart
	Sobranie
	Special-Extra-Filter
	ST-Dupont
	Star-Mild
	State-Express-555
	Sterling
	Strand
	Style
	Superkings
	Surya-Pro-Mild
	Sweet-Afton
	Taj-Chhap-Deluxe
	Tali-Jagat
	Tareyton
	Ten-Mild
	Thang-Long
	Time
	Tipper
	True
	U-Mild
	Ultra-Special
	Uno-Mild
	Up-Mild
	Urban-Mild
	Vantage
	Vegas-Mild
	Vogue
	Viceroy
	Virginia-Slims
	Viper
	West
	Wills-Navy-Cut
	Winfield
	Win-Mild
	Winston
	Wismilak
	Woodbine
	X-Mild
	Ziganov
	Zhongnanhai
);

my @petfood_brands = qw(
	Affinity
	Almo-nature
	Animonda
	Brekkies
	Canaillou
	Carnilove
	Cesar
	Compy
	Coshida
	Delikuit
	Dreamies
	Edgard-cooper
	Feringa
	Feringa-mit-viel-liebe-wie-hausgemacht
	Fido
	Friskies
	Frolic
	Greenies
	Hill-s
	Hills
	Iams
	Jacky
	Josera
	Juliet
	Kitekat
	Luckylou
	Lycat
	Lydog
	Monge
	Nutrivet
	Orijen
	Pedigree
	Perfect-fit
	Platinum
	Premiere
	Purina
	Purina-one
	Purizon
	Real-nature
	Riga
	Rinti
	Royal-canin
	Saphir
	Schesir
	Select-gold
	Sheba
	Tetra
	Tom-co
	Trixie
	Ultima
	Versele-laga
	Virbac
	Vitakraft
	Waltham
	Whiskas
	Wild-freedom
	Winston
	Yarrah
	Zooroyal
);

my @beauty_brands = qw(
	4711
	-18° [ ]
	& Other Stories
	100% pure
	1000 Hour
	1001 Remedies
	100BON
	111 Skin
	180 Cosmetics
	1919 Bains de Mer
	1944 Paris
	2B
	2FaceS
	2Moss
	2SOL
	3 Chênes Laboratoires
	3 Fées
	3 more inches
	3A Apple Anti-Age
	3C Pharma
	3CE 3 Concept Eyes
	3INA
	3M
	3Point3
	5SensesSystem
	5Yina
	66°30
	7Days
	7ème élément
	900.care
	A
	A Good Clean
	A La Claire Fontaine
	A Lab On Fire
	A True
	A World of Oils
	A-Cerumen
	A-Derma
	A-derma
	A. Vogel
	A.S Apothecary
	A'kin
	A'Pieu
	AA Skincare
	Aagaard
	Abahna
	Abalico
	Abbaye de Novy Dvur
	Abbaye de Sept-Fons
	ABBI
	Abel
	Abellie
	Abellio
	Abena
	Abercrombie & Fitch
	Abiessence
	Abiocom
	Abnomaly
	Aboca
	Absolument Parfumeur
	Absolute Aromas
	absolute collagen
	Absolute New York
	Absolute Organic
	absolution
	académie scientifique de beauté
	Accessorize
	Accord Parfait
	acevivi
	Achro Factor
	AcleYor
	ACM Laboratoire Dermatologique
	AcnEase
	AcneFree
	Acorelle
	Acorelle
	Acqua di Parma
	Act Bio
	Action
	Activa Laboratoires
	Activbod
	Active Formulas
	Activilong
	Activpharma
	Acure
	Ad Naturam
	Addax
	Additiva
	Adidas
	Adidas
	ADN Paris
	adopt
	Adrien Gagnon
	Aeos Active Energised Organic Skincare
	Aequilibrium
	Aerin
	Aesop
	AesthetiCare
	Aestura
	Aether Beauty
	Aflofarm
	African Botanics
	African Pride
	Africare
	Afrikissime
	Afterglow Cosmetics
	afterspa
	Agallocha
	Agat'he
	Agatha
	Agent Nateur
	Agent Provocateur
	Aginax
	Agovie
	Agraria
	Ahava
	AHC
	ahuhu
	aïam maïa
	Aiemok
	aime
	Aimée de Mars
	Ainhoa
	Ainsifont... bébé
	Aïny
	Air Paris
	Air Wick
	Air-Lift
	Airplus
	AIVA
	Aix les Bains
	Akamuti
	Akane
	AKEO
	Akildia
	Akileïne
	Akilenjur
	Al Hourra
	Al Rehab
	Alaena
	Alba Botanica
	Alban Muller
	Alcante
	Alcia Laboratoires
	Alderney Laboratoire
	Aldi
	Alepia
	Alessandro International
	Alexa Rodulfo
	Alexandra Soveral
	Alexandre.J
	Alexis Cosmetic
	Aleyria-cosmetiques
	Alfred Sung
	Algalys
	Algemarin
	Algenist
	Algo'nergy
	Algoane
	Algologie
	Algotherm
	Algovital
	Alguéna
	Alice & Peter
	Alima Pure
	Aliver
	Alix-de-faure
	Alkemilla Eco Bio Cosmetic
	All Tigers
	Allga San
	Allies of Skin
	Alline Procap
	Allo Nature
	Allynea
	Alma K.
	Almay
	Aloé Natural
	Aloe Vera Care
	AloeLand
	Aloeline
	Aloex
	Aloka
	Alorée
	Alors, Ça Pousse ?
	AlpAderm
	Alpdreams
	Alpecin
	Alpen Nature
	Alpha Foods
	Alpha-H
	Alphanova
	AlpinBreeze
	Alqvimia
	Alta Care Laboratoires
	Altearah
	Alter Ego
	Alterna
	Alternative Nature
	Alterra
	Alterra
	Altesse
	Altheagrey
	Altheys
	Altrient
	Aluminé by Peter Lamas
	Aluna
	alvadiem
	Alvéolys
	Alverde
	Alverde
	Alverde-naturkosmetik
	alviana
	Alvin Connor
	Alvira
	Alvityl
	always
	Alyssa Ashley
	Am'Style
	Amala
	Amalia Beauté
	Amanprana
	Amara
	Amaysie
	Amazing Cosmetics
	Amazon Secret
	Amazon Series
	Amazonia Viva
	Ambi Pur
	Ambiance Cade
	Ambiances des Alpes
	Ambiances Devineau
	Ambre
	Ame & Sens
	Amélie et Mélanie
	Ameliorate
	Aménaïde
	American Crew
	Ametis
	Amie
	amika
	Amilab
	AMLY
	amore puro
	Amorelie
	Amouage
	Ample : N
	AMUSE
	amycup
	Anaca3
	Anaé
	Anaféli Paris
	Anakae
	Ananné
	Anastasia Beverly Hills
	Anatole Lebreton
	Anatomicals
	AnboSyn
	Andalou Naturals
	Andishée
	Andrea Fulerton Nail Boutique
	Andrée Jardin
	andreia professional
	Andrew Barton
	Anes & Sens
	ânessence
	Anesses de Julie
	Ange du Sud
	Angel Care
	Angelina Contesi
	Anja Rubik
	Anjou
	Ann Steeger
	Anna Pegova
	Anna Sui
	Annagaspi
	Annayaké
	Anne Möller
	Anne Sémonin
	Anne-Marie Grallet parfums
	AnneMarie Börlind
	Annie's Way
	Anny
	Anny Rey
	ANS Brasil
	ansimara
	Antheya
	Antinomie
	Antipodes
	Antoinette Poisson
	Antonia Burrell
	Antonym
	Antos
	Anubis
	Any d'Avray
	Ao Tahiti
	Apaisac Biorga
	Apaisyl
	ApHogee
	Aphrosmile
	Api Sens
	api-ar
	Api-Nature
	Apicia
	Apiconseils
	Apiculture
	Apinat
	Apivita
	Apnée
	APO France
	Aponie
	ApoT.Care
	Apotek Organic
	Apple & Bears
	April
	Aprolis
	aptonia
	AQ Skin Solutions
	Aqua Bio
	Aquafresh
	Aquafresh
	Aquahero
	Aqualab
	Aquasilice
	AquaTéal
	Aquatherm
	Aquis
	AR457
	Arabisk
	Aragan
	Aramis
	Arbaurea
	Arbonne
	Arc en Sels
	Arcancil
	Archipelago
	Arcona
	Ard Al Zaafaran
	Ardell
	Ardes
	Areuh en Bio
	Arga Argany
	Argan Beaute
	Argan Bio
	Argan France
	Argan Héritage
	Argan Oil
	Argandia
	ArganEden
	Arganicare
	Arganis
	Argasol
	Argentum
	Argicrea
	argiletz
	Ariana Grande
	Arkential
	Arkopharma
	Armar
	Armencelle
	Armille
	Armonia
	Armonia Bio
	Arnaud Paris
	Arnidol
	Arno Sorel
	Arom&lys
	Aroma Celte
	Aroma Dead Sea
	Aroma Lamp
	Aroma Works
	Aroma-Zone
	Aroma-zone
	Aromachology
	aromacology
	Aromacology Sensi
	Aromadunes
	AromaKer
	Aromaleigh Mineral Cosmetics
	AromaNature
	Aromaore
	Aromaroc
	AromaSpray
	Aromat'Easy
	Aromatherapy Associates
	Aromatherapy Personals
	Aromatica
	Aromaya
	Arquiste
	Arrow
	Arrow Cosmetics Co
	Arsène Valère
	Artalep
	Artdeco
	ArtdeSoi
	Artègo
	Artejia
	Arti Shot
	Artifact Skin Co.
	Artis Brush
	Artistry
	artnaturals
	Arty Fragrance by Elisabeth de Feydeau
	arubix
	Arval L'Uomo
	As a Non-Believer
	As I Am
	Asella Cosmétiques
	Aseptonet
	Asinerie d'Embazac
	Asinerie de Pierretoun
	Asinerie du Pays des Collines
	Asinus
	asos
	assanis
	Assy 2000
	Astalift
	Astérale
	Asters Cosmetics
	Astier de Villatte
	Astra
	Astroplast
	At Last Naturals
	atashi cellular cosmetics
	Atelier Catherine Masson
	Atelier Cologne
	Atelier Flou
	Atelier Make-Up
	atelier nubio
	atelier populaire
	atida
	Atkinsons
	Atopiclair
	Atrix
	Attirance natural cosmetics
	Attitude
	Au Coeur des Traditions
	Au Moulin Rose
	Au Naturale Cosmetics
	Au Nom de la Rose
	Au Pays de la Fleur d'Oranger
	au petit monde de B.
	au poil
	Aubade
	Aubrey Organics
	Auchan
	Audispray
	Augustinus Bader
	aunea
	Aunt Jackie's
	Aura Chaké
	Auraflor
	Aurelia London
	Auriège
	Auriga
	Auris
	Auromère
	Aussie
	Aussie
	Australian Gold
	autenti care.
	Authentic
	Authentic Beauty Concept
	Authentine
	Autour du Bain
	Autour du Parfum
	Auxinol
	avaé
	Avalon Organics
	avant
	Aveda
	Aveeno
	Aveeno
	Avene
	Avène
	Avon
	Avon
	avril
	Avril Lavigne
	Axame
	Axe
	Axe
	Axiology
	Axitrans
	Ayres
	Aÿsse
	Ayur-Medic
	AYur-vana
	Aztec Secret
	Azzaro
	Azzedine Alaïa Paris
	Azzo
	B
	b basic
	B com BIO
	B Natur'all
	B Sand
	B.app professional
	B.Concept
	B.Kamins
	B.Lab
	b.tan
	Baba-Aloe
	Babaria
	Babaria
	Babor
	Baby Foot
	babybio
	Babyléna
	Babyliss
	BaByliss PRO
	Babylove
	Babysoin
	baccide
	Bachca
	Badger
	Bagsy
	Bahoma
	Baie Botanique
	Baïja
	Bailys & Harding
	Bain de terre
	Baiobay
	Bakanasan
	Balade en Provence
	Balance Me
	Balaruc les Bains
	BalbPharm
	Baldessarini
	Balea
	Balea
	Balea-med
	Balea-men
	Balenciaga
	Bali Body
	Ballot-Flurin
	Balm Balm
	Balmain
	Balmi
	Balmology
	Balmshell
	Balneum
	Balzac Paris
	Bambino Mio
	Bamboo Edition
	Bamford
	Banana Boat
	Banila co.
	Baobab Collection
	Baraboucle
	Baratti
	Barbara Gould
	Barbara Hofmann
	Barbe Saine
	Barberino’s
	Barcino Naturals
	bareMinerals
	Barnangen
	Barnängen
	Barr-Co.
	Basic Essentiel
	Basler
	Basq
	Bastide Aix en Provence
	Bath & Body Works
	Bath Bubble and Beyond
	Batiste
	Batiste Shampooing Sec
	Baume & Sens
	Baume du Hibou
	Bausch + Lomb
	BaviPhat
	Baxter of California
	Bayer
	Baylis and Harding
	Bdellium Tools
	bdk Parfums
	Be + Radiance
	Be Creative Make Up
	Be My Oil
	Be Relax
	Be you by Electro Dépôt
	be’Cup
	Béaba
	Bear Fruits
	Beardilizer
	beaudy.
	Beautanicae
	Beauté Insolente
	Beauté Médina
	Beauté Mediterranea
	Beauté Océane
	Beauté Pacifique
	Beauté Simple
	BeautéLive
	Beauteprivée
	BeauTerra
	Beautical
	Beautiful Curls
	Beautiful Finger
	beautigloo
	Beautilicious
	Beautiss
	beauty 360
	Beauty by Clinica Ivo Pitanguy
	Beauty Garden
	Beauty Glazed
	Beauty of Joseon
	Beauty Protector
	Beauty Star
	Beauty Success
	Beauty Uk
	Beautybird
	Beautyblender
	BeautyMix
	BeautyNails BNA
	BeautyPro
	Bebe More
	Bébé Racaille
	Bebe Young Care
	Bébisol
	BeChocolate
	BeconfiDent
	BeCosE
	Bee Cee
	Bee Good
	Bee Natural
	Bee Nature
	BeeKind
	beesline
	BeFine
	Beginning by Maclaren
	Beiersdorf
	Bel Nature
	Bel Premium
	BelDam
	BELEI
	Belengaia
	Belesa
	Bélice
	belif
	Beliflor
	Bell
	Bell'Ânesse en Provence
	Bella Aurora
	Bella Vita Body
	bellapierre Cosmetics
	Belle & Bio
	Belle France G20
	Belle's Secrets
	Bellecore
	belles soeurs
	Bellflower
	Belmacz
	Belweder
	Bemed
	Ben & Anna
	Ben Nye
	Benamôr
	Benchaâbane Parfumeur
	benecos
	benefit
	Benjabelle
	Benjamin Bernard's
	Benostan
	Bentley
	Bentley Organic
	Benton
	Benu Blanc
	BeO
	BePacifique
	Bepanthen
	BepanthenDerma
	Beppy
	Bérangé
	Berdoues
	bérine
	Bernard Cassière
	Bernard Jensen
	Berocca
	Berrisom
	Betty Barclay
	Betty Dain
	Betty's
	beurer
	Beyoncé
	Beyond
	BeYu
	bhcosmetics
	Bi Mât Cây
	Bi-Oil
	Biactol - Clearasil
	Biafine
	BIC
	Bielenda
	Bien et Bio
	Bien Vu - Magasins U
	Bien-être
	Bienaimé
	Big Boy
	Biguine
	Bijin
	Bijoux Indiscrets
	Bilou
	Bio 33
	Bio Atlantic
	bio BELLE
	Bio Bretagne Océan
	Bio Colloïdal
	Bio Formule
	Bio Glam Chic
	Bio Logica
	Bio Logical
	Bio Neuf
	Bio Planète
	Bio Sculpture Gel
	Bio Seasons
	Bio Secure
	Bio-Kult
	Bio-naia
	Bio-Recherche Laboratoires Paris
	Bio-Taches
	Bio:Végane SkinFood
	BioAqua
	BioBela
	biobrush berlin
	BioCarnac
	Biocoiff
	BioConcept
	biocoop
	Biocura
	Biocyte
	Bioderma
	Bioderma
	Biodroga
	BioEarth
	Bioeffect
	Biofficina Toscana
	Biofloral
	Bioflore
	Bioforet
	Biofreeze
	BioGaia
	BioGalene
	Biogaran
	Biogénie Beauté Concept
	BioKap
	Biokarité
	Biokos
	Biokosma
	Biolage de Matrix
	Biolane
	Biolane
	Biolissime
	Biolo
	Biologist Mood
	Biom
	Biomd
	biomed
	Bion
	Bionatural
	BioNike
	bioniva
	Biopha
	biopha nature
	Biophase
	Biophytum
	Biopur
	Bioré
	bioregena
	Bioreline
	Biorène
	Biorga
	Biorgane
	BiOrigine
	Biosalines
	Biosens
	bioseptyl
	Biosilk
	Biosince 1975
	BIOSME
	Biosmose
	BioSolis
	Biossane
	BioStop
	Biotanicus
	Biotanie
	Biotechnie
	Bioteeth
	biothalys
	Biotherm
	Biotherm
	BioticPhocea
	Biotics research
	Biotona
	Biotope des Montagnes
	Biotulin
	Bioturm
	BIOTYfull Box
	Biovéa
	Bioveillance
	biover
	Biovisol
	BioVit'am
	Biovive
	Bioxet
	Bioxidea
	Bioxsine
	Birdie
	Bivouak
	Björk & Berries
	Black Chicken Remedies
	Black Earth
	Black Forest Spa
	Black Head
	Black Opal
	black'Up
	Blackhead Killer
	blancrème
	Bleach London
	Blend-a-med
	Blendandplay
	Bleu d'Argens
	Bleu Kelsch
	bleu&marine Bretania
	BleuJaune en Provence
	Blinc
	Bling Cosmétiques
	BLINX
	Bliss
	Blissim
	Blistex
	Blithe
	Blondépil
	Bloom
	Blooming
	bloomy
	Bloon
	Blossom Jeju
	blue Skincare
	Blusche Minerals
	Blüte-Zeit
	BM Beauty
	BO Paris
	bo.ho Green
	Bobbi Brown
	Bobeam
	Bocoton
	BODHEA
	Bodhi & Birch
	Bodia Nature
	body & earth
	Body America
	Body Boom
	Body Drench
	body nature
	Body Respect
	BodyBlendz
	Bodyguard
	bodyminute
	Bodysol
	Boèmia
	Boiron
	Boiron
	Bois 1920
	Boland
	Bold Uniq
	Bomb Cosmetics
	Bon Parfumeur
	Bonanza Paris
	bondi sands.
	Boni sélection
	Bonjolie
	Bonne Bell
	Bonpoint
	Boo+
	Boots Laboratories
	Borghese
	Born to Bio
	Borotalco
	Borsari Spa
	Boscia
	Bôstick
	BOTAK
	Botan
	Botanic
	Botanics
	Botanicus
	Botanifique
	Botarin
	boté
	Boticinal Laboratoire
	Botlux
	Botot
	Bottega Veneta
	Bottega Verde
	Bouchara
	Boucheron
	Bouclème
	Boud'Soie Cosmétiques
	Bougies la Française
	Boulado
	Bourjois
	Bourjois
	Bout'Chou - Monoprix
	Boutique Nature
	Branded J Collections
	Braun
	Brave. New. Hair.
	Bravura
	breakout+aid
	BreastActives
	Breath Palette
	Brecourt
	Brenda Anvari
	Briochin
	Briochin
	Briogeo
	Brioni
	Britanie
	Britney Spears
	Brivon
	Bronx Colors
	Bronz'Express
	BRTC
	Bruno Banani
	brushworks
	Brut
	Brut
	BSoul
	bubble t
	Bubbles & Creams
	Bübchen
	Buccotherm
	Buddha Nose
	Buds
	Buds Organic
	Buff'd
	Bugatti
	Bulgari
	Bulldog Skincare For Men
	Bumble and Bumble
	bumGenius
	Buoceans
	Burberry
	Burdin
	Burt's Bees
	BustiCare
	Butter London
	Buxom
	BWC Beauty without cruelty
	By Anne P.
	By Beauty Bay
	By Dariia Day
	By Kazumi
	By Kilian
	By Paolo Gigly
	By Rosie Jane
	By So'Bulles
	By Terry
	By U - Magasins U
	By Vilain
	By Wishtrend
	By-u
	BYBI
	Bye Bye Nits
	Byly
	Byo Protec'Derm
	BYOMA
	Byphasse
	Byphasse
	Byrd
	Byredo
	Bys
	C
	C Products
	C. de Farme
	C.Lavie
	C.line.B
	C.O. Bigelow
	C'Clean
	C'est Moi Qui L’Ai Fait
	C20 O.S.T
	cacharel
	Caditar
	Cadiveu
	Cadonett Dop
	Cadum
	Cadum
	Caked
	calia
	Câline
	Câlinesse
	Callibelle
	Calliderm
	Calmosine
	Calor
	Calvin Klein
	Camaïeu
	Camille Albane
	Camille Florès
	Camille Rose Naturals
	Campos de Ibiza
	Camylle
	Candès
	Candle-Lite
	Candy Crush
	Cane + Austin
	Canmake
	cantu
	Caolion
	Cap Cosmetics
	Capace Exclusive
	Capiderma Canada
	Capil'liss
	Capillor
	Capilys
	Capiplante
	Capirelax
	Capitaine
	Capricia
	Caprina par Canus
	Cara
	Care Nature
	Caribbean Bronze
	Caribbean Joe
	Carita
	Carlo di Roma
	Carlotha Ray
	Carmex
	Carole Daver
	Carole Franck
	Carolina Herrera
	Carolina-B
	Caron
	Carrare
	Carrefour
	Carrement Belle
	Carryboo
	Carthusia
	Cartier
	Carven
	Casa d'Argane
	Casa Lopez
	Casa Nature
	Casa Zeta-Jones
	Casanera
	Casino
	Casmara
	Castelbajac
	Castera
	Cath Kidston
	Cathy Guetta
	catrice
	Cattier
	Cattier
	Caudalie
	Caudalie
	Cavaillès
	CB12
	CD
	CD
	Cd
	Ce'Bio
	Cebelia
	celestetic.
	Célia Beauté
	cell'innov
	CELLBN
	Cellcosmet
	Cellex-C
	CelliFlore
	Celluless MD
	Celluli 21
	Celtic bio
	Centaure Professional
	Centella
	Centifolia
	Centifolia
	Centrum
	CeraVe
	Cerave
	Céréal
	Ceremonia
	Cerises de Mars
	Cerro Qreen
	Cerruti
	Cetaphil
	Chabaud Maison de Parfum
	Champs de Provence
	Chandrika
	Chanel
	Chanel
	Chantal Lacroix par Misencil
	Chantal Thomass
	Chantecaille
	Chantelle
	Chanvria
	Chaps
	ChapStick
	Chapter
	Charles Jourdan
	Charles Worthington
	Charlotte Baby Bio
	Charlotte Bio
	Charlotte Tilbury
	Charme d'Orient
	Charme du Maroc
	Charmzone
	Charrier Parfums
	Charriol
	Château Berger Cosmétiques
	Chaugan
	Chemins d'Afrique
	Chemins d'Asie
	Chemins d'Orient
	Chemins de Provence
	Chemins des Iles
	Chemins des Vignes
	Chemins du Nil
	Chen Yu
	Chenot
	Chevalait
	Chevignon Parfums
	CHI
	Chiaro
	Chic & Nature
	chic des savons
	Chica Y Chico
	Chicco
	Chillsilk
	China Glaze
	Chloé
	Cho Nature
	Chopard
	Christèle Jacquemin
	Christian Audigier
	Christian Breton
	Christian Lenart
	Christian Louboutin
	Christina Aguilera
	Christine Arbel
	Christofle
	Christophe Robin
	christophe-nicolas biot
	Chupa Chups
	Ciaté
	Cicaleïne
	CicaManuka
	Cicatridina
	Cicatridine
	Cidem Cosmetics Paris
	Ciel d'Azur
	Cien
	Cigale Bio
	Cilaos
	Cîme
	Cinq Mondes
	Cinq sur Cinq
	Ciracle
	Circles
	Cirque
	CitroBiotic
	CitroPlus
	City Color Cosmetics
	CityPharma
	Claire's
	Clairjoie
	Clairol
	Clara en Provence
	Clarange
	Clarena
	Clarins
	Clarins
	Claripharm Laboratoire
	ClaRose
	Claude Galien
	Claus Porto
	clayeux
	Clayspray
	CLE
	clé de peau Beauté
	Clé des Champs
	Clean
	Clean & Clear
	Clean Hugs
	Cléancia
	Clear
	Clearasil
	ClearChoice
	ClémaScience
	Clematis
	Clémence & Vivien
	Cléopatra
	Clever Beauty
	Clic & Go
	Clinerience
	ClinicCare
	Clinique
	Clinique
	Clinomint
	Clio Blue
	Clipper
	Cliptol Sport
	Close Brussels
	Cloud 10 Customized Hair Care
	Clove + Hallow
	Club Parfum
	Cmd naturkosmetik
	CND
	COACH
	Coastal Scents
	Coco & Eve
	Cococare
	Coconut Care
	cocosolis
	Cocunat
	Codage
	Codex Labs
	Codexial
	Codifra Laboratoire
	Codina
	COELHO
	Coeur de Cigale
	Coiff&Co Professionnel
	Coiffance
	Coiffeo
	Coiffirst
	CoinMakeup
	cokoon
	Colab
	Colbert MD
	Colgate
	Colgate
	Colgate-palmolive
	Collagena
	Collagène M5
	Collection
	Collines de Provence
	Collistar
	Collosol
	Color Club
	Color On
	Color Wow
	Colorade
	Coloré par Rodolphe
	Coloriage
	Colorii
	Colorisi
	ColourB4
	Coloured Raine
	ColourPop
	Combinal
	Comfort Zone
	Comme Avant
	Comme des Garçons
	Comodynes
	Compagnie de Provence
	Compagnie des Indes
	Compagnie des Sens
	Compeed
	Compex
	Completely Nuts
	Comptoir de Famille
	Comptoir des Huiles
	Comptoir des Monoï
	Comptoir des Savonniers
	Comptoir Sud Pacifique
	Comptoirs & Compagnies
	Comvita
	Concept Provence
	Condensé
	CondoZone
	Confiança
	Connock London
	Cookies Make up
	Coola
	coop
	Cooper
	Cooper
	Copaïba
	Copines Line
	Coquillete Paris
	Cora
	Core
	Corème Paris
	Corine de Farme
	Corine-de-farme
	Corinne Costa Cosmétiques
	Corioliss
	Cory Cosmetics
	CoryMer
	Coryse Salomé
	Cos De BAHA
	Cos Line
	Cosbelle
	Coslys
	Coslys
	Cosmé Nail
	Cosmea
	Cosmecology
	Cosmelys
	Cosmépro
	Cosmer
	cosmesana
	Cosmésoins
	Cosmetane
	Cosmetics 27
	Cosmetics à la carte
	Cosmétiques d'Orient
	Cosmetisy
	Cosmia
	Cosmia
	Cosmia-baby
	Cosmia-bio
	Cosmigea
	Cosminia
	cosmo naturel
	Cosmo Skin Solutions
	Cosmo-naturel
	Cosmod
	Cosmolia
	Cosmopolitan
	Cosmoz
	Cosmydor
	Cosrx
	Costa Brazil
	Costes
	Costume National
	Cotonet
	Cottage
	Cottage
	Cotton100
	Coui Skincare
	COULEUR CARAMEL
	Couleurs Gaïa
	Country Life
	Coup d'éclat
	Courrèges
	Coutiver
	Couture Colour
	Cover FX
	CoverGirl
	Covermark
	Cow Brand Soap
	Cowshed
	CoZie
	Crabtree & Evelyn
	Crayola beauty
	Crazy Color
	Crazy Rumors
	Créa Beauty
	créa cosmétique
	CreaClip
	Cream Moon Face
	Cream-ly
	Creed
	Creightons
	Creme of Nature
	Cremorlab
	Crescina
	Crest
	Cristaline
	Cristian Lay
	Cristophe
	Croll & Denecke
	Crown Pride Naturals
	Crystal Body Deodorant
	Cultiv
	curasano
	Cure
	Curél
	Curiosa
	Curl Harmony
	Curl Junkie
	Curls
	Curly Hair Solutions
	Curly Q’s
	CurrentBody
	Cut By Fred
	Cute Balms
	Cutex
	Cuticura
	Cuticura Cholayil
	CV Cadea Vera
	cyla
	Cynos
	Cynthia Rowley
	Cystera
	Cystiphane Biorga
	Cytolnat
	Cytosial
	D
	D-Lab Nutricosmetics
	D. R. Harris
	d.licious
	D.S. & Durga
	D'Adamo Genoma
	d'âme nature
	D'Orleac Professional
	d+ For Care
	Dabur
	Dadi'Oil
	Dado Sens
	Dafni
	Daggett & Ramsdell
	Daily Concepts
	Daily Defense
	Daliane
	Daniel Hechter
	Daniel Sandler
	Danièle de Winter
	Dans ma Culotte
	DAP Professional
	Darcy's botanicals
	Darphin
	David Beckham
	david lucas
	David Mallett
	Davidoff
	Davines
	Dawood and Tanner
	Day'O
	Dayang
	DayDry
	Daylily Paris
	Daylong
	Daynà
	Daytox
	dBb Remond
	DBE Diffusion
	De Blangy
	De Bruyère
	De Fabulous
	De Laurier
	De Mamiel
	de Marseille et d'ailleurs
	De Saint Hilaire
	de Saint Hubert
	De-Coy
	Dead Sea
	Dead Sea Premier
	Dear Dahlia
	Dear Rose
	dear, klairs
	Debby
	Deborah Milano
	Declaré
	Decléor
	DeClermont
	DéCramp
	Deeba
	Deenox
	Deep Nature
	Déesse
	Défi forme
	Défi pour Homme
	Degree
	Dekodacc
	Del Sol
	Delabarre
	Delarom
	Delbiase
	Delbôve
	Delhaize
	Delia Cosmetics
	Deliplus
	Delphine Courteille
	demain
	Demain Nature
	Demak'up
	DeMert
	Demeter
	Denblan
	Denis made in Tokyo
	Denivit
	Denman
	DeNovo
	Densmore Laboratoire
	Dentalux
	Dentamyl
	DentaPro
	Dentavie
	Deo
	Déovert
	Dergam
	Derm Eyes
	Derm-Ink
	Derma
	Derma Cosmetics
	derma e
	Derma Plantae
	Derma Stim
	Dermablend Professional
	Dermaceutic
	Dermachronic
	Dermacia
	Dermacia Brasil
	Dermacimes
	Dermaclay
	Dermaclay
	Dermacol
	Dermactive
	DERMAdoctor
	Dermadvanced
	Dermafutura
	Dermagor
	Dermalex
	Dermalia
	Dermalogica
	Dermaltitude
	DermaNew
	Dermapositive
	DermArgan
	Dermaroller
	DermaSel
	DermaSkin
	Dermatherm
	Dermatoline Cosmetic
	dermaWand
	Dermayon
	DermEden
	Dermexel
	Dermina
	DermoCaress
	DermoFluide
	DermoLab
	Dermophil
	DermoPlant
	DermoPro
	Dermorelle
	Dermorens
	Dermtec Color
	Des Filles à la Vanille
	Desensin
	Desert Essence
	Design Essentials
	Designers Guild
	Desigual
	Désinfectis
	Dessange
	Dessange
	Dessange Compétence Professionnelle
	Dessine Moi Un Savon
	Detaille
	Dettol
	Dettol
	DevaCurl
	Devezin Cosmetics
	DexSil Pharma
	DHC
	Diadermine
	Diadermine
	Diana Vreeland
	Diâne
	Diane von Furstenberg
	Dianne Brill
	Diatomea
	DiCorsica
	Didact Hair
	Diego Dalla Palma
	Diesel
	Diet Horizon
	Dietactiv
	Diétaroma
	Dieti Natura
	Dietox
	DietWorld
	Digital Scale
	DIJO
	Dim
	Diogène 1919
	Dioica
	Dior
	Dior
	Diptyque
	Direct Nature
	Dirt Candles
	Dirty Works
	Disciple
	Disney
	Distillerie Saint-Hilaire
	Dita von Teese
	Divacup
	Divain
	Divine
	Divinessences
	Djulicious
	dm
	Dmp Du monde à la Provence
	DN Unik
	Do You Love Me
	Docteur Renaud
	dodie
	Dolce & Gabbana
	Doliderm
	Doliva
	Dollania
	Dolmen
	Dolpic
	Domaine Biologique de Bressol
	Donna è
	Donna Karan
	Donna Marie
	Dontodent
	Doobaline
	Dop
	Dop
	Doucce
	Douce Nature
	Douce-nature
	Doucenuit
	Douces Angevines
	Douceur & Vitalité
	Douceur Cerise
	Douglas
	Doux Me
	Dove
	Dove
	Dr Botanicals
	Dr Brandt
	Dr Irena Eris
	Dr Jackson’s
	Dr Sam Bunting
	Dr Sebagh
	Dr Temt
	Dr Valnet
	Dr-hauschka
	Dr. Adam
	Dr. Alkaitis
	Dr. Barbara Sturm
	Dr. Bronner's
	Dr. Dennis Gross
	Dr. Hauschka
	Dr. Janka
	Dr. Jart+
	Dr. Jr.
	Dr. Lipp
	Dr. med. Christine Schrammek Kosmetik
	Dr. Miracle's
	Dr. Organic
	Dr. Pawpaw
	Dr. Roebuck's
	Dr. Roller
	Dr. Santé
	Dr. Scheller
	Dr. Severin
	Dr. Smith
	Dr. Theiss
	Dr. Van der Hoog
	Dr. Vranjes
	Dr.Ceuracle
	Dr.Different
	Dr.Konopka's
	Dr.Pierre Ricaud
	Drainaflex
	DreamHair
	Dresdner Essenz
	Dromessence
	Drs. Hans Schreuder
	Druide
	Drunk Elephant
	Druydès
	Drybar
	Dsquared²
	Ducastel Laboratoire
	Ducray
	Ducray
	Dunhill
	Duo LP-Pro
	Durance
	durex
	Durex
	Duri
	Duschdas
	dwtn paris
	Dynasil
	Dyson
	Dzintars
	E
	ê Shave
	E. Coudray
	e.l.f. cosmetics
	E45
	Eafit
	Earth Mama Angel Baby
	Earth to Skin
	Earth Tu Face
	Earth.Line
	Earth's Recipe
	Easy Body (Protein Program)
	Easy to Use
	EasyKeratin
	EasyParapharmacie
	Easypiercing
	Easytattoo
	Eau de Mars
	Eau des Carmes Boyer
	Eau Jeune
	Eau précieuse
	Eau Thermale Jonzac
	Eau Thermale Montbrun
	Eau-thermale-avene
	Ebelin
	éciat
	Eclado
	Eclaé
	ÉCLAT
	Éclosia
	Eco by Sonya Driver
	Eco Cosmetics
	Eco Lips
	Eco Styler
	Eco.kid
	ecodis
	Ecooking
	EcoTools
	Ecran Laboratoires Genesse
	Ecrinal
	Ecume d'Arcachon
	Eddie Funkhouser
	Edel + White
	Edelbio
	Edelstein
	Edelswiss
	Eden Park
	Eden's Semilla
	Edenens
	Edet
	Edible Beauty Australia
	Editeur : Josette Lyon
	Edition Hachette
	éditions 5 ml
	Editions Dangles
	Editions de Parfums Frédéric Malle
	Editions Eyrolles
	Editions Grancher
	Editions Larousse
	Editions Leduc
	Editions Odile Jacob
	Editions Ouest-France
	Editions Solar
	Editions Tribal
	Edward Bess
	Edwin Jagger
	Effadiane
	Effasun
	EffiDerm
	Effik
	Efibio
	Efidium
	efiseptyl
	Ego Facto
	Egyptian Magic
	EH Emma Hardie
	EI Solutions
	Eight and Bob
	Eisenberg
	ejove
	ekia
	Ekstrasens
	El Corte Inglés
	El Melaki
	El Nabil
	Elaimei
	Elancyl
	Elastoplast
	ELbbuB
	elcéa
	Elegant Touch
	Element-Terre
	Elemental Herbology
	Eléments
	Elemis
	Elenature
	Elephant
	Elesis
	Elevage de la Thudinie Lait de Jument
	Elevation 3196
	Eleven Australia
	Elfy Naturals
	Elgon
	Elgydium
	elia
	Elicey
	Elie Saab
	Eligarden
	Elikya Beauty
	Elina
	Elishacoy
	elissance
	Elite
	Elixâne
	Elixir 79
	Elixirs & Co
	Eliza Jones
	Elizabeth Arden
	Elizabeth Grant
	Elizabeth Taylor
	Elizavecca
	Ella Baché
	Ella K
	ella+mila
	Ellaro
	ELLE
	Ellen Betrix
	Ellepi
	Ellis Faas
	elmex
	Elmex
	elmt
	Elodie d'Astèle
	Elsamakeup
	Elseve
	elta md
	elvie
	Elyctia
	Elysium Spa
	EM2H Cosmetics
	Email diamant
	Emani Minerals
	Emanuel Ungaro
	Emblica
	Embryolisse
	Emerald Bay
	Emeraude
	Emile Noël
	Emilio Pucci
	éminence
	Eminence Organic Skin Care
	Emite Make Up
	Emma Noël
	Emmanuel Levain
	Emmi-dent
	Emoform
	Emu Gold
	EmuCare
	En Douce Heure
	endro
	Eneomey
	Energie Fruit
	Energie-fruit
	Enfance Paris
	Engadyne
	Enissa
	EnjoyTEA
	Enliven
	Ennoïa
	ENO by Codexial
	Ensaya
	EnVie Intercosmetics
	Environ
	Envision
	Enzymatic Therapy
	Eolesens
	Eona
	eono
	eos
	Eostra
	Epicosm
	Epicuren
	Epitact
	Epithélium
	Epycure
	Equalya
	Equatoria
	Equi-Nutri
	Equiderma
	Equilac
	ErbaLab
	ErbaOrganics
	erborian
	Ere Perez
	Eric Favre
	Eric Stipa
	Ericson Laboratoire
	Ermenegildo Zegna
	Erno Laszlo
	Ernst Richter's
	eSalon
	Escada
	Escale au Pays des ânes
	Escofine
	Esdor
	esenka
	Esis
	eskalia
	Eskandar
	Eskinol
	Esprit
	Esprit Phyto
	Esquiderm
	Esquisse
	Ess
	essena
	essence
	Essence
	Essence of Eden
	Essenciagua
	Essenka
	Essensity by Schwarzkopf Professional
	Essential Care
	Essential Parfums
	essentiel b - boulanger
	Essentiel Eugène Perma Professionnel
	Essie
	Essie
	Essilac
	Esslux
	Esteban
	Estée Lauder
	estelle & thild
	Estelle Laborde Provence
	estheo
	esthética pure-nature
	Estime & Sens
	Estipharm
	Estrid
	et alors
	Etamine du Lys
	Etat Libre d'Orange
	Etat Pur
	ETC.
	Étern'L
	Eternelle
	Ethiquable
	ethique
	Ethnicia
	Ethnocosmetics
	Ethnodyne
	Etiaxil
	Etienne Aigner
	Etival Laboratoire
	Etnas
	ETNIA
	ETNIK
	être belle cosmetics
	Etro
	ETRONG
	Ets. Gayral
	Ettang
	Etude House
	Eubos
	Eucerin
	Eucerin
	Eugène Color
	Eugène Perma
	Eugène Perma 1919
	Eugène Perma Professionnel
	Eugene-perma
	Eugénie Prahy
	Eumadis
	Euoko
	Euphia
	Euramin
	Euro Sante Diffusion
	Europe Magic Wand
	Eurostil
	eva.nyc
	EvadéSens
	Evaflor
	Evalia Paris
	Evaux laboratoires
	Eve & Rose
	Eve Lom
	Eveline Cosmetics
	Ever Bio Cosmetics
	Evergreen
	Everwol
	Everyday Minerals
	Evian
	EviDens de Beauté
	Evo
	Evoa
	Evody
	evoleum
	Evoluderm
	Evoluderm
	EvoluPharm
	EvoluPlus
	Evolve
	Ex Nihilo
	Ex Voto
	excilor
	Excipial
	Exeko
	exertier
	Exfolderm
	Exo Keratin
	exosens
	Exp'r 1234
	Expanscience Laboratoires
	Experimental Perfume Club
	Express Color
	Express Solution
	exsens
	Extratissima Bio
	Extreme long lasting
	Eyden
	Eye Care
	Eye of Horus
	eyeko
	Eyesential
	Eyetex
	Eymard Gabrielle
	F
	Fa
	Fa
	FAB Factory
	Fab Feet
	Faberlic
	Fabio Salsa
	Fable & Mane
	Face Atelier
	Face Stockholm
	FaceD
	Facekult
	facetheory
	Facial Flex
	Facialderm
	Façonnable
	Fadiamone
	Fair Squared
	Faith in nature
	Fake Bake
	Famille & Co
	Famille Mary
	Family Bio
	Famivya
	Famous By Sue Moxley
	Fancl
	Fanola
	Fantasia
	Farevacare
	Farfacia
	Fariboles
	Farida b
	Farmacie
	Farmacy
	Farmasi
	FarmaVita
	Farmell
	Farsali
	Fashion Fair
	Fashion Lentilles
	Fashion Make-Up
	Fashion professional
	Fasteesh
	Fauchon
	Fauvert Professionnel
	Favre Cosmetics
	Fay
	fcuk
	Fear Hunters
	Febreze
	Feedyo' Hungry Hair
	Feel Free
	Feel Natural
	Feeligold
	Fées en Provence
	feï Paris
	Fekkai
	Felce Azzurra
	femfresh
	Femibion
	Fémilyane
	Femme Fatale
	Fempo
	Fendi
	Fenjal
	Fenty Beauty
	Fenty Hair
	Fenty Skin
	Fer à Cheval
	Féraud
	Feret Parfumeur
	Ferity
	Ferme de Gorge
	Ferme de la Comogne
	Ferme de Saussac
	Ferrari
	FG Cosmétique
	Fibao
	Fiberwig
	Figenzi
	Figs & Rouge
	FiiLiT Parfum du Voyage
	Filles des Iles
	Fillmed Laboratoires
	Filosofille
	find.
	Fine Perfumery
	Finishing Touch Flawless
	Fiori.
	First Aid Beauty
	First Editions
	Fitglow Beauty
	Fitne
	Fitness Zone
	Fitocose
	Fitoform
	Fittea
	Fixodent
	FKare
	Flamant Vert
	Flammarion
	Fleur's
	Fleurance Nature
	Fleurcup
	Fleurs de Bach
	Flora Amazonia
	Floraïku
	floral street
	Florame
	Florame
	Floratropia
	Flore Alpes
	Florémine
	Florena
	Florena Fermented Skincare
	florence by mills
	Florence organics
	Floressance
	Florêve Paris
	Florihana
	Floris
	Flormar
	Flower
	Flower Spice
	Floxia
	Fluocaril
	Fluocaril
	Fluoflor
	Fluomax
	Fluoryl
	Folie à Plusieurs
	Folies Royales
	Foligain
	Follement Bio
	Fontelia
	Food a Holic
	Footsteps
	For-women
	Foreo
	Forest Essentials
	Forever Living Products
	FormaDerm
	Formes & Flammes
	Formula 10.0.6
	Formula X
	Formule beauté
	Fornasetti
	Forster's Natural Products
	Forté Pharma
	Forvil
	Fossil
	Foucaud
	Fountain
	Fountain
	Fouquet's Paris
	Fourth Ray Beauty
	Fragonard
	Fragonard
	France Loisirs
	Frances Denney
	Franck Olivier
	Franck Provost
	Franck-provost
	François Nature
	Françoise Morice
	Frank
	frank body
	franprix
	Frau Tonis Parfum
	Fräulein 3°8
	Fräulein3°8
	Frazer Parfum
	Frederic M
	Freedge Beauty
	Freedom Makeup London
	Freeman
	Frescoryl
	Fresh
	Fresh Therapies
	Freshéa
	Freshly Cosmetics
	Fressi'Mouss
	FreyWille
	FrezyDerm
	Fructis
	Fructivia
	Fruit Forever
	Frulatte
	Frutique
	Fun Factory
	Fun'Ethic
	Funny Bee
	Funtime Beauty
	Furterer
	Fusion Beauty
	Futurcosmetic
	Fytofontana Cosmeceuticals
	G
	g-synergie
	G.U.M
	G&H
	Gabriel Color
	Gabriel Couzian
	Gadi 21 Minerals
	Gaiia
	Gaïna
	Galderma
	Galenco
	Galénic
	Galeries Lafayette
	Galimard
	Gallia
	Gallica Natura
	gallinée
	GamARde
	Gamila Secret
	Gandhour
	Gap
	Gapscent
	Garancia
	Garden of Wisdom for Victoria Health
	Garnier
	Garnier
	Garnier Bio
	Garnier-fructis
	Garnier-skinactive
	Gas Bijoux
	Gatineau
	Gavisconell
	Gaya
	Gayelord Hauser
	Geek & Gorgeous
	Gehwol
	Gelish
	Gellé Frères
	Gemelline
	Gemey-Maybelline
	Gemey-maybelline
	Gen-Ongles
	Gencix
	GeneRik
	Gentleman's Brand Co.
	Geoderm
	Geoffrey Beene
	Geomar
	Georganic
	Georges Rech
	Georges Stahl
	Gerblé
	Gerda Spillmann
	Gerlinéa
	Germaine de Capuccini
	GERnétic
	GESKE
	Gestarelle
	ghd
	Ghost
	Giambertone
	GiFi
	Gifrer
	GiGi
	Gilbert Laboratoires
	Gillette
	Gillette
	Ginkor
	Giorgio Armani
	Giorgio Armani beauty
	Giorgio Beverly Hills
	Giovanni
	Girl Smells
	Girlies Cup
	Girlz Only Haircare
	Gisèle Delorme
	gisou
	Givenchy
	GKhair
	glade
	Glam Brush
	Glam Hours
	GlamGlow
	Glamour Paris
	Glamza
	Glee
	Gleeden
	Gli Elementi
	Glime
	GliSODin
	Global Beauty
	Global Keratin
	Global Relax
	Gloria Vanderbilt
	Gloss
	Glossier.
	GLOSSYBOX
	Glov
	Glow Lab
	Glow Recipe
	GlowCup
	glowery
	Glowria
	GlySkinCare
	Go & Home
	Go be lovely
	Go Get Glitter
	Go Pretty
	Goa
	Godet
	Godrej
	Gold 48K
	Goldarome
	Golden Rose
	Goldfaden MD
	Goldies
	Goldwell
	goodal
	GoodSkin Labs
	Gorgée de Soleil
	Gorgona
	Gosh
	Gotta Love Nature
	Goutal Paris
	GPH Diffusion
	GR HealthCare
	Grace & Stella
	Grace Your Face
	Graine d'Orient
	Graine de Pastel
	Graine Sauvage
	Granado
	Grand Jury
	Grand Océan
	Grande Cosmetics
	Grandpa's
	Grangettes Genève
	Granions
	Grasse au parfum
	Grassroots
	Gratiae
	Green & Spring
	Green Barbès
	Green Beaver
	Green Gaia
	Green is better
	green keratin
	Green Light
	Green People
	Green Pharmacy
	Green Skincare
	Greenfrog Botanic
	Greenland
	Greensations
	Grégory Ferrié
	Gressa Skin
	Grim'tout
	GRN shades of nature
	Ground Soap
	Grow Gorgeous
	Grüv
	Gsk
	Guam
	Guayapi Tropical
	Gucci
	Guêpes & Papillons
	Guérande
	Guerlain
	Guerlain
	Guess
	Guhl
	Guinot
	Gum
	Gutto Natural
	Guy Laroche
	Gyada Cosmetics
	Gydrelle
	Gynedex laboratoires
	H
	H is for love
	H. Company
	H.Q Qualité Suisse
	H&M
	H2O at Home
	HADA
	Hada Labo Tokyo
	HadaLabo
	Hadali
	Hadamaru
	Hair 30
	Hair Go Straight
	Hair Science
	HairBurst
	hairfax
	Hairfinity
	Hairgum
	Hairissime
	HairLisse
	Hairlust
	HairMaker
	Hairmed
	Hairveda
	Hakansson
	Hakawerk
	Halia
	Halita
	Han Nari
	HAN Skincare Cosmetics
	Hanae Mori
	Hand San
	Hands On Veggies
	hanf natur
	Hansaplast
	Happy Cosmetics
	happybrush
	HapsatouSy
	Harajuku Lovers
	Hard Candy
	Harem des sens
	Hartmann
	haruharu wonder
	Harvest 10.
	Hashmi Surma
	Hask
	Haus Labs by Lady Gaga
	Haute Cosmetic
	Hawaiian Silky
	Hawaiian Tropic
	Hayaseï
	HBC One
	He-Shi
	Head & Shoulders
	Head-shoulders
	HealGel
	Health & Beauty
	Hean
	Heeley
	Hégor
	Hegron
	Hei Poa
	heimish
	Heïva
	Helena de Flussange
	Helena Rubinstein
	Hélénère
	HeLhem
	Héliabrine
	Heliocare
	HeliOnature
	hello JO
	Hello Nature
	HelloBody
	Helmut Lang
	Héloïse
	Héloïse De V.
	Heloria
	Helvance
	Helvetia Natura
	HEM
	Hema
	Hemani
	Hemp Phytomedical
	hemp+
	hemp4help
	Henkel
	Henné Color
	Henné Organics
	Henné Sahara Tazarine
	Hennédrog
	Henrik Vibskov
	Herb & Bløm
	Herba Helvetica
	Herbacin
	Herbagen
	Herbagénèse
	Herbal Essences
	Herbal Essentials
	Herbal Face Food
	Herbal Nature
	Herbal-essences
	HerbalGem
	Herbalife
	Herbamedicus
	Herbamix
	Herbatint
	Herbaviva
	Herbes et Sens Arômes
	Herbes et Traditions
	Herbesan
	Herbier de Provence
	Herbiolys Laboratoire
	Herbivore
	Herborist
	Heritage Store
	Hermès
	Hero.
	Hérôme
	Hershesons
	Hervé Gambs
	Hervé Herau
	Hervé Léger
	Hesh Herbal
	Hesh Pharma
	Heuliad
	Hévéa
	Hevendi
	Hexamer
	hic et nunk
	Hierbas de Ibiza
	Himalaya
	Hip
	Hip Peas
	Hipertin
	Hipp
	hismile
	Histoires de Parfums
	Historiae
	Hitton
	HL Haras de la Vienne
	Ho Karan
	Hohonua
	Holidermie
	Holika Holika
	Hollister
	HollywoodSkin
	Holt Renfrew
	Holy Lama
	Home Skin Lab
	HoMedics
	Homéocaryl
	Homeopharma
	HoméOsoin
	Honest Beauty
	Honestly pHresh
	Honeybee Gardens
	Honma Professional
	Honoré des Prés
	Honoré Payan
	Honua Skincare
	Hopscotch Kids
	Horace
	Hormeta
	HorseBall
	Horus Pharma
	Houbigant
	Hourglass
	House 99
	House of Sillage
	HTM Exclusive Cosmetics
	huages
	Hübner
	Huda Beauty
	Huggies
	Huggies
	Hugo Boss
	Hugo Naturals
	Hugo&Cie Editions
	Huile des Princesses
	Huiles & Baumes
	Huiles & Sens
	human+kind
	Humer
	Humiecki & Graef
	Hurraw
	Huyana
	Huygens
	Hyacos
	Hyaluronic XT
	HydraFlore
	Hydralane
	Hydralin
	Hydriska
	Hydroface
	Hydrophil
	Hydroxydase
	hydroxyderm
	Hyfac
	Hygée
	Hygios
	Hynt Beauty
	I
	I am - Migros
	i love BIO by Léa Nature
	I und M
	I-am
	I.C.O.N.
	I.D. Swiss Botanicals
	I’Liss
	I'm Free
	I'm from
	I'M MEME
	ialugen Advance
	IBA
	iba Halal Care
	Ibbeo Cosmétiques
	IBY Beauty
	Iceberg
	Icona Milano
	Iconic London
	ID Italian Design
	ID Parfums
	Idalmi St Barth
	IDC
	IDC Colors
	IDC Institute
	Idecap
	Idenov Laboratoire
	identik
	Idol White
	iéo
	IGK
	Igräne Cosmetics
	IKEA
	IKI Naturals
	IKKS
	ikoo
	Ikove
	Il Profumo
	Ilcsi
	Ilia
	Illamasqua
	Illiyoon
	Illume
	ILuxe
	Imagic Paris
	Imagic Pro
	Iman
	Imiza
	Imju
	Immun'Âge
	imparfaite*
	Imperial Leather
	Imperio Lusso Italy
	Implan
	Impulse
	Imwe
	In Fiore
	in Haircare
	Inava
	INC.redible
	Inca Oil
	Incanto
	IncaRose
	Incoco
	Incognito
	Indemne
	Indie Lee
	Indola
	Indult
	Inebios Laboratoires
	Inebrya
	inecto
	Ineffable Care
	Ineke
	Ineldea Santé Naturelle
	Inell
	Inessance
	Infiniment Vous
	InflammAge
	infuse My. colour
	Infuz
	Inglot
	Ingrid Cosmetics
	Ingrid Millet
	Inika
	Inizmé
	Inka Paris
	Inlight
	Innéis
	innisfree
	Innoderm Laboratoire
	Innossence
	Innovatouch Cosmetic
	innovit
	Innoxa
	Inoar
	Inokeratin
	Inopia Cosmétique
	InOya
	InSati
	Insect Ecran
	Inside and Out
	InstaNatural
	Institut Claude Bell
	Institut Esthederm
	Institut Karité
	Institut Phyto
	Instituto Español
	Instituto-espanol
	Integral Beauty
	Integral-8
	Intensae
	Intermarché - Apta
	Intermarché - Cotterley
	Intermarché - Pommette
	Intermarché - Top Budget
	Intermarché - Via
	Intermède Professionnel
	intibiome
	Intima
	Intima Gyn'expert
	Intimy
	Intrait Marron d'Inde
	inuwet
	Invisibobble
	ioma
	IOTA
	Ipheos
	IQQU
	Irén Shizen
	Irene Forte
	Irié
	Irisé Paris
	Iroha Nature
	Iroisie
	Isabel
	Isabelle Lancray
	Isabelle Laurier
	Isabey
	Isana
	Isdin
	Ishizawa
	IsisPharma
	ISkin
	Islandbeauty
	Isle of Paradise
	Isntree
	Isopouce
	isoxan
	Issahra
	Issey Miyake
	ISUN
	It Cosmetics
	It Works
	It's A Curl
	It's Skin
	Item Dermatologie
	ItStyle
	iUNIK
	Ivatherm
	IVY AÏA
	Ixage
	Ixiene
	Ixxi
	J
	J.R. Liggett's
	J.U.S Parfums
	J'ai Lu
	J'aime mes dents !
	Jacadi
	Jack N'Jill
	Jacoglu
	Jacomo
	Jacques Bogart
	Jacques Fath
	Jacques Paltz
	Jacques Seban
	Jade Roller
	Jafra
	Jaguar
	Jamaican Mango & Lime
	Jamal
	Jamal Paris
	James Brown
	James Read
	Jamieson
	Jana Cosmetics
	Jane Carter Solution
	Jane de Busset
	jane iredale
	jane scrivner
	Janelle
	Janjira
	Janssen Cosmetics
	Jao Brand
	Japonesque
	Jardin Bio
	Jardin Bio étic
	Jardin Bohème
	Jardin d'Apothicaire
	Jardin d'even
	Jardin de France
	Jardin des Zen
	Jardins d'écrivains
	Jasön
	Jasper Conran
	Jay-Z
	JCD Laboratoires
	Je m'en lave les mains
	Je Suis Bio
	Jealous Body Scrub
	Jean & Len
	Jean Couturier
	Jean d'Avèze
	Jean d'Estrées
	Jean Desprez
	Jean Louis David
	Jean Louis David Urban Care
	Jean Louis Scherrer
	Jean Marc Joubert
	Jean Patou
	Jean Paul Gaultier
	Jean Peste
	jean-charles Brosseau
	Jeanne Arthes
	Jeanne d'Urfé
	Jeanne en Provence
	Jeanne M.
	Jeewin
	Jeffree Star Cosmetics
	Jeffrey James Botanicals
	Jemako
	Jemma Kidd
	Jennifer Lopez
	Jergens
	Jeroboam
	Jersey Shore Cosmetics
	Jessica
	Jessica Simpson
	Jessicurl
	JetSilk
	Jeune & Belle
	Jeunesse
	JewelCandle
	Jezabelle
	jho.
	Jigsaw
	Jil Sander
	Jill Stuart
	Jimmy Choo
	JJ Young by Caolion Lab
	Jo Hansford
	Jo Malone
	Jo Wood Organics
	joa au naturel
	JOD
	Joe Style Frais
	Johairba
	Johan Yvon
	John Frieda
	John Galliano
	John Masters Organics
	John Varvatos
	John-frieda
	Johnny Concert
	Johnny's Chop Shop
	Johnson
	Johnson-johnson
	Johnson's
	Joico
	Join The Organic Future
	Jolen
	Joli'Essence
	Joliderm
	jolly
	Jolse
	Jones Road
	Jonzac
	Joone
	Joop !
	Jordan Samuel Skin
	Jordana
	Joséphine
	Joséphine Baker
	Josh Rosebrook
	Josiane Laure
	Josie Maran
	Josy's Doolè
	Jouer Cosmetics
	JOUR1
	Jouvence
	Jouvence de L'Abbé Soury
	Jouviance
	Jovan
	Joveda
	Jovees
	Jovoy Paris
	Jowaé
	Joyce
	Joyia
	Juara
	Judith Williams Cosmetics
	Judydoll
	Juice Beauty
	Juicy Couture
	Juju Cosmetics
	Jul et Mad
	Juliette has a gun
	Julisis
	Julliana D.
	June Jacobs
	Juni
	Jurlique
	Just
	Just For Men
	Justin Bieber
	JuvABio
	Juvaflorine
	Juvamine
	Juvel-5
	Juvia's Place
	JYB
	Jylor
	Jyta Cosmetic
	K
	K Derm
	K pour Karité
	K-Glo
	K-Link
	K-Max
	K-whole
	K.PiloTrac.T
	K18
	Kadalys
	Kaël
	Kaeso
	Kahina Giving Beauty
	Kahuna Benessere
	Kai
	Kairly Paris
	Kaita
	Kajame
	Kalavy
	Kaliom
	Kalip'tus
	Kalo Nero
	Kalys
	Kama Ayurveda
	KanaBeach
	Kanamour
	Kanellia
	Kani
	Kannaway
	Kanopé
	Kaolina
	Kaoma marque LM
	Kapa Reynolds
	Karandja
	Karawan
	Kardashian Beauty
	Karen Murrell
	Karethic
	Kari Derme
	Kariderm
	Kariline-Look’N Relax
	Karin Herzog
	Karinature
	Karine Joncas
	Karl Lagerfeld
	Karmameju
	Karop's
	Kart Laboratoires
	karuna
	Kat Burki
	Kate Moss
	Kate Somerville
	kate spade
	Kate Tokyo
	Katima'A
	Kativa
	Katy Perry
	Kaviaar Kare
	kaya
	Kayali
	kazidomi
	kear
	Kedem
	Kedma
	Keims
	Kela
	Kelémata
	Kelo-cote
	Kemon
	Kemsia
	KenMen
	Kenneth Cole
	Kent.
	Kenzo
	Kenzoki
	Kera Queen's
	KeraCare
	Kerali
	Keraline
	Keralong
	Kerâlto
	Keranove
	Kéranove
	Kerargan
	KerarganiC
	Kéraskin Esthetics
	Kerasoin
	Kerastase
	Kérastase
	Keratin Classic
	Keratin Fusion
	Keratop
	Kerazina
	Kerline
	Kerzon
	Kesari
	Keshmara
	Kester Black
	Ketish
	Keune
	Kevin.Murphy
	Kevyn Aucoin
	Keys Soulcare
	khadi
	Khadija
	Kiabi
	Kidna'poux
	Kiehl-s
	Kiehl's
	Kikilash
	Kiko
	KIKO Milano
	Kim Kardashian
	KimChi Chic Beauty
	Kin Cosmetics
	Kinaiia
	Kinara
	Kinésoins
	KING
	King C. Gillette
	Kings & Queens
	Kinky-Curly
	Kiotis - Stanhome
	Kisby
	Kiss
	Kiss my Face
	Kiss New York Professional
	Kisupu
	kitsch
	kivvi
	Kiwiibio
	Kjaer Weis
	Klapp
	Kleancolor
	Kleem Organics
	Kleenex
	Klorane
	Klorane
	Klytia
	kms California
	KmS Mineral Essentials
	Kneipp
	KOBA
	Kocostar
	Kokwaï
	Komaza Care
	Komoé
	Konad
	Kongy
	Kontrol
	Kora Organics
	Korento
	Korloff
	Körner Skincare
	Korres
	Kos Paris
	Kosas
	kosbiotic
	Kosé
	Kost Kamm
	Kotex
	Kotor Pharma
	Kovelia
	Kozmetics
	KraveBeauty
	krème
	Kricri Nature
	Krigler
	Krishna Thulasi Cholayil
	Kristin Ess
	Kruidvat
	Kryolan
	KTC
	Kuan Yuan Lian
	Kujten
	Kumano
	KumKuat
	Kuomayé Bio
	Kure Bazaar
	Kusmi Tea
	KVD Beauty
	Kydra by Phyto
	Kylie by Kylie Jenner
	Kylie Minogue
	Kypris
	L
	L Plaisir Féminin
	L-arbre-vert
	L-occitane
	L-occitane-en-provence
	L-oreal
	L-oreal-men-expert
	L-oreal-paris
	L-oreal-professionnel
	L:A Bruket
	L.A. Colors
	L.A. Girl
	L.A. Pince
	L.C.P
	L.T. Piver
	L'Abeille 1730
	L'Accent
	L'Action Paris
	L'Ane des collines
	L'Anza
	L'Arbre Vert
	L'Artisan barbier brossier
	L'Artisan Parfumeur
	L'Artisan Savonnier
	L'atelier des Bois de Grasse
	L'atelier des Délices
	L'Atelier des Secrets
	L'Atelier du Sourcil
	L'Atelier Maquillage
	L'Atelier Parfum
	L'Aurore
	L'Erbolario
	L'Essence des Notes
	L'Herbothicaire
	L'Infuseur
	L’Ô de Provence
	L'Occitane
	l'Odaïtès
	L'Officine du Monde
	L'Onglerie
	l'Or by One
	L'Oréal Paris
	L'Oréal Professionnel
	La Antigua Botica
	La Barbière de Paris
	La Bastide des Arômes
	La Beauté Hermès
	La Bella Donna
	La Belle boucle
	La Belle mèche
	La Biosthetique
	la bonne brosse
	La Canopée
	La Cassidaine en Provence
	La Chênaie
	La Chinata
	La Cité des Parfums
	La Compagnie du Savon de Marseille
	La Corvette
	La Crème Libre
	La droguerie écologique
	La Falaise
	La Fare 1789 en Provence
	La Fée de Paris
	La Ferme de Paula
	La Fontaine Essentielle
	La Formule
	La Kaz Naturelle
	La Laitière
	La Langerie
	La lettre d'Ines
	La maison de la Vanille
	La Maison des Savons
	La Maison des Sultans
	La Maison du Bambou
	La Maison du Coco
	La Maison du Savon de Marseille
	La Maison du Tui Na
	La Manufacture des Sens
	La Manufacture du Siècle
	La Martina
	La Mer
	La Mousserie
	La Nouvelle Botanique
	La Phyto
	La Prairie
	La Provençale
	La Reine Louhanne
	La Riché
	La Rive
	La Roche-Posay
	La Rosée
	La Roulotte à Savon
	La Sablière
	la Saponaria
	La Savonnerie Bourbonnaise
	La Savonnerie Champagne
	La Savonnerie de l’île de Ré
	La Savonnerie de la Venelle
	La Savonnerie de Marcel
	La Savonnerie de Romu
	La Savonnerie des Flandres
	La Savonnerie du Loup qui Chante
	La Savonnerie du Nouveau Monde
	La Savonnerie du Pilon du Roy
	La Savonnière
	La Savonnière du Moulin
	La Société Parisienne de Savons
	La Soulane
	La Sultane de Saba
	La Tisanière
	La Vallée
	La Vaque
	La Vie Claire
	La-Brasiliana
	La-roche-posay
	Labcatal
	Label. m
	Labell
	Labell
	Labello
	Labello
	Labiomer
	Labo
	Laboina
	Laborantin
	Laboratoire 4E
	Laboratoire Altho
	Laboratoire Apiphyt
	Laboratoire Bara
	Laboratoire Besins
	Laboratoire Biodermina
	Laboratoire Bioes
	Laboratoire C.C.D
	Laboratoire Château Rouge
	Laboratoire D.Plantes
	laboratoire de la mer
	Laboratoire dermophil Phyto-Dermatologique
	Laboratoire des Sources
	Laboratoire Deva
	Laboratoire Dissolvurol
	Laboratoire du Gomenol
	Laboratoire du Haut-Ségala
	Laboratoire Exopharm
	Laboratoire FreeSens
	Laboratoire Giphar
	Laboratoire Gravier
	Laboratoire Jaldes
	Laboratoire Janine Benoit
	Laboratoire Lescuyer
	Laboratoire Marque Verte
	Laboratoire Mergens
	Laboratoire Monin Chanteaud
	Laboratoire Pautrat
	Laboratoire Paysane
	Laboratoire Phytéa
	Laboratoire Promicea
	Laboratoire Roche
	Laboratoire Terpan
	Laboratoire Tevi
	Laboratoires ActiNutrition
	Laboratoires Anios
	Laboratoires Azbane
	Laboratoires Bailleul
	Laboratoires BioRecept
	Laboratoires Biotech
	Laboratoires Claude
	Laboratoires de Biarritz
	Laboratoires des Mascareignes
	Laboratoires du Cap-Ferret
	Laboratoires Fenioux
	Laboratoires Filorga
	Laboratoires Gallois
	Laboratoires Genévrier
	Laboratoires Gifrer
	Laboratoires Insphy
	Laboratoires Iprad
	Laboratoires Legan
	Laboratoires Lorica
	Laboratoires Lysedia
	Laboratoires Mediecos
	Laboratoires Nutrisanté
	Laboratoires nuvi
	Laboratoires Osma
	Laboratoires Pronutri
	Laboratoires Renophase
	Laboratoires Saint Benoît
	Laboratoires Science & Équilibre
	Laboratoires SFB
	Laboratoires Spirig
	Laboratoires V-Lab Paris
	Laboratoires Vendome
	Laboratoires Vitarmonyl
	Laboratoires Vivacy
	Laboratoires Wilson
	Laboratoires-gilbert
	Laboratorio Olfattivo
	Laboté
	laCabine
	Lacardabelle
	Lackperm
	Laco
	Lacoste
	Lactacyd
	lactovit
	Lacura
	Lacura
	ladrôme Laboratoire
	Ladurée
	Lady Gaga
	Lady Green
	Lady's Secret
	LadyCup
	Laetitia’s Ti Tree
	Lafes
	LaFolie
	Lai'sentiel
	Laidbare
	Laino
	Laino
	Lait de Jument en Morvan
	Lakmé
	LakShmi
	Lakshmi Kajal
	Lalique
	Lamazuna
	LAMEL
	lamora
	Lanaform
	Lancaster
	Lancôme
	Laneige
	Langé
	Lanolips
	Lansinoh
	Lanvin
	Lanzaloe
	Lao
	Lapiglove
	Laqa & Co
	Larénim mineral
	Laroc
	Larune
	Lasa Aromatics
	Lascad
	Lashem
	LashFood
	Lashilé Beauty
	Lasplash
	LastSwab
	Latika
	Laura
	Laura Baumer
	Laura Biagiotti
	Laura Clauvi
	Laura Geller
	Laura Mercier
	Laura Sim's
	Lauralep
	Laurel
	Lauren's Way
	Laurence Dumont
	LaurEss
	Lavanila Laboratories
	Lavato
	lavera
	Lavera
	Lavera-naturkosmetik
	Lavilin
	Lazartigue
	LBF
	LCA
	LCbio
	LCN
	LDreamam
	Le Bar des Coloristes
	Le Bien dans l'Etre
	Le Blanc
	Le Cercle des Parfumeurs Créateurs
	Le Chat
	Le Chateau du Bois
	Le Clos des Oliviers
	Le Complément Alimentaire
	Le Comptoir Aroma
	Le Comptoir de L'Apothicaire
	Le Comptoir de la Bougie
	Le Comptoir des Savonniers
	Le Comptoir du Bain
	Le Comptoir du Bio
	Le Couvent Maison de Parfum
	Le Domaine de Tamara
	le french make-up
	Le Jardin des Senteurs
	Le Labo
	Le Marsouin
	le mini macaron
	le moly
	Le Myosotis
	Le P'tit Zef
	Le Palais des Reines
	Le Parfum Citoyen
	Le Père Blaize
	Le Père Lucien
	Le Père Pelletier
	Le Petit Marseillais
	Le Petit Olivier
	Le Pommiere
	Le Prince Jardinier
	Le Prunier
	Le Rouge à Ongles
	Le Rouge Français
	Le Rucher Apirium
	Le Savon des Antilles
	Le Secret Naturel
	Le Sérail
	Le Simple
	Le Sourcil par Angélik Iffennecker
	Le Sultan d'Alep
	Le-chat
	Le-comptoir-du-bain
	Le-petit-marseillais
	Le-petit-olivier
	Léa Nature
	Leader Collection
	Leader Price
	Leaders
	Leafmotiv
	Leahlani
	LeanorBio
	Lebensbaum
	Lebon
	Leclerc Marque Repère
	Léclora
	Lee Cooper
	Lee Stafford
	LeeJiHam
	Lefery
	Legami
	Lehning
	Leighton Denny
	Lelo
	Lemahieu
	Lenart Herboriste
	Leonard
	Léonia Paris
	Leonor Greyl
	Léro
	Les 2 Marmottes
	Les Anes Montagnards
	Les Anges ont la Peau Douce
	Les Argiles du Soleil
	Les Aromagies
	Les Bains de Manon
	Les Bains Guerbois
	Les Bénédictines de Chantelle
	Les Bénédictines de Notre-Dame du Calvaire
	Les Bijoux de Maeva
	Les Bougies de Charroux
	Les bulles d'Ysaé
	Les Cent Ciels
	Les Chochottes
	Les Cocottes de Paris
	Les Condamines
	Les Copines
	Les Cosmétiques Design Paris
	les couleurs de Jeanne
	Les Couronnes de Victoire
	Les Délices d'Azylis
	Les Dermo-Cosmétiques de Biafine
	Les Ecuadors
	Les encens du Monde
	les Enfants Sauvages
	Les essentiels
	Les Filles en Rouje
	Les Fleurs de Basile
	Les HappyCuriennes
	les huilettes
	Les Jardins du Hammam
	Les Joyaux de Madagascar
	Les Lumières du Temps
	Les Naturelles
	Les Néréides
	Les Nez Parfums d'Auteurs
	les Oeufs de lilou
	Les Officines
	Les Parfums d'Uzège
	Les Parfums de Grasse
	Les Parfums de Rosine
	Les petites choses
	Les Petits Bains de Provence
	Les Petits Plaisirs
	Les Petits Prödiges
	Les Poulettes Paris
	Les Savons Cachalot
	Les Savons d'Honorée
	Les savons de Joya
	les savons de mon coeur
	Les Savons Gemme
	Les Secrets d'Eglantine
	Les Secrets d'Emilie
	Les secrets de Loly
	Les Sens de Marrakech
	Les Sens des Fleurs
	Les Senteurs Gourmandes
	Les Sentiers d'Alors
	Les Simples
	Les Soins aux Fleurs de Bach
	Les Tendances d'Emma
	Les Terriennes
	Les Thermes Marins de Saint-Malo
	Les Victoriennes
	Les-cosmetiques
	Les-cosmetiques-design-paris
	Les-savons-d-orely
	Less is More
	Lethal Cosmetics
	Leticia Well
	Levana
	Leven Rose
	Liara
	Libertin Louison
	Liberty Cup
	Lidl
	Liebe die Natur
	Lierac
	Life Extension
	Life Flo
	Lifebuoy
	Lifebuoy
	Lift & Roll
	Lift Technic
	Lift'Argan
	LiftBlue
	Ligne Bio
	Ligne Orientale
	Ligne ST Barth
	Likas
	Lilaroze
	Lilas Blanc
	LiLash
	Lilfox
	Lili Margo
	LiliKiwi
	Lillydoo
	Lily Lolo
	lily of the desert
	Lim Hair
	Lime Crime
	LimeLife by Alcone
	Lin d’min coin
	lina hanson
	Linaé
	Linari
	Lindsay
	Linéance
	Lioele
	Lionel de Benetti
	Lip Smacker
	Lipbalm Glam some
	Lipcote
	Lipstick Queen
	Lipton
	Liquides Imaginaires
	Lirene
	Lirikos
	Lisa Hoffman
	Lisane
	Lisap
	Lise Watier
	Lisine Epstein Cosmetics
	Lissfactor
	LissHair
	Listerine
	Listerine
	Little Balance
	Little Big Bio
	Little BU
	Little Marcel
	Littles Cocottes
	Live Botanical
	Live Native
	Livia
	Living Nature
	Living proof.
	lixirskin
	Liz Earle
	LLR-G5
	LOC Love of Color
	Lodesse
	Loelle
	Loewe
	Lofloral
	Logodent
	Logona
	Logona
	Lohmann & Rauscher
	lol
	Lolita Lempicka
	Lollia
	Lollipops
	London Botanical Laboratories
	London Brush Company
	Longcils Boncza
	Lookfantastic
	Loop
	Loovia
	Lora DiCarlo
	Lorac
	Lord & Berry
	Lord of Barbès
	Loreal
	Loreal-paris
	Loren Kadi
	Lorenzo Villoresi
	Lostmarc'H
	Lothantique
	Lothmann
	Lotus
	Lotus Aroma
	Lotus Wei
	Lou d’Arbois
	Louis Vuitton
	Louis Widmer
	Louise émoi
	Louloucup
	Louve Papillon
	Lov Organic
	Lova Skin
	Lovaderm
	Love & Green
	Love beauty and planet
	Love Boo
	Love System
	Love to Love
	Love-beauty-and-planet
	Lovea
	Lovea
	Lovinah
	Loving Tan
	LovoSkin
	LOVVES
	LPEV Laboratoire
	LPG
	LR
	LT Labo
	Lubatti
	Lubin
	Lucas Papaw
	Lucia Iraci
	Luckyfine
	Lueur du Sud
	Luksja
	Lull
	LullaBellz
	Lulu & Boo
	Lulu Nature
	LuluCastagnette
	LuLuLun
	Lumene
	Lumière de Sel
	Luminesce
	luminette
	Lumos
	Luna by Luna
	LunaCopine
	Lunapads
	Luneale
	Lunx
	LureBeauty.com
	Luseta
	Lush
	Lush
	Luster’s
	Lustrasilk
	Lutsine E 45
	Lux
	Luxéol
	Luxie
	Luxor Pro
	Luxuriance
	Luxury Gold
	Luxyor
	Luzern Laboratories
	LYFE
	Lyonsleaf
	Lypsyl
	LysaSkin
	Lytess
	M
	M Picaut
	M. Asam
	M.dam
	M.O. Cochon
	M&A Lab
	M2 Beauté
	M2A Cosmetic Brands
	Ma Belle Barbe
	Ma Cosmeto Perso
	ma kibell
	MAC
	Macadamia Professional
	MacrOvita
	Mad City Soap
	Mad Hippie
	Madame LA LA
	Madame La Présidente
	MadameParis
	Madara
	Made by Mitchell
	Made in Pigalle
	Made with Care
	Mademoiselle Agathe
	Mademoiselle bio
	Mademoiselle Gabrielle
	Mademoiselle papillonne Couture
	Mademoiselle Provence
	Mademoiselle Saint Germain
	Madini
	Madonna
	Madre Labs
	Mady
	Maege
	Maëllya
	MagiClear
	Magicstripes
	Magister
	Magnarelle
	magnifaïk
	Magnitone
	Mahalo Skin Care
	Maharishi Ayurveda
	Mahé
	Mahée
	Mahori
	Mai Couture
	Maie Piou
	Mailelani
	Maison Berger
	Maison Berthe Guilhem
	Maison Bronzini
	Maison Crivelli
	Maison de Senteurs
	Maison du Solide
	Maison Francis Kurkdjian
	Maison Frank Payne
	Maison Margiela
	Maison Matine
	Maison Méditerranée
	Maison Meunier
	Maison Payen 1730
	Maison Suzy
	Maître Augustin
	Maître Parfumeur et Gantier
	Maître Savon de Marseille
	Maitre-savon-de-marseille
	Makanai
	Makari
	make p:rem
	Make Up For Ever
	Make-Up Atelier Paris
	Makebelieve
	Makeup By Mario
	MakeUp Eraser
	Makeup Geek
	Makeup Revolution
	Making Of
	Malin+Goetz
	Malizia
	Malou & Marius
	Malu Wilz
	Mama Sango Cosmétique bio
	Mambino Organics
	Mamo cosmétique
	Manasi 7
	Manava
	Manavis
	Mandarina Duck
	Mandom
	Mane 'n Tail
	Manea Spa
	Mango
	Manhattan
	Manic Panic
	Manix
	Manly
	Manna Kadar
	Manoush
	manucurist
	Manufaktura
	MAPA
	MaqPro
	Marabout
	Maravilla Laboratoire Cosmétique
	Marbert
	Marc Jacobs
	Marcapar
	Marcelle
	Marcus Rohrer Spirulina
	Marcus Spurway
	Mareva
	Margaret Astor
	Margaret Dabbs
	Margot&Tita
	Maria Galland Paris
	Maria Nila
	Marie Jeanne
	Marie Rose
	Marie-Claire
	Mariella Rossi
	Marilou Bio
	Marina de Bourbon
	Mario Badescu
	Marion Cosmetics
	Marionnaud
	Marius Fabre
	Marius-fabre
	Marks & Spencer
	Marlay
	Marlies Möller
	Marna
	Marni
	marocMaroc
	Marokeratine MK
	Marokissime
	Martin de Candre
	Martina Gebhardt Naturkosmetik
	Martine Cosmetics
	Marula
	Marula Secrets
	Marvel
	Marvis
	Mary Cohr
	Mary Kay
	Mas du roseau
	Mascot Europe BV
	Masmi Natural Cotton
	Mason Pearson
	masque b.a.r
	Massada
	Massato
	Masters Colors
	Mastey
	MaterNatura
	maternov
	Mathera
	Matière Brute
	Matiere Premiere
	Matis Paris
	matrix
	Matthew Williamson
	Mauboussin
	Maui Moisture
	Mavala
	Mavill
	Mawena
	Max & Me
	Max & More
	Max Factor
	Max Mara
	maxmedix
	May Lindstrom Skin
	Maya Chia
	Mayaé Cosmétique
	Maybe Paris
	Maybelline
	Maybelline New York
	mayél
	Mayoly Spindler
	MB Milano
	MBMO My Body My Oil
	MCeutic Laboratoire Thalgo
	MD Corrective Care
	Me Makeover Essentials
	Mé-Mé
	Medela
	Medene
	Medi-Peel
	Mediadisque
	Médial
	Medicafarm
	MediCeutics
	medicube
	MediDerma
	Médiflor
	MediHeal
	Medik8
	Medimix
	Medipharma Cosmetics
	Medisana
	Mediterranean Spa
	MEEKI
	Meera
	Mégatone
	MegRhythm
	Mehitsa
	meisani
	Mekar
	Mel Millis
	Mel'anie's
	Mel&#257;huac
	Melanthion
	MelBeauty
	Melchior & Balthazar
	Melem
	Melkior Professional
	mélo Ayurveda
	MeLuna
	Mélusine
	Melvita
	Melyssa Cosmethnic
	Même
	Memo
	Men-ü
	Mënaji
	Menard
	Mennen
	Mennen
	Menobelle
	Menos Mas
	Mentholatum
	Meow Cosmetics
	Mercedes-Benz
	Merci Handy
	Merck
	Mercryl
	Mercurochrome
	meridol
	Meridol
	Merkur
	Mermade Hair
	Mermaid + Me
	Mersea
	Mesauda
	mesoestetic
	Mességué
	Meswak
	Metamorphose
	method.
	Methode Brigitte Kettner
	Méthode Jeanne Piaubert
	Methode Physiodermie
	MetroX
	Mexx
	mi-rê
	MIA Cosmetics Paris
	Michael Kors
	Michael Todd true organics
	Michel Brosseau
	Michel Mercier
	Micro Cell
	Migros
	Miguhara
	Mila d'Opiz
	Milani
	Milical
	Milk Makeup
	Mill Creek botanicals
	Millani
	Millea
	Millefiori
	Miller et Bertaux
	Miller Harris
	Milu Beauty
	Mimesis
	Mimitika
	Minceïne
	Mineral Flowers
	Mineral Fusion
	Mineral Line
	Mineralium Dead Sea
	Minerva
	Minesens
	MineTan
	Minexcell28
	minima[liste]
	Minois
	Minolvie
	Minus -417
	mio
	Mira
	Miraclar
	Miracle-8
	Miradent
	Mirenesse
	Miriam Quevedo
	MiroPure
	Mirra
	Misa
	Misencil
	Miss Cop
	Miss Den
	Miss Eden
	Miss Europe
	Miss Ferling
	Miss Jessie's
	Miss Sporty
	Miss W Pro
	Missha
	Misslyn
	Missoni
	Mitchell and Peach
	Mitosyl
	Miu Miu
	mium Lab
	Mixa
	Mixa
	Mixa-bebe
	Mixa-solaire
	Mixed Chicks
	mixsoon
	MiYé
	Mizani
	Mizensir
	Mizon
	Mki
	Mkl
	mkl green nature
	MMUK Man
	MOA Magic Organic Apothecary
	Moana
	Möbius
	Mod's Hair
	Model Co
	Modélite
	Models Own
	Modibodi
	Modifast Intensive
	modjo
	MOEA
	Moistie's
	Mojo Natural Sex Care
	Molinard
	Molton Brown
	Molyneux
	môme care
	Moment Couleur
	Mon petit Bandeau
	Mon Petit Nuage
	Mon Petit Paradis
	Mona di Orio
	Monaco Parfums
	Monasens
	Monastère de Ganagobie
	Monave Mineral Cosmetics
	Moncler
	Monoprix
	Monoprix bio !
	Monotheme
	Monsavon
	Monsavon
	Monsieur Barbier
	Monsieur D.
	Mont Roucous
	Mont St Michel
	Montagne Jeunesse 7th Heaven
	Montale
	Montana
	Montblanc
	Monte Carlo Beauty
	Monts et Merveilles
	Monu
	Moodz
	Mooncherry
	Mooncup
	moonshot
	moove & fit
	Mop Modern Organic Products
	Moraz
	Morgan
	Morgandra
	Morjana
	Morning street
	MoroccanOil
	Morphe
	Morphe 2
	Morphée
	Moschino
	Mosell'Âne
	Moskito Guard
	Mosqueta's
	Mosqueta's Green
	Moss skincare
	Mossa
	Motions
	Moulin des Senteurs
	mousse
	MoustiCare
	Moustidose
	MoustiKologne
	Mr. Jeannot
	Mr.Blanc Teeth
	Mroobest
	Mschic
	MSE
	Mtx
	MUA Makeup Academy
	MucoGyne
	Mudmasky
	Mugler
	Mühle
	Muji
	Mukti
	Müller
	Mum
	Mun
	Murad
	Musc Intime
	Musk Collection
	Mussvital
	Mustela
	Mustela
	Müster & Dikson
	Mustus
	MV Organic Skincare
	My Beauty Diary
	My Blend by Dr Olivier Courtin
	my Clarins
	My Cosmetik
	My Jolie Candle
	My KBeauty Box
	my little beauty
	My Little Box
	My Lubie
	My Perfume is a Twistick
	My Scheming
	My Skinadvance
	My SOS Beauty
	My Sweet Bio
	Mycelab Paris
	MyChelle
	Myego
	myIEVA
	Mylan
	mylee
	Myleuca
	Mypads
	MyProtein
	Myriam.K
	Myrurgia
	Myspa
	Mystic divine
	Mysticurls
	Mythos
	myVariations
	myVeggie
	N
	N-a-e
	N.A.E.
	N.Y.C. New York Color
	Na&t Story
	Nabi
	Nabila K
	Nabioka
	Nabla
	Nacara
	Nacomi
	Nacriderm
	Nadine Salembier
	Naf Naf
	Nail Tek
	Nailberry
	Nailmatic
	Nailner
	nails inc.
	nailstation
	Nair
	naissance
	Naked Lips
	Naloc
	namaki
	namari
	Nana
	Nana. M parfums
	Nanolash
	Naobay
	Narciso Rodriguez
	Nard
	Narjis Cosmetic
	Nars
	Narta
	Narta
	Narüko
	Nasomatto
	Nass-Cosmeto
	Nat&Form
	Nat&Nove Bio
	Natasha Denona
	Natessance
	Natessance
	Nateya
	Native
	Native Propolis
	Natorigin
	Natracare
	Natuderm Botanics
	Natulique
	Natur'
	Natur'Aile
	Natura Brasil
	Natura Estonica
	Natura Siberica
	Natura-siberica
	NaturaCelt
	Naturactive
	naturadika
	Naturado en Provence
	Natural Honey
	Natural Mojo
	Natural Nutrition
	Natural Pigma
	Natural Products
	Natural Repair
	Natural Sea Beauty
	Naturalia
	NaturaLine
	naturalium
	naturallogic
	Naturally Balmy
	Naturalmente
	NaturAloé
	Naturamind
	NaturDerm
	Nature & Découvertes
	Nature & Senteurs
	Nature attitude
	Nature Box
	Nature EffiScience
	Nature is Future by Phytodia
	Nature Marine
	Naturé Moi
	Nature Republic
	Nature Thalasso
	Nature's
	Nature's Bounty
	nature's Finest
	Nature's Gate
	Nature's Secrets
	Natureal
	Naturekind
	Naturel Ebène
	Naturel O Galop
	Naturelle Aphrodite
	Naturelle d'Argan
	Naturelle d'Orient
	Naturellement Bien
	Naturena
	Natures Plus
	NatureSun' Arôms
	Naturhôna
	Naturica
	Naturience
	Naturland
	NaturOli
	Naturoscience
	Naturtint
	Natury Bio
	Natus
	Naty
	Natyr
	Nautica
	Nayouni
	NCLA
	Neal's Yard Remedies
	Neat
	Nectar-of-beauty
	Nectar-of-nature
	Nejma
	Nejma Collection
	Nell Ross
	Nelly De Vuyst
	Nelson Honey
	Nelsons
	Neo by Nature
	neobio
	NéoBulle
	NeoCell
	Neoclaim
	Neogen Dermalogy
	Néolia
	Neoliss
	Neom
	Neomist
	NÉONAIL
	NeoStrata
	Neotantric Fragrances
	Nep
	NEQI
	Néroliane
	Nescens
	Nest Skincare
	Nesti Dante
	NetLine
	Nett
	Netto
	NEUR|AÉ
	Neutraderm
	Neutrogena
	Neutrogena
	Neve Cosmetics
	NevO Dead Sea SPA
	New Angance
	New Chapter
	New Cid Cosmetics
	New Nordic
	Newa
	NewPeptin
	Newseed
	NexUltra
	Nexxus
	Nez
	Nez à Nez
	Nfu.Oh
	NHCO Nutrition
	nia not into aging
	Nicka K New York
	Nicki Minaj
	Nicolaï
	nidéco
	Nihel
	Nildor
	Nilessences
	Nina Ricci
	Nino Amaddeo
	Niod
	Nioxin
	Nip + Fab
	Nippon Kodo
	Nirvel
	Nivea
	Nivea
	Nivea-men
	Nivea-sun
	NividiSkin
	Niwel
	NKD SKN Vita Liberata
	No Bump
	No-Germs
	Nobile 1942
	Noble Isle
	Noble Panacea
	Nocibe
	Nocibé
	Nocode Paris
	Noham
	Nohèm
	Noïa Hair Care
	noire ô naturel
	noka
	Nomade Palize
	Nominoë
	NOOANCE
	Nook
	Noreva Laboratoires
	Norma
	Norma de Durville
	normaness
	nostra
	Note Cosmetique
	Nougat London
	Nougatine Paris
	Noughty
	Nourish
	nout
	NovaBaume
	Novaderm
	Novange 788
	NovaSanté
	novépha
	novex
	Novexpert
	Novexpert
	Now
	Now Solutions
	nspa
	Nu Moments
	Nu Skin
	Nu U Nutrition
	nu3
	Nubar
	Nubian Heritage
	Nubo
	Nûby
	Nubyane
	Nude by Nature
	Nude Skincare
	NudeStix
	Nuhanciam
	NUI Cosmetics
	Nuk
	nulon
	Number 4
	Numeric Proof
	nuNAAT
	Nuobisong
	Nuoo
	Nuori
	Nüssa
	Nutergia
	nutrazul
	Nutreov Laboratoires
	NutriLife
	Nutrimetics
	NutriSaisons
	Nutrisaveurs
	NutriSensis
	NuWhite
	NUXE
	Nuxe
	Nya Paris
	Nyloa
	NYM
	nyoy
	NYX
	Nyx
	O
	O Pur
	O.B.
	O.P.I.
	O'lysee
	O'Natur
	O'o hawaii
	O'slee
	O2D-biotic
	O2Mer
	Obagi
	ObeyYourBody
	Obiotic
	Obvious
	OCC Obsessive Compulsive Cosmetics
	oceanheritage
	Océante
	Océopin
	Ocibel
	Odacité
	ODEN
	Odile Lecoin
	Odin
	Odorex
	Odyha
	Odylique by Essential Care
	OE
	Oemine
	Oenobiol
	Oenolia
	Oeufs de yoni
	Officine Universelle Buly
	Officinea
	Ofra
	Ogx
	Ogx
	Oh K!
	Oh My Cream Skincare
	Oh my Glow omg
	Oh qu’il est bio !
	Oh!
	ohëpo
	Oilily
	Oils of Heaven
	Oilten
	Ojova
	Oka Cosmetics
	Okaïdi
	Okoia
	Okoko Cosmétiques
	Olaplex
	Olaz
	OLC
	Old Spice
	Old-spice
	Oléanat
	Oléanes
	Oleassence
	OleHenriksen
	Olience
	Oligobs
	OligOcaps
	Oligodermie
	Olima
	olisma :
	Olivarrier
	Olive Oil ORS
	Olivelia
	Olivella
	Olivia Garden
	Olivier Claire
	Olivier Durbano
	Olivier Lebrun Paris Coiffeur
	Olivier Tissot
	Olivolio
	Olverum
	Om Aroma & Co
	OMA & ME
	Omaïdo
	Ombia
	Oméga Pharma
	Omer Soap
	Omerta
	OMG Oh My Goods
	Omindia
	Omnisens
	Omnivit
	Omorovicza
	Omoyé
	Omum
	on Behalf.
	On The Wild Side
	Onagrine
	ondo Beauty 36.5
	One Direction
	One Love Organics
	One Minute Manicure
	One Thing
	One Touch
	one.two.free!
	Ongle 24
	Only You
	Onyx
	Onyx Dermo Labs
	oOlution
	Opal London
	Opale
	Opalis
	Opaz
	Oppidum
	Optiat
	Optim Curcuma
	OptiSmile
	Optone
	Optys
	Oral-B
	Oréscience
	orfito
	Organic Fiji
	organic shop
	Organic Veda
	Organics by Africa's Best
	OrganiCup
	Organique
	Organix Cosmetix
	Organyc
	OrhiS
	Oribe
	Original Sprout
	Original-source
	Origins
	Origins Organics
	Oriza L. Legrand
	Orlane
	Orly
	Oro Therapy 24K
	Orphica
	Orphya
	ORS Organic Root Stimulator
	OrthéBio
	Orthemius
	Orthonat nutrition
	Ortis
	Orveda
	Oryam
	Oryza Lab
	Oscar + Dehn
	Oscar de la Renta
	Oscience by Claire Bianchin
	Osée
	Osélia
	Oskia
	osmo
	Osmo Essence
	Ostraly
	OUAI
	Ouity Natural Care
	Ovance Paris
	Oxalia
	Oxbow
	Oxy
	Oyster Cosmetics
	OZ Naturals
	Ozalys
	Ozentya
	Ozoane
	Ozon'
	P
	P-g
	P. Frapin & cie
	P. Jentschura
	P. S. Love your Skin
	P.lab Beauty
	P.Louise
	P.O.12
	P'tit Bobo
	P'tits Dessous
	P2 Cosmetics
	Pachamamaï
	Pacific Biotech
	Pacifica
	Pacifique Sud
	Padmini
	pagès
	Pai
	Paingone
	PaintGlow
	Palette
	Palgantong
	Palmer-s
	Palmer's
	Palmolive
	Palmolive
	Paloma
	Paloma Picasso
	Palta
	Pampers
	Pampers
	Paname
	Panasonic
	Pandhy's
	Panier des Sens
	Pannoc
	Panpuri
	Pantene
	Pantene
	Pantene Pro-V
	Pantene-pro-v
	Pantothen
	PaolaP
	papa recipe
	Papier d'Arménie
	Papillon Rouge
	Papulex
	Papustil
	Para'Kito
	Parachute Advansed
	Paradesa
	Paranix
	Parashop
	Parasidose
	Parasol
	Parfum d'Empire
	Parfums 137
	Parfums Corania
	Parfums d'Antan
	Parfums d'Orsay
	Parfums de la Bastide
	Parfums de Marly
	Parfums Delrae
	Parfums Grès
	Parfums H pour Homme
	Parfums Hashtag
	Parfums MDCI
	Parfums Roger Vivier
	Parfums Star
	Parfums Weil
	Paris Berlin
	Paris Elysées Beauté
	Paris Exclusive TO
	Paris Hilton
	Paris mon amour
	ParisAx
	Parissa
	Parker Safety Razor
	Parle Moi de Parfum
	Parlor by Jeff Chastain
	Parlux
	parodontax
	Parodontax
	Parogencyl
	PartyLite
	Pasante
	Pascal Morabito
	Pascoe
	PasJel
	Passion marine
	Passion Savon
	Past’elle
	Pat McGrath Labs
	Patchaïa
	Patchness
	patchology
	Patio
	Patisserie de Bain
	Patrice Mulato
	Patricia Wexler
	Patyka
	Paul & Joe
	Paul Brown Hawaii
	Paul Mitchell
	Paul Smith
	Paula's Choice
	Pause well-aging
	Payot
	paysans d'ici
	Paysans Savonniers
	Pb Cosmetics
	PBE
	Peace and Skin
	Peace Out
	Peaudouce
	PediSilk
	PediTech
	Peggy Sage
	Peigne en corne
	Pelle
	Penhaligon's
	Pento
	Peony
	Pepe Jeans London
	Percutalgin'Phyto
	Percy & Reed
	peripera
	Perlanesse
	Perle de Beauté
	Perle de Provence
	Perles de Rivière
	Perlucine
	Perricone MD
	Perron Rigot
	Perry Ellis
	Persavon
	Persavon
	Persil
	Personnelle
	Petal Fresh
	Peter Lamas
	Peter Thomas Roth
	Petipo de Patapo
	Petit Bateau
	Petit Gris
	Petite Maison
	PetitFée
	Pétrole Hahn
	Petrole-hahn
	Pevonia Botanica
	Phabel
	Phaedon Paris
	Pharell Williams
	Pharma Nord
	Pharmactiv
	PharmaPrix
	PharmaScience
	PharmaTheiss Cosmetics
	Pharmaton
	PharmaVoyage
	Pharmodel
	PHB Ethical Beauty
	Phebo
	phi Essentiel
	Philip B.
	Philip Kingsley
	Philipp Plein
	Philips
	Philosophy
	Phy
	Phyderma
	Phyl'Activ
	Physalis
	Physicians Formula
	Physio Sources
	Physio-Concept
	Physiodose
	Physioflor
	Physiomer
	Physiomins
	Phyt's
	Phytalessence
	Phytéal Laboratoires
	Phytema
	Phyto
	Phyto Aromatica
	Phyto One
	Phyto-Actif
	Phytobiodermie
	Phytobiol
	Phytocéane
	Phytoceutic
	Phytodess
	Phytodoxia
	PhytoFast
	Phytomarin
	Phytomer
	Phytonature
	Phytonorm
	Phytophilo
	PhytoPrevent
	PhytoQuant
	Phytorelax
	Phytosun
	Phytosun Aroms
	Pia
	Picture Polish
	Pienett
	Pier Augé
	Pierre Alun par Floressance
	Pierre Cardin
	Pierre Fabre
	Pierre Guillaume Paris
	Pierre René Professional
	Pierre-fabre
	Pierre-fabre-oral-care
	Pikpanou
	Pilaten
	PiLeJe
	Pilogen Carezza
	Pimkie
	Pin Up Secret
	Pink Bow Bath Boutique
	Pink Paris
	Pink Sugar
	Pinnacle
	Pino
	Pino Silvestre
	Pique et Pince
	Pitaya Natural Kosmetik
	Pivolea
	pixi
	Piz Buin
	Place des Lices
	Placentor Végétal
	Plaisir des Sens
	Plaisirs Secrets
	Planet Kid
	Planetary Herbals
	Planète Au Naturel
	Planète Panda
	Plant Apothecary
	Plant'Asia
	Planter's
	Plantes & Parfums Provence
	Plantes et Potions
	Plantifique
	Plantil
	Plants by Nature & Découvertes
	Plastimea
	Playboy
	Playboy Beauty
	Pléniday
	PliM
	Plombières Cosmétiques et Santé
	Plume Science
	Pocabana by Roval
	Podamour
	Poderm
	Podorape
	Poiray
	Polaar
	Polar Jade
	Polenia
	Police
	Poly Palette
	Pomarium
	Poméol
	Pommade Divine
	Pomponne
	Pond's
	Pont des Arts
	Pop !
	Pop Modern.C
	PopBrush
	Poreia
	Porsche Design
	Poshé
	Positiv'hair
	Possibility
	PostQuam
	Poulage Parfumeur
	poupina
	Pour Toujours
	Pourprées
	Pouxit
	Power-Up
	Pozzo di Borgo
	Practi Beauty
	Prada
	Prady Parfums
	Praïa
	Pranarom
	Pranarôm
	PraNaturals
	Précieuse Epil
	Precious
	Prephar
	Prescription Lab
	Prestance
	Prestige
	pretty Vulgar
	Preven's
	Previa
	prim aloé
	Primark
	Primavera
	Princess Skincare
	Prioderm
	Priori
	Privé
	Pro Aroma
	Pro Fvmvm Roma
	PrO-Care
	Proactiv Solution
	Procare Health
	Procter-gamble
	Proenza Schouler
	Profectiv
	Profumi del Forte
	Profusion Cosmetics
	Projet 28
	Promex Professional
	Promod
	Pronails
	Prophessence
	Propolia
	Propos'Nature
	Proraso
	ProRhinel
	Protex
	Protifast
	Proto-col
	Provençale d'Aromathérapie
	Provence & Nature
	Provence Santé
	ProWhite
	ProWin
	Prudence
	psa
	Puissante
	pukka
	Pulpe de Vie
	Puma
	Punch Power
	Pupa
	Pür
	Pur Eden
	Pur Inside
	Pur'Aloe
	Pura Bali
	pura d'or
	Purasana
	Pure
	Pure & Care
	Pure Air
	Pure Altitude
	Pure by Switzerland
	Pure Mineral
	Pure Nuff Stuff
	Pure Olive
	Pure Provence
	Pure Suisse Laboratoire
	Pure White Cosmetics
	pure97
	Purebess
	Purederm
	PureHeals
	puremetics
	PureOlogy
	Purepotions
	Puressentiel
	Puressentiel
	Pureté
	Purissimes
	Purito
	PuroBio Cosmetics
	Pylones
	Pyt
	pyt beauty
	Q
	q
	Q+A
	Qamaré
	Qiriness
	QRxLabs
	Queen Bee
	Queen Hélène
	Queen-Pam beauty
	Quegar
	Quick'Net
	Quies
	Quintessence
	R
	R System Paris
	r.e.m. beauty
	R'Factory
	R+CO
	RAAW Alchemy
	Rabanne
	Rachel's Plan Bee
	Raconte moi un savon
	RadiaLabs
	Radical Cosmetics
	Radico
	Radox
	Rahua
	Rainbow Honey
	Rainpharma
	Ralph Lauren
	Ramosu
	Rampage
	Rampal Latour
	Rampal-latour
	Rancé
	Rapid White
	RapidLash
	Rapunzel
	Rare Beauty
	Rare Paris
	Rasage Classique
	Rausch
	Raylex
	Re:cipe
	Real Barrier
	Real Techniques
	Réalia
	Reborn
	Recipe for Men
	Recipes of Babushka Agafia
	RECLAR
	Redecker
	Redken
	Réelle
	Refan
	RefectoCil
	Refer
	Référence
	Refinery
	Regenerate Enamel Science
	regimen lab
	Regine's
	Réjeanne
	Réjence
	Rejene
	REK UP !
	Reload
	Remedis
	Remington
	Reminiscence
	Rémy Laure
	REN
	René Furterer
	René Garraud
	Renée Blanche
	Renpure
	Repetto
	Replay
	Replens
	Résonances
	Respir' Activ
	respire
	Ressource Corps-Mental
	Restylane
	resultime
	Revamp Professional
	Rêve-Bienêtre
	Revelations Perfume
	Révèle
	RevelEssence
	Révérence de Bastien
	Reversa
	Reviive
	Revital.AB
	RevitaLash
	Revitatone
	Revitol
	revium
	Revlon
	Revlon
	Revlon Professional
	Revolution
	Revuele
	Rexaline
	Rexona
	Rexona
	Rexona-men
	Reyne
	RGB cosmetics
	Rhino Horn
	Rich Hair Care
	Richard James
	Richelet
	Richesses du Monde
	Ricin Shop
	Ricqlès
	Riemann
	Rihanna
	Rilastil
	Rimmel
	Rimmel
	Ringana
	Rio
	Rio-Keratin
	RiRe
	Ritessens
	Rituals
	Rituals
	Rituel de Fille
	Rivadouce
	Rivage
	Rival de Loop
	Riviera Tan
	RLizz
	rms beauty
	Robert Piguet
	Roberto Capucci
	Roberto Cavalli
	RoC
	Roccobarocco
	Rochas
	Rock & Ruddle
	Rococo Nail Apparel
	Rodial
	Rodin
	Roge-cavailles
	Roger-gallet
	Roger&Gallet
	Rohto
	rom&nd
	Romantic Bear
	Roméa D'Améor
	Romon Nature
	Romy.
	Ron Dorff
	Roos & Roos
	Rosalia
	Rosarôm
	Rosazucena
	Rose & Co.
	rose la lune
	Rose of Bulgaria
	Rosebud Perfume Co.
	Rosegold Paris
	Rosveda
	Rouge Baiser
	Rouge Bunny Rouge
	Rougj
	Rovectin
	Rovtop
	Rowenta
	Royal Roots
	Royal Tonus
	Royale Bee
	Royalissime
	RoyeR cosmétique
	Rubella
	Rubis
	Ruby & Millie
	Ruby Cosmetics
	Ruby Kisses
	Rudolph Care
	Rugard
	Ruhaku
	Runak
	Rusk
	Russie Blanche
	Ruth Niddam Paris
	S
	S.A.V.E
	S.he stylezone
	S.Heart.S
	s.Oliver
	S.T. Dupont
	S&Vaë
	S5
	saaf
	Sabé Masson
	Sabon
	Saborino
	Sacha
	Sachajuan
	SAEVE
	Saforelle
	Saforelle
	Safral
	Sahlini
	Saint Algue
	Saint-algue
	Saint-Bernard
	Saint-Gervais Mont Blanc
	Sainte Victoire
	Saisona
	Saisons d'Eden
	Sakaré
	Salerm Cosmetics
	Sally Hansen
	Salon Style
	Saltrates
	Salus
	Salva
	SalvaDerm
	Salvador Dali
	Salvatore Ferragamo
	Salwa Petersen
	Samarome
	samélie Plantes
	Sampar
	Sampure Minerals
	San Mar
	San Saru
	Sana
	Sanaka Bio
	Sananas Beauty
	Sanarom
	Sanase
	Sanca
	Sand & Sky
	Sanex
	Sanex
	sanicur
	Sankodo
	Sanodiane
	Sanofi
	Sanoflore
	Sanoflore
	Sanogyl
	Sanogyl
	sanoléo
	Sanotint
	Sans Soucis
	Santa Maria Novella
	Santane
	Santarome
	SantaVerde
	Santé d'Orient
	Sante Naturkosmetik
	Santé Verte
	Santee Cosmetics USA
	Sanytol
	Sanytol
	Saponaire
	Sarah Chapman
	Sarah Jessica Parker
	Sargenor
	Sarmance
	Sarôme
	Sasco
	Satin Naturel
	Satisfyer
	Sativa
	Saturday Skin
	Satya Sai Baba
	Saugella
	Saugette
	SaunaLifter
	Savanah
	Savex
	Savignac
	Savon de l'Artisan
	Savon Jumens lait de jument
	Savon Le Naturel
	Savon Stories
	Savonnerie Aubergine
	Savonnerie Bethanie
	Savonnerie de Beaulieu
	Savonnerie de Bormes
	Savonnerie de Ré
	Savonnerie des 5 Sens
	Savonnerie du Cèdre
	Savonnerie du Midi
	Savonnerie La Curieuse
	Savonnerie Le prieuré de St Georges
	Savonnerie Scala
	Savonnerie Soleya
	Savons & Bougies
	Savons Arthur
	SB Collection
	SBC Simply Beautiful
	Scented Garden
	Scentsy
	Scentys
	Schaebens
	Schauma
	Schauma
	Schiaparelli
	Schmidt-s
	Schmidt's
	Scholl
	Scholl
	Schwarzkopf
	Schwarzkopf
	Schwarzkopf Professional
	Schwarzkopf-henkel
	SCINIC
	Scitec Nutrition
	Scorpio
	Scotch & Soda
	Scotch Naturals
	Scott Barnes
	Scott-Vincent Borba
	Sea of SPA
	Sea-Band
	Sealine
	Seascape island apothecary
	Seasonly
	Sebamed
	Sebamed
	Sébastian Professional
	Seche
	Secret by Athena
	Secret des Avelines
	Secret Key
	secret nature
	Secret Professionnel by Phyto
	Secrets de Miel
	Secrets de Provence
	Secrets des Dames
	Secrets des Fées
	Secrets-de-provence
	Seda
	SeeSee
	SegMiniSmart
	Seizen
	sekoa
	Sel des Alpes
	Selective Professional
	Sen7
	sence
	Senka
	Sens&Spirit
	Sensai
	Sensation Chocolat
	SensatioNail
	Sensidol
	Sensodyne
	Sensodyne
	Sentara
	Sentéales
	Senteurs de Fée
	Senteurs et Bien-Etre
	Senti2
	Sento
	Senzera
	sepai
	Sephadis
	Sephora
	Sephora Collection
	Seraphine Boticanicals
	Serge Blanco
	Serge d'Estel
	Serge Lutens
	Sérium
	Sesderma
	Sesvalia
	Seveline
	Seventy One Percent
	Sevessence
	Sex Pistols
	Sézane
	shaeri
	Shakira
	ShakyLab
	Shantara
	Sharini
	Shark
	Shavata
	Shay & Blue
	She makeup
	Shea Moisture
	Shea Terra
	Shearer Candles
	Sheer Miracle
	SHEGLAM
	Shigeta
	Shills
	Shiseido
	Shiseido
	Shop Line Fleurilège
	Shoti Maa
	Shu Uemura
	shu uemura art of hair
	Shunga Erotic Art
	Si Si La Paillette
	Sia
	Siam Seas
	Sibel
	Sibu
	Sidmool
	Sierra Bees
	Sigma
	Signal
	Signal
	Signature Minerals makeup
	Sil'intime
	Silagic
	Silcare
	Silicium España
	Silk'n
	SilverCare
	Simon & Tom
	Simone Mahler
	Simple
	SimpleHuman
	SimySkin
	Sinagua
	SINAHET
	Sineaqua
	Sinful Colors
	SingulaDerm
	SinOmarin
	Sinovital
	sinutan
	Sioris
	SIPF Plantes Fraiches
	sisley
	Sister & Co.
	Six
	Six Scents
	Själ
	SJR Sandrine Jeanne-Rose
	SK-II
	Skandinavisk
	Skeyndor
	Skin & Co Roma
	Skin & Tonic London
	skin and out
	Skin Bliss
	Skin Doctors
	Skin Food
	Skin Gym
	skin loving
	Skin Method
	Skin Milk
	Skin Nutrition
	Skin Progress
	Skin-Cap
	SKIN1004
	Skin79
	skinblue
	Skincare
	Skinception
	skincere
	SkinCeuticals
	SkinChemists
	Skincode
	Skindesigned
	Skineance
	skinfy
	SkinHaptics
	SkinLabo
	Skinlite
	SkinMedica
	Skinny & Co.
	Skinny Tan
	SkinOwl
	SkinRenu
	Skintifique
	Skintruth
	SkinVitals
	Skip
	Skyn Iceland
	SLA Paris
	Slakkenwonder
	Slava Zaïtsev
	Sleek MakeUP
	Sleeping Club
	Slendertone
	Slim Cera
	Slim Intensive
	Slim Plus
	Slim Secrets
	Slimdoo
	Slimtess
	slip
	Slolie
	Slowen
	Smashbox
	Smashit Cosmetics
	smile makers
	Smiloh
	Smith's Rosebud
	Smith's Vitamins & Herbs
	Smoon lingerie
	Smoothskin
	Smoss
	Snail Star
	Snowberry
	Snowfire
	So Nature par Jean d'Estrées
	So Susan
	So-bio
	So-bio-etic
	SO'BiO étic
	So'cup
	So'Slim
	Soap & Glory
	Soap Andaloucy Company
	Soapwalla
	SoapyLove
	Sodasan
	Soébio
	Sofn'free
	Soft & Beautiful
	Soft Sence
	Soft touch
	Softsheen Carson
	Soin & Tradition
	Soin de Soi
	Soins d'Orient
	Soins Experts LDA
	Sol de Janeiro
	Sol.fine
	Sol’Esta
	Solac
	Solaray
	Solavie
	Soleil d'Orient
	Soleil des Iles
	Soleil Noir
	Soleil Sucré
	Soleil Toujours
	Solgar
	Solibio
	Solidea
	Solinotes
	Solvarome
	Somatoline Cosmetic
	Some By Mi
	Somersets
	Sommital
	Sonett
	Sonett
	Sonia Kashuk
	Sonia Orts
	Sonia Rykiel
	Sooa
	Sooa
	Soonghai
	SoOud
	sophia+mabelle
	Sophie la Girafe
	Sorifa
	Sosilk Professional
	Soskin
	Soteix
	Sothys
	Soultree
	Source Claire
	Source de Provence
	Source Naturals
	Sous les Oliviers de Provence
	SPA exclusives
	Spectrum
	Spiezia
	Spinée
	Spiritual Sky
	Spiritum Paris
	Spiruline Berbère
	Spiruline de Provence
	Splat
	Sponjac
	Sport-Elec
	SportFX
	Sports Akileïne
	Squid Soap
	St Barth
	St Ives
	St. Moriz
	St. Tropez
	Stamino
	Stara Mydlarnia
	StarGazer
	StarMiroir
	Starskin
	Startec
	STC Nutrition
	Stefi
	Stella Cadente
	Stendhal
	Stéphanie Franck Beauty
	Stérimar
	Steripan
	Steve McQueen
	Stiefel
	Stila
	Stiprox
	Stop The water while using me!
	Stowaway
	Street Looks
	StriVectin
	Strixaderm-MD
	Struthio Derma
	Studio 10
	Studio 78
	Studio Savon
	Studiomakeup
	STYLondon
	stylPro
	Su-Man
	Su:m37
	Suavinex
	Sublime Repair Forté
	Sublimo
	Sublinel cosmétique
	Subrina
	subtil
	SucreDerme
	Sugarbearhair
	Suilo
	Suki
	Sukin
	Sulwhasoo
	Summer Fridays
	Sun Laboratories
	Sun Pass
	Sun-dance
	Suncoat
	Sundance
	Sundari
	Sunday Natural
	Sunday Riley
	Sunkissed
	Sunlight
	Suntique
	Super Smart
	Superbon.
	Superdiet
	Superdry
	Supergoop!
	SuperWhite
	Supradyn
	SupraSvelt
	Suqqu
	Sur.Medic
	Surratt
	Surya Brasil
	Susanne Kaufmann
	Svr
	SVR Laboratoire Dermatologique
	Swanliss
	Swarovski
	sweat
	Sweet Musc
	SweetLisS
	Swiss Alpine cosmetic
	Swiss Blue Farm
	Swiss Esoteric Musk
	Swiss O Par
	Swissclinical
	Swissforce
	Swissmadelabs
	Sydella
	Sylaine Paris
	Syllepse
	Sylvaine Delacourte
	Symba
	Symbiosis
	Symbiosis London
	Symphonat
	SynActifs Laboratoires
	Synbionyme
	synergia
	Synthol
	syoss
	Syoss
	System Professional
	SYX
	T
	t by tetesept:
	T.LeClerc
	T3
	Taaj
	Tabac Original
	Tabaibaloe
	Tadam'
	Taft
	tahiti
	Tahiti
	Tahiti Naturel
	Taladerm
	Talavera
	TALIA
	Talika
	talm
	Tamalys
	tamburins
	Tampax
	Tan Organic
	Tan-Luxe
	Tanamera
	Tangle Teezer
	Tanita
	TannyMax
	TanOrganic
	Tara Smith
	Tarte
	Tartine et Chocolat
	Tata Harper
	Tatcha
	Tatiana.B
	Tauer
	Taylor Made Organics
	Taylor Swift
	TCQplus
	Tea Natura
	Téane
	Technic
	Tecna
	Ted Lapidus
	Teddy Care
	Teeez Cosmetics
	Tegoder
	Tek
	Téliane
	Temptu
	TENA
	Teñzor
	Téo Cabanel
	Teoxane
	Teraxyl
	Teraxyl
	Termix
	Terra Continens
	Terra Naturi
	Terrabio
	Terractive
	Terraïa
	Terraillon
	Terraké
	TerraPi
	Terre & Sens
	Terre de Couleur
	Terre de France
	Terre de Mars
	Terre de Rose
	Terre des Sens Provence
	terre éternelle
	Terre vivante
	Tesori d'Oriente
	tetesept:
	Tetley
	Tetra Medical
	Teva
	Texture my Way
	TF1 Vidéo
	Thalac
	Thalamag
	Thalazur
	Thalgo
	Thalion
	Thayers
	The 7 Virtues
	The Alchemist Atelier
	The Aromatherapy Co.
	The Aromatherapy Company
	The Bam&Boo
	The Barb’Xpert
	The Barber Company
	The Beauty Chef
	The Beauty Crop
	The Beauty Dept.
	The Body Deli
	The Body Shop
	The Brush Guard
	The Chemistry Brand
	The Cosmetic Republic
	The Different Company
	The emu oil well
	The Face Shop
	The Fragrance People
	The French Herborist
	The Green Emporium
	The hair project
	The History of Whoo
	The Humble Co.
	The Inkey List
	The Innate Life
	The Konjac Sponge Compagny
	THE LAB by blanc doux
	The Lab Room
	The Library of Fragrance
	The Little Alchemist
	the MASK Dr.
	The New Cool
	The Ordinary.
	The Organic Hemp Line
	The Organic Pharmacy
	The Plant Base
	The Pure Candle
	The Real Shaving Co.
	the SAEM
	The Sanctuary
	The Santuary
	The Scottish Fine Soaps Company
	The Sign Tribe
	the skin dr.
	The Skin Lounge
	The Skin Pharmacy
	the smilist
	The Soap & Paper Factory
	the VampStamp
	The Vintage Cosmetic Company
	The Voice
	The-body-shop
	The-ordinary
	Théa Pharma
	theBalm
	TheFaceShop
	Théléma Santé
	Thémaé
	Théobroma Secret Cacao
	Théophile Berthon
	Therabody
	Theralica
	TheraNeem
	Therapi
	Therapie Roques Oneil
	TheraSophia
	Thermobaby
	Thés de la Pagode
	Thetacosm
	Thierry Blondeau
	Thierry Duhec
	Thinkhappy Organic Surge
	Thinx
	Thirdman
	This is it
	ThisWorks
	Thomas Liorac
	Thomas Sabo
	Thomson
	Ti'Mad
	TIA’M
	Tibolli
	Tidoo
	Tierra Mia Organics
	Tiffany & Co.
	Tiger Balm
	Tigex
	TIGI
	Tiki Tahiti
	til
	Tilman
	timeless Skin Care
	Timotei
	Timotei
	Timothy Dunn London
	Tinti
	Tirtir
	Tisane Provençale
	Tisserand Aromatherapy
	Tiyya
	TMEA
	Today
	Tokyomilk
	Tom Ford
	Tommy Hilfiger
	Tommyguns
	Toni&Guy
	Tonic Nature
	TonyMoly
	Too Cool for School
	Too Faced
	TooFruit
	Topicrem
	TopModel parfums
	Toppik
	Topshop
	Torrente
	Tosowoong
	tot herba
	Total Intensity
	TOTHELOVE
	TotsBots
	Touch Organic
	TouchNature
	Tous
	Tous in Heaven
	ToyJoy
	Tradiphar
	Traitance
	Transparent Clinic
	Transvital
	Trap
	Travalo
	Treacle Moon
	Treets Traditions
	trend IT UP
	TrendyLiss
	Tresemme
	TRESemmé
	Trésor du Tchad
	Trevarno
	TREW
	Trezh Babig
	Tridyn
	Trilogy
	Trimincil
	Trind
	Triox
	Tropical Naturals
	Tropicania
	Trudon
	True Botanicals
	True Colors
	True Cover
	True Grace
	True Keratin
	True Organic of Sweden
	True Veda
	TRULY
	Trussardi
	Tulécos
	Tweezerman
	Twenty DC
	TwinLuxe
	TWSOUL
	typology.
	U
	U tout petits - Magasins U
	Uber Cosmetics
	uka
	Uki
	ulé
	Ulric de Varens
	Ulta
	Ultimate Face
	Ultra Violette
	Ultra-doux
	ultrasun
	ultron
	umaï
	Umbro
	Un Monde d'Argan
	Un Monde de Miel
	Unani
	unbottled
	Und Gretel
	Undergreen
	Une fée dans l'asinerie
	Une Heure Pour Moi
	Une Nuit à Bali
	Une Olive en Provence
	Unicorn Makeup Brush
	Unique
	unique Paris
	United Colors of Benetton
	Unixe
	Unkut
	Unlimited
	Unmei
	Unt
	Unyque
	uoga uoga
	Upsylon Dermatology
	URANG
	Urban Care
	Urban Decay
	Urban Keratin
	Urgo
	Uriage
	Uriage
	Uroda
	Ursa Major
	Urtekram
	Usana
	Ushuaia
	Ushuaïa
	Uslu Airlines
	uvas frescas
	UVBIO
	V
	V 10 Plus
	Vaadi herbals
	Vademecum
	Vademecum
	Vahine
	Valcena
	ValDena
	Valdispert
	Valentino
	Valera
	valeve
	Vallée des roses...
	Valmont
	Valöex
	Valona
	Vamousse
	Van Cleef & Arpels
	Van Gils
	Vanessences
	Vania
	Vaniqa
	Vapour
	Vasanti
	Vaseline
	Vaseline
	Vatika
	VàV
	VDL
	VEA
	Vebix
	Vecteur Energy
	Vecteur Santé
	Ved
	Védicare
	Veet
	Veet
	veg-up
	Vegebom
	Vegetable Garden
	Vegetable(s)
	Végétal'Emoi
	Vegeticals
	Vegetocaryl
	Veinomix
	Velan
	Veld's
	Velecta Paramount
	Velform
	Vellino
	Velour Lashes
	Velvera Cosmetics
	Vendara
	Ventilo
	Venus
	Venus & Gaia
	Vera
	Vera Lance
	Vera Valenti
	Vera Wang
	VeraCova
	Veraderm
	Verde Color
	Veronique Gabai
	Versace
	Versed
	Verso
	vertù
	Vetia Floris
	veuch
	Vibraluxe Pro
	Vicco
	Vichy
	Vicks
	Victoria Beckham
	Victoria's Secret
	VictoriaJackson
	Vida Glow
	Vida Lux Cosmetics
	Vidal
	Vigean
	Vigot
	Viktor & Rolf
	Vilhelm Parfumerie
	Villa Botania
	Villa Lodola
	Village 11 Factory
	Vinaesens
	Vinali
	Vine Secret
	Vinésime
	Vino-Cure
	Vinoderm
	Vintner's Daughter
	Viokox
	Violet
	Violette_FR
	virevolte
	Virginale
	Virtue
	Visconti Di Modrone
	Vishnu
	Visoanska
	Visons de St Hilaire
	Vit'All+
	Vita citral
	Vita Coco
	Vita Liberata
	Vita Verde
	Vitabiotics
	Vitacology
	Vitacreme B12
	Vitae Cosmetics
	Vitae Signature
	Vitaflor
	VitaflorBIO
	Vital Beauty
	Vital Proteins
	Vitalba
	Vitale
	Vitality's
	Vitamasques
	VitaOcéan
	VitaSil
	Vitavea
	Vitaya
	Vitry
	Vittel
	Viv'argile
	Vivaldi
	Vivelle-dop
	Vivexin
	Viviscal
	Vivo
	Voesh New York
	voilà.
	Volnay
	voshuiles.com
	Votary
	Voulez-Vous
	Voya
	Voyages Imaginaires
	VT
	Vuarnet
	vVardis
	Vyséo
	W
	W7 Cosmetics
	Waam
	wakati
	Wake Me Up.paris
	Waliwa
	wash wash cousin
	Wash with Joe
	waterclouds
	Waterl'eau
	Watermans
	Waterpik Be
	WaterWipes
	Watsons
	Wax Lyrical
	Wayne Goss
	WBCo
	We are Ipsé
	We Love The Planet
	We-Vibe
	WeDo
	Weleda
	Wella
	Wella
	Wellage
	Welleco
	Wellments
	Welton Design
	Welton London
	Wen by Chaz Dean
	Westlab
	Westman Atelier
	Wet Brush
	Wet n Wild
	Whamisa
	When
	whish
	White-Care
	White-now
	whiteLight
	Widmann
	Wild
	Wild Flower
	Wild Science Lab
	Wild Tiger
	Wilfried and Co
	Wilkinson Sword
	Williams
	Williams
	Wilna Sainvil
	Winky Lux
	Wishful
	Witch
	withings
	Womake
	Woman Essentials
	womanizer
	Womanology
	Wonder Balm
	Wondercoco
	Wonderstripes
	World Wild Men
	Worth
	Wunder2
	Wunderbar
	Wyritol
	X
	X-liso
	XBC Xpel Beauty Care
	Xen-Tan
	XHC Xpel Hair Care
	Xiaomi
	Xiel
	XL-S
	XL-S Medical
	XYGK
	Y
	Y.S.S.Y
	Yadah
	Yalacta
	Yalia
	Yankee Candle
	Yardley
	Yari
	Yarok
	Yaweco
	Ybera
	Yellow Rose
	Yeouth
	yepoda
	Yes
	Yes Love
	Yes One
	Yes To
	Yes!You
	YesCire!
	Yesensy
	YESforLOV
	YesStyle
	Ylaé
	Yllozure
	Ymalia
	ynée.
	Yoba
	Yodi
	Yogah
	Yoghi
	Yoghurt of Bulgaria
	Yogi Tea
	Yohji Yamamoto
	Yolaine
	Yole Beauty
	Yon-Ka
	Yope
	Youngblood
	Younique
	Your Tea
	YourGoodSkin
	Youth Lab.
	Youth to the People
	Ys Park
	Ysiance
	Yu.Be
	Yüli
	Yummie Body
	Yunnan Tuocha
	Yunsey Professional
	Yuthika
	Yva Océan Indien
	Yvan Serras
	Yves Ponroy
	Yves Rocher
	Yves Saint Laurent
	Yves-rocher
	Yves-saint-laurent
	Yvette Laboratory
	Z
	Z.one
	Z&MA
	Zadig & Voltaire
	Zaffiro Organica
	Zambon
	Zao
	Zara
	Zébio
	Zechstein Inside
	Zelens
	Zen Personal Care
	Zen’Arôme
	Zendium
	Zendium
	Zenzitude
	Zero Sensitive Skin
	Zest
	Zeyna
	Ziaja
	Zingus
	Zino
	Zlatan Ibrahimovi&#263;
	Zôdio
	Zoella Beauty
	Zoeva
	Zohi
	Zoly
	Zorah Biocosmétiques
	Zorgan
	Zoya
	Zuccari
	Zuzu Luxe
	Zwitsal
	Zymophar
);

my %baby_food_brands = ();

foreach my $brand (@baby_food_brands) {

	my $brandid = get_string_id_for_lang("no_language", $brand);
	$baby_food_brands{$brandid} = 1;

}

my %cigarette_brands = ();

foreach my $brand (@cigarette_brands) {

	my $brandid = get_string_id_for_lang("no_language", $brand);
	$cigarette_brands{$brandid} = 1;

}

my %petfood_brands = ();

foreach my $brand (@petfood_brands) {

	my $brandid = get_string_id_for_lang("no_language", $brand);
	$petfood_brands{$brandid} = 1;

}

my %beauty_brands = ();

foreach my $brand (@beauty_brands) {

	my $brandid = get_string_id_for_lang("no_language", $brand);
	$beauty_brands{$brandid} = 1;

}

=head1 FUNCTIONS

=head2 detect_categories( PRODUCT_REF )

Detects some categories like baby milk, baby food and cigarettes from other fields
such as brands, product name, generic name and ingredients.

=cut

sub detect_categories ($product_ref) {

	# match on fr product name, generic name, ingredients
	my $match_fr = "";

	(defined $product_ref->{product_name}) and $match_fr .= " " . $product_ref->{product_name};
	(defined $product_ref->{product_name_fr}) and $match_fr .= "  " . $product_ref->{product_name_fr};

	(defined $product_ref->{generic_name}) and $match_fr .= " " . $product_ref->{generic_name};
	(defined $product_ref->{generic_name_fr}) and $match_fr .= "  " . $product_ref->{generic_name_fr};

	(defined $product_ref->{ingredients_text}) and $match_fr .= " " . $product_ref->{ingredients_text};
	(defined $product_ref->{ingredients_text_fr}) and $match_fr .= "  " . $product_ref->{ingredients_text_fr};

	# try to identify baby milks

	if ($match_fr
		=~ /lait ([^,-]* )?(suite|croissance|infantile|bébé|bebe|nourrisson|nourisson|age|maternise|maternisé)/i)
	{
		if (not has_tag($product_ref, "categories", "en:baby-milks")) {
			push @{$product_ref->{data_quality_warnings_tags}},
				"en:detected-category-from-name-and-ingredients-may-be-missing-baby-milks";
		}
	}

	if (defined $product_ref->{brands_tags}) {
		foreach my $brandid (@{$product_ref->{brands_tags}}) {
			if (defined $baby_food_brands{$brandid}) {
				add_tag($product_ref, "data_quality_info", "en:detected-category-from-brand-baby-foods");
			}
			if (defined $cigarette_brands{$brandid}) {
				add_tag($product_ref, "data_quality_info", "en:detected-category-from-brand-cigarettes");
			}
			if (defined $petfood_brands{$brandid}) {
				add_tag($product_ref, "data_quality_info", "en:detected-category-from-brand-pet-foods");
			}
			if (defined $beauty_brands{$brandid}) {
				add_tag($product_ref, "data_quality_info", "en:detected-category-from-brand-beauty");
			}
		}
	}

	return;
}

=head2 check_nutrition_grades( PRODUCT_REF )

Compares the nutrition score and nutrition grade (Nutri-Score) we have computed with
the score and grade provided by manufacturers.

=cut

sub check_nutrition_grades ($product_ref) {

	if ((defined $product_ref->{nutrition_grade_fr_producer}) and (defined $product_ref->{nutrition_grade_fr})) {

		if ($product_ref->{nutrition_grade_fr_producer} eq $product_ref->{nutrition_grade_fr}) {
			push @{$product_ref->{data_quality_info_tags}}, "en:nutrition-grade-fr-producer-same-ok";
		}
		else {
			push @{$product_ref->{data_quality_warnings_tags}}, "en:nutrition-grade-fr-producer-mismatch-nok";
		}
	}

	if (    (defined $product_ref->{nutriments})
		and (defined $product_ref->{nutriments}{"nutrition-score-fr-producer"})
		and (defined $product_ref->{nutriments}{"nutrition-score-fr"}))
	{

		if ($product_ref->{nutriments}{"nutrition-score-fr-producer"} eq
			$product_ref->{nutriments}{"nutrition-score-fr"})
		{
			push @{$product_ref->{data_quality_info_tags}}, "en:nutrition-score-fr-producer-same-ok";
		}
		else {
			push @{$product_ref->{data_quality_warnings_tags}}, "en:nutrition-score-fr-producer-mismatch-nok";
		}
	}

	return;
}

=head2 check_carbon_footprint( PRODUCT_REF )

Checks related to the carbon footprint computed from ingredients analysis.

=cut

sub check_carbon_footprint ($product_ref) {

	if (defined $product_ref->{nutriments}) {

		if ((defined $product_ref->{nutriments}{"carbon-footprint-from-meat-or-fish_100g"})
			and not(defined $product_ref->{nutriments}{"carbon-footprint-from-known-ingredients_100g"}))
		{
			push @{$product_ref->{data_quality_info_tags}},
				"en:carbon-footprint-from-meat-or-fish-but-not-from-known-ingredients";
		}
		if (    (not defined $product_ref->{nutriments}{"carbon-footprint-from-meat-or-fish_100g"})
			and (defined $product_ref->{nutriments}{"carbon-footprint-from-known-ingredients_100g"}))
		{
			push @{$product_ref->{data_quality_info_tags}},
				"en:carbon-footprint-from-known-ingredients-but-not-from-meat-or-fish";
		}
		if (
				(defined $product_ref->{nutriments}{"carbon-footprint-from-meat-or-fish_100g"})
			and (defined $product_ref->{nutriments}{"carbon-footprint-from-known-ingredients_100g"})
			and ($product_ref->{nutriments}{"carbon-footprint-from-meat-or-fish_100g"}
				> $product_ref->{nutriments}{"carbon-footprint-from-known-ingredients_100g"})
			)
		{
			push @{$product_ref->{data_quality_warnings_tags}},
				"en:carbon-footprint-from-known-ingredients-less-than-from-meat-or-fish";
		}
		if (
				(defined $product_ref->{nutriments}{"carbon-footprint-from-meat-or-fish_100g"})
			and (defined $product_ref->{nutriments}{"carbon-footprint-from-known-ingredients_100g"})
			and ($product_ref->{nutriments}{"carbon-footprint-from-meat-or-fish_100g"}
				< $product_ref->{nutriments}{"carbon-footprint-from-known-ingredients_100g"})
			)
		{
			push @{$product_ref->{data_quality_info_tags}},
				"en:carbon-footprint-from-known-ingredients-more-than-from-meat-or-fish";
		}
	}

	return;
}

=head2 check_nutrition_data_energy_computation ( PRODUCT_REF )

Checks related to the nutrition facts values.

In particular, checks for obviously invalid values (e.g. more than 105 g of any nutrient for 100 g / 100 ml).
105 g is used instead of 100 g, because for some liquids, 100 ml can weight more than 100 g.

=cut

# Nutrients to energy conversion
# Currently only supporting Europe's method (similar to US and Canada 4-4-9, 4-4-9-7 and 4-4-9-7-2)

my %energy_from_nutrients = (
	europe => {
		carbohydrates_minus_polyols => {kj => 17, kcal => 4},
		polyols_minus_erythritol => {kj => 10, kcal => 2.4},
		proteins => {kj => 17, kcal => 4},
		fat => {kj => 37, kcal => 9},
		salatrim => {kj => 25, kcal => 6},    # no corresponding nutrients in nutrient tables?
		alcohol => {kj => 29, kcal => 7},
		organic_acids => {kj => 13, kcal => 3},    # no corresponding nutrients in nutrient tables?
		fiber => {kj => 8, kcal => 2},
		erythritol => {kj => 0, kcal => 0},
	},
);

sub check_nutrition_data_energy_computation ($product_ref) {

	my $nutriments_ref = $product_ref->{nutriments};

	if (not defined $nutriments_ref) {
		return;
	}

	# Different countries allow different ways to determine energy
	# One way is to compute energy from other nutrients
	# We can thus try to use energy as a key to verify other nutrients

	# See https://esha.com/blog/calorie-calculation-country/
	# and https://eur-lex.europa.eu/legal-content/FR/TXT/HTML/?uri=CELEX:32011R1169&from=FR Appendix XIV

	foreach my $unit ("kj", "kcal") {

		my $specified_energy = $nutriments_ref->{"energy-${unit}_value"};
		# We need at a minimum carbohydrates, fat and proteins to be defined to compute
		# energy.
		if (    (defined $specified_energy)
			and (defined $nutriments_ref->{"carbohydrates_value"})
			and (defined $nutriments_ref->{"fat_value"})
			and (defined $nutriments_ref->{"proteins_value"}))
		{

			# Compute the energy from other nutrients
			my $computed_energy = 0;
			foreach my $nid (keys %{$energy_from_nutrients{europe}}) {

				my $energy_per_gram = $energy_from_nutrients{europe}{$nid}{$unit};
				my $grams = 0;
				# handles nutriment1__minus__nutriment2 case
				if ($nid =~ /_minus_/) {
					my $nid_minus = $';
					$nid = $`;

					# If we are computing carbohydrates minus polyols, and we do not have a value for polyols
					# but we have a value for erythritol (which is a polyol), then we need to remove erythritol
					if (($nid_minus eq "polyols") and (not defined $product_ref->{nutriments}{$nid_minus . "_value"})) {
						$nid_minus = "erythritol";
					}
					# Similarly for polyols minus erythritol
					if (($nid eq "polyols") and (not defined $product_ref->{nutriments}{$nid . "_value"})) {
						$nid = "erythritol";
					}

					$grams -= $product_ref->{nutriments}{$nid_minus . "_value"} || 0;
				}
				$grams += $product_ref->{nutriments}{$nid . "_value"} || 0;
				$computed_energy += $grams * $energy_per_gram;
			}

			# following error/warning should be ignored for some categories
			# for example, lemon juices containing organic acid, it is forbidden to display organic acid in nutrition tables but
			# organic acid contributes to the total energy calculation
			my ($ignore_energy_calculated_error, $category_id)
				= get_inherited_property_from_categories_tags($product_ref, "ignore_energy_calculated_error:en");

			if (
				(
					not((defined $ignore_energy_calculated_error) and ($ignore_energy_calculated_error eq 'yes'))
					# consider only when energy is high enough to minimize false positives (issue #7789)
					# consider either computed_energy or energy input by contributor, to avoid when the energy is 5, but it should be 1500
					and (
						(($unit eq "kj") and (($specified_energy > 55) or ($computed_energy > 55)))
						or (    ($unit eq "kcal")
							and (($specified_energy > 13) or ($computed_energy > 13)))
					)
				)
				)
			{
				# Compare to specified energy value with a tolerance of 30% + an additiontal tolerance of 5
				if (   ($computed_energy < ($specified_energy * 0.7 - 5))
					or ($computed_energy > ($specified_energy * 1.3 + 5)))
				{
					# we have a quality problem
					push @{$product_ref->{data_quality_errors_tags}},
						"en:energy-value-in-$unit-does-not-match-value-computed-from-other-nutrients";
				}

				# Compare to specified energy value with a tolerance of 15% + an additiontal tolerance of 5
				if (   ($computed_energy < ($specified_energy * 0.85 - 5))
					or ($computed_energy > ($specified_energy * 1.15 + 5)))
				{
					# we have a quality warning
					push @{$product_ref->{data_quality_warnings_tags}},
						"en:energy-value-in-$unit-may-not-match-value-computed-from-other-nutrients";
				}
			}

			$nutriments_ref->{"energy-${unit}_value_computed"} = $computed_energy;
		}
		else {
			delete $nutriments_ref->{"energy-${unit}_value_computed"};
		}
	}

	return;
}

=head2 check_nutrition_data( PRODUCT_REF )

Checks related to the nutrition facts values.

In particular, checks for obviously invalid values (e.g. more than 105 g of any nutrient for 100 g / 100 ml).
105 g is used instead of 100 g, because for some liquids, 100 ml can weight more than 100 g.

=cut

sub check_nutrition_data ($product_ref) {

	if ((defined $product_ref->{multiple_nutrition_data}) and ($product_ref->{multiple_nutrition_data} eq 'on')) {

		push @{$product_ref->{data_quality_info_tags}}, "en:multiple-nutrition-data";

		if ((defined $product_ref->{not_comparable_nutrition_data}) and $product_ref->{not_comparable_nutrition_data}) {
			push @{$product_ref->{data_quality_info_tags}}, "en:not-comparable-nutrition-data";
		}
	}
	my $is_dried_product = has_tag($product_ref, "categories", "en:dried-products-to-be-rehydrated");

	my $nutrition_data_prepared
		= defined $product_ref->{nutrition_data_prepared} && $product_ref->{nutrition_data_prepared} eq 'on';
	my $no_nutrition_data = defined $product_ref->{no_nutrition_data} && $product_ref->{no_nutrition_data} eq 'on';
	my $nutrition_data = defined $product_ref->{nutrition_data} && $product_ref->{nutrition_data} eq 'on';

	$log->debug("nutrition_data_prepared: " . $nutrition_data_prepared) if $log->debug();

	if ($no_nutrition_data) {
		push @{$product_ref->{data_quality_info_tags}}, "en:no-nutrition-data";
	}
	else {
		if ($nutrition_data_prepared) {
			push @{$product_ref->{data_quality_info_tags}}, "en:nutrition-data-prepared";

			if (not $is_dried_product) {
				push @{$product_ref->{data_quality_warnings_tags}},
					"en:nutrition-data-prepared-without-category-dried-products-to-be-rehydrated";
			}
		}

		# catch serving_size = "serving", regardless of setting (per 100g or per serving)
		if (    (defined $product_ref->{serving_size})
			and ($product_ref->{serving_size} ne "")
			and ($product_ref->{serving_size} ne "-")
			and ($product_ref->{serving_size} !~ /\d/))
		{
			push @{$product_ref->{data_quality_errors_tags}}, "en:serving-size-is-missing-digits";
		}
		if (    $nutrition_data
			and (defined $product_ref->{nutrition_data_per})
			and ($product_ref->{nutrition_data_per} eq 'serving'))
		{
			if ((not defined $product_ref->{serving_size}) or ($product_ref->{serving_size} eq '')) {
				push @{$product_ref->{data_quality_errors_tags}}, "en:nutrition-data-per-serving-missing-serving-size";
			}
			elsif (defined $product_ref->{serving_quantity} and $product_ref->{serving_quantity} eq "0") {
				push @{$product_ref->{data_quality_errors_tags}}, "en:nutrition-data-per-serving-serving-quantity-is-0";
			}
		}
	}

	my $has_prepared_data = 0;

	if (defined $product_ref->{nutriments}) {

		my $total = 0;
		# variables to check if there are 3 or more duplicates in nutriments
		my @major_nutriments_values = ();
		my %nutriments_values_occurences = ();
		my %nutriments_values = ();

		if (    (defined $product_ref->{nutriments}{"energy-kcal_value"})
			and (defined $product_ref->{nutriments}{"energy-kj_value"}))
		{

			# energy in kcal greater than in kj
			if ($product_ref->{nutriments}{"energy-kcal_value"} > $product_ref->{nutriments}{"energy-kj_value"}) {
				push @{$product_ref->{data_quality_errors_tags}}, "en:energy-value-in-kcal-greater-than-in-kj";

				# additionally check if kcal value and kj value are reversed. Exact opposite condition as next error below
				if (
					(
						$product_ref->{nutriments}{"energy-kcal_value"}
						> 3.7 * $product_ref->{nutriments}{"energy-kj_value"} - 2
					)
					and ($product_ref->{nutriments}{"energy-kcal_value"}
						< 4.7 * $product_ref->{nutriments}{"energy-kj_value"} + 2)
					)
				{
					push @{$product_ref->{data_quality_errors_tags}}, "en:energy-value-in-kcal-and-kj-are-reversed";
				}
			}

			# check energy in kcal is ~ 4.2 (+/- 0.5) energy in kj
			#   +/- 2 to avoid false positives due to rounded values below 2 Kcal.
			#   Eg. 1.49 Kcal -> 6.26 KJ in reality, can be rounded by the producer to 1 Kcal -> 6 KJ.
			if (
				(
					$product_ref->{nutriments}{"energy-kj_value"}
					< 3.7 * $product_ref->{nutriments}{"energy-kcal_value"} - 2
				)
				or ($product_ref->{nutriments}{"energy-kj_value"}
					> 4.7 * $product_ref->{nutriments}{"energy-kcal_value"} + 2)
				)
			{
				push @{$product_ref->{data_quality_errors_tags}}, "en:energy-value-in-kcal-does-not-match-value-in-kj";
			}
		}

		foreach my $nid (sort keys %{$product_ref->{nutriments}}) {
			$log->debug("nid: " . $nid . ": " . $product_ref->{nutriments}{$nid}) if $log->is_debug();

			if ($nid =~ /_prepared_100g$/ && $product_ref->{nutriments}{$nid} > 0) {
				$has_prepared_data = 1;
			}

			if ($nid =~ /_100g/) {

				my $nid2 = $`;
				$nid2 =~ s/_/-/g;

				if (($nid !~ /energy/) and ($nid !~ /footprint/) and ($product_ref->{nutriments}{$nid} > 105)) {
					# product opener / ingredients analysis issue (See issue #10064)
					if ($nid =~ /estimate/) {
						push @{$product_ref->{data_quality_warnings_tags}}, "en:nutrition-value-over-105-$nid2";
					}
					else {
						push @{$product_ref->{data_quality_errors_tags}}, "en:nutrition-value-over-105-$nid2";
					}
				}

				if (($nid !~ /energy/) and ($nid !~ /footprint/) and ($product_ref->{nutriments}{$nid} > 1000)) {
					# product opener / ingredients analysis issue (See issue #10064)
					if ($nid =~ /estimate/) {
						push @{$product_ref->{data_quality_warnings_tags}}, "en:nutrition-value-over-1000-$nid2";
					}
					else {
						push @{$product_ref->{data_quality_errors_tags}}, "en:nutrition-value-over-1000-$nid2";
					}
				}

				if (($product_ref->{nutriments}{$nid} < 0) and (index($nid, "nutrition-score") == -1)) {
					# product opener / ingredients analysis issue (See issue #10064)
					if ($nid =~ /estimate/) {
						push @{$product_ref->{data_quality_warnings_tags}}, "en:nutrition-value-negative-$nid2";
					}
					else {
						push @{$product_ref->{data_quality_errors_tags}}, "en:nutrition-value-negative-$nid2";
					}
				}
			}

			if (    (defined $product_ref->{nutriments}{$nid . "_100g"})
				and (($nid eq 'fat') or ($nid eq 'carbohydrates') or ($nid eq 'proteins') or ($nid eq 'salt')))
			{
				$total += $product_ref->{nutriments}{$nid . "_100g"};
			}

			# variables to check if there are many duplicates in nutriments
			if (   ($nid eq 'energy-kj_100g')
				or ($nid eq 'energy-kcal_100g')
				or ($nid eq 'fat_100g')
				or ($nid eq 'saturated-fat_100g')
				or ($nid eq 'carbohydrates_100g')
				or ($nid eq 'sugars_100g')
				or ($nid eq 'fiber_100g')
				or ($nid eq 'proteins_100g')
				or ($nid eq 'salt_100g')
				or ($nid eq 'sodium_100g'))
			{
				push(@major_nutriments_values, $product_ref->{nutriments}{$nid});
				$nutriments_values{$nid} = $product_ref->{nutriments}{$nid};
			}

		}

		# create a hash key: nutriment value, value: number of occurences
		foreach my $nutriment_value (@major_nutriments_values) {
			if (exists($nutriments_values_occurences{$nutriment_value})) {
				$nutriments_values_occurences{$nutriment_value}++;
			}
			else {
				$nutriments_values_occurences{$nutriment_value} = 1;
			}
		}
		# retrieve max number of occurences
		my $nutriments_values_occurences_max_value = -1;
		# raise warning if there are 3 or more duplicates in nutriments and nutriment is above 1
		foreach my $key (keys %nutriments_values_occurences) {
			if (($nutriments_values_occurences{$key} > 2) and ($key > 1)) {
				add_tag($product_ref, "data_quality_warnings", "en:nutrition-3-or-more-values-are-identical");
			}
			if ($nutriments_values_occurences{$key} > $nutriments_values_occurences_max_value) {
				$nutriments_values_occurences_max_value = $nutriments_values_occurences{$key};
			}
		}
		# raise error if
		# all values are identical
		# and values (check first value only) are above 1 (see issue #9572)
		#  OR
		# all values but one - because sodium and salt can be automatically calculated one depending on the value of the other - are identical
		# and values (check salt (should not check sodium which could be lower)) are above 1 (see issue #9572)
		# and at least 4 values are input by contributors (see issue #9572)
		if (
			(
				(
					$nutriments_values_occurences_max_value == scalar @major_nutriments_values
					and ($major_nutriments_values[0] > 1)
				)
				or (
					($nutriments_values_occurences_max_value >= scalar @major_nutriments_values - 1)
					and (   (defined $nutriments_values{'salt_100g'})
						and (defined $nutriments_values{'sodium_100g'})
						and ($nutriments_values{'salt_100g'} != $nutriments_values{'sodium_100g'})
						and ($nutriments_values{'salt_100g'} > 1))
				)
			)
			and (scalar @major_nutriments_values > 3)
			)
		{
			push @{$product_ref->{data_quality_errors_tags}}, "en:nutrition-values-are-all-identical";
		}

		if ($total > 105) {
			push @{$product_ref->{data_quality_errors_tags}}, "en:nutrition-value-total-over-105";
		}
		if ($total > 1000) {
			push @{$product_ref->{data_quality_errors_tags}}, "en:nutrition-value-total-over-1000";
		}

		if (    (defined $product_ref->{nutriments}{"energy_100g"})
			and ($product_ref->{nutriments}{"energy_100g"} > 3800))
		{
			push @{$product_ref->{data_quality_errors_tags}}, "en:nutrition-value-over-3800-energy";
		}

		# sugar + starch cannot be greater than carbohydrates
		# do not raise error if sugar or starch contains "<" symbol (see issue #9267)
		if (
			(defined $product_ref->{nutriments}{"carbohydrates_100g"})
			and (
				# without "<" symbol, check sum of sugar and starch is not greater than carbohydrates
				(
					(
						(
							(
								(defined $product_ref->{nutriments}{"sugars_100g"})
								? $product_ref->{nutriments}{"sugars_100g"}
								: 0
							) + (
								(defined $product_ref->{nutriments}{"starch_100g"})
								? $product_ref->{nutriments}{"starch_100g"}
								: 0
							)
						) > ($product_ref->{nutriments}{"carbohydrates_100g"}) + 0.001
					)
					and not(defined $product_ref->{nutriments}{"sugar_modifier"})
					and not(defined $product_ref->{nutriments}{"starch_modifier"})
				)
				or
				# with "<" symbo, check only that sugar or starch are not greater than carbohydrates
				(
					(
						(
								(defined $product_ref->{nutriments}{"sugar_modifier"})
							and ($product_ref->{nutriments}{"sugar_modifier"} eq "<")
						)
						and (
							(
								(defined $product_ref->{nutriments}{"sugars_100g"})
								? $product_ref->{nutriments}{"sugars_100g"}
								: 0
							) > ($product_ref->{nutriments}{"carbohydrates_100g"}) + 0.001
						)
					)
					or (
						(
								(defined $product_ref->{nutriments}{"starch_modifier"})
							and ($product_ref->{nutriments}{"starch_modifier"} eq "<")
						)
						and (
							(
								(defined $product_ref->{nutriments}{"starch_100g"})
								? $product_ref->{nutriments}{"starch_100g"}
								: 0
							) > ($product_ref->{nutriments}{"carbohydrates_100g"}) + 0.001
						)
					)
				)
			)
			)
		{

			push @{$product_ref->{data_quality_errors_tags}},
				"en:nutrition-sugars-plus-starch-greater-than-carbohydrates";
		}

		# sum of nutriments that compose sugar can not be greater than sugar value
		if (defined $product_ref->{nutriments}{sugars_100g}) {
			my $fructose
				= defined $product_ref->{nutriments}{fructose_100g} ? $product_ref->{nutriments}{fructose_100g} : 0;
			my $glucose
				= defined $product_ref->{nutriments}{glucose_100g} ? $product_ref->{nutriments}{glucose_100g} : 0;
			my $maltose
				= defined $product_ref->{nutriments}{maltose_100g} ? $product_ref->{nutriments}{maltose_100g} : 0;
			# sometimes lactose < 0.01 is written below the nutrition table together whereas
			# sugar is 0 in the nutrition table (#10715)
			my $sucrose
				= defined $product_ref->{nutriments}{sucrose_100g} ? $product_ref->{nutriments}{sucrose_100g} : 0;

			# ignore lactose when having "<" symbol
			my $lactose = 0;
			if (defined $product_ref->{nutriments}{lactose_100g}) {
				my $lactose_modifier = $product_ref->{nutriments}{'lactose_modifier'};
				if (!defined $lactose_modifier || $lactose_modifier ne '<') {
					$lactose = $product_ref->{nutriments}{lactose_100g};
				}
			}

			my $total_sugar = $fructose + $glucose + $maltose + $lactose + $sucrose;

			if ($total_sugar > $product_ref->{nutriments}{sugars_100g} + 0.001) {
				push @{$product_ref->{data_quality_errors_tags}},
					"en:nutrition-fructose-plus-glucose-plus-maltose-plus-lactose-plus-sucrose-greater-than-sugars";
			}
		}

		if (    (defined $product_ref->{nutriments}{"saturated-fat_100g"})
			and (defined $product_ref->{nutriments}{"fat_100g"})
			and ($product_ref->{nutriments}{"saturated-fat_100g"} > ($product_ref->{nutriments}{"fat_100g"} + 0.001)))
		{

			push @{$product_ref->{data_quality_errors_tags}}, "en:nutrition-saturated-fat-greater-than-fat";

		}

		# sum of nutriments that compose fiber can not be greater than the value of fiber
		# ignore if there is "<" symbol (example: <1 + 5 = 5, issue #11075)
		if (defined $product_ref->{nutriments}{fiber_100g}) {
			my $soluble_fiber = 0;
			my $insoluble_fiber = 0;

			if (defined $product_ref->{nutriments}{'soluble-fiber_100g'}) {
				my $soluble_modifier = $product_ref->{nutriments}{'soluble-fiber_modifier'};
				if (!defined $soluble_modifier || $soluble_modifier ne '<') {
					$soluble_fiber = $product_ref->{nutriments}{'soluble-fiber_100g'};
				}
			}

			if (defined $product_ref->{nutriments}{'insoluble-fiber_100g'}) {
				my $insoluble_modifier = $product_ref->{nutriments}{'insoluble-fiber_modifier'};
				if (!defined $insoluble_modifier || $insoluble_modifier ne '<') {
					$insoluble_fiber = $product_ref->{nutriments}{'insoluble-fiber_100g'};
				}
			}

			my $total_fiber = $soluble_fiber + $insoluble_fiber;

			# increased threshold from 0.001 to 0.01 (see issue #10491)
			# make sure that floats stop after 2 decimals
			if (sprintf("%.2f", $total_fiber) > sprintf("%.2f", $product_ref->{nutriments}{fiber_100g} + 0.01)) {
				push @{$product_ref->{data_quality_errors_tags}},
					"en:nutrition-soluble-fiber-plus-insoluble-fiber-greater-than-fiber";
			}
		}

		# Too small salt value? (e.g. g entered in mg)
		# warning for salt < 0.1 was removed because it was leading to too much false positives (see #9346)
		if ((defined $product_ref->{nutriments}{"salt_100g"}) and ($product_ref->{nutriments}{"salt_100g"} > 0)) {

			if ($product_ref->{nutriments}{"salt_100g"} < 0.001) {
				push @{$product_ref->{data_quality_warnings_tags}}, "en:nutrition-value-under-0-001-g-salt";
			}
			elsif ($product_ref->{nutriments}{"salt_100g"} < 0.01) {
				push @{$product_ref->{data_quality_warnings_tags}}, "en:nutrition-value-under-0-01-g-salt";
			}
		}

		# some categories have expected nutriscore grade - push data quality error if calculated nutriscore grade differs from expected nutriscore grade or if it is not calculated
		my ($expected_nutriscore_grade, $category_id)
			= get_inherited_property_from_categories_tags($product_ref, "expected_nutriscore_grade:en");

		if (
			# exclude error if nutriscore cannot be calculated due to missing nutrients information (see issue #9297)
			(
					(defined $product_ref->{nutriscore}{2023}{nutrients_available})
				and ($product_ref->{nutriscore}{2023}{nutrients_available} == 1)
			)
			# we expect single letter a, b, c, d, e for nutriscore grade in the taxonomy. Case insensitive (/i).
			and (defined $expected_nutriscore_grade)
			and (($expected_nutriscore_grade =~ /^([a-e]){1}$/i))
			# nutriscore calculated but unexpected nutriscore grade
			and (defined $product_ref->{nutrition_grade_fr})
			and ($product_ref->{nutrition_grade_fr} ne $expected_nutriscore_grade)
			)
		{
			push @{$product_ref->{data_quality_errors_tags}},
				"en:nutri-score-grade-from-category-does-not-match-calculated-grade";
		}
	}
	$log->debug("has_prepared_data: " . $has_prepared_data) if $log->debug();

	# issue 1466: Add quality facet for dehydrated products that are missing prepared values
	if ($is_dried_product && ($no_nutrition_data || !($nutrition_data_prepared && $has_prepared_data))) {
		push @{$product_ref->{data_quality_warnings_tags}},
			"en:missing-nutrition-data-prepared-with-category-dried-products-to-be-rehydrated";
	}

	return;
}

=head2 compare_nutrition_facts_with_products_from_the_same_category( PRODUCT_REF )

Check that the product nutrition facts are comparable to other products from the same category.

Compare with the most specific category that has enough products to compute stats.

=cut

sub compare_nutrition_facts_with_products_from_same_category ($product_ref) {

	my $categories_nutriments_ref = $categories_nutriments_per_country{"world"};

	$log->debug("compare_nutrition_facts_with_products_from_same_category - start") if $log->debug();

	return if not defined $product_ref->{nutriments};
	return if not defined $product_ref->{categories_tags};

	my $i = @{$product_ref->{categories_tags}} - 1;

	while (
		($i >= 0)
		and not((defined $categories_nutriments_ref->{$product_ref->{categories_tags}[$i]})
			and (defined $categories_nutriments_ref->{$product_ref->{categories_tags}[$i]}{nutriments}))
		)
	{
		$i--;
	}
	# categories_tags has the most specific categories at the end

	if ($i >= 0) {

		my $specific_category = $product_ref->{categories_tags}[$i];
		$product_ref->{compared_to_category} = $specific_category;

		$log->debug("compare_nutrition_facts_with_products_from_same_category",
			{specific_category => $specific_category})
			if $log->is_debug();

		# check major nutrients
		my @nutrients = qw(energy fat saturated-fat carbohydrates sugars fiber proteins salt);

		foreach my $nid (@nutrients) {

			if (    (defined $product_ref->{nutriments}{$nid . "_100g"})
				and ($product_ref->{nutriments}{$nid . "_100g"} ne "")
				and (defined $categories_nutriments_ref->{$specific_category}{nutriments}{$nid . "_std"}))
			{

				# check if the value is in the range of the mean +- 3 * standard deviation
				# (for Gaussian distributions, this range contains 99.7% of the values)
				# note: we remove the bottom and top 5% before computing the std (to remove data errors that change the mean and std)
				# the computed std is smaller.
				# Too many values are outside mean +- 3 * std, try 4 * std

				$log->debug(
					"compare_nutrition_facts_with_products_from_same_category",
					{
						nid => $nid,
						product_100g => $product_ref->{nutriments}{$nid . "_100g"},
						category_100g => $categories_nutriments_ref->{$specific_category}{nutriments}{$nid . "_100g"},
						category_std => $categories_nutriments_ref->{$specific_category}{nutriments}{$nid . "_std"}
					}
				) if $log->is_debug();

				if (
					$product_ref->{nutriments}{$nid . "_100g"} < (
						$categories_nutriments_ref->{$specific_category}{nutriments}{$nid . "_100g"}
							- 4 * $categories_nutriments_ref->{$specific_category}{nutriments}{$nid . "_std"}
					)
					)
				{

					push @{$product_ref->{data_quality_warnings_tags}},
						"en:nutrition-value-very-low-for-category-" . $nid;
				}
				elsif (
					$product_ref->{nutriments}{$nid . "_100g"} > (
						$categories_nutriments_ref->{$specific_category}{nutriments}{$nid . "_100g"}
							+ 4 * $categories_nutriments_ref->{$specific_category}{nutriments}{$nid . "_std"}
					)
					)
				{

					push @{$product_ref->{data_quality_warnings_tags}},
						"en:nutrition-value-very-high-for-category-" . $nid;
				}
			}
		}
	}

	return;
}

sub calculate_digit_percentage ($text) {

	return 0.0 if not defined $text;

	my $tl = length($text);
	return 0.0 if $tl <= 0;

	my $dc = () = $text =~ /\d/g;
	return $dc / ($tl * 1.0);
}

=head2 check_ingredients( PRODUCT_REF )

Checks related to the ingredients list and ingredients analysis.

=cut

sub check_ingredients ($product_ref) {

	# spell corrected additives

	if ((defined $product_ref->{additives}) and ($product_ref->{additives} =~ /spell correction/)) {
		push @{$product_ref->{data_quality_warnings_tags}}, "en:ingredients-spell-corrected-additives";
	}

	# Multiple languages in ingredient lists

	my $nb_languages = 0;

	if (defined $product_ref->{ingredients_text}) {
		($product_ref->{ingredients_text} =~ /\b(ingrédients|sucre|eau|sel|farine)\b/i) and $nb_languages++;
		($product_ref->{ingredients_text} =~ /\b(sugar|salt|flour|milk)\b/i) and $nb_languages++;
		($product_ref->{ingredients_text} =~ /\b(ingrediënten|suiker|zout|bloem)\b/i) and $nb_languages++;
		($product_ref->{ingredients_text} =~ /\b(azucar|agua|harina)\b/i) and $nb_languages++;
		($product_ref->{ingredients_text} =~ /\b(zutaten|Zucker|Salz|Wasser|Mehl)\b/i) and $nb_languages++;
		($product_ref->{ingredients_text} =~ /\b(açúcar|farinha|água)\b/i) and $nb_languages++;
		($product_ref->{ingredients_text} =~ /\b(ingredienti|zucchero|farina|acqua)\b/i) and $nb_languages++;
	}

	if ($nb_languages > 1) {
		foreach my $max (5, 4, 3, 2, 1) {
			if ($nb_languages > $max) {
				push @{$product_ref->{data_quality_warnings_tags}}, "en:ingredients-number-of-languages-above-$max";
			}
		}
		push @{$product_ref->{data_quality_warnings_tags}}, "en:ingredients-number-of-languages-$nb_languages";
	}

	if ((defined $product_ref->{ingredients_n}) and ($product_ref->{ingredients_n} > 0)) {

		my $score = $product_ref->{unknown_ingredients_n} * 2 - $product_ref->{ingredients_n};

		foreach my $max (50, 40, 30, 20, 10, 5, 0) {
			if ($score > $max) {
				push @{$product_ref->{data_quality_warnings_tags}}, "en:ingredients-unknown-score-above-$max";
				last;
			}
		}

		foreach my $max (100, 90, 80, 70, 60, 50) {
			if (($product_ref->{unknown_ingredients_n} / $product_ref->{ingredients_n}) >= ($max / 100)) {
				push @{$product_ref->{data_quality_warnings_tags}}, "en:ingredients-$max-percent-unknown";
				last;
			}
		}
	}

	if (defined $product_ref->{ingredients_tags}) {

		my $max_length = 0;

		foreach my $ingredient_tag (@{$product_ref->{ingredients_tags}}) {
			my $length = length($ingredient_tag);
			$length > $max_length and $max_length = $length;
		}

		foreach my $max_length_threshold (50, 100, 200, 500, 1000) {

			if ($max_length > $max_length_threshold) {

				push @{$product_ref->{data_quality_warnings_tags}},
					"en:ingredients-ingredient-tag-length-greater-than-" . $max_length_threshold;

			}
		}
	}

	if (    (defined $product_ref->{ingredients_text})
		and (calculate_digit_percentage($product_ref->{ingredients_text}) > 0.3))
	{
		push @{$product_ref->{data_quality_warnings_tags}}, 'en:ingredients-over-30-percent-digits';
	}

	if (defined $product_ref->{languages_codes}) {

		foreach my $display_lc (keys %{$product_ref->{languages_codes}}) {

			my $ingredients_text_lc = "ingredients_text_" . ${display_lc};

			if (defined $product_ref->{$ingredients_text_lc}) {

				$log->debug("ingredients text", {quality => $product_ref->{$ingredients_text_lc}}) if $log->is_debug();

				if (calculate_digit_percentage($product_ref->{$ingredients_text_lc}) > 0.3) {
					push @{$product_ref->{data_quality_warnings_tags}},
						'en:ingredients-' . $display_lc . '-over-30-percent-digits';
				}

				if ($product_ref->{$ingredients_text_lc} =~ /,(\s*)$/is) {

					push @{$product_ref->{data_quality_warnings_tags}},
						"en:ingredients-" . $display_lc . "-ending-comma";
				}

				if ($product_ref->{$ingredients_text_lc} =~ /[aeiouy]{5}/is) {

					push @{$product_ref->{data_quality_warnings_tags}}, "en:ingredients-" . $display_lc . "-5-vowels";
				}

				# Dutch and other languages can have 4 consecutive consonants
				if ($display_lc !~ /de|hr|nl|pl/) {
					if ($product_ref->{$ingredients_text_lc} =~ /[bcdfghjklmnpqrstvwxz]{5}/is) {

						push @{$product_ref->{data_quality_warnings_tags}},
							"en:ingredients-" . $display_lc . "-5-consonants";
					}
				}

				if ($product_ref->{$ingredients_text_lc} =~ /(.)\1{4,}/is) {

					push @{$product_ref->{data_quality_warnings_tags}},
						"en:ingredients-" . $display_lc . "-4-repeated-chars";
				}

				if ($product_ref->{$ingredients_text_lc} =~ /[\$\€\£\¥\₩]/is) {

					push @{$product_ref->{data_quality_warnings_tags}},
						"en:ingredients-" . $display_lc . "-unexpected-chars-currencies";
				}

				if ($product_ref->{$ingredients_text_lc} =~ /[\@]/is) {

					push @{$product_ref->{data_quality_warnings_tags}},
						"en:ingredients-" . $display_lc . "-unexpected-chars-arobase";
				}

				if ($product_ref->{$ingredients_text_lc} =~ /[\!]/is) {

					push @{$product_ref->{data_quality_warnings_tags}},
						"en:ingredients-" . $display_lc . "-unexpected-chars-exclamation-mark";
				}

				if ($product_ref->{$ingredients_text_lc} =~ /[\?]/is) {

					push @{$product_ref->{data_quality_warnings_tags}},
						"en:ingredients-" . $display_lc . "-unexpected-chars-question-mark";
				}

				if ($product_ref->{$ingredients_text_lc} =~ /http/i) {
					add_tag($product_ref, "data_quality_errors", "en:ingredients-" . $display_lc . "-unexpected-url");
				}

				# French specific
				#if ($display_lc eq 'fr') {

				if ($product_ref->{$ingredients_text_lc}
					=~ /kcal|glucides|(dont sucres)|(dont acides gras)|(valeurs nutri)/is)
				{

					push @{$product_ref->{data_quality_warnings_tags}},
						"en:ingredients-" . $display_lc . "-includes-fr-nutrition-facts";
				}

				if ($product_ref->{$ingredients_text_lc}
					=~ /(à conserver)|(conditions de )|(à consommer )|(plus d'info)|consigne/is)
				{

					push @{$product_ref->{data_quality_warnings_tags}},
						"en:ingredients-" . $display_lc . "-includes-fr-instructions";
				}
				#}
			}

		}

	}

	my $agr_bio = qr/
		(ingrédients issus de l'Agriculture Biologique)
		|(aus biologischer Landwirtschaft)
		|(aus kontrolliert ökologischer Landwirtschaft)
		|(Zutaten aus ökol. Landwirtschaft)
	/x;

	if (    (defined $product_ref->{ingredients_text})
		and (($product_ref->{ingredients_text} =~ /$agr_bio/is) && !has_tag($product_ref, "labels", "en:organic")))
	{
		push @{$product_ref->{data_quality_warnings_tags}}, 'en:organic-ingredients-but-no-organic-label';
	}

	return;
}

=head2 check_quantity( PRODUCT_REF )

Checks related to the quantity and serving quantity.

=cut

# Check quantity values. See https://en.wiki.openfoodfacts.org/Products_quantities
sub check_quantity ($product_ref) {

	# quantity contains "e" - might be an indicator that the user might have wanted to use "℮" \N{U+212E}
	# example: 650 g e
	if (
		(defined $product_ref->{quantity})
		# contains "kg e", or "g e", or "cl e", etc.
		and ($product_ref->{quantity} =~ /(?:[0-9]+\s*[kmc]?[gl]\s*e)/i)
		# contains the "℮" symbol
		and (not($product_ref->{quantity} =~ /\N{U+212E}/i))
		)
	{
		push @{$product_ref->{data_quality_info_tags}}, "en:quantity-contains-e";
	}

	if (    (defined $product_ref->{quantity})
		and ($product_ref->{quantity} ne "")
		and (not defined $product_ref->{product_quantity}))
	{
		push @{$product_ref->{data_quality_warnings_tags}}, "en:quantity-not-recognized";
	}

	if ((defined $product_ref->{product_quantity}) and ($product_ref->{product_quantity} ne "")) {
		if ($product_ref->{product_quantity} > 10 * 1000) {
			push @{$product_ref->{data_quality_warnings_tags}}, "en:product-quantity-over-10kg";

			if ($product_ref->{product_quantity} > 30 * 1000) {
				push @{$product_ref->{data_quality_errors_tags}}, "en:product-quantity-over-30kg";
			}
		}
		if ($product_ref->{product_quantity} < 1) {
			push @{$product_ref->{data_quality_warnings_tags}}, "en:product-quantity-under-1g";
		}

		if (defined $product_ref->{quantity} && $product_ref->{quantity} ne '') {
			if ($product_ref->{quantity} =~ /\d\s?mg\b/i) {
				push @{$product_ref->{data_quality_warnings_tags}}, "en:product-quantity-in-mg";
			}
		}
	}

	if ((defined $product_ref->{serving_quantity}) and ($product_ref->{serving_quantity} ne "")) {
		if ($product_ref->{serving_quantity} > 500) {
			push @{$product_ref->{data_quality_warnings_tags}}, "en:serving-quantity-over-500g";
		}
		if ($product_ref->{serving_quantity} < 1) {
			push @{$product_ref->{data_quality_warnings_tags}}, "en:serving-quantity-under-1g";
		}

		if ((defined $product_ref->{product_quantity}) and ($product_ref->{product_quantity} ne "")) {
			if ($product_ref->{serving_quantity} > $product_ref->{product_quantity}) {
				push @{$product_ref->{data_quality_warnings_tags}}, "en:serving-quantity-over-product-quantity";
			}
			if ($product_ref->{serving_quantity} < $product_ref->{product_quantity} / 1000) {
				push @{$product_ref->{data_quality_warnings_tags}},
					"en:serving-quantity-less-than-product-quantity-divided-by-1000";
			}
		}
		else {
			push @{$product_ref->{data_quality_warnings_tags}}, "en:serving-quantity-defined-but-quantity-undefined";
		}

		if ($product_ref->{serving_size} =~ /\d\s?mg\b/i) {
			push @{$product_ref->{data_quality_warnings_tags}}, "en:serving-size-in-mg";
		}
	}

	# serving size not recognized (undefined serving quantity)
	# serving_size = 10g -> serving_quantity = 10
	# serving_size = 10  -> serving_quantity will be undefined
	if (    (defined $product_ref->{serving_size})
		and ($product_ref->{serving_size} ne "")
		and (!defined $product_ref->{serving_quantity}))
	{
		push @{$product_ref->{data_quality_warnings_tags}},
			"en:nutrition-data-per-serving-serving-quantity-is-not-recognized";
	}

	return;
}

=head2 check_categories( PRODUCT_REF )

Checks related to specific product categories.

Alcoholic beverages: check that there is an alcohol value in the nutrients.

=cut

sub check_categories ($product_ref) {

	# Check alcohol content
	if (has_tag($product_ref, "categories", "en:alcoholic-beverages")) {
		if (!(defined $product_ref->{nutriments}{alcohol_value}) || $product_ref->{nutriments}{alcohol_value} == 0) {
			push @{$product_ref->{data_quality_warnings_tags}}, 'en:alcoholic-beverages-category-without-alcohol-value';
		}
		if (has_tag($product_ref, "categories", "en:non-alcoholic-beverages")) {
			# Product cannot be alcoholic and non-alcoholic
			push @{$product_ref->{data_quality_warnings_tags}}, 'en:alcoholic-and-non-alcoholic-categories';
		}
	}

	if (    defined $product_ref->{nutriments}{alcohol_value}
		and $product_ref->{nutriments}{alcohol_value} > 0
		and not has_tag($product_ref, "categories", "en:alcoholic-beverages"))
	{

		push @{$product_ref->{data_quality_warnings_tags}}, 'en:alcohol-value-without-alcoholic-beverages-category';
	}

	# Plant milks should probably not be dairies https://github.com/openfoodfacts/openfoodfacts-server/issues/73
	if (has_tag($product_ref, "categories", "en:plant-milks") and has_tag($product_ref, "categories", "en:dairies")) {
		push @{$product_ref->{data_quality_warnings_tags}}, "en:incompatible-categories-plant-milk-and-dairy";
	}

	# some categories have an expected ingredient - push data quality error if ingredient differs from expected ingredient
	# note: we currently support only 1 expected ingredient
	my ($expected_ingredients, $category_id2)
		= get_inherited_property_from_categories_tags($product_ref, "expected_ingredients:en");

	if ((defined $expected_ingredients)) {
		$expected_ingredients = canonicalize_taxonomy_tag("en", "ingredients", $expected_ingredients);
		my $number_of_ingredients = (defined $product_ref->{ingredients}) ? @{$product_ref->{ingredients}} : 0;

		if ($number_of_ingredients == 0) {
			push @{$product_ref->{data_quality_warnings_tags}},
				"en:ingredients-single-ingredient-from-category-missing";
		}
		elsif (
			# more than 1 ingredient
			($number_of_ingredients > 1)
			# ingredient different than expected ingredient
			or not(is_a("ingredients", $product_ref->{ingredients}[0]{id}, $expected_ingredients))
			)
		{
			push @{$product_ref->{data_quality_errors_tags}},
				"en:ingredients-single-ingredient-from-category-does-not-match-actual-ingredients";
		}
	}

	# some categories have an expected minimum number of ingredients
	# push data quality error if ingredients count is lower than the expected number of ingredients
	my ($minimum_number_of_ingredients, $category_id3)
		= get_inherited_property_from_categories_tags($product_ref, "minimum_number_of_ingredients:en");

	if ((defined $minimum_number_of_ingredients)) {
		my $number_of_ingredients = (defined $product_ref->{ingredients}) ? @{$product_ref->{ingredients}} : 0;

		# category might be provided but not ingredients
		# consider only when some ingredients are provided
		if ($number_of_ingredients > 0 && $number_of_ingredients < $minimum_number_of_ingredients) {
			push @{$product_ref->{data_quality_errors_tags}},
				"en:ingredients-count-lower-than-expected-for-the-category";
		}
	}

	return;
}

=head2 check_labels( PRODUCT_REF )

Checks related to specific product labels.

=cut

sub check_labels ($product_ref) {
	# compare label claim and ingredients

	# Vegan label: check that there is no non-vegan ingredient.
	# Vegetarian label: check that there is no non-vegetarian ingredient.

	# this also include en:vegan that is a child of en:vegetarian
	if (defined $product_ref->{labels_tags} && has_tag($product_ref, "labels", "en:vegetarian")) {
		if (defined $product_ref->{ingredients}) {
			my @ingredients = @{$product_ref->{ingredients}};

			while (@ingredients) {

				# Remove and process the first ingredient
				my $ingredient_ref = shift @ingredients;
				my $ingredientid = $ingredient_ref->{id};

				# Add sub-ingredients at the beginning of the ingredients array
				if (defined $ingredient_ref->{ingredients}) {

					unshift @ingredients, @{$ingredient_ref->{ingredients}};
				}

				# - some additives_classes (like thickener, for example) do not have the key-value vegan and vegetarian
				#   it can be additives_classes that contain only vegan/vegetarian additives.
				# - also we cannot tell if a compound ingredient (preparation) is vegan or vegetarian
				# to handle both cases we ignore the ingredient having vegan/vegatarian "maybe" and if it contains sub-ingredients
				my $ignore_vegan_vegetarian_facet = 0;
				if (
					(defined $ingredient_ref->{ingredients})
					and (  ((defined $ingredient_ref->{"vegan"}) and ($ingredient_ref->{"vegan"} ne 'no'))
						or ((defined $ingredient_ref->{"vegetarian"}) and ($ingredient_ref->{"vegetarian"} ne 'no')))
					)
				{
					$ignore_vegan_vegetarian_facet = 1;
				}

				if (not $ignore_vegan_vegetarian_facet) {
					if (has_tag($product_ref, "labels", "en:vegan")) {
						# vegan
						if (defined $ingredient_ref->{"vegan"}) {
							if ($ingredient_ref->{"vegan"} eq 'no') {
								add_tag($product_ref, "data_quality_errors", "en:vegan-label-but-non-vegan-ingredient");
							}
							# else 'yes', 'maybe'
						}
						# no tag
						else {
							add_tag($product_ref, "data_quality_warnings",
								"en:vegan-label-but-could-not-confirm-for-all-ingredients");
						}
					}

					# vegetarian label condition is above
					if (defined $ingredient_ref->{"vegetarian"}) {
						if ($ingredient_ref->{"vegetarian"} eq 'no') {
							add_tag($product_ref, "data_quality_errors",
								"en:vegetarian-label-but-non-vegetarian-ingredient");
						}
						# else 'yes', 'maybe'
					}
					# no tag
					else {
						add_tag($product_ref, "data_quality_warnings",
							"en:vegetarian-label-but-could-not-confirm-for-all-ingredients");
					}
				}
			}
		}
	}

	# In EU, compare label claim and nutrition
	# https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX%3A02006R1924-20141213
	my @eu_countries = (
		"en:austria", "en:belgium", "en:bulgaria", "en:croatia", "en:cyprus", "en:czech republic",
		"en:denmark", "en:france", "en:estonia", "en:finland", "en:germany", "en:greece",
		"en:hungary", "en:ireland", "en:italy", "en:latvia", "en:lithuania", "en:luxembourg",
		"en:malta", "en:netherlands", "en:poland", "en:portugal", "en:romania", "en:slovakia",
		"en:slovenia", "en:spain", "en:sweden"
	);
	my $european_product = 0;
	foreach my $eu_country (@eu_countries) {
		if (has_tag(($product_ref, "countries", $eu_country))) {
			$european_product = 1;
			last;
		}
	}

	if (    (defined $product_ref->{nutriments})
		and (defined $product_ref->{labels_tags})
		and ($european_product == 1))
	{
		# maximal values differs depending if the product is
		# solid (higher maxmal values) or
		# liquid (lower maximal values)
		my $solid = 1;
		if (defined $product_ref->{quantity}) {
			my $standard_unit = extract_standard_unit($product_ref->{quantity});
			if ((defined $standard_unit) and ($standard_unit eq "ml")) {
				$solid = 0;
			}
		}

		if (   (defined $product_ref->{nutriments}{"energy-kcal_100g"})
			or (defined $product_ref->{nutriments}{"energy-kj_value"}))
		{
			# In EU, a claim that a food is low in energy may only be made where the product
			# does not contain more than 40 kcal (170 kJ)/100 g for solids or
			# more than 20 kcal (80 kJ)/100 ml for liquids.
			# (not handled) For table-top sweeteners the limit of 4 kcal (17 kJ)/portion,
			#   with equivalent sweetening properties to 6 g of sucrose
			#   (approximately 1 teaspoon of sucrose), applies.
			if (
				(has_tag($product_ref, "labels", "en:low-energy"))
				and (
					(
						($solid == 1) and (($product_ref->{nutriments}{"energy-kcal_100g"} > 40)
							or ($product_ref->{nutriments}{"energy-kj_100g"} > 170))
					)
					or (
						($solid == 0)
						and (  ($product_ref->{nutriments}{"energy-kcal_100g"} > 20)
							or ($product_ref->{nutriments}{"energy-kj_100g"} > 80))
					)
				)
				)
			{
				add_tag($product_ref, "data_quality_warnings", "en:low-energy-label-claim-but-energy-above-limitation");
			}

			# TODO: checks label and children - limitation applied on child should not apply on parent in some cases

			# In EU, a claim that a food is energy free may only be made where the product
			# does not contain more than 4 kcal (17 kJ)/100 ml.
			# (not handled) For table-top sweeteners the limit of 0,4 kcal (1,7 kJ)/portion,
			#    with equivalent sweetening properties to 6 g of sucrose
			#    (approximately 1 teaspoon of sucrose), applies.
			if (
				(has_tag($product_ref, "labels", "en:energy-free"))
				and (
					(
						   ($product_ref->{nutriments}{"energy-kcal_100g"} > 4)
						or ($product_ref->{nutriments}{"energy-kj_100g"} > 17)
					)
				)
				)
			{
				add_tag($product_ref, "data_quality_warnings",
					"en:energy-free-label-claim-but-energy-above-limitation");
			}
		}

		if (defined $product_ref->{nutriments}{fat_100g}) {
			# In EU, a claim that a food is low fat may only be made where the product contains
			# no more than 3 g of fat per 100 g for solids or
			# 1,5 g of fat per 100 ml for liquids
			# (1,8 g of fat per 100 ml for semi-skimmed milk).
			if (
				(has_tag($product_ref, "labels", "en:low-fat"))
				and (
					(($solid == 1) and ($product_ref->{nutriments}{fat_100g} > 3))
					or (    ($solid == 0)
						and ($product_ref->{nutriments}{fat_100g} > 1.5)
						and (!has_tag($product_ref, "categories", "en:semi-skimmed-milks")))
					or (    ($solid == 0)
						and ($product_ref->{nutriments}{fat_100g} > 1.8)
						and (has_tag($product_ref, "categories", "en:semi-skimmed-milks")))
				)
				)
			{
				add_tag($product_ref, "data_quality_warnings", "en:low-fat-label-claim-but-fat-above-limitation");
			}

			# In EU, a claim that a food is fat free may only be made where
			# the product contains no more than 0,5 g of fat per 100 g or 100 ml.
			if ((has_tag($product_ref, "labels", "en:no-fat")) && ($product_ref->{nutriments}{fat_100g} > 0.5)) {
				add_tag($product_ref, "data_quality_warnings", "en:no-fat-label-claim-but-fat-above-0.5");
			}

			# In EU, a claim that a food is high in monounsaturated fat may only be made where
			# at least 45 % of the fatty acids present in the product derive from monounsaturated fat
			# under the condition that monounsaturated fat provides more than 20 % of energy of the product.
			if (
					(has_tag($product_ref, "labels", "en:high-monounsaturated-fat"))
				and (defined $product_ref->{nutriments}{"monounsaturated-fat_100g"})
				and (
					(
						$product_ref->{nutriments}{"monounsaturated-fat_100g"}
						< ($product_ref->{nutriments}{fat_100g} * 45 / 100)
					)
					or (
						(
							  $product_ref->{nutriments}{"monounsaturated-fat_100g"}
							* $energy_from_nutrients{europe}{"fat"}{"kcal"}
						) < (20 * $product_ref->{nutriments}{"energy-kcal_value_computed"} / 100)
					)
					or (
						(
							  $product_ref->{nutriments}{"monounsaturated-fat_100g"}
							* $energy_from_nutrients{europe}{"fat"}{"kj"}
						) < (20 * $product_ref->{nutriments}{"energy-kj_value_computed"} / 100)
					)
				)
				)
			{
				add_tag($product_ref, "data_quality_warnings",
					"en:high-monounsaturated-fat-label-claim-but-monounsaturated-fat-under-limitation");
			}

			# In EU, a claim that a food is high in polyunsaturated fat may only be made where
			# at least 45 % of the fatty acids present in the product derive from polyunsaturated fat
			# under the condition that polyunsaturated fat provides more than 20 % of energy of the product.
			if (
					(has_tag($product_ref, "labels", "en:rich-in-polyunsaturated-fatty-acids"))
				and (defined $product_ref->{nutriments}{"polyunsaturated-fat_100g"})
				and (
					(
						$product_ref->{nutriments}{"polyunsaturated-fat_100g"}
						< ($product_ref->{nutriments}{fat_100g} * 45 / 100)
					)
					or (
						(
							  $product_ref->{nutriments}{"polyunsaturated-fat_100g"}
							* $energy_from_nutrients{europe}{"fat"}{"kcal"}
						) < (20 * $product_ref->{nutriments}{"energy-kcal_value_computed"} / 100)
					)
					or (
						(
							  $product_ref->{nutriments}{"polyunsaturated-fat_100g"}
							* $energy_from_nutrients{europe}{"fat"}{"kj"}
						) < (20 * $product_ref->{nutriments}{"energy-kj_value_computed"} / 100)
					)
				)
				)
			{
				add_tag($product_ref, "data_quality_warnings",
					"en:rich-in-polyunsaturated-fatty-acids-label-claim-but-polyunsaturated-fat-under-limitation");
			}

			# In EU, a claim that a food is high in unsaturated fat may only be made where
			# at least 70 % of the fatty acids present in the product derive from unsaturated fat
			# under the condition that unsaturated fat provides more than 20 % of energy of the product.
			if (
					(has_tag($product_ref, "labels", "en:rich-in-unsaturated-fatty-acids"))
				and (defined $product_ref->{nutriments}{"unsaturated-fat_100g"})
				and (
					(
						$product_ref->{nutriments}{"unsaturated-fat_100g"}
						< ($product_ref->{nutriments}{fat_100g} * 45 / 100)
					)
					or (
						(
							  $product_ref->{nutriments}{"unsaturated-fat_100g"}
							* $energy_from_nutrients{europe}{"fat"}{"kcal"}
						) < (20 * $product_ref->{nutriments}{"energy-kcal_value_computed"} / 100)
					)
					or (
						(     $product_ref->{nutriments}{"unsaturated-fat_100g"}
							* $energy_from_nutrients{europe}{"fat"}{"kj"})
						< (20 * $product_ref->{nutriments}{"energy-kj_value_computed"} / 100))
				)
				)
			{
				add_tag($product_ref, "data_quality_warnings",
					"en:rich-in-unsaturated-fatty-acids-label-claim-but-unsaturated-fat-under-limitation");
			}

		}

		if (defined $product_ref->{nutriments}{"saturated-fat_100g"}) {
			# In EU, a claim that a food is fat free may only be made if
			# the sum of saturated fatty acids and trans-fatty acids in the product does not exceed 1,5 g per 100 g for solids or
			# 0,75 g/100 ml for liquids and in either case
			# the sum of saturated fatty acids and trans-fatty acids must not provide more than 10 % of energy

			# use computed enegy because input energy may be undefined
			if (
				(has_tag($product_ref, "labels", "en:low-content-of-saturated-fat"))
				and (
					(($solid == 1) and ($product_ref->{nutriments}{"saturated-fat_100g"} > 1.5))
					or (    ($solid == 0)
						and ($product_ref->{nutriments}{"saturated-fat_100g"} > 0.75))
					or (
						(
							(
								(
									  $product_ref->{nutriments}{"saturated-fat_100g"}
									+ $product_ref->{nutriments}{"trans-fat_100g"} || 0
								) * $energy_from_nutrients{europe}{"fat"}{"kj"}
							) > (10 * $product_ref->{nutriments}{"energy-kj_value_computed"} / 100)
						)
						or (
							(
								(
									  $product_ref->{nutriments}{"saturated-fat_100g"}
									+ $product_ref->{nutriments}{"trans-fat_100g"} || 0
								) * $energy_from_nutrients{europe}{"fat"}{"kcal"}
							) > (10 * $product_ref->{nutriments}{"energy-kcal_value_computed"} / 100)
						)
					)
				)
				)
			{
				add_tag($product_ref, "data_quality_warnings",
					"en:low-saturated-fat-label-claim-but-fat-above-limitation");
			}

			# In EU, a claim that a food does not contain sturated fat may only be made where
			# the sum of saturated fat and trans-fatty acids does not exceed 0,1 g of saturated fat per 100 g or 100 ml.
			if (    (has_tag($product_ref, "labels", "en:saturated-fat-free"))
				and (($product_ref->{nutriments}{"saturated-fat_100g"} > 0.1)))
			{
				add_tag($product_ref, "data_quality_warnings", "en:saturated-fat-free-label-claim-but-fat-above-0.1");
			}
		}

		if (defined $product_ref->{nutriments}{sugars_100g}) {
			# In EU, a claim that a food is low sugar may only be made where the product contains
			# no more than 5 g of sugars per 100 g for solids or
			# 2,5 g of sugars per 100 ml for liquids.
			if (
				(has_tag($product_ref, "labels", "en:low-sugar"))
				and (
					(($solid == 1) and ($product_ref->{nutriments}{sugars_100g} > 5))
					or (    ($solid == 0)
						and ($product_ref->{nutriments}{sugars_100g} > 2.5))
				)
				)
			{
				add_tag($product_ref, "data_quality_warnings", "en:low-sugar-label-claim-but-sugar-above-limitation");
			}

			# In EU, a claim that a food is sugar-free may only be made where the product contains
			# no more than 0,5 g of sugars per 100 g or 100 ml.
			if (    (has_tag($product_ref, "labels", "en:no-sugar"))
				and (($product_ref->{nutriments}{sugars_100g} > 0.5)))
			{
				add_tag($product_ref, "data_quality_warnings", "en:sugar-free-label-claim-but-sugar-above-limitation");
			}
		}

		# In EU, a claim that a food is with no added sugars may only be made where
		# the product does not contain any added mono- or disaccharides or
		# any other food used for its sweetening properties.
		# (not handled) If sugars are naturally present in the food, the following indication should also appear on the label:
		#    ‘CONTAINS NATURALLY OCCURRING SUGARS’.
		if (    (has_tag($product_ref, "labels", "en:no-added-sugar"))
			and (has_tag($product_ref, "ingredients", "en:added-sugar")))
		{
			add_tag($product_ref, "data_quality_warnings", "en:no-added-sugar-label-claim-but-contains-added-sugar");
		}

		# In EU, a claim that a food is low sodium or low salt may only be made where
		# the product contains no more than 0,12 g of sodium, or the equivalent value for salt, per 100 g or per 100 ml.
		# (not handled) For waters, other than natural mineral waters falling within the scope of Directive 80/777/EEC,
		#    this value should not exceed 2 mg of sodium per 100 ml.
		if (
			(
				((defined $product_ref->{nutriments}{sodium_100g}) and ($product_ref->{nutriments}{sodium_100g} > 0.12))
				or ((defined $product_ref->{nutriments}{salt_100g}) and ($product_ref->{nutriments}{salt_100g} > 0.3))
			)
			and (has_tag($product_ref, "labels", "en:low-sodium") or has_tag($product_ref, "labels", "en:low-salt"))
			)
		{
			add_tag($product_ref, "data_quality_warnings",
				"en:low-sodium-or-low-salt-label-claim-but-sodium-or-salt-above-limitation");
		}

		# In EU, a claim that a food is very low in sodium/salt may only be made where
		# the product contains no more than 0,04 g of sodium, or the equivalent value for salt, per 100 g or per 100 ml.
		# This claim shall not be used for natural mineral waters and other waters.
		if (
			(
				((defined $product_ref->{nutriments}{sodium_100g}) and ($product_ref->{nutriments}{sodium_100g} > 0.04))
				or ((defined $product_ref->{nutriments}{salt_100g}) and ($product_ref->{nutriments}{salt_100g} > 0.1))
			)
			and (  has_tag($product_ref, "labels", "en:very-low-sodium")
				or has_tag($product_ref, "labels", "en:very-low-salt"))
			and (!has_tag($product_ref, "categories", "en:waters"))
			)
		{
			add_tag($product_ref, "data_quality_warnings",
				"en:very-low-sodium-or-very-low-salt-label-claim-but-sodium-or-salt-above-limitation");
		}

		# In EU, a claim that a food is sodium-free or salt-free may only be made where the product contains
		# no more than 0,005 g of sodium, or the equivalent value for salt, per 100 g.
		if (
			(
				(       (defined $product_ref->{nutriments}{sodium_100g})
					and ($product_ref->{nutriments}{sodium_100g} > 0.005))
				or (    (defined $product_ref->{nutriments}{salt_100g})
					and ($product_ref->{nutriments}{salt_100g} > 0.0125))
			)
			and (has_tag($product_ref, "labels", "en:no-sodium") or has_tag($product_ref, "labels", "en:no-salt"))
			)
		{
			add_tag($product_ref, "data_quality_warnings",
				"en:sodium-free-or-salt-free-label-claim-but-sodium-or-salt-above-limitation");
		}

		# In EU, a claim that sodium/salt has not been added to a food may only be made where the product
		# does not contain any added sodium/salt or any other ingredient containing added sodium/salt and
		# the product contains no more than 0,12 g sodium, or the equivalent value for salt, per 100 g or 100 ml.
		if (
			(
				((defined $product_ref->{nutriments}{sodium_100g}) and ($product_ref->{nutriments}{sodium_100g} > 0.12))
				or ((defined $product_ref->{nutriments}{salt_100g}) and ($product_ref->{nutriments}{salt_100g} > 0.3))
				or (has_tag($product_ref, "ingredients", "en:salt"))
			)
			and (  has_tag($product_ref, "labels", "en:no-added-sodium")
				or has_tag($product_ref, "labels", "en:no-added-salt"))
			)
		{
			add_tag($product_ref, "data_quality_warnings",
				"en:no-added-sodium-or-no-added-salt-label-claim-but-sodium-or-salt-above-limitation");
		}

		if (defined $product_ref->{nutriments}{fiber_100g}) {
			# In EU, a claim that a food is a source of fibre may only be made where the product contains
			# at least 3 g of fibre per 100 g or
			# at least 1,5 g of fibre per 100 kcal.
			if (
				(has_tag($product_ref, "labels", "en:source-of-fibre"))
				and (  (($solid == 1) and ($product_ref->{nutriments}{fiber_100g} < 3))
					or ($product_ref->{nutriments}{fiber_100g} * $energy_from_nutrients{europe}{"fiber"}{"kcal"})
					< (1.5 * $product_ref->{nutriments}{"energy-kcal_value_computed"} / 100))
				)
			{
				add_tag($product_ref, "data_quality_warnings",
					"en:source-of-fibre-label-claim-but-fibre-below-limitation");
			}
			# In EU, a claim that a food is high in fibre may only be made where the product contains
			# at least 6 g of fibre per 100 g or
			# at least 3 g of fibre per 100 kcal.
			if (
				(has_tag($product_ref, "labels", "en:high-fibres"))
				and (  (($solid == 1) and ($product_ref->{nutriments}{fiber_100g} < 6))
					or ($product_ref->{nutriments}{fiber_100g} * $energy_from_nutrients{europe}{"fiber"}{"kcal"})
					< (3 * $product_ref->{nutriments}{"energy-kcal_value_computed"} / 100))
				)
			{
				add_tag($product_ref, "data_quality_warnings", "en:high-fibres-label-claim-but-fibre-below-limitation");
			}
		}

		if (defined $product_ref->{nutriments}{proteins_100g}) {
			# In EU, a claim that a food is a source of protein may only be made where
			# at least 12 % of the energy value of the food is provided by protein.
			if (    (has_tag($product_ref, "labels", "en:source-of-proteins"))
				and ($product_ref->{nutriments}{proteins_100g} * $energy_from_nutrients{europe}{"proteins"}{"kcal"})
				< (12 * $product_ref->{nutriments}{"energy-kcal_value_computed"} / 100))
			{
				add_tag($product_ref, "data_quality_warnings",
					"en:source-of-proteins-label-claim-but-proteins-below-limitation");
			}

			# In EU, a claim that a food is high in protein may only be made where
			#at least 20 % of the energy value of the food is provided by protein.
			if (    (has_tag($product_ref, "labels", "en:high-proteins"))
				and ($product_ref->{nutriments}{proteins_100g} * $energy_from_nutrients{europe}{"proteins"}{"kcal"})
				< (20 * $product_ref->{nutriments}{"energy-kcal_value_computed"} / 100))
			{
				add_tag($product_ref, "data_quality_warnings",
					"en:high-proteins-label-claim-but-proteins-below-limitation");
			}
		}

		# See annex from: https://eur-lex.europa.eu/legal-content/EN/ALL/?uri=CELEX:31990L0496
		my %vitamins_and_minerals_labelling = (
			europe => {
				"vitamin-a" => {
					"en:vitamin-a-source" => 0.0008,    # 800 µg
					"en:rich-in-vitamin-a" => 0.0016,
				},
				"vitamin-d" => {
					"en:vitamin-d-source" => 0.000005,    # 5 µg
					"en:rich-in-vitamin-d" => 0.00001,
				},
				"vitamin-e" => {
					"en:vitamin-e-source" => 0.01,    # 10 mg
					"en:rich-in-vitamin-e" => 0.02,
				},
				"vitamin-c" => {
					"en:vitamin-c-source" => 0.06,    # 10 mg
					"en:rich-in-vitamin-c" => 0.12,
				},
				"vitamin-b1" => {
					"en:vitamin-b1-source" => 0.0014,    # 1.4 mg, thiamin
					"en:rich-in-vitamin-b1" => 0.0028,
				},
				"vitamin-b2" => {
					"en:vitamin-b2-source" => 0.0016,    # 1.6 mg, riboflavin
					"en:rich-in-vitamin-b2" => 0.0032,
				},
				"vitamin-b3" => {
					"en:vitamin-b3-source" => 0.018,    # 18 mg, niacin
					"en:rich-in-vitamin-b3" => 0.036,
				},
				"vitamin-b6" => {
					"en:vitamin-b6-source" => 0.002,    # 2 mg
					"en:rich-in-vitamin-b6" => 0.004,
				},
				"vitamin-b9" => {
					"en:vitamin-b9-source" => 0.0002,    # 200 µg, folacin
					"en:rich-in-vitamin-b9" => 0.0004,
				},
				"vitamin-b12" => {
					"en:vitamin-b12-source" => 0.000001,    # 1 µg
					"en:rich-in-vitamin-b12" => 0.000002,
				},
				"biotin" => {
					"en:source-of-biotin" => 0.00015,    # 0.15 mg
					"en:high-in-biotin" => 0.0003,
				},
				"pantothenic-acid" => {
					"en:source-of-pantothenic-acid" => 0.006,    # 6 mg
					"en:high-in-pantothenic-acid" => 0.012,
				},
				"calcium" => {
					"en:calcium-source" => 0.8,    # 800 mg
					"en:high-in-calcium" => 1.6,
				},
				"phosphorus" => {
					"en:phosphore-source" => 0.8,    # 800 mg
					"en:high-in-phosphore" => 1.6,
				},
				"iron" => {
					"en:iron-source" => 0.014,    # 14 mg
					"en:high-in-iron" => 0.028,
				},
				"magnesium" => {
					"en:magnesium-source" => 0.3,    # 300 mg
					"en:high-in-magnesium" => 0.6,
				},
				"zinc" => {
					"en:zinc-source" => 0.015,    # 15 mg
					"en:high-in-zinc" => 0.03,
				},
				"iodine" => {
					"en:iodine-source" => 0.00015,    # 150 µg
					"en:high-in-iodine" => 0.0003,
				},
			},
		);
		foreach my $vit_or_min (keys %{$vitamins_and_minerals_labelling{europe}}) {
			foreach my $vit_or_min_label (keys %{$vitamins_and_minerals_labelling{europe}{$vit_or_min}}) {
				if (
						(defined $product_ref->{nutriments}{$vit_or_min . "_100g"})
					and (has_tag($product_ref, "labels", $vit_or_min_label))
					and ($product_ref->{nutriments}{$vit_or_min . "_100g"}
						< $vitamins_and_minerals_labelling{europe}{$vit_or_min}{$vit_or_min_label})
					)
				{
					add_tag($product_ref, "data_quality_warnings",
							  "en:"
							. substr($vit_or_min_label, 3)
							. "-label-claim-but-$vit_or_min-below-$vitamins_and_minerals_labelling{europe}{$vit_or_min}{$vit_or_min_label}"
					);
				}
			}
		}

		# In EU, a claim that a food is a source of omega-3 may only be made where the product contains
		# at least 0,3 g alpha-linolenic acid per 100 g
		#   not handled: and per 100 kcal, or
		# at least 40 mg of the sum of eicosapentaenoic acid and docosahexaenoic acid per 100 g
		#   not handled: and per 100 kcal.
		if (
			(has_tag($product_ref, "labels", "en:source-of-omega-3"))
			and (
				(
						(defined $product_ref->{nutriments}{"alpha-linolenic-acid_100g"})
					and ($product_ref->{nutriments}{"alpha-linolenic-acid_100g"} < 0.3)
				)
				or (
						(defined $product_ref->{nutriments}{"eicosapentaenoic-acid_100g"})
					and (defined $product_ref->{nutriments}{"docosahexaenoic-acid_100g"})
					and (
						(
							  $product_ref->{nutriments}{"eicosapentaenoic-acid_100g"}
							+ $product_ref->{nutriments}{"docosahexaenoic-acid_100g"}
						) < 0.04
					)
				)
			)
			)
		{
			add_tag($product_ref, "data_quality_warnings",
				"en:source-of-omega-3-label-claim-but-ala-or-sum-of-epa-and-dha-below-limitation");
		}

		# In EU, a claim that a food is high in omega-3 may only be made where the product contains
		# at least 0,6 g alpha-linolenic acid per 100 g and per 100 kcal, or
		# at least 80 mg of the sum of eicosapentaenoic acid and docosahexaenoic acid per 100 g and per 100 kcal.
		if (
			(has_tag($product_ref, "labels", "en:high-in-omega-3"))
			and (
				(
						(defined $product_ref->{nutriments}{"alpha-linolenic-acid_100g"})
					and ($product_ref->{nutriments}{"alpha-linolenic-acid_100g"} < 0.6)
				)
				or (
						(defined $product_ref->{nutriments}{"eicosapentaenoic-acid_100g"})
					and (defined $product_ref->{nutriments}{"docosahexaenoic-acid_100g"})
					and (
						(
							  $product_ref->{nutriments}{"eicosapentaenoic-acid_100g"}
							+ $product_ref->{nutriments}{"docosahexaenoic-acid_100g"}
						) < 0.08
					)
				)
			)
			)
		{
			add_tag($product_ref, "data_quality_warnings",
				"en:high-in-omega-3-label-claim-but-ala-or-sum-of-epa-and-dha-below-limitation");
		}
	}

	# In EU, compare categories and regulations
	# https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX%3A02001L0113-20131118
	# my %spread_categories_regulation = (
	# 		europe => {
	# 			"en:jams" => "35",

	# some categories have mininal amount content required by regulations
	# $expected_minimal_amount_specific_ingredients = "en:fruit, 35, en:eu"
	my ($expected_minimal_amount_specific_ingredients, $category_id)
		= get_inherited_property_from_categories_tags($product_ref, "expected_minimal_amount_specific_ingredients:en");

	# convert as a list, in case there are more than a countries having regulations
	if (defined $expected_minimal_amount_specific_ingredients) {
		my @expected_minimal_amount_specific_ingredients_list = split /;/,
			$expected_minimal_amount_specific_ingredients;
		foreach my $expected_minimal_amount_specific_ingredients_element (
			@expected_minimal_amount_specific_ingredients_list)
		{
			# split on ", " to extract ingredient id, quantity in g and country
			my ($specific_ingredient_id, $quantity_threshold, $country) = split /, /,
				$expected_minimal_amount_specific_ingredients_element;

			if (
					(defined $specific_ingredient_id)
				and (defined $quantity_threshold)
				and (defined $country)
				and (  (($country eq "en:eu") and ($european_product == 1))
					or (has_tag(($product_ref, "countries", $country))))
				)
			{
				my $specific_ingredient_quantity;
				if (defined $product_ref->{specific_ingredients}) {
					foreach my $specific_ingredient ($product_ref->{specific_ingredients}[0]) {
						if (    (defined $specific_ingredient->{id})
							and (defined $specific_ingredient->{quantity_g})
							and ($specific_ingredient->{id} eq $specific_ingredient_id))
						{
							$specific_ingredient_quantity = $specific_ingredient->{quantity_g};
						}
					}
				}

				if (defined $specific_ingredient_quantity) {
					if ($specific_ingredient_quantity < $quantity_threshold) {
						add_tag($product_ref, "data_quality_errors",
								  "en:specific-ingredient-"
								. substr($specific_ingredient_id, 3)
								. "-quantity-is-below-the-minimum-value-of-$quantity_threshold-for-category-"
								. substr($category_id, 3));
					}
				}
				else {
					add_tag($product_ref, "data_quality_info", "en:missing-specific-ingredient-for-this-category");
				}

			}
		}
	}
	return;
}

sub compare_nutriscore_with_value_from_producer ($product_ref) {

	if (
		(defined $product_ref->{nutriscore_score})
		and (defined $product_ref->{nutriscore_score_producer}
			and ($product_ref->{nutriscore_score} ne lc($product_ref->{nutriscore_score_producer})))
		)
	{
		push @{$product_ref->{data_quality_warnings_tags}},
			"en:nutri-score-score-from-producer-does-not-match-calculated-score";
	}

	if (
		(defined $product_ref->{nutriscore_grade})
		and (defined $product_ref->{nutriscore_grade_producer}
			and ($product_ref->{nutriscore_grade} ne lc($product_ref->{nutriscore_grade_producer})))
		)
	{
		push @{$product_ref->{data_quality_warnings_tags}},
			"en:nutri-score-grade-from-producer-does-not-match-calculated-grade";
	}

	if (defined $product_ref->{nutriscore_grade}) {

		foreach my $grade ("a", "b", "c", "d", "e") {

			if (has_tag($product_ref, "labels", "en:nutriscore-grade-$grade")
				and (lc($product_ref->{nutriscore_grade}) ne $grade))
			{
				push @{$product_ref->{data_quality_warnings_tags}},
					"en:nutri-score-grade-from-label-does-not-match-calculated-grade";
			}
		}
	}

	return;
}

=head2 check_ingredients_percent_analysis( PRODUCT_REF )

Checks if we were able to analyze the minimum and maximum percent values for ingredients and sub-ingredients.

=cut

sub check_ingredients_percent_analysis ($product_ref) {

	if (defined $product_ref->{ingredients_percent_analysis}) {

		if ($product_ref->{ingredients_percent_analysis} < 0) {
			push @{$product_ref->{data_quality_warnings_tags}}, 'en:ingredients-percent-analysis-not-ok';
		}
		elsif ($product_ref->{ingredients_percent_analysis} > 0) {
			push @{$product_ref->{data_quality_info_tags}}, 'en:ingredients-percent-analysis-ok';
		}

	}

	return;
}

=head2 check_ingredients_with_specified_percent( PRODUCT_REF )

Check if all or almost all the ingredients have a specified percentage in the ingredients list.

=cut

sub check_ingredients_with_specified_percent ($product_ref) {

	if (    defined $product_ref->{ingredients_with_specified_percent_n}
		and $product_ref->{ingredients_with_specified_percent_n} > 0
		and defined $product_ref->{ingredients_with_unspecified_percent_n}
		and $product_ref->{ingredients_with_unspecified_percent_n} == 0)
	{
		push @{$product_ref->{data_quality_info_tags}}, 'en:all-ingredients-with-specified-percent';
	}
	elsif (defined $product_ref->{ingredients_with_unspecified_percent_n}
		and $product_ref->{ingredients_with_unspecified_percent_n} == 1)
	{
		push @{$product_ref->{data_quality_info_tags}}, 'en:all-but-one-ingredient-with-specified-percent';
	}

	if (    defined $product_ref->{ingredients_with_specified_percent_n}
		and $product_ref->{ingredients_with_specified_percent_n} > 0
		and defined $product_ref->{ingredients_with_specified_percent_sum}
		and $product_ref->{ingredients_with_specified_percent_sum} >= 90
		and defined $product_ref->{ingredients_with_unspecified_percent_sum}
		and $product_ref->{ingredients_with_unspecified_percent_sum} < 10)
	{
		push @{$product_ref->{data_quality_info_tags}}, 'en:sum-of-ingredients-with-unspecified-percent-lesser-than-10';
	}

	# Flag products where the sum of % is higher than 100
	if (    defined $product_ref->{ingredients_with_specified_percent_n}
		and $product_ref->{ingredients_with_specified_percent_n} > 0
		and defined $product_ref->{ingredients_with_specified_percent_sum}
		and $product_ref->{ingredients_with_specified_percent_sum} > 100)
	{
		push @{$product_ref->{data_quality_info_tags}}, 'en:sum-of-ingredients-with-specified-percent-greater-than-100';
	}

	if (    defined $product_ref->{ingredients_with_specified_percent_n}
		and $product_ref->{ingredients_with_specified_percent_n} > 0
		and defined $product_ref->{ingredients_with_specified_percent_sum}
		and $product_ref->{ingredients_with_specified_percent_sum} > 200)
	{
		push @{$product_ref->{data_quality_warnings_tags}},
			'en:sum-of-ingredients-with-specified-percent-greater-than-200';
	}

	# Percentage for ingredient is higher than 100% in extracted ingredients from the picture
	if (defined $product_ref->{ingredients_with_specified_percent_n}
		and $product_ref->{ingredients_with_specified_percent_n} > 0)
	{
		foreach my $ingredient_id (@{$product_ref->{ingredients}}) {
			if (    (defined $ingredient_id->{percent})
				and ($ingredient_id->{percent} > 100))
			{
				push @{$product_ref->{data_quality_warnings_tags}},
					'en:ingredients-extracted-ingredient-from-picture-with-more-than-100-percent';
				last;
			}
		}
	}

	return;
}

=head2 check_environmental_score_data( PRODUCT_REF )

Checks for data needed to compute the Eco-score.

=cut

sub check_environmental_score_data ($product_ref) {

	if (defined $product_ref->{environmental_score_data}) {

		foreach my $adjustment (sort keys %{$product_ref->{environmental_score_data}{adjustments}}) {

			if (defined $product_ref->{environmental_score_data}{adjustments}{$adjustment}{warning}) {
				my $warning
					= $adjustment . '-' . $product_ref->{environmental_score_data}{adjustments}{$adjustment}{warning};
				$warning =~ s/_/-/g;
				push @{$product_ref->{data_quality_warnings_tags}}, 'en:environmental-score-' . $warning;
			}
		}
	}

	# Extended Environmental-Score data from impact estimator
	if (defined $product_ref->{environmental_score_extended_data}) {

		push @{$product_ref->{data_quality_info_tags}}, 'en:environmental-score-extended-data-computed';

		if (is_environmental_score_extended_data_more_precise_than_agribalyse($product_ref)) {
			push @{$product_ref->{data_quality_info_tags}},
				'en:environmental-score-extended-data-more-precise-than-agribalyse';
		}
		else {
			push @{$product_ref->{data_quality_info_tags}},
				'en:environmental-score-extended-data-less-precise-than-agribalyse';
		}
	}
	else {
		push @{$product_ref->{data_quality_info_tags}}, 'en:environmental-score-extended-data-not-computed';
	}

	return;
}

=head2 check_food_groups( PRODUCT_REF )

Add info tags about food groups.

=cut

sub check_food_groups ($product_ref) {

	for (my $level = 1; $level <= 3; $level++) {

		if (deep_exists($product_ref, "food_groups_tags", $level - 1)) {
			push @{$product_ref->{data_quality_info_tags}}, 'en:food-groups-' . $level . '-known';
		}
		else {
			push @{$product_ref->{data_quality_info_tags}}, 'en:food-groups-' . $level . '-unknown';
		}
	}

	return;
}

=encoding utf8

=head2 check_incompatible_tags( PRODUCT_REF )

Checks if 2 incompatible tags are assigned to the product

To include more tags to this check, 
add the property "incompatible:en" 
at the end of code block in the taxonomy

Example:
en:Non-fair trade, Not fair trade
fr:Non issu du commerce équitable
incompatible_with:en: en:fair-trade

=cut

sub check_incompatible_tags ($product_ref) {

	# list of tags having 'incompatible_with' properties
	my @tagtypes_to_check = ("categories", "labels");

	foreach my $tagtype_to_check (@tagtypes_to_check) {
		$log->debug("check_incompatible_tags: tagtype_to_check $tagtype_to_check") if $log->debug();

		# we don't need to care about inherited properties
		# as every tag parent is also in the _tags field
		# thus, incompatibilities will pop-up
		my $incompatible_with_hash
			= get_all_tags_having_property($product_ref, $tagtype_to_check, "incompatible_with:en");

		foreach my $tags_having_property (keys %{$incompatible_with_hash}) {
			my $incompatible_tags = %{$incompatible_with_hash}{$tags_having_property};

			$log->debug("check_incompatible_tags: tags_having_property: "
					. $tags_having_property
					. ", incompatible_tags: "
					. $incompatible_tags)
				if $log->debug();

			# there can be more than a single incompatible_tags (comma (followed or
			# not-followed by space (remember that spaces are converted as hyphen) ) separated):
			#   categories:en:short-grain-rices, categories:en:medium-grain-rices
			my @all_incompatible_tags = split(/,-*/, $incompatible_tags);

			foreach my $incompatible_tag (@all_incompatible_tags) {
				$log->debug("check_incompatible_tags: incompatible_tag: " . $incompatible_tag) if $log->debug();

				# split by ":" and produce 2 element list
				#   for example, labels:en:contains-gluten -> (labels, en:contains-gluten)
				my ($tagtype, $tagid) = split(/:/, $incompatible_tag, 2);

				if (has_tag($product_ref, $tagtype, $tagid)) {
					# column (:) prevents formating of the data quality facet on the website
					$tags_having_property =~ s/en://g;
					$incompatible_tag =~ s/:en:/-/g;

					# sort in alphabetical order to avoid facet a-b and facet b-a
					my @incompatible_tags = sort ($tagtype_to_check . "-" . $tags_having_property, $incompatible_tag);

					add_tag($product_ref, "data_quality_errors",
						"en:mutually-exclusive-tags-for-$incompatible_tags[0]-and-$incompatible_tags[1]");
				}
			}
		}
	}

	return;
}

=head2 check_quality_food( PRODUCT_REF )

Run all quality checks defined in the module.

=cut

sub check_quality_food ($product_ref) {

	check_ingredients($product_ref);
	check_ingredients_percent_analysis($product_ref);
	check_ingredients_with_specified_percent($product_ref);
	check_nutrition_data($product_ref);
	check_nutrition_data_energy_computation($product_ref);
	compare_nutrition_facts_with_products_from_same_category($product_ref);
	check_nutrition_grades($product_ref);
	check_carbon_footprint($product_ref);
	check_quantity($product_ref);
	detect_categories($product_ref);
	check_categories($product_ref);
	check_labels($product_ref);
	compare_nutriscore_with_value_from_producer($product_ref);
	check_environmental_score_data($product_ref);
	check_food_groups($product_ref);
	check_incompatible_tags($product_ref);

	return;
}

1;
