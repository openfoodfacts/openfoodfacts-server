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
use ProductOpener::Data qw/:all/;
use ProductOpener::Orgs qw/list_org_ids retrieve_org/;
use ProductOpener::Users qw/retrieve_user/;
use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Store qw/:all/;

my $orgs_collection = get_orgs_collection();

sub main {
	my @orgs = list_org_ids();
	my $count = scalar @orgs;
	my $i = 0;

	foreach my $org_id (@orgs) {
		my $org_ref = retrieve_org($org_id);
		next if not defined $org_ref;

		my $creator_username = $org_ref->{creator};
		next if not defined $creator_username;

		my $creator_user_ref = retrieve_user($creator_username);
		next if not defined $creator_user_ref;

		my $creator_email = $creator_user_ref->{email};
		next if not defined $creator_email;

		$org_ref->{creator_email} = $creator_email;

		my $return = $orgs_collection->update_one({"org_id" => $org_ref->{org_id}},
			{'$set' => {"creator_email" => $creator_email}});
		store("$BASE_DIRS{ORGS}/" . $org_ref->{org_id} . ".sto", $org_ref);

		print STDERR "Updated organization $org_id with creator's email $creator_email. Return: $return\n";
		$i++;
	}

	print STDERR "$count organizations to update - $i organizations not empty or deleted\n";
	return;
}

main();

exit(0);
