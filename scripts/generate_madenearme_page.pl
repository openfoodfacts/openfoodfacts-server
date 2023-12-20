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

use ProductOpener::PerlStandards;

use CGI::Carp qw(fatalsToBrowser);
use CGI qw/:cgi :form escapeHTML/;

use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/:all/;
use ProductOpener::Paths qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::URL qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;
use Log::Any qw($log);

use ProductOpener::Lang qw/:all/;

# initialize html
sub get_initial_html ($cc) {
	my $html;
	if (open(my $IN, "<:encoding(UTF-8)", "$data_root/madenearme/madenearme-$cc.html")) {

		$html = join("", (<$IN>));
		close $IN;
	}
	else {
		die("$data_root/madenearme/madenearme-$cc.html not found\n");
	}
	return $html;
}

# parse the JSONL to find all products for country with emb_codes_tags
# return an iterator
sub iter_products_from_jsonl ($jsonl_path, $country, $verbose=undef) {
	my $jsonl;
	if ($jsonl_path =~ /\.gz$/) {
		open($jsonl, "-|", "gunzip -c $jsonl_path") or die("can’t open pipe to $jsonl_path");
	}
	else {
		open($jsonl, "<:encoding(UTF-8)", $jsonl_path)
			or die("$jsonl_path not found\n");
	}
	my $is_world = $country eq "en:world";
	my $line_count = 0;
	my $product_count = 0;
	my $start = time();
	# iterator
	return sub {
		while (my $line = <$jsonl>) {
			if ($verbose && !($line_count % 10000)) {
				my $t = time() - $start;
				print("$line_count lines processed ($product_count products) in $t seconds\n");
			}
			$line_count++;
			# quickly verify we have emb_codes_tags and countries_tags
			# without parsing json as it is slow
			my @emb_code_tags = ();
			my @countries_tags = ();
			if ($line =~ /emb_codes_tags["'] *: *(\[[^\]]+\])/) {
				@emb_code_tags = @{decode_json($1)};
				if ($line =~ /countries_tags["'] *: *(\[[^\]]+\])/) {
					@countries_tags = @{decode_json($1)};
				}
			}
			my $product_ref;
			if ((scalar @emb_code_tags)
				&& ($is_world || (grep {$_ eq $country} @countries_tags))) {
				eval {
					$product_ref = decode_json($line);
					1;
				} or next;
				$product_count++;
				return $product_ref;
			}
		}
		# end of iteration
		return;
	};
}

$cc = $ARGV[0];
$lc = $ARGV[1];
$subdomain = $cc;
$formatted_subdomain = format_subdomain($subdomain);
$header = "";
$initjs = "";

$lang = $lc;

if ((not defined $cc) or (not defined $lc)) {
	die("Pass country code (or world) and language code as arguments.\n");
}
else {
	if (defined $country_codes{$cc}) {
		$country = $country_codes{$cc};
	}
	else {
		$country = "en:world";
	}

	print STDERR "Generating map for country code $cc (country: $country) and language code $lc\n";
}

my $html;

$html = get_initial_html($cc);

my %map_options = (uk => "map.setView(new L.LatLng(54.0617609,-3.4433238),6);",);

my $request_ref = {};
my $graph_ref = {};

$log->info("finding products", {lc => $lc, cc => $cc, country => $country}) if $log->is_info();

my $jsonl_path = "$BASE_DIRS{PUBLIC_DATA}/openfoodfacts-products.jsonl.gz";
my $products_iter = iter_products_from_jsonl($jsonl_path, $country);

$request_ref->{map_options} = $product_countap_options{$cc} || "";
my $product_countap_html = map_of_products($products_iter, $request_ref, $graph_ref);

$html =~ s/<HEADER>/$header/;
$html =~ s/<INITJS>/$initjs/;
$html =~ s/<CONTENT>/$product_countap_html/;

binmode(STDOUT, ":encoding(UTF-8)");
print $html;

