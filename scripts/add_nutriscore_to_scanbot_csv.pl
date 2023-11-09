#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2023 Association Open Food Facts
# Contact: contact@openfoodfacts.org
# Address: 21 rue des Iles, 94100 Saint-Maur des Fossés, France
#
# Product Opener is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# This script expects nginx access logs on STDIN
# filtered by the app:
# grep "Official Android App" nginx.access2.log | grep Scan > android_app.log

use Modern::Perl '2017';
use utf8;

use CGI::Carp qw(fatalsToBrowser);

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Mail qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Data qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;

my %total = ();

print join("\t",
	qw(code scans unique_scans found source found_status found_scans found_unique_scans nutriscore_status nutriscore_scans nutriscore_unique_scans)
) . "\n";

while (<STDIN>) {
	$total{products}++;
	chomp;
	my ($code, $scans, $unique_scans, $found, $source) = split(/\t/);

	# Remove slashes in code (e.g. we have some in Google Analytics data)
	$code =~ s/\///g;

	my $found_scans = 0;
	my $found_unique_scans = 0;
	my $found_status = 0;

	my $producers_scans = 0;
	my $producers_unique_scans = 0;
	my $producers_status = 0;

	my $nutriscore_scans = 0;
	my $nutriscore_unique_scans = 0;
	my $nutriscore_status = 0;

	my $ecoscore_scans = 0;
	my $ecoscore_unique_scans = 0;
	my $ecoscore_status = 0;

	if ($source eq "producers") {
		$total{producers_products}++;
		$producers_status = 1;
		$producers_scans = $scans;
		$producers_unique_scans = $unique_scans;
	}

	# If we don't have a found column, look for the product on disk
	if ($found !~ /FOUND/) {
		my $product_ref = retrieve_product($code);
		if (defined $product_ref) {
			$found = "FOUND";
		}
		else {
			$found = "NOT_FOUND";
		}
	}

	if ($found eq "FOUND") {

		$total{found_products}++;
		$found_status = 1;
		$found_scans = $scans;
		$found_unique_scans = $unique_scans;

		my $product_ref = retrieve_product($code);
		if (defined $product_ref) {

			if (    (defined $product_ref->{nutriscore_grade})
				and ($product_ref->{nutriscore_grade} =~ /^[a-e]$/))
			{
				$nutriscore_scans = $scans;
				$nutriscore_unique_scans = $unique_scans;
				$nutriscore_status = 1;
				$total{nutriscore_products}++;
			}
			if (    (defined $product_ref->{ecoscore_grade})
				and ($product_ref->{ecoscore_grade} =~ /^[a-e]$/))
			{
				$ecoscore_scans = $scans;
				$ecoscore_unique_scans = $unique_scans;
				$ecoscore_status = 1;
				$total{ecoscore_products}++;
			}
		}
	}

	$total{scans} += $scans;
	$total{unique_scans} += $unique_scans;

	$total{found_scans} += $found_scans;
	$total{found_unique_scans} += $found_unique_scans;

	$total{producers_scans} += $producers_scans;
	$total{producers_unique_scans} += $producers_unique_scans;

	$total{nutriscore_scans} += $nutriscore_scans;
	$total{nutriscore_unique_scans} += $nutriscore_unique_scans;

	$total{ecoscore_scans} += $ecoscore_scans;
	$total{ecoscore_unique_scans} += $ecoscore_unique_scans;

	print join("\t",
		$code, $scans, $unique_scans, $found,
		$source, $found_status, $found_scans, $found_unique_scans,
		$nutriscore_status, $nutriscore_scans, $nutriscore_unique_scans)
		. "\n";
}

my $found_products_percent = sprintf("%.2f", 100 * $total{found_products} / $total{products});
my $found_scans_percent = sprintf("%.2f", 100 * $total{found_scans} / $total{scans});
my $found_unique_scans_percent = sprintf("%.2f", 100 * $total{found_unique_scans} / $total{unique_scans});

my $producers_products_percent = sprintf("%.2f", 100 * $total{producers_products} / $total{products});
my $producers_scans_percent = sprintf("%.2f", 100 * $total{producers_scans} / $total{scans});
my $producers_unique_scans_percent = sprintf("%.2f", 100 * $total{producers_unique_scans} / $total{unique_scans});

my $nutriscore_products_percent = sprintf("%.2f", 100 * $total{nutriscore_products} / $total{products});
my $nutriscore_scans_percent = sprintf("%.2f", 100 * $total{nutriscore_scans} / $total{scans});
my $nutriscore_unique_scans_percent = sprintf("%.2f", 100 * $total{nutriscore_unique_scans} / $total{unique_scans});

my $ecoscore_products_percent = sprintf("%.2f", 100 * $total{ecoscore_products} / $total{products});
my $ecoscore_scans_percent = sprintf("%.2f", 100 * $total{ecoscore_scans} / $total{scans});
my $ecoscore_unique_scans_percent = sprintf("%.2f", 100 * $total{ecoscore_unique_scans} / $total{unique_scans});

print STDERR <<TXT

products: $total{products}
scans: $total{scans}
unique_scans: $total{unique_scans}

found_products: $total{found_products} - $found_products_percent
found_scans: $total{found_scans} - $found_scans_percent
found_unique_scans: $total{found_unique_scans} - $found_unique_scans_percent

producers_products: $total{producers_products} - $producers_products_percent
producers_scans: $total{producers_scans} - $producers_scans_percent
producers_unique_scans: $total{producers_unique_scans} - $producers_unique_scans_percent

nutriscore_products: $total{nutriscore_products} - $nutriscore_products_percent
nutriscore_scans: $total{nutriscore_scans} - $nutriscore_scans_percent
nutriscore_unique_scans: $total{nutriscore_unique_scans} - $nutriscore_unique_scans_percent

ecoscore_products: $total{ecoscore_products} - $ecoscore_products_percent
ecoscore_scans: $total{ecoscore_scans} - $ecoscore_scans_percent
ecoscore_unique_scans: $total{ecoscore_unique_scans} - $ecoscore_unique_scans_percent

TXT
	;

