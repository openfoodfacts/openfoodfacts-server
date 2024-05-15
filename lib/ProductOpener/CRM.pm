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

For clarity:
	- user/org refers to the pro platform side
	- contact/company refers to the CRM side, where:
			contact => Odoo partner is an 'individual'
	  		company => Odoo partner is a 'company'

=cut

package ProductOpener::CRM;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&find_or_create_contact
		&find_or_create_company
		&add_contact_to_company
		&create_opportunity
		&add_user_to_company
		&change_company_main_contact
	);
	%EXPORT_TAGS = (all => [@EXPORT_OK]);

}
use vars @EXPORT_OK;

use ProductOpener::Config2;
use ProductOpener::Tags qw(%country_codes_reverse);
use ProductOpener::Users qw/retrieve_user store_user/;
use XML::RPC;
use Log::Any qw($log);

my %odoo_tags = (Producter => '10',);

our @api_credentials;
our $xmlrpc;

=head2 find_or_create_contact ($user_ref)

Attempts to find a contact, and if it doesn't exist, creates it

=head3 Arguments

=head4 $user_ref 

the user to which a 'contact' in the CRM should be linked

=head3 Return values

the id of the contact, or undef if an error occured

=cut

sub find_or_create_contact($user_ref) {
	my $contact_id = find_contact($user_ref);
	if (defined $contact_id) {
		return undef if not link_user_with_contact($user_ref, $contact_id);
	} else {
		$contact_id = create_contact($user_ref);
	}
	return $contact_id;
}

=head2 link_user_with_contact ($org_ref, $contact_id = undef)

Set the off_username field of a contact to the user_id  

=head3 Arguments

=head4 $user_ref 

=head4 $contact_id 

=head3 Return values

1 if success, undef otherwise

=cut

sub link_user_with_contact($user_ref, $contact_id) {
    my $req = odoo('res.partner', 'write', [[$contact_id], { x_off_username => $user_ref->{userid}, category_id => [[4, $odoo_tags{Producter}]]}]);
    $log->debug("link_user_with_contact", {user_id => $user_ref->{userid}, res => $req}) if $log->is_debug();
	return $req;
}

=head2 find_contact ($user_ref)

Finds a contact that has the user_id or same email as the given user_ref

=head3 Arguments

=head4 $user_ref

=head3 Return values

the contact id or undef

=cut

sub find_contact($user_ref) {
    # find the contact with the same user_id OR email, by date of creation (oldest first)
	my $req = odoo('res.partner', 'search_read', [[['is_company', '=', 0], '|', ['x_off_username', '=', $user_ref->{userid}], ['email', '=', $user_ref->{email}]]], 
    {fields => ['name', 'id', 'parent_id'], order => 'create_date ASC', limit => 1});
    my $contact = $req->[0];
	$log->debug("find_matching_contact", {contact => $contact}) if $log->is_debug();
	return $contact->{id};
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
	# 'lang' are actived languages in Odoo
	my $odoo_lang = odoo('res.lang', 'search_read', [[['iso_code', '=', $user_ref->{preferred_language}]]], {fields => ['code']});
	my $found_lang = $odoo_lang->[0];
	$contact->{lang} = $found_lang->{code} // 'en_US'; # default to english
	if (defined $found_lang->{id}) {
		$contact->{x_off_languages} = [$found_lang->{id}];
	}

	# create new contact with linked organization
	my $contact_id = odoo('res.partner', 'create', [{%$contact}]);
	$log->debug("create_contact", {contact_id => $contact_id}) if $log->is_debug();
	return $contact_id;
}

=head2 find_or_create_company ($org_ref, $contact_id = undef)

Attempts to find a company, and if it doesn't exist, creates it

=head3 Arguments

=head4 $org_ref 

the organization to which a 'company' in the CRM should be linked

=head4 $contact_id 

helps the strategy to find the company

=head3 Return values

the id of the contact, or undef if an error occured

=cut

sub find_or_create_company($org_ref, $contact_id = undef) {
	my $company_id = find_company($org_ref, $contact_id);
	if (defined $company_id) {
		return undef if not link_org_with_company($org_ref, $company_id);
	} else {
		$company_id = create_company($org_ref);
	}
	return $company_id;
}

=head2 link_org_with_company ($org_ref, $company_id)

Set the off_org field of a contact to the org_id  

=head3 Arguments

=head4 $org_ref

=head4 $company_id

=head3 Return values

1 if success, undef otherwise

=cut

sub link_org_with_company($org_ref, $company_id) {
    my $req = odoo('res.partner', 'write', [[$company_id], {x_off_org_id => $org_ref->{org_id}, category_id => [[4, $odoo_tags{Producter}]]}]);
    return $req;
}

=head2 find_company ($name)

Finds the oldest company following this strategy:

1. if the company has the corresponding off_org_id, use this one
2. if the contact_id is defined and the company he belongs to has no off_org_id, use this one 
3. if there is a company with the exact same name, use this one

=head3 Arguments

=head4 $user_ref

=head4 $org_ref

=head3 Return values

the company if found, undef otherwise

=cut

sub find_company($org_ref, $contact_id = undef) {
	# 1. & 3. merged in one query
	my $companies = odoo('res.partner', 'search_read', 
	[['&', ['is_company', '=', 1], '|', ['x_off_org_id', '=', $org_ref->{org_id}], '&', ['name', '=', $org_ref->{name}],['x_off_org_id', 'like', '0']]], 
	{fields => ['name', 'id', 'x_off_org_id', 'is_company'], order => 'create_date ASC'});  
	my $company = $companies->[0];
	# 1.
	if (defined $contact_id 
		and defined $company->{id} 
		and $company->{x_off_org_id} ne $org_ref->{org_id}) {
		# find the company of the contact
		my $req = odoo('res.partner', 'read', [$contact_id], {fields => ['name', 'id', 'parent_id']});
		# check if the company has no off_org_id
		my $contact = $req->[0];

		if (defined $contact && $contact->{parent_id} ne '0') {
			my $req = odoo('res.partner', 'read', [$company->{parent_id}->[0]], {fields => ['name', 'id', 'x_off_org_id']});
			my $contact_company = $req->[0];
			if (defined $contact_company and $company->{x_off_org_id} eq '0') {
				# 2.
				return $contact_company->{id};
			}
		}
		# 3
	}
	return $company->{id};
}

=head2 create_company ($org_ref)

Creates a new company in odoo from an org

=head3 Arguments

=head4 $org_ref

=head3 Return values

the id of the created company

=cut

sub create_company ($org_ref) {
	my $main_contact_user_ref = retrieve_user($org_ref);
	my $company = {
		name => 		$org_ref->{name}, 
		phone => 		$org_ref->{phone},
		email => 		$org_ref->{email}, 
		website => 		$org_ref->{website}, 
		category_id =>  [$odoo_tags{Producter}],  # "Producter" category id in odoo
		is_company => 	1,
		x_off_org_id => $org_ref->{org_id}, 
		x_main_contact => $main_contact_user_ref->{x_off_org_id},
	};
	my $company_id = odoo('res.partner', 'create', [{%$company}]);
	$log->debug("create_company", {company_id => $company_id}) if $log->is_debug();
	return $company_id;
}

=head2 add_contact_to_company ($org_ref)

Add a contact to a company in odoo

=head3 Arguments

=head4 $contact_id

=head4 $company_id

=head3 Return values

1 if success, undef otherwise

=cut

sub add_contact_to_company($contact_id, $company_id) {
	# set contact in children of company
	# 4 means add an existing record
	odoo('res.partner', 'write', [[$company_id], {child_ids => [[4, $contact_id]]}]);
	# set company of the contact
	my $result = odoo('res.partner', 'write', [[$contact_id], {parent_id => $company_id}]);
	$log->debug("add_contact_to_company", {company_id => $company_id, contact_id => $contact_id}) if $log->is_debug();
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

sub create_opportunity ($name, $partner_id) {
	my $opportunity_id = odoo('crm.lead', 'create', [{name => $name, partner_id => $partner_id}]);
	$log->debug("create_opportunity", {opportunity_id => $opportunity_id}) if $log->is_debug();
	return $opportunity_id;
}


=head2 add_user_to_company ($user_id, $company_id)

Add a user to a company in odoo.
Attemps to find the contact, create it if it doesn't exist, and add it to the company.

side effect: update user_ref with the corresponding CRM contact_id

=head3 Arguments

=head4 $user_id

=head4 $company_id

=head3 Return values

the contact_id, undef if an error occured while getting the contact_id

=cut

sub add_user_to_company($user_id, $company_id) {
	my $user_ref = retrieve_user($user_id);
	my $contact_id = find_contact($user_ref);
	if (not defined $contact_id) {
		$contact_id = create_contact($user_ref);
	} elsif (not link_user_with_contact($user_ref, $contact_id)) {
		return;
	}
	add_contact_to_company($contact_id, $company_id);
	$user_ref->{crm_user_id} = $contact_id;
	store_user($user_ref);
	return $contact_id;
}

=head2 change_company_main_contact ($org_ref, $user_id)

Change the main contact of a company, 
based on the associated company and contact in the CRM of the given org and user.

=head3 Arguments

=head4 $org_ref

=head4 $user_id 

id of a member of the organization

=head3 Return values

1 if success, undef otherwise

=cut

sub change_company_main_contact($org_ref, $user_id) {

	if (not is_user_in_org_group($org_ref, $user_id, 'members')) {
		$log->error("change_company_main_contact", {cause => "$user_id is not in the organization `$org_ref->{org_id}`"}) if $log->is_error();
		return;
	}

	my $user_ref = retrieve_user($user_id);

	my $req_opportunity = odoo('crm.lead', 'write', [[$org_ref->{crm_opportunity_id}], {partner_id => $user_ref->{crm_user_id}}]);
	return $req_opportunity if not $req_opportunity;

	my $req_company = odoo('res.partner', 'write', [[$org_ref->{crm_org_id}], {x_main_contact => $user_ref->{crm_user_id}}]);
	return $req_company if not $req_company;

	$log->debug("change_company_main_contact", {org_id => $org_ref->{org_id}, userid => $user_id}) if $log->is_debug();
	return $req_opportunity;
}

=head2 odoo (@params)

Calls odoo's API with the given parameters

=head3 Return values

the response or undef if an error occured

=cut

sub odoo(@params) {
	if (not defined $ProductOpener::Config2::crm_api_url) {
		# Odoo CRM is not configured
		return;
	}
	if (not defined $xmlrpc) { 
		# Initialize the connection
		my $api_url = $ProductOpener::Config2::crm_api_url;
		my $username = $ProductOpener::Config2::crm_username;
		my $db = $ProductOpener::Config2::crm_db;
		my $pwd = $ProductOpener::Config2::crm_pwd;

		eval {
			$xmlrpc = XML::RPC->new($api_url . 'common');
		};
		if ($@) {
			$log->error("odoo", {error => $@, reason => "Could not connect to Odoo CRM"}) if $log->is_error();
			$xmlrpc = undef;
			return;
		}

		my $uid;
		eval {
			$uid = $xmlrpc->call('authenticate', $db, $username, $pwd, {});
		};
		if ($@) {
			$log->error("odoo", {error => $@, , reason => "Could not authenticate to Odoo CRM"}) if $log->is_error();
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
		$log->error("odoo", {error => $@, params => \@params, reason => "Could not call Odoo"}) if $log->is_error();
		$xmlrpc = undef;
		return;
	}

	# Check if the result is an error
    if (ref($result) eq 'HASH' && exists $result->{faultCode}) {
        $log->error("odoo", {error => $result->{faultString}, params => \@params, , reason => "Odoo call returned an error"}) if $log->is_error();
        return;
    }

    return $result;
}

1;

