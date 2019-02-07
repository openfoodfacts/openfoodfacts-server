#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2018 Association Open Food Facts
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

use strict;
use utf8;

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
use ProductOpener::SiteQuality qw/:all/;
use ProductOpener::Data qw/:all/;

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
export_csv_file.pl expors product data from the database of Product Opener.

Usage:

export_csv_file.pl --query field_name=field_value --query other_field_name=other_field_value
--fields code,ingredients_texts_fr,categories_tags
TXT
;


my %query_fields_values = ();
my $fields;

GetOptions (
	"fields=s" => \$fields,
	"query=s%" => \%query_fields_values,
		)
  or die("Error in command line arguments:\n$\nusage");

print STDERR "export_csv_file.pl
- fields: $fields
- query fields values:
";

my $query_ref = {};

foreach my $field (sort keys %query_fields_values) {
	print STDERR "-- $field: $query_fields_values{$field}\n";
	$query_ref->{$field} = $query_fields_values{$field};
}

my $missing_arg = 0;
if (not defined $fields) {
	print STDERR "missing --fields parameter\n";
	$missing_arg++;
}


$missing_arg and exit();


my $csv = Text::CSV->new ( { binary => 1 , sep_char => "\t" } )  # should set binary attribute.
                 or die "Cannot use CSV: ".Text::CSV->error_diag ();

 
my $fh = *STDOUT; 
 
my @fields = split(/,/, $fields);

# Print the header line with fields names
$csv->print ($fh, \@fields);
print "\n";

my $cursor = get_products_collection()->query($query_ref);;
$cursor->immortal(1);
my $count = $cursor->count();

my $i = 0;
	
print STDERR "$count products to export\n";
	
while (my $product_ref = $cursor->next) {

	$i++;
	
	my @values = ();
	foreach my $field (@fields) {
		my $value;
		if (($field =~ /_tags$/) and (defined $product_ref->{$field})) {
			$value = join(",", @{$product_ref->{$field}});
		}
		else {
			$value = $product_ref->{$field};
		}
		push @values, $value;
	}
	
	$csv->print ($fh, \@values);
	print "\n";

}


print "\n\nexport done, $i products exported\n\n";

