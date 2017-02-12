#!/usr/bin/perl -w

use CGI::Carp qw(fatalsToBrowser);

use Modern::Perl '2012';
use utf8;

use ProductOpener::Display qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::Tags qw/:all/;

foreach my $emb_code (keys %packager_codes) {
	my @geo = undef;
	
	if (exists $packager_codes{$emb_code}) {
		if (exists $packager_codes{$emb_code}{lat}) {
			# some lat/lng have , for floating point numbers
			my $lat = $packager_codes{$emb_code}{lat};
			my $lng = $packager_codes{$emb_code}{lng};
			$lat =~ s/,/\./g;
			$lng =~ s/,/\./g;
			
			$lat =~ s/,/\./g;
			@geo = ($lng, $lat);
		}
		elsif (exists $packager_codes{$emb_code}{fsa_rating_business_geo_lat}) {
			@geo = ($packager_codes{$emb_code}{fsa_rating_business_geo_lng}, $packager_codes{$emb_code}{fsa_rating_business_geo_lat});
		}
		elsif (($packager_codes{$emb_code}{cc} eq 'uk') and (defined $packager_codes{$emb_code}{canon_local_authority})) {
			my $address = 'uk' . '.' . $packager_codes{$emb_code}{canon_local_authority};
			if (exists $geocode_addresses{$address}) {
				@geo = ($geocode_addresses{$address}[1], $geocode_addresses{$address}[0]);
			}
		}
	}
	
	my $city_code = get_city_code($emb_code);
	
	if ((not @geo) and (defined $emb_codes_geo{$city_code})) {
		# some lat/lng have , for floating point numbers
		my $lat = $emb_codes_geo{$city_code}[0];
		my $lng = $emb_codes_geo{$city_code}[1];
		$lat =~ s/,/\./g;
		$lng =~ s/,/\./g;
		@geo = ($lng, $lat);
	}
	
	if (@geo and (defined $geo[0]) and (defined $geo[1])) {
		@geo = ($geo[0] + 0.0, $geo[1] + 0.0);
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
