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


my $classes_file = "$data_root/taxonomies/off/additives/additives.classes.txt";

open (my $IN, "<:encoding(UTF-8)", $classes_file) or die("Could not open $classes_file: $!");

my %classes = ();
my %classes_hash = ();

while(<$IN>) {

	# Humectant;450(ii);Trisodium diphosphate
	my $line = $_;
	print STDERR $line;
	if ($line =~ /^(.*?);((\d+)(\w?))(;|\()/) {
		my $class = lc($1);
		$class =~ s/ /-/g;
		my $e = lc($2);
		(defined $classes{$e}) or  $classes{$e} = [];
		(defined $classes_hash{$e}) or  $classes_hash{$e} = {};
		if (not defined $classes_hash{$e}{"en:$class"}) {
			push @{$classes{$e}}, "en:$class";
			$classes_hash{$e}{"en:$class"} = 1;
		}
		#print STDERR "e_number: $e - class: en:$class\n";
	}
}

#exit;

my $csv_file = "$data_root/taxonomies/off/additives/additives.openfoodtoxtx22051_opinion.csv";

use Text::CSV;

my $csv = Text::CSV->new ( { binary => 1 , sep_char => "\t" } )  # should set binary attribute.
                 or die "Cannot use CSV: ".Text::CSV->error_diag ();
				 
open (my $io, '<:encoding(UTF-8)', $csv_file) or die("Could not open $csv_file: $!");

$csv->column_names ($csv->getline ($io));

my %studies = ();

while (my $line_ref = $csv->getline_hr ($io)) {				 


	# is it an additive?
	my $title = $line_ref->{TITLE};
	
	# skip cats, dogs, and other animals
	
	($title =~ /\b(cats|dogs|animals|animal|cat|dog|feed)/) and next;
	
	my $i = 0;
	
	$line_ref->{PUBLICATION_DATE} =~ s/^(....)(..)(..)/$1-$2-$3/;
	
	while ($title =~ /\bE(-| |)(\d\d\d(\d?)(abcdefgh)?)/i) {
	
		my $e_number = lc($2);
		$title = $';
		
		$studies{$e_number} = { title => $line_ref->{TITLE}, url => $line_ref->{URL}, date => $line_ref->{PUBLICATION_DATE} };
		
		
		
		# print "found additive $e_number : " . $line_ref->{TITLE} . "\n";
		$i++;
	}
	
	my $title2 = $line_ref->{TITLE};
	$title2 =~ s/Opinion of the Scientific Panel on food additives//i;
	$title2 =~ s/Scientific Opinion of the Panel on Food Additives//i;
	if (($i == 0) and ($title2 =~ /food additive/i)) {
		print STDERR "\n";		
		print STDERR "efsa_evaluation_url:en: " . $line_ref->{URL} . "\n";
		print STDERR "efsa_evaluation_date:en: " . $line_ref->{PUBLICATION_DATE} . "\n";
		print STDERR "efsa_evaluation:en: " . $line_ref->{TITLE} . "\n";		
		
	}
}
				 


binmode(STDIN, ":encoding(UTF-8)");
binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");


my $e;

require Encode;

my %properties = ();

my $j = 0;

while (<STDIN>) {

	my $line = $_;
	
	if ($line =~ /e_number:en:(.*)$/) {
		$e = lc($1);
		chomp($e);
		print STDERR "-> e_number: $e\n";
	}
	
	if ($line =~ /^([^:]+):/) {
		$properties{$1} = $';
	}
	
	my $line2 = $line;
	$line2 =~ s/\r|\n//g;
	if (($line2 =~ /^\s*$/)) {

	
		if (defined $e) {
		
#efsa_evaluation_url:en:http://www.efsa.europa.eu/fr/efsajournal/doc/1649.pdf
#efsa_evaluation_date:en:2010/07/26
#efsa_evaluation:en:Scientific Opinion on the re‐evaluation of Amaranth (E 123) as a food additive		
		
			if ((not defined $properties{efsa_evaluation}) and (defined $studies{$e})) {
			
				print "efsa_evaluation_url:en: " . $studies{$e}{url} . "\n";
				print "efsa_evaluation_date:en: " . $studies{$e}{date} . "\n";
				print "efsa_evaluation:en: " . $studies{$e}{title} . "\n";
				$j++;
			}
			
			# additives_classes:en: en:flavour-enhancer

			if ((not defined $properties{additives_classes}) and (defined $classes{$e})) {
				print "additives_classes:en: " . join(", ", @{$classes{$e}}) . "\n";
				# exit;
			}
			

			$e = undef;
			
		}
		
		%properties = ();
	}
	
	print $line;
}

print STDERR "added $j links to EFSA studies\n";

