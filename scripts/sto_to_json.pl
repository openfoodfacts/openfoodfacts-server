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

use Storable qw(lock_store lock_nstore lock_retrieve);
use JSON;

# binmode(STDOUT, ":encoding(UTF-8)");

sub retrieve {
	my $file = shift @_;
	# If the file does not exist, return undef.
	if (!-e $file) {
		return;
	}
	return lock_retrieve($file);
}

my $ref = retrieve($ARGV[0]);

if ($ref) {
	print JSON->new->utf8->canonical->pretty->encode($ref);
}
