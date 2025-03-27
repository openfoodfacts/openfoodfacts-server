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
		&update_import_date
		&update_export_date
		&update_last_logged_in_member
		&update_last_import_type
		&accept_pending_user_in_org
		&send_rejection_email

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Store qw/get_string_id_for_lang retrieve store/;
use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/%BASE_DIRS ensure_dir_created/;
use ProductOpener::Mail qw/:all/;
use ProductOpener::Lang qw/lang/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Tags qw/canonicalize_tag_link/;
use ProductOpener::CRM qw/:all/;
use ProductOpener::Users qw/retrieve_user store_user $User_id %User/;
use ProductOpener::Data qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use Encode;

use Log::Any qw($log);

=head1 DATA

Organization profile data is kept in files in the $BASE_DIRS{ORGS} directory.
If it does not exist yet, the directory is created when the module is initialized.

=cut

ensure_dir_created($BASE_DIRS{ORGS});

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
		my $org_ref = retrieve("$BASE_DIRS{ORGS}/$org_id.sto");
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
	my @org_files = glob("$BASE_DIRS{ORGS}/*.sto");
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
	my $previous_org_ref = retrieve("$BASE_DIRS{ORGS}/$org_ref->{org_id}.sto");

	if (defined $org_ref->{creator}) {
		my $creator_user_ref = retrieve_user($org_ref->{creator});
		if (defined $creator_user_ref) {
			my $creator_email = $creator_user_ref->{email};
			if (defined $creator_email) {
				$org_ref->{creator_email} = $creator_email;
			}
		}
	}

	if (   (defined $previous_org_ref)
		&& ($previous_org_ref->{valid_org} ne 'accepted')
		&& ($org_ref->{valid_org} eq 'accepted')
		&& (not sync_org_with_crm($org_ref, $User_id)))
	{
		$org_ref->{valid_org} = 'unreviewed';
	}

	if (    defined $org_ref->{crm_org_id}
		and exists $org_ref->{main_contact}
		and $org_ref->{main_contact} ne $previous_org_ref->{main_contact}
		and not change_company_main_contact($previous_org_ref, $org_ref->{main_contact}))
	{
		# fail -> revert main contact, so we don't lose sync with CRM if main contact cannot be changed
		$org_ref->{main_contact} = $previous_org_ref->{main_contact};
	}

	# Store to file
	store("$BASE_DIRS{ORGS}/" . $org_ref->{org_id} . ".sto", $org_ref);

	# Store to MongoDB
	my $orgs_collection = get_orgs_collection();
	$orgs_collection->replace_one({"org_id" => $org_ref->{org_id}}, $org_ref, {upsert => 1});

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

sub create_org ($creator, $org_id_or_name) {

	my $org_id = get_string_id_for_lang("no_language", $org_id_or_name);

	$log->debug("create_org", {$org_id_or_name => $org_id_or_name, org_id => $org_id}) if $log->is_debug();

	my $org_ref = {
		created_t => time(),
		creator => $creator,
		org_id => $org_id,
		name => $org_id_or_name,
		valid_org => 'unreviewed',
		# by default an org has its data protected
		# we will remove this only if appears later not to be fair-play
		protect_data => "on",
		admins => {},
		members => {},
		main_contact => undef,
		country => $country,
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
	my $glns_ref = retrieve("$BASE_DIRS{ORGS}/orgs_glns.sto");
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
	store("$BASE_DIRS{ORGS}/orgs_glns.sto", $glns_ref);
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

	my $org_ref = org_id_or_ref($org_id_or_ref);

	$log->debug("add_user_to_org", {org_ref => $org_ref, user_id => $user_id, groups_ref => $groups_ref})
		if $log->is_debug();

	foreach my $group (@{$groups_ref}) {
		(defined $org_ref->{$group}) or $org_ref->{$group} = {};
		$org_ref->{$group}{$user_id} = 1;

		# the first admin is main contact
		if ($group eq "admins"
			and (not exists $org_ref->{main_contact} or $org_ref->{main_contact} eq ''))
		{
			$org_ref->{main_contact} = $user_id;
		}
	}

	# sync CRM
	if ($org_ref->{valid_org} eq 'accepted') {
		add_user_to_company($user_id, $org_ref->{crm_org_id});
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

	my $org_ref = org_id_or_ref($org_id_or_ref);

	$log->debug("remove_user_from_org", {org_ref => $org_ref, user_id => $user_id, groups_ref => $groups_ref})
		if $log->is_debug();

	foreach my $group (@{$groups_ref}) {
		if (defined $org_ref->{$group}) {
			if ($group eq "members") {
				remove_user_from_company($user_id, $org_ref->{crm_org_id});
			}
			delete $org_ref->{$group}{$user_id};
		}
	}

	store_org($org_ref);

	return;
}

sub is_user_in_org_group ($org_id_or_ref, $user_id, $group_id) {

	my $org_ref = org_id_or_ref($org_id_or_ref);

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

sub update_import_date($org_id_or_ref, $time) {
	my $org_ref = org_id_or_ref($org_id_or_ref);
	$org_ref->{last_import_t} = $time;
	store_org($org_ref);
	update_last_import_date($org_ref, $time);
	return;
}

sub update_export_date($org_id_or_ref, $time) {
	my $org_ref = org_id_or_ref($org_id_or_ref);
	$org_ref->{last_export_t} = $time;
	store_org($org_ref);
	update_last_export_date($org_ref, $time);
	return;
}

sub send_rejection_email ($org_ref) {
	# send org rejection email to main contact
	my $main_contact_user = $org_ref->{main_contact};
	my $user_ref = retrieve_user($main_contact_user);
	if (not defined $user_ref) {
		$log->warning("send_rejection_email", {error => "main contact user not found", org_ref => $org_ref})
			if $log->is_warning();
		return;
	}

	my $language = $user_ref->{preferred_language} || $user_ref->{initial_lc};
	# if template does not exist in the requested language, use English
	my $template_name = "org_rejected.tt.html";
	my $template_path = "emails/$language/$template_name";
	my $default_path = "emails/en/$template_name";
	my $path = -e "$data_root/templates/$template_path" ? $template_path : $default_path;

	my $template_data_ref = {
		user => $user_ref,
		org => $org_ref,
	};

	my $email = '';
	my $res = process_template($path, $template_data_ref, \$email);
	if ($email =~ s/^(\s*Subject:\s*(.*))\n//) {
		my $subject = $2;
		my $body = $email;
		$body =~ s/^\n+//;
		send_html_email($user_ref, $subject, $body);
	}
	$log->debug("send_rejection_email", {path => $path, email => $email, res => $res}) if $log->is_debug();
	return;
}

sub update_last_logged_in_member($user_ref) {

	my $org_id = $user_ref->{org_id} // $user_ref->{requested_org_id};
	return if not defined $org_id;

	my $org_ref = retrieve_org($org_id);
	return if not defined $org_ref;
	is_user_in_org_group($org_ref, $user_ref->{userid}, "members") or return;

	$org_ref->{last_logged_member} = $user_ref->{userid};
	$org_ref->{last_logged_member_t} = time();

	if (defined $org_ref->{crm_org_id}) {
		update_company_last_logged_in_contact($org_ref, $user_ref);
	}

	store_org($org_ref);
	return;
}

=head2 update_last_import_type($orgid, $data_source)

Update the last import type for an organization.

=head3 Arguments

=head4 $orgid

=cut

sub update_last_import_type ($org_id_or_ref, $data_source) {
	my $org_ref = retrieve_org($org_id_or_ref);
	$org_ref->{last_import_type} = $data_source;
	update_company_last_import_type($org_ref, $data_source);
	store_org($org_ref);
	return;
}

sub accept_pending_user_in_org ($org_ref, $user_id) {
	return if not is_user_in_org_group($org_ref, $user_id, "pending");
	remove_user_from_org($org_ref, $user_id, ["pending"]);
	add_user_to_org($org_ref, $user_id, ["members"]);

	my $user_ref = retrieve_user($user_id);
	$user_ref->{org} = $org_ref->{org_id};
	$user_ref->{org_id} = $org_ref->{org_id};
	delete $user_ref->{requested_org};
	delete $user_ref->{requested_org_id};
	store_user($user_ref);
	return;
}

=head2 org_id_or_ref($org_id_or_ref)

Systematically return the org_ref for a given org_id or org_ref.

=cut

sub org_id_or_ref ($org_id_or_ref) {
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
	return $org_ref;
}

1;
