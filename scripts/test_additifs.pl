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


# Get a list of all products

my $class = 'additives';

open (my $OUT, q{>}, "$www_root/images/$class.html");

my $cursor = get_products_collection()->query({})->fields({ code => 1 })->sort({code =>1});
my $count = $cursor->count();

		my %plus = ();
		my %minus = ();
	
	print STDERR "$count products to update\n";
	
	while (my $product_ref = $cursor->next) {
        
		
		my $code = $product_ref->{code};
		my $path = product_path($code);
		
		#next if $code ne '3329770041684';
		
		#print "testing product $code\n";
		
		$product_ref = retrieve_product($code);
		my $class = 'additives';
		defined $product_ref->{$class . '_tags'} or	$product_ref->{$class . '_tags'} = [];		
		
		my @old_r = @{$product_ref->{$class . '_tags'}};
		my @old = @old_r;

		# Update
		extract_ingredients_classes_from_text($product_ref);
		
		my @new = @{$product_ref->{$class . '_tags'}};
		my %old = {};
		my %new = {};
		my %all = {};
		foreach my $old (@old) {
				$all{$old}--;
				$old{$old} = 1;
		}
		foreach my $new (@new) {
			$all{$new}++;
			$new{$new}++;
		}
		
		my $change = '';
		my $change_html = '';
		

		
		foreach my $id (@old) {
			if (not $new{$id}) {
				$change .= "($id) ";
				$change_html .= "<span style=\"color:#a00\">($id)</span> ";
				$minus{$id}++;
			}
		}
		
		foreach my $id (@new) {
			if (not $old{$id}) {
				$change .= "+$id ";
				$change_html .= "<span style=\"color:#0a0\">+$id</span> ";
				$plus{$id}++;
			}
		}		
		
		if ($change ne '') {
			print "change for $code: $change\n";
		}

		# Store
		
		next if $path =~ /invalid/;

		if (-e "$data_root/products/$path/product.sto") {
			#store("$data_root/products/$path/product.sto", $product_ref);		
			#get_products_collection()->save($product_ref);
		
			# print $OUT "<a href=\"" . product_url($product_ref) . "\">$product_ref->{code} - $product_ref->{name}</a> : " . join (" ", sort @{$product_ref->{$class . '_tags'}}) . "<br />\n";
			if ($change ne '') {
				print $OUT "<a href=\"" . product_url($product_ref) . "\">$product_ref->{code} - $product_ref->{product_name}</a> : " . $change_html . "<br />\n";
			}
		}
	}
	
	
print $OUT "<br><br><br>Additifs les plus enlevés :</br>";

foreach my $id (sort { $minus{$b} <=> $minus{$a} } keys %minus) {
	print $OUT "<span style=\"color:#a00\">($id)</span> : $minus{$id}<br/>\n";
}	

print $OUT "<br><br><br>Additifs les plus ajoutés :</br>";

foreach my $id (sort { $plus{$b} <=> $plus{$a} } keys %plus) {
	print $OUT "<span style=\"color:#0a0\">+$id</span> : $plus{$id}<br/>\n";
}	
	
	
close $OUT;	

exit(0);

