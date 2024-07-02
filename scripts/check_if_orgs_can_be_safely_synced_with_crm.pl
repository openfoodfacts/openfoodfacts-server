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

# This script is used to list all the orgs and test if they are already in the CRM.
# And if not, what would be the result of the sync .
# The result is saved in a csv file in the cwd.
# Last columns may be filled by hand and used for later processing.

use ProductOpener::PerlStandards;
use Modern::Perl '2017';
use utf8;

use ProductOpener::Store qw/store/;
use ProductOpener::Orgs qw/list_org_ids retrieve_org/;
use ProductOpener::Users qw/retrieve_user/;
use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::CRM qw/:all/;
use Encode;

binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");

my $matches = [];

my $fetched_partners = make_odoo_request(
	'res.partner',
	'search_read',
	[],
	{
		'fields' => ['id', 'name', 'email', 'is_company']
	}
);

my %contacts = ();
my %companies = ();
foreach my $partner (@{$fetched_partners}) {
	if ($partner->{is_company}) {
		$companies{$partner->{id}} = $partner;
	}
	else {
		$contacts{$partner->{id}} = $partner;
	}
}

foreach my $orgid (list_org_ids()) {
	my @errors = ();
	$orgid = decode utf8 => $orgid;
	my $org_ref = retrieve_org($orgid);
	if (not defined $org_ref->{name}) {
		push @errors, 'org has no name';
	}
	$org_ref->{name} //= '! has no name !';
	say "Processing org [$orgid] - $org_ref->{name}";
	if (not defined $org_ref->{main_contact}) {
		push @errors, 'org has no main contact';
	}
	my $main_contact_user_ref = retrieve_user($org_ref->{main_contact});
	my $matched_main_contact = find_contact($main_contact_user_ref);
	my $matched_company = find_company($org_ref, $matched_main_contact);

	my $match = {
		org_name => $org_ref->{name},
		org_id => $orgid,
		org_main_contact => $org_ref->{main_contact},
		validation_status => $org_ref->{valid_org} // 'unreviewed',
		crm_org_id => $org_ref->{crm_org_id} // '',
		matched_company => $matched_company ? $companies{$matched_company} : undef,
		contacts => {
			main_contact => $matched_main_contact ? $contacts{$matched_main_contact} : undef,
			members_matched_in_crm => [],
			members_not_matched_in_crm => [],
		},
	};

	foreach my $userid (keys %{$org_ref->{members}}) {
		if ($userid ne $main_contact_user_ref->{userid}) {
			my $user_ref = retrieve_user($userid);
			my $contact_id = find_contact($user_ref);
			if ($contact_id) {
				push @{$match->{contacts}->{members_matched_in_crm}}, [$userid => $contacts{$contact_id}];
			}
			else {
				push @{$match->{contacts}->{members_not_matched_in_crm}}, $userid;
			}
		}
	}

	if (    $matched_main_contact
		and $matched_company
		and exists $org_ref->{crm_opportunity_id}
		and $org_ref->{crm_opportunity_id} ne '')
	{
		$match->{org_seems_already_synced} = 1;
	}

	$match->{errors} = \@errors;

	push @{$matches}, $match;
}

my $csv
	= "org_id;org_name;validation_status;crm_org_id;matched_company;will the company be created ?;contacts_matched_in_crm;contacts_that_will_be_created;org_seems_already_synced;has errors;salesperson (email);ok accept (yes/no)\n";

foreach my $match (@{$matches}) {
	say "Processing org $match->{org_id} - $match->{org_name}";
	my $org_id = $match->{org_id};
	my $org_name = $match->{org_name};
	my $validation_status = $match->{validation_status};
	my $crm_org_id = $match->{crm_org_id};

	my $matched_company = '';
	if ($match->{matched_company}) {
		$matched_company = "($match->{matched_company}{id}, $match->{matched_company}{name})";
	}
	my $company_will_be_created = $match->{matched_company} ? 'no' : 'yes';

	my $contacts_matched_in_crm = '';
	my @matched_contacts = (@{$match->{contacts}->{members_matched_in_crm}});
	if (@matched_contacts) {
		$contacts_matched_in_crm = join(',', map {"($_->[1]{id}, $_->[0])"} @matched_contacts);
	}

	my $contacts_that_will_be_created = '';
	my @not_matched_members = @{$match->{contacts}->{members_not_matched_in_crm}};
	if (@not_matched_members) {
		$contacts_that_will_be_created = join(',', @not_matched_members);
	}

	if (defined $match->{contacts}->{main_contact}) {
		$contacts_matched_in_crm .= ($contacts_matched_in_crm ? ', ' : '')
			. "($match->{contacts}{main_contact}{id}, $match->{contacts}{main_contact}{name}, is main contact)";
	}
	elsif (defined $match->{org_main_contact}) {
		$contacts_that_will_be_created
			.= ($contacts_that_will_be_created ? ', ' : '') . '(' . $match->{org_main_contact} . ', as main contact)';
	}

	my $org_seems_already_synced = $match->{org_seems_already_sync} ? 1 : 0;
	my $salesperson = $match->{org_seems_already_synced} ? 'already synced' : '';
	my $ok_accept = $match->{org_seems_already_synced} ? 'done' : '';

	my $has_errors = $match->{errors} ? join(',', @{$match->{errors}}) : '';

	$csv
		.= "$org_id;$org_name;$validation_status;$crm_org_id;$matched_company;$company_will_be_created;$contacts_matched_in_crm;$contacts_that_will_be_created;$org_seems_already_synced;$has_errors;$salesperson;$ok_accept\n";
}

# say $csv;

my $filename = 'accept_org_dry_run_and_form.csv';
open(my $fh, '>:encoding(UTF-8)', $filename) or die "Could not open file '$filename' $!";
print $fh $csv;
close $fh;
