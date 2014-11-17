#!/usr/bin/perl

use CGI::Carp qw(fatalsToBrowser);

use strict;
use utf8;

use Blogs::Config qw/:all/;
use Blogs::Store qw/:all/;
use Blogs::Index qw/:all/;
use Blogs::Display qw/:all/;
use Blogs::Users qw/:all/;
use Blogs::Lang qw/:all/;

use CGI qw/:cgi :form escapeHTML charset/;
use URI::Escape::XS;
use Storable qw/dclone/;

Blogs::Display::init();

my $type = param('type') || 'add';
my $action = param('action') || 'display';

my $userid = get_fileid(param('userid'));

my $html = '';

my $user_ref = {};

if ($type eq 'edit') {
	$user_ref = retrieve("$data_root/users/$userid.sto");
	if (not defined $user_ref) {
		display_error($Lang{error_invalid_user}{$lang});
	}
}
else {
	$type = 'add';
}

if (($type eq 'edit') and ($User_id ne $userid) and not $admin) {
	display_error($Lang{error_no_permission}{$lang});
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
				display_error($Lang{error_no_permission}{$lang});
			}
		}
	}
	
	Blogs::Users::check_user_form($user_ref, \@errors);
	
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
	
	$html .= Blogs::Users::display_user_form($user_ref,\$scripts);
	$html .= Blogs::Users::display_user_form_optional($user_ref);
	
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

	if (($type eq 'add') or ($type eq 'edit')) {
		Blogs::Users::process_user_form($user_ref);
	}
	elsif ($type eq 'delete') {
		Blogs::Users::delete_user($user_ref);		
	}
	
	$html .= lang($type . "_user_confirm");
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

