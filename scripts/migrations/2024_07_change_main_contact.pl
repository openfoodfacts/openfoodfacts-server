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
# or to the first admin of the org if it exists

use ProductOpener::Store qw/store/;
use ProductOpener::Orgs qw/list_org_ids retrieve_org/;
use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Config qw/%admins/;
use Encode;

binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");

my @not_users = qw(agena3000 equadis codeonline bayard database-usda countrybot );
push @not_users, keys %admins;

foreach my $org_id (list_org_ids()) {

	$org_id = decode utf8 => $org_id;    # because of wide characters in org_id like greek letters
	my $org_ref = retrieve_org($org_id);

	if (
		(defined $org_ref->{main_contact})
		and (
			($org_ref->{main_contact} =~ /^\s*$/)    # empty or only whitespace
			or ($org_ref->{main_contact} =~ /[\p{Z}\p{C}]/)    # contains unicode whitespace or control characters
			or (grep {$org_ref->{main_contact} eq $_} @not_users)
		)    # shouldn't be a main contact
		or (not defined $org_ref->{main_contact})
		)
	{
		if (defined $org_ref->{main_contact}) {
			print "previous main contact: " . $org_ref->{main_contact} . "\n";
		}

		$org_ref->{main_contact} = undef;

		# take the first admin as main contact if available
		print $org_id . "\n";
		if (defined $org_ref->{admins}) {
			# find the first admin that is not in the list of users that are not users
			# and set it as main contact

			my $admin = undef;
			foreach my $admin_id (sort keys %{$org_ref->{admins}}) {
				if (not grep {$admin_id eq $_} @not_users) {
					$admin = $admin_id;
					$org_ref->{main_contact} = $admin;
					last;
				}
			}
			if (defined $org_ref->{main_contact}) {
				print "main_contact of $org_id set to $org_ref->{main_contact}\n";
			}
		}
		else {
			print "main_contact of $org_id set to undef\n";
		}
	}

	# not using store_org to avoid triggering the odoo sync
	store("$BASE_DIRS{ORGS}/" . $org_id . ".sto", $org_ref);
}

