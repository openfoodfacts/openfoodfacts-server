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

my $usage = <<TXT
find_and_replace_user_id_in_products.pl is a script that finds all products added or edited by
a specific user, and replace that user by another user in the product and product edit history.

Usage:

update_all_products.pl --user-id user-id --new-user-id new-user-id

TXT
	;

use ProductOpener::Config qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Products qw/:all/;

use Log::Any::Adapter 'TAP';
#use Log::Any::Adapter 'TAP', filter => "none";

my $user_id = $ARGV[0];
my $new_user_id = $ARGV[1];

if ((not defined $user_id) or (not defined $new_user_id)) {
	die("Need current userid and new userid as parameters.\n\n" . $usage);
}

print STDERR "Renaming userid $user_id to $new_user_id in all products.\n";

find_and_replace_user_id_in_products($user_id, $new_user_id);

exit(0);

