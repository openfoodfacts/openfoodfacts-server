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

use CGI::Carp qw(fatalsToBrowser);

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Web qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Mail qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::Units qw/:all/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::KnowledgePanels qw/:all/;
use ProductOpener::KnowledgePanelsContribution qw/:all/;
use ProductOpener::URL qw/:all/;
use ProductOpener::DataQuality qw/:all/;
use ProductOpener::Ecoscore qw/:all/;
use ProductOpener::Packaging qw/:all/;
use ProductOpener::ForestFootprint qw/:all/;
use ProductOpener::Web qw(get_languages_options_list);
use ProductOpener::Text qw/:all/;
use ProductOpener::Events qw/:all/;
use ProductOpener::API qw/:all/;
use ProductOpener::APIProductWrite qw/:all/;

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

# Function to display a form to add a product with a specific barcode (either typed in a field, or extracted from a barcode photo)
# or without a barcode

sub display_search_or_add_form() {

	# Producer platform and no org or not admin: do not offer to add products
	if (($server_options{producers_platform})
		and not((defined $Owner_id) and (($Owner_id =~ /^org-/) or ($User{moderator}) or $User{pro_moderator})))
	{
		display_error_and_exit(lang("no_owner_defined"), 200);
	}

	my $html = '';
	my $template_data_ref_content = {};

	$template_data_ref_content->{display_search_image_form} = display_search_image_form("block_side");
	process_template('web/common/includes/display_product_search_or_add.tt.html', $template_data_ref_content, \$html)
		|| ($html = "template error: " . $tt->error());

	# Producers platform: display an addition import products block

	if ($server_options{producers_platform}) {
		my $html_producer = '';
		my $template_data_ref_content_producer = {};

		process_template(
			'web/common/includes/display_product_search_or_add_producer.tt.html',
			$template_data_ref_content_producer,
			\$html_producer
		) || ($html_producer = "template error: " . $tt->error());

		$html .= $html_producer;
	}

	return $html;
}

=head2 create_packaging_components_from_request_parameters($product_ref)

Read form parameters related to packaging components, and create the corresponding packagings structure.

=cut

sub create_packaging_components_from_request_parameters ($product_ref) {

	# Check that the form is showing inputs for packaging components
	if (not defined single_param("packaging_max")) {
		return;
	}

	# The form contains packaging inputs, so we reset the packagings structure
	$product_ref->{packagings} = [];

	# And then we add each packaging component
	for (my $packaging_id = 1; $packaging_id <= single_param("packaging_max"); $packaging_id++) {

		my $input_packaging_ref = {};
		my $prefix = "packaging_" . $packaging_id . "_";
		foreach my $property (
			"number_of_units", "shape", "material", "recycling",
			"quantity_per_unit", "weight_measured", "weight_specified"
			)
		{
			$input_packaging_ref->{$property} = remove_tags_and_quote(decode utf8 => single_param($prefix . $property));
		}

		my $response_ref = {};   # Currently unused, may be used to display warnings in future versions of the interface

		my $packaging_ref
			= get_checked_and_taxonomized_packaging_component_data($lc, $input_packaging_ref, $response_ref);

		if (defined $packaging_ref) {
			apply_rules_to_augment_packaging_component_data($product_ref, $packaging_ref);

			push @{$product_ref->{packagings}}, $packaging_ref;

			$log->debug(
				"added a packaging component",
				{
					prefix => $prefix,
					packaging_id => $packaging_id,
					input_packaging => $input_packaging_ref,
					packaging => $packaging_ref
				}
			) if $log->is_debug();
		}
	}

	if (single_param("packagings_complete")) {
		$product_ref->{packagings_complete} = 1;
	}
	else {
		$product_ref->{packagings_complete} = 0;
	}

	return;
}

my $request_ref = ProductOpener::Display::init_request();

if ($User_id eq 'unwanted-user-french') {
	display_error_and_exit(
		"<b>Il y a des problèmes avec les modifications de produits que vous avez effectuées. Ce compte est temporairement bloqué, merci de nous contacter.</b>",
		403
	);
}

# Response structure to keep track of warnings and errors
# Note: currently some warnings and errors are added,
# but we do not yet do anything with them
my $response_ref = get_initialized_response();

my $type = single_param('type') || 'search_or_add';
my $action = single_param('action') || 'display';

my $comment = 'Modification : ';

my @errors = ();

my $html = '';
my $code = normalize_code(single_param('code'));
my $product_id;

my $product_ref = undef;

my $interface_version = '20190830';

local $log->context->{type} = $type;
local $log->context->{action} = $action;

my $template_data_ref = {};

$log->debug("product_multilingual - start", {code => $code, type => $type, action => $action}) if $log->is_debug();

# Search or add product
if ($type eq 'search_or_add') {

	if ($action eq "display") {

		my $title = lang("add_product");

		$html = display_search_or_add_form();

		$request_ref->{title} = lang('add_product');
		$request_ref->{content_ref} = \$html;
		display_page($request_ref);
		exit();
	}
	else {

		# barcode in image?
		my $filename;
		if ((not defined $code) or ($code eq "")) {
			$code = process_search_image_form(\$filename);
		}
		elsif ($code !~ /^\d{4,24}$/) {
			display_error_and_exit($Lang{invalid_barcode}{$lang}, 403);
		}

		my $r = Apache2::RequestUtil->request();
		my $method = $r->method();
		if (    (not defined $code)
			and ((not defined single_param("imgupload_search")) or (single_param("imgupload_search") eq ''))
			and ($method eq 'POST'))
		{

			($code, $product_id) = assign_new_code();
			$log->debug("assigned new code", {code => $code, product_id => $product_id}) if $log->is_debug();
		}

		my %data = ();
		my $location;

		if (defined $code) {
			$data{code} = $code;
			$product_id = product_id_for_owner($Owner_id, $code);
			$log->debug("we have a code", {code => $code, product_id => $product_id}) if $log->is_debug();

			$product_ref = product_exists($product_id);    # returns 0 if not

			if ($product_ref) {
				$log->info("product exists, redirecting to page", {code => $code}) if $log->is_info();
				$location = product_url($product_ref);

				# jquery.fileupload ?
				if (single_param('jqueryfileupload')) {

					$type = 'show';
				}
				else {
					my $r = shift;
					$r->headers_out->set(Location => $location);
					$r->status(301);
					return 301;
				}
			}
			else {
				$log->info("product does not exist, creating product", {code => $code, product_id => $product_id})
					if $log->is_info();
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
					process_image_upload($product_ref->{_id}, $filename, $User_id, time(),
						'image with barcode from web site Add product button',
						\$imgid, \$debug);
				}
			}
		}
		else {
			if (defined single_param("imgupload_search")) {
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
		if (single_param('jqueryfileupload')) {

			my $data = encode_json(\%data);

			$log->debug("jqueryfileupload JSON data output", {data => $data}) if $log->is_debug();

			print header(-type => 'application/json', -charset => 'utf-8') . $data;
			exit();
		}

		$template_data_ref->{param_imgupload_search} = single_param("imgupload_search");
	}
}

else {
	# We should have a code
	if ((not defined $code) or ($code eq '')) {
		display_error_and_exit($Lang{missing_barcode}{$lang}, 403);
	}
	elsif ($code !~ /^\d{4,24}$/) {
		display_error_and_exit($Lang{invalid_barcode}{$lang}, 403);
	}
	else {
		if (    ((defined $server_options{private_products}) and ($server_options{private_products}))
			and (not defined $Owner_id))
		{

			display_error_and_exit(lang("no_owner_defined"), 200);
		}
		$product_id = product_id_for_owner($Owner_id, $code);
		$product_ref = retrieve_product_or_deleted_product($product_id, $User{moderator});
		if (not defined $product_ref) {
			display_error_and_exit(sprintf(lang("no_product_for_barcode"), $code), 404);
		}
	}
}

if (($type eq 'delete') and (not $User{moderator})) {
	display_error_and_exit($Lang{error_no_permission}{$lang}, 403);
}

if ($User_id eq 'unwanted-bot-id') {
	my $r = Apache2::RequestUtil->request();
	$r->status(500);
	return 500;
}

if (($type eq 'add') or ($type eq 'edit') or ($type eq 'delete')) {

	if (not defined $User_id) {

		my $submit_label = "login_and_" . $type . "_product";
		$action = 'login';
		$template_data_ref->{type} = $type;
	}
}

$template_data_ref->{user_id} = $User_id;
$template_data_ref->{code} = $code;
process_template('web/pages/product_edit/product_edit_form.tt.html', $template_data_ref, \$html)
	or $html = "<p>" . $tt->error() . "</p>";

my @fields = @ProductOpener::Config::product_fields;

if ($admin) {

	# Let admins edit any other fields
	if (defined single_param("fields")) {
		push @fields, split(/,/, single_param("fields"));
	}
}

if (($action eq 'process') and (($type eq 'add') or ($type eq 'edit'))) {

	# Process edit rules

	$log->debug("phase 0 - checking edit rules", {code => $code, type => $type}) if $log->is_debug();

	my $proceed_with_edit = process_product_edit_rules($product_ref);

	$log->debug("phase 0", {code => $code, type => $type, proceed_with_edit => $proceed_with_edit}) if $log->is_debug();

	if (not $proceed_with_edit) {

		display_error_and_exit("Edit against edit rules", 403);
	}

	$log->debug("phase 1", {code => $code, type => $type}) if $log->is_debug();

	exists $product_ref->{new_server} and delete $product_ref->{new_server};

	# 26/01/2017 - disallow barcode changes until we fix bug #677
	if ($User{moderator} and (defined single_param("new_code")) and (single_param("new_code") ne "")) {

		change_product_server_or_code($product_ref, single_param("new_code"), \@errors);
		$code = $product_ref->{code};
	}

	my @param_fields = ();

	my @param_sorted_langs = ();
	my %param_sorted_langs = ();
	if (defined single_param("sorted_langs")) {
		foreach my $display_lc (split(/,/, single_param("sorted_langs"))) {
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
	if (    (defined single_param("lang"))
		and (single_param("lang") =~ /^\w\w$/)
		and (not defined $param_sorted_langs{single_param("lang")}))
	{
		push @param_sorted_langs, single_param("lang");
	}

	$product_ref->{"debug_param_sorted_langs"} = \@param_sorted_langs;

	foreach my $field ('product_name', 'generic_name', @fields, 'nutrition_data_per', 'nutrition_data_prepared_per',
		'serving_size', 'allergens', 'traces', 'ingredients_text', 'origin', 'packaging_text', 'lang')
	{

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

		my $product_lc = single_param("lang");

		foreach my $from_lc (@param_sorted_langs) {

			my $moveid = "move_" . $from_lc . "_data_and_images_to_main_language";

			if (($from_lc ne $product_lc) and (defined single_param($moveid)) and (single_param($moveid) eq "on")) {

				my $mode = single_param($moveid . "_mode") || "replace";

				$log->debug(
					"moving all data and photos from one language to another",
					{from_lc => $from_lc, product_lc => $product_lc, mode => $mode}
				) if $log->is_debug();

				# Text fields

				foreach my $field (sort keys %language_fields) {

					my $from_field = $field . "_" . $from_lc;
					my $to_field = $field . "_" . $product_lc;

					my $from_value = single_param($from_field);

					$log->debug("moving field value?",
						{from_field => $from_field, from_value => $from_value, to_field => $to_field})
						if $log->is_debug();

					if ((defined $from_value) and ($from_value ne "")) {

						my $to_value = single_param($to_field);

						$log->debug(
							"moving field value",
							{
								from_field => $from_field,
								from_value => $from_value,
								to_field => $to_field,
								to_value => $to_value,
								mode => $mode
							}
						) if $log->is_debug();

						if (($mode eq "replace") or ((not defined $to_value) or ($to_value eq ""))) {

							$log->debug(
								"replacing to field value",
								{
									from_field => $from_field,
									from_value => $from_value,
									to_field => $to_field,
									to_value => $to_value,
									mode => $mode
								}
							) if $log->is_debug();

							param($to_field, $from_value);
						}

						$log->debug(
							"deleting from field value",
							{
								from_field => $from_field,
								from_value => $from_value,
								to_field => $to_field,
								to_value => $to_value,
								mode => $mode
							}
						) if $log->is_debug();

						param($from_field, "");
					}
				}

				# Selected photos

				foreach my $imageid ("front", "ingredients", "nutrition", "packaging") {

					my $from_imageid = $imageid . "_" . $from_lc;
					my $to_imageid = $imageid . "_" . $product_lc;

					if ((defined $product_ref->{images}) and (defined $product_ref->{images}{$from_imageid})) {

						$log->debug("moving selected image", {from_imageid => $from_imageid, to_imageid => $to_imageid})
							if $log->is_debug();

						if (($mode eq "replace") or (not defined $product_ref->{images}{$to_imageid})) {

							$product_ref->{images}{$to_imageid} = $product_ref->{images}{$from_imageid};
							my $rev = $product_ref->{images}{$from_imageid}{rev};

							# Rename the images

							my $path = product_path($product_ref);

							foreach my $max ($thumb_size, $small_size, $display_size, "full") {
								my $from_file
									= "$www_root/images/products/$path/"
									. $from_imageid . "."
									. $rev . "."
									. $max . ".jpg";
								my $to_file
									= "$www_root/images/products/$path/"
									. $to_imageid . "."
									. $rev . "."
									. $max . ".jpg";
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
			else {
				# infocards set by admins can contain HTML
				if (($admin) and ($field =~ /infocard/)) {
					$product_ref->{$field} = decode utf8 => single_param($field);
				}
				else {
					# Preprocesses fields to remove email values as entries
					$product_ref->{$field} = preprocess_product_field($field, decode utf8 => single_param($field));
				}
			}

			$log->debug("before compute field_tags",
				{code => $code, field_name => $field, field_value => $product_ref->{$field}})
				if $log->is_debug();
			if ($field =~ /ingredients_text/) {
				# the ingredients_text_with_allergens[_$lc] will be recomputed after
				my $ingredients_text_with_allergens = $field;
				$ingredients_text_with_allergens =~ s/ingredients_text/ingredients_text_with_allergens/;
				delete $product_ref->{$ingredients_text_with_allergens};
			}

			compute_field_tags($product_ref, $lc, $field);

		}
		else {
			$log->debug("could not find field in params", {field => $field}) if $log->is_debug();
		}
	}

	# Obsolete products

	# We test if the "obsolete_since_date" field is present, as the checkbox field won't be sent if the box is unchecked
	if (($User{moderator} or $Owner_id) and (defined single_param('obsolete_since_date'))) {
		# We need to temporarily record if the product was obsolete, so that we can remove it
		# from the product or product_obsolete collection if its obsolete status changed
		$product_ref->{was_obsolete} = $product_ref->{obsolete};
		$product_ref->{obsolete} = remove_tags_and_quote(decode utf8 => single_param("obsolete"));
		$product_ref->{obsolete_since_date} = remove_tags_and_quote(decode utf8 => single_param("obsolete_since_date"));
	}

	# Update the nutrients

	assign_nutriments_values_from_request_parameters($product_ref, $nutriment_table, $User{moderator});

	# Process packaging components
	create_packaging_components_from_request_parameters($product_ref);

	# product check

	if ($User{moderator}) {

		my $checked = remove_tags_and_quote(decode utf8 => single_param("photos_and_data_checked"));
		if ((defined $checked) and ($checked eq 'on')) {
			if ((defined $product_ref->{checked}) and ($product_ref->{checked} eq 'on')) {
				my $rechecked = remove_tags_and_quote(decode utf8 => single_param("photos_and_data_rechecked"));
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

	analyze_and_enrich_product_data($product_ref, $response_ref);

	if ($#errors >= 0) {
		$action = 'display';
	}
}

# Display the product edit form

my %remember_fields = ('purchase_places' => 1, 'stores' => 1);

# Display each field

sub display_input_field ($product_ref, $field, $language) {
	# $field can be in %language_fields and suffixed by _[lc]

	my $fieldtype = $field;
	my $display_lc = $lc;
	my @field_notes;

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
			$autocomplete = "$formatted_subdomain/api/v3/taxonomy_suggestions?tagtype=$fieldtype";
		}
	}

	my $value = $product_ref->{$field};

	if (
			(defined $value)
		and (defined $taxonomy_fields{$field})
		# if the field was previously not taxonomized, the $field_hierarchy field does not exist
		and (defined $product_ref->{$field . "_hierarchy"})
		)
	{
		$value = display_tags_hierarchy_taxonomy($lc, $field, $product_ref->{$field . "_hierarchy"});
		# Remove tags
		$value =~ s/<(([^>]|\n)*)>//g;
	}
	if (not defined $value) {
		$value = "";
	}

	$template_data_ref_field->{language} = $language;
	$template_data_ref_field->{field} = $field;
	$template_data_ref_field->{class} = $class;
	$template_data_ref_field->{value} = $value;
	$template_data_ref_field->{display_lc} = $display_lc;
	$template_data_ref_field->{autocomplete} = $autocomplete;
	$template_data_ref_field->{fieldtype} = $Lang{$fieldtype}{$lang};

	my $html_field = '';

	if (($field =~ /infocard/) or ($field =~ /^packaging_text/)) {

	}
	else {
		# Line feeds will be removed in text inputs, convert them to spaces
		$value =~ s/\n/ /g;
	}

	foreach my $note ("_note", "_note_2", "_note_3") {
		if (defined $Lang{$fieldtype . $note}{$lang}) {

			push(
				@field_notes,
				{
					note => $Lang{$fieldtype . $note}{$lang},
				}
			);

		}
	}

	$template_data_ref_field->{field_notes} = \@field_notes;

	if (defined $Lang{$fieldtype . "_example"}{$lang}) {

		my $examples = $Lang{example}{$lang};
		if ($Lang{$fieldtype . "_example"}{$lang} =~ /,/) {
			$examples = $Lang{examples}{$lang};
		}
		$template_data_ref_field->{examples} = $examples;
		$template_data_ref_field->{field_type_examples} = $Lang{$fieldtype . "_example"}{$lang};
	}

	process_template('web/pages/product_edit/display_input_field.tt.html', $template_data_ref_field, \$html_field)
		or $html_field = "<p>" . $tt->error() . "</p>";

	return $html_field;
}

if (($action eq 'display') and (($type eq 'add') or ($type eq 'edit'))) {

	# Populate the energy-kcal or energy-kj field from the energy field if it exists
	compute_serving_size_data($product_ref);

	my $template_data_ref_display = {};
	my $js;

	$log->debug("displaying product", {code => $code}) if $log->is_debug();

	# Lang strings for product.js

	my $moderator = 0;
	if ($User{moderator}) {
		$moderator = 1;
	}

	$header .= <<HTML
<link rel="stylesheet" type="text/css" href="/css/dist/cropper.css" />
<link rel="stylesheet" type="text/css" href="/css/dist/tagify.css" />
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
<script type="text/javascript" src="/js/dist/product-multilingual.js?v=$file_timestamps{'js/dist/product-multilingual.js'}"></script>

HTML
		;

	my $thumb_selectable_size = $thumb_size + 20;

	$styles .= <<CSS
.ui-selectable li {
	margin: 3px;
	padding: 0px;
	float: left;
	width: ${thumb_selectable_size}px;
	height: ${thumb_selectable_size}px;
	line-height: ${thumb_selectable_size}px;
	text-align: center;
}
.show_for_manage_images {
	line-height:normal;
	font-weight:normal;
	font-size:0.8rem;
}
.select_manage .ui-selectable li { 
	height: 180px
}
CSS
		;

	if (    (not((defined $server_options{private_products}) and ($server_options{private_products})))
		and (defined $Org_id))
	{
		# Display a link to the producers platform
		$template_data_ref_display->{producers_platform_url} = $producers_platform_url;
	}

	$template_data_ref_display->{errors_index} = $#errors;
	$template_data_ref_display->{errors} = \@errors;

	my $label_new_code = $Lang{new_code}{$lang};

	# 26/01/2017 - disallow barcode changes until we fix bug #677
	if ($User{moderator}) {
	}

	$template_data_ref_display->{org_id} = $Org_id;
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
		$template_data_ref_display->{display_field_obsolete}
			= display_input_field($product_ref, "obsolete_since_date", undef);

	}

	# Main language
	my $lang_value = $lang;
	if (defined $product_ref->{lc}) {
		$lang_value = $product_ref->{lc};
	}

	$template_data_ref_display->{product_lang_value} = $lang_value;
	# List of all languages for the template to display a dropdown for fields that are language specific
	$template_data_ref_display->{lang_options} = get_languages_options_list($lc);
	$template_data_ref_display->{display_select_manage} = display_select_manage($product_ref);

	# sort function to put main language first, other languages by alphabetical order, then add new language tab

	defined $product_ref->{lc} or $product_ref->{lc} = $lc;
	defined $product_ref->{languages_codes} or $product_ref->{languages_codes} = {};

	$product_ref->{sorted_langs} = [$product_ref->{lc}];

	foreach my $olc (sort keys %{$product_ref->{languages_codes}}) {
		if ($olc ne $product_ref->{lc}) {
			push @{$product_ref->{sorted_langs}}, $olc;
		}
	}

	$template_data_ref_display->{product_ref_sorted_langs} = join(',', @{$product_ref->{sorted_langs}});

	sub display_input_tabs ($product_ref, $tabsid, $tabsids_array_ref, $tabsids_hash_ref, $fields_array_ref) {

		my $template_data_ref_tab = {};
		my @display_tabs;

		$template_data_ref_tab->{tabsid} = $tabsid;

		my $active = " active";

		foreach my $tabid (@$tabsids_array_ref, 'new_lc', 'new') {

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

				$language = display_taxonomy_tag($lc, 'languages', $language_codes{$tabid})
					;    # instead of $tabsids_hash_ref->{$tabid}
				$display_tab_ref->{language} = $language;

				my $display_lc = $tabid;
				$template_data_ref_tab->{display_lc} = $display_lc;

				foreach my $field (@{$fields_array_ref}) {

					# For the ingredient_text field, we will output a div above to display the image of the ingredients
					my $image_full_id;
					my $display_div;

					if ($field =~ /^(.*)_image/) {

						my $image_field = $1 . "_" . $display_lc;
						$display_div = display_select_crop($product_ref, $image_field, $language);
					}
					elsif ($field eq 'ingredients_text') {
						$image_full_id = "ingredients_" . ${display_lc} . "_image_full";
						$display_div = display_input_field($product_ref, $field . "_" . $display_lc, $language);
					}
					else {
						$log->debug("display_field", {field_name => $field, field_value => $product_ref->{$field}})
							if $log->is_debug();
						$display_div = display_input_field($product_ref, $field . "_" . $display_lc, $language);
					}

					push(
						@fields_arr,
						{
							image_full_id => $image_full_id,
							field => $field,
							display_div => $display_div,
						}
					);
				}

				$display_tab_ref->{fields} = \@fields_arr;
			}

			# For moderators, add a checkbox to move all data and photos to the main language
			# this needs to be below the "add (language name) in all field labels" above, so that it does not change this label.
			if (($User{moderator}) and ($tabsid eq "front_image")) {

				my $msg = f_lang(
					"f_move_data_and_photos_to_main_language",
					{
						language => '<span class="tab_language">' . $language . '</span>',
						main_language => '<span class="main_language">'
							. lang("lang_" . $product_ref->{lc})
							. '</span>'
					}
				);

				my $moveid = "move_" . $tabid . "_data_and_images_to_main_language";

				$display_tab_ref->{moveid} = $moveid;
				$display_tab_ref->{msg} = $msg;
			}

			push(@display_tabs, $display_tab_ref);

			# Only the first tab is active
			$active = "";

		}

		$template_data_ref_tab->{display_tabs} = \@display_tabs;

		my $html_tab = '';
		process_template('web/pages/product_edit/display_input_tabs.tt.html', $template_data_ref_tab, \$html_tab)
			or $html_tab = "<p>" . $tt->error() . "</p>";

		return $html_tab;
	}

	$template_data_ref_display->{display_tab_product_picture}
		= display_input_tabs($product_ref, "front_image", $product_ref->{sorted_langs}, \%Langs, ["front_image"]);
	$template_data_ref_display->{display_tab_product_characteristics}
		= display_input_tabs($product_ref, "product", $product_ref->{sorted_langs},
		\%Langs, ["product_name", "generic_name"]);

	my @display_fields_arr;
	foreach my $field (@fields) {
		# hide packaging field & origins are now displayed below allergens and traces in the ingredients section
		next if $field eq "origins" || $field eq "packaging";
		$log->debug("display_field", {field_name => $field, field_value => $product_ref->{$field}}) if $log->is_debug();
		my $display_field = display_input_field($product_ref, $field, undef);
		push(@display_fields_arr, $display_field);
	}

	$template_data_ref_display->{display_fields_arr} = \@display_fields_arr;
	my @ingredients_fields = ("ingredients_image", "ingredients_text", "origin");

	my $checked = '';
	my $tablestyle = 'display: table;';
	my $disabled = '';
	if ((defined $product_ref->{no_nutrition_data}) and ($product_ref->{no_nutrition_data} eq 'on')) {
		$checked = 'checked="checked"';
		$tablestyle = 'display: none;';
		$disabled = 'disabled="disabled"';
	}

	$template_data_ref_display->{nutrition_checked} = $checked;
	$template_data_ref_display->{display_tab_ingredients_image}
		= display_input_tabs($product_ref, "ingredients_image", $product_ref->{sorted_langs},
		\%Langs, \@ingredients_fields);
	$template_data_ref_display->{display_field_allergens} = display_input_field($product_ref, "allergens", undef);
	$template_data_ref_display->{display_field_traces} = display_input_field($product_ref, "traces", undef);
	$template_data_ref_display->{display_field_origins} = display_input_field($product_ref, "origins", undef);
	$template_data_ref_display->{display_tab_nutrition_image}
		= display_input_tabs($product_ref, "nutrition_image", $product_ref->{sorted_langs}, \%Langs,
		["nutrition_image"]);
	$template_data_ref_display->{display_field_serving_size} = display_input_field($product_ref, "serving_size", undef);

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

		if (
			($product_ref->{$nutrition_data_per} eq 'serving')
			# display by serving by default for the prepared product
			or (($product_type eq '_prepared') and (not defined $product_ref->{nutrition_data_prepared_per}))
			)
		{
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

		push(
			@nutrition_products,
			{
				checked => $checked,
				nutrition_data => $nutrition_data,
				nutrition_data_exists => $Lang{$nutrition_data_exists}{$lang},
				nutrition_data_per => $nutrition_data_per,
				checked_per_100g => $checked_per_100g,
				checked_per_serving => $checked_per_serving,
				nutrition_data_instructions => $nutrition_data_instructions,
				nutrition_data_instructions_check => $Lang{$nutrition_data_instructions},
				nutrition_data_instructions_lang => $Lang{$nutrition_data_instructions}{$lang},
				hidden => $hidden,
				nutriment_col_class => $nutriment_col_class,
				product_type_as_sold_or_prepared => $product_type_as_sold_or_prepared,
				checkmate => $product_ref->{$nutrition_data_per},
			}
		);

	}

	$template_data_ref_display->{nutrition_products} = \@nutrition_products;

	$template_data_ref_display->{column_display_style_nutrition_data} = $column_display_style{"nutrition_data"};
	$template_data_ref_display->{column_display_style_nutrition_data_prepared}
		= $column_display_style{"nutrition_data_prepared"};
	$template_data_ref_display->{nutrition_data_100g_style} = $nutrition_data_per_display_style{"nutrition_data_100g"};
	$template_data_ref_display->{nutrition_data_serving_style}
		= $nutrition_data_per_display_style{"nutrition_data_serving"};
	$template_data_ref_display->{nutrition_data_prepared_100g_style}
		= $nutrition_data_per_display_style{"nutrition_data_prepared_100g"};
	$template_data_ref_display->{nutrition_data_prepared_serving_style}
		= $nutrition_data_per_display_style{"nutrition_data_prepared_serving"};

	$template_data_ref_display->{tablestyle} = $tablestyle;

	defined $product_ref->{nutriments} or $product_ref->{nutriments} = {};

	my @unknown_nutriments = ();
	my %seen_unknown_nutriments = ();
	foreach my $nid (keys %{$product_ref->{nutriments}}) {

		next if (($nid =~ /_/) and ($nid !~ /_prepared$/));

		$nid =~ s/_prepared$//;

		$log->trace("detect unknown nutriment", {nid => $nid}) if $log->is_trace();

		if (    (not exists_taxonomy_tag("nutrients", "zz:$nid"))
			and (defined $product_ref->{nutriments}{$nid . "_label"})
			and (not defined $seen_unknown_nutriments{$nid}))
		{
			push @unknown_nutriments, $nid;
			$log->debug("unknown nutriment detected", {nid => $nid}) if $log->is_debug();
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

		if (
			   ($nutriment !~ /-$/)
			or ((defined $product_ref->{nutriments}{$nid}) and ($product_ref->{nutriments}{$nid} ne ''))
			or (    (defined $product_ref->{nutriments}{$nid . "_prepared"})
				and ($product_ref->{nutriments}{$nid . "_prepared"} ne ''))
			or (    (defined $product_ref->{nutriments}{$nid . "_modifier"})
				and ($product_ref->{nutriments}{$nid . "_modifier"} eq '-'))
			or (    (defined $product_ref->{nutriments}{$nid . "_prepared_modifier"})
				and ($product_ref->{nutriments}{$nid . "_prepared_modifier"} eq '-'))
			or ($nid eq 'new_0')
			or ($nid eq 'new_1')
			)
		{
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

		$nutriment_ref->{label_value} = $product_ref->{nutriments}{$nid . "_label"};
		$nutriment_ref->{product_add_nutrient} = $Lang{product_add_nutrient}{$lang};
		$nutriment_ref->{prefix} = $prefix;

		my $unit = "g";

		if (exists_taxonomy_tag("nutrients", "zz:$nid")) {
			$nutriment_ref->{name} = display_taxonomy_tag($lc, "nutrients", "zz:$nid");
			# We may have a unit specific to the country (e.g. US nutrition facts table using the International Unit for this nutrient, and Europe using mg)
			$unit = get_property("nutrients", "zz:$nid", "unit_$cc:en")
				// get_property("nutrients", "zz:$nid", "unit:en") // 'g';
		}
		else {
			if (defined $product_ref->{nutriments}{$nid . "_unit"}) {
				$unit = $product_ref->{nutriments}{$nid . "_unit"};
			}
		}

		my $value;    # product as sold
		my $valuep;    # prepared product

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

		# If we have a user specified unit and value, use it instead of the default unit of the field
		if (defined $product_ref->{nutriments}{$nid . "_unit"}) {
			$unit = $product_ref->{nutriments}{$nid . "_unit"};
			if (defined $product_ref->{nutriments}{$nid . "_value"}) {
				$value = $product_ref->{nutriments}{$nid . "_value"};
			}

			if (defined $product_ref->{nutriments}{$nidp . "_value"}) {
				$valuep = $product_ref->{nutriments}{$nidp . "_value"};
			}
		}

		# Add modifiers
		if (defined $product_ref->{nutriments}{$nid . "_modifier"}) {

			if ($value ne '') {
				$product_ref->{nutriments}{$nid . "_modifier"} eq '<' and $value = "&lt; $value";
				$product_ref->{nutriments}{$nid . "_modifier"} eq "\N{U+2264}" and $value = "&le; $value";
				$product_ref->{nutriments}{$nid . "_modifier"} eq '>' and $value = "&gt; $value";
				$product_ref->{nutriments}{$nid . "_modifier"} eq "\N{U+2265}" and $value = "&ge; $value";
				$product_ref->{nutriments}{$nid . "_modifier"} eq '~' and $value = "~ $value";
			}
			elsif ($product_ref->{nutriments}{$nid . "_modifier"} eq '-') {
				# The - minus sign indicates that there is no value specified on the product
				$value = '-';
			}
		}

		if (defined $product_ref->{nutriments}{$nidp . "_modifier"}) {

			if ($valuep ne '') {
				$product_ref->{nutriments}{$nidp . "_modifier"} eq '<' and $valuep = "&lt; $valuep";
				$product_ref->{nutriments}{$nidp . "_modifier"} eq "\N{U+2264}" and $valuep = "&le; $valuep";
				$product_ref->{nutriments}{$nidp . "_modifier"} eq '>' and $valuep = "&gt; $valuep";
				$product_ref->{nutriments}{$nidp . "_modifier"} eq "\N{U+2265}" and $valuep = "&ge; $valuep";
				$product_ref->{nutriments}{$nidp . "_modifier"} eq '~' and $valuep = "~ $valuep";
			}
			elsif ($product_ref->{nutriments}{$nidp . "_modifier"} eq '-') {
				# The - minus sign indicates that there is no value specified on the product
				$valuep = '-';
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

			if (($nid eq 'alcohol')) {$unit = '% vol / °';}    # alcohol in % vol / °
			elsif (($nid eq 'energy-kj')) {$unit = 'kJ';}
			elsif (($nid eq 'energy-kcal')) {$unit = 'kcal';}

			$nutriment_ref->{nutriment_unit} = $unit;

		}
		else {

			my @units = ('g', 'mg', 'µg');
			my @units_arr;

			if ($nid =~ /^energy/) {
				@units = ('kJ', 'kcal');
			}
			elsif ($nid eq 'water-hardness') {
				@units = (
					'mol/l', 'mmol/l', 'mval/l', 'ppm', "\N{U+00B0}rH", "\N{U+00B0}fH",
					"\N{U+00B0}e", "\N{U+00B0}dH", 'gpg'
				);
			}

			if (   (defined get_property("nutrients", "zz:$nid", "dv_value:en"))
				or ($nid =~ /^new_/)
				or (uc($unit) eq '% DV'))
			{
				push @units, '% DV';
			}
			if (   (defined get_property("nutrients", "zz:$nid", "iu_value:en"))
				or ($nid =~ /^new_/)
				or (uc($unit) eq 'IU')
				or (uc($unit) eq 'UI'))
			{
				push @units, 'IU';
			}

			my $hide_percent = '';
			my $hide_select = '';

			if ($unit eq '') {
				$hide_percent = ' style="display:none"';
				$hide_select = ' style="display:none"';

			}
			elsif ($unit eq '%') {
				$hide_select = ' style="display:none"';
			}
			else {
				$hide_percent = ' style="display:none"';
			}

			$nutriment_ref->{hide_select} = $hide_select;
			$nutriment_ref->{hide_percent} = $hide_percent;
			$nutriment_ref->{nutriment_unit_disabled} = $disabled;

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

				push(
					@units_arr,
					{
						u => $u,
						label => $label,
						selected => $selected,
					}
				);
			}

			$nutriment_ref->{units_arr} = \@units_arr;

		}

		$nutriment_ref->{shown} = $shown;
		$nutriment_ref->{enid} = $enid;
		$nutriment_ref->{enidp} = $enidp;
		$nutriment_ref->{nid} = $nid;
		$nutriment_ref->{class} = $class;
		$nutriment_ref->{value} = $value;
		$nutriment_ref->{valuep} = $valuep;
		$nutriment_ref->{display} = $display;
		$nutriment_ref->{disabled} = $disabled;

		push(@nutriments, $nutriment_ref);
	}

	$template_data_ref_display->{nutriments} = \@nutriments;

	# Compute a list of nutrients that will not be displayed in the nutrition facts table in the product edit form
	# because they are not set for the product, and are not displayed by default in the user's country.
	# Users will be allowed to add those nutrients, and this list will be used for nutrient name autocompletion.

	my $other_nutriments = '';
	my $nutriments = '';
	foreach my $nid (@{$other_nutriments_lists{$nutriment_table}}) {
		my $other_nutriment_value = display_taxonomy_tag($lc, "nutrients", "zz:$nid");

		# Some nutrients cannot be entered directly by users, so don't suggest them
		my $automatically_computed = get_property("nutrients", "zz:$nid", "automatically_computed:en");
		next if ((defined $automatically_computed) and ($automatically_computed eq "yes"));

		if ((not defined $product_ref->{nutriments}{$nid}) or ($product_ref->{nutriments}{$nid} eq '')) {
			my $supports_iu = "false";
			if (defined get_property("nutrients", "zz:$nid", "iu_value:en")) {
				$supports_iu = "true";
			}

			my $other_nutriment_unit = get_property("nutrients", "zz:$nid", "unit:en");
			$other_nutriments
				.= '{ "value" : "'
				. $other_nutriment_value
				. '", "unit" : "'
				. $other_nutriment_unit
				. '", "iu": '
				. $supports_iu . '  },' . "\n";
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

	# Packaging photo and data
	my @packaging_fields = ("packaging_image", "packaging_text");

	$template_data_ref_display->{display_tab_packaging}
		= display_input_tabs($product_ref, "packaging_image", $product_ref->{sorted_langs}, \%Langs,
		\@packaging_fields);

	# Add an empty packaging element to the form, that will be hidden and duplicated when the user adds new packaging items,
	# and another empty packaging element at the end
	if (not defined $product_ref->{packagings}) {
		$product_ref->{packagings} = [];
	}
	my $number_of_packaging_components = scalar @{$product_ref->{packagings}};

	unshift(@{$product_ref->{packagings}}, {});
	push(@{$product_ref->{packagings}}, {});

	# Product check

	if ($User{moderator}) {
		my $checked = '';
		my $label = $Lang{i_checked_the_photos_and_data}{$lang};
		my $recheck_html = "";

		if ((defined $product_ref->{checked}) and ($product_ref->{checked} eq 'on')) {
			$checked = 'checked="checked"';
			$label = $Lang{photos_and_data_checked}{$lang};
		}

		$template_data_ref_display->{product_ref_checked} = $product_ref->{checked};
		$template_data_ref_display->{product_check_label} = $label;
		$template_data_ref_display->{product_check_checked} = $checked;

	}

	$template_data_ref_display->{param_fields} = single_param("fields");
	$template_data_ref_display->{type} = $type;
	$template_data_ref_display->{code} = $code;
	$template_data_ref_display->{display_product_history} = display_product_history($code, $product_ref);
	$template_data_ref_display->{product} = $product_ref;

	process_template('web/pages/product_edit/product_edit_form_display.tt.html', $template_data_ref_display, \$html)
		or $html = "<p>" . $tt->error() . "</p>";
	process_template('web/pages/product_edit/product_edit_form_display.tt.js', $template_data_ref_display, \$js);
	$initjs .= $js;
	$request_ref->{page_type} = "product_edit";
	$request_ref->{page_format} = "banner";

}
elsif (($action eq 'display') and ($type eq 'delete') and ($User{moderator})) {

	my $template_data_ref_moderator = {};

	$log->debug("display product", {code => $code}) if $log->is_debug();

	$template_data_ref_moderator->{product_name} = $product_ref->{product_name};
	$template_data_ref_moderator->{type} = $type;
	$template_data_ref_moderator->{code} = $code;

	process_template('web/pages/product_edit/product_edit_form_display_user-moderator.tt.html',
		$template_data_ref_moderator, \$html)
		or $html = "<p>" . $tt->error() . "</p>";

}
elsif ($action eq 'process') {
	# process the form

	my $template_data_ref_process = {type => $type};

	$log->debug("phase 2", {code => $code}) if $log->is_debug();

	$product_ref->{interface_version_modified} = $interface_version;

	# removal is just putting "on" in delete
	if (($User{moderator}) and ($type eq 'delete')) {
		$product_ref->{deleted} = 'on';
		$comment = lang("deleting_product") . separator_before_colon($lc) . ":";
	}
	elsif (($User{moderator}) and (exists $product_ref->{deleted})) {
		delete $product_ref->{deleted};
	}

	my $time = time();
	$comment = $comment . remove_tags_and_quote(decode utf8 => single_param('comment'));
	store_product($User_id, $product_ref, $comment);

	# now display next page
	my $url_prefix = "";
	if (defined $product_ref->{server}) {
		# product that was moved to OBF from OFF etc.
		$url_prefix = "https://" . $subdomain . "." . $options{other_servers}{$product_ref->{server}}{domain};
	}
	elsif ($type eq 'delete') {
		my $email = <<MAIL
$User_id $Lang{has_deleted_product}{$lc}:

$html

MAIL
			;
		send_email_to_admin(lang("deleting_product"), $email);
		send_event({user_id => $User_id, event_type => "product_removed", barcode => $code, points => 5});
	}
	else {
		# Create an event
		send_event({user_id => $User_id, event_type => "product_edited", barcode => $code, points => 5});
	}

	$log->debug("product edited", {code => $code}) if $log->is_debug();

	$template_data_ref_process->{display_random_sample_of_products_after_edits_options}
		= $options{display_random_sample_of_products_after_edits};
	# warning: this option is very slow
	if (    (defined $options{display_random_sample_of_products_after_edits})
		and ($options{display_random_sample_of_products_after_edits}))
	{

		my %request = (
			'titleid' => get_string_id_for_lang($lc, product_name_brand($product_ref)),
			'query_string' => $ENV{QUERY_STRING},
			'referer' => referer(),
			'code' => $code,
			'product_changes_saved' => 1,
			'sample_size' => 10
		);

		display_product(\%request);
	}

	$template_data_ref_process->{edited_product_url} = $url_prefix . product_url($product_ref);
	$template_data_ref_process->{edit_product_url} = $url_prefix . product_action_url($product_ref->{code}, "");

	if ($type ne 'delete') {
		# adding contribution card
		# TODO: we should better have a more flexible way to select panels
		$product_ref->{"knowledge_panels_" . $lc} = {};
		$knowledge_panels_options_ref = {};
		initialize_knowledge_panels_options($knowledge_panels_options_ref, $request_ref);
		$knowledge_panels_options_ref->{knowledge_panels_client} = "web";
		create_contribution_card_panel($product_ref, $lc, $cc, $knowledge_panels_options_ref);
		$template_data_ref_process->{contribution_card_panel}
			= display_knowledge_panel($product_ref, $product_ref->{"knowledge_panels_" . $lc}, "contribution_card");
	}
	$template_data_ref_process->{code} = $product_ref->{code};
	process_template('web/pages/product_edit/product_edit_form_process.tt.html', $template_data_ref_process, \$html)
		or $html = "<p>" . $tt->error() . "</p>";

}

$request_ref->{title} = lang($type . '_product');
$request_ref->{content_ref} = \$html;
display_page($request_ref);

exit(0);
