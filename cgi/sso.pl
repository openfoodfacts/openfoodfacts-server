#!/usr/bin/perl

use CGI::Carp qw(fatalsToBrowser);

use strict;
use utf8;

use Blogs::Config qw/:all/;
use Blogs::Store qw/:all/;
use Blogs::Users qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON;

use Blogs::Lang qw/:all/;

my $user_id = param('user_id');
my $user_session = param('user_session');

my $response_ref = check_session($user_id, $user_session);

my $data =  encode_json($response_ref);
	
print "Content-Type: application/json; charset=UTF-8\r\n\r\n" . $data;	
	


