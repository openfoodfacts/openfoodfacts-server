# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2020 Association Open Food Facts
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

ProductOpener::Orgs - manages organizations

=head1 SYNOPSIS

C<ProductOpener::Orgs> contains functions to create and edit organization profiles.

    use ProductOpener::Orgs qw/:all/;

	[..]

=head1 DESCRIPTION

[..]

=cut

package ProductOpener::Orgs;

use utf8;
use Modern::Perl '2017';
use Exporter    qw< import >;

BEGIN
{
	use vars       qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(

		&retrieve_org
		&store_org
		&create_org
		&retrieve_or_create_org
		&add_user_to_org
		&remove_user_from_org

		&org_name
		&org_url
		&org_link

		);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;

use ProductOpener::Store qw/:all/;
use ProductOpener::Config qw/:all/;
use ProductOpener::Mail qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Cache qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Tags qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use Encode;


use Log::Any qw($log);


=head1 FUNCTIONS

=head2 retrieve_org ( $org_id / $org_name )

=head3 Arguments

=head4 $org_id / $org_name

Identifier for the org (without the "org-" prefix) or org name.

=head3 Return values

This function returns a hash ref for the org, or undef if the org does not exist.

=cut

sub retrieve_org($) {

	my $org_id_or_name = shift;
	
	my $org_id = get_string_id_for_lang("no_language", $org_id_or_name);

	$log->debug("retrieve_org", { org_id_or_name => $org_id_or_name, org_id => $org_id } ) if $log->is_debug();

	my $org_ref = retrieve("$data_root/orgs/$org_id.sto");

	return $org_ref;
}


=head2 store_org ( $org_ref )

=head3 Arguments

=head4 $org_ref

Hash ref for the org object.

=head3 Return values

None

=cut

sub store_org($) {
	
	my $org_ref = shift;

	$log->debug("store_org", { org_ref => $org_ref } ) if $log->is_debug();
	
	defined $org_ref->{org_id} or die("Missing org_id");

	store("$data_root/orgs/" . $org_ref->{org_id} . ".sto", $org_ref);

	return;
}


=head2 create_org ( $creator, $org_id / $org_name, $org_ref )

Creates a new org.

=head3 Arguments

=head4 $creator

User id of the user creating the org (it can be the first user of the org,
or an admin that creates an org by assigning an user to it).

=head4 $org_id / $org_name

Identifier for the org (without the "org-" prefix), or org name.

=head3 Return values

This function returns a hash ref for the org.

=cut

sub create_org($$) {

	my $creator = shift;
	my $org_id_or_name = shift;
	
	my $org_id = get_string_id_for_lang("no_language", $org_id_or_name);

	$log->debug("create_org", { $org_id_or_name => $org_id_or_name, org_id => $org_id } ) if $log->is_debug();

	my $org_ref = {
		created_t => time(),
		creator   => $creator,
		org_id    => $org_id,
		name  => $org_id_or_name,
		admins    => {},
		members   => {},
	};

	store_org($org_ref);
	
	my $admin_mail_body = <<EMAIL
creator: $creator
org_id: $org_id
name: $org_id_or_name
EMAIL
;
	send_email_to_producers_admin(
		"Org created - creator: $creator - org: $org_id",
		$admin_mail_body );

	return $org_ref;
}


=head2 retrieve_or_create_org ( $creator, $org_id / $org_name, $org_ref )

If the org exists, the function returns the org object. Otherwise it creates a new org.

=head3 Arguments

=head4 $creator

User id of the user creating the org (it can be the first user of the org,
or an admin that creates an org by assigning an user to it).

=head4 $org_id / $org_name

Identifier for the org (without the "org-" prefix), or org name.

=head3 Return values

This function returns a hash ref for the org.

=cut

sub retrieve_or_create_org($$) {

	my $creator = shift;
	my $org_id_or_name = shift;
	
	my $org_id = get_string_id_for_lang("no_language", $org_id_or_name);

	$log->debug("retrieve_or_create_org", { org_id => $org_id } ) if $log->is_debug();
		
	my $org_ref = retrieve_org($org_id);
	
	if (not defined $org_ref) {
		$org_ref = create_org($creator, $org_id_or_name);
	}

	return $org_ref;
}


=head2 add_user_to_org ( $org_id / $org_ref, $user_id, $groups_ref )

Add the user to the specified groups of an organization.

=head3 Arguments

=head4 $org_id / $org_ref

Org id or org object.

=head4 $user_id

User id.

=head4 $groups_ref

Reference to an array of group ids (e.g. ["admins", "members"])

=cut

sub add_user_to_org($$$) {

	my $org_id_or_ref = shift;
	my $user_id = shift;
	my $groups_ref = shift;
	
	my $org_id;
	my $org_ref;
	
	if (ref($org_id_or_ref) eq "") {
		$org_id = $org_id_or_ref;
		$org_ref = retrieve_org($org_id);
	}
	else {
		$org_ref = $org_id_or_ref;
		$org_id = $org_ref->{org_id};
	}

	$log->debug("add_user_to_org", { org_id => $org_id, org_ref => $org_ref, user_id => $user_id, groups_ref => $groups_ref } ) if $log->is_debug();
		
	foreach my $group (@{$groups_ref}) {
		(defined $org_ref->{$group}) or $org_ref->{$group} = {};
		$org_ref->{$group}{$user_id} = 1;
	}

	store_org($org_ref);

	return;
}


=head2 remove_user_from_org ( $org_id / $org_ref, $user_id, $groups_ref )

Remove the user from the specified groups of an organization.

=head3 Arguments

=head4 $org_id / $org_ref

Org id or org object.

=head4 $user_id

User id.

=head4 $groups_ref

Reference to an array of group ids (e.g. ["admins", "members"])

=cut

sub remove_user_from_org($$$) {

	my $org_id_or_ref = shift;
	my $user_id = shift;
	my $groups_ref = shift;
	
	my $org_id;
	my $org_ref;
	
	if (ref($org_id_or_ref) eq "") {
		$org_id = $org_id_or_ref;
		$org_ref = retrieve_org($org_id);
	}
	else {
		$org_ref = $org_id_or_ref;
		$org_id = $org_ref->{org_id};
	}

	$log->debug("remove_user_from_org", { org_id => $org_id, org_ref => $org_ref, user_id => $user_id, groups_ref => $groups_ref } ) if $log->is_debug();
		
	foreach my $group (@{$groups_ref}) {
		if (defined $org_ref->{$group}) {
			delete $org_ref->{$group}{$user_id};
		}
	}

	store_org($org_ref);

	return;
}


sub org_name($) {
	
	my $org_ref = shift;
	
	if ((defined $org_ref->{name}) and ($org_ref->{name} ne "")) {
		return $org_ref->{name};
	}
	else {
		return $org_ref->{org_id};
	}
}

sub org_url($) {

	my $org_ref = shift;

	return canonicalize_tag_link("orgs", $org_ref->{org_id});
}

sub org_link($) {
	
	my $org_ref = shift;
	
	return "<a href=\"" . org_url($org_ref) . "\">" . org_name($org_ref) . "</a>";
}

1;
