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

use JSON::MaybeXS;
use Text::CSV;
use POSIX ();
use Getopt::Long;
use File::Copy ();
use FindBin;

# Static web pages of the FOODTURE campaign, made from foodture_campaign.json (list_campaign_needed_categories.pl):
# - index.html: summary per country (sortable), with links to the country pages and to the campaign tools.
#   index.html?country=<cc> redirects to the page of the country.
# - <cc>.html: categories needed in one country (cc = country subdomain on openfoodfacts.org: at, be, uk...)
# - <cc>_ingredients.html: Taxonomy Wiz, unknown ingredients in the selected products of the country
#   (<cc>.html#ingredients redirects to it)
# - all.html: all countries on one page
# - data.js: data for the Scan Champion and Data Detective mini-sites
#   (https://github.com/openfoodfacts/smooth-app_assets, same format as their own data.js)
# - foodture_ingredients_by_country.csv and foodture_unknown_ingredients.csv: ingredients of the selected products
#   (Taxonomy Wiz mission)
# The pages are written in --output-dir, next to foodture_campaign.json, foodture_campaign.csv.
#
# --baseline: coverage of each country at the start of the campaign, for the progress shown by the mini-sites
# (start_baseline_pct, delta_pct). Created with the current coverage if the file does not exist.
#
# --history: metrics of each country for each day (foodture_history.csv), completed (or updated for the same date)
# at each run, for the progress charts of the pages. Kept in the output directory.
#
# --partners: organizations that relay the campaign in a country (associations, communities...), shown on the page of
# the country. JSON file: {"si": [{"name": "...", "url": "https://...", "logo": "https://..."}], ...}, keys are the
# country codes of the pages. Read from partners.json in the output directory if the option is not given.

my $usage
	= "build_campaign_site.pl --json <foodture_campaign.json> --output-dir <dir> [--baseline <file.json>] [--history <file.csv>] [--partners <file.json>]\n";

my ($json_file, $output_dir, $baseline_file, $history_file, $partners_file);
GetOptions(
	"json=s" => \$json_file,
	"output-dir=s" => \$output_dir,
	"baseline=s" => \$baseline_file,
	"history=s" => \$history_file,
	"partners=s" => \$partners_file
) or die $usage;
(defined $json_file and defined $output_dir) or die $usage;
-d $output_dir or die "Output directory $output_dir does not exist\n";
$baseline_file //= "$output_dir/scan_champion_baseline.json";
$history_file //= "$output_dir/foodture_history.csv";
$partners_file //= "$output_dir/partners.json";

# Partners of each country: $partners{cc} = [{name, url, logo}]
my %partners = ();
if (-e $partners_file) {
	open(my $PARTNERS, '<:raw', $partners_file) or die "Cannot read $partners_file: $!\n";
	%partners = %{JSON::MaybeXS->new(utf8 => 1)->decode(
			do {local $/; <$PARTNERS>}
		)
	};
	close $PARTNERS;
}
# Contact for organizations that want to relay the campaign
my $partners_contact = 'contact@openfoodfacts.org';

# Photos of Open Food Facts members scanning products in shops (from the blog post of the campaign), shown in the
# "How you can help" box: copied from assets/ next to this script to the output directory
my @citizen_photos = map {"citizen_scan_$_.jpg"} 1 .. 4;
foreach my $photo (@citizen_photos) {
	File::Copy::copy("$FindBin::Bin/assets/$photo", "$output_dir/$photo")
		or warn "Cannot copy $FindBin::Bin/assets/$photo to $output_dir: $!\n";
}

open(my $IN, '<:raw', $json_file) or die "Cannot read $json_file: $!\n";
my $data_ref = JSON::MaybeXS->new(utf8 => 1)->decode(
	do {local $/; <$IN>}
);
close $IN;

# Campaign tools (see https://blog.openfoodfacts.org/en/news/new-citizen-science-initiatives)
my $blog_url = "https://blog.openfoodfacts.org/en/news/new-citizen-science-initiatives";
my $scan_champion_url = "https://openfoodfacts.github.io/smooth-app_assets/photos-for-impact/index.html";
my $data_detective_url = "https://openfoodfacts.github.io/smooth-app_assets/data-detective/";
my $efsa_url = "https://www.efsa.europa.eu/en/data/food-consumption-data";
# the Scan Champion list uses language codes for some countries
my %scan_champion_cc = (cz => 'cs', gr => 'el');
# countries of the Scan Champion and Data Detective lists
my %scan_champion_countries = map {$_ => 1}
	qw/at be bg ca hr cy cs dk ee fi fr de el hu ie it lv lt lu mt me nl no pl pt ro rs sk si es se ch uk/;

my @rows = @{$data_ref->{rows}};
my $dump_date = $data_ref->{dump_date} // '';
my $generated = $data_ref->{generated} // '';
my $years_text = join(" and ", sort @{$data_ref->{scans_years} // []});

# Countries: name -> {country_code, languages}
my %countries = %{$data_ref->{countries} // {}};
foreach my $row_ref (@rows) {
	my $country_ref = $countries{$row_ref->{country}} //= {};
	$country_ref->{country_code} //= $row_ref->{country_code};
	if (not defined $country_ref->{languages}) {
		# older JSON files without the countries: languages of the local names and of the untranslated names
		my %languages = map {$_ => 1} (($row_ref->{off_category_names_local} // '') =~ /(?:^|; )(\w\w):/g),
			split(/,/, $row_ref->{off_category_untranslated_languages} // '');
		$country_ref->{languages_seen}{$_} = 1 for keys %languages;
	}
}
foreach my $country_ref (values %countries) {
	$country_ref->{languages} //= [sort keys %{$country_ref->{languages_seen} // {}}];
}

# Pairs of the dataset: needed by FOODTURE, or chosen for the other countries (Iceland, Canada)
foreach my $row_ref (@rows) {
	$row_ref->{dataset_needed} //= $row_ref->{foodture_needed};
	$countries{$row_ref->{country}}{foodture_country} ||= $row_ref->{foodture_needed} ? 1 : 0;
}

# Summary per country, and for all the FOODTURE countries ('')
my %summary = ();
foreach my $row_ref (@rows) {
	next if not $row_ref->{dataset_needed};
	for my $country ($row_ref->{country}, ($row_ref->{foodture_needed} ? '' : ())) {
		$summary{$country}{$row_ref->{status}}++;
		$summary{$country}{total}++;
	}
}

# FOODTURE computes the environmental impact of the products from their ingredients: it needs at least 95% of the
# estimated quantity of the ingredients recognized
my $min_recognized_quantity_pct = 95;

sub quantity_ok ($pct) {
	return ((defined $pct) and ($pct ne '') and ($pct >= $min_recognized_quantity_pct)) ? 1 : 0;
}

# Categories whose selected product (the most scanned complete product) has at least 95% of the estimated quantity of
# its ingredients recognized ("Complete + 95% ingredients"), and Full Coverage: their share of the needed categories
foreach my $row_ref (@rows) {
	next if (not $row_ref->{dataset_needed}) or ($row_ref->{status} ne 'OK');
	next if not quantity_ok($row_ref->{recognized_quantity_pct});
	$summary{$_}{READY}++ for ($row_ref->{country}, ($row_ref->{foodture_needed} ? '' : ()));
}

sub full_pct ($s) {
	return $s->{total} ? 100 * ($s->{READY} // 0) / $s->{total} : 0;
}

# Ingredients of the selected products, per country and for all the FOODTURE countries ('').
# Each product is counted once, even if it is selected for several categories.
# $ingredients{country}{products}{code} = {product info}, $ingredients{country}{unknown}{ingredient tag} = [product codes]
my %ingredients = ();
foreach my $row_ref (@rows) {
	next
		if (not $row_ref->{dataset_needed})
		or ($row_ref->{status} ne 'OK')
		or (($row_ref->{ingredients_n} // '') eq '');
	my $unknown_ref = $row_ref->{unknown_ingredients};
	my @unknown = grep {$_ ne ''} ref $unknown_ref eq 'ARRAY' ? @$unknown_ref : split(/,/, $unknown_ref // '');
	for my $country ($row_ref->{country}, ($row_ref->{foodture_needed} ? '' : ())) {
		my $i = $ingredients{$country} //= {products => {}, ingredients => 0, unknown_n => 0, unknown => {}};
		my $code = $row_ref->{code};
		if (defined $i->{products}{$code}) {
			push @{$i->{products}{$code}{categories}}, $row_ref->{off_category_name_en};
			next;
		}
		$i->{products}{$code} = {
			code => $code,
			name => $row_ref->{product_name},
			brands => $row_ref->{brands},
			url => $row_ref->{product_url},
			ingredients_lc => $row_ref->{ingredients_lc},
			ingredients_n => $row_ref->{ingredients_n} || 0,
			unknown_n => $row_ref->{unknown_ingredients_n} || 0,
			unknown => \@unknown,
			recognized_quantity_pct => $row_ref->{recognized_quantity_pct},
			categories => [$row_ref->{off_category_name_en}],
		};
		$i->{quantity_ok}++ if quantity_ok($row_ref->{recognized_quantity_pct});
		$i->{ingredients} += $row_ref->{ingredients_n} || 0;
		$i->{unknown_n} += $row_ref->{unknown_ingredients_n} || 0;
		push @{$i->{unknown}{$_} //= []}, $code for @unknown;
	}
}

# number of selected products with at least 95% of the quantity of ingredients recognized, and of selected products
sub quantity_ok_counts ($country) {
	my $i = $ingredients{$country} // {};
	return ($i->{quantity_ok} // 0, scalar(keys %{$i->{products} // {}}));
}

sub known_pct ($country) {
	my $i = $ingredients{$country};
	return if (not defined $i) or (not $i->{ingredients});
	return 100 * ($i->{ingredients} - $i->{unknown_n}) / $i->{ingredients};
}

my @country_names = sort grep {$_ ne ''} keys %summary;
my @foodture_names = grep {$countries{$_}{foodture_country}} @country_names;
my @other_names = grep {not $countries{$_}{foodture_country}} @country_names;

sub h ($text) {
	$text //= '';
	$text =~ s/&/&amp;/g;
	$text =~ s/</&lt;/g;
	$text =~ s/>/&gt;/g;
	$text =~ s/"/&quot;/g;
	return $text;
}

sub page_file ($country) {
	return $countries{$country}{country_code} . ".html";
}

# Taxonomy Wiz page of a country: unknown ingredients in the selected products
sub ingredients_page_file ($country) {
	return $countries{$country}{country_code} . "_ingredients.html";
}

sub pct ($s) {
	return $s->{total} ? 100 * ($s->{OK} // 0) / $s->{total} : 0;
}

sub write_file ($file, $content) {
	my $path = "$output_dir/$file";
	open(my $OUT, '>:encoding(UTF-8)', "$path.tmp") or die "Cannot write $path.tmp: $!\n";
	print $OUT $content;
	close $OUT;
	rename("$path.tmp", $path) or die "Cannot rename $path.tmp: $!\n";
	return;
}

my $style = <<'CSS';
:root { --bg: #fff; --fg: #1f2328; --muted: #57606a; --line: #d0d7de; --head: #f6f8fa;
	--missing: #b42318; --missing-bg: #fde8e7; --incomplete: #9a6700; --incomplete-bg: #fff4d6; --ok: #1a7f37; --ok-bg: #e6f4ea; --link: #0969da;
	--s1: #2a78d6; --s2: #eb6834; --s3: #1baf7a; }
:root[data-theme=dark] { --bg: #0d1117; --fg: #e6edf3; --muted: #9198a1; --line: #30363d; --head: #161b22;
	--missing: #ff8b80; --missing-bg: #3d1614; --incomplete: #e3b341; --incomplete-bg: #33270b; --ok: #56d364; --ok-bg: #12301b; --link: #4493f8;
	--s1: #3987e5; --s2: #d95926; --s3: #199e70; }
body { margin: 0; padding: 0 16px 48px; background: var(--bg); color: var(--fg); font: 15px/1.45 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; }
main { max-width: 1200px; margin: 0 auto; }
nav.top { padding: 10px 0; border-bottom: 1px solid var(--line); display: flex; flex-wrap: wrap; gap: 6px 16px; align-items: center; justify-content: space-between; }
nav.top .home { font-weight: 600; text-decoration: none; }
button.theme { font: inherit; color: var(--fg); background: var(--head); border: 1px solid var(--line); border-radius: 16px; padding: 4px 12px; cursor: pointer; }
.note.other { border-left: 4px solid var(--incomplete); }
footer { margin-top: 40px; padding-top: 16px; border-top: 1px solid var(--line); text-align: center; }
.sponsors { display: flex; flex-wrap: wrap; gap: 16px; justify-content: center; align-items: center; margin: 8px 0 16px; }
.sponsors a { display: inline-flex; align-items: center; background: #fff; border-radius: 8px; padding: 8px 12px; }
.sponsors img { height: 48px; width: auto; }
h1 { font-size: 1.6rem; margin: 20px 0 8px; }
h2 { font-size: 1.25rem; margin: 32px 0 4px; padding-top: 8px; border-top: 2px solid var(--line); }
a { color: var(--link); }
.muted, small { color: var(--muted); }
.note { background: var(--head); border: 1px solid var(--line); border-radius: 6px; padding: 8px 12px; margin: 12px 0; }
.tools { display: flex; flex-wrap: wrap; gap: 8px; margin: 12px 0; }
.tools a { display: inline-block; padding: 6px 12px; border: 1px solid var(--line); border-radius: 16px; text-decoration: none; background: var(--head); }
.filters { position: sticky; top: 0; z-index: 1; background: var(--bg); padding: 10px 0; border-bottom: 1px solid var(--line); display: flex; flex-wrap: wrap; gap: 8px 16px; align-items: center; }
.filters label { white-space: nowrap; }
select, input[type=search] { font: inherit; padding: 4px 6px; color: var(--fg); background: var(--bg); border: 1px solid var(--line); border-radius: 4px; }
.table-wrap { overflow-x: auto; }
table { border-collapse: collapse; width: 100%; margin: 8px 0; }
th, td { border-bottom: 1px solid var(--line); padding: 6px 8px; text-align: left; vertical-align: top; }
th { background: var(--head); font-weight: 600; }
.badge { display: inline-block; padding: 1px 8px; border-radius: 10px; font-size: 0.85em; font-weight: 600; white-space: nowrap; }
.MISSING { color: var(--missing); background: var(--missing-bg); }
.INCOMPLETE { color: var(--incomplete); background: var(--incomplete-bg); }
.OK { color: var(--ok); background: var(--ok-bg); }
.cat { font-weight: 600; }
.local { font-style: italic; }
.summary td, .summary th { text-align: right; white-space: nowrap; }
.summary td:first-child, .summary th:first-child, .summary td.left { text-align: left; }
.summary th[data-sort] { cursor: pointer; user-select: none; }
.summary thead th { white-space: normal; vertical-align: bottom; line-height: 1.25; }
.summary thead .badge { white-space: normal; }
.summary thead tr:last-child th[title] { text-decoration: underline dotted var(--muted); text-underline-offset: 3px; }
.summary .bar { width: 44px; }
.summary th, .summary td { padding: 6px 5px; }
.summary tr.groups th { text-align: left; font-weight: 600; background: var(--bg); border-bottom: 2px solid var(--line); }
.summary .quality { border-left: 2px solid var(--line); }
.summary th[data-sort]::after { content: " \2195"; color: var(--muted); }
.summary th[aria-sort=ascending]::after { content: " \2191"; color: var(--fg); }
.summary th[aria-sort=descending]::after { content: " \2193"; color: var(--fg); }
.bar { display: inline-block; width: 60px; height: 8px; background: var(--missing-bg); border-radius: 4px; vertical-align: middle; margin-left: 6px; overflow: hidden; }
.bar span { display: block; height: 100%; background: var(--ok); }
.hidden { display: none; }
figure.chart { margin: 8px 0 16px; position: relative; max-width: 820px; }
figure.chart svg { width: 100%; height: auto; display: block; overflow: visible; }
figure.chart .grid { stroke: var(--line); stroke-width: 1; }
figure.chart .axis { fill: var(--muted); font-size: 11px; }
figure.chart .series { fill: none; stroke-width: 2; stroke-linejoin: round; stroke-linecap: round; }
figure.chart .label { font-size: 12px; fill: var(--fg); }
figure.chart .cross { stroke: var(--muted); stroke-width: 1; }
.legend { display: flex; flex-wrap: wrap; gap: 4px 16px; font-size: 0.9em; color: var(--muted); margin: 4px 0; }
.legend i { display: inline-block; width: 14px; height: 3px; border-radius: 2px; vertical-align: middle; margin-right: 6px; }
.tooltip { position: absolute; pointer-events: none; background: var(--bg); color: var(--fg); border: 1px solid var(--line);
	border-radius: 6px; padding: 6px 8px; font-size: 0.85em; box-shadow: 0 2px 8px rgba(0,0,0,.15); white-space: nowrap; }
details.table-view summary { cursor: pointer; color: var(--link); font-size: 0.9em; }
.help { border: 2px solid var(--ok); border-radius: 8px; padding: 12px 16px; margin: 16px 0; background: var(--ok-bg); }
.help h2 { border: none; margin: 0 0 8px; padding: 0; }
.help ol { margin: 8px 0; padding-left: 22px; }
.help li { margin: 4px 0; }
.help .apps { display: flex; flex-wrap: wrap; gap: 8px; margin: 8px 0 0; }
.help .apps a, .help .cta { display: inline-block; padding: 6px 12px; border-radius: 16px; text-decoration: none; background: var(--bg); border: 1px solid var(--line); }
.help .cta { background: var(--ok); color: var(--bg); border-color: var(--ok); font-weight: 600; }
.partners { margin: 16px 0; }
.partners .sponsors { justify-content: flex-start; }
.partners .name { font-weight: 600; text-decoration: none; padding: 8px 12px; }
.advanced { margin-top: 40px; }
.help .photos { display: flex; gap: 8px; margin: 4px 0 12px; }
.help .photos img { flex: 1 1 0; min-width: 0; max-width: 260px; aspect-ratio: 345 / 302; object-fit: cover; border-radius: 6px; }
@media (max-width: 700px) { .summary tr.groups { display: none; } figure.chart { overflow-x: auto; } figure.chart svg { min-width: 540px; }
	.details-col { display: none; } .summary .wide { display: none; }
	.filters { position: static; }
	table.cards, table.cards tbody, table.cards tr, table.cards td { display: block; }
	table.cards tr:not(.row) { display: none; }
	table.cards tr.row { border-bottom: 1px solid var(--line); padding: 8px 0; }
	table.cards td { border: none; padding: 2px 0; }
	table.cards td.counts { font-size: 0.9em; }
	table.cards td.counts br.sep { display: none; }
	table.cards td.counts br.sep + span::before { content: " · "; } }
CSS

# Light theme by default, dark theme if chosen with the button (remembered in localStorage)
my $theme_head_script = <<'HTML';
<script>
try { if (localStorage.getItem('foodture-theme') === 'dark') { document.documentElement.dataset.theme = 'dark'; } } catch (e) {}
</script>
HTML

my $theme_script = <<'HTML';
<script>
(function () {
	var button = document.getElementById('theme');
	function label() { button.textContent = document.documentElement.dataset.theme === 'dark' ? '☀️ Light mode' : '🌙 Dark mode'; }
	button.addEventListener('click', function () {
		var dark = document.documentElement.dataset.theme !== 'dark';
		if (dark) { document.documentElement.dataset.theme = 'dark'; } else { delete document.documentElement.dataset.theme; }
		try { localStorage.setItem('foodture-theme', dark ? 'dark' : 'light'); } catch (e) {}
		label();
	});
	label();
})();
</script>
HTML

my $footer = <<'HTML';
<footer>
<div class="muted">Project supported by:</div>
<div class="sponsors">
<a href="https://www.fondationdefrance.org/en" title="Fondation de France"><img src="https://thumb.wikimedia.org/wikipedia/fr/thumb/d/d2/Fondation_de_France.svg/langfr-330px-Fondation_de_France.svg.png" alt="Fondation de France"></a>
<a href="https://foodture-project.eu/" title="FOODTURE project"><img src="https://foodture-project.eu/wp-content/uploads/2025/05/FOODTURE-LOGO_Color-scaled.png" alt="FOODTURE project"></a>
</div>
<p>🔬 Discover our citizen science research: <a href="https://world.openfoodfacts.org/citizen-science">Citizen science at Open Food Facts</a></p>
<p class="muted"><small>Made by <a href="https://world.openfoodfacts.org/">Open Food Facts</a>.
Source: projects/foodture/list_campaign_needed_categories.pl and build_campaign_site.pl in
<a href="https://github.com/openfoodfacts/openfoodfacts-server">openfoodfacts-server</a>.</small></p>
</footer>
HTML

# Progress over time: history of the metrics of each country (one line per date and country)
my @history_metrics = qw/needed complete incomplete_only no_product coverage_pct complete_95 full_coverage_pct
	selected_products known_ingredients_pct quantity_ok quantity_ok_pct/;
my %history = ();    # $history{country}{date} = {metric => value}
if (-e $history_file) {
	open(my $HISTORY, '<:encoding(UTF-8)', $history_file) or die "Cannot read $history_file: $!\n";
	my $csv = Text::CSV->new({binary => 1});
	my $header_ref = $csv->getline($HISTORY);
	$csv->column_names(@$header_ref);
	while (my $line_ref = $csv->getline_hr($HISTORY)) {
		$history{$line_ref->{country}}{$line_ref->{date}} = $line_ref;
	}
	close $HISTORY;
}
foreach my $country ((grep {$_ ne ''} keys %summary), '') {
	my $s = $summary{$country};
	my ($ok, $products) = quantity_ok_counts($country);
	my $known = known_pct($country);
	$history{$country eq '' ? 'All FOODTURE countries' : $country}{$dump_date} = {
		needed => $s->{total} // 0,
		complete => $s->{OK} // 0,
		incomplete_only => $s->{INCOMPLETE} // 0,
		no_product => $s->{MISSING} // 0,
		coverage_pct => sprintf("%.1f", pct($s)),
		complete_95 => $s->{READY} // 0,
		full_coverage_pct => sprintf("%.1f", full_pct($s)),
		selected_products => $products,
		known_ingredients_pct => defined $known ? sprintf("%.1f", $known) : '',
		quantity_ok => $ok,
		quantity_ok_pct => $products ? sprintf("%.1f", 100 * $ok / $products) : '',
	};
}
{
	my $csv = Text::CSV->new({binary => 1, eol => "\n"});
	open(my $HISTORY, '>:encoding(UTF-8)', "$history_file.tmp") or die "Cannot write $history_file.tmp: $!\n";
	$csv->print($HISTORY, ['date', 'country', @history_metrics]);
	foreach my $country (sort keys %history) {
		foreach my $date (sort keys %{$history{$country}}) {
			$csv->print($HISTORY, [$date, $country, map {$history{$country}{$date}{$_} // ''} @history_metrics]);
		}
	}
	close $HISTORY;
	rename("$history_file.tmp", $history_file) or die "Cannot rename $history_file.tmp: $!\n";
}

# Series of the progress charts: metric, name, color
my @chart_series = (
	['coverage_pct', 'Data Coverage: categories with a complete product', 'var(--s1)'],
	['full_coverage_pct', 'Full Coverage: complete product with ≥ 95% of ingredients recognized', 'var(--s2)'],
	['known_ingredients_pct', 'Recognized ingredients in the selected products', 'var(--s3)'],
);

sub days_since_epoch ($date) {
	my ($y, $m, $d) = split(/-/, $date);
	return POSIX::mktime(0, 0, 12, $d, $m - 1, $y - 1900) / 86400;
}

# Line chart (SVG) of the progress of a country, with a table view
sub progress_chart ($country) {
	my $country_history = $history{$country eq '' ? 'All FOODTURE countries' : $country} // {};
	my @dates = sort keys %$country_history;
	return '' if not @dates;
	my ($width, $height, $left, $right, $top, $bottom) = (720, 220, 36, 70, 12, 26);
	my ($x0, $x1) = (days_since_epoch($dates[0]), days_since_epoch($dates[-1]));
	my $x = sub ($date) {
		return $x1 > $x0 ? $left + ($width - $left - $right) * (days_since_epoch($date) - $x0) / ($x1 - $x0) : $left;
	};
	my $y = sub ($value) {return $top + ($height - $top - $bottom) * (1 - $value / 100)};

	my $svg = qq{<svg viewBox="0 0 $width $height" role="img" aria-label="Progress over time">\n};
	foreach my $tick (0, 25, 50, 75, 100) {
		my $ty = $y->($tick);
		$svg .= sprintf(
			qq{<line class="grid" x1="%d" x2="%d" y1="%.1f" y2="%.1f"/><text class="axis" x="%d" y="%.1f" text-anchor="end">%d%%</text>\n},
			$left, $width - $right,
			$ty, $ty, $left - 6, $ty + 4, $tick
		);
	}
	my @date_ticks = @dates > 1 ? ($dates[0], $dates[-1]) : ($dates[0]);
	foreach my $date (@date_ticks) {
		$svg .= sprintf(
			qq{<text class="axis" x="%.1f" y="%d" text-anchor="%s">%s</text>\n},
			$x->($date),
			$height - 6,
			($date eq $dates[0]) ? 'start' : 'end',
			h($date)
		);
	}
	my @labels = ();
	foreach my $series_ref (@chart_series) {
		my ($metric, $name, $color) = @$series_ref;
		my @points = map {[$x->($_), $y->($country_history->{$_}{$metric})]}
			grep {($country_history->{$_}{$metric} // '') ne ''} @dates;
		next if not @points;
		$svg .= sprintf(qq{<polyline class="series" style="stroke:%s" points="%s"/>\n},
			$color, join(" ", map {sprintf("%.1f,%.1f", @$_)} @points))
			if @points > 1;
		# markers: all points if there are few, otherwise the last one
		foreach my $point_ref (@points > 31 ? ($points[-1]) : @points) {
			$svg .= sprintf(qq{<circle cx="%.1f" cy="%.1f" r="4" style="fill:%s;stroke:var(--bg);stroke-width:2"/>\n},
				@$point_ref, $color);
		}
		my $last = $country_history->{(grep {($country_history->{$_}{$metric} // '') ne ''} @dates)[-1]}{$metric};
		push @labels, [$points[-1][1], sprintf("%.0f%%", $last), $color];
	}
	# direct labels at the end of the lines, at least 14px apart
	@labels = sort {$a->[0] <=> $b->[0]} @labels;
	for my $i (1 .. $#labels) {
		$labels[$i][0] = $labels[$i - 1][0] + 14 if $labels[$i][0] < $labels[$i - 1][0] + 14;
	}
	foreach my $label_ref (@labels) {
		$svg .= sprintf(
			qq{<text class="label" x="%d" y="%.1f"><tspan style="fill:%s">●</tspan> %s</text>\n},
			$width - $right + 8,
			$label_ref->[0] + 4,
			$label_ref->[2], $label_ref->[1]
		);
	}
	$svg .= qq{<line class="cross hidden" y1="$top" y2="} . ($height - $bottom) . qq{"/>\n</svg>\n};

	my $legend
		= qq{<div class="legend">}
		. join("", map {qq{<span><i style="background:$_->[2]"></i>} . h($_->[1]) . "</span>"} @chart_series)
		. "</div>\n";
	my @points_data = map {
		my $date = $_;
		{date => $date, x => $x->($date), values => [map {$country_history->{$date}{$_->[0]} // ''} @chart_series]}
	} @dates;
	my $data_json = h(JSON::MaybeXS->new(canonical => 1)->encode({width => $width, points => \@points_data}));

	my $table
		= qq{<details class="table-view"><summary>Show the data as a table</summary><div class="table-wrap"><table>\n<tr><th>Date</th>}
		. join("", map {"<th>" . h($_->[1]) . "</th>"} @chart_series)
		. "<th>Needed</th><th>Complete</th><th>Incomplete only</th><th>No product</th></tr>\n";
	foreach my $date (reverse @dates) {
		my $d = $country_history->{$date};
		$table
			.= "<tr><td>"
			. h($date) . "</td>"
			. join("",
			map {"<td>" . (($d->{$_->[0]} // '') ne '' ? h($d->{$_->[0]}) . "%" : '') . "</td>"} @chart_series)
			. join("", map {"<td>" . h($d->{$_} // '') . "</td>"} qw/needed complete incomplete_only no_product/)
			. "</tr>\n";
	}
	$table .= "</table></div></details>\n";

	return
		qq{<h2 id="progress">Progress</h2>\n$legend<figure class="chart" data-chart="$data_json">\n$svg</figure>\n$table};
}

# Crosshair and tooltip on the progress charts
my $chart_script = <<'HTML';
<script>
document.querySelectorAll('figure.chart').forEach(function (figure) {
	var data = JSON.parse(figure.dataset.chart);
	var svg = figure.querySelector('svg');
	var cross = svg.querySelector('.cross');
	var names = Array.prototype.map.call(figure.previousElementSibling.querySelectorAll('span'), function (s) { return s.textContent; });
	var tip = document.createElement('div');
	tip.className = 'tooltip hidden';
	figure.appendChild(tip);
	svg.addEventListener('mousemove', function (e) {
		var box = svg.getBoundingClientRect();
		var x = (e.clientX - box.left) * data.width / box.width;
		var best = data.points[0];
		data.points.forEach(function (p) { if (Math.abs(p.x - x) < Math.abs(best.x - x)) { best = p; } });
		cross.setAttribute('x1', best.x); cross.setAttribute('x2', best.x);
		cross.classList.remove('hidden');
		tip.innerHTML = '';
		var title = document.createElement('b'); title.textContent = best.date; tip.appendChild(title);
		best.values.forEach(function (v, i) {
			if (v === '') { return; }
			var line = document.createElement('div'); line.textContent = names[i] + ': ' + v + '%'; tip.appendChild(line);
		});
		tip.classList.remove('hidden');
		var left = best.x * box.width / data.width + 12;
		if (left + tip.offsetWidth > box.width) { left = best.x * box.width / data.width - tip.offsetWidth - 12; }
		tip.style.left = Math.max(0, left) + 'px';
		tip.style.top = '8px';
	});
	svg.addEventListener('mouseleave', function () { cross.classList.add('hidden'); tip.classList.add('hidden'); });
});
</script>
HTML

sub page ($title, $body, $script = '') {
	return <<HTML;
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>@{[h($title)]}</title>
$theme_head_script<style>
$style</style>
</head>
<body>
<main>
<nav class="top"><a class="home" href="index.html">🥫 FOODTURE campaign: all countries</a><button type="button" class="theme" id="theme">🌙 Dark mode</button></nav>
$body
$footer
</main>
$theme_script$chart_script$script
</body>
</html>
HTML
}

# Last update, under the title of the pages
my $updated_line = qq{<p class="muted"><small>Updated every day · last update: $dump_date</small></p>\n};

# Details on the data, at the bottom of the pages
my $data_note = <<HTML;
<section class="about-data">
<h2 id="about-data">About the data</h2>
<p>The pages are updated every day from the Open Food Facts database (products of $dump_date, pages generated $generated).
For each category, the selected product is the complete product of the category that was scanned by the most people in
the country (in $years_text).</p>
<p>The counts use the latest version of the Open Food Facts categories: for a few days, the category pages on the
Open Food Facts website can show fewer products.</p>
<p>Download the data for all countries: <a href="foodture_campaign.csv">CSV</a> · <a href="foodture_campaign.json">JSON</a></p>
</section>
HTML

sub country_select ($current) {
	my $html = qq{<label>Country <select id="f-country">\n<option value="index.html">Summary</option>\n};
	$html .= qq{<option value="all.html"} . ($current eq '*' ? ' selected' : '') . qq{>All countries</option>\n};
	foreach my $group (["FOODTURE countries", \@foodture_names], ["Other countries (not in FOODTURE)", \@other_names]) {
		next if not @{$group->[1]};
		$html .= qq{<optgroup label="$group->[0]">\n};
		foreach my $country (@{$group->[1]}) {
			$html
				.= qq{<option value="}
				. page_file($country) . qq{"}
				. ($country eq $current ? ' selected' : '') . ">"
				. h($country)
				. "</option>\n";
		}
		$html .= "</optgroup>\n";
	}
	return $html . "</select></label>\n";
}

sub tools_links ($country) {
	my $html = qq{<div class="tools">\n};
	my $cc = defined $country ? $countries{$country}{country_code} : undef;
	my $tools_cc = defined $cc ? ($scan_champion_cc{$cc} // $cc) : undef;
	if ((not defined $tools_cc) or $scan_champion_countries{$tools_cc}) {
		my $param = defined $tools_cc ? "?country=$tools_cc" : '';
		$html .= qq{<a href="$scan_champion_url$param">🛒 Scan Champion: scan list for shops</a>\n}
			. qq{<a href="$data_detective_url$param">🕵️ Data Detective: complete products at home</a>\n};
	}
	$html .= qq{<a href="} . ingredients_page_file($country) . qq{">🧙 Taxonomy Wiz: unknown ingredients</a>\n}
		if defined $country;
	return $html . qq{<a href="$blog_url">📖 Missions and guide</a>\n</div>\n};
}

sub fmt_scans ($r) {
	return "country: " . ($r->{country_scans} // 0) . " · all countries: " . ($r->{global_scans} // 0);
}

sub country_table ($country, $heading) {
	my @country_rows = grep {$_->{country} eq $country} @rows;
	my $s = $summary{$country} // {};
	my $languages = join(", ", grep {$_ ne 'en'} @{$countries{$country}{languages} // []});
	my $html = '';
	$html .= qq{<h2 id="} . h($countries{$country}{country_code}) . qq{">} . h($country) . "</h2>\n" if $heading;
	$html .= sprintf(
		qq{<p class="muted">%d needed categories: %d with no product, %d with incomplete products only, %d with a complete product,
including %d with at least 95%% of the ingredients recognized (Full Coverage: %.0f%%).%s</p>\n},
		$s->{total} // 0,
		$s->{MISSING} // 0,
		$s->{INCOMPLETE} // 0,
		$s->{OK} // 0,
		$s->{READY} // 0,
		full_pct($s),
		$languages ne '' ? " Category names in English and " . h($languages) . "." : ''
	);
	$html
		.= qq{<div class="table-wrap"><table class="cards">\n<tr><th>Category</th><th>Status</th><th>Products in }
		. h($country)
		. qq{</th><th class="details-col">Selected product</th></tr>\n};
	foreach my $r (@country_rows) {
		my $search = lc(join(" ", $r->{off_category_name_en}, $r->{off_category_names_local}, $r->{foodex2_name}));
		my $category
			= qq{<a class="cat" href="} . h($r->{category_url}) . qq{">} . h($r->{off_category_name_en}) . "</a>";
		$category .= qq{<br><span class="local">} . h($r->{off_category_names_local}) . "</span>"
			if ($r->{off_category_names_local} // '') ne '';
		$category .= "<br><small>FoodEx2 " . h($r->{foodex2_code}) . ": " . h($r->{foodex2_name}) . "</small>";
		if (not $r->{foodture_needed}) {
			$category
				.= "<br><small>Not needed by FOODTURE: "
				. h(($r->{selection_rule} // '') ne '' ? $r->{selection_rule} : 'dataset only')
				. "</small>";
		}
		my $counts = sprintf(
			qq{<span>%d products</span><br class="sep"><span>%d complete</span><br class="sep"><span>%d incomplete with photos</span>},
			$r->{products},
			$r->{complete_products},
			$r->{incomplete_products_with_photos}
		);
		if (@{$r->{incomplete_products} // []}) {
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
		if (($r->{code} // '') ne '') {
			$product
				= qq{<a href="}
				. h($r->{product_url}) . qq{">}
				. h($r->{product_name} || $r->{code}) . "</a>"
				. (($r->{brands} // '') ne '' ? " – " . h($r->{brands}) : '')
				. "<br><small>"
				. h($r->{code})
				. "<br>scans $years_text: "
				. fmt_scans($r)
				. "</small>";
		}
		$html .= sprintf(
			qq{<tr class="row" data-status="%s" data-search="%s"><td>%s</td><td><span class="badge %s">%s</span></td><td class="counts">%s</td><td class="details-col">%s</td></tr>\n},
			$r->{status}, h($search), $category, $r->{status}, h($r->{status_label}),
			$counts, $product
		);
	}
	return $html . "</table></div>\n";
}

# Status filters, with the number of categories of each status
sub filters ($counts_ref) {
	my $html = '';
	foreach my $status (['MISSING', 'no product'], ['INCOMPLETE', 'incomplete only'], ['OK', 'complete']) {
		my ($code, $label) = @$status;
		$html
			.= qq{<label><input type="checkbox" class="f-status" value="$code" checked> <span class="badge $code">}
			. ($counts_ref->{$code} // 0)
			. " $label</span></label>\n";
	}
	return $html . <<'HTML';
<label><input type="search" id="f-text" placeholder="Search a category"></label>
<span id="f-count" class="muted"></span>
HTML
}

my $filters_script = <<'HTML';
<script>
(function () {
	var select = document.getElementById('f-country');
	select.addEventListener('change', function () { location.href = select.value; });
	var text = document.getElementById('f-text');
	var statuses = document.querySelectorAll('.f-status');
	var count = document.getElementById('f-count');
	function apply() {
		var wanted = {};
		statuses.forEach(function (s) { wanted[s.value] = s.checked; });
		var t = text.value.trim().toLowerCase(), shown = 0;
		document.querySelectorAll('section.country').forEach(function (section) {
			var visible = 0;
			section.querySelectorAll('tr.row').forEach(function (row) {
				var ok = wanted[row.dataset.status] && (!t || row.dataset.search.indexOf(t) >= 0);
				row.classList.toggle('hidden', !ok);
				if (ok) { visible++; }
			});
			section.classList.toggle('hidden', visible === 0);
			shown += visible;
		});
		count.textContent = shown + ' categories shown';
	}
	text.addEventListener('input', apply);
	statuses.forEach(function (s) { s.addEventListener('change', apply); });
	apply();
})();
</script>
HTML

my $foodture_about = <<HTML;
<p><a href="https://foodture-project.eu/">FOODTURE</a> is a European research project to build an open database of the
environmental impacts of the food products consumed in Europe.
The project needs, for each category of the foods most consumed
in each European country, one representative product with complete data on Open Food Facts: photos, ingredients and nutrition facts.
All the data is open and free for everyone to reuse.</p>
HTML

my $foodture_intro = <<HTML;
<p><a href="https://foodture-project.eu/">FOODTURE</a> is a European research project to build an open database of the
environmental impacts of the food products consumed in Europe.
The project needs, for each category of the foods most consumed
in each European country, one representative product with complete data on Open Food Facts: photos, ingredients and nutrition facts.
Categories with <span class="badge MISSING">no product</span> or with <span class="badge INCOMPLETE">incomplete products only</span>
are listed first. Please scan and photograph products of these categories in your pantry or in stores with the Open Food Facts app,
or complete existing products from their photos.</p>
HTML

my $efsa_note = <<HTML;
<p>The categories of each country are the foods most consumed in that country. The European Food Safety Authority (EFSA)
<a href="$efsa_url">Comprehensive European Food Consumption Database</a> gathers the national dietary surveys
of European countries, with foods classified in EFSA's FoodEx2 system. Each of the selected FoodEx2 categories corresponds
to one Open Food Facts category.</p>
HTML

sub other_intro ($plural) {
	my ($subject, $verb, $its) = $plural ? ("These countries", "are", "their") : ("This country", "is", "its");
	return <<HTML;
<p>$subject $verb not part of the <a href="https://foodture-project.eu/">FOODTURE</a> project. We want to build
representative food products sets for other countries too, so that other research projects can use them. Until there are
food consumption data for $its categories, they are chosen from the FOODTURE needs of other countries (see below).
Scanning and completing products of these categories is just as welcome!</p>
HTML
}

my %other_rules = (
	is =>
		"Iceland: the categories needed by FOODTURE in at least 2 of the 4 Nordic countries (Denmark, Finland, Norway, Sweden).",
	ca =>
		"Canada: the categories needed by FOODTURE in at least 9 of the 32 European countries (a common European food basket).",
);

sub other_rule ($country) {
	my $rule = $other_rules{$countries{$country}{country_code}}
		// "$country: categories chosen from the FOODTURE needs of other countries.";
	return "<p><b>How the categories are chosen.</b> " . h($rule) . "</p>\n";
}

my $taxonomy_wiz_instructions = <<'HTML';
<p>The ingredients analysis (allergens, additives, vegan and vegetarian, palm oil, NOVA, environmental impact...) needs
recognized ingredients. Here are the ingredients that Open Food Facts does not recognize in the selected products of the
country. For each one, check what kind of problem it is:</p>
<ul>
<li><b>Valid ingredient, in the language of the ingredients list</b>: it needs to be added to the
<a href="https://github.com/openfoodfacts/openfoodfacts-server/blob/main/taxonomies/food/ingredients.txt">ingredients taxonomy</a>
with a pull request on GitHub. If you do not know how to open a pull request, post the ingredient with its English
translation (e.g. "framboise (raspberry)") in the #ingredients channel on Slack.</li>
<li><b>Ingredient in another language</b> than its language prefix (e.g. "de:" followed by an ingredient not in German):
the ingredients list was probably entered in the wrong language field (e.g. Spanish ingredients in the field for the
Portuguese ingredients list). Open the products and move or correct their ingredients list. Products with many unknown
ingredients are often in this case.</li>
<li><b>Misspelled ingredient</b> (or text that is not an ingredient): open the products and correct their ingredients
list. If there are many errors, extract the ingredients again from the ingredients photo: automatic text recognition is
now much better.</li>
<li><b>A pattern</b> in unknown ingredients (a specific formulation, processing, label...): tell us in the #ingredients or
#foodture channels on the <a href="https://slack.openfoodfacts.org/">Open Food Facts Slack</a>.</li>
</ul>
<p>Ingredients added to the taxonomy and corrected products count as known on the next daily update.</p>
HTML

sub product_link ($product_ref) {
	return
		  qq{<a href="}
		. h($product_ref->{url}) . qq{">}
		. h($product_ref->{name} || $product_ref->{code}) . "</a>"
		. (($product_ref->{brands} // '') ne '' ? " – " . h($product_ref->{brands}) : '')
		. "<br><small>"
		. h($product_ref->{code})
		. "</small>";
}

sub ingredient_link ($tag) {
	return qq{<a href="https://world.openfoodfacts.org/facets/ingredients/} . h($tag) . qq{">} . h($tag) . "</a>";
}

sub recognized_quantity_badge ($product_ref) {
	my $pct = $product_ref->{recognized_quantity_pct};
	return qq{<span class="badge MISSING">no quantity estimate</span>} if (not defined $pct) or ($pct eq '');
	my $class = quantity_ok($pct) ? 'OK' : 'MISSING';
	return sprintf(qq{<span class="badge %s">%.1f%%</span>}, $class, $pct);
}

sub ingredients_section ($country) {
	my $i = $ingredients{$country};
	my $html = '';
	if ((not defined $i) or (not %{$i->{products}})) {
		return $html . "<p>No selected product yet.</p>\n";
	}
	my @products = values %{$i->{products}};
	my @unknown
		= sort {scalar(@{$i->{unknown}{$b}}) <=> scalar(@{$i->{unknown}{$a}}) or $a cmp $b} keys %{$i->{unknown}};
	$html .= sprintf(
		qq{<p class="note"><b>%d of the %d selected products have at least %d%% of the estimated quantity of their ingredients recognized</b>:
FOODTURE needs it to compute their environmental impact.<br>
%d ingredients: %.1f%% recognized, %d unknown (%d different).</p>\n},
		quantity_ok_counts($country), $min_recognized_quantity_pct, $i->{ingredients}, known_pct($country) // 0,
		$i->{unknown_n}, scalar(@unknown)
	);
	$html .= $taxonomy_wiz_instructions;
	return $html if not @unknown;

	# products with the most unknown ingredients
	my @worst
		= sort {$b->{unknown_n} <=> $a->{unknown_n} or $a->{code} cmp $b->{code}} grep {$_->{unknown_n}} @products;
	$html
		.= "<h3>Products with the most unknown ingredients</h3>\n"
		. qq{<p class="muted">Often an ingredients list in the wrong language, or badly recognized from the photo.</p>\n}
		. qq{<div class="table-wrap"><table class="cards">\n}
		. "<tr><th>Product</th><th>Unknown ingredients</th><th>Recognized quantity</th><th>Ingredients list language</th></tr>\n";
	foreach my $product_ref (@worst) {
		$html .= sprintf(
			qq{<tr class="row"><td>%s<br><small>%s</small></td><td><b>%d / %d</b><br><small>%s</small></td><td>%s</td><td>%s</td></tr>\n},
			product_link($product_ref), h(join(", ", @{$product_ref->{categories}})),
			$product_ref->{unknown_n}, $product_ref->{ingredients_n},
			join(", ", map {h($_)} @{$product_ref->{unknown}}), recognized_quantity_badge($product_ref),
			h($product_ref->{ingredients_lc})
		);
	}
	$html .= "</table></div>\n";

	# unknown ingredients in the most products
	my $cc = $countries{$country}{country_code};
	$html
		.= "<h3>Unknown ingredients in the most products</h3>\n"
		. qq{<p class="muted">Often a valid ingredient missing from the ingredients taxonomy.</p>\n}
		. qq{<div class="table-wrap"><table class="cards">\n}
		. "<tr><th>Unknown ingredient</th><th>Products</th></tr>\n";
	foreach my $tag (@unknown) {
		my $codes_ref = $i->{unknown}{$tag};
		$html .= sprintf(
			qq{<tr class="row"><td>%s</td><td><b>%d</b><br><small>%s</small></td></tr>\n},
			ingredient_link($tag),
			scalar(@$codes_ref),
			join(", ",
				map {qq{<a href="https://$cc.openfoodfacts.org/product/} . h($_) . qq{">} . h($_) . "</a>"} @$codes_ref)
		);
	}
	return $html . "</table></div>\n";
}

# One line about the ingredients of the selected products, on the country page, with a link to the Taxonomy Wiz page
sub ingredients_summary ($country) {
	my $known = known_pct($country);
	return '' if not defined $known;
	my ($ok, $products) = quantity_ok_counts($country);
	return sprintf(
		qq{<p>%.1f%% of the ingredients of the selected products are recognized, and %d of the %d selected products have at
least %d%% of their ingredients recognized. <a href="%s">See the unknown ingredients</a>.</p>\n},
		$known, $ok, $products, $min_recognized_quantity_pct, ingredients_page_file($country)
	);
}

# Old links to <cc>.html#ingredients (the ingredients were on the country page) open the Taxonomy Wiz page
sub ingredients_redirect_script ($country) {
	my $file = ingredients_page_file($country);
	return qq{<script>if (location.hash === '#ingredients') { location.replace('$file'); }</script>\n};
}

sub status_counts ($country) {
	my %counts = ();
	$counts{$_->{status}}++ for grep {$_->{country} eq $country} @rows;
	return \%counts;
}

# "How you can help" box at the top of the country pages, for people who do not know Open Food Facts
# (e.g. members of a partner organization)
my $app_links = <<'HTML';
<div class="apps">
<a href="https://play.google.com/store/apps/details?id=org.openfoodfacts.scanner">📱 Android app</a>
<a href="https://apps.apple.com/app/open-food-facts/id588797948">📱 iPhone app</a>
<a href="https://f-droid.org/packages/openfoodfacts.github.scrachx.openfood/">F-Droid</a>
</div>
HTML

my $need_help = <<HTML;
<h3>Do you need help?</h3>
<p>Write to us at <a href="mailto:$partners_contact">$partners_contact</a>, or
<a href="https://slack.openfoodfacts.org/">join our Slack</a> and ask your questions in the #foodture channel.</p>
HTML

# $country = '': summary page, for all the FOODTURE countries
sub how_to_help ($country) {
	my $s = $summary{$country} // {};
	my $todo = ($s->{MISSING} // 0) + ($s->{INCOMPLETE} // 0);
	my $index = $country eq '';
	my $cc = $index ? '' : $countries{$country}{country_code};
	my $tools_cc = $scan_champion_cc{$cc} // $cc;
	my $name = $index ? 'the FOODTURE countries' : h($country);
	my $html = qq{<section class="help">\n<h2>🙌 How you can help in 5 minutes</h2>\n<div class="photos">}
		. join("",
		map {qq{<img src="$_" alt="Open Food Facts volunteer scanning products in a shop" loading="lazy">}}
			@citizen_photos)
		. "</div>\n";
	if (not $todo) {
		return
			  $html
			. "<p>All the needed categories of $name have a complete product: thank you! You can still help by making sure their ingredients are recognized (see the advanced contributors section at the bottom of the page).</p>\n"
			. $need_help
			. "</section>\n";
	}
	$html
		.= sprintf(
		qq{<p><b>We still need %d products sold in %s.</b> One product per category is enough: you do not need to scan everything!</p>\n},
		$todo, $name);
	my $find_step = $index
		? qq{Open the page of your country in the list below: it lists the categories marked
<span class="badge MISSING">no product</span> or <span class="badge INCOMPLETE">incomplete only</span>.
Find a product of one of these categories at home or in a shop. Any brand is fine, ideally a common one.}
		: qq{Look at the list below for a category marked <span class="badge MISSING">no product</span> or
<span class="badge INCOMPLETE">incomplete only</span>, and find a product of that category at home or in a shop.
Any brand is fine, ideally a common one.};
	$html .= <<HTML;
<ol>
<li>Install the free Open Food Facts app (no account needed to start).</li>
<li>$find_step</li>
<li>Scan its barcode and take 3 photos: the front of the package, the ingredients list and the nutrition facts table.</li>
<li>Add the category of the product (the one from the list, e.g. "Sauerkrauts"), so that we can find it.
That's it: volunteers and AI extract the other data from the photos.</li>
</ol>
$app_links
HTML
	if ($index) {
		$html .= qq{<p><a class="cta" href="#countries">Find your country ↓</a>};
	}
	else {
		$html .= qq{<p><a class="cta" href="#categories">See the products we need ↓</a>};
		$html .= qq{ <a href="$scan_champion_url?country=$tools_cc">🛒 Shopping list to use on your phone</a>}
			if $scan_champion_countries{$tools_cc};
	}
	$html .= "</p>\n";
	return $html . $need_help . "</section>\n";
}

# Organizations that relay the campaign in the country, and how to become one
sub partners_section ($country) {
	my $cc = $countries{$country}{country_code};
	my @partners = @{$partners{$cc} // []};
	my $name = h($country);
	my $html = qq{<section class="partners" id="partners">\n};
	if (@partners) {
		$html .= "<h2>🤝 Partners in $name</h2>\n<p>These organizations relay the campaign. Thank you!</p>\n"
			. qq{<div class="sponsors">\n};
		foreach my $partner_ref (@partners) {
			my $content
				= ($partner_ref->{logo} // '') ne ''
				? qq{<img src="} . h($partner_ref->{logo}) . qq{" alt="} . h($partner_ref->{name}) . qq{">}
				: qq{<span class="name">} . h($partner_ref->{name}) . "</span>";
			$html
				.= qq{<a href="}
				. h($partner_ref->{url})
				. qq{" title="}
				. h($partner_ref->{name})
				. qq{">$content</a>\n};
		}
		$html .= "</div>\n";
	}
	$html .= qq{<p class="muted">Your association, community or school wants to help gather the food products of $name?
Share this page with your members, and write to <a href="mailto:$partners_contact">$partners_contact</a>
to be listed as a partner, with your logo and a link to your website.</p>\n};
	return $html . "</section>\n";
}

# Country pages
foreach my $country (@country_names) {
	my $foodture = $countries{$country}{foodture_country};
	my $body
		= "<h1>"
		. ($foodture ? "FOODTURE: products needed in " : "Representative products needed in ")
		. h($country)
		. "</h1>\n"
		. $updated_line
		. (
		  $foodture
		? $foodture_about
		: qq{<div class="note other">\n} . other_intro(0) . other_rule($country) . "</div>\n"
		)
		. how_to_help($country)
		. partners_section($country)
		. qq{<h2 id="categories">Products needed in }
		. h($country)
		. "</h2>\n"
		. qq{<div class="filters">\n}
		. country_select($country)
		. filters(status_counts($country))
		. "</div>\n"
		. qq{<section class="country">\n}
		. country_table($country, 0)
		. "</section>\n"
		. progress_chart($country)
		. qq{<div class="advanced">\n<h2>For advanced contributors</h2>\n}
		. qq{<p class="muted">You do not need this section to help: scanning and photographing products is the most useful contribution. }
		. qq{Other campaign tools, including Taxonomy Wiz: the ingredients that Open Food Facts does not recognize yet in the selected products.</p>\n}
		. ingredients_summary($country)
		. tools_links($country)
		. "</div>\n"
		. $data_note;
	write_file(
		page_file($country),
		page(
			($foodture ? "FOODTURE" : "Representative products") . ": products needed in $country",
			$body, $filters_script . ingredients_redirect_script($country)
		)
	);

	# Taxonomy Wiz page of the country
	my $ingredients_body
		= "<h1>🧙 Taxonomy Wiz: unknown ingredients in "
		. h($country)
		. "</h1>\n"
		. qq{<p><a href="}
		. page_file($country)
		. qq{">← Products needed in }
		. h($country)
		. "</a></p>\n"
		. ingredients_section($country)
		. $data_note;
	write_file(ingredients_page_file($country),
		page("Taxonomy Wiz: unknown ingredients in $country", $ingredients_body));
}

# All countries on one page
{
	my %counts = ();
	$counts{$_->{status}}++ for @rows;
	my $body
		= "<h1>FOODTURE: products needed in each country</h1>\n"
		. $updated_line
		. $foodture_intro
		. qq{<div class="filters">\n}
		. country_select('*')
		. filters(\%counts)
		. "</div>\n";
	foreach my $country (@foodture_names, @other_names) {
		$body .= qq{<section class="country">\n};
		$body .= qq{<div class="note other">} . other_rule($country) . "</div>\n"
			if not $countries{$country}{foodture_country};
		$body .= country_table($country, 1) . "</section>\n";
	}
	$body .= $data_note;
	write_file("all.html", page("FOODTURE: products needed in each country", $body, $filters_script));
}

# Summary page
sub bar_cell ($pct) {
	return sprintf(qq{<td data-value="%.3f">%.0f%%<span class="bar"><span style="width:%.0f%%"></span></span></td>},
		$pct, $pct, $pct);
}

sub summary_table ($id, $names_ref, $with_total) {
	my $html = <<HTML;
<div class="table-wrap"><table class="summary" id="$id">
<thead>
<tr class="groups"><th colspan="7" title="Mission Scan Champion: find, scan and photograph the products of the needed categories in stores, or complete existing products from their photos">🛒 Data gathering: scan and complete products</th><th colspan="3" class="quality" title="Mission Taxonomy Wiz: make sure that the ingredients of the selected products are recognized, so that FOODTURE can compute their environmental impact">🧙 Data quality: ingredients analysis</th></tr>
<tr><th data-sort="text" aria-sort="ascending" title="Click on a country to see its needed categories and their products">Country</th>
<th data-sort="num" class="wide" title="Number of food categories needed in this country: the foods most consumed in the country, according to the EFSA food consumption data">Needed<br>categories</th>
<th data-sort="num" title="Number of needed categories with no product sold in this country on Open Food Facts"><span class="badge MISSING">no product</span></th>
<th data-sort="num" title="Number of needed categories that only have incomplete products in this country (photos, ingredients or nutrition facts missing)"><span class="badge INCOMPLETE">incomplete<br>only</span></th>
<th data-sort="num" title="Number of needed categories with at least one complete product (photos, ingredients and nutrition facts) sold in this country"><span class="badge OK">complete</span></th>
<th data-sort="num" title="Share of the needed categories that have at least one complete product in this country">Data<br>Coverage</th>
<th class="wide" title="Scan Champion: the list of the categories to scan in stores in this country, to use on your phone">Scan list</th>
<th data-sort="num" class="wide quality" title="Share of the ingredients of the selected products (the most scanned complete product of each category) that are recognized by Open Food Facts">Known<br>ingredients</th>
<th data-sort="num" class="wide" title="Number of needed categories whose selected product has at least 95% of its ingredients recognized, by estimated quantity: FOODTURE needs this to compute the environmental impact">Complete +<br>95% ingredients</th>
<th data-sort="num" title="Share of the needed categories whose selected product is complete and has at least 95% of its ingredients recognized by estimated quantity: the categories that FOODTURE can use">Full<br>Coverage</th></tr>
</thead>
<tbody>
HTML
	foreach my $country (@$names_ref) {
		my $s = $summary{$country};
		my $cc = $countries{$country}{country_code};
		my $tools_cc = $scan_champion_cc{$cc} // $cc;
		my $known = known_pct($country);
		$html .= sprintf(
			qq{<tr><td data-value="%s"><a href="%s">%s</a></td><td class="wide">%d</td><td>%d</td><td>%d</td><td>%d</td>},
			h($country), page_file($country), h($country), $s->{total},
			$s->{MISSING} // 0,
			$s->{INCOMPLETE} // 0,
			$s->{OK} // 0
			)
			. bar_cell(pct($s))
			. qq{<td class="wide left">}
			. (
			$scan_champion_countries{$tools_cc}
			? qq{<a href="$scan_champion_url?country=$tools_cc" title="Scan Champion: scan list for shops">🛒 Open</a>}
			: ''
			)
			. "</td>"
			. sprintf(
			qq{<td class="wide quality" data-value="%.3f">%s</td><td class="wide">%d</td>},
			$known // -1,
			defined $known ? sprintf(qq{<a href="%s">%.1f%%</a>}, ingredients_page_file($country), $known) : '',
			$s->{READY} // 0
			)
			. bar_cell(full_pct($s))
			. "</tr>\n";
	}
	$html .= "</tbody>\n";
	if ($with_total) {
		my $all = $summary{''} // {};
		my $known = known_pct('');
		$html .= sprintf(
			qq{<tfoot><tr><th><a href="all.html">All FOODTURE countries</a></th><th class="wide">%d</th><th>%d</th><th>%d</th><th>%d</th><th>%.0f%%</th><th class="wide"></th>}
				. qq{<th class="wide quality">%s</th><th class="wide">%d</th><th>%.0f%%</th></tr></tfoot>\n},
			$all->{total} // 0,
			$all->{MISSING} // 0,
			$all->{INCOMPLETE} // 0,
			$all->{OK} // 0,
			pct($all),
			defined $known ? sprintf("%.1f%%", $known) : '',
			$all->{READY} // 0,
			full_pct($all)
		);
	}
	$html .= <<'HTML';
</table></div>
<p class="muted"><small><b>Data Coverage</b>: share of the needed categories with a complete product (photos, ingredients and
nutrition facts) sold in the country. <b>Known ingredients</b>: share of the ingredients of the selected products that are
recognized. <b>Complete + 95% ingredients</b>: categories whose selected product (the most scanned complete product) has
at least 95% of the estimated quantity of its ingredients recognized, which FOODTURE needs to compute the environmental
impact. <b>Full Coverage</b>: their share of the needed categories.</small></p>
HTML
	return $html;
}

{
	my $body
		= "<h1>FOODTURE: products needed in each country</h1>\n"
		. $updated_line
		. $foodture_about
		. how_to_help('')
		. qq{<h2 id="countries">FOODTURE countries</h2>\n}
		. qq{<p class="muted">Pick your country to see the products we need. Click on a column header to sort.</p>\n}
		. summary_table("summary-foodture", \@foodture_names, 1);
	if (@other_names) {
		$body
			.= "<h2>Other countries (not part of FOODTURE)</h2>\n"
			. qq{<div class="note other">\n}
			. other_intro(@other_names > 1)
			. join("", map {other_rule($_)} @other_names)
			. "</div>\n"
			. summary_table("summary-other", \@other_names, 0);
	}
	$body
		.= progress_chart('')
		. qq{<div class="advanced">\n<h2>Other ways to help</h2>\n}
		. qq{<p class="muted">The campaign tools and the guide of the missions: complete existing products from their photos, }
		. qq{or make sure their ingredients are recognized.</p>\n}
		. tools_links(undef)
		. "</div>\n"
		. $data_note
		. $efsa_note;
	my %pages = map {($countries{$_}{country_code} => page_file($_))} @country_names;
	# also accept the country codes of the Scan Champion list
	$pages{$scan_champion_cc{$_}} = $pages{$_} for grep {defined $pages{$_}} keys %scan_champion_cc;
	my $pages_json = JSON::MaybeXS->new(canonical => 1)->encode(\%pages);
	my $script = <<HTML;
<script>
(function () {
	// index.html?country=<cc> opens the page of the country
	var pages = $pages_json;
	var cc = (new URLSearchParams(location.search).get('country') || '').toLowerCase();
	if (pages[cc]) { location.replace(pages[cc] + location.hash); return; }
	document.querySelectorAll('table.summary').forEach(function (table) {
		var tbody = table.tBodies[0];
		var headers = table.tHead.rows[table.tHead.rows.length - 1].cells;
		function value(row, i, type) {
			var cell = row.cells[i];
			var v = cell.dataset.value !== undefined ? cell.dataset.value : cell.textContent.trim();
			return type === 'num' ? parseFloat(v) : v.toLowerCase();
		}
		Array.prototype.forEach.call(headers, function (th, i) {
			var type = th.dataset.sort;
			if (!type) { return; }
			th.tabIndex = 0;
			function sort() {
				var current = th.getAttribute('aria-sort');
				var asc = current === 'ascending' ? false : (current === 'descending' ? true : type === 'text');
				Array.prototype.forEach.call(headers, function (h) { h.removeAttribute('aria-sort'); });
				th.setAttribute('aria-sort', asc ? 'ascending' : 'descending');
				var rows = Array.prototype.slice.call(tbody.rows);
				rows.sort(function (a, b) {
					var x = value(a, i, type), y = value(b, i, type);
					var c = x < y ? -1 : x > y ? 1 : 0;
					if (c === 0) { return value(a, 0, 'text') < value(b, 0, 'text') ? -1 : 1; }
					return asc ? c : -c;
				});
				rows.forEach(function (r) { tbody.appendChild(r); });
			}
			th.addEventListener('click', sort);
			th.addEventListener('keydown', function (e) { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); sort(); } });
		});
	});
})();
</script>
HTML
	write_file("index.html", page("FOODTURE: products needed in each country", $body, $script));
}

# Ingredients of the selected products (Taxonomy Wiz mission)
sub csv_text (@lines) {
	my $csv = Text::CSV->new({binary => 1});
	my $text = '';
	foreach my $line_ref (@lines) {
		$csv->combine(map {$_ // ''} @$line_ref) or die "Cannot make CSV line: " . $csv->error_diag() . "\n";
		$text .= $csv->string() . "\n";
	}
	return $text;
}

{
	my @lines = (
		[
			qw/date country country_code foodture_country selected_products ingredients unknown_ingredients
				known_ingredients_pct different_unknown_ingredients products_with_95pct_quantity_recognized/
		]
	);
	my @unknown_lines = ([qw/date country country_code ingredient selected_products codes/]);
	foreach my $country (@foodture_names, @other_names, '') {
		my $i = $ingredients{$country} // {products => {}, ingredients => 0, unknown_n => 0, unknown => {}};
		my $known = known_pct($country);
		push @lines,
			[
			$dump_date,
			$country eq '' ? 'All FOODTURE countries' : $country,
			$country eq '' ? '' : $countries{$country}{country_code},
			$country eq '' ? 1 : $countries{$country}{foodture_country},
			scalar(keys %{$i->{products}}),
			$i->{ingredients},
			$i->{unknown_n},
			defined $known ? sprintf("%.2f", $known) : '',
			scalar(keys %{$i->{unknown}}),
			$i->{quantity_ok} // 0
			];
		next if $country eq '';
		foreach my $tag (
			sort {scalar(@{$i->{unknown}{$b}}) <=> scalar(@{$i->{unknown}{$a}}) or $a cmp $b}
			keys %{$i->{unknown}}
			)
		{
			push @unknown_lines,
				[
				$dump_date, $country,
				$countries{$country}{country_code}, $tag,
				scalar(@{$i->{unknown}{$tag}}), join(",", @{$i->{unknown}{$tag}})
				];
		}
	}
	write_file("foodture_ingredients_by_country.csv", csv_text(@lines));
	write_file("foodture_unknown_ingredients.csv", csv_text(@unknown_lines));
}

# data.js for the Scan Champion and Data Detective mini-sites: same format as their own data.js
# (categories without a complete product have has_code = false and are the "high priority" ones of the scan list)
sub flag ($cc) {
	my $code = uc($cc eq 'uk' ? 'gb' : $cc);
	return join('', map {chr(0x1F1E6 + ord($_) - ord('A'))} split(//, $code));
}

sub round1 ($value) {
	return sprintf("%.1f", $value) + 0;
}

{
	my $baseline_ref = {};
	if (-e $baseline_file) {
		open(my $BASELINE, '<:raw', $baseline_file) or die "Cannot read $baseline_file: $!\n";
		$baseline_ref = JSON::MaybeXS->new(utf8 => 1)->decode(
			do {local $/; <$BASELINE>}
		);
		close $BASELINE;
	}
	my $new_baseline = not defined $baseline_ref->{date};
	$baseline_ref->{date} //= $dump_date;

	my (%stats_countries, %countries_data, %translations);
	my ($total_items, $total_with_code) = (0, 0);
	foreach my $country (@foodture_names, @other_names) {
		my $cc = $countries{$country}{country_code};
		my $code = $scan_champion_cc{$cc} // $cc;
		my @country_rows = grep {($_->{country} eq $country) and $_->{dataset_needed}} @rows;
		my $country_tag = $countries{$country}{country_tag} // $country_rows[0]{country_tag};
		my @items = ();
		my $with_code = 0;
		foreach my $r (@country_rows) {
			my $has_code = $r->{status} eq 'OK' ? 1 : 0;
			$with_code += $has_code;
			my $category_tag = $r->{off_category};
			push @items,
				{
				category_tag => $category_tag,
				category_name => $r->{off_category_name_en},
				code => $has_code ? $r->{code} : '',
				has_code => $has_code ? JSON::MaybeXS::true : JSON::MaybeXS::false,
				status => $has_code ? 'In database' : 'Needs photo / barcode',
				off_url => $has_code ? "https://world.openfoodfacts.org/product/$r->{code}" : '',
				hunger_games_url =>
					"https://hunger.openfoodfacts.org/questions?value_tag=$category_tag&type=category&country=$country_tag&sorted=true",
				needed_recipe => $r->{needs_recipe} || 'Yes',
				};
			$translations{$category_tag}{en} = $r->{off_category_name_en};
			foreach my $local (split(/; /, $r->{off_category_names_local} // '')) {
				$translations{$category_tag}{$1} = $2 if $local =~ /^(\w\w): (.+)$/;
			}
		}
		next if not @items;
		my $coverage = round1(100 * $with_code / @items);
		$baseline_ref->{countries}{$code} //= $coverage;
		my $metadata_ref = {
			name => $country,
			code => $code,
			flag => flag($cc),
			off_tag => $country_tag,
			languages => $countries{$country}{languages} // [],
			total => scalar(@items),
			with_code => $with_code,
			missing => @items - $with_code,
			coverage_pct => $coverage,
			start_baseline_pct => $baseline_ref->{countries}{$code},
			delta_pct => round1($coverage - $baseline_ref->{countries}{$code}),
		};
		$stats_countries{$code} = $metadata_ref;
		$countries_data{$code} = {metadata => $metadata_ref, categories => \@items};
		$total_items += @items;
		$total_with_code += $with_code;
	}
	my $stats_ref = {
		campaign_id => "photos_for_impact_2026",
		baseline_date => $baseline_ref->{date},
		last_updated => $generated,
		total_countries => scalar(keys %stats_countries),
		total_items => $total_items,
		total_with_code => $total_with_code,
		total_missing => $total_items - $total_with_code,
		overall_coverage_pct => $total_items ? round1(100 * $total_with_code / $total_items) : 0,
		countries => \%stats_countries,
	};
	# all the translations of the categories, if the JSON file has them
	foreach my $tag (keys %translations) {
		my $names_ref = $data_ref->{category_names}{$tag} // {};
		$translations{$tag}{$_} //= $names_ref->{$_} for keys %$names_ref;
	}
	my $json = JSON::MaybeXS->new(canonical => 1, pretty => 1);
	write_file("data.js",
			  "window.CAMPAIGN_STATS = "
			. $json->encode($stats_ref) . ";\n"
			. "window.COUNTRIES_DATA = "
			. $json->encode(\%countries_data) . ";\n"
			. "window.CATEGORY_TRANSLATIONS = "
			. $json->encode(\%translations)
			. ";\n");

	# keep the coverage at the start of the campaign (the baseline file is not overwritten once created,
	# only completed with the countries that were not in it)
	open(my $BASELINE, '>:raw', "$baseline_file.tmp") or die "Cannot write $baseline_file.tmp: $!\n";
	print $BASELINE JSON::MaybeXS->new(utf8 => 1, canonical => 1, pretty => 1)->encode($baseline_ref);
	close $BASELINE;
	rename("$baseline_file.tmp", $baseline_file) or die "Cannot rename $baseline_file.tmp: $!\n";
	print STDERR "Baseline " . ($new_baseline ? "created" : "read") . ": $baseline_file\n";
}

print STDERR scalar(@country_names)
	. " country pages, all.html, index.html, data.js and the ingredients CSV files written to $output_dir\n";
