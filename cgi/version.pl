#!/usr/bin/perl

use Modern::Perl '2015';
use utf8;

use CGI::Carp qw(fatalsToBrowser);

use ProductOpener::Version qw/:all/;

use CGI qw/:cgi :form escapeHTML/;

print "Content-Type: text/html; charset=UTF-8\r\n\r\nVersion: $version";

exit(0);

