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


use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;


# Load csv file

my $code_field = get_fileid("EAN");

my %products = ();

open (my $IN, "<:encoding(UTF-8)", "Offre_cible_ecommerce_25032016.csv") or die;

my $titles = <$IN>;
my @titles;
@titles = split(/\t/, $titles);

my @cols = ();
my %title_to_col = ();

foreach (my $i = 0; $i <= $#titles; $i++) {
	my $title = $titles[$i];

	$title =~ s/^"//;
	$title =~ s/"$//;
	$title =~ s/\s+$//;
	
	my $id = $title;

	if ($id !~ /_/) {
			$id = get_fileid($id);
	}

	$cols[$i] = $id;
	$title_to_col{$id} = $i;			
}
		

my %groups = ();

my $age_n = 0;
my $age_total = 0;


open (my $OUT,  ">:encoding(UTF-8)", "franprix_produits.csv");


print $OUT "Univers\tSous-groupe\tEAN\tLibellé\tMarque\tOFF\t\Complet\n";


open (my $OUT2,  ">:encoding(UTF-8)", "franprix_marques.csv");


print $OUT2 "Univers\tSous-groupe\tEAN\tLibellé\tMarque\tMarque OFF\t\URL\n";


open (my $OUT3,  ">:encoding(UTF-8)", "franprix_descriptions.csv");
print $OUT3 "EAN\tLibellé\tDescription produit\tPrésentation du produit\n";

my $lang = 'fr';
my $lc = 'fr';


while (<$IN>) {
	my $row = $_;
	$row =~ s/(\r|\n)*$//g;
	chomp($row);
	my @row;

	@row = split(/\t/, $row, -1);

	my $code = $row[$title_to_col{$code_field}];
	$products{$code} = {};
	
		my $univers = $row[$title_to_col{"univers"}];
		my $sous_groupe = $row[$title_to_col{"sous-groupe"}];
		my $libelle = $row[$title_to_col{"libelle"}];

		next if $univers eq "DPH";		
	
	foreach (my $i = 0; $i <= $#row; $i++) {
	


		next if $univers eq "DPH";
	
		$products{$code}{$cols[$i]} = $row[$i];
	
		$groups{$univers}{$code} = 1;
		$groups{$univers . " - " . $sous_groupe}{$code} = 1;
		$groups{"TOTAL"}{$code} = 1;		
	}
	
		my $franprix_marque =  $row[$title_to_col{"marque"}];
		my $franprix_marque_id = get_fileid($franprix_marque);
	
		my $product_ref = retrieve_product($code);
		
		my $p = $row . "\t";
		
		if (not defined $product_ref) {
			print "product code $code not found\n";
			$p .= "\t\n";
		}
		else {
		
			$products{$code}{off} = $product_ref;
			if ((exists $product_ref->{last_image_t}) and ($product_ref->{last_image_t} > 0)) {
				$age_n++;
				$age_total +=  (time() - $product_ref->{last_image_t}) / 86400;
			}
			$p .= "1\t";
			if ($products{$code}{off}{complete}) {
				$p .= "1";
			}
			$p .= "\n";
			
			my $off_brands = $products{$code}{off}{brands};
			my $off_brands_id = get_fileid($off_brands);
			
			if (($off_brands_id ne "") and ($off_brands_id !~ /$franprix_marque_id/)) {
				print $OUT2 $row . "\t" . $off_brands . "\t" . "https://world-fr.openfoodfacts.org/produit/$code\n";
			}
			
			my $description = product_name_brand_quantity($product_ref);
			
			my $presentation = <<HTML
$product_ref->{product_name}

$product_ref->{generic_name}

Marques : $product_ref->{brands}

Quantité : $product_ref->{quantity}

Ingrédients :

$product_ref->{ingredients_text_with_allergens}

HTML
;

		$presentation =~ s/Ingrédients :\n\n\n\n//;
		$presentation =~ s/Marques :\n\n//;
		$presentation =~ s/<span class="allergen">/<b>/g;
		$presentation =~ s/<\/span>/<\/b>/g;
		

		my $nutrition = "";
		
# $value = sprintf("%.2e", g_to_unit($comparison_ref->{nutriments}{$nid . "_100g"}, $unit)) + 0.0;		

		my @nids = @{$nutriments_tables{europe}};
		
		foreach my $nid (@nids) {
		
			my $col = "100g";
			
		my $unit = 'g';

		if ((exists $Nutriments{$nid}) and (exists $Nutriments{$nid}{unit})) {
			$unit = $Nutriments{$nid}{unit};

		}
		elsif ((not exists $Nutriments{$nid}) and (defined $product_ref->{nutriments}{$nid . "_unit"})) {
			$unit = $product_ref->{nutriments}{$nid . "_unit"};
		}
			
		my $values = '';
		
		my $values2 = '';
		
		my $col_class = '';
		
		if ((defined $product_ref->{nutriments}{$nid . "_$col"})) {
			
				# this is the actual value on the package, not a computed average. do not try to round to 2 decimals.
				my $value = g_to_unit($product_ref->{nutriments}{$nid . "_$col"}, $unit);
			
				# too small values are converted to e notation: 7.18e-05
				if (($value . ' ') =~ /e/) {
					# use %f (outputs extras 0 in the general case)
					$value = sprintf("%f", g_to_unit($product_ref->{nutriments}{$nid . "_$col"}, $unit));
				}
				
				my $value_unit = "$value $unit";
				
				if (defined $product_ref->{nutriments}{$nid . "_modifier"}) {
					$value_unit = $product_ref->{nutriments}{$nid . "_modifier"} . " " . $value_unit;
				}
				
				if ((not defined $product_ref->{nutriments}{$nid . "_$col"}) or ($product_ref->{nutriments}{$nid . "_$col"} eq '')) {
					$value_unit = '?';
				}
				elsif ($nid =~ /^energy/) {
					$value_unit .= "<br/>(" . g_to_unit($product_ref->{nutriments}{$nid . "_$col"}, 'kcal') . ' kcal)';
				}
				elsif ($nid eq 'sodium') {
					my $salt = $product_ref->{nutriments}{$nid . "_$col"} * 2.54;
					if (exists $product_ref->{nutriments}{"salt" . "_$col"}) {
						$salt = $product_ref->{nutriments}{"salt" . "_$col"};
					}
					$salt = sprintf("%.2e", g_to_unit($salt, $unit)) + 0.0;
					my $property = '';
					if ($col eq '100g') {
						$property = "property=\"food:saltEquivalentPer100g\" content=\"$salt\"";
					}
					$values2 .= "<td class=\"nutriment_value${col_class}\" $property>" . $salt . " " . $unit . "</td>";
					next;
				}
				elsif ($nid eq 'salt') {
					my $sodium = $product_ref->{nutriments}{$nid . "_$col"} / 2.54;
					if (exists $product_ref->{nutriments}{"sodium". "_$col"}) {
						$sodium = $product_ref->{nutriments}{"sodium". "_$col"};
					}
					my $sodium = sprintf("%.2e", g_to_unit($sodium, $unit)) + 0.0;
					my $property = '';
					if ($col eq '100g') {
						$property = "property=\"food:sodiumEquivalentPer100g\" content=\"$sodium\"";
					}
					$values2 .=  "\n$Nutriments{$nid}{$lang}" . $sodium . " " . $unit;
				}				
			
				$nutrition .= "$Nutriments{$nid}{$lang} : $value $unit\n";
		}
		}

		if ($nutrition ne "") {
			$presentation .= "Informations nutritionelles :\n\n" . $nutrition;
		}
		
		$presentation =~ s/\r//g;
		
		$presentation =~ s/\n(\n+)/\n\n/isg;
		$presentation =~ s/\n/<br\/>/g;
			
			print $OUT3 "$code\t$libelle\t$description\t$presentation\n";
		}	
		
		print $OUT $p;
}			

		


close($OUT);

close($OUT2);

open ($OUT,  ">:encoding(UTF-8)", "franprix.csv");

print $OUT "Univers - Sous-groupe\tProduits\tProduits dans OFF\tProduits dans OFF %\tProduits manquants dans OFF\tProduits complets dans OFF\tProduits complets dans OFF %\n";

foreach my $group (sort keys %groups) {

	my $products = 0;
	my $off = 0;
	my $complete = 0;
	
	foreach my $code (keys %{$groups{$group}}) {
	
		$products++;
		
		if (exists $products{$code}{off}) {
			$off++;
			
			if ($products{$code}{off}{complete}) {
				$complete++;
			}
		}
	}

	# print $group . "\t" . $products . " produits, $off dans OFF (" . sprintf("%d", 100 * $off / $products) . "%), $complete complets dans OFF (" . sprintf("%d", 100 * $complete / $products) . "%) \n";
	
	print $OUT $group . "\t" . $products . "\t$off\t" . sprintf("%d", 100 * $off / $products) . "" . "\t" . ($products - $off) . "\t" . $complete . "\t" . sprintf("%d", 100 * $complete / $products) . "\n";
	
	
}

close ($OUT);


print "age_n : $age_n  age_average : " . ($age_total / $age_n) . "\n";

exit(0);

