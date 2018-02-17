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

my $file = $ARGV[0];

print "Checking $file\n";

open(my $IN, "<:encoding(UTF-8)", $file) or die "Could not open $file: $!\n";

my %langs = ();

app_take_a_picture => {
	fr => "Prendre une photo",
	en => "Take a picture",
	es => "Saca una foto",
	pt => "Tira uma foto",
	ro => "Faceți o fotografie",
	ar => "التقاط صورة",
	de => "Machen Sie ein Foto",
	it => "Scattare una foto",  
	he => "צילום תמונה",
},

my $key = "";

while (<$IN>) {

	chomp;
	my $l = $_;
	if ($l =~ /=>\s*\{/) {
		$key = $`;
		$key =~ s/\s//g;
		%langs = ();
	}
	elsif ($l =~ /=>\s*/) {
		my $lang = $`;
		my $value = $';
		$lang =~ s/\s//g;
		if (exists $langs{$lang}) {
			print STDERR "key $key has 2 values for lang $lang\n\t$langs{$lang}\n\t$value\n";
		}
		else {
			$langs{$lang} = $value;
		}
	}

}

