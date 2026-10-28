#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2026 Association Open Food Facts
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

use ProductOpener::PerlStandards;

use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Store qw/retrieve_object/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Products qw/product_path_from_id/;
use JSON::MaybeXS;
use Text::CSV;
use Getopt::Long;

# This script selects the most scanned product for each country / category, for the FOODTURE countries.
# It replaces the off-query SQL that produced projects/foodture/ranked_products_202602231414.csv:
# - products are read from the MongoDB JSONL dump (e.g. openfoodfacts-products.jsonl.gz)
# - only complete products are kept (photos uploaded, ingredients and nutrition facts completed)
# - categories are recomputed with the current taxonomy from the input tags of all sources (tags_sources),
# or from the categories field for products with an older schema
# (stored categories_tags can have old tags and old parents)
# - a product is a candidate for a country only if it is sold there (countries_tags)
# - scans by country are read from the scans.json file of each product
# - products are ranked by the sum of their unique scans in the country for the selected years,
# then by their scans for the most recent years, then by code
#
# The output has the same first columns as the off-query file, and can be passed to
# extract_data_for_representative_products.pl with --ranked-file

my $usage = <<TXT
select_representative_products.pl --jsonl <products.jsonl[.gz]> [--output <file.csv>] [--years 2025,2026]
TXT
	;

my $jsonl_file;
my $out_file = "projects/foodture/ranked_products.csv";
my $years_list = "2025,2026";

GetOptions(
	"jsonl=s" => \$jsonl_file,
	"output=s" => \$out_file,
	"years=s" => \$years_list,
) or die $usage;

defined $jsonl_file or die $usage;

# most recent year first, used for ties
my @years = sort {$b <=> $a} split(/\s*,\s*/, $years_list);

# same countries as extract_data_for_representative_products.pl
my @countries = qw/
	Austria
	Belgium
	Bulgaria
	Croatia
	Cyprus
	Czechia
	Denmark
	Estonia
	Finland
	France
	Germany
	Greece
	Hungary
	Ireland
	Italy
	Latvia
	Lithuania
	Luxembourg
	Malta
	Montenegro
	Netherlands
	Norway
	Poland
	Portugal
	Romania
	Serbia
	Slovakia
	Slovenia
	Spain
	Sweden
	Switzerland
	UK
	/;

# country tag -> country codes used in scans.json (GeoIP uses gb for the United Kingdom)
my %countries_ccs = ();
foreach my $country (@countries) {
	my $country_tag = canonicalize_taxonomy_tag('en', 'countries', $country);
	my $cc = country_to_cc($country_tag) // die "No country code for $country_tag\n";
	$countries_ccs{$country_tag} = [$cc];
	push @{$countries_ccs{$country_tag}}, 'gb' if $cc eq 'uk';
}

my @complete_states = qw/en:nutrition-facts-completed en:ingredients-completed en:photos-uploaded/;

# Cache of recomputed categories, as many products have the same categories
my %categories_cache = ();

sub get_current_categories ($product_ref) {
	my ($tag_lc, @input_tags);
	my $sources_ref = $product_ref->{tags_sources}{categories};
	if (ref $sources_ref eq 'HASH') {
		# schema >= 1005: categories_tags is made from the tags of all sources (users, producers etc.)
		my %tags = map {$_ => 1} map {@{$_->{tags} // []}} grep {ref $_ eq 'HASH'} values %$sources_ref;
		($tag_lc, @input_tags) = ('en', sort keys %tags);
	}
	elsif (($product_ref->{categories} // '') ne '') {
		# older schema: categories_tags is made from the categories field
		($tag_lc, @input_tags) = (
			$product_ref->{categories_lc} // $product_ref->{lc} // 'en',
			split(/\s*,\s*/, $product_ref->{categories})
		);
	}
	else {
		# fall back to the stored tags
		($tag_lc, @input_tags) = ('en', @{$product_ref->{categories_tags} // []});
	}
	my $key = join("\t", $tag_lc, @input_tags);
	$categories_cache{$key} //= [gen_tags_list_with_parents($tag_lc, 'categories', \@input_tags)];
	return $categories_cache{$key};
}

# 1 if the ranking key $a_ref is better than $b_ref: [total scans, scans for each year (most recent first), code]
sub is_better ($a_ref, $b_ref) {
	for my $i (0 .. $#years + 1) {
		return 1 if $a_ref->[$i] > $b_ref->[$i];
		return 0 if $a_ref->[$i] < $b_ref->[$i];
	}
	return ($a_ref->[-1] lt $b_ref->[-1]) ? 1 : 0;
}

my $IN;
if ($jsonl_file =~ /\.gz$/) {
	open($IN, '-|', 'gzip', '-dc', $jsonl_file) or die "Cannot read $jsonl_file: $!\n";
}
else {
	open($IN, '<', $jsonl_file) or die "Cannot read $jsonl_file: $!\n";
}

my $json = JSON::MaybeXS->new(utf8 => 1);

my %best = ();    # $best{country tag}{category tag} = [ranking key, product name]
my %complete_products = ();    # $complete_products{country tag}{category tag} = number of candidate products
my ($n, $n_complete, $n_selected) = (0, 0, 0);

while (my $line = <$IN>) {
	$n++;
	print STDERR "$n products read, $n_complete complete, $n_selected in FOODTURE countries\n" if $n % 100000 == 0;

	# quick filter before decoding the JSON
	next if grep {index($line, "\"$_\"") < 0} @complete_states;

	my $product_ref = eval {$json->decode($line)};
	if (not defined $product_ref) {
		warn "Cannot decode line $n: $@\n";
		next;
	}

	my %states = map {$_ => 1} @{$product_ref->{states_tags} // []};
	next if grep {not $states{$_}} @complete_states;
	$n_complete++;

	my $code = $product_ref->{code};
	next if (not defined $code) or (ref $code) or ($code eq '');

	my @product_countries = grep {defined $countries_ccs{$_}}
		map {canonicalize_taxonomy_tag('en', 'countries', $_)} @{$product_ref->{countries_tags} // []};
	next if not @product_countries;
	$n_selected++;

	my $categories_ref = get_current_categories($product_ref);
	next if not @$categories_ref;

	my $scans_ref = retrieve_object("$BASE_DIRS{PRODUCTS}/" . product_path_from_id($code) . "/scans") // {};

	my $name = $product_ref->{product_name} // '';

	foreach my $country_tag (@product_countries) {
		my @year_scans = ();
		foreach my $year (@years) {
			my $scans_by_country_ref = $scans_ref->{$year}{unique_scans_n_by_country} // {};
			my $year_scans = 0;
			$year_scans += $scans_by_country_ref->{$_} // 0 for @{$countries_ccs{$country_tag}};
			push @year_scans, $year_scans;
		}
		my $total = 0;
		$total += $_ for @year_scans;
		my $key_ref = [$total, @year_scans, $code];

		foreach my $category_tag (@$categories_ref) {
			$complete_products{$country_tag}{$category_tag}++;
			my $best_ref = $best{$country_tag}{$category_tag};
			if ((not defined $best_ref) or is_better($key_ref, $best_ref->[0])) {
				$best{$country_tag}{$category_tag} = [$key_ref, $name];
			}
		}
	}
}
close $IN;

print STDERR "$n products read, $n_complete complete, $n_selected in FOODTURE countries\n";

open(my $OUT, '>:encoding(UTF-8)', $out_file) or die "Cannot write $out_file: $!\n";
my $csv_out = Text::CSV->new({binary => 1, eol => "\n"});
$csv_out->print($OUT,
	["code", "name", "country", "category", "scans", "complete_products", map {"country_scans_$_"} @years]);

my $rows = 0;
foreach my $country_tag (sort keys %best) {
	foreach my $category_tag (sort keys %{$best{$country_tag}}) {
		my ($key_ref, $name) = @{$best{$country_tag}{$category_tag}};
		my ($total, @year_scans) = @$key_ref[0 .. $#years + 1];
		$csv_out->print(
			$OUT,
			[
				$key_ref->[-1], $name, $country_tag, $category_tag, $total,
				$complete_products{$country_tag}{$category_tag}, @year_scans
			]
		);
		$rows++;
	}
}
close $OUT;

print STDERR "$rows country / category pairs written to $out_file\n";
