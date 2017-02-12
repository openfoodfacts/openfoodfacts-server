#!/usr/bin/perl

# This file is part of Product Opener.
# 
# Product Opener
# Copyright (C) 2017 Association Open Food Facts
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
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

use Modern::Perl '2012';
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

ProductOpener::Display::init();
use ProductOpener::Lang qw/:all/;

my $north = decode utf8=>param('north');
my $south = decode utf8=>param('south');
my $east = decode utf8=>param('east');
my $west = decode utf8=>param('west');
my $zoom = decode utf8=>param('zoom');

if ((not $north) or (not $south) or (not $east) or (not $west)) {
	display_error('error', 404);
}

$north = $north * 1.0;
$south = $south * 1.0;
$east = $east * 1.0;
$west = $west * 1.0;

my $geometry = { "type" => "Polygon", "coordinates" => [ [
	[ $west, $south ],
	[ $west, $north ],
	[ $east, $north ],
	[ $east, $south ],
	[ $west, $south ]
] ]};

my $aggregate_parameters = [
		{ "\$unwind" => "\$emb_codes_tags" },
		{ "\$lookup" =>
			{
			"from" => "emb_codes",
			"localField" => "emb_codes_tags",
			"foreignField" => "emb_code",
			"as" => "emb_codes_coordinates"
			}
		},
		{ "\$unwind" => "\$emb_codes_coordinates" },
		{ "\$match" => { "emb_codes_coordinates.loc" => { "\$geoWithin" => { "\$geometry" => $geometry } } } },
		{ "\$group" => {  "_id" => { "emb_code" => "\$emb_codes_coordinates.emb_code", "loc" => "\$emb_codes_coordinates.loc" }, "count" => { "\$sum" => 1 } } }
		];

print STDERR encode_json($aggregate_parameters)."\n";

my $results;
eval {
	$results = $products_collection->aggregate($aggregate_parameters);
};
if ($@) {
	print STDERR "emb_codes.pl - MongoDB error: $@ - retrying once\n";
	# maybe $connection auto-reconnects but $database and $products_collection still reference the old connection?
	
	# opening new connection
	eval {
		$connection = MongoDB->connect();
		$database = $connection->get_database($mongodb);
		$products_collection = $database->get_collection('products');
	};
	if ($@) {
		print STDERR "emb_codes.pl - MongoDB error: $@ - reconnecting failed\n";
		display_error('error querying data', 500);
	}
	else {
		print STDERR "emb_codes.pl - MongoDB error: $@ - reconnected ok\n";
		eval {
			$results = $products_collection->aggregate($aggregate_parameters);
		};
		print STDERR "emb_codes.pl - MongoDB error: $@ - ok\n";	
	}
}

my @features = ();

while (my $doc = $results->next) {
	my $val = $doc->{_id};
	my $feature = {
		type => 'Feature',
		geometry => $val->{loc},
		properties => {
			emb_code_tag => $val->{emb_code},
			products => $doc->{count},
			emb_code => normalize_packager_codes($val->{emb_code})
		}
	};
	push @features, $feature;
}

my $data = {
	type => 'FeatureCollection',
	features => \@features,
};

my $json = encode_json($data);
print header( -type => 'application/geo+json', -charset => 'utf-8', -access_control_allow_origin => '*', -cache_control => 'public, max-age: 10080' ) . $json;
