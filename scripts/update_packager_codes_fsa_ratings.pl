#!/usr/bin/perl -w

# This file is part of Product Opener.
# 
# Product Opener
# Copyright (C) 2011-2018 Association Open Food Facts
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

use Modern::Perl '2012';
use utf8;

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Tags qw/:all/;

use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;
use LWP::Simple;


my $packager_codes_ref = retrieve("$data_root/packager-codes/packager_codes.sto");
if (not defined $packager_codes_ref) {
	print "Could $data_root/packager-codes/packager_codes.sto \n";
	exit;
}


open (my $IN, q{<}, "$data_root/packager-codes/uk_packager_codes_fsa_rating_ids.csv") or die("could not open $data_root/packager-codes/uk_packager_codes_fsa_rating_ids.csv : $!\n");
my %fsa_rating_ids = ();
while (<$IN>) {
	chomp;
	if (/\t/) {
		my $code = $`;
		my $id = $';
		$id =~ s/(\r|\n)+$//;
		$fsa_rating_ids{$code} = $id;
		print "code $code --> rating id $id\n";
	}
}
close $IN;


my @codes = ();

if ($ARGV[0]) {
	@codes = @ARGV;
}
else {

	open (my $IN, q{<}, "$data_root/lists/packager-codes.uk.en.html") or print "Could not open $data_root/lists/packager-codes.uk.en.html : $!\n";
	while (<$IN>) {
		if (/packager-code\/(uk-([^"]+)-ec)/) {
			push @codes, $1;
		}
	}
	close $IN;

}

my $ncodes = 0;
my $nfound = 0;
my $nratings = 0;

foreach my $code (@codes) {

	$ncodes++;

	my $orig = $code;
	$code = normalize_packager_codes($code);
	$code = get_fileid($code);
	$code =~ s/-(eg|ce)$/-ec/i;
	
	print "\n\n$orig --> $code - ";

	if (not defined $packager_codes{$code}) {
		print "code not found in packager_codes.sto\n";
	}
	else {
		$nfound++;
		my $name = $packager_codes{$code}{name};
		# http://ratings.food.gov.uk/enhanced-search/en-GB/Rachels%20Dairy%20Ltd/%5E/Relevance/0/%5E/%5E/1/1/10/json
		
		my $canon_name = $name;
		$canon_name =~ s/\s*(\(|\/).*//;
		$canon_name =~ s/\s+(ltd|limited|plc)(.*)$//i;
		
		my $uriname = URI::Escape::XS::encodeURIComponent($canon_name);
		
		
		print "name: $name - $uriname - loading data from ratings.food.gov.uk\n";
		
		
		my $url = "http://ratings.food.gov.uk/enhanced-search/en-GB/$uriname/%5E/Relevance/0/%5E/%5E/1/1/10/json";
		
		print "URL: $url\n";
		
		my $content = get($url);
        if (not defined $content) {
            print "http error, could not load http://ratings.food.gov.uk/enhanced-search/en-GB/$uriname/%5E/Relevance/0/%5E/%5E/1/1/10/json\n";
        }
        else {
		
			my $example = <<JSON
{"?xml":{"\@version":"1.0"},"FHRSEstablishment":{
"Header":{"#text":"","ExtractDate":"2014-10-18","ItemCount":"1","ReturnCode":"Success","PageNumber":"1","PageSize":"10","PageCount":"1"},
"EstablishmentCollection":{"\@xmlns:xsd":"http://www.w3.org/2001/XMLSchema","\@xmlns:xsi":"http://www.w3.org/2001/XMLSchema-instance",
	"EstablishmentDetail":{"FHRSID":"632542","LocalAuthorityBusinessID":"2767","BusinessName":"RACHEL'S DAIRY LTD",
	"BusinessType":"Manufacturers/packers","BusinessTypeID":"7839",
	"AddressLine1":null,"AddressLine2":"62-63 Glanyrafon Industrial Estate","AddressLine3":"Glanyrafon Industrial Estate",
	"AddressLine4":"Aberystwyth Ceredigion","PostCode":"SY23 3JQ","RatingValue":"5","RatingKey":"fhrs_5_en-GB","RightToReply":null,
	"RatingDate":"12 March 2014","LocalAuthorityCode":"557",
	"LocalAuthorityName":"Ceredigion","LocalAuthorityWebSite":"http://www.ceredigion.gov.uk/",
	"LocalAuthorityEmailAddress":"envhealth\@ceredigion.gov.uk",
	"Scores":{"Hygiene":"0","Structural":"0","ConfidenceInManagement":"0"},"SchemeType":"FHRS",
	"Geocode":{"Longitude":"-4.043087","Latitude":"52.40259"},"Distance":{"\@xsi:nil":"true"}}}}}
JSON
;
			my $json = $content;
			my $json_ref =  decode_json($json);
			
			#use Data::Dumper;
			#print Dumper($json_ref) . "\n";
			
			$json_ref = $json_ref->{FHRSEstablishment};
			print "json - header>ItemCount : " . $json_ref->{Header}{ItemCount} . "\n";
			
			if ($json_ref->{Header}{ItemCount} > 0) {
				$nratings++;
			}
			
			print "-- $name - local_authority: $packager_codes{$code}{local_authority}\n";
			
			my $local_authority1 = get_fileid($packager_codes{$code}{local_authority});
			
			if ((defined $json_ref->{EstablishmentCollection}) and (defined $json_ref->{EstablishmentCollection}{EstablishmentDetail})) {
			
				if (ref($json_ref->{EstablishmentCollection}{EstablishmentDetail}) ne 'ARRAY') {
					# just one result
					$json_ref->{EstablishmentCollection}{EstablishmentDetail} = [$json_ref->{EstablishmentCollection}{EstablishmentDetail}];
				}
			
				foreach my $establishment_ref (@{$json_ref->{EstablishmentCollection}{EstablishmentDetail}}) {
					print "- $code - $establishment_ref->{FHRSID} - fsa_rating_id $fsa_rating_ids{$code} - Business name: $establishment_ref->{BusinessName} - Business type: $establishment_ref->{BusinessType}\n"
					. "LocalAuthorityName: $establishment_ref->{LocalAuthorityName} \n";
					#print "---> '$establishment_ref->{FHRSID}' eq '$fsa_rating_ids{$code}' -- " . ($establishment_ref->{FHRSID} eq $fsa_rating_ids{$code}) . "  -- " . (($establishment_ref->{FHRSID} . '') eq $fsa_rating_ids{$code}) . "\n";
					
					if ($establishment_ref->{FHRSID} eq $fsa_rating_ids{$code}) {
						print "\n\nmatch! $code -> $establishment_ref->{FHRSID}\n\n";
						$packager_codes{$code}{fsa_rating_address} = $establishment_ref->{AddressLine1} . "\n"
						. $establishment_ref->{AddressLine2} . "\n"
						. $establishment_ref->{AddressLine3} . "\n"
						. $establishment_ref->{AddressLine4} . "\n"
						. $establishment_ref->{PostCode};
						$packager_codes{$code}{fsa_rating_address} =~ s/\n+/\n/g;
						$packager_codes{$code}{fsa_rating_address} =~ s/\n$//;
						$packager_codes{$code}{fsa_rating_address} =~ s/^\n//;
						$packager_codes{$code}{fsa_rating_business_name} = $establishment_ref->{BusinessName};
						$packager_codes{$code}{fsa_rating_business_type} = $establishment_ref->{BusinessType};
						$packager_codes{$code}{fsa_rating_business_geo_lat} = $establishment_ref->{Geocode}{Latitude};
						$packager_codes{$code}{fsa_rating_business_geo_lng} = $establishment_ref->{Geocode}{Longitude};
						$packager_codes{$code}{fsa_rating_value} = $establishment_ref->{RatingValue};
						$packager_codes{$code}{fsa_rating_key} = $establishment_ref->{RatingKey};
						$packager_codes{$code}{fsa_rating_date} = $establishment_ref->{RatingDate};
						$packager_codes{$code}{fsa_rating_local_authority} = $establishment_ref->{LocalAuthorityName};
					}
					
				}
			}
		}
	}
}

print "\ncodes: $ncodes - found: $nfound - ratings: $nratings\n";


store("$data_root/packager-codes/packager_codes.sto", \%packager_codes);
