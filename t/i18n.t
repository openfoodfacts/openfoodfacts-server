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
	my %lang = %{ ProductOpener::I18N::read_po_files($path) };
	foreach my $key (keys %lang) {
		#diag explain $lang{$key}{en};
		if ((defined $lang{$key}{en}) and ($lang{$key}{en} =~ /$site_name_regex/)) {
			foreach my $lang (keys %{$lang{$key}}) {
				like($lang{$key}{$lang}, $site_name_regex, "'$key' in '$lang' should contain '<<site_name>>'");
			}
		}
	}
}

done_testing();
