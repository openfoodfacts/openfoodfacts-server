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

ProductOpener::KnowledgePanelsProduct - Generate knowledge panels around raw data

=head1 SYNOPSIS

This is a subpart of Knowledge Panels where we concentrate around raw information

=cut

package ProductOpener::KnowledgePanelsProduct;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

use Log::Any qw($log);
use Data::Dumper;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&create_product_card_panel
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::KnowledgePanels qw(create_panel_from_json_template);
use ProductOpener::Tags qw(display_taxonomy_tag get_tags_grouped_by_property get_taxonomy_tag_and_link_for_lang);

use Encode;
use Data::DeepAccess qw(deep_get);

=head2 create_product_card_panel ( $product_ref, $target_lc, $target_cc, $options_ref )


Creates a knowledge panel card that contains all knowledge panels related to the product.


This panel card is created for food, pet food, and beauty products.


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

sub create_product_card_panel ($product_ref, $target_lc, $target_cc, $options_ref, $request_ref) {
	$log->debug("create product card panel", {code => $product_ref->{code}}) if $log->is_debug();

	my @taxonomy_fields = qw(
		brands_tags
		countries_tags
		stores_tags
		origins_tags
		manufacturing_places_tags
		labels_tags
	);

	my @taxonomy_panels;

	foreach my $field (@taxonomy_fields) {
		my $tags = $product_ref->{$field};
		next unless $tags && @$tags;

		(my $field_name = $field) =~ s/_tags$//;
		my $raw_field_name = $field_name;
		$field_name =~ s/_/-/g;

		my @tags_data = map {
			my $link = get_taxonomy_tag_and_link_for_lang($target_lc, $field_name, $_);
			{
				name => $link->{display},
				url => "/facets/$field_name/" . $link->{tagurl},
			}
		} @$tags;

		my $panel_data_ref = {
			field_name => $field_name,
			tags => \@tags_data,
			raw_field_name => $raw_field_name,
		};

		create_panel_from_json_template("raw_$field_name", "api/knowledge-panels/product/product_panel.tt.json",
			$panel_data_ref, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref);

		push @taxonomy_panels,
			{
			field_name => $field_name,
			tags => \@tags_data,
			};
	}

	my $panel_data_ref = {
		taxonomy_panels => \@taxonomy_panels,
		target_lc => $target_lc,
	};

	$log->debug("Taxonomy panels: " . Dumper($panel_data_ref->{taxonomy_panels})) if $log->is_debug();

	create_panel_from_json_template("product_card", "api/knowledge-panels/product/product_card.tt.json",
		$panel_data_ref, $product_ref, $target_lc, $target_cc, $options_ref, $request_ref);

	return 1;
}

1;
