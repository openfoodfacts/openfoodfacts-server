#!/usr/bin/perl

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

--compute-nutrition-score	nutriscore

--check-quality	run quality checks

--index		specifies that the keywords used by the free text search function (name, brand etc.) need to be reindexed. -- TBD

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


use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON;

use Getopt::Long;


my @fields_to_update = ();
my $key;
my $index = '';
my $pretend = '';
my $process_ingredients = '';
my $compute_nutrition_score = '';
my $check_quality = '';

GetOptions ("key=s"   => \$key,      # string
			"fields=s" => \@fields_to_update,
			"index" => \$index,
			"pretend" => \$pretend,
			"process-ingredients" => \$process_ingredients,
			"compute-nutrition-score" => \$compute_nutrition_score,
			"check-quality" => \$check_quality,
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

if ((not $process_ingredients) and (not $compute_nutrition_score) and (not $check_quality) and (scalar @fields_to_update == 0)) {
	die("Missing fields to update:\n$\nusage");
}  

# Get a list of all products not yet updated

my $query_ref = {};
if (defined $key) {
	$query_ref = { update_key => { '$ne' => "$key" } };
}
else {
	$key = "key_" . time();
}

print "Update key: $key\n\n";

my $cursor = $products_collection->query($query_ref)->fields({ code => 1 });;
my $count = $cursor->count();

my $n = 0;
	
print STDERR "$count products to update\n";
	
while (my $product_ref = $cursor->next) {
	
	my $code = $product_ref->{code};
	my $path = product_path($code);
	
	#next if $code ne "9555118659523";
	
	print STDERR "updating product $code\n";
	
	$product_ref = retrieve_product($code);
	
	if ((defined $product_ref) and ($code ne '')) {
	
		$lc = $product_ref->{lc};
	
		# Update all fields
		
		foreach my $field (@fields_to_update) {
		
			if (defined $product_ref->{$field}) {
			
				if ($field eq 'emb_codes') {
					$product_ref->{emb_codes} = normalize_packager_codes($product_ref->{emb_codes});						
				}

				compute_field_tags($product_ref, $field);
			}
			else {
			}
		}
		
		if ((defined $product_ref->{nutriments}{"carbon-footprint"}) and ($product_ref->{nutriments}{"carbon-footprint"} ne '')) {
			push @{$product_ref->{"labels_hierarchy" }}, "en:carbon-footprint";
			push @{$product_ref->{"labels_tags" }}, "en:carbon-footprint";
		}
		
		
		if ($process_ingredients) {
			# Ingredients classes
			extract_ingredients_from_text($product_ref);
			extract_ingredients_classes_from_text($product_ref);

			compute_languages($product_ref); # need languages for allergens detection
			detect_allergens_from_text($product_ref);		
		}

		if ($compute_nutrition_score) {
			compute_nutrition_score($product_ref);
		}
		
		if ($server_domain =~ /openfoodfacts/) {
			ProductOpener::Food::special_process_product($product_ref);
		}		
		
		if ($check_quality) {
			ProductOpener::SiteQuality::check_quality($product_ref);
		}
		
		if (not $pretend) {
			$product_ref->{update_key} = $key;
			store("$data_root/products/$path/product.sto", $product_ref);		
			$products_collection->save($product_ref);		
		}
		
		
		$n++;
	}

}
			
print "$n products updated (pretend: $pretend)\n";
			
exit(0);

