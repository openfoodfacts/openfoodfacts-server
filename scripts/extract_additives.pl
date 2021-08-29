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

binmode STDIN, ':encoding(UTF-8)';
binmode STDOUT, ':encoding(UTF-8)';

my %additives = ();

my $category;
my %current = ();
my $c = 0;
my @h = ();

my %fields = (
couleur => 'color',
code => 'code',
origine => 'origin',
"nom chimique" => 'name',
"n°" => 'code',
'descriptif' => 'name',
);

my %not_names = ();
open(my $IN, "<:encoding(UTF-8)", "not_names.txt");
while (<$IN>) {
	my $l = $_;
	chomp($l);
	$l =~s/\t.*//;
	$not_names{lc($l)} = 1;
}



while (<STDIN>) {

	my $l = $_;

	# ($l =~ /E203/) and exit();

	if ($l =~ /<caption>(.+)<\/caption>/) {
		$category = $1;
	}

	$category or next;
	if ($l =~ /<tr(.*?)>/) {
		%current = ();
		$c = 0;
	}

	if ($l =~ /<th(.*?)>(.*)<\/th>/) {
		my $field = lc($2);
		
		if (defined $fields{$field}) {
		$field = $fields{$field};
		$h[$c] = lc($field);

		print STDERR "th - $c - $2 -> $field \n";
		}

		$c++;
	}
	if ($l =~ /<td(.*?)>(.*)<\/td>/) {
		my $field = $h[$c];
                $c++;
				
				


		print STDERR "c: $c - field: $field\n";
		next if not defined $field;


		$current{$field} = $2;

		$current{$field} =~ s/<(([^>]|\n)*)>//g;

		if ( $field eq 'code' ) {
			$current{$field} =~ s/\(.*//;
		}

		if ($field eq 'name') {
		
		my $possible_names = '';
		if (defined $additives{$current{code}}) {
			$possible_names = $additives{$current{code}}{names};
		}
		$possible_names .= ", " . $current{$field};
		
		print STDERR "code: $current{code} - name: $current{name} - possible_names: $possible_names \n";

		my @possible_names = split(/,|\(|\)| ou /, $possible_names);
		my @names = ();
		my %seen = ();
		foreach my $name (@possible_names) {
			$name =~ s/^\s+//;
			$name =~ s/\s+$//;
			if ((length($name) >= 2) and (not defined $not_names{lc($name)})) {
				if (not defined $seen{$name}) {
					push @names, $name;
					$seen{$name} = 1;
				}
			}
		}
		$current{names} = join(', ', @names);
		}
    }
	if (($l =~ /<\/tr>/) and (defined $current{code})) {

		print STDERR "saving $current{code} - $current{name}\n";
		$additives{$current{code}} = {%current};
	}
	
}

# eliminate names that aren't names (appearing multiple times)
my %names = ();
foreach my $code (sort keys %additives) {
	my @names = split(/,/, $additives{$code}{names});
	foreach my $name (@names) {
			$name =~ s/^\s+//;
			$name =~ s/\s+$//;
			if ($name ne '') {
				$names{$name}++;
			}
	}
}

#foreach my $name (sort { $names{$b} <=> $names{$a} } keys %names) {
#	print "$name\t$names{$name}\n";
#}

foreach my $code (sort keys %additives) {

	print $code . "\t" . $additives{$code}{names} . "\t(" . $additives{$code}{name} . ")\n";

}
