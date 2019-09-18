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

use Modern::Perl '2017';
use utf8;

my $usage = <<TXT
update_all_products.pl is a script that updates the latest version of products in the file system and on MongoDB.
It is used in particular to re-run tags generation when taxonomies have been updated.

Usage:

update_all_products.pl --key some_string_value --fields categories,labels --index

The key is used to keep track of which products have been updated. If there are many products and field to updates,
it is likely that the MongoDB cursor of products to be updated will expire, and the script will have to be re-run.

--count		do not do any processing, just count the number of products matching the --query options
--just-print-codes	do not do any processing, just print the barcodes
--query some_field=some_value (e.g. categories_tags=en:beers)	filter the products
--process-ingredients	compute allergens, additives detection
--clean-ingredients	remove nutrition facts, conservation conditions etc.
--compute-nutrition-score	nutriscore
--compute-serving-size	compute serving size values
--compute-history	compute history and completeness
--check-quality	run quality checks
--compute-codes
--fix-serving-size-mg-to-ml
--index		specifies that the keywords used by the free text search function (name, brand etc.) need to be reindexed. -- TBD
--user		create a separate .sto file and log the change in the product history, with the corresponding user
--comment	comment for change in product history
--pretend	do not actually update products
TXT
;

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


use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;

use Getopt::Long;


my @fields_to_update = ();
my $key;
my $index = '';
my $count = '';
my $just_print_codes = '',
my $pretend = '';
my $process_ingredients = '';
my $clean_ingredients = '';
my $compute_nutrition_score = '';
my $compute_serving_size = '';
my $compute_data_sources = '';
my $compute_nova = '';
my $check_quality = '';
my $compute_codes = '';
my $compute_carbon = '';
my $compute_history = '';
my $comment = '';
my $fix_serving_size_mg_to_ml = '';
my $fix_missing_lc = '';
my $fix_zulu_lang = '';
my $fix_rev_not_incremented = '';
my $run_ocr = '';
my $autorotate = '';
my $query_ref = {};	# filters for mongodb query

GetOptions ("key=s"   => \$key,      # string
			"query=s%" => $query_ref,
			"count" => \$count,
			"just-print-codes" => \$just_print_codes,
			"fields=s" => \@fields_to_update,
			"index" => \$index,
			"pretend" => \$pretend,
			"clean-ingredients" => \$clean_ingredients,
			"process-ingredients" => \$process_ingredients,
			"compute-nutrition-score" => \$compute_nutrition_score,
			"compute-history" => \$compute_history,
			"compute-serving-size" => \$compute_serving_size,
			"compute-data-sources" => \$compute_data_sources,
			"compute-nova" => \$compute_nova,
			"compute-codes" => \$compute_codes,
			"compute-carbon" => \$compute_carbon,
			"check-quality" => \$check_quality,
			"fix-serving-size-mg-to-ml" => \$fix_serving_size_mg_to_ml,
			"fix-missing-lc" => \$fix_missing_lc,
			"fix-zulu-lang" => \$fix_zulu_lang,
			"fix-rev-not-incremented" => \$fix_rev_not_incremented,
			"user_id=s" => \$User_id,
			"comment=s" => \$comment,
			"run-ocr" => \$run_ocr,
			"autorotate" => \$autorotate,
			)
  or die("Error in command line arguments:\n\n$usage");

use Data::Dumper;

print Dumper(\@fields_to_update);

@fields_to_update = split(/,/,join(',',@fields_to_update));


use Data::Dumper;

    # simple procedural interface
    print Dumper(\@fields_to_update);


print "Updating fields: " . join(", ", @fields_to_update) . "\n\n";

my $unknown_fields = 0;

foreach my $field (@fields_to_update) {
	if ( (not defined $tags_fields{$field}) and (not defined $taxonomy_fields{$field}) and (not defined $hierarchy_fields{$field}) ) {
		print "Unknown field: $field\n";
		$unknown_fields++;
	}
}

if ($unknown_fields > 0) {
	die("Unknown fields, check for typos.");
}

if ((not $process_ingredients) and (not $compute_nutrition_score) and (not $compute_nova)
	and (not $clean_ingredients)
	and (not $compute_serving_size)
	and (not $compute_data_sources) and (not $compute_history)
	and (not $run_ocr) and (not $autorotate)
	and (not $fix_missing_lc) and (not $fix_serving_size_mg_to_ml) and (not $fix_zulu_lang) and (not $fix_rev_not_incremented)
	and (not $compute_codes) and (not $compute_carbon) and (not $check_quality) and (scalar @fields_to_update == 0) and (not $count) and (not $just_print_codes)) {
	die("Missing fields to update or --count option:\n$usage");
}

# Make sure we have a user id and we will use a new .sto file for all edits that change values entered by users
if ((not defined $User_id) and (($fix_serving_size_mg_to_ml) or ($fix_missing_lc))) {
	die("Missing --user-id. We must have a user id and we will use a new .sto file for all edits that change values entered by users.\n");
}

# Get a list of all products not yet updated
# Use query filtes entered using --query categories_tags=en:plant-milks

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

if (defined $key) {
	$query_ref->{update_key} = { '$ne' => "$key" };
}
else {
	$key = "key_" . time();
}

# $query_ref->{unknown_nutrients_tags} = { '$exists' => true,  '$ne' => [] };

print STDERR "Update key: $key\n\n";

use Data::Dumper;
print STDERR "MongoDB query:\n" . Dumper($query_ref);

my $products_collection = get_products_collection();

my $count = $products_collection->count_documents($query_ref);

print STDERR "$count documents to update.\n";
sleep(2);


my $cursor = $products_collection->query($query_ref)->fields({ code => 1 });
$cursor->immortal(1);

my $n = 0;	# number of products updated
my $m = 0;	# number of products with a new version created

my $fix_rev_not_incremented_fixed = 0;

while (my $product_ref = $cursor->next) {

	my $code = $product_ref->{code};
	my $path = product_path($code);

	if (not defined $code) {
		print STDERR "code field undefined for product id: " . $product_ref->{id} . " _id: " . $product_ref->{_id} . "\n";
	}
	else {
		print STDERR "updating product $code ($n)\n";
	}

	next if $just_print_codes;

	$product_ref = retrieve_product($code);

	if ((defined $product_ref) and ($code ne '')) {

		$lc = $product_ref->{lc};

		my $product_values_changed = 0;

		if ($fix_rev_not_incremented) { # https://github.com/openfoodfacts/openfoodfacts-server/issues/2321

			my $changes_ref = retrieve("$data_root/products/$path/changes.sto");
			if (defined $changes_ref) {
				my $change_ref = @$changes_ref[-1];
				my $last_rev = $change_ref->{rev};
				my $current_rev = $product_ref->{rev};
				print STDERR "current_rev: $current_rev - last_rev: $last_rev\n";
				if ($last_rev > $current_rev) {
					print STDERR "-> setting rev to $last_rev\n";
					$fix_rev_not_incremented_fixed++;
					$product_ref->{rev} = $last_rev;
					compute_product_history_and_completeness($product_ref, $changes_ref);
					compute_data_sources($product_ref);
					store("$data_root/products/$path/changes.sto", $changes_ref);
				}
				else {
					next;
				}
			}
			else {
				next;
			}
		}

		# Fix zulu lang, bug https://github.com/openfoodfacts/openfoodfacts-server/issues/2063

		if ($fix_zulu_lang) {

			# Products that still have "zu" as the main language

			if ($product_ref->{lang} eq "zu") {

				if ($product_ref->{lc} ne "zu") {
					print STDERR "lang zu, lc: " . $product_ref->{lc} . " -- assigning lc value to lang\n";
					$product_ref->{lang} = $product_ref->{lc};
					$product_values_changed = 1;
				}

				# Do we have ingredients text
				foreach my $l ("fr", "de", "it", "es", "nl", "en") {
					if (((defined $product_ref->{"ingredients_text_" . $l}) and ($product_ref->{"ingredients_text_" . $l} ne ""))
						or ((defined $product_ref->{"product_name_" . $l}) and ($product_ref->{"product_name_" . $l} ne ""))) {
						print STDERR "ingredients_text or product_name in $l exists, assigning $l to lang and lc\n";
						$product_ref->{lang} = $l;
						$product_ref->{lc} = $l;
						$product_values_changed = 1;
						last;
					}
				}


				if ($product_values_changed) {
					# For fields that can have different values in different languages, copy the main language value to the non suffixed field

					foreach my $field (keys %language_fields) {
						if ($field !~ /_image/) {

							if (defined $product_ref->{$field . "_" . $product_ref->{lc}}) {
								$product_ref->{$field} = $product_ref->{$field . "_" . $product_ref->{lc}};
							}
						}
					}
				}

			}

			# Products that do not have "zu" as the main language any more (or that were just changed above)

			if ($product_ref->{lang} ne "zu") {

				# Move the zu value to the main language if we don't have a value for the main language
				# otherwise remove the zu value

				foreach my $field (keys %language_fields) {
					if ($field !~ /_image/) {

						if ((defined $product_ref->{$field . "_zu"}) and ( $product_ref->{$field . "_zu"} ne "")) {
							if ((not defined $product_ref->{$field . "_" . $product_ref->{lc}}) or ( $product_ref->{$field . "_" . $product_ref->{lc}} eq "") ) {
								print STDERR "moving zu value to " . $product_ref->{lc} . " for field $field\n";
								$product_ref->{$field . "_" . $product_ref->{lc}} = $product_ref->{$field . "_zu"};
								delete $product_ref->{$field . "_zu"};
							}
							else {
								print STDERR "deleting zu value for field $field - " .  $product_ref->{lc} . " value already exists\n";
								delete $product_ref->{$field . "_zu"};
							}
							$product_values_changed = 1;
						}

						if ((defined $product_ref->{$field . "_zu"}) and ( $product_ref->{$field . "_zu"} eq "")) {
							print STDERR "removing empty zu value for field $field\n";
							delete $product_ref->{$field . "_zu"};
							$product_values_changed = 1;
						}
					}
				}


				# Remove selected "zu" images
				if (defined $product_ref->{images}) {
					foreach my $imgid ("front", "ingredients", "nutrition") {
						if (defined $product_ref->{images}{$imgid . "_zu"}) {
							# Already selected image in correct language? remove the zu selected image
							if (defined $product_ref->{images}{$imgid . "_" . $product_ref->{lc}}) {
								print STDERR "image " . $imgid . "_zu exists, and " . $imgid . "_" . $product_ref->{lc} . " exists too, unselect zu image\n";
								delete $product_ref->{images}{$imgid . "_zu"};
							}
							else {
								print STDERR "image " . $imgid . "_zu exists, and " . $imgid . "_" . $product_ref->{lc} . " does not exist, turn selected zu image to " . $product_ref->{lc} . "\n";
								$product_ref->{images}{$imgid . "_" . $product_ref->{lc}} = $product_ref->{images}{$imgid . "_zu"};
								delete $product_ref->{images}{$imgid . "_zu"};

								# Rename the image file
								my $path =  product_path($code);
								my $rev = $product_ref->{images}{$imgid . "_" . $product_ref->{lc}}{rev};

								use File::Copy "move";
								foreach my $size (100, 200, 400, "full") {
									my $source = "$www_root/images/products/$path/${imgid}_zu.$rev.$size.jpg";
									my $target = "$www_root/images/products/$path/${imgid}_" . $product_ref->{lc} . ".$rev.$size.jpg";
									print STDERR "move $source to $target\n";
									move($source, $target);
								}
							}
							$product_values_changed = 1;
						}
					}
				}

			}
		}

		# Fix products and record if we have changed them so that we can create a new product version and .sto file
		if ($fix_serving_size_mg_to_ml) {

			# do not update the quantity if it is both in ml and mg
			# e.g. 8 ml (240 mg)

			if ((defined $product_ref->{serving_size}) and ($product_ref->{serving_size} =~ /\d\s?mg\b/i)
				and ($product_ref->{serving_size} !~ /sml\b/i)) {

				# if the nutrition data is specified per 100g, just delete the serving size

				if ($product_ref->{nutrition_data_per} eq "100g") {
					print STDERR "code $code deleting serving size " . $product_ref->{serving_size} . "\n";
					delete $product_ref->{serving_size};
					ProductOpener::Food::compute_serving_size_data($product_ref);
					$product_values_changed = 1;
				}

				# if the quantity is in L, ml etc. and the quantity
				# is in mg, we can assume it should be ml instead

				elsif ((defined $product_ref->{quantity}) and ($product_ref->{quantity} =~ /(l|litre|litres|liter|liters)$/i)) {

					print STDERR "code $code changing " . $product_ref->{serving_size} . "\n";
					$product_ref->{serving_size} =~ s/(\d)\s?(mg)\b/$1 ml/i;
					print STDERR "code $code changed to " . $product_ref->{serving_size} . "\n";
					ProductOpener::Food::compute_serving_size_data($product_ref);
					$product_values_changed = 1;
				}
			}
		}

		# Fix products that were created without the lc field, but that have a lang field
		if (($fix_missing_lc) and (not defined $product_ref->{lc})) {
			print STDERR "lang: " . $product_ref->{lang} . "\n";
			if ((defined $product_ref->{lang}) and ($product_ref->{lang} =~ /^[a-z][a-z]$/)) {
				print STDERR "fixing missing lc, using lang: " . $product_ref->{lang} . "\n";
				$product_ref->{lc} = $product_ref->{lang};
				$product_values_changed = 1;
			}
			else {
				print STDERR "fixing missing lc, lang also missing, assigning en";
				$product_ref->{lc} = "en";
				$product_ref->{lang} = "en";
				$product_values_changed = 1;
			}
		}

		# Fix ingredients_n that was set as string
		if (defined $product_ref->{ingredients_n}) {
			$product_ref->{ingredients_n} += 0;
		}

		# Fix nutrient _label fields that were mistakenly set to 0
		# bug https://github.com/openfoodfacts/openfoodfacts-server/issues/772

		# 2019-05-10: done in production, commenting out
		#if (defined $product_ref->{nutriments}) {
		#	foreach my $key (%{$product_ref->{nutriments}}) {
		#		next if $key !~ /^(.*)_label$/;
		#		my $nid = $1;
		#
		#		if ($product_ref->{nutriments}{$key} eq "0") {
		#			$product_ref->{nutriments}{$key} = ucfirst($nid);
		#		}
		#	}
		#}

		if ($run_ocr) {
			# run OCR on all selected ingredients and nutrition
			# images
			if (defined $product_ref->{images}) {
				foreach my $imgid (sort keys %{$product_ref->{images}}) {
					if ((not defined $product_ref->{images}{$imgid}{ocr}) or ($product_ref->{images}{$imgid}{ocr} == 0)) {
						if ($imgid =~ /^ingredients_/) {
							my $results_ref = {};
							print STDERR "extract_ingredients_from_image: $imgid\n";
							extract_ingredients_from_image($product_ref, $imgid, "google_cloud_vision", $results_ref);
						}
						elsif ($imgid =~ /^nutrition_/) {
							my $results_ref = {};
							print STDERR "extract_nutrition_from_image: $imgid\n";
							extract_nutrition_from_image($product_ref, $imgid, "google_cloud_vision", $results_ref);
						}
					}
				}
			}
		}

		if ($autorotate) {
			# OCR needs to have been run first
			if (defined $product_ref->{images}) {
				foreach my $imgid (sort keys %{$product_ref->{images}}) {
					if (($imgid =~ /^(ingredients|nutrition)_/)
						and (defined $product_ref->{images}{$imgid}{orientation}) and ($product_ref->{images}{$imgid}{orientation} != 0)
						# only rotate images that have not been manually cropped
						and ((not defined $product_ref->{images}{$imgid}{x1}) or ($product_ref->{images}{$imgid}{x1} <= 0))
						and ((not defined $product_ref->{images}{$imgid}{y1}) or ($product_ref->{images}{$imgid}{y1} <= 0))
						and ((not defined $product_ref->{images}{$imgid}{x2}) or ($product_ref->{images}{$imgid}{x2} <= 0))
						and ((not defined $product_ref->{images}{$imgid}{y2}) or ($product_ref->{images}{$imgid}{y2} <= 0))
						) {
						print STDERR "rotating image $imgid by " .  (- $product_ref->{images}{$imgid}{orientation}) . "\n";
						my $User_id_copy = $User_id;
						$User_id = "autorotate-bot";

						# Save product so that OCR results now:
						# autorotate may call image_process_crop which will read the product file on disk and
						# write a new one
						store("$data_root/products/$path/product.sto", $product_ref);

						eval {

							# process_image_crops saves a new version of the product
							$product_ref = process_image_crop($code, $imgid, $product_ref->{images}{$imgid}{imgid}, - $product_ref->{images}{$imgid}{orientation}, undef, undef, -1, -1, -1, -1);
						};
						$User_id = $User_id_copy;
					}
				}
			}
		}

		# Update all fields

		foreach my $field (@fields_to_update) {

			if (defined $product_ref->{$field}) {

				if ($field eq 'emb_codes') {
					$product_ref->{emb_codes} = normalize_packager_codes($product_ref->{emb_codes});
				}

				if (defined $taxonomy_fields{$field}) {
					# we do not know the language of the current value of $product_ref->{$field}
					# so regenerate it in the main language of the product
					my $value = display_tags_hierarchy_taxonomy($lc, $field, $product_ref->{$field . "_hierarchy"});
					# Remove tags
					$value =~ s/<(([^>]|\n)*)>//g;

					$product_ref->{$field} = $value;
				}

				compute_field_tags($product_ref, $lc, $field);
			}
			else {
			}
		}

		if ($server_domain =~ /openfoodfacts/) {
				ProductOpener::Food::special_process_product($product_ref);
		}

		if ((defined $product_ref->{nutriments}{"carbon-footprint"}) and ($product_ref->{nutriments}{"carbon-footprint"} ne '')) {
			push @{$product_ref->{"labels_hierarchy" }}, "en:carbon-footprint";
			push @{$product_ref->{"labels_tags" }}, "en:carbon-footprint";
		}


		if ($clean_ingredients) {
			clean_ingredients_text($product_ref);
		}


		if ($process_ingredients) {
			# Ingredients classes
			extract_ingredients_from_text($product_ref);
			extract_ingredients_classes_from_text($product_ref);
			compute_nova_group($product_ref);
			compute_languages($product_ref); # need languages for allergens detection
			detect_allergens_from_text($product_ref);
		}

		if ($compute_data_sources) {
			compute_data_sources($product_ref);
		}

		if ($compute_nova) {

			extract_ingredients_from_text($product_ref);
			compute_nova_group($product_ref);
		}

		if ($compute_nutrition_score) {
			fix_salt_equivalent($product_ref);
			compute_nutrition_score($product_ref);
			compute_nutrient_levels($product_ref);
		}

		if ($compute_codes) {
			compute_codes($product_ref);
		}

		if ($compute_carbon) {
			compute_carbon_footprint_from_ingredients($product_ref);
			compute_carbon_footprint_from_meat_or_fish($product_ref);
			compute_serving_size_data($product_ref);
			delete $product_ref->{environment_infocard};
			delete $product_ref->{environment_infocard_en};
			delete $product_ref->{environment_infocard_fr};
		}

		if ($compute_serving_size) {
			ProductOpener::Food::compute_serving_size_data($product_ref);
		}

		if ($check_quality) {
			ProductOpener::SiteQuality::check_quality($product_ref);
		}

		if (($compute_history) or ((defined $User_id) and ($User_id ne '') and ($product_values_changed))) {
			my $changes_ref = retrieve("$data_root/products/$path/changes.sto");
			if (not defined $changes_ref) {
				$changes_ref = [];
			}

			compute_product_history_and_completeness($product_ref, $changes_ref);
			compute_data_sources($product_ref);
			store("$data_root/products/$path/changes.sto", $changes_ref);
		}

		if (not $pretend) {
			$product_ref->{update_key} = $key;

			# Create a new version of the product and create a new .sto file
			# Useful when we actually change a value entered by a user
			if ((defined $User_id) and ($User_id ne '') and ($product_values_changed)) {
				store_product($product_ref, "update_all_products.pl - " . $comment );
				$m++;
			}

			# Otherwise, we silently update the .sto file of the last version
			else {

				# make sure nutrient values are numbers
				ProductOpener::Products::make_sure_numbers_are_stored_as_numbers($product_ref);

				store("$data_root/products/$path/product.sto", $product_ref);

				# Make sure product code is saved as string and not a number
				# see bug #1077 - https://github.com/openfoodfacts/openfoodfacts-server/issues/1077
				# make sure that code is saved as a string, otherwise mongodb saves it as number, and leading 0s are removed
				$product_ref->{code} = $product_ref->{code} . '';
				$products_collection->replace_one({"_id" => $product_ref->{_id}}, $product_ref, { upsert => 1 });
			}
		}

		$n++;
	}

}

print "$n products updated (pretend: $pretend) - $m new versions created\n";

if ($fix_rev_not_incremented_fixed) {
	print "$fix_rev_not_incremented_fixed rev fixed\n";
}

exit(0);

