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
use Modern::Perl '2019';

use Data::Table;
use Future::Utils   qw( fmap_scalar );
use Future;
use Geo::Coder::Google 0.19_01;    # dev version for the apikey support
use IO::Async::Function;
use IO::Async::Loop;
use IO::Async::SSL;
use Net::Async::HTTP;
use Text::CSV       qw( csv );
use URI;

use ProductOpener::Config qw/:all/;

binmode STDIN,  ':encoding(UTF-8)';
binmode STDOUT, ':encoding(UTF-8)';

my $base_url = URI->new(
	'https://fichiers-publics.agriculture.gouv.fr/dgal/ListesOfficielles/');

# these should match the filenames available from $base_url
my @sections = qw(
	SSA1_ACTIV_GEN            SSA1_VIAN_ONG_DOM
	SSA1_VIAN_COL_LAGO        SSA1_VIAN_GIB_ELEV
	SSA1_VIAN_GIB_SAUV        SSA1_VIAND_HACHE_VSM
	SSA4_AGSANPROBASEVDE_PRV  SSA4B_AS_CE_PRODCOQUI_COV
	SSA4B_AS_CE_PRODPECHE_COV SSA1_LAIT
	SSA1_OEUF                 SSA1_GREN_ESCARG
	SSA4_AGSANGREXPR_PRV      SSA4_AGR_ESVEBO_PRV
	SSA4_AGSANGELAT_PRV       SSA4_AGSANCOLL_PRV
	SSA_PROD_RAFF             SSA4_ASCCC_PRV
);
my $extension = '.txt';
my @address_columns
	= ( 'Adresse/Adress', 'Code postal/Postal code', 'Commune/Town' );

my @urls = map { URI->new_abs( $_ . $extension, $base_url ) } @sections;

my $GOOGLE_APIKEY = undef;
my $geocoder;
$geocoder = Geo::Coder::Google->new(
	apiver => 3,
	apikey => $GOOGLE_APIKEY,
	host   => 'maps.google.fr',
	hl     => 'en',
	gl     => 'fr'
) if defined $GOOGLE_APIKEY;

my $outfile = 'FR-merge-UTF-8.csv';

# use the file from previous run if available to reduce geocoding requests
my %coord_cache;
if ( -e "$data_root/packager-codes/$outfile" ) {
	my $row_refs = csv(
		in         => "$data_root/packager-codes/$outfile",
		headers    => 'auto',
		sep_char   => ';',
		quote_char => q{"}
	);
	foreach my $row_ref (@{$row_refs}) {
		if ( $row_ref->{'lat'} && $row_ref->{'lng'} ) {
			my $address = join ', ', @{$row_ref}{@address_columns};
			my $lat     = $row_ref->{'lat'};
			my $lng     = $row_ref->{'lng'};
			$address =~ tr/;/,/;
			if ($address) {
				$coord_cache{$address}{'lat'} = $lat;
				$coord_cache{$address}{'lng'} = $lng;
			}
		}
	}
}

###################################

sub make_table {
	my $octet_ref = shift;
	my $charset   = shift;
	my $url       = shift;

	open( my $fh, "<:encoding($charset)", $octet_ref )
		or die "Can't open in-memory CSV: $!";

	# The CSV-files have trailing empty columns without separators,
	# which Data::Table doesn't handle. We parse the CSV the hard way.
	my $rows_ref = csv( in => $fh, keep_headers => \my @headers );
	my @data     = map { [ @{$_}{@headers} ] } @{$rows_ref};

	close $fh;

	my $t_ref = Data::Table->new( \@data, \@headers, 0 );

	# fix a broken row from the source data
	if ( $url =~ /SSA4B_AS_CE_PRODCOQUI_COV\.txt\z/ ) {
		$t_ref->match_pattern_hash(
			'$_{"Numéro agrément/Approval number"} eq "34" && $_{SIRET}==301'
		);
		for ( @{ $t_ref->{MATCH} } ) {
			my $r = $t_ref->rowRef($_);
			$r->[1] = join '.', $r->@[ 1 .. 3 ];
			splice @{$r}, 2, -0, ( splice @{$r}, 4 );
			$r->@[ -2 .. -1 ] = undef;
		}
	}

	$t_ref->addCol( $url, 'Section' );

	$t_ref->addCol( undef, $_ ) for qw( lat lng );

	foreach my $row_idx ( 0 .. $t_ref->lastRow ) {
		foreach my $col_idx ( 0 .. $t_ref->lastCol ) {
			my $elm_ref = $t_ref->elmRef( $row_idx, $col_idx );
			if ( defined ${$elm_ref} ) {
				${$elm_ref} =~ tr/;/,/;
				${$elm_ref}
					=~ s/â\200\223/\N{EN DASH}/g;    # Some UTF-8 mixed in...
				${$elm_ref} =~ s/^\s+|\s+$//g;
			}
		}
	}

	return $t_ref;
}

sub geocode_row {
	my $r_ref = shift;

	my $address = join ', ', @{$r_ref}{@address_columns};

	my ( $lat, $lng );

	if ( exists $coord_cache{$address} ) {
		$lat = $coord_cache{$address}{'lat'};
		$lng = $coord_cache{$address}{'lng'};
	}
	elsif ( defined $geocoder ) {
		my $loc = $geocoder->geocode( location => $address );
		if (    exists $loc->{'geometry'}
			and exists $loc->{'geometry'}{'location'} )
		{
			$lat = $loc->{'geometry'}{'location'}{'lat'};
			$lng = $loc->{'geometry'}{'location'}{'lng'};
		}
		else {
			say STDERR "Didn't receive coordinates for address: $address";
		}
	}

	return ( $lat, $lng );
}

my $geocode_table = IO::Async::Function->new(
	code => sub {
		my $t_ref = shift;

		foreach my $row_idx ( 0 .. $t_ref->lastRow ) {
			my ( $lat, $lng ) = geocode_row $t_ref->rowHashRef($row_idx);
			$t_ref->setElm( $row_idx, 'lat', $lat );
			$t_ref->setElm( $row_idx, 'lng', $lng );
		}

		return $t_ref;
	}
);

my $loop = IO::Async::Loop->new();
my $http = Net::Async::HTTP->new( max_connections_per_host => 3 );

$loop->add($http);
$loop->add($geocode_table);

my $tables_f = fmap_scalar {
	my ($url) = @_;
	$http->GET($url)
	  ->on_done( sub { say "Downloading section $url succeeded"; } )
	  ->on_fail(
		  sub {
			  my $failure = shift;
			  say STDERR "Downloading section $url failed: $failure";
		  } )
	  ->then(
		  sub {
			  my ($res_ref) = @_;
			  my $t_ref = make_table $res_ref->content_ref,
				$res_ref->content_charset, $url->as_string;

			  $geocode_table->call( args => [$t_ref] );
		  } );
} foreach       => \@urls,
  concurrent    => 5;

my @table_refs = $loop->await($tables_f)->get;

my $merged_table_ref = shift @table_refs;
$merged_table_ref->rowMerge($_) for @table_refs;

open( my $ofh, '>:encoding(UTF-8)', $outfile )
  or die "Can't open $outfile for writing: $!";

$merged_table_ref->csv( 1, { file => $ofh, delimiter => ';' } );

close $ofh;
