#!/usr/bin/perl -w

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
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

use Modern::Perl '2017';
use utf8;

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Orgs qw/:all/;

use CGI qw/:cgi :form escapeHTML charset/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Log::Any qw($log);

my @user_groups = qw(producer database app bot moderator pro_moderator);

my $type = param('type') || 'add';
my $action = param('action') || 'display';

# Passing values to the template
my $template_data_ref = {};

# If the "Create user" form was submitted from the product edit page
# save the password parameter and unset it so that the ProductOpener::Display::init()
# function does not try to authenticate the user (which does not exist yet) with that password

my $new_user_password;
if (($type eq "add") and (defined param('prdct_mult'))) {

	$new_user_password = param('password');
	param("password", "");
}

ProductOpener::Display::init();


# $userid will contain the user to be edited, possibly different than $User_id
# if an administrator edits another user

my $userid = $User_id;

if (defined param('userid')) {

	$userid = param('userid');

	# The userid looks like an e-mail
	if ($admin and ($userid =~ /\@/)) {
		my $emails_ref = retrieve("$data_root/users_emails.sto");
		if (defined $emails_ref->{$userid}) {
			$userid = $emails_ref->{$userid}[0];
		}
	}

	$userid = get_fileid($userid, 1);
}

$log->debug("user form - start", { type => $type, action => $action, userid => $userid, User_id => $User_id }) if $log->is_debug();

my $html = '';
my $js = '';

my $user_ref = {};

if ($type =~ /^edit/) {
	$user_ref = retrieve("$data_root/users/$userid.sto");
	if (not defined $user_ref) {
		display_error($Lang{error_invalid_user}{$lang}, 404);
	}
}
else {
	$type = 'add';
}

if (($type =~ /^edit/) and ($User_id ne $userid) and not $admin) {
	display_error($Lang{error_no_permission}{$lang}, 403);
}

my $debug = 0;
my @errors = ();

if ($action eq 'process') {

	if ($type eq 'edit') {
		if (param('delete') eq 'on') {
			if ($admin) {
				$type = 'delete';
			}
			else {
				display_error($Lang{error_no_permission}{$lang}, 403);
			}
		}
	}

	if ($type eq 'edit_owner') {
		ProductOpener::Users::check_edit_owner($user_ref, \@errors);
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

$log->debug("user form - before display / process", { type => $type, action => $action, userid => $userid }) if $log->is_debug();

if ($action eq 'display') {

    # We can pre-fill the form to create an account using the username and password
	# passed in a form to open a session.
	# e.g. when a non-logged user clicks on the "Edit product" button

	if (($type eq "add") and (defined param("user_id"))) {
		my $user_info = remove_tags_and_quote(param('user_id'));
		$user_info =~ /^(.+?)@/;
		if ( defined ($1) ){
			$user_ref->{email} = $user_info;
			$user_ref->{userid} = $1;
			$user_ref->{name} = $1;
			$user_ref->{password} = $new_user_password;
		}
		else{
			$user_ref->{userid} = $user_info;
			$user_ref->{name} = $user_info;
			$user_ref->{password} = $new_user_password;
		}
	}

	$template_data_ref->{user_ref} = $user_ref;
	$template_data_ref->{user_id_field} = $user_ref->{userid};
	$template_data_ref->{user_password_field} = $user_ref->{password};

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
			]
		};

		# Professional account
		push @{$template_data_ref->{sections}}, {
			id => "professional",
			name => lang("pro_account"),
			description => "if_you_work_for_a_producer",
			note => "producers_platform_description_long",
			fields => [
				{
					field => "pro",
					type => "checkbox",
					label => lang("this_is_a_pro_account"),
					warning => sprintf(lang("this_is_a_pro_account_for_org"),"<b>" . $user_ref->{org} . "</b>"),
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
		my $team_section_ref = {
			id => "teams",
			name => lang("teams") . " (" . lang("optional") . ")",
			description => "teams_description",
			note => "teams_names_warning",
			fields => []
		};
		for (my $i = 1; $i <= 3; $i++) {
			push @{$team_section_ref->{fields}}, {
				field => "team_". $i,
				label => sprintf(lang("team_s"), $i),
			 };
		};

		push @{$template_data_ref->{sections}}, {%$team_section_ref};

		# Admin section
		my $administrator_section_ref = {
			id => "administrator",
			name => "Administrator fields",
			fields => []
		};
		push  @{$administrator_section_ref->{fields}}, {
			field => "org",
			label => lang("organization"),
		};
		foreach my $group (@user_groups) {
			push @{$administrator_section_ref->{fields}}, {
				field =>  "user_group_". $group,
				label =>  lang("user_group_". $group) . " " . lang("user_group_" . ${group} . "_description"),
				type => "checkbox",
				value => $user_ref->{$group},
			};
		};

		push @{$template_data_ref->{sections}}, {%$administrator_section_ref};
	}

	if ( ( defined $user_ref->{org} ) and ( $user_ref->{org} ne "" ) ) {

		$template_data_ref->{accepted_organization} = $user_ref->{org};
		$template_data_ref->{pro_account_org} = sprintf(lang("this_is_a_pro_account_for_org"),"<b>" . $user_ref->{org} . "</b>");
	}
	elsif ((defined $options{product_type}) and ($options{product_type} eq "food")) {
		my $requested_org_ref = retrieve_org($user_ref->{requested_org});
		$template_data_ref->{requested_org_ref} = $requested_org_ref;
		$template_data_ref-> {org_name} = sprintf(lang("add_user_existing_org"), org_name($requested_org_ref));
		$template_data_ref->{teams_flag} = not ((defined $server_options{private_products}) and ($server_options{private_products}));
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
			};

			# id to use for lang() strings
			my $field_lang_id = $field;

			if (not defined $field_ref->{value}) {
				$field_ref->{value} = $user_ref->{$field};
			};

			# Label
			if (not defined $field_ref->{label}) {
				$field_ref->{label} = lang($field_lang_id);
			};

			if (((defined $user_ref->{pro}) and ($user_ref->{pro}))
			or ((defined $server_options{producers_platform}) and ($type eq "add"))) {
				if (($section_ref->{id} eq "professional") and $field_ref->{type} eq "checkbox") {
					$field_ref->{value} = "on";
				}
			};
		};
	};

}

elsif ($action eq 'process') {

	if (($type eq 'add') or ($type =~ /^edit/)) {
		ProductOpener::Users::process_user_form($type, $user_ref);
	}
	elsif ($type eq 'delete') {
		ProductOpener::Users::delete_user($user_ref);
	}

	if ($type eq 'add') {

		$template_data_ref->{user_requested_org} = $user_ref->{requested_org};

		my $requested_org_ref = retrieve_org($user_ref->{requested_org});
		$template_data_ref->{add_user_existing_org} = sprintf(lang("add_user_existing_org"), org_name($requested_org_ref));

		$template_data_ref->{user_org} = $user_ref->{org};

		$template_data_ref->{server_options_producers_platform} = $server_options{producers_platform};

		my $pro_url = "https://" . $subdomain . ".pro." . $server_domain . "/";
		$template_data_ref->{add_user_pro_url} = sprintf(lang("add_user_you_can_edit_pro_promo"), $pro_url);

		$template_data_ref->{add_user_you_can_edit} = sprintf(lang("add_user_you_can_edit"), lang("get_the_app_link"));
		$template_data_ref->{add_user_join_the_project} = sprintf(lang("add_user_join_the_project"), lang("site_name"));
	}

}

$template_data_ref->{debug} = $debug;
$template_data_ref->{userid} = $userid;
$template_data_ref->{type} = $type;

my $full_width = 1;
if ($action ne 'display') {
	$full_width = 0;
}

if (($type eq "edit_owner") and ($action eq "process")) {
	$log->info("redirecting to / after changing owner", { }) if $log->is_info();

	my $r = shift;
	$r->headers_out->set(Location =>"/");
	$r->status(302);
	return 302;
}
else {

	my $title = lang($type . '_user_' . $action);

	$log->debug("user form - template data", { template_data_ref => $template_data_ref }) if $log->is_debug();

	process_template('user_form2.tt.html', $template_data_ref, \$html) or $html = "<p>" . $tt->error() . "</p>";
	process_template('user_form2.tt.js', $template_data_ref, \$js);

	$initjs .= $js;
	$scripts .= <<HTML
<script type="text/javascript" src="/js/dist/jquery.iframe-transport.js"></script>
<script type="text/javascript" src="/js/dist/jquery.fileupload.js"></script>
HTML
;

	display_new( {
		title=>$title,
		content_ref=>\$html,
		full_width=>$full_width,
	});
}