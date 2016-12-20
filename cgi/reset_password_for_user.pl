#!/usr/bin/perl

use Modern::Perl '2012';
use utf8;

use CGI::Carp qw(fatalsToBrowser);

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Mail qw/:all/;
use ProductOpener::Lang qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Encode;

	my $userid = $ARGV[0];
	my $user_ref = retrieve("$data_root/users/$userid.sto");
	$user_ref->{encrypted_password} = create_password_hash( encode_utf8 (decode utf8=>$ARGV[1]) );
	store("$data_root/users/$userid.sto", $user_ref);
