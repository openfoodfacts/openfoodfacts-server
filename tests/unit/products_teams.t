#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;

use ProductOpener::Products qw/add_teams_to_product/;

my $product_ref = {};

# comma separated values are split by the caller, values are normalized
is(add_teams_to_product($product_ref, split(/,/, "Team A, Équipe B")), 2);
is($product_ref->{teams_tags}, ["team-a", "equipe-b"]);
is($product_ref->{teams}, "team-a,equipe-b");

# existing teams are kept, duplicates and empty or undefined values are ignored
is(add_teams_to_product($product_ref, "team a", "", undef, " ", "Team C"), 1);
is($product_ref->{teams_tags}, ["team-a", "equipe-b", "team-c"]);
is($product_ref->{teams}, "team-a,equipe-b,team-c");

# nothing to add
is(add_teams_to_product({}, undef, ""), 0);

done_testing();
