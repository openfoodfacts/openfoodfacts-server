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

use Modern::Perl '2017';
use utf8;

use Carp ();

use ProductOpener::Store qw/:all/;
use ProductOpener::Config qw/:all/;

sub _parse_wikidata {
	my ($in) = @_;

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

	while (<$in>) {

		# Humectant;450(ii);Trisodium diphosphate
		my $line = $_;
		chomp $line;
		$line =~ s/[\r\n]//gmsx;

		next if ($line =~ /:\w\w:$/msx);

		if ($line =~ /^wikidata:en:(.*)$/msx) {
			$wikidata = $1;
			$property = undef;
			$lc = undef;
			$value = undef;
		}
		elsif ($line =~ /^(wikipedia_.*):(\w\w):(.+)$/msx) {
			$property = $1;
			$lc = $2;
			$value = $3;
			defined $properties{$wikidata} or $properties{$wikidata} = {};
			defined $properties{$wikidata}{$lc} or $properties{$wikidata}{$lc} = {};
			$properties{$wikidata}{$lc}{$property} = $value;
		}
		elsif ((defined $property) and (defined $lc)) {
			$properties{$wikidata}{$lc}{$property} .= " $line";
		}
	}

	return %properties;
}

# tmx files contain translations from the EU laws

my $wikipedia_file = "$data_root/taxonomies/off/additives/additives.wikipedia.txt";

open my $IN, '<:encoding(UTF-8)', $wikipedia_file or Carp::croak("Could not open $wikipedia_file");
my %properties = _parse_wikidata();
close $IN or Carp::croak("Could not open $wikipedia_file");

binmode STDIN, ':encoding(UTF-8)';
binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';

require Encode;

my $id;
my $wikidata;

while (<>) {

	my $line = $_;

	if ($line =~ /^en:(.*?)(,|$)/imsx) {
		$id = $1;
		$wikidata = undef;
	}

	if ($line =~ /wikidata:en:(.*)$/msx) {
		$wikidata = $1;
		if (defined $properties{$wikidata}) {
			print "\nen:$id\n" or Carp::croak('Unable to write to *STDOUT');
			foreach my $lc (sort keys %{$properties{$wikidata}}) {
				foreach my $property (sort keys %{$properties{$wikidata}{$lc}}) {
					print "$property:$lc: " . $properties{$wikidata}{$lc}{$property} . "\n" or Carp::croak('Unable to write to *STDOUT');
				}
			}
		}
	}

	if (($line =~ /^\s*$/msx)) {
		$id = undef;
		$wikidata = undef;
	}

}
