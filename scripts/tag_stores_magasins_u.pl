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

use strict;
use utf8;

binmode(STDOUT, ":encoding(UTF-8)");

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
use JSON::PP;
use Time::Local;
use Data::Dumper;

use Text::CSV;

my $csv = Text::CSV->new ( { binary => 1 , sep_char => ";" } )  # should set binary attribute.
                 or die "Cannot use CSV: ".Text::CSV->error_diag ();

$lc = "fr";

$User_id = 'magasins-u';

my $editor_user_id = 'magasins-u';

$User_id = $editor_user_id;
my $photo_user_id = $editor_user_id;
$editor_user_id = $editor_user_id;

not defined $photo_user_id and die;

my $csv_file = "/data/off/systemeu/SUYQD_DISPOMAG_08b.csv";


#my $csv_file = "/home/systemeu/SUYQD_AKENEO_PU_08b_diff.csv";



print "uploading csv_file: $csv_file\n";


my $i = 0;
my $j = 0;
my %codes = ();
my $current_code = undef;
my $previous_code = undef;
my $last_imgid = undef;

my $current_product_ref = undef;

my @param_sorted_langs = qw(fr);

my %global_params = (
	countries => "France",
	stores => "Magasins U",
);

$lc = 'fr';

my $comment = "Products sold in Magasins U";

my $time = time();

my $existing = 0;
my $new = 0;
my $differing = 0;
my %differing_fields = ();
my @edited = ();
my %edited = ();

my $testing = 0;
my $testing_allergens = 0;
# my $testing = 1;



print STDERR "tagging products\n";

open (my $io, '<:encoding(UTF-8)', $csv_file) or die("Could not open $csv_file: $!");
$csv->getline ($io);
$csv->column_names ($csv->getline ($io));



while (my $imported_product_ref = $csv->getline_hr ($io)) {
  	
			$i++;

			#print $json;
			
			my $modified = 0;
			
			my @modified_fields;
			my @images_ids;
			
			my $code = $imported_product_ref->{"EAN PRINCIPAL"};
			

			# next if $code ne "3256226790691";				
	
			if ($code eq '') {
				print STDERR "empty code\n";
				use Data::Dumper;
				print STDERR Dumper($imported_product_ref);
				print "EMPTY CODE\n";
				next;
			}			
	
			
		
			
			# next if ($code ne "3256220126366");
			
			# next if ($i < 2665);
			
			print "PRODUCT LINE NUMBER $i - CODE $code";
			
			my $product_ref = product_exists($code); # returns 0 if not
			
			if (not $product_ref) {
				print "- does not exist in OFF yet\n";
				next;								
			}
			else {
				print "- already exists in OFF\n";
				$existing++;
			}
	
			# First load the global params, then apply the product params on top
			my %params = %global_params;		
		
			# Create or update fields
			
			my @param_fields = ('stores', 'countries');
			
			foreach my $field (@param_fields) {
			

				
				if (defined $params{$field}) {				

				
					print STDERR "defined value for field $field : " . $params{$field} . "\n";
				
					# for tag fields, only add entries to it, do not remove other entries
					
					if (defined $tags_fields{$field}) {
					
						my $current_field = $product_ref->{$field};
	

						my %existing = ();
							if (defined $product_ref->{$field . "_tags"}) {
							foreach my $tagid (@{$product_ref->{$field . "_tags"}}) {
								$existing{$tagid} = 1;
							}
						}
						
						
						foreach my $tag (split(/,/, $params{$field})) {
		
							my $tagid;
							
							next if $tag =~ /^(\s|,|-|\%|;|_|°)*$/;
							
							$tag =~ s/^\s+//;
							$tag =~ s/\s+$//;

							if (defined $taxonomy_fields{$field}) {
								$tagid = get_taxonomyid(canonicalize_taxonomy_tag($params{lc}, $field, $tag));
							}
							else {
								$tagid = get_fileid($tag);
							}
							if (not exists $existing{$tagid}) {
								print "- adding $tagid to $field: $product_ref->{$field}\n";
								$product_ref->{$field} .= ", $tag";
							}
							else {
								#print "- $tagid already in $field\n";
							}
							
						}
						
						if ($product_ref->{$field} =~ /^, /) {
							$product_ref->{$field} = $';
						}	
						
						if (get_fileid($current_field) ne get_fileid($product_ref->{$field})) {
							print "changed value for product code: $code - field: $field = $product_ref->{$field} - old: $current_field\n";
							compute_field_tags($product_ref, $field);
							push @modified_fields, $field;
							$modified++;
						}
					
					
					}
		
				}
			}
			
			print STDERR "product code $code - number of modifications - $modified\n";
			if ($modified == 0) {
				print STDERR "skipping product code $code - no modifications\n";
				next;
			}	
				
			$User_id = $editor_user_id;
			
			if ($modified and (not $testing) and (not $testing_allergens)) {
			
				#print STDERR "Storing product code $code\n";
				#				use Data::Dumper;
				#print STDERR Dumper($product_ref);
				#exit;
				
				
				
				store_product($product_ref, "Editing product (import_systemeu.pl bulk import) - " . $comment );
				
				push @edited, $code;
				$edited{$code}++;
				
				$j++;
				#$j > 10 and last;
				#last;
			}
			
			#last;
		}  # if $file =~ json
			


print "$i products\n";
print "$new new products\n";
print "$existing existing products\n";
print "$differing differing values\n\n";

print ((scalar @edited) . " edited products\n");
print ((scalar keys %edited) . " editions\n");

foreach my $field (sort keys %differing_fields) {
	print "field $field - $differing_fields{$field} differing values\n";
}

