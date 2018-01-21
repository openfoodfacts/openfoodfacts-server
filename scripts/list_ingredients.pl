#!/usr/bin/perl

use Modern::Perl '2012';
use utf8;

my $usage = <<TXT
list_ingredients.pl extract ingredients lists of all product and output them to STDOUT.
The lists can then be further processed to create dictionaries for OCR, spell checkers etc.

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

#use Getopt::Long;
#
#my @fields_to_update = ();
#my $key;
#my $index = '';
#my $pretend = '';
#my $process_ingredients = '';
#my $compute_nutrition_score = '';
#my $check_quality = '';
#
#GetOptions ("key=s"   => \$key,      # string
#			"fields=s" => \@fields_to_update,
#			"index" => \$index,
#			"pretend" => \$pretend,
#			"process-ingredients" => \$process_ingredients,
#			"compute-nutrition-score" => \$compute_nutrition_score,
#			"check-quality" => \$check_quality,
#			)
# or die("Error in command line arguments:\n$\nusage");
 
my $query_ref = {};

my $cursor = $products_collection->query($query_ref)->fields({ code => 1 });;
my $count = $cursor->count();

my $n = 0;

binmode(STDOUT, ":utf8");
	
print STDERR "$count products in the database\n";
	
while (my $product_ref = $cursor->next) {
	
	my $code = $product_ref->{code};
	my $path = product_path($code);
		
	print STDERR "product $code\n";
	
	$product_ref = retrieve_product($code);
	
	if ((defined $product_ref) and ($code ne '')) {
	
		if (defined $product_ref->{languages_codes}) {
		
			foreach my $lc (keys %{$product_ref->{languages_codes}}) {
			
				if ((defined $product_ref->{"ingredients_text_$lc"}) and ($product_ref->{"ingredients_text_$lc"} !~ /^\s*$/)) {
				
					print $code . "\t" . $product_ref->{complete} . "\t" . $product_ref->{creator} . "\t" . $lc . "\t" . $product_ref->{"ingredients_text_$lc"} . "\n";
				}
			
			}
		
		}

		
		
		$n++;
	}

}
			
print STDERR "ingredients extracted from $n products\n";
			
exit(0);

