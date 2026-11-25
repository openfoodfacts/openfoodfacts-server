#!/usr/bin/perl -w

use ProductOpener::PerlStandards;
use Test2::V0;

# Each flavor must be loaded in a fresh process because they share the Config package.
my $check = <<'PERL';
use ProductOpener::PerlStandards;
use ProductOpener::Config2;
BEGIN {
    $ProductOpener::Config2::ecobalyse_api_token = $ARGV[0] eq 'set' ? 'test-ecobalyse-token' : undef;
}
use ProductOpener::Config qw/:all/;
use ProductOpener::EnvironmentalImpact;
if ($ARGV[0] eq 'set') {
    exit(defined $ecobalyse_api_token && $ecobalyse_api_token eq 'test-ecobalyse-token' ? 0 : 1);
}
exit(defined $ecobalyse_api_token ? 1 : 0);
PERL

foreach my $flavor (qw/off obf opf opff/) {
	local $ENV{PRODUCT_OPENER_FLAVOR_SHORT} = $flavor;
	foreach my $mode (qw/set unset/) {
		is(system($^X, '-e', $check, $mode), 0, "$flavor loads EnvironmentalImpact with the configured token $mode");
	}
}

done_testing();
