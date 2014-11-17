#!/usr/bin/perl

use CGI::Carp qw(fatalsToBrowser);

use strict;
use utf8;

use Blogs::Version qw/:all/;

use CGI qw/:cgi :form escapeHTML/;

print "Content-Type: text/html; charset=UTF-8\r\n\r\nVersion: $version";

exit(0);

