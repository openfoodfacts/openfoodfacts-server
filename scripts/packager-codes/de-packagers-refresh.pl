#/usr/bin/env -S perl -w

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
use autodie;
use open qw(:std :utf8);
use Modern::Perl '2017';

use Encode qw( encode );

use CHI                 ();
use Data::Table         qw( fromCSV );
use Future::AsyncAwait;
use Future::Utils       qw( fmap_scalar fmap0 );
use Geo::Coder::Google  0.20;
use IO::Async::Function ();
use IO::Async::Loop     ();
use Math::BigNum        ();
use Sort::Naturally     qw( ncmp );
use Text::CSV           qw( csv );

use ProductOpener::Config qw/:all/;

my $csv_file     = 'de-export.csv';
my $csv_encoding = 'cp-1252';

my $outfile       = 'DE-merge-UTF-8.csv';
my $nolatlongfile = 'DE-nolatlong.html';

my @address_columns = ( 'Straße / Haus-Nr.', 'Ort');

my $GOOGLE_APIKEY = undef;

my $geocoder;
$geocoder = Geo::Coder::Google->new(
	apiver => 3,
	apikey => $GOOGLE_APIKEY,
	host   => 'maps.google.de',
	hl     => 'en',
	gl     => 'de'
) if defined $GOOGLE_APIKEY;

my $csv = Text::CSV->new(
	{   allow_loose_quotes => 1,
		auto_diag          => 1,
		binary             => 1,
		empty_is_undef     => 1,
		sep_char           => q{;},
		quote_char         => undef,
		escape_char        => undef,
		strict             => 1,
	}
);

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

sub trim { my $s = shift; $s =~ s/^\s+|\s+$//gsmx; return $s };

sub fill_cache {
	my ($cache) = @_;

	if ( -e "$data_root/packager-codes/$outfile" ) {
		my $row_refs = csv(
			in           => "$data_root/packager-codes/$outfile",
			headers      => 'auto',
			sep_char     => q{;},
			quote_char   => q{"}
		);

		foreach my $row_ref (@{$row_refs}) {
			if ( $row_ref->{'lat'} && $row_ref->{'lng'} ) {
				my $address = join q{, }, @{$row_ref}{@address_columns};
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
	my $address     = join q{, }, @{$rowhash_ref}{@address_columns};

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

sub fixup_csv {
	my ($csv_string_ref) = @_;

	# Lines end with separator, parser thinks there's an empty field there
	${$csv_string_ref} =~ s/;$//gsmx;
	${$csv_string_ref} =~ tr/„”“‟/"/;      # Normalize different double quotes
	${$csv_string_ref} =~ s/\r\n//gsmx;    # Remove unquoted embedded CRLF
	# e.g ';OT Ebenheit' in address splitting the field
	${$csv_string_ref} =~ s/;(?=\sOT)/,/gsmx;

	return;
}

sub read_csv {
	open my $in_fh, "<:encoding($csv_encoding)", $csv_file;
	read $in_fh, my $csv_string, -s $in_fh;
	close $in_fh;

	fixup_csv(\$csv_string);

	open my $string_fh, '<:encoding(utf-8)', \( encode( 'utf-8', $csv_string ) );

	return $string_fh;
}

sub make_header {
	my ($fh) = @_;

	my $hrow = $csv->getline($fh);
	@{$hrow} = map { trim($_) } @{$hrow};

	my @header;
	my %seen_hdrs = ();
	foreach my $label ( @{$hrow} ) {
		my $nseen = ++$seen_hdrs{$label};

		if ( $nseen > 1 ) {
			$label = $label . $nseen;
		}

		push @header, $label;
	}

	return \@header;
}

sub make_table {
	my ( $fh, $header_ref ) = @_;

	my $t = Data::Table->new( [], $header_ref );

	# Data::Table::fromCSV doesn't have a good handling of loose quotes
	# at the start/end of a field. Use Text::CSV for reading.
	while (1) {
		my $row = $csv->getline($fh);
		last if $csv->eof;
		if ( defined $row ) {
			$t->addRow($row);
		}
	}

	$t->addCol( undef, 'code', 0 );
	$t->addCol( undef, $_ ) for ( 'lat', 'lng' );

	return $t;
}

async sub process_rows {
	my ($t) = @_;

	return await fmap0 {
		my ($i) = @_;
		my $row_ref = $t->rowRef($i);

		foreach my $col ( @{$row_ref} ) {
			if ( defined $col ) {
				$col = trim($col);
			}
		}

		# if the new approval number is empty,
		# use the egg packing approval number or
		# the old approval number as a fallback code
		my $code
			= $t->elm( $i, 'Neue Zulassungsnummer' )
			|| $t->elm( $i, 'Zulassungsnummer Eierpackstellen' )
			|| ( split /,/, $t->elm( $i, 'Alte Zulassungs-nummern' ) // q{} ) [0];
		$t->setElm( $i, 'code', $code );

		return Future->done();
	}
	    foreach    => [ 0 .. $t->lastRow ],
		concurrent => 15;
}

sub write_csv {
	my ($t) = @_;

	open my $out_fh, '>:encoding(utf-8)', $outfile;
	$t->csv( 1, { file => $out_fh, delimiter => q{;} } );
	close $out_fh;

	return;
}

sub write_nolatlong {
	my ($t) = @_;

	open my $nolatlong_fh, '>:encoding(utf-8)', $nolatlongfile;

	# it's useful to have a list of addresses that weren't geocoded
	my $nolatlong_table
		= $t->match_pattern_hash('!$_{lat} || !$_{lng}');    ## no critic (RequireInterpolationOfMetachars)

	print {$nolatlong_fh} $nolatlong_table->html;

	close $nolatlong_fh;

	return;
}

async sub main {
	fill_cache($cache);

	my $in_fh      = read_csv;
	my $header_ref = make_header($in_fh);
	my $t          = make_table( $in_fh, $header_ref );
	await process_rows($t);
	await geocode_table($t);

	$t->sort( 'code', \&ncmp, Data::Table::ASC );
	write_csv($t);
	write_nolatlong($t);

	exit 0;
}

exit main(@ARGV)->get;
