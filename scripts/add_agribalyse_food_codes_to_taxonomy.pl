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

use Carp ();
use Text::CSV;

binmode STDIN, ':encoding(UTF-8)';
binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';

sub _map_codes {
	my ($csv, $io) = @_;

	$csv->column_names($csv->getline($io));
	my %agb_ciqual_names_fr = ();

	while (my $agb_ref = $csv->getline_hr($io)) {
		$agb_ciqual_names_fr{$agb_ref->{ciqual_code}} = $agb_ref->{ciqual_name_fr};
		print {*STDERR} 'ciqual_code : ' . $agb_ref->{ciqual_code} . ' - ciqual_name_fr: ' . $agb_ref->{ciqual_name_fr} . "\n" or Carp::croak('Unable to write to *STDERR');
	}

	return %agb_ciqual_names_fr;
}

my $csv = Text::CSV->new ( { binary => 1 , sep_char => "\t" } );  # should set binary attribute.

open my $io, '<:encoding(UTF-8)', 'agribalyse_food_codes.csv' or Carp::croak('Could not open agribalyse_food_codes.csv');
my %agb_ciqual_names_fr = _map_codes($csv, $io);
close $io or Carp::croak('Could not close agribalyse_food_codes.csv');

while (<>) {
	my $line = $_;

	if ($line =~ /^ciqual_food_code:en:(\d+)/msx) {
		if (defined $agb_ciqual_names_fr{$1}) {
			print 'agribalyse_food_code:en:' . $1 . "\n" or Carp::croak('Unable to write to *STDOUT');
		}
	}

	print $line or Carp::croak('Unable to write to *STDOUT');
}
