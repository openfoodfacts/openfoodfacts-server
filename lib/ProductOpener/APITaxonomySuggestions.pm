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

ProductOpener::APITaxonomySuggestions - implementation of READ taxonomy suggestions API

=head1 DESCRIPTION

=cut

package ProductOpener::APITaxonomySuggestions;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

use Log::Any qw($log);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&taxonomy_suggestions_api
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Config qw/:all/;
use ProductOpener::Display qw/request_param/;
use ProductOpener::Tags qw/%taxonomy_fields/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::TaxonomySuggestions qw/get_taxonomy_suggestions_with_synonyms/;
use ProductOpener::API qw/add_error/;

use Encode;

=head2 taxonomy_suggestions_api ( $request_ref )

Process API V3 taxonomy suggestions requests.

=head3 Parameters

=head4 $request_ref (input)

Reference to the request object.

=cut

sub taxonomy_suggestions_api ($request_ref) {

	$log->debug("taxonomy_suggestions_api - start", {request => $request_ref}) if $log->is_debug();

	my $response_ref = $request_ref->{api_response};

	# Use HTTP parameters to populate the parameters needed to generate suggestions

	my $search_lc = $request_ref->{lc};

	# We need a taxonomy name to provide suggestions for
	my $tagtype = request_param($request_ref, "tagtype");

	# The API accepts a string input in the "string" field or "term" field.
	# - term is used by the jquery Autocomplete widget: https://api.jqueryui.com/autocomplete/
	# Use "string" only if both are present.
	my $string = request_param($request_ref, 'string') || request_param($request_ref, 'term');

	# We can use the context (e.g. are the suggestions for a specific product sold in a specific country, with specific categories etc.)
	# to rank higher suggestions that are popular for similar products
	my $context_ref = {
		country => $request_ref->{country},
		categories => request_param($request_ref, "categories"),    # list of product categories
		shape => request_param($request_ref, "shape"),    # packaging shape
	};

	# Options define how many suggestions should be returned, in which format etc.
	my $options_ref = {
		limit => request_param($request_ref, 'limit'),
		get_synonyms => request_param($request_ref, 'get_synonyms')
	};

	# Validate input parameters

	# $tagtype is the only mandatory parameter
	if (not defined $tagtype) {
		$log->info("missing tagtype", {tagtype => $tagtype}) if $log->is_info();
		add_error(
			$response_ref,
			{
				message => {id => "missing_field"},
				field => {id => "tagtype"},
				impact => {id => "failure"},
			}
		);
	}
	# Check that the taxonomy exists
	# we also provide suggestions for emb-codes (packaging codes)
	elsif ((not defined $taxonomy_fields{$tagtype}) and ($tagtype ne "emb_codes")) {
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
	# Generate suggestions
	else {
		my @suggestions
			= get_taxonomy_suggestions_with_synonyms($tagtype, $search_lc, $string, $context_ref, $options_ref);
		$log->debug("taxonomy_suggestions_api", @suggestions) if $log->is_debug();
		$response_ref->{suggestions} = [map {$_->{tag}} @suggestions];
		if ($options_ref->{get_synonyms}) {
			$response_ref->{matched_synonyms} = {};
			foreach (@suggestions) {
				$response_ref->{matched_synonyms}->{$_->{tag}} = ucfirst($_->{matched_synonym});
			}
		}
	}

	$log->debug("taxonomy_suggestions_api - stop", {request => $request_ref}) if $log->is_debug();

	return;
}

return 1;
