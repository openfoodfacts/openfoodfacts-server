#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2020 Association Open Food Facts
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

use Modern::Perl '2017';
use utf8;

binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");

use ProductOpener::Import qw/:all/;
use ProductOpener::Producers qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;
use Time::Local;
use XML::Rules;

use Log::Any::Adapter ('Stderr');

print STDERR "Loading " . $ARGV[0] . ":\n";

my $results_ref = load_csv_or_excel_file($ARGV[0]);

my $headers_ref = $results_ref->{headers};
my $rows_ref = $results_ref->{rows};

my %headers = ();
my $i =0;
foreach my $header (@{$headers_ref}) {

	$headers{$header} = $i;
	$i++;
	print STDERR "col $i : $header\n";
}

my %products = ();

my @keys = ("code", "serving_size");
my %keys = ("code" => 1, "serving_size" => 1);

foreach my $row_ref (@{$rows_ref}) {
	my $code = $row_ref->[$headers{EAN}];
	my $per_value = $row_ref->[$headers{"Quantité"}];
	my $per_unit = $row_ref->[$headers{"Quantité Valeur"}];
	my $prepared = $row_ref->[$headers{"Etat de préparation"}];
	my $nutrient = $row_ref->[$headers{"Element Nutritif"}];
	my $value = $row_ref->[$headers{"Quantité - 2"}];
	my $unit = $row_ref->[$headers{"Unité Quantité"}];

	defined $products{$code} or $products{$code} = {code => $code};

	if ($prepared =~ /préparation/i) {
		$prepared = "préparé";
	}
	else {
		$prepared = "";
	}

	my $per = "100g";

	if ((defined $per_value) and ($per_value != 100)) {
		$per = "par portion";
		if ($prepared or (not defined $products{$code}{serving_size})) {
			$products{$code}{serving_size} = $per_value . " " . $per_unit;
		}
	}

	if ($nutrient =~ /kcal|kj/) {
		$unit = "";
	}

	my $key = $nutrient . " - " . $prepared . " - " . $per . " - " . $unit;
	if (not defined $keys{$key}) {
		push @keys, $key;
		$keys{$key} = 1;
	}

	$products{$code}{$key} = $value;
}

my $csv_out = Text::CSV->new ( { binary => 1 , sep_char => "\t" } )  # should set binary attribute.
                 or die "Cannot use CSV: ".Text::CSV->error_diag ();


open (my $out, ">:encoding(UTF-8)", $ARGV[0] . ".merged.csv") or die("Cannot write " . $ARGV[0] . ".merged.csv : $!\n");
$csv_out->print ($out, \@keys);
print $out "\n";

foreach my $code (sort keys %products) {

	# delete per_serving values if we have per_100g values

	my @values = ();
	foreach my $key (@keys) {
		my $value = $products{$code}{$key};
		if ($key =~ /par portion/) {
			my $key2 = $key;
			$key2 =~ s/par portion/100g/;
			if ((defined $products{$code}{$key2}) and ($products{$code}{$key2} ne "")) {
				$value = undef;
			}
		}
		push @values, $value;
	}

	$csv_out->print ($out, [@values]);
	print $out "\n";
}

