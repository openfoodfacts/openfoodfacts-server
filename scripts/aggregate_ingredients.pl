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
aggregate_ingredients.pl process lists of individual ingredients
created with extract_individual_ingredients.pl 

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

my $cursor = get_products_collection()->query($query_ref)->fields({ code => 1 });;
my $count = $cursor->count();

my $n = 0;
my $i = 0;

binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDIN, ":encoding(UTF-8)");

my %ingredient_ids = ();
	
print STDERR "$count products in the database\n";
	
while (<STDIN>) {

	# extract_individual_ingredients.pl:
	# print $code . "\t" . $complete . "\t" . $creator . "\t" . $lc . "\t" . $ingredient_ref->{id} . "\t" . $ingredient_ref->{text} . "\n";
	
	chomp();
	my ($code, $complete, $creator, $lc, $ingredient_id, $ingredient_text) = split(/\t/);

	$ingredient_id = $lc . ":" . $ingredient_id;
	
	# normalize the text
	if ($lc ne 'de') {
		$ingredient_text = lc($ingredient_text);
	}
	
	if (not defined $ingredient_ids{$ingredient_id}) {
		$ingredient_ids{$ingredient_id} = {n => 0};
		$n++;
	}
	if (not defined $ingredient_ids{$ingredient_id}{texts}{$ingredient_text}) {
		$ingredient_ids{$ingredient_id}{texts}{$ingredient_text} = 0;
	}	
	$ingredient_ids{$ingredient_id}{n}++;
	$ingredient_ids{$ingredient_id}{texts}{$ingredient_text}++;
	
	# if an entry has _allergen_ in it, also add a version without the underscores
	if ($ingredient_text =~ /_(.*)_/) {
		my $ingredient_text_without_allergens = $ingredient_text;
		$ingredient_text_without_allergens =~ s/_//g;
		$ingredient_ids{$ingredient_id}{texts}{$ingredient_text_without_allergens}++;
	}

	
	$i++;
	
}

foreach my $ingredient_id (sort {$ingredient_ids{$b}{n} <=> $ingredient_ids{$a}{n}} keys %ingredient_ids ) {

	my $lc;
	if ($ingredient_id =~ /^(.*):/) {
		$lc = $1;
	}

	if (0) {
		print $ingredient_id . "\t" . $ingredient_ids{$ingredient_id}{n};
		foreach my $ingredient_text (sort {$ingredient_ids{$ingredient_id}{texts}{$b} <=> $ingredient_ids{$ingredient_id}{texts}{$a} } keys %{$ingredient_ids{$ingredient_id}{texts}} ) {
			print "\t" . $ingredient_text . "\t" . $ingredient_ids{$ingredient_id}{texts}{$ingredient_text};
		}
		print "\n";
	}
	if (1) {
		my $first = 1;
		
		foreach my $ingredient_text (sort {$ingredient_ids{$ingredient_id}{texts}{$b} <=> $ingredient_ids{$ingredient_id}{texts}{$a} } keys %{$ingredient_ids{$ingredient_id}{texts}} ) {
			if ($first) {
				print "$lc:" . $ingredient_text . "\n";
				$first = 0;
			}
			else {
				if ($ingredient_text =~ /_(.*)_/) {
					# only add allergens if the frequency is high enough
					if ($ingredient_ids{$ingredient_id}{texts}{$ingredient_text} > $ingredient_ids{$ingredient_id}{n} / 10 ) {
						print "allergens:$lc:" . $ingredient_text . "\n";
					}
					last;
				}
			}
		}
		print "\n";	
	}
	
}
			
print STDERR "$i individual ingredients aggregated into $n unique ingredient ids\n";
			
exit(0);

