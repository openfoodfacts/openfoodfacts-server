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

use ProductOpener::PerlStandards;

use ProductOpener::Orgs qw/:all/;

sub run_migration() {
	my $num_migrated = 0;
	my @org_ids = list_org_ids();
	foreach my $org_id (@org_ids) {
		my $org_ref = retrieve_org($org_id);
		if (!((defined $org_ref->{protect_data}) && ($org_ref->{protect_data} eq "on"))) {
			$org_ref->{protect_data} = "on";
			store_org($org_ref);
			$num_migrated++;
		}
	}
	print("$num_migrated org migrated\n");
	return 1;
}

run_migration();
