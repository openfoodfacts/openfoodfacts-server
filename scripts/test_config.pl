#!/usr/bin/perl -w

use CGI::Carp qw(fatalsToBrowser);

use Modern::Perl '2017';
use utf8;

use ProductOpener::Config qw/:all/;

print "server_domain: $server_domain\n";
print "options: " . $options{product_type} . "\n";

exit(0);

