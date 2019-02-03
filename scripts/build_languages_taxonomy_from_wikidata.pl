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




# get list of languages with a 2 letter iso code (Property P217)
# https://tools.wmflabs.org/autolist/?language=en&project=wikipedia&category=&depth=12&wdq=claim%5B218%5D&pagepile=&wdqs=&statementlist=&run=Run&mode_manual=or&mode_cat=or&mode_wdq=not&mode_wdqs=or&mode_find=or&chunk_size=10000&download=1


my @languages = qw(
Q10179
Q102172
Q11059
Q12107
Q12175
Q13199
Q1321
Q13216
Q13218
Q13263
Q13267
Q13275
Q13307
Q13310
Q13389
Q135305
Q13955
Q1405077
Q1412
Q14185
Q14196
Q143
Q150
Q1568
Q1571
Q1617
Q1860
Q188
Q25164
Q25167
Q25258
Q25285
Q25289
Q25355
Q256
Q27175
Q27183
Q27811
Q28026
Q28244
Q294
Q29401
Q29561
Q29572
Q29921
Q30005
Q32656
Q32704
Q33081
Q33111
Q33243
Q33251
Q33262
Q33273
Q33295
Q33315
Q33348
Q33350
Q33368
Q33390
Q33454
Q33491
Q33549
Q33552
Q33573
Q33578
Q33583
Q33587
Q33617
Q33673
Q33702
Q33810
Q33823
Q33864
Q33875
Q33900
Q33947
Q33954
Q33968
Q33976
Q33997
Q34002
Q34004
Q34011
Q34014
Q34057
Q34094
Q34124
Q34128
Q34137
Q34235
Q34257
Q34271
Q34311
Q34327
Q34340
Q35224
Q35452
Q35499
Q35613
Q35850
Q35876
Q35934
Q36094
Q36126
Q36157
Q36217
Q36236
Q36280
Q36368
Q36392
Q36451
Q36510
Q36727
Q36785
Q36850
Q36986
Q397
Q4627
Q5111
Q5137
Q5146
Q5218
Q5287
Q56475
Q58635
Q58680
Q5885
Q652
Q6654
Q7026
Q7411
Q7737
Q7838
Q7850
Q7913
Q7918
Q7930
Q809
Q8097
Q8108
Q8641
Q8748
Q8752
Q8765
Q8785
Q8798
Q9027
Q9035
Q9043
Q9051
Q9056
Q9058
Q9063
Q9067
Q9072
Q9078
Q9083
Q9091
Q9142
Q9166
Q9168
Q9176
Q9199
Q9205
Q9211
Q9217
Q9228
Q9237
Q9240
Q9252
Q9255
Q9260
Q9264
Q9267
Q9288
Q9292
Q9296
Q9299
Q9303
Q9307
Q9309
Q9314
Q9610
);

#@languages = (55, 189, 399, 213, 205047);

my %languages = ();
my %names = ();

my %properties = (
	'language_code_2' => 'P218',
	'language_code_3' => 'P219',
);

my %languages = ();

foreach my $qc (@languages) {

	$qc =~ s/^Q//;

	print "loading language Q$qc\n";
	my $content = get("https://www.wikidata.org/w/api.php?action=wbgetentities&sites=enwiki&ids=Q$qc&format=json");
	if (not defined $content) {
		print "http error, could not get content from wikidata\n";
	}
	else {
		my $json = decode_json($content);
		# {"entities":{"Q39":{"pageid":153,"ns":0,"title":"Q39","lastrevid":92159404,"modified":"2013-12-08T18:12:54Z","id":"Q39","type":"item","aliases":{"de":[{"language":"de","value":"Schweizerische Eidgenossenschaft"},
		
		$languages{$qc} = {labels=>{}, aliases=>{}, properties=>{}};
		
		my $language = $json->{entities}{"Q$qc"};
		foreach my $lc (keys %{$language->{labels}}) {
			# "fr":{"language":"fr","value":"Suisse"}
			print "$qc - label: $lc - $language->{labels}{$lc}{value}\n";
			$languages{$qc}{labels}{$lc} = $language->{labels}{$lc}{value};
			if ($lc eq 'en') {
				$names{$qc} = $language->{labels}{$lc}{value};
			}
		}
		if (defined $language->{aliases}) {
			foreach my $lc (keys %{$language->{aliases}}) {
				# "fr":{"language":"fr","value":"Suisse"}
				print "$qc - alias: $lc - " . ref($language->{aliases}{$lc}) . " - " . $language->{aliases}{$lc} . "\n";

				$languages{$qc}{aliases}{$lc} = '';
				foreach my $alias (@{$language->{aliases}{$lc}}) {
					$languages{$qc}{aliases}{$lc} .= ', ' . $alias->{value};
					print "$qc - alias: $lc - value:  $alias->{value}\n";
					
				}
			}			
		}
		
		print "properties\n";
		
		foreach my $p (keys %properties) {
			my $pp = $properties{$p};
			print "$qc - properties $p / $pp \n";

			if ((defined $language->{claims}) and (defined $language->{claims}{$pp})) {
				$languages{$qc}{properties}{$p} = $language->{claims}{$pp}[0]{mainsnak}{datavalue}{value};
				print "$qc - properties $p / $pp : $languages{$qc}{properties}{$p}\n";
			}
		}
		

	}
}




	open (my $OUT, ">:encoding(UTF-8)", "$data_root/taxonomies/languages.txt");


foreach my $qc (sort {$names{$a} cmp $names{$b}} keys %names) {

	print $OUT "en:" . $languages{$qc}{labels}{en} . $languages{$qc}{aliases}{en};

	if (defined $languages{$qc}{properties}{language_code_2}) {
		print $OUT ", $languages{$qc}{properties}{language_code_2}";
	}
	
	if (defined $languages{$qc}{properties}{language_code_3}) {
		print $OUT ", $languages{$qc}{properties}{language_code_3}";
	}	
	
	print $OUT "\n";
	foreach my $lc (sort keys %{$languages{$qc}{labels}}) {
		#next if length($lc) > 2;
		next if ($lc eq 'en');
		print $OUT "$lc:" . $languages{$qc}{labels}{$lc} . $languages{$qc}{aliases}{$lc} . "\n";
	}
	foreach my $p (sort keys %properties) {
		if (defined $languages{$qc}{properties}{$p}) {
			print $OUT "$p:en:$languages{$qc}{properties}{$p}\n";
		}
	}	
	
	print $OUT "wikidata:en:Q$qc\n";

	print $OUT "\n";

}

	close $OUT;
