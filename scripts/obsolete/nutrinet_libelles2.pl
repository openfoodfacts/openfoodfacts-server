#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use strict;

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Products qw/:all/;


use URI::Escape::XS;

#open (my $in, "<:encoding(UTF-8)", "/home/off/nutrinet/Nutrinet_Marques_Autres_20171121-PourOFF.csv");
open (my $in, "<:encoding(windows-1252)", "/home/off/nutrinet/Nettoyage-marques_Pour-OFF.csv");

my %libelle;
my %code_aliment;
my %id_libelle;
my %id_marque;
my %id_marque_net;
my %id_sans_nutrinet;
my %id_nutrinet_aliments;
my %marque;

my %marque_ids;

my %libelle_marque_id;
my %libelle_marque_id_libelle;
my %libelle_marque_id_marque;
my %libelle_marque_id_code_aliment;
my %libelle_marque_id_id_nutrinet_aliments;

my $header = <$in>;

my $i = 0;

while(<$in>) {
	my $line = $_;
	chomp($line);
	$line =~ s/\r|\n//g;
	my ($id, $code_aliment, $libelle, $id_nutrinet_aliments, $marque, $marque_net)
	= split(/;/, $line);


	$libelle{$libelle}++;
	$code_aliment{$code_aliment}++;
	$id_libelle{$id} = $libelle;
	$id_marque{$id} = $marque;
	$id_marque_net{$id} = $marque_net;
	$id_nutrinet_aliments{$id_nutrinet_aliments}++;

	my $libelle_marque_id = get_fileid($libelle) . " " . get_fileid($marque);
	$libelle_marque_id{$libelle_marque_id}++;
	$libelle_marque_id_code_aliment{$libelle_marque_id} = $code_aliment;
	($id_nutrinet_aliments ne '') and $libelle_marque_id_id_nutrinet_aliments{$libelle_marque_id} = $id_nutrinet_aliments;
	#$libelle_marque_id_marque{$libelle_marque_id} = $marque;
	$libelle_marque_id_marque{$libelle_marque_id} = $marque_net;
	$libelle_marque_id_libelle{$libelle_marque_id} = $libelle;

	if ((not defined $id_nutrinet_aliments) or ($id_nutrinet_aliments eq "")) {
		$id_sans_nutrinet{$code_aliment}++;
	}

	$marque{$marque}++;
	$marque_ids{ get_fileid($marque)}++;
	$i++;

#	print "$marque\n";
}



my $l1 = 0;
my $l2 = 0;

my %libelle_category;

if (1) { foreach my $libelle (sort { $libelle{$b} <=> $libelle{$a}} keys %libelle) {

	$l1++;

	my $tag = canonicalize_taxonomy_tag("fr", "categories", $libelle);

	my $libelle2 = $libelle;
	$libelle2 =~ s/\([^\)]*\)//;
	my $tag2 = canonicalize_taxonomy_tag("fr", "categories", $libelle2);

	if (exists_taxonomy_tag("categories", $tag)) {
                #print $libelle . "\t" . $libelle{$libelle} . "\t" . $tag . "\t" . display_taxonomy_tag("fr", "categories", $tag) . "\t" . display_taxonomy_tag_link("fr", "categories", $tag) . "\n";
		$l2++;
		$libelle_category{$libelle} = $tag;
	}
	elsif (exists_taxonomy_tag("categories", $tag2)) {
                #print $libelle . "\t" . $libelle{$libelle} . "\t" . $tag2 . "\t" . display_taxonomy_tag("fr", "categories", $tag2) . "\t" . display_taxonomy_tag_link("fr", "categories", $tag2) . "\n";
                $l2++;
		$libelle_category{$libelle} = $tag2;
        }

	else {
		#print $libelle . "\t" . $libelle{$libelle}  . "\n";
#	print "\n";
	}
}
print "$l1 libelles - $l2 libelles dans la taxonomie categories\n";

}

#exit;

print "$i items - libelle: " . (keys %libelle) . " - marque: " . (keys %marque ) . " - marque_id: " . (keys %marque_ids) . " - code_aliment: " . (keys %code_aliment  ) . " - id_nutrinet_aliments : " . (keys %id_nutrinet_aliments ) 
. " - libelle_marque_id: " . (keys %libelle_marque_id) . "\n";



foreach my $libelle_marque_id (sort { $libelle_marque_id{$b} <=> $libelle_marque_id{$a} } keys %libelle_marque_id ) {

	my $libelle = $libelle_marque_id_libelle{$libelle_marque_id};
	my $marque = $libelle_marque_id_marque{$libelle_marque_id};

	print STDERR $libelle_marque_id{$libelle_marque_id} . "\t" . $libelle_marque_id . "\t" . $libelle_marque_id_libelle{$libelle_marque_id} . "\t" .  $libelle_marque_id_marque{$libelle_marque_id} . "\n";

	my $query_ref = {};
	my $current_link = "";

	my $search_terms = $libelle_marque_id_marque{$libelle_marque_id} . " ";

	if (defined $libelle_category{$libelle}) {
		$query_ref->{categories_tags} = $libelle_category{$libelle};
		$current_link .= "&tagtype_0=categories&tag_contains_0=contains&tag_0=" . $libelle_category{$libelle};
	}
	else {
		$search_terms .= $libelle;
	}

	$search_terms =~ s/\(([^\)]*)\)/ /i;

			my %terms = ();

			foreach my $term (split(/,|'|\s/, $search_terms)) {
				if (length(get_fileid($term)) >= 2) {
					my $n = normalize_search_terms(get_fileid($term));
					next if $n eq 'type';
					$terms{$n} = 1;
				}
			}
			if (scalar keys %terms > 0) {
				$query_ref->{_keywords} = { '$all' => [keys %terms]};
				$current_link .= "\&search_terms=" . URI::Escape::XS::encodeURIComponent($search_terms);
			}

	$query_ref->{countries_tags} = "en:france";

	my $sort_ref = { last_modified_t_complete_first => -1 };

	my $cursor;

	eval {

	$cursor = $products_collection->query($query_ref)->sort($sort_ref)->limit(20)->skip(0);

	};

	my $test = 1;

	if ($@) {
		# maybe $connection auto-reconnects but $database and $products_collection still reference the old connection?
		
		# opening new connection
		eval {
			$connection = MongoDB->connect($mongodb_host);
			$database = $connection->get_database($mongodb);
			$products_collection = $database->get_collection('products');
	
        $cursor = $products_collection->query($query_ref)->sort($sort_ref)->limit(20)->skip(0);

		};
	}

	$current_link = "https://fr.openfoodfacts.org/cgi/search.pl?action=process" . $current_link;

	print STDERR "\n:current_link: " . $current_link . "\n";

	my $off_produit = "";
	my $off_url = "";

	if ($cursor->has_next) {
		my $product_ref = $cursor->next;

		$off_produit = $product_ref->{product_name} 
			. " / " . $product_ref->{brands};

		my $t = "test";

		$off_url = "https://fr.openfoodfacts.org/produit/" . $product_ref->{code} ;
	}

	print $libelle_marque_id{$libelle_marque_id} . "\t" . 
	$libelle_marque_id_code_aliment{$libelle_marque_id} . "\t" 
	. $libelle_marque_id_libelle{$libelle_marque_id} . "\t"
	. $libelle_marque_id_id_nutrinet_aliments{$libelle_marque_id} . "\t"
	
  	. $libelle_marque_id_marque{$libelle_marque_id} . "\t" . $current_link . "\t" . $off_url . "\t" . $off_produit . "\n";

}


