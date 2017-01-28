#!/usr/bin/perl

use Modern::Perl '2012';
use utf8;

use CGI::Carp qw(fatalsToBrowser);

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Users qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;

use ProductOpener::Lang qw/:all/;

my $user_id = param('user_id');
my $user_session = param('user_session');

my $response_ref = check_session($user_id, $user_session);

my $data =  encode_json($response_ref);
	
print header( -type => 'application/json', -charset => 'utf-8' ) . $data;
