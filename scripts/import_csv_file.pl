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
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Mail qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::DataQuality qw/:all/;
use ProductOpener::Import qw/:all/;

use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;
use Time::Local;
use Data::Dumper;
use Text::CSV;
use Getopt::Long;

use Log::Any::Adapter 'TAP', filter => "none";

my $usage = <<TXT
import_csv.pl imports product data (and optionnaly associated images) into the database of Product Opener.
The CSV file needs to be in the Product Opener format. Images need to be named [code]_[front|ingredients|nutrition]_[language code].[png|jpg]

Usage:

import_csv_file.pl --csv_file path_to_csv_file --images_dir path_to_directory_containing_images --user_id user_id --comment "Systeme U import"
 --define lc=fr --define stores="Magasins U"

--source_licence "Creative Commons CC-BY-SA 4.0"
--source_licence-url
--manufacturer : indicates the data comes from the manufacturer (and not another 3rd party open data source)
--test	: do not import product data or images, but compute statistics.
--define	: allows to define field values that will be applied to all products.
--code	: only import a product with a specific code
--skip_not_existing_products
--skip_products_without_images
--skip_products_without_info
--skip_existing_values
--only_select_not_existing_images
TXT
;


my $csv_file;
my %global_values = ();
my $skip_products_without_images = 0;
my $images_dir;
my $images_download_dir;
my $comment = '';
my $source_id;
my $source_name;
my $source_url;
my $source_licence;
my $source_licence_url;

my $manufacturer = 0;
my $test = 0;
my $import_lc;
my $no_source = 0;
my $skip_not_existing_products = 0;
my $pretend = 0;
my $skip_if_not_code;
my $skip_products_without_info = 0;
my $skip_existing_values = 0;
my $only_select_not_existing_images = 0;
my $user_id;
my $org_id;
my $owner_id;

GetOptions (
	"import_lc=s" => \$import_lc,
	"csv_file=s" => \$csv_file,
	"images_dir=s" => \$images_dir,
	"images_download_dir=s" => \$images_download_dir,
	"user_id=s" => \$user_id,
	"org_id=s" => \$org_id,
	"owner_id=s" => \$owner_id,
	"comment=s" => \$comment,
	"source_id=s" => \$source_id,
	"source_name=s" => \$source_name,
	"source_url=s" => \$source_url,
	"source_licence=s" => \$source_licence,
	"source_licence_url=s" => \$source_licence_url,
	"define=s%" => \%global_values,
	"test" => \$test,
	"manufacturer" => \$manufacturer,
	"no_source" => \$no_source,
	"skip_not_existing_products" => \$skip_not_existing_products,
	"skip_products_without_images" => \$skip_products_without_images,
	"code=s" => \$skip_if_not_code,
	"skip_products_without_info" => \$skip_products_without_info,
	"skip_existing_values" => \$skip_existing_values,
	"only_select_not_existing_images" => \$only_select_not_existing_images,
		)
  or die("Error in command line arguments:\n$\nusage");

print STDERR "import_csv_file.pl
- user_id: $user_id
- org_id: $org_id
- owner_id: $owner_id
- csv_file: $csv_file
- images_dir: $images_dir
- skip_products_without_images: $skip_products_without_images
- comment: $comment
- source_id: $source_id
- source_name: $source_name
- source_url: $source_url
- source_licence: $source_licence
- source_licence_url: $source_licence_url
- manufacturer: $manufacturer
- testing: $test
- global fields values:
";

foreach my $field (sort keys %global_values) {
	print STDERR "-- $field: $global_values{$field}\n";
}

my $missing_arg = 0;
if (not defined $csv_file) {
	print STDERR "missing --csv_file parameter\n";
	$missing_arg++;
}

if (not defined $user_id) {
	print STDERR "missing --user_id parameter\n";
	$missing_arg++;
}

if (not $no_source) {

	if (not defined $source_id) {
		print STDERR "missing --source_id parameter\n";
		$missing_arg++;
	}

	if (not defined $source_name) {
		print STDERR "missing --source_name parameter\n";
		$missing_arg++;
	}

	if (not defined $source_url) {
		print STDERR "missing --source_url parameter\n";
		$missing_arg++;
	}
}

$missing_arg and exit();

my $stats_ref = import_csv_file( {
	user_id => $user_id,
	org_id => $org_id,
	owner_id => $owner_id,
	csv_file => $csv_file,
	global_values => \%global_values,
	images_dir => $images_dir,
	images_download_dir => $images_download_dir,
	comment => $comment,
	source_id => $source_id,
	source_name => $source_name,
	source_url => $source_url,
	source_licence => $source_licence,
	source_licence_url => $source_licence_url,
	test => $test,
	manufacturer => $manufacturer,
	no_source => $no_source,
	skip_not_existing_products => $skip_not_existing_products,
	skip_products_without_images => $skip_products_without_images,
	skip_if_not_code => $skip_if_not_code,
	skip_products_without_info => $skip_products_without_info,
	skip_existing_values => $skip_existing_values,
	only_select_not_existing_images => $only_select_not_existing_images,
});

print STDERR "\n\nstats:\n\n";

foreach my $stat (sort keys %{$stats_ref}) {

	print STDERR $stat . "\t" . (scalar keys %{$stats_ref->{$stat}}) . "\n";

	open (my $out, ">", "$data_root/tmp/import.$stat.txt") or print "Could not create import.$stat.txt : $!\n";

	foreach my $code ( sort keys %{$stats_ref->{$stat}}) {
		print $out $code . "\n";
	}
	close($out);
}
