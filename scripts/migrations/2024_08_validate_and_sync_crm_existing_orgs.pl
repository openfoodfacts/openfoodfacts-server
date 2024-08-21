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
use Modern::Perl '2017';
use utf8;

use ProductOpener::Config qw( $data_root );
use ProductOpener::Paths qw( %BASE_DIRS );
use ProductOpener::Users qw( $User_id );
use ProductOpener::Orgs qw( list_org_ids retrieve_org store_org );
use Encode;

binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");

# This file is used to:
# Set the validation status of existing orgs to 'accepted' for the ones in the list, and sync with the CRM.
# Reject all the others and send a rejection email notification to them.
# Set the org name if it is missing.

# Set Manon as the salesperson for the orgs
$User_id = 'manoncorneille';

# read the list of orgs to sync
open my $orgs_to_accept, '<', "scripts/migrations/input/2024_08_orgs_to_accept_and_sync"
	or die "Could not open file: $!";
my %orgs_to_accept = map {chomp; $_ => 1} <$orgs_to_accept>;
close $orgs_to_accept;

# load checkpoint
my $checkpoint_file = "$BASE_DIRS{CACHE_TMP}/orgs_synced.checkpoint";
my $checkpoint;
if (!-e $checkpoint_file) {
	`touch $checkpoint_file`;
}
open($checkpoint, '+<:encoding(UTF-8)', $checkpoint_file) or die "Could not open file: $!";
foreach my $org_id (<$checkpoint>) {
	chomp $org_id;
	delete $orgs_to_accept{$org_id};
}

# if all orgs have been synced, exit
if (scalar keys %orgs_to_accept == 0) {
	print "All orgs have been synced\n";
	close $checkpoint;
	exit;
}

foreach my $org_id (list_org_ids()) {
	$org_id = decode utf8 => $org_id;
	my $org_ref = retrieve_org($org_id);

	my $org_name = $org_ref->{name};
	if (not defined $org_name) {
		$org_ref->{name} = $org_id =~ s/-/ /gr;
	}

	my $org_is_valid = exists $orgs_to_accept{$org_id};
	if ($org_is_valid) {
		$org_ref->{valid_org} = 'accepted';
	}
	else {
		$org_ref->{valid_org} = 'rejected';
	}

	store_org($org_ref);
	if ($org_is_valid) {
		print "$org_id\n";
		print $checkpoint "$org_id\n";
	}
}
