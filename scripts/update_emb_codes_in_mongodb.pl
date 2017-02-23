#!/usr/bin/perl -w

use CGI::Carp qw(fatalsToBrowser);

use Modern::Perl '2012';
use utf8;

use ProductOpener::Display qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::Tags qw/:all/;

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
