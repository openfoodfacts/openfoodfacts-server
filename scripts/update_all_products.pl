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

use Modern::Perl '2012';
use utf8;

my $usage = <<TXT
update_all_products.pl is a script that updates the latest version of products in the file system and on MongoDB.
It is used in particular to re-run tags generation when taxonomies have been updated.

Usage:

update_all_products.pl --key some_string_value --fields categories,labels --index

The key is used to keep track of which products have been updated. If there are many products and field to updates,
it is likely that the MongoDB cursor of products to be updated will expire, and the script will have to be re-run.

--process-ingredients	compute allergens, additives detection

--clean-ingredients	remove nutrition facts, conservation conditions etc.

--compute-nutrition-score	nutriscore

--compute-serving-size	compute serving size values

--check-quality	run quality checks

--compute-codes

--fix-serving-size-mg-to-ml

--index		specifies that the keywords used by the free text search function (name, brand etc.) need to be reindexed. -- TBD

--user		create a separate .sto file and log the change in the product history, with the corresponding user

--comment	comment for change in product history

--pretend	do not actually update products
TXT
;

use CGI::Carp qw(fatalsToBrowser);

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
use ProductOpener::SiteQuality qw/:all/;
use ProductOpener::Data qw/:all/;


use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;

use Getopt::Long;


my @fields_to_update = ();
my $key;
my $index = '';
my $pretend = '';
my $process_ingredients = '';
my $clean_ingredients = '';
my $compute_nutrition_score = '';
my $compute_serving_size = '';
my $compute_data_sources = '';
my $compute_nova = '';
my $check_quality = '';
my $compute_codes = '';
my $compute_carbon = '';
my $comment = '';
my $fix_serving_size_mg_to_ml = '';
my $query_ref = {};	# filters for mongodb query

GetOptions ("key=s"   => \$key,      # string
			"query=s%" => $query_ref,
			"fields=s" => \@fields_to_update,
			"index" => \$index,
			"pretend" => \$pretend,
			"clean-ingredients" => \$clean_ingredients,
			"process-ingredients" => \$process_ingredients,
			"compute-nutrition-score" => \$compute_nutrition_score,
			"compute-serving-size" => \$compute_serving_size,
			"compute-data-sources" => \$compute_data_sources,
			"compute-nova" => \$compute_nova,
			"compute-codes" => \$compute_codes,
			"compute-carbon" => \$compute_carbon,
			"check-quality" => \$check_quality,
			"fix-serving-size-mg-to-ml" => \$fix_serving_size_mg_to_ml,
			"user_id=s" => \$User_id,
			"comment=s" => \$comment,
			)
  or die("Error in command line arguments:\n$\nusage");
 
use Data::Dumper;

print Dumper(\@fields_to_update); 
 
@fields_to_update = split(/,/,join(',',@fields_to_update));

  
use Data::Dumper;

    # simple procedural interface
    print Dumper(\@fields_to_update);
	
	
print "Updating fields: " . join(", ", @fields_to_update) . "\n\n";

my $unknown_fields = 0;

foreach my $field (@fields_to_update) {
	if ( (not defined $tags_fields{$field}) and (not defined $taxonomy_fields{$field}) and (not defined $hierarchy_fields{$field}) ) {
		print "Unknown field: $field\n";
		$unknown_fields++;
	}
}

if ($unknown_fields > 0) {
	die("Unknown fields, check for typos.");
}

if ((not $process_ingredients) and (not $compute_nutrition_score) and (not $compute_nova) 
	and (not $clean_ingredients)
	and (not $compute_serving_size)
	and (not $compute_data_sources)
	and (not $compute_codes) and (not $compute_carbon) and (not $check_quality) and (scalar @fields_to_update == 0)) {
	die("Missing fields to update:\n$usage");
}  

# Make sure we have a user id and we will use a new .sto file for all edits that change values entered by users
if ((not defined $User_id) and (($fix_serving_size_mg_to_ml))) {
	die("Missing --user-id. We must have a user id and we will use a new .sto file for all edits that change values entered by users.\n");
}

# Get a list of all products not yet updated
# Use query filtes entered using --query categories_tags=en:plant-milks

if (defined $key) {
	$query_ref->{update_key} = { '$ne' => "$key" };
}
else {
	$key = "key_" . time();
}

#$query_ref->{code} = "3033490859206";
#$query_ref->{categories_tags} = "en:plant-milks";
#$query_ref->{quality_tags} = "ingredients-fr-includes-fr-nutrition-facts";

use boolean;
# $query_ref->{unknown_nutrients_tags} = { '$exists' => true,  '$ne' => [] };

print "Update key: $key\n\n";

my $cursor = get_products_collection()->query($query_ref)->fields({ code => 1 });;
$cursor->immortal(1);
my $count = $cursor->count();

my $n = 0;	# number of products updated
my $m = 0;	# number of products with a new version created
	
print STDERR "$count products to update\n";
	
while (my $product_ref = $cursor->next) {
	
	my $code = $product_ref->{code};
	my $path = product_path($code);
	
	# next if $code ne "7310865071804";
	
	print STDERR "updating product $code\n";
	
	$product_ref = retrieve_product($code);
	
	if ((defined $product_ref) and ($code ne '')) {
	
		$lc = $product_ref->{lc};
		
		my $product_values_changed = 0;
		
		# Fix products and record if we have changed them so that we can create a new product version and .sto file
		if ($fix_serving_size_mg_to_ml) {

			if ((defined $product_ref->{serving_size}) and ($product_ref->{serving_size} =~ /\d\s?mg\b/i)) {
				$product_ref->{serving_size} =~ s/(\d)\s?(mg)\b/$1 ml/i;
				ProductOpener::Food::compute_serving_size_data($product_ref);
				$product_values_changed = 1;
			}			
		}
		
		# Fix nutrient _label fields that were mistakenly set to 0
		# bug https://github.com/openfoodfacts/openfoodfacts-server/issues/772
		
		# 2019-05-10: done in production, commenting out
		#if (defined $product_ref->{nutriments}) {
		#	foreach my $key (%{$product_ref->{nutriments}}) {
		#		next if $key !~ /^(.*)_label$/;
		#		my $nid = $1;
		#		
		#		if ($product_ref->{nutriments}{$key} eq "0") {
		#			$product_ref->{nutriments}{$key} = ucfirst($nid);
		#		}
		#	}
		#}
	
		# Update all fields
		
		foreach my $field (@fields_to_update) {
		
			if (defined $product_ref->{$field}) {
			
				if ($field eq 'emb_codes') {
					$product_ref->{emb_codes} = normalize_packager_codes($product_ref->{emb_codes});						
				}
				
				# we do not know the language of the current value of $product_ref->{$field}
				# so regenerate it in the main language of the product
				my $value = display_tags_hierarchy_taxonomy($lc, $field, $product_ref->{$field . "_hierarchy"});
				# Remove tags
				$value =~ s/<(([^>]|\n)*)>//g;
				
				$product_ref->{$field} = $value;

				compute_field_tags($product_ref, $lc, $field);
			}
			else {
			}
		}

		if ($server_domain =~ /openfoodfacts/) {
				ProductOpener::Food::special_process_product($product_ref);
		}
		
		if ((defined $product_ref->{nutriments}{"carbon-footprint"}) and ($product_ref->{nutriments}{"carbon-footprint"} ne '')) {
			push @{$product_ref->{"labels_hierarchy" }}, "en:carbon-footprint";
			push @{$product_ref->{"labels_tags" }}, "en:carbon-footprint";
		}
	
		
		if ($clean_ingredients) {
			clean_ingredients_text($product_ref);
		}
	
		
		if ($process_ingredients) {
			# Ingredients classes
			extract_ingredients_from_text($product_ref);
			extract_ingredients_classes_from_text($product_ref);
			compute_nova_group($product_ref);
			compute_languages($product_ref); # need languages for allergens detection
			detect_allergens_from_text($product_ref);		
		}
		
		if ($compute_data_sources) {
			compute_data_sources($product_ref);
		}
		
		if ($compute_nova) {
		
			extract_ingredients_from_text($product_ref);
			compute_nova_group($product_ref);
		}

		if ($compute_nutrition_score) {
			compute_nutrition_score($product_ref);
			compute_nutrient_levels($product_ref);
		}
		
		if ($compute_codes) {
			compute_codes($product_ref);
		}
		
		if ($compute_carbon) {
			compute_carbon_footprint_from_ingredients($product_ref);
			compute_serving_size_data($product_ref);
			delete $product_ref->{environment_infocard};
			delete $product_ref->{environment_infocard_en};
			delete $product_ref->{environment_infocard_fr};		
		}
		
		if ($compute_serving_size) {
			ProductOpener::Food::compute_serving_size_data($product_ref);
		}

		if ($check_quality) {
			ProductOpener::SiteQuality::check_quality($product_ref);
		}
		
		if (not $pretend) {
			$product_ref->{update_key} = $key;
			
			# Create a new version of the product and create a new .sto file
			# Useful when we actually change a value entered by a user
			if ((defined $User_id) and ($User_id ne '') and ($product_values_changed)) {
				store_product($product_ref, "update_all_products.pl - " . $comment );
				$m++;
			}
			
			# Otherwise, we silently update the .sto file of the last version 
			else {
				
				# make sure nutrient values are numbers
				ProductOpener::Products::make_sure_numbers_are_stored_as_numbers($product_ref);
		
				store("$data_root/products/$path/product.sto", $product_ref);		

				# Make sure product code is saved as string and not a number
				# see bug #1077 - https://github.com/openfoodfacts/openfoodfacts-server/issues/1077
				# make sure that code is saved as a string, otherwise mongodb saves it as number, and leading 0s are removed
				$product_ref->{code} = $product_ref->{code} . '';
				get_products_collection()->save($product_ref);
			}
		}
		
		$n++;
	}

}
			
print "$n products updated (pretend: $pretend) - $m new versions created\n";
			
exit(0);

