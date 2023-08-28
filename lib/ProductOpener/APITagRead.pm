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

package ProductOpener::APITagRead;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

use Log::Any qw($log);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&read_tag_api
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Config qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::API qw/:all/;
use ProductOpener::KnowledgePanels qw/:all/;
use ProductOpener::KnowledgePanelsTags qw/:all/;
use ProductOpener::Tags qw/:all/;

=head2 read_tag_api ( $request_ref )

Process API V3 READ tag requests.

Currently only return the knowledge_panels field for the tag, if any.

=head3 Parameters

=head4 $request_ref (input)

Reference to the request object.

=cut

sub read_tag_api ($request_ref) {

	$log->debug("read_tag_api - start", {request => $request_ref}) if $log->is_debug();

	my $response_ref = $request_ref->{api_response};

	# we add the inputs to the response
	my $tagtype = $request_ref->{tagtype};
	my $tagid = $request_ref->{tagid};

	$response_ref->{tagtype} = $tagtype;
	$response_ref->{tagid} = $tagid;

	if (not defined $tagtype) {

		add_error(
			$response_ref,
			{
				message => {id => "missing_tagtype"},
				field => {id => "tagtype", value => $tagtype},
				impact => {id => "failure"},
			}
		);
		$response_ref->{result} = {id => "tag_not_found"};
	}

	if (not defined $tagid) {

		add_error(
			$response_ref,
			{
				message => {id => "missing_tagid"},
				field => {id => "tagid", value => $tagtype},
				impact => {id => "failure"},
			}
		);
		$response_ref->{result} = {id => "tag_not_found"};
	}

	# TODO: add check for valid tagtype? (we currently do not have a definitive list though)

	if ((defined $tagtype) and (defined $tagid)) {
		$response_ref->{result} = {id => "tag_found"};

		# Canonicalize the tagid
		my $canon_tagid;
		if (defined $taxonomy_fields{$tagtype}) {
			$canon_tagid = canonicalize_taxonomy_tag($lc, $tagtype, $tagid);

		}
		else {
			my $display_tag = canonicalize_tag2($tagtype, $tagid);
			$canon_tagid = get_string_id_for_lang("no_language", $display_tag);
		}

		# add canonical values to tag output
		$response_ref->{tag} = {
			tagid => $canon_tagid,
			tagtype => $tagtype
		};

		initialize_knowledge_panels_options($knowledge_panels_options_ref, $request_ref);
		my $tag_ref = {};    # Object to store the knowledge panels
		my $panels_created
			= create_tag_knowledge_panels($tag_ref, $lc, $cc, $knowledge_panels_options_ref, $tagtype, $canon_tagid);

		if ($panels_created) {
			$response_ref->{tag}{knowledge_panels} = $tag_ref->{"knowledge_panels" . "_" . $lc};
		}
	}

	$log->debug("read_tag_api - stop", {request => $request_ref}) if $log->is_debug();

	return;
}

1;
