#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2026 Association Open Food Facts
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

# Extract the ingredients (materials) of the Ecobalyse food2 scope from processes.json,
# with their unit: the amounts we send to the Ecobalyse food2 API are expressed in the unit of the material
# (kg for most ingredients, L for some liquids), and transformations can only be applied to materials in kg.
#
# Input: external-data/ecobalyse/processes.json (downloaded from Ecobalyse, not stored in git)
# Output: external-data/ecobalyse/processes_materials_food2.json

use ProductOpener::PerlStandards;
use utf8;
use JSON::MaybeXS;

my $input_file = "external-data/ecobalyse/processes.json";
my $output_file = "external-data/ecobalyse/processes_materials_food2.json";

open(my $in, '<:raw', $input_file) or die "Could not open $input_file: $!";
my $data = decode_json(do {local $/; <$in>});
close($in);
die "Expected a JSON array" unless ref($data) eq 'ARRAY';

my @materials = ();
foreach my $process_ref (@$data) {
	next unless grep {$_ eq 'food2'} @{$process_ref->{scopes} // []};
	next unless grep {$_ eq 'ingredient'} @{$process_ref->{categories} // []};
	push @materials,
		{
		id => $process_ref->{id},
		displayName => $process_ref->{displayName},
		unit => $process_ref->{unit},
		};
}

@materials = sort {$a->{id} cmp $b->{id}} @materials;

open(my $out, '>:raw', $output_file) or die "Could not write $output_file: $!";
print $out JSON::MaybeXS->new->utf8->canonical->pretty->encode(\@materials);
close($out);

print STDERR scalar(@materials) . " food2 materials written to $output_file\n";
