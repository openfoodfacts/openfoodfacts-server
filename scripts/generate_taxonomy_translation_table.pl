#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2023 Association Open Food Facts
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

=head1 NAME

generate_taxonomy_translation_table.pl - Generate a translation table for selected entries in taxonomy in selected languages

=head1 DESCRIPTION

This script was created to generate a translation table for rare crops in the ingredients taxonomy, to provide an easy way to review translations
of ingredients of interest for partners of the DIVINFOOD project about Neglected and Underutilized Crops (NUCs).

We may make this script more general in the future if we have similar uses.

=cut

use ProductOpener::PerlStandards;

use ProductOpener::Tags qw/:all/;

my $taxonomy = "ingredients";

my @languages = qw(la en bg cs da de el es et fi fr hr hu it lt lv mt nl pl pt ro sk sl sv);

my $entries_language = "en";

my @entries = (
	"Broad beans",
	"Lima bean",
	"Common bean",
	"Lingot beans",
	"Meat bean",
	"Blue lupin",
	"White lupin",
	"Pea",
	"Grass pea",
	"Grey pea",
	"Cowpea",
	"Chickpea",
	"Lentils",
	"Einkorn",
	"Emmer",
	"Poulard wheat",
	"Mung bean",
);

binmode STDOUT, ":encoding(UTF-8)";

# Output the header in CSV format, with language names
print join("\t", map {display_taxonomy_tag("en", 'languages', $language_codes{$_}) . " ($_)"} @languages) . "\n";

foreach my $entry (@entries) {
	my $canonical_entry = canonicalize_taxonomy_tag($entries_language, $taxonomy, $entry);
	my @translations = ();
	foreach my $language (@languages) {
		my $translation = display_taxonomy_tag($language, $taxonomy, $canonical_entry);
		if ($translation =~ /^\w\w:/) {
			$translation = '';
		}
		push @translations, $translation;
	}
	print join("\t", @translations) . "\n";
}

exit(0);
