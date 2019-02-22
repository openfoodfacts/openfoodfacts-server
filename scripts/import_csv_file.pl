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

use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;
use Time::Local;
use Data::Dumper;
use Text::CSV;
use Getopt::Long;


my $usage = <<TXT
import_csv.pl imports product data (and optionnaly associated images) into the database of Product Opener.
The CSV file needs to be in the Product Opener format. Images need to be named [code]_[front|ingredients|nutrition]_[language code].[png|jpg]

Usage:

import_csv_file.pl --csv_file path_to_csv_file --images_dir path_to_directory_containing_images --user_id user_id --comment "Systeme U import"
 --define lc=fr --define stores="Magasins U"

--source-licence "Creative Commons CC-BY-SA 4.0"
--source-licence-url
--manufacturer : indicates the data comes from the manufacturer (and not another 3rd party open data source)
--test	: do not import product data or images, but compute statistics.
--define	: allows to define field values that will be applied to all products.
--code	: only import a product with a specific code
--skip_not_existing_products
--only_import_products_with_images
--skip_products_without_info
--skip_existing_values
TXT
;


my $csv_file;
# $User_id is a global variable from Display.pm
my %global_values = ();
my $only_import_products_with_images = 0;
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
my $skip_if_not_code;
my $skip_products_without_info = 0;
my $skip_existing_values = 0;


GetOptions (
	"import_lc=s" => \$import_lc,
	"csv_file=s" => \$csv_file,
	"images_dir=s" => \$images_dir,
	"user_id=s" => \$User_id,
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
	"only_import_products_with_images" => \$only_import_products_with_images,
	"code=s" => \$skip_if_not_code,
	"skip_products_without_info" => \$skip_products_without_info,
	"skip_existing_values" => \$skip_existing_values,
		)
  or die("Error in command line arguments:\n$\nusage");

print STDERR "import.pl
- csv_file: $csv_file
- images_dir: $images_dir
- only_import_products_with_images: $only_import_products_with_images
- user_id: $User_id
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

if (not defined $User_id) {
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

my %stats = (
'products_in_file' => {},
'products_already_existing' => {},
'products_created' => {},
'products_data_updated' => {},
'products_data_not_updated' => {},
'products_info_added' => {},
'products_info_changed' => {},
'products_info_updated' => {},
'products_info_not_updated' => {},
'products_nutrition_added' => {},
'products_nutrition_changed' => {},
'products_nutrition_updated' => {},
'products_nutrition_not_updated' => {},
'products_images_added' => {},
'products_with_images' => {},
'products_with_data' => {},
'products_with_info' => {},
'products_with_nutrition' => {},
'products_without_images' => {},
'products_without_data' => {},
'products_without_info' => {},
'products_without_nutrition' => {},
'products_updated' => {},

);


my $csv = Text::CSV->new ( { binary => 1 , sep_char => "\t" } )  # should set binary attribute.
                 or die "Cannot use CSV: ".Text::CSV->error_diag ();


my $time = time();

my $i = 0;
my $j = 0;
my $existing = 0;
my $new = 0;
my $differing = 0;
my %differing_fields = ();
my @edited = ();
my %edited = ();
my %nutrients_edited = ();


# Read images if supplied

my $images_ref = {};

if ((defined $images_dir) and ($images_dir ne '')) {

	if (not -d $images_dir) {
		die("images_dir $images_dir is not a directory\n");
	}

	# images rules to assign front/ingredients/nutrition image ids

	my @images_rules = ();

	if (-e "$images_dir/images.rules") {

		print STDERR "found images rules: $images_dir/images.rules\n";

		open (my $in, '<', "$images_dir/images.rules") or die "Could not open $images_dir/images.rules : $!\n";
		my $line_number = 0;
		while (<$in>) {

			my $line = $_;
			chomp($line);

			$line_number++;

			if ($line =~ /^#/) {
				print STDERR "ignoring comment: $line\n";
				next;
			}
			elsif ($line =~ /^([^\t]+)\t([^\t]+)/) {
				push @images_rules, [$1, $2];
				print STDERR "adding rule - find: $1 - replace: $2\n";
			}
			else {
				die("Unrecognized line number $i: $line_number\n");
			}
		}
	}
	else {
		print STDERR "did not find images rules: $images_dir/images.rules does not exist\n";
	}

	print "Opening images_dir $images_dir\n";

	if (opendir (DH, "$images_dir")) {
		foreach my $file (sort { $a cmp $b } readdir(DH)) {

			# apply image rules to the file name to assign front/ingredients/nutrition
			my $file2 = $file;

			foreach my $images_rule_ref (@images_rules) {
				my $find = $images_rule_ref->[0];
				my $replace = $images_rule_ref->[1];
				#$file2 =~ s/$find/$replace/e;
				# above line does not work

				my $str = $file2;
				my $pat = $find;
				my $repl = $replace;

				# make $repl safe to eval
				$repl =~ tr/\0//d;
				$repl =~ s/([^A-Za-z0-9\$])/\\$1/g;
				$repl = '"' . $repl . '"';
				$str =~ s/$pat/$repl/eeg;

				$file2 = $str;

				if ($file2 ne $file) {
					print STDERR "applied rule find $find - replace $replace - file: $file - file2: $file2\n";
				}
			}

			if ($file2 =~ /(\d+)(_|-|\.)?([^\.-]*)?((-|\.)(.*))?\.(jpg|jpeg|png)/i) {

				my $code = $1;
				my $imagefield = $3;	# front / ingredients / nutrition , optionnaly with _[language code] suffix

				if ((not defined $imagefield) or ($imagefield eq '')) {
					$imagefield = "front";
				}

				$stats{products_with_images_even_if_no_data}{$code} = 1;

				print "FOUND IMAGE FOR PRODUCT CODE $code - file $file - file2 $file2 - imagefield: $imagefield\n";

				# skip jpg and keep png for front product image

				defined $images_ref->{$code} or $images_ref->{$code} = {};

				# push @{$images_ref->{$code}}, $file;
				# keep jpg if there is also a png
				if (not defined $images_ref->{$code}{$imagefield}) {
					$images_ref->{$code}{$imagefield} = $file;
				}
			}

		}
	}
	else {
		die ("Could not open images_dir $images_dir : $!\n");
	}
}

print "importing products\n";

open (my $io, '<:encoding(UTF-8)', $csv_file) or die("Could not open $csv_file: $!");

$csv->column_names ($csv->getline ($io));

my $skip_not_existing = 0;
my $skip_no_images = 0;

#my $skip_until = 8018759001393;
my $skip_until;

while (my $imported_product_ref = $csv->getline_hr ($io)) {

	$i++;

	my $modified = 0;

	# Keep track of fields that have been modified, so that we don't import products that have not been modified
	my @modified_fields;

	my @images_ids;

	my $code = remove_tags_and_quote($imported_product_ref->{code});

	if ((defined $skip_if_not_code) and ($code ne $skip_if_not_code)) {
		next;
	}


	if (($skip_until > 0) and ($code eq $skip_until)) {
		$skip_until = 0;
		next;
	}

	$skip_until and next;


	print "product $i - code: $code\n";

	if ($code eq '') {
		print "empty code\n";
		use Data::Dumper;
		print Dumper($imported_product_ref);
		die;
	}

	if ($code !~ /^\d\d\d\d\d\d\d\d(\d*)$/) {
		print "code $code is not a number with 8 or more digits\n";
		use Data::Dumper;
		print Dumper($imported_product_ref);
		next;
	}

	$stats{products_in_file}{$code} = 1;

	# apply global field values
	foreach my $field (keys %global_values) {
		if ((not defined $imported_product_ref->{$field}) or ($imported_product_ref->{$field} eq ""))  {
			$imported_product_ref->{$field} = $global_values{$field};
		}
	}

	if ((defined $imported_product_ref->{lc}) and ($imported_product_ref->{lc} !~ /^\w\w$/)) {
		print "lc " . $imported_product_ref->{lc} . " for product code $code is not a 2 letter language code\n";
		use Data::Dumper;
		print Dumper($imported_product_ref);
		die;
	}




	# next if ($i < 2665);

	if ($only_import_products_with_images) {

		print "PRODUCT LINE NUMBER $i - CODE $code\n";

		if (not defined $images_ref->{$code}) {
			print "MISSING IMAGES ALL - PRODUCT CODE $code\n";
		}
		if (not defined $images_ref->{$code}{front}) {
			print "MISSING IMAGES FRONT - PRODUCT CODE $code\n";
		}
		if (not defined $images_ref->{$code}{ingredients}) {
			print "MISSING IMAGES INGREDIENTS - PRODUCT CODE $code\n";
		}
		if (not defined $images_ref->{$code}{nutrition}) {
			print "MISSING IMAGES NUTRITION - PRODUCT CODE $code\n";
		}

		if ((not defined $images_ref->{$code}) or (not defined $images_ref->{$code}{front})
			or ((not defined $images_ref->{$code}{ingredients}))) {
			print "MISSING IMAGES SOME - PRODUCT CODE $code\n";
			$skip_no_images++;
			next;
		}
	}

	my $product_ref = product_exists($code); # returns 0 if not


	if ((not defined $imported_product_ref->{lc}) and (not defined $import_lc))  {
		die ("missing language code lc in csv file, global field values, or import_lc for product code $code \n");
	}

	my $product_comment = $comment;
	if ((defined $imported_product_ref->{comment}) and ($imported_product_ref->{comment} ne "")) {
		$product_comment .= " - " . $imported_product_ref->{comment};
	}

	if (not $product_ref) {
		print "- does not exist in OFF yet\n";

		if ($skip_not_existing_products) {
			print STDERR "skip not existing products\n";
			$skip_not_existing++;
			next;
		}

		$new++;
		if (1 and (not $product_ref)) {
			print "product code $code does not exist yet, creating product\n";

			$stats{products_created}{$code} = 1;

			$User_id = $User_id;
			$product_ref = init_product($code);
			$product_ref->{interface_version_created} = "import_csv_file.pl - version 2019/01/28";
			if (defined $global_values{lc}) {
				$product_ref->{lc} = $global_values{lc};
			}
			else {
				delete $product_ref->{lc};
			}
			delete $product_ref->{countries};
			delete $product_ref->{countries_tags};
			delete $product_ref->{countries_hierarchy};
			if (not $test) {
				# store_product($product_ref, "Creating product - " . $product_comment );
			}
		}

	}
	else {
		print "- already exists in OFF\n";
		$existing++;
		$stats{products_already_existing}{$code} = 1;
	}

	# First load the global params, then apply the product params on top
	my %params = %global_values;




	# Create or update fields

	my %param_langs = ();

	foreach my $field (keys %$imported_product_ref) {
		if (($field =~ /^(.*)_(\w\w)$/) and (defined $language_fields{$1})) {
			$param_langs{$2} = 1;
		}
	}

	my @param_sorted_langs = sort keys %param_langs;

	my @param_fields = ();

	foreach my $field ('lc', 'product_name', 'generic_name',
		@ProductOpener::Config::product_fields, @ProductOpener::Config::product_other_fields,
		'nutrition_data_per', 'nutrition_data_prepared_per', 'serving_size', 'allergens', 'traces', 'ingredients_text','lang') {

		if (defined $language_fields{$field}) {
			foreach my $display_lc (@param_sorted_langs) {
				push @param_fields, $field . "_" . $display_lc;
			}
		}
		else {
			push @param_fields, $field;
		}
	}

	foreach my $field (@param_fields) {
		print $field . "\n";
	}


	foreach my $field (@param_fields) {

		if ((defined $imported_product_ref->{$field}) and ($imported_product_ref->{$field} !~ /^\s*$/)) {


			print "defined and non empty value for field $field : " . $imported_product_ref->{$field} . "\n";

			if (($field =~ /product_name/) or ($field eq "brands")) {
				$stats{products_with_info}{$code} = 1;
			}

			# for tag fields, only add entries to it, do not remove other entries

			if (defined $tags_fields{$field}) {

				my $current_field = $product_ref->{$field};

				# brands -> remove existing values;
				# allergens -> remove existing values;
				if (($field eq 'brands') and ($product_ref->{$field} =~ /coq/i) ) {
					$product_ref->{$field} = "";
					delete $product_ref->{$field . "_tags"};
				}

				my %existing = ();
					if (defined $product_ref->{$field . "_tags"}) {
					foreach my $tagid (@{$product_ref->{$field . "_tags"}}) {
						$existing{$tagid} = 1;
					}
				}


				foreach my $tag (split(/,/, remove_tags_and_quote($imported_product_ref->{$field}))) {

					my $tagid;

					next if $tag =~ /^(\s|,|-|\%|;|_|°)*$/;

					$tag =~ s/^\s+//;
					$tag =~ s/\s+$//;

					if ($field eq 'emb_codes') {
						$tag = normalize_packager_codes($tag);
					}

					if (defined $taxonomy_fields{$field}) {
						$tagid = get_taxonomyid(canonicalize_taxonomy_tag($imported_product_ref->{lc}, $field, $tag));
					}
					else {
						$tagid = get_fileid($tag);
					}

					if (not exists $existing{$tagid}) {
						print "- adding $tagid to $field\n";
						$product_ref->{$field} .= ", $tag";
					}
					else {
						#print "- $tagid already in $field\n";
					}

				}

				if ($product_ref->{$field} =~ /^, /) {
					$product_ref->{$field} = $';
				}

				my $tag_lc = $product_ref->{lc};

				# If an import_lc was passed as a parameter, assume the imported values are in the import_lc language
				if (defined $import_lc) {
					$tag_lc = $import_lc;
				}

				if ($field eq 'emb_codes') {
					# French emb codes
					$product_ref->{emb_codes_orig} = $product_ref->{emb_codes};
					$product_ref->{emb_codes} = normalize_packager_codes($product_ref->{emb_codes});
				}
				if (not defined $current_field) {
					print "added value for product code: $code - field: $field = $product_ref->{$field}\n";
					compute_field_tags($product_ref, $tag_lc, $field);
					push @modified_fields, $field;
					$modified++;
					$stats{products_info_added}{$code} = 1;
				}
				elsif ($current_field ne $product_ref->{$field}) {
					print "changed value for product code: $code - field: $field = $product_ref->{$field} - old: $current_field\n";
					compute_field_tags($product_ref, $tag_lc, $field);
					push @modified_fields, $field;
					$modified++;
					$stats{products_info_changed}{$code} = 1;
				}
				elsif ($field eq "brands") {	# we removed it earlier
					compute_field_tags($product_ref, $tag_lc, $field);
				}


			}
			else {
				# non-tag field
				my $new_field_value = remove_tags_and_quote($imported_product_ref->{$field});

				$new_field_value =~ s/\s+$//;
				$new_field_value =~ s/^\s+//;

				next if $new_field_value eq "";

				if (($field eq 'quantity') or ($field eq 'serving_size')) {

						# openfood.ch now seems to round values to the 1st decimal, e.g. 28.0 g
						$new_field_value =~ s/\.0 / /;

						# 6x90g
						$new_field_value =~ s/(\d)(\s*)x(\s*)(\d)/$1 x $4/i;

						$new_field_value =~ s/(\d)( )?(g|gramme|grammes|gr)(\.)?/$1 g/i;
						$new_field_value =~ s/(\d)( )?(ml|millilitres)(\.)?/$1 ml/i;
						$new_field_value =~ s/litre|litres|liter|liters/l/i;
						$new_field_value =~ s/kilogramme|kilogrammes|kgs/kg/i;
				}

				$new_field_value =~ s/\s+$//g;
				$new_field_value =~ s/^\s+//g;

				if ($field =~ /^ingredients_text_(\w\w)/) {
					my $ingredients_lc = $1;
					$new_field_value = clean_ingredients_text_for_lang($new_field_value, $ingredients_lc);
				}

				next if $new_field_value eq "";

				# existing value?
				if ((defined $product_ref->{$field}) and ($product_ref->{$field} !~ /^\s*$/)) {

					if ($skip_existing_values) {
						print STDERR "skipping existing value for field $field : $product_ref->{$field}\n";
						next;
					}

					my $current_value = $product_ref->{$field};
					$current_value =~ s/\s+$//g;
					$current_value =~ s/^\s+//g;

					# normalize current value
					if (($field eq 'quantity') or ($field eq 'serving_size')) {

						$current_value =~ s/(\d)( )?(g|gramme|grammes|gr)(\.)?/$1 g/i;
						$current_value =~ s/(\d)( )?(ml|millilitres)(\.)?/$1 ml/i;
						$current_value =~ s/litre|litres|liter|liters/l/i;
						$current_value =~ s/kilogramme|kilogrammes|kgs/kg/i;
					}


					if (lc($current_value) ne lc($new_field_value)) {
					# if ($current_value ne $new_field_value) {
						print "differing value for product code $code - field $field - existing value:\n$product_ref->{$field}\nnew value:\n$new_field_value - https://world.openfoodfacts.org/product/$code\n";
						$differing++;
						$differing_fields{$field}++;

						print "changing previously existing value for product code $code - field $field - value: $new_field_value\n";
						$product_ref->{$field} = $new_field_value;
						push @modified_fields, $field;
						$modified++;

						$stats{products_info_changed}{$code} = 1;
					}
					elsif (($field eq 'quantity') and ($product_ref->{$field} ne $new_field_value)) {
						# normalize quantity
						print "normalizing quantity for product code $code - field $field - existing value: $product_ref->{$field} - value: $new_field_value\n";
						$product_ref->{$field} = $new_field_value;
						push @modified_fields, $field;
						$modified++;

						$stats{products_info_changed}{$code} = 1;
					}


				}
				else {
					print "setting previously unexisting value for product code $code - field $field - value: $new_field_value\n";
					$product_ref->{$field} = $new_field_value;
					push @modified_fields, $field;
					$modified++;
					$stats{products_info_added}{$code} = 1;
				}
			}
		}
	}


	# nutrients

	my $seen_salt = 0;

	foreach my $nutriment (@{$nutriments_tables{europe}}, "nutrition-score-fr-producer") {

		next if $nutriment =~ /^\#/;

		my $nid = $nutriment;
		$nid =~ s/^(-|!)+//g;
		$nid =~ s/-$//g;

		# don't set sodium if we have salt
		next if (($nid eq 'sodium') and ($seen_salt));

		# next if $nid =~ /^nutrition-score/;   #TODO


		# for prepared product
		my $nidp = $nid . "_prepared";

		# Save current values so that we can see if they have changed
		my %original_values = (
			$nid . "_modifier" => $product_ref->{nutriments}{$nid . "_modifier"},
			$nid . "_modifierp" => $product_ref->{nutriments}{$nid . "_modifierp"},
			$nid . "_value" => $product_ref->{nutriments}{$nid . "_value"},
			$nid . "_valuep" => $product_ref->{nutriments}{$nid . "_valuep"},
			$nid . "_unit" => $product_ref->{nutriments}{$nid . "_unit"},
		);


		my $value = remove_tags_and_quote($imported_product_ref->{$nid . "_value"});
		my $valuep = remove_tags_and_quote($imported_product_ref->{$nid . "_prepared_value"});
		my $unit = remove_tags_and_quote($imported_product_ref->{$nid . "_unit"});


		if ($nid eq 'alcohol') {
			$unit = '% vol';
		}

		my $modifier = undef;
		my $modifierp = undef;

		normalize_nutriment_value_and_modifier(\$value, \$modifier);
		normalize_nutriment_value_and_modifier(\$valuep, \$modifierp);


		if ((defined $value) and ($value ne '')) {

			if ($nid eq 'salt') {
				$seen_salt = 1;
			}

			print "nutrient with defined and non empty value: nid: $nid - value: $value\n";
			$stats{products_with_nutrition}{$code} = 1;

			assign_nid_modifier_value_and_unit($product_ref, $nid, $modifier, $value, $unit);
		}

		if ((defined $valuep) and ($valuep ne '')) {

			print "nutrient with defined and non empty prepared value: nidp: $nidp - valuep: $valuep\n";
			$stats{products_with_nutrition}{$code} = 1;

			assign_nid_modifier_value_and_unit($product_ref, $nidp, $modifierp, $valuep, $unit);
		}


		# See which fields have changed

		foreach my $field (sort keys %original_values) {
			if ((defined $product_ref->{nutriments}{$field}) and ($product_ref->{nutriments}{$field} ne "")
				and (defined $original_values{$field}) and ($original_values{$field} ne "")
				and ($product_ref->{nutriments}{$field} ne $original_values{$field})) {
				print "differing nutrient value for product code $code - field: $field - old: $original_values{$field} - new: $product_ref->{nutriments}{$field} \n";
				$stats{products_nutrition_updated}{$code} = 1;
				$stats{products_nutrition_changed}{$code} = 1;
				$modified++;
				$nutrients_edited{$code}++;
			}
			elsif ((defined $product_ref->{nutriments}{$field}) and ($product_ref->{nutriments}{$field} ne "")
				and ((not defined $original_values{$field})	or ($original_values{$field} eq ''))) {
				print "new nutrient value for product code $code - field: $field - new: $product_ref->{nutriments}{$field} \n";
				$stats{products_nutrition_updated}{$code} = 1;
				$stats{products_nutrition_added}{$code} = 1;
				$modified++;
				$nutrients_edited{$code}++;
			}
			elsif ((not defined $product_ref->{nutriments}{$field}) and (defined $original_values{$field}) and ($original_values{$field} ne '')) {
				print "deleted nutrient value for product code $code - field: $field - old: $original_values{$field} \n";
				$stats{products_nutrition_updated}{$code} = 1;
				$modified++;
				$nutrients_edited{$code}++;
			}
		}

	}


	if ((defined $stats{products_info_added}{$code}) or (defined $stats{products_info_changed}{$code})) {
		$stats{products_info_updated}{$code} = 1;
	}
	else {
		$stats{products_info_not_updated}{$code} = 1;
	}

	if ((defined $stats{products_nutrition_added}{$code}) or (defined $stats{products_nutrition_changed}{$code})) {
		$stats{products_nutrition_updated}{$code} = 1;
	}
	else {
		$stats{products_nutrition_not_updated}{$code} = 1;
	}

	if ((defined $stats{products_info_updated}{$code}) or (defined $stats{products_nutrition_updated}{$code})) {
		$stats{products_data_updated}{$code} = 1;
	}
	else {
		$stats{products_data_not_updated}{$code} = 1;
	}

	if (not defined $stats{products_with_info}{$code}) {
		$stats{products_without_info}{$code} = 1;
	}
	if (not defined $stats{products_with_nutrition}{$code}) {
		$stats{products_without_nutrition}{$code} = 1;
	}

	if ((defined $stats{products_with_info}{$code}) or (defined $stats{products_with_nutrition}{$code})) {
		$stats{products_with_data}{$code} = 1;
	}
	else {
		$stats{products_without_data}{$code} = 1;
	}


	if ($modified and not $stats{products_data_updated}{$code}) {
		die("modified but not products_data_updated\n");
	}

	if ((not $modified) and $stats{products_data_updated}{$code}) {
		die("not modified but not products_data_updated\n");
	}

	if ($code ne $product_ref->{code}) {
		print STDERR "code $code is not the same as product_ref->{code} " . $product_ref->{code} . "\n";
		# die("code $code is not the same as product_ref->{code} " . $product_ref->{code} . "\n");
		next;
	}

	# Skip further processing if we have not modified any of the fields

	print "product code $code - number of modifications - $modified\n";
	if ($modified == 0) {
		print "skipping product code $code - no modifications\n";
		$stats{products_data_not_updated}{$code} = 1;

	}
	elsif (($skip_products_without_info) and ($stats{products_without_info}{$code})) {
		print "skipping product code $code - product without info and --skip_products_without_info \n";
	}
	else {
		print "updating product code $code - $modified modifications\n";
		$stats{products_data_updated}{$code} = 1;

		# Process the fields

		# Food category rules for sweeetened/sugared beverages
		# French PNNS groups from categories

		if ($server_domain =~ /openfoodfacts/) {
			ProductOpener::Food::special_process_product($product_ref);
		}


		if ((defined $product_ref->{nutriments}{"carbon-footprint"}) and ($product_ref->{nutriments}{"carbon-footprint"} ne '')
			and not has_tag($product_ref, "labels", "en:carbon-footprint")) {
			push @{$product_ref->{"labels_hierarchy" }}, "en:carbon-footprint";
			push @{$product_ref->{"labels_tags" }}, "en:carbon-footprint";
		}

		if ((defined $product_ref->{nutriments}{"glycemic-index"}) and ($product_ref->{nutriments}{"glycemic-index"} ne '')
			and not has_tag($product_ref, "labels", "en:glycemic-index")) {
			push @{$product_ref->{"labels_hierarchy" }}, "en:glycemic-index";
			push @{$product_ref->{"labels_tags" }}, "en:glycemic-index";
		}



		# For fields that can have different values in different languages, copy the main language value to the non suffixed field

		foreach my $field (keys %language_fields) {
			if ($field !~ /_image/) {
				if (defined $product_ref->{$field . "_" . $product_ref->{lc}}) {
					$product_ref->{$field} = $product_ref->{$field . "_" . $product_ref->{lc}};
				}
			}
		}


		if ($server_domain =~ /openfoodfacts/) {
			ProductOpener::Food::special_process_product($product_ref);
		}

		compute_languages($product_ref); # need languages for allergens detection and cleaning ingredients

		# Ingredients classes
		clean_ingredients_text($product_ref);
		extract_ingredients_from_text($product_ref);
		extract_ingredients_classes_from_text($product_ref);
		detect_allergens_from_text($product_ref);


		if (not $no_source) {

			if (not defined $product_ref->{sources}) {
				$product_ref->{sources} = [];
			}

			my $product_source_url = $source_url;
			if ((defined $imported_product_ref->{source_url}) and ($imported_product_ref->{source_url} ne "")) {
				$product_source_url = $imported_product_ref->{source_url};
			}

			my $source_ref = {
				id => $source_id,
				name => $source_name,
				url => $product_source_url,
				manufacturer => $manufacturer,
				import_t => time(),
				fields => \@modified_fields,
				images => \@images_ids,
			};

			defined $source_licence and $source_ref->{source_licence} = $source_licence;
			defined $source_licence_url and $source_ref->{source_licence_url} = $source_licence_url;

			push @{$product_ref->{sources}}, $source_ref;

		}

		if (not $test) {

			fix_salt_equivalent($product_ref);

			compute_serving_size_data($product_ref);

			compute_nutrition_score($product_ref);

			compute_nova_group($product_ref);

			compute_nutrient_levels($product_ref);

			compute_unknown_nutrients($product_ref);

			ProductOpener::SiteQuality::check_quality($product_ref);


			print STDERR "Storing product code $code - product_ref->code: " . $product_ref->{code} . "\n";

			if ($code eq "3245413832719") {
				use Data::Dumper;
				print Dumper($product_ref);
			}
			#exit;


			store_product($product_ref, "Editing product (import_csv_file.pl) - " . $product_comment );

			push @edited, $code;
			$edited{$code}++;

			$stats{products_updated}{$code} = 1;

			$j++;

		}


	}


	# Images need to be updated after the product is saved (and possibly created)


	# Upload images

	if (defined $images_ref->{$code}) {

		$stats{products_with_images}{$code} = 1;

		if (not $test) {

			print STDERR "uploading images for product code $code\n";

			my $images_ref = $images_ref->{$code};

			foreach my $imagefield (sort keys %{$images_ref}) {

				print STDERR "imagefield: $imagefield\n";

				my $current_max_imgid = -1;

				if (defined $product_ref->{images}) {
					foreach my $imgid (keys %{$product_ref->{images}}) {
						if (($imgid =~ /^\d/) and ($imgid > $current_max_imgid)) {
							$current_max_imgid = $imgid;
						}
					}
				}

				my $imported_image_file = $images_ref->{$imagefield};

				# if the language is not specified, assign it to the language of the product

				my $imagefield_with_lc = $imagefield;

				if ($imagefield !~ /_\w\w/) {
					$imagefield_with_lc .= "_" . $product_ref->{lc};
				}

				# upload the image
				my $file = $imported_image_file;

				if (-e "$images_dir/$file") {
					print "found image file $images_dir/$file\n";

					# upload a photo
					my $imgid;
					my $return_code = process_image_upload($code, "$images_dir/$file", $User_id, undef, $product_comment, \$imgid);
					print "process_image_upload - file: $file - return code: $return_code - imgid: $imgid\n";

					if (($imgid > 0) and ($imgid > $current_max_imgid)) {
						$stats{products_images_added}{$code} = 1;
					}

					# select the photo
					if ($imagefield_with_lc =~ /front|ingredients|nutrition/) {

						if (($imgid > 0) and ($imgid > $current_max_imgid)) {

							print "assigning image $imgid to ${imagefield_with_lc}\n";
							eval { process_image_crop($code, $imagefield_with_lc, $imgid, 0, undef, undef, -1, -1, -1, -1); };
							# $modified++;

						}
						else {
							print "returned imgid $imgid not greater than the previous max imgid: $current_max_imgid\n";

							# overwrite already selected images
							if (($imgid > 0)
								and (exists $product_ref->{images})
								and (exists $product_ref->{images}{$imagefield_with_lc})
								and ($product_ref->{images}{$imagefield_with_lc}{imgid} != $imgid)) {
								print "re-assigning image $imgid to $imagefield_with_lc\n";
								eval { process_image_crop($code, $imagefield_with_lc, $imgid, 0, undef, undef, -1, -1, -1, -1); };
								# $modified++;
							}

						}
					}
				}
				else {
					print "did not find image file $images_dir/$file\n";
				}

			}
		}

	}
	else {
		print STDERR "no images for product code $code\n";
		$stats{products_without_images}{$code} = 1;
	}


	if ($modified) {
		$j++ > 10 and last;
	}
}


print "\n\nimport done\n\n";

foreach my $field (sort keys %differing_fields) {
	print "field $field - $differing_fields{$field} differing values\n";
}


print "$i products\n";
print "$new new products\n";
print "$skip_not_existing skipped not existing products\n";
print "$skip_no_images skipped no images products\n";
print "$existing existing products\n";
print "$differing differing values\n\n";

print ((scalar keys %nutrients_edited) . " products with edited nutrients\n");
print ((scalar keys %edited) . " products with edited fields or nutrients\n");

print ((scalar @edited) . " products updated\n");


print "\n\nstats:\n\n";

foreach my $stat (sort keys %stats) {

	print $stat . "\t" . (scalar keys %{$stats{$stat}}) . "\n";

	open (my $out, ">", "import.$stat.txt") or print "Could not create import.$stat.txt : $!\n";

	foreach my $code ( sort keys %{$stats{$stat}}) {
		print $out $code . "\n";
	}
	close($out);
}
