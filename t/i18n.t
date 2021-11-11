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
my $link_tag_regex = qr'<a\s[^>]+>.*</a>'is;

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

		# check for mismatched A tags
		if ((defined $terms{$key}{en}) and ($terms{$key}{en} =~ /$link_tag_regex/)) {
			foreach my $lang (keys %{$terms{$key}}) {
				like($terms{$key}{$lang}, $link_tag_regex, "$dir: '$key' in '$lang' should have matching html <a...>...</a> tags");
			}
		}

	}

	if ($dir eq 'common') {
		my @tests = (
			# check that text_direction is only ltr or rtl.
			{ key => 'text_direction', regex => qr/^(ltr|rtl)$/, test_name => "must be 'ltr' or 'rtl'" },
			
			# slack channel mustn't be translated
			{ key => 'help_improve_ingredients_analysis_instructions', regex => qr/#ingredients/, test_name => "Slack channel name must not be translated" },
			
			# check for mismatched tags
			{ key => 'help_improve_ingredients_analysis_instructions', regex => qr'(<a [^>]+>.+</a>.*){2}'is, test_name => "Should have 2 html <a...>...</a> tags" },
		);

		foreach my $test_ref (@tests) {
			my $key = $test_ref->{key};
			if (defined $terms{$key}) {
				foreach my $alang (keys %{$terms{$key}}) {
					like($terms{$key}{$alang}, $test_ref->{regex}, "$dir: '$key' in '$alang': " . $test_ref->{test_name} );
				}
			}
		}
	}
	
}

done_testing();
