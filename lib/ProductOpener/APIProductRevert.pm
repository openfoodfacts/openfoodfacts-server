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

ProductOpener::APIProductRevert - implementation of API to revert a product to a specific revision

=head1 DESCRIPTION

=cut

package ProductOpener::APIProductRevert;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

use Log::Any qw($log);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&revert_product_api
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Config qw/:all/;
use ProductOpener::HTTP qw/request_param/;
use ProductOpener::Users qw/$Owner_id $User_id/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::API qw/add_error check_user_permission customize_response_for_product normalize_requested_code/;
use ProductOpener::Text qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Mail qw/send_email_to_admin/;

use Encode;

=head2 revert_product_api($request_ref)

Process API v3 requests to revert a product to a specific revision.

=cut

sub revert_product_api ($request_ref) {

	$log->debug("revert_product_api - start", {request => $request_ref}) if $log->is_debug();

	my $response_ref = $request_ref->{api_response};

	# Set the result field for the API response, will be updated later if the product is successfully reverted
	$response_ref->{result} = {id => "product_not_reverted"};

	my $error = 0;

	my $request_body_ref = $request_ref->{body_json};

	# Check we have all needed input parameters
	foreach my $field ("code", "rev") {
		if (not defined $request_body_ref->{$field}) {
			$log->error("revert_product_api - missing input $field", {request => $request_ref})
				if $log->is_error();
			add_error(
				$response_ref,
				{
					message => {id => "missing_field"},
					field => {id => $field},
					impact => {id => "failure"},
				}
			);
			$error++;
		}
	}

	# Check that the user has permission (is an admin or a moderator, or we are on the producers platform)

	if (not check_user_permission($request_ref, $response_ref, "product_revert")) {
		$error++;
	}

	if (not $error) {

		# Load the product
		my ($code, $ai_data_string) = &normalize_requested_code($request_body_ref->{code}, $response_ref);
		my $rev = $request_body_ref->{rev};

		# Check if the code is valid
		if (not is_valid_code($code)) {

			$log->info("invalid code", {code => $code, original_code => $request_body_ref->{code}}) if $log->is_info();
			add_error(
				$response_ref,
				{
					message => {id => "invalid_code"},
					field => {id => "code", value => $request_body_ref->{code}},
					impact => {id => "failure"},
				}
			);
			$error = 1;
		}
		else {
			my $product_id = product_id_for_owner($Owner_id, $code);
			my $product_ref = retrieve_product($product_id);

			if (not defined $product_ref) {
				$log->info("product not found", {code => $code}) if $log->is_info();
				add_error(
					$response_ref,
					{
						message => {id => "product_not_found"},
						field => {id => "code", value => $code},
						impact => {id => "failure"},
					},
					404
				);
				$error = 1;
			}
			else {
				# Check if the revision exists
				my $revision_ref = retrieve_product($product_id, 0, $rev);

				if (not defined $revision_ref) {
					$log->info("revision not found", {code => $code, rev => $rev}) if $log->is_info();
					add_error(
						$response_ref,
						{
							message => {id => "revision_not_found"},
							field => {id => "rev", value => $rev},
							impact => {id => "failure"},
						},
						404
					);
					$error = 1;
				}
				else {
					# Save the product revision as a new revision
					my $comment = "API v3 - revert to revision $rev";
					my $user_comment = request_param($request_ref, "comment");
					if ((defined $user_comment) and ($user_comment !~ /^\s*$/)) {
						$comment .= " - $user_comment";
					}
					store_product($User_id, $revision_ref, $comment);

					# Set the result field for the API response
					$response_ref->{result} = {id => "product_reverted"};

					# Select / compute only the fields requested by the caller, default to all fields
					$response_ref->{product} = customize_response_for_product($request_ref, $revision_ref,
						request_param($request_ref, 'fields') || "all");

					# Send an email to admins - TODO: replace with an event or something once we have a better system in place
					my $email_subject = "Product $code reverted to revision $rev";
					my $email_body = "Product $code has been reverted to revision $rev by user $User_id\n";
					$email_body .= "Comment: $comment\n";
					$email_body .= "Product: " . product_name_brand_quantity($revision_ref) . "\n";
					send_email_to_admin($email_subject, $email_body);
				}
			}
		}
	}

	$log->debug("revert_product_api - stop", {request => $request_ref}) if $log->is_debug();

	return;
}

1;
