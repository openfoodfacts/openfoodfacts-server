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
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

=head1 NAME

ProductOpener::API - implementation of READ and WRITE APIs

=head1 DESCRIPTION

=cut

package ProductOpener::API;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

use Log::Any qw($log);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&get_initialized_response
		&add_warning
		&add_error
		&process_api_request
		&read_request_body
		&customize_response_for_product
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Config qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Export qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Ecoscore qw/localize_ecoscore/;

use CGI qw(header);
use Apache2::RequestIO();
use Apache2::RequestRec();
use JSON::PP;

sub get_initialized_response() {
	return {
		warnings => [],
		errors => [],
	};
}

sub init_api_response ($request_ref) {

	$request_ref->{api_response} = get_initialized_response();
}

sub add_warning ($response_ref, $warning_ref) {
	push @{$response_ref->{api_response}{warnings}}, $warning_ref;
}

sub add_error ($response_ref, $error_ref) {
	push @{$response_ref->{api_response}{errors}}, $error_ref;
}

sub read_request_body ($request_ref) {

	$log->debug("read_request_body - start", {request => $request_ref}) if $log->is_debug();

	my $r = Apache2::RequestUtil->request();

	my $content = '';

	{
		use bytes;

		my $offset = 0;
		my $cnt = 0;
		do {
			$cnt = $r->read($content, 8192, $offset);
			$offset += $cnt;
		} while ($cnt == 8192);
	}
	$request_ref->{body} = $content;

	$log->debug("read_request_body - end", {request => $request_ref}) if $log->is_debug();
}

sub decode_json_request_body ($request_ref) {

	if (length($request_ref->{body}) == 0) {
		$log->error("empty request body", {}) if $log->is_error();
		add_error(
			$request_ref->{api_response},
			{
				message => {id => "empty_request_body"},
				field => {id => "body", value => ""},
				impact => {id => "failure"},
			}
		);
	}
	else {
		eval {$request_ref->{request_body_json} = decode_json($request_ref->{body});};
		if ($@) {
			$log->error("JSON decoding error", {error => $@}) if $log->is_error();
			add_error(
				$request_ref->{api_response},
				{
					message => {id => "invalid_json_in_request_body"},
					field => {id => "body", value => $request_ref->{body}},
					impact => {id => "failure"},
				}
			);
		}
	}
}

sub add_localized_messages_to_api_response ($request_ref) {

}

sub read_product_api ($request_ref) {

	$log->debug("read_product_api - start", {request => $request_ref}) if $log->is_debug();

	# Is a sample product requested?
	if ((defined $request_ref->{code}) and ($request_ref->{code} eq "example")) {

		$request_ref->{code}
			= $options{"sample_product_code_country_${cc}_language_${lc}"}
			|| $options{"sample_product_code_country_${cc}"}
			|| $options{"sample_product_code_language_${lc}"}
			|| $options{"sample_product_code"}
			|| "";
	}

	my $code = normalize_code($request_ref->{code});
	my $product_id = product_id_for_owner($Owner_id, $code);

	# Check that the product exist, is published, is not deleted, and has not moved to a new url

	$log->debug("read_product_api", {code => $code, params => {CGI::Vars()}}) if $log->is_debug();

	$request_ref->{api_response}{code} = $code;

	my $product_ref;

	my $rev = single_param("rev");
	local $log->context->{rev} = $rev;
	if (defined $rev) {
		$product_ref = retrieve_product_rev($product_id, $rev);
	}
	else {
		$product_ref = retrieve_product($product_id);
	}

	if ($code !~ /^\d{4,24}$/) {

		$log->info("invalid code", {code => $code, original_code => $request_ref->{code}}) if $log->is_info();
		add_error(
			$request_ref->{api_response},
			{
				message => {id => "invalid_code"},
				field => {id => $code, value => $code},
				impact => {id => "failure"},
			}
		);
	}
	elsif ((not defined $product_ref) or (not defined $product_ref->{code})) {
		if (single_param("api_version") >= 1) {
			$request_ref->{status} = 404;
		}

		push @{$request_ref->{api_response}{errors}},
			{
			message => {id => "product_not_found"},
			field => {id => $code, value => $code},
			impact => {id => "failure"},
			};
	}
	else {
		$request_ref->{api_response}{result} = {id => "product_found"};

		add_images_urls_to_product($product_ref, $lc);

		# If the request specified a value for the fields parameter, return only the fields listed
		if (defined single_param('fields')) {

			$log->debug("display_product_api - fields parameter is set", {fields => single_param('fields')})
				if $log->is_debug();

			$request_ref->{api_response}{product} = customize_response_for_product($request_ref, $product_ref);
		}
		else {
			# Otherwise, return the full product
			$request_ref->{api_response}{product} = $product_ref;
		}

		# Disable nested ingredients in ingredients field (bug #2883)
		# 2021-02-25: we now store only nested ingredients, flatten them if the API is <= 1

		if ((defined single_param("api_version")) and (scalar single_param("api_version") <= 1)) {

			if (defined $product_ref->{ingredients}) {

				flatten_sub_ingredients($product_ref);

				foreach my $ingredient_ref (@{$product_ref->{ingredients}}) {
					# Delete sub-ingredients, keep only flattened ingredients
					exists $ingredient_ref->{ingredients} and delete $ingredient_ref->{ingredients};
				}
			}
		}

		# Return blame information
		if (single_param("blame")) {
			my $path = product_path_from_id($product_id);
			my $changes_ref = retrieve("$data_root/products/$path/changes.sto");
			if (not defined $changes_ref) {
				$changes_ref = [];
			}
			$request_ref->{api_response}{blame} = {};
			compute_product_history_and_completeness($data_root, $product_ref, $changes_ref,
				$request_ref->{api_response}{blame});
		}

	}

	$log->debug("read_product_api - stop", {request => $request_ref}) if $log->is_debug();

	return;
}

=head2 write_product_api()


=cut

sub write_product_api ($request_ref) {

	$log->debug("write_product_api - start", {request => $request_ref}) if $log->is_debug();

	decode_json_request_body($request_ref);
	my $request_body_ref = $request_ref->{request_body_json};

	$log->debug("write_product_api - body", {request_body => $request_body_ref}) if $log->is_debug();

	my $response_ref = $request_ref->{api_response};

	# TODO: load the product
	my $product_ref = {};

	if (not defined $request_body_ref) {
		$log->error("write_product_api - missing or invalid input body", {}) if $log->is_error();
	}
	elsif (not defined $request_body_ref->{product}) {
		$log->error("write_product_api - missing input product", {request_body => $request_body_ref})
			if $log->is_error();
		add_error(
			$request_ref->{api_response},
			{
				message => {id => "missing_product"},
				field => {id => "product"},
				impact => {id => "failure"},
			}
		);
	}
	else {
		my $input_product_ref = $request_body_ref->{product};

		$request_ref->{updated_product_fields} = {};

		foreach my $field (sort keys %{$input_product_ref}) {

			my $value = $input_product_ref->{$field};

			if ($field =~ /^packagings(_add)?/) {
				$request_ref->{updated_product_fields}{$1} = 1;
				my $add = $1;
				if (not defined $add) {
					$product_ref->{packagings} = {};
				}

				foreach my $input_packaging_ref (@{$value}) {
					my $packaging_ref = get_checked_and_taxonomized_packaging_component_data($request_ref->{tags_lc},
						$input_packaging_ref, $response_ref);
					add_or_combine_packaging_component_data($product_ref, $packaging_ref, $response_ref);
				}
			}
		}
	}

	$log->debug("write_product_api - stop", {request => $request_ref}) if $log->is_debug();

	return;
}

sub send_api_reponse ($request_ref) {

	my $status = $request_ref->{status_code} || "200";

	my $json = JSON::PP->new->allow_nonref->canonical->utf8->encode($request_ref->{api_response});

	# We need to send the header Access-Control-Allow-Credentials=true so that websites
	# such has hunger.openfoodfacts.org that send a query to world.openfoodfacts.org/cgi/auth.pl
	# can read the resulting response.

	# The Access-Control-Allow-Origin header must be set to the value of the Origin header
	my $r = Apache2::RequestUtil->request();
	my $origin = $r->headers_in->{Origin} || '';

	# Only allow requests from one of our subdomains

	if ($origin =~ /^https:\/\/[a-z0-9-.]+\.${server_domain}(:\d+)?$/) {
		$r->err_headers_out->set("Access-Control-Allow-Credentials", "true");
		$r->err_headers_out->set("Access-Control-Allow-Origin", $origin);
	}

	print header(-status => $status, -type => 'application/json', -charset => 'utf-8');

	print $json;

	$r->rflush;

	# Setting the status makes mod_perl append a default error to the body
	# $r->status($status);
	# Send 200 instead.
	$r->status(200);
}

sub process_api_request ($request_ref) {

	$log->debug("process_api_request - start", {request => $request_ref}) if $log->is_debug();

	init_api_response($request_ref);

	# Analyze the request body

	if ($request_ref->{api_action} eq "product") {

		if ($request_ref->{api_method} eq "POST") {
			write_product_api($request_ref);
		}
		else {
			read_product_api($request_ref);
		}
	}
	else {
		$log->warn("process_api_request - unknown action", {request => $request_ref}) if $log->is_warn();
		push @{$request_ref->{api_response}{errors}},
			{
			message => {id => "unknown_api_action"},
			field => {id => "api_action", value => $request_ref->{api_action}},
			impact => {id => "failure"},
			};
	}

	add_localized_messages_to_api_response($request_ref);

	send_api_reponse($request_ref);

	$log->debug("process_api_request - stop", {request => $request_ref}) if $log->is_debug();
}

=head2 customize_response_for_product ( $request_ref, $product_ref )

Using the fields parameter, API product or search queries can request
a specific set of fields to be returned.

This function filters the field to return only the requested fields,
and computes requested fields that are not stored in the database but
created on demand.

=head3 Parameters

=head4 $request_ref (input)

Reference to the request object.

=head4 $product_ref (input)

Reference to the product object (retrieved from disk or from a MongoDB query)

=head3 Return value

Reference to the customized product object.

=cut

sub customize_response_for_product ($request_ref, $product_ref) {

	my $customized_product_ref = {};

	my $carbon_footprint_computed = 0;

	my $fields = single_param('fields');

	# For non API queries, we need to compute attributes for personal search
	if (((not defined $fields) or ($fields eq "")) and ($request_ref->{user_preferences}) and (not $request_ref->{api}))
	{
		$fields = "code,product_display_name,url,image_front_small_url,attribute_groups";
	}

	# Localize the Eco-Score fields that depend on the country of the request
	localize_ecoscore($cc, $product_ref);

	foreach my $field (split(/,/, $fields)) {
		if ($field eq "product_display_name") {
			$customized_product_ref->{$field} = remove_tags_and_quote(product_name_brand_quantity($product_ref));
		}

		# Allow apps to request a HTML nutrition table by passing &fields=nutrition_table_html
		elsif ($field eq "nutrition_table_html") {
			$customized_product_ref->{$field} = display_nutrition_table($product_ref, undef);
		}

		# Eco-Score details in simple HTML
		elsif ($field eq "ecoscore_details_simple_html") {
			if ((1 or $show_ecoscore) and (defined $product_ref->{ecoscore_data})) {
				$customized_product_ref->{$field}
					= display_ecoscore_calculation_details_simple_html($cc, $product_ref->{ecoscore_data});
			}
		}

		# fields in %language_fields can have different values by language
		# by priority, return the first existing value in the language requested,
		# possibly multiple languages if sent ?lc=fr,nl for instance,
		# and otherwise fallback on the main language of the product
		elsif (defined $language_fields{$field}) {
			foreach my $preferred_lc (@lcs, $product_ref->{lc}) {
				if (    (defined $product_ref->{$field . "_" . $preferred_lc})
					and ($product_ref->{$field . "_" . $preferred_lc} ne ''))
				{
					$customized_product_ref->{$field} = $product_ref->{$field . "_" . $preferred_lc};
					last;
				}
			}
		}

		# [language_field]_languages : return a value with all existing values for a specific language field
		elsif ($field =~ /^(.*)_languages$/) {

			my $language_field = $1;
			$customized_product_ref->{$field} = {};
			if (defined $product_ref->{languages_codes}) {
				foreach my $language_code (sort keys %{$product_ref->{languages_codes}}) {
					if (defined $product_ref->{$language_field . "_" . $language_code}) {
						$customized_product_ref->{$field}{$language_code}
							= $product_ref->{$language_field . "_" . $language_code};
					}
				}
			}
		}

		# Taxonomy fields requested in a specific language
		elsif ($field =~ /^(.*)_tags_([a-z]{2})$/) {
			my $tagtype = $1;
			my $target_lc = $2;
			if (defined $product_ref->{$tagtype . "_tags"}) {
				$customized_product_ref->{$field} = [];
				foreach my $tagid (@{$product_ref->{$tagtype . "_tags"}}) {
					push @{$customized_product_ref->{$field}}, display_taxonomy_tag($target_lc, $tagtype, $tagid);
				}
			}
		}

		# Apps can request the full nutriments hash
		# or specific nutrients:
		# - saturated-fat_prepared_100g : return field at top level
		# - nutrients|nutriments.sugars_serving : return field in nutrients / nutriments hash
		elsif ($field =~ /^((nutrients|nutriments)\.)?((.*)_(100g|serving))$/) {
			my $return_hash = $2;
			my $nutrient = $3;
			if ((defined $product_ref->{nutriments}) and (defined $product_ref->{nutriments}{$nutrient})) {
				if (defined $return_hash) {
					if (not defined $customized_product_ref->{$return_hash}) {
						$customized_product_ref->{$return_hash} = {};
					}
					$customized_product_ref->{$return_hash}{$nutrient} = $product_ref->{nutriments}{$nutrient};
				}
				else {
					$customized_product_ref->{$nutrient} = $product_ref->{nutriments}{$nutrient};
				}
			}
		}
		# Eco-Score
		elsif ($field =~ /^ecoscore/) {

			if (defined $product_ref->{$field}) {
				$customized_product_ref->{$field} = $product_ref->{$field};
			}
		}
		# Product attributes requested in a specific language (or data only)
		elsif ($field =~ /^attribute_groups_([a-z]{2}|data)$/) {
			my $target_lc = $1;
			compute_attributes($product_ref, $target_lc, $cc, $attributes_options_ref);
			$customized_product_ref->{$field} = $product_ref->{$field};
		}
		# Product attributes in the $lc language
		elsif ($field eq "attribute_groups") {
			compute_attributes($product_ref, $lc, $cc, $attributes_options_ref);
			$customized_product_ref->{$field} = $product_ref->{"attribute_groups_" . $lc};
		}
		# Knowledge panels in the $lc language
		elsif ($field eq "knowledge_panels") {
			initialize_knowledge_panels_options($knowledge_panels_options_ref, $request_ref);
			create_knowledge_panels($product_ref, $lc, $cc, $knowledge_panels_options_ref);
			$customized_product_ref->{$field} = $product_ref->{"knowledge_panels_" . $lc};
		}

		# Images to update in a specific language
		elsif ($field =~ /^images_to_update_([a-z]{2})$/) {
			my $target_lc = $1;
			$customized_product_ref->{$field} = {};

			foreach my $imagetype ("front", "ingredients", "nutrition", "packaging") {

				my $imagetype_lc = $imagetype . "_" . $target_lc;

				# Ask for images in a specific language if we already have an old image for that language
				if ((defined $product_ref->{images}) and (defined $product_ref->{images}{$imagetype_lc})) {

					my $imgid = $product_ref->{images}{$imagetype . "_" . $target_lc}{imgid};
					my $age = time() - $product_ref->{images}{$imgid}{uploaded_t};

					if ($age > 365 * 86400) {    # 1 year
						$customized_product_ref->{$field}{$imagetype_lc} = $age;
					}
				}
				# or if the language is the main language of the product
				# or if we have a text value for ingredients / packagings
				elsif (
					($product_ref->{lc} eq $target_lc)
					or (    (defined $product_ref->{$imagetype . "_text_" . $target_lc})
						and ($product_ref->{$imagetype . "_text_" . $target_lc} ne ""))
					)
				{
					$customized_product_ref->{$field}{$imagetype_lc} = 0;
				}
			}
		}

		elsif ((not defined $customized_product_ref->{$field}) and (defined $product_ref->{$field})) {
			$customized_product_ref->{$field} = $product_ref->{$field};
		}
	}

	return $customized_product_ref;
}

1;
