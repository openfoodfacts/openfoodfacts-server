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
--query some_field=-some_value	match products that don't have some_value for some_field
--process-ingredients	compute allergens, additives detection
--clean-ingredients	remove nutrition facts, conservation conditions etc.
--compute-nutriscore	nutriscore
--compute-serving-size	compute serving size values
--compute-history	compute history and completeness
--check-quality	run quality checks
--compute-codes
--fix-serving-size-mg-to-ml
--index		specifies that the keywords used by the free text search function (name, brand etc.) need to be reindexed. -- TBD
--user		create a separate .sto file and log the change in the product history, with the corresponding user
--team		optional team for the user that is credited with the change
--comment	comment for change in product history
--pretend	do not actually update products
--mongodb-to-mongodb	do not use the .sto files at all, and only read from and write to mongodb
TXT
	;

use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/:all/;
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
use ProductOpener::DataQuality qw/:all/;
use ProductOpener::Data qw/:all/;
use ProductOpener::Ecoscore qw(:all);
use ProductOpener::Packaging qw(:all);
use ProductOpener::ForestFootprint qw(:all);
use ProductOpener::MainCountries qw(:all);
use ProductOpener::PackagerCodes qw/:all/;
use ProductOpener::API qw/:all/;
use ProductOpener::LoadData qw/:all/;
use ProductOpener::Redis qw/push_to_redis_stream/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;
use Data::DeepAccess qw(deep_get deep_exists deep_set);
use Data::Compare;

use Log::Any::Adapter 'TAP';

use Getopt::Long;

my @fields_to_update = ();
my $key;
my $index = '';
my $count = '';
my $just_print_codes = '', my $pretend = '';
my $process_ingredients = '';
my $process_packagings = '';
my $clean_ingredients = '';
my $compute_nutriscore = '';
my $compute_serving_size = '';
my $compute_data_sources = '';
my $compute_nova = '';
my $check_quality = '';
my $compute_codes = '';
my $compute_carbon = '';
my $compute_history = '';
my $compute_sort_key = '';
my $comment = '';
my $fix_serving_size_mg_to_ml = '';
my $fix_missing_lc = '';
my $fix_zulu_lang = '';
my $fix_rev_not_incremented = '';
my $fix_yuka_salt = '';
my $run_ocr = '';
my $autorotate = '';
my $remove_team = '';
my $remove_label = '';
my $remove_category = '';
my $remove_nutrient = '';
my $remove_old_carbon_footprint = '';
my $fix_spanish_ingredientes = '';
my $team = '';
my $assign_categories_properties = '';
my $restore_values_deleted_by_user = '';
my $delete_debug_tags = '';
my $all_owners = '';
my $mark_as_obsolete_since_date = '';
my $reassign_energy_kcal = '';
my $delete_old_fields = '';
my $mongodb_to_mongodb = '';
my $compute_ecoscore = '';
my $compute_forest_footprint = '';
my $fix_nutrition_data_per = '';
my $fix_nutrition_data = '';
my $compute_main_countries = '';
my $prefix_packaging_tags_with_language = '';
my $fix_non_string_ids = '';
my $assign_ciqual_codes = '';
my $obsolete = 0;
my $fix_obsolete;

my $query_ref = {};    # filters for mongodb query

GetOptions(
	"key=s" => \$key,    # string
	"query=s%" => $query_ref,
	"count" => \$count,
	"just-print-codes" => \$just_print_codes,
	"fields=s" => \@fields_to_update,
	"index" => \$index,
	"pretend" => \$pretend,
	"clean-ingredients" => \$clean_ingredients,
	"process-ingredients" => \$process_ingredients,
	"process-packagings" => \$process_packagings,
	"assign-categories-properties" => \$assign_categories_properties,
	"compute-nutriscore" => \$compute_nutriscore,
	"compute-history" => \$compute_history,
	"compute-serving-size" => \$compute_serving_size,
	"reassign-energy-kcal" => \$reassign_energy_kcal,
	"compute-data-sources" => \$compute_data_sources,
	"compute-nova" => \$compute_nova,
	"compute-codes" => \$compute_codes,
	"compute-carbon" => \$compute_carbon,
	"compute-ecoscore" => \$compute_ecoscore,
	"compute-forest-footprint" => \$compute_forest_footprint,
	"check-quality" => \$check_quality,
	"compute-sort-key" => \$compute_sort_key,
	"fix-serving-size-mg-to-ml" => \$fix_serving_size_mg_to_ml,
	"fix-missing-lc" => \$fix_missing_lc,
	"fix-zulu-lang" => \$fix_zulu_lang,
	"fix-rev-not-incremented" => \$fix_rev_not_incremented,
	"fix-non-string-ids" => \$fix_non_string_ids,
	"user-id=s" => \$User_id,
	"comment=s" => \$comment,
	"run-ocr" => \$run_ocr,
	"autorotate" => \$autorotate,
	"fix-yuka-salt" => \$fix_yuka_salt,
	"remove-team=s" => \$remove_team,
	"remove-label=s" => \$remove_label,
	"remove-category=s" => \$remove_category,
	"remove-nutrient=s" => \$remove_nutrient,
	"remove-old-carbon-footprint" => \$remove_old_carbon_footprint,
	"fix-spanish-ingredientes" => \$fix_spanish_ingredientes,
	"team=s" => \$team,
	"restore-values-deleted-by-user=s" => \$restore_values_deleted_by_user,
	"delete-debug-tags" => \$delete_debug_tags,
	"mark-as-obsolete-since-date=s" => \$mark_as_obsolete_since_date,
	"all-owners" => \$all_owners,
	"delete-old-fields" => \$delete_old_fields,
	"mongodb-to-mongodb" => \$mongodb_to_mongodb,
	"fix-nutrition-data-per" => \$fix_nutrition_data_per,
	"fix-nutrition-data" => \$fix_nutrition_data,
	"compute-main-countries" => \$compute_main_countries,
	"prefix-packaging-tags-with-language" => \$prefix_packaging_tags_with_language,
	"assign-ciqual-codes" => \$assign_ciqual_codes,
	"obsolete" => \$obsolete,
	"fix-obsolete" => \$fix_obsolete,
) or die("Error in command line arguments:\n\n$usage");

use Data::Dumper;

print Dumper(\@fields_to_update);

@fields_to_update = split(/,/, join(',', @fields_to_update));

print Dumper(\@fields_to_update);

if ((defined $team) and ($team ne "")) {
	$User{"team_1"} = $team;
}

print "Updating fields: " . join(", ", @fields_to_update) . "\n\n";

my $unknown_fields = 0;

foreach my $field (@fields_to_update) {
	if (    (not defined $tags_fields{$field})
		and (not defined $taxonomy_fields{$field}))
	{
		print "Unknown field: $field\n";
		$unknown_fields++;
	}
}

if ($unknown_fields > 0) {
	die("Unknown fields, check for typos.");
}

if (    (not $process_ingredients)
	and (not $compute_nutriscore)
	and (not $compute_nova)
	and (not $clean_ingredients)
	and (not $delete_old_fields)
	and (not $compute_serving_size)
	and (not $reassign_energy_kcal)
	and (not $compute_data_sources)
	and (not $compute_history)
	and (not $run_ocr)
	and (not $autorotate)
	and (not $fix_missing_lc)
	and (not $fix_serving_size_mg_to_ml)
	and (not $fix_zulu_lang)
	and (not $fix_rev_not_incremented)
	and (not $fix_yuka_salt)
	and (not $fix_spanish_ingredientes)
	and (not $fix_nutrition_data_per)
	and (not $fix_nutrition_data)
	and (not $fix_non_string_ids)
	and (not $compute_sort_key)
	and (not $remove_team)
	and (not $remove_category)
	and (not $remove_label)
	and (not $remove_nutrient)
	and (not $remove_old_carbon_footprint)
	and (not $mark_as_obsolete_since_date)
	and (not $compute_main_countries)
	and (not $assign_categories_properties)
	and (not $restore_values_deleted_by_user)
	and (not $delete_debug_tags)
	and (not $compute_codes)
	and (not $compute_carbon)
	and (not $compute_ecoscore)
	and (not $compute_forest_footprint)
	and (not $process_packagings)
	and (not $check_quality)
	and (scalar @fields_to_update == 0)
	and (not $count)
	and (not $just_print_codes)
	and (not $prefix_packaging_tags_with_language)
	and (not $assign_ciqual_codes)
	and (not $fix_obsolete))
{
	die("Missing fields to update or --count option:\n$usage");
}

# Make sure we have a user id and we will use a new .sto file for all edits that change values entered by users
if ((not defined $User_id) and (($fix_serving_size_mg_to_ml) or ($fix_missing_lc))) {
	die(
		"Missing --user-id. We must have a user id and we will use a new .sto file for all edits that change values entered by users.\n"
	);
}

load_data();

# Get a list of all products not yet updated
# Use query filters entered using --query categories_tags=en:plant-milks

use boolean;

foreach my $field (sort keys %{$query_ref}) {

	my $not = 0;

	if ($query_ref->{$field} =~ /^-/) {
		$query_ref->{$field} = $';
		$not = 1;
	}

	if ($query_ref->{$field} eq 'null') {
		# $query_ref->{$field} = { '$exists' => false };
		$query_ref->{$field} = undef;
	}
	elsif ($query_ref->{$field} eq 'exists') {
		$query_ref->{$field} = {'$exists' => true};
	}
	elsif ($field =~ /_t$/) {    # created_t, last_modified_t etc.
		$query_ref->{$field} += 0;
	}
	# Multiple values separated by commas
	elsif ($query_ref->{$field} =~ /,/) {
		my @tagids = split(/,/, $query_ref->{$field});

		if ($not) {
			$query_ref->{$field} = {'$nin' => \@tagids};
		}
		else {
			$query_ref->{$field} = {'$in' => \@tagids};
		}
	}
	elsif ($not) {
		$query_ref->{$field} = {'$ne' => $query_ref->{$field}};
	}
}

# Query products that have the _id field stored as a number
if ($fix_non_string_ids) {
	$query_ref->{_id} = {'$type' => "long"};
}

# On the producers platform, require --query owners_tags to be set, or the --all-owners field to be set.

if ((defined $server_options{private_products}) and ($server_options{private_products})) {
	if ((not $all_owners) and (not defined $query_ref->{owners_tags})) {
		print STDERR "On producers platform, --query owners_tags=... or --all-owners must be set.\n";
		exit();
	}
}

if ((defined $remove_team) and ($remove_team ne "")) {
	$query_ref->{teams_tags} = $remove_team;
}

if ((defined $remove_label) and ($remove_label ne "")) {
	$query_ref->{labels_tags} = $remove_label;
}

if ((defined $remove_category) and ($remove_category ne "")) {
	$query_ref->{categories_tags} = $remove_category;
}

if (defined $key) {
	$query_ref->{update_key} = {'$ne' => "$key"};
}
else {
	$key = "key_" . time();
}

# $query_ref->{unknown_nutrients_tags} = { '$exists' => true,  '$ne' => [] };

print STDERR "Update key: $key\n\n";

use Data::Dumper;
print STDERR "MongoDB query:\n" . Dumper($query_ref);

my $socket_timeout_ms = 2 * 60000;    # 2 mins, instead of 30s default, to not die as easily if mongodb is busy.

# Collection that will be used to iterate products
my $products_collection = get_products_collection({obsolete => $obsolete, timeout => $socket_timeout_ms});

# Collections for saving current / obsolete products
my %products_collections = (
	current => get_products_collection({timeout => $socket_timeout_ms}),
	obsolete => get_products_collection({obsolete => $obsolete, timeout => $socket_timeout_ms}),
);

my $products_count = "";

eval {
	$products_count = $products_collection->count_documents($query_ref);

	print STDERR "$products_count documents to update.\n";
};

if ($count) {exit(0);}

my $cursor;
if ($mongodb_to_mongodb) {
	# retrieve all fields
	$cursor = $products_collection->query($query_ref);
}
else {
	# only retrieve important fields
	$cursor = $products_collection->query($query_ref)->fields({_id => 1, code => 1, owner => 1});
}
$cursor->immortal(1);

my $l = 0;    # number of products tested
my $n = 0;    # number of products updated
my $m = 0;    # number of products with a new version created

my $fix_rev_not_incremented_fixed = 0;
my $fix_obsolete_fixed = 0;

# Used to get stats on fields deleted by an user
my %deleted_fields = ();

my $nutrition_data_per_n = 0;
my $nutrition_data_n = 0;

# Stats for --prefix-packaging-tags-with-language

my $prefix_packaging_already_prefixed = 0;
my $prefix_packaging_language_found = 0;
my $prefix_packaging_language_not_found = 0;

my %prefix_packaging_tags = ();
my %prefix_packaging_tags_language = ();
my %prefix_packaging_tags_properties = ();
my %prefix_packaging_tags_product_languages = ();

if ($prefix_packaging_tags_with_language) {
	init_packaging_taxonomies_regexps();
}

while (my $product_ref = $cursor->next) {
	$l++;

	# Response structure to keep track of warnings and errors
	# Note: currently some warnings and errors are added,
	# but we do not yet do anything with them
	my $response_ref = get_initialized_response();

	my $productid = $product_ref->{_id};
	my $code = $product_ref->{code};
	my $path = product_path($product_ref);

	my $owner_info = "";
	if (defined $product_ref->{owner}) {
		$owner_info = "- owner: " . $product_ref->{owner} . " ";
	}

	if (not defined $code) {
		print STDERR "\ncode field undefined for product id: " . $product_ref->{id} . " _id: " . $product_ref->{_id};
	}
	else {
		print STDERR "\nupdating product code: $code $owner_info ($l / $products_count)";
	}

	next if $just_print_codes;

	if (!$mongodb_to_mongodb) {
		# read product data from .sto file
		$product_ref = retrieve_product($productid);
	}

	if ((defined $product_ref) and ($productid ne '')) {
		my $original_product = dclone($product_ref);

		$lc = $product_ref->{lc};

		my $product_values_changed = 0;

		if ($delete_old_fields) {

			foreach my $field (
				qw(
				additives_old_n
				categories_properties
				ingredients_debug
				ingredients_ids_debug
				sortkey
				)
				)
			{

				defined $product_ref->{$field} and delete $product_ref->{$field};
			}
		}

		# Prefix untaxonomized packaging tags values with the most likely language
		# Skip products that have already been taxonomized (products which have a packaging_hierarchy field)
		if (    $prefix_packaging_tags_with_language
			and (defined $product_ref->{packaging})
			and ($product_ref->{packaging} ne '')
			and (not defined $product_ref->{packaging_hierarchy}))
		{
			my $current_packaging = $product_ref->{packaging};
			my @new_tags = ();
			foreach my $tag (split(/,/, $current_packaging)) {
				$tag =~ s/\s+$//g;
				$tag =~ s/^\s+//g;
				my $new_tag = $tag;
				# skip tags that are already prefixed with a a language
				if ($tag =~ /^[a-z]{2}:/) {
					$prefix_packaging_already_prefixed++;
				}
				else {
					# first try the language of the product, then languages that are the most represented on OFF
					my @potential_languages = (
						$product_ref->{lc}, "fr", "en", "de", "es", "it", "nl", "pt", "pl", "se", "ar", "cz", "ro",
						"bg", "nb", "da", "ru", "hu", "ca"
					);
					my $l = guess_language_of_packaging_text($tag, \@potential_languages);
					my $properties = "unrecognized_properties";

					if (defined $l) {
						$new_tag = $l . ':' . $tag;
						$prefix_packaging_language_found++;
						my $packaging_ref = parse_packaging_from_text_phrase($tag, $l);
						$properties
							= "shape: "
							. ($packaging_ref->{shape} // "unknown")
							. " - material: "
							. ($packaging_ref->{material} // "unknown")
							. " - recycling: "
							. ($packaging_ref->{recycling} // "unknown");
					}
					else {
						$prefix_packaging_language_not_found++;
					}

					# statistics: keep track of the language found and of the properties extracted
					deep_set(\%prefix_packaging_tags_properties, $tag, $properties);
					deep_set(\%prefix_packaging_tags_language, $tag, $l // "unrecognized_language");

					# statistics: increment a counter for the tag
					my $count = deep_get(\%prefix_packaging_tags, $tag) // 0;
					deep_set(\%prefix_packaging_tags, $tag, $count + 1);

					# statistics: increment a counter for each product language for the tag
					my $language_count = deep_get(\%prefix_packaging_tags_product_languages, $tag, $product_ref->{lc})
						// 0;
					deep_set(\%prefix_packaging_tags_product_languages, $tag, $product_ref->{lc}, $language_count + 1);
				}
				push @new_tags, $new_tag;
			}
			my $new_packaging = join(',', @new_tags);
			if ($new_packaging ne $current_packaging) {
				$product_ref->{packaging} = $new_packaging;
				$product_ref->{packaging_old_before_taxonomization} = $current_packaging;
				compute_field_tags($product_ref, $product_ref->{lc}, "packaging");
				$product_values_changed = 1;
			}
		}

		if ((defined $remove_team) and ($remove_team ne "")) {
			remove_tag($product_ref, "teams", $remove_team);
			$product_ref->{teams} = join(',', @{$product_ref->{teams_tags}});
		}

		if ((defined $remove_label) and ($remove_label ne "")) {
			remove_tag($product_ref, "labels", $remove_label);
			$product_ref->{labels} = join(',', @{$product_ref->{labels_tags}});
			compute_field_tags($product_ref, $product_ref->{lc}, "labels");
		}

		if ((defined $remove_category) and ($remove_category ne "")) {
			remove_tag($product_ref, "categories", $remove_category);
			$product_ref->{categories} = join(',', @{$product_ref->{categories_tags}});
			compute_field_tags($product_ref, $product_ref->{lc}, "categories");
		}

		if ((defined $remove_nutrient) and ($remove_nutrient ne "")) {
			if (defined $product_ref->{nutriments}) {
				delete $product_ref->{nutriments}{$remove_nutrient};
				delete $product_ref->{nutriments}{$remove_nutrient . "_value"};
				delete $product_ref->{nutriments}{$remove_nutrient . "_unit"};
				delete $product_ref->{nutriments}{$remove_nutrient . "_100g"};
				delete $product_ref->{nutriments}{$remove_nutrient . "_serving"};
				$product_values_changed = 1;
			}
		}

		if ($remove_old_carbon_footprint) {
			my @product_fields_to_delete = (
				"environment_impact_level", "environment_impact_level_tags",
				"environment_infocard", "environment_infocard_en",
				"environment_infocard_fr", "carbon_footprint_from_known_ingredients_debug",
				"carbon_footprint_from_meat_or_fish_debug"
			);
			remove_fields($product_ref, \@product_fields_to_delete);

			if (defined $product_ref->{nutriments}) {
				delete $product_ref->{nutriments}{"carbon-footprint-from-known-ingredients_100g"};
				delete $product_ref->{nutriments}{"carbon-footprint-from-meat-or-fish"};
				delete $product_ref->{nutriments}{"carbon-footprint-from-meat-or-fish_100g"};
				delete $product_ref->{nutriments}{"carbon-footprint-from-meat-or-fish_serving"};
				delete $product_ref->{nutriments}{"carbon-footprint-from-meat-or-fish_product"};
			}

			remove_tag($product_ref, "misc", "en:environment-infocard");
			remove_tag($product_ref, "misc", "en:carbon-footprint-from-known-ingredients");
			remove_tag($product_ref, "misc", "en:carbon-footprint-from-meat-or-fish");
		}

		# Some Spanish products had their ingredients list wrongly cut after "Ingredientes"
		# before: Brócoli*. (* Ingredientes procedentes de la agricultura ecológica). Categoría I.
		# after: procedentes de la agricultura ecológica). Categoría I.

		if (    ($fix_spanish_ingredientes)
			and (defined $product_ref->{ingredients_text_es})
			and ($product_ref->{ingredients_text_es} ne ""))
		{
			my $current_ingredients = $product_ref->{ingredients_text_es};
			my $length_current_ingredients = length($product_ref->{ingredients_text_es});

			my $rev = $product_ref->{rev} - 1;
			while ($rev >= 1) {
				my $rev_product_ref = retrieve("$BASE_DIRS{PRODUCTS}/$path/$rev.sto");
				if ((defined $rev_product_ref) and (defined $rev_product_ref->{ingredients_text_es})) {
					my $rindex = rindex($rev_product_ref->{ingredients_text_es}, $current_ingredients);

					if (    ($rindex > 15)
						and ($rindex == length($rev_product_ref->{ingredients_text_es}) - $length_current_ingredients)
						and (substr($rev_product_ref->{ingredients_text_es}, $rindex - 13, 13) =~ /^ingredientes $/i))
					{
						# print $rev_product_ref->{ingredients_text_es} . "\n" . $current_ingredients . "\n\n";
						$product_ref->{ingredients_text_es} = $rev_product_ref->{ingredients_text_es};
						if ($product_ref->{lc} eq "es") {
							$product_ref->{ingredients_text} = $product_ref->{ingredients_text_es};
						}
						$product_values_changed = 1;
						extract_ingredients_from_text($product_ref);
						extract_ingredients_classes_from_text($product_ref);
						compute_nova_group($product_ref);
						compute_languages($product_ref);    # need languages for allergens detection
						detect_allergens_from_text($product_ref);
						last;
					}
				}
				$rev--;
			}
		}

		# Fix for nutrition_data_per / nutrition_data_prepared_per field that was set to "100.0 g" or "240 g" by Equadis import
		if ($fix_nutrition_data_per) {

			foreach my $type ("", "_prepared") {

				my $nutrition_data_per_field = "nutrition_data" . $type . "_per";
				if (    (defined $product_ref->{$nutrition_data_per_field})
					and ($product_ref->{$nutrition_data_per_field} ne ""))
				{

					my $nutrition_data_per_value = $product_ref->{$nutrition_data_per_field};

					# Apps and the web product edit form on OFF always send "100g" or "serving" in the nutrition_data_per fields
					# but imports from GS1 / Equadis can have values like "100.0 g" or "240.0 grm"

					# 100.00g -> 100g
					$nutrition_data_per_value =~ s/(\d)(\.|,)0?0?([^0-9])/$1$3/;
					$nutrition_data_per_value =~ s/(grammes|grams|gr)\b/g/ig;

					# 100 g or 100 ml -> assign to the per 100g value
					if ($nutrition_data_per_value =~ /^100\s?(g|ml)$/i) {
						$nutrition_data_per_value = "100g";
					}
					# otherwise -> assign the per serving value, and assign serving size
					else {
						if (   (not defined $product_ref->{serving_size})
							or ($product_ref->{serving_size} ne $product_ref->{$nutrition_data_per_field}))
						{
							$product_ref->{serving_size} = $product_ref->{$nutrition_data_per_field};
							$product_values_changed = 1;
						}
						$nutrition_data_per_value = "serving";
					}

					if ($product_ref->{$nutrition_data_per_field} ne $nutrition_data_per_value) {
						print STDERR "owner:  "
							. $product_ref->{owner}
							. " - $nutrition_data_per_field - old: "
							. $product_ref->{$nutrition_data_per_field}
							. " - new: $nutrition_data_per_value\n";
						$product_ref->{$nutrition_data_per_field} = $nutrition_data_per_value;
						$product_values_changed = 1;
						$nutrition_data_per_n++;
					}
				}
			}
		}

		# Fix nutrition data checkbox: if we have nutrition data, check the checkbox
		if ($fix_nutrition_data) {
			if (defined $product_ref->{nutriments}) {
				foreach my $type ("", "_prepared") {
					if (    (defined $product_ref->{"nutrition_data" . $type})
						and ($product_ref->{"nutrition_data" . $type} eq '')
						and (defined $product_ref->{nutriments}{"energy" . $type . "_100g"}))
					{
						$product_ref->{"nutrition_data" . $type} = "on";
						$product_values_changed = 1;
						$nutrition_data_n++;
					}
				}
			}
		}

		if ($fix_rev_not_incremented) {    # https://github.com/openfoodfacts/openfoodfacts-server/issues/2321

			my $changes_ref = retrieve("$BASE_DIRS{PRODUCTS}/$path/changes.sto");
			if (defined $changes_ref) {
				my $change_ref = $changes_ref->[-1];
				my $last_rev = $change_ref->{rev};
				my $current_rev = $product_ref->{rev};
				print STDERR "current_rev: $current_rev - last_rev: $last_rev\n";
				if ($last_rev > $current_rev) {
					print STDERR "-> setting rev to $last_rev\n";
					$fix_rev_not_incremented_fixed++;
					$product_ref->{rev} = $last_rev;
					my $blame_ref = {};
					compute_product_history_and_completeness($data_root, $product_ref, $changes_ref, $blame_ref);
					compute_data_sources($product_ref, $changes_ref);
					store("$BASE_DIRS{PRODUCTS}/$path/changes.sto", $changes_ref);
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
					if (
						(
								(defined $product_ref->{"ingredients_text_" . $l})
							and ($product_ref->{"ingredients_text_" . $l} ne "")
						)
						or (    (defined $product_ref->{"product_name_" . $l})
							and ($product_ref->{"product_name_" . $l} ne ""))
						)
					{
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

						if ((defined $product_ref->{$field . "_zu"}) and ($product_ref->{$field . "_zu"} ne "")) {
							if (   (not defined $product_ref->{$field . "_" . $product_ref->{lc}})
								or ($product_ref->{$field . "_" . $product_ref->{lc}} eq ""))
							{
								print STDERR "moving zu value to " . $product_ref->{lc} . " for field $field\n";
								$product_ref->{$field . "_" . $product_ref->{lc}} = $product_ref->{$field . "_zu"};
								delete $product_ref->{$field . "_zu"};
							}
							else {
								print STDERR "deleting zu value for field $field - "
									. $product_ref->{lc}
									. " value already exists\n";
								delete $product_ref->{$field . "_zu"};
							}
							$product_values_changed = 1;
						}

						if ((defined $product_ref->{$field . "_zu"}) and ($product_ref->{$field . "_zu"} eq "")) {
							print STDERR "removing empty zu value for field $field\n";
							delete $product_ref->{$field . "_zu"};
							$product_values_changed = 1;
						}
					}
				}

				# Remove selected "zu" images
				if (defined $product_ref->{images}) {
					foreach my $imgid ("front", "ingredients", "nutrition", "packaging") {
						if (defined $product_ref->{images}{$imgid . "_zu"}) {
							# Already selected image in correct language? remove the zu selected image
							if (defined $product_ref->{images}{$imgid . "_" . $product_ref->{lc}}) {
								print STDERR "image "
									. $imgid
									. "_zu exists, and "
									. $imgid . "_"
									. $product_ref->{lc}
									. " exists too, unselect zu image\n";
								delete $product_ref->{images}{$imgid . "_zu"};
							}
							else {
								print STDERR "image "
									. $imgid
									. "_zu exists, and "
									. $imgid . "_"
									. $product_ref->{lc}
									. " does not exist, turn selected zu image to "
									. $product_ref->{lc} . "\n";
								$product_ref->{images}{$imgid . "_" . $product_ref->{lc}}
									= $product_ref->{images}{$imgid . "_zu"};
								delete $product_ref->{images}{$imgid . "_zu"};

								# Rename the image file
								my $path = product_path($code);
								my $rev = $product_ref->{images}{$imgid . "_" . $product_ref->{lc}}{rev};

								require File::Copy;
								foreach my $size (100, 200, 400, "full") {
									my $source = "$BASE_DIRS{PRODUCTS_IMAGES}/$path/${imgid}_zu.$rev.$size.jpg";
									my $target
										= "$BASE_DIRS{PRODUCTS_IMAGES}/$path/${imgid}_"
										. $product_ref->{lc}
										. ".$rev.$size.jpg";
									print STDERR "move $source to $target\n";
									File::Copy::move($source, $target);
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

			if (    (defined $product_ref->{serving_size})
				and ($product_ref->{serving_size} =~ /\d\s?mg\b/i)
				and ($product_ref->{serving_size} !~ /sml\b/i))
			{

				# if the nutrition data is specified per 100g, just delete the serving size

				if ($product_ref->{nutrition_data_per} eq "100g") {
					print STDERR "code $code deleting serving size " . $product_ref->{serving_size} . "\n";
					delete $product_ref->{serving_size};
					ProductOpener::Food::compute_serving_size_data($product_ref);
					$product_values_changed = 1;
				}

				# if the quantity is in L, ml etc. and the quantity
				# is in mg, we can assume it should be ml instead

				elsif ( (defined $product_ref->{quantity})
					and ($product_ref->{quantity} =~ /(l|litre|litres|liter|liters)$/i))
				{

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

		if (($fix_missing_lc) and (not defined $product_ref->{lang})) {
			print STDERR "lc: " . $product_ref->{lc} . "\n";
			if ((defined $product_ref->{lc}) and ($product_ref->{lc} =~ /^[a-z][a-z]$/)) {
				print STDERR "fixing missing lang, using lc: " . $product_ref->{lc} . "\n";
				$product_ref->{lang} = $product_ref->{lc};
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
					if ((not defined $product_ref->{images}{$imgid}{ocr}) or ($product_ref->{images}{$imgid}{ocr} == 0))
					{
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
					if (
							($imgid =~ /^(ingredients|nutrition)_/)
						and (defined $product_ref->{images}{$imgid}{orientation})
						and ($product_ref->{images}{$imgid}{orientation} != 0)
						# only rotate images that have not been manually cropped
						and
						((not defined $product_ref->{images}{$imgid}{x1}) or ($product_ref->{images}{$imgid}{x1} <= 0))
						and
						((not defined $product_ref->{images}{$imgid}{y1}) or ($product_ref->{images}{$imgid}{y1} <= 0))
						and
						((not defined $product_ref->{images}{$imgid}{x2}) or ($product_ref->{images}{$imgid}{x2} <= 0))
						and
						((not defined $product_ref->{images}{$imgid}{y2}) or ($product_ref->{images}{$imgid}{y2} <= 0))
						)
					{
						print STDERR "rotating image $imgid by "
							. (-$product_ref->{images}{$imgid}{orientation}) . "\n";

						# Save product so that OCR results now:
						# autorotate may call image_process_crop which will read the product file on disk and
						# write a new one
						store("$BASE_DIRS{PRODUCTS}/$path/product.sto", $product_ref);

						eval {

							# process_image_crops saves a new version of the product
							$product_ref = process_image_crop(
								"autorotate-bot", $code, $imgid,
								$product_ref->{images}{$imgid}{imgid},
								-$product_ref->{images}{$imgid}{orientation},
								undef, undef, -1, -1, -1, -1, "full"
							);
						};
					}
				}
			}
		}

		# Update all fields

		foreach my $field (@fields_to_update) {

			if (defined $product_ref->{$field}) {

				# Keep a copy of the existing value, in case something bad happens
				$product_ref->{$field . "_old"} = $product_ref->{$field};

				if ($field eq 'emb_codes') {
					$product_ref->{emb_codes} = normalize_packager_codes($product_ref->{emb_codes});
				}

				if (
					(defined $taxonomy_fields{$field})
					# if the field was previously not taxonomized, the $field_hierarchy field does not exist
					# assume the $field value is in the main language of the product
					and (defined $product_ref->{$field . "_hierarchy"})
					)
				{
					# we do not know the language of the current value of $product_ref->{$field}
					# so regenerate it in the main language of the product

					$product_ref->{$field}
						= list_taxonomy_tags_in_language($lc, $field, $product_ref->{$field . "_hierarchy"});
				}

				compute_field_tags($product_ref, $lc, $field);
				if ($product_ref->{$field} ne $product_ref->{$field . "_old"}) {
					$product_values_changed = 1;
				}
			}
			else {
			}
		}

		if ((defined $options{product_type}) and ($options{product_type} eq "food")) {
			ProductOpener::Food::special_process_product($product_ref);
		}
		if ($assign_categories_properties) {
			# assign_categories_properties_to_product() is already called by special_process_product
		}

		if (    (defined $product_ref->{nutriments}{"carbon-footprint"})
			and ($product_ref->{nutriments}{"carbon-footprint"} ne ''))
		{
			push @{$product_ref->{"labels_hierarchy"}}, "en:carbon-footprint";
			push @{$product_ref->{"labels_tags"}}, "en:carbon-footprint";
		}

		if ($clean_ingredients) {
			clean_ingredients_text($product_ref);
		}

		if ($process_ingredients) {
			# Ingredients classes
			extract_ingredients_from_text($product_ref);
			extract_ingredients_classes_from_text($product_ref);
			compute_nova_group($product_ref);
			compute_languages($product_ref);    # need languages for allergens detection
			detect_allergens_from_text($product_ref);
		}

		if ($compute_data_sources) {
			my $changes_ref = retrieve("$BASE_DIRS{PRODUCTS}/$path/changes.sto");
			if (not defined $changes_ref) {
				$changes_ref = [];
			}
			compute_data_sources($product_ref, $changes_ref);
		}

		if ($compute_nova) {

			extract_ingredients_from_text($product_ref);
			compute_nova_group($product_ref);
		}

		if ($compute_nutriscore) {
			$product_ref->{misc_tags} = [];
			fix_salt_equivalent($product_ref);
			compute_nutriscore($product_ref);
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

		# Fix energy-kcal values so that energy-kcal and energy-kcal/100g is stored in kcal instead of kJ
		if ($reassign_energy_kcal) {
			foreach my $product_type ("", "_prepared") {

				# see bug https://github.com/openfoodfacts/openfoodfacts-server/issues/3561
				# for details

				if (defined $product_ref->{nutriments}{"energy-kcal" . $product_type}) {
					if (not defined $product_ref->{nutriments}{"energy-kcal" . $product_type . "_unit"}) {
						$product_ref->{nutriments}{"energy-kcal" . $product_type . "_unit"} = "kcal";
					}
					# Reassign so that the energy-kcal field is recomputed
					assign_nid_modifier_value_and_unit(
						$product_ref,
						"energy-kcal" . $product_type,
						$product_ref->{nutriments}{"energy-kcal" . $product_type . "_modifier"},
						$product_ref->{nutriments}{"energy-kcal" . $product_type . "_value"},
						$product_ref->{nutriments}{"energy-kcal" . $product_type . "_unit"}
					);
				}
			}
			ProductOpener::Food::compute_serving_size_data($product_ref);
		}

		if ($compute_serving_size) {
			ProductOpener::Food::compute_serving_size_data($product_ref);
		}

		if ($check_quality) {
			ProductOpener::DataQuality::check_quality($product_ref);
		}

		if ($fix_yuka_salt) {    # https://github.com/openfoodfacts/openfoodfacts-server/issues/2945
			my $blame_ref = {};

			my $changes_ref = retrieve("$BASE_DIRS{PRODUCTS}/$path/changes.sto");
			compute_product_history_and_completeness($data_root, $product_ref, $changes_ref, $blame_ref);

			if (
					(defined $blame_ref->{nutriments})
				and (defined $blame_ref->{nutriments}{salt})
				and ($blame_ref->{nutriments}{salt}{userid} eq 'kiliweb')
				and ($blame_ref->{nutriments}{salt}{value} < 0.1)
				and ($blame_ref->{nutriments}{salt}{t} > 1579478400)    # Jan 20th 2020
				)
			{

				$User_id = "fix-salt-bot";

				print STDERR "salt : " . $blame_ref->{nutriments}{salt}{value} . "\n";
				push @{$product_ref->{data_quality_warnings_tags}}, "en:yuka-salt-bug-last-salt-edit-by-yuka";

				my $salt_value_changed = 0;

				if (    (defined $blame_ref->{nutriments}{salt}{previous_value})
					and ($blame_ref->{nutriments}{salt}{value} < $blame_ref->{nutriments}{salt}{previous_value} / 100))
				{

					push @{$product_ref->{data_quality_tags}}, "en:yuka-salt-bug-salt-value-divided-by-more-than-100";
					$salt_value_changed = 1;
				}
				else {

					if ($blame_ref->{nutriments}{salt}{value} < 0.001) {
						push @{$product_ref->{data_quality_tags}}, "en:yuka-salt-bug-new-salt-value-less-than-0-001-g";
						$salt_value_changed = 1;
					}
					elsif ($blame_ref->{nutriments}{salt}{value} < 0.01) {
						push @{$product_ref->{data_quality_tags}}, "en:yuka-salt-bug-new-salt-value-less-than-0-01-g";
						$salt_value_changed = 1;
					}
					elsif ($blame_ref->{nutriments}{salt}{value} < 0.1) {
						push @{$product_ref->{data_quality_tags}}, "en:yuka-salt-bug-new-salt-value-less-than-0-1-g";
					}
				}

				if ($salt_value_changed) {
					# Float issue, we can get things like 0.18000001, convert back to string and remove extra digit
					# also 0.00999999925 or 0.00089999995
					my $salt = $product_ref->{nutriments}{salt_value};
					if ($salt =~ /\.(\d*?[1-9]\d*?)0{2}/) {
						$salt = $` . '.' . $1;
					}
					if ($salt =~ /\.(\d+)([0-8]+)9999/) {
						$salt = $` . '.' . $1 . ($2 + 1);
					}
					$salt = $salt * 1000;
					# The divided by 1000 value may have been of the form 9.99999925e-06: try again
					if ($salt =~ /\.(\d*?[1-9]\d*?)0{2}/) {
						$salt = $` . '.' . $1;
					}
					if ($salt =~ /\.(\d+)([0-8]+)9999/) {
						$salt = $` . '.' . $1 . ($2 + 1);
					}
					$comment = "changing salt value from " . $product_ref->{nutriments}{salt_value} . " to " . $salt;

					assign_nid_modifier_value_and_unit($product_ref, 'salt',
						$product_ref->{nutriments}{'salt_modifier'},
						$salt, $product_ref->{nutriments}{'salt_unit'});

					fix_salt_equivalent($product_ref);
					compute_serving_size_data($product_ref);
					compute_nutriscore($product_ref);
					compute_nutrient_levels($product_ref);
					$product_values_changed = 1;
				}
			}
		}

		if (0) {    # fix float numbers for salt
			if ((defined $product_ref->{nutriments}) and ($product_ref->{nutriments}{salt_value})) {

				my $salt = $product_ref->{nutriments}{salt_value};
				if ($salt =~ /\.(\d*?[1-9]\d*?)0{2}/) {
					$salt = $` . '.' . $1;
				}
				if ($salt =~ /\.(\d+)([0-8]+)9999/) {
					$salt = $` . '.' . $1 . ($2 + 1);
				}

				assign_nid_modifier_value_and_unit($product_ref, 'salt', $product_ref->{nutriments}{'salt_modifier'},
					$salt, $product_ref->{nutriments}{'salt_unit'});

				fix_salt_equivalent($product_ref);
				compute_serving_size_data($product_ref);
				compute_nutriscore($product_ref);
				compute_nutrient_levels($product_ref);
			}
		}

		if ($process_packagings) {
			analyze_and_combine_packaging_data($product_ref, $response_ref);
		}

		if ($compute_ecoscore) {
			compute_ecoscore($product_ref);
		}

		if ($compute_forest_footprint) {
			compute_forest_footprint($product_ref);
		}

		if ($compute_main_countries) {
			compute_main_countries($product_ref);
		}

		if (($compute_history) or ((defined $User_id) and ($User_id ne '') and ($product_values_changed))) {
			my $changes_ref = retrieve("$BASE_DIRS{PRODUCTS}/$path/changes.sto");
			if (not defined $changes_ref) {
				$changes_ref = [];
			}
			my $blame_ref = {};
			compute_product_history_and_completeness($data_root, $product_ref, $changes_ref, $blame_ref);
			compute_data_sources($product_ref, $changes_ref);
			store("$BASE_DIRS{PRODUCTS}/$path/changes.sto", $changes_ref);
		}

		if ($restore_values_deleted_by_user) {
			my $changes_ref = retrieve("$BASE_DIRS{PRODUCTS}/$path/changes.sto");
			if (not defined $changes_ref) {
				$changes_ref = [];
			}

			# Go through all revisions, keep the latest value of all fields

			my %deleted_values = ();
			my $previous_rev_product_ref = {};
			my $revs = 0;

			foreach my $change_ref (@{$changes_ref}) {
				$revs++;
				my $rev = $change_ref->{rev};
				if (not defined $rev) {
					$rev = $revs;    # was not set before June 2012
				}

				my $rev_product_ref = retrieve("$BASE_DIRS{PRODUCTS}/$path/$rev.sto");

				if (defined $rev_product_ref) {

					if ((defined $change_ref->{userid}) and ($change_ref->{userid} eq $restore_values_deleted_by_user))
					{

						foreach my $field (sort keys %{$previous_rev_product_ref}) {

							next if $field =~ /debug/;
							next if $field =~ /_n$/;
							next
								if $field
								=~ /^(ingredients_percent|nova|nutriscore|pnns|nutrition|ingredients_text_with_allergens)/;
							next if not defined $previous_rev_product_ref->{$field};
							next
								if ref($previous_rev_product_ref->{$field}) ne
								"";    # if it is not a reference, it is a scalar
							next if $previous_rev_product_ref->{$field} eq "";

							if ((not defined $rev_product_ref->{$field}) or ($rev_product_ref->{$field} eq "")) {
								# print to STDOUT so that we can do further processing (e.g. grep etc.)
								print "product code $code - deleted value for field $field : "
									. $previous_rev_product_ref->{$field} . "\n";
								$deleted_values{$field} = $previous_rev_product_ref->{$field};
								defined $deleted_fields{$field} or $deleted_fields{$field} = 0;
								$deleted_fields{$field}++;
							}
						}
					}
					$previous_rev_product_ref = $rev_product_ref;
				}
			}

			if ((scalar keys %deleted_values) == 0) {
				next;
			}

			foreach my $field (sort keys %deleted_values) {
				if ((not defined $product_ref->{$field}) or ($product_ref->{$field} eq "")) {
					$product_ref->{$field} = $deleted_values{$field};
					if (defined $tags_fields{$field}) {
						compute_field_tags($product_ref, $product_ref->{lc}, $field);
					}
					$product_values_changed = 1;
				}
			}
		}

		# Delete old debug tags (many were created by error)
		if ($delete_debug_tags) {
			foreach my $field (sort keys %{$product_ref}) {
				if ($field =~ /_(debug|prev|next)_tags/) {
					delete $product_ref->{$field};
				}
			}
		}

		if ($compute_sort_key) {
			compute_sort_keys($product_ref);
		}

		if ($mark_as_obsolete_since_date) {
			if ((not defined $product_ref->{obsolete}) or (not $product_ref->{obsolete})) {
				$product_ref->{obsolete} = "on";
				$product_ref->{obsolete_since_date} = $mark_as_obsolete_since_date;
				$product_values_changed = 1;
			}
		}

		if ($assign_ciqual_codes) {
			assign_ciqual_codes($product_ref);
		}

		my $any_change = $product_values_changed;
		if (not $pretend) {
			if (!$any_change) {
				# Deep compare with original (if we don't already know that a change has been made)
				$any_change = !Compare($product_ref, $original_product);
			}
			if (!$any_change) {
				print STDERR ". Skipped";
			}
		}

		if ($any_change) {
			$product_ref->{update_key} = $key;

			# Create a new version of the product and create a new .sto file
			# Useful when we actually change a value entered by a user
			if ((defined $User_id) and ($User_id ne '') and ($product_values_changed)) {
				store_product($User_id, $product_ref, "update_all_products.pl - " . $comment);
				$m++;
			}

			# Otherwise, we silently update the .sto file of the last version
			else {
				# make sure nutrient values are numbers
				ProductOpener::Products::make_sure_numbers_are_stored_as_numbers($product_ref);

				# Make sure product _id and code are saved as string and not a number
				# see bug #1077 - https://github.com/openfoodfacts/openfoodfacts-server/issues/1077
				# make sure that code is saved as a string, otherwise mongodb saves it as number, and leading 0s are removed
				$product_ref->{_id} .= '';
				$product_ref->{code} .= '';

				# Set last modified time
				$product_ref->{last_modified_t} = time() + 0;

				# Send to redis
				push_to_redis_stream('update_all_products', $product_ref, "updated", $comment, {});

				if (!$mongodb_to_mongodb) {
					# Store data to .sto file
					store("$BASE_DIRS{PRODUCTS}/$path/product.sto", $product_ref);
				}

				# Store data to mongodb
				my $collection = "current";
				if ($product_ref->{obsolete}) {
					$collection = "obsolete";
				}
				$products_collections{$collection}
					->replace_one({"_id" => $product_ref->{_id}}, $product_ref, {upsert => 1});

				# If the obsolete flag of the product does not
				# correspond to the collection we are iterating over
				# delete the product from the collection
				if (
					$fix_obsolete
					and (  ($obsolete and not $product_ref->{obsolete})
						or ((not $obsolete) and $product_ref->{obsolete}))
					)
				{
					$products_collection->delete_one({"_id" => $product_ref->{_id}});
					$fix_obsolete_fixed++;
				}
			}

			$n++;
		}
	}
	else {
		print STDERR ". Unable to load product file for product code $code";
	}
}

print STDERR "\n";

if ($prefix_packaging_tags_with_language) {

	print "Results of --prefixy-packaging-tags-with-language:\n\n";

	# List all packaging tags
	foreach my $tag (sort {$prefix_packaging_tags{$a} <=> $prefix_packaging_tags{$b}} keys %prefix_packaging_tags) {

		next if ($prefix_packaging_tags_language{$tag} ne "unrecognized_language");

		print $tag . "\t"
			. $prefix_packaging_tags{$tag} . "\t"
			. $prefix_packaging_tags_language{$tag} . "\t"
			. $prefix_packaging_tags_properties{$tag} . "\t";

		# List the main languages of the products associated with the tag
		foreach my $l (
			sort {
				$prefix_packaging_tags_product_languages{$tag}{$b}
					<=> $prefix_packaging_tags_product_languages{$tag}{$a}
			} keys %{$prefix_packaging_tags_product_languages{$tag}}
			)
		{
			print $l . ' ' . $prefix_packaging_tags_product_languages{$tag}{$l} . ', ';
		}

		print "\n";
	}

	print "\n";

	print "stats for --prefix-packaging-tags-with-language\n\n";
	print "prefix_packaging_already_prefixed: $prefix_packaging_already_prefixed" . "\n";
	print "prefix_packaging_language_found: $prefix_packaging_language_found" . "\n";
	print "prefix_packaging_language_not_found: $prefix_packaging_language_not_found" . "\n" . "\n";
}

print "$n products updated (pretend: $pretend) - $m new versions created\n";

if ($fix_obsolete_fixed) {
	print "$fix_obsolete_fixed removed from wrong collection (obsolete or current)\n";
}

if ($fix_rev_not_incremented_fixed) {
	print "$fix_rev_not_incremented_fixed rev fixed\n";
}

if ($fix_nutrition_data_per) {
	print $nutrition_data_per_n . " nutrition_data_per fixed\n";
}

if ($fix_nutrition_data) {
	print $nutrition_data_n . " nutrition_data fixed\n";
}

if ($restore_values_deleted_by_user) {

	print STDERR "\n\ndeleted fields:\n";
	foreach my $field (sort keys %deleted_fields) {
		print STDERR "$deleted_fields{$field}\t$field\n";
	}
}

if ($fix_non_string_ids) {
	print STDERR
		"\nproducts stored in MongoDB with a non string _id have been reloaded from .sto files (if the products still exist) and stored with a string _id.\n";
	print STDERR "products with non string ids can now be deleted from MongoDB with this command:"
		. 'db.products.remove({_id : { $type : "long" }})' . "\n";
}

exit(0);
