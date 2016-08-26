#!/usr/bin/perl

use CGI::Carp qw(fatalsToBrowser);

use strict;
use utf8;

use Blogs::Config qw/:all/;
use Blogs::Store qw/:all/;
use Blogs::Index qw/:all/;
use Blogs::Display qw/:all/;
use Blogs::Tags qw/:all/;
use Blogs::Users qw/:all/;
use Blogs::Images qw/:all/;
use Blogs::Lang qw/:all/;
use Blogs::Mail qw/:all/;
use Blogs::Products qw/:all/;
use Blogs::Food qw/:all/;
use Blogs::Ingredients qw/:all/;
use Blogs::Images qw/:all/;
use Blogs::Missions qw/:all/;


use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON;


my $user_id = $ARGV[0];

my $user_ref = retrieve("$data_root/users/${user_id}.sto");

if (defined $user_ref) {		
	Blogs::Missions::compute_missions_for_user($user_ref);	
	# store("$data_root/users/${user_id}.sto", $user_ref);
}
else {
	print "user_id: $user_id not found\n";
}


Blogs::Missions::gen_missions_html()
