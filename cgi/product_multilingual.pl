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

use CGI::Carp qw(fatalsToBrowser);

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
use ProductOpener::URL qw/:all/;
use ProductOpener::DataQuality qw/:all/;
use ProductOpener::Ecoscore qw/:all/;
use ProductOpener::Packaging qw/:all/;
use ProductOpener::ForestFootprint qw/:all/;

use Apache2::RequestRec ();
use Apache2::Const ();

use CGI qw/:cgi :form escapeHTML :cgi-lib/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;
use Log::Any qw($log);
use File::Copy qw(move);
use Data::Dumper;

ProductOpener::Display::init();

if ($User_id eq 'unwanted-user-french') {
	display_error("<b>Il y a des problèmes avec les modifications de produits que vous avez effectuées. Ce compte est temporairement bloqué, merci de nous contacter.</b>", 403);
}


my $type = param('type') || 'search_or_add';
my $action = param('action') || 'display';

my $comment = 'Modification : ';

my @errors = ();

$admin = 1;

my $html = '';
my $code = normalize_code(param('code'));
my $product_id;

my $product_ref = undef;

my $interface_version = '20190830';

local $log->context->{type} = $type;
local $log->context->{action} = $action;

my $template_data_ref = {};

# Search or add product
if ($type eq 'search_or_add') {

	# barcode in image?
	my $filename;
	if ((not defined $code) or ($code eq "")) {
		$code = process_search_image_form(\$filename);
	}
	elsif ($code !~ /^\d{4,24}$/) {
		display_error($Lang{invalid_barcode}{$lang}, 403);
	}

	my $r = Apache2::RequestUtil->request();
	my $method = $r->method();
	if ((not defined $code) and ((not defined param("imgupload_search")) or ( param("imgupload_search") eq '')) and ($method eq 'POST')) {

		($code, $product_id) = assign_new_code();
	}

	my %data = ();
	my $location;



	if (defined $code) {
		$data{code} = $code;
		$product_id = product_id_for_owner($Owner_id, $code);
		$log->debug("we have a code", { code => $code, product_id => $product_id }) if $log->is_debug();

		$product_ref = product_exists($product_id); # returns 0 if not

		if ($product_ref) {
			$log->info("product exists, redirecting to page", { code => $code }) if $log->is_info();
			$location = product_url($product_ref);

			# jquery.fileupload ?
			if (param('jqueryfileupload')) {

				$type = 'show';
			}
			else {
				my $r = shift;
				$r->headers_out->set(Location =>$location);
				$r->status(301);
				return 301;
			}
		}
		else {
			$log->info("product does not exist, creating product", { code => $code, product_id => $product_id }) if $log->is_info();
			$product_ref = init_product($User_id, $Org_id, $code, $country);
			$product_ref->{interface_version_created} = $interface_version;
			store_product($User_id, $product_ref, 'product_created');

			$type = 'add';
			$action = 'display';
			$location = "/cgi/product.pl?type=add&code=$code";

			# If we got a barcode image, upload it
			if (defined $filename) {
				my $imgid;
				my $debug;
				process_image_upload($product_ref->{_id},$filename,$User_id, time(),'image with barcode from web site Add product button',\$imgid, \$debug);
			}
		}
	}
	else {
		if (defined param("imgupload_search")) {
			$log->info("no code found in image") if $log->is_info();
			$data{error} = lang("image_upload_error_no_barcode_found_in_image_short");
		}
		else {
			$log->info("no code found in text") if $log->is_info();
		}
	}

	$data{type} = $type;
	$data{location} = $location;

	# jquery.fileupload ?
	if (param('jqueryfileupload')) {

		my $data = encode_json(\%data);

		$log->debug("jqueryfileupload JSON data output", { data => $data }) if $log->is_debug();

		print header( -type => 'application/json', -charset => 'utf-8' ) . $data;
		exit();
	}

	$template_data_ref->{param_imgupload_search} = param("imgupload_search");

}

else {
	# We should have a code
	if ((not defined $code) or ($code eq '')) {
		display_error($Lang{missing_barcode}{$lang}, 403);
	}
	elsif ($code !~ /^\d{4,24}$/) {
		display_error($Lang{invalid_barcode}{$lang}, 403);
	}
	else {
		if ( ((defined $server_options{private_products}) and ($server_options{private_products}))
			and (not defined $Owner_id)) {

			display_error(lang("no_owner_defined"), 200);
		}
		$product_id = product_id_for_owner($Owner_id, $code);
		$product_ref = retrieve_product_or_deleted_product($product_id, $User{moderator});
		if (not defined $product_ref) {
			display_error(sprintf(lang("no_product_for_barcode"), $code), 404);
		}
	}
}

if (($type eq 'delete') and (not $User{moderator})) {
	display_error($Lang{error_no_permission}{$lang}, 403);
}

if ($User_id eq 'unwanted-bot-id') {
	my $r = Apache2::RequestUtil->request();
	$r->status(500);
	return 500;
}

if (($type eq 'add') or ($type eq 'edit') or ($type eq 'delete')) {

	if (not defined $User_id) {

		my $submit_label = "login_and_" .$type . "_product";
		$action = 'login';
		$template_data_ref->{type} = $type;
	}
}

$template_data_ref->{user_id} =  $User_id;
$template_data_ref->{code} = $code;
process_template('web/pages/product_edit/product_edit_form.tt.html', $template_data_ref, \$html) or $html = "<p>" . $tt->error() . "</p>";

my @fields = @ProductOpener::Config::product_fields;

if ($admin) {
	push @fields, "environment_impact_level";

	# Let admins edit any other fields
	if (defined param("fields")) {
		push @fields, split(/,/, param("fields"));
	}

}

if (($action eq 'process') and (($type eq 'add') or ($type eq 'edit'))) {

	# Process edit rules

	$log->debug("phase 0 - checking edit rules", { code => $code, type => $type }) if $log->is_debug();

	my $proceed_with_edit = process_product_edit_rules($product_ref);

	$log->debug("phase 0", { code => $code, type => $type, proceed_with_edit => $proceed_with_edit }) if $log->is_debug();

	if (not $proceed_with_edit) {

		display_error("Edit against edit rules", 403);
	}

	$log->debug("phase 1", { code => $code, type => $type }) if $log->is_debug();

	exists $product_ref->{new_server} and delete $product_ref->{new_server};

	# 26/01/2017 - disallow barcode changes until we fix bug #677
	if ($User{moderator} and (defined param("new_code")) and (param("new_code") ne "")) {

		change_product_server_or_code($product_ref, param("new_code"), \@errors);
		$code = $product_ref->{code};
	}

	my @param_fields = ();

	my @param_sorted_langs = ();
	my %param_sorted_langs = ();
	if (defined param("sorted_langs")) {
		foreach my $display_lc (split(/,/, param("sorted_langs"))) {
			if ($display_lc =~ /^\w\w$/) {
				push @param_sorted_langs, $display_lc;
				$param_sorted_langs{$display_lc} = 1;
			}
		}
	}
	else {
		push @param_sorted_langs, $product_ref->{lc};
	}

	# Make sure we have the main language of the product (which could be new)
	# needed if we are moving data from one language to the main language
	if ((defined param("lang")) and (param("lang") =~ /^\w\w$/) and (not defined $param_sorted_langs{param("lang")} )) {
		push @param_sorted_langs, param("lang");
	}

	$product_ref->{"debug_param_sorted_langs"} = \@param_sorted_langs;

	foreach my $field ('product_name', 'generic_name', @fields, 'nutrition_data_per', 'nutrition_data_prepared_per', 'serving_size', 'allergens', 'traces', 'ingredients_text', 'packaging_text', 'lang') {

		if (defined $language_fields{$field}) {
			foreach my $display_lc (@param_sorted_langs) {
				push @param_fields, $field . "_" . $display_lc;
			}
		}
		else {
			push @param_fields, $field;
		}
	}

	# Move all data and photos from one language to another?
	if ($User{moderator}) {

		my $product_lc = param("lang");

		foreach my $from_lc (@param_sorted_langs) {

			my $moveid = "move_" . $from_lc . "_data_and_images_to_main_language";

			if (($from_lc ne $product_lc) and (defined param($moveid)) and (param($moveid) eq "on")) {

				my $mode = param($moveid . "_mode") || "replace";

				$log->debug("moving all data and photos from one language to another",
					{ from_lc => $from_lc, product_lc => $product_lc, mode => $mode }) if $log->is_debug();

				# Text fields

				foreach my $field (sort keys %language_fields) {

					my $from_field = $field . "_" . $from_lc;
					my $to_field = $field . "_" . $product_lc;

					my $from_value = param($from_field);

					$log->debug("moving field value?",
							{ from_field => $from_field, from_value => $from_value, to_field => $to_field }) if $log->is_debug();

					if ((defined $from_value) and ($from_value ne "")) {

						my $to_value = param($to_field);

						$log->debug("moving field value",
							{ from_field => $from_field, from_value => $from_value, to_field => $to_field, to_value => $to_value, mode => $mode }) if $log->is_debug();

						if (($mode eq "replace") or ((not defined $to_value) or ($to_value eq ""))) {

							$log->debug("replacing to field value",
								{ from_field => $from_field, from_value => $from_value, to_field => $to_field, to_value => $to_value, mode => $mode }) if $log->is_debug();

							param($to_field, $from_value);
						}

						$log->debug("deleting from field value",
							{ from_field => $from_field, from_value => $from_value, to_field => $to_field, to_value => $to_value, mode => $mode }) if $log->is_debug();

						param($from_field, "");
					}
				}

				# Selected photos

				foreach my $imageid ("front", "ingredients", "nutrition") {

					my $from_imageid = $imageid . "_" . $from_lc;
					my $to_imageid = $imageid . "_" . $product_lc;

					if ((defined $product_ref->{images}) and (defined $product_ref->{images}{$from_imageid})) {

						$log->debug("moving selected image",
							{ from_imageid => $from_imageid, to_imageid => $to_imageid }) if $log->is_debug();


						if (($mode eq "replace") or (not defined $product_ref->{images}{$to_imageid})) {

							$product_ref->{images}{$to_imageid} = $product_ref->{images}{$from_imageid};
							my $rev = $product_ref->{images}{$from_imageid}{rev};

							# Rename the images

							my $path = product_path($product_ref);

							foreach my $max ($thumb_size, $small_size, $display_size, "full") {
								my $from_file = "$www_root/images/products/$path/" . $from_imageid . "." . $rev . "." . $max . ".jpg";
								my $to_file = "$www_root/images/products/$path/" . $to_imageid . "." . $rev . "." . $max . ".jpg";
								File::Copy::move($from_file, $to_file);
							}
						}

						delete $product_ref->{images}{$from_imageid};
					}
				}
			}
		}
	}


	foreach my $field (@param_fields) {

		if (defined param($field)) {

			# If we are on the public platform, and the field data has been imported from the producer platform
			# ignore the field changes for non tag fields, unless made by a moderator
			if (((not defined $server_options{private_products}) or (not $server_options{private_products}))
				and (defined $product_ref->{owner_fields}) and (defined $product_ref->{owner_fields}{$field})
				and (not $User{moderator})) {
				$log->debug("skipping field with a value set by the owner",
					{ code => $code, field_name => $field, existing_field_value => $product_ref->{$field},
					new_field_value => remove_tags_and_quote(decode utf8=>param($field))}) if $log->is_debug();
			}

			if ($field eq "lang") {
				my $value = remove_tags_and_quote(decode utf8=>param($field));
				
				# strip variants fr-BE fr_BE
				$value =~ s/^([a-z][a-z])(-|_).*$/$1/i;
				$value = lc($value);
				
				# skip unrecognized languages (keep the existing lang & lc value)
				if (defined $lang_lc{$value}) {
					$product_ref->{lang} = $value;
					$product_ref->{lc} = $value;
				}				
				
			}
			else {
				# infocards set by admins can contain HTML
				if (($admin) and ($field =~ /infocard/)) {
					$product_ref->{$field} = decode utf8=>param($field);
				}
				else {
					$product_ref->{$field} = remove_tags_and_quote(decode utf8=>param($field));
				}
			}

			$log->debug("before compute field_tags", { code => $code, field_name => $field, field_value => $product_ref->{$field}}) if $log->is_debug();
			if ($field =~ /ingredients_text/) {
				# the ingredients_text_with_allergens[_$lc] will be recomputed after
				my $ingredients_text_with_allergens = $field;
				$ingredients_text_with_allergens =~ s/ingredients_text/ingredients_text_with_allergens/;
				delete $product_ref->{$ingredients_text_with_allergens};
			}

			compute_field_tags($product_ref, $lc, $field);

		}
		else {
			$log->debug("could not find field in params", { field => $field }) if $log->is_debug();
		}
	}

	if ((defined $product_ref->{nutriments}{"carbon-footprint"}) and ($product_ref->{nutriments}{"carbon-footprint"} ne '')) {
		push @{$product_ref->{"labels_hierarchy" }}, "en:carbon-footprint";
		push @{$product_ref->{"labels_tags" }}, "en:carbon-footprint";
	}

	if ((defined $product_ref->{nutriments}{"glycemic-index"}) and ($product_ref->{nutriments}{"glycemic-index"} ne '')) {
		push @{$product_ref->{"labels_hierarchy" }}, "en:glycemic-index";
		push @{$product_ref->{"labels_tags" }}, "en:glycemic-index";
	}

	# For fields that can have different values in different languages, copy the main language value to the non suffixed field

	foreach my $field (keys %language_fields) {
		if ($field !~ /_image/) {
			if (defined $product_ref->{$field . "_$product_ref->{lc}"}) {
				$product_ref->{$field} = $product_ref->{$field . "_$product_ref->{lc}"};
			}
		}
	}

	$log->debug("compute_languages") if $log->is_debug();

	compute_languages($product_ref); # need languages for allergens detection and cleaning ingredients
	$log->debug("clean_ingredients") if $log->is_debug();

	# Ingredients classes
	clean_ingredients_text($product_ref);
	$log->debug("extract_ingredients_from_text") if $log->is_debug();
	extract_ingredients_from_text($product_ref);
	$log->debug("extract_ingredients_classes_from_text") if $log->is_debug();
	extract_ingredients_classes_from_text($product_ref);
	$log->debug("detect_allergens_from_text") if $log->is_debug();
	detect_allergens_from_text($product_ref);
	compute_carbon_footprint_from_ingredients($product_ref);
	compute_carbon_footprint_from_meat_or_fish($product_ref);
	
	# Food category rules for sweeetened/sugared beverages
	# French PNNS groups from categories

	if ((defined $options{product_type}) and ($options{product_type} eq "food")) {
		$log->debug("Food::special_process_product") if $log->is_debug();
		ProductOpener::Food::special_process_product($product_ref);
	}	

	# Nutrition data

	$log->debug("Nutrition data") if $log->is_debug();

	my $params_ref = Vars;

	# FIXME : there is no way to know if we get an unchecked value because the field was not there, or if the box is unchecked
	# the browser does not send anything when a box is unchecked...
	# this is an issue because we can't have the API check or uncheck a box

	$product_ref->{no_nutrition_data} = remove_tags_and_quote(decode utf8=>param("no_nutrition_data"));

	$product_ref->{nutrition_data} = remove_tags_and_quote(decode utf8=>param("nutrition_data"));

	$product_ref->{nutrition_data_prepared} = remove_tags_and_quote(decode utf8=>param("nutrition_data_prepared"));

	if (($User{moderator} or $Owner_id) and (defined param('obsolete_since_date'))) {
		$product_ref->{obsolete} = remove_tags_and_quote(decode utf8=>param("obsolete"));
		$product_ref->{obsolete_since_date} = remove_tags_and_quote(decode utf8=>param("obsolete_since_date"));
	}


	defined $product_ref->{nutriments} or $product_ref->{nutriments} = {};

	my @unknown_nutriments = ();
	my %seen_unknown_nutriments = ();
	foreach my $nid (keys %{$product_ref->{nutriments}}) {

		next if (($nid =~ /_/) and ($nid !~ /_prepared$/)) ;

		$nid =~ s/_prepared$//;

		if ((not exists $Nutriments{$nid}) and (defined $product_ref->{nutriments}{$nid . "_label"})
			and (not defined $seen_unknown_nutriments{$nid})) {
			push @unknown_nutriments, $nid;
			$log->debug("unknown_nutriment", { nid => $nid }) if $log->is_debug();
		}
	}

	my @new_nutriments = ();
	my $new_max = remove_tags_and_quote(param('new_max'));
	for (my $i = 1; $i <= $new_max; $i++) {
		push @new_nutriments, "new_$i";
	}

	# fix_salt_equivalent always prefers the 'salt' value of the product by default
	# the 'sodium' value should be preferred, though, if the 'salt' parameter is not
	# present. Therefore, delete the 'salt' value and let it be fixed by
	# fix_salt_equivalent afterwards.
	foreach my $product_type ("", "_prepared") {
		my $saltnid = "salt${product_type}";
		my $sodiumnid = "sodium${product_type}";

		my $salt = param("nutriment_${saltnid}");
		my $sodium = param("nutriment_${sodiumnid}");

		if (((not defined $salt) or ($salt eq ''))
			and (defined $sodium) and ($sodium ne ''))
		{
			delete $product_ref->{nutriments}{$saltnid};
			delete $product_ref->{nutriments}{$saltnid . "_unit"};
			delete $product_ref->{nutriments}{$saltnid . "_value"};
			delete $product_ref->{nutriments}{$saltnid . "_modifier"};
			delete $product_ref->{nutriments}{$saltnid . "_label"};
			delete $product_ref->{nutriments}{$saltnid . "_100g"};
			delete $product_ref->{nutriments}{$saltnid . "_serving"};
		}
	}

	foreach my $nutriment (@{$nutriments_tables{$nutriment_table}}, @unknown_nutriments, @new_nutriments) {
		next if $nutriment =~ /^\#/;

		my $nid = $nutriment;
		$nid =~ s/^(-|!)+//g;
		$nid =~ s/-$//g;

		next if $nid =~ /^nutrition-score/;

		my $enid = encodeURIComponent($nid);

		# for prepared product
		my $nidp = $nid . "_prepared";
		my $enidp = encodeURIComponent($nidp);

		# do not delete values if the nutriment is not provided
		next if ((not defined param("nutriment_${enid}")) and (not defined param("nutriment_${enidp}"))) ;

		my $value = remove_tags_and_quote(decode utf8=>param("nutriment_${enid}"));
		my $valuep = remove_tags_and_quote(decode utf8=>param("nutriment_${enidp}"));
		my $unit = remove_tags_and_quote(decode utf8=>param("nutriment_${enid}_unit"));
		my $label = remove_tags_and_quote(decode utf8=>param("nutriment_${enid}_label"));

		# energy: (see bug https://github.com/openfoodfacts/openfoodfacts-server/issues/2396 )
		# 1. if energy-kcal or energy-kj is set, delete existing energy data
		if (($nid eq "energy-kj") or ($nid eq "energy-kcal")) {
			delete $product_ref->{nutriments}{"energy"};
			delete $product_ref->{nutriments}{"energy_unit"};
			delete $product_ref->{nutriments}{"energy_label"};
			delete $product_ref->{nutriments}{"energy_value"};
			delete $product_ref->{nutriments}{"energy_modifier"};
			delete $product_ref->{nutriments}{"energy_100g"};
			delete $product_ref->{nutriments}{"energy_serving"};
			delete $product_ref->{nutriments}{"energy_prepared_value"};
			delete $product_ref->{nutriments}{"energy_prepared_modifier"};
			delete $product_ref->{nutriments}{"energy_prepared_100g"};
			delete $product_ref->{nutriments}{"energy_prepared_serving"};
		}
		# 2. if the nid passed is just energy, set instead energy-kj or energy-kcal using the passed unit
		elsif (($nid eq "energy") and ((lc($unit) eq "kj") or (lc($unit) eq "kcal"))) {
			$nid = $nid . "-" . lc($unit);
			$nidp = $nid . "_prepared";
			$log->debug("energy without unit, set nid with unit instead", { nid => $nid, unit => $unit }) if $log->is_debug();
		}

		if ($nid eq 'alcohol') {
			$unit = '% vol';
		}

		my $modifier = undef;
		my $modifierp = undef;

		(defined $value) and normalize_nutriment_value_and_modifier(\$value, \$modifier);
		(defined $valuep) and normalize_nutriment_value_and_modifier(\$valuep, \$modifierp);

		$log->debug("prepared nutrient info", { nid => $nid, value => $value, nidp => $nidp, valuep => $valuep, unit => $unit }) if $log->is_debug();

		# New label?
		my $new_nid = undef;
		if ((defined $label) and ($label ne '')) {
			$new_nid = canonicalize_nutriment($lc,$label);
			$log->debug("unknown nutrient", { nid => $nid, lc => $lc, canonicalize_nutriment => $new_nid }) if $log->is_debug();

			if ($new_nid ne $nid) {
				delete $product_ref->{nutriments}{$nid};
				delete $product_ref->{nutriments}{$nid . "_unit"};
				delete $product_ref->{nutriments}{$nid . "_label"};
				delete $product_ref->{nutriments}{$nid . "_value"};
				delete $product_ref->{nutriments}{$nid . "_modifier"};
				delete $product_ref->{nutriments}{$nid . "_100g"};
				delete $product_ref->{nutriments}{$nid . "_serving"};
				delete $product_ref->{nutriments}{$nid . "_prepared_value"};
				delete $product_ref->{nutriments}{$nid . "_prepared_modifier"};
				delete $product_ref->{nutriments}{$nid . "_prepared_100g"};
				delete $product_ref->{nutriments}{$nid . "_prepared_serving"};
				$log->debug("unknown nutrient", { nid => $nid, lc => $lc, known_nid => $new_nid }) if $log->is_debug();
				$nid = $new_nid;
				$nidp = $new_nid . "_prepared";
			}
			$product_ref->{nutriments}{$nid . "_label"} = $label;
		}

		if (defined param("nutriment_${enid}")) {
			if (($nid eq '') or (not defined $value) or ($value eq '')) {
					delete $product_ref->{nutriments}{$nid};
					delete $product_ref->{nutriments}{$nid . "_modifier"};
					delete $product_ref->{nutriments}{$nid . "_100g"};
					delete $product_ref->{nutriments}{$nid . "_serving"};
			}
			else {
				assign_nid_modifier_value_and_unit($product_ref, $nid, $modifier, $value, $unit);
			}
		}

		if (defined param("nutriment_${enidp}")) {
			if (($nid eq '') or (not defined $valuep) or ($valuep eq '')) {
					delete $product_ref->{nutriments}{$nidp};
					delete $product_ref->{nutriments}{$nidp . "_modifier"};
					delete $product_ref->{nutriments}{$nidp . "_100g"};
					delete $product_ref->{nutriments}{$nidp . "_serving"};
			}
			else {
				assign_nid_modifier_value_and_unit($product_ref, $nidp, $modifierp, $valuep, $unit);
			}
		}

		if (($nid eq '') or (not defined $value) or ($value eq '')) {
			delete $product_ref->{nutriments}{$nid . "_value"};
			delete $product_ref->{nutriments}{$nid . "_modifier"};
		}

		if (($nid eq '') or (not defined $valuep) or ($valuep eq '')) {
			delete $product_ref->{nutriments}{$nidp . "_value"};
			delete $product_ref->{nutriments}{$nidp . "_modifier"};
		}

		if (($nid eq '') or
			(((not defined $value) or ($value eq '')) and ((not defined $valuep) or ($valuep eq ''))))  {
				delete $product_ref->{nutriments}{$nid . "_unit"};
				delete $product_ref->{nutriments}{$nid . "_label"};
		}

	}

	# product check

	if ($User{moderator}) {

		my $checked = remove_tags_and_quote(decode utf8=>param("photos_and_data_checked"));
		if ((defined $checked) and ($checked eq 'on')) {
			if ((defined $product_ref->{checked}) and ($product_ref->{checked} eq 'on')) {
				my $rechecked = remove_tags_and_quote(decode utf8=>param("photos_and_data_rechecked"));
				if ((defined $rechecked) and ($rechecked eq 'on')) {
					$product_ref->{last_checker} = $User_id;
					$product_ref->{last_checked_t} = time();
				}
			}
			else {
				$product_ref->{checked} = 'on';
				$product_ref->{last_checker} = $User_id;
				$product_ref->{last_checked_t} = time();
			}
		}
		else {
			delete $product_ref->{checked};
			delete $product_ref->{last_checker};
			delete $product_ref->{last_checked_t};
		}

	}

	# Compute nutrition data per 100g and per serving

	$log->debug("compute nutrition data") if $log->is_debug();

	$log->trace("compute_serving_size_date - start") if $log->is_trace();

	fix_salt_equivalent($product_ref);

	compute_serving_size_data($product_ref);

	compute_nutrition_score($product_ref);

	compute_nova_group($product_ref);

	compute_nutrient_levels($product_ref);

	compute_unknown_nutrients($product_ref);
	
	# Until we provide an interface to directly change the packaging data structure
	# erase it before reconstructing it
	# (otherwise there is no way to remove incorrect entries)
	$product_ref->{packagings} = [];	
	
	analyze_and_combine_packaging_data($product_ref);
	
	if ((defined $options{product_type}) and ($options{product_type} eq "food")) {
		compute_ecoscore($product_ref);
		compute_forest_footprint($product_ref);
	}

	ProductOpener::DataQuality::check_quality($product_ref);

	$log->trace("end compute_serving_size_date - end") if $log->is_trace();

	if ($#errors >= 0) {
		$action = 'display';
	}
}

# Display the product edit form

my %remember_fields = ('purchase_places'=>1, 'stores'=>1);

# Display each field

sub display_input_field($$$) {

	my $product_ref = shift;
	my $field = shift;	# can be in %language_fields and suffixed by _[lc]
	my $language = shift;

	my $fieldtype = $field;
	my $display_lc = $lc;
	my @field_notes;
	my $examples = '';

	my $template_data_ref_field = {};

	if (($field =~ /^(.*?)_(..|new_lc)$/) and (defined $language_fields{$1})) {
		$fieldtype = $1;
		$display_lc = $2;
	}

	my $autocomplete = "";
	my $class = "";
	if (defined $tags_fields{$fieldtype}) {
		$class = "tagify-me";
		if ((defined $taxonomy_fields{$fieldtype}) or ($fieldtype eq 'emb_codes')) {
			$autocomplete = "$formatted_subdomain/cgi/suggest.pl?tagtype=$fieldtype&";
		}
	}

	my $value = $product_ref->{$field};

	if ((defined $value) and (defined $taxonomy_fields{$field})
		# if the field was previously not taxonomized, the $field_hierarchy field does not exist
		and (defined $product_ref->{$field . "_hierarchy"})) {
		$value = display_tags_hierarchy_taxonomy($lc, $field, $product_ref->{$field . "_hierarchy"});
		# Remove tags
		$value =~ s/<(([^>]|\n)*)>//g;
	}
	if (not defined $value) {
		$value = "";
	}

	$template_data_ref_field->{language} =  $language;
	$template_data_ref_field->{field} =  $field;
	$template_data_ref_field->{class} =  $class;
	$template_data_ref_field->{value} =  $value;
	$template_data_ref_field->{display_lc} =  $display_lc;
	$template_data_ref_field->{autocomplete} =  $autocomplete;
	$template_data_ref_field->{fieldtype} = $Lang{$fieldtype}{$lang};

	my $html_field = '';

	if (($field =~ /infocard/) or ($field =~ /^packaging_text/)) {

	}
	else {
		# Line feeds will be removed in text inputs, convert them to spaces
		$value =~ s/\n/ /g;
	}

	foreach my $note ("_note", "_note_2") {
		if (defined $Lang{$fieldtype . $note }{$lang}) {

			push (@field_notes, {
				note => $Lang{$fieldtype . $note }{$lang},
			});

		}
	}

	$template_data_ref_field->{field_notes} = \@field_notes;

	if (defined $Lang{$fieldtype . "_example"}{$lang}) {

		$examples = $Lang{example}{$lang};
		if ($Lang{$fieldtype . "_example"}{$lang} =~ /,/) {
			$examples = $Lang{examples}{$lang};
		}
	}

	$template_data_ref_field->{examples} = $examples;
	$template_data_ref_field->{field_type_examples} = $Lang{$fieldtype . "_example"}{$lang};

	process_template('web/pages/product_edit/display_input_field.tt.html', $template_data_ref_field, \$html_field) or $html_field = "<p>" . $tt->error() . "</p>";

	return $html_field;
}

if (($action eq 'display') and (($type eq 'add') or ($type eq 'edit'))) {

	# Populate the energy-kcal or energy-kj field from the energy field if it exists
	compute_serving_size_data($product_ref);

	my $template_data_ref_display = {};
	my $js;

	$log->debug("displaying product", { code => $code }) if $log->is_debug();

	# Lang strings for product.js

	my $moderator = 0;
	if ($User{moderator}) {
		$moderator = 1;
	}

	$header .= <<HTML
<link rel="stylesheet" type="text/css" href="/css/dist/cropper.css" />
<link rel="stylesheet" type="text/css" href="/css/dist/tagify.css" />
<link rel="stylesheet" type="text/css" href="/css/dist/product-multilingual.css?v=$file_timestamps{"css/dist/product-multilingual.css"}" />
HTML
;

	$scripts .= <<HTML
<script type="text/javascript" src="/js/dist/webcomponentsjs/webcomponents-loader.js"></script>
<script type="text/javascript" src="/js/dist/cropper.js"></script>
<script type="text/javascript" src="/js/dist/jquery-cropper.js"></script>
<script type="text/javascript" src="/js/dist/jquery.form.js"></script>
<script type="text/javascript" src="/js/dist/tagify.min.js"></script>
<script type="text/javascript" src="/js/dist/jquery.iframe-transport.js"></script>
<script type="text/javascript" src="/js/dist/jquery.fileupload.js"></script>
<script type="text/javascript" src="/js/dist/load-image.all.min.js"></script>
<script type="text/javascript" src="/js/dist/canvas-to-blob.js"></script>
<script type="text/javascript">
var admin = $moderator;
</script>
<script type="text/javascript" src="/js/dist/product-multilingual.js?v=$file_timestamps{"js/dist/product-multilingual.js"}"></script>
HTML
;

$html .= <<HTML
<span></span>
HTML
;

	if ((not ((defined $server_options{private_products}) and ($server_options{private_products})))
	 and (defined $Org_id)) {

		# Display a link to the producers platform
		
		my $producers_platform_url = $formatted_subdomain . '/';
		$producers_platform_url =~ s/\.open/\.pro\.open/;

		$template_data_ref_display->{producers_platform_url} = $producers_platform_url;
	}

	$template_data_ref_display->{errors_index} = $#errors;

	my @errors_arr;

	if ($#errors >= 0) {
		foreach my $error (@errors) {
			push(@errors_arr, $error);
		}
	}

	$template_data_ref_display->{errors} = \@errors;

	my $thumb_selectable_size = $thumb_size + 20;

	$template_data_ref_display->{thumb_selectable_size} = $thumb_selectable_size;

	my $label_new_code = $Lang{new_code}{$lang};

	# 26/01/2017 - disallow barcode changes until we fix bug #677
	if ($User{moderator}) {
	}

	$template_data_ref_display->{server_options_private_products} = $server_options{private_products};
	$template_data_ref_display->{org_id} = $Org_id;
	$template_data_ref_display->{user_moderator} = $User{moderator};
	$template_data_ref_display->{label_new_code} = $label_new_code;
	$template_data_ref_display->{owner_id} = $Owner_id;

	# obsolete products: restrict to admin on public site
	# authorize owners on producers platform
	if ($User{moderator} or $Owner_id) {

		my $checked = '';
		if ((defined $product_ref->{obsolete}) and ($product_ref->{obsolete} eq 'on')) {
			$checked = 'checked="checked"';
		}

		$template_data_ref_display->{obsolete_checked} = $checked;
		$template_data_ref_display->{display_field_obsolete} = display_input_field($product_ref, "obsolete_since_date", undef);

	}

	$template_data_ref_display->{obsolete} = $Lang{obsolete}{$lang};
	$template_data_ref_display->{warning_3rd_party_content} = $Lang{warning_3rd_party_content}{$lang};
	$template_data_ref_display->{licence_accept} = $Lang{licence_accept}{$lang};

	# Main language
	my @lang_options;
	my @lang_values = sort { display_taxonomy_tag($lc,'languages',$language_codes{$a}) cmp display_taxonomy_tag($lc,'languages',$language_codes{$b})} @Langs;

	my %lang_labels = ();
	foreach my $l (@lang_values) {
		next if (length($l) > 2);
		$lang_labels{$l} = display_taxonomy_tag($lc,'languages',$language_codes{$l});
		push(@lang_options, {
			value => $l,
			label => $lang_labels{$l},
		});
	}

	my $lang_value = $lang;
	if (defined $product_ref->{lc}) {
		$lang_value = $product_ref->{lc};
	}


	$template_data_ref_display->{lang_value} = $lang_value;
	$template_data_ref_display->{lang_options} = \@lang_options;
	$template_data_ref_display->{lang} = $Lang{lang}{$lang};
	$template_data_ref_display->{display_select_manage} = display_select_manage($product_ref);



		$template_data_ref_display->{copy_data} = $Lang{copy_data}{$lc};
		$template_data_ref_display->{manage_images_info} = $Lang{manage_images_info}{$lc};
		$template_data_ref_display->{delete_the_images} = $Lang{delete_the_images}{$lc};
		$template_data_ref_display->{move_images_to_another_product} = $Lang{move_images_to_another_product}{$lc};
		$template_data_ref_display->{barcode} = $Lang{barcode}{$lc};
		$template_data_ref_display->{manage_images} = $Lang{manage_images}{$lc};
	

	$product_ref->{langs_order} = { fr => 0, nl => 1, en => 1, new => 2 };

	# sort function to put main language first, other languages by alphabetical order, then add new language tab

	defined $product_ref->{lc} or $product_ref->{lc} = $lc;
	defined $product_ref->{languages_codes} or $product_ref->{languages_codes} = {};

	$product_ref->{sorted_langs} = [ $product_ref->{lc} ];

	foreach my $olc (sort keys %{$product_ref->{languages_codes}}) {
		if ($olc ne $product_ref->{lc}) {
			push @{$product_ref->{sorted_langs}}, $olc;
		}
	}

	$template_data_ref_display->{product_image} = $Lang{product_image}{$lang};
	$template_data_ref_display->{product_ref_sorted_langs} = join(',', @{$product_ref->{sorted_langs}});

sub display_input_tabs($$$$$) {

	my $product_ref = shift;
	my $tabsid = shift;
	my $tabsids_array_ref = shift;
	my $tabsids_hash_ref = shift;
	my $fields_array_ref = shift;

	my $html_tab = '';

	my $template_data_ref_tab = {};
	my @display_tabs;
	my $display_div;
	my $ingredients_image_full_id;
	my $id;
	my $value;

	$template_data_ref_tab->{tabsid} = $tabsid;
	$template_data_ref_tab->{user_moderator} = $User{moderator};

	my $active = " active";

	foreach my $tabid (@$tabsids_array_ref, 'new_lc','new') {

		my $new_lc = '';
		if ($tabid eq 'new_lc') {
			$new_lc = ' new_lc hide';
		}
		elsif ($tabid eq 'new') {
			$new_lc = ' new';
		}

		# We will create an array of fields for each language
		my @fields_arr = ();

		my $display_tab_ref = {
			tabid => $tabid,
			active => $active,
			new_lc => $new_lc,
		};

		my $language;

		if ($tabid ne 'new') {
			
			$language = display_taxonomy_tag($lc,'languages',$language_codes{$tabid});	 # instead of $tabsids_hash_ref->{$tabid}
			$display_tab_ref->{language} = $language;
		
			my $display_lc = $tabid;
			$template_data_ref_tab->{display_lc} = $display_lc;

			foreach my $field (@{$fields_array_ref}) {

				if ($field =~ /^(.*)_image/) {

					my $image_field = $1 . "_" . $display_lc;
					$display_div = display_select_crop($product_ref, $image_field, $language);

				}
				elsif ($field eq 'ingredients_text') {

					$value = $product_ref->{"ingredients_text_" . ${display_lc}};
					not defined $value and $value = "";
					$id = "ingredients_text_" . ${display_lc};
					$ingredients_image_full_id = "ingredients_" . ${display_lc} . "_image_full";

				}
				else {
					$log->debug("display_field", { field_name => $field, field_value => $product_ref->{$field} }) if $log->is_debug();
					$display_div = display_input_field($product_ref, $field . "_" . $display_lc, $language);
				}

				push(@fields_arr, {
					ingredients_image_full_id => $ingredients_image_full_id,
					tab_content_id => $id,
					ingredients_text_note => $Lang{ingredients_text_note}{$lang},
					examples =>  $Lang{example}{$lang},
					value => $value,
					ingredients_text_example => $Lang{ingredients_text_example}{$lang},
					ingredients_text => $Lang{ingredients_text}{$lang},
					field_status => $field,
					display_div => $display_div,
				});
			}

			$display_tab_ref->{fields} = \@fields_arr;
		}

		push(@display_tabs, $display_tab_ref);

		# For moderators, add a checkbox to move all data and photos to the main language
		# this needs to be below the "add (language name) in all field labels" above, so that it does not change this label.
		if (($User{moderator}) and ($tabsid eq "front_image")) {

			my $msg = sprintf(lang("move_data_and_photos_to_main_language"),
				'<span class="tab_language">' . $language . '</span>',
				'<span class="main_language">' . lang("lang_" . $product_ref->{lc}) . '</span>');

			my $moveid = "move_" . $tabid . "_data_and_images_to_main_language";

			$template_data_ref_tab->{moveid} = $moveid;
			$template_data_ref_tab->{msg} = $msg;
			$template_data_ref_tab->{move_data_and_photos_to_main_language_ignore} = $Lang{move_data_and_photos_to_main_language_ignore}{$lc};
			$template_data_ref_tab->{move_data_and_photos_to_main_language_replace}= $Lang{move_data_and_photos_to_main_language_replace}{$lc};

		}

		# Only the first tab is active
		$active = "";

	}

	$template_data_ref_tab->{display_tabs} = \@display_tabs;

	process_template('web/pages/product_edit/display_input_tabs.tt.html', $template_data_ref_tab, \$html_tab) or $html_tab = "<p>" . $tt->error() . "</p>";

	return $html_tab;
}
	$template_data_ref_display->{ingredients} = $Lang{ingredients}{$lang};
	$template_data_ref_display->{product_characteristics} = $Lang{product_characteristics}{$lang};
	$template_data_ref_display->{nutrition_data} = $Lang{nutrition_data}{$lang};
	$template_data_ref_display->{no_nutrition_data} = $Lang{no_nutrition_data}{$lang};
	$template_data_ref_display->{display_tab_product_picture} = display_input_tabs($product_ref, "front_image", $product_ref->{sorted_langs}, \%Langs, ["front_image"]);
	$template_data_ref_display->{display_tab_product_characteristics} = display_input_tabs($product_ref, "product", $product_ref->{sorted_langs}, \%Langs, ["product_name", "generic_name"]);

	my @display_fields_arr;
	foreach my $field (@fields) {
		next if $field eq "origins"; # now displayed below allergens and traces in the ingredients section
		$log->debug("display_field", { field_name => $field, field_value => $product_ref->{$field} }) if $log->is_debug();
		my $display_field = display_input_field($product_ref, $field, undef);
		push(@display_fields_arr, $display_field);
	}

	$template_data_ref_display->{display_fields_arr} = \@display_fields_arr;
	my @ingredients_fields = ("ingredients_image", "ingredients_text");

	my $checked = '';
	my $tablestyle = 'display: table;';
	my $disabled = '';
	if ((defined $product_ref->{no_nutrition_data}) and ($product_ref->{no_nutrition_data} eq 'on')) {
		$checked = 'checked="checked"';
		$tablestyle = 'display: none;';
		$disabled = 'disabled="disabled"';
	}

	$template_data_ref_display->{nutrition_checked} = $checked;
	$template_data_ref_display->{display_tab_ingredients_image} = display_input_tabs($product_ref, "ingredients_image", $product_ref->{sorted_langs}, \%Langs, \@ingredients_fields);
	$template_data_ref_display->{display_field_allergens} =  display_input_field($product_ref, "allergens", undef);
	$template_data_ref_display->{display_field_traces} =  display_input_field($product_ref, "traces", undef);
	$template_data_ref_display->{display_field_origins} =  display_input_field($product_ref, "origins", undef);
	$template_data_ref_display->{display_tab_nutrition_image} = display_input_tabs($product_ref, "nutrition_image", $product_ref->{sorted_langs}, \%Langs, ["nutrition_image"]);
	$template_data_ref_display->{display_field_serving_size} =   display_input_field($product_ref, "serving_size", undef);

	$initjs .= display_select_crop_init($product_ref);

	my $hidden_inputs = '';

	#<p class="note">&rarr; $Lang{nutrition_data_table_note}{$lang}</p>

	# Display 2 checkbox to indicate the nutrition values present on the product

	if (not defined $product_ref->{nutrition_data}) {
		# by default, display the nutrition data entry column for the product as sold
		$product_ref->{nutrition_data} = "on";
	}
	if (not defined $product_ref->{nutrition_data_prepared}) {
		# by default, do not display the nutrition data entry column for the prepared product
		$product_ref->{nutrition_data_prepared} = "";
	}

	my %column_display_style = ();
	my %nutrition_data_per_display_style = ();
	my @nutrition_products;

	# keep existing field ids for the product as sold, and append _prepared_product for the product after it has been prepared
	foreach my $product_type ("", "_prepared") {

		my $nutrition_data = "nutrition_data" . $product_type;
		my $nutrition_data_exists = "nutrition_data" . $product_type . "_exists";
		my $nutrition_data_instructions = "nutrition_data" . $product_type . "_instructions";

		my $checked = '';
		$column_display_style{$nutrition_data} = '';
		my $hidden = '';
		if (($product_ref->{$nutrition_data} eq 'on')) {
			$checked = 'checked="checked"';
		}
		else {
			$column_display_style{$nutrition_data} = 'style="display:none"';
			$hidden = 'style="display:none"';
		}

		my $checked_per_serving = '';
		my $checked_per_100g = 'checked="checked"';
		$nutrition_data_per_display_style{$nutrition_data . "_serving"} = ' style="display:none"';
		$nutrition_data_per_display_style{$nutrition_data . "_100g"} = '';

		my $nutrition_data_per = "nutrition_data" . $product_type . "_per";

		if (($product_ref->{$nutrition_data_per} eq 'serving')
			# display by serving by default for the prepared product
			or (($product_type eq '_prepared') and (not defined $product_ref->{nutrition_data_prepared_per}))) {
			$checked_per_serving = 'checked="checked"';
			$checked_per_100g = '';
			$nutrition_data_per_display_style{$nutrition_data . "_serving"} = '';
			$nutrition_data_per_display_style{$nutrition_data . "_100g"} = ' style="display:none"';
		}

		my $nutriment_col_class = "nutriment_col" . $product_type;
		
		my $product_type_as_sold_or_prepared = "as_sold";
		if ($product_type eq "_prepared") {
			$product_type_as_sold_or_prepared = "prepared";
		}

		push(@nutrition_products, {
			checked => $checked,
			nutrition_data => $nutrition_data,
			nutrition_data_exists => $Lang{$nutrition_data_exists}{$lang},
			nutrition_data_per => $nutrition_data_per,
			checked_per_100g => $checked_per_100g,
			checked_per_serving => $checked_per_serving,
			nutrition_data_per_100g => $Lang{nutrition_data_per_100g}{$lang},
			nutrition_data_per_serving => $Lang{nutrition_data_per_serving}{$lang},
			nutrition_data_instructions => $nutrition_data_instructions,
			nutrition_data_instructions_check => $Lang{$nutrition_data_instructions},
			nutrition_data_instructions_lang => $Lang{$nutrition_data_instructions}{$lang},
			hidden => $hidden,
			nutriment_col_class => $nutriment_col_class,
			product_type_as_sold_or_prepared => $product_type_as_sold_or_prepared,
			checkmate => $product_ref->{$nutrition_data_per},
		});

	}

	$template_data_ref_display->{nutrition_products} = \@nutrition_products;

	$template_data_ref_display->{column_display_style_nutrition_data} =$column_display_style{"nutrition_data"};
	$template_data_ref_display->{column_display_style_nutrition_data_prepared} =$column_display_style{"nutrition_data_prepared"};
	$template_data_ref_display->{nutrition_data_100g_style} = $nutrition_data_per_display_style{"nutrition_data_100g"};
	$template_data_ref_display->{nutrition_data_serving_style} = $nutrition_data_per_display_style{"nutrition_data_serving"};
	$template_data_ref_display->{nutrition_data_prepared_100g_style} = $nutrition_data_per_display_style{"nutrition_data_prepared_100g"};
	$template_data_ref_display->{nutrition_data_prepared_serving_style} = $nutrition_data_per_display_style{"nutrition_data_prepared_serving"};

	$template_data_ref_display->{nutrition_data_table} = $Lang{nutrition_data_table}{$lang};
	$template_data_ref_display->{product_as_sold} = $Lang{product_as_sold}{$lang};
	$template_data_ref_display->{prepared_product} = $Lang{prepared_product}{$lang};
	$template_data_ref_display->{nutriments_unit} = $Lang{unit}{$lang};
	$template_data_ref_display->{tablestyle} = $tablestyle;
	$template_data_ref_display->{nutrition_data_per_100g} = $Lang{nutrition_data_per_100g}{$lang};
	$template_data_ref_display->{nutrition_data_per_serving} = $Lang{nutrition_data_per_serving}{$lang};

	defined $product_ref->{nutriments} or $product_ref->{nutriments} = {};

	my @unknown_nutriments = ();
	my %seen_unknown_nutriments = ();
	foreach my $nid (keys %{$product_ref->{nutriments}}) {

		next if (($nid =~ /_/) and ($nid !~ /_prepared$/)) ;

		$nid =~ s/_prepared$//;

		$log->trace("detect unknown nutriment", { nid => $nid }) if $log->is_trace();

		if ((not exists $Nutriments{$nid}) and (defined $product_ref->{nutriments}{$nid . "_label"})
			and (not defined $seen_unknown_nutriments{$nid})) {
			push @unknown_nutriments, $nid;
			$log->debug("unknown nutriment detected", { nid => $nid }) if $log->is_debug();
		}
	}

	my @nutriments;	
	foreach my $nutriment (@{$nutriments_tables{$nutriment_table}}, @unknown_nutriments, 'new_0', 'new_1') {

		my $nutriment_ref = {};

		next if $nutriment =~ /^\#/;
		my $nid = $nutriment;
		$nid =~ s/^(-|!)+//g;
		$nid =~ s/-$//g;

		next if $nid =~ /^nutrition-score/;

		# Do not display the energy field without a unit, display energy-kcal or energy-kj instead
		next if $nid eq "energy";

		my $class = 'main';
		my $prefix = '';

		my $shown = 0;

		if  (($nutriment !~ /-$/)
			or ((defined $product_ref->{nutriments}{$nid}) and ($product_ref->{nutriments}{$nid} ne ''))
			or ($nid eq 'new_0') or ($nid eq 'new_1')) {
			$shown = 1;
		}

		if (($shown) and ($nutriment =~ /^-/)) {
			$class = 'sub';
			$prefix = $Lang{nutrition_data_table_sub}{$lang} . " ";
			if ($nutriment =~ /^--/) {
				$prefix = "&nbsp; " . $prefix;
			}
		}

		my $display = '';
		if ($nid eq 'new_0') {
			$display = ' style="display:none"';
		}

		my $enid = encodeURIComponent($nid);

		# for prepared product
		my $nidp = $nid . "_prepared";
		my $enidp = encodeURIComponent($nidp);

		my $label = '';
		if ((exists $Nutriments{$nid}) and (exists $Nutriments{$nid}{$lang})) {
			$nutriment_ref->{nutriments_nid} =  $Nutriments{$nid};
			$nutriment_ref->{nutriments_nid_lang} =  $Nutriments{$nid}{$lang};
		}
		elsif ((exists $Nutriments{$nid}) and (exists $Nutriments{$nid}{en})) {
			$nutriment_ref->{nutriments_nid} =  $Nutriments{$nid};
			$nutriment_ref->{nutriments_nid_en} =  $Nutriments{$nid}{en};
		}
		elsif (defined $product_ref->{nutriments}{$nid . "_label"}) {
			my $label_value = $product_ref->{nutriments}{$nid . "_label"};
		}

		$nutriment_ref->{label_value} =  $product_ref->{nutriments}{$nid . "_label"};
		$nutriment_ref->{product_add_nutrient} =  $Lang{product_add_nutrient}{$lang};
		$nutriment_ref->{prefix} = $prefix;

		my $unit = 'g';
		if ((exists $Nutriments{$nid}) and (exists $Nutriments{$nid}{"unit_$cc"})) {
			$unit = $Nutriments{$nid}{"unit_$cc"};
		}
		elsif ((exists $Nutriments{$nid}) and (exists $Nutriments{$nid}{unit})) {
			$unit = $Nutriments{$nid}{unit};
		}
		my $value; # product as sold
		my $valuep; # prepared product

		if ($nid eq 'water-hardness') {
			$value = mmoll_to_unit($product_ref->{nutriments}{$nid}, $unit);
			$valuep = mmoll_to_unit($product_ref->{nutriments}{$nidp}, $unit);
		}
		elsif ($nid eq 'energy-kcal') {
			# energy-kcal is already in kcal
			$value = $product_ref->{nutriments}{$nid};
			$valuep = $product_ref->{nutriments}{$nidp};
		}
		else {
			$value = g_to_unit($product_ref->{nutriments}{$nid}, $unit);
			$valuep = g_to_unit($product_ref->{nutriments}{$nidp}, $unit);
		}

		# user unit and value ? (e.g. DV for vitamins in US)
		if (defined $product_ref->{nutriments}{$nid . "_unit"}) {
			$unit = $product_ref->{nutriments}{$nid . "_unit"};
			if (defined $product_ref->{nutriments}{$nid . "_value"}) {
				$value = $product_ref->{nutriments}{$nid . "_value"};
				if (defined $product_ref->{nutriments}{$nid . "_modifier"}) {
					$product_ref->{nutriments}{$nid . "_modifier"} eq '<' and $value = "&lt; $value";
					$product_ref->{nutriments}{$nid . "_modifier"} eq "\N{U+2264}" and $value = "&le; $value";
					$product_ref->{nutriments}{$nid . "_modifier"} eq '>' and $value = "&gt; $value";
					$product_ref->{nutriments}{$nid . "_modifier"} eq "\N{U+2265}" and $value = "&ge; $value";
					$product_ref->{nutriments}{$nid . "_modifier"} eq '~' and $value = "~ $value";
				}
			}
			if (defined $product_ref->{nutriments}{$nidp . "_value"}) {
				$valuep = $product_ref->{nutriments}{$nidp . "_value"};
				if (defined $product_ref->{nutriments}{$nidp . "_modifier"}) {
					$product_ref->{nutriments}{$nidp . "_modifier"} eq '<' and $valuep = "&lt; $valuep";
					$product_ref->{nutriments}{$nidp . "_modifier"} eq "\N{U+2264}" and $valuep = "&le; $valuep";
					$product_ref->{nutriments}{$nidp . "_modifier"} eq '>' and $valuep = "&gt; $valuep";
					$product_ref->{nutriments}{$nidp . "_modifier"} eq "\N{U+2265}" and $valuep = "&ge; $valuep";
					$product_ref->{nutriments}{$nidp . "_modifier"} eq '~' and $valuep = "~ $valuep";
				}
			}
		}

		if (lc($unit) eq "mcg") {
			$unit = "µg";
		}

		my $disabled_backup = $disabled;
		if ($nid eq 'carbon-footprint') {
			# Workaround, so that the carbon footprint, that could be in a location different from actual nutrition facts,
			# will never be disabled.
			$disabled = '';
		}

		if (($nid eq 'alcohol') or ($nid eq 'energy-kj') or ($nid eq 'energy-kcal')) {
			my $unit = '';

			if (($nid eq 'alcohol')) { $unit = '% vol / °'; } # alcohol in % vol / °
			elsif (($nid eq 'energy-kj')) { $unit = 'kJ'; }
			elsif (($nid eq 'energy-kcal')) { $unit = 'kcal'; }

			$nutriment_ref->{nutriment_unit}  = $unit;

		}
		else {

			my @units = ('g','mg','µg');
			my @units_arr;

			if ($nid =~ /^energy/) {
				@units = ('kJ','kcal');
			}
			elsif ($nid eq 'water-hardness') {
				@units = ('mol/l', 'mmol/l', 'mval/l', 'ppm', "\N{U+00B0}rH", "\N{U+00B0}fH", "\N{U+00B0}e", "\N{U+00B0}dH", 'gpg');
			}

			if (((exists $Nutriments{$nid}) and (exists $Nutriments{$nid}{dv}) and ($Nutriments{$nid}{dv} > 0))
				or ($nid =~ /^new_/)
				or (uc($unit) eq '% DV')) {
				push @units, '% DV';
			}
			if (((exists $Nutriments{$nid}) and (exists $Nutriments{$nid}{iu}) and ($Nutriments{$nid}{iu} > 0))
				or ($nid =~ /^new_/)
				or (uc($unit) eq 'IU')
				or (uc($unit) eq 'UI')) {
				push @units, 'IU';
			}

			my $hide_percent = '';
			my $hide_select = '';

			if ((exists $Nutriments{$nid}) and (exists $Nutriments{$nid}{unit}) and ($Nutriments{$nid}{unit} eq '')) {
				$hide_percent = ' style="display:none"';
				$hide_select = ' style="display:none"';

			}
			elsif ((exists $Nutriments{$nid}) and (exists $Nutriments{$nid}{unit}) and ($Nutriments{$nid}{unit} eq '%')) {
				$hide_select = ' style="display:none"';
			}
			else {
				$hide_percent = ' style="display:none"';
			}

			$nutriment_ref->{hide_select}  = $hide_select;
			$nutriment_ref->{hide_percent}  = $hide_percent;
			$nutriment_ref->{nutriment_unit_disabled}  = $disabled;

			$disabled = $disabled_backup;

			foreach my $u (@units) {
				my $selected = '';
				if (lc($unit) eq lc($u)) {
					$selected = 'selected="selected" ';
				}
				my $label = $u;
				# Display both mcg and µg as different food labels show the unit differently
				if ($u eq 'µg') {
					$label = "mcg/µg";
				}

				push(@units_arr, {
					u => $u,
					label => $label,
					selected => $selected,
				});
			}

			$nutriment_ref->{units_arr} = \@units_arr;
	
		}
		
		$nutriment_ref->{shown} = $shown;
		$nutriment_ref->{enid} = $enid;
		$nutriment_ref->{enidp} = $enidp;
		$nutriment_ref->{nid} = $nid;
		$nutriment_ref->{label} = $label;
		$nutriment_ref->{class} = $class;
		$nutriment_ref->{value} = $value;
		$nutriment_ref->{valuep} = $valuep;
		$nutriment_ref->{display} = $display;
		$nutriment_ref->{disabled} = $disabled;

		push(@nutriments, $nutriment_ref);
	}
	
	$template_data_ref_display->{nutriments} = \@nutriments;

	my $other_nutriments = '';
	my $nutriments = '';
	foreach my $nid (@{$other_nutriments_lists{$nutriment_table}}) {
		my $other_nutriment_value;
		if ((exists $Nutriments{$nid}{$lang}) and ($Nutriments{$nid}{$lang} ne '')) {
			$other_nutriment_value = $Nutriments{$nid}{$lang};
		}
		else {
			foreach my $olc (@{$country_languages{$cc}}, 'en') {
				next if $olc eq $lang;
				if ((exists $Nutriments{$nid}{$olc}) and ($Nutriments{$nid}{$olc} ne '')) {
					$other_nutriment_value = $Nutriments{$nid}{$olc};
					last;
				}
			}
		}

		if ((not (defined $other_nutriment_value)) or ($other_nutriment_value eq '')) {
			$other_nutriment_value = $nid;
		}

		if ((not defined $product_ref->{nutriments}{$nid}) or ($product_ref->{nutriments}{$nid} eq '')) {
			my $supports_iu = "false";
			if ((exists $Nutriments{$nid}{iu}) and ($Nutriments{$nid}{iu} > 0)) {
				$supports_iu = "true";
			}

			$other_nutriments .= '{ "value" : "' . $other_nutriment_value . '", "unit" : "' . $Nutriments{$nid}{unit} . '", "iu": ' . $supports_iu . '  },' . "\n";
		}
		$nutriments .= '"' . $other_nutriment_value . '" : "' . $nid . '",' . "\n";
	}
	$nutriments =~ s/,\n$//s;
	$other_nutriments =~ s/,\n$//s;

	$scripts .= <<HTML
<script type="text/javascript">
var nutriments = {
$nutriments
};

var otherNutriments = [
$other_nutriments
];
</script>
HTML
;

$html .= <<HTML
<span></span>
HTML
;

	# Packaging photo and data
	my @packaging_fields = ("packaging_image", "packaging_text");

	$template_data_ref_display->{remove_all_nutrient_values} = $Lang{remove_all_nutrient_values}{$lang};
	$template_data_ref_display->{nutrition_data_table_note} = $Lang{nutrition_data_table_note}{$lang};
	$template_data_ref_display->{ecological_data_table_note} = $Lang{ecological_data_table_note}{$lang};
	$template_data_ref_display->{ecological_data_table} = $Lang{ecological_data_table}{$lang};
	$template_data_ref_display->{packaging} = $Lang{packaging}{$lang};
	$template_data_ref_display->{display_tab_packaging} =display_input_tabs($product_ref, "packaging_image", $product_ref->{sorted_langs}, \%Langs, \@packaging_fields);

	# Product check

	if ($User{moderator}) {
		my $checked = '';
		my $label = $Lang{i_checked_the_photos_and_data}{$lang};
		my $recheck_html = "";

		if ((defined $product_ref->{checked}) and ($product_ref->{checked} eq 'on')) {
			$checked = 'checked="checked"';
			$label = $Lang{photos_and_data_checked}{$lang};
		}

		$template_data_ref_display->{photos_and_data_check_description} = $Lang{photos_and_data_check_description}{$lang};
		$template_data_ref_display->{photos_and_data_check} = $Lang{photos_and_data_check}{$lang};
		$template_data_ref_display->{i_checked_the_photos_and_data_again} = $Lang{i_checked_the_photos_and_data_again}{$lang};
		$template_data_ref_display->{product_ref_checked} = $product_ref->{checked};
		$template_data_ref_display->{product_check_label} = $label;
		$template_data_ref_display->{product_check_checked} = $checked;

	}

	$template_data_ref_display->{param_fields} = param("fields");
	$template_data_ref_display->{type} = $type;
	$template_data_ref_display->{code} = $code;
	$template_data_ref_display->{save} = $Lang{save}{$lang};
	$template_data_ref_display->{cancel} = $Lang{cancel}{$lang};
	$template_data_ref_display->{edit_comment} = $Lang{edit_comment}{$lang};
	$template_data_ref_display->{display_product_history} = display_product_history($code, $product_ref);

	process_template('web/pages/product_edit/product_edit_form_display.tt.html', $template_data_ref_display, \$html) or $html = "<p>" . $tt->error() . "</p>";
	process_template('web/pages/product_edit/product_edit_form_display.tt.js', $template_data_ref_display, \$js);
	$initjs .= $js;

}
elsif (($action eq 'display') and ($type eq 'delete') and ($User{moderator})) {

	my $template_data_ref_moderator = {};

	$log->debug("display product", { code => $code }) if $log->is_debug();

	$template_data_ref_moderator->{delete_comment} = $Lang{delete_comment}{$lang};
	$template_data_ref_moderator->{delete_product_confirm} = $Lang{delete_product_confirm}{$lang};
	$template_data_ref_moderator->{product_name} = $Lang{product_name}{$lang};
	$template_data_ref_moderator->{product_ref_product_name} = $product_ref->{product_name};
	$template_data_ref_moderator->{barcode} = $Lang{barcode}{$lang};
	$template_data_ref_moderator->{type} = $type;
	$template_data_ref_moderator->{code} = $code;

	process_template('web/pages/product_edit/product_edit_form_display_user-moderator.tt.html', $template_data_ref_moderator, \$html) or $html = "<p>" . $tt->error() . "</p>";

}
elsif ($action eq 'process') {

	my $template_data_ref_process = {};

	$log->debug("phase 2", { code => $code }) if $log->is_debug();

	$product_ref->{interface_version_modified} = $interface_version;

	if (($User{moderator}) and ($type eq 'delete')) {
		$product_ref->{deleted} = 'on';
		$comment = lang("deleting_product") . separator_before_colon($lc) . ":";
	}
	elsif (($User{moderator}) and (exists $product_ref->{deleted})) {
		delete $product_ref->{deleted};
	}

	my $time = time();
	$comment = $comment . remove_tags_and_quote(decode utf8=>param('comment'));
	store_product($User_id, $product_ref, $comment);

	my $product_url = product_url($product_ref);


	$template_data_ref_process->{product_ref_server} = $product_ref->{server};

	if (defined $product_ref->{server}) {
		# product that was moved to OBF from OFF etc.
		$product_url = "https://" . $subdomain . "." . $options{other_servers}{$product_ref->{server}}{domain} . product_url($product_ref);
	}
	elsif ($type eq 'delete') {

		# Notify robotoff
		send_notification_for_product_change($product_ref, "deleted");

		my $email = <<MAIL
$User_id $Lang{has_deleted_product}{$lc}:

$html

MAIL
;
		send_email_to_admin(lang("deleting_product"), $email);

	} else {

		# Notify robotoff
		send_notification_for_product_change($product_ref, "updated");

		$template_data_ref_process->{display_random_sample_of_products_after_edits_options} = $options{display_random_sample_of_products_after_edits};

		# warning: this option is very slow
		if ((defined $options{display_random_sample_of_products_after_edits}) and ($options{display_random_sample_of_products_after_edits})) {

			my %request = (
				'titleid'=>get_string_id_for_lang($lc,product_name_brand($product_ref)),
				'query_string'=>$ENV{QUERY_STRING},
				'referer'=>referer(),
				'code'=>$code,
				'product_changes_saved'=>1,
				'sample_size'=>10
			);

			display_product(\%request);

		}
	}

	$template_data_ref_process->{product_url} = $product_url;
	process_template('web/pages/product_edit/product_edit_form_process.tt.html', $template_data_ref_process, \$html) or $html = "<p>" . $tt->error() . "</p>";

}

display_page( {
	blog_ref=>undef,
	blogid=>'all',
	tagid=>'all',
	title=>lang($type . '_product'),
	content_ref=>\$html,
	full_width=>1,
});

exit(0);