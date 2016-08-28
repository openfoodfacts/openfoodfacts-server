#!/usr/bin/perl

# This file is part of Product Opener.
# 
# Product Opener
# Copyright (C) 2011-2015 Association Open Food Facts
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

use CGI::Carp qw(fatalsToBrowser);

use strict;
use utf8;

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Lang qw/:all/;

use CGI qw/:cgi :form escapeHTML charset/;
use URI::Escape::XS;
use Storable qw/dclone/;

ProductOpener::Display::init();

my $type = param('type') || 'add';
my $action = param('action') || 'display';

my $userid = get_fileid(param('userid'));

my $html = '';

my $user_ref = {};

if ($type eq 'edit') {
	$user_ref = retrieve("$data_root/users/$userid.sto");
	if (not defined $user_ref) {
		display_error($Lang{error_invalid_user}{$lang}, 404);
	}
}
else {
	$type = 'add';
}

if (($type eq 'edit') and ($User_id ne $userid) and not $admin) {
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
	
	ProductOpener::Users::check_user_form($user_ref, \@errors);
	
	if ($#errors >= 0) {
		$action = 'display';
	}	
}


if ($action eq 'display') {
	
	$scripts .= <<SCRIPT
SCRIPT
;

	if ($#errors >= 0) {
		$html .= "<p><b>$Lang{correct_the_following_errors}{$lang}</b></p>";
		foreach my $error (@errors) {
			$html .= "<p class=\"error\">$error</p>\n";
		}
	}
	
	$html .= start_form()
	. "<table>";
	
	$html .= ProductOpener::Users::display_user_form($user_ref,\$scripts);
	$html .= ProductOpener::Users::display_user_form_optional($user_ref);
	
	if ($admin) {
		$html .= "\n<tr><td colspan=\"2\">" . checkbox(-name=>'delete', -label=>'Effacer l\'utilisateur') . "</td></tr>";
	}	
	
	$html .= "\n<tr><td>"
	. hidden(-name=>'action', -value=>'process', -override=>1)
	. hidden(-name=>'type', -value=>$type, -override=>1)
	. hidden(-name=>'userid', -value=>$userid, -override=>1)
	. submit()
	. "</td></tr>\n</table>"
	. end_form();

}
elsif ($action eq 'process') {

    my $dialog = '_user_confirm';
	if (($type eq 'add') or ($type eq 'edit')) {
		if ( ProductOpener::Users::process_user_form($user_ref) ) {
            $dialog = '_user_confirm_no_mail';
        }
	}
	elsif ($type eq 'delete') {
		ProductOpener::Users::delete_user($user_ref);		
	}
	
	$html .= lang($type . $dialog);
}

if ($debug) {
	$html .= "<p>type: $type action: $action userid: $userid</p>";
}

my $full_width = 1;
if ($action ne 'display') {
	$full_width = 0;
}

display_new( {
	title=>lang($type . '_user'),
	content_ref=>\$html,
	full_width=>$full_width,
});

