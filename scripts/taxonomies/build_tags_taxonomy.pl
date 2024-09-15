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

use Modern::Perl '2017';
use utf8;

use ProductOpener::Config qw/:all/;
use ProductOpener::Tags qw/:all/;

my $tagtype = $ARGV[0] // '*';
my $publish = $ARGV[1] // 1;

print STDERR "tagtype: $tagtype\n";

if ($tagtype eq '*') {
	my $errors_ref = ProductOpener::Tags::build_all_taxonomies($publish);
	foreach my $taxonomy (keys %{$errors_ref}) {
		if (@{$errors_ref->{$taxonomy}}) {
			print STDERR (scalar @{$errors_ref->{$taxonomy}}) . " errors while building $taxonomy taxonomy\n";
		}
	}
}
else {
	my @errors = ProductOpener::Tags::build_tags_taxonomy($tagtype, $publish);
	if (@errors) {
		print STDERR (scalar @errors) . " errors while building $tagtype taxonomy\n";
	}
}

print STDERR "done building tags taxonomy\n";

exit(0);
