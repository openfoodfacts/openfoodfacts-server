#!/usr/bin/perl

use CGI::Carp qw(fatalsToBrowser);

use Modern::Perl '2012';
use utf8;

# ProductOpener::Lang module should be loaded first
use ProductOpener::Lang qw/:all/;
use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Tags qw/:all/;

print STDERR "Recompute \%Lang - data_root: $data_root\n";

init_languages(1);

init_select_country_options(1);

exit(0);

