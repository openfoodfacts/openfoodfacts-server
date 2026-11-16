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
# Outputs, in --output-dir: index.html, foodture_campaign.csv, foodture_campaign.json

my $usage = <<TXT
list_campaign_needed_categories.pl --jsonl <products.jsonl[.gz]> --output-dir <dir>
	[--needed <foodture_needed_term_countries.csv>] [--mapping <foodture_foodex2_to_off_categories.csv>]
	[--years 2025,2026] [--min-photos 3] [--max-incomplete 3] [--all-pairs] [--dump-date YYYY-MM-DD]
TXT
	;

my $jsonl_file;
my $output_dir;
my $needed_file = "$FindBin::Bin/foodture_needed_term_countries.csv";
my $mapping_file = "$FindBin::Bin/foodture_foodex2_to_off_categories.csv";
my $years_list = "2025,2026";
my $min_photos = 3;
my $max_incomplete = 3;
my $all_pairs = 0;
my $dump_date;

GetOptions(
	"jsonl=s" => \$jsonl_file,
	"output-dir=s" => \$output_dir,
	"needed=s" => \$needed_file,
	"mapping=s" => \$mapping_file,
	"years=s" => \$years_list,
	"min-photos=i" => \$min_photos,
	"max-incomplete=i" => \$max_incomplete,
	"all-pairs" => \$all_pairs,
	"dump-date=s" => \$dump_date,
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
		};
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
		next if not($foodture_needed or $all_pairs);
		my $country_ref = $countries{$country_tag};
		my $cc = $country_ref->{cc};
		my $stats_ref = $stats{$country_tag}{$category_tag} // {products => 0, complete => 0, with_photos => 0};
		my $status = $stats_ref->{complete} ? 'OK' : $stats_ref->{products} ? 'INCOMPLETE' : 'MISSING';
		my %row = (
			foodture_needed => $foodture_needed,
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
		or $b->{foodture_needed} <=> $a->{foodture_needed}
		or $status_order{$a->{status}} <=> $status_order{$b->{status}}
		or lc($a->{off_category_name_en}) cmp lc($b->{off_category_name_en})
		or $a->{foodture_code} cmp $b->{foodture_code}
} @rows;

my @columns = (
	qw/foodture_needed foodture_country country country_tag country_code foodture_code foodex2_code foodex2_name l1 l2
		mapping_status off_category off_category_name_en off_category_names_local off_category_untranslated_languages
		category_url fallback_category status status_label code product_name brands product_url country_scans/,
	(map {"country_scans_$_"} @years),
	'global_scans',
	(map {"global_scans_$_"} @years),
	qw/products complete_products incomplete_products_with_photos incomplete_products_with_photos_codes/
);

# CSV
my $csv_file = "$output_dir/foodture_campaign.csv";
open(my $CSV, '>:encoding(UTF-8)', "$csv_file.tmp") or die "Cannot write $csv_file.tmp: $!\n";
$csv->print($CSV, \@columns);
$csv->print($CSV, [map {$_ // ''} @$_{@columns}]) for @rows;
close $CSV;
rename("$csv_file.tmp", $csv_file) or die "Cannot rename $csv_file.tmp: $!\n";

# Summary per country
my %summary = ();
foreach my $row_ref (grep {$_->{foodture_needed}} @rows) {
	$summary{$row_ref->{country}}{$row_ref->{status}}++;
	$summary{$row_ref->{country}}{total}++;
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
		summary => {
			map {
				my $s = $summary{$_};
				(($_ eq '' ? 'All countries' : $_) => {map {($_ => $s->{$_} // 0)} qw/total OK INCOMPLETE MISSING/})
			} keys %summary
		},
		rows => \@rows,
	}
);
close $JSON;
rename("$json_file.tmp", $json_file) or die "Cannot rename $json_file.tmp: $!\n";

# HTML
sub h ($text) {
	$text //= '';
	$text =~ s/&/&amp;/g;
	$text =~ s/</&lt;/g;
	$text =~ s/>/&gt;/g;
	$text =~ s/"/&quot;/g;
	return $text;
}

sub country_id ($name) {
	my $id = lc($name);
	$id =~ s/[^a-z0-9]+/-/g;
	return "country-$id";
}

sub fmt_scans ($row_ref) {
	return
		join(" · ", "country: " . ($row_ref->{country_scans} // 0),
		"all countries: " . ($row_ref->{global_scans} // 0));
}

my @country_names = sort keys %{{map {$_->{country} => 1} @rows}};
my $years_text = join(" and ", sort @years);

my $html = <<HTML;
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>FOODTURE: products to scan in each country</title>
<style>
:root { --bg: #fff; --fg: #1f2328; --muted: #57606a; --line: #d0d7de; --head: #f6f8fa;
	--missing: #b42318; --missing-bg: #fde8e7; --incomplete: #9a6700; --incomplete-bg: #fff4d6; --ok: #1a7f37; --ok-bg: #e6f4ea; --link: #0969da; }
\@media (prefers-color-scheme: dark) { :root { --bg: #0d1117; --fg: #e6edf3; --muted: #9198a1; --line: #30363d; --head: #161b22;
	--missing: #ff8b80; --missing-bg: #3d1614; --incomplete: #e3b341; --incomplete-bg: #33270b; --ok: #56d364; --ok-bg: #12301b; --link: #4493f8; } }
body { margin: 0; padding: 0 16px 48px; background: var(--bg); color: var(--fg); font: 15px/1.45 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; }
main { max-width: 1200px; margin: 0 auto; }
h1 { font-size: 1.6rem; margin: 24px 0 8px; }
h2 { font-size: 1.25rem; margin: 32px 0 4px; padding-top: 8px; border-top: 2px solid var(--line); }
a { color: var(--link); }
.muted, small { color: var(--muted); }
.note { background: var(--head); border: 1px solid var(--line); border-radius: 6px; padding: 8px 12px; margin: 12px 0; }
.filters { position: sticky; top: 0; z-index: 1; background: var(--bg); padding: 10px 0; border-bottom: 1px solid var(--line); display: flex; flex-wrap: wrap; gap: 8px 16px; align-items: center; }
.filters label { white-space: nowrap; }
select, input[type=search] { font: inherit; padding: 4px 6px; color: var(--fg); background: var(--bg); border: 1px solid var(--line); border-radius: 4px; }
.table-wrap { overflow-x: auto; }
table { border-collapse: collapse; width: 100%; margin: 8px 0; }
th, td { border-bottom: 1px solid var(--line); padding: 6px 8px; text-align: left; vertical-align: top; }
th { background: var(--head); font-weight: 600; }
td.num { text-align: right; white-space: nowrap; }
.badge { display: inline-block; padding: 1px 8px; border-radius: 10px; font-size: 0.85em; font-weight: 600; white-space: nowrap; }
.MISSING { color: var(--missing); background: var(--missing-bg); }
.INCOMPLETE { color: var(--incomplete); background: var(--incomplete-bg); }
.OK { color: var(--ok); background: var(--ok-bg); }
.cat { font-weight: 600; }
.local { font-style: italic; }
.summary td, .summary th { text-align: right; }
.summary td:first-child, .summary th:first-child { text-align: left; }
.hidden { display: none; }
\@media (max-width: 700px) { .details-col { display: none; } }
</style>
</head>
<body>
<main>
<h1>FOODTURE: products to scan in each country</h1>
<p>The <a href="https://foodture.eu/">FOODTURE</a> research project needs, for each type of food (FoodEx2 term) and each European country,
one representative product with complete data on Open Food Facts: photos, ingredients and nutrition facts.
This page lists the food categories needed in each country. Categories with <span class="badge MISSING">no product</span> or with
<span class="badge INCOMPLETE">incomplete products only</span> are listed first: if you live in one of these countries,
please scan and photograph products of these categories in stores with the Open Food Facts app,
or complete existing products from their photos.</p>
<div class="note">
<b>Updated daily.</b> Data: Open Food Facts products of $dump_date, page generated $generated. The selected product is the most scanned
complete product of the category sold in the country (unique scans in $years_text).<br>
The counts of this page use the latest categories taxonomy. The category pages on the Open Food Facts website can show fewer products
until all products are updated with the new categories.<br>
Data: <a href="foodture_campaign.csv">CSV</a> · <a href="foodture_campaign.json">JSON</a>
</div>
HTML

# overall summary table
$html .= <<HTML;
<h2 id="summary">Summary</h2>
<div class="table-wrap"><table class="summary">
<tr><th>Country</th><th>Needed categories</th><th><span class="badge MISSING">no product</span></th><th><span class="badge INCOMPLETE">incomplete only</span></th><th><span class="badge OK">complete</span></th></tr>
HTML
foreach my $country (
	sort {($summary{$b}{MISSING} // 0) <=> ($summary{$a}{MISSING} // 0) or $a cmp $b}
	grep {$_ ne ''} keys %summary
	)
{
	my $s = $summary{$country};
	$html .= sprintf(
		"<tr><td><a href=\"#%s\">%s</a></td><td>%d</td><td>%d</td><td>%d</td><td>%d</td></tr>\n",
		country_id($country), h($country), $s->{total},
		$s->{MISSING} // 0,
		$s->{INCOMPLETE} // 0,
		$s->{OK} // 0
	);
}
my $all = $summary{''} // {};
$html .= sprintf(
	"<tr><th>All countries</th><th>%d</th><th>%d</th><th>%d</th><th>%d</th></tr>\n</table></div>\n",
	$all->{total} // 0,
	$all->{MISSING} // 0,
	$all->{INCOMPLETE} // 0,
	$all->{OK} // 0
);

# filters
$html .= qq{<div class="filters">\n<label>Country <select id="f-country"><option value="">All countries</option>\n};
$html .= qq{<option value="} . h($_) . qq{">} . h($_) . "</option>\n" for @country_names;
$html .= <<HTML;
</select></label>
<label><input type="checkbox" class="f-status" value="MISSING" checked> <span class="badge MISSING">no product</span></label>
<label><input type="checkbox" class="f-status" value="INCOMPLETE" checked> <span class="badge INCOMPLETE">incomplete only</span></label>
<label><input type="checkbox" class="f-status" value="OK" checked> <span class="badge OK">complete</span></label>
<label><input type="search" id="f-text" placeholder="Search a category"></label>
<span id="f-count" class="muted"></span>
</div>
HTML

foreach my $country (@country_names) {
	my @country_rows = grep {$_->{country} eq $country} @rows;
	my $s = $summary{$country} // {};
	my $first = $country_rows[0];
	my $languages = join(", ", @{$countries{$first->{country_tag}}{languages}});
	$html .= sprintf(
		qq{<section class="country" data-country="%s">\n<h2 id="%s">%s</h2>\n<p class="muted">%d needed categories: %d with no product, %d with incomplete products only, %d with a complete product. Category names in: en, %s.</p>\n},
		h($country), country_id($country), h($country),
		$s->{total} // 0,
		$s->{MISSING} // 0,
		$s->{INCOMPLETE} // 0,
		$s->{OK} // 0,
		h($languages)
	);
	$html
		.= qq{<div class="table-wrap"><table>\n<tr><th>Category</th><th>Status</th><th>Products in $country</th><th class="details-col">Selected product</th></tr>\n};
	foreach my $r (@country_rows) {
		my $search = lc(join(" ", $r->{off_category_name_en}, $r->{off_category_names_local}, $r->{foodex2_name}));
		my $category
			= qq{<a class="cat" href="} . h($r->{category_url}) . qq{">} . h($r->{off_category_name_en}) . "</a>";
		$category .= qq{<br><span class="local">} . h($r->{off_category_names_local}) . "</span>"
			if $r->{off_category_names_local} ne '';
		$category .= "<br><small>FoodEx2 " . h($r->{foodex2_code}) . ": " . h($r->{foodex2_name}) . "</small>";
		$category .= "<br><small>Not needed by FOODTURE (dataset only)</small>" if not $r->{foodture_needed};
		my $counts = sprintf(
			"%d products<br>%d complete<br>%d incomplete with photos",
			$r->{products},
			$r->{complete_products},
			$r->{incomplete_products_with_photos}
		);
		if (@{$r->{incomplete_products}}) {
			$counts .= "<br><small>to complete: " . join(
				", ",
				map {
						  qq{<a href="}
						. h($_->{product_url})
						. qq{" title="missing: }
						. h($_->{missing}) . qq{">}
						. h($_->{code}) . "</a>"
				} @{$r->{incomplete_products}}
			) . "</small>";
		}
		my $product = '';
		if (defined $r->{code}) {
			$product
				= qq{<a href="}
				. h($r->{product_url}) . qq{">}
				. h($r->{product_name} || $r->{code}) . "</a>"
				. ($r->{brands} ne '' ? " – " . h($r->{brands}) : '')
				. "<br><small>"
				. h($r->{code})
				. "<br>scans $years_text: "
				. fmt_scans($r)
				. "</small>";
		}
		$html .= sprintf(
			qq{<tr class="row" data-status="%s" data-search="%s"><td>%s</td><td><span class="badge %s">%s</span></td><td>%s</td><td class="details-col">%s</td></tr>\n},
			$r->{status}, h($search), $category, $r->{status}, h($r->{status_label}),
			$counts, $product
		);
	}
	$html .= "</table></div>\n</section>\n";
}

$html .= <<'HTML';
<p class="muted">Made by Open Food Facts for the FOODTURE project. Source: projects/foodture/list_campaign_needed_categories.pl in
<a href="https://github.com/openfoodfacts/openfoodfacts-server">openfoodfacts-server</a>.</p>
</main>
<script>
(function () {
	var country = document.getElementById('f-country');
	var text = document.getElementById('f-text');
	var statuses = document.querySelectorAll('.f-status');
	var count = document.getElementById('f-count');
	function apply() {
		var wanted = {};
		statuses.forEach(function (s) { wanted[s.value] = s.checked; });
		var c = country.value, t = text.value.trim().toLowerCase(), shown = 0;
		document.querySelectorAll('section.country').forEach(function (section) {
			var visible = 0;
			if (!c || section.dataset.country === c) {
				section.querySelectorAll('tr.row').forEach(function (row) {
					var ok = wanted[row.dataset.status] && (!t || row.dataset.search.indexOf(t) >= 0);
					row.classList.toggle('hidden', !ok);
					if (ok) { visible++; }
				});
			}
			section.classList.toggle('hidden', visible === 0);
			shown += visible;
		});
		count.textContent = shown + ' categories shown';
		try { localStorage.setItem('foodture-country', c); } catch (e) {}
	}
	try { var saved = localStorage.getItem('foodture-country'); if (saved) { country.value = saved; } } catch (e) {}
	country.addEventListener('change', apply);
	text.addEventListener('input', apply);
	statuses.forEach(function (s) { s.addEventListener('change', apply); });
	apply();
})();
</script>
</body>
</html>
HTML

my $html_file = "$output_dir/index.html";
open(my $HTML, '>:encoding(UTF-8)', "$html_file.tmp") or die "Cannot write $html_file.tmp: $!\n";
print $HTML $html;
close $HTML;
rename("$html_file.tmp", $html_file) or die "Cannot rename $html_file.tmp: $!\n";

print STDERR scalar(@rows) . " rows written to $csv_file, $json_file and $html_file\n";
foreach my $country (sort grep {$_ ne ''} keys %summary) {
	my $s = $summary{$country};
	printf STDERR "%-20s %4d needed: %4d OK, %4d INCOMPLETE, %4d MISSING\n", $country, $s->{total}, $s->{OK} // 0,
		$s->{INCOMPLETE} // 0, $s->{MISSING} // 0;
}
printf STDERR "%-20s %4d needed: %4d OK, %4d INCOMPLETE, %4d MISSING\n", "All", $all->{total} // 0, $all->{OK} // 0,
	$all->{INCOMPLETE} // 0, $all->{MISSING} // 0;
