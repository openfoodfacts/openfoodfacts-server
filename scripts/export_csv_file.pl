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

use ProductOpener::Config qw/:all/;
use ProductOpener::Export qw/:all/;

use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;
use Time::Local;
use Data::Dumper;
use Text::CSV;
use Getopt::Long;

binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");


my $usage = <<TXT
export_csv_file.pl exports product data from the database of Product Opener.

If the --fields argument is specified, only the corresponding fields are exported,
otherwise all populated input fields (provided by users or producers) are exported.

The --extra_fields parameter allows to specify other fields to export (e.g fields
that are computed from other fields).

Usage:

export_csv_file.pl --query field_name=field_value --query other_field_name=other_field_value
[--fields code,ingredients_texts_fr,categories_tags] [--extra_fields nova_group,nutrition_grade_fr]
[--include-images-paths]
TXT
;


my %query_fields_values = ();
my $fields;
my $extra_fields;
my $separator = "\t";
my $include_images_paths;

GetOptions (
	"fields=s" => \$fields,
	"extra_fields=s" => \$extra_fields,
	"query=s%" => \%query_fields_values,
	"separator=s" => \$separator,
	"include-images-paths" => \$include_images_paths,
		)
  or die("Error in command line arguments:\n$\nusage");

print STDERR "export_csv_file.pl
- fields: $fields
- extra_fields: $extra_fields
- separator: $separator
- include_images_paths : $include_images_paths
- query fields values:
";

my $query_ref = {};

foreach my $field (sort keys %query_fields_values) {
	print STDERR "-- $field: $query_fields_values{$field}\n";
	$query_ref->{$field} = $query_fields_values{$field};
}

# Construct the MongoDB query

use boolean;

foreach my $field (sort keys %{$query_ref}) {
	if ($query_ref->{$field} eq 'null') {
		# $query_ref->{$field} = { '$exists' => false };
		$query_ref->{$field} = undef;
	}
	if ($query_ref->{$field} eq 'exists') {
		$query_ref->{$field} = { '$exists' => true };
	}
}

use Data::Dumper;
print STDERR "MongoDB query:\n" . Dumper($query_ref);

# CSV export

my $args_ref = {filehandle=>*STDOUT, separator=>$separator, query=>$query_ref };

if ((defined $fields) and ($fields ne "")) {
	$args_ref->{fields} = [split(/,/, $fields)];
}

if ((defined $extra_fields) and ($extra_fields ne "")) {
	$args_ref->{extra_fields} = [split(/,/, $extra_fields)];
}

if (defined $include_images_paths) {
	$args_ref->{include_images_paths} = 1;
}

export_csv($args_ref);

