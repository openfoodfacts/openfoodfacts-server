# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2026 Association Open Food Facts
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

ProductOpener::APITaxonomy - implementation of APIs to return the list of available attribute groups and preferences

=head1 DESCRIPTION

=cut

package ProductOpener::APIAttributeGroups;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

use Log::Any qw($log);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&display_preferences_api
		&display_attribute_groups_api
		&attribute_groups_api
		&preferences_api
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Config qw/:all/;
use ProductOpener::HTTP qw/set_http_response_header/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::API qw/add_error/;
use ProductOpener::Display qw/display_structured_response/;
use ProductOpener::Attributes qw/list_attributes/;
use Tie::IxHash;

use Encode;

=head2 display_preferences_api ( $target_lc )

Only for API V0 to V2

Return a JSON structure with all available preference values for attributes.

This is used by clients that ask for user preferences to personalize
filtering and ranking based on product attributes.

=head3 Arguments

=head4 request object reference $request_ref

=head4 language code $target_lc

Sets the desired language for the user facing strings.

=cut

sub display_preferences_api ($request_ref, $target_lc) {

	if (not defined $target_lc) {
		$target_lc = $lc;
	}

	$request_ref->{lc} = $target_lc;

	# We use the V3 API function to get the list of preferences
	$request_ref->{api_response} = {};
	preferences_api($request_ref);

	$request_ref->{structured_response} = $request_ref->{api_response}{preferences};

	display_structured_response($request_ref);

	return;
}

=head2 preferences_api ( $request_ref )

Only for API V3+

Return a JSON structure with all available preference values for attributes.

This is used by clients that ask for user preferences to personalize
filtering and ranking based on product attributes.

=head3 Parameters

=head4 $request_ref (input)

Reference to the request object.

=cut

sub preferences_api ($request_ref) {

	my $response_ref = $request_ref->{api_response};

	my $target_lc = $request_ref->{lc};

	$response_ref->{preferences} = [];

	foreach my $preference ("not_important", "important", "very_important", "mandatory") {

		my $preference_ref = {
			id => $preference,
			name => lang("preference_" . $preference),
		};

		if ($preference eq "important") {
			$preference_ref->{factor} = 1;
		}
		elsif ($preference eq "very_important") {
			$preference_ref->{factor} = 2;
		}
		elsif ($preference eq "mandatory") {
			$preference_ref->{factor} = 4;
			$preference_ref->{minimum_match} = 20;
		}

		push @{$response_ref->{preferences}}, $preference_ref;
	}

	set_http_response_header($request_ref, "Cache-Control", "public, max-age=86400");

	return;
}

=head2 display_attribute_groups_api ( $request_ref, $target_lc )

Only for API V0 to V2

Return a JSON structure with all available attribute groups and attributes,
with strings (names, descriptions etc.) in a specific language,
and return them in an array of attribute groups.

This is used in particular for clients of the API to know which
preferences they can ask users for, and then use for personalized
filtering and ranking.

Attributes with parameters such as
unwanted_ingredients are not returned.

=head3 Arguments

=head4 request object reference $request_ref

=head4 language code $target_lc

Returned attributes contain both data and strings intended to be displayed to users.
This parameter sets the desired language for the user facing strings.

=cut

sub display_attribute_groups_api ($request_ref, $target_lc) {

	if (not defined $target_lc) {
		$target_lc = $lc;
	}

	my $attribute_groups_ref = list_attributes($target_lc, $request_ref->{api_version});

	$request_ref->{structured_response} = $attribute_groups_ref;

	set_http_response_header($request_ref, "Cache-Control", "public, max-age=86400");

	display_structured_response($request_ref);

	return;
}

=head2 attribute_groups_api ( $request_ref )

Only for API V3+

Return a JSON structure with all available attribute groups and attributes,
with strings (names, descriptions etc.) in a specific language,
and return them in an array of attribute groups.

This is used in particular for clients of the API to know which
preferences they can ask users for, and then use for personalized
filtering and ranking.

If the API version requested is < 3.4, then attributes with parameters such as
unwanted_ingredients are not returned.

=head3 Parameters

=head4 $request_ref (input)

Reference to the request object.

=cut

sub attribute_groups_api ($request_ref) {

	my $response_ref = $request_ref->{api_response};

	my $target_lc = $request_ref->{lc};

	$response_ref->{attribute_groups} = list_attributes($target_lc, $request_ref->{api_version});

	set_http_response_header($request_ref, "Cache-Control", "public, max-age=86400");

	return;
}

return 1;
