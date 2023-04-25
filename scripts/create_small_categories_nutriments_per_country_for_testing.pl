#!/usr/bin/perl

use Modern::Perl '2017';
use utf8;

use CGI::Carp qw(fatalsToBrowser);

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;

# The real categories_nutriments_per_country.world.sto is too big to store for github,
# create a smaller version that can be used in unit tests

my $categories_nutriments_per_country_ref
	= retrieve("$data_root/data/categories_stats/categories_nutriments_per_country.world.sto");

my $test_ref = {"en:cakes" => $categories_nutriments_per_country_ref->{"en:cakes"}};

store("$data_root/data/categories_stats/categories_nutriments_per_country.world.for_unit_tests.sto", $test_ref);

exit(0);

