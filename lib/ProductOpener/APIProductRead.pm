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
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

=head1 NAME

ProductOpener::APIProductRead - implementation of READ API for accessing product data

=head1 DESCRIPTION

=cut

package ProductOpener::APIProductRead;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

use Log::Any qw($log);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&read_product_api
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Config qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::API qw/:all/;

=head2 read_product_api ( $request_ref )

Process API V3 READ product requests.

TODO: v0 / v1 / v2 READ product requests are still handled by Display::display_product_api () which contains similar code.
Internally, we should be able to upgrade those requests to v3, and then customize the response to make it return the v2 expected response.

=head3 Parameters

=head4 $request_ref (input)

Reference to the request object.

=cut

sub read_product_api ($request_ref) {

	$log->debug("read_product_api - start", {request => $request_ref}) if $log->is_debug();

	my $response_ref = $request_ref->{api_response};

	# Is a sample product requested?
	if ((defined $request_ref->{code}) and ($request_ref->{code} eq "example")) {

		$request_ref->{code}
			= $options{"sample_product_code_country_${cc}_language_${lc}"}
			|| $options{"sample_product_code_country_${cc}"}
			|| $options{"sample_product_code_language_${lc}"}
			|| $options{"sample_product_code"}
			|| "";
	}

	my $code = normalize_requested_code($request_ref->{code}, $response_ref);

	my $product_ref;
	my $product_id;

	# Check if the code is valid
	if ($code !~ /^\d{4,24}$/) {

		$log->info("invalid code", {code => $code, original_code => $request_ref->{code}}) if $log->is_info();
		add_error(
			$response_ref,
			{
				message => {id => "invalid_code"},
				field => {id => "code", value => $request_ref->{code}},
				impact => {id => "failure"},
			}
		);
		$response_ref->{result} = {id => "product_not_found"};
	}
	else {
		# Check that the product exist, is published, is not deleted, and has not moved to a new url

		$log->debug("read_product_api", {code => $code, params => {CGI::Vars()}}) if $log->is_debug();

		$product_id = product_id_for_owner($Owner_id, $code);

		my $rev = single_param("rev");
		local $log->context->{rev} = $rev;
		if (defined $rev) {
			$product_ref = retrieve_product_rev($product_id, $rev);
		}
		else {
			$product_ref = retrieve_product($product_id);
		}
	}

	if ((not defined $product_ref) or (not defined $product_ref->{code})) {

		# Return an error if we could not find a product

		if ($request_ref->{api_version} >= 1) {
			$request_ref->{status_code} = 404;
		}

		add_error(
			$response_ref,
			{
				message => {id => "product_not_found"},
				field => {id => "code", value => $code},
				impact => {id => "failure"},
			}
		);
		$response_ref->{result} = {id => "product_not_found"};
	}
	else {
		$response_ref->{result} = {id => "product_found"};

		add_images_urls_to_product($product_ref, $lc);

		# Select / compute only the fields requested by the caller, default to all
		$response_ref->{product} = customize_response_for_product($request_ref, $product_ref,
			request_param($request_ref, 'fields') || "all");

		# Disable nested ingredients in ingredients field (bug #2883)
		# 2021-02-25: we now store only nested ingredients, flatten them if the API is <= 1

		if ($request_ref->{api_version} <= 1) {

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
			$response_ref->{blame} = {};
			compute_product_history_and_completeness($data_root, $product_ref, $changes_ref, $response_ref->{blame});
		}

	}

	$log->debug("read_product_api - stop", {request => $request_ref}) if $log->is_debug();

	return;
}

1;
