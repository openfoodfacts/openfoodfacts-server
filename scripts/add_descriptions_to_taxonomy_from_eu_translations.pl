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

my @tmx_files = ("$data_root/taxonomies/off/additives_classes/32008R1333.tmx");

my %translations = ();

#<prop type="Txt::Doc. No.">32008R1333</prop>
#<tuv lang="EN-GB">
#<seg>‘sequestrants’ are substances which form chemical complexes with metallic ions;</seg>
#</tuv>
#<tuv lang="DE-DE">
#<seg>„Komplexbildner“ sind Stoffe, die mit Metallionen chemische Komplexe bilden.</seg>
#</tuv>

binmode(STDIN, ":encoding(UTF-8)");
binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");

foreach my $tmx_file (@tmx_files) {

	open (my $IN, "<:encoding(UTF-16)", $tmx_file) or die("Could not open $tmx_file: $!");

	my $english = "";
	my $lang = "";
	my $skip = 1;
	my $i = 0;
	
	while (<$IN>) {
		my $line = $_;
		#print STDERR $line;
		if ($line =~ /<tuv lang="(.*)">/i) {
			$lang = lc($1);
			$lang =~ s/-.*//;
			#print STDERR "lang: $lang\n";
		}
		elsif ($line =~ /<seg>(.*)<\/seg>/i) {
			my $translation = $1;
			
			# remove [2] and (2)
			$translation =~ s/ (\[|\()\d(\)|\])$//;
			
			if ($lang eq 'en') {
				if (not ($translation =~ /‘([^\’]+)’/)) {
					$skip = 1;
				}
				else {
					$english = lc($1);
					$english =~ s/s$//;
					$translations{$english} = {};
					$skip = 0;
				}
			}
			if (not $skip) {
				$translations{$english}{$lang} = $translation;
				print STDERR "English: $english - lang: $lang - translation: $translation\n";
			}			
		}
		$i++;
		($i % 1000 == 0) and print STDERR ".";
	}
	
	close ($IN);
}

my $english;

require Encode;

while (<STDIN>) {

	my $line = $_;
	
	if ($line =~ /^en:(.*)$/) {
		$english = $1;
		chomp($english);
		# remove [2] and (2)
		$english =~ s/ (\[|\()\d(\)|\])$//;
		$english =~ s/\s*,.*//;
		$english = lc($english);
		$english =~ s/s$//;
		$english =~ s/^\s+//;
		($english eq 'propellent ga') and $english = "propellant";
		print STDERR "-> english: $english\n";
	}
	
	my $line2 = $line;
	$line2 =~ s/\r|\n//g;
	if (($line2 =~ /^\s*$/) and (defined $english)) {
		if (defined $translations{$english}) {
			my $english_description = $translations{$english}{en};
			$english_description =~ s/\‘(.*?)\’/$1/;
			$english_description =~ s/(;|;)(\s)*$/\./;
			$english_description = ucfirst($english_description);
			print "description:" . "en" . ":" . $english_description . "\n";
			foreach my $lang (sort keys %{$translations{$english}}) {
				next if $lang eq "en";
				
				 use Encode qw(decode encode);
				# my $description =  decode('UTF-8', $translations{$english}{$lang});
				my $description = $translations{$english}{$lang};
						
				use utf8;
				
				$description =~ s/\‘(.*?)\’/$1/;
				$description =~ s/\"(.*?)\"/$1/;
				$description =~ s/\«(.*?)\»/$1/;
				$description =~ s/\„(.*?)\“/$1/;
				$description =~ s/\„(.*?)\”/$1/;
				$description =~ s/\”(.*?)\”/$1/;
				$description =~ s/\“(.*?)\”/$1/;
				$description =~ s/\»(.*?)\«/$1/;
				
				$description =~ s/(;|;)(\s)*$/\./;
				$description = ucfirst($description);
				print STDERR $description;
				
				print "description:" . $lang . ":" . $description . "\n";
			}
		}
		$english = undef;
	}
	
	print $line;
}



