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

use Modern::Perl '2017';
use utf8;

use CGI::Carp qw(fatalsToBrowser);
use CGI qw/:cgi :form escapeHTML/;

use ProductOpener::Config qw/:all/;
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

if (open(my $IN, "<:encoding(UTF-8)", "$data_root/madenearme/madenearme-$cc.html")) {

	$html = join("", (<$IN>));
	close $IN;
}
else {
	die("$data_root/madenearme/madenearme-$cc.html not found\n");
}

my %map_options =
(
uk => "map.setView(new L.LatLng(54.0617609,-3.4433238),6);",
);

my $request_ref = {};
my $query_ref = {};
my $graph_ref = {};

$log->info("building query", { lc => $lc, cc => $cc, query => $query_ref }) if $log->is_info();

$query_ref->{lc} = $lc;

# We want products with emb codes
$query_ref->{"emb_codes_tags"} = { '$exists' => 1 };

$request_ref->{map_options} = $map_options{$cc} || "";

my $map_html = search_and_map_products($request_ref, $query_ref, $graph_ref);


$html =~ s/<HEADER>/$header/;
$html =~ s/<INITJS>/$initjs/;
$html =~ s/<CONTENT>/$map_html/;

binmode(STDOUT, ":encoding(UTF-8)");
print $html;


