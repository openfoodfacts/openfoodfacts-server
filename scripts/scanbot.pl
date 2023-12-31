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

# This script expects nginx access logs on STDIN
# filtered by the app:
# grep "Official Android App" nginx.access2.log | grep Scan > android_app.log

use Modern::Perl '2017';
use utf8;

use CGI::Carp qw(fatalsToBrowser);

use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/:all/;
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
use ProductOpener::GeoIP;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;
use Getopt::Long;

my $year;
my $update_popularity;
my $update_scans;
my $add_countries;

GetOptions(
	'year=s' => \$year,
	'update-popularity' => \$update_popularity,
	'update-scans' => \$update_scans,
	'add-countries' => \$add_countries,
);

if ((not defined $year) or not((defined $update_popularity) or (defined $update_scans))) {
	print STDERR <<USAGE
scanbot.pl processes nginx log files that have been filtered to keep only the OFF apps scans for a particular year.

Usage:

scanbot.pl --year 2020 --update-popularity --update-scans --add-countries < scans_log

Options:
	--update-popularity	Update the popularity_tags facet for each scanned products.
	--update-scans		Update the scans.json file for each scanned product.
	
Products that are scanned but do not exist on OFF are not created,
but they are taken into account to compute some values of the popularity facets (e.g. top-95-percent-scans).

The --year parameter and at least one of --update-popularity or --update-scans is required.

e.g. sample usage to compute scan statistics for a full year, without adding new countries to products:

./scanbot.pl --year 2021 --update-popularity --update-scans < /srv/off/logs/*.log.scan.2021

The popularity_key needs to be recomputed with the new popularity data:

./update_all_products.pl --compute-sort

To compute scan data with Nutri-Score information, for one country:

grep country:fr ../data/scanbot.2021/scanbot.2021.products.csv  | ./add_nutriscore_to_scanbot_csv.pl > ../data/scanbot.2021/scanbot.with-nutriscore.csv

USAGE
		;
	exit();
}

print STDERR "Running scanbot for year $year\n";

my %codes = ();

my $j = 0;    # API calls (or scans if logs have been filtered to keep only scans)

# 139.167.246.115 - - [02/Jan/2019:17:46:57 +0100] "GET /api/v0/product/123.json?f

print STDERR "Loading scan logs\n";

# Save scan product data in /data
# This scan data can then be filtered and used as input for other scripts such as add_nutriscore_to_scanbot_csv.pl
my $output_dir = "$BASE_DIRS{PRIVATE_DATA}/scanbot.$year";
ensure_dir_created_or_die($output_dir);

my %ips = ();

while (<STDIN>) {
	my $line = $_;
	my $ip = $_;
	$ip =~ s/\s.*//;
	chomp($ip);

	# Get the product code e.g. "GET /api/v0/product/4548022405787.json?fields=image_front_small_url,product_name HTTP/2.0"
	if ($line =~ / \/api\/v(?:[^\/]+)\/product\/(\d+)/) {

		$j++;
		my $code = $1;

		# Skip bogus codes

		($code eq "1") and next;
		($code eq "15600703") and next;

		(defined $codes{$code}) or $codes{$code} = {n => 0, ips => {}};

		$codes{$code}{n}++;
		$codes{$code}{ips}{$ip}++;

		$ips{$ip}++;

		($j % 1000) == 0 and print "Loading scan logs $j\n";
	}
}

print STDERR "Loaded scan logs: $j lines\n";

my $changed_products = 0;
my $added_countries = 0;

# Count unique ips

my $total_scans = $j;
my $total_unique_scans = 0;

foreach my $code (keys %codes) {
	$codes{$code}{u} = scalar keys %{$codes{$code}{ips}};
	$total_unique_scans += $codes{$code}{u};
}

# Cache GeoIP results

my %geoips = ();
my $ips_n = scalar keys %ips;

print STDERR "Computing GeoIPs for $ips_n ip addresses\n";

$j = 0;

foreach my $ip (keys %ips) {
	$j++;
	$geoips{$ip} = ProductOpener::GeoIP::get_country_code_for_ip($ip);
	if (defined $geoips{$ip}) {
		$geoips{$ip} = lc($geoips{$ip});
	}
	($j % 1000) == 0 and print "$j / $ips_n ips\n";
}

# Compute countries

print STDERR "Computing countries for all products\n";

my %countries_for_products = ();
my %countries_for_all_products = ();
my %products_for_countries = ();

my %countries_ranks_for_products = ();

$j = 0;

my $k = 0;
my $i = 0;

foreach my $code (sort {$codes{$b}{u} <=> $codes{$a}{u} || $codes{$b}{n} <=> $codes{$a}{n}} keys %codes) {

	next if $code eq "";

	$j++;

	$countries_for_products{$code} = {"world" => 0};

	# too slow
	# next if not defined retrieve_product($code);
	my $product_id = $code;
	my $path = product_path_from_id($product_id);
	my $product_path = "$BASE_DIRS{PRODUCTS}/$path/product.sto";
	next if !-e $product_path;

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
		print "computing countries $j - $i ips \n";
		$k = 0;
		$i = 0;
	}
}

# Update scans.json

if ($update_scans) {

	my $scans_ref = retrieve_json("$BASE_DIRS{PRODUCTS}/all_products_scans.json");
	if (not defined $scans_ref) {
		$scans_ref = {};
	}

	$scans_ref->{$year} = {
		scans_n => $total_scans + 0,
		unique_scans_n => $total_unique_scans + 0,
		unique_scans_n_by_country => \%countries_for_all_products,
	};

	store_json("$BASE_DIRS{PRODUCTS}/all_products_scans.json", $scans_ref);
}

print STDERR "Ranking products for all countries\n";

foreach my $country_code (sort keys %products_for_countries) {

	my $rank = 0;

	foreach my $code (
		sort {$products_for_countries{$country_code}{$b} <=> $products_for_countries{$country_code}{$a}}
		keys %{$products_for_countries{$country_code}}
		)
	{

		$rank++;
		$countries_ranks_for_products{$code}{$country_code} = $rank;
	}
}

print STDERR "Ranked products for all countries\n";

print STDERR "Process and update all products\n";

# Log products scan counts

open(my $PRODUCTS, ">:encoding(UTF-8)", "$output_dir/scanbot.$year.products.csv")
	or die("Cannot create scanbot.$year.products.csv: $!\n");
open(my $LOG, ">:encoding(UTF-8)", "$output_dir/scanbot.log") or die("Cannot create scanbot.log: $!\n");

my $cumulative_scans
	= 0;    # cumulative total of scans so that we can compute which top products represent 95% of the scans

$i = 0;    # products scanned

foreach my $code (sort {$codes{$b}{u} <=> $codes{$a}{u} || $codes{$b}{n} <=> $codes{$a}{n}} keys %codes) {

	next if $code eq "";

	$i++;

	my $scans_n = $codes{$code}{n};
	my $unique_scans_n = $codes{$code}{u};

	my $bot = '';

	print "$i\t$code\t$codes{$code}{n}\t" . $unique_scans_n . "\t";

	$bot .= "product code $code scanned $scans_n times (from $unique_scans_n ips) - ";

	my %countries = %{$countries_for_products{$code}};

	my $countries_list = "";

	foreach my $cc (sort {$countries{$b} <=> $countries{$a}} keys %countries) {
		print "$cc:$countries{$cc} ";
		$bot .= "$cc:$countries{$cc} ";
		$countries_list .= "country:$cc ";    # for grepping a particular country
	}
	print "\n";

	$bot .= " -- ";

	print "$i - checking product $code - scans: $scans_n unique_scans: $unique_scans_n \n";

	my $product_ref = retrieve_product($code);

	my $found = "NOT_FOUND";
	my $source = "crowdsourcing";
	my $added_countries_list = "";

	if ((defined $product_ref) and ($code ne '') and (defined $product_ref->{code}) and (defined $product_ref->{lc})) {

		my $path = product_path($product_ref);

		$found = "FOUND";

		if (    (defined $product_ref->{data_sources})
			and ($product_ref->{data_sources} =~ /producer/i))
		{
			$source = "producers";
		}

		# Update scans.json

		if ($update_scans) {

			my $scans_ref = retrieve_json("$BASE_DIRS{PRODUCTS}/$path/scans.json");
			if (not defined $scans_ref) {
				$scans_ref = {};
			}

			$scans_ref->{$year} = {
				scans_n => $scans_n + 0,
				unique_scans_n => $unique_scans_n + 0,
				unique_scans_n_by_country => $countries_for_products{$code},
				unique_scans_rank_by_country => $countries_ranks_for_products{$code},
			};

			store_json("$BASE_DIRS{PRODUCTS}/$path/scans.json", $scans_ref);
		}

		# Update popularity_tags + add countries

		if ($update_popularity) {

			$product_ref->{unique_scans_n} = $unique_scans_n + 0;
			$product_ref->{scans_n} = $scans_n + 0;

			my $rank = $countries_ranks_for_products{$code}{"world"};

			# compute the top products

			if (defined $product_ref->{popularity_tags}) {
				my @popularity_tags = @{$product_ref->{popularity_tags}};
				$product_ref->{popularity_tags} = [];
				foreach my $tag (@popularity_tags) {
					if ($tag !~ /-$year/) {
						push @{$product_ref->{popularity_tags}}, $tag;
					}
				}
			}
			else {
				$product_ref->{popularity_tags} = [];
			}

			foreach my $top (10, 50, 100, 500, 1000, 5000, 10000, 50000, 100000) {

				if ($rank <= $top) {
					push @{$product_ref->{popularity_tags}}, "top-" . $top . "-scans-$year";
				}
			}

			foreach my $min (5, 10) {
				if ($unique_scans_n >= $min) {
					push @{$product_ref->{popularity_tags}}, "at-least-" . $min . "-scans-$year";
				}
			}

			$cumulative_scans += $codes{$code}{u};

			foreach my $percent (75, 80, 85, 90) {
				if ($cumulative_scans / $total_unique_scans <= $percent / 100) {
					push @{$product_ref->{popularity_tags}}, "top-" . $percent . "-percent-scans-$year";
				}
				else {
					push @{$product_ref->{popularity_tags}}, "bottom-" . (100 - $percent) . "-percent-scans-$year";
				}
			}

			# Add countries tags based on scans
			my $current_countries = $product_ref->{'countries'};

			my %existing = ();
			foreach my $countryid (@{$product_ref->{countries_tags}}) {
				$existing{$countryid} = 1;
			}

			$bot .= " current countries: $current_countries ";

			my $top_country;

			foreach my $cc (sort {$countries{$b} <=> $countries{$a}} keys %countries) {

				next if $cc eq "world";

				print "$cc:$countries{$cc} ";

				foreach my $top (10, 50, 100, 500, 1000, 5000, 10000, 50000, 100000) {

					if ($countries_ranks_for_products{$code}{$cc} <= $top) {
						push @{$product_ref->{popularity_tags}}, "top-" . $top . "-$cc-scans-$year";
					}
				}

				if (not $top_country) {
					push @{$product_ref->{popularity_tags}}, "top-country-" . $cc . "-scans-$year";
					$top_country = $cc;
				}

				if ($countries{$cc} >= 5) {
					my $country = canonicalize_taxonomy_tag('en', "countries", $cc);

					# Do not add countries for products with a code beginning by 2
					# (codes can be reused by different companies in different countries)
					if (($add_countries) and ($code !~ /^(02|2)/) and (not exists $existing{$country})) {
						print "- adding $country to $product_ref->{countries}\n";
						add_tags_to_field($product_ref, "en", "countries", $country);
						$bot .= "+$country ";
						$added_countries++;
						$added_countries_list .= $country . ',';
					}

					foreach my $min (5, 10) {
						if ($countries{$cc} >= $min) {
							push @{$product_ref->{popularity_tags}}, "at-least-" . $min . "-" . $cc . "-scans-$year";
						}
					}
				}
			}

			if ($added_countries_list ne "") {
				$product_ref->{"countries_beforescanbot"} = $current_countries;
				$changed_products++;

				my $comment = $bot;

				if (0) {
					# notify slack
					#  payload={"text": "A very important thing has occurred! <https://alert-system.com/alerts/1234|Click here> for details!"}

					# curl -X POST --data-urlencode 'payload={"channel": "#general", "username": "webhookbot", "text": "This is posted to #general and comes from a bot named webhookbot.", "icon_emoji": ":ghost:"}' https://openfoodfacts.slack.com/services/hooks/incoming-webhook?token=jMDE8Fzkz9qD7uC9Lq04fbZH

					# my $data =  encode_json(\%response);

					$bot .= " -- <https://world.openfoodfacts.org/product/$code>";

					print "notifying slack: $bot\n";

					require LWP::UserAgent;

					my $ua = LWP::UserAgent->new;

					my $server_endpoint
						= "https://openfoodfacts.slack.com/services/hooks/incoming-webhook?token=jMDE8Fzkz9qD7uC9Lq04fbZH";

					# set custom HTTP request header fields
					my $req = HTTP::Request->new(POST => $server_endpoint);
					$req->header('content-type' => 'application/json');

					# add POST data to HTTP request body
					my $post_data
						= '{"channel": "#bots-alerts", "username": "scanbot", "text": "'
						. $bot
						. '", "icon_emoji": ":ghost:" }';
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

				print "adding countries for $code - $bot\n";
				store_product('scanbot', $product_ref, $comment);
			}
			else {
				print "updating scan count for $code\n";
				store("$BASE_DIRS{PRODUCTS}/$path/product.sto", $product_ref);
				get_products_collection()->replace_one({"_id" => $product_ref->{_id}}, $product_ref, {upsert => 1});
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

if (($changed_products > 0) and ($added_countries > 0)) {

	my $msg = "\nI added $added_countries countries to $changed_products products\n\n";
	print $msg;

	if (1) {
		require LWP::UserAgent;

		my $ua = LWP::UserAgent->new;

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

print "products: $i - scans: $j\n";

