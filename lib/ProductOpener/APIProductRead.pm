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

=head3 Parameters

=head4 $request_ref (input)

Reference to the request object.

=cut

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
		my $fields = single_param('fields');
		if (defined $fields) {

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

1;
