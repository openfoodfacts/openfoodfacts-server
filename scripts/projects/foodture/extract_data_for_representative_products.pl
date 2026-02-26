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

# caching directory for API responses
my $cache_dir = "foodture/api_cache";
mkdir $cache_dir unless -d $cache_dir;

# variables for API fetching
my $ua = LWP::UserAgent->new(timeout => 20);
my $baseurl = "https://world.openfoodfacts.org/api/v3.5/product/";
my %product_data;

# helper to flatten ingredients
sub collect_ingredients {
	my ($ingredient_ref, $map) = @_;
	return unless ref $ingredient_ref eq 'HASH';
	if (defined $ingredient_ref->{id}) {
		my $id = $ingredient_ref->{id};
		my $pct = $ingredient_ref->{percent} // $ingredient_ref->{percent_estimate} // 0;
		$map->{$id} += $pct if $pct;
	}
	if (ref $ingredient_ref->{ingredients} eq 'ARRAY') {
		collect_ingredients($_, $map) for @{$ingredient_ref->{ingredients}};
	}
}

# first pass: read ranked products and group by country/category tags
my $ranked_file = "foodture/ranked_products_202602231414.csv";
open my $RANK, '<:encoding(UTF-8)', $ranked_file or die "Cannot open $ranked_file: $!\n";
<$RANK>;    # skip header
my $parser = Text::CSV->new(
	{
		binary => 1,
		auto_diag => 1,
		allow_loose_quotes => 1,
		allow_loose_escapes => 1,
	}
);
my %ranked;    # $ranked{ctag}{cat_tag}{$code}=1
while (<$RANK>) {
	chomp;
	s/\r//g;    # drop stray CRs that confuse Text::CSV
	next if /^\s*$/;
	$parser->parse($_);
	my @cols = $parser->fields();
	my ($code, $name, $country, $category, $recent_scans) = @cols[0 .. 4];
	next unless defined $code && $code ne '';
	my $country_tag = canonicalize_taxonomy_tag('en', 'countries', $country);
	my $category_tag = canonicalize_taxonomy_tag('en', 'categories', $category);
	$ranked{$country_tag}{$category_tag} = [$code, $recent_scans];
}
close $RANK;

# read target country/category pairs and output rows as we go
my $list_file = "foodture/FOODTURE_liste_extraction_OFF.csv";
open my $LIST, '<:encoding(UTF-8)', $list_file or die "Cannot open $list_file: $!\n";
<$LIST>;    # skip header

# prepare output file
my $out_file = "foodture/representative_products.csv";
open my $OUT, '>:encoding(UTF-8)', $out_file or die "Cannot write $out_file: $!\n";
my $csv_out = Text::CSV->new({binary => 1, eol => "\n"})
	or die "Cannot create CSV writer: " . Text::CSV->error_diag();
my @hdr = (
	"Country", "Segmentation OFF", "off_country_id", "off_category_id",
	"category_exists_in_taxonomy", "recent_scans", "url", "api_url",
	"code", "product_name", "brands", "lang",
	"ingredients_text_lc", "ingredients_text", "image_url", "image_ingredients_url",
	"image_nutrition_url", "image_packaging_url"
);

# ingredient columns (top 10 ingredients by quantity)
for my $i (1 .. 10) {push @hdr, "ingredient_id_$i", "ingredient_percent_$i";}

# packaging columns (first five components)
for my $j (1 .. 5) {
	for my $f (qw(number_of_units shape material quantity_per_unit)) {
		push @hdr, "packaging_${j}_$f";
	}
}

$csv_out->print($OUT, \@hdr);

# iterate through each country/category in list
my $n = 0;
while (<$LIST>) {
	chomp;
	my ($country, $segmentation) = split /\t/, $_, 2;

	# Skip hidden lines without segmentation
	# next if (not defined $segmentation) or ($segmentation eq '') or ($segmentation =~ /N\/D/i);

	my $country_tag = canonicalize_taxonomy_tag('en', 'countries', $country);
	# For testing skip if country is not en:france
	next unless $country_tag eq 'en:france';
	my $last_category = $segmentation;
	$last_category =~ s/.*>//;
	my $exists_in_taxonomy;
	my $category_tag = canonicalize_taxonomy_tag('en', 'categories', $last_category, \$exists_in_taxonomy);

	print STDERR
		"Processing $country / $last_category ($country_tag / $category_tag (known: $exists_in_taxonomy))...\n";

	# find the matching product
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
			}
			else {
				my $resp = $ua->get($baseurl . $code);
				if ($resp->is_success) {
					my $data = decode_json($resp->decoded_content);
					$product_data{$code} = $data;
					open my $cf, '>:encoding(UTF-8)', $cache_file or warn "Cannot write cache $cache_file: $!\n";
					print $cf encode_json($data);
					close $cf;
				}
				else {
					warn "failed to fetch product $code: " . $resp->status_line . "\n";
					next;
				}
			}
		}

		my $product_ref = $product_data{$code}{product} // next;

		my $url = "https://world.openfoodfacts.org" . product_url($code);
		my $api_url = $baseurl . $code;
		my $brands = $product_ref->{brands} // '';

		my $name = $product_ref->{product_name} // '';
		my $lang = $product_ref->{lang} // '';
		my $ingredients_txt = $product_ref->{ingredients_text} // '';
		my $ingredients_lc = lc $ingredients_txt;
		my $img_url = $product_ref->{image_url} // '';
		my $img_ing = $product_ref->{image_ingredients_url} // '';
		my $img_nut = $product_ref->{image_nutrition_url} // '';
		my $img_pack = $product_ref->{image_packaging_url} // '';

		my @row = (
			$country, $segmentation, $country_tag, $category_tag,
			$exists_in_taxonomy || 0, $recent_scans, $url, $api_url,
			$code, $name, $brands, $lang,
			$ingredients_lc, $ingredients_txt, $img_url, $img_ing,
			$img_nut, $img_pack
		);

		# top 10 ingredients by quantity

		my %ingredients;
		if (ref $product_ref->{ingredients} eq 'ARRAY') {
			collect_ingredients($_, \%ingredients) for @{$product_ref->{ingredients}};
		}
		my @sorted = sort {$ingredients{$b} <=> $ingredients{$a}} keys %ingredients;

		for my $i (1 .. 10) {
			my $idx = $i - 1;
			my $id = $sorted[$idx] // '';
			my $pct = defined $id ? $ingredients{$id} : '';
			push @row, $id, $pct;
		}

		# packaging values (five first elements)
		for my $j (1 .. 5) {
			my $idx = $j - 1;
			for my $f (qw(number_of_units shape material quantity_per_unit)) {
				my $val = '';
				if (ref $product_ref->{packagings} eq 'ARRAY' && defined $product_ref->{packagings}[$idx]) {
					$val = $product_ref->{packagings}[$idx]{$f} // '';
					if (ref($val) eq 'HASH') {
						$val = $val->{id} // '';
					}
				}
				push @row, $val;
			}
		}

		$csv_out->print($OUT, \@row);

	}
	else {
		# no product matched this country/category – output identifiers anyway
		my @row = ($country, $segmentation, $country_tag, $category_tag);
		push @row, ('') x (scalar(@hdr) - scalar(@row));
		$csv_out->print($OUT, \@row);
	}
	$n++;
	$n > 200 and last;    # for testing, limit to 100 lines
}
close $LIST;
close $OUT;

exit 0;
