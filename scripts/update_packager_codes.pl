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

use autodie;
use utf8;
use Modern::Perl '2017';
use experimental qw/switch/;

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Tags qw/:all/;

use Term::ANSIColor;
use Carp;
use JSON::PP;
use Text::CSV ();


say {*STDERR} "loading geocoded addresses";

if (opendir DH, "$data_root/packager-codes") {
	foreach my $file (readdir DH) {
		if ($file =~ /geocode-(\w+).json/sxm) {
			my $country = lc $1;
			say "loading geocode for country $country";
			open my $IN, '<:encoding(windows-1252)', "$data_root/packager-codes/$file";
			my $json = join q{}, (<$IN>);
			close $IN;
			my $json_ref =  decode_json($json) or carp "could not decode json: $!\n";

			my $addresses_ref = $json_ref->{data};
			foreach my $item_ref (@{$addresses_ref}) {
				$geocode_addresses{$country . q{.} . $item_ref->{item}{address}} = [$item_ref->{item}{latitude},$item_ref->{item}{longitude}];
				#print STDERR $country . '.' . $item_ref->{item}{address} . '--> ' . $item_ref->{item}{latitude} . ", " . $item_ref->{item}{longitude} . "\n";
			}
		}
		elsif ($file =~ /openlylocal/xsm) {
			my $country = 'uk';
			say "loading geocode for country $country - $file";
			open my $IN, '<:encoding(windows-1252)', "$data_root/packager-codes/$file";
			my $json = join q{}, (<$IN>);
			close $IN;
			my $json_ref =  decode_json($json) or say "could not decode json: $!";

			my $addresses_ref = $json_ref->{councils};
			foreach my $item_ref (@{$addresses_ref}) {
				my $canon_local_authority = get_canon_local_authority($item_ref->{name});
				$geocode_addresses{$country . q{.} . $canon_local_authority} = [$item_ref->{lat},$item_ref->{lng}];
				#print  "Name: " . $item_ref->{name} . " canon: " . $country . '.' . $canon_local_authority . '--> ' . $item_ref->{lat} . ", " . $item_ref->{item}{lng} . "\n";
			}
		}
	}
	closedir DH;
}
else {
	carp "could not open $data_root/packager-codes: $!\n";
}


# Load packager codes data

%packager_codes = ();

sub trim { my ($s) = @_; $s =~ s/^\s+|\s+$//sxmg; return $s };

sub normalize_code {
	my ( $cc, $code ) = @_;

	my $arg = do {
		given ($cc) {
			"BE $code EC" when 'be';
			"CH-$code"    when 'ch';
			"DE $code EC" when 'de';
			"EE $code EC" when 'ee';
			"ES $code CE" when 'es';
			"FI $code EC" when 'fi';
			"FR $code CE" when 'fr';
			"$code EC"    when 'hu';
			"$code EC"    when 'it';
			"LT $code EC" when 'lt';
			"LU $code EC" when 'lu';
			"PL $code EC" when 'pl';
			"$code EC"    when 'rs';
			"SE $code EC" when 'se';
			"SK $code EC" when 'sk';
			"UK $code EC" when 'uk';
			join q{  }, uc($cc), $code, 'EC';
		}
	};

	return normalize_packager_codes($arg);
}

my %code_processor = (
	it => sub {
		my ($c) = @_;
		$c =~ s/^CE //sxm;
		return $c;
	},
	uk => sub {
		my ($c) = @_;
		$c =~ s/(\s|\/)*ec$//isxm;
		$c =~ s/^uk//isxm;
		return $c;
	},
);

sub process_code {
	my ($cc, $code) = @_;

	if (exists $code_processor{$cc}) {
		$code = $code_processor{$cc}->($code);
	}

	$code = normalize_code( $cc, $code );

	$code = get_string_id_for_lang( 'no_language', $code );

	$code =~ s/-($ec_code_regexp)$/-ec/isxm;

	return $code;
}

sub normalize_local_authority {
	my ( $country, $authority, $district ) = @_;

	foreach my $local_authority (
		split /[,\/]/, (join ', ', $authority, $district ) )
	{
		my $canon_authority = get_canon_local_authority($local_authority);
		if (defined $geocode_addresses{
				join q{.}, $country, $canon_authority } )
		{
			return $canon_authority;
		}
	}

	return;
}

my $sep_set = [ q{;}, qq{\t} ];

my %approval_key = (
	be => 'no_agrement',
	ch => 'bew_nr',
	de => 'code',
	ee => 'tunnusnumber',
	es => 'n_rgseaa',
	fi => 'numero',
	fr => 'numero_agrement',
	hu => 'code',
	it => 'approvalnumber',
	lt => 'vet_approval_no',
	lu => 'zulassungsnummer',
	pl => 'code',
	rs => 'approval_number',
	se => 'nr',
	sk => 'schvaľovacie_čislo',
	uk => 'approval_number',
);

say {*STDERR} "loading packager codes";

my $found    = 0;
my $notfound = 0;

if (opendir DH, "$data_root/packager-codes") {
	foreach my $file (readdir DH) {
		if ( $file =~ /(\w+)-merge(-UTF-8)?[.][ct]sv$/isxm ) {
			my $country  = lc $1;
			my $encoding = 'windows-1252';
			if ( defined $2 ) {
				$encoding = $2;
				$encoding =~ s/^-//sxm;
			}

			if ( not exists $approval_key{$country} ) {
				say {*STDERR}
					"Approval number column not set for '$country'! Skipping...";
				next;
			}

			say "loading packager codes for country '$country'";

			my $key = $approval_key{$country};

			my $abs_file = "$data_root/packager-codes/$file";
			open my $in_fh, '<', $abs_file;

			my $parser = Text::CSV->new(
				{   quote_char     => q{"},
					binary         => 1,
					empty_is_undef => 1
				}
			) or croak q{} . Text::CSV->error_diag();

			$parser->header(
				$in_fh,
				{   sep_set            => $sep_set,
					munge_column_names => sub {
						my ($col) = @_;
						$col =~ s{/.*}{}sxm;
						$col = get_string_id_for_lang( 'no_language', $col );
						$col =~ s{-}{_}gsxm;
						( $col eq 'latitude' )  and $col = 'lat';
						( $col eq 'longitude' ) and $col = 'lng';
						return $col;
					}
				}
			);

			binmode $in_fh, ":encoding($encoding)";

			while ( my $row = $parser->getline_hr($in_fh) ) {
				my $code = $row->{$key};
				next if not $code;

				$code = process_code( $country, $code );

				# if we already have some info for the packager
				# code from a previous line, keep it
				if ( not defined $packager_codes{$code} ) {
					$packager_codes{$code} = { cc => $country };
				}

				while ( my ( $k, $v ) = each %{$row} ) {

					# do not overwrite with empty values
					# in case we already have some info
					# from another line with the same code
					# e.g. current CH file contains
					# multiple lines for CH 336 with geo
					# info missing on last line. bug #781
					if (    ( defined $v )
						and ( ( $v ne q{} ) and ( $v ne '\N' ) ) )
					{

						if ( ( $k eq 'lat' ) or ( $k eq 'lng' ) ) {
							$v =~ s/,/./sxm;
						}

						$v =~ s/\R+$//sxm;
						$v = trim($v);

						$packager_codes{$code}{$k} = $v;
					}

					if ( not defined $packager_codes{$code}{$k} ) {
						$packager_codes{$code}{$k} = q{};
					}
				}

				# Normalize local authority
				if ( $country eq 'uk' ) {

					my $authority = $packager_codes{$code}{local_authority};
					my $district  = $packager_codes{$code}{district};

					my $canon_authority
						= normalize_local_authority( $country, $authority,
						$district );

					if ( defined $canon_authority ) {
						$packager_codes{$code}{canon_local_authority}
							= $canon_authority;
						$found++;
					}
					else {
						$notfound++;
					}
				}
			}

			close $in_fh;

			if ( $country eq 'uk' ) {
				say
					"UK - found $found local authorities, not found: $notfound";
			}
		}
	}
	closedir DH;

}
else {
	carp "could not open $data_root/packager-codes: $!\n";
}

# Check that we have correct lat and lng fields
foreach my $code ( sort keys %packager_codes ) {
	foreach my $coordinate ( 'lat', 'lng' ) {
		if (   ( not defined $packager_codes{$code}{$coordinate} )
			or ( $packager_codes{$code}{$coordinate} eq q{} ) )
		{
			#print STDERR "$code\tmissing $coordinate\n";
		}
		elsif (
			$packager_codes{$code}{$coordinate} !~ m{
														^

														-?
														\d+
														[.,]
														\d+

														$
												}sxm
			)
		{
			my $invalid = $packager_codes{$code}{$coordinate};
			my $msg = "$code\tinvalid $coordinate\t$invalid";
			say {*STDERR} colored($msg, 'red');
			delete $packager_codes{$code}{$coordinate};
		}
	}
}

store("$data_root/packager-codes/packager_codes.sto", \%packager_codes);
store("$data_root/packager-codes/geocode_addresses.sto", \%geocode_addresses);
