#!/usr/bin/perl

use CGI::Carp qw(fatalsToBrowser);

use strict;
use utf8;

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

use Crypt::PasswdMD5 qw(unix_md5_crypt);


	my $userid = $ARGV[0];
	my $user_ref = retrieve("$data_root/users/$userid.sto");
	$user_ref->{encrypted_password} = unix_md5_crypt( encode_utf8 (decode utf8=>$ARGV[1]), gensalt(8) );
	store("$data_root/users/$userid.sto", $user_ref);
