#!/usr/bin/perl -w

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
# along with this program.  If not, see <https://www.gnu.org/licenses/>.


# This script exports database in CSV and RDF/XML formats. It's a command line
# without any argument. Usage:
# ./export_database.pl

# TODO: factorize code with search_and_export_products() function
# from ./lib/ProductOpener/Display.pm


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
use ProductOpener::Data qw/:all/;

# for RDF export: replace xml_escape() with xml_escape_NFC()
use Unicode::Normalize;
use URI::Escape::XS;



use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;
use DateTime qw/:all/;


sub xml_escape_NFC($) {
	my $s = shift;
	if (defined $s) {
		$s = sanitize_field_content($s);
		return xml_escape(NFC($s)); # NFC is provided by Unicode::Normalize
	}
}


# function sanitize_field_content("content", $LOG_FILE, $log_msg)
#
#   Replace non visible ASCII chars which can break the CSV file.
#   Including NULL (000), SOH (001), STX (002), ETX (003), ETX (004), ENQ (005),
#   ACK (006), BEL (007), BS (010 or \b), HT (011 or \t), LF (012 or \n),
#   VT (013), FF (014 or \f), CR (015 or \r), etc.
#   See https://en.wikipedia.org/wiki/ASCII
#
#   TODO? put it in ProductOpener::Data & use it to control data input and output
#         Q: Do we have to *always* delete \n?
#   TODO? Send an email if bad-chars?
sub sanitize_field_content {
	my $content = (shift(@_) // "");
	my $LOG = shift(@_);
	my $log_msg = (shift(@_) // "");
	if ($content =~ /[\000-\037]/) {
		print $LOG "$log_msg $content\n\n---\n" if (defined $LOG);
		# TODO? replace the bad char by a space or by nothing?
		$content =~ s/[\000-\037]+/ /g;
	};
	return $content;
}


my %tags_fields = (packaging => 1, brands => 1, categories => 1, labels => 1, origins => 1, manufacturing_places => 1, emb_codes=>1, cities=>1, allergen=>1, traces => 1, additives => 1, ingredients_from_palm_oil => 1, ingredients_that_may_be_from_palm_oil => 1, countries => 1, states=>1);


my %langs = ();
my $total = 0;

my $fields_ref = {};

foreach my $field (@export_fields) {
	$fields_ref->{$field} = 1;
	if (defined $tags_fields{$field}) {
		$fields_ref->{$field . "_tags"} = 1;
	}
}

$fields_ref->{nutriments} = 1;
$fields_ref->{ingredients} = 1;
$fields_ref->{images} = 1;
$fields_ref->{lc} = 1;

# Current date, used for RDF dcterms:modified: 2019-02-07
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
my $date = sprintf("%04d-%02d-%02d", $year + 1900, $mon + 1, $mday);


# now that we have 200 languages, we can't run the export for every language.
# foreach my $l (values %lang_lc) {
foreach my $l ("en", "fr") {

	$lc = $l;
	$lang = $l;

	my $categories_nutriments_ref = retrieve("$data_root/index/categories_nutriments.$lc.sto");


	my $cursor = get_products_collection()->query({'code' => { "\$ne" => "" }}, {'empty' => { "\$ne" => 1 }})->fields($fields_ref)->sort({code=>1});
	my $count = $cursor->count();

	$langs{$l} = $count;
	$total += $count;

	print STDERR "lc: $lc - $count products\n";
	print STDERR "Write file: $www_root/data/$lang.$server_domain.products.csv\n";
	print STDERR "Write file: $www_root/data/$lang.$server_domain.products.rdf\n";

	open (my $OUT, ">:encoding(UTF-8)", "$www_root/data/$lang.$server_domain.products.csv");
	open (my $RDF, ">:encoding(UTF-8)", "$www_root/data/$lang.$server_domain.products.rdf");
	open (my $BAD, ">:encoding(UTF-8)", "$www_root/data/$lang.$server_domain.products.bad-chars.log");


	# Headers

	# RDF header
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

	# CSV header
	my $csv = '';

	foreach my $field (@export_fields) {

		$csv .= $field . "\t";

		# Add "url" field right after "code" field
		if ($field eq 'code') {
			$csv .= "url\t";
		}

		# Add "created_datetime" and "last_modified_datetime" fields right after
		# "created_t" and "last_modified_t"
		if ($field =~ /_t$/) {
			$csv .= $` . "_datetime\t";
		}

		# If the field is a tag field, add a normalized version of this field ending
		# with _tag
		if (defined $tags_fields{$field}) {
			$csv .= $field . '_tags' . "\t";
		}

		# If the field is a taxonomy, add a localized version of this field ending
		# with the country code; example: allergens   allergens_fr
		if (defined $taxonomy_fields{$field}) {
			$csv .= $field . "_$lc" . "\t";
		}

		if ($field eq 'emb_codes') {
			$csv .= "first_packaging_code_geo\t";
		}

	}

	$csv .= "main_category\tmain_category_$lc\t";

	$csv .= "image_url\timage_small_url\t";
	$csv .= "image_ingredients_url\timage_ingredients_small_url\t";
	$csv .= "image_nutrition_url\timage_nutrition_small_url\t";



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
	my $ct = 0;

	while (my $product_ref = $cursor->next) {

		my $csv = '';
		my $url = "http://world-$lc.$server_domain" . product_url($product_ref);
		my $code = ($product_ref->{code} // '');

		$code eq '' and next;
		$code < 1 and next;

		$ct++;
		print "$ct \n" if ($ct % 1000 == 0); # print number of products each 1000

		foreach my $field (@export_fields) {

			my $field_value = ($product_ref->{$field} // "");
			$field_value = sanitize_field_content($field_value, $BAD, "$code barcode -> field $field:");

			# Add field value to CSV file
			$csv .= $field_value . "\t";

			# If current field is "code", add the product url after it; example:
			# 9542013592	http://world-fr.openfoodfacts.org/produit/0009542013592/gourmet-truffles-lindt
			if ($field eq 'code') {
				$csv .=  $url . "\t";
			}

			# If the field name ending with _t (ie a date in epoch format), add
			# a field in ISO 8601 date format; example:
			# created_t		created_datetime
			# 1489061370	2017-03-09T12:09:30Z
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
				# sanitize_field_content($field_value, $log_file, $log_msg);
				$geo = sanitize_field_content($geo, $BAD, "$code barcode -> field $field:");

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

		ProductOpener::Display::add_images_urls_to_product($product_ref);

		$csv .= ($product_ref->{image_url} // "") . "\t" . ($product_ref->{image_small_url} // "") . "\t";
		$csv .= ($product_ref->{image_ingredients_url} // "") . "\t" . ($product_ref->{image_ingredients_small_url} // "") . "\t";
		$csv .= ($product_ref->{image_nutrition_url} // "") . "\t" . ($product_ref->{image_nutrition_small_url} // "") . "\t";


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

				# Encode URI
				my $ing_encoded = URI::Escape::XS::encodeURIComponent($i->{id});
				$rdf .= "\t<food:containsIngredient>\n" .
						"\t\t<food:Ingredient>\n" .
						"\t\t\t<food:food rdf:resource=\"http://fr.$server_domain/ingredient/" . $ing_encoded . "\" />\n";
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
	close $BAD;

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

		# Encode URI
		$i = URI::Escape::XS::encodeURIComponent($i);

		print $RDF <<XML
<rdf:Description rdf:about="http://$lc.$server_domain/ingredient/$i" rdf:type="http://data.lirmm.fr/ontologies/food#Food">
	<food:name>$name</food:name>$sameas
</rdf:Description>

XML
;
	}

	print $RDF "</rdf:RDF>\n";

	close $RDF;

}


my $html = "<p>$total products:</p>\n";
foreach my $l (sort { $langs{$b} <=> $langs{$a}} keys %langs) {

	if ($langs{$l} > 0) {
		$lang = $l;
		$html .= "<p><a href=\"http://$lang.$server_domain/\">" . $Langs{$l} . "</a> - $langs{$l} " . lang("products") . "</p>\n";
	}

}
open (my $OUT, ">:encoding(UTF-8)", "$www_root/langs.html");
print $OUT $html;
close $OUT;

exit(0);
