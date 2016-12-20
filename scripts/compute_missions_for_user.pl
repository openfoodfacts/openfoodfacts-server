#!/usr/bin/perl

use CGI::Carp qw(fatalsToBrowser);

use Modern::Perl '2015';
use utf8;

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Mail qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Missions qw/:all/;


use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON;


my $user_id = $ARGV[0];

my $user_ref = retrieve("$data_root/users/${user_id}.sto");

if (defined $user_ref) {		
	ProductOpener::Missions::compute_missions_for_user($user_ref);	
	# store("$data_root/users/${user_id}.sto", $user_ref);
}
else {
	print "user_id: $user_id not found\n";
}


ProductOpener::Missions::gen_missions_html()
