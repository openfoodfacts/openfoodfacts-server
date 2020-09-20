#!/usr/bin/perl -w

use strict;
use warnings;
use utf8;

use Test::More;
use Log::Any::Adapter 'TAP';

use ProductOpener::I18N qw/:all/;
use ProductOpener::Config qw/:all/;

# Ensure that <<site_name>> is not translated - https://github.com/openfoodfacts/openfoodfacts-server/issues/1648
my $site_name_regex = qr/<<site_name>>/;

foreach my $dir ('common', 'openbeautyfacts', 'openfoodfacts', 'openpetfoodfacts', 'openproductsfacts', 'tags') {
	
	my $path = "$data_root/po/$dir/";
	my %terms = %{ ProductOpener::I18N::read_po_files($path) };
	
	foreach my $key (keys %terms) {
		#diag explain $terms{$key}{en};
		if ((defined $terms{$key}{en}) and ($terms{$key}{en} =~ /$site_name_regex/)) {
			foreach my $lang (keys %{$terms{$key}}) {
				like($terms{$key}{$lang}, $site_name_regex, "$dir: '$key' in '$lang' should contain '<<site_name>>'");
			}
		}
	}
	
	# check that text_direction is only ltr or rtl.
	my $key = 'text_direction';
	my $regex = qr/^(ltr|rtl)$/;
	if (defined $terms{$key}) {
		foreach my $alang (keys %{$terms{$key}}) {
			like($terms{$key}{$alang}, $regex, "$dir: '$key' in '$alang' must be 'ltr' or 'rtl'");
		}
	}
	
}

done_testing();
