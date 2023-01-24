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

ProductOpener::ContributionKnowledgePanels - Generate knowledge panels around contribution

=head1 SYNOPSIS

This is a subpart of KnowledgPanels where we concentrate around contribution informations

=cut

package ProductOpener::ContributionKnowledgePanels;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

use Log::Any qw($log);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&create_contribution_card_panel
		&create_data_quality_errors_panel
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::KnowledgePanels qw(create_panel_from_json_template);

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

	create_data_quality_errors_panel($product_ref, $target_lc, $target_cc, $options_ref);

	my $panel_data_ref = {};
	create_panel_from_json_template("contribution_card", "api/knowledge-panels/contribution/contribution_card.tt.json",
		$panel_data_ref, $product_ref, $target_lc, $target_cc, $options_ref);
	return;
}

=head2 create_data_quality_errors_panel ( $product_ref, $target_lc, $target_cc, $options_ref )

Creates knowledge panels to describe quality issues and invite to contribute

=head3 Arguments

=head4 product reference $product_ref

Loaded from the MongoDB database, Storable files, or the OFF API.

=head4 language code $target_lc

Returned attributes contain both data and strings intended to be displayed to users.
This parameter sets the desired language for the user facing strings.

=head4 country code $target_cc

=cut

sub create_data_quality_errors_panel ($product_ref, $target_lc, $target_cc, $options_ref) {

	$log->debug("create quality errors panel", {code => $product_ref->{code}}) if $log->is_debug();

	my $panel_data_ref = {};

	my @data_quality_errors_tags = @{$product_ref->{data_quality_errors_tags}};
	# Only display to login user on the web and if we have errors !
	if (   $options_ref->{user_logged_in}
		&& ($options_ref->{knowledge_panels_client} eq 'web')
		&& (scalar @data_quality_errors_tags))
	{
		create_panel_from_json_template("data_quality_errors",
			"api/knowledge-panels/contribution/data_quality_errors.tt.json",
			$panel_data_ref, $product_ref, $target_lc, $target_cc, $options_ref);
	}
	return;
}

1;
