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

use CGI::Carp qw(fatalsToBrowser);

use Modern::Perl '2012';
use utf8;

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;
use LWP::Simple;


# https://www.wikidata.org/w/api.php?action=wbgetentities&sites=enwiki&ids=Q39&format=json

# or any state with an Internet top level domain (P78)
# https://208.80.153.172/wdq/?q=claim[78]
# 270 results, includes territories like US Virgin Islands, French Polynesia etc.

my @countries = (16,17,20,22,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,43,45,51,55,77,79,96,114,115,117,142,145,148,155, 159,183,184,189,191,211,212,213,214,215,217,218,219,221,222,223,224,225,227,228,229,230,232,233,235,236,237,238,241,242, 244,252,258,262,265,298,327,334,347,398,399,403,408,414,419,423,424,458,574,657,664,668,672,678,683,685,686,691,695,697, 702,709,710,711,712,717,730,733,734,736,739,750,754,757,760,763,766,769,774,778,781,783,784,785,786,790,792,794,796,800, 801,804,805,810,811,813,817,819,822,826,833,836,837,842,843,846,851,854,858,863,865,869,874,878,881,884,889,902,912,916, 917,921,924,928,929,945,948,953,954,958,962,963,965,967,970,971,974,977,983,986,1000,1005,1006,1007,1008,1009,1011,1013, 1014,1016,1019,1020,1025,1027,1028,1029,1030,1032,1033,1036,1037,1039,1041,1042,1044,1045,1049,1050,1183,1410,3769,4628, 5689,5785,6250,7184,8646,9648,9676,11196,11703,12130,13353,14056,14773,15180,16635,16641,16644,16645,16957,17012,17054, 17063,17070,18221,21203,23408,23635,25228,25230,25279,25305,25362,25396,25528,26180,26273,26988,27561,30971,31057,31063, 33788,34020,34617,35086,35555,35672,36004,36704,36823,43448,46197,126125,129003,131083,131198,179313,192184,205047, 219060,407199,842829,927467,1555938,2552742);

#@countries = (55, 189, 399, 213, 205047);

my %countries = ();
my %names = ();

my %properties = (
	'country_code_2' => 'P297',
	'country_code_3' => 'P298',
);

my %languages = ();

foreach my $qc (@countries) {
	print "loading country Q$qc\n";
	my $content = get("https://www.wikidata.org/w/api.php?action=wbgetentities&sites=enwiki&ids=Q$qc&format=json");
	if (not defined $content) {
		print "http error, could not get content from wikidata\n";
	}
	else {
		my $json = decode_json($content);
		# {"entities":{"Q39":{"pageid":153,"ns":0,"title":"Q39","lastrevid":92159404,"modified":"2013-12-08T18:12:54Z","id":"Q39","type":"item","aliases":{"de":[{"language":"de","value":"Schweizerische Eidgenossenschaft"},
		
		$countries{$qc} = {labels=>{}, aliases=>{}, official_languages=>{}, properties=>{}};
		
		my $country = $json->{entities}{"Q$qc"};
		foreach my $lc (keys %{$country->{labels}}) {
			# "fr":{"language":"fr","value":"Suisse"}
			print "$qc - label: $lc - $country->{labels}{$lc}{value}\n";
			$countries{$qc}{labels}{$lc} = $country->{labels}{$lc}{value};
			if ($lc eq 'en') {
				$names{$qc} = $country->{labels}{$lc}{value};
			}
		}
		if (defined $country->{aliases}) {
			foreach my $lc (keys %{$country->{aliases}}) {
				# "fr":{"language":"fr","value":"Suisse"}
				print "$qc - alias: $lc - " . ref($country->{aliases}{$lc}) . " - " . $country->{aliases}{$lc} . "\n";

				$countries{$qc}{aliases}{$lc} = '';
				foreach my $alias (@{$country->{aliases}{$lc}}) {
					$countries{$qc}{aliases}{$lc} .= ', ' . $alias->{value};
					print "$qc - alias: $lc - value:  $alias->{value}\n";
					
				}
			}			
		}
		
		print "properties\n";
		
		foreach my $p (keys %properties) {
			my $pp = $properties{$p};
			print "$qc - properties $p / $pp \n";

			if ((defined $country->{claims}) and (defined $country->{claims}{$pp})) {
				$countries{$qc}{properties}{$p} = $country->{claims}{$pp}[0]{mainsnak}{datavalue}{value};
				print "$qc - properties $p / $pp : $countries{$qc}{properties}{$p}\n";
			}
		}
		
		if ((defined $country->{claims}) and (defined $country->{claims}{"P37"})) {
			foreach my $v (@{$country->{claims}{"P37"}}) {
				my $language = $v->{mainsnak}{datavalue}{value}{"numeric-id"};
				$countries{$qc}{official_languages}{$language} = 1;
				print "$qc - official_language: " . $language . "\n";
				$languages{$language} = "Q$language";
			}
		}
	}
}



foreach my $language (keys %languages) {
	print "loading language Q$language\n";
	my $content = get("https://www.wikidata.org/w/api.php?action=wbgetentities&sites=enwiki&ids=Q$language&format=json");
	if (not defined $content) {
		print "http error, could not get content from wikidata\n";
	}
	else {
		my $json = decode_json($content);
		# {"entities":{"Q39":{"pageid":153,"ns":0,"title":"Q39","lastrevid":92159404,"modified":"2013-12-08T18:12:54Z","id":"Q39","type":"item","aliases":{"de":[{"language":"de","value":"Schweizerische Eidgenossenschaft"},
		
		
		my $languagedata = $json->{entities}{"Q$language"};

		
		if ((defined $languagedata->{claims}) and (defined $languagedata->{claims}{"P218"})) {

			$languages{$language} = $languagedata->{claims}{"P218"}[0]{mainsnak}{datavalue}{value};;
		}
	}
}


	open (my $OUT, ">:encoding(UTF-8)", "$data_root/taxonomies/countries.txt");


foreach my $qc (sort {$names{$a} cmp $names{$b}} keys %names) {

	print $OUT "en:" . $countries{$qc}{labels}{en} . $countries{$qc}{aliases}{en};

	if (defined $countries{$qc}{properties}{country_code_2}) {
		print $OUT ", $countries{$qc}{properties}{country_code_2}";
	}
	
	if (defined $countries{$qc}{properties}{country_code_3}) {
		print $OUT ", $countries{$qc}{properties}{country_code_3}";
	}	
	
	print $OUT "\n";
	foreach my $lc (sort keys %{$countries{$qc}{labels}}) {
		#next if length($lc) > 2;
		next if ($lc eq 'en');
		print $OUT "$lc:" . $countries{$qc}{labels}{$lc} . $countries{$qc}{aliases}{$lc} . "\n";
	}
	foreach my $p (sort keys %properties) {
		if (defined $countries{$qc}{properties}{$p}) {
			print $OUT "$p:en:$countries{$qc}{properties}{$p}\n";
		}
	}	
	print $OUT "official_languages:en:" . join(',', map {$languages{$_}} (sort keys %{$countries{$qc}{official_languages}})) . "\n";

	print $OUT "\n";

}

	close $OUT;
