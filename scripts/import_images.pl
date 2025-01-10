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

use ProductOpener::PerlStandards;

use Log::Any qw($log);

use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Mail qw/send_email_to_producers_admin/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Import qw/list_product_images_files_in_dir upload_images_for_product/;
use ProductOpener::LoadData qw/load_data/;

use Storable qw/dclone/;
use Encode;
use Time::Local;
use Data::Dumper;
use Getopt::Long;

use Log::Any::Adapter 'TAP', filter => "none";

my $usage = <<TXT
import_images.pl imports product images from a directory into the database of Product Opener.

Images must be named [code]_[front|ingredients|nutrition]_[language code].[png|jpg]

Usage:

import_images.pl --images_dir path_to_directory_containing_images --import_lc [default language code of images] --user_id user_id --comment "Systeme U import"
 --define lc=fr 

--source_licence "Creative Commons CC-BY-SA 4.0"
--source_licence-url
--manufacturer : indicates the data comes from the manufacturer (and not another 3rd party open data source)
--test	: do not import product data or images, but compute statistics.
TXT
	;

my $csv_file;
my $images_dir;
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
my $skip_products_without_info = 0;
my $skip_existing_values = 0;
my $only_select_not_existing_images = 0;
my $use_brand_owner_as_org_name = 0;
my $user_id;
my $org_id;
my $owner_id;

GetOptions(
	"import_lc=s" => \$import_lc,
	"csv_file=s" => \$csv_file,
	"images_dir=s" => \$images_dir,
	"user_id=s" => \$user_id,
	"org_id=s" => \$org_id,
	"owner_id=s" => \$owner_id,
	"comment=s" => \$comment,
	"source_id=s" => \$source_id,
	"source_name=s" => \$source_name,
	"source_url=s" => \$source_url,
	"source_licence=s" => \$source_licence,
	"source_licence_url=s" => \$source_licence_url,
	"test" => \$test,
	"manufacturer" => \$manufacturer,
	"no_source" => \$no_source,
) or die("Error in command line arguments:\n\n$usage");

print STDERR "import_csv_file.pl
- import_lc: $import_lc
- user_id: $user_id
- org_id: $org_id
- owner_id: $owner_id
- images_dir: $images_dir
- comment: $comment
- source_id: $source_id
- source_name: $source_name
- source_url: $source_url
- source_licence: $source_licence
- source_licence_url: $source_licence_url
- manufacturer: $manufacturer
- testing: $test
";

my $missing_arg = 0;

if (not defined $import_lc) {
	print STDERR "missing --import_lc parameter\n";
	$missing_arg++;
}

if (not defined $images_dir) {
	print STDERR "missing --images_dir parameter\n";
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

load_data();

my $args_ref = {
	user_id => $user_id,
	org_id => $org_id,
	owner_id => $owner_id,
	global_values => {lc => $import_lc},
	images_dir => $images_dir,
	comment => $comment,
	source_id => $source_id,
	source_name => $source_name,
	source_url => $source_url,
	source_licence => $source_licence,
	source_licence_url => $source_licence_url,
	test => $test,
	manufacturer => $manufacturer,
	no_source => $no_source,
};

$Org_id = $org_id;
$Owner_id = get_owner_id($User_id, $Org_id, $args_ref->{owner_id});

my $stats_ref = {
	products_created => {},
	products_with_images => {},
};

my $images_ref = list_product_images_files_in_dir($args_ref->{images_dir}, $stats_ref);

foreach my $code (sort keys %{$images_ref}) {

	print STDERR "code: $code\n";

	my $product_id = product_id_for_owner($Owner_id, $code);

	my $product_ref = retrieve_product($product_id);

	if (not defined $product_ref) {
		$stats_ref->{products_created}{$code} = 1;

		$product_ref = init_product($user_id, $org_id, $code, undef);
		$product_ref->{lc} = $import_lc;
		$product_ref->{lang} = $import_lc;

		delete $product_ref->{countries};
		delete $product_ref->{countries_tags};
		delete $product_ref->{countries_hierarchy};

		store_product($user_id, $product_ref, "Creating product (import_images) - " . ($comment || ""));
	}

	# Upload images

	$stats_ref->{products_with_images}{$code} = 1;
	upload_images_for_product($args_ref, $images_ref->{$code}, $product_ref, {}, $product_id, $code, $user_id,
		"Adding photo (import_images) - " . ($comment || ""), $stats_ref);
}

print STDERR "\n\nstats:\n\n";

foreach my $stat (sort keys %{$stats_ref}) {

	print STDERR $stat . "\t" . (scalar keys %{$stats_ref->{$stat}}) . "\n";

	open(my $out, ">", "$BASE_DIRS{CACHE_TMP}/import_images.$stat.txt")
		or print "Could not create import_images.$stat.txt : $!\n";

	foreach my $code (sort keys %{$stats_ref->{$stat}}) {
		print $out $code . "\n";
	}
	close($out);
}

# Send an e-mail notification to admins

my $template_data_ref = {
	args => $args_ref,
	stats => $stats_ref,
};

my $mail = '';
process_template("emails/import_csv_file_admin_notification.tt.html", $template_data_ref, \$mail)
	or print STDERR "emails/import_csv_file_admin_notification.tt.html template error: " . $tt->error();
if ($mail =~ /^\s*Subject:\s*(.*)\n/i) {
	my $subject = $1;
	my $body = $';
	$body =~ s/^\n+//;

	send_email_to_producers_admin($subject, $body);

	print "email subject: $subject\n\n";
	print "email body:\n$body\n\n";
}

if ($stats_ref->{error}) {
	print STDERR "An error occured: " . $stats_ref->{error}{error} . "\n";
	exit(1);
}
