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

use ProductOpener::Tags qw/:all/;
use JSON::MaybeXS;
use Text::CSV;
use Getopt::Long;
use POSIX qw/strftime/;
use File::Basename qw/basename/;
use FindBin;
use lib $FindBin::Bin;
use RepresentativeProducts
	qw/%foodture_countries @complete_states %missing_names &dataset_countries_ccs &count_uploaded_photos &get_current_categories &retrieve_product_scans &country_year_scans &global_year_scans &is_better &open_jsonl/;

# List of the FoodEx2 categories needed by FOODTURE in each country, for the in-store citizen science campaign:
# contributors scan and photograph products of the categories that have no complete product in their country.
#
# For each needed (FOODTURE code, country), from the JSONL dump of the products:
# - the most scanned complete product of the OFF category in the country (same ranking as select_representative_products.pl:
#   categories recomputed with the current taxonomy, scans read from the scans.json file of each product),
# - the number of products of the category sold in the country, of complete products,
#   and of incomplete products that have photos (that contributors could complete from the photos),
# - a status: OK (a complete product is selected), INCOMPLETE (products, but none complete), MISSING (no product).
#
# Fallback categories (broader categories for the terms that have no product) are not used: the fallback_category
# column is left empty, for the end of the campaign.
#
# With --all-pairs, all the FOODTURE codes in all the countries of the representative products dataset
# (including Canada and Iceland) are listed, with foodture_needed = 0 for the pairs that FOODTURE does not need.
#
# The terms of the dataset countries that FOODTURE does not need (Iceland, Canada) are listed in
# --other-countries (representative_dataset_other_countries.csv, made by generate_needed_term_countries.py):
# they have foodture_needed = 0, dataset_needed = 1 and the rule used to choose them in selection_rule.
#
# Outputs, in --output-dir: foodture_campaign.csv and foodture_campaign.json, and
# foodture_selected_products_without_team.txt: the codes of the selected products (FOODTURE pairs, and Iceland and
# Canada) that are not yet in the --team team (foodture-2026 by default), one per line, to tag them with
# update_all_products.pl --query-codes-from-file --team
# build_campaign_site.pl makes the web pages from foodture_campaign.json

my $usage = <<TXT
list_campaign_needed_categories.pl --jsonl <products.jsonl[.gz]> --output-dir <dir>
	[--needed <foodture_needed_term_countries.csv>] [--mapping <foodture_foodex2_to_off_categories.csv>]
	[--other-countries <representative_dataset_other_countries.csv>]
	[--years 2025,2026] [--min-photos 3] [--max-incomplete 3] [--all-pairs] [--dump-date YYYY-MM-DD] [--team foodture-2026]
TXT
	;

my $jsonl_file;
my $output_dir;
my $needed_file = "$FindBin::Bin/foodture_needed_term_countries.csv";
my $other_countries_file = "$FindBin::Bin/representative_dataset_other_countries.csv";
my $mapping_file = "$FindBin::Bin/foodture_foodex2_to_off_categories.csv";
my $years_list = "2025,2026";
my $min_photos = 3;
my $max_incomplete = 3;
my $all_pairs = 0;
my $dump_date;
my $team = "foodture-2026";

GetOptions(
	"jsonl=s" => \$jsonl_file,
	"output-dir=s" => \$output_dir,
	"needed=s" => \$needed_file,
	"other-countries=s" => \$other_countries_file,
	"mapping=s" => \$mapping_file,
	"years=s" => \$years_list,
	"min-photos=i" => \$min_photos,
	"max-incomplete=i" => \$max_incomplete,
	"all-pairs" => \$all_pairs,
	"dump-date=s" => \$dump_date,
	"team=s" => \$team,
) or die $usage;

(defined $jsonl_file and defined $output_dir) or die $usage;
-d $output_dir or die "Output directory $output_dir does not exist\n";

# most recent year first
my @years = sort {$b <=> $a} split(/\s*,\s*/, $years_list);
$dump_date //= strftime("%Y-%m-%d", gmtime((stat($jsonl_file))[9]));

my $csv = Text::CSV->new({binary => 1, eol => "\n"});

sub read_csv ($file) {
	open(my $IN, '<:encoding(UTF-8)', $file) or die "Cannot read $file: $!\n";
	my $header_ref = $csv->getline($IN);
	$csv->column_names(@$header_ref);
	my @rows = ();
	while (my $row_ref = $csv->getline_hr($IN)) {
		push @rows, $row_ref;
	}
	close $IN;
	return @rows;
}

# Countries: tag -> country codes in scans.json, English name, languages, code of the country subdomain
my %countries_ccs = %{dataset_countries_ccs()};
my %foodture_country_tags
	= map {canonicalize_taxonomy_tag('en', 'countries', $_) => $foodture_countries{$_}} keys %foodture_countries;
my %countries = ();
foreach my $country_tag (keys %countries_ccs) {
	my $cc = $countries_ccs{$country_tag}[0];
	my @languages = split(/\s*,\s*/, get_property('countries', $country_tag, 'language_codes:en') // 'en');
	my $name = display_taxonomy_tag('en', 'countries', $country_tag);
	$countries{$country_tag} = {
		name => $name,
		cc => $cc,
		languages => \@languages,
		foodture => $foodture_country_tags{$country_tag} // 0,
	};
}

# FOODTURE codes and their OFF category
my %terms = ();
my %tracked_categories = ();
foreach my $row_ref (read_csv($mapping_file)) {
	my $category = $row_ref->{off_category};
	next if ($category // '') eq '';
	my $canon_category = canonicalize_taxonomy_tag('en', 'categories', $category);
	if (not exists_taxonomy_tag('categories', $canon_category)) {
		print STDERR "Warning: category $category of $row_ref->{foodture_code} is not in the taxonomy\n";
	}
	$terms{$row_ref->{foodture_code}} = {%$row_ref, off_category => $canon_category};
	$tracked_categories{$canon_category} = 1;
}

# Needed (FOODTURE code, country) pairs
my %needed = ();
foreach my $row_ref (read_csv($needed_file)) {
	my $country_tag = canonicalize_taxonomy_tag('en', 'countries', $row_ref->{country_tag} || $row_ref->{country});
	if (not defined $countries{$country_tag}) {
		print STDERR "Warning: country $row_ref->{country} is not in the dataset countries\n";
		next;
	}
	if (not defined $terms{$row_ref->{foodture_code}}) {
		print STDERR "Warning: FOODTURE code $row_ref->{foodture_code} is not in the mapping\n";
		next;
	}
	$needed{$row_ref->{foodture_code}}{$country_tag} = 1;
}

# Terms of the dataset countries that FOODTURE does not need: code -> country tag -> selection rule
my %other_needed = ();
foreach my $row_ref (read_csv($other_countries_file)) {
	my $country_tag = canonicalize_taxonomy_tag('en', 'countries', $row_ref->{country_tag} || $row_ref->{country});
	next if (not defined $countries{$country_tag}) or (not defined $terms{$row_ref->{foodture_code}});
	$other_needed{$row_ref->{foodture_code}}{$country_tag} = $row_ref->{selection_rule} // '';
}

# Ingredients of the selected products (Taxonomy Wiz mission): an ingredient is known if it is in the current
# ingredients taxonomy (the is_in_taxonomy field of the products is computed with the taxonomy of their last update)
my %ingredient_cache = ();    # stored id -> [canonical tag, known]

sub check_ingredient ($id) {
	return ('', 0) if $id eq '';
	if (not defined $ingredient_cache{$id}) {
		my $tag = canonicalize_taxonomy_tag('en', 'ingredients', $id);
		$ingredient_cache{$id} = [$tag, exists_taxonomy_tag('ingredients', $tag) ? 1 : 0];
	}
	return @{$ingredient_cache{$id}};
}

# Share of the estimated quantity of the ingredients (percent_estimate) that is recognized: FOODTURE computes the
# environmental impact of the products from their ingredients, and needs at least 95% of the quantity recognized.
# A recognized ingredient counts with all its quantity (even if some of its sub-ingredients are unknown),
# an unknown ingredient with sub-ingredients is replaced by its sub-ingredients.
# Returns undef if the product has no ingredients with an estimated quantity.
sub recognized_quantity ($ingredients_ref) {
	my ($total, $known) = (0, 0);
	foreach my $ingredient_ref (@{$ingredients_ref // []}) {
		next if ref $ingredient_ref ne 'HASH';
		my $quantity = $ingredient_ref->{percent_estimate};
		next
			if (not defined $quantity)
			or (ref $quantity)
			or ($quantity !~ /^-?[\d.]+(?:e-?\d+)?$/i)
			or ($quantity <= 0);
		$total += $quantity;
		my (undef, $is_known) = check_ingredient($ingredient_ref->{id} // '');
		if ($is_known) {
			$known += $quantity;
		}
		elsif (ref $ingredient_ref->{ingredients} eq 'ARRAY') {
			my ($sub_total, $sub_known) = recognized_quantity($ingredient_ref->{ingredients});
			# the sub-ingredients may not add up to the quantity of the ingredient
			$known += $quantity * $sub_known / $sub_total if $sub_total > 0;
		}
	}
	return ($total, $known);
}

sub recognized_quantity_pct ($ingredients_ref) {
	my ($total, $known) = recognized_quantity($ingredients_ref);
	return $total > 0 ? sprintf("%.1f", 100 * $known / $total) + 0 : undef;
}

sub ingredients_stats ($product_ref, $info_ref) {
	my ($n, $unknown) = (0, 0);
	my %unknown_tags = ();
	my @stack = @{$product_ref->{ingredients} // []};
	while (my $ingredient_ref = shift @stack) {
		next if ref $ingredient_ref ne 'HASH';
		push @stack, @{$ingredient_ref->{ingredients}} if ref $ingredient_ref->{ingredients} eq 'ARRAY';
		next if ($ingredient_ref->{id} // '') eq '';
		$n++;
		my ($tag, $known) = check_ingredient($ingredient_ref->{id});
		if (not $known) {
			$unknown++;
			$unknown_tags{$tag} = 1;
		}
	}
	$info_ref->{ingredients_n} = $n;
	$info_ref->{unknown_ingredients_n} = $unknown;
	$info_ref->{recognized_quantity_pct} = recognized_quantity_pct($product_ref->{ingredients});
	$info_ref->{unknown_ingredients} = [sort keys %unknown_tags];
	$info_ref->{ingredients_lc} = $product_ref->{ingredients_lc} // $product_ref->{lc} // '';
	return;
}

# Quick filter before decoding the JSON: products sold in one of the countries
my $countries_regexp = join('|', map {quotemeta("\"$_\"")} sort keys %countries);
$countries_regexp = qr/$countries_regexp/;

my $json = JSON::MaybeXS->new(utf8 => 1, canonical => 1);

# $stats{country tag}{category tag} = {products => n, complete => n, with_photos => n, best => [key, product], incomplete => [[key, product]]}
my %stats = ();
my ($n, $n_countries, $n_categories) = (0, 0, 0);

my $IN = open_jsonl($jsonl_file);
while (my $line = <$IN>) {
	$n++;
	print STDERR "$n products read, $n_countries in the countries, $n_categories in the tracked categories\n"
		if $n % 500000 == 0;
	next if $line !~ $countries_regexp;

	my $product_ref = eval {$json->decode($line)};
	if (not defined $product_ref) {
		warn "Cannot decode line $n: $@\n";
		next;
	}
	my $code = $product_ref->{code};
	next if (not defined $code) or (ref $code) or ($code eq '');

	my @product_countries = grep {defined $countries{$_}}
		map {canonicalize_taxonomy_tag('en', 'countries', $_)} @{$product_ref->{countries_tags} // []};
	next if not @product_countries;
	$n_countries++;

	my @categories = grep {$tracked_categories{$_}} @{get_current_categories($product_ref)};
	next if not @categories;
	$n_categories++;

	my %states = map {$_ => 1} @{$product_ref->{states_tags} // []};
	my @missing = grep {not $states{$_}} @complete_states;
	my $complete = @missing ? 0 : 1;
	my $photos = count_uploaded_photos($product_ref);
	my $with_photos = (
		(not $complete) and (($states{'en:ingredients-photo-selected'} and $states{'en:nutrition-photo-selected'})
			or ($photos >= $min_photos))
	) ? 1 : 0;

	my ($scans_ref, $product_info_ref);
	if ($complete or $with_photos) {
		$scans_ref = retrieve_product_scans($code);
		my %names = map {$_ => $product_ref->{$_}} grep {/^product_name(_\w\w)?$/ and ($product_ref->{$_} // '') ne ''}
			keys %$product_ref;
		$product_info_ref = {
			code => $code,
			names => \%names,
			brands => $product_ref->{brands} // '',
			photos => $photos,
			missing => join(", ", map {$missing_names{$_}} @missing),
			global_scans => [global_year_scans($scans_ref, \@years)],
			in_team => (grep {$_ eq $team} @{$product_ref->{teams_tags} // []}) ? 1 : 0,
		};
		ingredients_stats($product_ref, $product_info_ref) if $complete;
	}

	foreach my $country_tag (@product_countries) {
		my $key_ref;
		if (defined $scans_ref) {
			my @year_scans = country_year_scans($scans_ref, \@years, $countries_ccs{$country_tag});
			my $total = 0;
			$total += $_ for @year_scans;
			$key_ref = [$total, @year_scans, $code];
		}
		foreach my $category_tag (@categories) {
			my $stats_ref = $stats{$country_tag}{$category_tag} //= {products => 0, complete => 0, with_photos => 0};
			$stats_ref->{products}++;
			if ($complete) {
				$stats_ref->{complete}++;
				if ((not defined $stats_ref->{best}) or is_better($key_ref, $stats_ref->{best}[0])) {
					$stats_ref->{best} = [$key_ref, $product_info_ref];
				}
			}
			elsif ($with_photos) {
				$stats_ref->{with_photos}++;
				my $list_ref = $stats_ref->{incomplete} //= [];
				next if (@$list_ref >= $max_incomplete) and (not is_better($key_ref, $list_ref->[-1][0]));
				push @$list_ref, [$key_ref, $product_info_ref];
				@$list_ref = sort {is_better($a->[0], $b->[0]) ? -1 : 1} @$list_ref;
				splice(@$list_ref, $max_incomplete) if @$list_ref > $max_incomplete;
			}
		}
	}
}
close $IN;
print STDERR "$n products read, $n_countries in the countries, $n_categories in the tracked categories\n";

# Name of a category in a language, or empty if it is not translated
sub category_name ($lc, $category_tag) {
	my $name = $translations_to{categories}{$category_tag}{$lc} // $translations_to{categories}{$category_tag}{xx};
	return $name // '';
}

sub product_name ($product_ref, $languages_ref) {
	my $names_ref = $product_ref->{names};
	foreach my $field ((map {"product_name_$_"} @$languages_ref), "product_name", "product_name_en") {
		return $names_ref->{$field} if defined $names_ref->{$field};
	}
	my ($any) = sort keys %$names_ref;
	return defined $any ? $names_ref->{$any} : '';
}

# Rows: one per (FOODTURE code, country)
my @rows = ();
my %status_order = (MISSING => 0, INCOMPLETE => 1, OK => 2);
my %status_labels = (
	OK => 'complete product selected',
	INCOMPLETE => 'incomplete products only',
	MISSING => 'no product',
);
foreach my $code (sort keys %terms) {
	my $term_ref = $terms{$code};
	my $category_tag = $term_ref->{off_category};
	foreach my $country_tag (sort keys %countries) {
		my $foodture_needed = $needed{$code}{$country_tag} ? 1 : 0;
		my $selection_rule
			= $foodture_needed ? 'FOODTURE (ACTIA, EFSA consumption data)' : $other_needed{$code}{$country_tag};
		my $dataset_needed = defined $selection_rule ? 1 : 0;
		next if not($dataset_needed or $all_pairs);
		my $country_ref = $countries{$country_tag};
		my $cc = $country_ref->{cc};
		my $stats_ref = $stats{$country_tag}{$category_tag} // {products => 0, complete => 0, with_photos => 0};
		my $status = $stats_ref->{complete} ? 'OK' : $stats_ref->{products} ? 'INCOMPLETE' : 'MISSING';
		my %row = (
			foodture_needed => $foodture_needed,
			dataset_needed => $dataset_needed,
			selection_rule => $selection_rule // '',
			foodture_country => $country_ref->{foodture},
			country => $country_ref->{name},
			country_tag => $country_tag,
			country_code => $cc,
			foodture_code => $code,
			foodex2_code => $term_ref->{foodex2_code},
			foodex2_name => $term_ref->{foodture_name},
			l1 => $term_ref->{l1},
			l2 => $term_ref->{l2},
			mapping_status => $term_ref->{status},
			needs_recipe => $term_ref->{needs_recipe},
			off_category => $category_tag,
			off_category_name_en => category_name('en', $category_tag) || $term_ref->{off_name},
			off_category_names_local => join("; ",
				map {"$_: " . category_name($_, $category_tag)}
				grep {($_ ne 'en') and (category_name($_, $category_tag) ne '')} @{$country_ref->{languages}}),
			off_category_untranslated_languages =>
				join(",", grep {category_name($_, $category_tag) eq ''} @{$country_ref->{languages}}),
			# country subdomain + one facet: the products of the category sold in the country.
			# (world.openfoodfacts.org/facets/countries/<country>/categories/<category> needs a logged in user,
			# as 2 facets are not served to robots). English path and tag, redirected to the local language.
			category_url => "https://$cc.openfoodfacts.org/facets/categories/" . ($category_tag =~ s/^en://r),
			fallback_category => '',
			status => $status,
			status_label => $status_labels{$status},
			products => $stats_ref->{products},
			complete_products => $stats_ref->{complete},
			incomplete_products_with_photos => $stats_ref->{with_photos},
			incomplete_products_with_photos_codes => join(",", map {$_->[1]{code}} @{$stats_ref->{incomplete} // []}),
		);
		if (defined $stats_ref->{best}) {
			my ($key_ref, $product_ref) = @{$stats_ref->{best}};
			my $global = 0;
			$global += $_ for @{$product_ref->{global_scans}};
			%row = (
				%row,
				code => $product_ref->{code},
				product_name => product_name($product_ref, $country_ref->{languages}),
				brands => $product_ref->{brands},
				product_url => "https://$cc.openfoodfacts.org/product/$product_ref->{code}",
				country_scans => $key_ref->[0],
				(map {("country_scans_$years[$_]" => $key_ref->[$_ + 1])} 0 .. $#years),
				global_scans => $global,
				(map {("global_scans_$years[$_]" => $product_ref->{global_scans}[$_])} 0 .. $#years),
				ingredients_lc => $product_ref->{ingredients_lc},
				ingredients_n => $product_ref->{ingredients_n},
				unknown_ingredients_n => $product_ref->{unknown_ingredients_n},
				unknown_ingredients => $product_ref->{unknown_ingredients},
				recognized_quantity_pct => $product_ref->{recognized_quantity_pct},
				in_team => $product_ref->{in_team},
			);
		}
		$row{incomplete_products} = [
			map {
				{
					code => $_->[1]{code},
					product_name => product_name($_->[1], $country_ref->{languages}),
					brands => $_->[1]{brands},
					photos => $_->[1]{photos},
					missing => $_->[1]{missing},
					country_scans => $_->[0][0],
					product_url => "https://$cc.openfoodfacts.org/product/$_->[1]{code}",
				}
			} @{$stats_ref->{incomplete} // []}
		];
		push @rows, \%row;
	}
}

@rows = sort {
		   $a->{country} cmp $b->{country}
		or $b->{dataset_needed} <=> $a->{dataset_needed}
		or $status_order{$a->{status}} <=> $status_order{$b->{status}}
		or lc($a->{off_category_name_en}) cmp lc($b->{off_category_name_en})
		or $a->{foodture_code} cmp $b->{foodture_code}
} @rows;

my @columns = (
	qw/foodture_needed dataset_needed selection_rule foodture_country country country_tag country_code foodture_code foodex2_code foodex2_name l1 l2
		mapping_status needs_recipe off_category off_category_name_en off_category_names_local off_category_untranslated_languages
		category_url fallback_category status status_label code product_name brands product_url country_scans/,
	(map {"country_scans_$_"} @years),
	'global_scans',
	(map {"global_scans_$_"} @years),
	qw/ingredients_lc ingredients_n unknown_ingredients_n unknown_ingredients recognized_quantity_pct/,
	qw/products complete_products incomplete_products_with_photos incomplete_products_with_photos_codes/
);

# CSV
my $csv_file = "$output_dir/foodture_campaign.csv";
open(my $CSV, '>:encoding(UTF-8)', "$csv_file.tmp") or die "Cannot write $csv_file.tmp: $!\n";
$csv->print($CSV, \@columns);
# list fields (unknown ingredients can contain commas): separated by " | " in the CSV
$csv->print($CSV, [map {ref $_ eq 'ARRAY' ? join(" | ", @$_) : $_ // ''} @$_{@columns}]) for @rows;
close $CSV;
rename("$csv_file.tmp", $csv_file) or die "Cannot rename $csv_file.tmp: $!\n";

# Selected products of the dataset (FOODTURE pairs, and Iceland and Canada) that are not yet in the team
my %without_team = map {($_->{code} => 1)} grep {$_->{dataset_needed} and $_->{code} and not $_->{in_team}} @rows;
my $codes_file = "$output_dir/foodture_selected_products_without_team.txt";
open(my $CODES, '>', "$codes_file.tmp") or die "Cannot write $codes_file.tmp: $!\n";
print $CODES "$_\n" for sort keys %without_team;
close $CODES;
rename("$codes_file.tmp", $codes_file) or die "Cannot rename $codes_file.tmp: $!\n";
print STDERR scalar(keys %without_team) . " selected products are not in the $team team: $codes_file\n";

# Summary per country
my %summary = ();
foreach my $row_ref (grep {$_->{dataset_needed}} @rows) {
	$summary{$row_ref->{country}}{$row_ref->{status}}++;
	$summary{$row_ref->{country}}{total}++;
	next if not $row_ref->{foodture_needed};
	$summary{''}{$row_ref->{status}}++;
	$summary{''}{total}++;
}

my $generated = strftime("%Y-%m-%d %H:%M UTC", gmtime());

# JSON
my $json_file = "$output_dir/foodture_campaign.json";
open(my $JSON, '>', "$json_file.tmp") or die "Cannot write $json_file.tmp: $!\n";
print $JSON JSON::MaybeXS->new(utf8 => 1, canonical => 1, pretty => 1)->encode(
	{
		generated => $generated,
		dump_date => $dump_date,
		dump_file => basename($jsonl_file),
		scans_years => \@years,
		all_pairs => $all_pairs ? JSON::MaybeXS::true : JSON::MaybeXS::false,
		countries => {
			map {
				(
					$countries{$_}{name} => {
						country_tag => $_,
						country_code => $countries{$_}{cc},
						languages => $countries{$_}{languages},
						foodture_country => $countries{$_}{foodture},
					}
				)
			} keys %countries
		},
		summary => {
			map {
				my $s = $summary{$_};
				(($_ eq '' ? 'All FOODTURE countries' : $_) =>
						{map {($_ => $s->{$_} // 0)} qw/total OK INCOMPLETE MISSING/})
			} keys %summary
		},
		# names of the categories in all the languages of the taxonomy (for the mini-sites, in the language of the user)
		category_names => {
			map {
				my $tag = $_;
				($tag => {%{$translations_to{categories}{$tag} // {}}})
			} sort keys %tracked_categories
		},
		rows => \@rows,
	}
);
close $JSON;
rename("$json_file.tmp", $json_file) or die "Cannot rename $json_file.tmp: $!\n";

my $all = $summary{''} // {};

print STDERR scalar(@rows) . " rows written to $csv_file and $json_file\n";
foreach my $country (sort grep {$_ ne ''} keys %summary) {
	my $s = $summary{$country};
	printf STDERR "%-20s %4d needed: %4d OK, %4d INCOMPLETE, %4d MISSING\n", $country, $s->{total}, $s->{OK} // 0,
		$s->{INCOMPLETE} // 0, $s->{MISSING} // 0;
}
printf STDERR "%-20s %4d needed: %4d OK, %4d INCOMPLETE, %4d MISSING\n", "All FOODTURE", $all->{total} // 0,
	$all->{OK} // 0,
	$all->{INCOMPLETE} // 0, $all->{MISSING} // 0;
