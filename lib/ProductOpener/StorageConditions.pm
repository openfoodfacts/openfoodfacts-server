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
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

=encoding UTF-8

=head1 NAME

ProductOpener::StorageConditions - Set storage_conditions and storage_conditions_tags on products

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

package ProductOpener::StorageConditions;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

use Log::Any qw($log);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&set_storage_conditions
	);
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use ProductOpener::ProductsTags qw/add_tag remove_tag get_inherited_property_from_categories_tags/;

=head2 set_storage_conditions($product_ref)

Set the storage_conditions and storage_conditions_tags fields on a product
based on the inherited storage_conditions:en property of its categories.

=head3 Parameters

=head4 $product_ref

Reference to the product data structure.

=head3 Return

Modifies $product_ref in place, setting:
- storage_conditions: plain string value (e.g. "frozen")
- storage_conditions_tags: array ref of canonical tag IDs (e.g. ["en:frozen"])

=cut

sub set_storage_conditions ($product_ref) {

	$log->debug("set_storage_conditions - start") if $log->is_debug();

	if ((defined $product_ref->{categories_tags}) and (scalar @{$product_ref->{categories_tags}} > 0)) {

		my ($storage_condition_tag, $matching_category)
			= get_inherited_property_from_categories_tags($product_ref, "storage_conditions:en");

		if (defined $storage_condition_tag) {
			$product_ref->{storage_conditions} = $storage_condition_tag;
			$product_ref->{storage_conditions_tags} = [$storage_condition_tag];
		}
		else {
			delete $product_ref->{storage_conditions};
			delete $product_ref->{storage_conditions_tags};
		}
	}
	else {
		delete $product_ref->{storage_conditions};
		delete $product_ref->{storage_conditions_tags};
	}

	$log->debug(
		"set_storage_conditions - done",
		{
			storage_conditions => $product_ref->{storage_conditions},
			storage_conditions_tags => $product_ref->{storage_conditions_tags}
		}
	) if $log->is_debug();

	# Add a misc tag to indicate that storage_conditions were set or not
	if (defined $product_ref->{misc_tags}) {
		remove_tag($product_ref, "misc", "en:storage-conditions-set");
		remove_tag($product_ref, "misc", "en:storage-conditions-not-set");
	}
	if (defined $product_ref->{storage_conditions}) {
		add_tag($product_ref, "misc", "en:storage-conditions-set");
	}
	else {
		add_tag($product_ref, "misc", "en:storage-conditions-not-set");
	}

	return;
}

1;
