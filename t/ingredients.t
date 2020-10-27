#!/usr/bin/perl -w

use strict;
use warnings;

use utf8;

use Test::More;
use Log::Any::Adapter 'TAP';

use JSON;
use Getopt::Long;

use ProductOpener::Config qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::TagsEntries qw/:all/;
use ProductOpener::Ingredients qw/:all/;

my $testdir = "ingredients";

my $usage = <<TXT

The expected results of the tests are saved in $data_root/t/expected_test_results/$testdir

To verify differences and update the expected test results, actual test results
can be saved to a directory by passing --results [path of results directory]

The directory will be created if it does not already exist.

TXT
;

my $resultsdir;

GetOptions ("results=s"   => \$resultsdir)
  or die("Error in command line arguments.\n\n" . $usage);
  
if ((defined $resultsdir) and (! -e $resultsdir)) {
	mkdir($resultsdir, 0755) or die("Could not create $resultsdir directory: $!\n");
}

my @tests = (

	# FR
	
	[
		'fr-chocolate-cake',
		{
			lc => "fr",
			ingredients_text => "farine (12%), chocolat (beurre de cacao (15%), sucre [10%], protéines de lait, oeuf 1%) - émulsifiants : E463, E432 et E472 - correcteurs d'acidité : E322/E333 E474-E475, acidifiant (acide citrique, acide phosphorique) - sel"
		}
	],		
		
	[
		'fr-palm-kernel-fat',
		{
			lc => "fr",
			ingredients_text => "graisse de palmiste"
		}
	],		
	
	[
		'fr-marmelade',
		{
			lc => "fr",
			ingredients_text => "Marmelade d'oranges 41% (sirop de glucose-fructose, sucre, pulpe d'orange 4.5%, jus d'orange concentré 1.4% (équivalent jus d'orange 7.8%), pulpe d'orange concentrée 0.6% (équivalent pulpe d'orange 2.6%), gélifiant (pectines), acidifiant (acide citrique), correcteurs d'acidité (citrate de calcium, citrate de sodium), arôme naturel d'orange, épaississant (gomme xanthane)), chocolat 24.9% (sucre, pâte de cacao, beurre de cacao, graisses végétales (illipe, mangue, sal, karité et palme en proportions variables), arôme, émulsifiant (lécithine de soja), lactose et protéines de lait), farine de blé, sucre, oeufs, sirop de glucose-fructose, huile de colza, poudre à lever (carbonate acide d'ammonium, diphosphate disodique, carbonate acide de sodium), sel, émulsifiant (lécithine de soja)."
		}
	],

	# test synonyms for flavouring/flavour/flavor/flavoring
	[
		'en-flavour-synonyms',
		{
			lc => "en",
			ingredients_text => "Natural orange flavor, Lemon flavouring"
		}
	],

	# FR * label
	[
		"fr-starred-label",
		{
			lc => "fr",
			ingredients_text => "pâte de cacao* de Madagascar 75%, sucre de canne*, beurre de cacao*. * issus du commerce équitable et de l'agriculture biologique (100% du poids total)."
		}
	],

	# FR additive
	[
		"fr-additive",
		{
			lc => "fr",
			ingredients_text => "gélifiant (pectines)",
		}
	],

	# FR percents
	[
		"fr-percents",
		{
			lc => "fr",
			ingredients_text => "Fraise 12,3% ; Orange 6.5%, Pomme (3,5%)",
		}
	],		

	# FR origins labels
	[
		"fr-origins-labels",
		{
			lc => "fr",
			ingredients_text => "Fraise origine France, Cassis (origine Afrique du Sud), Framboise (origine : Belgique), Pamplemousse bio, Orange (bio), Citron (issue de l'agriculture biologique), cacao et beurre de cacao (commerce équitable), cerises issues de l'agriculture biologique",
		}
	],

	# FR percents origins
	[
		"fr-percents-origins",
		{
			lc => "fr",
			ingredients_text => "80% jus de pomme biologique, 20% de coing biologique, sel marin, 98% chlorure de sodium (France, Italie)",
		}
	],
	
	[
		"fr-percents-origins-2",
		{
			lc => "fr",
			ingredients_text => "émulsifiant : lécithines (tournesol), arôme)(UE), farine de blé 33% (France), sucre, beurre concentré* 6,5% (France)",
		}
	],

	# FR vegetal origin
	[
		"fr-vegetal-origin",
		{
			lc => "fr",
			ingredients_text => "mono - et diglycérides d'acides gras d'origine végétale, huile d'origine végétale, gélatine (origine végétale)",
		}
	],		

	# FR labels
	[
		"fr-labels",
		{
			lc => "fr",
			ingredients_text => "jus d'orange (sans conservateur), saumon (msc), sans gluten",
		}
	],		

	# Processing
	
	[
		"fr-processing-multi",
		 {
			lc => "fr",
			ingredients_text => "tomates pelées cuites, rondelle de citron, dés de courgette, lait cru, aubergines crues, jambon cru en tranches",
		}
	],		

	# Bugs #3827, #3706, #3826 - truncated purée
	
	[
		"fr-truncated-puree",
		{
			lc => "fr",
			ingredients_text =>
				"19% purée de tomate, 90% boeuf, 100% pur jus de fruit, 45% de matière grasses",
		}
	],		

	# FI additives, percent
	
	[
		"fi-additives-percents",
		{
			lc => "fi",
			ingredients_text => "jauho (12%), suklaa (kaakaovoi (15%), sokeri [10%], maitoproteiini, kananmuna 1%) - emulgointiaineet : E463, E432 ja E472 - happamuudensäätöaineet : E322/E333 E474-E475, happo (sitruunahappo, fosforihappo) - suola"
		}
	],

	# FI percents
	
	[
		"fi-percents",
		{
			lc => "fi",
			ingredients_text => "Mansikka 12,3% ; Appelsiini 6.5%, Omena (3,5%)",
		}
	],

	# FI additives and origins

	[
		"fi-additive",
		{
			lc => "fi",
			ingredients_text => "hyytelöimisaine (pektiinit)",
		}
	],
		
	[
		"fi-origins",
		{
		lc => "fi",
		ingredients_text => "Mansikka alkuperä Suomi, Mustaherukka (alkuperä Etelä-Afrikka), Vadelma (alkuperä : Ruotsi), Appelsiini (luomu), kaakao ja kaakaovoi (reilu kauppa)",
	}
	],
	
	[
		"fi-additives-origins",
		{
			lc => "fi",
			ingredients_text => "emulgointiaine : auringonkukkalesitiini, aromi)(EU), vehnäjauho 33% (Ranska), sokeri",
		}
	],		

	# FI labels
	[
		"fi-labels",
		{
			lc => "fi",
			ingredients_text => "appelsiinimehu (säilöntäaineeton), lohi (msc), gluteeniton",
		}
	],

	# bug #3432 - mm. should not match Myanmar
	[
		"fi-do-not-match-myanmar",
		{
			lc => "fi",
			ingredients_text => "mausteet (mm. kurkuma, inkivääri, paprika, valkosipuli, korianteri, sinapinsiemen)",
		},
	],

	# FI - organic label as part of the ingredient
	[
		"fi-organic-label-part-of-ingredient",
		{
			lc => "fi",
			ingredients_text => "vihreä luomutee, luomumaito, luomu ohramallas",
		}
	],

	# a label and multiple origins in parenthesis -- does not work yet
	[
		"fr-label-and-multiple-origins",
		{
			lc => "fr",
			ingredients_text => "oeufs (d'élevage au sol, Suisse, France)",
		}
	],

	# Do not mistake single letters for labels, bug #3300
	[
		"xx-single-letters",
		{
			lc => "fr",
			ingredients_text => "a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z,0,1,2,3,4,5,6,7,8,9,10,100,1000,vt,leaf,something(bio),somethingelse(u)",
		}
	],
	
	# Origins with regions
	[
		"en-origins",
		{
			lc => "en",
			ingredients_text => "California almonds, South Carolina peaches, South Carolina black olives, fresh tomatoes (California), Oranges (Florida, USA), orange juice concentrate from Florida",
		},
	],
	# Do not match U to US -> United States (by removing the "plural" S from US)
	[
		"en-origins-u",
		{
			lc => "en",
			ingredients_text => "Something (U)"
		}
	],
	# French origins
	[
		"fr-origins",
		{
			lc => "fr",
			ingredients_text => "Fraises de Bretagne, beurre doux de Normandie, tomates cerises (Bretagne), pommes (origine : Normandie)"
		}
	],
);



my $json = JSON->new->allow_nonref->canonical;

foreach my $test_ref (@tests) {

	my $testid = $test_ref->[0];
	my $product_ref = $test_ref->[1];
	
	# Run the test
	
	extract_ingredients_from_text($product_ref);
	
	# Save the result
	
	if (defined $resultsdir) {
		open (my $result, ">:encoding(UTF-8)", "$resultsdir/$testid.json") or die("Could not create $resultsdir/$testid.json: $!\n");
		print $result $json->pretty->encode($product_ref);
		close ($result);
	}
	
	# Compare the result with the expected result
	
	if (open (my $expected_result, "<:encoding(UTF-8)", "$data_root/t/expected_test_results/$testdir/$testid.json")) {

		local $/; #Enable 'slurp' mode
		my $expected_product_ref = $json->decode(<$expected_result>);
		is_deeply ($product_ref, $expected_product_ref) or diag explain $product_ref;
	}
	else {
		fail("could not load expected_test_results/$testdir/$testid.json");
	}
}


done_testing();
