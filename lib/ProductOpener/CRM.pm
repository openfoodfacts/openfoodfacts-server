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
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

=head1 NAME

ProductOpener::CRM - manages integration with the Odoo CRM

=head1 SYNOPSIS

C<ProductOpener::CRM> contains functions to interact with the Odoo CRM


=head1 DESCRIPTION

[..]

=cut

package ProductOpener::CRM;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&create_opportunity_with_user_and_company
	);
	%EXPORT_TAGS = (all => [@EXPORT_OK]);

}
use vars @EXPORT_OK;

use ProductOpener::Config2;
use ProductOpener::Tags qw(%country_codes_reverse);
use XML::RPC;
use Log::Any qw($log);

my %odoo_tags = (Producter => '10',);

our @api_credentials;
our $xmlrpc;

=head2 create_opportunity_with_user_and_company ($user_ref, $org_ref)

Attemps to match existing contacts and companies before creating new ones.
The opportunity is created only if the company is new.
The opportunity is attached to the user and named after the organization.

=head3 Arguments

=head4 $org_ref

=head3 Return values

A hash ref : crm_user_id, crm_org_id, crm_opportunity_id (if the company was created and not matched),
otherwise undef if an error occured

=cut

sub create_opportunity_with_user_and_company($user_ref, $org_ref) {
	my ($matched_user_id, $matched_org_id) = find_existing_partners($user_ref, $org_ref);
	eval {
		my $crm_org_id;
		if (defined $matched_org_id) {
			$crm_org_id = $matched_org_id;
			die "Failed to link org to odoo's company" if not defined link_org_with_company($org_ref, $crm_org_id);
		} else {
			$crm_org_id = create_company($org_ref);
			die "Failed to create company" if not defined $crm_org_id;
		}
		my $crm_user_id;
		if (defined $matched_user_id) {
			$crm_user_id = $matched_user_id;
			die "Failed to associate user with odoo's contact" if not defined link_user_with_contact($user_ref, $crm_user_id);
		} else {
			$crm_user_id = create_contact($user_ref);
			die "Failed to create contact" if not defined $crm_user_id;
		}

		if (not defined $matched_org_id && not defined $matched_user_id) {
			die "Failed to add contact to company" if not defined add_contact_to_company($crm_user_id, $crm_org_id);
		}

		my $opportunity_id;
		if (not defined $matched_org_id) {
			# only because the org is new, we create an opportunity
			$opportunity_id = create_opportunity("$org_ref->{name} - new", $crm_user_id);
			die "Failed to create opportunity" if not defined $opportunity_id;
		}

		return {crm_user_id => $crm_user_id, 
				crm_org_id => $crm_org_id, 
				crm_opportunity_id => $opportunity_id};
		1;
	} or do {
		$log->warn("store_org", {err => $@}) if $log->is_warn();
	};
	return undef;
}

=head2 create_company ($org_ref)

Creates a new company in odoo from an org

=head3 Arguments

=head4 $org_ref

=head3 Return values

the id of the created company

=cut

sub create_company ($org_ref) {
	my $company = {
		name => 		$org_ref->{name}, 
		x_off_org_id => $org_ref->{org_id}, 
		phone => 		$org_ref->{phone},
		email => 		$org_ref->{email}, 
		website => 		$org_ref->{website}, 
		category_id =>  [$odoo_tags{Producter}],  # "Producter" category id in odoo
		is_company => 	1,
	};
	my $company_id = odoo('res.partner', 'create', [{%$company}]);
	$log->debug("create_company", {company_id => $company_id}) if $log->is_debug();
	return $company_id;
}



=head2 create_contact ($user_ref)

Creates a new contact in odoo from a user

=head3 Arguments

=head4 $org_ref

=head3 Return values

the id of the created contact

=cut

sub create_contact ($user_ref) {
	my $contact = {
		name => 			$user_ref->{name}, 
		x_off_username => 	$user_ref->{userid},
		email => 			$user_ref->{email},
		phone => 			$user_ref->{phone}, 
		category_id => 		[$odoo_tags{Producter}],
	};
	
	# find country code id in odoo
	my $user_country_code = uc($country_codes_reverse{$user_ref->{country}}) || 'EN';
	my $country_id = odoo('res.country', 'search_read', [[['code', '=', $user_country_code]]], {fields => ['code', 'id']});
	$contact->{country_id} = $country_id->[0]{id};

	# find spoken language's code in Odoo
	my $odoo_lang = odoo('res.lang', 'search_read', [[['iso_code', '=', $user_ref->{preferred_language}]]], {fields => ['code']});
	my $found_lang = $odoo_lang->[0];
	$contact->{lang} = $found_lang->{code} // 'en_US'; # default to english
	if (defined $found_lang->{id}) {
		$contact->{x_off_languages} = [$found_lang->{id}];
	}

	# create new contact with associated organization
	my $contact_id = odoo('res.partner', 'create', [{%$contact}]);
	$log->debug("create_contact", {contact_id => $contact_id}) if $log->is_debug();
	return $contact_id;
}

=head2 add_contact_to_company ($org_ref)

Add a contact to a company in odoo

=head3 Arguments

=head4 $crm_user_id

=head4 $crm_org_id

=head3 Return values

1 if success, undef otherwise

=cut

sub add_contact_to_company($crm_user_id, $crm_org_id) {
	# set contact in children of company
	# 4 means add an existing record
	odoo('res.partner', 'write', [[$crm_org_id], {child_ids => [[4, $crm_user_id]]}]);
	# set company of the contact
	my $result = odoo('res.partner', 'write', [[$crm_user_id], {parent_id => $crm_org_id}]);
	$log->debug("add_contact_to_company", {company_id => $crm_org_id, contact_id => $crm_user_id}) if $log->is_debug();
	return $result
}

=head2 create_opportunity ($name, $partner_id)

create an opportunity attached to a partner 
and named after the organization

=head3 Arguments

=head4 $name

The name of the opportunity

=head4 $partner_id

The id of the partner to attach the opportunity to.
It can be a contact or a company

=head3 Return values

the id of the created opportunity

=cut
# "$org_ref->{name} - new org
sub create_opportunity ($name, $partner_id) {
	my $opportunity_id = odoo('crm.lead', 'create', [{name => $name, partner_id => $partner_id}]);
	$log->debug("create_opportunity", {opportunity_id => $opportunity_id}) if $log->is_debug();
	return $opportunity_id;
}


=head2 find_matching_org_with_user ($user_ref, $org_ref)

Finds a contact who has the same off_user_id as the given user_ref 
and who belongs to a company with the same off_org_id as the given org_ref

=head3 Arguments

=head4 $user_ref

=head4 $org_ref

=head3 Return values

a tuple with the contact id and the company id if found, undef otherwise

=cut

sub find_matching_org_and_user_by_id($org_ref, $user_ref) {

    my $contact = odoo('res.partner', 'search_read', [[['x_off_username', '=', $user_ref->{userid}], ['parent_id.x_off_org_id', '=', $org_ref->{org_id}]]],
	 { fields => ['name', 'id', 'parent_id', 'x_off_username'], limit => 1});

    my $contact_id = $contact->[0]->{id};
    my $company_id = $contact->[0]->{parent_id}->[0];
    if (defined $contact_id && defined $company_id) {
        return ($contact_id, $company_id);
    }
    return;
}

=head2 find_matching_contact ($user_ref)

Finds a contact that has the same email as the given user_ref, 
and get the company if it is linked to one without an off_org_id

=head3 Arguments

=head4 $user_ref

=head3 Return values

a tuple with the contact id and the company id if found, undef otherwise

=cut

sub find_matching_contact($user_ref) {

    # find the contact with the same email, by date of creation (oldest first)
    my $req = odoo('res.partner', 'search_read', [[['email', '=', $user_ref->{email}], ['is_company', '=', 0]]], 
    {fields => ['name', 'id', 'parent_id'], order => 'create_date ASC', limit => 1});
    my $contact = $req->[0];
	$log->debug("find_matching_contact", {contact => $contact}) if $log->is_debug();
    # if the contact is linked to a company without an off_org_id, get the company
    if (defined $contact->{id}) {
		if (exists $contact->{parent_id} && $contact->{parent_id}->[0] ne '0') {
			my $req = odoo('res.partner', 'read', [$contact->{parent_id}->[0]], {fields => ['name', 'id', 'x_off_org_id']});
			my $company = $req->[0];
			if (defined $company && $company->{x_off_org_id} eq '0') {
				return ($contact->{id}, $company->{id});
			}
		}
        return ($contact->{id})
    }
	return;
}

=head2 find_oldest_company_with_exact_name ($name)

Finds the oldest company with exact same name and no off_org_id

=head3 Arguments

=head4 $user_ref

=head4 $org_ref

=head3 Return values

the company if found, undef otherwise

=cut

sub find_oldest_company_with_exact_name($name) {
    
    my $companies = odoo('res.partner', 'search_read', 
    [[['name', '=', $name], ['is_company', '=', 1], ['x_off_org_id', 'like', '0']]], 
    {fields => ['name', 'id', 'x_off_org_id', 'is_company'], order => 'create_date ASC'});    
    
    return $companies->[0]->{id};
}


=head2 find_existing_partners($user_ref, $org_ref)

Tries to match existing partners (individual/company) in odoo, following these steps:

1. if there is a matching entry with off_org_id / off_user_id set 
   (it might have been set by producer platform team), use this one
2. if there is a contact with matching email (and no off_user_id), 
   use this one and if it's linked to an org (without an off_org_id), match it to the org
3. if there is an org with the exact same name (and no off_org_id) use this one

=head3 Arguments

=head4 $user_ref

=head4 $org_ref

=head3 Return values

a tuple with the contact id and the company id if found

=cut

sub find_existing_partners($user_ref, $org_ref) {
	my ($contact_id, $company_id) = find_matching_org_and_user_by_id($org_ref, $user_ref);
	if (not defined $contact_id and not defined $company_id) {
		($contact_id, $company_id) = find_matching_contact($user_ref);
		$company_id = $company_id // find_oldest_company_with_exact_name($org_ref->{name});
	}
	$log->debug("find_existing_partners", {contact_id => $contact_id, company_id => $company_id}) if $log->is_debug();
	return ($contact_id, $company_id);
}


sub link_user_with_contact($user_ref, $contact_id) {
    my $req = odoo('res.partner', 'write', [[$contact_id], { x_off_username => $user_ref->{userid}, category_id => [[4, $odoo_tags{Producter}]]}]);
    $log->debug("associate_user_with_contact", {user_id => $user_ref->{userid}}) if $log->is_debug();
	return $req;
}

sub link_org_with_company($org_ref, $company_id) {
    my $req = odoo('res.partner', 'write', [[$company_id], {x_off_org_id => $org_ref->{org_id}, category_id => [[4, $odoo_tags{Producter}]]}]);
    return $req;
}


=head2 odoo (@params)

Calls odoo api with the given parameters

=head3 Return values

the response or undef if an error occured

=cut

sub odoo(@params) {
	if (not defined $ProductOpener::Config2::crm_api_url) {
		return;
	}
	if (not defined $xmlrpc) {
		my $api_url = $ProductOpener::Config2::crm_api_url;
		my $username = $ProductOpener::Config2::crm_username;
		my $db = $ProductOpener::Config2::crm_db;
		my $pwd = $ProductOpener::Config2::crm_pwd;

		eval {
			$xmlrpc = XML::RPC->new($api_url . 'common');
		};
		if ($@) {
			$log->warn("odoo", {error => $@, reason => "Could not connect to Odoo CRM"}) if $log->is_warn();
			$xmlrpc = undef;
			return;
		}

		my $uid;
		eval {
			$uid = $xmlrpc->call('authenticate', $db, $username, $pwd, {});
		};
		if ($@) {
			$log->warn("odoo", {error => $@, , reason => "Could not authenticate to Odoo CRM"}) if $log->is_warn();
			$xmlrpc = undef;
			return;
		}
		@api_credentials = ($db, $uid, $pwd);
		$xmlrpc = XML::RPC->new($api_url . 'object');
	}
	
	my $result;
	eval {
		$result = $xmlrpc->call('execute_kw', (@api_credentials, @params));
	};
	if ($@) {
		$log->warn("odoo", {error => $@, params => \@params, reason => "Could not call Odoo"}) if $log->is_warn();
		$xmlrpc = undef;
		return;
	}

	# Check if the result is an error
    if (ref($result) eq 'HASH' && exists $result->{faultCode}) {
        $log->warn("odoo", {error => $result->{faultString}, params => \@params, , reason => "Odoo call returned an error"}) if $log->is_warn();
        return;
    }

    return $result;
}


1;

