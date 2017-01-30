#!/usr/bin/perl

use Modern::Perl '2012';
use utf8;

use CGI::Carp qw(fatalsToBrowser);

use ProductOpener::Version qw/:all/;

use CGI qw/:cgi :form escapeHTML/;

print header( -type => 'text/html', -charset => 'utf-8' ) . "Version: $version";

exit(0);

