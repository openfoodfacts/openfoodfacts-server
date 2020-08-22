#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2019 Association Open Food Facts
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

use ProductOpener::GeoIP;

my $year = $ARGV[0];

defined $year or die("Need to pass year 2019 or 2020 etc. as first argument.");

print STDERR "Running scanbot for year $year\n";

my %codes = ();

my $j = 0;    # API calls (or scans if logs have been filtered to keep only scans)

# 139.167.246.115 - - [02/Jan/2019:17:46:57 +0100] "GET /api/v0/product/123.json?f

while (<STDIN>)
{
	my $line = $_;
	my $ip = $_;
	$ip =~ s/\s.*//;
	chomp($ip);

	if ($line =~ /\/(\d+)\.json/) {

		$j++;
		my $code = $1;

		# Skip bogus codes
		
		($code eq "1") and next;
		($code eq "15600703") and next;

		(defined $codes{$code}) or $codes{$code} = {n => 0, ips => {}};

		$codes{$code}{n}++;
		$codes{$code}{ips}{$ip}++;
	}
}

my $changed_products = 0;
my $added_countries = 0;

# Count unique ips

my $total_scans = 0;

foreach my $code (keys %codes) {
	$codes{$code}{u} = scalar keys %{$codes{$code}{ips}};
	$total_scans += $codes{$code}{u};
}

# Log products scan counts

open (my $PRODUCTS, ">:encoding(UTF-8)", "scanbot.products.csv") or die("Cannot create scanbot.products.csv: $!\n");
open (my $LOG, ">:encoding(UTF-8)", "scanbot.log") or die("Cannot create scanbot.log: $!\n");


my $rank             = 0;    # existing products scanned
my $cumulative_scans = 0;    # cumulative total of scans so that we can compute which top products represent 95% of the scans
my %rank_by_country  = ();

my $i = 0;    # products scanned

foreach my $code (sort { $codes{$b}{u} <=> $codes{$a}{u} || $codes{$b}{n} <=> $codes{$a}{n} } keys %codes) {

	next if $code eq "";

	$i++;

	my $scans_n = $codes{$code}{n};
	my $unique_scans_n = $codes{$code}{u};

	my $bot = '';

	my %countries = ();
	foreach my $ip (keys %{$codes{$code}{ips}}) {
		my $countrycode = ProductOpener::GeoIP::get_country_code_for_ip($ip);
		if ((defined $countrycode) and ($countrycode ne "")) {
			$countrycode = lc($countrycode);
			$countries{$countrycode}++;
		}
	}

	print "$i\t$code\t$codes{$code}{n}\t" . $unique_scans_n . "\t";

	$bot .= "product code $code scanned $scans_n times (from $unique_scans_n ips) - ";

	foreach my $cc (sort { $countries{$b} <=> $countries{$a} } keys %countries) {
		print "$cc:$countries{$cc} ";
		$bot .= "$cc:$countries{$cc} ";
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

		if ((defined $product_ref->{data_sources}) 
			and ($product_ref->{data_sources} =~ /producer/i)) {
			$source = "producers";
		}

		$lc = $product_ref->{lc};

		$product_ref->{unique_scans_n} = $unique_scans_n + 0;
		$product_ref->{scans_n} = $scans_n + 0;

		$rank++;

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

		foreach my $percent (90, 95) {
			if ($cumulative_scans / $total_scans <= $percent / 100) {
				push @{$product_ref->{popularity_tags}}, "top-" . $percent . "-percent-scans-$year";
			}
			else {
				push @{$product_ref->{popularity_tags}}, "bottom-" . (100 - $percent) . "-percent-scans-$year";
			}
		}

		# Add countries tags based on scans
		my $field = 'countries';

		my $current_countries = $product_ref->{$field};

		my %existing = ();
		foreach my $countryid (@{$product_ref->{countries_tags}}) {
			$existing{$countryid} = 1;
		}

		$bot .= " current countries: $current_countries -- adding ";

		my $top_country;

		foreach my $cc (sort { $countries{$b} <=> $countries{$a} } keys %countries) {
			print "$cc:$countries{$cc} ";

			defined $rank_by_country{$cc} or $rank_by_country{$cc} = 0;
			$rank_by_country{$cc}++;

			foreach my $top (10, 50, 100, 500, 1000, 5000, 10000, 50000, 100000) {

				if ($rank_by_country{$cc} <= $top) {
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
				if (($code !~ /^(02|2)/) and (not exists $existing{$country})) {
					print "- adding $country to $product_ref->{countries}\n";
					$product_ref->{countries} .= ", $country";
					$bot .= "+$country ";
					$added_countries++;
					$added_countries_list .= $country .',';
				}

				foreach my $min (5, 10) {
					if ($countries{$cc} >= $min) {
						push @{$product_ref->{popularity_tags}}, "at-least-" . $min . "-" . $cc . "-scans-$year";
					}
				}
			}
		}

		if ($product_ref->{$field} ne $current_countries) {
			$product_ref->{"countries_beforescanbot"} = $current_countries;
			$changed_products++;

			if ($product_ref->{$field} =~ /^, /) {
				$product_ref->{$field} = $';
			}

			if (defined $taxonomy_fields{$field}) {
				$product_ref->{$field . "_hierarchy" } = [ gen_tags_hierarchy_taxonomy($lc, $field, $product_ref->{$field}) ];
				$product_ref->{$field . "_tags" } = [];
				foreach my $tag (@{$product_ref->{$field . "_hierarchy" }}) {
					push @{$product_ref->{$field . "_tags" }}, get_taxonomyid($lc, $tag);
				}
			}

			if (defined $hierarchy_fields{$field}) {
				$product_ref->{$field . "_hierarchy" } = [ gen_tags_hierarchy($field, $product_ref->{$field}) ];
				$product_ref->{$field . "_tags" } = [];
				foreach my $tag (@{$product_ref->{$field . "_hierarchy" }}) {
					if (get_fileid($tag) ne '') {
						push @{$product_ref->{$field . "_tags" }}, get_fileid($tag);
					}
				}
			}

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

				my $server_endpoint = "https://openfoodfacts.slack.com/services/hooks/incoming-webhook?token=jMDE8Fzkz9qD7uC9Lq04fbZH";

				# set custom HTTP request header fields
				my $req = HTTP::Request->new(POST => $server_endpoint);
				$req->header('content-type' => 'application/json');

				# add POST data to HTTP request body
				my $post_data = '{"channel": "#bots-alerts", "username": "scanbot", "text": "' . $bot . '", "icon_emoji": ":ghost:" }';
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

			$User_id = 'scanbot';
			store_product($product_ref, $comment);
		}
		else {
			print "updating scan count for $code\n";
			store("$data_root/products/$path/product.sto", $product_ref);
			get_products_collection()->replace_one({"_id" => $product_ref->{_id}}, $product_ref, { upsert => 1 });
		}
	}

	$added_countries_list =~ s/,$//;

	print $code . "\t" . $scans_n . "\t" . $unique_scans_n . "\t" . $found . "\t" . $source . "\t" . $added_countries_list . "\n";
	print $PRODUCTS $code . "\t" . $scans_n . "\t" . $unique_scans_n . "\t" . $found . "\t" . $source . "\t" . $added_countries_list . "\n";

	print $LOG $bot . "\n";

	print $bot . "\n";
}

if (($changed_products > 0) and ($added_countries > 0)) {

	my $msg = "\nI added $added_countries countries to $changed_products products\n\n";
	print $msg;

	if (1) {
		require LWP::UserAgent;

		my $ua = LWP::UserAgent->new;

		my $server_endpoint = "https://openfoodfacts.slack.com/services/hooks/incoming-webhook?token=jMDE8Fzkz9qD7uC9Lq04fbZH";

		# set custom HTTP request header fields
		my $req = HTTP::Request->new(POST => $server_endpoint);
		$req->header('content-type' => 'application/json');

		# add POST data to HTTP request body
		my $post_data = '{"channel": "#bots-alerts", "username": "scanbot", "text": "' . $msg . '", "icon_emoji": ":ghost:" }';
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

