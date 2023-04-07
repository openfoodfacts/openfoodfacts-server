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

ProductOpener::KnowledgePanelsContribution - Generate knowledge panels around contribution

=head1 SYNOPSIS

This is a subpart of Knowledge Panels where we concentrate around contribution information

=cut

package ProductOpener::KnowledgePanelsContribution;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

use Log::Any qw($log);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&create_contribution_card_panel
		&create_data_quality_panel
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::KnowledgePanels qw(create_panel_from_json_template);
use ProductOpener::Tags qw(:all);

use Encode;
use Data::DeepAccess qw(deep_get);

=head2 create_contribution_card_panel ( $product_ref, $target_lc, $target_cc, $options_ref )

Creates a knowledge panel card that contains all knowledge panels related to contribution

=head3 Arguments

=head4 product reference $product_ref

Loaded from the MongoDB database, Storable files, or the OFF API.

=head4 language code $target_lc

Returned attributes contain both data and strings intended to be displayed to users.
This parameter sets the desired language for the user facing strings.

=head4 country code $target_cc

We may display country specific recommendations from health authorities, or country specific scores.

=head4 options reference $options_ref

=cut

sub create_contribution_card_panel ($product_ref, $target_lc, $target_cc, $options_ref) {

	$log->debug("create contribution card panel", {code => $product_ref->{code}}) if $log->is_debug();

	my @panels = ();
	for my $tag_type (qw(data_quality_errors data_quality_warnings data_quality_info)) {
		# we need to create it first because it can condition contribution panel display
		my $created = create_data_quality_panel($tag_type, $product_ref, $target_lc, $target_cc, $options_ref);
		push(@panels, $created) if $created;
	}
	if (@panels) {
		my $panel_data_ref = {quality_panels => \@panels,};
		create_panel_from_json_template("contribution_card",
			"api/knowledge-panels/contribution/contribution_card.tt.json",
			$panel_data_ref, $product_ref, $target_lc, $target_cc, $options_ref);
	}
	return !!@panels;
}

# private sub to add tag names to data_quality_tags_by_actions: we just iterate to add tag name
sub _add_quality_tags_names ($tagtype, $target_lc, $quality_tags_by_action) {
	while (my ($action, $tags) = each %$quality_tags_by_action) {
		while (my ($tagid, $infos) = each %$tags) {
			$infos->{"display_name"} = display_taxonomy_tag($target_lc, $tagtype, $tagid);
		}
	}
	return;
}

=head2 create_data_quality_panel ( $tags_type, $product_ref, $target_lc, $target_cc, $options_ref )

Creates knowledge panels to describe quality issues and invite to contribute

=head3 Arguments

=head4 $tags_type - str

The type of tag. Eg. "data_quality_errors"

=head4 product reference $product_ref

Loaded from the MongoDB database, Storable files, or the OFF API.

=head4 language code $target_lc

Returned attributes contain both data and strings intended to be displayed to users.
This parameter sets the desired language for the user facing strings.

=head4 country code $target_cc

=cut

sub create_data_quality_panel ($tags_type, $product_ref, $target_lc, $target_cc, $options_ref) {

	$log->debug("create quality errors panel", {code => $product_ref->{code}}) if $log->is_debug();

	my $field_name = $tags_type . "_tags";
	my @data_quality_tags = @{$product_ref->{$field_name} // []};
	my $created = undef;
	# Only display to login user on the web !
	if (   $options_ref->{user_logged_in}
		&& ($options_ref->{knowledge_panels_client} eq 'web')
		&& (scalar @data_quality_tags))
	{
		my $panel_data_ref = {};
		my $quality_tags_by_action = get_tags_grouped_by_property("data_quality", $product_ref->{$field_name},
			"fix_action:en", ["description:en"], ["show_to:en"]);
		if (%$quality_tags_by_action) {
			_add_quality_tags_names($tags_type, $target_lc, $quality_tags_by_action);
			$panel_data_ref->{tags_type} = $tags_type;
			$panel_data_ref->{quality_actions} = $quality_tags_by_action;
			create_panel_from_json_template($tags_type, "api/knowledge-panels/contribution/data_quality_tags.tt.json",
				$panel_data_ref, $product_ref, $target_lc, $target_cc, $options_ref);
			$created = 1;
		}
	}
	return $tags_type if $created;
	return;
}

1;
