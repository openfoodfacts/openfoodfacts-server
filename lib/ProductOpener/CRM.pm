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


=encoding UTF-8

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
		&create_company
		&create_contact
		&add_contact_to_company
		&create_opportunity
		&test
	);
	%EXPORT_TAGS = (all => [@EXPORT_OK]);

}
use vars @EXPORT_OK;

use ProductOpener::Tags qw(%country_codes_reverse);
use XML::RPC;
use Log::Any qw($log);
use Data::Dumper;
use feature 'say';

my %odoo_tags = (
	'Producter' => '10',
);

our @api_credentials;
our $xmlrpc;


=head1 FUNCTIONS

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
	my $user_country_code = uc $country_codes_reverse{$user_ref->{country}} || 'EN';
	my $country_id = odoo('res.country', 'search_read', [[['code', '=', $user_country_code]]], { 'fields' => ['code', 'id']});
	$contact->{country_id} = $country_id->[0]{id};

	# find spoken language's code in Odoo
	my $odoo_lang = odoo('res.lang', 'search_read', [[['iso_code', '=', $user_ref->{preferred_language}]]], { 'fields' => ['code']});
	my $found_lang = $odoo_lang->[0];
	$contact->{lang} = $found_lang->{code} // 'en_US'; # default to english
	if(defined $found_lang->{id}) {
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

=head2 create_opportunity ($user_ref, $org_ref)

create an opportunity attached to a user 
and named after the organization

=head3 Arguments

=head4 $user_ref

=head4 $org_ref

=head3 Return values

the id of the created opportunity

=cut

sub create_opportunity ($user_ref, $org_ref) {
	my $opportunity_id = odoo('crm.lead', 'create', [{name => "$org_ref->{name} - new org", partner_id => $user_ref->{crm_user_id}}]);
	$log->debug("create_opportunity", {opportunity_id => $opportunity_id}) if $log->is_debug();
	return $opportunity_id;
}


=head2 odoo (@params)

call odoo api with the given parameters

=head3 Return values

the response or undef if an error occured

=cut

sub odoo(@params) {
	if(not defined $xmlrpc) {
		my $api_url = $ENV{ODOO_CRM_URL} . '//xmlrpc/2/';
		my $username = $ENV{ODOO_CRM_USER};
		my $db = $ENV{ODOO_CRM_DB};
		my $pwd = $ENV{ODOO_CRM_PASSWORD};

		eval {
			$xmlrpc = XML::RPC->new($api_url . 'common');
		};
		if($@) {
			$log->warn("odoo", {error => $@, reason => "Could not connect to Odoo CRM"});
			$xmlrpc = undef;
			return;
		}

		my $uid;
		eval {
			$uid = $xmlrpc->call('authenticate', $db, $username, $pwd, {});
		};
		if($@) {
			$log->warn("odoo", {error => $@, , reason => "Could not authenticate to Odoo CRM"});
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
	if($@) {
		$log->warn("odoo", {error => $@, params => \@params, reason => "Could not call Odoo"});
		$xmlrpc = undef;
		return;
	}

	# Check if the result is an error
    if (ref($result) eq 'HASH' && exists $result->{faultCode}) {
        $log->warn("odoo", {error => $result->{faultString}, params => \@params, , reason => "Odoo call returned an error"});
        return;
    }

    return $result;
}


1;

