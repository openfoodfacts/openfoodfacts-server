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

ProductOpener::APITaxonomy - implementation of APIs to canonicalize taxonomy tags and to display taxonomy tags in a specific language

=head1 DESCRIPTION

=cut

package ProductOpener::APITaxonomy;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

use Log::Any qw($log);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&taxonomy_canonicalize_tags_api
		&taxonomy_display_tags_api
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Config qw/:all/;
use ProductOpener::HTTP qw/request_param/;
use ProductOpener::Tags qw/%taxonomy_fields canonicalize_taxonomy_tag exists_taxonomy_tag display_taxonomy_tag/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::API qw/add_error/;
use Tie::IxHash;

use Encode;

=head2 taxonomy_canonicalize_tags_api ( $request_ref )

Process API V3 taxonomy_canonicalize_tags requests.

Given a comma separated list of tags in a specific language, return a comma separated list of canonical tags.

=head3 Parameters

=head4 $request_ref (input)

Reference to the request object.

=cut

sub taxonomy_canonicalize_tags_api ($request_ref) {

	my $response_ref = $request_ref->{api_response};

	my $target_lc = $request_ref->{lc};

	# We need a taxonomy name to provide suggestions for
	my $tagtype = request_param($request_ref, "tagtype");

	my $local_tags_list = request_param($request_ref, 'local_tags_list');

	# Validate input parameters

	# tagtype and local_tags_list are mandatory
	if (not defined $tagtype) {
		$log->info("missing tagtype") if $log->is_info();
		add_error(
			$response_ref,
			{
				message => {id => "missing_field"},
				field => {id => "tagtype"},
				impact => {id => "failure"},
			}
		);
	}
	if (not defined $local_tags_list) {
		$log->info("missing local_tags_list") if $log->is_info();
		add_error(
			$response_ref,
			{
				message => {id => "missing_field"},
				field => {id => "local_tags_list"},
				impact => {id => "failure"},
			}
		);
	}

	# Check that the taxonomy exists
	elsif (not defined $taxonomy_fields{$tagtype}) {
		$log->info("tagtype is not a taxonomy", {tagtype => $tagtype}) if $log->is_info();
		add_error(
			$response_ref,
			{
				message => {id => "unrecognized_value"},
				field => {id => "tagtype", value => $tagtype},
				impact => {id => "failure"},
			}
		);
	}
	# Canonicalize the tags
	else {
		my @canonical_tags
			= map {canonicalize_taxonomy_tag($target_lc, $tagtype, $_)} split(/\s*,\s*/, $local_tags_list);
		$response_ref->{canonical_tags_list} = join(",", grep {defined $_} @canonical_tags);

		# Also return the canonical tags as an array, and indicate if they exist in the taxonomy
		$response_ref->{canonical_tags}
			= [map {{tag => $_, exists_in_taxonomy => exists_taxonomy_tag($tagtype, $_) ? JSON::true : JSON::false}}
				@canonical_tags];
	}

	return;
}

=head2 taxonomy_display_tags_api ( $request_ref )

Process API V3 taxonomy_display_tags requests.

Given a comma separated list of canonical tags, return a comma separated list of the tags in a specific language.

=head3 Parameters

=head4 $request_ref (input)

Reference to the request object.

=cut

sub taxonomy_display_tags_api ($request_ref) {

	my $response_ref = $request_ref->{api_response};

	my $target_lc = $request_ref->{lc};

	# We need a taxonomy name to provide suggestions for
	my $tagtype = request_param($request_ref, "tagtype");

	my $canonical_tags_list = request_param($request_ref, 'canonical_tags_list');

	# Validate input parameters

	# tagtype and canonical_tags_list are mandatory
	if (not defined $tagtype) {
		$log->info("missing tagtype") if $log->is_info();
		add_error(
			$response_ref,
			{
				message => {id => "missing_field"},
				field => {id => "tagtype"},
				impact => {id => "failure"},
			}
		);
	}
	if (not defined $canonical_tags_list) {
		$log->info("missing canonical_tags_list") if $log->is_info();
		add_error(
			$response_ref,
			{
				message => {id => "missing_field"},
				field => {id => "tags_list"},
				impact => {id => "failure"},
			}
		);
	}

	# Check that the taxonomy exists
	elsif (not defined $taxonomy_fields{$tagtype}) {
		$log->info("tagtype is not a taxonomy", {tagtype => $tagtype}) if $log->is_info();
		add_error(
			$response_ref,
			{
				message => {id => "unrecognized_value"},
				field => {id => "tagtype", value => $tagtype},
				impact => {id => "failure"},
			}
		);
	}
	# Generate the local display tags
	else {
		$response_ref->{local_tags_list}
			= join(", ", map {display_taxonomy_tag($target_lc, $tagtype, $_)} split(/\s*,\s*/, $canonical_tags_list));
	}

	return;
}

return 1;
