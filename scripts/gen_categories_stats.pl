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
use ProductOpener::Data qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;

my $min_products = 10;


my %categories = ();


foreach my $l (values %lang_lc) {

	$lc = $l;
	$lang = $l;
	
	print STDERR "generating categories_stats for $lc";
	my $tags_count_ref = retrieve("$data_root/index/tags_count.$lc.sto");


	foreach my $tagid (keys %{$tags_count_ref->{categories}}) {

		print STDERR "tags_count for category $tagid: $tags_count_ref->{categories}{$tagid}\n";


		next if $tags_count_ref->{categories}{$tagid} <  $min_products;
		
		print STDERR "Generating stats for category $tagid\n";
		
		# Get all products
		
		my $cursor = get_products_collection()->query({lc=>$lc, categories_tags => $tagid})->fields({nutriments=>1});
		my $count = $cursor->count();
		
		# Compute mean, standard deviation etc.
		
		my $n = 0;
		my $nn = 0;
		my %nutriments = ();

		while (my $product_ref = $cursor->next) {
		
			next if (not defined $product_ref->{nutriments});
			next if (not defined $product_ref->{nutriments}{energy});
			next if (not defined $product_ref->{nutriments}{proteins});
			next if (not defined $product_ref->{nutriments}{carbohydrates});
			next if (not defined $product_ref->{nutriments}{fat});

			$n++;
			
			foreach my $nid (keys %{$product_ref->{nutriments}}) {
				next if $nid =~ /_/;
				next if ($product_ref->{nutriments}{$nid} eq '');
				
				$product_ref->{nutriments}{$nid} = unit_to_g($product_ref->{nutriments}{$nid}, 'g');
				
				if (not defined $nutriments{"${nid}_n"}) {
					$nutriments{"${nid}_n"} = 0;
					$nutriments{"${nid}_s"} = 0;
					$nutriments{"${nid}_array"} = [];
					$nn++;
				}
				
				$nutriments{"${nid}_n"}++;
				$nutriments{"${nid}_s"} += $product_ref->{nutriments}{$nid . "_100g"};
				push @{$nutriments{"${nid}_array"}}, $product_ref->{nutriments}{$nid . "_100g"};
						
			}
		
		}
		
		
		
		if ($n > $min_products) {
		
		$categories{$tagid} = {stats => 1, nutriments => {}, count => $count, n => $n, id=> $tagid};

		
		foreach my $nid (keys %nutriments) {
			next if $nid !~ /_n$/;
			$nid = $`;
			
			next if ($nutriments{"${nid}_n"} < $min_products);
			
			$nutriments{"${nid}_mean"} = $nutriments{"${nid}_s"} / $nutriments{"${nid}_n"};
			
			my $std = 0;
			foreach my $value (@{$nutriments{"${nid}_array"}}) {
				$std += ($value - $nutriments{"${nid}_mean"}) * ($value - $nutriments{"${nid}_mean"});
			}
			$std = sqrt($std / $nutriments{"${nid}_n"});
			
			$nutriments{"${nid}_std"} = $std;
			
			my @values = sort { $a <=> $b } @{$nutriments{"${nid}_array"}};
			
			$categories{$tagid}{nutriments}{"${nid}_n"} = $nutriments{"${nid}_n"};
			$categories{$tagid}{nutriments}{"$nid"} = $nutriments{"${nid}_mean"};
			$categories{$tagid}{nutriments}{"${nid}_100g"} = sprintf("%.2e", $nutriments{"${nid}_mean"}) + 0.0;
			$categories{$tagid}{nutriments}{"${nid}_mean"} = $nutriments{"${nid}_mean"};
			$categories{$tagid}{nutriments}{"${nid}_std"} =  sprintf("%.2e", $nutriments{"${nid}_std"}) + 0.0;

			if ($nid eq 'energy') {
				$categories{$tagid}{nutriments}{"${nid}_100g"} = int ($categories{$tagid}{nutriments}{"${nid}_100g"} + 0.5);
				$categories{$tagid}{nutriments}{"${nid}_std"} = int ($categories{$tagid}{nutriments}{"${nid}_std"} + 0.5);
			}				
			
			$categories{$tagid}{nutriments}{"${nid}_min"} = $values[0];
			$categories{$tagid}{nutriments}{"${nid}_max"} = $values[$nutriments{"${nid}_n"} - 1];
			#$categories{$tagid}{nutriments}{"${nid}_5"} = $nutriments{"${nid}_array"}[int ( ($nutriments{"${nid}_n"} - 1) * 0.05) ];
			#$categories{$tagid}{nutriments}{"${nid}_95"} = $nutriments{"${nid}_array"}[int ( ($nutriments{"${nid}_n"}) * 0.95) ];
			$categories{$tagid}{nutriments}{"${nid}_10"} = $values[int ( ($nutriments{"${nid}_n"} - 1) * 0.10) ];
			$categories{$tagid}{nutriments}{"${nid}_90"} = $values[int ( ($nutriments{"${nid}_n"}) * 0.90) ];
			$categories{$tagid}{nutriments}{"${nid}_50"} = $values[int ( ($nutriments{"${nid}_n"}) * 0.50) ];
			
			print STDERR "-> lc: lc -category $tagid - count: $count - n: nutriments: " . $nn . "$n \n";
			print STDERR "values for category $tagid: " . join(", ", @values) . "\n";
			print "tagid: $tagid - nid: $nid - 100g: " .  $categories{$tagid}{nutriments}{"${nid}_100g"}  . " min: " . $categories{$tagid}{nutriments}{"${nid}_min"} . " - max: " . $categories{$tagid}{nutriments}{"${nid}_max"} . 
				"mean: " . $categories{$tagid}{nutriments}{"${nid}_mean"} . " - median: " . $categories{$tagid}{nutriments}{"${nid}_50"} . "\n";
			
		}
		
		}
		
	}

	store("$data_root/index/categories_nutriments.$lc.sto", \%categories);
}
	
	
exit(0);

