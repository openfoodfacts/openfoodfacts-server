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

# This script expects nginx access logs on STDIN
# See scanbot.md in this directory for how to get the scan files and run scanbot
# filtered by the app:
# grep "Official Android App" nginx.access2.log | grep Scan > android_app.log

use ProductOpener::PerlStandards;
use utf8;

use CGI::Carp qw(fatalsToBrowser);

use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/%BASE_DIRS ensure_dir_created_or_die/;
use ProductOpener::Store qw/retrieve_object store_object object_exists write_json/;
use ProductOpener::Texts qw/:all/;
use ProductOpener::Tags qw/canonicalize_taxonomy_tag/;
use ProductOpener::ProductsTags qw/generate_field_tags_from_all_sources set_field_input_tags_for_source/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Mail qw/:all/;
use ProductOpener::Products
	qw/get_source_for_site_and_org product_path product_path_from_id retrieve_product store_product/;
use ProductOpener::Food qw/:all/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Data qw/get_products_collection/;
use ProductOpener::GeoIP;
use ProductOpener::HTTP qw/create_user_agent/;
use ProductOpener::Redis qw/push_product_update_to_redis/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone nstore retrieve/;
use Encode;
use JSON::MaybeXS;
use Getopt::Long;
use Time::HiRes qw/time/;

my $year;
my $update_popularity;
my $update_scans;
my $add_countries;
my $incremental;
my $dry_run;

GetOptions(
	'year=s' => \$year,
	'update-popularity' => \$update_popularity,
	'update-scans' => \$update_scans,
	'add-countries' => \$add_countries,
	'incremental' => \$incremental,
	'dry-run' => \$dry_run,
);

if ((not defined $year) or not(1 or (defined $update_popularity) or (defined $update_scans))) {
	print STDERR <<USAGE
scanbot.pl processes nginx log files that have been filtered to keep only the OFF apps scans for a particular year.

See scripts/scanbot.md for how to extract the scan files from the logs, and how to run scanbot.

Usage:

scanbot.pl --year 2020 --update-popularity --update-scans --add-countries [--incremental] [--dry-run] < scans_log

Options:
	--update-popularity	Update the popularity_tags facet for each scanned products.
	--update-scans		Update the scans.json file for each scanned product.
	--add-countries		Add countries with at least 5 unique scans to products.
	--incremental		Only update products whose scan data changed since the previous run for the same year.
	--dry-run		Compute everything and report what would change, but do not update products or files.

Products that are scanned but do not exist on OFF are not created,
but they are taken into account to compute some values of the popularity facets (e.g. top-95-percent-scans).

The --year parameter and at least one of --update-popularity or --update-scans is required.

e.g. sample usage to compute scan statistics for a full year, without adding new countries to products:

./scanbot.pl --year 2021 --update-popularity --update-scans < /srv/off/logs/*.log.scan.2021

Incremental updates:

Unique scans are counted by distinct IPs over the whole year, and ranks are computed over all products,
so scanbot always needs the scan logs of the whole year (old and new logs), not only the new logs.

Each run (incremental or not, except dry runs) saves the scan data of each product in
scanbot.[year]/scanbot.[year].state.sto, and (also in dry runs) the GeoIP results in scanbot.[year]/scanbot.[year].geoip.sto

With --incremental, a product is updated only if its number of scans, its number of unique scans,
its unique scans by country or its popularity tags for the year changed since the previous run.
Changes of ranks alone (because other products got more scans) do not update the product.
Countries are added only when they reach 5 unique scans since the previous run,
so that countries that were removed by users after a previous run are not added again.
GeoIP results of the previous runs are reused.

The options --update-popularity, --update-scans and --add-countries must be the same as in the run that created the state file.

If there is no state file yet, --incremental compares with the scan data in the scans.json file of each product
(popularity tags changes are then only detected for products whose scan data changed).

The popularity_key needs to be recomputed with the new popularity data:

./update_all_products.pl --compute-sort

To compute scan data with Nutri-Score information, for one country:

grep country:fr ../data/scanbot.2021/scanbot.2021.products.csv  | ./add_nutriscore_to_scanbot_csv.pl > ../data/scanbot.2021/scanbot.with-nutriscore.csv

USAGE
		;
	exit();
}

print STDERR "Running scanbot for year $year"
	. ($incremental ? " (incremental)" : "")
	. ($dry_run ? " (dry run)" : "") . "\n";

my $start_time = time();
my $phase_time = $start_time;

# Print the time spent in the phase that just ended
sub end_phase ($phase) {
	my $now = time();
	printf STDERR "Phase \"%s\" took %.1fs (total %.1fs)\n", $phase, $now - $phase_time, $now - $start_time;
	$phase_time = $now;
	return;
}

my %codes = ();

my $scans = 0;    # API calls (or scans if logs have been filtered to keep only scans)

# 139.167.246.115 - - [02/Jan/2019:17:46:57 +0100] "GET /api/v0/product/123.json?f

# Save scan product data in /data
# This scan data can then be filtered and used as input for other scripts such as add_nutriscore_to_scanbot_csv.pl
my $output_dir = "$BASE_DIRS{PRIVATE_DATA}/scanbot.$year";
ensure_dir_created_or_die($output_dir);

# State of the previous run: scan data of each found product, used to update only changed products
my $state_file = "$output_dir/scanbot.$year.state.sto";
# GeoIP results of the previous runs: ip -> country code ('' if unknown)
my $geoip_cache_file = "$output_dir/scanbot.$year.geoip.sto";

my %options = (
	update_popularity => $update_popularity ? 1 : 0,
	update_scans => $update_scans ? 1 : 0,
	add_countries => $add_countries ? 1 : 0,
);

my %previous_state = ();
my $have_previous_state = 0;

if ($incremental) {
	if (-e $state_file) {
		print STDERR "Loading previous state from $state_file\n";
		my $state_ref = retrieve($state_file);
		foreach my $option (sort keys %options) {
			if ($options{$option} != ($state_ref->{options}{$option} // 0)) {
				die(      "Option $option is $options{$option} but was "
						. ($state_ref->{options}{$option} // 0)
						. " in the previous run (state file $state_file).\n"
						. "Use the same options, or do a full run without --incremental.\n");
			}
		}
		%previous_state = %{$state_ref->{products}};
		$have_previous_state = 1;
		print STDERR "Loaded previous state for " . (scalar keys %previous_state) . " products\n";
	}
	else {
		print STDERR "No previous state in $state_file, comparing with the scans.json file of each product\n";
	}
	end_phase("load previous state");
}

print STDERR "Loading scan logs\n";

my %ips = ();
my $lines = 0;

while (<STDIN>) {
	my $line = $_;
	# The IP field is the X-Forwarded-For header, which can contain a list of IPs (e.g. "1.2.3.4, 1.2.3.4"
	# or "1.2.3.4, 5.6.7.8"). Keep the last one: it is added by our proxies, while the first ones
	# can be sent by the client (and spoofed).
	my $ip = '';
	if ($line =~ /^([^\s,]+(?:,\s*[^\s,]+)*)\s/) {
		$ip = (split(/,\s*/, $1))[-1];
	}
	$lines++;

	# Get the product code e.g. "GET /api/v0/product/4548022405787.json?fields=image_front_small_url,product_name HTTP/2.0"
	# or now: "GET /cgi/display.pl?/api/v3/product/6111242101852/?lc=fr&tags_lc=fr&cc=ma&fields=product_name%2Cproduct_name_languages%2Cbrands%2Ccode%2Cproduct_type%2Cnutrition_grade_fr%2Cimage_ [..]
	if ($line =~ /(?: |\/cgi\/display.pl\?)\/api\/v(?:[^\/]+)\/product\/(\d+)/) {

		my $code = $1;

		# Skip bogus codes

		($code =~ /^0*$/) and next;
		($code eq "1") and next;
		($code eq "15600703") and next;

		(defined $codes{$code}) or $codes{$code} = {n => 0, ips => {}};

		$codes{$code}{n}++;
		$codes{$code}{ips}{$ip}++;

		$ips{$ip}++;

		$scans++;
		($scans % 1000) == 0 and print "Loading scan logs $scans\n";
	}
}

print STDERR "Loaded scan logs: $scans scans from $lines lines\n";
end_phase("load scan logs");

my $changed_products = 0;
my $added_countries = 0;

# Count unique ips

my $total_scans = $scans;
my $total_unique_scans = 0;

foreach my $code (keys %codes) {
	$codes{$code}{u} = scalar keys %{$codes{$code}{ips}};
	$total_unique_scans += $codes{$code}{u};
}

# Cache GeoIP results

my %geoips = ();

if ($incremental and (-e $geoip_cache_file)) {
	%geoips = %{retrieve($geoip_cache_file)};
	print STDERR "Loaded " . (scalar keys %geoips) . " cached GeoIP results from $geoip_cache_file\n";
}

my $ips_n = scalar keys %ips;

print STDERR "Computing GeoIPs for $ips_n ip addresses\n";

my $ips = 0;
my $geoip_lookups = 0;

foreach my $ip (keys %ips) {
	$ips++;
	($ips % 1000) == 0 and print "$ips / $ips_n ips\n";
	next if exists $geoips{$ip};
	my $country_code = ProductOpener::GeoIP::get_country_code_for_ip($ip);
	$geoips{$ip} = defined $country_code ? lc($country_code) : '';
	$geoip_lookups++;
}

print STDERR "Computed GeoIPs: $geoip_lookups lookups, " . ($ips_n - $geoip_lookups) . " cached\n";

# The GeoIP cache is saved even in dry runs (it does not contain product data), so that the next run can reuse it
{
	# Keep only the IPs of this year's logs
	my %geoips_to_save = map {$_ => $geoips{$_}} keys %ips;
	nstore(\%geoips_to_save, "$geoip_cache_file.tmp");
	rename("$geoip_cache_file.tmp", $geoip_cache_file) or die("Cannot rename $geoip_cache_file.tmp: $!\n");
}

end_phase("GeoIP");

# Order of the products: most unique scans first, then most scans, then code so that the order is stable between runs

my @sorted_codes = sort {$codes{$b}{u} <=> $codes{$a}{u} || $codes{$b}{n} <=> $codes{$a}{n} || $a cmp $b} keys %codes;

# Compute countries

print STDERR "Computing countries for all products\n";

my %countries_for_products = ();
my %countries_for_all_products = ();
my %products_for_countries = ();

my %countries_ranks_for_products = ();

my $j = 0;
my $i = 0;

foreach my $code (@sorted_codes) {

	next if $code eq "";

	$j++;

	$countries_for_products{$code} = {"world" => 0};

	# too slow
	# next if not defined retrieve_product($code);
	# Products found in the previous run still exist (deleted products are very rare), no need to check them again
	if (not((defined $previous_state{$code}) and ($previous_state{$code}{f}))) {
		my $product_path = "$BASE_DIRS{PRODUCTS}/" . product_path_from_id($code) . "/product";
		next if !object_exists($product_path);
	}

	$countries_ranks_for_products{$code} = {};

	while (my ($ip, $v) = each %{$codes{$code}{ips}}) {
		#foreach my $ip (keys %{$codes{$code}{ips}}) {

		$i++;

		my $country_code = $geoips{$ip};

		if ((defined $country_code) and ($country_code ne "")) {
			$countries_for_products{$code}{$country_code}++;
			$countries_for_all_products{$country_code}++;
		}

		$countries_for_products{$code}{"world"}++;
		$countries_for_all_products{"world"}++;
	}

	foreach my $country_code (keys %{$countries_for_products{$code}}) {
		defined $products_for_countries{$country_code} or $products_for_countries{$country_code} = {};
		$products_for_countries{$country_code}{$code} = $countries_for_products{$code}{$country_code};
	}

	if (($j % 100) == 0) {
		print "computing countries $j products - $i ips \n";
		$i = 0;
	}
}

end_phase("compute countries");

# Update scans.json

if ($update_scans and not $dry_run) {

	my $scans_ref = retrieve_object("$BASE_DIRS{PRODUCTS}/all_products_scans");
	if (not defined $scans_ref) {
		$scans_ref = {};
	}

	$scans_ref->{$year} = {
		scans_n => $total_scans + 0,
		unique_scans_n => $total_unique_scans + 0,
		unique_scans_n_by_country => \%countries_for_all_products,
	};

	#11901: Switch to using store_object after migration. We always want to save these to JSON
	write_json("$BASE_DIRS{PRODUCTS}/all_products_scans.json", $scans_ref);
}

print STDERR "Ranking products for all countries\n";

foreach my $country_code (sort keys %products_for_countries) {

	my $rank = 0;

	foreach my $code (
		sort {$products_for_countries{$country_code}{$b} <=> $products_for_countries{$country_code}{$a} || $a cmp $b}
		keys %{$products_for_countries{$country_code}}
		)
	{

		$rank++;
		$countries_ranks_for_products{$code}{$country_code} = $rank;
	}
}

print STDERR "Ranked products for all countries\n";
end_phase("rank products");

=head2 popularity_tags_for_year ($code, $unique_scans_n, $cumulative_scans)

Return the popularity tags of a product for the year, computed from its ranks and scans by country.

=cut

sub popularity_tags_for_year ($code, $unique_scans_n, $cumulative_scans) {

	my @tags = ();
	my $countries_ref = $countries_for_products{$code};
	my $ranks_ref = $countries_ranks_for_products{$code};

	my $rank = $ranks_ref->{"world"};

	# compute the top products

	foreach my $top (10, 50, 100, 500, 1000, 5000, 10000, 50000, 100000) {

		if ($rank <= $top) {
			push @tags, "top-" . $top . "-scans-$year";
		}
	}

	foreach my $min (5, 10) {
		if ($unique_scans_n >= $min) {
			push @tags, "at-least-" . $min . "-scans-$year";
		}
	}

	foreach my $percent (75, 80, 85, 90) {
		if ($cumulative_scans / $total_unique_scans <= $percent / 100) {
			push @tags, "top-" . $percent . "-percent-scans-$year";
		}
		else {
			push @tags, "bottom-" . (100 - $percent) . "-percent-scans-$year";
		}
	}

	my $top_country;

	foreach my $cc (sort {$countries_ref->{$b} <=> $countries_ref->{$a} || $a cmp $b} keys %$countries_ref) {

		next if $cc eq "world";

		foreach my $top (10, 50, 100, 500, 1000, 5000, 10000, 50000, 100000) {

			if ($ranks_ref->{$cc} <= $top) {
				push @tags, "top-" . $top . "-$cc-scans-$year";
			}
		}

		if (not $top_country) {
			push @tags, "top-country-" . $cc . "-scans-$year";
			$top_country = $cc;
		}

		foreach my $min (5, 10) {
			if ($countries_ref->{$cc} >= $min) {
				push @tags, "at-least-" . $min . "-" . $cc . "-scans-$year";
			}
		}
	}

	return \@tags;
}

=head2 previous_state_from_scans_json ($code)

Build the previous state of a product from its scans.json file, when there is no state file yet.

=cut

sub previous_state_from_scans_json ($code) {

	my $scans_ref = retrieve_object("$BASE_DIRS{PRODUCTS}/" . product_path_from_id($code) . "/scans");
	return if not((defined $scans_ref) and (defined $scans_ref->{$year}));
	my $year_ref = $scans_ref->{$year};
	return {
		f => 1,
		n => $year_ref->{scans_n} // 0,
		u => $year_ref->{unique_scans_n} // 0,
		c => $year_ref->{unique_scans_n_by_country} // {},
		# popularity tags and countries added are unknown
		from_scans_json => 1,
	};
}

=head2 same_scan_data ($previous_ref, $new_ref)

Return 1 if the scan data of a product is the same as in the previous run.

=cut

sub same_scan_data ($previous_ref, $new_ref) {

	return 0 if ($previous_ref->{n} != $new_ref->{n}) or ($previous_ref->{u} != $new_ref->{u});

	my ($previous_c, $new_c) = ($previous_ref->{c}, $new_ref->{c});
	return 0 if (scalar keys %$previous_c) != (scalar keys %$new_c);
	foreach my $cc (keys %$new_c) {
		return 0 if ($previous_c->{$cc} // -1) != $new_c->{$cc};
	}

	# Popularity tags are unknown when the previous state comes from scans.json
	if (defined $previous_ref->{t}) {
		return 0 if join(",", @{$previous_ref->{t}}) ne join(",", @{$new_ref->{t}});
	}

	return 1;
}

print STDERR "Process and update all products\n";

# Log products scan counts

my $products_file = "$output_dir/scanbot.$year.products.csv";
my $log_file = "$output_dir/scanbot.log";
if ($dry_run) {
	$products_file .= ".dry-run";
	$log_file .= ".dry-run";
}

open(my $PRODUCTS, ">:encoding(UTF-8)", $products_file)
	or die("Cannot create $products_file: $!\n");
open(my $LOG, ">:encoding(UTF-8)", $log_file) or die("Cannot create $log_file: $!\n");

my $cumulative_scans
	= 0;    # cumulative total of scans so that we can compute which top products represent 95% of the scans

my %new_state = ();    # scan data of found products, saved for the next incremental run
my $unchanged_products = 0;
my $updated_products = 0;

$i = 0;    # products scanned

foreach my $code (@sorted_codes) {

	next if $code eq "";

	$i++;

	my $scans_n = $codes{$code}{n};
	my $unique_scans_n = $codes{$code}{u};

	my $bot = '';

	print "$i\t$code\t$codes{$code}{n}\t" . $unique_scans_n . "\t";

	$bot .= "product code $code scanned $scans_n times (from $unique_scans_n ips) - ";

	my %countries = %{$countries_for_products{$code}};

	my $countries_list = "";

	foreach my $cc (sort {$countries{$b} <=> $countries{$a} || $a cmp $b} keys %countries) {
		print "$cc:$countries{$cc} ";
		$bot .= "$cc:$countries{$cc} ";
		$countries_list .= "country:$cc ";    # for grepping a particular country
	}
	print "\n";

	$bot .= " -- ";

	# Popularity tags for the year, for existing products
	my $year_tags_ref = [];
	my $exists = exists $countries_ranks_for_products{$code};
	if ($exists and $update_popularity) {
		$cumulative_scans += $unique_scans_n;
		$year_tags_ref = popularity_tags_for_year($code, $unique_scans_n, $cumulative_scans);
	}

	my $new_state_ref = {
		n => $scans_n + 0,
		u => $unique_scans_n + 0,
		c => $countries_for_products{$code},
		t => [sort @$year_tags_ref],
	};

	# Skip products that did not change since the previous run
	my $previous_ref;
	if ($incremental and $exists) {
		$previous_ref = $have_previous_state ? $previous_state{$code} : previous_state_from_scans_json($code);
		if ((defined $previous_ref) and ($previous_ref->{f}) and same_scan_data($previous_ref, $new_state_ref)) {
			$unchanged_products++;
			$new_state{$code} = {%$new_state_ref, f => 1, s => $previous_ref->{s}};
			my $source = $previous_ref->{s} // "unknown";
			print $PRODUCTS "$code\t$scans_n\t$unique_scans_n\tFOUND\t$source\t\"$countries_list\n";
			next;
		}
	}

	print "$i - checking product $code - scans: $scans_n unique_scans: $unique_scans_n \n";

	# Products that do not exist were already detected when computing countries
	my $product_ref = $exists ? retrieve_product($code) : undef;

	my $found = "NOT_FOUND";
	my $source = "crowdsourcing";
	my $added_countries_list = "";

	if ((defined $product_ref) and ($code ne '') and (defined $product_ref->{code}) and (defined $product_ref->{lc})) {

		my $path = product_path($product_ref);

		$found = "FOUND";
		$updated_products++;

		if (    (defined $product_ref->{data_sources})
			and ($product_ref->{data_sources} =~ /producer/i))
		{
			$source = "producers";
		}

		$new_state{$code} = {%$new_state_ref, f => 1, s => $source};

		# Update scans.json

		if ($update_scans and not $dry_run) {

			my $scans_ref = retrieve_object("$BASE_DIRS{PRODUCTS}/$path/scans");
			if (not defined $scans_ref) {
				$scans_ref = {};
			}

			$scans_ref->{$year} = {
				scans_n => $scans_n + 0,
				unique_scans_n => $unique_scans_n + 0,
				unique_scans_n_by_country => $countries_for_products{$code},
				unique_scans_rank_by_country => $countries_ranks_for_products{$code},
			};

			#11901: Switch to using store_object after migration. We always want to save these to JSON
			write_json("$BASE_DIRS{PRODUCTS}/$path/scans.json", $scans_ref);
		}

		# Update popularity_tags + add countries

		if ($update_popularity) {

			$product_ref->{unique_scans_n} = $unique_scans_n + 0;
			$product_ref->{scans_n} = $scans_n + 0;

			# Replace the popularity tags of the year
			$product_ref->{popularity_tags}
				= [(grep {$_ !~ /-$year/} @{$product_ref->{popularity_tags} // []}), @$year_tags_ref];

			# Add countries tags based on scans

			# Regenerate countries_tags from the input tags of all sources, and remove fields from the old tags schema:
			# a previous version of scanbot set them with add_tags_to_field(), which replaced countries_tags
			# with only the added countries
			delete @{$product_ref}{qw(countries countries_hierarchy countries_lc)};
			generate_field_tags_from_all_sources($product_ref, "countries");

			my $current_countries = join(",", @{$product_ref->{countries_tags} // []});

			my %existing = ();
			foreach my $countryid (@{$product_ref->{countries_tags}}) {
				$existing{$countryid} = 1;
			}

			$bot .= " current countries: $current_countries ";

			foreach my $cc (sort {$countries{$b} <=> $countries{$a} || $a cmp $b} keys %countries) {

				next if $cc eq "world";

				print "$cc:$countries{$cc} ";

				next if $countries{$cc} < 5;

				# In incremental mode, only add countries that reached 5 unique scans since the previous run,
				# so that we do not add again countries that users removed after the previous run
				if (    (defined $previous_ref)
					and (not $previous_ref->{from_scans_json})
					and (($previous_ref->{c}{$cc} // 0) >= 5))
				{
					next;
				}

				my $country = canonicalize_taxonomy_tag('en', "countries", $cc);

				# Do not add countries for products with a code beginning by 2
				# (codes can be reused by different companies in different countries)
				if (($add_countries) and ($code !~ /^(02|2)/) and (not exists $existing{$country})) {
					print "- adding $country to $current_countries\n";
					# Add the country to the existing countries of the default source ("packaging" on the public platform)
					# so that it can be removed by users like any other country
					set_field_input_tags_for_source($product_ref, "en", "countries", get_source_for_site_and_org(),
						$country, 1);
					$bot .= "+$country ";
					$added_countries++;
					$added_countries_list .= $country . ',';
				}
			}

			if ($dry_run) {
				print "dry run: not updating $code\n";
				$changed_products++ if $added_countries_list ne "";
			}
			elsif ($added_countries_list ne "") {
				$product_ref->{"countries_beforescanbot"} = $current_countries;
				$changed_products++;

				my $comment = $bot;

				print "adding countries for $code - $bot\n";
				store_product('scanbot', $product_ref, $comment);
			}
			else {
				print "updating scan count for $code\n";
				$product_ref->{last_updated_t} = time() + 0;
				store_object("$BASE_DIRS{PRODUCTS}/$path/product", $product_ref);
				get_products_collection()->replace_one({"_id" => $product_ref->{_id}}, $product_ref, {upsert => 1});
				push_product_update_to_redis($product_ref, {"userid" => 'scanbot', "comment" => $year}, "updated");
			}
		}
	}

	$added_countries_list =~ s/,$//;

	print $code . "\t"
		. $scans_n . "\t"
		. $unique_scans_n . "\t"
		. $found . "\t"
		. $source . "\t"
		. $added_countries_list . "\t"
		. $countries_list . "\n";
	print $PRODUCTS $code . "\t"
		. $scans_n . "\t"
		. $unique_scans_n . "\t"
		. $found . "\t"
		. $source . "\t"
		. $added_countries_list . "\""
		. $countries_list . "\n";

	print $LOG $bot . "\n";

	print $bot . "\n";
}

end_phase("update products");

if (not $dry_run) {
	nstore({year => $year, options => \%options, products => \%new_state}, "$state_file.tmp");
	rename("$state_file.tmp", $state_file) or die("Cannot rename $state_file.tmp: $!\n");
	print STDERR "Saved state for " . (scalar keys %new_state) . " products in $state_file\n";
}

if (($changed_products > 0) and ($added_countries > 0) and (not $dry_run)) {

	my $msg = "\nI added $added_countries countries to $changed_products products\n\n";
	print $msg;

	if (1) {
		my $ua = create_user_agent();

		my $server_endpoint
			= "https://openfoodfacts.slack.com/services/hooks/incoming-webhook?token=jMDE8Fzkz9qD7uC9Lq04fbZH";

		# set custom HTTP request header fields
		my $req = HTTP::Request->new(POST => $server_endpoint);
		$req->header('content-type' => 'application/json');

		# add POST data to HTTP request body
		my $post_data
			= '{"channel": "#bots-alerts", "username": "scanbot", "text": "' . $msg . '", "icon_emoji": ":ghost:" }';
		$req->content($post_data);

		my $resp = $ua->request($req);
		if ($resp->is_success) {
			my $message = $resp->decoded_content;
			print "Received reply: $message\n";
		}
		else {
			print "HTTP POST error code: ", $resp->code, "\n";
			print "HTTP POST error message: ", $resp->message, "\n";
		}
	}
}

close $PRODUCTS;
close $LOG;

print "products: $i - scans: $scans\n";

foreach my $country_code (
	sort {$countries_for_all_products{$a} <=> $countries_for_all_products{$b}}
	keys %countries_for_all_products
	)
{
	print "$country_code: $countries_for_all_products{$country_code}\n";
}

print STDERR "Products: $i scanned, $updated_products "
	. ($dry_run ? "would be updated" : "updated")
	. ", $unchanged_products unchanged (skipped)"
	. ", $added_countries countries "
	. ($dry_run ? "would be added" : "added")
	. " to $changed_products products\n";

end_phase("done");
