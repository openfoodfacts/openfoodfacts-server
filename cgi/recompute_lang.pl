#!/usr/bin/perl

use CGI::Carp qw(fatalsToBrowser);

use strict;
use utf8;

use Blogs::Config qw/:all/;
use Blogs::Store qw/:all/;
use Blogs::Tags qw/:all/;
use Blogs::Lang qw/:all/;

print STDERR "Recompute \%Lang\n";

init_languages(1);
init_select_country_options(1);

exit(0);

