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

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Orgs qw/:all/;
use ProductOpener::Text qw/:all/;

use CGI qw/:cgi :form escapeHTML charset/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Log::Any qw($log);

my @user_groups = qw(producer database app bot moderator pro_moderator);

my $type = single_param('type') || 'add';
my $action = single_param('action') || 'display';

# Passing values to the template
my $template_data_ref = {};

# If the "Create user" form was submitted from the product edit page
# save the password parameter and unset it so that the ProductOpener::Display::init()
# function does not try to authenticate the user (which does not exist yet) with that password

my $new_user_password;
if (($type eq "add") and (defined single_param('prdct_mult'))) {

	$new_user_password = single_param('password');
	param("password", "");
}

my $request_ref = ProductOpener::Display::init_request();

# $userid will contain the user to be edited, possibly different than $User_id
# if an administrator edits another user

my $userid = $User_id;

if (defined single_param('userid')) {

	$userid = single_param('userid');

	# The userid looks like an e-mail
	if ($admin and ($userid =~ /\@/)) {
		my $emails_ref = retrieve("$data_root/users/users_emails.sto");
		if (defined $emails_ref->{$userid}) {
			$userid = $emails_ref->{$userid}[0];
		}
	}

	$userid = get_fileid($userid, 1);
}

$log->debug("user form - start", {type => $type, action => $action, userid => $userid, User_id => $User_id})
	if $log->is_debug();

my $html = '';
my $js = '';

my $user_ref = {};

if ($type =~ /^edit/) {
	$user_ref = retrieve("$data_root/users/$userid.sto");
	if (not defined $user_ref) {
		display_error_and_exit($Lang{error_invalid_user}{$lang}, 404);
	}
}
else {
	$type = 'add';
}

if (($type =~ /^edit/) and ($User_id ne $userid) and not $admin) {
	display_error_and_exit($Lang{error_no_permission}{$lang}, 403);
}

my $debug = 0;
my @errors = ();

if ($action eq 'process') {

	if ($type eq 'edit') {
		if (single_param('delete') eq 'on') {
			$type = 'delete';
		}
	}

	# change organization
	if ($type eq 'edit_owner') {
		# only admin and pro moderators can change organization freely
		if ($admin or $User{pro_moderator}) {
			ProductOpener::Users::check_edit_owner($user_ref, \@errors);
		}
		else {
			display_error_and_exit($Lang{error_no_permission}{$lang}, 403);
		}
	}
	elsif ($type ne 'delete') {
		ProductOpener::Users::check_user_form($type, $user_ref, \@errors);
	}

	if ($#errors >= 0) {
		if ($type eq 'edit_owner') {
			$action = 'none';
		}
		else {
			$action = 'display';
		}
	}
}

$template_data_ref->{action} = $action;
$template_data_ref->{errors} = \@errors;

# Create the list of countries and languages for the select options of country field and preferred language field
my @languages_list = get_languages();
my @countries_list = get_countries();
$template_data_ref->{languages_list} = \@languages_list;
$template_data_ref->{countries_list} = \@countries_list;

$log->debug("user form - before display / process", {type => $type, action => $action, userid => $userid})
	if $log->is_debug();

if ($action eq 'display') {

	# We can pre-fill the form to create an account using the username and password
	# passed in a form to open a session.
	# e.g. when a non-logged user clicks on the "Edit product" button

	if (($type eq "add") and (defined single_param("user_id"))) {
		my $user_info = remove_tags_and_quote(single_param('user_id'));
		$user_info =~ /^(.+?)@/;
		if (defined($1)) {
			$user_ref->{email} = $user_info;
			$user_ref->{userid} = $1;
			$user_ref->{name} = $1;
			$user_ref->{password} = $new_user_password;
		}
		else {
			$user_ref->{userid} = $user_info;
			$user_ref->{name} = $user_info;
			$user_ref->{password} = $new_user_password;
		}
	}

	$template_data_ref->{user_ref} = $user_ref;

	# Create the list of sections and fields

	$template_data_ref->{sections} = [];

	if ($user_ref) {
		push @{$template_data_ref->{sections}}, {
			id => "user",
			fields => [
				{
					field => "name"
				},
				{
					field => "email",
					type => "email",
				},
				{
					field => "userid",
					label => "username"
				},
				{
					field => "password",
					type => "password",
					label => "password"
				},
				{
					field => "confirm_password",
					type => "password",
					label => "password_confirm"
				},
				{
					field => "preferred_language",
					type => "language",
					label => "preferred_language"
				},
				{
					field => "country",
					type => "country",
					label => "select_country"
				},
				{
					# this is a honeypot to detect scripts, that fills every fields
					# this one is hidden in a div and user won't see it
					field => "faxnumber",
					type => "honeypot",
					label => "Do not enter your fax number",
				},
			]
		};

		# Professional account
		push @{$template_data_ref->{sections}},
			{
			id => "professional",
			name => lang("pro_account"),
			description => "if_you_work_for_a_producer",
			note => "producers_platform_description_long",
			fields => [
				{
					field => "pro",
					type => "checkbox",
					label => lang("this_is_a_pro_account"),
					value => "off",
				},
				{
					field => "pro_checkbox",
					type => "hidden",
					value => 1,
				},
				{
					field => "requested_org",
					label => lang("producer_or_brand") . ":",
				}
			]
			};

		# Teams section
		# Do not display teams if it is a professional account
		# Do not display teams on pro platform
		if (
			not(   (defined $server_options{producers_platform})
				or (defined $user_ref->{org})
				or (defined $user_ref->{requested_org}))
			)
		{
			my $team_section_ref = {
				id => "teams",
				name => lang("teams") . " (" . lang("optional") . ")",
				description => "teams_description",
				note => "teams_names_warning",
				fields => []
			};
			for (my $i = 1; $i <= 3; $i++) {
				push @{$team_section_ref->{fields}},
					{
					field => "team_" . $i,
					label => sprintf(lang("team_s"), $i),
					};
			}

			push @{$template_data_ref->{sections}}, {%$team_section_ref};
		}

		# Contributor section
		my $contributor_section_ref = {
			id => "contributor_settings",
			name => lang("contributor_settings") . " (" . lang("optional") . ")",
			description => "contributor_settings_description",
			fields => [
				{
					field => "display_barcode",
					type => "checkbox",
					label => display_icon("barcode") . lang("display_barcode_in_search"),
					value => $user_ref->{display_barcode} && "on",
				},
				{
					field => "edit_link",
					type => "checkbox",
					label => display_icon("edit") . lang("edit_link_in_search"),
					value => $user_ref->{edit_link} && "on",
				},
			]
		};

		push @{$template_data_ref->{sections}}, {%$contributor_section_ref};

		# Admin section
		if ($admin) {
			my $administrator_section_ref = {
				id => "administrator",
				name => "Administrator fields",
				fields => []
			};
			push @{$administrator_section_ref->{fields}},
				{
				field => "org",
				label => lang("organization"),
				};
			push @{$administrator_section_ref->{fields}},
				{
				field => "crm_user_id",
				label => lang("crm_user_id"),
				};
			foreach my $group (@user_groups) {
				push @{$administrator_section_ref->{fields}},
					{
					field => "user_group_" . $group,
					label => lang("user_group_" . $group) . " " . lang("user_group_" . ${group} . "_description"),
					type => "checkbox",
					value => $user_ref->{$group},
					};
			}
			push @{$template_data_ref->{sections}}, {%$administrator_section_ref};
		}
	}

	if ((defined $user_ref->{org}) and ($user_ref->{org} ne "")) {

		$template_data_ref->{accepted_organization} = $user_ref->{org};
	}
	elsif ( (defined $options{product_type})
		and ($options{product_type} eq "food")
		and (defined $user_ref->{requested_org})
		and ($user_ref->{requested_org} ne ""))
	{
		my $requested_org_ref = retrieve_org($user_ref->{requested_org});
		$template_data_ref->{requested_org_ref} = $requested_org_ref;
		$template_data_ref->{org_name} = sprintf(lang("add_user_existing_org"), org_name($requested_org_ref));
		$template_data_ref->{teams_flag}
			= not((defined $server_options{private_products}) and ($server_options{private_products}));
	}

	# Add labels, types, descriptions, notes and existing values for all fields
	foreach my $section_ref (@{$template_data_ref->{sections}}) {

		# Descriptions and notes for sections
		if (defined $section_ref->{id}) {
			if ($section_ref->{description}) {
				$section_ref->{description} = lang($section_ref->{description});
			}
			if ($section_ref->{note}) {
				$section_ref->{note} = lang($section_ref->{note});
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

			if (not defined $field_ref->{value}) {
				$field_ref->{value} = $user_ref->{$field};
			}

			# Label
			if (not defined $field_ref->{label}) {
				$field_ref->{label} = lang($field_lang_id);
			}

			if (   ((defined $user_ref->{pro}) and ($user_ref->{pro}))
				or (($server_options{producers_platform}) and ($type eq "add")))
			{
				if (($section_ref->{id} eq "professional") and $field_ref->{type} eq "checkbox") {
					$field_ref->{value} = "on";
				}
			}
		}
	}

}

elsif ($action eq 'process') {

	if (($type eq 'add') or ($type =~ /^edit/)) {
		ProductOpener::Users::process_user_form($type, $user_ref, $request_ref);
	}
	elsif ($type eq 'delete') {
		ProductOpener::Users::delete_user($user_ref);
	}

	if ($type eq 'add') {

		$template_data_ref->{user_requested_org} = $user_ref->{requested_org};

		my $requested_org_ref = retrieve_org($user_ref->{requested_org});
		$template_data_ref->{add_user_existing_org}
			= sprintf(lang("add_user_existing_org"), org_name($requested_org_ref));

		$template_data_ref->{user_org} = $user_ref->{org};

		my $pro_url = "https://" . $subdomain . ".pro." . $server_domain . "/";
		$template_data_ref->{add_user_pro_url} = sprintf(lang("add_user_you_can_edit_pro_promo"), $pro_url);

		$template_data_ref->{add_user_you_can_edit} = sprintf(lang("add_user_you_can_edit"), lang("get_the_app_link"));
		$template_data_ref->{add_user_join_the_project} = sprintf(lang("add_user_join_the_project"), lang("site_name"));
	}

}

$template_data_ref->{debug} = $debug;
$template_data_ref->{userid} = $userid;
$template_data_ref->{type} = $type;

if (($type eq "edit_owner") and ($action eq "process")) {
	$log->info("redirecting to / after changing owner", {}) if $log->is_info();

	my $r = shift;
	$r->headers_out->set(Location => "/");
	$r->status(302);
	return 302;
}
else {
	$log->debug("user form - template data", {template_data_ref => $template_data_ref}) if $log->is_debug();

	process_template('web/pages/user_form/user_form_page.tt.html', $template_data_ref, \$html)
		or $html = "<p>" . $tt->error() . "</p>";
	process_template('web/pages/user_form/user_form.tt.js', $template_data_ref, \$js);

	$initjs .= $js;

	$request_ref->{title} = lang($type . '_user_' . $action);
	$request_ref->{content_ref} = \$html;
	display_page($request_ref);
}
