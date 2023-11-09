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

ProductOpener::Orgs - manages organizations

=head1 SYNOPSIS

C<ProductOpener::Orgs> contains functions to create and edit organization profiles.

    use ProductOpener::Orgs qw/:all/;

	[..]

=head1 DESCRIPTION

[..]

=cut

package ProductOpener::Orgs;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(

		&list_org_ids
		&retrieve_org
		&store_org
		&create_org
		&retrieve_or_create_org
		&add_user_to_org
		&remove_user_from_org
		&is_user_in_org_group
		&set_org_gs1_gln

		&org_name
		&org_url

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Store qw/:all/;
use ProductOpener::Config qw/:all/;
use ProductOpener::Mail qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Tags qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use Encode;

use Log::Any qw($log);

=head1 DATA

Organization profile data is kept in files in the $data_root/orgs directory.
If it does not exist yet, the directory is created when the module is initialized.

=cut

if (!-e "$data_root/orgs") {
	mkdir("$data_root/orgs", 0755)
		or $log->warn("Could not create orgs dir", {dir => "$data_root/orgs", error => $!})
		if $log->is_warn();
}

=head1 FUNCTIONS

=head2 retrieve_org ( $org_id / $org_name )

=head3 Arguments

=head4 $org_id / $org_name

Identifier for the org (without the "org-" prefix) or org name.

=head3 Return values

This function returns a hash ref for the org, or undef if the org does not exist.

=cut

sub retrieve_org ($org_id_or_name) {

	my $org_id = get_string_id_for_lang("no_language", $org_id_or_name);

	$log->debug("retrieve_org", {org_id_or_name => $org_id_or_name, org_id => $org_id}) if $log->is_debug();

	if (defined $org_id and $org_id ne "") {

		my $org_ref = retrieve("$data_root/orgs/$org_id.sto");
		return $org_ref;
	}

	return;
}

=head1 FUNCTIONS

=head2 list_org_ids()

=head3 Return values

This function returns an array of all existing org ids

=cut

sub list_org_ids () {
	# all .sto but orgs_glns
	my @org_files = glob("$data_root/orgs/*.sto");
	# id is the filename without .sto
	my @org_ids = map {$_ =~ /\/([^\/]+).sto/;} @org_files;
	# remove "orgs_glns"
	@org_ids = grep {!/orgs_glns/} @org_ids;
	return @org_ids;
}

=head2 store_org ( $org_ref )

Save changes to an org

=head3 Arguments

=head4 $org_ref

Hash ref for the org object.

=head3 Return values

None

=cut

sub store_org ($org_ref) {

	$log->debug("store_org", {org_ref => $org_ref}) if $log->is_debug();

	defined $org_ref->{org_id} or die("Missing org_id");

	# retrieve eventual previous values
	my $previous_org_ref = retrieve("$data_root/orgs/" . $org_ref->{org_id} . ".sto");

	if ((defined $previous_org_ref) && !$previous_org_ref->{validated} && $org_ref->{validated}) {
		# we switched on validated
		# TODO: create org and its users in Odoo CRM
	}

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

=head4 boolean $validated

Indicate if the org should be considered validated

=head3 Return values

This function returns a hash ref for the org.

=cut

sub create_org ($creator, $org_id_or_name, $validated = 0) {

	my $org_id = get_string_id_for_lang("no_language", $org_id_or_name);

	$log->debug("create_org", {$org_id_or_name => $org_id_or_name, org_id => $org_id}) if $log->is_debug();

	my $org_ref = {
		created_t => time(),
		creator => $creator,
		org_id => $org_id,
		name => $org_id_or_name,
		# indicates if the org was manually validated
		validated => $validated,
		# by default an org has its data protected
		# we will remove this only if appears later not to be fair-play
		protect_data => "on",
		admins => {},
		members => {},
	};

	store_org($org_ref);

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

sub retrieve_or_create_org ($creator, $org_id_or_name) {

	my $org_id = get_string_id_for_lang("no_language", $org_id_or_name);

	$log->debug("retrieve_or_create_org", {org_id => $org_id}) if $log->is_debug();

	my $org_ref = retrieve_org($org_id);

	if (not defined $org_ref) {
		$org_ref = create_org($creator, $org_id_or_name);
	}

	return $org_ref;
}

=head2 set_org_gs1_gln ( $org_ref, $list_of_gs1_gln )

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

sub set_org_gs1_gln ($org_ref, $list_of_gs1_gln) {

	# Remove existing GLNs
	my $glns_ref = retrieve("$data_root/orgs/orgs_glns.sto");
	not defined $glns_ref and $glns_ref = {};
	if (defined $org_ref->{list_of_gs1_gln}) {
		foreach my $gln (split(/,| /, $org_ref->{list_of_gs1_gln})) {
			$gln =~ s/\s//g;
			if ($gln =~ /[0-9]+/) {
				delete $glns_ref->{$gln};
			}
		}
	}
	# Add new GLNs
	$org_ref->{list_of_gs1_gln} = $list_of_gs1_gln;
	if (defined $org_ref->{list_of_gs1_gln}) {
		foreach my $gln (split(/,| /, $org_ref->{list_of_gs1_gln})) {
			$gln =~ s/\s//g;
			if ($gln =~ /[0-9]+/) {
				$glns_ref->{$gln} = $org_ref->{org_id};
			}
		}
	}
	store("$data_root/orgs/orgs_glns.sto", $glns_ref);
	return;
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

sub add_user_to_org ($org_id_or_ref, $user_id, $groups_ref) {

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

	$log->debug("add_user_to_org",
		{org_id => $org_id, org_ref => $org_ref, user_id => $user_id, groups_ref => $groups_ref})
		if $log->is_debug();

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

sub remove_user_from_org ($org_id_or_ref, $user_id, $groups_ref) {

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

	$log->debug("remove_user_from_org",
		{org_id => $org_id, org_ref => $org_ref, user_id => $user_id, groups_ref => $groups_ref})
		if $log->is_debug();

	foreach my $group (@{$groups_ref}) {
		if (defined $org_ref->{$group}) {
			delete $org_ref->{$group}{$user_id};
		}
	}

	store_org($org_ref);

	return;
}

sub is_user_in_org_group ($org_id_or_ref, $user_id, $group_id) {

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

	if (    (defined $user_id)
		and (defined $org_ref)
		and (defined $org_ref->{$group_id})
		and (defined $org_ref->{$group_id}{$user_id}))
	{
		return 1;
	}
	else {
		return 0;
	}
}

sub org_name ($org_ref) {

	if ((defined $org_ref->{name}) and ($org_ref->{name} ne "")) {
		return $org_ref->{name};
	}
	else {
		return $org_ref->{org_id};
	}
}

sub org_url ($org_ref) {

	return canonicalize_tag_link("orgs", $org_ref->{org_id});
}

1;
