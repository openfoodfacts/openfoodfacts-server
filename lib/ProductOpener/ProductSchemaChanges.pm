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

ProductOpener::ProductSchemaChanges - convert product data between different schema versions

=head1 DESCRIPTION

C<ProductOpener::ProductSchemaChanges> is used to convert product data between different schema versions.

It can convert older product data (e.g. from old revisions of products) to the current schema version.

And for API backward compatibility, it can also convert the current product data to older schema versions.

=head2 Schema version numbering

Starting from March 2024, we will now include a new field in the product data called "schema_version", which will be an integer, starting at 1001.

The schema version will be incremented by 1 each time we make a change to the product data schema.

Products without a schema_version field will be considered to be at a schema version under 1000

=head2 Schema conversion functions

We will keep a list of functions that can convert product data between different schema versions.

=cut

package ProductOpener::ProductSchemaChanges;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		$current_schema_version
		&convert_product_schema
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Tags qw/compute_field_tags/;
use ProductOpener::Products qw/normalize_code/;
use ProductOpener::Config qw/:all/;

$current_schema_version = 1001;

my (%upgrade_functions, %downgrade_functions);

=head1 FUNCTIONS

=head2 convert_product_schema ($product_ref, $to_version)

Convert product data between different schema versions.

=cut

sub convert_product_schema ($product_ref, $to_version) {

	# If the product data does not have a schema_version field, it is 1000 or lower
	# If the product data contains environmental_score_grade, it is 1000, otherwise we set it to 998
	# so that we can run the 998 to 999 upgrade function (barcode normalization)
	my $from_version = $product_ref->{schema_version} // 999;
	if ($from_version < 1000 and exists $product_ref->{environmental_score_grade}) {
		$from_version = 1000;
	}

	if ($from_version < $to_version) {
		# incrementally upgrade schema
		for (my $schema_version = $from_version; $schema_version < $to_version; $schema_version++) {
			if (exists $upgrade_functions{$schema_version}) {
				$upgrade_functions{$schema_version}->($product_ref);
			}
		}
	}
	elsif ($from_version > $to_version) {
		# incrementally downgrade version
		for (my $schema_version = $from_version; $schema_version > $to_version; $schema_version--) {
			if (exists $downgrade_functions{$schema_version}) {
				$downgrade_functions{$schema_version}->($product_ref);
			}
		}
	}

	$product_ref->{schema_version} = $to_version;

	return;
}

%upgrade_functions = (
	998 => \&convert_schema_998_to_999_change_barcode_normalization,
	999 => \&convert_schema_999_to_1000_rename_ecoscore_fields_to_environmental_score,
	1000 => \&convert_schema_1000_to_1001_remove_ingredients_hierarchy_taxonomize_brands,
);

%downgrade_functions = (
	1000 => \&convert_schema_1000_to_999_rename_ecoscore_fields_to_environmental_score,
	1001 => \&convert_schema_1001_to_1000_remove_ingredients_hierarchy_taxonomize_brands,
);

=head2 998 to 999 - Change in barcode normalization

Change in normalization of leading 0s.

=cut

sub convert_schema_998_to_999_change_barcode_normalization ($product_ref) {

	my $code = normalize_code($product_ref->{code});
	$product_ref->{code} = $code;
	if (defined $product_ref->{id}) {
		$product_ref->{id} = $code;
	}
	if ($server_options{private_products}) {
		$product_ref->{_id} = $product_ref->{owner} . "/" . $code;
	}
	else {
		$product_ref->{_id} = $code;
	}

	return;
}

=head2 999 to 1000 - Rename ecoscore fields to environmental_score fields - API v3.1

2024/12/12 - 

=cut

sub convert_schema_999_to_1000_rename_ecoscore_fields_to_environmental_score ($product_ref) {

	# 2024/12: ecoscore fields were renamed to environmental_score
	foreach my $subfield (qw/data grade score tags/) {
		if (defined $product_ref->{"ecoscore_" . $subfield}) {
			# If we already have corresponding environmental_score fields, we keep them
			if (not defined $product_ref->{"environmental_score_" . $subfield}) {
				$product_ref->{"environmental_score_" . $subfield} = $product_ref->{"ecoscore_" . $subfield};
			}
			delete $product_ref->{"ecoscore_" . $subfield};
		}
	}

	return;
}

sub convert_schema_1000_to_999_rename_ecoscore_fields_to_environmental_score ($product_ref) {

	# 2024/12: ecoscore fields were renamed to environmental_score
	foreach my $subfield (qw/data grade score tags/) {
		if (defined $product_ref->{"environmental_score_" . $subfield}) {
			$product_ref->{"ecoscore_" . $subfield} = $product_ref->{"environmental_score_" . $subfield};
			delete $product_ref->{"environmental_score_" . $subfield};
		}
	}

	return;
}

=head2 1000 to 1001 - Remove the ingredients_hierarchy field - API v3.2

2012/03/14

- Remove the ingredients_hierarchy field, which was a duplicate of the ingredients_tags field
- Taxonomize brands

=cut

sub convert_schema_1000_to_1001_remove_ingredients_hierarchy_taxonomize_brands ($product_ref) {

	# The ingredients_hierarchy array contained exactly the same data as the ingredients_tags array
	delete $product_ref->{ingredients_hierarchy};

	# Taxonomize brands
	# we use the main language of the product, but the brands taxonomy is language-less
	# (all canonical entries use the language less xx: prefix) so any language would give the same result
	if (defined $product_ref->{brands}) {
		compute_field_tags($product_ref, $product_ref->{lang}, "brands");
	}

	return;
}

sub convert_schema_1001_to_1000_remove_ingredients_hierarchy_taxonomize_brands ($product_ref) {

	# The ingredients_hierarchy array contained exactly the same data as the ingredients_tags array
	if (exists $product_ref->{ingredients_tags}) {
		$product_ref->{ingredients_hierarchy} = $product_ref->{ingredients_tags};
	}

	# remove brands_lc and brands_hierarchy
	delete $product_ref->{brands_lc};
	delete $product_ref->{brands_hierarchy};
	# brands should already contain the list of brands, so we do not need to regenerate it from brands_hierarchy
	# brands_tags contains xx: prefixed tags, we can remove the xx: prefix to get the non-taxonomized canonical tags we had before
	if (exists $product_ref->{brands_tags}) {
		for my $brand_tag (@{$product_ref->{brands_tags}}) {
			$brand_tag =~ s/^xx://;
		}
	}

	return;
}

