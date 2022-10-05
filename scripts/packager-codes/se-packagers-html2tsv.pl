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

use autodie;
use utf8;
use open qw(:std :utf8);
use Modern::Perl '2017';

use CHI                 ();
use Data::Table         ();
use Future::AsyncAwait;
use Future::Utils       qw( fmap_scalar fmap0 );
use Geo::Coder::Google  0.20;
use HTML::TableExtract  ();
use IO::Async::Function ();
use IO::Async::Loop     ();
use Math::BigNum        ();
use Net::Async::HTTP    ();
use Sort::Naturally     qw( ncmp );
use Text::CSV           qw( csv );
use URI                 ();

use ProductOpener::Config qw/:all/;

my @html_headers = (
	'Nr',               'Namn',
	'Postadress',       'Kommun',
	'Län',              'Kategori',
	'Övrig verksamhet', 'Djurslag',
	'Kontrollerande myndighet',
);

my $base_url
	= 'https://www.livsmedelsverket.se'
	. '/produktion-handel--kontroll'
	. '/livsmedelskontroll'
	. '/livsmedelsanlaggningar'
	. '/eu-godkanda-anlaggningar/';

my @sections = qw(
	sektion-0---anlaggningar-med-allman-verksamhet
	sektion-i---kott-fran-tama-hov--och-klovdjur
	sektion-ii---kott-fran-fjaderfa-och-hardjur
	sektion-iii---kott-fran-hagnat-vilt
	sektion-iv---kott-fran-frilevande-vilt
	sektion-v---malet-kott-kottberedningar-och-maskinurbenat-kott
	sektion-vi---kottprodukter
	sektion-vii---levande-tvaskaliga-blotdjur
	sektion-viii---fiskprodukter-och-fiskefartyg
	sektion-ix---obehandlad-mjolk-och-mjolkprodukter
	sektion-x---agg-och-aggprodukter
	sektion-xi---grodlar-och-sniglar
	sektion-xii---utsmalt-djurfett-och-fettgrevar
	sektion-xiii---behandlade-magar-urinblasor-och-tarmar
	sektion-xiv---gelatin
	sektion-xv---kollagen
	xvi-hogforadlade-produkter
);

my $address_col = 'Postadress';

my @mergeable_cols = (
	'Kategori', 'Övrig verksamhet',
	'Djurslag', 'Kontrollerande myndighet',
);

my $outfile       = 'SE-merge-UTF-8.tsv';
my $nolatlongfile = 'SE-nolatlong.html';

my $GOOGLE_APIKEY = undef;

my $geocoder;
$geocoder = Geo::Coder::Google->new(
	apiver => 3,
	apikey => $GOOGLE_APIKEY,
	host   => 'maps.google.se',
	hl     => 'en',
	gl     => 'se'
) if defined $GOOGLE_APIKEY;

my $cache = CHI->new( driver => 'Memory', global => 1 );

my $loop = IO::Async::Loop->new;

my $geofun = IO::Async::Function->new(
	code => sub {
		my ($location) = @_;
		my $res;
		if (defined $geocoder ) {
			$res = eval { $geocoder->geocode( location => $location) };
			if ($@) {
				say {*STDERR} "Error geocoding $location: $@";
			}
		}
		return $res;
	},
	max_workers => 15,
);

$loop->add($geofun);

sub trim { my ($s) = @_; $s =~ s/^\s+|\s+$//sxmg; return $s };

sub clean_col {
	my ($col) = @_;

	$col = trim($col);

	return $col;
}

sub clean_row {
	my ($row_ref) = @_;

	for ( 0 .. $#{$row_ref} ) {
		my $value = $row_ref->[$_];
		if ( defined $value ) {
			$row_ref->[$_] = clean_col( $row_ref->[$_] );
		}
	}

	return;
}

sub fill_cache {
	my ($cache) = @_;

	if ( -e "$data_root/packager-codes/$outfile" ) {
		my $row_refs = csv(
			in           => "$data_root/packager-codes/$outfile",
			headers      => 'auto',
			sep_char     => qq{\t},
			quote_char   => q{"}
		);

		foreach my $row_ref (@{$row_refs}) {
			if ( $row_ref->{'lat'} && $row_ref->{'lng'} ) {
				my $address = $row_ref->{$address_col};
				my $lat     = $row_ref->{'lat'};
				my $lng     = $row_ref->{'lng'};
				if ($address) {
					$cache->set( $address, { lat => $lat, lng => $lng } );
				}
			}
		}
	}

	return;
}

sub merge_rows {
	my ( $r1_ref, $r2_ref, $cols_ref ) = @_;

	foreach my $col ( @{$cols_ref} ) {
		my $val1 = $r1_ref->[$col];
		my $val2 = $r2_ref->[$col];

		next if not defined $val2;

		if ( not defined $val1 ) {
			$r1_ref->[$col] = $val2;
			next;
		}

		for ( split q{ }, $val2 ) {
			if ( $val1 !~ m{ (?: ^ | \s ) \Q$_\E (?: $ | \s ) }isxm ) {
				$r1_ref->[$col] .= " $_";
			}
		}
	}

	return;
}

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
			say {*STDERR} "Didn't receive coordinates for address: $address";

		}
	}

	return ( $lat, $lng );
}

async sub geocode_row {
	my ( $t, $row_idx ) = @_;

	my $rowhash_ref = $t->rowHashRef($row_idx);
	my $address     = $rowhash_ref->{$address_col};

	my ( $lat, $lng ) = await geocode_address($address);

	$t->setElm( $row_idx, 'lat', $lat );
	$t->setElm( $row_idx, 'lng', $lng );
}


async sub geocode_table {
	my ($t) = @_;

	await fmap0 {
		my ($i) = @_;
		geocode_row( $t, $i );
	}
	  foreach    => [ 0 .. $t->lastRow ],
	  concurrent => 15;
}

my @urls = map { URI->new_abs($_, $base_url) } @sections;

my $http = Net::Async::HTTP->new( max_connections_per_host => 4 );
$loop->add($http);

fill_cache($cache);

my $tables_f = fmap_scalar {
	my ($url) = @_;
	$http->GET($url)
	  ->on_done( sub { say "Downloading section $url succeeded"; } )
	  ->on_fail(
		  sub {
			  my $failure = shift;
			  say {*STDERR} "Downloading $url failed: $failure";
		  }
		 )
	  ->then(
		  sub {
			  my ($res) = @_;

			  my $te = HTML::TableExtract->new(
				  headers      => \@html_headers,
				  depth        => 0,
				  count        => 0,
				  br_translate => 0
				 );
			  $te->parse($res->decoded_content);

			  my $ht = $te->first_table_found;

			  my @headers = $ht->hrow;
			  clean_row( \@headers );

			  my $t = Data::Table->new( [], \@headers );

			  foreach my $row ( $ht->rows ) {
				  clean_row($row);
				  $t->addRow($row);
			  }

			  $t->addCol( undef, $_ ) for ( 'lat', 'lng' );

			  say "Geocoding $url...";
			  return geocode_table($t)
				->then_done( ($t) )
				->on_fail(
					sub {
						my ($failure) = @_;
						say {*STDERR} "Geocoding table failed with: $failure";
					}
				   );
		  }
		 )
}
  foreach    => \@urls,
  concurrent => 5;

my @tables = $loop->await( $tables_f )->get;

my $merged_table = shift @tables;
$merged_table->rowMerge($_) for @tables;

my @merge_ids = map { $merged_table->colIndex($_) } @mergeable_cols;
my @delete_rowids;
$merged_table->each_group(
	['Nr'],
	sub {
		my $rowids_ref    = $_[1];
		my $rowrefs_ref   = $merged_table->rowRefs($rowids_ref);
		my $first_row_ref = shift @{$rowrefs_ref};

		merge_rows( $first_row_ref, $_, \@merge_ids ) for @{$rowrefs_ref};

		shift @{$rowids_ref};
		push @delete_rowids, @{$rowids_ref};
	}
);
$merged_table->delRows( \@delete_rowids );

$merged_table->sort( 'Nr', \&ncmp, Data::Table::ASC );

open my $ofh, '>:encoding(utf-8)', $outfile;

$merged_table->tsv( 1, { file => $ofh } );

close $ofh;

open my $nolatlong_fh, '>:encoding(utf-8)', $nolatlongfile;

# it's useful to have a list of addresses that weren't geocoded
my $nolatlong_table
	= $merged_table->match_pattern_hash('!$_{lat} || !$_{lng}'); ## no critic (RequireInterpolationOfMetachars)

print {$nolatlong_fh} $nolatlong_table->html;

close $nolatlong_fh;
