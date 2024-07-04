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

use ProductOpener::Config qw/$server_domain/;
use ProductOpener::Store qw/store/;
use ProductOpener::Orgs qw/list_org_ids retrieve_org/;
use ProductOpener::Users qw/retrieve_user/;
use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::CRM qw/:all/;
use Encode;
use JSON;
use LWP::Simple;

binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");

# This script is used to list all the orgs and test if they are already in the CRM.
# And if not, what would be the result of the sync .
# The result is saved in a csv file in the cwd.
# Last columns may be filled by hand and used for later processing.

# fetch all companies and contacts from odoo
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

# Fetch all opportunities
my $fetched_opportunities = make_odoo_request(
	'crm.lead',
	'search_read',
	[],
	{
		'fields' => ['id', 'name', 'partner_id']
	}
);

my %opportunities = map {$_->{id} => $_} @{$fetched_opportunities};

# Fetch number of imported products by org
my $url = "https://world.openfoodfacts.org/owners.json";
my $content = get($url);
if (not defined $content) {
	die "Could not fetch $url";
}
my $orgs = decode_json($content)->{tags};
my $org_by_id = {};
foreach my $org (@{$orgs}) {
	$org_by_id->{$org->{id}} = $org->{products};
}

my $csv
	= "id;name;nbr of imported products;validation status;company id in crm (in .sto);url in crm;Opportunity;Company matched;Will the company be created ?;Contacts matched in crm;Contacts that will be created;Org seems already synced; Errors;salesperson (email); can be accepted (yes/no)\n";

foreach my $orgid (list_org_ids()) {
	my @errors = ();

	$orgid = decode utf8 => $orgid;
	my $org_ref = retrieve_org($orgid);

	my $org_name = $org_ref->{name};
	if (not defined $org_name) {
		push @errors, 'org has no name';
		$org_name = '! has no name !';
	}
	say "Processing org [$orgid] - $org_name";

	my $validation_status = $org_ref->{valid_org} // 'unreviewed';
	my $crm_org_id = $org_ref->{crm_org_id} // '';

	my $main_contact_user_ref = retrieve_user($org_ref->{main_contact});
	my $matched_main_contact = find_contact($main_contact_user_ref);
	$matched_main_contact = defined $matched_main_contact ? $contacts{$matched_main_contact} : undef;
	if (not defined $org_ref->{main_contact}) {
		push @errors, 'org has no main contact';
	}

	my $matched_company = find_company($org_ref, $matched_main_contact);
	$matched_company = defined $matched_company ? $companies{$matched_company} : undef;
	my $company_will_be_created = 'yes';
	if ($matched_company) {
		$company_will_be_created = 'no';
		if ($org_ref->{crm_org_id} and $org_ref->{crm_org_id} ne $matched_company->{id}) {
			push @errors,
				"org has a crm_org_id ($org_ref->{crm_org_id}) but it does not match the company matched in the CRM ($matched_company->{id})";
		}
		$matched_company = "($matched_company->{id}, $matched_company->{name})";
	}
	else {
		$matched_company = '';
	}

	my $members_matched_in_crm = [];
	my $members_not_matched_in_crm = [];

	foreach my $userid (keys %{$org_ref->{members}}) {
		if ($userid ne $main_contact_user_ref->{userid}) {
			my $user_ref = retrieve_user($userid);
			my $contact_id = find_contact($user_ref);
			if ($contact_id) {
				push @{$members_matched_in_crm}, [$userid => $contacts{$contact_id}];
			}
			else {
				push @{$members_not_matched_in_crm}, $userid;
			}
		}
	}

	my $contacts_matched_in_crm = '';
	my @matched_contacts = (@{$members_matched_in_crm});
	if (@matched_contacts) {
		$contacts_matched_in_crm = join(',', map {"($_->[1]{id}, $_->[0])"} @matched_contacts);
	}

	my $contacts_that_will_be_created = '';
	my @not_matched_members = @{$members_not_matched_in_crm};
	if (@not_matched_members) {
		$contacts_that_will_be_created = join(',', @not_matched_members);
	}

	if (defined $matched_main_contact) {
		$contacts_matched_in_crm .= ($contacts_matched_in_crm ? ', ' : '')
			. "($matched_main_contact->{id}, $matched_main_contact->{name}, is main contact, $matched_main_contact->{email})";
	}
	elsif (defined $org_ref->{main_contact}) {
		$contacts_that_will_be_created
			.= ($contacts_that_will_be_created ? ', ' : '') . '(' . $org_ref->{main_contact} . ', as main contact)';
	}

	my $org_url = get_company_url($org_ref) // '', my $opportunity_url = '';
	if (defined $org_ref->{crm_opportunity_id}) {
		if (exists $opportunities{$org_ref->{crm_opportunity_id}}) {
			$opportunity_url = $ProductOpener::Config2::crm_url
				. "/web#id=$org_ref->{crm_opportunity_id}&cids=1&menu_id=133&action=191&model=crm.lead&view_type=form";
		}
		else {
			push @errors, 'opportunity id set but not found in CRM';
		}
	}

	my $org_seems_already_synced = '';
	my $salesperson = '';
	my $ok_accept = '';
	if (    $matched_main_contact
		and $matched_company
		and exists $org_ref->{crm_opportunity_id}
		and $org_ref->{crm_opportunity_id} ne '')
	{
		$org_seems_already_synced = 'yes';
		$salesperson
			= $org_seems_already_synced eq 'yes' ? 'already synced' . (@errors ? ' but look at the errors' : '') : '';
		$ok_accept = $org_seems_already_synced ? 'done' : '';
	}

	my $number_of_imported_products = '?';
	if (exists $org_by_id->{$orgid}) {
		$number_of_imported_products = $org_by_id->{$orgid}{products};
	}
	elsif (exists $org_by_id->{"org-$orgid"}) {
		$number_of_imported_products = $org_by_id->{"org-$orgid"}{products};
	}

	my $has_errors = @errors ? join(", ", @errors) : '';

	$csv
		.= "$orgid;$org_name;$number_of_imported_products;$validation_status;$crm_org_id;$org_url;$opportunity_url;$matched_company;$company_will_be_created;$contacts_matched_in_crm;$contacts_that_will_be_created;$org_seems_already_synced;$has_errors;$salesperson;$ok_accept\n";

}

my $filename = 'accept_org_dry_run_and_form.csv';
open(my $fh, '>:encoding(UTF-8)', $filename) or die "Could not open file '$filename' $!";
print $fh $csv;
close $fh;

