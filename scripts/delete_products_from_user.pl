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

#GetOptions ("key=s"   => \$key,      # string
#			"fields=s" => \@fields_to_update,
#			"index" => \$index,
#			"pretend" => \$pretend,
#			"process-ingredients" => \$process_ingredients,
#			)
#  or die("Error in command line arguments:\n$\nusage");
 
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
	#die("Unknown fields, check for typos.");
}

if ((not $process_ingredients) and (scalar @fields_to_update == 0)) {
	#die("Missing fields to update:\n$\nusage");
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
	
	if ((defined $product_ref) and ($code ne '') and $product_ref->{creator} eq 'usda-ndb-import') {
	
		$lc = $product_ref->{lc};
	
		$product_ref->{deleted} = 'on';

	
	my $comment = "delete";
	store_product($product_ref, $comment);
		
		
		$n++;
	}

}
			
print "$n products updated (pretend: $pretend)\n";
			
exit(0);

