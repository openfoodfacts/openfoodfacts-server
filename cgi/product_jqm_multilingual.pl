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

use ProductOpener::PerlStandards;

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
use ProductOpener::DataQuality qw/:all/;
use ProductOpener::Ecoscore qw/:all/;
use ProductOpener::Packaging qw/:all/;
use ProductOpener::ForestFootprint qw/:all/;
use ProductOpener::Text qw/:all/;

use Apache2::RequestRec ();
use Apache2::Const ();

use CGI qw/:cgi :form :cgi-lib escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;
use Log::Any qw($log);

my $request_ref = ProductOpener::Display::init_request();

my $comment = '(app)';

my $interface_version = '20150316.jqm2';

my %response = ();

my $code = single_param('code');
my $product_id;

$log->debug("start", {code => $code, lc => $lc}) if $log->is_debug();

# Allow apps to create products without barcodes
# Assign a code and return it in the response.
if ($code eq "new") {

	($code, $product_id) = assign_new_code();
	$response{code} = $code . "";    # Make sure the code is returned as a string
}

my $original_code = $code;

$code = normalize_code($code);

if ($code !~ /^\d{4,24}$/) {

	$log->info("invalid code", {code => $code, original_code => $original_code}) if $log->is_info();
	$response{status} = 0;
	$response{status_verbose} = 'no code or invalid code';
}
else {

	my $product_id = product_id_for_owner($Owner_id, $code);
	my $product_ref = retrieve_product($product_id);

	if (not defined $product_ref) {
		$product_ref = init_product($User_id, $Org_id, $code, $country);
		$product_ref->{interface_version_created} = $interface_version;
	}

	# Process edit rules

	$log->debug("phase 0 - checking edit rules", {code => $code}) if $log->is_debug();

	my $proceed_with_edit = process_product_edit_rules($product_ref);

	$log->debug("phase 0", {code => $code, proceed_with_edit => $proceed_with_edit}) if $log->is_debug();

	if (not $proceed_with_edit) {

		$response{status} = 0;
		$response{status_verbose} = 'Edit against edit rules';

		my $data = encode_json(\%response);

		print header(-type => 'application/json', -charset => 'utf-8', -access_control_allow_origin => '*') . $data;

		exit(0);
	}

	exists $product_ref->{new_server} and delete $product_ref->{new_server};

	my @errors = ();

	# Store parameters for debug purposes
	(-e "$data_root/debug") or mkdir("$data_root/debug", 0755);
	open(my $out, ">", "$data_root/debug/product_jqm_multilingual." . time() . "." . $code);
	print $out encode_json(Vars());
	close $out;

	# Fix too low salt values
	# 2020/02/25 - https://github.com/openfoodfacts/openfoodfacts-server/issues/2945
	if ((defined $User_id) and ($User_id eq 'kiliweb') and (defined single_param("nutriment_salt"))) {

		my $salt = single_param("nutriment_salt");

		if ((defined $product_ref->{nutriments}) and (defined $product_ref->{nutriments}{salt_100g})) {

			my $existing_salt = $product_ref->{nutriments}{salt_100g};

			$log->debug(
				"yuka - kiliweb : changing salt value of existing product",
				{salt => $salt, existing_salt => $existing_salt}
			) if $log->is_debug();

			# Salt value may have been divided by 1000 by the calling app
			if ($salt < $existing_salt / 100) {
				# Float issue, we can get things like 0.18000001, convert back to string and remove extra digit
				$salt = $salt . '';
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
				$log->debug("yuka - kiliweb : changing salt value - multiplying too low salt value by 1000",
					{salt => $salt, existing_salt => $existing_salt})
				  if $log->is_debug();
				param(-name => "nutriment_salt", -value => $salt);
			}
		}
		else {
			$log->debug("yuka - kiliweb : adding salt value", {salt => $salt}) if $log->is_debug();

			# Salt value may have been divided by 1000 by the calling app
			if ($salt < 0.001) {
				# Float issue, we can get things like 0.18000001, convert back to string and remove extra digit
				$salt = $salt . '';
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
				$log->debug("yuka - kiliweb : adding salt value - multiplying too low salt value by 1000",
					{salt => $salt})
				  if $log->is_debug();
				param(-name => "nutriment_salt", -value => $salt);
			}
			elsif ($salt < 0.1) {
				$log->debug("yuka - kiliweb : adding salt value - removing potentially too low salt value",
					{salt => $salt})
				  if $log->is_debug();
				param(-name => "nutriment_salt", -value => "");
			}
		}
	}

	# 26/01/2017 - disallow barcode changes until we fix bug #677
	if ($User{moderator} and (defined single_param('new_code'))) {

		change_product_server_or_code($product_ref, single_param('new_code'), \@errors);
		$code = $product_ref->{code};

		if ($#errors >= 0) {
			$response{status} = 0;
			$response{status_verbose} = 'new code is invalid';

			my $data = encode_json(\%response);

			print header(-type => 'application/json', -charset => 'utf-8', -access_control_allow_origin => '*') . $data;

			exit(0);
		}
	}

	#my @app_fields = qw(product_name brands quantity);
	my @app_fields
	  = qw(product_name generic_name quantity packaging brands categories labels origins manufacturing_places emb_codes link expiration_date purchase_places stores countries  );

	# admin field to set a creator
	if ($admin) {
		push @app_fields, "creator";
	}

	if ($admin or ($User_id eq "ecoscore-impact-estimator")) {
		push @app_fields, ("ecoscore_extended_data", "ecoscore_extended_data_version");
	}

	# generate a list of potential languages for language specific fields
	my %param_langs = ();
	foreach my $param (multi_param()) {
		if ($param =~ /^(.*)_(\w\w)$/) {
			if (defined $language_fields{$1}) {
				$param_langs{$2} = 1;
			}
		}
		# some apps may send pt-BR
		elsif ($param =~ /^(.*)_(\w\w)-(\w\w)$/) {
			if (defined $language_fields{$1}) {
				$param_langs{$2} = 1;
				# set the product_name_pt value to the value of product_name_pt-BR
				param($1 . "_" . $2, single_param($1 . "_" . $2 . "-" . $3));
			}
		}
	}
	my @param_langs = keys %param_langs;

	# 01/06/2019 --> Yuka always sends fr fields even for Spanish products, try to correct it

	if ((defined $User_id) and ($User_id eq 'kiliweb') and (defined single_param('cc'))) {

		my $param_cc = lc(single_param('cc'));
		$param_cc =~ s/^en://;

		my %lc_overrides = (
			au => "en",
			br => "pt",
			co => "es",
			es => "es",
			it => "it",
			de => "de",
			uk => "en",
			gb => "en",
			pt => "pt",
			nl => "nl",
			no => "no",
			us => "en",
			ie => "en",
			nz => "en",
			il => "he",
			mx => "es",
			tr => "tr",
			ru => "ru",
			th => "th",
			dk => "da",
			at => "de",
			se => "sv",
			bg => "bg",
			pl => "pl",

		);

		if (defined $lc_overrides{$param_cc}) {
			$lc = $lc_overrides{$param_cc};
		}
	}

	# Do not allow edits / removal through API for data provided by producers (only additions for non existing fields)
	# when the corresponding organization has the protect_data checkbox checked
	my $protected_data = product_data_is_protected($product_ref);

	foreach my $field (@app_fields, 'nutrition_data_per', 'serving_size', 'traces', 'ingredients_text', 'origin',
		'packaging_text', 'lang')
	{

		# 11/6/2018 --> force add_brands and add_countries for yuka / kiliweb
		if (    (defined $User_id)
			and ($User_id eq 'kiliweb')
			and (defined single_param($field))
			and (($field eq 'brands') or ($field eq 'countries')))
		{

			param(-name => "add_" . $field, -value => single_param($field));
			$log->debug("yuka - kiliweb : force add_field", {field => $field, code => $code}) if $log->is_debug();

		}

		# add_brands=additional brand : only add if it does not exist yet
		if ((defined $tags_fields{$field}) and (defined single_param("add_$field"))) {

			my $additional_fields = remove_tags_and_quote(decode utf8 => single_param("add_$field"));

			add_tags_to_field($product_ref, $lc, $field, $additional_fields);

			$log->debug(
				"add_field",
				{
					field => $field,
					code => $code,
					additional_fields => $additional_fields,
					existing_value => $product_ref->{$field}
				}
			) if $log->is_debug();
		}

		elsif (defined single_param($field)) {

			# Do not allow edits / removal through API for data provided by producers (only additions for non existing fields)
			if (($protected_data) and (defined $product_ref->{$field}) and ($product_ref->{$field} ne "")) {
				$log->debug("producer data already exists for field, skip empty value",
					{field => $field, code => $code, existing_value => $product_ref->{$field}})
				  if $log->is_debug();

			}
			else {
				if ($field eq "lang") {
					my $value = remove_tags_and_quote(decode utf8 => single_param($field));

					# strip variants fr-BE fr_BE
					$value =~ s/^([a-z][a-z])(-|_).*$/$1/i;
					$value = lc($value);

					# skip unrecognized languages (keep the existing lang & lc value)
					if (defined $lang_lc{$value}) {
						$product_ref->{lang} = $value;
						$product_ref->{lc} = $value;
					}

				}
				elsif ($field eq "ecoscore_extended_data") {
					# we expect a JSON value
					if (defined single_param($field)) {
						$product_ref->{$field} = decode_json(single_param($field));
					}
				}
				else {
					$product_ref->{$field} = remove_tags_and_quote(decode utf8 => single_param($field));

					if ((defined $language_fields{$field}) and (defined $product_ref->{lc})) {
						my $field_lc = $field . "_" . $product_ref->{lc};
						$product_ref->{$field_lc} = $product_ref->{$field};
					}

					compute_field_tags($product_ref, $lc, $field);
				}
			}
		}

		if (defined $language_fields{$field}) {

			foreach my $param_lang (@param_langs) {
				my $field_lc = $field . '_' . $param_lang;
				if (defined single_param($field_lc)) {

					# Do not allow edits / removal through API for data provided by producers (only additions for non existing fields)
					if (($protected_data) and (defined $product_ref->{$field_lc}) and ($product_ref->{$field_lc} ne ""))
					{
						$log->debug("producer data already exists for field, skip empty value",
							{field_lc => $field_lc, code => $code, existing_value => $product_ref->{$field_lc}})
						  if $log->is_debug();
					}
					else {

						$product_ref->{$field_lc} = remove_tags_and_quote(decode utf8 => single_param($field_lc));
						compute_field_tags($product_ref, $lc, $field_lc);
					}
				}
			}
		}
	}

	if (    (defined $product_ref->{nutriments}{"carbon-footprint"})
		and ($product_ref->{nutriments}{"carbon-footprint"} ne ''))
	{
		push @{$product_ref->{"labels_hierarchy"}}, "en:carbon-footprint";
		push @{$product_ref->{"labels_tags"}}, "en:carbon-footprint";
	}

	# For fields that can have different values in different languages, copy the main language value to the non suffixed field

	foreach my $field (keys %language_fields) {
		if ($field !~ /_image/) {
			if (defined $product_ref->{$field . "_$product_ref->{lc}"}) {
				$product_ref->{$field} = $product_ref->{$field . "_$product_ref->{lc}"};
			}
		}
	}

	compute_languages($product_ref);    # need languages for allergens detection and cleaning ingredients

	# Ingredients classes
	clean_ingredients_text($product_ref);
	extract_ingredients_from_text($product_ref);
	extract_ingredients_classes_from_text($product_ref);
	detect_allergens_from_text($product_ref);

	# Food category rules for sweeetened/sugared beverages
	# French PNNS groups from categories

	if ((defined $options{product_type}) and ($options{product_type} eq "food")) {
		ProductOpener::Food::special_process_product($product_ref);
	}

	# Nutrition data

	# Do not allow nutrition edits through API for data provided by producers
	if (($protected_data) and (defined $product_ref->{"nutriments"})) {
		print STDERR
		  "product_jqm_multilingual.pm - code: $code - nutrition data provided by producer exists, skip nutrients\n";
	}
	else {
		assign_nutriments_values_from_request_parameters($product_ref, $nutriment_table);
	}

	# Compute nutrition data per 100g and per serving

	$log->trace("compute_serving_size_date") if ($admin and $log->is_trace());

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

	$log->info("saving product", {code => $code}) if ($log->is_info() and not $log->is_debug());
	$log->debug("saving product", {code => $code, product => $product_ref})
	  if ($log->is_debug() and not $log->is_info());

	$product_ref->{interface_version_modified} = $interface_version;

	my $time = time();
	$comment = $comment . remove_tags_and_quote(decode utf8 => single_param('comment'));
	if (store_product($User_id, $product_ref, $comment)) {
		# Notify robotoff
		send_notification_for_product_change($product_ref, "updated");

		$response{status} = 1;
		$response{status_verbose} = 'fields saved';
	}
	else {
		$response{status} = 0;
		$response{status_verbose} = 'not modified';
	}
}

my $data = encode_json(\%response);

print header(-type => 'application/json', -charset => 'utf-8', -access_control_allow_origin => '*') . $data;

exit(0);

