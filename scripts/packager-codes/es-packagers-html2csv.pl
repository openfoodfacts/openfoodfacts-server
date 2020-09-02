#!/usr/bin/env -S perl -w

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

use utf8;
use open      qw(:std :utf8);
use Modern::Perl '2017';
use experimental 'smartmatch';

use List::Util qw( all );

use CHI                 ();
use Data::Table         ();
use Encode::ZapCP1252   qw( fix_cp1252 );
use Future::AsyncAwait;
use Future::Utils       qw( fmap_scalar fmap0 );
use Geo::Coder::Google 0.19_01;    # dev version for the apikey support
use HTML::TableExtract  ();
use IO::Async::Function ();
use IO::Async::Loop     ();
use Math::BigNum        ();
use Sort::Naturally         qw( ncmp );
use Text::CSV           qw( csv );

use ProductOpener::Config qw/:all/;

my @html_headers = (
	'Nº RGSEAA Registration number',
	'Razón Social Enterprise name',
	'Dom. Indl. Adress',
	'Localidad Town',
	'Provincia Province',
	'CCAA Region',
);


# These refer to the processed header
my @address_columns
	= ( 'Dom. Indl./Adress', 'Localidad/Town', 'Provincia/Province', );

my $html_encoding = 'cp1252';
my $html_dir      = 'rgseaa';

my $outfile       = 'ES-merge-UTF-8.csv';
my $nolatlongfile = 'ES-nolatlong.html';

my $GOOGLE_APIKEY = undef;

###########################################

sub trim { my ($s) = @_; $s =~ s/^\s+|\s+$//g; return $s; }

sub clean_col {
	my ($col) = @_;

	fix_cp1252 $col;
	$col = trim $col;
	$col =~ tr/ / /s;
	$col =~ tr/;/,/;
	$col =~ s/\R+/ /g;

	return $col;
}

sub clean_row {
	my ($row_ref) = @_;

	return [ map { clean_col $_ } @{$row_ref} ];
}

sub build_headers {
	my @hdrs = @_;

	my $es = qr{nº rgseaa|razón social|dom\. indl\.|localidad|provincia|ccaa}i;

	return map { s{^($es)\s*}{$1/}r } @hdrs;
}

sub fill_cache {
	my ($cache) = @_;

	if ( -e "$data_root/packager-codes/$outfile" ) {
		my $row_refs = csv(
			in           => "$data_root/packager-codes/$outfile",
			headers      => 'auto',
			keep_headers => \my @headers,
			sep_char     => ';',
			quote_char   => q{"}
		);

		return if not all { $_ ~~ @headers } @address_columns;

		foreach my $row_ref (@{$row_refs}) {
			if ( $row_ref->{'lat'} && $row_ref->{'lng'} ) {
				my $address = join ', ', @{$row_ref}{@address_columns};
				my $lat     = $row_ref->{'lat'};
				my $lng     = $row_ref->{'lng'};
				$address =~ tr/;/,/;
				if ($address) {
					$cache->set( $address, { lat => $lat, lng => $lng } );
				}
			}
		}
	}

	return;
}

###########################################

if ( !-d $html_dir ) {
	die "HTML directory does not exist!";
}

my @html_files = glob "$html_dir/*.html";

my $geocoder;
$geocoder = Geo::Coder::Google->new(
	apiver => 3,
	apikey => $GOOGLE_APIKEY,
	host   => 'maps.google.es',
	hl     => 'en',
	gl     => 'es'
) if defined $GOOGLE_APIKEY;

my $geofun = IO::Async::Function->new(
	code => sub {
		my ($location) = @_;
		my $res;
		if (defined $geocoder ) {
			$res = eval { $geocoder->geocode( location => $location) };
			if ($@) {
				say STDERR "Error geocoding $location: $@";
			}
		}
		return $res;
	},
	max_workers => 10,
);

my $loop = IO::Async::Loop->new;
$loop->add($geofun);

my $cache = CHI->new( driver => 'Memory', global => 1 );
fill_cache($cache);

async sub geocode_address {
	my ($address) = @_;

	my ( $lat, $lng );

	my $cached = $cache->get($address);
	if ($cached) {
		$lat = $cached->{lat};
		$lng = $cached->{lng};
	}
	else {
		my $res = await $geofun->call( args => [$address] );

		if (    exists $res->{'geometry'}
			and exists $res->{'geometry'}{'location'} )
		{
			$lat = $res->{'geometry'}{'location'}{'lat'};
			$lng = $res->{'geometry'}{'location'}{'lng'};

			# Exponential notation won't work
			$lat = Math::BigNum->new($lat)->as_float;
			$lng = Math::BigNum->new($lng)->as_float;

			$cache->set( $address, { lat => $lat, lng => $lng } );
		}
		else {
			say STDERR "Didn't receive coordinates for address: $address";

		}
	}

	return ( $lat, $lng );
}


async sub geocode_row {
	my ( $t_ref, $row_idx ) = @_;

	my $rowhash_ref = $t_ref->rowHashRef($row_idx);
	my $address     = join ", ", @{$rowhash_ref}{@address_columns};

	my ( $lat, $lng ) = await geocode_address($address);

	$t_ref->setElm( $row_idx, 'lat', $lat );
	$t_ref->setElm( $row_idx, 'lng', $lng );
}

async sub geocode_table {
	my ($t_ref) = @_;

	await fmap0 {
		my $i = shift;

		my $rowhash_ref = $t_ref->rowHashRef($i);
		my $address     = join ", ", @{$rowhash_ref}{@address_columns};

		geocode_row( $t_ref, $i );
	}
	  foreach       => [ 0 .. $t_ref->lastRow ],
	  concurrent    => 10;
}

my $tables_f = fmap_scalar {
	my ($file) = @_;

	say "Processing $file...";

	open my $html_fh, "<:encoding($html_encoding)", $file
		or die "Can't open file $!";
	read $html_fh, my $html_content, -s $html_fh
		or die "Can't read file $!";
	close $html_fh
		or warn "Can't close file $!";

	my $te_ref = HTML::TableExtract->new(
		headers => \@html_headers,
		depth   => 0,
		count   => 0,
	);
	$te_ref->parse($html_content);

	my $ht_ref  = $te_ref->first_table_found;
	my @headers = build_headers @{ clean_row( [ $ht_ref->hrow ] ) };
	my @rows    = map { clean_row $_ } $ht_ref->rows;

	my $t_ref = Data::Table->new( \@rows, \@headers, 0 );
	$t_ref->addCol( undef, $_ ) for qw( lat lng );

	say "Geocoding $file...";
	geocode_table($t_ref)
	  ->then_done( ($t_ref) )
	  ->on_fail(
		sub {
			my ($failure) = @_;
			say STDERR "Geocoding table failed with: $failure";
		}
	);
}
  foreach       => \@html_files,
  concurrent    => 10;

my @table_refs = $loop->await($tables_f)->get;

my $merged_table_ref = shift @table_refs;
$merged_table_ref->rowMerge($_) for @table_refs;

# sorting prevents large diffs when the file is regenerated
$merged_table_ref->sort('Nº RGSEAA/Registration number', \&ncmp, 0);

open( my $ofh, '>:encoding(utf-8)', $outfile )
	or die "Can't open $outfile for writing: $!";

$merged_table_ref->csv( 1, { file => $ofh, delimiter => ';' } );

close $ofh
	or die "Can't close $outfile: $!";

open( my $nolatlong_fh, '>:encoding(utf-8)', $nolatlongfile )
	or die "Can't open $nolatlongfile for writing: $!";

# it's useful to have a list of addresses that weren't geocoded
my $nolatlong_table_ref
	= $merged_table_ref->match_pattern_hash('!$_{lat} || !$_{lng}');

print $nolatlong_fh $nolatlong_table_ref->html;

close $nolatlong_fh
	or die "Can't close $nolatlongfile: $!";
