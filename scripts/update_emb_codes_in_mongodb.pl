#!/usr/bin/perl -w

# This file is part of Product Opener.
# 
# Product Opener
# Copyright (C) 2011-2020 Association Open Food Facts
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

use ProductOpener::Display qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Data qw/:all/;

my $emb_codes_collection = get_emb_codes_collection();

foreach my $emb_code (keys %packager_codes) {
	my ($lat, $lng) = get_packager_code_coordinates($emb_code);
	if ((defined $lat) and (defined $lng)) {
		my @geo = ($lng + 0.0, $lat + 0.0);
		next if $geo[0] == 0;
		my $geoJSON = {
			type => 'Point',
			coordinates => \@geo,
		};
		my $document = {
			emb_code => $emb_code,
			loc => $geoJSON,
		};
		$emb_codes_collection->replace_one({ emb_code => $emb_code }, $document, { upsert => 1 });
	}

}

$emb_codes_collection->indexes->create_one( [ loc => '2dsphere' ] );
$emb_codes_collection->indexes->create_one( [ emb_code => 1 ], { unique => 1 } );

exit(0);
