# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2020 Association Open Food Facts
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

ProductOpener::Packaging 

=head1 SYNOPSIS


=head1 DESCRIPTION


=cut

package ProductOpener::Packaging;

use utf8;
use Modern::Perl '2017';
use Exporter    qw< import >;

use Log::Any qw($log);

BEGIN
{
	use vars       qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(

		&extract_packaging_from_image

		);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;

use ProductOpener::Config qw/:all/;
use ProductOpener::Images qw/:all/;


=head1 FUNCTIONS

=head2 extract_packagings_from_image( $product_ref $id $ocr_engine $results_ref )

Extract packaging data from packaging info / recycling instructions photo.

=cut

sub extract_packaging_from_image($$$$) {

	my $product_ref = shift;
	my $id = shift;
	my $ocr_engine = shift;
	my $results_ref = shift;

	my $lc = $product_ref->{lc};

	if ($id =~ /_(\w\w)$/) {
		$lc = $1;
	}

	extract_text_from_image($product_ref, $id, "packaging_text_from_image", $ocr_engine, $results_ref);

	# TODO: extract structured data from the text
	if (($results_ref->{status} == 0) and (defined $results_ref->{packaging_text_from_image})) {

		$results_ref->{packaging_text_from_image_orig} = $product_ref->{packaging_text_from_image};
	}

	return;
}


1;

