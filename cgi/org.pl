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

use CGI::Carp qw(fatalsToBrowser);

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Orgs qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Text qw/:all/;

use CGI qw/:cgi :form escapeHTML charset/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use Log::Any qw($log);

my $type = single_param('type') || 'edit';
my $action = single_param('action') || 'display';

# Passing values to the template
my $template_data_ref = {lang => \&lang,};

my $request_ref = ProductOpener::Display::init_request();

my $orgid = $Org_id;

if (defined single_param('orgid')) {
	$orgid = get_fileid(single_param('orgid'), 1);
}

$log->debug("org profile form - start", {type => $type, action => $action, orgid => $orgid, User_id => $User_id})
	if $log->is_debug();

my $html = '';

my $org_ref = retrieve_org($orgid);

# Does the org exist?

if (not defined $org_ref) {
	$log->debug("org does not exist", {orgid => $orgid}) if $log->is_debug();

	if ($admin or $User{pro_moderator}) {
		$template_data_ref->{org_does_not_exist} = 1;
	}
	else {
		display_error_and_exit($Lang{error_org_does_not_exist}{$lang}, 404);
	}
}

# Does the user have permission to edit the org profile?

if (not(is_user_in_org_group($org_ref, $User_id, "admins") or $admin or $User{pro_moderator})) {
	$log->debug("user does not have permission to edit org",
		{orgid => $orgid, org_admins => $org_ref->{admins}, User_id => $User_id})
		if $log->is_debug();
	display_error_and_exit($Lang{error_no_permission}{$lang}, 403);
}

my @errors = ();

if ($action eq 'process') {

	if ($type eq 'edit') {
		if (single_param('delete') eq 'on') {
			if ($admin) {
				$type = 'delete';
			}
			else {
				display_error_and_exit($Lang{error_no_permission}{$lang}, 403);
			}
		}
		else {

			# Administrator fields

			if ($admin or $User{pro_moderator}) {

				# If the org does not exist yet, create it
				if (not defined $org_ref) {
					$org_ref = create_org($User_id, $orgid);
				}

				my @admin_fields = ();

				push(
					@admin_fields,
					(
						"valid_org",
						"enable_manual_export_to_public_platform",
						"activate_automated_daily_export_to_public_platform",
						"protect_data",
						"do_not_import_codeonline",
						"gs1_product_name_is_abbreviated",
						"gs1_nutrients_are_unprepared",
					)
				);

				if (defined $options{import_sources}) {
					foreach my $source_id (sort keys %{$options{import_sources}}) {
						push(@admin_fields, "import_source_" . $source_id);
					}
				}

				foreach my $field (@admin_fields) {
					$org_ref->{$field} = remove_tags_and_quote(decode utf8 => single_param($field));
				}

				# Set the list of org GLNs
				set_org_gs1_gln($org_ref, remove_tags_and_quote(decode utf8 => single_param("list_of_gs1_gln")));
			}

			# Other fields

			foreach my $field ("name", "link") {
				$org_ref->{$field} = remove_tags_and_quote(decode utf8 => single_param($field));
				if ($org_ref->{$field} eq "") {
					delete $org_ref->{$field};
				}
			}

			if (not defined $org_ref->{name}) {
				push @errors, $Lang{error_missing_org_name}{$lang};
			}

			# Contact sections

			foreach my $contact ("customer_service", "commercial_service") {

				$org_ref->{$contact} = {};

				foreach my $field ("name", "address", "email", "phone", "link", "info") {

					$org_ref->{$contact}{$field}
						= remove_tags_and_quote(decode utf8 => single_param($contact . "_" . $field));
					if ($org_ref->{$contact}{$field} eq "") {
						delete $org_ref->{$contact}{$field};
					}
				}

				if (scalar keys %{$org_ref->{$contact}} == 0) {
					delete $org_ref->{$contact};
				}
			}
		}
	}

	if ($#errors >= 0) {

		$action = 'display';
	}
}

$template_data_ref->{action} = $action;
$template_data_ref->{errors} = \@errors;

$log->debug("org form - before display / process", {type => $type, action => $action, orgid => $orgid})
	if $log->is_debug();

if ($action eq 'display') {

	$template_data_ref->{admin} = $admin;

	# Create the list of sections and fields

	$template_data_ref->{sections} = [];

	# Admin

	if ($admin or $User{pro_moderator}) {

		my $admin_fields_ref = [];

		push(
			@$admin_fields_ref,
			(
				{
					field => "valid_org",
					type => "checkbox",
				},
				{
					field => "enable_manual_export_to_public_platform",
					type => "checkbox",
				},
				{
					field => "activate_automated_daily_export_to_public_platform",
					type => "checkbox",
				},
				{
					field => "protect_data",
					type => "checkbox",
				},
				{
					field => "crm_org_id",
					label => lang("crm_org_id"),
				}
			)
		);

		if (defined $options{import_sources}) {
			foreach my $source_id (sort keys %{$options{import_sources}}) {
				push(
					@$admin_fields_ref,
					{
						field => "import_source_" . $source_id,
						type => "checkbox",
						label => sprintf(lang("import_source_string"), $options{import_sources}{$source_id}),
					},
				);
			}
		}

		push(
			@$admin_fields_ref,
			(
				{
					field => "list_of_gs1_gln",
				},
				{
					field => "gs1_product_name_is_abbreviated",
					type => "checkbox",
				},
				{
					field => "gs1_nutrients_are_unprepared",
					type => "checkbox",
				},
			)
		);

		push @{$template_data_ref->{sections}},
			{
			id => "admin",
			fields => $admin_fields_ref,
			};
	}

	# Name and information of the organization

	push @{$template_data_ref->{sections}},
		{
		fields => [
			{
				field => "name",
			},
			{
				field => "link",
			},
		]
		};

	# Contact information

	foreach my $contact ("customer_service", "commercial_service") {

		push @{$template_data_ref->{sections}},
			{
			id => $contact,
			fields => [
				{field => $contact . "_name"},
				{field => $contact . "_address", type => "textarea"},
				{field => $contact . "_email"},
				{field => $contact . "_link"},
				{field => $contact . "_phone"},
				{field => $contact . "_info", type => "textarea"},
			],
			};
	}

	# Add labels, types, descriptions, notes and existing values for all fields

	foreach my $section_ref (@{$template_data_ref->{sections}}) {

		# Descriptions and notes for sections
		if (defined $section_ref->{id}) {
			if (lang("org_" . $section_ref->{id})) {
				$section_ref->{name} = lang("org_" . $section_ref->{id});
			}
			if (lang("org_" . $section_ref->{id} . "_description")) {
				$section_ref->{description} = lang("org_" . $section_ref->{id} . "_description");
			}
			if (lang("org_" . $section_ref->{id} . "_note")) {
				$section_ref->{note} = lang("org_" . $section_ref->{id} . "_note");
			}
		}

		foreach my $field_ref (@{$section_ref->{fields}}) {

			my $field = $field_ref->{field};

			# Default to text field
			if (not defined $field_ref->{type}) {
				$field_ref->{type} = "text";
			}

			# id to use for lang() strings
			my $field_lang_id = $field;

			# Existing value

			if ($field =~ /^(customer_service|commercial_service)_(.*)$/) {

				# Field names for phone etc.
				$field_lang_id = "contact_" . $2;

				if ((defined $org_ref->{$1}) and (defined $org_ref->{$1}{$2})) {
					$field_ref->{value} = $org_ref->{$1}{$2};
				}
			}
			else {
				$field_ref->{value} = $org_ref->{$field};

				$field_lang_id = "org_" . $field;
			}

			# Label if it has not been set already
			if (not defined $field_ref->{label}) {
				$field_ref->{label} = lang($field_lang_id);
			}

			# Descriptions and notes for fields
			if (lang($field_lang_id . "_description")) {
				$field_ref->{description} = lang($field_lang_id . "_description");
			}
			if (lang($field_lang_id . "_note")) {
				$field_ref->{note} = lang($field_lang_id . "_note");
			}
		}
	}
}
elsif ($action eq 'process') {

	if ($type eq "edit") {

		store_org($org_ref);
		$template_data_ref->{result} = lang("edit_org_result");
	}
	elsif ($type eq 'user_delete') {

		if (is_user_in_org_group($org_ref, $User_id, "admins") or $admin or $User{pro_moderator}) {
			remove_user_by_org_admin(single_param('org_id'), single_param('user_id'));
			$template_data_ref->{result} = lang("edit_org_result");
		}
		else {
			display_error_and_exit($Lang{error_no_permission}{$lang}, 403);
		}

	}
	elsif ($type eq 'add_users') {
		if (is_user_in_org_group($org_ref, $User_id, "admins") or $admin or $User{pro_moderator}) {
			my $email_list = remove_tags_and_quote(single_param('email_list'));
			my $email_ref = add_users_to_org_by_admin($orgid, $email_list);

			# Set the template data for display
			$template_data_ref->{email_ref} = {
				added => \@{$email_ref->{added}},
				invited => \@{$email_ref->{invited}},
			};
		}
	}

	$template_data_ref->{profile_url} = canonicalize_tag_link("editors", "org-" . $orgid);
	$template_data_ref->{profile_name} = sprintf(lang('user_s_page'), $org_ref->{name});
}

$template_data_ref->{orgid} = $orgid;
$template_data_ref->{type} = $type;

my $title = lang($type . '_org_title');

$log->debug("org form - template data", {template_data_ref => $template_data_ref}) if $log->is_debug();

# allow org admins to view the list of users associated with their org
my @org_members;
foreach my $member_id (sort keys %{$org_ref->{members}}) {
	my $member_user_ref = retrieve_user($member_id);
	push @org_members, $member_user_ref;
}
$template_data_ref->{org_members} = \@org_members;

$tt->process('web/pages/org_form/org_form.tt.html', $template_data_ref, \$html)
	or $html = "<p>template error: " . $tt->error() . "</p>";

$request_ref->{title} = $title;
$request_ref->{content_ref} = \$html;
display_page($request_ref);
