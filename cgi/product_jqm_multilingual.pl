#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2025 Association Open Food Facts
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

=head1 NAME

product_jqm_multilingual.pl - implementation of the product WRITE API v0, v1 and v2

=head1 DESCRIPTION

This CGI script is v0 to v2 of the Product WRITE API.

API v3 is handled by a different /api/v3/product route, implemented in APIProductWrite.pm

=cut

use ProductOpener::PerlStandards;

use CGI::Carp qw(fatalsToBrowser);

use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/%BASE_DIRS ensure_dir_created/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::HTTP qw/write_cors_headers single_param/;
use ProductOpener::Tags qw/%language_fields %tags_fields add_tags_to_field compute_field_tags/;
use ProductOpener::URL qw/format_subdomain/;
use ProductOpener::Users qw/$Org_id $Owner_id $User_id %User/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Lang qw/$lc %lang_lc/;
use ProductOpener::Mail qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Food qw/assign_nutriments_values_from_request_parameters/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::DataQuality qw/:all/;
use ProductOpener::EnvironmentalScore qw/:all/;
use ProductOpener::Packaging qw/:all/;
use ProductOpener::ForestFootprint qw/:all/;
use ProductOpener::Text qw/remove_tags_and_quote/;
use ProductOpener::API qw/get_initialized_response check_user_permission/;
use ProductOpener::APIProductWrite
	qw/process_change_product_type_request_if_we_have_one process_change_product_code_request_if_we_have_one skip_protected_field/;

use Apache2::RequestRec ();
use Apache2::Const ();

use CGI qw/:cgi :form :cgi-lib escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::MaybeXS;
use Log::Any qw($log);

my $request_ref = ProductOpener::Display::init_request();

# Response structure to keep track of warnings and errors
# Note: currently some warnings and errors are added,
# but we do not yet do anything with them
my $response_ref = get_initialized_response();

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

if (not defined $User_id) {
	$log->info("no user credentials", {code => $code, original_code => $original_code}) if $log->is_info();
	$response{status} = 0;
	$response{status_verbose} = 'no user credentials';
}
elsif (not is_valid_code($code)) {

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
	else {
		# There is an existing product
		# If the product has a product_type and it is not the product_type of the server, redirect to the correct server
		# unless we are on the pro platform

		if (    (not $server_options{private_products})
			and (defined $product_ref->{product_type})
			and ($product_ref->{product_type} ne $options{product_type}))
		{
			redirect_to_url($request_ref, 307,
				format_subdomain($subdomain, $product_ref->{product_type}) . '/cgi/product_jqm.pl?code=' . $code);
		}
	}

	# Process edit rules

	$log->debug("phase 0 - checking edit rules", {code => $code}) if $log->is_debug();

	my $proceed_with_edit = process_product_edit_rules($product_ref);

	$log->debug("phase 0", {code => $code, proceed_with_edit => $proceed_with_edit}) if $log->is_debug();

	if (not $proceed_with_edit) {

		$response{status} = 0;
		$response{status_verbose} = 'Edit against edit rules';

		my $data = encode_json(\%response);
		write_cors_headers();
		print header(-type => 'application/json', -charset => 'utf-8') . $data;

		exit(0);
	}

	exists $product_ref->{new_server} and delete $product_ref->{new_server};

	my @errors = ();

	# Store parameters for debug purposes
	ensure_dir_created($BASE_DIRS{CACHE_DEBUG}) or display_error_and_exit($request_ref, "Missing path", 503);
	open(my $out, ">", "$BASE_DIRS{CACHE_DEBUG}/product_jqm_multilingual." . time() . "." . $code);
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

	# Change code or product type

	push @errors,
		process_change_product_code_request_if_we_have_one($request_ref, $response_ref, $product_ref,
		single_param("new_code"));
	$code = $product_ref->{code};

	push @errors,
		process_change_product_type_request_if_we_have_one($request_ref, $response_ref, $product_ref,
		single_param("product_type"));

	# Display an error message and exit if we have a fatal error (no permission to change barcode or product type, or invalid barcode or product type)
	if ($#errors >= 0) {
		$response{status} = 0;
		$response{status_verbose} = join(",", @errors);

		my $data = encode_json(\%response);

		write_cors_headers();
		print header(-type => 'application/json', -charset => 'utf-8') . $data;

		exit(0);
	}

	#my @app_fields = qw(product_name brands quantity);
	my @app_fields
		= qw(product_name generic_name quantity packaging brands categories labels origins manufacturing_places emb_codes link expiration_date purchase_places stores countries  );

	# admin field to set a creator
	if ($request_ref->{admin}) {
		push @app_fields, "creator";
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
			next;
		}

		if (defined single_param($field)) {

			# Only moderators can update values for fields sent by the producer
			if (skip_protected_field($product_ref, $field, $User{moderator})) {
				next;
			}

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
			elsif ($field eq "environmental_score_extended_data") {
				# we expect a JSON value
				if (defined single_param($field)) {
					$product_ref->{$field} = decode_json(single_param($field));
				}
			}
			else {
				$product_ref->{$field} = preprocess_product_field($field, decode utf8 => single_param($field));

				# If we have a language specific field like "ingredients_text" without a language code suffix
				# we assume it is in the language of the interface
				if (defined $language_fields{$field}) {
					my $field_lc = $field . "_" . $lc;
					$product_ref->{$field_lc} = $product_ref->{$field};
					delete $product_ref->{$field};
				}

				compute_field_tags($product_ref, $lc, $field);
			}
		}

		if (defined $language_fields{$field}) {

			foreach my $param_lang (@param_langs) {
				my $field_lc = $field . '_' . $param_lang;
				if (defined single_param($field_lc)) {

					# Only moderators can update values for fields sent by the producer
					if (skip_protected_field($product_ref, $field_lc, $User{moderator})) {
						next;
					}

					$product_ref->{$field_lc} = remove_tags_and_quote(decode utf8 => single_param($field_lc));
					compute_field_tags($product_ref, $lc, $field_lc);
				}
			}
		}
	}

	# Nutrition data

	assign_nutriments_values_from_request_parameters($product_ref, $nutriment_table, $User{moderator});

	analyze_and_enrich_product_data($product_ref, $response_ref);

	$log->info("saving product", {code => $code}) if ($log->is_info() and not $log->is_debug());
	$log->debug("saving product", {code => $code, product => $product_ref})
		if ($log->is_debug() and not $log->is_info());

	$product_ref->{interface_version_modified} = $interface_version;

	my $time = time();
	$comment = $comment . remove_tags_and_quote(decode utf8 => single_param('comment'));
	if (store_product($User_id, $product_ref, $comment)) {
		$response{status} = 1;
		$response{status_verbose} = 'fields saved';
	}
	else {
		$response{status} = 0;
		$response{status_verbose} = 'not modified';
	}
}

my $data = encode_json(\%response);

write_cors_headers();
print header(-type => 'application/json', -charset => 'utf-8') . $data;

exit(0);

