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

=encoding UTF-8

=head1 NAME

ProductOpener::TaxonomiesEnhancer - analyze ingredients and other fields to enrich the taxonomies

=head1 SYNOPSIS

C<ProductOpener::TaxonomiesEnhancer> analyze
analyze ingredients and other fields to enrich the taxonomies

    use ProductOpener::TaxonomiesEnhancer qw/:all/;

	[..]

	detect_taxonomy_translation_from_text($product_ref);

=head1 DESCRIPTION

[..]

=cut

package ProductOpener::TaxonomiesEnhancer;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(

		&detect_taxonomy_translation_from_text
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;
# use experimental 'smartmatch';
# use Encode;
# use Clone qw(clone);
# use LWP::UserAgent;
# use Encode;
# use JSON::MaybeXS;
use Log::Any qw($log);
# use List::MoreUtils qw(uniq);
# use Data::DeepAccess qw(deep_get deep_exists);

# use ProductOpener::Store qw/get_string_id_for_lang unac_string_perl/;
# use ProductOpener::Config qw/:all/;
# use ProductOpener::Users qw/:all/;
# use ProductOpener::Tags qw/:all/;
# use ProductOpener::Products qw/remove_fields/;
# use ProductOpener::URL qw/:all/;
# use ProductOpener::Images qw/extract_text_from_image/;
# use ProductOpener::Lang qw/$lc %Lang lang/;
# use ProductOpener::Units qw/normalize_quantity/;
# use ProductOpener::Food qw/is_fat_oil_nuts_seeds_for_nutrition_score/;
use ProductOpener::Ingredients qw/parse_ingredients_text_service/;



=head2 detect_taxonomy_translation_from_text ( product_ref )

This function extracts data for each language from the provided product reference.
It then detects failed extractions (missing stop words) and identifies missing translations.

=head3 Arguments

=head4 product_ref

A reference to the product data, which is expected to be a hash reference containing the necessary information.

=head3 Return value

This function does not return any value. It performs the extraction and detection internally.

=cut

sub detect_taxonomy_translation_from_text ($product_ref) {
	$log->debug("detect_taxonomy_translation_from_text - start") if $log->is_debug();
    print STDERR "detect_taxonomy_translation_from_text - start\n";
}

1;
