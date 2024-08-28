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
use ProductOpener::Users qw( $User_id retrieve_user );
use ProductOpener::Orgs qw( list_org_ids retrieve_org store_org send_rejection_email);
use ProductOpener::CRM qw( init_crm_data sync_org_with_crm );
use ProductOpener::Store qw( retrieve store );
use ProductOpener::Data qw( :all );
use Log::Any::Adapter 'TAP';
use Encode;

binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");

init_crm_data();

# This file is used to:
# Set the validation status of existing orgs to 'accepted' for the ones in the list, and sync with the CRM.
# Reject all the others and send a rejection email notification to them.
# Set the org name if it is missing.

# Set Manon as the salesperson for the orgs
$User_id = 'manoncorneille';
# the date the dump was made to review the orgs manually
my $dump_t = 1721061880;    # 2024-07-15 16:40:00

# read the list of orgs to sync, one per line (stdin or file)
my %orgs_to_accept = map {chomp; $_ => 1} <>;

# load checkpoint
# rm /mnt/podata/tmp/orgs_synced.checkpoint
my $checkpoint_file = "$BASE_DIRS{CACHE_TMP}/orgs_synced.checkpoint";
my $checkpoint;
if (!-e $checkpoint_file) {
	`touch $checkpoint_file`;
}
open($checkpoint, '+<:encoding(UTF-8)', $checkpoint_file) or die "Could not open file: $!";
my %orgs_processed = map {chomp; $_ => 1} <$checkpoint>;

foreach my $org_id (sort(list_org_ids())) {

	$org_id = decode utf8 => $org_id;
	my $org_ref = retrieve_org($org_id);

	next if exists $orgs_processed{$org_id};
	next if $org_ref->{created_t} > $dump_t;

	my $org_name = $org_ref->{name};
	if (not $org_name) {
		$org_ref->{name} = $org_id =~ s/-/ /gr;
	}

	if (not exists $org_ref->{country} and exists $org_ref->{main_contact}) {
		my $user_ref = retrieve_user($org_ref->{main_contact});
		$org_ref->{country} = $user_ref->{country} || 'en:world';
	}

	my $org_is_valid = exists $orgs_to_accept{$org_id};
	if ($org_is_valid) {
		$org_ref->{valid_org} = 'accepted';
		sync_org_with_crm($org_ref, $User_id);
		print "$org_id synced\n";
	}
	elsif ($org_ref->{valid_org} ne 'rejected' and $org_ref->{valid_org} ne 'accepted') {
		$org_ref->{valid_org} = 'rejected';
		send_rejection_email($org_ref);
		print "$org_id rejected\n";
	}

	store("$BASE_DIRS{ORGS}/" . $org_ref->{org_id} . ".sto", $org_ref);
	my $orgs_collection = get_orgs_collection();
	$orgs_collection->replace_one({"org_id" => $org_ref->{org_id}}, $org_ref, {upsert => 1});

	print $checkpoint "$org_id\n";
}
