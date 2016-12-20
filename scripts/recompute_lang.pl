#!/usr/bin/perl

use CGI::Carp qw(fatalsToBrowser);

use Modern::Perl '2015';
use utf8;

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Lang qw/:all/;

print STDERR "Recompute \%Lang\n";

init_languages(1);
init_select_country_options(1);

exit(0);

