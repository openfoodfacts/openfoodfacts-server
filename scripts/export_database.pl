#!/usr/bin/perl

use CGI::Carp qw(fatalsToBrowser);

use Modern::Perl '2012';
use utf8;

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
use ProductOpener::Lang qw/:all/;

# for RDF export: replace xml_escape() with xml_escape_NFC()
use Unicode::Normalize;




use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON;
use DateTime qw/:all/;


sub xml_escape_NFC($) {

        my $s = shift;
        return xml_escape(NFC($s));
}


my %tags_fields = (packaging => 1, brands => 1, categories => 1, labels => 1, origins => 1, manufacturing_places => 1, emb_codes=>1, cities=>1, allergen=>1, traces => 1, additives => 1, ingredients_from_palm_oil => 1, ingredients_that_may_be_from_palm_oil => 1, countries => 1, states=>1);

my @fields = qw (
code
creator
created_t
last_modified_t
product_name
generic_name
quantity
packaging
brands 
categories 
origins
manufacturing_places
labels
emb_codes
cities
purchase_places
stores
countries
ingredients_text
allergens
traces
serving_size
no_nutriments
additives_n
additives
ingredients_from_palm_oil_n
ingredients_from_palm_oil
ingredients_that_may_be_from_palm_oil_n
ingredients_that_may_be_from_palm_oil
nutrition_grade_uk
nutrition_grade_fr
pnns_groups_1
pnns_groups_2
states
);



my %langs = ();
my $total = 0;

my $fields_ref = {};
	
foreach my $field (@fields) {
	$fields_ref->{$field} = 1;
	if (defined $tags_fields{$field}) {
		$fields_ref->{$field . "_tags"} = 1;
	}
}

$fields_ref->{nutriments} = 1;
$fields_ref->{ingredients} = 1;
$fields_ref->{images} = 1;


	
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
my $date = sprintf("%04d-%02d-%02d", $year + 1900, $mon + 1, $mday);	

# now that we have 200 languages, we can't run the export for every language. 
# foreach my $l (values %lang_lc) {
foreach my $l ("en", "fr") {

	$lc = $l;
	$lang = $l;
	
	my $categories_nutriments_ref = retrieve("$data_root/index/categories_nutriments.$lc.sto");	

	
	my $cursor = $products_collection->query({'code' => { "\$ne" => "" }}, {'empty' => { "\$ne" => 1 }})->fields($fields_ref)->sort({code=>1});
	my $count = $cursor->count();
	
	$langs{$l} = $count;
	$total += $count;
		
	print STDERR "lc: $lc - $count products\n";
	
	open (my $OUT, ">:encoding(UTF-8)", "$www_root/data/$lang.$server_domain.products.csv");
	open (my $RDF, ">:encoding(UTF-8)", "$www_root/data/$lang.$server_domain.products.rdf");

	# Headers
	
	my $csv = '';
	
	print $RDF <<XML
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
		xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
		xmlns:food="http://data.lirmm.fr/ontologies/food#"
		xmlns:dcterms="http://purl.org/dc/terms/"
		xmlns:dc="http://purl.org/dc/elements/1.1/"
		xmlns:void="http://rdfs.org/ns/void#"
		xmlns:owl="http://www.w3.org/2002/07/owl#"
		xmlns:foaf="http://xmlns.com/foaf/0.1/">

<void:Dataset rdf:about="http://$lc.$server_domain">
	<void:dataDump rdf:resource="http://$lc.$server_domain/data/$lc.$server_domain.products.rdf"/>
	<void:vocabulary rdf:resource="http://data.lirmm.fr/ontologies/food"/>
	<dcterms:created rdf:datatype="http://www.w3.org/2001/XMLSchema#date">2012-05-21</dcterms:created>
	<dcterms:creator>Open Food Facts</dcterms:creator>
	<dcterms:description xml:lang="en">Data on food products from the world (includes ingredients, nutrition facts, brands, labels etc.) from http://$lc.$server_domain</dcterms:description>
	<dcterms:description xml:lang="fr">Données sur les produits alimentaires du monde entier (ingrédients, composition nutritionnelle, marques, labels etc.)</dcterms:description>
	<dcterms:license rdf:resource="https://opendatacommons.org/licenses/odbl/"/>
	<dcterms:modified rdf:datatype="http://www.w3.org/2001/XMLSchema#date">$date</dcterms:modified>
	<dcterms:subject rdf:resource="http://dbpedia.org/resource/Food"/>
	<dcterms:subject rdf:resource="http://dbpedia.org/resource/Nutrition"/>
	<dcterms:subject rdf:resource="http://dbpedia.org/resource/Nutrition_facts_label"/>
	<dcterms:subject rdf:resource="http://dbpedia.org/resource/Food_energy"/>
	<dcterms:title>Open Food Facts ($lc)</dcterms:title>
	<foaf:homepage rdf:resource="http://$lc.$server_domain"/>
</void:Dataset>	

<!--
This is a RDF export of the http://$lc.$server_domain food products database.
The database is available under Open Database Licence 1.0 (ODbL) https://opendatacommons.org/licenses/odbl/1.0/
-->

XML
;
	
	
		foreach my $field (@fields) {
		
			$csv .= $field . "\t";

		
			if ($field eq 'code') {
			
				$csv .= "url\t";
			
			}
			
			if ($field =~ /_t$/) {
				$csv .= $` . "_datetime\t";
			}
		
			if (defined $tags_fields{$field}) {
				$csv .= $field . '_tags' . "\t";
			}
			
			if (defined $taxonomy_fields{$field}) {
				$csv .= $field . "_$lc" . "\t";
			}
			
			if ($field eq 'emb_codes') {
				$csv .= "first_packaging_code_geo\t";
			}
		
		}
		
		$csv .= "main_category\tmain_category_$lc\t";
		
		$csv .= "image_url\timage_small_url\t";
		
		
		
		foreach my $nid (@{$nutriments_tables{"europe"}}) {
		
			$nid =~ /^#/ and next;
		
			$nid =~ s/!//g;
			$nid =~ s/^-//g;
			$nid =~ s/-$//g;
					
			$csv .= "${nid}_100g" . "\t";
		}	
	
	$csv =~ s/\t$/\n/;
	print $OUT $csv;
	
	# Products
	
	my %ingredients = ();
		
	while (my $product_ref = $cursor->next) {
		
		my $csv = '';
		my $url = "http://world-$lc.$server_domain" . product_url($product_ref);
		my $code = $product_ref->{code};
		
		$code eq '' and next;
		$code < 1 and next;
		
		foreach my $field (@fields) {
		
			$product_ref->{$field} =~ s/(\r|\n|\t)+/ /g;
		
			$csv .= $product_ref->{$field} . "\t";

		
			if ($field eq 'code') {
			
				
				$csv .=  $url . "\t";
			
			}
			
			if ($field =~ /_t$/) {
				if ($product_ref->{$field} > 0) {
					my $dt = DateTime->from_epoch( epoch => $product_ref->{$field} );
					$csv .= $dt->datetime() . 'Z' . "\t";
				}
				else {
					$csv .= "\t";
				}
			}
		
			if (defined $tags_fields{$field}) {
				if (defined $product_ref->{$field . '_tags'}) {				
					$csv .= join(',', @{$product_ref->{$field . '_tags'}}) . "\t";
				}
				else {
					$csv .= "\t";
				}
			}
			if (defined $taxonomy_fields{$field}) {
				if (defined $product_ref->{$field . '_tags'}) {				
					$csv .= join(',', map {display_taxonomy_tag($lc, $field, $_)}  @{$product_ref->{$field . '_tags'}}) . "\t";
				}
				else {
					$csv .= "\t";
				}			
			}
			
			if ($field eq 'emb_codes') {
				# take the first emb code
				my $geo = '';
				if (defined $product_ref->{"emb_codes_tags"}[0]) {
					my $emb_code = $product_ref->{"emb_codes_tags"}[0];
					my $city_code = get_city_code($emb_code);
					if (defined $emb_codes_geo{$city_code}) {
						$geo = $emb_codes_geo{$city_code}[0] . ',' . $emb_codes_geo{$city_code}[1];
					}
				}
				$csv .= $geo . "\t";
			}
			
		
		}
		
		

		# Try to get the "main" category: smallest category with at least 10 products with nutrition data
		
		my @comparisons = ();
		my %comparisons = ();
		
		my $main_cid = '';
		my $main_cid_lc = '';
		
		if ((defined $product_ref->{categories_tags}) and (scalar @{$product_ref->{categories_tags}} > 0)) {
		
			$main_cid = $product_ref->{categories_tags}[0];
			
			
		
			foreach my $cid (@{$product_ref->{categories_tags}}) {
				if ((defined $categories_nutriments_ref->{$cid}) and (defined $categories_nutriments_ref->{$cid}{stats})) {
					push @comparisons, {
						id => $cid,
						name => canonicalize_tag2('categories', $cid),
						link => canonicalize_taxonomy_tag_link($lc,'categories', $cid),
						nutriments => compare_nutriments($product_ref, $categories_nutriments_ref->{$cid}),
						count => $categories_nutriments_ref->{$cid}{count},
						n => $categories_nutriments_ref->{$cid}{n},
					};
				}
			}
			
			# print STDERR "main_cid_orig: $main_cid comparisons: $#comparisons\n";
			
			
			if ($#comparisons > -1) {
				@comparisons = sort { $a->{count} <=> $b->{count}} @comparisons;
				$comparisons[0]{show} = 1;
				$main_cid = $comparisons[0]{id};
				# print STDERR "main_cid: $main_cid\n";
			}
			
		}		
		
		if ($main_cid ne '') {
			$main_cid = canonicalize_tag2("categories",$main_cid);
			$main_cid_lc = display_taxonomy_tag($lc, 'categories', $main_cid);
		}
		
		$csv .= $main_cid . "\t";
		$csv .= $main_cid_lc . "\t";
		
		$product_ref->{main_category} = $main_cid;		
		
		my $id = 'front';
		my $size = $display_size;
		
		if ((defined $product_ref->{images}) and (defined $product_ref->{images}{$id})
			and (defined $product_ref->{images}{$id}{sizes}) and (defined $product_ref->{images}{$id}{sizes}{$size})) {
		
			my $path = product_path($product_ref->{code});

			
			$product_ref->{image_url} = "http://$lc.$server_domain/images/products/$path/$id." . $product_ref->{images}{$id}{rev} . '.' . $display_size . '.jpg';
			$product_ref->{image_small_url} = "http://$lc.$server_domain/images/products/$path/$id." . $product_ref->{images}{$id}{rev} . '.' . $small_size . '.jpg';
		
			
		}
		
		$csv .= $product_ref->{image_url} . "\t" . $product_ref->{image_small_url} . "\t";

		
		foreach my $nid (@{$nutriments_tables{"europe"}}) {
		
			$nid =~/^#/ and next;
		
			$nid =~ s/!//g;
			$nid =~ s/^-//g;
			$nid =~ s/-$//g;
			
			if (defined $product_ref->{nutriments}{$nid . "_100g"}) {		
			$csv .= $product_ref->{nutriments}{$nid . "_100g"} . "\t";
			}
			else {
				$csv .= "\t";
			}
		}
		
		$csv =~ s/\t$/\n/;
		
		my $name = xml_escape_NFC($product_ref->{product_name});
		my $ingredients_text = xml_escape_NFC($product_ref->{ingredients_text});
		
		my $rdf = <<XML
<rdf:Description rdf:about="$url" rdf:type="http://data.lirmm.fr/ontologies/food#FoodProduct">
	<food:code>$code</food:code>
	<food:name>$name</food:name>
	<food:IngredientListAsText>${ingredients_text}</food:IngredientListAsText>	
XML
;

		if (defined $product_ref->{ingredients}) {

			foreach my $i (@{$product_ref->{ingredients}}) {
		
				$rdf .= "\t<food:containsIngredient>\n\t\t<food:Ingredient>\n\t\t\t<food:food rdf:resource=\"http://fr.$server_domain/ingredient/" . $i->{id} . "\" />\n";
				not defined $ingredients{$i->{id}} and $ingredients{$i->{id}} = {};
				$ingredients{$i->{id}}{ucfirst($i->{text})}++;
				if (defined $i->{rank}) {
					$rdf .= "\t\t\t<food:rank>" . $i->{rank} . "</food:rank>\n";
				}
				if (defined $i->{percent}) {
					$rdf .= "\t\t\t<food:percent>" . $i->{percent} . "</food:percent>\n";
				}			
				$rdf .= "\t\t</food:Ingredient>\n";
				$rdf .= "\t</food:containsIngredient>\n";
		
			}	
		}
		
		foreach my $nid (keys %Nutriments) {
		
			if ((defined $product_ref->{nutriments}{$nid . '_100g'}) and ($product_ref->{nutriments}{$nid . '_100g'} ne '')) {
				my $property = $nid;
				next if ($nid =~ /^#/); #   #vitamins and #minerals sometimes filled
				$property =~ s/-([a-z])/ucfirst($1)/eg;
				$property .= "Per100g";
				
				$rdf .= "\t<food:$property>" . $product_ref->{nutriments}{$nid . '_100g'} . "</food:$property>\n";
			}
		
		}
		
		$rdf .= "</rdf:Description>\n\n";
				 
		print $OUT $csv;
		print $RDF $rdf;

	}
	
	close $OUT;
	
	my %links = ();
	if (-e "$data_root/rdf/${lc}_links")  {
	
		# <http://fr.$server_domain/ingredient/xylitol>  <http://www.w3.org/2002/07/owl#sameAs>  <http://fr.dbpedia.org/resource/Xylitol> 
	
		open my $IN, q{<}, "$data_root/rdf/${lc}_links";
		while(<$IN>) {
			my $l = $_;
			if ($l =~ /<.*ingredient\/(.*)>\s*<.*>\s*<(.*)>/) {
				my $ingredient = $1;
				my $sameas = $2;
				$links{$ingredient} = $sameas;
			}
		}
	}
	
	foreach my $i (sort keys %ingredients) {
	
		my @names = sort ( { $ingredients{$i}{$b} <=> $ingredients{$i}{$a} } keys %{$ingredients{$i}});
		my $name = xml_escape_NFC($names[0]);	
		
		# sameAs
		# <owl:sameAs rdf:resource="http://www.blueobelisk.org/ontologies/chemoinformatics-algorithms/#xlogP"/>
		
		my $sameas = '';
		if (defined $links{$i}) {
			$sameas = "\n\t<owl:sameAs rdf:resource=\"$links{$i}\"/>";
		}
		
		print $RDF <<XML
<rdf:Description rdf:about="http://$lc.$server_domain/ingredient/$i" rdf:type="http://data.lirmm.fr/ontologies/food#Food">
	<food:name>$name</food:name>$sameas
</rdf:Description>

XML
;	
	}
	
	print $RDF <<XML
</rdf:RDF>
XML
;
	
	close $RDF;
	
}


my $html = "<p>$total products:</p>";
foreach my $l (sort { $langs{$b} <=> $langs{$a}} keys %langs) {

	if ($langs{$l} > 0) {
		$lang = $l;
		$html .= "<p><a href=\"http://$lang.$server_domain/\">" . $Langs{$l} . "</a> - $langs{$l} " . lang("products") . "</p>";
	}

}
open (my $OUT, ">:encoding(UTF-8)", "$www_root/langs.html");
print $OUT $html;
close $OUT;

exit(0);

