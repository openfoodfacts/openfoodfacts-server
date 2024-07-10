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

# This file is used
# to change the main_contact field of orgs that are not users
# to an undef value

use ProductOpener::Store qw/store/;
use ProductOpener::Orgs qw/list_org_ids retrieve_org/;
use ProductOpener::Paths qw/%BASE_DIRS/;


my $not_users = qw(agena3000 equadis codeonline bayard database-usda countrybot);

foreach my $org_id (list_org_ids()) {
	my $org_ref = retrieve_org($org_id);
    
	# if main_contact is empty, blank or contains multiple blank or invisble characters or is equal to one of the bad contacts, set it to empty
    if (not defined $org_ref->{main_contact}          # undefined
        or $org_ref->{main_contact} =~ /^\s*$/        # empty or only whitespace
        or $org_ref->{main_contact} =~ /[\p{Z}\p{C}]/ # contains unicode whitespace or control characters
        or grep { $org_ref->{main_contact} eq $_ } @not_users) {

        $org_ref->{main_contact} = undef;
    }

	# not using store_org to avoid triggering the odoo sync
	store("$BASE_DIRS{ORGS}/" . $org_ref->{org_id} . ".sto", $org_ref);
}

