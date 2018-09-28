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


use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON;
use Text::CSV;

use strict;

binmode(STDOUT, ":utf8");


# read the EU translation memory

my %translations = ();

if (open (my $IN, "<:encoding(UTF-16)", "$data_root/taxonomies-obf/32006D0257.tmx.txt")) {

	my $english;

	while (<$IN>) {
		
		my $line = $_;
		if ($line =~ /<tuv lang="EN-GB">/) {
		
			$english = <$IN>;
			$english =~ s/<(\/)?seg>//g;
			$english = lc($english);
			chomp($english);
			$english =~ s/(\s|\r|\n)*$//;
			$english =~ s/^(\s|\r|\n)*//;		
			$english =~ s/(\s|\r|\n)+/ /g;
			$translations{$english} = {};
			
		}
		elsif ($line =~ /<tuv lang="(..).*">/) {
		
			my $lang = lc($1);
			my $translation = <$IN>;
			$translation =~ s/<(\/)?seg>//g;
			chomp($translation);
			$translation =~ s/(\s|\r|\n)*$//;
			$translation =~ s/^(\s|\r|\n)*//;
			$translation =~ s/(\s|\r|\n)+/ /g;
			# print "English: $english -- Translation: $lang - $translation\n";			
			$translations{$english}{$lang} = $translation;
		}

	}
	close $IN;
}
else {
	print STDERR "Could not open $data_root/taxonomies-obf/32006D0257.tmx.txt\n";
	exit;
}

my $csv_file = "$data_root/taxonomies-obf/COSING_Ingredients-Fragrance-Inventory_v2.wikidata.tsv";

my $csv = Text::CSV->new ( { binary => 1 , sep_char => "\t" } )  # should set binary attribute.
                 or die "Cannot use CSV: ".Text::CSV->error_diag ();

open (my $io, '<:encoding(UTF-8)', $csv_file) or die("Could not open $csv_file: $!");

$csv->column_names ($csv->getline ($io));

# COSING Ref No	INCI name	score of the best	candidatesQid	best Qid	candidates	wikidata suggestions	INN name	Ph. Eur. Name	CAS No	EC No	Chem/IUPAC Name / Description	Restriction	Function	Update Date	Column 11	Column 12	Column 13	Column 14	Column 15	Column 16	Column 17	Column 18


while (my $ingredient_ref = $csv->getline_hr ($io)) {

	foreach my $field (keys %{$ingredient_ref}) {
		$ingredient_ref->{$field} =~ s/(\s|\r|\n)*$//;
		$ingredient_ref->{$field} =~ s/^(\s|\r|\n)*//;
		$ingredient_ref->{$field} =~ s/(\s|\r|\n)+/ /g;	
	}

	my $name = $ingredient_ref->{"INCI name"};
	$name =~ s/(\s|\r|\n)*$//;
	$name =~ s/^(\s|\r|\n)*//;
	$name =~ s/(\s|\r|\n)+/ /g;

	
	print "en: " . $name . "\n";
	my $english = lc($ingredient_ref->{"INCI name"});
	$english =~ s/(\s|\r|\n)*$//;
	$english =~ s/^(\s|\r|\n)*//;
	$english =~ s/(\s|\r|\n)+/ /g;
	if (defined $translations{$english}) {
		foreach my $lang (sort keys %{$translations{$english}}) {
			print $lang . ": " . $translations{$english}{$lang} . "\n";
		}
	}
	
	if ((defined $ingredient_ref->{"COSING Ref No"}) and ($ingredient_ref->{"COSING Ref No"} ne "")) {
		print "cosing:en: " . $ingredient_ref->{"COSING Ref No"} . "\n";
	}

	if ((defined $ingredient_ref->{"CAS No"}) and ($ingredient_ref->{"CAS No"} ne "") and ($ingredient_ref->{"CAS No"} ne "-")) {
		print "cas:en: " . $ingredient_ref->{"CAS No"} . "\n";
	}
	
	if ((defined $ingredient_ref->{"EC No"}) and ($ingredient_ref->{"EC No"} ne "") and ($ingredient_ref->{"EC No"} ne "-")) {
		print "einecs:en: " . $ingredient_ref->{"EC No"} . "\n";
	}

	if ((defined $ingredient_ref->{"INN name"}) and ($ingredient_ref->{"INN name"} ne "") and ($ingredient_ref->{"INN name"} ne "-")) {
		print "inn-name:en: " . $ingredient_ref->{"INN name"} . "\n";
	}	
	
	if ((defined $ingredient_ref->{"Ph. Eur. Name"}) and ($ingredient_ref->{"Ph. Eur. Name"} ne "") and ($ingredient_ref->{"Ph. Eur. Name"} ne "-")) {
		print "ph-eur-name:en: " . $ingredient_ref->{"Ph. Eur. Name"} . "\n";
	}
	
	if ((defined $ingredient_ref->{"Update Date"}) and ($ingredient_ref->{"Update Date"} ne "") and ($ingredient_ref->{"Update Date"} ne "-")) {
		
		print "inci-update-date:en: " . $ingredient_ref->{"Update Date"} . "\n";
	}		
	
	if ((defined $ingredient_ref->{"Function"}) and ($ingredient_ref->{"Function"} ne "") and ($ingredient_ref->{"Function"} ne "-")) {
	
		my $function = $ingredient_ref->{"Function"};
		$function =~ s/ /-/g;
		my $functions = "en:" . join(", en:", split(/,(-|\s)?/, lc($function)));
		$functions =~ s/, en:-//g;
	
		print "inci-function:en: $functions\n";
	}	
	
	if ((defined $ingredient_ref->{"Chem/IUPAC Name / Description"}) and ($ingredient_ref->{"Chem/IUPAC Name / Description"} ne "")) {
	
		my $description = $ingredient_ref->{"Chem/IUPAC Name / Description"};
		$description =~ s/(\s|\r|\n)*$//;
		$description =~ s/^(\s|\r|\n)*//;		
		$description =~ s/(\s|\r|\n)+/ /g;
	
		print "inci-description:en: " . $description . "\n";

		my $english = lc($ingredient_ref->{"Chem/IUPAC Name / Description"});
		$english =~ s/(\s|\r|\n)*$//;
		$english =~ s/^(\s|\r|\n)*//;
		$english =~ s/(\s|\r|\n)+/ /g;
			
		if (defined $translations{$english}) {
			foreach my $lang (sort keys %{$translations{$english}}) {
				$description = $translations{$english}{$lang};
				$description =~ s/(\s|\r|\n)+/ /g;
				print "inci-description:" . $lang . ": " . $description . "\n";
			}
		}			
	}

	if ((defined $ingredient_ref->{"Restriction"}) and ($ingredient_ref->{"Restriction"} ne "")) {
		print "inci-restriction:en: " . $ingredient_ref->{"Restriction"} . "\n";

		my $english = lc($ingredient_ref->{"Restriction"});
		$english =~ s/(\s|\r|\n)*$//;
		$english =~ s/^(\s|\r|\n)*//;	
			
		if (defined $translations{$english}) {
			foreach my $lang (sort keys %{$translations{$english}}) {
				print "inci-restriction:" . $lang . ": " . $translations{$english}{$lang} . "\n";
			}
		}			
	}

	if ((defined $ingredient_ref->{"wikidata suggestions"}) and ($ingredient_ref->{"wikidata suggestions"} ne "")) {
		
		print "wikidata:en:" . $ingredient_ref->{"wikidata suggestions"} . "\n";
	}		
	
	print "\n";

}


exit(0);

