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

use CGI::Carp qw(fatalsToBrowser);

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Orgs qw/:all/;
use ProductOpener::Tags qw/:all/;

use CGI qw/:cgi :form escapeHTML charset/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use Log::Any qw($log);

my $type = param('type') || 'edit';
my $action = param('action') || 'display';

# Passing values to the template
my $template_data_ref = {
	lang => \&lang,
};

ProductOpener::Display::init();

my $orgid = $Org_id;

if (defined param('orgid')) {
	$orgid = get_fileid(param('orgid'), 1);
}

$log->debug("org profile form - start", { type => $type, action => $action, orgid => $orgid, User_id => $User_id }) if $log->is_debug();

my $html = '';

my $org_ref = retrieve_org($orgid);

# Does the org exist?

if (not defined $org_ref) {
	$log->debug("org does not exist", { orgid => $orgid }) if $log->is_debug();
	display_error($Lang{error_org_does_not_exist}{$lang}, 404);
}

# Does the user have permission to edit the org profile?

if (not (is_user_in_org_group($org_ref, "admins", $User_id) or $admin)) {
	$log->debug("user does not have permission to edit org", { orgid => $orgid, org_admins => $org_ref->{admins}, User_id => $User_id }) if $log->is_debug();
	display_error($Lang{error_no_permission}{$lang}, 403);
}

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
		else {
			
			foreach my $field ("name", "link") {
				$org_ref->{$field} = remove_tags_and_quote(decode utf8=>param($field));
				if ($org_ref->{$field} eq "") {
					delete $org_ref->{$field};
				}
			}
			
			if (not defined $org_ref->{name}) {
				push @errors, $Lang{error_missing_org_name}{$lang};
			}
			
			foreach my $contact ("customer_service", "commercial_service") {
				
				$org_ref->{$contact} = {};
				
				foreach my $field ("name", "address", "email", "phone", "link", "info") {
					
					$org_ref->{$contact}{$field} = remove_tags_and_quote(decode utf8=>param($contact . "_" . $field));
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

$log->debug("org form - before display / process", { type => $type, action => $action, orgid => $orgid }) if $log->is_debug();

if ($action eq 'display') {

	$template_data_ref->{admin} = $admin;
	
	# Create the list of sections and fields
	
	$template_data_ref->{sections} = [
		{
			fields => [
				{
					field => "name",
				},
				{
					field => "link",
				},
			]
		}
	];
	
	foreach my $contact ("customer_service", "commercial_service") {
		
		push @{$template_data_ref->{sections}}, {
			section => $contact,
			fields => [
				{ field => $contact . "_name" },
				{ field => $contact . "_address", type => "textarea" },
				{ field => $contact . "_email" },
				{ field => $contact . "_link" },
				{ field => $contact . "_phone" },				
				{ field => $contact . "_info", type => "textarea"  },
			],
		};
	}
	
	# Add labels, types, descriptions, notes and existing values for all fields
	
	foreach my $section_ref (@{$template_data_ref->{sections}}) {
		
		# Descriptions and notes for sections
		if (defined $section_ref->{section}) {
			if (lang("org_" . $section_ref->{section})) {
				$section_ref->{name} = lang("org_" . $section_ref->{section});
			}			
			if (lang("org_" . $section_ref->{section} . "_description")) {
				$section_ref->{description} = lang("org_" . $section_ref->{section} . "_description");
			}
			if (lang("org_" . $section_ref->{section} . "_note")) {
				$section_ref->{note} = lang("org_" . $section_ref->{section} . "_note");
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
			
			# Label
			$field_ref->{label} = lang($field_lang_id);
			
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
		
		$template_data_ref->{profile_url} = canonicalize_tag_link("users", "org-" . $orgid);
		$template_data_ref->{profile_name} = sprintf(lang('user_s_page'), $org_ref->{name});
	}
	elsif ($type eq 'delete') {
	}
}

$template_data_ref->{orgid} = $orgid;
$template_data_ref->{type} = $type;

my $full_width = 1;
if ($action ne 'display') {
	$full_width = 0;
}
	
my $title = lang($type . '_org_title');

$log->debug("org form - template data", { template_data_ref => $template_data_ref }) if $log->is_debug();

$tt->process('org_form.tt.html', $template_data_ref, \$html) or $html = "<p>template error: " . $tt->error() . "</p>";

display_new( {
	title=>$title,
	content_ref=>\$html,
	full_width=>$full_width,
});

