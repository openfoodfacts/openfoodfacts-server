#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2019 Association Open Food Facts
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

my $usage = <<TXT
list_tags_with_property.pl - list all entries in a taxonomy that have a specific property

Usage:

list_taxonomy_entries.pl --type ingredients --property vegan:en=null
-> list all ingredients that do not have a value for the vegan:en property

list_taxonomy_entries.pl --type ingredients --property vegan:en=exists
-> list all ingredients that have a value for the vegan:en property

list_taxonomy_entries.pl --type ingredients --property vegan:en=yes
-> list all ingredients that have the value "yes" for the vegan:en property

list_taxonomy_entries.pl --type ingredients --inherited-property vegan:en=yes
-> list all ingredients with an inherited value "yes" for the  vegan:en property

TXT
;

binmode(STDIN, ":encoding(UTF-8)");
binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Tags qw/:all/;

use Getopt::Long;

my $tagtype;
my $property_ref = { property=>{}, inherited_property=>{}};

GetOptions ("type=s"   => \$tagtype,      # string
			"property=s%" => $property_ref->{property},
			"inherited-property=s%" => $property_ref->{inherited_property},
			)
  or die("Error in command line arguments:\n\n$usage\n");


if (not defined $tagtype) {
	die ("missing the taxonomy type argument.\n\n$usage\n");
}
elsif (defined $translations_to{$tagtype}) {
	foreach my $tagid (sort keys %{$translations_to{$tagtype}}) {
		# Skip synonyms
		next if ((exists $just_synonyms{$tagtype}) and (exists $just_synonyms{$tagtype}{$tagid}));
		
		my $match = 1;
		
		foreach my $property_type ("property", "inherited_property") {
		
			if (defined $property_ref) {
				foreach my $property (sort keys %{$property_ref->{$property_type}}) {
					
					my $query = $property_ref->{$property_type}{$property};
					
					my $value;
					if ($property_type eq "property") {
						$value = get_property($tagtype, $tagid, $property);
					}
					else {
						$value = get_inherited_property($tagtype, $tagid, $property);
					}
									
					if (($query eq 'null') or ($query eq '')) {
						if (defined $value) {
							$match = 0;
							last;
						}
					}
					elsif ($query eq 'exists') {
						if (not defined $value) {
							$match = 0;
							last;
						}
					}
					elsif ($query =~ /^-/) {
						if ((defined $value) and ($value eq $')) {
							$match = 0;
							last;
						}
					}
					elsif ((not defined $value) or ($value ne $query)) {
						$match = 0;
						last;
					}
				}
			}
			
			if (not $match) {
				last;
			}
		}
		
		if ($match) {
			print $tagid . "\n";
		}
	}
}
else {
	die ("$tagtype is not an existing built taxonomy\n\n$usage\n");
}

exit(0);

