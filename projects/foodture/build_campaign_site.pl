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
use Getopt::Long;

# Static web pages of the FOODTURE campaign, made from foodture_campaign.json (list_campaign_needed_categories.pl):
# - index.html: summary per country (sortable), with links to the country pages and to the campaign tools.
#   index.html?country=<cc> redirects to the page of the country.
# - <cc>.html: categories needed in one country (cc = country subdomain on openfoodfacts.org: at, be, uk...)
# - all.html: all countries on one page
# The pages are written in --output-dir, next to foodture_campaign.json, foodture_campaign.csv.

my $usage = "build_campaign_site.pl --json <foodture_campaign.json> --output-dir <dir>\n";

my ($json_file, $output_dir);
GetOptions("json=s" => \$json_file, "output-dir=s" => \$output_dir) or die $usage;
(defined $json_file and defined $output_dir) or die $usage;
-d $output_dir or die "Output directory $output_dir does not exist\n";

open(my $IN, '<:raw', $json_file) or die "Cannot read $json_file: $!\n";
my $data_ref = JSON::MaybeXS->new(utf8 => 1)->decode(
	do {local $/; <$IN>}
);
close $IN;

# Campaign tools (see https://blog.openfoodfacts.org/en/news/new-citizen-science-initiatives)
my $blog_url = "https://blog.openfoodfacts.org/en/news/new-citizen-science-initiatives";
my $scan_champion_url = "https://openfoodfacts.github.io/smooth-app_assets/photos-for-impact/index.html";
my $data_detective_url = "https://openfoodfacts.github.io/smooth-app_assets/data-detective/";
# the Scan Champion list uses language codes for some countries
my %scan_champion_cc = (cz => 'cs', gr => 'el');

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

# Summary per country (pairs needed by FOODTURE only)
my %summary = ();
foreach my $row_ref (@rows) {
	next if not $row_ref->{foodture_needed};
	for my $country ($row_ref->{country}, '') {
		$summary{$country}{$row_ref->{status}}++;
		$summary{$country}{total}++;
	}
}

my @country_names = sort grep {$_ ne ''} keys %summary;

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
	--missing: #b42318; --missing-bg: #fde8e7; --incomplete: #9a6700; --incomplete-bg: #fff4d6; --ok: #1a7f37; --ok-bg: #e6f4ea; --link: #0969da; }
@media (prefers-color-scheme: dark) { :root { --bg: #0d1117; --fg: #e6edf3; --muted: #9198a1; --line: #30363d; --head: #161b22;
	--missing: #ff8b80; --missing-bg: #3d1614; --incomplete: #e3b341; --incomplete-bg: #33270b; --ok: #56d364; --ok-bg: #12301b; --link: #4493f8; } }
body { margin: 0; padding: 0 16px 48px; background: var(--bg); color: var(--fg); font: 15px/1.45 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; }
main { max-width: 1200px; margin: 0 auto; }
nav.top { padding: 10px 0; border-bottom: 1px solid var(--line); display: flex; flex-wrap: wrap; gap: 6px 16px; align-items: center; }
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
.summary th[data-sort]::after { content: " \2195"; color: var(--muted); }
.summary th[aria-sort=ascending]::after { content: " \2191"; color: var(--fg); }
.summary th[aria-sort=descending]::after { content: " \2193"; color: var(--fg); }
.bar { display: inline-block; width: 60px; height: 8px; background: var(--missing-bg); border-radius: 4px; vertical-align: middle; margin-left: 6px; overflow: hidden; }
.bar span { display: block; height: 100%; background: var(--ok); }
.hidden { display: none; }
@media (max-width: 700px) { .details-col { display: none; } .summary .wide { display: none; }
	.filters { position: static; }
	table.cards, table.cards tbody, table.cards tr, table.cards td { display: block; }
	table.cards tr:not(.row) { display: none; }
	table.cards tr.row { border-bottom: 1px solid var(--line); padding: 8px 0; }
	table.cards td { border: none; padding: 2px 0; }
	table.cards td.counts { font-size: 0.9em; }
	table.cards td.counts br.sep { display: none; }
	table.cards td.counts br.sep + span::before { content: " · "; } }
CSS

sub page ($title, $body, $script = '') {
	return <<HTML;
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>@{[h($title)]}</title>
<style>
$style</style>
</head>
<body>
<main>
$body
<p class="muted">Made by Open Food Facts for the <a href="https://foodture-project.eu/">FOODTURE</a> project.
Source: projects/foodture/list_campaign_needed_categories.pl and build_campaign_site.pl in
<a href="https://github.com/openfoodfacts/openfoodfacts-server">openfoodfacts-server</a>.</p>
</main>
$script
</body>
</html>
HTML
}

my $data_note = <<HTML;
<div class="note">
<b>Updated daily.</b> Open Food Facts products of $dump_date, pages generated $generated.
The selected product is the most scanned complete product of the category sold in the country (unique scans in $years_text).<br>
The counts use the latest categories taxonomy. The category pages on the Open Food Facts website can show fewer products
until all products are updated with the new categories.<br>
Data for all countries: <a href="foodture_campaign.csv">CSV</a> · <a href="foodture_campaign.json">JSON</a>
</div>
HTML

sub country_select ($current) {
	my $html = qq{<label>Country <select id="f-country">\n<option value="index.html">Summary</option>\n};
	$html .= qq{<option value="all.html"} . ($current eq '*' ? ' selected' : '') . qq{>All countries</option>\n};
	foreach my $country (@country_names) {
		$html
			.= qq{<option value="}
			. page_file($country) . qq{"}
			. ($country eq $current ? ' selected' : '') . ">"
			. h($country)
			. "</option>\n";
	}
	return $html . "</select></label>\n";
}

sub tools_links ($country) {
	my $cc = defined $country ? $countries{$country}{country_code} : undef;
	my $param = defined $cc ? "?country=" . ($scan_champion_cc{$cc} // $cc) : '';
	return <<HTML;
<div class="tools">
<a href="$scan_champion_url$param">🛒 Scan Champion: scan list for shops</a>
<a href="$data_detective_url$param">🕵️ Data Detective: complete products at home</a>
<a href="$blog_url">📖 Missions and guide</a>
</div>
HTML
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
		qq{<p class="muted">%d needed categories: %d with no product, %d with incomplete products only, %d with a complete product.%s</p>\n},
		$s->{total} // 0,
		$s->{MISSING} // 0,
		$s->{INCOMPLETE} // 0,
		$s->{OK} // 0,
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
		$category .= "<br><small>Not needed by FOODTURE (dataset only)</small>" if not $r->{foodture_needed};
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

my $filters = <<'HTML';
<label><input type="checkbox" class="f-status" value="MISSING" checked> <span class="badge MISSING">no product</span></label>
<label><input type="checkbox" class="f-status" value="INCOMPLETE" checked> <span class="badge INCOMPLETE">incomplete only</span></label>
<label><input type="checkbox" class="f-status" value="OK" checked> <span class="badge OK">complete</span></label>
<label><input type="search" id="f-text" placeholder="Search a category"></label>
<span id="f-count" class="muted"></span>
HTML

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

my $intro = <<HTML;
<p>The <a href="https://foodture-project.eu/">FOODTURE</a> research project needs, for each type of food (FoodEx2 term) and each European country,
one representative product with complete data on Open Food Facts: photos, ingredients and nutrition facts.
Categories with <span class="badge MISSING">no product</span> or with <span class="badge INCOMPLETE">incomplete products only</span>
are listed first: please scan and photograph products of these categories in stores with the Open Food Facts app,
or complete existing products from their photos.</p>
HTML

# Country pages
foreach my $country (@country_names) {
	my $body
		= qq{<nav class="top"><a href="index.html">← All countries</a></nav>\n}
		. "<h1>FOODTURE: products needed in "
		. h($country)
		. "</h1>\n"
		. $intro
		. tools_links($country)
		. $data_note
		. qq{<div class="filters">\n}
		. country_select($country)
		. $filters
		. "</div>\n"
		. qq{<section class="country">\n}
		. country_table($country, 0)
		. "</section>\n";
	write_file(page_file($country), page("FOODTURE: products needed in $country", $body, $filters_script));
}

# All countries on one page
{
	my $body
		= qq{<nav class="top"><a href="index.html">← Summary</a></nav>\n}
		. "<h1>FOODTURE: products needed in each country</h1>\n"
		. $intro
		. $data_note
		. qq{<div class="filters">\n}
		. country_select('*')
		. $filters
		. "</div>\n";
	$body .= qq{<section class="country">\n} . country_table($_, 1) . "</section>\n" for @country_names;
	write_file("all.html", page("FOODTURE: products needed in each country", $body, $filters_script));
}

# Summary page
{
	my $body = "<h1>FOODTURE: products needed in each country</h1>\n" . $intro . tools_links(undef) . $data_note;
	$body .= <<'HTML';
<h2>Summary</h2>
<p class="muted">Pick a country to see its categories. Click on a column header to sort.</p>
<div class="table-wrap"><table class="summary" id="summary">
<thead><tr><th data-sort="text" aria-sort="ascending">Country</th><th data-sort="num" class="wide">Needed</th>
<th data-sort="num"><span class="badge MISSING">no product</span></th><th data-sort="num"><span class="badge INCOMPLETE">incomplete only</span></th>
<th data-sort="num"><span class="badge OK">complete</span></th><th data-sort="num">Coverage</th><th class="wide">Scan list</th></tr></thead>
<tbody>
HTML
	foreach my $country (@country_names) {
		my $s = $summary{$country};
		my $cc = $countries{$country}{country_code};
		my $pct = pct($s);
		$body .= sprintf(
			qq{<tr><td data-value="%s"><a href="%s">%s</a></td><td class="wide">%d</td><td>%d</td><td>%d</td><td>%d</td>}
				. qq{<td data-value="%.3f">%.0f%%<span class="bar"><span style="width:%.0f%%"></span></span></td>}
				. qq{<td class="wide left"><a href="%s?country=%s">Scan Champion</a></td></tr>\n},
			h($country), page_file($country), h($country), $s->{total},
			$s->{MISSING} // 0, $s->{INCOMPLETE} // 0, $s->{OK} // 0, $pct,
			$pct, $pct, $scan_champion_url, $scan_champion_cc{$cc} // $cc
		);
	}
	my $all = $summary{''} // {};
	$body .= sprintf(
		qq{</tbody>\n<tfoot><tr><th><a href="all.html">All countries</a></th><th class="wide">%d</th><th>%d</th><th>%d</th><th>%d</th><th>%.0f%%</th><th class="wide"></th></tr></tfoot>\n</table></div>\n},
		$all->{total} // 0,
		$all->{MISSING} // 0,
		$all->{INCOMPLETE} // 0,
		$all->{OK} // 0,
		pct($all)
	);
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
	if (pages[cc]) { location.replace(pages[cc]); return; }
	var table = document.getElementById('summary');
	var tbody = table.tBodies[0];
	var headers = table.tHead.rows[0].cells;
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
			var asc = th.getAttribute('aria-sort') === 'ascending' ? false : (th.getAttribute('aria-sort') === 'descending' ? true : type === 'text');
			Array.prototype.forEach.call(headers, function (h) { h.removeAttribute('aria-sort'); });
			th.setAttribute('aria-sort', asc ? 'ascending' : 'descending');
			var rows = Array.prototype.slice.call(tbody.rows);
			rows.sort(function (a, b) {
				var x = value(a, i, type), y = value(b, i, type);
				var c = x < y ? -1 : x > y ? 1 : 0;
				if (c === 0) { c = value(a, 0, 'text') < value(b, 0, 'text') ? -1 : 1; return c; }
				return asc ? c : -c;
			});
			rows.forEach(function (r) { tbody.appendChild(r); });
		}
		th.addEventListener('click', sort);
		th.addEventListener('keydown', function (e) { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); sort(); } });
	});
})();
</script>
HTML
	write_file("index.html", page("FOODTURE: products needed in each country", $body, $script));
}

print STDERR scalar(@country_names) . " country pages, all.html and index.html written to $output_dir\n";
