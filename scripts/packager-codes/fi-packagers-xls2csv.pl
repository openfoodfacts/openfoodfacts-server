#!/usr/bin/env perl -w
# fi-packagers-xls2cvs.pl --

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

use strict;
use warnings;
use utf8;

use Encode qw(decode);
use File::Spec;
use File::Temp ();

use Data::Table;
use Data::Table::Excel qw(excelFileToTable);
use Geo::Coder::Google v0.19.100;
use Geo::Coder::OSM;
use LWP::Simple;
use Readonly;
use URI;

binmode STDOUT, ":encoding(utf8)";

Readonly my $GEOCODE_PROVIDER => 'google';
Readonly my $APIKEY           => undef;
Readonly my $SHEETNAME        => 'Laitoslista';
Readonly my $BASEURL          => URI->new(
	'https://www.ruokavirasto.fi/globalassets/yritykset/elintarvikeala/toiminnan-aloittaminen/elintarvikehuoneistot/'
);
Readonly my @FILES => (
	'liha-alan_laitokset.xls', 'kala-alan_laitokset.xls',
	'maitoalanlaitokset.xls',  'muna-alanlaitokset.xls',
	'varastolaitokset.xls',    'highly-refined-products.xlsx',
	'hyvaksytyt-idattamot.xlsx'
);

my %geocoders = (
	'google' => Geo::Coder::Google->new(
		apikey => $APIKEY,
		host   => 'maps.google.fi',
		region => 'fi'
	),

	'osm' => Geo::Coder::OSM->new
);

my $geocode  = 1;
my $geocoder = $geocoders{$GEOCODE_PROVIDER};
$geocode = $geocode && ( defined $geocoder );
if ( $geocode && $GEOCODE_PROVIDER eq 'google' && ( !defined $APIKEY ) ) {
	warn "Using Google provider requires an API key. Geocoding disabled.\n";
	$geocode = 0;
}

# Map some column names to remove clashes, sanitize them, etc.
my %colNameMaps = (
	'liha-alan_laitokset.xls' => {
		'CA' =>
			'Valvontaviranomainen / Övervakningsmyndighet / Competent authority'
	},

	'kala-alan_laitokset.xls' => {
		'CA' =>
			'Täyssäilykkeiden valmistaminen / Tillverkning av helkonserver / Canned products'
	},

	'varastolaitokset.xls' => {
		'1' =>
			'Pakkasvarasto / Lager för djupfrysta produkter / Store for frozen products',
		'2' =>
			'Jäähdytetty varasto / Lager för avkylda produkter / Store for chilled products',
		'3' =>
			'Jäähdyttämätön varasto / Oavkyld lager / Non-refrigerated store'
	},

	'maitoalanlaitokset.xls' => {
		'Raakamaito / Råmjölk / Rawmilk > 2 000 000 l / vuosi år year' =>
			'Raakamaito yli 2000000l per vuosi',
		'Raakamaito / Råmjölk / Rawmilk < 2 000 000 l / vuosi år year' =>
			'Raakamaito alle 2000000l per vuosi'
	},

	'muna-alanlaitokset.xls' =>
		{ 'C' => 'Siipikarja / Fjäderfä / Poultry' },

	'highly-refined-products.xlsx' => {
		'C' =>
			'Kollageenin tuotantolaitos / Anläggning som framställer kollagen / Establishment producing collagen'
	},
);

sub trim { my $s = shift; $s =~ s { \A \s* | \s* \z } {}gx; return $s }

my $tmp = File::Temp->newdir();

my $tMerged_ref = Data::Table->new();
foreach my $file (@FILES) {

	# Spreadsheet download

	my $url      = URI->new($file)->abs($BASEURL);
	my $fullPath = File::Spec->catfile( $tmp->dirname, $file );
	my $rc       = getstore( $url, $fullPath );

	die "Fetching $url failed with code $rc\n" if is_error($rc);

	# xls -> table

	my $ts_ref = ( excelFileToTable( $fullPath, [$SHEETNAME] ) )[0];
	my $t_ref  = $ts_ref->[0];

	# column 0 = approval number. We don't need lines without approval number.
	$t_ref = $t_ref->match_pattern(q/defined $_->[0] && $_->[0] ne ''/);

	# We don't need empty tables either.
	next if ( $t_ref->nofRow <= 1 );

	# Header row processing

	my $hdrRow_ref = $t_ref->delRow(0);

	for ( my $col = 0; $col <= $#$hdrRow_ref; $col++ ) {
		my $hdr = $hdrRow_ref->[$col];

		if ( !defined $hdr || $hdr eq '' ) {
			$t_ref->delCols( [ $col .. $t_ref->lastCol ] );
			last;
		}

		$hdr = decode( 'iso-8859-1', $hdr );

		$hdr = trim($hdr);
		$hdr =~ s { \s*\n\s* | \b\s{2,}\b } { / }gx;
		$hdr =~ s { \s{2,} } { }gx;

		if ( exists $colNameMaps{$file} && exists $colNameMaps{$file}{$hdr} )
		{
			$hdr = $colNameMaps{$file}{$hdr};
		}

		$t_ref->rename( $col, $hdr );
	}

	# Unify the approval number column name for merging.
	$t_ref->rename( 0, 'Numero / Nummer / Number' );

	if ($geocode) {
		my $colIdx
			= $t_ref->colIndex('Postitoimipaikka / Postanstalt / Post office')
			+ 1;
		$t_ref->addCol( undef, 'lat', $colIdx );
		$t_ref->addCol( undef, 'lng', $colIdx + 1 );
	}

	# Data row processing

	for ( my $row = 0; $row < $t_ref->nofRow; $row++ ) {
		for ( my $col = 0; $col < $t_ref->nofCol; $col++ ) {
			my $text = $t_ref->elm( $row, $col );
			if ( defined $text ) {
				$text = decode( 'iso-8859-1', $text );
				$text = trim($text);
				$text =~ s { /* \s*\n\s* /* } { / }gx;
				$t_ref->setElm( $row, $col, $text );
			}
		}

		if ($geocode) {
			my $street_addr = $t_ref->elm( $row,
				'Käyntiosoite / Besöksadress / Street address' );
			my $postal_addr = $t_ref->elm( $row,
				'Jakeluosoite / Postadress / Postal address' );
			my $addr = $street_addr || $postal_addr;
			if ( $addr ne '' ) {
				my $postal_code = $t_ref->elm( $row,
					'Postinumero / Postnummer / Postal code' );
				my $post_office = $t_ref->elm( $row,
					'Postitoimipaikka / Postanstalt / Post office' );
				my $addr_full
					= join( ", ", $addr, $postal_code, $post_office );

				my $location = $geocoder->geocode( location => $addr_full );
				my ( $lat, $lng );
				if ( $GEOCODE_PROVIDER eq 'google' ) {
					$lat = $location->{geometry}{location}{lat};
					$lng = $location->{geometry}{location}{lng};
				}
				elsif ( $GEOCODE_PROVIDER eq 'osm' ) {
					$lat = $location->{lat};
					$lng = $location->{lon};
				}
				$t_ref->setElm( $row, ['lat'], $lat );
				$t_ref->setElm( $row, ['lng'], $lng );
			}
		}
	}

	$tMerged_ref->rowMerge( $t_ref, { byName => 1, addNewCol => 1 } );
}

print $tMerged_ref->csv( 1, { delimiter => ';' } );
