#!/usr/bin/perl

use CGI::Carp qw(fatalsToBrowser);

use strict;
use utf8;

use Blogs::Config qw/:all/;
use Blogs::Store qw/:all/;
use Blogs::Index qw/:all/;
use Blogs::Display qw/:all/;
use Blogs::Images qw/:all/;
use Blogs::Users qw/:all/;
use Blogs::Mail qw/:all/;
use Blogs::Lang qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Encode;

use Crypt::PasswdMD5 qw(unix_md5_crypt);


	my $userid = $ARGV[0];
	my $user_ref = retrieve("$data_root/users/$userid.sto");
	$user_ref->{encrypted_password} = unix_md5_crypt( encode_utf8 (decode utf8=>$ARGV[1]), gensalt(8) );
	store("$data_root/users/$userid.sto", $user_ref);
