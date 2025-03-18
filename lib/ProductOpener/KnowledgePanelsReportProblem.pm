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

ProductOpener::KnowledgePanelsReportProblem - Generate knowledge panels to report a problem with the data or the product

=head1 SYNOPSIS

Knowledge panels to indicate how to report a problem with the product data,
or with the product (e.g. link to report to authorities like SignalConso in France)

=cut

package ProductOpener::KnowledgePanelsReportProblem;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

use Log::Any qw($log);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&create_report_problem_card_panel
		&create_data_quality_panel
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::KnowledgePanels qw(create_panel_from_json_template);
use ProductOpener::Tags qw/:all/;
use ProductOpener::ConfigEnv qw/:all/;

use Encode;
use Data::DeepAccess qw(deep_get);

=head2 create_report_problem_card_panel ( $product_ref, $target_lc, $target_cc, $options_ref )

Creates a knowledge panel card that contains all knowledge panels related to reporting problems.

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

sub create_report_problem_card_panel ($product_ref, $target_lc, $target_cc, $options_ref) {

	$log->debug("create contribution card panel", {code => $product_ref->{code}}) if $log->is_debug();

	my @panels = ();

	# TODO: add a panel to display the consumer service contact information if we have it
	# for the owner of the product. Otherwise, warn that we don't make or sell the product
	# + add promo message for the pro platform ("Are you the owner? Add your contact information")

	# Panel to tell users that they can fix the data themselves
	# or report to nutripatrol
	create_panel_from_json_template(
		"incomplete_or_incorrect_data",
		"api/knowledge-panels/report_problem/incomplete_or_incorrect_data.tt.json",
		{nutripatrol_enabled => !!$nutripatrol_url},
		$product_ref, $target_lc, $target_cc, $options_ref
	);
	push(@panels, "incomplete_or_incorrect_data");

	# Panels to report product issues to local authorities

	# France - SignalConso

	if (($target_cc eq "fr") and ($target_lc eq "fr")) {

		create_panel_from_json_template(
			"fr_report_product_signalconso",
			"api/knowledge-panels/report_problem/fr_report_product_signalconso.tt.json",
			{}, $product_ref, $target_lc, $target_cc, $options_ref
		);
		push(@panels, "fr_report_product_signalconso");
	}

	my $panel_data_ref = {report_problem_panels => \@panels,};
	create_panel_from_json_template("report_problem_card",
		"api/knowledge-panels/report_problem/report_problem_card.tt.json",
		$panel_data_ref, $product_ref, $target_lc, $target_cc, $options_ref);

	return 1;
}

1;
