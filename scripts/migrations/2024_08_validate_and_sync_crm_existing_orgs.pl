#!/usr/bin/perl -w

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
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

use ProductOpener::PerlStandards;
use Modern::Perl '2017';
use utf8;

use ProductOpener::Users qw( $User_id );
use ProductOpener::Orgs qw( list_org_ids retrieve_org store_org );
use Encode;

binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");

# This file is used to:
# Set the validation status of existing orgs to 'accepted' for the ones in the list,
# and sync with the CRM.
# Reject all the others and are sent a rejection email notification.
# Set the org name if it is missing.

# Set Manon as the salesperson for the orgs
$User_id = 'manoncorneille';

use Data::Dumper;
my %accepted = accepted_orgs();

foreach my $org_id (list_org_ids()) {
	$org_id = decode utf8 => $org_id;
	my $org_ref = retrieve_org($org_id);

	my $org_name = $org_ref->{name};
	if (not defined $org_name) {
		$org_ref->{name} = $org_id =~ s/-/ /gr;
	}

	my $org_is_valid = exists $accepted{$org_id};
	if ($org_is_valid) {
		$org_ref->{valid_org} = 'accepted';
	}
	else {
		$org_ref->{valid_org} = 'rejected';
	}

	store_org($org_ref);
	if ($org_is_valid) {
		print "$org_id\n";
	}
}

sub accepted_orgs {
	my @orgs = qw(
		auchan-apaw
		systeme-u
		les-mousquetaires
		scamark
		carrefour-espana
		monoprix
		alnatura
		unilever-france-gms
		nestle-france
		groupe-ldc
		lea-nature
		pepsico-france
		biocoop
		panzani-sa
		d-aucy
		bledina
		barilla
		ferrero-france-commerciale
		sill-entreprises
		yoplait-france
		bonduelle
		unilever-france
		materne
		arcadie
		la-belle-iloise
		laita
		danone-france
		brasseries-kronenbourg
		kazidomi
		barilla-france-sa
		ethiquable
		bel-france
		aoste
		carambar-co
		jacquet-brossard-distribution
		amalric-isla-delice
		royal-bourbon-industries
		bernard-royal-dauphine
		l-hermitage-sarl
		letswork-group
		idiffusion
		palais-des-mets
		ksante
		sas-jeannette-1850
		envie-d-oeufs
		kellogg-s
		la-fourche
		zweifel
		lustucru-frais
		cafes-bibal-torrefacteur
		ecoidees
		unilever-france-rhd
		rund-um-die-biene
		lactalis-fromages
		kaufland
		elle-vire
		fromagerie-milleret
		mere-lalie
		kambly-france
		les-compagnons-du-miel
		gerard-bertrand
		les-anis-de-l-abbaye-de-flavigny
		pere-dodu
		glaces-de-lyon
		la-boulangere-co
		st-mamet
		saint
		saint-hubert
		groupe-bel
		comme-jaime
		les-pates-grand-mere
		nestle-waters
		la-trinitaine
		laita-uf
		bel
		maison-torres
		mincavi
		cristalco
		boehli
		huel
		saffron
		kluth
		el-dulze
		coeur-de-pom
		little-gustave
		biscuiterie-de-l-abbaye
		terra-douceurs
		menguy-s
		conserverie-locale-artisanale-et-creative
		lokki
		hida-alimentacion-s-a
		les-nicois
		1664
		1001-graines
		10x-innovation-gmbh-co-kg
		3-monts
		a-de-fussigny
		abegoa-unipessoal-lda
		aceites-de-las-heras
		achats-marchandises-casino
		adwatis
		african-dream-taste-sarl
		afro-regal
		agro-sourcing
		al-fassia
		al-halabi
		alcimed
		aldi
		algroupe
		aline-olivier
		alpes-biscuits
		alpro
		alsace-lait
		alterfood-drinkyz
		andre-bazin
		anne-rozes
		aop-epoisses
		apericube-groupe-bel
		aqualande
		atelier-v
		auguste-bloch
		autour-du-riz
		avena
		avenia
		aydan-foods-s-a-r-l
		baker-and-baker
		baouw-organic-nutrition
		baronie-group
		basta
		batteleku-conserverie-jean-de-luz
		bee-consom-action
		beerscuit
		beess-up
		beirut-beer
		belledonne
		bergams
		bien-bon
		bioanalytics
		biobleud
		biofactoria-naturae-et-salus
		biscuiterie-cake-by-the-ocean
		biscuiterie-la-trinitaine
		biscuiterie-maison-le-goff
		biscuiterie-ouro
		biscuits-agathe
		biscuits-bouvard
		bjorg
		bjorg-bonneterre-et-compagnie
		bodin
		bolton-food
		bolton-food-sas
		bonbons-du-vercors
		bonduelle-europe-long-life
		borex-poissons
		borges-tramier
		bourbon-d-arsel
		bovetti
		bovetti-chocolat
		bpa
		bpa-angers
		brasserie-dupont
		breizh-on-egg
		brf
		brio-fruits
		brioches-pasquier
		brioches-thomas
		brousse-fils
		brussels-ketjep
		bulle-d-opale
		by-faratiana
		cacolac
		cafes-broceliande
		canavere
		candia
		caraldine
		carte-noire
		catlion-srl
		cemafood
		cėrebos
		ceres-epicerie-fine-sarl
		champagne-forget-brimont
		chancerelle
		charles-alice
		charles-chocolartisan
		charles-christ-nutriform-gillet-contres
		chateau-cormeil-figeac
		chicoree-leroux
		chicorevi
		circl-labs
		cirezi-food
		clac
		cocoa-valley
		cocoriton
		color-sa
		comme-j-aime
		compagnie-fruitiere
		confit-de-provence
		conserverie-gonidec
		contreeb
		coppenrath-wiese-kg
		coppola-industria-alimentare-srl
		culinare
		damiano
		danone
		danone-deutschland-gmbh
		danone-eaux-france-saeme
		dei
		delouis-france
		dodoni
		dodoni-sa
		dom-petroff
		domaine-de-la-flaguerie
		dpap
		dr-oetker-france-epicerie
		ecocascara-sa
		el-morjane
		elsy
		elvir
		elvir-elle-vire
		enasel
		enfin
		ensoleil-ade
		entreprise-cerf-dellier-marque-patisdecor
		epi-co
		epi-co-tereos
		epices-shira
		estandon
		eureden-d-aucy-france
		eurial
		eurial-sas
		euroconsumers
		europastry-s-a
		fage-international-s-a
		fair-farmers-market
		falafel
		ferme-de-grignon
		findus
		finesse-des-vergers
		florentin
		fnpl
		foie-gras-gourmet
		foodbowel
		foodles
		frais-embal
		france-cake-tradition
		franprix
		fresh-food-village
		frieslandcampina
		fromageries-bel
		fromarsac
		fruit-i-bee
		fruit-ride
		fruits-de-la-terre
		fruits-you
		funky-veggie
		gaec-de-courtilles
		gaudemer-azur-naturel
		gelagri
		gepack
		gingeur
		go-nuts
		golden-land
		gozoki
		graam
		graine-de-choc
		granarolo
		grand-fermage
		greenshoot
		greenweez
		groupe-broceliande
		groupe-danone
		groupe-soufflet
		guschette
		guyader-terroir-et-creation
		hairlust
		happy-ingredients
		happyvore
		hari-co
		hcentrale
		helene-grece-authentique
		hello-bio
		henaff
		homo-vegetaliens
		hqc-europe
		huile-d-olive-nikos
		i-grec
		ibo
		ideel-garden
		in-extremis
		incara-lab
		inno-vo-les-fees-bio-piaf-planet-cocktail
		innocent
		inpanasa
		intersnack
		intersnack-france
		invitation-a-la-ferme
		italians-do-it-better
		iuss-pavia
		jacquet-brossard
		jajaja
		jampi-glacier
		jardin-a-croquer
		jardins-arts-et-compagnie
		jc-david
		jeff-de-bruges
		jensens-foods
		jus-de-fruits-caraibes
		just4youcoaching
		juste-presse
		kalio
		kambly
		karine-jeff
		karyon
		ker-cadelac
		kokoji
		koro
		krokola
		kumo
		kyo-kombucha
		l-atelier-du-ferment
		l-atelier-v
		l-atelier-vegetal
		l-esperantine
		l-oustau-de-camille
		la-baleine
		la-belle-dreche
		la-boite-a-encas-foodles
		la-coop
		la-cour-d-orgeres
		la-fabrik-d-anscaire
		la-fromagerie-des-cevennes
		la-goulettoise
		la-jucerie
		la-main-dans-le-bol
		la-mesa-de-moras
		la-miellerie-vendeenne
		la-p-tite-ferme
		la-preserverie
		la-veggisserie
		la-vie
		la-vie-foods
		label-bee-friendly
		label-non-gmo-project
		laboratoire-france-bebe-nutrition
		laboratoire-santarel
		laboratoires-santinov
		lactalis
		lactalis-b-c
		lait-du-forez
		lamprien-provence
		le-club-bio
		le-comptoir-de-syrie
		le-craulois
		le-gaulois
		le-labo-dumoulin-lld-cie-producteur-de-kefir-de-fruit
		le-magicien-bio
		le-manchec
		le-pain-de-belledonne-sas
		le-pain-des-fleurs
		le-petit-versaillais
		le-sojami
		les-3-chouettes
		les-biolonistes
		les-bocaux-a-papa
		les-crea-du-domaine-des-tileuls-d-or
		les-escalettes-de-montpellier
		les-fabuleuses
		les-fous-de-terroirs
		les-nouveaux-affineurs
		les-nouveaux-fermiers
		les-tortillas-de-sonora
		lesieur
		lioravi
		liquid-forest-sas
		little-garden
		lld
		lotus-bakeries
		lou-karitan
		loue
		lucien-georgelin
		lunor
		lunor-distribution
		lustucru
		lynos
		machines-de-torrefaction-du-cafe-et-de-fruits-secs
		madeleines-bijou
		mademoiselle-desserts
		madrange
		magnum-nutraceuticals
		mahida-food-products
		maison-briau
		maison-gilliard
		maison-le-goff
		maison-martin
		maison-montfort
		maison-noe
		maison-perard
		maison-perrotte
		marie-morin-france
		marlette
		marques-propres
		martin-pouret
		mate-co
		matecito
		matines
		melfor
		mere-lalie-stephan
		michel-et-augustin
		micouleau
		mini-babybel
		mix-buffet
		mouneyrac
		mowi
		muller
		mytilimer
		nakd
		natifood
		natur-ab
		natural-development
		nature-aliments
		natureo
		naturvega
		neeka
		neyla
		norfood-sas
		normandoise
		nossa-fruits
		novo-cristal-sa
		nu3
		nudj
		nutraverse
		objet-fetiche
		ocean-spray
		ocni-factory
		ocu
		oeuf-de-nos-villages
		olvac
		omie
		omnomnom
		once-upon-a-tarte
		one-day-more
		onedaymore
		origeens
		owater
		pacha
		packtic
		panzani
		papapero
		partners-partners
		pastacorp-ecochard
		patris
		pave-d-affinois
		paysan-breton
		peaceful-delicious
		pek-makina
		periscop
		petit-cote
		picard-surgeles
		piccolo
		pierre-schmidt
		pietercil-interco
		pink-lady-europe
		pizzami-galati-s-r-l
		plantus
		pleurette
		prenfit
		pressade
		pretexte
		provence-prim
		proxifresh
		pural
		qaada
		qilibri
		qm
		raw-group
		re-belle
		reine-de-dijon
		reitzel
		reitzel-briand
		reseau-ges
		resurrection
		ricola
		rochefontaine
		royal-bernard
		sacla-sas
		saint-amour
		saint-jean
		saint-louis-sucre
		sarl-olvas
		sas-tadh
		savencia
		saveurs-d-hyeres
		saveurs-des-mauges
		sca-les-vignerons-du-mont-ventoux
		scl-agency
		sebil
		seconde-simon
		segafredo
		sensei-family
		sequoia-odg
		sev
		shanghai-food
		sia-labs
		sill
		simplot-australia
		sincera
		sirignano-srl
		smart-green
		so-vi-li-ma
		societe-nouvelle-de-boissons
		sodebo
		soin-amalthee
		soleane
		solis-culturae
		soverini
		spiruline-des-frangines
		spirulix
		st-jude
		swity
		tariette
		terraroma
		terres-bleues
		test-achats
		tienda-de-fruta
		timelapp-box
		tipiak-traiteur-patissier
		tomate-o-coeur
		tossolia
		tout-feu-tout-frais
		tramier
		triballat-noyal
		turtle
		ucc-coffee-uk
		umamiz-les-spiruvores
		un-zebre-en-cuisine
		unika-consulting-llc
		unilever-gms
		unipex-france-solution
		upfield
		vale-da-sarvinda
		vallee-verte-les-jus-du-soleil
		vallegrain
		vaubernier
		vegafruits
		vege-toque
		vegfood
		vendee-grands-crus
		virtualpackshot
		vitago
		vrai
		wok-foods
		yvan-gregory
	);
	my %hash;
	@hash{@orgs} = undef;
	return %hash;
}
