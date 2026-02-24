#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2023 Association Open Food Facts
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


use Modern::Perl '2017';
use utf8;

use CGI::Carp qw(fatalsToBrowser);

use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Texts qw/:all/;
use ProductOpener::Display qw/search_and_export_products/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Images qw/:all add_images_urls_to_product/;
use ProductOpener::Lang qw/$lc  %lang_lc/;
use ProductOpener::Mail qw/:all/;
use ProductOpener::Products qw/product_url/;
use ProductOpener::Food qw/%nutrients_tables/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::Data qw/get_products_collection/;
use ProductOpener::Text qw/xml_escape/;
use LWP::UserAgent;
use JSON::MaybeXS;
use Text::CSV;

# This script:
# - reads a list of countries and categories from foodture/FOODTURE_liste_extraction_OFF.csv
# - reads a list of most scanned products by country and category from foodture/ranked_products_202602231414.csv
# - for each product matching a country/category pair from the first list, we fetch its data from the OFF API (using LWP::UserAgent and caching in foodture/api_cache)
# - we then extract / process the needed data to output a new CSV file containing representative products
#
# Country,Segmentation OFF,code,product_name,lang,ingredients_text_lc,ingredients_text,image_url,image_ingredients_url,image_nutrition_url,image_packaging_url,
#
# In addition:
# The nested ingredients structure needs to be flattened and aggregated by ingredient id
# (percent of ingredient summed over all occurrences of the same ingredient in the ingredients tree)
#
# We output columns for the top 10 ingredients by quantity: ingredient_id_1, ingredient_percent_1, ingredient_id_2, ingredient_percent_2, etc.


# - reads a list of countries and categories from foodture/FOODTURE_liste_extraction_OFF.csv (tab separated, with header line)
# Action	Segmentation OFF
# Austria	Beverages and beverages preparations > Beverages > Waters > Spring waters > Mineral waters > Natural mineral waters
# Austria	Meals > Soups > Reheatable soups > Reheatable mixed vegetables soup
# Austria	Meals > Pizzas pies and quiches > Pizzas
# Austria	Beverages and beverages preparations > Beverages > Coffee drinks
# Austria	Meals > Meals with meat
# Austria	Meals > Pasta dishes > Stuffed pastas

# We need to taxonomize the country and the last category level

# --- begin FOODTURE extraction implementation ---

# caching directory for API responses
my $cache_dir = "foodture/api_cache";
mkdir $cache_dir unless -d $cache_dir;

# variables for API fetching
my $ua       = LWP::UserAgent->new(timeout=>20);
my $baseurl  = "https://world.openfoodfacts.org/api/v3.5/product/";
my %product_data;

# helper to flatten ingredients
sub collect_ingredients {
    my ($ingredient_ref, $map) = @_;
    return unless ref $ingredient_ref eq 'HASH';
    if (defined $ingredient_ref->{id}) {
        my $id  = $ingredient_ref->{id};
        my $pct = $ingredient_ref->{percent} // $ingredient_ref->{percent_estimate} // 0;
        $map->{$id} += $pct if $pct;
    }
    if (ref $ingredient_ref->{ingredients} eq 'ARRAY') {
        collect_ingredients($_, $map) for @{ $ingredient_ref->{ingredients} };
    }
}

# first pass: read ranked products and group by country/category tags
my $ranked_file = "foodture/ranked_products_202602231414.csv";
open my $RANK, '<:encoding(UTF-8)', $ranked_file or die "Cannot open $ranked_file: $!\n";
<$RANK>; # skip header
my $parser = Text::CSV->new({
    binary             => 1,
    auto_diag          => 1,
    allow_loose_quotes => 1,
    allow_loose_escapes=> 1,
});
my %ranked;    # $ranked{ctag}{cat_tag}{$code}=1
while (<$RANK>) {
    chomp;
    s/\r//g;            # drop stray CRs that confuse Text::CSV
    next if /^\s*$/;
    $parser->parse($_);
    my @cols = $parser->fields();
    my ($code, $name, $country, $category, $recent_scans) = @cols[0..4];
    next unless defined $code && $code ne '';
    my $country_tag = canonicalize_taxonomy_tag('en', 'countries', $country);
    my $category_tag = canonicalize_taxonomy_tag('en', 'categories', $category);
    $ranked{$country_tag}{$category_tag} = [$code, $recent_scans];
}
close $RANK;

# read target country/category pairs and output rows as we go
my $list_file = "foodture/FOODTURE_liste_extraction_OFF.csv";
open my $LIST, '<:encoding(UTF-8)', $list_file or die "Cannot open $list_file: $!\n";
<$LIST>; # skip header

# prepare output file
my $out_file = "foodture/representative_products.csv";
open my $OUT, '>:encoding(UTF-8)', $out_file or die "Cannot write $out_file: $!\n";
my $csv_out = Text::CSV->new({ binary=>1, eol=>"\n" })
    or die "Cannot create CSV writer: " . Text::CSV->error_diag();
my @hdr = ("Country","Segmentation OFF","off_country_id", "off_category_id", "recent_scans", "url", "api_url","code","product_name", "brands", "lang","ingredients_text_lc","ingredients_text",
           "image_url","image_ingredients_url","image_nutrition_url","image_packaging_url");
# packaging columns (first five components)
for my $j (1..5) {
    for my $f (qw(number_of_units shape material quantity_per_unit)) {
        push @hdr, "packaging_${j}_$f";
    }
}
for my $i (1..10) { push @hdr,"ingredient_id_$i","ingredient_percent_$i"; }
$csv_out->print($OUT, \@hdr);

# iterate through each country/category in list
my $n = 0;
while (<$LIST>) {
    chomp;
    s/\r//g;            # strip stray carriage returns
    next if /^	?$/;
    my ($country, $segmentation) = split /\t/, $_, 2;
    for ($country, $segmentation) { s/^\s+|\s+$//g if defined }
    my $country_tag = canonicalize_taxonomy_tag('en', 'countries', $country);
	# For testing skip if country is not en:france
	next unless $country_tag eq 'en:france';
    my $lastcat = '';
    if (defined $segmentation) {
        my @parts = split />/, $segmentation;
        $lastcat = pop @parts;
        $lastcat =~ s/^\s+|\s+$//g if defined $lastcat;
    }
    my $category_tag = canonicalize_taxonomy_tag('en', 'categories', $lastcat);

    # gather matching codes
	if (defined $ranked{$country_tag}{$category_tag}) {
   
		my ($code, $recent_scans) = @{$ranked{$country_tag}{$category_tag}};

		# ensure product data fetched
		unless (exists $product_data{$code}) {
			my $cache_file = "$cache_dir/$code.json";
			if (-e $cache_file) {
				open my $cf, '<:encoding(UTF-8)', $cache_file;
				local $/;
				my $json = <$cf>;
				close $cf;
				$product_data{$code} = decode_json($json);
			} else {
				my $resp = $ua->get($baseurl.$code);
				if ($resp->is_success) {
					my $data = decode_json($resp->decoded_content);
					$product_data{$code} = $data;
					open my $cf, '>:encoding(UTF-8)', $cache_file or warn "Cannot write cache $cache_file: $!\n";
					print $cf encode_json($data);
					close $cf;
				} else {
					warn "failed to fetch product $code: " . $resp->status_line . "\n";
					next;
				}
			}
		}

		my $url = product_url($code);
		my $api_url = $baseurl . $code;
		my $brands = $product_data{$code}{product}{brands} // '';
		my $prod = $product_data{$code}{product} // next;
		my $name = $prod->{product_name} // '';
		my $lang = $prod->{lang} // '';
		my $ingredients_txt = $prod->{ingredients_text} // '';
		my $ingredients_lc = lc $ingredients_txt;
		my $img_url = $prod->{image_url} // '';
		my $img_ing = $prod->{image_ingredients_url} // '';
		my $img_nut = $prod->{image_nutrition_url} // '';
		my $img_pack = $prod->{image_packaging_url} // '';
		my %ingredients;
		if (ref $prod->{ingredients} eq 'ARRAY') {
			collect_ingredients($_,\%ingredients) for @{ $prod->{ingredients} };
		}
		my @sorted = sort { $ingredients{$b} <=> $ingredients{$a} } keys %ingredients;
		my @row = ($country,$segmentation,$country_tag,$category_tag,$recent_scans, $url,$api_url,$code,$name,$brands,$lang,
					$ingredients_lc,$ingredients_txt,$img_url,$img_ing,
					$img_nut,$img_pack);
        # packaging values (five first elements)
        for my $j (1..5) {
            my $idx = $j - 1;
            for my $f (qw(number_of_units shape material quantity_per_unit)) {
                my $val = '';
                if (ref $prod->{packagings} eq 'ARRAY' && defined $prod->{packagings}[$idx]) {
                    $val = $prod->{packagings}[$idx]{$f} // '';
                }
                push @row, $val;
            }
        }
			push @row, $id, $pct;
		}
		$csv_out->print($OUT, \@row);
        
    } else {
        # output empty row for this pair
        $csv_out->print($OUT, [ ('') x scalar(@hdr) ]);
    }
	$n++;
}
close $LIST;
close $OUT;

exit 0;
