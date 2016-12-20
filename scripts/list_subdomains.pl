#!/usr/bin/perl

use CGI::Carp qw(fatalsToBrowser);

use Modern::Perl '2015';
use warnings;
use utf8;

use ProductOpener::Config qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Lang qw/:all/;

foreach my $country (sort keys %{$properties{countries}}) {
	next if not $country;
	my $cc = $properties{countries}{$country}{"country_code_2:en"};
	if ($country eq 'en:world') {
		$cc = 'world';
	}
	else {
		next if not $cc;
		$cc = lc($cc);
	}

	print "$cc.$server_domain\n";
	foreach my $l (sort values %lang_lc) {
		next if not $l;
		print "$cc-$l.$server_domain\n";
        }
}

exit(0);

