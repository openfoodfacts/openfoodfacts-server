#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2019 Association Open Food Facts
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
my $separator = "\t";

GetOptions (
	"fields=s" => \$fields,
	"query=s%" => \%query_fields_values,
	"separator=s" => \$separator,
		)
  or die("Error in command line arguments:\n$\nusage");

print STDERR "export_csv_file.pl
- fields: $fields
- separator: $separator
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

# Construct the MongoDB query

use boolean;

foreach my $field (sort keys %$query_ref) {
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

my $count = get_products_collection()->count_documents($query_ref);

print STDERR "$count documents to export.\n";
sleep(2);

my $cursor = get_products_collection()->find($query_ref);
$cursor->immortal(1);


# CSV export

my $csv = Text::CSV->new ( { binary => 1 , sep_char => $separator } )  # should set binary attribute.
                 or die "Cannot use CSV: ".Text::CSV->error_diag ();


my $fh = *STDOUT;

my @fields = split(/,/, $fields);

# Print the header line with fields names
$csv->print ($fh, \@fields);
print "\n";

my $i = 0;

while (my $product_ref = $cursor->next) {

	$i++;

	my $added_images_urls = 0;

	my @values = ();
	foreach my $field (@fields) {
		my $value;

		if (($field =~ /^image_/) and (not $added_images_urls)) {
			ProductOpener::Display::add_images_urls_to_product($product_ref);
			$added_images_urls = 1;
		}

		if ($field =~ /^image_(ingredients|nutrition)_json$/) {
			if (defined $product_ref->{"image_$1_url"}) {
				$value = $product_ref->{"image_$1_url"};
				$value =~ s/\.(\d+)\.jpg/.json/;
			}
		}
		elsif ($field =~ /^image_(.*)_full_url$/) {
			if (defined $product_ref->{"image_$1_url"}) {
				$value = $product_ref->{"image_$1_url"};
				$value =~ s/\.(\d+)\.jpg/.full.jpg/;
			}
		}
		elsif (($field =~ /_tags$/) and (defined $product_ref->{$field})) {
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

