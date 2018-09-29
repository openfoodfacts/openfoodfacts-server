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

use ProductOpener::Store qw/:all/;
use ProductOpener::Config qw/:all/;

# tmx files contain translations from the EU laws


my $wikipedia_file = "$data_root/taxonomies/off/additives/additives.wikipedia.txt";

open (my $IN, "<:encoding(UTF-8)", $wikipedia_file) or die("Could not open $wikipedia_file: $!");

my %properties = ();

#wikidata:en:Q1640437
#description:bg:
#description:es:
#description:cs:
#description:da:
#de:Hydroxypropylstärke
#wikipedia_url:de:https://de.wikipedia.org/wiki/Hydroxypropylstärke
#description:de:Hydroxypropylstärke (HPS) ist eine modifizierte Stärke, die als Lebensmittelzusatzstoff mit der Bezeichnung E 1440 verwendet wird.
#Sie wird aus Wachsmaisstärke oder Kartoffelstärke durch chemische Reaktion mit Propylenoxid hergestellt. Damit besteht sie fast ausschließlich aus Amylopektin, also aus verzweigten Ketten von Glucosemolekülen. Um einen zu schnellen Abbau des Amylopektins durch das endogene Enzym Amylase zu verhindern, erfolgt eine teilweise Hydroxypropylierung der Glucoseeinheiten. Diese Hydroxypropylierung ist auch notwendig um eine Wasserlöslichkeit von Stärke zu erreichen.
#Stärkeether werden vor allem als Verdickungsmittel eingesetzt, um die gewünschte Konsistenz wässriger Produkte zu erreichen. Heutige moderne Hydroxypropylstärken haben eine molare Masse von etwa 200.000 Da mit einem Substitutionsgrad von 59 %.
#description:et:

my $wikidata;

my $property;
my $lc;
my $value;

while(<$IN>) {

	# Humectant;450(ii);Trisodium diphosphate
	my $line = $_;
	chomp($line);
	$line =~ s/\r|\n//g;
	
	next if ($line =~ /:\w\w:$/);
	
	if ($line =~ /^wikidata:en:(.*)$/) {
		$wikidata = $1;
		$property = undef;
		$lc = undef;
		$value = undef;
	}
	elsif ($line =~ /^(wikipedia_.*):(\w\w):(.+)$/) {
		$property = $1;
		$lc = $2;
		$value = $3;
		defined $properties{$wikidata} or $properties{$wikidata} = {};
		defined $properties{$wikidata}{$lc} or $properties{$wikidata}{$lc} = {};
		$properties{$wikidata}{$lc}{$property} = $value;
	}
	elsif ((defined $property) and (defined $lc)) {
		$properties{$wikidata}{$lc}{$property} .= " " . $line;
	}
}

#exit;


binmode(STDIN, ":encoding(UTF-8)");
binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");




require Encode;


my $j = 0;

my $id;
$wikidata = undef;

while (<STDIN>) {

	my $line = $_;
	
	if ($line =~ /^en:(.*?)(,|$)/i) {
		$id = $1;
		$wikidata = undef;
	}
	
	if ($line =~ /wikidata:en:(.*)$/) {
		$wikidata = $1;
		if (defined $properties{$wikidata}) {
		
			print "\nen:$id\n";
			foreach my $lc (sort keys %{$properties{$wikidata}}) {
				foreach my $property (sort keys %{$properties{$wikidata}{$lc}}) {
					print "$property:$lc: " . $properties{$wikidata}{$lc}{$property} . "\n";
				}
			}
		}
	}

	if (($line =~ /^\s*$/)) {

		$id = undef;
		$wikidata = undef;
	}
	
}


